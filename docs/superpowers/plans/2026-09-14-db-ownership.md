# Kepemilikan skema (`databases[]`) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** N app boleh menempel ke 1 database tanpa saling merusak — tepat satu unit memiliki DDL-nya (`databases[].owner`), `wire` menolak apply migrasi baseline ke DB milik unit lain, dan pembaca proyeksi skema me-resolve ke pemilik sehingga deteksi reuse tak lagi mati pada app non-pemilik.

**Architecture:** Perubahan ke **prosa skill (markdown)** — satu **rule baru** (`plugin/rules/db-ownership.md`) yang memuat bentuk `databases[]` + fungsi resolusi, lalu edit bertarget ke `schema-projection`/`migration-impact`/`architect`/`wire`/`plan`/`breakdown`/`build`/`render-docs`/`init`/`upgrade`/`ask`, lalu regen `plugin-kimi`. Tak ada kode yang dieksekusi, tak ada skrip baru. Verifikasi tiap edit prosa = **`grep -Fc` anchor unik sebelum edit** + **read-back sesudahnya**; acceptance akhir = grep konsistensi (frasa lama harus 0 di jalur yang diubah) + **desk-check terhadap produk nyata** `~/Developer/project/mahjong` (KuyMahjong).

**Tech Stack:** Markdown (skill files context-vault), Bash (`grep`, `sed`, `python3` untuk ekstraksi anchor), `tools/build-kimi.sh` + `tools/tests/build-kimi.test.sh`.

**Spec:** `docs/superpowers/specs/2026-09-14-db-ownership-design.md` — plan ini berargumen dari spec; executor baca keduanya. Rujukan `§N` di bawah menunjuk section spec itu.

## Global Constraints

- **Working dir:** `/Users/mac-098506/Developer/project/context-vault`. Source of truth = `plugin/`; `plugin-kimi/` **GENERATED** — jangan edit tangan, regen di Task 12.
- **Anchor by quoted-phrase, BUKAN nomor baris.** Nomor baris di plan ini cuma alat bantu cari; ia bergeser begitu task sebelumnya mengedit file yang sama. Sebelum tiap Edit: `grep -Fc -e '<old_string>' <file>` HARUS `1`. Bila `0` → anchor sudah berubah (task lain sudah jalan / file drift): **STOP dan lapor**, jangan tebak anchor pengganti. Bila `>1` → perluas kutipan sampai unik.
- **Kutipan utuh, bukan elisi.** Semua `old_string` di plan ini dikutip PERSIS dari file — termasuk `→`, `↔`, `×`, `≥`, backtick, dan bold yang memang bagian teks. Plan ini **tidak** memakai `…` sebagai tanda potong.
- **Vocab kanonik (dipakai lintas task, jangan drift):** blok `databases[]` dengan field `name, engine, migrations, owner` · fungsi `resolve_db(app)`, `schema_owner(unit)`, `engine(app)`, `is_schema_owner(unit)` · istilah **pemilik skema** (Indonesian, dipakai di prosa) vs `owner` (nama field YAML) · penanda amandemen `(amandemen 2026-09-14)` di tiap sisipan baru supaya reviewer bisa grep.
- **Default legacy adalah INVARIAN, bukan fitur.** Tiap edit WAJIB mempertahankan: `databases[]` absen ⇒ `schema_owner(unit) == unit` ⇒ perilaku byte-identik dengan sebelum perubahan. Kalau sebuah edit membuat produk 1:1 berubah perilaku, edit itu salah (spec §4.3).
- **JANGAN sentuh:** file `control/*` produk mana pun di `~/Developer/**` (termasuk KuyMahjong — Task 13 read-only), `plugin/hooks/*`, `plugin/template/.claude/drive.sh`, Security Gate `ship` step 4.5, daftar verba `tweak/reference.md` §A.
- **Tak menambah skill** (yang ditambah = *rule*, bukan skill) → jumlah skill di README / `plugin.json` / `marketplace.json` **tak berubah**. Jangan sentuh ketiganya.
- **Commit tiap task.** Pesan Indonesian + prefix conventional-commits, **TANPA** trailer `Co-Authored-By`, **DENGAN** footer `Claude-Session: https://claude.ai/code/session_01LGXi99joeXK7LFsPNnK7Uy` di baris terakhir.
- **Bahasa & gaya prosa** = ikuti file yang diedit: Indonesian, **bold** untuk aturan keras, `backtick` untuk artefak/field/status, em-dash untuk aposisi.

## File Structure

| file | tanggung jawab | task |
|---|---|---|
| `plugin/rules/db-ownership.md` **(BARU)** | sumber kebenaran: bentuk `databases[]`, 4 fungsi resolusi, aturan validasi, default legacy | T1 |
| `plugin/rules/schema-projection.md` | resolve ke pemilik; no-op (bukan stub) untuk non-pemilik | T2 |
| `plugin/rules/migration-impact.md` | catatan pengelompokan per-DB di step 1 | T3 |
| `plugin/skills/architect/SKILL.md` | penulis tunggal `databases[]`; Q&A kepemilikan; promosi 1:1→N:1 | T4 |
| `plugin/skills/wire/SKILL.md` | palang pra-migrate; langkah 2/3 non-pemilik; 5.5 opt-in hanya pemilik; §0 seed | T5 |
| `plugin/skills/wire/reference.md` | syarat gate "DB reachable" untuk non-pemilik | T6 |
| `plugin/skills/plan/SKILL.md` | baca proyeksi via `schema_owner` | T7 |
| `plugin/skills/breakdown/SKILL.md` + `reference.md` | baca via `schema_owner`; validasi unit task `migrate` | T8 |
| `plugin/skills/build/SKILL.md` | read-set, reconcile, slice brief, regen — semua via `schema_owner` | T9 |
| `plugin/skills/render-docs/SKILL.md` | kartu skema per database + baris pembaca | T10 |
| `plugin/skills/init/SKILL.md`, `upgrade/SKILL.md`, `ask/SKILL.md` | seed template; advisory deteksi; baris tabel rute | T11 |
| `plugin-kimi/**` | regen (generated) | T12 |

**Urutan wajib:** T1 lebih dulu (semua task lain merujuk nama fungsi yang ia definisikan). T2–T11 saling bebas — boleh paralel, **kecuali** T8 yang menyentuh dua file dalam satu task. T12 sesudah T1–T11 semua hijau. T13 terakhir.

---

### Task 1: `plugin/rules/db-ownership.md` — rule baru (fondasi)

**Files:**
- Create: `plugin/rules/db-ownership.md`

**Interfaces:**
- Produces: nama fungsi `resolve_db(app)`, `schema_owner(unit)`, `engine(app)`, `is_schema_owner(unit)`; bentuk blok `databases[]` (`name`, `engine`, `migrations`, `owner`); 4 aturan validasi. **Task 2–11 merujuk rule ini lewat path `${CLAUDE_PLUGIN_ROOT}/rules/db-ownership.md` dan memakai nama fungsi di atas PERSIS** — jangan diparafrase jadi nama lain.

- [ ] **Step 1: Pastikan file belum ada**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
ls plugin/rules/
test -e plugin/rules/db-ownership.md && echo "SUDAH ADA — STOP" || echo "belum ada, lanjut"
```
Expected: listing memuat `anti-yes-man.md`, `migration-impact.md`, `pr-template.md`, `schema-projection.md` (dan lain-lain); baris terakhir `belum ada, lanjut`.

- [ ] **Step 2: Tulis file**

Create `plugin/rules/db-ownership.md` dengan isi PERSIS berikut:

````markdown
# DB Ownership — siapa pemilik skema sebuah database (aturan share)

Dirujuk skill yang menyentuh database sebuah unit: `architect` (penulis tunggal `databases[]`), `wire` (palang pra-migrate + langkah 2/3 + 5.5), `plan`/`breakdown`/`build` (pembaca proyeksi skema), `render-docs`, serta rule `schema-projection.md` & `migration-impact.md`. **BUKAN langkah berdiri sendiri** — ia **prosedur RESOLUSI read-only** yang dipanggil pemanggil itu.

Tujuan: menjawab pertanyaan yang dulu tak pernah ditanyakan — **"kalau N app menempel ke 1 database, siapa yang berhak meng-apply DDL?"** Tanpa jawabannya, `wire` menimpa riwayat migrasi app lain (tabel riwayat itu TUNGGAL per-DB: `supabase_migrations.schema_migrations`, `alembic_version`, `_prisma_migrations`, `goose_db_version`), dan proyeksi skema app non-pemilik lahir stub sehingga deteksi reuse mati diam-diam.

## Read-only (tak nulis file)
Rule ini cuma **me-resolve** lalu balik nilai in-memory. Penulis `databases[]` = `architect` (tunggal). Penulis `control/schema/` = `schema-projection.md` (tunggal). Rule ini tak menulis apa pun → tak ada concern penulis-tunggal.

## Artefak — blok `databases[]` di `control/workspace.yaml`

```yaml
databases:                                     # OPSIONAL — absen = semua app 1:1 (status quo)
  - name: main                                 # slug pendek; dirujuk stack.db
    engine: Supabase Postgres                  # engine/service; dulu nilai free-text stack.db
    migrations: kuymahjong/supabase/migrations # path folder migrasi, relatif ROOT PRODUK
    owner: kuymahjong                          # unit ∈ apps[].name — pemegang DDL
apps:
  - name: kuymahjong
    stack: { db: main, orm: "@supabase/supabase-js" }
  - name: venue
    stack: { db: main }                        # menempel, BUKAN pemilik
```

**`migrations` dan `owner` sengaja dipisah.** `migrations` = di mana folder itu **tinggal** — boleh di luar app mana pun (mis. monorepo dengan `supabase/` di root produk). `owner` = unit mana yang **task `migrate`-nya** mendarat dan yang proyeksi skemanya jadi kanonik. Memisahkan keduanya membuat layout root-level bekerja tanpa konsep tambahan.

**Hanya app.** `owner` HARUS unit `apps[]`. Package tak punya DB (lihat `breakdown/reference.md` §D-4); pseudo-unit `integration` tak punya path sendiri.

## Resolusi (fungsi — dipanggil pemanggil)

```
resolve_db(app)       = entri databases[] yang name-nya == app.stack.db
                        → NULL bila databases[] absen ATAU tak ada name yang cocok

schema_owner(unit)    = resolve_db(unit).owner   bila resolve_db(unit) != NULL
                      = unit                     selainnya            ← DEFAULT LEGACY

engine(app)           = resolve_db(app).engine   bila resolve_db(app) != NULL
                      = app.stack.db (free-text) selainnya            ← DEFAULT LEGACY

is_schema_owner(unit) = (schema_owner(unit) == unit)
```

**Nama parameter `app` dan `unit` bisa dipertukarkan** — nama app ADALAH nama unit (`apps[].name` ⊂ ruang nama unit). Pemanggil boleh menulis `schema_owner(app)` atau `schema_owner(unit)`; keduanya fungsi yang sama. Yang tidak sah cuma menyerahkan nama package atau `integration` (lihat "Hanya app" di atas).

**Pencocokan sengaja toleran.** `stack.db` boleh berupa **referensi** (`main`) **atau** free-text engine lama (`"Supabase Postgres (migrations di supabase/migrations, 38 file)"`). Cocok dengan sebuah `databases[].name` → mode kepemilikan. Tak cocok → legacy: app jadi pemilik dirinya sendiri dan string diperlakukan sebagai nama engine seperti selama ini. **Tak ada produk yang bisa pecah karena belum menulis ulang `stack.db`.**

**Default legacy adalah INVARIAN.** `databases[]` absen ⇒ tiap fungsi di atas jatuh ke identitas ⇒ perilaku byte-identik dengan sebelum rule ini ada. Pemanggil yang membuat produk 1:1 berubah perilaku berarti salah memakai rule ini.

Konsekuensi yang disengaja: agar deklarasi `databases[]` **berlaku**, `architect` menulis ulang `stack.db` tiap app terkait menjadi referensi — bagian dari langkah deklarasi, di-GATE.

## Validasi (dijalankan `architect` saat menulis; `breakdown` saat gate)

1. `owner` HARUS ∈ `apps[].name` — bukan `packages[]`, bukan `integration`.
2. `owner` sendiri HARUS `stack.db == <name>` — pemilik wajib menempel ke DB yang ia miliki.
3. `name` unik lintas `databases[]`.
4. App yang `stack.db`-nya merujuk `name` tak dikenal **bukan error** — itu jalur legacy (toleransi di atas). Yang ditangkap `wire`: dua app menembak DB sama sementara `resolve_db` masih NULL.

Deklarasi tak konsisten → **gate manusia** (tampilkan + minta koreksi), jangan auto-repair: `workspace.yaml` itu knowledge, keputusannya milik manusia.

## Sifat
- **Read-only:** tak pernah menulis file.
- **Aditif murni:** `databases[]` absen ⇒ status quo. Nol migrasi untuk produk lama, nol mode-legacy bercabang di skill pemanggil.
- **Generik lintas-stack:** tak ada cabang hardcode per-engine. Supabase hanya contoh.
- **Tanpa DB hidup:** semua resolusi dari `workspace.yaml` + file sumber. Tak ada introspeksi koneksi.
- **Degrade, jangan crash:** ragu → serahkan ke gate manusia (fail-safe, sejajar disiplin `migrate` jangan-auto).
````

- [ ] **Step 3: Verifikasi file & anchor yang akan dirujuk task lain**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -c . plugin/rules/db-ownership.md
for fn in 'resolve_db(app)' 'schema_owner(unit)' 'engine(app)' 'is_schema_owner(unit)'; do
  printf '%s -> ' "$fn"; grep -Fc -e "$fn" plugin/rules/db-ownership.md
done
grep -Fc -e 'DEFAULT LEGACY' plugin/rules/db-ownership.md
```
Expected: jumlah baris non-kosong > 40; tiap fungsi count ≥ 1; `DEFAULT LEGACY` count `2`.

- [ ] **Step 4: Commit**

```bash
cd /Users/mac-098506/Developer/project/context-vault
git add plugin/rules/db-ownership.md
git commit -F - <<'MSG'
feat(rules): db-ownership — resolusi pemilik skema untuk N app : 1 database

Rule share read-only: bentuk databases[] (name/engine/migrations/owner),
4 fungsi resolusi, 4 aturan validasi. Default legacy = identitas, jadi
produk 1:1 existing berperilaku byte-identik tanpa migrasi apa pun.

Claude-Session: https://claude.ai/code/session_01LGXi99joeXK7LFsPNnK7Uy
MSG
```

---

### Task 2: `schema-projection.md` — resolve ke pemilik, no-op untuk non-pemilik

**Files:**
- Modify: `plugin/rules/schema-projection.md` (2 edit: baris ≈3 tujuan, baris ≈9 input `app`)

**Interfaces:**
- Consumes: `schema_owner(unit)`, `is_schema_owner(unit)` dari T1.
- Produces: kontrak baru "dipanggil untuk non-pemilik = **no-op diam**, bukan stub" — dirujuk T5 (wire §0 seed) dan T9 (build regen).

- [ ] **Step 1: Konfirmasi kedua anchor unik**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -Fc -e 'Hormati induk §4 "satu sumber kebenaran (kode: skema/migrasi), banyak proyeksi".' plugin/rules/schema-projection.md
grep -Fc -e '- `app` — nama app (∈ `workspace.yaml` `apps[].name`). HANYA unit app — package tak punya table; pseudo-unit `integration` n/a.' plugin/rules/schema-projection.md
```
Expected: dua-duanya `1`.

- [ ] **Step 2: Edit A — tambah paragraf kepemilikan sesudah kalimat tujuan**

Edit tool pada `plugin/rules/schema-projection.md`:

`old_string`:
```
Hormati induk §4 "satu sumber kebenaran (kode: skema/migrasi), banyak proyeksi".
```

`new_string`:
```
Hormati induk §4 "satu sumber kebenaran (kode: skema/migrasi), banyak proyeksi".

**Proyeksi milik PEMILIK SKEMA, bukan tiap app (amandemen 2026-09-14).** Bila beberapa app menempel ke satu database, hanya app pemilik yang punya folder migrasi — jadi hanya ia yang punya proyeksi. Resolve `schema_owner(app)` per `${CLAUDE_PLUGIN_ROOT}/rules/db-ownership.md` lebih dulu: `is_schema_owner(app)` **true** → prosedur jalan seperti biasa, menulis `control/schema/<app>.md`; **false** → **NO-OP DIAM, jangan tulis stub**. Stub berarti "app ini nol tabel" — pernyataan yang SALAH untuk app non-pemilik, dan justru mematikan deteksi reuse di `plan`/`breakdown`/`build`. Ketiadaan file pada non-pemilik bukan lubang: pembaca me-resolve ke file pemiliknya. `databases[]` absen ⇒ `schema_owner(app) == app` ⇒ semua app pemilik dirinya sendiri ⇒ perilaku persis seperti sebelum amandemen ini.
```

- [ ] **Step 3: Edit B — perluas kontrak input `app`**

Edit tool pada `plugin/rules/schema-projection.md`:

`old_string`:
```
- `app` — nama app (∈ `workspace.yaml` `apps[].name`). HANYA unit app — package tak punya table; pseudo-unit `integration` n/a.
```

`new_string`:
```
- `app` — nama app (∈ `workspace.yaml` `apps[].name`). HANYA unit app — package tak punya table; pseudo-unit `integration` n/a. **Pemanggil boleh menyerahkan app mana pun**; rule me-resolve `schema_owner(app)` lebih dulu dan no-op bila app itu bukan pemilik (lihat paragraf kepemilikan di atas).
```

- [ ] **Step 4: Read-back**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -Fc -e 'NO-OP DIAM, jangan tulis stub' plugin/rules/schema-projection.md
grep -Fc -e 'rule me-resolve `schema_owner(app)` lebih dulu' plugin/rules/schema-projection.md
grep -Fc -e 'db-ownership.md' plugin/rules/schema-projection.md
```
Expected: `1`, `1`, `1`.

- [ ] **Step 5: Commit**

```bash
cd /Users/mac-098506/Developer/project/context-vault
git add plugin/rules/schema-projection.md
git commit -F - <<'MSG'
fix(rules): schema-projection resolve ke pemilik skema, no-op untuk non-pemilik

App non-pemilik dulu dapat stub "belum ada tabel" — pernyataan salah yang
mematikan deteksi reuse di plan/breakdown/build (bug B2 spec). Sekarang
no-op diam; pembaca me-resolve ke proyeksi pemiliknya.

Claude-Session: https://claude.ai/code/session_01LGXi99joeXK7LFsPNnK7Uy
MSG
```

---

### Task 3: `migration-impact.md` — catatan pengelompokan per-DB

**Files:**
- Modify: `plugin/rules/migration-impact.md` (1 edit, step 1 "Bibit dari M4")

**Interfaces:**
- Consumes: `resolve_db(app)` dari T1.
- Produces: tak ada kontrak baru. **Catatan penting untuk reviewer:** logika rule ini SUDAH benar (step 1 & 2 sudah iterate lintas app) — task ini hanya menambah kejelasan, **jangan** "memperbaiki" cakupannya.

- [ ] **Step 1: Konfirmasi anchor unik**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -Fc -e 'Catat `Asal` tabel kena (fitur pemilik) buat konteks.' plugin/rules/migration-impact.md
```
Expected: `1`.

- [ ] **Step 2: Edit**

Edit tool pada `plugin/rules/migration-impact.md`:

`old_string`:
```
Catat `Asal` tabel kena (fitur pemilik) buat konteks.
```

`new_string`:
```
Catat `Asal` tabel kena (fitur pemilik) buat konteks. **Pengelompokan per-DB (amandemen 2026-09-14):** bila `workspace.yaml` punya blok `databases[]` (`${CLAUDE_PLUGIN_ROOT}/rules/db-ownership.md`), sebut EKSPLISIT di laporan app mana saja yang `resolve_db`-nya sama dengan DB tabel `affects` — mereka pembaca satu-DB dan sudah tertangkap step 2, tapi menamainya membuat laporan terbaca ("`venue`, `admin` membaca DB `main`"). Ini **menambah kejelasan, bukan cakupan** — jangan ubah iterasi step 1/step 2 yang sudah melintasi semua app.
```

- [ ] **Step 3: Read-back**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -Fc -e 'menambah kejelasan, bukan cakupan' plugin/rules/migration-impact.md
grep -Fc -e 'Buat tiap app, baca kode' plugin/rules/migration-impact.md
```
Expected: `1` dan `1` (yang kedua membuktikan step 2 tak tersentuh).

- [ ] **Step 4: Commit**

```bash
cd /Users/mac-098506/Developer/project/context-vault
git add plugin/rules/migration-impact.md
git commit -F - <<'MSG'
docs(rules): migration-impact sebut pengelompokan per-DB di laporan step 1

Cakupan TIDAK berubah (step 1/2 sudah iterate lintas app). Hanya menamai
app sesama-DB supaya laporan terbaca saat databases[] ada.

Claude-Session: https://claude.ai/code/session_01LGXi99joeXK7LFsPNnK7Uy
MSG
```

---

### Task 4: `architect/SKILL.md` — penulis tunggal `databases[]` + Q&A kepemilikan

**Files:**
- Modify: `plugin/skills/architect/SKILL.md` (2 edit: 3a SETUP, 3b CAPTURE)

**Interfaces:**
- Consumes: bentuk `databases[]` + 4 aturan validasi dari T1.
- Produces: **`architect` = satu-satunya penulis `databases[]`** — dirujuk T5 (pesan palang `wire` mengarahkan ke sini) dan T11 (advisory `upgrade` mengarahkan ke sini).

- [ ] **Step 1: Konfirmasi kedua anchor unik**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -Fc -e '- Tulis hasil ke `stack` app di `control/workspace.yaml` (mis. `stack: { framework: Next.js, db: Postgres, orm: Prisma }`).' plugin/skills/architect/SKILL.md
grep -Fc -e '- Catat **divergensi** antar-app (mis. `web` pakai Prisma, `dashboard` pakai TypeORM) → laporkan ke user.' plugin/skills/architect/SKILL.md
```
Expected: dua-duanya `1`.

- [ ] **Step 2: Edit A — 3a SETUP: Q&A kepemilikan DB + promosi 1:1→N:1**

Edit tool pada `plugin/skills/architect/SKILL.md`:

`old_string`:
```
- Tulis hasil ke `stack` app di `control/workspace.yaml` (mis. `stack: { framework: Next.js, db: Postgres, orm: Prisma }`).
```

`new_string`:
```
- Tulis hasil ke `stack` app di `control/workspace.yaml` (mis. `stack: { framework: Next.js, db: Postgres, orm: Prisma }`).
- **Kepemilikan DB (amandemen 2026-09-14) — tanya HANYA bila produk sudah punya ≥1 app ber-DB lain.** Pertanyaannya: *"DB buat app ini — bikin baru, atau nempel ke `<name>` (`<engine>`, dipegang `<owner>`)?"*
  - **Bikin baru** → entri `databases[]` baru dengan `owner` = app ini. **Kecuali** bila `databases[]` masih absen DAN ini app ber-DB pertama → biarkan absen; 1:1 legacy sudah benar, jangan tulis blok yang tak mengubah perilaku.
  - **Nempel** → `stack.db` app ini = `<name>`; `owner` **TIDAK** berubah.
  - **Promosi 1:1 → N:1** (app kedua memilih nempel sementara `databases[]` masih absen) — lahirkan bloknya dalam SATU transaksi ter-GATE: (1) baca free-text `stack.db` app pemilik, ekstrak engine + path folder migrasi **by-understanding** (`conventions.md` + struktur repo, cara yang sama `schema-projection.md` step 1 melokalisasi sumber); (2) tulis entri `databases[]` — `name` (usulkan `main`, konfirmasi), `engine`, `migrations`, `owner` = app pemilik; (3) **tulis ulang `stack.db` KEDUA app jadi referensi** — tanpa ini deklarasi tak berlaku (pencocokan toleran `db-ownership.md`); (4) tampilkan diff `workspace.yaml` → **approve**.
  - `architect` adalah **penulis tunggal `databases[]`**. Bentuk, 4 fungsi resolusi, dan 4 aturan validasi: `${CLAUDE_PLUGIN_ROOT}/rules/db-ownership.md`. Validasi SEBELUM menulis; tak konsisten → tampilkan + minta koreksi, JANGAN auto-repair.
```

- [ ] **Step 3: Edit B — 3b CAPTURE: divergensi ORM sesama-DB**

Edit tool pada `plugin/skills/architect/SKILL.md`:

`old_string`:
```
- Catat **divergensi** antar-app (mis. `web` pakai Prisma, `dashboard` pakai TypeORM) → laporkan ke user.
```

`new_string`:
```
- Catat **divergensi** antar-app (mis. `web` pakai Prisma, `dashboard` pakai TypeORM) → laporkan ke user. **Bila dua app ternyata menembak DB yang sama (amandemen 2026-09-14):** sodorkan kepemilikan di gate — usulkan `databases[]` + `owner` (prosedur promosi di 3a). Divergensi `orm` antar-app sesama-DB **sah** (mis. satu pakai client SDK, satu pakai driver mentah) → laporkan, jangan jadikan palang.
```

- [ ] **Step 4: Read-back**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -Fc -e 'penulis tunggal `databases[]`' plugin/skills/architect/SKILL.md
grep -Fc -e 'Promosi 1:1 → N:1' plugin/skills/architect/SKILL.md
grep -Fc -e 'db-ownership.md' plugin/skills/architect/SKILL.md
grep -Fc -e 'amandemen 2026-09-14' plugin/skills/architect/SKILL.md
```
Expected: `1`, `1`, `1`, `2`.

- [ ] **Step 5: Commit**

```bash
cd /Users/mac-098506/Developer/project/context-vault
git add plugin/skills/architect/SKILL.md
git commit -F - <<'MSG'
feat(architect): penulis tunggal databases[] + Q&A kepemilikan DB

Q&A "bikin baru atau nempel" muncul hanya saat produk sudah punya app
ber-DB lain. Promosi 1:1->N:1 lahir dalam satu transaksi ter-GATE,
termasuk menulis ulang stack.db jadi referensi (tanpa itu deklarasi
tak berlaku).

Claude-Session: https://claude.ai/code/session_01LGXi99joeXK7LFsPNnK7Uy
MSG
```

---

### Task 5: `wire/SKILL.md` — palang pra-migrate + langkah 2/3 + 5.5 + §0 seed

**Files:**
- Modify: `plugin/skills/wire/SKILL.md` (4 edit: Prinsip, §0 seed, langkah 2, langkah 3, 5.5 — lihat catatan)

**Interfaces:**
- Consumes: `resolve_db`, `is_schema_owner` dari T1; kontrak no-op dari T2; nama skill `architect` sebagai tujuan arahan dari T4.
- Produces: palang pra-migrate — dirujuk T13 (desk-check skenario 3).

> **Catatan anchor:** task ini mengedit SATU file di 5 titik. Kerjakan **berurutan** Step 2→6; tiap Edit memakai kutipan unik yang tak tumpang-tindih dengan Edit lain di task ini.

- [ ] **Step 1: Konfirmasi semua anchor unik SEKALIGUS**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
F=plugin/skills/wire/SKILL.md
grep -Fc -e '- **Jangan mutusin arsitektur.**' $F
grep -Fc -e '`stack.orm` kosong **dan** tak ada folder migrasi → tulis stub + **warning** (app uncovered), jangan no-op diam.' $F
grep -Fc -e 'Sesuai hasil 0.5: bare-engine → spin Docker lokal (generate `docker-compose.yml`) / URL remote; managed → connect pakai creds (GATE). (reference C.)' $F
grep -Fc -e 'Init ORM/driver (`stack.orm`), generate migrasi **baseline** (kosong dari table fitur), **apply** (GATE — migrate jangan auto), smoke query buktikan koneksi.' $F
grep -Fc -e '**Opt-in apply-migrate additive (skippable, amandemen 2026-08-27):** untuk unit ber-DB, tanyakan TERPISAH dari rule verifikasi:' $F
```
Expected: kelima-limanya `1`. Ada yang `0` → STOP, lapor.

- [ ] **Step 2: Edit A — Prinsip: palang pemilik skema**

Edit tool pada `plugin/skills/wire/SKILL.md`:

`old_string`:
```
- **Jangan mutusin arsitektur.**
```

`new_string`:
```
- **DDL cuma milik pemilik skema (amandemen 2026-09-14).** Sebelum apply migrasi apa pun (langkah 3), resolve `is_schema_owner(app)` per `${CLAUDE_PLUGIN_ROOT}/rules/db-ownership.md`. Non-pemilik TIDAK pernah generate/apply migrasi — riwayat migrasi itu TUNGGAL per-DB, jadi folder migrasi kedua = mismatch permanen. Kepemilikan belum dideklarasi tapi ada app lain menembak DB sama → **palang** langkah 3.
- **Jangan mutusin arsitektur.**
```

- [ ] **Step 3: Edit B — §0 seed: stub+warning hanya untuk pemilik**

Edit tool pada `plugin/skills/wire/SKILL.md`:

`old_string`:
```
`stack.orm` kosong **dan** tak ada folder migrasi → tulis stub + **warning** (app uncovered), jangan no-op diam.
```

`new_string`:
```
`stack.orm` kosong **dan** tak ada folder migrasi → tulis stub + **warning** (app uncovered), jangan no-op diam. **Hanya berlaku untuk PEMILIK skema (amandemen 2026-09-14):** app yang `is_schema_owner`-nya false bukan "uncovered" — ia tercakup proyeksi pemiliknya, jadi `schema-projection.md` no-op dan **tak ada warning**.
```

- [ ] **Step 4: Edit C — langkah 2: non-pemilik menyambung, bukan provision**

Edit tool pada `plugin/skills/wire/SKILL.md`:

`old_string`:
```
Sesuai hasil 0.5: bare-engine → spin Docker lokal (generate `docker-compose.yml`) / URL remote; managed → connect pakai creds (GATE). (reference C.)
```

`new_string`:
```
Sesuai hasil 0.5: bare-engine → spin Docker lokal (generate `docker-compose.yml`) / URL remote; managed → connect pakai creds (GATE). (reference C.) **Non-pemilik (amandemen 2026-09-14):** `is_schema_owner(app)` false → **JANGAN provision database baru** — sambungkan ke DB existing (`engine(app)` + connection string dari env, GATE seperti biasa).
```

- [ ] **Step 5: Edit D — langkah 3: palang + skip baseline untuk non-pemilik**

Edit tool pada `plugin/skills/wire/SKILL.md`:

`old_string`:
```
Init ORM/driver (`stack.orm`), generate migrasi **baseline** (kosong dari table fitur), **apply** (GATE — migrate jangan auto), smoke query buktikan koneksi.
```

`new_string`:
```
Init ORM/driver (`stack.orm`), generate migrasi **baseline** (kosong dari table fitur), **apply** (GATE — migrate jangan auto), smoke query buktikan koneksi. **PALANG pra-migrate (amandemen 2026-09-14) — jalankan SEBELUM generate/apply:** adakah app **lain** di `workspace.yaml` yang menembak target DB sama? Bila ya **DAN** `resolve_db(app)` == NULL (kepemilikan belum dideklarasi — `databases[]` absen, atau `stack.db` app ini tak cocok entri mana pun) → **STOP, JANGAN apply**, lapor: *"app `<app>` nembak DB yang sama dengan `<app-lain>`, tapi kepemilikan migrasi belum dideklarasi. Jalanin `architect` dulu buat nentuin pemiliknya — kalau diterusin, migrasi baseline ini bakal nabrak riwayat migrasi yang udah ada."* Deteksi "target sama" **best-effort tanpa DB hidup** (banding `stack.db` ter-resolve; bila keduanya free-text, banding string + path folder migrasi yang terlokalisasi) — **ragu → tetap STOP** dan minta manusia memutuskan (fail-safe, sejajar disiplin `migrate` jangan-auto). **Non-pemilik** (`is_schema_owner(app)` false, kepemilikan SUDAH dideklarasi) → **SKIP generate + apply baseline**; init driver/ORM dan smoke query TETAP jalan (koneksi tetap wajib dibuktikan), dan `schema-projection` di bawah **tidak** dipanggil (no-op per rule-nya).
```

- [ ] **Step 6: Edit E — 5.5: opt-in hanya pemilik + deny cermin untuk non-pemilik**

Edit tool pada `plugin/skills/wire/SKILL.md`:

`old_string`:
```
**Opt-in apply-migrate additive (skippable, amandemen 2026-08-27):** untuk unit ber-DB, tanyakan TERPISAH dari rule verifikasi:
```

`new_string`:
```
**Opt-in apply-migrate additive (skippable, amandemen 2026-08-27; dipersempit 2026-09-14):** untuk unit ber-DB **yang `is_schema_owner`-nya true** (`${CLAUDE_PLUGIN_ROOT}/rules/db-ownership.md`), tanyakan TERPISAH dari rule verifikasi:
```

- [ ] **Step 7: Edit F — 5.5: tambahkan deny cermin untuk non-pemilik**

Edit tool pada `plugin/skills/wire/SKILL.md`:

`old_string`:
```
Tanpa opt-in, `build` men-hold migrasi additive (`hold: "allowlist migrate absen — wire 5.5"`) — bukan freeze, bukan `halt`.
```

`new_string`:
```
Tanpa opt-in, `build` men-hold migrasi additive (`hold: "allowlist migrate absen — wire 5.5"`) — bukan freeze, bukan `halt`. **Unit NON-pemilik (amandemen 2026-09-14):** opt-in tak pernah ditawarkan, DAN perintah apply tool DB-nya di-APPEND ke `permissions.deny` (mis. `Bash(supabase db push:*)`) — supaya `build --unattended` dari unit itu tak bisa apply meski task-nya salah dirakit. Ini pasangan runtime dari palang gate `breakdown` (task `migrate` cuma sah di unit pemilik): satu menolak saat merakit, satu menolak saat menjalankan.
```

- [ ] **Step 8: Read-back semua**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
F=plugin/skills/wire/SKILL.md
grep -Fc -e 'DDL cuma milik pemilik skema' $F
grep -Fc -e 'PALANG pra-migrate' $F
grep -Fc -e 'ragu → tetap STOP' $F
grep -Fc -e 'JANGAN provision database baru' $F
grep -Fc -e 'dipersempit 2026-09-14' $F
grep -Fc -e 'Unit NON-pemilik (amandemen 2026-09-14)' $F
grep -Fc -e 'amandemen 2026-09-14' $F
```
Expected: enam yang pertama `1`; yang terakhir `6`.

- [ ] **Step 9: Commit**

```bash
cd /Users/mac-098506/Developer/project/context-vault
git add plugin/skills/wire/SKILL.md
git commit -F - <<'MSG'
fix(wire): palang pra-migrate + non-pemilik skip baseline (bug B1, B4)

Langkah 3 dulu selalu generate+apply migrasi baseline tanpa menanyakan
apakah DB itu sudah dipegang unit lain — riwayat migrasi tunggal per-DB
jadi rusak permanen. Sekarang: palang saat kepemilikan belum dideklarasi
(ragu -> STOP), skip baseline untuk non-pemilik (smoke query tetap),
opt-in allowlist apply hanya untuk pemilik + deny cermin untuk sisanya.

Claude-Session: https://claude.ai/code/session_01LGXi99joeXK7LFsPNnK7Uy
MSG
```

---

### Task 6: `wire/reference.md` — syarat gate "DB reachable" untuk non-pemilik

**Files:**
- Modify: `plugin/skills/wire/reference.md` (2 edit: syarat gate ≈45, catatan presence-based ≈54)

**Interfaces:**
- Consumes: `is_schema_owner` (T1); keputusan skip-baseline (T5).

- [ ] **Step 1: Konfirmasi anchor unik**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -Fc -e '2. **DB reachable** — ORM connect, migrasi baseline ter-apply, smoke query ijo.' plugin/skills/wire/reference.md
grep -Fc -e 'Single-writer dihormati: `wire` **invoke** `schema-projection.md`, tak nulis `control/schema/` langsung.' plugin/skills/wire/reference.md
```
Expected: dua-duanya `1`.

- [ ] **Step 2: Edit A — syarat gate**

Edit tool pada `plugin/skills/wire/reference.md`:

`old_string`:
```
2. **DB reachable** — ORM connect, migrasi baseline ter-apply, smoke query ijo.
```

`new_string`:
```
2. **DB reachable** — ORM connect, migrasi baseline ter-apply, smoke query ijo. **Non-pemilik skema (amandemen 2026-09-14):** klausa "migrasi baseline ter-apply" **DICORET** — syaratnya jadi *ORM connect + smoke query ijo* saja. Unit itu memang tak pernah meng-apply DDL (`wire` SKILL langkah 3); yang tetap wajib dibuktikan adalah koneksinya.
```

- [ ] **Step 3: Edit B — catatan presence-based**

Edit tool pada `plugin/skills/wire/reference.md`:

`old_string`:
```
Single-writer dihormati: `wire` **invoke** `schema-projection.md`, tak nulis `control/schema/` langsung.
```

`new_string`:
```
Single-writer dihormati: `wire` **invoke** `schema-projection.md`, tak nulis `control/schema/` langsung. **Hanya pemilik yang punya proyeksi (amandemen 2026-09-14):** seed presence-based ini berlaku untuk app `is_schema_owner`; app non-pemilik sengaja TIDAK punya file di `control/schema/` (rule-nya no-op, bukan stub) — ketiadaannya bukan lubang yang perlu di-seed.
```

- [ ] **Step 4: Read-back**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -Fc -e 'klausa "migrasi baseline ter-apply" **DICORET**' plugin/skills/wire/reference.md
grep -Fc -e 'ketiadaannya bukan lubang yang perlu di-seed' plugin/skills/wire/reference.md
```
Expected: `1`, `1`.

- [ ] **Step 5: Commit**

```bash
cd /Users/mac-098506/Developer/project/context-vault
git add plugin/skills/wire/reference.md
git commit -F - <<'MSG'
fix(wire): syarat gate DB-reachable non-pemilik tanpa klausa baseline

Gate lama mensyaratkan "migrasi baseline ter-apply" — mustahil dipenuhi
unit yang memang tak boleh apply DDL. Koneksi tetap wajib dibuktikan.

Claude-Session: https://claude.ai/code/session_01LGXi99joeXK7LFsPNnK7Uy
MSG
```

---

### Task 7: `plan/SKILL.md` — baca proyeksi via `schema_owner`

**Files:**
- Modify: `plugin/skills/plan/SKILL.md` (1 edit, baris ≈39)

**Interfaces:**
- Consumes: `schema_owner(unit)` dari T1.
- Produces: verdict `Model/Schema` yang kini melihat tabel existing untuk app non-pemilik — prasyarat T13 desk-check skenario 4.

- [ ] **Step 1: Konfirmasi anchor unik**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -Fc -e '- **Baca `control/schema/<app>.md` (proyeksi skema durable, M4) DULU** sebagai baseline model data existing (table/kolom/relasi/`Asal`) — **JANGAN rekonstruksi skema dari nol**.' plugin/skills/plan/SKILL.md
```
Expected: `1`.

- [ ] **Step 2: Edit**

Edit tool pada `plugin/skills/plan/SKILL.md`:

`old_string`:
```
- **Baca `control/schema/<app>.md` (proyeksi skema durable, M4) DULU** sebagai baseline model data existing (table/kolom/relasi/`Asal`) — **JANGAN rekonstruksi skema dari nol**.
```

`new_string`:
```
- **Baca `control/schema/<schema_owner(app)>.md` (proyeksi skema durable, M4) DULU** sebagai baseline model data existing (table/kolom/relasi/`Asal`) — **JANGAN rekonstruksi skema dari nol**. **Resolusi pemilik (amandemen 2026-09-14):** `schema_owner(app)` per `${CLAUDE_PLUGIN_ROOT}/rules/db-ownership.md`; `databases[]` absen ⇒ hasilnya `app` itu sendiri ⇒ path persis seperti sebelumnya. Bila app menempel ke DB milik unit lain, baseline-nya adalah proyeksi **pemilik** — tanpa ini `plan` melihat "nol tabel" lalu memutuskan `NEW` untuk tabel yang sudah ada.
```

- [ ] **Step 3: Read-back**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -Fc -e 'control/schema/<schema_owner(app)>.md' plugin/skills/plan/SKILL.md
grep -Fc -e 'memutuskan `NEW` untuk tabel yang sudah ada' plugin/skills/plan/SKILL.md
grep -Fc -e '**Fallback:** `control/schema/<app>.md` absen/stub padahal app jelas ber-DB' plugin/skills/plan/SKILL.md
```
Expected: `1`, `1`, `1` (yang ketiga membuktikan jalur fallback lama masih utuh — spec §3.6).

- [ ] **Step 4: Commit**

```bash
cd /Users/mac-098506/Developer/project/context-vault
git add plugin/skills/plan/SKILL.md
git commit -F - <<'MSG'
fix(plan): baseline reuse-vs-NEW dibaca via schema_owner (bug B2)

App non-pemilik dulu melihat proyeksi stub -> memutuskan NEW untuk tabel
yang sudah ada. Jalur fallback lama dipertahankan utuh.

Claude-Session: https://claude.ai/code/session_01LGXi99joeXK7LFsPNnK7Uy
MSG
```

---

### Task 8: `breakdown` — baca via `schema_owner` + validasi unit task `migrate`

**Files:**
- Modify: `plugin/skills/breakdown/SKILL.md` (2 edit: read-set/validasi unit ≈15, konsultasi reuse ≈23)
- Modify: `plugin/skills/breakdown/reference.md` (2 edit: manifest ≈12, aturan `actions` ≈196)

**Interfaces:**
- Consumes: `schema_owner`, `is_schema_owner` dari T1.
- Produces: **gate "task `migrate` cuma sah di unit pemilik"** — pasangan merakit dari deny-cermin runtime T5; dirujuk T13 desk-check skenario 5.

- [ ] **Step 1: Konfirmasi keempat anchor unik**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -Fc -e '**Validasi unit (GATE eksplisit):** tiap `task.unit` HARUS cocok `apps[].name` ATAU `packages[].name` ATAU `integration`; kalau tidak → STOP + saran (`add-app`/`add-package`/typo).' plugin/skills/breakdown/SKILL.md
grep -Fc -e '**Reuse-aware (sebelum nulis `files`):** untuk task yang nyentuh data/file, konsultasi `control/schema/<app>.md` (tabel existing) + lirik ringan dir target (file existing).' plugin/skills/breakdown/SKILL.md
grep -Fc -e '  - control/schema/<unit>.md     #   tiap unit ber-DB yang kena (baseline skema)' plugin/skills/breakdown/reference.md
grep -Fc -e '**`migrate` membawa `kind`+`affects`** (§A): `kind` = additive|destructive|backfill (action-scoped `migrate.kind`, beda dari `kind:` level-task), `affects` = [tabel, Table.kolom].' plugin/skills/breakdown/reference.md
```
Expected: keempat-empatnya `1`.

- [ ] **Step 2: Edit A — validasi unit: tambah aturan migrate**

Edit tool pada `plugin/skills/breakdown/SKILL.md`:

`old_string`:
```
**Validasi unit (GATE eksplisit):** tiap `task.unit` HARUS cocok `apps[].name` ATAU `packages[].name` ATAU `integration`; kalau tidak → STOP + saran (`add-app`/`add-package`/typo).
```

`new_string`:
```
**Validasi unit (GATE eksplisit):** tiap `task.unit` HARUS cocok `apps[].name` ATAU `packages[].name` ATAU `integration`; kalau tidak → STOP + saran (`add-app`/`add-package`/typo). **Unit task `migrate` (amandemen 2026-09-14):** task ber-`actions: [migrate]` — ATAU `cmd` yang ternyata perintah apply-migrasi — HARUS `unit == schema_owner(unit)` per `${CLAUDE_PLUGIN_ROOT}/rules/db-ownership.md`; kalau tidak → **STOP** + saran: pindahkan task migrate ke `unit: <owner>`, lalu jadikan task kode di unit asal `deps` ke situ. Ini memang memaksa fitur lintas-unit saat DB dibagi — itu bentuk yang benar, dan mesinnya sudah ada (`deps` lintas-unit + pseudo-unit `integration`). `databases[]` absen ⇒ `schema_owner(unit) == unit` ⇒ aturan ini tak pernah menyala.
```

- [ ] **Step 3: Edit B — konsultasi reuse via owner**

Edit tool pada `plugin/skills/breakdown/SKILL.md`:

`old_string`:
```
**Reuse-aware (sebelum nulis `files`):** untuk task yang nyentuh data/file, konsultasi `control/schema/<app>.md` (tabel existing) + lirik ringan dir target (file existing).
```

`new_string`:
```
**Reuse-aware (sebelum nulis `files`):** untuk task yang nyentuh data/file, konsultasi `control/schema/<schema_owner(app)>.md` (tabel existing — resolusi pemilik per `${CLAUDE_PLUGIN_ROOT}/rules/db-ownership.md`, amandemen 2026-09-14; `databases[]` absen ⇒ identik `<app>.md`) + lirik ringan dir target (file existing).
```

- [ ] **Step 4: Edit C — manifest read-set**

Edit tool pada `plugin/skills/breakdown/reference.md`:

`old_string`:
```
  - control/schema/<unit>.md     #   tiap unit ber-DB yang kena (baseline skema)
```

`new_string`:
```
  - control/schema/<unit>.md     #   tiap unit ber-DB yang kena (baseline skema); nama file = schema_owner(unit) — rules/db-ownership.md
```

- [ ] **Step 5: Edit D — aturan `actions: migrate` di §D-1**

Edit tool pada `plugin/skills/breakdown/reference.md`:

`old_string`:
```
**`migrate` membawa `kind`+`affects`** (§A): `kind` = additive|destructive|backfill (action-scoped `migrate.kind`, beda dari `kind:` level-task), `affects` = [tabel, Table.kolom].
```

`new_string`:
```
**`migrate` membawa `kind`+`affects`** (§A): `kind` = additive|destructive|backfill (action-scoped `migrate.kind`, beda dari `kind:` level-task), `affects` = [tabel, Table.kolom]. **`migrate` cuma sah di unit pemilik skema (amandemen 2026-09-14):** `unit` task ini HARUS `== schema_owner(unit)` (`${CLAUDE_PLUGIN_ROOT}/rules/db-ownership.md`) — di-tegakkan sebagai STOP di gate validasi unit (SKILL.md step 1). Larangan lama tetap berlaku dan ortogonal: `unit: <package>` DILARANG `actions: [migrate]` (§D-4).
```

- [ ] **Step 6: Read-back**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -Fc -e 'Unit task `migrate` (amandemen 2026-09-14)' plugin/skills/breakdown/SKILL.md
grep -Fc -e 'control/schema/<schema_owner(app)>.md' plugin/skills/breakdown/SKILL.md
grep -Fc -e 'schema_owner(unit) — rules/db-ownership.md' plugin/skills/breakdown/reference.md
grep -Fc -e '`migrate` cuma sah di unit pemilik skema' plugin/skills/breakdown/reference.md
grep -Fc -e 'DILARANG** `actions: [migrate]`/`actions: [env]` (package tak punya DB/infra)' plugin/skills/breakdown/reference.md
```
Expected: lima-limanya `1` (yang terakhir membuktikan larangan package lama masih utuh).

- [ ] **Step 7: Commit**

```bash
cd /Users/mac-098506/Developer/project/context-vault
git add plugin/skills/breakdown/SKILL.md plugin/skills/breakdown/reference.md
git commit -F - <<'MSG'
fix(breakdown): task migrate cuma sah di unit pemilik + reuse via owner

B3: gate validasi unit dulu tak memeriksa apakah unit berhak menjalankan
DDL. B2: konsultasi reuse dibaca via schema_owner supaya app non-pemilik
tak lagi "degrade: lewati konsultasi tabel".

Claude-Session: https://claude.ai/code/session_01LGXi99joeXK7LFsPNnK7Uy
MSG
```

---

### Task 9: `build/SKILL.md` — read-set, reconcile, brief, regen via `schema_owner`

**Files:**
- Modify: `plugin/skills/build/SKILL.md` (3 edit: reconcile ≈17, brief ≈35, regen M4 ≈37)

**Interfaces:**
- Consumes: `schema_owner` dari T1.

> **Catatan anchor:** baris ≈15 (read-set) memuat `control/schema/<unit>.md` dua kali dalam satu baris sangat panjang. Jangan mengedit baris itu — cakupannya sudah benar begitu nama file di-resolve, dan resolusi itu ditegaskan di tiga titik lain yang lebih pendek dan unik. Ini keputusan sadar, bukan kelalaian.

- [ ] **Step 1: Konfirmasi ketiga anchor unik**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
F=plugin/skills/build/SKILL.md
grep -Fc -e '- **Reconcile reuse ↔ proyeksi skema (sekali, di awal):** untuk tiap task ber-`reuse: [table: <T>]`, assert `<T>` MASIH ada di `control/schema/<unit>.md` terkini;' $F
grep -Fc -e '**(bila unit app & proyeksi non-stub) blok skema & struktur existing (slice control/schema/<unit>.md + listing dir + directive reuse, `reference.md` §B)**' $F
grep -Fc -e '**Proyeksi skema (M4):** sesudah task ber-`actions: migrate:` dengan **`unit` ∈ `apps[]`** mencapai `done` (pasca-review step 4) → regen `control/schema/<unit>.md` per' $F
```
Expected: ketiga-tiganya `1`.

- [ ] **Step 2: Edit A — reconcile**

Edit tool pada `plugin/skills/build/SKILL.md`:

`old_string`:
```
- **Reconcile reuse ↔ proyeksi skema (sekali, di awal):** untuk tiap task ber-`reuse: [table: <T>]`, assert `<T>` MASIH ada di `control/schema/<unit>.md` terkini;
```

`new_string`:
```
- **Reconcile reuse ↔ proyeksi skema (sekali, di awal):** untuk tiap task ber-`reuse: [table: <T>]`, assert `<T>` MASIH ada di `control/schema/<schema_owner(unit)>.md` terkini (resolusi pemilik per `${CLAUDE_PLUGIN_ROOT}/rules/db-ownership.md`, amandemen 2026-09-14; `databases[]` absen ⇒ identik `<unit>.md`);
```

- [ ] **Step 3: Edit B — slice ke brief**

Edit tool pada `plugin/skills/build/SKILL.md`:

`old_string`:
```
**(bila unit app & proyeksi non-stub) blok skema & struktur existing (slice control/schema/<unit>.md + listing dir + directive reuse, `reference.md` §B)**
```

`new_string`:
```
**(bila unit app & proyeksi non-stub) blok skema & struktur existing (slice control/schema/<schema_owner(unit)>.md + listing dir + directive reuse, `reference.md` §B)**
```

- [ ] **Step 4: Edit C — regen M4**

Edit tool pada `plugin/skills/build/SKILL.md`:

`old_string`:
```
**Proyeksi skema (M4):** sesudah task ber-`actions: migrate:` dengan **`unit` ∈ `apps[]`** mencapai `done` (pasca-review step 4) → regen `control/schema/<unit>.md` per
```

`new_string`:
```
**Proyeksi skema (M4):** sesudah task ber-`actions: migrate:` dengan **`unit` ∈ `apps[]`** mencapai `done` (pasca-review step 4) → regen `control/schema/<schema_owner(unit)>.md` per
```

- [ ] **Step 5: Read-back**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
F=plugin/skills/build/SKILL.md
grep -Fo -e 'control/schema/<schema_owner(unit)>.md' $F | wc -l
grep -Fc -e 'db-ownership.md' $F
```
Expected: `3` dan `1`.

- [ ] **Step 6: Commit**

```bash
cd /Users/mac-098506/Developer/project/context-vault
git add plugin/skills/build/SKILL.md
git commit -F - <<'MSG'
fix(build): reconcile, slice brief, dan regen M4 via schema_owner

Tiga titik yang menyebut control/schema/<unit>.md di-resolve ke pemilik.
Karena breakdown kini memaksa task migrate mendarat di unit pemilik,
resolusi pada regen bersifat identitas — ditulis eksplisit supaya tak
bergantung pada invarian di skill lain.

Claude-Session: https://claude.ai/code/session_01LGXi99joeXK7LFsPNnK7Uy
MSG
```

---

### Task 10: `render-docs/SKILL.md` — kartu skema per database

**Files:**
- Modify: `plugin/skills/render-docs/SKILL.md` (1 edit, baris ≈28)

**Interfaces:**
- Consumes: `resolve_db`, `schema_owner` dari T1.

- [ ] **Step 1: Konfirmasi anchor unik**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -Fc -e 'Satu `.card` per app yang PUNYA table (dari `control/schema/<app>.md`): judul app + daftar table (nama + kolom ringkas + relasi) + `Asal` (fitur/fix).' plugin/skills/render-docs/SKILL.md
```
Expected: `1`.

- [ ] **Step 2: Edit**

Edit tool pada `plugin/skills/render-docs/SKILL.md`:

`old_string`:
```
Satu `.card` per app yang PUNYA table (dari `control/schema/<app>.md`): judul app + daftar table (nama + kolom ringkas + relasi) + `Asal` (fitur/fix).
```

`new_string`:
```
Satu `.card` per app yang PUNYA table (dari `control/schema/<app>.md`): judul app + daftar table (nama + kolom ringkas + relasi) + `Asal` (fitur/fix). **Bila `workspace.yaml` punya `databases[]` (amandemen 2026-09-14):** kartu dikelompokkan per **database**, bukan per app — judul `<name>` + `<engine>`, isi dari proyeksi pemilik (`control/schema/<owner>.md`), plus baris *"Dibaca oleh: `<app1>`, `<app2>`, …"* (semua app yang `resolve_db`-nya entri itu; `${CLAUDE_PLUGIN_ROOT}/rules/db-ownership.md`). `databases[]` absen ⇒ satu kartu per app seperti sebelumnya (identik, karena `schema_owner(app) == app`).
```

- [ ] **Step 3: Read-back**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -Fc -e 'Dibaca oleh:' plugin/skills/render-docs/SKILL.md
grep -Fc -e 'lewati section schema seluruhnya' plugin/skills/render-docs/SKILL.md
```
Expected: `1`, `1` (yang kedua membuktikan empty-handling lama utuh).

- [ ] **Step 4: Commit**

```bash
cd /Users/mac-098506/Developer/project/context-vault
git add plugin/skills/render-docs/SKILL.md
git commit -F - <<'MSG'
feat(render-docs): kartu Model Data dikelompokkan per database

Saat databases[] ada, satu kartu per DB + baris "Dibaca oleh". Tanpa
databases[], perilaku identik (satu kartu per app).

Claude-Session: https://claude.ai/code/session_01LGXi99joeXK7LFsPNnK7Uy
MSG
```

---

### Task 11: `init` + `upgrade` + `ask` — seed template, advisory, rute tanya

**Files:**
- Modify: `plugin/skills/init/SKILL.md` (1 edit, blok `workspace.yaml` langkah 5)
- Modify: `plugin/skills/upgrade/SKILL.md` (1 edit, dekat baris ≈51)
- Modify: `plugin/skills/ask/SKILL.md` (1 edit, tabel rute baris ≈22)

**Interfaces:**
- Consumes: bentuk `databases[]` dari T1; `architect` sebagai tujuan arahan dari T4.

- [ ] **Step 1: Konfirmasi ketiga anchor unik**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -Fc -e 'packages: []                # shared package (ui-kit/types/utils) — diisi skill add-package; consumers diisi fanout' plugin/skills/init/SKILL.md
grep -Fc -e '- **`control/schema/` absen/stub pada app ber-DB (produk lama belum punya proyeksi)** → `upgrade` **TIDAK nge-seed**' plugin/skills/upgrade/SKILL.md
grep -Fc -e '| Arsitektur: app/package, tanggung jawab, stack, capability, topology | `workspace.yaml` |' plugin/skills/ask/SKILL.md
```
Expected: ketiga-tiganya `1`.

- [ ] **Step 2: Edit A — `init` seed `databases: []`**

Edit tool pada `plugin/skills/init/SKILL.md`:

`old_string`:
```
packages: []                # shared package (ui-kit/types/utils) — diisi skill add-package; consumers diisi fanout
```

`new_string`:
```
packages: []                # shared package (ui-kit/types/utils) — diisi skill add-package; consumers diisi fanout
databases: []               # DB fisik + pemilik migrasi — diisi architect saat app KEDUA nempel ke DB yang sama; kosong = tiap app 1:1 (rules/db-ownership.md)
```

- [ ] **Step 3: Edit B — `upgrade` advisory deteksi `stack.db` kembar**

Edit tool pada `plugin/skills/upgrade/SKILL.md`:

`old_string`:
```
- **`control/schema/` absen/stub pada app ber-DB (produk lama belum punya proyeksi)** → `upgrade` **TIDAK nge-seed**
```

`new_string`:
```
- **≥2 app ber-`stack.db` yang sama tapi `databases[]` absen (amandemen 2026-09-14)** → **advisory, `upgrade` TIDAK menulis** (charter nol-sentuh-knowledge): laporkan *"app `<a>` & `<b>` kelihatan nembak DB yang sama tapi kepemilikan migrasi belum dideklarasi — jalankan `architect` buat nentuin pemiliknya"*, lalu ARAHKAN ke `architect`. Produk ini sedang duduk di atas risiko `wire` menimpa riwayat migrasi; `wire` sendiri punya palang pra-migrate sebagai jaring terakhir (`rules/db-ownership.md`).
- **`control/schema/` absen/stub pada app ber-DB (produk lama belum punya proyeksi)** → `upgrade` **TIDAK nge-seed**
```

- [ ] **Step 4: Edit C — `ask` tabel rute**

Edit tool pada `plugin/skills/ask/SKILL.md`:

`old_string`:
```
| Arsitektur: app/package, tanggung jawab, stack, capability, topology | `workspace.yaml` |
```

`new_string`:
```
| Arsitektur: app/package, tanggung jawab, stack, capability, topology, **pemilik skema DB** (`databases[]`) | `workspace.yaml` |
```

- [ ] **Step 5: Read-back**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -Fc -e 'databases: []' plugin/skills/init/SKILL.md
grep -Fc -e 'kepemilikan migrasi belum dideklarasi' plugin/skills/upgrade/SKILL.md
grep -Fc -e '**pemilik skema DB** (`databases[]`)' plugin/skills/ask/SKILL.md
```
Expected: `1`, `1`, `1`.

- [ ] **Step 6: Commit**

```bash
cd /Users/mac-098506/Developer/project/context-vault
git add plugin/skills/init/SKILL.md plugin/skills/upgrade/SKILL.md plugin/skills/ask/SKILL.md
git commit -F - <<'MSG'
feat(init,upgrade,ask): seed databases[], advisory stack.db kembar, rute tanya

init men-seed blok kosong. upgrade mendeteksi produk yang sudah N:1 tanpa
deklarasi lalu mengarahkan ke architect (tidak menulis knowledge sendiri).
ask tahu pertanyaan kepemilikan skema dijawab dari workspace.yaml.

Claude-Session: https://claude.ai/code/session_01LGXi99joeXK7LFsPNnK7Uy
MSG
```

---

### Task 12: Regen `plugin-kimi/`

**Files:**
- Modify: `plugin-kimi/**` (GENERATED — jangan edit tangan)

**Interfaces:**
- Consumes: seluruh hasil T1–T11.

- [ ] **Step 1: Pastikan T1–T11 sudah ter-commit**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
git status --porcelain
git log --oneline -11
```
Expected: `git status` bersih; log memuat 11 commit task ini (T1–T11) di atas commit spec `a554b37`.

- [ ] **Step 2: Regen**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
bash tools/build-kimi.sh
```
Expected: exit 0.

- [ ] **Step 3: Verifikasi rule baru ikut ter-generate + test sync hijau**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
test -e plugin-kimi/rules/db-ownership.md && echo "rule ikut" || echo "RULE HILANG — STOP"
bash tools/tests/build-kimi.test.sh
```
Expected: `rule ikut`; test exit 0 / semua hijau.

> Bila `RULE HILANG`: `tools/build-kimi.sh` mungkin meng-enumerasi `rules/` secara eksplisit. Periksa skripnya (`grep -n 'rules' tools/build-kimi.sh`), tambahkan `db-ownership.md` bila daftarnya hardcode, lalu ulangi Step 2. **Jangan** menyalin file itu dengan tangan ke `plugin-kimi/`.

- [ ] **Step 4: Commit**

```bash
cd /Users/mac-098506/Developer/project/context-vault
git add plugin-kimi/
git commit -F - <<'MSG'
chore(kimi): regen plugin-kimi — kepemilikan skema databases[]

Claude-Session: https://claude.ai/code/session_01LGXi99joeXK7LFsPNnK7Uy
MSG
```

---

### Task 13: Acceptance — konsistensi grep + desk-check produk nyata

**Files:**
- Tak ada yang diubah. Task ini **read-only** kecuali bila menemukan cacat (lalu perbaiki + commit terpisah).

**Interfaces:**
- Consumes: seluruh hasil T1–T12.

> **KuyMahjong dibaca, TIDAK diubah.** `~/Developer/project/mahjong/control/*` read-only sepanjang task ini (Global Constraints).

- [ ] **Step 1: Konsistensi — semua penyebut proyeksi sudah ter-resolusi**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
echo "--- penyebut db-ownership (harus >=9 file) ---"
grep -rl 'db-ownership' plugin/ | sort
echo "--- sisa <app>.md / <unit>.md yang BELUM ter-resolusi di jalur pembaca ---"
grep -rn 'control/schema/<app>.md\|control/schema/<unit>.md' plugin/skills/plan plugin/skills/breakdown plugin/skills/build
```
Expected: listing pertama memuat `rules/db-ownership.md`, `rules/schema-projection.md`, `rules/migration-impact.md`, `skills/architect/SKILL.md`, `skills/wire/SKILL.md`, `skills/plan/SKILL.md`, `skills/breakdown/SKILL.md`, `skills/breakdown/reference.md`, `skills/build/SKILL.md`, `skills/render-docs/SKILL.md`, `skills/upgrade/SKILL.md`.
Listing kedua **boleh tidak kosong** — sisa yang sah: `plan/SKILL.md` kalimat **Fallback** (sengaja bicara tentang file yang absen), `breakdown/reference.md:12` komentar manifest (sudah diberi catatan resolusi), `build/SKILL.md` baris read-set panjang (keputusan sadar T9). Yang **TIDAK** boleh tersisa: penyebut baru di jalur keputusan reuse. Periksa tiap hit; ragu → bandingkan ke spec §3.6.

- [ ] **Step 2: Invarian aditif — produk 1:1 tak berubah perilaku**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -rn 'databases\[\] absen' plugin/ | wc -l
grep -rn 'identik\|byte-identik\|persis seperti sebelum' plugin/rules/db-ownership.md plugin/skills/plan/SKILL.md plugin/skills/breakdown/SKILL.md plugin/skills/render-docs/SKILL.md | wc -l
```
Expected: hitungan pertama ≥ 5 (tiap skill pembaca menegaskan default legacy); kedua ≥ 4. Kalau ada skill pembaca yang **tidak** menyebut default legacy, tambahkan kalimatnya — invarian spec §4.3 harus terbaca di tempat ia berlaku, bukan hanya di rule.

- [ ] **Step 3: Desk-check skenario B1 — palang menyala tanpa deklarasi**

Baca `~/Developer/project/mahjong/control/workspace.yaml` (read-only). Simulasikan di kepala: `venue` ditambahkan dengan `stack.db` free-text yang sama, `databases[]` absen.

Telusuri `plugin/skills/wire/SKILL.md` langkah 3 dan jawab tertulis:
- Apakah palang menyala sebelum generate/apply? (harus: ya — `resolve_db` NULL + ada app lain menembak DB sama)
- Apakah pesannya menyebut `architect`? (harus: ya)
- Bila deteksi "target sama" ragu, apa yang terjadi? (harus: tetap STOP)

Expected: ketiganya sesuai. Tidak sesuai → perbaiki `wire/SKILL.md`, commit terpisah.

- [ ] **Step 4: Desk-check skenario B1-lanjutan — non-pemilik ter-deklarasi tetap bisa hijau** (spec §9.2)

Sekarang dengan `databases[]` TERDEKLARASI (`name: main`, `owner: kuymahjong`, `venue.stack.db: main`). Telusuri `plugin/skills/wire/SKILL.md` langkah 2, 3, dan `wire/reference.md` syarat gate; jawab tertulis:
- Apakah langkah 2 mem-provision DB baru untuk `venue`? (harus: TIDAK — menyambung ke DB existing)
- Apakah langkah 3 generate/apply migrasi baseline untuk `venue`? (harus: TIDAK)
- Apakah init driver/ORM + smoke query TETAP dijalankan? (harus: ya — koneksi wajib dibuktikan)
- Apakah gate "DB reachable" **bisa hijau** tanpa klausa baseline? (harus: ya — `wire/reference.md` mencoret klausa itu untuk non-pemilik)
- Apakah `schema-projection` dipanggil untuk `venue`? (harus: TIDAK — no-op per rule-nya; dan TIDAK ada warning "app uncovered")

Expected: kelima-limanya sesuai. Ini skenario yang membuktikan palang Step 3 **bukan jalan buntu** — ada jalur sah menuju hijau.

- [ ] **Step 5: Desk-check skenario B2 — reuse hidup untuk app non-pemilik**

Dengan `databases[]` terdeklarasi (`owner: kuymahjong`, `venue.stack.db: main`), telusuri `plugin/skills/plan/SKILL.md` baris **Baca proyeksi** dan jawab:
- File apa yang dibaca `plan` saat menggarap fitur di `venue`? (harus: `control/schema/kuymahjong.md`)
- Apakah `venues`/`sessions` terlihat sebagai tabel existing? (harus: ya — file itu memuatnya; verifikasi dengan `grep -c '^## ' ~/Developer/project/mahjong/control/schema/kuymahjong.md`, harus > 5)
- Verdict `Model/Schema` untuk kebutuhan "booking meja": `reuse` atau `NEW`? (harus: `reuse venues`/`reuse sessions`, bukan `NEW`)

Expected: ketiganya sesuai.

- [ ] **Step 6: Desk-check skenario B3 — task migrate salah unit ditolak**

Telusuri `plugin/skills/breakdown/SKILL.md` gate validasi unit. Simulasikan `tasks.yaml` dengan task ber-`actions: [migrate]` pada `unit: venue` (sementara `owner: kuymahjong`).
- Apakah gate STOP? (harus: ya)
- Apakah sarannya menyebut pemindahan ke `unit: kuymahjong` + `deps`? (harus: ya)
- Apakah larangan lama `unit: <package>` masih berlaku terpisah? (harus: ya, §D-4)

Expected: ketiganya sesuai.

- [ ] **Step 7: Desk-check skenario B4 — allowlist hanya pemilik**

Telusuri `plugin/skills/wire/SKILL.md` 5.5.
- Apakah `venue` (non-pemilik) ditawari opt-in apply-migrate? (harus: TIDAK)
- Apakah `venue` menerima deny cermin perintah apply? (harus: ya)
- Apakah `kuymahjong` (pemilik) tetap ditawari seperti sebelumnya? (harus: ya)

Expected: ketiganya sesuai.

- [ ] **Step 8: Desk-check promosi 1:1 → N:1 ter-GATE** (spec §9.7)

Telusuri `plugin/skills/add-app/SKILL.md` langkah 4 (chain ke `architect`) lalu `plugin/skills/architect/SKILL.md` 3a. Simulasikan `add-app venue` pada KuyMahjong apa adanya (`databases[]` absen, `kuymahjong` satu-satunya app ber-DB):
- Apakah pertanyaan kepemilikan muncul? (harus: ya — syaratnya "sudah punya ≥1 app ber-DB lain" terpenuhi)
- Bila user pilih **nempel**, berapa kali user diminta approve? (harus: SATU — promosi itu satu transaksi ter-GATE)
- Apakah diff yang disodorkan memuat KEEMPATNYA: entri `databases[]` baru, `stack.db` `kuymahjong` jadi `main`, `stack.db` `venue` = `main`, dan `owner: kuymahjong`? (harus: ya — tanpa penulisan ulang `stack.db` pemilik, deklarasi tak berlaku)
- Apakah `migrations` terisi dari ekstraksi free-text lama? (harus: ya — `kuymahjong/supabase/migrations`)

Expected: keempat-empatnya sesuai. Poin ketiga paling rawan terlewat — verifikasi eksplisit di prosa `architect`.

- [ ] **Step 9: Laporkan hasil**

Tulis ringkasan: tiap skenario Step 3–8 **LULUS/GAGAL** + kutipan baris yang membuktikannya. Ada GAGAL → perbaiki file terkait, commit terpisah dengan pesan `fix(review): <apa>`, lalu ulangi step yang gagal. **Jangan** menandai plan selesai selagi ada GAGAL.

- [ ] **Step 10: Commit (hanya bila ada perbaikan)**

```bash
cd /Users/mac-098506/Developer/project/context-vault
git status --porcelain
# bila kosong: tak ada commit — acceptance lulus tanpa perbaikan.
# bila ada perubahan: git add <file> && git commit dengan footer Claude-Session (lihat Global Constraints)
```

---

## Catatan untuk executor

- **Kalau anchor tak ketemu (`grep -Fc` = 0):** STOP dan lapor. Jangan tebak pengganti, jangan `sed` berbasis nomor baris. Kemungkinan besar file drift sejak plan ditulis (2026-09-14) — plan perlu di-refresh, bukan diakali.
- **Kalau sebuah edit terasa membuat produk 1:1 berubah perilaku:** itu tanda edit-nya salah. Default legacy adalah invarian (Global Constraints), bukan fitur opsional.
- **Jangan menambah skill.** Yang ditambah `rules/db-ownership.md` = *rule*, bukan skill; README / `plugin.json` / `marketplace.json` tak berubah.
