# context-vault — UI-Contract + Generate-in di `plan` — Design Spec

- **Tanggal:** 2026-06-07
- **Status:** Draft disetujui untuk masuk tahap perencanaan implementasi (hasil brainstorming, semua keputusan perilaku terkunci)
- **Terkait:** spec induk `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§4 just-in-time knowledge + "satu sumber kebenaran banyak proyeksi", §9 skill `plan`/`breakdown`/`build`); spec **mockup-thread** `docs/superpowers/specs/2026-06-04-mockup-thread-design-fidelity-design.md` (Spec A — jalur byte-opaque mockup yang spec ini DIBANGUN DI ATASnya); spec **design-system bring-up** `docs/superpowers/specs/2026-06-05-design-system-bring-up-design.md` (fondasi visual yang dipakai jalur generate); `plugin/skills/plan/SKILL.md` (tempat UI-Contract + 3-jalur `Mockup:` dipasang); `plugin/skills/breakdown/SKILL.md` (coverage check); `plugin/skills/build/SKILL.md` (konsumen hilir, tak diubah); skill **`frontend-design`** (existing di environment — dipinjam jalur generate).
- **Asal:** pertanyaan pengguna (FE dev) atas flow `feature`: (1) kalau user **tak punya** design dan minta digenerate — belum didukung; (2) alur FE natural butuh tahu **data/field apa** dulu sebelum bikin UI — belum ada step-nya. Contoh konkret: fitur `auth` → `register` butuh field apa (email/password/name?), bisa login Google/Facebook? Dua hal ini tak pernah dipermukaan-kan sebagai artifact, dan generate UI dari design-system existing belum di-wire ke pipeline.
- **Grounding:** dibaca langsung dari file nyata. **(gap discovery)** `plans/<app>.md` cuma `Model/Schema·API/Komponen·Lokasi·Mockup·Test` (`plan/SKILL.md:48-55`); tak ada artifact UI-sentris yang nyatakan field/provider/state sebuah layar. `intake` eksplisit melarang Q&A teknis/UI (`intake/SKILL.md:28-29`) → keputusan provider (Google/Facebook) hanya kebawa kalau kebetulan muncul di Q&A bisnis. **(gap generate)** slot `Mockup:` cuma 2-jalur — punya → pakai; tak punya → minta, atau (sengaja tak punya) degrade lanjut-tanpa (`plan/SKILL.md:42`); pas tak ada mockup, `build` membangun UI ad-hoc/ngarang (mockup-thread spec §3 Non-Tujuan: greenfield tanpa pointer-pola = di luar scope, implementer membangun ad-hoc). **(kapabilitas ada, belum di-wire)** environment punya Figma MCP + skill `frontend-design`, tapi tak satu pun dipanggil dari flow context-vault.

---

## 1. Ringkasan

Flow `feature` menangani UI lewat dua mekanisme yang sudah ada: **`design-system`** (bring-up fondasi visual — token + komponen primitif, sekali per gaya) dan **mockup-thread/Spec A** (mockup yang **diserahkan pengguna** di-thread byte-opaque `plan → breakdown → build` lalu direproduksi). Keduanya menganggap **design datang dari luar**. Dua celah tersisa:

- **Gap discovery (gap #2).** Tak ada artifact yang nyatakan "layar ini butuh field/provider/state apa". Field implisit di `Model/Schema`+`API/Komponen` (BE-sentris); keputusan provider (login Google/Facebook) tak dipermukaan-kan. FE dev tak punya kontrak data untuk *menyetir* design — harus nebak.
- **Gap generate (gap #1).** Pas pengguna **tak punya** mockup, tak ada jalur generate; slot `Mockup:` degrade ke kosong dan `build` ngarang layout — justru masalah yang Spec A perbaiki, tapi Spec A hanya berlaku kalau mockup **ada**.

Spec ini menutup keduanya dengan **mengupgrade satu titik** — keputusan slot `Mockup:` di skill `plan` — **tanpa skill baru, tanpa file artifact baru, tanpa pipa hilir baru**:

- **UI-Contract** (§4): section baru di `plans/<app>.md`, untuk app peran-UI saja. Diturunkan dari `business.md` (provider) + `Model/Schema` + `API/Komponen`. **Selalu** dibuat & ditampilkan rapi di gate `plan` — jadi pengguna dapat daftar field/provider/state **sebelum** memikirkan tampilan. Inilah "kontrak data UI".
- **Slot `Mockup:` jadi 3-jalur** (§5): (a) **bawa mockup** → simpan + **cross-check** vs UI-Contract; (b) **generate** → dispatch `frontend-design` dengan UI-Contract + token design-system → mockup ke `mockups/` → gate eyeball; (c) **degrade** → kosong, seperti sekarang.
- **Cross-check advisory** (§6): konfirmasi-manusia di gate, **tidak** mem-parse mockup → opacity byte-opaque mockup terjaga.
- **Hilir** (§7): `breakdown` tambah satu coverage-check (UI-Contract→task); `build` otomatis dapat konteks state dari section yang sama. `build` dispatch & gate **tak berubah**.

Prinsip inti: **field otoritatif hidup di teks UI-Contract (bukan mockup); mockup tetap byte-opaque; generate hanya mengisi lubang yang tadinya degrade, lewat skill `frontend-design` yang dipinjam — bukan kapabilitas baru di plugin.**

## 2. Masalah

- **M1 — Discovery: nol artifact UI-sentris.** `plans/<app>.md` punya `Model/Schema` (model data BE) + `API/Komponen` (identitas komponen, bukan kebutuhan datanya). Tak ada yang nyatakan "RegisterForm butuh field email/password/name, aksi submit + Continue-with-Google, state idle/loading/error". FE harus menurunkan ini manual dari beberapa slot — atau lupa (field ketinggalan, provider tak diputuskan).
- **M2 — Keputusan provider menguap.** "Login Google/Facebook?" adalah keputusan **scope bisnis** + implikasi teknis (OAuth). `intake` melarang Q&A teknis, tak ada checklist yang memaksa nanya provider. Kalau tak kebetulan muncul di Q&A bisnis → tak terekam → design & build menebak.
- **M3 — Generate: lubang degrade.** Slot `Mockup:` tak-ada-mockup → `build` membangun ad-hoc. Pengguna yang **memang tak punya** design (atau ingin sistem bikinkan) tak punya jalur; hasilnya layout ngarang yang lolos semua gate fungsional sampai eyeball manusia.
- **M4 — Chicken-and-egg pengguna.** Tanpa kontrak data: "design dulu" = risiko field tak lengkap (Claude design tak tahu kebutuhan data); "feature dulu" = `plan` jalan tanpa design. Pengguna terjebak. (Akar yang spec ini larutkan: kontrak data adalah **output** flow yang lahir di `plan`, jadi urutan benar = `/feature` dulu → dapat kontrak → baru design/generate.)
- **M5 — Kapabilitas nganggur.** `frontend-design` + Figma MCP ada di environment tapi tak pernah dipanggil pipeline → generate "pakai design system yang ada" mustahil lewat flow.

Akar: pipeline menganggap design selalu datang jadi dari luar. Yang hilang adalah (a) **artifact kontrak data** yang menjembatani business→design, dan (b) **jalur generate** saat design belum ada.

## 3. Tujuan & Non-Tujuan

**Tujuan:**
- **UI-Contract** (§4): section di `plans/<app>.md` untuk app peran-UI; field+provider+state; selalu ditampilkan rapi di gate `plan` (siap di-copy ke tool design eksternal).
- **Slot `Mockup:` 3-jalur** (§5): bawa-mockup(+cross-check) / generate / degrade — di satu keputusan yang sudah ada.
- **Generate** (§7) via skill `frontend-design` + token/komponen `design-system.md` → mockup ke `mockups/` → gate eyeball.
- **Cross-check advisory** (§6): nangkep field ketinggalan tanpa mem-parse mockup.
- **Hilir minimal** (§8): satu coverage-check di `breakdown`; konteks state ke `build` gratis (baca section yang sama).
- **Degrade-ke-noop** (§9): app non-UI nol biaya; app UI tapi user skip = perilaku sekarang.

**Non-Tujuan (diserahkan ke spec/iterasi lain):**
- **Bukan generate-langsung-jadi-kode-produksi.** Hasil generate = **mockup-reference**; `build` tetap implement ulang via TDD (jaga disiplin gate+test & model tunggal `build`=sumber kebenaran kode). Optimasi "generate langsung ke implementasi" = future.
- **Bukan design-system bring-up.** Token/komponen primitif tetap urusan skill `design-system`. Generate **mengonsumsi** `design-system.md`, tak membuatnya. App UI belum bergaya → `fanout` sudah memicu `design-system` lebih dulu (mekanisme existing).
- **Bukan parsing/prozaing isi mockup.** Mockup tetap byte-opaque. Cross-check = konfirmasi-manusia/glance advisory, bukan ekstraksi data.
- **Bukan multi-screen orchestration otomatis.** UI-Contract di-elicit per app/layar oleh judgment `plan`; tak ada mesin penemuan-layar otomatis.
- **Bukan verify render-compare otomatis.** Konsisten Spec A: verifikasi generate = eyeball manusia di gate (§7), bukan screenshot-diff.
- **Bukan skill/artifact/pipa baru.** Semua perubahan = edit `plan/SKILL.md` (+ reference bila perlu) + satu baris `breakdown`.

## 4. UI-Contract — artifact discovery (gap #2)

**Lokasi.** Section baru bernama `UI-Contract:` di dalam `control/features/<fitur>/plans/<app>.md`, **hanya** untuk app peran-UI (`type` ∈ {`fe`,`fullstack`} yang fitur ini memunculkan/mengubah permukaan UI-nya). App `be`/non-UI → section tak muncul (degrade, §9). **Keputusan: section, bukan file terpisah** — satu sumber kebenaran, `breakdown`/`build` sudah membaca `plans/<app>.md`, nol pipa baru, nol risiko drift file-kontrak vs plan.

**Sumber turunan.** `plan` menurunkan UI-Contract dari:
- **`business.md`** → keputusan provider/kebijakan (mis. "register pakai email + Google").
- **`Model/Schema`** (slot existing) → field yang punya backing data (email, password, name).
- **`API/Komponen`** (slot existing) → komponen/endpoint yang terlibat (RegisterForm, POST /register).

**Format** (di `plans/<app>.md`, sebagai section setelah `API/Komponen`):
```
UI-Contract:
  <Komponen/Layar>:
    fields  : <nama(req|opt, constraint ringkas)>, ...
    actions : <aksi + provider, mis. submit, "Continue with Google">
    states  : <idle / loading / error(<kasus>) / success / empty ...>
    shows   : <data yang ditampilkan — untuk layar baca/list; opsional>
```
Contoh (`auth`/`web`):
```
UI-Contract:
  RegisterForm:
    fields  : email(req), password(req,min8), name(req)
    actions : submit, "Continue with Google"
    states  : idle / loading / error(email-taken) / success
```

**Kapan dibuat.** SELALU, lebih dulu dari keputusan slot `Mockup:` — supaya berfungsi di ketiga jalur (§5): jadi spec yang dipenuhi mockup (jalur a), input generate (jalur b), dan tetap konteks build (jalur c). **Ditampilkan rapi di gate `plan`** sebagai blok mandiri yang bisa pengguna **copy** ke tool design eksternal (memenuhi kebutuhan "1 file/kontrak yang bisa dibawa" tanpa membuat file baru).

**Idempotent.** Re-run `plan` (mis. round-trip case design-sendiri, §5a) yang sudah punya `UI-Contract:` → tidak menghitung ulang dari nol; reuse yang ada kecuali `business.md`/`Model/Schema`/`API/Komponen` berubah.

## 5. Slot `Mockup:` jadi 3-jalur (gap #1)

Bagian yang **sama untuk ketiga jalur**: `plan` sudah menulis `UI-Contract:` (§4) dan menampilkannya. Lalu keputusan slot `Mockup:` (per app UI) bercabang:

### 5a. Jalur "bawa mockup" (mockup sudah jadi / design sendiri)
Perilaku Spec A + cross-check baru:
- Pengguna menyerahkan mockup (HTML/CSS/gambar/URL Figma) → simpan verbatim ke `control/features/<fitur>/mockups/` (Spec A) → **cross-check vs UI-Contract** (§6) di gate → isi pointer `Mockup:`.
- **Round-trip "design sendiri":**
  - *Sesi sama:* `plan` menampilkan UI-Contract → **menunggu di gate** → pengguna design di tool eksternal → paste/serahkan hasil → cross-check → isi `Mockup:`.
  - *Sesi beda:* jalankan **`/plan <fitur>`** lagi (modular, tak menarik `intake`/`fanout`) → serahkan mockup → UI-Contract sudah ada (idempotent) → cross-check → isi. Selama `breakdown` belum jalan, tak ada yang basi (aturan staleness existing tetap berlaku bila sudah).

### 5b. Jalur "generate" (tak punya mockup, minta dibikinkan)
Lihat §7. Hasil = mockup-reference di `mockups/`, gate eyeball, lalu isi `Mockup:`. Setelah terisi, identik dengan jalur 5a dari sisi hilir.

### 5c. Jalur "degrade" (sengaja tak mau mockup)
Perilaku sekarang persis: `Mockup:` kosong, lanjut. `build` membangun ad-hoc — tapi kini **dengan konteks UI-Contract** (state/field) di `plans/<app>.md`, jadi lebih terarah dari sebelumnya.

> Catatan: jalur dipilih pengguna eksplisit di gate `plan`. Default tidak otomatis-generate (hindari biaya tak diminta); `plan` menawarkan ketiganya saat app UI tak punya mockup tersimpan.

## 6. Cross-check (advisory, opacity terjaga)

Saat jalur 5a, `plan` **tidak** mem-parse mockup menjadi data terstruktur (mockup tetap byte-opaque sepanjang pipeline — invariant Spec A). Yang dilakukan:
- Di gate, **tampilkan UI-Contract di samping pointer mockup** + minta pengguna konfirmasi coverage: *"pastikan mockup memuat: email, password, name, Continue-with-Google. `name` kelihatannya belum ada — tambahkan?"*
- Bila mockup berupa **teks** (HTML/CSS), `plan` boleh melakukan **glance ringan** sebagai bantuan deteksi (mis. cari label/input yang tampak hilang) — tetap **advisory + dikonfirmasi manusia**, bukan diekstrak/disimpan.
- Hasil cross-check **tidak** ditulis sebagai prosa ke `plans/<app>.md` (hanya UI-Contract + pointer Mockup yang ditulis). Field otoritatif tetap UI-Contract.

Sifat: **advisory, bukan palang.** Pengguna boleh lanjut walau ada selisih (mis. field sengaja di-handle layar lain). Ini menjawab langsung kekhawatiran "field di Claude design ketinggalan".

## 7. Generate (jalur 5b)

- **Pemicu:** pengguna memilih "generate" di gate `Mockup:` untuk app UI tanpa mockup.
- **Prasyarat:** `control/design-system.md` ada & app dalam scope sebuah design system (`Berlaku buat`). Bila belum (app UI belum bergaya), itu sudah dipicu `fanout` → `design-system` lebih dulu (existing); bila tetap kosong, generate degrade ke ad-hoc + peringatan (jangan ngarang fondasi).
- **Dispatch:** `plan` memanggil skill **`frontend-design`** dengan konteks: isi `UI-Contract` + token + inventory komponen dari `design-system.md` + stack app dari `workspace.yaml`. Output = mockup (HTML/CSS — format yang mockup-thread sudah handle; URL/aset Figma sebagai alternatif bila relevan).
- **Persist:** simpan hasil verbatim ke `control/features/<fitur>/mockups/` (penulis = `plan`, konsisten Spec A).
- **Gate eyeball:** tampilkan hasil → pengguna **approve / regen-dengan-arahan** ("tombol Google lebih besar", "rapatkan spacing") / koreksi manual. Approve → isi pointer `Mockup:`.
- **Hilir:** identik jalur lain — `build` tetap reproduksi via TDD (mockup-reference, bukan kode produksi langsung; lihat §3 Non-Tujuan). Karena generate sudah memakai komponen design-system, reproduksi `build` murah & akurat.

## 8. Hilir — `breakdown` + `build` (perubahan minimal)

- **`breakdown`:** tambah **satu coverage-check** sejajar yang sudah ada (Model/Schema→task, mockup→task): *"tiap entri `UI-Contract` (field/aksi/state) ke-cover oleh ≥1 task?"* → tampilkan peta UI-Contract→task di gate. Tujuan: tak ada field/provider/state yang menguap jadi tak-tertangani. (Edit kecil di `breakdown/SKILL.md` §4 Coverage check.)
- **`build`:** **tak diubah.** `build` sudah membaca `plans/<app>.md` (`build/SKILL.md:14`), jadi section `UI-Contract` otomatis masuk konteks implementer → sadar semua state (idle/loading/error), bukan cuma yang kebetulan tergambar di mockup. Dispatch (§B) & gate (§6) Spec A tetap apa adanya.

## 9. Edge case & degrade-ke-noop

- **App non-UI / backend-only** → tak ada `UI-Contract:`, tak ada keputusan `Mockup:` → nol biaya (sama seperti `mockup:`/`actions:` opsional Spec A).
- **App UI tapi pengguna sengaja skip design** → jalur 5c degrade; `UI-Contract` tetap dibuat (murah, jadi konteks build), `Mockup:` kosong.
- **Generate dipilih tapi `design-system.md` kosong** → tak ngarang fondasi: degrade ke ad-hoc + peringatan arahkan `design-system` dulu.
- **`/plan` standalone (bukan via `feature`)** → `business.md` mungkin tipis; provider yang tak ada di `business.md` → `plan` tanya ringan saat menurunkan UI-Contract (tetap dalam batas: keputusan provider adalah scope yang harus eksplisit), atau tandai `?` di `actions` untuk dikonfirmasi.
- **Re-run setelah `breakdown`** → aturan staleness existing (`plan` berubah → ingatkan `breakdown` ulang, yang mempertahankan status task `done`) tetap berlaku; UI-Contract ikut perubahan plan.
- **Cross-check menemukan selisih** → advisory; pengguna boleh lanjut (field bisa sengaja di layar lain). Bukan palang.

## 10. File yang disentuh

```
DI-EDIT    : plugin/skills/plan/SKILL.md          (UI-Contract: section + format; slot Mockup: 3-jalur;
                                                    cross-check advisory; dispatch frontend-design; round-trip)
             plugin/skills/plan/reference.md       (bila detail format/dispatch panjang — buat/perluas)
             plugin/skills/breakdown/SKILL.md      (§4: +1 coverage-check UI-Contract→task)
SINKRON    : docs/superpowers/specs/2026-05-24-...-induk (§9 plan — catat UI-Contract + 3-jalur)
             docs/superpowers/specs/2026-06-04-mockup-thread-... (cross-ref: 3-jalur memperluas slot Mockup:)
DIPINJAM   : skill frontend-design (existing) — dipanggil jalur generate; bukan dimodifikasi
TIDAK BERUBAH: fanout, design-system, build, feature, feature.yaml, business.md, workspace.yaml
SKILL/ARTIFACT/PIPA BARU : ❌ tidak ada
```

## 11. Keputusan terkunci (dari brainstorming)

1. **Opsi 1** ("numpang di `plan`") dipilih atas Opsi 2 (skill `ui-design` terpisah) & Opsi 3 (pecah, generate nanti) — paling nempel filosofi, nutup dua gap sekaligus, permukaan minimal.
2. **UI-Contract = section di `plans/<app>.md`** (pilihan A), bukan file terpisah (pilihan B) — satu sumber kebenaran, nol drift, nol pipa baru; ditampilkan rapi di gate untuk di-copy.
3. **Cross-check dimasukkan** — advisory, konfirmasi-manusia, tak melanggar opacity mockup.
4. **`/feature` dulu, design belakangan** — urutan benar; kontrak data lahir di `plan` sebagai output, melarutkan chicken-and-egg.
5. **Generate = mockup-reference** (build tetap TDD), bukan kode produksi langsung.
6. **Generate via `frontend-design`** (skill existing dipinjam), bukan skill context-vault baru.

## 12. Detail terkunci (resolved dari Open Questions)

1. **Format `UI-Contract` final = `fields / actions / states / shows`** (empat slot §4); `shows` opsional (layar baca/list). Constraint per-field (req/opt, min/max, format) inline di `fields` — TANPA slot `validation`/`a11y` terpisah (hindari over-struktur; a11y dijaga komponen design-system + Web Interface Guidelines saat `build`).
2. **Glance cross-check dibatasi ke heuristik nama-field** untuk mockup teks (deteksi `<input>`/`<label>`/teks tombol yang tampak hilang vs `fields`/`actions`), **selalu dikonfirmasi manusia**, tak pernah disimpan/diprosa-kan. Mockup non-teks (gambar/Figma) → murni konfirmasi-manusia tanpa glance. Opacity terjaga (§6).
3. **Coverage `UI-Contract` di `breakdown` = tampil-di-gate, BUKAN palang** — sejajar coverage `Model/Schema`/mockup yang sudah ada (`breakdown/SKILL.md:24-25`). Selisih disodorkan ke pengguna, tak memblokir.
