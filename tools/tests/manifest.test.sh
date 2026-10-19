#!/usr/bin/env bash
# Test manifest plugin — plugin.json cuma pakai key yang diterima Claude Code lama, versi marketplace.json sinkron.
# Jalanin: bash tools/tests/manifest.test.sh  (exit 0 = semua lulus)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PJ="$ROOT/plugin/.claude-plugin/plugin.json"
MJ="$ROOT/.claude-plugin/marketplace.json"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL - $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; }
command -v jq >/dev/null 2>&1 || { echo "butuh jq"; exit 1; }

# Key yang lolos `plugin validate` Claude Code 2.0.30 & 2.1.0. Skema manifest di sana strict: satu key
# asing (mis. "types") = SELURUH plugin gagal dimuat (nol skill, nol hook). Key baru → uji dulu di CC
# lama (spec 2026-10-19-build-status-panel §10.2), baru tambahkan di sini.
OLD_OK='["name","version","description","author","homepage","repository","license","keywords"]'
extra="$(jq -c --argjson ok "$OLD_OK" '[keys[] | select(. as $k | $ok | index($k) | not)]' "$PJ")"
[ "$extra" = "[]" ] && ok "plugin.json cuma pakai key yang diterima CC lama" || bad "plugin.json punya key yang ditolak CC lama" "$extra"

pv="$(jq -r .version "$PJ")"
mv="$(jq -r '.metadata.version' "$MJ")"
ev="$(jq -r '.plugins[] | select(.name == "context-vault") | .version' "$MJ")"
[ "$mv" = "$pv" ] && [ "$ev" = "$pv" ] && ok "marketplace.json (metadata + entri plugin) = versi plugin.json ($pv)" \
  || bad "versi marketplace.json tak sinkron" "plugin.json=$pv metadata=$mv entri=$ev"

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
