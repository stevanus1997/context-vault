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
