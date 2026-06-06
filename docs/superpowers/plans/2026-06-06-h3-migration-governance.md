# H3 — Migration Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (sesi terpisah, per handoff). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bikin gate migrasi `build` jadi **sadar-dampak** (siapa pembaca tabel + risiko lock + perlu-backfill + saran expand-contract), tambah peringatan dini di `plan`, runbook urutan deploy di `ship`, dan konvensi zero-downtime — lewat satu shared rule `rules/migration-impact.md` (read-only analisis). Semua **advisory**. Tutup gap H3 (terakhir Langkah-2) tanpa nambah skill (tetap 21).

**Architecture:** Consumer-of-table diturunkan **runtime** dari kode (di-bibit FK M4 `control/schema/`), bukan disimpan. Isian migrasi tegas: `breakdown` nulis `migrate.kind`(additive|destructive|backfill)+`affects`([tabel/kolom]). `rules/migration-impact.md` = prosedur ANALISIS generik (read-only — TAK nulis file). Dipanggil `plan` (dini, degrade OFF pra-M4) + `build` (gate apply, diperkaya). `ship` agregasi runbook migrasi/deploy ke PR (advisory). `conventions.md` dapat heading expand-contract. Anchor ke M4 — **BUKAN** `packages[].consumers`, **BUKAN** `data-model.md`/`roadmap.yaml`. Spec: `docs/superpowers/specs/2026-06-06-h3-migration-governance-design.md`.

**Tech Stack:** Markdown skill/rule files + YAML schema (doc). Tak ada kode runtime. "Test" = grep-battery anchor verification (analog TDD untuk file instruksi) + coherence read.

**Branch:** `h3-migration-governance` (sudah dibuat; spec sudah di-commit @ `28d8865`). Eksekusi & post-exec verify = **sesi terpisah** (jangan execute di sesi penulisan plan).

**Bug-guard pre-bake (berlaku semua task):**
- **colon-space frontmatter:** H3 TAK menyentuh `description:` SKILL.md mana pun (cuma body) → nol risiko; bila terpaksa, ` — ` bukan `: `.
- **no-renumber:** semua sisipan = klausa/sub-bullet/sibling-line/heading baru — **JANGAN** renumber langkah/step skill.
- **`kind` collision:** breakdown/reference.md sudah punya `kind:` level-task (feat|fix|debt) §B. `migrate.kind` H3 = `kind:` action-scoped (sibling di bawah `- migrate:`). JANGAN grep telanjang `kind:` di file itu (ambigu); anchor via baris `- migrate: <deskripsi>` + verifikasi nesting visual.
- **mis-aimed-pointer:** verifikasi tiap `§X` nunjuk seksi benar (induk §8/§17/§9; breakdown §A/§B/§D).
- **anchor verify:** tiap find/replace di-`grep -Fc -e`-kan verbatim (robust leading-dash `- `, metachar `[]`/`**`/backtick, em-dash `—` vs arrow `→`, middot `·` U+00B7) SEBELUM commit.
- **anti-fiksi/anti-overload:** consumer dari `control/schema/`/scan-kode, BUKAN `packages[].consumers`/`data-model.md`/`roadmap.yaml`. Match pre-existing `packages[<pkg>].consumers` di breakdown §D-4 = H2, EXPECTED, jangan disentuh.
- **anti-palang-keras:** runbook/expand-contract/`WAJIB` = advisory/authoring — JANGAN tambah cek-blokir/STOP runtime (selain gate apply existing).
- **skill-count:** TETAP 21 — `plugin.json`/`marketplace.json`/README **TIDAK** disentuh.
- Tiap commit diakhiri trailer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

### Task 1: NEW rule `rules/migration-impact.md`

**Files:**
- Create: `plugin/rules/migration-impact.md`
- Test: grep-battery di file baru

- [ ] **Step 1: Tulis file** (verbatim)

````markdown
# Migration Impact — analisis dampak migrasi skema lintas-fitur (aturan share)

Dirujuk skill yang menilai dampak migrasi tabel: `plan` (peringatan dini saat desain) & `build` (gate migrate, tepat sebelum apply). **BUKAN langkah berdiri sendiri** — ia **prosedur ANALISIS read-only** yang dipanggil pemanggil itu. Tujuan: sebelum tabel diubah, munculkan **siapa pembaca tabel** + **risiko lock** + **perlu-backfill** + **saran expand-contract**, supaya gate "tampilkan + approve" yang ADA jadi **sadar-dampak**. Semua **advisory** — rule tak memblokir apa pun.

## Read-only (tak nulis file)
Rule ini cuma **menganalisis** lalu balik **laporan in-memory**. Ia **TIDAK** menulis artifact apa pun (beda dari `schema-projection.md` yang nulis `control/schema/`). Pemanggil yang memutuskan menampilkan laporan di gate / menulis ringkasannya ke plan-doc. Karena tak nulis → tak ada concern penulis-tunggal.

## Anti-fiksi / anti-overload (penting)
Consumer-of-table diturunkan dari **`control/schema/` (FK) + scan kode** — **BUKAN** `packages[].consumers` (itu "app impor package", konsep BEDA), **BUKAN** `data-model.md`/`roadmap.yaml` (tak ada di disk).

## Input (di-supply pemanggil)
- `affects` — tabel/kolom yang kena. Saat `build`: dari `migrate.affects` tugas. Saat `plan`: dari delta-rencana vs baseline `control/schema/`.
- `kind` — `additive` | `destructive` | `backfill` (migrate.kind). Saat `build`: dari tugas. Saat `plan`: taksiran sifat-perubahan.
- daftar app — dari `workspace.yaml` `apps[]` (+ `path`/`stack` tiap app).
- `control/schema/<app>.md` (M4, bila ada) — bibit consumer via FK + provenance `Asal`.
- (opsional, saat build) `tasks.yaml` fitur — buat lihat task `migrate` LAIN yang nyentuh tabel sama (expand→backfill→contract dipecah per task).

## Langkah (prosedur)
1. **Bibit dari M4 (scope jujur).** Baca `control/schema/` semua app: cari relasi FK yang nunjuk tabel di `affects` → kandidat dependent. **Batas:** FK = relasi **intra-DB** (satu app, atau lintas-app berbagi DB) — cuma nemu dependent satu-DB. **Consumer lintas-service** (DB terpisah; justru pemicu H3) TAK punya FK → ditemukan di step 2. Catat `Asal` tabel kena (fitur pemilik) buat konteks.
2. **Scan kode (campuran tabel+kolom).** Buat tiap app, baca kode (`path`/`stack`) → cari referensi **nama tabel** di `affects` (query/ORM model/raw SQL). **By-understanding, BUKAN regex/parser hardcode** (lintas-ORM). **TANPA DB hidup** — baca file sumber, bukan introspeksi koneksi. Bila `kind: destructive` & `affects` punya `Table.kolom` → tandai app yang kelihatan **nyentuh kolom itu** (sorot), tanpa men-skip yang cuma nyentuh tabel (jaring lebar).
3. **Nilai risiko by `kind`.**
   - `additive` (tambah tabel/kolom nullable/index concurrently) → lock rendah; pembaca existing aman; backfill: tidak.
   - `destructive` (drop/rename/ubah-tipe kolom, NOT NULL tanpa default) → lock tinggi (tabel besar); pembaca kolom yang diubah bisa rusak; backfill: mungkin (mis. NOT NULL butuh isi default dulu).
   - `backfill` (isi-ulang/transform baris existing) → long-running; risiko lock/beban; pembaca: data berubah saat proses.
4. **Saran expand-contract** (bila destructive pada kolom yang dibaca consumer hidup): pola **expand → migrate → contract** — (1) tambah bentuk baru tanpa hapus lama, (2) backfill + tulis-ganda, (3) alihkan pembaca, (4) hapus lama; dipecah lintas rilis. Bila `conventions.md` punya "Konvensi Migrasi" → rujuk spesialisasi project; rule bawa default generik bila kosong.
5. **Susun laporan** (in-memory): `affects` (tabel + kolom + `Asal`) · `kind` · daftar consumer (app + ditandai "nyentuh kolom yang diubah" / "nyentuh tabel saja") · level risiko-lock · flag perlu-backfill · saran expand-contract · (bila ada) "tabel ini juga disentuh task lain di fitur ini" (dari `tasks.yaml`) → cegah salah-alarm di fase contract.

## Sifat
- **Advisory:** laporan buat dipertimbangkan; rule TAK memblokir/STOP. Satu-satunya stop = gate apply existing.
- **Generik:** lintas-ORM/tool migrasi; runtime dari kode yang ADA; tak ada cabang hardcode per-stack; tak butuh DB hidup.
- **Degrade-ke-best-effort:** `control/schema/` tak ada / scan kosong → laporan "best-effort; tak ada consumer diketahui" + tetap tampilkan kind/risiko/saran. JANGAN error, JANGAN blokir.
- **Batas (sadar):** scan best-effort — akses dinamis/refleksi/string-tabel-runtime bisa lolos; consumer lewat API (bukan akses DB langsung) tak ketangkep. Gate manusia = jaring akhir.
````

- [ ] **Step 2: Verify** (grep-battery)

```bash
f=plugin/rules/migration-impact.md
test -f "$f" && echo "EXISTS ✓"
grep -Fc -e 'prosedur ANALISIS read-only' "$f"          # expect 1 (read-only)
grep -Fc -e 'TIDAK** menulis artifact' "$f"             # expect 1 (no write)
grep -Fc -e 'BUKAN** `packages[].consumers`' "$f"       # expect 1 (anti-overload)
grep -Fc -e 'data-model.md`/`roadmap.yaml' "$f"         # expect 1 (anti-fiksi)
grep -Fc -e 'BUKAN regex/parser hardcode' "$f"          # expect 1 (generik)
grep -Fc -e 'TANPA DB hidup' "$f"                       # expect 1 (no live DB)
grep -Fc -e 'Degrade-ke-best-effort' "$f"               # expect 1
grep -Fc -e 'additive' "$f"; grep -Fc -e 'destructive' "$f"; grep -Fc -e 'backfill' "$f"  # expect ≥1 each
grep -Fc -e 'expand → migrate → contract' "$f"          # expect 1
```
Expected: file ada + tiap grep ≥ angka di komentar.

- [ ] **Step 3: Commit**

```bash
git add plugin/rules/migration-impact.md
git commit -m "feat(h3): rules/migration-impact.md — analisis dampak migrasi generik (read-only; consumer dari control/schema/+scan, advisory)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `breakdown/reference.md` — `migrate.kind`+`affects` (§A skema + §B aturan + §D-1)

**Files:**
- Modify: `plugin/skills/breakdown/reference.md` (§A baris 25, §B baris 56, §D-1 baris 170)
- Test: grep anchor + `kind`-collision guard

- [ ] **Step 1a: §A skema** — sisipkan 2 sibling-line di bawah `- migrate:` (no-renumber; sibling action-level, 12-space indent supaya align di bawah key `migrate`).

FIND (verbatim):
```
          - migrate: <deskripsi>   #   DESTRUKTIF → build TAMPILKAN + GATE sebelum apply (jangan auto)
```
REPLACE WITH:
```
          - migrate: <deskripsi>   #   DESTRUKTIF → build TAMPILKAN + GATE sebelum apply (jangan auto)
            kind: additive|destructive|backfill   # migrate.kind (action-scoped, BEDA dari kind: feat|fix|debt level-task) — WAJIB tugas migrate
            affects: [Order, Order.status]         # tabel (+ Table.kolom bila ngerusak kolom) — basis gate dampak H3
```

- [ ] **Step 1b: §B aturan** — append kalimat WAJIB ke bullet `**`actions:` untuk kerja non-file.**`.

FIND (verbatim):
```
- **`actions:` untuk kerja non-file.** Migrasi DB, `npm install`, wiring env/secret, perintah infra TIDAK boleh terkubur di `approach` — taruh di `actions:` biar `build` eksekusi & verifikasi eksplisit. `install`/`cmd` auto; `migrate` (destruktif) lewat GATE; `env` ditulis `build` (nilai dari `manual:`/user).
```
REPLACE WITH:
```
- **`actions:` untuk kerja non-file.** Migrasi DB, `npm install`, wiring env/secret, perintah infra TIDAK boleh terkubur di `approach` — taruh di `actions:` biar `build` eksekusi & verifikasi eksplisit. `install`/`cmd` auto; `migrate` (destruktif) lewat GATE; `env` ditulis `build` (nilai dari `manual:`/user). **Tugas `migrate` WAJIB bawa `kind`(additive|destructive|backfill)+`affects`([tabel/Table.kolom])** (§A & §D-1) — basis gate dampak H3 (`rules/migration-impact.md`); WAJIB di sisi **penulis**, **bukan** validasi runtime (gate tetap advisory; degrade kalau tak ada).
```

- [ ] **Step 1c: §D-1** — append klausa `kind`+`affects` ke poin 1 actions.

FIND (verbatim):
```
1. **`actions` (kerja AI bisa, non-file).** Jenis: `install` (auto), `cmd` (auto), `migrate` (GATE — destruktif), `env` (build tulis ke `.env`). `build` mengeksekusi + memverifikasi tiap action sebagai bagian dari `done`.
```
REPLACE WITH:
```
1. **`actions` (kerja AI bisa, non-file).** Jenis: `install` (auto), `cmd` (auto), `migrate` (GATE — destruktif), `env` (build tulis ke `.env`). `build` mengeksekusi + memverifikasi tiap action sebagai bagian dari `done`. **`migrate` membawa `kind`+`affects`** (§A): `kind` = additive|destructive|backfill (action-scoped `migrate.kind`, beda dari `kind:` level-task), `affects` = [tabel, Table.kolom]. Dibaca gate dampak H3 (`${CLAUDE_PLUGIN_ROOT}/rules/migration-impact.md`).
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/breakdown/reference.md
grep -Fc -e '            kind: additive|destructive|backfill   # migrate.kind (action-scoped, BEDA dari kind: feat|fix|debt level-task) — WAJIB tugas migrate' "$f"  # expect 1 (§A sibling, 12-space)
grep -Fc -e '            affects: [Order, Order.status]         # tabel (+ Table.kolom bila ngerusak kolom) — basis gate dampak H3' "$f"  # expect 1 (§A)
grep -Fc -e '**Tugas `migrate` WAJIB bawa `kind`(additive|destructive|backfill)+`affects`([tabel/Table.kolom])**' "$f"  # expect 1 (§B)
grep -Fc -e '**`migrate` membawa `kind`+`affects`** (§A):' "$f"  # expect 1 (§D-1)
grep -Fc -e '          - migrate: <deskripsi>   #   DESTRUKTIF → build TAMPILKAN + GATE sebelum apply (jangan auto)' "$f"  # expect 1 (anchor §A utuh)
# kind-collision sanity: task-level kind: feat masih ADA & utuh (jangan tersentuh)
grep -Fc -e 'Task tanpa `kind` = implicit `feat`' "$f"  # expect 1
# anti-overload: pre-existing H2 packages[<pkg>].consumers utuh, tak tersentuh
grep -Fc -e 'untuk tiap nama di `packages[<pkg>].consumers`' "$f"  # expect 1 (EXPECTED H2, jangan diubah)
```
Expected: 1 / 1 / 1 / 1 / 1 / 1 / 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/breakdown/reference.md
git commit -m "feat(h3): breakdown tulis migrate.kind+affects tegas (action-scoped, WAJIB-penulis bukan runtime-block)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `build/SKILL.md` — gate migrate diperkaya dampak (step 3)

**Files:**
- Modify: `plugin/skills/build/SKILL.md` (step 3 "Actions task", baris 33)
- Test: grep anchor

- [ ] **Step 1: Edit** — sisip panggilan `migration-impact` ke dalam klausa gate migrate (sebelum apply; sebelum klausa M4 "**Proyeksi skema (M4):**" yang ada di line yang sama — gate-time mendahului post-`done` regen). Tak renumber.

FIND (verbatim):
```
**`migrate` → JANGAN auto: tampilkan rencana migrasi + minta approve user dulu** (destruktif), baru apply;
```
REPLACE WITH:
```
**`migrate` → JANGAN auto: tampilkan rencana migrasi + minta approve user dulu** (destruktif) — **sebelum approve**, panggil `${CLAUDE_PLUGIN_ROOT}/rules/migration-impact.md` (`migrate.kind`+`affects` tugas) buat tampilkan **dampak** (consumer + risiko-lock + perlu-backfill + saran expand-contract; advisory, **bukan** palang baru); baru apply;
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/build/SKILL.md
grep -Fc -e '**sebelum approve**, panggil `${CLAUDE_PLUGIN_ROOT}/rules/migration-impact.md` (`migrate.kind`+`affects` tugas) buat tampilkan **dampak**' "$f"  # expect 1
grep -Fc -e 'advisory, **bukan** palang baru); baru apply;' "$f"  # expect 1
# M4 clause di line yang sama TETAP utuh (tak tersentuh)
grep -Fc -e '**Proyeksi skema (M4):** sesudah task ber-`actions: migrate:` dengan **`unit` ∈ `apps[]`** mencapai `done`' "$f"  # expect 1
```
Expected: 1 / 1 / 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/build/SKILL.md
git commit -m "feat(h3): build gate migrate panggil migration-impact (dampak consumer/lock/backfill/expand-contract) sebelum approve

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: `build/reference.md` — §E migrate GATE diperkaya dampak

**Files:**
- Modify: `plugin/skills/build/reference.md` (§E baris 69)
- Test: grep anchor

- [ ] **Step 1: Edit** — enrich bullet `Eksekusi actions` bagian migrate (M4 bullet di baris bawahnya TAK tersentuh).

FIND (verbatim):
```
`migrate` → **GATE**: tampilkan + approve sebelum apply (destruktif).
```
REPLACE WITH:
```
`migrate` → **GATE**: tampilkan + **dampak (panggil `${CLAUDE_PLUGIN_ROOT}/rules/migration-impact.md`: consumer/lock/backfill/expand-contract; advisory)** + approve sebelum apply (destruktif).
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/build/reference.md
grep -Fc -e '`migrate` → **GATE**: tampilkan + **dampak (panggil `${CLAUDE_PLUGIN_ROOT}/rules/migration-impact.md`: consumer/lock/backfill/expand-contract; advisory)** + approve sebelum apply (destruktif).' "$f"  # expect 1
# M4 sub-bullet TETAP utuh
grep -Fc -e '**Proyeksi skema (M4):** sesudah task ber-`migrate` mencapai `done`' "$f"  # expect 1
```
Expected: 1 / 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/build/reference.md
git commit -m "feat(h3): build/reference.md §E migrate GATE tampilkan dampak via migration-impact (advisory)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: `plan/SKILL.md` — bullet "Dampak Skema Lintas-Fitur" (step 3)

**Files:**
- Modify: `plugin/skills/plan/SKILL.md` (### 3 Per app, baris 37 — bullet baca `control/schema/`)
- Test: grep anchor

- [ ] **Step 1: Edit** — sisipkan bullet Dampak Skema SETELAH bullet baca-proyeksi M4 (no-renumber).

FIND (verbatim):
```
- **Baca `control/schema/<app>.md` (proyeksi skema durable, M4) DULU** sebagai baseline model data existing (table/kolom/relasi/`Asal`) — **JANGAN rekonstruksi skema dari nol**. (Di-generate `wire`/`build`; read-only di sini.)
```
REPLACE WITH:
```
- **Baca `control/schema/<app>.md` (proyeksi skema durable, M4) DULU** sebagai baseline model data existing (table/kolom/relasi/`Asal`) — **JANGAN rekonstruksi skema dari nol**. (Di-generate `wire`/`build`; read-only di sini.)
- **Dampak Skema Lintas-Fitur (H3).** Bila rencana mengubah tabel ber-`Asal` fitur lain (alter-existing, bukan tabel baru fitur ini): `plan` men-supply `affects`=tabel-yang-diubah (delta vs baseline) + `kind`=taksiran sifat-perubahan, lalu panggil `${CLAUDE_PLUGIN_ROOT}/rules/migration-impact.md` → tulis blok prosa **Dampak Skema** (consumer + risiko-lock + perlu-backfill + saran expand-contract) ke `_shared.md` (consumer lintas-app) / `plans/<app>.md` (1 app), **SETELAH** fenced-template langkah 4 (bukan field di dalam fence) → sodorkan di gate. Tabel baru fitur ini / **pra-M4** (tak ada `Asal`) → skip (peringatan dini OFF; jaring pindah ke gate `build`).
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/plan/SKILL.md
grep -Fc -e '- **Dampak Skema Lintas-Fitur (H3).** Bila rencana mengubah tabel ber-`Asal` fitur lain' "$f"  # expect 1
grep -Fc -e 'panggil `${CLAUDE_PLUGIN_ROOT}/rules/migration-impact.md`' "$f"  # expect 1
grep -Fc -e '**SETELAH** fenced-template langkah 4 (bukan field di dalam fence)' "$f"  # expect 1
grep -Fc -e '**pra-M4** (tak ada `Asal`) → skip' "$f"  # expect 1 (degrade OFF)
# anchor M4 utuh
grep -Fc -e '- **Baca `control/schema/<app>.md` (proyeksi skema durable, M4) DULU**' "$f"  # expect 1
```
Expected: 1 / 1 / 1 / 1 / 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/plan/SKILL.md
git commit -m "feat(h3): plan section Dampak Skema Lintas-Fitur (peringatan dini via migration-impact; degrade OFF pra-M4)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: `ship/SKILL.md` — runbook urutan migrasi & deploy (step 6)

**Files:**
- Modify: `plugin/skills/ship/SKILL.md` (### 6 Kirim & tandai, baris 43 — sesudah Runbook integrasi)
- Test: grep anchor

- [ ] **Step 1: Edit** — sisipkan bullet runbook migrasi SETELAH bullet runbook integrasi (no-renumber).

FIND (verbatim):
```
- **Runbook integrasi (bila work-item kena vendor di `integrations.md`):** agregasi per vendor ke deskripsi PR — URL webhook yang perlu didaftarkan di console vendor (dari `Endpoint`/path receiver), env secret yang perlu di-set (NAMA var dari `Secret env`), switch mode test→live. Menutup gap "hasil langkah manual tak mendarat"; melengkapi challenge step 4. (Scoped ke integrasi — full release-runbook = Langkah 3.)
```
REPLACE WITH:
```
- **Runbook integrasi (bila work-item kena vendor di `integrations.md`):** agregasi per vendor ke deskripsi PR — URL webhook yang perlu didaftarkan di console vendor (dari `Endpoint`/path receiver), env secret yang perlu di-set (NAMA var dari `Secret env`), switch mode test→live. Menutup gap "hasil langkah manual tak mendarat"; melengkapi challenge step 4. (Scoped ke integrasi — full release-runbook = Langkah 3.)
- **Runbook migrasi & urutan deploy (bila work-item punya tugas `migrate`):** agregasi ke deskripsi PR — urutan aman (migrasi expand/additive dulu → deploy app pemakai → migrasi contract terakhir), catatan backfill (long-running), langkah zero-downtime (expand-contract per `conventions.md`). **Advisory** (panduan, **bukan** gate keras — alat tak tau infra deploy). Cermin runbook integrasi; scoped ke migrasi (full release-runbook = Langkah 3).
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/ship/SKILL.md
grep -Fc -e '- **Runbook migrasi & urutan deploy (bila work-item punya tugas `migrate`):**' "$f"  # expect 1
grep -Fc -e 'urutan aman (migrasi expand/additive dulu → deploy app pemakai → migrasi contract terakhir)' "$f"  # expect 1
grep -Fc -e '**Advisory** (panduan, **bukan** gate keras' "$f"  # expect 1 (anti-palang)
# anchor integrasi utuh
grep -Fc -e '- **Runbook integrasi (bila work-item kena vendor di `integrations.md`):**' "$f"  # expect 1
```
Expected: 1 / 1 / 1 / 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/ship/SKILL.md
git commit -m "feat(h3): ship runbook urutan migrasi & deploy ke PR (advisory, cermin runbook integrasi M5)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: `conventions.md` — heading "Konvensi Migrasi & Zero-Downtime"

**Files:**
- Modify: `plugin/template/control/conventions.md` (sesudah heading `## Konvensi Integrasi`)
- Test: grep anchor

- [ ] **Step 1: Edit** — tambah heading + komentar guidance expand-contract sesudah komentar Konvensi Integrasi.

FIND (verbatim):
```
<!-- Diisi saat add-integration/wire: SHAPE env vendor (NAMA var, tanpa nilai), konvensi webhook-receiver. -->
```
REPLACE WITH:
```
<!-- Diisi saat add-integration/wire: SHAPE env vendor (NAMA var, tanpa nilai), konvensi webhook-receiver. -->

## Konvensi Migrasi & Zero-Downtime
<!-- Pola expand-contract default buat perubahan ngerusak pada tabel dengan pembaca hidup:
     (1) expand — tambah bentuk baru (kolom/tabel) tanpa hapus lama;
     (2) backfill + tulis-ganda; (3) alihkan pembaca ke bentuk baru; (4) contract — hapus lama.
     Dipecah lintas beberapa rilis. Spesialisasi per-produk di sini; gate build/plan
     (rules/migration-impact.md) bawa default generik bila section ini kosong. -->
```

- [ ] **Step 2: Verify**

```bash
f=plugin/template/control/conventions.md
grep -Fc -e '## Konvensi Migrasi & Zero-Downtime' "$f"  # expect 1
grep -Fc -e '(1) expand — tambah bentuk baru (kolom/tabel) tanpa hapus lama;' "$f"  # expect 1
grep -Fc -e 'rules/migration-impact.md) bawa default generik bila section ini kosong.' "$f"  # expect 1
# anchor integrasi heading utuh
grep -Fc -e '## Konvensi Integrasi' "$f"  # expect 1
```
Expected: 1 / 1 / 1 / 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/template/control/conventions.md
git commit -m "feat(h3): conventions.md heading Konvensi Migrasi & Zero-Downtime (expand-contract generik)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Induk spec — §8 repo-tree rules + §17 Rules + §9 ship prose

**Files:**
- Modify: `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§8 baris 137, §17 baris 305, §9 baris 210)
- Test: grep anchor + skill-count guard

- [ ] **Step 1a: §8 repo-tree rules** — append `· migration-impact.md` (separator middot+space `· ` U+00B7, byte-eksak).

FIND (verbatim):
```
│   └── rules/    anti-yes-man.md· debt-aware.md· schema-projection.md   # anti-yes-man di-merge ke CLAUDE.md; sisanya dirujuk skill
```
REPLACE WITH:
```
│   └── rules/    anti-yes-man.md· debt-aware.md· schema-projection.md· migration-impact.md   # anti-yes-man di-merge ke CLAUDE.md; sisanya dirujuk skill
```

- [ ] **Step 1b: §17 Rules** — append ` · `migration-impact.md`` (separator spasi-middot-spasi + backtick; gaya §17).

FIND (verbatim):
```
- **Rules:** `anti-yes-man.md` · `debt-aware.md` · `schema-projection.md`
```
REPLACE WITH:
```
- **Rules:** `anti-yes-man.md` · `debt-aware.md` · `schema-projection.md` · `migration-impact.md`
```

- [ ] **Step 1c: §9 ship prose** — append kalimat runbook migrasi (cermin presedan M5 yang amend §9 untuk runbook integrasi).

FIND (verbatim):
```
temuan high → STOP. PR menyertakan runbook integrasi (webhook-URL + secret-NAMA + test→live).
```
REPLACE WITH:
```
temuan high → STOP. PR menyertakan runbook integrasi (webhook-URL + secret-NAMA + test→live). Bila ada tugas `migrate`, PR juga menyertakan runbook urutan migrasi & deploy (advisory; H3).
```

- [ ] **Step 2: Verify**

```bash
f=docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
grep -Fc -e 'anti-yes-man.md· debt-aware.md· schema-projection.md· migration-impact.md' "$f"  # expect 1 (§8, 4 rules middot)
grep -Fc -e '- **Rules:** `anti-yes-man.md` · `debt-aware.md` · `schema-projection.md` · `migration-impact.md`' "$f"  # expect 1 (§17)
grep -Fc -e 'Bila ada tugas `migrate`, PR juga menyertakan runbook urutan migrasi & deploy (advisory; H3).' "$f"  # expect 1 (§9)
grep -Fc -e '**Skills (21):**' "$f"  # expect 1 (skill-count TETAP 21)
```
Expected: 1 / 1 / 1 / 1.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
git commit -m "docs(spec): sync induk — rules += migration-impact.md (§8/§17) + §9 ship runbook migrasi; skills tetap 21

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Verifikasi akhir (grep-battery V0–V8 + coherence) — sesi eksekusi

**Files:** (read-only; commit hanya bila ada fix)

- [ ] **Step 1: Grep-battery** (dari root repo)

```bash
echo "V0 rule ada:";            test -f plugin/rules/migration-impact.md && echo ok
echo "V1 migration-impact direferensi ≥3 surface (build SKILL+ref, plan):"; grep -rl 'rules/migration-impact.md' plugin/skills/build plugin/skills/plan | wc -l   # expect ≥2 file (build SKILL, build ref, plan = 3 ref di ≥2 dir; cek juga ship)
grep -rl 'migration-impact.md' plugin/skills | sort -u   # tampilkan: build/SKILL, build/reference, plan/SKILL (ship rujuk konvensi, bukan rule langsung)
echo "V2 breakdown kind+affects:"; grep -Fc -e 'migrate.kind (action-scoped' plugin/skills/breakdown/reference.md; grep -Fc -e 'affects: [Order, Order.status]' plugin/skills/breakdown/reference.md
echo "V3 ship runbook migrasi:"; grep -Fc -e 'Runbook migrasi & urutan deploy' plugin/skills/ship/SKILL.md
echo "V4 conventions heading:"; grep -Fc -e '## Konvensi Migrasi & Zero-Downtime' plugin/template/control/conventions.md
echo "V5 skill-count 21 + plugin.json/marketplace/README TAK tersentuh:"; grep -Fc -e '**Skills (21):**' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md; git diff --name-only main..HEAD | grep -E 'plugin.json|marketplace.json|README' && echo "BOCOR!" || echo "clean ✓"
echo "V6 induk §8(4 rules)+§17+§9:"; grep -Fc -e 'schema-projection.md· migration-impact.md' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md; grep -Fc -e '`schema-projection.md` · `migration-impact.md`' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md; grep -Fc -e 'runbook urutan migrasi & deploy (advisory; H3)' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
echo "V7 anti-fiksi (TAK ada di artefak H3 baru/edit):"; grep -rn -e 'data-model.md' -e 'roadmap.yaml' plugin/rules/migration-impact.md && echo "fiksi cuma boleh sbg disclaimer — cek konteks" || echo "no fiksi-as-source ✓"
echo "V7b anti-overload (consumer BUKAN packages[].consumers di surface H3):"; grep -rn 'packages\[' plugin/rules/migration-impact.md plugin/skills/build/SKILL.md plugin/skills/plan/SKILL.md plugin/skills/ship/SKILL.md   # match HANYA boleh berupa disclaimer 'BUKAN packages[].consumers' di rule
echo "V8 anti-palang-keras (advisory, bukan STOP/blokir di surface H3):"; grep -rn -iE 'blokir|gagalkan|hard.gate' plugin/rules/migration-impact.md plugin/skills/ship/SKILL.md plugin/skills/build/SKILL.md plugin/skills/plan/SKILL.md && echo "cek: harus advisory" || echo "clean ✓"
```
Expected: V0 ok · V1 ≥2 dir (build SKILL+ref+plan) · V2 1+1 · V3 1 · V4 1 · V5 21 + clean · V6 1+1+1 · V7 no-source ✓ · V7b cuma disclaimer · V8 clean.

- [ ] **Step 2: Coherence read** — baca diff `main..HEAD`, pastikan: seam rule↔build(gate)↔plan(dini)↔ship(runbook)↔conventions nyambung; `migrate.kind`+`affects` ditulis breakdown & dibaca rule; consumer di-anchor ke `control/schema/`+scan (BUKAN `packages[].consumers`); semua advisory (gate apply existing = satu-satunya stop); pra-M4 plan-dini degrade OFF disebut; M4 clause di build SKILL+reference TAK rusak; induk §8 middot `·` U+00B7 benar + skills 21. Catat temuan.

- [ ] **Step 3: Selesai (sesi ini)** — JANGAN merge/push. Lapor: plan tereksekusi, N commit, tree clean. **Post-exec adversarial verify = sesi LAIN** (fresh-eyes 5-6 lensa: faithful-exec/seam/mis-aimed-pointer/parent-doc-staleness/anti-fiksi-generik-advisory/stress-test), baru FF-merge + push + hapus branch + update memory.

---

## Self-Review (penulis plan)

**1. Spec coverage** (tiap requirement spec → task):
- §4 `migrate.kind`+`affects` tegas (action-scoped, generik, degrade-bukan-block) → Task 2 (§A skema + §B WAJIB + §D-1).
- §5 rule (input/langkah/output/sifat, read-only, anti-fiksi, generik, degrade, batas, expand-contract, multi-task-same-table) → Task 1.
- §6a plan dini (supply affects/kind, tulis blok prosa SETELAH fence, degrade OFF pra-M4) → Task 5.
- §6b build gate diperkaya (sebelum approve, advisory, M4-clause utuh) → Task 3 + Task 4.
- §6c ship runbook migrasi/deploy (advisory) → Task 6 (+ induk §9 Task 8).
- §6d conventions heading expand-contract → Task 7.
- §7 generik (lintas-ORM, no-DB, degrade) → Task 1.
- §8 edge (tabel-baru/pra-M4/scan-kosong/breakdown-lama/additive/multi-task-same-table/API-consumer/lintas-repo/reject) → Task 1 (degrade+batas+langkah-5 multi-task) + Task 2 (degrade-bukan-block) + Task 5 (pra-M4 OFF).
- §9 edit-map (rule + breakdown + build×2 + plan + ship + conventions + induk §8/§17/§9) → Task 1-8 (1:1).
- §10 verifikasi V0-V8 + bug-guard → Task 9 + per-task grep + header bug-guard.
- §11 hubungan/non-goal (←M4 FK intra-DB + scan lintas-service; ≠packages[].consumers; ≠M5 overlap; no new skill) → header + Task 1 (anti-overload) + Task 8 (skills 21) + Task 9 V5/V7/V7b.
→ **Tak ada gap.**

**2. Placeholder scan:** tiap step punya isi nyata (file penuh Task 1; find/replace verbatim Task 2-8; grep konkret Task 9). Tak ada TBD/TODO/"similar to". ✓

**3. Type/anchor consistency:** istilah `migrate.kind`/`affects` konsisten rule(Task1)+breakdown(Task2)+build(Task3/4)+plan(Task5); idiom `${CLAUDE_PLUGIN_ROOT}/rules/migration-impact.md` sama di Task 1/2/3/4/5/7; "advisory"/"bukan palang baru" konsisten build/ship/rule; `control/schema/` sbg sumber consumer (bukan `packages[].consumers`) konsisten. Tiap anchor FIND diambil verbatim dari disk & sudah di-`grep -Fc`-verify =1 saat penulisan plan (breakdown:25/56/170, build/SKILL:33, build/ref:69, plan:37, ship:43, conventions integrasi-comment, induk:137/305/210). ✓
