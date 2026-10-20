## B. Menyusun brief implementer dari satu task

Dari satu entri `tasks.yaml`, **brief-writer** (`${CLAUDE_PLUGIN_ROOT}/agents/brief-writer.md`, didispatch controller `build` — SKILL step 3; jalur degrade: controller sendiri; peminjam `design-system`/`fix` memakai aturan isi ini apa adanya) merakit **brief** — ditulis ke `<root>/.claude/build/<work-item>/task-<id>-brief.md` (SKILL step 3; scratch ter-gitignore, TIDAK di-paste ke prompt) — berisi:
- **Task:** `desc` + `unit` (app/package/integration).
- **Files:** isi `files` (path create/modify/test).
- **Approach:** `approach`.
- **Test cases:** daftar `test` → "tulis test ini dulu (TDD), pastikan merah, baru implementasi sampai hijau".
- **Kontrak:** potongan `_shared.md` yang relevan.
- **Konvensi & stack:** dari `conventions.md` + `workspace.yaml` `stack` app.
- **Skema & struktur existing (WAJIB bila `unit ∈ apps[]` & `control/schema/<schema_owner(unit)>.md` non-stub) — otoritatif, reuse jangan duplikat:** tulis **slice skema relevan** + **listing dir target** ke brief, lalu directive reuse. **Nama file proyeksi di seluruh §B = `schema_owner(unit)`** (`${CLAUDE_PLUGIN_ROOT}/rules/db-ownership.md`, amandemen 2026-09-14) — app non-pemilik membaca proyeksi PEMILIK-nya; `databases[]` absen ⇒ identik `<unit>.md`.
  - **Slice skema** = fail-open UNION dibaca LIVE: tabel di `reuse:` ∪ tabel di `actions.affects` ∪ FK-neighbor (dari `control/schema/<schema_owner(unit)>.md`) dari tabel mana pun yang disebut — di-cap ~15 tabel; format ringkas proyeksi (kolom·tipe·key·FK). `reuse:` = SELECTION HINT, **bukan** filter otoritatif (over-include murah & aman; under-include malah ngalahin tujuan) → `reuse:` basi/parsial TIDAK fatal.
  - **Listing dir** = file yang sudah ada di tiap dir pada `files` task (mis. `internal/user/` → `user.go, repo.go, …`), **di-cap ~30 entri** (lebih → ringkas + hitung) biar dir gede tak membanjiri prompt.
  - **Directive:** *"Tabel & file ini SUDAH ADA — reuse/extend; JANGAN bikin tabel paralel atau file duplikat (mis. ada `user.go` → tambahin di situ, bukan `users.go`). Fakta kolom/FK/index di sini otoritatif."*
  - **Degrade:** `control/schema/<schema_owner(unit)>.md` absen/stub → blok jadi listing-dir saja + warning (ketiadaan `<unit>.md` pada app non-pemilik **bukan** pemicu); lanjut (no-op bagian skema). `unit` = package/`integration`/FE tanpa proyeksi → skip otomatis.
  - **Reconcile reuse↔proyeksi (cek di SKILL step 1, sekali di awal):** nama di `reuse:` task (table/file) di-assert MASIH ada di proyeksi/pohon SEBELUM dirakit ke brief — `reuse:` basi (mis. tabel di-rename fitur lain → match-by-nama putus) → WARN (`risk:low`) / STOP (`risk`≥`normal`), bukan nulis nama hantu yang nyuruh implementer extend tabel yang tak ada. Beda peran dari **Slice skema** di atas (yang fail-open & sengaja over-include untuk konteks): reconcile = **guard nama** anti-drift, slice = **konteks** otoritatif.
- **Titipan (`reference.md` §J):** semua titipan AKTIF task ini (`--format carry --for <id>`) — id + asal + isi apa adanya, di blok "Titipan" brief. Implementer mematuhinya seperti requirement.
- **Aturan repo:** rujuk `_rules-<repo>.md` lewat path (aturan yang sama untuk semua task di repo itu — `agents/brief-writer.md`); jangan salin isinya ke brief.
- **Pointer pola:** tunjuk 1-2 file existing sebagai contoh gaya (mis. route sejenis).
- **Mockup (bila task ber-`mockup:`):** baca file di path → **teks** (HTML/CSS) di-**tulis VERBATIM** ke brief; **gambar** (PNG/JPG) → sertakan path & minta subagent **membuka/melihat**-nya; **URL Figma** → fetch via Figma MCP bila tersedia, kalau tidak → perlakukan sebagai screenshot/gambar. Instruksi (**tech-agnostic**): *"Reproduksi HASIL VISUAL — layout, spacing, hierarki, dan animasi/transisi — memakai stack app (`workspace.yaml`) + komponen pada file 'Pointer pola'. JANGAN transplant markup mentah mockup; terjemahkan ke idiom komponen project. BAWA transisi/animasi yang ada di mockup — jangan dibuang sebagai dekoratif."* **Bila `control/design-system.md` ada & app dalam scope sebuah design system (cek `Berlaku buat`):** pakai **motion vocab bernama** di section `Motion`-nya untuk transisi/animasi (alih-alih nemu sendiri) — biar konsisten antar-fitur. Mockup = byte opaque user; `build` tak pernah mengasumsi framework-nya.
- **Signature dep (WAJIB bila ada `deps`):** untuk tiap task di `deps`, baca file yang dibuat/diubahnya **di disk** lalu tulis signature/ekspor TERKINI-nya ke brief (mis. `hash(pw: string): Promise<string>`, `issueSession(userId): string`). Implementer membangun di atas kode NYATA, bukan tebakan dari teks `approach`. **Repo pemilik dep sedang SIBUK (punya in-flight lane lain — mode lane §F):** JANGAN baca disk (bisa WIP) — baca dari **BASE-SHA task in-flight repo itu** (direkam SKILL step 3): `git -C <path-unit-workspace> show <base7-inflight>:./<file>` — `-C` pakai path unit LITERAL dari `workspace.yaml` (BUKAN toplevel hasil rev-parse; prefix allowlist `wire` 5.5 literal, wildcard-tengah mati) dan `./` WAJIB (tanpa itu `git show` resolve path relatif toplevel → salah di monorepo). Base in-flight = state committed+ter-review penuh terakhir, mencakup SEMUA task done — BUKAN head task dep (bisa BASI bila task done berikutnya me-refactor file yang sama). Repo dep idle → baca disk seperti biasa. **Bila task dep punya `produces:`** (signature ditranskripsi `breakdown` — `breakdown/reference.md` §A): bandingkan signature DISK vs `produces:` — beda → tandai **DRIFT** di prompt (+ catat buat gate). Disk SELALU menang; `produces:` cuma hint auditability, tak pernah meng-override kode nyata.
- **Instruksi (ditaruh di PROMPT dispatch, bukan brief — bentuk lengkap §K):** baca brief dulu (requirement, nilai eksak verbatim); pakai `test-driven-development`; commit setelah hijau; self-review; **tulis report detail ke path report** (apa yang dibangun + bukti test TDD + concern); balikan chat = **status + commit SHA + 1 baris test + concern**. Bila spec kurang, subagent boleh **balik nanya dulu** sebelum mulai (jangan nebak).

JANGAN suruh subagent membaca `tasks.yaml` — tulis teksnya ke brief; prompt dispatch cuma pointer brief + path report + kontrak balikan.

### Contoh (task T3 `auth`)
Brief `.claude/build/auth/task-T3-brief.md`:
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
```
Prompt dispatch (ramping):
```
Baca brief dulu — itu requirement-mu, nilai eksaknya dipakai verbatim:
  .claude/build/auth/task-T3-brief.md
Ikuti template (baca sendiri): <sdd>/implementer-prompt.md
Pakai test-driven-development. Commit setelah hijau. Self-review.
Tulis report detail (apa yang dibangun + bukti test TDD + concern) ke:
  .claude/build/auth/task-T3-report.md
Balikan chat: status + commit SHA + 1 baris hasil test + concern.
```

### Task integrasi (`unit: integration`)
Brief-writer merakit brief-nya (pola file-handoff sama): app mana yang di-boot (path/stack dari `workspace.yaml`), kontrak `_shared.md` yang diuji, kasus `test` roundtrip. Subagent menjalankan kedua app bareng (mis. start `api`, panggil dari `web`/HTTP), assert shape data cocok dua sisi. Status sama (DONE/BLOCKED/...). Konteks berat (boot+log) tetap di subagent.
