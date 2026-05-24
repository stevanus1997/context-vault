---
name: ship
description: Use saat development sebuah fitur SELESAI — finishing gate (code review + quality + cek keselarasan kode vs business.md), lalu bikin PR & tandai fitur shipped. Trigger — "ship <fitur>", "kelarin fitur <fitur>", "finishing <fitur>". Jalankan dari root produk yang punya control/.
---

# ship — Finishing & Kirim

Tujuan: pastikan fitur yang sudah diimplementasi BENAR & selaras bisnis, lalu kirim (PR) + tandai `shipped`. Status `shipped` jadi byproduct, bukan flag manual.

## Langkah

### 1. Baca fitur
Baca `control/features/<fitur>/feature.yaml` (harus `status: active`), `business.md`, `fanout.md`, `plans/*`. Tentukan app yang kena dari `fanout.md` + `path`/`stack` dari `control/workspace.yaml`.

### 2. Per app yang kena
- **Code review:** review diff app (mis. `git -C <path> diff <base-branch>...HEAD`). Cari bug & inkonsistensi konvensi (`control/conventions.md`).
- **Quality gate:** jalankan test/lint/typecheck/build app (perintah sesuai `stack`).
- **Business alignment:** bandingkan kode yang jadi vs `business.md` + `plans/<app>.md` — invoke subagent `critic` dengan fokus: scope creep? requirement kelewat? menyimpang dari maksud bisnis?

### 3. Challenge Checklist (WAJIB sebelum ship)
- Semua test hijau? alignment ke `business.md` OK?
- Ada scope creep / requirement kelewat?
- Ada risiko yang belum ke-cover?

### 4. Putuskan
- **Semua hijau →** lanjut Step 5.
- **Ada merah →** laporkan kegagalan/misalignment ke user, **STOP — jangan ship.** Jangan rubber-stamp.

### 5. Kirim & tandai (GATE)
- Susun deskripsi PR dari `business.md` + `fanout.md` + `plans` + ringkasan diff (terhubung ke ALASAN bisnis, bukan cuma "what").
- Bikin PR: **multi-repo → satu PR per app yang kena**; **monorepo → satu PR**. Pakai `gh pr create`; bila `gh`/remote tak ada, tampilkan deskripsi PR untuk dibuat user sendiri.
- Set `feature.yaml` → `status: shipped` + tambah `shipped_at: <YYYY-MM-DD>`.
- Regenerate doc: invoke skill `render-docs` bila tersedia; bila belum ada (Fase 5), ingatkan user untuk regenerate nanti.

## Catatan
- `ship` TIDAK mengeksekusi/menulis fitur — implementasi dilakukan sebelumnya (pola executing-plans/subagent). `ship` = finishing gate + kirim.
- Hanya jalan pada fitur `status: active`. Bila belum, hentikan & jelaskan.
