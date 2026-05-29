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
        app: <nama app>            # cocok dengan apps[].name di workspace.yaml
        desc: <satu baris — apa yang dibangun>
        files:                     # WHERE — path saja, BUKAN kode
          - create: <path relatif app>
          - modify: <path relatif app>   # boleh + komentar singkat
          - test:   <path test relatif app>
        approach: <1-2 baris HOW ringkas; boleh rujuk task lain, mis. "pakai util T1">
        test:                      # WHAT di-assert (kasus), BUKAN kode test
          - <kasus 1>
          - <kasus 2>
        deps: []                   # id task lain yang harus done dulu
        status: pending            # pending | in_progress | done | blocked
```

## B. Aturan granularitas & enrich

- **Satu task = unit testable terkecil.** Kalau satu task butuh > ~3 file inti atau test case-nya > 5, itu sinyal harus dipecah.
- **`files` = path saja.** Tidak ada potongan kode implementasi di `tasks.yaml`. Kode ditulis `build` per task (just-in-time, lawan kode terkini).
- **`test` = daftar kasus** yang harus lulus (mis. "dup-email 409"), bukan kode test. Kode test ditulis implementer subagent saat `build` (TDD).
- **`approach` ringkas** (1-2 baris). Boleh menyebut dependency antar-task ("session dari T2").
- **`deps`** topologis: fondasi (`_shared.md`) paling dulu; lintas-app ikut Urutan `fanout.md` (mis. `api` sebelum `web`); intra-app sesuai logika.
- **Rasionalisasi hierarki:** varian yang flow-nya identik digabung (mis. "register by google" = "login by google" → satu milestone OAuth/provider).
- **JANGAN panggil `writing-plans`** — `breakdown` sengaja TIDAK menghasilkan plan monolitik berisi kode (lihat spec §7.1).

## C. Contoh (fitur `auth`, 2 app: api + web)

```yaml
feature: auth
generated_from: [plans/_shared.md, plans/api.md, plans/web.md]
milestones:
  - id: M1
    title: Fondasi + email/password
    tasks:
      - id: T1
        app: api
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
        app: api
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
        app: api
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
        app: api
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
        app: web
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
        app: web
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
  - id: M2
    title: Password lifecycle (forgot / reset / change)
    tasks: []   # T7-T12 — diisi breakdown saat dijalankan
  - id: M3
    title: OAuth Google (login+register, 1 flow)
    tasks: []   # T13 api callback, T14 web button
  # M4 Facebook, M5 Apple — pola sama
```
