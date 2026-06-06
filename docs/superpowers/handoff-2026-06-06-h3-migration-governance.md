# HANDOFF — Langkah-2 H3 (migration-governance) — gap TERAKHIR

> Fresh session: baca ini, langsung act. Tanggal: **2026-06-06**. Repo `~/Developer/ai-boilerplate`, branch `main` @ `92c0ed6` (clean). H3 = gap **terakhir** Langkah-2 (M4 sudah LIVE → dependency H3 ada). Spec+plan sendiri; eksekusi + verify di sesi TERPISAH.

## Next (urut)
1. **brainstorming** (WAJIB — eksplor Open questions via AskUserQuestion, JANGAN pre-decide) → tulis spec ke `docs/superpowers/specs/2026-06-XX-h3-migration-governance-design.md`.
2. **6-dim adversarial spec self-review (workflow, verified-vs-disk)** — di M4 nangkep must-fix struktural di tahap-spec (murah). Fix inline.
3. **writing-plans** (one-file-per-task; tiap FIND-anchor `grep -Fc -e`-verified =1 verbatim dari disk SEBELUM commit).
4. branch `h3-migration-governance` → commit spec+plan.
5. **executing-plans** (sesi terpisah) → post-exec fresh-eyes verify (sesi LAIN, 6-lens workflow) → FF-merge + push + hapus branch.

## State
- **M4 LIVE @ `92c0ed6`** (21 skill). `control/schema/<app>.md` ADA = proyeksi per-app (table·kolom·relasi·provenance `Asal`/`terakhir-ubah`), di-generate `wire`(baseline)+`build`(pasca task-migrate `done`) lewat `rules/schema-projection.md`. **Ini jangkar H3** — tapi M4 cuma **producer-side** (siapa BIKIN/UBAH table); H3 = **consumer-side** (siapa BACA table). M4 sengaja TAK simpan consumer.
- Migrate hari ini: `actions: - migrate: <deskripsi>` (string tunggal) di breakdown; gate `build` cuma "tampilkan rencana + approve sebelum apply" (binary, destruktif). `plan` scoped 1 app. Tak ada governance urutan/zero-downtime lintas-app/repo.

## Arah dari audit (TITIK-AWAL brainstorming — BUKAN final; tetap lewati AskUserQuestion)
- **Gap:** tak ada gate dampak saat fitur baru ALTER table fitur lama (ref-integrity/backfill); tak ada governance urutan migrasi/zero-downtime lintas-app/repo. Trigger: ubah `Order.status` / pecah `Product.price`→`ProductVariant`; kolom NOT NULL dibaca worker+dashboard tanpa expand-contract → LIVE = lock = downtime.
- **Fix direction:** section "Dampak skema lintas-fitur" di `plan` + `migrate.kind: additive|destructive|backfill` + `migrate.affects:[table]` di `breakdown` + gate `migrate` build tampilkan consumer+lock-risk+backfill + `ship` "urutan deploy & migrasi" + konvensi zero-downtime (expand-contract) ke `conventions.md`.

## Open questions (H3 — neutral, putuskan di brainstorming)
- **(CRUX) "siapa BACA table X" (consumer-of-table) diturunkan dari mana?** opsi: dari relasi/FK di M4 `control/schema/` · scan kode app saat gate · field consumer baru yang di-track (siapa yang nulis?). M4 TAK simpan ini (sengaja). JANGAN pakai `packages[].consumers` (itu "app impor package", konsep BEDA).
- granularitas consumer: per-table cukup, atau per-**kolom** (trigger-nya "kolom NOT NULL dibaca worker")?
- H3 nambah skill baru, atau cuma extend `plan`/`breakdown`/`build`/`ship`/`conventions.md`? (kalau tak nambah skill → skill tetap **21**; kalau nambah → update plugin.json+marketplace+README+induk §7/§8/§12/§17).
- `migrate.kind`/`affects`: parse `<deskripsi>` string yang ada, atau field eksplisit baru di task schema breakdown? (audit condong field eksplisit).
- urutan deploy lintas-repo di `ship`: runbook advisory atau gate keras? expand-contract: di-enforce sebagai gate atau di-flag risk + konvensi?

## Pointers
- **Resep proses terbukti (TIRU):** M4 spec `docs/superpowers/specs/2026-06-05-m4-schema-projection-design.md` + plan `docs/superpowers/plans/2026-06-05-m4-schema-projection.md` (one-file-per-task, anchor grep-verified, 6-dim self-review).
- **Audit asli H3 + caveat koherensi:** `docs/superpowers/handoff-2026-06-01-langkah-2-sisa-3.md` (H3 ~baris 77-81, coherence caveat ~121).
- **M4 artifact (jangkar):** `plugin/rules/schema-projection.md` + format `control/schema/<app>.md` (M4 spec §4).
- **Surfaces yang kemungkinan H3 edit:** `plugin/skills/{plan,breakdown,build,ship}/{SKILL.md,reference.md}` + `plugin/template/control/conventions.md`. (breakdown task schema: reference §A; §D-4 = package DILARANG migrate.)
- **Parent (sumber kebenaran):** `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§7 control-tree, §8 repo-tree, §12 lifecycle, §17 skill-count=21).
- **Memory:** `~/.claude/projects/-Users-stevanus-Developer-ai-boilerplate/memory/{MEMORY.md,context-vault-project.md}` (riwayat + Lesson #1-14).

## Gotchas / bug-guard
- **Koherensi (CRITICAL):** consumer-of-table H3 di-anchor ke M4 `control/schema/` — **BUKAN `packages[].consumers` (H2)**, **BUKAN `data-model.md`/`roadmap.yaml` (fiksi, gak ada di disk)**.
- **Generic:** `migrate.kind`/`affects` + lock-risk + expand-contract harus jalan lintas ORM/tool migrasi — diturunkan runtime, bukan hardcode satu stack.
- **Lesson #14 (dari M4 verify):** (a) parent-doc-staleness (mis. induk §13 sidebar, §9 input-lists) cuma ke-catch fresh-eyes READ — grep-battery miss prosa; verify-pass WAJIB baca induk utuh. (b) functional empty/edge hole cuma ke-catch lensa ADVERSARIAL STRESS-TEST (bayangin input ekstrem, mis. "semua app kosong") — sertakan lensa itu di verify, jangan cuma faithful-exec/seam/pointer.
- **Lesson #12-13:** 6-dim spec-self-review WORKFLOW nangkep struktural di hulu (murah); `grep -Fc -e` verbatim anchor-verify WAJIB pra-commit (nangkep em-dash `—` vs arrow `→` byte-trap, anchor ganda/0).
- **Bug-guard pre-bake:** colon-space frontmatter (` — ` bukan `: ` di nilai `description:`); no-renumber (sisip sub-bullet/decimal step, bukan renumber langkah); mis-aimed-pointer (verifikasi tiap §X nunjuk seksi benar — di skill DAN spec); `grep -Fc -e` anchor (robust leading-dash `- ` & metachar `[]`/`**`/backtick); dup-phrase (cek frasa anchor unik antar-file sebelum edit).
