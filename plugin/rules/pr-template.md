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
