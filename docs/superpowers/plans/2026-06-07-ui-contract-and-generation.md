# UI-Contract + Generate-in di `plan` — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tutup gap discovery (kontrak data UI) + gap generate UI di flow context-vault dengan mengedit skill `plan` (numpang di slot `Mockup:`), tanpa skill/artifact/pipa hilir baru.

**Architecture:** Semua perubahan terpusat di skill `plan`: tambah artifact `UI-Contract` (section di `plans/<app>.md`, sumber field/provider/state otoritatif) + ubah keputusan slot `Mockup:` jadi 3-jalur (bawa+cross-check / generate via `frontend-design` / degrade). Detail panjang dipindah ke `plan/reference.md` baru (match pola `build`/`breakdown`). `breakdown` dapat satu coverage-check; `build` tak diubah (sudah baca `plans/<app>.md`). Mockup tetap byte-opaque; field otoritatif = teks UI-Contract.

**Tech Stack:** Markdown skill files (Claude Code plugin — `plugin/skills/<skill>/SKILL.md` + `reference.md`). TIDAK ada test harness otomatis untuk skill; verifikasi = (1) struktural (frontmatter utuh, markdown valid, `${CLAUDE_PLUGIN_ROOT}` path benar), (2) konsistensi internal (instruksi baru tak bentrok dengan tetangganya), (3) **scenario walkthrough** (dry-run skenario auth-UI / non-UI / generate). Commits via git di branch `feat/ui-contract-generation` (sudah aktif).

**Spec:** `docs/superpowers/specs/2026-06-07-ui-contract-and-generation-design.md`

---

## File Structure

| File | Aksi | Tanggung jawab |
|---|---|---|
| `plugin/skills/plan/reference.md` | **CREATE** | Detail: §A format+derivasi UI-Contract · §B slot Mockup 3-jalur · §C cross-check · §D dispatch generate · §E round-trip |
| `plugin/skills/plan/SKILL.md` | MODIFY | Pointer ke reference · baca `design-system.md` · bullet UI-Contract + bullet Mockup 3-jalur (step 3) · `UI-Contract` di template output (step 4) · Catatan |
| `plugin/skills/breakdown/SKILL.md` | MODIFY | +1 coverage-check `UI-Contract→task` (step 4, tampil-di-gate bukan palang) |
| `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` | MODIFY (sync) | §9 `plan` — catat UI-Contract + Mockup 3-jalur di Perilaku & Output |
| `docs/superpowers/specs/2026-06-04-mockup-thread-design-fidelity-design.md` | MODIFY (sync) | §3 Non-Tujuan — back-ref: gap generate/discovery kini ditangani spec 2026-06-07 |

**Tidak diubah (sengaja):** `fanout`, `design-system`, `build`, `feature`, `feature.yaml`, `business.md`, `workspace.yaml`. `frontend-design` cuma **dipinjam** (dipanggil), tak dimodifikasi.

**Catatan eksekutor:** `${CLAUDE_PLUGIN_ROOT}` adalah variabel path plugin yang dipakai skill lain (lihat `plan/SKILL.md` baris yang merujuk `${CLAUDE_PLUGIN_ROOT}/rules/...`). Pertahankan gaya itu untuk pointer reference.

---

## Task 1: Create `plan/reference.md`

**Files:**
- Create: `plugin/skills/plan/reference.md`

- [ ] **Step 1: Acceptance criteria (apa yang harus benar setelah task)**

File `plugin/skills/plan/reference.md` ada, ber-header gaya rumah (`# plan — Reference (...)` + kalimat "Dibaca oleh skill `plan`..."), memuat 5 section §A–§E sesuai spec §4–§9 + §12 (detail terkunci), tanpa placeholder.

- [ ] **Step 2: Tulis file**

Tulis isi PERSIS berikut ke `plugin/skills/plan/reference.md`:

````markdown
# plan — Reference (UI-Contract + slot `Mockup:` 3-jalur)

Dibaca oleh skill `plan`. SKILL.md tetap ramping; detail UI-Contract, keputusan slot `Mockup:`, cross-check, dispatch generate, dan round-trip ada di sini.

## A. UI-Contract — artifact discovery

Section di `plans/<app>.md`, **HANYA** untuk app peran-UI (`type` ∈ {`fe`,`fullstack`} yang fitur ini **memunculkan/mengubah permukaan UI**-nya). App `be`/non-UI → **JANGAN** tulis section ini (degrade nol-biaya).

Diturunkan dari:
- `business.md` → keputusan provider/kebijakan (mis. "register pakai email + Google").
- `Model/Schema` (slot existing) → field ber-backing-data (email, password, name).
- `API/Komponen` (slot existing) → komponen/endpoint terlibat (RegisterForm, POST /register).

Format (section setelah `API/Komponen` di `plans/<app>.md`):
```
UI-Contract:
  <Komponen/Layar>:
    fields  : <nama(req|opt, constraint ringkas)>, ...
    actions : <aksi + provider, mis. submit, "Continue with Google">
    states  : <idle / loading / error(<kasus>) / success / empty ...>
    shows   : <data yang ditampilkan — layar baca/list; OPSIONAL>
```
- `shows` **opsional** (layar baca/list). Constraint per-field inline di `fields` (req/opt, min/max, format) — **TANPA** slot `validation`/`a11y` terpisah (a11y dijaga komponen design-system saat `build`).
- **SELALU** dibuat lebih dulu dari keputusan slot `Mockup:` — berfungsi di 3 jalur (§B): spec yang dipenuhi mockup (a), input generate (b), konteks build (c).
- **Tampilkan rapi di gate** sebagai blok mandiri yang bisa pengguna **copy** ke tool design eksternal (memenuhi "1 kontrak yang bisa dibawa" tanpa file baru).
- **Idempotent:** re-run `plan` yang sudah punya `UI-Contract:` → reuse, kecuali `business.md`/`Model/Schema`/`API/Komponen` berubah.

Contoh (`auth`/`web`):
```
UI-Contract:
  RegisterForm:
    fields  : email(req), password(req,min8), name(req)
    actions : submit, "Continue with Google"
    states  : idle / loading / error(email-taken) / success
```

## B. Slot `Mockup:` — 3 jalur

Bagian **sama** untuk ketiganya: `UI-Contract` (§A) sudah ditulis & ditampilkan. Lalu keputusan slot `Mockup:` (per app UI) — **tawarkan ketiga jalur** ke pengguna saat app UI belum punya mockup tersimpan; **default TIDAK auto-generate** (hindari biaya tak diminta):

1. **Bawa mockup** (sudah jadi / design sendiri): simpan verbatim ke `mockups/` (Spec A) → **cross-check** (§C) → isi pointer `Mockup:`.
2. **Generate**: §D → mockup-reference ke `mockups/` → **gate eyeball** → isi `Mockup:`.
3. **Degrade** (sengaja skip): `Mockup:` kosong, lanjut (perilaku sekarang); `UI-Contract` tetap ada sebagai konteks `build`.

## C. Cross-check (advisory, opacity terjaga)

Saat jalur **bawa-mockup**. **JANGAN** parse mockup jadi data — mockup tetap **byte-opaque** sepanjang pipeline (invariant Spec A). Yang dilakukan:
- Di gate, **tampilkan UI-Contract di samping pointer mockup** + minta pengguna konfirmasi coverage: *"pastikan mockup memuat: email, password, name, Continue-with-Google. `name` kelihatannya belum ada — tambahkan?"*
- Mockup **teks** (HTML/CSS): boleh **glance ringan** — heuristik nama-field (cari `<input>`/`<label>`/teks tombol yang tampak hilang vs `fields`/`actions`). **Selalu** dikonfirmasi manusia; tak disimpan/diprosa-kan.
- Mockup **non-teks** (gambar/Figma): murni konfirmasi-manusia, tanpa glance.
- Hasil cross-check **TIDAK** ditulis sebagai prosa ke `plans/<app>.md` (hanya `UI-Contract` + pointer `Mockup:` yang ditulis). Field otoritatif = `UI-Contract`.
- Sifat **ADVISORY, bukan palang** — pengguna boleh lanjut walau ada selisih (field bisa sengaja di layar lain).

## D. Generate (dispatch `frontend-design`)

- **Pemicu:** pengguna pilih "generate" di gate `Mockup:` untuk app UI tanpa mockup.
- **Prasyarat:** `control/design-system.md` ada & app dalam scope sebuah design system (cek `Berlaku buat`). Bila app UI belum bergaya, `fanout` sudah memicu `design-system` lebih dulu (existing). Bila `design-system.md` tetap kosong untuk app ini → **JANGAN ngarang fondasi**: degrade ke ad-hoc + peringatan arahkan jalankan `design-system` dulu.
- **Dispatch:** invoke skill **`frontend-design`** dengan konteks: isi `UI-Contract` (§A) + token + inventory komponen dari `design-system.md` + stack app dari `workspace.yaml`. Minta output **mockup HTML/CSS** (format yang mockup-thread sudah handle); URL/aset Figma sebagai alternatif bila relevan.
- **Persist:** simpan hasil **verbatim** ke `control/features/<fitur>/mockups/` (penulis = `plan`, konsisten Spec A).
- **Gate eyeball:** tampilkan hasil → pengguna **approve / regen-dengan-arahan** ("tombol Google lebih besar", "rapatkan spacing") / koreksi manual. Approve → isi pointer `Mockup:`.
- **Hilir:** identik jalur lain — hasil = **mockup-reference**; `build` tetap reproduksi via TDD (BUKAN kode produksi langsung). Karena generate sudah pakai komponen design-system, reproduksi `build` murah & akurat.

## E. Round-trip "design sendiri"

Pengguna pilih jalur **bawa-mockup** tapi belum design:
- **Sesi sama:** `plan` tampilkan `UI-Contract` → **menunggu di gate** → pengguna design di tool eksternal → paste/serahkan hasil → cross-check (§C) → isi `Mockup:`.
- **Sesi beda:** jalankan **`/plan <fitur>`** lagi (modular, tak menarik `intake`/`fanout`) → pengguna serahkan mockup → `UI-Contract` sudah ada (idempotent §A) → cross-check → isi.
- Selama `breakdown` belum jalan, tak ada yang basi. Bila sudah `breakdown`, aturan staleness existing berlaku (`plan` berubah → ingatkan `breakdown` ulang, yang mempertahankan status task `done`).
````

- [ ] **Step 3: Verify struktur**

Run: `head -3 plugin/skills/plan/reference.md && grep -nE "^## [A-E]\." plugin/skills/plan/reference.md`
Expected: baris 1 = `# plan — Reference (UI-Contract + slot \`Mockup:\` 3-jalur)`; grep menampilkan tepat 5 baris `## A.` … `## E.`.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/plan/reference.md
git commit -m "feat(plan): tambah reference.md — UI-Contract + slot Mockup 3-jalur (detail)"
```

---

## Task 2: `plan/SKILL.md` — pointer reference + baca `design-system.md`

**Files:**
- Modify: `plugin/skills/plan/SKILL.md` (intro + step 1)

- [ ] **Step 1: Tambah pointer ke reference.md**

Edit `plugin/skills/plan/SKILL.md` — ganti:

```
Tujuan: untuk tiap app yang kena fitur, susun plan implementasi konkret berbasis kode & konvensi yang ADA.

## Langkah
```

menjadi:

```
Tujuan: untuk tiap app yang kena fitur, susun plan implementasi konkret berbasis kode & konvensi yang ADA.

> Detail **UI-Contract**, slot `Mockup:` 3-jalur, cross-check, dispatch generate, & round-trip ada di `${CLAUDE_PLUGIN_ROOT}/skills/plan/reference.md` — baca itu saat app menyentuh permukaan UI.

## Langkah
```

- [ ] **Step 2: Tambah `design-system.md` ke daftar baca (step 1)**

Edit `plugin/skills/plan/SKILL.md` — pada paragraf "### 1. Baca input", ganti tail:

```
+ `control/features/<fitur>/mockups/` (mockup UI yang diserahkan pengguna, **bila ada** — cek keberadaan saja; isi TIDAK di-parse di sini, diserahkan ke `build`).
```

menjadi:

```
+ `control/features/<fitur>/mockups/` (mockup UI yang diserahkan pengguna, **bila ada** — cek keberadaan saja; isi TIDAK di-parse di sini, diserahkan ke `build`) + `control/design-system.md` (fondasi visual — untuk jalur generate & konteks komponen app UI, read-only).
```

- [ ] **Step 3: Verify**

Run: `grep -n "reference.md" plugin/skills/plan/SKILL.md && grep -n "design-system.md" plugin/skills/plan/SKILL.md`
Expected: pointer reference muncul (1 hit di intro); `design-system.md` muncul di step 1 baca-input.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/plan/SKILL.md
git commit -m "feat(plan): pointer reference.md + baca design-system.md (jalur generate)"
```

---

## Task 3: `plan/SKILL.md` step 3 — bullet UI-Contract + bullet Mockup 3-jalur

**Files:**
- Modify: `plugin/skills/plan/SKILL.md` (### 3. Per app — bullet Mockup)

- [ ] **Step 1: Acceptance**

Bullet lama "Mockup UI (bila app punya permukaan UI)" diganti DUA bullet: (1) `UI-Contract` (derivasi + tampil di gate, skip non-UI), (2) slot `Mockup:` 3-jalur (bawa+cross-check / generate / degrade) dengan pointer ke `reference.md` §A–§E.

- [ ] **Step 2: Edit**

Edit `plugin/skills/plan/SKILL.md` — ganti bullet (satu baris penuh) ini:

```
- **Mockup UI (bila app punya permukaan UI).** Bila pengguna menyerahkan mockup (HTML/CSS/gambar/URL Figma) untuk app ini → simpan **verbatim** ke `control/features/<fitur>/mockups/` (format apa pun; **JANGAN** inline ke plan, **JANGAN** diprosa-kan jadi deskripsi), catat path-nya untuk slot `Mockup:` (langkah 4). Bila `/plan` dijalankan **standalone** & app punya UI tapi belum ada mockup tersimpan → **minta** mockup dulu (jangan jalan diam-diam); pengguna sengaja tak punya → lanjut tanpa `Mockup:` (degrade ke perilaku sekarang).
```

menjadi (dua bullet):

```
- **UI-Contract (bila app punya permukaan UI).** SEBELUM mengurus mockup, turunkan **UI-Contract** layar/komponen fitur ini dari `business.md` (provider/kebijakan, mis. login Google/Facebook) + `Model/Schema` + `API/Komponen` — field, actions (+provider), states (idle/loading/error/success). Tulis sebagai section di `plans/<app>.md` (langkah 4) + **tampilkan rapi di gate** sebagai blok yang bisa pengguna copy ke tool design eksternal. App `be`/non-UI → SKIP (nol biaya). Idempotent (re-run reuse). Format + derivasi: `reference.md` §A.
- **Slot `Mockup:` — 3 jalur (bila app punya permukaan UI).** Setelah UI-Contract ada, untuk app UI yang belum punya mockup tersimpan, **tawarkan 3 jalur** (default TIDAK auto-generate): **(a) bawa mockup** — pengguna menyerahkan mockup (HTML/CSS/gambar/URL Figma) → simpan **verbatim** ke `control/features/<fitur>/mockups/` (**JANGAN** inline/diprosa-kan) → **cross-check** vs UI-Contract (advisory, konfirmasi-manusia; opacity mockup terjaga — `reference.md` §C); **(b) generate** — dispatch skill `frontend-design` dengan UI-Contract + token/komponen `design-system.md` → mockup ke `mockups/` → **gate eyeball** approve/regen (`reference.md` §D); **(c) degrade** — sengaja tak mau → lanjut tanpa `Mockup:` (perilaku sekarang). Catat path hasil (a/b) untuk slot `Mockup:` (langkah 4). **Round-trip "design sendiri"** (kasih UI-Contract → pengguna design di luar → balik): sesi-sama tunggu di gate; sesi-beda jalankan `/plan` lagi — `reference.md` §E.
```

- [ ] **Step 3: Verify**

Run: `grep -n "UI-Contract" plugin/skills/plan/SKILL.md && grep -nc "Mockup" plugin/skills/plan/SKILL.md`
Expected: ≥1 hit "UI-Contract" di step 3; bullet 3-jalur memuat "(a) bawa mockup", "(b) generate", "(c) degrade" (cek manual baca bullet).

- [ ] **Step 4: Konsistensi check (baca tetangga)**

Baca step 3 utuh — pastikan bullet baru tak bentrok dengan bullet "Challenge teknis" & "Debt-aware" sesudahnya (urutan logis: schema → kode → Q&A → plan → **UI-Contract → Mockup** → challenge → debt). Tak ada duplikasi instruksi mockup.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/plan/SKILL.md
git commit -m "feat(plan): step 3 — derive UI-Contract + slot Mockup 3-jalur"
```

---

## Task 4: `plan/SKILL.md` step 4 — `UI-Contract` di template output

**Files:**
- Modify: `plugin/skills/plan/SKILL.md` (### 4. Tulis output — fenced template)

- [ ] **Step 1: Edit template**

Edit `plugin/skills/plan/SKILL.md` — ganti blok template:

```
# <app>
Model/Schema : <...>
API/Komponen : <...>
Lokasi       : <path konkret di app>
Mockup       : <path… ke control/features/<fitur>/mockups/ ATAU kosong>
Test         : <...>
```

menjadi:

```
# <app>
Model/Schema : <...>
API/Komponen : <...>
UI-Contract  : <field/actions/states per layar — app UI saja (reference.md §A); ATAU kosong non-UI>
Lokasi       : <path konkret di app>
Mockup       : <path… ke control/features/<fitur>/mockups/ ATAU kosong>
Test         : <...>
```

- [ ] **Step 2: Verify**

Run: `grep -n "UI-Contract  :" plugin/skills/plan/SKILL.md`
Expected: 1 hit, di blok template step 4, tepat setelah baris `API/Komponen : <...>`.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/plan/SKILL.md
git commit -m "feat(plan): step 4 — UI-Contract di template output plans/<app>.md"
```

---

## Task 5: `plan/SKILL.md` Catatan — UI-Contract vs Mockup

**Files:**
- Modify: `plugin/skills/plan/SKILL.md` (## Catatan)

- [ ] **Step 1: Edit — tambah bullet penjelas**

Edit `plugin/skills/plan/SKILL.md` — ganti bullet Catatan ini:

```
- `plan` tetap FLAT. Dekomposisi jadi task kecil (siap-eksekusi) = jatah skill `breakdown`, bukan di sini. Slot `Mockup:` adalah **pointer** ke file di `mockups/`, **bukan** deskripsi visual — `plan` tak pernah memprosa-kan isi mockup (itu byte opaque untuk `build`).
```

menjadi:

```
- `plan` tetap FLAT. Dekomposisi jadi task kecil (siap-eksekusi) = jatah skill `breakdown`, bukan di sini. Slot `Mockup:` adalah **pointer** ke file di `mockups/`, **bukan** deskripsi visual — `plan` tak pernah memprosa-kan isi mockup (itu byte opaque untuk `build`).
- **UI-Contract vs Mockup (dua hal beda).** `UI-Contract` = kebutuhan data (field/provider/state) sebagai **teks otoritatif** — sumber field yang dibaca `breakdown`/`build`. `Mockup:` = tampilan sebagai **byte opaque** (di-reproduksi `build`). UI-Contract menyetir design (bahan generate / cek mockup-bawaan); generate menghasilkan **mockup-reference**, `build` tetap implement via TDD (bukan kode produksi langsung). Field otoritatif tetap UI-Contract walau mockup ada.
```

- [ ] **Step 2: Verify**

Run: `grep -n "UI-Contract vs Mockup" plugin/skills/plan/SKILL.md`
Expected: 1 hit, di section `## Catatan`.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/plan/SKILL.md
git commit -m "docs(plan): Catatan — UI-Contract (teks otoritatif) vs Mockup (byte opaque)"
```

---

## Task 6: `breakdown/SKILL.md` — coverage-check UI-Contract→task

**Files:**
- Modify: `plugin/skills/breakdown/SKILL.md` (### 4. Coverage check + task integrasi)

- [ ] **Step 1: Edit — tambah bullet coverage**

Edit `plugin/skills/breakdown/SKILL.md` — ganti bullet ini:

```
- **UI coverage (mockup→task):** tiap file mockup yang dirujuk `plans/<app>.md` (baris `Mockup:`) WAJIB ke-map ke ≥1 task ber-`mockup:`. Tampilkan **peta mockup→task** di gate (di samping peta plan→task) — biar tak ada layar yang kelupaan jadi task.
```

menjadi:

```
- **UI coverage (mockup→task):** tiap file mockup yang dirujuk `plans/<app>.md` (baris `Mockup:`) WAJIB ke-map ke ≥1 task ber-`mockup:`. Tampilkan **peta mockup→task** di gate (di samping peta plan→task) — biar tak ada layar yang kelupaan jadi task.
- **UI-Contract coverage:** bila `plans/<app>.md` punya section `UI-Contract`, tiap entri (field/actions/states) SEBAIKNYA ke-cover ≥1 task. Tampilkan **peta UI-Contract→task** di gate (di samping peta plan→task & mockup→task). **Tampil-di-gate, BUKAN palang** (sejajar coverage Model/Schema) — selisih disodorkan ke user, tak memblokir.
```

- [ ] **Step 2: Verify**

Run: `grep -n "UI-Contract coverage" plugin/skills/breakdown/SKILL.md`
Expected: 1 hit di step 4. Pastikan frasa "BUKAN palang" ada (advisory, bukan STOP).

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/breakdown/SKILL.md
git commit -m "feat(breakdown): coverage-check UI-Contract→task (tampil-di-gate, advisory)"
```

---

## Task 7: Sync spec induk §9 + back-ref mockup-thread

**Files:**
- Modify: `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§9 `plan`)
- Modify: `docs/superpowers/specs/2026-06-04-mockup-thread-design-fidelity-design.md` (§3 Non-Tujuan)

- [ ] **Step 1: Edit induk §9 Perilaku**

Edit `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` — ganti tail kalimat Perilaku `plan`:

```
(Karena `architect` sudah jalan, `plan` selalu membaca stack yang ada — tidak menetapkan stack.)
```

menjadi:

```
(Karena `architect` sudah jalan, `plan` selalu membaca stack yang ada — tidak menetapkan stack.) **(App UI)** turunkan **UI-Contract** (field/provider/state) lalu slot `Mockup:` **3-jalur**: bawa(+cross-check)/generate(via `frontend-design`)/degrade — detail `plan/reference.md`.
```

- [ ] **Step 2: Edit induk §9 Output**

Edit file yang sama — ganti baris Output `plan`:

```
- **Output:** `features/<nama>/plans/_shared.md` + `plans/<app>.md`.
```

menjadi:

```
- **Output:** `features/<nama>/plans/_shared.md` + `plans/<app>.md` (+ section `UI-Contract` & pointer `Mockup:` untuk app UI).
```

- [ ] **Step 3: Back-ref di mockup-thread §3**

Edit `docs/superpowers/specs/2026-06-04-mockup-thread-design-fidelity-design.md` — ganti akhir bullet "Bukan design-system bring-up greenfield":

```
Spec A mengasumsikan komponen sudah ada di kode (steady-state) ATAU implementer membangun ad-hoc dari mockup.
```

menjadi:

```
Spec A mengasumsikan komponen sudah ada di kode (steady-state) ATAU implementer membangun ad-hoc dari mockup. **(Update 2026-06-07)** jalur "tak punya mockup → generate" + discovery field/provider ("UI-Contract") kini ditangani spec `2026-06-07-ui-contract-and-generation-design.md` (numpang di `plan`, slot `Mockup:` 3-jalur).
```

- [ ] **Step 4: Verify**

Run: `grep -n "UI-Contract" docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md docs/superpowers/specs/2026-06-04-mockup-thread-design-fidelity-design.md`
Expected: hit di induk §9 (Perilaku + Output) dan di mockup-thread §3.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md docs/superpowers/specs/2026-06-04-mockup-thread-design-fidelity-design.md
git commit -m "docs(spec): sync induk §9 + back-ref mockup-thread untuk UI-Contract + generate"
```

---

## Task 8: Validasi end-to-end (scenario walkthrough) + tutup

**Files:** (read-only verify; tak ada edit kecuali nemu bug)

- [ ] **Step 1: Frontmatter & struktur utuh**

Run: `head -4 plugin/skills/plan/SKILL.md && head -4 plugin/skills/breakdown/SKILL.md`
Expected: frontmatter `---\nname: plan\ndescription: ...\n---` dan `name: breakdown` masih utuh (tak rusak oleh edit).

- [ ] **Step 2: Tak ada referensi menggantung**

Run: `grep -rnE "reference\.md|frontend-design|design-system\.md" plugin/skills/plan/SKILL.md`
Expected: pointer `reference.md` ada; `frontend-design` disebut di bullet generate; `design-system.md` disebut di step 1 + bullet generate. Tak ada typo path.

- [ ] **Step 3: Scenario walkthrough — auth app UI (jalur normal)**

Dry-run baca `plan/SKILL.md` + `reference.md` untuk fitur `auth`, app `web` (type fullstack, UI). Konfirmasi alur terbaca benar:
1. step 3 → turunkan `UI-Contract` (RegisterForm: email/password/name, submit + Google, states) dari business+Model/Schema+API.
2. step 3 → slot `Mockup:` tawarkan 3 jalur; tampilkan UI-Contract di gate.
3. step 4 → template punya baris `UI-Contract :` + `Mockup :`.
Expected: tak ada langkah yang kontradiktif/ambigu; UI-Contract muncul SEBELUM keputusan Mockup.

- [ ] **Step 4: Scenario walkthrough — app non-UI (degrade nol-biaya)**

Dry-run untuk app `api` (type be). Konfirmasi: bullet UI-Contract + bullet Mockup keduanya bergerbang "bila app punya permukaan UI" → di-SKIP; template `UI-Contract :` & `Mockup :` boleh "kosong". 
Expected: nol biaya, tak ada instruksi yang memaksa UI-Contract untuk app non-UI.

- [ ] **Step 5: Scenario walkthrough — jalur generate**

Dry-run jalur generate (`reference.md` §D): prasyarat design-system.md ada → dispatch `frontend-design` (UI-Contract + token) → simpan mockups/ → gate eyeball → isi Mockup. Konfirmasi degrade bila design-system.md kosong (ad-hoc + peringatan, tak ngarang fondasi).
Expected: alur lengkap, gate eyeball ada, degrade aman.

- [ ] **Step 6: Konfirmasi `build` sengaja tak diubah**

Run: `git diff --name-only main...HEAD`
Expected: TIDAK ada `plugin/skills/build/` di daftar. (build baca `plans/<app>.md` → UI-Contract masuk konteks tanpa edit; ini desain.)

- [ ] **Step 7: Commit penutup (bila ada perbaikan dari walkthrough) + ringkas**

Bila step 3–6 menemukan bug → perbaiki inline lalu commit `fix(plan): <ringkas>`. Bila bersih → tak perlu commit tambahan. Lalu laporkan ke user: ringkasan file yang berubah + saran langkah berikut (uji nyata: jalankan `/feature` dengan fitur UI di produk contoh, atau buka PR dari branch `feat/ui-contract-generation`).

---

## Self-Review (penulis plan — sudah dijalankan)

**1. Spec coverage:**
- §4 UI-Contract (format/lokasi/derivasi/idempotent/tampil-di-gate) → Task 1 §A + Task 3 (bullet) + Task 4 (template). ✅
- §5 Mockup 3-jalur → Task 1 §B + Task 3 (bullet). ✅
- §6 cross-check advisory + opacity → Task 1 §C + Task 3 (bullet a). ✅
- §7 generate via frontend-design + gate eyeball + mockup-reference → Task 1 §D + Task 2 (baca design-system.md) + Task 3 (bullet b). ✅
- §8 hilir: breakdown coverage + build konteks → Task 6 + Task 8 step 6 (build tak diubah by-design). ✅
- §9 edge/degrade → Task 1 §A/§D + Task 8 step 4–5. ✅
- §10 file disentuh → File Structure table + Task 1–7. ✅
- §11 keputusan terkunci → tercermin di isi edit (section bukan file; cross-check in; frontend-design dipinjam; mockup-reference). ✅
- §12 detail terkunci (format final/glance/coverage-bukan-palang) → Task 1 §A/§C + Task 6. ✅
- §3 round-trip → Task 1 §E + Task 3 (bullet). ✅

**2. Placeholder scan:** Tak ada TBD/TODO; semua edit menyertakan teks lama→baru lengkap. ✅

**3. Type/istilah consistency:** Nama konsisten lintas task — `UI-Contract` (section + baris template + coverage), slot `Mockup:`, `reference.md §A–§E`, `frontend-design`, "mockup-reference", "byte-opaque". Tak ada drift nama. ✅
