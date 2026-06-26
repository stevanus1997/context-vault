# Pintu Mockup buat `/fix` — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tambah jalur mockup ke lane `fix` (paritas `plan→build`) — post-ship intake penuh (bawa/generate/degrade) + in-flight re-attach — supaya bug visual bisa disodorin mockup target.

**Architecture:** Sisi authoring saja. Engine `build` sudah generik atas `mockup:` (`build/reference.md §B` baca+reproduksi; `kind: fix` cuma metadata; gate segmen eyeball) → eksekusi + verifikasi visual datang gratis. `fix` cuma perlu pintu yang ngisi field `mockup:` di fix-task, dengan mekanik 3-jalur **dipinjam dari `plan` by-reference** (pola identik "mesin eksekusi dipinjam `build`").

**Tech Stack:** Markdown prompt-spec (skill files context-vault). Tak ada kode runtime; "test" = assertion struktural (grep/cross-ref resolve) + walkthrough eval-scenario.

## Global Constraints

- **`plan`, `build`, `breakdown`, `design-system`, `tweak` TIDAK disentuh.** Blast radius hanya `plugin/skills/fix/reference.md` + `plugin/skills/fix/SKILL.md` (+ version bump release di Task 5).
- **`fix` TAK PERNAH menulis UI-Contract** — `plan` pemilik tunggal (single-writer). `fix` reuse read-only dari `control/features/<fitur>/plans/<app>.md`.
- **Pinjam by-reference, bukan duplikat** — `fix/reference.md §F` menunjuk `plan/reference.md §B–§E`, hanya menulis delta fix.
- **Bahasa Indonesia**, samakan voice file skill existing (imperatif ringkas, `§` untuk section, `${CLAUDE_PLUGIN_ROOT}/...` untuk path skill).
- **Field `mockup:` opsional** — diisi HANYA saat triage menandai `visual-defect`. Jalur degrade (mayoritas fix) = `mockup:` kosong → nol regresi.
- Path skill di-reference pakai bentuk `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/reference.md §X` (cermin baris 3 & 10 file existing).

---

### Task 1: Field `mockup:` di skema fix-task (`fix/reference.md §B`)

**Files:**
- Modify: `plugin/skills/fix/reference.md` (blok YAML §B baris 31-42 + prosa baris 44)

**Interfaces:**
- Consumes: — (titik mulai)
- Produces: field task **`mockup:`** (string pointer ke file mockup, ATAU kosong) — dipakai §F (Task 2) sebagai output, dan SKILL.md (Task 3) saat nulis fix-task.

- [ ] **Step 1: Tulis assertion (grep) — pastikan field belum ada**

Run: `grep -n "mockup" plugin/skills/fix/reference.md`
Expected: **nol baris** (field belum ada — ini state "merah").

- [ ] **Step 2: Tambah field `mockup:` ke blok YAML skema**

Edit `plugin/skills/fix/reference.md`, ganti exact:

```
  test: ["<kasus regresi yang harus lulus>"]
  deps: []
```

jadi:

```
  test: ["<kasus regresi yang harus lulus>"]
  mockup: <path ke control/fixes/<id>/mockups/ ATAU control/features/<fitur>/mockups/ — ATAU kosong>   # OPSIONAL; diisi HANYA saat visual-defect (§F)
  deps: []
```

- [ ] **Step 3: Update prosa pasca-blok — `mockup:` bukan metadata pasif**

Edit `plugin/skills/fix/reference.md`, ganti exact:

```
`build` memperlakukan `kind`/`corrects`/`observed` sebagai **metadata** (traceability) — tidak mengubah eksekusi.
```

jadi:

```
`build` memperlakukan `kind`/`corrects`/`observed` sebagai **metadata** (traceability) — tidak mengubah eksekusi. Field **`mockup:`** (opsional, hanya saat visual-defect — §F) **bukan** metadata pasif: `build` menelannya generik (`${CLAUDE_PLUGIN_ROOT}/skills/build/reference.md` §B) → reproduksi-visual + gate eyeball + bobot-3 + model terkuat, **tanpa** perubahan `build`.
```

- [ ] **Step 4: Run assertion — field sekarang ada (3 rujukan)**

Run: `grep -n "mockup" plugin/skills/fix/reference.md`
Expected: **2 baris** — (a) field `mockup:` di blok YAML (komentar `visual-defect` di baris yang sama), (b) prosa "`mockup:` ... bukan metadata pasif". (state "hijau").

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/fix/reference.md
git commit -m "feat(fix): field mockup: opsional di skema fix-task (§B)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Section baru `fix/reference.md §F` — Pintu Mockup

**Files:**
- Modify: `plugin/skills/fix/reference.md` (append section §F setelah §E, akhir file)

**Interfaces:**
- Consumes: field `mockup:` (Task 1); section `plan/reference.md §B/§C/§D/§E` (existing — 3-jalur/cross-check/generate/round-trip).
- Produces: section **`§F`** (trigger visual-defect + 3-jalur by-reference + Delta-1/2/3 + Guard) — di-reference SKILL.md (Task 3).

- [ ] **Step 1: Assertion — verifikasi section sumber di `plan` ADA (prasyarat by-reference)**

Run: `grep -nE "^## (B|C|D|E)\." plugin/skills/plan/reference.md`
Expected: 4 baris — `## B. Slot ...Mockup... 3 jalur`, `## C. Cross-check ...`, `## D. Generate ...frontend-design...`, `## E. Round-trip ...`. (Kalau meleset, STOP — referensi by-reference tak valid.)

- [ ] **Step 2: Assertion — §F belum ada**

Run: `grep -n "^## F\." plugin/skills/fix/reference.md`
Expected: **nol baris** (state "merah").

- [ ] **Step 3: Append section §F**

Edit `plugin/skills/fix/reference.md`, ganti exact (baris terakhir file, akhir §E):

```
Triage/investigasi = bukan-bug / wontfix / duplikat → `fix` **self-set** `fix.yaml` `status: dropped` + isi `reason`, folder dikeep (memori). **JANGAN** panggil skill `drop` (itu khusus fitur — asumsi `feature.yaml`/promosi capability yang tak relevan untuk fix).
```

jadi (tambah §F sesudahnya):

```
Triage/investigasi = bukan-bug / wontfix / duplikat → `fix` **self-set** `fix.yaml` `status: dropped` + isi `reason`, folder dikeep (memori). **JANGAN** panggil skill `drop` (itu khusus fitur — asumsi `feature.yaml`/promosi capability yang tak relevan untuk fix).

## F. Pintu Mockup (defect visual) — pinjam `plan` by-reference

Berlaku **HANYA** saat triage menandai **`visual-defect`** (§D + `SKILL.md §1`): `units` ∈ peran-UI (`fe`/`fullstack`-UI per `control/workspace.yaml`) **DAN** gejala/root-cause bersifat visual (layout · spacing · style · animasi · state-render tak muncul). Bug logika di app UI → pintu **TUTUP** (lewati §F, `mockup:` kosong). Ambigu → tanya 1× (`${CLAUDE_PLUGIN_ROOT}/rules/elicitation.md`).

**Mekanik 3-jalur DIPINJAM dari `plan`** (persis pola "mesin eksekusi dipinjam `build`", baris 3): ikuti `${CLAUDE_PLUGIN_ROOT}/skills/plan/reference.md` **§B** (bawa / generate / degrade), **§C** (cross-check advisory, opacity terjaga), **§D** (dispatch `frontend-design` untuk jalur generate), **§E** (round-trip "design sendiri"). `fix` **tak menyalin** mekanik itu — hanya menulis **delta** di bawah.

**Delta-1 — UI-Contract (READ-ONLY).** Reuse dari `control/features/<fitur>/plans/<app>.md` (persist setelah ship; `fix` post-ship sudah baca artifact folder fitur). `fix` **TAK PERNAH** menulis UI-Contract — `plan` tetap pemilik tunggal (single-writer).
- UI-Contract **absen** (fitur lama ambil degrade / bug tanpa-fitur `relates_to: []`) **dan** pilih **generate** → turunkan UI-Contract **sekali-pakai inline** (judgment konduktor dari `business.md` + Model/Schema bila ada) semata sebagai input generate; **JANGAN persist**.
- UI-Contract **absen** **dan** pilih **bawa** → cross-check turun jadi murni konfirmasi-manusia (`plan/reference.md §C` jalur non-teks).

**Delta-2 — lokasi simpan mockup.**
- post-ship (bawa/generate) → `control/fixes/<id>/mockups/` (artifact milik fix, sejajar `fix.yaml`/`notes.md`).
- in-flight, bawa mockup **BARU** → `control/features/<fitur>/mockups/` (in-flight memang menulis ke folder fitur).
- in-flight, **RE-ATTACH** mockup existing → set `mockup:` menunjuk file existing di `control/features/<fitur>/mockups/<file>` (read-only, **tanpa menyalin**). Bila file sudah tak ada → **palang fidelitas path** (sejajar cek path `breakdown`): minta koreksi, jangan tulis pointer hantu yang gagal telat di `build`.

**Delta-3 — output.** Isi pointer `mockup:` pada fix-task (§B). `build` menelan `mockup:` generik (`${CLAUDE_PLUGIN_ROOT}/skills/build/reference.md` §B) + memperlakukan `kind: fix` sebagai metadata → reproduksi-visual + gate eyeball + bobot-3 + model terkuat **datang dari `build`** (nol perubahan `build`).

**Guard anti-backdoor.** Cross-check (`plan §C`) = early-warning: bila mockup memperkenalkan **field/action/state BARU** di luar UI-Contract → sinyal **requirement baru**, bukan defect → kena **tripwire** (§D: butuh capability/unit/vendor baru) → STOP → `/feature`. Pintu mockup **BUKAN** pintu belakang menambah scope UI.
```

- [ ] **Step 4: Assertion — §F + semua rujukan ada**

Run: `grep -nE "^## F\.|plan/reference.md|Delta-[123]|Guard anti-backdoor|visual-defect" plugin/skills/fix/reference.md`
Expected: baris `## F.`, ≥1 rujukan `plan/reference.md`, `Delta-1`, `Delta-2`, `Delta-3`, `Guard anti-backdoor`, `visual-defect` — semua tampil. (state "hijau").

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/fix/reference.md
git commit -m "feat(fix): section §F Pintu Mockup — 3-jalur pinjam plan by-reference

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Wire §F ke dua flow (`fix/SKILL.md`)

**Files:**
- Modify: `plugin/skills/fix/SKILL.md` (§1 triage tag; §2 langkah 2.5; §3 langkah 4.5; §3 langkah 7 catatan verify)

**Interfaces:**
- Consumes: section `reference.md §F` (Task 2); field `mockup:` (Task 1).
- Produces: — (titik konsumsi akhir; tak ada task hilir selain validasi).

- [ ] **Step 1: Assertion — wiring belum ada**

Run: `grep -nE "visual-defect|Pintu Mockup|2\.5\.|4\.5\." plugin/skills/fix/SKILL.md`
Expected: **nol baris** (state "merah").

- [ ] **Step 2: §1 — tambah sub-tag `visual-defect` sebelum paragraf Debt-aware**

Edit `plugin/skills/fix/SKILL.md`, ganti exact:

```
**Debt-aware (utang teknis di area bug).**
```

jadi:

```
**Visual-defect (sub-tag pada cabang "kode salah").** Bila triage memilih *kode salah* DAN `units` ∈ peran-UI (`fe`/`fullstack`-UI) DAN gejala/root-cause visual (layout/spacing/style/animasi/state-render) → tandai **`visual-defect`** → pintu mockup terbuka (reference §F: bawa/generate/degrade). Bug logika di app UI → tag tak diset (pintu tutup). Ambigu → tanya 1× (`${CLAUDE_PLUGIN_ROOT}/rules/elicitation.md`).

**Debt-aware (utang teknis di area bug).**
```

- [ ] **Step 3: §2 in-flight — sisip langkah 2.5 setelah root-cause**

Edit `plugin/skills/fix/SKILL.md`, ganti exact:

```
2. **Root-cause (subagent, `systematic-debugging`)** — akar penyimpangan (reference §C.2).
3. **Append corrective task**
```

jadi:

```
2. **Root-cause (subagent, `systematic-debugging`)** — akar penyimpangan (reference §C.2).
2.5. **(bila `visual-defect`) Pintu Mockup** — reference §F: bawa/generate/degrade → set `mockup:` pada corrective task (langkah 3). Mockup baru → simpan `control/features/<fitur>/mockups/`; meleset-dari-mockup-existing → re-attach pointer file existing.
3. **Append corrective task**
```

- [ ] **Step 4: §3 post-ship — sisip langkah 4.5 setelah root-cause**

Edit `plugin/skills/fix/SKILL.md`, ganti exact:

```
4. **Root-cause (subagent, `systematic-debugging`)** — isi `root_cause` → `status: diagnosed` (reference §C.2). Bila ungkap doc salah → cabang koreksi knowledge (reference §D.3).
5. **Tulis fix-task**
```

jadi:

```
4. **Root-cause (subagent, `systematic-debugging`)** — isi `root_cause` → `status: diagnosed` (reference §C.2). Bila ungkap doc salah → cabang koreksi knowledge (reference §D.3).
4.5. **(bila `visual-defect`) Pintu Mockup** — reference §F: bawa/generate/degrade → simpan ke `control/fixes/<id>/mockups/` → set `mockup:` pada fix-task (langkah 5). Gate eyeball (jalur generate) = `plan/reference.md §D`.
5. **Tulis fix-task**
```

- [ ] **Step 5: §3 langkah 7 — catatan verifikasi visual gratis dari `build`**

Edit `plugin/skills/fix/SKILL.md`, ganti exact:

```
7. **Verify lokal + STOP** — quality (test/lint/typecheck/build) ijo → **STOP, "siap di-`ship`"**. `/ship <fix>` dijalankan TERPISAH (boleh nawarin "lanjut ship?", default STOP). Picu `render-docs` saat status berubah (`open`/`diagnosed`→ Known Issues tampil/ter-update).
```

jadi (tambah kalimat di akhir):

```
7. **Verify lokal + STOP** — quality (test/lint/typecheck/build) ijo → **STOP, "siap di-`ship`"**. `/ship <fix>` dijalankan TERPISAH (boleh nawarin "lanjut ship?", default STOP). Picu `render-docs` saat status berubah (`open`/`diagnosed`→ Known Issues tampil/ter-update). Reproduksi visual task ber-`mockup:` sudah ter-verifikasi gate segmen `build` (eyeball mockup-vs-render) — **tak ada gate visual baru** di sini.
```

- [ ] **Step 6: Run assertion — semua wiring tampil**

Run: `grep -nE "visual-defect|Pintu Mockup|2\.5\.|4\.5\.|tak ada gate visual baru" plugin/skills/fix/SKILL.md`
Expected: **4 baris unik** — sub-tag visual-defect (§1), langkah 2.5 (§2), langkah 4.5 (§3), catatan verify §7. (Beberapa baris cocok >1 alternatif — yang penting keempat titik wiring tampil.) (state "hijau").

- [ ] **Step 7: Commit**

```bash
git add plugin/skills/fix/SKILL.md
git commit -m "feat(fix): wire pintu mockup ke triage + flow in-flight/post-ship

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Validasi — integritas cross-ref + walkthrough eval-scenario

**Files:**
- (verification-only — tak ada file diubah; gate reviewer)

**Interfaces:**
- Consumes: hasil Task 1–3.
- Produces: bukti validasi (ditampilkan di gate; tak ada commit).

- [ ] **Step 1: Integritas cross-ref — tiap §F resolve, tiap plan §B–§E ada**

Run:
```bash
echo "--- SKILL.md merujuk §F ---"; grep -nE "§F|reference §F" plugin/skills/fix/SKILL.md
echo "--- §F ada di reference.md ---"; grep -n "^## F\." plugin/skills/fix/reference.md
echo "--- plan §B–§E target ada ---"; grep -nE "^## (B|C|D|E)\." plugin/skills/plan/reference.md
```
Expected: SKILL.md punya ≥1 rujukan §F; reference.md punya 1 `## F.`; plan/reference.md punya 4 section B/C/D/E. Semua resolve (tak ada rujukan menggantung).

- [ ] **Step 2: Sanity markdown — fence & header seimbang**

Run: `awk '/^```/{n++} END{print "fences:", n, (n%2==0?"OK (genap)":"GANJIL — rusak")}' plugin/skills/fix/reference.md`
Expected: `fences: <genap> OK (genap)` (blok kode YAML/contoh tertutup rapi).

- [ ] **Step 3: Walkthrough eval-scenario (judgment — telusuri teks skill, konfirmasi perilaku)**

Telusuri tiap skenario di teks `fix/SKILL.md` + `§F`, tulis trace 1-baris/skenario:
1. **Post-ship + bawa** (web shipped, "tombol checkout kepotong", bawa HTML) → §1 tandai `visual-defect` → §3 langkah 4.5 simpan `fixes/<id>/mockups/` → `mockup:` keisi → build reproduksi+eyeball. ✅
2. **In-flight + re-attach** (build meleset dari mockup existing) → §2 langkah 2.5 re-attach pointer existing → nol authoring baru. ✅
3. **Bug logika di app UI** ("total diskon salah", fullstack) → §1 tag visual-defect TAK diset → pintu tutup, `mockup:` kosong. ✅
4. **Backdoor scope** (mockup punya field "kupon" di luar UI-Contract) → Guard §F cross-check → tripwire §D → STOP → `/feature`. ✅
5. **Generate tanpa UI-Contract** (bug tanpa-fitur, pilih generate) → §F Delta-1 throwaway-derive inline → `frontend-design` → gate eyeball. ✅

Expected: kelima trace lolos. Bila ada yang gak ke-cover teks → balik ke Task 2/3, perbaiki, ulang.

- [ ] **Step 4: Gate (no commit)** — sajikan bukti Step 1–3 ke reviewer. Tak ada perubahan file → tak ada commit.

---

### Task 5: Release prep — bump versi 0.11.0 → 0.12.0

**Files:**
- Modify: `plugin/.claude-plugin/plugin.json:4` (version) + `:3` (klausa deskripsi fix)
- Modify: `.claude-plugin/marketplace.json:9` + `:16` (version) + `:15` (klausa deskripsi fix)

**Interfaces:**
- Consumes: fitur lengkap (Task 1–4 lolos).
- Produces: manifest ter-bump, siap rilis.

- [ ] **Step 1: Assertion — versi masih 0.11.0 di 3 lokasi**

Run: `grep -rn "0.11.0" plugin/.claude-plugin/plugin.json .claude-plugin/marketplace.json`
Expected: 3 baris (`plugin.json:4`, `marketplace.json:9`, `marketplace.json:16`).

- [ ] **Step 2: Bump `plugin/.claude-plugin/plugin.json`**

Edit, ganti exact `"version": "0.11.0",` jadi `"version": "0.12.0",`.

Lalu tambah klausa fitur — ganti exact:
```
fix (lane bugfix dua-mode: in-flight/post-ship, control/fixes/ first-class),
```
jadi:
```
fix (lane bugfix dua-mode: in-flight/post-ship, control/fixes/ first-class, pintu mockup defect visual),
```

- [ ] **Step 3: Bump `.claude-plugin/marketplace.json` (2 lokasi versi)**

Edit, ganti **kedua** kemunculan `"version": "0.11.0"` jadi `"version": "0.12.0"` (gunakan replace-all; satu di `metadata`, satu di entri `plugins[0]`).

Lalu klausa fitur — ganti exact `lane bugfix fix +` jadi `lane bugfix fix (pintu mockup defect visual) +`.

- [ ] **Step 4: Run assertion — 0.12.0 di 3 lokasi, 0.11.0 hilang**

Run: `grep -rn "0.12.0" plugin/.claude-plugin/plugin.json .claude-plugin/marketplace.json; echo "--- sisa 0.11.0 (harus kosong) ---"; grep -rn "0.11.0" plugin/.claude-plugin/plugin.json .claude-plugin/marketplace.json`
Expected: 3 baris `0.12.0`; bagian sisa `0.11.0` **kosong**.

- [ ] **Step 5: Commit**

```bash
git add plugin/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore(release): bump 0.12.0 — pintu mockup di /fix

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Catatan eksekusi

- **Urutan & deps:** Task 1 → 2 → 3 → 4 → 5 berurutan (tiap task konsumsi output sebelumnya). Task 4 = gate validasi (no-commit); Task 5 = release (boleh ditunda kalau mau rilis batch).
- **Branch:** sudah di `feat/fix-mockup-door` (spec sudah ter-commit di sini). PR & merge = jatah pengguna (jangan auto-PR).
- **Tak ada test runtime** — ini prompt-spec; assertion = grep struktural + walkthrough judgment. Itu disengaja & jujur (bukan TDD kode).
