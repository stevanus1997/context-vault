# build — Reference (panduan dispatch subagent)

Dibaca oleh skill `build`. Cara menyusun prompt implementer dari satu task, template yang dipinjam, pilih model, dan cadence gate.

## A. Pinjam dari `subagent-driven-development`

`build` TIDAK meng-invoke skill `subagent-driven-development` (itu mengeksekusi plan `writing-plans` secara continuous + diakhiri `finishing-a-development-branch` — bentrok dengan gate kita & `ship`). `build` **meminjam** template & polanya:
- `implementer-prompt.md` — struktur prompt implementer.
- `spec-reviewer-prompt.md` — reviewer kepatuhan-spec.
- `code-quality-reviewer-prompt.md` — reviewer kualitas (pakai template `requesting-code-review`).
- Panduan pilih-model & penanganan status (DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT).

Kunci dari template implementer: *controller mem-paste teks task ke prompt; subagent TIDAK membaca file plan.* Maka sumber teks task kita = `tasks.yaml` (bukan file `writing-plans`).

## B. Menyusun prompt implementer dari satu task

Dari satu entri `tasks.yaml`, controller (`build`) merakit prompt berisi:
- **Task:** `desc` + `unit` (app/package/integration).
- **Files:** isi `files` (path create/modify/test).
- **Approach:** `approach`.
- **Test cases:** daftar `test` → "tulis test ini dulu (TDD), pastikan merah, baru implementasi sampai hijau".
- **Kontrak:** potongan `_shared.md` yang relevan.
- **Konvensi & stack:** dari `conventions.md` + `workspace.yaml` `stack` app.
- **Pointer pola:** tunjuk 1-2 file existing sebagai contoh gaya (mis. route sejenis).
- **Signature dep (WAJIB bila ada `deps`):** untuk tiap task di `deps`, baca file yang dibuat/diubahnya **di disk** lalu paste signature/ekspor TERKINI-nya (mis. `hash(pw: string): Promise<string>`, `issueSession(userId): string`). Implementer membangun di atas kode NYATA, bukan tebakan dari teks `approach`.
- **Instruksi:** pakai `test-driven-development`; commit setelah hijau; self-review; balik **ringkasan + status**. Bila spec kurang, subagent boleh **balik nanya dulu** sebelum mulai (jangan nebak).

JANGAN suruh subagent membaca `tasks.yaml` — paste teksnya.

### Contoh (task T3 `auth`)
```
Task: POST /auth/register (unit: api)
Files: create src/routes/auth/register.ts; modify src/routes/index.ts;
       test test/auth/register.test.ts
Approach: hash(util T1, src/lib/hash.ts) -> simpan User -> session(T2, src/lib/session.ts)
          -> 201 + set-cookie
Test cases (tulis dulu, TDD): sukses 201+cookie; email kepake 409; pw lemah 422
Kontrak (_shared): session = cookie httpOnly JWT HS256 TTL 7d
Konvensi: error problem+json; validasi zod (pola: src/routes/auth/login.ts)
Stack: Express + Prisma + Postgres
-> Pakai test-driven-development. Commit setelah hijau. Balik ringkasan + status.
```

### Task integrasi (`unit: integration`)
Controller merakit prompt: app mana yang di-boot (path/stack dari `workspace.yaml`), kontrak `_shared.md` yang diuji, kasus `test` roundtrip. Subagent menjalankan kedua app bareng (mis. start `api`, panggil dari `web`/HTTP), assert shape data cocok dua sisi. Status sama (DONE/BLOCKED/...). Konteks berat (boot+log) tetap di subagent.

## C. Pilih model (hemat biaya & cepat)
- Task mekanikal (1-2 file, spec jelas) → model murah/cepat.
- Integrasi multi-file / pattern-matching → model standar.
- Butuh judgment desain → model paling kuat.

## D. Cadence gate (mode A adaptif)
- **Default:** gate per **app × milestone** — semua task satu app dalam satu milestone hijau → BERHENTI, tampilkan diff + test + "dibangun vs task" + challenge checklist → approve/revisi.
- **Lebih rapat:** app pemegang kontrak `_shared.md` / ditandai berisiko (milestone fondasi) → checkpoint per-task.
- **Lebih longgar:** milestone bermotif mapan (OAuth provider ke-2/ke-3) → gabung gate.
- **Fitur 1-app** → ciut jadi 1 gate.
- Selalu hormati `deps` + Urutan `fanout` (mis. `web` dibangun setelah `api` nyata, bukan yang direncanakan).

## E. Status & resume
- **Atomik (konkret):** set `in_progress` **sebelum** dispatch; set `done` **hanya** setelah lulus verifikasi (commit+test, lihat SKILL step 4) + DUA review. Tulis **satu task per operasi** (Edit satu field / temp-file lalu rename) — jangan batch banyak task dalam satu tulis, biar interupsi nggak ninggalin YAML korup. `tasks.yaml` ikut ke-commit, jadi versi korup bisa dipulihkan dari git.
- Buntu beneran (bug/dead-end) → `blocked` + STOP + lapor (sandar `systematic-debugging`). Jangan `done` palsu; **jangan auto-retry `blocked`** (risiko loop).
- **Resume (sesi baru):** baca `tasks.yaml`. (1) `done` → lewati. (2) **`in_progress` → JANGAN dilewati**: sesi lalu mati di tengah; reconcile dengan working tree + `git log` (revert/bereskan WIP setengah jadi), reset ke `pending`, lalu re-dispatch. (3) `blocked` → laporkan + task yang nyangkut karena gantung ke situ; butuh reset eksplisit ke `pending` sebelum lanjut. (4) lanjut `pending` pertama yang seluruh `deps`-nya `done`.
- **Status balikan subagent** (dari template implementer — beda dari `status` task di `tasks.yaml`):
  - `DONE` → lanjut verifikasi + review.
  - `DONE_WITH_CONCERNS` → JANGAN langsung anggap `done`; tampilkan concern-nya, biar review/gate yang putuskan.
  - `NEEDS_CONTEXT` → kasih konteks yang diminta → re-dispatch (**bukan** `blocked`).
  - `BLOCKED` → root-cause dulu: bug lokal → `systematic-debugging`; task salah → balik `breakdown`; kontrak salah → balik `plan`. Re-dispatch ke model sama tanpa perubahan = anti-pola.
- **Eksekusi `actions`:** `install`/`cmd` → jalankan + verifikasi (paket/exit-code). `migrate` → **GATE**: tampilkan + approve sebelum apply (destruktif). `env` → tulis ke `.env` app. Semua action terverifikasi = syarat `done`.
- **`needs_human`** (task ber-`manual:` belum beres): dideteksi di step 2 → STOP seluruh build, lapor checklist; resume setelah user konfirmasi langkah manual beres → jalankan `actions` terkait → `in_progress`. Hitung sebagai BELUM siap-ship.

## F. Multi-repo (probe & branch)

Probe identitas repo tiap unit NYATA (app ATAU package; resolve `path` dari `apps[]`/`packages[]`): `git -C <path> rev-parse --show-toplevel`.
- `toplevel(app) == toplevel(hub)` atau antar-app sama → **SAMA repo** (monorepo/nested) → satu branch `feature/<fitur>`, nanti 1 PR.
- `toplevel(app) != toplevel(hub)` → **repo TERPISAH** → branch `feature/<fitur>` sendiri per repo, nanti PR sendiri.
- probe error → belum git repo → minta user `git init`/skip.

Implementer subagent commit di repo unit-nya (`git -C <path>`). `build` memastikan branch ada SEBELUM dispatch task yang nulis ke repo itu. **Pseudo-unit `integration` dilewati** saat probe/branch (tak punya `path`/repo sendiri); ia jalan di atas repo unit di `deps`-nya yang branch-nya sudah dibuat. Package mono-repo (`path = packages/<nama>`) ciut ke toplevel hub; multi-repo (`path = ../<nama>`) dapat branch+PR sendiri — sama seperti app. Eksekusi tetap sekuensial sesuai `deps` (tak ada dua subagent nulis tree sama serempak).
