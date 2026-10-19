#!/usr/bin/env bash
# Test aturan titik tunggu attended (rules/ask-user.md) — jalanin: bash tools/tests/ask-user.test.sh (exit 0 = semua lulus)
# Pola sama dengan tools/tests/build-kimi.test.sh (counter PASS/FAIL).
# Spec: docs/superpowers/specs/2026-10-19-attended-ask-push-design.md
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/plugin"
RULE="$SRC/rules/ask-user.md"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL - $1"; }

# --- R. aturan rules/ask-user.md ---
[ -f "$RULE" ] && ok "R1 rules/ask-user.md ada" || bad "R1 rules/ask-user.md hilang"
for kw in 'AskUserQuestion' 'Konten dulu, kotak belakangan' 'Push when actions required' 'Unattended/headless: DILARANG' 'Dikecualikan: `discovery` & `init`' 'Subagent tidak memanggil' 'Pilihan > 4'; do
  grep -qF -- "$kw" "$RULE" 2>/dev/null && ok "R2 aturan memuat: $kw" || bad "R2 aturan tanpa: $kw"
done
grep -qF 'rules/ask-user.md' "$SRC/rules/elicitation.md" \
  && ok "R3 elicitation.md menunjuk ask-user.md" || bad "R3 elicitation.md tanpa pointer ask-user.md"

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
