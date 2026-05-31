# add-app Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new `add-app` skill (conductor: declare app entry → chain `architect` → `wire`) plus the integration edits that let `fanout` detect "feature needs a new app" and `feature` auto-invoke `add-app`, closing the documented gap where the feature pipeline assumes all apps pre-exist.

**Architecture:** `add-app` is a thin conductor skill (one `SKILL.md`, no `reference.md`). It is the only writer of new app entries to `control/workspace.yaml` after `init`. It writes the entry (identity only), then invokes `architect` (stack) and `wire` (bring-up), reusing those skills' gates. `fanout` gains a detection branch + anti-yes-man challenge that marks an unhostable role as a `NEW` app; `feature` auto-invokes `add-app` for each `NEW` app before `plan`. The rest is doc/consistency edits to `architect`, `wire`, `init`, `README.md`, `plugin.json`, and the parent spec.

**Tech Stack:** Markdown + YAML frontmatter (Claude Code plugin skills). No code, no tests. Verification = YAML-frontmatter lint (specifically the colon-space-in-value guard that broke `wire` twice), grep-consistency across skill files, and cross-reference checks. Work happens on branch `add-app-skill` (already created; spec already committed there at `10ae53b`/`b944b49`).

**Spec:** `docs/superpowers/specs/2026-05-31-add-app-skill-design.md`

---

## Task 1: Create the `add-app` skill

**Files:**
- Create: `plugin/skills/add-app/SKILL.md`

- [ ] **Step 1: Write the skill file**

Create `plugin/skills/add-app/SKILL.md` with EXACTLY this content:

````markdown
---
name: add-app
description: Use untuk nambah SATU app baru ke produk yang sudah di-init — tulis entri app ke workspace.yaml lalu chain architect (stack) lalu wire (bring-up) jadi skeleton kosong-tapi-jalan, semua di-GATE. Satu-satunya penulis entri app baru pasca-init. Dipanggil feature saat fanout nandain app baru, atau standalone. Trigger — "add-app <nama>", "tambah app <x>", "bikin app baru", "scaffold app baru". Jalankan dari root produk yang punya control/.
---

# add-app — Nambah App Baru (declare lalu architect lalu wire)

Tujuan: numbuhin produk yang SUDAH di-`init` dengan SATU app baru. `add-app` = konduktor tipis: tulis identitas app ke `control/workspace.yaml`, lalu chain `architect` (stack) lalu `wire` (bring-up). Hasilnya app baru jadi skeleton kosong-tapi-jalan, siap di-`feature`. Jalankan dari root produk (punya `control/`).

`add-app` **satu-satunya penulis entri app baru pasca-`init`**. Ia TIDAK mutusin stack (jatah `architect`) & TIDAK scaffold/DB/wiring sendiri (jatah `wire`) — ia delegasi. Berat-beratnya tetap di skill yang dipanggil.

## Prinsip (jangan dilanggar)
- **Bukan `init`.** `add-app` TIDAK bootstrap produk / deteksi topologi / scaffold `control/`. `control/` harus sudah ada — kalau belum, arahin ke `init`.
- **Cuma identitas, bukan stack.** `add-app` nanya name/type/responsibility (deklarasi). Framework/db/orm = jatah `architect` di langkah 4. JANGAN tanya stack di sini.
- **App doang (v1).** fe/be/fullstack. Shared package (ui-kit/types) BUKAN urusan `add-app` — beda cabang (nggak ada DB/wiring/smoke).
- **Idempotent.** App yang sudah ada di `workspace.yaml` → STOP, jangan re-declare.
- **Tiap aksi side-effecting = GATE.** Tulis entri = gate sendiri; architect & wire pakai gate masing-masing.

## Langkah (urut)

### 0. Baca state
Baca `control/workspace.yaml` (`topology` + `apps[]` existing). **Prasyarat:** `control/workspace.yaml` ada. Kalau nggak ada → ini bukan `add-app`; arahin ke `init`.

### 1. Cek duplikat (idempotent)
Kalau app `<nama>` sudah ada di `apps[]` → **STOP**, jangan re-declare. Kalau user cuma mau ngelengkapin fondasi app existing → arahin ke `architect`/`wire`.

### 2. Q&A identitas app (singkat — level DEKLARASI, bukan stack)
Tanya:
- `name` (kalau belum dari arg/usulan `fanout`)
- `type`: fe / be / fullstack
- `responsibility`: satu kalimat

Derive `path` dari `topology`:
- **monorepo** → `apps/<nama>` (atau konvensi yang terbaca dari apps existing)
- **multi-repo** → `../<nama>` + minta `repo_url` (boleh kosong kalau repo belum dibuat)

JANGAN tanya framework/db/orm di sini — itu `architect` (langkah 4).

### 3. Tulis entri ke workspace.yaml (GATE)
Tambah entri app baru ke `apps[]` (ikuti bentuk entri `init`):
```yaml
  - name: <nama>
    path: <apps/<nama> | ../<nama>>
    repo_url: <isi untuk multi-repo, kosongkan untuk monorepo>
    type: <fe|be|fullstack>
    responsibility: "<ringkas>"
    capabilities: []        # tumbuh lewat fanout/feature
    stack: {}               # diisi architect (langkah 4)
```
**Add-only-if-absent.** Tampilkan diff `workspace.yaml` → minta **approve**.

### 4. Invoke skill `architect` untuk app ini
`architect` SETUP mode buat app baru: Q&A teknikal (framework/lang/db/orm) → tulis `stack`, cek divergensi konvensi vs app lain, update `conventions.md` bila perlu. Pakai gate-nya `architect`. (`add-app` nggak nentuin stack.)

### 5. Invoke skill `wire` untuk app ini
`wire` greenfield: scaffold (tool resmi) → nyalain DB → konek BE↔DB → wire FE↔BE → env standar → smoke test. Pakai gate-gate `wire`. Hasil: skeleton kosong-tapi-jalan.

### 6. Tutup & balikin
Lapor "**app `<nama>` siap di-`feature`**".
- Dipanggil `feature` (fitur butuh app baru) → balikin kontrol ke `feature` buat lanjut `plan`.
- Standalone → saranin langkah berikutnya (mis. `feature <fitur>`).

## Catatan
- **Cara kanonik nambah app pasca-`init`.** `architect`/`wire` boleh jalan standalone, tapi yang **nulis entri app baru** cuma `add-app`. `init` cuma declare app AWAL pas bootstrap.
- **Multi-repo:** `add-app` cuma nyatet `path` + `repo_url`. Pembuatan repo fisik (git init/remote) di-defer ke `wire` + user (gated) — repo app tidak dikelola hub.
- **Beberapa app baru dalam 1 fitur:** dipanggil sekali per app (oleh `feature`). Ikuti "Urutan" di `fanout.md` bila ada.
- TIDAK nyentuh `control/business/*` dan TIDAK bikin table/kode fitur (itu `build`).
````

- [ ] **Step 2: Verify frontmatter is well-formed (colon-space guard + required keys)**

Run:
```bash
# (a) required structure
grep -c '^---$' plugin/skills/add-app/SKILL.md   # expect: 2
grep -qE '^name: add-app$' plugin/skills/add-app/SKILL.md && echo "name OK"
grep -qE '^description: ' plugin/skills/add-app/SKILL.md && echo "description OK"
# (b) the colon-space-in-value bug that broke wire twice: the description VALUE must contain no ": "
sed -n 's/^description: //p' plugin/skills/add-app/SKILL.md | grep -q ': ' \
  && echo "FAIL: colon-space in description value" \
  || echo "OK: no colon-space in description value"
```
Expected output:
```
2
name OK
description OK
OK: no colon-space in description value
```

- [ ] **Step 3: Verify YAML frontmatter parses (best-effort)**

Run:
```bash
awk 'f&&/^---$/{exit} /^---$/{f=1;next} f' plugin/skills/add-app/SKILL.md \
  | python3 -c "import sys,yaml; d=yaml.safe_load(sys.stdin); assert d.get('name')=='add-app'; assert d.get('description'); print('YAML OK:', list(d.keys()))" 2>/dev/null \
  || echo "python3/pyyaml unavailable — rely on Step 2 grep checks"
```
Expected: either `YAML OK: ['name', 'description']` or the fallback line. (Step 2 is the binding check.)

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/add-app/SKILL.md
git commit -m "feat(add-app): new conductor skill (declare app -> architect -> wire)"
```

---

## Task 2: Add new-app detection to `fanout`

**Files:**
- Modify: `plugin/skills/fanout/SKILL.md` (step 2 mapping, step 3 checklist, step 4 output)

- [ ] **Step 1: Add the detection branch to step 2**

In `plugin/skills/fanout/SKILL.md`, find this line (the last bullet of step 2):

```
- Bila user memberi hint app (mis. "cuma web"), tetap **VERIFIKASI** terhadap capabilities — koreksi bila ternyata menyentuh app lain. "Cuma 1 app" adalah KESIMPULAN, bukan input. JANGAN skip pengecekan.
```

Replace it with (same line, then a new bullet):

```
- Bila user memberi hint app (mis. "cuma web"), tetap **VERIFIKASI** terhadap capabilities — koreksi bila ternyata menyentuh app lain. "Cuma 1 app" adalah KESIMPULAN, bukan input. JANGAN skip pengecekan.
- **Kalau ADA peran yang nggak ketampung app mana pun → mungkin butuh APP BARU.** Tantang dulu (anti-yes-man): beneran perlu app baru, atau scope-creep / bisa ditampung app existing? Lolos tantangan → tandai di output sebagai app `NEW` (langkah 4). `fanout` cuma **MENGUSULKAN**; yang nulis entri app + bring-up = skill `add-app` (dipanggil otomatis `feature`).
```

- [ ] **Step 2: Add a line to the step 3 Challenge Checklist**

Find:

```
### 3. Challenge Checklist (WAJIB sebelum gate)
- Ada app yang kelewat?
```

Replace with:

```
### 3. Challenge Checklist (WAJIB sebelum gate)
- Ada app yang kelewat?
- Ada peran yang nggak ketampung app mana pun → butuh app baru? (beneran perlu, atau scope-creep?)
```

- [ ] **Step 3: Mark NEW apps in the step 4 output format**

Find this line inside the `fanout.md` format block:

```
<app> (<peran/kapabilitas>) : <apa yang berubah>
```

Replace with:

```
<app> (<peran/kapabilitas>) : <apa yang berubah>
<usulan-nama> (NEW — belum ada) : <peran>      # app baru; diwujudkan add-app
```

- [ ] **Step 4: Clarify that fanout does not write NEW app entries**

Find:

```
Lalu **update `capabilities`** app terkait di `control/workspace.yaml` (tambah kapabilitas baru yang diperkenalkan fitur ini). **Add-only-if-absent:** kalau kapabilitas sudah ada, jangan tambah lagi (re-run fanout nggak boleh bikin entri ganda).
```

Replace with:

```
Lalu **update `capabilities`** app terkait di `control/workspace.yaml` (tambah kapabilitas baru yang diperkenalkan fitur ini). **Add-only-if-absent:** kalau kapabilitas sudah ada, jangan tambah lagi (re-run fanout nggak boleh bikin entri ganda). App bertanda `NEW` **JANGAN** ditulis ke `workspace.yaml` di sini — itu jatah `add-app`; `fanout` cuma update `capabilities` app **existing**.
```

- [ ] **Step 5: Verify all four edits landed and frontmatter still intact**

Run:
```bash
grep -c 'NEW' plugin/skills/fanout/SKILL.md                 # expect: >= 2
grep -q 'skill `add-app`' plugin/skills/fanout/SKILL.md && echo "routes to add-app OK"
grep -q 'butuh app baru?' plugin/skills/fanout/SKILL.md && echo "checklist line OK"
grep -c '^---$' plugin/skills/fanout/SKILL.md               # expect: 2
```
Expected:
```
<a number >= 2>
routes to add-app OK
checklist line OK
2
```

- [ ] **Step 6: Commit**

```bash
git add plugin/skills/fanout/SKILL.md
git commit -m "feat(fanout): detect 'feature needs new app' and route to add-app"
```

---

## Task 3: Auto-invoke `add-app` from `feature`

**Files:**
- Modify: `plugin/skills/feature/SKILL.md` (step 2 sequence, Catatan prasyarat)

- [ ] **Step 1: Insert the auto-invoke sub-step after fanout**

In `plugin/skills/feature/SKILL.md`, find:

```
2. Invoke skill **`fanout`** untuk `<nama>` → tunggu gate (approve `fanout.md`).
```

Replace with (same line + a nested sub-bullet — no renumbering of the 1/2/3 list):

```
2. Invoke skill **`fanout`** untuk `<nama>` → tunggu gate (approve `fanout.md`).
   - **Bila `fanout.md` nandain app `NEW` (belum ada):** untuk tiap app baru, invoke skill **`add-app <nama-app>`** (declare entri → `architect` → `wire`, semua gated) → tunggu beres. Baru lanjut ke `plan`. Saat `plan` jalan, app baru sudah ada di `workspace.yaml` **dan** sudah ter-wire.
```

- [ ] **Step 2: Extend the prasyarat note to cover not-yet-existing apps**

Find:

```
- Prasyarat: app sudah di-`wire` (skeleton jalan: DB nyambung, FE↔BE ke-wire). Kalau `plan` mentok karena fondasi belum ada, jalankan `wire` dulu (setelah `architect`).
```

Replace with:

```
- Prasyarat: app sudah di-`wire` (skeleton jalan: DB nyambung, FE↔BE ke-wire). Kalau `plan` mentok karena fondasi belum ada, jalankan `wire` dulu (setelah `architect`). Kalau fitur butuh app yang **BELUM ADA** sama sekali, itu ditangani `add-app` (dipicu otomatis dari `fanout` — lihat langkah 2).
```

- [ ] **Step 3: Verify edits landed**

Run:
```bash
grep -q 'add-app <nama-app>' plugin/skills/feature/SKILL.md && echo "auto-invoke OK"
grep -q 'BELUM ADA' plugin/skills/feature/SKILL.md && echo "prasyarat note OK"
# confirm the 1/2/3 list was NOT renumbered (still exactly one '3. Invoke skill **`plan`**')
grep -c '3\. Invoke skill \*\*`plan`\*\*' plugin/skills/feature/SKILL.md   # expect: 1
grep -c '^---$' plugin/skills/feature/SKILL.md                           # expect: 2
```
Expected:
```
auto-invoke OK
prasyarat note OK
1
2
```

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/feature/SKILL.md
git commit -m "feat(feature): auto-invoke add-app when fanout flags a new app"
```

---

## Task 4: Dedup ownership notes (`architect`, `wire`, `init`)

**Files:**
- Modify: `plugin/skills/architect/SKILL.md` (Catatan)
- Modify: `plugin/skills/wire/SKILL.md` (Catatan)
- Modify: `plugin/skills/init/SKILL.md` (step 3)

- [ ] **Step 1: Point architect's "nambah app" note at add-app**

In `plugin/skills/architect/SKILL.md`, find:

```
- Bisa di-rerun saat nambah app/shared package.
```

Replace with:

```
- Nambah app baru pasca-`init` = lewat skill `add-app` (yang manggil `architect` ini buat set `stack` app yang baru dideklarasi). `architect` standalone tetap buat set/recapture stack app yang **sudah terdaftar** — ia **tidak** nulis entri app baru ke `workspace.yaml`. Shared package: rerun manual.
```

- [ ] **Step 2: Point wire's "nambah app" note at add-app**

In `plugin/skills/wire/SKILL.md`, find:

```
- `wire` sekali jalan (kayak `extract`), bisa di-rerun saat nambah app (kayak `architect`). Brownfield: bersifat **repair** — hanya bila wiring belum lengkap.
```

Replace with:

```
- `wire` sekali jalan (kayak `extract`). Saat nambah app baru, dipanggil oleh skill `add-app` (yang chain `architect`→`wire`); bisa juga di-rerun manual. Brownfield: bersifat **repair** — hanya bila wiring belum lengkap.
```

- [ ] **Step 3: Point init's "tambah nanti" at add-app**

In `plugin/skills/init/SKILL.md`, find:

```
- App apa saja yang sudah kebayang? (greenfield: declare; existing: konfirmasi yang terdeteksi). Boleh mulai dari satu, tambah nanti.
```

Replace with:

```
- App apa saja yang sudah kebayang? (greenfield: declare; existing: konfirmasi yang terdeteksi). Boleh mulai dari satu, tambah app lain nanti lewat skill `add-app`.
```

- [ ] **Step 4: Verify all three point at add-app, frontmatter intact**

Run:
```bash
grep -q 'add-app' plugin/skills/architect/SKILL.md && echo "architect OK"
grep -q 'add-app' plugin/skills/wire/SKILL.md && echo "wire OK"
grep -q 'add-app' plugin/skills/init/SKILL.md && echo "init OK"
# no stale "bisa di-rerun saat nambah app" left implying nobody writes the entry
grep -rn 'bisa di-rerun saat nambah app' plugin/skills/architect/SKILL.md plugin/skills/wire/SKILL.md \
  && echo "WARN: stale note remains" || echo "stale notes cleared"
```
Expected:
```
architect OK
wire OK
init OK
stale notes cleared
```

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/architect/SKILL.md plugin/skills/wire/SKILL.md plugin/skills/init/SKILL.md
git commit -m "docs(skills): point architect/wire/init app-adding notes at add-app"
```

---

## Task 5: Update `README.md` and `plugin.json`

**Files:**
- Modify: `README.md` ("Bikin fitur" section)
- Modify: `plugin/.claude-plugin/plugin.json` (description)

- [ ] **Step 1: Add the add-app branch note to README**

In `README.md`, find this blockquote line:

```
> `breakdown` kini bisa wakili kerja non-file (`actions:` migrate/install/env) & langkah manusia (`manual:`/status `needs_human`); `build` jalanin+verifikasi actions (migrasi lewat gate) dan uji integrasi cross-app; `build`/`ship` sadar multi-repo (branch & PR per repo).
```

Replace with (same line + a new blockquote line):

```
> `breakdown` kini bisa wakili kerja non-file (`actions:` migrate/install/env) & langkah manusia (`manual:`/status `needs_human`); `build` jalanin+verifikasi actions (migrasi lewat gate) dan uji integrasi cross-app; `build`/`ship` sadar multi-repo (branch & PR per repo).

> Kalau sebuah fitur butuh **app baru** (belum ada di `workspace.yaml`), `fanout` nandain dan `feature` otomatis panggil `add-app` (declare entri → `architect` → `wire`) sebelum `plan`. `add-app <nama>` juga bisa dipanggil standalone buat numbuhin produk pasca-`init`.
```

- [ ] **Step 2: Mention add-app in plugin.json description**

In `plugin/.claude-plugin/plugin.json`, find:

```
  "description": "AI-first product boilerplate: lapisan AI + knowledge untuk mengelola produk multi-app (init, architect + wire bring-up, feature pipeline, breakdown/build dengan actions/manual + integrasi cross-app + multi-repo aware, ship/drop, docs).",
```

Replace with:

```
  "description": "AI-first product boilerplate: lapisan AI + knowledge untuk mengelola produk multi-app (init, architect + wire bring-up, add-app nambah app baru, feature pipeline, breakdown/build dengan actions/manual + integrasi cross-app + multi-repo aware, ship/drop, docs).",
```

- [ ] **Step 3: Verify README edit + JSON still valid**

Run:
```bash
grep -q 'otomatis panggil `add-app`' README.md && echo "README OK"
python3 -c "import json; json.load(open('plugin/.claude-plugin/plugin.json')); print('plugin.json valid')"
grep -q 'add-app nambah app baru' plugin/.claude-plugin/plugin.json && echo "plugin.json desc OK"
```
Expected:
```
README OK
plugin.json valid
plugin.json desc OK
```

- [ ] **Step 4: Commit**

```bash
git add README.md plugin/.claude-plugin/plugin.json
git commit -m "docs: mention add-app in README lifecycle and plugin description"
```

---

## Task 6: Update parent spec (§12 lifecycle, §17 komponen)

**Files:**
- Modify: `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§12, §17)

- [ ] **Step 1: Add the triggered-branch note to §12 (after the lifecycle diagram)**

In `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`, find:

```
Status di `feature.yaml`:
```

Replace with:

```
**Cabang dipicu — fitur butuh app baru:** bila `fanout` mendeteksi tidak ada app existing yang menampung sebuah peran, `feature` otomatis invoke **`add-app`** (declare entri ke `workspace.yaml` → `architect` → `wire`) sebelum `plan`. `add-app` juga bisa dipanggil standalone. Lihat spec `2026-05-31-add-app-skill-design.md`.

Status di `feature.yaml`:
```

- [ ] **Step 2: Add add-app to §17 Komponen and bump the count**

Find:

```
- **Skills (14):** `discovery` · `init` · `architect` · `wire` · `extract` · `feature` (→ `intake` · `fanout` · `plan`) · `breakdown` · `build` · `ship` · `drop` · `render-docs`
```

Replace with:

```
- **Skills (15):** `discovery` · `init` · `architect` · `wire` · `add-app` · `extract` · `feature` (→ `intake` · `fanout` · `plan`) · `breakdown` · `build` · `ship` · `drop` · `render-docs`
```

- [ ] **Step 3: Verify both edits**

Run:
```bash
grep -q 'Cabang dipicu — fitur butuh app baru' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md && echo "§12 note OK"
grep -q '\*\*Skills (15):\*\*' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md && echo "§17 count OK"
grep -q 'wire` · `add-app` · `extract' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md && echo "§17 list OK"
```
Expected:
```
§12 note OK
§17 count OK
§17 list OK
```

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
git commit -m "docs(spec): record add-app in parent design (§12 lifecycle, §17 komponen 14->15)"
```

---

## Task 7: Final consistency sweep

**Files:**
- Verify only (fix inline if a check fails); no new files.

- [ ] **Step 1: All skill frontmatters parse (colon-space guard across the whole plugin)**

Run:
```bash
for f in plugin/skills/*/SKILL.md; do
  n=$(grep -c '^---$' "$f")
  v=$(sed -n 's/^description: //p' "$f" | grep -c ': ')
  echo "$f delims=$n colon_space_in_desc=$v"
done
```
Expected: every line shows `delims=2 colon_space_in_desc=0`. If any `colon_space_in_desc` is non-zero, that description value has a `: ` that breaks YAML — fix that skill's description (rephrase the `: ` away, e.g. use `—`).

- [ ] **Step 2: add-app is referenced consistently by the skills that route to it**

Run:
```bash
for f in fanout feature architect wire init; do
  grep -q 'add-app' "plugin/skills/$f/SKILL.md" && echo "$f references add-app: OK" || echo "$f references add-app: MISSING"
done
```
Expected: all five print `OK`.

- [ ] **Step 3: No dangling references — `add-app` skill dir exists and is named correctly**

Run:
```bash
test -f plugin/skills/add-app/SKILL.md && echo "add-app skill exists"
grep -q '^name: add-app$' plugin/skills/add-app/SKILL.md && echo "name matches dir"
# the README/plugin/spec all mention add-app
grep -rl 'add-app' README.md plugin/.claude-plugin/plugin.json docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md | wc -l   # expect: 3
```
Expected:
```
add-app skill exists
name matches dir
3
```

- [ ] **Step 4: Read-back coherence check (manual)**

Read `plugin/skills/add-app/SKILL.md`, `plugin/skills/fanout/SKILL.md` (step 2–4), and `plugin/skills/feature/SKILL.md` (step 2) end-to-end. Confirm the flow reads coherently: fanout marks `NEW` → feature invokes `add-app <name>` → add-app declares entry + chains architect→wire → returns to feature for `plan`. Confirm no edit left a half-sentence or broken list. If anything reads wrong, fix it and amend the relevant task's commit (or add a `fix:` commit).

- [ ] **Step 5: Commit (only if Step 4 produced fixes)**

```bash
git add -A
git commit -m "fix(add-app): consistency-sweep corrections"
```

If Step 4 produced no fixes, skip this commit — the sweep is verification-only.

---

## Done criteria

- `plugin/skills/add-app/SKILL.md` exists, frontmatter valid, no colon-space in description value.
- `fanout` detects "no app fits" (with anti-yes-man challenge) and marks `NEW`; does not write the entry.
- `feature` auto-invokes `add-app` for each `NEW` app before `plan`, with the 1/2/3 list un-renumbered.
- `architect`/`wire`/`init` notes point new-app declaration at `add-app`; no stale "bisa di-rerun saat nambah app" remains in architect/wire.
- `README.md`, `plugin.json`, and parent spec (§12 + §17) reflect `add-app`; spec skill count is 15.
- Every task committed on branch `add-app-skill`.
