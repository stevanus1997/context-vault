---
name: share
description: Use untuk bikin SATU file HTML review fitur yang bisa dikirim ke rekan (storyboard tangkapan layar mockup, keputusan, diagram, tombol 💬 + Copy feedback), atau untuk mentriase blok feedback yang dikirim balik. Dipanggil otomatis di akhir feature (rancangan) & ship (dibangun), atau manual kapan saja setelah business.md ada. Trigger — "share <fitur>", "bikin file review <fitur>", "kirim rancangan ke rekan", paste teks berawalan "=== FEEDBACK share:". Jalankan dari root produk yang punya control/.
---

# share — File review fitur buat rekan

Tujuan: rekan yang dikirimi **satu file `.html`** langsung paham fiturnya **dari gambar**, bisa komentar per bagian + milih opsi yang masih terbuka, lalu ngirim balik blok teks yang ditriase ke pipeline. Beda dengan `render-docs`: itu tingkat **produk** buat stakeholder; `share` per **fitur** buat **reviewer**.

Isi, katalog komponen, strategi tangkap layar, Mermaid, format feedback & `reviews.md` ada di `${CLAUDE_PLUGIN_ROOT}/skills/share/reference.md`. **Baca dulu sebelum generate maupun triase.** Kerangka halaman = `${CLAUDE_PLUGIN_ROOT}/skills/share/template.html` (jangan disunting per fitur). Helper: `capture.py` (tangkap layar) & `assemble.py` (rakit) di folder yang sama.

## Deteksi mode
- Argumen memuat `=== FEEDBACK share:` → **Mode Triase** (§B).
- `share <fitur> feedback` → minta user paste blok, lalu Mode Triase.
- `share <fitur>` → **Mode Generate** (§A). Mode halaman `dibangun` bila dipanggil `ship` atau `feature.yaml` `status: shipped`; selain itu `rancangan`.
- Tanpa nama fitur → daftar fitur di `control/features/` yang punya `business.md`, minta pilih.

## A. Mode Generate

### 1. Baca
`control/features/<f>/`: `feature.yaml`, `business.md` (**wajib**; absen → STOP, arahkan `/intake <f>`), lalu bila ada: `fanout.md`, `plans/*.md`, `mockups/*`, `reviews.md`. Mode dibangun: juga `tasks.yaml` + bukti gate dari `ship` (§A.8). **Jangan** baca kode, `.env`, atau apa pun di luar folder fitur. Halaman ini dikirim ke luar tim.

### 2. Rencanakan isi
Ikuti `reference.md` §1–§3. Tentukan:
- bagian yang tampil (bagian tanpa data DILEWATI utuh)
- skenario cerita (5–7 langkah dari Flow `business.md`)
- kasus gagal, keputusan, keputusan terbuka (Pilih satu), dan 2–4 diagram

Tulis dulu **daftar frame**: `nama → mockup + selector/hash + device`.

### 3. Tangkap layar
Scratch: `.claude/share/<f>/img/`. Per frame:
```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/share/capture.py" --mockup "control/features/<f>/mockups/<m>.html" \
  --out ".claude/share/<f>/img" --name <nama> --select '<css>' --device tablet   # atau --hash <frag> / --full; --device phone; --hide '<css>'
```
Strategi isolasi: `reference.md` §4.
- Exit 4 (selector tak ketemu) → periksa mockup, perbaiki selector.
- Exit 1 "tangkapan kosong" → elemen salah / belum tergambar.
- **Exit 3 (Chrome tak ada)** → lanjut TANPA gambar (`reference.md` §4.5) dan sebut terus terang di ringkasan.

### 4. Tulis body
Tulis `.claude/share/<f>/body.html` HANYA dari komponen katalog `reference.md` §5. Nol CSS/JS baru. Patuhi §2 (isi & bahasa) dan §6 (Mermaid). Gambar `__IMG:<nama>__`, tombol mockup `__MOCK:<berkas>__`, angka revisi `__REV__` (eyebrow, footer), versi di footer `__HASH__`.

### 5. Rakit
```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/share/assemble.py" --feature-dir "control/features/<f>" \
  --body ".claude/share/<f>/body.html" --images ".claude/share/<f>/img" --mode rancangan \
  --out "control/features/<f>/share.html"
```
- Exit 1 = validasi gagal: tiap masalah satu baris `error:` di stderr, output TIDAK ditulis. Perbaiki body, rakit ulang.
- Sukses: stdout `ok <hash> <bytes> <path>`.

### 6. Periksa
Render seluruh halaman (`reference.md` §9) dan **lihat** hasilnya: gambar terbaca? urutan benar? teks kepanjangan? ada yang kosong? Perbaiki, rakit ulang. Jangan menyerahkan file yang belum kamu lihat.

### 7. `.gitignore` (self-heal)
Untuk baris `control/features/*/share.html` dan `.claude/share/`: cek `grep -qxF` di `<produk>/.gitignore`. Belum ada → `printf '%s\n' '<baris>' >> .gitignore` (buat file bila absen).

### 8. Ringkas
- **Lokasi:** path + ukuran file, dan `open control/features/<f>/share.html`.
- **Cara kirim:** buka dengan dobel-klik di browser (bukan pratinjau WA/Slack). Diagram butuh internet (offline → teks). Rekan klik 💬 / **Pilih**, isi nama, **Copy feedback**, kirim balik, lalu paste ke sini.
- **Data sensitif:** `sensitivity` memuat `pii`/`payments` → ingatkan SEKALI: "isi rancangan & mockup ikut terkirim — pastikan nggak ada data asli."
- **Mode dibangun dari `ship`:** bagian **Hasilnya** (`reference.md` §8) memakai bukti yang SUDAH dirakit `ship` untuk PR (link PR per repo, hasil gate, temuan alignment `critic`). Jangan menjalankan ulang gate.

## B. Mode Triase
1. **Parse** semua blok `=== FEEDBACK share:<f> === … === END ===` (bisa beberapa reviewer sekaligus). Fitur tak ada → STOP.
2. **Cek versi.** Hash di baris `versi:` dibandingkan `python3 "${CLAUDE_PLUGIN_ROOT}/skills/share/assemble.py" --hash-only --feature-dir control/features/<f>`. Beda → peringatkan "feedback buat versi lama (`<hash>`, `<tanggal>`)". Tetap triase, tandai **basi** baris yang bagiannya sudah berubah.
3. **Tabel triase** (bagian · isi ringkas · sumber · tahap saran · rekomendasi), aturan tahap `reference.md` §7.2. Baris `pilih:` = **suara** per grup, bukan keputusan.
4. **User putuskan per baris:** `terima` / `tolak` (+alasan) / `diskusi`. Rekomendasimu jujur (`${CLAUDE_PLUGIN_ROOT}/rules/anti-yes-man.md`): masukan yang bentrok dengan aturan/keputusan tercatat → tandai + rujuk nomornya.
5. **Catat** (append) ke `control/features/<f>/reviews.md`, format `reference.md` §7.3. Kutipan verbatim.
6. **Arahkan:** sebut SATU tahap paling awal di antara butir `terima`. User menjalankannya, lalu `/share <f>` lagi (bagian "Masukan kemarin → jadinya" terisi dari `reviews.md`). Nol butir terima → cukup catat.

## Guardrails
- **Nol tulis ke artefak tahap.** `share` hanya menulis `share.html`, `reviews.md`, scratch `.claude/share/`, dan `.gitignore`. `business.md`/`fanout.md`/`plans`/`mockups` milik `intake`/`fanout`/`plan`.
- **Nggak ngarang.** Kotak "Sekarang" hanya bila `business.md` menyatakan masalahnya. Kutipan masukan verbatim, atau ditulis sebagai topik. Tiap bagian ber-`data-src` ke sumbernya.
- **Nggak menghalangi.** Dipanggil `feature`/`ship`: gagal apa pun (Chrome, validasi yang tak beres) = catatan di ringkasan, status fitur tetap jalan.
- **Template tetap.** Kebutuhan komponen baru = ubah `template.html` di plugin (+ test), bukan CSS/JS di body.
- Lane `fix`/`tweak`/`debt` tidak di-share.
