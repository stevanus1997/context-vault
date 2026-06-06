# HANDOFF — Langkah-3 (gap medium/low + deferred)

> Fresh session: baca ini, act dari sini. Tanggal: **2026-06-06**. Repo `~/Developer/ai-boilerplate`, branch `main` @ `10ea486` (== origin/main, clean). Langkah-2 TUNTAS — mulai Langkah-3.

## Next
1. **Tentukan item Langkah-3 yang digarap** (lihat Open questions — daftar item + mana yang murah). User pilih, atau tanya user dulu.
2. Begitu kepilih, jalankan **resep per-gap** (terbukti 16×): `brainstorming` (WAJIB AskUserQuestion; user **bukan orang produk/teknis** — jelasin plain-language + contoh konkret, lihat [[user-not-product-business-person]]) → tulis spec → **6-dim adversarial spec self-review WORKFLOW (verified-vs-disk)** fix inline → `writing-plans` (one-file-per-task; tiap FIND-anchor `grep -Fc -e` =1 verbatim pra-commit) → branch `<topic>` + commit spec+plan. **Eksekusi + post-exec 6-lens verify = sesi TERPISAH** → FF-merge+push origin/main+hapus branch+update memory.

## State
- **Langkah-2 LIVE @ `10ea486`** (H2 add-package · M5 add-integration · M4 schema-projection · H3 migration-governance). **21 skill + 2 rule baru** (`schema-projection.md`, `migration-impact.md`). Langkah-1 (invariants+security-gate) + 5 fase build awal juga LIVE.
- Plugin **GENERIC** (bukan ecommerce-specific; "Shopify-builder solo-dev full-AI" cuma skenario uji audit).

## Decisions
- Garap **Langkah-3 dulu** (user pilih di atas live-install test).
- Langkah-3 **semua medium/low — bukan fatal**; inti "produk uang+PII tahan banting" sudah ketutup Langkah-1+2. Boleh dicicil / re-prioritas / skip per kebutuhan.

## Open questions
- **Item Langkah-3 mana dulu?** (proposed-fix tiap item: lihat Pointers handoff `2026-06-01-langkah-2-sisa-3.md` §4)
  - **M6** compliance-risk discovery kebuang (PCI/pajak/KYC/GDPR) — **paling murah / kandidat quick-win**
  - **M1** roadmap/epic decomposition · **M3** platform-capability slot (queue/job/RBAC/audit lintas-app) · **M7** graduated-autonomy (gate flat → bottleneck approval) · **M8** observability feedback loop
  - **L1** capability blueprint · **L2** iterasi-v2/deprecate · **L3** render-docs "shipped"≠"live"
  - **Deferred** deploy/release/env-model penuh · `extract` brownfield package-inference

## Pointers
- **Daftar lengkap Langkah-3 + proposed-fix per item:** `docs/superpowers/handoff-2026-06-01-langkah-2-sisa-3.md` §4 (+ §5 resep proses).
- **Contoh spec+plan terbaru (TIRU):** H3 `docs/superpowers/specs/2026-06-06-h3-migration-governance-design.md` + plan `docs/superpowers/plans/2026-06-06-h3-migration-governance.md` (one-file-per-task, anchor grep-verified, 6-dim self-review).
- **Parent spec (sumber kebenaran):** `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§7 control-tree, §8 repo-tree, §9 stages, §12 lifecycle, §17 komponen/skill-count=21).
- **Memory:** `~/.claude/projects/-Users-stevanus-Developer-ai-boilerplate/memory/{MEMORY.md, context-vault-project.md}` (riwayat per-gap + Lesson #1-16).

## Gotchas
- **Live `/plugin install` end-to-end test BELUM PERNAH** (semua fase; semua skill cuma diverifikasi dry-run / "AI pura-pura jadi skill", bukan plugin ter-install + auto-trigger di sesi baru). **Risiko tertua** — butuh tangan user (install + reload + trigger). Pertimbangkan sebelum numpuk gap lagi.
- **README drift:** Status-narrative README belum sebut M4 + H3 (locked "README untouched" saat itu) — backfill di sync berikut.
- **Bug-guard per-plan (pasang preventif):** colon-space `description:` frontmatter (pakai ` — ` bukan `: `); no-renumber (sisip decimal/sub-bullet, jangan renumber step + cek cross-ref "step N"); mis-aimed-pointer (tiap §X/reference nunjuk seksi benar — di skill DAN spec; edit-map before→after BUKAN pointer live); `grep -Fc -e` verbatim anchor pra-commit (em-dash `—` vs arrow `→` vs middot `·` U+00B7 byte-trap, dup-phrase scope ke file target); one-file-per-task; anti-fiksi (jangan sandar artefak yang belum ada di disk); parent-doc staleness cuma ke-catch fresh-eyes READ (grep miss prosa/sidebar).
- **Lesson #15/#16:** sertakan lensa **design-hole STRESS-TEST** di spec-self-review DAN post-exec verify — nangkep (a) klaim arsitektural-nyaman yang gagal di kasus pemicu, (b) "promise di spec vs shipped-text di surface tempat logika BENERAN jalan" (≠ faithful-exec edit-map check).
