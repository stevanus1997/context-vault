#!/usr/bin/env python3
"""measure-build-context.py — ukur context & kualitas sesi `/context-vault:build` dari transcript Claude Code.

Membaca file transcript `.jsonl` (biasanya `~/.claude/projects/<produk>/*.jsonl`), memilih sesi build,
lalu menghitung per sesi: context saat dispatch implementer pertama, median pertumbuhan context antar
dispatch implementer, atribusi hasil tool per kelas, dan sinyal kualitas (ronde review, NEEDS_CONTEXT,
BLOCKED, item ⚠️). Read-only, Python 3 stdlib saja.
Spec: docs/superpowers/specs/2026-10-20-build-lean-controller-design.md §4.10.

Pakai: python3 tools/measure-build-context.py [--json] PATH...
  PATH = file .jsonl atau direktori (diambil *.jsonl langsung di dalamnya, non-rekursif — subagents/ tak ikut).
"""
from __future__ import annotations

import argparse
import json
import re
import statistics
import sys
from pathlib import Path

CLASSES = ('skillref', 'state', 'code', 'agent', 'other')
STATE_RE = re.compile(r'tasks\.yaml|feature\.yaml|last-run|gates\.yaml|carry|_rules|workspace\.yaml|conventions|'
                      r'invariants|plans/|_shared|fanout|report\.md|review-r|notify|memory/|build_status\.py')
CODE_RE = re.compile(r'/src/|migrations|mockups/|\.tsx?\b|\.sql\b|\.html\b|\.css\b|\.go\b|\.py\b|-brief\.md|'
                     r'/schema/|package\.json')
IMPL_RE = re.compile(r'task-([A-Za-z0-9_.-]+)-brief\.md')
AGENT_ID_RE = re.compile(r'agentId:\s*([A-Za-z0-9_-]+)')
AGENT_MSG_RE = re.compile(r'<agent-message from="([^"]+)">')
NEEDS_CONTEXT_RE = re.compile(r'(?m)^\s*(?:Status:\s*)?NEEDS_CONTEXT\b')
BLOCKED_RE = re.compile(r'(?m)^\s*(?:Status:\s*)?BLOCKED\b')
WARN_COUNT_RE = re.compile(r'(?m)^\s*⚠️:\s*(\d+)')


def classify(tool_name: str, tool_input: dict) -> str:
    """Kelas atribusi hasil tool: skillref | state | code | agent | other (diuji berurutan)."""
    if tool_name == 'Agent':
        return 'agent'
    s = json.dumps(tool_input, ensure_ascii=False)
    if 'skills/build/' in s or 'SKILL.md' in s:
        return 'skillref'
    if STATE_RE.search(s):
        return 'state'
    if CODE_RE.search(s):
        return 'code'
    return 'other'


def _records(path: Path):
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            for line in f:
                try:
                    r = json.loads(line)
                except ValueError:
                    continue                      # baris rusak dilewati
                if isinstance(r, dict):
                    yield r
    except OSError:
        return


def _text(content) -> str:
    """Isi pesan/tool_result → teks (string, atau gabungan blok type=text)."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return '\n'.join(b.get('text', '') for b in content
                         if isinstance(b, dict) and b.get('type') == 'text' and isinstance(b.get('text'), str))
    return ''


def _ctx(usage) -> int:
    if not isinstance(usage, dict):
        return 0
    return sum(int(usage.get(k) or 0) for k in ('input_tokens', 'cache_read_input_tokens', 'cache_creation_input_tokens'))


def _dispatch_kind(tool_input: dict):
    """(kind, task_id) untuk tool_use Agent: brief_writer | reviewer | implementer | None."""
    if tool_input.get('subagent_type') == 'context-vault:brief-writer':
        return 'brief_writer', None
    prompt = tool_input.get('prompt') if isinstance(tool_input.get('prompt'), str) else ''
    if '.diff' in prompt and '-brief.md' in prompt:
        return 'reviewer', None
    m = IMPL_RE.search(prompt)
    if m and '-report.md' in prompt:
        return 'implementer', m.group(1)
    return None, None


def _is_build(records: list) -> bool:
    for r in records:
        msg = r.get('message') if isinstance(r.get('message'), dict) else {}
        content = msg.get('content')
        if r.get('type') == 'user' and '<command-name>/context-vault:build' in _text(content):
            return True
        if r.get('type') == 'assistant' and isinstance(content, list):
            for b in content:
                if (isinstance(b, dict) and b.get('type') == 'tool_use' and b.get('name') == 'Skill'
                        and _dict(b.get('input')).get('skill') == 'context-vault:build'):
                    return True
    return False


def _dict(x) -> dict:
    return x if isinstance(x, dict) else {}


def analyze_session(path: Path) -> dict | None:
    """Metrik satu transcript; None kalau bukan sesi build."""
    records = list(_records(Path(path)))
    if not _is_build(records):
        return None
    uses = {}                                     # tool_use_id → {name, input, ctx, cls, kind, task}
    dispatches = []                               # urut: {kind, task, ctx, result}
    by_agent = {}                                 # agentId → dispatch
    attribution = dict.fromkeys(CLASSES, 0)
    for r in records:
        msg = _dict(r.get('message'))
        content = msg.get('content')
        if r.get('type') == 'assistant' and isinstance(content, list):
            for b in content:
                if not (isinstance(b, dict) and b.get('type') == 'tool_use'):
                    continue
                name, inp = b.get('name') or '', _dict(b.get('input'))
                use = {'cls': classify(name, inp), 'dispatch': None}
                if name == 'Agent':
                    kind, task = _dispatch_kind(inp)
                    if kind:
                        use['dispatch'] = {'kind': kind, 'task': task, 'ctx': _ctx(msg.get('usage')), 'result': ''}
                        dispatches.append(use['dispatch'])
                uses[b.get('id')] = use
        elif r.get('type') == 'user':
            if isinstance(content, list):
                for b in content:
                    if not (isinstance(b, dict) and b.get('type') == 'tool_result'):
                        continue
                    use = uses.get(b.get('tool_use_id'))
                    if use is None:
                        continue
                    txt = _text(b.get('content'))
                    attribution[use['cls']] += len(txt)
                    d = use['dispatch']
                    if d is not None:
                        d['result'] += txt + '\n'
                        for aid in AGENT_ID_RE.findall(txt):
                            by_agent[aid] = d
            txt = _text(content) if isinstance(content, str) else ''
            for aid in AGENT_MSG_RE.findall(txt):
                if aid in by_agent:
                    by_agent[aid]['result'] += txt + '\n'
                    attribution['agent'] += len(txt)
                    break

    impl = [d for d in dispatches if d['kind'] == 'implementer']
    reviews = [d for d in dispatches if d['kind'] == 'reviewer']
    ctxs = [d['ctx'] for d in impl]
    growth = [b - a for a, b in zip(ctxs, ctxs[1:])]
    cannot = 0
    for d in reviews:
        m = WARN_COUNT_RE.search(d['result'])
        cannot += int(m.group(1)) if m else d['result'].count('Cannot verify from diff')
    return {
        'id': Path(path).stem,
        'ctx_first_impl': ctxs[0] if ctxs else None,
        'growth_median': int(round(statistics.median(growth))) if growth else None,
        'impl_dispatches': len(impl),
        'tasks': len({d['task'] for d in impl}),
        'review_dispatches': len(reviews),
        'brief_writer_dispatches': sum(d['kind'] == 'brief_writer' for d in dispatches),
        'needs_context_tasks': len({d['task'] for d in impl if NEEDS_CONTEXT_RE.search(d['result'])}),
        'blocked_tasks': len({d['task'] for d in impl if BLOCKED_RE.search(d['result'])}),
        'cannot_verify': cannot,
        'attribution': attribution,
    }


def _ratio(a: float, b: float):
    return round(a / b, 2) if b else None


def _median(xs: list):
    return round(statistics.median(xs), 2) if xs else None


def summarize(sessions: list[dict]) -> dict:
    tot = lambda k: sum(s[k] for s in sessions)  # noqa: E731
    return {
        'sessions': len(sessions),
        'median_ctx_first_impl': _median([s['ctx_first_impl'] for s in sessions if s['ctx_first_impl'] is not None]),
        'median_growth': _median([s['growth_median'] for s in sessions if s['growth_median'] is not None]),
        'review_rounds_per_task': _ratio(tot('review_dispatches'), tot('tasks')),
        'needs_context_per_task': _ratio(tot('needs_context_tasks'), tot('tasks')),
        'blocked_per_task': _ratio(tot('blocked_tasks'), tot('tasks')),
        'cannot_verify_per_review': _ratio(tot('cannot_verify'), tot('review_dispatches')),
    }


def _k(n) -> str:
    return '-' if n is None else f"{round(n / 1000)}K"


def _x(v) -> str:
    return '-' if v is None else f"{v:g}"


def _files(paths: list[str]) -> list[Path]:
    out = []
    for p in map(Path, paths):
        out += sorted(p.glob('*.jsonl')) if p.is_dir() else [p]
    return out


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog='measure-build-context.py',
                                 description='Ukur context & kualitas sesi /context-vault:build dari transcript .jsonl.')
    ap.add_argument('--json', action='store_true', help='keluarkan JSON {sessions, summary}')
    ap.add_argument('paths', nargs='+', metavar='PATH', help='file .jsonl atau direktori transcript')
    args = ap.parse_args(argv)
    sessions = [s for f in _files(args.paths) if (s := analyze_session(f)) is not None]
    summary = summarize(sessions)
    if args.json:
        print(json.dumps({'sessions': sessions, 'summary': summary}, ensure_ascii=False))
        return 0
    for s in sessions:
        print(f"{s['id'][:8]} ctx@impl1={_k(s['ctx_first_impl'])} growth={_k(s['growth_median'])} "
              f"impl={s['impl_dispatches']} tasks={s['tasks']} review/task={_x(_ratio(s['review_dispatches'], s['tasks']))} "
              f"needs_ctx={s['needs_context_tasks']} blocked={s['blocked_tasks']} ⚠️={s['cannot_verify']}")
    print(f"median ctx@impl1={_k(summary['median_ctx_first_impl'])} · median growth={_k(summary['median_growth'])} · "
          f"review/task={_x(summary['review_rounds_per_task'])} · needs_ctx/task={_x(summary['needs_context_per_task'])} · "
          f"blocked/task={_x(summary['blocked_per_task'])} · ⚠️/review={_x(summary['cannot_verify_per_review'])} · "
          f"sessions={summary['sessions']}")
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
