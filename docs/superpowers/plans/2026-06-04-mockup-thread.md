# mockup-thread (Design Fidelity Spec A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Thread the user-provided UI mockup (any format, opaque bytes) through `plan → breakdown → build` so the implementer reproduces layout + animation instead of reconstructing UI from prose — killing the manual `/fix` round per UI feature.

**Architecture:** Five additive edits across 5 skill-doc files. CAPTURE in `plan` (save mockup verbatim to `control/features/<f>/mockups/` + `Mockup:` pointer); THREAD in `breakdown` (optional `mockup:` task key + coverage check); DISPATCH+EYEBALL in `build` (implementer receives mockup content/pointer + tech-agnostic "reproduce-result, don't-transplant" instruction; one eyeball item in the existing gate). Everything optional → non-UI features degrade to current behavior at zero cost.

**Tech Stack:** Markdown skill docs (`SKILL.md` + `reference.md`) under `plugin/skills/`. No code, no new files, no new skills/agents. "Tests" = `grep` anchor verification (verbatim before/after) + coherence checks — the project's established pattern for skill-doc edits. Branch: `mockup-thread` (already checked out).

**Spec:** `docs/superpowers/specs/2026-06-04-mockup-thread-design-fidelity-design.md` (§10 edit-map is the locked scope).

---

## File Structure

| File | Responsibility in this change | Edits |
|---|---|---|
| `plugin/skills/plan/SKILL.md` | CAPTURE — read `mockups/`, save mockup on handoff, `Mockup:` slot in `plans/<app>.md` | 4 |
| `plugin/skills/breakdown/reference.md` | THREAD schema — `mockup:` task key (§A) + threading rule (§D) | 2 |
| `plugin/skills/breakdown/SKILL.md` | THREAD coverage — UI coverage check (step 4) | 1 |
| `plugin/skills/build/reference.md` | DISPATCH — mockup in implementer prompt (§B) + model choice (§C) | 2 |
| `plugin/skills/build/SKILL.md` | DISPATCH + EYEBALL — prompt assembly (step 3) + gate item (step 6) | 2 |

**Bug-guards (pre-baked, from repeated execution lessons):** all edits are **additive** (no heading/step/list renumber); `mockup:` added as a sub-key / new bullet; zero new frontmatter/skill/agent (→ zero skill-count staleness, zero colon-space risk, zero `plugin.json`/`marketplace.json`/`README`/parent-spec updates); grep verification uses **single-quoted** patterns for backtick-containing strings; each cross-pointer (`reference §B/§C`) is verified to target the section holding the content.

**Execution note:** run all `git`/`grep` from repo root `/Users/stevanus/Developer/ai-boilerplate`. Confirm branch first: `git branch --show-current` → expect `mockup-thread`.

---

### Task 1: `plan/SKILL.md` — CAPTURE

**Files:**
- Modify: `plugin/skills/plan/SKILL.md` (step 1 read, step 3 clause, step 4 template, Catatan)

- [ ] **Step 1: Verify anchors present**

Run:
```bash
grep -n 'itu jatah `fanout`\*\*) + `control/integrations.md`' plugin/skills/plan/SKILL.md
grep -n '^- Susun plan: file yang disentuh' plugin/skills/plan/SKILL.md
grep -n '^Lokasi       : <path konkret di app>' plugin/skills/plan/SKILL.md
grep -n '^- `plan` tetap FLAT\.' plugin/skills/plan/SKILL.md
```
Expected: each returns exactly one line (lines ~13, ~39, ~49, ~57).

- [ ] **Step 2a: Edit — step 1 read list (append `mockups/`)**

Replace:
```
itu jatah `fanout`**) + `control/integrations.md` (kontrak vendor eksternal — read-only).
```
With:
```
itu jatah `fanout`**) + `control/integrations.md` (kontrak vendor eksternal — read-only) + `control/features/<fitur>/mockups/` (mockup UI yang diserahkan pengguna, **bila ada** — cek keberadaan saja; isi TIDAK di-parse di sini, diserahkan ke `build`).
```

- [ ] **Step 2b: Edit — step 3 capture clause (new bullet after "Susun plan")**

Replace:
```
- Susun plan: file yang disentuh, endpoint/komponen, model data, test. **Bila app mengonsumsi package** → catat dependency-nya (package apa, dipakai untuk apa) di plan app.
```
With:
```
- Susun plan: file yang disentuh, endpoint/komponen, model data, test. **Bila app mengonsumsi package** → catat dependency-nya (package apa, dipakai untuk apa) di plan app.
- **Mockup UI (bila app punya permukaan UI).** Bila pengguna menyerahkan mockup (HTML/CSS/gambar/URL Figma) untuk app ini → simpan **verbatim** ke `control/features/<fitur>/mockups/` (format apa pun; **JANGAN** inline ke plan, **JANGAN** diprosa-kan jadi deskripsi), catat path-nya untuk slot `Mockup:` (langkah 4). Bila `/plan` dijalankan **standalone** & app punya UI tapi belum ada mockup tersimpan → **minta** mockup dulu (jangan jalan diam-diam); pengguna sengaja tak punya → lanjut tanpa `Mockup:` (degrade ke perilaku sekarang).
```

- [ ] **Step 2c: Edit — step 4 template slot (insert `Mockup:` between `Lokasi` and `Test`)**

Replace:
```
Lokasi       : <path konkret di app>
Test         : <...>
```
With:
```
Lokasi       : <path konkret di app>
Mockup       : <path… ke control/features/<fitur>/mockups/ ATAU kosong>
Test         : <...>
```

- [ ] **Step 2d: Edit — Catatan (mockup = pointer, bukan prosa)**

Replace:
```
- `plan` tetap FLAT. Dekomposisi jadi task kecil (siap-eksekusi) = jatah skill `breakdown`, bukan di sini.
```
With:
```
- `plan` tetap FLAT. Dekomposisi jadi task kecil (siap-eksekusi) = jatah skill `breakdown`, bukan di sini. Slot `Mockup:` adalah **pointer** ke file di `mockups/`, **bukan** deskripsi visual — `plan` tak pernah memprosa-kan isi mockup (itu byte opaque untuk `build`).
```

- [ ] **Step 3: Verify result**

Run:
```bash
grep -n 'mockups/' plugin/skills/plan/SKILL.md          # expect ≥3 hits (read, capture clause, template, catatan)
grep -n '^Mockup       :' plugin/skills/plan/SKILL.md    # expect 1 (template slot)
grep -c 'JANGAN diprosa-kan' plugin/skills/plan/SKILL.md # expect 1
grep -n '^API/Komponen : <...>' plugin/skills/plan/SKILL.md  # preserved (template intact)
```
Expected: `Mockup       :` appears once in the template; capture clause + catatan present; existing template lines intact.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/plan/SKILL.md
git commit -m "feat(plan): CAPTURE mockup UI -> control/features/<f>/mockups/ + slot Mockup: (mockup-thread)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `breakdown/reference.md` — THREAD schema

**Files:**
- Modify: `plugin/skills/breakdown/reference.md` (§A `tasks.yaml` schema key + §D threading rule)

- [ ] **Step 1: Verify anchors present**

Run:
```bash
grep -n '^        manual:                    # OPSIONAL' plugin/skills/breakdown/reference.md
grep -n '^        test:                      # WHAT di-assert' plugin/skills/breakdown/reference.md
grep -n '^5\. \*\*Task inbound-eksternal (webhook vendor)' plugin/skills/breakdown/reference.md
```
Expected: each one line (schema `manual:`/`test:` in §A; §D item 5 is the last numbered item).

- [ ] **Step 2a: Edit — §A schema, add `mockup:` key (between `manual:` block and `test:`)**

Replace:
```
        manual:                    # OPSIONAL — langkah yang AI NGGAK BISA (butuh manusia)
          - <mis. "bikin OAuth app di Google Console, dapetin client id + secret">
        test:                      # WHAT di-assert (kasus), BUKAN kode test
```
With:
```
        manual:                    # OPSIONAL — langkah yang AI NGGAK BISA (butuh manusia)
          - <mis. "bikin OAuth app di Google Console, dapetin client id + secret">
        mockup: <path>             # OPSIONAL — pointer file mockup UI (dari plans/<app>.md "Mockup:");
                                   #   build mem-paste/melampirkan isinya VERBATIM ke prompt implementer
        test:                      # WHAT di-assert (kasus), BUKAN kode test
```

- [ ] **Step 2b: Edit — §D, append threading rule as item 6**

Replace:
```
5. **Task inbound-eksternal (webhook vendor).** Saat `plans/<Receiver app>.md` memuat baris "kebutuhan receiver" (dari `plan` §2c — vendor inbound/both di `integrations.md`), terbitkan task biasa `unit: <Receiver app>` (app NYATA — BUKAN pseudo-unit `integration`): `approach` = "terima webhook `<vendor>`: verifikasi signature per `integrations.md`, idempotent (dedup key), tahan replay"; `actions` boleh `env: [<VENDOR>_WEBHOOK_SECRET]` (NAMA var; `build` tulis ke `.env`, nilai GATE/manual); `test` (kasus keamanan baku) = "signature salah → tolak 401/403", "id/event duplikat → respons sama, tak proses 2× (idempotent/replay)". Vendor **outbound** = task biasa pada app pemanggil (panggil API vendor + idempotency-key + retry sesuai `integrations.md`) — tak butuh varian khusus.
```
With:
```
5. **Task inbound-eksternal (webhook vendor).** Saat `plans/<Receiver app>.md` memuat baris "kebutuhan receiver" (dari `plan` §2c — vendor inbound/both di `integrations.md`), terbitkan task biasa `unit: <Receiver app>` (app NYATA — BUKAN pseudo-unit `integration`): `approach` = "terima webhook `<vendor>`: verifikasi signature per `integrations.md`, idempotent (dedup key), tahan replay"; `actions` boleh `env: [<VENDOR>_WEBHOOK_SECRET]` (NAMA var; `build` tulis ke `.env`, nilai GATE/manual); `test` (kasus keamanan baku) = "signature salah → tolak 401/403", "id/event duplikat → respons sama, tak proses 2× (idempotent/replay)". Vendor **outbound** = task biasa pada app pemanggil (panggil API vendor + idempotency-key + retry sesuai `integrations.md`) — tak butuh varian khusus.
6. **Task UI ber-mockup (design fidelity).** Task yang `plans/<app>.md`-nya memuat baris `Mockup:` membawa key `mockup: <path>` (pointer ke file di `control/features/<fitur>/mockups/`). **Banyak task boleh berbagi satu path** (satu file mockup berisi banyak layar) — **layar mana** ditentukan dari `desc` task; tak ada mekanisme region/anchor. `mockup:` = metadata seperti `kind:`/`actions:` → **dipertahankan saat re-breakdown** bila plan tak berubah (SKILL.md §7). `build` yang mem-paste/melampirkan isinya ke implementer (`build/reference.md` §B). DILARANG pada `unit: <package>` (package tak punya UI).
```

- [ ] **Step 3: Verify result**

Run:
```bash
grep -n 'mockup: <path>' plugin/skills/breakdown/reference.md          # expect 1 (§A schema)
grep -n '^6\. \*\*Task UI ber-mockup' plugin/skills/breakdown/reference.md  # expect 1 (§D item 6)
grep -c '^5\. \*\*Task inbound-eksternal' plugin/skills/breakdown/reference.md  # expect 1 (item 5 preserved)
grep -n '^        test:                      # WHAT di-assert' plugin/skills/breakdown/reference.md  # preserved
```
Expected: `mockup:` key present in §A, item 6 appended in §D, items 1–5 untouched.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/breakdown/reference.md
git commit -m "feat(breakdown): THREAD mockup: task key (schema A) + threading rule (D) (mockup-thread)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `breakdown/SKILL.md` — THREAD coverage

**Files:**
- Modify: `plugin/skills/breakdown/SKILL.md` (step 4 coverage check)

- [ ] **Step 1: Verify anchor present**

Run:
```bash
grep -n '^- \*\*Coverage:\*\* tiap keputusan' plugin/skills/breakdown/SKILL.md
```
Expected: one line (~24, the main Coverage bullet in step 4).

- [ ] **Step 2: Edit — add UI coverage sub-bullet after the Coverage bullet**

Replace:
```
- **Coverage:** tiap keputusan `_shared.md` ("env yang dibagi", mekanisme) & tiap baris Model/Schema di `plans/<app>.md` HARUS ke-map ke sebuah task/`action`/`manual` — jangan ada yang menguap. Tampilkan peta plan→task di gate.
```
With:
```
- **Coverage:** tiap keputusan `_shared.md` ("env yang dibagi", mekanisme) & tiap baris Model/Schema di `plans/<app>.md` HARUS ke-map ke sebuah task/`action`/`manual` — jangan ada yang menguap. Tampilkan peta plan→task di gate.
- **UI coverage (mockup→task):** tiap file mockup yang dirujuk `plans/<app>.md` (baris `Mockup:`) WAJIB ke-map ke ≥1 task ber-`mockup:`. Tampilkan **peta mockup→task** di gate (di samping peta plan→task) — biar tak ada layar yang kelupaan jadi task.
```

- [ ] **Step 3: Verify result**

Run:
```bash
grep -n 'UI coverage (mockup→task)' plugin/skills/breakdown/SKILL.md   # expect 1
grep -c '^- \*\*Coverage:\*\* tiap keputusan' plugin/skills/breakdown/SKILL.md  # expect 1 (original preserved)
grep -n '^- \*\*Inbound-eksternal coverage:' plugin/skills/breakdown/SKILL.md   # preserved
```
Expected: new UI coverage bullet present; existing coverage bullets intact.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/breakdown/SKILL.md
git commit -m "feat(breakdown): UI coverage check (tiap mockup -> >=1 task) (mockup-thread)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: `build/reference.md` — DISPATCH (prompt + model)

**Files:**
- Modify: `plugin/skills/build/reference.md` (§B implementer prompt bullet + §C model choice)

- [ ] **Step 1: Verify anchors present**

Run:
```bash
grep -n '^- \*\*Pointer pola:\*\* tunjuk 1-2 file existing' plugin/skills/build/reference.md
grep -n '^- Butuh judgment desain → model paling kuat\.' plugin/skills/build/reference.md
```
Expected: each one line (§B Pointer-pola bullet ~24; §C model bullet ~50).

- [ ] **Step 2a: Edit — §B, add Mockup bullet after "Pointer pola"**

Replace:
```
- **Pointer pola:** tunjuk 1-2 file existing sebagai contoh gaya (mis. route sejenis).
```
With:
```
- **Pointer pola:** tunjuk 1-2 file existing sebagai contoh gaya (mis. route sejenis).
- **Mockup (bila task ber-`mockup:`):** baca file di path → **teks** (HTML/CSS) di-**paste VERBATIM** ke prompt; **gambar** (PNG/JPG) → sertakan path & minta subagent **membuka/melihat**-nya; **URL Figma** → fetch via Figma MCP bila tersedia, kalau tidak → perlakukan sebagai screenshot/gambar. Instruksi (**tech-agnostic**): *"Reproduksi HASIL VISUAL — layout, spacing, hierarki, dan animasi/transisi — memakai stack app (`workspace.yaml`) + komponen pada file 'Pointer pola'. JANGAN transplant markup mentah mockup; terjemahkan ke idiom komponen project. BAWA transisi/animasi yang ada di mockup — jangan dibuang sebagai dekoratif."* Mockup = byte opaque user; `build` tak pernah mengasumsi framework-nya.
```

- [ ] **Step 2b: Edit — §C, annotate the judgment-desain bullet for `mockup:` tasks**

Replace:
```
- Butuh judgment desain → model paling kuat.
```
With:
```
- Butuh judgment desain → model paling kuat. **Task ber-`mockup:` masuk kategori ini** — menerjemahkan mockup (yang teknologinya bisa ≠ stack project) ke komponen existing tanpa transplant markup butuh judgment desain.
```

- [ ] **Step 3: Verify result**

Run:
```bash
grep -n 'Mockup (bila task ber-`mockup:`)' plugin/skills/build/reference.md   # expect 1 (§B)
grep -n 'JANGAN transplant markup' plugin/skills/build/reference.md            # expect 1
grep -n 'BAWA transisi/animasi' plugin/skills/build/reference.md               # expect 1
grep -n 'Task ber-`mockup:` masuk kategori ini' plugin/skills/build/reference.md  # expect 1 (§C)
grep -c '^- \*\*Pointer pola:\*\* tunjuk 1-2 file existing' plugin/skills/build/reference.md  # expect 1 (preserved)
```
Expected: §B Mockup bullet with "don't transplant" + "carry animation"; §C annotation; Pointer-pola preserved.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/build/reference.md
git commit -m "feat(build): DISPATCH mockup ke implementer (paste/lihat/figma) + reproduksi-hasil tech-agnostic + model terkuat (mockup-thread)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: `build/SKILL.md` — DISPATCH assembly + EYEBALL gate

**Files:**
- Modify: `plugin/skills/build/SKILL.md` (step 3 prompt assembly + step 6 gate challenge checklist)

- [ ] **Step 1: Verify anchors present**

Run:
```bash
grep -n 'konvensi + stack + pointer file pola\. \*\*Untuk tiap `deps`' plugin/skills/build/SKILL.md
grep -n 'membypass mandatory package di `packages\[\]\.mandatory_for`?) → minta \*\*approve/revisi\*\*' plugin/skills/build/SKILL.md
```
Expected: each one line (step 3 prompt sentence ~31; step 6 gate challenge-checklist ~47).

- [ ] **Step 2a: Edit — step 3, add mockup to the LENGKAP prompt list**

Replace:
```
konvensi + stack + pointer file pola. **Untuk tiap `deps`:
```
With:
```
konvensi + stack + pointer file pola + **(bila task ber-`mockup:`) isi/pointer file mockup + instruksi reproduksi-visual (`reference.md` §B)**. **Untuk tiap `deps`:
```

- [ ] **Step 2b: Edit — step 6, add eyeball item to the gate challenge checklist**

Replace:
```
membypass mandatory package di `packages[].mandatory_for`?) → minta **approve/revisi**.
```
With:
```
membypass mandatory package di `packages[].mandatory_for`? **untuk task ber-`mockup:` — hasil render UI cocok dengan mockup, layout + animasi? (eyeball + buka app)**) → minta **approve/revisi**.
```

- [ ] **Step 3: Verify result**

Run:
```bash
grep -n 'bila task ber-`mockup:`) isi/pointer file mockup' plugin/skills/build/SKILL.md   # expect 1 (step 3)
grep -n 'untuk task ber-`mockup:` — hasil render UI cocok' plugin/skills/build/SKILL.md    # expect 1 (step 6 gate)
grep -c '→ minta \*\*approve/revisi\*\*' plugin/skills/build/SKILL.md                        # expect 1 (gate intact)
```
Expected: step 3 prompt list includes mockup; step 6 challenge checklist includes the eyeball item.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/build/SKILL.md
git commit -m "feat(build): rakit prompt + mockup (step 3) & gate eyeball render-vs-mockup (step 6) (mockup-thread)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Final verification battery (no new edits)

**Files:** none modified — verification + coherence only.

- [ ] **Step 1: V1 — `mockup:`/`Mockup:` appears at all 5 threading points**

```bash
echo "V1a plan capture+slot:";   grep -c 'mockups/' plugin/skills/plan/SKILL.md           # expect >=3
echo "V1b plan slot:";           grep -c '^Mockup       :' plugin/skills/plan/SKILL.md     # expect 1
echo "V1c breakdown schema:";    grep -c 'mockup: <path>' plugin/skills/breakdown/reference.md  # expect 1
echo "V1d breakdown rule:";      grep -c 'Task UI ber-mockup' plugin/skills/breakdown/reference.md  # expect 1
echo "V1e breakdown coverage:";  grep -c 'UI coverage (mockup→task)' plugin/skills/breakdown/SKILL.md  # expect 1
echo "V1f build dispatch §B:";   grep -c 'Mockup (bila task ber-`mockup:`)' plugin/skills/build/reference.md  # expect 1
echo "V1g build prompt step3:";  grep -c 'bila task ber-`mockup:`) isi/pointer file mockup' plugin/skills/build/SKILL.md  # expect 1
echo "V1h build gate step6:";    grep -c 'untuk task ber-`mockup:` — hasil render UI cocok' plugin/skills/build/SKILL.md  # expect 1
```
Expected: all counts as annotated. Any 0 = a missing edit → fix the owning task.

- [ ] **Step 2: V2 — tech-agnostic instruction integrity (the load-bearing line)**

```bash
grep -c 'JANGAN transplant markup' plugin/skills/build/reference.md   # expect 1
grep -c 'BAWA transisi/animasi'    plugin/skills/build/reference.md   # expect 1
grep -c 'byte opaque'              plugin/skills/build/reference.md   # expect 1
```
Expected: the "reproduce-result, don't-transplant, carry-animation, opaque" instruction is intact in `build/reference.md` §B.

- [ ] **Step 3: V3 — cross-pointer targets resolve**

```bash
# §B referenced from build/SKILL step 3 must exist in build/reference.md
grep -n '^## B\. Menyusun prompt implementer' plugin/skills/build/reference.md   # the "§B" target
# §7 referenced for re-breakdown preservation must exist in breakdown/SKILL.md
grep -n '^### 7\. Tulis output (GATE)' plugin/skills/breakdown/SKILL.md
```
Expected: both targets found — `reference.md §B` (prompt assembly) and `breakdown/SKILL.md §7` (re-breakdown preservation) are real sections. (Anti mis-aimed-pointer.)

- [ ] **Step 4: V4 — no accidental renumber / no new skill-surface**

```bash
git diff main...mockup-thread --stat -- plugin/   # expect ONLY the 5 skill files, no plugin.json/marketplace.json/README
grep -rc 'name: ' plugin/skills/*/SKILL.md | grep -v ':1$' || echo "all SKILL frontmatter single name: OK"
```
Expected: diff touches exactly the 5 target skill files; no manifest/README change; no frontmatter duplication.

- [ ] **Step 5: V5 — degrade-to-noop is honest (optionality stated)**

```bash
grep -c 'OPSIONAL' plugin/skills/breakdown/reference.md   # mockup: marked OPSIONAL alongside actions/manual
grep -c 'ATAU kosong' plugin/skills/plan/SKILL.md          # Mockup: slot allows empty
```
Expected: `mockup:` schema key tagged OPSIONAL; `Mockup:` slot permits empty → non-UI features cost nothing.

- [ ] **Step 6: Report**

Summarize: V1–V5 results, any 0-counts and which task fixed them. If all green → report **"mockup-thread Spec A siap di-review (post-exec adversarial verify di sesi fresh) lalu di-merge."** Do NOT merge here — merge/finishing is the user's call (follow the project's separate-session post-exec-verify pattern before fast-forward merge to `main`).

---

## Self-Review

**1. Spec coverage** (each spec section → task):
- §4 artifact `mockups/` → defined-by-use in Task 1 (plan saves there) + Task 4 (build reads there). ✓ (no standalone file to create — it's a runtime dir created by `plan` on handoff.)
- §5 CAPTURE@plan (read/save/slot/pointer) → Task 1 (2a read, 2b save clause, 2c slot, 2d pointer-not-prose). ✓
- §6.1 THREAD schema `mockup:` + rule → Task 2 (2a key, 2b §D item 6). ✓
- §6.2 coverage check → Task 3. ✓
- §7.1 dispatch prompt + §7.2 model → Task 4 (2a §B, 2b §C). ✓
- §7.3 prompt assembly + §7.4 eyeball gate → Task 5 (2a step 3, 2b step 6). ✓
- §8 generic principles → encoded in Task 4 §B instruction ("opaque", "don't transplant", stack from workspace.yaml). ✓
- §9 degrade-to-noop → V5; optionality in every edit (`bila ...`, OPSIONAL, ATAU kosong). ✓
- §11 verification + bug-guards → Task 6 (V1–V5) + additive-only edits. ✓
- §12 Spec B relationship → out of scope by design; no task (correct). ✓

**2. Placeholder scan:** No TBD/TODO. All `<...>`/`<path…>` are intentional schema placeholders matching existing skill-doc style. Every edit shows exact old→new strings. ✓

**3. Type/string consistency:** Threading token is `mockup:` (task key, lowercase) ↔ `Mockup:` (plan slot, capitalized) — consistent everywhere: plan writes `Mockup:` slot → breakdown reads `Mockup:` → emits `mockup:` task key → build reads `mockup:`. Verified V1 greps use the exact casings. Cross-pointer `reference.md §B` is the real section "## B. Menyusun prompt implementer" (V3). ✓
