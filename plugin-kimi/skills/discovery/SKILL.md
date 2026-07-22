---
name: discovery
description: Use saat punya ide produk MENTAH dan mau divalidasi jadi konsep produk sebelum init — business consultant pra-init (Q&A visi operator dulu, lalu riset pasar, kompetitor, monetisasi, verdict go/no-go; compliance conditional opt-in). Greenfield/tahap-ide SAJA; produk berkode pakai extract. Trigger — "validasi ide", "ide produk baru", "discovery", "konsultasi bisnis produk". Jalankan dari folder kosong calon produk.
---

> **Harness Kimi Code:** sebelum dispatch subagent apa pun, baca `${KIMI_SKILL_DIR}/../../rules/kimi-harness.md` (mapping critic/implementer → sub-agent bawaan Kimi).

# discovery — Business Consultant (pra-init)

Tujuan: ubah ide mentah jadi konsep produk yang tervalidasi (level STRATEGI, bukan fitur, NOL teknis), seed ke `control/business/` + hasilkan HTML strategis, lalu serahkan ke `init`.

> Operator mungkin BUKAN orang produk/bisnis. Tugasmu MENYETIR: usulkan & riset, jangan cuma mewawancara. **Riset web WAJIB** — jangan andalkan ingatan. Baca `${KIMI_SKILL_DIR}/../../skills/discovery/reference.md` (framework pertanyaan + aturan sitasi/label), pakai `${KIMI_SKILL_DIR}/../../skills/discovery/template.html` sebagai desain HTML, dan `${KIMI_SKILL_DIR}/../../skills/discovery/chart-cheatsheet.md` untuk geometri chart-nya.

## Langkah

### 1. Tangkap ide mentah
Minta operator cerita idenya bebas. Rekam dalam kata-katanya sebagai bibit. Konfirmasi versi kasar 1 kalimat: "produk ini ngapain & buat siapa".

### 2. Q&A visi produk (SEBELUM riset)
Ikuti `${KIMI_SKILL_DIR}/../../rules/elicitation.md` (keputusan-bercabang satu per giliran, opsi bawa konsekuensi). Gali dari operator — masalah versi DIA, siapa penggunanya menurut dia, hasil/nilai yang diincar, batasan/keharusan yang sudah ia tetapkan, gambaran sukses. **Riset web DILARANG di step ini** — ini sesi memahami visi, bukan memvalidasi. Operator menjawab "gak tau/terserah" pada suatu slot → tandai slot itu `AI-usul`, AI yang mengusulkan di step 3. Visi = operator menyetir; JANGAN menimpa jawaban operator dengan usulan riset diam-diam.

### 3. Riset validasi + kembangkan konsep (loop)
Untuk tiap seksi di `reference.md` bagian A selain Visi & Risiko (masalah, pengguna, value, pasar, kompetitor, monetisasi): **riset web dulu** (kompetitor nyata, data pasar), lalu **usulkan draft** ke operator + jelaskan kenapanya — tiap usulan DIIKAT balik ke jawaban visi step 2; slot `AI-usul` diisi penuh oleh AI. Riset bertentangan dengan visi → tunjukkan buktinya, operator yang putuskan (JANGAN menimpa diam-diam). Tiap klaim faktual: catat sumber (URL + tanggal) & beri label keyakinan sesuai `reference.md` bagian B & C. JANGAN mengarang angka/URL.

### 4. Risiko + compliance (conditional)
Risiko BISNIS (pasar jenuh, switching cost, beratnya eksekusi) digali untuk SEMUA produk seperti seksi lain. **Asesmen compliance terstruktur** (PCI/GDPR/pajak/KYC + regulasi sektor — `${KIMI_SKILL_DIR}/../../rules/compliance-risk.md`) HANYA bila ide kena heuristik pemicu — menggerakkan/menyimpan uang · PII berat (gov-id/kesehatan/finansial) · sektor regulated (keuangan, kesehatan, pendidikan-anak, dst.) — dan itu pun lewat SATU pertanyaan opt-in ("produk ini kena sinyal <X> — mau kucek kewajiban regulasinya sekali jalan?"). Default/decline → SKIP — seksi Risiko HTML memuat baris "compliance dilewati atas pilihan operator", `risks.md` TIDAK di-seed (skeleton = jalur degrade normal pembaca M6).

### 5. Susun draft dok strategis
Rangkai temuan jadi draft: masalah · pengguna/segmen · value · pasar · kompetitor · monetisasi · risiko · **verdict** (`go`/`caution`/`no-go`). Verdict = kesimpulan jujur berbasis temuan (boleh negatif).

### 6. critic (GATE)
Invoke subagent `critic` atas draft. Minta khusus periksa: cherry-pick? sumber lemah/ngarang? lompatan logika di verdict? klaim berlabel `terverifikasi` tanpa sumber kuat? Tanggapi TIAP keberatan bersama operator; turunkan label klaim yang tak tahan uji. JANGAN lanjut sebelum keberatan ditanggapi.

### 7. Render HTML (visual-first)
Clone `${KIMI_SKILL_DIR}/../../skills/discovery/template.html` APA ADANYA (CSS & struktur). Template ini **visual-first** — tiap section ditandai komentar (`<!-- HERO -->`, `<!-- CONCEPT -->`, `<!-- MASALAH -->`, `<!-- PENGGUNA -->`, `<!-- VALUE -->`, `<!-- PASAR -->`, `<!-- KOMPETITOR -->`, `<!-- MONETISASI -->`, `<!-- RISIKO -->`, `<!-- VERDICT -->`, `<!-- SUMBER -->`) dan punya elemen visual (meter, ring, funnel, line chart, matriks, gauge). Ganti **isi tiap section** dengan data produk nyata, **dan hitung ulang geometri tiap chart** sesuai `${KIMI_SKILL_DIR}/../../skills/discovery/chart-cheatsheet.md`. Pertahankan: label keyakinan (`<span class="conf v|a|s">`), sitasi (superscript `<sup class="ref">` ke seksi Sumber), dan daftar Sumber. Ganti `StokKu` di `<title>` + brand sidebar dengan nama produk. **Hapus** banner `.demo` (`⚑ Contoh isi …`) karena isi sudah nyata. Tulis ke `./discovery-draft.html` di root folder produk (control/ belum ada). Self-contained (CSS inline dari template; sumber boleh `<a href>` eksternal, tapi TIDAK ada `<link>`/`<script src>`/gambar eksternal).

### 8. Review loop (GATE)
Suruh operator buka `./discovery-draft.html` & baca. Tampung feedback. Bila ada → balik ke langkah 2–5 (gali visi ulang / riset ulang / tajamkan) → regen HTML. ULANG sampai operator bilang **SEPAKAT**. JANGAN lanjut tanpa kata sepakat eksplisit.

### 9. Sepakat → init + seed (GATE)
1. Jalankan alur skill `init`. Kamu SUDAH punya framing (nama produk + 1 kalimat + apps yang kebayang) dari langkah 1–5, jadi `init` skip Framing Q&A-nya (lihat klausa di `init` langkah 3). `init` deteksi topologi (gate-nya sendiri) → scaffold `control/` + `workspace.yaml` + `CLAUDE.md`.
2. SEED `business/` (KONSERVATIF, hanya `terverifikasi` & durable — `reference.md` bagian D): `domain.md` (Produk/Pengguna/Nilai + `## Aturan Domain` awal bila jelas), `glossary.md` (istilah), `flows.md` (flow kunci bila ada), **`risks.md`** (HANYA bila asesmen compliance step 4 dijalankan — kewajiban dari seksi Risiko, `terverifikasi`/`asumsi`+sumber, carve-out M6, lihat `${KIMI_SKILL_DIR}/../../rules/compliance-risk.md`; slot tak relevan → `N/A — alasan`; asesmen di-skip → JANGAN seed, biarkan `risks.md` skeleton — jalur degrade normal pembaca M6). Yang `asumsi`/`spekulatif` & analisis pasar JANGAN dimasukkan (kecuali kewajiban compliance → `risks.md`).
3. Pindahkan HTML final: `./discovery-draft.html` → `control/docs/discovery.html`.
4. Ringkas hasil + **tawarkan chain `/roadmap`** (susun backlog fitur — konteks lagi hangat; boleh skip), lalu sarankan `architect` (fondasi teknis).

## Catatan
- NOL teknis (stack/arsitektur = jatah `architect`). Berhenti di konsep produk; backlog fitur = jatah `roadmap`; detail fitur = jatah `feature`/`intake`.
- Verdict bukan perintah — selalu "ini alasan + sumber, operator yang putuskan". Riset MENURUNKAN halusinasi, tidak MENGHAPUS.
- Brownfield berkode → pakai `extract`, bukan ini.
