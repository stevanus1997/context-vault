---
name: render-docs
description: Use untuk men-generate dokumen human-readable (HTML) dari knowledge control/ — untuk PM/stakeholder non-teknis. Dipanggil otomatis oleh ship, atau manual untuk preview. Trigger — "render docs", "generate doc", "update dokumentasi produk". Jalankan dari root produk yang punya control/.
---

# render-docs — Knowledge → HTML (human-readable)

Tujuan: hasilkan SATU file HTML self-contained yang rapi & ramah orang non-teknis, di-generate dari knowledge (tidak ditulis manual → tidak pernah drift).

## Langkah

### 1. Baca knowledge
- `control/workspace.yaml` → `product`, `topology`, daftar `apps` (name, type, responsibility, capabilities, stack) + daftar `packages` (name, responsibility, consumers, mandatory_for).
- `control/integrations.md` → daftar vendor eksternal (vendor, Arah, Dipakai, Mode) — SHAPE-only, TANPA secret.
- `control/business/domain.md`, `flows.md`, `glossary.md`.
- `control/features/*/feature.yaml` (+ `business.md`) — kumpulkan fitur.
- `control/fixes/*/fix.yaml` — kumpulkan defect (id, status, severity, reported, relates_to, flow). SHAPE-only, TANPA isi sensitif.
- `control/debt.yaml` — kumpulkan utang teknis (id, area, owner, severity, observed). **Status diturunkan** (bukan field): silang `pays_debt: <id>` di `control/features/*/tasks.yaml` + `control/fixes/*/tasks.yaml` & status host → `open`/`scheduled`/`shipped`; `dropped` dari field `dropped`. SHAPE-only.
- `control/schema/*.md` → proyeksi skema per app (table, kolom, relasi, `Asal`/provenance) — read-only; di-generate `wire`/`build`, **JANGAN** regenerate di sini.

### 2. Baca template desain
Baca `${CLAUDE_PLUGIN_ROOT}/skills/render-docs/template.html`. Pakai `<head>`/CSS dan struktur B1-nya APA ADANYA (jangan redesign) supaya konsisten antar-generate.

### 3. Isi konten ke tiap slot
Ganti tiap penanda `<!-- SLOT:x -->` + section contohnya dengan konten nyata:
- **overview:** isi dari `domain.md` (produk, pengguna, nilai) → paragraf ramah.
- **apps:** satu `.card` per app: judul `name` + `type`, `responsibility`, lalu `capabilities` sebagai `.chip`.
- **schema (Model Data):** isi `<!-- SLOT:schema -->`. Satu `.card` per app yang PUNYA table (dari `control/schema/<app>.md`): judul app + daftar table (nama + kolom ringkas + relasi) + `Asal` (fitur/fix). **Read-only, TANPA filter ship-status** (skema ter-migrasi tampil walau fitur belum ship — by design M4). **Empty-handling:** app yang `control/schema/<app>.md`-nya stub/nol-table → **skip** (jangan render kartu kosong; ikut konvensi debt/integrations). Bila TAK ada app yang punya table (semua stub/nol-table — mis. tepat sesudah `wire` baseline, sebelum fitur pertama migrasi) → **lewati section schema seluruhnya** (tak ada section kosong) DAN jangan render nav link `#schema`.
- **packages:** isi `<!-- SLOT:packages -->`. Satu `.card` per shared package: judul `name` + label "package", `responsibility`, `consumers` (app yang memakai) sebagai `.chip`, tandai `mandatory_for` bila ada. Bedakan visual dari kartu app. **Empty-handling (cermin schema):** produk tanpa package → lewati section seluruhnya + jangan render nav link `#packages`.
- **integrations:** isi `<!-- SLOT:integrations -->`. Satu `.card` per vendor eksternal (dari `integrations.md`): judul `vendor` + label "integrasi", `Dipakai`, `Arah` + `Mode` sebagai `.chip`. SHAPE-only — JANGAN tampilkan nilai secret (cuma NAMA env var bila perlu). Bedakan visual dari kartu app/package. **Empty-handling (cermin schema):** tak ada vendor → lewati section seluruhnya + jangan render nav link `#integrations`.
- **fixes:** isi `<!-- SLOT:fixes -->`. Satu `.card` per fix dari `control/fixes/`: judul `id` + `.sev` (`severity`) + `.status` (`status`), `reported`, lalu `.meta` link `relates_to` (fitur) + `flow`. Urut: **Known Issues** (`open`/`diagnosed`) dulu, severity `urgent` di atas; lalu **Riwayat** (`shipped`). `dropped` JANGAN ditampilkan.
- **utang teknis (di slot yang sama, label "Known Issues / Utang Teknis"):** satu `.card` per utang dari `control/debt.yaml` (reuse class yang sama): judul `id` + `.sev` (`severity`) + `.status` (status **diturunkan**, §1), `observed`, lalu `.meta` `area` + `owner`. Urut: `open`/`scheduled` dulu (severity `high`/`owner: foundation` di atas) = bagian Known Issues; `shipped` masuk **Riwayat**. `dropped` JANGAN ditampilkan. Bila `debt.yaml` tak ada / `debt: []` → lewati (tak ada section kosong).
- **capabilities:** tabel kapabilitas × app (centang app mana punya kapabilitas apa).
- **flows:** render `flows.md` (heading per flow + langkah) jadi HTML.
- **glossary:** render `glossary.md` (istilah + definisi).
- Ganti `__PRODUCT__` (judul + sidebar) dengan nama produk.
- Render markdown sederhana (heading, list, bold, inline code) jadi HTML yang sesuai.

### 4. FILTER status fitur
Fitur ber-status `dropped` JANGAN ditampilkan di bagian utama. (Opsional: bagian kecil "Diarsipkan" di akhir, tapi default sembunyikan.) Fitur `active`/`shipped` boleh tampil (mis. badge `.status`). **Bila badge `shipped` ditampilkan, sertakan keterangan makna** (legend statis dekat badge): `shipped` = sudah di-PR / siap-kirim, **bukan** indikator merged / ter-deploy / live (cermin induk §3/§16 Future "in-review"). `render-docs` tak punya sinyal CI/deploy — jangan klaim status produksi. Untuk fix: `dropped` JANGAN ditampilkan; `open`/`diagnosed` = "Known Issues"; `shipped` = "Riwayat". `render-docs` dipicu `ship` (fix shipped) **dan** oleh `fix` saat status fix berubah jadi `open`/`diagnosed` (biar Known Issues muncul tanpa nunggu ship lain). Untuk utang teknis: `dropped` JANGAN ditampilkan; `open`/`scheduled` = "Known Issues / Utang Teknis" (jaring — utang `open` selalu kelihatan walau areanya tak disentuh `plan`/`fix` lagi); `shipped` = "Riwayat".

### 5. Tulis output
Tulis hasil ke `control/docs/site/index.html` (buat folder bila belum ada). Pastikan self-contained (CSS inline dari template, tanpa file eksternal).

### 6. Ringkas
Sebutkan path output + cara buka (double-click / `open control/docs/site/index.html`).

## Catatan
- Sumber kebenaran = knowledge `control/`. JANGAN pernah suruh user edit HTML langsung — edit knowledge lalu regenerate.
- Dipanggil `ship` setelah fitur shipped, atau manual kapan saja untuk preview.
