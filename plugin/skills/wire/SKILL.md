---
name: wire
description: Use untuk bring-up fondasi teknis produk SETELAH architect — scaffold app via tool resmi + nyalain DB + wiring FE↔BE + env standar jadi skeleton KOSONG-tapi-JALAN, semua di-GATE. Generic — baca stack dari workspace.yaml (apa pun framework/db/orm-nya), bukan daftar tetap. Greenfield (scaffold penuh) & brownfield (repair, idempotent). Trigger — "wire", "bring-up", "nyalain project", "scaffold skeleton". Jalankan dari root produk yang punya control/.
---

# wire — Bring-Up Fondasi (skeleton kosong-tapi-jalan)

Tujuan: ubah KEPUTUSAN `architect` jadi skeleton yang JALAN — app ter-scaffold (tool resmi), DB nyala & nyambung, FE↔BE ter-wire, env standar terpasang — KOSONG dari kode fitur. Setelahnya `feature`/`build` tinggal "bikin table + panggil API". Jalankan dari root produk (punya `control/`).

`architect` = WHAT (mutusin stack). `wire` = HOW TO RUN (instansiasi). `wire` **GENERIC**: jalanin apa pun yang architect putuskan (Next/SolidStart/Go/ClickHouse/Supabase/…), bukan daftar stack tetap.

> Detail (batas architect/wire, prosedur generik, DB managed vs bare-engine, env contract, smoke test, brownfield, multi-repo, pinjam mesin `build`) ada di `${CLAUDE_PLUGIN_ROOT}/skills/wire/reference.md` — baca itu dulu.

## Prinsip (jangan dilanggar)
- **Delegasi ke scaffolder resmi.** Jangan tulis kode framework sendiri — panggil tool resmi (`create-*`, `nest new`, `django-admin`, dll). `wire` cuma nulis GLUE (env, base URL, CORS, client).
- **Tiap aksi side-effecting = GATE.** Scaffold, bikin DB, migrate, tulis secret → tampilkan rencana + dampak → minta approve dulu. `migrate` JANGAN auto.
- **Generic, tapi jujur.** Stack mainstream → tahu command resminya. Stack langka → ajukan tebakan terbaik + GATE konfirmasi (atau lookup). JANGAN diam-diam salah.
- **Jangan mutusin arsitektur.** Engine/framework/orm = jatah architect. Keputusan LOGICAL hilang → balikin ke architect.

## Langkah (per app, urut; detail tiap langkah di reference)

### 0. Baca state & deteksi mode
Baca `control/workspace.yaml` (`apps[]`: path/type/stack/topology) + `control/conventions.md`. **Prasyarat:** architect sudah set `stack` logical (min framework + db + orm) per app; kalau belum → arahkan ke `architect`. Cek kode tiap `path`: kosong → **greenfield (scaffold penuh)**; ada kode → **brownfield (repair: lengkapi yang kurang, idempotent, jangan timpa)**.

### 0.5 Q&A operasional ("nutup architect")
Per app, tanya yang OPERASIONAL (bukan pilih arsitektur): DB bare-engine → **Docker lokal / URL remote?**; DB managed → minta creds (gated); package manager/runtime; nilai env/secret. Konfirmasi `stack` logical yang dibaca; field logical hilang/ambigu → STOP, balikin ke architect.

### 1. Scaffold app
Jalankan **tool resmi** framework (GATE sebelum eksekusi). Brownfield: lewati bila sudah ter-scaffold.

### 2. Nyalain DB
Sesuai hasil 0.5: bare-engine → spin Docker lokal (generate `docker-compose.yml`) / URL remote; managed → connect pakai creds (GATE). (reference C.)

### 3. Konek BE↔DB
Init ORM/driver (`stack.orm`), generate migrasi **baseline** (kosong dari table fitur), **apply** (GATE — migrate jangan auto), smoke query buktikan koneksi.

### 4. Wire FE↔BE
Fullstack → env + internal call; FE/BE kepisah → API base URL + CORS + (bila relevan) typed client. Ikut `conventions.md`. (reference A/B.)

### 5. Env standar
Tulis `.env` app (pastikan gitignored): DB_URL, API base URL, secret. Rekam SHAPE-nya (nama var + arti, tanpa nilai) ke `conventions.md`. Secret = GATE/manual. (detail env contract: reference D; action `env` pinjam build: reference H.)

### 6. Smoke test (GATE penutup)
Boot? DB kebaca? FE→BE nyampe? Ijo → tutup gate, laporkan "**app <x> siap di-`feature`**". Merah → STOP + lapor akar masalah (sandar `systematic-debugging`); JANGAN klaim siap. (reference E.)

## Catatan
- `wire` sekali jalan (kayak `extract`). Saat nambah app baru, dipanggil oleh skill `add-app` (yang chain `architect`→`wire`); bisa juga di-rerun manual. Brownfield: bersifat **repair** — hanya bila wiring belum lengkap.
- TIDAK bikin table/skema fitur — itu jatah `build`. `wire` cuma bikin pipeline migrasi BERFUNGSI + baseline.
- TIDAK nyentuh `control/business/*`. PR & merge = jatah pengguna/`ship`; cek branch dulu (jangan mulai di `main` tanpa izin).
