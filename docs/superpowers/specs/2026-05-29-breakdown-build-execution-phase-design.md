# context-vault — Fase Eksekusi: `breakdown` + `build` (Design Spec)

- **Tanggal:** 2026-05-29
- **Status:** Draft disetujui untuk masuk tahap perencanaan implementasi
- **Terkait:** spec induk `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (ini me-REVISI satu non-tujuan v1-nya — lihat §3)

---

## 1. Ringkasan

Spec induk menutup pipeline fitur di `plan` (status `active`), lalu menyerahkan **implementasi** ke "pola yang sudah ada (executing-plans/subagent)" secara manual, sebelum `ship`. Praktiknya ini meninggalkan **celah menganga** antara plan yang disetujui dan ship: tidak ada yang (a) mengarahkan dari `active` ke implementasi, dan (b) tidak ada yang benar-benar **menyetir** implementasi.

Spec ini mengisi celah itu dengan **dua skill baru yang membentuk Fase Eksekusi** di antara `plan` dan `ship`:

- **`breakdown`** — memecah `plans/*.md` (yang sengaja tetap **flat**) menjadi **`tasks.yaml` yang enriched**: tiap task punya `files` (WHERE), `approach`, dan kasus `test` (WHAT) + `deps` + `status` — **tanpa kode implementasi**. Ringan, sekali jalan, satu gate.
- **`build`** — orchestrator tipis yang mengeksekusi `tasks.yaml` task-demi-task: tiap task di-dispatch ke implementer subagent (TDD, menulis kode just-in-time lawan kode terkini), di-review 2-tahap, lalu diserahkan ke `ship`. **Resumable lintas-sesi** & **hemat konteks** lewat isolasi subagent. Ia **meminjam template + pola** `subagent-driven-development`, bukan meng-invoke skill-nya utuh (lihat §7.1).

Lifecycle fitur menjadi: `intake → fanout → plan → (active) → breakdown → build → ship → (shipped)`.

## 2. Masalah

Mengacu ke spec induk §12 (Lifecycle), transisi `active → build → ship` digambarkan sebagai langkah **"build"** manual tanpa tooling. Tiga konsekuensi:

- **C1 — Dead-air setelah `plan`.** Begitu plan di-approve (`active`), alur "ngedump": tidak ada skill yang mengarahkan pengguna mulai implementasi maupun kembali ke `ship`.
- **C2 — Implementasi tidak disetir.** Pengguna ingin AI **benar-benar mengerjakan** implementasi (minimal menyetir per app), bukan hanya menyerahkan plan.
- **C3 — Plan flat tidak siap-eksekusi.** Output `plan` adalah satu blok per app (`Model/Schema · API/Komponen · Lokasi · Test`) tanpa notasi urutan/milestone. Untuk fitur besar (mis. `auth`: login + register + forgot/change + 3 OAuth provider) ini menumpuk jadi satu "gate raksasa" kalau dieksekusi polos.

Akar: fase eksekusi tidak punya artifact perantara (task list) maupun konduktor (build).

## 3. Tujuan & Non-Tujuan

**Tujuan:**
- Menutup celah `plan → ship` dengan dua skill yang jelas perannya.
- Implementasi disetir AI, tetap di bawah **gate** dan disiplin **anti-yes-man** yang sama dengan fase lain.
- Tiap fase (`feature`/`breakdown`/`build`/`ship`) **bisa dijalankan di sesi terpisah** — handoff lewat file di `control/`, bukan lewat konteks percakapan.
- `build` **resumable lintas-sesi** dan **hemat konteks** (fase paling berat).
- `plan` **tidak diubah** (tetap flat); dekomposisi pindah ke `breakdown`.

**REVISI terhadap spec induk:** Spec induk §3 menjadikan "eksekusi/implementasi kode lintas-app" sebagai **non-tujuan v1** ("pipeline berhenti di plan yang disetujui"). Spec ini **mencabut** non-tujuan itu: implementasi yang disetir (lewat `build`) kini **masuk scope**. `build` **meminjam** building-block superpowers yang ada (`test-driven-development` sebagai skill; template prompt + pola review 2-tahap + panduan pilih-model dari `subagent-driven-development`) — TAPI **tidak** memakai `writing-plans` dan **tidak** meng-invoke `subagent-driven-development`/`executing-plans` sebagai paket utuh, karena keduanya terikat ke file plan monolitik & eksekusi continuous yang bentrok dengan model incremental + gate kita (lihat §7.1).

**Non-tujuan (tetap):**
- `build` **bukan** engine eksekusi baru dari nol — loop orkestrasinya tipis & meminjam template/pola/TDD dari superpowers (§7.1).
- Eksekusi **paralel lintas-app** (worktree per app berjalan serempak) — default `build` sekuensial (hormati dependency); paralelisasi = future.
- Status fitur granular baru — status tetap kasar (lihat §9).
- `build` tidak mengelola strategi git: ia commit per-task di branch fitur (minta izin bila di `main`), tapi **pembuatan branch, PR, & merge** tetap urusan pengguna/`ship` (§11).

## 4. Lifecycle Baru

```
Greenfield: init → architect(setup)  →             /feature → breakdown → build → ship
Brownfield: init → architect(capture) → extract(opsi) → /feature → breakdown → build → ship

/feature <nama>:  intake →(gate)→ fanout →(gate)→ plan →(gate)→  status: active
   breakdown <nama>:  plans/*.md (flat) → tasks.yaml  →(gate: peta task)
   build <nama>:      eksekusi tasks.yaml task-by-task (TDD) →(gate per app, adaptif) → "siap ship"
/ship <nama>:     code review + quality + alignment(critic) → PR → status: shipped → render-docs
```

Dua kotak tengah (`breakdown`, `build`) adalah yang baru. `breakdown` & `build` **dipanggil eksplisit** (tidak di-auto-chain oleh `feature`) — justru supaya tiap fase bisa jadi sesi sendiri (lihat §8).

## 5. Skill `breakdown`

- **Tujuan:** mengubah `plans/*.md` flat menjadi rencana kerja yang siap-eksekusi (`tasks.yaml`): task kecil, berurutan, ber-dependency.
- **Input:** `control/features/<fitur>/plans/_shared.md` + `plans/<app>.md` + `fanout.md` (untuk Urutan lintas-app) + `control/workspace.yaml` (untuk `app`/`path`/`stack`). Boleh **mengintip ringan** struktur kode untuk menakar granularitas, tetapi **baca-kode mendalam = jatah `build`** (jaga `breakdown` tetap ringan).
- **Perilaku:**
  1. Baca semua plan + `_shared.md`. Prasyarat: fitur `status: active` (plan sudah di-approve). Bila belum, hentikan & arahkan ke `feature`/`plan`.
  2. Iris jadi **milestone** (slice logis; mis. fondasi dulu, fitur turunan menyusul) lalu **task** di dalamnya. Granularitas: **satu task = unit testable terkecil**.
  3. **Enrich tiap task** sampai siap-implement: `files` (path dibuat/diubah/test — WHERE), `approach` (1–2 baris HOW ringkas), `test` (kasus yang harus lulus — WHAT). **JANGAN tulis kode implementasi** — itu jatah `build` (just-in-time, lawan kode terkini). Ini mengambil disiplin `writing-plans` (path & test eksplisit) tanpa monolit kode-nya (§7.1).
  4. Tentukan **urutan & dependency** dari: kontrak `_shared.md` (fondasi paling dulu), `fanout.md` Urutan (lintas-app, mis. `api` sebelum `web`), dan dependency logis intra-app.
  5. Rasionalisasi hierarki fitur (mis. "register by google" = flow OAuth yang sama dengan "login by google" → satu milestone OAuth per provider menutup keduanya).
  6. Untuk fitur besar/berisiko, boleh invoke `critic` atas peta task (urutan keliru? milestone kegedean? dependency kelewat?).
- **Output:** `control/features/<fitur>/tasks.yaml` (skema §6) — tiap task ber-`files`/`approach`/`test` cases, **tanpa kode implementasi**; semua `status: pending`. `breakdown` **tidak** memanggil `writing-plans` (§7.1).
- **Gate:** tampilkan **peta task** (milestone × app × task + dependency) → minta **approve/koreksi**. Di gate ini pengguna belum melihat kode — hanya menyetujui **rencana kerja**. Murah & cepat.

## 6. Skema `tasks.yaml`

```yaml
feature: auth
generated_from: [plans/_shared.md, plans/api.md, plans/web.md]
milestones:
  - id: M1
    title: Fondasi + email/password
    tasks:
      - id: T1
        app: api                            # cocok dengan apps[].name di workspace.yaml
        desc: User model + util hashing password
        files:                              # WHERE — path saja, BUKAN kode
          - create: src/models/user.ts
          - create: src/lib/hash.ts
          - test:   test/lib/hash.test.ts
        approach: bcrypt cost 12; email unik (index DB)
        test:                               # WHAT di-assert (kasus), bukan kode test
          - hash↔verify ok
          - email dup ditolak DB
        deps: []
        status: pending                     # pending | in_progress | done | blocked
      - id: T3
        app: api
        desc: POST /auth/register
        files:
          - create: src/routes/auth/register.ts
          - modify: src/routes/index.ts     # daftarin route
          - test:   test/auth/register.test.ts
        approach: hash(T1) → simpan User → mulai session(T2) → 201 + set-cookie
        test:
          - sukses → 201, cookie session terset
          - email kepake → 409
          - pw lemah → 422
        deps: [T1, T2]
        status: pending
      # ...T2 session, T4 login/logout, T5 LoginPage[web], T6 RegisterPage[web]...
  - id: M2
    title: Password lifecycle               # forgot / reset / change
    tasks: [ ... ]
  - id: M3
    title: OAuth Google                     # api callback + web button
    tasks: [ ... ]
  # M4 Facebook · M5 Apple
```

- **`files` + `approach` + `test` = WHAT + WHERE, bukan HOW.** Tidak ada kode implementasi di sini — kode ditulis `build` per task (just-in-time, lawan kode terkini). `test` = daftar **kasus** yang harus lulus, bukan kode test. Ini disiplin `writing-plans` (path & test eksplisit) tanpa monolit kode-nya (§7.1).
- **`status` adalah INTI, bukan metadata.** Ia yang membuat `build` resumable lintas-sesi (§8) dan menjadi sumber progres halus (§9). `build` meng-update `status` **atomik per task** (langsung tulis ke file begitu satu task selesai), bukan di-batch.
- **`deps`** mengacu `id` task lain → `build` mengeksekusi secara topologis.
- Format YAML (bukan markdown) dipilih karena task adalah daftar **stateful** — sejalan dengan `feature.yaml`/`workspace.yaml`, dan bisa dibaca skill lain (`build`, `render-docs`).

## 7. Skill `build`

- **Tujuan:** mengeksekusi `tasks.yaml` menjadi kode yang sudah lulus test, di bawah gate, lalu menyatakan fitur **siap di-`ship`**.
- **Input:** `control/features/<fitur>/tasks.yaml` + `plans/*` + `_shared.md` + `control/conventions.md` + `control/workspace.yaml` (`path`/`stack` per app) + **kode app**.
- **Prasyarat:** `tasks.yaml` ada. Bila belum, hentikan & arahkan jalankan `breakdown` dulu (sebaiknya sesi terpisah). `build` **tidak** auto-generate task diam-diam.
- **Perilaku:**
  1. Baca `tasks.yaml`. **Cek branch git** — kalau di `main`/`master`, minta konfirmasi/bikin branch fitur dulu (jangan mulai di main tanpa izin). Cari task `pending` pertama yang seluruh `deps`-nya `done`.
  2. **Dispatch implementer subagent.** `build` (controller) **menyusun & mem-paste teks task lengkap** ke prompt subagent (jangan suruh subagent baca `tasks.yaml` sendiri): `desc` + `files` + `approach` + kasus `test` + potongan `_shared.md` + konvensi + `stack` + pointer file pola. Pilih **model** sesuai kompleksitas task. Subagent menulis kode **TDD** (`test-driven-development`: test dari kasus `test:` dulu → kode sampai ijo), commit, self-review, lalu balik dengan **ringkasan + status** (DONE/DONE_WITH_CONCERNS/BLOCKED/NEEDS_CONTEXT). Pakai template `implementer-prompt.md` dari `subagent-driven-development`. Konteks berat (baca file/diff/test) tetap di subagent.
  3. **Review 2-tahap** (otomatis, antar-subagent, tanpa ganggu user): dispatch **spec-reviewer** (`spec-reviewer-prompt.md` — "verifikasi dengan baca kode, jangan percaya report") → bila lulus, **code-quality-reviewer** (`code-quality-reviewer-prompt.md` + template `requesting-code-review`). Reviewer nemu masalah → implementer (subagent sama) perbaiki → review ulang sampai lulus.
  4. Set `status`: `in_progress` saat mulai, `done` saat lulus **dua** review (atomik — tulis ke file). Bila buntu → `blocked`, **STOP**, laporkan (sandar `systematic-debugging`). **Jangan** tandai `done` palsu (anti-yes-man).
  5. **Gate — mode A adaptif** (lihat di bawah).
  6. Ulang sampai semua task `done` → laporkan "fitur `<nama>` siap di-`ship`" (serahkan ke `ship`; **jangan** jalankan `finishing-a-development-branch` — itu jatah `ship`).
- **Output:** kode terimplementasi di working tree tiap app + `tasks.yaml` dengan `status` ter-update. `build` **tidak** mengubah `feature.yaml` (status tetap `active`; lihat §9).
- **Gate (mode A adaptif):**
  - **Default — gate per app per milestone.** Setelah semua task satu app dalam satu milestone `done`, BERHENTI: tampilkan **diff app itu + hasil test + "yang dibangun vs task/plan" + challenge checklist**. Pengguna **approve** (lanjut) atau **minta revisi** (subagent perbaiki → balik gate).
  - **Lebih rapat** untuk app yang memegang kontrak `_shared.md` / ditandai berisiko (di milestone fondasi) → boleh checkpoint per-task.
  - **Lebih longgar** untuk milestone bermotif mapan (mis. OAuth provider ke-2 & ke-3) → boleh gabung gate.
  - **Fitur 1-app** → ciut jadi 1 gate. **Banyaknya gate bisa di-dial pengguna.**
  - Urutan eksekusi selalu hormati `deps` + Urutan `fanout` (mis. `api` sebelum `web` → `web` dibangun di atas kontrak `api` yang **sudah nyata**, bukan yang baru direncanakan).

### 7.1 Kenapa bukan `writing-plans` (dan kenapa tetap aman tanpanya)

`writing-plans` menghasilkan **satu plan monolitik** per fitur — semua task + **kode lengkap per langkah** dalam satu file. Untuk fitur besar (`auth` ≈ 14 task) ini:
- bikin **gate `breakdown` jadi raksasa** (review satu dokumen tebal — masalah C3 balik lagi);
- **meledakkan konteks** di awal `build` (`subagent-driven-development` mulai dengan membaca *seluruh* plan ke controller);
- **kode cepat basi** — detail T10 ditulis sebelum T1 dibangun, padahal context-vault ingin tiap task dibangun di atas kode TERKINI.

Maka kita **belah**: `breakdown` memutuskan **WHAT + WHERE** (kasus test + `files`, di-review murah di gate), `build` menulis **HOW** (kode) just-in-time lawan kode terkini. Pembelahan ini justru nilai-jual kita di atas `writing-plans` (yang menyatukan ketiganya jadi satu blok basi).

**Kenapa tetap jalan tanpa file `writing-plans`:** template `implementer-prompt.md` menyuruh controller **mem-paste teks task ke prompt** — *"\[FULL TEXT of task from plan - paste it here, don't make subagent read file]"*. Subagent **tidak pernah** membaca file plan; ia hanya butuh prompt yang lengkap. Maka **sumber teks task** boleh dari mana saja — bagi kita dari `tasks.yaml` enriched. Semua yang template sebut "from the plan" (teks task, struktur file) ke-cover `tasks.yaml`; konsistensi dijaga spec-reviewer + code-quality-reviewer + `conventions.md`. `build` memakai **mesin subagent yang sama**, hanya beda sumber task.

## 8. Manajemen Konteks & Sesi

`build` adalah fase **paling berat** (baca kode + tulis kode + output test × banyak task). Tiga lapis kendali:

1. **Antar-fase (gratis).** `feature` / `breakdown` / `build` / `ship` boleh masing-masing sesi sendiri, karena handoff lewat file `control/`. (Sub-skill `intake`/`fanout`/`plan` pun sudah bisa dipanggil terpisah.)
2. **`build` antar-sesi (resumable).** `build` commit `status` tiap task selesai (atomik). Konteks membengkak? Stop. Sesi baru `/build <fitur>` membaca `tasks.yaml`, melewati yang `done`, lanjut dari task `pending` berikutnya — konteks fresh.
3. **`build` intra-sesi (subagent).** Tiap task di-dispatch ke subagent ber-konteks sendiri; sesi utama `build` hanya menampung **ringkasan + status**, sehingga tetap ramping walau task banyak.

Konsekuensi: fase ringan (`breakdown`, `intake`, `fanout`) nyaman sebagai sesi pendek; `build` aman dicicil sebesar apa pun fiturnya.

## 9. Status Fitur

Tidak menambah status baru. `feature.yaml.status` tetap **kasar (4)**: `draft → active → shipped/dropped` (spec induk §12). Sepanjang `breakdown`/`build`, status tetap **`active`**; **progres halus dibaca dari `tasks.yaml`** (mis. `8/14 done`). Alasan: konsisten dengan prinsip induk "status sengaja kasar", dan `tasks.yaml` sudah jadi sumber progres yang lebih presisi daripada flag manual.

## 10. Anti-Yes-Man & `critic`

- `breakdown` gate: challenge atas peta task; `critic` opsional untuk fitur besar.
- `build` gate: **challenge checklist wajib** (konsistensi konvensi? risiko? cara lebih sederhana?) + larangan menandai task `done` saat test merah (`blocked`, bukan rubber-stamp).
- `ship` (tak berubah) tetap puncak alignment dengan `critic` (kode jadi vs `business.md`).

## 11. Multi-repo & Git

- `build` beroperasi per app pada `path`-nya dari `workspace.yaml` (sama seperti `ship`). Kolom `app` di tiap task menentukan lokasi.
- Eksekusi **sekuensial** sesuai `deps` (tidak ada dua subagent menulis tree yang sama serempak) → aman untuk monorepo & multi-repo tanpa worktree. Worktree/paralel = future (spec induk §16).
- **Commit per task** (frequent commits ala TDD; sekalian jejak resume/diff) dilakukan implementer subagent. TAPI `build` **cek branch dulu — tidak memulai di `main`/`master` tanpa izin** (minta bikin branch fitur). **PR & merge tetap jatah `ship`**; git selebihnya tetap ranah pengguna (konsisten `ship`/`drop`).

## 12. Dampak ke Komponen Existing

- **`feature/SKILL.md`** langkah 4: ganti saran "implementasi (pakai pola executing-plans/subagent), lalu ship" → arahkan ke **`breakdown` lalu `build`** (sebaiknya sesi terpisah), baru `ship`.
- **`ship/SKILL.md`**: prasyarat tetap `status: active`; tambahkan catatan bahwa implementasi diharapkan lewat `build` (boleh manual juga). Tidak ada perubahan logika inti.
- **`plan/SKILL.md`**: **tidak berubah** (tetap flat) — tambahkan satu baris catatan bahwa dekomposisi task = jatah `breakdown`.
- **`README.md`** & spec induk §12: tambahkan `breakdown → build` ke diagram lifecycle.
- **`render-docs`** (opsional, future): boleh menampilkan progres `tasks.yaml` (`x/y done`) — bukan bagian wajib spec ini.
- **`plugin/.claude-plugin/plugin.json`** deskripsi & §17 spec induk: jumlah skill bertambah 2 (`breakdown`, `build`).

## 13. Scope v1 (Fase Eksekusi) & Future

- **v1 (in):** skill `breakdown` (+ `tasks.yaml`), skill `build` (mode A adaptif, TDD via subagent, resumable, atomic status), integrasi gate + anti-yes-man, update dok lifecycle.
- **Future:** eksekusi paralel lintas-app via worktree; `render-docs` menampilkan progres task; auto-detect "build selesai" untuk nyaris-mulus ke `ship`; status `in-review` (warisan future spec induk).

## 14. Open Questions (untuk tahap perencanaan)

- Apakah `build` boleh menawarkan menjalankan `breakdown` inline bila `tasks.yaml` belum ada (kenyamanan) vs selalu menyuruh sesi terpisah (kebersihan konteks)? Default spec ini: **suruh `breakdown` dulu**, tapi boleh ditinjau.
- Apakah challenge checklist `build` ditaruh di SKILL atau diwariskan dari `anti-yes-man.md` yang sudah di CLAUDE.md.
- Apakah `build` menyalin template prompt `subagent-driven-development` apa adanya, atau menulis varian sendiri yang sadar-`tasks.yaml` — diputuskan saat implementasi.
