# HANDOFF (EKSEKUSI) — Spec B `design-system bring-up`

> **Buat sesi baru: BACA INI DULU.** Spec + plan SUDAH SELESAI & ter-commit. Tugas sesi ini = **EKSEKUSI plan**. Self-contained — sumber kebenaran = spec + plan (di-link §2). Tanggal: **2026-06-05**. Repo: `~/Developer/ai-boilerplate`. **Branch kerja: `design-system-bringup`** (spec+plan udah di situ; JANGAN mulai dari `main`).

---

## 1. Status & tugas

- **Brainstorming SELESAI** — semua fork dikunci (lihat spec). **JANGAN re-decide desain.**
- **Spec DITULIS + di-hardening** lewat 6-dim adversarial self-review (MAJOR_FIXES → 4 must-fix + 11 should-fix di-resolve). Commit `d5be991`.
- **Plan DITULIS** — 12 task one-file-per-task, **18 anchor diverifikasi verbatim ke disk**. Commit `2389f1b`.
- **Tugas lo SEKARANG:** jalanin plan via `executing-plans` (atau `subagent-driven-development`) — 12 task, tiap task: grep-verify anchor → Edit → grep-verify landed + no-renumber → commit. Plan udah punya semua perintah + konten penuh.
- **SETELAH eksekusi:** post-exec fresh-eyes adversarial verify di **sesi LAIN** (§4), lalu **FF-merge + push `origin/main` + hapus branch**.

## 2. Pointer file kunci

- **Plan (yang dieksekusi):** `docs/superpowers/plans/2026-06-05-design-system-bring-up.md` — 12 task, urut. Mulai dari Task 1.
- **Spec (sumber kebenaran desain):** `docs/superpowers/specs/2026-06-05-design-system-bring-up-design.md`.
- **Spec A (LIVE — atom yang B pakai):** `docs/superpowers/specs/2026-06-04-mockup-thread-design-fidelity-design.md` (`build/reference.md §B` = atom dispatch mockup).
- **Memory:** `~/.claude/projects/-Users-stevanus-Developer-ai-boilerplate/memory/MEMORY.md` + `context-vault-project.md` (riwayat + 9 pelajaran eksekusi).

## 3. Apa yang dibangun (recap intent, biar eksekusi paham)

Skill BARU `design-system` = konduktor bring-up fondasi visual untuk project dari-0 (gap greenfield yang Spec A serahkan ke B). Keputusan terkunci:
- **Dua mode** (simetris architect): **SETUP** (app kosong → bootstrap token+komponen primitif dari mockup, bikin kode) & **CAPTURE** (app sudah ada komponen → dokumentasiin ke `.md`, no code-gen).
- **`control/design-system.md` multi-section** — **N design system per produk**, tiap gaya di-scope ke app (`Berlaku buat`). Kode ngikut scope: 1 app → app-local; >1 app → 1 shared package (via `add-package`).
- **Auto-invoke by `feature`** saat `fanout` nandai `DESIGN-SYSTEM NEEDED` (app peran-UI belum-terdaftar); standalone juga.
- **Bangun kode pakai atom Spec A** (`build §B` paste mockup + reproduksi-visual + model terkuat) — `design-system` OWN sintesis unit kerja (bukan invoke build).
- **Carve-out** (dari self-review): `design-system` nulis `consumers[]`+`mandatory_for` LANGSUNG buat ui-kit package (fanout sole-writer gak jalan di jalur ini). **Mockup di-persist** ke `mockups/` SEBELUM elicit (design-system jalan sebelum plan/Spec A). **Eyeball package DITUNDA** ke konsumsi pertama.

## 4. Cara kerja WAJIB + bug-guard

**Proses:** `executing-plans` (atau `subagent-driven-development`) di branch `design-system-bringup` → jalanin Task 1..12 urut, commit per task → **final grep-battery** (ada di akhir plan) → **post-exec fresh-eyes verify di sesi LAIN** (5-lensa: seam-coherence / spec-faithful / mis-aimed-pointer / parent-doc-staleness / prose-casing → adjudikasi skeptis) → **FF-merge + push `origin/main` + hapus branch**.

**Bug-guard (sudah pre-bake di plan — taati):**
- **colon-space** — frontmatter `description:` skill baru JANGAN ada `": "` di nilai (pakai `" — "`). Plan Task 2 udah verify ini.
- **no-renumber** — tiap sentuhan skill existing = sisipan sub-bullet/baris, BUKAN renumber langkah/list. Plan verify count heading.
- **mis-aimed-pointer** — tiap "reference §X" diverifikasi nunjuk seksi yang BENER (streak putus di Spec A — PERTAHANKAN; fresh-eyes read sesi lain tetap wajib).
- **parent-doc-tree staleness** — Task 12 update induk §7 control-tree + §8 repo-tree + §12 lifecycle + §17 (skills **20→21**). JANGAN lewat (kelas bug ke-8×, Spec A lolos §7).
- **sentinel literal-scan** — seed `design-system.md` (Task 3) header murni, TANPA `## <name>`/`Berlaku buat:` palsu.
- **grep pakai `-Fc -e`** untuk anchor literal (robust ke leading-dash `- ` & metachar `[]`/`**`) — plan udah pakai ini.
- **GENERIC** — bahasa visual elicited; JANGAN hardcode Tailwind/shadcn/CSS-lib.

## 5. Catatan

- **render-docs/ask integration DI-DEFER** (additif, non-inti) — bukan bagian plan ini; follow-up terpisah. JANGAN tambahin.
- **Lesson dari 9 eksekusi sebelumnya:** yang lolos verify sesi-eksekusi sendiri biasanya = prose/casing/parent-doc-staleness, bukan logika. Fresh-eyes read di sesi terpisah tetap earn its keep — JANGAN skip post-exec verify.
- **User:** solo dev, bukan orang produk/bisnis → drive proaktif, insist sumber. Casual Bahasa Indonesia ("gw/lo").
- **Antrean lain (jangan campur):** Langkah-2 M4 (schema-projection) → H3 (migration-governance); tes live `/plugin install` end-to-end.
