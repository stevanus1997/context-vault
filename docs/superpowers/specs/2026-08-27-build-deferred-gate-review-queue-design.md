# Desain — Gate ditunda ke antrian review (`gates.yaml`): `build --unattended` tanpa stop-the-world

**Tanggal:** 2026-08-27
**Status:** Disetujui (siap masuk `writing-plans`)
**Scope:** build (step 1–7a + lapor-keluar) · artefak baru `gates.yaml` · `drive.sh` · `wire` 5.5 + `upgrade` (opt-in allowlist migrate) · `intake`/`feature` (arti `risk`) · `ship` (tolak antrian belum kosong) · doc-sync
**Menyusul / mengoreksi:** `2026-06-06-m7-graduated-autonomy-design.md` (D4 + floor `risk:high`), `2026-06-18-unattended-risk-floor-decouple-design.md` (§6 "granularitas per-segmen — out of scope")
**Amandemen arahan M7:** "JANGAN batch/sticky-approve" **dipertegas, bukan dibatalkan** — approve tetap **per gate** (tidak sticky); yang di-batch hanya **waktunya** (drain pagi). Lintas-app sticky tetap dilarang.
**Koreksi pasca-verifikasi 2026-08-27 (diedit di tempat, tiap edit bertanda koreksi):** §3.2 contoh skema → `fitur-x` + kosakata `reason` (+debt fondasional); §3.3 contoh penanda stop + pintu ke-4 unattended; §3.4 filter blast-radius `files:` ATAU `deps:`; §9.4 angka `login`/`generate-website`. **Koreksi review 2026-08-28 (reviewer independen atas d985027..821924e):** §3.3 cross-check DDL jalur-maju (C1), §3.3 `cmd` apply-migrasi (I3), §4.8, §3.4 langkah route debt (I2), §3.4 contoh blast-radius gate-wide (M4), §9.4 catatan downgrade.

---

## 1. Masalah

Operator lapor (2026-08-27): *"build selalu kehalang kehadiran gw — semua task jadi high, nyentuh DB high, nyentuh payment high; build makan berhari-hari dan gw nggak bisa tinggal tidur."*

Fix Juni (`2026-06-18`) cuma menyempitkan **tag** (`pii`-only tak lagi `high`) dan secara eksplisit menunda granularitas (§6). Struktur dasarnya tetap **"berhenti total di floor pertama"**, dengan tiga sebab yang menumpuk — semuanya terverifikasi di produk nyata:

1. **`risk` per-FITUR, bahaya per-TASK.** `feature.yaml risk: high` → `build --unattended` `halt` di ronde-1 sebelum satu task pun jalan (`build/SKILL.md` step 1/6, `reference.md` §G). Produk `branding`: `onboarding`, `login`, `generate-website` semua `high`. `login` = 25 task, `created: 2026-07-22` → siap-ship 2026-07-27 (**5 hari**, seluruhnya attended), padahal T3 (copy), T11/T12 (link "Masuk"), T17 (wordmark) nol bahaya.
2. **"Nyentuh DB → high" dari intake.** Pemicu `high` di `intake/SKILL.md` step 7 memuat *"migrasi skema/data"* — `generate-website` migrasinya `kind: additive` (3 tabel baru), dan task `migrate` sudah punya gate sendiri di build step 3 → 40 task jadi attended karena satu migrasi aditif. Dobel-gate.
3. **Floor-scan menangkap hampir semua diff produk nyata, dan tiap kena = stop the world.** Daftar verba (`tweak/reference.md` §A: validasi input, serialization, role/permission, tenant, session/token, …) sengaja lebar. `simplify-scoring-stp` (BFI, `risk: normal`, `sensitivity: []`, cuma flag-gating form) kena *"validation-gating diff"* → stop attended. `drive.sh` pada `halt` **mati, tak restart** → semua task lain yang aman ikut menunggu manusia.

**Kebutuhan operator:** *"parkir yang butuh gw, sisanya jalan terus, pagi gw review sekaligus."*

## 2. Wawasan kunci — gate memeriksa kode yang SUDAH JADI

Urutan build per task (step 3–5) nol campur tangan manusia: implementer (TDD) → test ijo → commit → reviewer dua-verdict → `status: done`. Gate step 6 muncul **sesudah** semua task segmen `done` — ia memeriksa kode yang sudah ada di branch, sudah di-commit, sudah di-test. Persetujuan manusia tidak "membuka" kode; ia kesempatan berkata "bukan ini maksudku". Dan syarat task berikutnya hanya `deps` berstatus `done` — bukan "sudah di-approve manusia".

Maka gate **bisa ditunda** tanpa mengubah satu pun mekanik dispatch: yang diantrikan adalah **persetujuan**, bukan kodenya. Harga jujurnya: kode dibangun di atas segmen yang belum dilihat manusia → revisi pagi bisa merembet ke dependents (biaya token + satu malam, **bukan** biaya keamanan — tak ada yang mencapai `main` tanpa `ship`).

Alternatif "tunda gate, tapi dependents ikut nunggu" ditolak operator: untuk fitur auth/DB hampir semuanya bergantung ke M1 → hasilnya ≈ sekarang.

## 3. Keputusan desain

### 3.1 Tiga kelas titik-manusia (menggantikan "HARD floor" flat)

| kelas | pemicu | perilaku unattended |
|---|---|---|
| **A. Gate review (ditunda)** | floor-scan kena (verba keamanan/uang — daftar `tweak` §A **tidak dipersempit**); fitur `risk` efektif `high` (tiap segmen); DDL di diff (declared additive → tetap masuk antrian sesudah apply; undeclared → antrian + **TIDAK** di-apply); penyimpangan-dari-maksud (disiplin fix embed tetap jalan otomatis → corrective task; gate-nya diantrikan); smoke Part B gagal padahal unit-test ijo (= penyimpangan) | segmen sudah dibangun + test + review subagent → entri `queued` di `gates.yaml` (+ `security-critic` otomatis bila alasan verba keamanan/uang ATAU `sensitivity` non-kosong) → **lanjut** dispatch |
| **B. Blocker (subtree nunggu)** | `migrate` destructive/backfill (approve sebelum apply); `migrate` additive tapi perintah apply belum di-allowlist; `needs_human` (`manual:`); `blocked` (error / mentok 3 ronde review); implementer `NEEDS_CONTEXT` yang jawabannya harus dari user; task konflik pre-flight (invariants/mandatory package) | task ditandai (`needs_human`/`blocked`, vocab existing) + dilewati scheduler; dependents otomatis tak ready (deps belum `done`); **task lain yang tak bergantung lanjut**. Circuit breaker tetap: 2 `blocked` berakar sama → `halt` |
| **C. Auto-approve** | segmen bersih: nol floor, test ijo, "dibangun vs task" cocok, `risk` efektif low/normal | lanjut; entri `auto` di `gates.yaml` (jejak audit) |

**Arti baru `risk` fitur — bukan kill-switch:**
- `high` → **semua** segmen `queued` (nol auto-approve), build tak pernah berhenti karenanya. `login`/`onboarding` jadi "review semua pagi", bukan "nunggu dari menit pertama".
- `normal`/`low` → floor-scan memutuskan per segmen (seperti sekarang).
- Degrade `sensitivity:payments → high` **tetap** (kini non-blocking → aman dipertahankan).
- Fitur lama yang terlanjur `high`: **nol pemulihan manual** — langsung mendapat perilaku "semua gate diantrikan".

**Mode attended (`build <fitur>` tanpa flag) tidak berubah:** tetap berhenti per gate — kalau manusia memang duduk di situ, review-sebelum-dibangun-di-atasnya adalah yang termurah. Bedanya hanya: bila ada entri `queued` / blocker dari malam sebelumnya, attended **menguras antrian dulu** (drain, §3.5).

**`outcome` di `last-run.md` — empat nilai:**
- `continue` — masih ada task ready & cap-volume kena → driver restart.
- `review` — **BARU.** Tak ada lagi yang bisa dibangun tanpa manusia: ada `queued` dan/atau blocker kelas B, tapi **tak ada yang rusak** → driver berhenti, notif *"N gate + M blocker nunggu lo"*.
- `halt` — hanya **abnormal**: circuit-breaker, blocker lingkungan (allowlist kosong/permission/env), state korup. Arti: "ada yang rusak, bukan tinggal jawab".
- `done` — semua task `done` **DAN** antrian kosong **DAN** simplify 7a lolos → siap `ship`.

**Presedensi:** `halt` > `continue` > `review` > `done`. (`continue` di atas `review`: selama ada yang bisa dibangun, bangun dulu; antrian persisten.)

### 3.2 Artefak: `gates.yaml` + header `last-run.md`

**Prinsip:** `tasks.yaml` **nol status baru** (hormati keputusan spec lanes 2026-07-21 yang menolak status `parked`); satu-satunya tambahan = field opsional build-written `hold:` (preseden `commits:`). Kelas B hidup di `tasks.yaml` pakai status existing; kelas A/C hidup di file baru.

**`control/features/<fitur>/gates.yaml`** — penulis tunggal `build`; ke-commit bareng `control/` (durable, resumable, pulih dari git seperti `tasks.yaml`). Hanya work-item **fitur** (fix selalu attended → tidak punya).

```yaml
feature: fitur-x
gates:
  - id: G1                          # urut kronologis penulisan (G1, G2, …); satu segmen boleh muncul >1 kali (per due-event)
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

**Kelas B di `tasks.yaml` — vocab existing, nol status baru, satu field opsional build-written:**
- `migrate` destructive/backfill menunggu approve, ATAU additive tapi perintah apply belum di-allowlist → task **`needs_human`** (kode migrasi sudah di-commit & lolos review subagent; **`commits:` ditulis saat hold** agar tak hilang). Semantik pas: "menunggu manusia sebelum action jalan" — identik `needs_human` untuk `manual:`, jalur resume sudah ada (§E: konfirmasi → jalankan action → `done`). Beda hanya titik masuk: `manual:` terdeteksi sebelum dispatch, migrate sesudah implementer.
- `NEEDS_CONTEXT` yang harus dijawab user → `needs_human` (jangan ditinggal `in_progress` — resume §E akan salah reconcile).
- Konflik pre-flight → `needs_human`.
- **Field `hold:`** (OPSIONAL, ditulis `build` saat men-set `needs_human` bukan-karena-`manual:` — preseden `commits:` yang juga opsional & build-written; **bukan** status baru): satu baris alasan yang self-describing & durable, mis. `hold: "migrate destructive — nunggu approve (kind: destructive, affects: brands.kit)"` · `hold: "allowlist migrate absen — wire 5.5"` · `hold: "NEEDS_CONTEXT: <pertanyaan implementer verbatim>"` · `hold: "konflik invariant Tenancy — task ini nulis query tanpa filter tenant"`. Drain (§3.4) membaca `hold:`; absen (task `manual:` / `tasks.yaml` lama) → derive dari bentuk task (ada `manual:` → checklist manual; ada `actions: migrate` → migrate) — degrade, bukan error. Prosa `last-run.md` **menyalin** `hold:` (bukan sumber kebenaran — ia ditulis ulang tiap stop). `hold:` dihapus saat task keluar dari `needs_human`.
- `blocked` tetap `blocked` (alasan = objeksi reviewer/error di report file scratch + prosa, seperti sekarang). Task yang di-hold **tidak pernah** ditinggal `in_progress`.

**Header mesin `last-run.md`** (baris pertama dibaca `drive.sh`; dua baris baru opsional untuk manusia/notif — driver toleran bila absen):
```
outcome: review
done: 25
pending: 0
review: 6          # BARU — jumlah gate `queued`
blockers: 1        # BARU — jumlah task needs_human/blocked
reason: 6 gate menunggu review (G1–G4, G6, G7) + T7 migrate destructive nunggu approve
```
Prosa: daftar antrian (segmen + alasan + 1 baris ringkas diff), daftar blocker + apa yang dibutuhkan (termasuk pertanyaan `NEEDS_CONTEXT` verbatim), daftar `auto`, banner **DIBANGUN UNATTENDED** bila ada `auto` yang menyentuh area sensitif.

**Scratch** (`.claude/build/<work-item>/`, sudah gitignored oleh `init`): `gate-Gn-critic.md`, `gate-Gn-impact.md`. Diff segmen **tidak** bikin file baru — pakai paket `review-<base7>..<head7>.diff` per task yang sudah ada; hilang → regenerate dari `commits:` via git. Critic hilang → re-run saat drain (degrade, bukan error).

**Pembaca lain:** `ship` step 1 (ada `status: queued` → **BERHENTI**, arahkan ke `build`; sejajar cek "semua task done") + step 6 (body PR: daftar gate `auto` + `approved` — jejak siapa-review-apa); `ask` (tabel Status: baris `gates.yaml`, read-only). Higiene commit `gates.yaml` = `tasks.yaml` (§F: tak commit ke repo yang lane-nya in-flight).

### 3.3 Alur unattended — perubahan `build` per step

**Step 1 — baca state & prasyarat**
- Baca `gates.yaml` (absen → kosong). Entri `queued` dari run sebelumnya **tidak menghalangi** run baru (keputusan operator: bangun di atasnya). Tak ada lagi yang bisa dibangun → langsung `review` (idempoten, nol kerja).
- **Hapus** klausa `risk:high → halt dini ronde-1`. `risk` efektif hanya menentukan: `high` = tiap segmen `queued`.
- **Pre-flight conflict sweep:** dulu unattended → `halt` total. Baru: task konflik → `needs_human` + `hold: "konflik …"`, task lain lanjut. Attended tetap satu pertanyaan batched.
- Precheck allowlist tetap (kosong → `halt`). Tambah WARN: ada task migrate additive tapi perintah apply belum di-allowlist → "bakal di-hold, jalankan `wire` 5.5".

**Step 2 — scheduler**
- READY-SET (`pending` yang semua `deps` `done`) **nol perubahan**; `needs_human`/`blocked` bukan `pending` → dilewati, dependents tak pernah ready. Subtree-nunggu **gratis**.
- `manual:` belum dikonfirmasi → `needs_human`; dulu "STOP SELURUH build" → unattended: tandai + lanjut task lain. Attended tetap tanya langsung.
- Urutan atomik (completion → evaluasi gate → tick) tetap; di unattended evaluasi gate **tak pernah STOP-dispatch** — hanya menulis `gates.yaml` (+ dispatch critic).

**Step 3 — dispatch + actions**
- `migrate` unattended, baca `kind`:
  - **`additive`** → (1) **cross-check deterministik (koreksi review 2026-08-28 — C1):** grep **HANYA jalur maju** file migrasi (Alembic `def upgrade()`, goose `+goose Up`, sqlx `*.up.sql`; `.sql` tanpa pemisah = seluruh file), abaikan komentar & seluruh bagian downgrade/rollback — migrasi additive jujur PASTI punya `drop_*` di downgrade; versi awal spec ini men-grep seluruh file → SEMUA migrasi Alembic ter-hold "kind bohong" dan auto-apply tak pernah nyala (ditemukan review atas file T7 `generate-website` asli) — cocokkan per-statement untuk verba destruktif (`DROP`, `RENAME`, `ALTER … TYPE`, `SET NOT NULL` tanpa default, `TRUNCATE`, `DELETE FROM`, `UPDATE … SET`, `op.drop_*`/`op.rename_*`) — kena = `kind` bohong → perlakukan destructive; (2) perintah apply di-allowlist? tidak → hold `needs_human` + `hold: "allowlist migrate absen — wire 5.5"`; (3) jalankan `rules/migration-impact.md` → `gate-Gn-impact.md`; (4) apply + verifikasi + regen `control/schema/<unit>.md` (M4) → `done`; gate segmen nanti `queued` ("ddl additive Tn (auto-applied)").
  - **`destructive`/`backfill`** → task `needs_human` + `commits:` + `hold:` → lanjut task lain. Pagi: approve → apply → `done`.
  - **`kind` absen** (breakdown lama) → fail-safe destructive (hold) + ingatkan lengkapi.
  - Attended: tidak berubah (tampilkan rencana + dampak + approve). **Koreksi review 2026-08-28 (deviasi eksekutor, DIPERTAHANKAN — I3):** `actions: cmd` yang ternyata perintah apply-migrasi (cocok prefix opt-in `wire` 5.5 / tool migrasi `stack.orm`) → diperlakukan `migrate` tanpa `kind` — attended: GATE (bukan auto); unattended: fail-safe destructive → hold. Menutup bypass nyata pasca opt-in (`cmd: alembic upgrade head` akan dieksekusi harness tanpa cross-check). Ini SATU-SATUNYA perubahan perilaku attended (lihat §4.8).
- `NEEDS_CONTEXT` yang harus dijawab user → `needs_human` + `hold: "NEEDS_CONTEXT: <pertanyaan>"` (controller tetap mencoba menjawab sendiri dulu, seperti sekarang).
- Brief implementer +1 kalimat: *"DDL di luar `actions: migrate` dilarang; jangan apply migrasi ke DB di luar action"* (menutup jalur undeclared-DDL mencuri apply).

**Step 4 — verifikasi + review:** nol perubahan. Mentok 3 ronde → `blocked` → unattended lanjut task lain.

**Step 5 — status:** `blocked` dulu STOP; unattended → lanjut lane lain. Circuit breaker tetap (2 `blocked` berakar sama → `halt`). Attended tetap drain + agenda.

**Step 6 — gate per segmen (inti)**
Segmen due → evaluasi seperti sekarang (floor-scan verba+DDL, `risk` efektif, "dibangun vs task", smoke Part B), lalu **bukan berhenti**:
- **Bersih + `risk` low/normal** → entri `auto` → lanjut.
- **`risk:high` / floor-scan / DDL / penyimpangan / smoke gagal** → entri `queued` (alasan spesifik) → bila alasan verba keamanan/uang ATAU `sensitivity` non-kosong → dispatch **`security-critic`** (agent existing, read-only; input = path diff per task + `invariants`/`conventions`/`integrations`/`risks`) → `gate-Gn-critic.md` → lanjut. Critic tak menghalangi dispatch task berikutnya; wajib selesai sebelum `last-run.md` ditulis. Critic **tidak** dihitung bobot cap-volume.
- **Penyimpangan / smoke gagal** → disiplin fix embed otomatis (reproduce → root-cause → corrective `kind: fix` ke `tasks.yaml`, **milestone yang sama**) → gate `queued` "penyimpangan → corrective Tn". Corrective kelar → segmen due lagi → entri gate baru.
- **Undeclared DDL** → `queued` "ddl undeclared Tn (TIDAK di-apply)".
- Pintu ke-4 (debt): fondasional saat unattended → APPEND `open` `owner: foundation` ke `control/debt.yaml` + gate segmen `queued` "debt fondasional Tn: <1 baris>" (drain pagi memutuskan route-nya — koreksi 2026-08-27 pasca-review); guard smoke lintas-app (lane): nol perubahan.
- Challenge checklist **tidak disimpan** malam itu — drain mengevaluasi ulang live.

**Step 7 / 7a**
- Semua task `done` tapi ada `queued` → **JANGAN** jalankan 7a (revisi pagi bisa mengubah diff) → `review`.
- Tak ada `queued` (semua `auto`) → 7a seperti sekarang; floor kena → gate `simplify` `queued` → `review: 1`.
- `done` = semua `done` + antrian kosong + 7a clear.

**Lapor-keluar:** presedensi §3.1; `.unattended-stop` satu baris (mis. *"review: 6 gate + 1 blocker — build fitur-x"*); banner, notif via hook: nol perubahan mekanik.

### 3.4 Alur pagi — drain (attended)

**Pemicu:** `build <fitur>` tanpa flag; step 1 menemukan `queued` di `gates.yaml` **atau** `needs_human`/`blocked` di `tasks.yaml` → **mode drain** sebelum dispatch apa pun. (`--unattended` lagi = skip drain: lanjut bangun, atau `review` bila tak ada yang bisa dibangun.)

**Urutan sajian:**
1. **Ringkasan** (`last-run.md` + `gates.yaml`): *"Semalam: 25 done · 6 gate queued (G1–G4, G6, G7) · 1 blocker (T7 migrate destructive) · 1 auto (web×M5)."*
2. **Re-run test sekali per repo** (baseline segar; prinsip "jangan percaya laporan").
3. **Gate `queued` urut G-id (tertua dulu)** — revisi di G1 paling mungkin merembet ke bawah.
4. **Blocker** (`needs_human`/`blocked`) sesudahnya.
5. Daftar `auto` ringkas, nol aksi.

**Tiap gate = UX gate step 6 + bukti semalam:** header (segmen · task · commits · alasan · tanggal) · diff per task · hasil test + "dibangun vs task" · **Challenge checklist dievaluasi live** · temuan security-critic (hilang → jalankan sekarang) · laporan migration-impact bila ada · observasi smoke · **"Kalau direvisi, yang kena:"** = task yang dibangun *sesudah* gate ini — yaitu (a) task milik entri gate ber-G-id **lebih besar**, plus (b) task `done` yang belum masuk entri gate mana pun (segmennya belum due) — yang `files:`-nya tumpang-tindih dengan `files:` task gate ini ATAU punya jalur `deps:` (langsung/transitif) ke salah satu task gate ini (deterministik dari `gates.yaml` + `tasks.yaml`; superset — under-report hanya bila `deps:` bolong — koreksi 2026-08-27 pasca-verifikasi: filter `files:` saja cuma menghasilkan {T13, T15} untuk contoh ini, karena konsumen kontrak `produces:` tak mengedit file produsennya; contoh G1 `login` = {T1,T2,T3} **gate-wide** (hitungan review 2026-08-28): 17 task — 14 via jalur `deps:` + T19/T22/T23 via `auth/copy.ts` milik T3; kalau dihitung untuk T1 saja: 11 task ⊇ {T4, T5, T9, T10, T13, T15}. Aturan §I = gate-wide, jangan meniru hitungan per-task) · "Coba sendiri" Part A · **bila `reason` diawali "debt fondasional"** → tampilkan entri debt provisional + minta route eksplisit (`/architect`·`/add-package`·`/wire`·catat sadar), catat di `decision:`, hapus awalan provisional (koreksi review 2026-08-28 — I2) · → **approve / revisi** — **per gate, tanpa "approve semua"**.

**Keputusan:**
- **approve** → `approved` + `decided_at` + `decision: approve`.
- **revisi** → corrective `kind: fix` (`corrects: [T..]`, `observed: <keberatan>`) ke **milestone yang sama** (pola T13–T17 `login`) → segmen due lagi → entri gate baru. Gate ini → `revised` + `decision: "revisi: <1 baris> → corrective Tn"`.
- Tulis **atomik** satu entri per operasi (pola `tasks.yaml` §E). Sesi mati mid-drain → `build` berikutnya lanjut dari `queued` tersisa.

**Blocker per jenis** (jalur existing, dikumpulkan; jenis dibaca dari `hold:` — absen → derive dari bentuk task):
- `needs_human` (`manual:`) → checklist → konfirmasi → actions → `done`.
- `needs_human` (migrate destructive/backfill) → rencana + `migration-impact` → approve → apply → verifikasi → regen skema → `done`. Tolak → pilih: corrective task ATAU balik `breakdown`.
- `needs_human` (allowlist migrate absen) → approve apply sekarang (attended, permission prompt normal) ATAU jalankan `wire` 5.5 dulu.
- `needs_human` (`NEEDS_CONTEXT`) → tampilkan pertanyaan dari `hold:` → jawab → re-dispatch dengan jawaban di-paste; hapus `hold:`.
- `needs_human` (konflik pre-flight) → tampilkan → override sadar (reset `pending`) ATAU revisi via `breakdown`.
- `blocked` → objeksi/error → arah user → reset eksplisit `pending` (tetap tak auto-retry).

**Akhir drain — STOP + ringkasan, bukan otomatis lanjut bangun.** Tulis ulang `last-run.md` (`outcome` `continue`/`review`/`done` + prosa "drain pagi: G1 approve, G2 revisi → T26 …"), lalu tanya sekali: *"lanjut attended sekarang, atau berhenti biar `drive.sh` yang lanjutin malam ini?"* — jangan kembali ke pola "harus ada manusia" tepat sesudah dibongkar.
Semua `done` + antrian kosong sesudah drain → 7a (gate attended) → `done` → *"siap di-`ship`"*.

### 3.5 Driver, hook, `/schedule`, allowlist migrate

**`drive.sh`** (template; `upgrade` menyusulkan produk lama — file generik, ganti versi baru dengan GATE diff):
- cabang `review` → *"[drive] outcome=review → N gate + M blocker nunggu lo 🔔 — pagi jalankan `build <fitur>` buat drain"* → `break`. N/M dari baris `review:`/`blockers:` (absen → tanpa angka).
- pesan `halt` dipertegas: *"abnormal (circuit-breaker/env/allowlist/state) — cek `last-run.md`"*.
- rem nol-kemajuan, deadline, precheck (notify/allowlist/trust): **nol perubahan**. `continue` hanya bila ada task ready → `done` pasti naik → rem sehat.
- komentar header: 4 outcome.

**Hook `on-stop.sh`/`on-permission.sh`: nol perubahan.** Migrate additive yang belum di-allowlist tak pernah dicoba (hold dulu) → hook permission tak terpancing beku.

**`/schedule` (§H Engkol 2):** `review` diperlakukan seperti `halt` — run berikutnya `review` lagi (nol kerja, notif berulang) → pause/hapus routine sampai drain.

**Allowlist apply-migrate — `wire` 5.5 + `upgrade` (satu-satunya aturan harness yang berubah):**
- 5.5 kini *"JANGAN pernah masukkan apply-migrate"* → diubah: apply-migrate **boleh HANYA lewat opt-in eksplisit terpisah** — pertanyaan sendiri di GATE 5.5: *"Izinkan `build --unattended` apply migrasi `kind: additive` otomatis? (skip = additive bakal nunggu lo tiap pagi)"*. **Default skip.**
- Perintah diturunkan **by-understanding dari `stack.orm`/tool migrasi** unit (`alembic upgrade`, `prisma migrate deploy`, `drizzle-kit migrate`, `supabase db push`, `sqlx migrate run`, `goose up`, …) — bukan daftar tetap. Bentuk `Bash(<perintah>:*)` (prefix; wildcard-tengah mati).
- **Deny cermin** ditambah bareng opt-in: rollback/reset tool yang sama (`alembic downgrade`, `prisma migrate reset`, `supabase db reset`, …). Rollback = keputusan manusia.
- **Model kepercayaan (ditulis jujur di 5.5):** harness tak bisa membedakan additive vs destructive — ia hanya melihat perintah. Pagar destructive = rantai plugin: `kind` ditulis `breakdown` → di-approve user di gate breakdown → cross-check grep DDL saat apply → hold bila bohong. Mengizinkan perintah ini = memercayai rantai itu — model kepercayaan yang **sama** dengan `git commit` yang sudah di-allowlist.
- `upgrade` step 2/4 menawarkan opt-in yang sama untuk produk lama (domain `.claude/`). Precheck `drive.sh` **tidak** mengecek ini (tak tahu stack; build yang handle via hold + alasan jelas).

**Kimi (`plugin-kimi`, `tools/build-kimi.sh`):** `--unattended` tetap DITOLAK di Kimi. **Drain pagi = attended → jalan di Kimi** (state di disk, pola hybrid README). Generator nge-anchor heading pertama ber-"unattended" di `reference.md` (§G) → **heading tidak diganti**; `tools/tests/build-kimi.test.sh` wajib ijo pasca-regen.

### 3.6 `intake`/`feature`, doc-sync, amandemen spec

- **Scaffold `feature.yaml`** (intake ≈21 = feature ≈23, **byte-identik**, nol bocor `: ` ke value — BUG-GUARD 2026-06-18): `risk: normal           # (M7) low | normal | high — blast-radius build; high = SEMUA gate segmen masuk antrian review saat unattended (bukan kill-switch); payments-movement → floor high (hard), pii saja tidak`.
- **`intake` step 7:** pemicu `high` *"migrasi skema/data"* → *"migrasi destructive/backfill atas tabel existing (tabel/kolom baru additive TIDAK memicu)"*; pemicu lain tetap; +1 kalimat arti baru `high`; degrade `sensitivity:payments → high` tetap.
- **`upgrade` step 4** bullet "fitur lama ter-floor `risk:high`" → opsional: *"turunkan ke `normal` bila ingin sebagian auto-approve; tanpa itu semua gate diantrikan (tak lagi halt)"*.
- **Doc-sync** (nol skill baru → 25 tetap): `build/SKILL.md` description ("auto-approve segmen risk rendah" → "gate ditunda ke antrian review (`gates.yaml`), blocker subtree-only"); `breakdown/reference.md` komentar migrate (§A ≈36: "DESTRUKTIF → GATE" → "additive → auto-apply unattended bila di-allowlist; destructive/backfill → GATE"); `guide/reference.md` cheatsheet `/build`; `ask` tabel Status (+ baris `gates.yaml`); README seksi M7 + status; `plugin.json` description + **bump `0.23.0`**; regen `plugin-kimi`.
- **Spec M7 (`2026-06-06`)**: **append** amandemen bertanggal (sejarah dipertahankan): gate ditunda; `risk:high` bukan kill-switch; additive auto-apply opt-in; arahan "JANGAN batch/sticky-approve" dipertegas (per-gate, batch waktu saja). **Spec `2026-06-18` §6**: +1 baris pointer "terpenuhi 2026-08-27 lewat antrian, bukan tag per-task".

## 4. Invarian keamanan yang DIJAGA

1. **Security Gate `ship` utuh**; `ship` **menolak** bila ada `queued`. Tak ada auto-merge/push dari build — PR tetap jatah `ship` (attended).
2. **Destructive/backfill tak pernah auto-apply**; `kind: additive` di-cross-check grep DDL saat apply.
3. **Floor-scan tidak dipersempit**; tiap hit tetap dapat mata manusia (ditunda) + `security-critic` otomatis.
4. **Rem run-level utuh:** circuit breaker, cap-volume (bobot), precheck allowlist/notify/trust; `halt` untuk abnormal.
5. **Deny diperluas** (rollback/reset migrasi) bersama opt-in apply.
6. **Approve per gate** (tak sticky); challenge checklist dievaluasi live saat drain.
7. **`tasks.yaml` nol status baru**; satu field opsional build-written `hold:` (preseden `commits:`); resume §E tak tersentuh (task hold tak pernah `in_progress`).
8. Mode attended **byte-identik** perilakunya di luar drain — **satu pengecualian sadar (koreksi 2026-08-28):** `cmd` apply-migrasi kini GATE seperti `migrate` (§3.3), bukan auto.

## 5. Alternatif yang DITOLAK

- **Per-task `risk` tag** (kandidat 2026-06-18 §6) — butuh eval akurasi tagger + *topological collapse*; antrian memberi manfaat sama tanpa skema baru.
- **Status task baru `parked`/`held`** — ditolak spec lanes (kontrak `tasks.yaml` lintas-skill); pakai `needs_human`.
- **Gate state di `milestones[].gate` `tasks.yaml`** — kontrak berubah; segmen `app×milestone` ≠ 1:1 milestone.
- **Antrian prosa-saja di `last-run.md`** — tak kebaca mesin saat resume; approved vs belum tak terbedakan.
- **Tunda gate tapi dependents ikut nunggu** — ditolak operator (≈ sekarang untuk fitur auth/DB).
- **Persempit verba floor-scan** — ditunda: hit kini murah (satu item antrian); revisit bila beban review pagi terlalu tinggi.
- **"Approve semua"/sticky** — dilarang M7.
- **Auto-apply destructive** — irreversible di DB remote (branding: `DATABASE_URL` → Supabase remote).
- **Auto-lanjut attended sesudah drain** — mengembalikan syarat kehadiran.
- **`--allowedTools` per-run di `drive.sh` untuk migrate** — settings opt-in lebih terlihat, ter-`upgrade`, pola mapan.

## 6. Di luar scope

- Preview antrian dari HP tanpa terminal (HTML/`render-docs`) — `last-run.md` prosa + notif cukup dulu.
- Per-task risk tagging (lihat §5).
- Port `--unattended` ke Kimi (fase 2, tak berubah).
- Perubahan `fix` lane (tetap attended, tanpa `gates.yaml`).

## 7. Edge case & degrade

| kasus | perilaku |
|---|---|
| `gates.yaml` absen (fitur lama / run pertama) | = kosong; dibuat saat entri pertama |
| User edit `gates.yaml` manual (set `approved`) | dipercaya (pola `tasks.yaml`) |
| Segmen due >1 kali (corrective) sementara gate lama masih `queued` | dua entri; drain tertua dulu; blast-radius dihitung vs task sesudahnya |
| Sesi mati mid-run | entri gate atomik; `in_progress` reconcile §E seperti sekarang |
| Sesi mati mid-drain | `queued` tersisa lanjut di `build` berikutnya |
| Critic/impact scratch hilang | re-run saat drain (degrade) |
| Diff scratch hilang | regenerate dari `commits:` |
| `kind` absen pada migrate | fail-safe destructive → hold |
| `hold:` absen pada task `needs_human` (tasks.yaml lama / `manual:`) | drain derive jenis dari bentuk task (`manual:` → checklist; `actions: migrate` → migrate) |
| Perintah apply belum di-allowlist | hold `needs_human`, alasan "allowlist migrate absen — wire 5.5"; drain menawarkan apply attended |
| Semua segmen `auto`, 7a bersih | `done` persis perilaku lama (regresi nol) |
| Run kedua tanpa drain, tak ada yang bisa dibangun | `review` segera, nol kerja |
| `ready-set` kosong, `pending` > 0, blocker 0 | deps rujuk task tak ada → state korup → `halt` |
| Work-item fix | tak ada `gates.yaml`; `--unattended` ditolak seperti sekarang |
| `/schedule` | `review` = pause routine |
| Kimi | drain jalan (attended); `--unattended` ditolak |

## 8. Daftar file yang berubah (anchor dikonfirmasi saat planning)

| File | Perubahan |
|---|---|
| `plugin/skills/build/SKILL.md` | description; step 1 (hapus halt-dini `risk:high`, conflict → `needs_human`, WARN allowlist migrate, baca `gates.yaml`); step 2 (`needs_human` tak STOP total di unattended); step 3 (migrate by `kind` + cross-check + hold; `NEEDS_CONTEXT` → `needs_human`; brief +1 kalimat); step 5 (`blocked` lanjut lane lain); step 6 (queue/auto/critic, undeclared DDL, corrective → milestone sama); step 7/7a (tunda 7a bila `queued`); lapor-keluar (`review`, presedensi, header `review:`/`blockers:`); **drain** (referensi ke `reference.md` §I) |
| `plugin/skills/build/reference.md` | §D (cadence unattended: kelas A/B/C); §E (`needs_human` untuk migrate-hold + `commits:` saat hold; `NEEDS_CONTEXT` unattended); §G (nilai `outcome` +`review`; header baru; heading **tetap**); §H (`drive.sh` `review`; `/schedule` pause); **§I baru: `gates.yaml` (skema) + prosedur drain** |
| `plugin/template/.claude/drive.sh` | cabang `review`; pesan `halt`; komentar header |
| `plugin/skills/ship/SKILL.md` | step 1 (tolak `queued`); step 6 (body PR: daftar gate) |
| `plugin/skills/intake/SKILL.md` | scaffold comment (≈21); step 7 pemicu `high` + arti baru |
| `plugin/skills/feature/SKILL.md` | scaffold comment (≈23) — byte-identik |
| `plugin/skills/wire/SKILL.md` | 5.5: opt-in apply-migrate (gated, default skip) + deny cermin + catatan model kepercayaan |
| `plugin/skills/upgrade/SKILL.md` | step 2 checklist settings (opt-in migrate); step 4 bullet `risk:high` |
| `plugin/skills/breakdown/reference.md` | §A komentar `- migrate:` (doc-sync) + baris `hold:` di skema (OPSIONAL, diisi build saat `needs_human` — sebelah `commits:`) |
| `plugin/skills/guide/reference.md` | cheatsheet `/build` |
| `plugin/skills/ask/SKILL.md` | tabel Status: baris `gates.yaml` |
| `plugin/hooks/tests/drive.test.sh` | **baru** — test `drive.sh` (claude palsu) |
| `README.md`, `plugin/.claude-plugin/plugin.json` | seksi M7 + status; description + bump `0.23.0` |
| `docs/superpowers/specs/2026-06-06-m7-…`, `…2026-06-18-…` | append amandemen / pointer |
| `plugin-kimi/` | regen via `tools/build-kimi.sh` |

## 9. Verifikasi

1. **Anchor/grep:** scaffold intake = feature byte-identik; nol `: ` bocor; heading §G utuh; semua rujukan "STOP SELURUH build" / "halt dini ronde-1" / "presedensi halt > continue > done" di SKILL step 1·2·5·6 + §D·§G·§H + `drive.sh` konsisten (grep sebelum/sesudah).
2. **`drive.test.sh`:** `claude` palsu di PATH menulis `last-run.md` per skenario → `review` berhenti + pesan; `continue`→`continue`(done naik)→`done` = 3 putaran; `continue` tanpa kenaikan `done` → mandek; `halt` → berhenti; header malformed → fail-safe. Precheck via `HOME` temp (`.claude.json` trust) + `notify.sh` + `settings.json` dummy.
3. **Kimi:** `tools/tests/build-kimi.test.sh` ijo pasca-regen.
4. **Desk-check skenario nyata** (`tasks.yaml` asli; ekspektasi ditulis di plan): `login` (`risk:high`) → 0 stop, `review: 7`, `auto: 0` (koreksi 2026-08-27: `high` = semua segmen `queued`, §3.1), blast-radius G1 ⊇ T4/T5/T9/T10/T13/T15 · `generate-website` T7 additive → di-allowlist: cross-check jalur maju `upgrade()` lolos (`downgrade()`-nya ber-`drop_table` ×3 + `DROP TYPE`, sengaja diabaikan — koreksi review 2026-08-28) → apply + `queued` "ddl additive"; tidak: `needs_human` + dependents nunggu, 22 lain lanjut (koreksi 2026-08-27: subtree T7 = 17 task transitif) · `simplify-scoring-stp` → `queued: 1`, bukan stop · `marketing-landing` → `done` seperti dulu (**regresi nol**) · hipotetis: destructive → `needs_human` + subtree; `NEEDS_CONTEXT` → `needs_human`; 2 `blocked` sistemik → `halt`; drain revisi G1 → corrective milestone sama → due lagi.
5. **Live smoke (rekomendasi pasca-merge, operator sekali):** `drive.sh` semalam atas satu fitur kecil nyata (`risk: normal`, sesudah breakdown) → pagi drain. Satu-satunya bukti end-to-end.

## 10. Ringkas

Gate memeriksa kode yang sudah jadi → persetujuannya bisa **ditunda ke antrian** (`gates.yaml`) tanpa menyentuh dispatch. Titik-manusia dipecah tiga kelas: review (ditunda, lanjut), blocker (subtree nunggu via `needs_human`+`hold:`, sisanya lanjut), auto. `risk:high` = "review semua pagi", bukan kill-switch; migrasi additive auto-apply lewat opt-in allowlist, destructive/backfill tetap nunggu manusia. Driver dapat `outcome: review`. Hasil: `login` yang dulu 5 hari attended → satu malam build + satu drain pagi (6 gate) + malam kedua untuk corrective — nol begadang, nol pelonggaran Security Gate `ship`.
