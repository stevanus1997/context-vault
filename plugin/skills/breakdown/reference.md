# breakdown — Reference (skema `tasks.yaml` + aturan)

Dibaca oleh skill `breakdown`. SKILL.md tetap ramping; detail skema & aturan ada di sini.

## A. Skema `tasks.yaml`

```yaml
feature: <nama-fitur>
generated_from: [plans/_shared.md, plans/<app>.md, ...]
milestones:
  - id: M1
    title: <judul milestone>
    tasks:
      - id: T1
        unit: <nama app/pkg>        # cocok dengan apps[].name ATAU packages[].name; atau "integration"
        desc: <satu baris — apa yang dibangun>
        files:                     # WHERE — path saja, BUKAN kode
          - create: <path relatif unit>
          - modify: <path relatif unit>   # boleh + komentar singkat
          - test:   <path test relatif unit>
        approach: <1-2 baris HOW ringkas; boleh rujuk task lain, mis. "pakai util T1">
        actions:                   # OPSIONAL — kerja non-file; build yang EKSEKUSI + VERIFIKASI
          - install: <pkg>         #   build: `npm install <pkg>` (auto), verifikasi masuk package.json
          - cmd: <perintah>        #   perintah lain non-destruktif (auto), mis. "npx prisma generate"
          - migrate: <deskripsi>   #   DESTRUKTIF → build TAMPILKAN + GATE sebelum apply (jangan auto)
          - env: [VAR1, VAR2]      #   build tulis var ke .env (nilai dari manual:/prompt user)
        manual:                    # OPSIONAL — langkah yang AI NGGAK BISA (butuh manusia)
          - <mis. "bikin OAuth app di Google Console, dapetin client id + secret">
        test:                      # WHAT di-assert (kasus), BUKAN kode test
          - <kasus 1>              #   boleh kriteria non-unit: "typecheck hijau", "migration apply bersih"
          - <kasus 2>
        deps: []                   # id task lain yang harus done dulu
        status: pending            # pending | in_progress | done | blocked | needs_human
      # Task integrasi cross-app (lihat §D-3 & spec S2): menjalankan >1 app bareng
      - id: T_INT
        unit: integration           # pseudo-unit — gate-nya membentang beberapa tree, tak punya path sendiri
        desc: <uji end-to-end flow lintas-app, mis. register via web → user di DB api>
        approach: boot app terkait (path/stack dari workspace.yaml) lalu jalankan flow nyata
        test:
          - <roundtrip nyata; shape data cocok di dua sisi kontrak _shared.md>
        deps: [<id sisi A>, <id sisi B>]   # KEDUA sisi kontrak
        status: pending
```

## B. Aturan granularitas & enrich

- **Satu task = unit testable terkecil.** Kalau satu task butuh > ~3 file inti atau test case-nya > 5, itu sinyal harus dipecah.
- **`files` = path saja.** Tidak ada potongan kode implementasi di `tasks.yaml`. Kode ditulis `build` per task (just-in-time, lawan kode terkini).
- **`test` = daftar kasus** yang harus lulus (mis. "dup-email 409"), bukan kode test. Kode test ditulis implementer subagent saat `build` (TDD).
- **`approach` ringkas** (1-2 baris). Boleh menyebut dependency antar-task ("session dari T2").
- **`deps`** topologis: fondasi (`_shared.md`) paling dulu; lintas-app ikut Urutan `fanout.md` (mis. `api` sebelum `web`); intra-app sesuai logika.
- **Rasionalisasi hierarki:** varian yang flow-nya identik digabung (mis. "register by google" = "login by google" → satu milestone OAuth/provider).
- **JANGAN panggil `writing-plans`** — `breakdown` sengaja TIDAK menghasilkan plan monolitik berisi kode (lihat spec §7.1).
- **`actions:` untuk kerja non-file.** Migrasi DB, `npm install`, wiring env/secret, perintah infra TIDAK boleh terkubur di `approach` — taruh di `actions:` biar `build` eksekusi & verifikasi eksplisit. `install`/`cmd` auto; `migrate` (destruktif) lewat GATE; `env` ditulis `build` (nilai dari `manual:`/user).
- **`manual:` untuk langkah AI-nggak-bisa.** Bikin OAuth app, set secret produksi, provision DB → daftar di `manual:`; `build` pause (`needs_human`) & lapor checklist.
- **`test:` boleh non-unit.** Untuk task non-unit-testable (config, scaffold, shared types), `test:` boleh berisi kriteria seperti "typecheck hijau"/"build sukses"/"file ada & ke-import"; size-nya "satu artifact koheren".

## C. Contoh (fitur `auth`, 2 app — api + web)

```yaml
feature: auth
generated_from: [plans/_shared.md, plans/api.md, plans/web.md]
milestones:
  - id: M1
    title: Fondasi + email/password
    tasks:
      - id: T1
        unit: api
        desc: User model + util hashing password
        files:
          - create: src/models/user.ts
          - create: src/lib/hash.ts
          - test:   test/lib/hash.test.ts
        approach: bcrypt cost 12; email unik (index DB)
        test:
          - hash lalu verify cocok
          - email dup ditolak DB
        deps: []
        status: pending
      - id: T2
        unit: api
        desc: Session (issue + verify) per _shared.md
        files:
          - create: src/lib/session.ts
          - test:   test/lib/session.test.ts
        approach: cookie httpOnly JWT HS256 TTL 7d; issuer & validator = api
        test:
          - issue lalu verify roundtrip
          - token kedaluwarsa ditolak
        deps: [T1]
        status: pending
      - id: T3
        unit: api
        desc: POST /auth/register
        files:
          - create: src/routes/auth/register.ts
          - modify: src/routes/index.ts
          - test:   test/auth/register.test.ts
        approach: hash(T1) lalu simpan User lalu session(T2) lalu 201 + set-cookie
        test:
          - sukses 201 + cookie session terset
          - email kepake 409
          - password lemah 422
        deps: [T1, T2]
        status: pending
      - id: T4
        unit: api
        desc: POST /auth/login + POST /auth/logout
        files:
          - create: src/routes/auth/login.ts
          - modify: src/routes/index.ts
          - test:   test/auth/login.test.ts
        approach: verify pw lalu session(T2); logout hapus cookie
        test:
          - login benar 200 + cookie
          - pw salah 401
          - logout hapus cookie
        deps: [T1, T2]
        status: pending
      - id: T5
        unit: web
        desc: LoginPage (email+pw) wired ke /auth/login
        files:
          - create: src/app/(auth)/login/page.tsx
          - test:   test/auth/login-page.test.tsx
        approach: form email+pw; submit ke /auth/login; tampilkan error
        test:
          - validasi form kosong
          - error 401 ditampilkan
        deps: [T4]
        status: pending
      - id: T6
        unit: web
        desc: RegisterPage wired ke /auth/register
        files:
          - create: src/app/(auth)/register/page.tsx
          - test:   test/auth/register-page.test.tsx
        approach: form daftar; submit ke /auth/register; redirect on success
        test:
          - validasi form
          - email kepake 409 ditampilkan
        deps: [T3]
        status: pending
      - id: T_PKG
        unit: money                  # shared package (packages[].name) — bukan app
        desc: util formatMoney + parseMoney (dipakai web + api)
        files:
          - create: src/index.ts
          - test:   test/money.test.ts
        approach: format minor-unit ke string lokal; tanpa DB/route
        test:
          - format 100050 -> "Rp 1.000,50"
          - typecheck hijau
        deps: []
        status: pending
  - id: M2
    title: Password lifecycle (forgot / reset / change)
    tasks: []   # T7-T12 — diisi breakdown saat dijalankan
  - id: M3
    title: OAuth Google (login+register, 1 flow)
    tasks: []   # T13 api callback, T14 web button
  # M4 Facebook, M5 Apple — pola sama
```

## D. Kerja non-file, langkah manual, & task integrasi

1. **`actions` (kerja AI bisa, non-file).** Jenis: `install` (auto), `cmd` (auto), `migrate` (GATE — destruktif), `env` (build tulis ke `.env`). `build` mengeksekusi + memverifikasi tiap action sebagai bagian dari `done`.
2. **`manual` + status `needs_human` (kerja manusia).** Task ber-`manual:` yang belum beres → `build` set `status: needs_human`, **STOP SELURUH build**, lapor checklist; lanjut setelah user beresin. `needs_human` ≠ `blocked` (blocked = ada error/bug; needs_human = bener, nunggu manusia).
3. **Task integrasi (`unit: integration`).** Untuk tiap dependency lintas-app di `_shared.md`/`fanout.md`, munculkan SATU task integrasi: `deps` ke KEDUA sisi kontrak, `test` = roundtrip end-to-end nyata. Pseudo-unit `integration` tak punya `path`/repo sendiri (jalan di atas repo unit di `deps`-nya). Fitur 1-app tanpa `_shared.md` → tidak perlu.
4. **Task package & fan-IN.** Task yang hidup di shared package → `unit: <nama-pkg>` (cocok `packages[].name`); **DILARANG** `actions: [migrate]`/`actions: [env]` (package tak punya DB/infra); `test` = typecheck/unit exports. **Fan-IN (saat `plans/<pkg>.md` ber-flag `BREAKING`):** terbitkan 1 task `unit: <pkg>` (ubah package) + **1 update-task per consumer** (`unit: <consumer-app>`, `deps: [task-pkg]`) untuk tiap nama di `packages[<pkg>].consumers` + 1 task `unit: integration` (roundtrip package↔consumer). Pseudo-unit `integration` diperluas mencakup roundtrip package↔consumer (boot consumer app, panggil exports package, assert sesuai kontrak `plans/<pkg>.md`).
5. **Task inbound-eksternal (webhook vendor).** Saat `plans/<Receiver app>.md` memuat baris "kebutuhan receiver" (dari `plan` §2c — vendor inbound/both di `integrations.md`), terbitkan task biasa `unit: <Receiver app>` (app NYATA — BUKAN pseudo-unit `integration`): `approach` = "terima webhook `<vendor>`: verifikasi signature per `integrations.md`, idempotent (dedup key), tahan replay"; `actions` boleh `env: [<VENDOR>_WEBHOOK_SECRET]` (NAMA var; `build` tulis ke `.env`, nilai GATE/manual); `test` (kasus keamanan baku) = "signature salah → tolak 401/403", "id/event duplikat → respons sama, tak proses 2× (idempotent/replay)". Vendor **outbound** = task biasa pada app pemanggil (panggil API vendor + idempotency-key + retry sesuai `integrations.md`) — tak butuh varian khusus.
