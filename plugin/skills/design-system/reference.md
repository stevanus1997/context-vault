# design-system — Reference (bring-up fondasi visual)

Dibaca oleh skill `design-system`. SKILL.md tetap ramping; detail di sini.

## A. Format `control/design-system.md`

Satu file, **multi-section** (satu produk bisa punya N design system — persis `integrations.md` yang multi-vendor). Tiap section = satu gaya visual:

```
## <nama design system>            # mis. "web" / "admin" / nama brand
Berlaku buat : [web]               # ATAU [cms, cms-internal] — scope: app yang berbagi gaya ini
Kode di      : web/app-lokal       # ATAU "package <nama>" bila scope >1 app
Tokens       : warna · tipografi · spacing · radius · shadow   # nilai konkret + nama, tech-agnostic
Motion       : easing & durasi bernama (mis. ease-bounce = cubic-bezier(.34,1.56,.64,1)/240ms)
Komponen     : Button · Input · Card · …      # inventory primitif yang ada
Mockup kanonik: <pointer ke control/features/<f>/mockups/… ATAU file komponen kanonik (CAPTURE)>
```

- **`Berlaku buat`** = sumber kebenaran **governance** (yang menyetir scan trigger `fanout`). **Ditulis `design-system`.**
- **Nilai konkret (asimetri sadar):** `design-system.md` = satu-satunya artifact `control/` yang nyimpen nilai visual konkret (warna/easing), bukan cuma SHAPE/nama. Disengaja: mockup byte-opaque & nilai visual gak punya upstream buat diprojeksi (persis `integrations.md` asimetris ke M4).
- File boleh kosong (header saja) kalau belum ada gaya dikunci → scan governance nemu 0 app diatur.

## B. Elicit token + motion (SETUP, judgment)

Baca **mockup** (byte-opaque — JANGAN parse/transpile jadi kode; baca buat NURUNIN nilai) → turunkan:
- **Tokens**: palet warna (+ peran: primary/surface/text/…), skala tipografi, spacing, radius, shadow — nilai konkret + nama.
- **Motion vocab**: easing (cubic-bezier) & durasi, **bernama** (mis. `ease-bounce`/`240ms`) — rumah durable buat animasi per-fitur (Spec A ngerujuk).
- **Inventory komponen primitif** yang dibutuhin bahasa visual mockup (Button/Input/Card/dst).
Tulis ke section `design-system.md` (§A) → GATE approve.

## C. Bangun kode — atom dispatch Spec A + wadah

`design-system` **TIDAK** invoke `breakdown`/`build` (sirkular — dipanggil OLEH `feature` sebelum `plan`, & gak punya `tasks.yaml`). Ia **pakai atom-atom `build`**: instruksi mockup-dispatch (`build/reference.md §B`) + pilih-model (`§C`) — tapi **OWN sintesis unit kerjanya sendiri** (set token, lalu tiap komponen primitif). (Beda dari `wire §H` yang pinjam *engine side-effect* parameterless; di sini yang dipakai = *instruksi dispatch*-nya.)

**Wadah kode ngikut scope:**
- **scope 1 app → app-local.** Bangun token + primitif langsung di app (skeleton udah di-`wire`). Tak ada package.
- **scope >1 app → satu shared package:**
  - **Nama package (GATE):** usulin slug **kebab-case** (default `<slug-nama-ds>-ui`) + **cek tabrakan** vs `apps[]`/`packages[]` → konfirmasi user. Slug deterministik + bebas-tabrakan WAJIB sebelum `add-package` (idempotent pada `name` konkret).
  - Invoke `add-package <nama>` (declare `packages[]` → `architect` stack → `wire` mode-package, gate typecheck).
  - **`design-system` nulis `mandatory_for` = app scope DAN `consumers[]` = app scope LANGSUNG** ke entri package — **carve-out terdokumentasi dari "`fanout` penulis-tunggal `consumers[]`"**: konsumsi di sini DEFINISIONAL (scope = konsumen), `fanout` fitur pemicu udah jalan sebelum `design-system`. `fanout` berikut tetap add-only-if-absent. **Tak perlu `plans/<pkg>.md`** — "kontrak" kit = kode primitif (dibaca `build` lewat pointer-pola/signature-dep).
  - Lalu bangun token+primitif ke package itu.

**Dispatch implementer** (per unit kerja): rakit prompt = mockup (paste teks verbatim / lampir gambar / fetch URL Figma) + instruksi **tech-agnostic**: *"Reproduksi HASIL VISUAL token & komponen primitif ini pakai stack app (`workspace.yaml`) + konvensi (`conventions.md`). JANGAN transplant markup mentah; terjemahkan ke idiom project. Bangun token bernama (warna/type/spacing/radius/shadow/motion) lalu komponen primitif yang makainya. BAWA easing/durasi animasi."* + **model paling kuat** (judgment desain).

## D. Gate penutup

- **typecheck/lint hijau** (package → lewat gate `wire` mode-package) — SELALU.
- **eyeball** (render primitif vs mockup):
  - **app-local:** render di route scratch app skeleton (app udah di-`wire`) → eyeball saat penutup.
  - **package:** eyeball **DITUNDA** ke build fitur pemicu yang pertama mengonsumsi kit (gate eyeball Spec A — `build` SKILL step 6) — saat tutup belum ada app nge-import package (gate `wire` mode-package cuma typecheck). **Tak ada mekanisme preview baru.** Standalone tanpa fitur pemicu → eyeball jatuh ke konsumsi pertama.
- Konsisten Spec A: tak ada render-compare otomatis; eyeball manusia di GATE.

## E. CAPTURE (brownfield, dokumentasi-only)

App scope udah punya komponen → **dokumentasiin**, JANGAN generate kode:
- Baca token files / theme / komponen primitif existing → konfirmasi user → tulis section `design-system.md` (pointer file komponen kanonik = pengganti "Mockup kanonik").
- **Ambang kelengkapan (anti-mengarang):** **inventory komponen = WAJIB** (terbaca dari kode); **tokens & motion = best-effort**. Field tak-terbaca-jelas → penanda konfirmasi + minta user isi/tunjuk acuan; JANGAN ngarang nilai. Section valid dengan token parsial.
- Tujuan: project steady-state (mis. board game) langsung punya `design-system.md` → Spec A punya acuan token/motion konsisten.

## F. Scope & N design system

- **Scope = app yang berbagi satu gaya visual** (bukan global). Web playful & admin plain = dua gaya, dua section.
- **Tentukan scope (langkah 1):** untuk target app, NANYA user — **gaya baru** (section baru) atau **ikut gaya existing** (tambah app ke `Berlaku buat` section yang ada)? Pengguna yang nentuin app mana se-vibe.
- **Campur SETUP/CAPTURE dalam satu scope:** app ber-komponen = SUMBER KANONIK → CAPTURE-nya ke `.md`, lalu app kosong dalam scope dibangun primitifnya DARI `design-system.md` + komponen kanonik itu (sumber reproduksi Spec A, bukan mockup); gate app yang dibangun = typecheck + eyeball vs app kanonik. >1 app beda gaya → STOP, minta user tunjuk kanonik / pisah run. (Tak ada code-gen ke app kanonik.)

## G. Persist mockup (durable — WAJIB di SETUP)

`design-system` jalan SEBELUM `plan` (yang selama ini satu-satunya penulis `control/features/<f>/mockups/` — Spec A). Maka di jalur feature, **`design-system` yang nyimpen mockup DULU**:
- Ambil mockup yang diserahkan (context / yang ditunjuk user) → **simpan VERBATIM (byte-opaque) ke `control/features/<f>/mockups/`** sebelum elicit (§B). Ini bikin pointer `Mockup kanonik` resolve & **selamat di sesi fresh/resume** (kalau nggak, jalur feature/resume diam-diam degrade ke ad-hoc — cross-session killer Spec A).
- `plan`/Spec A yang jalan belakangan nemu folder udah terisi → **idempotent, tak meng-capture ganda** (Spec A `plan` cuma cek keberadaan).
- **Standalone** tanpa feature → minta mockup; rekam pointernya sebagai `Mockup kanonik` (boleh salin ke `control/`). User sengaja tanpa mockup → ad-hoc atau batal (degrade), jangan jalan diam-diam.
