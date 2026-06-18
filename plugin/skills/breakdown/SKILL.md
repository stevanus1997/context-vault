---
name: breakdown
description: Use untuk memecah plan flat sebuah fitur (status active) jadi tasks.yaml — daftar task kecil berurutan (files + approach + test cases, TANPA kode) yang nanti dieksekusi build. Trigger — "breakdown <fitur>", "pecah task <fitur>", "bikin tasks <fitur>". Jalankan dari root produk yang punya control/.
---

# breakdown — Plan Flat → Task List (`tasks.yaml`)

Tujuan: ubah `plans/*.md` (flat) jadi rencana kerja siap-eksekusi: task kecil, berurutan, ber-dependency, dengan `files` + `approach` + kasus `test` — TANPA kode. Output dimakan `build`. Jalankan dari root produk (punya `control/`).

> Skema lengkap `tasks.yaml` + aturan granularitas + contoh ada di `${CLAUDE_PLUGIN_ROOT}/skills/breakdown/reference.md` — baca itu dulu.

## Langkah

### 1. Baca input
Baca `control/features/<fitur>/plans/_shared.md` + `plans/<pkg>.md` + `plans/<app>.md` + `fanout.md` (untuk Urutan lintas-app) + `control/workspace.yaml` (app/path/stack + `packages[]`/`consumers`) + `control/schema/<app>.md` (proyeksi skema durable per app — baseline tabel existing, read-only; absen/stub → degrade, lihat step 3). **Prasyarat:** `feature.yaml` `status: active`. **Validasi unit (GATE eksplisit):** tiap `task.unit` HARUS cocok `apps[].name` ATAU `packages[].name` ATAU `integration`; kalau tidak → STOP + saran (`add-app`/`add-package`/typo). (Dulu kendala ini laten → gagal telat di `build`; sekarang dicek di depan.) Bila belum, hentikan & arahkan ke `feature`/`plan`. (Boleh mengintip ringan struktur kode untuk menakar granularitas; baca-kode mendalam = jatah `build`.)

### 2. Iris milestone + task
Iris jadi **milestone** (slice logis: fondasi dulu, turunan menyusul) lalu **task** di dalamnya. Granularitas: **satu task = unit testable terkecil**. Rasionalisasi hierarki fitur (mis. "register by google" = flow OAuth yang sama dengan "login by google" → satu milestone OAuth per provider).

### 3. Enrich tiap task
Isi tiap task: `files` (path create/modify/test — WHERE), `approach` (1-2 baris HOW ringkas), `test` (daftar kasus yang harus lulus — WHAT). **Kerja non-file** (migrasi DB, `npm install`, wiring env/secret, perintah infra) → taruh di **`actions:`** (jangan kubur di `approach`). **Langkah yang AI nggak bisa** (bikin OAuth app, set secret prod, provision DB) → **`manual:`**. **JANGAN tulis kode implementasi** — itu jatah `build`. `breakdown` **TIDAK** memanggil `writing-plans`. (Skema actions/manual: `reference.md` §A & §D.)

**Reuse-aware (sebelum nulis `files`):** untuk task yang nyentuh data/file, konsultasi `control/schema/<app>.md` (tabel existing) + lirik ringan dir target (file existing). **Transkripsi** verdict `Model/Schema` `plans/<app>.md` (reuse `<Tabel>` vs NEW) ke task: padanan existing → `files: modify` (bukan `create`) + isi `reuse: [table: <T>, file: <f>]` (NAMA-only, `reference.md` §B). `breakdown` MELIHAT dir untuk memutuskan path mana di-extend, tapi **TIDAK mencatat listing dir** ke `tasks.yaml` (listing disuntik LIVE oleh `build`, D1). Default condong extend/modify bila ada padanan; ragu (verdict plan tak jelas) → balik `plan`, jangan diam-diam `create`. Degrade: `control/schema/<app>.md` absen/stub → lewati konsultasi tabel (tetap lirik dir), no-op.

### 4. Coverage check + task integrasi
- **Coverage:** tiap keputusan `_shared.md` ("env yang dibagi", mekanisme) & tiap baris Model/Schema di `plans/<app>.md` HARUS ke-map ke sebuah task/`action`/`manual` — jangan ada yang menguap. Tampilkan peta plan→task di gate.
- **UI coverage (mockup→task):** tiap file mockup yang dirujuk `plans/<app>.md` (baris `Mockup:`) WAJIB ke-map ke ≥1 task ber-`mockup:`. Tampilkan **peta mockup→task** di gate (di samping peta plan→task) — biar tak ada layar yang kelupaan jadi task.
- **UI-Contract coverage:** bila `plans/<app>.md` punya section `UI-Contract`, tiap entri (field/actions/states) SEBAIKNYA ke-cover ≥1 task. Tampilkan **peta UI-Contract→task** di gate (di samping peta plan→task & mockup→task). **Tampil-di-gate, BUKAN palang** (sejajar coverage Model/Schema) — selisih disodorkan ke user, tak memblokir.
- **Utang yang dilunasi:** untuk tiap utang yang ditandai-dilunasi di `plans/*` (baris "Utang dilunasi: `<id>`" yang ditulis `plan` lewat `rules/debt-aware.md`), munculkan satu task `kind: debt, pays_debt: <id>` (refactor — jaga perilaku TETAP sama, `test` = kasus regresi yang membuktikan perilaku tak berubah). `unit` = app pemilik area utang.
- **Task integrasi:** untuk tiap dependency lintas-app INTERNAL (app↔app / package↔consumer) di `_shared.md`/`fanout.md`, munculkan satu task `unit: integration` (`deps` ke KEDUA sisi, `test` = roundtrip end-to-end). **BUKAN baris kontrak vendor yang dipromote `plan` §2c** (itu app↔vendor eksternal — ditangani "Inbound-eksternal coverage" di bawah pada `unit: <Receiver app>`, atau task outbound app pemanggil; vendor bukan unit, jadi `deps`-nya tak resolvable sebagai pseudo-unit `integration`). Fitur 1-app tanpa `_shared.md` → skip.
- **Invarian:** tiap task yang nyentuh skema/endpoint patuh `control/invariants.md` (mis. table baru bawa `tenant_id` bila tenancy shared-db; uang pakai representasi yang dikunci)? Tandai task yang berisiko melanggar. **Mandatory package (M2):** task yang bikin logika yang seharusnya pakai package di `packages[].mandatory_for` → tandai melanggar (redirect ke package).
- **Reuse-before-create (advisory — cermin Invarian di atas).** Tiap task skema **sebut NAMA tabel/file existing yang di-extend** (`reuse:`). Flag task yang usul **tabel/file BARU yang entitas-nya overlap existing** di `control/schema/<app>.md` / dir target (mis. task bikin `users` padahal `users` ada; bikin `users.go` padahal `user.go` ada) → minta justify atau redirect ke reuse. Tampilkan **peta reuse→task** di gate (di samping peta plan→task). **Tampil-di-gate, BUKAN palang** (sejajar coverage Model/Schema) — selisih disodorkan ke user, tak memblokir.
- **Fan-IN coverage:** kalau `plans/<pkg>.md` ber-flag `BREAKING`, tiap consumer di `packages[<pkg>].consumers` WAJIB punya ≥1 task (update-task `unit: <consumer>` atau ter-cover task `unit: integration`). (Skema fan-IN: `reference.md` §D-4.)
- **Inbound-eksternal coverage:** tiap baris "kebutuhan receiver" di `plans/<Receiver app>.md` (vendor inbound) WAJIB jadi task `unit: <Receiver app>` varian inbound-eksternal (verifikasi signature + idempotent + replay, test keamanan baku). (Skema: `reference.md` §D-5.)

### 5. Urutan & dependency
Tentukan `deps` tiap task dari: kontrak `_shared.md` (fondasi paling dulu), Urutan `fanout.md` (lintas-app, mis. `api` sebelum `web`), dependency logis intra-app.

### 6. Critic (opsional)
Untuk fitur besar/berisiko, invoke subagent `critic` atas peta task: urutan keliru? milestone kegedean? dependency kelewat?

### 7. Tulis output (GATE)
Tulis `control/features/<fitur>/tasks.yaml` sesuai skema reference, semua `status: pending`. **Bila `tasks.yaml` sudah ada (re-breakdown):** JANGAN timpa buta jadi semua-`pending`. Untuk task ber-`id` sama, **pertahankan `status`** (`done`/`in_progress`/`blocked`); ubah `files`/`approach`/`test` hanya bila plan-nya berubah; tambah task baru sebagai `pending`. **Pertahankan task `kind: fix` dan `kind: debt`** (corrective dari lane `fix`/disiplin embed `build`; atau pelunasan utang teknis ber-`pays_debt`) yang **tak punya asal-`plan`** — JANGAN buang saat regenerate dari plan (kalau dibuang, bug yang sudah di-fix bisa ter-regress diam-diam, dan utang yang sudah dijadwalkan jadi hilang dari tracking). **Pertahankan metadata `reuse:`** (nama tabel/file existing yang di-extend) untuk task ber-`id` sama selama keputusan plan tak berubah — sejajar `status`/`kind`/`mockup:`; kalau dibuang saat re-breakdown, keputusan reuse hilang & build balik bikin tabel/file duplikat (failure mode yang fitur ini cegah). Task `kind: fix`/`kind: debt` ikut dipertahankan statusnya seperti task `done`/`in_progress` lain. Bila ada task `done` yang plan asalnya berubah, **tandai perlu-rebuild & BERHENTI minta konfirmasi** sebelum nulis (jangan diam-diam buang progres `build`). Tampilkan **PETA TASK** (milestone × unit × task + `deps` + `files` + kasus `test`) → minta **approve/koreksi**. Di gate ini pengguna belum melihat kode — hanya menyetujui rencana kerja. Murah & cepat.

## Catatan
- Output = input `build`. JANGAN nulis kode di sini.
- `tasks.yaml` `status` jadi sumber progres + mekanisme resume `build`.
- `plan` tetap flat; `breakdown` yang menambah struktur task.
