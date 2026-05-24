---
name: render-docs
description: Use untuk men-generate dokumen human-readable (HTML) dari knowledge control/ — untuk PM/stakeholder non-teknis. Dipanggil otomatis oleh ship, atau manual untuk preview. Trigger — "render docs", "generate doc", "update dokumentasi produk". Jalankan dari root produk yang punya control/.
---

# render-docs — Knowledge → HTML (human-readable)

Tujuan: hasilkan SATU file HTML self-contained yang rapi & ramah orang non-teknis, di-generate dari knowledge (tidak ditulis manual → tidak pernah drift).

## Langkah

### 1. Baca knowledge
- `control/workspace.yaml` → `product`, `topology`, daftar `apps` (name, type, responsibility, capabilities, stack).
- `control/business/domain.md`, `flows.md`, `glossary.md`.
- `control/features/*/feature.yaml` (+ `business.md`) — kumpulkan fitur.

### 2. Baca template desain
Baca `${CLAUDE_PLUGIN_ROOT}/skills/render-docs/template.html`. Pakai `<head>`/CSS dan struktur B1-nya APA ADANYA (jangan redesign) supaya konsisten antar-generate.

### 3. Isi konten ke tiap slot
Ganti tiap penanda `<!-- SLOT:x -->` + section contohnya dengan konten nyata:
- **overview:** isi dari `domain.md` (produk, pengguna, nilai) → paragraf ramah.
- **apps:** satu `.card` per app: judul `name` + `type`, `responsibility`, lalu `capabilities` sebagai `.chip`.
- **capabilities:** tabel kapabilitas × app (centang app mana punya kapabilitas apa).
- **flows:** render `flows.md` (heading per flow + langkah) jadi HTML.
- **glossary:** render `glossary.md` (istilah + definisi).
- Ganti `__PRODUCT__` (judul + sidebar) dengan nama produk.
- Render markdown sederhana (heading, list, bold, inline code) jadi HTML yang sesuai.

### 4. FILTER status fitur
Fitur ber-status `dropped` JANGAN ditampilkan di bagian utama. (Opsional: bagian kecil "Diarsipkan" di akhir, tapi default sembunyikan.) Fitur `active`/`shipped` boleh tampil (mis. badge `.status`).

### 5. Tulis output
Tulis hasil ke `control/docs/site/index.html` (buat folder bila belum ada). Pastikan self-contained (CSS inline dari template, tanpa file eksternal).

### 6. Ringkas
Sebutkan path output + cara buka (double-click / `open control/docs/site/index.html`).

## Catatan
- Sumber kebenaran = knowledge `control/`. JANGAN pernah suruh user edit HTML langsung — edit knowledge lalu regenerate.
- Dipanggil `ship` setelah fitur shipped, atau manual kapan saja untuk preview.
