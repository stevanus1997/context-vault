---
name: drop
description: Use untuk membatalkan fitur yang lagi direncanakan/dibangun (status draft/active) — tandai dropped + alasan, review knowledge yang sempat dipromosikan, simpan folder sebagai memori keputusan. Trigger — "drop <fitur>", "batalin fitur <fitur>", "cancel <fitur>". Jalankan dari root produk yang punya control/.
---

# drop — Batalkan Fitur

> **Titik tunggu attended → `AskUserQuestion`:** tiap gate approve/revisi, Q&A keputusan, & konfirmasi yang nunggu jawaban user — tulis konten (draft/diff/ringkasan) sebagai teks DULU, lalu tanya lewat tool `AskUserQuestion` (pertanyaan pendek, opsi bawa konsekuensi); JANGAN akhiri turn dengan pertanyaan teks (tak memicu push Remote Control). Run unattended/headless tetap tak pernah bertanya (satu pengecualian: lihat §Batas). Detail: `${CLAUDE_PLUGIN_ROOT}/rules/ask-user.md`.

Tujuan: batalkan fitur dengan rapi — `dropped` jadi byproduct + memori keputusan tersimpan.

## Langkah

### 1. Baca fitur
Baca `control/features/<fitur>/feature.yaml` + artifact yang ada (`business.md`, `fanout.md`, `plans/*`).

### 2. Tanya alasan
Tanya kenapa di-drop (singkat). WAJIB — ini jadi memori keputusan.

### 3. Review promosi knowledge
Daftar kandidat diambil dari penanda: `python3 -B ${CLAUDE_PLUGIN_ROOT}/skills/sync/sync_status.py markers --root . --feature <fitur>` (plus pemindaian manual untuk entri lama tanpa penanda). Identifikasi knowledge durable yang sempat disumbang fitur ini: aturan di `control/business/`, `capabilities` di `control/workspace.yaml`. Invoke subagent `critic` untuk bantu pilah: mana yang **feature-specific** (kandidat revert) vs **benar lepas dari fitur** (keep). Tanyakan ke user keep/revert per item, lalu terapkan. Item keep → lepas penandanya (`unmark`); item revert → hapus barisnya.
- **Bila fitur ini bikin app/package baru yang ikut di-drop:** kalau sebuah **app** dihapus, bersihkan namanya dari semua `packages[].consumers` + `mandatory_for` (jangan tinggalkan consumer hantu yang bikin fan-IN salah-target).
- **Bila fitur ini memperkenalkan vendor eksternal** (cek `fanout.md` fitur): **pengingat lunak** ke user — "fitur ini memperkenalkan `<vendor>`; tinjau apakah entri `control/integrations.md` masih dipakai fitur lain sebelum dibersihkan." Tanpa mesin keras (v1 tak melacak vendor-consumers presisi); drop entri `integrations.md` = aksi manual user.

### 4. Tandai dropped (GATE)
Set `control/features/<fitur>/feature.yaml`:
```yaml
name: <fitur>
status: dropped
created: <tetap>
reason: "<alasan>"
dropped_at: <YYYY-MM-DD>
```
**JANGAN hapus folder** — simpan sebagai memori keputusan (`render-docs` akan memfilter status `dropped` dari doc stakeholder).

### 5. Ingatkan kode/branch
Bila implementasi sudah mulai (status `active`), ingatkan user untuk revert/hapus branch terkait. `drop` TIDAK menyentuh kode app (git urusan user).

## Catatan
- Folder fitur `dropped` tetap ada agar keputusan & alasannya tidak dibahas ulang di kemudian hari.
- **drop-package** (hapus shared package dari `packages[]`): hanya bila package **tak punya `consumers`** dan tak ada di `mandatory_for` app aktif — kalau masih dipakai → **STOP/warn** (jangan drop package yang masih dipakai). Promosi knowledge ditinjau sama seperti drop app.
