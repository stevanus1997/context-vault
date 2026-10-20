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
    #   | "penyimpangan → corrective T13" | "smoke gagal: POST /login 500" | "bersih (risk:normal, floor-scan nihil)" | "debt fondasional T9: <1 baris>" | gabungan: "risk:high; floor-scan T1 (session/token)"
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
- **Scratch** (`<root>/<wi>/`, gitignored `init`): `gate-Gn-critic.md`, `gate-Gn-impact.md`. Diff segmen TIDAK bikin file baru — pakai paket `review-<base7>..<head7>.diff` per task; hilang → regenerate dari `commits:` via `git -C <path> diff <base7>..<head7>`. Critic hilang → re-run saat drain (degrade).
- **`ship`** menolak selama ada `status: queued`; body PR memuat daftar `approved` + `auto`.

### Field `hold:` di `tasks.yaml` (opsional, build-written — preseden `commits:`; BUKAN status baru)
Ditulis saat `build` men-set `needs_human` **bukan-karena-`manual:`**, satu baris self-describing & durable: `hold: "migrate destructive — nunggu approve (affects: brands.kit)"` · `hold: "allowlist migrate absen — wire 5.5"` · `hold: "NEEDS_CONTEXT: <pertanyaan implementer verbatim>"` · `hold: "konflik invariant Tenancy — query tanpa filter tenant"` · `hold: "reuse basi: users_v2 — tabel di-rename fitur lain (step 1)"`. Dihapus saat task keluar dari `needs_human`. Absen (task `manual:` / `tasks.yaml` lama) → drain derive dari bentuk task: ada `manual:` → checklist manual; ada `actions: migrate` → migrate. Prosa `last-run.md` MENYALIN `hold:` (bukan sumber kebenaran — ia ditulis ulang tiap stop).

### Drain pagi (attended) — dipicu SKILL step 1
**Pemicu:** `build <fitur>` tanpa flag DAN (`gates.yaml` punya `queued` ATAU `tasks.yaml` punya `needs_human`/`blocked`) → mode drain pagi SEBELUM dispatch apa pun. `--unattended` → skip drain pagi (lanjut bangun; tak ada task READY → `outcome: review`).

**Urutan sajian:**
1. **Ringkasan** dari `last-run.md` + `gates.yaml`: *"Semalam: 25 done · 6 gate queued (G1–G4, G6, G7) · 1 blocker (T7 migrate destructive) · 1 auto (web×M5)."*
2. **Re-run test sekali per repo** (baseline segar; "jangan percaya laporan") — hasil ditampilkan di tiap gate.
3. **Gate `queued` urut G-id (tertua dulu)** — revisi di G1 paling mungkin merembet ke bawah.
4. **Blocker** (`needs_human`/`blocked`) sesudahnya.
5. Daftar `auto` ringkas, nol aksi.

**Tiap gate = UX gate step 6 + bukti semalam:** header (segmen · task · commits · alasan · tanggal) · diff per task · hasil test + "dibangun vs task" · **Challenge checklist dievaluasi LIVE** (`rules/anti-yes-man.md`; tak disimpan semalam) · temuan security-critic (`critic:`; hilang → jalankan sekarang) · laporan migration-impact (`impact:`) · observasi smoke · **"Kalau direvisi, yang kena:"** = task yang dibangun *sesudah* gate ini — (a) task milik entri gate ber-G-id **lebih besar**, plus (b) task `done` yang belum masuk entri gate mana pun (segmennya belum due) — yang `files:`-nya tumpang-tindih dengan `files:` task gate ini ATAU punya jalur `deps:` (langsung/transitif) ke salah satu task gate ini (deterministik dari `gates.yaml` + `tasks.yaml`; superset — boleh over-report; under-report hanya bila `deps:` bolong (Guard Urutan-fanout, SKILL step 1); filter `files:` saja gagal karena konsumen kontrak `produces:` biasanya tak mengedit file produsennya — koreksi 2026-08-27 pasca-verifikasi) · "Coba sendiri" Part A (§D) · · **bila `reason` diawali "debt fondasional"** (pintu ke-4 unattended, SKILL step 6) → tampilkan entri `control/debt.yaml` provisional-nya (`observed:` berawalan "UNATTENDED — belum diputuskan:") + minta **route eksplisit SEKARANG** (`/architect` · `/add-package` · `/wire` · ATAU catat sadar `owner: foundation`) — tulis di `decision:` (mis. `"approve; debt api-cache-layer → route /architect"`) dan hapus awalan provisional di `observed:` (`rules/debt-aware.md`); keputusan mahal tak boleh lolos lewat approve-diff saja (`rules/anti-yes-man.md`) · → **approve / revisi** — **per gate, TANPA "approve semua"** (sticky-approve dilarang M7). Satu gate = satu panggilan `AskUserQuestion` sesudah konten gate itu tampil sebagai teks — jangan gabung beberapa gate dalam satu panggilan (`rules/ask-user.md`).

**Keputusan:**
- **approve** → `status: approved` + `decided_at` + `decision: approve`.
- **revisi** → disiplin fix embed yang sama dengan penyimpangan step 6: corrective task `kind: fix` (`corrects: [T..]`, `observed: <keberatan user>`) ke **milestone yang sama** dengan segmen → segmen due lagi saat corrective `done` → entri gate baru. Gate ini → `status: revised` + `decision: "revisi: <1 baris> → corrective Tn"`.
- Sesi mati mid-drain pagi → `build` berikutnya lanjut dari `queued` tersisa (atomik).

**Blocker per jenis** (jenis dari `hold:`; absen → derive dari bentuk task):
- `needs_human` (`manual:`) → checklist → user konfirmasi → jalankan actions → `in_progress` → `done` (existing §E).
- `needs_human` (migrate destructive/backfill) → tampilkan rencana + `migration-impact` (`rules/migration-impact.md`) → approve → apply → verifikasi → regen `control/schema/<schema_owner(unit)>.md` → `done`. Tolak → user pilih: corrective task (ubah migrasi) ATAU balik `breakdown`.
- `needs_human` (allowlist migrate absen) → tawarkan: approve apply SEKARANG (attended — permission prompt harness jalan normal) ATAU jalankan `wire` 5.5 (opt-in) dulu supaya malam berikutnya otomatis.
- `needs_human` (`NEEDS_CONTEXT`) → tampilkan pertanyaan dari `hold:` → user jawab → re-dispatch dengan jawaban di-paste (§E) → hapus `hold:`.
- `needs_human` (konflik pre-flight) → tampilkan konflik → override sadar (reset `pending`) ATAU revisi via `breakdown`.
- `needs_human` (reuse basi) → tampilkan nama `reuse:` yang tak ada lagi di proyeksi skema/pohon unit → user pilih: perbaiki `reuse:` via `breakdown` (merge pertahankan status) ATAU override sadar (reset `pending`; brief dirakit tanpa nama basi).
- `blocked` → objeksi reviewer/error (report file + prosa) → arah user → reset eksplisit `pending` (§E; tetap TIDAK auto-retry).

**Akhir drain — STOP + ringkasan, BUKAN otomatis lanjut bangun.** Tulis ulang `last-run.md` (`outcome` `continue`/`review`/`done` + prosa "drain pagi: G1 approve, G2 revisi → T26 …"), lalu tanya SEKALI: *"lanjut attended sekarang, atau berhenti biar `drive.sh` yang lanjutin malam ini?"* — jangan kembali ke pola "harus ada manusia". Semua task `done` + antrian kosong sesudah drain → 7a (gate attended, SKILL step 7a) → `done` → *"siap di-`ship`"*.

**Kimi:** drain pagi = attended → jalan di Kimi (state di disk); `--unattended` tetap ditolak di Kimi.
