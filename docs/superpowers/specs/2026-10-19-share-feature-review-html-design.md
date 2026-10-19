# Desain — `share`: satu file HTML untuk review fitur oleh rekan

**Tanggal:** 2026-10-19
**Status:** Draf (menunggu review user → `writing-plans`)
**Scope:** skill baru `share` (`SKILL.md` · `reference.md` · `template.html` · `capture.py` · `assemble.py`) · `feature` (langkah 4) · `ship` (langkah 6) · `guide/reference.md` · `init` + `upgrade` (`.gitignore`) · `tools/tests/share.test.sh` · regen `plugin-kimi/`
**Prototipe acuan:** `venue-tables-review-rev3.html` (v4, dipakai nyata untuk review partner 2026-10-13, produk KuyMahjong fitur `venue-tables` revisi 3)

---

## 1. Masalah

Satu `/feature` menghasilkan `business.md` (venue-tables revisi 3: 53KB, 25 keputusan, 20 aturan), `fanout.md`, `plans/_shared.md` + satu plan per app, dan mockup HTML. Semuanya ditulis untuk pipeline (Claude + `critic` + `build`), bukan untuk manusia lain. Akibatnya:

- **Rekan nggak bisa ikut review.** Mengirim folder `.md` = minta orang membaca ~150KB teks teknis. Nggak ada yang melakukannya.
- **Mockup mentah juga nggak membantu.** Prototipe v1 menyematkan mockup utuh di iframe. Reaksi user: *"yang mockup u plek ketiplek gt susah jga temen gw bacanya"*.
- **Feedback nggak punya jalur balik.** Komentar rekan datang lewat chat, lepas dari bagian yang dikomentari, dan nggak tercatat. Revisi 3 venue-tables lahir dari masukan rekan semacam itu (*"gak bisa on/off meja, harus on"*, *"add 4 orang"*, *"liat nya susah"*). Jejaknya cuma kutipan yang diselipkan ke `business.md`.

`render-docs` bukan jawabannya. Skill itu merender knowledge **tingkat produk** untuk stakeholder non-teknis, ditulis ke `control/docs/site/index.html` saat `ship`. Yang dibutuhkan di sini adalah artefak **per fitur**, untuk **rekan yang diminta menilai rancangan**, dengan feedback yang bisa ditarik balik ke pipeline.

## 2. Hasil yang diharapkan

Rekan menerima **satu file `.html`** (dikirim lewat WA/Slack/email). Dibuka dengan dobel-klik, dia langsung paham fiturnya dari gambar, bukan dari teks. Dia bisa memberi komentar per bagian dan memilih opsi yang masih terbuka, lalu menekan **Copy feedback** dan mengirim teksnya balik. Pemilik fitur mem-paste teks itu ke Claude, dan `share` menyusun triase yang dicatat dan diarahkan ke tahap pipeline yang tepat.

Kriteria berhasil (dari uji nyata v2→v4):
- Rekan memahami fitur tanpa membuka file lain dan tanpa membaca paragraf panjang.
- Masukan versi sebelumnya kelihatan sudah dijawab atau belum.
- Keputusan yang masih terbuka bisa dipilih langsung di file.
- Feedback yang kembali selalu menyebut bagian, sumber, dan versi.

## 3. Keputusan desain (dari brainstorming + uji partner)

| # | Keputusan | Alasan |
|---|-----------|--------|
| D1 | Skill **baru** `share`, bukan perluasan `render-docs` dan bukan tiap tahap menulis potongannya sendiri | `render-docs` = tingkat produk, audiens lain, dipanggil `ship`. Kalau tiap tahap menulis potongan, susunan dan nada halaman pecah. Nama `feedback` dihindari karena bentrok dengan `control/feedback/` (sinyal lapangan M8). |
| D2 | Kapan: otomatis di akhir `/feature` (status `active`) dan di `/ship` (mode "dibangun"). Manual `/share <fitur>` kapan saja setelah `business.md` ada | Uji nyata: share revisi 3 justru dibutuhkan **sebelum** gate plan, supaya rekan bisa memilih tata letak papan. |
| D3 | Feedback = 💬 per bagian + **Copy feedback** (blok teks terstruktur) → di-paste balik ke Claude. Satu file offline, tanpa server | Kanal kirim apa pun bisa dipakai. Nol infrastruktur. Komentar disimpan di browser rekan (localStorage). |
| D4 | Diagram: Mermaid dari CDN (`mermaid@11.4.1`, jsDelivr). Kalau offline, sumber diagram tampil sebagai teks | Satu-satunya ketergantungan jaringan. Gagalnya tetap bisa dibaca. |
| D5 | **Gambar dulu, kata belakangan.** Storyboard tangkapan layar mockup per langkah. Mockup utuh cuma lewat tombol di bagian Detail | Reaksi v1 ("masih bnyak kata2") dan v2→v3 (ringkasan apa & kenapa diminta). |
| D6 | Isi ditulis Claude (butuh penilaian). Kerja mekanis dikerjakan dua script: `capture.py` (tangkap layar) dan `assemble.py` (rakit, sematkan, hash) | Isi tetap sesuai fitur, sedangkan perakitan deterministik dan bisa dites. Pola prototipe (`cap.py` + `build.py`) terbukti di v4. |
| D7 | Output `control/features/<f>/share.html`, **di-gitignore**. Log triase `control/features/<f>/reviews.md` **di-commit** | File besar (v4: 2MB) dan bisa digenerate ulang. Keputusan atas feedback = knowledge. |
| D8 | `share` **tak pernah** mengubah `business.md`/`fanout.md`/`plans`/mockup. Triase hanya mencatat, lalu menyarankan tahap paling awal yang perlu diulang | Tahap pipeline tetap satu-satunya penulis artefaknya (gate, `critic`). |

## 4. Isi halaman

Urutan tetap. Bagian yang datanya nggak ada **dilewati utuh**: nggak ada judul kosong, nggak ada "TBD".

1. **Hero:**
   - eyebrow mode dan revisi ("Review rancangan · sebelum dibangun · revisi 3" / "Udah dibangun · cek sebelum merge")
   - judul pendek dan lede satu kalimat
   - chip: nama fitur, app yang kena, risiko (`feature.yaml` `risk`, chip peringatan bila `high`)
   - kotak hitam **"Yang gw minta"**: tugas pembaca dalam ≤ 3 butir bernomor, misalnya ① pilih opsi ② cek masukan kemarin ③ 💬 di mana aja
2. **Masukan kemarin → jadinya** (hanya bila ada versi sebelumnya yang direview):
   - satu baris per masukan: kutipan atau topik (miring) → hasilnya (tebal) → tautan "lihat ③" ke langkah cerita
   - sumber: butir `diterima` di `reviews.md`. Kalau tidak ada, pakai kutipan masukan yang tercatat di `business.md`/`fanout.md`/`plans`
   - **kutipan wajib verbatim**. Masukan tanpa kutipan ditulis sebagai topik, bukan kutipan karangan
3. **Apa & kenapa:**
   - kotak "Sekarang" (merah) → "Sesudah fitur ini" (hijau), 3–4 butir dari `business.md` Tujuan/Hasil
   - **"Sekarang" hanya diisi bila `business.md` menyatakan masalahnya**, nggak boleh dikarang. Kalau tidak ada, cuma kotak "Sesudah"
   - 2–3 kartu fakta siapa-pakai-apa (dari Pengguna)
4. **Ceritanya** (storyboard):
   - 5–7 langkah, satu skenario konkret dari `business.md` Flow (nama, jam, tempat sama dengan dokumen)
   - tiap langkah: nomor + waktu + judul 1 kalimat + keterangan 1 kalimat + 1–2 tangkapan layar
   - tata gambar: tunggal / `pair` (dua ponsel) / `pair wide` (tablet + ponsel)
   - langkah yang tak berubah dari revisi sebelumnya diberi tanda "sama kayak kemarin"
   - klik gambar → lightbox
5. **Pilih satu** (hanya bila ada keputusan terbuka):
   - opsi yang **secara eksplisit** menunggu pilihan user di dokumen (mis. `plans/venue.md`: "tata letak = SATU dari 3 opsi, dipilih user di gate"), dengan tangkapan layarnya
   - tiap opsi: gambar, judul, satu baris `+`, satu baris `−` (dari mockup/plan), tombol **Pilih X**
   - satu grup pilihan per keputusan terbuka. Maks 2 grup per halaman; sisanya jadi baris di Keputusan
6. **Kalau ada yang nggak beres:** 2 figur tangkapan layar kasus gagal paling penting, lalu sisanya satu baris per kasus di `<details>` ("▸ N kasus lain"). Risiko yang diterima ditebalkan.
7. **Keputusan:**
   - baris `pertanyaan → ✓ jawaban` + tag `baru`/`dibalik` untuk keputusan revisi terakhir
   - keputusan lama yang tetap dilipat
8. **Di balik layar:**
   - 2–4 diagram urutan Mermaid dalam tab, bahasa awam, nol nama RPC/tabel
   - catatan "Disederhanain dari `plans/`"
9. **Detail** (semua dilipat):
   - semua aturan satu baris
   - app yang kena (urut rilis)
   - yang nggak dikerjain
   - tombol buka **mockup interaktif lengkap** (disematkan base64, dibuka di tab baru)
10. **Footer:** "Dibuat otomatis dari `control/features/<f>/` · tanggal · revisi · versi `<hash>`".

**Mode "dibangun" (`ship`)** menambah bagian **Hasilnya** setelah Hero:
- task selesai/total (`tasks.yaml`) dan tautan PR per repo
- berkas berubah per app (`git diff --stat` terhadap base hasil deteksi `ship`) dan status quality/security gate (bukti dari langkah 2–4.5 `ship`)
- **"Beda dari rancangan"** dari temuan alignment `critic` (kosong → "Nggak ada"). Selain itu, kotak "Yang gw minta" diganti "cek hasilnya sebelum merge"
- tangkapan layar tetap dari mockup. Tangkapan layar app nyata = di luar scope (§10)

**Aturan bahasa** (ditegakkan `reference.md`):
- Indonesia santai, kalimat pendek
- judul langkah ≤ 1 kalimat, keterangan ≤ 1 kalimat
- istilah teknis diterjemahkan ("jatah meja", bukan `capacity`); nama dan contoh mengikuti dokumen sumber
- atribut `data-src` tiap bagian menunjuk sumbernya (`business.md#Keputusan 18 · Aturan 18`) supaya feedback bisa ditelusuri

## 5. Feedback di halaman

- **💬 per bagian.** Tiap elemen ber-`data-fb="<bagian>/<id>"` mendapat tombol. Isinya textarea dengan Simpan/Hapus, dan tombol berubah "💬 ✓" kalau sudah ada isi. `data-title` opsional menimpa judul turunan.
- **Grup pilihan** (`data-choice`). Tombol Pilih bersifat radio (klik lagi = batal). Pilihan dan komentar grup disimpan di entri yang sama.
- **Bar bawah tetap:** jumlah komentar, kolom nama (`localStorage` `share-fb:name`), **Komentar umum**, **Copy feedback**.
- **Penyimpanan:** `localStorage` kunci `share-fb:<fitur>:<hash>`. `<hash>` = 8 heksa pertama SHA-256 atas `business.md`, `fanout.md`, `plans/*.md`, `mockups/*` (urut nama; `reviews.md` sengaja tidak ikut, jadi mencatat triase tak mengganti versi). Versi baru = kunci baru, jadi komentar versi lama tak ikut ke versi baru. *(Koreksi prototipe v3 yang memakai tanggal.)* Semua akses storage dibungkus try/catch. Halaman tetap jalan tanpa storage (komentar hidup selama tab terbuka).
- **Format blok** (kontrak dengan mode triase §7):

```
=== FEEDBACK share:<fitur> ===
versi: <rancangan|dibangun> · revisi <n> · <YYYY-MM-DD> · <hash>
reviewer: <nama | (tanpa nama)>
---
[<bagian>/<id>] <judul>
sumber: <data-src>
pilih: <opsi>            # hanya untuk grup pilihan
> <baris komentar>
=== END ===
```

- Clipboard gagal (file:// di beberapa browser) → `prompt()` berisi teks untuk disalin manual.

## 6. Arsitektur skill

```
plugin/skills/share/
  SKILL.md        mode generate (rancangan | dibangun) + mode triase
  reference.md    katalog komponen, aturan isi & bahasa, strategi tangkap layar, aturan Mermaid, contoh
  template.html   kerangka v4: CSS, JS feedback/pilihan/lightbox/tab/mockup, slot <!-- BODY -->
  capture.py      tangkap layar frame mockup (headless Chrome) → JPEG
  assemble.py     template + body + gambar + mockup → share.html (+ hash, validasi)
```

### 6.1 Alur generate

1. **Baca:** `feature.yaml`, `business.md`, `fanout.md` (bila ada), `plans/*` (bila ada), `mockups/*` (bila ada), `reviews.md` (bila ada). Minimum = `business.md`. Kalau tidak ada, berhenti dan arahkan ke `/intake`. **Revisi** = angka "Revisi N" tertinggi di kepala `business.md` (tak ada → 1).
2. **Rencanakan isi** (`reference.md` §isi): pilih skenario cerita, langkah, kasus gagal, keputusan, diagram, dan keputusan terbuka. Untuk tiap langkah, tentukan frame mockup mana yang ditangkap.
3. **Tangkap layar** dengan `capture.py`. Claude memeriksa struktur mockup dan memilih cara isolasi per frame:
   - **frame statis** (`section#id .frame`, `figure#id .phone`, dll.): selector CSS. Elemen dipindah ke body kosong, sprite `<svg><symbol>` dipertahankan, transform di-reset.
   - **routing hash** (`#state/sub/dev`): URL + hash, CSS pembersih opsional untuk menyembunyikan chrome mockup.
   - **tanpa cara isolasi:** satu tangkapan halaman penuh.
   Ukuran: tablet lebar 1100px, ponsel 420px. Whitespace dipangkas bila PIL ada. Garis "batas layar" di bawah bingkai dipotong.
4. **Tulis body** (scratch `.claude/share/<f>/body.html`, gambar di `.claude/share/<f>/img/`) dari komponen katalog dengan placeholder `__IMG:<nama>__` dan `__MOCK:<berkas>__`.
5. **Rakit** dengan `assemble.py`. Hasilnya ke `control/features/<f>/share.html`.
6. **Periksa:** render headless + tes fungsi singkat (§9). Tunjukkan path dan ukuran, buka di browser, dan sebutkan cara kirim (dobel-klik, jangan pratinjau WA/Slack; diagram butuh internet).
7. **Self-heal `.gitignore`:** baris `control/features/*/share.html` dan `.claude/share/` di-append idempoten (`grep -qxF`, pola `build`).

### 6.2 `capture.py`

```
capture.py --mockup <path> --out <dir> --name <nama> (--select <css> | --hash <frag>) [--device tablet|phone] [--clean-css <file>]
```

- Mencari Chrome/Chromium: path macOS standar, `google-chrome`, `chromium`, `chromium-browser` di `PATH`. Tidak ketemu → exit 3 dengan pesan yang jelas.
- Menyuntik skrip isolasi ke salinan sementara mockup (bukan file asli). Lalu `--headless=new --hide-scrollbars --window-size=… --virtual-time-budget=3000 --screenshot`.
- PIL ada → pangkas latar putih, ubah ukuran ke lebar target, JPEG q82. PIL tidak ada → PNG apa adanya, plus satu baris peringatan.
- **Tanpa `CLAUDE_PLUGIN_ROOT`** di berkas mana pun. Script menemukan saudaranya lewat `__file__`, karena self-check `build-kimi.sh` gagal bila ada residu variabel itu dan rewrite-nya cuma menyentuh `.md`.

### 6.3 `assemble.py`

```
assemble.py --feature-dir <control/features/f> --body <body.html> --images <dir> --mode rancangan|dibangun --revision <n> --out <share.html>
```

- Menempel body ke slot template. Mengganti `__IMG:x__` → data URI, `__MOCK:x__` → base64 mockup (dibuka lewat `TextDecoder` di tab baru), `__META__` → `{feature, mode, revision, generated, hash}`.
- Menghitung hash sumber (§5).
- **Validasi (gagal = exit ≠ 0, nggak menulis output):**
  - sisa placeholder `__X:…__`
  - gambar yang dirujuk tapi tidak ada
  - `data-fb` ganda
  - `#` diikuti angka di dalam `pre.mermaid` yang belum di-escape `#35;` (bug v4: `"Meja #1"` terpotong)
  - `\n` di label Mermaid (harus `<br/>`)
  - kelas `.label` di body (bentrok dengan kelas internal Mermaid, bug v1)
- Melapor ukuran. Lebih dari 16MB → peringatan (batas lampiran umum), tetap ditulis.

### 6.4 Template

Kerangka v4 apa adanya. Token warna di `:root`, layout satu kolom di ≤ 800px, bar feedback tetap, lightbox, tab diagram, Mermaid dijalankan per tab/`details` saat dibuka. Komponen dan kelasnya (`hero`, `ask`, `chg`/`chg-row`, `why`, `facts`, `story`/`step`/`pair`/`pair wide`/`same`, `opts`/`opt`/`pro`/`con`/`pick`, `oops`, `list1`, `decs`/`dec`/`tag`, `tabs`/`diagram`, `detail`/`rules`) didokumentasikan di `reference.md` dengan cuplikan siap pakai. Claude **tidak** menulis CSS/JS baru per fitur.

## 7. Mode triase

**Pemicu:** argumen berisi `=== FEEDBACK share:` (paste), atau `/share <fitur> feedback`, yang lalu meminta paste.

1. **Parse** semua blok (bisa lebih dari satu reviewer sekaligus). Fitur tak dikenal → berhenti.
2. **Cek versi.** Hash blok dibandingkan hash sumber saat ini. Kalau beda, tampilkan peringatan "feedback untuk versi lama (`<hash>`, `<tanggal>`)". Komentar tetap ditriase, ditandai **basi** bila bagiannya sudah berubah.
3. **Tabel triase**, satu baris per komentar:
   - bagian, isi ringkas, sumber (`data-src`)
   - **tahap yang disarankan**, yaitu tahap paling awal yang memiliki artefak terdampak: aturan/keputusan/flow → `/intake`, app yang kena → `/fanout`, kontrak/UI/mockup → `/plan`, salah ketik/penyajian halaman → regenerate `share` saja
   Baris `pilih:` dikumpulkan per grup sebagai **suara**, bukan keputusan. Keputusannya tetap milik user di gate tahap pemilik opsi itu.
4. **User memutuskan per baris:** `terima` / `tolak` (+ alasan singkat) / `diskusi`. Claude memberi rekomendasi per baris (anti-yes-man berlaku: masukan yang bertentangan dengan aturan atau keputusan tercatat ditandai, dengan rujukannya).
5. **Catat** ke `control/features/<f>/reviews.md` (append). Entri per sesi: tanggal, reviewer, versi/hash, lalu per komentar `[bagian] kutipan verbatim → keputusan · alasan · tahap`, plus rekap suara pilihan.
6. **Arahkan.** Sebut **satu** tahap paling awal di antara butir `terima` (mis. "`/intake venue-tables` dulu, karena 2 butir mengubah aturan; `fanout`/`plan` ikut ulang sesudahnya"). Sesudah tahap itu selesai, `/share <fitur>` lagi. Bagian "Masukan kemarin → jadinya" lalu terisi dari `reviews.md`.

`share` tidak menjalankan tahap itu sendiri dan tidak menyunting artefak tahap (D8).

## 8. Integrasi

- **`feature` langkah 4 (Ringkas):** sesudah status `active`, invoke `share <nama>` (mode rancangan), lalu sebut path-nya di ringkasan. Kalau gagal (mis. Chrome tidak ada), cukup catatan, **bukan** penghalang: status tetap `active`.
- **`ship` langkah 6:** sesudah PR dibuat dan status `shipped`, invoke `share <fitur>` mode dibangun **sebelum** `render-docs`, dengan bukti gate yang sudah dirakit untuk PR. Kalau gagal, cukup catatan, bukan penghalang. Lane fix (`fix.yaml`) **tidak** di-share (di luar scope §10).
- **`guide/reference.md`:**
  - baris cheatsheet "Bagikan rancangan fitur ke rekan & tarik feedback-nya → `/share <fitur>`"
  - entri katalog satu baris
  - catatan beda dengan `/render-docs` (per-fitur untuk reviewer vs tingkat produk untuk stakeholder)
- **`init`** (langkah tulis `.gitignore`) **dan `upgrade`** (cek + merge `.gitignore`): tambah `control/features/*/share.html` dan `.claude/share/`.
- **`plugin-kimi/`:** regen lewat `tools/build-kimi.sh`. `.py`/`.html` ikut tersalin (`cp -R skills`). Test kimi menghitung `SKILL.md`, jadi skill baru otomatis tercakup.

## 9. Pengujian

`tools/tests/share.test.sh` (pola counter PASS/FAIL seperti `plugin/hooks/tests/*.test.sh`), dengan fixture `tools/tests/fixtures/share/` (fitur mini: `feature.yaml`, `business.md`, satu plan, mockup kecil berisi 2 frame statis dan 1 hash state):

1. **`assemble.py`:**
   - placeholder terganti semua dan hash stabil untuk sumber yang sama
   - hash berubah bila satu byte `business.md` berubah
   - masing-masing gagal (exit ≠ 0, output tak ditulis) untuk: placeholder sisa, gambar hilang, `data-fb` ganda, `#1` di Mermaid, `\n` di label, kelas `.label`
2. **`capture.py`** (dilewati dengan `skip` bila Chrome tidak ada): selector statis → JPEG/PNG non-kosong dengan lebar target. Selector tak ketemu → exit ≠ 0. Mockup asli tak berubah (checksum).
3. **Perilaku halaman** (headless Chrome `--dump-dom` + skrip uji yang disuntik, dilewati bila Chrome tidak ada):
   - komentar + pilihan → blok Copy feedback persis sesuai format §5 (clipboard di-stub)
   - pilihan bersifat radio
   - menghapus komentar tanpa menghapus pilihan
   - kunci storage memuat hash
4. **Statis:**
   - nol `CLAUDE_PLUGIN_ROOT` di `plugin/skills/share/*.py|*.html`
   - frontmatter `SKILL.md` valid
   - `build-kimi.test.sh` tetap hijau

Uji penerimaan manual: generate ulang venue-tables revisi 3 dari skill. Hasilnya setara v4 (bagian, urutan, pilihan A/B/C, kutipan masukan), dan triase blok feedback contoh menghasilkan `reviews.md` + saran tahap yang benar.

## 10. Di luar scope

- Tangkapan layar app **nyata** di mode dibangun (butuh app jalan + data seed). Mockup tetap jadi sumber gambar.
- Hosting/URL bersama, komentar kolaboratif waktu-nyata, server feedback. Satu file offline adalah inti D3.
- Share untuk lane `fix`/`tweak`/`debt`.
- Terjemahan ke bahasa lain dan tema gelap.
- Penyematan Mermaid offline (bundle ~2MB). Fallback teks dianggap cukup.

## 11. Risiko & catatan

- **Isi mockup ikut terkirim utuh** (tombol mockup lengkap + tangkapan layar). Data contoh mockup pipeline ini fiktif, tapi kalau fitur ber-`sensitivity` (`pii`/`payments`), `share` mengingatkan sekali sebelum menyebut file siap dikirim: "isi rancangan & mockup ikut terkirim; pastikan nggak ada data asli".
- **Chrome tidak terpasang:** generate tetap jalan tanpa gambar. Storyboard jadi teks dengan tombol mockup per langkah, dan halaman memberi tahu ini dengan jujur. `feature`/`ship` tidak terhalang.
- **Ukuran:** venue-tables revisi 3 = 2MB (35 JPEG + 2 mockup ±600KB base64). Masih wajar untuk WA/Slack/email.
- **Kesetiaan isi:** risiko terbesar adalah Claude mengarang ringkasan. Pagarnya: aturan "Sekarang hanya bila tertulis", kutipan verbatim, `data-src` per bagian yang menunjuk sumber, dan footer "dibuat otomatis dari …" supaya rekan tahu sumber kebenarannya `control/`.
