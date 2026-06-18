# Schema & Structure Awareness pada `build` — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tutup context-delivery gap yang bikin `build` hasilkan kode BE jelek — antarkan skema + struktur existing ke penulis kode, dan biarkan `breakdown` mentranskripsi keputusan reuse yang durable.

**Architecture:** Editan PROMPT/markdown pada skill context-vault (bukan kode runtime). Poros arsitek→mandor→tukang: `plan` pegang verdict reuse level-tabel (D5) → `breakdown` transkripsi ke field `reuse:` durable + putuskan struktur file (D2) → `build` controller (mandor) suntik slice skema + listing dir LIVE ke prompt implementer (D1) → implementer (tukang) nulis lawan realita → gate/review jaring drift (D4). `conventions.md` dapat slot query (D3); `wire` nge-seed proyeksi brownfield presence-based (D6).

**Tech Stack:** Markdown skill files di `/Users/stevanus/Developer/ai-boilerplate/plugin/` (context-vault). TIDAK ADA runtime/test executable — "verifikasi" tiap task = (a) assertion `rg`/grep bahwa teks instruksi baru hadir di anchor yang benar, (b) cek konsistensi lintas-file (referensi field/path tak yatim), (c) read-back koheren section + ~10 baris sekitarnya. Git untuk commit per task. Branch kerja: `feat/schema-structure-awareness` (sudah aktif).

**Spec sumber:** `docs/superpowers/specs/2026-06-18-schema-structure-awareness-build-design.md` (sudah di-commit `f5e8007`, diverifikasi adversarial 5 dimensi).

## Global Constraints

Setiap task tunduk pada invarian spec §3 (verbatim):
- **Nol kode di `tasks.yaml`.** Field `reuse:` = NAMA-only (tabel/file) + verb extend|create. JANGAN kolom/signature/SQL/line-range (itu VOLATILE, dibaca live oleh build).
- **Nol palang keras baru.** Semua tambahan = ADVISORY + show-at-gate (sejajar invariants-check & migration-impact yang sudah advisory). JANGAN bikin STOP/block baru.
- **Degrade no-op.** `control/schema/<unit>.md` absen/stub → bagian skema jadi no-op + warning; JANGAN crash/blokir.
- **Context-hemat & resumable.** Suntik proyeksi RINGKAS (1 baris/tabel) + listing dir di-cap; controller baca proyeksi LAZY per-task. JANGAN load penuh semua unit di depan.
- **Single-writer `control/schema/`.** HANYA `wire`/`build` yang invoke `rules/schema-projection.md`; JANGAN nulis `control/schema/` langsung dari skill lain. `upgrade` HARAM nyentuh knowledge.
- **Pertahankan voice skill existing** (Bahasa Indonesia teknis, istilah teknis Inggris — seperti file sekitarnya).
- **Editan markdown, bukan kode.** "TDD" klasik tak berlaku; tiap task diverifikasi via grep-assertion + read-back, lalu commit.

---

### Task 1: D3 — Slot `## Konvensi Query & Data-Access` di template conventions

**Files:**
- Modify: `plugin/template/control/conventions.md` (append section setelah "Konvensi Migrasi & Zero-Downtime", baris 12-17)

**Interfaces:**
- Consumes: —
- Produces: section bernama `## Konvensi Query & Data-Access` di template conventions, yang `architect` isi dan `build` paste ke tiap prompt implementer (`build/reference.md:23`). Task 5 & Task 6 (D1/D4) berasumsi disiplin query punya rumah durable di sini.

- [ ] **Step 1: Buka file & konfirmasi anchor**

Run: `cat -n plugin/template/control/conventions.md`
Expected: 3 section komentar — `## Konvensi Package` (baris 6), `## Konvensi Integrasi` (baris 9), `## Konvensi Migrasi & Zero-Downtime` (baris 12). File berakhir baris 17.

- [ ] **Step 2: Append section baru di akhir file**

Tambahkan PERSIS ini setelah baris terakhir (`(rules/migration-impact.md) bawa default generik bila section ini kosong. -->`):

```markdown

## Konvensi Query & Data-Access
<!-- Diisi architect: pola akses data app — reuse repository/query-layer existing vs raw SQL;
     index/unique di kolom lookup; ekspektasi no-N+1 / batch-load; default pagination.
     Di-paste build ke tiap prompt implementer (build/reference.md §B). Kosong = degrade no-op
     (default generik: ikuti pola data-access file existing terdekat / "pointer pola"). -->
```

- [ ] **Step 3: Verifikasi section hadir & template tetap valid**

Run: `rg -n "Konvensi Query & Data-Access" plugin/template/control/conventions.md`
Expected: 1 hit (heading baru).
Run: `rg -n "^## " plugin/template/control/conventions.md`
Expected: 4 heading sekarang (Package, Integrasi, Migrasi & Zero-Downtime, Query & Data-Access) — urutan benar, Query di paling bawah.

- [ ] **Step 4: Read-back koherensi**

Baca seluruh file. Konfirmasi: gaya komentar `<!-- Diisi ... -->` konsisten dengan 3 section lain; tak ada placeholder `<PRODUCT>` yang rusak; section baru tak menjanjikan palang (cuma "diisi architect / degrade no-op").

- [ ] **Step 5: Commit**

```bash
git add plugin/template/control/conventions.md
git commit -m "feat(conventions): slot Konvensi Query & Data-Access (D3)

Rumah durable disiplin query (repo-reuse/index/N+1/pagination) yang
di-paste build ke tiap prompt implementer. Kosong = degrade no-op."
```

---

### Task 2: D5 — `plan` paksa verdict reuse-vs-NEW + fallback proyeksi stub

**Files:**
- Modify: `plugin/skills/plan/SKILL.md` step 3 (baris 39-40, bullet baca-schema) dan template langkah 4 (baris 53, slot `Model/Schema`)

**Interfaces:**
- Consumes: `control/schema/<app>.md` (sudah dibaca plan, baris 39).
- Produces: verdict reuse-vs-NEW level-tabel di slot `Model/Schema` `plans/<app>.md` = **sumber tunggal** yang Task 3/4 (breakdown) transkripsi ke `reuse:`. Bentuk verdict per kebutuhan data: `reuse <Tabel>` ATAU `NEW <Tabel> (justify) + actions:migrate`.

- [ ] **Step 1: Konfirmasi anchor step 3**

Run: `sed -n '38,41p' plugin/skills/plan/SKILL.md`
Expected: baris 39 diawali "- **Baca `control/schema/<app>.md` (proyeksi skema durable, M4) DULU** sebagai baseline model data existing ... **JANGAN rekonstruksi skema dari nol**." dan baris 40 bullet "Dampak Skema Lintas-Fitur (H3)".

- [ ] **Step 2: Perkuat bullet baca-schema (step 3) — tambah verdict + fallback**

Ganti baris 39 (bullet "Baca control/schema ... DULU") jadi (pertahankan kalimat awal, tambah dua kalimat):

```markdown
- **Baca `control/schema/<app>.md` (proyeksi skema durable, M4) DULU** sebagai baseline model data existing (table/kolom/relasi/`Asal`) — **JANGAN rekonstruksi skema dari nol**. (Di-generate `wire`/`build`; read-only di sini.) **Keputusan reuse-vs-NEW (sumber tunggal):** untuk tiap kebutuhan data fitur ini, putuskan eksplisit **reuse tabel existing** (extend) **vs NEW** (tabel baru — justify kenapa tak bisa extend) dengan membandingkan ke baseline; tulis verdict di slot `Model/Schema` (langkah 4). Verdict ini otoritatif — `breakdown` (`reuse:`) cuma mentranskripsi, tak memutuskan ulang. **Fallback:** `control/schema/<app>.md` absen/stub padahal app jelas ber-DB → JANGAN anggap kosong = otoritatif; lakukan inventory ORM/migrasi nyata (atau arahkan jalankan `wire` yang me-regen proyeksi) sebelum mutusin NEW.
```

- [ ] **Step 3: Augment slot `Model/Schema` di template langkah 4**

Run: `sed -n '50,60p' plugin/skills/plan/SKILL.md`
Expected: fenced template berisi `Model/Schema : <...>` di baris 53.

Ganti baris `Model/Schema : <...>` jadi:

```markdown
Model/Schema : <per kebutuhan data: "reuse <Tabel>" (extend existing) ATAU "NEW <Tabel> (justify) + actions:migrate"; dibanding baseline control/schema/<app>.md>
```

- [ ] **Step 4: Verifikasi**

Run: `rg -n "reuse-vs-NEW|reuse <Tabel>|sumber tunggal" plugin/skills/plan/SKILL.md`
Expected: ≥2 hit (step 3 directive + template slot).
Run: `rg -n "Fallback:.*absen/stub" plugin/skills/plan/SKILL.md`
Expected: 1 hit.

- [ ] **Step 5: Read-back koherensi**

Baca step 3 (baris 38-48) penuh. Konfirmasi: verdict directive tak bentrok dengan bullet H3 (baris 40, yang soal ALTER tabel fitur lain) — keduanya komplementer (H3 = dampak ALTER lintas-fitur; verdict = reuse-vs-create untuk kebutuhan fitur ini). Tak ada palang baru (verdict = keputusan desain di gate plan yang sudah ada). Catatan baris 65 ("plan tetap FLAT") tetap akurat.

- [ ] **Step 6: Commit**

```bash
git add plugin/skills/plan/SKILL.md
git commit -m "feat(plan): verdict reuse-vs-NEW level-tabel + fallback stub (D5)

plan = pemilik verdict reuse-vs-create data-model (sumber tunggal);
breakdown mentranskripsi. Fallback inventory bila proyeksi absen/stub."
```

---

### Task 3: D2a — Field `reuse:` di skema `tasks.yaml` + preservasi re-breakdown

**Files:**
- Modify: `plugin/skills/breakdown/reference.md` §A skema (baris 7-47, tambah field `reuse:`) + §B granularity rules (baris ~52, batas NAMA-only)
- Modify: `plugin/skills/breakdown/SKILL.md` step 7 (baris 40, daftar metadata yang dipertahankan saat re-breakdown)

**Interfaces:**
- Consumes: —
- Produces: field `reuse:` (NAMA-only: `table:`/`file:`), KONTRAK yang dipakai Task 4 (breakdown nulis), Task 5 (build slice selection hint), Task 6 (gate cek dihormati). Aturan: `reuse:` dipertahankan saat re-breakdown (metadata).

- [ ] **Step 1: Konfirmasi anchor §A**

Run: `sed -n '13,47p' plugin/skills/breakdown/reference.md`
Expected: blok YAML skema task — ada `files:` (baris 17-20), `approach:` (21), `actions:` (22-28), `manual:` (29), `mockup:` (31), `test:` (33-35), `deps:` (36), `status:` (37).

- [ ] **Step 2: Tambah field `reuse:` ke skema YAML §A (setelah blok `files:`)**

Sisipkan PERSIS ini di antara blok `files:` (berakhir baris 20 `- test: ...`) dan baris `approach:` (21):

```yaml
        reuse:                     # OPSIONAL — keputusan DURABLE reuse existing (NAMA-only, BUKAN kode)
          - table: <nama tabel existing yang di-EXTEND, bukan bikin baru>   # ditranskripsi dari verdict plan (Model/Schema)
          - file:  <path file existing yang di-EXTEND, bukan bikin duplikat>
```

- [ ] **Step 3: Tambah aturan batas NAMA-only di §B**

Run: `sed -n '50,53p' plugin/skills/breakdown/reference.md`
Expected: baris 52 = "- **`files` = path saja.** Tidak ada potongan kode implementasi di `tasks.yaml`. Kode ditulis `build` per task (just-in-time, lawan kode terkini)."

Sisipkan bullet baru PERSIS setelah baris 52:

```markdown
- **`reuse:` = NAMA saja (durable, bukan kode).** Isi `reuse:` HANYA nama tabel + path file existing yang di-EXTEND (verb implisit extend) — **JANGAN** kolom/signature/SQL/line-range (itu VOLATILE, dibaca LIVE oleh `build` dari `control/schema/` + disk; lihat `files = path saja` di atas). WHY-reuse tinggal di **eksistensi proyeksi**, bukan di `tasks.yaml`. `reuse:` **ditranskripsi** dari verdict `Model/Schema` `plans/<app>.md` (jatah `plan`), bukan diputuskan ulang di sini; ragu → balik `plan`.
```

- [ ] **Step 4: Tambah `reuse:` ke daftar preservasi re-breakdown (SKILL.md step 7)**

Run: `sed -n '40,40p' plugin/skills/breakdown/SKILL.md`
Expected: baris 40 panjang, memuat "**Bila `tasks.yaml` sudah ada (re-breakdown):** JANGAN timpa buta ... Untuk task ber-`id` sama, **pertahankan `status`** ... ubah `files`/`approach`/`test` hanya bila plan-nya berubah ...".

Di kalimat itu, setelah frasa "**Pertahankan task `kind: fix` dan `kind: debt`**" — tambahkan klausa preservasi `reuse:` (EKSPLISIT, bukan analogi). Sisipkan kalimat ini tepat setelah "... yang **tak punya asal-`plan`** — JANGAN buang saat regenerate dari plan ...)" dan sebelum kalimat tentang task `done`:

```markdown
**Pertahankan metadata `reuse:`** (nama tabel/file existing yang di-extend) untuk task ber-`id` sama selama keputusan plan tak berubah — sejajar `status`/`kind`/`mockup:`; kalau dibuang saat re-breakdown, keputusan reuse hilang & build balik bikin tabel/file duplikat (failure mode yang fitur ini cegah).
```

- [ ] **Step 5: Tambah klausa preservasi cermin di §A (dekat `mockup:` metadata note)**

Run: `rg -n "mockup: = metadata seperti" plugin/skills/breakdown/reference.md`
Expected: 1 hit di §D-6 (baris ~177) — "`mockup:` = metadata seperti `kind:`/`actions:` → **dipertahankan saat re-breakdown** bila plan tak berubah (SKILL.md §7)."

Setelah definisi field `reuse:` di §A (Step 2), TIDAK perlu duplikasi panjang; cukup pastikan baris komentar `reuse:` di Step 2 sudah menyebut "DURABLE". (Preservasi otoritatif ada di SKILL.md §7 Step 4 + §B bullet Step 3 — itu cukup; jangan over-dokumentasi.)

Skip-able: bila mau simetri penuh dgn `mockup:`, tambah di §B bullet Step 3 akhir: " (`reuse:` = metadata → dipertahankan saat re-breakdown, SKILL.md §7)."

- [ ] **Step 6: Verifikasi konsistensi**

Run: `rg -n "reuse:" plugin/skills/breakdown/reference.md plugin/skills/breakdown/SKILL.md`
Expected: ≥3 hit — skema §A (Step 2), aturan §B (Step 3), preservasi SKILL §7 (Step 4).
Run: `rg -n "NAMA saja|NAMA-only|VOLATILE" plugin/skills/breakdown/reference.md`
Expected: ≥1 hit (batas name-only).

- [ ] **Step 7: Read-back koherensi**

Baca §A skema penuh (Step 2 hasil) + §B granularity (Step 3). Konfirmasi: `reuse:` ditandai OPSIONAL (tak memaksa tiap task); indentasi YAML konsisten (8 spasi, sejajar `files:`/`actions:`); batas name-only sejajar dengan aturan `files = path saja` existing; SKILL §7 kalimat baru menyatu (tak motong kalimat lama).

- [ ] **Step 8: Commit**

```bash
git add plugin/skills/breakdown/reference.md plugin/skills/breakdown/SKILL.md
git commit -m "feat(breakdown): field reuse: (NAMA-only) + preservasi re-breakdown (D2a)

Keputusan reuse durable di tasks.yaml: nama tabel/file yang di-extend.
Batas tegas name-only (no kode/volatile). Dipertahankan saat re-breakdown
(eksplisit di SKILL §7, sejajar status/kind/mockup)."
```

---

### Task 4: D2b — `breakdown` baca proyeksi + step keputusan reuse + coverage check

**Files:**
- Modify: `plugin/skills/breakdown/SKILL.md` step 1 (baris 15, read-set), step 3 (baris 20-21, enrich → tambah konsultasi schema), step 4 (baris 23-31, coverage → tambah reuse-before-create)

**Interfaces:**
- Consumes: field `reuse:` + aturan name-only (Task 3); verdict `Model/Schema` dari `plans/<app>.md` (Task 2).
- Produces: `tasks.yaml` task BE membawa `files: modify` (vs create) + `reuse:` saat ada padanan existing; peta coverage reuse di gate.

- [ ] **Step 1: Konfirmasi anchor step 1 (read-set)**

Run: `sed -n '14,15p' plugin/skills/breakdown/SKILL.md`
Expected: baris 15 diawali "Baca `control/features/<fitur>/plans/_shared.md` + `plans/<pkg>.md` + `plans/<app>.md` + `fanout.md` (untuk Urutan lintas-app) + `control/workspace.yaml` (app/path/stack + `packages[]`/`consumers`)."

- [ ] **Step 2: Tambah `control/schema/` ke read-set step 1**

Di baris 15, setelah "`control/workspace.yaml` (app/path/stack + `packages[]`/`consumers`)" sisipkan:

```markdown
 + `control/schema/<app>.md` (proyeksi skema durable per app — baseline tabel existing, read-only; absen/stub → degrade, lihat step 3)
```

- [ ] **Step 3: Tambah konsultasi schema + keputusan reuse di step 3 (enrich)**

Run: `sed -n '20,21p' plugin/skills/breakdown/SKILL.md`
Expected: baris 20 = "### 3. Enrich tiap task", baris 21 mulai "Isi tiap task: `files` ... `approach` ... `test` ...".

Sisipkan paragraf baru PERSIS setelah baris 21 (sebelum "### 4. Coverage check"):

```markdown

**Reuse-aware (sebelum nulis `files`):** untuk task yang nyentuh data/file, konsultasi `control/schema/<app>.md` (tabel existing) + lirik ringan dir target (file existing). **Transkripsi** verdict `Model/Schema` `plans/<app>.md` (reuse `<Tabel>` vs NEW) ke task: padanan existing → `files: modify` (bukan `create`) + isi `reuse: [table: <T>, file: <f>]` (NAMA-only, `reference.md` §B). `breakdown` MELIHAT dir untuk memutuskan path mana di-extend, tapi **TIDAK mencatat listing dir** ke `tasks.yaml` (listing disuntik LIVE oleh `build`, D1). Default condong extend/modify bila ada padanan; ragu (verdict plan tak jelas) → balik `plan`, jangan diam-diam `create`. Degrade: `control/schema/<app>.md` absen/stub → lewati konsultasi tabel (tetap lirik dir), no-op.
```

- [ ] **Step 4: Tambah baris reuse-before-create di coverage check step 4**

Run: `sed -n '29,29p' plugin/skills/breakdown/SKILL.md`
Expected: baris 29 = bullet "**Invarian:** tiap task yang nyentuh skema/endpoint patuh `control/invariants.md` ... **Mandatory package (M2):** ...".

Sisipkan bullet baru PERSIS setelah baris 29 (sebelum bullet "Fan-IN coverage"):

```markdown
- **Reuse-before-create (advisory — cermin Invarian di atas).** Tiap task skema **sebut NAMA tabel/file existing yang di-extend** (`reuse:`). Flag task yang usul **tabel/file BARU yang entitas-nya overlap existing** di `control/schema/<app>.md` / dir target (mis. task bikin `users` padahal `users` ada; bikin `users.go` padahal `user.go` ada) → minta justify atau redirect ke reuse. Tampilkan **peta reuse→task** di gate (di samping peta plan→task). **Tampil-di-gate, BUKAN palang** (sejajar coverage Model/Schema) — selisih disodorkan ke user, tak memblokir.
```

- [ ] **Step 5: Verifikasi**

Run: `rg -n "control/schema|Reuse-aware|Reuse-before-create|reuse→task" plugin/skills/breakdown/SKILL.md`
Expected: ≥4 hit (read-set step 1, enrich step 3, coverage step 4 + peta).
Run: `rg -n "TIDAK mencatat listing dir" plugin/skills/breakdown/SKILL.md`
Expected: 1 hit (jaga: dir = decision-only, bukan recorded).

- [ ] **Step 6: Read-back koherensi**

Baca step 1 (14-16), step 3 (20-22+sisipan), step 4 (23-32). Konfirmasi: read-set baru menyatu di kalimat baca-input; paragraf reuse-aware tak menduplikasi field schema (itu di reference.md); coverage bullet sejajar gaya bullet lain (advisory, tampil-di-gate); konsisten dgn presedensi "plan mutusin, breakdown transkripsi".

- [ ] **Step 7: Commit**

```bash
git add plugin/skills/breakdown/SKILL.md
git commit -m "feat(breakdown): baca proyeksi skema + transkripsi reuse + coverage (D2b)

Step 1 baca control/schema; step 3 transkripsi verdict plan ke reuse:/
files:modify; step 4 reuse-before-create advisory (flag tabel/file baru
yang overlap existing). Degrade no-op bila proyeksi absen."
```

---

### Task 5: D1 — `build` antarkan slice skema + listing dir ke prompt implementer

**Files:**
- Modify: `plugin/skills/build/SKILL.md` step 1 (baris 15, read-set lazy) + step 3 (baris 32, rakit prompt)
- Modify: `plugin/skills/build/reference.md` §B (baris ~24, sisip blok prompt setelah "Konvensi & stack")

**Interfaces:**
- Consumes: `control/schema/<unit>.md` (proyeksi); field `reuse:` + `actions.affects` (Task 3) sebagai selection hint slice.
- Produces: blok prompt "SKEMA & STRUKTUR EXISTING" yang dilihat implementer (tukang) saat nulis. Task 6 (gate) berasumsi blok ini ada.

- [ ] **Step 1: Konfirmasi anchor §B**

Run: `sed -n '23,24p' plugin/skills/build/reference.md`
Expected: baris 23 = "- **Konvensi & stack:** dari `conventions.md` + `workspace.yaml` `stack` app." dan baris 24 = "- **Pointer pola:** tunjuk 1-2 file existing sebagai contoh gaya (mis. route sejenis).".

- [ ] **Step 2: Sisip blok prompt baru di §B (antara "Konvensi & stack" dan "Pointer pola")**

Sisipkan PERSIS ini di antara baris 23 dan baris 24:

```markdown
- **Skema & struktur existing (WAJIB bila `unit ∈ apps[]` & `control/schema/<unit>.md` non-stub) — otoritatif, reuse jangan duplikat:** paste **slice skema relevan** + **listing dir target**, lalu directive reuse.
  - **Slice skema** = fail-open UNION dibaca LIVE: tabel di `reuse:` ∪ tabel di `actions.affects` ∪ FK-neighbor (dari `control/schema/<unit>.md`) dari tabel mana pun yang disebut — di-cap ~15 tabel; format ringkas proyeksi (kolom·tipe·key·FK). `reuse:` = SELECTION HINT, **bukan** filter otoritatif (over-include murah & aman; under-include malah ngalahin tujuan) → `reuse:` basi/parsial TIDAK fatal.
  - **Listing dir** = file yang sudah ada di tiap dir pada `files` task (mis. `internal/user/` → `user.go, repo.go, …`), **di-cap ~30 entri** (lebih → ringkas + hitung) biar dir gede tak membanjiri prompt.
  - **Directive:** *"Tabel & file ini SUDAH ADA — reuse/extend; JANGAN bikin tabel paralel atau file duplikat (mis. ada `user.go` → tambahin di situ, bukan `users.go`). Fakta kolom/FK/index di sini otoritatif."*
  - **Degrade:** `control/schema/<unit>.md` absen/stub → blok jadi listing-dir saja + warning; lanjut (no-op bagian skema). `unit` = package/`integration`/FE tanpa proyeksi → skip otomatis.
```

- [ ] **Step 3: Konfirmasi anchor build/SKILL.md step 1 (read-set)**

Run: `sed -n '14,14p' plugin/skills/build/SKILL.md`
Expected: baris 14 (step 1) memuat "Baca `<work-item>/tasks.yaml` ... + `control/conventions.md` + `control/workspace.yaml` (path/stack).".

- [ ] **Step 4: Tambah read lazy `control/schema/` di build/SKILL.md step 1**

Di baris 14, setelah "+ `control/workspace.yaml` (path/stack)." sisipkan kalimat (sebelum "**Prasyarat:**"):

```markdown
 Baca `control/schema/<unit>.md` **LAZY per-task** (hanya slice yang akan di-paste untuk task berjalan, `reference.md` §B — bukan load penuh semua unit di depan; jaga sesi build ramping & resumable).
```

- [ ] **Step 5: Tambah penyebutan blok skema di build/SKILL.md step 3 (rakit prompt)**

Run: `rg -n "pointer file pola" plugin/skills/build/SKILL.md`
Expected: 1 hit di baris 32 — "Rakit prompt LENGKAP dari task (paste teks task ...): `desc` + `files` + `approach` + kasus `test` + potongan `_shared.md` + konvensi + stack + pointer file pola + **(bila ...mockup...)**".

Di baris 32, setelah "+ konvensi + stack +" dan sebelum "pointer file pola", sisipkan: `+ **(bila unit app & proyeksi non-stub) blok skema & struktur existing (slice control/schema/<unit>.md + listing dir + directive reuse, `reference.md` §B)** `.

- [ ] **Step 6: Verifikasi**

Run: `rg -n "Skema & struktur existing|fail-open UNION|SELECTION HINT" plugin/skills/build/reference.md`
Expected: ≥3 hit (blok §B).
Run: `rg -n "control/schema/<unit>.md|LAZY per-task|blok skema" plugin/skills/build/SKILL.md`
Expected: ≥2 hit (step 1 lazy read + step 3 rakit prompt).

- [ ] **Step 7: Read-back koherensi**

Baca §B (baris 15-43) penuh. Konfirmasi: blok baru duduk di antara "Konvensi & stack" & "Pointer pola"; konsisten dgn gaya bullet existing (mis. "Signature dep (WAJIB bila ada `deps`)"); degrade & scope-skip eksplisit; tak mengubah aturan "subagent TIDAK membaca file plan" (baris 13) — kita paste konten, bukan suruh baca. build/SKILL.md baris 8 & 55 (context-hemat) tetap akurat (lazy + cap).

- [ ] **Step 8: Commit**

```bash
git add plugin/skills/build/SKILL.md plugin/skills/build/reference.md
git commit -m "feat(build): antarkan slice skema + listing dir ke implementer (D1)

Mandor nyodorin denah ke tukang: blok prompt 'skema & struktur existing'
(slice union fail-open, cap ~15 tabel + listing dir cap ~30) + directive
reuse. Controller baca proyeksi lazy per-task. Degrade no-op."
```

---

### Task 6: D4 — Jaring redundant-table/file + query di gate & reviewer baseline

**Files:**
- Modify: `plugin/skills/build/SKILL.md` step 6 (baris 48, challenge checklist) + step 4 (baris 42, dispatch reviewer)

**Interfaces:**
- Consumes: `reuse:` (Task 3), slice skema (Task 5), `control/schema/<unit>.md`.
- Produces: 3 baris challenge checklist + reviewer dibekali baseline skema. Jaring akhir advisory.

- [ ] **Step 1: Konfirmasi anchor step 6 checklist**

Run: `rg -n "challenge checklist" plugin/skills/build/SKILL.md`
Expected: 1 hit di baris 48 — "...**challenge checklist** (termasuk: ada yang melanggar invarian terkunci di `control/invariants.md`? ada yang membypass mandatory package di `packages[].mandatory_for`? **untuk task ber-`mockup:` — hasil render UI cocok dengan mockup, layout + animasi? (eyeball + buka app)**) → minta **approve/revisi**.".

- [ ] **Step 2: Tambah 3 item redundancy/query ke challenge checklist**

Di baris 48, di dalam kurung "(termasuk: ...)", setelah item mockup dan sebelum "→ minta **approve/revisi**", sisipkan:

```markdown
 **redundant-table — ada `CREATE TABLE` di diff yang entitas-nya duplikat tabel existing di `control/schema/<unit>.md`?** **redundant-file — ada file baru yang duplikat file existing (mis. `users.go` vs `user.go`, by entity-equivalence BUKAN sekadar nama mirip)? `reuse:` task dihormati (extend, bukan create)?** **query — data-access reuse repo/query-layer existing & hindari N+1/lookup tak-terindeks?**
```

- [ ] **Step 3: Konfirmasi anchor step 4 (dispatch reviewer)**

Run: `sed -n '42,42p' plugin/skills/build/SKILL.md`
Expected: baris 42 — "Lalu dispatch **spec-reviewer** (\"verifikasi dengan baca kode, jangan percaya report\") → bila lulus, **code-quality-reviewer**. ...".

- [ ] **Step 4: Bekali reviewer dengan baseline skema**

Di baris 42, setelah "Lalu dispatch **spec-reviewer** (\"verifikasi dengan baca kode, jangan percaya report\")" sisipkan klausa:

```markdown
 — **bekali kedua reviewer slice `control/schema/<unit>.md` + listing dir yang disentuh (baseline yang sama dengan prompt implementer, `reference.md` §B)** supaya bisa deteksi tabel/file redundant vs existing —
```

- [ ] **Step 5: Verifikasi**

Run: `rg -n "redundant-table|redundant-file|entity-equivalence" plugin/skills/build/SKILL.md`
Expected: ≥2 hit (checklist).
Run: `rg -n "bekali kedua reviewer slice" plugin/skills/build/SKILL.md`
Expected: 1 hit (step 4).

- [ ] **Step 6: Read-back koherensi**

Baca step 4 (38-42) + step 6 (47-48). Konfirmasi: item baru menyatu di dalam kurung checklist existing (advisory, bagian "approve/revisi" — bukan floor baru); redundant-file pakai "entity-equivalence BUKAN sekadar nama mirip" (hindari false-positive `user.go` vs `useragent.go`); klausa reviewer tak memecah kalimat dispatch lama. Konsisten dgn unattended (baris 48 floor-scan TIDAK berubah — ini cuma item challenge checklist yang sudah ada).

- [ ] **Step 7: Commit**

```bash
git add plugin/skills/build/SKILL.md
git commit -m "feat(build): jaring redundant-table/file + query di gate & reviewer (D4)

Challenge checklist step 6 + 3 item (redundant table/file by
entity-equivalence, query reuse/N+1); reviewer dibekali baseline skema.
Advisory, bukan floor baru; floor-scan unattended tak berubah."
```

---

### Task 7: D6a — `wire` nge-seed proyeksi brownfield (presence-based)

**Files:**
- Modify: `plugin/skills/wire/SKILL.md` step 3 (baris 37, generalisasi sumber skema) + step 0 (baris 23-24, brownfield presence-seed)
- Modify: `plugin/skills/wire/reference.md` §F (baris 50-54, brownfield idempotency)

**Interfaces:**
- Consumes: `rules/schema-projection.md` (sudah ada — invoke; single-writer dihormati); `workspace.yaml` `stack` (orm + path).
- Produces: `control/schema/<app>.md` ter-seed dari sumber existing untuk app brownfield — bikin D1/D2/D5 berguna di repo lama.

- [ ] **Step 1: Konfirmasi anchor step 3 (proyeksi note)**

Run: `sed -n '36,37p' plugin/skills/wire/SKILL.md`
Expected: baris 37 = "### 3. Konek BE↔DB ... **Proyeksi skema (M4):** lalu generate `control/schema/<app>.md` awal per `...schema-projection.md` (`label=<none>`) — file lahir (header proyeksi; nol/baseline table) supaya `plan` tak pernah kena file-absen.".

- [ ] **Step 2: Generalisasi sumber skema di step 3 (ORM atau migrasi raw-SQL)**

Di baris 37, pada kalimat "Proyeksi skema (M4)", ganti frasa "generate `control/schema/<app>.md` awal" jadi:

```markdown
generate `control/schema/<app>.md` dari **sumber skema existing** (ORM **atau** folder migrasi raw-SQL — `schema-projection.md` lokalisasi by-understanding, TANPA DB hidup)
```

- [ ] **Step 3: Tambah brownfield presence-seed di step 0**

Run: `sed -n '23,24p' plugin/skills/wire/SKILL.md`
Expected: baris 23 (### 0. Baca state) berakhir "...ada kode → **brownfield (repair: lengkapi yang kurang, idempotent, jangan timpa)**.".

Sisipkan kalimat PERSIS setelah baris 23 (sebelum bullet "Unit `type: package`"):

```markdown
- **Seed proyeksi skema (brownfield, presence-based):** untuk tiap app dengan sumber skema (ORM atau folder migrasi raw-SQL) yang `control/schema/<app>.md`-nya **absen/stub**, invoke `${CLAUDE_PLUGIN_ROOT}/rules/schema-projection.md` (`label=(pra-M4)`) buat seed dari sumber existing — **di-gate pada KEBERADAAN proyeksi, BUKAN status ter-wire** (app sudah ter-wire tapi proyeksi belum lahir TETAP di-seed; kalau tidak, step 3 yang no-op pada already-wired bikin proyeksi tetap kosong → ngalahin D1/D2/D5 di repo lama). `stack.orm` kosong **dan** tak ada folder migrasi → tulis stub + **warning** (app uncovered), jangan no-op diam. Idempoten (proyeksi sudah ada & current → skip).
```

- [ ] **Step 4: Tambah klausa presence-seed di reference §F (brownfield)**

Run: `sed -n '50,54p' plugin/skills/wire/reference.md`
Expected: §F bullet — baris 52 "Deteksi state per app: ... sudah ter-wire → **no-op**, lapor." dan baris 53 "Idempotent: re-run ... Jangan timpa kode / `.env` / migrasi existing.".

Sisipkan bullet baru PERSIS setelah baris 53 (sebelum baris 54 "`wire(repair)` = pasangan operasional..."):

```markdown
- **Proyeksi skema = presence-based, lepas dari status-wired:** "no-op pada sudah-ter-wire" berlaku untuk scaffold/DB/FE↔BE — TAPI `control/schema/<app>.md` yang **absen/stub** TETAP di-seed dari sumber existing (SKILL §0), karena proyeksi yang hilang ≠ wiring yang lengkap. Sejajar prinsip repair "lengkapi yang kurang". Single-writer dihormati: `wire` **invoke** `schema-projection.md`, tak nulis `control/schema/` langsung.
```

- [ ] **Step 5: Verifikasi**

Run: `rg -n "presence-based|presence-seed|absen/stub" plugin/skills/wire/SKILL.md plugin/skills/wire/reference.md`
Expected: ≥2 hit (SKILL step 0 + reference §F).
Run: `rg -n "schema-projection" plugin/skills/wire/SKILL.md`
Expected: ≥2 hit (step 0 seed + step 3 existing) — semua via invoke (single-writer).

- [ ] **Step 6: Read-back koherensi**

Baca step 0 (22-25) + step 3 (36-37) + reference §F (50-54). Konfirmasi: seed = invoke (bukan nulis langsung — single-writer); presence-gate jelas beda dari wiring-status; raw-SQL ditangani; degrade (no orm + no migrasi → stub+warning) selaras `schema-projection.md:15`; tak melanggar prinsip wire "TIDAK bikin table fitur" (ini cuma proyeksi/read).

- [ ] **Step 7: Commit**

```bash
git add plugin/skills/wire/SKILL.md plugin/skills/wire/reference.md
git commit -m "feat(wire): seed proyeksi skema brownfield presence-based (D6a)

Seed control/schema/ dari sumber existing (ORM/migrasi raw-SQL) di-gate
pada KEBERADAAN proyeksi (bukan status-wired) — app already-wired tapi
proyeksi stub tetap di-seed. Invoke schema-projection (single-writer)."
```

---

### Task 8: D6b — `upgrade` arahkan ke `wire` untuk seed (nol-sentuh-knowledge)

**Files:**
- Modify: `plugin/skills/upgrade/SKILL.md` step 4 (baris 49, saran langkah lanjut)

**Interfaces:**
- Consumes: D6a (`wire` yang nge-seed — Task 7) sebagai tujuan arahan.
- Produces: satu baris saran di `upgrade` (TIDAK nge-seed sendiri; charter nol-sentuh-knowledge tetap utuh).

- [ ] **Step 1: Konfirmasi anchor step 4 & guardrail**

Run: `sed -n '49,49p' plugin/skills/upgrade/SKILL.md`
Expected: baris 49 = "- File `control/` baru lahir kosong (mis. `invariants.md`) → arahkan skill pemiliknya (`/architect` dll) untuk mengisinya.".
Run: `sed -n '33,33p' plugin/skills/upgrade/SKILL.md`
Expected: baris 33 memuat carve-out "`control/schema/` di-generate runtime oleh `wire`/`build` ... jangan disync di sini.".

- [ ] **Step 2: Tambah bullet arahan seed (pakai pola "arahkan skill pemilik" existing)**

Sisipkan bullet baru PERSIS setelah baris 49:

```markdown
- **`control/schema/` absen/stub pada app ber-DB (produk lama belum punya proyeksi)** → `upgrade` **TIDAK nge-seed** (charter nol-sentuh-knowledge; proyeksi = runtime-generated, lihat step 1). Cukup **ARAHKAN** user jalankan `wire` (brownfield-repair nge-seed proyeksi dari sumber existing, presence-based) — pola arahkan-skill-pemilik yang sama dgn baris di atas.
```

- [ ] **Step 3: Verifikasi**

Run: `rg -n "control/schema/ absen/stub|TIDAK nge-seed|ARAHKAN user jalankan .wire." plugin/skills/upgrade/SKILL.md`
Expected: 1 hit (bullet baru).
Run: `rg -n "schema-projection|nulis control/schema" plugin/skills/upgrade/SKILL.md`
Expected: 0 hit (upgrade TIDAK invoke/nulis — cuma arahkan).

- [ ] **Step 4: Read-back koherensi**

Baca step 4 (44-49) + Guardrails (51-55). Konfirmasi: bullet baru konsisten dgn carve-out baris 33 & guardrail "Nol sentuh knowledge" (baris 52) — upgrade cuma ARAHKAN, tak nge-seed/nulis; pola sejajar bullet "file control/ baru lahir kosong → arahkan pemilik". Tak ada kontradiksi.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/upgrade/SKILL.md
git commit -m "feat(upgrade): arahkan ke wire untuk seed proyeksi (D6b)

upgrade TIDAK nge-seed (charter nol-sentuh-knowledge); bila produk lama
punya control/schema/ absen/stub di app ber-DB → arahkan jalankan wire."
```

---

### Task 9: Integration verification — trace worked-example + sweep konsistensi lintas-file

**Files:**
- (read-only verification; no edits unless a gap found)

**Interfaces:**
- Consumes: semua Task 1-8.
- Produces: bukti bahwa rantai arsitek→mandor→tukang nyambung end-to-end + tak ada referensi yatim.

- [ ] **Step 1: Sweep konsistensi `reuse:` lintas-file**

Run: `rg -n "reuse:" plugin/skills/breakdown plugin/skills/build`
Expected: definisi (breakdown/reference.md §A), penulis (breakdown/SKILL.md step 3-4), pembaca/hint (build/reference.md §B slice + build/SKILL.md step 6 gate). Konfirmasi nama field identik (`reuse:` dgn sub-key `table:`/`file:`) di semua tempat — tak ada varian (`reuses:`/`reuse_tables:`).

- [ ] **Step 2: Sweep `control/schema/` reader/writer**

Run: `rg -n "control/schema" plugin/skills plugin/rules`
Expected: WRITER hanya via invoke `schema-projection.md` (wire step 0+3, build step 3 regen). READER: plan (step 3), breakdown (step 1), build (step 1 lazy + reviewer), migration-impact. upgrade = 0 hit nulis/invoke (cuma arahkan, teks "wire ... seed"). Konfirmasi tak ada skill selain wire/build yang INVOKE schema-projection (single-writer).

- [ ] **Step 3: Trace worked-example (spec §5) secara manual**

Telusuri skenario `users`/`user.go` lewat teks skill hasil edit:
1. `plan` (Task 2): verdict `Model/Schema: reuse users` (extend) — apakah directive step 3 menghasilkan ini? ✓ bila reuse-vs-NEW directive ada.
2. `breakdown` (Task 4): transkripsi → `files: modify internal/user/user.go` + `reuse:[table: users, file: internal/user/user.go]`; coverage flag bila ada `create users`. ✓
3. `build` (Task 5): prompt implementer memuat slice `users` (union) + listing `internal/user/` + directive "extend, jangan duplikat". ✓
4. gate (Task 6): checklist cek tak ada `CREATE TABLE users`/`users.go` baru; `reuse:` dihormati. ✓
5. brownfield (Task 7): bila repo lama, `wire` sudah nge-seed `control/schema/api.md` presence-based sebelum langkah 1-4. ✓

Tulis hasil trace (1 paragraf) ke report. Bila ada mata rantai yang teksnya TIDAK mendukung langkah di atas → itu gap; perbaiki di task terkait lalu re-commit.

- [ ] **Step 4: Spec-coverage cross-check**

Buka spec `docs/superpowers/specs/2026-06-18-schema-structure-awareness-build-design.md` §4 (D1-D6) + dimensi file-level + §8 success criteria. Untuk tiap D & tiap success criterion, tunjuk task plan yang mengimplementasikannya:
- D1→Task 5; D2→Task 3+4; D3→Task 1; D4→Task 6; D5→Task 2; D6→Task 7+8; file-level→Task 3(reuse file:)+5(listing)+6(gate). Success criteria 1-6 → ter-cover.
Daftar gap bila ada criterion tanpa task.

- [ ] **Step 5: Degrade & scope sanity (grep negatif)**

Run: `rg -n "palang|STOP" plugin/skills/build/SKILL.md plugin/skills/breakdown/SKILL.md | rg -i "redundant|reuse|schema slice"`
Expected: 0 hit — konfirmasi tak ada palang/STOP baru yang nyangkut di fitur ini (semua advisory). Bila ada → langgar Global Constraint, perbaiki.

- [ ] **Step 6: Final commit (report)**

```bash
git add -A
git commit -m "test(schema-awareness): integration verification — trace + sweep konsistensi (Task 9)

Worked-example users/user.go nyambung end-to-end; reuse:/control-schema
konsisten lintas-file; single-writer terjaga; nol palang baru."
```

---

## Self-Review (writing-plans checklist — dijalankan penulis plan)

**1. Spec coverage:** D1→T5, D2→T3+T4, D3→T1, D4→T6, D5→T2, D6→T7+T8, dimensi file-level→T3/T5/T6. Success criteria §8 (1-6) ter-cover; cold-start brownfield (criterion 4) → T7 presence-based. **Tak ada D/criterion tanpa task.**

**2. Placeholder scan:** Tiap step "Modify" punya anchor exact (`sed -n`/`rg` konfirmasi) + teks markdown exact untuk disisipkan. Tak ada "TBD"/"sesuaikan"/"dst". Step 5 Task 3 ditandai skip-able eksplisit (bukan placeholder — itu keputusan YAGNI sadar).

**3. Type/contract consistency:** Field `reuse:` (sub-key `table:`/`file:`) dipakai identik di T3 (definisi), T4 (penulis), T5 (slice hint), T6 (gate), T9 (sweep). `control/schema/<unit|app>.md` path konsisten (`<unit>` di build, `<app>` di plan/breakdown/wire — sesuai konvensi existing tiap skill). `schema-projection.md` selalu di-INVOKE (single-writer), tak pernah ditulis langsung.

**Catatan eksekusi:** Task 1-2 independen (boleh paralel). T3 → T4 → T5 → T6 berurut (kontrak `reuse:` + slice mengalir). T7 independen; T8 deps T7. T9 terakhir (deps semua).
