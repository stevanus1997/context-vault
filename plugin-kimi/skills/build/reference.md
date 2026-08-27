# build — Reference (panduan dispatch subagent)

Dibaca oleh skill `build`. Cara menyusun prompt implementer dari satu task, template yang dipinjam, pilih model, dan cadence gate.

## A. Pinjam dari `subagent-driven-development`

`build` TIDAK meng-invoke skill `subagent-driven-development` (itu mengeksekusi plan `writing-plans` secara continuous + diakhiri `finishing-a-development-branch` — bentrok dengan gate kita & `ship`). `build` **meminjam** template & polanya:
- `implementer-prompt.md` — struktur prompt implementer (≥6.0: ber-placeholder `[BRIEF_FILE]` + `[REPORT_FILE]`, bukan slot teks-task).
- `task-reviewer-prompt.md` — reviewer task: SATU sesi, DUA verdict (spec compliance + code quality) atas satu kali baca file diff; input = TIGA path REQUIRED (`[BRIEF_FILE]`/`[REPORT_FILE]`/`[DIFF_FILE]`) + boleh balikin kategori ke-3 `⚠️ Cannot verify from diff` (routing: SKILL step 4). (superpowers ≥6.0 menggabungkan `spec-reviewer-prompt.md` + `code-quality-reviewer-prompt.md` lama — dua file itu sudah TIDAK ada, jangan dirujuk.)
- `scripts/review-package BASE HEAD OUTFILE` — generator paket diff reviewer (commit list + stat + `diff -U10`). Git-based → dipakai langsung, TAPI **OUTFILE (arg-3) selalu diisi** `<root>/.claude/build/<work-item>/review-<base7>..<head7>.diff` (penamaan per-range dijaga manual); tanpa arg-3, sejak 6.0.3 script default ke `<repo-root>/.superpowers/sdd/` repo app (via `sdd-workspace`, self-gitignore) — dir scratch KEDUA di luar `.claude/build/`, jangan.
- Panduan pilih-model & penanganan status (DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT).

**Yang TIDAK ikut dipinjam dari template task-reviewer:** klausa "jangan re-run test yang sudah dijalankan implementer" — controller `build` TETAP verifikasi sendiri (HEAD maju + re-run test, SKILL step 4). Paranoia controller tidak dilonggarkan.

Kunci dari template implementer (≥6.0): **file-handoff** — controller menulis BRIEF per task ke file, prompt dispatch cuma menunjuk path (brief + report); artefak bulky TIDAK di-paste ke prompt (rasional upstream: semua yang di-paste nempel di konteks controller tiap turn — sejalan tujuan sesi `build` ramping & resumable). Prinsip yang TETAP: *subagent TIDAK membaca file plan/`tasks.yaml` UTUH* — brief self-contained = satu-satunya sumber requirement. Sumber teks task kita = `tasks.yaml` → `build` **menulis brief-nya SENDIRI** (`scripts/task-brief` upstream mem-parse format plan `writing-plans`, TIDAK bisa baca `tasks.yaml` — jangan dipakai; `scripts/review-package` tetap dipakai karena git-based).

## B. Menyusun brief implementer dari satu task

Dari satu entri `tasks.yaml`, controller (`build`) merakit **brief** — ditulis ke `<root>/.claude/build/<work-item>/task-<id>-brief.md` (SKILL step 3; scratch ter-gitignore, TIDAK di-paste ke prompt) — berisi:
- **Task:** `desc` + `unit` (app/package/integration).
- **Files:** isi `files` (path create/modify/test).
- **Approach:** `approach`.
- **Test cases:** daftar `test` → "tulis test ini dulu (TDD), pastikan merah, baru implementasi sampai hijau".
- **Kontrak:** potongan `_shared.md` yang relevan.
- **Konvensi & stack:** dari `conventions.md` + `workspace.yaml` `stack` app.
- **Skema & struktur existing (WAJIB bila `unit ∈ apps[]` & `control/schema/<unit>.md` non-stub) — otoritatif, reuse jangan duplikat:** tulis **slice skema relevan** + **listing dir target** ke brief, lalu directive reuse.
  - **Slice skema** = fail-open UNION dibaca LIVE: tabel di `reuse:` ∪ tabel di `actions.affects` ∪ FK-neighbor (dari `control/schema/<unit>.md`) dari tabel mana pun yang disebut — di-cap ~15 tabel; format ringkas proyeksi (kolom·tipe·key·FK). `reuse:` = SELECTION HINT, **bukan** filter otoritatif (over-include murah & aman; under-include malah ngalahin tujuan) → `reuse:` basi/parsial TIDAK fatal.
  - **Listing dir** = file yang sudah ada di tiap dir pada `files` task (mis. `internal/user/` → `user.go, repo.go, …`), **di-cap ~30 entri** (lebih → ringkas + hitung) biar dir gede tak membanjiri prompt.
  - **Directive:** *"Tabel & file ini SUDAH ADA — reuse/extend; JANGAN bikin tabel paralel atau file duplikat (mis. ada `user.go` → tambahin di situ, bukan `users.go`). Fakta kolom/FK/index di sini otoritatif."*
  - **Degrade:** `control/schema/<unit>.md` absen/stub → blok jadi listing-dir saja + warning; lanjut (no-op bagian skema). `unit` = package/`integration`/FE tanpa proyeksi → skip otomatis.
  - **Reconcile reuse↔proyeksi (cek di SKILL step 1, sekali di awal):** nama di `reuse:` task (table/file) di-assert MASIH ada di proyeksi/pohon SEBELUM dirakit ke brief — `reuse:` basi (mis. tabel di-rename fitur lain → match-by-nama putus) → WARN (`risk:low`) / STOP (`risk`≥`normal`), bukan nulis nama hantu yang nyuruh implementer extend tabel yang tak ada. Beda peran dari **Slice skema** di atas (yang fail-open & sengaja over-include untuk konteks): reconcile = **guard nama** anti-drift, slice = **konteks** otoritatif.
- **Pointer pola:** tunjuk 1-2 file existing sebagai contoh gaya (mis. route sejenis).
- **Mockup (bila task ber-`mockup:`):** baca file di path → **teks** (HTML/CSS) di-**tulis VERBATIM** ke brief; **gambar** (PNG/JPG) → sertakan path & minta subagent **membuka/melihat**-nya; **URL Figma** → fetch via Figma MCP bila tersedia, kalau tidak → perlakukan sebagai screenshot/gambar. Instruksi (**tech-agnostic**): *"Reproduksi HASIL VISUAL — layout, spacing, hierarki, dan animasi/transisi — memakai stack app (`workspace.yaml`) + komponen pada file 'Pointer pola'. JANGAN transplant markup mentah mockup; terjemahkan ke idiom komponen project. BAWA transisi/animasi yang ada di mockup — jangan dibuang sebagai dekoratif."* **Bila `control/design-system.md` ada & app dalam scope sebuah design system (cek `Berlaku buat`):** pakai **motion vocab bernama** di section `Motion`-nya untuk transisi/animasi (alih-alih nemu sendiri) — biar konsisten antar-fitur. Mockup = byte opaque user; `build` tak pernah mengasumsi framework-nya.
- **Signature dep (WAJIB bila ada `deps`):** untuk tiap task di `deps`, baca file yang dibuat/diubahnya **di disk** lalu tulis signature/ekspor TERKINI-nya ke brief (mis. `hash(pw: string): Promise<string>`, `issueSession(userId): string`). Implementer membangun di atas kode NYATA, bukan tebakan dari teks `approach`. **Repo pemilik dep sedang SIBUK (punya in-flight lane lain — mode lane §F):** JANGAN baca disk (bisa WIP) — baca dari **BASE-SHA task in-flight repo itu** (direkam SKILL step 3): `git -C <path-unit-workspace> show <base7-inflight>:./<file>` — `-C` pakai path unit LITERAL dari `workspace.yaml` (BUKAN toplevel hasil rev-parse; prefix allowlist `wire` 5.5 literal, wildcard-tengah mati) dan `./` WAJIB (tanpa itu `git show` resolve path relatif toplevel → salah di monorepo). Base in-flight = state committed+ter-review penuh terakhir, mencakup SEMUA task done — BUKAN head task dep (bisa BASI bila task done berikutnya me-refactor file yang sama). Repo dep idle → baca disk seperti biasa. **Bila task dep punya `produces:`** (signature ditranskripsi `breakdown` — `breakdown/reference.md` §A): bandingkan signature DISK vs `produces:` — beda → tandai **DRIFT** di prompt (+ catat buat gate). Disk SELALU menang; `produces:` cuma hint auditability, tak pernah meng-override kode nyata.
- **Instruksi (ditaruh di PROMPT dispatch, bukan brief):** baca brief dulu (requirement, nilai eksak verbatim); pakai `test-driven-development`; commit setelah hijau; self-review; **tulis report detail ke path report** (apa yang dibangun + bukti test TDD + concern); balikan chat = **status + commit SHA + 1 baris test + concern**. Bila spec kurang, subagent boleh **balik nanya dulu** sebelum mulai (jangan nebak).

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
Pakai test-driven-development. Commit setelah hijau. Self-review.
Tulis report detail (apa yang dibangun + bukti test TDD + concern) ke:
  .claude/build/auth/task-T3-report.md
Balikan chat: status + commit SHA + 1 baris hasil test + concern.
```

### Task integrasi (`unit: integration`)
Controller merakit brief-nya (pola file-handoff sama): app mana yang di-boot (path/stack dari `workspace.yaml`), kontrak `_shared.md` yang diuji, kasus `test` roundtrip. Subagent menjalankan kedua app bareng (mis. start `api`, panggil dari `web`/HTTP), assert shape data cocok dua sisi. Status sama (DONE/BLOCKED/...). Konteks berat (boot+log) tetap di subagent.

## C. Pilih model (hemat biaya & cepat)
- Task mekanikal (1-2 file, spec jelas) → tier terendah yang lolos floor di bawah.
- Integrasi multi-file / pattern-matching → model standar.
- Butuh judgment desain → model paling kuat. **Task ber-`mockup:` masuk kategori ini** — menerjemahkan mockup (yang teknologinya bisa ≠ stack project) ke komponen existing tanpa transplant markup butuh judgment desain.
- **Turn count beats token price (upstream ≥6.1):** model termurah rutin makan 2–3× turn di kerja multi-step — total malah lebih lambat & lebih mahal. **Floor mid-tier untuk reviewer DAN implementer yang kerja dari prosa.** Task `tasks.yaml` = prosa (desc/approach/test, TANPA kode) → praktisnya implementer hampir selalu floor mid-tier; tier termurah HANYA bila teks task memuat kode lengkap tinggal transkripsi+test, atau fix mekanikal 1-file. Reviewer JANGAN pernah di bawah mid-tier (rubber-stamp + deteksi entity-equivalence butuh judgment).

## D. Cadence gate (mode A adaptif)
- **Default:** gate per **app × milestone** — semua task satu unit (app/pkg) dalam satu milestone hijau → BERHENTI, tampilkan diff + test + "dibangun vs task" + challenge checklist → approve/revisi.
- **Lebih rapat:** app pemegang kontrak `_shared.md` / ditandai berisiko (milestone fondasi) → checkpoint per-task.
- **Lebih longgar:** milestone bermotif mapan (OAuth provider ke-2/ke-3) → gabung gate.
- **Fitur 1-app** → ciut jadi 1 gate.
- **`--unattended` (opt-in, fitur saja — M7):** (amandemen 2026-08-27 — gate ditunda, §I) gate segmen TIDAK PERNAH menghentikan run. Tiga kelas titik-manusia: **A gate review (ditunda)** — `risk:high` / floor-scan / DDL / penyimpangan / smoke gagal → entri `queued` di `gates.yaml` + `security-critic` bila alasan keamanan/uang → lanjut; **B blocker (subtree nunggu)** — `migrate` destructive/backfill atau apply tak di-allowlist / `needs_human` / `blocked` / `NEEDS_CONTEXT` user-only / konflik pre-flight / reuse basi → task `needs_human`/`blocked` + `hold:`, dependents otomatis tak READY, sisanya lanjut; **C auto** — bersih + `risk` low/normal → entri `auto`. Run berhenti hanya: tak ada task READY (`review`) / cap-volume (`continue`) / abnormal (`halt`) / selesai (`done`). Menunda gate yang ADA, BUKAN gate baru/pelonggaran; tak menyentuh Security Gate `ship`. Default (tanpa flag) = stop tiap segmen, plus drain antrian di awal bila ada (§I). **Floor-scan diff (M7-amend 2026-06-18):** jaring deterministik tak-bergantung tag `risk` — grep diff tiap segmen untuk verba bahaya (*Verba-keamanan* + *Verba-uang PLUMBING* `tweak/reference.md` §A) + DDL migrasi; kena → attended STOP / unattended `queued`. Degrade: `risk` absen + `sensitivity:[payments]` → diperlakukan `high` (= semua gate `queued`, non-blocking).
  - **Prasyarat harness (cek di awal run, step 1):** `permissions.allow` di `<produk>/.claude/settings.json` memuat perintah verifikasi stack unit yang kena (diisi `wire` 5.5). Kosong/kurang → WARN sebelum mulai: run bakal nyangkut di permission prompt harness (satpam yang tak dirancang), bukan di gate plugin — tawarkan jalan attended atau lengkapi allowlist dulu (`wire` repair).
  - **Rem run-level (wajib saat unattended):** (a) **circuit breaker** — 2 task berturut-turut berakhir `blocked`/gagal dengan akar serupa → STOP SELURUH run + lapor "dugaan masalah sistemik" (1 penyebab ≠ N bug; jangan giling task berikutnya, bakar token percuma); (b) **cap volume (budget bobot)** — BUKAN hitung jumlah task (10 task enteng ≠ 10 task berat ber-token); tiap task punya **bobot**, dan satu run berhenti **sebelum** mulai task yang bakal bikin total bobot **lewat budget** (default **10**) — jadi total bobot per run selalu **≤ budget**. **Bobot per task** diturunkan dari field `tasks.yaml` yang SUDAH ADA (tak perlu — & tak bisa — ukur token dari dalam): **3 (berat)** bila ber-`mockup:` ATAU `unit: integration` ATAU `files` > 4; **2 (sedang)** bila `files` 3–4; **1 (enteng)** selainnya. **Aturan stop (look-ahead):** sebelum dispatch tiap task, hitung `total_berjalan + bobot(task)`; bila `> budget` DAN sudah ≥1 task jalan di run ini → STOP + ringkasan run + sisa antrian. **Task PERTAMA tiap run SELALU jalan** (jamin minimal 1 task/run, biar 1 task super-berat tak ke-block selamanya). User boleh set budget lain saat memanggil. Efek: task berat "makan jatah" lebih cepat → proses tetap ramping (cegah 1 proses gendut sampai context membengkak). **`breakdown` TAK berubah** — bobot dihitung di build dari field yang sudah ada. Rem ini level-RUN — melengkapi cap 3-ronde review yang levelnya per-task (SKILL step 4), bukan menggantikannya.
  - **Mode lane (paralel lintas-repo §F):** (a) **breaker** — `blocked` PERTAMA (unattended, amandemen 2026-08-27) TIDAK menghentikan run: task hold, subtree nunggu, lane lain lanjut; `blocked` KEDUA ber-akar-serupa → `halt` `reason` "dugaan sistemik" (breaker = memperkaya diagnosis; hitung "berturut kronologis lintas-lane" DITOLAK — race-dependent, bisa gagal trip saat interleaving). (b) **cap budget** — look-ahead dicek SAAT dispatch (controller satu proses, dispatch satu-per-satu); bobot = semua task ter-dispatch run ini TERMASUK in-flight; lewat → stop dispatch baru → drain → `continue` (kecuali drain hasilkan floor/`blocked` → presedensi `halt` > `continue` > `review` > `done`, SKILL step 1). Garansi task-pertama: "pertama" = ready paling awal urut dokumen LINTAS-lane, bebas cek budget (generalisasi setia aturan existing — task berat urutan-belakang nunggu giliran persis seperti sekuensial, bukan regresi). (c) **auto-approve** gate TIDAK menghentikan lane lain; segmen yang kelar DI TENGAH drain-halt & lolos kriteria → tetap auto-approve + catat (stop-nya disebabkan hal lain). Start run dengan `blocked` sudah di `tasks.yaml` → attended: drain dulu (§I); unattended: laporkan + lanjut lane lain (§E); tak ada ready-task di luar subtree blocked → `outcome: review` (bukan `halt` — blocker nunggu drain pagi; amandemen 2026-08-27).
- Urutan `fanout` (mis. `web` setelah `api` NYATA) ter-encode sebagai `deps` oleh `breakdown`; scheduler lane menghormatinya via `deps` + **guard cross-check** (SKILL step 1): ready-task repo HILIR tanpa jalur `deps` ke task mana pun repo HULU yang masih ber-`pending`/in-flight → tahan dispatch lintas-repo + WARN ("deps lintas-app mungkin bolong — cek `breakdown`"); era sekuensial nutupin bolong ini lewat urutan dokumen, lane membukanya.
- **Simplify pass final (gate one-shot, SKILL step 7a):** BUKAN bagian loop cadence per-segmen di atas — jalan SEKALI sesudah semua task `done` (hard-guard lolos), sebelum nyatakan siap-ship. Atas **diff fitur utuh** (lintas-segmen/app), bukan per-segmen: nangkep duplikasi/helper-kembar/dead-code yang baru kelihatan pasca-rakit. **HANYA behavior-preserving** (seperti `kind: debt`; test existing = bukti regresi, re-run sesudah apply). Aman+lokal → apply→re-verify→GATE approve/revisi (cap 3 ronde seperti review step 4; mentok → buang perubahan); besar/berisiko/ubah-perilaku → APPEND `debt.yaml` (pintu ke-4), JANGAN paksa masuk. Floor-scan (verba bahaya §A + DDL) & aturan unattended sama persis dengan cadence di atas: kena floor → attended STOP / unattended `queued` (`segment: simplify`) apa pun `risk`; unattended bersih + `risk` low/normal + ijo → `auto`. 7a TIDAK dijalankan selama `gates.yaml` masih punya `queued` (SKILL step 7, amandemen 2026-08-27). Anti-rekursi: inline, JANGAN invoke `/simplify`/`/debt`/`/fix`. Subagent: `code-simplifier` (dibekali diff + `conventions.md` + slice `control/schema/<unit>.md`).
- **Milestone smoke + section "Coba sendiri" (M-smoke, SKILL step 6).** Tiap gate segmen menampilkan section **"Coba sendiri"** di samping diff/test/challenge:
  - **Part A (SELALU, murah, tanpa boot):** (a) **test-case lulus** eksplisit dari `test:` task-task segmen (bukan cuma "N/N ijo"); (b) **resep verifikasi manual** — `curl`/URL "buka …" untuk surface yang dibangun, diturunkan dari **diff + `files` + port env-contract** (`wire` `.env`). Milestone logika-murni (tanpa surface) → resep kosong "no runnable surface", test-case tetap tampil.
  - **Part B (self-smoke, KONDISIONAL — auto+lapor):** dispatch **smoke subagent** bila trigger (tabel bawah) terpenuhi. Brief smoke (pola file-handoff, sama `unit: integration`): app mana yang di-boot (path/stack `workspace.yaml`) + resep Part A + path report. Subagent: boot app (mekanisme SAMA boot `unit: integration` — BUKAN invoke skill `/run`/`/verify`; pinjam polanya) → jalankan resep terhadap app hidup → tangkap **observasi** (status+shape response untuk API; screenshot/render-check untuk UI page) → tulis report → balikan ringkas. Gate menampilkan observasi di sebelah resep. Model smoke subagent = **tier rendah** (boot+probe, bukan judgment).
  - **Trigger Part B (semua harus IYA):**

    | syarat | lolos bila |
    |---|---|
    | ada runnable surface | diff segmen `create` **ATAU** `modify` HTTP route / UI page (`modify` penting — `fix` ngedit endpoint existing) |
    | belum di-boot integration | surface tak di-cover task `unit: integration` di segmen |
    | bukan mockup | task **tanpa** `mockup:` (yang ber-`mockup:` sudah eyeball+buka app) |
    | unit runnable | `unit ∈ apps[]` (package/`integration` → skip) |

    Deteksi "runnable surface" = **heuristik ringan** atas `unit`+`files`+diff (cocok konvensi routing/page app). **Ragu → skip Part B** + catat "surface tak jelas — smoke di-skip" (advisory, BUKAN palang; false-skip = balik perilaku lama, aman).
  - **Environment:** di titik gate env lokal DIJAMIN ada (DB ter-`wire`; `manual:` env/secret sudah lewat `needs_human` step 2). Smoke HANYA melawan env lokal ter-wire — tak pernah prod; boleh memutasi DB dev lokal (mis. `register` bikin row uji).
  - **Failure:** boot-fail / endpoint 5xx / crash / render rusak **PADAHAL unit-test ijo** = **penyimpangan** → masuk **disiplin fix embed** step 6 (reproduce→root-cause→corrective `kind: fix`); unattended: gate segmen `queued` "smoke gagal: …" (bukan `auto`), disiplin fix embed tetap jalan (amandemen 2026-08-27). Boot-fail karena prereq lingkungan yang mestinya ada → **blocker lingkungan** (`halt`), bukan corrective task. Observasi plausible → tampil gate (attended) / ringkas `last-run.md` (unattended). **Mode lane unattended (§F):** smoke gagal SEMENTARA lane lain in-flight yang runtime/DB-nya bisa terpanggil app yang di-boot → JANGAN langsung penyimpangan (bisa 5xx dari WIP repo sebelah → corrective task fiktif): tunggu repo terkait idle → re-run smoke SEKALI → tetap gagal → baru penyimpangan. (Attended aman by construction — gate dievaluasi pasca drain, semua lane idle.)
  - **Unattended (M7):** Part B tetap jalan (tujuannya). Observasi → prosa `last-run.md`. Ongkos = **satu boot per segmen qualifying** — TIDAK mengubah model bobot cap-volume (bobot = look-ahead per-task; smoke per-segmen di gate). Floor-scan tak terpengaruh (smoke tak nambah diff).
  - **Anti-dobel:** smoke SKIP surface yang sudah di-cover `unit: integration` / `mockup:` / roundtrip `ship` step 3. M-smoke = lebih dini, per-milestone, single-surface.
  - **Contoh (gate M2 `auth`):**
    ```
    ── Coba sendiri ──────────────────────────────
    test case lulus:
      • register sukses → 201 + set-cookie
      • register email kepake → 409 · pw lemah → 422
      • login sukses → 200 · pw salah → 401 · user ∅ → 401
    verifikasi manual (localhost:3000):
      curl -i -X POST localhost:3000/auth/register -d '{"email":"a@b.co","password":"secret12"}'
      curl -i -X POST localhost:3000/auth/login    -d '{"email":"a@b.co","password":"salah"}'
    smoke (auto):
      ✓ POST /auth/register → 201 {id,email} + Set-Cookie: sid=…
      ✓ POST /auth/login (pw salah) → 401 {error:"invalid_credentials"}
    ──────────────────────────────────────────────
    ```
    M1 (`hash`/`session`) → resep+smoke kosong ("no runnable surface"), test-case tetap tampil. M3 (`login` UI ber-`mockup:`) → Part B skip (sudah eyeball via mockup).

## E. Status & resume
- **Atomik (konkret):** set `in_progress` **sebelum** dispatch; set `done` **hanya** setelah lulus verifikasi (commit+test, lihat SKILL step 4) + review dua-verdict (task no-op fan-in → verifikasi deterministik step 4, tanpa reviewer). Tulis **satu task per operasi** (Edit satu field / temp-file lalu rename) — jangan batch banyak task dalam satu tulis, biar interupsi nggak ninggalin YAML korup. `tasks.yaml` ikut ke-commit, jadi versi korup bisa dipulihkan dari git.
- **Rentang commit per task (audit/resume).** Saat task → `done`, build tulis field `commits:` = `[<base7>..<head7>, ...]` per repo tersentuh (`base` = SHA direkam SEBELUM dispatch di SKILL step 3, per-repo — BUKAN `HEAD~1`). Ditulis **atomik bareng** `status: done` (satu operasi tulis, sejajar Atomik di atas). Bikin task→commit kebaca tanpa inferensi `git log`; `resume`/`ship` pakai buat verifikasi commit mana milik task `done` mana. `tasks.yaml` lama tanpa `commits:` → degrade (skip; perilaku resume existing tak berubah).
- Buntu beneran (bug/dead-end) → `blocked` + lapor (sandar `systematic-debugging`); attended STOP, unattended lanjut task lain — subtree nunggu (SKILL step 5, amandemen 2026-08-27). Jangan `done` palsu; **jangan auto-retry `blocked`** (risiko loop).
- **Resume (sesi baru):** baca `tasks.yaml`. (1) `done` → lewati. (2) **`in_progress` → JANGAN dilewati**: sesi lalu mati di tengah; reconcile dengan working tree + `git log` (revert/bereskan WIP setengah jadi), reset ke `pending`, lalu re-dispatch. Mode lane (§F): `in_progress` bisa JAMAK (sesi mati = semua in-flight mati bareng) — reconcile SATU-SATU per repo masing-masing; task `integration` → reconcile SEMUA repo di `deps`-nya; **≥2 `in_progress` di repo SAMA = state korup (langgar single-writer) → fail-safe: sekuensial + tanya user, JANGAN reconcile buta**. (3) `blocked` → laporkan + task yang nyangkut karena gantung ke situ; butuh reset eksplisit ke `pending` sebelum lanjut. (4) lanjut scheduler lane SKILL step 2 (READY-SET per repo; degrade monorepo = `pending` pertama yang seluruh `deps`-nya `done` — perilaku lama).
- **Status balikan subagent** (dari template implementer — beda dari `status` task di `tasks.yaml`):
  - `DONE` → verifikasi controller (commit+test) → rakit paket review (brief + report + diff via `review-package`) → dispatch task-reviewer (SKILL step 4).
  - `DONE_WITH_CONCERNS` → JANGAN langsung anggap `done`; tampilkan concern-nya, biar review/gate yang putuskan.
  - `NEEDS_CONTEXT` → kasih konteks yang diminta → re-dispatch (**bukan** `blocked`). Jawaban harus dari USER (mode lane, saat drain SKILL step 6): task jadi agenda stop — status tetap `in_progress`, re-dispatch pasca jawaban (BUKAN reset `pending`). **Unattended (amandemen 2026-08-27):** set `needs_human` + `hold: "NEEDS_CONTEXT: <pertanyaan>"` (JANGAN tinggal `in_progress`); drain pagi (§I) menjawab → re-dispatch.
  - `BLOCKED` → root-cause dulu: bug lokal → `systematic-debugging`; task salah → balik `breakdown`; kontrak salah → balik `plan`. Re-dispatch ke model sama tanpa perubahan = anti-pola.
  - Verdict reviewer `⚠️ Cannot verify from diff` → BUKAN status implementer & BUKAN lulus otomatis: controller resolve tiap item sendiri (SKILL step 4); gap nyata = spec ❌ → re-dispatch.
- **Eksekusi `actions`:** `install`/`cmd` → jalankan + verifikasi (paket/exit-code). `migrate` → **GATE**: tampilkan + **dampak (panggil `${KIMI_SKILL_DIR}/../../rules/migration-impact.md`: consumer/lock/backfill/expand-contract; advisory)** + approve sebelum apply (destruktif). **Unattended (amandemen 2026-08-27):** cabang by `migrate.kind` (SKILL step 3) — `additive` → cross-check DDL + apply otomatis bila perintahnya di-allowlist (opt-in `wire` 5.5) + impact ke scratch `gate-Gn-impact.md`; `destructive`/`backfill` (atau `kind` absen / apply tak di-allowlist) → hold `needs_human` + `commits:` + `hold:`. `env` → tulis ke `.env` app. Semua action terverifikasi = syarat `done`.
- **Proyeksi skema (M4):** sesudah task ber-`migrate` mencapai `done`, regen `control/schema/<unit>.md` per `${KIMI_SKILL_DIR}/../../rules/schema-projection.md` — **HANYA `unit` ∈ `apps[]`** (bukan package/`integration`); `label` = `feature:` (fitur) / `fix/<id>` (fix).
- **`needs_human`** = task menunggu manusia (amandemen 2026-08-27): (a) ber-`manual:` belum beres (dideteksi step 2), (b) hold non-manual ber-`hold:` (migrate destructive/backfill · allowlist migrate absen · `NEEDS_CONTEXT` · konflik pre-flight · reuse basi — §I). Attended: STOP + lapor; unattended: tandai + lanjut task lain (subtree nunggu). Resume/drain (§I): user konfirmasi/approve/jawab → jalankan `actions` terkait / re-dispatch → `in_progress` → `done`; hapus `hold:`. Hitung sebagai BELUM siap-ship.

## F. Multi-repo (probe & branch)

Probe identitas repo tiap unit NYATA (app ATAU package; resolve `path` dari `apps[]`/`packages[]`): `git -C <path> rev-parse --show-toplevel`.
- `toplevel(app) == toplevel(hub)` atau antar-app sama → **SAMA repo** (monorepo/nested) → satu branch work-item (`feature/<fitur>` atau `fix/<id>`), nanti 1 PR.
- `toplevel(app) != toplevel(hub)` → **repo TERPISAH** → branch work-item (`feature/<fitur>` atau `fix/<id>`) sendiri per repo, nanti PR sendiri.
- probe error → belum git repo → minta user `git init`/skip.

Implementer subagent commit di repo unit-nya (`git -C <path>`). `build` memastikan branch ada SEBELUM dispatch task yang nulis ke repo itu. **Pseudo-unit `integration` dilewati** saat probe/branch (tak punya `path`/repo sendiri); ia jalan di atas repo unit di `deps`-nya yang branch-nya sudah dibuat. Package mono-repo (`path = packages/<nama>`) ciut ke toplevel hub; multi-repo (`path = ../<nama>`) dapat branch+PR sendiri — sama seperti app. Eksekusi = **lane per repo** (single-writer per repo): task di repo BERBEDA boleh jalan serempak; DALAM satu repo tetap sekuensial — **maks 1 task in-flight per repo**, tak pernah dua subagent nulis tree sama serempak. Tiap lane ambil task READY paling awal urut dokumen `tasks.yaml` (scheduler: SKILL step 2). **Degrade otomatis:** semua unit satu toplevel (monorepo) → satu lane → sekuensial persis perilaku lama; ragu identitas repo (probe error/ambigu) → sekuensial + WARN; user boleh minta "sequential" kapan pun.
- **`integration` = eksklusif + quiesce (anti-starvation, anti-deadlock):** butuh SEMUA repo unit di `deps`-nya idle — **app DAN package** (package polyrepo ter-compile dari working tree-nya saat consumer boot; WIP package = roundtrip palsu). Begitu ia jadi ready-task paling awal urut dokumen untuk repo-repo target → **quiesce**: STOP dispatch baru ke lane-lane itu, tunggu in-flight kelar (status final), lalu dispatch dengan lock atomik SEMUA repo target — TANPA hold parsial (tak pernah pegang repo A sambil nunggu repo B → tak ada circular wait). ≥2 integration bersaing → urutan dokumen. Selama ia in-flight, repo target tak menerima dispatch lain.
- **Higiene hub-repo campuran** (hub memuat `control/` + sebuah app lane aktif satu toplevel): controller **tak pernah COMMIT** ke repo yang lane-nya sedang in-flight — tulis working-tree boleh (status `tasks.yaml`, proyeksi M4, `last-run.md`); commit artefak control ditunda sampai lane repo itu idle. Brief implementer menegaskan **commit HANYA file task** (per `files:`, BUKAN `git add -A`) — jaga diff review & `commits:` bersih dari tulisan controller yang belum ter-commit.

## G. Lapor-keluar / notifikasi (mode unattended — M7)

> ⛔ **Harness Kimi Code:** bagian unattended di file ini BELUM berlaku di Kimi — lihat banner di `SKILL.md` (fase 2).

Tujuan: run hands-off TAK berhenti DIAM — manusia dikabari saat dibutuhkan, bukan menunggui terminal. **Sumber kebenaran = laporan disk; notifikasi = best-effort di atasnya** (kanal tak diset / nama event hook beda antar-versi → laporan tetap ada, run tetap resumable). Nol pelonggaran gate: manusia & keputusan yang sama, cuma ditambah "telepon".

**Tiga artefak (ditulis `build`):**
1. **Penanda mode** `<root>/.claude/.unattended` — ditulis di AWAL run unattended (step 1); berarti "ada run hands-off berjalan, kabari kalau beku". Di-clear saat run ATTENDED (self-heal penanda basi dari run yang ke-abort) & dihapus hook `on-stop` saat run berhenti.
2. **Penanda stop** `<root>/.claude/.unattended-stop` — ditulis TEPAT sebelum mengakhiri turn di SETIAP titik STOP (cap-volume / tak ada task READY — antrian & blocker / abnormal / selesai — pemetaan SKILL step 1), isi = SATU baris alasan (mis. `review: 6 gate + 1 blocker — build fitur-x`). Hanya ditulis bila run mode unattended.
3. **Laporan** `<work-item>/last-run.md` — ditulis di tiap stop. **Baris pertama WAJIB header mesin** (kebaca driver outer-loop §H), lalu prosa human-readable:
   ```
   outcome: continue|review|done|halt
   done: <jumlah task done total>
   pending: <jumlah task belum done>
   review: <jumlah entri queued di gates.yaml — OPSIONAL, driver toleran absen>
   blockers: <jumlah task needs_human + blocked — OPSIONAL>
   reason: <satu baris alasan berhenti>
   ```
   Lalu prosa: task/segmen terakhir, ringkas diff, "butuh apa dari manusia" — (amandemen 2026-08-27) WAJIB memuat: daftar entri `queued` (segmen + `reason` + 1 baris ringkas diff), daftar blocker (`needs_human`/`blocked` + `hold:` disalin verbatim — pertanyaan `NEEDS_CONTEXT` ikut), daftar `auto` ringkas; sumber kebenaran tetap `gates.yaml`/`tasks.yaml` (prosa ini ditulis ulang tiap stop). Ini bahan resume + input driver outer-loop (§H). (Driver baca `outcome`+`done`; `pending`/`reason` buat notif + laporan manusia.) (Bila run unattended menyentuh area sensitif, prosa memuat banner *"DIBANGUN UNATTENDED — review security-critic wajib sebelum merge"*.)

**Nilai `outcome` (dipetakan dari alasan stop):**
- `done` — SEMUA task `done` + `gates.yaml` tanpa `queued` + 7a clear (step 7, siap-ship). Driver berhenti (sukses).
- `continue` — berhenti karena **cap-volume** (§D) tercapai, masih ada task READY. Aman di-restart proses fresh → driver lanjut (entri `queued` persisten, tak menghalangi).
- `review` — (amandemen 2026-08-27) tak ada task READY, tapi ada gate `queued` dan/atau task `needs_human`/`blocked` — nunggu keputusan manusia, TAK ada yang rusak. Driver berhenti, notif; manusia jalankan `build <fitur>` attended → drain (§I) → lalu `drive.sh` lagi.
- `halt` — HANYA **abnormal** (amandemen 2026-08-27): circuit-breaker (§D, 2 `blocked` berakar sama) / **blocker lingkungan** (allowlist kosong, permission denial tak teratasi, tak bisa tulis `tasks.yaml`/commit, env) / state korup (`in_progress` ganda satu repo, deps rujuk task tak ada). `needs_human`/`blocked` tunggal/`migrate` destructive/`risk:high` BUKAN `halt` — mereka `review` (subtree nunggu, sisanya sudah dibangun). Ada yang rusak → driver berhenti, JANGAN restart — cek `last-run.md`.

**WAJIB di mode unattended (headless `claude -p`):** JANGAN PERNAH akhiri turn dengan pertanyaan interaktif / pesan ngobrol — tak ada yang baca/jawab, dan driver cuma dapat "last-run.md tak ada". Tiap berhenti (termasuk blocker tak terduga) **emit `outcome` + `last-run.md` DULU, baru stop**. Pertanyaan di unattended TIDAK pernah ditanyakan (amandemen 2026-08-27): approval gate → entri `queued` di `gates.yaml`; approval blocker (migrate destructive/backfill, `manual:`, `NEEDS_CONTEXT`, konflik pre-flight) → `needs_human` + `hold:`; hanya pertanyaan run-mode/state pra-dispatch yang tak bisa diantrikan (mis. staleness `tasks.yaml` vs `plans/*`) → `halt` (abnormal).

**Pengiriman notif = HARNESS via hook (deterministik — jalan walau build beku/crash), BUKAN model:**
- `on-stop.sh` (hook `Stop`, ter-ship di template): tiap turn berakhir → ADA penanda stop? → panggil `notify.sh` + hapus penanda stop + matikan penanda mode. Tak ada penanda → diam (sesi biasa tak ke-spam).
- `on-permission.sh` (hook `PermissionRequest`, ter-ship): tool minta approval → penanda mode ADA? → kabari "BEKU nunggu approval" (kasus allowlist §D bocor; model tak bisa kabari diri sendiri saat beku). Tanpa penanda mode → diam. **TIDAK** auto-approve/deny — cuma kabari.

**notify.sh** (`<root>/.claude/notify.sh`) = kanal pilihan USER, diset SEKALI lewat Q&A kanal **di sesi interaktif** (`wire` 5.5 / `upgrade` / `build --unattended` interaktif) — **JANGAN di headless** (`drive.sh`/`/schedule`): di headless, absen → hook no-op + dicatat di `last-run.md`, precheck `drive.sh` yang menjaga di depan — **BUKAN di-ship plugin** (bisa memuat token/topik pribadi → wajib gitignored, di-handle `init`). Q&A: *"mau dikabarin lewat apa? (1) HP via ntfy.sh (2) notif macOS (3) Telegram (4) tak usah"* → tulis baris yang sesuai, `chmod +x`:
- ntfy: `curl -fsS -d "$1" ntfy.sh/<topik-unik-user>`
- macOS: `osascript -e "display notification \"$1\" with title \"build\""`
- Telegram: `curl -fsS "https://api.telegram.org/bot<TOKEN>/sendMessage" -d chat_id=<ID> --data-urlencode "text=$1"`
- pilihan 4 / kanal lain (Slack/Discord/email): file no-op atau user tulis satu baris `curl` sendiri.

Absen / pilihan 4 → hook jadi no-op otomatis (guard `[ -x notify.sh ]`); laporan disk tetap jalan. Generik: plugin tak mengunci satu kanal — menyediakan mekanisme + slot, user yang colok.

**Higiene kanal (ingatkan user saat Q&A):** pakai topik/channel **privat & tak-ketebak** (mis. ntfy topik dengan akhiran acak `stevanus-build-9f3a`, bukan kata umum) — pesan notif memuat ringkas alasan/tool yang beku, jadi topik publik = bocor info. Pesan sengaja ringkas (alasan + nama tool), bukan dump perintah penuh, untuk perkecil paparan.

## H. Outer-loop driver (unattended berkelanjutan lintas-sesi — M7)

Tujuan: ubah "user ngetik `build` lagi tiap sesi" jadi mesin yang muter sendiri sampai fitur kelar / butuh manusia. **Inti = sinyal `outcome` (§G); driver tinggal baca lalu putuskan lanjut/stop.** Plugin TAK bikin mesin loop sendiri — pakai yang harness/OS sudah sediakan (selaras prinsip `wire`: delegasi ke tool resmi). Dua engkol, sinyal sama:

**Fresh context: cuma dari PROSES BARU.** `claude -p` (proses baru tiap putaran) & `/schedule` (sesi cloud fresh tiap run) memberi context kosong + resume dari `tasks.yaml` (disk) — pola Ralph asli. `/loop` TIDAK (akumulatif, sesi sama) → bukan engkol untuk ini.

### Engkol 1 — bash (`drive.sh`, ter-ship di template) — grind kontinu
`bash <root>/.claude/drive.sh <fitur> [maks-jam]`. Tiap putaran: spawn `claude -p "build <fitur> --unattended" --permission-mode acceptEdits` (PROSES BARU, context fresh) → baca header `outcome`/`done` dari `last-run.md` → putuskan. **`acceptEdits` WAJIB** — auto-terima tool `Edit`/`Write` (mis. `tasks.yaml` + file kode) tanpa prompt, **sementara Bash TETAP tunduk allowlist** (push/`rm -rf` tetap diblok `deny`). Tanpa ini, headless beku di permission tool `Edit` (kasus nyata: reset status task ke-deny → build mati di task-1). Allowlist Bash WAJIB punya bentuk multi-repo `git -C <path> <subcmd>` ter-ENUMERASI per unit path (commit/checkout/dst) selain bentuk polos — bentuk wildcard-tengah `git -C * …` TAK PERNAH match (mati; matcher cuma hormati `:*` di akhir), diturunkan `wire` 5.5/`upgrade` dari `workspace.yaml`. Kalau tak ada/masih bentuk-mati, commit per-repo beku. Plus workspace WAJIB di-`trust` (precheck `drive.sh`) — kalau tidak, `permissions.allow` produk diabaikan headless. **TIGA backstop (semua deterministik, di luar model):**
- `outcome: done` → stop sukses; `outcome: review` → stop, manusia drain pagi (`build <fitur>` attended, §I) lalu jalankan `drive.sh` lagi; `outcome: halt` → stop abnormal, **JANGAN restart** — cek `last-run.md`.
- **nol-kemajuan** — `done` tak naik dari putaran sebelumnya → mandek → stop (auto-scale: 10 atau 1000 task tak masalah, yang dijaga "ada kemajuan", bukan "berapa kali").
- **deadline waktu** (`maks-jam`, default 6) → stop.

Build self-cap per putaran (cap-volume §D = **budget bobot**, default **10 poin** — bukan jumlah task; task berat ber-`mockup:`/`integration` makan jatah lebih cepat) supaya tiap proses kecil & mati sebelum context membengkak. "Budget 10" = aturan tertulis yang model hitung-sendiri-lalu-patuhi; `drive.sh` = rem keras di luar model.

### Engkol 2 — `/schedule` — batch terjadwal (overnight / lepas-laptop)
`/schedule` sebuah routine: tiap <interval> jalankan `build <fitur> --unattended`. Tiap run = sesi cloud FRESH → build self-resume dari `tasks.yaml`, kerjakan 1 batch (≤cap), tulis `outcome` + notif. Routine berulang sampai `outcome: done` (run berikutnya jadi no-op: manifest closed / tak ada `pending`) — lalu **hapus routine**. **Bedanya dari bash:** `/schedule` tak baca `outcome` untuk auto-stop (tiap run independen) → saat `outcome: review`/`halt`, run terjadwal berikutnya akan berakhir sama lagi (nol kerja, notif berulang "masih nunggu kamu") → **pause/hapus routine sampai manusia drain/beresin**. Cocok bila tak mau grind kontinu / laptop mati.

### Aturan aman (dua-duanya)
Driver menumpang floor (langkah-1 §D) + notif (§G); ia **tak pernah** melonggarkan gate. `review`/`halt` → selalu berhenti & panggil manusia; driver tak pernah auto-lewati `needs_human`/migrate destructive/Security — migrate additive auto-apply HANYA bila opt-in allowlist (`wire` 5.5). Tak ada auto-merge/auto-ship — `outcome: done` berarti "siap di-`ship`", `ship` tetap attended (jatah manusia).

## I. Antrian gate (`gates.yaml`) + drain pagi — gate ditunda (amandemen 2026-08-27)

**Wawasan:** gate step 6 memeriksa kode yang SUDAH jadi (implementer → test ijo → commit → reviewer dua-verdict → `done`); syarat task berikutnya cuma `deps` `done`, bukan "sudah di-approve manusia". Maka **persetujuan** bisa ditunda tanpa menyentuh dispatch — yang diantrikan approval-nya, bukan kodenya. Harga jujur: revisi pagi bisa merembet ke dependents (biaya token + satu malam, BUKAN biaya keamanan — tak ada yang mencapai `main` tanpa `ship`).

**Tiga kelas titik-manusia (SKILL step 6):** **A gate review (ditunda)** → entri `queued`, run lanjut · **B blocker (subtree nunggu)** → task `needs_human`/`blocked` + `hold:`, dependents otomatis tak READY, sisanya lanjut · **C auto** → entri `auto`. Run unattended berhenti hanya: tak ada task READY (`review`) / cap-volume (`continue`) / abnormal (`halt`) / selesai (`done`) — §G.

### Skema `<work-item>/gates.yaml` (penulis tunggal `build`; ke-commit bareng `control/`; HANYA work-item fitur)
```yaml
feature: fitur-x
gates:
  - id: G1                          # urut kronologis penulisan; satu segmen boleh muncul >1 kali (per due-event, mis. sesudah corrective)
    segment: web×M1                 # <unit>×<milestone> | <unit>×<milestone>/<task-id> (cadence per-task §D) | integration×<task-id> | simplify (7a)
    tasks: [T1, T2, T3]
    commits: [68fb1b5..47da07e]     # union rentang `commits:` task-task segmen (per repo; integration → per repo deps)
    status: queued                  # queued | approved | revised | auto
    reason: "floor-scan T1 (origin/redirect), T2 (session/token)"
    #   ATAU "risk:high" | "ddl additive T7 (auto-applied)" | "ddl undeclared T9 (TIDAK di-apply)"
    #   | "penyimpangan → corrective T13" | "smoke gagal: POST /login 500" | "bersih (risk:normal, floor-scan nihil)" | "debt fondasional T9: <1 baris>"
    critic: .claude/build/fitur-x/gate-G1-critic.md    # OPSIONAL — laporan security-critic (scratch)
    impact: .claude/build/fitur-x/gate-G1-impact.md    # OPSIONAL — laporan migration-impact (bila ada ddl)
    smoke: "no runnable surface"                     # OPSIONAL — ringkas observasi Part B
    queued_at: 2026-08-27           # tanggal entri ditulis (juga untuk `auto`)
    decided_at: 2026-08-28          # diisi saat drain
    decision: "approve"             # ATAU "revisi: <1 baris> → corrective T26"
  - id: G5
    segment: web×M5
    tasks: [T11, T12, T17]
    commits: [5c0b2fb..23df66d]
    status: auto                    # jejak audit; drain menampilkan ringkas, nol aksi
    reason: "bersih (risk:normal, floor-scan nihil)"
    queued_at: 2026-08-27
```
- **Atomik:** satu entri / satu flip status per operasi tulis (pola `tasks.yaml` §E). Absen → dianggap kosong; dibuat saat entri pertama. User boleh edit manual (dipercaya, pola `tasks.yaml`).
- **Higiene commit** = `tasks.yaml` (§F): jangan commit ke repo yang lane-nya in-flight.
- **Scratch** (`<root>/.claude/build/<work-item>/`, gitignored `init`): `gate-Gn-critic.md`, `gate-Gn-impact.md`. Diff segmen TIDAK bikin file baru — pakai paket `review-<base7>..<head7>.diff` per task; hilang → regenerate dari `commits:` via `git -C <path> diff <base7>..<head7>`. Critic hilang → re-run saat drain (degrade).
- **`ship`** menolak selama ada `status: queued`; body PR memuat daftar `approved` + `auto`.

### Field `hold:` di `tasks.yaml` (opsional, build-written — preseden `commits:`; BUKAN status baru)
Ditulis saat `build` men-set `needs_human` **bukan-karena-`manual:`**, satu baris self-describing & durable: `hold: "migrate destructive — nunggu approve (affects: brands.kit)"` · `hold: "allowlist migrate absen — wire 5.5"` · `hold: "NEEDS_CONTEXT: <pertanyaan implementer verbatim>"` · `hold: "konflik invariant Tenancy — query tanpa filter tenant"` · `hold: "reuse basi: users_v2 — tabel di-rename fitur lain (step 1)"`. Dihapus saat task keluar dari `needs_human`. Absen (task `manual:` / `tasks.yaml` lama) → drain derive dari bentuk task: ada `manual:` → checklist manual; ada `actions: migrate` → migrate. Prosa `last-run.md` MENYALIN `hold:` (bukan sumber kebenaran — ia ditulis ulang tiap stop).

### Drain pagi (attended) — dipicu SKILL step 1
**Pemicu:** `build <fitur>` tanpa flag DAN (`gates.yaml` punya `queued` ATAU `tasks.yaml` punya `needs_human`/`blocked`) → mode drain SEBELUM dispatch apa pun. `--unattended` → skip drain (lanjut bangun; tak ada task READY → `outcome: review`).

**Urutan sajian:**
1. **Ringkasan** dari `last-run.md` + `gates.yaml`: *"Semalam: 25 done · 6 gate queued (G1–G4, G6, G7) · 1 blocker (T7 migrate destructive) · 1 auto (web×M5)."*
2. **Re-run test sekali per repo** (baseline segar; "jangan percaya laporan") — hasil ditampilkan di tiap gate.
3. **Gate `queued` urut G-id (tertua dulu)** — revisi di G1 paling mungkin merembet ke bawah.
4. **Blocker** (`needs_human`/`blocked`) sesudahnya.
5. Daftar `auto` ringkas, nol aksi.

**Tiap gate = UX gate step 6 + bukti semalam:** header (segmen · task · commits · alasan · tanggal) · diff per task · hasil test + "dibangun vs task" · **Challenge checklist dievaluasi LIVE** (`rules/anti-yes-man.md`; tak disimpan semalam) · temuan security-critic (`critic:`; hilang → jalankan sekarang) · laporan migration-impact (`impact:`) · observasi smoke · **"Kalau direvisi, yang kena:"** = task yang dibangun *sesudah* gate ini — (a) task milik entri gate ber-G-id **lebih besar**, plus (b) task `done` yang belum masuk entri gate mana pun (segmennya belum due) — yang `files:`-nya tumpang-tindih dengan `files:` task gate ini ATAU punya jalur `deps:` (langsung/transitif) ke salah satu task gate ini (deterministik dari `gates.yaml` + `tasks.yaml`; superset — boleh over-report; under-report hanya bila `deps:` bolong (Guard Urutan-fanout, SKILL step 1); filter `files:` saja gagal karena konsumen kontrak `produces:` biasanya tak mengedit file produsennya — koreksi 2026-08-27 pasca-verifikasi) · "Coba sendiri" Part A (§D) · → **approve / revisi** — **per gate, TANPA "approve semua"** (sticky-approve dilarang M7).

**Keputusan:**
- **approve** → `status: approved` + `decided_at` + `decision: approve`.
- **revisi** → disiplin fix embed yang sama dengan penyimpangan step 6: corrective task `kind: fix` (`corrects: [T..]`, `observed: <keberatan user>`) ke **milestone yang sama** dengan segmen → segmen due lagi saat corrective `done` → entri gate baru. Gate ini → `status: revised` + `decision: "revisi: <1 baris> → corrective Tn"`.
- Sesi mati mid-drain → `build` berikutnya lanjut dari `queued` tersisa (atomik).

**Blocker per jenis** (jenis dari `hold:`; absen → derive dari bentuk task):
- `needs_human` (`manual:`) → checklist → user konfirmasi → jalankan actions → `in_progress` → `done` (existing §E).
- `needs_human` (migrate destructive/backfill) → tampilkan rencana + `migration-impact` (`rules/migration-impact.md`) → approve → apply → verifikasi → regen `control/schema/<unit>.md` → `done`. Tolak → user pilih: corrective task (ubah migrasi) ATAU balik `breakdown`.
- `needs_human` (allowlist migrate absen) → tawarkan: approve apply SEKARANG (attended — permission prompt harness jalan normal) ATAU jalankan `wire` 5.5 (opt-in) dulu supaya malam berikutnya otomatis.
- `needs_human` (`NEEDS_CONTEXT`) → tampilkan pertanyaan dari `hold:` → user jawab → re-dispatch dengan jawaban di-paste (§E) → hapus `hold:`.
- `needs_human` (konflik pre-flight) → tampilkan konflik → override sadar (reset `pending`) ATAU revisi via `breakdown`.
- `needs_human` (reuse basi) → tampilkan nama `reuse:` yang tak ada lagi di proyeksi skema/pohon unit → user pilih: perbaiki `reuse:` via `breakdown` (merge pertahankan status) ATAU override sadar (reset `pending`; brief dirakit tanpa nama basi).
- `blocked` → objeksi reviewer/error (report file + prosa) → arah user → reset eksplisit `pending` (§E; tetap TIDAK auto-retry).

**Akhir drain — STOP + ringkasan, BUKAN otomatis lanjut bangun.** Tulis ulang `last-run.md` (`outcome` `continue`/`review`/`done` + prosa "drain pagi: G1 approve, G2 revisi → T26 …"), lalu tanya SEKALI: *"lanjut attended sekarang, atau berhenti biar `drive.sh` yang lanjutin malam ini?"* — jangan kembali ke pola "harus ada manusia". Semua task `done` + antrian kosong sesudah drain → 7a (gate attended, SKILL step 7a) → `done` → *"siap di-`ship`"*.

**Kimi:** drain = attended → jalan di Kimi (state di disk); `--unattended` tetap ditolak di Kimi.
