---
name: feature
description: Use untuk membangun sebuah fitur end-to-end — konduktor yang menjalankan intake → fanout → plan dengan gate tiap tahap dan mengelola status fitur. Trigger — "feature <nama>", "bikin fitur <nama>", "tambah fitur <nama>".
---

# feature — Konduktor Pipeline Fitur

Tujuan: menyetir pipeline fitur dari ide sampai plan siap-eksekusi. Jalankan dari root produk (yang punya `control/`).

## Langkah

### 1. Buat folder & status fitur
Buat `control/features/<nama>/feature.yaml`:
```yaml
name: <nama>
status: draft
created: <YYYY-MM-DD>
sensitivity: []        # [] | [payments] | [pii] | [payments, pii] — diusulkan intake, dikonfirmasi user
```
(Bila sudah ada, lanjutkan dari tahap yang belum selesai — lihat artifact mana yang sudah ada.)

### 2. Jalankan tahap berurutan dengan gate
1. Invoke skill **`intake`** untuk `<nama>` → tunggu gate (approve `business.md`).
2. Invoke skill **`fanout`** untuk `<nama>` → tunggu gate (approve `fanout.md`).
   - **Bila `fanout.md` nandain app `NEW` (belum ada):** untuk tiap app baru, invoke skill **`add-app <nama-app>`** (declare entri → `architect` → `wire`, semua gated) → tunggu beres.
   - **Bila `fanout.md` nandain `PACKAGE NEW` (belum ada):** untuk tiap package baru, invoke skill **`add-package <nama-pkg>`** (declare entri → `architect` → `wire` mode-package, semua gated) → tunggu beres.
   - **Bila `fanout.md` nandain `VENDOR NEW` atau `VENDOR TOUCHED — perlu UPDATE`:** untuk tiap vendor itu, invoke skill **`add-integration <vendor>`** (declare kontrak SHAPE → `wire` mode-integration bila inbound, gated) → tunggu beres. Plain `VENDOR TOUCHED` (tanpa perlu-UPDATE) TIDAK di-invoke — cukup `plan` promote kontrak existing.
   - **Bila `fanout.md` nandain `DESIGN-SYSTEM NEEDED` (app peran-UI belum terdaftar):** untuk tiap app itu, invoke skill **`design-system`** (tentukan scope → SETUP/CAPTURE → tulis `control/design-system.md` + bangun token & komponen primitif, semua gated) → tunggu beres.
   - Selesaikan SEMUA `add-app` lalu `add-package` lalu `add-integration` lalu `design-system` dulu, **baru lanjut ke `plan`**. Saat `plan` jalan, app/package baru sudah ada di `workspace.yaml` (app ter-wire; package ter-typecheck), vendor sudah ada di `integrations.md`, & app peran-UI sudah bergaya (token+primitif di kode, `design-system.md` terisi) — fitur tinggal konsumsi.
3. Invoke skill **`plan`** untuk `<nama>` → tunggu gate (approve semua `plans/<app>.md`).

Jangan lanjut tahap berikutnya sebelum gate tahap sebelumnya di-approve user.

### 3. Tandai active
Setelah semua `plan` di-approve, set `control/features/<nama>/feature.yaml` → `status: active`.

### 4. Ringkas
Tampilkan artifact yang dihasilkan (`business.md`, `fanout.md`, `plans/*`). Sarankan langkah berikutnya: jalankan `breakdown` (pecah plan jadi `tasks.yaml`) lalu `build` (eksekusi) — sebaiknya masing-masing sesi terpisah — baru `ship` saat selesai.

## Catatan
- `intake`/`fanout`/`plan` modular — bisa dipanggil sendiri untuk mengulang satu tahap (mis. `fanout` ulang setelah revisi `business.md`).
- Prasyarat: app sudah di-`wire` (skeleton jalan: DB nyambung, FE↔BE ke-wire). Kalau `plan` mentok karena fondasi belum ada, jalankan `wire` dulu (setelah `architect`). Kalau fitur butuh app yang **BELUM ADA** sama sekali, itu ditangani `add-app`; kalau butuh shared package yang **BELUM ADA**, ditangani `add-package` (keduanya dipicu otomatis dari `fanout` — lihat langkah 2).
- **Bila `tasks.yaml` sudah dibuat `breakdown` lalu kamu merevisi `plan`/`business`, jalankan `breakdown` ulang** (ia mempertahankan status task yang sudah `done`) sebelum lanjut `build` — biar task nggak basi.
- Eksekusi implementasi ditangani `breakdown` → `build`; transisi `shipped`/`dropped` ditangani `ship`/`drop`.
