#!/usr/bin/env python3
"""sync_status.py — patokan sinkron control/ ↔ branch utama tiap repo (skill `sync`, context-vault).

Satu-satunya penulis control/sync.yaml. Dipakai skill sync, penjaga basi skill lain
(rules/stale-guard.md), dan hook SessionStart (hooks/sync-check.sh). Output JSON ke stdout.

  status  --root DIR [--repos k1,k2] [--format json|hook] [--fetch]
  init    --root DIR [--since YYYY-MM-DD] [--contracts a,b] [--base KEY=REF ...] [--force] [--only KEY]
  advance --root DIR --repo KEY --sha SHA
  range   --root DIR --repo KEY [--fetch]
  markers --root DIR [--feature F] [--status s1,s2]
  unmark  --root DIR --feature F

Exit: 0 ok · 1 gagal (pesan ke stderr) · 2 argumen salah · 3 init butuh --base (stdout {"need_base": [...]}).
`status` tidak pernah fetch dan tidak pernah melempar error per repo (masuk field `error`).
"""
from __future__ import annotations

import sys

sys.dont_write_bytecode = True

import argparse
import datetime
import importlib.util
import json
import os
import re
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve()
BUILD_STATUS = HERE.parents[2] / 'template' / '.claude' / 'build_status.py'
WORKERS = 8           # git paralel antar-repo: hook SessionStart harus < 1 detik untuk ~11 repo (spec D4)
NEEDS_BASELINE = ('patokan hilang dari riwayat', 'belum ada patokan')
BOT_RE = re.compile(r'(-bot|\[bot\])$')
DATE_RE = re.compile(r'^\d{4}-\d{2}-\d{2}$')
HEADER = ('# control/sync.yaml — patokan sinkron control/ ↔ branch utama tiap repo.\n'
          '# Ditulis skill sync (sync_status.py). Boleh edit tangan: bot_authors, contracts_repos.\n')

_bs = None


def _build_status():
    global _bs
    if _bs is None:
        spec = importlib.util.spec_from_file_location('cv_build_status', BUILD_STATUS)
        _bs = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_bs)
    return _bs


def parse_yaml(text: str):
    return _build_status().parse_yaml(text)


def git(cwd, *args) -> tuple[int, str]:
    """(exit code, stdout di-strip). Timeout/OSError → (1, '')."""
    try:
        r = subprocess.run(['git', '-C', str(cwd), *args], capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return 1, ''
    return r.returncode, r.stdout.strip()


def today() -> str:
    return datetime.date.today().isoformat()


# --- workspace & sync.yaml -------------------------------------------------------------------

def _as_list(x) -> list:
    return x if isinstance(x, list) else []


def load_workspace(root: Path) -> list[dict]:
    """Repo = toplevel git tiap apps[]/packages[], dikelompokkan per toplevel, urut key.
    Tiap Repo juga membawa `units` (entri workspace mentah: name/path/repo_url/…) untuk pemakai lain
    (prs.py); field itu tidak ikut di output status."""
    ws = parse_yaml((root / 'control' / 'workspace.yaml').read_text(encoding='utf-8'))
    ws = ws if isinstance(ws, dict) else {}
    real_root = os.path.realpath(root)
    repos: dict[str, dict] = {}
    units = [u for u in _as_list(ws.get('apps')) + _as_list(ws.get('packages'))
             if isinstance(u, dict) and isinstance(u.get('name'), str)]
    rels = [u.get('path') if isinstance(u.get('path'), str) else u['name'] for u in units]

    def toplevel(rel):
        p = root / rel
        return git(p, 'rev-parse', '--show-toplevel') if p.is_dir() else (1, '')

    with ThreadPoolExecutor(WORKERS) as ex:
        tops = list(ex.map(toplevel, rels))
    for unit, rel, (rc, top) in zip(units, rels, tops):
        p = root / rel
        if rc == 0 and top:
            key = os.path.relpath(os.path.realpath(top), real_root)
            path, error = os.path.realpath(top), None
        else:
            key = os.path.normpath(rel)
            path, error = str(p.resolve()), 'bukan repo git'
        r = repos.setdefault(key, {'key': key, 'path': path, 'apps': [], 'units': [], 'error': error})
        r['apps'].append(unit['name'])
        r['units'].append(unit)
    return [repos[k] for k in sorted(repos)]


def read_sync(root: Path) -> dict | None:
    p = root / 'control' / 'sync.yaml'
    if not p.is_file():
        return None
    data = parse_yaml(p.read_text(encoding='utf-8'))
    data = data if isinstance(data, dict) else {}
    data['bot_authors'] = [x for x in _as_list(data.get('bot_authors')) if isinstance(x, str)]
    data['contracts_repos'] = [x for x in _as_list(data.get('contracts_repos')) if isinstance(x, str)]
    data['repos'] = {k: v for k, v in (data.get('repos') or {}).items() if isinstance(v, dict)} \
        if isinstance(data.get('repos'), dict) else {}
    return data


def _scalar(s: str, always_quote: bool = False) -> str:
    s = str(s)
    if always_quote or s == '' or re.search(r'[\[\]:#\s,{}"\'&*!|>%@`]', s):
        return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'
    return s


def _flow(items) -> str:
    return '[' + ', '.join(_scalar(x) for x in items) + ']'


def write_sync(root: Path, data: dict) -> None:
    lines = [HEADER.rstrip('\n'),
             f"bot_authors: {_flow(data.get('bot_authors', []))}",
             f"contracts_repos: {_flow(data.get('contracts_repos', []))}"]
    repos = data.get('repos', {})
    if not repos:
        lines.append('repos: {}')
    else:
        lines.append('repos:')
        for key in sorted(repos):
            e = repos[key]
            lines += [f'  {_scalar(key)}:',
                      f"    apps: {_flow(e.get('apps', []))}",
                      f"    base_ref: {_scalar(e['base_ref'])}",
                      f"    synced_sha: {_scalar(e['synced_sha'])}",
                      f"    synced_at: {_scalar(e['synced_at'], always_quote=True)}"]
    p = root / 'control' / 'sync.yaml'
    tmp = p.with_name('.sync.yaml.tmp')
    tmp.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    os.replace(tmp, p)


# --- status ----------------------------------------------------------------------------------

def _resolve(path: str, ref: str) -> str | None:
    rc, sha = git(path, 'rev-parse', '--verify', '--quiet', f'{ref}^{{commit}}')
    return sha if rc == 0 and sha else None


def _is_ancestor(path: str, a: str, b: str) -> bool:
    return git(path, 'merge-base', '--is-ancestor', a, b)[0] == 0


def repo_status(repo: dict, entry: dict | None, bots: set[str]) -> dict:
    out = {'key': repo['key'], 'path': repo['path'], 'apps': repo['apps'], 'base_ref': None,
           'synced_sha': None, 'head_sha': None, 'behind': None, 'behind_all': None,
           'synced_at': None, 'error': repo['error']}
    if out['error']:
        return out
    if not entry:
        out['error'] = 'belum ada patokan'
        return out
    base, synced = entry.get('base_ref'), entry.get('synced_sha')
    out.update(base_ref=base, synced_sha=synced, synced_at=entry.get('synced_at'))
    if not isinstance(base, str) or not isinstance(synced, str):
        out['error'] = 'entri sync.yaml tidak lengkap'
        return out
    head = _resolve(repo['path'], base)
    if not head:
        out['error'] = f'ref {base} tidak ada'
        return out
    out['head_sha'] = head
    if not _is_ancestor(repo['path'], synced, head):
        out['error'] = 'patokan hilang dari riwayat'
        return out
    # satu panggilan: tiap baris = satu commit first-parent (prefix '@' agar author kosong tetap terhitung)
    rc, log = git(repo['path'], 'log', '--first-parent', '--format=@%an', f'{synced}..{head}')
    if rc:
        out['error'] = 'gagal menghitung selisih'
        return out
    authors = [a[1:] for a in log.splitlines() if a.startswith('@')]
    out['behind_all'] = len(authors)
    out['behind'] = sum(1 for a in authors if a not in bots)
    return out


def fetch_repo(path: str) -> str | None:
    """`git fetch --quiet origin`; None = sukses, selain itu baris pertama error."""
    try:
        r = subprocess.run(['git', '-C', path, 'fetch', '--quiet', 'origin'], capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.SubprocessError) as e:
        return f'git fetch gagal: {e}'
    return (r.stderr.strip().splitlines() or ['git fetch gagal'])[0] if r.returncode else None


def compute_status(root: Path, only: list[str] | None = None, fetch: bool = False) -> dict:
    res = {'initialized': False, 'reason': None, 'repos': [], 'stale': [], 'needs_baseline': []}
    if not (root / 'control' / 'workspace.yaml').is_file():
        res['reason'] = 'bukan produk context-vault'
        return res
    sync = read_sync(root)
    if sync is None:
        res['reason'] = 'belum pernah sinkron'
        return res
    res['initialized'] = True
    bots = set(sync['bot_authors'])
    repos = [r for r in load_workspace(root)
             if not only or r['key'] in only or set(r['apps']) & set(only)]
    with ThreadPoolExecutor(WORKERS) as ex:
        fetched = {}
        if fetch:
            todo = [r for r in repos if not r['error'] and r['key'] in sync['repos']]
            fetched = dict(zip((r['key'] for r in todo), ex.map(lambda r: fetch_repo(r['path']), todo)))
        res['repos'] = list(ex.map(lambda r: repo_status(r, sync['repos'].get(r['key']), bots), repos))
    for r in res['repos']:
        if fetch:
            r['fetch_error'] = fetched.get(r['key'])
    res['stale'] = [r['key'] for r in res['repos'] if r['behind']]
    res['needs_baseline'] = [r['key'] for r in res['repos'] if r['error'] in NEEDS_BASELINE]
    return res


def hook_text(res: dict) -> str | None:
    stale = [r for r in res['repos'] if r['behind']]
    rebase = res.get('needs_baseline') or []
    if not stale and not rebase:
        return None
    parts = []
    if stale:
        total = sum(r['behind'] for r in stale)
        since = min((str(r['synced_at']) for r in stale if r['synced_at']), default='?')
        per = ', '.join(f"{r['key']} ({r['behind']})" for r in stale)
        parts.append(f'control/ ketinggalan {total} commit (di luar bot) sejak {since}: {per}.')
    if rebase:
        parts.append(f"Repo yang patokan sinkronnya perlu diulang (branch utama di-force-push / app baru): {', '.join(rebase)}.")
    return ('[context-vault] ' + ' '.join(parts) +
            ' Jangan sinkron sendiri — skill feature/plan/fix/tweak/review-pr akan menawarkan /sync dulu.')


def _csv(s: str | None) -> list[str]:
    return [x.strip() for x in (s or '').split(',') if x.strip()]


def cmd_status(args) -> int:
    root = Path(args.root)
    try:
        res = compute_status(root, _csv(args.repos) or None, fetch=args.fetch)
    except Exception as e:  # workspace/sync.yaml rusak — jangan pernah crash (hook/penjaga)
        if args.format == 'hook':
            return 1
        res = {'initialized': False, 'reason': f'gagal membaca control/: {e}', 'repos': [], 'stale': [],
               'needs_baseline': []}
    if args.format == 'hook':
        text = hook_text(res)
        if text:
            print(json.dumps({'hookSpecificOutput': {'hookEventName': 'SessionStart',
                                                     'additionalContext': text}}, ensure_ascii=False))
        return 0
    print(json.dumps(res, ensure_ascii=False, indent=2))
    return 0


# --- init ------------------------------------------------------------------------------------

def _start_sha(path: str, base: str, since: str | None) -> str | None:
    if not since:
        return _resolve(path, base)
    rc, sha = git(path, 'rev-list', '-1', f'--before={since} 00:00', base)
    if rc == 0 and sha:
        return sha
    rc, roots = git(path, 'rev-list', '--max-parents=0', base)
    return roots.splitlines()[-1] if rc == 0 and roots else None


def _detect_bots(repos: list[dict], bases: dict[str, str]) -> list[str]:
    found = set()
    for r in repos:
        if r['key'] in bases:
            rc, names = git(r['path'], 'log', '-500', '--format=%an', bases[r['key']])
            found |= {n for n in names.splitlines() if rc == 0 and BOT_RE.search(n)}
    return sorted(found)


def cmd_init(args) -> int:
    root = Path(args.root)
    if not (root / 'control' / 'workspace.yaml').is_file():
        print('bukan produk context-vault (control/workspace.yaml tidak ada)', file=sys.stderr)
        return 1
    if args.since and not DATE_RE.match(args.since):
        print(f'--since harus YYYY-MM-DD: {args.since}', file=sys.stderr)
        return 2
    if args.only and not args.force:
        print('--only wajib bersama --force', file=sys.stderr)
        return 2
    overrides = {}
    for b in args.base or []:
        k, sep, v = b.partition('=')
        if not sep or not k or not v:
            print(f'--base harus KEY=REF: {b}', file=sys.stderr)
            return 2
        overrides[k] = v
    old = read_sync(root)
    if old is not None and not args.force:
        print('control/sync.yaml sudah ada — pakai --force untuk baseline ulang', file=sys.stderr)
        return 1
    repos = [r for r in load_workspace(root) if not r['error']]
    if args.only:
        repos = [r for r in repos if r['key'] == args.only or args.only in r['apps']]
        if not repos:
            print(f'repo tidak dikenal (atau bukan repo git): {args.only}', file=sys.stderr)
            return 1
    bases, need = {}, []
    for r in repos:
        base = overrides.get(r['key']) or next((overrides[a] for a in r['apps'] if a in overrides), None)
        if not base:
            rc, base = git(r['path'], 'symbolic-ref', '--short', 'refs/remotes/origin/HEAD')
            base = base if rc == 0 and base else None
        if base and _resolve(r['path'], base):
            bases[r['key']] = base
        else:
            need.append(r['key'])
    if need:
        print(json.dumps({'need_base': need}, ensure_ascii=False))
        return 3
    entries = {}
    for r in repos:
        sha = _start_sha(r['path'], bases[r['key']], args.since)
        if not sha:
            print(f'gagal menentukan patokan {r["key"]}', file=sys.stderr)
            return 1
        entries[r['key']] = {'apps': r['apps'], 'base_ref': bases[r['key']], 'synced_sha': sha,
                             'synced_at': today()}
    if args.only:
        data = old
        data['repos'].update(entries)
    else:
        prev = old or {'bot_authors': [], 'contracts_repos': []}
        data = {'bot_authors': sorted(set(prev['bot_authors']) | set(_detect_bots(repos, bases))),
                'contracts_repos': _csv(args.contracts) if args.contracts is not None else prev['contracts_repos'],
                'repos': entries}
    write_sync(root, data)
    print(json.dumps(compute_status(root), ensure_ascii=False, indent=2))
    return 0


# --- advance ---------------------------------------------------------------------------------

def cmd_advance(args) -> int:
    root = Path(args.root)
    sync = read_sync(root) if (root / 'control' / 'workspace.yaml').is_file() else None
    if sync is None:
        print('belum pernah sinkron (control/sync.yaml tidak ada)', file=sys.stderr)
        return 1
    repo = next((r for r in load_workspace(root) if r['key'] == args.repo), None)
    entry = sync['repos'].get(args.repo)
    if not repo or repo['error'] or not entry:
        print(f'repo tanpa patokan: {args.repo}', file=sys.stderr)
        return 1
    sha = _resolve(repo['path'], args.sha)
    head = _resolve(repo['path'], str(entry.get('base_ref')))
    if not sha or not head:
        print(f'sha/base_ref tidak dikenal: {args.sha}', file=sys.stderr)
        return 1
    if not _is_ancestor(repo['path'], str(entry.get('synced_sha')), sha) or not _is_ancestor(repo['path'], sha, head):
        print(f'{args.sha} bukan keturunan patokan atau bukan leluhur {entry.get("base_ref")}', file=sys.stderr)
        return 1
    entry.update(synced_sha=sha, synced_at=today())
    write_sync(root, sync)
    print(json.dumps({'repo': args.repo, 'synced_sha': sha, 'synced_at': entry['synced_at']}))
    return 0


# --- range -----------------------------------------------------------------------------------

PR_RES = (re.compile(r'\(#(\d+)\)\s*$'), re.compile(r'^Merge pull request #(\d+)'))
PR_URL_RE = re.compile(r'/([^/\s]+)/pull/(\d+)')


def _pr_of(subject: str) -> int | None:
    for rx in PR_RES:
        m = rx.search(subject)
        if m:
            return int(m.group(1))
    return None


def own_prs(root: Path, repo: dict) -> set[int]:
    """Nomor PR repo ini yang tercatat di features/*/feature.yaml `prs` atau fixes/*/fix.yaml `fix_pr`
    (format "<key>#<n>" atau URL …/<nama-repo>/pull/<n>)."""
    names = {os.path.basename(repo['path']), os.path.basename(repo['key'])}
    out = set()
    for pattern, field in (('features/*/feature.yaml', 'prs'), ('fixes/*/fix.yaml', 'fix_pr')):
        for f in sorted((root / 'control').glob(pattern)):
            try:
                y = parse_yaml(f.read_text(encoding='utf-8'))
            except Exception:
                continue
            v = y.get(field) if isinstance(y, dict) else None
            for item in (v if isinstance(v, list) else [v]):
                if not isinstance(item, str):
                    continue
                k, sep, n = item.strip().rpartition('#')
                if sep and k == repo['key'] and n.isdigit():
                    out.add(int(n))
                m = PR_URL_RE.search(item)
                if m and m.group(1).removesuffix('.git') in names:
                    out.add(int(m.group(2)))
    return out


def cmd_range(args) -> int:
    root = Path(args.root)
    sync = read_sync(root) if (root / 'control' / 'workspace.yaml').is_file() else None
    if sync is None:
        print('belum pernah sinkron (control/sync.yaml tidak ada)', file=sys.stderr)
        return 1
    repo = next((r for r in load_workspace(root) if r['key'] == args.repo), None)
    entry = sync['repos'].get(args.repo)
    if not repo or repo['error'] or not entry:
        print(f'repo tanpa patokan: {args.repo}', file=sys.stderr)
        return 1
    fetch_error = fetch_repo(repo['path']) if args.fetch else None
    st = repo_status(repo, entry, set(sync['bot_authors']))
    if st['error']:
        print(f"{args.repo}: {st['error']}", file=sys.stderr)
        return 1
    bots, own = set(sync['bot_authors']), own_prs(root, repo)
    rc, log = git(repo['path'], 'log', '--first-parent', '--reverse', '--format=%H%x1f%an%x1f%ad%x1f%s',
                  '--date=short', f"{st['synced_sha']}..{st['head_sha']}")
    if rc:
        print(f'{args.repo}: git log gagal', file=sys.stderr)
        return 1
    commits = []
    for line in log.splitlines():
        sha, author, date, subject = (line.split('\x1f') + ['', '', ''])[:4]
        pr = _pr_of(subject)
        commits.append({'sha': sha, 'short': sha[:7], 'author': author, 'date': date, 'subject': subject,
                        'pr': pr, 'bot': author in bots, 'own': pr is not None and pr in own})
    print(json.dumps({'repo': args.repo, 'from': st['synced_sha'], 'to': st['head_sha'],
                      'fetch_error': fetch_error, 'commits': commits}, ensure_ascii=False, indent=2))
    return 0


# --- penanda fitur ---------------------------------------------------------------------------

MD_MARK = re.compile(r'<!-- feature:([a-z0-9][a-z0-9-]*) -->')
YAML_MARK = re.compile(r'#\s*feature:([a-z0-9][a-z0-9-]*)\s*$')
# Baris versi master yang ditulis sync di samping baris ber-penanda fitur aktif (bentrok, D25).
# Dibereskan ship sebelum unmark; unmark sendiri tidak menyentuhnya.
MD_CONFLICT = re.compile(r'<!-- sync-conflict:([a-z0-9][a-z0-9-]*) [0-9a-f]{7,40} \d{4}-\d{2}-\d{2} -->')
YAML_CONFLICT = re.compile(r'#\s*sync-conflict:([a-z0-9][a-z0-9-]*) [0-9a-f]{7,40} \d{4}-\d{2}-\d{2}[ \t]*$')


def _knowledge_files(root: Path) -> list[Path]:
    ctl = root / 'control'
    out = []
    for f in sorted(ctl.rglob('*')):
        rel = f.relative_to(ctl).parts
        if f.is_file() and f.suffix in ('.md', '.yaml') and rel[0] not in ('features', 'fixes'):
            out.append(f)
    return out


def _feature_status(root: Path, feature: str) -> str | None:
    try:
        y = parse_yaml((root / 'control' / 'features' / feature / 'feature.yaml').read_text(encoding='utf-8'))
    except Exception:
        return None
    return y.get('status') if isinstance(y, dict) and isinstance(y.get('status'), str) else None


def cmd_markers(args) -> int:
    root = Path(args.root)
    wanted = set(_csv(args.status))
    statuses: dict[str, str | None] = {}
    out = []
    for f in _knowledge_files(root):
        rxs = (('feature', MD_MARK), ('conflict', MD_CONFLICT)) if f.suffix == '.md' else \
              (('feature', YAML_MARK), ('conflict', YAML_CONFLICT))
        try:
            lines = f.read_text(encoding='utf-8').splitlines()
        except (OSError, UnicodeDecodeError):
            continue
        for n, line in enumerate(lines, 1):
            for kind, rx, m in ((k, rx, m) for k, rx in rxs for m in rx.finditer(line)):
                feat = m.group(1)
                if args.feature and feat != args.feature:
                    continue
                if feat not in statuses:
                    statuses[feat] = _feature_status(root, feat)
                if wanted and statuses[feat] not in wanted:
                    continue
                out.append({'file': f.relative_to(root).as_posix(), 'line': n, 'feature': feat, 'kind': kind,
                            'status': statuses[feat], 'text': rx.sub('', line).rstrip()})
    print(json.dumps(out, ensure_ascii=False, indent=2))
    return 0


def cmd_unmark(args) -> int:
    root = Path(args.root)
    f_esc = re.escape(args.feature)
    md = re.compile(r' ?<!-- feature:' + f_esc + r' -->')
    ym = re.compile(r' ?#[ \t]*feature:' + f_esc + r'[ \t]*$', re.M)   # [ \t], bukan \s: jangan makan newline
    removed = 0
    for f in _knowledge_files(root):
        try:
            text = f.read_text(encoding='utf-8')
        except (OSError, UnicodeDecodeError):
            continue
        new, n = (md if f.suffix == '.md' else ym).subn('', text)
        if n:
            f.write_text(new, encoding='utf-8')
            removed += n
    print(json.dumps({'removed': removed}))
    return 0


# --- main ------------------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(prog='sync_status.py', description='Patokan sinkron control/ (skill sync).')
    sub = ap.add_subparsers(dest='cmd', required=True)
    s = sub.add_parser('status')
    s.add_argument('--root', required=True)
    s.add_argument('--repos')
    s.add_argument('--format', choices=('json', 'hook'), default='json')
    s.add_argument('--fetch', action='store_true', help='git fetch tiap repo berpatokan dulu (skill sync; hook TIDAK)')
    s.set_defaults(fn=cmd_status)
    i = sub.add_parser('init')
    i.add_argument('--root', required=True)
    i.add_argument('--since')
    i.add_argument('--contracts')
    i.add_argument('--base', action='append')
    i.add_argument('--force', action='store_true')
    i.add_argument('--only')
    i.set_defaults(fn=cmd_init)
    a = sub.add_parser('advance')
    a.add_argument('--root', required=True)
    a.add_argument('--repo', required=True)
    a.add_argument('--sha', required=True)
    a.set_defaults(fn=cmd_advance)
    r = sub.add_parser('range')
    r.add_argument('--root', required=True)
    r.add_argument('--repo', required=True)
    r.add_argument('--fetch', action='store_true')
    r.set_defaults(fn=cmd_range)
    m = sub.add_parser('markers')
    m.add_argument('--root', required=True)
    m.add_argument('--feature')
    m.add_argument('--status')
    m.set_defaults(fn=cmd_markers)
    u = sub.add_parser('unmark')
    u.add_argument('--root', required=True)
    u.add_argument('--feature', required=True)
    u.set_defaults(fn=cmd_unmark)
    return ap


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    return args.fn(args)


if __name__ == '__main__':
    sys.exit(main())
