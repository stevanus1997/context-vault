# Schema & Structure Awareness pada `build` — Design Spec

> Status: **DRAFT** (menunggu review user → lanjut `writing-plans`)
> Tanggal: 2026-06-18
> Area kena: `breakdown`, `build`, `plan`, `wire`, `upgrade`, `rules/migration-impact.md`, `template/control/conventions.md`
> Sifat: editan prompt/markdown skill (bukan kode runtime). Nol palang keras baru — semua advisory/show-at-gate, selaras filosofi degrade-friendly + context-hemat + resumable yang sudah ada.

---

## 1. Masalah

Feedback lapangan: kode **backend** hasil `build` berkualitas jelek dalam 3 gejala spesifik:

1. **Gak aware tabel existing** → bikin tabel baru yang redundant (mis. `user_profiles` padahal harusnya kolom di `users`).
2. **Gak aware file/struktur existing** → bikin file duplikat (mis. `internal/users/users.go` padahal `internal/user/user.go` udah ada).
3. **Query jelek** → gak reuse query-layer/repository existing, gak sadar index, rawan N+1.

Muncul di produk **brownfield** (DB sudah ada banyak tabel) maupun **greenfield** (schema tumbuh bertahap).

## 2. Akar masalah (dari diagnosis 2026-06-18)

Sumber kebenaran skema **sudah ada dan durable** — `control/schema/<app>.md`, ditulis tunggal oleh `rules/schema-projection.md`, lahir saat `wire` baseline-migrate, di-regen `build` tiap habis task `migrate`. **Tapi proyeksi itu tidak pernah sampai ke agen yang menulis kode.**

Jejak putusnya rantai:

| Fase | Pegang skema existing? | Bukti |
|---|---|---|
| `plan` | ✅ Ya | `plan/SKILL.md:39` — baca `control/schema/<app>.md` dulu sebagai baseline |
| `migration-impact` (gate migrate) | ⚠️ Baca, tapi sempit | `migration-impact.md:9,15-19` — tabel baru diklasifikasi "additive → aman" (`:22`), gak pernah dibanding ke existing |
| `breakdown` | ❌ Tidak | `breakdown/SKILL.md:15` input = `plans/*`+`fanout`+`workspace.yaml`; nol referensi `control/schema/` |
| `build` (controller) | ❌ Tidak | `build/SKILL.md:14` step-1 read-set gak masuk `control/schema/`; cuma dipakai sebagai **output** (regen pasca-migrate, `:34`) |
| `build` → **implementer subagent** | ❌ Tidak | `build/reference.md §B (17-27)` daftar lengkap prompt — **nol item skema**; `:13` "subagent TIDAK membaca file plan" |

### 2b. Akar yang lebih dalam — rigor jatuh di celah split writing-plans

context-vault sengaja men-split alur superpowers `writing-plans` (plan monolitik berisi kode) jadi **`breakdown` (struktur/task, tanpa kode) + `build` (kode lawan kode-hidup)** — keputusan yang **benar** untuk produk hidup-lama (kode di plan cepat basi; `breakdown` bisa di-jalankan ulang & pertahankan status task, `breakdown/SKILL.md:40`).

Tapi `writing-plans` menjamin correctness lewat **dua** mekanisme, dan keduanya terpisahkan:
- **Kode di-front-load** (rawan basi) → context-vault **benar** menolaknya. Jangan dibalikin.
- **Disiplin "File Structure"** (`writing-plans/SKILL.md:26-34`: petakan file yang dibuat/diubah + tanggung jawabnya, *"follow established patterns"*, *"this is where decomposition decisions get locked in"*) → **ikut terbuang**, padahal ini **tidak ada hubungannya dengan kode**.

`breakdown` membuang disiplin struktur ini (jadi `files` = path telanjang, `reference.md:52`); `build` tidak pernah mengambilnya. **Rigor-nya menguap di celah.** Lebih parah: taruhan "build menulis lawan konteks-hidup" **tidak pernah didanai** — build cuma menyodorkan 1-2 "pointer pola" (`build/reference.md:24`), bukan skema/struktur.

**Kesimpulan:** ini **context-delivery gap**, bukan "model malas" atau "breakdown sloppy di satu fitur". Kambuh di **setiap** fitur BE. Fix = selesaikan utang delivery + kembalikan disiplin struktur ke breakdown — **tanpa** mengembalikan kode ke plan.

## 3. Prinsip desain (poros)

**Arsitek → Mandor → Tukang.** Denah (skema + struktur existing) harus mengalir utuh: arsitek memutuskan → mandor menyodorkan → tukang mengeksekusi. Putus di mana pun = rumah salah.

- **`breakdown` = arsitek** → memegang **KEPUTUSAN** reuse-vs-create (tabel & file) + tanggung jawab struktur. **Durable, bukan kode.** (Keputusan "reuse tabel `users`" tidak basi seperti kode basi.)
- **`build` (controller) = mandor** → **MENGANTARKAN** baseline (slice skema + listing dir) ke prompt implementer.
- **implementer subagent = tukang** → menulis kode lawan realita yang sudah disodorkan.
- **gate/review = QC** → menjaring drift kalau masih lolos.

Pembagian by sifat-data:

| DURABLE (gak basi) → `breakdown` | VOLATILE (cepat basi) → live di `build` |
|---|---|
| Keputusan reuse-vs-create (tabel & file) | Kode implementasi |
| Tanggung jawab file / struktur | Signature dep (build baca live dari disk) |
| `reuse:` (tabel/file yang di-extend) | Detail API/skema terkini |

**Invariant yang dijaga:**
- Nol kode di `tasks.yaml` (garis batas tegas — masukin kode = impor balik staleness yang bikin kita tinggalin writing-plans).
- Nol palang keras baru — semua advisory + show-at-gate (sejajar invariants check & migration-impact yang sudah advisory).
- Degrade no-op kalau proyeksi absen/stub (jangan crash; selaras `schema-projection.md:15`).
- Context-hemat: yang disuntik = **proyeksi ringkas** (1 baris/tabel) + listing dir, **bukan** kode/migrasi penuh — jaga sesi build ramping & resumable (`build/SKILL.md:8,55`).

## 4. Desain detail

Dua poros co-equal (D1 build-delivery + D2 breakdown-decision) plus 4 penopang (D3-D6). **Tidak ada yang bisa dibuang** dari D1/D2; keduanya load-bearing.

### D1 — `build` mengantarkan baseline ke implementer (poros: mandor) — HIGH

**Target:** `build/reference.md §B`, `build/SKILL.md` step 1 & step 3.

- **Read-set step 1 (+):** controller baca `control/schema/<unit>.md` **per-task, lazy** — hanya slice yang akan di-paste untuk task berjalan (bukan load penuh semua unit di depan), supaya sesi build tetap ramping & resumable (`build/SKILL.md:8,55`).
- **Rakitan prompt step 3 (+):** sisipkan **blok baru** di antara "Konvensi & stack" dan "Pointer pola" (`build/reference.md §B`), untuk task ber-`unit ∈ apps[]` yang punya `control/schema/<unit>.md` non-stub. Blok berisi:
  1. **Slice skema relevan** — dihitung **fail-open UNION, dibaca LIVE di build**: tabel di `reuse:` ∪ tabel di `actions.affects` ∪ FK-neighbor live (dari `control/schema/<unit>.md`) dari tabel mana pun yang disebut keduanya; di-cap ambang ~15 tabel. **`reuse:` = SELECTION HINT, bukan filter otoritatif** — over-include murah & aman, under-include malah ngalahin tujuan D1; jadi `reuse:` basi/parsial **tidak fatal** (mis. worked-example: `reuse:[users]` vs `affects:[users, users.display_name, …]` → union tetap nge-cover `users`). Format ringkas proyeksi (kolom·tipe·key·FK).
  2. **Listing dir target** — daftar file yang sudah ada di tiap dir pada `files` task (mis. `internal/user/` → `user.go, repo.go, session.go`). **Di-cap ~30 entri** (lebih → ringkas + hitung) biar dir gede tak membanjiri prompt.
  3. **Directive:** *"Tabel & file ini SUDAH ADA — reuse/extend; JANGAN bikin tabel paralel atau file duplikat (mis. ada `user.go` → tambahin di situ, bukan `users.go`). Fakta kolom/FK/index di sini otoritatif."*
- **Degrade:** `control/schema/<unit>.md` absen/stub → blok jadi listing-dir saja + warning; tetap lanjut (no-op pada bagian skema).
- **Scope otomatis:** file proyeksi cuma ada untuk app dengan sumber skema → FE/package/`integration` tidak kena tanpa deteksi rapuh.

### D2 — `breakdown` transkripsi verdict reuse + putuskan struktur file (poros: arsitek-pelaksana) — HIGH

**Target:** `breakdown/SKILL.md` step 1, step 3, step 4, **step 7**; `breakdown/reference.md §A`.

- **Presedensi keputusan (penting):** verdict **reuse-vs-NEW level tabel/data-model** dipegang `plan` (D5 — `plan` memang pemilik data-model). `breakdown` **MENTRANSKRIPSI** verdict tabel itu ke struktur task (`reuse:` + `files: modify` vs `create`) dan **MEMUTUSKAN sendiri di level file/struktur task** (file mana di-extend). `breakdown` **tidak memutuskan ulang** verdict tabel; bila baseline skema bikin ragu → **balik ke `plan`**, jangan diam-diam `create`. (Framing "arsitek" tetap utuh, dua altitude: `plan` = arsitek data-model, `breakdown` = arsitek struktur-task/file.)
- **Read-set step 1 (+):** tambah `control/schema/<app>.md`.
- **Step keputusan (BARU, sisip di enrich step 3):** untuk tiap task yang nyentuh data/file — sebelum menulis `files`, konsultasi `control/schema/<app>.md` (tabel existing) + lirik ringan dir target (file existing). `breakdown` **MELIHAT** dir untuk memutuskan path mana di-extend, tapi **TIDAK mencatat listing dir** ke `tasks.yaml` (listing disuntik live oleh `build`, D1). Default condong **extend/modify** kalau ada padanan existing.
- **Field baru `reuse:` (opsional, di skema `tasks.yaml`, `reference.md §A`) — NAMA-ONLY:**
  ```yaml
  reuse:                          # keputusan durable (BUKAN kode)
    - table: users                #   extend tabel ini, jangan bikin baru
    - file: internal/user/user.go #   extend file ini, jangan bikin duplikat
  ```
  **Batas tegas (cermin `reference.md:52` "files = path saja"):** `reuse:` = **NAMA saja** (tabel/file) + verb implisit extend|create. **JANGAN catat kolom/signature/SQL/line-range** — itu VOLATILE, dibaca live oleh `build` dari `control/schema/` + disk. WHY-reuse tinggal di **eksistensi proyeksi**, bukan di `tasks.yaml`.
  **Preservasi (mekanisme EKSPLISIT, bukan analogi):** D2 menulis `reuse:` ke daftar metadata yang dipertahankan saat re-breakdown di `breakdown/SKILL.md` **step 7** (sejajar `status`/`kind`/`mockup:`) + klausa cermin di `reference.md §A` (ikut pola `mockup:` di `reference.md:177`). Tanpa klausa tertulis ini, re-breakdown setelah plan berubah bakal diam-diam buang keputusan reuse — persis failure mode yang spec ini ada untuk cegah. `build` mem-paste `reuse:` ke prompt (numpang mekanisme paste teks task yang sudah ada).
- **Coverage check step 4 (+):** baris advisory **"reuse-before-create"** (cermin invariants check `breakdown/SKILL.md:29`): tiap task skema **sebut NAMA tabel/file existing yang di-extend**; flag task yang usul **tabel/file baru yang entitas-nya overlap existing** → minta justify atau redirect ke reuse. **Tampil di gate, BUKAN palang.**

### D3 — Slot konvensi Query & Data-Access — MED

**Target:** `template/control/conventions.md`.

Tambah section `## Konvensi Query & Data-Access` (sibling Package/Integrasi/Migrasi) untuk `architect` rekam: pola repository/data-access-layer (reuse modul query existing vs raw SQL), index/unique di kolom lookup, ekspektasi no-N+1/batch-load, default pagination. Karena `conventions.md` di-paste ke **tiap** prompt implementer (`build/reference.md:23`), ini rumah durable buat disiplin query + default fallback. (Slot kosong = degrade no-op.)

### D4 — Jaring redundant-table/file + query di gate & review — MED

**Target:** `build/SKILL.md` step 6 (challenge checklist), reviewer prompts (`build/reference.md §A`).

- Tambah ke challenge checklist step 6:
  1. *"Ada `CREATE TABLE` di diff yang duplikat tabel di `control/schema/<unit>.md`?"*
  2. *"Ada file baru yang duplikat file existing (mis. `users.go` vs `user.go`)? `reuse:` task dihormati?"*
  3. *"Data-access reuse repo/query-layer existing & hindari N+1/lookup tak-terindeks?"*
- Beri **spec-reviewer & code-quality-reviewer** slice `control/schema/<unit>.md` + listing dir yang disentuh, sebagai baseline deteksi redundansi.
- **Selaras unattended (M7):** ini melengkapi challenge checklist yang sudah ada, bukan floor baru — tidak mengubah cadence/floor-scan; sejajar item invariant/mandatory-package/mockup yang sudah di step 6.

### D5 — `plan` paksa keputusan reuse-vs-new + fallback stub — MED

**Target:** `plan/SKILL.md` step 3 & template step 4.

- Slot `Model/Schema` (slot di template langkah 4, `plan/SKILL.md:53`) wajib nyatakan per kebutuhan data: **"reuse tabel X"** vs **"NEW (justify) + `actions:migrate`"**, dibanding ke baseline `control/schema/<app>.md`. (H3/`migration-impact` sekarang cuma nyala untuk ALTER tabel fitur lain, `:40` — ADD redundant tak terjaring di gate plan.)
- **Sumber tunggal verdict tabel:** keputusan reuse-vs-NEW level tabel di sini = otoritatif; `breakdown` (D2) **mentranskripsi** ke `reuse:`, tidak memutuskan ulang. (Cegah dua sumber kebenaran yang diam-diam bentrok.)
- **Fallback:** `control/schema/<app>.md` absen/stub padahal app jelas ber-DB → paksa inventory ORM/migrasi nyata (atau invoke `schema-projection`) alih-alih menganggap kosong = otoritatif.

### D6 — Seed brownfield (krusial untuk repo lama) — MED

**Target:** `wire` (jalur brownfield repair) **SAJA**.

Untuk tiap app dengan sumber skema (ORM **atau** folder migrasi raw-SQL) yang `control/schema/<app>.md`-nya belum ada/stub: **invoke `rules/schema-projection.md`** (label `(pra-M4)`/baseline) untuk seed dari **sumber existing** (`schema-projection.md:16` baca file skema/migrasi *by-understanding, TANPA DB hidup*). Bukan mekanisme baru — memanggil prosedur yang sudah ada (hormati single-writer: hanya `wire`/`build` boleh invoke, `schema-projection.md:5-6`). **Idempoten** (re-run = no-op kalau sudah ada). Menutup lubang "proyeksi kosong di repo lama" → bikin D1/D2/D5 berguna di brownfield.

- **Presence-based, BUKAN status-wired:** seed di-gate pada **KEBERADAAN** `control/schema/<app>.md` (absen/stub → seed), **bukan** pada status ter-wire app. Jadi app yang **sudah ter-wire tapi proyeksinya belum lahir/stub TETAP di-seed** (sejajar sifat repair "lengkapi yang kurang, idempotent", `wire/reference.md §F:52`). Tanpa ini, app already-wired bakal lewat (step-3 wire = no-op) dan stub-nya nyampe ke build — ngalahin D1/D2/D5 persis di tempat paling penting.
- **`stack.orm` absen + tak ada folder migrasi** → tulis stub + **warning** (app uncovered), bukan no-op diam (jangan nutupin gap). `wire` sudah nge-gate `architect` set stack (`wire/SKILL.md:23`), jadi prasyarat ini natural terpenuhi di jalur wire.
- **`upgrade` TIDAK nge-seed** (charter nol-sentuh-knowledge; `control/schema/` runtime-generated, `upgrade/SKILL.md:33`). Bila produk lama butuh seed → `upgrade` cukup **ARAHKAN** user jalankan `wire` (pola arahkan-skill-pemilik yang sudah ada, `upgrade/SKILL.md:49`).

### Dimensi file-level (dilebur ke D1+D2+D4, bukan fix terpisah)

Redundansi **file** (`users.go` vs `user.go`) = sibling redundansi tabel; akar sama (penulis & reviewer tak punya baseline "apa yang sudah ada"). Diselesaikan dengan: `reuse: [file: ...]` (D2), listing-dir di prompt (D1), cek redundant-file di gate (D4). Prinsip seragam: **inject existing schema + existing files di area yang disentuh.**

## 5. Worked example (skenario `user.go` / tabel `users`)

Repo brownfield, app `api` (Go + Postgres). Existing: `internal/user/user.go` + tabel `users`. Fitur: "profil — display name + avatar".

**Tanpa fix:** `breakdown` baca `plans/api.md` (bukan `control/schema/`) → nebak `create: internal/users/profile.go` + `migrate: create table user_profiles`. `build` dispatch tanpa sinyal existing → implementer bikin file & tabel baru. Gate tanpa baseline → lolos. **Hasil:** `user_profiles` (harusnya kolom di `users`) + `internal/users/` (harusnya `internal/user/`).

**Dengan fix:**
1. **breakdown (D2):** baca `control/schema/api.md` (`users` ada) + lirik `internal/user/` (`user.go` ada) → putuskan extend. `tasks.yaml`:
   ```yaml
   - id: T1
     unit: api
     desc: Tambah display_name + avatar_url ke profil user
     reuse:
       - table: users
       - file: internal/user/user.go
     files:
       - modify: internal/user/user.go      # modify, bukan create
       - modify: internal/user/repo.go
       - test:   internal/user/user_test.go
     approach: tambah 2 kolom ke struct User + repo; reuse query layer existing
     actions:
       - migrate: ALTER users ADD display_name text, avatar_url text
         kind: additive
         affects: [users, users.display_name, users.avatar_url]
     test: [simpan profil lalu baca balik cocok, migrasi apply bersih]
     status: pending
   ```
2. **build (D1):** prompt implementer dapat blok baru — slice `users` dari `control/schema/api.md` + listing `internal/user/` (`user.go, repo.go, session.go`) + directive "ALTER tabel ini / extend file ini, jangan duplikat".
3. **gate (D4):** checklist cek tak ada `CREATE TABLE` redundant / file duplikat; `reuse:` dihormati.

## 6. Scope & edge cases

- **`unit: package`** → tak punya DB; D1 skip bagian skema (tetap bisa listing-dir). `reuse:` boleh `file:` saja.
- **`unit: integration`** → pseudo-unit tanpa path/proyeksi sendiri → D1 skip; tak terpengaruh.
- **App FE/non-DB** → tak punya `control/schema/<app>.md` → bagian skema D1 degrade ke listing-dir; D5 UI-Contract path tak berubah.
- **App DB raw-SQL (tanpa ORM)** → kelas KETIGA (bukan ORM, bukan non-DB): seed/proyeksi dari **folder migrasi** (`schema-projection.md:14-16` sudah lokalisasi folder migrasi raw-SQL *by-understanding*). `stack.orm` kosong **dan** tak ada folder migrasi → tandai uncovered + warning, **jangan** no-op diam (justru DB app inilah yang rawan tabel-redundant).
- **Greenfield awal** → proyeksi tipis/baru → D1 nganterin apa yang ada (tumbuh tiap migrate); D2 sering belum banyak yang diputuskan — tetap benar (degrade natural).
- **fix-build** (`control/fixes/<id>/`, tasks.yaml tanpa `feature:`) → D1/D2 berlaku sama; label proyeksi = `fix/<id>` (konsisten `schema-projection.md:10`).
- **Headless/unattended (M7)** → D1-D6 nol interaksi & nol palang baru → aman; tak mengubah `outcome`/floor/cadence. D4 cuma nambah baris di challenge checklist yang sudah ada.
- **Proyeksi absen/stub** → semua D degrade no-op + warning; tak pernah crash/blokir.

## 7. Non-goals (eksplisit di luar scope)

- **JANGAN** masukin kode/snippet implementasi ke `tasks.yaml` (impor balik staleness; rusak re-breakdown & resumability).
- **JANGAN** bikin palang keras baru / gate baru — semua advisory + show-at-gate.
- **JANGAN** ubah `subagent-driven-development` upstream atau ganti template implementer pinjaman secara struktural — cukup tambah blok konteks di rakitan `build`.
- **JANGAN** introspeksi DB hidup di mana pun (proyeksi selalu dari sumber file, `schema-projection.md`).
- Bukan optimasi performa query otomatis / linter — cuma menyediakan konteks + konvensi + jaring review.

## 8. Success criteria

1. Implementer subagent menerima daftar tabel & file existing yang relevan di prompt-nya untuk task BE (verifikasi: rakitan prompt `build` memuat blok skema+dir).
2. `tasks.yaml` task BE membawa keputusan `reuse:` eksplisit saat ada padanan existing.
3. Skenario worked-example (`users`/`user.go`) menghasilkan ALTER+modify, bukan tabel+file baru.
4. Brownfield: `wire` (brownfield-repair) nge-seed `control/schema/` dari sumber existing — **presence-based** (KEBERADAAN proyeksi, bukan status-wired) & idempoten. `upgrade` hanya mengarahkan ke `wire`, tak nge-seed.
5. Nol regresi pada alur degrade (proyeksi kosong), headless/unattended, package/integration/FE.
6. `conventions.md` punya rumah untuk disiplin query.

## 9. Open questions (untuk dikonfirmasi sebelum/saat writing-plans)

- Bentuk final field `reuse:` — `table:`/`file:` cukup, atau perlu `repo:`/`module:` granular?
- Ambang "proyeksi besar" untuk slice vs full di D1 (default ~15 tabel) — angka pas?
- ~~D6 owner~~ **RESOLVED (verifikasi 2026-06-18):** `wire` brownfield-repair SAJA — bukan `upgrade` (langgar charter nol-sentuh-knowledge), bukan `extract` (stack belum tercatat). Seed butuh `stack.orm`/sumber skema → natural terpenuhi setelah `architect` CAPTURE, yang `wire` sudah jadikan prasyarat (`wire/SKILL.md:23`).
