# H3 — Migration Governance (gate dampak skema lintas-fitur + urutan deploy + zero-downtime)

> Langkah-2, gap **H3** (HIGH) — gap **TERAKHIR** Langkah-2. Tanggal: **2026-06-06**. Repo `~/Developer/ai-boilerplate`, base `main` @ `92c0ed6`.
> Brainstorming **terkunci** lewat 6 AskUserQuestion: sumber consumer=**AI nyisir kode pas gate (dibantu FK M4)**; ketelitian=**campuran (lapor tabel + sorot kolom)**; bentuk=**nempel ke skill yang ada (skill tetap 21)**; data migrasi=**isian tegas `kind`+`affects` di breakdown**; urutan deploy=**runbook advisory di ship**; zero-downtime=**ingetin + konvensi (bukan paksa)**; momen warning=**dua-duanya (plan dini + build gate)**.

## 1. Ringkasan

Hari ini gate migrasi `build` cuma biner: "tampilkan rencana migrasi → approve → apply". Tak ada yang ngecek **dampak**: kalau fitur baru ngubah tabel milik fitur lama (`Order.status`, pecah `Product.price`→`ProductVariant`), tak ada yang ngingetin **siapa pembaca tabel itu** (worker, dashboard), **risiko lock/downtime**, atau **perlu-backfill**. Juga tak ada governance **urutan migrasi/deploy** lintas-app/repo, dan tak ada konvensi **zero-downtime** (expand-contract).

H3 bikin gate yang ADA jadi **sadar-dampak** dan nambah panduan deploy + konvensi — semuanya **advisory** (memperkaya gate "tampilkan + approve" yang sudah ada, **bukan** palang keras baru). Logika "siapa baca tabel X + nilai risiko" generik tinggal di **satu shared rule** `rules/migration-impact.md` (cermin `rules/schema-projection.md`), dipanggil `plan` (peringatan dini) + `build` (gate apply). **Tak ada skill baru** (skill tetap **21**). H3 nyandar **M4** (`control/schema/`) sebagai bibit consumer — **BUKAN** `packages[].consumers` (H2; konsep beda), **BUKAN** `data-model.md`/`roadmap.yaml` (fiksi, tak ada di disk).

## 2. Masalah

- **Gate migrasi buta-dampak.** `build/SKILL.md` step 3: `migrate` → "tampilkan rencana migrasi + approve dulu, baru apply". Itu menjawab "boleh apply?" tapi **tidak** "apa yang rusak kalau di-apply?". Tak ada daftar consumer, tak ada lock-risk, tak ada flag backfill.
- **Skema migrasi cuma kalimat bebas.** Di `breakdown/reference.md` blok `actions:`, item `- migrate: <deskripsi>` = satu string (cuma plus komentar gate inline). Tak ada penanda **jenis** (nambah aman / ngerusak bahaya / isi-ulang data) atau **tabel/kolom yang kena**. Gate tak punya bahan terstruktur buat menilai risiko.
- **Consumer-of-table tak ada rumahnya.** M4 `control/schema/<app>.md` mencatat **produsen-side** (siapa BIKIN/UBAH tabel) + relasi FK, tapi **sengaja tak** mencatat **siapa BACA tabel**. Trigger H3 ("kolom NOT NULL dibaca worker+dashboard") justru butuh sisi-pembaca itu.
- **Tak ada governance urutan & zero-downtime.** `plan` scoped 1 app → tak melihat dampak lintas-fitur/lintas-app. `ship` tak punya runbook "migrasi mana duluan, deploy app mana duluan" lintas-repo. `conventions.md` tak punya konvensi expand-contract. Di sistem LIVE: ALTER kolom dibaca worker+dashboard tanpa expand-contract = lock = downtime.

## 3. Tujuan & Non-Tujuan

**Tujuan**
- Gate migrasi `build` **sadar-dampak**: sebelum apply, tampilkan consumer (app + apakah nyentuh kolom yang diubah) + level risiko-lock + perlu-backfill + saran expand-contract. Tetap gate "tampilkan + approve" (advisory, bukan palang baru).
- `plan` kasih **peringatan dini** dampak skema lintas-fitur saat desain (section "Dampak Skema") → expand-contract bisa dirancang dari awal, bukan tambalan.
- Isian migrasi **tegas**: `breakdown` nulis `kind` (additive|destructive|backfill) + `affects` ([tabel, Table.kolom]) eksplisit per tugas migrasi.
- Consumer-of-table diturunkan **runtime** dari kode (di-bibit FK M4) — generik lintas-ORM, **tanpa DB hidup**, **tanpa** artifact durable baru / writer baru.
- `ship` agregasi **runbook urutan migrasi + deploy** ke deskripsi PR (advisory, cermin runbook integrasi M5).
- `conventions.md` punya heading konvensi migrasi/zero-downtime (expand-contract).

**Non-Tujuan (seam bersih, anti scope-creep)**
- **Tak ada skill baru**, tak ada `/migrate`/`/migrate-review`. Skill tetap **21**. Nol churn `plugin.json`/`marketplace.json`/README/induk §12 (lifecycle)/§7 (control-tree — H3 tak nambah file `control/`).
- **Tak ada palang keras.** Urutan deploy = runbook advisory; expand-contract = di-flag + konvensi, **tidak** dipaksa/diblokir. Alat generik tak tau infra deploy & apakah downtime-sebentar OK buat produk ini.
- **Tak ada artifact durable consumer-REGISTRY.** Consumer di-derive saat gate (read-only analisis), **tidak** disimpan sebagai mapping consumer-of-table yang queryable/di-maintain (hindari writer baru + staleness — konsisten alasan M4 sengaja tak simpan consumer). Blok prosa "Dampak Skema" yang `plan` tulis (§6a) = **narasi desain di plan-doc**, BUKAN registry durable yang dirujuk balik — sekali pakai di gate plan, basi-aman saat re-plan.
- **Tak overload `packages[].consumers`** (H2 = "app impor package", beda dari "fitur/kolom gantung ke tabel"). **Tak nyandar fiksi** `data-model.md`/`roadmap.yaml`.
- **Tak ubah** M4 `rules/schema-projection.md` (consumer = concern terpisah; H3 cuma BACA `control/schema/`).
- **Tak ubah `render-docs`** (dampak = analisis gate-time efemeral, bukan doc durable yang di-render).
- **Tak ubah** `invariants.md` (H3 bukan invarian platform), `intake`/`feature.yaml` (sensitivity tak relevan ke migrasi), brownfield `extract` (ditunda, konsisten M4/H2).
- **Package tetap DILARANG migrate** (`breakdown` §D-4 tak berubah) → `kind`/`affects` cuma relevan unit ∈ `apps[]`.

## 4. Isian migrasi tegas — `kind` + `affects` (`breakdown`)

Tugas migrasi sekarang: `actions: - migrate: <deskripsi>` (satu string). H3 nambah **dua sibling field** pada list-item action yang sama. Kalimat `migrate: <deskripsi>` **tetap utuh** (anchor M4 "task ber-`migrate`" aman; backward-compatible):

```yaml
actions:
  - migrate: <deskripsi>                       # tetep ada — DESTRUKTIF → build GATE sebelum apply
    kind: additive | destructive | backfill    # migrate.kind — action-scoped; WAJIB diisi breakdown buat tugas migrasi
    affects: [Order, Order.status]             # tabel (+ Table.kolom bila ngerusak/ubah kolom spesifik)
```

- **NAMA FIELD — disambiguasi (penting buat exec/grep).** `kind` di sini = **`migrate.kind`**, sibling dari list-item `- migrate:` di dalam `actions[]` (action-scoped). Ini **BEDA** dari `kind:` level-task yang sudah ada (`breakdown/reference.md` §B: `kind: feat|fix|debt` = traceability). Beda value-domain, beda nesting (action vs task). Karena dua `kind:` hidup di file yang sama (breakdown/reference.md), grep anchor WAJIB di-scope (lihat bug-guard §10 dup-phrase).
- `kind` (migrate.kind) — **additive** (tambah tabel/kolom nullable/index concurrently = aman, low-lock) · **destructive** (drop/rename/ubah-tipe kolom, NOT NULL tanpa default = bahaya, pembaca bisa rusak, lock) · **backfill** (isi-ulang/transform data baris existing = long-running, lock/beban). Nilai **tool-agnostic** (bukan istilah satu ORM).
- `affects` — daftar tabel yang disentuh; tambahkan `Table.kolom` bila perubahan ngerusak/ubah kolom spesifik (basis "sorot kolom" §6). Producer tau scope-nya sendiri (ini migrasi miliknya) → **bukan** consumer (consumer di-derive rule, §5).
- **Generik:** `migrate.kind`/`affects` diisi by-understanding dari rencana migrasi, lintas-ORM.
- **Degrade (BUKAN runtime-block):** tugas migrasi tanpa `kind`/`affects` (mis. dari breakdown lama) tetap valid — gate jatuh ke perilaku biner lama + minta lengkapi. **"WAJIB" = kewajiban PENULIS breakdown, bukan validasi runtime yang nge-abort** — jangan tambah cek-blokir di build/breakdown (langgar anti-palang-keras §3).

## 5. Otak bersama — shared rule `rules/migration-impact.md`

Satu file resep generik (cermin `rules/schema-projection.md`), dipanggil via `${CLAUDE_PLUGIN_ROOT}/rules/migration-impact.md`. **Prosedur ANALISIS read-only — tidak menulis file apa pun** (beda dari `schema-projection` yang nulis `control/schema/`; karena itu **tak ada concern penulis-tunggal**). Output = laporan in-memory yang dipakai pemanggil buat ditampilkan di gate / ditulis ke plan-doc.

**Input** (di-supply pemanggil):
- `affects` — tabel/kolom yang kena (dari `migrate.affects` saat build; dari delta-rencana-vs-baseline-M4 saat plan).
- `kind` — additive|destructive|backfill.
- daftar app — dari `workspace.yaml` `apps[]` (+ `path`/`stack` tiap app).
- `control/schema/<app>.md` (M4, bila ada) — bibit consumer via FK + provenance `Asal`.
- (opsional, saat build) `tasks.yaml` fitur — buat lihat task `migrate` LAIN yang `affects`-nya nyentuh tabel sama (expand→backfill→contract dipecah per task) → cegah salah-alarm di fase contract (§8).

**Langkah** (prosedur):
1. **Bibit dari M4 (scope jujur).** Baca `control/schema/` semua app: cari relasi FK yang menunjuk tabel di `affects` → kandidat yang gantung. **Batas:** FK M4 = relasi **intra-DB** (dalam satu app, atau lintas-app yang berbagi DB yang sama) — FK ini cuma nemu dependent satu-DB. **Consumer lintas-service** (app/worker/dashboard di DB terpisah yang baca tabel ini — justru kasus pemicu H3 di §1/§2) **TAK punya FK** ke tabel app lain → ditemukan oleh **scan kode (step 2)**, bukan dari FK. Jadi FK = bibit murah buat dependent satu-DB; beban deteksi lintas-service ada di scan. Catat juga `Asal` tabel kena (fitur pemilik) buat konteks gate.
2. **Nyisir kode (campuran tabel+kolom).** Buat tiap app di `workspace.yaml`, baca kode app (`path`/`stack`) → cari referensi **nama tabel** di `affects` (query/ORM model/raw SQL). **By-understanding, BUKAN regex/parser hardcode** (jalan lintas ORM). **Tanpa DB hidup** — baca file sumber, bukan introspeksi koneksi. Bila `kind: destructive` & `affects` memuat `Table.kolom` → sekalian tandai app mana yang kelihatan **nyentuh kolom itu** (sorot), tanpa men-skip yang cuma nyentuh tabel (jaring lebar).
3. **Nilai risiko by `kind`.**
   - `additive` → lock rendah; pembaca existing tak rusak (tambahan aman); backfill: tidak.
   - `destructive` → lock tinggi pada tabel besar; pembaca kolom yang diubah **bisa rusak**; backfill: mungkin (mis. NOT NULL butuh isi default dulu).
   - `backfill` → long-running; risiko lock/beban tabel; pembaca: data berubah saat proses.
4. **Susun laporan:** `affects` (tabel + kolom + `Asal`) · `kind` · **daftar consumer** (app + ditandai "nyentuh kolom yang diubah" / "nyentuh tabel saja") · **level risiko-lock** · **flag perlu-backfill** · **saran expand-contract** (bila destructive pada kolom yang dibaca consumer hidup).

**Saran expand-contract (generik, dibawa rule):** "Untuk perubahan ngerusak pada kolom yang masih dibaca consumer, pertimbangkan pola **expand → migrate → contract**: (1) tambah bentuk baru (kolom/tabel) tanpa hapus lama, (2) backfill + tulis-ganda, (3) alihkan pembaca ke bentuk baru, (4) baru hapus yang lama — dipecah lintas beberapa rilis." Rule bawa pengetahuan ini sendiri → **tetap jalan walau `conventions.md` section migrasi kosong**; bila ada, gate juga rujuk spesialisasi project di `conventions.md`.

**Aturan rule:**
- **Read-only:** menganalisis, tak menulis artifact. Pemanggil yang memutuskan menampilkan/menulis-ke-plan.
- **Generik:** lintas-ORM; runtime dari kode yang ADA; tak ada cabang hardcode per-stack; tak butuh DB hidup.
- **Anti-fiksi/anti-overload:** consumer = FK M4 + scan kode. **BUKAN** `packages[].consumers`; **BUKAN** `data-model.md`/`roadmap.yaml`.
- **Degrade-ke-best-effort:** `control/schema/` tak ada / scan kosong → laporan "best-effort; tak ada consumer diketahui" + tetap tampilkan `kind`/risiko/saran. **Jangan error**, jangan blokir.
- **Batas (sadar):** scan kode best-effort — akses dinamis/refleksi/string tabel terbangun runtime bisa lolos; consumer lewat API (bukan akses DB langsung) tak ketangkep. Gate tetap minta approve manusia (advisory), jadi miss = degradasi anggun, bukan fatal.

## 6. Wiring — di mana H3 nempel

### 6a. `plan` — section "Dampak Skema Lintas-Fitur" (peringatan dini)
`plan` step 3 sudah baca `control/schema/<app>.md` (baseline M4). Tambah: bila rencana fitur ini **mengubah tabel yang sudah ada di baseline** (tabel ber-`Asal` fitur lain — alter-existing, bukan tabel baru fitur ini) → panggil `migration-impact` (affects = delta-rencana, kind = ditaksir dari sifat perubahan) → tulis blok **"Dampak Skema"** (tabel kena + consumer + risiko + saran expand-contract) ke `plans/_shared.md` (bila consumer lintas-app) / `plans/<app>.md` (bila 1 app) → sodorkan di **gate plan**. Murni peringatan dini; keputusan tetap user. Tabel **baru** (fitur ini yang bikin) → tak ada dampak lintas-fitur → skip. **Pra-M4/brownfield (tak ada `control/schema/` → tak ada `Asal`):** peringatan dini plan-side **degrade OFF** (tak ada baseline buat hitung delta-vs-`Asal`); jaring pindah ke gate `build` (§6b, via scan kode) — bukan hole fatal, tapi dini-nya hilang sampai M4 ngisi baseline.

### 6b. `build` — gate migrate diperkaya (titik keputusan)
`build/SKILL.md` step 3 + `reference.md` §E: gate `migrate` ("tampilkan + approve sebelum apply") TETAP. Tambah: **sebelum approve**, panggil `migration-impact` (pakai `kind`+`affects` tugas) → tampilkan consumer + risiko-lock + perlu-backfill + saran expand-contract di samping rencana migrasi → baru minta approve. **Bukan palang baru** — approve yang sama, konten lebih lengkap. (Tetap cuma unit ∈ `apps[]`; package/integration tak migrate.)

### 6c. `ship` — runbook urutan migrasi & deploy (advisory)
`ship/SKILL.md` step 6 sudah agregasi runbook integrasi (M5) ke deskripsi PR. Tambah: bila work-item punya tugas `migrate` (apalagi `destructive`/`backfill`, apalagi lintas-app/repo) → agregasi **runbook urutan migrasi + deploy** ke deskripsi PR: urutan aman (migrasi expand/additive dulu → deploy app pemakai → migrasi contract terakhir) + catatan backfill + langkah zero-downtime. **Advisory** (panduan, bukan gate keras). Cermin runbook integrasi; scoped ke migrasi (full release-runbook = Langkah 3).

### 6d. `conventions.md` — heading "Konvensi Migrasi & Zero-Downtime"
Template `plugin/template/control/conventions.md` dapat heading stub baru (cermin "Konvensi Package"/"Konvensi Integrasi" yang sudah ada) berisi pola expand-contract generik + tempat spesialisasi per-produk. Gate `build`/`plan` rujuk section ini bila ada (rule tetap bawa pengetahuan generik bila kosong, §5).

## 7. Generik (jaminan lintas-stack)

- `kind` (additive/destructive/backfill) + konsep lock/backfill/expand-contract = **universal**, bukan istilah satu ORM/tool.
- `affects` = nama tabel/kolom = generik.
- consumer-scan = by-understanding, lintas-ORM, **tanpa DB hidup** (baca kode sumber).
- expand-contract = pola universal; rule bawa pengetahuannya, tak hardcode stack.
- **Degrade-anggun** di tiap titik: no M4 file / scan kosong / breakdown lama tanpa `kind` → best-effort + tetap gate manual, tak pernah error/blokir.

## 8. Edge case & degrade

| Kasus | Perilaku |
|---|---|
| Tabel **baru** (fitur ini yang bikin) | Tak ada dampak lintas-fitur. plan skip blok Dampak; build gate tampil "additive, tak ada consumer existing". |
| `control/schema/` belum ada (pra-M4/brownfield) | Bibit FK kosong → scan kode saja → laporan best-effort. Tak error. **plan-side early-warning OFF** (tak ada `Asal` buat picu §6a); gate `build` tetap jaring via scan. |
| Beberapa task migrate nyentuh **tabel sama** (expand→backfill→contract dipecah per task: T3 tambah kolom nullable, T8 backfill, T12 NOT NULL) | Gate **per-task wajar** (tiap task tetap di-approve; peringatan berulang = **sengaja**, bukan bug — jangan invent de-dup state). Rule **boleh** baca `affects` task lain di `tasks.yaml` fitur ini → sebut "tabel ini juga disentuh task T#/T# (expand/backfill)" supaya saran expand-contract **tak salah-alarm di fase contract** (T12 aman justru karena T3+T8 sudah expand+backfill). |
| Scan kode tak nemu consumer | Laporan "tak ada consumer diketahui (best-effort)"; gate tetap tampilkan kind/risiko/saran. |
| Tugas migrate lama tanpa `kind`/`affects` | Gate jatuh ke perilaku biner lama + minta user lengkapi/`breakdown` ulang. Tak crash. |
| `kind: additive` | Risiko rendah; gate ringkas (tak ada saran expand-contract); ship runbook taruh di urutan awal. |
| Consumer lewat API (bukan akses DB langsung) | Best-effort scan bisa miss (§5 batas); gate manual = jaring akhir. |
| Unit `package`/`integration` punya `migrate` | Tak terjadi (package DILARANG migrate §D-4; integration n/a). H3 tak relevan. |
| Migrasi lintas-repo | `affects`/consumer di-scan lintas semua app `workspace.yaml` (path masing-masing); ship runbook urutkan per repo. |
| User reject di gate | Tak apply (perilaku gate existing); tak ada efek samping H3. |

## 9. Edit-map (anchor diverifikasi `grep -Fc -e` saat writing-plans)

**NEW**
- `plugin/rules/migration-impact.md` — prosedur §5 lengkap (input/langkah/output/aturan/batas, read-only, generik, anti-fiksi).

**MODIFY skill**
- `plugin/skills/breakdown/reference.md` — §A actions block (anchor `  - migrate: <deskripsi>   #   DESTRUKTIF → build TAMPILKAN + GATE sebelum apply (jangan auto)`): tambah dua sibling line `kind:` + `affects:` (sisip sub-line, **bukan** renumber). §D-1 (anchor `1. **\`actions\` (kerja AI bisa, non-file).**`): tambah klausa "`migrate` bawa `kind`(additive|destructive|backfill)+`affects`([tabel/kolom]) — WAJIB; basis gate dampak H3". §B (aturan `actions:`, anchor `**\`actions:\` untuk kerja non-file.**`): tambah kalimat "tugas `migrate` WAJIB `kind`+`affects`".
- `plugin/skills/build/SKILL.md` — step 3 actions (anchor `**\`migrate\` → JANGAN auto: tampilkan rencana migrasi + minta approve user dulu** (destruktif), baru apply;`): tambah klausa "sebelum approve, panggil `${CLAUDE_PLUGIN_ROOT}/rules/migration-impact.md` (`migrate.kind`+`affects` tugas) → tampilkan consumer + risiko-lock + perlu-backfill + saran expand-contract; gate tetap advisory". **Catatan exec:** line ini sudah PADAT (carry teks migrate-GATE + klausa M4 "**Proyeksi skema (M4):**" pada line yang sama). Sisip klausa H3 **SEGERA setelah "…baru apply;" dan SEBELUM "**Proyeksi skema (M4):**"** (gate-time analysis mendahului post-`done` regen). Sub-clause, **bukan** baris/step baru.
- `plugin/skills/build/reference.md` — §E (anchor `\`migrate\` → **GATE**: tampilkan + approve sebelum apply (destruktif).`): tambah sub "+ panggil rule `migration-impact` buat tampilkan dampak (consumer/lock/backfill/expand-contract) sebelum approve".
- `plugin/skills/plan/SKILL.md` — step 3, sesudah bullet baca `control/schema/<app>.md` (anchor `- **Baca \`control/schema/<app>.md\` (proyeksi skema durable, M4) DULU**`): tambah bullet "Dampak Skema Lintas-Fitur — bila rencana mengubah tabel ber-`Asal` fitur lain, **`plan` men-supply `affects`=tabel-yang-rencananya-diubah (delta vs baseline `control/schema/`) + `kind`=taksiran dari sifat perubahan**, lalu panggil `${CLAUDE_PLUGIN_ROOT}/rules/migration-impact.md` → tulis blok Dampak Skema (consumer/risiko/saran) ke `_shared.md`/`plans/<app>.md`, sodorkan di gate. Pra-M4 (tak ada baseline) → bullet ini OFF (§6a)." **Blok Dampak Skema = prosa SETELAH fenced-template step 4 (seperti narasi gate/utang yang sudah ada), BUKAN field di dalam fence — jangan tambah baris ke blok template berpagar.**
- `plugin/skills/ship/SKILL.md` — step 6, sesudah Runbook integrasi (anchor `**Runbook integrasi (bila work-item kena vendor di \`integrations.md\`):**`): tambah "**Runbook migrasi & urutan deploy (bila work-item punya tugas `migrate`):**" — agregasi urutan aman (expand/additive→deploy→contract) + backfill + langkah zero-downtime ke deskripsi PR (advisory).
- `plugin/template/control/conventions.md` — sesudah heading `## Konvensi Integrasi` (anchor `## Konvensi Integrasi`): tambah `## Konvensi Migrasi & Zero-Downtime` + komentar guidance expand-contract generik.

**MODIFY parent spec** `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`
- §8 repo-tree rules (anchor `│   └── rules/    anti-yes-man.md· debt-aware.md· schema-projection.md`): append `· migration-impact.md` → `…· schema-projection.md· migration-impact.md`. **Separator = middot+space `· ` (U+00B7), BUKAN titik biasa/bullet** — `grep -Fc -e` byte-eksak.
- §17 Komponen baris **Rules** (anchor `- **Rules:** \`anti-yes-man.md\` · \`debt-aware.md\` · \`schema-projection.md\``): tambah ` · \`migration-impact.md\``. (Separator §17 = ` · ` spasi-middot-spasi + backtick — beda gaya dari §8 tree; ikuti gaya lokal masing-masing.)
- §9 ship prose (anchor `temuan high → STOP. PR menyertakan runbook integrasi (webhook-URL + secret-NAMA + test→live).`): append kalimat "Bila ada tugas `migrate`, PR juga menyertakan runbook urutan migrasi & deploy (advisory)." — cermin presedan M5 (commit `84d471b` meng-amend §9 saat ship mulai agregasi runbook integrasi; runbook migrasi H3 paralel, biar deskripsi ship di induk tetap lengkap). **Parent-doc completeness — perilaku nyata ada di `ship/SKILL.md` (sudah di edit-map di atas).**

**TAK disentuh (eksplisit):** skill-count (tetap **21**), `plugin.json`, `marketplace.json`, README, induk §7 (control-tree — tak ada file `control/` baru), §12 (lifecycle — tak ada fase baru), `render-docs`, `invariants.md`, `intake`/`feature.yaml`, M4 `rules/schema-projection.md`, `packages[].consumers`.

## 10. Verifikasi & bug-guard

**Grep-battery (post-exec):**
- V0 `plugin/rules/migration-impact.md` ADA + memuat klausa §5 (read-only, generik lintas-ORM, anti-fiksi consumer, degrade best-effort, saran expand-contract). (Janji perilaku — prosa resep — diverifikasi by-read, bukan grep.)
- V1 `migration-impact` direferensi `plan` + `build/SKILL.md` + `build/reference.md` (idiom `${CLAUDE_PLUGIN_ROOT}/rules/migration-impact.md`; ≥3 surface).
- V2 `breakdown/reference.md` memuat `kind:` + `affects:` di blok actions migrate + aturan WAJIB di §B/§D.
- V3 `ship/SKILL.md` memuat "Runbook migrasi" (urutan deploy/migrasi) di step 6.
- V4 `conventions.md` memuat heading `## Konvensi Migrasi & Zero-Downtime`.
- V5 skill-count tetap **21** di induk §17 + tak ada edit `plugin.json`/`marketplace.json`/README.
- V6 induk §8 rules + §17 Rules memuat `migration-impact.md` (4 file rules).
- V7 **anti-fiksi/anti-overload (scope ke surface H3):** tak ada referensi `data-model.md`/`roadmap.yaml` di artifact H3; consumer di-anchor ke `control/schema/`/scan-kode, **bukan** `packages[].consumers`. Cek hanya **surface yang H3 tambah** (`rules/migration-impact.md` baru + klausa H3 di build/plan/ship) — bukan grep telanjang `packages[` se-repo. **EXPECTED match (BUKAN regresi):** `breakdown/reference.md` §D-4 sudah punya `untuk tiap nama di packages[<pkg>].consumers` (fan-IN H2, konsep "app impor package" — sah, tak disentuh H3). Jangan salah-fix itu.
- V8 **anti-palang-keras:** ship runbook & expand-contract berkata "advisory/panduan/saran", bukan "blokir/STOP/gagal" (kecuali gate apply existing yang sudah ada).

**Bug-guard pre-bake (untuk plan):**
- **colon-space frontmatter:** H3 **tak** mengubah `description:` SKILL.md mana pun (cuma body) → risiko rendah; bila terpaksa, pakai ` — ` bukan `: `.
- **no-renumber:** semua sisipan = sub-line/sub-bullet/klausa/heading baru — **jangan** renumber langkah/step skill. (build step 3, plan step 3, ship step 6, breakdown §A/§B/§D = sisip, bukan renumber.)
- **mis-aimed-pointer:** verifikasi tiap `§X`/`reference §Y` nunjuk seksi benar — di rule, skill, DAN spec ini (induk §7/§8/§12/§17). Edit-map before→after di §9 yang nge-quote teks-lama = dokumentasi, **bukan** pointer live.
- **`grep -Fc -e` anchor:** tiap find/replace diverifikasi verbatim SEBELUM commit (robust leading-dash `- ` & metachar `[]`/`**`/backtick/`→`; awas em-dash `—` vs arrow `→` byte-trap, Lesson #13).
- **dup-phrase + `kind` collision:** anchor `migrate`/`affects` dicek unik antar-file (mis. `- migrate: <deskripsi>` muncul di breakdown reference; scope grep ke file target). **Khusus `kind:`** — breakdown/reference.md sudah punya `kind:` level-task (feat|fix|debt) di §B; `migrate.kind` H3 = `kind:` action-scoped berbeda. JANGAN grep telanjang `kind:` di file itu (ambigu). Anchor edit migrate via baris `- migrate: <deskripsi>` + sisip sibling ber-indent action-level; verifikasi visual nesting (di bawah `actions:`, bukan di bawah task).
- **one-file-per-task:** plan satu task = satu file; tiap anchor diverifikasi vs file SEKARANG.
- **literal-scan sentinel:** token baru (`kind`/`affects`/`additive`/`destructive`/`backfill`) aman — pastikan tak nabrak scan literal skill lain.

## 11. Hubungan

- **← M4 (`control/schema/`):** H3 nyandar M4 sebagai bibit consumer **satu-DB** (FK = dependent intra-DB) + konteks `Asal`; consumer **lintas-service** (kasus pemicu) datang dari scan kode, bukan FK (§5 step 1). M4 producer-side; H3 nambah consumer-side + governance. M4 **tak diubah** (H3 cuma BACA). Asimetri sengaja: M4 simpan provenance (tak bisa ditebak dari skema); consumer **bisa** diturunkan dari kode → H3 derive runtime, tak simpan (hindari writer/staleness).
- **vs H2 (`packages[].consumers`):** **konsep beda** — H2 = "app impor package"; H3 = "fitur/kolom gantung ke tabel". H3 **tak** overload `packages[].consumers`.
- **vs M5 (`integrations.md`/runbook):** ship runbook migrasi = **cermin** runbook integrasi M5 (pola sama, scope beda). Tak overlap.
- **vs Langkah-1 (security gate):** ortogonal; H3 = integritas skema/availability, bukan security. Tak menyentuh `security-critic`/`sensitivity`.
- **Lifecycle:** tak ada fase baru. H3 = kewaspadaan yang nempel di `plan`/`build`/`ship`/`conventions.md`. Skill tetap 21.
- **→ Langkah berikutnya:** H3 = gap **terakhir** Langkah-2 → Langkah-2 TUNTAS. Sisa: Langkah 3 (medium/low, lihat handoff `2026-06-01-langkah-2-sisa-3.md` §4) + live `/plugin install` end-to-end test (belum pernah, semua fase).
