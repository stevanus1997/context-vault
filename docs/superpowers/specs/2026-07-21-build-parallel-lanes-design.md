# Design — Eksekusi Paralel Lintas-Repo di `build` (lane per repo, gate berhenti-bareng)

- **Tanggal:** 2026-07-21
- **Status:** Draft v2 (pasca red-team 3 critic independen — 10 temuan high/medium ditutup) — nunggu approve
- **Area kena:** `plugin/skills/build/SKILL.md` (step 1, 2, 3, 5, 6), `plugin/skills/build/reference.md` (§B, §D, §E, §F). **`breakdown`/`fanout`/`ship`/`tweak` TIDAK disentuh**; `fix` keikut gratis (pinjam mesin `build`).

---

## 1. Konteks & Masalah

`build` sekarang **sekuensial murni**: step 2 ambil task `pending` PERTAMA yang deps-nya `done`, satu implementer pada satu waktu (`build/SKILL.md:24`); `reference.md` §F menegaskan *"eksekusi tetap sekuensial sesuai `deps` (tak ada dua subagent nulis tree sama serempak)"*. Ini keputusan sadar (spec `2026-05-29-breakdown-build-execution-phase-design.md`: worktree/paralel = future §16).

Alasan aslinya = **single-writer per tree**: seluruh akuntansi build bertumpu pada "satu penulis per repo pada satu waktu" — base-SHA direkam sebelum dispatch (step 3), verifikasi "HEAD maju dari base" + paket review `base..head` + `commits:` (step 4/5), dan verifikasi no-op fan-in ("HEAD **TIDAK** maju" = bukti no-op). Dua penulis di repo yang sama → semua akuntansi itu bubar.

**Observasi kunci: alasan itu TIDAK berlaku lintas-repo.** Dua ready-task yang hidup di repo BERBEDA (polyrepo: `api` repo A, `web` repo B) tak mungkin nulis tree yang sama; akuntansi per-repo tetap utuh asal tiap repo tetap single-writer. Probe identitas repo (`git -C <path> rev-parse --show-toplevel`) sudah ada di §F.

Payoff nyata: (a) produk polyrepo multi-app; (b) fan-in cheap-skip pasca package `BREAKING` (N consumer-task ready & independen serentak); (c) mode `--unattended` — lane bisa grind kontinu tanpa jeda manusia.

## 2. Tujuan & Non-Tujuan

**Tujuan**
- Ready-task di **repo berbeda** jalan serempak — **lane per repo, maks 1 task in-flight per repo**.
- **Degrade otomatis**: monorepo / 1 repo → perilaku sekarang PERSIS (tanpa flag, tanpa jalur kode beda).
- Semua invariant akuntansi existing utuh: base-SHA per repo, review dua-verdict per task, `commits:`, no-op fan-in, floor-scan, cadence gate per app × milestone.

**Non-Tujuan (YAGNI)**
- **Tidak** ada paralel DALAM satu repo (worktree per task = Tier 2, future terpisah — merge-back + env contention belum kebayar).
- **Tidak** mengubah `breakdown` / skema `tasks.yaml` — `deps` tetap sumber kebenaran urutan lintas-lane (di-backstop guard D13 untuk tasks.yaml legacy yang deps lintas-app-nya bolong).
- **Tidak** menambah kosakata `status` baru di `tasks.yaml` (usul "parked" ditolak — lihat §8).
- **Tidak** mengubah semantik gate (tetap per app × milestone, checklist sama) selain aturan **drain** (D5).
- **Tidak** ada gate antri / lane jalan terus saat manusia mikir (opsi canggih — ditolak, lihat §8).
- **Tidak** mengubah `ship` / simplify pass 7a (tetap one-shot sesudah semua `done`).

## 3. Keputusan Desain

| # | Keputusan |
|---|---|
| **D1** | **Lane per repo, single-writer per repo, urutan pemrosesan atomik.** Step 2 berubah: dari "ambil `pending` pertama yang deps `done`" → "hitung **READY-SET** (SEMUA `pending` yang seluruh `deps`-nya `done`), kelompokkan per identitas repo (toplevel §F, sudah diprobe step 1), dispatch dengan aturan keras: **maks 1 task in-flight per repo**". Tiap lane mengambil **task READY paling awal urut dokumen** `tasks.yaml` (BUKAN menunggu task dokumen-pertama lane yang belum ready — semantik sama dengan sekuensial existing yang juga melewati task belum-ready). Lifecycle per task TIDAK berubah: dispatch → implement → verify → review dua-verdict → `done` → baru scheduler tick berikutnya. **Urutan pemrosesan tiap completion WAJIB atomik: (1) proses completion (verify + review + tulis status) → (2) evaluasi SEMUA gate/floor/titik-manusia yang jadi due — ada yang due (attended) → langsung set STOP-dispatch (D5) → (3) BARU scheduler tick (dispatch ready-task baru).** Jadi task yang baru ready TEPAT pada completion yang memicu gate tak akan pernah ter-dispatch sebelum gate resolved — tak ada yang membangun di atas kontrak yang mungkin direvisi. |
| **D2** | **Degrade otomatis, tanpa flag; fail-safe = sekuensial.** Paralel nyala HANYA bila ready-set memuat ≥2 task di repo berbeda; semua unit satu toplevel (monorepo) → satu lane → identik perilaku sekarang. **Ragu → sekuensial + WARN**, untuk SEMUA kasus ragu: probe toplevel error / identitas repo ambigu / ≥2 `in_progress` di repo SAMA saat recovery (state korup — D7) / primitive dispatch-background tak tersedia (D12). User bisa minta eksplisit "sequential" kapan pun. |
| **D3** | **Akuntansi per task nol perubahan + higiene hub-repo campuran.** Base-SHA tetap direkam per repo saat dispatch task itu (step 3 existing). Karena single-writer per repo: "HEAD maju dari base", paket review `base..head`, `commits: [base7..head7]`, dan verifikasi no-op fan-in tetap deterministik. `tasks.yaml` tetap ditulis SATU penulis (controller). **Higiene hub-repo campuran** (hub repo memuat `control/` DAN sebuah app lane aktif, mis. `apps/api` + `control/` satu toplevel): (a) controller **tak pernah COMMIT** ke repo yang lane-nya sedang in-flight (tulis working-tree boleh — flip status `tasks.yaml`, proyeksi M4, `last-run.md`; commit artefak control ditunda sampai lane repo itu idle); (b) brief implementer menegaskan **commit HANYA file task-nya** (per `files:`, bukan `git add -A` dari root) — supaya tulisan controller yang belum ter-commit tak tersapu ke commit task & memolusi diff review / `commits:`. |
| **D4** | **Task `unit: integration` = eksklusif + reservasi quiesce (anti-starvation, anti-deadlock).** Ia mem-boot app NYATA di `deps`-nya → butuh SEMUA repo unit terkait idle. **Repo yang di-lock = repo SEMUA unit di `deps`-nya, app DAN package** (package polyrepo ter-compile dari working tree-nya saat consumer boot — WIP package = roundtrip palsu). Protokol: begitu task integration jadi **ready-task paling awal urut dokumen** untuk repo-repo target-nya → **quiesce**: STOP dispatch baru ke lane-lane itu, tunggu in-flight mereka kelar (status final), lalu dispatch integration dengan lock atomik atas semua repo target (TANPA hold parsial — tak pernah pegang repo A sambil menunggu repo B, jadi tak ada circular wait). ≥2 integration bersaing → urutan dokumen `tasks.yaml` (tie-break D1). Selama integration in-flight, repo-repo target tak menerima dispatch lain. |
| **D5** | **Gate & semua titik-butuh-manusia = BERHENTI-BARENG (drain lalu tanya) — attended.** Trigger: gate segmen due, `needs_human` (step 2), `blocked` (step 5), approve `migrate` (step 3), floor-scan kena, subagent balik-nanya yang jawabannya harus dari user. Controller: (1) **STOP dispatch baru di SEMUA lane** (per urutan atomik D1, ini terjadi SEBELUM scheduler tick — task yang baru ready tak ter-dispatch); (2) **DRAIN** — tunggu task yang sudah in-flight SEBELUM titik-manusia terdeteksi sampai status final (verify + review + tulis status). **Drain = menunggu in-flight LAIN; task PEMICU sendiri TIDAK ditunggu** — ia berhenti di state menunggu-keputusan (status tetap `in_progress`; TANPA kosakata status baru) dan keputusannya jadi agenda stop, bukan bagian drain (hindari tunggu-melingkar: approve migrate / jawaban NEEDS_CONTEXT adalah prasyarat task itu final). Task drain yang di tengah drain ikut mentok titik-manusia → sama: berhenti menunggu-keputusan, itemnya masuk agenda stop yang sama; (3) sajikan SEMUA agenda dalam **SATU pemberhentian** (bisa >1 gate bila drain membuat segmen lain ikut kelar; task drain yang berakhir `blocked` ikut dilaporkan); (4) sesudah keputusan → jawaban NEEDS_CONTEXT di-re-dispatch (jalur §E existing, bukan reset `pending`), lalu resume dispatch paralel. Sesi mati DI stop → recovery D7 existing (reconcile → reset `pending`) — dapat diterima, bukan jalur baru. |
| **D6** | **Unattended: auto-approve TANPA drain + guard smoke + presedensi outcome.** Gate segmen yang lolos auto-approve (fitur `risk` low/normal + ijo + tak menyimpang + lolos floor-scan — kriteria M7 existing) TIDAK menghentikan lane lain. **Guard smoke lintas-app:** smoke Part B gagal SEMENTARA ada lane lain in-flight yang runtime/DB-nya bisa terpanggil oleh app yang di-boot → **JANGAN langsung nyatakan penyimpangan** (bisa 5xx dari WIP repo sebelah — HARD floor palsu + corrective task fiktif): tunggu/drain repo terkait idle → re-run smoke SEKALI → tetap gagal → baru penyimpangan (jalur existing). (Attended aman by construction: gate dievaluasi pasca drain D5 — semua lane idle.) **Titik STOP beneran** (`halt`/floor/cap/circuit-breaker) → drain per D5, lalu emit `outcome` + `last-run.md` SEKALI. **Presedensi outcome saat sebab campur (hasil drain): `halt` > `continue` > `done`** — task `blocked` hasil drain SELALU memaksa `halt` (jangan sampai `continue` bikin driver restart & blocked terkubur); `reason:` = sebab prioritas tertinggi (floor > blocked > lainnya) + "(+N isu lain, lihat prosa)"; prosa per lane. Segmen lain yang kelar DI TENGAH drain-halt & lolos kriteria auto-approve → tetap di-approve + dicatat (stop-nya disebabkan hal lain). Start run dengan `blocked` sudah di `tasks.yaml` → paritas sekuensial existing (§E: laporkan + lanjut lane lain); bila TAK ada ready-task di luar subtree blocked → `halt` dini. Kontrak header §G & driver §H tak berubah. |
| **D7** | **Recovery multi-`in_progress`.** Step 1: `in_progress` kini bisa JAMAK (sesi mati saat paralel — semua in-flight mati bareng). Reconcile SATU-SATU dengan working tree + `git log` repo masing-masing (mekanisme existing per task), reset ke `pending`. **Task `integration` in-progress → reconcile terhadap SEMUA repo di `deps`-nya** (bukan satu repo). **≥2 `in_progress` di repo yang SAMA = state korup** (melanggar single-writer) → JANGAN reconcile buta: fail-safe D2 (sekuensial + tanya user). Makna `in_progress` tak berubah: "ada dispatch yang belum tuntas". |
| **D8** | **Signature-dep lintas-lane: baca dari BASE-SHA task in-flight repo dep — bukan head task dep, bukan tree sibuk.** Brief step 3 membaca file dep dari disk. Bahaya paralel: repo pemilik dep sedang punya in-flight lain → disk bisa memuat WIP. **Sumber yang benar saat repo dep sibuk = BASE-SHA yang DIREKAM untuk task in-flight repo itu** (step 3 per D3 — selalu ada, tanpa bergantung field `commits:`): itu persis state committed + ter-review penuh terakhir, MENCAKUP SEMUA task done (termasuk task done belakangan yang mengubah file dep — head task dep sendiri bisa BASI kalau file-nya sudah di-refactor task done berikutnya; dua critic independen menemukan bug ini di draft v1). Repo dep idle → baca disk seperti biasa (existing). **Bentuk perintah WAJIB match allowlist `wire` 5.5:** `git -C <path-unit-workspace> show <base7>:./<file>` — `-C` pakai path unit LITERAL dari `workspace.yaml` (bukan toplevel hasil rev-parse — prefix literal allowlist tak match) dan `./<file>` relatif cwd `-C` (tanpa `./`, `git show` me-resolve path relatif toplevel → salah di monorepo). Tak butuh perubahan `wire` (bentuk `git -C <P> show:*` sudah dienumerasi 5.5). |
| **D9** | **Rem run-level (unattended) — redefinisi minimal.** (a) **Blocked & circuit breaker:** `blocked` PERTAMA tetap memicu drain + `halt` (existing §G — tak berubah); bila DRAIN menghasilkan `blocked` TAMBAHAN ber-akar-serupa → `reason` = "dugaan sistemik" (fungsi breaker = memperkaya diagnosis + tegaskan jangan-restart; definisi "berturut kronologis lintas-lane" DITOLAK — race-dependent & bisa gagal trip saat interleaving). (b) **Cap volume (budget bobot):** cek look-ahead tetap SAAT dispatch — controller satu proses, dispatch satu-per-satu walau eksekusi paralel; bobot dihitung atas semua task yang sudah di-dispatch run ini (termasuk in-flight). Lewat budget → stop dispatch baru → drain → `outcome: continue` (kecuali drain menghasilkan floor/blocked → presedensi D6). **Garansi "task PERTAMA tiap run SELALU jalan": "pertama" = ready-task paling awal urut dokumen LINTAS-lane** — dispatch pertama run bebas cek budget (generalisasi setia aturan existing; task berat yang urutan dokumennya belakangan menunggu gilirannya persis seperti di sekuensial — bukan regresi). (c) `drive.sh`/outer-loop §H **nol perubahan** (cuma baca `outcome`). |
| **D10** | **Artefak scratch bebas kolisi by construction.** Brief/report bernama per task (`task-<id>-*.md`); paket diff bernama per-range per repo (`review-<base7>..<head7>.diff`); proyeksi skema (M4) & `tasks.yaml` ditulis controller (satu proses, satu penulis; higiene commit hub-repo → D3). Nol perubahan penamaan. |
| **D11** | **`fix` keikut gratis; `tweak` tak tersentuh.** Work-item fix pinjam mesin `build` → dapat aturan lane otomatis; praktisnya fix sering 1 repo → degrade sekuensial (D2). `tweak` inline single-session, bukan mesin build — nol perubahan. |
| **D12** | **Mekanisme dispatch dikunci: subagent BACKGROUND, controller satu turn.** Paralel mensyaratkan primitive **dispatch subagent background** (implementer/reviewer jalan di belakang; controller menerima completion satu-per-satu dan memproses per urutan atomik D1). Controller **TIDAK mengakhiri turn selagi ada in-flight** (headless `claude -p`: akhir turn = proses exit = in-flight mati → residu multi-`in_progress` tiap putaran driver); menunggu = poll/tunggu dalam turn yang sama. Reviewer task lane A boleh jalan bareng implementer lane B (keduanya subagent background; lifecycle DALAM satu lane tetap serial per D1). **Degrade (konsisten D2):** primitive background tak tersedia / ragu → model ronde-barrier (dispatch batch paralel satu pesan, proses semua hasil, ronde berikutnya — throughput lebih rendah, correctness sama; tie completion dalam satu ronde → urutan dokumen) ATAU sekuensial penuh + WARN. Narasi "grind kontinu tanpa jeda" (§1 payoff c) berlaku penuh HANYA pada mode background. |
| **D13** | **Guard Urutan-fanout (tasks.yaml legacy / deps lintas-app bolong).** `breakdown` memang meng-encode Urutan `fanout.md` ke `deps` — tapi tak ada palang yang memvalidasinya, dan di era sekuensial deps lintas-app yang bolong TERTUTUPI urutan dokumen (hulu selalu duluan). Sebelum paralel nyala (sekali, step 1): cross-check Urutan `fanout.md` — ada ready-task di repo HILIR yang TIDAK punya jalur `deps` ke task mana pun repo HULU, SEMENTARA repo hulu masih punya `pending`/in-flight → **tahan dispatch lintas-repo task itu + WARN** ("deps lintas-app mungkin bolong — cek `breakdown`"); user bisa override atau jalankan sekuensial (D2). Fitur tanpa `fanout.md` (1-app) / Urutan kosong → guard no-op. |

## 4. Arsitektur / Alur

```
step 2' (scheduler lane; SEMUA pemrosesan atomik per completion — D1):
  READY-SET = semua pending yang deps-nya done
  quiesce-set = repo target task integration yang jadi ready-task
                paling awal urut dokumen untuk repo-repo itu (D4)
  guard D13: ready-task hilir tanpa jalur deps ke hulu ber-pending → tahan + WARN

  saat completion sebuah task masuk:
    1. proses: verify (HEAD maju + re-run test) → review dua-verdict → tulis status
    2. evaluasi gate/floor/titik-manusia yang due:
         attended  → set STOP-dispatch semua lane → DRAIN (in-flight lain sampai
                     status final; task pemicu = agenda, bukan ditunggu — D5)
                     → sajikan SEMUA agenda dalam SATU stop → keputusan → resume
         unattended + lolos auto-approve → catat, lane lain TIDAK berhenti (D6;
                     smoke-fail saat lane lain in-flight → guard re-run dulu)
         unattended + floor/blocked/cap → drain → outcome (presedensi D6) + last-run
    3. scheduler tick: per lane idle (di luar quiesce & stop-dispatch) →
         dispatch task ready paling awal urut dokumen lane itu
         (unit: integration → tunggu quiesce beres → lock atomik semua repo target)

  semua done → hard-guard step 7 → simplify 7a (tak berubah, one-shot)
```

## 5. Contoh Konkret — fitur `auth`, polyrepo (`api` repo A, `web` repo B)

Task: T1 hash, T2 session, T3 register, T4 login (semua api; T3/T4 deps T1+T2); W0 skeleton layout web (web, TANPA deps ke api), W1 form login (web, deps T4).

```
SEKARANG (sekuensial):
  T1 → T2 → T3 → T4 → [gate api×M1..M2] → W0 → W1 → [gate web]

SESUDAH (lane per repo):
  lane api : T1 → T2 → T3 → T4
  lane web : W0 ──────────────┐        (W0 independen — jalan dari menit-0)
                              │
  completion T4 masuk (D1 atomik):
    1. verify+review T4 → done
    2. gate api×M2 due (attended) → STOP-dispatch semua lane
       → DRAIN: W0 (in-flight SEBELUM gate due) diselesaikan sampai status final
       → W1 (baru ready TEPAT karena T4 done) TIDAK PERNAH ter-dispatch —
         ia menunggu keputusan gate (kontrak T4 bisa direvisi)
    3. sajikan gate api (+ hasil W0 bila segmennya ikut kelar) dalam SATU stop
       → approve → resume: lane web dispatch W1
  unattended (risk normal): gate api auto-approve → lane web TIDAK berhenti
```

Fan-in pasca package `BREAKING` (polyrepo): task update consumer `app-a`/`app-b`/`app-c` ready serentak → tiga lane jalan bareng; verifikasi no-op fan-in per repo tetap deterministik (D3).

## 6. File yang Disentuh (edit-map)

- **`plugin/skills/build/SKILL.md`**
  - **step 1** — recovery jamak D7 (+ integration lintas-repo, same-repo dobel → fail-safe), fail-safe probe D2, guard fanout D13 (sekali di awal, sebelah pre-flight sweep).
  - **step 2** — scheduler ready-set + aturan lane + urutan pemrosesan atomik (D1), quiesce integration (D4).
  - **step 3** — dispatch background (D12), signature-dep lintas-lane (D8), brief: commit hanya file task (D3).
  - **step 5** — `blocked` → trigger drain D5 (BUKAN cuma wording: "STOP, laporkan" → "STOP-dispatch semua lane → drain → lapor agenda bareng").
  - **step 6** — drain attended D5; unattended D6 (guard smoke, presedensi outcome).
  - step 4 — wording jamak saja (verifikasi per task tak berubah).
- **`plugin/skills/build/reference.md`**
  - **§B** — klausa "Signature dep: baca file di disk" → + aturan repo-sibuk baca `git -C <path-unit> show <base7-inflight>:./<file>` (D8).
  - **§D** — rem run-level (D9), klausa "Selalu hormati `deps` + Urutan `fanout`" dirumuskan ulang: "Urutan fanout ter-encode sebagai `deps` oleh `breakdown`; scheduler lane menghormatinya via `deps` + guard cross-check D13".
  - **§E** — resume jamak (D7), item (4) "lanjut `pending` pertama" → rujuk scheduler ready-set (D1), status balikan NEEDS_CONTEXT saat drain (D5).
  - **§F** — ganti kalimat "eksekusi tetap sekuensial" → aturan lane + eksklusivitas & quiesce `integration` (D4) + higiene hub-repo (D3).
- **`docs/superpowers/specs/2026-05-29-breakdown-build-execution-phase-design.md`** — TIDAK diedit (dokumen historis); future item §16 "paralel" terealisasi sebagian oleh spec ini.

## 7. Risiko & Mitigasi

- **`deps` lintas-app under-specified di tasks.yaml legacy** → ditutup guard D13 (deteksi dini deterministik + WARN), bukan lagi cuma deteksi post-hoc "gejala aneh → sequential".
- **Konduktor makin kompleks** (juggling beberapa completion). Mitigasi: urutan pemrosesan atomik D1 (satu completion diproses tuntas sebelum tick); lebar paralel dibatasi alami jumlah repo (praktisnya 2–4 lane); drain D5 menjaga "satu sesi keputusan pada satu waktu"; fail-safe sekuensial menyeluruh (D2).
- **Shared dev-DB / runtime lintas-app** → test/smoke dua lane saling ganggu. Mitigasi: `wire` umumnya DB per app; smoke → guard re-run D6; roundtrip → lock integration D4; gejala flaky menetap → sequential (D2). Tak ada mesin deteksi baru (YAGNI).
- **Brief membaca state salah lintas-lane** → ditutup D8 (base-SHA in-flight; bukan head-dep yang bisa basi, bukan tree WIP).
- **Headless beku di permission** → bentuk perintah D8 match allowlist `wire` 5.5 (fakta terverifikasi: `git -C <P> show:*` sudah dienumerasi); controller tak pernah end-turn selagi in-flight (D12).
- **`last-run.md` membingungkan saat multi-lane** → header mesin tunggal + presedensi outcome & reason (D6), prosa per lane.

## 8. Alternatif Ditolak

- **Opsi canggih (lane jalan terus saat gate nunggu manusia; gate antri).** Ditolak: keputusan gate bisa berupa revisi kontrak → kerjaan lane lain yang jalan duluan jadi basi/bongkar; chat interleave bikin sesi rawan; resume state campur-aduk. Future bila terbukti perlu — D5 (drain) fondasi yang kompatibel ke arah itu.
- **Worktree per task dalam satu repo (Tier 2).** Ditolak sekarang: merge-back N branch = serial + konflik; worktree tak mengisolasi env (port/DB). Future terpisah, prasyarat `files:` disjoint-check.
- **Flag opt-in `--parallel`.** Ditolak: degrade otomatis (D2) membuat flag redundan — monorepo tak terpengaruh sama sekali, polyrepo dapat perilaku baru dengan invariant sama; fail-safe "ragu → sekuensial" + escape "sequential" cukup. (Beda dari `--unattended` yang opt-in karena MELONGGARKAN gate manusia; ini tidak menyentuh gate.)
- **Status baru "parked" untuk task pemicu yang menunggu keputusan.** Ditolak: nambah kosakata status = sentuh kontrak `tasks.yaml` lintas-skill (breakdown/resume/ship); `in_progress` + agenda stop (D5) cukup, dan sesi-mati-di-stop jatuh ke recovery existing.
- **Signature-dep dari head commit task dep (`commits:`) — draft v1.** Ditolak pasca red-team: head task dep bisa BASI (task done berikutnya me-refactor file yang sama) → brief & reviewer ter-anchor kontrak lama → kode salah lolos review. Diganti base-SHA task in-flight (D8) — lebih benar DAN lebih simpel (tanpa degrade `commits:`-absen).
- **Circuit breaker "2 blocked berturut kronologis lintas-lane" — draft v1.** Ditolak: race-dependent antar-lane, bisa gagal trip saat blocked terselingi sukses lane lain. Diganti: blocked pertama = halt (existing); blocked tambahan ber-akar-serupa hasil drain → reason "dugaan sistemik" (D9a).
