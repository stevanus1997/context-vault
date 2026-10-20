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
has "$A" "tools: Read, Bash, Write" "agent: tools tanpa Grep/Glob (CC tak punya)"
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

# === T8: jalur review ===
has "$S" "SELALU lewat git di SEMUA mode" "SKILL step 4: paket diff via git (D11)"
has "$S" "**override format balikan**" "SKILL step 4: override format reviewer"
has "$S" 'path file review `task-<id>-review-r<n>.md`' "SKILL step 4: re-dispatch tunjuk file review"
has "$S" "controller MEMUTUSKAN tiap item ⚠️ sendiri" "SKILL step 4: keputusan ⚠️ tetap controller"
has "$S" "**Cap maksimal 3 ronde**" "SKILL step 4: cap 3 ronde tak berubah (D12)"
has "$B/reference/a-pinjam-sdd.md" "cap 3 ronde = keputusan desain user" "§A: re-review scoped/resume tidak diadopsi"
n="$(grep -rlF 'scripts/review-package' "$B" | grep -v 'a-pinjam-sdd.md' | wc -l | tr -d ' ')"
[ "$n" = 0 ] && ok "review-package hanya disebut di §A (tidak dipakai)" || bad "review-package masih dipanggil di luar §A ($n file)"
hasnt "$B/reference/e-status-resume.md" 'diff via `review-package`' "§E: paket review via git"

# === T10: fallback headless (probe 2026-10-20: Read/Glob plugin-cache dari subagent ditolak di claude -p) ===
has "$S" '(c) mode unattended DAN allowlist tak memuat `Read(~/.claude/plugins/cache/**)`' "SKILL degrade (c): hanya bila allowlist Read plugin absen"

# === final review C-1: legacy tetap dibaca sampai legacy_converted ===
has "$J" "legacy_converted:" "§J: penanda konversi legacy"
has "$K" "legacy_converted:" "§K: subagent konversi set penanda + tak menimpa"
has "$S" "SEBELUM titipan pre-flight ditulis" "SKILL step 1: konversi legacy dulu"
has "$ROOT/plugin/skills/ship/SKILL.md" "legacy_converted:" "ship: fallback baca legacy sampai dikonversi"

# === final review I-1/I-2/I-4/I-6: harness tanpa Glob, degrade lengkap, kontrak unattended mandiri ===
hasnt "$K" "pakai tool **Glob**" "§K: <sdd> tak bergantung tool Glob (main session tak punya)"
hasnt "$S" "tanpa titipan resmi" "SKILL degrade: titipan tetap dibaca (I-2)"
has "$S" "titipan dibaca sendiri: \`<work-item>/carry.yaml\`" "SKILL degrade: fallback baca carry.yaml + legacy (I-2)"
has "$S" "(a) ATAU (b) → **cara lama penuh**" "SKILL degrade (a) juga cara lama + WARN (I-6)"
has "$S" "(degrade (c) step 1: controller merakit sendiri)" "SKILL step 3: pengecualian degrade (c)"
has "$S" "berlaku walau §J tak terbaca" "SKILL step 2: kontrak minimum carry.yaml inline (I-4)"

# === review independen sesi desain 2026-10-20: Read plugin di headless, tanpa Grep/Glob, catatan reviewer, penanda peta ===
TS="$ROOT/plugin/template/.claude/settings.json"
has "$TS" '"Read(~/.claude/plugins/cache/**)"' "template: allowlist Read cache plugin (probe headless: tanpa ini ditolak)"
has "$TS" '"Read(~/.claude/plugins/installed_plugins.json)"' "template: allowlist Read installed_plugins.json (<sdd>)"
hasnt "$TS" '"Read(~/.claude/plugins/**)"' "template: aturan baca tak selebar ~/.claude/plugins/**"
has "$ROOT/plugin/skills/upgrade/SKILL.md" 'Read(~/.claude/plugins/cache/**)' "upgrade: susulin allowlist Read plugin"
has "$S" 'stderr `invalid choice`' "SKILL degrade (b): salinan lama dibedakan dari file rusak"
has "$S" '`.claude/settings.local.json`' "SKILL degrade (a): cek dua file settings"
has "$S" "**Sebelum dispatch, ambil entri lengkap task terpilih**" "SKILL step 2: manual/actions/mockup dari entri lengkap"
has "$S" '(penanda peta `[migrate:additive]`)' "SKILL step 1: WARN migrate dari penanda peta"
has "$S" "≤5 baris \`catatan:\`" "SKILL step 4: catatan reviewer dirutekan controller"
has "$S" "Read rentang file, atau grep/sed bila Bash-nya di-allowlist" "SKILL step 4: bukti ⚠️ tanpa grep di unattended"
has "$K" "installed_plugins.json" "§K: <sdd> dari installed_plugins.json"
hasnt "$K" ".claude/build/_sdd" "§K: tanpa salinan _sdd"
has "$K" "catatan: n" "§K: verdict reviewer bawa catatan Minor/Important"
has "$K" "Maks 2 kali dispatch ulang" "§K: batas loop ambigu"
has "$K" "<root>/<wi>/task-<id>-brief.md" "§K: placeholder <wi> = folder scratch"
hasnt "$K" "<root>/.claude/build/<work-item>/" "§K: tak ada path scratch dua-makna"
hasnt "$A" "Glob" "agent: tak menyuruh Glob"
hasnt "$A" "Grep" "agent: tak menyuruh Grep"
has "$A" "show HEAD:./<dir>/" "agent: listing dir via git show (sudah di-allowlist)"
has "$A" "titipan: GAGAL" "agent: error titipan tak jadi none"
has "$A" "Tulis ulang SETIAP kali" "agent: _rules selalu ditulis ulang (mtime tak terbaca)"
for f in "$J" "$B/reference/e-status-resume.md"; do hasnt "$f" "Grep -n" "$(basename "$f"): tanpa Grep -n"; done
has "$B/reference/e-status-resume.md" "end_line" "§E: blok task dari line/end_line"
has "$J" "korup:" "§J: baris korup"
has "$J" "boleh list" "§J: for: multi-target"

# === re-review minor 2026-10-20 ===
hasnt "$S" ".claude/build/<work-item>/" "SKILL: path scratch pakai <wi>, bukan <work-item> dua-makna"
has "$S" '**`<wi>`** = folder scratch work-item' "SKILL step 1: definisi <wi> (+ fallback degrade)"
has "$S" "ambil ULANG tepat sebelum tiap tulis" "SKILL step 2: line/end_line tak dipakai ulang basi"
has "$S" "task tak dikenal: <id>" "SKILL degrade: pesan error dibaca, bukan semua = file rusak"
has "$K" "Alat: Read saja (unattended: grep/find/ls lewat Bash ditolak)" "§K bukti ⚠️: Read saja"
has "$K" "Read brief \`limit: 1\`" "§K: jawaban ambigu tanpa baca brief utuh"
has "$J" "line_no" "§J: nomor baris titipan = line_no"

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
