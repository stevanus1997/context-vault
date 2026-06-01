# HANDOFF — context-vault pipeline hardening (audit ecommerce-builder)

> ⛔ **SUPERSEDED (2026-06-01):** H2 di dokumen ini SUDAH selesai & LIVE di `main` @ `fa62982`. Buat sesi baru, baca **`docs/superpowers/handoff-2026-06-01-langkah-2-sisa-3.md`** (Langkah 2 sisa M5/M4/H3 + Langkah 3). Dokumen ini disimpan sebagai riwayat.

> **Buat sesi baru: BACA INI DULU.** Dokumen ini self-contained — kamu tak perlu konteks chat sesi sebelumnya. Sumber kebenaran tetap spec + plan di repo (di-link di bawah). Tanggal handoff: **2026-06-01**. Repo: `~/Developer/ai-boilerplate` (github.com/stevanus1997/context-vault), branch kerja: `main`.

---

## 0. TL;DR — apa yang harus dilakukan

1. **Langkah 1 = SELESAI & LIVE di `main`** (@ `54632e4`). Jangan ulang.
2. **Tugasmu: diskusikan + bangun Langkah 2** (mulai dari **H2 shared-package**), nanti **Langkah 3**.
3. **Cara kerja WAJIB** (lihat §5): `brainstorming → writing-plans → executing-plans → verifikasi pasca-eksekusi sesi-terpisah → FF-merge+push`. Jangan skip brainstorming. Plugin ini **GENERIC** (bukan khusus ecommerce — Shopify cuma skenario uji).
4. **Sebelum nulis spec apa pun:** baca §6 (caveat koherensi) — beberapa usulan fix nyandar artefak yang BELUM ADA; jangan source dari fiksi.

---

## 1. Problem & konteks

**Apa itu context-vault:** Claude Code plugin + template yang nyediain **lapisan AI + knowledge (BUKAN kode)** buat ngelola produk multi-app. Knowledge hidup di `control/` (`workspace.yaml`, `business/`, `conventions.md`, `invariants.md`, `features/`), tumbuh just-in-time tiap fitur. Lifecycle skill:

```
discovery → init → architect → wire → feature(intake→fanout→plan) → breakdown → build → ship
            (+ cabang add-app saat fitur butuh app baru; drop; extract; render-docs)
```
15 skill + 2 agent (`critic`, `security-critic`). Desain induk: `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`.

**Asal kerjaan ini:** user (solo dev) minta stress-test — "anggep gw solo dev mau bikin **ecommerce builder ala Shopify** (SaaS multi-tenant: merchant bikin toko sendiri, katalog/cart/checkout, **pembayaran Stripe Connect + payout + platform fee**, order/shipping/pajak, theme builder, custom domain per tenant, webhook, background job) **full-AI** pakai pipeline ini — flow mana yang bolong?"

**Audit adversarial** (26-agent: 8 finder lensa-beda baca file skill asli → cluster/dedup → skeptik per-gap baca-file → sintesis): **45 temuan mentah → 16 gap kanonik, 0 dibantah** (yang berubah cuma kalibrasi severity). **Vonis:** pipeline **sehat di sumbu "satu fitur ide→PR"**, **bolong di sumbu "produk utuh berbasis uang+PII"** — 3 klaster: (a) **hulu kosong** (no roadmap/invarian/shared-package/integrasi/data-model durable), (b) **nol gate keamanan**, (c) **lifecycle mati di "PR dibuka"**. Tak ada gap yang bikin crash — semuanya **degradasi senyap / utang yang numpuk pas skala Shopify**.

Gap dipetakan ke **Langkah** by impact: Langkah 1 (fatal+murah, **DONE**), Langkah 2 (akar merembet, **NEXT**), Langkah 3 (medium/low + deferred).

---

## 2. STATUS LANGKAH 1 — SELESAI, LIVE di `main` @ `54632e4`

Mengerjakan gap **H1** (invarian platform dikunci telat), **H4** (nol gate keamanan), **M2** (invarian tak ter-enforce). Tanpa skill baru.

- Spec: `docs/superpowers/specs/2026-06-01-platform-invariants-security-gate-design.md`
- Plan: `docs/superpowers/plans/2026-06-01-platform-invariants-security-gate.md`

**Yang sekarang LIVE:**
- **`control/invariants.md`** (artifact baru, template di `plugin/template/control/`) — rumah invarian platform; 6 slot saran (Tenancy, Money & Currency, Idempotency, Authz/RBAC, PII/PCI, Rate-limit), tiap slot "ISI" atau "N/A — alasan", sentinel kosong = `<belum dikunci>`. Generic: architect boleh nambah/N-A-kan.
- **`architect` langkah 4.5 "Kunci Invarian"** — gated, `critic` WAJIB, idempotent (skip kalau semua slot resolved). Level-produk, sekali kunci.
- **`wire` step 0** — nolak bring-up DB kalau `invariants.md` belum resolved (ada `<belum dikunci>`).
- **agent baru `plugin/agents/security-critic.md`** (read-only red-team diff: secret/PII/PCI/webhook-sig/authz-tenant/input).
- **`ship` langkah 4.5 "Security & Compliance Gate"** — berskala ke tag `feature.yaml sensitivity` (kosong→quick-scan; `payments`/`pii`→security-critic penuh, STOP-on-fail).
- **tag `sensitivity`** diusulkan `intake` dari business.md (heuristik + cross-check invariants.md), disimpan `feature.yaml sensitivity:[]`.
- **M2:** 1 baris challenge "melanggar invarian terkunci?" di `plan`/`breakdown`/`build`.

**Pelajaran dari verifikasi pasca-eksekusi Langkah 1** (penting buat Langkah 2 — sesi eksekusi sendiri MELEWATKAN ini, ketangkep di baca-adversarial sesi-lain):
- **Jebakan literal-scan sentinel (kelas BUG BARU):** kalau skill nge-scan token penanda (mis. `<belum dikunci>`), pastikan token itu **TAK muncul di prose/instruksi** file yang di-scan, cuma di slot yang dimaksud — kalau nggak, cek "tak-ada-token" gagal-positif selamanya. (Bug ini lolos verify sesi-eksekusi, di-fix `54632e4`.)
- **Verifikasi janji-amandemen spec turunan:** spec Langkah-1 §10 janji amandemen parent-spec §9-intake & §12, tapi plan-nya cuma garap sebagian → 2 section ketinggalan. **Cek tiap "§X bakal diamandemen" di spec beneran masuk plan.**

---

## 3. LANGKAH 2 — NEXT (diskusikan + spec; mulai dari H2)

4 gap. **REKOMENDASI: spec TERPISAH per gap** (ini 4 subsistem agak independen — jangan dijejal 1 spec). **Urutan (dari audit):** H2 → M5 → M4 → H3 (M4 mengaktifkan H3). Mulai brainstorming dari **H2**.

### H2 — Shared-package buta end-to-end (severity: HIGH) ⭐ MULAI DARI SINI
**Gap:** seluruh pipeline buta terhadap shared package. `workspace.yaml` cuma `apps[]`; `add-app` eksplisit nolak package; `breakdown` mewajibkan `task.app == apps[].name` → task di package dipaksa salah; **tak ada fan-IN** (saat API package berubah, N consumer yang udah di-ship tak pernah dienumerasi/diuji-ulang — pipeline cuma fan-OUT).
**Trigger Shopify:** hari-1 butuh `@store/money` + `@store/tenancy` dipakai 3 app; signature `formatMoney()` berubah → consumer nggak ke-update.
**Usulan fix (tiru pola `add-app` yang terbukti):** array `packages:` di workspace.yaml (`name,path,type=package,responsibility,consumers[],mandatory_for` — TANPA db/route/smoke) + skill **`add-package`** (sibling add-app, gate = **typecheck hijau**, bukan smoke/DB) + `fanout` cocokin ke `packages[].consumers` + `plan` tulis `plans/<pkg>.md` (kontrak exports/signature) + perluas `task.app`→`task.unit` (app ATAU package) + **aturan fan-IN**: API package berubah → 1 update-task per consumer + task `integration` retest. **Bisa distage:** `packages[]`+add-package dulu, fan-IN kedua. **Catatan:** M2 punya klausa "membypass mandatory package" yang SENGAJA ditunda dari Langkah 1 — pasang di sini.

### M5 — Integrasi vendor tak punya rumah durable (severity: MEDIUM)
**Gap:** vendor eksternal (Stripe/email/carrier/tax) tak punya entitas di `control/`; kontrak vendor di-derive ULANG tiap fitur di `plans/_shared.md`; `fanout` tak punya kolom vendor; hasil langkah manual (secret/webhook/mode test-live) tak mendarat; webhook **inbound** + mode test/live tak dimodelkan.
**Trigger:** Stripe Connect nyentuh 5 fitur × 3 app; idempotency/webhook/signature di-derive ulang; risiko launch pakai `sk_test_`.
**Usulan fix:** `control/integrations.md` (SHAPE-only: vendor, endpoint webhook, idempotency-key, mode test/live, secret shape, retry) + `plan` baca/promote kontrak vendor (O(1)/vendor) + varian task "inbound eksternal" (verifikasi signature/idempotent/replay) + `wire` scaffold webhook-receiver stub.

### M4 — Tak ada model-data durable (severity: MEDIUM) — mengaktifkan H3
**Gap:** skema cuma hidup sebagai baris inline di `plans/<app>.md` per-fitur, direkonstruksi dari kode tiap sesi.
**Trigger:** fitur #20 perlu bentuk Order/Product/Tenant dari fitur #1/#3/#7; AI rekonstruksi ~30 table dari kode mentah.
**Usulan fix:** `control/schema/<app>.md` sebagai **PROJEKSI TER-GENERATE dari migrations** (di gate migrate / render-docs) — **BUKAN doc tangan** (hormati prinsip induk §4 "satu sumber kebenaran, banyak proyeksi"). `plan` baca sebagai input step-1. Ini memberi **basis consumer** yang dibutuhkan H3.

### H3 — Tak ada migration-governance lintas-fitur (severity: HIGH)
**Gap:** tak ada gate dampak saat fitur baru **ALTER table** milik fitur lama (referential integrity/backfill) maupun governance urutan migrasi/zero-downtime lintas-app/lintas-repo. `plan` scoped ke 1 app; `migrate`-gate `build` cuma "apply atau tidak".
**Trigger:** fitur #20 ubah `Order.status`/pecah `Product.price`→`ProductVariant`; multi-repo kolom NOT NULL dibaca worker+dashboard tanpa expand-contract → di sistem LIVE = lock = downtime.
**Usulan fix:** section "Dampak skema lintas-fitur" di `plan` + `migrate.kind: additive|destructive|backfill` + `migrate.affects:[table]` di `breakdown` + `migrate`-GATE `build` tampilkan consumer + lock-risk + butuh-backfill + `ship` section "urutan deploy & migrasi" + konvensi zero-downtime ke `conventions.md`. **Re-anchor:** basis consumer dari M4 (jangan nyandar `data-model.md` yang nggak ada).

---

## 4. LANGKAH 3 — LATER (diskusikan setelah Langkah 2)

Medium/low + sebagian sengaja-deferred. Diskusikan prioritasnya saat Langkah 2 kelar.

- **M1 (med) — Roadmap/epic decomposition.** Entrypoint langsung lompat ke satu `/feature`; tak ada yang ubah visi → backlog terurut sadar-dependency. Fix-light: field `epic`+`depends_on[]` di feature.yaml + warn-gate (bukan hard-block) + sizing-check di intake. Skill `roadmap` penuh defer di belakang `brainstorming`.
- **M3 (med) — Platform-capability slot.** workspace.yaml tak punya tempat untuk queue/job-runner/RBAC/audit/rate-limit lintas-app. Fix: nudge fanout "peran ini cross-cutting?" + rekomendasi app `worker` di architect; `platform:` block + skill = defer.
- **M6 (med) — Risiko compliance discovery kebuang.** `discovery` riset PCI/pajak/KYC/GDPR tapi seed konservatif buang analisis risiko; tak ada skill hilir baca discovery.html. Fix: `control/business/risks.md` yang discovery WAJIB seed (carve-out: risiko compliance boleh durable, risiko pasar tetap di HTML) + architect/intake baca sbg constraint. **(Murah — kandidat quick-win.)**
- **M7 (med) — Graduated autonomy.** Gate flat → solo dev jadi bottleneck approval (~17-19 stop/fitur). Fix: `feature.yaml risk:low|normal|high` (auto-tag-high HARD floor) + build `--unattended` per-segmen. **JANGAN ambil** batch/sticky-approve yang ngikis review per-app (itu value-prop buat produk bayar) — cukup unattended-segment + tiering.
- **M8 (low) — Observability feedback loop.** Produk live hasilkan incident tapi tak ada jalan balik ke intake. Fix: `control/feedback/` + intake baca sbg input (soft).
- **L1 (low) — Capability blueprint.** 1 prompt opsional di init "produk besar → declare semua app target sekarang".
- **L2 (low) — Iterasi-v2 / deprecate.** Status cuma draft/active/shipped/dropped; tak ada v2/deprecation fitur live. Promosikan rencana S4.1 (immutable old-folder + `<nama>-v2` + status `deprecated`).
- **L3 (low) — render-docs "shipped"≠"live".** Wording badge nyesatin. Fix interim: label "siap-kirim/merged" bukan "live".
- **Sengaja-deferred (spec struktural `2026-05-31-pipeline-hardening-structural-design.md` §S4.1/§10):** deploy/release/env-model penuh, post-ship lifecycle, provenance. Buat Shopify ini mode dominan tapi berat — ambil hanya **jembatan minimal** dulu (mis. `ship` "Release notes & deploy checklist" yang agregasi semua `manual:`/`actions(env+migrate)` jadi runbook).

---

## 5. Cara kerja project (WAJIB diikuti)

**Workflow per perubahan** (pola yang konsisten dari semua skill sebelumnya — wire/add-app/pipeline-hardening/Langkah-1):
1. **`brainstorming`** (skill superpowers) — JANGAN skip, walau kelihatan simpel. Tanya 1-1 (AskUserQuestion), kunci keputusan desain, sajikan design, approve.
2. **Tulis spec** → `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`, self-review, commit, user review.
3. **`writing-plans`** → `docs/superpowers/plans/YYYY-MM-DD-<topic>.md` — task bite-size, find/replace EKSAK, grep-verify, commit per task. **Verifikasi tiap anchor find/replace match file asli SEBELUM commit plan.**
4. **`executing-plans`** (atau subagent-driven) — biasanya **sesi terpisah**. Eksekusi langsung per-task lebih aman daripada over-batch (lihat pelajaran).
5. **Verifikasi pasca-eksekusi di SESI LAIN** — grep-battery + renumber-cross-ref audit + **1 agen adversarial fresh**. Ini menangkap apa yang verify sesi-eksekusi lewatkan.
6. **`finishing-a-development-branch`** → user putuskan; biasanya **FF-merge + push ke `origin/main`** lalu hapus branch lokal.

**Bug-guard berulang (pasang preventif di tiap plan):**
- **Colon-space di YAML** — `description:`/contoh-skema value TAK boleh mengandung `": "` (pakai em-dash/kurung). Bug ini muncul 4× (breakdown, wire, dst). Guard: `sed -n 's/^description: //p' FILE | grep ': '` harus kosong.
- **Renumber cross-ref** — kalau nyisip langkah, pakai **desimal (mis. 4.5)** biar tak me-renumber integer + tak mecah cross-ref internal "lanjut Step N". Verifikasi tiap rujukan "step N"/"langkah N" masih nunjuk target benar (bukan cuma heading unik). Bug `5520de5`.
- **Mis-aimed pointer** — tiap "§X"/"reference Y"/"(lihat ...)" di skill DAN spec: cek beneran nunjuk section yang punya kontennya. Lolos verify-eksekusi 4×; ketangkep di baca-adversarial sesi-lain.
- **Literal-scan sentinel** — token penanda yang di-scan skill jangan muncul di prose/instruksi (lihat §2 pelajaran).
- **Over-batch Edit+commit** — JANGAN ngumpulin banyak Edit+Bash+commit dalam 1 response; Edit butuh Read dulu & anchor bisa mismatch diam-diam sementara commit jalan → commit isinya nggak lengkap. Sekuensial per-file lebih aman.
- **Cek frontmatter description JUGA** (bukan cuma body) buat stale phrase.

**Caveat koherensi (CRITICAL):** beberapa proposed_fix audit nyandar artefak yang **BELUM ADA** — `roadmap.yaml` (L1/M1), `data-model.md` (H3), `packages[]`/`add-package` (H2 sebelum dibikin). **Jangan source dari fiksi** — re-anchor ke primitif yang ada (`apps[]`/`responsibility`, scan baris "Model/Schema" di `plans/`) sampai artefaknya beneran dibikin.

---

## 6. Risiko terbuka & file pointer

**Risiko paling tua (belum pernah ditutup):** plugin ini **belum pernah dites live `/plugin install`** (Fase 2+ & semua skill tambahan cuma diverifikasi "AI pura-pura jadi skill", BUKAN plugin ter-install + skill auto-trigger). Pertimbangkan tes live (butuh tangan user: install + reload + trigger di sesi baru) sebelum numpuk Langkah 2 — atau minimal sadar semua "verifikasi" sejauh ini dry-run.

**Pointer:**
- Desain induk: `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`
- Spec/plan Langkah 1: `docs/superpowers/{specs,plans}/2026-06-01-platform-invariants-security-gate*.md`
- Spec struktural (deferred items): `docs/superpowers/specs/2026-05-31-pipeline-hardening-structural-design.md`
- Skill: `plugin/skills/<nama>/SKILL.md` (+ `reference.md` di wire/breakdown/build/discovery). Agent: `plugin/agents/{critic,security-critic}.md`. Template: `plugin/template/control/`.
- Memory log lengkap (kalau ke-load): `~/.claude/projects/-Users-stevanus-Developer-ai-boilerplate/memory/context-vault-project.md`

**State git saat handoff:** `main` == `origin/main` @ `54632e4` (Langkah 1 live), working tree clean, tak ada branch nyangkut.
