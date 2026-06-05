# Design-System Bring-Up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tambah skill baru `design-system` (konduktor dua-mode SETUP/CAPTURE) yang nurunin mockup awal jadi `control/design-system.md` (tokens + motion + komponen primitif) DAN bangun kode token+komponen primitif via atom dispatch Spec A, lalu wire-kan ke pipeline (fanout deteksi → feature auto-invoke) + update meta/parent.

**Architecture:** Ini perubahan **dokumen-skill** (Markdown/JSON), bukan kode runtime. "Test" tiap task = **grep-battery + coherence** (anchor verbatim ada sebelum diedit; konten baru ada sesudah; nol renumber). Spec sumber: `docs/superpowers/specs/2026-06-05-design-system-bring-up-design.md`. Spec A (LIVE, atom yang dipakai): `docs/superpowers/specs/2026-06-04-mockup-thread-design-fidelity-design.md`.

**Tech Stack:** Claude Code plugin skills (Markdown frontmatter + body), `control/` knowledge YAML/MD, plugin.json/marketplace.json (JSON), parent design-spec (MD).

**Scope note (v1 boundary):** Integrasi `render-docs` (section "Design System" di doc) + `ask` (sumber knowledge design-system) = **DITUNDA** (additif, non-inti, spec §11.B item 8). Bukan bagian plan ini; follow-up terpisah. Plan ini = 12 task, one-file-per-task.

**Bug-guard pre-bake (pelajaran berulang — taati di TIAP task):**
- **colon-space**: frontmatter `description:` skill baru JANGAN ada `": "` (colon-space) di dalam nilai — pakai `" — "`. (Kasus `Generic:`→`Generic —` berkali.)
- **no-renumber**: tiap sentuhan skill existing = sisipan sub-bullet/baris/kalimat, BUKAN renumber langkah/list/heading.
- **mis-aimed-pointer**: tiap "reference §X" / "lihat §Y" diverifikasi nunjuk seksi yang BENER (grep di Step verify).
- **sentinel literal-scan**: seed `design-system.md` JANGAN ada `## <name>` / `Berlaku buat:` palsu (memecah scan governance). Header murni.
- **grep pakai single-quote** untuk pola berisi backtick.
- **skill-count 20→21**: T9-T12 wajib; jangan lewat.

---

## Task 1: NEW `plugin/skills/design-system/reference.md`

**Files:**
- Create: `plugin/skills/design-system/reference.md`

Reference ditulis DULU supaya SKILL.md (Task 2) bisa nunjuk seksinya.

- [ ] **Step 1: Tulis file**

````markdown
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
````

- [ ] **Step 2: Verify konten kunci ada + nol colon-space-bug**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
F=plugin/skills/design-system/reference.md
grep -Fc -e 'Berlaku buat' "$F"          # expect >=2
grep -Fc -e 'carve-out' "$F"             # expect >=1 (consumers/mandatory_for)
grep -Fc -e 'DITUNDA' "$F"               # expect >=1 (eyeball package)
grep -Fc -e 'byte-opaque' "$F"           # expect >=1 (persist mockup)
grep -Fc -e 'anti-mengarang' "$F"        # expect 1 (CAPTURE threshold)
grep -nE '## [A-G]\.' "$F" | wc -l   # expect 7 (sections A-G)
```
Expected: counts ≥ noted; 7 sections.

- [ ] **Step 3: Commit**

```bash
cd /Users/stevanus/Developer/ai-boilerplate
git add plugin/skills/design-system/reference.md
git commit -m "feat(design-system): reference.md — format design-system.md + elicit + dispatch atom + gate + CAPTURE (design-system-bringup)"
```

---

## Task 2: NEW `plugin/skills/design-system/SKILL.md`

**Files:**
- Create: `plugin/skills/design-system/SKILL.md`

- [ ] **Step 1: Tulis file**

> **GUARD colon-space:** nilai `description:` di bawah TAK boleh ada `": "`. Pakai `" — "`. Verifikasi di Step 2.

````markdown
---
name: design-system
description: Use untuk bring-up FONDASI visual produk — turunin mockup awal jadi control/design-system.md (tokens + motion + komponen primitif) sekaligus bangun kode token+komponen primitif, semua di-GATE. Dua mode — SETUP (greenfield, dari mockup) dan CAPTURE (brownfield, dokumentasiin komponen existing). N design system per produk, di-scope per gaya visual (app mana se-vibe). Dipanggil feature saat fanout nandain app peran-UI belum-terdaftar, atau standalone. Generic — bahasa visual di-elicit, nol lock-in framework/CSS-lib. Trigger — "design-system", "bikin design system", "setup tokens", "bring-up komponen dari mockup". Jalankan dari root produk yang punya control/.
---

# design-system — Bring-Up Fondasi Visual (tokens + komponen primitif dari mockup)

Tujuan: ubah mockup awal jadi fondasi visual yang DURABLE — `control/design-system.md` (tokens + motion vocab + inventory komponen) + KODE token & komponen primitif — biar fitur UI berikutnya tinggal makai, gak nginvent ad-hoc tiap kali. `design-system` = konduktor tipis (kembaran `add-package`/`add-integration`), beda kunci: ia **bangun kode bertampilan** via atom dispatch Spec A, bukan cuma scaffold skeleton kosong. Jalankan dari root produk (punya `control/`).

`design-system` dibangun DI ATAS Spec A (mockup-thread, LIVE): atom "implementer melihat mockup & mereproduksinya dengan stack project" (`build/reference.md §B`) = mesin yang dipakai buat bangun primitif. A = steady-state (komponen udah ada → layout+animasi per-fitur); design-system = **bootstrap sekali-jalan** yang bawa project dari-0 ke kondisi steady-state itu.

> Detail (format `design-system.md`, elicit token+motion, atom dispatch + wadah app-local/package, gate, CAPTURE, scope N-design-system, persist mockup) ada di `${CLAUDE_PLUGIN_ROOT}/skills/design-system/reference.md` — baca itu dulu.

## Prinsip (jangan dilanggar)
- **Satu design system = satu gaya visual, di-scope ke app yang berbagi gaya.** BUKAN satu-paksa-semua-app. Web playful & admin plain = dua gaya, dua section.
- **Pengguna yang nentuin app mana se-vibe** — `design-system` NANYA ("gaya baru, atau ikut yang udah ada?"), gak nebak.
- **Mode dideteksi dari kode** (simetris `architect`): app kosong komponen → SETUP; udah ada → CAPTURE.
- **Generic.** Bahasa visual di-elicit dari mockup/kode; plugin gak pernah asumsi/nulis framework/CSS-lib. Stack dari `workspace.yaml`.
- **Tiap aksi side-effecting = GATE.** Tulis `design-system.md` = gate; bangun kode = gate (typecheck + eyeball); `add-package` (bila dipakai) pakai gate-nya sendiri.
- **Idempotent.** App yang udah diatur (cek `Berlaku buat`) gak di-bootstrap ulang. Re-run = no-op/repair.
- **Bukan komposit/page-level.** Scope = token + komponen primitif (Button/Input/Card/dst). Layout halaman = wilayah per-fitur Spec A.

## Langkah (urut)

### 0. Baca state & tentukan target
Baca `control/design-system.md` (section + `Berlaku buat` yang ada) + `control/workspace.yaml` (`apps[]`: type fe/be/fullstack, path, stack) + `control/conventions.md`. **Target** = app peran-UI yang **belum** diatur design system (dari arg standalone, atau dari `fanout.md` saat dipanggil `feature`). App backend-only / app yang udah diatur → SKIP.

### 1. Tentukan scope gaya (GATE keputusan)
Tanya pengguna: **gaya baru** (bikin design system baru) atau **ikut design system yang udah ada** (tambah app ke `Berlaku buat` section existing)? Gaya baru & user nyebut app lain se-vibe → scope = beberapa app. Hasil: nama design system + daftar app dalam scope. (reference §F.)

### 2. Deteksi mode per scope
Cek kode app-app dalam scope: semua kosong komponen → **SETUP** (3a); udah ada komponen → **CAPTURE** (3b); **campur** → app ber-komponen jadi sumber kanonik (reference §F).

### 3a. SETUP (greenfield) — persist mockup, elicit, bangun
- **Persist mockup (WAJIB):** simpan mockup verbatim (byte-opaque) ke `control/features/<f>/mockups/` LEBIH DULU — `design-system` jalan sebelum `plan`/Spec A, jadi ia penulis pertama folder ini; tanpa ini sesi fresh/resume kehilangan mockup (reference §G). Standalone tanpa mockup → minta dulu; user sengaja tanpa → ad-hoc/batal (degrade).
- **Elicit `design-system.md`** (judgment): turunkan tokens + motion vocab + inventory komponen dari mockup → tulis section (GATE approve). (reference §A/§B.)
- **Bangun kode**: token + komponen primitif via atom dispatch Spec A, ke wadah sesuai scope (app-local / package via `add-package`; carve-out `consumers[]`/`mandatory_for`). Gate = typecheck + eyeball. (reference §C/§D.)

### 3b. CAPTURE (brownfield) — dokumentasi-only
Baca komponen/token existing app dalam scope → konfirmasi user → tulis section `design-system.md` (inventory WAJIB; token/motion best-effort; JANGAN ngarang). **TIDAK** generate kode. GATE approve `.md`. (reference §E.)

### 4. Tutup & balikin
Lapor "**design system `<nama>` siap; app `<scope>` bergaya `<nama>`**".
- Dipanggil `feature` → balikin kontrol ke `feature` buat lanjut `plan` (fitur konsumsi primitif fresh; Spec A handle layout+animasi).
- Standalone → saranin langkah berikutnya (mis. `feature <fitur>`).

## Catatan
- **Cara kanonik bring-up design system.** `architect` mutusin stack + "lib kunci"; `design-system` yang nangkep BAHASA VISUAL + bangun primitif — beda concern.
- **Dipanggil `feature`** saat `fanout` nandain `DESIGN-SYSTEM NEEDED` (app peran-UI belum-terdaftar), atau **standalone**. Simetris dua-mode dengan `architect`/`wire`.
- TIDAK nyentuh `control/business/*`; TIDAK nulis kode FITUR (itu `build` per-fitur — `design-system` cuma fondasi primitif). PR & merge = jatah pengguna/`ship`; cek branch dulu.
````

- [ ] **Step 2: Verify frontmatter valid + nol colon-space-bug + pointer ke reference bener**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
F=plugin/skills/design-system/SKILL.md
head -3 "$F" | grep -q '^name: design-system' && echo "name OK"
# colon-space guard: nilai description TAK boleh ada ': ' — ambil baris description, buang 'description: ' prefix, cek sisa
sed -n 's/^description: //p' "$F" | grep -n ': ' && echo "!!! COLON-SPACE BUG" || echo "no colon-space OK"
grep -Fc -e 'reference §' "$F"           # expect >=5 (pointer ke reference)
grep -Fc -e 'SETUP' "$F"; grep -Fc -e 'CAPTURE' "$F"
grep -q 'skills/design-system/reference.md' "$F" && echo "reference pointer OK"
```
Expected: `name OK`, `no colon-space OK`, pointer counts ≥ noted, `reference pointer OK`.

- [ ] **Step 3: Commit**

```bash
cd /Users/stevanus/Developer/ai-boilerplate
git add plugin/skills/design-system/SKILL.md
git commit -m "feat(design-system): SKILL.md — konduktor dua-mode (SETUP/CAPTURE) bring-up fondasi visual (design-system-bringup)"
```

---

## Task 3: NEW `plugin/template/control/design-system.md` (seed)

**Files:**
- Create: `plugin/template/control/design-system.md`

Seed kosong (header murni) — biar control-tree lengkap dari `init`. **GUARD sentinel:** TANPA `## <name>` / `Berlaku buat:` palsu (memecah scan governance).

- [ ] **Step 1: Tulis file**

```markdown
# <PRODUCT> — Design System

> Knowledge fondasi visual produk. Diisi oleh skill `design-system` (tokens + motion + komponen primitif per gaya visual). Satu produk bisa punya beberapa design system, tiap section satu gaya (di-scope ke app yang berbagi gaya).

Belum ada design system terdaftar.
```

- [ ] **Step 2: Verify nol sentinel-trap (tak ada governance line palsu)**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
F=plugin/template/control/design-system.md
grep -q '<PRODUCT>' "$F" && echo "PRODUCT placeholder OK"
grep -nE '^## |^Berlaku buat' "$F" && echo "!!! SENTINEL TRAP" || echo "no fake governance line OK"
```
Expected: `PRODUCT placeholder OK`, `no fake governance line OK`.

- [ ] **Step 3: Commit**

```bash
cd /Users/stevanus/Developer/ai-boilerplate
git add plugin/template/control/design-system.md
git commit -m "feat(design-system): seed template/control/design-system.md (header murni) (design-system-bringup)"
```

---

## Task 4: MODIFY `plugin/skills/init/SKILL.md` — tambah design-system.md ke enumerasi `<PRODUCT>`-replace

**Files:**
- Modify: `plugin/skills/init/SKILL.md` (langkah 4)

`init` udah `cp -R` seluruh `template/control/` → seed auto-ke-copy. Cukup tambah `design-system.md` ke daftar file yang di-`<PRODUCT>`-replace (sejajar `integrations.md`).

- [ ] **Step 1: Verify anchor verbatim ada**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
grep -Fc -e 'conventions.md`, `invariants.md`, \*\*dan\*\* `integrations.md`' plugin/skills/init/SKILL.md
```
Expected: `1`.

- [ ] **Step 2: Edit (sisipan, no renumber)**

Ganti:
```
semua `business/*.md`, `conventions.md`, `invariants.md`, **dan** `integrations.md`)
```
Jadi:
```
semua `business/*.md`, `conventions.md`, `invariants.md`, `integrations.md`, **dan** `design-system.md`)
```

- [ ] **Step 3: Verify**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
grep -Fc -e '`integrations.md`, \*\*dan\*\* `design-system.md`' plugin/skills/init/SKILL.md   # expect 1
grep -nE '^### ' plugin/skills/init/SKILL.md | wc -l    # langkah headings unchanged (expect 7)
```
Expected: `1`; `7`.

- [ ] **Step 4: Commit**

```bash
cd /Users/stevanus/Developer/ai-boilerplate
git add plugin/skills/init/SKILL.md
git commit -m "feat(design-system): init seed design-system.md via <PRODUCT>-replace enumerasi (design-system-bringup)"
```

---

## Task 5: MODIFY `plugin/skills/fanout/SKILL.md` — deteksi UI-surface belum-terdaftar (langkah 2 + 3 + 4)

**Files:**
- Modify: `plugin/skills/fanout/SKILL.md` (langkah 2 bullet, langkah 3 checklist, langkah 4 format)

Semua **sisipan sub-bullet/baris**, BUKAN renumber.

- [ ] **Step 1: Verify 3 anchor verbatim ada**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
grep -Fc -e '**Isi `consumers[]` (penulis tunggal):**' plugin/skills/fanout/SKILL.md   # langkah 2 anchor
grep -Fc -e 'Ada dependency/kontrak lintas-app (mis. issuer↔validator)?' plugin/skills/fanout/SKILL.md  # langkah 3 anchor
grep -Fc -e 'VENDOR TOUCHED — perlu UPDATE) : <butuh arah>' plugin/skills/fanout/SKILL.md  # langkah 4 anchor
```
Expected: `1`, `1`, `1`.

- [ ] **Step 2a: Edit langkah 2 — sisip bullet deteksi SEBELUM bullet `consumers[]`**

Ganti (anchor = bullet consumers, dipertahankan):
```
- **Isi `consumers[]` (penulis tunggal):**
```
Jadi (bullet baru + anchor):
```
- **Kalau ADA app dengan peran-UI yang BELUM terdaftar di `design-system.md`** (`Berlaku buat`) → mungkin butuh **bring-up design system**. Picu HANYA bila peran fanout app itu **memperkenalkan/mengubah permukaan UI** (app `type` fullstack yang fiturnya cuma backend → JANGAN picu). Tantang (anti-yes-man): beneran perlu gaya sendiri, atau berbagi gaya app existing / cukup lib jadi? Lolos → tandai `DESIGN-SYSTEM NEEDED` (langkah 4); diwujudkan `design-system` (dipanggil otomatis `feature`). `fanout` cuma **MENGUSULKAN**.
- **Isi `consumers[]` (penulis tunggal):**
```

- [ ] **Step 2b: Edit langkah 3 — sisip butir checklist SEBELUM "Ada dependency/kontrak"**

Ganti:
```
- Ada dependency/kontrak lintas-app (mis. issuer↔validator)?
```
Jadi:
```
- Ada app peran-UI yang belum terdaftar di `design-system.md`? (beneran perlu gaya sendiri, atau berbagi gaya existing / pakai lib jadi?)
- Ada dependency/kontrak lintas-app (mis. issuer↔validator)?
```

- [ ] **Step 2c: Edit langkah 4 — sisip baris format SETELAH baris VENDOR TOUCHED**

Ganti:
```
<vendor> (VENDOR TOUCHED — perlu UPDATE) : <butuh arah>   # vendor existing, SHAPE perlu diperluas
```
Jadi:
```
<vendor> (VENDOR TOUCHED — perlu UPDATE) : <butuh arah>   # vendor existing, SHAPE perlu diperluas
<app> (DESIGN-SYSTEM NEEDED — belum terdaftar di design-system.md) : <permukaan UI>   # bring-up fondasi visual; diwujudkan design-system
```

- [ ] **Step 3: Verify sisipan landed + nol renumber**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
F=plugin/skills/fanout/SKILL.md
grep -Fc -e 'DESIGN-SYSTEM NEEDED' "$F"        # expect 2 (checklist-implied + format line); minimal: format line ada
grep -Fc -e 'belum terdaftar di `design-system.md`' "$F"   # expect 2 (langkah 2 bullet + checklist)
grep -nE '^### ' "$F" | wc -l              # langkah headings unchanged (expect 4)
```
Expected: format line ada; `2`; `4`.

- [ ] **Step 4: Commit**

```bash
cd /Users/stevanus/Developer/ai-boilerplate
git add plugin/skills/fanout/SKILL.md
git commit -m "feat(design-system): fanout deteksi app peran-UI belum-terdaftar → DESIGN-SYSTEM NEEDED (design-system-bringup)"
```

---

## Task 6: MODIFY `plugin/skills/feature/SKILL.md` — auto-invoke design-system (langkah 2)

**Files:**
- Modify: `plugin/skills/feature/SKILL.md` (langkah 2)

Sisip klausa auto-invoke SETELAH bullet `add-integration`, dan tambah `design-system` ke urutan "selesaikan dulu baru plan".

- [ ] **Step 1: Verify 2 anchor verbatim ada**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
grep -Fc -e 'Plain `VENDOR TOUCHED` (tanpa perlu-UPDATE) TIDAK di-invoke' plugin/skills/feature/SKILL.md
grep -Fc -e 'Selesaikan SEMUA `add-app` lalu `add-package` lalu `add-integration` dulu, \*\*baru lanjut ke `plan`\*\*' plugin/skills/feature/SKILL.md
```
Expected: `1`, `1`.

- [ ] **Step 2a: Edit — sisip bullet auto-invoke SETELAH bullet add-integration**

Ganti (akhir bullet add-integration = anchor):
```
 Plain `VENDOR TOUCHED` (tanpa perlu-UPDATE) TIDAK di-invoke — cukup `plan` promote kontrak existing.
```
Jadi:
```
 Plain `VENDOR TOUCHED` (tanpa perlu-UPDATE) TIDAK di-invoke — cukup `plan` promote kontrak existing.
   - **Bila `fanout.md` nandain `DESIGN-SYSTEM NEEDED` (app peran-UI belum terdaftar):** untuk tiap app itu, invoke skill **`design-system`** (tentukan scope → SETUP/CAPTURE → tulis `control/design-system.md` + bangun token & komponen primitif, semua gated) → tunggu beres.
```

- [ ] **Step 2b: Edit — tambah design-system ke urutan "selesaikan dulu"**

Ganti:
```
   - Selesaikan SEMUA `add-app` lalu `add-package` lalu `add-integration` dulu, **baru lanjut ke `plan`**. Saat `plan` jalan, app/package baru sudah ada di `workspace.yaml` (app ter-wire; package ter-typecheck) & vendor sudah ada di `integrations.md`.
```
Jadi:
```
   - Selesaikan SEMUA `add-app` lalu `add-package` lalu `add-integration` lalu `design-system` dulu, **baru lanjut ke `plan`**. Saat `plan` jalan, app/package baru sudah ada di `workspace.yaml` (app ter-wire; package ter-typecheck), vendor sudah ada di `integrations.md`, & app peran-UI sudah bergaya (token+primitif di kode, `design-system.md` terisi) — fitur tinggal konsumsi.
```

- [ ] **Step 3: Verify + nol renumber**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
F=plugin/skills/feature/SKILL.md
grep -Fc -e 'DESIGN-SYSTEM NEEDED' "$F"        # expect 1
grep -Fc -e 'lalu `design-system` dulu' "$F"   # expect 1
grep -nE '^### ' "$F" | wc -l              # langkah headings unchanged (expect 4)
```
Expected: `1`; `1`; `4`.

- [ ] **Step 4: Commit**

```bash
cd /Users/stevanus/Developer/ai-boilerplate
git add plugin/skills/feature/SKILL.md
git commit -m "feat(design-system): feature auto-invoke design-system pada DESIGN-SYSTEM NEEDED sebelum plan (design-system-bringup)"
```

---

## Task 7: MODIFY `plugin/skills/build/reference.md` — klausa motion vocab di §B

**Files:**
- Modify: `plugin/skills/build/reference.md` (§B, bullet Mockup)

Tambah satu kalimat ke instruksi mockup Spec A: rujuk motion vocab `design-system.md` bila ada. Additif, nol ubah perilaku Spec A bila `design-system.md` tak ada.

- [ ] **Step 1: Verify anchor verbatim ada**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
grep -Fc -e 'Mockup = byte opaque user; `build` tak pernah mengasumsi framework-nya.' plugin/skills/build/reference.md
```
Expected: `1`.

- [ ] **Step 2: Edit — sisip kalимat sebelum penutup bullet Mockup**

Ganti:
```
 Mockup = byte opaque user; `build` tak pernah mengasumsi framework-nya.
```
Jadi:
```
 **Bila `control/design-system.md` ada & app dalam scope sebuah design system (cek `Berlaku buat`):** pakai **motion vocab bernama** di section `Motion`-nya untuk transisi/animasi (alih-alih nemu sendiri) — biar konsisten antar-fitur. Mockup = byte opaque user; `build` tak pernah mengasumsi framework-nya.
```

- [ ] **Step 3: Verify**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
grep -Fc -e 'motion vocab bernama' plugin/skills/build/reference.md   # expect 1
grep -Fc -e 'design-system.md' plugin/skills/build/reference.md       # expect >=1
grep -nE '^## ' plugin/skills/build/reference.md | wc -l          # section headings unchanged (expect 6: A-F)
```
Expected: `1`; ≥1; `6`.

- [ ] **Step 4: Commit**

```bash
cd /Users/stevanus/Developer/ai-boilerplate
git add plugin/skills/build/reference.md
git commit -m "feat(design-system): build §B rujuk motion vocab design-system.md bila ada (konsistensi animasi antar-fitur) (design-system-bringup)"
```

---

## Task 8: MODIFY `plugin/skills/architect/SKILL.md` — pointer ke design-system (Catatan)

**Files:**
- Modify: `plugin/skills/architect/SKILL.md` (Catatan, 1 bullet baru)

- [ ] **Step 1: Verify anchor verbatim ada**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
grep -Fc -e 'Sesudah ini, skill `plan` membaca `stack` + `conventions.md` + kode yang ada — tidak menetapkan stack lagi.' plugin/skills/architect/SKILL.md
```
Expected: `1`.

- [ ] **Step 2: Edit — sisip bullet pointer SEBELUM bullet penutup Catatan**

Ganti:
```
- Sesudah ini, skill `plan` membaca `stack` + `conventions.md` + kode yang ada — tidak menetapkan stack lagi.
```
Jadi:
```
- **Identitas visual / design system** (palet, tipografi, motion, komponen primitif) di-handle skill `design-system` (dari mockup), BUKAN di sini — `architect` cukup pilih stack + "lib kunci".
- Sesudah ini, skill `plan` membaca `stack` + `conventions.md` + kode yang ada — tidak menetapkan stack lagi.
```

- [ ] **Step 3: Verify + nol renumber**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
grep -Fc -e 'Identitas visual / design system' plugin/skills/architect/SKILL.md   # expect 1
grep -nE '^### ' plugin/skills/architect/SKILL.md | wc -l    # langkah headings unchanged (expect 9)
```
Expected: `1`; `9`.

- [ ] **Step 4: Commit**

```bash
cd /Users/stevanus/Developer/ai-boilerplate
git add plugin/skills/architect/SKILL.md
git commit -m "feat(design-system): architect Catatan pointer ke skill design-system (identitas visual) (design-system-bringup)"
```

---

## Task 9: MODIFY `plugin/.claude-plugin/plugin.json` — sebut design-system di description prosa

**Files:**
- Modify: `plugin/.claude-plugin/plugin.json` (`description` string)

**TAK ada array skills** — skill cuma disebut di prosa `description`. Tambah sebutan (kosmetik).

- [ ] **Step 1: Verify anchor verbatim ada**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
grep -Fc -e 'resurface by locality), docs).' plugin/.claude-plugin/plugin.json
```
Expected: `1`.

- [ ] **Step 2: Edit — sisip sebutan design-system sebelum "docs)."**

Ganti:
```
resurface by locality), docs).
```
Jadi:
```
resurface by locality), design-system (bring-up fondasi visual: tokens+motion+komponen primitif dari mockup ke control/design-system.md, dua-mode SETUP/CAPTURE), docs).
```

- [ ] **Step 3: Verify JSON masih valid**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
python3 -m json.tool plugin/.claude-plugin/plugin.json > /dev/null && echo "JSON valid"
grep -Fc -e 'design-system' plugin/.claude-plugin/plugin.json   # expect 1
```
Expected: `JSON valid`; `1`.

- [ ] **Step 4: Commit**

```bash
cd /Users/stevanus/Developer/ai-boilerplate
git add plugin/.claude-plugin/plugin.json
git commit -m "feat(design-system): plugin.json description sebut design-system (design-system-bringup)"
```

---

## Task 10: MODIFY `.claude-plugin/marketplace.json` — sebut design-system di description prosa

**Files:**
- Modify: `.claude-plugin/marketplace.json` (plugin `description` string)

- [ ] **Step 1: Verify anchor verbatim ada**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
grep -Fc -e 'lane utang teknis debt)' .claude-plugin/marketplace.json
```
Expected: `1`.

- [ ] **Step 2: Edit**

Ganti:
```
lane utang teknis debt)
```
Jadi:
```
lane utang teknis debt + design-system bring-up fondasi visual)
```

- [ ] **Step 3: Verify JSON valid**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
python3 -m json.tool .claude-plugin/marketplace.json > /dev/null && echo "JSON valid"
grep -Fc -e 'design-system' .claude-plugin/marketplace.json   # expect 1
```
Expected: `JSON valid`; `1`.

- [ ] **Step 4: Commit**

```bash
cd /Users/stevanus/Developer/ai-boilerplate
git add .claude-plugin/marketplace.json
git commit -m "feat(design-system): marketplace.json sebut design-system (design-system-bringup)"
```

---

## Task 11: MODIFY `README.md` — branch-skill prosa + Status

**Files:**
- Modify: `README.md` (paragraf branch-skill `> Kalau sebuah fitur butuh app baru…` + paragraf Status)

**JANGAN** sentuh arrow-string lifecycle (cuma 7 langkah inti, by-design).

- [ ] **Step 1: Verify 2 anchor verbatim ada**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
grep -Fc -e 'scaffold stub webhook bila inbound).' README.md   # akhir paragraf branch-skill
grep -Fc -e 'steward `/debt` (list/triage/promote/drop).' README.md   # akhir paragraf Status
```
Expected: `1`, `1`.

- [ ] **Step 2a: Edit paragraf branch-skill — tambah kalimat design-system di akhir**

Ganti:
```
scaffold stub webhook bila inbound).
```
Jadi:
```
scaffold stub webhook bila inbound). Dan kalau fitur UI nyentuh app yang **belum punya design system**, `fanout` nandai `DESIGN-SYSTEM NEEDED` dan `feature` otomatis panggil `design-system` (turunin mockup jadi `control/design-system.md` + token & komponen primitif; dua-mode SETUP/CAPTURE) sebelum `plan`. `design-system` juga bisa standalone.
```

- [ ] **Step 2b: Edit paragraf Status — tambah kalimat design-system di akhir**

Ganti:
```
steward `/debt` (list/triage/promote/drop).
```
Jadi:
```
steward `/debt` (list/triage/promote/drop). **Design-fidelity:** `design-system` (bring-up fondasi visual — turunin mockup awal jadi `control/design-system.md` tokens+motion + bangun komponen primitif via atom dispatch Spec A; dua-mode SETUP greenfield / CAPTURE brownfield; N design system per-scope; dipicu `fanout`/`feature` atau standalone).
```

- [ ] **Step 3: Verify + arrow-string lifecycle TAK tersentuh**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
grep -Fc -e 'design-system' README.md          # expect >=2
grep -Fc -e '/init` -> `/architect` -> `/wire` -> `/feature`' README.md   # lifecycle arrows unchanged (expect 2)
```
Expected: ≥2; `2`.

- [ ] **Step 4: Commit**

```bash
cd /Users/stevanus/Developer/ai-boilerplate
git add README.md
git commit -m "feat(design-system): README branch-skill prosa + Status sebut design-system (design-system-bringup)"
```

---

## Task 12: MODIFY parent spec `2026-05-24-ai-first-boilerplate-design.md` — §7 + §8 + §12 + §17

**Files:**
- Modify: `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (control-tree §7, repo-tree §8, lifecycle §12, komponen §17)

Satu file, 4 sub-edit. Skill-count 20→21. **GUARD parent-doc-tree staleness** (kelas bug ke-8× — Spec A lolos §7).

- [ ] **Step 1: Verify 5 anchor verbatim ada**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
S=docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
grep -Fc -e '├── integrations.md       # kontrak SHAPE vendor eksternal (M5; diisi add-integration)' "$S"   # §7 anchor
grep -Fc -e '│   ├── skills/   discovery· init· architect· wire· add-app· add-package· add-integration· extract· intake· fanout· plan· feature· breakdown· build· ship· drop· render-docs· fix· ask· debt' "$S"   # §8 anchor
grep -Fc -e '**Lane korektif — defect (bug):**' "$S"   # §12 anchor (sisip cabang SEBELUM ini)
grep -Fc -e '- **Skills (20):**' "$S"   # §17 skills anchor
grep -Fc -e '- **Knowledge (`control/`):** `workspace.yaml` (apps[] + packages[]) · `business/` · `conventions.md` · `invariants.md` · `integrations.md` · `features/` · `docs/`' "$S"   # §17 knowledge anchor
```
Expected: `1` ×5.

- [ ] **Step 2a: §7 control-tree — sisip baris design-system.md SETELAH integrations.md**

Ganti:
```
├── integrations.md       # kontrak SHAPE vendor eksternal (M5; diisi add-integration)
```
Jadi:
```
├── integrations.md       # kontrak SHAPE vendor eksternal (M5; diisi add-integration)
├── design-system.md      # fondasi visual: tokens+motion+komponen primitif per gaya (diisi design-system)
```

- [ ] **Step 2b: §8 repo-tree — tambah design-system ke daftar skills**

Ganti:
```
│   ├── skills/   discovery· init· architect· wire· add-app· add-package· add-integration· extract· intake· fanout· plan· feature· breakdown· build· ship· drop· render-docs· fix· ask· debt
```
Jadi:
```
│   ├── skills/   discovery· init· architect· wire· design-system· add-app· add-package· add-integration· extract· intake· fanout· plan· feature· breakdown· build· ship· drop· render-docs· fix· ask· debt
```

Lalu (file yang sama, baris template control §8) — tambah design-system.md ke daftar template control. Verify anchor + edit:
```bash
grep -Fc -e '│   ├── control/  (workspace.yaml· business/· conventions.md· invariants.md· integrations.md· features/· docs/ theme warm)' "$S"   # expect 1
```
Ganti:
```
│   ├── control/  (workspace.yaml· business/· conventions.md· invariants.md· integrations.md· features/· docs/ theme warm)
```
Jadi:
```
│   ├── control/  (workspace.yaml· business/· conventions.md· invariants.md· integrations.md· design-system.md· features/· docs/ theme warm)
```

- [ ] **Step 2c: §12 lifecycle — sisip paragraf cabang SEBELUM "Lane korektif — defect"**

Ganti:
```
**Lane korektif — defect (bug):**
```
Jadi:
```
**Cabang dipicu — fitur UI butuh design system:** bila `fanout` menandai app peran-UI yang **belum terdaftar** di `control/design-system.md` sebagai `DESIGN-SYSTEM NEEDED`, `feature` otomatis invoke **`design-system`** (tentukan scope gaya → SETUP greenfield dari mockup / CAPTURE brownfield dari kode → tulis `control/design-system.md` + bangun token & komponen primitif via atom dispatch Spec A) sebelum `plan`. Dua-mode simetris `architect`. Standalone `/design-system` juga tersedia. Lihat spec `2026-06-05-design-system-bring-up-design.md`.

**Lane korektif — defect (bug):**
```

- [ ] **Step 2d: §17 — skill-count 20→21 + tambah design-system + Knowledge +design-system.md**

Ganti:
```
- **Skills (20):** `discovery` · `init` · `architect` · `wire` · `add-app` · `add-package` · `add-integration` · `extract` · `feature` (→ `intake` · `fanout` · `plan`) · `breakdown` · `build` · `ship` · `drop` · `render-docs` · `fix` · `ask` · `debt`
```
Jadi:
```
- **Skills (21):** `discovery` · `init` · `architect` · `wire` · `design-system` · `add-app` · `add-package` · `add-integration` · `extract` · `feature` (→ `intake` · `fanout` · `plan`) · `breakdown` · `build` · `ship` · `drop` · `render-docs` · `fix` · `ask` · `debt`
```

Lalu Knowledge line — ganti:
```
- **Knowledge (`control/`):** `workspace.yaml` (apps[] + packages[]) · `business/` · `conventions.md` · `invariants.md` · `integrations.md` · `features/` · `docs/`
```
Jadi:
```
- **Knowledge (`control/`):** `workspace.yaml` (apps[] + packages[]) · `business/` · `conventions.md` · `invariants.md` · `integrations.md` · `design-system.md` · `features/` · `docs/`
```

- [ ] **Step 3: Verify semua 4 sub-edit landed + count konsisten**

Run:
```bash
cd /Users/stevanus/Developer/ai-boilerplate
S=docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
grep -Fc -e 'design-system.md      # fondasi visual' "$S"        # §7 expect 1
grep -Fc -e 'wire· design-system· add-app' "$S"                  # §8 skills expect 1
grep -Fc -e 'integrations.md· design-system.md· features/' "$S"  # §8 template control expect 1
grep -Fc -e 'Cabang dipicu — fitur UI butuh design system' "$S"  # §12 expect 1
grep -Fc -e '**Skills (21):**' "$S"                              # §17 expect 1
grep -Fc -e '`integrations.md` · `design-system.md` · `features/`' "$S"  # §17 knowledge expect 1
grep -Fc -e 'Skills (20)' "$S"                                   # expect 0 (stale gone)
```
Expected: `1`×6, terakhir `0`.

- [ ] **Step 4: Commit**

```bash
cd /Users/stevanus/Developer/ai-boilerplate
git add docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
git commit -m "docs(spec): sync induk — design-system di §7 control-tree + §8 repo-tree + §12 lifecycle + §17 (skills 20→21) (design-system-bringup)"
```

---

## Final verification (setelah semua task)

Run grep-battery lintas-file buat konfirmasi seam koheren end-to-end:

```bash
cd /Users/stevanus/Developer/ai-boilerplate
echo "=== skill baru ada ==="
ls plugin/skills/design-system/   # SKILL.md + reference.md
echo "=== seam DESIGN-SYSTEM NEEDED konsisten (fanout nulis → feature baca) ==="
grep -l 'DESIGN-SYSTEM NEEDED' plugin/skills/fanout/SKILL.md plugin/skills/feature/SKILL.md
echo "=== Berlaku buat dipakai konsisten (design-system nulis, fanout/reference baca) ==="
grep -rl 'Berlaku buat' plugin/skills/design-system/ plugin/skills/fanout/SKILL.md
echo "=== motion vocab reference design-system.md di build ==="
grep -Fc -e 'motion vocab bernama' plugin/skills/build/reference.md
echo "=== skill-count 21 di induk, nol '20' stale ==="
grep -Fc -e 'Skills (21)' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
grep -Fc -e 'Skills (20)' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
echo "=== JSON valid ==="
python3 -m json.tool plugin/.claude-plugin/plugin.json > /dev/null && python3 -m json.tool .claude-plugin/marketplace.json > /dev/null && echo "both JSON valid"
echo "=== colon-space guard skill baru ==="
sed -n 's/^description: //p' plugin/skills/design-system/SKILL.md | grep -n ': ' && echo "!!! BUG" || echo "no colon-space OK"
```
Expected: skill dir ada, seam konsisten, motion=1, Skills(21)=1 & Skills(20)=0, both JSON valid, no colon-space OK.

**Validasi nyata (post-merge, by user):** jalanin satu project dari-0 (mockup → bootstrap SETUP) + satu CAPTURE pada board game → `design-system.md` terisi, primitif konsisten. + tes live `/plugin install`.
