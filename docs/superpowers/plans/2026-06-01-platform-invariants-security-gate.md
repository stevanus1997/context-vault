# Platform Invariants + Security Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tambal gap H1 (kunci invarian platform sebelum table pertama), H4 (Security & Compliance Gate di `ship`), M2 (ikat `invariants.md` ke gate) dari audit ecommerce-builder — tanpa skill baru.

**Architecture:** Artifact baru `control/invariants.md` (slot bernama, resolved-or-N/A) jadi rumah invarian; `architect` dapat langkah 4.5 "Kunci Invarian" (gated, `critic` wajib, idempotent); `wire` step 0 menolak bring-up kalau invarian belum terkunci; `ship` dapat langkah 4.5 "Security Gate" ber-agent baru `security-critic`, kedalamannya berskala ke tag `sensitivity` (intake→feature.yaml→ship); satu baris challenge di `plan`/`breakdown`/`build` mengikat invarian ke gate. Sisanya doc-consistency + amandemen spec induk.

**Tech Stack:** Markdown + YAML frontmatter (Claude Code plugin skills/agents/template). No code, no runtime tests. Verifikasi = YAML-frontmatter lint (guard colon-space-in-value yang dua kali bikin `wire` jebol), grep-consistency lintas file, + renumber-cross-ref check (sisipan langkah desimal 4.5). Kerja di branch `platform-invariants-security-gate` (sudah dibuat; spec ke-commit di `3575b48`).

**Spec:** `docs/superpowers/specs/2026-06-01-platform-invariants-security-gate-design.md`

---

## Task 1: Buat template `control/invariants.md`

**Files:**
- Create: `plugin/template/control/invariants.md`

- [ ] **Step 1: Tulis template**

Create `plugin/template/control/invariants.md` dengan EXACTLY isi ini:

````markdown
# <PRODUCT> — Invarian Platform

> Keputusan fondasi yang berlaku ke SELURUH produk; mahal diubah belakangan.
> Dikunci SEKALI oleh `architect` (langkah "Kunci Invarian") sebelum `wire`.
> Tiap slot: ISI keputusannya, ATAU tulis "N/A — <alasan>". Jangan biarkan "<belum dikunci>".
> Slot di bawah = saran umum; `architect` boleh menambah invarian spesifik-produk atau menandai N/A.

## Tenancy
<belum dikunci>

## Money & Currency
<belum dikunci>

## Idempotency
<belum dikunci>

## Authz / RBAC
<belum dikunci>

## PII / PCI / Data Sensitif
<belum dikunci>

## Rate-limit / Abuse
<belum dikunci>
````

- [ ] **Step 2: Verifikasi bentuk**

Run:
```bash
grep -c '<belum dikunci>' plugin/template/control/invariants.md   # expect: 6
grep -q '^# <PRODUCT> — Invarian Platform$' plugin/template/control/invariants.md && echo "title placeholder OK"
grep -cE '^## ' plugin/template/control/invariants.md             # expect: 6
```
Expected:
```
6
title placeholder OK
6
```

- [ ] **Step 3: Commit**

```bash
git add plugin/template/control/invariants.md
git commit -m "feat(template): add control/invariants.md skeleton (platform invariants home)"
```

---

## Task 2: `init` meng-copy + replace `<PRODUCT>` di `invariants.md`

**Files:**
- Modify: `plugin/skills/init/SKILL.md` (step 4, line ~36)

> Catatan: `cp -R "${CLAUDE_PLUGIN_ROOT}/template/control/."` di step 4 SUDAH otomatis meng-copy `invariants.md`. Yang kurang: klausa replace `<PRODUCT>` belum menyebut `invariants.md`.

- [ ] **Step 1: Perluas klausa replace `<PRODUCT>`**

Find (persis):

```
- Ganti placeholder `<PRODUCT>` dengan nama produk di SEMUA file `control/` yang baru di-scaffold (semua `business/*.md` **dan** `conventions.md`) — `<PRODUCT>` selalu berarti nama produk, jadi jangan tinggalkan satu pun.
```

Replace with:

```
- Ganti placeholder `<PRODUCT>` dengan nama produk di SEMUA file `control/` yang baru di-scaffold (semua `business/*.md`, `conventions.md`, **dan** `invariants.md`) — `<PRODUCT>` selalu berarti nama produk, jadi jangan tinggalkan satu pun.
```

- [ ] **Step 2: Verifikasi**

Run:
```bash
grep -q 'dan\*\* `invariants.md`' plugin/skills/init/SKILL.md && echo "invariants in replace clause OK"
grep -c '^---$' plugin/skills/init/SKILL.md   # expect: 2 (frontmatter intact)
```
Expected:
```
invariants in replace clause OK
2
```

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/init/SKILL.md
git commit -m "fix(init): replace <PRODUCT> in invariants.md too"
```

---

## Task 3: `architect` — langkah 4.5 "Kunci Invarian Platform"

**Files:**
- Modify: `plugin/skills/architect/SKILL.md` (sisip langkah 4.5 antara step 4 & step 5; perluas gate step 6; tambah catatan)

- [ ] **Step 1: Sisip langkah 4.5 setelah "Konvensi lintas-app"**

Find (persis — akhir step 4, awal step 5):

```
### 4. Konvensi lintas-app
Tetapkan/rekam kontrak bersama (auth, format API, shared package, ORM standar) → tulis ke `control/conventions.md` (ganti skeleton-nya). Untuk keputusan fondasi besar (mahal di-refactor), jalankan Challenge Checklist + invoke subagent `critic`.

### 5. Challenge Checklist (WAJIB sebelum gate)
```

Replace with:

```
### 4. Konvensi lintas-app
Tetapkan/rekam kontrak bersama (auth, format API, shared package, ORM standar) → tulis ke `control/conventions.md` (ganti skeleton-nya). Untuk keputusan fondasi besar (mahal di-refactor), jalankan Challenge Checklist + invoke subagent `critic`.

### 4.5 Kunci Invarian Platform (sekali, level-produk, GATE)
Invarian = keputusan fondasi yang membentuk SETIAP table & query, mahal di-refactor (model tenancy, representasi uang, idempotency, authz, PII/PCI, rate-limit). Dikunci di DEPAN, bukan ditunda ke fitur pertama.
- Baca `control/invariants.md`. **Idempotent:** kalau SEMUA slot sudah resolved (bukan lagi `<belum dikunci>`) → tampilkan ringkas + konfirmasi, **JANGAN tanya ulang**. (Penting: `architect` di-rerun & dipanggil `add-app` per app baru — penguncian invarian level-produk TIDAK boleh terjadi tiap app.)
- Kalau ada slot `<belum dikunci>`: **ELICIT** per slot keputusannya (level fondasi, bukan stack). User boleh jawab `N/A — alasan`. Sodorkan slot saran; terima invarian tambahan spesifik-produk. Tulis hasil ke `control/invariants.md` (ganti `<belum dikunci>`).
- **`critic` WAJIB di gate ini** (bukan kondisional): red-team `invariants.md` — invarian fondasi kelewat? keputusan berisiko/over-engineered? bentrok antar-invarian? Tanggapi tiap keberatan sebelum gate lewat.

### 5. Challenge Checklist (WAJIB sebelum gate)
```

- [ ] **Step 2: Perluas tampilan gate (step 6) untuk ikut menampilkan invariants.md**

Find (persis):

```
Tampilkan `stack` & `capabilities` per app (`workspace.yaml`) + isi `conventions.md` → minta **approve**. Sarankan langkah berikutnya: `wire` (bring-up: scaffold + DB + wiring + env jadi skeleton jalan) sebelum `feature`. (Brownfield: `extract` opsional dulu.)
```

Replace with:

```
Tampilkan `stack` & `capabilities` per app (`workspace.yaml`) + isi `conventions.md` + `invariants.md` → minta **approve**. Sarankan langkah berikutnya: `wire` (bring-up: scaffold + DB + wiring + env jadi skeleton jalan) sebelum `feature`. (Brownfield: `extract` opsional dulu.)
```

- [ ] **Step 3: Tambah catatan idempotency invarian (untuk add-app)**

Find (persis — bullet kedua di Catatan):

```
- Nambah app baru pasca-`init` = lewat skill `add-app` (yang manggil `architect` ini buat set `stack` app yang baru dideklarasi). `architect` standalone tetap buat set/recapture stack app yang **sudah terdaftar** — ia **tidak** nulis entri app baru ke `workspace.yaml`. Shared package: rerun manual.
```

Replace with:

```
- Nambah app baru pasca-`init` = lewat skill `add-app` (yang manggil `architect` ini buat set `stack` app yang baru dideklarasi). `architect` standalone tetap buat set/recapture stack app yang **sudah terdaftar** — ia **tidak** nulis entri app baru ke `workspace.yaml`. Shared package: rerun manual.
- **Invarian platform (langkah 4.5) level-PRODUK, sekali kunci.** Saat `architect` di-rerun atau dipanggil `add-app` untuk app baru, langkah 4.5 hanya mengonfirmasi `invariants.md` yang sudah resolved — TIDAK menanya/mengunci ulang.
```

- [ ] **Step 4: Verifikasi edits + frontmatter**

Run:
```bash
grep -q '### 4.5 Kunci Invarian Platform' plugin/skills/architect/SKILL.md && echo "step 4.5 OK"
grep -q 'critic` WAJIB di gate ini' plugin/skills/architect/SKILL.md && echo "critic mandatory OK"
grep -q "conventions.md` + \`invariants.md" plugin/skills/architect/SKILL.md && echo "gate display OK"
grep -q 'level-PRODUK, sekali kunci' plugin/skills/architect/SKILL.md && echo "idempotency note OK"
grep -c '^---$' plugin/skills/architect/SKILL.md   # expect: 2
# guard: tak ada langkah integer yang ke-renumber (step 5 & 6 masih ada apa adanya)
grep -q '### 5. Challenge Checklist' plugin/skills/architect/SKILL.md && grep -q '### 6. Tulis output' plugin/skills/architect/SKILL.md && echo "no integer renumber OK"
```
Expected: semua baris `OK` + `2`.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/architect/SKILL.md
git commit -m "feat(architect): step 4.5 Kunci Invarian Platform (gated, critic-mandatory, idempotent)"
```

---

## Task 4: `wire` — prasyarat invarian di step 0

**Files:**
- Modify: `plugin/skills/wire/SKILL.md` (step 0, line ~23)

- [ ] **Step 1: Tambah cek prasyarat invarian**

Find (persis):

```
Baca `control/workspace.yaml` (`apps[]`: path/type/stack/topology) + `control/conventions.md`. **Prasyarat:** architect sudah set `stack` logical (min framework + db + orm) per app; kalau belum → arahkan ke `architect`. Cek kode tiap `path`: kosong → **greenfield (scaffold penuh)**; ada kode → **brownfield (repair: lengkapi yang kurang, idempotent, jangan timpa)**.
```

Replace with:

```
Baca `control/workspace.yaml` (`apps[]`: path/type/stack/topology) + `control/conventions.md` + `control/invariants.md`. **Prasyarat stack:** architect sudah set `stack` logical (min framework + db + orm) per app; kalau belum → arahkan ke `architect`. **Prasyarat invarian:** `control/invariants.md` ada DAN semua slot resolved (tak ada `<belum dikunci>`); kalau tidak → **STOP**, arahkan ke `architect` (kunci invarian dulu — ia membentuk skema baseline). Cek kode tiap `path`: kosong → **greenfield (scaffold penuh)**; ada kode → **brownfield (repair: lengkapi yang kurang, idempotent, jangan timpa)**.
```

- [ ] **Step 2: Verifikasi**

Run:
```bash
grep -q 'Prasyarat invarian' plugin/skills/wire/SKILL.md && echo "invariant prereq OK"
grep -q '<belum dikunci>' plugin/skills/wire/SKILL.md && echo "placeholder check OK"
grep -c '^---$' plugin/skills/wire/SKILL.md   # expect: 2
```
Expected: `invariant prereq OK` / `placeholder check OK` / `2`.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/wire/SKILL.md
git commit -m "feat(wire): refuse bring-up until platform invariants locked"
```

---

## Task 5: Agent baru `security-critic`

**Files:**
- Create: `plugin/agents/security-critic.md`

- [ ] **Step 1: Tulis agent**

Create `plugin/agents/security-critic.md` dengan EXACTLY isi ini (description value SENGAJA tanpa `": "` — guard bug colon-space):

````markdown
---
name: security-critic
description: Red-team keamanan independen atas DIFF sebuah fitur. Diberi diff + invariants.md/conventions.md, tugasnya MENCARI kerentanan — secret ke-commit, PII di log, data kartu (PCI), webhook tanpa verifikasi signature, endpoint tanpa cek tenant/role, input tak divalidasi. Dipanggil ship di Security & Compliance Gate untuk fitur ber-sensitivity. Read-only.
tools: Read, Grep, Glob
---

Kamu adalah SECURITY-CRITIC — red-team keamanan independen, BUKAN pengusul. Tugasmu HANYA mencari kerentanan di DIFF fitur. Jangan menyetujui, jangan melunak.

Kamu menerima: diff fitur (path + range/SHA per repo) + `control/invariants.md` (baseline invarian Tenancy/Authz/PII-PCI) + `control/conventions.md`.

Lakukan:
1. Baca diff + `control/invariants.md` + `control/conventions.md`.
2. Cari & laporkan sespesifik mungkin (sebut file:line di diff):
   - **Secret/credential hardcoded** — API key, token, password, connection string ke-commit (bukan dari env).
   - **PII bocor** — email/nama/alamat/telp/gov-id masuk ke log, pesan error, atau response yang tak semestinya.
   - **Data kartu (PCI)** — PAN/CVV/expiry disimpan ke DB atau di-log → pelanggaran PCI-DSS.
   - **Webhook/endpoint masuk tanpa verifikasi** — signature/origin/HMAC tak dicek.
   - **Authz/tenant bocor** — endpoint tanpa cek role/tenant; query tanpa filter `tenant_id` (silang dengan invarian Tenancy/Authz di `invariants.md` → privilege escalation / cross-tenant leak).
   - **Input tak divalidasi** — surface injection (SQL/command/path), deserialisasi tak aman.
3. Tiap temuan: file:line + severity (high/med/low) + alasan + 1 baris saran perbaikan.

Output: daftar temuan bernomor dengan severity. Kalau memang tak ada masalah signifikan setelah benar-benar mencari, katakan eksplisit "Tidak menemukan masalah keamanan signifikan". Jangan mengarang. Kamu read-only — JANGAN menulis/memperbaiki kode.
````

- [ ] **Step 2: Verifikasi frontmatter (guard colon-space + required keys)**

Run:
```bash
grep -c '^---$' plugin/agents/security-critic.md   # expect: 2
grep -qE '^name: security-critic$' plugin/agents/security-critic.md && echo "name OK"
grep -qE '^tools: ' plugin/agents/security-critic.md && echo "tools OK"
# guard: nilai description tak boleh mengandung ": "
sed -n 's/^description: //p' plugin/agents/security-critic.md | grep -q ': ' \
  && echo "FAIL: colon-space in description value" \
  || echo "OK: no colon-space in description value"
```
Expected:
```
2
name OK
tools OK
OK: no colon-space in description value
```

- [ ] **Step 3: Commit**

```bash
git add plugin/agents/security-critic.md
git commit -m "feat(agents): add security-critic red-team agent (read-only diff scan)"
```

---

## Task 6: `feature` — skema `feature.yaml` + `sensitivity`

**Files:**
- Modify: `plugin/skills/feature/SKILL.md` (step 1 yaml block)

- [ ] **Step 1: Tambah field `sensitivity` ke skema feature.yaml**

Find (persis):

```yaml
name: <nama>
status: draft
created: <YYYY-MM-DD>
```

Replace with:

```yaml
name: <nama>
status: draft
created: <YYYY-MM-DD>
sensitivity: []        # [] | [payments] | [pii] | [payments, pii] — diusulkan intake, dikonfirmasi user
```

- [ ] **Step 2: Verifikasi**

Run:
```bash
grep -q 'sensitivity: \[\]' plugin/skills/feature/SKILL.md && echo "sensitivity field OK"
grep -c '^---$' plugin/skills/feature/SKILL.md   # expect: 2
```
Expected: `sensitivity field OK` / `2`.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/feature/SKILL.md
git commit -m "feat(feature): add sensitivity field to feature.yaml schema"
```

---

## Task 7: `intake` — tulis `sensitivity: []` + usulkan tag

**Files:**
- Modify: `plugin/skills/intake/SKILL.md` (step 1 yaml block + step 7 gate)

- [ ] **Step 1: Tambah `sensitivity` ke skema feature.yaml fallback (step 1)**

Find (persis):

```yaml
name: <fitur>
status: draft
created: <YYYY-MM-DD>
```

Replace with:

```yaml
name: <fitur>
status: draft
created: <YYYY-MM-DD>
sensitivity: []        # [] | [payments] | [pii] | [payments, pii] — diusulkan di step 7, dikonfirmasi user
```

- [ ] **Step 2: Tambah usulan tag `sensitivity` di gate (step 7)**

Find (persis — kalimat penutup step 7):

```
Tampilkan `business.md` + daftar promosi knowledge → minta **approve**. Boleh tulis draft dulu lalu konfirmasi.
```

Replace with:

```
**Usulkan tag `sensitivity`** dari isi `business.md` (heuristik): `payments` kalau fitur menggerakkan/menyimpan uang (bayar, billing, payout, refund, fee); `pii` kalau mengumpulkan/menyimpan/menampilkan data pribadi (nama, email, alamat, telp, gov-id). Cross-check ringan ke `control/invariants.md` — kalau slot PII/PCI di-`N/A`, jangan ngotot tag `pii`. Tulis usulan ke `feature.yaml` `sensitivity:` (kosong boleh).

Tampilkan `business.md` + daftar promosi knowledge + usulan `sensitivity` → minta **approve/koreksi**. Boleh tulis draft dulu lalu konfirmasi.
```

- [ ] **Step 3: Verifikasi**

Run:
```bash
grep -q 'sensitivity: \[\]' plugin/skills/intake/SKILL.md && echo "sensitivity field OK"
grep -q 'Usulkan tag `sensitivity`' plugin/skills/intake/SKILL.md && echo "tag proposal OK"
grep -q 'slot PII/PCI di-`N/A`' plugin/skills/intake/SKILL.md && echo "cross-check OK"
grep -c '^---$' plugin/skills/intake/SKILL.md   # expect: 2
```
Expected: 3 baris `OK` + `2`.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/intake/SKILL.md
git commit -m "feat(intake): propose sensitivity tags from business.md (cross-checked vs invariants)"
```

---

## Task 8: `ship` — Security & Compliance Gate (langkah 4.5)

**Files:**
- Modify: `plugin/skills/ship/SKILL.md` (step 1 read, step 4 checklist item, sisip step 4.5)

- [ ] **Step 1: Step 1 ikut membaca `sensitivity`**

Find (persis):

```
Baca `control/features/<fitur>/feature.yaml` (harus `status: active`), `business.md`, `fanout.md`, `plans/*`. Tentukan app yang kena dari `fanout.md` + `path`/`stack` dari `control/workspace.yaml`.
```

Replace with:

```
Baca `control/features/<fitur>/feature.yaml` (harus `status: active`, + field `sensitivity`), `business.md`, `fanout.md`, `plans/*`. Tentukan app yang kena dari `fanout.md` + `path`/`stack` dari `control/workspace.yaml`.
```

- [ ] **Step 2: Tambah item keamanan ke Challenge Checklist (step 4)**

Find (persis):

```
- Ada langkah `manual:` (`tasks.yaml`) yang belum dikonfirmasi beres? (env/secret/OAuth app prod)
```

Replace with:

```
- Ada langkah `manual:` (`tasks.yaml`) yang belum dikonfirmasi beres? (env/secret/OAuth app prod)
- Ada temuan dari Security & Compliance Gate (step 4.5) yang belum kelar? (secret/PII/PCI/authz/webhook-signature)
```

- [ ] **Step 3: Sisip langkah 4.5 antara step 4 (Challenge Checklist) dan step 5 (Putuskan)**

Find (persis — akhir step 4, awal step 5):

```
### 5. Putuskan
- **Semua hijau →** lanjut Step 6.
```

Replace with:

```
### 4.5 Security & Compliance Gate (STOP-on-fail, sebobot quality gate)
Berskala ke `feature.yaml` `sensitivity` (baca di step 1):
- **`sensitivity` kosong →** quick scan murah: grep diff fitur untuk secret hardcoded (API key/token/password/connstring di luar env) + PII di log. Temuan → angkat ke Putuskan.
- **`sensitivity` memuat `payments`/`pii` →** invoke subagent **`security-critic`** atas diff penuh (lintas repo yang kena, path/SHA dari code-review step 2) + `control/invariants.md`. Temuan **severity high** = **RED**.
Disisipkan di sini (desimal 4.5) supaya tak me-renumber Step 5/6 & cross-ref internal "lanjut Step 6" tetap valid.

### 5. Putuskan
- **Semua hijau (termasuk Security Gate) →** lanjut Step 6.
```

- [ ] **Step 4: Verifikasi edits + renumber-cross-ref (KRITIS)**

Run:
```bash
grep -q '### 4.5 Security & Compliance Gate' plugin/skills/ship/SKILL.md && echo "step 4.5 OK"
grep -q 'invoke subagent \*\*`security-critic`' plugin/skills/ship/SKILL.md && echo "security-critic invoked OK"
grep -q '+ field `sensitivity`' plugin/skills/ship/SKILL.md && echo "reads sensitivity OK"
# KRITIS (bug renumber 5520de5): "lanjut Step 6" harus masih valid; Step 6 = Kirim & tandai
grep -q 'lanjut Step 6' plugin/skills/ship/SKILL.md && grep -q '### 6. Kirim & tandai' plugin/skills/ship/SKILL.md && echo "cross-ref Step 6 still valid OK"
grep -q '### 5. Putuskan' plugin/skills/ship/SKILL.md && echo "step 5 intact OK"
grep -c '^---$' plugin/skills/ship/SKILL.md   # expect: 2
```
Expected: semua baris `OK` + `2`.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/ship/SKILL.md
git commit -m "feat(ship): Security & Compliance Gate (step 4.5, scaled by sensitivity, STOP-on-fail)"
```

---

## Task 9: M2 — item challenge invarian di `plan`/`breakdown`/`build`

**Files:**
- Modify: `plugin/skills/plan/SKILL.md` (step 3)
- Modify: `plugin/skills/breakdown/SKILL.md` (step 4 coverage)
- Modify: `plugin/skills/build/SKILL.md` (step 6 gate)

- [ ] **Step 1: `plan` — tambah cek invarian di Challenge teknis**

Find (persis):

```
- **Challenge teknis** sebelum gate: konsistensi dengan konvensi? risiko? cara lebih sederhana?
```

Replace with:

```
- **Challenge teknis** sebelum gate: konsistensi dengan konvensi? risiko? cara lebih sederhana? Apakah plan ini melanggar invarian yang terkunci di `control/invariants.md` (tenancy/money/idempotency/authz/PII-PCI)?
```

- [ ] **Step 2: `breakdown` — tambah cek invarian di Coverage check**

Find (persis):

```
- **Task integrasi:** untuk tiap dependency lintas-app di `_shared.md`/`fanout.md`, munculkan satu task `app: integration` (`deps` ke KEDUA sisi, `test` = roundtrip end-to-end). Fitur 1-app tanpa `_shared.md` → skip.
```

Replace with:

```
- **Task integrasi:** untuk tiap dependency lintas-app di `_shared.md`/`fanout.md`, munculkan satu task `app: integration` (`deps` ke KEDUA sisi, `test` = roundtrip end-to-end). Fitur 1-app tanpa `_shared.md` → skip.
- **Invarian:** tiap task yang nyentuh skema/endpoint patuh `control/invariants.md` (mis. table baru bawa `tenant_id` bila tenancy shared-db; uang pakai representasi yang dikunci)? Tandai task yang berisiko melanggar.
```

- [ ] **Step 3: `build` — tambah cek invarian di gate per segmen**

Find (persis):

```
Semua task satu segmen (default **app × milestone**) `done` → **BERHENTI**: tampilkan diff segmen + hasil test + "dibangun vs task" + **challenge checklist** → minta **approve/revisi**.
```

Replace with:

```
Semua task satu segmen (default **app × milestone**) `done` → **BERHENTI**: tampilkan diff segmen + hasil test + "dibangun vs task" + **challenge checklist** (termasuk: ada yang melanggar invarian terkunci di `control/invariants.md`?) → minta **approve/revisi**.
```

- [ ] **Step 4: Verifikasi ketiga edits + frontmatter**

Run:
```bash
grep -q 'invarian yang terkunci di `control/invariants.md`' plugin/skills/plan/SKILL.md && echo "plan OK"
grep -q '\*\*Invarian:\*\* tiap task yang nyentuh skema' plugin/skills/breakdown/SKILL.md && echo "breakdown OK"
grep -q 'melanggar invarian terkunci di `control/invariants.md`' plugin/skills/build/SKILL.md && echo "build OK"
for f in plan breakdown build; do grep -c '^---$' plugin/skills/$f/SKILL.md; done   # expect: 2 2 2
```
Expected: `plan OK` / `breakdown OK` / `build OK` / `2` / `2` / `2`.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/plan/SKILL.md plugin/skills/breakdown/SKILL.md plugin/skills/build/SKILL.md
git commit -m "feat(plan,breakdown,build): challenge item binding tasks to control/invariants.md"
```

---

## Task 10: Doc-consistency — `add-app` note + README + plugin.json

**Files:**
- Modify: `plugin/skills/add-app/SKILL.md` (Catatan)
- Modify: `README.md`
- Modify: `plugin/.claude-plugin/plugin.json`

- [ ] **Step 1: `add-app` — catatan invarian tak di-relock**

Find (persis — bullet keempat Catatan add-app):

```
- **Multi-repo:** `add-app` cuma nyatet `path` + `repo_url`. Pembuatan repo fisik (git init/remote) di-defer ke `wire` + user (gated) — repo app tidak dikelola hub.
```

Replace with:

```
- **Multi-repo:** `add-app` cuma nyatet `path` + `repo_url`. Pembuatan repo fisik (git init/remote) di-defer ke `wire` + user (gated) — repo app tidak dikelola hub.
- **Invarian platform tak di-relock.** `architect` (langkah 4) yang dipanggil `add-app` hanya set `stack` app baru + konfirmasi `invariants.md` yang sudah resolved — invarian level-produk dikunci sekali, bukan per app baru.
```

- [ ] **Step 2: README — sebut invarian di `/architect` + security gate di `/ship`**

Find (persis):

```
/architect          # tetapkan stack (greenfield) / rekam stack+capabilities (brownfield) + konvensi
```

Replace with:

```
/architect          # tetapkan stack (greenfield) / rekam stack+capabilities (brownfield) + konvensi + kunci invarian platform
```

Then find (persis):

```
/ship <fitur>       # finishing: review + quality + cek alignment ke business -> PR -> tandai shipped
```

Replace with:

```
/ship <fitur>       # finishing: review + quality + security gate (sensitivity-scaled) + cek alignment ke business -> PR -> tandai shipped
```

- [ ] **Step 3: plugin.json — sebut invarian + security gate di description**

Find (persis):

```
  "description": "AI-first product boilerplate: lapisan AI + knowledge untuk mengelola produk multi-app (init, architect + wire bring-up, add-app nambah app baru, feature pipeline, breakdown/build dengan actions/manual + integrasi cross-app + multi-repo aware, ship/drop, docs).",
```

Replace with:

```
  "description": "AI-first product boilerplate: lapisan AI + knowledge untuk mengelola produk multi-app (init, architect + kunci invarian platform + wire bring-up, add-app nambah app baru, feature pipeline, breakdown/build dengan actions/manual + integrasi cross-app + multi-repo aware, ship dengan security gate/drop, docs).",
```

- [ ] **Step 4: Verifikasi (termasuk JSON valid)**

Run:
```bash
grep -q 'kunci invarian platform' README.md && echo "README architect OK"
grep -q 'security gate (sensitivity-scaled)' README.md && echo "README ship OK"
grep -q 'Invarian platform tak di-relock' plugin/skills/add-app/SKILL.md && echo "add-app note OK"
python3 -c "import json; json.load(open('plugin/.claude-plugin/plugin.json')); print('plugin.json valid JSON OK')" \
  || echo "FAIL: plugin.json invalid JSON — fix before commit"
```
Expected: `README architect OK` / `README ship OK` / `add-app note OK` / `plugin.json valid JSON OK`.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/add-app/SKILL.md README.md plugin/.claude-plugin/plugin.json
git commit -m "docs: mention platform invariants + security gate (add-app/README/plugin.json)"
```

---

## Task 11: Amandemen spec induk

**Files:**
- Modify: `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§7, §9, §10, §17)

- [ ] **Step 1: §7 — tambah `invariants.md` ke pohon `control/`**

Find (persis):

```
├── conventions.md        # konvensi & kontrak teknis lintas-app
```

Replace with:

```
├── conventions.md        # konvensi & kontrak teknis lintas-app
├── invariants.md         # invarian platform (tenancy/money/idempotency/authz/PII-PCI/rate-limit; dikunci architect)
```

- [ ] **Step 2: §9 `architect` Output — tambah invariants.md**

Find (persis):

```
- **Output:** `workspace.yaml` (stack + capabilities) + `conventions.md`.
```

Replace with:

```
- **Output:** `workspace.yaml` (stack + capabilities) + `conventions.md` + `invariants.md` (invarian platform dikunci sekali, gated, `critic` wajib — sebelum `wire`).
```

- [ ] **Step 3: §9 `ship` — tambah Security & Compliance Gate ke daftar langkah**

Find (persis):

```
  2. **Quality gate** — test, lint, typecheck, build.
```

Replace with:

```
  2. **Quality gate** — test, lint, typecheck, build.
  2.5. **Security & Compliance gate** — berskala ke `sensitivity` fitur; `payments`/`pii` → subagent `security-critic` red-team diff (secret/PII/PCI/authz/webhook); temuan high → STOP.
```

- [ ] **Step 4: §10 — sebut `security-critic`**

Find (persis):

```
Agent terpisah (konteks sendiri) yang tugasnya **mencari celah/bentrok/blind-spot**. Dipanggil di gate penting (`intake` untuk keputusan fondasi, `ship` untuk business alignment). Mengembalikan daftar keberatan; agent utama wajib menanggapi sebelum gate lewat. Pemisahan ini menghilangkan bias "yang mengusulkan = yang menilai".
```

Replace with:

```
Agent terpisah (konteks sendiri) yang tugasnya **mencari celah/bentrok/blind-spot**. Dipanggil di gate penting (`intake` untuk keputusan fondasi, `architect` untuk kunci invarian, `ship` untuk business alignment). Mengembalikan daftar keberatan; agent utama wajib menanggapi sebelum gate lewat. Pemisahan ini menghilangkan bias "yang mengusulkan = yang menilai".

Agent kedua **`security-critic`** (read-only, konteks sendiri): dipanggil `ship` di Security & Compliance Gate untuk fitur ber-`sensitivity` — red-team DIFF mencari kerentanan (secret/PII/PCI/authz-tenant/webhook-signature/input). Sama prinsipnya: penilai ≠ pengusul.
```

- [ ] **Step 5: §17 — Agent (1→2) + Knowledge tambah invariants.md**

Find (persis):

```
- **Agent:** `critic`
- **Rules:** `anti-yes-man.md`
- **Knowledge (`control/`):** `workspace.yaml` · `business/` · `conventions.md` · `features/` · `docs/`
```

Replace with:

```
- **Agent:** `critic` · `security-critic`
- **Rules:** `anti-yes-man.md`
- **Knowledge (`control/`):** `workspace.yaml` · `business/` · `conventions.md` · `invariants.md` · `features/` · `docs/`
```

- [ ] **Step 6: Verifikasi semua amandemen**

Run:
```bash
spec=docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
grep -q 'invariants.md         # invarian platform' "$spec" && echo "§7 tree OK"
grep -q "conventions.md\` + \`invariants.md\`" "$spec" && echo "§9 architect OK"
grep -q '2.5. \*\*Security & Compliance gate' "$spec" && echo "§9 ship OK"
grep -q 'Agent kedua \*\*`security-critic`' "$spec" && echo "§10 OK"
grep -q 'Agent:\*\* `critic` · `security-critic`' "$spec" && echo "§17 agent OK"
grep -q "conventions.md\` · \`invariants.md\`" "$spec" && echo "§17 knowledge OK"
```
Expected: 6 baris `OK`.

- [ ] **Step 7: Commit**

```bash
git add docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
git commit -m "docs(spec): record invariants.md + security-critic in parent design (§7/§9/§10/§17)"
```

---

## Task 12: Sweep konsistensi akhir + renumber-cross-ref audit

**Files:** (verifikasi lintas-file; tak ada konten baru)

- [ ] **Step 1: Grep-battery konsistensi global**

Run:
```bash
echo "== invariants.md disebut di skill yang seharusnya =="
for f in architect wire intake plan breakdown build ship add-app; do
  grep -lq 'invariants.md' plugin/skills/$f/SKILL.md && echo "$f references invariants.md" || echo "MISSING: $f"
done
echo "== security-critic disebut di ship + spec =="
grep -lq 'security-critic' plugin/skills/ship/SKILL.md && echo "ship OK"
grep -lq 'security-critic' plugin/agents/security-critic.md && echo "agent OK"
echo "== guard: TAK ADA pointer ke artifact fiktif (Langkah 2) =="
grep -rn 'packages\[\]\|data-model.md\|roadmap.yaml\|add-package' plugin/ && echo "FAIL: found Langkah-2 artifact reference" || echo "OK: no fictional-artifact pointers"
```
Expected: `architect/wire/intake/plan/breakdown/build/ship/add-app` semua "references invariants.md"; `ship OK`/`agent OK`; `OK: no fictional-artifact pointers`.

- [ ] **Step 2: Frontmatter lint semua file yang diedit/dibuat**

Run:
```bash
for f in plugin/skills/architect plugin/skills/wire plugin/skills/intake plugin/skills/feature \
         plugin/skills/plan plugin/skills/breakdown plugin/skills/build plugin/skills/ship \
         plugin/skills/init plugin/skills/add-app; do
  [ "$(grep -c '^---$' $f/SKILL.md)" = "2" ] && echo "$f frontmatter OK" || echo "FAIL: $f frontmatter"
done
[ "$(grep -c '^---$' plugin/agents/security-critic.md)" = "2" ] && echo "security-critic frontmatter OK" || echo "FAIL: security-critic"
```
Expected: semua `frontmatter OK`.

- [ ] **Step 3: Renumber-cross-ref audit (bug 5520de5) — KRITIS**

Verifikasi MANUAL (baca, jangan cuma grep): di `plugin/skills/ship/SKILL.md`, sisipan langkah 4.5 TIDAK boleh memecah cross-ref "lanjut Step 6" — pastikan Step 6 masih heading "Kirim & tandai". Di `plugin/skills/architect/SKILL.md`, sisipan 4.5 TIDAK me-renumber Step 5/6.

Run (sanity):
```bash
grep -n '### [0-9]' plugin/skills/ship/SKILL.md
grep -n 'lanjut Step' plugin/skills/ship/SKILL.md
grep -n '### [0-9]' plugin/skills/architect/SKILL.md
```
Cek mata: urutan heading `ship` = 1,2,3,4,4.5,5,6 dan "lanjut Step 6" → Step 6 = "Kirim & tandai". `architect` = 1,2,3a,3b,4,4.5,5,6.

- [ ] **Step 4: Dry-run reasoning (tulis ke output, tak ada file berubah)**

Telusuri mental & laporkan ke user 4 skenario spec §11.4:
1. `wire` dijalankan, `invariants.md` masih `<belum dikunci>` → step 0 STOP balik architect. (Cek: `wire` step 0 punya klausa `<belum dikunci>` → STOP.)
2. `architect` rerun, invarian sudah resolved → step 4.5 skip-konfirmasi. (Cek: klausa idempotent.)
3. `ship` fitur `sensitivity:[payments]`, ada secret di diff → step 4.5 invoke security-critic → high → Putuskan RED → STOP.
4. `ship` fitur `sensitivity:[]` → step 4.5 quick scan saja, tak panggil security-critic.

- [ ] **Step 5: Commit (kalau ada perbaikan dari sweep) + lapor**

Kalau Step 1-3 nemu masalah, perbaiki di task terkait lalu:
```bash
git add -A && git commit -m "fix: consistency sweep for platform-invariants-security-gate"
```
Kalau bersih, tak perlu commit. Lapor ringkasan sweep ke user.

---

## Self-Review (penulis plan — sudah dijalankan)

**1. Spec coverage:** H1 → Task 1/2/3/4 (invariants.md + init + architect 4.5 + wire prereq). H4 → Task 5/6/7/8 (security-critic + feature.yaml + intake propose + ship 4.5). M2 → Task 9. Doc/spec coherence → Task 10/11. Verifikasi → Task 12. Semua §9 permukaan-integrasi ke-cover; `render-docs` sengaja di-defer (spec §9 "opsional"). ✓

**2. Placeholder scan:** Tak ada TBD/TODO; semua find/replace berisi teks eksak; `<belum dikunci>`/`<PRODUCT>`/`<YYYY-MM-DD>` = placeholder template yang disengaja. ✓

**3. Type/nama consistency:** `sensitivity` (bukan `sensitivities`) konsisten Task 6/7/8/11. `security-critic` (hyphen) konsisten Task 5/8/11/12. `invariants.md` (plural file) + slot `<belum dikunci>` konsisten lintas task. Langkah desimal `4.5` konsisten architect & ship. ✓

**4. Urutan dependency:** Task 1 (artifact) sebelum yang baca; Task 5 (agent) sebelum Task 8 (yang invoke); Task 11 (spec) setelah implementasi nyata; Task 12 sweep terakhir. ✓

**Caveat dijaga:** Task 9 sengaja TANPA klausa "mandatory package" (butuh H2/Langkah 2); Task 12 Step 1 punya guard yang FAIL kalau ada pointer ke `packages[]`/`add-package`/`data-model.md`/`roadmap.yaml`.
