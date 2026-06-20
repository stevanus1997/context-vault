# Q&A Elicitation & Flow-Awareness pada Pipeline Fitur — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pasang konvensi Q&A sumber-tunggal (`rules/elicitation.md`) + slot `Flow/Skenario` first-class di `business.md`, lalu wiring tipis ke 5 skill Q&A (`intake`, `fanout`, `plan`, `tweak`, `fix`) — agar keputusan yang menyetir hasil diambil sadar oleh user dan flow fitur tak lagi keskip.

**Architecture:** Editan PROMPT/markdown pada skill context-vault (BUKAN kode runtime). Satu file aturan baru jadi sumber kebenaran; skill merujuk via `${CLAUDE_PLUGIN_ROOT}/rules/elicitation.md` (pola identik `anti-yes-man.md`/`debt-aware.md`). `intake` dapat slot Flow + langkah elicit.

**Tech Stack:** Markdown skill files di `/Users/stevanus/Developer/ai-boilerplate/plugin/`. TIDAK ADA runtime/test executable — verifikasi tiap task = (a) `rg` assertion bahwa teks baru hadir di anchor benar (red→green), (b) cek konsistensi lintas-file (path rujukan resolve, tak ada referensi yatim), (c) read-back koheren section + sekitarnya. Git untuk commit per task.

**Spec sumber:** `docs/superpowers/specs/2026-06-20-feature-qna-elicitation-flow-design.md` (commit `5144948`). Branch kerja: `feat/qna-elicitation-flow` (sudah aktif).

## Global Constraints

Setiap task tunduk pada invarian spec §4 (verbatim):
- **Nol palang keras baru.** Semua tambahan = disiplin Q&A + show-at-gate; TIDAK ada STOP/block baru.
- **Sumber-tunggal konvensi.** Isi aturan HANYA di `elicitation.md`; skill MERUJUK, tidak menyalin (hindari drift 5-salinan).
- **Degrade proporsional.** Fitur 1-app/sepele tak diregang jadi banyak giliran.
- **Pertahankan voice + minimalisme.** Editan tipis; SKILL.md tetap ramping. Bahasa Indonesia teknis, istilah teknis Inggris — seperti file sekitarnya.
- **Editan markdown, bukan kode.** "TDD" klasik tak berlaku; verifikasi via grep-assertion + read-back, lalu commit.
- **Triage mekanis tak disentuh.** Routing verba-list `tweak`/`fix` (cabang B/C/A, tabel mode) TETAP mekanis — elicitation hanya di momen klarifikasi ke user.

---

### Task 1: Buat `plugin/rules/elicitation.md` (sumber-tunggal)

**Files:**
- Create: `plugin/rules/elicitation.md`

**Interfaces:**
- Consumes: —
- Produces: file `plugin/rules/elicitation.md` dengan heading `# Elicitation — Aturan Q&A & Penyajian Opsi`, section `## Kontrak` (5 bullet) + `## Batas` (3 bullet). Task 2-6 merujuk file ini via path `${CLAUDE_PLUGIN_ROOT}/rules/elicitation.md`.

- [ ] **Step 1: Konfirmasi file belum ada (red)**

Run: `ls plugin/rules/elicitation.md 2>&1`
Expected: `No such file or directory`

- [ ] **Step 2: Tulis file**

Buat `plugin/rules/elicitation.md` dengan isi PERSIS:

```markdown
# Elicitation — Aturan Q&A & Penyajian Opsi

Dirujuk skill yang meng-elicit keputusan dari user lewat Q&A discovery/design
(intake, fanout, plan, tweak, fix). Berlaku saat skill MENANYAKAN keputusan ke
user — BUKAN ke routing mekanis (mis. triage verba-list tweak/fix). Tujuan:
keputusan yang MENYETIR hasil diambil sadar oleh user — bukan keborong jadi satu
tembakan, bukan "asal pilih recommended".

## Kontrak
- **Keputusan-bercabang = satu pertanyaan per giliran.** Keputusan yang MENGUBAH
  ARAH hasil (siapa pengguna, flow/skenario, aturan bisnis, reuse-vs-NEW tabel,
  app/package/vendor baru, jalur Mockup) ditanya SATU per giliran. JANGAN gabung
  2+ keputusan-bercabang dalam satu tembakan. Konfirmasi sepele (ejaan nama,
  yes/no kecil, "ada lagi?") BOLEH digabung.
- **Tiap opsi bawa konsekuensi.** Tiap pilihan disertai 1 baris akibat/tradeoff
  ("kalau ini → ..."), BUKAN label telanjang. User harus bisa milih tanpa nebak
  maksud opsi.
- **Selalu sediakan jalan keluar dari menu.** Selain opsi yang ditawarkan, selalu
  beri ruang "ceritain versimu sendiri" — opsi bukan kurungan.
- **Jangan tandai *recommended* untuk keputusan ber-impact tinggi/ireversibel.**
  Sajikan tradeoff lalu minta user yang putuskan; default-recommend malah mancing
  "asal pilih". (Selaras `anti-yes-man.md`: persetujuan harus berdasar.)
- **Surface di gate.** Keputusan-bercabang yang sudah diambil HARUS kelihatan di
  artifact yang ditampilkan saat gate (slot di business.md/fanout.md/plans) — biar
  bisa di-review, bukan terkubur.

## Batas
- **Bukan pelarangan batch di mana-mana.** Skill yang sengaja mem-batch demi biaya
  manusia (mis. pre-flight conflict sweep `build`, build/SKILL.md:18) TIDAK
  dilanggar — itu konfirmasi-borong disengaja, bukan Q&A discovery bercabang.
- **Gate ≠ interogasi.** Gate yang menampilkan Challenge Checklist/diff TERISI untuk
  di-review (mis. `tweak` step 5 — "output terisi, BUKAN interogasi 4-ronde",
  tweak/SKILL.md:40; gate `intake`/`build`) BUKAN sasaran aturan ini. "Satu
  pertanyaan per giliran" mengatur Q&A discovery, bukan mengubah gate jadi
  tanya-jawab beruntun.
- **Proporsional.** Fitur 1-app/sepele tak perlu diregang jadi 10 giliran — aturan
  ini menyerang keputusan yang benar-benar bercabang, bukan bikin birokrasi.
```

- [ ] **Step 3: Verifikasi isi hadir (green)**

Run: `rg -n "Keputusan-bercabang = satu pertanyaan per giliran|Tiap opsi bawa konsekuensi|Gate ≠ interogasi" plugin/rules/elicitation.md`
Expected: 3 baris match (1 per frasa kunci).

- [ ] **Step 4: Read-back**

Run: `cat plugin/rules/elicitation.md`
Expected: heading + `## Kontrak` (5 bullet) + `## Batas` (3 bullet), voice konsisten dengan `plugin/rules/anti-yes-man.md`.

- [ ] **Step 5: Commit**

```bash
git add plugin/rules/elicitation.md
git commit -m "feat(elicitation): aturan Q&A sumber-tunggal (rules/elicitation.md)"
```

---

### Task 2: `intake` — slot Flow/Skenario + langkah elicit + sumber promote

**Files:**
- Modify: `plugin/skills/intake/SKILL.md:28-29` (step 3 Q&A), `:47-54` (template business.md), `:55` (promote)

**Interfaces:**
- Consumes: `plugin/rules/elicitation.md` (Task 1).
- Produces: template `business.md` ber-slot `Flow/Skenario:`; langkah Q&A menyebut flow+edge & merujuk elicitation. Slot ini di-baca `breakdown`/`build` hilir sebagai bagian `business.md` (tak ada parser baru — tetap prosa).

- [ ] **Step 1: Konfirmasi state awal (red)**

Run: `rg -n "Flow/Skenario|elicitation" plugin/skills/intake/SKILL.md`
Expected: TIDAK ada match (slot & rujukan belum ada).

- [ ] **Step 2: Edit langkah Q&A (intake:28-29)**

Ganti baris (saat ini):
```
### 3. Q&A level BISNIS (bukan teknis)
Tanya satu per satu: siapa penggunanya, aturan/kebijakan, hasil yang diharapkan, batasan. JANGAN tanya hal teknis (framework, DB, dll) — itu jatah skill `plan`.
```
Jadi:
```
### 3. Q&A level BISNIS (bukan teknis)
Q&A ikuti `${CLAUDE_PLUGIN_ROOT}/rules/elicitation.md` (keputusan-bercabang satu per giliran, opsi bawa konsekuensi). Tanya level bisnis: siapa penggunanya, **alur yang dilewati pengguna (happy-path) + minimal 1 skenario edge/gagal**, aturan/kebijakan, hasil yang diharapkan, batasan. JANGAN tanya hal teknis (framework, DB, dll) — itu jatah skill `plan`.
```

- [ ] **Step 3: Edit template business.md (intake:47-54)**

Ganti fenced template (saat ini):
```
# <Fitur> — Business Spec
Tujuan      : <...>
Pengguna    : <...>
Aturan      : <... + referensi business/ bila relevan>
Hasil/Reward: <...>
Out of scope: <...>
```
Jadi (tambah baris `Flow/Skenario` setelah `Pengguna`, kolom titik dua diluruskan ke label terpanjang):
```
# <Fitur> — Business Spec
Tujuan       : <...>
Pengguna     : <...>
Flow/Skenario: <happy-path: langkah 1 → 2 → 3 …; + minimal 1 skenario edge/gagal: <kondisi> → <yang terjadi>>
Aturan       : <... + referensi business/ bila relevan>
Hasil/Reward : <...>
Out of scope : <...>
```

- [ ] **Step 4: Edit langkah promote (intake:55) — tandai sumber flow**

Di kalimat promote, ganti substring:
```
flow → `business/flows.md`
```
Jadi:
```
flow (dari slot `Flow/Skenario`) → `business/flows.md`
```

- [ ] **Step 5: Verifikasi (green)**

Run: `rg -n "Flow/Skenario|elicitation.md|skenario edge/gagal" plugin/skills/intake/SKILL.md`
Expected: match di step 3 (rujukan + "skenario edge/gagal"), template (`Flow/Skenario:`), dan promote (`dari slot \`Flow/Skenario\``).

- [ ] **Step 6: Read-back konsistensi**

Run: `sed -n '28,30p;46,56p' plugin/skills/intake/SKILL.md`
Expected: kolom titik dua di template lurus; baris Flow ada setelah Pengguna; tak ada slot lama yang rusak.

- [ ] **Step 7: Commit**

```bash
git add plugin/skills/intake/SKILL.md
git commit -m "feat(intake): slot Flow/Skenario di business.md + elicit flow & rujuk elicitation"
```

---

### Task 3: `fanout` — wiring elicitation di pemetaan app

**Files:**
- Modify: `plugin/skills/fanout/SKILL.md:15-16` (intro step 2)

**Interfaces:**
- Consumes: `plugin/rules/elicitation.md` (Task 1).
- Produces: step 2 `fanout` merujuk elicitation untuk semua challenge bercabang (app/package/vendor/design-system baru) di bawahnya.

- [ ] **Step 1: Konfirmasi state awal (red)**

Run: `rg -n "elicitation" plugin/skills/fanout/SKILL.md`
Expected: TIDAK ada match.

- [ ] **Step 2: Edit intro step 2 (fanout:15-16)**

Ganti baris (saat ini):
```
### 2. Petakan ke app
Cocokkan kebutuhan fitur ke `capabilities`/`responsibility` tiap app → tentukan app yang kena + apa perannya.
```
Jadi:
```
### 2. Petakan ke app
Cocokkan kebutuhan fitur ke `capabilities`/`responsibility` tiap app → tentukan app yang kena + apa perannya. **Q&A/konfirmasi ke user ikuti `${CLAUDE_PLUGIN_ROOT}/rules/elicitation.md`** — tiap keputusan-bercabang di bawah (app/package/vendor/design-system baru) ditanya satu per giliran dengan konsekuensinya, jangan diborong.
```

- [ ] **Step 3: Verifikasi (green)**

Run: `rg -n "rules/elicitation.md" plugin/skills/fanout/SKILL.md`
Expected: 1 match di intro step 2.

- [ ] **Step 4: Read-back**

Run: `sed -n '15,17p' plugin/skills/fanout/SKILL.md`
Expected: rujukan menempel di intro step 2, bullet "Adaptif" di bawahnya utuh.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/fanout/SKILL.md
git commit -m "feat(fanout): rujuk elicitation untuk challenge bercabang di pemetaan app"
```

---

### Task 4: `plan` — wiring elicitation di Q&A teknis

**Files:**
- Modify: `plugin/skills/plan/SKILL.md:42` (bullet "Q&A teknis seperlunya")

**Interfaces:**
- Consumes: `plugin/rules/elicitation.md` (Task 1).
- Produces: bullet Q&A teknis `plan` merujuk elicitation; menyebut reuse-vs-NEW tabel & jalur Mockup sebagai keputusan-bercabang.

- [ ] **Step 1: Konfirmasi state awal (red)**

Run: `rg -n "elicitation" plugin/skills/plan/SKILL.md`
Expected: TIDAK ada match.

- [ ] **Step 2: Edit bullet Q&A (plan:42)**

Ganti baris (saat ini):
```
- Q&A **teknis** seperlunya.
```
Jadi:
```
- Q&A **teknis** seperlunya — ikuti `${CLAUDE_PLUGIN_ROOT}/rules/elicitation.md` (keputusan-bercabang seperti reuse-vs-NEW tabel & jalur `Mockup:` ditanya satu per giliran, opsi bawa konsekuensi).
```

- [ ] **Step 3: Verifikasi (green)**

Run: `rg -n "rules/elicitation.md" plugin/skills/plan/SKILL.md`
Expected: 1 match di bullet Q&A teknis.

- [ ] **Step 4: Read-back**

Run: `sed -n '42,42p' plugin/skills/plan/SKILL.md`
Expected: bullet utuh, menyebut reuse-vs-NEW & Mockup.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/plan/SKILL.md
git commit -m "feat(plan): rujuk elicitation untuk Q&A teknis bercabang"
```

---

### Task 5: `tweak` — wiring elicitation di titik tanya (bukan routing)

**Files:**
- Modify: `plugin/skills/tweak/SKILL.md:27` (Cabang C — defect)

**Interfaces:**
- Consumes: `plugin/rules/elicitation.md` (Task 1).
- Produces: titik "tanya satu pertanyaan" di cabang-C merujuk elicitation; routing verba-list B/C/A & gate step 5 TIDAK disentuh (carve-out spec D4).

- [ ] **Step 1: Konfirmasi state awal (red)**

Run: `rg -n "elicitation" plugin/skills/tweak/SKILL.md`
Expected: TIDAK ada match.

- [ ] **Step 2: Edit cabang C (tweak:27)**

Ganti baris (saat ini):
```
**Cabang C — defect → `/fix`.** Triage by framing (`reference.md` §C): "salah/harusnya/bug" → route `/fix` bawa konteks; ambigu → tanya satu pertanyaan.
```
Jadi:
```
**Cabang C — defect → `/fix`.** Triage by framing (`reference.md` §C): "salah/harusnya/bug" → route `/fix` bawa konteks; ambigu → tanya satu pertanyaan (ikuti `${CLAUDE_PLUGIN_ROOT}/rules/elicitation.md` — titik tanya ke user; routing verba-list & Challenge Checklist gate step 5 tetap mekanis/output-terisi, BUKAN interogasi).
```

- [ ] **Step 3: Verifikasi (green)**

Run: `rg -n "rules/elicitation.md" plugin/skills/tweak/SKILL.md`
Expected: 1 match di cabang C.

- [ ] **Step 4: Read-back carve-out**

Run: `rg -n "interogasi 4-ronde|tetap mekanis/output-terisi" plugin/skills/tweak/SKILL.md`
Expected: 2 match — gate step 5 (`:40`, "BUKAN interogasi 4-ronde") tetap utuh + carve-out baru di cabang C. Konfirmasi keduanya tak saling bertentangan.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/tweak/SKILL.md
git commit -m "feat(tweak): rujuk elicitation di titik tanya cabang-C (carve-out gate utuh)"
```

---

### Task 6: `fix` — wiring elicitation di titik konfirmasi mode/triage/unit

**Files:**
- Modify: `plugin/skills/fix/SKILL.md:25` (triage guard, akhir step 1)

**Interfaces:**
- Consumes: `plugin/rules/elicitation.md` (Task 1).
- Produces: satu kalimat umbrella di step 1 menutup tiga titik konfirmasi (pilih mode bila DUA fitur `:23`, triage-guard `:25`, unit-inference `:50`); routing tabel mode & triage-guard tetap mekanis.

- [ ] **Step 1: Konfirmasi state awal (red)**

Run: `rg -n "elicitation" plugin/skills/fix/SKILL.md`
Expected: TIDAK ada match.

- [ ] **Step 2: Edit akhir triage guard (fix:25)**

Ganti baris (saat ini):
```
Lalu **triage guard** (reference §D): **kode salah** (lanjut) / **requirement baru** (STOP → `/feature`) / **doc salah** (koreksi knowledge, gated `critic`). Cek **tripwire** (butuh capability/vendor/unit baru → STOP → `/feature`).
```
Jadi (tambah kalimat umbrella di akhir):
```
Lalu **triage guard** (reference §D): **kode salah** (lanjut) / **requirement baru** (STOP → `/feature`) / **doc salah** (koreksi knowledge, gated `critic`). Cek **tripwire** (butuh capability/vendor/unit baru → STOP → `/feature`). **Tiap titik TANYA/konfirmasi ke user (pilih mode bila DUA fitur, triage ambigu, unit-inference §3) ikuti `${CLAUDE_PLUGIN_ROOT}/rules/elicitation.md`: satu keputusan-bercabang per giliran, opsi bawa konsekuensi, jangan tebak diam-diam** (routing tabel mode & triage-guard tetap mekanis — elicitation hanya di momen klarifikasi).
```

- [ ] **Step 3: Verifikasi (green)**

Run: `rg -n "rules/elicitation.md" plugin/skills/fix/SKILL.md`
Expected: 1 match di akhir triage guard step 1.

- [ ] **Step 4: Read-back cakupan**

Run: `sed -n '23,25p;50,50p' plugin/skills/fix/SKILL.md`
Expected: baris "DUA fitur → TANYA" (`:23`) & unit-inference "konfirmasi user" (`:50`) masih ada; kalimat umbrella di `:25` menyebut ketiganya.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/fix/SKILL.md
git commit -m "feat(fix): rujuk elicitation di titik konfirmasi mode/triage/unit"
```

---

### Task 7: Sweep konsistensi lintas-file + cek enumerasi rules

**Files:**
- Verify-only (semua file di atas). Modify HANYA bila ditemukan tempat yang meng-enumerasi file `rules/` (mis. README/manifest) yang perlu menyebut `elicitation.md`.

**Interfaces:**
- Consumes: hasil Task 1-6.
- Produces: jaminan tak ada referensi yatim + (bila ada indeks rules) `elicitation.md` terdaftar.

- [ ] **Step 1: Semua 5 skill merujuk elicitation (green menyeluruh)**

Run: `rg -n "rules/elicitation.md" plugin/skills/intake/SKILL.md plugin/skills/fanout/SKILL.md plugin/skills/plan/SKILL.md plugin/skills/tweak/SKILL.md plugin/skills/fix/SKILL.md`
Expected: tepat 5 match (1 per skill).

- [ ] **Step 2: Tak ada referensi yatim / salah eja path**

Run: `rg -n "elicitation" plugin/ docs/ | rg -v "rules/elicitation.md|plugin/rules/elicitation.md|docs/superpowers/(specs|plans)"`
Expected: TIDAK ada baris (semua penyebutan mengeja path benar atau ada di spec/plan).

- [ ] **Step 3: Cek apakah ada indeks/enumerasi file `rules/`**

Run: `rg -n "anti-yes-man|debt-aware|migration-impact|compliance-risk|schema-projection" README.md .claude-plugin/ plugin/skills/init/SKILL.md`
Expected: lihat apakah ada daftar yang menyebut SEMUA file rules secara enumeratif (mis. README plugin). **Bila ADA enumerasi lengkap** → tambahkan `elicitation.md` ke daftar itu (+ commit). **Bila tidak ada** (hanya `init` yang merge `anti-yes-man` secara spesifik, bukan enumerasi) → tak ada yang perlu diubah; catat di summary.

- [ ] **Step 4: Read-back final 3 file rules baru-rujuk**

Run: `cat plugin/rules/elicitation.md && echo "---INTAKE 28-29---" && sed -n '28,29p' plugin/skills/intake/SKILL.md`
Expected: aturan utuh; intake merujuknya. Voice konsisten lintas file.

- [ ] **Step 5: Commit (hanya bila Step 3 menghasilkan edit)**

```bash
# Jika Step 3 menambah elicitation.md ke indeks rules:
git add -A && git commit -m "docs(rules): daftarkan elicitation.md di indeks rules"
# Jika tidak ada indeks: tak ada commit; verifikasi selesai.
```

---

## Self-Review (penulis plan)

**1. Spec coverage:**
- D1 (elicitation.md) → Task 1 ✅
- D2a/b/c (slot Flow + elicit + sumber promote) → Task 2 ✅
- D3 wiring 5 skill → Task 2 (intake), 3 (fanout), 4 (plan), 5 (tweak), 6 (fix) ✅
- D4 carve-out → ter-encode di Task 1 (Batas) + ditegakkan Task 5 step 4 & Task 6 step 2/4 ✅
- D5 idempotency/retrofit → tak butuh task (perilaku re-run intake; dicatat) ✅
- D6 verifikasi → tiap task step grep+read-back + Task 7 sweep ✅
- §5 out-of-scope → tak ada task (discovery/architect/CLAUDE.md-merge sengaja dilewat) ✅

**2. Placeholder scan:** Tak ada TBD/TODO. `<...>` di Task 2 = placeholder template `business.md` (memang format), bukan plan-gap. Task 7 step 3/5 conditional ("bila ada indeks") — eksplisit cabangnya, bukan placeholder.

**3. Type/anchor consistency:** Path rujukan identik di 5 skill: `${CLAUDE_PLUGIN_ROOT}/rules/elicitation.md`. Nama slot identik: `Flow/Skenario`. Frasa carve-out ("output terisi"/"interogasi") cocok dengan tweak:40 existing. Anchor `file:line` dari pembacaan aktual (commit `5144948`-era); bila implementer menemukan geser baris, pakai pencarian frasa (bukan nomor baris mati).
