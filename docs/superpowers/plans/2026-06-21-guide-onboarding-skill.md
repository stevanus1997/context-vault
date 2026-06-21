# Skill `guide` — Onboarding & Q&A Plugin — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Saat menulis isi `SKILL.md`/`reference.md`, gunakan juga superpowers:writing-skills sebagai acuan kualitas skill.

**Goal:** Menambah satu skill `guide` — pintu masuk tunggal, read-only, untuk *memahami plugin context-vault* (tur orientasi progresif + Q&A soal skill/flow/metodologi), lalu menunjuknya dari README & plugin.json agar gampang ditemukan.

**Architecture:** Skill markdown murni (tanpa kode runtime). `reference.md` menampung lapisan **baked** (peta flow + tabel keputusan + katalog 1-liner); `SKILL.md` menampung **perilaku dua mode** (tur progresif tanpa argumen / Q&A dengan argumen) + guardrails, dan untuk detail mendalam membaca `SKILL.md` skill tetangga **on-demand** (path relatif ke base dir-nya sendiri → jalan di repo dev maupun cache plugin user). "Skill apa yang ADA" diturunkan dari listing folder (`ls ../`) supaya tahan drift; katalog baked hanya memoles 1-liner.

**Tech Stack:** Markdown + YAML frontmatter (format skill Claude Code). Verifikasi via shell (grep/loop) — tanpa dependency eksternal. Spec acuan: `docs/superpowers/specs/2026-06-21-guide-onboarding-skill-design.md`.

## Global Constraints

- **Bahasa:** Indonesia santai, samakan voice skill lain (acuan `plugin/skills/ask/SKILL.md`).
- **Read-only mutlak:** `guide` tak pernah Write/Edit saat runtime, tak menyentuh `control/` maupun kode produk; tak meng-invoke skill lain (hanya pointer command). (Edit README/plugin.json di Task 3 adalah perubahan *implementasi sekali*, bukan perilaku skill.)
- **Frontmatter wajib:** `name: guide` (== nama folder), `description:` gaya repo ("Use untuk …", sertakan contoh Trigger + catatan lokasi jalan).
- **Scope = PLUGIN, bukan produk** (cermin `ask`): pertanyaan tentang produk user → diarahkan ke `/ask`.
- **Path sibling relatif:** baca skill tetangga lewat base-dir skill `guide` sendiri (`<base>/../<skill>/SKILL.md`), bukan path absolut hardcoded.
- **Commit:** ikut konvensi repo; tiap commit diakhiri trailer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`. Spec sudah ter-commit (`dc66516`) — jangan re-commit spec.
- **Katalog harus lengkap:** setiap folder di `plugin/skills/*/` muncul di `reference.md` sebagai `/​<nama>` (invarian diuji di Task 1).

---

### Task 1: `reference.md` — lapisan baked (peta + tabel + katalog)

**Files:**
- Create: `plugin/skills/guide/reference.md`
- Test: cek shell completeness (di bawah)

**Interfaces:**
- Produces: file `reference.md` yang berisi (a) tiga peta flow, (b) tabel keputusan "kapan pakai apa" + tabel `feature`/`fix`/`tweak` + baris `ask`/`guide`, (c) katalog skill terkelompok dengan token `/<nama>` untuk **setiap** skill di `plugin/skills/*/`. Dikonsumsi `SKILL.md` (Task 2) sebagai sumber jawaban baked.

- [ ] **Step 1: Tulis check completeness (yang harus GAGAL dulu)**

Simpan sebagai perintah yang dijalankan langsung (bukan file permanen):

```bash
# Verifikasi tiap folder skill muncul sebagai /<nama> di reference.md
missing=0
for d in plugin/skills/*/; do
  s=$(basename "$d")
  grep -qF "/$s" plugin/skills/guide/reference.md 2>/dev/null || { echo "MISSING: /$s"; missing=1; }
done
[ "$missing" = 0 ] && echo "OK: katalog lengkap" || echo "FAIL: ada skill tak terdaftar"
```

- [ ] **Step 2: Jalankan → pastikan GAGAL**

Run: perintah di Step 1.
Expected: daftar `MISSING: /...` untuk semua skill + `FAIL: ada skill tak terdaftar` (karena `reference.md` belum ada).

- [ ] **Step 3: Tulis `plugin/skills/guide/reference.md`**

Isi **persis** (sesuaikan hanya bila ada skill baru di `plugin/skills/` yang belum tercantum — lihat Step 4):

````markdown
# guide — Referensi baked (peta + cheatsheet + katalog)

Lapisan terkurasi untuk jawaban instan. Untuk **detail** satu skill, `guide` baca `SKILL.md` asli skill itu (jangan duplikasi isi panjang ke sini).

## Peta flow

**Greenfield (ide masih mentah):**
```
discovery → init → architect → wire → feature → breakdown → build → ship
```
**Greenfield (ide sudah jelas):**
```
init → architect → wire → feature → breakdown → build → ship
```
**Brownfield (repo existing):**
```
init → architect → extract(opsional) → wire → feature → breakdown → build → ship
```
`feature` = konduktor yang menjalankan `intake → fanout → plan`. Lane samping bisa kapan saja: `fix` (bug), `tweak` (perubahan kecil), `debt` (utang teknis), `ask` (tanya produk), `drop` (batalin fitur).

## Cheatsheet — kapan pakai apa

| Mau… | Pakai |
|---|---|
| Validasi ide yang masih mentah | `/discovery` |
| Mulai produk (ide jelas / adopsi repo existing) | `/init` |
| Tetapkan stack & fondasi teknis | `/architect` |
| Nyalain skeleton project (kosong-tapi-jalan) | `/wire` |
| Bikin kapabilitas/fitur baru | `/feature` |
| Pecah plan → task kecil | `/breakdown` |
| Eksekusi task → kode | `/build` |
| Selesaikan + PR fitur | `/ship` |
| Perbaiki bug (perilaku lama yang salah) | `/fix` |
| Perubahan kecil (bukan bug, bukan fondasi) | `/tweak` |
| Lihat/triase utang teknis | `/debt` |
| Tanya soal **produk lu** (status/fitur/auth) | `/ask` |
| Tanya soal **plugin ini** (skill/flow/cara kerja) | `/guide` |
| Batalin fitur | `/drop` |
| Nambah app / shared package / vendor eksternal | `/add-app` · `/add-package` · `/add-integration` |
| Bring-up fondasi visual (tokens+komponen) | `/design-system` |
| Front-load knowledge dari kode (brownfield) | `/extract` |
| Doc HTML buat stakeholder | `/render-docs` |
| Susulin produk lama ke template terbaru | `/upgrade` |

### `/feature` vs `/fix` vs `/tweak`

| Skill | Kapan |
|---|---|
| `/tweak` | perubahan KECIL, bukan bug, nggak fondasional — raih duluan |
| `/fix` | perilaku lama yang *salah* (defect) |
| `/feature` | kapabilitas baru / gede / lintas-app / fondasional |

### `/ask` vs `/guide`

| | `/ask` | `/guide` |
|---|---|---|
| Scope | **Produk** lu (baca `control/` + kode) | **Plugin** context-vault (skill/flow/metodologi) |
| Contoh | "fitur gw apa aja", "auth produk apa" | "/fanout itu apa", "abis /init ngapain" |

## Katalog skill

### Pipeline utama (lifecycle produk)
- `/discovery` — validasi ide mentah pra-init: riset pasar/kompetitor/monetisasi + verdict go/no-go, lalu auto lanjut `/init`.
- `/init` — mulai produk baru (greenfield) atau adopsi repo/monorepo existing ke context-vault.
- `/architect` — tetapkan (greenfield) / rekam (brownfield) fondasi teknis: stack per app + capabilities + konvensi + kunci invarian platform.
- `/wire` — bring-up skeleton kosong-tapi-jalan: scaffold app + DB + wiring FE↔BE + env (gated).
- `/feature` — konduktor fitur end-to-end: `intake → fanout → plan` dengan gate tiap tahap.
- `/intake` — fase bisnis fitur: Q&A level bisnis → `business.md` (+ slot Flow/Skenario).
- `/fanout` — petakan fitur ke app yang kena lintas-repo → `fanout.md` + update capabilities.
- `/plan` — fase teknis per-app: baca kode tiap app + Q&A teknis → plan implementasi.
- `/breakdown` — pecah plan flat → `tasks.yaml` (task kecil berurutan, tanpa kode).
- `/build` — eksekusi `tasks.yaml` → kode lulus-test: implementer subagent per task (TDD) + review + gate; resumable; ada mode `--unattended`.
- `/ship` — finishing gate: review + quality + security (sensitivity-scaled) + cek alignment ke business → PR → tandai shipped.

### Lane samping
- `/fix` — lane bugfix: auto-deteksi in-flight (fitur active) / post-ship (`control/fixes/<id>/`); reproduce → root-cause → TDD fix → verify.
- `/tweak` — perubahan kecil berjejak: capture keputusan/kebijakan kecil ke `control/` tanpa pipeline berat; tripwire auto naik-kelas.
- `/debt` — lane utang teknis: registry `control/debt.yaml`; list/triage/promote/drop.
- `/ask` — AMA produk read-only: knowledge-first + code-fallback, sebut sumber, flag drift → route.
- `/drop` — batalkan fitur: tandai dropped + alasan, simpan jadi memori keputusan.

### Scaffolding / numbuhin produk
- `/add-app` — nambah app baru pasca-init (declare → `architect` → `wire`).
- `/add-package` — nambah shared package (fan-IN).
- `/add-integration` — nambah vendor eksternal: tulis kontrak SHAPE ke `control/integrations.md`, scaffold stub webhook bila inbound.
- `/design-system` — bring-up fondasi visual: tokens+motion+komponen primitif dari mockup → `control/design-system.md` (dua-mode SETUP/CAPTURE).

### Docs & maintenance
- `/extract` — (brownfield, opsional) front-load `control/business/` dari kode existing.
- `/render-docs` — generate doc HTML human-readable dari knowledge → `control/docs/site/index.html`.
- `/upgrade` — susulin produk lama (di-init versi plugin sebelumnya) ke template terbaru tanpa menyentuh knowledge.
- `/guide` — (skill ini) panduan & Q&A plugin: tur orientasi progresif + tanya skill/flow/metodologi.
````

- [ ] **Step 4: Jalankan check → pastikan LULUS (+ sinkron skill aktual)**

Run: perintah Step 1.
Expected: `OK: katalog lengkap`. Jika muncul `MISSING: /<nama>` (mis. ada skill baru ditambah sejak plan ini ditulis), tambahkan baris 1-liner untuk skill itu ke grup yang sesuai di `reference.md`, lalu jalankan ulang sampai `OK`.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/guide/reference.md
git commit -m "feat(guide): reference baked — peta flow + cheatsheet + katalog skill

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `guide/SKILL.md` — frontmatter + perilaku dua mode

**Files:**
- Create: `plugin/skills/guide/SKILL.md`
- Test: cek frontmatter + konten (di bawah)

**Interfaces:**
- Consumes: `reference.md` (Task 1) sebagai sumber baked; `plugin/skills/<lain>/SKILL.md` dibaca on-demand via base-dir relatif.
- Produces: skill `guide` yang ter-load Claude Code dengan `name: guide`. Tak ada interface kode.

- [ ] **Step 1: Tulis check frontmatter+konten (harus GAGAL dulu)**

```bash
f=plugin/skills/guide/SKILL.md
grep -q "^name: guide$" "$f" 2>/dev/null \
 && grep -q "^description: Use untuk" "$f" 2>/dev/null \
 && grep -q "/ask" "$f" 2>/dev/null \
 && grep -qi "read-only" "$f" 2>/dev/null \
 && grep -qi "progresif" "$f" 2>/dev/null \
 && echo "OK: frontmatter+konten ada" || echo "FAIL"
```

- [ ] **Step 2: Jalankan → pastikan GAGAL**

Run: perintah Step 1.
Expected: `FAIL` (file belum ada).

- [ ] **Step 3: Tulis `plugin/skills/guide/SKILL.md`**

Isi **persis**:

````markdown
---
name: guide
description: Use untuk ngerti/onboarding plugin context-vault sendiri (BUKAN produk yang lagi dibangun) — tur orientasi progresif + tanya-jawab soal skill, flow, metodologi. Tanpa argumen = tur (apa itu, peta flow, cheatsheet, mulai dari mana, lalu tawarin dalami bagian tertentu). Dengan argumen = jawab "skill X apa", "kapan pakai Y", "bedanya /fix & /tweak", "abis /init ngapain". Hybrid: cheatsheet baked + baca SKILL.md asli on-demand buat detail. Read-only, nggak nyentuh file, nggak nge-launch skill lain. Pertanyaan soal PRODUK (status/fitur/auth) → arahin ke /ask. Trigger — "guide", "panduan plugin", "cara pake plugin ini", "skill apa aja", "mulai dari mana", "onboarding". Bisa dipanggil dari mana saja (nggak butuh control/).
---

# guide — Panduan & Q&A plugin context-vault (read-only)

Tujuan: bantu siapa pun **paham plugin context-vault** — ada skill apa aja, flow-nya gimana, mulai dari mana, dan jawab pertanyaan soal cara kerjanya. **100% read-only** — nggak pernah nyentuh file, nggak nge-launch skill lain; satu-satunya efek = teks jawaban + pointer command.

## Prasyarat & scope
- Bisa dipanggil **dari mana saja** — nggak butuh `control/` (jalan walau user belum punya produk).
- **Scope = PLUGIN** (skill/flow/metodologi context-vault), **BUKAN produk** yang lagi dibangun. Ini cermin `/ask` (yang scope-nya produk). Pertanyaan soal produk → arahin `/ask`.

## Deteksi mode
- **Tanpa argumen bermakna** → **Mode Tur** (progresif).
- **Dengan argumen** (pertanyaan/topik) → **Mode Q&A**.

## Mode Tur (progresif — JANGAN dump semua sekaligus)
Keluarkan langkah 1–4 saja dulu (ringkas, muat layar), lalu tawarkan dalami:

1. **Sapaan + apa itu** (1 paragraf): context-vault = lapisan AI + knowledge (bukan kode) buat ngelola produk multi-app bareng Claude Code.
2. **Peta flow ringkas** (1 baris): `discovery → init → architect → wire → feature → breakdown → build → ship`, plus sebut sekilas lane samping (`fix`/`tweak`/`debt`/`ask`). (Detail tiga varian flow ada di `reference.md`.)
3. **Cheatsheet inti** — tabel pendek "mau X → pakai `/Y`" buat aksi paling umum (mulai produk, bikin fitur, ada bug, perubahan kecil, tanya produk vs tanya plugin). Ambil dari `reference.md`, potong yang paling sering dipakai.
4. **Mulai dari mana**: `/discovery` (ide masih mentah) atau `/init` (udah jelas / brownfield).
5. **Tawarkan dalami** (menu): "Mau gw dalemin yang mana? (1) pipeline fitur (2) lane samping fix/tweak/debt (3) scaffolding add-app/package/integration/design-system (4) docs & maintenance (5) tanya bebas". Baru di giliran berikutnya, tarik grup katalog terkait dari `reference.md` dan jelasin.

**Aturan:** jangan cetak seluruh katalog + deskripsi panjang di langkah pertama. Detail per-grup keluar **on-demand** lewat langkah 5.

## Mode Q&A (ada argumen)
1. **Boundary check dulu.** Kalau pertanyaan sebenarnya soal **produk** user (status, fitur yang udah jalan, auth produk, isi `control/`) → bilang itu ranah `/ask`, arahin ke sana, **stop**. Jangan jawab sebagai guide.
2. **Jawab dari baked** (`reference.md`) buat pertanyaan peta/cheatsheet/"kapan pakai apa"/perbandingan — instan.
3. **Drill on-demand** buat pertanyaan dalam soal **satu skill** ("/build detailnya gimana", "/fanout ngapain persisnya"): baca `SKILL.md` skill itu lewat base-dir skill ini sendiri → `<base-dir-guide>/../<skill>/SKILL.md`. Jawab dari sumber asli. (Path relatif → jalan di repo dev maupun cache plugin user.)
4. **Perbandingan** ("/fix vs /tweak", "/feature vs /tweak"): pakai tabel keputusan di `reference.md`; kalau butuh nuansa, baca dua `SKILL.md`-nya.
5. **Anti-ngarang**: di luar pengetahuan plugin → bilang terus terang + arahin; jangan nebak (selaras `rules/anti-yes-man.md`).

## Sumber & anti-drift
- `reference.md` = lapisan **baked** (peta flow + tabel keputusan + katalog 1-liner) — buat jawaban cepat & seragam.
- **"Skill apa yang ADA" = listing folder**, bukan percaya buta `reference.md`. Saat nampilin katalog penuh, lihat folder tetangga (`<base-dir-guide>/../`) sebagai sumber kebenaran daftar skill. Kalau ada folder skill **tanpa** entri di katalog, sebut apa adanya: "ada skill `X` yang belum ada ringkasannya — ketik `/guide X` buat detail."
- **Detail** selalu dari `SKILL.md` asli (jangan duplikasi isi panjang ke sini).

## Guardrails
- **Read-only mutlak.** Nggak pernah Write/Edit. Nggak nyentuh `control/` maupun kode. Efek = teks + pointer command.
- **Nggak nge-launch.** Kasih pointer command (mis. `/init`, `/feature`); user yang ngetik. Jangan invoke skill lain.
- **Scope = plugin, bukan produk** (cermin `/ask`): pertanyaan produk → route `/ask`.
- **Anti-ngarang.** Pengetahuan plugin diam → bilang + arahin; detail → baca `SKILL.md` asli.
- **Bahasa Indonesia santai.** Hemat konteks — tur progresif & drill cuma baca `SKILL.md` relevan, bukan scan seluruh `skills/`.

## Catatan
- `guide` cermin `/ask`: `ask` jawab soal **produk** (`control/` + kode), `guide` jawab soal **plugin** (skill/flow/metodologi). Keduanya saling-rute di batas scope.
- Pintu masuk buat user baru "males baca README" — satu trigger buat orientasi + tanya-jawab.
````

- [ ] **Step 4: Jalankan check → pastikan LULUS**

Run: perintah Step 1.
Expected: `OK: frontmatter+konten ada`.

- [ ] **Step 5: Verifikasi referensi path sibling realistis**

```bash
# Pastikan ada skill tetangga yang bisa dibaca relatif dari folder guide
ls plugin/skills/guide/../ask/SKILL.md plugin/skills/guide/../build/SKILL.md
```
Expected: kedua path ke-resolve (membuktikan pola `<base>/../<skill>/SKILL.md` valid).

- [ ] **Step 6: Commit**

```bash
git add plugin/skills/guide/SKILL.md
git commit -m "feat(guide): SKILL.md — tur progresif + Q&A plugin, read-only, cermin /ask

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Rollout discoverability — README + plugin.json

**Files:**
- Modify: `README.md` (sisip callout di atas)
- Modify: `plugin/.claude-plugin/plugin.json` (sebut `guide` di `description`)
- Test: grep (di bawah)

**Interfaces:**
- Consumes: keberadaan skill `guide` (Task 2).
- Produces: dua titik discoverability yang menyebut `/guide`.

- [ ] **Step 1: Tulis check (harus GAGAL dulu)**

```bash
grep -q "/guide" README.md && grep -q "guide" plugin/.claude-plugin/plugin.json \
  && echo "OK: discoverability terpasang" || echo "FAIL"
```

- [ ] **Step 2: Jalankan → pastikan GAGAL**

Run: perintah Step 1.
Expected: `FAIL`.

- [ ] **Step 3: Edit `README.md`**

Sisipkan callout tepat setelah baris tagline (baris 3) dan sebelum `## Install`. Ubah:

```markdown
AI-first product boilerplate — lapisan AI + knowledge (bukan kode) untuk mengelola produk multi-app dengan Claude Code.

## Install
```

menjadi:

```markdown
AI-first product boilerplate — lapisan AI + knowledge (bukan kode) untuk mengelola produk multi-app dengan Claude Code.

> **Baru install / males baca?** Ketik `/guide` — panduan + tanya-jawab soal plugin ini (ada skill apa aja, flow-nya gimana, mulai dari mana).

## Install
```

- [ ] **Step 4: Edit `plugin/.claude-plugin/plugin.json`**

Di field `description`, sisipkan penyebutan `guide` tepat setelah pembuka `"AI-first product boilerplate: lapisan AI + knowledge untuk mengelola produk multi-app (`. Ubah potongan:

```
mengelola produk multi-app (init, architect
```

menjadi:

```
mengelola produk multi-app (guide (panduan & Q&A onboarding plugin: tur progresif + tanya skill/flow), init, architect
```

- [ ] **Step 5: Jalankan check → pastikan LULUS + JSON valid**

```bash
grep -q "/guide" README.md && grep -q "guide" plugin/.claude-plugin/plugin.json && echo "OK: discoverability terpasang"
# JSON harus tetap valid setelah edit
python3 -c "import json,sys; json.load(open('plugin/.claude-plugin/plugin.json')); print('JSON OK')"
```
Expected: `OK: discoverability terpasang` lalu `JSON OK`.

- [ ] **Step 6: Commit**

```bash
git add README.md plugin/.claude-plugin/plugin.json
git commit -m "docs(guide): tunjuk /guide sebagai pintu masuk di README + plugin.json

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Verifikasi behavioral end-to-end (acceptance)

**Files:**
- (tak ada perubahan file; gerbang penerimaan)

**Interfaces:**
- Consumes: Task 1–3.

Karena skill tak bisa di-unit-test, gerbang ini = **smoke test behavioral manual** + sapuan struktural akhir. Jalankan tiap item; semua harus sesuai sebelum dianggap selesai.

- [ ] **Step 1: Sapuan struktural final**

```bash
echo "== file ada =="; ls plugin/skills/guide/SKILL.md plugin/skills/guide/reference.md
echo "== katalog lengkap =="; for d in plugin/skills/*/; do s=$(basename "$d"); grep -qF "/$s" plugin/skills/guide/reference.md || echo "MISSING: /$s"; done; echo "(kosong = lengkap)"
echo "== frontmatter =="; grep -m1 "^name: guide$" plugin/skills/guide/SKILL.md
echo "== discoverability =="; grep -c "/guide" README.md; grep -c "guide" plugin/.claude-plugin/plugin.json
```
Expected: kedua file ada; tak ada baris `MISSING:`; `name: guide` cocok; hitungan `/guide` ≥1 di README & ≥1 di plugin.json.

- [ ] **Step 2: Acceptance behavioral — Mode Tur**

Picu `/guide` (tanpa argumen) di sesi Claude Code (atau telusuri instruksi SKILL.md sebagai dry-run). Verifikasi output:
- Muncul: sapaan + 1 paragraf "apa itu", peta flow 1-baris, cheatsheet pendek, "mulai dari `/discovery` atau `/init`", lalu **menu dalami (1–5)**.
- **TIDAK** menumpahkan seluruh katalog 24 skill sekaligus (uji sifat *progresif*).

- [ ] **Step 3: Acceptance behavioral — Mode Q&A (drill)**

Picu `/guide fanout itu apa`. Verifikasi: guide menjawab peran `fanout` dan, untuk detail, membaca `plugin/skills/fanout/SKILL.md` (sumber asli), bukan mengarang.

- [ ] **Step 4: Acceptance behavioral — Perbandingan**

Picu `/guide bedanya fix sama tweak`. Verifikasi: jawaban memakai tabel keputusan (`/tweak` kecil-bukan-bug, `/fix` defect, `/feature` kapabilitas baru).

- [ ] **Step 5: Acceptance behavioral — Boundary ke /ask**

Picu `/guide fitur produk gw apa aja`. Verifikasi: guide **menolak menjawab sebagai data produk** dan **mengarahkan ke `/ask`** (cermin scope), tidak membaca `control/`.

- [ ] **Step 6: Catat hasil acceptance**

Tulis ringkas hasil Step 2–5 (lulus/temuan) sebagai catatan verifikasi di body PR/commit deskripsi saat finishing. Jika ada item gagal → balik ke Task terkait, perbaiki, ulangi.

---

## Self-Review (diisi penulis plan)

**1. Spec coverage:**
- §4.1 tur progresif → Task 2 (Mode Tur) + Task 4 Step 2. ✓
- §4.2 Q&A + boundary + drill + perbandingan → Task 2 (Mode Q&A) + Task 4 Step 3–5. ✓
- §5 hybrid + anti-drift listing → Task 1 (katalog + check) + Task 2 (aturan listing folder). ✓
- §6 guardrails read-only/no-launch/scope/anti-ngarang/bahasa → Task 2 (Guardrails). ✓
- §7 rollout README + plugin.json → Task 3. ✓
- §8 struktur file (SKILL.md + reference.md) → Task 1 & 2. ✓
- §9 frontmatter description → Task 2 Step 3 (verbatim). ✓
- §10 keputusan terkunci → tercermin di Global Constraints + tugas. ✓
- §11 risiko (overlap ask, katalog basi, tur kepanjangan, over-reach nulis) → mitigasi di Task 2 boundary, Task 1 check, Task 2 aturan progresif, Global Constraints read-only. ✓
- marketplace.json sengaja DI-LUAR scope (spec §7 menandai opsional; user pilih README+plugin.json). Tidak ada gap.

**2. Placeholder scan:** Tak ada TBD/TODO; isi `SKILL.md` & `reference.md` ditulis penuh; perintah verifikasi konkret. ✓

**3. Type consistency:** Tak ada tipe kode. Konsistensi nama: `name: guide` == folder `plugin/skills/guide/` == trigger `/guide`; token katalog `/​<nama>` dipakai seragam di check (Task 1/3/4) dan di `reference.md`. ✓
