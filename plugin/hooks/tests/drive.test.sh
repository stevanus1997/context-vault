#!/usr/bin/env bash
# Test drive.sh (outer-loop driver) — `claude` PALSU di PATH menulis last-run.md per skenario.
# Jalanin: bash plugin/hooks/tests/drive.test.sh  (exit 0 = semua lulus)
# Pola sama dengan auto-title.test.sh (counter PASS/FAIL).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
DRIVE_SRC="$ROOT/plugin/template/.claude/drive.sh"
BS_SRC="$ROOT/plugin/template/.claude/build_status.py"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL - $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; }
command -v jq >/dev/null 2>&1 || { echo "butuh jq"; exit 1; }

# setup <skenario>  — skenario = token per baris, satu token per putaran claude:
#   [slow:]<outcome>:<done>[:<review>:<blockers>]  |  garbage  |  nofile
#   slow: = claude palsu tidur 1.2 dtk + salin drive.json (heartbeat) ke .claude/hb-seen dulu
# Menyiapkan produk palsu yang lolos precheck (notify.sh, allowlist non-git, trust, python3 + build_status.py).
setup() {
  export HOME="$(mktemp -d)"
  PROD="$(cd "$(mktemp -d)" && pwd)"
  mkdir -p "$PROD/.claude" "$PROD/control/features/fitur-x" "$HOME/bin"
  cp "$DRIVE_SRC" "$PROD/.claude/drive.sh"; chmod +x "$PROD/.claude/drive.sh"
  cp "$BS_SRC" "$PROD/.claude/build_status.py"
  printf 'status: active\n' > "$PROD/control/features/fitur-x/feature.yaml"
  printf '%s\n' 'feature: fitur-x' 'milestones:' '  - id: M1' '    title: Satu' '    tasks:' \
    '      - id: T1' '        unit: api' '        desc: satu' '        status: done' \
    '      - id: T2' '        unit: api' '        desc: dua' '        deps: [T1]' '        status: pending' \
    > "$PROD/control/features/fitur-x/tasks.yaml"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$PROD/.claude/notify.sh"; chmod +x "$PROD/.claude/notify.sh"
  printf '{"permissions":{"allow":["Bash(git status:*)","Bash(pnpm test:*)"]}}\n' > "$PROD/.claude/settings.json"
  jq -n --arg p "$PROD" '{projects:{($p):{hasTrustDialogAccepted:true}}}' > "$HOME/.claude.json"
  printf '%s\n' "$1" > "$PROD/.claude/scenario"
  : > "$PROD/.claude/calls"
  cat > "$HOME/bin/claude" <<'FAKE'
#!/usr/bin/env bash
# claude palsu: tiap panggilan = satu putaran → baca token ke-N skenario → tulis last-run.md
DIR="$(pwd)"; REPORT="$DIR/control/features/fitur-x/last-run.md"
echo "$*" >> "$DIR/.claude/calls"
n="$(wc -l < "$DIR/.claude/calls" | tr -d ' ')"
tok="$(sed -n "${n}p" "$DIR/.claude/scenario")"
case "$tok" in
  slow:*) tok="${tok#slow:}"; sleep 1.2
          HB="$DIR/.claude/build/fitur-x/drive.json"; [ -f "$HB" ] && cp "$HB" "$DIR/.claude/hb-seen" ;;
esac
case "$tok" in
  nofile)  rm -f "$REPORT"; exit 0 ;;
  garbage) printf 'outcome: weird\ndone: 1\n' > "$REPORT"; exit 0 ;;
esac
IFS=: read -r o d r b <<< "$tok"
{ printf 'outcome: %s\ndone: %s\npending: 0\n' "$o" "$d"
  [ -n "${r:-}" ] && printf 'review: %s\nblockers: %s\n' "$r" "${b:-0}"
  printf 'reason: test\n'; } > "$REPORT"
exit 0
FAKE
  chmod +x "$HOME/bin/claude"
}
drive() { (cd "$PROD" && PATH="$HOME/bin:$PATH" bash .claude/drive.sh fitur-x 1 2>&1); }
calls() { wc -l < "$PROD/.claude/calls" | tr -d ' '; }

# 1. review → berhenti setelah 1 putaran, pesan review + angka
setup $'review:5:6:1'; out="$(drive)"
if grep -q 'outcome=review' <<<"$out" && grep -q '6 gate' <<<"$out" && [ "$(calls)" = 1 ]; then ok "review → stop 1 putaran + pesan '6 gate'"; else bad "review → stop 1 putaran + pesan" "$out"; fi

# 2. review tanpa baris review:/blockers: → tetap berhenti (toleran header lama)
setup $'review:5'; out="$(drive)"
if grep -q 'outcome=review' <<<"$out" && grep -q '? gate + ? blocker' <<<"$out" && [ "$(calls)" = 1 ]; then ok "review tanpa angka → tetap stop, fallback '?'"; else bad "review tanpa angka" "$out"; fi

# 3. continue → continue → done = 3 putaran, SELESAI
setup $'continue:3\ncontinue:6\ndone:9'; out="$(drive)"
if grep -q 'SELESAI' <<<"$out" && [ "$(calls)" = 3 ]; then ok "continue,continue,done → 3 putaran SELESAI"; else bad "continue→done" "$out"; fi

# 4. continue tanpa kenaikan done → mandek setelah putaran ke-2
setup $'continue:3\ncontinue:3\ncontinue:3'; out="$(drive)"
if grep -q 'NOL kemajuan' <<<"$out" && [ "$(calls)" = 2 ]; then ok "nol kemajuan → stop putaran 2"; else bad "nol kemajuan" "$out"; fi

# 5. halt → berhenti 1 putaran, pesan abnormal
setup $'halt:2'; out="$(drive)"
if grep -q 'outcome=halt' <<<"$out" && [ "$(calls)" = 1 ]; then ok "halt → stop 1 putaran"; else bad "halt" "$out"; fi

# 6. outcome tak dikenal → fail-safe stop
setup $'garbage'; out="$(drive)"
if grep -q 'tak dikenal' <<<"$out" && [ "$(calls)" = 1 ]; then ok "outcome asing → fail-safe stop"; else bad "outcome asing" "$out"; fi

# 7. last-run.md tak ditulis → stop
setup $'nofile'; out="$(drive)"
if grep -q 'last-run.md tak ada' <<<"$out" && [ "$(calls)" = 1 ]; then ok "last-run.md absen → stop"; else bad "last-run absen" "$out"; fi

# 8. precheck notify.sh absen → exit 1, nol putaran
setup $'done:1'; rm -f "$PROD/.claude/notify.sh"; out="$(drive)"
if grep -q 'notify.sh belum diset' <<<"$out" && [ "$(calls)" = 0 ]; then ok "precheck notify absen → exit tanpa putaran"; else bad "precheck notify" "$out"; fi

# 9. precheck allowlist: cuma git + rule apply-migrate → STOP (rule migrate bukan bukti verifikasi stack)
setup $'done:1'; printf '{"permissions":{"allow":["Bash(git status:*)","Bash(alembic upgrade:*)"]}}\n' > "$PROD/.claude/settings.json"; out="$(drive)"
if grep -q 'allowlist verifikasi stack belum keisi' <<<"$out" && [ "$(calls)" = 0 ]; then ok "precheck allowlist: rule migrate saja → STOP"; else bad "precheck allowlist migrate-only" "$out"; fi

# 10. precheck allowlist kosong → STOP
setup $'done:1'; printf '{"permissions":{"allow":[]}}\n' > "$PROD/.claude/settings.json"; out="$(drive)"
if grep -q 'allowlist verifikasi stack belum keisi' <<<"$out" && [ "$(calls)" = 0 ]; then ok "precheck allowlist kosong → STOP"; else bad "precheck allowlist kosong" "$out"; fi

# 11. precheck workspace belum di-trust → STOP
setup $'done:1'; jq -n --arg p "$PROD" '{projects:{($p):{hasTrustDialogAccepted:false}}}' > "$HOME/.claude.json"; out="$(drive)"
if grep -q 'workspace belum di-trust' <<<"$out" && [ "$(calls)" = 0 ]; then ok "precheck trust → STOP"; else bad "precheck trust" "$out"; fi

# 12. baris progres (non-TTY): ticker cetak state dari build_status.py selama claude jalan
setup $'slow:done:2'; out="$(DRIVE_TICK=0.3 drive)"
if grep -q '^\[drive\] putaran 1 · 1/2' <<<"$out"; then ok "baris progres '[drive] putaran 1 · 1/2…' (non-TTY)"; else bad "baris progres non-TTY" "$out"; fi
HBS="$PROD/.claude/hb-seen"
if [ -f "$HBS" ] && [ "$(jq .round "$HBS")" = 1 ] && [ "$(jq .max_hours "$HBS")" = 1 ] && [ ! -e "$PROD/.claude/build/fitur-x/drive.json" ]; then
  ok "heartbeat drive.json ada saat claude jalan (round 1, max_hours 1) & dihapus waktu keluar"
else bad "heartbeat drive.json" "hb-seen=$(cat "$HBS" 2>&1) sisa=$(ls "$PROD/.claude/build/fitur-x" 2>&1)"; fi
if [ "$(grep -c '^\[drive\] putaran 1 · 1/2' <<<"$out")" = 1 ]; then ok "non-TTY: baris sama nggak diulang tiap tick"; else bad "non-TTY: baris diulang" "$out"; fi

# 13. sesudah drive keluar: ticker + sleep anaknya mati, stdout nggak ditahan (tick panjang = sleep lama)
dleft() { pgrep -f "$PROD/.claude/drive.sh"; pgrep -f 'sleep 6.17'; }
setup $'slow:done:2'; SECONDS=0
(cd "$PROD" && DRIVE_TICK=6.17 PATH="$HOME/bin:$PATH" bash "$PROD/.claude/drive.sh" fitur-x 1 > "$PROD/drive.out" 2>&1) & dpid=$!
wait "$dpid"; dur=$SECONDS
s1="$(wc -c < "$PROD/drive.out")"; sleep 1; s2="$(wc -c < "$PROD/drive.out")"; left="$(dleft)"
if [ "$s1" = "$s2" ] && [ -z "$left" ] && [ "$dur" -lt 5 ]; then ok "keluar normal: output berhenti, nol proses sisa, selesai < 5 dtk"; else bad "ticker/sleep sisa" "dur=$dur s1=$s1 s2=$s2 sisa=[$left]"; fi
setup $'slow:done:2'; SECONDS=0; out="$(DRIVE_TICK=6.17 drive)"; dur=$SECONDS
if [ "$dur" -lt 5 ]; then ok "\$(drive) nggak nunggu sleep ticker (dur=${dur}s)"; else bad "\$(drive) ketahan sleep ticker" "dur=$dur"; fi

# 14. dibunuh (TERM) di tengah putaran → exit 130, heartbeat dihapus, nol proses sisa
setup $'slow:continue:1\ndone:2'
PATH="$HOME/bin:$PATH" DRIVE_TICK=6.17 bash "$PROD/.claude/drive.sh" fitur-x 1 > "$PROD/drive.out" 2>&1 & dpid=$!
sleep 0.5; kill -TERM "$dpid"; wait "$dpid"; rc=$?; sleep 0.3; left="$(dleft)"
if [ "$rc" = 130 ] && [ ! -e "$PROD/.claude/build/fitur-x/drive.json" ] && [ -z "$left" ] && [ "$(calls)" = 1 ]; then
  ok "TERM → exit 130, heartbeat hilang, ticker mati"
else bad "TERM di tengah putaran" "rc=$rc calls=$(calls) sisa=[$left] hb=$(ls "$PROD/.claude/build/fitur-x" 2>&1)"; fi

# 15. precheck python3 → STOP + instruksi, nol putaran
setup $'done:1'; out="$(DRIVE_PYTHON=/nonexistent drive)"; rc=$?
if [ "$rc" != 0 ] && grep -q 'butuh python3' <<<"$out" && grep -q 'xcode-select --install' <<<"$out" && [ "$(calls)" = 0 ]; then ok "precheck python3 absen → STOP"; else bad "precheck python3" "rc=$rc $out"; fi

# 16. precheck build_status.py absen → STOP, arahkan upgrade
setup $'done:1'; rm -f "$PROD/.claude/build_status.py"; out="$(drive)"; rc=$?
if [ "$rc" != 0 ] && grep -q "jalankan 'upgrade'" <<<"$out" && [ "$(calls)" = 0 ]; then ok "precheck build_status.py absen → STOP"; else bad "precheck build_status.py" "rc=$rc $out"; fi

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
