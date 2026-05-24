# Fase 3: Architecture & Extract — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) atau superpowers:executing-plans untuk eksekusi task-by-task. Gunakan **superpowers:writing-skills** saat menulis `SKILL.md`. Verifikasi bersifat **skenario** (jalankan skill pada produk temp ber-`control/`, cek artifact), bukan unit test.
>
> **PRASYARAT:** Fase 1 & 2 sudah merged + pushed (plugin installable, `init` + pipeline `feature` jalan). Skill di fase ini mengikuti pola yang sudah ada di `plugin/skills/*` (frontmatter `name`+`description`, body Bahasa Indonesia, operasi pada `control/` produk, pola Challenge Checklist + invoke subagent `critic`, GATE sebelum menulis).

**Goal:** Membuat skill `architect` (menetapkan stack greenfield / merekam stack+capabilities brownfield + konvensi lintas-app) dan `extract` (front-load `business/` dari kode existing, opsional brownfield).

**Architecture:** Dua skill di `plugin/skills/`. `architect` mengisi lapisan TEKNIS dari System Map — `stack` & `capabilities` tiap app di `control/workspace.yaml` + `control/conventions.md` — terpisah dari fitur bisnis; ia knowledge-only (kode app dibuat scaffolder resmi pada setup, atau sudah ada pada capture). `extract` mengisi `control/business/` dari kode existing via scan + wawancara + `critic`, dengan format identik output `intake`. Keduanya pakai pola Challenge Checklist + GATE + `critic` yang sudah ada.

**Tech Stack:** Claude Code Plugin (SKILL.md markdown), YAML (workspace.yaml), Markdown (conventions.md, business/). Tidak ada runtime code.

**Konvensi commit:** tiap commit diakhiri trailer `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`. Tidak diulang di tiap blok.

---

## File Structure

Semua path relatif ke root repo `context-vault`:

- `plugin/skills/architect/SKILL.md` — fondasi teknis (stack + capabilities + conventions), mode setup/capture.
- `plugin/skills/extract/SKILL.md` — front-load `business/` dari kode (brownfield, opsional).
- `README.md` — Modify: tambah `architect` & `extract` ke alur.

Tanggung jawab terpisah: `architect` = lapisan TEKNIS knowledge; `extract` = lapisan BISNIS knowledge dari kode existing. Keduanya menulis `control/` produk, bukan aset plugin. Tidak ada perubahan pada `init`/pipeline.

**Artifact yang disentuh (di produk):** `control/workspace.yaml` (`stack`, `capabilities`), `control/conventions.md`, `control/business/*.md`.

---

## Task 1: Skill `architect`

**Files:**
- Create: `plugin/skills/architect/SKILL.md`

- [ ] **Step 1: Tulis `plugin/skills/architect/SKILL.md`**

````markdown
---
name: architect
description: Use untuk menetapkan (greenfield) atau merekam (brownfield) fondasi teknis produk — stack per app + capabilities + konvensi lintas-app. Dijalankan setelah init, sebelum bikin fitur; bisa di-rerun saat nambah app/package. Trigger — "architect", "setup stack", "capture arsitektur". Jalankan dari root produk yang punya control/.
---

# architect — Fondasi Teknis

Tujuan: isi lapisan TEKNIS dari System Map — `stack` tiap app + `capabilities` + konvensi lintas-app (`conventions.md`) — TERPISAH dari fitur bisnis.

## Langkah

### 1. Baca state
Baca `control/workspace.yaml` (apps, path, stack, capabilities) + `control/conventions.md`.

### 2. Tentukan mode PER app
Untuk tiap app, cek kode di `path`-nya:
- **Kosong / belum ada kode → SETUP mode.**
- **Ada kode → CAPTURE mode.**
(Boleh campur: sebagian app setup, sebagian capture.)

### 3a. SETUP (app greenfield)
- Q&A **TEKNIKAL** (bukan bisnis): framework, bahasa, DB/ORM, lib kunci.
- Tulis hasil ke `stack` app di `control/workspace.yaml` (mis. `stack: { framework: Next.js, db: Postgres, orm: Prisma }`).
- Usulkan command bootstrap RESMI stack-nya (mis. `npx create-next-app@latest apps/web`) → **GATE: user yang jalanin.** `architect` TIDAK menulis kode framework sendiri — delegasi ke scaffolder resmi.

### 3b. CAPTURE (app existing)
- Scan `package.json` + struktur folder/route di `path` app → rekam `stack` (framework, db bila terbaca) ke `control/workspace.yaml`.
- Inferensi `capabilities` dari nama route/module/folder (mis. `routes/checkout` → `checkout`) → isi `capabilities` app di `workspace.yaml`. **Konfirmasi ke user** sebelum menulis.
- Catat **divergensi** antar-app (mis. `web` pakai Prisma, `dashboard` pakai TypeORM) → laporkan ke user.

### 4. Konvensi lintas-app
Tetapkan/rekam kontrak bersama (auth, format API, shared package, ORM standar) → tulis ke `control/conventions.md` (ganti skeleton-nya). Untuk keputusan fondasi besar (mahal di-refactor), jalankan Challenge Checklist + invoke subagent `critic`.

### 5. Challenge Checklist (WAJIB sebelum gate)
- Konsisten antar-app? ada divergensi berisiko?
- Tradeoff pilihan stack/konvensi?
- Ada yang over-engineered / bisa lebih sederhana?

### 6. Tulis output (GATE)
Tampilkan `stack` & `capabilities` per app (`workspace.yaml`) + isi `conventions.md` → minta **approve**. Sarankan langkah berikutnya: `extract` (brownfield, opsional) atau langsung `feature`.

## Catatan
- `architect` = KNOWLEDGE fondasi (stack/konvensi/capabilities), BUKAN generator kode. Kode app dibuat scaffolder resmi (setup) atau sudah ada (capture).
- Bisa di-rerun saat nambah app/shared package.
- Sesudah ini, skill `plan` membaca `stack` + `conventions.md` + kode yang ada — tidak menetapkan stack lagi.
````

- [ ] **Step 2: Validasi frontmatter**

Run: `head -4 plugin/skills/architect/SKILL.md`
Expected: `---`, `name: architect`, `description: ...`, `---`.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/architect/SKILL.md
git commit -m "feat(skill): add architect (tech foundation) skill"
```

---

## Task 2: Skill `extract`

**Files:**
- Create: `plugin/skills/extract/SKILL.md`

- [ ] **Step 1: Tulis `plugin/skills/extract/SKILL.md`**

````markdown
---
name: extract
description: Use HANYA untuk produk brownfield — front-load business/ (domain/flows/glossary) dari kode existing + wawancara, sekali jalan. Opsional; default sistem = knowledge tumbuh just-in-time lewat feature. Trigger — "extract business", "bootstrap knowledge dari kode". Jalankan dari root produk yang punya control/.
---

# extract — Front-load Business Knowledge (brownfield, opsional)

Tujuan: isi `control/business/` dari kode yang sudah ada, untuk produk besar yang perlu knowledge lengkap di awal. Output FORMAT SAMA dengan output `intake`.

## Langkah

### 1. Baca state
Baca `control/workspace.yaml` (apps + path) + `control/business/*` (lihat yang sudah ada, jangan timpa membabi buta).

### 2. Scan kode lintas-app
Untuk tiap app, baca kode di `path`-nya. Identifikasi yang **TERBUKTI di kode**:
- Aturan/kebijakan (validasi, batas, status, perhitungan harga/pajak) → kandidat domain rule.
- Alur (urutan langkah di endpoint/handler) → kandidat flow.
- Istilah berulang (entity/konsep) → kandidat glossary.

### 3. Wawancara (kode gak nyimpen "kenapa")
Tanya user untuk mengonfirmasi & melengkapi alasan/kebijakan yang tak terlihat dari kode. Tandai yang belum terverifikasi.

### 4. Critic (WAJIB sebelum nulis)
Invoke subagent `critic` atas draft `business/` — minta flag aturan yang spekulatif / tak didukung kode / belum dikonfirmasi. Jangan masukkan yang masih ragu sebagai fakta; beri tanda "perlu konfirmasi".

### 5. Tulis output (GATE per bagian)
Tulis ke `control/business/domain.md`, `flows.md`, `glossary.md` (format sama dengan `intake`). Konservatif — jangan mengarang. Tampilkan draft → minta **approve per bagian**.

## Catatan
- `extract` OPSIONAL & sekali jalan. Default sistem = just-in-time lewat `feature`/`plan`.
- Jalankan SETELAH `architect` (butuh path app; lebih baik bila `capabilities` sudah terisi).
````

- [ ] **Step 2: Validasi frontmatter**

Run: `head -4 plugin/skills/extract/SKILL.md`
Expected: `---`, `name: extract`, `description: ...`, `---`.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/extract/SKILL.md
git commit -m "feat(skill): add extract (brownfield business front-load) skill"
```

---

## Task 3: Verifikasi end-to-end (skenario)

Setup `control/` manual agar tes tidak bergantung pada init.

- [ ] **Step 1: Skenario A — `architect` SETUP (greenfield)**

Setup:
```bash
mkdir -p /tmp/cv-arch-setup/control/business /tmp/cv-arch-setup/apps
cat > /tmp/cv-arch-setup/control/workspace.yaml <<'YAML'
product: demo
topology: monorepo
apps:
  - name: web
    path: apps/web
    type: fullstack
    responsibility: "Builder + dashboard"
    capabilities: []
    stack: {}
YAML
printf '# demo — Konvensi & Kontrak Teknis Lintas-App\n' > /tmp/cv-arch-setup/control/conventions.md
echo "setup A done"
```
Di sesi Claude Code dengan plugin ter-install, cwd `/tmp/cv-arch-setup`, invoke `architect`. App `web` kosong → mode SETUP; jawab Q&A teknikal (Next.js, Postgres, Prisma). Approve. (Command bootstrap cukup ditampilkan, tidak perlu dijalankan untuk tes ini.)

- [ ] **Step 2: Assert A**

Run:
```bash
grep -q "framework: Next.js" /tmp/cv-arch-setup/control/workspace.yaml \
  && test -s /tmp/cv-arch-setup/control/conventions.md \
  && echo "ARCH SETUP OK"
```
Expected: `ARCH SETUP OK`

- [ ] **Step 3: Skenario B — `architect` CAPTURE (brownfield)**

Setup:
```bash
mkdir -p /tmp/cv-arch-cap/control/business /tmp/cv-arch-cap/apps/web/src/routes/checkout /tmp/cv-arch-cap/apps/web/src/routes/catalog
cat > /tmp/cv-arch-cap/control/workspace.yaml <<'YAML'
product: shop
topology: monorepo
apps:
  - name: web
    path: apps/web
    type: fullstack
    responsibility: "Storefront"
    capabilities: []
    stack: {}
YAML
echo '{"dependencies":{"next":"14.0.0","prisma":"5.0.0"}}' > /tmp/cv-arch-cap/apps/web/package.json
printf '# shop\n' > /tmp/cv-arch-cap/control/conventions.md
echo "setup B done"
```
cwd `/tmp/cv-arch-cap`, invoke `architect`. App `web` ada kode → mode CAPTURE; konfirmasi capabilities yang di-infer (mis. `checkout`, `catalog`). Approve.

- [ ] **Step 4: Assert B**

Run:
```bash
grep -q "framework: Next.js" /tmp/cv-arch-cap/control/workspace.yaml \
  && grep -Eq "checkout|catalog" /tmp/cv-arch-cap/control/workspace.yaml \
  && echo "ARCH CAPTURE OK"
```
Expected: `ARCH CAPTURE OK` (capabilities `checkout`/`catalog` ter-infer dari nama route, stack ter-capture dari package.json)

- [ ] **Step 5: Skenario C — `extract` (brownfield)**

Setup (pakai produk dari skenario B + tambah kode beraturan):
```bash
mkdir -p /tmp/cv-arch-cap/apps/web/src/lib
cat > /tmp/cv-arch-cap/apps/web/src/lib/checkout.ts <<'TS'
// pajak 11% diterapkan di checkout
export const TAX_RATE = 0.11;
// voucher tidak bisa ditumpuk
export function applyVoucher(order, voucher) { /* satu voucher per order */ }
TS
: > /tmp/cv-arch-cap/control/business/domain.md
: > /tmp/cv-arch-cap/control/business/flows.md
: > /tmp/cv-arch-cap/control/business/glossary.md
echo "setup C done"
```
cwd `/tmp/cv-arch-cap`, invoke `extract`. Verifikasi: scan kode nemu aturan (pajak 11%, voucher tak menumpuk), wawancara konfirmasi, `critic` di-invoke buat flag yang spekulatif, lalu tulis ke `business/`.

- [ ] **Step 6: Assert C**

Run:
```bash
test -s /tmp/cv-arch-cap/control/business/domain.md \
  && grep -Eqi "pajak|tax|voucher" /tmp/cv-arch-cap/control/business/domain.md \
  && echo "EXTRACT OK"
```
Expected: `EXTRACT OK` (business/domain.md terisi aturan yang terbukti di kode)

- [ ] **Step 7: Konfirmasi `critic` (skenario)**

Pada Step 5, pastikan `critic` dipanggil dan memberi flag terhadap aturan yang belum terkonfirmasi (mis. menandai asumsi yang tidak terbukti di kode). Catat di hasil.

- [ ] **Step 8: Bersihkan**

Run: `rm -rf /tmp/cv-arch-setup /tmp/cv-arch-cap && echo "cleaned"`
Expected: `cleaned`

---

## Task 4: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Tambah `architect` & `extract` ke alur di `README.md`**

Sisipkan ke bagian alur produk (sesuaikan dengan teks aktual; setelah `/init`, sebelum `/feature`):
```markdown
## Fondasi teknis
```
/architect          # tetapkan stack (greenfield) / rekam stack+capabilities (brownfield) + konvensi
/extract            # (brownfield, opsional) front-load business/ dari kode existing
```
Urutan brownfield: `/init` -> `/architect` -> `/extract` (opsional) -> `/feature`.
Urutan greenfield: `/init` -> `/architect` -> `/feature`.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: document architect and extract skills in README"
```

---

## Definition of Done (Fase 3)

- [ ] `plugin/skills/architect/SKILL.md` + `plugin/skills/extract/SKILL.md` ada, frontmatter valid, terdeteksi setelah plugin reload.
- [ ] `architect` SETUP mengisi `stack` di `workspace.yaml` + menulis `conventions.md`, dan mengusulkan (bukan menjalankan) command bootstrap (ARCH SETUP OK).
- [ ] `architect` CAPTURE merekam `stack` dari `package.json` + mengisi `capabilities` dari struktur kode + melaporkan divergensi (ARCH CAPTURE OK).
- [ ] `extract` mengisi `business/` dari aturan yang terbukti di kode, lewat `critic` + GATE, konservatif (EXTRACT OK).
- [ ] `critic` ter-invoke di `extract` (dan di keputusan fondasi besar `architect`).
- [ ] README ter-update; tidak ada placeholder tersisa di file produksi.
```
