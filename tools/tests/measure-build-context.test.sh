#!/usr/bin/env bash
# Test alat ukur context sesi build — tools/measure-build-context.py (transcript .jsonl → metrik per sesi + summary).
# Jalanin: bash tools/tests/measure-build-context.test.sh  (exit 0 = semua lulus)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MB="$ROOT/tools/measure-build-context.py"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL - $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; }
command -v python3 >/dev/null 2>&1 || { echo "butuh python3"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "butuh jq"; exit 1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PY="python3 -B"

# === fixture: satu sesi build + satu sesi biasa ===
$PY - "$T" <<'PY'
import json, sys
from pathlib import Path
d = Path(sys.argv[1])

def usage(n):
    return {'input_tokens': 0, 'cache_creation_input_tokens': 0, 'cache_read_input_tokens': n}

def call(n, uid, name, inp, result):
    return [{'type': 'assistant', 'message': {'role': 'assistant', 'usage': usage(n),
             'content': [{'type': 'tool_use', 'id': uid, 'name': name, 'input': inp}]}},
            {'type': 'user', 'message': {'role': 'user',
             'content': [{'type': 'tool_result', 'tool_use_id': uid, 'content': result}]}}]

impl1 = {'description': 'Implement T1',
         'prompt': 'Baca brief: .claude/build/x/task-T1-brief.md\nReport: .claude/build/x/task-T1-report.md'}
recs = [{'type': 'user', 'message': {'role': 'user', 'content':
         '<command-message>context-vault:build</command-message>\n<command-name>/context-vault:build</command-name>\n<command-args>x</command-args>'}}]
recs += call(40000, 'u1', 'Read', {'file_path': '/p/plugin/skills/build/reference.md'}, 'A' * 3200)
recs += call(50000, 'u2', 'Bash', {'command': 'sed -n 1,40p control/features/x/tasks.yaml'}, 'B' * 6400)
recs += call(60000, 'u3', 'Agent', impl1, 'Async agent launched successfully.\nagentId: aaa1 (internal)')
recs += [{'type': 'user', 'message': {'role': 'user', 'content':
          'Another Claude session sent a message:\n<agent-message from="aaa1">\n  Status: NEEDS_CONTEXT\n  butuh nama tabel\n</agent-message>'}}]
recs += call(62000, 'u4', 'Agent', impl1, 'Status: DONE\nCommit abc1234')
recs += call(65000, 'u5', 'Agent', {'description': 'Review T1', 'prompt':
             '.claude/build/x/task-T1-brief.md .claude/build/x/task-T1-report.md .claude/build/x/review-abc1234..def5678.diff'},
             'spec: ✅\nquality: ✅ (Critical 0 · Important 0 · Minor 1)\n⚠️: 2\n  - a\n  - b\nreview: r.md')
recs += call(70000, 'u6', 'Bash', {'command': 'cat src/app/page.tsx'}, 'C' * 9600)
recs += call(80000, 'u7', 'Agent', {'description': 'Implement T2',
             'prompt': '.claude/build/x/task-T2-brief.md .claude/build/x/task-T2-report.md'}, 'Status: BLOCKED\nalasan')
recs += call(81000, 'u8', 'Agent', {'subagent_type': 'context-vault:brief-writer',
             'prompt': 'Tulis brief ke: .claude/build/x/task-T3-brief.md'}, 'brief: x\nambigu: none')
recs += call(82000, 'u9', 'Agent', {'subagent_type': 'context-vault:brief-writer',
             'prompt': 'Rakit brief task T4\nTulis brief ke: .claude/build/x/task-T4-brief.md'},
             'brief: y\nambigu: tabel orders atau order?')
recs += call(82500, 'u11', 'Agent', {'subagent_type': 'context-vault:brief-writer', 'prompt': 'Rakit brief tanpa path'},
             'ambigu: tanpa id task')
recs += call(83000, 'u10', 'Agent', {'subagent_type': 'context-vault:critic', 'prompt': 'Pre-flight sweep build x'},
             'Async agent launched successfully.\nagentId: ccc9 (internal)')
recs += [{'type': 'user', 'message': {'role': 'user', 'content':
          'Another Claude session sent a message:\n<agent-message from="ccc9">\n' + 'X' * 5000 + '\n</agent-message>'}}]
(d / 'build.jsonl').write_text('\n'.join(json.dumps(r, ensure_ascii=False) for r in recs) + '\n', encoding='utf-8')

plain = [{'type': 'user', 'message': {'role': 'user', 'content': 'halo'}},
         {'type': 'assistant', 'message': {'role': 'assistant', 'usage': usage(1000),
          'content': [{'type': 'text', 'text': 'halo juga'}]}}]
(d / 'plain.jsonl').write_text('\n'.join(json.dumps(r) for r in plain) + '\n{rusak\n', encoding='utf-8')
PY

J="$($PY "$MB" --json "$T" 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "--json exit 0" || bad "--json exit 0" "rc=$rc $J"
q() { jq -r "$1" <<<"$J" 2>/dev/null; }
eq() { local got; got="$(q "$1")"; [ "$got" = "$2" ] && ok "$1 == $2" || bad "$1 == $2" "got: $got"; }

eq '.sessions|length' 1
eq '.sessions[0].ctx_first_impl' 60000
eq '.sessions[0].growth_median' 10000
eq '.sessions[0].impl_dispatches' 3
eq '.sessions[0].tasks' 2
eq '.sessions[0].review_dispatches' 1
eq '.sessions[0].brief_writer_dispatches' 3
eq '.sessions[0].brief_tasks' 2
eq '.sessions[0].ambiguity_tasks' 1
eq '.sessions[0].attribution.agent >= 5000' true
eq '.sessions[0].needs_context_tasks' 1
eq '.sessions[0].blocked_tasks' 1
eq '.sessions[0].cannot_verify' 2
eq '.sessions[0].attribution.skillref' 3200
eq '.sessions[0].attribution.state' 6400
eq '.sessions[0].attribution.code' 9600
eq '.sessions[0].attribution.agent > 0' true
eq '.summary.review_rounds_per_task' 0.5
eq '.summary.needs_context_per_task' 0.5
eq '.summary.blocked_per_task' 0.5
eq '.summary.cannot_verify_per_review == 2' true
eq '.summary.ambiguity_per_task' 0.5

out="$($PY "$MB" "$T" 2>&1)"
grep -qF 'ctx@impl1=60K' <<<"$out" && grep -qF 'sessions=1' <<<"$out" \
  && ok "teks: ctx@impl1=60K + sessions=1" || bad "teks: ctx@impl1=60K + sessions=1" "$out"

# === bentuk balikan nyata + subagent bukti ⚠️ (final review I-3) ===
T2="$T/variants"; mkdir -p "$T2"
$PY - "$T2" <<'PY'
import json, sys
from pathlib import Path
u = lambda n: {'input_tokens': 0, 'cache_creation_input_tokens': 0, 'cache_read_input_tokens': n}
def call(n, uid, inp, result):
    return [{'type': 'assistant', 'message': {'role': 'assistant', 'usage': u(n),
             'content': [{'type': 'tool_use', 'id': uid, 'name': 'Agent', 'input': inp}]}},
            {'type': 'user', 'message': {'role': 'user', 'content': [{'type': 'tool_result', 'tool_use_id': uid, 'content': result}]}}]
b = lambda i: f".claude/build/x/task-{i}-brief.md"
r = lambda i: f".claude/build/x/task-{i}-report.md"
recs = [{'type': 'user', 'message': {'role': 'user', 'content': '<command-name>/context-vault:build</command-name>'}}]
recs += call(10000, 'v1', {'prompt': f"{b('T1')} {r('T1')}"}, 'STATUS: BLOCKED\nrepo kotor')
recs += call(20000, 'v2', {'prompt': f"{b('T2')} {r('T2')}"}, '**Status: NEEDS_CONTEXT.** butuh nama kolom')
recs += call(30000, 'v3', {'prompt': f"{b('T3')} {r('T3')}"}, 'Status: DONE\nBlocked: none')
recs += call(40000, 'v4', {'prompt': f"{b('T3')} {r('T3')} .claude/build/x/review-a1..b2.diff"}, 'spec: ✅\n⚠️: 1\nreview: r.md')
recs += call(50000, 'v5', {'subagent_type': 'Explore', 'prompt':
             f"Task T3. Item ⚠️ dari reviewer:\n  - x\nBrief: {b('T3')}   Diff: .claude/build/x/review-a1..b2.diff"}, 'x → aman — bukti a.ts:1')
(Path(sys.argv[1]) / 'v.jsonl').write_text('\n'.join(json.dumps(x, ensure_ascii=False) for x in recs) + '\n', encoding='utf-8')
PY
J="$($PY "$MB" --json "$T2" 2>&1)"
eq '.sessions[0].review_dispatches' 1
eq '.sessions[0].blocked_tasks' 1
eq '.sessions[0].needs_context_tasks' 1

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
