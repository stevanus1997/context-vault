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

# === T5: brief-writer + §K ===
A="$ROOT/plugin/agents/brief-writer.md"
has "$A" "name: brief-writer" "agent: name"
has "$A" "model: inherit" "agent: model inherit (D5)"
has "$A" "tools: Read, Grep, Glob, Bash, Write" "agent: tools"
for k in "brief:" "rules:" "titipan:" "deps:" "ambigu:" "tier:"; do has "$A" "$k" "agent: kunci balikan $k"; done
has "$A" "Jangan menebak." "agent: lapor ambigu, bukan nebak"
K="$B/reference/k-prompt-dispatch.md"
has "$K" "Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT" "§K: status implementer"
has "$K" "OVERRIDE format balikan template" "§K: override format reviewer"
has "$K" "task-<id>-review-r<n>.md" "§K: file review"
has "$K" "cap 3 ronde" "§K: cap 3 ronde tetap (D12)"
has "$B/reference/b-brief.md" "**brief-writer**" "§B: perakit = brief-writer"
has "$B/reference.md" "reference/k-prompt-dispatch.md" "indeks: §K"

# === T6: titipan ===
J="$B/reference/j-state-titipan.md"
has "$J" "# carry.yaml — titipan antar-task build. Penulis tunggal: controller build. Entri terbaru di ATAS." "§J: header carry.yaml"
has "$J" "Kandidat debt BUKAN titipan" "§J: debt tetap ke debt.yaml (D10)"
has "$B/reference.md" "reference/j-state-titipan.md" "indeks: §J"
has "$B/SKILL.md" "--format carry --for gate:<M>/<unit>" "SKILL gate: agenda titipan"
has "$B/SKILL.md" "--format carry --for simplify" "SKILL 7a: titipan simplify"
has "$B/SKILL.md" "**Titipan legacy (sekali, attended):**" "SKILL step 1: konversi legacy"
has "$B/SKILL.md" "WAJIB sebelum tick: brief-writer cuma tahu yang tertulis" "SKILL step 2: titipan sebelum tick (D6)"
has "$ROOT/plugin/skills/ship/SKILL.md" "--format carry --for ship" "ship: titipan ship"

# === T7: controller pakai peta + brief-writer ===
S="$B/SKILL.md"
has "$S" "= **indeks**" "SKILL: reference = indeks, baca per step"
has "$S" "--format controller --work-item <work-item>" "SKILL step 1: ringkasan state"
has "$S" 'Bash(python3 .claude/build_status.py:*)' "SKILL step 1: cek allowlist sebelum panggil (unattended)"
has "$S" 'jalankan `/upgrade` biar build hemat context' "SKILL step 1: WARN degrade"
has "$S" "**Brief dirakit subagent \`context-vault:brief-writer\`**" "SKILL step 3: brief-writer"
has "$S" '`hold: "NEEDS_CONTEXT: <pertanyaan verbatim>"`, lanjut task lain' "SKILL step 3: ambigu unattended → hold"
hasnt "$S" "Rakit **BRIEF** LENGKAP dari task" "SKILL: controller tak merakit brief lagi"
has "$S" "dispatch SATU subagent \`context-vault:critic\`" "SKILL step 1: pre-flight via subagent"
has "$B/reference/e-status-resume.md" "**Tanpa membaca file utuh**" "§E: tulis status tanpa baca utuh"

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
