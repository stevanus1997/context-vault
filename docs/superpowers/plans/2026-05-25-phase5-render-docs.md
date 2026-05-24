# Fase 5: render-docs — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) atau superpowers:executing-plans. Gunakan **superpowers:writing-skills** untuk `SKILL.md` dan **frontend-design** (bila tersedia) saat menyusun template HTML. Verifikasi bersifat **skenario** (jalankan skill pada produk temp ber-`control/`, cek `index.html`), bukan unit test.
>
> **PRASYARAT:** Fase 1–4 sudah merged + pushed. Struktur knowledge yang dibaca: `control/workspace.yaml` (product, topology, apps[name,path,type,responsibility,capabilities,stack]), `control/business/{domain,flows,glossary}.md`, `control/features/<fitur>/{feature.yaml(status), business.md}`. Skill `ship` (Fase 4) sudah memanggil `render-docs` bila tersedia — fase ini melengkapinya.

**Goal:** Membuat `render-docs` — skill yang men-generate satu file HTML human-readable (layout sidebar B1, tema Warm/Friendly) dari knowledge `control/`, memfilter fitur ber-status `dropped`, ke `control/docs/site/index.html`.

**Architecture:** Satu skill + satu aset template. `plugin/skills/render-docs/template.html` = sumber desain (CSS warm + struktur B1) yang openable sebagai contoh. `render-docs` SKILL membaca knowledge `control/`, meng-clone struktur/CSS template, mengisi konten nyata (apps + capabilities + business knowledge yang di-render + daftar fitur non-dropped), lalu menulis `control/docs/site/index.html` (self-contained, CSS inline). Zero-dependency; desain konsisten karena template fixed, konten dinamis dari knowledge. Karena dibaca dari sumber yang sama dengan yang dibaca AI → tidak pernah drift.

**Tech Stack:** Claude Code Plugin (SKILL.md), HTML + CSS (inline, self-contained), sedikit JS opsional (nav). Tidak ada build/deps.

**Konvensi commit:** tiap commit diakhiri trailer `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`. Tidak diulang di tiap blok.

---

## File Structure

Semua path relatif ke root repo `context-vault`:

- `plugin/skills/render-docs/template.html` — aset desain (warm B1, CSS inline, konten contoh). Dibaca skill via `${CLAUDE_PLUGIN_ROOT}`.
- `plugin/skills/render-docs/SKILL.md` — skill generator (knowledge → index.html).
- `README.md` — Modify: tambah `render-docs` + bump `## Status` ke "selesai (Fase 1–5)".

Tanggung jawab terpisah: `template.html` = DESAIN (fixed), `SKILL.md` = MAPPING knowledge→konten. Output (`control/docs/site/index.html`) ada di produk.

---

## Task 1: Aset template `template.html` (warm B1)

**Files:**
- Create: `plugin/skills/render-docs/template.html`

- [ ] **Step 1: Tulis `plugin/skills/render-docs/template.html`**

```html
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>__PRODUCT__ — Product Docs</title>
<style>
  :root{ --bg:#fbfaf8; --panel:#f4f1ea; --ink:#37352f; --muted:#8a8578;
         --line:#eae3d3; --accent:#b08968; --chip:#efe9dc; --chipink:#7a6f54; }
  *{box-sizing:border-box} html{scroll-behavior:smooth}
  body{margin:0;font-family:-apple-system,Segoe UI,Roboto,sans-serif;background:var(--bg);
       color:var(--ink);line-height:1.6;display:flex}
  aside{width:240px;min-height:100vh;background:var(--panel);border-right:1px solid var(--line);
        padding:24px 16px;position:sticky;top:0;align-self:flex-start}
  aside h1{font-size:16px;margin:0 0 4px} aside .tag{color:var(--muted);font-size:12px;margin-bottom:20px}
  aside nav a{display:block;padding:8px 10px;border-radius:8px;color:var(--ink);text-decoration:none;font-size:14px}
  aside nav a:hover{background:#fff}
  main{flex:1;padding:40px 48px;max-width:900px}
  section{margin-bottom:48px} h2{font-size:24px;border-bottom:2px solid var(--line);padding-bottom:8px}
  h3{font-size:17px;margin-top:24px}
  .card{background:#fff;border:1px solid var(--line);border-radius:12px;padding:18px 20px;margin:12px 0;
        box-shadow:0 1px 3px rgba(0,0,0,.04)}
  .card h3{margin-top:0}
  .chip{display:inline-block;background:var(--chip);color:var(--chipink);padding:3px 10px;
        border-radius:999px;font-size:12px;margin:2px 4px 2px 0}
  .meta{color:var(--muted);font-size:13px}
  .status{font-size:12px;padding:2px 8px;border-radius:6px}
  .status.active{background:#e6efe1;color:#4a7a3f} .status.shipped{background:#dfeaf6;color:#3a6ea5}
  table{border-collapse:collapse;width:100%} td,th{border:1px solid var(--line);padding:8px 10px;text-align:left;font-size:14px}
  code{background:var(--panel);padding:1px 5px;border-radius:4px;font-size:13px}
</style>
</head>
<body>
<aside>
  <h1>📦 __PRODUCT__</h1>
  <div class="tag">Product Docs · auto-generated</div>
  <nav>
    <a href="#overview">📊 Overview</a>
    <a href="#apps">🧩 Apps</a>
    <a href="#capabilities">🔌 Kapabilitas</a>
    <a href="#flows">🔀 Flows</a>
    <a href="#glossary">📖 Glossary</a>
  </nav>
</aside>
<main>
  <!-- SLOT:overview -->
  <section id="overview"><h2>Overview</h2><p class="meta">Ringkasan produk dari domain.md.</p></section>
  <!-- SLOT:apps -->
  <section id="apps"><h2>Apps</h2>
    <div class="card"><h3>web <span class="meta">· fullstack</span></h3>
      <p>Builder + dashboard.</p>
      <div><span class="chip">auth</span><span class="chip">checkout</span></div></div>
  </section>
  <!-- SLOT:capabilities -->
  <section id="capabilities"><h2>Kapabilitas</h2><p class="meta">Matriks kapabilitas × app.</p></section>
  <!-- SLOT:flows -->
  <section id="flows"><h2>Flows</h2><p class="meta">Business flows dari flows.md.</p></section>
  <!-- SLOT:glossary -->
  <section id="glossary"><h2>Glossary</h2><p class="meta">Istilah dari glossary.md.</p></section>
</main>
</body>
</html>
```

- [ ] **Step 2: Validasi HTML openable (struktur)**

Run: `grep -c "SLOT:" plugin/skills/render-docs/template.html`
Expected: `5` (lima penanda slot: overview, apps, capabilities, flows, glossary)

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/render-docs/template.html
git commit -m "feat(render-docs): add warm B1 HTML template asset"
```

---

## Task 2: Skill `render-docs`

**Files:**
- Create: `plugin/skills/render-docs/SKILL.md`

- [ ] **Step 1: Tulis `plugin/skills/render-docs/SKILL.md`**

````markdown
---
name: render-docs
description: Use untuk men-generate dokumen human-readable (HTML) dari knowledge control/ — untuk PM/stakeholder non-teknis. Dipanggil otomatis oleh ship, atau manual untuk preview. Trigger — "render docs", "generate doc", "update dokumentasi produk". Jalankan dari root produk yang punya control/.
---

# render-docs — Knowledge → HTML (human-readable)

Tujuan: hasilkan SATU file HTML self-contained yang rapi & ramah orang non-teknis, di-generate dari knowledge (tidak ditulis manual → tidak pernah drift).

## Langkah

### 1. Baca knowledge
- `control/workspace.yaml` → `product`, `topology`, daftar `apps` (name, type, responsibility, capabilities, stack).
- `control/business/domain.md`, `flows.md`, `glossary.md`.
- `control/features/*/feature.yaml` (+ `business.md`) — kumpulkan fitur.

### 2. Baca template desain
Baca `${CLAUDE_PLUGIN_ROOT}/skills/render-docs/template.html`. Pakai `<head>`/CSS dan struktur B1-nya APA ADANYA (jangan redesign) supaya konsisten antar-generate.

### 3. Isi konten ke tiap slot
Ganti tiap penanda `<!-- SLOT:x -->` + section contohnya dengan konten nyata:
- **overview:** isi dari `domain.md` (produk, pengguna, nilai) → paragraf ramah.
- **apps:** satu `.card` per app: judul `name` + `type`, `responsibility`, lalu `capabilities` sebagai `.chip`.
- **capabilities:** tabel kapabilitas × app (centang app mana punya kapabilitas apa).
- **flows:** render `flows.md` (heading per flow + langkah) jadi HTML.
- **glossary:** render `glossary.md` (istilah + definisi).
- Ganti `__PRODUCT__` (judul + sidebar) dengan nama produk.
- Render markdown sederhana (heading, list, bold, inline code) jadi HTML yang sesuai.

### 4. FILTER status fitur
Fitur ber-status `dropped` JANGAN ditampilkan di bagian utama. (Opsional: bagian kecil "Diarsipkan" di akhir, tapi default sembunyikan.) Fitur `active`/`shipped` boleh tampil (mis. badge `.status`).

### 5. Tulis output
Tulis hasil ke `control/docs/site/index.html` (buat folder bila belum ada). Pastikan self-contained (CSS inline dari template, tanpa file eksternal).

### 6. Ringkas
Sebutkan path output + cara buka (double-click / `open control/docs/site/index.html`).

## Catatan
- Sumber kebenaran = knowledge `control/`. JANGAN pernah suruh user edit HTML langsung — edit knowledge lalu regenerate.
- Dipanggil `ship` setelah fitur shipped, atau manual kapan saja untuk preview.
````

- [ ] **Step 2: Validasi frontmatter**

Run: `head -4 plugin/skills/render-docs/SKILL.md`
Expected: `---`, `name: render-docs`, `description: ...`, `---`.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/render-docs/SKILL.md
git commit -m "feat(skill): add render-docs (knowledge to HTML) skill"
```

---

## Task 3: Verifikasi end-to-end (skenario)

- [ ] **Step 1: Setup produk temp ber-knowledge + fitur (termasuk satu dropped)**

```bash
mkdir -p /tmp/cv-docs/control/business /tmp/cv-docs/control/features/auth-flow /tmp/cv-docs/control/features/gamification
cat > /tmp/cv-docs/control/workspace.yaml <<'YAML'
product: landing-ai
topology: monorepo
apps:
  - name: web
    path: apps/web
    type: fullstack
    responsibility: "Builder + dashboard UMKM"
    capabilities: [auth, checkout]
  - name: api
    path: apps/api
    type: be
    responsibility: "AI generation + serving"
    capabilities: [auth-validation]
YAML
printf '# landing-ai — Domain\nProduk: bantu UMKM bikin landing page powered by AI.\nPengguna: pemilik UMKM.\nNilai: cepet & gampang.\n' > /tmp/cv-docs/control/business/domain.md
printf '# landing-ai — Flows\n## Auth\nDaftar (Google/email) lalu workspace dibuat.\n' > /tmp/cv-docs/control/business/flows.md
printf '# landing-ai — Glossary\n**workspace** — satu akun UMKM, punya banyak landing page.\n' > /tmp/cv-docs/control/business/glossary.md
printf 'name: auth-flow\nstatus: shipped\ncreated: 2026-05-25\n' > /tmp/cv-docs/control/features/auth-flow/feature.yaml
printf '# Auth Flow — Business Spec\nTujuan: login UMKM friksi minim.\n' > /tmp/cv-docs/control/features/auth-flow/business.md
printf 'name: gamification\nstatus: dropped\nreason: "ditunda"\ncreated: 2026-05-25\n' > /tmp/cv-docs/control/features/gamification/feature.yaml
printf '# Gamification — Business Spec\nTujuan: poin & badge.\n' > /tmp/cv-docs/control/features/gamification/business.md
echo "docs setup done"
```
Expected: `docs setup done`

- [ ] **Step 2: Jalankan `render-docs` (skenario)**

Di sesi Claude Code (plugin ter-install), cwd `/tmp/cv-docs`, invoke `render-docs`. Verifikasi: baca knowledge + template, isi slot, tulis `control/docs/site/index.html`.

- [ ] **Step 3: Assert output**

Run:
```bash
F=/tmp/cv-docs/control/docs/site/index.html
test -f "$F" \
  && grep -q "landing-ai" "$F" \
  && grep -q "web" "$F" && grep -q "api" "$F" \
  && grep -Eq "auth|checkout" "$F" \
  && grep -qi "workspace" "$F" \
  && ! grep -qi "poin & badge" "$F" \
  && echo "DOCS OK"
```
Expected: `DOCS OK` (HTML ada; berisi produk, apps, capability, glossary; fitur `dropped` "gamification/poin & badge" TIDAK muncul)

- [ ] **Step 4: Cek self-contained (tanpa aset eksternal)**

Run: `grep -Eqi '<link[^>]+href|src="http' /tmp/cv-docs/control/docs/site/index.html && echo "ADA EKSTERNAL (cek)" || echo "SELF-CONTAINED OK"`
Expected: `SELF-CONTAINED OK`

- [ ] **Step 5: Bersihkan**

Run: `rm -rf /tmp/cv-docs && echo "cleaned"`
Expected: `cleaned`

---

## Task 4: Update README (+ bump Status ke selesai)

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Tambah `render-docs` ke alur**

Sisipkan ke bagian lifecycle:
```markdown
## Dokumentasi
```
/render-docs        # generate doc HTML human-readable dari knowledge -> control/docs/site/index.html
```
Otomatis dipanggil `ship`; bisa juga manual untuk preview.
```

- [ ] **Step 2: Bump baris `## Status`**

Ganti baris status menjadi:
```markdown
## Status
Selesai (Fase 1–5): init, pipeline fitur (feature/intake/fanout/plan + critic), architect/extract, lifecycle (ship/drop), render-docs. Boilerplate context-vault lengkap end-to-end.
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: document render-docs and mark boilerplate complete (Phase 5)"
```

---

## Definition of Done (Fase 5)

- [ ] `plugin/skills/render-docs/template.html` (warm B1, 5 slot) + `plugin/skills/render-docs/SKILL.md` ada, frontmatter valid.
- [ ] `render-docs` membaca knowledge + template → menulis `control/docs/site/index.html` self-contained (DOCS OK + SELF-CONTAINED OK).
- [ ] Konten doc mencakup produk, apps + capabilities, flows, glossary; fitur `dropped` TIDAK ditampilkan di bagian utama.
- [ ] README ter-update (render-docs + Status = selesai Fase 1–5).
- [ ] Tidak ada placeholder tersisa di file produksi (penanda `<!-- SLOT:x -->` & `__PRODUCT__` di `template.html` adalah penanda yang sengaja, diisi saat generate).
```
