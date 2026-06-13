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
> Bila framing produk SUDAH tersedia (mis. dipanggil setelah skill `discovery`: nama produk + satu kalimat + apps sudah diketahui), JANGAN tanya ulang — pakai itu, cukup konfirmasi ringkas ke user, lalu lanjut ke langkah 4.

Tanyakan satu per satu:
- Nama produk?
- Satu kalimat: ngapain & buat siapa?
- App apa saja yang sudah kebayang? (greenfield: declare; existing: konfirmasi yang terdeteksi). Boleh mulai dari satu, tambah app lain nanti lewat skill `add-app`.
  - **(Opsional — blueprint app)** Kalau produk terdengar besar & app target sudah jelas sejak sekarang, boleh declare SEMUA app target sekaligus (semua masuk `apps[]` dengan `stack: {}` — lihat langkah 5). Tandai tiap app blueprint dengan menambah frasa `(blueprint — belum di-bring-up)` di akhir `responsibility`-nya + komentar `# blueprint, belum di-bring-up` pada entri-nya (lihat langkah 5), supaya pembaca seperti `ask`/`design-system`/`fanout` tahu app itu baru niat, belum dibangun. Ini cuma men-declare niat/topologi; bring-up (architect lalu wire) tetap per app saat app itu digarap — saat itu marker `(blueprint — belum di-bring-up)` dilepas. Produk kecil/belum jelas → cukup mulai satu, sisanya belakangan lewat `add-app`. (Nambah app sesudah init pertama tetap lewat `add-app`, bukan re-run init.)

### 4. Scaffold control/
- Copy isi `${CLAUDE_PLUGIN_ROOT}/template/control/` ke `<produk>/control/` (mis. `cp -R "${CLAUDE_PLUGIN_ROOT}/template/control/." "<produk>/control/"`).
- Ganti placeholder `<PRODUCT>` dengan nama produk di SEMUA file `control/` yang baru di-scaffold (semua `business/*.md`, `conventions.md`, `invariants.md`, `integrations.md`, **dan** `design-system.md`) — `<PRODUCT>` selalu berarti nama produk, jadi jangan tinggalkan satu pun. Pakai in-place replace (mis. `sed`/`perl`) ketimbang meng-Edit, supaya tidak perlu Read tiap file hasil copy lebih dulu. Placeholder konten lain (mis. `<satu kalimat: ngapain & buat siapa>`, `<siapa>`, `<nilai inti>`) dibiarkan; itu tumbuh belakangan lewat `feature`/`architect`.
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
packages: []                # shared package (ui-kit/types/utils) — diisi skill add-package; consumers diisi fanout
```
Untuk existing, isi `stack` per app dari hasil deteksi `package.json` (framework, db bila terbaca). Biarkan `packages: []` kosong — package tumbuh lewat `add-package`, bukan di-declare saat init.
Untuk app yang di-declare sebagai blueprint (opsi blueprint langkah 3 — di-declare tapi belum di-bring-up) → tambahkan frasa `(blueprint — belum di-bring-up)` di akhir `responsibility`-nya DAN komentar inline `# blueprint, belum di-bring-up` pada baris entri (mis. baris `- name:`), supaya pembaca `apps[]` (`ask`/`design-system`/`fanout`) tahu app itu baru niat. `architect`/`wire` melepas frasa marker dari `responsibility` saat app betul-betul di-bring-up.

### 6. Generate CLAUDE.md
Tulis `<produk>/.claude/CLAUDE.md`:
- Baris konteks produk (nama + satu kalimat dari Q&A).
- Baris: "Knowledge sistem ada di `control/` (workspace.yaml + business/ + conventions.md). Selalu mulai dari bisnis, bukan kode."
- **Merge** isi `${CLAUDE_PLUGIN_ROOT}/rules/anti-yes-man.md` ke bagian bawah CLAUDE.md.
Copy juga seluruh isi `${CLAUDE_PLUGIN_ROOT}/template/.claude/` ke `<produk>/.claude/` (mis. `cp -R "${CLAUDE_PLUGIN_ROOT}/template/.claude/." "<produk>/.claude/"`) — termasuk `settings.json` (permissions allowlist/deny + hooks), folder `hooks/` (skrip notifikasi unattended `on-stop.sh`/`on-permission.sh`), **dan** `drive.sh` (outer-loop driver bash untuk `build --unattended` berkelanjutan — build reference §H). Pastikan skrip executable: `chmod +x "<produk>/.claude/hooks/"*.sh "<produk>/.claude/drive.sh"`. (Tak menimpa `CLAUDE.md` yang baru ditulis di atas — template tak memuatnya.)
Lalu **tulis** (bukan sekadar "pastikan" — ini aksi APPEND deterministik, idempoten) baris `.claude/notify.sh` dan `.claude/.unattended*` ke `<produk>/.gitignore`: untuk tiap baris, `grep -qxF` dulu → kalau belum ada baru `printf '%s\n' >> .gitignore` (buat file bila absen). Lakukan di langkah ini, JANGAN ditunda — `notify.sh` (ditulis `build` nanti) bisa memuat token/topik notif pribadi (jangan ke-commit, seperti `.env`); penanda `.unattended*` = state runtime build, bukan knowledge. (Proteksi dipasang `init` SEBELUM `build` pernah membuat `notify.sh`.)

### 7. Ringkas hasil (GATE)
Tampilkan struktur `control/` yang dibuat + isi `workspace.yaml`. Konfirmasi ke user. Sarankan langkah berikutnya: `architect` (setup/capture fondasi teknis).

## Catatan
- `init` hanya men-scaffold + seed tipis. Knowledge bisnis tumbuh just-in-time lewat `feature`. Fondasi teknis ditangani `architect` (keputusan stack) lalu `wire` (bring-up: skeleton kosong-tapi-jalan).
- Untuk multi-repo, `control/` adalah repo/hub tersendiri; repo app TIDAK dimigrasi.
