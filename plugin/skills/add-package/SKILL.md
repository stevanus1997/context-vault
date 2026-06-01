---
name: add-package
description: Use untuk nambah SATU shared package baru ke produk yang sudah di-init — tulis entri package ke workspace.yaml lalu chain architect (stack) lalu wire mode-package (scaffold lib + register, gate typecheck, TANPA DB/wiring/smoke). Satu-satunya penulis entri package baru pasca-init. Dipanggil feature saat fanout nandain package baru, atau standalone. Trigger — "add-package <nama>", "tambah package <x>", "bikin shared package", "scaffold package baru". Jalankan dari root produk yang punya control/.
---

# add-package — Nambah Shared Package Baru (declare lalu architect lalu wire mode-package)

Tujuan: numbuhin produk yang SUDAH di-`init` dengan SATU shared package baru (kode bareng dipakai >1 app — ui-kit/types/utils/hooks). `add-package` = konduktor tipis: tulis identitas package ke `control/workspace.yaml` `packages[]`, lalu chain `architect` (stack) lalu `wire` mode-package (scaffold + register, gate typecheck). Hasilnya package baru jadi skeleton kosong-tapi-typecheck-hijau, siap dikonsumsi app. Jalankan dari root produk (punya `control/`).

`add-package` = **kembaran `add-app`** (lihat spec `2026-05-31-add-app-skill-design.md`), beda di bring-up: package TAK punya DB/server/route → `wire` mode-package SKIP DB/wiring/smoke, gate = typecheck/lint hijau.

## Prinsip (jangan dilanggar)
- **Bukan `init`, bukan `add-app`.** `control/` harus sudah ada (post-init); minimal satu app sudah ada (package butuh consumer). Kalau belum → arahin ke `init`/`add-app`.
- **Cuma identitas, bukan stack.** `add-package` nanya name/responsibility (+ opsional wajib-buat-app-mana). Bahasa/build-tool/test-runner = jatah `architect` di langkah 4. JANGAN tanya stack di sini.
- **Shared package, bukan app.** Package = kode bareng tanpa runtime sendiri (no DB/route/smoke). Kalau ternyata butuh DB/route/server → itu app; pakai `add-app`.
- **Consumer = nama app saja (v1).** Package yang dikonsumsi package lain di luar scope (treat sebagai internal). `consumers[]` diisi `fanout` saat package dipakai, BUKAN di sini (standalone add-package → consumers kosong).
- **Idempotent.** Package yang sudah ada di `packages[]` → STOP, jangan re-declare.
- **Tiap aksi side-effecting = GATE.** Tulis entri = gate sendiri; architect & wire pakai gate masing-masing.
- **Invarian platform tak di-relock.** Package = CONSUMER invarian (`invariants.md`), bukan pengunci. `architect` yang dipanggil add-package cuma RE-KONFIRMASI stack package tak ngelanggar invarian terkunci.

## Langkah (urut)

### 0. Baca state
Baca `control/workspace.yaml` (`topology` + `apps[]` + `packages[]`) + `control/conventions.md` + `control/invariants.md`. **Prasyarat:** `control/` ada — kalau nggak, arahin ke `init`. **Prasyarat invarian (BACKSTOP):** kalau `invariants.md` belum ada / masih ada slot `<belum dikunci>` → **STOP**, arahin ke `architect` "Kunci Invarian" dulu (bukan deadlock — sekadar arah-ulang; normalnya invarian sudah terkunci saat app pertama dibuat).

### 1. Cek duplikat (idempotent)
Kalau package `<nama>` sudah ada di `packages[]` → **STOP**, jangan re-declare.

### 2. Q&A identitas package (singkat — level DEKLARASI, bukan stack)
Tanya:
- `name` (kalau belum dari arg/usulan `fanout`)
- `responsibility`: satu kalimat (mis. "format dan hitung uang")
- (opsional) wajib dipakai app mana? → usulan `mandatory_for` (kosong kalau nggak wajib)

Derive `path` dari `topology`:
- **monorepo** → `packages/<nama>` (atau konvensi yang terbaca)
- **multi-repo** → `../<nama>` + minta `repo_url` (boleh kosong)

JANGAN tanya bahasa/build-tool/test-runner di sini — itu `architect` (langkah 4).

### 3. Tulis entri ke workspace.yaml (GATE)
Tambah entri package baru ke `packages[]`:
```yaml
  - name: <nama>
    path: <packages/<nama> | ../<nama>>
    repo_url: <isi untuk multi-repo, kosongkan untuk monorepo>
    type: package
    responsibility: "<ringkas>"
    consumers: []           # diisi fanout saat package dipakai
    mandatory_for: []       # app yang WAJIB pakai package ini; kosong = tidak wajib
    stack: {}               # diisi architect (langkah 4)
```
**Add-only-if-absent.** Tampilkan diff `workspace.yaml` → minta **approve**.

### 4. Invoke skill `architect` untuk package ini
`architect` mode-package (langkah 3c): Q&A teknikal (bahasa/build-tool/test-runner) → tulis `stack` package, rekam konvensi import/build ke `conventions.md`. Langkah "Kunci Invarian" (architect 4.5) TIDAK menanya/mengunci untuk package — cuma RE-KONFIRMASI stack package patuh `invariants.md` terkunci. Pakai gate-nya `architect`.

### 5. Invoke skill `wire` (mode-package) untuk package ini
`wire` mode-package (reference §I): scaffold skeleton lib (tool resmi stack) → register di workspace (pnpm-workspace/turbo/tsconfig paths). **Gate penutup = typecheck/lint hijau.** SKIP spin DB, ORM/migrate, wiring FE↔BE, smoke runtime. Pakai gate-gate `wire`.

### 6. Tutup & balikin
Lapor "**package `<nama>` siap dikonsumsi app**".
- Dipanggil `feature` (fitur butuh package baru) → balikin kontrol ke `feature` buat lanjut `plan`.
- Standalone → saranin langkah berikutnya (mis. `feature <fitur>`). `consumers[]` masih kosong; bakal diisi `fanout` saat package dipakai pertama kali.

## Catatan
- **Cara kanonik nambah package pasca-`init`.** `architect`/`wire` boleh jalan standalone, tapi yang **nulis entri package baru** cuma `add-package`.
- **Multi-repo:** `add-package` cuma nyatet `path` + `repo_url`. Pembuatan repo fisik di-defer ke `wire` + user (gated).
- **Beda dari `add-app`:** package TAK punya DB/route/server → tak ada `wire` DB/smoke; gate = typecheck. Selain itu polanya identik.
- TIDAK nyentuh `control/business/*` dan TIDAK nulis kode fitur (itu `build`).
