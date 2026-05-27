# discovery — Pre-Init Business Consultant Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) atau superpowers:executing-plans untuk eksekusi task-by-task. Gunakan **superpowers:writing-skills** saat menyusun `SKILL.md`/`reference.md`. Verifikasi bersifat **skenario** (jalankan skill pada folder produk temp, assert artefak), bukan unit test. Steps pakai checkbox (`- [ ]`).
>
> **PRASYARAT:** Fase 1–5 sudah merged + pushed. Spec sumber kebenaran: `docs/superpowers/specs/2026-05-27-discovery-pre-init-consultant-design.md`. Skill `init` (Fase 1) ada di `plugin/skills/init/SKILL.md` dan akan disenggol 1 klausa di langkah 3-nya. Aset desain warm referensi: `plugin/skills/render-docs/template.html` (palet CSS di-reuse).

**Goal:** Membuat `discovery` — skill pra-`init` yang berperan sebagai business consultant: ubah ide produk mentah jadi konsep tervalidasi (riset pasar/kompetitor/monetisasi + verdict go/no-go), seed ke `control/business/`, hasilkan HTML strategis, lalu serahkan ke `init`.

**Architecture:** Satu skill utuh + dua aset, mengikuti pola `intake`/`render-docs`. `plugin/skills/discovery/SKILL.md` = orkestrasi 7 langkah (riset→draft→`critic`→HTML→review loop→init+seed) dengan `critic` sebagai step internal. `plugin/skills/discovery/template.html` = template HTML dok strategis (palet warm di-reuse dari `render-docs`, seksi strategis berbeda). `plugin/skills/discovery/reference.md` = framework pertanyaan konsultan + aturan sitasi & label keyakinan (memisahkan detail dari SKILL.md biar ramping). Reuse: agent `critic`, alur skill `init`. Output produk: `./discovery-draft.html` (saat loop) → `control/docs/discovery.html` (final) + seed `control/business/`.

> **Catatan deviasi dari spec §10:** spec menyebut "1 file aset"; plan ini memecahnya jadi **2 aset fokus** — `template.html` (desain, openable seperti aset `render-docs`) + `reference.md` (teks framework/aturan). Lebih bersih daripada mencampur HTML dan prosa di satu file.

**Tech Stack:** Claude Code Plugin (SKILL.md markdown + frontmatter), HTML + CSS (inline, self-contained), riset web (WebSearch bawaan / skill `firecrawl`). Tidak ada build/deps.

**Konvensi commit:** tiap commit diakhiri trailer `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`. Tidak diulang di tiap blok.

---

## File Structure

Semua path relatif ke root repo `context-vault`:

- `plugin/skills/discovery/template.html` — **Create.** Template HTML dok strategis (warm, 10 slot seksi, label keyakinan + sitasi). Dibaca skill via `${CLAUDE_PLUGIN_ROOT}`.
- `plugin/skills/discovery/reference.md` — **Create.** Framework pertanyaan/riset per seksi + aturan sitasi (B) + label keyakinan (C) + aturan seed ke `business/` (D).
- `plugin/skills/discovery/SKILL.md` — **Create.** Orkestrasi 7 langkah.
- `plugin/skills/init/SKILL.md` — **Modify.** Tambah 1 klausa di langkah 3 (skip Framing Q&A bila framing sudah ada).
- `README.md` — **Modify.** Tambah `discovery` ke alur mulai + section "Validasi ide" + catatan Status.

Tanggung jawab terpisah: `template.html` = DESAIN, `reference.md` = ATURAN/FRAMEWORK, `SKILL.md` = ORKESTRASI.

---

## Task 1: Aset `template.html` (dok strategis, warm)

**Files:**
- Create: `plugin/skills/discovery/template.html`

- [ ] **Step 1: Tulis `plugin/skills/discovery/template.html`**

```html
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>__PRODUCT__ — Business Discovery</title>
<style>
  /* palet warm di-reuse dari render-docs/template.html */
  :root{ --bg:#fbfaf8; --panel:#f4f1ea; --ink:#37352f; --muted:#8a8578;
         --line:#eae3d3; --accent:#b08968; --chip:#efe9dc; --chipink:#7a6f54;
         --ok:#4a7a3f; --okbg:#e6efe1; --warn:#9a6b2f; --warnbg:#f3e8d6; --spec:#a14b4b; --specbg:#f3dede; }
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
  .conf{font-size:11px;padding:2px 8px;border-radius:6px;font-weight:600;text-transform:uppercase;letter-spacing:.03em}
  .conf.verified{background:var(--okbg);color:var(--ok)}
  .conf.assumed{background:var(--warnbg);color:var(--warn)}
  .conf.spec{background:var(--specbg);color:var(--spec)}
  sup.ref a{color:var(--accent);text-decoration:none;font-size:11px}
  .verdict{font-size:18px;font-weight:700;padding:4px 12px;border-radius:8px;display:inline-block}
  .verdict.go{background:var(--okbg);color:var(--ok)}
  .verdict.caution{background:var(--warnbg);color:var(--warn)}
  .verdict.nogo{background:var(--specbg);color:var(--spec)}
  table{border-collapse:collapse;width:100%} td,th{border:1px solid var(--line);padding:8px 10px;text-align:left;font-size:14px}
  code{background:var(--panel);padding:1px 5px;border-radius:4px;font-size:13px}
  ol.sources{font-size:13px;color:var(--muted)} ol.sources a{color:var(--accent)}
</style>
</head>
<body>
<aside>
  <h1>🧭 __PRODUCT__</h1>
  <div class="tag">Business Discovery · draft</div>
  <nav>
    <a href="#ide">💡 Ide</a>
    <a href="#masalah">🎯 Masalah</a>
    <a href="#pengguna">👥 Pengguna</a>
    <a href="#value">✨ Value</a>
    <a href="#pasar">📈 Pasar</a>
    <a href="#kompetitor">⚔️ Kompetitor</a>
    <a href="#monetisasi">💰 Monetisasi</a>
    <a href="#risiko">⚠️ Risiko</a>
    <a href="#verdict">⚖️ Verdict</a>
    <a href="#sumber">🔗 Sumber</a>
  </nav>
  <div class="tag" style="margin-top:20px">Label: <span class="conf verified">terverifikasi</span> <span class="conf assumed">asumsi</span> <span class="conf spec">spekulatif</span></div>
</aside>
<main>
  <!-- SLOT:ide -->
  <section id="ide"><h2>Ide</h2><p class="meta">Ide mentah + konsep yang dipertajam.</p></section>
  <!-- SLOT:masalah -->
  <section id="masalah"><h2>Masalah</h2><p class="meta">Masalah yang dipecahkan + buat siapa.</p></section>
  <!-- SLOT:pengguna -->
  <section id="pengguna"><h2>Pengguna / Segmen</h2><p class="meta">Target pengguna & segmen.</p></section>
  <!-- SLOT:value -->
  <section id="value"><h2>Value Proposition</h2><p class="meta">Nilai inti & kenapa beda.</p></section>
  <!-- SLOT:pasar -->
  <section id="pasar"><h2>Pasar</h2><p class="meta">Ukuran/arah pasar — tiap klaim berlabel + bersumber.</p></section>
  <!-- SLOT:kompetitor -->
  <section id="kompetitor"><h2>Kompetitor</h2><p class="meta">Pemain existing + posisi/harga.</p></section>
  <!-- SLOT:monetisasi -->
  <section id="monetisasi"><h2>Monetisasi</h2><p class="meta">Model pendapatan kandidat.</p></section>
  <!-- SLOT:risiko -->
  <section id="risiko"><h2>Risiko</h2><p class="meta">Yang bisa bikin gagal.</p></section>
  <!-- SLOT:verdict -->
  <section id="verdict"><h2>Verdict</h2><p class="meta"><span class="verdict caution">GO / CAUTION / NO-GO</span> + alasan. Keputusan akhir di tangan operator.</p></section>
  <!-- SLOT:sumber -->
  <section id="sumber"><h2>Sumber</h2><ol class="sources"><li>Daftar sumber riset (URL + tanggal akses).</li></ol></section>
</main>
</body>
</html>
```

- [ ] **Step 2: Validasi jumlah slot**

Run: `grep -c "SLOT:" plugin/skills/discovery/template.html`
Expected: `10` (ide, masalah, pengguna, value, pasar, kompetitor, monetisasi, risiko, verdict, sumber)

- [ ] **Step 3: Validasi class label & verdict ada**

Run: `grep -Eq 'conf\.verified' plugin/skills/discovery/template.html && grep -Eq 'verdict\.(go|caution|nogo)' plugin/skills/discovery/template.html && echo "STYLES OK"`
Expected: `STYLES OK`

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/discovery/template.html
git commit -m "feat(discovery): add strategic-doc HTML template (warm aesthetic + confidence labels)"
```

---

## Task 2: Aset `reference.md` (framework + aturan)

**Files:**
- Create: `plugin/skills/discovery/reference.md`

- [ ] **Step 1: Tulis `plugin/skills/discovery/reference.md`**

````markdown
# discovery — Reference (framework konsultan + aturan sitasi/label)

Dibaca oleh skill `discovery`. SKILL.md tetap ramping; detail "apa yang digali & gimana nandainnya" ada di sini.

## A. Framework pertanyaan & riset per seksi

Prinsip: AI **MENYETIR**. Untuk tiap seksi, RISET dulu lalu USULKAN draft ke operator + jelaskan kenapanya — JANGAN tanya kosong ke operator yang bukan orang bisnis.

- **Masalah** — Masalah apa, sakitnya di mana, buat siapa? Riset: apakah masalah ini nyata & dibicarakan (forum, review, artikel)?
- **Pengguna/Segmen** — Siapa paling kena masalahnya? Usulkan 2–3 segmen + mana yang paling tajam.
- **Value proposition** — Kenapa solusi ini, kenapa beda dari yang sudah ada?
- **Pasar** — Seberapa besar / ke mana arahnya? Riset angka real (laporan, data publik). Tandai TIAP angka.
- **Kompetitor** — Siapa yang sudah menyelesaikan ini (langsung & tidak langsung)? Riset nama nyata + posisi/harga. Minimal 3 bila ada.
- **Monetisasi** — Model pendapatan kandidat (langganan, sekali bayar, freemium, komisi, dll) + mana yang cocok dengan segmen.
- **Risiko** — Apa yang bisa bikin gagal (pasar jenuh, switching cost tinggi, regulasi, beratnya eksekusi)?
- **Verdict** — `go` / `caution` / `no-go` + alasan ringkas, berbasis temuan di atas. Wajib jujur — boleh `no-go`.

## B. Aturan sitasi (WAJIB)

- Tiap klaim faktual (angka pasar, fakta kompetitor, tren) WAJIB menempel sumber: URL + tanggal akses.
- Tampung sumber di seksi "Sumber" (`<ol class="sources">`, bernomor). Klaim merujuk dengan superscript: `<sup class="ref"><a href="#s1">[1]</a></sup>`.
- TIDAK ADA sumber → klaim itu otomatis `asumsi` atau `spekulatif`, JANGAN `terverifikasi`.
- JANGAN mengarang URL atau angka. Bila tak ketemu data → tulis "tidak ditemukan data" dan label `spekulatif`.

## C. Label keyakinan (3 tingkat)

Tiap klaim non-sepele diberi label (pakai class CSS template):
- `terverifikasi` (`<span class="conf verified">`) — ada sumber kuat & relevan (idealnya >1).
- `asumsi` (`<span class="conf assumed">`) — nalar wajar tapi belum tervalidasi sumber.
- `spekulatif` (`<span class="conf spec">`) — tebakan/ekstrapolasi; perlu konfirmasi.

## D. Yang nyebrang ke business/ (saat seed, langkah 7)

KONSERVATIF — hanya yang `terverifikasi` & durable:
- `domain.md`: Produk (1 kalimat), Pengguna, Nilai inti, + `## Aturan Domain` awal (hanya kalau sudah jelas).
- `glossary.md`: istilah domain.
- `flows.md`: flow kunci (kalau sudah kebayang).

Yang `asumsi`/`spekulatif` & SEMUA analisis pasar (pasar, kompetitor, monetisasi, risiko, verdict) TINGGAL di HTML — JANGAN masuk `business/`.
````

- [ ] **Step 2: Validasi 4 bagian (A–D) ada**

Run: `grep -Ec '^## (A|B|C|D)\.' plugin/skills/discovery/reference.md`
Expected: `4`

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/discovery/reference.md
git commit -m "feat(discovery): add consultant reference (question framework + citation/label rules)"
```

---

## Task 3: Skill `discovery/SKILL.md`

**Files:**
- Create: `plugin/skills/discovery/SKILL.md`

- [ ] **Step 1: Tulis `plugin/skills/discovery/SKILL.md`**

````markdown
---
name: discovery
description: Use saat punya ide produk MENTAH dan mau divalidasi jadi konsep produk sebelum init — business consultant pra-init (riset pasar, kompetitor, monetisasi, verdict go/no-go). Greenfield/tahap-ide SAJA; produk berkode pakai extract. Trigger — "validasi ide", "ide produk baru", "discovery", "konsultasi bisnis produk". Jalankan dari folder kosong calon produk.
---

# discovery — Business Consultant (pra-init)

Tujuan: ubah ide mentah jadi konsep produk yang tervalidasi (level STRATEGI, bukan fitur, NOL teknis), seed ke `control/business/` + hasilkan HTML strategis, lalu serahkan ke `init`.

> Operator mungkin BUKAN orang produk/bisnis. Tugasmu MENYETIR: usulkan & riset, jangan cuma mewawancara. **Riset web WAJIB** — jangan andalkan ingatan. Baca `${CLAUDE_PLUGIN_ROOT}/skills/discovery/reference.md` (framework pertanyaan + aturan sitasi/label) dan pakai `${CLAUDE_PLUGIN_ROOT}/skills/discovery/template.html` sebagai desain HTML.

## Langkah

### 1. Tangkap ide mentah
Minta operator cerita idenya bebas. Rekam dalam kata-katanya sebagai bibit. Konfirmasi versi kasar 1 kalimat: "produk ini ngapain & buat siapa".

### 2. Riset + kembangkan konsep (loop)
Untuk tiap seksi di `reference.md` bagian A (masalah, pengguna, value, pasar, kompetitor, monetisasi, risiko): **riset web dulu** (kompetitor nyata, data pasar), lalu **usulkan draft** ke operator + jelaskan kenapanya. Tiap klaim faktual: catat sumber (URL + tanggal) & beri label keyakinan sesuai `reference.md` bagian B & C. JANGAN mengarang angka/URL.

### 3. Susun draft dok strategis
Rangkai temuan jadi draft: masalah · pengguna/segmen · value · pasar · kompetitor · monetisasi · risiko · **verdict** (`go`/`caution`/`no-go`). Verdict = kesimpulan jujur berbasis temuan (boleh negatif).

### 4. critic (GATE)
Invoke subagent `critic` atas draft. Minta khusus periksa: cherry-pick? sumber lemah/ngarang? lompatan logika di verdict? klaim berlabel `terverifikasi` tanpa sumber kuat? Tanggapi TIAP keberatan bersama operator; turunkan label klaim yang tak tahan uji. JANGAN lanjut sebelum keberatan ditanggapi.

### 5. Render HTML
Clone `${CLAUDE_PLUGIN_ROOT}/skills/discovery/template.html` APA ADANYA (CSS & struktur). Ganti tiap `<!-- SLOT:x -->` + section contohnya dengan konten nyata; pasang label keyakinan (`<span class="conf ...">`) & sitasi (superscript `<sup class="ref">` ke seksi Sumber). Ganti `__PRODUCT__` dengan nama produk. Tulis ke `./discovery-draft.html` di root folder produk (control/ belum ada). Self-contained (CSS inline dari template; sumber boleh `<a href>` eksternal, tapi TIDAK ada `<link>`/`<script src>`/gambar eksternal).

### 6. Review loop (GATE)
Suruh operator buka `./discovery-draft.html` & baca. Tampung feedback. Bila ada → balik ke langkah 2/3 (riset ulang / tajamkan) → regen HTML. ULANG sampai operator bilang **SEPAKAT**. JANGAN lanjut tanpa kata sepakat eksplisit.

### 7. Sepakat → init + seed (GATE)
1. Jalankan alur skill `init`. Kamu SUDAH punya framing (nama produk + 1 kalimat + apps yang kebayang) dari langkah 1–3, jadi `init` skip Framing Q&A-nya (lihat klausa di `init` langkah 3). `init` deteksi topologi (gate-nya sendiri) → scaffold `control/` + `workspace.yaml` + `CLAUDE.md`.
2. SEED `business/` (KONSERVATIF, hanya `terverifikasi` & durable — `reference.md` bagian D): `domain.md` (Produk/Pengguna/Nilai + `## Aturan Domain` awal bila jelas), `glossary.md` (istilah), `flows.md` (flow kunci bila ada). Yang `asumsi`/`spekulatif` & analisis pasar JANGAN dimasukkan.
3. Pindahkan HTML final: `./discovery-draft.html` → `control/docs/discovery.html`.
4. Ringkas hasil + sarankan langkah berikut: `architect` (fondasi teknis).

## Catatan
- NOL teknis (stack/arsitektur = jatah `architect`). Berhenti di konsep produk; fitur = jatah `feature`/`intake`.
- Verdict bukan perintah — selalu "ini alasan + sumber, operator yang putuskan". Riset MENURUNKAN halusinasi, tidak MENGHAPUS.
- Brownfield berkode → pakai `extract`, bukan ini.
````

- [ ] **Step 2: Validasi frontmatter**

Run: `head -4 plugin/skills/discovery/SKILL.md`
Expected: baris `---`, `name: discovery`, `description: ...`, `---`.

- [ ] **Step 3: Validasi 7 langkah ada**

Run: `grep -Ec '^### [1-7]\.' plugin/skills/discovery/SKILL.md`
Expected: `7`

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/discovery/SKILL.md
git commit -m "feat(skill): add discovery (pre-init business consultant) skill"
```

---

## Task 4: Colekan di `init` (skip Framing Q&A bila sudah ada)

**Files:**
- Modify: `plugin/skills/init/SKILL.md` (langkah 3)

- [ ] **Step 1: Sisipkan klausa di langkah 3**

Cari blok ini di `plugin/skills/init/SKILL.md`:

```markdown
### 3. Framing Q&A (singkat, level produk)
Tanyakan satu per satu:
```

Ganti jadi (tambah 1 blockquote di antara heading dan "Tanyakan"):

```markdown
### 3. Framing Q&A (singkat, level produk)
> Bila framing produk SUDAH tersedia (mis. dipanggil setelah skill `discovery`: nama produk + satu kalimat + apps sudah diketahui), JANGAN tanya ulang — pakai itu, cukup konfirmasi ringkas ke user, lalu lanjut ke langkah 4.

Tanyakan satu per satu:
```

- [ ] **Step 2: Validasi klausa tersisip & langkah 3 utuh**

Run: `grep -q "framing produk SUDAH tersedia" plugin/skills/init/SKILL.md && grep -q "Tanyakan satu per satu:" plugin/skills/init/SKILL.md && echo "INIT CLAUSE OK"`
Expected: `INIT CLAUSE OK`

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/init/SKILL.md
git commit -m "feat(init): skip framing Q&A when product framing already provided (discovery handoff)"
```

---

## Task 5: Verifikasi end-to-end (skenario)

> Catatan: bagian behavioral (kualitas riset web, `critic`, init-skip-framing) paling valid diuji di **sesi asli dengan plugin ter-install**. Dry-run di bawah memverifikasi artefak yang bisa di-assert. Ide contoh: **"aplikasi buat UMKM atur stok & jualan online"**, nama produk **StokUMKM**.

- [ ] **Step 1: Setup folder produk kosong**

```bash
rm -rf /tmp/cv-disc && mkdir -p /tmp/cv-disc && echo "empty product folder ready"
```
Expected: `empty product folder ready`

- [ ] **Step 2: Jalankan `discovery` langkah 1–5 (skenario)**

Di sesi Claude Code (plugin ter-install), cwd `/tmp/cv-disc`, invoke `discovery` dengan ide contoh. Verifikasi perilaku: **riset web** kompetitor/pasar nyata → usulkan draft tiap seksi dengan **sitasi + label keyakinan** → tulis `./discovery-draft.html` dari template.

- [ ] **Step 3: Assert artefak HTML**

Run:
```bash
F=/tmp/cv-disc/discovery-draft.html
test -f "$F" \
  && grep -qi "kompetitor" "$F" \
  && grep -qi "monetisasi" "$F" \
  && grep -Eqi "verdict|no-go|caution" "$F" \
  && grep -q 'class="conf' "$F" \
  && grep -Eqi 'https?://' "$F" \
  && ! grep -Eqi '<link[^>]+href=|<script[^>]+src=|<img[^>]+src="http' "$F" \
  && echo "DISCOVERY HTML OK"
```
Expected: `DISCOVERY HTML OK` (HTML ada; seksi strategis terisi; ada label keyakinan `class="conf"`; ada minimal 1 URL sumber; self-contained — tanpa CSS/JS/gambar eksternal)

- [ ] **Step 4: Assert `critic` jalan (behavioral)**

Di sesi: `critic` di-dispatch sebagai subagent atas draft dan mengembalikan **≥1 keberatan konkret** (mis. sumber lemah, cherry-pick, lompatan verdict); agent menanggapi tiap keberatan & menurunkan label klaim yang tak tahan uji.
Expected: ada daftar keberatan + respons; tidak ada klaim `terverifikasi` tanpa sumber yang tersisa.

- [ ] **Step 5: Skenario "sepakat" → init + seed**

Di sesi: operator bilang "sepakat". Agent jalankan langkah 7 — `init` **tanpa mengulang Framing Q&A** (nama `StokUMKM` + 1-liner + apps sudah diketahui dari discovery), scaffold `control/`, lalu **seed** `business/` (konservatif) + pindahkan HTML ke `control/docs/discovery.html`.
(Dry-run tanpa plugin: simulasikan scaffold `init` dengan `mkdir -p /tmp/cv-disc/control && cp -R plugin/template/control/. /tmp/cv-disc/control/` lalu ganti `<PRODUCT>`→`StokUMKM`, kemudian agent menyeed `domain.md`/`glossary.md` dari temuan & memindahkan HTML.)

- [ ] **Step 6: Assert seed + relokasi HTML**

Run:
```bash
D=/tmp/cv-disc/control
test -f "$D/business/domain.md" \
  && ! grep -q "ngapain & buat siapa" "$D/business/domain.md" \
  && grep -Eqi "UMKM|stok" "$D/business/domain.md" \
  && test -f "$D/docs/discovery.html" \
  && ! test -f /tmp/cv-disc/discovery-draft.html \
  && echo "SEED+RELOCATE OK"
```
Expected: `SEED+RELOCATE OK` (placeholder `<satu kalimat: ngapain & buat siapa>` di `domain.md` SUDAH terganti konten nyata; HTML final pindah ke `control/docs/`; draft root sudah tidak ada)

- [ ] **Step 7: Bersihkan**

Run: `rm -rf /tmp/cv-disc && echo "cleaned"`
Expected: `cleaned`

---

## Task 6: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Tambah `discovery` ke "Mulai produk"**

Cari blok:
```markdown
## Mulai produk
```
# di folder produk (baru atau existing)
/init
```
Lalu `architect` (fondasi teknis), `feature` (bikin fitur), `ship`/`drop` (lifecycle), `render-docs` (doc human-readable).
```
Ganti jadi:
```markdown
## Mulai produk
```
# punya ide masih MENTAH? mulai dari sini (business consultant, lalu auto lanjut ke init)
/discovery

# produk sudah jelas (atau existing)? langsung:
/init
```
Lalu `architect` (fondasi teknis), `feature` (bikin fitur), `ship`/`drop` (lifecycle), `render-docs` (doc human-readable).
```

- [ ] **Step 2: Tambah section "Validasi ide" + update urutan greenfield**

Cari baris:
```markdown
Urutan greenfield: `/init` -> `/architect` -> `/feature`.
```
Ganti jadi:
```markdown
Urutan greenfield (ide jelas): `/init` -> `/architect` -> `/feature`.
Urutan greenfield (ide mentah): `/discovery` -> `/init` -> `/architect` -> `/feature`.
```
Lalu sisipkan section baru tepat sebelum `## Fondasi teknis`:
```markdown
## Validasi ide (opsional, greenfield)
```
/discovery          # business consultant pra-init: riset pasar/kompetitor/monetisasi + verdict go/no-go
```
Buat ide yang masih mentah. Nol teknis. Output: dok strategis HTML (`control/docs/discovery.html`) + seed awal `control/business/`; di akhir otomatis panggil `/init`. Tiap klaim disitasi + dilabeli keyakinan; `critic` menantang sebelum kamu menerima.

```

- [ ] **Step 3: Tambah catatan di `## Status`**

Cari baris status:
```markdown
Selesai (Fase 1–5): init, pipeline fitur (feature/intake/fanout/plan + critic), architect/extract, lifecycle (ship/drop), render-docs. Boilerplate context-vault lengkap end-to-end.
```
Ganti jadi:
```markdown
Selesai (Fase 1–5): init, pipeline fitur (feature/intake/fanout/plan + critic), architect/extract, lifecycle (ship/drop), render-docs. Boilerplate context-vault lengkap end-to-end. **Tambahan:** `discovery` — business consultant pra-`init` (validasi ide mentah → seed `business/` + HTML strategis).
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: document discovery skill and update start flow"
```

---

## Definition of Done

- [ ] `plugin/skills/discovery/template.html` ada (10 slot, label keyakinan + verdict styles) — Task 1 grep `10` & `STYLES OK`.
- [ ] `plugin/skills/discovery/reference.md` ada (bagian A–D) — Task 2 grep `4`.
- [ ] `plugin/skills/discovery/SKILL.md` ada (frontmatter valid, 7 langkah) — Task 3 grep `7`.
- [ ] `plugin/skills/init/SKILL.md` punya klausa skip-framing, langkah 3 tetap utuh — Task 4 `INIT CLAUSE OK`.
- [ ] Skenario: `discovery` menulis `./discovery-draft.html` dengan seksi strategis + label `class="conf"` + sumber URL, self-contained (`DISCOVERY HTML OK`); `critic` mengembalikan keberatan & ditanggapi.
- [ ] Skenario: "sepakat" → `init` tanpa ulang Framing Q&A → seed `business/` (placeholder domain terganti) + HTML pindah ke `control/docs/discovery.html` (`SEED+RELOCATE OK`).
- [ ] README ter-update (discovery di alur mulai + section "Validasi ide" + catatan Status).
- [ ] Tidak ada placeholder tersisa di file produksi (`__PRODUCT__` & `<!-- SLOT:x -->` di `template.html` adalah penanda sengaja, diisi saat render).
- [ ] **BELUM (jatah user, konsisten dgn fase lain):** tes asli `/plugin install` + reload lalu trigger `/discovery` di sesi baru (auto-trigger frontmatter + riset web live + handoff ke `init` belum teruji dengan plugin ter-install).
```

