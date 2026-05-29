---
name: build
description: Use untuk mengeksekusi tasks.yaml sebuah fitur (status active) jadi kode lulus-test — dispatch implementer subagent per task (TDD), review 2-tahap, gate per app/milestone, lalu siap di-ship. Resumable lintas-sesi. Trigger — "build <fitur>", "implement <fitur>", "kerjain <fitur>". Jalankan dari root produk yang punya control/.
---

# build — Eksekusi `tasks.yaml` (orchestrator)

Tujuan: jalanin `tasks.yaml` jadi kode yang lulus test, di bawah gate, lalu nyatakan fitur siap di-`ship`. `build` = **KONDUKTOR**; kode ditulis subagent (konteks isolasi → sesi build tetap ramping & resumable).

> Panduan dispatch (rakit prompt implementer dari satu task, template yang dipinjam, pilih model, cadence gate, resume) ada di `${CLAUDE_PLUGIN_ROOT}/skills/build/reference.md` — baca itu dulu.

## Langkah

### 1. Baca state & cek branch
Baca `control/features/<fitur>/tasks.yaml` + `plans/*` + `_shared.md` + `control/conventions.md` + `control/workspace.yaml` (path/stack). **Prasyarat:** `tasks.yaml` ada (kalau belum → suruh jalankan `breakdown` dulu, sebaiknya sesi terpisah); `feature.yaml` `status: active`. **Cek branch git** — kalau di `main`/`master`, minta konfirmasi / bikin branch fitur dulu (jangan mulai di main tanpa izin).

### 2. Pilih task
Ambil task `pending` pertama yang seluruh `deps`-nya `done`.

### 3. Dispatch implementer subagent
Rakit prompt LENGKAP dari task (paste teks task; **jangan** suruh subagent baca `tasks.yaml`): `desc` + `files` + `approach` + kasus `test` + potongan `_shared.md` + konvensi + stack + pointer file pola. Pilih model sesuai kompleksitas. Subagent menulis kode **TDD** (test dari kasus dulu → hijau), commit, self-review → balik **ringkasan + status**. (Detail rakitan prompt: `reference.md` bagian B.)

### 4. Review 2-tahap
Dispatch **spec-reviewer** ("verifikasi dengan baca kode, jangan percaya report") → bila lulus, **code-quality-reviewer**. Reviewer nemu masalah → implementer (subagent sama) perbaiki → review ulang sampai lulus.

### 5. Tandai status
Set `status`: `in_progress` saat mulai, `done` saat lulus DUA review (atomik — tulis ke `tasks.yaml`). Buntu → `blocked`, **STOP**, laporkan (sandar `systematic-debugging`). **JANGAN** tandai `done` palsu.

### 6. Gate per segmen (mode A adaptif)
Semua task satu segmen (default **app × milestone**) `done` → **BERHENTI**: tampilkan diff segmen + hasil test + "dibangun vs task" + **challenge checklist** → minta **approve/revisi**. Adaptif: app pemegang `_shared.md`/berisiko → boleh per-task; milestone mapan → boleh gabung; fitur 1-app → 1 gate. (Detail: `reference.md` bagian D.)

### 7. Selesai
Ulang sampai semua task `done` → laporkan **"fitur <fitur> siap di-`ship`"**. Serahkan ke `ship` — **JANGAN** jalankan `finishing-a-development-branch` (itu jatah `ship`). `feature.yaml` `status` tetap `active`.

## Catatan
- `build` BUKAN urusannya: nentuin stack (→ `architect`), mecah task (→ `breakdown`), bikin PR / tandai `shipped` (→ `ship`).
- Hemat konteks: kerja berat di subagent; sesi `build` cuma nampung ringkasan + status → bisa dicicil lintas sesi (resume dari `tasks.yaml`).
- Commit per task di branch fitur; PR & merge tetap jatah `ship`.
