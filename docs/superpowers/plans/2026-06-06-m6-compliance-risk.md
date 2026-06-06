# M6 — Compliance-Risk Discovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (sesi terpisah, per handoff). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tangkap pengetahuan compliance/regulasi (PCI/GDPR/pajak/KYC) yang selama ini dibuang `discovery` ke HTML — jadi file durable `control/business/risks.md`, lalu dibaca `architect` (kunci invarian PII/PCI), `intake` (constraint per-fitur + perkuat sensitivity), `ship`/`security-critic` (baseline red-team). Semua **advisory** (di hilir `ship` memperkaya gate existing, bukan gate baru). Tutup gap M6 (quick-win Langkah-3) tanpa nambah skill (tetap 21); rules 4→5.

**Architecture:** Penulis tunggal = `discovery` (carve-out §D melonggarkan ke `terverifikasi`+`asumsi` khusus compliance). `risks.md` = slot+sentinel (cermin `invariants.md`). Otak bersama = `rules/compliance-risk.md` (cermin `rules/migration-impact.md`): carve-out boundary + advisory + degrade + anti-fiksi. Pembaca read-only; tak ada pembaca menulis `risks.md`. `risks.md` = lanskap regulasi HULU yang memberi makan slot `invariants.md` PII/PCI + tag `sensitivity` — **bukan** duplikatnya. Spec: `docs/superpowers/specs/2026-06-06-m6-compliance-risk-design.md`.

**Tech Stack:** Markdown skill/rule/template files. Tak ada kode runtime. "Test" = grep-battery anchor verification (analog TDD untuk file instruksi) + coherence read.

**Branch:** `m6-compliance-risk` (sudah dibuat). Eksekusi & post-exec verify = **sesi terpisah** (jangan execute di sesi penulisan plan). Commit spec+plan dulu (Task 0).

**Bug-guard pre-bake (berlaku semua task):**
- **colon-space frontmatter:** M6 **mengubah `description:` `security-critic.md`** (Task 7 step 1d) — tambah `risks.md` pakai separator `/`, **TANPA `: `**. Cek pasca-edit `sed -n 's/^description: //p' plugin/agents/security-critic.md | grep ': '` tetap **kosong**. Skill/agent lain: edit body, bukan description.
- **no-renumber:** semua sisipan = klausa/sub-bullet/sibling-line/heading/baris-tree baru — **JANGAN** renumber langkah/step skill (architect 4.5, intake 2/5/7, ship 4.5, discovery 7, security-critic langkah 1/2).
- **mis-aimed-pointer:** ship-gate prose induk ada di **§9 (### ship, line ~210)** BUKAN §17; rules muncul di DUA tempat induk (§8 tree line 137 + §17 Rules line 305); tree business/ di §7 line 69.
- **anchor verify:** tiap find/replace di-`grep -Fc -e`-kan verbatim (robust leading-dash `- `, metachar `[]`/`**`/backtick, em-dash `—`, middot `·` U+00B7, spasi-alignment tree) SEBELUM commit.
- **anti-duplikasi:** `risks.md` di-frame *constraint/baseline/input* (advisory) — **bukan** pengganti slot `invariants.md` PII/PCI atau tag `sensitivity`.
- **anti-palang-keras:** klausa di discovery/architect/intake = advisory; satu-satunya STOP = Security Gate `ship` existing (high→RED, ambang TAK diubah). Jangan tambah cek-blokir runtime.
- **carve-out:** cuma compliance yang durable; pasar/kompetitor/monetisasi/verdict + risiko `spekulatif` TETAP di HTML.
- **scope:** 4 kategori inti (PCI/GDPR/pajak/KYC) + baris bebas — **JANGAN** jadikan aksesibilitas/ToS kategori tetap (user tolak).
- **skill-count:** TETAP 21 — `plugin.json`/`marketplace.json`/README **TIDAK** disentuh.
- Tiap commit diakhiri trailer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

### Task 0: Commit spec + plan (branch `m6-compliance-risk`)

**Files:**
- Add: `docs/superpowers/specs/2026-06-06-m6-compliance-risk-design.md` (sudah ada, hasil brainstorming + self-review)
- Add: `docs/superpowers/plans/2026-06-06-m6-compliance-risk.md` (file ini)

- [ ] **Step 1: Commit**

```bash
git add docs/superpowers/specs/2026-06-06-m6-compliance-risk-design.md docs/superpowers/plans/2026-06-06-m6-compliance-risk.md
git commit -m "docs(m6): spec + plan compliance-risk discovery (advisory; risks.md durable + 4 consumer; 6-dim self-review fixed)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 1: NEW template `control/business/risks.md`

**Files:**
- Create: `plugin/template/control/business/risks.md`
- Test: grep-battery di file baru

- [ ] **Step 1: Tulis file** (verbatim)

````markdown
# <PRODUCT> — Risiko Compliance

> Kewajiban hukum/regulasi DURABLE yang berlaku ke produk; di-seed `discovery` (carve-out compliance), dibaca `architect` (kunci invarian PII/PCI), `intake` (constraint per-fitur), `ship` (baseline red-team).
> Cuma compliance/regulasi di sini — risiko pasar/kompetitor TINGGAL di `docs/discovery.html`.
> Tiap slot: ISI kewajibannya, ATAU tulis "N/A — <alasan>" — jangan tinggalkan pada penanda kosong sebelum produk jalan.
> Bentuk entri tiap slot: pemicu (apa yang mengaktifkan) — kewajiban (apa yang harus dilakukan) — [label keyakinan] — sumber. Tambah baris bebas untuk regulasi spesifik-produk.

## PCI (kartu / pembayaran)
<belum dinilai>

## GDPR / Privasi (data pribadi)
<belum dinilai>

## Pajak (jurisdiksi / PPN)
<belum dinilai>

## KYC / AML (verifikasi identitas)
<belum dinilai>
````

- [ ] **Step 2: Verify** (grep-battery)

```bash
f=plugin/template/control/business/risks.md
test -f "$f" && echo "EXISTS ✓"
grep -Fc -e '# <PRODUCT> — Risiko Compliance' "$f"          # expect 1 (placeholder <PRODUCT>)
grep -Fc -e '## PCI (kartu / pembayaran)' "$f"              # expect 1
grep -Fc -e '## GDPR / Privasi (data pribadi)' "$f"         # expect 1
grep -Fc -e '## Pajak (jurisdiksi / PPN)' "$f"              # expect 1
grep -Fc -e '## KYC / AML (verifikasi identitas)' "$f"      # expect 1
grep -Fc -e '<belum dinilai>' "$f"                          # expect 4 (sentinel tiap slot)
grep -Fc -e 'risiko pasar/kompetitor TINGGAL di `docs/discovery.html`' "$f"  # expect 1 (carve-out)
```
Expected: EXISTS ✓ · 1 · 1 · 1 · 1 · 1 · 4 · 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/template/control/business/risks.md
git commit -m "feat(m6): template control/business/risks.md — slot compliance (PCI/GDPR/pajak/KYC) + sentinel

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: NEW rule `rules/compliance-risk.md`

**Files:**
- Create: `plugin/rules/compliance-risk.md`
- Test: grep-battery di file baru

- [ ] **Step 1: Tulis file** (verbatim)

````markdown
# Compliance Risk — risiko compliance durable (aturan share)

Dirujuk skill yang menulis/membaca kewajiban compliance di `control/business/risks.md`: **penulis** `discovery` (seed carve-out); **pembaca** `architect` (kunci invarian PII/PCI), `intake` (constraint per-fitur + perkuat `sensitivity`), `ship`/`security-critic` (baseline red-team). **BUKAN langkah berdiri sendiri** — dokumentasi + prosedur ringan yang dipanggil pemanggil itu. Semua **advisory**.

## Penulis tunggal = discovery (pembaca read-only)
Hanya `discovery` yang menulis `risks.md` (seed pra-init). **Tak ada pembaca yang menulis** `risks.md`. Bila pembaca menemukan gap compliance baru → **angkat ke user** (advisory), JANGAN tulis diam-diam. Efek "gap baru" beda per kelas pembaca (lihat Advisory di bawah).

## Batas carve-out (definisi tunggal)
- **DURABLE ke `risks.md`:** kewajiban **compliance/regulasi** lepas-dari-fitur — PCI (kartu/bayar) · GDPR/privasi (data pribadi) · pajak (jurisdiksi/PPN) · KYC/AML (identitas) + regulasi sektor/jurisdiksi spesifik. Label `terverifikasi`/`asumsi` + sumber/alasan.
- **TINGGAL di HTML** (`control/docs/discovery.html`): pasar, kompetitor, monetisasi, verdict, dan risiko ber-label `spekulatif`.
- **Melonggarkan §D discovery secara sadar & terbatas:** aturan §D existing izinkan HANYA `terverifikasi` nyebrang ke `business/` (`asumsi` JANGAN). Carve-out compliance izinkan `terverifikasi`+`asumsi` **khusus sub-kelas compliance** — karena (i) M6 advisory (false-positive = sekadar peringatan, murah) dan (ii) **under-detect compliance lebih bahaya** dari over-detect.
- **Aturan-batas overlap (compliance vs market-risk):** satu temuan regulasi bisa punya dua dimensi — *compliance-obligation* (apa yang HARUS dilakukan agar legal) DAN *market-risk* (apakah regulasi mengancam viabilitas). Pembagi: **kewajibannya nyebrang ke `risks.md`; analisis dampak-pasarnya tetap HTML.**

## Bentuk entri
Per slot kategori: **pemicu — kewajiban — [label keyakinan] — sumber.** Baris bebas untuk regulasi lain. Slot tak relevan → `N/A — alasan`. Sentinel `<belum dinilai>` = belum diisi.

## Advisory (cara tiap pembaca pakai)
Kewajiban dimunculkan sebagai **constraint/catatan**; rule **TAK memblokir** architect/intake/feature. Satu-satunya STOP = Security Gate `ship` existing (high-sev → RED) — mekanisme yang ADA, bukan gate baru.
- **Pembaca-elicitation (`architect`/`intake`):** cocokkan keputusan/fitur dgn kewajiban → perkaya elicitation; gap baru → angkat advisory, lanjut.
- **Pembaca-gate (`security-critic` di `ship`):** subagent read-only ber-output daftar temuan; kewajiban yang dilanggar & dinilai **high → jadi RED** lewat mekanisme `ship` existing (memang fungsinya), bukan "angkat lalu lanjut". Konsekuensi: himpunan temuan RED bisa **melebar** (diff yang langgar kewajiban yg kini diketahui) — dikehendaki, sejajar menambah invarian. **Terbatas** ke fitur ber-`sensitivity` `payments`/`pii` (security-critic cuma di-invoke di situ).

## Anti-fiksi
Kewajiban berasal dari **riset `discovery` yang bersumber** (aturan label/sitasi `discovery/reference.md` §B/§C), **bukan** dikarang pembaca. JANGAN nyandar artifact fiksi.

## Degrade-ke-best-effort
`risks.md` tak ada / semua slot `<belum dinilai>` / produk tanpa discovery → pembaca jalan "best-effort, tak ada kewajiban compliance diketahui" + tetap pakai mekanisme existing (heuristik sensitivity intake, Q&A architect, scan security-critic). **JANGAN error, JANGAN blokir.**

## Generik & batas
- **Generik:** kategori PCI/GDPR/pajak/KYC lintas-domain; tak hardcode jurisdiksi/stack; baris bebas tampung regulasi spesifik.
- **Batas (sadar):** `risks.md` hanya selengkap riset discovery; produk yang skip discovery / regulasi yang luput riset tak tertangkap → gate manusia (architect/ship) = jaring akhir.
````

- [ ] **Step 2: Verify** (grep-battery)

```bash
f=plugin/rules/compliance-risk.md
test -f "$f" && echo "EXISTS ✓"
grep -Fc -e 'Penulis tunggal = discovery' "$f"                    # expect 1
grep -Fc -e 'Melonggarkan §D discovery secara sadar & terbatas' "$f"  # expect 1 (carve-out jujur)
grep -Fc -e 'under-detect compliance lebih bahaya' "$f"           # expect 1
grep -Fc -e 'Aturan-batas overlap (compliance vs market-risk)' "$f"  # expect 1
grep -Fc -e 'TAK** memblokir' "$f"                                # expect 1 (advisory)
grep -Fc -e 'Pembaca-gate (`security-critic` di `ship`)' "$f"     # expect 1 (kelas pembaca)
grep -Fc -e 'Degrade-ke-best-effort' "$f"                         # expect 1
grep -Fc -e 'dikarang pembaca' "$f"                               # expect 1 (anti-fiksi)
```
Expected: EXISTS ✓ + tiap grep = 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/rules/compliance-risk.md
git commit -m "feat(m6): rules/compliance-risk.md — carve-out + advisory + degrade + anti-fiksi (penulis tunggal discovery)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `discovery/reference.md` — §A sub-prompt compliance + §D carve-out

**Files:**
- Modify: `plugin/skills/discovery/reference.md` (§A baris 15, §D baris 39)
- Test: grep anchor

- [ ] **Step 1a: §A** — append klausa compliance ke bullet Risiko (no-renumber; perdalam riset regulasi).

FIND (verbatim):
```
- **Risiko** — Apa yang bisa bikin gagal (pasar jenuh, switching cost tinggi, regulasi, beratnya eksekusi)?
```
REPLACE WITH:
```
- **Risiko** — Apa yang bisa bikin gagal (pasar jenuh, switching cost tinggi, regulasi, beratnya eksekusi)? **Compliance (durable, carve-out ke `risks.md`):** nilai terstruktur kewajiban regulasi — **PCI** (kartu/bayar) · **GDPR/privasi** (data pribadi) · **pajak** (jurisdiksi/PPN) · **KYC/AML** (identitas) + regulasi sektor/jurisdiksi spesifik. Lihat `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`.
```

- [ ] **Step 1b: §D** — sisip baris pengecualian compliance SESUDAH baris larangan (no-renumber; melonggarkan §D).

FIND (verbatim):
```
Yang `asumsi`/`spekulatif` & SEMUA analisis pasar (pasar, kompetitor, monetisasi, risiko, verdict) TINGGAL di HTML — JANGAN masuk `business/`.
```
REPLACE WITH:
```
Yang `asumsi`/`spekulatif` & SEMUA analisis pasar (pasar, kompetitor, monetisasi, risiko, verdict) TINGGAL di HTML — JANGAN masuk `business/`.

**Pengecualian compliance (carve-out M6):** kewajiban regulasi (PCI/GDPR/pajak/KYC + spesifik-produk) ber-label `terverifikasi`/`asumsi` + sumber **nyebrang ke `control/business/risks.md`** — ini **melonggarkan** aturan "hanya `terverifikasi`" di atas KHUSUS sub-kelas compliance (alasan: advisory, under-detect lebih bahaya). Analisis pasar/kompetitor/monetisasi/verdict + risiko `spekulatif` TETAP di HTML. Pembagi overlap & detail: `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`.
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/discovery/reference.md
grep -Fc -e '**Compliance (durable, carve-out ke `risks.md`):** nilai terstruktur kewajiban regulasi' "$f"  # expect 1 (§A)
grep -Fc -e '**Pengecualian compliance (carve-out M6):**' "$f"  # expect 1 (§D)
grep -Fc -e 'ini **melonggarkan** aturan "hanya `terverifikasi`" di atas KHUSUS sub-kelas compliance' "$f"  # expect 1
# anchor §A/§D utuh
grep -Fc -e '- **Risiko** — Apa yang bisa bikin gagal (pasar jenuh, switching cost tinggi, regulasi, beratnya eksekusi)?' "$f"  # expect 1
grep -Fc -e 'Yang `asumsi`/`spekulatif` & SEMUA analisis pasar (pasar, kompetitor, monetisasi, risiko, verdict) TINGGAL di HTML — JANGAN masuk `business/`.' "$f"  # expect 1
```
Expected: 1 / 1 / 1 / 1 / 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/discovery/reference.md
git commit -m "feat(m6): discovery §A riset 4-kategori compliance + §D carve-out durable ke risks.md (melonggarkan sadar)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: `discovery/SKILL.md` — step 7.2 seed `risks.md`

**Files:**
- Modify: `plugin/skills/discovery/SKILL.md` (step 7 sub-2, baris 34)
- Test: grep anchor

- [ ] **Step 1: Edit** — tambah `risks.md` ke daftar seed (no-renumber; kualifikasi pengecualian compliance agar tak kontradiksi "asumsi JANGAN").

FIND (verbatim):
```
2. SEED `business/` (KONSERVATIF, hanya `terverifikasi` & durable — `reference.md` bagian D): `domain.md` (Produk/Pengguna/Nilai + `## Aturan Domain` awal bila jelas), `glossary.md` (istilah), `flows.md` (flow kunci bila ada). Yang `asumsi`/`spekulatif` & analisis pasar JANGAN dimasukkan.
```
REPLACE WITH:
```
2. SEED `business/` (KONSERVATIF, hanya `terverifikasi` & durable — `reference.md` bagian D): `domain.md` (Produk/Pengguna/Nilai + `## Aturan Domain` awal bila jelas), `glossary.md` (istilah), `flows.md` (flow kunci bila ada), **`risks.md`** (kewajiban compliance dari seksi Risiko — `terverifikasi`/`asumsi`+sumber, carve-out M6, lihat `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`; slot tak relevan → `N/A — alasan`). Yang `asumsi`/`spekulatif` & analisis pasar JANGAN dimasukkan (kecuali kewajiban compliance → `risks.md`).
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/discovery/SKILL.md
grep -Fc -e '**`risks.md`** (kewajiban compliance dari seksi Risiko — `terverifikasi`/`asumsi`+sumber, carve-out M6' "$f"  # expect 1
grep -Fc -e 'JANGAN dimasukkan (kecuali kewajiban compliance → `risks.md`).' "$f"  # expect 1 (no kontradiksi)
grep -Fc -e '${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md' "$f"  # expect 1
```
Expected: 1 / 1 / 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/discovery/SKILL.md
git commit -m "feat(m6): discovery step7 seed risks.md (carve-out compliance, rujuk rule)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: `architect/SKILL.md` — step 4.5 baca `risks.md` (constraint)

**Files:**
- Modify: `plugin/skills/architect/SKILL.md` (step 4.5, baris 40)
- Test: grep anchor

- [ ] **Step 1: Edit** — append klausa compliance-constraint ke bullet ELICIT (no-renumber; advisory + degrade).

FIND (verbatim):
```
- Kalau ada slot `<belum dikunci>`: **ELICIT** per slot keputusannya (level fondasi, bukan stack). User boleh jawab `N/A — alasan`. Sodorkan slot saran; terima invarian tambahan spesifik-produk. Tulis hasil ke `control/invariants.md` (ganti `<belum dikunci>`).
```
REPLACE WITH:
```
- Kalau ada slot `<belum dikunci>`: **ELICIT** per slot keputusannya (level fondasi, bukan stack). User boleh jawab `N/A — alasan`. Sodorkan slot saran; terima invarian tambahan spesifik-produk. Tulis hasil ke `control/invariants.md` (ganti `<belum dikunci>`). **Compliance constraint (M6):** baca `control/business/risks.md` (bila ada) saat ELICIT slot **PII/PCI & Money & Currency** — cocokkan keputusan teknis dgn kewajiban regulasi yang diketahui (mis. risks.md sebut PCI → slot PII/PCI harus menutup penanganan kartu). Advisory; degrade bila absen/sentinel. Lihat `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`.
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/architect/SKILL.md
grep -Fc -e '**Compliance constraint (M6):** baca `control/business/risks.md` (bila ada) saat ELICIT slot **PII/PCI & Money & Currency**' "$f"  # expect 1
grep -Fc -e 'Advisory; degrade bila absen/sentinel. Lihat `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`.' "$f"  # expect 1
# anchor 4.5 utuh
grep -Fc -e '- Kalau ada slot `<belum dikunci>`: **ELICIT** per slot keputusannya (level fondasi, bukan stack).' "$f"  # expect 1
```
Expected: 1 / 1 / 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/architect/SKILL.md
git commit -m "feat(m6): architect 4.5 baca risks.md sbg constraint kunci invarian PII/PCI & Money (advisory, degrade)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: `intake/SKILL.md` — step 2 baca + step 5 challenge + step 7 sensitivity

**Files:**
- Modify: `plugin/skills/intake/SKILL.md` (step 2 baris 22, step 5 baris 34, step 7 baris 51)
- Test: grep anchor

- [ ] **Step 1a: step 2** — tambah `risks.md` ke daftar baca.

FIND (verbatim):
```
Baca `control/business/*.md` (domain, flows, glossary) + `control/workspace.yaml` (apps + capabilities).
```
REPLACE WITH:
```
Baca `control/business/*.md` (domain, flows, glossary, **`risks.md`** — kewajiban compliance, constraint per-fitur) + `control/workspace.yaml` (apps + capabilities).
```

- [ ] **Step 1b: step 5** — sisip bullet compliance SETELAH bullet terakhir Challenge Checklist (no-renumber).

FIND (verbatim):
```
- Apa yang bisa jebol / risiko?
```
REPLACE WITH:
```
- Apa yang bisa jebol / risiko?
- Menyentuh kewajiban compliance di `risks.md`? (PCI/GDPR/pajak/KYC) — kutip + pastikan tertangani (advisory).
```

- [ ] **Step 1c: step 7** — append klausa perkuat-sensitivity ke akhir kalimat usulan tag.

FIND (verbatim):
```
**Usulkan tag `sensitivity`** dari isi `business.md` (heuristik): `payments` kalau fitur menggerakkan/menyimpan uang (bayar, billing, payout, refund, fee); `pii` kalau mengumpulkan/menyimpan/menampilkan data pribadi (nama, email, alamat, telp, gov-id). Cross-check ringan ke `control/invariants.md` — kalau slot PII/PCI di-`N/A`, jangan ngotot tag `pii`. Tulis usulan ke `feature.yaml` `sensitivity:` (kosong boleh).
```
REPLACE WITH:
```
**Usulkan tag `sensitivity`** dari isi `business.md` (heuristik): `payments` kalau fitur menggerakkan/menyimpan uang (bayar, billing, payout, refund, fee); `pii` kalau mengumpulkan/menyimpan/menampilkan data pribadi (nama, email, alamat, telp, gov-id). Cross-check ringan ke `control/invariants.md` — kalau slot PII/PCI di-`N/A`, jangan ngotot tag `pii`. Tulis usulan ke `feature.yaml` `sensitivity:` (kosong boleh). **Compliance (M6):** kalau fitur cocok dgn pemicu di `control/business/risks.md` → **perkuat** usulan tag + sebut kewajibannya sbg alasan (advisory; heuristik teks tetap jalan tanpa `risks.md`). Lihat `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`.
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/intake/SKILL.md
grep -Fc -e 'Baca `control/business/*.md` (domain, flows, glossary, **`risks.md`** — kewajiban compliance, constraint per-fitur)' "$f"  # expect 1 (step2)
grep -Fc -e '- Menyentuh kewajiban compliance di `risks.md`? (PCI/GDPR/pajak/KYC) — kutip + pastikan tertangani (advisory).' "$f"  # expect 1 (step5)
grep -Fc -e '**Compliance (M6):** kalau fitur cocok dgn pemicu di `control/business/risks.md` → **perkuat** usulan tag' "$f"  # expect 1 (step7)
# anchor step5 utuh
grep -Fc -e '- Apa yang bisa jebol / risiko?' "$f"  # expect 1
```
Expected: 1 / 1 / 1 / 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/intake/SKILL.md
git commit -m "feat(m6): intake baca risks.md (step2) + challenge compliance (step5) + perkuat sensitivity (step7)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: `agents/security-critic.md` — input + langkah 1 + lensa + description

**Files:**
- Modify: `plugin/agents/security-critic.md` (description baris 3, "Kamu menerima" baris 9, langkah 1 baris 12, langkah 2 PCI bullet baris 16)
- Test: grep anchor + colon-space guard

- [ ] **Step 1a: "Kamu menerima"** — sisip `risks.md` ke set input (body — colon `:` OK di body, pakai ` — ` biar konsisten).

FIND (verbatim):
```
Kamu menerima: diff fitur (path + range/SHA per repo) + `control/invariants.md` (baseline invarian Tenancy/Authz/PII-PCI + Integrasi/Webhook) + `control/conventions.md` + `control/integrations.md` (kontrak SHAPE vendor — baseline webhook signature/mode/idempotency).
```
REPLACE WITH:
```
Kamu menerima: diff fitur (path + range/SHA per repo) + `control/invariants.md` (baseline invarian Tenancy/Authz/PII-PCI + Integrasi/Webhook) + `control/conventions.md` + `control/integrations.md` (kontrak SHAPE vendor — baseline webhook signature/mode/idempotency) + `control/business/risks.md` (baseline kewajiban compliance — PCI/GDPR/pajak/KYC).
```

- [ ] **Step 1b: langkah 1** — tambah `risks.md` ke daftar baca.

FIND (verbatim):
```
1. Baca diff + `control/invariants.md` + `control/conventions.md` + `control/integrations.md`.
```
REPLACE WITH:
```
1. Baca diff + `control/invariants.md` + `control/conventions.md` + `control/integrations.md` + `control/business/risks.md`.
```

- [ ] **Step 1c: langkah 2 lensa** — sisip bullet compliance SETELAH bullet "Data kartu (PCI)" (no-renumber).

FIND (verbatim):
```
   - **Data kartu (PCI)** — PAN/CVV/expiry disimpan ke DB atau di-log → pelanggaran PCI-DSS.
```
REPLACE WITH:
```
   - **Data kartu (PCI)** — PAN/CVV/expiry disimpan ke DB atau di-log → pelanggaran PCI-DSS.
   - **Langgar kewajiban compliance** — silang `control/business/risks.md`: diff menyentuh pemicu (kartu→PCI, PII→GDPR, identitas→KYC, transaksi→pajak) → kewajibannya tak dipenuhi. Severity sesuai dampak; gap high tetap dilaporkan (jadi RED via ship). Degrade: risks.md absen/sentinel → lewati lensa ini.
```

- [ ] **Step 1d: frontmatter `description:`** — tambah `risks.md` ke daftar baseline (separator `/`, TANPA `: `).

FIND (verbatim):
```
description: Red-team keamanan independen atas DIFF sebuah fitur. Diberi diff + invariants.md/conventions.md/integrations.md, tugasnya MENCARI kerentanan — secret ke-commit, PII di log, data kartu (PCI), webhook tanpa verifikasi signature, endpoint tanpa cek tenant/role, input tak divalidasi. Dipanggil ship di Security & Compliance Gate untuk fitur ber-sensitivity. Read-only.
```
REPLACE WITH:
```
description: Red-team keamanan independen atas DIFF sebuah fitur. Diberi diff + invariants.md/conventions.md/integrations.md/risks.md, tugasnya MENCARI kerentanan — secret ke-commit, PII di log, data kartu (PCI), webhook tanpa verifikasi signature, endpoint tanpa cek tenant/role, input tak divalidasi, langgar kewajiban compliance. Dipanggil ship di Security & Compliance Gate untuk fitur ber-sensitivity. Read-only.
```

- [ ] **Step 2: Verify** (+ colon-space guard)

```bash
f=plugin/agents/security-critic.md
grep -Fc -e '+ `control/business/risks.md` (baseline kewajiban compliance — PCI/GDPR/pajak/KYC).' "$f"  # expect 1 (input)
grep -Fc -e '1. Baca diff + `control/invariants.md` + `control/conventions.md` + `control/integrations.md` + `control/business/risks.md`.' "$f"  # expect 1 (langkah1)
grep -Fc -e '   - **Langgar kewajiban compliance** — silang `control/business/risks.md`:' "$f"  # expect 1 (lensa)
grep -Fc -e 'invariants.md/conventions.md/integrations.md/risks.md, tugasnya MENCARI' "$f"  # expect 1 (description)
# colon-space guard: value description TANPA ": "
sed -n 's/^description: //p' "$f" | grep ': ' && echo "BOCOR colon-space!" || echo "desc clean ✓"
```
Expected: 1 / 1 / 1 / 1 / desc clean ✓.

- [ ] **Step 3: Commit**

```bash
git add plugin/agents/security-critic.md
git commit -m "feat(m6): security-critic baseline risks.md + lensa langgar-compliance (input/langkah1/lensa/description)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: `ship/SKILL.md` — step 4.5 sertakan `risks.md` ke baseline

**Files:**
- Modify: `plugin/skills/ship/SKILL.md` (step 4.5, baris 34)
- Test: grep anchor

- [ ] **Step 1: Edit** — sisip `risks.md` SETELAH `(baseline webhook ... per vendor)` (no-renumber; ambang RED tak diubah).

FIND (verbatim):
```
- **`sensitivity` memuat `payments`/`pii` →** invoke subagent **`security-critic`** atas diff penuh (lintas repo yang kena, path/SHA dari code-review step 2) + `control/invariants.md` + `control/integrations.md` (baseline webhook signature/mode/idempotency per vendor). Temuan **severity high** = **RED**.
```
REPLACE WITH:
```
- **`sensitivity` memuat `payments`/`pii` →** invoke subagent **`security-critic`** atas diff penuh (lintas repo yang kena, path/SHA dari code-review step 2) + `control/invariants.md` + `control/integrations.md` (baseline webhook signature/mode/idempotency per vendor) + `control/business/risks.md` (baseline kewajiban compliance; advisory). Temuan **severity high** = **RED**.
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/ship/SKILL.md
grep -Fc -e 'per vendor) + `control/business/risks.md` (baseline kewajiban compliance; advisory). Temuan **severity high** = **RED**.' "$f"  # expect 1
# tak ada qualifier menggantung: risks.md SESUDAH (baseline webhook)
grep -Fc -e '(baseline webhook signature/mode/idempotency per vendor) + `control/business/risks.md`' "$f"  # expect 1
```
Expected: 1 / 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/ship/SKILL.md
git commit -m "feat(m6): ship step4.5 sertakan risks.md ke baseline security-critic (advisory; ambang RED tak diubah)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Induk spec — §7 tree + §8 rules + §9 ship gate + §17 Rules

**Files:**
- Modify: `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§7 baris 69, §8 baris 137, §9 baris 210, §17 baris 305)
- Test: grep anchor + skill-count guard

- [ ] **Step 1a: §7 control-tree** — ubah glossary `└──`→`├──` + sisip baris `risks.md` (anchor 7 spasi sebelum `#`; baris baru 10 spasi).

FIND (verbatim):
```
│   └── glossary.md       # istilah
```
REPLACE WITH:
```
│   ├── glossary.md       # istilah
│   └── risks.md          # risiko compliance durable (M6; diisi discovery)
```

- [ ] **Step 1b: §8 repo-tree rules** — append `· compliance-risk.md` (separator middot+space `· ` U+00B7, TANPA spasi-depan; gaya §8).

FIND (verbatim):
```
anti-yes-man.md· debt-aware.md· schema-projection.md· migration-impact.md
```
REPLACE WITH:
```
anti-yes-man.md· debt-aware.md· schema-projection.md· migration-impact.md· compliance-risk.md
```

- [ ] **Step 1c: §9 ship gate** — sisip `risks.md` SESUDAH `(baseline webhook)` (cermin presedan M5/H3 amend §9).

FIND (verbatim):
```
red-team diff (secret/PII/PCI/authz/webhook) terhadap `invariants.md` + `integrations.md` (baseline webhook); temuan high → STOP.
```
REPLACE WITH:
```
red-team diff (secret/PII/PCI/authz/webhook) terhadap `invariants.md` + `integrations.md` (baseline webhook) + `risks.md` (baseline compliance, M6); temuan high → STOP.
```

- [ ] **Step 1d: §17 Rules** — append ` · `compliance-risk.md`` (separator spasi-middot-spasi + backtick; gaya §17).

FIND (verbatim):
```
- **Rules:** `anti-yes-man.md` · `debt-aware.md` · `schema-projection.md` · `migration-impact.md`
```
REPLACE WITH:
```
- **Rules:** `anti-yes-man.md` · `debt-aware.md` · `schema-projection.md` · `migration-impact.md` · `compliance-risk.md`
```

- [ ] **Step 2: Verify**

```bash
f=docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
grep -Fc -e '│   ├── glossary.md       # istilah' "$f"  # expect 1 (glossary jadi ├)
grep -Fc -e '│   └── risks.md          # risiko compliance durable (M6; diisi discovery)' "$f"  # expect 1 (§7 baris baru)
grep -Fc -e 'schema-projection.md· migration-impact.md· compliance-risk.md' "$f"  # expect 1 (§8, 5 rules middot)
grep -Fc -e '(baseline webhook) + `risks.md` (baseline compliance, M6); temuan high → STOP.' "$f"  # expect 1 (§9)
grep -Fc -e '`schema-projection.md` · `migration-impact.md` · `compliance-risk.md`' "$f"  # expect 1 (§17)
grep -Fc -e '**Skills (21):**' "$f"  # expect 1 (skill-count TETAP 21)
```
Expected: 1 / 1 / 1 / 1 / 1 / 1.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
git commit -m "docs(spec): sync induk — risks.md di §7 tree + rules += compliance-risk.md (§8/§17) + §9 ship baseline; skills tetap 21

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: Verifikasi akhir (grep-battery V0–V9 + coherence) — sesi eksekusi

**Files:** (read-only; commit hanya bila ada fix)

- [ ] **Step 1: Grep-battery** (dari root repo)

```bash
echo "V0 risks.md template ada + 4 slot + 4 sentinel:"; test -f plugin/template/control/business/risks.md && grep -c '<belum dinilai>' plugin/template/control/business/risks.md
echo "V0b rule ada:"; test -f plugin/rules/compliance-risk.md && echo ok
echo "V1 compliance-risk rule direferensi discovery+architect+intake (≥3 surface):"; grep -rl 'rules/compliance-risk.md' plugin/skills | sort -u
echo "V2 risks.md direferensi ≥6 surface:"; grep -rl 'risks.md' plugin/skills/discovery plugin/skills/architect plugin/skills/intake plugin/skills/ship plugin/agents | sort -u
echo "V3 intake challenge+sensitivity:"; grep -Fc -e 'Menyentuh kewajiban compliance di `risks.md`?' plugin/skills/intake/SKILL.md; grep -Fc -e '**Compliance (M6):** kalau fitur cocok dgn pemicu' plugin/skills/intake/SKILL.md
echo "V4 security-critic risks.md (input+langkah1+lensa+desc):"; grep -c 'risks.md' plugin/agents/security-critic.md   # expect ≥4
echo "V5 skill-count 21 + plugin.json/marketplace/README TAK tersentuh:"; grep -Fc -e '**Skills (21):**' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md; git diff --name-only main..HEAD | grep -E 'plugin.json|marketplace.json|README' && echo "BOCOR!" || echo "clean ✓"
echo "V6 induk §7 risks.md + §8(5 rules)+§9+§17:"; grep -Fc -e '│   └── risks.md          # risiko compliance durable' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md; grep -Fc -e 'migration-impact.md· compliance-risk.md' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md; grep -Fc -e '`migration-impact.md` · `compliance-risk.md`' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md; grep -Fc -e '(baseline webhook) + `risks.md` (baseline compliance, M6)' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
echo "V7 colon-space security-critic description bersih:"; sed -n 's/^description: //p' plugin/agents/security-critic.md | grep ': ' && echo "BOCOR!" || echo "clean ✓"
echo "V8 anti-palang-keras (klausa M6 advisory, bukan blokir di hulu):"; grep -rn -iE 'blokir|hard.gate|gagalkan' plugin/skills/discovery plugin/skills/architect plugin/skills/intake plugin/rules/compliance-risk.md && echo "cek konteks" || echo "clean ✓"
echo "V9 carve-out utuh (pasar tetap HTML, §D larangan asli ada):"; grep -Fc -e 'SEMUA analisis pasar (pasar, kompetitor, monetisasi, risiko, verdict) TINGGAL di HTML' plugin/skills/discovery/reference.md
echo "V9b scope: aksesibilitas/ToS BUKAN kategori tetap (cuma boleh contoh baris-bebas):"; grep -rn -i 'aksesibilitas\|consumer-protection' plugin/template/control/business/risks.md plugin/rules/compliance-risk.md && echo "cek: jangan jadi slot tetap" || echo "no a11y slot ✓"
```
Expected: V0 4 · V0b ok · V1 discovery+architect+intake (3) · V2 ≥5 file · V3 1+1 · V4 ≥4 · V5 1 + clean · V6 1/1/1/1 · V7 clean · V8 clean · V9 1 · V9b no a11y slot ✓.

- [ ] **Step 2: Coherence read** — baca diff `main..HEAD`, pastikan: seam penulis(discovery)↔risks.md↔pembaca(architect/intake/ship-critic) nyambung; carve-out melonggarkan §D diakui jujur (tak diklaim "konsisten"); advisory di hulu, gate existing di hilir (ambang RED tak diubah); penulis tunggal discovery (tak ada pembaca nulis risks.md); degrade no-discovery disebut tiap pembaca; `invariants.md` PII/PCI + `sensitivity` TAK diduplikasi (risks.md = input/baseline); induk §7 alignment tree benar + §8/§17 dua listing rules konsisten (5) + skills 21. Catat temuan.

- [ ] **Step 3: Selesai (sesi ini)** — JANGAN merge/push. Lapor: plan tereksekusi, N commit, tree clean. **Post-exec adversarial verify = sesi LAIN** (fresh-eyes 6 lensa: faithful-exec/seam/mis-aimed-pointer/parent-doc-staleness/anti-fiksi-advisory/design-hole stress-test — termasuk cek "advisory vs ship-RED widening" beneran jujur di shipped-text), baru FF-merge + push origin/main + hapus branch + update memory.

---

## Self-Review (penulis plan)

**1. Spec coverage** (tiap requirement spec → task):
- §4 file `risks.md` (slot PCI/GDPR/pajak/KYC + sentinel + bentuk entri + init auto-scaffold) → Task 1 (init tak butuh edit — `cp -R` + `<PRODUCT>` glob sudah nyakup).
- §5 rule `compliance-risk.md` (penulis-tunggal, carve-out melonggarkan, overlap-rule, advisory per-kelas-pembaca, anti-fiksi, degrade, generik, batas) → Task 2.
- §6a discovery §A sub-prompt + §D carve-out + SKILL step7 seed → Task 3 (§A/§D) + Task 4 (seed).
- §6b architect 4.5 baca risks.md constraint → Task 5.
- §6c intake step2 baca + step5 challenge + step7 perkuat-sensitivity → Task 6.
- §6d ship+security-critic baseline → Task 7 (agent: input/langkah1/lensa/description) + Task 8 (ship oper baseline).
- §7 generik/degrade → Task 2 (rule).
- §8 edge (greenfield/no-discovery/sentinel/N-A/perkuat-tag/RED/gap-baru/pasar-HTML/spesifik-produk/riset-tipis) → Task 1 (sentinel) + Task 2 (degrade+kelas-pembaca+anti-fiksi) + Task 5/6/7 (advisory).
- §9 edit-map (template + rule + discovery §A/§D + discovery SKILL + architect + intake×3 + security-critic×4 + ship + induk §7/§8/§9/§17) → Task 1-9 (1:1).
- §10 verifikasi V0-V9 + bug-guard → Task 10 + per-task grep + header.
- §11 hubungan/non-goal (←discovery; →invariants/sensitivity/ship hilir; ≠duplikasi; skills 21; honesty ship-RED + blast-radius) → header + Task 2 (kelas-pembaca) + Task 7/8 (honesty di shipped-text) + Task 9 (skills 21) + Task 10 V4/V5.
→ **Tak ada gap.**

**2. Placeholder scan:** tiap step punya isi nyata (file penuh Task 1/2; find/replace verbatim Task 3-9; grep konkret Task 10). Tak ada TBD/TODO/"similar to". ✓

**3. Type/anchor consistency:** istilah `risks.md`/`compliance`/`carve-out`/`advisory` konsisten rule(Task2)+discovery(Task3/4)+architect(Task5)+intake(Task6)+security-critic(Task7)+ship(Task8); idiom `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md` sama di Task 2/3/4/5/6; sentinel `<belum dinilai>` konsisten template(Task1)+rule(Task2); "advisory di hulu, gate existing di hilir" konsisten. Tiap anchor FIND diambil verbatim dari disk & di-`grep -Fc`-verify =1 saat penulisan plan (discovery/reference:15/39, discovery/SKILL:34, architect:40, intake:22/34/51, security-critic:3/9/12/16, ship:34, induk:69(7sp)/137/210/305). Parent §7 alignment: glossary 7sp (verified), risks.md 10sp (kolom # = glossary). ✓
