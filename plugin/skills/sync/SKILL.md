---
name: sync
description: Use untuk NYUSULIN control/ ke kode yang sudah merge di branch utama tiap repo (kerja tim — rekan/squad lain commit tanpa update control/). Hitung selisih sejak patokan control/sync.yaml, analisis per repo (subagent sync-reader), catat LENGKAP ke file knowledge pemiliknya tanpa gate per item, lalu buka ringkasan bisnis HTML (fitur baru · aturan bisnis berubah · aturan coding baru). Tidak menimpa catatan bertanda fitur aktif. Dipanggil penjaga basi skill lain atau manual. Trigger — "sync", "sinkron control", "nyusulin knowledge", "abis pull". Jalankan dari root produk yang punya control/.
---

# sync — Nyusulin `control/` ke kode yang sudah merge

> **Titik tunggu attended → `AskUserQuestion`:** tiap gate approve/revisi, Q&A keputusan, & konfirmasi yang nunggu jawaban user — tulis konten (draft/diff/ringkasan) sebagai teks DULU, lalu tanya lewat tool `AskUserQuestion` (pertanyaan pendek, opsi bawa konsekuensi); JANGAN akhiri turn dengan pertanyaan teks (tak memicu push Remote Control). Run unattended/headless tetap tak pernah bertanya (satu pengecualian: lihat §Batas). Detail: `${CLAUDE_PLUGIN_ROOT}/rules/ask-user.md`.

Tujuan: `control/` cuma ada di laptop user, kodenya digarap banyak orang. `sync` membaca commit yang sudah merge ke branch utama tiap repo sejak patokan terakhir, mencatat **lengkap** ke file knowledge pemiliknya, lalu menampilkan **satu halaman ringkasan level bisnis**. User nggak baca daftar commit.

Skema usulan tulis, peta file, skema JSON ringkasan, dan aturan label ada di `${CLAUDE_PLUGIN_ROOT}/skills/sync/reference.md`. **Baca dulu.** Helper di folder yang sama: `sync_status.py` (patokan/selisih/penanda) dan `assemble.py` (rakit HTML). Di bawah, `SS` = `python3 -B ${CLAUDE_PLUGIN_ROOT}/skills/sync/sync_status.py`.

### 0. Mode
Unattended/headless → **STOP** dengan satu kalimat ("sync tidak pernah jalan otomatis — jalankan `/sync` saat attended"). Tanpa `control/workspace.yaml` → STOP, arahkan `/init`.

### 1. Baseline (`control/sync.yaml` absen)
1. Usulkan `contracts_repos`: app/package yang `responsibility`-nya di `workspace.yaml` menyebut kontrak/schema/API bersama. Tampilkan kandidat sebagai teks.
2. `AskUserQuestion` dua pertanyaan:
   - **Titik mulai**: "Anggap control/ sekarang sudah sinkron" (patokan = branch utama sekarang, tanpa ringkasan) / "Sinkron sejak tanggal …" (user ketik `YYYY-MM-DD`).
   - **Repo kontrak**: kandidat tadi / tidak ada / lainnya.
3. `SS init --root . [--since <tgl>] [--contracts a,b]`.
   - Exit 3 + `need_base` → per repo di daftar itu tanya branch utamanya (`AskUserQuestion`, opsi dari `git -C <path> branch -r`), lalu ulangi dengan `--base <key>=<ref>` per repo.
4. Sebut fitur `active` yang ada (`control/features/*/feature.yaml`): "catatan dari fitur ini yang ditulis sebelum penanda ada nggak bisa dikenali — cek manual, tambahkan `<!-- feature:<f> -->` bila perlu" (`${CLAUDE_PLUGIN_ROOT}/rules/feature-marker.md`).
5. Opsi pertama → **selesai** (tanpa ringkasan). Opsi kedua → lanjut ke langkah 2.

### 2. Hitung
1. `SS status --root .`. Per repo:
   - `error: "patokan hilang dari riwayat"` (branch utama di-force-push) → `AskUserQuestion`: baseline ulang repo itu (`SS init --force --only <key> --root .`) / skip repo itu.
   - `error: "belum ada patokan"` (app baru di `workspace.yaml`) → tawarkan `SS init --force --only <key> --root .` (`need_base` → `--base <key>=<ref>`).
   - `error` lain (bukan repo git, ref tak ada) → catat untuk `stale_note`, lewati.
2. Per repo yang `behind_all > 0`: `SS range --root . --repo <key> --fetch > .claude/sync/work/<slug>-range.json` (`<slug>` = key dengan `/`→`-`, `.` → `root`). `fetch_error` → lanjut dari ref lokal, catat di `stale_note`.
3. Commit `bot: true` atau `own: true` **tidak dibaca**, cukup dihitung. Repo yang semua commit-nya bot/own → langsung ke langkah 5.
4. `.gitignore` (self-heal): baris `.claude/sync/` belum ada (`grep -qxF`) → append.

### 3. Analisis (subagent per repo, paralel)
Dispatch `context-vault:sync-reader` **paralel, satu per repo basi** (dengan `name: sync-<slug>`). Isi prompt:
- root produk, `key`, `path` repo, path file range JSON;
- daftar file knowledge yang ada (`control/business/*.md`, `invariants.md`, `conventions.md`, `integrations.md`, `design-system.md`, `schema/*.md`, `workspace.yaml`);
- output `SS markers --root . --status active,draft`, dan `contracts_repos` dari `sync.yaml`;
- `Balikan SEKALI: SendMessage ke main, lalu teks akhir persis "."`.

Range > 60 commit non-bot/non-own → pecah per 60 (sebut rentang indeks di prompt), lebih dari satu dispatch per repo.

### 4. Tulis ke `control/`
Controller (bukan subagent) menerapkan usulan tulis sesuai `reference.md` §2:
- Tiap baris yang ditulis diberi jejak `<!-- sync <sha7> <YYYY-MM-DD> -->` (Markdown) / `# sync <sha7> <YYYY-MM-DD>` (YAML).
- **Penanda fitur menang:** usulan yang mengenai baris ber-penanda fitur `draft`/`active` (daftar `markers`) **tidak diterapkan**. Tulis versi master **di baris baru di sampingnya** dengan jejak sync, lalu masukkan ke `conflicts` ringkasan.
- **Larangan (D8):** jangan menambah entri app/package/vendor baru (jadikan `pointers` → `/add-app`, `/add-package`, `/add-integration`), dan jangan menyentuh `control/features/**` / `control/fixes/**`.
- Usulan yang `old`-nya tidak ketemu persis satu kali → jangan ditebak. Lewati, sebut di chat.

### 5. Majukan patokan
Per repo, **setelah semua tulisan repo itu sukses**: `SS advance --root . --repo <key> --sha <to dari range>`. Satu repo gagal tulis → patokan repo itu tidak maju (aman diulang), repo lain tetap maju.

### 6. Laporan
1. Rakit JSON ringkasan (`reference.md` §3) ke `.claude/sync/work/summary.json`: `summary_item` dari subagent masuk `features`/`business_rules`/`coding_rules`, ditambah `conflicts`, `pointers`, `written`, dan hitungan per repo.
2. `python3 -B ${CLAUDE_PLUGIN_ROOT}/skills/sync/assemble.py --data .claude/sync/work/summary.json --out .claude/sync/<YYYY-MM-DD-HHMM>.html`. Exit 1 → baca stderr, perbaiki JSON, rakit ulang.
3. Buka: `open <file>` (macOS) / `xdg-open <file>` (Linux). Gagal → cetak path.
4. Di chat cukup satu kalimat ("<N> hal baru dari <M> commit, dicatat ke control/") + path.

### 7. Dipanggil penjaga
Dipanggil dari penjaga basi skill lain (`${CLAUDE_PLUGIN_ROOT}/rules/stale-guard.md`) → setelah langkah 6, **kembali ke skill pemanggil** di langkah yang sama. Jangan berhenti di sini.

## Guardrails
- **Hanya yang terbukti di diff.** Catat perilaku/aturan/pola yang kelihatan di kode, bukan dugaan dari judul commit (`${CLAUDE_PLUGIN_ROOT}/rules/anti-yes-man.md`). Ragu → masuk hitungan "commit lain", bukan knowledge.
- **SHAPE-only** untuk secret/PII: nama field/variabel boleh, nilai tidak pernah.
- **Unattended/headless → tidak pernah sinkron otomatis.** Hook `SessionStart` hanya mendeteksi. Penjaga di skill lain cuma menawarkan.
- `sync.yaml` hanya ditulis lewat `sync_status.py`. User boleh mengedit tangan `bot_authors` dan `contracts_repos` saja.
- Repo di folder produk yang tidak terdaftar di `workspace.yaml` diabaikan. Cukup satu `pointers` "ada repo tak terdaftar: <nama>" → `/add-app`/`/add-package`.
