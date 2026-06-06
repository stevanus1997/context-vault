# M4 — Schema Projection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (sesi terpisah, per handoff). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tambah proyeksi skema durable `control/schema/<app>.md` (di-generate dari skema/migrasi app, bukan doc tangan) lewat satu shared rule `rules/schema-projection.md` yang dipanggil `wire` (baseline) + `build` (pasca task-migrate `done`); `plan` membacanya sebagai baseline, `render-docs` me-render-nya read-only. Tutup gap M4 tanpa nambah skill (tetap 21).

**Architecture:** Sumber kebenaran = kode (skema ORM dan/atau migrasi). `rules/schema-projection.md` = prosedur generik (penulis tunggal `control/schema/`). Trigger: `wire` step-3 (baseline, `label=<none>`) + `build` (sesudah task ber-`actions: migrate:` untuk `unit ∈ apps[]` mencapai `done` pasca-review; `label` = `feature:`/`fix/<id>`). Konsumen read-only: `plan` (baseline per-app), `render-docs` (kartu Model Data, skip app nol-table). Spec: `docs/superpowers/specs/2026-06-05-m4-schema-projection-design.md`.

**Tech Stack:** Markdown skill/rule files + HTML template. Tak ada kode runtime. "Test" = grep-battery anchor verification (analog TDD untuk file instruksi) + coherence read.

**Branch:** `m4-schema-projection` (sudah dibuat; spec sudah di-commit @ `d37e8a9`). Eksekusi & post-exec verify = **sesi terpisah** (jangan execute di sesi penulisan plan).

**Bug-guard pre-bake (berlaku semua task):**
- **colon-space frontmatter:** rule files TAK punya YAML frontmatter (lihat `anti-yes-man.md`/`debt-aware.md`) → nol risiko; TAK menyentuh `description:` SKILL.md mana pun.
- **no-renumber:** semua sisipan = klausa/sub-bullet/slot/nav baru — **JANGAN** renumber langkah skill.
- **mis-aimed-pointer:** verifikasi tiap `§X` nunjuk seksi benar (induk §4/§7/§8/§17, breakdown §D-4).
- **anchor verify:** tiap find/replace di-`grep -Fc -e`-kan verbatim (robust leading-dash `- ` & metachar `[]`/`**`/backtick) SEBELUM commit.
- **dup-phrase trap:** frasa `pipeline migrasi BERFUNGSI + baseline` ada di wire/SKILL.md:50 (plain) **dan** wire/reference.md:73 (bold). Task 5 hanya edit reference.md (versi bold) — scope grep ke file itu.
- **skill-count:** TETAP 21 — `plugin.json`/`marketplace.json`/README **TIDAK** disentuh.
- Tiap commit diakhiri trailer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

### Task 1: NEW rule `rules/schema-projection.md`

**Files:**
- Create: `plugin/rules/schema-projection.md`
- Test: grep-battery di file baru

- [ ] **Step 1: Tulis file** (verbatim)

````markdown
# Schema Projection — Generate `control/schema/<app>.md` dari skema/migrasi (aturan share)

Dirujuk skill yang mengubah skema database sebuah app: `wire` (migrasi baseline) & `build` (table fitur, sesudah task `migrate` `done`). **BUKAN langkah berdiri sendiri** — ia **prosedur** yang dipanggil pemanggil itu. Tujuan: skema data punya **proyeksi durable** `control/schema/<app>.md` (di-generate, **JANGAN edit tangan**) supaya `plan` membaca model data, bukan merekonstruksi dari kode tiap sesi. Hormati induk §4 "satu sumber kebenaran (kode: skema/migrasi), banyak proyeksi".

## Penulis tunggal
HANYA aturan ini yang menulis `control/schema/`. `wire`/`build` **memanggil**; `plan`/`render-docs` cuma **baca**. Jangan ada skill lain menulis ke sana.

## Input (di-supply pemanggil)
- `app` — nama app (∈ `workspace.yaml` `apps[].name`). HANYA unit app — package tak punya table; pseudo-unit `integration` n/a.
- `label` — penanda work-item untuk provenance: **nama fitur** (`tasks.yaml` `feature:`) saat feature-build; **`fix/<id>`** saat fix-build (`build` juga jalan di `fixes/<id>/`, tasks.yaml-nya tanpa `feature:`); **`<none>`** saat `wire`-baseline / refresh.
- `stack` app — dari `workspace.yaml` (`db`, `orm`).
- Proyeksi sebelumnya `control/schema/<app>.md` (bila ada) — untuk preserve provenance.

## Langkah
1. **Lokalisasi sumber.** Dari `app.stack.orm` + `conventions.md`, tentukan di mana skema/migrasi app tinggal (mis. `schema.prisma`, schema Drizzle `*.ts`, Django `models.py`, folder migrasi raw-SQL). `stack.orm` kosong / sumber tak ketemu → tulis stub `# <app> — Schema (belum ada tabel)` lalu **STOP** (degrade no-op).
2. **Baca + PAHAMI sumber** (declarative schema file DAN/ATAU file migrasi). Ekstrak **by-understanding, BUKAN regex/parser hardcode** — supaya jalan lintas ORM apa pun: daftar table → tiap table { kolom: nama·tipe·nullable·key(pk/fk/unique); relasi: FK→table }. **JANGAN butuh DB hidup** — baca file sumber, bukan introspeksi koneksi.
3. **Provenance** (baca proyeksi lama):
   - Table **sudah ada** (match by-name) → bawa `Asal` origin apa adanya; kolom/relasi BEDA dari lama → set `terakhir-ubah: <label>`.
   - Table **baru** → `Asal: <label>`; bila `label=<none>` & table sudah ada sebelum M4 (baseline/brownfield) → `Asal: (pra-M4)`.
   - Batas sadar: table **rename** kehilangan origin (match by-name gagal) — best-effort.
4. **Tulis ulang LENGKAP** `control/schema/<app>.md` (struktur fresh dari sumber + provenance terpreserve), format:
   ```
   # <app> — Schema (proyeksi; JANGAN edit tangan — di-generate dari skema/migrasi app)
   > Sumber kebenaran = kode (skema ORM dan/atau migrasi app), bukan doc ini. Regenerate lewat wire/build, jangan edit langsung.

   ## <Table>
   Kolom  : <nama> <tipe> [pk|fk→<Table>|unique|null] · ...
   Relasi : <Table> 1—N <Other> · ...
   Asal   : <label-asal: fitur ATAU fix/id> · terakhir-ubah: <label>
   ```

## Sifat
- **Idempotent:** jalan ulang tanpa perubahan sumber → file identik (provenance ter-stamp dipertahankan).
- **Anti-drift / self-healing:** struktur selalu di-derive ulang dari sumber → file selalu = skema terkini.
- **Generik:** lintas ORM/tool migrasi; tak ada cabang hardcode per-stack; tak butuh DB hidup.
````

- [ ] **Step 2: Verify** (grep-battery — semua harus sesuai)

```bash
f=plugin/rules/schema-projection.md
test -f "$f" && echo "EXISTS ✓"
grep -Fc -e 'Penulis tunggal' "$f"            # expect 1
grep -Fc -e 'BUKAN regex/parser hardcode' "$f" # expect 1 (generik)
grep -Fc -e 'JANGAN butuh DB hidup' "$f"       # expect 1 (no live DB)
grep -Fc -e 'degrade no-op' "$f"               # expect 1
grep -Fc -e 'Idempotent:' "$f"                 # expect 1
grep -Fc -e 'label=<none>' "$f"                # expect ≥1 (provenance fallback)
grep -Fc -e 'fix/<id>' "$f"                    # expect ≥1 (fix-lane label)
```
Expected: file ada + tiap grep ≥ jumlah di komentar.

- [ ] **Step 3: Commit**

```bash
git add plugin/rules/schema-projection.md
git commit -m "feat(m4): rules/schema-projection.md — prosedur generik proyeksi skema (penulis tunggal control/schema/)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `build/SKILL.md` — regen klausa di migrate handling (pasca task `done`)

**Files:**
- Modify: `plugin/skills/build/SKILL.md` (step 3 "Actions task", baris 33)
- Test: grep anchor

- [ ] **Step 1: Edit** — anchor pada kalimat penutup baris 33.

FIND (verbatim):
```
`env` → `build` tulis ke `.env` app (nilai dari `manual:`/prompt user). Actions terverifikasi = prasyarat task `done`.
```
REPLACE WITH:
```
`env` → `build` tulis ke `.env` app (nilai dari `manual:`/prompt user). Actions terverifikasi = prasyarat task `done`. **Proyeksi skema (M4):** sesudah task ber-`actions: migrate:` dengan **`unit` ∈ `apps[]`** mencapai `done` (pasca-review step 4) → regen `control/schema/<unit>.md` per `${CLAUDE_PLUGIN_ROOT}/rules/schema-projection.md` (`label` = `tasks.yaml` `feature:` untuk work-item fitur ATAU `fix/<id>` untuk work-item fix). BUKAN untuk `unit` package/`integration`; BUKAN tiap task — cuma yang benar-benar migrasi app.
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/build/SKILL.md
grep -Fc -e '**Proyeksi skema (M4):** sesudah task ber-`actions: migrate:` dengan **`unit` ∈ `apps[]`** mencapai `done`' "$f"  # expect 1
grep -Fc -e '${CLAUDE_PLUGIN_ROOT}/rules/schema-projection.md' "$f"  # expect 1
grep -Fc -e 'Actions terverifikasi = prasyarat task `done`.' "$f"    # expect 1 (anchor masih ada, tak ganda)
```
Expected: 1 / 1 / 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/build/SKILL.md
git commit -m "feat(m4): build regen control/schema/<app>.md sesudah task-migrate done (label feature/fix, unit app saja)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `build/reference.md` — sub-bullet regen di §E (eksekusi actions)

**Files:**
- Modify: `plugin/skills/build/reference.md` (§E, baris 69)
- Test: grep anchor

- [ ] **Step 1: Edit**

FIND (verbatim):
```
- **Eksekusi `actions`:** `install`/`cmd` → jalankan + verifikasi (paket/exit-code). `migrate` → **GATE**: tampilkan + approve sebelum apply (destruktif). `env` → tulis ke `.env` app. Semua action terverifikasi = syarat `done`.
```
REPLACE WITH:
```
- **Eksekusi `actions`:** `install`/`cmd` → jalankan + verifikasi (paket/exit-code). `migrate` → **GATE**: tampilkan + approve sebelum apply (destruktif). `env` → tulis ke `.env` app. Semua action terverifikasi = syarat `done`.
- **Proyeksi skema (M4):** sesudah task ber-`migrate` mencapai `done`, regen `control/schema/<unit>.md` per `${CLAUDE_PLUGIN_ROOT}/rules/schema-projection.md` — **HANYA `unit` ∈ `apps[]`** (bukan package/`integration`); `label` = `feature:` (fitur) / `fix/<id>` (fix).
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/build/reference.md
grep -Fc -e '**Proyeksi skema (M4):** sesudah task ber-`migrate` mencapai `done`' "$f"   # expect 1
grep -Fc -e 'HANYA `unit` ∈ `apps[]`' "$f"                                               # expect 1
grep -Fc -e 'Semua action terverifikasi = syarat `done`.' "$f"                           # expect 1 (anchor utuh)
```
Expected: 1 / 1 / 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/build/reference.md
git commit -m "feat(m4): build/reference.md sub-bullet regen schema pasca task-migrate done (unit app)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: `wire/SKILL.md` — lahirkan `control/schema/<app>.md` di step 3

**Files:**
- Modify: `plugin/skills/wire/SKILL.md` (### 3 Konek BE↔DB, baris 37)
- Test: grep anchor

- [ ] **Step 1: Edit**

FIND (verbatim):
```
Init ORM/driver (`stack.orm`), generate migrasi **baseline** (kosong dari table fitur), **apply** (GATE — migrate jangan auto), smoke query buktikan koneksi.
```
REPLACE WITH:
```
Init ORM/driver (`stack.orm`), generate migrasi **baseline** (kosong dari table fitur), **apply** (GATE — migrate jangan auto), smoke query buktikan koneksi. **Proyeksi skema (M4):** lalu generate `control/schema/<app>.md` awal per `${CLAUDE_PLUGIN_ROOT}/rules/schema-projection.md` (`label=<none>`) — file lahir (header proyeksi; nol/baseline table) supaya `plan` tak pernah kena file-absen.
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/wire/SKILL.md
grep -Fc -e '**Proyeksi skema (M4):** lalu generate `control/schema/<app>.md` awal' "$f"  # expect 1
grep -Fc -e 'label=<none>' "$f"                                                           # expect 1
grep -Fc -e 'smoke query buktikan koneksi.' "$f"                                          # expect 1 (anchor utuh)
```
Expected: 1 / 1 / 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/wire/SKILL.md
git commit -m "feat(m4): wire lahirkan control/schema/<app>.md di baseline (label=<none>)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: `wire/reference.md` — catatan birth proyeksi di §H

**Files:**
- Modify: `plugin/skills/wire/reference.md` (§H, baris 73; versi **bold** — scope ke file ini)
- Test: grep anchor

- [ ] **Step 1: Edit** — anchor pada versi **bold** (unik di reference.md; versi plain wire/SKILL.md:50 JANGAN disentuh).

FIND (verbatim):
```
wire bikin **pipeline migrasi BERFUNGSI + baseline** (kosong table fitur); build bikin **TABLE fitur**. Dua-duanya gate `migrate`.
```
REPLACE WITH:
```
wire bikin **pipeline migrasi BERFUNGSI + baseline** (kosong table fitur); build bikin **TABLE fitur**. Dua-duanya gate `migrate`. **Proyeksi skema (M4):** wire juga **melahirkan `control/schema/<app>.md`** (proyeksi, `label=<none>`) per `${CLAUDE_PLUGIN_ROOT}/rules/schema-projection.md`; build me-regen-nya tiap task-migrate app `done`.
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/wire/reference.md
grep -Fc -e 'wire juga **melahirkan `control/schema/<app>.md`**' "$f"   # expect 1
grep -Fc -e 'wire bikin **pipeline migrasi BERFUNGSI + baseline**' "$f" # expect 1 (anchor bold utuh, di file ini)
# sanity: versi plain TIDAK tersentuh di SKILL.md
grep -Fc -e 'control/schema' plugin/skills/wire/SKILL.md                 # expect 1 (cuma dari Task 4, bukan bocor ke baris 50)
```
Expected: 1 / 1 / 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/wire/reference.md
git commit -m "feat(m4): wire/reference.md catat birth control/schema/ di baseline

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: `plan/SKILL.md` — baca proyeksi sebagai baseline per-app (step 3)

**Files:**
- Modify: `plugin/skills/plan/SKILL.md` (### 3 Per app, baris 37 — bullet "Buka kode app")
- Test: grep anchor

- [ ] **Step 1: Edit** — sisipkan bullet baca-proyeksi DULU (no-renumber: tambah bullet, bukan ubah nomor langkah).

FIND (verbatim):
```
- Buka kode app di `path`-nya (dari `workspace.yaml`). Baca pola yang ada; ikuti `conventions.md` & `stack`.
```
REPLACE WITH:
```
- **Baca `control/schema/<app>.md` (proyeksi skema durable, M4) DULU** sebagai baseline model data existing (table/kolom/relasi/`Asal`) — **JANGAN rekonstruksi skema dari nol**. (Di-generate `wire`/`build`; read-only di sini.)
- Buka kode app di `path`-nya (dari `workspace.yaml`). Baca pola yang ada; ikuti `conventions.md` & `stack`. Baca kode cuma untuk **delta/detail** yang tak ada di proyeksi.
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/plan/SKILL.md
grep -Fc -e '**Baca `control/schema/<app>.md` (proyeksi skema durable, M4) DULU**' "$f"  # expect 1
grep -Fc -e 'JANGAN rekonstruksi skema dari nol' "$f"                                     # expect 1
grep -Fc -e 'Buka kode app di `path`-nya (dari `workspace.yaml`). Baca pola yang ada; ikuti `conventions.md` & `stack`.' "$f"  # expect 1 (anchor utuh)
```
Expected: 1 / 1 / 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/plan/SKILL.md
git commit -m "feat(m4): plan baca control/schema/<app>.md sbg baseline (ganti rekonstruksi-dari-kode)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: `render-docs/SKILL.md` — baca + render kartu Model Data (skip nol-table)

**Files:**
- Modify: `plugin/skills/render-docs/SKILL.md` (### 1 baris 18 + ### 3 baris 26)
- Test: grep anchor

- [ ] **Step 1a: Edit ### 1 (Baca knowledge)** — sisipkan bullet schema sesudah bullet `debt.yaml`. **Anchor pada EKOR baris debt** (unik, count 1) — hindari char dash/arrow ambigu di tengah baris (disk pakai em-dash `—`, bukan arrow, di "debt.yaml — kumpulkan").

FIND (verbatim — ekor baris `debt.yaml`):
```
`dropped` dari field `dropped`. SHAPE-only.
```
REPLACE WITH:
```
`dropped` dari field `dropped`. SHAPE-only.
- `control/schema/*.md` → proyeksi skema per app (table, kolom, relasi, `Asal`/provenance) — read-only; di-generate `wire`/`build`, **JANGAN** regenerate di sini.
```

- [ ] **Step 1b: Edit ### 3 (Isi konten ke tiap slot)** — sisipkan bullet schema sesudah bullet `apps`.

FIND (verbatim):
```
- **apps:** satu `.card` per app: judul `name` + `type`, `responsibility`, lalu `capabilities` sebagai `.chip`.
```
REPLACE WITH:
```
- **apps:** satu `.card` per app: judul `name` + `type`, `responsibility`, lalu `capabilities` sebagai `.chip`.
- **schema (Model Data):** isi `<!-- SLOT:schema -->`. Satu `.card` per app yang PUNYA table (dari `control/schema/<app>.md`): judul app + daftar table (nama + kolom ringkas + relasi) + `Asal` (fitur/fix). **Read-only, TANPA filter ship-status** (skema ter-migrasi tampil walau fitur belum ship — by design M4). **Empty-handling:** app yang `control/schema/<app>.md`-nya stub/nol-table → **skip** (jangan render kartu kosong; ikut konvensi debt/integrations).
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/render-docs/SKILL.md
grep -Fc -e '- `control/schema/*.md` → proyeksi skema per app' "$f"        # expect 1 (read)
grep -Fc -e '**schema (Model Data):** isi `<!-- SLOT:schema -->`' "$f"     # expect 1 (render)
grep -Fc -e 'stub/nol-table → **skip**' "$f"                               # expect 1 (empty-handling)
grep -Fc -e 'TANPA filter ship-status' "$f"                                # expect 1 (by-design)
```
Expected: 1 / 1 / 1 / 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/render-docs/SKILL.md
git commit -m "feat(m4): render-docs baca control/schema/* + kartu Model Data (skip app nol-table, read-only)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: `render-docs/template.html` — nav link + SLOT schema

**Files:**
- Modify: `plugin/skills/render-docs/template.html` (nav baris 42 + body sesudah section apps baris 57)
- Test: grep anchor

- [ ] **Step 1a: Edit nav** — tambah link sesudah Apps.

FIND (verbatim):
```
    <a href="#apps">🧩 Apps</a>
```
REPLACE WITH:
```
    <a href="#apps">🧩 Apps</a>
    <a href="#schema">🗄️ Model Data</a>
```

- [ ] **Step 1b: Edit body** — sisipkan SLOT + contoh section sesudah penutup section apps, sebelum `<!-- SLOT:capabilities -->`.

FIND (verbatim):
```
      <div><span class="chip">auth</span><span class="chip">checkout</span></div></div>
  </section>
  <!-- SLOT:capabilities -->
```
REPLACE WITH:
```
      <div><span class="chip">auth</span><span class="chip">checkout</span></div></div>
  </section>
  <!-- SLOT:schema -->
  <section id="schema"><h2>Model Data</h2>
    <p class="meta">Skema per app dari control/schema/. Read-only; app tanpa table di-skip.</p>
    <div class="card"><h3>api <span class="meta">· schema</span></h3>
      <p>Order(id, tenant_id→Tenant, status, total_cents) · Product(id, tenant_id→Tenant, name, price_cents)</p></div>
  </section>
  <!-- SLOT:capabilities -->
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/render-docs/template.html
grep -Fc -e '<a href="#schema">🗄️ Model Data</a>' "$f"   # expect 1 (nav)
grep -Fc -e '<!-- SLOT:schema -->' "$f"                   # expect 1 (slot)
grep -Fc -e '<section id="schema"><h2>Model Data</h2>' "$f" # expect 1 (section)
```
Expected: 1 / 1 / 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/render-docs/template.html
git commit -m "feat(m4): template.html nav + SLOT schema (Model Data)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Induk spec — §7 control-tree + §8 repo-tree + §17 komponen

**Files:**
- Modify: `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§7 baris 73, §8 baris 135, §17 baris 303-304)
- Test: grep anchor + skill-count guard

- [ ] **Step 1a: §7 control-tree** — sisipkan node `schema/` sesudah `design-system.md`. **Glyph `├──`** (bukan sibling terakhir).

FIND (verbatim):
```
├── design-system.md      # fondasi visual: tokens+motion+komponen primitif per gaya (diisi design-system)
```
REPLACE WITH:
```
├── design-system.md      # fondasi visual: tokens+motion+komponen primitif per gaya (diisi design-system)
├── schema/               # proyeksi skema per app (generated wire/build dari skema/migrasi; M4; tak di-scaffold init)
│   └── <app>.md
```

- [ ] **Step 1b: §8 repo-tree** — daftar `rules/`: backfill `debt-aware.md` (stale) + tambah `schema-projection.md`.

FIND (verbatim):
```
│   └── rules/    anti-yes-man.md         # di-merge ke CLAUDE.md produk
```
REPLACE WITH:
```
│   └── rules/    anti-yes-man.md· debt-aware.md· schema-projection.md   # anti-yes-man di-merge ke CLAUDE.md; sisanya dirujuk skill
```

- [ ] **Step 1c: §17 Rules** — backfill `debt-aware.md` + tambah `schema-projection.md`.

FIND (verbatim):
```
- **Rules:** `anti-yes-man.md`
```
REPLACE WITH:
```
- **Rules:** `anti-yes-man.md` · `debt-aware.md` · `schema-projection.md`
```

- [ ] **Step 1d: §17 Knowledge** — tambah `schema/` sesudah `design-system.md`.

FIND (verbatim):
```
- **Knowledge (`control/`):** `workspace.yaml` (apps[] + packages[]) · `business/` · `conventions.md` · `invariants.md` · `integrations.md` · `design-system.md` · `features/` · `docs/`
```
REPLACE WITH:
```
- **Knowledge (`control/`):** `workspace.yaml` (apps[] + packages[]) · `business/` · `conventions.md` · `invariants.md` · `integrations.md` · `design-system.md` · `schema/` · `features/` · `docs/`
```

- [ ] **Step 2: Verify**

```bash
f=docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
grep -Fc -e '├── schema/               # proyeksi skema per app' "$f"   # expect 1 (§7 node, glyph ├──)
grep -Fc -e '│   └── <app>.md' "$f"                                      # expect 1 (§7 child)
grep -Fc -e 'anti-yes-man.md· debt-aware.md· schema-projection.md' "$f"  # expect 1 (§8 rules)
grep -Fc -e '- **Rules:** `anti-yes-man.md` · `debt-aware.md` · `schema-projection.md`' "$f"  # expect 1 (§17 rules)
grep -Fc -e '`design-system.md` · `schema/` · `features/`' "$f"          # expect 1 (§17 knowledge)
grep -Fc -e '**Skills (21):**' "$f"                                      # expect 1 (skill-count TETAP 21)
```
Expected: 1 / 1 / 1 / 1 / 1 / 1.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
git commit -m "docs(spec): sync induk — schema/ di §7 control-tree + §8/§17 (rules += debt-aware backfill + schema-projection); skills tetap 21

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: Verifikasi akhir (grep-battery V0–V7 + coherence) — sesi eksekusi

**Files:** (read-only; commit hanya bila ada fix)

- [ ] **Step 1: Grep-battery lintas-repo** (dari root produk-boilerplate)

```bash
echo "V0 rule ada:";            test -f plugin/rules/schema-projection.md && echo ok
echo "V1 control/schema/ ≥3 surface (rule+plan+render-docs):"; grep -rl 'control/schema/' plugin/rules plugin/skills/plan plugin/skills/render-docs | wc -l   # expect ≥3
echo "V2 rule direferensi build+wire:"; grep -rl 'rules/schema-projection.md' plugin/skills/build plugin/skills/wire | wc -l  # expect 2
echo "V3 penulis tunggal (TAK ada skill SELAIN rule yang 'tulis/generate control/schema'):"; grep -rn 'control/schema' plugin/skills | grep -iE 'tulis|generate|regen' # build/wire boleh (memanggil rule); pastikan tak ada yang nulis langsung tanpa rule
echo "V4 skill-count 21 + plugin.json/marketplace TAK tersentuh:"; grep -Fc -e '**Skills (21):**' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md; git diff --name-only main..HEAD | grep -E 'plugin.json|marketplace.json' && echo "BOCOR!" || echo "clean ✓"
echo "V5 §7 schema/ node + §17 rules(3)+knowledge(schema/):"; grep -Fc -e '├── schema/' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md; grep -Fc -e 'debt-aware.md` · `schema-projection.md`' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
echo "V6 template nav+slot:"; grep -Fc -e '#schema' plugin/skills/render-docs/template.html; grep -Fc -e '<!-- SLOT:schema -->' plugin/skills/render-docs/template.html
echo "V7 anti-fiksi/anti-H3 (TAK ada di artefak M4):"; grep -rn -e 'data-model.md' -e 'roadmap.yaml' -e 'migrate.kind' -e 'migrate.affects' plugin/rules/schema-projection.md plugin/skills/build plugin/skills/wire plugin/skills/plan plugin/skills/render-docs && echo "BOCOR!" || echo "clean ✓"
```
Expected: V0 ok · V1 ≥3 · V2 =2 · V3 cuma build/wire (lewat rule) · V4 21 + clean · V5 1 + 1 · V6 1 + 1 · V7 clean.

- [ ] **Step 2: Coherence read** — baca diff `main..HEAD`, pastikan: seam rule↔build/wire↔plan/render-docs nyambung; `label` (feature/fix/<none>) konsisten di rule+build+wire; `unit ∈ apps[]` guard ada di build SKILL+reference; tak ada `packages[].consumers` di-tulis M4; glyph tree §7 benar (`├──` + `│   └──`). Catat temuan.

- [ ] **Step 3: Selesai (sesi ini)** — JANGAN merge/push. Lapor ke user: plan tereksekusi, N commit, tree clean. **Post-exec adversarial verify = sesi LAIN** (fresh-eyes 5-6 lensa), baru FF-merge + push + hapus branch.

---

## Self-Review (penulis plan)

**1. Spec coverage** (tiap requirement spec → task):
- §4 artifact RICH (header+kolom+relasi+Asal) → Task 1 (format di rule) + Task 8 (contoh template).
- §5 rule (input/langkah/output/aturan/batas, sole-writer, generik, degrade, idempotent) → Task 1.
- §6 trigger wire(baseline,`<none>`) + build(pasca task-migrate `done`, label feature/fix, unit∈apps[]) → Task 2/3 (build) + Task 4/5 (wire).
- §7 konsumen plan(baseline per-app) + render-docs(render read-only, skip nol-table) → Task 6 + Task 7/8.
- §8 freshness (regen struktur + provenance label) → Task 1 (langkah 2-4 + Sifat).
- §9 generik (lintas-ORM, no-DB) → Task 1.
- §10 edge (degrade/baseline/fix-build/pra-M4/rename/reject/non-app/multi-repo) → Task 1 (degrade+provenance+batas) + Task 2/3 (unit guard) + Task 7 (empty-handling).
- §11 edit-map (rule + build×2 + wire×2 + plan + render-docs + template + induk §7/§8/§17) → Task 1-9 (1:1).
- §12 verifikasi V0-V7 + bug-guard → Task 10 + per-task grep + header bug-guard.
- §13 hubungan/non-goal (no H3, no packages[].consumers, no new skill) → header + Task 9 (skills tetap 21) + Task 10 V4/V7.
→ **Tak ada gap.**

**2. Placeholder scan:** tiap step punya isi nyata (file penuh Task 1; find/replace verbatim Task 2-9; perintah grep konkret). Tak ada TBD/TODO/"similar to". ✓

**3. Type/anchor consistency:** istilah `label` (bukan `fitur`) konsisten rule+build+wire; `${CLAUDE_PLUGIN_ROOT}/rules/schema-projection.md` idiom sama di Task 1/2/3/4/5; `control/schema/<app>.md` path konsisten; glyph `├── schema/` + `│   └── <app>.md` sinkron §7↔Task 9. Anchor FIND tiap task diambil verbatim dari disk (build/SKILL:33, build/ref:69, wire/SKILL:37, wire/ref:73, plan/SKILL:37, render-docs/SKILL:18+26, template:42+57, induk:73/135/303/304). ✓
