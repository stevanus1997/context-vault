#!/usr/bin/env bash
# Test drive.sh (outer-loop driver) — `claude` PALSU di PATH menulis last-run.md per skenario.
# Jalanin: bash plugin/hooks/tests/drive.test.sh  (exit 0 = semua lulus)
# Pola sama dengan auto-title.test.sh (counter PASS/FAIL).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
DRIVE_SRC="$ROOT/plugin/template/.claude/drive.sh"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL - $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; }
command -v jq >/dev/null 2>&1 || { echo "butuh jq"; exit 1; }

# setup <skenario>  — skenario = token per baris, satu token per putaran claude:
#   <outcome>:<done>[:<review>:<blockers>]  |  garbage  |  nofile
# Menyiapkan produk palsu yang lolos precheck (notify.sh, allowlist non-git, trust).
setup() {
  export HOME="$(mktemp -d)"
  PROD="$(cd "$(mktemp -d)" && pwd)"
  mkdir -p "$PROD/.claude" "$PROD/control/features/fitur-x" "$HOME/bin"
  cp "$DRIVE_SRC" "$PROD/.claude/drive.sh"; chmod +x "$PROD/.claude/drive.sh"
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
if grep -q 'outcome=review' <<<"$out" && [ "$(calls)" = 1 ]; then ok "review tanpa angka → tetap stop"; else bad "review tanpa angka" "$out"; fi

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
setup $'done:1'; rm -f "$PROD/.claude/notify.sh"; out="$(drive)"; rc=$?
if grep -q 'notify.sh belum diset' <<<"$out" && [ "$(calls)" = 0 ]; then ok "precheck notify absen → exit tanpa putaran"; else bad "precheck notify" "$out"; fi

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
