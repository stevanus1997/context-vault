#!/usr/bin/env python3
"""prs.py — daftar & detail PR rekan lewat `gh` (skill `review-pr`, context-vault). Read-only.

  inbox    --root DIR                                  PR yang minta review user, di repo produk saja
  view     --root DIR --pr OWNER/REPO#N|URL|KEY#N      detail satu PR (+ tiket)
  siblings --root DIR --ticket T --exclude OWNER/REPO#N  PR terbuka lain dengan tiket sama di repo produk

Output JSON ke stdout. Exit: 0 ok · 1 error gh lain · 2 argumen salah · 4 gh tak ada · 5 gh akun/izin
(404/403/401/Could not resolve → kemungkinan akun gh aktif bukan akun kerja).
"""
from __future__ import annotations

import sys

sys.dont_write_bytecode = True

import argparse
import importlib.util
import json
import re
import shutil
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve()
SYNC_STATUS = HERE.parents[1] / 'sync' / 'sync_status.py'
TICKET_RE = re.compile(r'\b[A-Z][A-Z0-9]+-\d+\b')
REPO_URL_RE = re.compile(r'github\.com[/:]([^/\s]+)/([^/\s]+?)(?:\.git)?/?$')
PR_URL_RE = re.compile(r'github\.com/([^/\s]+/[^/\s]+)/pull/(\d+)')
AUTH_MARKERS = ('Could not resolve', '404', '403', 'HTTP 401')
HINT = 'Akun gh aktif mungkin bukan akun kerja — coba `gh auth switch`.'
PR_FIELDS = 'number,title,author,url,headRefName,headRefOid,baseRefName'


class GhError(Exception):
    def __init__(self, code: int, payload: dict):
        super().__init__(payload.get('detail', ''))
        self.code, self.payload = code, payload


def _sync_status():
    spec = importlib.util.spec_from_file_location('cv_sync_status', SYNC_STATUS)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def slug(key: str) -> str:
    """Nama file laporan per repo: `.` → `root`, `/` → `-`."""
    return 'root' if key == '.' else key.replace('/', '-')


def load_repos(root: Path) -> dict[str, str]:
    """owner/repo (huruf kecil) → repo_key, dari repo_url app/package di workspace.yaml."""
    out = {}
    for repo in _sync_status().load_workspace(root):
        for unit in repo['units']:
            m = REPO_URL_RE.search(str(unit.get('repo_url') or ''))
            if m:
                out.setdefault(f'{m.group(1)}/{m.group(2)}'.lower(), repo['key'])
    return out


def gh(*args) -> object:
    try:
        r = subprocess.run(['gh', *args], capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.SubprocessError) as e:
        raise GhError(1, {'error': 'gh', 'detail': str(e)}) from None
    if r.returncode:
        detail = (r.stderr.strip().splitlines() or [f'gh exit {r.returncode}'])[0]
        if any(m in r.stderr for m in AUTH_MARKERS):
            raise GhError(5, {'error': 'gh-auth', 'detail': detail, 'hint': HINT})
        raise GhError(1, {'error': 'gh', 'detail': detail})
    try:
        return json.loads(r.stdout or 'null')
    except json.JSONDecodeError:
        raise GhError(1, {'error': 'gh', 'detail': 'output gh bukan JSON'}) from None


def ticket_of(*texts) -> str | None:
    for t in texts:
        m = TICKET_RE.search(t or '')
        if m:
            return m.group(0)
    return None


def _login(a) -> str:
    return a.get('login', '') if isinstance(a, dict) else str(a or '')


def _view_shape(pr: dict, owner_repo: str, repos: dict[str, str]) -> dict:
    return {'repo_key': repos.get(owner_repo.lower()), 'owner_repo': owner_repo, 'number': pr.get('number'),
            'title': pr.get('title'), 'author': _login(pr.get('author')), 'url': pr.get('url'),
            'head_ref': pr.get('headRefName'), 'head_sha': pr.get('headRefOid'), 'base_ref': pr.get('baseRefName'),
            'ticket': ticket_of(pr.get('headRefName'), pr.get('title'))}


def parse_pr(arg: str, repos: dict[str, str]) -> tuple[str, int] | None:
    m = PR_URL_RE.search(arg)
    if m:
        return m.group(1), int(m.group(2))
    ref, sep, n = arg.strip().rpartition('#')
    if not sep or not n.isdigit() or not ref:
        return None
    if '/' in ref and ref.lower() in repos:
        return ref, int(n)
    for owner_repo, key in repos.items():
        if key == ref:
            return owner_repo, int(n)
    return (ref, int(n)) if ref.count('/') == 1 else None


def cmd_inbox(args, repos) -> object:
    found = gh('search', 'prs', '--review-requested=@me', '--state=open', '--limit', '100',
               '--json', 'number,title,author,createdAt,url,repository') or []
    out = []
    for pr in found:
        owner_repo = (pr.get('repository') or {}).get('nameWithOwner', '')
        key = repos.get(owner_repo.lower())
        if key is None:
            continue
        out.append({'repo_key': key, 'owner_repo': owner_repo, 'number': pr.get('number'),
                    'title': pr.get('title'), 'author': _login(pr.get('author')),
                    'created': str(pr.get('createdAt') or '')[:10], 'url': pr.get('url'),
                    'ticket': ticket_of(pr.get('title')),
                    'reviewed_local': (Path(args.root) / '.claude' / 'review' /
                                       f'{slug(key)}-{pr.get("number")}.html').is_file()})
    return sorted(out, key=lambda x: (x['created'], x['owner_repo'], x['number'] or 0))


def cmd_view(args, repos) -> object:
    ref = parse_pr(args.pr, repos)
    if not ref:
        raise GhError(2, {'error': 'arg', 'detail': f'--pr tidak dikenal: {args.pr} (pakai OWNER/REPO#N, URL, atau repo-key#N)'})
    owner_repo, n = ref
    pr = gh('pr', 'view', str(n), '--repo', owner_repo, '--json', PR_FIELDS) or {}
    return _view_shape(pr, owner_repo, repos)


def cmd_siblings(args, repos) -> object:
    exclude = parse_pr(args.exclude, repos) if args.exclude else None
    exclude = (exclude[0].lower(), exclude[1]) if exclude else None
    rx = re.compile(r'\b' + re.escape(args.ticket) + r'\b')
    out = []
    for owner_repo in sorted(repos):
        for pr in gh('pr', 'list', '--repo', owner_repo, '--state', 'open', '--search', args.ticket,
                     '--json', PR_FIELDS) or []:
            if exclude == (owner_repo, pr.get('number')):
                continue
            if rx.search(pr.get('headRefName') or '') or rx.search(pr.get('title') or ''):
                out.append(_view_shape(pr, owner_repo, repos))
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog='prs.py', description='PR rekan lewat gh (skill review-pr).')
    sub = ap.add_subparsers(dest='cmd', required=True)
    for name in ('inbox', 'view', 'siblings'):
        p = sub.add_parser(name)
        p.add_argument('--root', required=True)
        if name == 'view':
            p.add_argument('--pr', required=True)
        if name == 'siblings':
            p.add_argument('--ticket', required=True)
            p.add_argument('--exclude')
    args = ap.parse_args(argv)
    if not shutil.which('gh'):
        print(json.dumps({'error': 'gh-missing', 'hint': 'Pasang GitHub CLI (gh) lalu `gh auth login`.'}))
        return 4
    try:
        repos = load_repos(Path(args.root))
        res = {'inbox': cmd_inbox, 'view': cmd_view, 'siblings': cmd_siblings}[args.cmd](args, repos)
    except GhError as e:
        print(json.dumps(e.payload, ensure_ascii=False))
        return e.code
    except Exception as e:  # workspace.yaml absen/rusak (YamlError bukan ValueError)
        print(json.dumps({'error': 'workspace', 'detail': str(e)}, ensure_ascii=False))
        return 1
    print(json.dumps(res, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    sys.exit(main())
