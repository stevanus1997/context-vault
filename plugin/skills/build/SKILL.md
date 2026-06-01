---
name: build
description: Use untuk mengeksekusi tasks.yaml sebuah fitur (status active) jadi kode lulus-test — dispatch implementer subagent per task (TDD), review 2-tahap, gate per unit/milestone, lalu siap di-ship. Resumable lintas-sesi. Trigger — "build <fitur>", "implement <fitur>", "kerjain <fitur>". Jalankan dari root produk yang punya control/.
---

# build — Eksekusi `tasks.yaml` (orchestrator)

Tujuan: jalanin `tasks.yaml` jadi kode yang lulus test, di bawah gate, lalu nyatakan fitur siap di-`ship`. `build` = **KONDUKTOR**; kode ditulis subagent (konteks isolasi → sesi build tetap ramping & resumable).

> Panduan dispatch (rakit prompt implementer dari satu task, template yang dipinjam, pilih model, cadence gate, resume) ada di `${CLAUDE_PLUGIN_ROOT}/skills/build/reference.md` — baca itu dulu.

## Langkah

### 1. Baca state, cek prasyarat & recovery
Baca `control/features/<fitur>/tasks.yaml` + `plans/*` + `_shared.md` + `control/conventions.md` + `control/workspace.yaml` (path/stack). **Prasyarat:** `tasks.yaml` ada (kalau belum → suruh jalankan `breakdown` dulu, sebaiknya sesi terpisah). **`feature.yaml` `status` HARUS `active`** — kalau `shipped`/`dropped`/`draft`, BERHENTI & jelaskan (jangan eksekusi fitur yang sudah ditutup atau belum di-plan).
- **Staleness check:** bila `plans/*` / `_shared.md` / `business.md` lebih baru (mtime) dari `tasks.yaml`, BERHENTI & tanyakan apakah perlu `breakdown` ulang dulu — task bisa basi (lihat `breakdown` step 7 untuk merge yang mempertahankan status).
- **Recovery resume:** scan task `in_progress` (sisa sesi yang mati di tengah). Untuk tiap `in_progress`: reconcile dengan working tree + `git log` — kalau ada WIP setengah jadi & test merah, revert/bereskan lalu set balik `pending`. **JANGAN pernah lewati `in_progress` diam-diam** (kalau dilewati, dependents-nya nyangkut selamanya). Laporkan juga task `blocked` + task yang nyangkut karena gantung ke situ.
- **Branch per repo (multi-repo aware):** untuk tiap unit NYATA yang kena (app ATAU package, dari `tasks.yaml`/`fanout.md`, **KECUALI pseudo-unit `integration`** yang tak punya `path` sendiri), resolve `path` dari `workspace.yaml` — `unit ∈ apps[]` → `apps[].path`; `unit ∈ packages[]` → `packages[].path` — lalu probe `git -C <path> rev-parse --show-toplevel`. Kelompokkan unit per **repo unik** (toplevel sama = satu repo; monorepo/nested otomatis ciut). Untuk tiap repo unik: cek branch — kalau di `main`/`master`, minta izin lalu `git -C <path> checkout -b feature/<fitur>` (atau checkout bila sudah ada). **Jangan commit di `main`/`master` tanpa izin.** Probe error (belum git) → minta user init / skip git. (Detail: `reference.md` §F.)

### 2. Pilih task
Ambil task `pending` pertama yang seluruh `deps`-nya `done`.
Bila task terpilih punya `manual:` yang belum dikonfirmasi beres → set `status: needs_human`, **STOP SELURUH build**, lapor checklist langkah manual ke user; **jangan dispatch** (hemat ronde implementer). Lanjut setelah user konfirmasi beres.

### 3. Dispatch implementer subagent
**Bila `unit: integration`:** ini BUKAN edit satu app — dispatch subagent yang mem-boot app-app di `deps` (pakai `path`/`stack` `workspace.yaml`), jalankan `test` roundtrip nyata terhadap kontrak `_shared.md`/`plans/<pkg>.md`, balik ringkasan + status. Gate-nya (step 6) membentang tree unit terkait, bukan satu app.

**Bila `unit` = package** (`unit ∈ packages[]`): dispatch = typecheck + test exports package (BUKAN boot/smoke app); resolve `path` dari `packages[].path`. **Fan-IN cheap-skip:** untuk update-task consumer (`deps: [task-pkg]` dari perubahan package `BREAKING`), subagent CEK dulu "consumer ini beneran memakai export yang berubah?" — kalau **tidak** → tandai no-op, pastikan typecheck hijau, selesai cepat (tak ada perubahan kode). Enumerasi tetap semua consumer (aman); biaya per-consumer murah.

Rakit prompt LENGKAP dari task (paste teks task; **jangan** suruh subagent baca `tasks.yaml`): `desc` + `files` + `approach` + kasus `test` + potongan `_shared.md` + konvensi + stack + pointer file pola. **Untuk tiap `deps`: baca file dep yang sudah ada di disk & paste signature/ekspor ASLINYA** ke prompt — jangan biarkan implementer nebak dari teks `approach`. Pilih model sesuai kompleksitas. Subagent menulis kode **TDD** (test dari kasus dulu → hijau), commit, self-review → balik **ringkasan + status**. Bila subagent **balik nanya** (spec kurang) sebelum mulai: jawab → re-dispatch dengan jawaban di-paste; jangan tandai gagal.

**Actions task** (bila ada): `install`/`cmd` → `build` jalanin lalu verifikasi (paket masuk `package.json`, perintah exit 0); **`migrate` → JANGAN auto: tampilkan rencana migrasi + minta approve user dulu** (destruktif), baru apply; `env` → `build` tulis ke `.env` app (nilai dari `manual:`/prompt user). Actions terverifikasi = prasyarat task `done`.

(Detail rakitan prompt + matrix status balikan: `reference.md` bagian B & E.)

### 4. Verifikasi + Review 2-tahap
Untuk task `unit: integration`: verify = commit maju di SETIAP repo app yang ada di `deps` + jalankan ulang `test` roundtrip (bukan satu "test app" tunggal).

**Sebelum percaya report:** pastikan subagent beneran commit (HEAD repo app maju dari SHA sebelum dispatch) & **jalankan ulang test app** — jangan tandai apa pun atas dasar klaim "DONE" doang.
Lalu dispatch **spec-reviewer** ("verifikasi dengan baca kode, jangan percaya report") → bila lulus, **code-quality-reviewer**. Reviewer nemu masalah → implementer (subagent sama; prompt re-dispatch HARUS self-contained: teks task penuh + temuan reviewer + SHA/file yang disentuh) perbaiki → review ulang. **Cap maksimal 3 ronde** — kalau belum lulus juga, set `blocked` + laporkan objeksi yang nggak kelar (jangan loop selamanya, jangan rubber-stamp).

### 5. Tandai status
Set `status`: `in_progress` saat mulai, `done` saat lulus DUA review + semua `actions` terverifikasi (atomik — tulis ke `tasks.yaml`). **Task ber-`manual:` belum beres → `needs_human` (sudah dideteksi di step 2: STOP + lapor checklist; bukan `blocked` — ini nunggu manusia, bukan error).** Buntu/error → `blocked`, **STOP**, laporkan (sandar `systematic-debugging`). **JANGAN** tandai `done` palsu.

### 6. Gate per segmen (mode A adaptif)
Semua task satu segmen (default **app × milestone**) `done` → **BERHENTI**: tampilkan diff segmen + hasil test + "dibangun vs task" + **challenge checklist** (termasuk: ada yang melanggar invarian terkunci di `control/invariants.md`? ada yang membypass mandatory package di `packages[].mandatory_for`?) → minta **approve/revisi**. Adaptif: app pemegang `_shared.md`/berisiko → boleh per-task; milestone mapan → boleh gabung; fitur 1-app → 1 gate. Task `unit: integration` membentuk segmen gate sendiri yang membentang tree unit di `deps`-nya (bukan satu app × milestone). (Detail: `reference.md` bagian D.)

### 7. Selesai
Ulang sampai semua task `done`. **Hard guard sebelum nyatakan selesai:** verifikasi SETIAP task di SETIAP milestone berstatus `done` — bila masih ada `pending`/`in_progress`/`blocked`/`needs_human`, JANGAN bilang siap-ship; laporkan task mana yang belum & kenapa. Baru kalau semua `done` → laporkan **"fitur <fitur> siap di-`ship`"**. Serahkan ke `ship` — **JANGAN** jalankan `finishing-a-development-branch` (itu jatah `ship`). `feature.yaml` `status` tetap `active`.

## Catatan
- `build` BUKAN urusannya: nentuin stack (→ `architect`), mecah task (→ `breakdown`), bikin PR / tandai `shipped` (→ `ship`).
- Hemat konteks: kerja berat di subagent; sesi `build` cuma nampung ringkasan + status → bisa dicicil lintas sesi (resume dari `tasks.yaml`).
- Commit per task di branch fitur; PR & merge tetap jatah `ship`.
