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
```
(Bila sudah ada, lanjutkan dari tahap yang belum selesai — lihat artifact mana yang sudah ada.)

### 2. Jalankan tahap berurutan dengan gate
1. Invoke skill **`intake`** untuk `<nama>` → tunggu gate (approve `business.md`).
2. Invoke skill **`fanout`** untuk `<nama>` → tunggu gate (approve `fanout.md`).
3. Invoke skill **`plan`** untuk `<nama>` → tunggu gate (approve semua `plans/<app>.md`).

Jangan lanjut tahap berikutnya sebelum gate tahap sebelumnya di-approve user.

### 3. Tandai active
Setelah semua `plan` di-approve, set `control/features/<nama>/feature.yaml` → `status: active`.

### 4. Ringkas
Tampilkan artifact yang dihasilkan (`business.md`, `fanout.md`, `plans/*`). Sarankan langkah berikutnya: jalankan `breakdown` (pecah plan jadi `tasks.yaml`) lalu `build` (eksekusi) — sebaiknya masing-masing sesi terpisah — baru `ship` saat selesai.

## Catatan
- `intake`/`fanout`/`plan` modular — bisa dipanggil sendiri untuk mengulang satu tahap (mis. `fanout` ulang setelah revisi `business.md`).
- Eksekusi implementasi ditangani `breakdown` → `build`; transisi `shipped`/`dropped` ditangani `ship`/`drop`.
