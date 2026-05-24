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
