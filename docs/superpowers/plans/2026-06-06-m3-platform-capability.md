# M3 — Platform-Capability Nudge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (sesi terpisah, per handoff). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tambah **pola nudge ke-6** (peran cross-cutting / platform — queue / job-runner / background-processing / audit-log) ke `fanout` step 2 (sejajar 5 nudge existing: tantang anti-yes-man → tandai `NEW` → realizer `add-app`) + **1 baris Challenge Checklist** (step 3) + **1 sub-clause advisory** di `architect` step 4.5. Murni **advisory** — `fanout` MENGUSULKAN; `add-app` (dipanggil otomatis `feature`) yang mewujudkan. **Tak ada `platform:` block**, **tak ada skill baru** (skill tetap 21), **type enum `fe|be|fullstack` tak berubah** (worker = `type` `be` + responsibility cross-cutting), **rules tetap 5**. Tutup gap M3 (MEDIUM, fix-light). Spec: `docs/superpowers/specs/2026-06-06-m3-platform-capability-design.md`.

**Architecture:** Surface nudge = `fanout` (D1 — disk membuktikan `architect` tak punya seam usul-app; seam usul-app = `fanout` step 2 → realizer `add-app`). Gap dipersempit ke mekanisme runtime cross-cutting; RBAC/rate-limit/webhook/idempotency DIKELUARKAN (D2 — sudah punya slot `invariants.md`, klaim "tak punya tempat" = over-claim → duplikat). Worker = `type` `be`, enum tak diubah (D3). Advisory bukan gate (D4 — satu-satunya STOP tetap Security Gate `ship` existing, tak disentuh). `platform:` block + skill `/platform` = DEFER (D5). Diksi "cross-cutting / platform" BUKAN "lintas-app" (D6 — "lintas-app" sudah dipakai untuk dependency antar-app-existing di Challenge Checklist). Induk §7.1/§17/§8 TAK disentuh; §9 fanout-prose opsional disinkronkan (D7).

**Tech Stack:** Markdown skill/agent/spec files. Tak ada kode runtime. "Test" = grep-battery anchor verification (analog TDD untuk file instruksi) + coherence read.

**Branch:** branch kerja sekarang (sudah punya 7 spec committed + semua skill dari main). Eksekusi & post-exec verify = **sesi terpisah**. Commit spec+plan dulu (Task 0).

**Anchor verification (dijalankan saat penulisan plan — SEMUA `grep -Fc -e` = 1):**
- `fanout/SKILL.md` PACKAGE bullet (L20, Sisip-1 anchor) → **1**
- `fanout/SKILL.md` dependency lintas-app (L31, Sisip-2 anchor) → **1**
- `fanout/SKILL.md` output-template NEW line (L40, context no-edit) → **1**
- `architect/SKILL.md` full ELICIT bullet line (L40, Task-2 FIND) → **1**
- `architect/SKILL.md` M6 clause substring `**Compliance constraint (M6):** baca …` (must stay =1 after edit) → **1**
- `architect/SKILL.md` tail `degrade bila absen/sentinel. Lihat …compliance-risk.md.` (append-point) → **1**
- induk §9 fanout-prose Challenge (L195, di bawah heading `#### \`fanout\` (P1)` L193 — BUKAN §17) → **1**
- induk `**Skills (21):**` (skill-count guard, no-touch) → **1**

**Bug-guard pre-bake (berlaku semua task):**
- **byte-trap:** anchor & replace pakai em-dash `—` (U+2014), arrow `→` (U+2192), middot `·` (U+00B7), `↔` (U+2194) VERBATIM dari disk — JANGAN normalisasi/ketik-ulang. Audit char: fanout L20/L31 = 3×`→` + 1×`↔`; replace bullets (spec L90/L102/L119/L154) konsisten em-dash/arrow.
- **colon-space:** M3 **TIDAK menyentuh** frontmatter `description:` mana pun (fanout L3 & architect L3 unchanged). Satu-satunya `: ` di bullet baru = `(anti-yes-man): beneran` — **prose body** identik 4× pola existing di disk (`grep -Fc '(anti-yes-man): beneran'` = 4); BUKAN value YAML/output-template. Worker pakai `type` `be` (backtick), **bukan** `type: be`. Nol `: ` baru di konteks YAML/value/description.
- **no-renumber:** semua sisipan = bullet/baris baru di step 2 & 3 (bullet, bukan nomor) + sub-clause di akhir bullet ELICIT (4.5) + frasa di prose §9. **Tak ada** step/langkah ter-renumber; tiap "step N"/"langkah N" tetap nunjuk target benar.
- **M6 string utuh:** sisip 5b nempel SESUDAH kalimat M6 di architect 4.5 (tak menimpa). Anchor `**Compliance constraint (M6):**` + `compliance-risk.md` tetap =1 setelah edit.
- **diksi advisory:** bullet baru pakai "tantang/usulkan/mungkin/pertimbangkan" — NOL "blokir/wajib/STOP/gagal". Grep negatif di baris baru.
- **diksi cross-cutting ≠ lintas-app:** baris baru pakai "cross-cutting / platform"; istilah "lintas-app" L31 existing tak diutak-atik (tetap untuk dependency antar-app).
- **enum bersih:** worker `type` `be` (backtick); TIDAK menambah `worker` ke enum mana pun (init/add-app/induk §7.1). Bila eksekutor yakin butuh type baru → **scopeFlag**, jangan diam-diam balloon.
- **no `platform:` leak:** tak ada `platform:` block ke workspace.yaml shape; tak ada skill `/platform`/file baru. Skill tetap 21, rules tetap 5; `plugin.json`/`marketplace.json`/README **TIDAK** disentuh.
- **realizer benar:** nudge merujuk `add-app` sebagai penulis entri (bukan architect). 5b merujuk `fanout`→`add-app`, bukan "architect nulis app".
- **mis-aimed-pointer:** §9 fanout-prose di induk = heading `#### \`fanout\` (P1)` (L193), BUKAN §17 (verified). Tiap "§X"/"(lihat …)" di replace nunjuk section yang punya kontennya.
- **one-file-per-task:** satu task = satu file = satu commit. JANGAN over-batch.
- **scopeFlags bila menyimpang:** (a) nambah `worker` ke enum; (b) nambah `platform:` block; (c) gate keras; (d) `wire` mode headless-worker baru — keempatnya bukan-light → WAJIB FLAG. **CATATAN (d):** worker `type: be` murni-background TANPA route inbound → smoke gate `wire` (reference §E) tak bisa dijawab → 4d adalah outcome yang DIHARAPKAN, bukan edge-case (spec §3 "Tak menyentuh `wire`" + §5c). M3 sendiri tak menambah mode itu.
- Tiap commit diakhiri trailer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

### Task 0: Commit spec + plan

**Files:**
- Add: `docs/superpowers/specs/2026-06-06-m3-platform-capability-design.md` (sudah ada, hasil brainstorming + self-review)
- Add: `docs/superpowers/plans/2026-06-06-m3-platform-capability.md` (file ini)

- [ ] **Step 1: Commit**

```bash
git add docs/superpowers/specs/2026-06-06-m3-platform-capability-design.md docs/superpowers/plans/2026-06-06-m3-platform-capability.md
git commit -m "docs(m3): spec + plan platform-capability nudge (advisory; fanout pola ke-6 cross-cutting → usul unit worker; skills tetap 21, enum tak berubah)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 1: `fanout/SKILL.md` — step 2 bullet nudge ke-6 (cross-cutting → unit worker) [SURFACE UTAMA]

**Files:**
- Modify: `plugin/skills/fanout/SKILL.md` (step 2, sisip SESUDAH bullet PACKAGE baris 20, SEBELUM bullet VENDOR baris 21)
- Test: grep anchor + diksi-advisory guard

> **Posisi:** bullet baru disisip sebagai sibling SESUDAH bullet PACKAGE (L20), SEBELUM bullet VENDOR (L21). Anchor FIND = bullet PACKAGE verbatim (terverifikasi `grep -Fc` = 1). Bila eksekutor pindah posisi (mis. sesudah APP-BARU L19) → WAJIB re-`grep -Fc` anchor baru SEBELUM edit; JANGAN free-hand. **Byte-trap:** FIND memuat 1×`→` (U+2192) — copy verbatim. REPLACE bullet baru memuat `→` + em-dash `—` (U+2014) — jangan tukar.

- [ ] **Step 1: Edit** — sisip bullet nudge ke-6 SESUDAH bullet PACKAGE (no-renumber; bentuk identik 5 nudge existing: tantang anti-yes-man → tandai `NEW` → realizer `add-app`).

FIND (verbatim):
```
- **Kalau ADA kode-bareng yang dipakai >1 app** (mis. format uang, tipe domain bersama) → mungkin **SHARED PACKAGE**. Tantang (anti-yes-man): beneran shared >1 app, atau cukup 1 app saja? Lolos → tandai `PACKAGE NEW: <nama>` (langkah 4); diwujudkan `add-package` (dipanggil otomatis `feature`). **Kalau fitur menyentuh API package yang SUDAH ADA** → tandai `PACKAGE TOUCHED: <nama>` + tarik daftar consumer dari `packages[<nama>].consumers` (basis fan-IN; `plan` yang memutuskan BREAKING).
```
REPLACE WITH:
```
- **Kalau ADA kode-bareng yang dipakai >1 app** (mis. format uang, tipe domain bersama) → mungkin **SHARED PACKAGE**. Tantang (anti-yes-man): beneran shared >1 app, atau cukup 1 app saja? Lolos → tandai `PACKAGE NEW: <nama>` (langkah 4); diwujudkan `add-package` (dipanggil otomatis `feature`). **Kalau fitur menyentuh API package yang SUDAH ADA** → tandai `PACKAGE TOUCHED: <nama>` + tarik daftar consumer dari `packages[<nama>].consumers` (basis fan-IN; `plan` yang memutuskan BREAKING).
- **Kalau ADA peran cross-cutting / platform** (queue, job-runner, background-processing, audit-log) yang bukan milik satu app — kerja runtime lintas-app, bukan dependency antar-app existing — mungkin butuh **UNIT WORKER terpisah**. Tantang (anti-yes-man): beneran perlu unit worker sendiri, atau bisa ditampung app existing / scope-creep? Lolos → usulkan app worker bertanda `NEW` (langkah 4) dengan `type` `be` + responsibility cross-cutting (mis. "queue/job runner lintas-app"); diwujudkan `add-app` (dipanggil otomatis `feature`). `fanout` cuma **MENGUSULKAN** — yang nulis entri + bring-up = `add-app`. (RBAC/rate-limit/webhook/idempotency BUKAN ini — itu invarian fondasi, sudah punya slot di `invariants.md`; jangan diusulkan jadi worker.)
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/fanout/SKILL.md
grep -Fc -e '- **Kalau ADA peran cross-cutting / platform** (queue, job-runner, background-processing, audit-log) yang bukan milik satu app' "$f"  # expect 1 (bullet baru)
grep -Fc -e 'usulkan app worker bertanda `NEW` (langkah 4) dengan `type` `be` + responsibility cross-cutting' "$f"  # expect 1 (worker = type be, backtick — bukan enum baru)
grep -Fc -e 'RBAC/rate-limit/webhook/idempotency BUKAN ini — itu invarian fondasi, sudah punya slot di `invariants.md`' "$f"  # expect 1 (anti over-claim D2)
# anchor PACKAGE utuh (tak terhapus)
grep -Fc -e '- **Kalau ADA kode-bareng yang dipakai >1 app** (mis. format uang, tipe domain bersama) → mungkin **SHARED PACKAGE**.' "$f"  # expect 1
# diksi-advisory guard: bullet baru NOL blokir/wajib/STOP
grep -n 'cross-cutting / platform' "$f" | grep -iE 'blokir|wajib|STOP|gagal' && echo "BOCOR diksi keras!" || echo "advisory clean ✓"
# enum bersih: tak ada 'type: be' polos di bullet baru (harus 'type` `be')
grep -Fc -e 'dengan `type` `be`' "$f"  # expect 1 (backtick form)
```
Expected: 1 / 1 / 1 / 1 / advisory clean ✓ / 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/fanout/SKILL.md
git commit -m "feat(m3): fanout step2 pola nudge ke-6 — peran cross-cutting/platform → usul UNIT WORKER (type be, NEW; advisory, realizer add-app)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `fanout/SKILL.md` — step 3 Challenge Checklist +1 baris

**Files:**
- Modify: `plugin/skills/fanout/SKILL.md` (step 3, sisip SESUDAH baris "dependency/kontrak lintas-app" baris 31)
- Test: grep anchor

> Sisip SESUDAH baris dependency-lintas-app (L31) agar konsep cross-cutting berdampingan tapi terbedakan dari dependency-lintas-app (D6 — istilah "lintas-app" L31 tetap untuk dependency antar-app, baris baru pakai "cross-cutting/platform"). **Byte-trap:** anchor L31 memuat `↔` (U+2194) di "issuer↔validator" — copy verbatim; REPLACE baris baru memuat `→` (U+2192).

- [ ] **Step 1: Edit** — sisip baris Challenge cross-cutting SESUDAH baris dependency-lintas-app (no-renumber; bullet, bukan nomor).

FIND (verbatim):
```
- Ada dependency/kontrak lintas-app (mis. issuer↔validator)?
```
REPLACE WITH:
```
- Ada dependency/kontrak lintas-app (mis. issuer↔validator)?
- Ada peran cross-cutting/platform (queue/job/audit/background) yang bukan milik satu app → butuh unit worker terpisah? (beneran perlu, atau bisa ditampung app existing / scope-creep?)
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/fanout/SKILL.md
grep -Fc -e '- Ada peran cross-cutting/platform (queue/job/audit/background) yang bukan milik satu app → butuh unit worker terpisah? (beneran perlu, atau bisa ditampung app existing / scope-creep?)' "$f"  # expect 1 (baris baru)
# anchor dependency-lintas-app utuh + diksi lintas-app TAK terganggu
grep -Fc -e '- Ada dependency/kontrak lintas-app (mis. issuer↔validator)?' "$f"  # expect 1
# diksi-advisory guard: baris baru NOL blokir/wajib/STOP
grep -n 'cross-cutting/platform (queue/job/audit/background)' "$f" | grep -iE 'blokir|wajib|STOP|gagal' && echo "BOCOR diksi keras!" || echo "advisory clean ✓"
```
Expected: 1 / 1 / advisory clean ✓.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/fanout/SKILL.md
git commit -m "feat(m3): fanout step3 Challenge +1 baris peran cross-cutting/platform → unit worker (advisory)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `architect/SKILL.md` — step 4.5 sub-clause advisory cross-cutting (HOTSPOT bersama M6)

**Files:**
- Modify: `plugin/skills/architect/SKILL.md` (step 4.5 bullet ELICIT, baris 40)
- Test: grep anchor + M6-string-utuh guard

> **PERINGATAN KONTRAK:** bullet ELICIT (L40) sudah memuat klausa **M6** (`**Compliance constraint (M6):** baca …`, =1). Sisip M3 sebagai **sub-clause terpisah di AKHIR bullet ELICIT** (sesudah kalimat M6), BUKAN modifikasi kalimat M6. FIND = baris bullet ELICIT PENUH verbatim (terverifikasi =1) → REPLACE = baris yang sama + sub-clause M3 di belakang. **Byte-trap:** baris memuat em-dash `—` (U+2014) di beberapa tempat — copy verbatim. **Sifat OPSIONAL** (spec §5b): bila eksekutor ingin minimal-viable absolut, task ini boleh di-skip; pipeline tetap koheren (nudge utama di fanout, Task 1/2). Bila dipakai → advisory murni.

- [ ] **Step 1: Edit** — append sub-clause M3 SESUDAH kalimat M6, masih dalam bullet ELICIT yang sama (no-renumber; advisory, merujuk `fanout`→`add-app`).

FIND (verbatim):
```
- Kalau ada slot `<belum dikunci>`: **ELICIT** per slot keputusannya (level fondasi, bukan stack). User boleh jawab `N/A — alasan`. Sodorkan slot saran; terima invarian tambahan spesifik-produk. Tulis hasil ke `control/invariants.md` (ganti `<belum dikunci>`). **Compliance constraint (M6):** baca `control/business/risks.md` (bila ada) saat ELICIT slot **PII/PCI & Money & Currency** — cocokkan keputusan teknis dgn kewajiban regulasi yang diketahui (mis. risks.md sebut PCI → slot PII/PCI harus menutup penanganan kartu). Advisory; degrade bila absen/sentinel. Lihat `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`.
```
REPLACE WITH:
```
- Kalau ada slot `<belum dikunci>`: **ELICIT** per slot keputusannya (level fondasi, bukan stack). User boleh jawab `N/A — alasan`. Sodorkan slot saran; terima invarian tambahan spesifik-produk. Tulis hasil ke `control/invariants.md` (ganti `<belum dikunci>`). **Compliance constraint (M6):** baca `control/business/risks.md` (bila ada) saat ELICIT slot **PII/PCI & Money & Currency** — cocokkan keputusan teknis dgn kewajiban regulasi yang diketahui (mis. risks.md sebut PCI → slot PII/PCI harus menutup penanganan kartu). Advisory; degrade bila absen/sentinel. Lihat `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`. **Cross-cutting (M3, advisory):** bila kebutuhan bersifat runtime lintas-app (queue/job/audit/background) — bukan invarian fondasi — pertimbangkan apakah butuh **unit worker** terpisah; usul lewat `fanout`→`add-app`, **bukan** kunci slot invarian baru (Authz/Rate-limit sudah punya slot). Tak memblokir.
```

- [ ] **Step 2: Verify** (+ M6-string-utuh guard)

```bash
f=plugin/skills/architect/SKILL.md
grep -Fc -e '**Cross-cutting (M3, advisory):** bila kebutuhan bersifat runtime lintas-app (queue/job/audit/background) — bukan invarian fondasi — pertimbangkan apakah butuh **unit worker** terpisah' "$f"  # expect 1 (sub-clause M3)
grep -Fc -e 'usul lewat `fanout`→`add-app`, **bukan** kunci slot invarian baru (Authz/Rate-limit sudah punya slot). Tak memblokir.' "$f"  # expect 1 (realizer benar + advisory)
# M6-string-utuh guard: klausa M6 MASIH match=1 (M3 nempel sesudahnya, tak menimpa)
grep -Fc -e '**Compliance constraint (M6):** baca `control/business/risks.md`' "$f"  # expect 1
grep -Fc -e 'degrade bila absen/sentinel. Lihat `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`.' "$f"  # expect 1 (titik-temu M6→M3)
# diksi-advisory + realizer guard (plain-ERE; buang baris benign ber-'Tak memblokir' via grep -v lalu pindai sisa — JANGAN pakai lookahead PCRE 'blokir(?!...)' : grep -E menolaknya (exit 2) & malah false-pass tanpa pernah memindai). Sanity-check, bukan gate keras: bila 'cek konteks' muncul, baca baris yang kena & pastikan diksinya advisory.
grep -n 'Cross-cutting (M3, advisory)' "$f" | grep -v 'Tak memblokir' | grep -iE 'blokir|wajib|STOP|gagal' && echo "cek konteks" || echo "advisory clean ✓"
# colon-space guard: frontmatter description: TAK disentuh
sed -n 's/^description: //p' "$f" | grep ': ' && echo "BOCOR colon-space!" || echo "desc clean ✓"
```
Expected: 1 / 1 / 1 / 1 / advisory clean ✓ / desc clean ✓. (Task 3 OPSIONAL — bila di-skip, JANGAN jalankan Step 2 ini; cek-1 & cek-2 jadi 0, cek-3/cek-4 tetap 1 dari M6 yang tak tersentuh.)

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/architect/SKILL.md
git commit -m "feat(m3): architect 4.5 sub-clause advisory cross-cutting — runtime lintas-app → pertimbangkan unit worker (usul fanout→add-app; tak memblokir; M6 string utuh)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Induk spec — §9 fanout-prose sinkron nudge ke-6 (OPSIONAL)

**Files:**
- Modify: `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§9 fanout-prose, baris 195, di bawah heading `#### \`fanout\` (P1)` L193)
- Test: grep anchor + skill-count guard

> **Mis-aimed-pointer guard:** anchor L195 berada di blok `#### \`fanout\` (P1)` (heading L193) — ini §9 pipeline-prose, **BUKAN** §17 (verified). Sisip frasa "peran cross-cutting (queue/job/audit) → unit worker?" ke daftar Challenge yang dicontohkan, **bukan** renumber. **Sifat OPSIONAL** (spec §6/D7): induk shape (§7.1/§17/§8) TAK disentuh; hanya §9 yang mencerminkan perilaku `fanout`. Bila ingin minimal absolut, task ini boleh di-skip — perilaku-of-record ada di `fanout/SKILL.md` (Task 1/2). **Byte-trap:** anchor + replace memuat `→` (U+2192) di "→ unit worker?".

- [ ] **Step 1: Edit** — sisip frasa cross-cutting ke daftar Challenge §9 (no-renumber; sinkron perilaku SKILL).

FIND (verbatim):
```
Challenge: "ada app kelewat? dependency lintas-app? butuh vendor eksternal?".
```
REPLACE WITH:
```
Challenge: "ada app kelewat? dependency lintas-app? peran cross-cutting (queue/job/audit) → unit worker? butuh vendor eksternal?".
```

- [ ] **Step 2: Verify** (+ skill-count guard)

```bash
f=docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
grep -Fc -e 'Challenge: "ada app kelewat? dependency lintas-app? peran cross-cutting (queue/job/audit) → unit worker? butuh vendor eksternal?".' "$f"  # expect 1 (frasa baru)
# anchor lama TIDAK boleh tersisa (sudah terganti)
grep -Fc -e 'Challenge: "ada app kelewat? dependency lintas-app? butuh vendor eksternal?".' "$f"  # expect 0
# frasa baru berada di blok fanout §9, bukan §17
awk 'NR<=195 && /^#/{h=$0; n=NR} END{print n": "h}' "$f"  # expect 193: #### `fanout` (P1)
# skill-count guard: TETAP 21 (induk shape tak drift)
grep -Fc -e '**Skills (21):**' "$f"  # expect 1
```
Expected: 1 / 0 / `193: #### \`fanout\` (P1)` / 1.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
git commit -m "docs(spec): sync induk §9 fanout-prose — Challenge += peran cross-cutting (queue/job/audit) → unit worker (sinkron M3; §7.1/§17/§8 tak disentuh, skills tetap 21)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Verifikasi akhir (grep-battery V0–V8 + coherence) — sesi eksekusi

**Files:** (read-only; commit hanya bila ada fix)

- [ ] **Step 1: Grep-battery** (dari root repo)

```bash
echo "V0 fanout nudge ke-6 (bullet step2):"; grep -Fc -e '- **Kalau ADA peran cross-cutting / platform** (queue, job-runner, background-processing, audit-log) yang bukan milik satu app' plugin/skills/fanout/SKILL.md   # expect 1
echo "V1 fanout step3 Challenge cross-cutting:"; grep -Fc -e '- Ada peran cross-cutting/platform (queue/job/audit/background) yang bukan milik satu app → butuh unit worker terpisah?' plugin/skills/fanout/SKILL.md   # expect 1
echo "V2 fanout realizer = add-app (bukan architect) + MENGUSULKAN:"; grep -Fc -e 'yang nulis entri + bring-up = `add-app`. (RBAC/rate-limit/webhook/idempotency BUKAN ini' plugin/skills/fanout/SKILL.md   # expect 1
echo "V3 architect 4.5 sub-clause M3 + M6 string utuh:"; grep -Fc -e '**Cross-cutting (M3, advisory):**' plugin/skills/architect/SKILL.md; grep -Fc -e '**Compliance constraint (M6):** baca `control/business/risks.md`' plugin/skills/architect/SKILL.md   # expect 1 (atau 0 bila Task 3 di-skip) / 1 (M6 tak tersentuh, selalu 1)
echo "V4 induk §9 fanout-prose sinkron (frasa cross-cutting):"; grep -Fc -e 'peran cross-cutting (queue/job/audit) → unit worker?' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md   # expect 1 (atau 0 bila Task 4 di-skip)
echo "V5 enum TAK berubah (no 'worker' di enum; init/add-app/induk §7.1 tak tersentuh):"; git diff --name-only main..HEAD | grep -E 'plugin/skills/init/SKILL.md|plugin/skills/add-app/SKILL.md|plugin/skills/wire/SKILL.md' && echo "BOCOR enum-surface!" || echo "enum clean ✓"; grep -Fc -e 'type: <fe|be|fullstack>' plugin/skills/init/SKILL.md   # expect 1 (enum utuh)
echo "V6 no 'platform:' leak + skill-count 21 + plugin.json/marketplace/README TAK tersentuh:"; grep -rn 'platform:' plugin/template plugin/skills/init/SKILL.md && echo "cek konteks (jangan jadi block)" || echo "no platform block ✓"; grep -Fc -e '**Skills (21):**' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md; git diff --name-only main..HEAD | grep -E 'plugin.json|marketplace.json|README' && echo "BOCOR!" || echo "clean ✓"
echo "V7 diksi advisory (nudge baru NOL blokir/wajib/STOP):"; grep -n -iE 'cross-cutting|unit worker' plugin/skills/fanout/SKILL.md plugin/skills/architect/SKILL.md | grep -iE 'blokir|wajib keras|STOP|gagalkan' && echo "cek konteks (Tak memblokir = OK)" || echo "advisory clean ✓"
echo "V8 colon-space description bersih (fanout+architect tak disentuh):"; for f in plugin/skills/fanout/SKILL.md plugin/skills/architect/SKILL.md; do sed -n 's/^description: //p' "$f" | grep ': ' && echo "BOCOR $f"; done; echo "desc-scan done"
```
Expected: V0 1 · V1 1 · V2 1 · V3 1 (atau 0 bila Task 3 di-skip) / 1 · V4 1 (atau 0 bila Task 4 di-skip) · V5 enum clean ✓ + 1 · V6 no platform block ✓ + 1 + clean ✓ · V7 advisory clean ✓ · V8 desc-scan done (tak ada BOCOR).

- [ ] **Step 2: Coherence read** — baca diff `main..HEAD`, pastikan: nudge ke-6 (fanout step2) bentuk identik 5 nudge existing (tantang anti-yes-man → tandai `NEW` → realizer `add-app`); `fanout` MENGUSULKAN, `add-app` mewujudkan (tak ada klaim "fanout bikin worker"); diksi cross-cutting ≠ lintas-app (L31 utuh); worker = `type` `be` (backtick), enum `fe|be|fullstack` tak disentuh (init/add-app/wire bersih); RBAC/rate-limit/webhook/idempotency dikeluarkan (D2 — sudah punya slot invariants.md, tak diusulkan jadi worker); architect 4.5 sub-clause M3 advisory murni di SESUDAH kalimat M6 (M6 utuh); §9 fanout-prose sinkron (atau di-skip) tanpa drift §7.1/§17/§8; skills 21 + rules 5 + nol churn plugin.json/marketplace/README; satu-satunya STOP tetap Security Gate `ship` existing (tak disentuh). **Honesty-note (spec §7):** shipped-text jujur "fanout MENGUSULKAN; user/add-app putuskan" + worker routeless → `wire` smoke 4d scopeFlag = EXPECTED (bukan diklaim mulus). Catat temuan.

- [ ] **Step 3: Selesai (sesi ini)** — JANGAN merge/push. Lapor: plan tereksekusi, N commit, tree clean. **Post-exec adversarial verify = sesi LAIN** (fresh-eyes lensa: faithful-exec / seam fanout↔add-app / mis-aimed-pointer §9-vs-§17 / parent-doc-staleness / diksi-advisory-vs-gate / enum-no-balloon / `wire` headless-worker design-hole jujur), baru FF-merge + push + hapus branch + update memory.

---

## Self-Review (penulis plan)

**1. Spec coverage** (tiap requirement spec → task):
- §3 Tujuan-1 + §5a Sisip-1 (fanout step2 bullet nudge ke-6) → **Task 1**.
- §3 Tujuan-2 + §5a Sisip-2 (fanout step3 Challenge +1 baris) → **Task 2**.
- §3 Tujuan-3 + §5b (architect 4.5 sub-clause advisory, OPSIONAL) → **Task 3**.
- §3 Tujuan-4 (opsional) + §6 amendment OPSIONAL (induk §9 fanout-prose) → **Task 4**.
- §5a Catatan output-template step 4 ("TIDAK menambah baris template; tak ada edit di step 4") → **NO TASK** (eksplisit no-edit; worker reuse penanda `NEW` existing L40).
- §5c TAK-disentuh (init/add-app/wire/invariants.md/workspace.yaml-fiksi/plugin.json/marketplace/README) → **NO TASK** (D3/D5/D7); diverifikasi negatif di Task 5 V5/V6.
- §6 induk §7/§7.1/§8/§12/§17 = TAK disentuh (D7) → **NO TASK**; skill-count 21 guard di Task 4 V + Task 5 V6.
- §8 self-review (anchor/no-renumber/M6-utuh/advisory/cross-cutting≠lintas-app/enum/colon-space/no-platform-leak/realizer/induk-no-drift/scopeFlags/generik) → **header bug-guard + per-task Verify + Task 5 V0-V8**.
- §10 verifikasi V0-V9 (spec self-review) → **Task 5 + per-task grep + header**.
→ **Tak ada gap.** (Task 3 & Task 4 ditandai OPSIONAL persis seperti spec; inti M3 = Task 1+2 di fanout.)

**2. Placeholder scan:** tiap step punya isi nyata (find/replace verbatim Task 1-4; grep konkret Task 5). Tak ada TBD/TODO/"similar to". ✓

**3. Anchor consistency:** tiap FIND diambil verbatim dari disk & di-`grep -Fc -e`-verify =1 saat penulisan plan: fanout PACKAGE L20 (=1), fanout dependency-lintas-app L31 (=1), fanout output-template NEW L40 (=1, context no-edit), architect full ELICIT bullet L40 (=1) + M6 substring (=1) + tail append-point (=1), induk §9 fanout-prose L195 (=1, di bawah `#### \`fanout\` (P1)` L193 — bukan §17), induk `**Skills (21):**` (=1). Byte-trap audited: fanout L20/L31 = 3×`→`(U+2192) + 1×`↔`(U+2194); replace bullets konsisten em-dash `—`(U+2014)/arrow `→`. colon-space: satu-satunya `: ` di bullet baru = `(anti-yes-man): beneran` (prose body, 4× existing di disk); worker = `type` `be` backtick (bukan `type: be`); frontmatter description: TAK disentuh. ✓
