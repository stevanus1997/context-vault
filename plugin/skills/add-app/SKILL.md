---
name: add-app
description: Use untuk nambah SATU app baru ke produk yang sudah di-init — tulis entri app ke workspace.yaml lalu chain architect (stack) lalu wire (bring-up) jadi skeleton kosong-tapi-jalan, semua di-GATE. Satu-satunya penulis entri app baru pasca-init. Dipanggil feature saat fanout nandain app baru, atau standalone. Trigger — "add-app <nama>", "tambah app <x>", "bikin app baru", "scaffold app baru". Jalankan dari root produk yang punya control/.
---

# add-app — Nambah App Baru (declare lalu architect lalu wire)

Tujuan: numbuhin produk yang SUDAH di-`init` dengan SATU app baru. `add-app` = konduktor tipis: tulis identitas app ke `control/workspace.yaml`, lalu chain `architect` (stack) lalu `wire` (bring-up). Hasilnya app baru jadi skeleton kosong-tapi-jalan, siap di-`feature`. Jalankan dari root produk (punya `control/`).

`add-app` **satu-satunya penulis entri app baru pasca-`init`**. Ia TIDAK mutusin stack (jatah `architect`) & TIDAK scaffold/DB/wiring sendiri (jatah `wire`) — ia delegasi. Berat-beratnya tetap di skill yang dipanggil.

## Prinsip (jangan dilanggar)
- **Bukan `init`.** `add-app` TIDAK bootstrap produk / deteksi topologi / scaffold `control/`. `control/` harus sudah ada — kalau belum, arahin ke `init`.
- **Cuma identitas, bukan stack.** `add-app` nanya name/type/responsibility (deklarasi). Framework/db/orm = jatah `architect` di langkah 4. JANGAN tanya stack di sini.
- **App doang (v1).** fe/be/fullstack. Shared package (ui-kit/types) BUKAN urusan `add-app` — beda cabang (nggak ada DB/wiring/smoke).
- **Idempotent.** App yang sudah ada di `workspace.yaml` → STOP, jangan re-declare.
- **Tiap aksi side-effecting = GATE.** Tulis entri = gate sendiri; architect & wire pakai gate masing-masing.

## Langkah (urut)

### 0. Baca state
Baca `control/workspace.yaml` (`topology` + `apps[]` existing). **Prasyarat:** `control/workspace.yaml` ada. Kalau nggak ada → ini bukan `add-app`; arahin ke `init`.

### 1. Cek duplikat (idempotent)
Kalau app `<nama>` sudah ada di `apps[]` → **STOP**, jangan re-declare. Kalau user cuma mau ngelengkapin fondasi app existing → arahin ke `architect`/`wire`.

### 2. Q&A identitas app (singkat — level DEKLARASI, bukan stack)
Tanya:
- `name` (kalau belum dari arg/usulan `fanout`)
- `type`: fe / be / fullstack
- `responsibility`: satu kalimat

Derive `path` dari `topology`:
- **monorepo** → `apps/<nama>` (atau konvensi yang terbaca dari apps existing)
- **multi-repo** → `../<nama>` + minta `repo_url` (boleh kosong kalau repo belum dibuat)

JANGAN tanya framework/db/orm di sini — itu `architect` (langkah 4).

### 3. Tulis entri ke workspace.yaml (GATE)
Tambah entri app baru ke `apps[]` (ikuti bentuk entri `init`):
```yaml
  - name: <nama>
    path: <apps/<nama> | ../<nama>>
    repo_url: <isi untuk multi-repo, kosongkan untuk monorepo>
    type: <fe|be|fullstack>
    responsibility: "<ringkas>"
    capabilities: []        # tumbuh lewat fanout/feature
    stack: {}               # diisi architect (langkah 4)
```
**Add-only-if-absent.** Tampilkan diff `workspace.yaml` → minta **approve**.

### 4. Invoke skill `architect` untuk app ini
`architect` SETUP mode buat app baru: Q&A teknikal (framework/lang/db/orm) → tulis `stack`, cek divergensi konvensi vs app lain, update `conventions.md` bila perlu. Pakai gate-nya `architect`. (`add-app` nggak nentuin stack.)

### 5. Invoke skill `wire` untuk app ini
`wire` greenfield: scaffold (tool resmi) → nyalain DB → konek BE↔DB → wire FE↔BE → env standar → smoke test. Pakai gate-gate `wire`. Hasil: skeleton kosong-tapi-jalan.

### 6. Tutup & balikin
Lapor "**app `<nama>` siap di-`feature`**".
- Dipanggil `feature` (fitur butuh app baru) → balikin kontrol ke `feature` buat lanjut `plan`.
- Standalone → saranin langkah berikutnya (mis. `feature <fitur>`).

## Catatan
- **Cara kanonik nambah app pasca-`init`.** `architect`/`wire` boleh jalan standalone, tapi yang **nulis entri app baru** cuma `add-app`. `init` cuma declare app AWAL pas bootstrap.
- **Multi-repo:** `add-app` cuma nyatet `path` + `repo_url`. Pembuatan repo fisik (git init/remote) di-defer ke `wire` + user (gated) — repo app tidak dikelola hub.
- **Beberapa app baru dalam 1 fitur:** dipanggil sekali per app (oleh `feature`). Ikuti "Urutan" di `fanout.md` bila ada.
- TIDAK nyentuh `control/business/*` dan TIDAK bikin table/kode fitur (itu `build`).
