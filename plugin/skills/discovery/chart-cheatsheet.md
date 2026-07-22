# discovery — Chart Cheatsheet (render-time)

Dibaca saat **langkah 7 (Render HTML)**. `template.html` itu visual-first: tiap section
punya minimal 1 elemen visual statik (HTML/CSS/SVG). Saat ganti angka contoh dengan data
nyata, **hitung ulang geometri** sesuai aturan di bawah biar chart nggak meleset.

Semua warna pakai token `:root` template (`--accent --blue --amber --go --caution --nogo` + `*Soft`).

## Peta section → elemen visual

| Marker | Section | Elemen visual |
|--------|---------|---------------|
| `<!-- HERO -->` | 01 Ide / Hero | 3 kartu statistik + (`<!-- CONCEPT -->`) kartu konsep + daftar fitur |
| `<!-- MASALAH -->` | 02 Masalah | kartu + **severity meter** (bar %) per masalah |
| `<!-- PENGGUNA -->` | 03 Pengguna | kartu segmen + **score ring** (donut) per segmen |
| `<!-- VALUE -->` | 04 Value | split **before/after** + kalimat pembeda |
| `<!-- PASAR -->` | 05 Pasar | **funnel TAM/SAM/SOM** + **line chart** tren |
| `<!-- KOMPETITOR -->` | 06 Kompetitor | **matriks posisi 2×2** (SVG) + tabel banding |
| `<!-- MONETISASI -->` | 07 Monetisasi | 3 kartu tier harga (1 `.feat`) |
| `<!-- RISIKO -->` | 08 Risiko | **matriks risiko** (heat 3 kolom) + daftar risiko |
| `<!-- VERDICT -->` | 09 Verdict | badge + **gauge** skor + alasan |
| `<!-- SUMBER -->` | 10 Sumber | daftar bernomor (URL + tanggal akses) |

## Severity meter (Masalah)
```html
<div class="meter"><i style="width:88%;background:var(--nogo)"></i></div>
```
- `width` = skor intensitas 0–100 (%).
- Warna: `≥80 → var(--nogo)` · `50–79 → var(--caution)` · `<50 → var(--blue)`.

## Score ring / donut (Pengguna)
```html
<div class="ring" style="--p:86"><b>86</b></div>
```
- `--p` = skor 0–100. Angka di `<b>` samain.

## Funnel TAM/SAM/SOM (Pasar)
```html
<div class="fb" style="background:var(--blue);width:100%">…<span class="v">64<s>jt</s></span></div>
<div class="fb" style="background:#4f80b3;width:80%">…</div>
<div class="fb" style="background:var(--accent);width:56%">…</div>
```
- `width` cuma VISUAL (bukan rasio literal): TAM `100%`, SAM `~75–85%`, SOM `~50–60%`.
- Angka asli ditaruh di `<span class="v">`. Label keyakinan di `.cap`.

## Line chart (Pasar) — 6 titik
- **X tetap**: `42, 112, 182, 252, 322, 392`.
- **Y dihitung** dari nilai persen. Sumbu: `0% → y=184`, `40% → y=40`. Rumus:
  ```
  y = 184 - (persen / 40) * 144
  ```
  Contoh: 10%→148, 20%→112, 30%→76.
- Update DI TIGA tempat dengan koordinat yang sama: `path` area (`fill`), `path` garis
  (`stroke`), dan `<circle>` titik. Ganti juga label tahun di sumbu-X kalau perlu.

## Matriks posisi 2×2 (Kompetitor)
- Area plot: `x: 48 → 382` (lebar 334), `y: 16 → 268` (tinggi 252).
- Tiap pemain `<circle cx cy>`:
  ```
  cx = 48 + (skor_sumbuX / 100) * 334
  cy = 268 - (skor_sumbuY / 100) * 252
  ```
  (di contoh StokKu: sumbu-X 0=pembukuan→100=stok, sumbu-Y 0=gratis→100=premium)
- Lingkaran "kita" pakai `fill:var(--accent)` + `stroke:#fff stroke-width:3` biar nonjol.

## Matriks risiko (Risiko)
- Area plot: `x: 50 → 326` (lebar 276), `y: 14 → 238` (tinggi 224).
  ```
  cx = 50 + (kemungkinan / 100) * 276
  cy = 238 - (dampak / 100) * 224
  ```
- Warna titik = level: `Tinggi var(--nogo)` · `Sedang var(--caution)` · `Rendah var(--go)`.
- 3 kolom heat (hijau/amber/merah) cuma background — gak usah diubah.

## Gauge skor (Verdict)
- Setengah lingkaran, pusat `(100,102)`, radius `80`. Latar: `M20,102 A80,80 0 0,1 180,102`.
- Arc isi dari kiri `(20,102)` ke titik sesuai skor `S` (0–100):
  ```
  θ (radian) = (S / 100) * π
  x = 100 - 80 * cos(θ)
  y = 102 - 80 * sin(θ)
  → path: d="M20,102 A80,80 0 0,1 {x},{y}"
  ```
  Contoh `S=58`: x≈122, y≈25. Ganti juga angka `58` di `<text>` & badge.
- Badge verdict (`.vbadge`): `GO → var(--go)` · `CAUTION → var(--caution)` · `NO-GO → var(--nogo)`.
