---
name: feature
description: Use untuk membangun sebuah fitur end-to-end — konduktor yang menjalankan intake → fanout → plan dengan gate tiap tahap dan mengelola status fitur. Trigger — "feature <nama>", "bikin fitur <nama>", "tambah fitur <nama>".
---

# feature — Konduktor Pipeline Fitur

Tujuan: menyetir pipeline fitur dari ide sampai plan siap-eksekusi. Jalankan dari root produk (yang punya `control/`).

## Langkah

### 1. Buat folder & status fitur
**Roadmap-aware (bila `control/roadmap.md` ada; absen → skip diam-diam, jalan seperti biasa):** dipanggil TANPA nama fitur → tampilkan backlog + status turunan (baca `status` tiap `features/<fitur>/feature.yaml`; roadmap TIDAK menyimpan status) dan sarankan fitur berikutnya yang belum shipped — operator tetap bebas milih lain. Dipanggil DENGAN nama — nama ada di roadmap → **prefill** `epic`/`depends_on` `feature.yaml` di bawah dari baris roadmap-nya (user konfirmasi di gate intake seperti biasa); tak ada di roadmap → catatan advisory "tak tercatat di roadmap — lanjut saja; re-run `/roadmap` bila mau dicatat", lalu jalan normal. Roadmap = saran, BUKAN palang.

Buat `control/features/<nama>/feature.yaml`:
```yaml
name: <nama>
status: draft
created: <YYYY-MM-DD>
sensitivity: []        # [] | [payments] | [pii] | [payments, pii] — diusulkan intake, dikonfirmasi user
epic: ""               # (M1) nama epik pengelompok; "" = standalone — metadata, bukan kontrol eksekusi
depends_on: []         # (M1) [<nama-fitur>] yang idealnya shipped dulu; warn-gate step 2 (BUKAN block)
risk: normal           # (M7) low | normal | high — blast-radius build; high = SEMUA gate segmen masuk antrian review saat unattended (bukan kill-switch); payments-movement → floor high (hard), pii saja tidak
```
(Bila sudah ada, lanjutkan dari tahap yang belum selesai — lihat artifact mana yang sudah ada.)

### 2. Jalankan tahap berurutan dengan gate
**Cek dependency (warn, BUKAN block — M1):** bila `feature.yaml` punya `depends_on` non-kosong, untuk tiap `<dep>` baca `control/features/<dep>/feature.yaml`. Bila `status` ≠ `shipped` (atau `dropped`/tak ditemukan), **tampilkan peringatan** (mis. `dep <X> belum shipped (status active)` / `<X> dropped — rencana mungkin basi` / `<X> tak ditemukan`) + **minta konfirmasi lanjut** — peringatan, BUKAN palang; user boleh lanjut (dependency sering dikerjakan paralel). Degrade: `depends_on` kosong/absen → skip diam-diam. Catatan jujur: di `/feature` run-pertama `depends_on` masih default `[]` (sizing-check intake mengisinya belakangan) → warn skip; warn bermakna pada run lanjutan / `depends_on` yang user isi manual.
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
- **Iterasi fitur yang sudah `shipped`** — tak ada status `deprecate`/jalur penerus first-class (status sengaja kasar — induk §12). Untuk perubahan substansial, **buat fitur baru** (nama bebas, mis. `<nama>-v2`) lewat `/feature`; untuk perbaikan bug perilaku yang sudah ada, pakai `/fix`. Jalur penerus/pensiun otomatis (immutable old-folder + supersedes) = **future, spec terpisah** (lihat induk §16 + pipeline-hardening §S4.1/§10-4).
