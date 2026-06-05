# M4 — Schema Projection (`control/schema/<app>.md`)

> Langkah-2, gap **M4** (MEDIUM, mengaktifkan H3). Tanggal: **2026-06-05**. Repo `~/Developer/ai-boilerplate`.
> Brainstorming **terkunci** lewat 4+1 AskUserQuestion: trigger=**build(gate migrate)+wire**, pemilik=**shared rule** (skill tetap 21), bentuk=**per-app RICH**, fresh=**regen-struktur + provenance-awet**.

## 1. Ringkasan

Skema data hari ini cuma hidup sebagai **satu baris prosa** `Model/Schema : <...>` per app di `plans/<app>.md`, direkonstruksi dari kode mentah tiap sesi. M4 menambah satu **proyeksi durable** `control/schema/<app>.md` — di-**generate dari kode** (skema ORM dan/atau migrasi app = sumber kebenaran), **bukan** doc tangan — supaya `plan` **membaca** model data, bukan **menurunkannya ulang** tiap kali. Logika generik "baca migrasi → tulis proyeksi" tinggal di **satu shared rule** `rules/schema-projection.md`, dipanggil otomatis oleh `wire` (baseline) + `build` (sesudah migrasi apply). **Tak ada skill baru** (skill tetap 21). M4 meletakkan seam bersih untuk H3 tapi **tidak membangun H3**.

## 2. Masalah

- **Skema fana.** `plan/SKILL.md` menulis `Model/Schema : <...>` per app (1 baris, tanpa aturan isi); `plan` **tidak** membaca skema apa pun sebagai input — ia merekonstruksi dari kode tiap sesi (`plan/SKILL.md` langkah "Buka kode app... baca pola yang ada").
- **Trigger nyata.** Fitur #20 butuh bentuk `Order`/`Product`/`Tenant` dari fitur #1/#3/#7 → AI baca ulang ~30 table dari kode mentah tiap sesi. Mahal, rawan salah, tak ada satu tempat melihat "bentuk model produk sekarang".
- **Sumber kebenaran sudah ada, tapi tak diproyeksikan.** `architect` mengunci `stack: {framework, db, orm}` ke `workspace.yaml`; `wire` init ORM + **migrasi baseline**; `build` bikin **table fitur** lewat `actions: migrate:` (GATE). Migrasi = sumber kebenaran skema, tapi tak pernah diproyeksikan ke artifact yang bisa dibaca AI.
- **render-docs schema-blind.** Generator proyeksi induk §4 yang ada (`render-docs`) membaca `control/*` → HTML, tapi **tak baca skema/migrasi sama sekali** hari ini.

## 3. Tujuan & Non-Tujuan

**Tujuan**
- Artifact durable `control/schema/<app>.md` per app — proyeksi ter-generate, **jangan edit tangan**, RICH (table · kolom+tipe+nullable+key · relasi · provenance).
- Selalu fresh by-construction: regen tepat saat skema berubah (`wire` baseline, `build` sesudah migrasi apply).
- Generik lintas ORM (Prisma/Drizzle/raw-SQL/Django/dll), diturunkan **runtime** dari sumber yang ADA — **bukan parser hardcode satu stack**, **tak butuh DB hidup**.
- `plan` membaca proyeksi sebagai input langkah-1 (menutup gap rekonstruksi).
- `render-docs` me-render proyeksi ke HTML manusia (read-only consumer).

**Non-Tujuan (seam bersih, anti scope-creep)**
- **H3 (migration-governance)** — "siapa **baca** table X" (consumer-of-table), `migrate.kind: additive|destructive|backfill`, `migrate.affects:[table]`, gate dampak lintas-fitur, urutan deploy, konvensi zero-downtime → **Langkah terpisah**. M4 cuma mencatat **provenance produsen-side** (siapa **bikin/ubah** table); consumer-side = H3. M4 meninggalkan `control/schema/` sebagai jangkar yang H3 baca nanti; **tak menyentuh `packages[].consumers`** (itu "app impor package" — konsep BEDA dari "fitur/kolom gantung ke table").
- **Brownfield `extract`** populasi skema — **ditunda** (konsisten dengan H2 yang menunda brownfield extract). Degrade rule (`Asal: (pra-M4)`) sudah meng-handle bila `wire`/`build` jalan di app brownfield.
- **Tak ada** skill baru, **tak ada** command `/schema`, **tak ada** introspeksi DB hidup.
- **Tak ada** perubahan task-schema `breakdown`, `invariants.md`, `conventions.md`, `plugin.json`, `marketplace.json` (semua khusus H3 / skill-baru — bukan M4).
- **Tak menyandar fiksi**: M4 **tidak** mereferensi `data-model.md`/`roadmap.yaml`/artifact H3 (semua belum ada).

## 4. Artifact — `control/schema/<app>.md` (per-app, RICH, generated)

Satu file per app di `control/schema/`. **Proyeksi ter-generate; JANGAN edit tangan** (header memperingatkan). Bentuk:

```
# <app> — Schema (proyeksi; JANGAN edit tangan — di-generate dari skema/migrasi app)
> Sumber kebenaran = kode (skema ORM dan/atau migrasi app), bukan doc ini. Regenerate lewat wire/build, jangan edit langsung.

## <Table>
Kolom  : <nama> <tipe> [pk|fk→<Table>|unique|null] · <nama> <tipe> · ...
Relasi : <Table> 1—N <Other> · ...        # bila ada
Asal   : <label-asal: fitur ATAU fix/id> · terakhir-ubah: <label>   # provenance; "(pra-M4)" bila tak tercatat
```

Contoh (app `api`):
```
# api — Schema (proyeksi; JANGAN edit tangan — di-generate dari skema/migrasi app)
## Order
Kolom  : id uuid pk · tenant_id uuid fk→Tenant · status text · total_cents int · created_at timestamptz
Relasi : Tenant 1—N Order · Order 1—N OrderItem
Asal   : checkout (#3) · terakhir-ubah: refund (#12)
## Product
Kolom  : id uuid pk · tenant_id uuid fk→Tenant · name text · price_cents int
Relasi : Product 1—N OrderItem
Asal   : catalog (#1)
```

**Asimetri SADAR vs M5** (selaras induk §4 "satu sumber kebenaran, banyak proyeksi"): `integrations.md` = **hand-authored** (kontrak vendor tak punya hulu untuk diproyeksi); `control/schema/` = **proyeksi ter-generate** (skema PUNYA hulu = migrasi). M4 adalah "saudara terproyeksi" yang sudah disebut eksplisit oleh spec M5. Aturan §4 "jangan edit proyeksi" mengikat artifact ter-generate ini.

## 5. Pemilik — shared rule `rules/schema-projection.md` (penulis tunggal `control/schema/`)

Satu file resep generik, dipanggil via `${CLAUDE_PLUGIN_ROOT}/rules/schema-projection.md` (idiom sama seperti `rules/debt-aware.md` yang dipakai `plan`/`breakdown`/`fix`). **Tak nambah skill** → skill tetap 21, nol churn `plugin.json`/`marketplace.json`/README/induk §12.

**Input** (di-supply pemanggil):
- `app` — nama app (∈ `workspace.yaml` `apps[].name`).
- `label` — penanda work-item untuk provenance: **nama fitur** (dari `tasks.yaml` `feature:`) saat feature-build; **`fix/<id>`** (dari `fix.yaml`) saat fix-build (`build` juga jalan di `fixes/<id>/`, yang tasks.yaml-nya TAK punya `feature:`); ATAU `<none>` saat `wire`-baseline / refresh manual.
- `stack` app — dari `workspace.yaml` (`db`, `orm`).
- Proyeksi sebelumnya `control/schema/<app>.md` (bila ada) — untuk preserve provenance.

**Langkah** (prosedur):
1. **Lokalisasi sumber.** Dari `app.stack.orm` + `conventions.md`, tentukan di mana skema/migrasi app tinggal. Bila `stack.orm` kosong / sumber tak ketemu → tulis stub `# <app> — Schema (belum ada tabel)` lalu **STOP** (degrade no-op).
2. **Baca + PAHAMI sumber** (ORM declarative schema file — `schema.prisma`/`schema.ts`/`models.py`/dll — DAN/ATAU file migrasi untuk raw-SQL). Ekstrak by-understanding (BUKAN regex/parser hardcode): daftar table → tiap table { kolom: nama·tipe·nullable·key(pk/fk/unique); relasi: FK→table }.
3. **Provenance** (baca proyeksi lama):
   - Table **sudah ada** di proyeksi lama (match by-name) → bawa `Asal` origin apa adanya; bila kolom/relasi BEDA dari lama → set `terakhir-ubah: <label>` (mis. `terakhir-ubah: fix/<id>` saat fix-build).
   - Table **baru** → `Asal: <label>`; bila `label=<none>` & table sudah ada sebelum M4 (baseline/brownfield) → `Asal: (pra-M4)`.
4. **Tulis ulang LENGKAP** `control/schema/<app>.md` (struktur fresh dari sumber + provenance terpreserve), pakai header §4.

**Output:** `control/schema/<app>.md` fresh.

**Aturan rule:**
- **Penulis tunggal:** HANYA rule ini menulis `control/schema/`. `wire`/`build` **memanggil**; `plan`/`render-docs` cuma **baca**.
- **Generik:** jalan lintas ORM; diturunkan runtime dari sumber yang ADA; tak ada parser per-stack; tak butuh DB hidup (baca file sumber, bukan introspeksi koneksi).
- **Idempotent:** jalan ulang tanpa perubahan sumber → file identik (provenance yang sudah ter-stamp dipertahankan).
- **Batas (sadar):** table **rename** kehilangan origin (match by-name gagal → terlihat sebagai drop+add). Jarang; best-effort.

## 6. Trigger — kapan regen menyala

- **`wire`** (sesudah migrasi baseline apply, GATE) → panggil rule (`label=<none>`). Melahirkan `control/schema/<app>.md` (header §4 RICH, nol `## <Table>` bila baseline kosong). **Menjamin file selalu ADA** sejak bring-up → `plan` tak pernah kena "file not found". Per app yang di-wire.
- **`build`** (sesudah **task ber-`actions: migrate:` untuk unit app** mencapai `done` **pasca-review** — tiap task migrate, **bukan** sekali per fitur) → panggil rule (`label` = `tasks.yaml` `feature:` untuk feature-build, ATAU `fix/<id>` untuk fix-build). Regen file app itu. **HANYA untuk unit ∈ `apps[]`** — **BUKAN** unit package (DILARANG `migrate` per breakdown §D-4) / pseudo-unit `integration` (n/a); **BUKAN** tiap task (cuma task yang migrasi app benar-benar apply).

Sekuens build: gate migrate → user approve → apply → verifikasi → review (langkah 4/6, bisa men-rewrite migrasi) → task mencapai `done` → **baru** regen proyeksi. Regen **TUNGGU `done` pasca-review**, bukan tepat sesudah apply — supaya proyeksi mencerminkan skema FINAL (kalau review menyuruh implementer ubah migrasi, regen pra-review akan basi & self-heal §8 tak menyelamatkan karena regen cuma menyala saat migrate-apply).

## 7. Konsumen — read-only

- **`plan`** — saat **baca-kode per-app** (langkah "Per app: buka kode app"), baca `control/schema/<app>.md` dulu sebagai **baseline model data**; baca kode app **cuma untuk delta/detail** yang tak ada di proyeksi. Ini mengganti "rekonstruksi skema dari kode" → "baca proyeksi durable + delta" = menutup gap. Baris per-fitur `Model/Schema : <...>` di `plans/<app>.md` **TETAP** (itu **delta** yang di-cover `breakdown`; M4 cuma memberi baseline durable supaya plan tak baca ulang 30 table).
- **`render-docs`** — tambah section **"Schema / Model Data"** + slot nav yang **me-render** proyeksi per-app yang SUDAH ADA ke HTML manusia. **Read-only consumer; tidak meng-generate** proyeksi (build/wire yang generate). Bila fitur belum di-ship tapi sudah migrasi, proyeksi sudah fresh (build generate saat migrate) → HTML tampil skema terkini.

## 8. Freshness — hybrid (regen struktur + preserve provenance)

Tiap regen: **(a)** re-derive SELURUH struktur (table/kolom/relasi) dari sumber → **anti-drift, self-healing** (state file selalu = sumber terkini); **(b)** baca proyeksi lama untuk **bawa provenance**: table lama pertahankan `Asal` origin; table baru di-stamp `<label>` berjalan; table yang kolom/relasinya berubah → `terakhir-ubah: <label>`. Provenance hanya terketahui sejak M4 ada → table pra-M4/brownfield = `(pra-M4)`.

Kunci pembeda dari opsi lain: struktur **bisa** diturunkan ulang dari sumber (jadi di-regen, anti-drift), tapi provenance "fitur asal" **tak bisa** ditebak dari skema mentah (jadi di-stamp + di-preserve).

## 9. Prinsip generik

- **Lintas-ORM:** rule menyuruh AI memahami sumber apa pun yang dipakai stack (declarative schema file dan/atau migrasi) — tak ada cabang hardcode per-ORM. ORM tak dikenal tetap jalan selama AI bisa baca sumbernya.
- **Tanpa DB hidup:** baca file sumber (schema def / migrasi), bukan introspeksi koneksi DB. Aman di sesi tanpa DB nyala.
- **Degrade-ke-noop:** `stack.orm` kosong / sumber tak ketemu → stub + STOP, jangan error.
- **Satu sumber, banyak proyeksi (induk §4):** sumber = kode (skema ORM dan/atau migrasi); `control/schema/<app>.md` = proyeksi AI-readable (di-generate, jangan edit); HTML render-docs = proyeksi manusia. Dua-duanya turunan, tak pernah di-edit tangan.

## 10. Edge case & degrade

| Kasus | Perilaku |
|---|---|
| `stack.orm` kosong / app belum lewat architect | Stub `# <app> — Schema (belum ada tabel)` + STOP (no-op). |
| `wire` baseline (belum ada table fitur) | File lahir pakai header §4 RICH dengan **nol** `## <Table>` (bukan stub "belum ada tabel"), `Asal` n/a. `plan` fitur pertama baca file "kosong tabel". |
| **`build` jalan work-item fix** (`fixes/<id>/`) yang punya `migrate` | `label = fix/<id>` (tasks.yaml fix tak punya `feature:`); table existing → `Asal` lama dipertahankan, set `terakhir-ubah: fix/<id>`. |
| Table pra-M4 / brownfield (origin tak tercatat) | `Asal: (pra-M4)`. |
| Table di-rename antar regen | Match by-name gagal → origin baru di-stamp `<label>` berjalan (batas sadar §5). |
| Migrasi apply gagal / user reject di gate | Migrasi tak apply → tak ada regen (state tak berubah). |
| Unit `package` / `integration` punya `migrate` | `build` tak regen schema untuk non-app (package dilarang `migrate` per breakdown §D-4; integration n/a). |
| Multi-repo / multi-app | Tiap app = file sendiri di `control/schema/` (knowledge home tunggal apa pun topologi, seperti `apps[]` sentral di `workspace.yaml`). |

## 11. Edit-map (anchor diverifikasi `grep -Fc -e` saat writing-plans)

**NEW**
- `plugin/rules/schema-projection.md` — prosedur §5 lengkap (input/langkah/output/aturan/batas).

**MODIFY skill**
- `plugin/skills/build/SKILL.md` — di handling `actions: migrate:` (sekarang "migrate → JANGAN auto: tampilkan... baru apply"): tambah klausa "sesudah task ber-migrate untuk **unit ∈ `apps[]`** mencapai `done` (pasca-review) → regen `control/schema/<unit>.md` per `${CLAUDE_PLUGIN_ROOT}/rules/schema-projection.md` (`label` = `tasks.yaml` `feature:` ATAU `fix/<id>`); **BUKAN** untuk package/integration".
- `plugin/skills/build/reference.md` — restatement migrate (sekarang "migrate → GATE: tampilkan + approve sebelum apply"): tambah sub-bullet "regen `control/schema/<unit>.md` sesudah task ber-migrate mencapai `done`, **HANYA unit ∈ `apps[]`** (bukan package/integration), per rule (`label`)".
- `plugin/skills/wire/SKILL.md` — langkah konek BE↔DB (sekarang "generate migrasi baseline... apply (GATE)... smoke query"): tambah "lalu generate `control/schema/<app>.md` awal per rule (`label=<none>`)".
- `plugin/skills/wire/reference.md` — baris "wire bikin pipeline migrasi BERFUNGSI + baseline" (anchor versi **bold** di reference.md:73; catatan: frasa sama juga ada di wire/SKILL.md:50 → scope grep ke reference.md): tambah catatan birth proyeksi schema.
- `plugin/skills/plan/SKILL.md` — di langkah per-app "Buka kode app di path-nya... Baca pola yang ada" (langkah 3, BUKAN langkah-1 input): tambah bullet "baca `control/schema/<app>.md` (proyeksi durable) DULU sebagai baseline model data; baca kode cuma untuk delta — jangan rekonstruksi skema dari nol".
- `plugin/skills/render-docs/SKILL.md` — langkah-1 (Baca knowledge): tambah `control/schema/*.md`; langkah-3 (render): tambah section **"Schema / Model Data"** per app (read-only, **tanpa** filter ship-status — by design §7). **Empty-handling** (ikut konvensi debt/integrations "bila ada"/"lewati section kosong"): render kartu HANYA untuk app yang PUNYA table; `control/schema/<app>.md` stub/nol-tabel → **skip** app itu.
- `plugin/skills/render-docs/template.html` — nav: tambah `<a href="#schema">🗄️ Model Data</a>` (sesudah `#apps`, antara `#apps` & `#capabilities`); body: tambah `<!-- SLOT:schema -->`. (render-docs **tak punya** reference.md — cuma SKILL.md + template.html; detail kartu inline di SKILL.md.)

**MODIFY parent spec** `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`
- §7 control-tree — sisipkan node direktori `├── schema/` + anak `│   └── <app>.md  # proyeksi skema per app (di-generate wire/build dari skema/migrasi; M4; TAK di-scaffold init)` (sesudah `design-system.md`, sebelum `features/`). **Glyph `├──`** (bukan `└──`) karena `schema/` BUKAN sibling terakhir → verifikasi glyph vs tree live saat exec (guard mis-aimed-pointer §12).
- §8 repo-tree — daftar `rules/` (di disk sekarang cuma `anti-yes-man.md`, **stale**): jadikan `anti-yes-man.md · debt-aware.md · schema-projection.md` (backfill `debt-aware.md` yang hilang + tambah `schema-projection.md`).
- §17 Komponen — baris **Rules**: `anti-yes-man.md` → `anti-yes-man.md · debt-aware.md · schema-projection.md` (**fix staleness**: `debt-aware.md` hilang dari §17 hari ini); baris **Knowledge**: tambah `schema/`.

**TAK disentuh (eksplisit):** skill-count (tetap **21**), `plugin.json`, `marketplace.json`, README, induk §12 (proyeksi = side-effect, bukan fase lifecycle baru), `breakdown`/task-schema, `invariants.md`, `conventions.md`.

## 12. Verifikasi & bug-guard

**Grep-battery (post-exec):**
- V0 `plugin/rules/schema-projection.md` ADA + memuat klausa §5 (degrade-STOP, generik lintas-ORM, idempotent, penulis-tunggal). (Janji perilaku — prosa resep — diverifikasi by-read, bukan grep.)
- V1 `control/schema/` disebut sebagai output rule + dibaca plan + dibaca render-docs (≥3 surface).
- V2 `rules/schema-projection.md` direferensi build + wire (idiom `${CLAUDE_PLUGIN_ROOT}/rules/schema-projection.md`).
- V3 "penulis tunggal" terjaga: tak ada skill SELAIN rule yang menulis `control/schema/` (build/wire memanggil rule, bukan nulis sendiri).
- V4 skill-count tetap 21 di induk §17 + tak ada edit `plugin.json`/`marketplace.json`.
- V5 §17 Rules memuat 3 file; §7 punya node `schema/`; §17 Knowledge punya `schema/`.
- V6 template.html: 1 nav link `#schema` + 1 `<!-- SLOT:schema -->`.
- V7 tak ada referensi `data-model.md`/`roadmap.yaml`/`migrate.kind`/`migrate.affects`/`packages[].consumers` di artifact M4 (anti-fiksi, anti-H3).

**Bug-guard pre-bake (untuk plan):**
- **colon-space frontmatter:** kalau menyentuh `description:` SKILL.md mana pun, pakai ` — ` bukan `: ` di dalam nilai. (M4 tak ubah description → risiko rendah, tetap waspada.)
- **no-renumber:** semua sisipan = klausa/sub-bullet/slot baru — **jangan** renumber langkah skill.
- **mis-aimed-pointer:** verifikasi tiap `§X` (induk §4/§7/§8/§17) nunjuk seksi yang benar — di rule, skill, DAN spec ini.
- **sentinel literal-scan:** header `JANGAN edit tangan` & `(pra-M4)` aman; pastikan tak ada placeholder yang nabrak scan literal skill lain.
- **anchor verify:** tiap find/replace di-`grep -Fc -e`-kan verbatim SEBELUM commit (robust leading-dash & metachar `[]`/`**`).
- **one-file-per-task:** plan satu task = satu file.

## 13. Hubungan

- **vs M5 (`integrations.md`):** asimetri sadar (§4 spec ini) — vendor hand-authored, skema terproyeksi. Tak overlap; tak overload `packages[].consumers`.
- **→ H3 (migration-governance):** M4 LIVE dulu, baru H3. H3 me-re-anchor "siapa baca table X" ke `control/schema/` ini (BUKAN `packages[].consumers`, BUKAN `data-model.md`). M4 menyediakan struktur+provenance; H3 menambah consumer-side + `migrate.kind/affects` + gate dampak + zero-downtime. **M4 tak membangun apa pun dari H3.**
- **Lifecycle:** tak ada fase baru. Proyeksi = side-effect `wire`/`build`, dikonsumsi `plan`/`render-docs`.
- **Langkah berikutnya:** H3 (gap terakhir Langkah-2), lalu live `/plugin install` end-to-end test.
