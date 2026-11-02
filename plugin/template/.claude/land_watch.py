#!/usr/bin/env python3
"""land_watch.py — jalur `gh`/`git` skill `land` (context-vault): jaga PR satu work-item sampai merge.

Disalin ke `.claude/` produk (pola build_status.py). Satu-satunya pintu land ke GitHub, supaya
allowlist cukup satu baris dan batasnya ada di sini, bisa dites.

  scan    --root DIR (--work-item W | --links U[,U…])              satu putaran, cetak kejadian
  watch   … [--interval 120] [--max-rounds N]                      ulang sampai ada kejadian, lalu exit
  ack     …                                                        tandai isi event.json sudah diproses
  attempt … --pr REF --check NAME [--reset]                        hitung percobaan fix pipeline
  log     … --pr REF --check NAME                                  400 baris terakhir log check gagal
  worktree … (--pr REF | --repo-key KEY --base BASE) [--discard]    buat/sinkronkan .land/<slug>/<repo>
  merge-base … --pr REF --dir D                                    merge branch tujuan ke worktree
  commit  … --dir D --message-file F                               commit semua perubahan worktree
  push    … --pr REF --dir D                                       push ke head-ref PR, cuma fast-forward
  reply   … --pr REF --to ID --body-file F                         balas komentar di PR terdaftar
  open-pr … --repo-key KEY --dir D --head B --base BASE --title T --body-file F   PR baru, branch baru
  cleanup …                                                        hapus worktree dan state slug ini

W = `features/<fitur>` atau `fixes/<id>`. REF = `<repo-key>#<n>`. Output JSON ke stdout.
Exit: 0 ok · 1 gagal · 2 argumen salah · 4 gh tak ada · 5 gh akun/izin · 6 ditolak batas `land`.
Skrip ini sengaja tidak punya perintah merge PR, approve, atau menutup PR.
"""
from __future__ import annotations

import sys

sys.dont_write_bytecode = True

import argparse
import importlib.util
import json
import os
import re
import shutil
import signal
import subprocess
import time
from pathlib import Path

HERE = Path(__file__).resolve()
BACKOFF_MAX = 600     # detik; gangguan sementara: lipat dua sampai sini
REPO_URL_RE = re.compile(r'github\.com[/:]([^/\s]+)/([^/\s]+?)(?:\.git)?/?$')
PR_URL_RE = re.compile(r'github\.com/([^/\s]+/[^/\s]+)/pull/(\d+)')
RUN_RE = re.compile(r'/actions/runs/(\d+)')
WORK_ITEM_RE = re.compile(r'^(features|fixes)/([A-Za-z0-9][A-Za-z0-9._-]*)$')
AUTH_MARKERS = ('Could not resolve', 'HTTP 404', 'HTTP 403', 'HTTP 401')
HINT = 'Akun gh aktif mungkin bukan akun kerja — coba `gh auth switch`.'
LOGIN_HINT = 'gh belum login — jalankan `gh auth login` (akun kerja).'
PR_FIELDS = ('number,state,url,headRefName,headRefOid,baseRefName,mergeable,reviewDecision,'
             'isCrossRepository,comments,reviews,statusCheckRollup')
RUN_FAILED = {'FAILURE', 'TIMED_OUT', 'CANCELLED', 'ACTION_REQUIRED', 'STARTUP_FAILURE'}
STATUS_FAILED = {'FAILURE', 'ERROR'}
STATUS_PENDING = {'PENDING', 'EXPECTED'}
KINDS = ('auth', 'merged', 'closed', 'conflict', 'checks_failed', 'comments')

_bs = None


class Fail(Exception):
    """Gagal yang dilaporkan ke user: `code` = exit code, `payload` = JSON stdout. Kode 1 dari `gh` = sementara."""

    def __init__(self, code: int, payload: dict):
        super().__init__(payload.get('detail', ''))
        self.code, self.payload = code, payload


class Replaced(Exception):
    """Watcher ini diganti watcher baru (SIGTERM)."""


def parse_yaml(text: str):
    global _bs
    if _bs is None:
        path = HERE.parent / 'build_status.py'
        if not path.is_file():
            raise Fail(1, {'error': 'build-status-missing', 'hint': 'jalankan /upgrade'})
        spec = importlib.util.spec_from_file_location('cv_build_status', path)
        _bs = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_bs)
    return _bs.parse_yaml(text)


def run_git(cwd, *args, timeout: int = 60) -> tuple[int, str, str]:
    """(exit code, stdout, stderr), di-strip. Timeout/OSError → exit 1."""
    try:
        r = subprocess.run(['git', '-C', str(cwd), *args], capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError) as e:
        return 1, '', str(e)
    return r.returncode, r.stdout.strip(), r.stderr.strip()


def git(cwd, *args) -> tuple[int, str]:
    return run_git(cwd, *args)[:2]


def gh(*args, ndjson: bool = False, raw: bool = False) -> object:
    try:
        r = subprocess.run(['gh', *args], capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.SubprocessError) as e:
        raise Fail(1, {'error': 'gh', 'detail': str(e)}) from None
    if r.returncode:
        detail = (r.stderr.strip().splitlines() or [f'gh exit {r.returncode}'])[0]
        if 'rate limit' in r.stderr.lower():   # 403 rate limit ≠ salah akun
            raise Fail(1, {'error': 'gh-rate-limit', 'detail': detail})
        if 'gh auth login' in r.stderr:
            raise Fail(5, {'error': 'gh-auth', 'detail': detail, 'hint': LOGIN_HINT})
        if any(m in r.stderr for m in AUTH_MARKERS):
            raise Fail(5, {'error': 'gh-auth', 'detail': detail, 'hint': HINT})
        raise Fail(1, {'error': 'gh', 'detail': detail})
    if raw:
        return r.stdout
    try:
        if ndjson:
            return [json.loads(line) for line in r.stdout.splitlines() if line.strip()]
        return json.loads(r.stdout or 'null')
    except json.JSONDecodeError:
        raise Fail(1, {'error': 'gh', 'detail': 'output gh bukan JSON'}) from None


# --- scope -----------------------------------------------------------------------------------

class Scope:
    """Satu work-item (atau daftar link): PR yang dijaga + folder state."""

    def __init__(self, root: Path, slug: str, prs: list[dict], repos: list[dict], bots: set[str]):
        self.root, self.slug, self.prs, self.repos, self.bots = root, slug, prs, repos, bots
        self.state_dir = root / '.claude' / 'land' / slug
        self.work_dir = root / '.land' / slug

    def pr(self, ref: str) -> dict:
        for p in self.prs:
            if p['ref'] == ref:
                return p
        raise Fail(2, {'error': 'unknown-pr', 'detail': f'{ref} tidak terdaftar di {self.slug}'})

    def repo(self, key: str) -> dict:
        for r in self.repos:
            if r['key'] == key:
                return r
        raise Fail(2, {'error': 'unknown-repo', 'detail': f'{key} bukan repo produk'})


def _as_list(x) -> list:
    return x if isinstance(x, list) else []


def load_repos(root: Path) -> list[dict]:
    """Repo = toplevel git tiap apps[]/packages[]. owner/repo dari repo_url, fallback origin (nilai mentah
    konfigurasi: `remote get-url` ikut menerapkan insteadOf)."""
    ws = parse_yaml((root / 'control' / 'workspace.yaml').read_text(encoding='utf-8'))
    ws = ws if isinstance(ws, dict) else {}
    real_root = os.path.realpath(root)
    repos: dict[str, dict] = {}
    for u in _as_list(ws.get('apps')) + _as_list(ws.get('packages')):
        if not isinstance(u, dict) or not isinstance(u.get('name'), str):
            continue
        p = root / (u.get('path') if isinstance(u.get('path'), str) else u['name'])
        rc, top = git(p, 'rev-parse', '--show-toplevel') if p.is_dir() else (1, '')
        if rc or not top:
            continue
        key = os.path.relpath(os.path.realpath(top), real_root)
        repo = repos.setdefault(key, {'key': key, 'path': os.path.realpath(top), 'owner_repo': None})
        if repo['owner_repo'] is None:
            url = str(u.get('repo_url') or '')
            m = REPO_URL_RE.search(url) or REPO_URL_RE.search(git(top, 'config', '--get', 'remote.origin.url')[1])
            repo['owner_repo'] = f'{m.group(1)}/{m.group(2)}' if m else None
    return list(repos.values())


def parse_ref(item: str, repos: list[dict]) -> dict:
    """`<key>#<n>`, `<owner>/<repo>#<n>`, atau URL PR → entri PR scope."""
    m = PR_URL_RE.search(item)
    if m:
        name, n = m.group(1), m.group(2)
    else:
        name, sep, n = item.strip().rpartition('#')
        if not sep or not n.isdigit():
            raise Fail(2, {'error': 'arg', 'detail': f'PR tidak dikenal: {item}'})
    for r in repos:
        if name == r['key'] or name.lower() == (r['owner_repo'] or '').lower():
            return {'ref': f"{r['key']}#{n}", 'owner_repo': r['owner_repo'], 'number': int(n),
                    'repo_key': r['key'], 'repo_path': r['path']}
    raise Fail(2, {'error': 'unknown-repo', 'detail': f'{item} bukan repo produk',
                   'hint': 'Repo ini belum terdaftar — tambahkan lewat /add-app.'})


def _bot_authors(root: Path) -> set[str]:
    p = root / 'control' / 'sync.yaml'
    y = parse_yaml(p.read_text(encoding='utf-8')) if p.is_file() else None
    bots = y.get('bot_authors') if isinstance(y, dict) else None
    return {_bare(b) for b in _as_list(bots) if isinstance(b, str)}


def _bare(login: str) -> str:
    """GraphQL menulis `renovate`, REST dan git menulis `renovate[bot]`: akun yang sama."""
    return login.removesuffix('[bot]')


def load_scope(root, work_item: str | None, links: str | None) -> Scope:
    root = Path(os.path.realpath(root))   # absolut: `git -C <repo> worktree add` memakai path ini
    repos = load_repos(root)
    if links is not None:
        prs = [parse_ref(u, repos) for u in links.split(',') if u.strip()]
        if not prs:
            raise Fail(2, {'error': 'arg', 'detail': '--links kosong'})
        slug = '+'.join(f"pr-{p['owner_repo'].replace('/', '-')}-{p['number']}" for p in prs)
        return Scope(root, slug, prs, repos, _bot_authors(root))
    m = WORK_ITEM_RE.match(work_item or '')
    if not m:
        raise Fail(2, {'error': 'arg', 'detail': f'--work-item harus features/<fitur> atau fixes/<id>: {work_item}'})
    kind, name = m.groups()
    fname, field = ('feature.yaml', 'prs') if kind == 'features' else ('fix.yaml', 'fix_pr')
    path = root / 'control' / kind / name / fname
    if not path.is_file():
        raise Fail(1, {'error': 'manifest', 'detail': f'{path} tidak ada'})
    y = parse_yaml(path.read_text(encoding='utf-8'))
    raw = y.get(field) if isinstance(y, dict) else None
    items = [i.strip() for i in (raw if isinstance(raw, list) else [raw]) if isinstance(i, str) and i.strip()]
    prs = {}
    for item in items:
        pr = parse_ref(item, repos)
        prs.setdefault(pr['ref'], pr)
    slug = name if kind == 'features' else f'fix-{name}'
    return Scope(root, slug, list(prs.values()), repos, _bot_authors(root))


# --- baca PR ---------------------------------------------------------------------------------

def _login(a) -> str:
    return a.get('login', '') if isinstance(a, dict) else str(a or '')


def _checks(rollup: list) -> tuple[list[dict], int]:
    failed, pending = [], 0
    for c in rollup:
        if c.get('__typename') == 'StatusContext':
            name, link = c.get('context'), c.get('targetUrl')
            bad, wait = c.get('state') in STATUS_FAILED, c.get('state') in STATUS_PENDING
        else:
            name, link = c.get('name'), c.get('detailsUrl')
            bad, wait = c.get('conclusion') in RUN_FAILED, c.get('status') != 'COMPLETED'
        if bad:
            m = RUN_RE.search(link or '')
            failed.append({'name': name, 'link': link, 'run_id': m.group(1) if m else None})
        elif wait:
            pending += 1
    return failed, pending


def _comments(raw: dict, inline: list) -> list[dict]:
    out = [{'id': f"c{c.get('id')}", 'kind': 'inline', 'author': _login(c.get('user')), 'body': c.get('body') or '',
            'path': c.get('path'), 'line': c.get('line') or c.get('original_line'), 'url': c.get('html_url'),
            'created_at': c.get('created_at'), 'thread': c.get('in_reply_to_id') or c.get('id')} for c in inline]
    out += [{'id': f"i{c.get('id')}", 'kind': 'conversation', 'author': _login(c.get('author')),
             'body': c.get('body') or '', 'path': None, 'line': None, 'url': c.get('url'),
             'created_at': c.get('createdAt')} for c in _as_list(raw.get('comments'))]
    out += [{'id': f"r{c.get('id')}", 'kind': 'review', 'author': _login(c.get('author')), 'body': c['body'],
             'path': None, 'line': None, 'url': c.get('url') or raw.get('url'), 'created_at': c.get('submittedAt')}
            for c in _as_list(raw.get('reviews')) if c.get('body')]
    return out


def fetch_pr(pr: dict) -> dict:
    r, n = pr['owner_repo'], pr['number']
    raw = gh('pr', 'view', str(n), '--repo', r, '--json', PR_FIELDS) or {}
    inline = gh('api', f'repos/{r}/pulls/{n}/comments', '--paginate', '--jq', '.[]', ndjson=True)
    failed, pending = _checks(_as_list(raw.get('statusCheckRollup')))
    return {'ref': pr['ref'], 'owner_repo': r, 'number': n, 'url': raw.get('url'), 'state': raw.get('state'),
            'head_ref': raw.get('headRefName'), 'head_sha': raw.get('headRefOid'), 'base_ref': raw.get('baseRefName'),
            'mergeable': raw.get('mergeable'), 'review_decision': raw.get('reviewDecision'),
            'pending_checks': pending, 'cross_repo': bool(raw.get('isCrossRepository')),
            'failed_checks': failed, 'comments': _comments(raw, inline)}


# --- kejadian --------------------------------------------------------------------------------

def blank_event(login: str = '', need_pr: bool = False) -> dict:
    return {'kinds': [], 'need_pr': need_pr, 'all_merged': False, 'any_closed': False, 'login': login,
            'hint': None, 'detail': None, 'prs': []}


def _answered(comments: list[dict], login: str) -> list[str]:
    """Id komentar di thread inline yang komentar terakhirnya dari `login`."""
    threads: dict = {}
    for c in comments:
        if c['kind'] == 'inline':
            threads.setdefault(c['thread'], []).append(c)
    return [c['id'] for cs in threads.values() if cs[-1]['author'] == login for c in cs]


def settle(state: dict, prs: list[dict], login: str) -> None:
    """Rapikan kursor dari keadaan GitHub: state.json hilang → thread yang sudah dijawab tidak dianggap
    baru; PR dibuka lagi atau konfliknya beres → penutupan/konflik berikutnya kejadian baru."""
    if 'seen_comments' not in state:
        state['seen_comments'] = [i for p in prs for i in _answered(p['comments'], login)]
    for p in prs:
        if p['state'] == 'OPEN':
            state.get('seen_state', {}).pop(p['ref'], None)
        if p['mergeable'] == 'MERGEABLE':   # UNKNOWN = GitHub lagi menghitung ulang, bukan konflik beres
            state.get('seen_conflict', {}).pop(p['ref'], None)


def diff_event(prs: list[dict], state: dict, login: str, bots: set[str]) -> dict:
    """Kejadian = semua yang baru sejak kursor. Semua PR merge selalu kejadian, supaya penutupan yang
    terputus sesudah `ack` tidak menunggu selamanya."""
    seen_comments = set(state.get('seen_comments') or [])
    seen_checks, seen_state = state.get('seen_checks', {}), state.get('seen_state', {})
    seen_conflict = state.get('seen_conflict', {})
    all_merged = bool(prs) and all(p['state'] == 'MERGED' for p in prs)
    kinds, out = set(), []
    for p in prs:
        ref, sha = p['ref'], p['head_sha']
        comments = [{k: v for k, v in c.items() if k != 'thread'} for c in p['comments']
                    if c['id'] not in seen_comments and c['author'] != login and _bare(c['author']) not in bots]
        known = seen_checks.get(ref, {})
        old = set(known.get('names', [])) if known.get('sha') == sha else set()
        failed = [c for c in p['failed_checks'] if c['name'] not in old]
        if p['state'] != 'OPEN':   # pipeline PR yang sudah selesai tidak perlu ditangani
            failed = []
        if comments:
            kinds.add('comments')
        if failed:
            kinds.add('checks_failed')
        if p['state'] == 'MERGED' and (all_merged or seen_state.get(ref) != 'MERGED'):
            kinds.add('merged')
        if p['state'] == 'CLOSED' and seen_state.get(ref) != 'CLOSED':
            kinds.add('closed')
        if p['state'] == 'OPEN' and p['mergeable'] == 'CONFLICTING' and seen_conflict.get(ref) != sha:
            kinds.add('conflict')
        out.append({**p, 'failed_checks': failed, 'comments': comments})
    event = blank_event(login)
    event.update(kinds=[k for k in KINDS if k in kinds], all_merged=all_merged,
                 any_closed=any(p['state'] == 'CLOSED' for p in prs), prs=out)
    return event


def apply_ack(state: dict, event: dict) -> dict:
    """Hanya isi kejadian yang ditandai: yang datang sesudahnya tetap muncul di putaran berikutnya."""
    seen = list(state.get('seen_comments') or [])
    state.update(login=event.get('login', ''), seen_comments=seen)
    for p in event.get('prs', []):
        ref, sha = p['ref'], p['head_sha']
        seen += [c['id'] for c in p['comments'] if c['id'] not in seen]
        if p['failed_checks']:
            checks = state.setdefault('seen_checks', {})
            old = checks[ref]['names'] if checks.get(ref, {}).get('sha') == sha else []
            checks[ref] = {'sha': sha, 'names': old + [c['name'] for c in p['failed_checks'] if c['name'] not in old]}
        if p['state'] in ('MERGED', 'CLOSED'):
            state.setdefault('seen_state', {})[ref] = p['state']
        if p['mergeable'] == 'CONFLICTING':
            state.setdefault('seen_conflict', {})[ref] = sha
    return state


# --- state -----------------------------------------------------------------------------------

def _read_json(path: Path) -> dict:
    try:
        d = json.loads(path.read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return {}
    return d if isinstance(d, dict) else {}


def _write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f'.{path.name}.{os.getpid()}.tmp')
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    os.replace(tmp, path)


def scan_round(scope: Scope) -> dict:
    if not scope.prs:
        return blank_event(need_pr=True)
    login = _login(gh('api', 'user'))
    prs = [fetch_pr(p) for p in scope.prs]
    path = scope.state_dir / 'state.json'
    state = _read_json(path)   # dibaca sesudah gh: `attempt` boleh jalan selagi watcher hidup
    before = json.dumps(state, sort_keys=True)
    settle(state, prs, login)
    if json.dumps(state, sort_keys=True) != before:
        _write_json(path, state)
    event = diff_event(prs, state, login, scope.bots)
    if event['kinds']:
        _write_json(scope.state_dir / 'event.json', event)
    return event


# --- perintah --------------------------------------------------------------------------------

def _emit(data: dict) -> int:
    print(json.dumps(data, ensure_ascii=False, indent=2))
    return 0


def cmd_scan(args, scope: Scope) -> int:
    return _emit(scan_round(scope))


def _read_pid(path: Path) -> int | None:
    try:
        return int(path.read_text(encoding='utf-8').strip())
    except (OSError, ValueError):
        return None


def _is_watcher(pid: int) -> bool:
    """Pid di watch.pid bisa sudah dipakai proses lain: jangan bunuh yang bukan watcher."""
    try:
        r = subprocess.run(['ps', '-o', 'command=', '-p', str(pid)], capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return False
    return 'land_watch.py' in r.stdout


def _stop_old(pid_file: Path) -> None:
    pid = _read_pid(pid_file)
    if pid is None or pid == os.getpid() or not _is_watcher(pid):
        return
    try:
        os.kill(pid, signal.SIGTERM)
    except OSError:
        return
    for _ in range(50):
        if not _is_watcher(pid):
            return
        time.sleep(0.1)
    try:
        os.kill(pid, signal.SIGKILL)
    except OSError:
        pass


def _on_term(*_):
    raise Replaced


def _watch_loop(args, scope: Scope) -> dict:
    rounds, delay = 0, args.interval
    while True:
        rounds += 1
        try:
            event = scan_round(scope)
            delay = args.interval
            if event['kinds'] or event['need_pr']:
                return event
        except Fail as e:
            if e.code == 5:
                event = blank_event()
                event.update(kinds=['auth'], hint=e.payload.get('hint'), detail=e.payload.get('detail'))
                _write_json(scope.state_dir / 'event.json', event)
                return event
            if e.code != 1:
                raise
            delay = min(BACKOFF_MAX, delay * 2)
        if args.max_rounds and rounds >= args.max_rounds:
            return blank_event()
        time.sleep(delay)


def cmd_watch(args, scope: Scope) -> int:
    scope.state_dir.mkdir(parents=True, exist_ok=True)
    pid_file = scope.state_dir / 'watch.pid'
    _stop_old(pid_file)
    signal.signal(signal.SIGTERM, _on_term)
    pid_file.write_text(str(os.getpid()), encoding='utf-8')
    try:
        return _emit(_watch_loop(args, scope))
    except Replaced:
        return _emit({**blank_event(), 'replaced': True})
    finally:
        if _read_pid(pid_file) == os.getpid():
            pid_file.unlink(missing_ok=True)


def cmd_ack(args, scope: Scope) -> int:
    ev_path, st_path = scope.state_dir / 'event.json', scope.state_dir / 'state.json'
    event = _read_json(ev_path)
    if not event:
        return _emit({'acked': False})
    _write_json(st_path, apply_ack(_read_json(st_path), event))
    ev_path.unlink(missing_ok=True)
    return _emit({'acked': True})


def cmd_attempt(args, scope: Scope) -> int:
    pr = scope.pr(args.pr)
    path = scope.state_dir / 'state.json'
    state = _read_json(path)
    attempts = state.setdefault('attempts', {})
    key = f"{pr['ref']}|{args.check}"
    attempts[key] = 0 if args.reset else attempts.get(key, 0) + 1
    _write_json(path, state)
    return _emit({'count': attempts[key]})


# --- tulis ke repo dan GitHub, dengan batas ----------------------------------------------------

def _refuse(error: str, detail: str, **extra):
    raise Fail(6, {'error': error, 'detail': detail, **extra})


def _input_file(path: str) -> str:
    if not os.path.isfile(path):
        raise Fail(2, {'error': 'arg', 'detail': f'file tidak ada: {path}'})
    return path


def _worktree_dir(scope: Scope, repo: dict) -> Path:
    """Dari key, bukan basename path: `fe/app` dan `be/app` harus dapat worktree sendiri-sendiri."""
    return scope.work_dir / (repo['key'].strip('./').replace('/', '-') or os.path.basename(repo['path']))


def _check_dir(scope: Scope, d: str, repo: dict | None = None) -> str:
    """`--dir` harus worktree `.land/<slug>/<repo-slug>`; `repo` → harus worktree repo itu, supaya
    commit satu repo tidak ter-push ke branch repo lain."""
    real, base = os.path.realpath(d), os.path.realpath(scope.work_dir)
    want = os.path.realpath(_worktree_dir(scope, repo)) if repo else real
    rc, top = git(real, 'rev-parse', '--show-toplevel')
    if os.path.dirname(real) != base or real != want or rc or os.path.realpath(top) != real:
        raise Fail(2, {'error': 'dir', 'detail': f'--dir harus worktree di {want if repo else base}: {d}'})
    return real


def _fetch_ref(cwd, ref: str) -> str:
    rc, _, err = run_git(cwd, 'fetch', '--quiet', 'origin', f'refs/heads/{ref}', timeout=180)
    if rc:
        raise Fail(1, {'error': 'git', 'detail': (err.splitlines() or ['git fetch gagal'])[0]})
    return git(cwd, 'rev-parse', 'FETCH_HEAD')[1]


def _default_branch(repo_path: str, owner_repo: str) -> str | None:
    rc, out = git(repo_path, 'symbolic-ref', 'refs/remotes/origin/HEAD')
    if rc == 0 and out:
        return out.removeprefix('refs/remotes/origin/')
    return ((gh('repo', 'view', owner_repo, '--json', 'defaultBranchRef') or {}).get('defaultBranchRef') or {}).get('name')


def _push(d: str, head: str) -> None:
    rc, _, err = run_git(d, 'push', '--quiet', 'origin', f'HEAD:refs/heads/{head}', timeout=300)
    if rc:
        if 'rejected' in err or 'non-fast-forward' in err:
            _refuse('non-fast-forward', f'{head} berubah di remote')
        raise Fail(1, {'error': 'git', 'detail': (err.splitlines() or ['git push gagal'])[0]})


def _dirty(d) -> list[str]:
    changed = git(d, 'diff', 'HEAD', '--name-only')[1].splitlines()
    return sorted({*changed, *git(d, 'ls-files', '--others', '--exclude-standard')[1].splitlines()})


def _open_worktree(scope: Scope, repo: dict, ref: str, discard: bool = False) -> dict:
    """Sisa kerja sesi yang putus (`ahead`, `dirty`) tidak disentuh dan dilaporkan: `commit` memakai
    `add -A`, jadi diam-diam menyusulkannya berarti ikut ter-push tanpa pernah dilihat user."""
    repo_path = repo['path']
    d = _worktree_dir(scope, repo)
    sha = _fetch_ref(repo_path, ref)
    if (d / '.git').exists():
        if discard:
            git(d, 'reset', '--quiet', '--hard')
            git(d, 'clean', '-dfq')
        ahead, dirty = int(git(d, 'rev-list', '--count', f'{sha}..HEAD')[1] or 0), _dirty(d)
        if ahead or dirty:
            return {'dir': str(d), 'ahead': ahead, 'dirty': dirty}
        if git(d, 'checkout', '--quiet', '--detach', sha)[0]:
            _refuse('worktree-dirty', f'{d} gagal disusulkan ke {ref}')
        return {'dir': str(d), 'ahead': 0, 'dirty': []}
    d.parent.mkdir(parents=True, exist_ok=True)
    git(repo_path, 'worktree', 'prune')
    rc, _, err = run_git(repo_path, 'worktree', 'add', '--quiet', '--detach', str(d), sha)
    if rc:
        raise Fail(1, {'error': 'git', 'detail': (err.splitlines() or ['git worktree gagal'])[0]})
    return {'dir': str(d), 'ahead': 0, 'dirty': []}


def cmd_worktree(args, scope: Scope) -> int:
    if args.pr and not (args.repo_key or args.base):
        pr = scope.pr(args.pr)
        p = fetch_pr(pr)
        if p['cross_repo']:
            _refuse('fork', f"{pr['ref']} dari fork: head-ref bukan branch di origin")
        return _emit(_open_worktree(scope, scope.repo(pr['repo_key']), p['head_ref'], args.discard))
    if args.pr or not (args.repo_key and args.base):
        raise Fail(2, {'error': 'arg', 'detail': 'pakai --pr, atau --repo-key + --base'})
    return _emit(_open_worktree(scope, scope.repo(args.repo_key), args.base, args.discard))


def cmd_merge_base(args, scope: Scope) -> int:
    pr = scope.pr(args.pr)
    d = _check_dir(scope, args.dir, scope.repo(pr['repo_key']))
    _fetch_ref(d, fetch_pr(pr)['base_ref'])
    rc, out, err = run_git(d, 'merge', 'FETCH_HEAD', '--no-edit')
    conflicts = git(d, 'diff', '--name-only', '--diff-filter=U')[1].splitlines()
    if rc and not conflicts:
        _refuse('merge', err or out)
    return _emit({'clean': rc == 0, 'conflicts': conflicts})


def cmd_commit(args, scope: Scope) -> int:
    d = _check_dir(scope, args.dir)
    msg = _input_file(args.message_file)
    git(d, 'add', '-A')
    merging = git(d, 'rev-parse', '-q', '--verify', 'MERGE_HEAD')[0] == 0
    if not merging and git(d, 'diff', '--cached', '--quiet')[0] == 0:
        _refuse('no-changes', 'tidak ada perubahan')
    if merging:   # `--check` juga melapor whitespace: yang dipakai cuma penanda konflik
        rows = git(d, 'diff', '--cached', '--check')[1].splitlines()
        files = sorted({x.split(':')[0] for x in rows if x.endswith('leftover conflict marker')})
        if files:
            _refuse('conflict-markers', 'masih ada penanda konflik', files=files)
    rc, out, err = run_git(d, 'commit', '--quiet', '-F', os.path.realpath(msg), timeout=300)
    if rc:
        raise Fail(1, {'error': 'git', 'detail': err or out})
    return _emit({'sha': git(d, 'rev-parse', 'HEAD')[1]})


def cmd_push(args, scope: Scope) -> int:
    pr = scope.pr(args.pr)
    d = _check_dir(scope, args.dir, scope.repo(pr['repo_key']))
    p = fetch_pr(pr)
    head = p['head_ref']
    if p['state'] != 'OPEN':
        _refuse('not-open', f"{pr['ref']} sudah {p['state']}")
    if p['cross_repo']:
        _refuse('fork', f"{pr['ref']} dari fork: head-ref bukan branch di origin")
    if head == p['base_ref'] or head == _default_branch(pr['repo_path'], pr['owner_repo']):
        _refuse('protected-branch', f'{head} bukan branch PR yang boleh di-push')
    remote = _fetch_ref(d, head)
    if git(d, 'merge-base', '--is-ancestor', remote, 'HEAD')[0]:
        _refuse('non-fast-forward', f'{head} berubah di remote sejak worktree dibuat')
    _push(d, head)
    return _emit({'sha': git(d, 'rev-parse', 'HEAD')[1], 'branch': head})


def cmd_log(args, scope: Scope) -> int:
    pr = scope.pr(args.pr)
    c = next((c for c in fetch_pr(pr)['failed_checks'] if c['name'] == args.check), None)
    if c is None:
        _refuse('no-check', f'{args.check} tidak gagal di {pr["ref"]}')
    if not c['run_id']:
        _refuse('no-log', 'check ini log-nya tidak bisa dibaca gh', link=c['link'])
    text = gh('run', 'view', c['run_id'], '--repo', pr['owner_repo'], '--log-failed', raw=True)
    return _emit({'log': '\n'.join(text.splitlines()[-400:])})


def cmd_reply(args, scope: Scope) -> int:
    pr = scope.pr(args.pr)
    r, n = pr['owner_repo'], pr['number']
    body = _input_file(args.body_file)
    if args.to.startswith('c'):
        inline = gh('api', f'repos/{r}/pulls/{n}/comments', '--paginate', '--jq', '.[]', ndjson=True)
        c = next((c for c in inline if f"c{c.get('id')}" == args.to), None)
        if c is None:
            raise Fail(2, {'error': 'unknown-comment', 'detail': f"{args.to} bukan komentar di {pr['ref']}"})
        root = c.get('in_reply_to_id') or c.get('id')   # GitHub menolak balasan atas balasan: selalu ke akar thread
        res = gh('api', f'repos/{r}/pulls/{n}/comments/{root}/replies', '--method', 'POST', '-F', f'body=@{body}')
        return _emit({'url': (res or {}).get('html_url')})
    if args.to[:1] in ('i', 'r'):
        return _emit({'url': gh('pr', 'comment', str(n), '--repo', r, '--body-file', body, raw=True).strip()})
    raise Fail(2, {'error': 'arg', 'detail': f'--to tidak dikenal: {args.to}'})


def cmd_open_pr(args, scope: Scope) -> int:
    repo = scope.repo(args.repo_key)
    d = _check_dir(scope, args.dir, repo)
    body = _input_file(args.body_file)
    if args.head == args.base or args.head == _default_branch(repo['path'], repo['owner_repo']):
        _refuse('protected-branch', f'{args.head} tidak bisa jadi branch PR')
    if git(d, 'ls-remote', '--heads', 'origin', f'refs/heads/{args.head}')[1]:
        _refuse('branch-exists', f'{args.head} sudah ada di remote')
    _push(d, args.head)
    url = gh('pr', 'create', '--repo', repo['owner_repo'], '--head', args.head, '--base', args.base,
             '--title', args.title, '--body-file', body, raw=True).strip()
    m = re.search(r'/pull/(\d+)', url)
    return _emit({'ref': f"{repo['key']}#{m.group(1)}" if m else None, 'url': url})


def cmd_cleanup(args, scope: Scope) -> int:
    _stop_old(scope.state_dir / 'watch.pid')
    base = os.path.realpath(scope.work_dir) + os.sep
    for r in scope.repos:
        rows = git(r['path'], 'worktree', 'list', '--porcelain')[1].splitlines()
        for path in (x.removeprefix('worktree ') for x in rows if x.startswith('worktree ')):
            if os.path.realpath(path).startswith(base):
                git(r['path'], 'worktree', 'remove', path)
    shutil.rmtree(scope.work_dir, ignore_errors=True)   # worktree kotor: isinya tidak dipakai lagi
    shutil.rmtree(scope.state_dir, ignore_errors=True)
    for r in scope.repos:
        git(r['path'], 'worktree', 'prune')
    try:
        scope.work_dir.parent.rmdir()
    except OSError:
        pass
    return _emit({'cleaned': scope.slug})


# --- main ------------------------------------------------------------------------------------

def _parser(sub, name: str, fn, needs_gh: bool = True) -> argparse.ArgumentParser:
    p = sub.add_parser(name)
    p.add_argument('--root', required=True)
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument('--work-item')
    g.add_argument('--links')
    p.set_defaults(fn=fn, needs_gh=needs_gh)
    return p


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(prog='land_watch.py', description='Jaga PR satu work-item (skill land).')
    sub = ap.add_subparsers(dest='cmd', required=True)
    _parser(sub, 'scan', cmd_scan)
    w = _parser(sub, 'watch', cmd_watch)
    w.add_argument('--interval', type=int, default=120)
    w.add_argument('--max-rounds', type=int)
    _parser(sub, 'ack', cmd_ack, needs_gh=False)
    a = _parser(sub, 'attempt', cmd_attempt, needs_gh=False)
    a.add_argument('--pr', required=True)
    a.add_argument('--check', required=True)
    a.add_argument('--reset', action='store_true')
    lg = _parser(sub, 'log', cmd_log)
    lg.add_argument('--pr', required=True)
    lg.add_argument('--check', required=True)
    wt = _parser(sub, 'worktree', cmd_worktree)
    wt.add_argument('--pr')
    wt.add_argument('--repo-key')
    wt.add_argument('--base')
    wt.add_argument('--discard', action='store_true', help='buang perubahan belum di-commit di worktree')
    mb = _parser(sub, 'merge-base', cmd_merge_base)
    mb.add_argument('--pr', required=True)
    mb.add_argument('--dir', required=True)
    c = _parser(sub, 'commit', cmd_commit, needs_gh=False)
    c.add_argument('--dir', required=True)
    c.add_argument('--message-file', required=True)
    pu = _parser(sub, 'push', cmd_push)
    pu.add_argument('--pr', required=True)
    pu.add_argument('--dir', required=True)
    r = _parser(sub, 'reply', cmd_reply)
    r.add_argument('--pr', required=True)
    r.add_argument('--to', required=True)
    r.add_argument('--body-file', required=True)
    o = _parser(sub, 'open-pr', cmd_open_pr)
    o.add_argument('--repo-key', required=True)
    o.add_argument('--dir', required=True)
    o.add_argument('--head', required=True)
    o.add_argument('--base', required=True)
    o.add_argument('--title', required=True)
    o.add_argument('--body-file', required=True)
    _parser(sub, 'cleanup', cmd_cleanup, needs_gh=False)
    return ap


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    if args.needs_gh and not shutil.which('gh'):
        print(json.dumps({'error': 'gh-missing', 'hint': 'Pasang GitHub CLI (gh) lalu `gh auth login`.'}))
        return 4
    try:
        return args.fn(args, load_scope(args.root, args.work_item, args.links))
    except Fail as e:
        print(json.dumps(e.payload, ensure_ascii=False))
        return e.code
    except Exception as e:  # workspace/manifest rusak (YamlError bukan ValueError)
        print(json.dumps({'error': 'workspace', 'detail': str(e)}, ensure_ascii=False))
        return 1


if __name__ == '__main__':
    sys.exit(main())
