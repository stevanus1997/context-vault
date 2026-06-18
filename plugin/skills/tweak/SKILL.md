---
name: tweak
description: Use untuk perubahan KECIL berjejak — keputusan/kebijakan kecil (kode + alasan) yang tetep ke-capture ke control/ TANPA pipeline berat feature→build. BUKAN koreksi perilaku salah (→ /fix) & BUKAN kapabilitas baru/lintas-app/fondasional (→ /feature); tripwire auto naik-kelas kalau ternyata gede/bahaya/bug. Alur — triage+tripwire 3-cabang → TDD otomatis → capture ke business/* → gate (floor-scan + Challenge Checklist) → commit+PR. Trigger — "tweak <x>", "naikin/ganti/ubah <x> jadi", "ganti konstanta/threshold/policy <x>". Jalankan dari root produk yang punya control/.
---

# tweak — Jalur ringan berjejak (konduktor)

Tujuan: perubahan KECIL yang tetep ninggalin jejak keputusan di `control/`, TANPA `feature→fanout→plan→breakdown→build`. Cepet karena buang **birokrasi**, BUKAN nurunin bar (TDD + anti-yes-man + floor keamanan tetep jalan). Aman jadi **pintu default**: tripwire auto naik-kelas ke `/feature` (gede/bahaya) atau `/fix` (bug).

> Mekanik detail (daftar verba tripwire, garis angka-vs-plumbing, format capture, mekanik PR, skenario eval) → `${CLAUDE_PLUGIN_ROOT}/skills/tweak/reference.md` — baca itu dulu.

## Langkah

### 1. Baca state minimal + cek branch
<!-- diisi Task 2 -->

### 2. Triage + Tripwire (3 cabang, precedence B→C→A)
<!-- diisi Task 2 -->

### 3. Bikin perubahan — TDD otomatis, inline
<!-- diisi Task 4 -->

### 4. Capture keputusan (kalau ada)
<!-- diisi Task 4 -->

### 5. Gate (floor-scan + anti-yes-man)
<!-- diisi Task 5 -->

### 6. Finish — commit + PR
<!-- diisi Task 5 -->

## Catatan
<!-- diisi Task 5/6 -->
