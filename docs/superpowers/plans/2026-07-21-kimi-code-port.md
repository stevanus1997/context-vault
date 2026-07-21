# Port Kimi Code Fase 1 (Generator `plugin-kimi/`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Plugin context-vault bisa di-install & 24 skill-nya jalan interaktif di Kimi Code CLI, via tree `plugin-kimi/` yang di-generate dari `plugin/` — tanpa menyentuh sisi Claude sedikit pun.

**Architecture:** Satu generator bash (`tools/build-kimi.sh`) regen-dari-nol `plugin-kimi/` tiap jalan: copy selektif (skills/rules/agents/template; TANPA hooks & .claude-plugin), rewrite `${CLAUDE_PLUGIN_ROOT}` → `${KIMI_SKILL_DIR}/../..`, tulis manifest `.kimi-plugin/plugin.json` (jq dari source), inject mapping subagent (D4) + banner tolak `--unattended` (D5), lalu self-check keras bahwa `plugin/` tak berubah. Spec: `docs/superpowers/specs/2026-07-21-kimi-code-port-design.md`.

**Tech Stack:** bash 3.2-compatible (macOS default), jq, perl (in-place edit portabel), awk (BWK/macOS), git. Test = skrip bash pola `plugin/hooks/tests/auto-title.test.sh` (counter PASS/FAIL, exit 0 = lulus).

## Global Constraints

- `plugin/` **READ-ONLY** untuk seluruh plan ini — tak ada task yang boleh mengedit isinya; generator punya guard before/after `git status --porcelain -- plugin/`.
- **JANGAN `git add plugin-kimi/` sebelum Task 3** — `.gitignore` rule `build/` menelan `plugin-kimi/skills/build/` sampai exception ditambahkan di Task 3. Task 1–2 commit `tools/` saja.
- Bash 3.2 macOS: TANPA `mapfile`, assoc array, `globstar`. Dependensi runtime: `bash`, `jq`, `perl`, `awk`, `git`.
- Komentar & output skrip berbahasa Indonesia (house-style; contoh: `plugin/hooks/auto-title.sh`).
- Konvensi commit: `feat(kimi): …` / `docs(spec): …` / `chore(release): …`; TANPA trailer co-author (settings sudah enforce).
- Output generator deterministik — dilarang timestamp/random di file hasil generate (test determinism `diff -r` dua kali jalan).
- Rewrite path: literal `${CLAUDE_PLUGIN_ROOT}` → literal `${KIMI_SKILL_DIR}/../..` (D3). String `CLAUDE_PLUGIN_ROOT` tak boleh tersisa di `plugin-kimi/`.
- Versi manifest Kimi HARUS == versi `plugin/.claude-plugin/plugin.json` (sync via jq, bukan tulis-tangan).

---

### Task 1: Generator inti + test harness

**Files:**
- Create: `tools/build-kimi.sh`
- Create: `tools/tests/build-kimi.test.sh`

**Interfaces:**
- Consumes: `plugin/` (read-only), `plugin/.claude-plugin/plugin.json` (name/description/version/author).
- Produces: `tools/build-kimi.sh` (dipanggil `bash tools/build-kimi.sh`, exit 0 = sukses; regen penuh `plugin-kimi/`) berisi fungsi `die()` dan `inject_below_frontmatter <target-md> <file-teks-injeksi>` yang dipakai Task 2; test harness dengan helper `ok <nama>` / `bad <nama>` yang Task 2 tambahi kasus.

- [ ] **Step 1: Tulis test yang gagal**

Tulis `tools/tests/build-kimi.test.sh`:

```bash
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
```

- [ ] **Step 2: Jalankan test — pastikan gagal**

Run: `bash tools/tests/build-kimi.test.sh`
Expected: FAIL — `generator exit 0` gagal (file `tools/build-kimi.sh` belum ada), diikuti kegagalan assert lain; exit non-zero.

- [ ] **Step 3: Implement generator inti**

Tulis `tools/build-kimi.sh`:

```bash
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
```

Catatan implementasi:
- Delimiter perl `s|…|…|g` (bukan `/`) supaya `/../..` di replacement tak perlu escape.
- `cp -R "$SRC/template" "$DST/template"` meng-copy dotdir `.claude/` di dalamnya (cp -R atas direktori ikut hidden entries — beda dengan glob `*`).
- `grep -rq … && die` di bawah `set -e`: aman karena grep yang tak-match (exit 1) berada di posisi kiri `&&` (bukan perintah terakhir pipeline yang bikin exit).

- [ ] **Step 4: Jalankan test — pastikan lulus**

Run: `bash tools/tests/build-kimi.test.sh`
Expected: semua `ok`, baris akhir `pass=N fail=0`, exit 0. (`plugin-kimi/` sekarang ada di working tree — BIARKAN uncommitted sampai Task 3.)

- [ ] **Step 5: Commit (tools/ saja)**

```bash
git add tools/build-kimi.sh tools/tests/build-kimi.test.sh
git commit -m "feat(kimi): generator plugin-kimi inti — copy selektif, rewrite path root, manifest sync, self-check source read-only"
```

---

### Task 2: Injeksi D4 (kimi-harness + pointer subagent) & D5 (banner unattended)

**Files:**
- Modify: `tools/build-kimi.sh` (isi bagian "Injeksi D4/D5" sebelum blok self-checks)
- Modify: `tools/tests/build-kimi.test.sh` (tambah kasus, sebelum blok determinism `# --- 7.`)

**Interfaces:**
- Consumes: `inject_below_frontmatter <target-md> <file-teks-injeksi>` dan `die()` dari Task 1.
- Produces: `plugin-kimi/rules/kimi-harness.md`; pointer di tiap `plugin-kimi/skills/*/SKILL.md` yang menyebut `subagent` (case-insensitive); banner di `plugin-kimi/skills/build/SKILL.md`; note satu-baris di `plugin-kimi/skills/build/reference.md` setelah heading pertama ber-kata `unattended` (saat plan ditulis: baris `## G. Lapor-keluar / notifikasi (mode unattended — M7)`).

- [ ] **Step 1: Tambah kasus test yang gagal**

Sisipkan blok berikut ke `tools/tests/build-kimi.test.sh` TEPAT SEBELUM baris komentar `# --- 7. deterministik…` (supaya determinism tetap kasus terakhir):

```bash
# --- 5. injeksi D4 & D5 ---
[ -f "$DST/rules/kimi-harness.md" ] && grep -q 'explore' "$DST/rules/kimi-harness.md" \
  && ok "rules/kimi-harness.md ada + mapping explore" || bad "rules/kimi-harness.md hilang/kosong"

# Pointer: presence XOR — skill ber-'subagent' WAJIB punya pointer, yang tidak WAJIB bersih.
# Daftar diturunkan dari grep atas SOURCE (mirror logika generator), bukan hardcode.
PTR_OK=1
for f in "$SRC"/skills/*/SKILL.md; do
  name="$(basename "$(dirname "$f")")"
  dst_f="$DST/skills/$name/SKILL.md"
  if grep -qi 'subagent' "$f"; then
    grep -q 'kimi-harness.md' "$dst_f" || { PTR_OK=0; echo "     (pointer HILANG di $name)"; }
  else
    grep -q 'kimi-harness.md' "$dst_f" && { PTR_OK=0; echo "     (pointer NYASAR di $name)"; }
  fi
done
[ "$PTR_OK" = 1 ] && ok "pointer kimi-harness presence-XOR sesuai grep subagent" || bad "pointer kimi-harness tidak sesuai daftar grep"

# Banner D5 di build/SKILL.md, posisinya DI ATAS H1 (tepat bawah frontmatter)
BF="$DST/skills/build/SKILL.md"
bline="$(grep -n 'HARNESS KIMI CODE' "$BF" 2>/dev/null | head -1 | cut -d: -f1)"
hline="$(grep -n '^# ' "$BF" 2>/dev/null | head -1 | cut -d: -f1)"
if [ -n "$bline" ] && [ -n "$hline" ] && [ "$bline" -lt "$hline" ]; then
  ok "banner unattended di build/SKILL.md (di atas H1)"
else bad "banner unattended hilang/salah posisi di build/SKILL.md"; fi

# Note D5 di build/reference.md (setelah heading unattended pertama)
grep -q 'Harness Kimi Code' "$DST/skills/build/reference.md" \
  && ok "note unattended di build/reference.md" || bad "note unattended hilang di build/reference.md"
```

- [ ] **Step 2: Jalankan test — pastikan kasus baru gagal**

Run: `bash tools/tests/build-kimi.test.sh`
Expected: kasus lama `ok`, 4 kasus baru `FAIL` (kimi-harness hilang, pointer hilang, banner hilang, note hilang); exit non-zero.

- [ ] **Step 3: Implement injeksi di generator**

Ganti baris placeholder `# (Injeksi D4/D5 diisi Task 2 …)` di `tools/build-kimi.sh` dengan:

```bash
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
```

- [ ] **Step 4: Jalankan test — pastikan lulus semua (termasuk determinism)**

Run: `bash tools/tests/build-kimi.test.sh`
Expected: semua `ok` (kasus lama + 4 baru + determinism), `pass=N fail=0`, exit 0.
Catatan: determinism aman karena regen-dari-nol — pointer berisi kata `subagent` tapi tiap run mulai dari copy source yang bersih.

- [ ] **Step 5: Verifikasi visual sekali (bukan test)**

Run: `head -20 plugin-kimi/skills/build/SKILL.md`
Expected: frontmatter → (kosong) → banner ⛔ → (kosong) → pointer kimi-harness → H1 `# build — …`.

- [ ] **Step 6: Commit (tools/ saja — plugin-kimi/ MASIH ditahan)**

```bash
git add tools/build-kimi.sh tools/tests/build-kimi.test.sh
git commit -m "feat(kimi): injeksi D4 kimi-harness+pointer subagent & D5 banner tolak unattended"
```

---

### Task 3: Fix `.gitignore` + commit perdana `plugin-kimi/`

Rule `build/` di `.gitignore` (artefak app Node) menelan `plugin-kimi/skills/build/` — persis jebakan yang sudah pernah kena di tree Claude (ada exception `!plugin/skills/build/`). Tanpa fix ini, skill paling penting hilang diam-diam dari commit.

**Files:**
- Modify: `.gitignore` (blok exception yang sudah ada)
- Add (generated): `plugin-kimi/` seluruhnya

**Interfaces:**
- Consumes: `plugin-kimi/` hasil Task 1–2 (sudah ada di working tree).
- Produces: `plugin-kimi/` ter-commit utuh — prasyarat Task 4 (README merujuknya) & Task 5 (install dari path repo).

- [ ] **Step 1: Tambah exception di `.gitignore`**

Ubah blok exception yang ada:

```
# Exception: `build/` di atas untuk artefak app, BUKAN skill dir `build`
!plugin/skills/build/
```

menjadi:

```
# Exception: `build/` di atas untuk artefak app, BUKAN skill dir `build`
!plugin/skills/build/
!plugin-kimi/skills/build/
```

- [ ] **Step 2: Verifikasi ignore rule beres**

Run: `git check-ignore -v plugin-kimi/skills/build/SKILL.md; echo "rc=$?"`
Expected: TANPA output rule yang match dan `rc=1` (artinya TIDAK ter-ignore). Kalau keluar rule `build/` → exception belum bener, ulangi Step 1.

- [ ] **Step 3: Regen bersih + test**

Run: `bash tools/build-kimi.sh && bash tools/tests/build-kimi.test.sh`
Expected: generator OK + `pass=N fail=0`.

- [ ] **Step 4: Commit perdana tree generated**

```bash
git add .gitignore plugin-kimi
git commit -m "feat(kimi): commit perdana plugin-kimi/ (generated) + exception gitignore skills/build"
```

- [ ] **Step 5: Sanity pasca-commit — build/ ikut ke-commit**

Run: `git ls-files plugin-kimi/skills/build/ | head -3`
Expected: minimal `plugin-kimi/skills/build/SKILL.md` dan `plugin-kimi/skills/build/reference.md` kelisting. Kosong = gitignore masih nelen → balik ke Step 1.

---

### Task 4: README — seksi "Kimi Code"

**Files:**
- Modify: `README.md` (sisip seksi baru TEPAT SEBELUM baris `## Mulai produk`)

**Interfaces:**
- Consumes: path & perintah dari Task 1–3 (`plugin-kimi/`, `tools/build-kimi.sh`, `tools/tests/build-kimi.test.sh`).
- Produces: dokumentasi user-facing; dirujuk Task 5 (langkah install) & Task 6 (ritual rilis).

- [ ] **Step 1: Sisip seksi**

Sisipkan markdown berikut di `README.md`, tepat sebelum `## Mulai produk`:

```markdown
## Kimi Code

Plugin ini juga bisa dipakai di [Kimi Code CLI](https://www.kimi.com/code/docs/en/) (MoonshotAI) lewat tree hasil generate `plugin-kimi/`. Source of truth tetap `plugin/` (format Claude Code) — **jangan edit `plugin-kimi/` langsung**; edit `plugin/` lalu regen.

- **Install:** buka `kimi` → `/plugins` → tab **Custom** → install dari path `<repo-ini>/plugin-kimi` → `/reload`.
- **Invokasi:** `/skill:<nama>` (mis. `/skill:guide`, `/skill:build checkout-v2`) — namespace beda dari Claude Code (`/context-vault:<nama>`).
- **Belum tersedia di Kimi (fase 2):** auto-title session (`sessionTitle` = fitur Claude-only) dan `build --unattended` — `kimi -p` auto-approve SEMUA tool, rem allowlist/deny belum terbukti berlaku di mode itu, jadi skill `build` versi Kimi akan MENOLAK `--unattended`.
- **Pola hybrid:** state produk hidup di disk (`control/`, `tasks.yaml`, git) — kerja interaktif bebas di Kimi/Claude; lane unattended tetap via Claude Code: `bash .claude/drive.sh <fitur>`.
- **Ritual rilis:** tiap rilis plugin → `bash tools/build-kimi.sh` (regen) + `bash tools/tests/build-kimi.test.sh` (jaga sync) → commit `plugin-kimi/`.
- Spec & keputusan desain: `docs/superpowers/specs/2026-07-21-kimi-code-port-design.md`.
```

- [ ] **Step 2: Verifikasi struktur README**

Run: `grep -n '^## ' README.md | head -6`
Expected: `## Install` → `## Kimi Code` → `## Mulai produk` berurutan.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs(kimi): seksi Kimi Code di README — install, namespace /skill:, batasan fase 1, ritual rilis"
```

---

### Task 5: Acceptance empiris di `kimi` 0.28.1 + addendum spec

⚠️ **Butuh manusia di terminal** — `/plugins` adalah TUI interaktif; jalankan bareng user. Acceptance ini = hakim untuk skema manifest (spec D2) & perilaku placeholder (spec D3). Kalau ada temuan yang menuntut perubahan generator: ubah `tools/build-kimi.sh`, jalankan test, regen, commit `fix(kimi): …` — LALU catat di addendum.

**Files:**
- Modify: `docs/superpowers/specs/2026-07-21-kimi-code-port-design.md` (tambah `## 9. Addendum pasca-implementasi (2026-07-21)` di akhir — pola addendum spec auto-title)
- (Kondisional) Modify: `tools/build-kimi.sh` + regen `plugin-kimi/` bila temuan menuntut

**Interfaces:**
- Consumes: `plugin-kimi/` ter-commit (Task 3), langkah install README (Task 4).
- Produces: addendum empiris di spec; sinyal go/no-go untuk Task 6 (rilis).

- [ ] **Step 1: Install plugin di kimi (bareng user)**

Di terminal user: `cd` ke folder produk ber-`control/` (atau folder scratch kosong untuk uji guide saja) → `kimi` → `/plugins` → tab **Custom** → install dari path absolut `…/context-vault/plugin-kimi` → `/reload`.
Catat: apakah manifest `{name, description, version, author}` diterima; kalau ditolak/error, catat pesan error persisnya (field apa yang dituntut/ditolak).

- [ ] **Step 2: Verifikasi 24 skill kelisting**

Di sesi kimi: buka daftar skill (via `/plugins` detail plugin, atau autocomplete `/skill:`).
Expected: 24 skill context-vault muncul. Catat bentuk namespace yang tampil (mis. `/skill:build` vs `/skill:context-vault:build`) — README di-update kalau beda dari asumsi.

- [ ] **Step 3: Smoke `/skill:guide`**

Di sesi kimi: `/skill:guide`
Expected: tur onboarding jalan end-to-end (guide = read-only, aman di mana pun).

- [ ] **Step 4: Bukti rewrite path root beneran resolve**

Di sesi kimi, di folder produk: `/skill:ask produk ini fiturnya apa aja?`
`ask` menyebut subagent → SKILL.md-nya ber-pointer. Amati transcript: model membaca `…/rules/kimi-harness.md` via path hasil substitusi `${KIMI_SKILL_DIR}/../..` (path absolut ke plugin ter-install).
Expected: file kebaca (bukti substitusi + rewrite jalan). Kalau placeholder muncul LITERAL (tak disubstitusi): fallback spec D3 — ubah rewrite generator jadi prosa `dua level di atas folder skill ini (folder SKILL.md yang sedang jalan)`, jalankan test + regen + commit `fix(kimi): fallback prosa path root — KIMI_SKILL_DIR tak disubstitusi`, ulangi step ini.

- [ ] **Step 5: Tulis addendum di spec**

Tambahkan di akhir file spec:

```markdown
---

## 9. Addendum pasca-implementasi (2026-07-21)

Temuan empiris acceptance `kimi` 0.28.1:

1. **Skema manifest:** `{name, description, version, author}` <diterima apa adanya / dituntut field X — generator disesuaikan: …>.
2. **Namespace invokasi:** skill tampil sebagai `/skill:<…>` <sesuai asumsi / beda: … — README disesuaikan>.
3. **Substitusi `${KIMI_SKILL_DIR}`:** <tersubstitusi di body skill; alur baca rules/kimi-harness.md terbukti / TIDAK — fallback prosa D3 dipakai>.
4. **Listing skill:** 24/24 kelisting via <…>.
5. Catatan lain: <perilaku auto-invoke description, /reload, dsb — atau "tidak ada">.
```

Isi tiap `<…>` dengan temuan nyata (JANGAN biarkan placeholder tersisa di commit).

- [ ] **Step 6: Commit addendum (+ perubahan kondisional bila ada)**

```bash
git add docs/superpowers/specs/2026-07-21-kimi-code-port-design.md
git commit -m "docs(spec): addendum empiris port Kimi fase 1 — skema manifest, namespace, substitusi KIMI_SKILL_DIR (kimi 0.28.1)"
```

---

### Task 6: Rilis 0.21.0

Prasyarat: Task 5 selesai dengan verdict "jalan" (temuan besar sudah di-fix & tercatat di addendum).

**Files:**
- Modify: `plugin/.claude-plugin/plugin.json` (version `0.20.0` → `0.21.0`) — *satu-satunya sentuhan ke `plugin/` di plan ini, dan sifatnya rilis, bukan porting*
- Modify: `.claude-plugin/marketplace.json` (dua field version `0.20.0` → `0.21.0`)
- Regen: `plugin-kimi/` (version ikut via sync)

**Interfaces:**
- Consumes: seluruh hasil Task 1–5.
- Produces: rilis 0.21.0 utuh; version manifest Kimi == 0.21.0 via regen (dijaga test #4).

- [ ] **Step 1: Bump versi**

Edit `plugin/.claude-plugin/plugin.json`: `"version": "0.20.0"` → `"version": "0.21.0"`.
Edit `.claude-plugin/marketplace.json`: `"version": "0.20.0"` → `"version": "0.21.0"` (di `metadata` DAN di entri `plugins[0]`).
(Opsional, kebiasaan rilis repo: tambah frasa fitur kimi di `description` plugin.json — keputusan user, bukan blocker.)

- [ ] **Step 2: Regen + test (version sync kejaga otomatis)**

Run: `bash tools/build-kimi.sh && bash tools/tests/build-kimi.test.sh`
Expected: `pass=N fail=0`; test `version manifest == version source` membuktikan `plugin-kimi/.kimi-plugin/plugin.json` ikut 0.21.0.

- [ ] **Step 3: Commit rilis**

```bash
git add plugin/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugin-kimi
git commit -m "chore(release): bump 0.21.0 — port Kimi Code fase 1 (plugin-kimi generated, core interaktif + rem unattended)"
```

- [ ] **Step 4: Sanity terakhir sisi Claude**

Run: `git diff HEAD~1 --stat -- plugin/`
Expected: HANYA `plugin/.claude-plugin/plugin.json | 2 +-` (bump versi). File skill/rules/agents/hooks Claude nol perubahan sepanjang seluruh plan (Task 1–5 tak menyentuh `plugin/` sama sekali).
