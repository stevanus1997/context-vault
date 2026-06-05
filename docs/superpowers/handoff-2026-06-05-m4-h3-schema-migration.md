# HANDOFF — Langkah-2 M4 (schema-projection) → H3 (migration-governance)

> Fresh session: baca ini, langsung act. Tanggal: **2026-06-05**. Repo `~/Developer/ai-boilerplate`, branch `main` @ `6960b3b` (clean). Dua gap terakhir Langkah-2; **garap M4 dulu** (M4 mengaktifkan H3). Tiap gap = spec+plan sendiri, sesi terpisah.

## Next (urut)
1. **M4 dulu.** Jalankan proses WAJIB (lihat Gotchas): `brainstorming` (eksplor Open questions M4 via AskUserQuestion — jangan pre-decide) → tulis spec ke `docs/superpowers/specs/2026-06-XX-m4-schema-projection-design.md` → **6-dim adversarial spec self-review (workflow, verified-vs-disk)** → `writing-plans` (one-file-per-task, tiap anchor `grep -Fc -e`-verified verbatim sebelum commit) → branch `m4-schema-projection` → `executing-plans` (sesi terpisah) → post-exec fresh-eyes verify (sesi LAIN) → FF-merge + push + hapus branch.
2. **H3 sesudah M4 LIVE.** Spec+plan terpisah. H3 me-re-anchor "siapa baca table X" ke artefak M4 (`control/schema/`) — jadi M4 harus ada dulu.

## State
- LIVE di `origin/main` @ `6960b3b` (21 skill): Langkah-1 (invariants + security-gate), Langkah-2 **H2** (shared-package) + **M5** (integrations), **Spec A** (mockup-thread), **Spec B** (design-system). H2+M5 nutup 2 dari 4 gap Langkah-2.
- **M4 + H3 BELUM mulai.** Sisa terakhir Langkah-2.

## Arah dari audit (TITIK-AWAL brainstorming — BUKAN keputusan final; tetap lewati AskUserQuestion)
- **M4 — model-data durable (MEDIUM, mengaktifkan H3).** Gap: skema cuma baris inline `plans/<app>.md` per-fitur, direkonstruksi dari kode tiap sesi (fitur #20 butuh bentuk Order/Product/Tenant dari fitur lama → AI baca ulang ~30 table). Arah fix: `control/schema/<app>.md` = **PROJEKSI ter-generate dari migrations** (di gate migrate / render-docs), **BUKAN doc tangan** (hormati induk §4 "satu sumber kebenaran, banyak proyeksi"). `plan` baca sebagai input step-1. Asimetri SADAR vs M5/`integrations.md` (M5 hand-authored — vendor tanpa hulu; skema PUNYA hulu = migrasi → diproyeksi).
- **H3 — migration-governance lintas-fitur (HIGH).** Gap: tak ada gate dampak saat fitur baru ALTER table fitur lama (ref-integrity/backfill) + tak ada governance urutan migrasi/zero-downtime lintas-app/repo (`plan` scoped 1 app; gate `migrate` build cuma "apply/tidak"). Trigger: ubah `Order.status` / pecah `Product.price`→`ProductVariant`; kolom NOT NULL dibaca worker+dashboard tanpa expand-contract → LIVE = lock = downtime. Arah fix: section "Dampak skema lintas-fitur" di `plan` + `migrate.kind: additive|destructive|backfill` + `migrate.affects:[table]` di `breakdown` + gate `migrate` build tampilkan consumer+lock-risk+backfill + `ship` "urutan deploy & migrasi" + konvensi zero-downtime ke `conventions.md`.

## Open questions (M4 — neutral, putuskan di brainstorming)
- Proyeksi di-generate KAPAN & oleh SIAPA — di gate `migrate` (`build`), di `render-docs`, atau dua-duanya? Skill baru vs perluas existing?
- Bentuk file: per-app (`control/schema/<app>.md`) vs satu file? Isi apa (tables/kolom/relasi/owning-feature)?
- Gimana jaga fresh tanpa drift (regenerasi vs incremental)?
- (H3, nanti) granularitas consumer-tracking "fitur/kolom mana gantung ke table X" — diturunkan dari proyeksi M4 gimana?

## Pointers
- **Detail audit + M4/H3/Langkah-3 lengkap:** `docs/superpowers/handoff-2026-06-01-langkah-2-sisa-3.md` (M4 baris 72-75, H3 77-81, **caveat koherensi 121**).
- **Parent spec (sumber kebenaran):** `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§4 satu-sumber-banyak-proyeksi, §7 control-tree, §8 repo-tree, §12 lifecycle, §17 komponen/skill-count).
- **Resep proses terbukti (contoh tiru):** Spec B — spec `docs/superpowers/specs/2026-06-05-design-system-bring-up-design.md` + plan `docs/superpowers/plans/2026-06-05-design-system-bring-up.md` (one-file-per-task, anchor grep-verified).
- **Memory:** `~/.claude/projects/-Users-stevanus-Developer-ai-boilerplate/memory/{MEMORY.md,context-vault-project.md}` (riwayat + 11 pelajaran eksekusi).

## Gotchas / bug-guard
- **Koherensi (CRITICAL):** saat garap M4, `control/schema/` + `data-model.md`/`roadmap.yaml` MASIH FIKSI — jangan source dari mereka, **jangan nyandar H3**; re-anchor ke primitif yang ADA (migrasi, `plans/<app>.md`). Saat garap H3: basis consumer dari **M4 `control/schema/`**, **BUKAN `packages[].consumers` (H2)** — itu "app impor package", konsep BEDA dari "fitur/kolom gantung ke table".
- **Generic:** M4 proyeksi harus jalan lintas ORM/tool migrasi (Prisma/Drizzle/raw SQL/Django/dll) — diturunkan runtime dari migrasi yang ADA, bukan parser hardcode satu stack.
- **Proses WAJIB:** brainstorming dulu (jangan pre-decide); spec self-review = **workflow 6-dim adversarial verified-vs-disk** (di Spec B nangkep 4 must-fix STRUKTURAL di tahap-spec — murah di hulu); writing-plans one-file-per-task + tiap anchor `grep -Fc -e`-verified verbatim; eksekusi & verify di **sesi terpisah**.
- **Bug-guard pre-bake:** colon-space frontmatter (` — ` bukan `: `); no-renumber (sisipan sub-bullet, bukan renumber langkah); mis-aimed-pointer (verifikasi tiap §X nunjuk seksi yang bener — di skill DAN spec); **kalau nambah skill → update plugin.json + marketplace.json + README + induk §7/§8/§12/§17 (skill-count)**; sentinel literal-scan trap; `grep -Fc -e` untuk cek anchor (robust leading-dash `- ` & metachar `[]`/`**`).
