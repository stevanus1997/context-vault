# Schema & Structure Awareness — Integration Verification (Task 9)

Plan: `docs/superpowers/plans/2026-06-18-schema-structure-awareness.md`
Spec: `docs/superpowers/specs/2026-06-18-schema-structure-awareness-build-design.md`
Branch: `feat/schema-structure-awareness`

Editan = PROMPT/markdown skill context-vault (bukan kode runtime). Verifikasi = grep-assertion +
read-back koherensi + cross-file sweep. Semua 8 task implementasi (T1-T8) di-commit terpisah.

## Step 1 — Konsistensi field `reuse:` lintas-file

Nama field **identik** di semua tempat: `reuse:` dengan sub-key `table:` / `file:`. Tak ada varian
(`reuses:` / `reuse_tables:` / `reuse_table:` → nol hit).
- Definisi: `breakdown/reference.md` §A (skema YAML) + §B (batas NAMA-only).
- Penulis: `breakdown/SKILL.md` step 3 (transkripsi → `reuse:[table:,file:]`) + step 4 (coverage) +
  step 7 (preservasi re-breakdown).
- Pembaca/hint: `build/reference.md` §B (slice = SELECTION HINT) + `build/SKILL.md` step 6 (gate).

## Step 2 — Reader/writer `control/schema/` (single-writer)

- **WRITER (invoke `rules/schema-projection.md`)**: HANYA `wire` (SKILL §0 seed + §3 baseline) & `build`
  (SKILL step 3 regen pasca-migrate). Path literal `rules/schema-projection.md` utuh — tak ada orphan
  `rules/n.md` (cek negatif: nol hit). `wire/SKILL.md`×2, `wire/reference.md`×2, `build/SKILL.md`×1,
  `build/reference.md`×1.
- **READER**: `plan` (step 3 baseline), `breakdown` (step 1 read-set), `build` (step 1 lazy + reviewer),
  `migration-impact.md`, `render-docs`.
- **`upgrade`**: 0 invoke / 0 tulis `control/schema/` — hanya MENGARAHKAN ke `wire` (charter
  nol-sentuh-knowledge utuh).

## Step 3 — Worked-example trace (`users` / `user.go`)

Skenario brownfield app `api` (Go+Postgres), existing `internal/user/user.go` + tabel `users`,
fitur "profil — display name + avatar". Rantai arsitek→mandor→tukang→gate nyambung penuh:

1. **plan (T2)** — directive "Keputusan reuse-vs-NEW (sumber tunggal)" banding ke baseline
   `control/schema/api.md` (`users` ada) → verdict `Model/Schema: reuse users` (extend).
2. **breakdown (T4)** — baca `control/schema/api.md` (read-set) + Reuse-aware transkripsi →
   `files: modify internal/user/user.go` + `reuse:[table: users, file: internal/user/user.go]`;
   coverage step 4 flag bila ada `create users`. Cocok PERSIS dengan spec §5 worked-example T1.
3. **build (T5)** — prompt implementer dapat slice `users` (fail-open union) + listing
   `internal/user/` + directive "extend, jangan bikin tabel/file duplikat".
4. **gate (T6)** — challenge checklist cek tak ada `CREATE TABLE users` / `users.go` baru
   (by entity-equivalence) + `reuse:` dihormati.
5. **brownfield (T7)** — bila repo lama, `wire` nge-seed `control/schema/api.md` presence-based
   sebelum langkah 1-4.

**Tak ada mata rantai yang teksnya gagal mendukung langkah di atas.** Nol gap.

## Step 4 — Spec-coverage cross-check

| Spec | Task |
|---|---|
| D1 (deliver baseline ke implementer) | T5 |
| D2 (transkripsi reuse + struktur file) | T3 + T4 |
| D3 (slot Konvensi Query) | T1 |
| D4 (jaring redundant + query) | T6 |
| D5 (plan verdict reuse-vs-NEW) | T2 |
| D6 (seed brownfield) | T7 (wire) + T8 (upgrade arahkan) |
| Dimensi file-level | T3 (`reuse:[file:]`) + T5 (listing-dir) + T6 (redundant-file gate) |

Success criteria §8 (1-6) seluruhnya ter-cover (crit-3 = trace Step 3; crit-4 presence-based = T7).
**Tak ada D / criterion tanpa task.**

## Step 5 — Degrade & scope sanity (nol palang baru)

Global Constraint "Nol palang keras baru" **terjaga**. Cek `git diff` baris ber-`+`:
- Satu-satunya kalimat BARU yang menyebut "palang" = `breakdown` "Reuse-before-create" → eksplisit
  **"Tampil-di-gate, BUKAN palang ... tak memblokir"** (advisory).
- Item `redundant-table` / `redundant-file` / `query` = item challenge-checklist di bawah
  "→ minta approve/revisi" (advisory), BUKAN STOP.
- Token `STOP` yang muncul di baris yang ku-edit (`breakdown` read-set, `build` step-1/step-6) semuanya
  **pre-existing** (Validasi unit GATE, manifest-closed BERHENTI, Fondasional STOP, Floor-scan STOP) —
  muncul di diff `+` hanya karena git menampilkan seluruh baris yang dimodifikasi; sisipanku tak
  menambah STOP. Dua kalimat ber-"palang" dua-duanya negasi ("bukan palang").

## Kesimpulan

Rantai end-to-end nyambung; `reuse:` & `control/schema/` konsisten lintas-file; single-writer
(`wire`/`build` saja yang invoke `schema-projection.md`) terjaga; degrade no-op & nol palang baru
sesuai invarian spec §3 + non-goals §7. Tak ada gap → tak ada task perlu re-commit.
