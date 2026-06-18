# Skill `/tweak` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bangun skill baru `/tweak` di plugin context-vault — jalur ringan buat perubahan kecil-tapi-berdampak (kode + keputusan) yang tetep capture ke `control/` tanpa pipeline berat `feature→build`, dengan tripwire yang auto naik-kelas ke `/feature`/`/fix`.

**Architecture:** Skill ditulis sebagai **konduktor ramping** `plugin/skills/tweak/SKILL.md` (alur 6-langkah + ringkasan tripwire) yang nunjuk ke `plugin/skills/tweak/reference.md` (mekanik detail: daftar verba, prosedur angka-vs-plumbing, format capture, mekanik PR, skenario eval) — persis pola `build`/`fix`. Sumber kebenaran konten = spec `docs/superpowers/specs/2026-06-17-tweak-lightweight-change-lane-design.md` (rev.3, committed `098daf4`). Registrasi via auto-discovery `plugin/skills/*/SKILL.md` + update README + bump versi di dua manifest.

**Tech Stack:** Markdown skill files (Claude Code plugin format, frontmatter `name`+`description`). Bahasa **Indonesia kasual** (samain gaya skill lain). **Tidak ada toolchain build/test** — verifikasi tiap task = (a) **skenario eval** (prompt → routing/perilaku yang diharapkan, dijalankan via dry-run/reasoning terhadap teks skill), (b) **cek struktural** (grep heading/anchor/silang-referensi). Ini adaptasi jujur: skill = instruksi prosa buat LLM, bukan kode eksekusi — "TDD" di sini = tulis skenario eval (perilaku yang diharapkan) DULU, baru tulis instruksi yang memenuhinya, lalu cek instruksinya beneran memprediksi perilaku itu.

## Global Constraints

Tiap task implisit tunduk ke ini (nilai disalin verbatim dari spec):
- **Ownership `control/`:** `tweak` nulis langsung **HANYA** ke `business/domain.md · flows.md · glossary.md`. `conventions.md` / `integrations.md` / `invariants.md` → **route/eskalasi**, NGGAK ditulis langsung (single-owner: architect/add-integration/architect).
- **Precedence tripwire:** urutan **B → C → A**. Cabang **B (keamanan) & C (defect) SELALU jalan & TIDAK bisa di-override**. Override-sadar HANYA cabang A sub-trigger "revamp/kapabilitas" — BUKAN ">1 unit/app", "ubah kontrak shared", "sentuh stack/conventions/integrations".
- **Cek tripwire mekanis (daftar verba), bukan judgment.** `invariants.md` WAJIB dibaca buat evaluasi cabang-B (kecuali murni-kosmetik).
- **TDD otomatis** (skill nulis test, bukan user); TDD = korektifitas, BUKAN keamanan.
- **Finish sampai PR**, dijustifikasi via **manifest-lifecycle** (tweak atomik, nggak punya status buat ditutup → nggak butuh ship). **NON-resumable**, single-session.
- **Nol surface `control/` baru.** Capture idempotent bandingin **FAKTA saja** (abaikan blok alasan).
- **Pola file:** SKILL.md ramping + reference.md detail (pinjam frasa `${CLAUDE_PLUGIN_ROOT}/skills/tweak/reference.md`).
- **Anti-rekursi:** `tweak` boleh **invoke** `/feature` (eskalasi cabang A) & route ke `/fix` (cabang C); TIDAK manggil `/ship`/`/build`/`/debt`.

---

## File Structure

- **Create** `plugin/skills/tweak/SKILL.md` — konduktor: frontmatter + alur 6-langkah + ringkasan tripwire 3-cabang + precedence. Ramping; detail → reference.md.
- **Create** `plugin/skills/tweak/reference.md` — mekanik: §A daftar verba (keamanan + uang) · §B garis angka-kebijakan-vs-plumbing + precedence file-sensitivity · §C triage defect (cabang C) · §D format capture (marker inline + idempotensi fakta + rule-change-vs-konstanta + no-home) · §E mekanik PR (branch/base/multi-repo) + floor-scan · §F skenario eval.
- **Modify** `README.md` — tambah `/tweak` ke daftar skill + tabel "kapan pake yang mana" (tweak/fix/feature).
- **Modify** `plugin/skills/fix/SKILL.md` (Catatan) — sebut boundary `tweak` (perubahan kecil bukan-defect → `/tweak`).
- **Modify** `plugin/skills/intake/SKILL.md` (Catatan/awal) — akui `tweak` bisa eskalasi masuk ke `feature`→`intake` (seed konteks).
- **Modify** `plugin/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — bump `0.4.2 → 0.5.0` + sebut `tweak` di description.

Decomposition: Task 1 (skeleton+description) → 2 (SKILL.md tripwire) → 3 (reference tripwire detail) → 4 (capture) → 5 (gate+finish) → 6 (cross-ref+registrasi). Tiap task = deliverable yang bisa di-review & di-reject independen.

---

### Task 1: `tweak/SKILL.md` — frontmatter, skeleton, triggering description

**Files:**
- Create: `plugin/skills/tweak/SKILL.md`

**Interfaces:**
- Produces: file SKILL.md dengan frontmatter `name: tweak` + `description` (dipakai router skill) + kerangka heading `## Langkah` step 1-6 (diisi Task 2,4,5).

- [ ] **Step 1: Tulis skenario eval triggering (perilaku yang diharapkan) dulu**

Catat di scratchpad (jadi acceptance Task 1; nanti dipindah ke reference.md §F di Task 3/6):
```
TRIGGER + : "naikin diskon maks ke 30%"           → /tweak
TRIGGER + : "ganti default page size jadi 50"     → /tweak
TRIGGER + : "tweak rate limit window"             → /tweak (lalu cabang-B eskalasi — fase routing tetap /tweak)
TRIGGER − : "checkout-nya salah, harusnya pajak dihitung sebelum diskon" → /fix (BUKAN tweak)
TRIGGER − : "tambah login SSO"                     → /feature (BUKAN tweak)
```

- [ ] **Step 2: Tulis frontmatter + heading + kerangka**

Tulis ke `plugin/skills/tweak/SKILL.md`:
```markdown
---
name: tweak
description: Use untuk perubahan KECIL berjejak — keputusan/kebijakan kecil (kode + alasan) yang tetep ke-capture ke control/ TANPA pipeline berat feature→build. BUKAN koreksi perilaku salah (→ /fix) & BUKAN kapabilitas baru/lintas-app/fondasional (→ /feature); tripwire auto naik-kelas kalau ternyata gede/bahaya/bug. Alur — triage+tripwire 3-cabang → TDD otomatis → capture ke business/* → gate (floor-scan + Challenge Checklist) → commit+PR. Trigger — "tweak <x>", "naikin/ganti/ubah <x> jadi", "ganti konstanta/threshold/policy <x>". Jalankan dari root produk yang punya control/.
---

# tweak — Jalur ringan berjejak (konduktor)

Tujuan: perubahan KECIL yang tetep ninggalin jejak keputusan di `control/`, TANPA `feature→fanout→plan→breakdown→build`. Cepet karena buang **birokrasi**, BUKAN nurunin bar (TDD + anti-yes-man + floor keamanan tetep jalan). Aman jadi **pintu default**: tripwire auto naik-kelas ke `/feature` (gede/bahaya) atau `/fix` (bug).

> Mekanik detail (daftar verba tripwire, garis angka-vs-plumbing, format capture, mekanik PR, skenario eval) → `${CLAUDE_PLUGIN_ROOT}/skills/tweak/reference.md` — baca itu dulu.

## Langkah

### 1. Baca state minimal + cek branch
<!-- diisi Task 2 -->

### 2. Triage + Tripwire (3 cabang, precedence B→C→A)
<!-- diisi Task 2 -->

### 3. Bikin perubahan — TDD otomatis, inline
<!-- diisi Task 4 -->

### 4. Capture keputusan (kalau ada)
<!-- diisi Task 4 -->

### 5. Gate (floor-scan + anti-yes-man)
<!-- diisi Task 5 -->

### 6. Finish — commit + PR
<!-- diisi Task 5 -->

## Catatan
<!-- diisi Task 5/6 -->
```

- [ ] **Step 3: Verifikasi (dry-run routing terhadap description)**

Untuk tiap baris eval Step 1, baca `description` + bandingin sama description `fix`/`feature` (`plugin/skills/fix/SKILL.md`, `plugin/skills/feature/SKILL.md`). Pastiin frasa pembeda eksplisit ada: "BUKAN koreksi perilaku salah (→ /fix)" nangkep TRIGGER−#1; "BUKAN kapabilitas baru/lintas-app/fondasional (→ /feature)" nangkep TRIGGER−#2; "naikin/ganti/ubah" nangkep TRIGGER+. Catat alasan tiap eval lulus.
Run cek struktural: `grep -nE '^### [1-6]\.' plugin/skills/tweak/SKILL.md` → Expected: 6 heading langkah ada.

- [ ] **Step 4: Commit**
```bash
git add plugin/skills/tweak/SKILL.md
git commit -m "feat(tweak): skeleton SKILL.md + frontmatter triggering (skill ke-23)"
```

---

### Task 2: SKILL.md step 1-2 — baca state + tripwire 3-cabang (ringkasan)

**Files:**
- Modify: `plugin/skills/tweak/SKILL.md` (isi `### 1.` + `### 2.`)

**Interfaces:**
- Consumes: kerangka heading dari Task 1.
- Produces: instruksi step 1 (baca state) + step 2 (tripwire ringkas + precedence + pointer ke reference.md §A-C). Detail daftar verba ada di Task 3 (reference.md).

- [ ] **Step 1: Tulis skenario eval tripwire (perilaku diharapkan)**

```
T-A1: edit nyentuh 2 app (lintas-unit)            → cabang A, HARD-escalate /feature (override TIDAK boleh)
T-A2: "revamp dashboard jadi modular"             → cabang A, OFFER /feature (override sadar boleh)
T-B1: "requireAuth: true → false"                 → cabang B HARD-STOP (1 baris pun)
T-B2: "naikin rate limit 10→100"                  → cabang B HARD-STOP (rate-limit = keamanan)
T-B3: produk belum-architect, invariants <belum dikunci>, edit area tenancy → cabang B eskalasi (degrade pesimis)
T-C1: "checkout salah hitung pajak"               → cabang C → /fix
T-OK: "naikin diskon maks 30%"                    → lolos B,C,A → lanjut jalur ringan
T-PREC: edit nyentuh integrations.md + ubah TTL token → B menang (HARD-STOP), bukan A-offer
```

- [ ] **Step 2: Tulis `### 1. Baca state minimal + cek branch`**

```markdown
### 1. Baca state minimal + cek branch
Baca `control/workspace.yaml` (apps + stack + path) + cek branch sekarang (multi-repo aware; **jangan commit di `main`/`master` tanpa izin** — branch `tweak/<slug>`). `control/business/*`+`glossary` dibaca **lazy** (pas capture perlu, step 4). **`control/invariants.md` WAJIB dibaca** buat evaluasi tripwire cabang-B (step 2) — KECUALI perubahan jelas murni-kosmetik (copy/format/rename). Prasyarat: ada `control/`; kalau nggak → BERHENTI, suruh `init`.
```

- [ ] **Step 3: Tulis `### 2. Triage + Tripwire (3 cabang, precedence B→C→A)`**

```markdown
### 2. Triage + Tripwire (3 cabang, precedence B→C→A)
SEBELUM nyentuh kode. **Cek mekanis pakai daftar verba di `reference.md` §A-C, bukan feeling.**

**Precedence (algoritmik):** evaluasi **B → C → A**.
- **B (keamanan) & C (defect) SELALU jalan & TIDAK bisa di-override** user.
- **Override-sadar HANYA cabang A** sub-trigger judgment "revamp gede/kapabilitas baru" — **BUKAN** ">1 unit/app", "ubah kontrak shared", "sentuh stack/conventions/integrations" (itu hard-escalate, bikin multi-repo / nyentuh single-owner).
- Lolos B+C+A → lanjut jalur ringan (step 3).

**Cabang B — keamanan → HARD-STOP** (nggak bisa di-talk-out). Kena verba-keamanan / verba-uang(plumbing) / PII-expansion / invariants (`reference.md` §A) → STOP; satu-satunya maju = **invoke `/feature`** (ujungnya `ship` Security Gate), seed konteks. Degrade pesimis: slot `invariants.md` relevan masih `<belum dikunci>` → eskalasi. Fail-safe: ragu fungsi-keamanan → treat keamanan.

**Cabang C — defect → `/fix`.** Triage by framing (`reference.md` §C): "salah/harusnya/bug" → route `/fix` bawa konteks; ambigu → tanya satu pertanyaan.

**Cabang A — ukuran/fondasional → `/feature`.** Definisi sejalan `build` step 6 (`>1 app`, digeneralisasi ke unit nyata) — `reference.md` §B. Kena → **invoke `/feature`** seed konteks (override sadar lihat precedence).

**Garis angka-kebijakan vs plumbing** (biar perubahan angka kebijakan kayak diskon-cap nggak ketabrak cabang-B): `reference.md` §B.
```

- [ ] **Step 4: Verifikasi**

Dry-run tiap eval Step 1 terhadap teks step 2 + (sementara) logika §A-C yang bakal ditulis Task 3. Khusus T-PREC: pastiin teks "B → C → A" + "B...TIDAK bisa di-override" beneran maksa B menang. Catat hasil tiap eval.
Run: `grep -nE 'B → C → A|HARD-STOP|override' plugin/skills/tweak/SKILL.md` → Expected: precedence + hard-stop tertulis.

- [ ] **Step 5: Commit**
```bash
git add plugin/skills/tweak/SKILL.md
git commit -m "feat(tweak): step 1-2 — baca state + tripwire 3-cabang + precedence"
```

---

### Task 3: `tweak/reference.md` — §A daftar verba, §B angka-vs-plumbing, §C triage defect

**Files:**
- Create: `plugin/skills/tweak/reference.md`

**Interfaces:**
- Consumes: pointer dari SKILL.md step 2.
- Produces: anchor `§A` (verba), `§B` (angka-vs-plumbing + definisi fondasional cabang A), `§C` (triage defect). Dipakai SKILL.md step 2 + Task 4/5.

- [ ] **Step 1: Tulis §A — daftar verba mekanis (keamanan + uang + PII + invariants)**

```markdown
# tweak — Reference (mekanik tripwire + capture + finish)

## A. Cabang B — daftar verba mekanis (kena salah satu = HARD-STOP, eskalasi /feature)
**Verba-keamanan:** authentication/authorization · session/token/TTL · CORS/origin · role/permission check · **rate-limit/throttle/quota** (semua yang fungsinya abuse/DoS-prevention) · validasi input · **serialization/deserialization & query-building** (surface injection) · **tenant/tenancy isolation filter** · **mode test/live vendor** · secret/credential.
**Verba-uang (PLUMBING):** charge/capture · refund · payout/settlement/transfer · simpan PAN/instrumen-bayar/token-kartu. (Heuristik sensitivity `intake` + `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md` = PENGUAT, bukan classifier utama — daftar verba ini yang operasional.)
**PII:** kumpulin/simpan/tampilin data pribadi, ATAU **MEMPERLUAS surface PII yang udah ada** (un-masking, nurunin redaction, nambah audience, propagate ke log/analytics/response/pihak-ketiga).
**Invariants:** keputusan yang **rumahnya `invariants.md`** (tenancy/money/idempotency/authz/pii-pci/rate-limit/integrasi) → eskalasi (tweak nggak boleh nulis `invariants.md`). **Degrade pesimis:** slot relevan masih `<belum dikunci>` → fondasi-belum-dikunci → eskalasi.
**Fail-safe:** ragu apakah suatu perubahan/limit punya fungsi keamanan → treat sebagai keamanan.
```

- [ ] **Step 2: Tulis §B — angka-kebijakan vs plumbing + definisi fondasional (cabang A)**

```markdown
## B. Cabang A (fondasional) + garis angka-kebijakan vs plumbing

**Cabang A — fondasional (ukuran):** sejalan `build` step 6 (`>1 app`), **digeneralisasi ke unit nyata** (app ATAU package, konsisten grouping `ship`). Kena bila: sentuh **stack** / `conventions.md` / **shared package** / `integrations.md`, ATAU **lintas >1 unit nyata**, ATAU **ubah kontrak shared**, ATAU **kapabilitas baru / revamp gede**. (Bukan "verbatim" build — digeneralisasi.) Override-sadar cuma sub-trigger "revamp/kapabilitas".

**Garis ANGKA-KEBIJAKAN vs PLUMBING (decidable):**
- **LOLOS cabang-B** = ngubah **angka kebijakan bisnis** dari daftar-putih: **diskon maks · threshold gratis-ongkir · page-size** + angka sejenis yang **murni kebijakan, bukan fungsi keamanan**. → di-capture ke `domain.md`; risiko bisnis dijaga **Challenge Checklist** (step 5).
- **`rate-limit`/`throttle`/`quota` BUKAN angka-kebijakan** — itu §A (keamanan).
- **Precedence file-sensitivity:** "diff nyentuh file/modul ber-sensitivity" memicu STOP **HANYA bila diff nyentuh PLUMBING** (verba-uang/kolom-data §A), **BUKAN** bila cuma ngubah angka kebijakan. → diskon-cap di file pricing payments-sensitive **tetep lolos**.
```

- [ ] **Step 3: Tulis §C — triage defect (cabang C)**

```markdown
## C. Cabang C — triage defect → /fix
Triage **by framing user**:
- "salah / harusnya / bug / nggak jalan" → **`/fix`** (route bawa konteks; fix punya disiplin reproduce→root-cause).
- "naikin / ganti / ubah jadi / set" → **`tweak`** (ngubah keputusan; perilaku lama nggak salah).
- **Ambigu → tanya SATU pertanyaan:** "ini perilaku lama yang *salah* (bug), atau keputusan baru?" Jangan tebak diam-diam.
```

- [ ] **Step 4: Verifikasi**

Re-run semua eval T-A/T-B/T-C/T-OK/T-PREC dari Task 2 Step 1 terhadap §A-C yang udah konkret. Pastiin: T-B2 (rate-limit) kena §A bukan daftar-putih §B; T-OK (diskon) lolos §B walau di file payments (precedence file-sensitivity); T-C1 kena §C framing "salah".
Run: `grep -nE 'rate-limit|angka kebijakan|daftar-putih|by framing' plugin/skills/tweak/reference.md` → Expected: ketiga aturan ada.

- [ ] **Step 5: Commit**
```bash
git add plugin/skills/tweak/reference.md
git commit -m "feat(tweak): reference §A-C — daftar verba + angka-vs-plumbing + triage defect"
```

---

### Task 4: SKILL.md step 3-4 + reference.md §D — TDD otomatis & capture

**Files:**
- Modify: `plugin/skills/tweak/SKILL.md` (isi `### 3.` + `### 4.`)
- Modify: `plugin/skills/tweak/reference.md` (tambah §D)

**Interfaces:**
- Consumes: §A-C (Task 3), ownership constraint (Global).
- Produces: instruksi TDD + capture; §D format capture (marker + idempotensi + rule-vs-konstanta + no-home).

- [ ] **Step 1: Tulis skenario eval capture**

```
C-RULE : bikin aturan BARU "ada tier loyalty" → rule-change → critic independen DULU, lalu tulis domain.md
C-CONST: "diskon 20→30" (aturan diskon udah ada) → konstanta → cukup Challenge Checklist (tanpa critic)
C-IDEMP: jalanin C-CONST 2× → domain.md TIDAK duplikat (banding fakta, abai blok alasan)
C-OWN  : keputusan rumahnya conventions.md → route, JANGAN tulis langsung
C-HOME : keputusan tanpa owner jelas → default domain.md + tampil di gate ("pindahin?")
C-COSME: rename variabel, nol keputusan → skip capture
```

- [ ] **Step 2: Tulis `### 3.` (TDD otomatis) + `### 4.` (capture) di SKILL.md**

```markdown
### 3. Bikin perubahan — TDD otomatis, inline
Skill yang **nulis test sendiri** dari perilaku yang diubah (merah → implement → ijo), ikut `conventions.md` + pola yang ada. Edit **inline** (TANPA orkestrasi subagent per-task — itu sumber berat `build`). **Pengecualian sempit:** murni nggak-berperilaku (copy/teks/format/rename) → nggak ada yang dites (≠ "boleh logika tanpa test"). **TDD = jaminan KOREKTIFITAS, BUKAN keamanan** (keamanan = cabang-B + floor-scan step 5).

### 4. Capture keputusan (kalau ada)
Kalau perubahan bawa fakta durable → APPEND ke file knowledge **pemilik** sesuai `reference.md` §D. Ringkas: tulis langsung **HANYA** ke `business/domain.md · flows.md · glossary.md` (idempotent, + alasan inline); `conventions.md`/`integrations.md`/`invariants.md` → **route/eskalasi, JANGAN tulis**. **Rule-change** (bikin/restruktur aturan) → **critic independen** nilai dulu; **konstanta** (ganti angka aturan existing) → cukup Challenge Checklist. Murni kosmetik → skip.
```

- [ ] **Step 3: Tulis §D di reference.md**

```markdown
## D. Capture — ownership, format, idempotensi
- **Tulis langsung HANYA ke `business/domain.md · flows.md · glossary.md`** (ketiganya multi-writer: `intake` step 7 + `extract` + `tweak` = penulis sah). `conventions.md`/`integrations.md`/`invariants.md` = single-owner-gated → **route ke pemilik / eskalasi**, NGGAK ditulis (pola `ask`).
- **Format alasan inline:** marker `<!-- tweak: <YYYY-MM-DD> — <kenapa> -->` di sebelah fakta. (Aturan BARU tweak; `intake` cuma idempotent tanpa alasan-inline.)
- **Idempotensi:** sebelum nambah, banding **FAKTA saja** (abaikan blok marker) → kalau fakta serupa ada, update; jangan duplikat. Aman di-re-run & nggak duplikat entri `intake`/`extract`.
- **Rule-change vs konstanta:** ngubah **ANGKA pada aturan yang SUDAH ADA** di `domain.md` = konstanta → Challenge Checklist. **Bikin aturan BARU / restruktur** = rule-change → **critic independen** (`context-vault:critic`) nilai usulan SEBELUM ditulis (anti-circular).
- **No-home fallback:** kandidat by jenis fakta (aturan→`domain`, langkah→`flows`, istilah→`glossary`); nggak jelas → default `domain.md` TAPI tampil di gate step 5 ("capture ke domain.md — pindahin?"). Jangan diam-diam drop.
```

- [ ] **Step 4: Verifikasi**

Dry-run C-RULE/C-CONST/C-IDEMP/C-OWN/C-HOME/C-COSME terhadap step 4 + §D. Pastiin C-OWN beneran route (cek frasa "JANGAN tulis"); C-IDEMP terlindungi frasa "banding FAKTA saja".
Run: `grep -nE 'FAKTA saja|critic independen|route|tweak: <YYYY' plugin/skills/tweak/reference.md` → Expected: keempat aturan ada.

- [ ] **Step 5: Commit**
```bash
git add plugin/skills/tweak/SKILL.md plugin/skills/tweak/reference.md
git commit -m "feat(tweak): step 3-4 + reference §D — TDD otomatis + capture ownership-correct"
```

---

### Task 5: SKILL.md step 5-6 + Catatan + reference.md §E — gate, floor-scan, finish/PR

**Files:**
- Modify: `plugin/skills/tweak/SKILL.md` (isi `### 5.`, `### 6.`, `## Catatan`)
- Modify: `plugin/skills/tweak/reference.md` (tambah §E)

**Interfaces:**
- Consumes: semua sebelumnya.
- Produces: gate + floor-scan + finish PR + justifikasi manifest-lifecycle + NON-resumable; §E mekanik PR.

- [ ] **Step 1: Tulis skenario eval gate/finish**

```
G-SECRET : diff ada API key hardcoded            → floor-scan STOP di step 5
G-LOOSEN : diff `auth: false` lolos cabang B?(no, ke-catch B) tapi floor-scan tetep nangkep pola loosening → STOP
G-CHECK  : gate nampilin Challenge Checklist TERISI (bukan "approve?" doang)
F-BRANCH : di main → bikin branch tweak/<slug> dulu (minta izin)
F-PR     : finish = commit + buka PR (BUKAN nyerah ke /ship)
F-RESUME : interupsi setelah commit → re-run dari awal (sandar git), bukan resume manifest
```

- [ ] **Step 2: Tulis `### 5.`, `### 6.`, `## Catatan` di SKILL.md**

```markdown
### 5. Gate (floor-scan + anti-yes-man)
**Floor-scan WAJIB dulu** (`reference.md` §E): scan diff buat (a) **secret hardcoded** + **PII di log/response**, (b) **pola security-loosening** (toggle auth→false, hapus middleware auth/validasi, TTL membesar, hapus signature-check). Kena → STOP. Lalu tampilin: diff kode + update knowledge + alasan + hasil test + **Challenge Checklist TERISI** (`Bentrok aturan: <isi> · Tradeoff: <isi> · Alternatif simpel: <isi> · Yang bisa jebol: <isi>`) → minta **approve/revisi**. (Challenge Checklist = output terisi, BUKAN interogasi 4-ronde.)

### 6. Finish — commit + PR
Commit (pesan muat rasionale) → buka PR (`reference.md` §E). Selesai **satu perintah**. Refresh `render-docs` opsional (default skip). **Kenapa boleh nge-PR padahal `fix` nggak:** `ship` pemilik siklus status manifest (`shipped`); `fix` punya `fix.yaml` jadi butuh ship nutup lifecycle; **`tweak` nggak punya manifest (atomik) → nggak ada lifecycle buat ditutup → finish sendiri.** Bukan nyerobot ship.

## Catatan
- BUKAN urusannya: defect (→ `/fix`), kapabilitas/lintas-app/fondasional (→ `/feature`), nentuin stack (→ `architect`), nandai `shipped` (→ `ship`).
- **NON-resumable, single-session.** Interupsi → re-run dari awal, sandar git (ter-commit kelihatan, capture idempotent, un-committed dibuang).
- Visibility: tweak ber-capture kelihatan via `business/*.md` (dibaca `ask` live); `render-docs` HTML perlu regen (default-skip = bisa stale). Tweak kosmetik = git history aja.
- TDD = korektifitas; keamanan = cabang-B + floor-scan (TDD-ijo BUKAN jaminan aman).
```

- [ ] **Step 3: Tulis §E di reference.md**

```markdown
## E. Floor-scan + mekanik PR
**Floor-scan (step 5, WAJIB, mekanis):** grep diff final — (a) secret hardcoded (API key/token/password/connstring di luar env) + PII di log/response (persis quick-scan `ship` sensitivity-kosong); (b) pola security-loosening: `auth`/flag → `false`, penghapusan middleware auth/validasi, TTL membesar, penghapusan signature-check. Kena → STOP, lapor.
**Mekanik PR (step 6, reuse `ship`):**
- Branch `tweak/<slug>` (kalau di `main`/`master` → minta izin / checkout dulu).
- Base-branch: symbolic-ref; **tanya kalau ambigu**.
- **Multi-repo:** karena override-sadar TIDAK berlaku buat ">1 unit", tweak paling banyak 1 unit app → commit kode di repo app + commit capture di repo hub `control/` → **PR di repo app**.
- **NGGAK** pakai `finishing-a-development-branch` (jatah `ship`).
```

- [ ] **Step 4: Verifikasi**

Dry-run G-SECRET/G-LOOSEN/G-CHECK/F-BRANCH/F-PR/F-RESUME terhadap step 5-6 + §E + Catatan. Pastiin F-PR justifikasi manifest-lifecycle ada; F-RESUME "re-run dari awal" ada.
Run: `grep -nE 'security-loosening|manifest|NON-resumable|finishing-a-development-branch' plugin/skills/tweak/SKILL.md plugin/skills/tweak/reference.md` → Expected: keempat konsep ada.

- [ ] **Step 5: Commit**
```bash
git add plugin/skills/tweak/SKILL.md plugin/skills/tweak/reference.md
git commit -m "feat(tweak): step 5-6 + reference §E — gate/floor-scan + finish/PR (manifest-lifecycle)"
```

---

### Task 6: Cross-ref, skenario eval §F, registrasi + bump versi

**Files:**
- Modify: `plugin/skills/tweak/reference.md` (tambah §F skenario eval)
- Modify: `README.md`
- Modify: `plugin/skills/fix/SKILL.md` (Catatan), `plugin/skills/intake/SKILL.md` (Catatan)
- Modify: `plugin/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`

**Interfaces:**
- Consumes: skill `tweak` lengkap.
- Produces: skill ke-23 teregistrasi & cross-ref bersih.

- [ ] **Step 1: Tulis §F (skenario eval) di reference.md**

Pindahkan SEMUA skenario eval dari scratchpad Task 1-5 (TRIGGER±, T-A/B/C/OK/PREC, C-*, G-*, F-*) jadi `## F. Skenario eval` — tabel `prompt | cabang/perilaku diharapkan`. Ini acceptance permanen skill.

- [ ] **Step 2: Update README.md — daftar skill + tabel lane**

Tambah blok di `README.md` (dekat bagian "Bikin fitur"/"lifecycle"):
```markdown
## Perubahan kecil (jalur ringan)
```
/tweak <apa>        # perubahan KECIL berjejak: keputusan/kebijakan kecil → capture ke control/ tanpa pipeline berat; tripwire auto naik-kelas
```
| Skill | Kapan |
|---|---|
| `/tweak` | perubahan kecil, bukan bug, nggak fondasional — raih duluan |
| `/fix` | perilaku lama yang *salah* (defect) |
| `/feature` | kapabilitas baru / gede / lintas-app / fondasional |
```

- [ ] **Step 3: Cross-ref di `fix` + `intake`**

Di `plugin/skills/fix/SKILL.md` `## Catatan`, tambah baris: `- Perubahan kecil yang BUKAN defect (ganti kebijakan/konstanta) → \`/tweak\`, bukan \`fix\`.`
Di `plugin/skills/intake/SKILL.md` (awal/Catatan), tambah baris: `- \`tweak\` bisa eskalasi ke sini (invoke \`/feature\`→\`intake\`) bawa seed konteks saat perubahan kecil ternyata gede/fondasional.`

- [ ] **Step 4: Bump versi + sebut tweak di dua manifest**

`plugin/.claude-plugin/plugin.json`: `version` `0.4.2`→`0.5.0`; sisipin di description: `tweak (jalur ringan perubahan kecil berjejak: tripwire 3-cabang ukuran/keamanan/defect, capture ke business/* tanpa pipeline berat, finish-sampai-PR)`.
`.claude-plugin/marketplace.json`: `metadata.version` + `plugins[0].version` `0.4.2`→`0.5.0`; sisipin `tweak` di `plugins[0].description`.

- [ ] **Step 5: Verifikasi**

```bash
grep -c '"version": "0.5.0"' plugin/.claude-plugin/plugin.json .claude-plugin/marketplace.json   # marketplace punya 2 → total 3
grep -n "tweak" README.md plugin/skills/fix/SKILL.md plugin/skills/intake/SKILL.md
grep -nE '^## F' plugin/skills/tweak/reference.md
```
Expected: versi `0.5.0` di semua manifest; `tweak` muncul di README+fix+intake; §F ada. Pastiin nggak ada referensi ke task/fungsi yang nggak ada.

- [ ] **Step 6: Commit**
```bash
git add README.md plugin/skills/tweak/reference.md plugin/skills/fix/SKILL.md plugin/skills/intake/SKILL.md plugin/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "feat(tweak): registrasi skill ke-23 — README + cross-ref fix/intake + bump 0.5.0 + §F eval"
```

---

## Self-Review

**1. Spec coverage** (tiap section spec → task):
- §1-2 konteks/tujuan → Task 1 description + tujuan SKILL.md ✓
- §3 posisi vs fix/feature → Task 1 description + Task 6 README lane ✓
- §4 alur 6-langkah → Task 1 (skeleton) + 2,4,5 (isi) ✓
- §5 tripwire 3-cabang + precedence + angka-vs-plumbing → Task 2 (SKILL ringkas) + Task 3 (§A-C detail) ✓
- §6 capture (ownership/marker/idempotensi/rule-vs-konstanta/no-home) → Task 4 + §D ✓
- §7 TDD otomatis korektifitas-saja → Task 4 step 3 ✓
- §8 finish PR + manifest-lifecycle + multi-repo + visibility → Task 5 + §E ✓
- §9 keamanan berlapis (floor-scan + critic mekanis) → Task 5 §E + Task 4 §D (critic) ✓
- §10 NON-resumable → Task 5 Catatan ✓
- §11 eval (trigger ±, tripwire, capture, floor-scan) → skenario di tiap task, dikonsolidasi §F (Task 6) ✓
- §12 ditunda (decisions.yaml, render-docs default) → sengaja TIDAK diimplementasi (non-goal) ✓

**2. Placeholder scan:** Konten verba/marker/aturan ditulis konkret (verbatim dari spec). Komentar `<!-- diisi Task N -->` di Task 1 adalah **scaffolding sengaja** yang diisi Task 2/4/5 — bukan placeholder yang ketinggalan; tiap pengisi punya konten lengkap di task-nya.

**3. Konsistensi nama/anchor:** Anchor reference.md `§A`(verba)·`§B`(angka-vs-plumbing+fondasional)·`§C`(defect)·`§D`(capture)·`§E`(floor-scan+PR)·`§F`(eval) dipakai konsisten dari SKILL.md. Marker `<!-- tweak: <YYYY-MM-DD> — ... -->` sama di SKILL §4 ringkas & §D detail. Versi `0.5.0` sama di kedua manifest.

> **Catatan domain:** "test" di plan ini = skenario eval + cek struktural grep (skill = prosa LLM, bukan kode eksekusi — plugin ini nggak punya harness unit-test). Validasi perilaku sebenarnya = jalanin skill terhadap prompt eval §F setelah ke-install.
