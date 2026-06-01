# H2 Shared-Package End-to-End — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Jadikan shared package unit kelas-satu di pipeline context-vault — `packages[]` di workspace.yaml, skill `add-package`, `task.unit` (app ATAU package), kontrak `plans/<pkg>.md`, robot fan-IN (retest consumer saat API package berubah), dan enforcement M2 `mandatory_for`.

**Architecture:** Plugin = lapisan AI+knowledge (markdown/yaml), BUKAN kode runtime. Implementasi = **edit file skill** (`plugin/skills/<nama>/SKILL.md` + sebagian `reference.md`) + 1 file skill BARU (`add-package`) + amandemen 2 spec. Tiru pola `add-app` yang sudah live. **Satu task = satu file** (semua anchor find/replace diverifikasi vs file SEKARANG — tak ada anchor antar-task yang rapuh). Fan-IN dormant sampai sebuah package benar-benar berubah, jadi pipeline fan-OUT langsung fungsional setelah task-task awal.

**Tech Stack:** Markdown skill files (frontmatter YAML + prose), `git` per task. Tak ada test runner — verifikasi = `grep`-battery + baca manual + dry-run skenario di akhir.

**Spec:** `docs/superpowers/specs/2026-06-01-h2-shared-package-design.md` (§ dirujuk per task).

---

## Aturan eksekusi (baca dulu — bug-guard berulang project ini)

Tiap task: terapkan Edit(s) → jalankan grep-verify → commit. **Per-file sekuensial; JANGAN batch banyak Edit+commit dalam satu langkah** (Edit butuh anchor cocok; commit di tengah bisa nyimpen state setengah). Bug-guard yang WAJIB dijaga di SETIAP edit:

- **Colon-space YAML:** value `description:` frontmatter & contoh-skema TAK boleh mengandung `": "` (pakai em-dash `—` / kurung / `=`). Guard: `sed -n 's/^description: //p' FILE | grep ': '` harus kosong.
- **Mis-aimed pointer:** tiap `§X`/`reference Y`/`(lihat …)` yang ditulis HARUS nunjuk section yang beneran punya kontennya.
- **Renumber:** plan ini **tidak me-renumber** langkah integer mana pun — semua tambahan disisip sebagai **sub-bullet** atau **langkah desimal** (mis. `0.5`) supaya cross-ref "step N" tetap valid. Jangan ubah nomor langkah existing.
- **Rename `app:`→`unit:` (Task 9 & 10):** setelah rename, grep stale `app:` di konteks `tasks.yaml` harus 0.
- **Cek frontmatter description JUGA** (bukan cuma body) saat update phrase.

Commit message: prefiks `feat(<skill>):` / `docs(spec):`, akhiri dengan baris `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

**Branch:** sudah di `h2-shared-package` (spec sudah di-commit di sini). Semua task commit di branch ini.

**Titik mergeable (informasional):** setelah Task 14, pipeline bisa **bikin + pakai + ship** package (fan-OUT lengkap; fan-IN dormant). Task 8/9/10 sudah memuat logika fan-IN tapi baru aktif saat ada package `BREAKING`. Task 15 (M2) & sisanya melengkapi.

---

## Task 1: `init` — tambah `packages: []` ke generator workspace.yaml

**Files:**
- Modify: `plugin/skills/init/SKILL.md` (langkah 5, blok YAML)

Spec §4.3. `init` menulis key `packages: []` kosong setelah blok `apps:` agar selalu ada untuk dibaca skill hilir. `init` TIDAK menanyakan package (muncul belakangan lewat `add-package`).

- [ ] **Step 1: Edit blok YAML workspace.yaml**

Old:
```
    capabilities: []        # diisi fanout/architect
    stack: {}               # diisi architect
```
```
Untuk existing, isi `stack` per app dari hasil deteksi `package.json` (framework, db bila terbaca).
```

New:
```
    capabilities: []        # diisi fanout/architect
    stack: {}               # diisi architect
packages: []                # shared package (ui-kit/types/utils) — diisi skill add-package; consumers diisi fanout
```
```
Untuk existing, isi `stack` per app dari hasil deteksi `package.json` (framework, db bila terbaca). Biarkan `packages: []` kosong — package tumbuh lewat `add-package`, bukan di-declare saat init.
```

(Catatan editor: dua blok di atas berurutan; edit pertama menyisipkan baris `packages: []` sebelum penutup ```` ``` ````, edit kedua menambah kalimat pada paragraf setelahnya. Terapkan sebagai dua Edit terpisah agar anchor unik.)

- [ ] **Step 2: Verify**

Run: `grep -n 'packages: \[\]' plugin/skills/init/SKILL.md && sed -n 's/^description: //p' plugin/skills/init/SKILL.md | grep ': ' || echo "colon-space OK"`
Expected: baris `packages: []` muncul; "colon-space OK".

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/init/SKILL.md
git commit -m "feat(init): seed empty packages[] in workspace.yaml generator (H2 §4.3)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: `add-app` — ubah penolakan package jadi pointer ke `add-package`

**Files:**
- Modify: `plugin/skills/add-app/SKILL.md:15` (prinsip)

Spec §11. Baris penolakan buntu jadi pointer.

- [ ] **Step 1: Edit baris prinsip**

Old:
```
- **App doang (v1).** fe/be/fullstack. Shared package (ui-kit/types) BUKAN urusan `add-app` — beda cabang (nggak ada DB/wiring/smoke).
```
New:
```
- **App doang.** fe/be/fullstack. Shared package (ui-kit/types/utils) bukan urusan `add-app` — pakai skill **`add-package`** (cabang sendiri: tak ada DB/wiring/smoke, gate typecheck). Lihat spec H2 §5.
```

- [ ] **Step 2: Verify**

Run: `grep -n 'add-package' plugin/skills/add-app/SKILL.md`
Expected: baris prinsip menyebut `add-package`.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/add-app/SKILL.md
git commit -m "feat(add-app): point shared-package refusal to add-package (H2 §11)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: `wire` — mode-package (scaffold lib + register, gate typecheck, skip DB/smoke)

**Files:**
- Modify: `plugin/skills/wire/SKILL.md` (langkah 0 + Catatan)
- Modify: `plugin/skills/wire/reference.md` (section baru I)

Spec §6. `wire` sudah generic-from-stack; tambah cabang unit `type: package`.

- [ ] **Step 1: Edit langkah 0 (baca packages[] + cabang mode-package)**

Old:
```
### 0. Baca state & deteksi mode
Baca `control/workspace.yaml` (`apps[]`: path/type/stack/topology) + `control/conventions.md` + `control/invariants.md`. **Prasyarat stack:** architect sudah set `stack` logical (min framework + db + orm) per app; kalau belum → arahkan ke `architect`. **Prasyarat invarian:** `control/invariants.md` ada DAN semua slot resolved (tak ada `<belum dikunci>`); kalau tidak → **STOP**, arahkan ke `architect` (kunci invarian dulu — ia membentuk skema baseline). Cek kode tiap `path`: kosong → **greenfield (scaffold penuh)**; ada kode → **brownfield (repair: lengkapi yang kurang, idempotent, jangan timpa)**.
```
New:
```
### 0. Baca state & deteksi mode
Baca `control/workspace.yaml` (`apps[]` + `packages[]`: path/type/stack/topology) + `control/conventions.md` + `control/invariants.md`. **Prasyarat stack:** architect sudah set `stack` logical (min framework + db + orm) per app; kalau belum → arahkan ke `architect`. **Prasyarat invarian:** `control/invariants.md` ada DAN semua slot resolved (tak ada `<belum dikunci>`); kalau tidak → **STOP**, arahkan ke `architect` (kunci invarian dulu — ia membentuk skema baseline). Cek kode tiap `path`: kosong → **greenfield (scaffold penuh)**; ada kode → **brownfield (repair: lengkapi yang kurang, idempotent, jangan timpa)**.
- **Unit `type: package` → MODE-PACKAGE (reference §I):** package tak punya DB/server/route. Scaffold skeleton lib + register di workspace; **gate penutup = typecheck/lint hijau**; SKIP langkah 2 (DB), 3 (ORM/migrate), 4 (FE↔BE), 6 (smoke runtime). Resolve `path` dari `packages[].path`.
```

- [ ] **Step 2: Edit Catatan (sebut mode-package dipanggil add-package)**

Old:
```
- `wire` sekali jalan (kayak `extract`). Saat nambah app baru, dipanggil oleh skill `add-app` (yang chain `architect`→`wire`); bisa juga di-rerun manual. Brownfield: bersifat **repair** — hanya bila wiring belum lengkap.
```
New:
```
- `wire` sekali jalan (kayak `extract`). Saat nambah app baru, dipanggil oleh skill `add-app` (yang chain `architect`→`wire`); saat nambah shared package, dipanggil oleh skill `add-package` (mode-package — reference §I); bisa juga di-rerun manual. Brownfield: bersifat **repair** — hanya bila wiring belum lengkap.
```

- [ ] **Step 3: Tambah section I ke reference.md**

Tambah di akhir `plugin/skills/wire/reference.md` (setelah section H):
```

## I. Mode-package (unit `type: package`)

Shared package = kode bareng tanpa runtime sendiri → bring-up dipangkas. Dipanggil `add-package`.

- **Yang DIKERJAKAN:** scaffold skeleton library via tool resmi stack (mis. `tsup`/`tsc --init`, atau minimal `package.json` + `tsconfig` + `src/index`) + **register di workspace** (pnpm-workspace.yaml / turbo / `tsconfig` paths) sesuai topology.
- **Gate penutup = typecheck/lint hijau** (ganti smoke test runtime). Definisi "siap": package ke-build/typecheck tanpa error & ter-resolve dari workspace.
- **Yang DI-SKIP:** spin DB, ORM/migrasi, wiring FE↔BE, smoke HTTP. Package tak punya `db`/route.
- **Invarian:** package = CONSUMER invarian, bukan pengunci — prasyarat invarian (langkah 0) tetap berlaku sebagai backstop, tapi `wire` tak mengunci apa pun.
- **Multi-repo:** sama seperti app — `git -C <packages[pkg].path> rev-parse --show-toplevel`, branch per repo unik (§G).
```

- [ ] **Step 4: Verify**

Run: `grep -n -i 'mode-package\|type: package' plugin/skills/wire/SKILL.md plugin/skills/wire/reference.md`
Expected: cabang mode-package di SKILL langkah 0 + section I di reference.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/wire/SKILL.md plugin/skills/wire/reference.md
git commit -m "feat(wire): package mode (scaffold lib + register, typecheck gate, skip DB/smoke) (H2 §6)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: `architect` — handle package stack + update catatan shared-package

**Files:**
- Modify: `plugin/skills/architect/SKILL.md` (langkah 3 area + Catatan line 50)

Spec §5 (architect dipanggil add-package) + §11. Architect set stack package; langkah 4.5 tetap confirm-only (sudah idempotent); update catatan "Shared package: rerun manual".

- [ ] **Step 1: Tambah sub-langkah 3c (PACKAGE mode) setelah 3b**

Old:
```
### 4. Konvensi lintas-app
```
New:
```
### 3c. PACKAGE (unit `type: package`, dipanggil `add-package`)
Bila dijalankan untuk sebuah shared package (bukan app): Q&A **teknikal** singkat — bahasa, build-tool, test-runner. Tulis ke `stack` package di `control/workspace.yaml`. Rekam konvensi import/build package ke `conventions.md` (langkah 4). Package = CONSUMER invarian — langkah 4.5 hanya RE-KONFIRMASI `stack` package tak melanggar `invariants.md` terkunci (tak mengunci ulang).

### 4. Konvensi lintas-app
```

- [ ] **Step 2: Update Catatan (line ~50 "Shared package: rerun manual")**

Old:
```
- Nambah app baru pasca-`init` = lewat skill `add-app` (yang manggil `architect` ini buat set `stack` app yang baru dideklarasi). `architect` standalone tetap buat set/recapture stack app yang **sudah terdaftar** — ia **tidak** nulis entri app baru ke `workspace.yaml`. Shared package: rerun manual.
```
New:
```
- Nambah app baru pasca-`init` = lewat skill `add-app`; nambah shared package = lewat skill `add-package` (keduanya manggil `architect` ini buat set `stack` unit yang baru dideklarasi — app via 3a/3b, package via 3c). `architect` standalone tetap buat set/recapture stack unit yang **sudah terdaftar** — ia **tidak** nulis entri app/package baru ke `workspace.yaml`.
```

- [ ] **Step 3: Verify**

Run: `grep -n -i 'PACKAGE (unit\|add-package' plugin/skills/architect/SKILL.md && grep -c 'rerun manual' plugin/skills/architect/SKILL.md`
Expected: sub-langkah 3c + catatan add-package ada; `rerun manual` = 0 (sudah diganti).

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/architect/SKILL.md
git commit -m "feat(architect): package-mode stack Q&A; add-package replaces 'rerun manual' (H2 §5)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: `add-package` — skill BARU (conductor, cermin `add-app`)

**Files:**
- Create: `plugin/skills/add-package/SKILL.md`

Spec §5. Conductor: declare → architect (3c) → wire (mode-package). Gate typecheck. Depends: Task 3 (wire mode-package) + Task 4 (architect 3c) supaya invocation-nya nyambung.

- [ ] **Step 1: Buat file**

Tulis `plugin/skills/add-package/SKILL.md` PERSIS:
```markdown
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
\`\`\`yaml
  - name: <nama>
    path: <packages/<nama> | ../<nama>>
    repo_url: <isi untuk multi-repo, kosongkan untuk monorepo>
    type: package
    responsibility: "<ringkas>"
    consumers: []           # diisi fanout saat package dipakai
    mandatory_for: []       # app yang WAJIB pakai package ini; kosong = tidak wajib
    stack: {}               # diisi architect (langkah 4)
\`\`\`
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
```

(Catatan editor: blok ```` ```yaml ```` di dalam file ditulis sebagai fence biasa — di plan ini di-escape `\`\`\`` agar tak menutup contoh. Saat menulis file nyata, pakai fence ```` ``` ```` normal.)

- [ ] **Step 2: Verify**

Run: `sed -n 's/^description: //p' plugin/skills/add-package/SKILL.md | grep ': ' && echo "FAIL colon-space" || echo "colon-space OK"`
Run: `grep -c 'mode-package\|packages\[\]\|mandatory_for' plugin/skills/add-package/SKILL.md`
Expected: "colon-space OK"; count ≥ 3.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/add-package/SKILL.md
git commit -m "feat(add-package): new skill — conductor mirroring add-app, typecheck gate (H2 §5)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: `fanout` — baca packages[], PACKAGE NEW/TOUCHED, isi consumers[] (penulis tunggal)

**Files:**
- Modify: `plugin/skills/fanout/SKILL.md` (langkah 1, 2, 3, 4)

Spec §7.1 + §8.1. fanout = penulis tunggal `consumers[]`.

- [ ] **Step 1: langkah 1 — baca packages[]**

Old:
```
### 1. Baca input
Baca `control/features/<fitur>/business.md` + `control/workspace.yaml` (apps, capabilities, responsibility).
```
New:
```
### 1. Baca input
Baca `control/features/<fitur>/business.md` + `control/workspace.yaml` (apps, capabilities, responsibility, **packages** + consumers).
```

- [ ] **Step 2: langkah 2 — tambah deteksi package (sub-bullet baru, JANGAN renumber)**

Old:
```
- **Kalau ADA peran yang nggak ketampung app mana pun → mungkin butuh APP BARU.** Tantang dulu (anti-yes-man): beneran perlu app baru, atau scope-creep / bisa ditampung app existing? Lolos tantangan → tandai di output sebagai app `NEW` (langkah 4). `fanout` cuma **MENGUSULKAN**; yang nulis entri app + bring-up = skill `add-app` (dipanggil otomatis `feature`).
```
New:
```
- **Kalau ADA peran yang nggak ketampung app mana pun → mungkin butuh APP BARU.** Tantang dulu (anti-yes-man): beneran perlu app baru, atau scope-creep / bisa ditampung app existing? Lolos tantangan → tandai di output sebagai app `NEW` (langkah 4). `fanout` cuma **MENGUSULKAN**; yang nulis entri app + bring-up = skill `add-app` (dipanggil otomatis `feature`).
- **Kalau ADA kode-bareng yang dipakai >1 app** (mis. format uang, tipe domain bersama) → mungkin **SHARED PACKAGE**. Tantang (anti-yes-man): beneran shared >1 app, atau cukup 1 app saja? Lolos → tandai `PACKAGE NEW: <nama>` (langkah 4); diwujudkan `add-package` (dipanggil otomatis `feature`). **Kalau fitur menyentuh API package yang SUDAH ADA** → tandai `PACKAGE TOUCHED: <nama>` + tarik daftar consumer dari `packages[<nama>].consumers` (basis fan-IN; `plan` yang memutuskan BREAKING).
- **Isi `consumers[]` (penulis tunggal):** saat app terbukti memakai sebuah package (baru ATAU existing) → tambah nama app ke `packages[<pkg>].consumers` (idempotent, add-only-if-absent). Ini SATU-SATUNYA entry point pengisian `consumers[]`; `plan`/`breakdown` cuma membaca.
```

- [ ] **Step 3: langkah 3 — tambah item challenge**

Old:
```
- Ada peran yang nggak ketampung app mana pun → butuh app baru? (beneran perlu, atau scope-creep?)
```
New:
```
- Ada peran yang nggak ketampung app mana pun → butuh app baru? (beneran perlu, atau scope-creep?)
- Ada kode-bareng >1 app → butuh shared package? (beneran shared, atau cukup 1 app?) Ada API package existing yang disentuh → consumer mana yang kena?
```

- [ ] **Step 4: langkah 4 — tambah baris output package + catatan consumers**

Old:
```
<usulan-nama> (NEW — belum ada) : <peran>      # app baru; diwujudkan add-app
...
Dependency lintas-app: <... bila ada>
Urutan: <... bila ada>
```
New:
```
<usulan-nama> (NEW — belum ada) : <peran>      # app baru; diwujudkan add-app
<pkg> (PACKAGE NEW — belum ada) : <peran>      # shared package baru; diwujudkan add-package
<pkg> (PACKAGE TOUCHED) : <API yang disentuh> [consumers: <app1, app2>]   # basis fan-IN
...
Dependency lintas-app: <... bila ada>
Urutan: <... bila ada>
```

Old:
```
Lalu **update `capabilities`** app terkait di `control/workspace.yaml` (tambah kapabilitas baru yang diperkenalkan fitur ini). **Add-only-if-absent:** kalau kapabilitas sudah ada, jangan tambah lagi (re-run fanout nggak boleh bikin entri ganda). App bertanda `NEW` **JANGAN** ditulis ke `workspace.yaml` di sini — itu jatah `add-app`; `fanout` cuma update `capabilities` app **existing**.
```
New:
```
Lalu **update `capabilities`** app terkait di `control/workspace.yaml` (tambah kapabilitas baru yang diperkenalkan fitur ini) **dan `packages[].consumers`** (tambah app yang memakai package, add-only-if-absent). **Add-only-if-absent:** kalau sudah ada, jangan tambah lagi (re-run fanout nggak boleh bikin entri ganda). Unit bertanda `NEW`/`PACKAGE NEW` **JANGAN** ditulis ke `workspace.yaml` di sini — itu jatah `add-app`/`add-package`; `fanout` cuma update `capabilities` + `consumers` unit **existing**.
```

- [ ] **Step 5: Verify**

Run: `grep -n 'PACKAGE NEW\|PACKAGE TOUCHED\|consumers' plugin/skills/fanout/SKILL.md`
Expected: penanda + consumers muncul di langkah 2 & 4.

- [ ] **Step 6: Commit**

```bash
git add plugin/skills/fanout/SKILL.md
git commit -m "feat(fanout): detect PACKAGE NEW/TOUCHED, sole-writer of consumers[] (H2 §7.1/§8.1)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: `feature` — auto-invoke `add-package` loop saat PACKAGE NEW

**Files:**
- Modify: `plugin/skills/feature/SKILL.md` (langkah 2 + Catatan)

Spec §7.2. Setelah loop `add-app`, tambah loop `add-package` sebelum `plan`.

- [ ] **Step 1: Edit langkah 2 sub-bullet (tambah loop add-package)**

Old:
```
   - **Bila `fanout.md` nandain app `NEW` (belum ada):** untuk tiap app baru, invoke skill **`add-app <nama-app>`** (declare entri → `architect` → `wire`, semua gated) → tunggu beres. Baru lanjut ke `plan`. Saat `plan` jalan, app baru sudah ada di `workspace.yaml` **dan** sudah ter-wire.
```
New:
```
   - **Bila `fanout.md` nandain app `NEW` (belum ada):** untuk tiap app baru, invoke skill **`add-app <nama-app>`** (declare entri → `architect` → `wire`, semua gated) → tunggu beres.
   - **Bila `fanout.md` nandain `PACKAGE NEW` (belum ada):** untuk tiap package baru, invoke skill **`add-package <nama-pkg>`** (declare entri → `architect` → `wire` mode-package, semua gated) → tunggu beres.
   - Selesaikan SEMUA `add-app` lalu `add-package` dulu, **baru lanjut ke `plan`**. Saat `plan` jalan, app/package baru sudah ada di `workspace.yaml` (app ter-wire; package ter-typecheck).
```

- [ ] **Step 2: Edit Catatan (sebut package baru)**

Old:
```
- Prasyarat: app sudah di-`wire` (skeleton jalan: DB nyambung, FE↔BE ke-wire). Kalau `plan` mentok karena fondasi belum ada, jalankan `wire` dulu (setelah `architect`). Kalau fitur butuh app yang **BELUM ADA** sama sekali, itu ditangani `add-app` (dipicu otomatis dari `fanout` — lihat langkah 2).
```
New:
```
- Prasyarat: app sudah di-`wire` (skeleton jalan: DB nyambung, FE↔BE ke-wire). Kalau `plan` mentok karena fondasi belum ada, jalankan `wire` dulu (setelah `architect`). Kalau fitur butuh app yang **BELUM ADA** sama sekali, itu ditangani `add-app`; kalau butuh shared package yang **BELUM ADA**, ditangani `add-package` (keduanya dipicu otomatis dari `fanout` — lihat langkah 2).
```

- [ ] **Step 3: Verify**

Run: `grep -n 'add-package\|PACKAGE NEW' plugin/skills/feature/SKILL.md`
Expected: loop add-package di langkah 2 + catatan.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/feature/SKILL.md
git commit -m "feat(feature): auto-invoke add-package on PACKAGE NEW before plan (H2 §7.2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: `plan` — packages[]/consumers[] read, plans/<pkg>.md kontrak + BREAKING, dependency, M2 challenge

**Files:**
- Modify: `plugin/skills/plan/SKILL.md` (langkah 1, 2, 3, 4)

Spec §7.3 + §8.1 (deteksi BREAKING + carve-out package baru) + §9 (M2 challenge).

- [ ] **Step 1: langkah 1 — baca packages[]+consumers[] (read-only)**

Old:
```
### 1. Baca input
Baca `control/features/<fitur>/business.md` + `fanout.md` + `control/conventions.md` + `control/workspace.yaml` (untuk `path` & `stack` tiap app).
```
New:
```
### 1. Baca input
Baca `control/features/<fitur>/business.md` + `fanout.md` + `control/conventions.md` + `control/workspace.yaml` (untuk `path` & `stack` tiap app, **plus `packages[]` + `consumers[]` — read-only; `plan` tak pernah menulis `consumers[]`, itu jatah `fanout`**).
```

- [ ] **Step 2: langkah 2 — tambah sub-langkah kontrak package (plans/<pkg>.md + BREAKING + carve-out)**

Old:
```
### 3. Per app (untuk tiap app di fanout.md)
```
New:
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

### 3. Per app (untuk tiap app di fanout.md)
```

- [ ] **Step 3: langkah 3 — app consumer catat dependency + (M2 challenge ditambah di step 4 challenge)**

Old:
```
- Susun plan: file yang disentuh, endpoint/komponen, model data, test.
- **Challenge teknis** sebelum gate: konsistensi dengan konvensi? risiko? cara lebih sederhana? Apakah plan ini melanggar invarian yang terkunci di `control/invariants.md` (tenancy/money/idempotency/authz/PII-PCI)?
```
New:
```
- Susun plan: file yang disentuh, endpoint/komponen, model data, test. **Bila app mengonsumsi package** → catat dependency-nya (package apa, dipakai untuk apa) di plan app.
- **Challenge teknis** sebelum gate: konsistensi dengan konvensi? risiko? cara lebih sederhana? Apakah plan ini melanggar invarian yang terkunci di `control/invariants.md` (tenancy/money/idempotency/authz/PII-PCI)? **Apakah app ini membuat logika yang seharusnya pakai mandatory package** (mis. format uang sendiri padahal `money` ada di `packages[].mandatory_for` app ini)?
```

- [ ] **Step 4: langkah 4 — sebut output plans/<pkg>.md**

Old:
```
### 4. Tulis output (GATE per app)
Tulis `control/features/<fitur>/plans/<app>.md`:
```
New:
```
### 4. Tulis output (GATE per app/package)
Tulis `control/features/<fitur>/plans/<pkg>.md` (kontrak, langkah 2b) lalu `control/features/<fitur>/plans/<app>.md`:
```

- [ ] **Step 5: Verify**

Run: `grep -n 'plans/<pkg>.md\|BREAKING\|mandatory package\|read-only' plugin/skills/plan/SKILL.md`
Expected: kontrak package + BREAKING + carve-out + M2 challenge + read-only consumers.

- [ ] **Step 6: Commit**

```bash
git add plugin/skills/plan/SKILL.md
git commit -m "feat(plan): plans/<pkg>.md contract + BREAKING/carve-out + M2 challenge (H2 §7.3/§8.1/§9)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: `breakdown` — rename task.app→task.unit, gate eksplisit, fan-IN task-gen, M2, package-task rules

**Files:**
- Modify: `plugin/skills/breakdown/reference.md` (skema + contoh + integrasi + fan-IN)
- Modify: `plugin/skills/breakdown/SKILL.md` (langkah 1, 3, 4)

Spec §7.4 + §8.2 + §9. **Rename adalah bagian paling rawan — grep-verify ketat di Step akhir.**

- [ ] **Step 1: `breakdown/reference.md` — rename field `app:`→`unit:` (HINDARI blind replace_all — line 58 "2 app: api + web" itu prosa, BUKAN field). Terapkan pasangan berikut, urut:**

  - **1a — heading §C (buang "app: " non-field):** `## C. Contoh (fitur \`auth\`, 2 app: api + web)` → `## C. Contoh (fitur \`auth\`, 2 app — api + web)`
  - **1b — `replace_all` `app: api` → `unit: api`** (4 baris contoh T1/T2/T3/T4)
  - **1c — `replace_all` `app: web` → `unit: web`** (2 baris contoh T5/T6)
  - **1d — skema (line 15):** `        app: <nama app>            # cocok dengan apps[].name di workspace.yaml` → `        unit: <nama app/pkg>        # cocok dengan apps[].name ATAU packages[].name; atau "integration"`
  - **1e — integrasi (line 36):** `        app: integration           # pseudo-app — gate-nya membentang beberapa tree, tak punya path sendiri` → `        unit: integration           # pseudo-unit — gate-nya membentang beberapa tree, tak punya path sendiri`
  - **1f — §D-3 (line 157) — rename + APPEND item §D-4 fan-IN:**

Old:
```
3. **Task integrasi (`app: integration`).** Untuk tiap dependency lintas-app di `_shared.md`/`fanout.md`, munculkan SATU task integrasi: `deps` ke KEDUA sisi kontrak, `test` = roundtrip end-to-end nyata. Pseudo-app `integration` tak punya `path`/repo sendiri (jalan di atas repo app-app di `deps`-nya). Fitur 1-app tanpa `_shared.md` → tidak perlu.
```
New:
```
3. **Task integrasi (`unit: integration`).** Untuk tiap dependency lintas-app di `_shared.md`/`fanout.md`, munculkan SATU task integrasi: `deps` ke KEDUA sisi kontrak, `test` = roundtrip end-to-end nyata. Pseudo-unit `integration` tak punya `path`/repo sendiri (jalan di atas repo unit di `deps`-nya). Fitur 1-app tanpa `_shared.md` → tidak perlu.
4. **Task package & fan-IN.** Task yang hidup di shared package → `unit: <nama-pkg>` (cocok `packages[].name`); **DILARANG** `actions: [migrate]`/`actions: [env]` (package tak punya DB/infra); `test` = typecheck/unit exports. **Fan-IN (saat `plans/<pkg>.md` ber-flag `BREAKING`):** terbitkan 1 task `unit: <pkg>` (ubah package) + **1 update-task per consumer** (`unit: <consumer-app>`, `deps: [task-pkg]`) untuk tiap nama di `packages[<pkg>].consumers` + 1 task `unit: integration` (roundtrip package↔consumer). Pseudo-unit `integration` diperluas mencakup roundtrip package↔consumer (boot consumer app, panggil exports package, assert sesuai kontrak `plans/<pkg>.md`).
```

- [ ] **Step 2: `breakdown/SKILL.md` — rename sisa field `app: integration` (langkah 4 task integrasi)**

Old:
```
- **Task integrasi:** untuk tiap dependency lintas-app di `_shared.md`/`fanout.md`, munculkan satu task `app: integration` (`deps` ke KEDUA sisi, `test` = roundtrip end-to-end). Fitur 1-app tanpa `_shared.md` → skip.
```
New:
```
- **Task integrasi:** untuk tiap dependency lintas-app di `_shared.md`/`fanout.md`, munculkan satu task `unit: integration` (`deps` ke KEDUA sisi, `test` = roundtrip end-to-end). Fitur 1-app tanpa `_shared.md` → skip.
```

- [ ] **Step 3: reference.md — tambah contoh task package di §C (setelah T6 web, sebelum milestone M2)**

Old:
```
        deps: [T3]
        status: pending
  - id: M2
    title: Password lifecycle (forgot / reset / change)
```
New:
```
        deps: [T3]
        status: pending
      - id: T_PKG
        unit: money                  # shared package (packages[].name) — bukan app
        desc: util formatMoney + parseMoney (dipakai web + api)
        files:
          - create: src/index.ts
          - test:   test/money.test.ts
        approach: format minor-unit ke string lokal; tanpa DB/route
        test:
          - format 100050 -> "Rp 1.000,50"
          - typecheck hijau
        deps: []
        status: pending
  - id: M2
    title: Password lifecycle (forgot / reset / change)
```

- [ ] **Step 4: SKILL.md langkah 1 — baca packages[]**

Old:
```
Baca `control/features/<fitur>/plans/_shared.md` + `plans/<app>.md` + `fanout.md` (untuk Urutan lintas-app) + `control/workspace.yaml` (app/path/stack). **Prasyarat:** `feature.yaml` `status: active`.
```
New:
```
Baca `control/features/<fitur>/plans/_shared.md` + `plans/<pkg>.md` + `plans/<app>.md` + `fanout.md` (untuk Urutan lintas-app) + `control/workspace.yaml` (app/path/stack + `packages[]`/`consumers`). **Prasyarat:** `feature.yaml` `status: active`. **Validasi unit (GATE eksplisit):** tiap `task.unit` HARUS cocok `apps[].name` ATAU `packages[].name` ATAU `integration`; kalau tidak → STOP + saran (`add-app`/`add-package`/typo). (Dulu kendala ini laten → gagal telat di `build`; sekarang dicek di depan.)
```

- [ ] **Step 5: SKILL.md langkah 4 — coverage fan-IN + M2 challenge**

Old:
```
- **Invarian:** tiap task yang nyentuh skema/endpoint patuh `control/invariants.md` (mis. table baru bawa `tenant_id` bila tenancy shared-db; uang pakai representasi yang dikunci)? Tandai task yang berisiko melanggar.
```
New:
```
- **Invarian:** tiap task yang nyentuh skema/endpoint patuh `control/invariants.md` (mis. table baru bawa `tenant_id` bila tenancy shared-db; uang pakai representasi yang dikunci)? Tandai task yang berisiko melanggar. **Mandatory package (M2):** task yang bikin logika yang seharusnya pakai package di `packages[].mandatory_for` → tandai melanggar (redirect ke package).
- **Fan-IN coverage:** kalau `plans/<pkg>.md` ber-flag `BREAKING`, tiap consumer di `packages[<pkg>].consumers` WAJIB punya ≥1 task (update-task `unit: <consumer>` atau ter-cover task `unit: integration`). (Skema fan-IN: `reference.md` §D-4.)
```

- [ ] **Step 6: Verify (KETAT — rename + fitur)**

Run: `grep -rn 'app: ' plugin/skills/breakdown/ && echo "FAIL stale app:" || echo "rename OK (no stale app: field)"`
Run: `grep -n 'unit:\|pseudo-unit\|D-4\|mandatory package\|BREAKING' plugin/skills/breakdown/SKILL.md plugin/skills/breakdown/reference.md`
Expected: "rename OK"; `unit:` + pseudo-unit + fan-IN (§D-4) + M2 + BREAKING semua muncul.

- [ ] **Step 7: Commit**

```bash
git add plugin/skills/breakdown/SKILL.md plugin/skills/breakdown/reference.md
git commit -m "feat(breakdown): task.unit rename + explicit gate + fan-IN task-gen + M2 (H2 §7.4/§8.2/§9)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: `build` — resolusi path packages[], dispatch package, cheap-skip consumer, M2

**Files:**
- Modify: `plugin/skills/build/SKILL.md` (langkah 1, 3, 6)
- Modify: `plugin/skills/build/reference.md` (§B, §F)

Spec §7.5 + §8.3 + §9. Termasuk rename field `app: integration`→`unit: integration` + prose "app NYATA"→"unit NYATA".

- [ ] **Step 1: SKILL.md langkah 1 — branch per repo: unit NYATA (app/package)**

Old:
```
- **Branch per repo (multi-repo aware):** untuk tiap app NYATA yang kena (dari `tasks.yaml`/`fanout.md`, **KECUALI pseudo-app `integration`** yang tak punya `path` sendiri), resolve `path` dari `workspace.yaml` lalu probe `git -C <path> rev-parse --show-toplevel`.
```
New:
```
- **Branch per repo (multi-repo aware):** untuk tiap unit NYATA yang kena (app ATAU package, dari `tasks.yaml`/`fanout.md`, **KECUALI pseudo-unit `integration`** yang tak punya `path` sendiri), resolve `path` dari `workspace.yaml` — `unit ∈ apps[]` → `apps[].path`; `unit ∈ packages[]` → `packages[].path` — lalu probe `git -C <path> rev-parse --show-toplevel`.
```

- [ ] **Step 2: SKILL.md langkah 3 — dispatch: integration field rename + package dispatch + cheap-skip**

Old:
```
**Bila `app: integration`:** ini BUKAN edit satu app — dispatch subagent yang mem-boot app-app di `deps` (pakai `path`/`stack` `workspace.yaml`), jalankan `test` roundtrip nyata terhadap kontrak `_shared.md`, balik ringkasan + status. Gate-nya (step 6) membentang tree app-app terkait, bukan satu app.
```
New:
```
**Bila `unit: integration`:** ini BUKAN edit satu app — dispatch subagent yang mem-boot app-app di `deps` (pakai `path`/`stack` `workspace.yaml`), jalankan `test` roundtrip nyata terhadap kontrak `_shared.md`/`plans/<pkg>.md`, balik ringkasan + status. Gate-nya (step 6) membentang tree unit terkait, bukan satu app.

**Bila `unit` = package** (`unit ∈ packages[]`): dispatch = typecheck + test exports package (BUKAN boot/smoke app); resolve `path` dari `packages[].path`. **Fan-IN cheap-skip:** untuk update-task consumer (`deps: [task-pkg]` dari perubahan package `BREAKING`), subagent CEK dulu "consumer ini beneran memakai export yang berubah?" — kalau **tidak** → tandai no-op, pastikan typecheck hijau, selesai cepat (tak ada perubahan kode). Enumerasi tetap semua consumer (aman); biaya per-consumer murah.
```

- [ ] **Step 2b: `build` — rename sisa field `app: integration` → `unit: integration` (3 tempat)**

  - **SKILL.md (verify, line 34):** `Untuk task \`app: integration\`: verify = commit maju di SETIAP repo app yang ada di \`deps\` + jalankan ulang \`test\` roundtrip (bukan satu "test app" tunggal).` → ganti `\`app: integration\`` jadi `\`unit: integration\`` di awal kalimat itu (sisanya tetap).
  - **SKILL.md (klausa gate-segmen, line 43 — substring BERBEDA dari Step 3):** `Task \`app: integration\` membentuk segmen gate sendiri yang membentang tree app-app di \`deps\`-nya (bukan satu app × milestone).` → `Task \`unit: integration\` membentuk segmen gate sendiri yang membentang tree unit di \`deps\`-nya (bukan satu app × milestone).`
  - **reference.md (§B subsection heading, line 44):** `### Task integrasi (\`app: integration\`)` → `### Task integrasi (\`unit: integration\`)`

- [ ] **Step 3: SKILL.md langkah 6 — M2 challenge di gate**

Old:
```
Semua task satu segmen (default **app × milestone**) `done` → **BERHENTI**: tampilkan diff segmen + hasil test + "dibangun vs task" + **challenge checklist** (termasuk: ada yang melanggar invarian terkunci di `control/invariants.md`?) → minta **approve/revisi**.
```
New:
```
Semua task satu segmen (default **app × milestone**) `done` → **BERHENTI**: tampilkan diff segmen + hasil test + "dibangun vs task" + **challenge checklist** (termasuk: ada yang melanggar invarian terkunci di `control/invariants.md`? ada yang membypass mandatory package di `packages[].mandatory_for`?) → minta **approve/revisi**.
```

- [ ] **Step 4: reference.md §B — field `app`→`unit` (dua tempat)**

Old:
```
- **Task:** `desc` + `app`.
```
New:
```
- **Task:** `desc` + `unit` (app/package/integration).
```

Old:
```
Task: POST /auth/register (app: api)
```
New:
```
Task: POST /auth/register (unit: api)
```

- [ ] **Step 5: reference.md §F — unit NYATA + pseudo-unit + package probe**

Old:
```
Probe identitas repo tiap app NYATA: `git -C <path> rev-parse --show-toplevel`.
```
New:
```
Probe identitas repo tiap unit NYATA (app ATAU package; resolve `path` dari `apps[]`/`packages[]`): `git -C <path> rev-parse --show-toplevel`.
```

Old:
```
Implementer subagent commit di repo app-nya (`git -C <path>`). `build` memastikan branch ada SEBELUM dispatch task yang nulis ke repo itu. **Pseudo-app `integration` dilewati** saat probe/branch (tak punya `path`/repo sendiri); ia jalan di atas repo app-app di `deps`-nya yang branch-nya sudah dibuat. Eksekusi tetap sekuensial sesuai `deps` (tak ada dua subagent nulis tree sama serempak).
```
New:
```
Implementer subagent commit di repo unit-nya (`git -C <path>`). `build` memastikan branch ada SEBELUM dispatch task yang nulis ke repo itu. **Pseudo-unit `integration` dilewati** saat probe/branch (tak punya `path`/repo sendiri); ia jalan di atas repo unit di `deps`-nya yang branch-nya sudah dibuat. Package mono-repo (`path = packages/<nama>`) ciut ke toplevel hub; multi-repo (`path = ../<nama>`) dapat branch+PR sendiri — sama seperti app. Eksekusi tetap sekuensial sesuai `deps` (tak ada dua subagent nulis tree sama serempak).
```

- [ ] **Step 6: Verify (rename + fitur)**

Run: `grep -rn 'app: ' plugin/skills/build/ && echo "FAIL stale app: field" || echo "rename OK (no stale app: field)"`
Run: `grep -n 'unit: integration\|unit ∈ packages\|cheap-skip\|mandatory package\|pseudo-unit' plugin/skills/build/SKILL.md plugin/skills/build/reference.md`
Expected: "rename OK (no stale app: field)"; `unit: integration` + package path-resolve + cheap-skip + M2 + pseudo-unit muncul.

- [ ] **Step 7: Commit**

```bash
git add plugin/skills/build/SKILL.md plugin/skills/build/reference.md
git commit -m "feat(build): package path-resolve + dispatch + fan-IN cheap-skip + M2 (H2 §7.5/§8.3/§9)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: `ship` — baca packages[], probe repo package, grouping PR

**Files:**
- Modify: `plugin/skills/ship/SKILL.md` (langkah 1, 6)

Spec §8.5.

- [ ] **Step 1: langkah 1 — baca packages[]**

Old:
```
Baca `control/features/<fitur>/feature.yaml` (harus `status: active`, + field `sensitivity`), `business.md`, `fanout.md`, `plans/*`. Tentukan app yang kena dari `fanout.md` + `path`/`stack` dari `control/workspace.yaml`.
```
New:
```
Baca `control/features/<fitur>/feature.yaml` (harus `status: active`, + field `sensitivity`), `business.md`, `fanout.md`, `plans/*`. Tentukan **unit** (app ATAU package) yang kena dari `fanout.md`/`tasks.yaml` + `path`/`stack` dari `control/workspace.yaml` (`apps[]` + `packages[]`).
```

- [ ] **Step 2: langkah 6 — probe repo unit (app+package)**

Old:
```
- Tentukan **repo unik** yang kena: probe `git -C <path> rev-parse --show-toplevel` tiap app NYATA, kelompokkan per toplevel. Bikin **satu PR per repo unik** (monorepo/nested → otomatis 1 PR karena toplevel sama; multi-repo → 1 PR per repo).
```
New:
```
- Tentukan **repo unik** yang kena: probe `git -C <path> rev-parse --show-toplevel` tiap unit NYATA (app ATAU package; resolve `path` dari `apps[]`/`packages[]`), kelompokkan per toplevel. Bikin **satu PR per repo unik** (monorepo/nested → otomatis 1 PR karena toplevel sama; multi-repo → 1 PR per repo). Update-task consumer (fan-IN) sudah masuk `tasks.yaml` → repo consumer otomatis ikut grouping.
```

- [ ] **Step 3: Verify**

Run: `grep -n 'packages\[\]\|unit NYATA' plugin/skills/ship/SKILL.md`
Expected: baca packages[] + probe unit NYATA.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/ship/SKILL.md
git commit -m "feat(ship): probe package repos + package-aware PR grouping (H2 §8.5)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: `render-docs` — kartu package di HTML

**Files:**
- Modify: `plugin/skills/render-docs/SKILL.md` (langkah 1, 3)

Spec §10.1.

- [ ] **Step 1: langkah 1 — baca packages[]**

Old:
```
- `control/workspace.yaml` → `product`, `topology`, daftar `apps` (name, type, responsibility, capabilities, stack).
```
New:
```
- `control/workspace.yaml` → `product`, `topology`, daftar `apps` (name, type, responsibility, capabilities, stack) + daftar `packages` (name, responsibility, consumers, mandatory_for).
```

- [ ] **Step 2: langkah 3 — slot kartu package**

Old:
```
- **apps:** satu `.card` per app: judul `name` + `type`, `responsibility`, lalu `capabilities` sebagai `.chip`.
```
New:
```
- **apps:** satu `.card` per app: judul `name` + `type`, `responsibility`, lalu `capabilities` sebagai `.chip`.
- **packages:** satu `.card` per shared package (bila ada): judul `name` + label "package", `responsibility`, `consumers` (app yang memakai) sebagai `.chip`, tandai `mandatory_for` bila ada. Bedakan visual dari kartu app.
```

- [ ] **Step 3: Verify**

Run: `grep -n -i 'packages\|consumers' plugin/skills/render-docs/SKILL.md`
Expected: baca packages + slot kartu package.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/render-docs/SKILL.md
git commit -m "feat(render-docs): package cards in HTML output (H2 §10.1)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 13: `drop` — drop-package + bersihkan consumers[] saat drop app

**Files:**
- Modify: `plugin/skills/drop/SKILL.md` (langkah 3 + Catatan)

Spec §10.2.

- [ ] **Step 1: langkah 3 — drop app bersihkan consumers[]**

Old:
```
### 3. Review promosi knowledge
Identifikasi knowledge durable yang sempat disumbang fitur ini: aturan di `control/business/`, `capabilities` di `control/workspace.yaml`. Invoke subagent `critic` untuk bantu pilah: mana yang **feature-specific** (kandidat revert) vs **benar lepas dari fitur** (keep). Tanyakan ke user keep/revert per item, lalu terapkan.
```
New:
```
### 3. Review promosi knowledge
Identifikasi knowledge durable yang sempat disumbang fitur ini: aturan di `control/business/`, `capabilities` di `control/workspace.yaml`. Invoke subagent `critic` untuk bantu pilah: mana yang **feature-specific** (kandidat revert) vs **benar lepas dari fitur** (keep). Tanyakan ke user keep/revert per item, lalu terapkan.
- **Bila fitur ini bikin app/package baru yang ikut di-drop:** kalau sebuah **app** dihapus, bersihkan namanya dari semua `packages[].consumers` + `mandatory_for` (jangan tinggalkan consumer hantu yang bikin fan-IN salah-target).
```

- [ ] **Step 2: Catatan — drop-package**

Old:
```
## Catatan
- Folder fitur `dropped` tetap ada agar keputusan & alasannya tidak dibahas ulang di kemudian hari.
```
New:
```
## Catatan
- Folder fitur `dropped` tetap ada agar keputusan & alasannya tidak dibahas ulang di kemudian hari.
- **drop-package** (hapus shared package dari `packages[]`): hanya bila package **tak punya `consumers`** dan tak ada di `mandatory_for` app aktif — kalau masih dipakai → **STOP/warn** (jangan drop package yang masih dipakai). Promosi knowledge ditinjau sama seperti drop app.
```

- [ ] **Step 3: Verify**

Run: `grep -n -i 'drop-package\|consumers\|mandatory_for' plugin/skills/drop/SKILL.md`
Expected: bersihkan consumers (langkah 3) + drop-package (Catatan).

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/drop/SKILL.md
git commit -m "feat(drop): drop-package + clean consumers[] on app drop (H2 §10.2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 14: `conventions.md` template — heading Konvensi Package

**Files:**
- Modify: `plugin/template/control/conventions.md`

Spec §10.3.

- [ ] **Step 1: Tambah heading**

Old:
```
# <PRODUCT> — Konvensi & Kontrak Teknis Lintas-App

<!-- Diisi oleh skill architect. Contoh: mekanisme auth token web<->api,
     format API, shared package, ORM standar. -->
```
New:
```
# <PRODUCT> — Konvensi & Kontrak Teknis Lintas-App

<!-- Diisi oleh skill architect. Contoh: mekanisme auth token web<->api,
     format API, shared package, ORM standar. -->

## Konvensi Package
<!-- Diisi architect saat add-package: path import, build/test tool, sinyal breaking/deprecation. -->
```

- [ ] **Step 2: Verify**

Run: `grep -n 'Konvensi Package' plugin/template/control/conventions.md`
Expected: heading muncul.

- [ ] **Step 3: Commit**

```bash
git add plugin/template/control/conventions.md
git commit -m "feat(template): conventions.md package-conventions heading (H2 §10.3)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 15: Amandemen spec induk (`2026-05-24-ai-first-boilerplate-design.md`)

**Files:**
- Modify: `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§7.1, §12 cabang note, §17)

Spec §12.1. (Pelajaran L1: amandemen yang dijanjikan spec turunan WAJIB beneran masuk.)

- [ ] **Step 1: §7.1 — tambah packages[] ke skema workspace.yaml**

Old:
```
    capabilities: [auth, workspace]   # tumbuh per fitur (fanout)
    stack: { framework: Next.js, db: Postgres }   # diisi architect
```
```
- `capabilities` = bahan bakar fan-out (P1). Diisi bertahap oleh `fanout` (greenfield) atau lebih awal oleh `architect` (brownfield).
```
New:
```
    capabilities: [auth, workspace]   # tumbuh per fitur (fanout)
    stack: { framework: Next.js, db: Postgres }   # diisi architect
packages:                            # shared package (H2) — diisi add-package
  - name: money
    path: packages/money
    type: package
    responsibility: "format dan hitung uang"
    consumers: [web, api]            # diisi fanout; basis fan-IN
    mandatory_for: []                # app yang wajib pakai package ini
```
```
- `capabilities` = bahan bakar fan-out (P1). Diisi bertahap oleh `fanout` (greenfield) atau lebih awal oleh `architect` (brownfield).
- `packages` = shared code lintas-app (H2). Entri ditulis `add-package`; `consumers` (basis fan-IN) ditulis `fanout`. Lihat spec `2026-06-01-h2-shared-package-design.md`.
```

- [ ] **Step 2: §12 — cabang lifecycle add-package**

Old:
```
**Cabang dipicu — fitur butuh app baru:** bila `fanout` mendeteksi tidak ada app existing yang menampung sebuah peran, `feature` otomatis invoke **`add-app`** (declare entri ke `workspace.yaml` → `architect` → `wire`) sebelum `plan`. `add-app` juga bisa dipanggil standalone. Lihat spec `2026-05-31-add-app-skill-design.md`.
```
New:
```
**Cabang dipicu — fitur butuh app baru:** bila `fanout` mendeteksi tidak ada app existing yang menampung sebuah peran, `feature` otomatis invoke **`add-app`** (declare entri ke `workspace.yaml` → `architect` → `wire`) sebelum `plan`. `add-app` juga bisa dipanggil standalone. Lihat spec `2026-05-31-add-app-skill-design.md`.

**Cabang dipicu — fitur butuh shared package baru:** bila `fanout` menandai kode-bareng >1 app sebagai `PACKAGE NEW`, `feature` otomatis invoke **`add-package`** (declare entri ke `packages[]` → `architect` → `wire` mode-package, gate typecheck) sebelum `plan`. Saat API shared package berubah, `breakdown` menerbitkan update-task per consumer (fan-IN). Task hidup di `unit` (app ATAU package). Lihat spec `2026-06-01-h2-shared-package-design.md`.
```

- [ ] **Step 3: §17 — skill 15→16 + packages[]**

Old:
```
- **Skills (15):** `discovery` · `init` · `architect` · `wire` · `add-app` · `extract` · `feature` (→ `intake` · `fanout` · `plan`) · `breakdown` · `build` · `ship` · `drop` · `render-docs`
```
New:
```
- **Skills (16):** `discovery` · `init` · `architect` · `wire` · `add-app` · `add-package` · `extract` · `feature` (→ `intake` · `fanout` · `plan`) · `breakdown` · `build` · `ship` · `drop` · `render-docs`
```

Old:
```
- **Knowledge (`control/`):** `workspace.yaml` · `business/` · `conventions.md` · `invariants.md` · `features/` · `docs/`
```
New:
```
- **Knowledge (`control/`):** `workspace.yaml` (apps[] + packages[]) · `business/` · `conventions.md` · `invariants.md` · `features/` · `docs/`
```

- [ ] **Step 4: Verify**

Run: `grep -n 'add-package\|packages\|Skills (16)' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md | head`
Run: `sed -n 's/^description: //p' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md | grep ': ' || echo "no frontmatter desc (spec) OK"`
Expected: §7.1 packages[] + §12 cabang + §17 (16 + packages[]).

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
git commit -m "docs(spec): amend parent design for H2 (packages[], add-package branch, §17 16 skills)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 16: Amandemen spec Langkah-1 — tandai M2 mandatory-package direalisasikan

**Files:**
- Modify: `docs/superpowers/specs/2026-06-01-platform-invariants-security-gate-design.md` (§8, §12)

Spec §12.2.

- [ ] **Step 1: §8 — update "Sengaja dipotong"**

Old:
```
**Sengaja dipotong:** klausa "membypass mandatory package" dari rekomendasi audit — itu butuh H2/`packages[]` yang **belum ada**. Menambahkannya sekarang = pointer ke artifact fiktif (langgar caveat koherensi audit). Masuk di Langkah 2.
```
New:
```
**Sengaja dipotong (Langkah 1):** klausa "membypass mandatory package" — saat itu butuh H2/`packages[]` yang belum ada. **Direalisasikan di H2** (`docs/superpowers/specs/2026-06-01-h2-shared-package-design.md` §9): field `packages[].mandatory_for` + 1 baris challenge "membypass mandatory package?" di `plan`/`breakdown`/`build`.
```

- [ ] **Step 2: §12 — update pointer**

Old:
```
Spec berikutnya menggarap akar yang merembet & governance evolusi: **H2** (`packages[]` + skill `add-package` + fan-IN), **M5** (`control/integrations.md` + plan promote vendor + webhook-idempotency bar), **M4** (`control/schema/<app>.md` sebagai projeksi ter-generate dari migrations), **H3** (impact-analysis migrasi lintas-fitur + `migrate.kind/affects`). M2-bagian "mandatory package" menyusul bersama H2.
```
New:
```
Spec berikutnya menggarap akar yang merembet & governance evolusi: **H2** (`packages[]` + skill `add-package` + fan-IN) — **sudah dispec & direalisasikan** (`2026-06-01-h2-shared-package-design.md`), termasuk M2-bagian "mandatory package". Berikutnya: **M5** (`control/integrations.md` + plan promote vendor + webhook-idempotency bar), **M4** (`control/schema/<app>.md` sebagai projeksi ter-generate dari migrations), **H3** (impact-analysis migrasi lintas-fitur + `migrate.kind/affects`).
```

- [ ] **Step 3: Verify**

Run: `grep -n 'Direalisasikan di H2\|sudah dispec' docs/superpowers/specs/2026-06-01-platform-invariants-security-gate-design.md`
Expected: kedua amandemen muncul.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-06-01-platform-invariants-security-gate-design.md
git commit -m "docs(spec): mark M2 mandatory-package realized by H2 (Langkah-1 §8/§12)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 17: Verifikasi akhir (grep-battery + coherence + dry-run)

**Files:** none (verifikasi lintas-file)

Spec §14. Jalankan SETELAH semua task. Tak ada commit kode; kalau ada temuan → balik fix task terkait.

- [ ] **Step 1: Grep-battery konsistensi**

Run:
```bash
grep -rln 'add-package' plugin/skills/*/SKILL.md            # add-package + fanout/feature/wire/architect/add-app
grep -rln 'packages' plugin/skills/*/SKILL.md               # init,fanout,plan,breakdown,build,ship,render-docs,wire,drop,add-package
grep -rn 'app: ' plugin/skills/breakdown/ plugin/skills/build/ && echo "FAIL stale app: field (breakdown/build)" || echo "rename complete"
grep -rn 'task\.app\|app: integration' plugin/skills/ && echo "FAIL stray field ref" || echo "no stray task.app/app: integration anywhere"
```
Expected: add-package dirujuk lintas skill; packages dibaca di skill yang diklaim §11; **"rename complete"** + **"no stray task.app/app: integration anywhere"** (rename tuntas lintas skill).

- [ ] **Step 2: Colon-space guard (frontmatter SEMUA skill yang disentuh)**

Run:
```bash
for f in init add-app wire architect add-package fanout feature plan breakdown build ship render-docs drop; do
  sed -n 's/^description: //p' plugin/skills/$f/SKILL.md | grep ': ' && echo "FAIL $f" ;
done; echo "colon-space scan done"
```
Expected: tak ada "FAIL"; "colon-space scan done".

- [ ] **Step 3: Coherence guard (CRITICAL — tak nyandar artifact fiktif)**

Run: `grep -rn 'integrations\.md\|control/schema\|data-model\.md\|roadmap\.yaml' plugin/skills/ plugin/template/`
Expected: **kosong** (H2 tak menyentuh artifact Langkah-2 lain). Kalau ada → BUG, hapus.

- [ ] **Step 4: Mis-aimed pointer check**

Periksa tiap pointer yang ditulis plan ini menunjuk target benar:
- `wire/reference.md §I` ada (Task 3).
- `breakdown/reference.md §D-4` ada (Task 9 Step 2).
- `architect` langkah `3c` ada (Task 4).
- `2026-05-31-add-app-skill-design.md` (di add-package) = file nyata.
Run: `grep -n 'reference §I\|§D-4\|langkah 3c\|3c\.' plugin/skills/add-package/SKILL.md plugin/skills/breakdown/SKILL.md plugin/skills/wire/SKILL.md`
Expected: pointer ada & target-nya (section yang dibuat di task terkait) eksis.

- [ ] **Step 5: Dry-run skenario (baca-telusur, bukan eksekusi)**

Telusuri mental tiap alur, pastikan skill-text mendukungnya:
- (a) `fanout` lihat kode-bareng → `PACKAGE NEW` + challenge → `feature` auto-invoke `add-package`.
- (b) `add-package` idempotent (package sudah ada → STOP).
- (c) `breakdown` `task.unit: <pkg>` → lolos gate; `unit` ngaco → STOP.
- (d) fitur ubah signature package ber-consumer → `plan` flag `BREAKING` → `breakdown` terbitkan update-task tiap consumer + integration.
- (e) `build` consumer tak-kena → no-op cepat (cheap-skip).
- (f) app membypass `mandatory_for` → challenge STOP (plan/breakdown/build).
- (g) `drop-package` saat masih ada consumer → STOP.
- (h) package baru di fitur yang sama → TIDAK ada BREAKING (carve-out plan §2b).

- [ ] **Step 6: 1 ronde baca-adversarial di SESI TERPISAH**

Catatan untuk pelaksana: setelah merge-candidate siap, jalankan 1 agen adversarial fresh di sesi lain khusus: mis-aimed pointer `skill→reference`/`§X`, staleness parent/Langkah-1 spec, **kelengkapan rename `task.unit`** (grep `\.app`/`app:` di seluruh konteks tasks.yaml + reader manapun). Pelajaran berulang: verify sesi-eksekusi sendiri melewatkan kelas-bug ini (sudah 5× kejadian).

---

## Catatan eksekusi & handoff

- **Urutan task = urutan dependency.** Task 3/4 (wire/architect mode) sebelum Task 5 (add-package invoke keduanya). Task 1 (packages[] schema) paling dulu.
- **Bagian paling rawan = Task 9 & 10 (rename `task.app`→`task.unit`).** Grep-verify "no stale app:" di Step 6 tiap task + Step 1/4 Task 17. Kalau ragu, baca ulang file penuh sebelum commit.
- **Fan-IN dormant:** Task 8/9/10 memuat logika fan-IN; baru aktif saat ada package `BREAKING`. Pipeline fan-OUT fungsional sejak Task 14.
- Setelah Task 17 hijau → `finishing-a-development-branch` (user putuskan; biasanya FF-merge + push ke `origin/main`, hapus branch). Lalu update memory + handoff.
