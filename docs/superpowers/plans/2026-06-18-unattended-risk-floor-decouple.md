# Decouple risk/sensitivity + buka jalan loop unattended — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persempit floor `sensitivity → risk:high` ke payments-movement-only, pasang floor-scan deterministik di build, dan tutup dua jalur freeze ronde-1 lain (notify + allowlist) — supaya loop unattended benar-benar terpakai tanpa mengorbankan keamanan.

**Architecture:** Perubahan ke **prosa skill (markdown)** + satu **skrip bash** (`drive.sh`). Tak ada kode aplikasi / unit-test pytest. Verifikasi tiap edit = **grep struktural** + **read-back** (baca teks baru, konfirmasi maksud); khusus `drive.sh` ada **smoke-test bash** beneran (jalankan di temp dir). Acceptance akhir = **adversarial-verify workflow** (pola kerja user).

**Tech Stack:** Markdown (skill files context-vault), Bash (`drive.sh`), `grep`/`jq` untuk verifikasi.

## Global Constraints

- **Scaffold comment byte-identik:** `plugin/skills/intake/SKILL.md` (≈baris 21) dan `plugin/skills/feature/SKILL.md` (≈baris 21) WAJIB string identik; **tanpa `: ` (colon-space) di value YAML** (BUG-GUARD M7 §4a). Value tetap `normal`; perubahan ada di komentar `#`.
- **Pinjam kosakata verba VERBATIM** dari `plugin/skills/tweak/reference.md` §A (baris 4–6): *Verba-keamanan*, *Verba-uang (PLUMBING)*, *PII*. JANGAN bikin daftar paralel baru (cegah drift dua permukaan).
- **JANGAN sentuh:** mekanik heuristik `sensitivity` di `intake` step 7, Security Gate `ship` (`ship/SKILL.md`), dan file `control/*` di produk mana pun.
- **Anchor by quoted-phrase, bukan nomor baris** — beberapa task ngedit file yang sama (`build/SKILL.md`, `build/reference.md`); nomor baris bergeser tiap edit. Cari frasa yang dikutip.
- **Commit tiap task.** Pesan commit Indonesian + prefix conventional-commits + footer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **Tak menambah skill** → JANGAN ubah hitungan skill di README / `plugin.json` / `marketplace.json` / induk spec §17.

---

### Task 1: Decouple floor + scaffold comments (intake + feature)

**Files:**
- Modify: `plugin/skills/intake/SKILL.md` — baris 57 (definisi `risk` + floor), baris 21 (scaffold comment)
- Modify: `plugin/skills/feature/SKILL.md` — baris 21 (scaffold comment, identik dgn intake)

**Interfaces:**
- Produces: **wording floor baru** = "payments **DAN** menggerakkan uang (verba-uang) → risk:high; pii saja TIDAK floor". Task 2/5/7 mengandalkan makna ini.
- Produces: **string scaffold comment kanonik** (dipakai byte-identik di dua file).

- [ ] **Step 1: Ganti definisi `risk` + floor di `intake/SKILL.md`**

Cari kalimat (baris 57) yang diawali `**Usulkan \`risk\` (M7)**` sampai `user konfirmasi di gate ini.` — ganti SELURUH kalimat itu dengan:

```markdown
**Usulkan `risk` (M7)** (`low|normal|high`) = **blast-radius BUILD** (seberapa bahaya kalau build keliru — BUKAN seberapa sensitif datanya; itu `sensitivity`, lihat M7 D1). `high` bila build-nya sendiri berbahaya: operasi **destruktif/irreversible**; **migrasi skema/data**; **batas auth/keamanan** (authn/authz, session/token, isolasi tenant, CORS/origin — daftar *Verba-keamanan* `tweak/reference.md` §A); **plumbing pergerakan uang** (charge/capture/refund/payout/settlement/transfer, simpan PAN/token-kartu — *Verba-uang PLUMBING* `tweak/reference.md` §A). **Floor (dipersempit — M7-amend 2026-06-18):** bila usulan `sensitivity` memuat `payments` **DAN** fitur benar-benar **menggerakkan uang** (verba-uang di atas, atau menyimpan instrumen-bayar — BUKAN sekadar menampilkan harga/invoice/saldo read-only) → `risk` minimal `high` (HARD). **`pii` saja TIDAK memaksa floor** — `pii` menyetir kedalaman Security Gate `ship`, bukan cadence build. Tulis ke `feature.yaml` `risk`. Advisory — default `normal` bila tak yakin; user konfirmasi di gate ini.
```

- [ ] **Step 2: Ganti scaffold comment di `intake/SKILL.md` (baris 21)**

Ganti baris:
```yaml
risk: normal           # (M7) low | normal | high — menyetir cadence approval build --unattended; sensitivity non-kosong → floor high (hard)
```
menjadi:
```yaml
risk: normal           # (M7) low | normal | high — blast-radius build; menyetir cadence build --unattended; payments-movement → floor high (hard), pii saja tidak
```

- [ ] **Step 3: Ganti scaffold comment di `feature/SKILL.md` (baris 21) — IDENTIK**

Terapkan **persis** edit Step 2 di `plugin/skills/feature/SKILL.md` baris 21 (string harus byte-identik dengan intake).

- [ ] **Step 4: Verifikasi byte-identik + no colon-space leak**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
A=$(grep -n 'risk: normal' plugin/skills/intake/SKILL.md | head -1 | cut -d: -f3-)
B=$(grep -n 'risk: normal' plugin/skills/feature/SKILL.md | head -1 | cut -d: -f3-)
[ "$A" = "$B" ] && echo "IDENTIK OK" || { echo "DRIFT: <$A> vs <$B>"; exit 1; }
# value YAML sebelum '#' tak boleh punya ': '
echo "$A" | sed 's/#.*//' | grep -q ': ' && { echo "COLON-SPACE LEAK"; exit 1; } || echo "NO-LEAK OK"
```
Expected: `IDENTIK OK` lalu `NO-LEAK OK`.

- [ ] **Step 5: Read-back floor**

Run: `grep -n 'pii.*saja.*TIDAK memaksa floor\|pii saja TIDAK' plugin/skills/intake/SKILL.md`
Expected: ketemu 1 baris — konfirmasi floor sekarang payments-movement-only, pii read-only bebas.

- [ ] **Step 6: Commit**

```bash
git add plugin/skills/intake/SKILL.md plugin/skills/feature/SKILL.md
git commit -m "feat(intake): decouple risk dari sensitivity — floor dipersempit ke payments-movement

risk = blast-radius build (niat M7 D1); pii read-only tak lagi floor high.
Scaffold comment intake/feature disinkron byte-identik.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Build risk gate — floor-scan deterministik + degrade-vs-sensitivity

**Files:**
- Modify: `plugin/skills/build/SKILL.md` — step 1 (frasa `Risk + mode unattended (M7)`), step 6 (frasa `HARD floor — TETAP STOP walau unattended`)
- Modify: `plugin/skills/build/reference.md` — §D (frasa `**\`--unattended\` (opt-in, fitur saja — M7):**`), §H (frasa `**\`risk: high\` saat unattended**`)

**Interfaces:**
- Consumes: makna floor baru dari Task 1.
- Produces: **floor-scan B** (jaring deterministik tak-bergantung tag `risk`) + aturan **migrasi-tak-terdeklarasi → STOP** + **degrade `risk` absen vs sensitivity:payments → high**. Task 5/7 mengandalkan istilah "floor-scan".

- [ ] **Step 1: Tambah degrade-vs-sensitivity di `build/SKILL.md` step 1**

Cari frasa `baca juga \`feature.yaml\` \`risk\` (\`low|normal|high\`, default \`normal\` bila absen/typo — degrade fail-safe)`. Ganti jadi:

```markdown
baca juga `feature.yaml` `risk` (`low|normal|high`; default absen/typo → `normal`, **KECUALI bila `sensitivity` memuat `payments` → degrade ke `high`** — fail-safe terhadap pergerakan uang)
```

- [ ] **Step 2: Tambah floor-scan B + migrasi-tak-terdeklarasi di `build/SKILL.md` step 6**

Cari klausa `**HARD floor — TETAP STOP walau unattended:** \`risk: high\`, task \`migrate\` (step 3), \`needs_human\` (step 2), \`blocked\` (step 5), ATAU penyimpangan-dari-maksud`. Tepat SETELAH `(jalankan disiplin fix embed seperti biasa).` di klausa itu, sisipkan kalimat baru:

```markdown
 **+ Floor-scan diff (jaring deterministik, M7-amend 2026-06-18):** sebelum auto-approve sebuah segmen, grep diff segmen untuk verba bahaya (daftar *Verba-keamanan* + *Verba-uang PLUMBING* `tweak/reference.md` §A: authn/authz, session/token/TTL, filter isolasi tenant, CORS/origin, secret/credential, validasi input/serialization, charge/capture/refund/payout/settlement/transfer, simpan PAN/token-kartu) **DAN** DDL migrasi (`CREATE`/`ALTER`/`DROP` table, `prisma migrate`/`db push`, `drizzle push`). Kena → **STOP attended**, *apa pun* tag `risk` fitur (tutup lubang intake salah-tag). **Migrasi tak-terdeklarasi:** diff ber-DDL tanpa task ber-`actions: migrate` → STOP (floor `migrate` step-3 tak bisa di-bypass salah-tag). Floor-scan = jaring tambahan, BUKAN pengganti gate lain.
```

- [ ] **Step 3: Tambah klausa floor-scan + degrade di `build/reference.md` §D**

Cari bullet §D yang diawali `- **\`--unattended\` (opt-in, fitur saja — M7):**`. Di akhir kalimat bullet itu (setelah `Default (tanpa flag) = stop tiap segmen.`), tambahkan:

```markdown
 **Floor-scan diff (M7-amend 2026-06-18):** jaring deterministik tak-bergantung tag `risk` — grep diff tiap segmen untuk verba bahaya (*Verba-keamanan* + *Verba-uang PLUMBING* `tweak/reference.md` §A) + DDL migrasi; kena → STOP attended. Degrade: `risk` absen + `sensitivity:[payments]` → diperlakukan `high`.
```

- [ ] **Step 4: Klarifikasi reason di `build/reference.md` §H**

Cari frasa `**\`risk: high\` saat unattended** (auto-approve tak pernah nyala → tiap gate stop; emit \`halt\` DINI di ronde-1, reason "risk:high butuh attended")`. Ganti jadi:

```markdown
**`risk: high` saat unattended** (auto-approve tak pernah nyala → emit `halt` DINI ronde-1; reason **membedakan**: floor-scan/verba-bahaya = `"risk:high (berbahaya: <verba>) butuh attended"` vs `risk` di-set manual = `"risk:high (di-set) — turunkan feature.yaml atau jalankan attended"`)
```

- [ ] **Step 5: Read-back floor-scan**

Run:
```bash
grep -c 'Floor-scan diff' plugin/skills/build/SKILL.md plugin/skills/build/reference.md
grep -q 'Migrasi tak-terdeklarasi' plugin/skills/build/SKILL.md && echo "UNDECLARED-MIGRATION OK"
grep -q 'sensitivity.*payments.*→.*high\|sensitivity\` memuat \`payments\` → degrade' plugin/skills/build/SKILL.md && echo "DEGRADE OK"
```
Expected: tiap file ≥1 hit `Floor-scan diff`, `UNDECLARED-MIGRATION OK`, `DEGRADE OK`.

- [ ] **Step 6: Read-back skenario (reasoning, bukan command)**

Konfirmasi dengan membaca: fitur auth yang sengaja di-tag `risk: normal`, saat build menyentuh diff `session`/`token`/`tenant_id` → **floor-scan STOP** walau tag normal. Bila teks tak menjamin ini, perbaiki Step 2.

- [ ] **Step 7: Commit**

```bash
git add plugin/skills/build/SKILL.md plugin/skills/build/reference.md
git commit -m "feat(build): floor-scan deterministik + degrade risk vs sensitivity:payments

Jaring diff-level (verba tweak §A + DDL) STOP segmen berbahaya apa pun tag risk —
tutup lubang intake salah-tag. Migrasi tak-terdeklarasi → STOP. risk absen +
payments → degrade high.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: drive.sh precheck backstop (notify + allowlist)

**Files:**
- Create: `/tmp/test-drive-precheck.sh` (smoke-test sementara, tak di-commit)
- Modify: `plugin/template/.claude/drive.sh` — sisipkan blok precheck sebelum `prev_done=-1`

**Interfaces:**
- Produces: backstop "Y" — bila `notify.sh` absen / allowlist verifikasi kosong → cetak instruksi + `exit 1` SEBELUM loop (no-freeze, no-silent).

- [ ] **Step 1: Tulis smoke-test (gagal dulu)**

Create `/tmp/test-drive-precheck.sh`:
```bash
#!/usr/bin/env bash
set -uo pipefail
DRIVE=/Users/stevanus/Developer/ai-boilerplate/plugin/template/.claude/drive.sh
TMP=$(mktemp -d); mkdir -p "$TMP/.claude" "$TMP/control/features/x"
# kasus A: notify.sh absen → harus exit !=0 dgn pesan notify, TANPA spawn claude
out=$(cd "$TMP" && bash "$DRIVE" x 1 2>&1); rc=$?
echo "$out" | grep -qi 'notify.sh belum diset' && [ $rc -ne 0 ] && echo "A-NOTIFY OK" || { echo "A FAIL rc=$rc out=$out"; exit 1; }
# kasus B: notify ada, allowlist cuma git → harus exit !=0 dgn pesan allowlist
printf '#!/bin/sh\n:' > "$TMP/.claude/notify.sh"; chmod +x "$TMP/.claude/notify.sh"
printf '{"permissions":{"allow":["Bash(git status:*)"]}}' > "$TMP/.claude/settings.json"
out=$(cd "$TMP" && bash "$DRIVE" x 1 2>&1); rc=$?
echo "$out" | grep -qi 'allowlist' && [ $rc -ne 0 ] && echo "B-ALLOWLIST OK" || { echo "B FAIL rc=$rc out=$out"; exit 1; }
rm -rf "$TMP"; echo "ALL PRECHECK TESTS PASS"
```

- [ ] **Step 2: Jalankan — pastikan GAGAL**

Run: `bash /tmp/test-drive-precheck.sh`
Expected: FAIL di kasus A (drive.sh sekarang langsung masuk loop & coba spawn `claude` / cari last-run.md, tak ada pesan `notify.sh belum diset`).

- [ ] **Step 3: Sisipkan blok precheck di `drive.sh`**

Di `plugin/template/.claude/drive.sh`, TEPAT sebelum baris `prev_done=-1`, sisipkan:

```bash
# --- Precheck prasyarat unattended (backstop "Y") — dijalankan saat MANUSIA masih di
#     terminal, supaya tak freeze headless di tengah loop. Kurang → instruksi + EXIT. ---
SETTINGS="$ROOT/.claude/settings.json"
NOTIFY="$ROOT/.claude/notify.sh"
if [ ! -x "$NOTIFY" ]; then
  echo "[drive] STOP — notify.sh belum diset; loop unattended butuh kanal notif." >&2
  echo "        Setup: jalankan 'wire'/'upgrade', ATAU 'build $FITUR --unattended' sekali interaktif." >&2
  exit 1
fi
if command -v jq >/dev/null 2>&1; then
  nongit="$(jq -r '[.permissions.allow[]? | select(test("^Bash\\(git")|not)] | length' "$SETTINGS" 2>/dev/null || echo 0)"
else
  nongit=1   # tanpa jq: jangan false-block, lewati cek allowlist
fi
if [ ! -f "$SETTINGS" ] || [ "${nongit:-0}" -eq 0 ]; then
  echo "[drive] STOP — allowlist verifikasi stack belum keisi di .claude/settings.json." >&2
  echo "        Tanpa ini build beku di permission prompt headless. Jalankan 'wire' step 5.5 dulu." >&2
  exit 1
fi
```

- [ ] **Step 4: Jalankan smoke-test — pastikan LULUS**

Run: `bash /tmp/test-drive-precheck.sh`
Expected: `A-NOTIFY OK`, `B-ALLOWLIST OK`, `ALL PRECHECK TESTS PASS`.

- [ ] **Step 5: Sanity — syntax bash**

Run: `bash -n plugin/template/.claude/drive.sh && echo "SYNTAX OK"`
Expected: `SYNTAX OK`.

- [ ] **Step 6: Commit (buang smoke-test)**

```bash
rm -f /tmp/test-drive-precheck.sh
git add plugin/template/.claude/drive.sh
git commit -m "feat(drive): precheck notify.sh + allowlist sebelum loop (backstop Y)

Kurang → cetak instruksi & exit saat manusia masih di terminal; bukan freeze
headless di tengah loop. Nutup dua dead-end ronde-1 (notify stall + allowlist kosong).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: wire step 5.5 — setup notify (skippable)

**Files:**
- Modify: `plugin/skills/wire/SKILL.md` — step 5.5 (akhir paragraf, setelah allowlist append)

**Interfaces:**
- Consumes: precheck `drive.sh` (Task 3) sebagai jaring bila user skip.
- Produces: jalur proaktif setup `notify.sh` saat ada manusia (greenfield/brownfield bring-up).

- [ ] **Step 1: Tambah paragraf notify di wire step 5.5**

Di akhir bagian `### 5.5 Permission harness (unattended-ready)` (setelah kalimat terakhir `...typecheck/test-nya juga butuh izin).`), tambahkan paragraf baru:

```markdown

**Setup notify unattended (skippable, M7-amend 2026-06-18):** karena allowlist baru disiapkan untuk unattended, sekalian **tawarkan** setup kanal notif (di sini ada manusia, bukan headless): *"Setup notif buat `build --unattended`? (skip kalau belum perlu)"*. Bila ya → Q&A kanal (wording kanonik `build/reference.md` §G: ntfy/macOS/Telegram/no-op) → tulis `<produk>/.claude/notify.sh` + `chmod +x` (sudah gitignored oleh `init`). Bila skip → lanjut; nanti precheck `drive.sh` yang ingatkan saat user benar-benar coba unattended. `notify.sh` user-specific → **DITANYA, bukan di-ship**. GATE: tampilkan isi notify.sh yang mau ditulis → approve.
```

- [ ] **Step 2: Read-back**

Run: `grep -q 'Setup notify unattended (skippable' plugin/skills/wire/SKILL.md && echo "WIRE-NOTIFY OK"`
Expected: `WIRE-NOTIFY OK`.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/wire/SKILL.md
git commit -m "feat(wire): tawarkan setup notify.sh (skippable) di step 5.5

Setup notif pas ada manusia di terminal, sejajar allowlist. Skip → di-backstop drive.sh.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: build headless tak-pernah-nanya + allowlist-as-halt + notify-absent transparan

**Files:**
- Modify: `plugin/skills/build/SKILL.md` — step lapor-keluar (frasa `Mode unattended (headless): JANGAN PERNAH nanya interaktif`)
- Modify: `plugin/skills/build/reference.md` — §G (frasa `ditulis \`build\` SEKALI lewat Q&A first-unattended`)

**Interfaces:**
- Consumes: precheck `drive.sh` (Task 3) — primary gate; ini belt-and-suspenders untuk jalur non-drive (mis. `/schedule`, `claude -p` langsung).
- Produces: di headless, build TAK PERNAH Q&A notify; allowlist kosong → `outcome: halt` reason jelas; notify absen → catat di `last-run.md`, jangan stall.

- [ ] **Step 1: Tambah aturan headless-notify + allowlist-halt di `build/SKILL.md`**

Cari frasa `tiap berhenti (termasuk permission-denial/env/\`risk:high\`) emit \`outcome\`+\`last-run.md\` DULU lalu STOP`. Tepat setelahnya, sisipkan:

```markdown
 **Setup notify = BUKAN di headless (M7-amend 2026-06-18):** Q&A kanal notif HANYA di sesi interaktif (di-handle `wire`/`upgrade`/precheck `drive.sh`). Headless + `notify.sh` absen → JANGAN tanya kanal: lanjut dgn hook no-op (laporan disk tetap jalan) **DAN catat di `last-run.md` reason "notify.sh absen — notif mati run ini"** (transparan, bukan stall, bukan diam). **Allowlist verifikasi stack kosong/kurang saat unattended → emit `outcome: halt` reason "allowlist kosong — jalankan wire 5.5"** (jangan biarkan beku di permission prompt harness).
```

- [ ] **Step 2: Sesuaikan §G `build/reference.md` (notify setup keluar dari headless)**

Cari kalimat `**notify.sh** (\`<root>/.claude/notify.sh\`) = kanal pilihan USER, ditulis \`build\` SEKALI lewat Q&A first-unattended (step 1)`. Ganti potongan `ditulis \`build\` SEKALI lewat Q&A first-unattended (step 1)` jadi:

```markdown
diset SEKALI lewat Q&A kanal **di sesi interaktif** (`wire` 5.5 / `upgrade` / `build --unattended` interaktif) — **JANGAN di headless** (`drive.sh`/`/schedule`): di headless, absen → hook no-op + dicatat di `last-run.md`, precheck `drive.sh` yang menjaga di depan
```

- [ ] **Step 3: Read-back**

Run:
```bash
grep -q 'notify.sh absen — notif mati run ini' plugin/skills/build/SKILL.md && echo "NOTIFY-TRANSPARAN OK"
grep -q 'allowlist kosong — jalankan wire 5.5' plugin/skills/build/SKILL.md && echo "ALLOWLIST-HALT OK"
grep -q 'JANGAN di headless' plugin/skills/build/reference.md && echo "REF-G OK"
```
Expected: tiga baris OK.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/build/SKILL.md plugin/skills/build/reference.md
git commit -m "feat(build): headless tak-pernah Q&A notify; allowlist kosong → halt jelas

Setup notif pindah ke jalur interaktif (wire/upgrade/precheck). Headless + notify
absen → no-op + dicatat last-run.md (transparan). Allowlist kosong → outcome:halt,
bukan freeze.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: upgrade — tawarkan setup notify + cek allowlist (produk lama)

**Files:**
- Modify: `plugin/skills/upgrade/SKILL.md` — step 4 (bullet `Notif unattended belum diset`)
- Verify (read-only): `plugin/skills/init/SKILL.md` baris 65 — `notify.sh` sudah di-gitignore

**Interfaces:**
- Consumes: wording Q&A kanonik `build/reference.md` §G.
- Produces: jalur migrasi prasyarat unattended untuk produk yang di-init versi lama (temen-temen user yang sudah install).

- [ ] **Step 1: Ganti bullet manual jadi OFFER di upgrade step 4**

Cari bullet (step 4):
```markdown
- Notif unattended belum diset → "jalankan `build <fitur> --unattended` sekali **interaktif** untuk set `notify.sh`" (Q&A first-unattended cuma bisa di sesi interaktif, bukan headless `drive.sh`).
```
Ganti jadi:
```markdown
- **Notif unattended belum diset → TAWARKAN setup sekarang** (di sini ada manusia): *"Setup notif buat `build --unattended`? (skip boleh)"* → bila ya, Q&A kanal (wording kanonik `build/reference.md` §G: ntfy/macOS/Telegram/no-op) → tulis `.claude/notify.sh` + `chmod +x` (sudah gitignored). GATE: tampilkan isi → approve. (Tetap nol-sentuh knowledge: `notify.sh` = file plugin/`.claude`, bukan `control/`.)
- **Cek allowlist verifikasi stack** sudah keisi (step 2 sudah derive per-stack dari `workspace.yaml`) — kalau belum lengkap, ingatkan `wire` step 5.5. Tanpa ini `drive.sh` precheck akan menahan.
- **Fitur lama ter-floor `risk:high`** (floor lama, sebelum M7-amend 2026-06-18) tetap halt saat unattended — `upgrade` TIDAK menyentuh `feature.yaml` (knowledge). Pemulihan manual: edit `feature.yaml` `risk: high → normal` untuk fitur pii-only, atau re-run `intake`.
```

- [ ] **Step 2: Verifikasi init sudah gitignore notify (read-only)**

Run: `grep -q '.claude/notify.sh' plugin/skills/init/SKILL.md && echo "INIT-GITIGNORE OK (no change)"`
Expected: `INIT-GITIGNORE OK (no change)` — konfirmasi tak perlu ubah init.

- [ ] **Step 3: Read-back**

Run: `grep -q 'TAWARKAN setup sekarang' plugin/skills/upgrade/SKILL.md && grep -q 'Fitur lama ter-floor' plugin/skills/upgrade/SKILL.md && echo "UPGRADE OK"`
Expected: `UPGRADE OK`.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/upgrade/SKILL.md
git commit -m "feat(upgrade): tawarkan setup notify + cek allowlist + catatan recovery fitur lama

Produk lama (init versi lawas) bisa nyusulin prasyarat unattended via upgrade
(nol-sentuh knowledge). Plus panduan turunkan fitur yang terlanjur ter-floor high.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Transparansi — banner BUILT-UNATTENDED + invariants WARN

**Files:**
- Modify: `plugin/skills/build/SKILL.md` — step lapor-keluar (tambah banner) + step 1 (WARN invariants)
- Modify: `plugin/skills/build/reference.md` — §G (artefak laporan)

**Interfaces:**
- Consumes: istilah floor-scan (Task 2).
- Produces: penanda `last-run.md` "DIBANGUN UNATTENDED" untuk segmen sensitif; WARN bila `invariants.md` belum dikunci sebelum unattended.

- [ ] **Step 1: Tambah WARN invariants di `build/SKILL.md` step 1**

Cari frasa hasil Task 2 Step 1 (`...degrade ke \`high\`** — fail-safe terhadap pergerakan uang))`). Tepat setelahnya tambahkan:

```markdown
 **WARN invariants (advisory):** bila `control/invariants.md` masih punya slot `<belum dikunci>` relevan, **peringatkan sebelum unattended** — jaring konsistensi lintas-fitur (sejajar precheck allowlist); backstop security-critic `ship` ompong tanpa baseline terkunci. WARN, bukan palang.
```

- [ ] **Step 2: Tambah banner di `build/SKILL.md` lapor-keluar**

Cari frasa hasil Task 5 Step 1 (`...reason "allowlist kosong — jalankan wire 5.5"** ...harness).`). Tepat setelahnya tambahkan:

```markdown
 **Banner DIBANGUN-UNATTENDED:** bila ada segmen yang auto-approve unattended menyentuh area sensitif (kena heuristik floor-scan namun lolos karena read-only, atau `sensitivity:[pii]`), tandai di `last-run.md` (prosa) — `"DIBANGUN UNATTENDED — review security-critic wajib sebelum merge"` — supaya backstop manusia (`ship` Security Gate) tak diam-diam di-rubber-stamp.
```

- [ ] **Step 3: Catat artefak banner di `build/reference.md` §G**

Cari header `**Tiga artefak (ditulis \`build\`):**`. Di bawah item 3 (`Laporan` ... `last-run.md`), tambahkan kalimat di akhir deskripsi item 3:

```markdown
 (Bila run unattended menyentuh area sensitif, prosa memuat banner *"DIBANGUN UNATTENDED — review security-critic wajib sebelum merge"*.)
```

- [ ] **Step 4: Read-back**

Run:
```bash
grep -q 'WARN invariants' plugin/skills/build/SKILL.md && echo "WARN-INV OK"
grep -q 'DIBANGUN UNATTENDED' plugin/skills/build/SKILL.md && grep -q 'DIBANGUN UNATTENDED' plugin/skills/build/reference.md && echo "BANNER OK"
```
Expected: `WARN-INV OK`, `BANNER OK`.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/build/SKILL.md plugin/skills/build/reference.md
git commit -m "feat(build): WARN invariants belum-dikunci + banner DIBANGUN-UNATTENDED

Jaga konsistensi lintas-fitur (WARN) + cegah Security Gate ship di-rubber-stamp
diam-diam untuk segmen sensitif yang auto-approve unattended.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: M7 spec amendment + doc-sync check

**Files:**
- Modify: `docs/superpowers/specs/2026-06-06-m7-graduated-autonomy-design.md` — append catatan menyusul (jangan tulis-ulang)

**Interfaces:**
- Produces: catatan resmi bahwa D4 dipersempit; pointer ke spec & plan 2026-06-18.

- [ ] **Step 1: Append amendment ke akhir file spec M7**

Tambahkan di PALING BAWAH `docs/superpowers/specs/2026-06-06-m7-graduated-autonomy-design.md`:

```markdown

---

## Amendemen 2026-06-18 — D4 dipersempit (decouple risk/sensitivity)

D4 (floor borongan `sensitivity non-kosong → risk:high`) **dipersempit** ke
`payments-movement → risk:high`; `pii` read-only **tidak lagi** memaksa floor —
mengembalikan ke niat **D1** (risk = blast-radius build; sensitivity = kedalaman
ship). Ditambah floor-scan diff deterministik di build + setup prasyarat
unattended (notify/allowlist) via wire/upgrade + backstop `drive.sh`.

Spec lengkap: `docs/superpowers/specs/2026-06-18-unattended-risk-floor-decouple-design.md`.
Plan: `docs/superpowers/plans/2026-06-18-unattended-risk-floor-decouple.md`.
(Sejarah D4 di atas DIPERTAHANKAN — ini catatan menyusul, bukan tulis-ulang.)
```

- [ ] **Step 2: Doc-sync check (tak ada perubahan hitungan skill)**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
grep -rn 'skill ke-\|23 skill\|22 skill' README.md plugin/.claude-plugin/plugin.json .claude-plugin/marketplace.json 2>/dev/null | head
echo "--- pastikan TAK perlu ubah hitungan: perubahan ini nol skill baru ---"
```
Expected: review output — konfirmasi tak ada hitungan skill yang jadi salah (kita tak nambah skill). Bila ada deskripsi trigger yang jadi tak-akurat karena perubahan perilaku, perbaiki; kemungkinan besar tak ada.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-06-06-m7-graduated-autonomy-design.md
git commit -m "docs(spec): amendemen M7 D4 — dipersempit ke payments-movement (pointer ke 2026-06-18)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Acceptance — adversarial-verify + full read-back

**Files:** (none — verifikasi menyeluruh)

**Interfaces:**
- Consumes: seluruh diff Task 1–8.

- [ ] **Step 1: Diff menyeluruh**

Run: `git log --oneline -8 && git diff --stat HEAD~8`
Expected: 8 commit, file berubah = intake/feature/build(SKILL+ref)/wire/upgrade/drive.sh/spec M7. TAK ada `control/` produk, TAK ada `ship/SKILL.md`, TAK ada hitungan skill.

- [ ] **Step 2: Re-verify byte-identik + floor-scan + precheck (kumulatif)**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
diff <(grep 'risk: normal' plugin/skills/intake/SKILL.md) <(grep 'risk: normal' plugin/skills/feature/SKILL.md) && echo "SCAFFOLD IDENTIK OK"
grep -q 'Floor-scan diff' plugin/skills/build/SKILL.md && echo "FLOOR-SCAN OK"
bash -n plugin/template/.claude/drive.sh && echo "DRIVE SYNTAX OK"
```
Expected: tiga OK.

- [ ] **Step 3: Adversarial-verify workflow (pola kerja user)**

Jalankan workflow adversarial (4–5 lensa, skeptik per-temuan) atas full diff dengan fokus lensa:
1. **Keamanan** — apa floor-scan B benar-benar nutup lubang auth-underclassify? ada verba bahaya yang kelewat dari daftar tweak §A?
2. **Konsistensi** — scaffold comment byte-identik? istilah "floor-scan" konsisten antar build SKILL/reference? reason-halt cocok antar §G/§H/SKILL?
3. **Regresi gate** — Security Gate `ship` benar-benar tak tersentuh? floor `migrate`/`needs_human`/`blocked` masih utuh?
4. **Headless-safety** — masih ada jalur di mana build Q&A interaktif saat headless? precheck drive.sh nutup `/schedule` juga atau cuma bash?
5. **Migrasi** — fitur lama ter-floor: jalur recovery jelas & nyata?

Beresin must-fix & should-fix (inline, commit terpisah per perbaikan).

- [ ] **Step 4: Final report**

Laporkan ke user: ringkas 8 commit + hasil adversarial-verify (temuan + yang dibereskan) + status "siap di-test live / merge". JANGAN auto-merge/auto-push (jatah user).

---

## Self-Review (penulis plan — sudah dijalankan)

- **Spec coverage:** §3 A→Task 1+2; §3 B→Task 2; §3 C→Task 3+4+5+6; §3 D→Task 6(recovery)+7; §4 invarian→Task 2(degrade)+7(WARN)+Task 9(regresi); §7 file list→Task 1–8; §8 verifikasi→tiap Task Step verifikasi + Task 9. ✓ Tak ada seksi spec tanpa task.
- **Placeholder scan:** nol TBD/TODO; tiap edit punya wording konkret + verifikasi grep/read-back. ✓
- **Consistency:** istilah "floor-scan diff", "Verba-keamanan/Verba-uang PLUMBING `tweak/reference.md` §A", "M7-amend 2026-06-18", "DIBANGUN UNATTENDED" dipakai konsisten lintas task. ✓
- **Catatan:** `/schedule` (Engkol 2) tak punya precheck seperti `drive.sh` (Engkol 1) — Task 5 (build-side allowlist-halt + notify-no-op transparan) yang menjaga jalur itu; diangkat eksplisit sebagai lensa 4 di Task 9.
