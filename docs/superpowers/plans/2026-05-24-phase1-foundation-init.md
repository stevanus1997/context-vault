# Fase 1: Foundation + `init` — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Karena deliverable di fase ini adalah **file skill (markdown)** + config + template (bukan kode runtime), gunakan juga **superpowers:writing-skills** saat menulis `SKILL.md`. Verifikasi bersifat **skenario** (jalankan skill di direktori temp, cek file hasilnya), bukan unit test.

**Goal:** Membuat plugin `context-vault` bisa di-install dan skill `/init` bisa men-scaffold lapisan `control/` untuk sebuah produk (greenfield monorepo + deteksi multi-repo/brownfield).

**Architecture:** Repo ini = marketplace + plugin sekaligus. `marketplace.json` (root) mendaftarkan plugin di `plugin/`. Plugin berisi `skills/`, `agents/`, `rules/`. `template/` berisi scaffold `control/` + `.claude/` yang di-copy `init` ke produk. `init` membaca kondisi folder target, mengonfirmasi topologi, lalu menulis `control/` + meng-generate `workspace.yaml` dan `CLAUDE.md` (dinamis) sementara file skeleton (business/, conventions.md) di-copy dari template.

**Tech Stack:** Claude Code Plugin (plugin.json + SKILL.md markdown), YAML (workspace.yaml), Markdown (knowledge + skill files). Tidak ada runtime code di fase ini.

**Konvensi commit:** setiap commit diakhiri trailer `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` (sesuai konvensi repo). Demi keringkasan, trailer tidak diulang di tiap blok di bawah.

---

## File Structure

Dibuat di fase ini (semua path relatif ke root repo `context-vault`):

- `.claude-plugin/marketplace.json` — mendaftarkan plugin agar bisa `/plugin install`.
- `plugin/.claude-plugin/plugin.json` — manifest plugin.
- `plugin/rules/anti-yes-man.md` — aturan sikap kritis (di-merge `init` ke CLAUDE.md produk).
- `plugin/skills/init/SKILL.md` — skill `init`.
- `template/control/business/domain.md` — skeleton domain.
- `template/control/business/flows.md` — skeleton flows.
- `template/control/business/glossary.md` — skeleton glossary.
- `template/control/conventions.md` — skeleton konvensi lintas-app.
- `template/control/features/.gitkeep` — folder fitur (kosong).
- `template/control/docs/.gitkeep` — folder doc (diisi Fase 5).
- `template/.claude/settings.json` — settings starter produk.
- `README.md` — dokumentasi repo + cara install.

Tanggung jawab masing-masing terpisah: `plugin/` = yang reusable (di-install), `template/` = yang di-copy per produk. `init` (satu file skill) = satu-satunya yang tahu cara merangkai keduanya jadi produk.

---

## Task 1: Plugin manifest + marketplace (bikin installable)

**Files:**
- Create: `plugin/.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Tulis `plugin/.claude-plugin/plugin.json`**

```json
{
  "name": "context-vault",
  "description": "AI-first product boilerplate: lapisan AI + knowledge untuk mengelola produk multi-app (init, feature pipeline, ship/drop, docs).",
  "version": "0.1.0",
  "author": {
    "name": "stevanus",
    "email": "stevanus.yohanesvcn@gmail.com"
  }
}
```

- [ ] **Step 2: Tulis `.claude-plugin/marketplace.json`**

```json
{
  "name": "context-vault",
  "owner": {
    "name": "stevanus",
    "email": "stevanus.yohanesvcn@gmail.com"
  },
  "metadata": {
    "description": "AI-first product boilerplate.",
    "version": "0.1.0"
  },
  "plugins": [
    {
      "name": "context-vault",
      "source": "./plugin",
      "description": "Skills, agent, dan rules untuk mengelola produk multi-app secara AI-first.",
      "version": "0.1.0"
    }
  ]
}
```

- [ ] **Step 3: Validasi JSON kedua file**

Run: `python3 -c "import json,sys; [json.load(open(f)) for f in ['.claude-plugin/marketplace.json','plugin/.claude-plugin/plugin.json']]; print('JSON OK')"`
Expected: `JSON OK`

- [ ] **Step 4: Verifikasi plugin ke-load (skenario)**

Di sesi Claude Code, dari root repo, jalankan:
```
/plugin marketplace add /Users/stevanus/Developer/ai-boilerplate
/plugin install context-vault
```
Expected: install sukses, plugin `context-vault` muncul di daftar plugin. (Catatan: kalau format `source` relatif tidak dikenali, cek dokumentasi plugin terkini lewat agent `claude-code-guide` dan sesuaikan — verifikasi ini yang menangkapnya.)

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/marketplace.json plugin/.claude-plugin/plugin.json
git commit -m "feat(plugin): add context-vault plugin manifest and marketplace"
```

---

## Task 2: Anti-yes-man rules

**Files:**
- Create: `plugin/rules/anti-yes-man.md`

- [ ] **Step 1: Tulis `plugin/rules/anti-yes-man.md`**

```markdown
# Anti-Yes-Man — Aturan Sikap (selalu aktif)

Kamu adalah partner kritis, BUKAN yes-man. Aturan ini berlaku di setiap interaksi pada produk ini.

- **Tantang dulu, jangan langsung iya.** Kalau permintaan bentrok dengan aturan di `control/business/*.md`, berisiko teknis, atau tidak selaras dengan tujuan produk di `control/business/domain.md` — angkat keberatannya sebelum melanjutkan.
- **Selalu munculkan tradeoff.** Untuk setiap keputusan, sebutkan apa yang dikorbankan dan alternatif yang lebih sederhana.
- **Jangan setuju hanya untuk menyenangkan.** Persetujuan harus berdasar, bukan refleks.
- **Di setiap gate, isi & tampilkan Challenge Checklist:**
  - Bentrok aturan bisnis yang mana? (cek `control/business/`)
  - Apa tradeoff-nya?
  - Ada cara yang lebih sederhana?
  - Apa yang bisa jebol / risikonya?
- Kalau keputusannya fondasional (mahal di-refactor), minta keputusan eksplisit SEKARANG, jangan ditunda diam-diam.
```

- [ ] **Step 2: Verifikasi file ada & non-kosong**

Run: `test -s plugin/rules/anti-yes-man.md && echo "OK"`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add plugin/rules/anti-yes-man.md
git commit -m "feat(rules): add anti-yes-man baseline rule"
```

---

## Task 3: Template scaffold (`control/` skeleton + `.claude/`)

**Files:**
- Create: `template/control/business/domain.md`
- Create: `template/control/business/flows.md`
- Create: `template/control/business/glossary.md`
- Create: `template/control/conventions.md`
- Create: `template/control/features/.gitkeep`
- Create: `template/control/docs/.gitkeep`
- Create: `template/.claude/settings.json`

- [ ] **Step 1: Tulis `template/control/business/domain.md`**

```markdown
# <PRODUCT> — Domain

Produk   : <satu kalimat: ngapain & buat siapa>
Pengguna : <siapa>
Nilai    : <nilai inti>

## Aturan Domain
<!-- Diisi sambil jalan lewat skill intake. Satu heading per aturan. -->
```

- [ ] **Step 2: Tulis `template/control/business/flows.md`**

```markdown
# <PRODUCT> — Flows

<!-- Business process / flow. Diisi sambil jalan lewat intake. -->
<!-- Format per flow: ## <Nama Flow>, lalu langkah-langkahnya. -->
```

- [ ] **Step 3: Tulis `template/control/business/glossary.md`**

```markdown
# <PRODUCT> — Glossary

<!-- Istilah domain. Format: **term** — definisi. Diisi sambil jalan. -->
```

- [ ] **Step 4: Tulis `template/control/conventions.md`**

```markdown
# <PRODUCT> — Konvensi & Kontrak Teknis Lintas-App

<!-- Diisi oleh skill architect. Contoh: mekanisme auth token web<->api,
     format API, shared package, ORM standar. -->
```

- [ ] **Step 5: Buat folder kosong dengan `.gitkeep`**

Run:
```bash
mkdir -p template/control/features template/control/docs
touch template/control/features/.gitkeep template/control/docs/.gitkeep
```

- [ ] **Step 6: Tulis `template/.claude/settings.json`**

```json
{
  "permissions": {
    "allow": [],
    "deny": []
  }
}
```

- [ ] **Step 7: Verifikasi struktur template**

Run: `find template -type f | sort`
Expected (urut):
```
template/.claude/settings.json
template/control/business/domain.md
template/control/business/flows.md
template/control/business/glossary.md
template/control/conventions.md
template/control/docs/.gitkeep
template/control/features/.gitkeep
```

- [ ] **Step 8: Commit**

```bash
git add template/
git commit -m "feat(template): add control/ skeleton and .claude starter"
```

---

## Task 4: Skill `init`

**Files:**
- Create: `plugin/skills/init/SKILL.md`

> Tulis `SKILL.md` mengikuti konvensi superpowers:writing-skills (frontmatter `name` + `description` yang memicu dengan tepat, body instruksi jelas & berurutan).

- [ ] **Step 1: Tulis `plugin/skills/init/SKILL.md`**

````markdown
---
name: init
description: Use saat memulai produk baru atau mengadopsi repo/monorepo existing ke dalam sistem context-vault. Men-scaffold lapisan control/ (knowledge) + workspace.yaml + CLAUDE.md. Trigger pada "init produk", "setup context-vault", "mulai produk baru".
---

# init — Bootstrap Produk

Tujuan: menyiapkan lapisan `control/` untuk sebuah produk, mendeteksi topologi, dan men-seed knowledge awal. Jalankan dari root folder produk target.

## Langkah

### 1. Inspect folder target
Tentukan kondisi:
- **Kosong** (tidak ada file selain config dasar) → **greenfield**.
- Ada `apps/` + file workspace monorepo (`turbo.json` / `pnpm-workspace.yaml` / `nx.json`) → **monorepo existing (brownfield)**.
- Ada beberapa direktori yang masing-masing punya `.git` (sibling repos) → **multi-repo existing (brownfield)**.

### 2. Konfirmasi topologi (GATE)
Sampaikan kesimpulan deteksi + rekomendasi:
- Greenfield → rekomendasi **monorepo**.
- Existing → ikuti yang terdeteksi (monorepo / multi-repo).
Minta user konfirmasi sebelum lanjut. JANGAN menulis apa pun sebelum dikonfirmasi.

### 3. Framing Q&A (singkat, level produk)
Tanyakan satu per satu:
- Nama produk?
- Satu kalimat: ngapain & buat siapa?
- App apa saja yang sudah kebayang? (greenfield: declare; existing: konfirmasi yang terdeteksi). Boleh mulai dari satu, tambah nanti.

### 4. Scaffold control/
- Copy isi `template/control/` dari plugin ke `<produk>/control/`.
- Ganti placeholder `<PRODUCT>` dengan nama produk di file business/.
- **Greenfield:** biarkan `business/` tetap skeleton (akan tumbuh lewat fitur).
- **Existing:** isi `domain.md` dengan ringkasan dari README bila ada; deteksi `stack` tiap app dari `package.json`. (Capture mendalam stack/capabilities = tugas skill `architect` di langkah berikutnya, bukan di sini.)

### 5. Generate workspace.yaml
Tulis `<produk>/control/workspace.yaml`:
```yaml
product: <nama-produk>
topology: <monorepo|multi-repo>
apps:
  - name: <app>
    path: <apps/<app> untuk monorepo | ../<app> untuk multi-repo>
    repo_url: <isi untuk multi-repo, kosongkan untuk monorepo>
    type: <fe|be|fullstack>
    responsibility: "<ringkas>"
    capabilities: []        # diisi fanout/architect
    stack: {}               # diisi architect
```
Untuk existing, isi `stack` per app dari hasil deteksi `package.json` (framework, db bila terbaca).

### 6. Generate CLAUDE.md
Tulis `<produk>/.claude/CLAUDE.md`:
- Baris konteks produk (nama + satu kalimat dari Q&A).
- Baris: "Knowledge sistem ada di `control/` (workspace.yaml + business/ + conventions.md). Selalu mulai dari bisnis, bukan kode."
- **Merge** isi `plugin/rules/anti-yes-man.md` ke bagian bawah CLAUDE.md.
Copy juga `template/.claude/settings.json` ke `<produk>/.claude/settings.json`.

### 7. Ringkas hasil (GATE)
Tampilkan struktur `control/` yang dibuat + isi `workspace.yaml`. Konfirmasi ke user. Sarankan langkah berikutnya: `architect` (setup/capture fondasi teknis).

## Catatan
- `init` hanya men-scaffold + seed tipis. Knowledge bisnis tumbuh just-in-time lewat `feature`. Fondasi teknis ditangani `architect`.
- Untuk multi-repo, `control/` adalah repo/hub tersendiri; repo app TIDAK dimigrasi.
````

- [ ] **Step 2: Verifikasi frontmatter & struktur skill**

Run: `head -5 plugin/skills/init/SKILL.md`
Expected: ada `---`, `name: init`, `description: ...`, `---`.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/init/SKILL.md
git commit -m "feat(skill): add init skill for product scaffolding"
```

---

## Task 5: Verifikasi end-to-end (skenario)

Tidak ada unit test untuk skill; verifikasi dengan menjalankan `/init` di direktori temp dan memeriksa hasilnya.

- [ ] **Step 1: Siapkan dua direktori temp**

Run:
```bash
mkdir -p /tmp/cv-green
mkdir -p /tmp/cv-multi/web/.git /tmp/cv-multi/api/.git
echo '{"dependencies":{"next":"14.0.0"}}' > /tmp/cv-multi/web/package.json
echo '{"dependencies":{"hono":"4.0.0"}}'  > /tmp/cv-multi/api/package.json
echo "Setup done"
```
Expected: `Setup done` (cv-green = greenfield kosong; cv-multi = dua sibling repo).

- [ ] **Step 2: Jalankan skenario greenfield**

Di sesi Claude Code dengan plugin ter-install, cwd `/tmp/cv-green`, invoke skill `init`. Jawab Q&A: produk `demo`, "app demo buat tes", app `web` (fullstack). Konfirmasi semua gate.

- [ ] **Step 3: Assert hasil greenfield**

Run:
```bash
test -f /tmp/cv-green/control/workspace.yaml \
  && test -f /tmp/cv-green/control/business/domain.md \
  && test -f /tmp/cv-green/.claude/CLAUDE.md \
  && grep -q "topology: monorepo" /tmp/cv-green/control/workspace.yaml \
  && grep -qi "anti-yes-man\|partner kritis\|yes-man" /tmp/cv-green/.claude/CLAUDE.md \
  && echo "GREENFIELD OK"
```
Expected: `GREENFIELD OK`

- [ ] **Step 4: Jalankan skenario multi-repo**

Di sesi Claude Code, cwd `/tmp/cv-multi`, invoke `init`. Verifikasi `init` mendeteksi **multi-repo** (dua sibling `.git`) dan mengusulkannya. Konfirmasi.

- [ ] **Step 5: Assert hasil multi-repo**

Run:
```bash
test -f /tmp/cv-multi/control/workspace.yaml \
  && grep -q "topology: multi-repo" /tmp/cv-multi/control/workspace.yaml \
  && grep -q "path: ../web" /tmp/cv-multi/control/workspace.yaml \
  && echo "MULTIREPO OK"
```
Expected: `MULTIREPO OK`

- [ ] **Step 6: Bersihkan**

Run: `rm -rf /tmp/cv-green /tmp/cv-multi && echo "cleaned"`
Expected: `cleaned`

---

## Task 6: README repo

**Files:**
- Create: `README.md`

- [ ] **Step 1: Tulis `README.md`**

```markdown
# context-vault

AI-first product boilerplate — lapisan AI + knowledge (bukan kode) untuk mengelola produk multi-app dengan Claude Code.

## Install
```
/plugin marketplace add <path-atau-url-repo-ini>
/plugin install context-vault
```

## Mulai produk
```
# di folder produk (baru atau existing)
/init
```
Lalu `architect` (fondasi teknis), `feature` (bikin fitur), `ship`/`drop` (lifecycle), `render-docs` (doc human-readable).

## Desain
Lihat `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`.

## Status
Fase 1 (foundation + init). Roadmap di `docs/superpowers/plans/`.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add repo README with install and usage"
```

---

## Definition of Done (Fase 1)

- [ ] Plugin `context-vault` bisa di-install via `/plugin install` dan skill `init` terdeteksi.
- [ ] `/init` di folder kosong menghasilkan `control/` + `workspace.yaml` (topology: monorepo) + `.claude/CLAUDE.md` ber-rules anti-yes-man (GREENFIELD OK).
- [ ] `/init` di folder berisi sibling repos mendeteksi `multi-repo` dan menulis `path: ../<app>` (MULTIREPO OK).
- [ ] Semua file ter-commit; tidak ada placeholder tersisa di file produksi (skeleton template yang sengaja kosong tidak dihitung).
