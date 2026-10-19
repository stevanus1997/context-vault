# share — Referensi isi, komponen & triase

Dibaca `SKILL.md` sebelum generate/triase. Prototipe acuan: review `venue-tables` revisi 3 (KuyMahjong, 2026-10-13). Desain: `docs/superpowers/specs/2026-10-19-share-feature-review-html-design.md` di repo plugin.

## §1 Bagian, sumber, kapan dilewati

Urutan tetap. Bagian tanpa data **dilewati utuh** (tanpa judul kosong, tanpa "TBD").

| # | Bagian | Sumber | Dilewati bila |
|---|---|---|---|
| 1 | Hero + "Yang gw minta" | `feature.yaml` (nama, `risk`), `fanout.md` (app), revisi (`__REV__`, dihitung `assemble.py`: "Revisi N" tertinggi di kepala `business.md`, atau sesi terakhir `reviews.md` +1 bila sumber sudah berubah sejak direview) | tak pernah |
| — | Hasilnya (mode dibangun) | bukti `ship`, `tasks.yaml` | mode rancangan |
| 2 | Masukan kemarin → jadinya | butir `terima` di `reviews.md` sesi ber-hash ≠ hash sekarang. Tak ada → kutipan masukan yang tercatat di `business.md`/`fanout.md`/`plans` | belum pernah ada review/masukan |
| 3 | Apa & kenapa | `business.md` Tujuan, Hasil/Reward, Pengguna | tak pernah (kotak "Sekarang" bisa absen) |
| 4 | Ceritanya | `business.md` Flow/Skenario + `mockups/` | tak ada Flow |
| 5 | Pilih satu | opsi yang **tertulis** menunggu pilihan user (plan/mockup: "dipilih user di gate") | tak ada keputusan terbuka |
| 6 | Kalau ada yang nggak beres | `business.md` Edge/gagal + frame mockup error | tak ada Edge |
| 7 | Keputusan | `business.md` Keputusan (tag revisi) | tak ada Keputusan |
| 8 | Di balik layar | `plans/_shared.md` + `plans/<app>.md` | belum ada plan |
| 9 | Detail | Aturan, `fanout.md`, Out of scope, `mockups/` | per butir: dilewati bila sumbernya tak ada |
| 10 | Footer | — | tak pernah |

"Yang gw minta": ≤ 3 butir bernomor sesuai bagian yang ADA, misalnya ① pilih tata letak (bila §5 ada) ② cek masukan kemarin udah kejawab (bila §2 ada) ③ klik 💬 di mana aja.

## §2 Aturan isi & bahasa

- **Gambar dulu, kata belakangan.** Judul langkah ≤ 1 kalimat, keterangan ≤ 1 kalimat, baris keputusan `pertanyaan → jawaban` pendek. Paragraf = salah.
- Bahasa Indonesia santai ("nggak", "udah", "lo/gw" boleh bila produk memakai gaya itu). Istilah teknis diterjemahkan: "jatah meja", bukan `capacity`. **Nol nama RPC/tabel/kolom/kode error** di luar bagian Detail.
- Nama, jam, tempat, angka **sama dengan dokumen sumber**. Jangan bikin contoh baru.
- **"Sekarang"** (kotak merah) hanya bila `business.md` menyatakan masalah/keadaan sekarang. Kalau tidak, tampilkan cuma "Sesudah fitur ini".
- **Kutipan** (`"…"`, miring) wajib verbatim dari `reviews.md`/dokumen. Masukan tanpa kutipan → tulis sebagai topik, tanpa tanda kutip.
- Tiap elemen ber-`data-fb` WAJIB punya `data-src` yang menunjuk sumbernya: `business.md#Keputusan 18 · Aturan 18`, `plans/venue.md#BoardScreen · mockup venue-tables #opsi-a`.
- `data-fb` = `<bagian>/<slug>`, unik sehalaman. Prefiks bagian: `hasil`, `berubah`, `ringkasan`, `cerita`, `pilihan`, `masalah`, `keputusan`, `balik-layar`, `detail`.
- Risiko yang diterima ditebalkan (`<b>risiko diterima</b>`) di daftar kasus.
- Kelas `label` dilarang di body (bentrok dengan Mermaid). Pakai nama lain.

## §3 Storyboard

- Satu skenario konkret dari Flow `business.md` (venue-tables: "Sabtu 24 Okt di Arkam Mahjong: Meja 1–4 otomatis, 5–6 manual"). Sebut skenarionya di `hsub`.
- **5–7 langkah**, urut waktu. Satu langkah = satu momen yang mengubah sesuatu bagi pengguna. Langkah persiapan sekali jalan boleh jadi langkah 1 (`time`: "sekali di awal").
- Gambar per langkah:
  - 1 tangkapan tablet/desktop **atau**
  - `pair` (2 ponsel) **atau**
  - `pair wide` (tablet + ponsel, misalnya aksi kasir + yang dilihat pemain)
- Langkah yang tak berubah dari revisi sebelumnya → `<span class="same">sama kayak kemarin</span>`.
- Revisi > 1 dengan banyak perubahan: dahulukan langkah yang menunjukkan perubahan. Langkah lama yang masih penting cukup 1.
- Bagian "Masukan kemarin → jadinya" menautkan ke langkah (`<a href="#s3">lihat ③</a>`), jadi tiap langkah ber-`id="sN"`.

## §4 Tangkap layar

Periksa struktur mockup dulu (cari `id` frame, kelas bingkai, routing hash, elemen dekorasi), baru pilih cara.

1. **Frame statis** (paling umum di mockup `plan`): halaman panjang berisi banyak bingkai ber-`id`.
   - tablet: `--select '#f5a .frame' --device tablet`
   - ponsel: `--select '#f10b .phone' --device phone`
   Skrip memindah elemen ke body kosong, mempertahankan sprite `<svg><symbol>`, dan me-reset `transform` (bingkai yang di-*scale* agar muat).
2. **Elemen dekorasi mockup** (garis "batas layar", label anotasi, toolbar): `--hide '.fold' --hide '.g-cap'`. Contoh venue-tables: `.fold` = garis merah putus-putus batas layar tablet.
3. **Routing hash** (mockup satu-layar-banyak-state, misalnya `#atur`, `#walkin/rebut/L`): `--hash 'walkin/rebut/L'`. Chrome mockup (header state, catatan) disembunyikan lewat `--clean-css <file>` atau `--hide`.
4. **Tak bisa diisolasi:** `--full` (halaman penuh, dipangkas).
   Frame/halaman yang lebih tinggi/lebar dari jendela device: jendela diperbesar otomatis sampai muat (maks 10000px, lebih dari itu ada peringatan).
5. **Mockup berupa gambar** (`.png/.jpg` di `mockups/`): tidak ditangkap. Salin ke `.claude/share/<f>/img/<nama>.<ext>`.
6. Nama gambar: `v-<id>` (tablet/venue), `p-<id>` (ponsel/pemain), atau `<app>-<id>`. Pendek dan stabil.

### §4.5 Tanpa Chrome
Storyboard tetap ditulis, tapi tanpa `<img>`: tiap langkah memakai tombol `<button class="btn" data-mock="__MOCK:<berkas>__">Lihat layar ↗</button>`. `hsub` Ceritanya: "Gambar nggak tersedia di versi ini — buka layarnya lewat tombol." Bagian "Pilih satu" tanpa gambar memakai tombol yang sama per opsi. Sebutkan di ringkasan bahwa Chrome tak ada.

## §5 Katalog komponen

Salin cuplikan apa adanya, lalu ganti isinya. Semua cuplikan di bawah lolos `assemble.py` bila dirakit bersama (diuji `tools/tests/share.test.sh` S8), jadi `data-fb`-nya unik antar-cuplikan.

### Hero
```html
<header class="hero">
  <div class="eyebrow">Review rancangan · sebelum dibangun · revisi __REV__</div>
  <h1>Papan meja: walk-in &amp; room online satu hitungan</h1>
  <p class="lede">Revisi 3 nambahin jenis meja, room ber-4, dan "Kabari aku", dari masukan kemarin.</p>
  <div class="chips"><span class="chip">venue-tables</span><span class="chip">app pemain + venue + admin + database</span><span class="chip warn">risiko tinggi</span></div>
  <div class="ask">👀 <span><b>Yang gw minta:</b> ① <a href="#pilih">pilih tata letak papan</a> A/B/C ② cek masukan kemarin udah kejawab ③ klik <b>💬</b> di mana aja.</span></div>
</header>
```
Mode dibangun: eyebrow `Udah dibangun · cek sebelum merge · revisi __REV__`, ask `cek hasilnya sebelum merge`. `chip warn` hanya untuk `risk: high`.

### Masukan kemarin → jadinya
```html
<h2 class="h" style="margin-top:28px">Masukan kemarin → jadinya</h2>
<p class="hsub">Yang berubah sejak revisi 2.</p>
<div class="chg">
  <div class="chg-row" data-fb="berubah/saklar" data-src="business.md#Keputusan 17 · Aturan 15"><span class="from">"gak bisa on/off meja, harus on"</span><span class="arr">→</span><span class="to">Owner nggak punya tombol nyala/mati lagi. Papan dinyalain tim KuyMahjong.</span><a href="#s1">lihat ①</a></div>
  <div class="chg-row" data-fb="berubah/kabari" data-src="business.md#Keputusan 19 · Aturan 19"><span class="from">Jam penuh, terus gimana?</span><span class="arr">→</span><span class="to">Tombol "Kabari aku": dapat notif kalau mejanya kebuka lagi.</span><a href="#s4">lihat ④</a></div>
</div>
```

### Apa & kenapa
```html
<h2 class="h">Apa &amp; kenapa</h2>
<p class="hsub">Biar pemain online &amp; tamu yang datang langsung bener-bener sinkron.</p>
<div class="why" data-fb="ringkasan/kenapa" data-src="business.md#Tujuan + Hasil/Reward">
  <div class="why-col before">
    <div class="why-tag">Sekarang</div>
    <ul><li>Walk-in dan room online <b>dihitung terpisah</b></li></ul>
  </div>
  <div class="why-arrow">→</div>
  <div class="why-col after">
    <div class="why-tag">Sesudah fitur ini</div>
    <ul><li><b>Satu jatah meja</b> dipakai bareng walk-in &amp; room online</li></ul>
  </div>
</div>
<div class="facts">
  <div><span>Kasir &amp; owner</span><b>Papan meja + tab "Per meja"</b></div>
  <div><span>Pemain</span><b>Pilih durasi, jenis meja, "Udah ber-4"</b></div>
</div>
```
Tanpa "Sekarang": hapus `why-col before` + `why-arrow`, sisakan `after`.

### Ceritanya
```html
<h2 class="h">Ceritanya</h2>
<p class="hsub">Sabtu 24 Okt di Arkam Mahjong: Meja 1–4 otomatis, Meja 5–6 manual. Klik gambar buat perbesar.</p>
<div class="story">
  <div class="step" id="s1" data-fb="cerita/1-atur-meja" data-src="business.md#R1 + Aturan 15 · mockup venue-tables #f5a">
    <div class="txt"><span class="num">1</span><span class="time">sekali di awal</span>
      <h3>Owner daftarin meja + jenisnya. Papan dinyalain tim KuyMahjong.</h3><p>Owner nggak punya tombol nyala/mati lagi.</p></div>
    <img class="shot" src="__IMG:v-f5a__" alt="Atur meja">
  </div>
  <div class="step" id="s2" data-fb="cerita/2-ber-4" data-src="business.md#R2 · mockup player f10b, venue-tables #f7a">
    <div class="txt"><span class="num">2</span><span class="time">10.00</span>
      <h3>Gita udah ber-4: room langsung terkunci</h3><p>Nggak muncul di feed.</p></div>
    <div class="pair wide">
      <figure><img class="shot" src="__IMG:v-f7a__" alt="Ada meja"><figcaption>Kasir pilih meja</figcaption></figure>
      <figure><img class="shot" src="__IMG:p-f10b__" alt="Udah ber-4"><figcaption>Gita pilih "Udah ber-4"</figcaption></figure>
    </div>
  </div>
  <div class="step" id="s3" data-fb="cerita/3-penuh" data-src="business.md#R3 · mockup player f1, f4">
    <div class="txt"><span class="num">3</span><span class="time">14.00</span><span class="same">sama kayak kemarin</span>
      <h3>Hendra: meja otomatis penuh, manual masih ada</h3><p>Dia tap "Kabari aku".</p></div>
    <div class="pair">
      <figure><img class="shot" src="__IMG:p-f1__" alt="Penuh"><figcaption>Satu baris status</figcaption></figure>
      <figure><img class="shot" src="__IMG:p-f4__" alt="Kabari aku"><figcaption>"Kabari aku" aktif</figcaption></figure>
    </div>
  </div>
</div>
```

### Pilih satu
`data-choice` WAJIB sama dengan `data-fb` grup itu. `data-title` = judul di blok feedback. Maks 2 grup per halaman.
```html
<h2 class="h" id="pilih">Pilih satu: tata letak papan</h2>
<p class="hsub">Datanya sama persis, cuma cara gambarnya beda.</p>
<div class="opts" data-choice="pilihan/papan" data-fb="pilihan/papan" data-title="Tata letak papan (A/B/C)" data-src="plans/venue.md#BoardScreen · mockup venue-tables #opsi-a/b/c">
  <div class="opt" data-val="A">
    <img class="shot" src="__IMG:v-opsi-a__" alt="Opsi A">
    <h3>A · Kartu per jenis</h3>
    <p class="pro">Mirip kemarin, paling cepat dibangun</p>
    <p class="con">Janji berikutnya baru kelihatan kalau di-tap</p>
    <button class="btn pick">Pilih A</button>
  </div>
  <div class="opt" data-val="B">
    <img class="shot" src="__IMG:v-opsi-b__" alt="Opsi B">
    <h3>B · Daftar baris</h3>
    <p class="pro">Padat: 12 meja muat tanpa scroll</p>
    <p class="con">Kurang kebaca dari jauh</p>
    <button class="btn pick">Pilih B</button>
  </div>
</div>
```

### Kalau ada yang nggak beres
```html
<h2 class="h">Kalau ada yang nggak beres</h2>
<p class="hsub">Papan selalu jujur, nggak pernah pura-pura berhasil.</p>
<div class="oops">
  <figure data-fb="masalah/ubah-jenis-ditolak" data-src="business.md#Edge revisi 3 · mockup #f5c">
    <img class="shot" src="__IMG:v-f5c__" alt="Ditolak">
    <figcaption><b>Ubah jenis meja ditolak kalau bikin jatah kurang</b><span>Pindahin dulu room yang udah dijanjiin.</span></figcaption>
  </figure>
  <figure data-fb="masalah/perpanjang-ditolak" data-src="business.md#Edge Case 3 · mockup #r2-extend">
    <img class="shot" src="__IMG:v-r2-extend__" alt="+1 jam ditolak">
    <figcaption><b>+1 jam ditolak kalau semua meja udah kepakai</b><span>Contohnya room 4/4 yang datang jam 20.00.</span></figcaption>
  </figure>
</div>
<details class="more"><summary>▸ 2 kasus lain</summary>
  <ul class="list1">
    <li data-fb="masalah/ber-4-palsu">1 akun ngaku ber-4 <span>→ <b>risiko diterima</b>, venue boleh jawab "Gak ada meja"</span></li>
    <li data-fb="masalah/meja-terakhir">Owner nonaktifin meja terakhir <span>→ ditolak</span></li>
  </ul>
</details>
```

### Keputusan
Tag: `baru` / `dibalik` (keputusan revisi terakhir). Keputusan lama yang tetap → `details.more` + `list1`.
```html
<h2 class="h">Keputusan yang udah diambil</h2>
<p class="hsub">Yang baru di revisi 3.</p>
<div class="decs">
  <div class="dec" data-fb="keputusan/17" data-src="business.md#Keputusan 17"><span class="q">Siapa nyalain papan?</span><span class="a">Tim KuyMahjong, bukan owner</span><span class="tag">dibalik</span></div>
  <div class="dec" data-fb="keputusan/18" data-src="business.md#Keputusan 18"><span class="q">Room ber-4 dikunci kapan?</span><span class="a">Langsung pas dibuat</span><span class="tag">baru</span></div>
</div>
<details class="more"><summary>▸ 1 keputusan sebelumnya yang tetap</summary>
  <ul class="list1">
    <li data-fb="keputusan/9">App pemain ikut baca papan <span>→ jam penuh nggak bisa dipilih</span></li>
  </ul>
</details>
```

### Di balik layar
Satu grup tab per halaman. Panel pertama tanpa `hidden`, sisanya `hidden`. Id `seq-1…seq-n`. Aturan diagram: §6.
```html
<h2 class="h">Di balik layar</h2>
<p class="hsub">Siapa ngomong ke siapa.</p>
<div class="tabs" role="tablist">
  <button data-tab="seq-1" aria-selected="true">Room ber-4</button>
  <button data-tab="seq-2" aria-selected="false">Kabari aku</button>
</div>
<div class="diagram" id="seq-1" data-panel data-fb="balik-layar/ber-4" data-src="plans/_shared.md#12 Room 4 orang">
<pre class="mermaid">
sequenceDiagram
  actor G as Gita
  participant A as App pemain
  participant DB as Database
  G->>A: Udah ber-4, 19.00, 3 jam
  A->>DB: bikin room ber-4
  alt HP belum ada
    DB-->>A: ditolak + alasannya
  else lolos
    DB-->>A: "Meja #35;1 siap · otomatis"
  end
</pre>
</div>
<div class="diagram" id="seq-2" data-panel hidden data-fb="balik-layar/kabari" data-src="plans/_shared.md#11 Kabari aku">
<pre class="mermaid">
sequenceDiagram
  actor H as Hendra
  participant DB as Database
  H->>DB: Kabari aku (19.00 otomatis)
  DB-->>H: notif "Meja kebuka lagi"<br/>(ke semua penunggu)
</pre>
</div>
<p class="note">Disederhanain dari <code>plans/</code>.</p>
```

### Detail
```html
<h2 class="h">Detail</h2>
<p class="hsub">Buat yang mau gali lebih dalam.</p>
<details class="detail"><summary>Semua aturan <span class="hint">2</span></summary><div class="body"><ol class="rules">
  <li>Meja: nama pendek unik, nggak bisa dihapus.</li>
  <li><b>Jatah meja</b>: walk-in + room ≤ jumlah meja, per jenis.</li>
</ol></div></details>
<details class="detail"><summary>App yang kena <span class="hint">2: database duluan</span></summary><div class="body">
  <b>1. Database</b>: meja + jenis, jatah per jenis.<br>
  <b>2. App pemain</b>: durasi, jenis meja, "Udah ber-4".
</div></details>
<details class="detail"><summary>Nggak dikerjain sekarang <span class="hint">2</span></summary><div class="body">
  Harga per jenis meja · pilihan "terserah"
</div></details>
<details class="detail"><summary>Mockup interaktif lengkap <span class="hint">buat yang teliti</span></summary><div class="body">
  <button class="btn" data-mock="__MOCK:venue-tables.html__">App venue (26 frame) ↗</button>
</div></details>
```

### Footer
```html
<footer>Dibuat otomatis dari <code>control/features/venue-tables/</code> · 13 Okt 2026, revisi __REV__ · versi __HASH__</footer>
```

## §6 Mermaid

- Hanya `sequenceDiagram`, 2–4 diagram. Peserta pakai nama awam (`actor K as Kasir`, `participant DB as Database`). **Nol nama RPC/tabel.**
- `#` diikuti angka WAJIB `#35;` (`"Meja #35;1 siap"`). Mermaid membaca `#1…` sebagai entitas dan memotong teks. Divalidasi `assemble.py`.
- Baris baru di label: `<br/>`, bukan `\n` (divalidasi).
- Cabang sukses/gagal pakai `alt … else … end`, singkat.
- Satu diagram ≤ ~12 pesan. Kalau lebih, pecah jadi dua tab.

## §7 Feedback & triase

### §7.1 Blok dari halaman
```
=== FEEDBACK share:<fitur> ===
versi: <rancangan|dibangun> · revisi <n> · <YYYY-MM-DD> · <hash>
reviewer: <nama | (tanpa nama)>
---
[<bagian>/<id>] <judul>
sumber: <data-src>
pilih: <opsi>            # hanya grup pilihan
> <baris komentar>
=== END ===
```
`[umum]` = Komentar umum (tanpa `sumber:`).

### §7.2 Tahap yang disarankan
Tahap **paling awal** yang memiliki artefak terdampak:

| Komentar menyentuh | Tahap |
|---|---|
| tujuan, pengguna, flow, aturan, keputusan, kasus gagal, scope | `/intake <f>` |
| app/package/vendor yang kena | `/fanout <f>` |
| kontrak, UI, mockup, urutan rilis, diagram | `/plan <f>` |
| penyajian halaman saja (salah ketik, gambar kurang jelas, urutan) | regenerate `/share <f>` |
| `pilih:` | suara untuk gate tahap pemilik opsi (biasanya `/plan`). Catat rekapnya, user yang memutuskan di gate |

### §7.3 `reviews.md`
Append. Satu sesi per paste. Kutipan verbatim; komentar multi-baris digabung dengan ` / `, dan `|` di-escape `\|`.
```markdown
# Review — <fitur>

## 2026-10-14 · Rina · versi 77b1e9f9 (revisi 3, rancangan)
Suara: `pilihan/papan` → B

| Bagian | Komentar | Keputusan | Alasan | Tahap |
|---|---|---|---|---|
| berubah/ber-4 | "Mantap, tapi HP wajib agak ribet" | tolak | HP wajib = Keputusan 24(b), venue harus bisa hubungi rombongan | — |
| cerita/4-kabari | "Notifnya kirim juga ke WA?" | diskusi | butuh kanal baru, di luar scope | — |
| masalah/meja-terakhir | "Owner tetap perlu cara berhenti" | terima | — | /intake |

Arahan: `/intake venue-tables` dulu (1 butir mengubah aturan); `fanout`/`plan` ikut ulang sesudahnya, lalu `/share venue-tables`.
```
Bagian "Masukan kemarin → jadinya" generate berikutnya mengambil baris `terima` dari sesi terakhir yang hash-nya ≠ hash sekarang. Kolom Komentar dipakai sebagai kutipan, dan hasilnya diambil dari artefak yang sudah direvisi.

## §8 Mode dibangun — Hasilnya
Setelah Hero. Sumber: bukti yang dirakit `ship` untuk PR. Manual pada fitur `shipped`: `tasks.yaml` + `feature.yaml` `shipped_at`. PR/gate yang tak diketahui dilewati, bukan ditebak.
```html
<h2 class="h" style="margin-top:28px">Hasilnya</h2>
<p class="hsub">Yang udah dibangun dibanding rancangan.</p>
<div class="facts" data-fb="hasil/ringkas" data-title="Hasilnya" data-src="tasks.yaml · PR · gate ship">
  <div><span>Task</span><b>18/18 selesai</b></div>
  <div><span>PR</span><b><a href="https://github.com/org/repo/pull/12">repo#12</a></b></div>
  <div><span>Gate</span><b>Test, lint, security ✓</b></div>
</div>
<div class="decs" style="margin-top:12px">
  <div class="dec" data-fb="hasil/beda-1" data-src="ship · alignment critic"><span class="q">Rancangan: tab "Per meja" tersembunyi saat papan mati</span><span class="a">Jadinya: tetap tampil, kosong</span><span class="tag">beda</span></div>
</div>
<details class="detail" style="margin-top:12px"><summary>Berkas berubah <span class="hint">2 app</span></summary><div class="body">
  <b>kuymahjong</b>: 14 berkas (+820 −40)<br>
  <b>venue</b>: 22 berkas (+1.310 −95)
</div></details>
```
Tak ada beda → satu baris `dec`: "Beda dari rancangan?" → "Nggak ada".

## §9 Pemeriksaan visual
```bash
CHROME="$(python3 "${CLAUDE_PLUGIN_ROOT}/skills/share/capture.py" --find-chrome)"
"$CHROME" --headless=new --disable-gpu --hide-scrollbars --user-data-dir="$(mktemp -d)" \
  --window-size=1280,12000 --virtual-time-budget=8000 \
  --screenshot="$PWD/.claude/share/<f>/page.png" "file://$PWD/control/features/<f>/share.html"
python3 - ".claude/share/<f>/page.png" <<'PY'
import sys
from PIL import Image
im=Image.open(sys.argv[1]); w,h=im.size; n=0
for y in range(0,h,2400):
    im.crop((0,y,w,min(y+2400,h))).resize((w//2,(min(y+2400,h)-y)//2)).save(sys.argv[1].replace('.png',f'-{n}.jpg'),quality=80); n+=1
PY
```
Lihat tiap potongan (`page-0.jpg`, …). Ruang kosong panjang di bawah = tinggi jendela kelebihan, bukan bug. Cek juga lebar ponsel (`--window-size=390,12000`): satu kolom, tanpa scroll ke samping. Tanpa Pillow → lihat `page.png` utuh.
