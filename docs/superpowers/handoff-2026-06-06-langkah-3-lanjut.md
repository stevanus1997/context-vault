# HANDOFF — Langkah-3 lanjut (M6 TUNTAS; pilih gap berikutnya)

> Fresh session: baca ini, act dari sini. Tanggal: **2026-06-06**. Repo `~/Developer/ai-boilerplate`, branch `main` @ `1dba8d1` (== origin/main, clean). **M6 (gap pertama Langkah-3) LIVE.** Langkah-1 + Langkah-2 (H2/M5/M4/H3) juga LIVE.

## Next
1. **Pilih item Langkah-3 berikutnya** (lihat Open questions) — tanya user dulu; user **bukan orang produk/teknis**, jelasin plain-language + contoh konkret ([[user-not-product-business-person]]).
2. Begitu kepilih, jalankan **resep per-gap** (terbukti 17×): `brainstorming` (WAJIB AskUserQuestion) → tulis spec → **6-dim adversarial spec self-review WORKFLOW (verified-vs-disk)** fix inline → `writing-plans` (one-file-per-task; tiap FIND-anchor `grep -Fc -e` =1 verbatim pra-commit) → branch `<topic>` + commit spec+plan. **Eksekusi + post-exec 6-lens verify boleh sesi sama atau terpisah** (user M6 eksekusi di sesi terpisah, verify+merge di sesi lain — dua-duanya jalan) → FF-merge+push origin/main+hapus branch+update memory.
3. **ATAU** garap risiko tertua: **live `/plugin install` end-to-end test** (lihat Gotchas).

## State
- **M6 LIVE @ `1dba8d1`** (rule `compliance-risk.md` + template `control/business/risks.md`; discovery carve-out → architect/intake/ship-security-critic baca). **21 skill, 5 rule** (anti-yes-man·debt-aware·schema-projection·migration-impact·compliance-risk).
- Plugin **GENERIK** (skenario "Shopify-builder solo-dev full-AI" cuma alat uji audit).

## Decisions
- **Langkah-3 semua medium/low — bukan fatal**; inti "produk uang+PII tahan banting" sudah ketutup Langkah-1+2. Boleh dicicil / re-prioritas / skip per kebutuhan.
- M6 = advisory (peringatan, bukan gate baru); di seam ship memperkaya gate existing (bisa lebarkan RED utk fitur sensitivity payments/pii) — sudah didokumentasi jujur.

## Open questions
- **Item Langkah-3 mana berikutnya?** (proposed-fix tiap item: handoff `2026-06-01-langkah-2-sisa-3.md` §4)
  - **M1** roadmap/epic decomposition (field `epic`+`depends_on[]` di feature.yaml + warn-gate)
  - **M3** platform-capability slot (queue/job/RBAC/audit/rate-limit lintas-app; nudge fanout + app `worker`)
  - **M7** graduated-autonomy (`feature.yaml risk:low|normal|high` + build unattended per-segmen; JANGAN ambil batch/sticky-approve)
  - **M8** observability feedback loop (`control/feedback/` dibaca intake)
  - **L1** capability blueprint · **L2** iterasi-v2/deprecate · **L3** render-docs "shipped"≠"live"
  - **Deferred** deploy/release/env-model penuh · `extract` brownfield package-inference

## Pointers
- **Daftar lengkap Langkah-3 + proposed-fix per item:** `docs/superpowers/handoff-2026-06-01-langkah-2-sisa-3.md` §4 (+ §5 resep proses).
- **Contoh spec+plan terbaru (TIRU):** M6 spec `docs/superpowers/specs/2026-06-06-m6-compliance-risk-design.md` + plan `docs/superpowers/plans/2026-06-06-m6-compliance-risk.md` (one-file-per-task, anchor grep-verified, 6-dim self-review, honesty-note pola).
- **Parent spec (sumber kebenaran):** `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§7 control-tree, §8 repo-tree, §9 skills, §12 lifecycle, §17 komponen — skill 21, rule 5).
- **Memory:** `~/.claude/projects/-Users-stevanus-Developer-ai-boilerplate/memory/{MEMORY.md, context-vault-project.md}` (riwayat per-gap + Lesson #1-18).

## Gotchas
- **Live `/plugin install` end-to-end test BELUM PERNAH** (semua fase; semua skill cuma diverifikasi dry-run / "AI pura-pura jadi skill"). **Risiko tertua** — butuh tangan user (install + reload + trigger di sesi baru). Pertimbangkan sebelum numpuk gap lagi.
- **README drift:** Status-narrative README belum sebut M4 + H3 + M6 (locked "README untouched" tiap gap) — backfill di sync berikut.
- **MEMORY.md > limit** (~28KB): index entry context-vault sudah satu baris raksasa. Jangan nambah-numpuk; detail per-gap masuk `context-vault-project.md`, MEMORY.md cukup ringkas.
- **Bug-guard per-plan (pasang preventif):** colon-space `description:` frontmatter (pakai ` — `/`/` bukan `: `); no-renumber (sisip sub-bullet/decimal, cek cross-ref "step N"); mis-aimed-pointer (tiap §X nunjuk seksi benar — induk ship-gate prose di **§9** bukan §17; rules muncul DUA tempat §8 tree + §17); `grep -Fc -e` verbatim anchor pra-commit (em-dash `—` vs arrow `→` vs middot `·` U+00B7 byte-trap; spasi-alignment tree); one-file-per-task; anti-fiksi.
- **Lesson #15-18 (sertakan di self-review DAN post-exec verify):** design-hole STRESS-TEST (klaim arsitektural-nyaman yg gagal di kasus pemicu); "promise di spec vs shipped-text di surface tempat logika BENERAN jalan"; parent-doc paragraf deskripsi-agent (induk §10) perlu di-track tiap nambah lensa; pilihan user yg tegang (advisory + kasih-ke-gate-existing) → jujur-in-shipped-text di surface verdict.
