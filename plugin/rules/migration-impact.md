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
