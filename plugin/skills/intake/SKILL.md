---
name: intake
description: Use untuk fase bisnis sebuah fitur (P2 fase 1) — Q&A level bisnis, validasi ke aturan domain, hasilkan business.md. Trigger — "intake <fitur>", dipanggil oleh skill feature. Jalankan dari root produk yang punya control/.
---

# intake — Business Intake (P2 fase 1)

Tujuan: ubah ide fitur jadi spec bisnis yang jelas & selaras domain, SEBELUM menyentuh teknis.

## Langkah

### 1. Pastikan folder fitur ada
Bila `control/features/<fitur>/feature.yaml` belum ada (intake dipanggil langsung, bukan via `feature`), buat:
```yaml
name: <fitur>
status: draft
created: <YYYY-MM-DD>
sensitivity: []        # [] | [payments] | [pii] | [payments, pii] — diusulkan di step 7, dikonfirmasi user
epic: ""               # (M1) nama epik pengelompok; "" = standalone — metadata, bukan kontrol eksekusi
depends_on: []         # (M1) [<nama-fitur>] yang idealnya shipped dulu; warn-gate feature (BUKAN block)
risk: normal           # (M7) low | normal | high — blast-radius build; menyetir cadence build --unattended; payments-movement → floor high (hard), pii saja tidak
```

### 2. Baca knowledge
Baca `control/business/*.md` (domain, flows, glossary, **`risks.md`** — kewajiban compliance, constraint per-fitur) + `control/workspace.yaml` (apps + capabilities).
**Feedback (M8):** bila ada, baca `control/feedback/` (sinyal lapangan mentah dari produk live — keluhan/incident/request) sebagai **input SOFT** (advisory, **bukan** gate; tak memblokir). Sinyal yang ternyata bug → arahkan ke `/fix`, bukan diselesaikan di sini. Degrade: kosong/absen → lanjut seperti biasa. (Surfacing ke user di-paksa di step 5 — lihat Challenge Checklist.)

### 3. Q&A level BISNIS (bukan teknis)
Tanya satu per satu: siapa penggunanya, aturan/kebijakan, hasil yang diharapkan, batasan. JANGAN tanya hal teknis (framework, DB, dll) — itu jatah skill `plan`.

### 4. Cek feasibility kasar
Bandingkan kebutuhan fitur dengan `capabilities` app di `workspace.yaml`. Catat mana yang sudah didukung vs baru. **Sizing-check (advisory, M1):** bila kebutuhan fitur terlihat sebesar epik (banyak app/flow/milestone independen, scope melar), **usulkan** pecah jadi beberapa fitur lebih kecil — isi `epic` (pengelompok) + `depends_on` (urutan) di tiap `feature.yaml`. Usulan saja; user putuskan. Tak memblokir.

### 5. Challenge Checklist (WAJIB tampilkan sebelum gate)
- Bentrok aturan bisnis yang mana? (cek `control/business/`)
- Tradeoff-nya apa?
- Ada cara lebih sederhana?
- Apa yang bisa jebol / risiko?
- Menyentuh kewajiban compliance di `risks.md`? (PCI/GDPR/pajak/KYC) — kutip + pastikan tertangani (advisory).
- Ada sinyal lapangan relevan di `feedback/`? — kutip + tanya apakah fitur ini menanganinya (advisory).

### 6. Critic (gate penting)
Untuk fitur fondasional/berisiko, invoke subagent `critic` atas draft `business.md` + knowledge. Tanggapi tiap keberatan bersama user sebelum lanjut.

### 7. Tulis output (GATE)
Tulis `control/features/<fitur>/business.md` dengan format:
```
# <Fitur> — Business Spec
Tujuan      : <...>
Pengguna    : <...>
Aturan      : <... + referensi business/ bila relevan>
Hasil/Reward: <...>
Out of scope: <...>
```
Lalu **promosikan fakta DURABLE** ke knowledge (konservatif — hanya yang benar lepas dari fitur): aturan domain → `business/domain.md`; flow → `business/flows.md`; istilah → `business/glossary.md`. **Idempotent:** sebelum nambah, cek apakah fakta serupa sudah ada di file tujuan — update yang ada, jangan duplikat (re-run intake nggak boleh numpuk aturan ganda).

**Usulkan tag `sensitivity`** dari isi `business.md` (heuristik): `payments` kalau fitur menggerakkan/menyimpan uang (bayar, billing, payout, refund, fee); `pii` kalau mengumpulkan/menyimpan/menampilkan data pribadi (nama, email, alamat, telp, gov-id). Cross-check ringan ke `control/invariants.md` — kalau slot PII/PCI di-`N/A`, jangan ngotot tag `pii`. Tulis usulan ke `feature.yaml` `sensitivity:` (kosong boleh). **Compliance (M6):** kalau fitur cocok dgn pemicu di `control/business/risks.md` → **perkuat** usulan tag + sebut kewajibannya sbg alasan (advisory; heuristik teks tetap jalan tanpa `risks.md`). Lihat `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`. **Usulkan `risk` (M7)** (`low|normal|high`) = **blast-radius BUILD** (seberapa bahaya kalau build keliru — BUKAN seberapa sensitif datanya; itu `sensitivity`, lihat M7 D1). `high` bila build-nya sendiri berbahaya: operasi **destruktif/irreversible**; **migrasi skema/data**; **batas auth/keamanan** (authn/authz, session/token, isolasi tenant, CORS/origin — daftar *Verba-keamanan* `tweak/reference.md` §A); **plumbing pergerakan uang** (charge/capture/refund/payout/settlement/transfer, simpan PAN/token-kartu — *Verba-uang PLUMBING* `tweak/reference.md` §A). **Floor (dipersempit — M7-amend 2026-06-18):** bila usulan `sensitivity` memuat `payments` **DAN** fitur benar-benar **menggerakkan uang** (verba-uang di atas, atau menyimpan instrumen-bayar — BUKAN sekadar menampilkan harga/invoice/saldo read-only) → `risk` minimal `high` (HARD). **`pii` saja TIDAK memaksa floor** — `pii` menyetir kedalaman Security Gate `ship`, bukan cadence build. Tulis ke `feature.yaml` `risk`. Advisory — default `normal` bila tak yakin; user konfirmasi di gate ini.

Tampilkan `business.md` + daftar promosi knowledge + usulan `sensitivity` → minta **approve/koreksi**. Boleh tulis draft dulu lalu konfirmasi.

## Catatan
- Output ini jadi input `fanout`. JANGAN melakukan pemetaan app di sini.
- `tweak` bisa eskalasi ke sini (invoke `/feature`→`intake`) bawa seed konteks saat perubahan kecil ternyata gede/fondasional.
