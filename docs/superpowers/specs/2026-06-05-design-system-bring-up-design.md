# context-vault — Design-System Bring-Up (greenfield + brownfield) — Design Spec

- **Tanggal:** 2026-06-05
- **Status:** Draft disetujui untuk masuk tahap perencanaan implementasi (hasil brainstorming, semua keputusan perilaku terkunci)
- **Terkait:** spec induk `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§7 model knowledge `control/`, §8 struktur repo, §9 skills, §12 lifecycle, §17 komponen); **Spec A** `docs/superpowers/specs/2026-06-04-mockup-thread-design-fidelity-design.md` (mockup-thread — atom dispatch `build/reference.md §B` yang spec ini PAKAI; §12 = hubungan A→B); pola konduktor `add-package` (`docs/superpowers/specs/2026-06-01-h2-shared-package-design.md`) & `add-integration` (`docs/superpowers/specs/2026-06-01-m5-integrations-design.md`); pola SHAPE hand-authored `control/integrations.md`; pola dua-mode SETUP/CAPTURE `architect` (`plugin/skills/architect/SKILL.md` langkah 2/3a/3b); pola "pinjam mesin `build`" `wire/reference.md §H`.
- **Asal:** test end-to-end pengguna (project board game) yang melahirkan Spec A. Spec A menutup gap design-fidelity untuk project **steady-state** (design system sudah ada di kode → `build` meniru lewat "pointer pola"). Tapi project **dari 0** belum punya design system di kode sama sekali — mockup awal seharusnya jadi sumber fondasi (tokens + komponen primitif), bukan cuma layout per-fitur. Pipeline tak punya fase untuk ini. Spec A §3 (Non-Tujuan) eksplisit menyerahkan kasus greenfield + deteksi UI-surface di `fanout` + auto-prompt di `feature` ke **Spec B** (dokumen ini).
- **Grounding:** dibaca dari current-state pipeline (2026-06-05). `architect` (`SKILL.md`) memutuskan stack + "lib kunci" per app — **tak menangkap bahasa visual**. `wire` (`SKILL.md`/`reference.md`) cuma skeleton teknis (scaffold+DB+wiring+env) — **nol concern design**, dan prinsipnya "delegasi scaffolder, JANGAN mutusin arsitektur" → tak cocok untuk kerja judgment-berat. `add-package` (`SKILL.md`) bisa bikin package `ui-kit` tapi cuma menangkap **kontrak exports**, bukan tampilan (gap capture sama). Dua reviewer (`critic`/`security-critic`, tools `Read/Grep/Glob`) buta-render. Konsekuensi: fitur UI **pertama** di project dari-0 menginvent design system ad-hoc dari mockup-nya → tiap fitur berikut drift.

---

## 1. Ringkasan

Project **dari 0** belum punya design system di kode — token (warna/tipografi/spacing/radius/shadow + **motion**) dan komponen primitif (Button/Input/Card/…) belum ada. Mockup awal yang pengguna serahkan adalah spec visual terkaya untuk fondasi itu, tapi pipeline **tak punya fase** yang menurunkannya jadi design system; akibatnya fitur UI pertama membangun token+komponen ad-hoc dan tiap fitur berikut menyimpang. Spec A (steady-state) mengandalkan komponen yang **sudah ada** di kode — di project dari-0, yang ditunjuk "pointer pola" itu belum ada.

Spec ini menambah **fase bring-up design system**: satu **skill baru `design-system`** (konduktor tipis, kembaran `add-package`/`add-integration`) yang menghasilkan **dua hal**:
- **(a) `control/design-system.md`** — knowledge durable, **multi-section** (satu produk bisa punya N design system), tiap section: scope (app mana yang diatur) + tokens + **motion vocab** + inventory komponen + pointer mockup kanonik. Di-*elicit* by judgment dari mockup (SETUP) atau dari kode existing (CAPTURE) — **bukan** projeksi mekanis (mockup byte-opaque, plugin tak parse).
- **(b) KODE** — token + komponen primitif, dibangun **memakai atom dispatch Spec A** (`build/reference.md §B`: paste/lampir mockup + instruksi reproduksi-visual + model terkuat). Wadah kode mengikuti scope: 1 app → app-local; >1 app se-vibe → satu shared package via `add-package`.

**Dua mode** (simetris `architect`): **SETUP** (app kosong komponen → bootstrap dari mockup, bikin kode) & **CAPTURE** (app sudah punya komponen → dokumentasikan ke `.md` saja, tanpa code-gen).

**Trigger:** `fanout` mendeteksi app ber-permukaan-UI yang **belum diatur** design system mana pun → menandai di `fanout.md`; `feature` auto-invoke `design-system` (persis pola `add-app`/`add-package`/`add-integration`) **sebelum** `plan`. Juga bisa **standalone** (`/design-system`).

Prinsip inti: **design system = satu gaya visual, di-scope ke app yang berbagi gaya itu; di-bootstrap sekali dari mockup (atau di-capture dari kode existing); plugin tetap GENERIC — bahasa visual di-elicit, nol lock-in framework/CSS-lib.**

## 2. Masalah

- **M1 — Nol fase fondasi visual.** `architect` memutuskan stack + "lib kunci" (boleh pilih Tailwind/shadcn) tapi **tak menangkap bahasa visual** (palet, skala, motion). `wire` cuma skeleton teknis — nol concern design. Tak ada langkah yang menurunkan mockup awal jadi token + komponen primitif.
- **M2 — Capture-gap di `add-package ui-kit`.** Bisa men-scaffold package `ui-kit`, tapi cuma kontrak exports — **nol token dikunci, nol tampilan ditangkap**. Persis gap capture Spec A, tapi di level fondasi.
- **M3 — Pointer-pola kosong di greenfield.** Spec A mengandalkan komponen existing yang ditunjuk "pointer pola". Project dari-0 → tak ada yang ditunjuk → implementer membangun primitif ad-hoc dari mockup tiap fitur.
- **M4 — Drift lintas-fitur & lintas-app.** Tanpa design system durable, fitur UI pertama menetapkan token/komponen secara implisit; fitur ke-2 dst (sesi fresh, baca `control/`) tak punya sumber kanonik → menyimpang. Multi-app sebrand → tiap app menginvent salinan → drift lebih parah.
- **M5 — Tak ada rumah untuk motion vocab.** Spec A meminta implementer "BAWA animasi" dari mockup per-fitur, tapi tanpa vocab motion bernama yang durable, easing/durasi di-reinvent tiap fitur → animasi tak konsisten antar-fitur.

Akar: pipeline menangkap **bisnis** (`business/`), **teknis** (`stack`/`conventions.md`), **invarian**, **vendor** (`integrations.md`) — tapi **tak pernah menangkap bahasa visual** sebagai knowledge durable. Mockup awal, spec visual terkaya, tak punya rumah fondasi.

## 3. Tujuan & Non-Tujuan

**Tujuan:**
- **Artifact `control/design-system.md`** (§4): rumah durable design system, multi-section, di-scope per gaya visual.
- **Skill `design-system`** (§5): konduktor dua-mode (SETUP/CAPTURE), mengelola N design system per produk, menanya scope (gaya baru vs ikut existing).
- **Trigger via `fanout` + `feature`** (§6): deteksi UI-surface-belum-bergaya + auto-invoke sebelum `plan`; standalone juga.
- **Bangun kode via atom Spec A** (§7): token + komponen primitif memakai dispatch `build/reference.md §B`; wadah app-local vs shared package (`add-package`) mengikuti scope.
- **Motion vocab + hubungan ke Spec A** (§8): section `Motion` di `.md`; Spec A (`build §B`) merujuknya agar animasi per-fitur konsisten.
- **Generik & dua-mode** (§9): bahasa visual di-elicit; nol lock-in; CAPTURE untuk brownfield (simetris `architect`/`wire`/`extract`).

**Non-Tujuan (Spec B — diserahkan ke iterasi/Langkah lain):**
- **Bukan komposit / page-level.** Scope v1 = **token + komponen primitif** (Button/Input/Card/dst). Layout halaman & komposisi multi-komponen = wilayah **per-fitur Spec A**.
- **Bukan verify render-compare otomatis.** Tak ada subagent render→screenshot→diff, tak ada agent `design-critic`. Verifikasi = **eyeball manusia** (render primitif vs mockup) di GATE — konsisten Spec A (animasi menolak verifikasi screenshot).
- **Bukan critic-wajib.** Tak seperti kunci-invarian (`architect 4.5`, critic mandatory), gate `design-system` = GATE biasa (approve `.md` + eyeball). Design system = keputusan visual, bukan keamanan/fondasi data.
- **Bukan parse/validasi mockup.** Mockup tetap **byte-opaque** (prinsip Spec A); `design-system` membacanya untuk **elicit** token (judgment), tak pernah mem-parse/men-transpile-nya jadi kode.
- **Bukan migrasi otomatis app-local→package.** Bila design system yang awalnya 1-app berkembang scope-nya jadi >1 app, promosi app-local→shared-package adalah **di luar scope v1 & BELUM ada seam-nya** — `fanout PACKAGE NEW` mendeteksi *fitur* yang memperkenalkan kode-bareng, BUKAN *design system* yang tumbuh scope-nya, jadi jalur existing TAK menanganinya. Dicatat sebagai pengembangan berikutnya (§13), bukan diklaim sudah beres.
- **Tak menyentuh `intake`/`business.md`/`workspace.yaml` `stack`.** Bahasa visual bukan bisnis dan bukan stack; ia knowledge baru sendiri (`design-system.md`).

## 4. Artifact: `control/design-system.md`

- **Lokasi:** `control/design-system.md` (level-produk, sejajar `conventions.md`/`invariants.md`/`integrations.md`).
- **Penulis tunggal:** skill `design-system`. Pembaca: `build` (rujuk motion/token saat reproduksi UI per-fitur — §8), `render-docs` (opsional), `ask` (opsional). `fanout`/`feature` cuma membacanya untuk tahu app mana yang **sudah** diatur (deteksi trigger — §6).
- **Multi-section** (persis `integrations.md` yang multi-vendor): satu produk bisa punya **N design system**. Tiap section = satu gaya visual:

```
## <nama design system>            # mis. "web" / "admin" / nama brand
Berlaku buat : [web]               # ATAU [cms, cms-internal] — scope: app yang berbagi gaya ini
Kode di      : web/app-lokal       # ATAU "package <nama>" bila scope >1 app
Tokens       : warna · tipografi · spacing · radius · shadow   # nilai + nama, tech-agnostic
Motion       : easing & durasi bernama (mis. ease-bounce = cubic-bezier(...)/240ms)
Komponen     : Button · Input · Card · …      # inventory primitif yang ada
Mockup kanonik: <pointer ke control/features/<f>/mockups/… ATAU sumber>
```

- **Sifat:** **di-elicit by judgment** (bukan projeksi). Token & motion adalah **nilai konkret + nama** yang tech-agnostic (mis. hex/cubic-bezier), BUKAN snippet CSS/framework. Penerjemahan ke idiom project (CSS vars / theme object / config) dilakukan saat **bangun kode** (§7) oleh implementer, sandar `stack`+`conventions.md`.
- **`Berlaku buat` vs `packages[].consumers`:** `Berlaku buat` (app yang diatur gaya ini; **ditulis `design-system`**) adalah yang **menyetir scan trigger** (§6 — "app belum terdaftar"). Untuk design system ber-package (scope >1 app), `design-system` JUGA mengisi `packages[].consumers` + `mandatory_for` = app scope (carve-out terdokumentasi, §7); keduanya normalnya berimpit untuk package gaya, tapi **`Berlaku buat` tetap sumber kebenaran governance** (boleh berbeda dari `consumers[]` yang juga tumbuh lewat `fanout`).
- **Nilai konkret di `control/` (asimetri SADAR):** `design-system.md` adalah **satu-satunya** artifact `control/` yang menyimpan **nilai visual konkret** (warna/easing), bukan cuma SHAPE/nama seperti `integrations.md`/`conventions.md`/`invariants.md`. Ini **disengaja**: mockup byte-opaque & nilai visual **tak punya sumber upstream untuk diprojeksi** — persis seperti `integrations.md` dibuat asimetris terhadap M4. Bukan pelanggaran norma; pengecualian sadar.
- **Tidak ada** bila produk tak punya permukaan UI / tak ada gaya yang dikunci → file boleh kosong (header saja) atau absen; seluruh jalur dorman.

## 5. Skill `design-system` — alur konduktor

`design-system` = **konduktor tipis**, kembaran `add-package`/`add-integration`. Beda kunci: ia **bangun kode bertampilan** (token+komponen primitif) via atom Spec A, bukan cuma scaffold skeleton kosong. Jalankan dari root produk (punya `control/`).

### Prinsip (jangan dilanggar)
- **Satu design system = satu gaya visual, di-scope ke app yang berbagi gaya.** BUKAN "satu paksa semua app". Web playful & admin plain = dua gaya berbeda; tak pernah dipaksa nyatu.
- **Pengguna yang menentukan app mana se-vibe** — `design-system` menanya ("gaya baru, atau ikut gaya yang sudah ada?"), tak menebak.
- **Mode dideteksi dari kode** (simetris `architect`): app kosong komponen → SETUP; app sudah punya komponen → CAPTURE.
- **Generik.** Bahasa visual di-elicit dari mockup/kode; plugin tak pernah mengasumsi/menulis framework/CSS-lib. Stack dari `workspace.yaml`.
- **Tiap aksi side-effecting = GATE.** Tulis `design-system.md` = gate; bangun kode = gate (typecheck + eyeball); `add-package` (bila dipakai) pakai gate-nya sendiri.
- **Idempotent.** App yang sudah diatur sebuah design system → tak di-bootstrap ulang (deteksi via `Berlaku buat`). Re-run = no-op/repair.

### Langkah (urut)

**0. Baca state & tentukan target.** Baca `control/design-system.md` (section + `Berlaku buat` yang ada) + `control/workspace.yaml` (`apps[]`: type fe/be/fullstack, path, stack) + `control/conventions.md`. Target = app(s) ber-permukaan-UI yang **belum** diatur design system (dari arg standalone, atau dari `fanout.md` saat dipanggil `feature`). App backend-only / app yang sudah diatur → SKIP.

**1. Tentukan scope gaya (GATE keputusan).** Untuk target app: tanya pengguna — **gaya baru** (bikin design system baru) atau **ikut design system yang sudah ada** (tambah app ini ke `Berlaku buat` section existing)? Bila gaya baru & pengguna menyebut app lain berbagi gaya itu → scope = beberapa app. Hasil: nama design system + daftar app dalam scope.

**2. Deteksi mode per scope.** Cek kode app-app dalam scope:
- Semua kosong komponen → **SETUP** (lanjut 3a).
- Sudah ada komponen → **CAPTURE** (lanjut 3b).
- **Campur** (sebagian app scope sudah punya komponen, sebagian kosong) → app ber-komponen jadi **SUMBER KANONIK**: CAPTURE-nya ke `design-system.md` (dokumentasi), lalu app kosong dalam scope **dibangun primitifnya DARI** `design-system.md` + komponen kanonik itu sebagai sumber reproduksi Spec A (bukan dari mockup); gate app yang dibangun = typecheck + eyeball **vs app kanonik**. Bila >1 app punya komponen **berbeda gaya** → **STOP**, minta pengguna tunjuk satu kanonik atau pisah jadi scope/run terpisah. (Tak ada code-gen ke app kanonik — itu tetap CAPTURE-only.)

**3a. SETUP (greenfield) — elicit + bangun.**
- **Pastikan & PERSIST mockup (durable — WAJIB).** Bila dipanggil `feature` → ambil mockup yang diserahkan (di context / yang ditunjuk pengguna) lalu **simpan VERBATIM (byte-opaque) ke `control/features/<f>/mockups/` LEBIH DULU**, sebelum elicit. `design-system` adalah **penulis pertama** folder itu pada jalur ini (ia jalan SEBELUM `plan`/Spec A, yang selama ini satu-satunya penulis `mockups/`); ini yang membuat pointer `Mockup kanonik` (§4) resolve & **selamat di sesi fresh/resume** — tanpa ini, jalur feature/resume diam-diam degrade ke ad-hoc (persis cross-session killer yang Spec A lawan). `plan`/Spec A yang jalan belakangan **menemukan folder sudah terisi → idempotent, tak meng-capture ganda** (Spec A `plan` cuma cek keberadaan). **Standalone** tanpa feature → minta mockup; rekam pointernya sebagai `Mockup kanonik` (boleh salin ke `control/` untuk durabilitas). Pengguna sengaja tanpa mockup → ad-hoc atau batal (degrade), jangan jalan diam-diam.
- **Elicit `design-system.md`** (judgment): baca mockup → turunkan tokens (warna/type/spacing/radius/shadow) + **motion vocab** (easing/durasi bernama) + inventory komponen primitif yang dibutuhkan. Tulis section ke `control/design-system.md` (GATE approve).
- **Bangun kode** (§7): token + komponen primitif via atom Spec A, ke wadah sesuai scope.

**3b. CAPTURE (brownfield) — dokumentasi-only.**
- Baca kode existing app dalam scope: token files / theme / komponen primitif yang ada → **konfirmasi ke pengguna** → tulis section `design-system.md` (pointer file komponen kanonik = pengganti "mockup kanonik"). **TIDAK** men-generate kode. GATE approve `.md`.
- **Ambang kelengkapan (anti-mengarang):** **inventory komponen = WAJIB** (terbaca dari kode); **tokens & motion = best-effort** dari token/theme files. Field yang **tak terbaca jelas** → tinggalkan penanda konfirmasi + minta pengguna isi atau tunjuk file/mockup acuan; **JANGAN mengarang nilai.** Section CAPTURE **valid dengan token parsial** (inventory + pointer komponen kanonik sudah cukup jadi acuan Spec A).
- Tujuan: project steady-state (kayak board game pengguna) langsung punya `design-system.md` → Spec A punya acuan token/motion konsisten.

**4. Tutup & balikin.** Lapor "**design system `<nama>` siap; app `<scope>` bergaya `<nama>`**".
- Dipanggil `feature` → balikin kontrol ke `feature` buat lanjut `plan` (fitur sekarang konsumsi primitif fresh; Spec A handle layout+animasi).
- Standalone → saranin langkah berikutnya (mis. `feature <fitur>`).

## 6. Trigger — `fanout` deteksi + `feature` auto-invoke

Mengikuti persis pola `NEW`/`PACKAGE NEW`/`VENDOR NEW` yang sudah ada.

### 6.1 `fanout` — deteksi (SKILL.md langkah 2 + 3 + 4)
- **Langkah 2 (Petakan ke app):** tambah satu pengecekan — bila peran fanout sebuah app **memperkenalkan/mengubah permukaan UI** (BUKAN sekadar `type` fe/fullstack — app fullstack yang fiturnya **cuma backend** TIDAK memicu) dan app itu **belum terdaftar** di `control/design-system.md` (`Berlaku buat`) → tandai butuh bring-up design system. Tantang dulu (anti-yes-man): app ini beneran perlu gaya sendiri, atau berbagi gaya app yang sudah ada / cukup pakai lib jadi? (Keputusan scope final tetap di `design-system` langkah 1; `fanout` cuma **MENGUSULKAN**.)
- **Langkah 3 (Challenge Checklist):** tambah satu butir — "ada app UI belum-terdaftar design-system → beneran perlu gaya sendiri, atau berbagi gaya existing / pakai lib jadi?" (sub-bullet, BUKAN renumber).
- **Langkah 4 (output `fanout.md`):** tambah baris penanda (sub-bullet, BUKAN renumber format existing), mis.:
  `<app> (DESIGN-SYSTEM NEEDED — belum terdaftar di design-system.md) : <permukaan UI>   # diwujudkan design-system`
  Penanda ini cocok untuk SETUP (greenfield) maupun CAPTURE (brownfield styled-tapi-belum-terdokumentasi). `fanout` **TIDAK** menulis `design-system.md` (itu jatah `design-system`) — cuma mengusulkan, seperti `NEW`/`PACKAGE NEW`.

### 6.2 `feature` — auto-invoke (SKILL.md langkah 2)
- Tambah klausa (sub-bullet di langkah 2, setelah `add-integration`): **bila `fanout.md` menandai `DESIGN-SYSTEM NEEDED`** → untuk tiap app itu, invoke skill **`design-system`** (tentukan scope → SETUP/CAPTURE → `design-system.md` + bangun kode, semua gated) → tunggu beres.
- **Urutan:** selesaikan `add-app` → `add-package` → `add-integration` → **`design-system`** dulu, **baru** `plan`. Saat `plan` jalan, primitif sudah ada di kode (app/package) & `design-system.md` sudah terisi — fitur tinggal konsumsi.

## 7. Bangun kode (SETUP) — atom dispatch Spec A

`design-system` **TIDAK** invoke `breakdown`/`build` (sirkular — ia dipanggil OLEH `feature` sebelum `plan`, & tak punya `tasks.yaml`). Ia **memakai atom-atom `build`**: instruksi mockup-dispatch (`build/reference.md §B`) + pemilihan model (`§C`) — TAPI **mensintesis unit kerjanya sendiri** (set token, lalu tiap komponen primitif), bukan membaca task. (Beda dari `wire §H` yang meminjam *engine side-effect* `build` yang parameterless; di sini yang dipakai = *instruksi dispatch*-nya, bukan task-dispatcher — `design-system` yang OWN sintesis unit kerja.)

- **Wadah kode mengikuti scope:**
  - **scope 1 app → app-local.** Bangun token + komponen primitif langsung di app itu (skeleton sudah di-`wire`). Tak ada package.
  - **scope >1 app → satu shared package:**
    - **Nama package (GATE):** `design-system` mengusulkan slug **kebab-case** (default `<slug-nama-ds>-ui`) + **cek tabrakan** vs `apps[]`/`packages[]` existing → konfirmasi ke pengguna (konsisten "pengguna yang menentukan"). Slug deterministik + bebas-tabrakan WAJIB sebelum `add-package` (yang idempotent pada `name` konkret) — bukan sekadar contoh.
    - Invoke `add-package <nama>` (declare entri `packages[]` → `architect` stack → `wire` mode-package scaffold+register, gate typecheck).
    - **`design-system` menulis `mandatory_for` = app scope DAN `consumers[]` = app scope LANGSUNG** ke entri package itu — **carve-out terdokumentasi dari "`fanout` penulis-tunggal `consumers[]`"**: konsumsi di sini **definisional** (scope = konsumen), bukan ditemukan; lagipula `fanout` fitur pemicu sudah jalan SEBELUM `design-system` (takkan mengisinya). `fanout` berikut tetap add-only-if-absent (tak menggandakan). **Tak perlu `plans/<pkg>.md`:** "kontrak" kit = kode primitif yang dibangun, dibaca langsung `build` fitur lewat pointer-pola/signature-dep — bukan kontrak yang direncanakan.
    - Lalu bangun token+primitif ke package itu.
- **Dispatch implementer = atom Spec A** (`build/reference.md §B`): untuk tiap unit kerja (set token, lalu tiap komponen primitif), rakit prompt berisi mockup (paste teks HTML/CSS verbatim / lampirkan gambar / fetch URL Figma) + instruksi **tech-agnostic**: *"Reproduksi HASIL VISUAL token & komponen primitif ini memakai stack app (`workspace.yaml`) + konvensi (`conventions.md`). JANGAN transplant markup mentah; terjemahkan ke idiom project. Bangun token bernama (warna/type/spacing/radius/shadow/motion) lalu komponen primitif yang memakainya. BAWA easing/durasi animasi."* + **model paling kuat** (judgment desain — `build/reference.md §C`).
- **Gate penutup:**
  - **typecheck/lint hijau** (package → lewat gate `wire` mode-package) — SELALU.
  - **eyeball** (render primitif vs mockup):
    - **app-local:** render di route scratch app skeleton (app sudah di-`wire`) → eyeball saat penutup `design-system`.
    - **package:** eyeball **DITUNDA** ke build fitur pemicu yang pertama mengonsumsi kit (gate eyeball Spec A — `build` SKILL step 6 / Spec A §7.4) — saat `design-system` menutup **belum ada app yang nge-import** package (gate `wire` mode-package cuma typecheck; app scope baru ter-wire mengonsumsi saat build fitur). **Tak ada mekanisme preview baru** (konsisten §10): primitif sudah valid-typecheck + direproduksi-dari-mockup oleh model terkuat, lalu diverifikasi mata saat konsumsi pertama. Standalone tanpa fitur pemicu → eyeball package jatuh ke konsumsi pertama berikutnya.
  - Konsisten Spec A: **tak ada** render-compare otomatis; eyeball manusia di GATE.

## 8. Motion vocab + hubungan ke Spec A

- **`design-system.md` section `Motion`** menyimpan easing & durasi **bernama** (tech-agnostic), mis. `ease-bounce = cubic-bezier(.34,1.56,.64,1) / 240ms`. Inilah rumah durable yang dulu hilang (M5).
- **Spec A merujuknya:** `build/reference.md §B` (instruksi mockup Spec A) ditambah **satu klausa** — *"Bila `control/design-system.md` punya section `Motion` (& app dalam scope sebuah design system), pakai vocab motion bernama itu untuk transisi/animasi alih-alih menemukan sendiri — biar konsisten antar-fitur."* Ini satu-satunya sentuhan ke teritori Spec A (additif, tidak mengubah perilaku Spec A bila `design-system.md` tak ada).
- Dengan ini, animasi per-fitur (Spec A) konsisten dengan fondasi (Spec B): token & motion sekali dikunci, dipakai ulang.

## 9. Prinsip generik (jangan dilanggar)

- **Bahasa visual di-elicit, bukan di-hardcode.** Plugin tak pernah menulis Tailwind/shadcn/CSS-vars sebagai asumsi; ia menurunkan token+komponen dari mockup/kode pengguna, lalu implementer menerjemahkan ke idiom project (stack+conventions).
- **Reproduksi hasil, jangan transplant** (warisan Spec A): semua format mockup seragam jadi "tiru tampilannya, bangun pakai stack project".
- **Mockup byte-opaque.** `design-system` membaca mockup untuk elicit (judgment), tak pernah mem-parse/men-transpile jadi kode.
- **Design system di-scope, bukan global.** N design system per produk; tiap gaya punya scope app; tak ada paksaan satu-gaya-semua-app.
- **Dua-mode simetris pipeline.** SETUP/CAPTURE seperti `architect`; CAPTURE dokumentasi-only (tak meng-generate), seperti `architect`-capture/`extract`.

## 10. Edge case & degrade-ke-noop

- **Produk tanpa UI / app backend-only** → `fanout` tak menandai; `design-system.md` absen; seluruh jalur dorman, nol biaya. **Termasuk app fullstack yang peran fiturnya backend-only** → TIDAK memicu `DESIGN-SYSTEM NEEDED` (trigger keyed ke peran-UI fanout, bukan `type` statis — sejajar pengecualian backend-only existing).
- **Scope campur SETUP/CAPTURE** → app ber-komponen = sumber kanonik (CAPTURE), app kosong dibangun darinya; >1 gaya berbeda → STOP/split (prosedur di §5 langkah 2).
- **App sudah diatur design system** → idempotent: `fanout` tak menandai ulang, `design-system` no-op (deteksi via `Berlaku buat`).
- **App ke-2 dengan gaya berbeda** (mis. `cms` plain setelah `web` playful) → `design-system` langkah 1 menanya; pengguna bilang "beda" → design system **baru** (section kedua), tak nyampur. Pengguna bilang "ikut `web`" → tambah app ke `Berlaku buat` section `web` (dan, bila itu membuat scope >1 app, promosi app-local→package = jalur `add-package`, di luar scope v1; v1 cukup catat scope + arahkan).
- **App plain pakai komponen jadi (shadcn/MUI)** → pengguna boleh **tak** men-trigger `design-system` untuk app itu (gaya = default lib, dipilih `architect`); atau CAPTURE default lib jadi section dokumentasi. `design-system` tak memaksa.
- **SETUP tanpa mockup (standalone)** → `design-system` minta mockup dulu; pengguna sengaja tanpa → lanjut ad-hoc atau batal (degrade), tak jalan diam-diam.
- **CAPTURE: token/motion existing tak terbaca jelas** → catat yang terbaca + konfirmasi sisanya ke pengguna; jangan mengarang.
- **mockup-tech ≠ project-tech** → instruksi "reproduksi hasil, jangan transplant" (§7) — sama seperti Spec A.
- **Eyeball untuk package** → **DITUNDA** ke build fitur pemicu yang pertama mengonsumsi kit (gate eyeball Spec A) — saat `design-system` menutup belum ada consumer ter-wire; **tak ada mekanisme preview baru** (sejalan §7). App-local → eyeball langsung di route scratch app skeleton.
- **Re-run / repair** → idempotent; section existing dipertahankan, hanya yang kurang dilengkapi.

## 11. Edit-map (skill BARU + integrasi + meta/parent)

> Anchor presisi (verbatim) diverifikasi `writing-plans` ke disk sebelum commit. Spec ini menetapkan **peta**, bukan diff final. Berbeda dari Spec A (additif murni): B **menambah skill** → wajib update meta + parent (lihat §12 bug-guard).

**A. Skill baru (2 file):**
1. `plugin/skills/design-system/SKILL.md` — konduktor (§5): prinsip, langkah 0–4, dua mode, scope. Frontmatter `name`/`description` (waspada colon-space — pakai ` — `, bukan `: `).
2. `plugin/skills/design-system/reference.md` — detail: format section `design-system.md` (§4), prosedur elicit token+motion, atom dispatch Spec A + wadah app-local/package (§7), gate typecheck+eyeball, CAPTURE.

**B. Integrasi (sentuh skill existing — additif, tanpa renumber):**
3. `plugin/skills/fanout/SKILL.md` — langkah 2: pengecekan app peran-UI yang **belum terdaftar** di `design-system.md` (§6.1); langkah 3 (Challenge Checklist): tambah satu butir; langkah 4: baris penanda `DESIGN-SYSTEM NEEDED` di format `fanout.md` (sub-bullet). Semua sisipan, BUKAN renumber.
4. `plugin/skills/feature/SKILL.md` — langkah 2: klausa auto-invoke `design-system` bila `DESIGN-SYSTEM NEEDED` (sub-bullet setelah `add-integration`) + urutan "design-system sebelum plan".
5. `plugin/skills/build/reference.md` — §B: klausa "pakai motion vocab `design-system.md` bila ada" (§8). Additif ke instruksi mockup Spec A.
6. `plugin/skills/architect/SKILL.md` — satu kalimat pointer (Catatan): "identitas visual/design system ditangani skill `design-system`, bukan di sini" (no renumber).
7. `plugin/template/control/design-system.md` (file BARU seed) + `plugin/skills/init/SKILL.md` — seed `design-system.md` (header `# <PRODUCT> — Design System` + catatan "Belum ada design system terdaftar.", **tanpa** section `## <name>` / baris `Berlaku buat:` palsu yang memecah scan governance). `init` meng-copy SELURUH `plugin/template/control/` via `cp -R` (langkah 4) → file otomatis ter-seed; cukup **tambah `design-system.md` ke enumerasi `<PRODUCT>`-replace di init/SKILL.md langkah 4** (sejajar `integrations.md`). Path benar = `plugin/template/control/` (BUKAN top-level `template/control/`, yang tak ada). Direkomendasikan untuk kelengkapan control-tree.
8. (Opsional, additif) `plugin/skills/render-docs/...` — section "Design System" di doc; `plugin/skills/ask/...` — sumber knowledge design-system. Boleh ditunda bila menambah risiko; bukan inti.

**C. Meta + parent (WAJIB karena skill-count berubah):**
9. `plugin/.claude-plugin/plugin.json` — **TAK ada array skills** (skill auto-discover dari `plugin/skills/`); skill cuma disebut di **string `description`** prosa. Tambah sebut `design-system` ke prosa `description` (kosmetik ~1 baris, pola commit "daftar skill debt" sebelumnya) — BUKAN entri registry.
10. `.claude-plugin/marketplace.json` — sama: tak ada array skills; tambah sebut `design-system` ke string `description` plugin (prosa, kosmetik).
11. `README.md` — **JANGAN** sisipkan ke arrow-string lifecycle (hanya 7 langkah inti, by-design). Tambah `design-system` ke **paragraf prosa branch-skill** (blok `> Kalau sebuah fitur butuh app baru…`) + paragraf **Status** — pola yang dipakai tiap branch-skill sebelumnya (`add-app`/`add-package`/`add-integration`).
12. Parent spec `2026-05-24-...`: **§7** control-tree (`control/` diagram +`design-system.md`); **§8** repo-tree (daftar skills +`design-system`, daftar template control +`design-system.md`); **§12** lifecycle (baris diagram + paragraf "Cabang dipicu — fitur butuh design system"); **§17** Komponen (**Skills 20→21** +`design-system`; Knowledge +`design-system.md`).

## 12. Verifikasi & bug-guard

**Verifikasi implementasi** (edit dokumen-skill → "test" = grep-battery + coherence):
- `design-system` muncul konsisten: skill baru (SKILL+reference), `fanout` penanda, `feature` auto-invoke, `build §B` klausa motion, `architect` pointer, `init`/template seed, plugin.json, marketplace.json, README, induk §7/§8/§12/§17.
- `control/design-system.md` format multi-section konsisten antara skill `design-system` (penulis) ↔ `build §B` (pembaca motion) ↔ deteksi `fanout` (`Berlaku buat`).
- Mode SETUP/CAPTURE + scope (N design system, attach vs new) terbaca jelas; sifat degrade-ke-noop di tiap titik.
- Tiap pointer silang ("rujuk §X" / "atom Spec A `build §B`" / "pola `add-package`") menunjuk seksi/artifact yang BENAR & NYATA.
- **Validasi nyata** (post-merge): jalankan satu project dari-0 (mockup → bootstrap) + satu CAPTURE pada board game → `design-system.md` terisi, primitif konsisten.

**Bug-guard di-prebake** (pelajaran berulang riwayat eksekusi):
- **Skill-count berubah** → WAJIB update plugin.json + marketplace.json + README + induk **§17** (20→21) **+ §8 repo-tree + §12 lifecycle + §7 control-tree** (staleness skill-count + parent-doc-tree = dua kelas bug yang konsisten — Spec A lolos §7 control-tree, ke-8×). **Catatan eksekusi:** plugin.json/marketplace.json TAK punya array skills — "update" = tambah sebut di string `description` prosa (§11 item 9-10); jangan cari array registry yang tak ada. README: ke paragraf prosa branch-skill + Status, BUKAN arrow-string lifecycle (§11 item 11).
- **colon-space** di `name:`/`description:` frontmatter skill baru (`design-system`) — pakai ` — ` (kasus `Generic:`→`Generic —` berkali).
- **mis-aimed-pointer** — tiap "reference §X"/"SKILL §Y" diverifikasi menunjuk seksi yang BENAR (streak 7× baru putus di Spec A karena guard ini di-prebake — PERTAHANKAN; fresh-eyes read di sesi terpisah tetap wajib).
- **no-renumber** — semua sentuhan ke `fanout`/`feature`/`build`/`architect`/`init` = sisipan sub-bullet/kalimat, BUKAN renumber langkah/list existing.
- **sentinel literal-scan trap** — seed `design-system.md` JANGAN pakai sentinel (mis. `<belum dikunci>`) yang bisa memecah scan `Berlaku buat` `design-system`/`fanout` (preseden `<belum dikunci>` invariants.md yang sempat memecah scan wire/architect). Seed = header murni tanpa nama app palsu.
- **coherence guard** — B menyandar Spec A (LIVE) + `add-package` (LIVE) + atom `build §B` (LIVE); semua NYATA, bukan artifact fiktif. JANGAN merujuk Langkah masa depan (M4/H3) yang belum ada.
- Grep verifikasi pakai **single-quote** untuk pola berisi backtick.

## 13. Hubungan ke Spec A, lifecycle, & Langkah berikutnya

- **B dibangun DI ATAS A.** Atom A ("implementer melihat mockup & mereproduksinya dengan stack project", `build §B`) = mesin yang B pakai untuk membangun token+komponen primitif. A = steady-state (komponen sudah ada → layout+animasi per-fitur); B = **bootstrap sekali-jalan** yang membawa project dari-0 sampai ke kondisi steady-state itu. Setelah B jalan, fitur UI berikutnya jatuh ke jalur A.
- **Lifecycle (induk §12) jadi:** `… wire → /feature(intake→fanout→plan) → …`, dengan **cabang dipicu** baru: bila `fanout` menandai `DESIGN-SYSTEM NEEDED`, `feature` auto-invoke `design-system` (scope → SETUP/CAPTURE → `design-system.md` + token+primitif) **sebelum** `plan` — sejajar cabang `add-app`/`add-package`/`add-integration`. Standalone `/design-system` juga tersedia.
- **Skill total 20 → 21.** `design-system` menjadi skill fondasi ke sekian, simetris dua-mode dengan `architect`/`wire`.
- **Langkah berikutnya yang TERPISAH (jangan campur):** Langkah-2 **M4 (schema-projection) → H3 (migration-governance)**; promosi app-local→shared-package untuk design system yang berkembang scope-nya (**seam belum ada** — lihat §3, bukan ditangani `fanout PACKAGE NEW` existing); tes live `/plugin install` end-to-end. Validasi nyata Spec A (1 fitur UI board game) juga masih menunggu pengguna.
