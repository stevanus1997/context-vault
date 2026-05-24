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
