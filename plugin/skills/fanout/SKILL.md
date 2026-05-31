---
name: fanout
description: Use untuk memetakan sebuah fitur ke app yang terkena lintas-repo (P1) — hasilkan fanout.md + update capabilities. Adaptif (murah kalau cuma 1 app). Trigger — "fanout <fitur>", dipanggil oleh skill feature.
---

# fanout — Cross-repo Fan-out (P1)

Tujuan: tentukan app mana saja yang terkena fitur & perannya, lalu tumbuhkan System Map.

## Langkah

### 1. Baca input
Baca `control/features/<fitur>/business.md` + `control/workspace.yaml` (apps, capabilities, responsibility).

### 2. Petakan ke app
Cocokkan kebutuhan fitur ke `capabilities`/`responsibility` tiap app → tentukan app yang kena + apa perannya.
- **Adaptif:** kalau hanya 1 app yang relevan → konfirmasi cepat ("cuma <app>. Yakin gak nyentuh app lain?"). Kalau banyak → breakdown penuh.
- Bila user memberi hint app (mis. "cuma web"), tetap **VERIFIKASI** terhadap capabilities — koreksi bila ternyata menyentuh app lain. "Cuma 1 app" adalah KESIMPULAN, bukan input. JANGAN skip pengecekan.

### 3. Challenge Checklist (WAJIB sebelum gate)
- Ada app yang kelewat?
- Ada dependency/kontrak lintas-app (mis. issuer↔validator)?
- Tradeoff & yang bisa jebol?
(Untuk fitur besar, boleh invoke `critic`.)

### 4. Tulis output (GATE)
Tulis `control/features/<fitur>/fanout.md`:
```
# <Fitur> — Fan-out
<app> (<peran/kapabilitas>) : <apa yang berubah>
...
Dependency lintas-app: <... bila ada>
Urutan: <... bila ada>
```
Lalu **update `capabilities`** app terkait di `control/workspace.yaml` (tambah kapabilitas baru yang diperkenalkan fitur ini). **Add-only-if-absent:** kalau kapabilitas sudah ada, jangan tambah lagi (re-run fanout nggak boleh bikin entri ganda).

Tampilkan `fanout.md` + perubahan capabilities → minta **approve/koreksi** (user paling tahu peta produk).

## Catatan
- Output ini jadi input `plan`. JANGAN masuk ke detail teknis di sini.
