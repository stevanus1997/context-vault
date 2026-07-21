#!/usr/bin/env bash
# Test generator build-kimi.sh — jalanin: bash tools/tests/build-kimi.test.sh (exit 0 = semua lulus)
# Pola sama dengan plugin/hooks/tests/auto-title.test.sh (counter PASS/FAIL).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GEN="$ROOT/tools/build-kimi.sh"
SRC="$ROOT/plugin"
DST="$ROOT/plugin-kimi"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL - $1"; }

# Snapshot kebersihan plugin/ SEBELUM generator jalan (pembanding test #2)
BEFORE="$(git -C "$ROOT" status --porcelain -- plugin/)"

# --- 1. generator ada & exit 0 ---
if bash "$GEN"; then ok "generator exit 0"; else bad "generator exit 0"; fi

# --- 2. plugin/ untouched (source read-only) ---
AFTER="$(git -C "$ROOT" status --porcelain -- plugin/)"
if [ "$BEFORE" = "$AFTER" ]; then ok "plugin/ tak berubah"; else bad "plugin/ BERUBAH — generator nulis ke source!"; fi

# --- 3. nol residu CLAUDE_PLUGIN_ROOT ---
if [ -d "$DST" ] && ! grep -rq 'CLAUDE_PLUGIN_ROOT' "$DST"; then ok "nol residu CLAUDE_PLUGIN_ROOT"; else bad "masih ada residu CLAUDE_PLUGIN_ROOT di plugin-kimi/"; fi

# --- 4. manifest valid + version sync ---
MAN="$DST/.kimi-plugin/plugin.json"
if jq -e . "$MAN" >/dev/null 2>&1; then ok "manifest JSON valid"; else bad "manifest JSON valid"; fi
if [ "$(jq -r .version "$MAN" 2>/dev/null)" = "$(jq -r .version "$SRC/.claude-plugin/plugin.json")" ]; then
  ok "version manifest == version source"
else bad "version manifest != version source"; fi

# --- 6. hooks/ & .claude-plugin/ TIDAK ikut; tree wajib ada ---
[ ! -e "$DST/hooks" ]          && ok "hooks/ tidak ikut"          || bad "hooks/ ikut ke plugin-kimi/"
[ ! -e "$DST/.claude-plugin" ] && ok ".claude-plugin/ tidak ikut" || bad ".claude-plugin/ ikut ke plugin-kimi/"
for d in skills rules agents template; do
  [ -d "$DST/$d" ] && ok "tree $d/ ada" || bad "tree $d/ hilang"
done
[ -f "$DST/README.md" ] && grep -q 'GENERATED' "$DST/README.md" && ok "README GENERATED ada" || bad "README GENERATED hilang"

# --- jumlah SKILL.md sama dengan source (24 saat plan ditulis; assert kesetaraan, bukan angka) ---
NSRC="$(find "$SRC/skills" -name SKILL.md | wc -l | tr -d ' ')"
NDST="$(find "$DST/skills" -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')"
[ "$NSRC" = "$NDST" ] && ok "jumlah SKILL.md sama ($NDST)" || bad "jumlah SKILL.md beda (src=$NSRC dst=$NDST)"

# --- template ikut utuh termasuk dotdir .claude/ (produk hybrid, spec D6) ---
[ -f "$DST/template/.claude/drive.sh" ] && ok "template/.claude/ ikut (drive.sh ada)" || bad "template/.claude/ tak ikut utuh"

# --- 7. deterministik: dua kali jalan → identik ---
TMP="$(mktemp -d)"
cp -R "$DST" "$TMP/first"
if bash "$GEN" >/dev/null 2>&1 && diff -rq "$TMP/first" "$DST" >/dev/null 2>&1; then
  ok "deterministik (2x jalan identik)"
else bad "TIDAK deterministik (2x jalan beda)"; fi
rm -rf "$TMP"

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
