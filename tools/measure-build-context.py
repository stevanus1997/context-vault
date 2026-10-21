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
# CC lama: 'agentId: <id>' + <agent-message from="<id>">; CC 2.1.30x: 'agent_id: <id>' / 'name: <nama>'
# + <teammate-message teammate_id="<nama>"> — dua-duanya dipetakan ke dispatch-nya
AGENT_ID_RE = re.compile(r'(?m)(?:agentId|agent_id|^name):\s*([A-Za-z0-9_.-]+)')
AGENT_MSG_RE = re.compile(r'<(?:agent-message from|teammate-message teammate_id)="([^"]+)"')
AMBIGU_RE = re.compile(r'(?mi)^\s*ambigu:\s*(?!none\b)\S')
# Status implementer di awal baris; kata "status" boleh huruf apa pun + markdown (`STATUS: BLOCKED`,
# `**Status: NEEDS_CONTEXT.**`). Token status tetap HURUF BESAR — "Blocked: none" bukan BLOCKED.
NEEDS_CONTEXT_RE = re.compile(r'(?m)^\W*(?:[Ss][Tt][Aa][Tt][Uu][Ss]\W*)?NEEDS_CONTEXT\b')
BLOCKED_RE = re.compile(r'(?m)^\W*(?:[Ss][Tt][Aa][Tt][Uu][Ss]\W*)?BLOCKED\b')
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
    prompt = tool_input.get('prompt') if isinstance(tool_input.get('prompt'), str) else ''
    if tool_input.get('subagent_type') == 'context-vault:brief-writer':
        m = IMPL_RE.search(prompt)
        return 'brief_writer', m.group(1) if m else None
    if '.diff' in prompt and '-brief.md' in prompt and '-report.md' in prompt:
        return 'reviewer', None                   # subagent bukti ⚠️ (brief + diff, tanpa report) bukan reviewer
    m = IMPL_RE.search(prompt)
    if m and '-report.md' in prompt:
        return 'implementer', m.group(1)
    return 'other', None                          # critic/Explore/smoke: dihitung atribusinya saja


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
    ctx_seq = []                                  # ctx tiap record assistant (urut) → total kenaikan, tahan compaction
    for r in records:
        msg = _dict(r.get('message'))
        content = msg.get('content')
        if r.get('type') == 'assistant' and isinstance(content, list):
            if _ctx(msg.get('usage')):
                ctx_seq.append(_ctx(msg.get('usage')))
            for b in content:
                if not (isinstance(b, dict) and b.get('type') == 'tool_use'):
                    continue
                name, inp = b.get('name') or '', _dict(b.get('input'))
                use = {'cls': classify(name, inp), 'dispatch': None}
                if name == 'Agent':
                    kind, task = _dispatch_kind(inp)
                    use['dispatch'] = {'kind': kind, 'task': task, 'ctx': _ctx(msg.get('usage')), 'result': ''}
                    dispatches.append(use['dispatch'])
                    if isinstance(inp.get('name'), str) and inp['name']:
                        by_agent[inp['name']] = use['dispatch']      # nama dipakai ulang → dispatch terbaru menang
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
        # total kenaikan context sesi ÷ task — sesi yang dibuka gate/mockup tetap sebanding (ctx@impl1 tidak)
        'growth_per_task_total': (int(round(sum(max(0, b - a) for a, b in zip(ctx_seq, ctx_seq[1:])) / len({d['task'] for d in impl})))
                                  if impl else None),
        'impl_dispatches': len(impl),
        'tasks': len({d['task'] for d in impl}),
        'review_dispatches': len(reviews),
        'brief_writer_dispatches': sum(d['kind'] == 'brief_writer' for d in dispatches),
        'needs_context_tasks': len({d['task'] for d in impl if NEEDS_CONTEXT_RE.search(d['result'])}),
        # brief-writer menangkap ambiguitas SEBELUM implementer jalan → bandingkan (needs_ctx + ambigu) vs baseline needs_ctx
        'ambiguity_tasks': len({d['task'] for d in dispatches
                                if d['kind'] == 'brief_writer' and d['task'] and AMBIGU_RE.search(d['result'])}),
        'brief_tasks': len({d['task'] for d in dispatches if d['kind'] == 'brief_writer' and d['task']}),
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
        'median_growth_per_task_total': _median([s['growth_per_task_total'] for s in sessions
                                                 if s['growth_per_task_total'] is not None]),
        'review_rounds_per_task': _ratio(tot('review_dispatches'), tot('tasks')),
        'needs_context_per_task': _ratio(tot('needs_context_tasks'), tot('tasks')),
        'ambiguity_per_task': _ratio(tot('ambiguity_tasks'), tot('brief_tasks')),   # per task yang di-brief
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
              f"growth/task-total={_k(s['growth_per_task_total'])} "
              f"impl={s['impl_dispatches']} tasks={s['tasks']} review/task={_x(_ratio(s['review_dispatches'], s['tasks']))} "
              f"needs_ctx={s['needs_context_tasks']} ambigu={s['ambiguity_tasks']} blocked={s['blocked_tasks']} ⚠️={s['cannot_verify']}")
    print(f"median ctx@impl1={_k(summary['median_ctx_first_impl'])} · median growth={_k(summary['median_growth'])} · "
          f"median growth/task-total={_k(summary['median_growth_per_task_total'])} · "
          f"review/task={_x(summary['review_rounds_per_task'])} · needs_ctx/task={_x(summary['needs_context_per_task'])} · "
          f"ambigu/task={_x(summary['ambiguity_per_task'])} · "
          f"blocked/task={_x(summary['blocked_per_task'])} · ⚠️/review={_x(summary['cannot_verify_per_review'])} · "
          f"sessions={summary['sessions']}")
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
