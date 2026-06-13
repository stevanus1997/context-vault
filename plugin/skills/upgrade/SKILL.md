---
name: upgrade
description: Use untuk menyusulin produk LAMA (di-init pakai versi plugin sebelumnya) ke template terbaru — sinkron file scaffolding kubu-plugin (.claude/ hooks+drive.sh+settings, control/ skeleton yang HILANG) tanpa menyentuh knowledge. Idempoten, presence-based, GATE tiap tulis. BUKAN untuk produk baru (init terbaru sudah lengkap). Trigger — "upgrade", "sync template", "produk ketinggalan versi plugin", "aktifin unattended di produk lama". Jalankan dari root produk yang punya control/.
---

# upgrade — Susulin produk ke template terbaru (migrasi versi)

Tujuan: produk yang di-`init` pakai plugin versi LAMA ketinggalan file scaffolding yang ditambah versi baru (mis. `.claude/hooks/`, `drive.sh`, blok `hooks` di `settings.json`, file `control/` baru seperti `invariants.md`/`risks.md`). `upgrade` menyusulinnya — **hanya file kubu-plugin**, **tanpa pernah menyentuh knowledge/customisasi produk**. Produk BARU tak perlu ini (`init` terbaru sudah menyalin semua).

> `init` = bikin produk (sekali). `upgrade` = susulin produk yang SUDAH ada ke template terkini (kapan saja, idempoten). BUKAN re-init / re-wire.

## Prinsip (jangan dilanggar)
- **Idempoten + presence-based.** Cek KEBERADAAN tiap elemen template terkini; yang ADA & current → skip; yang HILANG/ketinggalan → susulin. Jalan berkali-kali aman (produk current = no-op). Tak butuh stempel versi (cek file nyata, bukan nebak nomor).
- **Pisahkan dua kubu — haram salah sentuh:**
  - **Kubu PLUGIN (boleh disusulin):** `.claude/hooks/*.sh`, `.claude/drive.sh`, bagian template `settings.json` (baseline `allow`/`deny` + blok `hooks` + perintah verifikasi per-stack), template `control/` skeleton.
  - **Kubu PRODUK (HARAM disentuh):** semua `control/*` yang SUDAH ADA (knowledge: `workspace.yaml`/`business/`/isi `invariants.md`/`tasks.yaml`/`feature.yaml`/…), `.claude/CLAUDE.md`, `.claude/notify.sh` (secret user), `.env`, kode.
- **Tiap tulis = GATE.** Tampilkan apa yang mau disusulin/di-merge → approve dulu.
- **Merge, bukan timpa, untuk file campuran.** `settings.json` & `.gitignore` di-MERGE (pertahankan entri custom user, tambah yang kurang, dedup). File generik murni (hooks/drive.sh) boleh diganti versi terkini (GATE + tampilkan diff bila beda).
- **`control/`: tambah-yang-HILANG saja.** File template `control/` yang absen di produk → tambahkan (ganti placeholder `<PRODUCT>`). File yang SUDAH ADA → JANGAN sentuh (itu knowledge milik skill lain).

## Prasyarat
- Jalankan dari root produk yang punya `control/`.
- **Tanpa `control/`** → bukan produk context-vault (atau belum init) → arahkan `/init`, STOP. (`upgrade` menyusulin produk yang SUDAH ada, bukan bikin baru.)

## Alur

### 1. Deteksi selisih (read-only dulu)
Bandingkan produk vs `${CLAUDE_PLUGIN_ROOT}/template/`:
- `.claude/hooks/on-stop.sh`, `on-permission.sh` — ada? executable?
- `.claude/drive.sh` — ada? executable?
- `.claude/settings.json` — punya `permissions.allow` baseline (git read-only + `add`/`commit`)? `permissions.deny` foot-gun (force-push/reset --hard/clean/rm -rf)? blok `hooks` (`Stop` + `PermissionRequest`)? perintah verifikasi per-stack (test/lint/typecheck/build sesuai `workspace.yaml` `stack`)?
- `.gitignore` — punya `.claude/notify.sh` + `.claude/.unattended*`?
- `control/` — file/dir template mana yang ABSEN di produk (mis. `invariants.md`, `integrations.md`, `design-system.md`, `business/risks.md`, `debt.yaml`, `fixes/`)? (CATATAN: `control/schema/` di-generate runtime oleh `wire`/`build` dari skema nyata — BUKAN skeleton template; jangan disync di sini.)
Susun **daftar selisih** + tampilkan ke user (apa yang akan disusulin, apa yang di-skip karena sudah-ada/itu-knowledge). Tak ada selisih → "produk sudah current" + STOP.

### 2. Sinkron `.claude/` (GATE)
- **hooks/ + drive.sh** hilang → copy dari template + `chmod +x`. Ada tapi beda → tampilkan diff, GATE ganti (file generik plugin).
- **`settings.json`** → MERGE: union baseline `allow` + `deny` + blok `hooks` ke yang ada (dedup, pertahankan entri custom user — JANGAN buang); lalu derive + tambah **perintah verifikasi per-stack** dari `workspace.yaml` `stack` (logika `wire` step 5.5: HANYA baca/verifikasi — test/lint/typecheck/build; JANGAN push/deploy/apply-migrate/`rm`/jaringan-tulis). Tampilkan hasil merge → approve. File absen → copy utuh dari template lalu lanjut derive per-stack.
- **`.gitignore`** → append baris yang kurang (`grep -qxF` dulu; idempoten).

### 3. Sinkron `control/` skeleton (GATE — tambah-yang-hilang)
Untuk tiap file/dir template `control/` yang **ABSEN** di produk: tambahkan (copy + ganti `<PRODUCT>` dengan nama produk dari `workspace.yaml`, seperti `init` step 4). File yang **SUDAH ADA**: SKIP — jangan baca/tulis (itu knowledge milik skill pemiliknya). Ini cuma skeleton kosong; ISI-nya tumbuh lewat skill pemilik (`architect`/`feature`/`add-integration`/…), BUKAN `upgrade`.

### 4. Ringkas (GATE penutup)
Laporkan: disusulin apa, di-merge apa, di-skip apa (+ alasan). Saran langkah lanjut:
- Notif unattended belum diset → "jalankan `build <fitur> --unattended` sekali **interaktif** untuk set `notify.sh`" (Q&A first-unattended cuma bisa di sesi interaktif, bukan headless `drive.sh`).
- File `control/` baru lahir kosong (mis. `invariants.md`) → arahkan skill pemiliknya (`/architect` dll) untuk mengisinya.

## Guardrails
- **Nol sentuh knowledge.** Tak pernah Edit/timpa file `control/` yang sudah ada, `CLAUDE.md`, `notify.sh`, `.env`, kode. Cuma TAMBAH file plugin yang hilang + MERGE settings/gitignore.
- **Bukan re-init/re-wire.** Tak men-scaffold app, tak nyalain DB, tak nyentuh stack/arsitektur. Cuma nyamain file scaffolding template.
- **Anti-ngarang versi.** Presence-based (cek file nyata), bukan nebak dari nomor versi — jalan walau produk tak punya stempel versi.
- **Aman diulang.** Jalan ke produk yang sudah current = no-op (semua elemen sudah ada).

## Catatan
- Produk BARU (di-`init` versi terkini) sudah lengkap → `upgrade` no-op. Skill ini KHUSUS migrasi produk yang di-init versi lama.
- Jalur maintenance resmi: tiap kali plugin nambah file template ke depan, `upgrade` cara nyusulin produk existing (punya sendiri & user lain) tanpa re-init.
