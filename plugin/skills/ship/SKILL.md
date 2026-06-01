---
name: ship
description: Use saat development sebuah fitur SELESAI — finishing gate (code review + quality + cek keselarasan kode vs business.md), lalu bikin PR & tandai fitur shipped. Trigger — "ship <fitur>", "kelarin fitur <fitur>", "finishing <fitur>". Jalankan dari root produk yang punya control/.
---

# ship — Finishing & Kirim

Tujuan: pastikan fitur yang sudah diimplementasi BENAR & selaras bisnis, lalu kirim (PR) + tandai `shipped`. Status `shipped` jadi byproduct, bukan flag manual.

## Langkah

### 1. Baca fitur & cek kesiapan
Baca `control/features/<fitur>/feature.yaml` (harus `status: active`, + field `sensitivity`), `business.md`, `fanout.md`, `plans/*`. Tentukan **unit** (app ATAU package) yang kena dari `fanout.md`/`tasks.yaml` + `path`/`stack` dari `control/workspace.yaml` (`apps[]` + `packages[]`).
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
- Ada temuan dari Security & Compliance Gate (step 4.5) yang belum kelar? (secret/PII/PCI/authz/webhook-signature)

### 4.5 Security & Compliance Gate (STOP-on-fail, sebobot quality gate)
Berskala ke `feature.yaml` `sensitivity` (baca di step 1):
- **`sensitivity` kosong →** quick scan murah: grep diff fitur untuk secret hardcoded (API key/token/password/connstring di luar env) + PII di log. Temuan → angkat ke Putuskan.
- **`sensitivity` memuat `payments`/`pii` →** invoke subagent **`security-critic`** atas diff penuh (lintas repo yang kena, path/SHA dari code-review step 2) + `control/invariants.md` + `control/integrations.md` (baseline webhook signature/mode/idempotency per vendor). Temuan **severity high** = **RED**.
Disisipkan di sini (desimal 4.5) supaya tak me-renumber Step 5/6 & cross-ref internal "lanjut Step 6" tetap valid.

### 5. Putuskan
- **Semua hijau (termasuk Security Gate) →** lanjut Step 6.
- **Ada merah →** laporkan kegagalan/misalignment ke user, **STOP — jangan ship.** Jangan rubber-stamp.

### 6. Kirim & tandai (GATE)
- Susun deskripsi PR dari `business.md` + `fanout.md` + `plans` + ringkasan diff (terhubung ke ALASAN bisnis, bukan cuma "what").
- **Runbook integrasi (bila fitur kena vendor di `integrations.md`):** agregasi per vendor ke deskripsi PR — URL webhook yang perlu didaftarkan di console vendor (dari `Endpoint`/path receiver), env secret yang perlu di-set (NAMA var dari `Secret env`), switch mode test→live. Menutup gap "hasil langkah manual tak mendarat"; melengkapi challenge step 4. (Scoped ke integrasi — full release-runbook = Langkah 3.)
- Tentukan **repo unik** yang kena: probe `git -C <path> rev-parse --show-toplevel` tiap unit NYATA (app ATAU package; resolve `path` dari `apps[]`/`packages[]`), kelompokkan per toplevel. Bikin **satu PR per repo unik** (monorepo/nested → otomatis 1 PR karena toplevel sama; multi-repo → 1 PR per repo). Update-task consumer (fan-IN) sudah masuk `tasks.yaml` → repo consumer otomatis ikut grouping. Base = hasil deteksi `symbolic-ref` (di code-review step). Pakai `gh pr create`; bila `gh`/remote tak ada, tampilkan deskripsi PR untuk dibuat user.
- Set `feature.yaml` → `status: shipped` + tambah `shipped_at: <YYYY-MM-DD>`.
- Regenerate doc: invoke skill `render-docs` bila tersedia; bila belum ada (Fase 5), ingatkan user untuk regenerate nanti.

## Catatan
- `ship` TIDAK mengeksekusi/menulis fitur — implementasi dilakukan sebelumnya oleh `build` (atau manual). `ship` = finishing gate + kirim, dan yang membuat PR / menandai `shipped` (bukan `build`).
- Hanya jalan pada fitur `status: active`. Bila belum, hentikan & jelaskan.
