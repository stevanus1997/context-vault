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
- **Mockup (bila task ber-`mockup:`):** baca file di path → **teks** (HTML/CSS) di-**paste VERBATIM** ke prompt; **gambar** (PNG/JPG) → sertakan path & minta subagent **membuka/melihat**-nya; **URL Figma** → fetch via Figma MCP bila tersedia, kalau tidak → perlakukan sebagai screenshot/gambar. Instruksi (**tech-agnostic**): *"Reproduksi HASIL VISUAL — layout, spacing, hierarki, dan animasi/transisi — memakai stack app (`workspace.yaml`) + komponen pada file 'Pointer pola'. JANGAN transplant markup mentah mockup; terjemahkan ke idiom komponen project. BAWA transisi/animasi yang ada di mockup — jangan dibuang sebagai dekoratif."* **Bila `control/design-system.md` ada & app dalam scope sebuah design system (cek `Berlaku buat`):** pakai **motion vocab bernama** di section `Motion`-nya untuk transisi/animasi (alih-alih nemu sendiri) — biar konsisten antar-fitur. Mockup = byte opaque user; `build` tak pernah mengasumsi framework-nya.
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
- Butuh judgment desain → model paling kuat. **Task ber-`mockup:` masuk kategori ini** — menerjemahkan mockup (yang teknologinya bisa ≠ stack project) ke komponen existing tanpa transplant markup butuh judgment desain.

## D. Cadence gate (mode A adaptif)
- **Default:** gate per **app × milestone** — semua task satu unit (app/pkg) dalam satu milestone hijau → BERHENTI, tampilkan diff + test + "dibangun vs task" + challenge checklist → approve/revisi.
- **Lebih rapat:** app pemegang kontrak `_shared.md` / ditandai berisiko (milestone fondasi) → checkpoint per-task.
- **Lebih longgar:** milestone bermotif mapan (OAuth provider ke-2/ke-3) → gabung gate.
- **Fitur 1-app** → ciut jadi 1 gate.
- **`--unattended` (opt-in, fitur saja — M7):** segmen ber-tier `risk` `low`/`normal` yang ijo + tak-menyimpang → auto-approve (lanjut tanpa stop). HARD floor tetap STOP: `risk: high` / `migrate` / `needs_human` / `blocked` / penyimpangan. Melonggarkan cadence ini, BUKAN menambah gate; tak menyentuh Security Gate `ship`. Default (tanpa flag) = stop tiap segmen. **Floor-scan diff (M7-amend 2026-06-18):** jaring deterministik tak-bergantung tag `risk` — grep diff tiap segmen untuk verba bahaya (*Verba-keamanan* + *Verba-uang PLUMBING* `tweak/reference.md` §A) + DDL migrasi; kena → STOP attended. Degrade: `risk` absen + `sensitivity:[payments]` → diperlakukan `high`.
  - **Prasyarat harness (cek di awal run, step 1):** `permissions.allow` di `<produk>/.claude/settings.json` memuat perintah verifikasi stack unit yang kena (diisi `wire` 5.5). Kosong/kurang → WARN sebelum mulai: run bakal nyangkut di permission prompt harness (satpam yang tak dirancang), bukan di gate plugin — tawarkan jalan attended atau lengkapi allowlist dulu (`wire` repair).
  - **Rem run-level (wajib saat unattended):** (a) **circuit breaker** — 2 task berturut-turut berakhir `blocked`/gagal dengan akar serupa → STOP SELURUH run + lapor "dugaan masalah sistemik" (1 penyebab ≠ N bug; jangan giling task berikutnya, bakar token percuma); (b) **cap volume (budget bobot)** — BUKAN hitung jumlah task (10 task enteng ≠ 10 task berat ber-token); tiap task punya **bobot**, dan satu run berhenti **sebelum** mulai task yang bakal bikin total bobot **lewat budget** (default **10**) — jadi total bobot per run selalu **≤ budget**. **Bobot per task** diturunkan dari field `tasks.yaml` yang SUDAH ADA (tak perlu — & tak bisa — ukur token dari dalam): **3 (berat)** bila ber-`mockup:` ATAU `unit: integration` ATAU `files` > 4; **2 (sedang)** bila `files` 3–4; **1 (enteng)** selainnya. **Aturan stop (look-ahead):** sebelum dispatch tiap task, hitung `total_berjalan + bobot(task)`; bila `> budget` DAN sudah ≥1 task jalan di run ini → STOP + ringkasan run + sisa antrian. **Task PERTAMA tiap run SELALU jalan** (jamin minimal 1 task/run, biar 1 task super-berat tak ke-block selamanya). User boleh set budget lain saat memanggil. Efek: task berat "makan jatah" lebih cepat → proses tetap ramping (cegah 1 proses gendut sampai context membengkak). **`breakdown` TAK berubah** — bobot dihitung di build dari field yang sudah ada. Rem ini level-RUN — melengkapi cap 3-ronde review yang levelnya per-task (SKILL step 4), bukan menggantikannya.
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
- **Eksekusi `actions`:** `install`/`cmd` → jalankan + verifikasi (paket/exit-code). `migrate` → **GATE**: tampilkan + **dampak (panggil `${CLAUDE_PLUGIN_ROOT}/rules/migration-impact.md`: consumer/lock/backfill/expand-contract; advisory)** + approve sebelum apply (destruktif). `env` → tulis ke `.env` app. Semua action terverifikasi = syarat `done`.
- **Proyeksi skema (M4):** sesudah task ber-`migrate` mencapai `done`, regen `control/schema/<unit>.md` per `${CLAUDE_PLUGIN_ROOT}/rules/schema-projection.md` — **HANYA `unit` ∈ `apps[]`** (bukan package/`integration`); `label` = `feature:` (fitur) / `fix/<id>` (fix).
- **`needs_human`** (task ber-`manual:` belum beres): dideteksi di step 2 → STOP seluruh build, lapor checklist; resume setelah user konfirmasi langkah manual beres → jalankan `actions` terkait → `in_progress`. Hitung sebagai BELUM siap-ship.

## F. Multi-repo (probe & branch)

Probe identitas repo tiap unit NYATA (app ATAU package; resolve `path` dari `apps[]`/`packages[]`): `git -C <path> rev-parse --show-toplevel`.
- `toplevel(app) == toplevel(hub)` atau antar-app sama → **SAMA repo** (monorepo/nested) → satu branch work-item (`feature/<fitur>` atau `fix/<id>`), nanti 1 PR.
- `toplevel(app) != toplevel(hub)` → **repo TERPISAH** → branch work-item (`feature/<fitur>` atau `fix/<id>`) sendiri per repo, nanti PR sendiri.
- probe error → belum git repo → minta user `git init`/skip.

Implementer subagent commit di repo unit-nya (`git -C <path>`). `build` memastikan branch ada SEBELUM dispatch task yang nulis ke repo itu. **Pseudo-unit `integration` dilewati** saat probe/branch (tak punya `path`/repo sendiri); ia jalan di atas repo unit di `deps`-nya yang branch-nya sudah dibuat. Package mono-repo (`path = packages/<nama>`) ciut ke toplevel hub; multi-repo (`path = ../<nama>`) dapat branch+PR sendiri — sama seperti app. Eksekusi tetap sekuensial sesuai `deps` (tak ada dua subagent nulis tree sama serempak).

## G. Lapor-keluar / notifikasi (mode unattended — M7)

Tujuan: run hands-off TAK berhenti DIAM — manusia dikabari saat dibutuhkan, bukan menunggui terminal. **Sumber kebenaran = laporan disk; notifikasi = best-effort di atasnya** (kanal tak diset / nama event hook beda antar-versi → laporan tetap ada, run tetap resumable). Nol pelonggaran gate: manusia & keputusan yang sama, cuma ditambah "telepon".

**Tiga artefak (ditulis `build`):**
1. **Penanda mode** `<root>/.claude/.unattended` — ditulis di AWAL run unattended (step 1); berarti "ada run hands-off berjalan, kabari kalau beku". Di-clear saat run ATTENDED (self-heal penanda basi dari run yang ke-abort) & dihapus hook `on-stop` saat run berhenti.
2. **Penanda stop** `<root>/.claude/.unattended-stop` — ditulis TEPAT sebelum mengakhiri turn di SETIAP titik STOP (`needs_human` step 2 / `blocked` step 5 / circuit-breaker & cap-volume & gate step 6 / selesai step 7), isi = SATU baris alasan. Hanya ditulis bila run mode unattended.
3. **Laporan** `<work-item>/last-run.md` — ditulis di tiap stop. **Baris pertama WAJIB header mesin** (kebaca driver outer-loop §H), lalu prosa human-readable:
   ```
   outcome: continue|done|halt
   done: <jumlah task done total>
   pending: <jumlah task belum done>
   reason: <satu baris alasan berhenti>
   ```
   Lalu prosa: task/segmen terakhir, ringkas diff, "butuh apa dari manusia". Ini bahan resume + input driver outer-loop (§H). (Driver baca `outcome`+`done`; `pending`/`reason` buat notif + laporan manusia.)

**Nilai `outcome` (dipetakan dari alasan stop):**
- `done` — SEMUA task `done` (step 7, siap-ship). Driver berhenti (sukses).
- `continue` — berhenti karena **cap-volume** (§D) tercapai, masih ada `pending`, TAK ada floor. Aman di-restart proses fresh → driver lanjut.
- `halt` — kena **FLOOR atau BLOCKER**: `needs_human` (step 2) / `blocked` (step 5) / circuit-breaker (§D) / gate `migrate` / Security Gate / **blocker lingkungan** (permission denial tak teratasi, tak bisa tulis `tasks.yaml`/commit) / **`risk: high` saat unattended** (auto-approve tak pernah nyala → emit `halt` DINI ronde-1; reason **membedakan**: floor-scan/verba-bahaya = `"risk:high (berbahaya: <verba>) butuh attended"` vs `risk` di-set manual = `"risk:high (di-set) — turunkan feature.yaml atau jalankan attended"`). Butuh manusia → driver berhenti, JANGAN restart.

**WAJIB di mode unattended (headless `claude -p`):** JANGAN PERNAH akhiri turn dengan pertanyaan interaktif / pesan ngobrol — tak ada yang baca/jawab, dan driver cuma dapat "last-run.md tak ada". Tiap berhenti (termasuk blocker tak terduga) **emit `outcome` + `last-run.md` DULU, baru stop**. Pertanyaan run-mode/approval di unattended = otomatis `halt` (bukan ditanyakan).

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
`bash <root>/.claude/drive.sh <fitur> [maks-jam]`. Tiap putaran: spawn `claude -p "build <fitur> --unattended" --permission-mode acceptEdits` (PROSES BARU, context fresh) → baca header `outcome`/`done` dari `last-run.md` → putuskan. **`acceptEdits` WAJIB** — auto-terima tool `Edit`/`Write` (mis. `tasks.yaml` + file kode) tanpa prompt, **sementara Bash TETAP tunduk allowlist** (push/`rm -rf` tetap diblok `deny`). Tanpa ini, headless beku di permission tool `Edit` (kasus nyata: reset status task ke-deny → build mati di task-1). Allowlist Bash WAJIB punya bentuk multi-repo `git -C * <subcmd>` (commit/checkout/dst) selain bentuk polos — kalau tidak, commit per-repo beku. **TIGA backstop (semua deterministik, di luar model):**
- `outcome: done` → stop sukses; `outcome: halt` → stop, **JANGAN restart** (floor = tembok).
- **nol-kemajuan** — `done` tak naik dari putaran sebelumnya → mandek → stop (auto-scale: 10 atau 1000 task tak masalah, yang dijaga "ada kemajuan", bukan "berapa kali").
- **deadline waktu** (`maks-jam`, default 6) → stop.

Build self-cap per putaran (cap-volume §D = **budget bobot**, default **10 poin** — bukan jumlah task; task berat ber-`mockup:`/`integration` makan jatah lebih cepat) supaya tiap proses kecil & mati sebelum context membengkak. "Budget 10" = aturan tertulis yang model hitung-sendiri-lalu-patuhi; `drive.sh` = rem keras di luar model.

### Engkol 2 — `/schedule` — batch terjadwal (overnight / lepas-laptop)
`/schedule` sebuah routine: tiap <interval> jalankan `build <fitur> --unattended`. Tiap run = sesi cloud FRESH → build self-resume dari `tasks.yaml`, kerjakan 1 batch (≤cap), tulis `outcome` + notif. Routine berulang sampai `outcome: done` (run berikutnya jadi no-op: manifest closed / tak ada `pending`) — lalu **hapus routine**. **Bedanya dari bash:** `/schedule` tak baca `outcome` untuk auto-stop (tiap run independen) → saat `outcome: halt`, run terjadwal berikutnya akan halt lagi (notif berulang "masih nunggu kamu") → **pause/hapus routine sampai manusia beresin**. Cocok bila tak mau grind kontinu / laptop mati.

### Aturan aman (dua-duanya)
Driver menumpang floor (langkah-1 §D) + notif (§G); ia **tak pernah** melonggarkan gate. `halt` → selalu berhenti & panggil manusia, tak pernah auto-lewati `needs_human`/`migrate`/Security. Tak ada auto-merge/auto-ship — `outcome: done` berarti "siap di-`ship`", `ship` tetap attended (jatah manusia).
