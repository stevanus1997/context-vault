# context-vault — Lane Bugfix: `fix` (Design Spec)

- **Tanggal:** 2026-06-02
- **Status:** Draft disetujui untuk masuk tahap perencanaan implementasi (sudah lewat satu pass `critic`)
- **Terkait:** spec induk `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (mengisi void lifecycle §12 — tidak ada jalur defect); spec `2026-05-29-breakdown-build-execution-phase-design.md` (`fix` meminjam **eksekutor** `build` + skema `tasks.yaml`); spec `2026-06-01-platform-invariants-security-gate-design.md` (Security Gate `ship` di-skala `sensitivity` — di-RE-EVALUASI oleh fix, bukan diwarisi pasif).

---

## 1. Ringkasan

Seluruh pipeline saat ini berputar pada **penciptaan kapabilitas baru**:

```
discovery → init → architect → wire → feature(intake→fanout→plan) → breakdown → build → ship
                                                                                    └ drop
```

Tidak ada **jalur untuk defect** — perilaku yang **sudah ada** ternyata salah. Dua kejadian nyata jatuh ke void ini:

- **A — bug saat `build` (pre-ship, in-flight).** `build` menjalankan `tasks.yaml`; test "lulus" tapi hasilnya menyimpang dari `business.md`/`plan` (mis. *"diskon persentase"* dieksekusi jadi *diskon flat*; landing page boot tapi UI meleset). Gate `build` (`SKILL.md` line 46) cuma `BERHENTI minta approve/revisi` — **tak ada cabang pemulihan terdefinisi**. Pengguna mentok: "ada beda, harus apa?"
- **B — bug dari report pengguna (post-ship, produksi).** Fitur sudah `shipped`; pengguna melapor (mis. *"kupon expired masih kepake"*). Satu-satunya jalur yang ada = `/feature` — yang menyeret **intake bisnis dari nol + fanout + plan** untuk sesuatu yang **knowledge bisnisnya sudah ada**. Itu memperlakukan **koreksi** seakan **kapabilitas baru** — overkill, dan secara konsep salah.

Spec ini mengisi void dengan **satu skill baru, `fix`**, yang **auto-deteksi mode** dari status target:

- **mode in-flight** (target nyangkut fitur `active`) — reproduce → root-cause → tulis **corrective task** ke `tasks.yaml` fitur itu → eksekusi (pinjam `build`) → ijo → **STOP**. Tidak dicatat sebagai entitas terpisah (belum pernah `shipped`).
- **mode post-ship** (target = bug produksi / fitur `shipped`) — triage → catat `control/fixes/<id>/` (**entitas first-class, sejajar `features/`**) → reproduce → root-cause → fix (pinjam `build`) → verify lokal → **STOP di "siap di-`ship`"**.

Prinsip inti: **satu mesin, dua pintu.** Loop dalam (reproduce → root-cause → TDD fix → verify) sama; yang beda hanya **entry**, **artifact**, dan **exit**. `fix` **tidak pernah** auto-`ship` — `ship` tetap langkah eksplisit terpisah (konsisten dengan `build`/`ship` yang memang "boleh sesi terpisah").

> **Catatan kejujuran (anti-yes-man):** "reuse" di sini **bukan** "nol perubahan". Generalisasi work-item menyentuh `build`, `ship`, `breakdown`, dan `render-docs` secara nyata (lihat §13). Klaim "konsep baru minimal" berlaku untuk **model data** (`fixes/` meniru `features/`), bukan untuk "tak menyentuh skill lain".

## 2. Masalah

- **D1 — `build` dead-stop saat "test ijo tapi hasil salah".** `build/SKILL.md` line 44 menyandar `systematic-debugging` **hanya** saat task `blocked` (error eksplisit). Kasus paling licik — task **`done`** (test hijau) tapi perilaku menyimpang dari maksud — ketahuan di gate (line 46, cek "dibangun vs task") yang cuma `BERHENTI minta approve/revisi` **tanpa loop pemulihan**. `bug_mentions` di `build` = **NONE**.
- **D2 — `ship` dead-stop, tak balik ke perbaikan.** `ship/SKILL.md` line 39: *"Ada merah → STOP, jangan ship."* Benar (anti rubber-stamp), tapi **tidak ada jalur balik** terstruktur. `bug_mentions` di `ship` = **NONE**.
- **D3 — `/feature` overkill untuk defect produksi.** Status `shipped` bahkan **menolak** `build`/`ship` (build line 15, ship line 50) — jadi tak ada jalur sah untuk menyentuh kode yang sudah dikirim, selain `/feature` yang mengulang intake.
- **D4 — Defect tak punya rumah knowledge.** Filosofi sistem: "knowledge as byproduct" + dokumen yang tak pernah drift (induk §4). Tapi **root cause** sebuah bug tak punya tempat tinggal, dan `render-docs` tak punya konsep "Known Issues / Riwayat Fix".
- **D5 — Knowledge bisa jadi BIANG bug.** Kadang kode benar, `business.md`/`flows.md`-nya yang usang/salah. Tanpa jalur koreksi knowledge, lane korektif justru **memperlebar** drift (memperbaiki kode agar cocok doc yang salah). [temuan critic #9]

Akar: lane korektif tidak punya pelaksana maupun model data. Pipeline berhenti di "fitur dikirim", padahal hidup produk justru baru mulai di situ.

## 3. Tujuan & Non-Tujuan

**Tujuan:**
- Menutup void defect dengan **satu skill `fix`** ber-**dua mode auto-deteksi** (in-flight / post-ship), dengan **tabel keputusan mode eksplisit** (§4) yang menutup semua cabang status target.
- **Satu mesin, dua pintu** — loop dalam (reproduce → root-cause → TDD → verify) dipakai-ulang; beda hanya entry/artifact/exit. Tidak ada eksekutor kedua (anti-drift).
- **`fix` hanya sampai ijo; `ship` selalu terpisah** — `fix` tak pernah auto-`ship`.
- **mode post-ship = entitas first-class** `control/fixes/<id>/` sejajar `features/`, memakai **skema `tasks.yaml` yang sama** dengan `breakdown`/`build` (milestone-wrapped — §9), bukan list flat.
- **Triage 3-arah (anti scope-creep + anti drift)** — bug (kode salah) vs requirement baru (→ `/feature`) vs **doc salah** (→ koreksi knowledge, gated `critic`). Plus **tripwire mekanis** untuk eskalasi (§8).
- **Sensitivity di-RE-EVALUASI, bukan diwarisi pasif** — triage cross-check `invariants.md` agar fix yang memperkenalkan sentuhan data sensitif baru tetap kena Security Gate (§8, §11). [critic #5]
- **Defect punya rumah knowledge** — `root_cause` + repro tercatat (`fix.yaml` + `notes.md`); `render-docs` dapat section "Riwayat Fix / Known Issues".

**Non-Tujuan (v1):**
- `fix` **bukan** generator fitur. Butuh kapabilitas/kontrak/vendor baru → **STOP → `/feature`** (guard §8).
- `fix` **tidak** auto-`ship` dan **tidak** membuat PR — jatah `/ship` terpisah.
- **Triase berat / dedup laporan / SLA / on-call** di luar scope. `severity` v1 = **2 tingkat** (`normal`/`urgent`) — metadata untuk urutan render-docs + sinyal, bukan mesin SLA. [critic #13]
- **Rollback/revert otomatis** di luar scope (revert sebuah fix `shipped` = fix baru / urusan git).
- **Auto-ingest report** (issue tracker/Sentry) di luar scope — input bug v1 dari pengguna.

## 4. Lifecycle Baru & Tabel Keputusan Mode

```
Penciptaan : … → build → ship → shipped
Koreksi    :
   in-flight  (fitur active):   /fix → reproduce → root-cause → append corrective task → build(exec) → IJO → STOP
                                 (ship NANTI, sekalian seluruh fitur, sesi terpisah)
   post-ship  (fitur shipped):  /fix → triage → fixes/<id>/ → reproduce → root-cause → build(exec) → verify → STOP "siap ship"
                                 → /ship <fix>  (TERPISAH) → PR → fix.yaml shipped → render-docs
```

**Tabel keputusan mode** (menutup cabang yang sebelumnya ambigu — critic #7):

| Target nyangkut… | Mode | Aksi |
|---|---|---|
| **1 fitur `active`** (punya `tasks.yaml`, branch hidup) | **in-flight** | corrective task ke `tasks.yaml` fitur itu |
| **fitur `shipped`** | **post-ship** | `fixes/<id>/` first-class |
| **fitur `draft`** (belum `build`, belum ada kode) | **DITOLAK** | bukan bug — itu fitur belum dikerjakan; arahkan lanjutkan `/feature` |
| **TAK nyangkut fitur mana pun** (bug di skeleton `wire`/shared util) | **post-ship** | `fixes/<id>/`, `relates_to: []`; sensitivity **wajib** dievaluasi dari nol vs `invariants.md` (tak ada yang diwarisi) |
| **DUA fitur — `active` + `shipped`** sekaligus | **tie-break → tanya** | default usul: kalau bug ada di kode yang **sedang di-build** → in-flight; selain itu post-ship. Konfirmasi ke user (jangan tebak diam-diam). |

`fix` **dipanggil eksplisit** (tidak di-auto-chain ke `ship`), **bisa sesi terpisah**. Mode dideteksi otomatis lalu dikonfirmasi pada kasus ambigu — pengguna tidak memilih mode secara manual.

## 5. Konsep Inti — Satu Mesin, Dua Pintu

| Dimensi | mode in-flight | mode post-ship |
|---|---|---|
| Pemicu | bug saat `build`/cek manual; fitur `active` | report pengguna; fitur `shipped` |
| Loop dalam | reproduce → root-cause → TDD fix → verify | reproduce → root-cause → TDD fix → verify |
| Artifact | **corrective task** di `tasks.yaml` fitur (`kind: fix`) | **`control/fixes/<id>/`** (fix.yaml + notes.md + tasks.yaml mini) |
| Eksekutor | `build` (mem-`pick` task baru) | `build` (work-item generalization, §11) |
| Dicatat? | **Tidak** (belum pernah shipped) | **Ya** (first-class, §9) |
| Exit | ijo → STOP; fitur tetap `active`; ship nanti sekalian fitur | ijo + verify lokal → STOP "siap ship"; `/ship <fix>` terpisah |

Loop dalam = **sumbu reuse**: keduanya sandar `systematic-debugging` (root-cause, **di-dispatch ke subagent** — §6/§7) + TDD (reproduce = test merah dulu) + eksekutor `build` (implementer subagent + review 2-tahap + gate). Yang berbeda hanya **lapisan luar**.

## 6. Mode in-flight — Prosedur

Konteks: fitur `active`, `tasks.yaml` ada, branch hidup. Bug = task `done` tapi hasil meleset, atau gap yang task tak cover.

**Dua pemicu, dipisah tegas (anti-rekursi — critic #6):**
- **(P-user) `/fix` dijalankan pengguna** di sesi baru → `fix` menulis corrective task lalu **memanggil `build`** untuk eksekusi.
- **(P-build) `build` sendiri** mendeteksi penyimpangan di gate (line 46) → `build` menjalankan **disiplin fix yang di-EMBED** (menulis corrective task ke `tasks.yaml`-nya sendiri, lanjut loop internalnya). **`build` TIDAK pernah meng-invoke skill `/fix`.** Jadi tak ada jalur `build → /fix → build`. Skill `/fix` hanya entry dari luar; di dalam `build`, disiplinnya inline.

Prosedur (`/fix` pengguna):
1. **Triage guard (§8).** Bug / requirement-baru / doc-salah. Requirement baru → `/feature`. Doc salah → cabang koreksi knowledge.
2. **Reproduce (subagent).** Dispatch subagent menulis **test/snapshot MERAH** yang menangkap penyimpangan. Test ini jadi `test` di corrective task.
3. **Root-cause (subagent, `systematic-debugging`).** Investigasi context-heavy → **di subagent**, konduktor cuma simpan kesimpulan (task mana meleset / gap mana). [critic #11]
4. **Append corrective task** ke `control/features/<fitur>/tasks.yaml` — **skema sama** (`milestones[].tasks[]`, masuk milestone yang relevan atau milestone `fixes` khusus):
   ```yaml
   # di dalam milestones[].tasks[]
   - id: fix-hero-mobile
     kind: fix                 # default task tanpa kind = implicit "feat"; ini penanda korektif
     corrects: hero-section    # task yang hasilnya meleset (traceability)
     observed: "hero CTA kepotong di mobile, beda dari plan"
     unit: web
     status: pending
     deps: []
     test: ["snapshot hero mobile sesuai plan"]
     approach: "reproduce dulu (snapshot), baru perbaiki spacing"
   ```
5. **Eksekusi** — pinjam `build`: ia mem-`pick` task `pending` ini → dispatch implementer (TDD merah→hijau, dengan konteks: `conventions.md` + pointer file pola + signature dep dari disk, persis build step 3) → review 2-tahap → gate per segmen → `done`.
6. **Selesai.** Ijo → **STOP**. Fitur **tetap `active`**. **Tidak** ada `fixes/<id>/`. `ship` nanti, sekali, untuk seluruh fitur.

## 7. Mode post-ship — Prosedur

Konteks: bug produksi; tak ada branch hidup; fitur `shipped` (atau tak nyangkut fitur).

1. **Triage (§8) + framing.** Bug / requirement / doc-salah. Tetapkan `severity` (`normal`/`urgent`). Identifikasi `relates_to` fitur + `flow` dengan **membaca `business.md` + `flows.md`** (BUKAN intake dari nol). **RE-EVALUASI `sensitivity`** terhadap `invariants.md` (bukan sekadar warisan — critic #5). Tentukan `units` (lihat catatan unit-inference di bawah).
2. **Record.** `control/fixes/<YYYY-MM-DD>-<slug>/`: `fix.yaml` (`status: open`, schema §9), `notes.md` (repro + log investigasi).
3. **Reproduce (subagent).** Test regresi **MERAH** → langkah di `notes.md`.
4. **Root-cause (subagent, `systematic-debugging`).** Isi `root_cause` → `status: diagnosed`. Bila root-cause mengungkap **`business.md`/`flows.md` yang salah** → masuk cabang koreksi knowledge (§8).
5. **Tulis fix-task** ke `control/fixes/<id>/tasks.yaml` (**skema milestone-wrapped**, 1–3 task). Lintas-unit → tulis `_shared.md` mini **wajib** (pembawa kontrak antar-unit — critic #3).
6. **Eksekusi** — pinjam `build` via **work-item generalization (§11)**: branch `fix/<id>` per repo → implementer (TDD, konteks: `conventions.md` + pointer file + `root_cause` + kutipan `business.md` fitur `relates_to`) → review 2-tahap → gate per `unit`.
7. **Verify lokal + STOP.** Quality (test/lint/typecheck/build) ijo → **STOP, "siap di-`ship`"**. `/ship <fix>` dijalankan terpisah (boleh nawarin "lanjut ship?" tapi default STOP).
8. **Drop path.** Triage/investigasi = **bukan-bug / wontfix / duplikat** → `fix` **self-set** `status: dropped` + `reason`, folder dikeep (memori). **`drop` TIDAK menerima fix-id** (critic #8).

**Unit-inference (bukan "mini-fanout" — critic #14):** `fix` meng-**infer** `units` dari `fanout.md` fitur `relates_to` lalu **konfirmasi ke user**. Ini **versi-lemah** dari `fanout` dan jujur diakui begitu — ia **tidak** menjalankan deteksi vendor / unit-kelewat penuh. **Tripwire:** kalau perbaikan ternyata menyentuh **`unit` di luar footprint fitur `relates_to`**, atau butuh **vendor baru** (`integrations.md`), atau **capability baru** → itu sinyal **bukan fix sederhana → STOP → `/feature`** (§8).

Gate `ship` (terpisah, §11): code-review + quality + **business-alignment** (`critic`) + **Security Gate** (bila `sensitivity` hasil re-evaluasi memuat `payments`/`pii` → `security-critic` + `invariants.md`/`integrations.md`) → PR per repo (desc dari `root_cause` + diff) → `fix.yaml` `shipped` → `render-docs`.

## 8. Triage Guard — 3 Arah + Tripwire (anti scope-creep & anti drift)

Semua mode lewat pintu ini. **Tiga kemungkinan** (sebelumnya cuma dua — critic #9):

1. **Perilaku ≠ `business.md`/`plan`, kode salah** → **bug**, lanjut lane `fix` (koreksi kode).
2. **Perilaku yang diminta tak pernah dispec** → **fitur baru** → **STOP → `/feature`**.
3. **Perilaku kode benar, `business.md`/`flows.md` yang salah/usang** → **koreksi KNOWLEDGE** (update `business/` gated + `critic`), bukan koreksi kode. Bila keduanya salah → koreksi kode **dan** knowledge. *Ini menutup D5: lane korektif harus bisa menyentuh knowledge, bukan cuma kode — kalau tidak, ia memperlebar drift.*

**Tripwire mekanis untuk eskalasi ke `/feature`** (bukan judgment call — critic #12). STOP & arahkan `/feature` bila fix:
- butuh entri **BARU** di `workspace.yaml.capabilities`, **atau**
- butuh entri/vendor **BARU** di `control/integrations.md`, **atau**
- menambah **`unit`** yang **bukan** bagian footprint fitur `relates_to` (cek terhadap `fanout.md`).

Ketiganya bisa dicek mekanis (pola yang sama dengan validasi `unit` di `breakdown` step 1) → guard tidak bisa di-rasionalisasi.

**Sensitivity re-evaluation** (bagian dari triage, bukan warisan pasif): bandingkan diff/rencana fix terhadap `invariants.md` (tenancy/money/idempotency/authz/PII-PCI). Bila fix menyentuh data sensitif yang fitur asal tak punya → set `fix.yaml.sensitivity` sesuai temuan, sekalipun fitur `relates_to` ber-`sensitivity: []`. Ini menjamin Security Gate (`ship` 4.5) jalan untuk perubahan yang justru paling rawan.

## 9. Recording Model — `fixes/<id>/` First-Class

`control/fixes/` adalah **tetangga sebelah** `control/features/` — entitas lifecycle setara.

```
control/
├── features/
│   └── checkout-kupon/        status: shipped
└── fixes/                                    ← entitas baru, sejajar features/
    ├── 2026-06-02-kupon-expired/
    │   ├── fix.yaml
    │   ├── notes.md           ← repro + log root-cause (memori)
    │   ├── _shared.md         ← HANYA bila lintas-unit (kontrak, wajib bila >1 unit)
    │   └── tasks.yaml         ← skema milestone-wrapped, mini (1–3 task)
    └── 2026-06-15-email-encoding/
        └── fix.yaml           ← bug sepele: notes.md & tasks.yaml minimal (fast-path)
```

**`fix.yaml` (skema):**
```yaml
id: kupon-expired
status: open                 # open → diagnosed → shipped (+ dropped)
severity: normal             # normal | urgent  (metadata: urutan render-docs + sinyal)
reported_at: 2026-06-02
reported: "user: kupon SUMMER expired masih kepake di checkout"
relates_to: [checkout-kupon] # link fitur asal (array; boleh >1; boleh kosong utk shared util)
flow: checkout               # link ke business/flows.md
units: [api]                 # app/package kena (inferensi + konfirmasi) — basis branch & gate
sensitivity: payments        # HASIL RE-EVALUASI vs invariants.md (bukan warisan pasif)
root_cause: ""               # diisi saat diagnosed
knowledge_touched: []        # mis. ["business/flows.md"] bila triage cabang-3 mengoreksi doc
fix_pr: ""                   # diisi saat shipped
shipped_at: ""               # diisi saat shipped
reason: ""                   # diisi saat dropped (wontfix/bukan-bug/dup)
```

- **Konsistensi penuh** dengan model `features/`: folder + manifest + status byproduct + filter render-docs + folder = memori keputusan (kayak `/drop`).
- **`tasks.yaml` fix memakai SKEMA YANG SAMA** dengan `breakdown`/`build` (`feature:`/`generated_from:` opsional, tapi **`milestones[].tasks[]` wajib** — minimal 1 milestone bungkus), supaya hard-guard `build` line 50 (iterasi per-milestone) tidak mismatch. [critic #1]
- **Root cause punya rumah** (`notes.md` + field).
- **Lintas-fitur aman:** `relates_to` array (boleh kosong).
- **Fast-path bug sepele:** `severity: normal` boleh skip `notes.md` & `tasks.yaml` minimal; folder tetap dibuat demi konsistensi.

## 10. Status Lifecycle `fix.yaml`

Kasar (selaras induk §12 — progress halus dibaca dari artifact):

| Status | Dipicu oleh | Otomatis/Manual |
|---|---|---|
| `open` | `/fix` mulai (post-ship), report + triage lolos | otomatis |
| `diagnosed` | `root_cause` terisi | otomatis |
| `shipped` | `/ship <fix>` semua-hijau → PR | hasil menjalankan skill |
| `dropped` | `fix` self-set saat triage = bukan-bug / wontfix / dup | hasil menjalankan skill |

Progress halus **`fixing`/`done`** dibaca dari `fixes/<id>/tasks.yaml`. Mode **in-flight tidak punya `fix.yaml`** — hidup sebagai task di `tasks.yaml` fitur.

## 11. Reuse — Work-Item Generalization (Opsi A) + koreksi klaim

Sumbu reuse. `build`/`ship` saat ini hardcode `control/features/<fitur>/`. Generalisasi: **work-item = folder berisi `tasks.yaml` (milestone-wrapped) + manifest**; manifest = `feature.yaml` (fitur) ATAU `fix.yaml` (fix). Lanjutan langsung H2 (dulu `unit` → *app/package*; kini *work-item* → *fitur/fix*).

**Perubahan nyata per skill (dikoreksi dari draft pertama yang terlalu optimis):**

- **`build`:**
  - line 15 (status-check) → terima **manifest work-item**: `feature.yaml` (`active`) **ATAU** `fix.yaml` (`open`/`diagnosed`); folder `features/<f>/` ATAU `fixes/<id>/`; reject bila manifest **closed** (`shipped`/`dropped`).
  - line 16 (staleness) → untuk fix, baseline staleness = `fix.yaml`/`notes.md` (bukan `plans/*` yang mungkin tak ada).
  - line 46 (gate) → saat gate merah karena **penyimpangan** (bukan error), jalankan **disiplin fix yang di-EMBED** (tulis corrective task, lanjut loop) — **bukan** invoke `/fix` (anti-rekursi #6).
  - terima metadata task `kind`/`corrects`/`observed` (traceability; tak mengubah eksekusi).
  - `plans/*`/`_shared.md` **opsional untuk fix 1-unit**; **`_shared.md` mini WAJIB untuk fix lintas-unit** (pembawa kontrak — #3). Konteks implementer untuk fix diambil dari `conventions.md` + pointer file pola + `root_cause` + kutipan `business.md` `relates_to` (eksplisit, bukan asumsi).
  - line 18 (branch) + step 7 (line 50/55) → derive prefix & pesan-selesai per work-item: `feature/<fitur>` (fitur) vs `fix/<id>` (fix); `build` tak mengubah status manifest. (Gap koreksi pasca-implementasi: spec draft awal lupa menyebut langkah branch/selesai.)
- **`ship`:**
  - line 12–13 → baca `feature.yaml` **ATAU** `fix.yaml`; **sumber `unit` = `fix.yaml.units`** (bukan `fanout.md`, yang tak ada untuk fix). [#4]
  - step 2/3 → fix lintas-unit (`units` >1) **tetap** menjalankan contract/smoke test (step 3) terhadap `_shared.md` mini fix. Fix 1-unit lewati (seperti fitur 1-app). [#4]
  - step 4.5 (Security Gate) → baca `sensitivity` dari `fix.yaml` (**hasil re-evaluasi**, #5) + cross-check `invariants.md`/`integrations.md`.
  - step 6 → desc PR fix dari `root_cause` + diff; set `fix.yaml` `status: shipped` + `shipped_at` + `fix_pr`.
  - line 50 (guard) → terima `fix.yaml` `open`/`diagnosed`.
  - step 2 (business-alignment) → untuk fix, `critic` bandingkan vs `root_cause` + kutipan `business.md` `relates_to` (`plans/<app>.md` tak ada); `relates_to: []` → `root_cause`/`invariants.md` saja. step 6 (runbook integrasi) → gate "bila **work-item** kena vendor" (fix yang menyentuh vendor existing tetap perlu runbook).
- **`breakdown` (BERUBAH — draft pertama keliru bilang "tak ada perubahan wajib"):** step 7 (merge yang mempertahankan status) **wajib mempertahankan task `kind: fix`** yang tak punya asal-`plan` — kalau tidak, re-`breakdown` membuang corrective task in-flight diam-diam → bug ter-regress (#2). Penulis sah `tasks.yaml` fitur tetap `breakdown`, tapi `fix`/`build` boleh **append** task `kind: fix`; `breakdown` mengenalinya sebagai task yang dipertahankan, bukan di-regenerate.
- **`drop`:** **TIDAK** diberi fix-id (hindari setengah-generalisasi skill kedua — #8). `fix` self-handle `dropped`.
- **`render-docs` (perubahan SUBSTANSIAL, bukan opsional — #10):** baca direktori baru `control/fixes/`, render section **"Riwayat Fix / Known Issues"** (kartu severity, link `relates_to`+`flow`). **Trigger:** selain saat `ship` (untuk fix `shipped`), `fix` **memicu/mengingatkan** regenerate saat `fix.yaml` jadi `open`/`diagnosed` — kalau tidak, "Known Issues" tak muncul ke stakeholder sampai ada `ship` lain tak-berhubungan.

**Kenapa A, bukan "build/ship dibekukan":** karena `/ship <fix>` dipanggil terpisah, `ship` **mau-tak-mau** harus fix-aware. Membekukan tidak menyelamatkan apa pun; dua eksekutor yang harus dijaga-sinkron justru bibit drift (induk §4: "satu sumber kebenaran").

## 12. Orkestrasi & Batas Sesi

- **`fix` tak pernah auto-`ship`.** Selalu berhenti di ijo/"siap ship". `ship` = `/ship` eksplisit terpisah.
- **in-flight tak menyentuh `ship`** — fitur tetap `active`, ship nanti sekalian fitur.
- **post-ship boleh menawarkan** "lanjut `/ship`?" di akhir, **default STOP**.
- **Konteks ramping — dijaga sungguhan:** reproduce **dan** root-cause **dan** implementasi semuanya di-dispatch ke **subagent**; sesi `fix` konduktor hanya menampung kesimpulan + status (bukan investigasi). [#11]

## 13. Dampak ke Komponen Existing

- **Skill baru:** `plugin/skills/fix/SKILL.md` (+ kemungkinan `reference.md` delta khas-fix: reproduce-first, root-cause-subagent; sebagian besar sandar `build/reference.md`).
- **`build/SKILL.md`:** generalisasi manifest (line 15) + staleness baseline (16) + embed disiplin fix di gate merah (46, bukan invoke `/fix`) + terima metadata `kind`/`corrects`/`observed` + aturan konteks/`_shared.md` untuk fix + branch & pesan-selesai per work-item (18, 50, 55).
- **`breakdown/SKILL.md`:** step 7 pertahankan task `kind: fix` tanpa asal-plan (BERUBAH).
- **`ship/SKILL.md`:** baca `feature.yaml`/`fix.yaml`; unit dari `fix.yaml.units`; step 3 contract test fix lintas-unit; Security Gate baca sensitivity fix; set status di manifest tepat; business-alignment & runbook integrasi per work-item.
- **`render-docs/SKILL.md`:** baca `control/fixes/`; section "Riwayat Fix/Known Issues" (severity-sorted, link feature/flow); trigger saat status fix berubah (SUBSTANSIAL).
- **`control/` template:** `control/fixes/.gitkeep`.
- **`invariants.md`:** dibaca di triage fix (re-evaluasi sensitivity) + Security Gate — bukan komponen baru, tapi titik-baca baru.
- **spec induk:** §7 tambah `fixes/`; §12 tambah lane `fix` + tabel status fix; §17 jumlah skill +1.
- **`README.md`** & **`plugin/.claude-plugin/plugin.json`/`marketplace.json`:** tambah `/fix`.

## 14. Scope v1 & Future

- **v1 (in):** skill `fix` dua-mode (§6, §7), tabel keputusan mode (§4), triage 3-arah + tripwire + sensitivity re-eval (§8), recording first-class skema-sama (§9), status (§10), work-item generalization + koreksi `build`/`ship`/`breakdown`/`render-docs` (§11), orkestrasi ship-terpisah + subagent root-cause (§12).
- **Future:** auto-ingest report (issue tracker/Sentry); dedup laporan + severity→SLA/on-call (saat ada konsumen nyata, naikkan lagi granularitas severity); rollback terbantu; metrik MTTR/recurrence per flow; cache pola root-cause berulang; `fanout` penuh untuk fix (ganti unit-inference lemah) bila bug lintas-app jadi sering.

## 15. Open Questions (untuk tahap perencanaan)

Yang **sudah diputuskan** (tak lagi terbuka, hasil pass critic): drop-ownership (`fix` self-handle), in-flight eksekusi (`fix` panggil `build` inline; `build` embed disiplinnya sendiri), severity (2-tingkat), sensitivity (re-evaluasi), knowledge-drift (triage cabang-3), tabel mode (§4).

Yang **masih terbuka:**
- **Format slug fix id:** `<YYYY-MM-DD>-<slug>` (default, sortable) vs counter. Usul: tanggal+slug.
- **`fix/reference.md` terpisah** vs murni sandar `build/reference.md`? Sebagian besar template dispatch identik; mungkin cukup pointer + delta reproduce/root-cause. Diputuskan saat implementasi.
- **Milestone untuk `tasks.yaml` fix:** satu milestone `fix` generik, atau ikut nama milestone fitur yang dikoreksi (in-flight)? Default usul: in-flight ikut milestone task `corrects`-nya; post-ship satu milestone `fix`.
- **`render-docs` "Known Issues" ambang tampil:** semua `open`/`diagnosed`, atau hanya `urgent`? Default usul: semua, urut severity (transparansi).
- **Kutipan `business.md` ke prompt implementer fix:** seberapa banyak konteks bisnis yang dipaste (seluruh `business.md` fitur `relates_to` vs ringkasan)? Diputuskan saat implementasi (trade konteks vs token).
