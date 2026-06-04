---
name: debt
description: Use untuk mengelola UTANG TEKNIS produk — registry control/debt.yaml. Steward tipis read/triase: list (+ status diturunkan), triage (masih relevan? sesuaikan severity / buang kalau cuma selera), promote (tarik manual jadi task kind:debt), drop (decline + alasan, simpan jadi memori). build yang APPEND stub pas nemu di luar scope (pintu ke-4); /debt yang triage/promote/drop. TIDAK nulis kode. Trigger — "debt list", "ada utang teknis apa", "lunasin utang <x>", "drop utang <x>". Jalankan dari root produk yang punya control/.
---

# debt — Steward Utang Teknis (registry control/debt.yaml)

Tujuan: kelola registry utang teknis — hal yang secara arsitektur menyusahkan tapi **sekarang masih benar** (bukan defect → `/fix`; bukan kapabilitas baru → `/feature`). `/debt` **tidak** menulis kode & **tidak** memanggil `build` — pelunasan terjadi di host feature/fix (lewat task `kind: debt`). Satu-satunya pemilik schema `control/debt.yaml`.

## Prasyarat
- Jalankan dari root produk yang punya `control/`.
- **Tanpa `control/`** → belum ada produk; arahkan `/init`, lalu STOP.
- **`control/debt.yaml` belum ada** (produk lama) → buat dari template `${CLAUDE_PLUGIN_ROOT}/template/control/debt.yaml` (root kosong `debt: []`), lalu lanjut.

## Status diturunkan (jangan tulis flag manual)
Status TIDAK disimpan; hitung **on-read** dengan menyilang `pays_debt: <id>` di seluruh `control/features/*/tasks.yaml` + `control/fixes/*/tasks.yaml` dan status host (`feature.yaml`/`fix.yaml`):
- **open** = tak ada task `pays_debt: <id>` aktif & `dropped` kosong.
- **scheduled** = ada task `pays_debt: <id>` `pending`/`in_progress` di host aktif.
- **shipped** = task `pays_debt: <id>` di feature/fix yang sudah `shipped`.
- **dropped** = field `dropped` terisi.

## Verb

### `list` (default tanpa argumen)
Baca `control/debt.yaml`, hitung status tiap entri (di atas), tampilkan tabel: `id` · `area` · `owner` · `severity` · **status** · `observed`. Urut: `high`/`foundation` dulu, lalu `open` sebelum `scheduled`/`shipped`. Sembunyikan `dropped` (kecuali diminta `list --all`).

### `triage [<id>]`
Review utang `open` (atau `<id>` tertentu): masih relevan? Sesuaikan `severity` (`normal`/`high`). Bila ternyata **selera/kosmetik** (gagal bar "drag nyata") → arahkan `drop`. Bila ternyata **fondasional** (sentuh stack/`conventions.md`/shared package/`integrations.md`, ATAU lintas >1 app, ATAU ubah kontrak shared) tapi ter-`owner: feature` → betulkan `owner: foundation` + naikkan `severity`, ingatkan ini butuh `/architect`/`/add-*` (bukan dilunasi `plan`/`fix`). Tampilkan perubahan → minta approve sebelum tulis. (Opsional `critic` untuk registry besar — lihat spec §11.)

### `promote <id>`
Tarik manual sebuah utang jadi kerjaan — pelengkap jalur locality (`plan`/`fix`). Tentukan host: fitur/fix `active`/`open` yang relevan (`area` cocok), ATAU lane fix post-ship bila berdiri sendiri. **Arahkan** pembuatan task `kind: debt, pays_debt: <id>` ke host itu (lewat `breakdown`/`fix`) — `/debt` sendiri tak menulis `tasks.yaml`. Setelah ada task aktif, status entri otomatis jadi `scheduled` (diturunkan).

### `drop <id>`
Decline: tulis `dropped: {at: <YYYY-MM-DD>, reason: "<alasan>"}` ke entri (satu-satunya tulisan status eksplisit). **Entri dikeep** sebagai memori keputusan (precedent skill `drop`); `render-docs` menyaringnya dari Known Issues aktif. Minta alasan sebelum tulis.

## Guardrails
- **Pemilik tunggal.** Hanya `/debt` yang menulis schema/`dropped`; `build` cuma APPEND entri `open` (pintu ke-4). Tak ada penulis lain.
- **Tidak nulis kode / tidak panggil `build`.** Pelunasan di host feature/fix via task `kind: debt`. `/debt` murni read + edit-metadata ringan.
- **Status-as-byproduct.** Jangan pernah tulis field `status:`; selalu turunkan. Mencegah "nyangkut selamanya" terulang.
- **Bukan defect, bukan fitur.** Bug → `/fix`. Kapabilitas baru → `/feature`. `/debt` cuma untuk "benar tapi jelek, nanti".

## Catatan
- Capture (lahir entri) = otomatis di `build` pintu ke-4 — bukan di sini. `/debt` mulai dari entri yang sudah ada.
- Pelengkap: `render-docs` memproyeksikan utang `open`/`scheduled` ke "Known Issues / Utang Teknis" (jaring selalu-nyala — nol debt hilang walau areanya tak disentuh lagi).
