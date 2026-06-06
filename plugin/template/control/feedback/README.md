# Feedback — Sinyal Lapangan (input SOFT untuk intake)

Drop di sini sinyal MENTAH dari produk yang sudah live: keluhan user, incident ops, request fitur, insight analytics/support. Satu sinyal = satu file `.md` (mis. `2026-06-10-checkout-sering-timeout.md`).

**Penulis = MANUSIA (operator/user).** Drop manual — tak ada skill yang mengisi folder ini, tak ada auto-ingest. **Pembaca = `intake`** (saat merencanakan fitur, ia memunculkan sinyal relevan — sebagai INPUT SOFT, BUKAN gate; tak memblokir apa pun).

**Format ringan yang disarankan** (bebas, tak wajib):
- Judul singkat + tanggal.
- Sinyal: apa yang diamati di lapangan (kutip keluhan/incident apa adanya).
- Dugaan area dampak: app/fitur/flow yang relevan (bila tahu).

**Garis batas — apa yang BUKAN feedback:**
- **Bug terkonfirmasi** (bisa di-reproduce) → bukan di sini; jalankan `/fix` (lane `control/fixes/`).
- **Kewajiban compliance/regulasi** (PCI/GDPR/pajak/KYC) → bukan di sini; rumahnya `control/business/risks.md`.
- Feedback = sinyal HULU MENTAH yang belum tentu bug; ia menginformasikan fitur berikutnya, bukan eksekusi.

Folder boleh kosong (cuma README ini) — `intake` degrade mulus bila tak ada sinyal.
