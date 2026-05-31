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
```

### 2. Baca knowledge
Baca `control/business/*.md` (domain, flows, glossary) + `control/workspace.yaml` (apps + capabilities).

### 3. Q&A level BISNIS (bukan teknis)
Tanya satu per satu: siapa penggunanya, aturan/kebijakan, hasil yang diharapkan, batasan. JANGAN tanya hal teknis (framework, DB, dll) — itu jatah skill `plan`.

### 4. Cek feasibility kasar
Bandingkan kebutuhan fitur dengan `capabilities` app di `workspace.yaml`. Catat mana yang sudah didukung vs baru.

### 5. Challenge Checklist (WAJIB tampilkan sebelum gate)
- Bentrok aturan bisnis yang mana? (cek `control/business/`)
- Tradeoff-nya apa?
- Ada cara lebih sederhana?
- Apa yang bisa jebol / risiko?

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

Tampilkan `business.md` + daftar promosi knowledge → minta **approve**. Boleh tulis draft dulu lalu konfirmasi.

## Catatan
- Output ini jadi input `fanout`. JANGAN melakukan pemetaan app di sini.
