---
name: init
description: Use when starting a new product (greenfield) or adopting an existing repo/monorepo/multi-repo (polyrepo) into the context-vault system. Triggers — "init produk", "setup context-vault", "mulai produk baru", "adopsi repo ke context-vault".
---

# init — Bootstrap Produk

Tujuan: menyiapkan lapisan `control/` untuk sebuah produk, mendeteksi topologi, dan men-seed knowledge awal. Jalankan dari root folder produk target.

> File template & rules dibaca dari plugin yang ter-install lewat variabel `${KIMI_SKILL_DIR}/../..` (path absolut ke lokasi plugin). JANGAN hardcode path repo boilerplate.

## Langkah

### 1. Inspect folder target
**Topology = BERAPA GIT REPO, bukan bentuk folder (amandemen 2026-09-14).** Deteksi dari repo NYATA, jangan dari nama folder: `apps/` bisa berisi banyak repo terpisah, dan repo-repo terpisah bisa duduk di dalam root produk.

1. **Kumpulkan kandidat unit** — direktori di kedalaman 1–2 dari root yang kelihatan proyek (punya manifest: `package.json` / `go.mod` / `pyproject.toml` / `Cargo.toml` / `pom.xml` / dsb.) ATAU memuat `.git`. Abaikan `node_modules`, `.next`, `dist`, `build`, `vendor`, `target`, `.venv`.
2. **Resolve repo tiap kandidat DAN root produk:** `git -C <dir> rev-parse --show-toplevel` (gagal/exit≠0 ⇒ belum ter-git). Toplevel root produk sendiri = `ROOT_TOP` (boleh kosong bila root bukan repo).
3. **Simpulkan** — bandingkan toplevel kandidat terhadap `ROOT_TOP`, **jangan cuma hitung jumlahnya** (satu unit = satu repo, jumlah saja tak pernah bisa membedakan monorepo dari multi-repo):
   - Nol kandidat & folder kosong (selain config dasar) → **greenfield**.
   - Semua kandidat resolve ke **`ROOT_TOP`** (root produk sendiri repo-nya, unit hidup di dalamnya) → **monorepo existing (brownfield)**. File workspace (`turbo.json` / `pnpm-workspace.yaml` / `nx.json`) = **bukti penguat**, BUKAN penentu.
   - Ada kandidat yang toplevel-nya **BUKAN `ROOT_TOP`** (termasuk saat `ROOT_TOP` kosong — hub `control/` bakal duduk di luar repo app mana pun) → **multi-repo existing (brownfield)**, **walau kandidatnya cuma SATU** — layout apa pun: nested flat (`x`), nested di bawah folder induk (`apps/x`), atau sibling. Satu repo app + hub terpisah = produk multi-repo yang app keduanya belum ada.
   - Ada kandidat tapi **nol** yang ter-git → **TANYA user**: kode existing yang belum di-`git init`, atau greenfield dengan sisa file? Jangan tebak.
4. **Catat LAYOUT-nya juga, bukan cuma topology** — lokasi NYATA tiap kandidat relatif root produk. Itu yang dipakai langkah 5 mengisi `path`; brownfield **WAJIB** pakai lokasi nyata, jangan default. (Catatan jujur: deteksi ini memindai folder target, jadi multi-repo yang KETEMU di sini pasti ber-layout nested — `path` = `x`/`apps/x`, **bukan** `../x`. Default `../<app>` di langkah 5 hanya masuk akal bila user sengaja menaruh hub `control/` BERSEBELAHAN dengan repo-repo app, dan itu tak akan pernah terdeteksi dari sini — tanyakan, jangan asumsikan.)

### 2. Framing Q&A (singkat, level produk)
> Bila framing produk SUDAH tersedia (mis. dipanggil setelah skill `discovery`: nama produk + satu kalimat + apps sudah diketahui), JANGAN tanya ulang — pakai itu, cukup konfirmasi ringkas ke user, lalu lanjut ke langkah 3 (keputusan topologi).

Tanyakan satu per satu:
- Nama produk?
- Satu kalimat: ngapain & buat siapa?
- App apa saja yang sudah kebayang? (greenfield: declare; existing: konfirmasi yang terdeteksi). Boleh mulai dari satu, tambah app lain nanti lewat skill `add-app`.
  - **(Opsional — blueprint app)** Kalau produk terdengar besar & app target sudah jelas sejak sekarang, boleh declare SEMUA app target sekaligus (semua masuk `apps[]` dengan `stack: {}` — lihat langkah 5). Tandai tiap app blueprint dengan menambah frasa `(blueprint — belum di-bring-up)` di akhir `responsibility`-nya + komentar `# blueprint, belum di-bring-up` pada entri-nya (lihat langkah 5), supaya pembaca seperti `ask`/`design-system`/`fanout` tahu app itu baru niat, belum dibangun. Ini cuma men-declare niat/topologi; bring-up (architect lalu wire) tetap per app saat app itu digarap — saat itu marker `(blueprint — belum di-bring-up)` dilepas. Produk kecil/belum jelas → cukup mulai satu, sisanya belakangan lewat `add-app`. (Nambah app sesudah init pertama tetap lewat `add-app`, bukan re-run init.)

### 3. Keputusan topologi (GATE)
App sudah diketahui (langkah 2) → tetapkan topology dengan dasar, bukan asal default.
- **Brownfield (existing):** ikuti yang terdeteksi di langkah 1 (monorepo / multi-repo); konfirmasi ke user. `init` TIDAK mengusulkan mecah monorepo existing jadi multi-repo (atau sebaliknya) — itu migrasi kode, di luar jatah `init`.
- **Greenfield, 1 app:** **monorepo** — tak perlu tanya, langsung lanjut.
- **Greenfield, ≥2 app:** tanya **satu** pertanyaan ringkas buat baca sinyal — app-app ini (a) **berbagi bahasa/kode** (shared types/ui-kit/util) atau bakal jalan di bahasa beda?, dan (b) **deploy/scale/dimiliki independen** (tim beda, cadence rilis beda, atau ada runtime non-JS spt service Python/Go)?
  - **Default condong monorepo** kalau ragu / sinyal lemah — lebih simpel buat mulai (YAGNI), tetap satu tempat, gampang dipecah belakangan.
  - **Rekomendasiin multi-repo (polyrepo)** kalau divergensi jelas: runtime beneran beda **+** deploy/kepemilikan independen **+** sedikit kode bareng. Sodorkan rekomendasi + alasannya — jangan paksa.
- Bila `discovery`/framing sudah ngasih sinyal topology, pakai itu — jangan tanya ulang.
- **Catatan kejujuran:** `init` ini justru momen TERMURAH buat nentuin topology (belum ada kode — ganti = edit 1 baris `workspace.yaml`). Tapi begitu `wire` scaffold skeleton, topology nempel ke layout fisik (folder + git repo + config), jadi ganti setelahnya = migrasi mahal. Makanya putusin serius sekarang, jangan asal default.

Minta user konfirmasi sebelum lanjut. JANGAN menulis apa pun sebelum dikonfirmasi. ("polyrepo" = sinonim user-facing untuk nilai `topology: multi-repo`.)

### 4. Scaffold control/
- Copy isi `${KIMI_SKILL_DIR}/../../template/control/` ke `<produk>/control/` (mis. `cp -R "${KIMI_SKILL_DIR}/../../template/control/." "<produk>/control/"`).
- Ganti placeholder `<PRODUCT>` dengan nama produk di SEMUA file `control/` yang baru di-scaffold (semua `business/*.md`, `conventions.md`, `invariants.md`, `integrations.md`, **dan** `design-system.md`) — `<PRODUCT>` selalu berarti nama produk, jadi jangan tinggalkan satu pun. Pakai in-place replace (mis. `sed`/`perl`) ketimbang meng-Edit, supaya tidak perlu Read tiap file hasil copy lebih dulu. Placeholder konten lain (mis. `<satu kalimat: ngapain & buat siapa>`, `<siapa>`, `<nilai inti>`) dibiarkan; itu tumbuh belakangan lewat `feature`/`architect`.
- **Greenfield:** biarkan `business/` tetap skeleton (akan tumbuh lewat fitur).
- **Existing:** isi `domain.md` dengan ringkasan dari README bila ada; deteksi `stack` tiap app dari `package.json`. (Capture mendalam stack/capabilities = tugas skill `architect` di langkah berikutnya, bukan di sini.)

### 5. Generate workspace.yaml
Tulis `<produk>/control/workspace.yaml`:
```yaml
product: <nama-produk>
topology: <monorepo|multi-repo>        # "polyrepo" = multi-repo
apps:
  - name: <app>
    path: <lokasi unit relatif root produk — default apps/<app> (monorepo) | ../<app> (multi-repo); layout BEBAS, konfirmasi ke user>
    repo_url: <isi untuk multi-repo, kosongkan untuk monorepo>
    type: <fe|be|fullstack>
    responsibility: "<ringkas>"
    capabilities: []        # diisi fanout/architect
    stack: {}               # diisi architect
packages: []                # shared package (ui-kit/types/utils) — diisi skill add-package; consumers diisi fanout
databases: []               # DB fisik + pemilik migrasi — diisi architect saat app KEDUA nempel ke DB yang sama; kosong = tiap app 1:1 (rules/db-ownership.md)
```
Untuk existing, isi `stack` per app dari hasil deteksi `package.json` (framework, db bila terbaca). Biarkan `packages: []` kosong — package tumbuh lewat `add-package`, bukan di-declare saat init.
**`path` = layout fisik, BUKAN turunan `topology` (amandemen 2026-09-14).** Nilai di atas cuma **default**; brownfield → pakai lokasi NYATA yang terdeteksi langkah 1, greenfield → tawarkan default lalu **konfirmasi** (user boleh override). Multi-repo sah di layout mana pun — sibling (`../x`), nested flat (`x`), atau nested di bawah folder induk (`apps/x`) yang tiap foldernya punya `.git` sendiri; `apps/` **bukan** penanda monorepo (yang bikin monorepo satu repo, bukan nama folder). Yang ditentukan `topology` cuma `repo_url` (diisi untuk multi-repo). Konvensi yang dipilih di sini jadi pola yang dibaca `add-app` untuk app berikutnya (`add-app` langkah 2).
Untuk app yang di-declare sebagai blueprint (opsi blueprint langkah 2 — di-declare tapi belum di-bring-up) → tambahkan frasa `(blueprint — belum di-bring-up)` di akhir `responsibility`-nya DAN komentar inline `# blueprint, belum di-bring-up` pada baris entri (mis. baris `- name:`), supaya pembaca `apps[]` (`ask`/`design-system`/`fanout`) tahu app itu baru niat. `architect`/`wire` melepas frasa marker dari `responsibility` saat app betul-betul di-bring-up.

### 6. Generate CLAUDE.md
Tulis `<produk>/.claude/CLAUDE.md`:
- Baris konteks produk (nama + satu kalimat dari Q&A).
- Baris: "Knowledge sistem ada di `control/` (workspace.yaml + business/ + conventions.md). Selalu mulai dari bisnis, bukan kode."
- **Merge** isi `${KIMI_SKILL_DIR}/../../rules/anti-yes-man.md` ke bagian bawah CLAUDE.md.
Copy juga seluruh isi `${KIMI_SKILL_DIR}/../../template/.claude/` ke `<produk>/.claude/` (mis. `cp -R "${KIMI_SKILL_DIR}/../../template/.claude/." "<produk>/.claude/"`) — termasuk `settings.json` (permissions allowlist/deny + hooks), folder `hooks/` (skrip notifikasi unattended `on-stop.sh`/`on-permission.sh`), **dan** `drive.sh` (outer-loop driver bash untuk `build --unattended` berkelanjutan — build reference §H) + `build_status.py` (pembaca status build untuk baris progres `drive.sh` & panel; butuh `python3`). Pastikan skrip executable: `chmod +x "<produk>/.claude/hooks/"*.sh "<produk>/.claude/drive.sh"`. (Tak menimpa `CLAUDE.md` yang baru ditulis di atas — template tak memuatnya.)
Lalu **tulis** (bukan sekadar "pastikan" — ini aksi APPEND deterministik, idempoten) baris `.claude/notify.sh`, `.claude/.unattended*`, `.claude/build/`, `.claude/share/`, dan `control/features/*/share.html` ke `<produk>/.gitignore`: untuk tiap baris, `grep -qxF` dulu → kalau belum ada baru `printf '%s\n' >> .gitignore` (buat file bila absen). Lakukan di langkah ini, JANGAN ditunda — `notify.sh` (ditulis `build` nanti) bisa memuat token/topik notif pribadi (jangan ke-commit, seperti `.env`); penanda `.unattended*` = state runtime build, bukan knowledge; `.claude/build/` = scratch brief/report/paket-diff per-task `build` (file-handoff), bukan knowledge; `.claude/share/` + `share.html` = scratch & hasil generate skill `share` (±2MB per fitur, bisa digenerate ulang), bukan knowledge. (Proteksi dipasang `init` SEBELUM `build` pernah membuat file-file itu; `build` tetap self-heal bila produk lama belum punya.)

### 7. Ringkas hasil (GATE)
Tampilkan struktur `control/` yang dibuat + isi `workspace.yaml`. Konfirmasi ke user. Sarankan langkah berikutnya: `architect` (setup/capture fondasi teknis).

## Catatan
- `init` hanya men-scaffold + seed tipis. Knowledge bisnis tumbuh just-in-time lewat `feature`. Fondasi teknis ditangani `architect` (keputusan stack) lalu `wire` (bring-up: skeleton kosong-tapi-jalan).
- Untuk multi-repo, `control/` adalah repo/hub tersendiri; repo app TIDAK dimigrasi.
