---
name: tweak
description: Use untuk perubahan KECIL berjejak — keputusan/kebijakan kecil (kode + alasan) yang tetep ke-capture ke control/ TANPA pipeline berat feature→build. BUKAN koreksi perilaku salah (→ /fix) & BUKAN kapabilitas baru/lintas-app/fondasional (→ /feature); tripwire auto naik-kelas kalau ternyata gede/bahaya/bug. Alur — triage+tripwire 3-cabang → TDD otomatis → capture ke business/* → gate (floor-scan + Challenge Checklist) → commit+PR. Trigger — "tweak <x>", "naikin/ganti/ubah <x> jadi", "ganti konstanta/threshold/policy <x>". Jalankan dari root produk yang punya control/.
---

# tweak — Jalur ringan berjejak (konduktor)

Tujuan: perubahan KECIL yang tetep ninggalin jejak keputusan di `control/`, TANPA `feature→fanout→plan→breakdown→build`. Cepet karena buang **birokrasi**, BUKAN nurunin bar (TDD + anti-yes-man + floor keamanan tetep jalan). Aman jadi **pintu default**: tripwire auto naik-kelas ke `/feature` (gede/bahaya) atau `/fix` (bug).

> Mekanik detail (daftar verba tripwire, garis angka-vs-plumbing, format capture, mekanik PR, skenario eval) → `${CLAUDE_PLUGIN_ROOT}/skills/tweak/reference.md` — baca itu dulu.

## Langkah

### 1. Baca state minimal + cek branch
Baca `control/workspace.yaml` (apps + stack + path) + cek branch sekarang (multi-repo aware; **jangan commit di `main`/`master` tanpa izin** — branch `tweak/<slug>`). `control/business/*`+`glossary` dibaca **lazy** (pas capture perlu, step 4). **`control/invariants.md` WAJIB dibaca** buat evaluasi tripwire cabang-B (step 2) — KECUALI perubahan jelas murni-kosmetik (copy/format/rename). Prasyarat: ada `control/`; kalau nggak → BERHENTI, suruh `init`.

### 2. Triage + Tripwire (3 cabang, precedence B→C→A)
SEBELUM nyentuh kode. **Cek mekanis pakai daftar verba di `reference.md` §A-C, bukan feeling.**

**Precedence (algoritmik):** evaluasi **B → C → A**.
- **B (keamanan) & C (defect) SELALU jalan & TIDAK bisa di-override** user.
- **Override-sadar HANYA cabang A** sub-trigger judgment "revamp gede/kapabilitas baru" — **BUKAN** ">1 unit/app", "ubah kontrak shared", "sentuh stack/conventions/integrations" (itu hard-escalate, bikin multi-repo / nyentuh single-owner).
- Lolos B+C+A → lanjut jalur ringan (step 3).

**Cabang B — keamanan → HARD-STOP** (nggak bisa di-talk-out). Kena verba-keamanan / verba-uang(plumbing) / PII-expansion / invariants (`reference.md` §A) → STOP; satu-satunya maju = **invoke `/feature`** (ujungnya `ship` Security Gate), seed konteks. Degrade pesimis: slot `invariants.md` relevan masih `<belum dikunci>` → eskalasi. Fail-safe: ragu fungsi-keamanan → treat keamanan.

**Cabang C — defect → `/fix`.** Triage by framing (`reference.md` §C): "salah/harusnya/bug" → route `/fix` bawa konteks; ambigu → tanya satu pertanyaan.

**Cabang A — ukuran/fondasional → `/feature`.** Definisi sejalan `build` step 6 (`>1 app`, digeneralisasi ke unit nyata) — `reference.md` §B. Kena → **invoke `/feature`** seed konteks (override sadar lihat precedence).

**Garis angka-kebijakan vs plumbing** (biar perubahan angka kebijakan kayak diskon-cap nggak ketabrak cabang-B): `reference.md` §B.

### 3. Bikin perubahan — TDD otomatis, inline
Skill yang **nulis test sendiri** dari perilaku yang diubah (merah → implement → ijo), ikut `conventions.md` + pola yang ada. Edit **inline** (TANPA orkestrasi subagent per-task — itu sumber berat `build`). **Pengecualian sempit:** murni nggak-berperilaku (copy/teks/format/rename) → nggak ada yang dites (≠ "boleh logika tanpa test"). **TDD = jaminan KOREKTIFITAS, BUKAN keamanan** (keamanan = cabang-B + floor-scan step 5).

### 4. Capture keputusan (kalau ada)
Kalau perubahan bawa fakta durable → APPEND ke file knowledge **pemilik** sesuai `reference.md` §D. Ringkas: tulis langsung **HANYA** ke `business/domain.md · flows.md · glossary.md` (idempotent, + alasan inline); `conventions.md`/`integrations.md`/`invariants.md` → **route/eskalasi, JANGAN tulis**. **Rule-change** (bikin/restruktur aturan) → **critic independen** nilai dulu; **konstanta** (ganti angka aturan existing) → cukup Challenge Checklist. Murni kosmetik → skip.

### 5. Gate (floor-scan + anti-yes-man)
**Floor-scan WAJIB dulu** (`reference.md` §E): scan diff buat (a) **secret hardcoded** + **PII di log/response**, (b) **pola security-loosening** (toggle auth→false, hapus middleware auth/validasi, TTL membesar, hapus signature-check). Kena → STOP. Lalu tampilin: diff kode + update knowledge + alasan + hasil test + **Challenge Checklist TERISI** (`Bentrok aturan: <isi> · Tradeoff: <isi> · Alternatif simpel: <isi> · Yang bisa jebol: <isi>`) → minta **approve/revisi**. (Challenge Checklist = output terisi, BUKAN interogasi 4-ronde.)

### 6. Finish — commit + PR
Commit (pesan muat rasionale) → buka PR (`reference.md` §E). Selesai **satu perintah**. Refresh `render-docs` opsional (default skip). **Kenapa boleh nge-PR padahal `fix` nggak:** `ship` pemilik siklus status manifest (`shipped`); `fix` punya `fix.yaml` jadi butuh ship nutup lifecycle; **`tweak` nggak punya manifest (atomik) → nggak ada lifecycle buat ditutup → finish sendiri.** Bukan nyerobot ship.

## Catatan
- BUKAN urusannya: defect (→ `/fix`), kapabilitas/lintas-app/fondasional (→ `/feature`), nentuin stack (→ `architect`), nandai `shipped` (→ `ship`).
- **NON-resumable, single-session.** Interupsi → re-run dari awal, sandar git (ter-commit kelihatan, capture idempotent, un-committed dibuang).
- Visibility: tweak ber-capture kelihatan via `business/*.md` (dibaca `ask` live); `render-docs` HTML perlu regen (default-skip = bisa stale). Tweak kosmetik = git history aja.
- TDD = korektifitas; keamanan = cabang-B + floor-scan (TDD-ijo BUKAN jaminan aman).
