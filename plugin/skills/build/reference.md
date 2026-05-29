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
- **Task:** `desc` + `app`.
- **Files:** isi `files` (path create/modify/test).
- **Approach:** `approach`.
- **Test cases:** daftar `test` → "tulis test ini dulu (TDD), pastikan merah, baru implementasi sampai hijau".
- **Kontrak:** potongan `_shared.md` yang relevan.
- **Konvensi & stack:** dari `conventions.md` + `workspace.yaml` `stack` app.
- **Pointer pola:** tunjuk 1-2 file existing sebagai contoh gaya (mis. route sejenis).
- **Instruksi:** pakai `test-driven-development`; commit setelah hijau; self-review; balik **ringkasan + status**.

JANGAN suruh subagent membaca `tasks.yaml` — paste teksnya.

### Contoh (task T3 `auth`)
```
Task: POST /auth/register (app: api)
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
- `build` set `status` task: `in_progress` → `done` (atomik, tulis ke `tasks.yaml`) setelah lulus DUA review.
- Buntu → `blocked` + STOP + lapor (sandar `systematic-debugging`). Jangan `done` palsu.
- Resume: sesi baru baca `tasks.yaml`, lewati `done`, lanjut `pending` berikut.
