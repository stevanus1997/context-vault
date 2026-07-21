# Compliance Risk — risiko compliance durable (aturan share)

Dirujuk skill yang menulis/membaca kewajiban compliance di `control/business/risks.md`: **penulis** `discovery` (seed carve-out); **pembaca** `architect` (kunci invarian PII/PCI), `intake` (constraint per-fitur + perkuat `sensitivity`), `ship`/`security-critic` (baseline red-team). **BUKAN langkah berdiri sendiri** — dokumentasi + prosedur ringan yang dipanggil pemanggil itu. Semua **advisory**.

## Penulis tunggal = discovery (pembaca read-only)
Hanya `discovery` yang menulis `risks.md` (seed pra-init). **Tak ada pembaca yang menulis** `risks.md`. Bila pembaca menemukan gap compliance baru → **angkat ke user** (advisory), JANGAN tulis diam-diam. Efek "gap baru" beda per kelas pembaca (lihat Advisory di bawah).

## Batas carve-out (definisi tunggal)
- **DURABLE ke `risks.md`:** kewajiban **compliance/regulasi** lepas-dari-fitur — PCI (kartu/bayar) · GDPR/privasi (data pribadi) · pajak (jurisdiksi/PPN) · KYC/AML (identitas) + regulasi sektor/jurisdiksi spesifik. Label `terverifikasi`/`asumsi` + sumber/alasan.
- **TINGGAL di HTML** (`control/docs/discovery.html`): pasar, kompetitor, monetisasi, verdict, dan risiko ber-label `spekulatif`.
- **Melonggarkan §D discovery secara sadar & terbatas:** aturan §D existing izinkan HANYA `terverifikasi` nyebrang ke `business/` (`asumsi` JANGAN). Carve-out compliance izinkan `terverifikasi`+`asumsi` **khusus sub-kelas compliance** — karena (i) M6 advisory (false-positive = sekadar peringatan, murah) dan (ii) **under-detect compliance lebih bahaya** dari over-detect.
- **Aturan-batas overlap (compliance vs market-risk):** satu temuan regulasi bisa punya dua dimensi — *compliance-obligation* (apa yang HARUS dilakukan agar legal) DAN *market-risk* (apakah regulasi mengancam viabilitas). Pembagi: **kewajibannya nyebrang ke `risks.md`; analisis dampak-pasarnya tetap HTML.**

## Bentuk entri
Per slot kategori: **pemicu — kewajiban — [label keyakinan] — sumber.** Baris bebas untuk regulasi lain. Slot tak relevan → `N/A — alasan`. Sentinel `<belum dinilai>` = belum diisi.

## Advisory (cara tiap pembaca pakai)
Kewajiban dimunculkan sebagai **constraint/catatan**; rule **TAK** memblokir architect/intake/feature. Satu-satunya STOP = Security Gate `ship` existing (high-sev → RED) — mekanisme yang ADA, bukan gate baru.
- **Pembaca-elicitation (`architect`/`intake`):** cocokkan keputusan/fitur dgn kewajiban → perkaya elicitation; gap baru → angkat advisory, lanjut.
- **Pembaca-gate (`security-critic` di `ship`):** subagent read-only ber-output daftar temuan; kewajiban yang dilanggar & dinilai **high → jadi RED** lewat mekanisme `ship` existing (memang fungsinya), bukan "angkat lalu lanjut". Konsekuensi: himpunan temuan RED bisa **melebar** (diff yang langgar kewajiban yg kini diketahui) — dikehendaki, sejajar menambah invarian. **Terbatas** ke fitur ber-`sensitivity` `payments`/`pii` (security-critic cuma di-invoke di situ).

## Anti-fiksi
Kewajiban berasal dari **riset `discovery` yang bersumber** (aturan label/sitasi `discovery/reference.md` §B/§C), **bukan** dikarang pembaca. JANGAN nyandar artifact fiksi.

## Degrade-ke-best-effort
`risks.md` tak ada / semua slot `<belum dinilai>` / produk tanpa discovery → pembaca jalan "best-effort, tak ada kewajiban compliance diketahui" + tetap pakai mekanisme existing (heuristik sensitivity intake, Q&A architect, scan security-critic). **JANGAN error, JANGAN blokir.**

## Generik & batas
- **Generik:** kategori PCI/GDPR/pajak/KYC lintas-domain; tak hardcode jurisdiksi/stack; baris bebas tampung regulasi spesifik.
- **Batas (sadar):** `risks.md` hanya selengkap riset discovery; produk yang skip discovery / regulasi yang luput riset tak tertangkap → gate manusia (architect/ship) = jaring akhir.
