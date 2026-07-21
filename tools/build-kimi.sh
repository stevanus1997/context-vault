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
# Temuan empiris kimi 0.28.1 (acceptance): skills TIDAK auto-discover — wajib deklarasi
# eksplisit "skills": "./skills/". skillInstructions = mapping harness level-manifest
# (pola plugin superpowers yang terbukti jalan di kimi versi sama; komplemen pointer D4).
SKILL_INSTRUCTIONS='Mapping harness Kimi Code untuk skill context-vault:
- Sebelum dispatch subagent apa pun, baca rules/kimi-harness.md di root plugin (dua level di atas folder skill yang sedang jalan).
- Dispatch subagent context-vault:critic / context-vault:security-critic → tool Agent subagent_type "explore" dengan prompt = SELURUH isi agents/critic.md / agents/security-critic.md + konteks tugas.
- Implementer/worker nulis-kode → subagent_type "coder"; reviewer/reader read-only → subagent_type "explore".
- build <fitur> --unattended DITOLAK di Kimi Code (belum diporting — fase 2); tawarkan build interaktif atau lane unattended via Claude Code.'
jq --arg si "$SKILL_INSTRUCTIONS" \
   '{name, description, version, author, skills: "./skills/", skillInstructions: $si}' \
   "$SRC/.claude-plugin/plugin.json" > "$DST/.kimi-plugin/plugin.json"

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

# --- 6. rules/kimi-harness.md (spec D4) — mapping subagent → sub-agent bawaan Kimi ---
cat > "$DST/rules/kimi-harness.md" <<'EOF'
# Harness Kimi Code — mapping subagent

Kimi Code TIDAK punya custom agent file (padanan `agents/*.md` Claude tak ada).
Sub-agent yang tersedia hanya built-in: `coder` (baca+tulis+shell), `explore`
(read-only), `plan` (desain, tanpa shell). Sub-agent TIDAK menerima custom
system prompt → seluruh isi file agent dimasukkan sebagai bagian PROMPT tugas.

| Dispatch di skill | Di Kimi Code |
|---|---|
| subagent `context-vault:critic` | sub-agent `explore` (read-only); prompt = SELURUH isi `agents/critic.md` di root plugin (baca via Read) + konteks tugas |
| subagent `context-vault:security-critic` | sub-agent `explore`; prompt = SELURUH isi `agents/security-critic.md` di root plugin + diff/konteks |
| implementer / worker nulis-kode (build, fix, dst) | sub-agent `coder` |
| reviewer / reader read-only | sub-agent `explore` |

Root plugin = dua level di atas folder skill yang sedang jalan (`${KIMI_SKILL_DIR}/../..`).
EOF

# --- 7. Pointer D4 — inject di SKILL.md yang menyebut 'subagent' (grep-driven, bukan hardcode) ---
PTR_FILE="$(mktemp)"
printf '%s\n' '> **Harness Kimi Code:** sebelum dispatch subagent apa pun, baca `${KIMI_SKILL_DIR}/../../rules/kimi-harness.md` (mapping critic/implementer → sub-agent bawaan Kimi).' > "$PTR_FILE"
for f in "$DST"/skills/*/SKILL.md; do
  grep -qi 'subagent' "$f" || continue
  inject_below_frontmatter "$f" "$PTR_FILE"
done
rm -f "$PTR_FILE"

# --- 8. Banner D5 — build/SKILL.md (jalan SESUDAH pointer → banner mendarat DI ATAS pointer) ---
BANNER_FILE="$(mktemp)"
cat > "$BANNER_FILE" <<'EOF'
> ⛔ **HARNESS KIMI CODE — `--unattended` BELUM diporting (fase 2).**
> `kimi -p` auto-approve SEMUA tool; rem allowlist/deny belum terbukti berlaku di mode itu.
> Kalau user minta `build <fitur> --unattended` di sini: TOLAK, jelaskan alasan di atas,
> lalu tawarkan build interaktif biasa ATAU lane unattended via Claude Code
> (`bash .claude/drive.sh <fitur>`) di repo yang sama.
EOF
inject_below_frontmatter "$DST/skills/build/SKILL.md" "$BANNER_FILE"
rm -f "$BANNER_FILE"

# --- 8b. Note D5 — build/reference.md, sesudah heading pertama ber-'unattended' ---
REF="$DST/skills/build/reference.md"
grep -qiE '^#{1,6} .*unattended' "$REF" || die "anchor heading 'unattended' di build/reference.md tak ketemu — source berubah, sesuaikan generator"
awk '
  done==0 && /^#/ && tolower($0) ~ /unattended/ {
    print; print ""
    print "> ⛔ **Harness Kimi Code:** bagian unattended di file ini BELUM berlaku di Kimi — lihat banner di `SKILL.md` (fase 2)."
    done=1; next
  }
  { print }' "$REF" > "$REF.tmp" && mv "$REF.tmp" "$REF"

# --- 9. Self-checks (fail keras, jangan diam-diam) ---
AFTER="$(git -C "$ROOT" status --porcelain -- plugin/)"
[ "$BEFORE" = "$AFTER" ] || die "SELF-CHECK GAGAL: plugin/ berubah — generator HARUS read-only terhadap source"
grep -rq 'CLAUDE_PLUGIN_ROOT' "$DST" && die "SELF-CHECK GAGAL: residu CLAUDE_PLUGIN_ROOT di plugin-kimi/"
jq -e . "$DST/.kimi-plugin/plugin.json" >/dev/null || die "SELF-CHECK GAGAL: manifest bukan JSON valid"

echo "[build-kimi] OK — plugin-kimi/ regenerated ($(find "$DST/skills" -name SKILL.md | wc -l | tr -d ' ') skills)"
