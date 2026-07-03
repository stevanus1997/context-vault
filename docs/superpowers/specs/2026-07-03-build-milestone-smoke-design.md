# Design — Milestone Smoke + "Coba Sendiri" di Gate `build` (+ propagasi `fix`, Part-A `tweak`)

- **Tanggal:** 2026-07-03
- **Status:** Disetujui (brainstorming) → siap plan implementasi
- **Area kena:** `plugin/skills/build/SKILL.md` (step 6), `plugin/skills/build/reference.md` (§D), `plugin/skills/tweak/SKILL.md` (step 5), `plugin/skills/tweak/reference.md` (§E). **`fix` TIDAK disentuh** (keikut gratis — pinjam mesin `build`).

---

## 1. Konteks & Masalah

Dua keluhan nyata pas jalanin `build` per-milestone:

1. **Gate nggak proaktif nyodorin apa yang bisa dites.** Tiap milestone `build` berhenti di gate step 6 & inform user, tapi user harus **mancing sendiri** tiap kali: "test case apa yang lulus?" + "ada yang bisa gue test manual dulu nggak?". Yang gate tampilin sekarang (`build/SKILL.md:52`) cuma: diff segmen + **hasil test** (diringkas jadi "N/N ijo") + "dibangun vs task" + challenge checklist. Nggak ada daftar test-case eksplisit, nggak ada resep smoke manual.

2. **Self-test `build` cuma parsial & kondisional.** Yang ada sekarang:
   - **TDD per task** (step 3) + **controller re-run test** (step 4) — automated, **selalu**.
   - **Boot app NYATA + roundtrip** — **cuma** task `unit: integration`.
   - **Buka app + eyeball UI** — **cuma** task ber-`mockup:`.

   Endpoint API biasa / UI non-mockup **nggak pernah di-hit live**. Akibatnya "lulus unit test" ≠ "beneran jalan end-to-end". Nggak ada mekanisme generik yang boot app + curl endpoint yang baru dibangun + lihat response nyatanya per milestone.

> Catatan pembatas: harness sudah punya skill built-in `/verify` & `/run` yang konsepnya persis untuk (2), tapi `build` **tidak** memanggilnya sekarang. Desain ini **meminjam pola**-nya (boot via stack) di dalam subagent `build`, **bukan** invoke skill-nya (lihat D5/D9).

## 2. Tujuan & Non-Tujuan

**Tujuan**
- Gate `build` proaktif nyodorin **test-case lulus + resep verifikasi manual** tiap milestone (**Part A**).
- `build` **beneran boot + drive** surface yang dibangun (auto + lapor) buat milestone ber-surface yang **belum** ke-cover `integration`/`mockup` (**Part B**).
- `fix` **keikut otomatis** (pinjam gate `build`) — jadi verifikasi fix end-to-end, bukan cuma unit-test ijo.
- `tweak` dapet **Part A doang** di gate-nya — konsisten, murah, **tanpa** boot.

**Non-Tujuan (YAGNI)**
- **Tidak** mengubah TDD / review dua-verdict / floor-scan / Security Gate `ship`. Ini nambah *surfacing* + satu *smoke pass* — **bukan** gate baru yang mblokir (kecuali smoke mengungkap milestone rusak → jalur deviasi yang SUDAH ada).
- **Tidak** mengubah `breakdown` (skema/bobot task tetap; resep smoke diturunkan di `build` dari field yang sudah ada — konsisten dengan cara bobot-budget diturunkan).
- **Tidak** menambah Part B (auto-boot) ke `tweak` (langgar DNA: ringan, inline, single-session, non-resumable).
- **Tidak** nge-smoke `unit: package` / `unit: integration` / task `mockup:` / milestone logika-murni.
- **Tidak** menggantikan smoke roundtrip `ship` step 3 (itu **final**, lintas-app; ini **per-milestone**, single-surface — komplementer & lebih dini).
- **Tidak** mengubah model bobot cap-volume unattended (§D) — bobot itu look-ahead per-task; smoke terjadi per-segmen di gate.

## 3. Keputusan Desain (terkunci)

| # | Keputusan |
|---|---|
| **D1** | **Part A — surfacing (selalu, murah, tanpa boot).** Gate `build` step 6 nambah section **"Coba sendiri"**: (a) daftar **test-case lulus** eksplisit dari `test:` task-task segmen (bukan cuma "N/N ijo"); (b) **resep verifikasi manual** (perintah `curl` / URL "buka …") untuk surface yang dibangun. Muncul di **SEMUA** gate — milestone logika-murni → resep kosong, test-case tetap tampil. |
| **D2** | **Part B — self-smoke (auto + lapor).** Untuk segmen yang qualify (D3), `build` dispatch **smoke subagent** (pola *file-handoff*, sama seperti task `unit: integration`): boot app (D5) → jalankan resep D1 terhadap app hidup → tangkap **observasi nyata** (status + shape response untuk API; screenshot/eyeball untuk UI) → tulis ke report file → balikan status ringkas. Gate menampilkan observasi **di sebelah** resep. |
| **D3** | **Trigger Part B.** Jalankan smoke bila segmen **nyentuh runnable surface** (HTTP route / UI page), **create ATAU modify** (`modify` penting — `fix` biasanya ngedit endpoint existing), **DAN** surface itu **belum** di-boot task `unit: integration`, **DAN** bukan task `mockup:` (sudah eyeball + buka app). Selain itu → **skip Part B** (Part A tetap jalan). `unit: package`/`integration` → skip Part B. |
| **D4** | **Deteksi "runnable surface"** = heuristik **ringan** di `build` atas `unit` + `files` + diff (file cocok konvensi routing app / page-component). **Ragu → default skip Part B** + catat "surface tak jelas — smoke di-skip" (advisory, **bukan** palang). Tidak ada mesin deteksi berat baru; reuse yang `build` sudah tahu (`unit`, `files`, diff yang sudah di-scan floor-scan). |
| **D5** | **Stack-agnostic, in-subagent.** Boot + resep diturunkan dari `workspace.yaml` `stack` **saat runtime** — **mekanisme yang SAMA** dengan boot task `unit: integration` (`build/SKILL.md:28`) + smoke `wire` §E + `actions`. Port/URL dari env-contract `wire`. **Meminjam pola** `/run`/`/verify` (boot per jenis-project), **bukan** invoke skill-nya (anti cross-skill-invoke; konsisten dengan `build` yang minjem template `subagent-driven-development` tanpa invoke). `build` tak pernah hardcode framework. |
| **D6** | **Environment dijamin ada di titik gate.** DB sudah di-`wire`; env/secret ber-`manual:` sudah lewat `needs_human` step 2. Jadi smoke **mengasumsikan** app bisa boot lokal. Smoke hanya melawan **env lokal ter-wire** — **tak pernah** prod; boleh memutasi DB dev lokal (mis. `POST /register` bikin row uji) — dapat diterima. |
| **D7** | **Failure semantics.** (a) **Boot gagal / endpoint 5xx / crash / layar rusak PADAHAL unit-test ijo** → sinyal milestone tak beneran jalan → masuk **disiplin fix yang di-EMBED** step 6 (jalur existing: reproduce → root-cause → corrective `kind: fix`). Attended → STOP di gate; unattended → deviasi → (bila tak self-resolve) `blocked` → `halt`. (b) **Response plausible** → tampil di gate (attended eyeball) / diringkas ke `last-run.md` (unattended) — **bukan** palang. (c) Boot gagal karena prereq lingkungan yang mestinya ada (seharusnya tak terjadi per D6) → laporkan sebagai **blocker lingkungan** (`halt`), bukan corrective task kode. |
| **D8** | **Unattended (M7).** Part B **tetap jalan** (itu tujuannya). Observasi → prosa `last-run.md`. Smoke mengungkap rusak → deviasi/`halt` per D7. Ongkos: **satu boot per segmen qualifying** — **tidak** mengubah model bobot §D. Floor-scan tak terpengaruh (smoke tak menambah diff). |
| **D9** | **Anti-dobel & anti-rekursi.** Smoke **SKIP** yang sudah di-cover `integration` (boot+roundtrip) / `mockup:` (eyeball+buka app) / `ship` step 3 (roundtrip final). `build` **tidak** invoke `/verify`/`/run`/`/fix`/`/debt` sebagai skill — semua disiplin **inline/pinjam-pola**, konsisten dengan arsitektur `build`. |
| **D10** | **Propagasi `fix` — gratis, tanpa edit.** `fix` pinjam gate `build` di dua mode (in-flight `fix/SKILL.md:37`; post-ship `fix/SKILL.md:50`) → **Part A + Part B keikut otomatis**. Trigger D3 (`create` **ATAU** `modify`) memastikan fix (yang ngedit surface existing) ter-smoke. `fix` step 7 "Verify lokal + STOP" tetap (quality gate final, komplementer). **Nol perubahan file `fix`.** |
| **D11** | **`tweak` — Part A doang.** Gate `tweak` step 5 nambah blok **"Coba sendiri"** = test-case lulus + resep manual, diturunkan dari diff (tweak jalankan TDD inline step 3 → murah). **TANPA Part B** (auto-boot) — jaga tweak inline/single-session/non-resumable. Kosmetik murni (tak ada test) → blok di-skip. |

## 4. Arsitektur / Alur

```
build step 6 (per segmen app × milestone, semua task `done`)
   │
   ├── Part A (SELALU): rakit "Coba sendiri"
   │      • test-case lulus  ← dari `test:` task segmen (sudah di memori)
   │      • resep manual      ← dari diff + `files` + port env-contract
   │
   ├── qualify Part B? (D3)  ──no──►  tampil gate (diff + test + dibangun-vs-task
   │      │                                        + challenge + "Coba sendiri" A)
   │     yes
   │      ▼
   │   dispatch SMOKE SUBAGENT (file-handoff, ala unit:integration)
   │      boot app (stack workspace.yaml) → jalankan resep → tangkap observasi
   │      → report file → balikan ringkas
   │      │
   │      ├── observasi plausible ──► tampilkan di gate di sebelah resep
   │      └── boot-fail / 5xx / rusak (unit-test ijo) ──► DEVIASI
   │                                       → disiplin fix embed (step 6 existing)
   │
   └──►  gate: approve / revisi / (deviasi → corrective task)
```

`fix` memakai jalur yang **sama** (pinjam `build`). `tweak` punya jalurnya sendiri (step 5) — cuma cabang **Part A**.

## 5. Contoh Konkret (before → after) — gate milestone M2 `auth` (`POST /auth/register`, `/auth/login`)

**SEBELUM (sekarang):**
```
=== GATE: auth × M2 (api) ===
diff: src/routes/auth/register.ts (+48), src/routes/auth/login.ts (+37), src/routes/index.ts (+4)
test: 6/6 ijo
dibangun vs task: sesuai (register+login + validasi)
challenge checklist: invariant ok · mandatory-pkg ok · redundant-table none · query ok
→ approve / revisi?
```

**SESUDAH:**
```
=== GATE: auth × M2 (api) ===
diff: src/routes/auth/register.ts (+48), src/routes/auth/login.ts (+37), src/routes/index.ts (+4)
test: 6/6 ijo
dibangun vs task: sesuai (register+login + validasi)
challenge checklist: invariant ok · mandatory-pkg ok · redundant-table none · query ok

── Coba sendiri ──────────────────────────────────────────────
test case lulus:
  • register sukses          → 201 + set-cookie
  • register email kepake     → 409
  • register pw lemah         → 422
  • login sukses              → 200 + set-cookie
  • login pw salah            → 401
  • login user nggak ada      → 401
verifikasi manual (app di localhost:3000):
  curl -i -X POST localhost:3000/auth/register -d '{"email":"a@b.co","password":"secret12"}'
  curl -i -X POST localhost:3000/auth/login    -d '{"email":"a@b.co","password":"salah"}'
smoke (auto):
  ✓ POST /auth/register → 201 {id, email}  + Set-Cookie: sid=…
  ✓ POST /auth/login  (pw salah) → 401 {error:"invalid_credentials"}
──────────────────────────────────────────────────────────────
→ approve / revisi?
```

M1 (`hash`/`session`, logika murni) → section "Coba sendiri" **cuma** daftar test-case (resep + smoke kosong: "no runnable surface — skip"). M3 (`login` UI ber-`mockup:`) → smoke Part B **skip** (sudah eyeball+buka app via mekanisme mockup existing).

## 6. Anti-Dobel — layer existing vs smoke baru

| Layer existing | Kapan | Smoke milestone (baru) |
|---|---|---|
| TDD per-task + controller re-run test | selalu | tetap; smoke **bukan** pengganti unit-test |
| Boot + roundtrip `unit: integration` | task integration | smoke **SKIP** segmen yang di-cover-nya |
| Eyeball + buka app `mockup:` | task mockup | smoke **SKIP** (mockup sudah buka app) |
| Roundtrip lintas-app `ship` step 3 | final, sebelum PR | smoke **komplementer** — lebih dini, per-milestone, single-surface |

## 7. File yang Disentuh

- **`plugin/skills/build/SKILL.md` step 6** — tambah Part A (section "Coba sendiri" di presentasi gate) + Part B (dispatch smoke subagent bila qualify D3) + failure semantics D7.
- **`plugin/skills/build/reference.md` §D** — dokumentasikan trigger D3/D4, mekanisme boot D5, unattended D8, contoh §5.
- **`plugin/skills/tweak/SKILL.md` step 5** — tambah blok "Coba sendiri" (Part A doang, D11).
- **`plugin/skills/tweak/reference.md` §E** — penurunan resep manual + test-case di gate tweak.
- **`plugin/skills/fix/*`** — **NOL perubahan** (D10, keikut via pinjam `build`).

## 8. Risiko & Mitigasi

- **Boot mahal / lama** → dibatasi trigger D3 (cuma surface belum-ter-cover) + heuristik D4 default-skip saat ragu; konteks berat boot tetap di subagent (D2) → sesi `build` ramping.
- **Heuristik surface meleset** (false-skip / false-fire) → advisory, bukan palang (D4); false-skip = balik ke perilaku lama (aman); false-fire di segmen tanpa surface = smoke no-op cepat + catat.
- **Smoke flaky** (timing boot) → observasi flaky ≠ deviasi otomatis; boot-fail dibedakan dari endpoint-error (D7); attended user yang judge.
- **Mutasi DB dev** oleh smoke (mis. `register`) → hanya env lokal ter-wire (D6), diterima; bukan prod.
