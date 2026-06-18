# <PRODUCT> — Konvensi & Kontrak Teknis Lintas-App

<!-- Diisi oleh skill architect. Contoh: mekanisme auth token web<->api,
     format API, shared package, ORM standar. -->

## Konvensi Package
<!-- Diisi architect saat add-package: path import, build/test tool, sinyal breaking/deprecation. -->

## Konvensi Integrasi
<!-- Diisi saat add-integration/wire: SHAPE env vendor (NAMA var, tanpa nilai), konvensi webhook-receiver. -->

## Konvensi Migrasi & Zero-Downtime
<!-- Pola expand-contract default buat perubahan ngerusak pada tabel dengan pembaca hidup:
     (1) expand — tambah bentuk baru (kolom/tabel) tanpa hapus lama;
     (2) backfill + tulis-ganda; (3) alihkan pembaca ke bentuk baru; (4) contract — hapus lama.
     Dipecah lintas beberapa rilis. Spesialisasi per-produk di sini; gate build/plan
     (rules/migration-impact.md) bawa default generik bila section ini kosong. -->

## Konvensi Query & Data-Access
<!-- Diisi architect: pola akses data app — reuse repository/query-layer existing vs raw SQL;
     index/unique di kolom lookup; ekspektasi no-N+1 / batch-load; default pagination.
     Di-paste build ke tiap prompt implementer (build/reference.md §B). Kosong = degrade no-op
     (default generik: ikuti pola data-access file existing terdekat / "pointer pola"). -->
