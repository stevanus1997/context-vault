# Lane Bugfix `fix` — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tambah skill `fix` (lane korektif dua-mode) + generalisasi `build`/`ship`/`breakdown`/`render-docs` agar bisa bekerja pada work-item fitur ATAU fix.

**Architecture:** Satu skill `fix` (konduktor) auto-deteksi mode dari status target: **in-flight** (fitur `active` → corrective task `kind: fix` numpang di `tasks.yaml` fitur, eksekusi lewat `build`) vs **post-ship** (fitur `shipped`/tanpa-fitur → `control/fixes/<id>/` first-class). Loop dalam (reproduce → root-cause → TDD fix → verify) di-dispatch ke subagent; `fix` berhenti di ijo, `/ship` selalu terpisah. `build`/`ship` di-generalisasi menerima manifest `feature.yaml` ATAU `fix.yaml`.

**Tech Stack:** Plugin Claude Code berbasis **markdown** (`SKILL.md` + `reference.md` + `template.html`) — TIDAK ada kode/test harness. Karena itu tiap task memakai **langkah verifikasi struktural** (`grep`/cek cross-ref/baca) sebagai ganti unit test, dan commit per task.

**Spec:** `docs/superpowers/specs/2026-06-02-fix-bugfix-lane-design.md` (sudah lewat pass `critic`).

**Catatan eksekusi:** Kerjakan di branch `feat/fix-bugfix-lane` (spec sudah ter-commit di sana). Setiap task = satu commit. Bahasa konten = Indonesian, match house-style skill existing (terse, bold-marker, numbered).

---

## File Map

**Buat baru:**
- `plugin/skills/fix/SKILL.md` — konduktor: deteksi mode + triage + prosedur dua mode.
- `plugin/skills/fix/reference.md` — skema `fix.yaml`, skema `tasks.yaml`-fix, dispatch deltas (reproduce/root-cause subagent), drop self-handle.
- `plugin/template/control/fixes/.gitkeep` — direktori entitas fix di template produk.

**Modifikasi:**
- `plugin/skills/build/SKILL.md` — manifest work-item (15), staleness baseline (16), embed disiplin fix di gate merah (46), metadata `kind`/`corrects`/`observed`, aturan konteks/`_shared.md` fix.
- `plugin/skills/ship/SKILL.md` — manifest+unit dari `fix.yaml` (12–13), contract test fix lintas-unit (3), sensitivity dari `fix.yaml` (4.5), PR desc + set status (6), guard (50).
- `plugin/skills/breakdown/SKILL.md` — step 7 pertahankan task `kind: fix` tanpa asal-plan.
- `plugin/skills/render-docs/SKILL.md` + `plugin/skills/render-docs/template.html` — section "Riwayat Fix / Known Issues".
- `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` — induk §7/§12/§17.
- `README.md` — lifecycle + commands.
- `plugin/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — deskripsi.

**TIDAK disentuh** (keputusan spec): `drop` (fix self-handle dropped, bukan `drop <fix-id>`), `feature`, `intake`, `fanout`, `plan`, `add-*`, `invariants.md` template (cuma titik-baca baru, bukan perubahan file).

---

## Task 1: Template direktori `control/fixes/`

**Files:**
- Create: `plugin/template/control/fixes/.gitkeep`

- [ ] **Step 1: Buat file kosong**

```bash
touch plugin/template/control/fixes/.gitkeep
```

- [ ] **Step 2: Verifikasi**

Run: `ls -la plugin/template/control/fixes/ && ls plugin/template/control/`
Expected: `.gitkeep` ada di `fixes/`; `fixes/` muncul sejajar `features/` di `control/`.

- [ ] **Step 3: Commit**

```bash
git add plugin/template/control/fixes/.gitkeep
git commit -m "feat(template): control/fixes/ dir (entitas fix first-class, sejajar features/)"
```

---

## Task 2: `fix/reference.md` — skema + dispatch deltas

**Files:**
- Create: `plugin/skills/fix/reference.md`

- [ ] **Step 1: Tulis file**

Tulis `plugin/skills/fix/reference.md` PERSIS:

````markdown
# fix — Reference (skema `fix.yaml` + `tasks.yaml`-fix + dispatch deltas)

Dibaca oleh skill `fix`. SKILL.md tetap ramping; detail skema & template ada di sini. Sebagian besar mesin eksekusi **dipinjam dari `build`** — lihat `${CLAUDE_PLUGIN_ROOT}/skills/build/reference.md` (rakit prompt §B, gate §D, resume §E). File ini hanya menulis **delta khas-fix**.

## A. Skema `fix.yaml` (mode post-ship)

```yaml
id: <slug>                   # mis. kupon-expired
status: open                 # open → diagnosed → shipped (+ dropped)
severity: normal             # normal | urgent  (metadata: urutan render-docs + sinyal)
reported_at: <YYYY-MM-DD>
reported: "<gejala dari user, 1 baris>"
relates_to: [<nama-fitur>]   # array; boleh >1; boleh [] (bug di shared util / skeleton wire)
flow: <nama-flow>            # link ke business/flows.md (boleh kosong)
units: [<app/pkg>]           # app/package kena (inferensi + KONFIRMASI user) — basis branch & gate
sensitivity: ""              # HASIL RE-EVALUASI vs invariants.md (lihat §D) — BUKAN warisan pasif
root_cause: ""               # diisi saat diagnosed
knowledge_touched: []        # mis. ["business/flows.md"] bila triage cabang-3 koreksi doc
fix_pr: ""                   # diisi saat shipped (oleh ship)
shipped_at: ""               # diisi saat shipped (oleh ship)
reason: ""                   # diisi saat dropped
```

## B. Skema `tasks.yaml` untuk fix

**WAJIB skema yang SAMA** dengan `breakdown` (`${CLAUDE_PLUGIN_ROOT}/skills/breakdown/reference.md` §A) — yaitu **milestone-wrapped** (`milestones[].tasks[]`), supaya hard-guard `build` (iterasi per-milestone) tidak mismatch. JANGAN list task flat.

- **mode post-ship** → tulis ke `control/fixes/<id>/tasks.yaml`: satu milestone `id: FIX`, `title: <slug>`, isi 1–3 task. Task `unit` = app/package dari `fix.yaml.units`. Lintas-unit → tambah task `unit: integration` (roundtrip) + tulis `_shared.md` mini **wajib**.
- **mode in-flight** → **append** task ke `control/features/<fitur>/tasks.yaml` yang sudah ada, ke dalam milestone task `corrects`-nya (atau milestone `FIX` baru bila tak jelas). Tiap task fix bawa field tambahan:

```yaml
- id: fix-<slug>
  kind: fix                  # default task TANPA kind = implicit "feat"; ini penanda korektif
  corrects: <id-task-asal>   # task yang hasilnya meleset (traceability) — boleh kosong utk gap
  observed: "<apa yang menyimpang dari plan/business>"
  unit: <app/pkg>
  files: [ ... ]             # seperti task biasa
  approach: "reproduce dulu (<test>), baru perbaiki"
  test: ["<kasus regresi yang harus lulus>"]
  deps: []
  status: pending
```

`build` memperlakukan `kind`/`corrects`/`observed` sebagai **metadata** (traceability) — tidak mengubah eksekusi.

## C. Dispatch deltas (semua kerja berat → subagent; konduktor cuma simpan kesimpulan)

1. **Reproduce (subagent).** Dispatch subagent: "tulis SATU test/snapshot yang MERAH menangkap `<gejala>`; jangan perbaiki dulu". Balikan = path test + bukti merah. Test ini jadi `test` di task.
2. **Root-cause (subagent, `systematic-debugging`).** Dispatch subagent investigasi (context-heavy → JANGAN di konduktor): "temukan akar `<gejala>` pakai systematic-debugging; balik 1 paragraf root cause + file/baris". Konduktor simpan ke `root_cause` (post-ship) atau ke `observed`/`approach` task (in-flight).
3. **Implementasi (pinjam `build`).** Setelah task tertulis, eksekusi via `build` (post-ship: work-item `fixes/<id>/`; in-flight: `build` mem-`pick` task baru). Konteks prompt implementer untuk fix WAJIB memuat (eksplisit, jangan diasumsikan): `conventions.md` + pointer file pola + `root_cause` + (post-ship) kutipan `business.md` fitur `relates_to`. Lintas-unit → potongan `_shared.md` mini.

## D. Triage 3-arah + tripwire + sensitivity re-eval

**Tiga kemungkinan** (gate sebelum kerja apa pun):
1. **Kode salah** (perilaku ≠ `business.md`/`plan`) → lanjut lane `fix` (koreksi kode).
2. **Requirement baru** (perilaku diminta tak pernah dispec) → **STOP → `/feature`**.
3. **Doc salah** (kode benar, `business.md`/`flows.md` usang) → **koreksi KNOWLEDGE** (update `business/`, gated + `critic`), catat di `knowledge_touched`. Bila keduanya salah → koreksi kode + knowledge.

**Tripwire eskalasi ke `/feature`** (mekanis, bukan judgment) — STOP bila fix:
- butuh entri BARU di `workspace.yaml.capabilities`, ATAU
- butuh vendor BARU di `control/integrations.md`, ATAU
- menambah `unit` di luar footprint fitur `relates_to` (cek `fanout.md`).

**Sensitivity re-evaluation:** bandingkan rencana/diff fix vs `control/invariants.md` (tenancy/money/idempotency/authz/PII-PCI). Bila fix menyentuh data sensitif yang fitur asal tak punya → set `fix.yaml.sensitivity` sesuai temuan (mis. `payments`/`pii`), walau fitur `relates_to` ber-`sensitivity: []`. Ini yang menyetir Security Gate `ship` (4.5).

## E. Drop (self-handle)

Triage/investigasi = bukan-bug / wontfix / duplikat → `fix` **self-set** `fix.yaml` `status: dropped` + isi `reason`, folder dikeep (memori). **JANGAN** panggil skill `drop` (itu khusus fitur — asумsi `feature.yaml`/promosi capability yang tak relevan untuk fix).
````

- [ ] **Step 2: Verifikasi struktur**

Run: `grep -n "^## [A-E]\." plugin/skills/fix/reference.md`
Expected: 5 heading (A–E). Lalu `grep -c "milestones" plugin/skills/fix/reference.md` → ≥1 (skema milestone-wrapped disebut).

- [ ] **Step 3: Verifikasi cross-ref**

Run: `grep -n "build/reference.md\|breakdown/reference.md\|invariants.md\|systematic-debugging" plugin/skills/fix/reference.md`
Expected: keempat referensi muncul (reuse build/breakdown, baca invariants, sandar systematic-debugging).

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/fix/reference.md
git commit -m "feat(fix): reference.md — skema fix.yaml + tasks.yaml-fix milestone-wrapped + dispatch deltas"
```

---

## Task 3: `fix/SKILL.md` — konduktor dua-mode

**Files:**
- Create: `plugin/skills/fix/SKILL.md`

- [ ] **Step 1: Tulis file**

Tulis `plugin/skills/fix/SKILL.md` PERSIS:

````markdown
---
name: fix
description: Use untuk memperbaiki DEFECT — perilaku yang SUDAH ADA ternyata salah, bukan kapabilitas baru. Auto-deteksi mode — in-flight (bug saat build, fitur active → corrective task di tasks.yaml fitur) atau post-ship (bug produksi, fitur shipped → control/fixes/<id>/ first-class). Alur — reproduce → root-cause → TDD fix → verify; berhenti di IJO (ship TERPISAH). Trigger — "fix <x>", "ada bug <x>", "report bug <x>", "perbaiki <x>". Jalankan dari root produk yang punya control/.
---

# fix — Lane Bugfix (konduktor, dua mode)

Tujuan: koreksi perilaku yang **sudah ada** & salah — TANPA menyeret pipeline fitur penuh. `fix` = **KONDUKTOR**; reproduce, root-cause, dan implementasi ditulis subagent (konteks isolasi → sesi `fix` tetap ramping). **Satu mesin, dua pintu:** loop dalam sama; beda hanya entry/artifact/exit.

> Skema (`fix.yaml`, `tasks.yaml`-fix), dispatch deltas (reproduce/root-cause subagent), triage 3-arah + tripwire, drop → `${CLAUDE_PLUGIN_ROOT}/skills/fix/reference.md`. Mesin eksekusi dipinjam `build` → `${CLAUDE_PLUGIN_ROOT}/skills/build/reference.md`.

## Langkah

### 1. Deteksi mode + triage (GATE)
Tentukan target nyangkut apa, lalu pilih mode:

| Target | Mode | Aksi |
|---|---|---|
| 1 fitur `active` (punya `tasks.yaml`, branch hidup) | **in-flight** (§2) | corrective task ke `tasks.yaml` fitur |
| fitur `shipped` | **post-ship** (§3) | `control/fixes/<id>/` |
| TAK nyangkut fitur (bug skeleton `wire`/shared util) | **post-ship** (§3) | `fixes/<id>/`, `relates_to: []`, sensitivity dievaluasi dari nol |
| fitur `draft` (belum `build`, belum ada kode) | **TOLAK** | bukan bug — fitur belum dikerjakan; arahkan lanjut `/feature` |
| DUA fitur (`active` + `shipped`) | **TANYA** | bug di kode yang sedang di-build → in-flight; selain itu post-ship. Konfirmasi, jangan tebak diam-diam |

Lalu **triage guard** (reference §D): **kode salah** (lanjut) / **requirement baru** (STOP → `/feature`) / **doc salah** (koreksi knowledge, gated `critic`). Cek **tripwire** (butuh capability/vendor/unit baru → STOP → `/feature`).

### 2. Mode in-flight
Konteks: fitur `active`, `tasks.yaml` ada, branch hidup. Bug = task `done` tapi hasil meleset / gap tak ke-cover.
1. **Reproduce (subagent)** — test/snapshot MERAH (reference §C.1).
2. **Root-cause (subagent, `systematic-debugging`)** — akar penyimpangan (reference §C.2).
3. **Append corrective task** ke `control/features/<fitur>/tasks.yaml` (`kind: fix` + `corrects` + `observed`; skema milestone-wrapped — reference §B).
4. **Eksekusi** — pinjam `build`: ia mem-`pick` task `pending` ini (TDD merah→hijau + review 2-tahap + gate). `fix` panggil `build`; **`build` TIDAK pernah balik panggil `/fix`** (anti-rekursi).
5. **STOP** — ijo → selesai. Fitur **tetap `active`**. TIDAK ada `fixes/<id>/`. `ship` nanti, sekali, untuk seluruh fitur (sesi terpisah).

> Catatan: bila `build` SENDIRI mendeteksi penyimpangan di gate-nya, ia menjalankan disiplin fix **di-embed** (tulis corrective task, lanjut loopnya) — bukan invoke `/fix`. Skill `/fix` ini hanya entry dari LUAR.

### 3. Mode post-ship
Konteks: bug produksi; tak ada branch hidup; fitur `shipped` (atau tanpa-fitur).
1. **Triage + framing** — `severity` (`normal`/`urgent`); `relates_to`+`flow` dgn BACA `business.md`+`flows.md` (BUKAN intake dari nol); **RE-EVALUASI `sensitivity`** vs `invariants.md` (reference §D); `units` via inferensi+konfirmasi (lihat catatan).
2. **Record** — `control/fixes/<YYYY-MM-DD>-<slug>/`: `fix.yaml` (`status: open`, reference §A) + `notes.md` (repro + log).
3. **Reproduce (subagent)** — test regresi MERAH → `notes.md` (reference §C.1).
4. **Root-cause (subagent, `systematic-debugging`)** — isi `root_cause` → `status: diagnosed` (reference §C.2). Bila ungkap doc salah → cabang koreksi knowledge (reference §D.3).
5. **Tulis fix-task** — `control/fixes/<id>/tasks.yaml` (milestone-wrapped, 1–3 task; reference §B). Lintas-unit → `_shared.md` mini **wajib**.
6. **Eksekusi** — pinjam `build` (work-item `fixes/<id>/`; branch `fix/<id>` per repo): implementer (TDD) + review 2-tahap + gate per unit.
7. **Verify lokal + STOP** — quality (test/lint/typecheck/build) ijo → **STOP, "siap di-`ship`"**. `/ship <fix>` dijalankan TERPISAH (boleh nawarin "lanjut ship?", default STOP). Picu `render-docs` saat status berubah (`open`→ Known Issues tampil).
8. **Drop path** — bukan-bug/wontfix/dup → self-set `status: dropped` + `reason`, folder dikeep (reference §E).

**Unit-inference (bukan fanout penuh):** infer `units` dari `fanout.md` fitur `relates_to` lalu **konfirmasi user**. Ini versi-lemah `fanout` (tak deteksi vendor/unit-kelewat penuh) — bila ternyata nyentuh unit di luar footprint / vendor baru → itu tripwire → `/feature` (reference §D).

## Catatan
- `fix` **tak pernah** auto-`ship` & tak bikin PR — jatah `/ship` (terpisah, eksplisit). `fix` cuma sampai IJO.
- BUKAN urusannya: kapabilitas/kontrak/vendor BARU (→ `/feature`); nentuin stack (→ `architect`); bikin PR/`shipped` (→ `ship`).
- Hemat konteks: reproduce + root-cause + implementasi semua di subagent; sesi `fix` cuma nampung kesimpulan + status.
````

- [ ] **Step 2: Verifikasi frontmatter & discoverability**

Run: `head -4 plugin/skills/fix/SKILL.md`
Expected: frontmatter valid `name: fix` + `description:` memuat "DEFECT" + "in-flight" + "post-ship" + trigger.

- [ ] **Step 3: Verifikasi tabel mode lengkap (4 cabang + tie-break)**

Run: `grep -n "in-flight\|post-ship\|TOLAK\|TANYA" plugin/skills/fix/SKILL.md`
Expected: kelima baris tabel mode ada (active/shipped/no-feature/draft/dua-fitur).

- [ ] **Step 4: Verifikasi anti-rekursi tertulis**

Run: `grep -n "TIDAK pernah balik panggil\|di-embed\|anti-rekursi" plugin/skills/fix/SKILL.md`
Expected: minimal 1 hit (pemisahan `build` embed vs `/fix` skill).

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/fix/SKILL.md
git commit -m "feat(fix): SKILL.md konduktor dua-mode (in-flight/post-ship) + triage 3-arah + tabel deteksi mode"
```

---

## Task 4: `build` — generalisasi work-item + embed disiplin fix

**Files:**
- Modify: `plugin/skills/build/SKILL.md:15` (prasyarat manifest), `:16` (staleness), `:46` (gate), `:24-33` (metadata fix)

- [ ] **Step 1: Generalisasi prasyarat manifest (line 15)**

Di `plugin/skills/build/SKILL.md` step 1, GANTI kalimat:
> **`feature.yaml` `status` HARUS `active`** — kalau `shipped`/`dropped`/`draft`, BERHENTI & jelaskan (jangan eksekusi fitur yang sudah ditutup atau belum di-plan).

MENJADI:
> **Manifest work-item HARUS aktif:** `feature.yaml` `status: active` (work-item `features/<fitur>/`) **ATAU** `fix.yaml` `status: open`/`diagnosed` (work-item `fixes/<id>/`, lane bugfix). Kalau manifest **closed** (`shipped`/`dropped`) atau fitur `draft`, BERHENTI & jelaskan. Untuk work-item fix, `plans/*` boleh tak ada (kontrak ringan); `_shared.md` mini **wajib** bila fix lintas-unit.

- [ ] **Step 2: Staleness baseline untuk fix (line 16)**

Di kalimat staleness ("bila `plans/*` / `_shared.md` / `business.md` lebih baru (mtime) dari `tasks.yaml`..."), TAMBAHKAN di akhir kalimat:
> (Untuk work-item fix tanpa `plans/*`, baseline staleness = `fix.yaml`/`notes.md`.)

- [ ] **Step 3: Embed disiplin fix di gate merah (line 46-47)**

Di step 6 (gate), setelah kalimat "...minta **approve/revisi**.", TAMBAHKAN kalimat:
> **Bila merah karena PENYIMPANGAN** (test ijo tapi "dibangun vs task" meleset dari maksud — bukan error/blocked), jalankan **disiplin fix yang di-EMBED**: dispatch subagent reproduce (test merah penangkap penyimpangan) → root-cause (`systematic-debugging`) → tulis corrective task `kind: fix` ke `tasks.yaml` → lanjut loop. **JANGAN invoke skill `/fix`** (anti-rekursi `build`→fix→`build`); disiplinnya inline di sini. Skill `/fix` hanya entry dari luar.

- [ ] **Step 4: Terima metadata task fix (step 3, sekitar line 31)**

Di step 3 ("Rakit prompt LENGKAP dari task..."), TAMBAHKAN kalimat di akhir paragraf pertama:
> Task ber-`kind: fix` (dari lane `fix`/disiplin embed) diperlakukan seperti task biasa — `kind`/`corrects`/`observed` adalah **metadata traceability**, tidak mengubah dispatch. Konteks prompt fix WAJIB memuat `conventions.md` + pointer file pola + `root_cause` + (work-item fix post-ship) kutipan `business.md` fitur `relates_to`.

- [ ] **Step 5: Verifikasi**

Run: `grep -n "fix.yaml\|kind: fix\|di-EMBED\|anti-rekursi\|baseline staleness = .fix" plugin/skills/build/SKILL.md`
Expected: manifest fix (line ~15), embed discipline + anti-rekursi (line ~47), metadata kind:fix (line ~31), staleness baseline (line ~16) — semua muncul.

- [ ] **Step 6: Verifikasi tidak merusak alur existing**

Run: `grep -n "status. HARUS\|HARUS aktif\|status: active" plugin/skills/build/SKILL.md`
Expected: prasyarat sekarang menyebut feature.yaml active OR fix.yaml open/diagnosed (tidak lagi hardcode "HARUS active" tunggal).

- [ ] **Step 7: Commit**

```bash
git add plugin/skills/build/SKILL.md
git commit -m "feat(build): work-item generalization (feature.yaml|fix.yaml) + embed disiplin fix di gate penyimpangan (anti-rekursi)"
```

---

## Task 5: `ship` — generalisasi manifest + unit fix + sensitivity fix

**Files:**
- Modify: `plugin/skills/ship/SKILL.md:12-14` (step 1), `:22` (step 3), `:32-34` (step 4.5), `:42-45` (step 6), `:50` (catatan)

- [ ] **Step 1: Generalisasi step 1 (manifest + unit source, line 12-14)**

GANTI kalimat awal step 1:
> Baca `control/features/<fitur>/feature.yaml` (harus `status: active`, + field `sensitivity`), `business.md`, `fanout.md`, `plans/*`. Tentukan **unit** (app ATAU package) yang kena dari `fanout.md`/`tasks.yaml` + `path`/`stack` dari `control/workspace.yaml` (`apps[]` + `packages[]`).

MENJADI:
> Baca manifest work-item: **fitur** `control/features/<fitur>/feature.yaml` (`status: active`) **ATAU fix** `control/fixes/<id>/fix.yaml` (`status: open`/`diagnosed`, lane bugfix) — keduanya bawa field `sensitivity`. Untuk fitur: baca `business.md`, `fanout.md`, `plans/*`; **unit** dari `fanout.md`/`tasks.yaml`. Untuk fix: baca `notes.md`+`root_cause`+`business.md` fitur `relates_to`; **unit dari `fix.yaml.units`** (fix tak punya `fanout.md`). `path`/`stack` dari `control/workspace.yaml`.

- [ ] **Step 2: Step 3 contract test fix lintas-unit (line 22)**

Di step 3, di kalimat "(Loop per-app di step 2 hanya app NYATA dari `fanout.md`...Fitur 1-app → lewati.)", TAMBAHKAN:
> Untuk work-item fix: unit dari `fix.yaml.units`; fix lintas-unit (`units` >1) **tetap** jalankan roundtrip ini terhadap `_shared.md` mini fix; fix 1-unit lewati.

- [ ] **Step 3: Step 4.5 sensitivity fix (line 32)**

Di step 4.5, di kalimat "Berskala ke `feature.yaml` `sensitivity` (baca di step 1):", GANTI jadi:
> Berskala ke `sensitivity` manifest work-item (`feature.yaml` ATAU `fix.yaml` — baca di step 1; untuk fix ini **hasil re-evaluasi** triage vs `invariants.md`, bukan warisan pasif):

- [ ] **Step 4: Step 6 PR desc + set status (line 42, 45)**

Di step 6, kalimat "Susun deskripsi PR dari `business.md` + `fanout.md` + `plans`..." TAMBAHKAN:
> (Untuk fix: deskripsi PR dari `root_cause` + diff + link `relates_to`/`flow`.)

Lalu kalimat "Set `feature.yaml` → `status: shipped` + tambah `shipped_at`..." GANTI jadi:
> Set manifest work-item → `status: shipped` + `shipped_at: <YYYY-MM-DD>` (untuk fix: `fix.yaml`, plus isi `fix_pr`).

- [ ] **Step 5: Catatan guard (line 50)**

Di Catatan, kalimat "Hanya jalan pada fitur `status: active`. Bila belum, hentikan & jelaskan." GANTI jadi:
> Hanya jalan pada work-item aktif: fitur `status: active` ATAU fix `status: open`/`diagnosed`. Bila belum (mis. fitur belum selesai `build`, fix belum `diagnosed`), hentikan & jelaskan.

- [ ] **Step 6: Verifikasi**

Run: `grep -n "fix.yaml\|fix.yaml.units\|relates_to\|root_cause\|hasil re-evaluasi" plugin/skills/ship/SKILL.md`
Expected: manifest fix (step 1), unit dari fix.yaml.units (step 1/3), sensitivity re-eval (4.5), PR desc root_cause (6) — semua muncul.

- [ ] **Step 7: Commit**

```bash
git add plugin/skills/ship/SKILL.md
git commit -m "feat(ship): generalisasi manifest feature.yaml|fix.yaml + unit dari fix.yaml.units + sensitivity fix re-eval + PR desc root_cause"
```

---

## Task 6: `breakdown` — pertahankan task `kind: fix`

**Files:**
- Modify: `plugin/skills/breakdown/SKILL.md:37` (step 7)

- [ ] **Step 1: Tambah aturan preserve kind:fix**

Di step 7, setelah kalimat "...tambah task baru sebagai `pending`.", TAMBAHKAN:
> **Pertahankan task `kind: fix`** (corrective, dari lane `fix`/disiplin embed `build`) yang **tak punya asal-`plan`** — JANGAN buang saat regenerate dari plan (kalau dibuang, bug yang sudah di-fix bisa ter-regress diam-diam). Task `kind: fix` ikut dipertahankan statusnya seperti task `done`/`in_progress` lain.

- [ ] **Step 2: Verifikasi**

Run: `grep -n "kind: fix\|ter-regress" plugin/skills/breakdown/SKILL.md`
Expected: aturan preserve task fix muncul di step 7.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/breakdown/SKILL.md
git commit -m "fix(breakdown): step 7 pertahankan task kind:fix tanpa asal-plan (cegah regresi saat re-breakdown)"
```

---

## Task 7: `render-docs` — section "Riwayat Fix / Known Issues"

**Files:**
- Modify: `plugin/skills/render-docs/template.html:16-28` (CSS+nav+SLOT), `plugin/skills/render-docs/SKILL.md:16` (step 1), `:26` (step 3), `:34` (step 4)

- [ ] **Step 1: Template — nav entry (template.html line 42)**

Di `<nav>`, setelah `<a href="#glossary">📖 Glossary</a>`, TAMBAHKAN baris:
```html
    <a href="#fixes">🛠️ Riwayat Fix</a>
```

- [ ] **Step 2: Template — CSS status & severity (template.html line 28)**

Setelah baris `.status.active{...} .status.shipped{...}`, TAMBAHKAN:
```css
  .status.open{background:#f6ecdf;color:#a5703a} .status.diagnosed{background:#f6f0df;color:#9a8a3a}
  .sev{font-size:11px;padding:2px 8px;border-radius:6px;margin-left:6px}
  .sev.urgent{background:#f6dfe0;color:#a53a45} .sev.normal{background:#eee;color:#777}
```

- [ ] **Step 3: Template — SLOT:fixes section (template.html, sebelum `</main>` line 60)**

Sebelum `</main>`, TAMBAHKAN:
```html
  <!-- SLOT:fixes -->
  <section id="fixes"><h2>Riwayat Fix / Known Issues</h2>
    <p class="meta">Defect dari control/fixes/. Known Issues (open/diagnosed) di atas, Riwayat (shipped) di bawah.</p>
    <div class="card"><h3>kupon-expired <span class="sev urgent">urgent</span> <span class="status open">open</span></h3>
      <p>kupon SUMMER expired masih kepake di checkout.</p>
      <div class="meta">fitur: checkout-kupon · flow: checkout</div></div>
  </section>
```

- [ ] **Step 4: SKILL.md step 1 — baca fixes/ (line 16)**

Setelah baris "`control/features/*/feature.yaml` (+ `business.md`) — kumpulkan fitur.", TAMBAHKAN baris:
> - `control/fixes/*/fix.yaml` — kumpulkan defect (id, status, severity, reported, relates_to, flow). SHAPE-only, TANPA isi sensitif.

- [ ] **Step 5: SKILL.md step 3 — render fixes (line 26, setelah integrations bullet)**

Setelah bullet `**integrations:**`, TAMBAHKAN bullet:
> - **fixes:** isi `<!-- SLOT:fixes -->`. Satu `.card` per fix dari `control/fixes/`: judul `id` + `.sev` (`severity`) + `.status` (`status`), `reported`, lalu `.meta` link `relates_to` (fitur) + `flow`. Urut: **Known Issues** (`open`/`diagnosed`) dulu, severity `urgent` di atas; lalu **Riwayat** (`shipped`). `dropped` JANGAN ditampilkan.

- [ ] **Step 6: SKILL.md step 4 — filter status fix (line 34)**

Di step 4 (FILTER status), TAMBAHKAN kalimat:
> Untuk fix: `dropped` JANGAN ditampilkan; `open`/`diagnosed` = "Known Issues"; `shipped` = "Riwayat". `render-docs` dipicu `ship` (fix shipped) **dan** oleh `fix` saat status fix berubah jadi `open`/`diagnosed` (biar Known Issues muncul tanpa nunggu ship lain).

- [ ] **Step 7: Verifikasi template**

Run: `grep -n "SLOT:fixes\|#fixes\|status.open\|sev.urgent" plugin/skills/render-docs/template.html`
Expected: nav `#fixes`, `SLOT:fixes` section, CSS `.status.open` + `.sev.urgent` — semua ada.

- [ ] **Step 8: Verifikasi SKILL.md**

Run: `grep -n "control/fixes\|Known Issues\|Riwayat" plugin/skills/render-docs/SKILL.md`
Expected: baca fixes/ (step 1), render + filter (step 3/4) muncul.

- [ ] **Step 9: Commit**

```bash
git add plugin/skills/render-docs/SKILL.md plugin/skills/render-docs/template.html
git commit -m "feat(render-docs): section Riwayat Fix / Known Issues dari control/fixes/ (slot + filter status + trigger on status change)"
```

---

## Task 8: Spec induk — §7/§12/§17

**Files:**
- Modify: `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md:73-83` (§7 tree), `:232-256` (§12 lifecycle+status), `:286-291` (§17)

- [ ] **Step 1: §7 model knowledge — tambah `fixes/` ke tree (sekitar line 80)**

Di blok tree `control/`, setelah blok `├── features/ ... └── plans/`, TAMBAHKAN sebelum `└── docs/`:
```
├── fixes/                # lane bugfix (post-ship) — entitas first-class
│   └── <id>/
│       ├── fix.yaml      # status + severity + relates_to + root_cause
│       ├── notes.md      # repro + log root-cause
│       └── tasks.yaml    # mini (milestone-wrapped)
```

- [ ] **Step 2: §12 lifecycle — tambah cabang fix (setelah blok "Cabang dipicu — vendor", sekitar line 243)**

TAMBAHKAN paragraf:
> **Lane korektif — defect (bug):** untuk perilaku yang **sudah ada** & salah, **`/fix`** (auto-deteksi mode). **in-flight** (fitur `active`): corrective task `kind: fix` di `tasks.yaml` fitur, eksekusi lewat `build`, berhenti di ijo (ship nanti sekalian fitur). **post-ship** (fitur `shipped`/tanpa-fitur): `control/fixes/<id>/` first-class, berhenti di "siap ship" → `/ship <fix>` TERPISAH. `build`/`ship` di-generalisasi (work-item = fitur ATAU fix). Lihat spec `2026-06-02-fix-bugfix-lane-design.md`.

- [ ] **Step 3: §12 tabel status — tambah baris fix (setelah tabel status feature.yaml, line 254)**

Setelah tabel status fitur, TAMBAHKAN:
> Status `fix.yaml` (post-ship): `open` (`/fix` mulai) → `diagnosed` (root_cause terisi) → `shipped` (`/ship` hijau) (+ `dropped` bila bukan-bug). Progress halus `fixing`/`done` dibaca dari `fixes/<id>/tasks.yaml`.

- [ ] **Step 4: §17 komponen — skill count +1 (line 288)**

Di "**Skills (17):**", ubah `(17)` → `(18)` dan tambahkan ` · `fix`` di akhir daftar (setelah `render-docs`).

- [ ] **Step 5: Verifikasi**

Run: `grep -n "fixes/\|/fix\|Lane korektif\|Skills (18)" docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`
Expected: tree fixes/ (§7), lane korektif (§12), status fix (§12), Skills (18) (§17).

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
git commit -m "docs: induk §7/§12/§17 — lane bugfix fix (fixes/ tree, lifecycle+status, skill count 18)"
```

---

## Task 9: README — lifecycle + commands

**Files:**
- Modify: `README.md:33-35` (urutan lifecycle), `:49-53` (section lifecycle), `:64-65` (status)

- [ ] **Step 1: Tambah `/fix` ke section "Selesai & lifecycle" (line 49-53)**

Di blok kode setelah `/drop <fitur>`, TAMBAHKAN:
```
/fix <apa-yang-rusak>   # lane bugfix: auto-deteksi in-flight (fitur active) / post-ship (fixes/<id>/); berhenti di ijo, ship terpisah
```
Lalu di bawah blok, TAMBAHKAN kalimat:
> `/fix` = koreksi perilaku yang **sudah ada** (bukan `/feature` yang buat kapabilitas baru). in-flight → corrective task di `tasks.yaml` fitur; post-ship → `control/fixes/<id>/` first-class. `build`/`ship` work-item-aware (fitur ATAU fix).

- [ ] **Step 2: Update Status (line 65) — sebut lane fix**

Di akhir baris Status, TAMBAHKAN:
> **Lane bugfix:** `fix` (dua-mode in-flight/post-ship, `control/fixes/` first-class, work-item generalization `build`/`ship`).

- [ ] **Step 3: Verifikasi**

Run: `grep -n "/fix\|lane bugfix\|fixes/" README.md`
Expected: command `/fix`, deskripsi, status update muncul.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs(readme): tambah /fix (lane bugfix dua-mode) ke lifecycle & status"
```

---

## Task 10: Deskripsi plugin & marketplace

**Files:**
- Modify: `plugin/.claude-plugin/plugin.json:3`, `.claude-plugin/marketplace.json` (plugins[].description)

- [ ] **Step 1: plugin.json — sebut fix di description**

Di `plugin/.claude-plugin/plugin.json` field `description`, sebelum `, docs).`, TAMBAHKAN:
> `, fix (lane bugfix dua-mode: in-flight/post-ship, control/fixes/ first-class)`

(hasil: `...ship dengan security gate/drop, fix (lane bugfix dua-mode: in-flight/post-ship, control/fixes/ first-class), docs).`)

- [ ] **Step 2: marketplace.json — sebut fix**

Di `.claude-plugin/marketplace.json` `plugins[0].description` ("Skills, agent, dan rules untuk mengelola produk multi-app secara AI-first."), GANTI jadi:
> "Skills (init→ship + lane bugfix fix), agent, dan rules untuk mengelola produk multi-app secara AI-first."

- [ ] **Step 3: Verifikasi JSON valid**

Run: `python3 -c "import json; json.load(open('plugin/.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json')); print('JSON OK')"`
Expected: `JSON OK` (kedua file tetap valid).

- [ ] **Step 4: Commit**

```bash
git add plugin/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "docs(plugin): deskripsi memuat lane bugfix fix"
```

---

## Task 11: Consistency pass (self-review final)

**Files:** (read-only verifikasi lintas-file)

- [ ] **Step 1: Cross-ref resolusi — semua pointer `fix` valid**

Run: `grep -rn "skills/fix/\|fix.yaml\|fixes/\|kind: fix" plugin/skills/ | grep -v "skills/fix/"`
Expected: referensi `fix` di `build`/`ship`/`breakdown`/`render-docs` semua menunjuk konsep yang didefinisikan di `fix/SKILL.md`+`reference.md` (tak ada nama field/skill menggantung).

- [ ] **Step 2: Skill count konsisten**

Run: `ls plugin/skills/ | wc -l` lalu `grep -rn "Skills (1[78])\|skill +1\|(17 skill\|17)" docs/ README.md plugin/.claude-plugin/plugin.json`
Expected: jumlah direktori skill = 18 (17 lama + `fix`); semua sebutan "17" yang merujuk jumlah skill sudah jadi "18" (kecuali referensi historis di spec lama yang memang tak diubah — periksa konteks).

- [ ] **Step 3: Anti-rekursi & ship-terpisah konsisten**

Run: `grep -rn "TIDAK pernah balik panggil\|di-embed\|auto-.ship\|tak pernah.*ship\|TERPISAH" plugin/skills/fix/SKILL.md plugin/skills/build/SKILL.md`
Expected: `build` embed disiplin (bukan invoke `/fix`) + `fix` tak auto-ship — dua invariant kunci tertulis & tak saling bertentangan.

- [ ] **Step 4: Tak ada placeholder/TODO yang bocor**

Run: `grep -rn "TODO\|TBD\|FIXME\|<placeholder>\|implement later" plugin/skills/fix/`
Expected: kosong.

- [ ] **Step 5: Validasi terhadap spec — coverage**

Baca ulang `docs/superpowers/specs/2026-06-02-fix-bugfix-lane-design.md` §13 (Dampak ke Komponen). Untuk tiap baris dampak (build, breakdown, ship, render-docs, template, induk, README, plugin.json), pastikan ada task yang mewujudkannya. Daftar gap bila ada; bila ada, tambah task & ulangi.

Expected: nol gap — tiap komponen di §13 punya task (1–10).

- [ ] **Step 6: Commit (bila ada perbaikan dari pass ini)**

```bash
git add -A && git commit -m "chore(fix): consistency pass — cross-ref, skill count, invariants" || echo "nothing to fix"
```

---

## Selesai

Setelah Task 11 hijau: branch `feat/fix-bugfix-lane` berisi lane `fix` lengkap (skill + reference + template fix + generalisasi `build`/`ship`/`breakdown`/`render-docs` + doc induk/README/plugin). **Tidak ada PR otomatis** — buka PR manual saat siap (konsisten dengan disiplin sistem: PR = keputusan manusia).

**Smoke manual yang disarankan** (opsional, di produk uji yang punya `control/`):
1. `/fix` pada fitur `active` dengan bug bikinan → cek corrective task `kind: fix` masuk `tasks.yaml`, `build` eksekusi, fitur tetap `active`.
2. `/fix` pada fitur `shipped` → cek `control/fixes/<id>/` terbentuk, berhenti di "siap ship", `/ship <fix>` bikin PR + `fix.yaml` `shipped`.
3. `/render-docs` → cek section "Riwayat Fix / Known Issues" muncul.
