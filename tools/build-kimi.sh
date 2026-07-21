#!/usr/bin/env bash
# tools/build-kimi.sh — generator plugin-kimi/ (artefak Kimi Code) dari plugin/ (source of truth Claude).
# plugin/ = READ-ONLY bagi skrip ini; guard before/after di bawah memaksa itu.
# Regen-dari-nol tiap jalan → idempoten by construction, deterministik (tanpa timestamp).
# Spec: docs/superpowers/specs/2026-07-21-kimi-code-port-design.md
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/plugin"
DST="$ROOT/plugin-kimi"

die() { echo "[build-kimi] $*" >&2; exit 1; }
command -v jq   >/dev/null 2>&1 || die "butuh jq"
command -v perl >/dev/null 2>&1 || die "butuh perl"
[ -d "$SRC" ] || die "plugin/ tidak ditemukan — jalankan dari dalam repo context-vault"

# Guard: snapshot status plugin/ SEBELUM (dibandingkan lagi di akhir — source wajib untouched)
BEFORE="$(git -C "$ROOT" status --porcelain -- plugin/)"

# --- 1. Regen dari nol ---
rm -rf "$DST"
mkdir -p "$DST/.kimi-plugin"

# --- 2. Copy selektif (spec D6): hooks/ & .claude-plugin/ SENGAJA tidak ikut ---
cp -R "$SRC/skills"   "$DST/skills"
cp -R "$SRC/rules"    "$DST/rules"
cp -R "$SRC/agents"   "$DST/agents"
cp -R "$SRC/template" "$DST/template"

# --- 3. Rewrite path root (spec D3): ${CLAUDE_PLUGIN_ROOT} → ${KIMI_SKILL_DIR}/../.. di semua .md ---
find "$DST" -type f -name '*.md' -exec perl -pi -e 's|\$\{CLAUDE_PLUGIN_ROOT\}|\$\{KIMI_SKILL_DIR}/../..|g' {} +

# --- 4. Manifest (spec D2): name/description/version/author sync dari source via jq ---
jq '{name, description, version, author}' "$SRC/.claude-plugin/plugin.json" > "$DST/.kimi-plugin/plugin.json"

# --- 5. README penanda GENERATED ---
cat > "$DST/README.md" <<'EOF'
# plugin-kimi — GENERATED, JANGAN EDIT DI SINI

Tree ini artefak hasil generate untuk **Kimi Code CLI**.
Source of truth: `../plugin/` (format Claude Code).

Edit di `plugin/`, lalu regen: `bash tools/build-kimi.sh` (test: `bash tools/tests/build-kimi.test.sh`).
Spec: `docs/superpowers/specs/2026-07-21-kimi-code-port-design.md`
EOF

# --- Helper injeksi: sisip isi <file-teks> tepat di bawah frontmatter (setelah '---' kedua) ---
inject_below_frontmatter() { # <target-md> <file-teks-injeksi>
  local f="$1" ins="$2"
  awk -v insfile="$ins" '
    BEGIN{n=0}
    { print
      if ($0=="---" && n<2) { n++
        if (n==2) { print ""; while ((getline line < insfile) > 0) print line }
      }
    }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

# (Injeksi D4/D5 diisi Task 2 — urutan: pointer subagent dulu, lalu banner build.)

# --- 9. Self-checks (fail keras, jangan diam-diam) ---
AFTER="$(git -C "$ROOT" status --porcelain -- plugin/)"
[ "$BEFORE" = "$AFTER" ] || die "SELF-CHECK GAGAL: plugin/ berubah — generator HARUS read-only terhadap source"
grep -rq 'CLAUDE_PLUGIN_ROOT' "$DST" && die "SELF-CHECK GAGAL: residu CLAUDE_PLUGIN_ROOT di plugin-kimi/"
jq -e . "$DST/.kimi-plugin/plugin.json" >/dev/null || die "SELF-CHECK GAGAL: manifest bukan JSON valid"

echo "[build-kimi] OK — plugin-kimi/ regenerated ($(find "$DST/skills" -name SKILL.md | wc -l | tr -d ' ') skills)"
