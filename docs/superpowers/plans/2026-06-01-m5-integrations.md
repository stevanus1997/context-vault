# M5 — Integrasi Vendor Eksternal — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Beri vendor eksternal (pembayaran/email/kurir/pajak) rumah durable lewat `control/integrations.md` + skill `add-integration`, sehingga kontrak vendor dipromote O(1) oleh `plan`, webhook inbound punya stub+task keamanan, dan `security-critic` punya baseline.

**Architecture:** Tiru pola `add-app`/`add-package`. File SHAPE-only `control/integrations.md` (sejajar `conventions.md`/`invariants.md`); skill conductor `add-integration` (sole-writer, tanpa `architect`); `fanout` menandai `VENDOR NEW`/`VENDOR TOUCHED — perlu UPDATE`; `feature` auto-invoke; `plan` promote; `breakdown`/`build` varian task inbound-eksternal di `unit:<app>`; `wire` mode-integration (stub); slot invarian + `security-critic` baca `integrations.md`; hygiene `ship`/`render-docs`/`drop`. Plugin tetap generic. Tidak menyandar M4/H3; tidak overload `packages[].consumers`.

**Tech Stack:** Markdown skill files (`plugin/skills/*/SKILL.md` + `reference.md`), template `control/` files, agent markdown, spec docs. Tidak ada kode runtime — semua edit instruksi-skill + template. Verifikasi = grep-battery + colon-space guard + dry-run reasoning.

**Sumber kebenaran:** `docs/superpowers/specs/2026-06-01-m5-integrations-design.md` (§-pointer di tiap task).

**Urutan & staging (spec §12):** Stage 1 (T1–T9 — deklarasi & promote, mergeable sendiri) → Stage 2 (T10–T17 — inbound & keamanan) → Amandemen (T18). Tiap task = satu file (atau satu pasang SKILL+reference) + commit sendiri.

**Bug-guard yang dipasang preventif (spec §13, handoff §5):**
- **Colon-space:** tiap `description:` frontmatter baru/diedit TAK boleh mengandung `": "`. Verifikasi tiap task yang menyentuh frontmatter: `sed -n 's/^description: //p' FILE | grep ': '` → **harus kosong**.
- **Renumber:** semua sisipan pakai **sub-bullet/desimal/section baru** — JANGAN me-renumber integer step. `architect` 4.5 & `ship` 4.5/step 6 cuma DIPERLUAS.
- **Mis-aimed pointer:** `§J`/`§D`/`§I` di skill = section `wire/reference.md`; `§N` di spec = spec M5. Verifikasi tiap pointer.
- **Sentinel:** slot invarian baru pakai `<belum dikunci>` yang SUDAH ada; `integrations.md` TIDAK memperkenalkan sentinel baru.
- **Sole-writer:** hanya `add-integration` menulis entri `integrations.md`.
- **Generic:** `stripe`/`sk_test_` hanya sebagai contoh berlabel, bukan skema.

---

## Task 1: Template `control/integrations.md` (BARU)

Spec §4.1, §4.3.

**Files:**
- Create: `plugin/template/control/integrations.md`

- [ ] **Step 1: Create the file**

Tulis `plugin/template/control/integrations.md` dengan isi PERSIS:

```markdown
# <PRODUCT> — Integrasi Vendor Eksternal

> Kontrak SHAPE tiap layanan pihak-ketiga (pembayaran, email, kurir, pajak, dst).
> TANPA nilai secret — hanya NAMA env var. Entri diisi `add-integration` saat sebuah
> fitur butuh vendor baru (dipicu `fanout` → VENDOR NEW). Dibaca `plan` (promote kontrak),
> `security-critic` (baseline), `ship` (runbook deploy).
>
> Belum ada vendor — daftar tumbuh just-in-time lewat add-integration.
>
> Bentuk tiap entri (ditambah add-integration):
>
>     ## <vendor>
>     Arah         : outbound | inbound | both
>     Dipakai      : <ringkas; mis. proses pembayaran>
>     Endpoint     : <base URL pattern (outbound) / path webhook (inbound) — SHAPE, bukan rahasia>
>     Receiver app : <nama app dari apps[] yang menerima webhook — hanya bila Arah memuat inbound>
>     Idempotency  : <bentuk key; mis. header Idempotency-Key tiap request outbound>
>     Mode         : test | live (per environment)
>     Secret env   : <NAMA env var — tanpa nilai>
>     Retry        : <kebijakan; mis. backoff 3x>
>     Signature    : <algo verifikasi inbound; mis. HMAC-SHA256 — hanya bila inbound>
>     Wrapped by   : <package opsional yang membungkus vendor ini — opsional>
```

- [ ] **Step 2: Verify (no new scanned sentinel; PRODUCT placeholder present)**

Run: `grep -c '<PRODUCT>' plugin/template/control/integrations.md && grep -c 'belum dikunci' plugin/template/control/integrations.md`
Expected: first `1` (placeholder ada), second `0` (TIDAK memakai sentinel invariants.md — bukan literal-scan trap).

- [ ] **Step 3: Commit**

```bash
git add plugin/template/control/integrations.md
git commit -m "feat(template): control/integrations.md SHAPE template (M5 §4)"
```

---

## Task 2: `init` seed `integrations.md` (`<PRODUCT>`-replace)

Spec §4.3. `init` langkah 4 sudah `cp -R` seluruh `template/control/` → `integrations.md` ikut tercopy otomatis; cuma perlu masuk daftar file yang di-`<PRODUCT>`-replace.

**Files:**
- Modify: `plugin/skills/init/SKILL.md` (langkah 4)

- [ ] **Step 1: Edit the `<PRODUCT>`-replace list**

Find (verbatim):
```
- Ganti placeholder `<PRODUCT>` dengan nama produk di SEMUA file `control/` yang baru di-scaffold (semua `business/*.md`, `conventions.md`, **dan** `invariants.md`) — `<PRODUCT>` selalu berarti nama produk, jadi jangan tinggalkan satu pun.
```
Replace with:
```
- Ganti placeholder `<PRODUCT>` dengan nama produk di SEMUA file `control/` yang baru di-scaffold (semua `business/*.md`, `conventions.md`, `invariants.md`, **dan** `integrations.md`) — `<PRODUCT>` selalu berarti nama produk, jadi jangan tinggalkan satu pun.
```

- [ ] **Step 2: Verify**

Run: `grep -c 'invariants.md`, **dan** `integrations.md`' plugin/skills/init/SKILL.md`
Expected: `1`

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/init/SKILL.md
git commit -m "feat(init): seed control/integrations.md (PRODUCT-replace, M5 §4.3)"
```

---

## Task 3: Skill `add-integration` (BARU)

Spec §5. Conductor cermin `add-package` (tanpa `reference.md`, tanpa `architect`).

**Files:**
- Create: `plugin/skills/add-integration/SKILL.md`

- [ ] **Step 1: Create the file**

Tulis `plugin/skills/add-integration/SKILL.md` dengan isi PERSIS (perhatikan: `description:` value TANPA `": "`):

```markdown
---
name: add-integration
description: Use untuk nambah SATU vendor eksternal (pembayaran/email/kurir/pajak) ke produk yang sudah di-init — tulis kontrak SHAPE ke control/integrations.md lalu (bila inbound) chain wire mode-integration buat scaffold stub webhook-receiver. Satu-satunya penulis entri integrations.md. Dipanggil feature saat fanout nandain vendor baru, atau standalone. Trigger — "add-integration <vendor>", "tambah integrasi", "daftar vendor", "scaffold webhook". Jalankan dari root produk yang punya control/.
---

# add-integration — Nambah Vendor Eksternal (declare lalu wire mode-integration bila inbound)

Tujuan: numbuhin produk yang SUDAH di-`init` dengan SATU vendor eksternal (layanan pihak-ketiga — pembayaran/email/kurir/pajak). `add-integration` = konduktor tipis: tulis kontrak SHAPE vendor ke `control/integrations.md`, lalu (HANYA bila vendor punya arah inbound) chain `wire` mode-integration buat scaffold stub webhook-receiver + rekam SHAPE env. Jalankan dari root produk (punya `control/`).

`add-integration` = **kembaran `add-app`/`add-package`** (lihat spec `2026-06-01-m5-integrations-design.md`), beda penting: vendor TAK punya stack → **TIDAK** chain `architect`; vendor outbound-only → cukup rekam SHAPE env, **TANPA** `wire`.

## Prinsip (jangan dilanggar)
- **Bukan `init`.** `control/` harus sudah ada (post-init); `control/integrations.md` sudah ada (di-seed `init`). Minimal satu app sudah ada (vendor dipakai/diterima sebuah app).
- **SHAPE-only, TANPA secret.** `add-integration` nanya BENTUK kontrak (arah/endpoint/idempotency/mode/NAMA env var/retry/signature). NILAI secret JANGAN pernah ditulis ke `control/`/git — itu `.env` lewat GATE/manual.
- **Vendor, bukan app/package.** Vendor = layanan eksternal pihak-ketiga, bukan kode kita; tak punya stack/DB/route sendiri.
- **Idempotent.** Vendor yang sudah ada di `integrations.md` → ini UPDATE (perluas SHAPE) atau STOP bila tak berubah; jangan bikin section ganda.
- **Satu-satunya penulis entri `integrations.md`.** `fanout`/`plan`/`security-critic`/`ship`/`render-docs` cuma membaca.
- **Tiap aksi side-effecting = GATE.** Tulis entri = gate sendiri; `wire` pakai gate-nya.
- **Invarian platform tak di-relock.** Vendor = CONSUMER invarian; prasyarat slot "Integrasi & Webhook Eksternal" terkunci (backstop).

## Langkah (urut)

### 0. Baca state
Baca `control/integrations.md` + `control/workspace.yaml` (`apps[]`) + `control/conventions.md` + `control/invariants.md`. **Prasyarat:** `control/` ada — kalau nggak, arahin ke `init`. **Prasyarat invarian (BACKSTOP):** kalau slot `## Integrasi & Webhook Eksternal` di `invariants.md` masih `<belum dikunci>` → **STOP**, arahin ke `architect` "Kunci Invarian" dulu (bukan deadlock — sekadar arah-ulang; normalnya invarian sudah terkunci sebelum fitur pertama).

### 1. Cek duplikat (idempotent)
Kalau vendor `<vendor>` sudah ada di `integrations.md`:
- SHAPE yang dibutuhkan sudah tercakup `Arah`-nya → **STOP**, jangan re-declare.
- Butuh perluasan (mis. tambah arah `inbound` ke vendor `outbound`-only) → lanjut sebagai **UPDATE** (perluas entri yang ADA, jangan bikin section kedua).

### 2. Q&A SHAPE (level DEKLARASI kontrak, BUKAN nilai)
Tanya (lewati yang tak relevan ke arah vendor):
- Arah — outbound (kita panggil vendor) / inbound (vendor panggil kita) / both
- Dipakai — satu kalimat (mis. "proses pembayaran & payout")
- Endpoint — base URL pattern (outbound) / path webhook (inbound); SHAPE, bukan rahasia
- Idempotency — bentuk key (mis. header Idempotency-Key tiap request)
- Mode — test / live (per environment)
- Secret env — NAMA env var (mis. PAYMENTS_API_KEY); TANPA nilai
- Retry — kebijakan (mis. backoff 3x)
- (bila inbound) Signature — algo verifikasi (mis. HMAC-SHA256 di header X-Signature)
- (bila inbound) Receiver app — app dari `apps[]` yang menerima webhook → isi field DURABLE (biar `plan` sesi-lain tak nebak)
- (opsional) Wrapped by — package H2 yang membungkus vendor ini (pointer 1-arah; JANGAN pakai `packages[].consumers`)

JANGAN minta NILAI secret apa pun.

### 3. Tulis entri ke integrations.md (GATE)
Tambah/perbarui section `## <vendor>` di `control/integrations.md` (format di header template `integrations.md`). **Validasi SHAPE-only:** tak ada nilai yang terlihat seperti secret asli — cuma NAMA env var. Tampilkan diff → minta **approve**.

### 4. Rekam SHAPE env + (bila inbound) wire mode-integration
- **SELALU** (outbound & inbound): rekam SHAPE env (NAMA var) ke `conventions.md` lewat pola env `wire` (`wire/reference.md` §D) — satu mekanisme yang sama.
- **HANYA bila `Arah` memuat inbound:** invoke `wire` (MODE-INTEGRATION, `wire/reference.md` §J) buat scaffold stub webhook-receiver di `Receiver app` → GATE = app tetap boot + route ter-register + typecheck. Logika verifikasi signature/idempotent/replay = jatah `build`, BUKAN di sini.
- Outbound-only berhenti setelah rekam SHAPE env (tak ada receiver untuk di-scaffold).

### 5. Tutup & balikin
Lapor "**vendor `<vendor>` terdeklarasi di integrations.md**".
- Dipanggil `feature` (fitur butuh vendor baru) → balikin kontrol ke `feature` buat lanjut `plan`.
- Standalone → saranin langkah berikutnya (mis. `feature <fitur>`).

## Catatan
- **Cara kanonik nambah vendor pasca-`init`.** Yang nulis entri `integrations.md` cuma `add-integration`.
- **Beda dari `add-app`/`add-package`:** TAK chain `architect` (vendor tak punya stack); outbound-only TAK chain `wire`. Selain itu polanya identik (declare → bring-up gated).
- TIDAK nyentuh `control/business/*`, TIDAK nulis kode fitur (itu `build`), TIDAK nulis NILAI secret (itu `.env` GATE/manual).
```

- [ ] **Step 2: Verify (colon-space guard + structure)**

Run: `sed -n 's/^description: //p' plugin/skills/add-integration/SKILL.md | grep ': ' ; echo "exit=$?"`
Expected: no matching lines, `exit=1` (grep found nothing → description bebas `": "`).

Run: `grep -c '### 0. Baca state\|### 5. Tutup' plugin/skills/add-integration/SKILL.md`
Expected: `2`

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/add-integration/SKILL.md
git commit -m "feat(add-integration): skill konduktor vendor eksternal (M5 §5)"
```

---

## Task 4: `fanout` — deteksi & tandai vendor

Spec §7.1. Empat sisipan ke `fanout/SKILL.md`: baca `integrations.md` (step 1), bullet deteksi vendor (step 2), challenge checklist (step 3), marker di template output (step 4). Semua **sub-bullet/baris baru** — tanpa renumber.

**Files:**
- Modify: `plugin/skills/fanout/SKILL.md`

- [ ] **Step 1: Step 1 — baca `integrations.md`**

Find (verbatim):
```
Baca `control/features/<fitur>/business.md` + `control/workspace.yaml` (apps, capabilities, responsibility, **packages** + consumers).
```
Replace with:
```
Baca `control/features/<fitur>/business.md` + `control/workspace.yaml` (apps, capabilities, responsibility, **packages** + consumers) + `control/integrations.md` (vendor eksternal yang sudah dideklarasi).
```

- [ ] **Step 2: Step 2 — bullet deteksi vendor (sisip setelah bullet PACKAGE)**

Find (verbatim — bullet shared-package, baris terakhirnya):
```
- **Kalau ADA kode-bareng yang dipakai >1 app** (mis. format uang, tipe domain bersama) → mungkin **SHARED PACKAGE**. Tantang (anti-yes-man): beneran shared >1 app, atau cukup 1 app saja? Lolos → tandai `PACKAGE NEW: <nama>` (langkah 4); diwujudkan `add-package` (dipanggil otomatis `feature`). **Kalau fitur menyentuh API package yang SUDAH ADA** → tandai `PACKAGE TOUCHED: <nama>` + tarik daftar consumer dari `packages[<nama>].consumers` (basis fan-IN; `plan` yang memutuskan BREAKING).
```
Replace with (tambah bullet vendor di bawahnya):
```
- **Kalau ADA kode-bareng yang dipakai >1 app** (mis. format uang, tipe domain bersama) → mungkin **SHARED PACKAGE**. Tantang (anti-yes-man): beneran shared >1 app, atau cukup 1 app saja? Lolos → tandai `PACKAGE NEW: <nama>` (langkah 4); diwujudkan `add-package` (dipanggil otomatis `feature`). **Kalau fitur menyentuh API package yang SUDAH ADA** → tandai `PACKAGE TOUCHED: <nama>` + tarik daftar consumer dari `packages[<nama>].consumers` (basis fan-IN; `plan` yang memutuskan BREAKING).
- **Kalau ADA kebutuhan layanan pihak-ketiga** (pembayaran/email/kurir/pajak/dst) → mungkin **VENDOR EKSTERNAL**. Tantang (anti-yes-man): beneran butuh vendor luar, atau bisa in-house / sudah ada vendor existing yang menanggung? Lolos → bandingkan arah yang dibutuhkan (kita panggil vendor? vendor panggil kita?) dengan `integrations.md`: vendor **belum ada** → tandai `VENDOR NEW: <vendor>`; vendor **sudah ada & `Arah`-nya mencakup** kebutuhan → `VENDOR TOUCHED: <vendor>` (informatif; `plan` promote kontrak existing); vendor **sudah ada TAPI `Arah`/SHAPE belum mencakup** (mis. entri outbound-only, fitur butuh webhook inbound) → `VENDOR TOUCHED — perlu UPDATE: <vendor> (butuh <arah>)`. Diwujudkan `add-integration` (dipanggil otomatis `feature` untuk `VENDOR NEW` + `perlu UPDATE`). `fanout` cuma **MENGUSULKAN** — yang nulis `integrations.md` = `add-integration`.
```

- [ ] **Step 3: Step 3 — challenge checklist (sisip baris)**

Find (verbatim):
```
- Ada kode-bareng >1 app → butuh shared package? (beneran shared, atau cukup 1 app?) Ada API package existing yang disentuh → consumer mana yang kena?
```
Replace with:
```
- Ada kode-bareng >1 app → butuh shared package? (beneran shared, atau cukup 1 app?) Ada API package existing yang disentuh → consumer mana yang kena?
- Ada kebutuhan layanan pihak-ketiga → butuh vendor eksternal? (beneran perlu, atau in-house/sudah ada?) Vendor existing tapi arah/SHAPE belum cukup → perlu UPDATE?
```

- [ ] **Step 4: Step 4 — marker di template output (sisip baris)**

Find (verbatim):
```
<pkg> (PACKAGE TOUCHED) : <API yang disentuh> [consumers: <app1, app2>]   # basis fan-IN
```
Replace with:
```
<pkg> (PACKAGE TOUCHED) : <API yang disentuh> [consumers: <app1, app2>]   # basis fan-IN
<vendor> (VENDOR NEW — belum ada) : <peran>        # vendor eksternal baru; diwujudkan add-integration
<vendor> (VENDOR TOUCHED — perlu UPDATE) : <butuh arah>   # vendor existing, SHAPE perlu diperluas
```

- [ ] **Step 5: Verify**

Run: `grep -c 'VENDOR NEW\|VENDOR TOUCHED\|integrations.md\|layanan pihak-ketiga' plugin/skills/fanout/SKILL.md`
Expected: `>= 5` (deteksi + challenge + 2 marker + step1 read).

- [ ] **Step 6: Commit**

```bash
git add plugin/skills/fanout/SKILL.md
git commit -m "feat(fanout): deteksi + tandai VENDOR NEW/TOUCHED/perlu-UPDATE (M5 §7.1)"
```

---

## Task 5: `feature` — auto-invoke `add-integration`

Spec §7.2. Sisip loop ketiga setelah loop `add-package`, sebelum `plan` — sub-bullet, tanpa renumber.

**Files:**
- Modify: `plugin/skills/feature/SKILL.md` (langkah 2)

- [ ] **Step 1: Sisip bullet loop + update kalimat urutan**

Find (verbatim):
```
   - **Bila `fanout.md` nandain `PACKAGE NEW` (belum ada):** untuk tiap package baru, invoke skill **`add-package <nama-pkg>`** (declare entri → `architect` → `wire` mode-package, semua gated) → tunggu beres.
   - Selesaikan SEMUA `add-app` lalu `add-package` dulu, **baru lanjut ke `plan`**. Saat `plan` jalan, app/package baru sudah ada di `workspace.yaml` (app ter-wire; package ter-typecheck).
```
Replace with:
```
   - **Bila `fanout.md` nandain `PACKAGE NEW` (belum ada):** untuk tiap package baru, invoke skill **`add-package <nama-pkg>`** (declare entri → `architect` → `wire` mode-package, semua gated) → tunggu beres.
   - **Bila `fanout.md` nandain `VENDOR NEW` atau `VENDOR TOUCHED — perlu UPDATE`:** untuk tiap vendor itu, invoke skill **`add-integration <vendor>`** (declare kontrak SHAPE → `wire` mode-integration bila inbound, gated) → tunggu beres. Plain `VENDOR TOUCHED` (tanpa perlu-UPDATE) TIDAK di-invoke — cukup `plan` promote kontrak existing.
   - Selesaikan SEMUA `add-app` lalu `add-package` lalu `add-integration` dulu, **baru lanjut ke `plan`**. Saat `plan` jalan, app/package baru sudah ada di `workspace.yaml` (app ter-wire; package ter-typecheck) & vendor sudah ada di `integrations.md`.
```

- [ ] **Step 2: Verify**

Run: `grep -c 'add-integration' plugin/skills/feature/SKILL.md`
Expected: `>= 2`

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/feature/SKILL.md
git commit -m "feat(feature): auto-invoke add-integration loop (M5 §7.2)"
```

---

## Task 6: `plan` — promote kontrak vendor (O(1))

Spec §7.3. Tiga sisipan: baca `integrations.md` (step 1), step baru `2c` (promote + receiver line, idempotent), challenge (step 3). Pakai step baru `2c` (decimal) — tanpa renumber.

**Files:**
- Modify: `plugin/skills/plan/SKILL.md`

- [ ] **Step 1: Step 1 — baca `integrations.md`**

Find (verbatim):
```
Baca `control/features/<fitur>/business.md` + `fanout.md` + `control/conventions.md` + `control/workspace.yaml` (untuk `path` & `stack` tiap app, **plus `packages[]` + `consumers[]` — read-only; `plan` tak pernah menulis `consumers[]`, itu jatah `fanout`**).
```
Replace with:
```
Baca `control/features/<fitur>/business.md` + `fanout.md` + `control/conventions.md` + `control/workspace.yaml` (untuk `path` & `stack` tiap app, **plus `packages[]` + `consumers[]` — read-only; `plan` tak pernah menulis `consumers[]`, itu jatah `fanout`**) + `control/integrations.md` (kontrak vendor eksternal — read-only).
```

- [ ] **Step 2: Sisip step `2c` (promote vendor) setelah step `2b`**

Find (verbatim — akhir blok 2b, baris carve-out package baru):
```
**Deteksi BREAKING (fan-IN):** kalau package SUDAH ADA sebelum fitur ini (`PACKAGE TOUCHED`, punya kode terkini) dan exports/signature berubah dibanding kode terkini → tandai **`BREAKING`** di `plans/<pkg>.md` + daftar consumer terdampak. **Carve-out package baru:** package yang **baru dibikin fitur ini** (`PACKAGE NEW`, lewat `add-package`) tak punya kontrak sebelumnya → **TIDAK ada `BREAKING`**; consumer-nya dapat integrasi fan-OUT biasa. (Cek: package ada di `workspace.yaml` saat fitur mulai?)
```
Replace with (tambah blok 2c di bawahnya):
```
**Deteksi BREAKING (fan-IN):** kalau package SUDAH ADA sebelum fitur ini (`PACKAGE TOUCHED`, punya kode terkini) dan exports/signature berubah dibanding kode terkini → tandai **`BREAKING`** di `plans/<pkg>.md` + daftar consumer terdampak. **Carve-out package baru:** package yang **baru dibikin fitur ini** (`PACKAGE NEW`, lewat `add-package`) tak punya kontrak sebelumnya → **TIDAK ada `BREAKING`**; consumer-nya dapat integrasi fan-OUT biasa. (Cek: package ada di `workspace.yaml` saat fitur mulai?)

### 2c. Promote kontrak vendor (untuk tiap vendor di fanout.md)
Untuk tiap vendor yang kena fitur (`VENDOR NEW`/`VENDOR TOUCHED`/`…perlu UPDATE`), **promote** kontraknya dari `control/integrations.md` ke `plans/_shared.md` — **referensikan**, bukan derive ulang. **Idempotent:** kalau kontrak vendor itu sudah ada di `_shared.md` (fitur lebih awal sudah promote) → reuse/referensikan, JANGAN tulis ulang. Mis. "Pembayaran via `<vendor>` — outbound dgn Idempotency-Key per request; inbound webhook di `<Receiver app>` path `<...>`, verifikasi `<Signature>`."
**Kebutuhan receiver (vendor inbound/both):** ambil `Receiver app` dari entri `integrations.md` (field durable) → tulis di `plans/<Receiver app>.md` satu baris: "Webhook masuk `<vendor>` di `<path>`: verifikasi signature (`<algo>`), idempotent (dedup), tahan replay." → basis varian task inbound-eksternal `breakdown`. (`plan` read-only ke `integrations.md`; `Receiver app` HARUS dari situ, bukan ditebak.)
```

- [ ] **Step 3: Step 3 — challenge "vendor tanpa kontrak"**

Find (verbatim):
```
- **Challenge teknis** sebelum gate: konsistensi dengan konvensi? risiko? cara lebih sederhana? Apakah plan ini melanggar invarian yang terkunci di `control/invariants.md` (tenancy/money/idempotency/authz/PII-PCI)? **Apakah app ini membuat logika yang seharusnya pakai mandatory package** (mis. format uang sendiri padahal `money` ada di `packages[].mandatory_for` app ini)?
```
Replace with:
```
- **Challenge teknis** sebelum gate: konsistensi dengan konvensi? risiko? cara lebih sederhana? Apakah plan ini melanggar invarian yang terkunci di `control/invariants.md` (tenancy/money/idempotency/authz/PII-PCI)? **Apakah app ini membuat logika yang seharusnya pakai mandatory package** (mis. format uang sendiri padahal `money` ada di `packages[].mandatory_for` app ini)? **Apakah fitur menyentuh vendor eksternal tapi kontraknya tak ada di `control/integrations.md`** (seam `fanout` terlewat)? → arahkan jalankan `add-integration`.
```

- [ ] **Step 4: Verify (+ renumber-cross-ref aman — step 2c tak ganggu integer)**

Run: `grep -c 'integrations.md\|### 2c\|Receiver app\|vendor eksternal' plugin/skills/plan/SKILL.md`
Expected: `>= 4`

Run: `grep -n '### ' plugin/skills/plan/SKILL.md`
Expected: urutan heading `### 1.` `### 2.` `### 2b.` `### 2c.` `### 3.` `### 4.` (integer step 3/4 TIDAK berubah).

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/plan/SKILL.md
git commit -m "feat(plan): promote kontrak vendor O(1) + receiver line + challenge (M5 §7.3)"
```

---

## Task 7: `render-docs` — kartu integrasi

Spec §9.2. Dua sisipan (mirror perlakuan kartu package, yang juga tanpa SLOT template khusus): baca `integrations.md` (step 1), bullet kartu integrasi (step 3).

**Files:**
- Modify: `plugin/skills/render-docs/SKILL.md`

- [ ] **Step 1: Step 1 — baca `integrations.md`**

Find (verbatim):
```
- `control/workspace.yaml` → `product`, `topology`, daftar `apps` (name, type, responsibility, capabilities, stack) + daftar `packages` (name, responsibility, consumers, mandatory_for).
```
Replace with:
```
- `control/workspace.yaml` → `product`, `topology`, daftar `apps` (name, type, responsibility, capabilities, stack) + daftar `packages` (name, responsibility, consumers, mandatory_for).
- `control/integrations.md` → daftar vendor eksternal (vendor, Arah, Dipakai, Mode) — SHAPE-only, TANPA secret.
```

- [ ] **Step 2: Step 3 — bullet kartu integrasi (sisip setelah bullet packages)**

Find (verbatim):
```
- **packages:** satu `.card` per shared package (bila ada): judul `name` + label "package", `responsibility`, `consumers` (app yang memakai) sebagai `.chip`, tandai `mandatory_for` bila ada. Bedakan visual dari kartu app.
```
Replace with:
```
- **packages:** satu `.card` per shared package (bila ada): judul `name` + label "package", `responsibility`, `consumers` (app yang memakai) sebagai `.chip`, tandai `mandatory_for` bila ada. Bedakan visual dari kartu app.
- **integrations:** satu `.card` per vendor eksternal (bila ada, dari `integrations.md`): judul `vendor` + label "integrasi", `Dipakai`, `Arah` + `Mode` sebagai `.chip`. SHAPE-only — JANGAN tampilkan nilai secret (cuma NAMA env var bila perlu). Bedakan visual dari kartu app/package.
```

- [ ] **Step 3: Verify**

Run: `grep -c 'integrations.md\|integrasi' plugin/skills/render-docs/SKILL.md`
Expected: `>= 2`

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/render-docs/SKILL.md
git commit -m "feat(render-docs): kartu integrasi vendor (M5 §9.2)"
```

---

## Task 8: `drop` — pengingat provenance vendor

Spec §9.3. Sisip ke step 3 (review promosi knowledge), sub-bullet — sejajar dengan pembersihan app/package yang sudah ada.

**Files:**
- Modify: `plugin/skills/drop/SKILL.md` (langkah 3)

- [ ] **Step 1: Sisip sub-bullet provenance vendor**

Find (verbatim):
```
- **Bila fitur ini bikin app/package baru yang ikut di-drop:** kalau sebuah **app** dihapus, bersihkan namanya dari semua `packages[].consumers` + `mandatory_for` (jangan tinggalkan consumer hantu yang bikin fan-IN salah-target).
```
Replace with:
```
- **Bila fitur ini bikin app/package baru yang ikut di-drop:** kalau sebuah **app** dihapus, bersihkan namanya dari semua `packages[].consumers` + `mandatory_for` (jangan tinggalkan consumer hantu yang bikin fan-IN salah-target).
- **Bila fitur ini memperkenalkan vendor eksternal** (cek `fanout.md` fitur): **pengingat lunak** ke user — "fitur ini memperkenalkan `<vendor>`; tinjau apakah entri `control/integrations.md` masih dipakai fitur lain sebelum dibersihkan." Tanpa mesin keras (v1 tak melacak vendor-consumers presisi); drop entri `integrations.md` = aksi manual user.
```

- [ ] **Step 2: Verify**

Run: `grep -c 'vendor eksternal\|integrations.md' plugin/skills/drop/SKILL.md`
Expected: `>= 1`

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/drop/SKILL.md
git commit -m "feat(drop): pengingat provenance vendor saat drop fitur (M5 §9.3)"
```

---

## Task 9: `conventions.md` template — heading "Konvensi Integrasi"

Spec §9.4. Heading kosong (diisi `add-integration`/`wire`).

**Files:**
- Modify: `plugin/template/control/conventions.md`

- [ ] **Step 1: Tambah heading di akhir**

Find (verbatim):
```
## Konvensi Package
<!-- Diisi architect saat add-package: path import, build/test tool, sinyal breaking/deprecation. -->
```
Replace with:
```
## Konvensi Package
<!-- Diisi architect saat add-package: path import, build/test tool, sinyal breaking/deprecation. -->

## Konvensi Integrasi
<!-- Diisi saat add-integration/wire: SHAPE env vendor (NAMA var, tanpa nilai), konvensi webhook-receiver. -->
```

- [ ] **Step 2: Verify**

Run: `grep -c 'Konvensi Integrasi' plugin/template/control/conventions.md`
Expected: `1`

- [ ] **Step 3: Commit**

```bash
git add plugin/template/control/conventions.md
git commit -m "feat(template): heading Konvensi Integrasi (M5 §9.4)"
```

---

## Task 10: `wire/reference.md` — §J mode-integration (BARU)

Spec §6. Tambah section §J setelah §I (yang kini terakhir).

**Files:**
- Modify: `plugin/skills/wire/reference.md`

- [ ] **Step 1: Tambah §J di akhir file**

Find (verbatim — akhir §I, baris terakhir file):
```
- **Multi-repo:** sama seperti app — `git -C <packages[pkg].path> rev-parse --show-toplevel`, branch per repo unik (§G).
```
Replace with:
```
- **Multi-repo:** sama seperti app — `git -C <packages[pkg].path> rev-parse --show-toplevel`, branch per repo unik (§G).

## J. Mode-integration (vendor eksternal inbound)

Vendor eksternal dengan arah **inbound** (vendor mengirim webhook ke kita) butuh endpoint penerima. Dipanggil `add-integration` (hanya bila `Arah` memuat inbound).

- **Yang DIKERJAKAN:** scaffold **stub** route webhook-receiver di app penerima (`Receiver app` dari entri `integrations.md`): route ter-register di framework app, handler mengembalikan placeholder (mis. 200/501) — **BELUM** ada logika verifikasi. Plus rekam SHAPE env vendor (NAMA var, mis. `<VENDOR>_WEBHOOK_SECRET`) ke `conventions.md` (pola §D).
- **Gate penutup mode-integration** = app tetap boot + route ter-register + typecheck/lint hijau. (Tak ada smoke HTTP penuh.)
- **Yang DI-SKIP:** verifikasi signature, idempotent/replay, test keamanan → itu **task `build`** (varian inbound-eksternal). Secret = tetap GATE/manual (§D); JANGAN masuk `control/`/git.
- **Outbound-only** tak menyentuh mode-integration (tak ada receiver) — `add-integration` cukup merekam SHAPE env (§D).
- Reuse scaffolder app + mesin env `build` yang sama (§H); tak ada duplikasi.
```

- [ ] **Step 2: Verify (§J ada, pointer benar)**

Run: `grep -c '## J. Mode-integration\|stub route webhook-receiver' plugin/skills/wire/reference.md`
Expected: `2`

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/wire/reference.md
git commit -m "feat(wire): reference §J mode-integration webhook stub (M5 §6)"
```

---

## Task 11: `wire/SKILL.md` — deteksi mode-integration

Spec §6. Sisip bullet di step 0 (setelah bullet mode-package) + note di Catatan.

**Files:**
- Modify: `plugin/skills/wire/SKILL.md`

- [ ] **Step 1: Step 0 — bullet mode-integration**

Find (verbatim):
```
- **Unit `type: package` → MODE-PACKAGE (reference §I):** package tak punya DB/server/route. Scaffold skeleton lib + register di workspace; **gate penutup = typecheck/lint hijau**; SKIP langkah 2 (DB), 3 (ORM/migrate), 4 (FE↔BE), 6 (smoke runtime). Resolve `path` dari `packages[].path`.
```
Replace with:
```
- **Unit `type: package` → MODE-PACKAGE (reference §I):** package tak punya DB/server/route. Scaffold skeleton lib + register di workspace; **gate penutup = typecheck/lint hijau**; SKIP langkah 2 (DB), 3 (ORM/migrate), 4 (FE↔BE), 6 (smoke runtime). Resolve `path` dari `packages[].path`.
- **Dipanggil `add-integration` untuk vendor inbound → MODE-INTEGRATION (reference §J):** scaffold stub route webhook-receiver di app penerima (`Receiver app`) + rekam SHAPE env vendor ke `conventions.md`; **gate = app boot + route ter-register + typecheck**; SKIP DB/ORM/FE↔BE/smoke penuh. Logika verifikasi signature/idempotent = jatah `build`.
```

- [ ] **Step 2: Catatan — sebut add-integration**

Find (verbatim):
```
- `wire` sekali jalan (kayak `extract`). Saat nambah app baru, dipanggil oleh skill `add-app` (yang chain `architect`→`wire`); saat nambah shared package, dipanggil oleh skill `add-package` (mode-package — reference §I); bisa juga di-rerun manual. Brownfield: bersifat **repair** — hanya bila wiring belum lengkap.
```
Replace with:
```
- `wire` sekali jalan (kayak `extract`). Saat nambah app baru, dipanggil oleh skill `add-app` (yang chain `architect`→`wire`); saat nambah shared package, dipanggil oleh skill `add-package` (mode-package — reference §I); saat nambah vendor eksternal inbound, dipanggil oleh skill `add-integration` (mode-integration — reference §J); bisa juga di-rerun manual. Brownfield: bersifat **repair** — hanya bila wiring belum lengkap.
```

- [ ] **Step 3: Verify**

Run: `grep -c 'MODE-INTEGRATION\|mode-integration\|reference §J' plugin/skills/wire/SKILL.md`
Expected: `>= 2`

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/wire/SKILL.md
git commit -m "feat(wire): deteksi mode-integration dari add-integration (M5 §6)"
```

---

## Task 12: `breakdown` — varian task inbound-eksternal

Spec §7.4. Sisip ke `reference.md` §D (item baru 5) + satu baris di `SKILL.md` step 4 (coverage). Tanpa field skema baru — task biasa `unit:<app>`.

**Files:**
- Modify: `plugin/skills/breakdown/reference.md` (§D)
- Modify: `plugin/skills/breakdown/SKILL.md` (langkah 4)

- [ ] **Step 1: `reference.md` §D — tambah item 5 (inbound-eksternal)**

Find (verbatim — akhir §D item 4):
```
4. **Task package & fan-IN.** Task yang hidup di shared package → `unit: <nama-pkg>` (cocok `packages[].name`); **DILARANG** `actions: [migrate]`/`actions: [env]` (package tak punya DB/infra); `test` = typecheck/unit exports. **Fan-IN (saat `plans/<pkg>.md` ber-flag `BREAKING`):** terbitkan 1 task `unit: <pkg>` (ubah package) + **1 update-task per consumer** (`unit: <consumer-app>`, `deps: [task-pkg]`) untuk tiap nama di `packages[<pkg>].consumers` + 1 task `unit: integration` (roundtrip package↔consumer). Pseudo-unit `integration` diperluas mencakup roundtrip package↔consumer (boot consumer app, panggil exports package, assert sesuai kontrak `plans/<pkg>.md`).
```
Replace with:
```
4. **Task package & fan-IN.** Task yang hidup di shared package → `unit: <nama-pkg>` (cocok `packages[].name`); **DILARANG** `actions: [migrate]`/`actions: [env]` (package tak punya DB/infra); `test` = typecheck/unit exports. **Fan-IN (saat `plans/<pkg>.md` ber-flag `BREAKING`):** terbitkan 1 task `unit: <pkg>` (ubah package) + **1 update-task per consumer** (`unit: <consumer-app>`, `deps: [task-pkg]`) untuk tiap nama di `packages[<pkg>].consumers` + 1 task `unit: integration` (roundtrip package↔consumer). Pseudo-unit `integration` diperluas mencakup roundtrip package↔consumer (boot consumer app, panggil exports package, assert sesuai kontrak `plans/<pkg>.md`).
5. **Task inbound-eksternal (webhook vendor).** Saat `plans/<Receiver app>.md` memuat baris "kebutuhan receiver" (dari `plan` §2c — vendor inbound/both di `integrations.md`), terbitkan task biasa `unit: <Receiver app>` (app NYATA — BUKAN pseudo-unit `integration`): `approach` = "terima webhook `<vendor>`: verifikasi signature per `integrations.md`, idempotent (dedup key), tahan replay"; `actions` boleh `env: [<VENDOR>_WEBHOOK_SECRET]` (NAMA var; `build` tulis ke `.env`, nilai GATE/manual); `test` (kasus keamanan baku) = "signature salah → tolak 401/403", "id/event duplikat → respons sama, tak proses 2× (idempotent/replay)". Vendor **outbound** = task biasa pada app pemanggil (panggil API vendor + idempotency-key + retry sesuai `integrations.md`) — tak butuh varian khusus.
```

- [ ] **Step 2: `SKILL.md` step 4 — coverage line untuk vendor inbound**

Find (verbatim):
```
- **Fan-IN coverage:** kalau `plans/<pkg>.md` ber-flag `BREAKING`, tiap consumer di `packages[<pkg>].consumers` WAJIB punya ≥1 task (update-task `unit: <consumer>` atau ter-cover task `unit: integration`). (Skema fan-IN: `reference.md` §D-4.)
```
Replace with:
```
- **Fan-IN coverage:** kalau `plans/<pkg>.md` ber-flag `BREAKING`, tiap consumer di `packages[<pkg>].consumers` WAJIB punya ≥1 task (update-task `unit: <consumer>` atau ter-cover task `unit: integration`). (Skema fan-IN: `reference.md` §D-4.)
- **Inbound-eksternal coverage:** tiap baris "kebutuhan receiver" di `plans/<Receiver app>.md` (vendor inbound) WAJIB jadi task `unit: <Receiver app>` varian inbound-eksternal (verifikasi signature + idempotent + replay, test keamanan baku). (Skema: `reference.md` §D-5.)
```

- [ ] **Step 3: Verify (kedua file + pointer §D-5 valid)**

Run: `grep -c 'inbound-eksternal\|kebutuhan receiver' plugin/skills/breakdown/reference.md plugin/skills/breakdown/SKILL.md`
Expected: kedua file `>= 1`.

Run: `grep -c '^5\. \*\*Task inbound-eksternal' plugin/skills/breakdown/reference.md`
Expected: `1` (item §D-5 ada → pointer "reference.md §D-5" valid).

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/breakdown/reference.md plugin/skills/breakdown/SKILL.md
git commit -m "feat(breakdown): varian task inbound-eksternal webhook (M5 §7.4)"
```

---

## Task 13: `build` — eksekusi task inbound-eksternal

Spec §7.5. Satu sisipan di step 3 (dispatch) — task inbound-eksternal = task app biasa di atas stub `wire`.

**Files:**
- Modify: `plugin/skills/build/SKILL.md` (langkah 3)

- [ ] **Step 1: Sisip catatan di step 3 (setelah blok package fan-IN)**

Find (verbatim):
```
**Bila `unit` = package** (`unit ∈ packages[]`): dispatch = typecheck + test exports package (BUKAN boot/smoke app); resolve `path` dari `packages[].path`. **Fan-IN cheap-skip:** untuk update-task consumer (`deps: [task-pkg]` dari perubahan package `BREAKING`), subagent CEK dulu "consumer ini beneran memakai export yang berubah?" — kalau **tidak** → tandai no-op, pastikan typecheck hijau, selesai cepat (tak ada perubahan kode). Enumerasi tetap semua consumer (aman); biaya per-consumer murah.
```
Replace with:
```
**Bila `unit` = package** (`unit ∈ packages[]`): dispatch = typecheck + test exports package (BUKAN boot/smoke app); resolve `path` dari `packages[].path`. **Fan-IN cheap-skip:** untuk update-task consumer (`deps: [task-pkg]` dari perubahan package `BREAKING`), subagent CEK dulu "consumer ini beneran memakai export yang berubah?" — kalau **tidak** → tandai no-op, pastikan typecheck hijau, selesai cepat (tak ada perubahan kode). Enumerasi tetap semua consumer (aman); biaya per-consumer murah.

**Task inbound-eksternal (webhook vendor):** = task app biasa pada `unit:<Receiver app>` di atas stub route yang sudah di-scaffold `wire` mode-integration. Subagent mengisi logika verifikasi signature (per `integrations.md`) + idempotent (dedup) + tahan replay, dan menulis test keamanan baku (signature salah → 401/403; id duplikat → idempotent). `actions: [env: ...]` untuk NAMA secret webhook (nilai GATE/manual). Tak ada infra khusus.
```

- [ ] **Step 2: Verify**

Run: `grep -c 'inbound-eksternal\|stub route\|Receiver app' plugin/skills/build/SKILL.md`
Expected: `>= 1`

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/build/SKILL.md
git commit -m "feat(build): eksekusi task inbound-eksternal di atas stub wire (M5 §7.5)"
```

---

## Task 14: `invariants.md` template — slot baru

Spec §8.1. Slot ketujuh, sentinel `<belum dikunci>` yang SUDAH ada (bukan token baru).

**Files:**
- Modify: `plugin/template/control/invariants.md`

- [ ] **Step 1: Tambah slot setelah Rate-limit**

Find (verbatim):
```
## Rate-limit / Abuse
<belum dikunci>
```
Replace with:
```
## Rate-limit / Abuse
<belum dikunci>

## Integrasi & Webhook Eksternal
<belum dikunci>
```

- [ ] **Step 2: Verify**

Run: `grep -c '## Integrasi & Webhook Eksternal' plugin/template/control/invariants.md && grep -c '<belum dikunci>' plugin/template/control/invariants.md`
Expected: first `1`, second `7` (6 slot lama + 1 baru — sentinel konsisten, tak ada token baru).

- [ ] **Step 3: Commit**

```bash
git add plugin/template/control/invariants.md
git commit -m "feat(template): slot invarian Integrasi & Webhook Eksternal (M5 §8.1)"
```

---

## Task 15: `architect` — frasa di contoh langkah 4.5

Spec §8.1. Cuma tambah frasa ke daftar contoh — TANPA renumber (4.5 tetap 4.5).

**Files:**
- Modify: `plugin/skills/architect/SKILL.md` (langkah 4.5)

- [ ] **Step 1: Tambah frasa ke daftar contoh invarian**

Find (verbatim):
```
Invarian = keputusan fondasi yang membentuk SETIAP table & query, mahal di-refactor (model tenancy, representasi uang, idempotency, authz, PII/PCI, rate-limit). Dikunci di DEPAN, bukan ditunda ke fitur pertama.
```
Replace with:
```
Invarian = keputusan fondasi yang membentuk SETIAP table & query, mahal di-refactor (model tenancy, representasi uang, idempotency, authz, PII/PCI, rate-limit, integrasi/webhook eksternal). Dikunci di DEPAN, bukan ditunda ke fitur pertama.
```

- [ ] **Step 2: Verify (frasa ada; step 4.5 tak ter-renumber)**

Run: `grep -c 'integrasi/webhook eksternal' plugin/skills/architect/SKILL.md && grep -c '### 4.5 Kunci Invarian' plugin/skills/architect/SKILL.md`
Expected: first `1`, second `1`.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/architect/SKILL.md
git commit -m "feat(architect): slot integrasi/webhook di contoh Kunci Invarian (M5 §8.1)"
```

---

## Task 16: `security-critic` — input `integrations.md` + lensa grounded

Spec §8.2. Tiga sisipan: description (input list), "Kamu menerima" line, step 1 + step 2 webhook bullet + test/live bullet. **Description WAJIB tetap colon-space-free.**

**Files:**
- Modify: `plugin/agents/security-critic.md`

- [ ] **Step 1: Description — tambah integrations.md ke input list**

Find (verbatim):
```
description: Red-team keamanan independen atas DIFF sebuah fitur. Diberi diff + invariants.md/conventions.md, tugasnya MENCARI kerentanan — secret ke-commit, PII di log, data kartu (PCI), webhook tanpa verifikasi signature, endpoint tanpa cek tenant/role, input tak divalidasi. Dipanggil ship di Security & Compliance Gate untuk fitur ber-sensitivity. Read-only.
```
Replace with:
```
description: Red-team keamanan independen atas DIFF sebuah fitur. Diberi diff + invariants.md/conventions.md/integrations.md, tugasnya MENCARI kerentanan — secret ke-commit, PII di log, data kartu (PCI), webhook tanpa verifikasi signature, endpoint tanpa cek tenant/role, input tak divalidasi. Dipanggil ship di Security & Compliance Gate untuk fitur ber-sensitivity. Read-only.
```

- [ ] **Step 2: "Kamu menerima" + step 1 — tambah integrations.md**

Find (verbatim):
```
Kamu menerima: diff fitur (path + range/SHA per repo) + `control/invariants.md` (baseline invarian Tenancy/Authz/PII-PCI) + `control/conventions.md`.

Lakukan:
1. Baca diff + `control/invariants.md` + `control/conventions.md`.
```
Replace with:
```
Kamu menerima: diff fitur (path + range/SHA per repo) + `control/invariants.md` (baseline invarian Tenancy/Authz/PII-PCI + Integrasi/Webhook) + `control/conventions.md` + `control/integrations.md` (kontrak SHAPE vendor — baseline webhook signature/mode/idempotency).

Lakukan:
1. Baca diff + `control/invariants.md` + `control/conventions.md` + `control/integrations.md`.
```

- [ ] **Step 3: Webhook bullet — ground ke baseline + tambah mode test/live**

Find (verbatim):
```
   - **Webhook/endpoint masuk tanpa verifikasi** — signature/origin/HMAC tak dicek.
```
Replace with:
```
   - **Webhook/endpoint masuk tanpa verifikasi** — signature/origin/HMAC tak dicek. Silang dengan `integrations.md`: vendor ber-`Signature` (mis. HMAC-SHA256) → diff WAJIB memverifikasinya (timing-safe); idempotency-key sesuai kontrak.
   - **Mode test/live salah** — vendor ber-`Mode: test` di staging tapi kode merutekan secret/endpoint mode live (atau sebaliknya); cek terhadap `integrations.md`.
```

- [ ] **Step 4: Verify (colon-space guard + grounding)**

Run: `sed -n 's/^description: //p' plugin/agents/security-critic.md | grep ': ' ; echo "exit=$?"`
Expected: no matching lines, `exit=1` (description tetap bebas `": "` — `invariants.md/conventions.md/integrations.md` pakai `/`).

Run: `grep -c 'integrations.md' plugin/agents/security-critic.md`
Expected: `>= 3`

- [ ] **Step 5: Commit**

```bash
git add plugin/agents/security-critic.md
git commit -m "feat(security-critic): baca integrations.md sebagai baseline webhook/mode (M5 §8.2)"
```

---

## Task 17: `ship` — feed baseline (4.5) + runbook integrasi (step 6)

Spec §8.3, §9.1. Dua sisipan — keduanya **memperluas** step yang ada, TANPA renumber (jaga cross-ref "lanjut Step 6").

**Files:**
- Modify: `plugin/skills/ship/SKILL.md`

- [ ] **Step 1: Step 4.5 — feed integrations.md ke security-critic**

Find (verbatim):
```
- **`sensitivity` memuat `payments`/`pii` →** invoke subagent **`security-critic`** atas diff penuh (lintas repo yang kena, path/SHA dari code-review step 2) + `control/invariants.md`. Temuan **severity high** = **RED**.
```
Replace with:
```
- **`sensitivity` memuat `payments`/`pii` →** invoke subagent **`security-critic`** atas diff penuh (lintas repo yang kena, path/SHA dari code-review step 2) + `control/invariants.md` + `control/integrations.md` (baseline webhook signature/mode/idempotency per vendor). Temuan **severity high** = **RED**.
```

- [ ] **Step 2: Step 6 — seksi runbook integrasi di deskripsi PR**

Find (verbatim):
```
- Susun deskripsi PR dari `business.md` + `fanout.md` + `plans` + ringkasan diff (terhubung ke ALASAN bisnis, bukan cuma "what").
```
Replace with:
```
- Susun deskripsi PR dari `business.md` + `fanout.md` + `plans` + ringkasan diff (terhubung ke ALASAN bisnis, bukan cuma "what").
- **Runbook integrasi (bila fitur kena vendor di `integrations.md`):** agregasi per vendor ke deskripsi PR — URL webhook yang perlu didaftarkan di console vendor (dari `Endpoint`/path receiver), env secret yang perlu di-set (NAMA var dari `Secret env`), switch mode test→live. Menutup gap "hasil langkah manual tak mendarat"; melengkapi challenge step 4. (Scoped ke integrasi — full release-runbook = Langkah 3.)
```

- [ ] **Step 3: Verify (feed + runbook; step 5/6 tak ter-renumber)**

Run: `grep -c 'integrations.md\|Runbook integrasi' plugin/skills/ship/SKILL.md`
Expected: `>= 2`

Run: `grep -c 'lanjut Step 6' plugin/skills/ship/SKILL.md`
Expected: `1` (cross-ref step 5→6 tetap valid — tak ada renumber).

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/ship/SKILL.md
git commit -m "feat(ship): feed integrations.md ke security-critic + runbook integrasi (M5 §8.3, §9.1)"
```

---

## Task 18: Amandemen spec induk + README

Spec §11.1. Edit `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§7 tree, §9 fanout/plan/ship/drop/render-docs, §12 Cabang, §17) + `README.md`. **`feature` TIDAK diamandemen di §9** (cabang di §12). **Spec Langkah-1 TIDAK diedit** (sudah forward-ref M5 di §12). Banyak sub-step → satu commit.

**Files:**
- Modify: `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`
- Modify: `README.md`

- [ ] **Step 1: §7 control tree — tambah integrations.md**

Find (verbatim):
```
├── invariants.md         # invarian platform (tenancy/money/idempotency/authz/PII-PCI/rate-limit; dikunci architect)
```
Replace with:
```
├── invariants.md         # invarian platform (tenancy/money/idempotency/authz/PII-PCI/rate-limit; dikunci architect)
├── integrations.md       # kontrak SHAPE vendor eksternal (M5; diisi add-integration)
```

- [ ] **Step 2: §9 `fanout` — Perilaku + Output**

Find (verbatim):
```
- **Perilaku:** cocokkan kebutuhan fitur ke `capabilities`/`responsibility` tiap app → tentukan app yang kena & perannya; **adaptif**: bila hanya 1 app → konfirmasi cepat; bila banyak → breakdown penuh. Boleh menerima hint `--app`, tetapi **tetap memverifikasi** (bisa mengoreksi bila ternyata menyentuh app lain). Challenge: "ada app kelewat? dependency lintas-app?".
- **Output:** `features/<nama>/fanout.md` + update `capabilities` di `workspace.yaml`.
```
Replace with:
```
- **Perilaku:** cocokkan kebutuhan fitur ke `capabilities`/`responsibility` tiap app → tentukan app yang kena & perannya; **adaptif**: bila hanya 1 app → konfirmasi cepat; bila banyak → breakdown penuh. Boleh menerima hint `--app`, tetapi **tetap memverifikasi** (bisa mengoreksi bila ternyata menyentuh app lain). Challenge: "ada app kelewat? dependency lintas-app? butuh vendor eksternal?". Baca `integrations.md` → tandai `VENDOR NEW`/`VENDOR TOUCHED`/`VENDOR TOUCHED — perlu UPDATE` (diwujudkan `add-integration`).
- **Output:** `features/<nama>/fanout.md` (+ penanda `VENDOR …`) + update `capabilities` di `workspace.yaml`.
```

- [ ] **Step 3: §9 `plan` — Input + Output**

Find (verbatim):
```
- **Input:** `business.md` + `fanout.md` + **kode app** yang kena + `conventions.md`.
- **Perilaku:** selesaikan **kontrak lintas-app** dulu (mis. mekanisme token) → untuk tiap app: baca kode/konvensi, Q&A **teknis**, susun plan (file, endpoint, model data, test); challenge teknis. (Karena `architect` sudah jalan, `plan` selalu membaca stack yang ada — tidak menetapkan stack.)
```
Replace with:
```
- **Input:** `business.md` + `fanout.md` + **kode app** yang kena + `conventions.md` + `integrations.md` (kontrak vendor, read-only).
- **Perilaku:** selesaikan **kontrak lintas-app** dulu (mis. mekanisme token) + **promote kontrak vendor** dari `integrations.md` ke `_shared.md` (O(1), idempotent) → untuk tiap app: baca kode/konvensi, Q&A **teknis**, susun plan (file, endpoint, model data, test; baris kebutuhan receiver untuk webhook vendor inbound); challenge teknis. (Karena `architect` sudah jalan, `plan` selalu membaca stack yang ada — tidak menetapkan stack.)
```

- [ ] **Step 4: §9 `ship` — step 2.5 security gate input**

Find (verbatim):
```
  2.5. **Security & Compliance gate** — berskala ke `sensitivity` fitur; `payments`/`pii` → subagent `security-critic` red-team diff (secret/PII/PCI/authz/webhook); temuan high → STOP.
```
Replace with:
```
  2.5. **Security & Compliance gate** — berskala ke `sensitivity` fitur; `payments`/`pii` → subagent `security-critic` red-team diff (secret/PII/PCI/authz/webhook) terhadap `invariants.md` + `integrations.md` (baseline webhook); temuan high → STOP. PR menyertakan runbook integrasi (webhook-URL + secret-NAMA + test→live).
```

- [ ] **Step 5: §9 `drop` — provenance vendor**

Find (verbatim):
```
- **Perilaku:** tanya alasan → set status `dropped` + reason + tanggal; review promosi knowledge fitur ini ("keep atau revert?" — `critic` membantu flag); folder **dikeep** sebagai memori keputusan; branch git diingatkan (urusan git user).
```
Replace with:
```
- **Perilaku:** tanya alasan → set status `dropped` + reason + tanggal; review promosi knowledge fitur ini ("keep atau revert?" — `critic` membantu flag; bila fitur memperkenalkan vendor → pengingat tinjau entri `integrations.md`); folder **dikeep** sebagai memori keputusan; branch git diingatkan (urusan git user).
```

- [ ] **Step 6: §9 `render-docs` — Input**

Find (verbatim):
```
- **Input:** `workspace.yaml` + `business/` + `features/`.
```
Replace with:
```
- **Input:** `workspace.yaml` + `business/` + `integrations.md` + `features/`.
```

- [ ] **Step 7: §12 — Cabang dipicu add-integration (sisip setelah cabang add-package)**

Find (verbatim):
```
**Cabang dipicu — fitur butuh shared package baru:** bila `fanout` menandai kode-bareng >1 app sebagai `PACKAGE NEW`, `feature` otomatis invoke **`add-package`** (declare entri ke `packages[]` → `architect` → `wire` mode-package, gate typecheck) sebelum `plan`. Saat API shared package berubah, `breakdown` menerbitkan update-task per consumer (fan-IN). Task hidup di `unit` (app ATAU package). Lihat spec `2026-06-01-h2-shared-package-design.md`.
```
Replace with:
```
**Cabang dipicu — fitur butuh shared package baru:** bila `fanout` menandai kode-bareng >1 app sebagai `PACKAGE NEW`, `feature` otomatis invoke **`add-package`** (declare entri ke `packages[]` → `architect` → `wire` mode-package, gate typecheck) sebelum `plan`. Saat API shared package berubah, `breakdown` menerbitkan update-task per consumer (fan-IN). Task hidup di `unit` (app ATAU package). Lihat spec `2026-06-01-h2-shared-package-design.md`.

**Cabang dipicu — fitur butuh vendor eksternal:** bila `fanout` menandai kebutuhan layanan pihak-ketiga sebagai `VENDOR NEW` (atau `VENDOR TOUCHED — perlu UPDATE`), `feature` otomatis invoke **`add-integration`** (declare kontrak SHAPE ke `control/integrations.md` → `wire` mode-integration buat stub webhook-receiver bila inbound) sebelum `plan`. `add-integration` TAK chain `architect` (vendor tak punya stack). Webhook inbound jadi task `unit:<app>` varian inbound-eksternal (verifikasi signature/idempotent/replay). Lihat spec `2026-06-01-m5-integrations-design.md`.
```

- [ ] **Step 8: §17 — skill count 16→17 + add-integration**

Find (verbatim):
```
- **Skills (16):** `discovery` · `init` · `architect` · `wire` · `add-app` · `add-package` · `extract` · `feature` (→ `intake` · `fanout` · `plan`) · `breakdown` · `build` · `ship` · `drop` · `render-docs`
```
Replace with:
```
- **Skills (17):** `discovery` · `init` · `architect` · `wire` · `add-app` · `add-package` · `add-integration` · `extract` · `feature` (→ `intake` · `fanout` · `plan`) · `breakdown` · `build` · `ship` · `drop` · `render-docs`
```

- [ ] **Step 9: §17 — Knowledge tambah integrations.md**

Find (verbatim):
```
- **Knowledge (`control/`):** `workspace.yaml` (apps[] + packages[]) · `business/` · `conventions.md` · `invariants.md` · `features/` · `docs/`
```
Replace with:
```
- **Knowledge (`control/`):** `workspace.yaml` (apps[] + packages[]) · `business/` · `conventions.md` · `invariants.md` · `integrations.md` · `features/` · `docs/`
```

- [ ] **Step 10: README — cabang add-integration + Langkah 2 note**

Find (verbatim):
```
> Kalau sebuah fitur butuh **app baru** (belum ada di `workspace.yaml`), `fanout` nandain dan `feature` otomatis panggil `add-app` (declare entri → `architect` → `wire`) sebelum `plan`. `add-app <nama>` juga bisa dipanggil standalone buat numbuhin produk pasca-`init`.
```
Replace with:
```
> Kalau sebuah fitur butuh **app baru** (belum ada di `workspace.yaml`), `fanout` nandain dan `feature` otomatis panggil `add-app` (declare entri → `architect` → `wire`) sebelum `plan`. `add-app <nama>` juga bisa dipanggil standalone buat numbuhin produk pasca-`init`. Hal serupa untuk **shared package baru** (`add-package`, mode-package) dan **vendor eksternal** (`add-integration` — tulis kontrak SHAPE ke `control/integrations.md`, scaffold stub webhook bila inbound).
```

- [ ] **Step 11: README — Langkah 2 note (Selesai & lifecycle)**

Find (verbatim):
```
**Hardening (Langkah 1 — audit ecommerce-builder):** invarian platform dikunci `architect` sebelum `wire` (di `control/invariants.md`) + **Security & Compliance Gate** di `ship` (berskala `sensitivity`, agent `security-critic`).
```
Replace with:
```
**Hardening (Langkah 1 — audit ecommerce-builder):** invarian platform dikunci `architect` sebelum `wire` (di `control/invariants.md`) + **Security & Compliance Gate** di `ship` (berskala `sensitivity`, agent `security-critic`). **Langkah 2:** shared package end-to-end + fan-IN (`add-package`, `packages[]` — H2) + vendor eksternal durable (`add-integration`, `control/integrations.md`, webhook inbound + baseline `security-critic` — M5).
```

- [ ] **Step 12: Verify (semua amandemen + tak ada double-edit)**

Run: `grep -c 'integrations.md' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`
Expected: `>= 5` (§7 tree, §9 plan, §9 ship, §9 render-docs, §17 Knowledge, §12).

Run: `grep -c 'Skills (17)\|add-integration' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`
Expected: `>= 2`

Run: `grep -c 'add-integration\|control/integrations.md' README.md`
Expected: `>= 2`

- [ ] **Step 13: Commit**

```bash
git add docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md README.md
git commit -m "docs: amend induk §7/§9/§12/§17 + README untuk M5 (integrations)"
```

---

## Verifikasi akhir (setelah semua task — spec §13)

Jalankan SETELAH semua task `done`, sebelum hand-off ke verifikasi sesi-terpisah:

- [ ] **V1 — Colon-space guard (semua frontmatter baru/diedit):**

```bash
for f in plugin/skills/add-integration/SKILL.md plugin/agents/security-critic.md; do
  echo "== $f =="; sed -n 's/^description: //p' "$f" | grep ': ' && echo "FAIL colon-space" || echo "OK"
done
```
Expected: dua-duanya `OK`.

- [ ] **V2 — Grep-battery konsistensi (lintas file §10):**

```bash
grep -rl 'integrations.md\|add-integration\|VENDOR NEW\|mode-integration\|Receiver app' plugin/ | sort
```
Expected: memuat `init`, `add-integration`, `fanout`, `feature`, `plan`, `wire` (SKILL+reference), `breakdown` (SKILL+reference), `build`, `security-critic`, `ship`, `render-docs`, `drop`, template `integrations.md`/`invariants.md`/`conventions.md`.

- [ ] **V3 — Coherence guard (NO fiction M4/H3):**

```bash
grep -rn 'control/schema\|migration-governance\|data-model.md' plugin/ ; echo "exit=$?"
```
Expected: `exit=1` (tak ada — M5 tak menyandar M4/H3).

- [ ] **V4 — packages[].consumers TIDAK di-overload:**

```bash
grep -rn 'consumers' plugin/skills/ | grep -i vendor
```
Expected: kosong (consumers tetap soal app↔package, bukan vendor).

- [ ] **V5 — Sentinel tak baru:** Task 1 step 2 + Task 14 step 2 sudah cek `<belum dikunci>` hanya di `invariants.md` (7×), `integrations.md` 0×.

- [ ] **V6 — Renumber-cross-ref:** `plan` heading urut (`1/2/2b/2c/3/4`), `ship` "lanjut Step 6" valid, `architect` "### 4.5" utuh (dicek di Task 6/15/17).

- [ ] **V7 — Mis-aimed pointer:** `§J`/`§D`/`§I` di skill = `wire/reference.md` (Task 10 bikin §J); `reference.md §D-5` (Task 12 bikin item 5); `§N` di spec M5 = spec M5.

---

## Self-Review (writing-plans)

**Spec coverage (§-by-§):**
- §4 integrations.md (SHAPE + init seed) → T1, T2 ✓
- §5 add-integration → T3 ✓
- §6 wire mode-integration → T10, T11 ✓
- §7.1 fanout → T4 ✓ · §7.2 feature → T5 ✓ · §7.3 plan promote → T6 ✓ · §7.4 breakdown → T12 ✓ · §7.5 build → T13 ✓
- §8.1 invariant slot + architect → T14, T15 ✓ · §8.2 security-critic → T16 ✓ · §8.3 ship feed → T17 ✓
- §9.1 ship runbook → T17 ✓ · §9.2 render-docs → T7 ✓ · §9.3 drop → T8 ✓ · §9.4 conventions → T9 ✓
- §11 amandemen → T18 ✓ (Langkah-1 spec sengaja TIDAK diedit — sudah forward-ref M5)

**Placeholder scan:** tiap task punya find/replace verbatim + perintah verify konkret. Tak ada "TBD"/"sesuaikan".

**Type/nama konsisten:** `VENDOR NEW`/`VENDOR TOUCHED`/`VENDOR TOUCHED — perlu UPDATE`, `Receiver app`, `mode-integration`, `§J`, `inbound-eksternal`, `## Integrasi & Webhook Eksternal` dipakai identik lintas task.
