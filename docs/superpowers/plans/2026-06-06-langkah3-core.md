# Langkah-3 CORE — Implementation Plan (M1 · M7 · M8 · L1 · L2 terkoordinasi)

> **For agentic workers:** REQUIRED SUB-SKILL — Use superpowers:executing-plans to implement task-by-task (sesi terpisah). Steps pakai checkbox (`- [ ]`). Strategi **ONE-FILE-PER-TASK**: tiap task ngedit SATU file, find/replace EKSAK (FIND = verbatim disk → REPLACE), commit per task.

**Goal:** Eksekusi 5 spec Langkah-3 yang sudah review-adversarial, dalam SATU rencana terkoordinasi karena mereka mengedit **file yang sama**:
- **M1** (roadmap/epic) — field `epic`/`depends_on` di `feature.yaml` (2 creation site) + warn-gate `feature` step 2 + sizing-check `intake` step 4 + parent §7/§9. Spec: `docs/superpowers/specs/2026-06-06-m1-roadmap-epic-design.md`.
- **M7** (graduated autonomy) — field `risk` di `feature.yaml` (2 creation site) + `build` step 1 (baca+deteksi mode) / step 6 (klausa unattended) / description (trigger) / reference §D + intake step 7 (usulkan risk + auto-floor) + parent §12. Spec: `docs/superpowers/specs/2026-06-06-m7-graduated-autonomy-design.md`.
- **M8** (feedback loop) — NEW `template/control/feedback/README.md` + `intake` step 2 (baca SOFT) / step 5 (challenge item) + `ask` feedback row + parent §7/§17/§9-Input. Spec: `docs/superpowers/specs/2026-06-06-m8-observability-feedback-design.md`.
- **L1** (capability blueprint) — `init` Langkah 3/5 (blueprint marker) + `ask` (laporkan blueprint apa adanya). Parent NOL amandemen wajib. Spec: `docs/superpowers/specs/2026-06-06-l1-capability-blueprint-design.md`.
- **L2** (iterasi-v2/deprecate) — doc-hint 1 bullet `feature` `## Catatan` + parent §16 Future. (Edit render-docs/badge `shipped` = milik spec L3, DI LUAR plan ini.) Spec: `docs/superpowers/specs/2026-06-06-l2-iteration-deprecate-design.md`.

**Tech Stack:** Markdown skill/agent/template/spec. Tak ada kode runtime. "Test" = grep-battery anchor verification + coherence read.

**Branch:** branch kerja sekarang (sudah punya 7 spec committed + semua skill dari main). Eksekusi & post-exec verify = **sesi terpisah**. JANGAN merge/push di sesi eksekusi.

**Honesty-frame seluruh plan (preseden M6 §1 — tulis jujur di surface tempat logika jalan):**
- M1 = metadata + warn (BUKAN block); satu-satunya STOP tetap Security Gate `ship`. Warn-gate `feature` step 2 bermakna hanya bila `depends_on` ter-deklarasi lebih dulu (run lanjutan / isi manual), bukan run-pertama (jujur soal timing, M1 §6b/§10).
- M7 = MELONGGARKAN cadence gate `build` step 6 yang ADA (opt-in `--unattended`), BUKAN gate baru; HARD floor (`risk: high`+`migrate`+`needs_human`+`blocked`+penyimpangan) tetap STOP; ship/security TIDAK disentuh.
- M8 = murni advisory di hulu `intake`; penulis = manusia (drop manual), tak ada auto-ingest; degrade-mulus bila kosong/absen.
- L1 = advisory/opsional 1 jalur (init langsung); via discovery di-skip (jujur); declare ≠ scaffold; marker dibaca reader.
- L2 = doc-hint murni, NOL perubahan perilaku; gap inti tetap future (induk §16).

---

## Urutan & non-tabrakan (BACA DULU — peta FILE → daftar edit)

Lima item mengedit beberapa **file bersama**. Tabel berikut memetakan tiap file ke edit dari semua item, dengan region teks yang DISTINCT (tak overlap). Aturan: (a) edit di region berbeda → boleh satu task multi-sub-step (tiru M6 Task 6/7); (b) dua item nyentuh baris SAMA → **GABUNG** jadi satu REPLACE; (c) anchor tiap edit = teks stabil yang tak diubah edit lain.

| File | Item · region (top→bottom) | Tabrakan? |
|---|---|---|
| `template/control/feedback/README.md` | **M8** (NEW file) | — (file baru) |
| `intake/SKILL.md` | **M1+M7** step 1 (field `epic`/`depends_on`/`risk` setelah `sensitivity`) · **M8** step 2 (baca feedback, SETELAH baris risks.md M6) · **M1** step 4 (sizing-check) · **M8** step 5 (item feedback, SETELAH item compliance M6) · **M7** step 7 (usulkan risk, SETELAH klausa compliance M6) | step 1 = **GABUNG M1+M7** (baris `sensitivity` sama). Sisanya region berbeda (step 2/4/5/7) — tak overlap. M6 sudah di disk; M8/M1/M7 nempel SETELAH anchor M6, anchor M6 tetap utuh. |
| `feature/SKILL.md` | **M1+M7** step 1 (field setelah `sensitivity`) · **M1** step 2 (warn-gate, SEBELUM sub-1 invoke intake) · **L2** `## Catatan` (bullet iterasi setelah baris transisi) | step 1 = **GABUNG M1+M7**. step 2 & Catatan region berbeda. |
| `build/SKILL.md` | **M7** step 1 (baca risk + deteksi mode) · step 6 (klausa unattended) · description (trigger varian) | semua M7, region berbeda. |
| `build/reference.md` | **M7** §D (bullet `--unattended`) | hanya M7. |
| `ask/SKILL.md` | **M8** feedback row (tabel, SETELAH fixes-row) · **L1** prose blueprint (SETELAH baris "lintas-domain") | region berbeda (tabel vs prose-bawah-tabel). M1 ask cosmetic = **SKIP** (spec: ragu→skip; cell status rapuh). |
| `init/SKILL.md` | **L1** Langkah 3 (sub-bullet blueprint) · Langkah 5 (kalimat marker setelah baris existing) | hanya L1, region berbeda. |
| Induk `2026-05-24-ai-first-boilerplate-design.md` | **M1** §7 (komentar feature.yaml) · **M8** §7 (baris `feedback/` SEBELUM `fixes/`) · **M1** §9 intake Perilaku · **M8** §9 intake Input · **M1** §9 feature Perilaku · **M7** §12 (kalimat risk) · **M8** §17 Knowledge · **L2** §16 Future | semua anchor DISTINCT (verified). §7 M1=komentar feature.yaml (line 79), §7 M8=baris fixes/ (line 86) — beda baris. §9 intake Perilaku(189) ≠ Input(188) ≠ feature Perilaku(184). |

**Field-order contract `feature.yaml` (KEDUA creation site identik):** `name` → `status` → `created` → `sensitivity` (existing, JANGAN geser) → `epic` (M1) → `depends_on` (M1) → `risk` (M7). Sumber: M1 §4 + M7 §4a ("`sensitivity` → [M1 fields] → `risk` di akhir").

**Sequencing keputusan:** tiap task = satu file = satu commit. Karena semua edit pakai FIND verbatim (bukan nomor baris) di region distinct, urutan antar-task tak merusak anchor. Dalam satu task multi-sub-step, urut top→bottom file untuk keterbacaan. Task 0 commit dulu (no-op bila spec sudah committed — skip bila `git status` bersih untuk 5 spec).

**Opsional yang DI-SKIP (jujur):** M1 §6d `ask` cosmetic (spec: skip bila ragu) · M1 §18 open-q parent (spec: boleh dilewati) · L1 §6 parent §9 init klausa (spec: DEFAULT SKIP, VERIFY-BEFORE-EDIT) · M8 §8-repo-tree `template/control/` listing (spec: OPSIONAL). Bila eksekutor mau menambah salah satu → FLAG, jangan diam-diam balloon.

**Catatan eksekutor (BUKAN bug — dari review; jangan ubah plan, cukup sadar saat eksekusi):**
- **Task 8 step1a komentar induk §7 `feature.yaml`** sengaja menggabung M1+M7 → `(sensitivity; epic/depends_on M1; risk M7)`. M7 §7 menyebut "opsi A = jangan-edit komentar" tapi tegas "opsi B aman"; plan ambil opsi B (gabung dgn M1). Bila kamu baca M7 §7 harfiah, jangan bingung — anchor unik, tanpa `: `, semicolon gaya M1. Self-review baris ~715 menjelaskan.
- **Task 8 step1b alignment `feedback/` tree:** kolom `#` ada di char-index 26 (rata dgn `fixes/` dan semua sibling §7). Prosa M8 spec §7 sempat menyebut "13 spasi" sedangkan literal-example spec-nya sedikit off (14 spasi) — **plan ini BENAR** (REPLACE pakai teks plan, verified `grep -Fc` = 1; alignment dihitung = 26). Pakai teks plan, bukan teks spec.
- **Task 6 step1a feedback-row `ask`** mendarat DI TENGAH tabel (antara baris `fixes/` dan `debt/`), bukan di akhir — sesuai M8 spec §11 ("setelah baris fixes"). Bukan bug; jangan heran row muncul sebelum baris `debt/`.
- **Task 6 step1b blockquote L1** memuat frasa sentinel `(blueprint — belum di-bring-up)` dalam prosa `ask/SKILL.md`. Aman: `ask` men-scan sentinel di `workspace.yaml` (bukan di SKILL.md-nya sendiri). Semua 8 kemunculan frasa pakai em-dash U+2014 identik (verified) — tulis verbatim, jangan normalisasi.

---

## Bug-guard pre-bake (berlaku semua task)

- **colon-space `: ` HARAM di value YAML / `description:` frontmatter.** Satu-satunya `description:` yang disentuh = **M7 `build/SKILL.md`** (Task 4 step 3) — tambah varian trigger pakai **em-dash** dalam kurung, TANPA `: ` (token `--unattended` aman: tak ada spasi setelah titik-dua). Verifikasi pasca-edit `sed -n 's/^description: //p' plugin/skills/build/SKILL.md | grep ': '` tetap **kosong** (sudah kosong pra-edit, verified). Field YAML baru `epic: ""`/`depends_on: []`/`risk: normal` — value bersih (`: ` tak ada DI value); komentar inline pakai em-dash/kurung/koma. Marker L1 `(blueprint — belum di-bring-up)` & komentar `# blueprint, belum di-bring-up` TANPA `: ` (em-dash/koma). README M8 = prosa markdown (colon di prosa aman, bukan value YAML).
- **no-renumber:** SEMUA sisipan = field/sub-bullet/klausa/baris-tree/baris-tabel baru. JANGAN renumber step skill (intake 2/4/5/7, feature 2, build 1/6, init 3/5) atau section parent. Warn-gate M1 = sub-klausa SEBELUM sub-1 feature step 2 (sub-1/2/3 tetap nomornya). Sizing M1 = sub-klausa di intake step 4. M7 risk = sisip setelah klausa sensitivity intake step 7. L2 = bullet baru di `## Catatan`.
- **byte-trap:** bedakan em-dash `—` (U+2014) vs arrow `->`/`→` (U+2192) vs middot `·` (U+00B7) vs `×` (U+00D7, di "app × milestone"). COPY anchor verbatim dari disk; JANGAN normalisasi/ketik-ulang. Anchor build step 6 memuat `×` (U+00D7) — pakai apa adanya.
- **mis-aimed-pointer:** tiap `§X`/"(lihat …)"/"step N" di REPLACE nunjuk target benar. M7 build step 6 rujuk "step 1/2/3/5" (floor di-tegakkan di step 2/3/5) — verified step itu ada. L1 init sub-bullet rujuk "langkah 5" — verified Langkah 5 = Generate workspace.yaml. L2 bullet rujuk "induk §12/§16 + pipeline-hardening §S4.1/§10-4" — induk §12 = tabel status, §16 = Future (verified); §S4.1/§10-4 = spec pipeline-hardening (terverifikasi di L2 §1.3).
- **M6 anchor preservation:** disk SUDAH punya edit M6 di intake step 2 (risks.md), step 5 (item compliance), step 7 (klausa compliance) + induk §7(risks.md)/§9-ship/§17(compliance-risk.md). M8/M1/M7 nempel SETELAH anchor M6 → REPLACE menyertakan anchor M6 verbatim + sisipan baru. JANGAN ubah/hapus teks M6.
- **literal-scan sentinel:** L1 marker frasa `(blueprint — belum di-bring-up)` & komentar `# blueprint, belum di-bring-up` = penanda yang DIBACA `ask`/`design-system`/`fanout` — tulis verbatim konsisten di init L3, init L5, ask. M8 README tak menambah sentinel `<…>` baru (TANPA `<PRODUCT>`).
- **anchor verify:** tiap FIND di-`grep -Fc -e` verbatim = **1** SEBELUM commit (ringkasan di bawah). Robust leading-dash `- `, metachar `[]`/`**`/backtick/`()`/`×`, em-dash, middot, box-drawing tree `├`/`└` + padding-spasi, alignment kolom `#`.
- **skill-count TETAP 21, rules TETAP 5:** `plugin.json`/`marketplace.json`/README TIDAK disentuh. Induk §17 `**Skills (21):**` tak diubah; §8/§17 rules listing tak diubah (M7/M8/L1/L2 tak nambah rule; M6 sudah nambah compliance-risk.md = rule ke-5, di disk).
- Tiap commit diakhiri trailer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## Ringkasan verifikasi anchor (semua `grep -Fc -e` = 1 saat penulisan plan)

Dijalankan vs disk saat menulis plan ini — semua FIND **= 1**:

| Anchor (file) | grep |
|---|---|
| intake step1 `sensitivity` line | 1 |
| intake step2 baca-knowledge (risks.md M6) | 1 |
| intake step4 feasibility-content | 1 |
| intake step5 item-compliance (M6) | 1 |
| intake step7 `**Usulkan tag sensitivity**...(heuristik):` + trailing `Lihat ${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md.` | 1 / 1 |
| feature step1 `sensitivity` line | 1 |
| feature step2 heading + sub-1 invoke intake | 1 / 1 |
| feature `## Catatan` transisi line (L2) | 1 |
| build step1 manifest-aktif + tail-sentence | 1 / 1 |
| build step6 heading + first-sentence prefix | 1 / 1 |
| build description trigger list | 1 |
| build/reference §D `Fitur 1-app` bullet | 1 |
| ask fixes-row (M8) | 1 |
| ask `Pertanyaan lintas-domain → buka >1 sumber.` (L1) | 1 |
| ask status-row (M1 cosmetic — SKIP) | 1 |
| init L3 app-apa-saja | 1 |
| init L5 existing-stack | 1 |
| induk §7 `feature.yaml  # status + metadata` (M1) | 1 |
| induk §7 `fixes/` tree line (M8) | 1 |
| induk §9 intake Perilaku (M1) | 1 |
| induk §9 intake Input (M8) | 1 |
| induk §9 feature Perilaku (M1) | 1 |
| induk §12 sensitivity-invarian sentence (M7) | 1 |
| induk §17 Knowledge line (M8) | 1 |
| induk §16 Future bullet (L2) | 1 |
| induk `**Skills (21):**` (guard) | 1 |
| build description colon-space (value) | **0** (`: ` tak ada — clean pra/pasca-edit) |

---

### Task 0: Pastikan 5 spec ter-commit (branch kerja)

- [ ] **Step 1:** `git status --short` — bila 5 spec Langkah-3 (m1/m7/m8/l1/l2) sudah committed (tree bersih untuk file itu), **SKIP commit**. Bila ada spec belum ter-add:

```bash
git add docs/superpowers/specs/2026-06-06-m1-roadmap-epic-design.md docs/superpowers/specs/2026-06-06-m7-graduated-autonomy-design.md docs/superpowers/specs/2026-06-06-m8-observability-feedback-design.md docs/superpowers/specs/2026-06-06-l1-capability-blueprint-design.md docs/superpowers/specs/2026-06-06-l2-iteration-deprecate-design.md docs/superpowers/plans/2026-06-06-langkah3-core.md
git commit -m "docs(langkah3): spec M1/M7/M8/L1/L2 + plan core terkoordinasi

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 1: NEW template `control/feedback/README.md` (M8)

**File:** Create `plugin/template/control/feedback/README.md`

- [ ] **Step 1: Tulis file** (verbatim — TANPA `<PRODUCT>`)

````markdown
# Feedback — Sinyal Lapangan (input SOFT untuk intake)

Drop di sini sinyal MENTAH dari produk yang sudah live: keluhan user, incident ops, request fitur, insight analytics/support. Satu sinyal = satu file `.md` (mis. `2026-06-10-checkout-sering-timeout.md`).

**Penulis = MANUSIA (operator/user).** Drop manual — tak ada skill yang mengisi folder ini, tak ada auto-ingest. **Pembaca = `intake`** (saat merencanakan fitur, ia memunculkan sinyal relevan — sebagai INPUT SOFT, BUKAN gate; tak memblokir apa pun).

**Format ringan yang disarankan** (bebas, tak wajib):
- Judul singkat + tanggal.
- Sinyal: apa yang diamati di lapangan (kutip keluhan/incident apa adanya).
- Dugaan area dampak: app/fitur/flow yang relevan (bila tahu).

**Garis batas — apa yang BUKAN feedback:**
- **Bug terkonfirmasi** (bisa di-reproduce) → bukan di sini; jalankan `/fix` (lane `control/fixes/`).
- **Kewajiban compliance/regulasi** (PCI/GDPR/pajak/KYC) → bukan di sini; rumahnya `control/business/risks.md`.
- Feedback = sinyal HULU MENTAH yang belum tentu bug; ia menginformasikan fitur berikutnya, bukan eksekusi.

Folder boleh kosong (cuma README ini) — `intake` degrade mulus bila tak ada sinyal.
````

- [ ] **Step 2: Verify**

```bash
f=plugin/template/control/feedback/README.md
test -f "$f" && echo "EXISTS ✓"
grep -Fc -e '# Feedback — Sinyal Lapangan (input SOFT untuk intake)' "$f"   # expect 1
grep -Fc -e '**Penulis = MANUSIA (operator/user).**' "$f"                   # expect 1 (penulis-manusia)
grep -Fc -e 'sebagai INPUT SOFT, BUKAN gate' "$f"                           # expect 1 (sifat SOFT)
grep -Fc -e 'jalankan `/fix` (lane `control/fixes/`).' "$f"                 # expect 1 (garis batas fix)
grep -Fc -e 'rumahnya `control/business/risks.md`.' "$f"                    # expect 1 (garis batas risks)
grep -Fc -e 'tak ada auto-ingest' "$f"                                      # expect 1 (anti-pipeline)
grep -Fc -e '<PRODUCT>' "$f"                                                # expect 0 (TANPA placeholder)
```
Expected: EXISTS ✓ · 1 · 1 · 1 · 1 · 1 · 1 · 0.

- [ ] **Step 3: Commit**

```bash
git add plugin/template/control/feedback/README.md
git commit -m "feat(m8): template control/feedback/README.md — sinyal lapangan SOFT (penulis manusia, garis batas vs fix/risks)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `intake/SKILL.md` — field (M1+M7) + feedback (M8) + sizing (M1) + risk-usulan (M7)

**File:** Modify `plugin/skills/intake/SKILL.md` (5 sub-step, region distinct; M6 anchor dipertahankan)

- [ ] **Step 1a: step 1 creation** — sisip 3 field SETELAH baris `sensitivity` (GABUNG M1 `epic`/`depends_on` + M7 `risk`; field-order contract).

FIND (verbatim):
```
sensitivity: []        # [] | [payments] | [pii] | [payments, pii] — diusulkan di step 7, dikonfirmasi user
```
REPLACE WITH:
```
sensitivity: []        # [] | [payments] | [pii] | [payments, pii] — diusulkan di step 7, dikonfirmasi user
epic: ""               # (M1) nama epik pengelompok; "" = standalone — metadata, bukan kontrol eksekusi
depends_on: []         # (M1) [<nama-fitur>] yang idealnya shipped dulu; warn-gate feature (BUKAN block)
risk: normal           # (M7) low | normal | high — menyetir cadence approval build --unattended; sensitivity non-kosong → floor high (hard)
```

- [ ] **Step 1b: step 2** — sisip kalimat feedback (M8) SETELAH baris baca-knowledge (anchor M6 utuh).

FIND (verbatim):
```
Baca `control/business/*.md` (domain, flows, glossary, **`risks.md`** — kewajiban compliance, constraint per-fitur) + `control/workspace.yaml` (apps + capabilities).
```
REPLACE WITH:
```
Baca `control/business/*.md` (domain, flows, glossary, **`risks.md`** — kewajiban compliance, constraint per-fitur) + `control/workspace.yaml` (apps + capabilities).
**Feedback (M8):** bila ada, baca `control/feedback/` (sinyal lapangan mentah dari produk live — keluhan/incident/request) sebagai **input SOFT** (advisory, **bukan** gate; tak memblokir). Sinyal yang ternyata bug → arahkan ke `/fix`, bukan diselesaikan di sini. Degrade: kosong/absen → lanjut seperti biasa. (Surfacing ke user di-paksa di step 5 — lihat Challenge Checklist.)
```

- [ ] **Step 1c: step 4** — sisip klausa sizing-check (M1) SETELAH kalimat feasibility.

FIND (verbatim):
```
Bandingkan kebutuhan fitur dengan `capabilities` app di `workspace.yaml`. Catat mana yang sudah didukung vs baru.
```
REPLACE WITH:
```
Bandingkan kebutuhan fitur dengan `capabilities` app di `workspace.yaml`. Catat mana yang sudah didukung vs baru. **Sizing-check (advisory, M1):** bila kebutuhan fitur terlihat sebesar epik (banyak app/flow/milestone independen, scope melar), **usulkan** pecah jadi beberapa fitur lebih kecil — isi `epic` (pengelompok) + `depends_on` (urutan) di tiap `feature.yaml`. Usulan saja; user putuskan. Tak memblokir.
```

- [ ] **Step 1d: step 5** — sisip item feedback (M8) SETELAH item compliance M6 (anchor M6 utuh).

FIND (verbatim):
```
- Menyentuh kewajiban compliance di `risks.md`? (PCI/GDPR/pajak/KYC) — kutip + pastikan tertangani (advisory).
```
REPLACE WITH:
```
- Menyentuh kewajiban compliance di `risks.md`? (PCI/GDPR/pajak/KYC) — kutip + pastikan tertangani (advisory).
- Ada sinyal lapangan relevan di `feedback/`? — kutip + tanya apakah fitur ini menanganinya (advisory).
```

- [ ] **Step 1e: step 7** — sisip klausa risk-usulan + auto-floor (M7) SETELAH klausa compliance M6 (anchor M6 utuh; `Lihat ...compliance-risk.md.` = penutup kalimat M6, append SESUDAHNYA).

FIND (verbatim):
```
**Compliance (M6):** kalau fitur cocok dgn pemicu di `control/business/risks.md` → **perkuat** usulan tag + sebut kewajibannya sbg alasan (advisory; heuristik teks tetap jalan tanpa `risks.md`). Lihat `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`.
```
REPLACE WITH:
```
**Compliance (M6):** kalau fitur cocok dgn pemicu di `control/business/risks.md` → **perkuat** usulan tag + sebut kewajibannya sbg alasan (advisory; heuristik teks tetap jalan tanpa `risks.md`). Lihat `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`. **Usulkan `risk` (M7)** (`low|normal|high`): seberapa berbahaya bila build keliru (luas perubahan, destruktif/irreversible, sentuh fondasi). **Floor:** bila usulan `sensitivity` memuat `payments`/`pii` → `risk` minimal `high` (HARD, tak bisa diturunkan selama sensitivity non-kosong). Tulis ke `feature.yaml` `risk`. Advisory — default `normal` bila tak yakin (fail-safe ke lebih banyak review); user konfirmasi di gate ini.
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/intake/SKILL.md
grep -Fc -e 'epic: ""               # (M1) nama epik pengelompok; "" = standalone — metadata, bukan kontrol eksekusi' "$f"  # 1
grep -Fc -e 'depends_on: []         # (M1) [<nama-fitur>] yang idealnya shipped dulu; warn-gate feature (BUKAN block)' "$f"  # 1
grep -Fc -e 'risk: normal           # (M7) low | normal | high — menyetir cadence approval build --unattended; sensitivity non-kosong → floor high (hard)' "$f"  # 1
grep -Fc -e '**Feedback (M8):** bila ada, baca `control/feedback/`' "$f"  # 1
grep -Fc -e '**Sizing-check (advisory, M1):** bila kebutuhan fitur terlihat sebesar epik' "$f"  # 1
grep -Fc -e '- Ada sinyal lapangan relevan di `feedback/`? — kutip + tanya apakah fitur ini menanganinya (advisory).' "$f"  # 1
grep -Fc -e '**Usulkan `risk` (M7)** (`low|normal|high`):' "$f"  # 1
grep -Fc -e 'bila usulan `sensitivity` memuat `payments`/`pii` → `risk` minimal `high` (HARD' "$f"  # 1
# M6 anchor preserved
grep -Fc -e '- Menyentuh kewajiban compliance di `risks.md`? (PCI/GDPR/pajak/KYC) — kutip + pastikan tertangani (advisory).' "$f"  # 1
# colon-space: description tak disentuh
sed -n 's/^description: //p' "$f" | grep ': ' && echo "BOCOR!" || echo "desc clean ✓"
```
Expected: 1×8 · M6=1 · desc clean ✓.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/intake/SKILL.md
git commit -m "feat(m1+m7+m8): intake — field epic/depends_on/risk (step1) + feedback SOFT (step2/5) + sizing-check (step4) + usulkan risk auto-floor (step7)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `feature/SKILL.md` — field (M1+M7) + warn-gate (M1) + doc-hint iterasi (L2)

**File:** Modify `plugin/skills/feature/SKILL.md` (3 sub-step, region distinct)

- [ ] **Step 1a: step 1 creation** — sisip 3 field SETELAH baris `sensitivity` (GABUNG M1+M7; komentar BEDA dari intake — verbatim disk feature).

FIND (verbatim):
```
sensitivity: []        # [] | [payments] | [pii] | [payments, pii] — diusulkan intake, dikonfirmasi user
```
REPLACE WITH:
```
sensitivity: []        # [] | [payments] | [pii] | [payments, pii] — diusulkan intake, dikonfirmasi user
epic: ""               # (M1) nama epik pengelompok; "" = standalone — metadata, bukan kontrol eksekusi
depends_on: []         # (M1) [<nama-fitur>] yang idealnya shipped dulu; warn-gate step 2 (BUKAN block)
risk: normal           # (M7) low | normal | high — menyetir cadence approval build --unattended; sensitivity non-kosong → floor high (hard)
```

- [ ] **Step 1b: step 2 warn-gate (M1)** — sisip sub-klausa SEBELUM sub-1 (invoke intake); no-renumber (sub-1/2/3 tetap).

FIND (verbatim):
```
1. Invoke skill **`intake`** untuk `<nama>` → tunggu gate (approve `business.md`).
```
REPLACE WITH:
```
**Cek dependency (warn, BUKAN block — M1):** bila `feature.yaml` punya `depends_on` non-kosong, untuk tiap `<dep>` baca `control/features/<dep>/feature.yaml`. Bila `status` ≠ `shipped` (atau `dropped`/tak ditemukan), **tampilkan peringatan** (mis. `dep <X> belum shipped (status active)` / `<X> dropped — rencana mungkin basi` / `<X> tak ditemukan`) + **minta konfirmasi lanjut** — peringatan, BUKAN palang; user boleh lanjut (dependency sering dikerjakan paralel). Degrade: `depends_on` kosong/absen → skip diam-diam. Catatan jujur: di `/feature` run-pertama `depends_on` masih default `[]` (sizing-check intake mengisinya belakangan) → warn skip; warn bermakna pada run lanjutan / `depends_on` yang user isi manual.
1. Invoke skill **`intake`** untuk `<nama>` → tunggu gate (approve `business.md`).
```

- [ ] **Step 1c: `## Catatan` doc-hint iterasi (L2)** — sisip bullet SETELAH baris transisi.

FIND (verbatim):
```
- Eksekusi implementasi ditangani `breakdown` → `build`; transisi `shipped`/`dropped` ditangani `ship`/`drop`.
```
REPLACE WITH:
```
- Eksekusi implementasi ditangani `breakdown` → `build`; transisi `shipped`/`dropped` ditangani `ship`/`drop`.
- **Iterasi fitur yang sudah `shipped`** — tak ada status `deprecate`/jalur penerus first-class (status sengaja kasar — induk §12). Untuk perubahan substansial, **buat fitur baru** (nama bebas, mis. `<nama>-v2`) lewat `/feature`; untuk perbaikan bug perilaku yang sudah ada, pakai `/fix`. Jalur penerus/pensiun otomatis (immutable old-folder + supersedes) = **future, spec terpisah** (lihat induk §16 + pipeline-hardening §S4.1/§10-4).
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/feature/SKILL.md
grep -Fc -e 'epic: ""               # (M1) nama epik pengelompok; "" = standalone — metadata, bukan kontrol eksekusi' "$f"  # 1
grep -Fc -e 'depends_on: []         # (M1) [<nama-fitur>] yang idealnya shipped dulu; warn-gate step 2 (BUKAN block)' "$f"  # 1
grep -Fc -e 'risk: normal           # (M7) low | normal | high — menyetir cadence approval build --unattended; sensitivity non-kosong → floor high (hard)' "$f"  # 1
grep -Fc -e '**Cek dependency (warn, BUKAN block — M1):**' "$f"  # 1
grep -Fc -e 'peringatan, BUKAN palang; user boleh lanjut' "$f"  # 1
grep -Fc -e '- **Iterasi fitur yang sudah `shipped`** — tak ada status `deprecate`/jalur penerus first-class' "$f"  # 1
grep -Fc -e 'future, spec terpisah** (lihat induk §16 + pipeline-hardening §S4.1/§10-4).' "$f"  # 1
# anchor sub-1 invoke intake tetap utuh (1×, bukan duplikat)
grep -Fc -e '1. Invoke skill **`intake`** untuk `<nama>` → tunggu gate (approve `business.md`).' "$f"  # 1
# warn pakai bahasa warn-only, BUKAN STOP/blokir
grep -Fn -iE 'STOP|blokir|gagal' "$f" | grep -i 'depends_on' && echo "cek konteks" || echo "warn-only ✓"
sed -n 's/^description: //p' "$f" | grep ': ' && echo "BOCOR!" || echo "desc clean ✓"
```
Expected: 1×7 · sub-1=1 · warn-only ✓ · desc clean ✓.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/feature/SKILL.md
git commit -m "feat(m1+m7+l2): feature — field epic/depends_on/risk (step1) + warn-gate depends_on (step2, warn-not-block) + doc-hint iterasi-v2 (Catatan)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: `build/SKILL.md` — baca risk + deteksi mode (step1) + klausa unattended (step6) + trigger (description) (M7)

**File:** Modify `plugin/skills/build/SKILL.md` (3 sub-step)

- [ ] **Step 1: step 1 — baca `risk` + deteksi mode unattended** — sisip sub-klausa SETELAH kalimat manifest-aktif (akhir paragraf intro step 1, sebelum bullet Staleness).

FIND (verbatim):
```
Kalau manifest **closed** (`shipped`/`dropped`) atau fitur `draft`, BERHENTI & jelaskan. Untuk work-item fix, `plans/*` boleh tak ada (kontrak ringan); `_shared.md` mini **wajib** bila fix lintas-unit.
```
REPLACE WITH:
```
Kalau manifest **closed** (`shipped`/`dropped`) atau fitur `draft`, BERHENTI & jelaskan. Untuk work-item fix, `plans/*` boleh tak ada (kontrak ringan); `_shared.md` mini **wajib** bila fix lintas-unit. **Risk + mode unattended (M7):** bila work-item fitur, baca juga `feature.yaml` `risk` (`low|normal|high`, default `normal` bila absen/typo — degrade fail-safe) untuk cadence gate step 6. **Deteksi mode unattended:** bila trigger memuat token `--unattended` ATAU user menyatakan maksud tanpa-pengawasan (mis. `build <fitur> unattended`, `jalanin yang aman tanpa aku`, `mode tanpa pengawasan`) → set mode unattended untuk run ini (ephemeral, per-run). Default = attended. Mode unattended HANYA berefek di step 6 untuk work-item fitur (work-item fix selalu attended; fix tak punya `risk`).
```

- [ ] **Step 2: step 6 — klausa unattended** — sisip SETELAH kalimat pertama gate (anchor = prefix kalimat pertama; REPLACE = prefix + sisanya verbatim + klausa). Karena kalimat pertama step 6 panjang & memuat metachar, gunakan anchor PREFIX yang stabil lalu append klausa di akhir kalimat. Anchor stabil = penutup kalimat pertama `(Detail: reference.md bagian D.)` di akhir step 6.

FIND (verbatim):
```
Task `unit: integration` membentuk segmen gate sendiri yang membentang tree unit di `deps`-nya (bukan satu app × milestone). (Detail: `reference.md` bagian D.)
```
REPLACE WITH:
```
Task `unit: integration` membentuk segmen gate sendiri yang membentang tree unit di `deps`-nya (bukan satu app × milestone). **Mode unattended (opt-in, hanya work-item fitur — M7):** bila mode unattended terdeteksi di step 1 (token `--unattended` atau maksud NL tanpa-pengawasan) DAN `feature.yaml` `risk` ∈ {`low`,`normal`} (absen di-treat `normal`) DAN segmen ini test-ijo + "dibangun vs task" COCOK (tak ada penyimpangan) → **auto-approve** segmen (catat ringkasan, lanjut loop tanpa stop user). **HARD floor — TETAP STOP walau unattended:** `risk: high`, task `migrate` (step 3), `needs_human` (step 2), `blocked` (step 5), ATAU penyimpangan-dari-maksud (jalankan disiplin fix embed seperti biasa). Catatan struktural: floor `migrate`/`needs_human`/`blocked` di-tegakkan di step 2/3/5 SEBELUM loop sampai gate step 6, jadi klausa ini tak mungkin auto-approve segmen yang punya floor-task belum-tuntas. Mode unattended MELONGGARKAN cadence gate yang ADA — BUKAN gate baru; tak pernah menyentuh Security Gate `ship`/migrate/needs_human. Tanpa mode = perilaku default (stop tiap segmen). (Detail: `reference.md` bagian D.)
```

- [ ] **Step 3: frontmatter `description:` — tambah varian trigger** (em-dash, TANPA `: `).

FIND (verbatim):
```
Trigger — "build <fitur>", "implement <fitur>", "kerjain <fitur>".
```
REPLACE WITH:
```
Trigger — "build <fitur>", "implement <fitur>", "kerjain <fitur>", "build <fitur> unattended" (mode tanpa pengawasan — auto-approve segmen risk rendah, lihat step 6).
```

- [ ] **Step 4: Verify** (+ colon-space guard)

```bash
f=plugin/skills/build/SKILL.md
grep -Fc -e '**Risk + mode unattended (M7):** bila work-item fitur, baca juga `feature.yaml` `risk`' "$f"  # 1 (step1)
grep -Fc -e '**Deteksi mode unattended:** bila trigger memuat token `--unattended`' "$f"  # 1 (step1)
grep -Fc -e '**Mode unattended (opt-in, hanya work-item fitur — M7):**' "$f"  # 1 (step6)
grep -Fc -e '**HARD floor — TETAP STOP walau unattended:** `risk: high`, task `migrate` (step 3), `needs_human` (step 2), `blocked` (step 5), ATAU penyimpangan-dari-maksud' "$f"  # 1 (floor lengkap)
grep -Fc -e 'MELONGGARKAN cadence gate yang ADA — BUKAN gate baru; tak pernah menyentuh Security Gate `ship`' "$f"  # 1 (honesty)
grep -Fc -e '"build <fitur> unattended" (mode tanpa pengawasan — auto-approve segmen risk rendah, lihat step 6).' "$f"  # 1 (trigger)
# anchor integration-segmen tetap 1× (REPLACE menjaga, bukan duplikat)
grep -Fc -e 'Task `unit: integration` membentuk segmen gate sendiri yang membentang tree unit di `deps`-nya (bukan satu app × milestone).' "$f"  # 1
# colon-space guard: description value bersih
sed -n 's/^description: //p' "$f" | grep ': ' && echo "BOCOR colon-space!" || echo "desc clean ✓"
```
Expected: 1×6 · integration=1 · desc clean ✓.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/build/SKILL.md
git commit -m "feat(m7): build — baca risk + deteksi mode unattended (step1) + klausa auto-approve+HARD-floor (step6) + trigger varian (description)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: `build/reference.md` — §D bullet `--unattended` (M7)

**File:** Modify `plugin/skills/build/reference.md` (1 edit)

- [ ] **Step 1: §D** — sisip bullet SETELAH bullet `Fitur 1-app`.

FIND (verbatim):
```
- **Fitur 1-app** → ciut jadi 1 gate.
```
REPLACE WITH:
```
- **Fitur 1-app** → ciut jadi 1 gate.
- **`--unattended` (opt-in, fitur saja — M7):** segmen ber-tier `risk` `low`/`normal` yang ijo + tak-menyimpang → auto-approve (lanjut tanpa stop). HARD floor tetap STOP: `risk: high` / `migrate` / `needs_human` / `blocked` / penyimpangan. Melonggarkan cadence ini, BUKAN menambah gate; tak menyentuh Security Gate `ship`. Default (tanpa flag) = stop tiap segmen.
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/build/reference.md
grep -Fc -e '- **`--unattended` (opt-in, fitur saja — M7):** segmen ber-tier `risk` `low`/`normal` yang ijo + tak-menyimpang → auto-approve' "$f"  # 1
grep -Fc -e 'Melonggarkan cadence ini, BUKAN menambah gate; tak menyentuh Security Gate `ship`. Default (tanpa flag) = stop tiap segmen.' "$f"  # 1
# anchor Fitur 1-app tetap 1×
grep -Fc -e '- **Fitur 1-app** → ciut jadi 1 gate.' "$f"  # 1
```
Expected: 1 / 1 / 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/build/reference.md
git commit -m "feat(m7): build/reference §D bullet --unattended (auto-approve risk rendah; HARD floor tetap STOP)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: `ask/SKILL.md` — feedback row (M8) + laporkan blueprint (L1)

**File:** Modify `plugin/skills/ask/SKILL.md` (2 sub-step, region distinct: tabel vs prose-bawah-tabel). **M1 ask cosmetic SKIP** (spec: ragu→skip).

- [ ] **Step 1a: tabel — feedback row (M8)** — sisip baris SETELAH fixes-row.

FIND (verbatim):
```
| Bug / known-issues / riwayat fix | `fixes/*/fix.yaml` (+ `notes.md`) |
```
REPLACE WITH:
```
| Bug / known-issues / riwayat fix | `fixes/*/fix.yaml` (+ `notes.md`) |
| Feedback / sinyal lapangan (keluhan/incident/request) | `feedback/*.md` |
```

- [ ] **Step 1b: prose — laporkan blueprint apa adanya (L1)** — sisip baris prose SETELAH baris lintas-domain (di luar tabel; tabel utuh).

FIND (verbatim):
```
Pertanyaan lintas-domain → buka >1 sumber.
```
REPLACE WITH:
```
Pertanyaan lintas-domain → buka >1 sumber.

> App ber-`responsibility` bertanda `(blueprint — belum di-bring-up)` (atau komentar `# blueprint, belum di-bring-up`) = baru di-declare, **belum dibangun**. Laporkan apa adanya ("declared, belum di-bring-up"), jangan sajikan sebagai app riil.
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/ask/SKILL.md
grep -Fc -e '| Feedback / sinyal lapangan (keluhan/incident/request) | `feedback/*.md` |' "$f"  # 1 (M8 row)
grep -Fc -e 'App ber-`responsibility` bertanda `(blueprint — belum di-bring-up)`' "$f"  # 1 (L1 prose)
grep -Fc -e 'Laporkan apa adanya ("declared, belum di-bring-up"), jangan sajikan sebagai app riil.' "$f"  # 1
# anchor utuh
grep -Fc -e '| Bug / known-issues / riwayat fix | `fixes/*/fix.yaml` (+ `notes.md`) |' "$f"  # 1
grep -Fc -e 'Pertanyaan lintas-domain → buka >1 sumber.' "$f"  # 1
sed -n 's/^description: //p' "$f" | grep ': ' && echo "BOCOR!" || echo "desc clean ✓"
```
Expected: 1 / 1 / 1 / 1 / 1 · desc clean ✓ (description ask TAK disentuh; pre-existing `: ` di description ask diabaikan — guard hanya untuk value yang DIUBAH; di sini tak diubah).

> **Catatan colon-space:** description `ask` TIDAK disentuh task ini. Bila `sed | grep ': '` melaporkan match, itu pre-existing & di luar scope (kita tak mengubah description). Yang penting: tak ada baris baru ber-`: ` di value YAML/description.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/ask/SKILL.md
git commit -m "feat(m8+l1): ask — read-surface feedback/*.md (M8) + laporkan app blueprint apa adanya (L1, reader truthfulness)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: `init/SKILL.md` — blueprint sub-bullet (Langkah 3) + marker (Langkah 5) (L1)

**File:** Modify `plugin/skills/init/SKILL.md` (2 sub-step, region distinct)

- [ ] **Step 1a: Langkah 3** — sisip sub-bullet OPSIONAL (indentasi 2 spasi) di bawah bullet "App apa saja"; no-renumber.

FIND (verbatim):
```
- App apa saja yang sudah kebayang? (greenfield: declare; existing: konfirmasi yang terdeteksi). Boleh mulai dari satu, tambah app lain nanti lewat skill `add-app`.
```
REPLACE WITH:
```
- App apa saja yang sudah kebayang? (greenfield: declare; existing: konfirmasi yang terdeteksi). Boleh mulai dari satu, tambah app lain nanti lewat skill `add-app`.
  - **(Opsional — blueprint app)** Kalau produk terdengar besar & app target sudah jelas sejak sekarang, boleh declare SEMUA app target sekaligus (semua masuk `apps[]` dengan `stack: {}` — lihat langkah 5). Tandai tiap app blueprint dengan menambah frasa `(blueprint — belum di-bring-up)` di akhir `responsibility`-nya + komentar `# blueprint, belum di-bring-up` pada entri-nya (lihat langkah 5), supaya pembaca seperti `ask`/`design-system`/`fanout` tahu app itu baru niat, belum dibangun. Ini cuma men-declare niat/topologi; bring-up (architect lalu wire) tetap per app saat app itu digarap — saat itu marker `(blueprint — belum di-bring-up)` dilepas. Produk kecil/belum jelas → cukup mulai satu, sisanya belakangan lewat `add-app`. (Nambah app sesudah init pertama tetap lewat `add-app`, bukan re-run init.)
```

- [ ] **Step 1b: Langkah 5** — sisip kalimat marker SETELAH baris existing-stack.

FIND (verbatim):
```
Untuk existing, isi `stack` per app dari hasil deteksi `package.json` (framework, db bila terbaca). Biarkan `packages: []` kosong — package tumbuh lewat `add-package`, bukan di-declare saat init.
```
REPLACE WITH:
```
Untuk existing, isi `stack` per app dari hasil deteksi `package.json` (framework, db bila terbaca). Biarkan `packages: []` kosong — package tumbuh lewat `add-package`, bukan di-declare saat init.
Untuk app yang di-declare sebagai blueprint (opsi blueprint langkah 3 — di-declare tapi belum di-bring-up) → tambahkan frasa `(blueprint — belum di-bring-up)` di akhir `responsibility`-nya DAN komentar inline `# blueprint, belum di-bring-up` pada baris entri (mis. baris `- name:`), supaya pembaca `apps[]` (`ask`/`design-system`/`fanout`) tahu app itu baru niat. `architect`/`wire` melepas frasa marker dari `responsibility` saat app betul-betul di-bring-up.
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/init/SKILL.md
grep -Fc -e '  - **(Opsional — blueprint app)** Kalau produk terdengar besar & app target sudah jelas sejak sekarang' "$f"  # 1 (L3 sub-bullet, indent 2)
grep -Fc -e 'Ini cuma men-declare niat/topologi; bring-up (architect lalu wire) tetap per app' "$f"  # 1 (declare≠scaffold)
grep -Fc -e '(Nambah app sesudah init pertama tetap lewat `add-app`, bukan re-run init.)' "$f"  # 1 (otoritas add-app)
grep -Fc -e 'Untuk app yang di-declare sebagai blueprint (opsi blueprint langkah 3 — di-declare tapi belum di-bring-up)' "$f"  # 1 (L5 marker)
grep -Fc -e '`architect`/`wire` melepas frasa marker dari `responsibility` saat app betul-betul di-bring-up.' "$f"  # 1
# anchor utuh
grep -Fc -e '- App apa saja yang sudah kebayang? (greenfield: declare; existing: konfirmasi yang terdeteksi). Boleh mulai dari satu, tambah app lain nanti lewat skill `add-app`.' "$f"  # 1
# frontmatter init TAK disentuh
sed -n 's/^description: //p' "$f" | grep ': ' && echo "BOCOR!" || echo "desc clean ✓"
```
Expected: 1×5 · anchor=1 · desc clean ✓.

> **Catatan:** description `init` memuat `Triggers — "init produk"...` tanpa `: ` di value; tak disentuh task ini. `(Opsional)` literal di sub-bullet = honesty wajib (L1 §7).

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/init/SKILL.md
git commit -m "feat(l1): init — sub-bullet opsional blueprint app (Langkah 3) + instruksi marker durable (Langkah 5); declare != scaffold

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Induk spec — M1 (§7/§9×2) + M7 (§12) + M8 (§7/§17/§9-Input) + L2 (§16)

**File:** Modify `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (8 sub-step, anchor DISTINCT — verified). Skill-count 21 & rules 5 TAK diubah.

- [ ] **Step 1a: §7 tree — komentar `feature.yaml` (M1)** — perkaya komentar inline (TANPA `: ` — pakai `;`/kurung; tak ubah box-drawing/alignment).

FIND (verbatim):
```
│       ├── feature.yaml  # status + metadata
```
REPLACE WITH:
```
│       ├── feature.yaml  # status + metadata (sensitivity; epic/depends_on M1; risk M7)
```

- [ ] **Step 1b: §7 tree — baris `feedback/` SEBELUM `fixes/` (M8)** — sibling top-level; alignment kolom `#` (fixes/ = 16 spasi sebelum `#`; feedback/ = 9 char → 13 spasi).

FIND (verbatim):
```
├── fixes/                # lane bugfix (post-ship) — entitas first-class
```
REPLACE WITH:
```
├── feedback/             # sinyal lapangan mentah (M8; di-drop manusia, dibaca intake SOFT)
├── fixes/                # lane bugfix (post-ship) — entitas first-class
```

- [ ] **Step 1c: §9 intake Perilaku — sizing-check (M1)** — append frasa di akhir bullet Perilaku intake.

FIND (verbatim):
```
- **Perilaku:** Q&A **level bisnis** (bukan teknis); cek feasibility kasar dari `capabilities`; jalankan **challenge checklist**; panggil `critic` di gate penting.
```
REPLACE WITH:
```
- **Perilaku:** Q&A **level bisnis** (bukan teknis); cek feasibility kasar dari `capabilities`; jalankan **challenge checklist**; panggil `critic` di gate penting; sizing-check advisory (fitur sebesar epik → usulkan pecah + isi `epic`/`depends_on`, M1); usulkan `risk` (`low`/`normal`/`high`; sensitivity non-kosong → floor `high`, M7).
```

- [ ] **Step 1d: §9 intake Input — feedback (M8)** — append `+ feedback/ (SOFT, opsional)` sebelum titik.

FIND (verbatim):
```
- **Input:** ide fitur + `business/*.md` + `workspace.yaml`.
```
REPLACE WITH:
```
- **Input:** ide fitur + `business/*.md` + `workspace.yaml` + `feedback/` (SOFT, opsional, M8).
```

- [ ] **Step 1e: §9 feature Perilaku — warn-gate (M1)** — sisip klausa warn SESUDAH "status `draft`)".

FIND (verbatim):
```
- **Perilaku:** buat `features/<nama>/` (`feature.yaml` status `draft`) → jalankan `intake` →(gate)→ `fanout` →(gate)→ `plan` semua app yang kena →(gate). Setelah gate `plan` terakhir lulus → status otomatis `active`.
```
REPLACE WITH:
```
- **Perilaku:** buat `features/<nama>/` (`feature.yaml` status `draft`; warn bila `depends_on` belum shipped — peringatan, BUKAN block, M1) → jalankan `intake` →(gate)→ `fanout` →(gate)→ `plan` semua app yang kena →(gate). Setelah gate `plan` terakhir lulus → status otomatis `active`.
```

- [ ] **Step 1f: §12 — kalimat risk (M7)** — sisip kalimat SETELAH kalimat sensitivity (paritas pola "Lihat spec ..." di paragraf yang sama).

FIND (verbatim):
```
`intake` menandai `feature.yaml` `sensitivity` (`payments`/`pii`) yang menyetir kedalaman Security & Compliance Gate di `ship`. Lihat spec `2026-06-01-platform-invariants-security-gate-design.md`.
```
REPLACE WITH:
```
`intake` menandai `feature.yaml` `sensitivity` (`payments`/`pii`) yang menyetir kedalaman Security & Compliance Gate di `ship`. Lihat spec `2026-06-01-platform-invariants-security-gate-design.md`. `intake` juga mengusulkan `feature.yaml` `risk` (`low`/`normal`/`high`; sensitivity non-kosong → floor `high`) yang menyetir **cadence approval** `build` saat mode unattended (M7) — axis terpisah dari `sensitivity`. Lihat spec `2026-06-06-m7-graduated-autonomy-design.md`.
```

- [ ] **Step 1g: §17 Knowledge — `feedback/` (M8)** — sisip ` · `feedback/`` SETELAH `features/` (sebelum `docs/`).

FIND (verbatim):
```
- **Knowledge (`control/`):** `workspace.yaml` (apps[] + packages[]) · `business/` · `conventions.md` · `invariants.md` · `integrations.md` · `design-system.md` · `schema/` · `features/` · `docs/`
```
REPLACE WITH:
```
- **Knowledge (`control/`):** `workspace.yaml` (apps[] + packages[]) · `business/` · `conventions.md` · `invariants.md` · `integrations.md` · `design-system.md` · `schema/` · `features/` · `feedback/` · `docs/`
```

- [ ] **Step 1h: §16 Future — lifecycle pasca-shipped (L2)** — append frasa di akhir bullet Future (sisip frasa, BUKAN bullet baru).

FIND (verbatim):
```
- **Future:** eksekusi/implementasi otomatis lintas-app (orchestrator), MCP knowledge server, status `in-review` (PR dibuka vs merged), auto-detect merge untuk trigger `shipped`.
```
REPLACE WITH:
```
- **Future:** eksekusi/implementasi otomatis lintas-app (orchestrator), MCP knowledge server, status `in-review` (PR dibuka vs merged), auto-detect merge untuk trigger `shipped`, **lifecycle pasca-`shipped` (iterasi-v2/deprecate/supersedes — status-machine lintas feature/ship/drop/render-docs; spec terpisah, lih. pipeline-hardening §S4.1/§10-4)**.
```

- [ ] **Step 2: Verify**

```bash
f=docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
grep -Fc -e '│       ├── feature.yaml  # status + metadata (sensitivity; epic/depends_on M1; risk M7)' "$f"  # 1 (§7 M1)
grep -Fc -e '├── feedback/             # sinyal lapangan mentah (M8; di-drop manusia, dibaca intake SOFT)' "$f"  # 1 (§7 M8)
grep -Fc -e 'sizing-check advisory (fitur sebesar epik → usulkan pecah + isi `epic`/`depends_on`, M1); usulkan `risk`' "$f"  # 1 (§9 intake Perilaku)
grep -Fc -e '- **Input:** ide fitur + `business/*.md` + `workspace.yaml` + `feedback/` (SOFT, opsional, M8).' "$f"  # 1 (§9 intake Input)
grep -Fc -e '(`feature.yaml` status `draft`; warn bila `depends_on` belum shipped — peringatan, BUKAN block, M1)' "$f"  # 1 (§9 feature Perilaku)
grep -Fc -e '`intake` juga mengusulkan `feature.yaml` `risk` (`low`/`normal`/`high`; sensitivity non-kosong → floor `high`) yang menyetir **cadence approval** `build`' "$f"  # 1 (§12 M7)
grep -Fc -e '· `features/` · `feedback/` · `docs/`' "$f"  # 1 (§17 M8)
grep -Fc -e 'lifecycle pasca-`shipped` (iterasi-v2/deprecate/supersedes — status-machine lintas feature/ship/drop/render-docs; spec terpisah, lih. pipeline-hardening §S4.1/§10-4)**.' "$f"  # 1 (§16 L2)
# GUARD: skill-count 21 + rules listing TAK berubah
grep -Fc -e '**Skills (21):**' "$f"  # 1
grep -Fc -e '`schema-projection.md` · `migration-impact.md` · `compliance-risk.md`' "$f"  # 1 (rules tetap 5, M6)
# GUARD: §7 fixes line tetap utuh (1×, REPLACE menambah feedback/ DI ATAS, bukan menggusur)
grep -Fc -e '├── fixes/                # lane bugfix (post-ship) — entitas first-class' "$f"  # 1
# alignment kolom # feedback/ vs fixes/ (cek kolom hash sama secara visual)
grep -nE '── (feedback|fixes)/' "$f"
# GUARD: plugin.json/marketplace/README tak ke-touch
git diff --name-only | grep -E 'plugin.json|marketplace.json|README' && echo "BOCOR!" || echo "core files clean ✓"
```
Expected: 1×8 · Skills(21)=1 · rules=1 · fixes=1 · alignment kolom `#` rata · core files clean ✓.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
git commit -m "docs(spec): sync induk — §7 feature.yaml komentar+feedback/ tree; §9 intake sizing/risk/feedback + feature warn-gate; §12 risk axis; §17 feedback/; §16 future iterasi-v2; skills 21 rules 5 tetap

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Verifikasi akhir (grep-battery + coherence) — sesi eksekusi

**Files:** (read-only; commit hanya bila ada fix)

- [ ] **Step 1: Grep-battery** (dari root repo)

```bash
echo "V0 feedback README ada + tanpa <PRODUCT>:"; test -f plugin/template/control/feedback/README.md && grep -Fc -e '<PRODUCT>' plugin/template/control/feedback/README.md  # expect 0
echo "V1 field feature.yaml 2 site identik (epic/depends_on/risk):"; for f in intake feature; do echo "$f:"; grep -Fc -e 'epic: ""' plugin/skills/$f/SKILL.md; grep -Fc -e 'depends_on: []' plugin/skills/$f/SKILL.md; grep -Fc -e 'risk: normal' plugin/skills/$f/SKILL.md; done  # each 1
echo "V2 intake M1+M7+M8 surfaces:"; grep -Fc -e '**Feedback (M8):**' plugin/skills/intake/SKILL.md; grep -Fc -e '**Sizing-check (advisory, M1):**' plugin/skills/intake/SKILL.md; grep -Fc -e '**Usulkan `risk` (M7)**' plugin/skills/intake/SKILL.md; grep -Fc -e '- Ada sinyal lapangan relevan di `feedback/`?' plugin/skills/intake/SKILL.md  # 1×4
echo "V3 feature warn-gate + L2 + field:"; grep -Fc -e '**Cek dependency (warn, BUKAN block — M1):**' plugin/skills/feature/SKILL.md; grep -Fc -e '- **Iterasi fitur yang sudah `shipped`**' plugin/skills/feature/SKILL.md  # 1×2
echo "V4 build M7 (step1+step6+desc) + reference §D:"; grep -Fc -e '**Deteksi mode unattended:**' plugin/skills/build/SKILL.md; grep -Fc -e '**Mode unattended (opt-in, hanya work-item fitur — M7):**' plugin/skills/build/SKILL.md; grep -Fc -e '"build <fitur> unattended"' plugin/skills/build/SKILL.md; grep -Fc -e '- **`--unattended` (opt-in, fitur saja — M7):**' plugin/skills/build/reference.md  # 1×4
echo "V5 HARD floor lengkap (high+migrate+needs_human+blocked+penyimpangan):"; grep -Fc -e '`risk: high`, task `migrate` (step 3), `needs_human` (step 2), `blocked` (step 5), ATAU penyimpangan-dari-maksud' plugin/skills/build/SKILL.md  # 1
echo "V6 ask (M8 row + L1 blueprint):"; grep -Fc -e '`feedback/*.md`' plugin/skills/ask/SKILL.md; grep -Fc -e '(blueprint — belum di-bring-up)' plugin/skills/ask/SKILL.md  # 1×2
echo "V7 init L1 (L3 sub-bullet + L5 marker):"; grep -Fc -e '**(Opsional — blueprint app)**' plugin/skills/init/SKILL.md; grep -Fc -e 'Untuk app yang di-declare sebagai blueprint' plugin/skills/init/SKILL.md  # 1×2
echo "V8 induk 8 amandemen:"; grep -Fc -e '(sensitivity; epic/depends_on M1; risk M7)' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md; grep -Fc -e '├── feedback/             # sinyal lapangan' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md; grep -Fc -e '· `features/` · `feedback/` · `docs/`' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md; grep -Fc -e 'lifecycle pasca-`shipped` (iterasi-v2/deprecate/supersedes' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md  # 1×4
echo "V9 skill-count 21 + rules 5 + core files clean:"; grep -Fc -e '**Skills (21):**' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md; git diff --name-only main..HEAD | grep -E 'plugin.json|marketplace.json|^README' && echo "BOCOR!" || echo "clean ✓"
echo "V10 colon-space — build description value bersih (satu-satunya desc disentuh):"; sed -n 's/^description: //p' plugin/skills/build/SKILL.md | grep ': ' && echo "BOCOR!" || echo "clean ✓"
echo "V11 anti-palang-keras hulu (M1 warn/M8 SOFT/L1 opsional = advisory, BUKAN STOP baru):"; grep -rn -iE 'blokir|hard.gate|gagalkan' plugin/skills/intake/SKILL.md plugin/skills/feature/SKILL.md plugin/skills/init/SKILL.md plugin/template/control/feedback/README.md && echo "cek konteks" || echo "clean ✓"
echo "V12 M6 anchor preserved (tak terhapus oleh sisipan M8/M1/M7):"; grep -Fc -e '- Menyentuh kewajiban compliance di `risks.md`? (PCI/GDPR/pajak/KYC) — kutip + pastikan tertangani (advisory).' plugin/skills/intake/SKILL.md  # 1
```
Expected: V0 0 · V1 each 1 · V2 1×4 · V3 1×2 · V4 1×4 · V5 1 · V6 1×2 · V7 1×2 · V8 1×4 · V9 1 + clean ✓ · V10 clean ✓ · V11 clean ✓ · V12 1.

- [ ] **Step 2: Coherence read** — baca diff `main..HEAD`, pastikan:
  - **Field-order `feature.yaml` identik** di intake & feature step 1: `sensitivity` → `epic` → `depends_on` → `risk` (no drift).
  - **M1 honesty:** warn-gate `feature` step 2 pakai "peringatan/konfirmasi/boleh lanjut" (BUKAN STOP/blokir); timing-note jujur (run-pertama skip). Sizing intake step 4 = "usulkan/advisory".
  - **M7 honesty:** build step 6 "MELONGGARKAN cadence yang ADA, BUKAN gate baru"; HARD floor lengkap 5; ship/security tak disentuh; deteksi mode NL + token; trigger discoverable di description.
  - **M8 honesty:** intake baca SOFT (step 2) + paksa-tampil (step 5); README penulis=manusia, tak ada auto-ingest; degrade-mulus; tak ada render-docs/gate.
  - **L1 honesty:** sub-bullet literal "(Opsional)"; declare ≠ scaffold; marker dibaca `ask`; discovery-skip diakui (di spec, bukan shipped).
  - **L2 honesty:** doc-hint, NOL perubahan perilaku; gap inti future di induk §16; `<nama>-v2` = nama manual bukan machinery.
  - **Non-tabrakan:** tak ada region overlap; M6 anchor utuh; §7 M1(komentar feature.yaml) ≠ §7 M8(feedback/ tree); §9 intake Perilaku/Input/feature Perilaku tiga anchor beda.
  - **Skill 21, rules 5, plugin.json/marketplace/README tak tersentuh.**
  Catat temuan.

- [ ] **Step 3: Selesai (sesi ini)** — JANGAN merge/push. Lapor: plan tereksekusi, N commit (≈8 + Task 0 bila perlu), tree clean. **Post-exec adversarial verify = sesi LAIN** (fresh-eyes: faithful-exec / seam penulis↔reader / mis-aimed-pointer / parent-doc-staleness / anti-fiksi-advisory / field-order-drift / colon-space / honesty-in-shipped-text), baru FF-merge + push + hapus branch + update memory.

---

## Self-Review (penulis plan)

**1. Spec coverage** (tiap requirement → task):
- M1 §4 field epic/depends_on (2 site) → Task 2 step1a + Task 3 step1a. §6b warn-gate → Task 3 step1b. §6c sizing → Task 2 step1c. §6d ask cosmetic → **SKIP** (spec: ragu→skip). §7 parent §7/§9×2 → Task 8 step1a/1c/1e. §18 → SKIP (opsional).
- M7 §3 field risk (2 site) → Task 2 step1a + Task 3 step1a (GABUNG M1). §4b intake step7 usulkan+floor → Task 2 step1e. §4c build step1/step6/desc → Task 4. reference §D → Task 5. §7 parent §12 → Task 8 step1f. §7 tree opsi A → tak edit (DIPUTUSKAN opsi A; tapi Task 8 step1a komentar feature.yaml menambah "risk M7" — selaras opsi B aman karena gabung dgn M1, anchor unik, tanpa `: `).
- M8 §5 README → Task 1. §6a intake step2/step5 → Task 2 step1b/1d. §6b ask row → Task 6 step1a. §6c init = no-edit (cp -R) → tak ada task (verified template netral). §11 parent §7/§17/§9-Input → Task 8 step1b/1g/1d.
- L1 §5a init L3 → Task 7 step1a. §5a-bis ask → Task 6 step1b. §5b init L5 → Task 7 step1b. §6 parent NOL wajib → tak ada task (§9 init klausa = SKIP default).
- L2 §3.A feature Catatan → Task 3 step1c. §4 induk §16 → Task 8 step1h. (render-docs/template = milik L3, di luar plan.)
→ **Tak ada gap wajib.**

**2. Non-tabrakan (a/b/c terpenuhi):**
- (a) Section "Urutan & non-tabrakan" memetakan FILE→edit semua item; urut top→bottom dalam tiap file.
- (b) Region OVERLAP cuma di `feature.yaml` creation line (`sensitivity`) → **DIGABUNG** M1+M7 jadi satu REPLACE (Task 2 step1a, Task 3 step1a). Tak ada dua task ngedit region sama.
- (c) Anchor tiap edit = teks stabil tak diubah edit lain (verified =1). M6 anchor dipertahankan verbatim dalam REPLACE M8/M1/M7.

**3. Anchor verification:** SEMUA FIND di-`grep -Fc -e` = 1 saat penulisan plan (tabel "Ringkasan verifikasi anchor"). build description value colon-space = 0 (clean). Field-order contract sumber M1 §4 + M7 §4a. Komentar `feature.yaml` baru pakai `;`/em-dash/kurung/koma (TANPA `: ` di value). M7 description varian pakai em-dash (TANPA `: `). Tree alignment §7 feedback/ = 13 spasi (kolom `#` rata dgn fixes/ 16 spasi, 9-char vs 6-char unit). No-renumber: semua sisipan field/sub-bullet/klausa/baris-tree/baris-tabel. Mis-aimed-pointer: "langkah 5"/"step 1/2/3/5/6"/"§12/§16/§S4.1/§10-4" verified. Skill-count 21 & rules 5 di-guard di Task 8 + Task 9 V9.
