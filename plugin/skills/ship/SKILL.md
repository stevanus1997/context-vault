---
name: ship
description: Use saat development sebuah fitur SELESAI — finishing gate (code review + quality + cek keselarasan kode vs business.md), lalu bikin PR & tandai fitur shipped. Trigger — "ship <fitur>", "kelarin fitur <fitur>", "finishing <fitur>". Jalankan dari root produk yang punya control/.
---

# ship — Finishing & Kirim

Tujuan: pastikan fitur yang sudah diimplementasi BENAR & selaras bisnis, lalu kirim (PR) + tandai `shipped`. Status `shipped` jadi byproduct, bukan flag manual.

## Langkah

### 1. Baca fitur & cek kesiapan
Baca `control/features/<fitur>/feature.yaml` (harus `status: active`), `business.md`, `fanout.md`, `plans/*`. Tentukan app yang kena dari `fanout.md` + `path`/`stack` dari `control/workspace.yaml`.
**Cek kelengkapan build:** bila `tasks.yaml` ada, verifikasi SEMUA task `done`. Ada task belum-`done` (`pending`/`in_progress`/`blocked`/`needs_human`/status belum-selesai lain) → **BERHENTI**, arahkan balik ke `build` (jangan ship fitur setengah jadi). Bila `tasks.yaml` tidak ada, konfirmasi implementasi dilakukan manual. **Guard diff kosong:** kalau tidak ada perubahan kode terhadap base, jangan bikin PR — laporkan.

### 2. Per app yang kena
- **Code review:** **deteksi base-branch per repo** dulu — `git -C <path> symbolic-ref refs/remotes/origin/HEAD` (mis. → `origin/main`); kalau gagal/ambigu, TANYA user (jangan asal `main`). Lalu review diff app (`git -C <path> diff <base>...HEAD`). Cari bug & inkonsistensi konvensi (`control/conventions.md`).
- **Quality gate:** jalankan test/lint/typecheck/build app (perintah sesuai `stack`).
- **Business alignment:** bandingkan kode yang jadi vs `business.md` + `plans/<app>.md` — invoke subagent `critic` dengan fokus: scope creep? requirement kelewat? menyimpang dari maksud bisnis?

### 3. Integrasi cross-app (bila fitur >1 app + ada `_shared.md`)
Boot app-app terkait bareng (path/stack `workspace.yaml`), jalankan contract/smoke test terhadap flow bersama (mis. login web↔api): cookie/format token/shape JSON cocok dua sisi. Gagal → STOP, jangan ship. (Loop per-app di step 2 hanya app NYATA dari `fanout.md`; roundtrip integrasi ditangani khusus oleh step ini. Fitur 1-app → lewati.)

### 4. Challenge Checklist (WAJIB sebelum ship)
- Semua test hijau? alignment ke `business.md` OK?
- Ada scope creep / requirement kelewat?
- Ada risiko yang belum ke-cover?
- Ada langkah `manual:` (`tasks.yaml`) yang belum dikonfirmasi beres? (env/secret/OAuth app prod)

### 5. Putuskan
- **Semua hijau →** lanjut Step 6.
- **Ada merah →** laporkan kegagalan/misalignment ke user, **STOP — jangan ship.** Jangan rubber-stamp.

### 6. Kirim & tandai (GATE)
- Susun deskripsi PR dari `business.md` + `fanout.md` + `plans` + ringkasan diff (terhubung ke ALASAN bisnis, bukan cuma "what").
- Tentukan **repo unik** yang kena: probe `git -C <path> rev-parse --show-toplevel` tiap app NYATA, kelompokkan per toplevel. Bikin **satu PR per repo unik** (monorepo/nested → otomatis 1 PR karena toplevel sama; multi-repo → 1 PR per repo). Base = hasil deteksi `symbolic-ref` (di code-review step). Pakai `gh pr create`; bila `gh`/remote tak ada, tampilkan deskripsi PR untuk dibuat user.
- Set `feature.yaml` → `status: shipped` + tambah `shipped_at: <YYYY-MM-DD>`.
- Regenerate doc: invoke skill `render-docs` bila tersedia; bila belum ada (Fase 5), ingatkan user untuk regenerate nanti.

## Catatan
- `ship` TIDAK mengeksekusi/menulis fitur — implementasi dilakukan sebelumnya oleh `build` (atau manual). `ship` = finishing gate + kirim, dan yang membuat PR / menandai `shipped` (bukan `build`).
- Hanya jalan pada fitur `status: active`. Bila belum, hentikan & jelaskan.
