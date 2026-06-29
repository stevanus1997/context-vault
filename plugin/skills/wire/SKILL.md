---
name: wire
description: Use untuk bring-up fondasi teknis produk SETELAH architect — scaffold app via tool resmi + nyalain DB + wiring FE↔BE + env standar jadi skeleton KOSONG-tapi-JALAN, semua di-GATE. Generic — baca stack dari workspace.yaml (apa pun framework/db/orm-nya), bukan daftar tetap. Greenfield (scaffold penuh) & brownfield (repair, idempotent). Trigger — "wire", "bring-up", "nyalain project", "scaffold skeleton". Jalankan dari root produk yang punya control/.
---

# wire — Bring-Up Fondasi (skeleton kosong-tapi-jalan)

Tujuan: ubah KEPUTUSAN `architect` jadi skeleton yang JALAN — app ter-scaffold (tool resmi), DB nyala & nyambung, FE↔BE ter-wire, env standar terpasang — KOSONG dari kode fitur. Setelahnya `feature`/`build` tinggal "bikin table + panggil API". Jalankan dari root produk (punya `control/`).

`architect` = WHAT (mutusin stack). `wire` = HOW TO RUN (instansiasi). `wire` **GENERIC**: jalanin apa pun yang architect putuskan (Next/SolidStart/Go/ClickHouse/Supabase/…), bukan daftar stack tetap.

> Detail (batas architect/wire, prosedur generik, DB managed vs bare-engine, env contract, smoke test, brownfield, multi-repo, pinjam mesin `build`) ada di `${CLAUDE_PLUGIN_ROOT}/skills/wire/reference.md` — baca itu dulu.

## Prinsip (jangan dilanggar)
- **Delegasi ke scaffolder resmi.** Jangan tulis kode framework sendiri — panggil tool resmi (`create-*`, `nest new`, `django-admin`, dll). `wire` cuma nulis GLUE (env, base URL, CORS, client).
- **Tiap aksi side-effecting = GATE.** Scaffold, bikin DB, migrate, tulis secret → tampilkan rencana + dampak → minta approve dulu. `migrate` JANGAN auto.
- **Generic, tapi jujur.** Stack mainstream → tahu command resminya. Stack langka → ajukan tebakan terbaik + GATE konfirmasi (atau lookup). JANGAN diam-diam salah.
- **Jangan mutusin arsitektur.** Engine/framework/orm = jatah architect. Keputusan LOGICAL hilang → balikin ke architect.

## Langkah (per app, urut; detail tiap langkah di reference)

### 0. Baca state & deteksi mode
Baca `control/workspace.yaml` (`apps[]` + `packages[]`: path/type/stack/topology) + `control/conventions.md` + `control/invariants.md`. **Prasyarat stack:** architect sudah set `stack` logical (min framework + db + orm) per app; kalau belum → arahkan ke `architect`. **Prasyarat invarian:** `control/invariants.md` ada DAN semua slot resolved (tak ada `<belum dikunci>`); kalau tidak → **STOP**, arahkan ke `architect` (kunci invarian dulu — ia membentuk skema baseline). Cek kode tiap `path`: kosong → **greenfield (scaffold penuh)**; ada kode → **brownfield (repair: lengkapi yang kurang, idempotent, jangan timpa)**.
- **Seed proyeksi skema (brownfield, presence-based):** untuk tiap app dengan sumber skema (ORM atau folder migrasi raw-SQL) yang `control/schema/<app>.md`-nya **absen/stub**, invoke `${CLAUDE_PLUGIN_ROOT}/rules/schema-projection.md` (`label=(pra-M4)`) buat seed dari sumber existing — **di-gate pada KEBERADAAN proyeksi, BUKAN status ter-wire** (app sudah ter-wire tapi proyeksi belum lahir TETAP di-seed; kalau tidak, step 3 yang no-op pada already-wired bikin proyeksi tetap kosong → ngalahin D1/D2/D5 di repo lama). `stack.orm` kosong **dan** tak ada folder migrasi → tulis stub + **warning** (app uncovered), jangan no-op diam. Idempoten (proyeksi sudah ada & current → skip).
- **Unit `type: package` → mode-package (reference §I):** package tak punya DB/server/route. Scaffold skeleton lib + register di workspace; **gate penutup = typecheck/lint hijau**; SKIP langkah 2 (DB), 3 (ORM/migrate), 4 (FE↔BE), 6 (smoke runtime). Resolve `path` dari `packages[].path`.
- **Dipanggil `add-integration` untuk vendor inbound → mode-integration (reference §J):** scaffold stub route webhook-receiver di app penerima (`Receiver app`) + rekam SHAPE env vendor ke `conventions.md`; **gate = app boot + route ter-register + typecheck**; SKIP DB/ORM/FE↔BE/smoke penuh. Logika verifikasi signature/idempotent = jatah `build`.

### 0.5 Q&A operasional ("nutup architect")
Per app, tanya yang OPERASIONAL (bukan pilih arsitektur): DB bare-engine → **Docker lokal / URL remote?**; DB managed → minta creds (gated); package manager/runtime; nilai env/secret. Konfirmasi `stack` logical yang dibaca; field logical hilang/ambigu → STOP, balikin ke architect.

### 1. Scaffold app
Jalankan **tool resmi** framework (GATE sebelum eksekusi). Brownfield: lewati bila sudah ter-scaffold.

### 2. Nyalain DB
Sesuai hasil 0.5: bare-engine → spin Docker lokal (generate `docker-compose.yml`) / URL remote; managed → connect pakai creds (GATE). (reference C.)

### 3. Konek BE↔DB
Init ORM/driver (`stack.orm`), generate migrasi **baseline** (kosong dari table fitur), **apply** (GATE — migrate jangan auto), smoke query buktikan koneksi. **Proyeksi skema (M4):** lalu generate `control/schema/<app>.md` dari **sumber skema existing** (ORM **atau** folder migrasi raw-SQL — `schema-projection.md` lokalisasi by-understanding, TANPA DB hidup) per `${CLAUDE_PLUGIN_ROOT}/rules/schema-projection.md` (`label=<none>`) — file lahir (header proyeksi; nol/baseline table) supaya `plan` tak pernah kena file-absen.

### 4. Wire FE↔BE
Fullstack → env + internal call; FE/BE kepisah → API base URL + CORS + (bila relevan) typed client. Ikut `conventions.md`. (reference A/B.)

### 5. Env standar
Tulis `.env` app (pastikan gitignored): DB_URL, API base URL, secret. Rekam SHAPE-nya (nama var + arti, tanpa nilai) ke `conventions.md`. Secret = GATE/manual. (detail env contract: reference D; action `env` pinjam build: reference H.)

### 5.5 Permission harness (unattended-ready)
Turunkan perintah **VERIFIKASI** unit ini dari `stack` + package manager (hasil 0.5): test runner, lint, typecheck, build — sesuai stack-nya (mis. `npm test` / `pnpm lint` / `npx tsc` / `cargo test` / `pytest`), bukan daftar tetap. **APPEND** sebagai rule harness (`Bash(<prefix>:*)`) ke `permissions.allow` di `<produk>/.claude/settings.json` root produk (file warisan `init`; absen → copy dari `${CLAUDE_PLUGIN_ROOT}/template/.claude/settings.json` dulu; dedup — jangan dobel). **GATE:** tampilkan rule yang mau ditambah + approve dulu (nulis settings = side-effecting). HANYA perintah yang sifatnya baca/verifikasi — JANGAN pernah masukkan: push/deploy/apply-migrate/`rm`/perintah jaringan-tulis (biar tetap nyangkut di prompt — itu memang fungsinya). Kenapa: tanpa allowlist ini `build --unattended` (M7) macet di permission prompt **harness** — berhenti di satpam yang tak dirancang, bukan di gate plugin. Brownfield: repair — lengkapi yang kurang. Mode-package/mode-integration: tetap jalan (typecheck/test-nya juga butuh izin).

**Allowlist multi-repo (`git -C <path>`) — ENUMERASI per path, BUKAN wildcard (kritis):** matcher permission Bash Claude Code cuma menghormati wildcard `:*` di **akhir** (prefix match); `*` di **tengah** pola (mis. `Bash(git -C * commit:*)`) diperlakukan **literal → TAK PERNAH match perintah nyata** (kebukti empiris — bahkan `git -C foo status` tanpa slash pun gagal; `**` globstar juga tidak). Karena `build`/`ship`/`fix` menjalankan git lewat bentuk multi-repo `git -C <path> <subcmd>`, allowlist-nya HARUS dienumerasi per path NYATA. Untuk tiap unit path `P` ∈ (`workspace.yaml` `apps[].path` ∪ `packages[].path`), **APPEND** ke `permissions.allow` cermin 9 bentuk polos ber-prefix `git -C <P>`: `Bash(git -C <P> status:*)`, `…diff`, `…log`, `…show`, `…rev-parse`, `…branch`, `…add`, `…commit`, `…checkout` (push/reset/clean SENGAJA tak di-allow → kalau dipakai, halt aman); dan **APPEND** ke `permissions.deny` cermin foot-gun polos: `Bash(git -C <P> push --force:*)`, `…push -f`, `…reset --hard`, `…clean`, `…checkout -- :*` (deny menang atas allow — kebukti; ini defense-in-depth bila allow kelak dilebarkan). Dedup vs entri ada; **GATE** bareng rule harness di atas. **Brownfield/repair:** buang dulu entri legacy bentuk-mati `Bash(git -C * …)` (allow & deny) bila ada — itu tak pernah jalan & memberi rasa-aman palsu — lalu enumerasi. Single-app yang app-nya = root repo: bentuk polos cukup untuk cwd, tapi karena build tetap pakai `git -C <path>`, enumerasi path tetap dilakukan.

**Setup notify unattended (skippable, M7-amend 2026-06-18):** karena allowlist baru disiapkan untuk unattended, sekalian **tawarkan** setup kanal notif (di sini ada manusia, bukan headless): *"Setup notif buat `build --unattended`? (skip kalau belum perlu)"*. Bila ya → Q&A kanal (wording kanonik `build/reference.md` §G: ntfy/macOS/Telegram/no-op) → tulis `<produk>/.claude/notify.sh` + `chmod +x` (sudah gitignored oleh `init`). Bila skip → lanjut; nanti precheck `drive.sh` yang ingatkan saat user benar-benar coba unattended. `notify.sh` user-specific → **DITANYA, bukan di-ship**. GATE: tampilkan isi notify.sh yang mau ditulis → approve.

### 6. Smoke test (GATE penutup)
Boot? DB kebaca? FE→BE nyampe? Ijo → tutup gate, laporkan "**app <x> siap di-`feature`**". **Lepas marker blueprint bila ada** — kalau `apps[].responsibility` app ini masih memuat frasa `(blueprint — belum di-bring-up)` (sisa declare blueprint di `init`), hapus frasa itu dari `responsibility` di `workspace.yaml` sekarang; app sudah di-bring-up, jadi `ask`/pembaca tak lagi salah-lapor sebagai 'belum dibangun'. Merah → STOP + lapor akar masalah (sandar `systematic-debugging`); JANGAN klaim siap. (reference E.)

## Catatan
- `wire` sekali jalan (kayak `extract`). Saat nambah app baru, dipanggil oleh skill `add-app` (yang chain `architect`→`wire`); saat nambah shared package, dipanggil oleh skill `add-package` (mode-package — reference §I); saat nambah vendor eksternal inbound, dipanggil oleh skill `add-integration` (mode-integration — reference §J); bisa juga di-rerun manual. Brownfield: bersifat **repair** — hanya bila wiring belum lengkap.
- TIDAK bikin table/skema fitur — itu jatah `build`. `wire` cuma bikin pipeline migrasi BERFUNGSI + baseline.
- TIDAK nyentuh `control/business/*`. PR & merge = jatah pengguna/`ship`; cek branch dulu (jangan mulai di `main` tanpa izin).
