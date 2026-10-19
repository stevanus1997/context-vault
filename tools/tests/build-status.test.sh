#!/usr/bin/env bash
# Test pembaca status build — plugin/template/.claude/build_status.py (parser YAML subset, snapshot, teks ringkas).
# Jalanin: bash tools/tests/build-status.test.sh  (exit 0 = semua lulus)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BS="$ROOT/plugin/template/.claude/build_status.py"
FX="$ROOT/tools/tests/fixtures/build-status"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL - $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; }
command -v python3 >/dev/null 2>&1 || { echo "butuh python3"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "butuh jq"; exit 1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PY="python3 -B"

# === parser YAML ===
# 1. konstruksi → JSON sama persis (bandingkan sebagai objek, bukan teks)
out="$($PY "$BS" --parse-yaml "$FX/yaml/constructs.yaml")"
$PY -c 'import json,sys; sys.exit(0 if json.loads(sys.argv[1])==json.load(open(sys.argv[2])) else 1)' "$out" "$FX/yaml/constructs.json" \
  && ok "parse-yaml konstruksi" || bad "parse-yaml konstruksi" "$out"
# 2. tab di indentasi → exit 2, stderr sebut nama file
err="$($PY "$BS" --parse-yaml "$FX/yaml/tab.yaml" 2>&1 >/dev/null)"; rc=$?
[ "$rc" = 2 ] && grep -q 'tab.yaml' <<<"$err" && ok "tab → exit 2" || bad "tab → exit 2" "rc=$rc $err"

# === snapshot v1 (--format json) terhadap produk palsu ===
NOW=1800000000
P="$T/prod"; CV="$P/control/features/checkout-v2"; SB="$P/.claude/build/checkout-v2"
FIXD="$P/control/fixes/2026-10-01-null-guard"
setm() { $PY -c 'import os,sys; t=int(sys.argv[2]); os.utime(sys.argv[1],(t,t))' "$1" "$((NOW - $2))"; }   # setm <file> <detik-sebelum-NOW>
mkprod() {
  rm -rf "$P"; cp -R "$FX/prod" "$P"
  git -C "$P/api" init -q; git -C "$P/web" init -q
  setm "$CV/tasks.yaml" 60
  setm "$SB/task-T5-brief.md" 4000; setm "$SB/task-T5-report.md" 3400
  setm "$SB/task-T6-brief.md" 3300; setm "$SB/task-T6-report.md" 2580
  setm "$SB/task-T7-brief.md" 2500; setm "$SB/task-T7-report.md" 1660
  setm "$SB/task-T8-brief.md" 720
  setm "$SB/task-T11-brief.md" 420; setm "$SB/task-T11-report.md" 120
  setm "$CV/last-run.md" 100
  setm "$FIXD/tasks.yaml" 3000
  setm "$P/.claude/build/fixes/2026-10-01-null-guard/task-fix-null-guard-brief.md" 3000
}
hb() { # hb <dir-scratch> <pid> [round] [started-detik-sebelum-NOW] — heartbeat drive.sh
  mkdir -p "$1"
  printf '{"round":%s,"started":%s,"round_started":%s,"max_hours":6,"pid":%s}\n' "${3:-2}" "$((NOW - ${4:-4320}))" "$((NOW - 600))" "$2" > "$1/drive.json"
}
snap() { $PY "$BS" --root "$P" --format json --now $NOW "$@"; }
J=""
chk() { # chk <label> <jq-expr> <expected-json> — dibandingkan sebagai JSON ter-normalisasi
  local got want
  got="$(jq -cS "$2" <<<"$J" 2>&1)"; want="$(jq -cS . <<<"$3")"
  [ "$got" = "$want" ] && ok "$1" || bad "$1" "got:  $got"$'\n'"want: $want"
}

mkprod; hb "$SB" $$
J="$(snap)" || bad "snapshot exit 0" "$J"
chk "v == 1"                                '.v' '1'
chk "items = checkout-v2, fix (old-done & shipped-x nggak ikut)" '[.items[].name]' '["checkout-v2","2026-10-01-null-guard"]'
chk "kind/dir item"                         '[.items[] | [.kind,.dir]]' '[["feature","control/features/checkout-v2"],["fix","control/fixes/2026-10-01-null-guard"]]'
chk "checkout done/total 7/12"              '.items[0] | [.done,.total]' '[7,12]'
chk "lanes T8, T11 (urut dokumen)"          '[.items[0].lanes[].id]' '["T8","T11"]'
chk "lane T8: impl 12m (brief tanpa report)" '.items[0].lanes[0] | [.phase,.elapsed]' '["impl","12m"]'
chk "lane T11: tanpa fase 7m (report ada)"  '.items[0].lanes[1] | [.phase,.elapsed]' '[null,"7m"]'
chk "held T9 + reason hold + blocks transitif" '.items[0].held' '[{"id":"T9","unit":"api","status":"needs_human","reason":"migrate destructive — nunggu lo","blocks":["T12","T13"]}]'
chk "task held di pohon dapat reason sama"  '.items[0].milestones[1].tasks[] | select(.id=="T9") | .reason' '"migrate destructive — nunggu lo"'
chk "gates = hanya queued"                  '.items[0].gates' '[{"id":"G3","segment":"api×M2","reason":"floor-scan T6 (token)"}]'
chk "milestone 4/4 dan 3/8"                 '[.items[0].milestones[] | [.done,.total]]' '[[4,4],[3,8]]'
chk "milestone id/title"                    '[.items[0].milestones[] | [.id,.title]]' '[["M1","Fondasi auth"],["M2","Checkout"]]'
chk "waiting_on T12 / T13"                  '[.items[0].milestones[1].tasks[] | select(.id=="T12" or .id=="T13") | .waiting_on]' '[["T9","T11"],["T8","T12"]]'
chk "heartbeat hidup → unattended + drive"  '.items[0] | [.mode,.drive]' '["unattended",{"round":2,"elapsed":"1j12m","max":"6j"}]'
chk "heartbeat hidup → running"             '.items[0].running' 'true'

hb "$SB" 999999; J="$(snap)"
chk "heartbeat PID mati → attended, drive null" '.items[0] | [.mode,.drive]' '["attended",null]'

rm -f "$SB/drive.json"; J="$(snap)"
chk "tanpa drive.json: fix diam 50m, running false" '.items[1] | [.lanes[0].quiet,.lanes[0].quiet_for,.running]' '[true,"50m",false]'
chk "tanpa drive.json: checkout tetap running (aktivitas 1m lalu)" '.items[0] | [.lanes[0].quiet,.running]' '[false,true]'
chk "fix-cleanup tanpa unit/desc, dep tak dikenal" '.items[1].milestones[0].tasks[] | select(.id=="fix-cleanup") | [.unit,.desc,.waiting_on]' '["","",["T99"]]'
chk "fix tanpa gates.yaml → gates []"       '.items[1].gates' '[]'

J="$(snap --work-item control/features/old-done)"
chk "--work-item old-done → persis item itu" '[.items[].name]' '["old-done"]'
mkdir -p "$P/control/features/belum-ada"; printf 'status: active\n' > "$P/control/features/belum-ada/feature.yaml"
J="$(snap --work-item control/features/belum-ada)"
chk "--work-item tanpa tasks.yaml → total 0, milestones []" '.items[0] | [.total,.milestones]' '[0,[]]'
J="$(snap)"
chk "fitur tanpa tasks.yaml nggak ikut scan" '[.items[].name]' '["checkout-v2","2026-10-01-null-guard"]'

cp "$CV/tasks.yaml" "$T/tasks.bak"; printf 'milestones:\n\t- id: M9\n' >> "$CV/tasks.yaml"
out="$(snap 2>"$T/err")"; rc=$?
[ "$rc" = 2 ] && grep -q 'checkout-v2/tasks.yaml' "$T/err" && [ -z "$out" ] && ok "tasks.yaml rusak → exit 2, path di stderr, stdout kosong" \
  || bad "tasks.yaml rusak → exit 2" "rc=$rc out=$out err=$(cat "$T/err")"
cp "$T/tasks.bak" "$CV/tasks.yaml"

rm -f "$CV/gates.yaml"; J="$(snap)"
chk "gates.yaml dihapus → gates [] (nggak crash)" '.items[0].gates' '[]'

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
