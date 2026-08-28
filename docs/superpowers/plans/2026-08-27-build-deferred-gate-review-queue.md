# Gate ditunda ke antrian review (`gates.yaml`) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `build --unattended` tak pernah berhenti karena gate — gate yang butuh mata manusia ditunda ke antrian `gates.yaml` (kode tetap dibangun di atasnya), blocker cuma menahan subtree-nya, migrasi additive auto-apply lewat opt-in allowlist, driver mengenal `outcome: review`, dan `build` attended menguras antrian pagi hari.

**Architecture:** Perubahan ke **prosa skill (markdown)** — `build` (SKILL + reference §D/§E/§G/§H + **§I baru**), `ship`, `intake`/`feature`, `wire`, `upgrade`, `breakdown`/`guide`/`ask` (doc-sync) — plus **satu skrip bash** (`template/.claude/drive.sh`) dengan **test bash baru** (`plugin/hooks/tests/drive.test.sh`, `claude` palsu di PATH), lalu release (bump + regen `plugin-kimi`). Verifikasi tiap edit prosa = **`grep -Fc` anchor unik** sebelum edit + **read-back** sesudahnya; skrip = test bash beneran. Acceptance akhir = grep konsistensi (frasa lama harus 0) + desk-check skenario nyata (`login`, `generate-website`, `simplify-scoring-stp`, `marketing-landing`).

**Tech Stack:** Markdown (skill files context-vault), Bash (`drive.sh` + test), `jq`, `grep`, `python3` (edit multi-anchor opsional).

**Spec:** `docs/superpowers/specs/2026-08-27-build-deferred-gate-review-queue-design.md` — plan ini berargumen dari spec; executor baca keduanya.

## Global Constraints

- **Working dir:** `/Users/mac-098506/Developer/project/context-vault`. Source of truth = `plugin/`; `plugin-kimi/` GENERATED (jangan edit tangan — regen Task 12).
- **Anchor by quoted-phrase, bukan nomor baris.** Beberapa task mengedit file yang sama (`build/SKILL.md`, `build/reference.md`) → nomor baris bergeser. Sebelum tiap Edit: `grep -Fc -e '<old_string>' <file>` HARUS `1` (unik). Pakai Edit tool (`old_string` → `new_string`) **PERSIS seperti dikutip** — termasuk karakter `…`, `→`, `×`, backtick, dan bold yang memang bagian teks (plan ini TIDAK memakai `…` sebagai tanda elisi; semua kutipan utuh).
- **Vocab kanonik (dipakai lintas task, jangan drift):** status entri gate `queued | approved | revised | auto`; field entri `id, segment, tasks, commits, status, reason, critic, impact, smoke, queued_at, decided_at, decision`; label segmen `<unit>×<milestone>` | `<unit>×<milestone>/<task-id>` | `integration×<task-id>` | `simplify`; header `last-run.md` `outcome: continue|review|done|halt` + `done:`/`pending:`/`review:`/`blockers:`/`reason:`; presedensi `halt > continue > review > done`; field task opsional build-written `hold:`; tiga kelas titik-manusia **A gate review (ditunda) / B blocker (subtree nunggu) / C auto**.
- **Heading §G `build/reference.md` (`## G. Lapor-keluar / notifikasi (mode unattended — M7)`) TIDAK diganti** — anchor generator Kimi (`tools/build-kimi.sh` baris ≈111).
- **Scaffold comment `risk:` byte-identik** di `intake/SKILL.md` (≈21) & `feature/SKILL.md` (≈23); **tanpa `: ` (colon-space) di value YAML** (BUG-GUARD 2026-06-18). Value tetap `normal`; perubahan di komentar `#`.
- **JANGAN sentuh:** file `control/*` produk mana pun (`~/Developer/**`), Security Gate `ship` step 4.5, daftar verba `tweak/reference.md` §A, mekanik heuristik `sensitivity` intake, `plugin/hooks/auto-title.sh`.
- **Tak menambah skill** → jumlah skill (25) di README / `plugin.json` / `marketplace.json` tak berubah.
- **Commit tiap task.** Pesan Indonesian + prefix conventional-commits, **TANPA** trailer `Co-Authored-By` (setting attribution repo), **DENGAN** footer `Claude-Session: https://claude.ai/code/session_01WQfR5ujAtkSf7aPKkWBswz` di baris terakhir.
- **Bahasa & gaya prosa** = ikuti file yang diedit (Indonesian, bold untuk aturan keras, backtick untuk artefak/status). Tiap sisipan baru ditandai `(amandemen 2026-08-27)` supaya reviewer bisa grep.

---

### Task 1: `build/reference.md` — §I baru: skema `gates.yaml` + prosedur drain

**Files:**
- Modify: `plugin/skills/build/reference.md` — APPEND di akhir file (sesudah §H "Aturan aman (dua-duanya)")

**Interfaces:**
- Produces: **§I** = sumber kebenaran skema `gates.yaml`, aturan `hold:`, prosedur drain, aturan "kalau direvisi, yang kena", nama file scratch `gate-Gn-critic.md`/`gate-Gn-impact.md`. Task 2–7, 10 merujuk `reference.md` §I dengan nama ini.

- [ ] **Step 1: Konfirmasi titik append**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
tail -3 plugin/skills/build/reference.md
grep -c '^## I\.' plugin/skills/build/reference.md   # harus 0 (belum ada §I)
```
Expected: baris terakhir = paragraf "Driver menumpang floor (langkah-1 §D) + notif (§G); ia **tak pernah** melonggarkan gate. …"; count `0`.

- [ ] **Step 2: Append §I**

Append (pakai Edit tool: `old_string` = kalimat terakhir file `Tak ada auto-merge/auto-ship — \`outcome: done\` berarti "siap di-\`ship\`", \`ship\` tetap attended (jatah manusia).` → `new_string` = kalimat itu + dua baris kosong + blok berikut):

````markdown
## I. Antrian gate (`gates.yaml`) + drain pagi — gate ditunda (amandemen 2026-08-27)

**Wawasan:** gate step 6 memeriksa kode yang SUDAH jadi (implementer → test ijo → commit → reviewer dua-verdict → `done`); syarat task berikutnya cuma `deps` `done`, bukan "sudah di-approve manusia". Maka **persetujuan** bisa ditunda tanpa menyentuh dispatch — yang diantrikan approval-nya, bukan kodenya. Harga jujur: revisi pagi bisa merembet ke dependents (biaya token + satu malam, BUKAN biaya keamanan — tak ada yang mencapai `main` tanpa `ship`).

**Tiga kelas titik-manusia (SKILL step 6):** **A gate review (ditunda)** → entri `queued`, run lanjut · **B blocker (subtree nunggu)** → task `needs_human`/`blocked` + `hold:`, dependents otomatis tak READY, sisanya lanjut · **C auto** → entri `auto`. Run unattended berhenti hanya: tak ada task READY (`review`) / cap-volume (`continue`) / abnormal (`halt`) / selesai (`done`) — §G.

### Skema `<work-item>/gates.yaml` (penulis tunggal `build`; ke-commit bareng `control/`; HANYA work-item fitur)
```yaml
feature: login
gates:
  - id: G1                          # urut kronologis penulisan; satu segmen boleh muncul >1 kali (per due-event, mis. sesudah corrective)
    segment: web×M1                 # <unit>×<milestone> | <unit>×<milestone>/<task-id> (cadence per-task §D) | integration×<task-id> | simplify (7a)
    tasks: [T1, T2, T3]
    commits: [68fb1b5..47da07e]     # union rentang `commits:` task-task segmen (per repo; integration → per repo deps)
    status: queued                  # queued | approved | revised | auto
    reason: "floor-scan T1 (origin/redirect), T2 (session/token)"
    #   ATAU "risk:high" | "ddl additive T7 (auto-applied)" | "ddl undeclared T9 (TIDAK di-apply)"
    #   | "penyimpangan → corrective T13" | "smoke gagal: POST /login 500" | "bersih (risk:normal, floor-scan nihil)"
    critic: .claude/build/login/gate-G1-critic.md    # OPSIONAL — laporan security-critic (scratch)
    impact: .claude/build/login/gate-G1-impact.md    # OPSIONAL — laporan migration-impact (bila ada ddl)
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
Ditulis saat `build` men-set `needs_human` **bukan-karena-`manual:`**, satu baris self-describing & durable: `hold: "migrate destructive — nunggu approve (affects: brands.kit)"` · `hold: "allowlist migrate absen — wire 5.5"` · `hold: "NEEDS_CONTEXT: <pertanyaan implementer verbatim>"` · `hold: "konflik invariant Tenancy — query tanpa filter tenant"`. Dihapus saat task keluar dari `needs_human`. Absen (task `manual:` / `tasks.yaml` lama) → drain derive dari bentuk task: ada `manual:` → checklist manual; ada `actions: migrate` → migrate. Prosa `last-run.md` MENYALIN `hold:` (bukan sumber kebenaran — ia ditulis ulang tiap stop).

### Drain pagi (attended) — dipicu SKILL step 1
**Pemicu:** `build <fitur>` tanpa flag DAN (`gates.yaml` punya `queued` ATAU `tasks.yaml` punya `needs_human`/`blocked`) → mode drain SEBELUM dispatch apa pun. `--unattended` → skip drain (lanjut bangun; tak ada task READY → `outcome: review`).

**Urutan sajian:**
1. **Ringkasan** dari `last-run.md` + `gates.yaml`: *"Semalam: 25 done · 6 gate queued (G1–G4, G6, G7) · 1 blocker (T7 migrate destructive) · 1 auto (web×M5)."*
2. **Re-run test sekali per repo** (baseline segar; "jangan percaya laporan") — hasil ditampilkan di tiap gate.
3. **Gate `queued` urut G-id (tertua dulu)** — revisi di G1 paling mungkin merembet ke bawah.
4. **Blocker** (`needs_human`/`blocked`) sesudahnya.
5. Daftar `auto` ringkas, nol aksi.

**Tiap gate = UX gate step 6 + bukti semalam:** header (segmen · task · commits · alasan · tanggal) · diff per task · hasil test + "dibangun vs task" · **Challenge checklist dievaluasi LIVE** (`rules/anti-yes-man.md`; tak disimpan semalam) · temuan security-critic (`critic:`; hilang → jalankan sekarang) · laporan migration-impact (`impact:`) · observasi smoke · **"Kalau direvisi, yang kena:"** = task yang dibangun *sesudah* gate ini — (a) task milik entri gate ber-G-id **lebih besar**, plus (b) task `done` yang belum masuk entri gate mana pun (segmennya belum due) — yang `files:`-nya tumpang-tindih dengan `files:` task gate ini (deterministik dari `gates.yaml` + `tasks.yaml`) · "Coba sendiri" Part A (§D) · → **approve / revisi** — **per gate, TANPA "approve semua"** (sticky-approve dilarang M7).

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
- `blocked` → objeksi reviewer/error (report file + prosa) → arah user → reset eksplisit `pending` (§E; tetap TIDAK auto-retry).

**Akhir drain — STOP + ringkasan, BUKAN otomatis lanjut bangun.** Tulis ulang `last-run.md` (`outcome` `continue`/`review`/`done` + prosa "drain pagi: G1 approve, G2 revisi → T26 …"), lalu tanya SEKALI: *"lanjut attended sekarang, atau berhenti biar `drive.sh` yang lanjutin malam ini?"* — jangan kembali ke pola "harus ada manusia". Semua task `done` + antrian kosong sesudah drain → 7a (gate attended, SKILL step 7a) → `done` → *"siap di-`ship`"*.

**Kimi:** drain = attended → jalan di Kimi (state di disk); `--unattended` tetap ditolak di Kimi.
````

- [ ] **Step 3: Read-back + verifikasi struktur**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -c '^## I\. Antrian gate' plugin/skills/build/reference.md          # 1
grep -c '^## G\. Lapor-keluar / notifikasi (mode unattended — M7)' plugin/skills/build/reference.md   # 1 (heading §G utuh)
grep -c 'queued | approved | revised | auto' plugin/skills/build/reference.md   # 1
grep -c 'Kalau direvisi, yang kena' plugin/skills/build/reference.md            # 1
```
Expected: `1`, `1`, `1`, `1`. Baca ulang §I: skema YAML valid secara visual (indentasi 2 spasi, komentar di belakang `#`), tak ada "TBD".

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/build/reference.md
git commit -m "feat(build): reference §I — skema gates.yaml (gate ditunda), field hold:, prosedur drain pagi

Claude-Session: https://claude.ai/code/session_01WQfR5ujAtkSf7aPKkWBswz"
```

---

### Task 2: `build/SKILL.md` step 1 + lapor-keluar — baca `gates.yaml`, `risk` bukan kill-switch, `outcome: review`

**Files:**
- Modify: `plugin/skills/build/SKILL.md` — step 1 (paragraf "Risk + mode unattended", bullet "Pre-flight conflict sweep", bullet "Lapor-keluar")

**Interfaces:**
- Consumes: §I (Task 1) — nama file `gates.yaml`, `hold:`, drain.
- Produces: pemetaan `outcome` 4 nilai + presedensi `halt > continue > review > done` + header `review:`/`blockers:` — dipakai Task 5 (§G/§H) & Task 6 (`drive.sh`).

- [ ] **Step 1: Arti `risk` + baca `gates.yaml` + drain entry (step 1)**

`old_string` (unik):
```
untuk cadence gate step 6. **WARN invariants (advisory):**
```
`new_string`:
```
untuk cadence gate step 6. **Arti `risk` (amandemen 2026-08-27): BUKAN kill-switch** — `high` = SEMUA gate segmen masuk antrian review (`<work-item>/gates.yaml`, step 6 + `reference.md` §I), `low`/`normal` = floor-scan memutuskan per segmen; build TIDAK pernah berhenti karena `risk`. **Baca `<work-item>/gates.yaml`** (absen → kosong): entri `queued` dari run sebelumnya TIDAK menghalangi run baru (bangun di atasnya). **Drain (attended):** bila ada `queued` di `gates.yaml` ATAU task `needs_human`/`blocked` di `tasks.yaml` DAN mode attended → masuk **mode drain** (`reference.md` §I) SEBELUM dispatch apa pun; unattended → skip drain (lanjut bangun; tak ada task READY → `outcome: review`). **WARN invariants (advisory):**
```

- [ ] **Step 2: Efek mode unattended (step 1, kalimat penutup paragraf)**

`old_string` (unik):
```
Mode unattended HANYA berefek di step 6 untuk work-item fitur (work-item fix selalu attended; fix tak punya `risk`).
```
`new_string`:
```
Mode unattended berefek di step 1/2/3/5/6 untuk work-item fitur — titik-manusia jadi antrian (`gates.yaml`) atau hold (`needs_human` + `hold:`), BUKAN stop (amandemen 2026-08-27; lihat step 6); work-item fix selalu attended (tak punya `risk` maupun `gates.yaml`). **WARN allowlist migrate:** ada task `actions: migrate` `kind: additive` tapi perintah apply-nya (dari `stack.orm`, opt-in `wire` 5.5) belum ada di `permissions.allow` → WARN "bakal di-hold `needs_human`, jalankan `wire` 5.5" (bukan `halt`).
```

- [ ] **Step 3: Pre-flight conflict → `needs_human`, bukan `halt`**

`old_string` (unik):
```
**Unattended:** ada konflik → `outcome: halt` (butuh keputusan manusia), JANGAN auto-approve.
```
`new_string`:
```
**Unattended (amandemen 2026-08-27):** task yang konflik → set `needs_human` + `hold: "konflik <invariant/package>: <1 baris>"` (task lain lanjut; drain pagi `reference.md` §I yang memutuskan) — JANGAN auto-approve, JANGAN `halt` seluruh run.
```

- [ ] **Step 4: Header mesin 4 nilai (lapor-keluar)**

`old_string` (unik):
```
(baris pertama WAJIB header mesin `outcome: continue|done|halt` + `done:`/`pending:`/`reason:`, lalu prosa)
```
`new_string`:
```
(baris pertama WAJIB header mesin `outcome: continue|review|done|halt` + `done:`/`pending:`/`review:`/`blockers:`/`reason:`, lalu prosa — format `reference.md` §G)
```

- [ ] **Step 5: Pemetaan `outcome` + presedensi**

`old_string` (unik — satu kalimat panjang, kutip persis):
```
Pemetaan `outcome`: semua done (step 7)=`done`; cap-volume tercapai & masih pending & tak ada floor=`continue`; floor/blocker (`needs_human`/`blocked`/circuit-breaker/`migrate`/Security/floor-scan-simplify-7a/blocker-lingkungan/`risk:high`-saat-unattended)=`halt`. **Sebab campur hasil drain (mode lane §F): presedensi `halt` > `continue` > `done`** — `blocked` hasil drain SELALU `halt` (jangan `continue` bikin driver restart & blocked terkubur); `reason` = sebab prioritas tertinggi (floor > blocked > lainnya) + "(+N isu lain, lihat prosa)".
```
`new_string`:
```
Pemetaan `outcome` (amandemen 2026-08-27): `done` = semua task `done` DAN `gates.yaml` tanpa `queued` DAN 7a clear; `continue` = masih ada task READY (cap-volume tercapai); `review` = tak ada task READY tapi ada gate `queued` dan/atau task `needs_human`/`blocked` (nunggu keputusan manusia, TAK ada yang rusak); `halt` = HANYA abnormal — circuit-breaker (2 `blocked` berakar sama), blocker lingkungan (allowlist kosong / permission denial tak teratasi / env), state korup (`in_progress` ganda satu repo / deps rujuk task tak ada). **Presedensi `halt` > `continue` > `review` > `done`**; `reason` = sebab prioritas tertinggi + "(+N isu lain, lihat prosa)". `blocked` tunggal BUKAN lagi `halt` — ia `review` (subtree nunggu, sisanya sudah dibangun; driver berhenti, manusia drain). `review:` = jumlah entri `queued`; `blockers:` = jumlah task `needs_human`+`blocked`.
```

- [ ] **Step 6: Hapus halt-dini `risk:high`**

`old_string` (unik):
```
`risk:high` saat unattended → emit `halt` dini ronde-1 (auto-approve tak nyala; butuh attended).
```
`new_string`:
```
`risk:high` saat unattended → TIDAK `halt` (amandemen 2026-08-27): semua gate segmen `queued`, run lanjut sampai `review`.
```

Lalu `old_string` (unik):
```
tiap berhenti (termasuk permission-denial/env/`risk:high`) emit `outcome`+`last-run.md` DULU lalu STOP
```
`new_string`:
```
tiap berhenti (termasuk permission-denial/env) emit `outcome`+`last-run.md` DULU lalu STOP
```

- [ ] **Step 7: Verifikasi anchor lama hilang + read-back**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
f=plugin/skills/build/SKILL.md
grep -Fc -e 'halt` dini ronde-1' $f        # 0
grep -Fc -e 'risk:high`-saat-unattended' $f # 0
grep -Fc -e 'presedensi `halt` > `continue` > `review` > `done`' $f   # 1
grep -Fc -e 'Baca `<work-item>/gates.yaml`' $f   # 1
grep -Fc -e 'hold: "konflik' $f             # 1
```
Expected: `0 0 1 1 1`. Baca ulang step 1 utuh: alur "baca state → drain (attended) / skip (unattended)" masuk akal, tak ada kalimat yang saling bertentangan dengan WARN invariants/allowlist.

- [ ] **Step 8: Commit**

```bash
git add plugin/skills/build/SKILL.md
git commit -m "feat(build): step 1 — risk bukan kill-switch, baca gates.yaml + drain entry, conflict → needs_human, outcome review + presedensi baru

Claude-Session: https://claude.ai/code/session_01WQfR5ujAtkSf7aPKkWBswz"
```

---

### Task 3: `build/SKILL.md` step 2 + 3 + 5 — `manual:` tak stop total, migrate by `kind`, `NEEDS_CONTEXT`/`blocked` → hold, `hold:`

**Files:**
- Modify: `plugin/skills/build/SKILL.md` — step 2 (urutan atomik + `manual:`), step 3 (brief + `NEEDS_CONTEXT` + actions `migrate`), step 5 (`needs_human`/`blocked`/`hold:`)

**Interfaces:**
- Consumes: `hold:` (§I Task 1); `gate-Gn-impact.md` (§I).
- Produces: aturan cross-check DDL + cabang `kind` (dirujuk Task 5 §E dan Task 9 `wire`).

- [ ] **Step 1: Urutan atomik — unattended tak STOP-dispatch (step 2)**

`old_string` (unik):
```
due (attended) → STOP-dispatch SEMUA lane (step 6) → (3) BARU scheduler tick
```
`new_string`:
```
due (attended) → STOP-dispatch SEMUA lane (step 6); due (unattended, amandemen 2026-08-27) → tulis entri `gates.yaml` / set hold TANPA STOP-dispatch (step 6) → (3) BARU scheduler tick
```

- [ ] **Step 2: `manual:` → `needs_human` tanpa stop total (step 2)**

`old_string` (unik):
```
Bila task terpilih punya `manual:` yang belum dikonfirmasi beres → set `status: needs_human`, **STOP SELURUH build** (mode lane: STOP-dispatch semua lane + drain step 6 dulu), lapor checklist langkah manual ke user; **jangan dispatch** (hemat ronde implementer). Lanjut setelah user konfirmasi beres.
```
`new_string`:
```
Bila task terpilih punya `manual:` yang belum dikonfirmasi beres → set `status: needs_human`; **jangan dispatch** (hemat ronde implementer). **Attended:** STOP SELURUH build (mode lane: STOP-dispatch semua lane + drain step 6 dulu), lapor checklist langkah manual ke user; lanjut setelah konfirmasi. **Unattended (amandemen 2026-08-27):** JANGAN stop — tandai lalu lanjut scheduler tick (dependents-nya otomatis tak READY karena deps belum `done`; task lain lanjut); checklist masuk prosa `last-run.md` + drain pagi (`reference.md` §I).
```

- [ ] **Step 3: `NEEDS_CONTEXT` user-only → `needs_human` + `hold:` (step 3)**

`old_string` (unik):
```
Bila subagent **balik nanya** (spec kurang) sebelum mulai: jawab → re-dispatch dengan jawaban di-paste; jangan tandai gagal.
```
`new_string`:
```
Bila subagent **balik nanya** (spec kurang) sebelum mulai: jawab → re-dispatch dengan jawaban di-paste; jangan tandai gagal. **Unattended (amandemen 2026-08-27):** bila jawabannya HARUS dari user (controller tak bisa jawab dari `tasks.yaml`/plans/kode) → set `needs_human` + `hold: "NEEDS_CONTEXT: <pertanyaan verbatim>"` (JANGAN ditinggal `in_progress` — resume `reference.md` §E akan salah reconcile), lanjut task lain; drain pagi menjawab → re-dispatch.
```

- [ ] **Step 4: Brief — DDL di luar action dilarang (step 3)**

`old_string` (unik):
```
**Brief menegaskan: commit HANYA file task (per `files:`), BUKAN `git add -A`** (higiene hub-repo §F).
```
`new_string`:
```
**Brief menegaskan: commit HANYA file task (per `files:`), BUKAN `git add -A`** (higiene hub-repo §F). **Brief juga menegaskan (amandemen 2026-08-27): DDL/migrasi di luar `actions: migrate` DILARANG — jangan pernah apply migrasi ke DB di luar action** (jalur "undeclared DDL" step 6 tak boleh mencuri apply).
```

- [ ] **Step 5: Actions `migrate` — cabang by `kind` saat unattended (step 3)**

`old_string` (unik):
```
baru apply; `env` → `build` tulis ke `.env` app (nilai dari `manual:`/prompt user).
```
`new_string`:
```
baru apply. **Unattended (amandemen 2026-08-27) — cabang by `migrate.kind`:** `additive` → (1) **cross-check deterministik:** grep file migrasi di diff task untuk verba destruktif (`DROP`, `RENAME`, `ALTER … TYPE`, `SET NOT NULL` tanpa default, `TRUNCATE`, `DELETE FROM`, `UPDATE … SET`) — kena = `kind` bohong → perlakukan `destructive`; (2) perintah apply (diturunkan dari `stack.orm`/tool migrasi unit — opt-in `wire` 5.5) ada di `permissions.allow`? tidak → `needs_human` + `commits:` + `hold: "allowlist migrate absen — wire 5.5"`, lanjut task lain; (3) panggil `migration-impact` → tulis `<root>/.claude/build/<work-item>/gate-Gn-impact.md` (dirujuk entri gate step 6 `impact:`); (4) apply + verifikasi + regen proyeksi (M4, di bawah) → `done`. `destructive`/`backfill` → JANGAN apply: task `needs_human` + `commits:` (kode migrasi sudah di-commit & lolos review step 4) + `hold: "migrate <kind> — nunggu approve (affects: <affects>)"` → lanjut task lain; drain pagi approve → apply → `done`. `kind` absen (breakdown lama) → fail-safe `destructive` (hold) + ingatkan lengkapi. Attended: tak berubah (tampilkan + dampak + approve). `env` → `build` tulis ke `.env` app (nilai dari `manual:`/prompt user).
```

- [ ] **Step 6: `blocked` unattended lanjut + `hold:` + `needs_human` wording (step 5)**

`old_string` (unik):
```
**Task ber-`manual:` belum beres → `needs_human` (sudah dideteksi di step 2: STOP + lapor checklist; bukan `blocked` — ini nunggu manusia, bukan error).** Buntu/error → `blocked`, **STOP**, laporkan (sandar `systematic-debugging`; mode lane §F: STOP-dispatch semua lane → **drain** step 6 → lapor agenda bareng — `blocked` tambahan ber-akar-serupa hasil drain → reason "dugaan sistemik", `reference.md` §D).
```
`new_string`:
```
**Task ber-`manual:` belum beres → `needs_human` (sudah dideteksi di step 2: attended STOP + lapor checklist, unattended tandai + lanjut; bukan `blocked` — ini nunggu manusia, bukan error).** **Field `hold:` (amandemen 2026-08-27; opsional, build-written, preseden `commits:` — BUKAN status baru):** tulis satu baris alasan saat men-set `needs_human` BUKAN-karena-`manual:` (migrate hold / allowlist migrate absen / `NEEDS_CONTEXT` / konflik pre-flight — kosakata `reference.md` §I); hapus saat task keluar dari `needs_human`. Buntu/error → `blocked`, laporkan (sandar `systematic-debugging`). **Attended:** STOP (mode lane §F: STOP-dispatch semua lane → **drain** step 6 → lapor agenda bareng — `blocked` tambahan ber-akar-serupa hasil drain → reason "dugaan sistemik", `reference.md` §D). **Unattended (amandemen 2026-08-27):** JANGAN stop run — subtree-nya otomatis nunggu (deps), lane/task lain lanjut; circuit breaker tetap: 2 `blocked` berakar sama → `halt` (sistemik).
```

- [ ] **Step 7: Verifikasi + read-back**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
f=plugin/skills/build/SKILL.md
grep -Fc -e 'cabang by `migrate.kind`' $f        # 1
grep -Fc -e 'hold: "NEEDS_CONTEXT' $f            # 1
grep -Fc -e 'Field `hold:`' $f                   # 1
grep -Fc -e '**STOP SELURUH build** (mode lane' $f   # 0 (kalimat lama step 2 sudah terbelah attended/unattended)
grep -c 'amandemen 2026-08-27' $f                # ≥ 9
```
Expected sesuai komentar. Read-back step 3 actions: urutan (1)→(4) untuk additive koheren; `env` masih ada di ujung kalimat.

- [ ] **Step 8: Commit**

```bash
git add plugin/skills/build/SKILL.md
git commit -m "feat(build): step 2/3/5 — manual: tak stop total unattended, migrate cabang by kind (additive auto-apply, destructive hold), NEEDS_CONTEXT/blocked → hold subtree, field hold:

Claude-Session: https://claude.ai/code/session_01WQfR5ujAtkSf7aPKkWBswz"
```

---

### Task 4: `build/SKILL.md` step 6 + 7/7a — gate ditunda (`queued`/`auto`/critic), undeclared DDL, 7a ditunda

**Files:**
- Modify: `plugin/skills/build/SKILL.md` — step 6 (klausa Mode unattended, HARD floor, floor-scan, migrasi tak-terdeklarasi, catatan struktural, penyimpangan, smoke), step 7 (hard guard), 7a (floor-scan + unattended), kalimat penutup "siap di-ship"

**Interfaces:**
- Consumes: §I (entri gate, `reason` kosakata, critic scratch path).
- Produces: definisi `done` (antrian kosong) dipakai Task 5 §G dan Task 7 `ship`.

- [ ] **Step 1: Klausa Mode unattended → gate ditunda (step 6)**

`old_string` (unik — kutip persis):
```
**Mode unattended (opt-in, hanya work-item fitur — M7):** bila mode unattended terdeteksi di step 1 (token `--unattended` atau maksud NL tanpa-pengawasan) DAN `feature.yaml` `risk` ∈ {`low`,`normal`} (nilai efektif per step 1: absen → `normal`, KECUALI `sensitivity:payments` → `high`) DAN segmen ini test-ijo + "dibangun vs task" COCOK (tak ada penyimpangan) → **auto-approve** segmen (catat ringkasan, lanjut loop tanpa stop user; mode lane §F: lane lain TIDAK berhenti — tak ada manusia yang ditunggu.
```
`new_string`:
```
**Mode unattended (opt-in, hanya work-item fitur — M7; amandemen 2026-08-27 "gate ditunda"):** bila mode unattended terdeteksi di step 1 (token `--unattended` atau maksud NL tanpa-pengawasan) → gate segmen TIDAK PERNAH menghentikan run. Evaluasi segmen seperti biasa (floor-scan di bawah, `risk` efektif step 1, "dibangun vs task", smoke Part B), lalu tulis SATU entri ke `<work-item>/gates.yaml` (skema + prosedur `reference.md` §I): (a) **bersih** — nol floor-scan, test ijo, "dibangun vs task" COCOK, `risk` efektif ∈ {`low`,`normal`} → entri `status: auto` (jejak audit) → lanjut; (b) **`risk:high` / floor-scan kena / DDL di diff / penyimpangan / smoke gagal** → entri `status: queued` + `reason` spesifik (kosakata §I: "floor-scan T1 (session/token)" / "risk:high" / "ddl additive T7 (auto-applied)" / "ddl undeclared T9 (TIDAK di-apply)" / "penyimpangan → corrective T13" / "smoke gagal: …") → bila alasan memuat verba keamanan/uang ATAU `sensitivity` non-kosong → dispatch subagent **`security-critic`** (`${CLAUDE_PLUGIN_ROOT}/agents/security-critic.md`; input = path paket diff per task `review-*.diff` + `control/invariants.md`/`conventions.md`/`integrations.md`/`business/risks.md`) → tulis `<root>/.claude/build/<work-item>/gate-Gn-critic.md` → `critic:` di entri; critic TIDAK menghalangi dispatch task berikutnya, TIDAK dihitung bobot cap-volume, tapi WAJIB selesai sebelum `last-run.md` ditulis → lanjut (mode lane §F: lane lain TIDAK berhenti — tak ada manusia yang ditunggu.
```

- [ ] **Step 2: HARD floor → tiga kelas (step 6)**

`old_string` (unik):
```
**HARD floor — TETAP STOP walau unattended:** `risk: high`, task `migrate` (step 3), `needs_human` (step 2), `blocked` (step 5), ATAU penyimpangan-dari-maksud (jalankan disiplin fix embed seperti biasa).
```
`new_string`:
```
**Tiga kelas titik-manusia (amandemen 2026-08-27, menggantikan "HARD floor" flat — `reference.md` §I):** kelas **A gate review (ditunda)** — `queued` di `gates.yaml`, run lanjut: `risk:high`, floor-scan, DDL, penyimpangan (disiplin fix embed tetap jalan otomatis → corrective `kind: fix` ke MILESTONE YANG SAMA dengan segmen; segmen due lagi saat corrective `done` → entri gate baru — satu segmen boleh muncul >1 kali), smoke gagal (= penyimpangan). Kelas **B blocker (subtree nunggu)** — `needs_human`/`blocked` + `hold:`, dependents otomatis tak READY, sisanya lanjut: `migrate` destructive/backfill atau apply belum di-allowlist (step 3), `needs_human` (step 2), `blocked` (step 5), `NEEDS_CONTEXT` user-only (step 3), konflik pre-flight (step 1). Kelas **C auto**. Tak satu pun menghentikan run unattended; yang menghentikan hanya abnormal (`halt`, pemetaan step 1).
```

- [ ] **Step 3: Floor-scan → attended STOP / unattended queued (step 6)**

`old_string` (unik):
```
Kena → **STOP attended**, *apa pun* tag `risk` fitur (tutup lubang intake salah-tag). **Migrasi tak-terdeklarasi:** diff ber-DDL tanpa task ber-`actions: migrate` → STOP (floor `migrate` step-3 tak bisa di-bypass salah-tag).
```
`new_string`:
```
Kena → **attended: STOP; unattended: entri `queued`** (bukan stop, amandemen 2026-08-27), *apa pun* tag `risk` fitur (tutup lubang intake salah-tag). **Migrasi tak-terdeklarasi:** diff ber-DDL tanpa task ber-`actions: migrate` → attended: STOP; unattended: entri `queued` "ddl undeclared Tn (TIDAK di-apply)" — build TIDAK meng-apply apa pun (floor `migrate` step-3 tak bisa di-bypass salah-tag).
```

- [ ] **Step 4: Catatan struktural (step 6)**

`old_string` (unik):
```
Catatan struktural: floor `migrate`/`needs_human`/`blocked` di-tegakkan di step 2/3/5 SEBELUM loop sampai gate step 6, jadi klausa ini tak mungkin auto-approve segmen yang punya floor-task belum-tuntas. Mode unattended MELONGGARKAN cadence gate yang ADA — BUKAN gate baru; tak pernah menyentuh Security Gate `ship`/migrate/needs_human.
```
`new_string`:
```
Catatan struktural: blocker kelas B ditegakkan di step 1/2/3/5 — task-nya tak pernah `done`, jadi segmennya tak pernah due; klausa ini tak mungkin auto-approve segmen yang punya blocker belum-tuntas. Mode unattended MENUNDA gate yang ADA ke antrian — BUKAN gate baru, BUKAN pelonggaran; tak pernah menyentuh Security Gate `ship`; `ship` menolak selama ada `queued`.
```

- [ ] **Step 5: Penyimpangan + smoke gagal (step 6)**

`old_string` (unik):
```
→ tulis corrective task `kind: fix` ke `tasks.yaml` → lanjut loop.
```
`new_string`:
```
→ tulis corrective task `kind: fix` ke `tasks.yaml` (milestone yang SAMA dengan segmen) → lanjut loop (unattended: gate segmen ini masuk `queued` "penyimpangan → corrective Tn", amandemen 2026-08-27).
```

Lalu `old_string` (unik):
```
jalankan disiplin fix embed yang SAMA (HARD floor: auto-approve unattended tak nyala); boot-fail prereq-lingkungan → blocker lingkungan (`halt`).
```
`new_string`:
```
jalankan disiplin fix embed yang SAMA (unattended: gate `queued` "smoke gagal: …", bukan `auto`); boot-fail prereq-lingkungan → blocker lingkungan (`halt`).
```

- [ ] **Step 6: Hard guard antrian (step 7)**

`old_string` (unik):
```
bila masih ada `pending`/`in_progress`/`blocked`/`needs_human`, JANGAN bilang siap-ship; laporkan task mana yang belum & kenapa.
```
`new_string`:
```
bila masih ada `pending`/`in_progress`/`blocked`/`needs_human`, JANGAN bilang siap-ship; laporkan task mana yang belum & kenapa. **Guard antrian (amandemen 2026-08-27):** semua task `done` TAPI `gates.yaml` masih punya `status: queued` → JANGAN jalankan 7a (revisi pagi bisa mengubah diff) & JANGAN bilang siap-ship → unattended: `outcome: review`; attended: masuk drain `reference.md` §I dulu.
```

- [ ] **Step 7: 7a — floor-scan + unattended (step 7a)**

`old_string` (unik):
```
diff simplify kena verba-keamanan/uang atau DDL → **STOP attended**, apa pun tag `risk` (simplify murni harusnya tak nyentuh ini; kalau kena = sinyal, jangan auto-approve). **Unattended (opt-in, hanya work-item fitur, `risk` ∈ {`low`,`normal`} per step 1):** behavior-preserving + test ijo + lolos floor-scan → boleh auto-approve (catat ringkasan di `last-run.md`; banner DIBANGUN-UNATTENDED bila relevan); selain itu STOP attended seperti floor step 6.
```
`new_string`:
```
diff simplify kena verba-keamanan/uang atau DDL → attended: **STOP**; unattended: `queued` (lihat kalimat Unattended) — apa pun tag `risk` (simplify murni harusnya tak nyentuh ini; kalau kena = sinyal, jangan auto-approve). **Unattended (opt-in, hanya work-item fitur; amandemen 2026-08-27):** behavior-preserving + test ijo + lolos floor-scan + `risk` efektif ∈ {`low`,`normal`} → auto-approve (entri `gates.yaml` `segment: simplify` `status: auto`; banner DIBANGUN-UNATTENDED bila relevan); selain itu (floor kena / `risk:high`) → entri `segment: simplify` `status: queued` → `outcome: review` (drain pagi mengevaluasi diff simplify seperti gate lain).
```

- [ ] **Step 8: Definisi siap-ship**

`old_string` (unik):
```
Baru kalau semua `done` **dan 7a clear** → laporkan
```
`new_string`:
```
Baru kalau semua `done` **dan `gates.yaml` tanpa `queued` dan 7a clear** → laporkan
```

- [ ] **Step 9: Verifikasi + read-back**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
f=plugin/skills/build/SKILL.md
grep -Fc -e 'HARD floor — TETAP STOP walau unattended' $f   # 0
grep -Fc -e 'auto-approve unattended tak nyala' $f          # 0
grep -Fc -e 'Tiga kelas titik-manusia' $f                    # 1
grep -Fc -e 'gate-Gn-critic.md' $f                           # 1
grep -Fc -e 'Guard antrian (amandemen 2026-08-27)' $f        # 1
grep -Fc -e 'segment: simplify' $f                           # ≥1
```
Read-back step 6 utuh: kalimat (a)/(b) → "Guard smoke lintas-app" yang sudah ada masih nyambung sesudah kurung tutup; tak ada "STOP attended" tersisa tanpa cabang unattended: `grep -Fc -e 'STOP attended' $f` → `0`.

- [ ] **Step 10: Commit**

```bash
git add plugin/skills/build/SKILL.md
git commit -m "feat(build): step 6/7a — gate ditunda (queued/auto + security-critic), tiga kelas titik-manusia, undeclared DDL queued, 7a ditunda selama antrian, siap-ship butuh antrian kosong

Claude-Session: https://claude.ai/code/session_01WQfR5ujAtkSf7aPKkWBswz"
```

---

### Task 5: `build/SKILL.md` description + `build/reference.md` §D/§E/§G/§H sync

**Files:**
- Modify: `plugin/skills/build/SKILL.md` — frontmatter `description` (baris 3)
- Modify: `plugin/skills/build/reference.md` — §D (bullet `--unattended`, floor-scan, rem lane (a)/(b), smoke Failure, simplify), §E (blocked, NEEDS_CONTEXT, migrate, needs_human), §G (penanda stop, header, nilai `outcome`), §H (backstop, Engkol 2, Aturan aman)

**Interfaces:**
- Consumes: pemetaan `outcome` (Task 2), cabang `kind` (Task 3), kelas A/B/C (Task 4), §I (Task 1).
- Produces: teks §G/§H yang dibaca `drive.sh` (Task 6) & `/schedule`.

- [ ] **Step 1: Description SKILL.md (frontmatter YAML — JANGAN masukkan `: `)**

`old_string` (unik):
```
(mode tanpa pengawasan — auto-approve segmen risk rendah, lihat step 6)
```
`new_string`:
```
(mode tanpa pengawasan — gate ditunda ke antrian review gates.yaml, blocker cuma nahan subtree-nya, lihat step 6 + reference §I)
```

- [ ] **Step 2: §D bullet `--unattended`**

`old_string` (unik):
```
segmen ber-tier `risk` `low`/`normal` yang ijo + tak-menyimpang → auto-approve (lanjut tanpa stop). HARD floor tetap STOP: `risk: high` / `migrate` / `needs_human` / `blocked` / penyimpangan. Melonggarkan cadence ini, BUKAN menambah gate; tak menyentuh Security Gate `ship`. Default (tanpa flag) = stop tiap segmen.
```
`new_string`:
```
(amandemen 2026-08-27 — gate ditunda, §I) gate segmen TIDAK PERNAH menghentikan run. Tiga kelas titik-manusia: **A gate review (ditunda)** — `risk:high` / floor-scan / DDL / penyimpangan / smoke gagal → entri `queued` di `gates.yaml` + `security-critic` bila alasan keamanan/uang → lanjut; **B blocker (subtree nunggu)** — `migrate` destructive/backfill atau apply tak di-allowlist / `needs_human` / `blocked` / `NEEDS_CONTEXT` user-only / konflik pre-flight → task `needs_human`/`blocked` + `hold:`, dependents otomatis tak READY, sisanya lanjut; **C auto** — bersih + `risk` low/normal → entri `auto`. Run berhenti hanya: tak ada task READY (`review`) / cap-volume (`continue`) / abnormal (`halt`) / selesai (`done`). Menunda gate yang ADA, BUKAN gate baru/pelonggaran; tak menyentuh Security Gate `ship`. Default (tanpa flag) = stop tiap segmen, plus drain antrian di awal bila ada (§I).
```

Lalu `old_string` (unik, di bullet yang sama):
```
kena → STOP attended. Degrade: `risk` absen + `sensitivity:[payments]` → diperlakukan `high`.
```
`new_string`:
```
kena → attended STOP / unattended `queued`. Degrade: `risk` absen + `sensitivity:[payments]` → diperlakukan `high` (= semua gate `queued`, non-blocking).
```

- [ ] **Step 3: §D rem lane (a) breaker + (b) presedensi**

`old_string` (unik):
```
(a) **breaker** — `blocked` PERTAMA tetap drain + `halt` (existing §G); `blocked` TAMBAHAN ber-akar-serupa hasil drain → `reason` "dugaan sistemik"
```
`new_string`:
```
(a) **breaker** — `blocked` PERTAMA (unattended, amandemen 2026-08-27) TIDAK menghentikan run: task hold, subtree nunggu, lane lain lanjut; `blocked` KEDUA ber-akar-serupa → `halt` `reason` "dugaan sistemik"
```

Lalu `old_string` (unik):
```
presedensi `halt` > `continue` > `done`, SKILL step 1
```
`new_string`:
```
presedensi `halt` > `continue` > `review` > `done`, SKILL step 1
```

- [ ] **Step 4: §D smoke Failure + simplify**

`old_string` (unik):
```
karena "penyimpangan" = HARD floor, auto-approve unattended TIDAK nyala.
```
`new_string`:
```
unattended: gate segmen `queued` "smoke gagal: …" (bukan `auto`), disiplin fix embed tetap jalan (amandemen 2026-08-27).
```

Lalu `old_string` (unik):
```
kena floor → STOP attended apa pun `risk`; unattended fitur `risk` low/normal + ijo + lolos floor → boleh auto-approve.
```
`new_string`:
```
kena floor → attended STOP / unattended `queued` (`segment: simplify`) apa pun `risk`; unattended bersih + `risk` low/normal + ijo → `auto`. 7a TIDAK dijalankan selama `gates.yaml` masih punya `queued` (SKILL step 7, amandemen 2026-08-27).
```

- [ ] **Step 5: §E — blocked, NEEDS_CONTEXT, migrate, needs_human**

`old_string` (unik):
```
- Buntu beneran (bug/dead-end) → `blocked` + STOP + lapor (sandar `systematic-debugging`).
```
`new_string`:
```
- Buntu beneran (bug/dead-end) → `blocked` + lapor (sandar `systematic-debugging`); attended STOP, unattended lanjut task lain — subtree nunggu (SKILL step 5, amandemen 2026-08-27).
```

`old_string` (unik):
```
task jadi agenda stop — status tetap `in_progress`, re-dispatch pasca jawaban (BUKAN reset `pending`).
```
`new_string`:
```
task jadi agenda stop — status tetap `in_progress`, re-dispatch pasca jawaban (BUKAN reset `pending`). **Unattended (amandemen 2026-08-27):** set `needs_human` + `hold: "NEEDS_CONTEXT: <pertanyaan>"` (JANGAN tinggal `in_progress`); drain pagi (§I) menjawab → re-dispatch.
```

`old_string` (unik):
```
+ approve sebelum apply (destruktif). `env` → tulis ke `.env` app.
```
`new_string`:
```
+ approve sebelum apply (destruktif). **Unattended (amandemen 2026-08-27):** cabang by `migrate.kind` (SKILL step 3) — `additive` → cross-check DDL + apply otomatis bila perintahnya di-allowlist (opt-in `wire` 5.5) + impact ke scratch `gate-Gn-impact.md`; `destructive`/`backfill` (atau `kind` absen / apply tak di-allowlist) → hold `needs_human` + `commits:` + `hold:`. `env` → tulis ke `.env` app.
```

`old_string` (unik):
```
- **`needs_human`** (task ber-`manual:` belum beres): dideteksi di step 2 → STOP seluruh build, lapor checklist; resume setelah user konfirmasi langkah manual beres → jalankan `actions` terkait → `in_progress`. Hitung sebagai BELUM siap-ship.
```
`new_string`:
```
- **`needs_human`** = task menunggu manusia (amandemen 2026-08-27): (a) ber-`manual:` belum beres (dideteksi step 2), (b) hold non-manual ber-`hold:` (migrate destructive/backfill · allowlist migrate absen · `NEEDS_CONTEXT` · konflik pre-flight — §I). Attended: STOP + lapor; unattended: tandai + lanjut task lain (subtree nunggu). Resume/drain (§I): user konfirmasi/approve/jawab → jalankan `actions` terkait / re-dispatch → `in_progress` → `done`; hapus `hold:`. Hitung sebagai BELUM siap-ship.
```

- [ ] **Step 6: §G — penanda stop, header, nilai `outcome`**

`old_string` (unik):
```
ditulis TEPAT sebelum mengakhiri turn di SETIAP titik STOP (`needs_human` step 2 / `blocked` step 5 / circuit-breaker & cap-volume & gate step 6 / selesai step 7), isi = SATU baris alasan.
```
`new_string`:
```
ditulis TEPAT sebelum mengakhiri turn di SETIAP titik STOP (cap-volume / tak ada task READY — antrian & blocker / abnormal / selesai — pemetaan SKILL step 1), isi = SATU baris alasan (mis. `review: 6 gate + 1 blocker — build login`).
```

`old_string` (unik — blok header di dalam fence):
```
   outcome: continue|done|halt
   done: <jumlah task done total>
   pending: <jumlah task belum done>
   reason: <satu baris alasan berhenti>
```
`new_string`:
```
   outcome: continue|review|done|halt
   done: <jumlah task done total>
   pending: <jumlah task belum done>
   review: <jumlah entri queued di gates.yaml — OPSIONAL, driver toleran absen>
   blockers: <jumlah task needs_human + blocked — OPSIONAL>
   reason: <satu baris alasan berhenti>
```

`old_string` (unik):
```
- `done` — SEMUA task `done` (step 7, siap-ship). Driver berhenti (sukses).
- `continue` — berhenti karena **cap-volume** (§D) tercapai, masih ada `pending`, TAK ada floor. Aman di-restart proses fresh → driver lanjut.
```
`new_string`:
```
- `done` — SEMUA task `done` + `gates.yaml` tanpa `queued` + 7a clear (step 7, siap-ship). Driver berhenti (sukses).
- `continue` — berhenti karena **cap-volume** (§D) tercapai, masih ada task READY. Aman di-restart proses fresh → driver lanjut (entri `queued` persisten, tak menghalangi).
- `review` — (amandemen 2026-08-27) tak ada task READY, tapi ada gate `queued` dan/atau task `needs_human`/`blocked` — nunggu keputusan manusia, TAK ada yang rusak. Driver berhenti, notif; manusia jalankan `build <fitur>` attended → drain (§I) → lalu `drive.sh` lagi.
```

`old_string` (unik — kutip persis awal bullet halt sampai "JANGAN restart."):
```
- `halt` — kena **FLOOR atau BLOCKER**: `needs_human` (step 2) / `blocked` (step 5) / circuit-breaker (§D) / gate `migrate` / Security Gate / **blocker lingkungan** (permission denial tak teratasi, tak bisa tulis `tasks.yaml`/commit) / **`risk: high` saat unattended** (auto-approve tak pernah nyala → emit `halt` DINI ronde-1; reason **membedakan**: floor-scan/verba-bahaya = `"risk:high (berbahaya: <verba>) butuh attended"` vs `risk` di-set manual = `"risk:high (di-set) — turunkan feature.yaml atau jalankan attended"`). Butuh manusia → driver berhenti, JANGAN restart.
```
`new_string`:
```
- `halt` — HANYA **abnormal** (amandemen 2026-08-27): circuit-breaker (§D, 2 `blocked` berakar sama) / **blocker lingkungan** (allowlist kosong, permission denial tak teratasi, tak bisa tulis `tasks.yaml`/commit, env) / state korup (`in_progress` ganda satu repo, deps rujuk task tak ada). `needs_human`/`blocked` tunggal/`migrate` destructive/`risk:high` BUKAN `halt` — mereka `review` (subtree nunggu, sisanya sudah dibangun). Ada yang rusak → driver berhenti, JANGAN restart — cek `last-run.md`.
```

- [ ] **Step 6b: §G — prosa `last-run.md` memuat antrian + blocker + auto**

`old_string` (unik):
```
Lalu prosa: task/segmen terakhir, ringkas diff, "butuh apa dari manusia". Ini bahan resume + input driver outer-loop (§H).
```
`new_string`:
```
Lalu prosa: task/segmen terakhir, ringkas diff, "butuh apa dari manusia" — (amandemen 2026-08-27) WAJIB memuat: daftar entri `queued` (segmen + `reason` + 1 baris ringkas diff), daftar blocker (`needs_human`/`blocked` + `hold:` disalin verbatim — pertanyaan `NEEDS_CONTEXT` ikut), daftar `auto` ringkas; sumber kebenaran tetap `gates.yaml`/`tasks.yaml` (prosa ini ditulis ulang tiap stop). Ini bahan resume + input driver outer-loop (§H).
```

- [ ] **Step 7: §H — backstop driver, Engkol 2, Aturan aman**

`old_string` (unik):
```
- `outcome: done` → stop sukses; `outcome: halt` → stop, **JANGAN restart** (floor = tembok).
```
`new_string`:
```
- `outcome: done` → stop sukses; `outcome: review` → stop, manusia drain pagi (`build <fitur>` attended, §I) lalu jalankan `drive.sh` lagi; `outcome: halt` → stop abnormal, **JANGAN restart** — cek `last-run.md`.
```

`old_string` (unik):
```
saat `outcome: halt`, run terjadwal berikutnya akan halt lagi (notif berulang "masih nunggu kamu") → **pause/hapus routine sampai manusia beresin**.
```
`new_string`:
```
saat `outcome: review`/`halt`, run terjadwal berikutnya akan berakhir sama lagi (nol kerja, notif berulang "masih nunggu kamu") → **pause/hapus routine sampai manusia drain/beresin**.
```

`old_string` (unik):
```
`halt` → selalu berhenti & panggil manusia, tak pernah auto-lewati `needs_human`/`migrate`/Security.
```
`new_string`:
```
`review`/`halt` → selalu berhenti & panggil manusia; driver tak pernah auto-lewati `needs_human`/migrate destructive/Security — migrate additive auto-apply HANYA bila opt-in allowlist (`wire` 5.5).
```

- [ ] **Step 8: Verifikasi + read-back**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
r=plugin/skills/build/reference.md
grep -c '^## G\. Lapor-keluar / notifikasi (mode unattended — M7)' $r   # 1 (heading utuh)
grep -Fc -e 'outcome: continue|review|done|halt' $r                     # 1
grep -Fc -e 'auto-approve tak pernah nyala' $r                           # 0
grep -Fc -e 'HARD floor tetap STOP' $r                                   # 0
grep -Fc -e 'presedensi `halt` > `continue` > `done`' $r                 # 0
grep -Fc -e 'gate ditunda ke antrian review gates.yaml' plugin/skills/build/SKILL.md   # 1
grep -Fc -e 'disalin verbatim' $r                                        # 1 (prosa §G)
python3 -c "import re,sys; t=open('plugin/skills/build/SKILL.md').read().split('---')[1]; print('colon-space di description OK' if ': ' not in t.split('description:',1)[1] else 'BOCOR : di description')"
```
Expected: `1 1 0 0 0 1` + "colon-space di description OK".

- [ ] **Step 9: Commit**

```bash
git add plugin/skills/build/SKILL.md plugin/skills/build/reference.md
git commit -m "feat(build): sync description + reference §D/§E/§G/§H — kelas A/B/C, needs_human ber-hold:, outcome review, driver/schedule kenal review

Claude-Session: https://claude.ai/code/session_01WQfR5ujAtkSf7aPKkWBswz"
```

---

### Task 6: `drive.sh` — cabang `review` (TDD dengan `drive.test.sh`)

**Files:**
- Create: `plugin/hooks/tests/drive.test.sh`
- Modify: `plugin/template/.claude/drive.sh` — blok komentar header, `case "$outcome"`

**Interfaces:**
- Consumes: header `last-run.md` (`outcome`/`done`/`review`/`blockers`) dari §G (Task 5).
- Produces: perilaku driver — `review` → berhenti + pesan `outcome=review`; dipakai README/`/schedule` (Task 10).

- [ ] **Step 1: Tulis test (gagal dulu)**

Buat `plugin/hooks/tests/drive.test.sh`:

```bash
#!/usr/bin/env bash
# Test drive.sh (outer-loop driver) — `claude` PALSU di PATH menulis last-run.md per skenario.
# Jalanin: bash plugin/hooks/tests/drive.test.sh  (exit 0 = semua lulus)
# Pola sama dengan auto-title.test.sh (counter PASS/FAIL).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
DRIVE_SRC="$ROOT/plugin/template/.claude/drive.sh"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL - $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; }
command -v jq >/dev/null 2>&1 || { echo "butuh jq"; exit 1; }

# setup <skenario>  — skenario = token per baris, satu token per putaran claude:
#   <outcome>:<done>[:<review>:<blockers>]  |  garbage  |  nofile
# Menyiapkan produk palsu yang lolos precheck (notify.sh, allowlist non-git, trust).
setup() {
  export HOME="$(mktemp -d)"
  PROD="$(cd "$(mktemp -d)" && pwd)"
  mkdir -p "$PROD/.claude" "$PROD/control/features/fitur-x" "$HOME/bin"
  cp "$DRIVE_SRC" "$PROD/.claude/drive.sh"; chmod +x "$PROD/.claude/drive.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$PROD/.claude/notify.sh"; chmod +x "$PROD/.claude/notify.sh"
  printf '{"permissions":{"allow":["Bash(git status:*)","Bash(pnpm test:*)"]}}\n' > "$PROD/.claude/settings.json"
  jq -n --arg p "$PROD" '{projects:{($p):{hasTrustDialogAccepted:true}}}' > "$HOME/.claude.json"
  printf '%s\n' "$1" > "$PROD/.claude/scenario"
  : > "$PROD/.claude/calls"
  cat > "$HOME/bin/claude" <<'FAKE'
#!/usr/bin/env bash
# claude palsu: tiap panggilan = satu putaran → baca token ke-N skenario → tulis last-run.md
DIR="$(pwd)"; REPORT="$DIR/control/features/fitur-x/last-run.md"
echo "$*" >> "$DIR/.claude/calls"
n="$(wc -l < "$DIR/.claude/calls" | tr -d ' ')"
tok="$(sed -n "${n}p" "$DIR/.claude/scenario")"
case "$tok" in
  nofile)  rm -f "$REPORT"; exit 0 ;;
  garbage) printf 'outcome: weird\ndone: 1\n' > "$REPORT"; exit 0 ;;
esac
IFS=: read -r o d r b <<< "$tok"
{ printf 'outcome: %s\ndone: %s\npending: 0\n' "$o" "$d"
  [ -n "${r:-}" ] && printf 'review: %s\nblockers: %s\n' "$r" "${b:-0}"
  printf 'reason: test\n'; } > "$REPORT"
exit 0
FAKE
  chmod +x "$HOME/bin/claude"
}
drive() { (cd "$PROD" && PATH="$HOME/bin:$PATH" bash .claude/drive.sh fitur-x 1 2>&1); }
calls() { wc -l < "$PROD/.claude/calls" | tr -d ' '; }

# 1. review → berhenti setelah 1 putaran, pesan review + angka
setup $'review:5:6:1'; out="$(drive)"
if grep -q 'outcome=review' <<<"$out" && grep -q '6 gate' <<<"$out" && [ "$(calls)" = 1 ]; then ok "review → stop 1 putaran + pesan '6 gate'"; else bad "review → stop 1 putaran + pesan" "$out"; fi

# 2. review tanpa baris review:/blockers: → tetap berhenti (toleran header lama)
setup $'review:5'; out="$(drive)"
if grep -q 'outcome=review' <<<"$out" && [ "$(calls)" = 1 ]; then ok "review tanpa angka → tetap stop"; else bad "review tanpa angka" "$out"; fi

# 3. continue → continue → done = 3 putaran, SELESAI
setup $'continue:3\ncontinue:6\ndone:9'; out="$(drive)"
if grep -q 'SELESAI' <<<"$out" && [ "$(calls)" = 3 ]; then ok "continue,continue,done → 3 putaran SELESAI"; else bad "continue→done" "$out"; fi

# 4. continue tanpa kenaikan done → mandek setelah putaran ke-2
setup $'continue:3\ncontinue:3\ncontinue:3'; out="$(drive)"
if grep -q 'NOL kemajuan' <<<"$out" && [ "$(calls)" = 2 ]; then ok "nol kemajuan → stop putaran 2"; else bad "nol kemajuan" "$out"; fi

# 5. halt → berhenti 1 putaran, pesan abnormal
setup $'halt:2'; out="$(drive)"
if grep -q 'outcome=halt' <<<"$out" && [ "$(calls)" = 1 ]; then ok "halt → stop 1 putaran"; else bad "halt" "$out"; fi

# 6. outcome tak dikenal → fail-safe stop
setup $'garbage'; out="$(drive)"
if grep -q 'tak dikenal' <<<"$out" && [ "$(calls)" = 1 ]; then ok "outcome asing → fail-safe stop"; else bad "outcome asing" "$out"; fi

# 7. last-run.md tak ditulis → stop
setup $'nofile'; out="$(drive)"
if grep -q 'last-run.md tak ada' <<<"$out" && [ "$(calls)" = 1 ]; then ok "last-run.md absen → stop"; else bad "last-run absen" "$out"; fi

# 8. precheck notify.sh absen → exit 1, nol putaran
setup $'done:1'; rm -f "$PROD/.claude/notify.sh"; out="$(drive)"; rc=$?
if grep -q 'notify.sh belum diset' <<<"$out" && [ "$(calls)" = 0 ]; then ok "precheck notify absen → exit tanpa putaran"; else bad "precheck notify" "$out"; fi

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Jalankan — pastikan GAGAL di kasus review**

Run: `bash plugin/hooks/tests/drive.test.sh`
Expected: kasus 1 & 2 `FAIL` (drive.sh lama memetakan `review` ke "outcome tak dikenal"), kasus 3–8 `ok`. Exit ≠ 0.

- [ ] **Step 3: Edit `drive.sh` — komentar header**

`old_string` (unik):
```
# Berhenti saat: outcome=done (selesai) / outcome=halt (butuh manusia — TAK di-restart) /
# satu putaran nol-kemajuan (mandek) / lewat batas waktu. Sinyal dibaca dari header
# mesin di control/features/<fitur>/last-run.md (lihat build reference §G & §H).
```
`new_string`:
```
# Berhenti saat: outcome=done (selesai) / outcome=review (gate/blocker nunggu manusia —
# drain pagi via `build <fitur>` attended, lalu jalankan lagi) / outcome=halt (ABNORMAL:
# circuit-breaker/env/allowlist/state — TAK di-restart) / satu putaran nol-kemajuan (mandek)
# / lewat batas waktu. Sinyal dibaca dari header mesin di control/features/<fitur>/last-run.md
# (lihat build reference §G, §H, §I). Gate yang butuh manusia TIDAK menghentikan build —
# ia diantrikan ke gates.yaml; build lanjut sampai tak ada task yang bisa dibangun.
```

- [ ] **Step 4: Edit `drive.sh` — baca `review:`/`blockers:` + cabang `review`**

`old_string` (unik):
```
  [[ "$done_now" =~ ^[0-9]+$ ]] || done_now=0   # header malformed/non-numerik → 0 (fail-safe: nol-kemajuan bakal nge-bail)

  case "$outcome" in
    done) echo "[drive] outcome=done → SELESAI, fitur siap di-ship 🎉"; break ;;
    halt) echo "[drive] outcome=halt → butuh manusia 🔔 (floor; TIDAK di-restart)"; break ;;
```
`new_string`:
```
  [[ "$done_now" =~ ^[0-9]+$ ]] || done_now=0   # header malformed/non-numerik → 0 (fail-safe: nol-kemajuan bakal nge-bail)
  rev_n="$(grep -m1 '^review:'   "$REPORT" | awk '{print $2}')"   # opsional (header lama tak punya) → "?"
  blk_n="$(grep -m1 '^blockers:' "$REPORT" | awk '{print $2}')"
  [[ "${rev_n:-}" =~ ^[0-9]+$ ]] || rev_n="?"
  [[ "${blk_n:-}" =~ ^[0-9]+$ ]] || blk_n="?"

  case "$outcome" in
    done)   echo "[drive] outcome=done → SELESAI, fitur siap di-ship 🎉"; break ;;
    review) echo "[drive] outcome=review → ${rev_n} gate + ${blk_n} blocker nunggu lo 🔔 — pagi jalankan 'build $FITUR' (attended) buat drain, lalu drive.sh lagi (TIDAK di-restart otomatis)"; break ;;
    halt)   echo "[drive] outcome=halt → ABNORMAL (circuit-breaker/env/allowlist/state) — cek last-run.md; TIDAK di-restart"; break ;;
```

- [ ] **Step 5: Jalankan test — pastikan LULUS semua**

Run: `bash plugin/hooks/tests/drive.test.sh`
Expected: 8× `ok`, `pass=8 fail=0`, exit 0. Juga `bash -n plugin/template/.claude/drive.sh` → exit 0 (syntax).

- [ ] **Step 6: Commit**

```bash
git add plugin/template/.claude/drive.sh plugin/hooks/tests/drive.test.sh
git commit -m "feat(drive): outcome review — stop + pesan gate/blocker nunggu, halt = abnormal; test drive.sh dengan claude palsu

Claude-Session: https://claude.ai/code/session_01WQfR5ujAtkSf7aPKkWBswz"
```

---

### Task 7: `ship` — tolak antrian belum kosong + jejak gate di body PR

**Files:**
- Modify: `plugin/skills/ship/SKILL.md` — step 1 ("Cek kelengkapan build"), step 6 (rakit body PR)

**Interfaces:**
- Consumes: `gates.yaml` `status` (§I).

- [ ] **Step 1: Step 1 — cek antrian**

`old_string` (unik):
```
→ **BERHENTI**, arahkan balik ke `build` (jangan ship fitur setengah jadi).
```
`new_string`:
```
→ **BERHENTI**, arahkan balik ke `build` (jangan ship fitur setengah jadi). **Cek antrian gate (amandemen 2026-08-27):** bila `<work-item>/gates.yaml` ada dan punya entri `status: queued` → **BERHENTI**, arahkan ke `build <fitur>` attended (drain pagi, `build/reference.md` §I) — gate yang ditunda unattended belum dilihat manusia; jangan ship di atasnya.
```

- [ ] **Step 2: Step 6 — jejak gate**

`old_string` (unik):
```
**Runbook integrasi & migrasi** (vendor di `integrations.md` / task `migrate`) ikut dirakit rule sebagai section bila relevan.
```
`new_string`:
```
**Runbook integrasi & migrasi** (vendor di `integrations.md` / task `migrate`) ikut dirakit rule sebagai section bila relevan. **Jejak gate (bila `gates.yaml` ada, amandemen 2026-08-27):** section ringkas daftar segmen `approved` (tanggal + `decision`) dan `auto` (`reason`) — siapa-review-apa; entri `auto` yang menyentuh area sensitif bawa banner "DIBANGUN UNATTENDED — sudah lewat Security & Compliance Gate 4.5".
```

- [ ] **Step 3: Verifikasi + commit**

Run: `grep -c 'amandemen 2026-08-27' plugin/skills/ship/SKILL.md` → `2`; `grep -Fc -e 'status: queued' plugin/skills/ship/SKILL.md` → `1`.

```bash
git add plugin/skills/ship/SKILL.md
git commit -m "feat(ship): tolak ship selama gates.yaml punya queued; jejak gate approved/auto di body PR

Claude-Session: https://claude.ai/code/session_01WQfR5ujAtkSf7aPKkWBswz"
```

---

### Task 8: `intake` + `feature` (scaffold byte-identik) + `upgrade` step 4 — arti baru `risk`

**Files:**
- Modify: `plugin/skills/intake/SKILL.md` — scaffold comment `risk:` (≈21), step 7 paragraf "Usulkan `risk` (M7)" (≈58)
- Modify: `plugin/skills/feature/SKILL.md` — scaffold comment `risk:` (≈23), IDENTIK
- Modify: `plugin/skills/upgrade/SKILL.md` — bullet "Fitur lama ter-floor `risk:high`" (≈48)

**Interfaces:**
- Produces: string scaffold kanonik (di bawah) — Task 13 memverifikasi byte-identik.

- [ ] **Step 1: Scaffold comment intake (≈21)**

`old_string` (unik di file):
```
risk: normal           # (M7) low | normal | high — blast-radius build; menyetir cadence build --unattended; payments-movement → floor high (hard), pii saja tidak
```
`new_string`:
```
risk: normal           # (M7) low | normal | high — blast-radius build; high = SEMUA gate segmen masuk antrian review saat unattended (bukan kill-switch); payments-movement → floor high (hard), pii saja tidak
```

- [ ] **Step 2: Scaffold comment feature (≈23) — IDENTIK**

Terapkan **persis** edit Step 1 di `plugin/skills/feature/SKILL.md` (old/new string sama byte-per-byte).

- [ ] **Step 3: Step 7 intake — pemicu `high` + arti baru**

`old_string` (unik):
```
`high` bila build-nya sendiri berbahaya: operasi **destruktif/irreversible**; **migrasi skema/data**; **batas auth/keamanan**
```
`new_string`:
```
`high` bila build-nya sendiri berbahaya: operasi **destruktif/irreversible**; **migrasi destructive/backfill atas tabel existing** (tabel/kolom baru additive TIDAK memicu — task `migrate` punya jalur sendiri di `build` step 3, amandemen 2026-08-27); **batas auth/keamanan**
```

Lalu `old_string` (unik):
```
Tulis ke `feature.yaml` `risk`. Advisory — default `normal` bila tak yakin; user konfirmasi di gate ini.
```
`new_string`:
```
Tulis ke `feature.yaml` `risk`. Advisory — default `normal` bila tak yakin; user konfirmasi di gate ini. **Arti `risk` di `build` (amandemen 2026-08-27): BUKAN kill-switch unattended** — `high` = semua gate segmen masuk antrian review pagi (`gates.yaml`), `normal`/`low` = floor-scan memutuskan per segmen; build tak pernah berhenti karena tag ini.
```

- [ ] **Step 4: Upgrade step 4 — bullet pemulihan jadi opsional**

`old_string` (unik — kutip persis seluruh bullet):
```
- **Fitur lama ter-floor `risk:high`** (floor lama, sebelum M7-amend 2026-06-18) tetap halt saat unattended — `upgrade` TIDAK menyentuh `feature.yaml` (knowledge). Pemulihan manual: edit `feature.yaml` `risk: high → normal` untuk fitur yang di bawah aturan baru TIDAK lagi ter-floor (pii-only, ATAU payments yang read-only — tampil harga/invoice/saldo, tak gerak uang), atau re-run `intake` (menilai ulang `sensitivity` + floor sekaligus, bila tag-nya sendiri keliru — mis. ter-tag `payments` padahal read-only).
```
`new_string`:
```
- **Fitur lama ber-`risk:high`** — sejak amandemen 2026-08-27 `risk:high` BUKAN kill-switch: unattended tetap jalan, semua gate segmennya masuk antrian review pagi (`gates.yaml`); **nol pemulihan wajib**. Opsional: edit `feature.yaml` `risk: high → normal` bila ingin sebagian segmen auto-approve (fitur pii-only / payments read-only), atau re-run `intake` bila tag `sensitivity`-nya sendiri keliru. `upgrade` TIDAK menyentuh `feature.yaml` (knowledge).
- **Opt-in apply-migrate additive belum diset** (produk ber-DB, `permissions.allow` tanpa perintah apply migrasi) → ingatkan: tanpa opt-in, migrasi `kind: additive` saat unattended di-hold `needs_human` tiap pagi (`build` step 3); tawarkan via merge `settings.json` step 2.
```

- [ ] **Step 5: Verifikasi byte-identik + no colon-space leak**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
A=$(grep -F 'risk: normal           #' plugin/skills/intake/SKILL.md | head -1)
B=$(grep -F 'risk: normal           #' plugin/skills/feature/SKILL.md | head -1)
[ "$A" = "$B" ] && echo IDENTIK || { echo BEDA; echo "$A"; echo "$B"; }
printf '%s' "${A#*#}" | grep -c ': ' ; echo "(harus 0 — nol colon-space di komentar)"
grep -Fc -e 'kill-switch' plugin/skills/intake/SKILL.md   # 2 (scaffold + step 7)
grep -Fc -e 'migrasi skema/data' plugin/skills/intake/SKILL.md   # 0
grep -Fc -e 'Opt-in apply-migrate additive belum diset' plugin/skills/upgrade/SKILL.md  # 1
```
Expected: `IDENTIK`, `0`, `2`, `0`, `1`.

- [ ] **Step 6: Commit**

```bash
git add plugin/skills/intake/SKILL.md plugin/skills/feature/SKILL.md plugin/skills/upgrade/SKILL.md
git commit -m "feat(intake,feature,upgrade): risk:high = antrian review (bukan kill-switch), migrasi additive tak memicu high; upgrade — pemulihan opsional + ingat opt-in migrate

Claude-Session: https://claude.ai/code/session_01WQfR5ujAtkSf7aPKkWBswz"
```

---

### Task 9: `wire` 5.5 + `upgrade` step 2 — opt-in allowlist apply-migrate additive

**Files:**
- Modify: `plugin/skills/wire/SKILL.md` — 5.5 paragraf pertama (larangan apply-migrate), paragraf baru "Opt-in apply-migrate additive" sesudah paragraf "Allowlist multi-repo"
- Modify: `plugin/skills/upgrade/SKILL.md` — step 2 checklist `settings.json` (≈31), bullet MERGE `settings.json` (≈38)

**Interfaces:**
- Produces: bentuk rule `Bash(<perintah-apply-migrasi>:*)` + deny cermin rollback — dibaca `build` step 3 (Task 3) saat cek allowlist.

- [ ] **Step 1: wire 5.5 — pengecualian ber-opt-in**

`old_string` (unik):
```
HANYA perintah yang sifatnya baca/verifikasi — JANGAN pernah masukkan: push/deploy/apply-migrate/`rm`/perintah jaringan-tulis (biar tetap nyangkut di prompt — itu memang fungsinya).
```
`new_string`:
```
HANYA perintah yang sifatnya baca/verifikasi — JANGAN pernah masukkan: push/deploy/`rm`/perintah jaringan-tulis (biar tetap nyangkut di prompt — itu memang fungsinya). **Apply-migrate = pengecualian ber-opt-in (amandemen 2026-08-27), lihat paragraf "Opt-in apply-migrate additive" di bawah — tanpa opt-in tetap TIDAK masuk allowlist.**
```

- [ ] **Step 2: wire 5.5 — paragraf opt-in baru (sisipkan SEBELUM paragraf "**Setup notify unattended (skippable, M7-amend 2026-06-18):**")**

`old_string` (unik — awal paragraf notify):
```
**Setup notify unattended (skippable, M7-amend 2026-06-18):**
```
`new_string` (paragraf baru + baris kosong + awal paragraf notify yang sama):
```
**Opt-in apply-migrate additive (skippable, amandemen 2026-08-27):** untuk unit ber-DB, tanyakan TERPISAH dari rule verifikasi: *"Izinkan `build --unattended` apply migrasi `kind: additive` (tabel/kolom baru, reversible) otomatis? (skip = additive bakal di-hold `needs_human` & nunggu kamu tiap pagi)"* — **default skip** (konservatif). Bila ya → turunkan perintah apply **by-understanding dari `stack.orm`/tool migrasi** unit (mis. `alembic upgrade`, `prisma migrate deploy`, `drizzle-kit migrate`, `supabase db push`, `sqlx migrate run`, `goose up` — bukan daftar tetap) → APPEND `Bash(<perintah-apply>:*)` ke `permissions.allow` (prefix; wildcard-tengah mati — bentuk `cd`/`-C` per path bila tool butuh cwd unit, enumerasi seperti `git -C`), DAN APPEND **deny cermin rollback/reset** tool yang sama ke `permissions.deny` (mis. `Bash(alembic downgrade:*)`, `Bash(prisma migrate reset:*)`, `Bash(supabase db reset:*)`) — rollback = keputusan manusia, tak pernah dibutuhkan unattended. Dedup; **GATE** tampilkan rule + approve. **Model kepercayaan (jujur):** harness TIDAK bisa membedakan additive vs destructive — ia hanya melihat perintah. Pagar destructive = rantai plugin: `migrate.kind` ditulis `breakdown` → di-approve user di gate breakdown → `build` cross-check grep DDL saat apply → hold bila bohong (`build` step 3). Mengizinkan perintah ini = memercayai rantai itu — model kepercayaan yang SAMA dengan `git commit` yang sudah di-allowlist. Tanpa opt-in, `build` men-hold migrasi additive (`hold: "allowlist migrate absen — wire 5.5"`) — bukan freeze, bukan `halt`.

**Setup notify unattended (skippable, M7-amend 2026-06-18):**
```

- [ ] **Step 3: upgrade step 2 — checklist (≈31)**

`old_string` (unik):
```
**`includeCoAuthoredBy: false` + `attribution` (`commit`/`pr` kosong)** — matiin trailer co-author Claude di commit & body PR produk?
```
`new_string`:
```
**`includeCoAuthoredBy: false` + `attribution` (`commit`/`pr` kosong)** — matiin trailer co-author Claude di commit & body PR produk? **Opt-in apply-migrate additive** (`Bash(<perintah-apply-migrasi>:*)` + deny rollback cermin — HANYA bila user opt-in; absen = default konservatif, BUKAN cacat)?
```

- [ ] **Step 4: upgrade step 2 — bullet MERGE (≈38)**

`old_string` (unik):
```
(logika `wire` step 5.5: HANYA baca/verifikasi — test/lint/typecheck/build; JANGAN push/deploy/apply-migrate/`rm`/jaringan-tulis). Tampilkan hasil merge → approve.
```
`new_string`:
```
(logika `wire` step 5.5: HANYA baca/verifikasi — test/lint/typecheck/build; JANGAN push/deploy/`rm`/jaringan-tulis; apply-migrate HANYA lewat opt-in). **Opt-in apply-migrate additive (amandemen 2026-08-27):** untuk unit ber-DB tawarkan pertanyaan terpisah persis `wire` 5.5 (*"Izinkan `build --unattended` apply migrasi `kind: additive` otomatis?"*, default skip) → bila ya, derive perintah apply dari `stack.orm` + deny rollback cermin; GATE. Tampilkan hasil merge → approve.
```

- [ ] **Step 5: Verifikasi + read-back**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -Fc -e 'push/deploy/apply-migrate' plugin/skills/wire/SKILL.md plugin/skills/upgrade/SKILL.md   # keduanya 0
grep -Fc -e 'Opt-in apply-migrate additive' plugin/skills/wire/SKILL.md      # 2 (rujukan + heading paragraf)
grep -Fc -e 'Opt-in apply-migrate additive' plugin/skills/upgrade/SKILL.md   # 3 (checklist + merge + step 4 dari Task 8)
grep -Fc -e 'deny cermin rollback' plugin/skills/wire/SKILL.md               # 1
```
Read-back wire 5.5 utuh: urutan paragraf = verifikasi → multi-repo `git -C` → opt-in migrate → notify. Kalimat "bentuk `cd`/`-C` per path bila tool butuh cwd unit" konsisten dengan aturan enumerasi `git -C` di paragraf sebelumnya.

- [ ] **Step 6: Commit**

```bash
git add plugin/skills/wire/SKILL.md plugin/skills/upgrade/SKILL.md
git commit -m "feat(wire,upgrade): opt-in allowlist apply-migrate additive (default skip) + deny rollback cermin + catatan model kepercayaan

Claude-Session: https://claude.ai/code/session_01WQfR5ujAtkSf7aPKkWBswz"
```

---

### Task 10: Doc-sync — `breakdown` schema, `guide`, `ask`, README, induk spec

**Files:**
- Modify: `plugin/skills/breakdown/reference.md` — §A komentar `- migrate:` + baris `hold:` sesudah `commits:`
- Modify: `plugin/skills/guide/reference.md` — cheatsheet `/build`
- Modify: `plugin/skills/ask/SKILL.md` — tabel Status (+1 baris)
- Modify: `README.md` — blockquote "Bikin fitur" + blockquote baru unattended + kalimat Status M7
- Modify: `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` — frasa "cadence approval"

- [ ] **Step 1: breakdown/reference.md §A — komentar migrate + `hold:`**

`old_string` (unik):
```
          - migrate: <deskripsi>   #   DESTRUKTIF → build TAMPILKAN + GATE sebelum apply (jangan auto)
```
`new_string`:
```
          - migrate: <deskripsi>   #   build: attended = TAMPILKAN + GATE sebelum apply; unattended = additive auto-apply (bila opt-in allowlist wire 5.5), destructive/backfill = hold needs_human
```

Lalu `old_string` (unik):
```
        commits: [<base7>..<head7>, ...]   # OPSIONAL — DIISI build saat done (rentang commit per repo tersentuh, audit task→commit); bukan dari breakdown
```
`new_string`:
```
        commits: [<base7>..<head7>, ...]   # OPSIONAL — DIISI build saat done (rentang commit per repo tersentuh, audit task→commit); bukan dari breakdown
        hold: "<alasan 1 baris>"           # OPSIONAL — DIISI build saat needs_human BUKAN-karena-manual: (migrate destructive/backfill | allowlist migrate absen | NEEDS_CONTEXT: <pertanyaan> | konflik <invariant>); dihapus saat keluar needs_human; bukan dari breakdown (build/reference.md §I)
```

- [ ] **Step 2: guide/reference.md cheatsheet**

`old_string` (unik):
```
; resumable; ada mode `--unattended`.
```
`new_string`:
```
; resumable; mode `--unattended` = gate ditunda ke antrian `gates.yaml` (review pagi via `/build` attended = drain), blocker cuma nahan subtree-nya.
```

- [ ] **Step 3: ask/SKILL.md tabel Status (+1 baris sesudah baris Status)**

`old_string` (unik):
```
| Status: fitur apa saja, draft/active/shipped, perilaku 1 fitur | `features/*/feature.yaml` (+ `business.md`) |
```
`new_string`:
```
| Status: fitur apa saja, draft/active/shipped, perilaku 1 fitur | `features/*/feature.yaml` (+ `business.md`) |
| Antrian gate unattended: "ada yang nunggu review gw?", "kenapa build berhenti semalam" | `features/*/gates.yaml` (`queued`/`approved`/`auto`) + `last-run.md` (header `outcome`/`review`/`blockers`) |
```

- [ ] **Step 4: README "Bikin fitur"**

`old_string` (unik):
```
`build` jalanin+verifikasi actions (migrasi lewat gate) dan uji integrasi cross-app;
```
`new_string`:
```
`build` jalanin+verifikasi actions (migrasi lewat gate; unattended: additive auto-apply ber-opt-in, destructive nunggu lo) dan uji integrasi cross-app;
```

Lalu sisipkan blockquote baru: `old_string` (unik — awal blockquote add-app):
```
> Kalau sebuah fitur butuh **app baru** (belum ada di `workspace.yaml`),
```
`new_string`:
```
> **Mode tanpa pengawasan:** `/build <nama> --unattended` (atau `bash .claude/drive.sh <nama>` semalaman) — gate yang butuh mata manusia **ditunda ke antrian** `control/features/<nama>/gates.yaml`, bukan menghentikan build; task berikutnya tetap dibangun. Pagi: `/build <nama>` (attended) nguras antrian — diff + test + security-critic + "kalau direvisi, yang kena" → approve/revisi per gate. Blocker beneran (migrasi destructive, langkah manual, error) cuma nahan subtree-nya; driver berhenti dengan `outcome: review` saat tak ada lagi yang bisa dibangun.

> Kalau sebuah fitur butuh **app baru** (belum ada di `workspace.yaml`),
```

- [ ] **Step 5: README Status — kalimat M7**

`old_string` (unik — kutip persis):
```
**Autonomy (Langkah 3 — M7):** `build --unattended` auto-approve segmen risk rendah (`feature.yaml` `risk`); HARD floor (`migrate`/`needs_human`/`blocked`/risk tinggi/Security) tetap attended; allowlist harness + rem run-level (circuit breaker + cap volume); lapor-keluar via hook (`template/.claude/` `on-stop.sh`/`on-permission.sh`/`notify.sh`, sumber-kebenaran laporan disk); outer-loop driver dua-engkol (`drive.sh` bash grind kontinu + `/schedule` cloud) buat `build --unattended` berkelanjutan lintas-sesi (sinyal `outcome` di `last-run.md`).
```
`new_string`:
```
**Autonomy (Langkah 3 — M7, amandemen 2026-08-27 "gate ditunda"):** `build --unattended` tak pernah berhenti karena gate — gate yang butuh manusia (`risk:high`/floor-scan/DDL/penyimpangan) **diantrikan** ke `control/features/<fitur>/gates.yaml` (+ `security-critic` otomatis), task berikutnya tetap dibangun; blocker (migrasi destructive/backfill, `needs_human`, `blocked`) cuma nahan subtree-nya (`hold:`); migrasi `kind: additive` auto-apply lewat opt-in allowlist `wire` 5.5; pagi `build` attended menguras antrian (drain); allowlist harness + rem run-level (circuit breaker + cap volume); lapor-keluar via hook (`template/.claude/` `on-stop.sh`/`on-permission.sh`/`notify.sh`, sumber-kebenaran laporan disk); outer-loop driver dua-engkol (`drive.sh` bash grind kontinu + `/schedule` cloud) buat `build --unattended` berkelanjutan lintas-sesi (sinyal `outcome: continue|review|done|halt` di `last-run.md`; `ship` menolak selama antrian belum kosong).
```

- [ ] **Step 6: Induk spec — frasa "cadence approval"**

`old_string` (unik):
```
yang menyetir **cadence approval** `build` saat mode unattended (M7)
```
`new_string`:
```
yang menyetir **kadar review** `build` saat unattended (M7; `high` = semua gate diantrikan ke `gates.yaml`, bukan kill-switch — amandemen 2026-08-27)
```

- [ ] **Step 7: Verifikasi + commit**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -Fc -e 'hold: "<alasan 1 baris>"' plugin/skills/breakdown/reference.md   # 1
grep -Fc -e 'gates.yaml' plugin/skills/guide/reference.md plugin/skills/ask/SKILL.md README.md   # ≥1 tiap file
grep -Fc -e 'auto-approve segmen risk rendah' README.md   # 0
grep -Fc -e 'cadence approval' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md   # 0
```

```bash
git add plugin/skills/breakdown/reference.md plugin/skills/guide/reference.md plugin/skills/ask/SKILL.md README.md docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
git commit -m "docs(sync): gate ditunda — skema hold: di breakdown, cheatsheet guide, tabel ask, README bikin-fitur/status, induk spec risk axis

Claude-Session: https://claude.ai/code/session_01WQfR5ujAtkSf7aPKkWBswz"
```

---

### Task 11: Amandemen spec M7 + pointer spec 2026-06-18

**Files:**
- Modify: `docs/superpowers/specs/2026-06-06-m7-graduated-autonomy-design.md` — APPEND di akhir
- Modify: `docs/superpowers/specs/2026-06-18-unattended-risk-floor-decouple-design.md` — §6, sesudah bullet "Risk granularitas per-segmen/per-milestone"

- [ ] **Step 1: Append amandemen ke spec M7**

`old_string` (unik — baris terakhir file):
```
(Sejarah D4 di atas DIPERTAHANKAN — ini catatan menyusul, bukan tulis-ulang.)
```
`new_string`:
```
(Sejarah D4 di atas DIPERTAHANKAN — ini catatan menyusul, bukan tulis-ulang.)

---

## Amendemen 2026-08-27 — gate ditunda ke antrian review (`gates.yaml`)

Operator lapor build tetap terhalang kehadiran manusia (`risk:high` = halt ronde-1;
floor-scan + `migrate` = stop-the-world; `drive.sh` mati di `halt`). Perubahan:

- **Gate ditunda, bukan stop.** Gate memeriksa kode yang sudah jadi → persetujuan
  diantrikan ke `<work-item>/gates.yaml` (`queued|approved|revised|auto`), build lanjut
  membangun di atasnya. Tiga kelas titik-manusia: A gate review (ditunda) · B blocker
  (subtree nunggu via `needs_human`/`blocked` + `hold:`) · C auto.
- **`risk:high` BUKAN kill-switch** — = semua gate segmen diantrikan. D4/2026-06-18 tetap
  berlaku untuk floor payments-movement, kini non-blocking.
- **Migrate by `kind`:** additive auto-apply (opt-in allowlist `wire` 5.5 + cross-check DDL);
  destructive/backfill hold `needs_human`.
- **`outcome: review`** baru; `halt` hanya abnormal. `ship` menolak selama ada `queued`.
- **Arahan "JANGAN batch/sticky-approve" DIPERTEGAS, bukan dibatalkan:** approve tetap
  per gate (tak sticky); yang di-batch hanya WAKTUNYA (drain pagi). Lintas-app sticky
  tetap dilarang (M7-FLAG-B).

Spec: `docs/superpowers/specs/2026-08-27-build-deferred-gate-review-queue-design.md`.
Plan: `docs/superpowers/plans/2026-08-27-build-deferred-gate-review-queue.md`.
```

- [ ] **Step 2: Pointer di spec 2026-06-18 §6**

`old_string` (unik):
```
Dicatat sebagai kandidat lanjutan; tidak dikerjakan di iterasi ini.
```
`new_string`:
```
Dicatat sebagai kandidat lanjutan; tidak dikerjakan di iterasi ini. **Menyusul 2026-08-27:** kebutuhan ini terpenuhi lewat jalur BERBEDA — antrian gate `gates.yaml` (gate ditunda, bukan tag per-task), lihat `2026-08-27-build-deferred-gate-review-queue-design.md`.
```

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-06-06-m7-graduated-autonomy-design.md docs/superpowers/specs/2026-06-18-unattended-risk-floor-decouple-design.md
git commit -m "docs(spec): amandemen M7 — gate ditunda ke antrian review; pointer di spec decouple §6

Claude-Session: https://claude.ai/code/session_01WQfR5ujAtkSf7aPKkWBswz"
```

---

### Task 12: Release — bump `0.23.0`, description, regen `plugin-kimi`

**Files:**
- Modify: `plugin/.claude-plugin/plugin.json` — `version` + substring description M7
- Modify: `.claude-plugin/marketplace.json` — `metadata.version`, `plugins[0].version`, substring description
- Regenerate: `plugin-kimi/` via `tools/build-kimi.sh`

- [ ] **Step 1: plugin.json**

`old_string` (unik):
```
graduated autonomy M7 (build --unattended auto-approve segmen risk rendah dengan hard-floor migrate/needs_human/security, allowlist harness + rem run-level, lapor-keluar via hook + outer-loop driver drive.sh/schedule lintas-sesi)
```
`new_string`:
```
graduated autonomy M7 (build --unattended: gate ditunda ke antrian review gates.yaml + security-critic otomatis, blocker subtree-only via hold:, migrate additive auto-apply ber-opt-in, outcome review + drain pagi; allowlist harness + rem run-level, lapor-keluar via hook + outer-loop driver drive.sh/schedule lintas-sesi)
```
Lalu `"version": "0.22.0"` → `"version": "0.23.0"`.

- [ ] **Step 2: marketplace.json**

`old_string` (unik): `graduated autonomy M7 build --unattended + outer-loop driver` → `new_string`: `graduated autonomy M7 build --unattended (gate ditunda ke antrian gates.yaml + drain pagi) + outer-loop driver`. Ganti KEDUA `"version": "0.22.0"` → `"0.23.0"` (metadata + plugins[0]).

- [ ] **Step 3: Validasi JSON + commit bump**

Run: `jq . plugin/.claude-plugin/plugin.json >/dev/null && jq . .claude-plugin/marketplace.json >/dev/null && echo JSON-OK`; `grep -c '0.23.0' plugin/.claude-plugin/plugin.json .claude-plugin/marketplace.json` → `1` dan `2`.

```bash
git add plugin/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore(release): bump 0.23.0 — gate ditunda ke antrian review (gates.yaml), blocker subtree-only, migrate additive auto-apply opt-in, outcome review

Claude-Session: https://claude.ai/code/session_01WQfR5ujAtkSf7aPKkWBswz"
```

- [ ] **Step 4: Regen plugin-kimi + test generator**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
bash tools/build-kimi.sh && bash tools/tests/build-kimi.test.sh
grep -c 'Antrian gate' plugin-kimi/skills/build/reference.md   # ≥1 (§I ikut ter-generate)
grep -c 'BELUM berlaku di Kimi' plugin-kimi/skills/build/reference.md   # 1 (note D5 masih nempel di §G)
```
Expected: generator `OK — plugin-kimi/ regenerated (25 skills)`; test `fail=0`; `≥1`; `1`.

- [ ] **Step 5: Commit regen**

```bash
git add plugin-kimi
git commit -m "chore(kimi): regen plugin-kimi 0.23.0 — gate ditunda ke antrian review

Claude-Session: https://claude.ai/code/session_01WQfR5ujAtkSf7aPKkWBswz"
```

---

### Task 13: Verifikasi akhir — grep konsistensi, semua test, desk-check skenario nyata

**Files:** tidak ada edit (kecuali perbaikan temuan — commit terpisah `fix(review): …`).

- [ ] **Step 1: Frasa lama harus 0 di seluruh `plugin/`**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
for p in 'halt` dini ronde-1' 'auto-approve tak nyala' 'auto-approve tak pernah nyala' 'HARD floor — TETAP STOP' 'HARD floor tetap STOP' 'presedensi `halt` > `continue` > `done`' 'auto-approve segmen risk rendah' 'push/deploy/apply-migrate' 'STOP attended' 'outcome: continue|done|halt'; do
  printf '%-50s %s\n' "$p" "$(grep -rFc -e "$p" plugin/skills plugin/template README.md | awk -F: '{s+=$2} END{print s+0}')"
done
```
Expected: semua `0`. (Catatan: "STOP attended" boleh muncul HANYA bila diawali "attended:"/"attended STOP" bentuk baru — kalau grep >0, buka konteksnya dan pastikan cabang unattended-nya ada.)

- [ ] **Step 2: Frasa baru harus ada & konsisten**

Run:
```bash
grep -rFc -e 'gates.yaml' plugin/skills/build/SKILL.md plugin/skills/build/reference.md plugin/skills/ship/SKILL.md plugin/skills/ask/SKILL.md plugin/skills/guide/reference.md README.md
grep -rFc -e 'hold:' plugin/skills/build/SKILL.md plugin/skills/build/reference.md plugin/skills/breakdown/reference.md
grep -rFc -e 'outcome: review' plugin/skills/build/SKILL.md plugin/skills/build/reference.md
grep -rn 'queued | approved | revised | auto' plugin/skills/build/reference.md | wc -l   # 1
grep -rho 'presedensi `halt` > `continue` > `review` > `done`' plugin/skills/build | sort | uniq -c   # ≥2, satu bentuk
```
Expected: tiap file ≥1; bentuk presedensi seragam.

- [ ] **Step 3: Semua test bash ijo**

Run: `bash plugin/hooks/tests/drive.test.sh && bash plugin/hooks/tests/auto-title.test.sh && bash tools/tests/build-kimi.test.sh && echo ALL-GREEN`
Expected: `ALL-GREEN`. Bila `build-kimi.test.sh` menulis ulang `plugin-kimi/` → `git status --porcelain plugin-kimi` harus kosong (regen deterministik).

- [ ] **Step 4: Desk-check skenario nyata (reasoning atas `build/SKILL.md` baru; tulis hasil di `last-run`-style catatan ke scratchpad, BUKAN ke repo produk)**

Baca `tasks.yaml` + `feature.yaml` fitur berikut (read-only) lalu jalankan aturan step 1–7 di kepala; ekspektasi:

| fitur | input | ekspektasi |
|---|---|---|
| `~/Developer/project/branding/control/features/login` | `risk: high`, 25 task, 7 milestone | 0 stop; semua segmen `queued` (risk:high) kecuali tidak ada `auto`; `security-critic` jalan di 7 gate (`sensitivity: [pii]` → semua gate, bukan cuma ber-verba — koreksi review 2026-08-28); `outcome: review`, `review: 7`, `blockers: 0`; blast-radius G1 gate-wide ⊇ {T4, T5, T9, T10, T13, T15} (aturan §I: `files:` tumpang-tindih ATAU jalur `deps:`; 17 task per hitungan review 2026-08-28) |
| `~/Developer/project/branding/control/features/generate-website` | T7 `migrate` `kind: additive` (3 tabel + RLS), `risk: high` | apply di-allowlist → T7 cross-check DDL lolos (jalur maju `upgrade()` = `CREATE`/`ENABLE ROW LEVEL SECURITY`; `downgrade()` ber-`drop_table`/`DROP TYPE` DIABAIKAN — koreksi review 2026-08-28) → apply → `done` → gate `queued` "ddl additive T7 (auto-applied)"; apply TIDAK di-allowlist → T7 `needs_human` + `hold: "allowlist migrate absen — wire 5.5"`, dependents T7 nunggu, task lain lanjut |
| `~/Developer/BFI/los-platform/control/features/simplify-scoring-stp` | `risk: normal`, `sensitivity: []`, diff "validation-gating" | segmen M1 `queued` "floor-scan (validasi input)" — BUKAN stop; `review: 1` di akhir |
| `~/Developer/project/branding/control/features/marketing-landing` | `risk: low`, semua bersih | semua segmen `auto`; 7a jalan; `outcome: done` — **regresi nol** vs `last-run.md` aslinya |
| hipotetis | migrate `kind: destructive` di M1, 10 task lain independen | task migrate `needs_human` + `hold:` + `commits:`; dependents nunggu; 10 lain dibangun; `review` dengan `blockers: 1` |
| hipotetis | 2 task `blocked` berakar sama | `halt` "dugaan sistemik" (bukan `review`) |
| hipotetis | drain pagi: revisi G1 | corrective `kind: fix` ke milestone G1; G1 `revised`; segmen due lagi → G-baru |

Tiap baris yang hasil reasoning-nya BEDA dari ekspektasi = cacat prosa → perbaiki (`fix(review): …`) lalu ulangi Step 1–3.

- [ ] **Step 5: Commit temuan (bila ada) + laporan**

Bila ada perbaikan: `git commit -m "fix(review): temuan verifikasi pasca-eksekusi — <ringkas>"` (+ footer Claude-Session). Laporkan ke user: daftar commit, hasil 3 test, tabel desk-check terisi, dan **rekomendasi live smoke** (spec §9.5): `bash .claude/drive.sh <fitur-kecil>` semalam di produk nyata, pagi `build <fitur>` drain — satu-satunya bukti end-to-end.
