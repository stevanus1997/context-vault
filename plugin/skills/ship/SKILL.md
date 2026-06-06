---
name: ship
description: Use saat development sebuah fitur SELESAI — finishing gate (code review + quality + cek keselarasan kode vs business.md), lalu bikin PR & tandai fitur shipped. Trigger — "ship <fitur>", "kelarin fitur <fitur>", "finishing <fitur>". Jalankan dari root produk yang punya control/.
---

# ship — Finishing & Kirim

Tujuan: pastikan fitur yang sudah diimplementasi BENAR & selaras bisnis, lalu kirim (PR) + tandai `shipped`. Status `shipped` jadi byproduct, bukan flag manual.

## Langkah

### 1. Baca fitur & cek kesiapan
Baca manifest work-item: **fitur** `control/features/<fitur>/feature.yaml` (`status: active`) **ATAU fix** `control/fixes/<id>/fix.yaml` (`status: open`/`diagnosed`, lane bugfix) — keduanya bawa field `sensitivity`. Untuk fitur: baca `business.md`, `fanout.md`, `plans/*`; **unit** dari `fanout.md`/`tasks.yaml`. Untuk fix: baca `notes.md`+`root_cause`+`business.md` fitur `relates_to`; **unit dari `fix.yaml.units`** (fix tak punya `fanout.md`). `path`/`stack` dari `control/workspace.yaml`.
**Cek kelengkapan build:** bila `tasks.yaml` ada, verifikasi SEMUA task `done`. Ada task belum-`done` (`pending`/`in_progress`/`blocked`/`needs_human`/status belum-selesai lain) → **BERHENTI**, arahkan balik ke `build` (jangan ship fitur setengah jadi). Bila `tasks.yaml` tidak ada, konfirmasi implementasi dilakukan manual. **Guard diff kosong:** kalau tidak ada perubahan kode terhadap base, jangan bikin PR — laporkan.

### 2. Per app yang kena
- **Code review:** **deteksi base-branch per repo** dulu — `git -C <path> symbolic-ref refs/remotes/origin/HEAD` (mis. → `origin/main`); kalau gagal/ambigu, TANYA user (jangan asal `main`). Lalu review diff app (`git -C <path> diff <base>...HEAD`). Cari bug & inkonsistensi konvensi (`control/conventions.md`).
- **Quality gate:** jalankan test/lint/typecheck/build app (perintah sesuai `stack`).
- **Business alignment:** bandingkan kode yang jadi vs `business.md` + `plans/<app>.md` — invoke subagent `critic` dengan fokus: scope creep? requirement kelewat? menyimpang dari maksud bisnis? (Untuk fix: bandingkan vs `root_cause` + kutipan `business.md` fitur `relates_to`; `plans/<app>.md` tak ada → lewati. `relates_to: []` → alignment ke `root_cause`/`invariants.md` saja.)

### 3. Integrasi cross-app (bila fitur >1 app + ada `_shared.md`)
Boot app-app terkait bareng (path/stack `workspace.yaml`), jalankan contract/smoke test terhadap flow bersama (mis. login web↔api): cookie/format token/shape JSON cocok dua sisi. Gagal → STOP, jangan ship. (Loop per-app di step 2 hanya app NYATA dari `fanout.md`; roundtrip integrasi ditangani khusus oleh step ini. Fitur 1-app → lewati.) Untuk work-item fix: unit dari `fix.yaml.units`; fix lintas-unit (`units` >1) **tetap** jalankan roundtrip ini terhadap `_shared.md` mini fix; fix 1-unit lewati.

### 4. Challenge Checklist (WAJIB sebelum ship)
- Semua test hijau? alignment ke `business.md` OK?
- Ada scope creep / requirement kelewat?
- Ada risiko yang belum ke-cover?
- Ada langkah `manual:` (`tasks.yaml`) yang belum dikonfirmasi beres? (env/secret/OAuth app prod)
- Ada temuan dari Security & Compliance Gate (step 4.5) yang belum kelar? (secret/PII/PCI/authz/webhook-signature)

### 4.5 Security & Compliance Gate (STOP-on-fail, sebobot quality gate)
Berskala ke `sensitivity` manifest work-item (`feature.yaml` ATAU `fix.yaml` — baca di step 1; untuk fix ini **hasil re-evaluasi** triage vs `invariants.md`, bukan warisan pasif):
- **`sensitivity` kosong →** quick scan murah: grep diff fitur untuk secret hardcoded (API key/token/password/connstring di luar env) + PII di log. Temuan → angkat ke Putuskan.
- **`sensitivity` memuat `payments`/`pii` →** invoke subagent **`security-critic`** atas diff penuh (lintas repo yang kena, path/SHA dari code-review step 2) + `control/invariants.md` + `control/integrations.md` (baseline webhook signature/mode/idempotency per vendor) + `control/business/risks.md` (baseline kewajiban compliance; memperkaya gate ini — pelanggaran high tetap RED). Temuan **severity high** = **RED**.
Disisipkan di sini (desimal 4.5) supaya tak me-renumber Step 5/6 & cross-ref internal "lanjut Step 6" tetap valid.

### 5. Putuskan
- **Semua hijau (termasuk Security Gate) →** lanjut Step 6.
- **Ada merah →** laporkan kegagalan/misalignment ke user, **STOP — jangan ship.** Jangan rubber-stamp.

### 6. Kirim & tandai (GATE)
- Susun deskripsi PR dari `business.md` + `fanout.md` + `plans` + ringkasan diff (terhubung ke ALASAN bisnis, bukan cuma "what"). (Untuk fix: deskripsi PR dari `root_cause` + diff + link `relates_to`/`flow`.)
- **Runbook integrasi (bila work-item kena vendor di `integrations.md`):** agregasi per vendor ke deskripsi PR — URL webhook yang perlu didaftarkan di console vendor (dari `Endpoint`/path receiver), env secret yang perlu di-set (NAMA var dari `Secret env`), switch mode test→live. Menutup gap "hasil langkah manual tak mendarat"; melengkapi challenge step 4. (Scoped ke integrasi — full release-runbook = Langkah 3.)
- **Runbook migrasi & urutan deploy (bila work-item punya tugas `migrate`):** agregasi ke deskripsi PR — urutan aman (migrasi expand/additive dulu → deploy app pemakai → migrasi contract terakhir), catatan backfill (long-running), langkah zero-downtime (expand-contract per `conventions.md`). **Advisory** (panduan, **bukan** gate keras — alat tak tau infra deploy). Cermin runbook integrasi; scoped ke migrasi (full release-runbook = Langkah 3).
- Tentukan **repo unik** yang kena: probe `git -C <path> rev-parse --show-toplevel` tiap unit NYATA (app ATAU package; resolve `path` dari `apps[]`/`packages[]`), kelompokkan per toplevel. Bikin **satu PR per repo unik** (monorepo/nested → otomatis 1 PR karena toplevel sama; multi-repo → 1 PR per repo). Update-task consumer (fan-IN) sudah masuk `tasks.yaml` → repo consumer otomatis ikut grouping. Base = hasil deteksi `symbolic-ref` (di code-review step). Pakai `gh pr create`; bila `gh`/remote tak ada, tampilkan deskripsi PR untuk dibuat user.
- Set manifest work-item → `status: shipped` + `shipped_at: <YYYY-MM-DD>` (untuk fix: `fix.yaml`, plus isi `fix_pr`).
- Regenerate doc: invoke skill `render-docs` bila tersedia; bila belum ada (Fase 5), ingatkan user untuk regenerate nanti.

## Catatan
- `ship` TIDAK mengeksekusi/menulis fitur — implementasi dilakukan sebelumnya oleh `build` (atau manual). `ship` = finishing gate + kirim, dan yang membuat PR / menandai `shipped` (bukan `build`).
- Hanya jalan pada work-item aktif: fitur `status: active` ATAU fix `status: open`/`diagnosed`. Bila belum (mis. fitur belum selesai `build`, fix belum `diagnosed`), hentikan & jelaskan.
