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
# temuan review akhir: pointer elicitation.md bocor ke discovery (D10) · Q&A kanal notif build-unattended interaktif · (Recommended) di gate
grep -qF '`discovery` & `init` TIDAK pakai kotak' "$SRC/rules/elicitation.md" \
  && ok "R4 pointer elicitation.md menyebut pengecualian discovery/init" || bad "R4 pointer elicitation.md tanpa pengecualian discovery/init"
grep -qF 'Pengecualian: Q&A kanal notif' "$RULE" && grep -qF 'Q&A SEKALI lewat kotak `AskUserQuestion`' "$SRC/skills/build/SKILL.md" \
  && ok "R5 Q&A kanal notif build-unattended interaktif = kotak" || bad "R5 Q&A kanal notif build-unattended interaktif belum dikecualikan"
grep -qF 'TANPA label "(Recommended)" di opsi gate' "$RULE" \
  && ok "R6 gate tanpa label (Recommended)" || bad "R6 gate masih boleh label (Recommended)"

# --- S. baris rujukan di SKILL.md (tepat sekali, 2 baris di bawah H1) ---
LINE='> **Titik tunggu attended → `AskUserQuestion`:** tiap gate approve/revisi, Q&A keputusan, & konfirmasi yang nunggu jawaban user — tulis konten (draft/diff/ringkasan) sebagai teks DULU, lalu tanya lewat tool `AskUserQuestion` (pertanyaan pendek, opsi bawa konsekuensi); JANGAN akhiri turn dengan pertanyaan teks (tak memicu push Remote Control). Unattended/headless tetap tak pernah bertanya. Detail: `${CLAUDE_PLUGIN_ROOT}/rules/ask-user.md`.'
EXCL=" discovery init render-docs "   # discovery/init = keputusan user (spec D10); render-docs = tanpa titik tunggu
case "$LINE" in
  *subagent*) bad "S0 baris rujukan memuat 'subagent' (generator kimi bakal nyuntik pointer)";;
  *)          ok  "S0 baris rujukan bebas kata 'subagent'";;
esac
for f in "$SRC"/skills/*/SKILL.md; do
  name="$(basename "$(dirname "$f")")"
  if [[ "$EXCL" == *" $name "* ]]; then
    grep -qF 'rules/ask-user.md' "$f" && bad "S1 $name dikecualikan tapi merujuk ask-user.md" || ok "S1 $name dikecualikan, bersih"
    continue
  fi
  n="$(grep -cxF -- "$LINE" "$f")"
  h="$(grep -n '^# ' "$f" | head -1 | cut -d: -f1)"
  l="$(grep -nxF -- "$LINE" "$f" | head -1 | cut -d: -f1)"
  if [ "$n" = 1 ] && [ -n "$h" ] && [ "$l" = "$((h+2))" ]; then
    ok "S2 $name: baris rujukan tepat sekali, 2 baris di bawah H1"
  else bad "S2 $name: baris rujukan (n=$n h1=$h baris=$l)"; fi
done
grep -qF 'Satu gate = satu panggilan `AskUserQuestion`' "$SRC/skills/build/reference.md" \
  && ok "S3 drain pagi: satu gate per panggilan" || bad "S3 drain pagi tanpa aturan satu gate per panggilan"

# --- D. tip setup push di guide + README ---
grep -qF 'Push when actions required' "$SRC/skills/guide/reference.md" \
  && ok "D1 guide cheatsheet: tip push" || bad "D1 guide cheatsheet tanpa tip push"
grep -qF 'Push when actions required' "$ROOT/README.md" \
  && ok "D2 README: tip push" || bad "D2 README tanpa tip push"

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
