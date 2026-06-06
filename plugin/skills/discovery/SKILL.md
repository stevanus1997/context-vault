---
name: discovery
description: Use saat punya ide produk MENTAH dan mau divalidasi jadi konsep produk sebelum init — business consultant pra-init (riset pasar, kompetitor, monetisasi, verdict go/no-go). Greenfield/tahap-ide SAJA; produk berkode pakai extract. Trigger — "validasi ide", "ide produk baru", "discovery", "konsultasi bisnis produk". Jalankan dari folder kosong calon produk.
---

# discovery — Business Consultant (pra-init)

Tujuan: ubah ide mentah jadi konsep produk yang tervalidasi (level STRATEGI, bukan fitur, NOL teknis), seed ke `control/business/` + hasilkan HTML strategis, lalu serahkan ke `init`.

> Operator mungkin BUKAN orang produk/bisnis. Tugasmu MENYETIR: usulkan & riset, jangan cuma mewawancara. **Riset web WAJIB** — jangan andalkan ingatan. Baca `${CLAUDE_PLUGIN_ROOT}/skills/discovery/reference.md` (framework pertanyaan + aturan sitasi/label), pakai `${CLAUDE_PLUGIN_ROOT}/skills/discovery/template.html` sebagai desain HTML, dan `${CLAUDE_PLUGIN_ROOT}/skills/discovery/chart-cheatsheet.md` untuk geometri chart-nya.

## Langkah

### 1. Tangkap ide mentah
Minta operator cerita idenya bebas. Rekam dalam kata-katanya sebagai bibit. Konfirmasi versi kasar 1 kalimat: "produk ini ngapain & buat siapa".

### 2. Riset + kembangkan konsep (loop)
Untuk tiap seksi di `reference.md` bagian A (masalah, pengguna, value, pasar, kompetitor, monetisasi, risiko): **riset web dulu** (kompetitor nyata, data pasar), lalu **usulkan draft** ke operator + jelaskan kenapanya. Tiap klaim faktual: catat sumber (URL + tanggal) & beri label keyakinan sesuai `reference.md` bagian B & C. JANGAN mengarang angka/URL.

### 3. Susun draft dok strategis
Rangkai temuan jadi draft: masalah · pengguna/segmen · value · pasar · kompetitor · monetisasi · risiko · **verdict** (`go`/`caution`/`no-go`). Verdict = kesimpulan jujur berbasis temuan (boleh negatif).

### 4. critic (GATE)
Invoke subagent `critic` atas draft. Minta khusus periksa: cherry-pick? sumber lemah/ngarang? lompatan logika di verdict? klaim berlabel `terverifikasi` tanpa sumber kuat? Tanggapi TIAP keberatan bersama operator; turunkan label klaim yang tak tahan uji. JANGAN lanjut sebelum keberatan ditanggapi.

### 5. Render HTML (visual-first)
Clone `${CLAUDE_PLUGIN_ROOT}/skills/discovery/template.html` APA ADANYA (CSS & struktur). Template ini **visual-first** — tiap section ditandai komentar (`<!-- HERO -->`, `<!-- CONCEPT -->`, `<!-- MASALAH -->`, `<!-- PENGGUNA -->`, `<!-- VALUE -->`, `<!-- PASAR -->`, `<!-- KOMPETITOR -->`, `<!-- MONETISASI -->`, `<!-- RISIKO -->`, `<!-- VERDICT -->`, `<!-- SUMBER -->`) dan punya elemen visual (meter, ring, funnel, line chart, matriks, gauge). Ganti **isi tiap section** dengan data produk nyata, **dan hitung ulang geometri tiap chart** sesuai `${CLAUDE_PLUGIN_ROOT}/skills/discovery/chart-cheatsheet.md`. Pertahankan: label keyakinan (`<span class="conf v|a|s">`), sitasi (superscript `<sup class="ref">` ke seksi Sumber), dan daftar Sumber. Ganti `StokKu` di `<title>` + brand sidebar dengan nama produk. **Hapus** banner `.demo` (`⚑ Contoh isi …`) karena isi sudah nyata. Tulis ke `./discovery-draft.html` di root folder produk (control/ belum ada). Self-contained (CSS inline dari template; sumber boleh `<a href>` eksternal, tapi TIDAK ada `<link>`/`<script src>`/gambar eksternal).

### 6. Review loop (GATE)
Suruh operator buka `./discovery-draft.html` & baca. Tampung feedback. Bila ada → balik ke langkah 2/3 (riset ulang / tajamkan) → regen HTML. ULANG sampai operator bilang **SEPAKAT**. JANGAN lanjut tanpa kata sepakat eksplisit.

### 7. Sepakat → init + seed (GATE)
1. Jalankan alur skill `init`. Kamu SUDAH punya framing (nama produk + 1 kalimat + apps yang kebayang) dari langkah 1–3, jadi `init` skip Framing Q&A-nya (lihat klausa di `init` langkah 3). `init` deteksi topologi (gate-nya sendiri) → scaffold `control/` + `workspace.yaml` + `CLAUDE.md`.
2. SEED `business/` (KONSERVATIF, hanya `terverifikasi` & durable — `reference.md` bagian D): `domain.md` (Produk/Pengguna/Nilai + `## Aturan Domain` awal bila jelas), `glossary.md` (istilah), `flows.md` (flow kunci bila ada), **`risks.md`** (kewajiban compliance dari seksi Risiko — `terverifikasi`/`asumsi`+sumber, carve-out M6, lihat `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`; slot tak relevan → `N/A — alasan`). Yang `asumsi`/`spekulatif` & analisis pasar JANGAN dimasukkan (kecuali kewajiban compliance → `risks.md`).
3. Pindahkan HTML final: `./discovery-draft.html` → `control/docs/discovery.html`.
4. Ringkas hasil + sarankan langkah berikut: `architect` (fondasi teknis).

## Catatan
- NOL teknis (stack/arsitektur = jatah `architect`). Berhenti di konsep produk; fitur = jatah `feature`/`intake`.
- Verdict bukan perintah — selalu "ini alasan + sumber, operator yang putuskan". Riset MENURUNKAN halusinasi, tidak MENGHAPUS.
- Brownfield berkode → pakai `extract`, bukan ini.
