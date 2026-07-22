# discovery — Reference (framework konsultan + aturan sitasi/label)

Dibaca oleh skill `discovery`. SKILL.md tetap ramping; detail "apa yang digali & gimana nandainnya" ada di sini.

## A. Framework pertanyaan & riset per seksi

Prinsip dibelah per-ranah. **Visi produk — operator menyetir**: AI menggali & merekam (SKILL.md step 2, TANPA riset); slot yang operator jawab "gak tau" → `AI-usul`. **Riset pasar — AI menyetir**: RISET dulu lalu USULKAN draft + jelaskan kenapanya — JANGAN tanya kosong soal angka pasar ke operator yang bukan orang bisnis, dan JANGAN menimpa visi operator dengan hasil riset diam-diam (konflik → tunjukkan bukti, operator putuskan).

- **Visi (dari operator — SKILL.md step 2, TANPA riset)** — Masalah versi operator, pengguna menurut dia, hasil/nilai yang diincar, batasan/keharusan yang sudah ia tetapkan, gambaran sukses. Sumber = jawaban operator, bukan web.
- **Masalah** — Masalah apa, sakitnya di mana, buat siapa? Riset: apakah masalah ini nyata & dibicarakan (forum, review, artikel)?
- **Pengguna/Segmen** — Siapa paling kena masalahnya? Usulkan 2–3 segmen + mana yang paling tajam.
- **Value proposition** — Kenapa solusi ini, kenapa beda dari yang sudah ada?
- **Pasar** — Seberapa besar / ke mana arahnya? Riset angka real (laporan, data publik). Tandai TIAP angka.
- **Kompetitor** — Siapa yang sudah menyelesaikan ini (langsung & tidak langsung)? Riset nama nyata + posisi/harga. Minimal 3 bila ada.
- **Monetisasi** — Model pendapatan kandidat (langganan, sekali bayar, freemium, komisi, dll) + mana yang cocok dengan segmen.
- **Risiko** — Apa yang bisa bikin gagal (pasar jenuh, switching cost tinggi, regulasi, beratnya eksekusi)? **Compliance (durable, carve-out ke `risks.md` — CONDITIONAL opt-in, SKILL.md step 4; heuristik pemicu uang/PII-berat/sektor-regulated + SATU pertanyaan; di-skip → `risks.md` tetap skeleton, degrade M6):** nilai terstruktur kewajiban regulasi — **PCI** (kartu/bayar) · **GDPR/privasi** (data pribadi) · **pajak** (jurisdiksi/PPN) · **KYC/AML** (identitas) + regulasi sektor/jurisdiksi spesifik. Lihat `${KIMI_SKILL_DIR}/../../rules/compliance-risk.md`.
- **Verdict** — `go` / `caution` / `no-go` + alasan ringkas, berbasis temuan di atas. Wajib jujur — boleh `no-go`.

## B. Aturan sitasi (WAJIB)

- Tiap klaim faktual (angka pasar, fakta kompetitor, tren) WAJIB menempel sumber: URL + tanggal akses.
- Tampung sumber di seksi "Sumber" (`<ol class="sources">`, bernomor). Klaim merujuk dengan superscript: `<sup class="ref"><a href="#s1">[1]</a></sup>`.
- TIDAK ADA sumber → klaim itu otomatis `asumsi` atau `spekulatif`, JANGAN `terverifikasi`.
- JANGAN mengarang URL atau angka. Bila tak ketemu data → tulis "tidak ditemukan data" dan label `spekulatif`.

## C. Label keyakinan (3 tingkat)

Tiap klaim non-sepele diberi label (pakai class CSS template):
- `terverifikasi` (`<span class="conf v">verif</span>`) — ada sumber kuat & relevan (idealnya >1).
- `asumsi` (`<span class="conf a">asumsi</span>`) — nalar wajar tapi belum tervalidasi sumber.
- `spekulatif` (`<span class="conf s">spek</span>`) — tebakan/ekstrapolasi; perlu konfirmasi.

**Aturan render:** output WAJIB visual-first — tiap section punya minimal 1 elemen visual (meter, ring, funnel, line chart, matriks, atau gauge). Teks = pendukung, bukan paragraf panjang. Geometri chart: lihat `${KIMI_SKILL_DIR}/../../skills/discovery/chart-cheatsheet.md`.

## D. Yang nyebrang ke business/ (saat seed, langkah 9)

KONSERVATIF — hanya yang `terverifikasi` & durable:
- `domain.md`: Produk (1 kalimat), Pengguna, Nilai inti, + `## Aturan Domain` awal (hanya kalau sudah jelas).
- `glossary.md`: istilah domain.
- `flows.md`: flow kunci (kalau sudah kebayang).

Yang `asumsi`/`spekulatif` & SEMUA analisis pasar (pasar, kompetitor, monetisasi, risiko, verdict) TINGGAL di HTML — JANGAN masuk `business/`.

**Pengecualian compliance (carve-out M6 — hanya bila asesmen compliance step 4 dijalankan; di-skip → tak ada yang nyebrang, `risks.md` skeleton):** kewajiban regulasi (PCI/GDPR/pajak/KYC + spesifik-produk) ber-label `terverifikasi`/`asumsi` + sumber **nyebrang ke `control/business/risks.md`** — ini **melonggarkan** aturan "hanya `terverifikasi`" di atas KHUSUS sub-kelas compliance (alasan: advisory, under-detect lebih bahaya). Analisis pasar/kompetitor/monetisasi/verdict + risiko `spekulatif` TETAP di HTML. Pembagi overlap & detail: `${KIMI_SKILL_DIR}/../../rules/compliance-risk.md`.
