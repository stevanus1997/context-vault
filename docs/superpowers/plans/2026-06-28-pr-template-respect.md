# PR Template Respect — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bikin satu rule share untuk merakit judul+body PR, dipanggil `ship` & `tweak`, yang menghormati PR template repo bila ada dan jatuh ke bentuk per-rasa plugin bila tidak.

**Architecture:** Rule baru `plugin/rules/pr-template.md` (pola `migration-impact.md`: prosedur yang dipanggil, read-only terhadap `control/`, menghasilkan `{judul, body}`). `ship/SKILL.md` step 6 & `tweak/SKILL.md` step 6 + `tweak/reference.md §E` berhenti merakit body inline → cukup memanggil rule dengan `rasa` + sumber + `evidence`. Mekanik `gh pr create`/repo-grouping/base-branch tetap di pemanggil.

**Tech Stack:** Markdown skill files (Claude Code plugin). Tidak ada test runner — verifikasi = walk skenario acceptance + grep cross-reference.

**Spec:** `docs/superpowers/specs/2026-06-28-pr-template-respect-design.md`

## Global Constraints

Berlaku di SEMUA task (disalin verbatim dari spec):

- **Heading PR English, isi Indonesia.** (spec D6)
- **Judul PR conventional commits:** `feat(<unit>): …` / `fix(<unit>): …` / `tweak(<unit>): …`. (spec D7)
- **Repo punya template → struktur dipakai PERSIS** (heading/urutan/checklist/komentar tak diutak-atik). (spec D2)
- **Integritas:** checkbox dicentang HANYA dari `evidence` nyata; section Flow di-skip bila alur tak bisa diturunkan akurat; konten tanpa rumah → `### Additional context (auto)`, bukan dipaksa ke section salah. (spec D4, D8, §5.2)
- **Format file rule ikut `plugin/rules/migration-impact.md`** (judul + "Dirujuk skill …" + Input/Output/Langkah/Sifat).
- **Rule tak menulis `control/`** — read-only, hanya menghasilkan teks (beda `schema-projection.md`).
- **Referensi antar-file pakai** `${CLAUDE_PLUGIN_ROOT}/rules/pr-template.md`.

---

### Task 1: Buat rule `plugin/rules/pr-template.md`

Deliverable inti: file rule yang merakit judul+body, deteksi+hormati template repo, fallback per-rasa, section Flow kondisional, eval table.

**Files:**
- Create: `plugin/rules/pr-template.md`

**Interfaces:**
- Produces (dikonsumsi Task 2 & 3): rule dipanggil dengan input `{rasa, repo_path, sumber-per-rasa, evidence, units}` → menghasilkan `{judul, body}`. Nama path referensi: `${CLAUDE_PLUGIN_ROOT}/rules/pr-template.md`.

- [ ] **Step 1: Baca file rule contoh buat samain format & tone**

Run: baca `plugin/rules/migration-impact.md`.
Expected: paham strukturnya — judul `# X — desc (aturan share)`, paragraf "Dirujuk skill …", lalu section Input/Langkah/Sifat; tone Indonesia + istilah teknis; advisory.

- [ ] **Step 2: Tulis file `plugin/rules/pr-template.md` dengan isi PERSIS berikut**

````markdown
# PR Template — perakitan judul & body PR (aturan share)

Dirujuk skill yang mengirim PR: `ship` (step 6 — rasa `feature`/`fix`) & `tweak` (step 6 — rasa `tweak`). **BUKAN langkah berdiri sendiri** — prosedur **perakitan** yang dipanggil: menghasilkan `{judul, body}` untuk `gh pr create`. **Tidak menulis** artifact `control/` (beda `schema-projection.md`). Mekanik repo-grouping, base-branch, dan `gh pr create` tetap milik pemanggil.

Prinsip: **kalau repo punya PR template, itu dipakai PERSIS** — bentuk per-rasa plugin cuma fallback saat repo tak punya template. Integritas: jangan mengarang (checkbox tak terbukti, diagram menebak).

## Input (di-supply pemanggil, per repo unik)
- `rasa` — `feature` | `fix` | `tweak`.
- `repo_path` — toplevel repo (deteksi template + diff).
- **sumber konten** sesuai rasa (lihat Bentuk fallback).
- `evidence` — gate yang BENAR-BENAR dijalankan & lulus pemanggil (ship: test/lint/typecheck/build + code-review + security-gate; tweak: floor-scan + TDD + Challenge Checklist). Dasar pencentangan checkbox.
- `units` + interaksinya (keputusan section Flow).

## Output
`{ judul, body }` markdown siap pakai. Pemanggil menjalankan `gh pr create` / menampilkan body bila `gh` tak ada.

## Langkah (prosedur, per repo)
1. **Deteksi PR template repo** (presedens, case-insensitive; yang pertama ketemu menang):
   1. `.github/PULL_REQUEST_TEMPLATE.md` / `.github/pull_request_template.md`
   2. `PULL_REQUEST_TEMPLATE.md` di root repo
   3. `docs/PULL_REQUEST_TEMPLATE.md` / `docs/pull_request_template.md`
   4. Dir `.github/PULL_REQUEST_TEMPLATE/*.md` (multi-file)
   Tak ada → step 3 (fallback).
2. **Ada template → pakai PERSIS sebagai body:**
   - **Dir multi-file:** pilih file yang cocok `rasa` by nama (mis. `fix.md`/`feature.md`/`bug.md`); tak ada yang cocok → **TANYA user** pilih mana (jangan tebak).
   - **Struktur persis:** jangan tambah/hapus/urut-ulang heading; jangan hapus checklist/komentar `<!-- -->`.
   - **Isi area prose** (yang jelas "tempat nulis", mis. di bawah `## Description`, menggantikan `<!-- … -->`) by-understanding: petakan section template → sumber per-rasa (`Summary`/`Description` ← headline; `Why`/`Motivation`/`Context` ← alasan bisnis / root_cause / rationale; `Testing`/`How tested` ← evidence test).
   - **Konten tanpa rumah** (runbook, traceability, diagram) → append di akhir body di bawah `### Additional context (auto)`. JANGAN paksa ke section yang salah.
   - **Checkbox:** centang HANYA item yang `evidence` buktikan (mis. "Tests pass" saat test gate lulus). Tak terverifikasi (mis. "Tested on staging", "Updated CHANGELOG") → biarkan kosong. JANGAN mengarang centang.
   - Lanjut step 4 (runbook) lalu step 5 (judul).
3. **Tak ada template → bentuk fallback per-rasa.** Skeleton: `Summary → Why → Flow? → Changes → Testing → Runbook? → Traceability → Checklist` (heading English, isi Indonesia). Per rasa:
   - **`feature`** (sumber `business.md`+`fanout.md`+`plans/*`+diff): `Summary` (headline+target bisnis) · `Why` (alasan `business.md`) · `Flow` (lihat "Section Flow") · `Changes` (per unit dari diff/plans) · `Testing` (evidence) · `Traceability` (`control/features/<fitur>/` + flow) · checklist hasil gate (centang per evidence).
   - **`fix`** (sumber `root_cause`+diff+`relates_to`/`flow`): `Summary` · `Root cause` (ganti `Why`) · `Flow` (HANYA bila lintas-unit) · `Changes` · `Testing` · `Traceability` (`control/fixes/<id>/` + relates_to/flow + severity) · checklist.
   - **`tweak`** (sumber rationale+Challenge Checklist+diff): `Summary` · `Rationale` (ganti `Why`) · `Changes` · `Challenge Checklist` (Bentrok aturan/Tradeoff/Alternatif simpel/Yang bisa jebol) · `Testing` (+ floor-scan bersih) · `Capture` (file knowledge + alasan). **TANPA** section `Flow` & **TANPA** `Traceability` manifest (atomik).
4. **Runbook (kondisional, kedua jalur):**
   - **Integrasi** (work-item kena vendor di `integrations.md`) → section runbook: URL webhook yang perlu didaftarkan di console vendor, env secret yang perlu di-set, switch mode test→live. (Scoped ke integrasi.)
   - **Migrasi** (ada task `migrate`) → section runbook: urutan aman (expand/additive → deploy app pemakai → contract terakhir), backfill long-running, langkah zero-downtime per `conventions.md`. **Advisory** (bukan gate keras).
   - Pada jalur template repo, runbook masuk lewat `### Additional context (auto)`.
5. **Judul** — conventional commit: `<type>(<unit>): <desc ringkas>`; `type` = `feat`(feature) / `fix` / `tweak`; `<unit>` = unit nyata utama yang kena; multi-unit → unit sentral atau hilangkan scope. Selaras gaya commit repo.

## Section Flow (Mermaid sequence diagram) — kapan
- **Muncul HANYA bila:** rasa `feature` ATAU `fix` lintas-unit, **DAN** >1 unit saling interaksi.
- **Sumber:** `flows.md` + `fanout.md` + `_shared.md` + diff (by-understanding).
- **Tipe:** Mermaid `sequenceDiagram` (aktor + pesan antar-unit).
- **Anti-fiksi:** alur tak bisa diturunkan akurat → **SKIP** (diagram salah lebih buruk dari tak ada).
- **Penempatan:** hanya di bentuk fallback. Template repo menang → tak disuntik (paling banter mengalir ke prose `Description` bila kompleks; default tidak).

## Sifat
- **Perakitan, bukan gate:** rule TAK memblokir/STOP; keputusan ship/lanjut tetap di gate pemanggil (`ship` step 5 / `tweak` step 5). Satu-satunya interupsi: TANYA saat dir multi-template tanpa match rasa.
- **Integritas:** checkbox hanya dari `evidence`; diagram di-skip bila menebak; konten ragu → `### Additional context (auto)`.
- **Degrade:** sumber per-rasa kurang (mis. `plans/` tak ada untuk fix) → isi best-effort dari yang ada, JANGAN error. `gh`/remote tak ada → pemanggil tampilkan body manual.

## Skenario eval (acceptance permanen)
| skenario | perilaku |
|---|---|
| repo punya `.github/PULL_REQUEST_TEMPLATE.md` | body = template repo persis; prose diisi; checkbox terverifikasi dicentang |
| repo tanpa template, feature 2-app interaksi | fallback feature + section Flow |
| repo tanpa template, feature 1-unit | fallback feature, TANPA Flow |
| repo tanpa template, fix 1-unit | fallback fix, TANPA Flow |
| repo tanpa template, fix lintas-unit | fallback fix + Flow |
| repo tanpa template, tweak | fallback tweak; TANPA Flow & Traceability manifest |
| dir `PULL_REQUEST_TEMPLATE/` punya `fix.md`+`feature.md`, rasa fix | pakai `fix.md` |
| dir multi-template tanpa match rasa | TANYA user |
| checkbox "Tested on staging" (tak terverifikasi) | dibiarkan kosong |
| fitur multi-repo: A punya template, B tidak | PR-A pakai template A; PR-B fallback |
| judul fix di unit `api` | `fix(api): <desc>` |
| alur feature tak bisa diturunkan akurat | section Flow di-skip (bukan diagram tebakan) |
````

- [ ] **Step 3: Verifikasi file kebuat & cross-reference valid**

Run: `test -f plugin/rules/pr-template.md && grep -c '^## ' plugin/rules/pr-template.md`
Expected: file ada; ≥4 section heading (`Input`, `Output`, `Langkah`, `Section Flow`, `Sifat`, `Skenario eval`).

- [ ] **Step 4: Walk skenario acceptance terhadap teks rule**

Baca ulang `plugin/rules/pr-template.md`, lalu untuk tiap baris tabel "Skenario eval", tunjuk kalimat di rule yang mendikte perilaku itu.
Expected: 12 baris semua kecakup (deteksi presedens step 1; dir-match step 2; checkbox-evidence step 2; fallback per-rasa step 3; Flow-condition section Flow; judul step 5). Kalau ada baris tanpa rujukan → tambal teks rule sebelum commit.

- [ ] **Step 5: Commit**

```bash
git add plugin/rules/pr-template.md
git commit -m "feat(rules): pr-template — rakit PR body + hormati template repo

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Wire `ship/SKILL.md` step 6 ke rule

**Files:**
- Modify: `plugin/skills/ship/SKILL.md:42-44`

**Interfaces:**
- Consumes: `${CLAUDE_PLUGIN_ROOT}/rules/pr-template.md` (Task 1) dengan `rasa` = `feature` (fitur) / `fix` (fix-mode).

- [ ] **Step 1: Baca step 6 sekarang biar tahu persis yang diganti**

Run: baca `plugin/skills/ship/SKILL.md` baris 41–47.
Expected: lihat 3 bullet perakitan (baris 42 deskripsi PR feature/fix; 43 runbook integrasi; 44 runbook migrasi) + bullet 45 (repo unik + `gh pr create`) + bullet 46 (status shipped) + bullet 47 (render-docs).

- [ ] **Step 2: Ganti tiga bullet perakitan (42–44) jadi satu pointer ke rule**

Ganti baris 42–44 (mulai `- Susun deskripsi PR …` sampai akhir bullet runbook migrasi) dengan:

```markdown
- Rakit **judul + body PR** per repo ikut `${CLAUDE_PLUGIN_ROOT}/rules/pr-template.md` — `rasa` = `feature` (fitur) / `fix` (fix-mode); supply sumber per-rasa (`business.md`/`fanout.md`/`plans` untuk feature; `root_cause`/`relates_to`/`flow` untuk fix) + `evidence` dari gate step 2 & 4.5 (test/lint/build, code-review, security). Bila repo punya PR template → dipakai persis; bila tidak → bentuk fallback per-rasa. **Runbook integrasi & migrasi** (vendor di `integrations.md` / task `migrate`) ikut dirakit rule sebagai section bila relevan.
```

- [ ] **Step 3: Pastikan bullet `gh pr create` (lama baris 45) masih utuh & nyambung**

Run: `grep -n 'gh pr create\|repo unik\|pr-template' plugin/skills/ship/SKILL.md`
Expected: bullet repo-unik + `gh pr create` masih ada (TIDAK dihapus); baris pointer `pr-template.md` muncul tepat sebelumnya.

- [ ] **Step 4: Verifikasi tak ada info hilang**

Baca ulang step 6 hasil edit. Konfirmasi semua substansi runbook lama (URL webhook, env secret, test→live, urutan expand-contract, backfill, zero-downtime) sekarang tertanggung oleh rule step 4 (cek Task 1 file). Konfirmasi nuansa "advisory" migrasi tetap ada (di rule).
Expected: tak ada item runbook yang lenyap; kalau ada → tambahkan ke rule (Task 1 file) lalu re-commit Task 1.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/ship/SKILL.md
git commit -m "feat(ship): rakit PR via rules/pr-template (rasa feature/fix)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Wire `tweak` step 6 + `reference.md §E` ke rule

**Files:**
- Modify: `plugin/skills/tweak/SKILL.md:42-43`
- Modify: `plugin/skills/tweak/reference.md:34-38`

**Interfaces:**
- Consumes: `${CLAUDE_PLUGIN_ROOT}/rules/pr-template.md` (Task 1) dengan `rasa` = `tweak`.

- [ ] **Step 1: Baca dua lokasi yang diedit**

Run: baca `plugin/skills/tweak/SKILL.md` baris 42–43 (step 6 "Finish — commit + PR") dan `plugin/skills/tweak/reference.md` baris 32–38 (§E "Floor-scan + mekanik PR").
Expected: SKILL.md step 6 = "Commit … → buka PR (`reference.md §E`)"; reference §E = mekanik branch/base/multi-repo, "reuse `ship`", tanpa bentuk body.

- [ ] **Step 2: Tambah pointer rule di `tweak/SKILL.md` step 6**

Pada step 6, sisipkan kalimat (setelah "buka PR"):

```markdown
Body & judul PR dirakit ikut `${CLAUDE_PLUGIN_ROOT}/rules/pr-template.md` (`rasa` = `tweak`; supply rationale + Challenge Checklist step 5 + diff + `evidence` floor-scan/TDD). Repo punya PR template → dipakai persis; tidak → bentuk fallback `tweak`.
```

- [ ] **Step 3: Tambah pointer rule di `tweak/reference.md §E` (blok "Mekanik PR")**

Pada §E "Mekanik PR (step 6, reuse `ship`)", tambahkan bullet pertama:

```markdown
- **Body+judul:** ikut `${CLAUDE_PLUGIN_ROOT}/rules/pr-template.md` (`rasa` = `tweak`). Bentuk fallback tweak: `Summary · Rationale · Changes · Challenge Checklist · Testing · Capture` — TANPA section Flow & Traceability (atomik). Judul `tweak(<unit>): …`.
```

- [ ] **Step 4: Verifikasi konsistensi tweak vs rule**

Run: `grep -n 'pr-template' plugin/skills/tweak/SKILL.md plugin/skills/tweak/reference.md`
Expected: dua-duanya rujuk `${CLAUDE_PLUGIN_ROOT}/rules/pr-template.md` rasa `tweak`. Bentuk fallback tweak di reference §E cocok dengan rule step 3 (`tweak`) Task 1 — TANPA Flow/Traceability.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/tweak/SKILL.md plugin/skills/tweak/reference.md
git commit -m "feat(tweak): rakit PR via rules/pr-template (rasa tweak)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Consistency sweep + final acceptance walk

**Files:**
- Modify: (hanya bila sweep menemukan site lain) — kandidat: file mana pun di `plugin/` yang merakit PR/`gh pr create` selain ship & tweak.

- [ ] **Step 1: Sweep semua site perakitan PR di plugin**

Run: `grep -rn 'gh pr create\|deskripsi PR\|buka PR\|PULL_REQUEST' plugin/`
Expected: pemakaian `gh pr create` HANYA di `ship` (step 6) & `tweak/reference.md §E` — dua-duanya sudah rujuk rule. Kalau ada site LAIN yang merakit body PR tanpa rujuk rule → wire ke rule (edit + commit di task ini). (Catatan: `fix` TIDAK bikin PR — kalau muncul, itu salah.)

- [ ] **Step 2: Sweep instruksi body PR usang**

Run: `grep -rn 'Susun deskripsi PR\|business.md.*fanout.md.*plans' plugin/skills/ship/SKILL.md`
Expected: TIDAK ada lagi instruksi rakit body inline di ship step 6 (sudah diganti pointer Task 2). Kalau masih ada → bersihkan.

- [ ] **Step 3: Final acceptance walk lintas-file**

Baca `plugin/rules/pr-template.md` + step 6 `ship` + step 6 `tweak`. Jalankan mental tiap baris "Skenario eval" Task 1 end-to-end: pemanggil mana (ship/tweak) → rasa → deteksi template → body. Konfirmasi rantai pointer utuh (`${CLAUDE_PLUGIN_ROOT}/rules/pr-template.md` resolve dari ketiga file).
Expected: 12 skenario jalan; tak ada referensi menggantung.

- [ ] **Step 4: Commit (bila ada perubahan dari sweep) atau tandai selesai**

```bash
# Hanya bila Step 1/2 mengubah file:
git add -A && git commit -m "chore(pr-template): consistency sweep site perakitan PR

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```
Bila tak ada perubahan: tak perlu commit — laporkan sweep bersih.

---

## Self-Review (penulis plan)

**1. Spec coverage** — tiap keputusan §3 spec → task:
- D1 (rule share) → Task 1 + wiring Task 2/3 ✓
- D2/D4/§5.2 (template persis + isi prose + checkbox-evidence) → Task 1 step 2 (Langkah 2) ✓
- D3/D5/D6 (fallback skeleton, heading English) → Task 1 step 2 (Langkah 3) ✓
- D7 (judul conventional commit) → Task 1 (Langkah 5) ✓
- D8 (Flow kondisional) → Task 1 (Section Flow) ✓
- D9 (multi-repo per-repo) → Task 1 (Input "per repo unik") + eval row ✓
- D10 (dir multi-template) → Task 1 (Langkah 2 dir-multi) ✓
- §9 (edit ship/tweak) → Task 2 & 3 ✓
- §10 edge cases (template kosong, gh tak ada, diff kosong) → Task 1 Sifat (degrade) ✓
- §11 acceptance → Task 1 eval table + Task 4 walk ✓

**2. Placeholder scan** — tak ada "TBD/TODO/dll"; isi rule lengkap verbatim di Task 1 step 2. ✓

**3. Type consistency** — istilah konsisten lintas task: `rasa` (feature/fix/tweak), `evidence`, `${CLAUDE_PLUGIN_ROOT}/rules/pr-template.md`, `### Additional context (auto)`, skeleton `Summary→Why→Flow?→Changes→Testing→Runbook?→Traceability→Checklist`. ✓
