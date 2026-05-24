---
name: plan
description: Use untuk fase teknis per-app sebuah fitur (P2 fase 2) — baca kode tiap app yang kena, Q&A teknis, hasilkan plan implementasi. Trigger — "plan <fitur>", dipanggil oleh skill feature.
---

# plan — Technical Plan per-app (P2 fase 2)

Tujuan: untuk tiap app yang kena fitur, susun plan implementasi konkret berbasis kode & konvensi yang ADA.

## Langkah

### 1. Baca input
Baca `control/features/<fitur>/business.md` + `fanout.md` + `control/conventions.md` + `control/workspace.yaml` (untuk `path` & `stack` tiap app).

### 2. Selesaikan kontrak lintas-app dulu
Bila `fanout.md` menyebut dependency lintas-app (mis. mekanisme token web↔api), putuskan kontraknya lebih dulu dan tulis `control/features/<fitur>/plans/_shared.md`:
```
# <Fitur> — Kontrak Lintas-App
<keputusan bersama, mis. mekanisme/format, siapa issuer & validator, env yang dibagi>
```

### 3. Per app (untuk tiap app di fanout.md)
- Buka kode app di `path`-nya (dari `workspace.yaml`). Baca pola yang ada; ikuti `conventions.md` & `stack`.
- Q&A **teknis** seperlunya.
- Susun plan: file yang disentuh, endpoint/komponen, model data, test.
- **Challenge teknis** sebelum gate: konsistensi dengan konvensi? risiko? cara lebih sederhana?

### 4. Tulis output (GATE per app)
Tulis `control/features/<fitur>/plans/<app>.md`:
```
# <app>
Model/Schema : <...>
API/Komponen : <...>
Lokasi       : <path konkret di app>
Test         : <...>
```
Tampilkan tiap plan → minta **approve per app**.

## Catatan
- JANGAN menetapkan stack/framework di sini — itu sudah ditetapkan `architect`. `plan` membaca yang ADA. Bila app belum punya fondasi, hentikan & arahkan user menjalankan `architect` dulu.
- Setelah semua plan di-approve, kontrol kembali ke `feature` (yang menandai status `active`).
