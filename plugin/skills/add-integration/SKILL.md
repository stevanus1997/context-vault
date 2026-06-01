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
- **HANYA bila `Arah` memuat inbound (termasuk `both`):** invoke `wire` (mode-integration, `wire/reference.md` §J) buat scaffold stub webhook-receiver di `Receiver app` → GATE = app tetap boot + route ter-register + typecheck. Logika verifikasi signature/idempotent/replay = jatah `build`, BUKAN di sini.
- Outbound-only berhenti setelah rekam SHAPE env (tak ada receiver untuk di-scaffold).

### 5. Tutup & balikin
Lapor "**vendor `<vendor>` terdeklarasi di integrations.md**".
- Dipanggil `feature` (fitur butuh vendor baru) → balikin kontrol ke `feature` buat lanjut `plan`.
- Standalone → saranin langkah berikutnya (mis. `feature <fitur>`).

## Catatan
- **Cara kanonik nambah vendor pasca-`init`.** Yang nulis entri `integrations.md` cuma `add-integration`.
- **Beda dari `add-app`/`add-package`:** TAK chain `architect` (vendor tak punya stack); outbound-only TAK chain `wire`. Selain itu polanya identik (declare → bring-up gated).
- TIDAK nyentuh `control/business/*`, TIDAK nulis kode fitur (itu `build`), TIDAK nulis NILAI secret (itu `.env` GATE/manual).
