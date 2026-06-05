---
name: design-system
description: Use untuk bring-up FONDASI visual produk — turunin mockup awal jadi control/design-system.md (tokens + motion + komponen primitif) sekaligus bangun kode token+komponen primitif, semua di-GATE. Dua mode — SETUP (greenfield, dari mockup) dan CAPTURE (brownfield, dokumentasiin komponen existing). N design system per produk, di-scope per gaya visual (app mana se-vibe). Dipanggil feature saat fanout nandain app peran-UI belum-terdaftar, atau standalone. Generic — bahasa visual di-elicit, nol lock-in framework/CSS-lib. Trigger — "design-system", "bikin design system", "setup tokens", "bring-up komponen dari mockup". Jalankan dari root produk yang punya control/.
---

# design-system — Bring-Up Fondasi Visual (tokens + komponen primitif dari mockup)

Tujuan: ubah mockup awal jadi fondasi visual yang DURABLE — `control/design-system.md` (tokens + motion vocab + inventory komponen) + KODE token & komponen primitif — biar fitur UI berikutnya tinggal makai, gak nginvent ad-hoc tiap kali. `design-system` = konduktor tipis (kembaran `add-package`/`add-integration`), beda kunci: ia **bangun kode bertampilan** via atom dispatch Spec A, bukan cuma scaffold skeleton kosong. Jalankan dari root produk (punya `control/`).

`design-system` dibangun DI ATAS Spec A (mockup-thread, LIVE): atom "implementer melihat mockup & mereproduksinya dengan stack project" (`build/reference.md §B`) = mesin yang dipakai buat bangun primitif. A = steady-state (komponen udah ada → layout+animasi per-fitur); design-system = **bootstrap sekali-jalan** yang bawa project dari-0 ke kondisi steady-state itu.

> Detail (format `design-system.md`, elicit token+motion, atom dispatch + wadah app-local/package, gate, CAPTURE, scope N-design-system, persist mockup) ada di `${CLAUDE_PLUGIN_ROOT}/skills/design-system/reference.md` — baca itu dulu.

## Prinsip (jangan dilanggar)
- **Satu design system = satu gaya visual, di-scope ke app yang berbagi gaya.** BUKAN satu-paksa-semua-app. Web playful & admin plain = dua gaya, dua section.
- **Pengguna yang nentuin app mana se-vibe** — `design-system` NANYA ("gaya baru, atau ikut yang udah ada?"), gak nebak.
- **Mode dideteksi dari kode** (simetris `architect`): app kosong komponen → SETUP; udah ada → CAPTURE.
- **Generic.** Bahasa visual di-elicit dari mockup/kode; plugin gak pernah asumsi/nulis framework/CSS-lib. Stack dari `workspace.yaml`.
- **Tiap aksi side-effecting = GATE.** Tulis `design-system.md` = gate; bangun kode = gate (typecheck + eyeball); `add-package` (bila dipakai) pakai gate-nya sendiri.
- **Idempotent.** App yang udah diatur (cek `Berlaku buat`) gak di-bootstrap ulang. Re-run = no-op/repair.
- **Bukan komposit/page-level.** Scope = token + komponen primitif (Button/Input/Card/dst). Layout halaman = wilayah per-fitur Spec A.

## Langkah (urut)

### 0. Baca state & tentukan target
Baca `control/design-system.md` (section + `Berlaku buat` yang ada) + `control/workspace.yaml` (`apps[]`: type fe/be/fullstack, path, stack) + `control/conventions.md`. **Target** = app peran-UI yang **belum** diatur design system (dari arg standalone, atau dari `fanout.md` saat dipanggil `feature`). App backend-only / app yang udah diatur → SKIP.

### 1. Tentukan scope gaya (GATE keputusan)
Tanya pengguna: **gaya baru** (bikin design system baru) atau **ikut design system yang udah ada** (tambah app ke `Berlaku buat` section existing)? Gaya baru & user nyebut app lain se-vibe → scope = beberapa app. Hasil: nama design system + daftar app dalam scope. (reference §F.)

### 2. Deteksi mode per scope
Cek kode app-app dalam scope: semua kosong komponen → **SETUP** (3a); udah ada komponen → **CAPTURE** (3b); **campur** → app ber-komponen jadi sumber kanonik (reference §F).

### 3a. SETUP (greenfield) — persist mockup, elicit, bangun
- **Persist mockup (WAJIB):** simpan mockup verbatim (byte-opaque) ke `control/features/<f>/mockups/` LEBIH DULU — `design-system` jalan sebelum `plan`/Spec A, jadi ia penulis pertama folder ini; tanpa ini sesi fresh/resume kehilangan mockup (reference §G). Standalone tanpa mockup → minta dulu; user sengaja tanpa → ad-hoc/batal (degrade).
- **Elicit `design-system.md`** (judgment): turunkan tokens + motion vocab + inventory komponen dari mockup → tulis section (GATE approve). (reference §A/§B.)
- **Bangun kode**: token + komponen primitif via atom dispatch Spec A, ke wadah sesuai scope (app-local / package via `add-package`; carve-out `consumers[]`/`mandatory_for`). Gate = typecheck + eyeball. (reference §C/§D.)

### 3b. CAPTURE (brownfield) — dokumentasi-only
Baca komponen/token existing app dalam scope → konfirmasi user → tulis section `design-system.md` (inventory WAJIB; token/motion best-effort; JANGAN ngarang). **TIDAK** generate kode. GATE approve `.md`. (reference §E.)

### 4. Tutup & balikin
Lapor "**design system `<nama>` siap; app `<scope>` bergaya `<nama>`**".
- Dipanggil `feature` → balikin kontrol ke `feature` buat lanjut `plan` (fitur konsumsi primitif fresh; Spec A handle layout+animasi).
- Standalone → saranin langkah berikutnya (mis. `feature <fitur>`).

## Catatan
- **Cara kanonik bring-up design system.** `architect` mutusin stack + "lib kunci"; `design-system` yang nangkep BAHASA VISUAL + bangun primitif — beda concern.
- **Dipanggil `feature`** saat `fanout` nandain `DESIGN-SYSTEM NEEDED` (app peran-UI belum-terdaftar), atau **standalone**. Simetris dua-mode dengan `architect`/`wire`.
- TIDAK nyentuh `control/business/*`; TIDAK nulis kode FITUR (itu `build` per-fitur — `design-system` cuma fondasi primitif). PR & merge = jatah pengguna/`ship`; cek branch dulu.
