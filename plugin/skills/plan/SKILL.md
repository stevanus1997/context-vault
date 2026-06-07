---
name: plan
description: Use untuk fase teknis per-app sebuah fitur (P2 fase 2) — baca kode tiap app yang kena, Q&A teknis, hasilkan plan implementasi. Trigger — "plan <fitur>", dipanggil oleh skill feature.
---

# plan — Technical Plan per-app (P2 fase 2)

Tujuan: untuk tiap app yang kena fitur, susun plan implementasi konkret berbasis kode & konvensi yang ADA.

> Detail **UI-Contract**, slot `Mockup:` 3-jalur, cross-check, dispatch generate, & round-trip ada di `${CLAUDE_PLUGIN_ROOT}/skills/plan/reference.md` — baca itu saat app menyentuh permukaan UI.

## Langkah

### 1. Baca input
Baca `control/features/<fitur>/business.md` + `fanout.md` + `control/conventions.md` + `control/workspace.yaml` (untuk `path` & `stack` tiap app, **plus `packages[]` + `consumers[]` — read-only; `plan` tak pernah menulis `consumers[]`, itu jatah `fanout`**) + `control/integrations.md` (kontrak vendor eksternal — read-only) + `control/features/<fitur>/mockups/` (mockup UI yang diserahkan pengguna, **bila ada** — cek keberadaan saja; isi TIDAK di-parse di sini, diserahkan ke `build`) + `control/design-system.md` (fondasi visual — untuk jalur generate & konteks komponen app UI, read-only).

### 2. Selesaikan kontrak lintas-app dulu
Bila `fanout.md` menyebut dependency lintas-app (mis. mekanisme token web↔api), putuskan kontraknya lebih dulu dan tulis `control/features/<fitur>/plans/_shared.md`:
```
# <Fitur> — Kontrak Lintas-App
<keputusan bersama, mis. mekanisme/format, siapa issuer & validator, env yang dibagi>
```

### 2b. Kontrak package (untuk tiap package di fanout.md)
Untuk tiap package yang kena fitur (`PACKAGE NEW`/`PACKAGE TOUCHED`), tulis `control/features/<fitur>/plans/<pkg>.md` = **kontrak** (bukan implementasi):
```
# <pkg> — Kontrak
Exports   : <fungsi/tipe + signature>
Invarian  : <invarian yang dijaga package, mis. semua uang lewat sini>
Consumers : <app dari packages[<pkg>].consumers>
```
**Deteksi BREAKING (fan-IN):** kalau package SUDAH ADA sebelum fitur ini (`PACKAGE TOUCHED`, punya kode terkini) dan exports/signature berubah dibanding kode terkini → tandai **`BREAKING`** di `plans/<pkg>.md` + daftar consumer terdampak. **Carve-out package baru:** package yang **baru dibikin fitur ini** (`PACKAGE NEW`, lewat `add-package`) tak punya kontrak sebelumnya → **TIDAK ada `BREAKING`**; consumer-nya dapat integrasi fan-OUT biasa. (Cek: package ada di `workspace.yaml` saat fitur mulai?)

### 2c. Promote kontrak vendor (untuk tiap vendor di fanout.md)
Untuk tiap vendor yang kena fitur (`VENDOR NEW`/`VENDOR TOUCHED`/`…perlu UPDATE`), **promote** kontraknya dari `control/integrations.md` ke `plans/_shared.md` — **referensikan**, bukan derive ulang. **Idempotent:** kalau kontrak vendor itu sudah ada di `_shared.md` (fitur lebih awal sudah promote) → reuse/referensikan, JANGAN tulis ulang. Mis. "Pembayaran via `<vendor>` — outbound dgn Idempotency-Key per request; inbound webhook di `<Receiver app>` path `<...>`, verifikasi `<Signature>`."
**Kebutuhan receiver (vendor inbound/both):** ambil `Receiver app` dari entri `integrations.md` (field durable) → tulis di `plans/<Receiver app>.md` satu baris: "Webhook masuk `<vendor>` di `<path>`: verifikasi signature (`<algo>`), idempotent (dedup), tahan replay." → basis varian task inbound-eksternal `breakdown`. (`plan` read-only ke `integrations.md`; `Receiver app` HARUS dari situ, bukan ditebak.)

### 3. Per app (untuk tiap app di fanout.md)
- **Baca `control/schema/<app>.md` (proyeksi skema durable, M4) DULU** sebagai baseline model data existing (table/kolom/relasi/`Asal`) — **JANGAN rekonstruksi skema dari nol**. (Di-generate `wire`/`build`; read-only di sini.)
- **Dampak Skema Lintas-Fitur (H3).** Bila rencana mengubah tabel ber-`Asal` fitur lain (alter-existing, bukan tabel baru fitur ini): `plan` men-supply `affects`=tabel-yang-diubah (delta vs baseline) + `kind`=taksiran sifat-perubahan, lalu panggil `${CLAUDE_PLUGIN_ROOT}/rules/migration-impact.md` → tulis blok prosa **Dampak Skema** (consumer + risiko-lock + perlu-backfill + saran expand-contract) ke `_shared.md` (consumer lintas-app) / `plans/<app>.md` (1 app), **SETELAH** fenced-template langkah 4 (bukan field di dalam fence) → sodorkan di gate. Tabel baru fitur ini / **pra-M4** (tak ada `Asal`) → skip (peringatan dini OFF; jaring pindah ke gate `build`).
- Buka kode app di `path`-nya (dari `workspace.yaml`). Baca pola yang ada; ikuti `conventions.md` & `stack`. Baca kode cuma untuk **delta/detail** yang tak ada di proyeksi.
- Q&A **teknis** seperlunya.
- Susun plan: file yang disentuh, endpoint/komponen, model data, test. **Bila app mengonsumsi package** → catat dependency-nya (package apa, dipakai untuk apa) di plan app.
- **UI-Contract (bila app punya permukaan UI).** SEBELUM mengurus mockup, turunkan **UI-Contract** layar/komponen fitur ini dari `business.md` (provider/kebijakan, mis. login Google/Facebook) + `Model/Schema` + `API/Komponen` — field, actions (+provider), states (idle/loading/error/success). Tulis sebagai section di `plans/<app>.md` (langkah 4) + **tampilkan rapi di gate** sebagai blok yang bisa pengguna copy ke tool design eksternal. App `be`/non-UI → SKIP (nol biaya). Idempotent (re-run reuse). Format + derivasi: `reference.md` §A.
- **Slot `Mockup:` — 3 jalur (bila app punya permukaan UI).** Setelah UI-Contract ada, untuk app UI yang belum punya mockup tersimpan, **tawarkan 3 jalur** (default TIDAK auto-generate): **(a) bawa mockup** — pengguna menyerahkan mockup (HTML/CSS/gambar/URL Figma) → simpan **verbatim** ke `control/features/<fitur>/mockups/` (**JANGAN** inline/diprosa-kan) → **cross-check** vs UI-Contract (advisory, konfirmasi-manusia; opacity mockup terjaga — `reference.md` §C); **(b) generate** — dispatch skill `frontend-design` dengan UI-Contract + token/komponen `design-system.md` → mockup ke `mockups/` → **gate eyeball** approve/regen (`reference.md` §D); **(c) degrade** — sengaja tak mau → lanjut tanpa `Mockup:` (perilaku sekarang). Catat path hasil (a/b) untuk slot `Mockup:` (langkah 4). **Round-trip "design sendiri"** (kasih UI-Contract → pengguna design di luar → balik): sesi-sama tunggu di gate; sesi-beda jalankan `/plan` lagi — `reference.md` §E.
- **Challenge teknis** sebelum gate: konsistensi dengan konvensi? risiko? cara lebih sederhana? Apakah plan ini melanggar invarian yang terkunci di `control/invariants.md` (tenancy/money/idempotency/authz/PII-PCI)? **Apakah app ini membuat logika yang seharusnya pakai mandatory package** (mis. format uang sendiri padahal `money` ada di `packages[].mandatory_for` app ini)? **Apakah fitur menyentuh vendor eksternal tapi kontraknya tak ada di `control/integrations.md`** (seam `fanout` terlewat)? → arahkan jalankan `add-integration`.
- **Debt-aware (utang teknis di area ini).** Ikuti `${CLAUDE_PLUGIN_ROOT}/rules/debt-aware.md`: baca `control/debt.yaml`, saring utang `open` (`owner: feature`) yang `area`-nya ∈ app ini. Ini **rider** pada baca-kode app yang sudah dilakukan di atas, bukan langkah baru. Utang yang ketemu disodorkan di gate (langkah 4).

### 4. Tulis output (GATE per app/package)
Tulis `control/features/<fitur>/plans/<pkg>.md` (kontrak, langkah 2b) lalu `control/features/<fitur>/plans/<app>.md`:
```
# <app>
Model/Schema : <...>
API/Komponen : <...>
UI-Contract  : <field/actions/states per layar — app UI saja (reference.md §A); ATAU kosong non-UI>
Lokasi       : <path konkret di app>
Mockup       : <path… ke control/features/<fitur>/mockups/ ATAU kosong>
Test         : <...>
```
Tampilkan tiap plan → minta **approve per app**. **Bila ada utang `open` di area app ini** (langkah 3 debt-aware): sodorkan di gate — *"area ini punya N utang open: `<ringkas>`. Lipat ke fitur ini? (+N task)"*. Untuk tiap utang yang di-ACC, tulis baris **`Utang dilunasi: <id>`** di `plans/<app>.md` (ini yang dibaca `breakdown` §4 untuk membuat task `kind: debt, pays_debt: <id>`). Yang ditolak biarkan `open` — tetap muncul di render-docs "Known Issues". `plan` **tidak** menulis `control/debt.yaml` (status diturunkan; pemiliknya `/debt`).

## Catatan
- JANGAN menetapkan stack/framework di sini — itu sudah ditetapkan `architect`. `plan` membaca yang ADA. Bila app belum punya fondasi (skeleton belum jalan), hentikan & arahkan user menjalankan `wire` dulu (bring-up; `wire` jalan setelah `architect`).
- Setelah semua plan di-approve, kontrol kembali ke `feature` (yang menandai status `active`).
- `plan` tetap FLAT. Dekomposisi jadi task kecil (siap-eksekusi) = jatah skill `breakdown`, bukan di sini. Slot `Mockup:` adalah **pointer** ke file di `mockups/`, **bukan** deskripsi visual — `plan` tak pernah memprosa-kan isi mockup (itu byte opaque untuk `build`).
- **UI-Contract vs Mockup (dua hal beda).** `UI-Contract` = kebutuhan data (field/provider/state) sebagai **teks otoritatif** — sumber field yang dibaca `breakdown`/`build`. `Mockup:` = tampilan sebagai **byte opaque** (di-reproduksi `build`). UI-Contract menyetir design (bahan generate / cek mockup-bawaan); generate menghasilkan **mockup-reference**, `build` tetap implement via TDD (bukan kode produksi langsung). Field otoritatif tetap UI-Contract walau mockup ada.
- Bila `tasks.yaml` sudah ada untuk fitur ini (sudah pernah `breakdown`), revisi `plan` membuatnya **basi** — ingatkan user menjalankan `breakdown` ulang (yang mempertahankan status task `done`) sebelum `build` lanjut.
