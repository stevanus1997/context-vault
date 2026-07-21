---
name: architect
description: Use untuk menetapkan (greenfield) atau merekam (brownfield) fondasi teknis produk — stack per app + capabilities + konvensi lintas-app. Dijalankan setelah init, sebelum bikin fitur; nambah app baru lewat add-app. Trigger — "architect", "setup stack", "capture arsitektur". Jalankan dari root produk yang punya control/.
---

> **Harness Kimi Code:** sebelum dispatch subagent apa pun, baca `${KIMI_SKILL_DIR}/../../rules/kimi-harness.md` (mapping critic/implementer → sub-agent bawaan Kimi).

# architect — Fondasi Teknis

Tujuan: isi lapisan TEKNIS dari System Map — `stack` tiap app + `capabilities` + konvensi lintas-app (`conventions.md`) — TERPISAH dari fitur bisnis.

## Langkah

### 1. Baca state
Baca `control/workspace.yaml` (apps, path, stack, capabilities) + `control/conventions.md`.

### 2. Tentukan mode PER app
Untuk tiap app, cek kode di `path`-nya:
- **Kosong / belum ada kode → SETUP mode.**
- **Ada kode → CAPTURE mode.**
(Boleh campur: sebagian app setup, sebagian capture.)

### 3a. SETUP (app greenfield)
- Q&A **TEKNIKAL** (bukan bisnis): framework, bahasa, DB/ORM, lib kunci.
- Tulis hasil ke `stack` app di `control/workspace.yaml` (mis. `stack: { framework: Next.js, db: Postgres, orm: Prisma }`).
- Catat command bootstrap RESMI stack-nya (mis. `npx create-next-app@latest apps/web`) sebagai bagian keputusan. **Eksekusi scaffold/bring-up = jatah `wire`** (gated), BUKAN di sini. `architect` TIDAK menulis/menjalankan kode framework — ia menetapkan, `wire` yang men-scaffold lewat scaffolder resmi.

### 3b. CAPTURE (app existing)
- Scan `package.json` + struktur folder/route di `path` app → rekam `stack` (framework, db bila terbaca) ke `control/workspace.yaml`.
- Inferensi `capabilities` dari nama route/module/folder (mis. `routes/checkout` → `checkout`) → isi `capabilities` app di `workspace.yaml`. **Konfirmasi ke user** sebelum menulis.
- Catat **divergensi** antar-app (mis. `web` pakai Prisma, `dashboard` pakai TypeORM) → laporkan ke user.

### 3c. PACKAGE (unit `type: package`, dipanggil `add-package`)
Bila dijalankan untuk sebuah shared package (bukan app): Q&A **teknikal** singkat — bahasa, build-tool, test-runner. Tulis ke `stack` package di `control/workspace.yaml`. Rekam konvensi import/build package ke `conventions.md` (langkah 4). Package = CONSUMER invarian — langkah 4.5 hanya RE-KONFIRMASI `stack` package tak melanggar `invariants.md` terkunci (tak mengunci ulang).

### 4. Konvensi lintas-app
Tetapkan/rekam kontrak bersama (auth, format API, shared package, ORM standar) → tulis ke `control/conventions.md` (ganti skeleton-nya). **Termasuk prinsip penempatan kode** (section *Konvensi Struktur & Penempatan Kode*): "split by responsibility, BUKAN by technical-layer; file yang berubah bareng taruh bareng; satu file satu tanggung jawab" — `plan` baca ini buat ngisi slot `Lokasi`. Untuk keputusan fondasi besar (mahal di-refactor), jalankan Challenge Checklist + invoke subagent `critic`.

### 4.5 Kunci Invarian Platform (sekali, level-produk, GATE)
Invarian = keputusan fondasi yang membentuk SETIAP table & query, mahal di-refactor (model tenancy, representasi uang, idempotency, authz, PII/PCI, rate-limit, integrasi/webhook eksternal). Dikunci di DEPAN, bukan ditunda ke fitur pertama.
- Baca `control/invariants.md`. **Idempotent:** kalau SEMUA slot sudah resolved (bukan lagi `<belum dikunci>`) → tampilkan ringkas + konfirmasi, **JANGAN tanya ulang**. (Penting: `architect` di-rerun & dipanggil `add-app` per app baru — penguncian invarian level-produk TIDAK boleh terjadi tiap app.)
- Kalau ada slot `<belum dikunci>`: **ELICIT** per slot keputusannya (level fondasi, bukan stack). User boleh jawab `N/A — alasan`. Sodorkan slot saran; terima invarian tambahan spesifik-produk. Tulis hasil ke `control/invariants.md` (ganti `<belum dikunci>`). **Compliance constraint (M6):** baca `control/business/risks.md` (bila ada) saat ELICIT slot **PII/PCI & Money & Currency** — cocokkan keputusan teknis dgn kewajiban regulasi yang diketahui (mis. risks.md sebut PCI → slot PII/PCI harus menutup penanganan kartu). Advisory; degrade bila absen/sentinel. Lihat `${KIMI_SKILL_DIR}/../../rules/compliance-risk.md`. **Cross-cutting (M3, advisory):** bila kebutuhan bersifat runtime lintas-app (queue/job/audit/background) — bukan invarian fondasi — pertimbangkan apakah butuh **unit worker** terpisah; usul lewat `fanout`→`add-app`, **bukan** kunci slot invarian baru (Authz/Rate-limit sudah punya slot). Tak memblokir.
- **`critic` WAJIB di gate ini** (bukan kondisional): red-team `invariants.md` — invarian fondasi kelewat? keputusan berisiko/over-engineered? bentrok antar-invarian? Tanggapi tiap keberatan sebelum gate lewat.

### 5. Challenge Checklist (WAJIB sebelum gate)
- Konsisten antar-app? ada divergensi berisiko?
- Tradeoff pilihan stack/konvensi?
- Ada yang over-engineered / bisa lebih sederhana?

### 6. Tulis output (GATE)
Tampilkan `stack` & `capabilities` per app (`workspace.yaml`) + isi `conventions.md` + `invariants.md` → minta **approve**. Sarankan langkah berikutnya: `wire` (bring-up: scaffold + DB + wiring + env jadi skeleton jalan) sebelum `feature`. (Brownfield: `extract` opsional dulu.)

## Catatan
- `architect` = KNOWLEDGE fondasi (stack/konvensi/capabilities), BUKAN generator kode. Kode app dibuat scaffolder resmi (setup — **dijalankan `wire`**, gated) atau sudah ada (capture).
- Nambah app baru pasca-`init` = lewat skill `add-app`; nambah shared package = lewat skill `add-package` (keduanya manggil `architect` ini buat set `stack` unit yang baru dideklarasi — app via 3a/3b, package via 3c). `architect` standalone tetap buat set/recapture stack unit yang **sudah terdaftar** — ia **tidak** nulis entri app/package baru ke `workspace.yaml`.
- **Invarian platform (langkah 4.5) level-PRODUK, sekali kunci.** Saat `architect` di-rerun atau dipanggil `add-app` untuk app baru, langkah 4.5 hanya mengonfirmasi `invariants.md` yang sudah resolved — TIDAK menanya/mengunci ulang.
- **Identitas visual / design system** (palet, tipografi, motion, komponen primitif) di-handle skill `design-system` (dari mockup), BUKAN di sini — `architect` cukup pilih stack + "lib kunci".
- Sesudah ini, skill `plan` membaca `stack` + `conventions.md` + kode yang ada — tidak menetapkan stack lagi.
