# discovery — Reference (framework konsultan + aturan sitasi/label)

Dibaca oleh skill `discovery`. SKILL.md tetap ramping; detail "apa yang digali & gimana nandainnya" ada di sini.

## A. Framework pertanyaan & riset per seksi

Prinsip: AI **MENYETIR**. Untuk tiap seksi, RISET dulu lalu USULKAN draft ke operator + jelaskan kenapanya — JANGAN tanya kosong ke operator yang bukan orang bisnis.

- **Masalah** — Masalah apa, sakitnya di mana, buat siapa? Riset: apakah masalah ini nyata & dibicarakan (forum, review, artikel)?
- **Pengguna/Segmen** — Siapa paling kena masalahnya? Usulkan 2–3 segmen + mana yang paling tajam.
- **Value proposition** — Kenapa solusi ini, kenapa beda dari yang sudah ada?
- **Pasar** — Seberapa besar / ke mana arahnya? Riset angka real (laporan, data publik). Tandai TIAP angka.
- **Kompetitor** — Siapa yang sudah menyelesaikan ini (langsung & tidak langsung)? Riset nama nyata + posisi/harga. Minimal 3 bila ada.
- **Monetisasi** — Model pendapatan kandidat (langganan, sekali bayar, freemium, komisi, dll) + mana yang cocok dengan segmen.
- **Risiko** — Apa yang bisa bikin gagal (pasar jenuh, switching cost tinggi, regulasi, beratnya eksekusi)?
- **Verdict** — `go` / `caution` / `no-go` + alasan ringkas, berbasis temuan di atas. Wajib jujur — boleh `no-go`.

## B. Aturan sitasi (WAJIB)

- Tiap klaim faktual (angka pasar, fakta kompetitor, tren) WAJIB menempel sumber: URL + tanggal akses.
- Tampung sumber di seksi "Sumber" (`<ol class="sources">`, bernomor). Klaim merujuk dengan superscript: `<sup class="ref"><a href="#s1">[1]</a></sup>`.
- TIDAK ADA sumber → klaim itu otomatis `asumsi` atau `spekulatif`, JANGAN `terverifikasi`.
- JANGAN mengarang URL atau angka. Bila tak ketemu data → tulis "tidak ditemukan data" dan label `spekulatif`.

## C. Label keyakinan (3 tingkat)

Tiap klaim non-sepele diberi label (pakai class CSS template):
- `terverifikasi` (`<span class="conf verified">`) — ada sumber kuat & relevan (idealnya >1).
- `asumsi` (`<span class="conf assumed">`) — nalar wajar tapi belum tervalidasi sumber.
- `spekulatif` (`<span class="conf spec">`) — tebakan/ekstrapolasi; perlu konfirmasi.

## D. Yang nyebrang ke business/ (saat seed, langkah 7)

KONSERVATIF — hanya yang `terverifikasi` & durable:
- `domain.md`: Produk (1 kalimat), Pengguna, Nilai inti, + `## Aturan Domain` awal (hanya kalau sudah jelas).
- `glossary.md`: istilah domain.
- `flows.md`: flow kunci (kalau sudah kebayang).

Yang `asumsi`/`spekulatif` & SEMUA analisis pasar (pasar, kompetitor, monetisasi, risiko, verdict) TINGGAL di HTML — JANGAN masuk `business/`.
