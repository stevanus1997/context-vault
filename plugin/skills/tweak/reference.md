# tweak — Reference (mekanik tripwire + capture + finish)

## A. Cabang B — daftar verba mekanis (kena salah satu = HARD-STOP, eskalasi /feature)
**Verba-keamanan:** authentication/authorization · session/token/TTL · CORS/origin · role/permission check · **rate-limit/throttle/quota** (semua yang fungsinya abuse/DoS-prevention) · validasi input · **serialization/deserialization & query-building** (surface injection) · **tenant/tenancy isolation filter** · **mode test/live vendor** · secret/credential.
**Verba-uang (PLUMBING):** charge/capture · refund · payout/settlement/transfer · simpan PAN/instrumen-bayar/token-kartu. (Heuristik sensitivity `intake` + `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md` = PENGUAT, bukan classifier utama — daftar verba ini yang operasional.)
**PII:** kumpulin/simpan/tampilin data pribadi, ATAU **MEMPERLUAS surface PII yang udah ada** (un-masking, nurunin redaction, nambah audience, propagate ke log/analytics/response/pihak-ketiga).
**Invariants:** keputusan yang **rumahnya `invariants.md`** (tenancy/money/idempotency/authz/pii-pci/rate-limit/integrasi) → eskalasi (tweak nggak boleh nulis `invariants.md`). **Degrade pesimis:** slot relevan masih `<belum dikunci>` → fondasi-belum-dikunci → eskalasi.
**Fail-safe:** ragu apakah suatu perubahan/limit punya fungsi keamanan → treat sebagai keamanan.

## B. Cabang A (fondasional) + garis angka-kebijakan vs plumbing

**Cabang A — fondasional (ukuran):** sejalan `build` step 6 (`>1 app`), **digeneralisasi ke unit nyata** (app ATAU package, konsisten grouping `ship`). Kena bila: sentuh **stack** / `conventions.md` / **shared package** / `integrations.md`, ATAU **lintas >1 unit nyata**, ATAU **ubah kontrak shared**, ATAU **kapabilitas baru / revamp gede**. (Bukan "verbatim" build — digeneralisasi.) Override-sadar cuma sub-trigger "revamp/kapabilitas".

**Garis ANGKA-KEBIJAKAN vs PLUMBING (decidable):**
- **LOLOS cabang-B** = ngubah **angka kebijakan bisnis** dari daftar-putih: **diskon maks · threshold gratis-ongkir · page-size** + angka sejenis yang **murni kebijakan, bukan fungsi keamanan**. → di-capture ke `domain.md`; risiko bisnis dijaga **Challenge Checklist** (step 5).
- **`rate-limit`/`throttle`/`quota` BUKAN angka-kebijakan** — itu §A (keamanan).
- **Precedence file-sensitivity:** "diff nyentuh file/modul ber-sensitivity" memicu STOP **HANYA bila diff nyentuh PLUMBING** (verba-uang/kolom-data §A), **BUKAN** bila cuma ngubah angka kebijakan. → diskon-cap di file pricing payments-sensitive **tetep lolos**.

## C. Cabang C — triage defect → /fix
Triage **by framing user**:
- "salah / harusnya / bug / nggak jalan" → **`/fix`** (route bawa konteks; fix punya disiplin reproduce→root-cause).
- "naikin / ganti / ubah jadi / set" → **`tweak`** (ngubah keputusan; perilaku lama nggak salah).
- **Ambigu → tanya SATU pertanyaan:** "ini perilaku lama yang *salah* (bug), atau keputusan baru?" Jangan tebak diam-diam.
