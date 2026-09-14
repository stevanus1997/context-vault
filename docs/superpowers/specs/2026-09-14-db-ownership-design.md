# Desain — Kepemilikan skema (`databases[]`): N app berbagi 1 database

**Tanggal:** 2026-09-14
**Status:** Disetujui (siap masuk `writing-plans`)
**Scope:** rule baru `db-ownership.md` · `architect` (penulis tunggal `databases[]`) · `wire` (palang pra-migrate + langkah 2/3 + 5.5) · `schema-projection` · `plan`/`breakdown`/`build` (resolusi pembaca proyeksi) · `breakdown` (validasi unit migrate) · `render-docs` · `migration-impact` (catatan) · `init` (template) · `upgrade` (advisory)
**Menyusul:** `migration-impact.md` step 1 yang sudah menyebut kasus *"lintas-app berbagi DB"* tanpa pernah punya unit yang memilikinya

---

## 1. Masalah

Seluruh sistem mengasumsikan **app ⟷ database itu 1:1**. Asumsi ini tak pernah ditulis sebagai keputusan — ia menetes dari penamaan artefak (`control/schema/<app>.md`) dan dari `stack.db` yang hidup di dalam entri app. Begitu dua app menempel ke satu database, empat hal pecah, dan tiga di antaranya pecah **diam-diam**.

Pemicu nyata (produk KuyMahjong, 2026-09-14): satu app `kuymahjong` (`type: fullstack`, Supabase, 38 migrasi raw-SQL di `supabase/migrations`) hendak ditemani app `venue` dan `admin` yang menembak **project Supabase yang sama**.

### B1 — `wire` menimpa riwayat migrasi DB yang sudah dipegang app lain

`wire/SKILL.md:38` langkah 3: *"Init ORM/driver (`stack.orm`), generate migrasi **baseline** (kosong dari table fitur), **apply** (GATE)"*, dan `wire/reference.md:45` menjadikannya syarat gate keras: *"**DB reachable** — ORM connect, migrasi baseline ter-apply, smoke query ijo."* Tidak ada satu pun guard yang menanyakan apakah database itu sudah dimiliki unit lain.

Untuk Supabase kerusakannya konkret: riwayat migrasi disimpan **di remote**, di tabel `supabase_migrations.schema_migrations`, dan dibandingkan terhadap **satu** folder `supabase/migrations/` lokal. Dua folder lokal berbeda yang menembak satu project ref → mismatch **permanen**, bukan sesekali: tiap `db push` dari app B melihat migrasi app A sebagai "ada di remote, tak ada di lokal". Docs Supabase menyediakan `supabase migration repair --status applied <TIMESTAMP>` justru untuk kelas kerusakan ini. Kelasnya generik (Alembic `alembic_version`, Prisma `_prisma_migrations`, goose `goose_db_version` — semua tabel riwayat tunggal per-DB); Supabase hanya kasus yang memicu spec ini.

### B2 — Proyeksi stub pada app non-pemilik mematikan deteksi reuse (paling mahal)

`schema-projection.md` menulis `control/schema/<app>.md` dari sumber skema **app itu sendiri**. App non-pemilik tak punya folder migrasi → dapat stub (`wire/SKILL.md:24`: *"`stack.orm` kosong **dan** tak ada folder migrasi → tulis stub + **warning**"*). Tiga pembaca lalu menyimpulkan "nol tabel":

- `plan/SKILL.md:39` — baseline model data untuk verdict **reuse-vs-NEW**. Stub → condong memutuskan `NEW <Tabel>` untuk tabel yang **sudah ada**. Ada fallback (*"absen/stub padahal app jelas ber-DB → JANGAN anggap kosong = otoritatif; lakukan inventory ORM/migrasi nyata"*), tapi fallback itu memaksa inventory manual tiap sesi, bukan memakai proyeksi yang sebenarnya sudah ada di sebelahnya.
- `breakdown/SKILL.md:23` — *"Degrade: `control/schema/<app>.md` absen/stub → lewati konsultasi tabel"*. Konsultasi reuse mati → `reuse:` tak terisi.
- `build/SKILL.md:17` — reconcile `reuse:` ↔ proyeksi. Tak ada `reuse:` untuk direkonsiliasi → cek lewat.

Hasil akhirnya: **build membuat tabel duplikat** — persis failure mode yang seluruh rantai `reuse:` dibangun untuk mencegah, ter-bypass tanpa satu warning pun di jalur yang menentukan.

### B3 — Tak ada aturan yang memaksa task `migrate` mendarat di unit pemilik

`breakdown/SKILL.md:15` memvalidasi `task.unit` ∈ `apps[]` ∪ `packages[]` ∪ `integration`. Tidak ada yang memeriksa apakah unit itu berhak menjalankan DDL. Fitur di app `venue` yang butuh tabel baru bisa menerbitkan `actions: [migrate]` pada `unit: venue` — yang lalu menulis file migrasi ke folder yang salah dan meng-apply-nya dari riwayat yang salah (B1 lewat pintu belakang, di luar `wire`).

### B4 — Opt-in allowlist apply-migrate diturunkan per-unit

`wire/SKILL.md:51`: *"untuk unit ber-DB, tanyakan … turunkan perintah apply by-understanding dari `stack.orm`"* → `Bash(supabase db push:*)` masuk `permissions.allow`. Pertanyaan itu diajukan **per unit ber-DB**, jadi ketiga app menerima izin push ke database yang hanya boleh disentuh satu di antaranya. `build --unattended` kemudian bisa apply dari unit mana pun.

### Yang TIDAK pecah (diperiksa, dikoreksi dari analisis awal)

`migration-impact.md` **aman**. Step 1 membaca `control/schema/` **semua app** (proyeksi si pemilik memuat FK graph lengkap, karena folder migrasi mendefinisikan seluruh DB), dan step 2 men-scan kode **tiap app** untuk referensi nama tabel. Dua-duanya sudah iterate lintas app. Gate dampak H3 tidak buta; hanya catatan step 1 yang perlu menyebut pengelompokan per-DB secara eksplisit.

---

## 2. Wawasan kunci — yang hilang adalah RELASI, bukan bentuk unit

Godaan pertama adalah menambah `type: db` (unit repo/folder khusus migrasi) di samping `fe`/`be`/`fullstack`. Itu salah tempat.

`type` menjawab **"unit ini bentuknya apa"** — punya server? punya UI? punya route? Ia dipakai `wire` untuk memilih mode bring-up. Sedangkan "siapa yang berhak meng-apply DDL ke database X" adalah **relasi antara unit dan database**, dan sebuah relasi tak bisa dikodekan di field yang menggambarkan satu sisinya. Bukti bahwa ini relasi: nilainya berubah ketika database-nya berubah, bukan ketika unit-nya berubah.

Dua konsekuensi yang menyelamatkan banyak pekerjaan:

1. **`type: db` tidak diperlukan di cabang mana pun.** Repo-skema-terpisah (satu-satunya bentuk yang benar-benar butuh unit tanpa server) tetap bisa diwujudkan nanti sebagai app biasa yang kebetulan jadi `owner` — tanpa mode `wire` baru, tanpa aturan `breakdown` baru. Ditunda, tidak ditolak (§6).
2. **Relasi itu bisa punya default yang persis sama dengan perilaku hari ini.** Bila tak dideklarasikan, tiap app adalah pemilik dirinya sendiri — yaitu 1:1, yaitu status quo. Maka perubahan ini **aditif murni**: nol migrasi untuk produk yang sudah di-`init`, nol mode-legacy yang harus dipelihara bercabang di tiap skill.

Wawasan kedua menentukan penamaan artefak. Proyeksi skema dikunci ke **nama unit pemilik**, bukan nama database. Di kasus 1:1 pemilik adalah app itu sendiri → path-nya `control/schema/<app>.md`, **tak berubah sedikit pun**. Di kasus N:1 ketiga app me-resolve ke file yang sama. Tidak ada file yang perlu di-rename, tidak ada versi minimum, tidak ada perintah upgrade wajib.

---

## 3. Keputusan desain

### 3.1 Artefak: blok `databases[]` di `workspace.yaml`

```yaml
product: KuyMahjong
topology: monorepo
databases:                                     # OPSIONAL — absen = semua app 1:1 (status quo)
  - name: main                                 # identitas; dirujuk stack.db
    engine: Supabase Postgres                  # dulu nilai free-text stack.db
    migrations: kuymahjong/supabase/migrations # path relatif ROOT PRODUK
    owner: kuymahjong                          # unit ∈ apps[].name — pemegang DDL
apps:
  - name: kuymahjong
    stack: { db: main, orm: "@supabase/supabase-js", ... }
  - name: venue
    stack: { db: main, ... }                   # menempel, BUKAN pemilik
  - name: admin
    stack: { db: main, ... }
```

**`migrations` dan `owner` sengaja dipisah.** `migrations` = di mana folder itu **tinggal** (boleh di luar app mana pun — mis. monorepo dengan `supabase/` di root produk). `owner` = unit mana yang **task migrate-nya** mendarat dan yang proyeksinya jadi kanonik. Memisahkan keduanya membuat layout monorepo root-level bekerja tanpa konsep tambahan.

**Penulis tunggal `databases[]` = `architect`.** Ia sudah pemilik `stack`; kepemilikan DB adalah keputusan stack. `init` hanya men-seed `databases: []` di template. `add-app`/`add-package` tidak pernah menulisnya langsung (mereka chain ke `architect`). `wire`/`build`/`plan`/`breakdown`/`render-docs` read-only.

### 3.2 Rule baru `rules/db-ownership.md` — resolusi

Tujuh call-site membutuhkan resolusi yang sama, jadi ia jadi rule share (sebangun `schema-projection.md` / `migration-impact.md`: prosedur read-only yang di-*invoke*, bukan langkah berdiri sendiri).

```
resolve_db(app)            = databases[] entri yang name-nya == app.stack.db
                             → NULL bila databases[] absen ATAU tak ada yang cocok

schema_owner(unit)         = resolve_db(unit).owner   bila resolve_db(unit) ada
                           = unit                     selainnya          ← default legacy

engine(app)                = resolve_db(app).engine   bila ada
                           = app.stack.db (free-text) selainnya          ← default legacy

is_schema_owner(unit)      = schema_owner(unit) == unit
```

**Pencocokan sengaja toleran.** `stack.db` boleh berupa referensi (`main`) **atau** free-text engine lama (`"Supabase Postgres (migrations di supabase/migrations, 38 file)"`). Cocok dengan `databases[].name` → mode baru; tidak cocok → legacy, app jadi pemilik dirinya sendiri dan string diperlakukan sebagai nama engine seperti hari ini. Tak ada produk yang bisa pecah karena belum menulis ulang `stack.db`.

Konsekuensinya: agar deklarasi `databases[]` **berlaku**, `architect` harus sekalian menulis ulang `stack.db` tiap app terkait menjadi referensi. Itu bagian dari langkah deklarasi, di-GATE (§3.3).

**Validasi (dijalankan `architect` saat menulis, `breakdown` saat gate):**
- `owner` HARUS ∈ `apps[].name` (bukan `packages[]` — package tak punya DB; bukan `integration`).
- `owner` sendiri HARUS `stack.db == <name>` (pemilik wajib menempel ke DB yang ia miliki).
- `name` unik lintas `databases[]`.
- App yang `stack.db`-nya merujuk `name` tak dikenal → bukan error, itu jalur legacy (lihat toleransi di atas). Tapi bila `databases[]` **ada** dan ada app lain yang menembak DB yang sama, `wire` menangkapnya di §3.4.

### 3.3 `architect` — momen kelahiran `databases[]`

Pertanyaan baru di Q&A teknikal, **hanya muncul bila produk sudah punya ≥1 app ber-DB**:

> *"DB buat app ini — bikin baru, atau nempel ke `main` (Supabase Postgres, dipegang `kuymahjong`)?"*

- **Bikin baru** → entri `databases[]` baru, `owner` = app ini. (Atau, bila `databases[]` masih absen dan ini app ber-DB pertama, biarkan absen — 1:1 legacy sudah benar. Jangan menulis blok yang tak mengubah perilaku.)
- **Nempel** → app ini `stack.db: <name>`, `owner` **tidak** berubah.

**Promosi 1:1 → N:1 (jalur yang dilewati KuyMahjong).** Saat app kedua memilih "nempel" sementara `databases[]` masih absen, `architect` melahirkan bloknya dalam satu transaksi ter-GATE:

1. Baca free-text `stack.db` app pemilik; ekstrak engine + path folder migrasi (by-understanding — `conventions.md` + struktur repo, seperti `schema-projection.md` step 1).
2. Tulis `databases[]` entri: `name` (usulkan `main`, konfirmasi), `engine`, `migrations`, `owner` = app pemilik.
3. Tulis ulang `stack.db` app pemilik → referensi; tulis `stack.db` app baru → referensi yang sama.
4. Tampilkan diff `workspace.yaml` → **approve**.

Informasi yang tadinya terkunci di free-text (`"migrations di supabase/migrations, 38 file"`) naik jadi field `migrations` yang terbaca mesin — efek samping yang diinginkan, bukan kebetulan.

`architect` juga memeriksa divergensi konvensi seperti biasa; bila dua app berbagi DB tapi `orm`-nya beda, itu layak disodorkan di gate (bukan palang — sah, mis. satu app pakai client SDK, satu pakai driver mentah).

### 3.4 `wire` — palang pra-migrate, langkah 2/3, dan 5.5

**Palang pra-migrate (baru, jaring terakhir).** Sebelum apply migrasi baseline di langkah 3, `wire` memeriksa: adakah app **lain** di `workspace.yaml` yang menembak target DB yang sama? Bila ya **DAN** `resolve_db(app)` == NULL (yaitu kepemilikan belum dideklarasi — `databases[]` absen, atau `stack.db` app ini tak cocok entri mana pun) → **STOP, jangan apply**:

> *"app `venue` nembak DB yang sama dengan `kuymahjong`, tapi kepemilikan migrasi belum dideklarasi. Jalanin `architect` dulu buat nentuin pemiliknya — kalau diterusin, migrasi baseline ini bakal nabrak riwayat migrasi yang udah ada."*

Palang ini ada karena §3.3 hanya menolong produk yang **melewati** `architect`, dan `upgrade` hanya menolong produk yang menjalankannya. Produk yang sudah N:1 tanpa deklarasi tidak dijangkau keduanya; palang ini menangkapnya **tepat sebelum** kerusakan, bukan di dokumentasi. Deteksi "target sama" bersifat best-effort (bandingkan `stack.db` ter-resolve; bila keduanya free-text, bandingkan string + path folder migrasi yang terlokalisasi) — ragu → tetap STOP dan minta manusia memutuskan (fail-safe, sejajar disiplin `migrate` jangan-auto).

**Langkah 2 (nyalain DB).** `is_schema_owner(app)` false → **jangan provision** database baru; sambungkan ke DB existing (connection string dari `databases[].engine` + env, GATE seperti biasa).

**Langkah 3 (konek BE↔DB).** Non-pemilik → **SKIP generate + apply migrasi baseline**. Init driver/ORM dan smoke query **tetap jalan** — "DB reachable" tetap harus dibuktikan, yang hilang hanya DDL-nya. Syarat gate `wire/reference.md:45` dibaca ulang untuk non-pemilik: *ORM connect + smoke query ijo* (tanpa klausa "migrasi baseline ter-apply"). Proyeksi skema: non-pemilik **tidak** memanggil `schema-projection` (§3.5).

**Langkah 5.5 (opt-in allowlist apply-migrate).** Pertanyaan opt-in hanya diajukan untuk unit yang `is_schema_owner` — non-pemilik tak pernah ditawari. Lebih jauh, non-pemilik menerima **deny cermin** perintah apply tool itu (ke `permissions.deny`, dalam bentuk **ber-path** unit itu — mis. `Bash(supabase db push --workdir venue:*)`. *Koreksi review pasca-eksekusi 2026-09-14: contoh awal `Bash(supabase db push:*)` polos salah — `permissions` satu file per produk dan deny menang atas allow, jadi deny polos ikut mematikan allow pemilik; allow pemilik di DB bersama pun wajib ber-path, dan tool yang tak bisa dibedakan per path tak mendapat deny cermin — pagarnya tinggal gate `breakdown`.*), sehingga `build --unattended` dari unit itu tak bisa apply meski task-nya salah dirakit. Ini melengkapi B3: `breakdown` menolak di gate, allowlist menolak di runtime.

### 3.5 `schema-projection` — resolve ke pemilik, no-op untuk sisanya

Input `app` diperluas: pemanggil boleh menyerahkan unit apa pun; rule me-resolve `schema_owner(app)` lebih dulu.

- `is_schema_owner(app)` **true** → prosedur berjalan seperti sekarang, menulis `control/schema/<app>.md`. Tak ada perubahan format, provenance, maupun idempotensi.
- **false** → **no-op diam**, bukan stub. Alasannya: stub adalah pernyataan "app ini nol tabel", dan untuk app non-pemilik pernyataan itu **salah** — ia justru B2. Ketiadaan file pada non-pemilik bukan lubang; pembaca me-resolve ke file pemilik (§3.6).

Konsekuensi ke `wire/SKILL.md:24` (seed brownfield presence-based): syarat *"`stack.orm` kosong **dan** tak ada folder migrasi → tulis stub + warning (app uncovered)"* hanya berlaku untuk **pemilik**. Non-pemilik bukan "uncovered" — ia tercakup oleh proyeksi pemiliknya, jadi tak ada warning.

Penulis tunggal tetap dihormati: hanya rule ini yang menulis `control/schema/`.

### 3.6 Pembaca proyeksi — satu baris, empat tempat

`control/schema/<unit>.md` → `control/schema/<schema_owner(unit)>.md` di:

| file | konteks |
|---|---|
| `plan/SKILL.md:39` | baseline reuse-vs-NEW |
| `breakdown/SKILL.md:15,23` | read-set + konsultasi reuse |
| `breakdown/reference.md:12,87` | manifest `generated_from` |
| `build/SKILL.md:15,17,35` | read-set, reconcile `reuse:`, slice ke brief |

Jalur degrade yang ada (*"absen/stub → degrade"*) dipertahankan apa adanya — ia kini hanya menyala saat proyeksi **pemilik** benar-benar absen/stub, yaitu kasus jujur "DB ini memang belum punya tabel".

`build` regen pasca-`migrate` (`build/SKILL.md:37`) ikut me-resolve; karena §3.7 memaksa `unit == owner`, resolusinya identitas — tapi ditulis eksplisit agar tak bergantung pada invarian di skill lain.

### 3.7 `breakdown` — `actions: migrate` hanya sah di unit pemilik

Ditambahkan ke "Validasi unit (GATE eksplisit)" yang sudah ada di `breakdown/SKILL.md:15`:

> Task ber-`actions: [migrate]` (atau `cmd` yang ternyata perintah apply-migrasi) HARUS `unit == schema_owner(unit)`. Bila tidak → **STOP** + saran: pindahkan task migrate ke `unit: <owner>`, dan jadikan task kode di unit asal `deps` ke situ.

Ini memaksa bentuk yang memang benar untuk shared-DB: fitur yang butuh tabel baru **memang** melintasi dua unit. Mesinnya sudah ada — `deps` lintas-unit + pseudo-unit `integration` untuk roundtrip. Tak ada primitif baru.

Larangan lama tetap: `unit: <package>` DILARANG `actions: [migrate]` (`breakdown/reference.md:199`). Aturan baru ini ortogonal dan lebih ketat untuk app.

### 3.8 `render-docs` — kartu per database

`render-docs/SKILL.md:28` (`SLOT:schema`): satu `.card` per **database** alih-alih per app — judul = nama DB + engine, isi = tabel dari proyeksi pemilik, plus baris *"Dibaca oleh: kuymahjong, venue, admin"*. `databases[]` absen → perilaku sekarang (satu kartu per app), karena `schema_owner(app) == app` membuat keduanya identik. Empty-handling & aturan skip section tidak berubah.

### 3.9 `migration-impact` — catatan saja

Step 1 sudah benar (§1, "Yang TIDAK pecah"). Yang ditambahkan hanya kejelasan: saat `databases[]` ada, kandidat consumer dikelompokkan per-DB, dan app yang berbagi DB dengan tabel `affects` disebut eksplisit di laporan (mereka sudah tertangkap step 2; ini membuat laporannya terbaca, bukan mengubah cakupannya). Batas "FK = relasi intra-DB" di baris 19 kini punya konsep yang menopangnya.

### 3.10 `init` & `upgrade`

`init` — tambahkan `databases: []` ke template `workspace.yaml` dengan komentar penjelas. Tidak menanyakan apa pun saat bootstrap (app pertama selalu 1:1; pertanyaannya baru relevan di app kedua, yaitu `architect` §3.3).

`upgrade` — **advisory, tidak menulis knowledge** (charter nol-sentuh-knowledge, pola `upgrade/SKILL.md:51`): deteksi ≥2 app dengan `stack.db` yang sama sementara `databases[]` absen → laporkan + arahkan ke `architect`. Tidak ada sinkronisasi file, tidak ada penulisan `workspace.yaml`.

---

## 4. Invarian yang DIJAGA

1. **Penulis tunggal.** `databases[]` hanya ditulis `architect`. `control/schema/` tetap hanya ditulis `schema-projection.md`.
2. **`migrate` jangan auto.** Palang §3.4 hanya menambah kondisi STOP; tak ada jalur baru yang meng-apply DDL tanpa gate.
3. **Aditif murni.** `databases[]` absen ⇒ setiap fungsi §3.2 jatuh ke identitas ⇒ perilaku byte-identik dengan hari ini. Tak ada produk lama yang wajib melakukan apa pun.
4. **Generik lintas-stack.** Tak ada cabang hardcode per-engine. Supabase hanya contoh; Alembic/Prisma/goose/Drizzle punya tabel riwayat tunggal per-DB yang sama sifatnya.
5. **Tanpa DB hidup.** Semua resolusi & deteksi dari `workspace.yaml` + file sumber. Tak ada introspeksi koneksi.
6. **Degrade, jangan crash.** Deklarasi tak konsisten → gate manusia; ragu di palang `wire` → STOP fail-safe, bukan lanjut diam-diam.

---

## 5. Alternatif yang DITOLAK

**`type: db` sebagai unit type keempat.** Salah kategori: `type` menggambarkan bentuk unit, kepemilikan DDL adalah relasi (§2). Ongkosnya nyata — mode `wire` baru (scaffold tanpa server, gate tanpa smoke runtime), kasus `schema-projection` baru, aturan `breakdown` baru — untuk bentuk yang tak satu pun cabang kebutuhan benar-benar memerlukannya. Repo-skema-terpisah tetap bisa diwujudkan sebagai app biasa ber-`owner` (§6).

**Proyeksi dinamai per database (`control/schema/main.md`).** Lebih jujur — file itu memang proyeksi sebuah DB, bukan sebuah app — tapi memaksa rename artefak di tiap produk lama plus dua mode pembacaan selama transisi. Ditolak: kejujuran nama tak sebanding dengan hilangnya sifat "aditif murni" (§4.3). Harga yang diterima: di kasus N:1 nama file sedikit menipu (`control/schema/kuymahjong.md` memuat skema yang dipakai bertiga); dimitigasi header proyeksi + kartu `render-docs` yang menyebut pembacanya (§3.8).

**Stub bertanda pointer pada app non-pemilik** (`control/schema/venue.md` berisi *"→ lihat kuymahjong.md"*). Menambah format file kedua dan indireksi yang harus dipahami tiap pembaca, demi menghindari satu pemanggilan fungsi resolusi. Ditolak; no-op (§3.5) lebih sederhana.

**`stack.db` tetap free-text + field terpisah `stack.db_ref`.** Menghindari penulisan ulang `stack.db`, tapi meninggalkan dua field yang menjawab pertanyaan yang sama — sumber ambiguitas permanen. Ditolak; toleransi pencocokan (§3.2) sudah membuat penulisan ulang aman dan opsional-sampai-dibutuhkan.

**Satu app menempel ke >1 database** (`stack.db` jadi list). YAGNI — tak ada kebutuhan nyata; menaikkan tiap fungsi resolusi dari skalar ke himpunan dan membuat "proyeksi app" ambigu. Di luar scope (§6).

---

## 6. Di luar scope

- **`type: db` / repo-skema berdiri sendiri.** Ditunda, tidak ditutup. Bila kelak dibutuhkan, bentuknya: app biasa yang `is_schema_owner`, `type`-nya menyusul saat `wire` benar-benar butuh mode tanpa-server. Spec ini tidak menghalangi.
- **App multi-DB** (§5).
- **Migrasi topologi** (multi-repo ⇄ monorepo) — tetap di luar jatah `init`/`upgrade` seperti sekarang (`init/SKILL.md:31`).
- **Penegakan RLS / kebijakan akses per-audiens.** Itu isi migrasi, jatah `invariants.md` + `build`, bukan kepemilikan skema.
- **Deteksi otomatis "dua app menembak project ref yang sama" lewat kredensial/introspeksi.** Palang §3.4 sengaja berbasis deklarasi + best-effort string; tanpa DB hidup (invarian §4.5).

---

## 7. Edge case & degrade

| kasus | perilaku |
|---|---|
| App `type: fe` tanpa `stack.db` | Tak ada resolusi, tak ada proyeksi. Tak berubah. |
| Unit package / pseudo-unit `integration` | Tak pernah punya DB. `schema_owner` tak dipanggil. Larangan `migrate` lama tetap. |
| `databases[]` ada, `owner` menunjuk app tak dikenal | `architect` menolak saat menulis; `breakdown` STOP di gate validasi unit. |
| `owner` tidak menempel ke DB-nya sendiri (`stack.db != name`) | Sama — tolak di penulisan, STOP di gate. |
| Folder migrasi di root produk (monorepo), di luar app mana pun | Didukung: `migrations` path relatif root, `owner` tetap sebuah unit (§3.1). |
| App pemilik di-`drop`/rename | `databases[].owner` menggantung → `breakdown` STOP + arahkan `architect`. Tak ada auto-repair (knowledge = keputusan manusia). |
| Free-text `stack.db` lama kebetulan sama persis dengan sebuah `databases[].name` | Ter-resolve sebagai referensi. Risiko diterima: `name` adalah slug pendek (`main`), free-text lama adalah kalimat. |
| `databases[]` ada tapi produk sebenarnya 1:1 | Sah — perilaku identik dengan legacy. `architect` disarankan tidak menulis blok yang tak mengubah apa pun (§3.3). |
| Proyeksi pemilik absen/stub padahal DB jelas berisi | Jalur degrade lama menyala (`plan` fallback inventory, `breakdown` lewati konsultasi) — kini dengan sebab yang jujur. |
| `wire` ragu apakah dua app menembak DB yang sama | STOP fail-safe + minta manusia memutuskan (§3.4). |

---

## 8. Daftar file yang berubah (anchor dikonfirmasi saat planning)

**Baru**
- `plugin/rules/db-ownership.md` — bentuk `databases[]`, fungsi resolusi, validasi, default legacy.

**Diubah**
- `plugin/skills/architect/SKILL.md` — Q&A kepemilikan DB; penulis tunggal `databases[]`; promosi 1:1→N:1 ter-GATE.
- `plugin/skills/wire/SKILL.md` — palang pra-migrate; langkah 2 (non-pemilik: sambung, jangan provision); langkah 3 (non-pemilik: skip baseline, smoke tetap); §0 seed brownfield (stub+warning hanya untuk pemilik); 5.5 (opt-in hanya pemilik + deny cermin untuk non-pemilik).
- `plugin/skills/wire/reference.md` — syarat gate `:45` untuk non-pemilik; catatan `:54` presence-based; `:74` beda wire/build.
- `plugin/rules/schema-projection.md` — resolve ke pemilik; no-op (bukan stub) untuk non-pemilik; input `app` diperluas.
- `plugin/skills/plan/SKILL.md` — `:39` baca via `schema_owner`.
- `plugin/skills/breakdown/SKILL.md` — `:15` read-set + validasi unit migrate; `:23` konsultasi reuse via `schema_owner`.
- `plugin/skills/breakdown/reference.md` — `:12`/`:87` manifest; `:196`/`:199` aturan `actions: migrate`.
- `plugin/skills/build/SKILL.md` — `:15` read-set; `:17` reconcile; `:35` slice brief; `:37` regen pasca-migrate.
- `plugin/rules/migration-impact.md` — catatan step 1 (pengelompokan per-DB).
- `plugin/skills/render-docs/SKILL.md` — `:28` kartu per database + baris pembaca.
- `plugin/skills/init/SKILL.md` — langkah 5 (`:47`–`:58`), blok `workspace.yaml` yang di-*generate*: seed `databases: []` + komentar. (Catatan: `plugin/template/control/` **tidak** memuat `workspace.yaml` — file itu ditulis `init` dari blok inline ini, jadi tak ada file template yang perlu disentuh.)
- `plugin/skills/upgrade/SKILL.md` — advisory deteksi `stack.db` kembar.
- `plugin/skills/ask/SKILL.md` — `:22` tabel rute: baris "Arsitektur … topology" diperluas menyebut kepemilikan DB (sumber tetap `workspace.yaml`; `ask` tak membaca `control/schema/`, jadi perubahannya satu baris tabel — opsional, bukan prasyarat).

**Regen**
- `plugin-kimi/` — `bash tools/build-kimi.sh` + `bash tools/tests/build-kimi.test.sh` (ritual rilis, README).

---

## 9. Verifikasi

1. **Aditif murni.** Produk 1:1 existing (KuyMahjong apa adanya): jalankan `plan`/`breakdown` pada fitur contoh → read-set & path proyeksi identik dengan sebelum perubahan. `control/schema/kuymahjong.md` tak tersentuh.
2. **B1 tertutup.** Deklarasikan `venue` dengan `stack.db: main`, `owner: kuymahjong` → `wire venue` tidak menghasilkan file migrasi baru dan tidak memanggil perintah apply; smoke query tetap dijalankan dan gate tetap bisa ijo.
3. **B1 tanpa deklarasi.** `venue` dengan `stack.db` free-text sama, `databases[]` absen → `wire venue` **STOP** sebelum apply, pesannya mengarahkan ke `architect`.
4. **B2 tertutup.** `plan` untuk fitur di `venue` membaca `control/schema/kuymahjong.md` → verdict `Model/Schema` memutuskan **reuse `venues`/`sessions`**, bukan `NEW`. `breakdown` mengisi `reuse:`; `build` step 1 berhasil me-reconcile-nya.
5. **B3 tertutup.** `tasks.yaml` dengan `actions: [migrate]` pada `unit: venue` → `breakdown` STOP di gate validasi unit dengan saran pindah ke `unit: kuymahjong`.
6. **B4 tertutup.** `wire venue` 5.5 tidak menawarkan opt-in apply-migrate; `permissions.deny` memuat cermin perintah apply.
7. **Promosi ter-GATE.** `add-app venue` → `architect` menawarkan nempel → diff `workspace.yaml` memperlihatkan `databases[]` lahir + `stack.db` kedua app jadi referensi, dalam satu approve.
8. **Sync Kimi.** `bash tools/tests/build-kimi.test.sh` hijau setelah regen.

---

## 10. Ringkas

Sistem tak pernah memutuskan bahwa app dan database itu 1:1 — ia hanya tak pernah ditanya. Spec ini menanyakannya, lalu menjawab dengan satu blok deklaratif (`databases[]`), satu fungsi resolusi (`schema_owner`), dan satu palang di tempat kerusakan benar-benar terjadi (`wire`, sebelum apply). Default-nya adalah status quo, sehingga produk yang memang 1:1 tak pernah perlu tahu fitur ini ada.

`type: db` — yang memicu penyelidikan ini — tidak diperlukan, dan tetap mungkin nanti tanpa membatalkan apa pun di sini.
