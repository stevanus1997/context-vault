# M7 — Graduated Autonomy (risk tiering per-fitur + unattended-segment build)

> Langkah-3, gap **M7** (MEDIUM) — autonomy bottleneck. Tanggal: **2026-06-06**. Repo `~/Developer/ai-boilerplate`, base `main` @ `1dba8d1`.
> USULAN FIX (titik awal, BUKAN final): field `feature.yaml` `risk: low|normal|high` + build flag `--unattended` per-segmen. Auto-tag-high HARD floor untuk fitur sensitif. JANGAN ambil batch/sticky-approve lintas-app (itu value-prop produk bayar) — cukup unattended-segment dalam SATU fitur + tiering.

## 1. Ringkasan

`build` step 6 menghentikan eksekusi (**BERHENTI** + minta approve/revisi) di tiap **segmen gate** (default `app × milestone`, `build/reference.md` §D). Untuk fitur multi-app multi-milestone yang dibangun solo-dev full-AI, ini menumpuk **belasan stop** per fitur (tiap segmen + tiap `migrate` + tiap `needs_human` + tiap `blocked`) → review jadi bottleneck approval, padahal **tidak semua segmen sama bahayanya**. Gate flat memperlakukan refactor CSS sepele sama beratnya dengan perubahan pembayaran.

M7 menambah **satu field durable** `feature.yaml` `risk: low|normal|high` (axis BARU, **terpisah dari** `sensitivity` — lihat §2 keputusan D1) + **satu flag opsional** `build --unattended`. Saat `--unattended`, segmen ber-`risk: low`/`normal` **auto-approve** (build lanjut tanpa stop user); segmen yang menyentuh **HARD floor** (`risk: high`, ATAU task `migrate`, ATAU `needs_human`, ATAU `blocked`, ATAU penyimpangan-dari-maksud) **TETAP STOP** — floor ini yang menjaga value-prop review per-app. `risk` di-USULKAN `intake` (heuristik, sejajar `sensitivity`) dengan **auto-floor**: fitur ber-`sensitivity` non-kosong → `risk` minimal `high` (HARD, tak bisa diturunkan). Dibaca `build` (konsumen baru — build belum baca `sensitivity` saat ini).

> **Catatan jujur (melonggarkan cadence, BUKAN gate baru).** M7 **tidak** menambah gate. Ia **MELONGGARKAN** cadence gate `build` step 6 yang SUDAH ADA, hanya untuk segmen ber-`risk` rendah & hanya saat user **eksplisit** minta mode unattended (token `--unattended` ATAU maksud NL tanpa-pengawasan — dideteksi di build step 1). Default (tanpa mode) = perilaku sekarang (stop tiap segmen). HARD floor (`risk: high` + `migrate` + `needs_human` + `blocked` + penyimpangan) **tetap STOP** — review per-app untuk hal berbahaya tak pernah dikikis. Ini ditulis jujur di **build step 6** (tempat logika cadence beneran jalan) + **build/reference.md §D**. **Security Gate `ship` (step 4.5) TIDAK disentuh** — unattended cuma melonggarkan approval BUILD-segment, bukan ship/security/migrate.

M7 **tak menggandakan** mesin: `risk` = SEBERAPA berbahaya kalau salah (menyetir **cadence approval** di `build`); `sensitivity` = APA yang sensitif (menyetir **kedalaman security gate** di `ship`). Beda konsumen, beda gate. Auto-floor menautkan keduanya satu arah (sensitivity → risk minimum) tanpa membuat satu field melayani dua gate.

## 2. Keputusan desain (tiap fork + alternatif yang ditolak + alasan)

> Ini GANTI brainstorming 1-1. Tiap keputusan di bawah aku putuskan sendiri sebagai titik awal — **user boleh veto** mana pun.

### D1. `risk` = axis TERPISAH, BUKAN turunan/extend `sensitivity` — **DIPUTUSKAN: terpisah**
- **Pilihan:** (a) `risk` field baru, independen; (b) `risk` = turunan/derived dari `sensitivity` (mis. `payments`/`pii` ⇒ `risk: high`, sisanya `normal`); (c) extend `sensitivity` jadi menanggung dua makna.
- **DIPUTUSKAN (a) terpisah.** Alasan: `sensitivity` & `risk` punya **konsumen berbeda & gate berbeda**. `sensitivity` dibaca `ship` step 4.5 (apakah invoke `security-critic` + kedalaman red-team) dan di-RE-EVAL di `fix` (`fix/reference.md` §D baris 64 — bukan warisan pasif). `risk` dibaca `build` step 6 (cadence approval). Memaksa satu field melayani dua gate = coupling jelek: fitur PII-read-only yang aman dibangun (CSS tampilkan nama) **butuh** `sensitivity: [pii]` untuk red-team ship, tapi **tidak** butuh `risk: high` di build. Sebaliknya migrasi DB besar tanpa PII = `risk` tinggi, `sensitivity` kosong.
- **Korelasi satu arah (auto-floor, D4):** keduanya boleh berkorelasi — `sensitivity` non-kosong → `risk` minimal `high`. Tapi korelasi ≠ identitas. Ditolak (b)/(c) karena menghilangkan kemampuan menyatakan "sensitif tapi build-nya aman" atau "build berbahaya tapi tak sensitif".
- **Preseden:** cermin M6 §11 "Hubungan" yang membedakan `risks.md` (lanskap) vs `invariants.md` (keputusan) vs `sensitivity` (per-fitur) — beda peran walau berkorelasi.

### D2. Nilai tier = `low | normal | high` (3 tingkat), default `normal` — **DIPUTUSKAN**
- **Pilihan:** (a) 2-state `low|high`; (b) 3-state `low|normal|high`; (c) skala numerik 1-5.
- **DIPUTUSKAN (b).** `normal` = default (perilaku konservatif: tanpa `--unattended`, semua tier stop seperti sekarang; dengan `--unattended`, `low`+`normal` auto, `high` stop). 2-state terlalu kasar (tak ada "default aman tengah"); numerik over-engineer untuk fix-light. Default `normal` (bukan `low`) supaya fitur yang **lupa** di-tag tidak diam-diam jadi auto-approve paling longgar — fail-safe ke arah lebih banyak review.

### D3. Mekanik longgar = `build --unattended` flag (opt-in eksplisit, per-RUN), BUKAN field durable `unattended: true` di feature.yaml — **DIPUTUSKAN: flag**
- **Pilihan:** (a) flag CLI `build --unattended` (ephemeral, per-invocation); (b) field durable di `feature.yaml`.
- **DIPUTUSKAN (a) flag.** Unattended = **keputusan operasional saat ini** ("aku lagi nggak di depan layar, jalanin yang aman"), bukan properti durable fitur. Flag membuat default selalu = attended (aman); user memilih melonggarkan secara sadar tiap run. Field durable bikin mode longgar "lengket" & mudah terlupa nyala. **Honesty:** tanpa mode, M7 nyaris no-op di build (cuma `risk` ke-baca & ditampilkan); efek longgar HANYA muncul saat user opt-in.
- **Deteksi (krusial — Lesson #16):** trigger `build` = bahasa-natural (`build <fitur>`/`implement`/`kerjain`), dan **tak ada parser flag CLI** di skill mana pun (diverifikasi: nol `$ARGUMENTS`/`argument-hint`/flag-parse di plugin). Maka mode HARUS dikenali dari NL request, bukan hanya token literal. build step 1 (§4c) mengenali mode dari token `--unattended` ATAU frasa maksud ("unattended", "tanpa pengawasan", "jalanin yang aman tanpa aku"), dan `--unattended` ditambahkan ke daftar trigger description supaya mode discoverable. Tanpa kedua kait ini, klausa unattended step 6 jadi teks mati (tak ada surface yang membaca/mengiklankannya).

### D4. Auto-tag-high = HARD floor dari `sensitivity` non-kosong, SEMPIT — **DIPUTUSKAN: sensitivity non-kosong ⇒ risk ≥ high (hard)**
- **Masalah (HOLE-7 scout):** "auto-tag-high HARD floor" — apa pemicunya? Kalau dari sensitivity, apakah bisa diturunkan user?
- **DIPUTUSKAN:** pemicu = **`sensitivity` memuat `payments` ATAU `pii`** (mis. cocok dengan slot PII/PCI di `invariants.md` / pemicu di `risks.md` M6) ⇒ `intake` USULKAN `risk: high` dan tandai sebagai **floor** (user boleh naikkan, **tak boleh turunkan** di bawah `high` selama `sensitivity` non-kosong). Konsisten karena sensitivity sendiri sudah di-konfirmasi user di intake gate + di-re-eval di fix. Tier `risk` lain (non-sensitif) sepenuhnya usulan-yang-bisa-diedit.
- **Alternatif ditolak:** (i) auto-high SOFT (bisa diturunkan) — ditolak: prompt minta HARD floor; melindungi value-prop (fitur uang/PII tak boleh diam-diam unattended). (ii) auto-high dari heuristik teks luas (mis. kata "delete"/"migrate") — ditolak: over-trigger, bikin `risk: high` palsu (lihat HOLE-7); `migrate` sudah punya HARD floor sendiri di build step 3 (D5), tak perlu naikkan seluruh fitur.
- **Honesty (over-trigger jujur):** fitur PII sepele (tampilkan nama) ⇒ floor `high` ⇒ unattended mati untuk fitur itu. Ini **disengaja & konservatif** — kalau user yakin aman, ia jalankan attended (default) atau turunkan `sensitivity` di gate intake (yang lalu menurunkan floor secara sah). Ditulis di intake step 7 + reference.

### D5. HARD floor di build = `risk: high` + `migrate` + `needs_human` + `blocked` + penyimpangan — **DIPUTUSKAN (carve-out berlapis)**
- **Masalah (HOLE-5/6 scout):** unattended tak boleh menelan stop yang melindungi hal mahal/destruktif.
- **DIPUTUSKAN — `--unattended` TIDAK PERNAH skip:**
  - segmen yang memuat task ber-`risk: high` (tier fitur high → SELURUH segmen attended);
  - task `actions: migrate:` (build step 3 baris 33 "JANGAN auto: minta approve user dulu" — destruktif, **bukan** risk-axis);
  - task `needs_human` (build step 2 baris 22 — `manual:` STOP);
  - task `blocked` (build step 5 baris 44 — error → STOP);
  - **penyimpangan-dari-maksud** (build step 6 "dibangun vs task meleset" → disiplin fix embed) — auto-approve hanya untuk segmen yang test ijo DAN "dibangun vs task" cocok; meleset → STOP walau `risk: low`.
- **Alasan:** `risk` axis ≠ destruktif-axis ≠ error-axis. Migrate/needs_human/blocked/penyimpangan adalah gate berbasis-SIFAT-aksi (sudah ada), ortogonal ke risk berbasis-bahaya-fitur. Unattended cuma melonggarkan **approval-segmen-rutin-yang-ijo** untuk tier rendah.
- **Floor STRUKTURAL, bukan cuma deklaratif (diverifikasi disk):** tiga floor pertama tegak SEBELUM loop mencapai gate step 6 — `needs_human` STOP-kan seluruh build di **step 2** (`manual:` belum beres), `migrate` gate di **step 3** (minta approve sebelum apply), `blocked` STOP di **step 5** (error). Maka klausa unattended step 6 secara struktural **tak pernah** bisa auto-approve segmen yang punya floor-task belum-tuntas: build berhenti lebih dulu di step 2/3/5. Hanya `risk: high` & penyimpangan yang dievaluasi DI step 6 itu sendiri. Ini memperkuat klaim kejujuran — floor bukan janji di atas kertas, ia di-enforce oleh urutan langkah yang sudah ada.
- **Anti-yes-man (build step 6 baris 47 "keputusan mahal jangan ditunda diam-diam"):** unattended yang melompati floor = menunda keputusan mahal diam-diam → DILARANG. Floor ini operasionalisasi prinsip itu.

### D6. Granularity `risk` = per-FITUR (feature.yaml), BUKAN per-milestone/per-task — **DIPUTUSKAN (fix-light)**
- **Pilihan:** (a) `risk` di `feature.yaml` (per-fitur, build terapkan ke semua segmen); (b) `risk` per-milestone di `tasks.yaml`/`breakdown`.
- **DIPUTUSKAN (a).** Per-milestone = lebih besar (sentuh `breakdown` + skema `tasks.yaml` + per-segmen tiering) → melebihi "light" (scope-flag M7-FLAG-A). Fix-light = satu `risk` per fitur; build menerapkan tier ke seluruh segmen fitur, dengan floor per-SIFAT-task (migrate/needs_human/blocked) yang tetap mengoverride per-segmen. Cukup memecah bottleneck tanpa membangun mesin tiering granular.
- **Konsekuensi jujur:** fitur ber-`risk: low` yang punya SATU milestone berbahaya → tetap `low` di feature.yaml, tapi milestone berbahaya itu **tetap** kena floor migrate/blocked/penyimpangan kalau ada; kalau bahayanya "halus" (tak memicu floor) user bisa naikkan ke `normal`/`high` di intake. Batas diterima untuk fix-light.

### D7. `fix.yaml` TIDAK dapat `risk` — fix selalu attended — **DIPUTUSKAN (konservatif)**
- **Masalah (HOLE-8 scout):** fix pinjam mesin `build` (`fix/SKILL.md` baris 10/34/46). Kalau `--unattended` berlaku ke fix-build, `risk` fix dari mana?
- **DIPUTUSKAN:** fix lane **selalu attended** — `--unattended` adalah pintu masuk FITUR (`build <fitur>`), bukan fix. Bug = inherently berisiko (perilaku yang sudah dipakai user ternyata salah); auto-approve fix mengikis kehati-hatian. Tak menambah field `risk` ke `fix.yaml` (`fix.yaml` sudah punya `sensitivity` re-eval; menambah `risk` = perluasan, scope-flag M7-FLAG-C). Build step 6 unattended-clause berlaku **hanya** saat work-item = `features/<fitur>/` (bukan `fixes/<id>/`).
- **Mekanik:** build sudah tahu work-item-type (step 1 baris 15: `feature.yaml status: active` vs `fix.yaml status: open/diagnosed`). Klausa unattended cek "work-item fitur DAN feature.yaml `risk` ≠ high" sebelum auto-approve.

### D8. Default tanpa flag = perilaku LAMA persis (zero-churn untuk yang tak opt-in) — **DIPUTUSKAN**
- Tanpa `--unattended`: build stop tiap segmen seperti sekarang, `risk` cuma di-baca & ditampilkan di header gate (informatif). Tak ada perubahan perilaku untuk siapa pun yang tak mengetik flag. Ini membuat M7 aman-mundur & mudah di-veto sebagian (user bisa pakai `risk` field tanpa pernah pakai `--unattended`).

## 3. Skema field — `feature.yaml` `risk`

Field BARU di blok `feature.yaml` (di-CIPTAKAN dua tempat: `intake/SKILL.md` step 1 + `feature/SKILL.md` step 1 — **WAJIB identik di keduanya** atau drift). Ditambah **SETELAH** `sensitivity` (yang TETAP di posisinya — banyak skill anchor ke barisnya; jangan geser):

```yaml
name: <fitur>
status: draft
created: <YYYY-MM-DD>
sensitivity: []        # (existing — JANGAN ubah) [] | [payments] | [pii] | [payments, pii]
risk: normal           # (M7) low | normal | high — menyetir cadence approval build --unattended; sensitivity non-kosong → floor high (hard)
```

- **Nilai:** `low` | `normal` | `high` (default `normal`, D2).
- **Semantik:** SEBERAPA berbahaya bila build keliru → menyetir cadence approval `build` (bukan kedalaman security `ship` — itu `sensitivity`).
- **Floor (D4):** `sensitivity` memuat `payments`/`pii` ⇒ `risk` minimal `high` (hard; user boleh naikkan, tak boleh turunkan selama sensitivity non-kosong).
- **BUG-GUARD colon-space:** value `risk: normal` tunggal & bersih (tak ada `: ` di value). Komentar inline pakai em-dash/kurung, **bukan** `: ` setelah value. Verifikasi pasca-edit: tak ada `: ` dalam value YAML.
- **Default scaffold:** field ditulis saat feature.yaml di-CIPTAKAN (intake/feature step 1) — tak ada file template feature.yaml (di-generate; lihat §4), jadi tak ada perubahan `init`.

**Asimetri sengaja vs `sensitivity`:** keduanya per-fitur, di feature.yaml, diusulkan intake. Beda: `sensitivity` = APA-sensitif → konsumen `ship` (security-critic) + re-eval `fix`; `risk` = SEBERAPA-bahaya → konsumen `build` (cadence). `risk` adalah konsumen-baca BARU di build (build belum baca `sensitivity` sekarang).

## 4. Wiring — di mana M7 nempel

### 4a. `feature.yaml` creation — DUA tempat identik (M1+M7 share; tulis ke KEDUANYA)
`feature.yaml` **tidak punya file template** (diverifikasi: di-generate, dibaca 8 skill). Ia di-CIPTAKAN di dua blok hampir-kembar:
- `intake/SKILL.md` step 1 (baris 13-19) — komentar `diusulkan di step 7`.
- `feature/SKILL.md` step 1 (baris 13-19) — komentar `diusulkan intake`.
Kedua blok **WAJIB** menambah `risk:` (D8) — kalau cuma satu, fitur yang dibuat lewat jalur lain kehilangan field. (Catatan: M1 — bila dijalankan — menambah `epic`/`depends_on` ke blok yang sama; kontrak urutan = `sensitivity` → [M1 fields] → `risk` di akhir. M7 di sini hanya menambah `risk`.)
- **Staleness audit (8 pembaca feature.yaml):** field `risk:` di-CIPTAKAN 2 pembuat (intake/feature) & di-BACA 1 konsumen baru (build, §4c). 5 pembaca lain TAK perlu diedit — `render-docs` tak merender `risk` (cermin `sensitivity`/`risks.md` tak dirender, §7); `ask`/`breakdown`/`debt`/`drop` baca field LAIN (`status`/`sensitivity`/dll) → menambah satu key YAML `risk:` **inert** bagi mereka (parser YAML abaikan key yang tak dibaca). Tak ada edit di kelima pembaca itu.

### 4b. `intake` — usulkan `risk` + auto-floor (penulis usulan)
- `intake/SKILL.md` step 1 (creation): tambah baris `risk: normal` ke blok feature.yaml (§3).
- `intake/SKILL.md` step 7 (usulan sensitivity): tambah klausa **risk** SETELAH klausa sensitivity existing — "**Usulkan `risk`** (`low|normal|high`): seberapa berbahaya bila build keliru (luas perubahan, destruktif/irreversible, sentuh fondasi). **Floor:** bila usulan `sensitivity` memuat `payments`/`pii` → `risk` minimal `high` (HARD, tak bisa diturunkan selama sensitivity non-kosong). Tulis ke `feature.yaml` `risk:`. Advisory: default `normal` bila tak yakin; user konfirmasi di gate." Ditampilkan bersama usulan sensitivity (step 7 sudah "Tampilkan ... usulan sensitivity → minta approve").
- **Anchor (verbatim disk):** `**Usulkan tag `sensitivity`** dari isi `business.md` (heuristik):` — sisip klausa risk SETELAH kalimat sensitivity+compliance (baris 52), **bukan** renumber step.

### 4c. `build` — baca `risk` + `--unattended` cadence (konsumen baru)
- `build/SKILL.md` step 1 (baca state + DETEKSI mode): build sudah baca `feature.yaml status: active` (baris 15). Tambah DUA hal di step 1 — (1) baca `risk`, (2) **deteksi mode unattended** (krusial: tak ada parser flag CLI di plugin mana pun — trigger build = bahasa-natural, jadi mode HARUS dikenali dari NL request, bukan token literal). **Anchor (verbatim disk):** `**Manifest work-item HARUS aktif:** `feature.yaml` `status: active` (work-item `features/<fitur>/`) **ATAU** `fix.yaml` `status: open`/`diagnosed``. Tambah sub-klausa: "Bila work-item fitur, baca juga `feature.yaml` `risk:` (`low|normal|high`, default `normal` bila absen — degrade) untuk cadence gate step 6. **Deteksi mode unattended:** bila trigger memuat token `--unattended` ATAU user menyatakan maksud tanpa-pengawasan (mis. `build <fitur> unattended`, `jalanin yang aman tanpa aku`, `mode tanpa pengawasan`) → set mode unattended untuk run ini (ephemeral, per-run; D3). Default = attended. Mode unattended HANYA berefek di step 6 untuk work-item fitur (fix selalu attended, D7)." Work-item fix tak punya `risk` (D7).
- `build/SKILL.md` step 6 (Gate per segmen): tambah **klausa unattended** ke gate yang ADA (sisip, **bukan** gate baru/renumber). **Anchor (verbatim disk):** heading `### 6. Gate per segmen (mode A adaptif)` + kalimat pertama `Semua task satu segmen (default **app × milestone**) `done` → **BERHENTI**: tampilkan diff segmen + hasil test + "dibangun vs task" + **challenge checklist** ...`. Tambah klausa: "**Mode unattended (opt-in, hanya work-item fitur):** bila mode unattended terdeteksi di step 1 (token `--unattended` atau maksud NL tanpa-pengawasan) DAN `feature.yaml` `risk` ∈ {`low`,`normal`} (absen di-treat `normal`) DAN segmen ini test-ijo + 'dibangun vs task' COCOK (tak ada penyimpangan) → **auto-approve** segmen (catat ringkasan, lanjut loop tanpa stop user). **HARD floor — TETAP STOP walau unattended:** `risk: high`, task `migrate` (step 3), `needs_human` (step 2), `blocked` (step 5), ATAU penyimpangan-dari-maksud (jalankan disiplin fix embed seperti biasa). Catatan struktural: floor `migrate`/`needs_human`/`blocked` di-tegakkan di step 2/3/5 SEBELUM loop sampai ke gate step 6, jadi klausa unattended step 6 secara struktural tak mungkin auto-approve segmen yang punya floor-task belum-tuntas (D5). Mode unattended MELONGGARKAN cadence step 6 yang ada — BUKAN gate baru; ia tak pernah menyentuh Security Gate `ship`/migrate/needs_human. Tanpa mode = perilaku default (stop tiap segmen)."
- `build/reference.md` §D (Cadence gate): tambah bullet `--unattended` SETELAH bullet existing. **Anchor (verbatim disk):** bullet `- **Fitur 1-app** → ciut jadi 1 gate.` — sisip bullet baru SETELAHNYA: "- **`--unattended` (opt-in, fitur saja):** segmen ber-tier `risk: low`/`normal` yang ijo + tak-menyimpang → auto-approve (lanjut tanpa stop). HARD floor tetap STOP: `risk: high` / `migrate` / `needs_human` / `blocked` / penyimpangan. Melonggarkan cadence ini, bukan menambah gate; tak menyentuh Security Gate `ship`. Default (tanpa flag) = stop tiap segmen."
- `build/SKILL.md` frontmatter `description:` — **WAJIB tambah penyebut `--unattended` ke daftar trigger** supaya mode dapat ditemukan (discoverability). Tanpa ini, klausa unattended step 6 jadi teks mati: tak ada surface yang mengiklankan mode & model tak punya instruksi mengenalinya dari NL. **Anchor (verbatim disk):** trigger list `Trigger — "build <fitur>", "implement <fitur>", "kerjain <fitur>".` — sisip varian unattended SETELAH `"kerjain <fitur>"`, mis. `Trigger — "build <fitur>", "implement <fitur>", "kerjain <fitur>", "build <fitur> unattended" (mode tanpa pengawasan — auto-approve segmen risk rendah, lihat step 6).`. **BUG-GUARD colon-space:** penjelasan dalam kurung pakai em-dash, **tanpa** `: ` (token `--unattended` itu sendiri aman: tak ada spasi setelah titik-dua); verifikasi pasca-edit tak ada `: ` di description. Description ringkasan-fungsi tak diubah — hanya daftar trigger di-tambah satu varian. (Pasangan: deteksi NL di step 1 mengaktifkan mode walau user tak ketik token persis; trigger di sini membuatnya discoverable.)

### 4d. `fix` — TIDAK disentuh (D7)
fix selalu attended. Build step 6 unattended-clause cek "work-item fitur" → fix-build (work-item `fixes/<id>/`) tak pernah masuk jalur auto-approve. Tak ada edit di `fix/SKILL.md`/`fix/reference.md`/`fix.yaml`.

## 5. Generik (jaminan lintas-produk)

- `risk: low|normal|high` = tier universal lintas domain (bukan ecommerce-specific); tak meng-hardcode jurisdiksi/stack.
- `--unattended` = mekanik build generik (longgarkan cadence segmen rutin); tak mengasumsi jenis fitur.
- Auto-floor menumpang `sensitivity` yang sudah generik (`payments`/`pii`).
- **Degrade-anggun (SATU aturan, selaras §6/D8):** `risk:` absen = di-treat `normal` (BUKAN `low`; fail-safe ke arah lebih banyak review, D2). Konsekuensi: tanpa flag → attended penuh (stop tiap segmen) sama seperti `risk: normal`; dengan `--unattended` → segmen ijo+tak-menyimpang auto-approve persis seperti `risk: normal` eksplisit (HARD floor `migrate`/`needs_human`/`blocked`/`high`/penyimpangan tetap STOP). Artinya fitur yang **lupa** di-tag default ke auto-under-flag — disengaja & konsisten dengan fail-safe D2 (normal, bukan low). Tak pernah error.

## 6. Edge case & degrade

| Kasus | Perilaku |
|---|---|
| build tanpa `--unattended` | Stop tiap segmen seperti sekarang (default). `risk` cuma ditampilkan di header gate (informatif). Zero churn. |
| `--unattended` + `risk: low`/`normal` + segmen ijo + cocok | Auto-approve, lanjut loop tanpa stop user. Ringkasan dicatat. |
| `--unattended` + `risk: high` | SELURUH segmen TETAP STOP (HARD floor D5). Flag efektif no-op untuk fitur high. |
| `--unattended` + segmen punya task `migrate` | STOP di migrate (build step 3, destruktif) walau `risk: low` (D5). |
| `--unattended` + task `needs_human`/`blocked` | STOP (build step 2/5) walau `risk: low` (D5). |
| `--unattended` + "dibangun vs task" MELESET (penyimpangan) | STOP + jalankan disiplin fix embed (build step 6 existing) walau `risk: low` (D5). |
| `sensitivity: [payments]` tapi user usul `risk: low` | intake tolak — floor `high` (D4); usulan dinaikkan ke `high`, user konfirmasi. |
| `feature.yaml` tanpa `risk:` (fitur lama / brownfield) | Build degrade = `normal` (default, fail-safe). Attended penuh tanpa flag; dengan flag, `normal` ⇒ auto (kecuali floor). Tak error. |
| Fix lane (`--unattended` tak berlaku) | fix selalu attended (D7); build unattended-clause cek work-item fitur → fix-build tak masuk jalur auto. |
| `risk` value tak dikenal (typo, mis. `medium`) | Build degrade ke `normal` + ingatkan user perbaiki (jangan crash; cermin degrade build migrate-tanpa-kind step 3). |
| Fitur 1-app 1-milestone + `--unattended` + `risk: low` | Segmen tunggal auto-approve (ciut 1 gate, reference §D). Tetap kena floor bila ada migrate/blocked. |

## 7. Parent-spec amendments (`docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`)

> **Catatan completeness:** §9 (Skills) **tidak punya** subsection `### build` tersendiri (lompat dari `plan` ke `ship`) — verified `grep` heading §9 = ...plan→ship. Maka cadence gate build hidup di **§12 lifecycle** (flow line 245-246) + **§11 anti-yes-man** (challenge checklist line 237) + **§17 komponen**. M7 surface parent-spec **tipis** (mostly feature.yaml metadata) — ini jujur, bukan kelalaian.

- **§7 control-tree (anchor verbatim, line 79):** `│       ├── feature.yaml  # status + metadata` — opsi A (minimal): biarkan ("metadata" sudah memayungi `risk`). Opsi B (eksplisit): ubah komentar → `# status + metadata (sensitivity, risk M7)`. **DIPUTUSKAN opsi A** (tree komentar ringkas; field detail di §17/spec ini) — tak edit tree. (Bila author mau eksplisit, opsi B aman: anchor unik, tanpa `: `.)
- **§12 Lifecycle — "Invarian platform & sensitivity" (anchor verbatim, line 259):** kalimat sensitivity diakhiri pointer `Lihat spec `2026-06-01-platform-invariants-security-gate-design.md`.` (paragraf ini memakai pola "Lihat spec ..." — jaga paritas). Sisip SETELAH kalimat sensitivity (sebelum/sesudah pointer existing, di paragraf yang sama): "`intake` juga mengusulkan `feature.yaml` `risk` (`low`/`normal`/`high`; sensitivity non-kosong → floor `high`) yang menyetir **cadence approval** `build` saat mode unattended (M7) — axis terpisah dari `sensitivity`. Lihat spec `2026-06-06-m7-graduated-autonomy-design.md`." (Sisip kalimat di paragraf yang sama, **bukan** subsection/renumber; tag `(M6)`/`(M7)` inline = preseden parent line 231.)
- **§17 Komponen (anchor verbatim, line 307):** `- **Knowledge (`control/`):** `workspace.yaml` (apps[] + packages[]) · `business/` · ...` — TIDAK disentuh (knowledge dirs tak berubah). **Skills (21) TIDAK berubah** (line 304 — M7 tak menambah skill; `--unattended` = flag, bukan skill). **Rules TIDAK berubah** (line 306 — M7 tak menambah rule; logika cadence inline di build SKILL/reference, tak butuh shared-rule karena single-consumer = build). Verifikasi: skill-count tetap **21**, rules tetap **5**.
- **§9 `ship` gate (line 211) — TIDAK disentuh:** Security Gate tak berubah (M7 tak menyentuh ship/security-critic; unattended cuma build-segment).

**TAK disentuh (eksplisit):** skill-count (**21**), rules (**5**), `plugin.json`, `marketplace.json`, README, §9 ship gate, `security-critic`, `ship`, `fix`/`fix.yaml`, `breakdown`/`tasks.yaml` skema (per-fitur risk, bukan per-milestone — D6), `render-docs` (risk tak dirender — cermin preseden sensitivity/risks.md tak dirender), `init` (feature.yaml di-generate, tak ada template), tag `sensitivity` mekanik (M7 cuma BACA untuk floor, tak ubah).

> **Amendemen pasca-spec (lapisan lapor-keluar / notifikasi unattended):** scope M7 di atas DIPERLUAS dengan kanal lapor-keluar agar unattended bisa ditinggal. Ini MENYENTUH induk §8 repo-tree — `template/.claude/` kini memuat `hooks/` (`on-stop.sh`, `on-permission.sh`) + `settings.json` memuat blok `hooks`. Prasyarat harness (allowlist `permissions.allow`) + rem run-level (circuit breaker + cap volume) juga ditambahkan ke build reference §D, dan mekanik notifikasi penuh ada di build reference §G. `init` menyalin `.claude/hooks/` + memasang `.gitignore` (`notify.sh`/`.unattended*`). Gate/ship/security TETAP tak tersentuh.
>
> **Amendemen lanjutan (outer-loop driver — unattended berkelanjutan lintas-sesi):** `build` kini menulis header mesin `outcome: continue|done|halt` (+`done:`/`pending:`/`reason:`) di baris pertama `last-run.md` (build reference §G). Driver membaca header itu untuk lanjut/stop — dua engkol: `template/.claude/drive.sh` (bash, ter-ship: proses `claude -p` fresh tiap putaran + backstop nol-kemajuan/waktu, tak pernah restart `halt`) dan `/schedule` (batch terjadwal cloud). Resep + aturan aman di build reference §H baru. `init` salin+chmod `drive.sh`. Driver menumpang floor §D + notif §G; nol pelonggaran gate, tak ada auto-merge/ship (`done` = "siap di-`ship`", `ship` tetap attended).
>
> **Amendemen lanjutan (cap-volume: hitung-task → budget bobot):** rem `cap volume` (§D) yang semula "max N **task** per run" diganti jadi **budget BOBOT** — tiap task ber-bobot 3/2/1 (berat: `mockup:`/`unit: integration`/`files`>4; sedang: `files` 3–4; enteng: selainnya); satu run berhenti **look-ahead** sebelum total bobot lewat budget (default 10), task PERTAMA tiap run selalu jalan (jamin min 1 task/run). Alasan: jumlah task ≠ jumlah token (10 task berat bisa = ratusan-ribu token), satuan bobot lebih dekat ke beban context sebenarnya → tiap proses `claude -p` fresh tetap ramping. Operatif di build reference §D; §H + komentar `drive.sh` disesuaikan. `breakdown`/`tasks.yaml` skema TAK berubah (bobot diturunkan di build dari field yang sudah ada).

## 8. Honesty-note (advisory vs gate — preseden M6 §1)

- **build step 6 + reference §D (tempat logika cadence jalan):** `--unattended` **MELONGGARKAN** cadence gate yang ADA untuk segmen `risk` rendah — **BUKAN gate baru, BUKAN auto-pipeline tanpa rem**. Default (tanpa flag) = stop tiap segmen (perilaku sekarang). HARD floor (`risk: high` + `migrate` + `needs_human` + `blocked` + penyimpangan) **tetap STOP** — review per-app untuk hal berbahaya tak dikikis (menjaga value-prop produk bayar). Tulis jujur di kedua surface.
- **intake step 7 (tempat risk diusulkan):** `risk` = usulan + auto-floor (advisory untuk tier rendah; HARD untuk floor sensitivity). Default `normal` bila tak yakin (fail-safe ke lebih banyak review). User konfirmasi di gate.
- **build step 1 (tempat risk dibaca):** `risk` dibaca informatif walau tanpa `--unattended` (ditampilkan di header gate) — tapi efek cadence HANYA aktif dengan flag (jangan klaim build berubah perilaku default).
- **Anti over-claim:** M7 tak menyentuh ship/security/migrate/fix. Klaim "graduated autonomy" terbatas ke **build-segment approval untuk fitur, opt-in, tier rendah**. Jangan klaim lebih.

## 9. Self-review checklist awal

- [ ] **D1 axis terpisah** didokumentasikan eksplisit (risk→build cadence, sensitivity→ship depth) — bukan extend sensitivity.
- [ ] `risk:` ditambah ke **KEDUA** blok feature.yaml creation (`intake/SKILL.md` step 1 + `feature/SKILL.md` step 1) — identik, tak drift.
- [ ] **deteksi mode unattended (mustFix):** build step 1 mengenali mode dari token `--unattended` ATAU maksud NL tanpa-pengawasan (bukan token literal saja — tak ada parser flag CLI di plugin). Step 6 mengacu "mode terdeteksi di step 1", bukan "dipanggil --unattended".
- [ ] **discoverability (mustFix):** `--unattended` ditambahkan ke daftar trigger di `build` description supaya mode bukan teks mati. Colon-space aman (token tanpa spasi-setelah-titik-dua; kurung penjelas pakai em-dash).
- [ ] **colon-space guard:** `risk: normal` value bersih (tak ada `: ` di value); komentar inline pakai em-dash/kurung. Cek juga build description (trigger varian unattended) — tak ada `: ` bocor.
- [ ] **no-renumber:** intake step 7 (klausa risk = sisip setelah sensitivity), build step 1 (sub-klausa risk + deteksi mode), build step 6 (klausa unattended = sisip ke gate ada), reference §D (bullet baru). Tak ada step skill di-renumber.
- [ ] **HARD floor lengkap (D5):** unattended skip-clause eksplisit menyebut `risk: high` + `migrate` + `needs_human` + `blocked` + penyimpangan TETAP STOP.
- [ ] **auto-floor (D4):** intake step 7 menyatakan sensitivity `payments`/`pii` → risk ≥ `high` HARD.
- [ ] **fix tak disentuh (D7):** build unattended-clause cek work-item fitur; tak ada edit fix.yaml/fix SKILL/reference.
- [ ] **default safe (D2/D8):** `risk` default `normal`; tanpa `--unattended` = perilaku lama; degrade absen/typo → `normal` fail-safe.
- [ ] **parent-spec:** §12 line 259 sisip kalimat risk; §7 tree opsi A (tak edit); skill-count **21** & rules **5** TAK berubah (verifikasi tak ada churn §17).
- [ ] **mis-aimed-pointer:** tiap anchor di §4 nge-quote teks DISK SEKARANG (intake L52, build L15/L46-47, reference §D `- **Fitur 1-app** → ciut jadi 1 gate.`, parent L259/L79). Edit-map before→after = dokumentasi, bukan pointer live.
- [ ] **honesty (§8):** "melonggarkan cadence, bukan gate baru" ditulis di build step 6 + reference §D (tempat logika jalan); tak klaim ship/security berubah.
- [ ] **generik:** tier & unattended tak ecommerce-specific; degrade tiap titik.
- [ ] **scope-flags (lihat handoff):** per-milestone risk (M7-FLAG-A) ditolak demi fix-light (D6); batch/sticky cross-app (M7-FLAG-B) DILARANG; risk di fix.yaml (M7-FLAG-C) ditolak (D7). Tak diam-diam balloon.

---

## Amendemen 2026-06-18 — D4 dipersempit (decouple risk/sensitivity)

D4 (floor borongan `sensitivity non-kosong → risk:high`) **dipersempit** ke
`payments-movement → risk:high`; `pii` read-only **tidak lagi** memaksa floor —
mengembalikan ke niat **D1** (risk = blast-radius build; sensitivity = kedalaman
ship). Ditambah floor-scan diff deterministik di build + setup prasyarat
unattended (notify/allowlist) via wire/upgrade + backstop `drive.sh`.

Spec lengkap: `docs/superpowers/specs/2026-06-18-unattended-risk-floor-decouple-design.md`.
Plan: `docs/superpowers/plans/2026-06-18-unattended-risk-floor-decouple.md`.
(Sejarah D4 di atas DIPERTAHANKAN — ini catatan menyusul, bukan tulis-ulang.)

---

## Amendemen 2026-08-27 — gate ditunda ke antrian review (`gates.yaml`)

Operator lapor build tetap terhalang kehadiran manusia (`risk:high` = halt ronde-1;
floor-scan + `migrate` = stop-the-world; `drive.sh` mati di `halt`). Perubahan:

- **Gate ditunda, bukan stop.** Gate memeriksa kode yang sudah jadi → persetujuan
  diantrikan ke `<work-item>/gates.yaml` (`queued|approved|revised|auto`), build lanjut
  membangun di atasnya. Tiga kelas titik-manusia: A gate review (ditunda) · B blocker
  (subtree nunggu via `needs_human`/`blocked` + `hold:`) · C auto.
- **`risk:high` BUKAN kill-switch** — = semua gate segmen diantrikan. D4/2026-06-18 tetap
  berlaku untuk floor payments-movement, kini non-blocking.
- **Migrate by `kind`:** additive auto-apply (opt-in allowlist `wire` 5.5 + cross-check DDL);
  destructive/backfill hold `needs_human`.
- **`outcome: review`** baru; `halt` hanya abnormal. `ship` menolak selama ada `queued`.
- **Arahan "JANGAN batch/sticky-approve" DIPERTEGAS, bukan dibatalkan:** approve tetap
  per gate (tak sticky); yang di-batch hanya WAKTUNYA (drain pagi). Lintas-app sticky
  tetap dilarang (M7-FLAG-B).

Spec: `docs/superpowers/specs/2026-08-27-build-deferred-gate-review-queue-design.md`.
Plan: `docs/superpowers/plans/2026-08-27-build-deferred-gate-review-queue.md`.
