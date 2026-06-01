# HANDOFF — context-vault Langkah 2 (sisa M5/M4/H3) + Langkah 3

> **Buat sesi baru: BACA INI DULU.** Dokumen ini self-contained — kamu tak perlu konteks chat sesi sebelumnya. Sumber kebenaran tetap spec + plan + memory di repo (di-link di bawah). Tanggal handoff: **2026-06-01**. Repo: `~/Developer/ai-boilerplate` (github.com/stevanus1997/context-vault), branch kerja: `main`.
>
> **Menggantikan** `docs/superpowers/handoff-2026-06-01-langkah-2-3.md` (handoff lama; H2 di situ sekarang SUDAH selesai).

---

## 0. TL;DR — apa yang harus dilakukan

1. **Langkah 1 = SELESAI & LIVE di `main`** (@ `54632e4`). **H2 + M5 (dua gap pertama Langkah 2) = SELESAI & LIVE di `main`** (@ `264b017`). Jangan ulang ketiganya.
2. **Langkah 2 BELUM kelar** — sisa **M4 → H3** (urutan dari audit; M4 mengaktifkan H3). **Mulai dari M4.** Tiap gap = **spec terpisah** (subsistem agak independen, jangan dijejal 1 spec).
3. **Setelah Langkah 2 tuntas → Langkah 3** (item medium/low + deferred; lihat §4).
4. **Cara kerja WAJIB** (lihat §5): `brainstorming → tulis spec → writing-plans → executing-plans (sesi terpisah) → verifikasi pasca-eksekusi sesi-LAIN → FF-merge+push`. JANGAN skip brainstorming. Plugin ini **GENERIC** (bukan khusus ecommerce — Shopify cuma skenario uji).
5. **Sebelum nulis spec apa pun:** baca §5 caveat koherensi — beberapa usulan fix nyandar artefak yang BELUM ADA; jangan source dari fiksi.

---

## 1. Problem & konteks

**Apa itu context-vault:** Claude Code plugin + template yang nyediain **lapisan AI + knowledge (BUKAN kode)** buat ngelola produk multi-app. Knowledge hidup di `control/` (`workspace.yaml`, `business/`, `conventions.md`, `invariants.md`, `features/`), tumbuh just-in-time tiap fitur. Lifecycle skill (post-H2):

```
discovery → init → architect → wire → feature(intake→fanout→plan) → breakdown → build → ship
            (+ cabang add-app saat fitur butuh app baru)
            (+ cabang add-package saat fitur butuh shared package baru)   ← BARU dari H2
            (+ drop; extract; render-docs)
```
**17 skill** + 2 agent (`critic`, `security-critic`). Desain induk: `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`.

**Asal kerjaan ini:** user (solo dev) minta stress-test — "anggep gw solo dev mau bikin **ecommerce builder ala Shopify** (SaaS multi-tenant: merchant bikin toko sendiri, katalog/cart/checkout, **pembayaran Stripe Connect + payout + platform fee**, order/shipping/pajak, theme builder, custom domain per tenant, webhook, background job) **full-AI** pakai pipeline ini — flow mana yang bolong?"

**Audit adversarial** (26-agent: 8 finder lensa-beda baca file skill asli → cluster/dedup → skeptik per-gap baca-file → sintesis): **45 temuan mentah → 16 gap kanonik, 0 dibantah**. **Vonis:** pipeline **sehat di sumbu "satu fitur ide→PR"**, **bolong di sumbu "produk utuh berbasis uang+PII"** — 3 klaster: (a) **hulu kosong** (no roadmap/invarian/shared-package/integrasi/data-model durable), (b) **nol gate keamanan**, (c) **lifecycle mati di "PR dibuka"**. Tak ada gap yang bikin crash — semuanya **degradasi senyap / utang yang numpuk pas skala Shopify**.

Gap dipetakan ke **Langkah** by impact: Langkah 1 (fatal+murah, **DONE**), Langkah 2 (akar merembet, H2 **DONE**, sisa **M5/M4/H3**), Langkah 3 (medium/low + deferred).

---

## 2. STATUS — yang sudah LIVE di `main`

### 2.1 Langkah 1 (H1+H4+M2) — LIVE @ `54632e4`
Gap H1 (invarian platform dikunci telat), H4 (nol gate keamanan), M2 (invarian tak ter-enforce). Tanpa skill baru.
- Spec: `docs/superpowers/specs/2026-06-01-platform-invariants-security-gate-design.md` · Plan: `…/plans/2026-06-01-platform-invariants-security-gate.md`
- LIVE: `control/invariants.md` (template, 6 slot saran, sentinel `<belum dikunci>`) · `architect` langkah 4.5 "Kunci Invarian" (gated, critic WAJIB, idempotent) · `wire` step 0 nolak bring-up kalau invarian belum resolved · agent `security-critic.md` (read-only red-team diff) · `ship` langkah 4.5 Security Gate (berskala `feature.yaml sensitivity`, STOP-on-fail) · tag `sensitivity` diusulkan `intake` · M2 challenge "melanggar invarian terkunci?" di `plan`/`breakdown`/`build`.

### 2.2 H2 — Shared-package end-to-end + fan-IN — LIVE @ `fa62982` (BARU)
Gap: pipeline buta total terhadap shared package (workspace cuma `apps[]`; add-app nolak package; `task.app==apps[].name`; nol fan-IN). **Sekarang tertutup.**
- Spec: `docs/superpowers/specs/2026-06-01-h2-shared-package-design.md` · Plan: `…/plans/2026-06-01-h2-shared-package.md`
- **Yang LIVE:**
  - **`packages[]` di `workspace.yaml`** — `{name, path, type:package, responsibility, consumers[], mandatory_for, stack}` (TANPA capabilities/db/route/`version` — lock-step). `init` seed `packages: []` kosong.
  - **Skill baru `add-package`** (`plugin/skills/add-package/SKILL.md`, **tanpa reference.md**) — cermin `add-app`: declare entri → `architect` (mode-package, langkah 3c) → `wire` (mode-package, reference §I); **gate = typecheck hijau**, SKIP DB/wiring/smoke. Satu-satunya penulis entri `packages[]` pasca-init.
  - **`fanout`** = **penulis tunggal `consumers[]`** (idempotent); nandai `PACKAGE NEW` (belum ada → add-package) & `PACKAGE TOUCHED` (existing, API disentuh → basis fan-IN).
  - **`feature`** auto-invoke `add-package` saat `PACKAGE NEW` (sebelum `plan`), cermin seam `APP NEW`→`add-app`.
  - **`plan`** tulis `plans/<pkg>.md` (kontrak exports/signature) + flag **`BREAKING`** (carve-out: package yang BARU dibikin fitur itu TIDAK breaking); baca `packages[]`/`consumers[]` read-only.
  - **`task.app` → `task.unit`** (app ATAU package ATAU `integration`) — gate validasi eksplisit di `breakdown` (dulu laten, gagal telat di build).
  - **Robot fan-IN** (`breakdown` §D-4 + `build`): `BREAKING` → 1 task ubah package + **1 update-task per consumer** (`deps:[task-pkg]`) + 1 task `integration` retest; `build` **cheap-skip** consumer yang tak kena (enumerasi semua = aman, biaya per-consumer murah).
  - **M2 `mandatory_for`** + challenge "membypass mandatory package?" di `plan`/`breakdown`/`build` (klausa yang ditunda dari Langkah-1, **kini direalisasikan**).
  - **Hygiene:** `wire` mode-package, `ship` probe repo package + PR-grouping, `render-docs` kartu package, `drop` drop-package + bersihin consumers[], `conventions.md` heading "Konvensi Package".
- **Pelajaran verifikasi H2** (penting buat M5/M4/H3): post-exec adversarial 5-dimensi → seam/design-hole/spec-staleness **CLEAN first-pass**; functional core (fan-IN/M2/seam) bener dari awal. Yang lolos verify-sesi-eksekusi-sendiri kali ini = **5 spot polish rename di prose/komentar/frontmatter-description** (bukan field/logic) — mis. kontradiksi dalam-kalimat "untuk tiap **unit** NYATA… Kelompokkan **app** per repo" + description "gate per app/milestone"; di-fix `fa62982`. **Lesson ke-6 (konsisten):** fresh adversarial read sesi-LAIN tetap perlu walau temuan makin tipis; **cek frontmatter description, bukan cuma body.** Plus: kalau spec punya **edit-map** (before→after) yang nge-quote teks-lama, itu BUKAN mis-aimed-pointer (jangan "fix" jadi salah) — dokumentasi perubahan, bukan pointer live.

---

## 3. LANGKAH 2 — SISA (garap berurutan: M4 → H3)

> H2 + M5 sudah DONE & LIVE @ `264b017` (blok M5 di bawah = RIWAYAT, JANGAN dikerjakan ulang). Mulai dari **M4**. Tiap gap = spec+plan sendiri. Usulan fix di bawah = titik-awal brainstorming, BUKAN keputusan final — selalu lewati `brainstorming` + AskUserQuestion dulu.

### M5 — Integrasi vendor tak punya rumah durable (severity: MEDIUM) ✅ SELESAI & LIVE @ 264b017
**Gap:** vendor eksternal (Stripe/email/carrier/tax) tak punya entitas di `control/`; kontrak vendor di-derive ULANG tiap fitur di `plans/_shared.md`; `fanout` tak punya kolom vendor; hasil langkah manual (secret/webhook/mode test-live) tak mendarat; webhook **inbound** + mode test/live tak dimodelkan.
**Trigger:** Stripe Connect nyentuh 5 fitur × 3 app; idempotency/webhook/signature di-derive ulang; risiko launch pakai `sk_test_`.
**Usulan fix:** `control/integrations.md` (SHAPE-only: vendor, endpoint webhook, idempotency-key, mode test/live, secret shape, retry) + `plan` baca/promote kontrak vendor (O(1)/vendor) + varian task "inbound eksternal" (verifikasi signature/idempotent/replay) + `wire` scaffold webhook-receiver stub. **Silang dgn Langkah-1:** webhook-signature & secret sudah jadi lensa `security-critic` (ship 4.5) — integrations.md kasih dia baseline. **Silang dgn H2:** kalau ada `@store/payments` package, vendor-contract bisa nyentuh `packages[].consumers`.

### M4 — Tak ada model-data durable (severity: MEDIUM) — mengaktifkan H3
**Gap:** skema cuma hidup sebagai baris inline di `plans/<app>.md` per-fitur, direkonstruksi dari kode tiap sesi.
**Trigger:** fitur #20 perlu bentuk Order/Product/Tenant dari fitur #1/#3/#7; AI rekonstruksi ~30 table dari kode mentah.
**Usulan fix:** `control/schema/<app>.md` sebagai **PROJEKSI TER-GENERATE dari migrations** (di gate migrate / render-docs) — **BUKAN doc tangan** (hormati prinsip induk §4 "satu sumber kebenaran, banyak proyeksi"). `plan` baca sebagai input step-1. Ini memberi **basis consumer-skema** yang dibutuhkan H3.

### H3 — Tak ada migration-governance lintas-fitur (severity: HIGH)
**Gap:** tak ada gate dampak saat fitur baru **ALTER table** milik fitur lama (referential integrity/backfill) maupun governance urutan migrasi/zero-downtime lintas-app/lintas-repo. `plan` scoped ke 1 app; `migrate`-gate `build` cuma "apply atau tidak".
**Trigger:** fitur #20 ubah `Order.status`/pecah `Product.price`→`ProductVariant`; multi-repo kolom NOT NULL dibaca worker+dashboard tanpa expand-contract → di sistem LIVE = lock = downtime.
**Usulan fix:** section "Dampak skema lintas-fitur" di `plan` + `migrate.kind: additive|destructive|backfill` + `migrate.affects:[table]` di `breakdown` + `migrate`-GATE `build` tampilkan consumer + lock-risk + butuh-backfill + `ship` section "urutan deploy & migrasi" + konvensi zero-downtime ke `conventions.md`.
**Re-anchor consumer (PENTING):** basis "siapa baca table X" datang dari **M4** (`control/schema/`), bukan `data-model.md` yang nggak ada. **JANGAN keliru pakai `packages[].consumers` (H2)** — itu "app mana impor package", konsep BEDA dari "fitur/kolom mana gantung ke table". Garap H3 SETELAH M4 ada.

---

## 4. LANGKAH 3 — LATER (diskusikan prioritas setelah Langkah 2 tuntas)

Medium/low + sebagian sengaja-deferred.

- **M1 (med) — Roadmap/epic decomposition.** Entrypoint langsung lompat ke satu `/feature`; tak ada yang ubah visi → backlog terurut sadar-dependency. Fix-light: field `epic`+`depends_on[]` di feature.yaml + warn-gate (bukan hard-block) + sizing-check di intake. Skill `roadmap` penuh = defer di belakang `brainstorming`.
- **M3 (med) — Platform-capability slot.** workspace.yaml tak punya tempat untuk queue/job-runner/RBAC/audit/rate-limit lintas-app. Fix: nudge fanout "peran ini cross-cutting?" + rekomendasi app `worker` di architect; `platform:` block + skill = defer.
- **M6 (med) — Risiko compliance discovery kebuang.** `discovery` riset PCI/pajak/KYC/GDPR tapi seed konservatif buang analisis risiko; tak ada skill hilir baca discovery.html. Fix: `control/business/risks.md` yang discovery WAJIB seed (carve-out: risiko compliance boleh durable, risiko pasar tetap di HTML) + architect/intake baca sbg constraint. **(Murah — kandidat quick-win.)**
- **M7 (med) — Graduated autonomy.** Gate flat → solo dev jadi bottleneck approval (~17-19 stop/fitur). Fix: `feature.yaml risk:low|normal|high` (auto-tag-high HARD floor) + build `--unattended` per-segmen. **JANGAN ambil** batch/sticky-approve yang ngikis review per-app (itu value-prop buat produk bayar) — cukup unattended-segment + tiering.
- **M8 (low) — Observability feedback loop.** Produk live hasilkan incident tapi tak ada jalan balik ke intake. Fix: `control/feedback/` + intake baca sbg input (soft).
- **L1 (low) — Capability blueprint.** 1 prompt opsional di init "produk besar → declare semua app target sekarang".
- **L2 (low) — Iterasi-v2 / deprecate.** Status cuma draft/active/shipped/dropped; tak ada v2/deprecation fitur live. Promosikan rencana S4.1 (immutable old-folder + `<nama>-v2` + status `deprecated`).
- **L3 (low) — render-docs "shipped"≠"live".** Wording badge nyesatin. Fix interim: label "siap-kirim/merged" bukan "live".
- **Sengaja-deferred (spec struktural `2026-05-31-pipeline-hardening-structural-design.md` §S4.1/§10):** deploy/release/env-model penuh, post-ship lifecycle, provenance. Buat Shopify ini mode dominan tapi berat — ambil hanya **jembatan minimal** dulu (mis. `ship` "Release notes & deploy checklist" yang agregasi semua `manual:`/`actions(env+migrate)` jadi runbook).
- **extract brownfield package-inference (dari H2, di-defer):** `extract` nebak shared package dari scan kode existing — sub-proyek tersendiri, belum digarap.

---

## 5. Cara kerja project (WAJIB diikuti)

**Workflow per gap** (pola konsisten dari semua skill: wire/add-app/pipeline-hardening/Langkah-1/H2):
1. **`brainstorming`** (skill superpowers) — JANGAN skip. Tanya 1-1 (AskUserQuestion), kunci keputusan desain, sajikan design, approve. (Catatan: user **bukan orang produk/bisnis** — kalau perlu, jelasin opsi pakai contoh konkret dulu; lihat memory [[user-not-product-business-person]].)
2. **Tulis spec** → `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`, self-review (idealnya 1 ronde adversarial fan-out: konsistensi/coherence-guard/anchor/amandemen/design-hole), commit, user review.
3. **`writing-plans`** → `docs/superpowers/plans/YYYY-MM-DD-<topic>.md` — task bite-size, find/replace EKSAK, grep-verify, commit per task. **Verifikasi tiap anchor find/replace match file asli SEBELUM commit plan** (grep-battery). **Strategi one-file-per-task** (H2) ampuh: tiap anchor diverifikasi vs file SEKARANG, no anchor antar-task yang rapuh.
4. **`executing-plans`** (atau subagent-driven) — biasanya **sesi terpisah**. Eksekusi langsung per-task lebih aman daripada over-batch.
5. **Verifikasi pasca-eksekusi di SESI LAIN** — grep-battery + renumber-cross-ref audit + **workflow adversarial multi-dimensi (seam/pointer/rename/design-hole/staleness)**. Ini menangkap apa yang verify sesi-eksekusi lewatkan (sudah 6× kejadian).
6. **`finishing-a-development-branch`** → user putuskan; biasanya **FF-merge + push ke `origin/main`** lalu hapus branch lokal. Lalu **update memory** (`context-vault-project.md` + `MEMORY.md`).

**Bug-guard berulang (pasang preventif di tiap plan):**
- **Colon-space di YAML** — `description:`/contoh-skema value TAK boleh mengandung `": "` (pakai em-dash/kurung/`=`). Bug muncul 4×. Guard: `sed -n 's/^description: //p' FILE | grep ': '` harus kosong.
- **Renumber cross-ref** — kalau nyisip langkah, pakai **desimal (4.5)** atau **sub-bullet** biar tak me-renumber integer + tak mecah cross-ref "step N". Verifikasi tiap "step N"/"langkah N" masih nunjuk target benar. Bug `5520de5`.
- **Mis-aimed pointer** — tiap "§X"/"reference Y"/"(lihat …)" di skill DAN spec: cek beneran nunjuk section yang punya kontennya. (Tapi **edit-map before→after di spec yang nge-quote teks-lama itu BUKAN mis-aimed** — jangan salah-fix.)
- **Literal-scan sentinel** — token penanda yang di-scan skill jangan muncul di prose/instruksi.
- **Over-batch Edit+commit** — JANGAN ngumpulin banyak Edit+Bash+commit dalam 1 response; sekuensial per-file lebih aman.
- **Rename lintas-file** — kalau rename token (mis. `app:`→`unit:`): JANGAN blind `replace_all` token-pendek (bisa false-positive prosa); enumerasi SEMUA occurrence dulu (`grep`), bikin daftar find/replace eksplisit + grep-verify "no stale" akhir. **Dan rename PROSE/komentar/frontmatter-description juga**, bukan cuma field/logic (pelajaran H2).
- **Cek frontmatter description JUGA** (bukan cuma body) buat stale phrase.

**Caveat koherensi (CRITICAL):** beberapa proposed_fix audit nyandar artefak yang **BELUM ADA**. Per status sekarang: `packages[]`/`add-package` (H2) **SUDAH ADA**; tapi `control/integrations.md` (M5), `control/schema/` (M4), `data-model.md`/`roadmap.yaml` **MASIH FIKSI**. **Jangan source dari fiksi** — saat garap M5, jangan nyandar M4/H3; saat garap M4, jangan nyandar H3. Re-anchor ke primitif yang ada sampai artefaknya beneran dibikin.

---

## 6. Risiko terbuka & file pointer

**Risiko paling tua (belum pernah ditutup):** plugin ini **belum pernah dites live `/plugin install`** — semua skill (Fase 2+ & semua tambahan termasuk H2) cuma diverifikasi "AI pura-pura jadi skill" / dry-run, BUKAN plugin ter-install + skill auto-trigger di sesi baru. Cuma Fase-1/`init` yang pernah dites live (2026-05-24). Pertimbangkan tes live (butuh tangan user: install + reload + trigger) sebelum numpuk gap lagi — atau minimal sadar semua "verifikasi" sejauh ini dry-run.

**Pointer:**
- Desain induk: `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§4 prinsip, §7 model control/, §9 skills, §12 lifecycle, §17 komponen — sudah di-amend buat add-package/packages[]).
- Spec/plan Langkah 1: `docs/superpowers/{specs,plans}/2026-06-01-platform-invariants-security-gate*.md`
- Spec/plan H2: `docs/superpowers/{specs,plans}/2026-06-01-h2-shared-package*.md`
- Spec struktural (deferred items Langkah 3): `docs/superpowers/specs/2026-05-31-pipeline-hardening-structural-design.md`
- Skill: `plugin/skills/<nama>/SKILL.md` (+ `reference.md` di `wire`/`breakdown`/`build`/`discovery` — `add-package` TIDAK punya reference.md). Agent: `plugin/agents/{critic,security-critic}.md`. Template: `plugin/template/control/`.
- **Memory log lengkap (kalau ke-load):** `~/.claude/projects/-Users-stevanus-Developer-ai-boilerplate/memory/context-vault-project.md` (+ index `MEMORY.md`). Riwayat per-fase + semua pelajaran ada di situ.

**State git saat handoff:** `main` == `origin/main` @ `264b017` (Langkah 1 + H2 + M5 live), working tree clean, tak ada branch nyangkut. **(Diperbarui pasca-verify M5: 5 fix koherensi di-commit di atas 264b017.)**
