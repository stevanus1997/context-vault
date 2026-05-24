# Fase 2: Feature Pipeline — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) atau superpowers:executing-plans untuk eksekusi task-by-task. Gunakan **superpowers:writing-skills** saat menulis `SKILL.md`/`agent`. Verifikasi bersifat **skenario** (jalankan pipeline pada produk temp, cek artifact), bukan unit test.
>
> **PRASYARAT:** Fase 1 sudah merged (plugin installable, `init` menghasilkan `control/`). Sebelum eksekusi fase ini, pastikan tes `/plugin install` + `/init` asli sudah LULUS — pipeline ini menumpuk di plugin yang sama.

**Goal:** Membuat pipeline fitur `feature` → `intake` → `fanout` → `plan` (+ agent `critic`) yang mengubah ide fitur menjadi `business.md` → `fanout.md` → `plans/*.md` di `control/features/<fitur>/`, dengan gate & disiplin anti-yes-man di tiap tahap.

**Architecture:** Empat skill + satu agent, semua di `plugin/`. `feature` adalah konduktor tipis yang meng-invoke `intake` → `fanout` → `plan` berurutan dengan gate; ketiganya juga bisa dipanggil sendiri (modular). Skill beroperasi pada `control/` produk (cwd), bukan aset plugin. `critic` adalah subagent independen yang di-invoke di gate penting untuk red-team. Status fitur (`draft`→`active`) dikelola `feature` lewat `feature.yaml`; transisi `shipped`/`dropped` adalah Fase 4.

**Tech Stack:** Claude Code Plugin (SKILL.md + agent markdown), YAML (workspace.yaml, feature.yaml), Markdown (artifact fitur). Tidak ada runtime code.

**Konvensi commit:** tiap commit diakhiri trailer `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`. Tidak diulang di tiap blok.

---

## File Structure

Semua path relatif ke root repo `context-vault`:

- `plugin/agents/critic.md` — subagent red-team (dipanggil di gate penting).
- `plugin/skills/intake/SKILL.md` — fase bisnis (P2 fase 1) → `business.md`.
- `plugin/skills/fanout/SKILL.md` — pemetaan lintas-app (P1) → `fanout.md`.
- `plugin/skills/plan/SKILL.md` — fase teknis per-app (P2 fase 2) → `plans/*.md`.
- `plugin/skills/feature/SKILL.md` — konduktor (buat `feature.yaml`, jalankan ketiganya berurutan).
- `README.md` — Modify: tambah daftar skill pipeline.

Tanggung jawab terpisah: tiap skill = satu tahap pipeline (single responsibility); `feature` hanya menyetir; `critic` hanya menilai. Semua membaca/menulis `control/` produk; tidak ada yang menyalin aset plugin selain yang sudah di-handle `init`.

**Artifact yang dihasilkan pipeline (di produk, bukan di repo ini):**
- `control/features/<fitur>/feature.yaml` — `{ name, status, created }`
- `control/features/<fitur>/business.md`
- `control/features/<fitur>/fanout.md`
- `control/features/<fitur>/plans/_shared.md` + `plans/<app>.md`

---

## Task 1: Agent `critic`

**Files:**
- Create: `plugin/agents/critic.md`

- [ ] **Step 1: Tulis `plugin/agents/critic.md`**

```markdown
---
name: critic
description: Red-team independen. Diberi sebuah proposal (business.md / fanout.md / plans) + akses knowledge produk, tugasnya MENCARI celah, bentrok aturan, risiko, dan blind-spot — bukan menyetujui. Dipanggil di gate penting oleh skill intake/fanout/plan (dan ship di fase berikutnya).
tools: Read, Grep, Glob
---

Kamu adalah CRITIC — penilai independen, BUKAN pengusul. Tugasmu HANYA mencari masalah. Jangan menyetujui, jangan menyenangkan, jangan melunak.

Kamu menerima: sebuah proposal (path file di `control/features/<fitur>/`) dan akses ke knowledge produk (`control/business/*.md`, `control/workspace.yaml`, `control/conventions.md`).

Lakukan:
1. Baca proposal + knowledge terkait.
2. Cari & laporkan sespesifik mungkin:
   - **Bentrok aturan domain** — proposal melanggar aturan di `control/business/`. Sebut aturan & file-nya.
   - **Risiko / yang bisa jebol** — celah teknis, keamanan, abuse, edge case.
   - **Blind spot** — app/flow/requirement yang kemungkinan kelewat.
   - **Keputusan fondasi belum dikunci** — hal mahal-di-refactor yang ditunda diam-diam.
3. Tiap temuan: sertakan referensi (file/aturan) + alasan kenapa itu masalah.

Output: daftar keberatan bernomor. Kalau memang tidak ada masalah signifikan, katakan eksplisit "Tidak menemukan masalah signifikan" — tapi HANYA setelah benar-benar mencari. Jangan mengarang masalah.
```

- [ ] **Step 2: Validasi frontmatter**

Run: `head -6 plugin/agents/critic.md`
Expected: blok `---` berisi `name: critic`, `description: ...`, `tools: Read, Grep, Glob`, lalu `---`.

- [ ] **Step 3: Commit**

```bash
git add plugin/agents/critic.md
git commit -m "feat(agent): add critic red-team subagent"
```

---

## Task 2: Skill `intake`

**Files:**
- Create: `plugin/skills/intake/SKILL.md`

- [ ] **Step 1: Tulis `plugin/skills/intake/SKILL.md`**

````markdown
---
name: intake
description: Use untuk fase bisnis sebuah fitur (P2 fase 1) — Q&A level bisnis, validasi ke aturan domain, hasilkan business.md. Trigger — "intake <fitur>", dipanggil oleh skill feature. Jalankan dari root produk yang punya control/.
---

# intake — Business Intake (P2 fase 1)

Tujuan: ubah ide fitur jadi spec bisnis yang jelas & selaras domain, SEBELUM menyentuh teknis.

## Langkah

### 1. Pastikan folder fitur ada
Bila `control/features/<fitur>/feature.yaml` belum ada (intake dipanggil langsung, bukan via `feature`), buat:
```yaml
name: <fitur>
status: draft
created: <YYYY-MM-DD>
```

### 2. Baca knowledge
Baca `control/business/*.md` (domain, flows, glossary) + `control/workspace.yaml` (apps + capabilities).

### 3. Q&A level BISNIS (bukan teknis)
Tanya satu per satu: siapa penggunanya, aturan/kebijakan, hasil yang diharapkan, batasan. JANGAN tanya hal teknis (framework, DB, dll) — itu jatah skill `plan`.

### 4. Cek feasibility kasar
Bandingkan kebutuhan fitur dengan `capabilities` app di `workspace.yaml`. Catat mana yang sudah didukung vs baru.

### 5. Challenge Checklist (WAJIB tampilkan sebelum gate)
- Bentrok aturan bisnis yang mana? (cek `control/business/`)
- Tradeoff-nya apa?
- Ada cara lebih sederhana?
- Apa yang bisa jebol / risiko?

### 6. Critic (gate penting)
Untuk fitur fondasional/berisiko, invoke subagent `critic` atas draft `business.md` + knowledge. Tanggapi tiap keberatan bersama user sebelum lanjut.

### 7. Tulis output (GATE)
Tulis `control/features/<fitur>/business.md` dengan format:
```
# <Fitur> — Business Spec
Tujuan      : <...>
Pengguna    : <...>
Aturan      : <... + referensi business/ bila relevan>
Hasil/Reward: <...>
Out of scope: <...>
```
Lalu **promosikan fakta DURABLE** ke knowledge (konservatif — hanya yang benar lepas dari fitur): aturan domain → `business/domain.md`; flow → `business/flows.md`; istilah → `business/glossary.md`.

Tampilkan `business.md` + daftar promosi knowledge → minta **approve**. Boleh tulis draft dulu lalu konfirmasi.

## Catatan
- Output ini jadi input `fanout`. JANGAN melakukan pemetaan app di sini.
````

- [ ] **Step 2: Validasi frontmatter**

Run: `head -4 plugin/skills/intake/SKILL.md`
Expected: `---`, `name: intake`, `description: ...`, `---`.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/intake/SKILL.md
git commit -m "feat(skill): add intake (business phase) skill"
```

---

## Task 3: Skill `fanout`

**Files:**
- Create: `plugin/skills/fanout/SKILL.md`

- [ ] **Step 1: Tulis `plugin/skills/fanout/SKILL.md`**

````markdown
---
name: fanout
description: Use untuk memetakan sebuah fitur ke app yang terkena lintas-repo (P1) — hasilkan fanout.md + update capabilities. Adaptif (murah kalau cuma 1 app). Trigger — "fanout <fitur>", dipanggil oleh skill feature.
---

# fanout — Cross-repo Fan-out (P1)

Tujuan: tentukan app mana saja yang terkena fitur & perannya, lalu tumbuhkan System Map.

## Langkah

### 1. Baca input
Baca `control/features/<fitur>/business.md` + `control/workspace.yaml` (apps, capabilities, responsibility).

### 2. Petakan ke app
Cocokkan kebutuhan fitur ke `capabilities`/`responsibility` tiap app → tentukan app yang kena + apa perannya.
- **Adaptif:** kalau hanya 1 app yang relevan → konfirmasi cepat ("cuma <app>. Yakin gak nyentuh app lain?"). Kalau banyak → breakdown penuh.
- Bila user memberi hint app (mis. "cuma web"), tetap **VERIFIKASI** terhadap capabilities — koreksi bila ternyata menyentuh app lain. "Cuma 1 app" adalah KESIMPULAN, bukan input. JANGAN skip pengecekan.

### 3. Challenge Checklist (WAJIB sebelum gate)
- Ada app yang kelewat?
- Ada dependency/kontrak lintas-app (mis. issuer↔validator)?
- Tradeoff & yang bisa jebol?
(Untuk fitur besar, boleh invoke `critic`.)

### 4. Tulis output (GATE)
Tulis `control/features/<fitur>/fanout.md`:
```
# <Fitur> — Fan-out
<app> (<peran/kapabilitas>) : <apa yang berubah>
...
Dependency lintas-app: <... bila ada>
Urutan: <... bila ada>
```
Lalu **update `capabilities`** app terkait di `control/workspace.yaml` (tambah kapabilitas baru yang diperkenalkan fitur ini).

Tampilkan `fanout.md` + perubahan capabilities → minta **approve/koreksi** (user paling tahu peta produk).

## Catatan
- Output ini jadi input `plan`. JANGAN masuk ke detail teknis di sini.
````

- [ ] **Step 2: Validasi frontmatter**

Run: `head -4 plugin/skills/fanout/SKILL.md`
Expected: `---`, `name: fanout`, `description: ...`, `---`.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/fanout/SKILL.md
git commit -m "feat(skill): add fanout (cross-repo mapping) skill"
```

---

## Task 4: Skill `plan`

**Files:**
- Create: `plugin/skills/plan/SKILL.md`

- [ ] **Step 1: Tulis `plugin/skills/plan/SKILL.md`**

````markdown
---
name: plan
description: Use untuk fase teknis per-app sebuah fitur (P2 fase 2) — baca kode tiap app yang kena, Q&A teknis, hasilkan plan implementasi. Trigger — "plan <fitur>", dipanggil oleh skill feature.
---

# plan — Technical Plan per-app (P2 fase 2)

Tujuan: untuk tiap app yang kena fitur, susun plan implementasi konkret berbasis kode & konvensi yang ADA.

## Langkah

### 1. Baca input
Baca `control/features/<fitur>/business.md` + `fanout.md` + `control/conventions.md` + `control/workspace.yaml` (untuk `path` & `stack` tiap app).

### 2. Selesaikan kontrak lintas-app dulu
Bila `fanout.md` menyebut dependency lintas-app (mis. mekanisme token web↔api), putuskan kontraknya lebih dulu dan tulis `control/features/<fitur>/plans/_shared.md`:
```
# <Fitur> — Kontrak Lintas-App
<keputusan bersama, mis. mekanisme/format, siapa issuer & validator, env yang dibagi>
```

### 3. Per app (untuk tiap app di fanout.md)
- Buka kode app di `path`-nya (dari `workspace.yaml`). Baca pola yang ada; ikuti `conventions.md` & `stack`.
- Q&A **teknis** seperlunya.
- Susun plan: file yang disentuh, endpoint/komponen, model data, test.
- **Challenge teknis** sebelum gate: konsistensi dengan konvensi? risiko? cara lebih sederhana?

### 4. Tulis output (GATE per app)
Tulis `control/features/<fitur>/plans/<app>.md`:
```
# <app>
Model/Schema : <...>
API/Komponen : <...>
Lokasi       : <path konkret di app>
Test         : <...>
```
Tampilkan tiap plan → minta **approve per app**.

## Catatan
- JANGAN menetapkan stack/framework di sini — itu sudah ditetapkan `architect`. `plan` membaca yang ADA. Bila app belum punya fondasi, hentikan & arahkan user menjalankan `architect` dulu.
- Setelah semua plan di-approve, kontrol kembali ke `feature` (yang menandai status `active`).
````

- [ ] **Step 2: Validasi frontmatter**

Run: `head -4 plugin/skills/plan/SKILL.md`
Expected: `---`, `name: plan`, `description: ...`, `---`.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/plan/SKILL.md
git commit -m "feat(skill): add plan (technical per-app) skill"
```

---

## Task 5: Skill `feature` (konduktor)

**Files:**
- Create: `plugin/skills/feature/SKILL.md`

- [ ] **Step 1: Tulis `plugin/skills/feature/SKILL.md`**

````markdown
---
name: feature
description: Use untuk membangun sebuah fitur end-to-end — konduktor yang menjalankan intake → fanout → plan dengan gate tiap tahap dan mengelola status fitur. Trigger — "feature <nama>", "bikin fitur <nama>", "tambah fitur <nama>".
---

# feature — Konduktor Pipeline Fitur

Tujuan: menyetir pipeline fitur dari ide sampai plan siap-eksekusi. Jalankan dari root produk (yang punya `control/`).

## Langkah

### 1. Buat folder & status fitur
Buat `control/features/<nama>/feature.yaml`:
```yaml
name: <nama>
status: draft
created: <YYYY-MM-DD>
```
(Bila sudah ada, lanjutkan dari tahap yang belum selesai — lihat artifact mana yang sudah ada.)

### 2. Jalankan tahap berurutan dengan gate
1. Invoke skill **`intake`** untuk `<nama>` → tunggu gate (approve `business.md`).
2. Invoke skill **`fanout`** untuk `<nama>` → tunggu gate (approve `fanout.md`).
3. Invoke skill **`plan`** untuk `<nama>` → tunggu gate (approve semua `plans/<app>.md`).

Jangan lanjut tahap berikutnya sebelum gate tahap sebelumnya di-approve user.

### 3. Tandai active
Setelah semua `plan` di-approve, set `control/features/<nama>/feature.yaml` → `status: active`.

### 4. Ringkas
Tampilkan artifact yang dihasilkan (`business.md`, `fanout.md`, `plans/*`). Sarankan langkah berikutnya: implementasi (pakai pola executing-plans/subagent), lalu `ship` (Fase 4) saat selesai.

## Catatan
- `intake`/`fanout`/`plan` modular — bisa dipanggil sendiri untuk mengulang satu tahap (mis. `fanout` ulang setelah revisi `business.md`).
- Transisi `shipped`/`dropped` ditangani skill `ship`/`drop` (Fase 4).
````

- [ ] **Step 2: Validasi frontmatter**

Run: `head -4 plugin/skills/feature/SKILL.md`
Expected: `---`, `name: feature`, `description: ...`, `---`.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/feature/SKILL.md
git commit -m "feat(skill): add feature orchestrator skill"
```

---

## Task 6: Verifikasi end-to-end (skenario)

Pipeline diuji dengan menjalankan `/feature` pada produk temp ber-`control/` minimal, lalu memeriksa artifact. Setup `control/` dibuat manual agar tes ini tidak bergantung pada install/init.

- [ ] **Step 1: Siapkan produk temp ber-control minimal**

Run:
```bash
mkdir -p /tmp/cv-pipe/control/business /tmp/cv-pipe/control/features /tmp/cv-pipe/apps/web /tmp/cv-pipe/apps/api
cat > /tmp/cv-pipe/control/workspace.yaml <<'YAML'
product: landing-ai
topology: monorepo
apps:
  - name: web
    path: apps/web
    type: fullstack
    responsibility: "Builder + dashboard UMKM"
    capabilities: []
    stack: { framework: Next.js }
  - name: api
    path: apps/api
    type: be
    responsibility: "AI generation + serving halaman"
    capabilities: []
    stack: { framework: Hono }
YAML
printf '# landing-ai — Domain\nProduk: bantu UMKM bikin landing page powered by AI.\nNilai: cepet & gampang.\n\n## Aturan Domain\n' > /tmp/cv-pipe/control/business/domain.md
: > /tmp/cv-pipe/control/business/flows.md
: > /tmp/cv-pipe/control/business/glossary.md
echo "setup done"
```
Expected: `setup done`

- [ ] **Step 2: Jalankan pipeline (skenario)**

Di sesi Claude Code dengan plugin ter-install, cwd `/tmp/cv-pipe`, invoke skill `feature` untuk fitur `auth-flow`. Jawab Q&A bisnis (mis. pengguna UMKM, login Google+email, 1 akun banyak landing page). Lewati tiap gate (approve). Verifikasi: intake nanya BISNIS (bukan teknis), fanout memetakan ke `web`+`api` & menambah capabilities, plan menulis `_shared.md` (kontrak token) + `plans/web.md` + `plans/api.md`.

- [ ] **Step 3: Assert artifact**

Run:
```bash
test -f /tmp/cv-pipe/control/features/auth-flow/feature.yaml \
  && grep -q "status: active" /tmp/cv-pipe/control/features/auth-flow/feature.yaml \
  && test -f /tmp/cv-pipe/control/features/auth-flow/business.md \
  && test -f /tmp/cv-pipe/control/features/auth-flow/fanout.md \
  && test -f /tmp/cv-pipe/control/features/auth-flow/plans/web.md \
  && test -f /tmp/cv-pipe/control/features/auth-flow/plans/api.md \
  && grep -q "auth" /tmp/cv-pipe/control/workspace.yaml \
  && echo "PIPELINE OK"
```
Expected: `PIPELINE OK`

- [ ] **Step 4: Assert critic ke-invoke (skenario)**

Pada Step 2, konfirmasi bahwa di gate `intake` (fitur fondasional seperti auth) subagent `critic` dipanggil dan mengembalikan daftar keberatan (mis. soal model tenant / abuse). Catat di hasil verifikasi.

- [ ] **Step 5: Bersihkan**

Run: `rm -rf /tmp/cv-pipe && echo "cleaned"`
Expected: `cleaned`

---

## Task 7: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Tambah bagian skill pipeline ke `README.md`**

Tambahkan setelah bagian "Mulai produk" (sesuaikan dengan teks README aktual; tujuannya mendokumentasikan skill baru):
```markdown
## Bikin fitur
```
/feature <nama>     # konduktor: intake (bisnis) -> fanout (lintas-app) -> plan (teknis)
```
Sub-skill bisa dipanggil sendiri: `/intake`, `/fanout`, `/plan`. Tiap tahap ada gate; agent `critic` me-review di gate penting.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: document feature pipeline skills in README"
```

---

## Definition of Done (Fase 2)

- [ ] `plugin/agents/critic.md` + 4 skill (`intake`, `fanout`, `plan`, `feature`) ada, frontmatter valid, terdeteksi setelah plugin di-reload.
- [ ] `/feature <nama>` pada produk ber-`control/` menghasilkan `feature.yaml` (status `active` setelah selesai), `business.md`, `fanout.md`, `plans/_shared.md` + `plans/<app>.md` (PIPELINE OK).
- [ ] `intake` Q&A bersifat bisnis (bukan teknis); `fanout` menambah `capabilities` di `workspace.yaml`; `plan` membaca stack yang ada (tidak menetapkan stack).
- [ ] `critic` ter-invoke di gate penting & mengembalikan keberatan konkret.
- [ ] Tidak ada placeholder tersisa di file produksi.
```
