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

## D. Capture — ownership, format, idempotensi
- **Tulis langsung HANYA ke `business/domain.md · flows.md · glossary.md`** (ketiganya multi-writer: `intake` step 7 + `extract` + `tweak` = penulis sah). `conventions.md`/`integrations.md`/`invariants.md` = single-owner-gated → **route ke pemilik / eskalasi**, NGGAK ditulis (pola `ask`).
- **Format alasan inline:** marker `<!-- tweak: <YYYY-MM-DD> — <kenapa> -->` di sebelah fakta. (Aturan BARU tweak; `intake` cuma idempotent tanpa alasan-inline.)
- **Idempotensi:** sebelum nambah, banding **FAKTA saja** (abaikan blok marker) → kalau fakta serupa ada, update; jangan duplikat. Aman di-re-run & nggak duplikat entri `intake`/`extract`.
- **Rule-change vs konstanta:** ngubah **ANGKA pada aturan yang SUDAH ADA** di `domain.md` = konstanta → Challenge Checklist. **Bikin aturan BARU / restruktur** = rule-change → **critic independen** (`context-vault:critic`) nilai usulan SEBELUM ditulis (anti-circular).
- **No-home fallback:** kandidat by jenis fakta (aturan→`domain`, langkah→`flows`, istilah→`glossary`); nggak jelas → default `domain.md` TAPI tampil di gate step 5 ("capture ke domain.md — pindahin?"). Jangan diam-diam drop.

## E. Floor-scan + mekanik PR
**Floor-scan (step 5, WAJIB, mekanis):** grep diff final — (a) secret hardcoded (API key/token/password/connstring di luar env) + PII di log/response (persis quick-scan `ship` sensitivity-kosong); (b) pola security-loosening: `auth`/flag → `false`, penghapusan middleware auth/validasi, TTL membesar, penghapusan signature-check. Kena → STOP, lapor.
**Mekanik PR (step 6, reuse `ship`):**
- Branch `tweak/<slug>` (kalau di `main`/`master` → minta izin / checkout dulu).
- Base-branch: symbolic-ref; **tanya kalau ambigu**.
- **Multi-repo:** karena override-sadar TIDAK berlaku buat ">1 unit", tweak paling banyak 1 unit app → commit kode di repo app + commit capture di repo hub `control/` → **PR di repo app**.
- **NGGAK** pakai `finishing-a-development-branch` (jatah `ship`).
