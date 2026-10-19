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

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
