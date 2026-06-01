# context-vault — Shared-Package End-to-End (H2) — Design Spec

- **Tanggal:** 2026-06-01
- **Status:** Draft disetujui untuk masuk tahap perencanaan implementasi
- **Terkait:** spec induk `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§4 just-in-time knowledge + "satu sumber kebenaran banyak proyeksi", §7 model `control/`/`workspace.yaml`, §9 skill `architect`/`fanout`/`plan`/`breakdown`/`build`/`ship`, §12 lifecycle, §17 komponen); spec Langkah-1 `2026-06-01-platform-invariants-security-gate-design.md` (`invariants.md`, challenge invarian di `plan`/`breakdown`/`build`, M2-bagian "mandatory package" yang **ditunda ke sini**); spec `2026-05-31-add-app-skill-design.md` (pola conductor `add-app` yang **ditiru** `add-package`); spec `2026-05-31-wire-skill-design.md` (`wire` generic-from-stack); spec `2026-05-29-breakdown-build-execution-phase-design.md` (mesin `task`/`actions`/`integration`).
- **Asal:** audit adversarial pipeline (26 agent) terhadap skenario "solo dev bikin ecommerce-builder ala Shopify full-AI". 16 gap terkonfirmasi (0 dibantah). Spec ini mengerjakan gap **H2** (shared-package buta end-to-end) — gap pertama **Langkah 2**. M5/M4/H3 = spec terpisah berikutnya.
- **Grounding:** sebelum desain, current-state diverifikasi ulang ke file nyata (bukan ringkasan handoff) lewat 9-agent read+adversarial-check. Keempat klaim handoff (workspace.yaml cuma `apps[]`; `add-app` nolak package; `breakdown` `task.app == apps[].name`; nol fan-IN) **terkonfirmasi**, dengan refinement: kendala `task.app` itu **laten** (gagal telat di `build` path-resolve, bukan gate eksplisit); primitif `plans/_shared.md` (`plan`) & pseudo-unit `integration` (`breakdown`) bisa **diperluas** bukan dibikin baru; `fanout` udah punya penanda `APP NEW` yang simetris untuk `PACKAGE NEW`.

---

## 1. Ringkasan

Seluruh pipeline **buta terhadap shared package**. `workspace.yaml` cuma punya `apps[]` (ditulis `init`); `add-app/SKILL.md` eksplisit menolak package ("Shared package … BUKAN urusan `add-app` — beda cabang"); `breakdown` memvalidasi `task.app == apps[].name` sehingga task yang hidup di package dipaksa salah; dan **tak ada fan-IN** — saat API sebuah shared package berubah, N consumer yang sudah di-ship tak pernah dienumerasi/diuji-ulang. Pipeline cuma **fan-OUT** (satu ide fitur → menyebar ke banyak app); tak ada jalur balik (satu package berubah → mengumpul ke semua app yang memakainya).

Trigger Shopify: hari-1 butuh `@store/money` + `@store/tenancy` dipakai 3 app; saat `formatMoney()` ganti signature, consumer tak ter-update → degradasi senyap / crash saat skala.

**Pendekatan:** jadikan shared package **unit kelas-satu** dengan meniru pola `add-app` yang sudah terbukti. (a) Array `packages[]` di `workspace.yaml`; (b) skill baru **`add-package`** (sibling `add-app`, gate = **typecheck hijau**, tanpa DB/wiring/smoke), di-auto-invoke `feature` saat `fanout` menandai `PACKAGE NEW`; (c) `task.app` → **`task.unit`** (app ATAU package), dengan kendala laten **dinaikkan jadi gate eksplisit** di `breakdown`; (d) `plan` menulis `plans/<pkg>.md` (kontrak exports/signature); (e) **robot fan-IN** — saat fitur mengubah API package yang punya consumer, `breakdown` otomatis menerbitkan 1 update-task per consumer + 1 task `integration` retest, `build` skip-cepat consumer yang tak kena; (f) **M2 enforcement** — field `mandatory_for[]` + satu baris challenge "membypass mandatory package?" (klausa yang **sengaja ditunda dari Langkah 1**, dipasang di sini). Plugin tetap **generic** — Shopify hanya alat uji.

## 2. Tujuan & Non-Tujuan

**Tujuan:**
- Shared package punya **representasi durable** di `workspace.yaml` (`packages[]`) dan **entrypoint resmi** (`add-package`), sejajar dengan `apps[]`/`add-app`.
- Task bisa **hidup di package** (`task.unit` = app atau package) tanpa gagal-laten di `build`.
- `plan` menulis **kontrak package** (`plans/<pkg>.md`) sekali, bukan men-derive ulang tiap fitur.
- **Fan-IN ada:** perubahan API package otomatis meng-enumerasi consumer + menerbitkan update/retest task. Tak ada lagi consumer "dilupakan".
- **M2 terpasang:** package boleh ditandai `mandatory_for` app tertentu; gate menolak app yang membypass-nya.
- **Reuse maksimal:** tiru `add-app`; perluas `wire` (mode-package), `plans/_shared.md`, pseudo-unit `integration` — bukan bikin mesin baru.
- **Tetap generic:** package di-*elicit* (fanout mengusulkan, user menentukan); tak ada asumsi ecommerce.

**Non-Tujuan (spec ini):**
- **Fan-IN granular per-export** (cuma retest consumer yang pakai export yang berubah). Dipilih model **konservatif-tapi-murah**: enumerasi semua consumer, tiap task skip-cepat kalau tak kena (§8.3). Per-export tracking = future (butuh `consumers:[{app,uses[]}]` → menambah kompleksitas + risiko retrofit; sengaja dihindari).
- **Versioning per-app / version pinning.** Package **lock-step** (semua consumer ikut versi terkini); tak ada field `version`. Fan-IN trigger = "kontrak berubah?" (dibanding kode terkini), bukan "version bump?". Independent release train = future.
- **Deploy/release/publish package** (npm publish, package registry, release order). Ikut defer "post-ship lifecycle" (spec struktural `2026-05-31-pipeline-hardening-structural-design.md` §S4.1).
- **`extract` brownfield package-inference** (nebak shared package dari scan kode existing). Sub-proyek tersendiri; defer.
- **Shared package non-kode** (config/asset bersama) — v1 fokus package kode (types/ui-kit/utils/hooks).
- **M5/M4/H3** — gap Langkah 2 lain; spec sendiri.

**Revisi terhadap spec induk & Langkah-1:** spec induk menyebut "shared package" hanya sebagai kontrak konvensi di prosa `architect` (§9, `architect/SKILL.md:32`) + catatan "Shared package: rerun manual" (`architect/SKILL.md:50`) — tak ada struktur. Spec ini menjadikannya **operasional**: entitas di `workspace.yaml` + skill + fan-IN. Langkah-1 (§8/§12) **menjanjikan** M2-mandatory-package "menyusul bersama H2" — spec ini **merealisasikannya** (§9).

## 3. Prinsip yang Dijaga

- **Tiru yang terbukti.** `add-package` = cermin `add-app` (conductor: declare → architect → bring-up, semua gated). Bedanya cuma bring-up: typecheck, bukan DB/smoke. Mengurangi permukaan-bug & beban-belajar.
- **Satu sumber kebenaran, banyak proyeksi (induk §4).** Kontrak package = **kode package itu sendiri**; `plans/<pkg>.md` adalah proyeksi/derivasi, bukan sumber kedua yang bisa basi. Fan-IN mendeteksi "kontrak berubah" dengan membandingkan niat-fitur vs kode terkini — **tanpa** file-diff durable baru.
- **JIT tidak dilanggar.** `packages[]` tumbuh just-in-time saat fitur pertama butuh kode-bareng (lewat `add-package`), persis seperti `apps[]` tumbuh lewat `add-app`. Tak ada deklarasi package di muka.
- **Anti-yes-man.** `fanout` meng-*challenge* sebelum menandai `PACKAGE NEW`: "beneran dipakai >1 app? cukup 1 app saja tidak?" — cegah package prematur (over-engineering) maupun duplikasi peran lintas app.
- **Invarian level-produk tidak di-fork package.** Package adalah **consumer** invarian (`invariants.md`), bukan pengunci. `add-package` tak pernah me-`lock` invarian baru; ia cuma mengecek stack package patuh.
- **Gate berskala, bukan seremoni.** Bring-up package lebih murah dari app (no DB/smoke). Fan-IN menerbitkan banyak task tapi tiap task **skip-cepat** kalau tak kena — hindari beban-approve yang jadi keluhan (audit M7).

## 4. Data model — `packages[]` di `workspace.yaml`

### 4.1 Skema entry
Array `packages:` di root `workspace.yaml`, **sejajar `apps:`**. Tiap entry:
```yaml
packages:
  - name: money                  # identitas package (mis. @store/money → "money")
    path: packages/money         # monorepo — packages/<nama> | multi-repo — ../<nama>
    repo_url:                    # diisi untuk multi-repo, kosong untuk monorepo
    type: package                # penanda unit = package (vs fe/be/fullstack di apps[])
    responsibility: "format dan hitung uang"
    consumers: []                # nama app yang mengimpor package ini; diisi fanout/plan (idempotent)
    mandatory_for: []            # nama app yang WAJIB pakai package ini (M2); kosong = tidak wajib
    stack: {}                    # diisi architect (lang/build-tool/test-runner)
```

### 4.2 Semantik
- **`consumers[]`** = jantung fan-IN. Daftar **nama app** saja (sederhana — keputusan granularity §8.3 menghindari bentuk `{app,uses[]}`). **Penulis tunggal = `fanout`** (idempotent, add-only-if-absent), saat sebuah app terbukti mengimpor package; `plan`/`breakdown` **hanya membaca** (cegah double-write/hilang-entri lintas-skill). Dibersihkan oleh `drop` saat app/package dihapus (§10.2).
- **Scope v1 — `consumers[]` berisi nama app saja, BUKAN package lain.** Dependency package-ke-package (package A mengimpor package B) di luar scope: A memperlakukan B sebagai **internal**, tak memicu fan-IN berjenjang. (Rasional: hindari graph siklik + ledakan jumlah task; ekstensi data-model masa depan.)
- **`mandatory_for[]`** = enforcement M2 (§9). Sumbernya bisa diturunkan dari `invariants.md` (mis. slot Money "semua uang lewat `@store/money`") atau dideklarasi user saat `add-package`. Kosong = tak ada paksaan.
- **TANPA `capabilities`** (itu milik `apps[]`; package "punya" exports/API surface, bukan capability fitur). **TANPA** `db`/`route`/`smoke` (package tak punya runtime). **TANPA** `version` (lock-step; lihat Non-Tujuan).
- **Tak ada file baru di `control/`.** Package hidup di `workspace.yaml` + kontrak per-fitur di `plans/<pkg>.md`. Konsisten prinsip induk §4.

### 4.3 Inisialisasi
`init` menulis **`packages: []`** (key kosong) di `workspace.yaml` setelah blok `apps:`, agar key selalu ada untuk dibaca skill hilir. `init` **tidak** menanyakan package saat Q&A (package muncul belakangan lewat `add-package`, seperti app baru lewat `add-app`). Penambahan ke generator `init` aman (replace placeholder berbasis sed; tak ada nilai mengandung `": "`).

## 5. Skill baru — `add-package` (conductor, cermin `add-app`)

File baru `plugin/skills/add-package/SKILL.md` (**tanpa** `reference.md` — thin conductor seperti `add-app`). Spine identik `add-app`, bring-up dipangkas:

```
add-package <nama>
  0  Prasyarat : baca control/workspace.yaml (apps[]+packages[]) + conventions.md + invariants.md.
                 Wajib ada control/ (post-init). Prasyarat invarian (BACKSTOP, sama seperti
                 add-app/wire): kalau invariants.md belum ada / masih ada slot <belum dikunci>
                 → STOP, arahkan ke architect "Kunci Invarian" dulu (bukan deadlock — sekadar
                 arah-ulang). Package = consumer invarian, BUKAN pengunci. Normalnya invarian
                 sudah terkunci saat app pertama dibuat (package butuh app untuk dikonsumsi),
                 jadi cek ini jarang menyala.
  1  Idempotent: kalau <nama> sudah di packages[] → STOP.
  2  Q&A identitas: name, responsibility (1 kalimat), type=package; path diturunkan dari topology
                 (monorepo → packages/<nama>; multi-repo → ../<nama> + repo_url). Tanya opsional
                 "wajib dipakai app mana?" → usulan mandatory_for. JANGAN tanya stack di sini.
  3  GATE — tulis entry ke packages[] di workspace.yaml (diff → approve).
  4  Invoke architect (mode-package): Q&A stack (lang/build-tool/test-runner) + rekam konvensi
                 import/build package ke conventions.md (§10.3).
                 → langkah "Kunci Invarian" (architect 4.5) TIDAK nyala untuk package — architect
                   hanya RE-KONFIRMASI stack package tak melanggar invariants.md terkunci.
  5  Invoke wire (MODE-PACKAGE, §6): scaffold skeleton lib + register di workspace
                 → GATE = typecheck/lint hijau. SKIP DB/server/migrate/smoke.
  6  Close + kembali ke feature (kalau dipanggil feature) untuk lanjut plan; else sarankan langkah
     berikut (feature <nama-fitur>).
```
**Catatan `consumers[]` saat manual:** `add-package` standalone bikin skeleton + `consumers: []` **kosong**. `consumers[]` baru terisi saat package itu dipakai pertama kali lewat `fanout` di sebuah fitur (§7.1) — `fanout` penulis tunggalnya.

- **Gate = typecheck hijau**, bukan smoke/DB (sesuai mandat audit H2).
- **`add-package` satu-satunya penulis entri `packages[]` pasca-init** (cermin "add-app satu-satunya penulis `apps[]`"). `architect`/`wire` boleh jalan standalone tapi tak menulis entri package baru.
- **Bisa dipanggil manual** (`/add-package <nama>`) atau **auto oleh `feature`** (§7.2).

## 6. `wire` — mode-package

`wire` sudah **generic-from-stack** (baca stack dari `workspace.yaml`, bukan hardcode). Tambah deteksi unit `type: package`:
- **`wire` langkah 0** (prasyarat, yang kini baca `apps[]`): juga baca `packages[]`. Saat dipanggil untuk sebuah package, resolve path dari `packages[].path`.
- **Mode-package = subset bring-up:** scaffold skeleton library (via tool resmi stack, mis. `tsup`/`tsc` init atau minimal `package.json`+`tsconfig`+`src/index`) + **register di workspace** (mis. `pnpm-workspace.yaml`/`turbo`/`tsconfig` paths). **SKIP**: spin DB, ORM/migrate, wiring FE↔BE, smoke test runtime.
- **Gate penutup mode-package = typecheck/lint hijau** (ganti smoke test).
- Reuse satu scaffolder (konsisten `add-app` → `wire`); tak ada duplikasi logika scaffold di `add-package`.

## 7. Seam fan-OUT (membuat & memakai package)

### 7.1 `fanout` — deteksi `PACKAGE NEW` + isi `consumers[]`
- Baca `packages[]` (tambahan dari kini hanya `apps[]`).
- Saat memetakan peran fitur ke unit: kalau ada **kode-bareng yang dipakai >1 app** (mis. format uang, tipe domain bersama) → **challenge anti-yes-man** ("beneran shared >1 app? cukup 1 app tidak?"). Lolos → tandai output **`PACKAGE NEW: <nama>`** (simetris dengan `APP NEW` yang sudah ada). Seperti `APP NEW`, entri **tidak** ditulis ke `workspace.yaml` di sini — itu jatah `add-package`.
- Saat app terbukti memakai package (yang **baru dibikin fitur ini** ATAU **existing**) → tambah nama app ke `packages[<pkg>].consumers` (idempotent), persis cara `fanout` kini meng-update `apps[].capabilities`. Ini **satu-satunya** entry point pengisian `consumers[]`.

### 7.2 `feature` — auto-invoke `add-package`
Urutan `feature` (kini: intake → fanout → [add-app per `APP NEW`] → plan) disisipi: setelah loop `add-app`, tambah loop **`add-package`** — untuk tiap `PACKAGE NEW` di `fanout.md`, invoke `add-package <nama>` (declare → architect → wire mode-package, semua gated) → tunggu beres → baru lanjut `plan`. Cermin persis seam `APP NEW` → `add-app`.

### 7.3 `plan` — `plans/<pkg>.md` (kontrak)
- Baca `packages[]` + `consumers[]` (**read-only** — `plan` tak pernah menulis `consumers[]`; itu jatah `fanout` §7.1).
- Untuk tiap package yang kena fitur → tulis **`plans/<pkg>.md`** = **kontrak**: daftar exports + signature + invarian yang dijaga package. Bukan implementasi. Ini menggantikan "derive ulang kontrak di `plans/_shared.md`" — `_shared.md` tetap untuk kontrak lintas-app non-package.
- `plans/<app>.md` untuk app consumer mencatat **dependency package**-nya (package apa, dipakai untuk apa).

### 7.4 `breakdown` — `task.unit` + gate eksplisit
- **Rename `task.app` → `task.unit`** di skema (`reference.md`) + **semua contoh task**. `unit` boleh = nama app, nama package, atau pseudo-unit `integration`.
- **Naikkan kendala laten jadi gate eksplisit:** sebelum tulis `tasks.yaml`, validasi tiap `task.unit` cocok dengan `apps[].name` ATAU `packages[].name` ATAU `integration`; kalau tidak → STOP + saran (`add-app`/`add-package`/typo). (Kini kendala ini cuma komentar skema → gagal-laten di `build` path-resolve; kita pindahkan ke depan.)
- Task di package: **dilarang** `actions:[migrate]`/`actions:[env]` (package tak punya DB/infra).

### 7.5 `build` — resolusi path + dispatch package
- Resolusi path bercabang: `unit ∈ apps[]` → `apps[].path`; `unit ∈ packages[]` → `packages[].path`; `unit == integration` → skip-path (sudah ada). `git -C <path>` probe & branch-per-repo berlaku sama untuk path package.
- Dispatch task package = jalankan **typecheck + test exports** package (bukan boot/smoke app).

## 8. Robot fan-IN (menjaga consumer saat package berubah)

### 8.1 Deteksi (tanpa file-diff durable)
1. **`fanout`** menandai fitur **`PACKAGE TOUCHED: <nama>`** untuk package existing yang API-nya disentuh fitur, dan menarik daftar consumer dari `packages[<nama>].consumers`.
2. **`plan`** membaca **kode package terkini** (sumber kebenaran) + niat fitur → menulis `plans/<pkg>.md`. Kalau exports/signature berubah dibanding kode terkini (mis. `formatMoney(cents)` → `formatMoney(amount, currency)`) → tandai **`BREAKING`** di `plans/<pkg>.md` + cantumkan daftar consumer terdampak.

**Carve-out package baru:** deteksi `BREAKING` & fan-IN **hanya** berlaku untuk package yang **sudah ada sebelum fitur ini** (punya kode terkini + `consumers[]` terisi). Package yang **baru dibikin fitur ini** (lewat `add-package`) tak punya kontrak sebelumnya → **tak ada `BREAKING`**; consumer-nya dapat task **integrasi fan-OUT biasa** (§7), bukan retest fan-IN. (`plan` cek: package ada di `workspace.yaml` saat fitur mulai?)

### 8.2 Enumerasi & task (`breakdown`)
Saat `plans/<pkg>.md` ber-flag `BREAKING`, `breakdown` menerbitkan otomatis:
- 1 task `unit: <pkg>` (ubah package-nya),
- **1 update-task per consumer** (`unit: <consumer-app>`, `deps: [task-package]`) untuk tiap nama di `packages[<pkg>].consumers`,
- 1 task `unit: integration` (retest roundtrip kontrak package ↔ consumer; reuse pseudo-unit `integration` yang sudah ada).

Coverage-check `breakdown`: tiap consumer di `packages[<pkg>].consumers` **wajib** punya ≥1 task (update atau ter-cover integration) saat `BREAKING`.

Pseudo-unit `integration` **diperluas** mencakup roundtrip **package↔consumer** (boot consumer app dari path/stack `workspace.yaml`, panggil exports package, assert sesuai kontrak `plans/<pkg>.md`) — sintaks `unit: integration` **sama** dengan kontrak app↔app yang sudah ada (`breakdown/reference.md` D-3), bukan pseudo-unit baru. Kalau satu fitur punya roundtrip app↔app DAN package↔consumer → terbitkan beberapa task `unit: integration` (deps berjenjang).

### 8.3 Eksekusi murah (`build`) — model "enumerasi semua, skip-cepat"
`build` jalankan urut: task package → update-task consumer → integration. **Tiap update-task consumer mengecek dulu**: "consumer ini beneran memakai export yang berubah?" Kalau **tidak** → tandai *no-op*, typecheck lewat, selesai cepat (tak ada perubahan kode). Ini memberi keamanan "tak ada consumer terlewat" **tanpa** memaksa pipeline menyimpan peta per-export di `workspace.yaml`. (Keputusan granularity: konservatif-tapi-murah; alternatif "retest penuh semua" lebih boros, "presisi per-export" lebih ribet + berisiko retrofit `consumers[]` — keduanya ditolak, lihat §2 Non-Tujuan.)

### 8.4 Consumer yang sudah di-ship
Kalau `formatMoney` berubah di fitur #20, sedangkan `web`/`dashboard` di-ship di fitur #1/#3 → update-task untuk app-app itu tetap masuk breakdown **fitur #20** (fitur yang mengubah package = yang menanggung update consumer). Inilah inti penutupan gap "N consumer ter-ship tak pernah dienumerasi".

### 8.5 `ship` — sadar package
- `ship` baca `packages[]`; saat probe repo (kini per app), sertakan path package yang kena (`git -C <packages[pkg].path>`). Satu PR per repo-toplevel unik (apps + packages digabung). Karena update-task consumer sudah masuk `tasks.yaml` (§8.2), repo consumer otomatis ikut grouping — `ship` cuma perlu tak buta terhadap repo package itu sendiri.
- **Mono- & multi-repo sama:** logika branch-per-repo `build` (`reference.md` §F: `git -C <path> rev-parse --show-toplevel`, group per toplevel unik) berlaku **identik** untuk package — monorepo (`path = packages/<nama>`, toplevel = hub) maupun multi-repo (`path = ../<nama>`, `repo_url` diisi, toplevel = repo sendiri). Tiap repo unik dapat satu branch `feature/<fitur>` + satu PR.

## 9. M2 — `mandatory_for` + challenge "membypass mandatory package"

Klausa yang **sengaja ditunda dari Langkah 1** (Langkah-1-spec §8: "Menambahkannya sekarang = pointer ke artifact fiktif … Masuk di Langkah 2"). Sekarang `packages[]` ada, jadi dipasang:
- Field **`mandatory_for: []`** (§4.1) menandai app yang wajib memakai package (mis. semua app wajib `money` untuk uang, bukan format sendiri). Diisi saat `add-package` (§5 step 2) atau diturunkan dari `invariants.md`.
- Tambah **satu baris challenge** (di samping challenge invarian Langkah-1), di:
  - `plan/SKILL.md` (Challenge teknis),
  - `breakdown/SKILL.md` (challenge/coverage),
  - `build/SKILL.md` (challenge checklist gate per-segmen).
  > "Apakah task ini membuat logika yang seharusnya memakai mandatory package (mis. format uang sendiri padahal `money` wajib untuk app ini)?" → kalau ya, STOP/redirect ke package.
- Challenge ini **bersilang dengan `invariants.md`**: kalau invarian menyebut "semua uang lewat package X", `mandatory_for` adalah proyeksi enforceable-nya.

## 10. Hygiene skills

### 10.1 `render-docs`
Baca `packages[]`; render **kartu package** di HTML (nama, responsibility, consumers, mandatory_for) — dibedakan dari kartu app. (Tanpa ini, doc jadi package-blind.)

### 10.2 `drop` (+ kemampuan drop-package)
- **drop-package:** hapus entri dari `packages[]`. **Revalidasi:** kalau package masih punya `consumers` atau ada di `mandatory_for` app aktif → **STOP/warn** (jangan drop package yang masih dipakai). Promosi knowledge sama seperti drop app.
- **drop app** (existing) diperluas: saat app dihapus, **bersihkan namanya dari semua `packages[].consumers`** (dan `mandatory_for`) agar fan-IN tak menarget app hantu.

### 10.3 `conventions.md`
Seksi baru "Konvensi Package" (path import, build/test, sinyal breaking/deprecation), diisi `architect` saat `add-package` step 4. Template `plugin/template/control/conventions.md` boleh menyiapkan heading kosong.

## 11. Permukaan Integrasi (peta edit file)

| File | Perubahan |
|---|---|
| `plugin/skills/init/SKILL.md` | Tulis `packages: []` (key kosong) di `workspace.yaml` setelah blok `apps:` (§4.3) |
| `plugin/skills/add-package/SKILL.md` | **BARU** — conductor §5 |
| `plugin/skills/wire/SKILL.md` (+ `reference.md`) | Mode-package: baca `packages[]`, scaffold lib + register workspace, gate typecheck, skip DB/smoke (§6) |
| `plugin/skills/architect/SKILL.md` | Mode-package dipanggil `add-package`: Q&A stack package, re-konfirmasi (BUKAN re-lock) invarian; update catatan `:50` "Shared package: rerun manual" → "lewat `add-package`" (§5/§10.3) |
| `plugin/skills/fanout/SKILL.md` | Baca `packages[]`; challenge + tandai `PACKAGE NEW`/`PACKAGE TOUCHED`; isi `consumers[]` idempotent (§7.1/§8.1) |
| `plugin/skills/feature/SKILL.md` | Loop auto-invoke `add-package` per `PACKAGE NEW` sebelum `plan` (§7.2) |
| `plugin/skills/plan/SKILL.md` | Baca `packages[]`; tulis `plans/<pkg>.md` kontrak + flag `BREAKING`; `plans/<app>.md` catat dependency; 1 challenge M2 (§7.3/§8.1/§9) |
| `plugin/skills/breakdown/SKILL.md` (+ `reference.md`) | Rename `task.app`→`task.unit` + contoh; gate validasi unit eksplisit; fan-IN task-gen saat `BREAKING` + coverage; larang `migrate/env` di task package; 1 challenge M2 (§7.4/§8.2/§9) |
| `plugin/skills/build/SKILL.md` (+ `reference.md`) | Resolusi path packages[]; dispatch typecheck/test package; skip-cepat consumer tak-kena; 1 challenge M2 (§7.5/§8.3/§9) |
| `plugin/skills/ship/SKILL.md` | Baca `packages[]`; probe repo package; grouping PR sertakan repo package (§8.5) |
| `plugin/skills/render-docs/SKILL.md` (+ template) | Kartu package di HTML (§10.1) |
| `plugin/skills/drop/SKILL.md` | drop-package + revalidasi consumer; drop-app bersihkan `consumers[]`/`mandatory_for` (§10.2) |
| `plugin/skills/add-app/SKILL.md` | Update baris penolakan (`:15`): "Shared package … BUKAN urusan add-app" → "lewat skill `add-package`" (pointer, bukan refusal buntu) |
| `plugin/template/control/conventions.md` | Heading "Konvensi Package" (§10.3) |

## 12. Amandemen Spec

### 12.1 Spec induk (`2026-05-24-ai-first-boilerplate-design.md`)
- **§7 `workspace.yaml`** (skema System Map, sekitar line 84-97): tambah `packages[]` sejajar `apps[]`.
- **§9 Skill (subsection yang ADA di parent):** `feature` (line ~163 — loop auto-invoke `add-package` per `PACKAGE NEW`), `fanout` (line ~174 — deteksi `PACKAGE NEW/TOUCHED` + isi `consumers[]`), `plan` (line ~181 — tulis `plans/<pkg>.md`), `ship` (line ~187 — probe repo package), `drop` (line ~197 — drop-package), `render-docs` (line ~201 — kartu package). **Catatan:** `breakdown`/`build`/`wire`/`add-app` **tak punya** subsection §9 di parent (didokumentasi di spec masing-masing) → perilaku package-nya dicatat di spec H2 ini, **bukan** amandemen §9.
- **Cabang lifecycle (note "Cabang dipicu — fitur butuh app baru", line ~230):** tambah **cabang sibling** — fitur butuh shared package → `feature` auto-invoke `add-package` saat `PACKAGE NEW`. Diagram lifecycle (§12) tambah cabang `add-package` sejajar `add-app`; sebut `task.unit`.
- **§17 Komponen** (line ~275): jumlah skill **15 → 16** (tambah `add-package` ke daftar, sejajar `add-app`); catat `packages[]` di `workspace.yaml`; sebut `wire` mode-package.

### 12.2 Spec Langkah-1 (`2026-06-01-platform-invariants-security-gate-design.md`)
- **§8 / §12** ("M2-bagian 'mandatory package' menyusul bersama H2"): tandai **direalisasikan** di spec ini §9.

## 13. Staging untuk Plan (eksekusi bertahap — di level *plan*, bukan spec)

Desain utuh di spec ini, tapi `writing-plans` boleh memecah eksekusi/merge:
- **Stage 1 — fan-OUT (mergeable sendiri):** `packages[]` schema (init) · `add-package` · `wire` mode-package · `fanout` `PACKAGE NEW` + `consumers[]` · `feature` auto-invoke · `plan` `plans/<pkg>.md` · `breakdown` `task.unit` + gate · `build` path-resolve · `render-docs`/`drop`/`conventions`. → package bisa **dibuat, dipakai, di-ship**. `consumers[]` **wajib sudah diisi benar** di stage ini (kalau tidak, Stage 2 perlu retrofit — peringatan adversarial-check). **Catatan:** Stage 1 **sengaja belum** punya robot fan-IN — kalau fitur Stage-1 mengubah API package ber-consumer, dampaknya ditangani **manual** (interim, sama seperti keadaan sekarang); `consumers[]` tetap diisi `fanout` supaya Stage 2 tinggal baca.
- **Stage 2 — fan-IN + M2:** deteksi `BREAKING`/`PACKAGE TOUCHED` · enumerasi consumer · update-task + integration retest · skip-cepat · `mandatory_for` + challenge M2.

## 14. Rencana Verifikasi

Eksekusi via `writing-plans` → `executing-plans` (biasanya sesi terpisah). Setelah implement:
1. **YAML-lint / frontmatter:** tiap skill diedit valid; **colon-space guard** — tak ada `description:`/contoh-skema value mengandung `": "` (bug berulang 4×).
2. **Grep-battery konsistensi:** `packages`/`add-package`/`task.unit`/`PACKAGE NEW`/`PACKAGE TOUCHED`/`mandatory_for`/`consumers` muncul konsisten lintas file yang diklaim §11. **Khusus:** verifikasi rename `task.app`→`task.unit` **lengkap** — grep sisa `app:` di konteks `tasks.yaml`/contoh (breakdown reference + build reference + reader manapun) tak ada yang basi.
3. **Coherence guard (CRITICAL):** tak ada pointer ke artifact Langkah-2 lain yang **belum ada** — `control/integrations.md` (M5), `control/schema/` (M4), `data-model.md` (H3). H2 hanya boleh menyandar primitif yang ada + yang H2 bikin. (Caveat koherensi audit.)
4. **Renumber-cross-ref check (WAJIB):** kalau menyisip langkah ke `feature`/`fanout`/`plan`/`breakdown`/`build`/`wire`/`ship`, pakai **desimal** + verifikasi tiap cross-ref internal "step N"/"langkah N" masih menunjuk target benar (bukan cuma heading unik). Bug `5520de5` lolos 2×.
5. **Mis-aimed pointer check:** tiap "§X"/"reference Y"/"(lihat …)" di skill DAN spec menunjuk section yang benar-benar memuat kontennya (lolos verify-eksekusi 4×; bug pernah di SPEC).
6. **Dry-run skenario:** (a) `fanout` deteksi kode-bareng → tandai `PACKAGE NEW` + challenge; `feature` auto-invoke `add-package`; (b) `add-package` idempotent (package sudah ada → STOP); (c) `breakdown` `task.unit` package → lolos gate; `task.unit` ngaco → STOP; (d) fitur ubah signature package ber-consumer → `plan` flag `BREAKING` → `breakdown` terbitkan update-task tiap consumer + integration; (e) `build` consumer tak-kena → no-op cepat; (f) app membypass `mandatory_for` package → challenge STOP; (g) `drop-package` saat masih ada consumer → STOP.
7. **1 ronde baca-adversarial di SESI TERPISAH** khusus mis-aimed pointer + staleness parent/Langkah-1 spec + kelengkapan rename `task.unit` — pelajaran berulang: verify sesi-eksekusi sendiri melewatkan kelas-bug ini.

## 15. Out of Scope → sisa Langkah 2 (pointer)

Gap Langkah 2 berikutnya (spec sendiri, urutan dari audit): **M5** (`control/integrations.md` + plan promote kontrak vendor + task "inbound eksternal" + `wire` webhook-receiver stub), **M4** (`control/schema/<app>.md` sebagai projeksi ter-generate dari migrations), **H3** (impact-analysis migrasi lintas-fitur + `migrate.kind/affects` — re-anchor basis consumer ke M4, **bukan** `packages[].consumers` H2). Future H2 sendiri: fan-IN per-export granular, version pinning per-app, package deployment/release, `extract` brownfield package-inference.
