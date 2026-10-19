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
# 1b. YAML tak valid tapi bermakna (kutip lalu teks, ': ' di skalar polos) → skalar polos, bukan error
out="$($PY "$BS" --parse-yaml "$FX/yaml/tolerant.yaml" 2>&1)"
$PY -c 'import json,sys; sys.exit(0 if json.loads(sys.argv[1])==json.load(open(sys.argv[2])) else 1)' "$out" "$FX/yaml/tolerant.json" 2>/dev/null \
  && ok "parse-yaml toleran (kutip + teks sesudahnya)" || bad "parse-yaml toleran" "$out"
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

cp "$CV/tasks.yaml" "$T/tasks.bak"; printf 'milestones:\n\t- id: M9\n' >> "$CV/tasks.yaml"; setm "$CV/tasks.yaml" 5
out="$(snap 2>"$T/err")"; rc=$?
[ "$rc" = 2 ] && grep -q 'checkout-v2/tasks.yaml' "$T/err" && [ -z "$out" ] && ok "tasks.yaml rusak & baru ditulis (≤60 dtk) → exit 2, path di stderr, stdout kosong" \
  || bad "tasks.yaml rusak baru → exit 2" "rc=$rc out=$out err=$(cat "$T/err")"
cp "$T/tasks.bak" "$CV/tasks.yaml"; setm "$CV/tasks.yaml" 60
J="$(snap)"
chk "normal: errors []"                     '.errors' '[]'
printf '%s\n' 'feature: old-done' 'milestones:' '  - id: M1' '    title: X' '    tasks:' '      - id: T1' '        desc: x' '       status: done' \
  > "$P/control/features/old-done/tasks.yaml"; setm "$P/control/features/old-done/tasks.yaml" 3600
printf 'status:\tshipped\n\tx: 1\n' > "$P/control/features/shipped-x/feature.yaml"; setm "$P/control/features/shipped-x/feature.yaml" 3600
J="$(snap 2>"$T/err")"; rc=$?
[ "$rc" = 0 ] && ok "file rusak LAMA di work-item lain → exit 0 (bukan gelapkan semua)" || bad "file rusak lama → exit 0" "rc=$rc $(cat "$T/err")"
chk "file rusak lama: item sehat tetap tampil" '[.items[].name]' '["checkout-v2","2026-10-01-null-guard"]'
chk "file rusak lama: dilaporkan di errors"  '[.errors[] | .dir] | sort' '["control/features/old-done","control/features/shipped-x"]'
chk "errors.message relatif root + baris"    '.errors[] | select(.dir == "control/features/old-done") | .message' '"control/features/old-done/tasks.yaml: baris 8: indentasi tak terduga"'
cp "$FX/prod/control/features/old-done/tasks.yaml" "$P/control/features/old-done/tasks.yaml"
cp "$FX/prod/control/features/shipped-x/feature.yaml" "$P/control/features/shipped-x/feature.yaml"

rm -f "$CV/gates.yaml"; J="$(snap)"
chk "gates.yaml dihapus → gates [] (nggak crash)" '.items[0].gates' '[]'

# === estimasi + teks ringkas: fungsi murni ===
pyt() { # pyt <label> <ekspresi python; modul = bs, near(a,b) = toleransi float> — lulus kalau True
  local out
  out="$($PY -c 'import importlib.util,sys
s=importlib.util.spec_from_file_location("bs",sys.argv[1]); bs=importlib.util.module_from_spec(s); s.loader.exec_module(bs)
near=lambda a,b: a is not None and len(a)==len(b) and all(abs(x-y)<1e-6 for x,y in zip(a,b))
r=eval(sys.argv[2]); print(repr(r)); sys.exit(0 if r is True else 1)' "$BS" "$2" 2>&1)" && ok "$1" || bad "$1" "$2 → $out"
}
pyt "estimate: 2 pending satu lane"        'near(bs.estimate([("api",1,None),("api",1,None)], [600,720,840]), (880.0,2080.0))'
pyt "eta_text(880,2080)"                    'bs.eta_text(880, 2080) == "~10–35m"'
pyt "estimate: dua lane, elapsed dikurangi" 'near(bs.estimate([("api",1,720.0),("web",1,420.0)], [600,720,840]), (20.0,620.0))'
pyt "eta_text(20,620)"                      'bs.eta_text(20, 620) == "~1–15m"'
pyt "estimate: integration ditambah ke lane terberat" 'near(bs.estimate([("api",1,None),("__integration__",3,None)], [600,600,600]), (1600.0,3200.0))'
pyt "eta_text(1600,3200)"                   'bs.eta_text(1600, 3200) == "~25–55m"'
pyt "eta_text ≥ 1 jam"                      'bs.eta_text(3000, 6000) == "~50m–1j40m"'
pyt "estimate: < 3 sampel → None"           'bs.estimate([("api",1,None)], [600,600]) is None'
pyt "estimate: rows kosong → None"          'bs.estimate([], [600,720,840]) is None'
pyt "fmt_dur"                               '[bs.fmt_dur(x) for x in (4320,3600,45,720)] == ["1j12m","1j","<1m","12m"]'

# === estimasi + teks ringkas + alert: CLI ===
mkprod; hb "$SB" $$
J="$(snap)"
chk "eta checkout + held_note"              '.items[0].eta' '{"text":"~1–15m","held_note":"+ T9 nunggu lo"}'
chk "status_line di snapshot"               '.status_line' '"checkout-v2 7/12 · 2 lane · 1 ketahan · 1 gate · ~1–15m · +1 build lain"'
chk "fix: < 3 sampel → eta null"            '.items[1].eta' 'null'
out="$($PY "$BS" --root "$P" --format status --now $NOW)"
[ "$out" = "checkout-v2 7/12 · 2 lane · 1 ketahan · 1 gate · ~1–15m · +1 build lain" ] && ok "--format status" || bad "--format status" "$out"
rm -f "$SB/drive.json"
out="$($PY "$BS" --root "$P" --format status --now $NOW --quiet-min 0)"
[ "$out" = "checkout-v2 7/12 · 2 diam · 1 ketahan · 1 gate · ~5–20m · +1 build lain" ] \
  && ok "build diam (crash): '2 diam', ETA tanpa mengurangi elapsed basi" || bad "build diam: status_line" "$out"
hb "$SB" $$
out="$($PY "$BS" --root "$P" --format drive --now $NOW --work-item control/features/checkout-v2)"
[ "$out" = "putaran 2 · 7/12 · ▸ T8 api, T11 web · ⏸ 1 · ◆ 1 · 1j12m · sisa ~1–15m" ] && ok "--format drive checkout" || bad "--format drive checkout" "$out"
out="$($PY "$BS" --root "$P" --format drive --now $NOW --work-item control/features/checkout-v2 --width 30)"
[ "$out" = "putaran 2 · 7/12 · ▸ T8 api, …" ] && ok "--width 30 → dipotong + '…' (muat satu baris terminal)" || bad "--width 30" "$out"
out="$($PY "$BS" --root "$P" --format drive --now $NOW --work-item control/features/checkout-v2 --width 200)"
[ "$out" = "putaran 2 · 7/12 · ▸ T8 api, T11 web · ⏸ 1 · ◆ 1 · 1j12m · sisa ~1–15m" ] && ok "--width lebar → utuh" || bad "--width 200" "$out"
mkdir -p "$P/control/features/belum-ada"; printf 'status: active\n' > "$P/control/features/belum-ada/feature.yaml"
hb "$P/.claude/build/belum-ada" $$ 1 30
out="$($PY "$BS" --root "$P" --format drive --now $NOW --work-item control/features/belum-ada)"
[ "$out" = "putaran 1 · tasks.yaml belum ada · <1m" ] && ok "--format drive tanpa tasks.yaml" || bad "--format drive tanpa tasks.yaml" "$out"
J="$(snap)"
chk "alert keys held/gate/stop"             '[.alerts[].key | select(. == "held|control/features/checkout-v2|T9|needs_human|migrate destructive — nunggu lo" or . == "gate|control/features/checkout-v2|G3" or . == "stop|control/features/checkout-v2|review|1799999900")] | length' '3'
chk "alert stop review .text"               '.alerts[] | select(.key|startswith("stop|control/features/checkout-v2|")) | .text' '"🔔 checkout-v2 · build berhenti — 1 gate + 1 blocker nunggu lo"'
chk "alert held .text"                      '.alerts[] | select(.key|startswith("held|")) | .text' '"⏸ checkout-v2 · T9 needs_human — migrate destructive — nunggu lo, nahan 2 task"'
chk "alert gate .text"                      '.alerts[] | select(.key|startswith("gate|")) | .text' '"◆ checkout-v2 · gate G3 antri — api×M2: floor-scan T6 (token)"'
printf 'outcome: done\ndone: 2\npending: 0\nreason: selesai\n' > "$P/control/features/old-done/last-run.md"; setm "$P/control/features/old-done/last-run.md" 50
J="$(snap)"
chk "alert juga untuk work-item yang nggak tampil (old-done selesai)" '[.alerts[] | select(.key == "stop|control/features/old-done|done|1799999950") | .text]' '["✓ old-done · build selesai — siap /ship"]'
printf 'outcome: review\ndone: 7\npending: 5\nreason: gate antri\n' > "$CV/last-run.md"
J="$(snap)"
chk "last-run tanpa review:/blockers: → ?"  '[.alerts[] | select(.key|startswith("stop|control/features/checkout-v2|")) | .text | contains("? gate + ? blocker")]' '[true]'
printf 'outcome: halt\ndone: 7\npending: 5\nreason: allowlist kosong\n' > "$CV/last-run.md"
J="$(snap)"
chk "alert halt .text"                      '[.alerts[] | select(.key|startswith("stop|control/features/checkout-v2|halt|")) | .text]' '["⚠ checkout-v2 · build halt — allowlist kosong"]'
printf 'outcome: continue\ndone: 7\npending: 5\nreason: cap\n' > "$CV/last-run.md"
J="$(snap)"
chk "outcome continue → nggak ada alert stop" '[.alerts[] | select(.key|startswith("stop|control/features/checkout-v2|"))] | length' '0'

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
