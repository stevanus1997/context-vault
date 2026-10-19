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

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
