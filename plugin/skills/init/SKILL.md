---
name: init
description: Use when starting a new product (greenfield) or adopting an existing repo/monorepo/multi-repo into the context-vault system. Triggers — "init produk", "setup context-vault", "mulai produk baru", "adopsi repo ke context-vault".
---

# init — Bootstrap Produk

Tujuan: menyiapkan lapisan `control/` untuk sebuah produk, mendeteksi topologi, dan men-seed knowledge awal. Jalankan dari root folder produk target.

> File template & rules dibaca dari plugin yang ter-install lewat variabel `${CLAUDE_PLUGIN_ROOT}` (path absolut ke lokasi plugin). JANGAN hardcode path repo boilerplate.

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
- Copy isi `${CLAUDE_PLUGIN_ROOT}/template/control/` ke `<produk>/control/` (mis. `cp -R "${CLAUDE_PLUGIN_ROOT}/template/control/." "<produk>/control/"`).
- Ganti placeholder `<PRODUCT>` dengan nama produk di SEMUA file `control/` yang baru di-scaffold (semua `business/*.md` **dan** `conventions.md`) — `<PRODUCT>` selalu berarti nama produk, jadi jangan tinggalkan satu pun. Pakai in-place replace (mis. `sed`/`perl`) ketimbang meng-Edit, supaya tidak perlu Read tiap file hasil copy lebih dulu. Placeholder konten lain (mis. `<satu kalimat: ngapain & buat siapa>`, `<siapa>`, `<nilai inti>`) dibiarkan; itu tumbuh belakangan lewat `feature`/`architect`.
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
- **Merge** isi `${CLAUDE_PLUGIN_ROOT}/rules/anti-yes-man.md` ke bagian bawah CLAUDE.md.
Copy juga `${CLAUDE_PLUGIN_ROOT}/template/.claude/settings.json` ke `<produk>/.claude/settings.json`.

### 7. Ringkas hasil (GATE)
Tampilkan struktur `control/` yang dibuat + isi `workspace.yaml`. Konfirmasi ke user. Sarankan langkah berikutnya: `architect` (setup/capture fondasi teknis).

## Catatan
- `init` hanya men-scaffold + seed tipis. Knowledge bisnis tumbuh just-in-time lewat `feature`. Fondasi teknis ditangani `architect`.
- Untuk multi-repo, `control/` adalah repo/hub tersendiri; repo app TIDAK dimigrasi.
