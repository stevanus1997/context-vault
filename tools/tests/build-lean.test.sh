#!/usr/bin/env bash
# Kontrak prosa build hemat-context (spec docs/superpowers/specs/2026-10-20-build-lean-controller-design.md).
# Jalanin: bash tools/tests/build-lean.test.sh  (exit 0 = semua lulus)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
B="$ROOT/plugin/skills/build"
PASS=0; FAIL=0
ok()    { PASS=$((PASS+1)); echo "ok   - $1"; }
bad()   { FAIL=$((FAIL+1)); echo "FAIL - $1"; }
has()   { grep -qF -- "$2" "$1" && ok "$3" || bad "$3"; }   # has <file> <string> <label>
hasnt() { grep -qF -- "$2" "$1" && bad "$3" || ok "$3"; }

# === T4: reference dipecah ===
grep -qE '^## [A-I]\. ' "$B/reference.md" && bad "reference.md masih memuat badan section" || ok "reference.md = indeks saja"
for f in $(grep -oE '`reference/[a-z]-[a-z-]+\.md`' "$B/reference.md" | tr -d '`'); do
  L="$(basename "$f" | cut -c1 | tr a-z A-Z)"
  [ -f "$B/$f" ] && head -1 "$B/$f" | grep -qE "^## $L\. " && ok "indeks → $f" || bad "indeks → $f (hilang / heading salah)"
done

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
