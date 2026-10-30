---
name: review-pr
description: Use untuk mereview PR REKAN (bukan fitur sendiri — itu ship) lintas-repo — tanpa argumen tampilkan PR yang minta review lo di semua repo produk lalu pilih; dengan argumen langsung ke PR itu. PR satu tiket di repo lain digabung jadi satu review. Empat lapis — konsistensi, best practice, alur lintas-repo, kontrak — dicek ke control/ + kontrak di branch utama & PR saudara. Hasil satu laporan HTML (vonis, skor per lapis, temuan + draft komentar tinggal copy). Read-only, tidak pernah posting ke GitHub. Trigger — "review-pr", "review PR <x>", "PR mana yang harus gw review". Jalankan dari root produk yang punya control/.
---

# review-pr — Review PR rekan lintas-repo

> **Titik tunggu attended → `AskUserQuestion`:** tiap gate approve/revisi, Q&A keputusan, & konfirmasi yang nunggu jawaban user — tulis konten (draft/diff/ringkasan) sebagai teks DULU, lalu tanya lewat tool `AskUserQuestion` (pertanyaan pendek, opsi bawa konsekuensi); JANGAN akhiri turn dengan pertanyaan teks (tak memicu push Remote Control). Run unattended/headless tetap tak pernah bertanya. Detail: `${CLAUDE_PLUGIN_ROOT}/rules/ask-user.md`.

Tujuan: user memutuskan approve / minta ubah PR rekan dari **satu halaman**. Ketidakcocokan lintas-repo (field FE vs schema kontrak, transisi status vs `invariants.md`) harus tertangkap walaupun perubahannya tersebar di beberapa PR satu tiket.

Checklist per lapis, contoh temuan, skema JSON laporan, pilihan `evidence`, dan cara membangun `map` ada di `${CLAUDE_PLUGIN_ROOT}/skills/review-pr/reference.md`. **Baca dulu.** Helper di folder yang sama: `prs.py` (bungkus `gh`) dan `assemble.py` (rakit HTML). Di bawah, `PRS` = `python3 -B ${CLAUDE_PLUGIN_ROOT}/skills/review-pr/prs.py`.

### 1. Pilih PR
- **Tanpa argumen** → `PRS inbox --root .`. Tampilkan tabel ringkas (repo · judul · penulis · umur · sudah direview lokal?). Lalu `AskUserQuestion` dengan PR sebagai opsi (maks 4, paling lama dulu). Lebih dari 4 → tampilkan tabel bernomor dan minta user ketik nomornya. Kosong → bilang "nggak ada PR yang minta review lo di repo produk ini", STOP.
- **Argumen** URL / `owner/repo#n` / `repo-key#n` → `PRS view --root . --pr <arg>`.
- Exit 4 (`gh` tak ada) atau exit 5 (`gh-auth`: akun aktif mungkin bukan akun kerja) → sampaikan `hint` dari JSON apa adanya, lalu STOP. Tidak pernah ganti akun `gh` sendiri.
- PR di luar repo produk (`repo_key: null`) → bilang repo itu tak terdaftar di `workspace.yaml` (→ `/add-app`), STOP.

### 2. Penjaga basi
`${CLAUDE_PLUGIN_ROOT}/rules/stale-guard.md` dengan repo relevan = repo PR terpilih + repo PR saudaranya (langkah 3; jalankan setelah daftar PR gabungan diketahui). Skip → temuan yang bersandar ke knowledge repo basi diberi `stale: true`, dan repo itu masuk `stale_repos`.

### 3. Gabung per tiket
`ticket` ada → `PRS siblings --root . --ticket <T> --exclude <owner/repo#n>`. Tampilkan daftar gabungan dalam satu kalimat ("BLCS-5302: LBOFE #1482, LTS #911, LSS #377"), lalu lanjut tanpa bertanya. Tanpa tiket → satu PR saja.

### 4. Kumpulkan bahan (read-only)
Per PR:
- `gh pr diff <n> --repo <owner/repo>` untuk diff.
- Berkas utuh: `git -C <path repo> fetch --quiet origin pull/<n>/head:refs/cv-review/<n>`, lalu `git -C <path repo> show refs/cv-review/<n>:<file>`. Kode sekitar di branch utama: `git -C <path repo> show origin/<base_ref>:<file>`.
- Dilarang checkout, switch, atau stash di repo user: working tree user tidak boleh berubah.
- Di akhir (sukses maupun gagal): `git -C <path repo> update-ref -d refs/cv-review/<n>` untuk tiap ref yang dibuat.

Knowledge: `control/conventions.md`, `invariants.md`, `business/flows.md`·`domain.md`, `integrations.md`, `workspace.yaml` (consumer/producer), `schema/<app>.md`. Penanda fitur: `python3 -B ${CLAUDE_PLUGIN_ROOT}/skills/sync/sync_status.py markers --root . --status active,draft`.

Kontrak: repo di `contracts_repos` (`control/sync.yaml`). Bandingkan versi di `origin/<base>` **ditambah** versi di PR saudara bila ada (perubahan kontrak satu tiket belum merge). `sync.yaml` absen / tanpa kunci itu → anggap tidak ada repo kontrak, sebut sekali "jalankan `/sync` buat nentuin repo kontrak".

### 5. Empat lapis
Detail cek per lapis: `reference.md` §1.
1. **Konsistensi** (`konsistensi`): `conventions.md` + pola kode di sekitar diff (struktur, penamaan, helper bersama).
2. **Best practice** (`best_practice`): error handling, test, keamanan, performa. Diff menyentuh data pribadi / uang / auth / role / tenant / secret / vendor di `integrations.md` → dispatch agent `context-vault:security-critic` atas diff itu, lalu masukkan temuannya ke lapis ini (D18).
3. **Alur lintas-repo** (`alur`): `business/flows.md`, `invariants.md`, dan consumer/producer lain di `workspace.yaml` yang mestinya ikut berubah tapi tidak ada di PR mana pun.
4. **Kontrak** (`kontrak`): PR di repo kontrak → kejelasan (nama field, wajib/opsional, versi, dampak ke consumer). PR consumer → field/tipe yang dipakai cocok dengan kontrak (base + PR saudara).

**Penanda fitur** (`${CLAUDE_PLUGIN_ROOT}/rules/feature-marker.md`): entri knowledge ber-penanda fitur `draft`/`active` belum berlaku di master → **bukan** dasar tuduhan. PR yang bentrok dengannya → temuan `level: info` "bakal bentrok sama fitur lo <f>" (tidak memengaruhi vonis).

**Tingkat:** `harus` = perilaku salah / langgar aturan tercatat / kontrak putus. `saran` = mutu (error handling, test kurang, keterbacaan). Selera bukan temuan (`${CLAUDE_PLUGIN_ROOT}/rules/anti-yes-man.md`). Tiap temuan menyebut lokasi konkret (`<label> <file>:<baris>`).

**Draft komentar (D24):** Indonesia santai-sopan, berbentuk pertanyaan/usulan (bukan perintah), 1–2 kalimat, menyebut file/field konkret dengan `backtick`. Contoh: "Field ini di schema LSS namanya `survey_schedule_at` dan wajib diisi. Kayaknya ketuker sama `surveyDate`?"

### 6. Laporan
1. Tulis JSON (`reference.md` §3) ke `.claude/review/work/<slug>-<n>.json` (`<slug>` = repo_key dengan `/`→`-`, `.` → `root`; `<n>` = nomor PR terpilih).
2. `python3 -B ${CLAUDE_PLUGIN_ROOT}/skills/review-pr/assemble.py --data .claude/review/work/<slug>-<n>.json --out .claude/review/<slug>-<n>.html`. Exit 1 → baca stderr, perbaiki JSON, rakit ulang. Vonis dan skor lapis diturunkan script, jangan ditulis tangan.
3. Buka: `open <file>` (macOS) / `xdg-open <file>` (Linux). Gagal → cetak path.
4. `.gitignore` (self-heal): baris `.claude/review/` belum ada (`grep -qxF`) → append.
5. Di chat maksimal 3 baris: vonis, jumlah temuan (harus/saran/info), path.

## Guardrails
- **Read-only** terhadap `control/` dan working tree repo. Satu-satunya tulisan: `.claude/review/**` dan `.gitignore` produk.
- Tidak pernah `gh pr review` / `gh pr comment` / posting apa pun ke GitHub. User yang menyalin draft komentar.
- Tidak pernah `gh auth switch` sendiri. Akun salah → sampaikan hint, user yang ganti.
- **SHAPE-only** untuk secret/PII: sebut nama field/variabel, jangan pernah nilainya, termasuk di draft komentar.
- Knowledge dari PR rekan baru masuk `control/` lewat `/sync` setelah merge, bukan dari review ini.
