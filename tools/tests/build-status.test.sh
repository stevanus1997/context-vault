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
hb() { # hb <dir-scratch> <pid> [round] [started-detik-sebelum-NOW] [mtime-detik-sebelum-NOW] — heartbeat drive.sh
  mkdir -p "$1"
  printf '{"round":%s,"started":%s,"round_started":%s,"max_hours":6,"pid":%s}\n' "${3:-2}" "$((NOW - ${4:-4320}))" "$((NOW - 600))" "$2" > "$1/drive.json"
  setm "$1/drive.json" "${5:-10}"          # ticker drive.sh men-touch tiap tick → heartbeat hidup = baru di-touch
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
hb "$SB" $$ 2 4320 600; J="$(snap)"
chk "heartbeat basi (PID hidup tapi nggak di-touch 10 mnt — PID bisa kepakai ulang) → attended" '.items[0] | [.mode,.drive]' '["attended",null]'

rm -f "$SB/drive.json"; J="$(snap --quiet-min 30)"
chk "tanpa drive.json, --quiet-min 30: fix diam 50m, running false" '.items[1] | [.lanes[0].quiet,.lanes[0].quiet_for,.running]' '[true,"50m",false]'
chk "tanpa drive.json: checkout tetap running (aktivitas 1m lalu)" '.items[0] | [.lanes[0].quiet,.running]' '[false,true]'
J="$(snap)"
chk "ambang diam default 90 mnt: jeda 50m (implementer attended yang lama) belum diam" '.items[1] | [.lanes[0].quiet,.running]' '[false,true]'
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
: > "$CV/tasks.yaml"; setm "$CV/tasks.yaml" 5
out="$(snap 2>"$T/err")"; rc=$?
[ "$rc" = 2 ] && grep -q 'checkout-v2/tasks.yaml' "$T/err" && ok "tasks.yaml kosong & baru ditulis → exit 2 (setengah tertulis, mod pakai hasil terakhir)" \
  || bad "tasks.yaml kosong baru → exit 2" "rc=$rc err=$(cat "$T/err")"
printf 'feature: checkout-v2\n' > "$CV/tasks.yaml"; setm "$CV/tasks.yaml" 5
out="$(snap 2>"$T/err")"; rc=$?
[ "$rc" = 2 ] && ok "tasks.yaml tanpa milestones & baru ditulis → exit 2" || bad "tasks.yaml tanpa milestones baru → exit 2" "rc=$rc"
: > "$CV/tasks.yaml"; setm "$CV/tasks.yaml" 3600
out="$(snap 2>"$T/err")"; rc=$?
[ "$rc" = 0 ] && ok "tasks.yaml kosong & lama → exit 0 (memang kosong, bukan setengah tertulis)" || bad "tasks.yaml kosong lama" "rc=$rc err=$(cat "$T/err")"
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
setm "$SB/task-T8-brief.md" 3000; setm "$SB/task-T11-brief.md" 3000   # keduanya jalan 50m > estimasi atas (~17m)
J="$(snap)"
chk "ETA: sisa cuma task jalan yang lewat estimasi → 'lewat estimasi', bukan ~1–6m selamanya" '.items[0].eta.text' '"lewat estimasi"'
out="$($PY "$BS" --root "$P" --format drive --now $NOW --work-item control/features/checkout-v2)"
[ "$out" = "putaran 2 · 7/12 · ▸ T8 api, T11 web · ⏸ 1 · ◆ 1 · 1j12m · lewat estimasi" ] && ok "--format drive: 'lewat estimasi' tanpa 'sisa'" || bad "drive lewat estimasi" "$out"
mkprod; hb "$SB" $$
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

# === format controller|task|carry (fixture lean — ringkasan state controller build) ===
LN="$T/lean"; LX="control/features/lean-x"; LF="control/fixes/2026-10-02-legacy"
mklean() { rm -rf "$LN"; cp -R "$FX/lean" "$LN"; git -C "$LN/api" init -q; git -C "$LN/web" init -q; }
lean() { $PY "$BS" --root "$LN" "$@"; }
mklean
J="$(lean --format task --task T9,T3 --work-item $LX)" || bad "task exit 0" "$J"
chk "task: urut sesuai --task"              '[.tasks[].id]' '["T9","T3"]'
chk "task: milestone ditempel"              '.tasks[1].milestone' '"M2"'
chk "task: reuse blok utuh"                 '.tasks[1].reuse' '[{"table":"users"}]'
chk "task: work_item relatif root"          '.work_item' '"control/features/lean-x"'
err="$(lean --format task --task T42 --work-item $LX 2>&1 >/dev/null)"; rc=$?
[ "$rc" = 2 ] && grep -qF 'task tak dikenal: T42' <<<"$err" && ok "task tak dikenal → exit 2" || bad "task tak dikenal → exit 2" "rc=$rc $err"
err="$(lean --format task --task T3 2>&1 >/dev/null)"; rc=$?
[ "$rc" = 2 ] && grep -qF 'butuh --work-item' <<<"$err" && ok "task tanpa --work-item → exit 2" || bad "task tanpa --work-item → exit 2" "rc=$rc $err"
J="$(lean --format carry --for T3 --work-item $LX)"
chk "carry T3: sumber carry.yaml"           '.source' '"carry.yaml"'
chk "carry T3 → C1"                         '[.notes[].id]' '["C1"]'
J="$(lean --format carry --for T1 --work-item $LX)"
chk "carry task done → kosong"              '.notes' '[]'
J="$(lean --format carry --for gate:M2/api --work-item $LX)"
chk "carry gate:M2/api → C3 (C5 closed)"    '[.notes[].id]' '["C3"]'
J="$(lean --format carry --for gate:M2 --work-item $LX)"
chk "carry gate:M2 → C3 (segmen ikut)"      '[.notes[].id]' '["C3"]'
J="$(lean --format carry --for ship,T3 --work-item $LX)"
chk "carry ship,T3 → urut file"             '[.notes[].id]' '["C4","C1"]'
J="$(lean --format carry --for F1 --work-item $LF)"
chk "carry legacy: sumber legacy"           '.source' '"legacy"'
chk "carry legacy F1 → barisnya"            '.notes' '[{"line":"- F1: jangan ubah signature parse()"}]'
J="$(lean --format carry --for F0 --work-item $LF)"
chk "carry legacy task done → kosong"       '.notes' '[]'
J="$(lean --format carry --for ship,simplify,gate:M1 --work-item $LF)"
chk "carry legacy ship/simplify/gate"       '[.notes[].line]' '["- gate M1: cek log error","- SHIP: catat env baru FOO_URL","- 7a: helper kembar formatDate"]'
printf '\t- id: C9\n' >> "$LN/$LX/carry.yaml"
err="$(lean --format carry --for T3 --work-item $LX 2>&1 >/dev/null)"; rc=$?
[ "$rc" = 2 ] && grep -qF 'carry.yaml' <<<"$err" && ok "carry.yaml rusak → exit 2, sebut file" || bad "carry.yaml rusak → exit 2" "rc=$rc $err"
rm -f "$LN/$LX/carry.yaml"
J="$(lean --format carry --for T3 --work-item $LX)"
chk "tanpa carry & legacy → none"           '[.source,.notes]' '["none",[]]'

mklean
setm "$LN/$LX/tasks.yaml" 600; setm "$LN/$LX/plans/api.md" 60; setm "$LN/$LX/plans/_shared.md" 900; setm "$LN/$LX/business.md" 30
lean --format controller --work-item $LX > "$T/ctl1" 2>&1; rc=$?
[ "$rc" = 0 ] && cmp -s "$T/ctl1" "$FX/lean/expected-controller.txt" && ok "controller lean-x == expected-controller.txt" \
  || bad "controller lean-x == expected-controller.txt" "rc=$rc"$'\n'"$(diff "$FX/lean/expected-controller.txt" "$T/ctl1")"
lean --format controller --work-item $LX > "$T/ctl2" 2>&1; rc2=$?
[ "$rc" = 0 ] && [ "$rc2" = 0 ] && cmp -s "$T/ctl1" "$T/ctl2" && ok "controller deterministik (dua kali identik)" || bad "controller deterministik" "$(diff "$T/ctl1" "$T/ctl2")"
line() { lean --format controller --work-item "$1" 2>&1 | sed -n "$2"; }
setm "$LN/$LX/plans/api.md" 900
out="$(line $LX 2p)"; [ "$out" = "staleness: WARN business.md > tasks.yaml" ] && ok "staleness WARN business.md" || bad "staleness WARN business.md" "$out"
setm "$LN/$LX/business.md" 900
out="$(line $LX 2p)"; [ "$out" = "staleness: OK" ] && ok "staleness OK" || bad "staleness OK" "$out"
rm -f "$LN/control/schema/api.md"
out="$(line $LX '/^reuse basi:/p')"; [ "$out" = "reuse basi: T4 file src/ghost.ts" ] \
  && ok "proyeksi skema absen → cek tabel dilewati (nggak basi palsu)" || bad "proyeksi absen → reuse basi" "$out"
mklean
$PY - "$LN/$LX/tasks.yaml" <<'PY'
import sys; p = sys.argv[1]; s = open(p).read()
old = "        reuse:\n          - table: carts\n          - file: src/ghost.ts\n"
assert s.count(old) == 1; open(p, 'w').write(s.replace(old, "        reuse: [ {table: carts}, {file: src/ghost.ts} ]\n"))
PY
out="$(line $LX '/^reuse basi:/p')"; [ "$out" = "reuse basi: T4 table carts · T4 file src/ghost.ts" ] \
  && ok "reuse bentuk flow map ({table: x}) tetap dibaca" || bad "reuse flow map" "$out"
out="$(line $LF 1p)"; [ "$out" = "work-item: control/fixes/2026-10-02-legacy (fix) · scratch .claude/build/fixes/2026-10-02-legacy" ] && ok "controller fix: baris work-item" || bad "controller fix: baris work-item" "$out"
out="$(line $LF '/^carry:/p')"; [ "$out" = "carry: legacy _carry-notes.md (5 baris) · next C1" ] && ok "controller fix: carry legacy" || bad "controller fix: carry legacy" "$out"
# legacy belum dikonversi + carry.yaml baru (titipan pertama ditulis unattended) → legacy TETAP kebaca (final review C-1)
mklean
printf '%s\n' '# carry.yaml — titipan antar-task build. Penulis tunggal: controller build. Entri terbaru di ATAS.' 'notes:' \
  '  - id: C1' '    for: ship' '    from: review F1' '    at: 2026-10-21' '    note: "deploy web dulu"' > "$LN/$LF/carry.yaml"
J="$(lean --format carry --for F1,ship --work-item $LF)"
chk "carry.yaml + legacy belum dikonversi → sumber gabungan" '.source' '"carry.yaml+legacy"'
chk "… entri carry.yaml lalu baris legacy"  '[.notes[] | (.id // .line)]' '["C1","- F1: jangan ubah signature parse()","- SHIP: catat env baru FOO_URL"]'
out="$(line $LF '/^carry:/p')"; [ "$out" = "carry: ship×1 · next C2 · legacy _carry-notes.md aktif (5 baris)" ] \
  && ok "controller: legacy tetap ditandai selama belum dikonversi" || bad "controller: legacy + carry.yaml" "$out"
$PY - "$LN/$LF/carry.yaml" <<'PY'
import sys; p = sys.argv[1]; s = open(p).read(); open(p, 'w').write(s.replace('notes:\n', 'legacy_converted: 2026-10-21\nnotes:\n', 1))
PY
J="$(lean --format carry --for F1 --work-item $LF)"
chk "legacy_converted → legacy berhenti dibaca" '[.source,.notes]' '["carry.yaml",[]]'
out="$(line $LF '/^carry:/p')"; [ "$out" = "carry: ship×1 · next C2" ] && ok "controller: legacy_converted → tanpa penanda legacy" || bad "controller: legacy_converted" "$out"
# monorepo: unit tanpa path = repo root produk, bukan lane 'root' terpisah (2 task sekaligus di 1 repo) — final review I-5
MO="$T/mono"; rm -rf "$MO"; mkdir -p "$MO/control/features/m" "$MO/apps/web"
printf '%s\n' 'topology: monorepo' 'apps:' '  - name: web' '    path: apps/web' 'packages:' '  - name: shared' > "$MO/control/workspace.yaml"
printf '%s\n' 'milestones:' '  - id: M1' '    title: X' '    tasks:' '      - id: T1' '        unit: web' '        status: pending' \
  '      - id: T2' '        unit: shared' '        status: pending' > "$MO/control/features/m/tasks.yaml"
git -C "$MO" init -q
out="$($PY "$BS" --root "$MO" --format controller --work-item control/features/m 2>&1 | sed -n '3,4p')"
[ "$out" = $'repos: web=mono · shared=mono\nREADY: mono T1 T2' ] && ok "monorepo: unit tanpa path satu lane dengan repo root" || bad "monorepo: lane unit tanpa path" "$out"
err="$(lean --format controller 2>&1 >/dev/null)"; rc=$?
[ "$rc" = 2 ] && grep -qF 'butuh --work-item' <<<"$err" && ok "controller tanpa --work-item → exit 2" || bad "controller tanpa --work-item → exit 2" "rc=$rc $err"
mkprod
out="$($PY "$BS" --root "$P" --format controller --work-item control/features/checkout-v2 2>&1)"; rc=$?
[ "$rc" = 0 ] && grep -qxF 'READY: —' <<<"$out" && grep -qxF 'gates queued: G3 api×M2 "floor-scan T6 (token)"' <<<"$out" \
  && ok "controller prod checkout-v2: READY — + gate G3" || bad "controller prod checkout-v2" "rc=$rc"$'\n'"$out"

# === fix(review) 2026-10-20: baris task/carry, multi-target, work-item salah, penanda peta, korup ===
mklean
J="$(lean --format task --task T3,T10 --work-item $LX)"
l3="$(jq -r '.tasks[0].line' <<<"$J")"; e3="$(jq -r '.tasks[0].end_line' <<<"$J")"; e10="$(jq -r '.tasks[1].end_line' <<<"$J")"
TY="$LN/$LX/tasks.yaml"
[ "$(sed -n "${l3}p" "$TY")" = "      - id: T3" ] && sed -n "${l3},${e3}p" "$TY" | grep -qx '        status: pending' \
  && [ "$(sed -n "$((e3+1))p" "$TY")" = "      - id: T4" ] && ok "task: line/end_line = blok task (Read offset/limit + Edit)" || bad "task: line/end_line" "$J"
[ "$e10" = "$(wc -l < "$TY" | tr -d ' ')" ] && ok "task terakhir: end_line = baris terakhir file" || bad "task terakhir: end_line" "$e10"
J="$(lean --format carry --for T3 --work-item $LX)"
lc="$(jq -r '.notes[0].line_no' <<<"$J")"
[ "$(sed -n "${lc}p" "$LN/$LX/carry.yaml")" = "  - id: C1" ] && ok "carry: line_no = baris '- id:' entri (beda dari .line teks legacy)" || bad "carry: line_no" "$J"
$PY - "$LN/$LX/carry.yaml" <<'PY2'
import sys; p = sys.argv[1]; s = open(p).read()
add = ('notes:\n'
       '  - id: C8\n    for: [T1, T9]\n    from: review T1\n    at: 2026-10-20\n    note: "multi, satu done"\n'
       '  - id: C7\n    for: "T5, T9"\n    from: review T1\n    at: 2026-10-20\n    note: "multi koma"\n'
       '  - id: C6\n    for: [T3, T5]\n    from: review T1\n    at: 2026-10-20\n    note: "multi list"\n')
assert s.count('notes:\n') == 1; open(p, 'w').write(s.replace('notes:\n', add, 1))
PY2
J="$(lean --format carry --for T5 --work-item $LX)"; chk "carry multi-target: T5 ← C7,C6"            '[.notes[].id]' '["C7","C6"]'
J="$(lean --format carry --for T9 --work-item $LX)"; chk "carry multi-target: T9 ← C8 (T1 done),C7" '[.notes[].id]' '["C8","C7"]'
J="$(lean --format carry --for T3 --work-item $LX)"; chk "carry multi-target: T3 ← C6,C1"            '[.notes[].id]' '["C6","C1"]'
out="$(line $LX '/^carry:/p')"; [ "$out" = "carry: T9×2 · T5×2 · T3×2 · ship×1 · gate:M2/api×1 · next C9" ] \
  && ok "controller: hitung titipan multi-target per target" || bad "controller: titipan multi-target" "$out"
for f in controller "task --task T1" "carry --for T1"; do
  err="$(lean --format $f --work-item control/features/nope 2>&1 >/dev/null)"; rc=$?
  [ "$rc" = 2 ] && grep -qF 'tasks.yaml tidak ada' <<<"$err" && ok "--work-item salah ($f) → exit 2" || bad "--work-item salah ($f)" "rc=$rc $err"
done
mklean
$PY - "$LN/$LX/tasks.yaml" <<'PY2'
import sys; p = sys.argv[1]; s = open(p).read()
old = "        desc: orders totals\n"
new = old + ("        manual:\n          - set env FOO\n"
             "        actions:\n          - migrate: add col total\n            kind: additive\n          - install: zod\n"
             "        mockup: mockups/totals.html\n")
assert s.count(old) == 1; s = s.replace(old, new)
s = s.replace("        desc: orders page\n", "        desc: orders page\n        actions: [install: zod]\n", 1)
s = s.replace("        desc: orders endpoint\n", "        desc: orders endpoint\n        actions: [migrate: drop col]\n", 1)
for t in ("flaky seed", "tambah endpoint"):
    i = s.index(t); j = s.index("status: ", i); k = s.index("\n", j)
    s = s[:j] + "status: in_progress" + s[k:]
open(p, 'w').write(s)
PY2
out="$(line $LX '/^    T5 /p')"; [ "$out" = "    T5 api pending deps T3 [manual] [migrate:additive] [actions] [mockup] · orders totals" ] \
  && ok "peta: penanda manual/migrate/actions/mockup" || bad "peta: penanda" "$out"
out="$(line $LX '/^    T[34] /p')"; [ "$out" = $'    T3 api pending deps T1 [migrate:?] · orders endpoint\n    T4 web pending deps T2 [actions] · orders page' ] \
  && ok "peta: actions bentuk flow ([install: zod]) ikut ditandai" || bad "peta: actions flow" "$out"
out="$(line $LX '/^korup:/p')"; [ "$out" = "korup: T10 deps T99 (tak dikenal) · api in_progress ganda T8,T9" ] \
  && ok "korup: deps tak dikenal + in_progress ganda satu repo" || bad "korup" "$out"

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
