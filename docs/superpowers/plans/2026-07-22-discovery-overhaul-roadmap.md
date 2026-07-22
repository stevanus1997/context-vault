# Discovery Overhaul + Skill `/roadmap` — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL — Use superpowers:subagent-driven-development (recommended) atau superpowers:executing-plans, task-by-task. Steps pakai checkbox (`- [ ]`). Strategi **ONE-FILE-PER-TASK** (kecuali Task 11 bump rilis 2-file & Task 12 regen): tiap task ngedit SATU file, FIND = teks verbatim disk → REPLACE, commit per task.

**Goal:** Eksekusi spec `docs/superpowers/specs/2026-07-22-discovery-overhaul-roadmap-design.md` — rombak `discovery` (elicit-first + compliance conditional opt-in), skill baru `/roadmap` (ke-25, jembatan konsep→backlog, bayar defer M1), integrasi tipis `feature`/`intake`, registrasi penuh + bump **0.22.0** + regen `plugin-kimi/`.

**Architecture:** Semua deliverable = markdown skill/rules/README + 1 baris bash hook + 2 JSON meta. `roadmap.md` BUKAN template (lahir via skill); status fitur SELALU turunan `features/*/feature.yaml` (nol dual-write); semua pembaca degrade diam-diam bila `roadmap.md`/`risks.md` absen.

**Tech Stack:** Markdown prompt-file. Tak ada kode runtime kecuali `plugin/hooks/auto-title.sh` (whitelist 1 baris). "Test" = grep-battery anchor verification + `tools/tests/build-kimi.test.sh` + coherence read.

## Global Constraints

- **colon-space `: ` HARAM di value YAML** — frontmatter `description:` skill baru & semua sisipan komentar YAML pakai em-dash/kurung. Body markdown & string JSON bebas.
- **byte-trap:** em-dash `—` (U+2014), arrow `→` (U+2192), middot `·` (U+00B7) — COPY verbatim dari blok plan/disk, JANGAN ketik-ulang/normalisasi.
- **Renumber HANYA di `discovery/SKILL.md` Langkah** (disahkan spec §4 — step 1–9 baru). File lain: sisipan murni, JANGAN renumber step/section.
- **FIND unik & verbatim.** Sebelum tiap edit: `grep -Fc "<potongan FIND>" <file>` = 1. Gagal match → STOP, baca file, sesuaikan — jangan ngarang.
- Charter: `roadmap` NOL teknis (stack jatah `architect`); BUKAN dependency-engine (warn 1-hop M1 tetap); `epic` tetap string label; `ship`/`drop`/`upgrade`/`ask`/`render-docs`/template TIDAK disentuh.
- Commit per task, pesan conventional Indonesia, TANPA co-author.

---

## Peta FILE → task (nol tabrakan — tiap file disentuh tepat satu task)

| Task | File | Jenis |
|---|---|---|
| 1 | `plugin/skills/roadmap/SKILL.md` | NEW |
| 2 | `plugin/skills/discovery/SKILL.md` | rombak Langkah (renumber sah) |
| 3 | `plugin/skills/discovery/reference.md` | §A visi + prinsip belah + Risiko conditional; §D langkah 9 |
| 4 | `plugin/rules/elicitation.md` | daftar perujuk |
| 5 | `plugin/rules/compliance-risk.md` | penulis kondisional |
| 6 | `plugin/skills/feature/SKILL.md` | roadmap-aware step 1 |
| 7 | `plugin/skills/intake/SKILL.md` | sizing-check +1 kalimat |
| 8 | `plugin/hooks/auto-title.sh` | whitelist +`roadmap` |
| 9 | `plugin/skills/guide/reference.md` | peta + cheatsheet + katalog |
| 10 | `README.md` | 5 edit |
| 11 | `plugin/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` | bump 0.22.0 |
| 12 | `plugin-kimi/` (generated) | regen + test + battery final |

---

### Task 1: Skill baru `plugin/skills/roadmap/SKILL.md`

**Files:**
- Create: `plugin/skills/roadmap/SKILL.md`

**Interfaces:**
- Produces: artifact `control/roadmap.md` (format §Langkah 4 di bawah — dikonsumsi Task 6 `feature` step 1); nama skill `roadmap` (dikonsumsi Task 8 whitelist, Task 9/10 docs, Task 11 description).

- [ ] **Step 1: Tulis file lengkap** (verbatim, perhatikan em-dash & TANPA `: ` di value description):

`````markdown
---
name: roadmap
description: Use untuk menyusun / me-re-plan BACKLOG produk — jembatan konsep→fitur. Q&A gali flow produk + fitur inti (MVP vs nanti) + urutan dependency → tulis control/roadmap.md (penulis tunggal; status fitur TIDAK disimpan — turunan features/*/feature.yaml). Level bisnis murni, NOL teknis. Dipanggil dari ujung discovery (chain), standalone pasca-init, atau re-run kapan pun buat re-plan. Trigger — "roadmap", "susun backlog", "fitur apa dulu", "mulai dari mana", "re-plan backlog". Jalankan dari root produk yang punya control/.
---

# roadmap — Jembatan Konsep → Backlog

Tujuan: mengubah konsep produk jadi backlog fitur terurut yang bisa langsung dikonsumsi `feature` — flow produk + daftar fitur (tujuan · epic · depends_on · target), semua level BISNIS. Penulis tunggal `control/roadmap.md`. Re-runnable kapan pun untuk re-plan.

> Q&A ikuti `${CLAUDE_PLUGIN_ROOT}/rules/elicitation.md` (keputusan-bercabang satu per giliran, opsi bawa konsekuensi). Status fitur TIDAK pernah ditulis ke `roadmap.md` — selalu diturunkan dari `control/features/*/feature.yaml` saat dibaca (nol dual-write).

## Langkah

### 1. Baca konteks
`control/workspace.yaml` (apps + capabilities) + `control/business/*.md` (domain/flows/glossary) + `control/docs/discovery.html` (bila ada — konsep & verdict) + `control/features/*/feature.yaml` (status nyata tiap fitur) + `control/feedback/` (bila ada — sinyal lapangan, input SOFT advisory, cermin intake M8) + `control/roadmap.md` existing (bila re-run). Degrade: sumber absen dilewati diam-diam — produk pasca-init minimal punya `workspace.yaml`.

### 2. Q&A visi & backlog
Ikuti `elicitation.md`. Urutan gali:
1. **Flow pengguna inti** — happy-path dari pengguna datang sampai dapat nilai. Usulkan draft dari `flows.md`/discovery bila ada; operator koreksi.
2. **Kandidat fitur** — usulkan daftar DARI flow itu (tiap langkah flow → kandidat); operator koreksi/tambah/coret. JANGAN mengarang fitur yang tak berakar di flow/visi.
3. **MVP vs nanti** — mana yang WAJIB rilis pertama; sisanya dapat label target bebas (`v1.1`/`nanti`).
4. **Urutan & dependency** — fitur mana butuh fitur mana shipped dulu (1-hop, bahan `depends_on`); kelompokkan yang setema jadi `epic`.

**Re-run (re-plan):** diff-oriented — tampilkan dulu "sejak roadmap terakhir — X shipped, Y dropped, sinyal feedback Z" lalu tanya apa yang berubah (prioritas geser? fitur baru? coret?). BUKAN interogasi ulang dari nol.

### 3. Draft + gate (GATE)
Susun draft `roadmap.md` (format langkah 4) → tampilkan UTUH → minta approve/koreksi. JANGAN tulis sebelum sepakat. Run pertama produk / perombakan besar → invoke subagent `critic` atas draft (fitur bolong? urutan janggal? dependency mustahil? scope MVP melar?) dan tanggapi tiap keberatan bersama operator sebelum lanjut.

### 4. Tulis + promote
Tulis `control/roadmap.md`:
```markdown
# <PRODUCT> — Roadmap
> Ditulis skill roadmap. Status fitur TIDAK disimpan di sini — turunan control/features/*/feature.yaml.

## Flow produk
<jalur pengguna inti, berurutan>

## Backlog terurut
| # | Fitur | Tujuan | Epic | depends_on | Target |
|---|-------|--------|------|------------|--------|

## Catatan prioritas
<alasan urutan/penundaan — opsional>
```
Nama fitur = calon nama folder `features/<fitur>/` (kebab-case). Lalu **promosikan fakta durable** secara idempotent (cermin intake step 7): flow produk → `business/flows.md`; pengguna/nilai yang tergali → `business/domain.md` (perkaya slot Produk/Pengguna/Nilai). Cek dulu apakah fakta serupa sudah ada — update, jangan duplikat.

### 5. Handoff
Sarankan fitur pertama yang belum shipped — "`/feature <fitur#1>`?". Bila dipanggil dari chain discovery (produk belum di-bring-up) → ingatkan `architect` → `wire` dulu sebelum build fitur.

## Catatan
- BUKAN dependency-engine — tak ada topo-sort/cycle-detection; `depends_on` tetap warn 1-hop di `feature` (M1). `epic` tetap string label, bukan entitas.
- `roadmap.md` BUKAN file template — lahir di sini; pembaca (`feature`) degrade diam-diam bila absen.
- Baris roadmap basi (fitur di-drop / prioritas geser) dibereskan re-run skill ini — `ship`/`drop` TIDAK menulis `roadmap.md`.
- NOL teknis — stack/arsitektur jatah `architect`; detail per-fitur jatah `intake`.
`````

- [ ] **Step 2: Verify**

Run: `sed -n 's/^description: //p' plugin/skills/roadmap/SKILL.md | grep -c ': '`
Expected: `0`
Run: `grep -Fc 'turunan control/features/*/feature.yaml' plugin/skills/roadmap/SKILL.md`
Expected: `2` (blockquote + skeleton artifact)
Run: `ls plugin/skills/ | wc -l`
Expected: `25`

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/roadmap/SKILL.md
git commit -m "feat(roadmap): skill baru /roadmap — jembatan konsep→backlog (control/roadmap.md, status turunan, re-runnable; bayar defer M1)"
```

---

### Task 2: Rombak `plugin/skills/discovery/SKILL.md`

**Files:**
- Modify: `plugin/skills/discovery/SKILL.md`

**Urutan sub-step WAJIB bottom-up-dulu** (renumber heading ekor sebelum sisip step baru — jaga FIND unik).

- [ ] **Step 1: Renumber heading ekor (5 FIND/REPLACE, urut ini):**

| FIND (verbatim) | REPLACE |
|---|---|
| `### 7. Sepakat → init + seed (GATE)` | `### 9. Sepakat → init + seed (GATE)` |
| `### 6. Review loop (GATE)` | `### 8. Review loop (GATE)` |
| `### 5. Render HTML (visual-first)` | `### 7. Render HTML (visual-first)` |
| `### 4. critic (GATE)` | `### 6. critic (GATE)` |
| `### 3. Susun draft dok strategis` | `### 5. Susun draft dok strategis` |

- [ ] **Step 2: Ganti blok step 2 lama jadi step 2+3+4 baru.**

FIND (verbatim, 2 baris):
```
### 2. Riset + kembangkan konsep (loop)
Untuk tiap seksi di `reference.md` bagian A (masalah, pengguna, value, pasar, kompetitor, monetisasi, risiko): **riset web dulu** (kompetitor nyata, data pasar), lalu **usulkan draft** ke operator + jelaskan kenapanya. Tiap klaim faktual: catat sumber (URL + tanggal) & beri label keyakinan sesuai `reference.md` bagian B & C. JANGAN mengarang angka/URL.
```
REPLACE:
```
### 2. Q&A visi produk (SEBELUM riset)
Ikuti `${CLAUDE_PLUGIN_ROOT}/rules/elicitation.md` (keputusan-bercabang satu per giliran, opsi bawa konsekuensi). Gali dari operator — masalah versi DIA, siapa penggunanya menurut dia, hasil/nilai yang diincar, batasan/keharusan yang sudah ia tetapkan, gambaran sukses. **Riset web DILARANG di step ini** — ini sesi memahami visi, bukan memvalidasi. Operator menjawab "gak tau/terserah" pada suatu slot → tandai slot itu `AI-usul`, AI yang mengusulkan di step 3. Visi = operator menyetir; JANGAN menimpa jawaban operator dengan usulan riset diam-diam.

### 3. Riset validasi + kembangkan konsep (loop)
Untuk tiap seksi di `reference.md` bagian A selain Visi & Risiko (masalah, pengguna, value, pasar, kompetitor, monetisasi): **riset web dulu** (kompetitor nyata, data pasar), lalu **usulkan draft** ke operator + jelaskan kenapanya — tiap usulan DIIKAT balik ke jawaban visi step 2; slot `AI-usul` diisi penuh oleh AI. Riset bertentangan dengan visi → tunjukkan buktinya, operator yang putuskan (JANGAN menimpa diam-diam). Tiap klaim faktual: catat sumber (URL + tanggal) & beri label keyakinan sesuai `reference.md` bagian B & C. JANGAN mengarang angka/URL.

### 4. Risiko + compliance (conditional)
Risiko BISNIS (pasar jenuh, switching cost, beratnya eksekusi) digali untuk SEMUA produk seperti seksi lain. **Asesmen compliance terstruktur** (PCI/GDPR/pajak/KYC + regulasi sektor — `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`) HANYA bila ide kena heuristik pemicu — menggerakkan/menyimpan uang · PII berat (gov-id/kesehatan/finansial) · sektor regulated (keuangan, kesehatan, pendidikan-anak, dst.) — dan itu pun lewat SATU pertanyaan opt-in ("produk ini kena sinyal <X> — mau kucek kewajiban regulasinya sekali jalan?"). Default/decline → SKIP — seksi Risiko HTML memuat baris "compliance dilewati atas pilihan operator", `risks.md` TIDAK di-seed (skeleton = jalur degrade normal pembaca M6).
```

- [ ] **Step 3: Review loop — target balik.**

FIND: `Bila ada → balik ke langkah 2/3 (riset ulang / tajamkan) → regen HTML.`
REPLACE: `Bila ada → balik ke langkah 2–5 (gali visi ulang / riset ulang / tajamkan) → regen HTML.`

- [ ] **Step 4: Step 9 — framing range, seed risks.md conditional, tawaran /roadmap (3 FIND/REPLACE):**

FIND: `dari langkah 1–3, jadi `init` skip Framing Q&A-nya`
REPLACE: `dari langkah 1–5, jadi `init` skip Framing Q&A-nya`

FIND:
```
**`risks.md`** (kewajiban compliance dari seksi Risiko — `terverifikasi`/`asumsi`+sumber, carve-out M6, lihat `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`; slot tak relevan → `N/A — alasan`)
```
REPLACE:
```
**`risks.md`** (HANYA bila asesmen compliance step 4 dijalankan — kewajiban dari seksi Risiko, `terverifikasi`/`asumsi`+sumber, carve-out M6, lihat `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`; slot tak relevan → `N/A — alasan`; asesmen di-skip → JANGAN seed, biarkan `risks.md` skeleton — jalur degrade normal pembaca M6)
```

FIND: `4. Ringkas hasil + sarankan langkah berikut: `architect` (fondasi teknis).`
REPLACE: `4. Ringkas hasil + **tawarkan chain `/roadmap`** (susun backlog fitur — konteks lagi hangat; boleh skip), lalu sarankan `architect` (fondasi teknis).`

- [ ] **Step 5: Description frontmatter + Catatan (2 FIND/REPLACE):**

FIND: `business consultant pra-init (riset pasar, kompetitor, monetisasi, verdict go/no-go).`
REPLACE: `business consultant pra-init (Q&A visi operator dulu, lalu riset pasar, kompetitor, monetisasi, verdict go/no-go; compliance conditional opt-in).`

FIND: `Berhenti di konsep produk; fitur = jatah `feature`/`intake`.`
REPLACE: `Berhenti di konsep produk; backlog fitur = jatah `roadmap`; detail fitur = jatah `feature`/`intake`.`

- [ ] **Step 6: Verify**

Run: `grep -c '^### ' plugin/skills/discovery/SKILL.md`
Expected: `9`
Run: `grep -Fc 'Riset web DILARANG' plugin/skills/discovery/SKILL.md && grep -Fc 'tawarkan chain `/roadmap`' plugin/skills/discovery/SKILL.md`
Expected: `1` dan `1`
Run: `sed -n 's/^description: //p' plugin/skills/discovery/SKILL.md | grep -c ': '`
Expected: `0`

- [ ] **Step 7: Commit**

```bash
git add plugin/skills/discovery/SKILL.md
git commit -m "feat(discovery): elicit-first — Q&A visi step 2 sebelum riset + compliance conditional opt-in step 4 + tawaran chain /roadmap"
```

---

### Task 3: `plugin/skills/discovery/reference.md`

**Files:**
- Modify: `plugin/skills/discovery/reference.md`

- [ ] **Step 1: Prinsip §A dibelah.**

FIND: `Prinsip: AI **MENYETIR**. Untuk tiap seksi, RISET dulu lalu USULKAN draft ke operator + jelaskan kenapanya — JANGAN tanya kosong ke operator yang bukan orang bisnis.`
REPLACE: `Prinsip dibelah per-ranah. **Visi produk — operator menyetir**: AI menggali & merekam (SKILL.md step 2, TANPA riset); slot yang operator jawab "gak tau" → `AI-usul`. **Riset pasar — AI menyetir**: RISET dulu lalu USULKAN draft + jelaskan kenapanya — JANGAN tanya kosong soal angka pasar ke operator yang bukan orang bisnis, dan JANGAN menimpa visi operator dengan hasil riset diam-diam (konflik → tunjukkan bukti, operator putuskan).`

- [ ] **Step 2: Sisip bullet Visi di atas Masalah.**

FIND: `- **Masalah** — Masalah apa, sakitnya di mana, buat siapa? Riset: apakah masalah ini nyata & dibicarakan (forum, review, artikel)?`
REPLACE:
```
- **Visi (dari operator — SKILL.md step 2, TANPA riset)** — Masalah versi operator, pengguna menurut dia, hasil/nilai yang diincar, batasan/keharusan yang sudah ia tetapkan, gambaran sukses. Sumber = jawaban operator, bukan web.
- **Masalah** — Masalah apa, sakitnya di mana, buat siapa? Riset: apakah masalah ini nyata & dibicarakan (forum, review, artikel)?
```

- [ ] **Step 3: Risiko — compliance conditional.**

FIND: `**Compliance (durable, carve-out ke `risks.md`):** nilai terstruktur kewajiban regulasi`
REPLACE: `**Compliance (durable, carve-out ke `risks.md` — CONDITIONAL opt-in, SKILL.md step 4; heuristik pemicu uang/PII-berat/sektor-regulated + SATU pertanyaan; di-skip → `risks.md` tetap skeleton, degrade M6):** nilai terstruktur kewajiban regulasi`

- [ ] **Step 4: §D — langkah 9 + prasyarat seed (2 FIND/REPLACE):**

FIND: `## D. Yang nyebrang ke business/ (saat seed, langkah 7)`
REPLACE: `## D. Yang nyebrang ke business/ (saat seed, langkah 9)`

FIND: `**Pengecualian compliance (carve-out M6):** kewajiban regulasi`
REPLACE: `**Pengecualian compliance (carve-out M6 — hanya bila asesmen compliance step 4 dijalankan; di-skip → tak ada yang nyebrang, `risks.md` skeleton):** kewajiban regulasi`

- [ ] **Step 5: Verify**

Run: `grep -Fc 'Visi (dari operator' plugin/skills/discovery/reference.md && grep -Fc 'langkah 9' plugin/skills/discovery/reference.md && grep -Fc 'langkah 7' plugin/skills/discovery/reference.md`
Expected: `1`, `1`, `0`

- [ ] **Step 6: Commit**

```bash
git add plugin/skills/discovery/reference.md
git commit -m "docs(discovery): reference — seksi Visi + prinsip MENYETIR dibelah per-ranah + carve-out compliance kondisional (langkah 9)"
```

---

### Task 4: `plugin/rules/elicitation.md`

- [ ] **Step 1:** FIND: `(intake, fanout, plan, tweak, fix). Berlaku` → REPLACE: `(discovery, intake, fanout, plan, tweak, fix, roadmap). Berlaku`

- [ ] **Step 2: Verify** — Run: `grep -Fc '(discovery, intake, fanout, plan, tweak, fix, roadmap)' plugin/rules/elicitation.md` → Expected: `1`

- [ ] **Step 3: Commit**

```bash
git add plugin/rules/elicitation.md
git commit -m "docs(rules): elicitation — wire discovery + roadmap ke daftar perujuk"
```

---

### Task 5: `plugin/rules/compliance-risk.md`

- [ ] **Step 1 (2 FIND/REPLACE):**

FIND: `**penulis** `discovery` (seed carve-out);`
REPLACE: `**penulis** `discovery` (seed carve-out — kondisional opt-in);`

FIND: `Hanya `discovery` yang menulis `risks.md` (seed pra-init).`
REPLACE: `Hanya `discovery` yang menulis `risks.md` (seed pra-init; penulisan KONDISIONAL — opt-in operator di discovery step 4, heuristik pemicu + satu pertanyaan; `risks.md` skeleton/absen = jalur NORMAL, bukan anomali → pembaca pakai Degrade-ke-best-effort di bawah).`

- [ ] **Step 2: Verify** — Run: `grep -Fc 'KONDISIONAL' plugin/rules/compliance-risk.md` → Expected: `1`

- [ ] **Step 3: Commit**

```bash
git add plugin/rules/compliance-risk.md
git commit -m "docs(rules): compliance-risk — penulisan risks.md kondisional (skeleton = jalur normal)"
```

---

### Task 6: `plugin/skills/feature/SKILL.md` — roadmap-aware

**Interfaces:**
- Consumes: format tabel `control/roadmap.md` Task 1 (kolom Fitur/Epic/depends_on) + `status` di `features/*/feature.yaml`.

- [ ] **Step 1: Sisip klausa di awal step 1.**

FIND (2 baris):
```
### 1. Buat folder & status fitur
Buat `control/features/<nama>/feature.yaml`:
```
REPLACE:
```
### 1. Buat folder & status fitur
**Roadmap-aware (bila `control/roadmap.md` ada; absen → skip diam-diam, jalan seperti biasa):** dipanggil TANPA nama fitur → tampilkan backlog + status turunan (baca `status` tiap `features/<fitur>/feature.yaml`; roadmap TIDAK menyimpan status) dan sarankan fitur berikutnya yang belum shipped — operator tetap bebas milih lain. Dipanggil DENGAN nama — nama ada di roadmap → **prefill** `epic`/`depends_on` `feature.yaml` di bawah dari baris roadmap-nya (user konfirmasi di gate intake seperti biasa); tak ada di roadmap → catatan advisory "tak tercatat di roadmap — lanjut saja; re-run `/roadmap` bila mau dicatat", lalu jalan normal. Roadmap = saran, BUKAN palang.

Buat `control/features/<nama>/feature.yaml`:
```

- [ ] **Step 2: Verify** — Run: `grep -Fc 'Roadmap-aware' plugin/skills/feature/SKILL.md` → Expected: `1`; Run: `grep -c 'depends_on: \[\]' plugin/skills/feature/SKILL.md` → Expected: `1` (blok yaml TIDAK berubah)

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/feature/SKILL.md
git commit -m "feat(feature): roadmap-aware step 1 — saran fitur berikutnya + prefill epic/depends_on dari control/roadmap.md (degrade bila absen)"
```

---

### Task 7: `plugin/skills/intake/SKILL.md` — sizing-check +1 kalimat

- [ ] **Step 1:**

FIND: `isi `epic` (pengelompok) + `depends_on` (urutan) di tiap `feature.yaml`. Usulan saja; user putuskan. Tak memblokir.`
REPLACE: `isi `epic` (pengelompok) + `depends_on` (urutan) di tiap `feature.yaml`. Bila usul pecah diterima & `control/roadmap.md` ada → sarankan re-run `/roadmap` supaya pecahan tercatat di backlog (advisory). Usulan saja; user putuskan. Tak memblokir.`

- [ ] **Step 2: Verify** — Run: `grep -Fc 're-run `/roadmap`' plugin/skills/intake/SKILL.md` → Expected: `1`

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/intake/SKILL.md
git commit -m "docs(intake): sizing-check — saran re-run /roadmap saat pecah epik (advisory)"
```

---

### Task 8: `plugin/hooks/auto-title.sh` — whitelist

- [ ] **Step 1:**

FIND: `feature|intake|fanout|plan|breakdown|build|fix|tweak|ship|drop|add-app|add-package|add-integration|init|architect|wire|design-system|extract|upgrade|discovery) ;;`
REPLACE: `feature|intake|fanout|plan|breakdown|build|fix|tweak|ship|drop|add-app|add-package|add-integration|init|architect|wire|design-system|extract|upgrade|discovery|roadmap) ;;`

- [ ] **Step 2: Verify** — Run: `grep -Fc '|roadmap) ;;' plugin/hooks/auto-title.sh` → Expected: `1`; lalu bila ada test hook: `bash plugin/hooks/tests/auto-title.test.sh` → Expected: exit 0, nol FAIL.

- [ ] **Step 3: Commit**

```bash
git add plugin/hooks/auto-title.sh
git commit -m "fix(hooks): auto-title — whitelist skill roadmap (work skill, ikut judul session)"
```

---

### Task 9: `plugin/skills/guide/reference.md`

- [ ] **Step 1: Peta flow (2 FIND/REPLACE blok berpagar — FIND WAJIB include heading biar unik, sebab baris jelas = substring baris mentah):**

FIND:
````
**Greenfield (ide masih mentah):**
```
discovery → init → architect → wire → feature → breakdown → build → ship
```
````
REPLACE:
````
**Greenfield (ide masih mentah):**
```
discovery → init → roadmap? → architect → wire → feature → breakdown → build → ship
```
````

FIND:
````
**Greenfield (ide sudah jelas):**
```
init → architect → wire → feature → breakdown → build → ship
```
````
REPLACE:
````
**Greenfield (ide sudah jelas):**
```
init → roadmap? → architect → wire → feature → breakdown → build → ship
```
````

- [ ] **Step 2: Catatan lane + baris roadmap.**

FIND: ``feature` = konduktor yang menjalankan `intake → fanout → plan`. Lane samping bisa kapan saja: `fix` (bug), `tweak` (perubahan kecil), `debt` (utang teknis), `ask` (tanya produk), `drop` (batalin fitur).`
REPLACE: ``feature` = konduktor yang menjalankan `intake → fanout → plan`. `roadmap?` = opsional — susun/re-plan backlog fitur terurut (`control/roadmap.md`); brownfield pun boleh panggil standalone kapan saja. Lane samping bisa kapan saja: `fix` (bug), `tweak` (perubahan kecil), `debt` (utang teknis), `ask` (tanya produk), `drop` (batalin fitur).`

- [ ] **Step 3: Cheatsheet row.**

FIND: `| Bikin kapabilitas/fitur baru | `/feature` |`
REPLACE:
```
| Susun / re-plan backlog fitur (mulai dari mana) | `/roadmap` |
| Bikin kapabilitas/fitur baru | `/feature` |
```

- [ ] **Step 4: Katalog (2 FIND/REPLACE):**

FIND: `- `/discovery` — validasi ide mentah pra-init: riset pasar/kompetitor/monetisasi + verdict go/no-go, lalu auto lanjut `/init`.`
REPLACE: `- `/discovery` — validasi ide mentah pra-init: Q&A visi operator dulu, baru riset pasar/kompetitor/monetisasi + verdict go/no-go (compliance conditional opt-in), lalu auto lanjut `/init` + tawaran `/roadmap`.`

FIND: `- `/init` — mulai produk baru (greenfield) atau adopsi repo existing (monorepo / multi-repo alias polyrepo) ke context-vault.`
REPLACE:
```
- `/init` — mulai produk baru (greenfield) atau adopsi repo existing (monorepo / multi-repo alias polyrepo) ke context-vault.
- `/roadmap` — (opsional) jembatan konsep→backlog: Q&A flow produk + fitur inti (MVP vs nanti) + urutan → `control/roadmap.md` (fitur · epic · depends_on · target; status turunan `feature.yaml`); re-runnable buat re-plan.
```

- [ ] **Step 5: Verify** — Run: `grep -c 'roadmap' plugin/skills/guide/reference.md` → Expected: `≥6`; Run: `grep -Fc 'roadmap?' plugin/skills/guide/reference.md` → Expected: `3`

- [ ] **Step 6: Commit**

```bash
git add plugin/skills/guide/reference.md
git commit -m "docs(guide): peta flow + cheatsheet + katalog — masuk /roadmap (opsional, re-runnable)"
```

---

### Task 10: `README.md`

- [ ] **Step 1: Baris lanjutan "Mulai produk".**

FIND: `Lalu `architect` (fondasi teknis), `wire` (bring-up skeleton kosong-tapi-jalan), `feature` (bikin fitur), `ship`/`drop` (lifecycle), `render-docs` (doc human-readable).`
REPLACE: `Lalu `roadmap` (opsional — susun backlog fitur), `architect` (fondasi teknis), `wire` (bring-up skeleton kosong-tapi-jalan), `feature` (bikin fitur), `ship`/`drop` (lifecycle), `render-docs` (doc human-readable).`

- [ ] **Step 2: Seksi "Validasi ide" — elicit-first + tawaran roadmap.**

FIND: `Buat ide yang masih mentah. Nol teknis. Output: dok strategis HTML (`control/docs/discovery.html`) + seed awal `control/business/`; di akhir otomatis panggil `/init`.`
REPLACE: `Buat ide yang masih mentah. **Q&A visi operator dulu, baru riset** (elicit-first); asesmen compliance cuma opt-in bila produk kena sinyal regulated (uang/PII berat/sektor). Nol teknis. Output: dok strategis HTML (`control/docs/discovery.html`) + seed awal `control/business/`; di akhir otomatis panggil `/init` + tawarkan `/roadmap`.`

- [ ] **Step 3: Seksi baru "Susun backlog" — sisip SEBELUM `## Fondasi teknis`.**

FIND: `## Fondasi teknis`
REPLACE:
`````
## Susun backlog (opsional)
```
/roadmap            # jembatan konsep→fitur: Q&A flow produk + fitur inti (MVP vs nanti) + urutan → control/roadmap.md
```
Re-runnable kapan pun buat re-plan; status fitur TIDAK disimpan (turunan `features/*/feature.yaml`). `feature` membacanya buat saran fitur berikutnya + prefill `epic`/`depends_on`; tanpa `roadmap.md` semua jalan seperti biasa (degrade).

## Fondasi teknis
`````

- [ ] **Step 4: Urutan lifecycle (2 FIND/REPLACE — brownfield SENGAJA tak diubah):**

FIND: `Urutan greenfield (ide jelas): `/init` -> `/architect` -> `/wire` -> `/feature` -> `/breakdown` -> `/build` -> `/ship`.`
REPLACE: `Urutan greenfield (ide jelas): `/init` -> `/roadmap` (opsional) -> `/architect` -> `/wire` -> `/feature` -> `/breakdown` -> `/build` -> `/ship`.`

FIND: `Urutan greenfield (ide mentah): `/discovery` -> `/init` -> `/architect` -> `/wire` -> `/feature` -> `/breakdown` -> `/build` -> `/ship`.`
REPLACE: `Urutan greenfield (ide mentah): `/discovery` -> `/init` -> `/roadmap` (opsional) -> `/architect` -> `/wire` -> `/feature` -> `/breakdown` -> `/build` -> `/ship`.`

- [ ] **Step 5: Status — append di ujung paragraf.**

FIND: `ditunjuk di README + plugin.json + marketplace sebagai pintu masuk.`
REPLACE: `ditunjuk di README + plugin.json + marketplace sebagai pintu masuk. **Jembatan konsep→backlog (0.22 — bayar defer M1):** `roadmap` — pengampu `control/roadmap.md` (flow produk + backlog terurut fitur·epic·depends_on·target; status TURUNAN `feature.yaml`, nol dual-write); di-chain dari ujung `discovery`, standalone pasca-`init`, re-runnable buat re-plan; `feature` roadmap-aware (saran fitur berikutnya + prefill `epic`/`depends_on`, degrade bila absen). **Discovery elicit-first:** Q&A visi produk (kontrak `elicitation.md`) SEBELUM riset; prinsip MENYETIR dibelah per-ranah (visi=operator, riset=AI); asesmen compliance conditional opt-in (heuristik pemicu + satu pertanyaan; skip → `risks.md` skeleton, degrade M6). Spec: `docs/superpowers/specs/2026-07-22-discovery-overhaul-roadmap-design.md`.`

- [ ] **Step 6: Verify** — Run: `grep -c 'roadmap' README.md` → Expected: `≥8`; Run: `grep -Fc '## Susun backlog (opsional)' README.md` → Expected: `1`

- [ ] **Step 7: Commit**

```bash
git add README.md
git commit -m "docs(readme): seksi /roadmap + urutan lifecycle + discovery elicit-first di Status"
```

---

### Task 11: Bump rilis 0.22.0 (`plugin.json` + `marketplace.json`)

- [ ] **Step 1: `plugin/.claude-plugin/plugin.json` (2 FIND/REPLACE):**

FIND: `tur progresif + tanya skill/flow), init, architect`
REPLACE: `tur progresif + tanya skill/flow), discovery elicit-first (Q&A visi dulu + compliance conditional opt-in), init, roadmap (jembatan konsep→backlog — control/roadmap.md flow produk + backlog terurut epic/depends_on, status turunan feature.yaml, re-runnable re-plan; feature roadmap-aware prefill), architect`

FIND: `"version": "0.21.0",`
REPLACE: `"version": "0.22.0",`

- [ ] **Step 2: `.claude-plugin/marketplace.json` (3 FIND/REPLACE):**

FIND: `+ init→ship + lane bugfix`
REPLACE: `+ init→ship + roadmap jembatan konsep→backlog + discovery elicit-first (compliance conditional) + lane bugfix`

FIND: `"description": "AI-first product boilerplate.",
    "version": "0.21.0"`
REPLACE: `"description": "AI-first product boilerplate.",
    "version": "0.22.0"`

FIND: `AI-first.",
      "version": "0.21.0"`
REPLACE: `AI-first.",
      "version": "0.22.0"`

- [ ] **Step 3: Verify** — Run: `jq -r .version plugin/.claude-plugin/plugin.json` → `0.22.0`; Run: `jq -r '.metadata.version, .plugins[0].version' .claude-plugin/marketplace.json` → `0.22.0` dua baris; Run: `grep -c '0.21.0' plugin/.claude-plugin/plugin.json .claude-plugin/marketplace.json` → `0` keduanya.

- [ ] **Step 4: Commit**

```bash
git add plugin/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore(release): bump 0.22.0 — skill roadmap (jembatan konsep→backlog) + discovery elicit-first"
```

---

### Task 12: Regen `plugin-kimi/` + battery final

- [ ] **Step 1: Regen + test (ritual rilis README).**

Run: `bash tools/build-kimi.sh`
Expected: `[build-kimi] OK — plugin-kimi/ regenerated (25 skills)`
Run: `bash tools/tests/build-kimi.test.sh`
Expected: exit 0, nol `FAIL`

- [ ] **Step 2: Battery koherensi final.**

Run: `grep -rn "langkah 7" plugin/skills/discovery/` → Expected: kosong
Run: `grep -rln "roadmap" plugin/skills/feature/SKILL.md plugin/skills/intake/SKILL.md plugin/skills/guide/reference.md plugin/rules/elicitation.md README.md | wc -l` → Expected: `5`
Run: `grep -rn ": \"" plugin/skills/roadmap/SKILL.md | grep -v description` → sanity frontmatter (kosong)
Run: `git status --porcelain -- plugin/` → Expected: kosong (generator tak nulis ke source)
Coherence read: buka `plugin/skills/discovery/SKILL.md` + `roadmap/SKILL.md` sekali jalan — nomor step nyambung, rujukan silang (step 2/3/4, langkah 9, `/roadmap`) semua nunjuk target benar.

- [ ] **Step 3: Commit**

```bash
git add plugin-kimi/
git commit -m "chore(kimi): regen plugin-kimi 0.22.0 — 25 skills (masuk roadmap + discovery elicit-first)"
```

---

## Skipped sadar (jujur — jangan diam-diam balloon)

- `ask`/`render-docs` roadmap-view — spec §FLAG (kosmetik/defer). `ask` sudah baca `control/` menyeluruh tanpa edit.
- README urutan brownfield & guide peta brownfield TIDAK dapat `roadmap?` — cukup kalimat "brownfield pun boleh panggil standalone" (Task 9 Step 2); jaga baris urutan tetap ringkas.
- Prefill `epic`/`depends_on` jalur intake-dipanggil-langsung — batas sadar spec §6/§FLAG.
- Spec induk §12 TIDAK diedit — spec 2026-07-22 = addendum (pola kimi `72ec743`).
- Pointer lama `(lihat klausa di `init` langkah 3)` di discovery step 9 — pre-existing (framing klausa sebenarnya di init langkah 2), DI LUAR scope; bila mau, FLAG terpisah.
