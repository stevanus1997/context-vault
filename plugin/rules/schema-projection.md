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
1. **Lokalisasi sumber.** Dari `app.stack.orm` + `conventions.md`, tentukan di mana skema/migrasi app tinggal (mis. `schema.prisma`, schema Drizzle `*.ts`, Django `models.py`, folder migrasi raw-SQL). **Sumber tak ketemu SAMA SEKALI** (`stack.orm` kosong **DAN** tak ada folder migrasi/skema raw-SQL) → tulis stub `# <app> — Schema (belum ada tabel)` lalu **STOP** (degrade no-op). **`stack.orm` kosong TAPI ada folder migrasi raw-SQL → JANGAN STOP**: lanjut step 2 (ekstrak by-understanding dari folder migrasi) — app raw-SQL tetap dapat proyeksi (sejajar AND-guard `wire/SKILL.md` §0; lokalisasi folder migrasi = kerjaan step 1 INI sendiri, dari `conventions.md` + struktur repo — bukan prosedur `migration-impact.md`). Sumber-tunggal: orm = sumber utama bila ada; folder migrasi = sumber bila orm kosong.
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
