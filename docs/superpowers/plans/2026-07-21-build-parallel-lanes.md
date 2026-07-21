# Eksekusi Paralel Lintas-Repo di `build` (Lane per Repo) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `build` mengeksekusi ready-task di repo BERBEDA serempak (lane per repo, maks 1 in-flight per repo) dengan gate berhenti-bareng (drain), degrade otomatis ke sekuensial di monorepo, dan semua invariant akuntansi existing utuh.

**Architecture:** Semua perubahan = **edit prose skill markdown** (tak ada kode ber-test-harness). Fondasi aturan lane hidup di `build/reference.md` §F (mengganti kalimat "eksekusi tetap sekuensial"), didukung §B (signature-dep repo-sibuk), §D (rem run-level mode lane + reword klausa fanout), §E (resume jamak). `build/SKILL.md` menyusul: step 2 jadi scheduler lane, step 1/3/5/6 dapet klausa mode-lane. `breakdown`/`fanout`/`ship`/`fix`/`tweak` = NOL perubahan.

**Tech Stack:** Markdown (skill-authoring plugin context-vault). Verifikasi = `rg` (teks tersisip + anchor unik) + baca-cek konsistensi lintas-file. Tak ada unit-test runtime; "test" tiap task = assertion tekstual.

**Spec:** `docs/superpowers/specs/2026-07-21-build-parallel-lanes-design.md` (13 keputusan D1–D13).

## Global Constraints

Copy verbatim dari spec — implicit di SETIAP task:

- **Single-writer per repo:** maks 1 task in-flight per repo; dalam satu repo tetap sekuensial. Semua akuntansi base-SHA/`commits:`/no-op fan-in bertumpu ke sini. (D1/D3)
- **Urutan pemrosesan atomik:** (1) proses completion → (2) evaluasi gate/floor/titik-manusia (due → STOP-dispatch) → (3) BARU scheduler tick. (D1)
- **Fail-safe = sekuensial + WARN** untuk SEMUA kasus ragu (probe error, state korup, primitive background absen). (D2)
- **Drain = tunggu in-flight LAIN; task PEMICU tidak ditunggu** — ia agenda stop, status tetap `in_progress`. TANPA kosakata status baru. (D5)
- **Signature-dep repo-sibuk:** baca dari BASE-SHA task in-flight repo dep, bentuk `git -C <path-unit-workspace> show <base7>:./<file>` (path unit LITERAL + `./` wajib — match allowlist `wire` 5.5). BUKAN head task dep (bisa basi), BUKAN tree WIP. (D8)
- **Presedensi outcome sebab-campur:** `halt` > `continue` > `done`; `blocked` hasil drain SELALU `halt`. (D6)
- **`breakdown`/skema `tasks.yaml`/`ship`/`fix`/`tweak` = NOL perubahan file.** (Non-tujuan, D11)
- **Voice:** padat, bilingual-Indonesia sesuai skill existing; istilah konsisten: "mode lane", "lane per repo", "berhenti-bareng", "drain", "quiesce", "READY-SET".

## File Structure

| File | Tanggung jawab perubahan |
|---|---|
| `plugin/skills/build/reference.md` §F | **Fondasi aturan lane** — ganti kalimat sekuensial: lane per repo, quiesce `integration` (app+package), higiene hub-repo. (Task 1) |
| `plugin/skills/build/reference.md` §B + §E | **Brief & resume** — signature-dep repo-sibuk (D8); resume `in_progress` jamak, item (4) → scheduler lane, NEEDS_CONTEXT saat drain. (Task 2) |
| `plugin/skills/build/reference.md` §D | **Rem run-level mode lane** (breaker, cap, garansi task-pertama, auto-approve saat drain-halt) + reword klausa "Urutan fanout" (D13) + guard smoke di M-smoke Failure. (Task 3) |
| `plugin/skills/build/SKILL.md` step 1 + 2 | **Recovery jamak + guard fanout + presedensi outcome** (step 1); **scheduler lane + urutan atomik** (step 2). (Task 4) |
| `plugin/skills/build/SKILL.md` step 3 (+cek step 4) | **Dispatch background (D12) + signature-dep sibuk (D8) + commit-scope brief (D3).** (Task 5) |
| `plugin/skills/build/SKILL.md` step 5 + 6 | **`blocked` → drain** (step 5); **gate berhenti-bareng + unattended no-drain + guard smoke** (step 6). (Task 6) |

**Urutan:** Task 1 → 2 → 3 (reference = fondasi yang di-pointer) → Task 4 → 5 → 6 (SKILL menunjuk anchor reference yang sudah ada).

---

### Task 1: `reference.md` §F — aturan lane (fondasi)

**Files:**
- Modify: `plugin/skills/build/reference.md` (§F, kalimat penutup)

**Interfaces:**
- Produces: anchor **"lane per repo"** + protokol **"quiesce"** + **"Higiene hub-repo"** di §F — di-pointer SKILL step 2/3/6 (Task 4–6) via "§F".

- [ ] **Step 1: Ganti kalimat sekuensial dengan aturan lane**

Edit — `old_string`:

```
Eksekusi tetap sekuensial sesuai `deps` (tak ada dua subagent nulis tree sama serempak).
```

`new_string`:

```
Eksekusi = **lane per repo** (single-writer per repo): task di repo BERBEDA boleh jalan serempak; DALAM satu repo tetap sekuensial — **maks 1 task in-flight per repo**, tak pernah dua subagent nulis tree sama serempak. Tiap lane ambil task READY paling awal urut dokumen `tasks.yaml` (scheduler: SKILL step 2). **Degrade otomatis:** semua unit satu toplevel (monorepo) → satu lane → sekuensial persis perilaku lama; ragu identitas repo (probe error/ambigu) → sekuensial + WARN; user boleh minta "sequential" kapan pun.
- **`integration` = eksklusif + quiesce (anti-starvation, anti-deadlock):** butuh SEMUA repo unit di `deps`-nya idle — **app DAN package** (package polyrepo ter-compile dari working tree-nya saat consumer boot; WIP package = roundtrip palsu). Begitu ia jadi ready-task paling awal urut dokumen untuk repo-repo target → **quiesce**: STOP dispatch baru ke lane-lane itu, tunggu in-flight kelar (status final), lalu dispatch dengan lock atomik SEMUA repo target — TANPA hold parsial (tak pernah pegang repo A sambil nunggu repo B → tak ada circular wait). ≥2 integration bersaing → urutan dokumen. Selama ia in-flight, repo target tak menerima dispatch lain.
- **Higiene hub-repo campuran** (hub memuat `control/` + sebuah app lane aktif satu toplevel): controller **tak pernah COMMIT** ke repo yang lane-nya sedang in-flight — tulis working-tree boleh (status `tasks.yaml`, proyeksi M4, `last-run.md`); commit artefak control ditunda sampai lane repo itu idle. Brief implementer menegaskan **commit HANYA file task** (per `files:`, BUKAN `git add -A`) — jaga diff review & `commits:` bersih dari tulisan controller yang belum ter-commit.
```

- [ ] **Step 2: Verifikasi anchor & kalimat lama hilang**

Run:
```bash
rg -n "lane per repo|quiesce|Higiene hub-repo" plugin/skills/build/reference.md
rg -n "Eksekusi tetap sekuensial" plugin/skills/build/reference.md
```
Expected: 3 anchor hit di §F; "Eksekusi tetap sekuensial" = **nol hit**.

- [ ] **Step 3: Baca-cek §F**

Assert: (a) lock integration menyebut "app DAN package"; (b) "TANPA hold parsial" ada (anti-deadlock); (c) degrade monorepo eksplisit "persis perilaku lama". Tak ada `TBD`/`TODO`.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/build/reference.md
git commit -m "feat(build): reference §F — aturan lane per repo, quiesce integration, higiene hub-repo"
```

---

### Task 2: `reference.md` §B + §E — signature-dep repo-sibuk & resume jamak

**Files:**
- Modify: `plugin/skills/build/reference.md` (§B bullet "Signature dep"; §E item resume (2)/(4) + baris NEEDS_CONTEXT)

**Interfaces:**
- Consumes: anchor "lane per repo"/§F (Task 1).
- Produces: aturan **"repo pemilik dep SIBUK → base-SHA in-flight"** (§B) yang di-pointer SKILL step 3 (Task 5); resume jamak (§E) yang di-pointer SKILL step 1 (Task 4).

- [ ] **Step 1: §B — sisip aturan repo-sibuk di bullet Signature dep**

Edit — `old_string`:

```
Implementer membangun di atas kode NYATA, bukan tebakan dari teks `approach`.
```

`new_string`:

```
Implementer membangun di atas kode NYATA, bukan tebakan dari teks `approach`. **Repo pemilik dep sedang SIBUK (punya in-flight lane lain — mode lane §F):** JANGAN baca disk (bisa WIP) — baca dari **BASE-SHA task in-flight repo itu** (direkam SKILL step 3): `git -C <path-unit-workspace> show <base7-inflight>:./<file>` — `-C` pakai path unit LITERAL dari `workspace.yaml` (BUKAN toplevel hasil rev-parse; prefix allowlist `wire` 5.5 literal, wildcard-tengah mati) dan `./` WAJIB (tanpa itu `git show` resolve path relatif toplevel → salah di monorepo). Base in-flight = state committed+ter-review penuh terakhir, mencakup SEMUA task done — BUKAN head task dep (bisa BASI bila task done berikutnya me-refactor file yang sama). Repo dep idle → baca disk seperti biasa.
```

- [ ] **Step 2: §E — resume `in_progress` jamak**

Edit — `old_string`:

```
(2) **`in_progress` → JANGAN dilewati**: sesi lalu mati di tengah; reconcile dengan working tree + `git log` (revert/bereskan WIP setengah jadi), reset ke `pending`, lalu re-dispatch.
```

`new_string`:

```
(2) **`in_progress` → JANGAN dilewati**: sesi lalu mati di tengah; reconcile dengan working tree + `git log` (revert/bereskan WIP setengah jadi), reset ke `pending`, lalu re-dispatch. Mode lane (§F): `in_progress` bisa JAMAK (sesi mati = semua in-flight mati bareng) — reconcile SATU-SATU per repo masing-masing; task `integration` → reconcile SEMUA repo di `deps`-nya; **≥2 `in_progress` di repo SAMA = state korup (langgar single-writer) → fail-safe: sekuensial + tanya user, JANGAN reconcile buta**.
```

- [ ] **Step 3: §E — item (4) rujuk scheduler lane**

Edit — `old_string`:

```
(4) lanjut `pending` pertama yang seluruh `deps`-nya `done`.
```

`new_string`:

```
(4) lanjut scheduler lane SKILL step 2 (READY-SET per repo; degrade monorepo = `pending` pertama yang seluruh `deps`-nya `done` — perilaku lama).
```

- [ ] **Step 4: §E — NEEDS_CONTEXT saat drain**

Edit — `old_string`:

```
  - `NEEDS_CONTEXT` → kasih konteks yang diminta → re-dispatch (**bukan** `blocked`).
```

`new_string`:

```
  - `NEEDS_CONTEXT` → kasih konteks yang diminta → re-dispatch (**bukan** `blocked`). Jawaban harus dari USER (mode lane, saat drain SKILL step 6): task jadi agenda stop — status tetap `in_progress`, re-dispatch pasca jawaban (BUKAN reset `pending`).
```

- [ ] **Step 5: Verifikasi**

Run:
```bash
rg -n "base7-inflight|BASE-SHA task in-flight|state korup|scheduler lane SKILL step 2|agenda stop" plugin/skills/build/reference.md
```
Expected: §B punya bentuk perintah `git -C <path-unit-workspace> show <base7-inflight>:./<file>` verbatim; §E memuat "state korup" + "scheduler lane SKILL step 2" + "agenda stop".

- [ ] **Step 6: Commit**

```bash
git add plugin/skills/build/reference.md
git commit -m "feat(build): reference §B/§E — signature-dep repo-sibuk (base-SHA in-flight) + resume in_progress jamak"
```

---

### Task 3: `reference.md` §D — rem run-level mode lane + reword fanout + guard smoke

**Files:**
- Modify: `plugin/skills/build/reference.md` (§D: klausa fanout, sub-bullet Rem run-level, sub-bullet Failure M-smoke)

**Interfaces:**
- Consumes: anchor §F (Task 1).
- Produces: sub-bullet **"Mode lane"** di Rem run-level + guard smoke di M-smoke — di-pointer SKILL step 5/6 (Task 6).

- [ ] **Step 1: Reword klausa "Selalu hormati deps + Urutan fanout" (D13)**

Edit — `old_string`:

```
- Selalu hormati `deps` + Urutan `fanout` (mis. `web` dibangun setelah `api` nyata, bukan yang direncanakan).
```

`new_string`:

```
- Urutan `fanout` (mis. `web` setelah `api` NYATA) ter-encode sebagai `deps` oleh `breakdown`; scheduler lane menghormatinya via `deps` + **guard cross-check** (SKILL step 1): ready-task repo HILIR tanpa jalur `deps` ke task mana pun repo HULU yang masih ber-`pending`/in-flight → tahan dispatch lintas-repo + WARN ("deps lintas-app mungkin bolong — cek `breakdown`"); era sekuensial nutupin bolong ini lewat urutan dokumen, lane membukanya.
```

- [ ] **Step 2: Sisip sub-bullet "Mode lane" di ekor Rem run-level**

Edit — `old_string` (ekor sub-bullet Rem run-level):

```
Rem ini level-RUN — melengkapi cap 3-ronde review yang levelnya per-task (SKILL step 4), bukan menggantikannya.
```

`new_string`:

```
Rem ini level-RUN — melengkapi cap 3-ronde review yang levelnya per-task (SKILL step 4), bukan menggantikannya.
  - **Mode lane (paralel lintas-repo §F):** (a) **breaker** — `blocked` PERTAMA tetap drain + `halt` (existing §G); `blocked` TAMBAHAN ber-akar-serupa hasil drain → `reason` "dugaan sistemik" (breaker = memperkaya diagnosis; hitung "berturut kronologis lintas-lane" DITOLAK — race-dependent, bisa gagal trip saat interleaving). (b) **cap budget** — look-ahead dicek SAAT dispatch (controller satu proses, dispatch satu-per-satu); bobot = semua task ter-dispatch run ini TERMASUK in-flight; lewat → stop dispatch baru → drain → `continue` (kecuali drain hasilkan floor/`blocked` → presedensi `halt` > `continue` > `done`, SKILL step 1). Garansi task-pertama: "pertama" = ready paling awal urut dokumen LINTAS-lane, bebas cek budget (generalisasi setia aturan existing — task berat urutan-belakang nunggu giliran persis seperti sekuensial, bukan regresi). (c) **auto-approve** gate TIDAK menghentikan lane lain; segmen yang kelar DI TENGAH drain-halt & lolos kriteria → tetap auto-approve + catat (stop-nya disebabkan hal lain). Start run dengan `blocked` sudah di `tasks.yaml` → paritas existing (§E: laporkan + lanjut lane lain); tak ada ready-task di luar subtree blocked → `halt` dini.
```

- [ ] **Step 3: Guard smoke lintas-app di sub-bullet Failure M-smoke**

Edit — `old_string`:

```
Boot-fail karena prereq lingkungan yang mestinya ada → **blocker lingkungan** (`halt`), bukan corrective task. Observasi plausible → tampil gate (attended) / ringkas `last-run.md` (unattended).
```

`new_string`:

```
Boot-fail karena prereq lingkungan yang mestinya ada → **blocker lingkungan** (`halt`), bukan corrective task. Observasi plausible → tampil gate (attended) / ringkas `last-run.md` (unattended). **Mode lane unattended (§F):** smoke gagal SEMENTARA lane lain in-flight yang runtime/DB-nya bisa terpanggil app yang di-boot → JANGAN langsung penyimpangan (bisa 5xx dari WIP repo sebelah → corrective task fiktif): tunggu repo terkait idle → re-run smoke SEKALI → tetap gagal → baru penyimpangan. (Attended aman by construction — gate dievaluasi pasca drain, semua lane idle.)
```

- [ ] **Step 4: Verifikasi**

Run:
```bash
rg -n "guard cross-check|Mode lane \(paralel lintas-repo|re-run smoke SEKALI" plugin/skills/build/reference.md
rg -n "Selalu hormati .deps." plugin/skills/build/reference.md
```
Expected: 3 sisipan ada di §D; "Selalu hormati `deps`" = **nol hit** (sudah di-reword).

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/build/reference.md
git commit -m "feat(build): reference §D — rem run-level mode lane, guard fanout D13, guard smoke lintas-app"
```

---

### Task 4: `SKILL.md` step 1 + 2 — recovery jamak, guard fanout, presedensi outcome, scheduler lane

**Files:**
- Modify: `plugin/skills/build/SKILL.md` (step 1: bullet Recovery resume, bullet Branch per repo, bullet Lapor-keluar; step 2: rewrite)

**Interfaces:**
- Consumes: anchor §F "lane per repo"/quiesce (Task 1), §E resume jamak (Task 2), §D guard fanout (Task 3).
- Produces: **scheduler lane + urutan atomik** di step 2 — di-pointer step 3/5/6 (Task 5–6) via "step 2".

- [ ] **Step 1: Recovery resume — `in_progress` jamak**

Edit — `old_string`:

```
kalau ada WIP setengah jadi & test merah, revert/bereskan lalu set balik `pending`. **JANGAN pernah lewati `in_progress` diam-diam** (kalau dilewati, dependents-nya nyangkut selamanya).
```

`new_string`:

```
kalau ada WIP setengah jadi & test merah, revert/bereskan lalu set balik `pending`. Mode lane (`reference.md` §F): `in_progress` bisa JAMAK (sesi mati = semua in-flight mati bareng) — reconcile SATU-SATU per repo; task `integration` → reconcile SEMUA repo `deps`-nya; **≥2 `in_progress` di repo SAMA = state korup → fail-safe sekuensial + tanya user, JANGAN reconcile buta**. **JANGAN pernah lewati `in_progress` diam-diam** (kalau dilewati, dependents-nya nyangkut selamanya).
```

- [ ] **Step 2: Bullet baru Guard Urutan-fanout (sesudah bullet Branch per repo)**

Edit — `old_string`:

```
Probe error (belum git) → minta user init / skip git. (Detail: `reference.md` §F.)
```

`new_string`:

```
Probe error (belum git) → minta user init / skip git. (Detail: `reference.md` §F.)
- **Guard Urutan-fanout (mode lane, sekali — bila lane paralel bakal nyala):** cross-check Urutan `fanout.md` — ada ready-task di repo HILIR yang TIDAK punya jalur `deps` ke task mana pun repo HULU, SEMENTARA repo hulu masih punya `pending`/in-flight → **tahan dispatch lintas-repo task itu + WARN** ("deps lintas-app mungkin bolong — cek `breakdown`"); user boleh override atau minta sekuensial. Fitur 1-app / tanpa `fanout.md` / Urutan kosong → no-op. (Era sekuensial nutupin deps bolong lewat urutan dokumen — lane membukanya; `reference.md` §D.)
```

- [ ] **Step 3: Presedensi outcome sebab-campur (bullet Lapor-keluar)**

Edit — `old_string`:

```
Pemetaan `outcome`: semua done (step 7)=`done`; cap-volume tercapai & masih pending & tak ada floor=`continue`; floor/blocker (`needs_human`/`blocked`/circuit-breaker/`migrate`/Security/floor-scan-simplify-7a/blocker-lingkungan/`risk:high`-saat-unattended)=`halt`.
```

`new_string`:

```
Pemetaan `outcome`: semua done (step 7)=`done`; cap-volume tercapai & masih pending & tak ada floor=`continue`; floor/blocker (`needs_human`/`blocked`/circuit-breaker/`migrate`/Security/floor-scan-simplify-7a/blocker-lingkungan/`risk:high`-saat-unattended)=`halt`. **Sebab campur hasil drain (mode lane §F): presedensi `halt` > `continue` > `done`** — `blocked` hasil drain SELALU `halt` (jangan `continue` bikin driver restart & blocked terkubur); `reason` = sebab prioritas tertinggi (floor > blocked > lainnya) + "(+N isu lain, lihat prosa)".
```

- [ ] **Step 4: Rewrite step 2 — scheduler lane + urutan atomik**

Edit — `old_string`:

```
### 2. Pilih task
Ambil task `pending` pertama yang seluruh `deps`-nya `done`.
Bila task terpilih punya `manual:` yang belum dikonfirmasi beres → set `status: needs_human`, **STOP SELURUH build**, lapor checklist langkah manual ke user; **jangan dispatch** (hemat ronde implementer). Lanjut setelah user konfirmasi beres.
```

`new_string`:

```
### 2. Pilih task (scheduler lane)
Hitung **READY-SET** = SEMUA task `pending` yang seluruh `deps`-nya `done`; kelompokkan per **repo** (toplevel dari probe step 1, `reference.md` §F). Dispatch dengan aturan keras **maks 1 task in-flight per repo** (single-writer); tiap lane ambil task READY paling awal urut dokumen `tasks.yaml`. **Degrade otomatis:** satu repo (monorepo) → identik perilaku lama (ambil `pending` pertama yang deps-nya `done`, satu-satu); ragu → sekuensial + WARN. Task `unit: integration` → protokol quiesce + lock atomik `reference.md` §F. **Urutan pemrosesan tiap completion ATOMIK: (1) proses completion (verify + review + status, step 4–5) → (2) evaluasi gate/floor/titik-manusia yang jadi due — due (attended) → STOP-dispatch SEMUA lane (step 6) → (3) BARU scheduler tick (dispatch ready-task baru).** Task yang baru ready TEPAT pada completion pemicu gate tak pernah ter-dispatch sebelum gate resolved (tak ada yang membangun di atas kontrak yang mungkin direvisi).
Bila task terpilih punya `manual:` yang belum dikonfirmasi beres → set `status: needs_human`, **STOP SELURUH build** (mode lane: STOP-dispatch semua lane + drain step 6 dulu), lapor checklist langkah manual ke user; **jangan dispatch** (hemat ronde implementer). Lanjut setelah user konfirmasi beres.
```

- [ ] **Step 5: Verifikasi**

Run:
```bash
rg -n "READY-SET|maks 1 task in-flight per repo|Urutan pemrosesan tiap completion ATOMIK|Guard Urutan-fanout|presedensi .halt." plugin/skills/build/SKILL.md
```
Expected: semua anchor ada; "READY-SET" & "ATOMIK" di step 2; guard di step 1.

- [ ] **Step 6: Commit**

```bash
git add plugin/skills/build/SKILL.md
git commit -m "feat(build): step 1-2 — scheduler lane (READY-SET, urutan atomik), recovery jamak, guard fanout, presedensi outcome"
```

---

### Task 5: `SKILL.md` step 3 — dispatch background, signature-dep sibuk, commit-scope brief (+cek step 4)

**Files:**
- Modify: `plugin/skills/build/SKILL.md` (step 3, ekor paragraf dispatch)

**Interfaces:**
- Consumes: §B aturan repo-sibuk (Task 2), scheduler step 2 (Task 4).
- Produces: klausa **"dispatch = subagent BACKGROUND"** — prasyarat mekanisme yang step 6 (Task 6) andalkan untuk drain.

- [ ] **Step 1: Sisip klausa mode-lane di ekor step 3 (sesudah Rekam BASE commit)**

Edit — `old_string`:

```
**Rekam BASE commit:** sebelum dispatch, catat `git -C <path> rev-parse --short=7 HEAD` per repo yang bakal disentuh task ini — basis verifikasi "HEAD maju" (step 4) + field `commits:` (step 5).
```

`new_string`:

```
**Rekam BASE commit:** sebelum dispatch, catat `git -C <path> rev-parse --short=7 HEAD` per repo yang bakal disentuh task ini — basis verifikasi "HEAD maju" (step 4) + field `commits:` (step 5). **Mode lane (`reference.md` §F) — dispatch = subagent BACKGROUND:** implementer/reviewer lane BERBEDA jalan serempak; controller memproses completion SATU-PER-SATU (urutan atomik step 2) dan **TIDAK mengakhiri turn selagi ada in-flight** (headless: akhir turn = proses exit = in-flight mati → residu multi-`in_progress` tiap putaran driver). Primitive background tak tersedia/ragu → degrade ronde-barrier (dispatch batch paralel → proses semua hasil → ronde berikut; tie completion → urutan dokumen) ATAU sekuensial + WARN. **Signature dep saat repo dep SIBUK:** baca dari base-SHA task in-flight repo itu — bentuk `git -C <path-unit> show <base7>:./<file>`, detail `reference.md` §B (BUKAN disk WIP, BUKAN head task dep yang bisa basi). **Brief menegaskan: commit HANYA file task (per `files:`), BUKAN `git add -A`** (higiene hub-repo §F).
```

- [ ] **Step 2: Cek step 4 — nol asumsi single-task tersisa**

Baca step 4 `plugin/skills/build/SKILL.md`. Assert: verifikasi per task (HEAD maju dari base task itu, paket diff per-range) tetap valid apa adanya di mode lane — **nol edit diharapkan** (spec: "step 4 wording jamak saja; verifikasi per task tak berubah"). Kalau ketemu kalimat yang eksplisit mengasumsikan "cuma ada satu task berjalan", laporkan di gate (jangan edit diam-diam di luar plan).

- [ ] **Step 3: Verifikasi**

Run:
```bash
rg -n "subagent BACKGROUND|TIDAK mengakhiri turn|ronde-barrier|commit HANYA file task" plugin/skills/build/SKILL.md
```
Expected: semua di step 3.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/build/SKILL.md
git commit -m "feat(build): step 3 — dispatch background mode lane, signature-dep repo-sibuk, commit-scope brief"
```

---

### Task 6: `SKILL.md` step 5 + 6 — blocked → drain, gate berhenti-bareng, unattended no-drain + guard smoke

**Files:**
- Modify: `plugin/skills/build/SKILL.md` (step 5: kalimat blocked; step 6: kalimat pembuka gate + klausa auto-approve unattended)

**Interfaces:**
- Consumes: urutan atomik step 2 (Task 4), rem mode lane §D + guard smoke (Task 3), NEEDS_CONTEXT §E (Task 2).

- [ ] **Step 1: Step 5 — blocked memicu drain**

Edit — `old_string`:

```
Buntu/error → `blocked`, **STOP**, laporkan (sandar `systematic-debugging`).
```

`new_string`:

```
Buntu/error → `blocked`, **STOP**, laporkan (sandar `systematic-debugging`; mode lane §F: STOP-dispatch semua lane → **drain** step 6 → lapor agenda bareng — `blocked` tambahan ber-akar-serupa hasil drain → reason "dugaan sistemik", `reference.md` §D).
```

- [ ] **Step 2: Step 6 — kalimat pembuka gate = berhenti-bareng + drain**

Edit — `old_string`:

```
Semua task satu segmen (default **app × milestone**) `done` → **BERHENTI**: tampilkan
```

`new_string`:

```
Semua task satu segmen (default **app × milestone**) `done` → **BERHENTI** — mode lane (§F) = **berhenti-bareng**: STOP-dispatch SEMUA lane (urutan atomik step 2, SEBELUM scheduler tick — task yang baru ready tak ter-dispatch), **DRAIN** in-flight lain sampai status final; task PEMICU titik-manusia sendiri TIDAK ditunggu — ia jadi **agenda stop** (status tetap `in_progress`; hindari tunggu-melingkar: approve `migrate`/jawaban NEEDS_CONTEXT justru prasyarat ia final); sajikan SEMUA agenda (bisa >1 gate / `blocked` hasil drain) dalam SATU pemberhentian; pasca keputusan → resume dispatch paralel. Lalu: tampilkan
```

- [ ] **Step 3: Step 6 — auto-approve unattended: lane lain jalan terus + guard smoke**

Edit — `old_string`:

```
→ **auto-approve** segmen (catat ringkasan, lanjut loop tanpa stop user).
```

`new_string`:

```
→ **auto-approve** segmen (catat ringkasan, lanjut loop tanpa stop user; mode lane §F: lane lain TIDAK berhenti — tak ada manusia yang ditunggu. **Guard smoke lintas-app:** smoke Part B gagal SEMENTARA lane lain in-flight yang runtime/DB-nya bisa terpanggil app yang di-boot → JANGAN langsung penyimpangan: tunggu repo terkait idle → re-run smoke SEKALI → tetap gagal → baru penyimpangan — `reference.md` §D).
```

- [ ] **Step 4: Verifikasi**

Run:
```bash
rg -n "berhenti-bareng|agenda stop|DRAIN in-flight lain|Guard smoke lintas-app|dugaan sistemik" plugin/skills/build/SKILL.md
```
Expected: "berhenti-bareng"/"DRAIN"/"agenda stop" di step 6; "dugaan sistemik" di step 5; guard smoke di klausa unattended step 6 (BUKAN step 7a).

- [ ] **Step 5: Baca-cek lintas-file final**

Assert konsistensi istilah lintas SKILL ↔ reference: "mode lane" · "lane per repo" · "berhenti-bareng" · "drain" · "quiesce" · "READY-SET" · "agenda stop" · bentuk `git -C <path-unit> show <base7>:./<file>` identik di §B (Task 2) & step 3 (Task 5). `breakdown`/`fanout`/`ship`/`fix`/`tweak` = `git status` bersih di luar `plugin/skills/build/`.

- [ ] **Step 6: Commit**

```bash
git add plugin/skills/build/SKILL.md
git commit -m "feat(build): step 5-6 — blocked drain, gate berhenti-bareng, unattended no-drain + guard smoke"
```

---

## Self-Review (diisi penulis plan)

**1. Spec coverage:** D1(lane+atomik)→T4 step 4 + T1 · D2(degrade/fail-safe)→T1/T4 (+korup T2/T4 step 1) · D3(akuntansi nol + hub-repo)→T1 + T5 (commit-scope); base-SHA existing = nol edit · D4(integration quiesce)→T1 + pointer T4 · D5(drain+agenda)→T6 step 1-2 + T2 step 4 (NEEDS_CONTEXT) · D6(no-drain, guard smoke, presedensi)→T6 step 3 + T3 step 2-3 + T4 step 3 · D7(recovery jamak)→T4 step 1 + T2 step 2 · D8(signature base-SHA in-flight)→T2 step 1 + T5 step 1 · D9(rem)→T3 step 2 + T4 step 3 · D10(scratch by construction)→nol edit (penamaan existing) · D11(fix/tweak nol)→T6 step 5 assert · D12(background+degrade)→T5 step 1 · D13(guard fanout)→T4 step 2 + T3 step 1. **Tak ada D tanpa task.**

**2. Placeholder scan:** Nol `TBD`/`TODO`/"handle edge cases" — semua insertion teks final verbatim.

**3. Konsistensi penamaan:** "mode lane (§F)" dipakai sebagai marker di SEMUA sisipan SKILL; bentuk perintah `git -C <path-unit-workspace> show <base7-inflight>:./<file>` (§B) vs pointer ringkas `git -C <path-unit> show <base7>:./<file>` (step 3) — step 3 menunjuk §B untuk detail (satu sumber kebenaran). "READY-SET"/"berhenti-bareng"/"quiesce"/"agenda stop"/"dugaan sistemik" konsisten T1–T6.
