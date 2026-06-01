# wire — Reference (bring-up fondasi)

Dibaca oleh skill `wire`. SKILL.md tetap ramping; detail di sini.

## A. Batas `architect` (WHAT) vs `wire` (HOW)

| Dimensi | architect (keputusan/knowledge) | wire (instansiasi/operasional) |
|---|---|---|
| Framework | "Next.js" / "SolidStart" / "Django" | jalankan scaffolder resminya |
| Engine/service DB | "Postgres" / "ClickHouse" / "Supabase" | Docker lokal / managed-connect / remote URL |
| ORM/data | "Prisma" / "Drizzle" / "raw" | init + migrasi baseline + smoke query |
| Kontrak lintas-app | auth / format API / shared (conventions.md) | eksekusi: CORS, base URL, client, env shape |
| Hosting/runtime | — (bukan arsitektur) | Q&A wire: Docker?, port, package manager |

- **architect SEBUT engine/service; wire TENTUKAN cara instansiasi + nyambungnya.** "Docker-or-not" bukan keputusan arsitektur → jatuh ke Q&A wire (langkah 0.5).
- **Managed service** (Supabase/Neon/PlanetScale): identitas service = architect (ngiket ke auth/storage/realtime mereka); koneksi (project/key/region) = wire.
- Field **LOGICAL** hilang (mis. orm belum diputusin) → wire STOP, balikin ke architect. Hal **operasional** (Docker dll) → SELALU wire.

## B. Prosedur generik (TANPA daftar resep)

wire TIDAK punya registry resep per stack. Yang universal = **urutan CONCERN** (scaffold → DB up → BE↔DB → FE↔BE → env → smoke); command spesifik diturunkan agent dari `stack` saat runtime (pola sama `actions` di `build`).

- **Delegasi scaffolder resmi:** panggil tool resmi (`create-next-app`, `npm create vite`, `nest new`, `npx degit solidjs/templates/...`, `django-admin startproject`, `go mod init`, dll). Tulis hanya **GLUE** (env, base URL, CORS, client). Jangan reimplementasi internal framework — itu yang seluruh proyek ini definisikan sebagai BUKAN tugasnya.
- **Caveat jujur (anti-yes-man):** "generic" = **prosedurnya** universal, BUKAN jaminan command benar tiap stack. Mainstream → agent tahu command resminya persis. Langka → agent ajukan **tebakan terbaik + GATE konfirmasi** (atau lookup dulu). JANGAN diam-diam salah — paling banter nanya ke user.

## C. Database: managed vs bare-engine

Ditentukan hasil Q&A 0.5, bukan hardcode:

- **Bare-engine** (Postgres / MariaDB·MySQL / ClickHouse / Mongo / …): default **Docker lokal** — generate `docker-compose.yml` + connection string (nyaris 100% otomatis, tanpa creds cloud). Alternatif: **URL remote** dari user.
- **Managed** (Supabase / Neon / PlanetScale / …): **connect** pakai creds yang user masukin (**GATE/manual** — out-of-band). Provisioning project di luar scope wire.
- Connection string → `.env` (gated bila secret). Migrasi baseline + smoke query (§E) buktikan DB hidup & nyambung sebelum gate ditutup.

## D. Env contract & secret

- **Shape** (nama var + arti, TANPA nilai) per app type → rekam di `conventions.md` (committed). Mis. BE: `DB_URL`, `JWT_SECRET`, `PORT`, `CORS_ORIGINS`; FE: `API_BASE_URL`, public keys.
- **Nilai** → `.env` app (gitignored); secret diisi via **GATE/manual** (pola `manual:`/`needs_human` + action `env` build). Secret JANGAN masuk `control/` atau git.
- Pastikan `.env` ada di `.gitignore` app (tambah bila belum).

## E. Smoke test — definisi "wired"

Gate penutup punya acceptance bar konkret:

1. **BE boot** — proses start; health endpoint (bila ada) merespons.
2. **DB reachable** — ORM connect, migrasi baseline ter-apply, smoke query ijo.
3. **FE→BE** — FE boot & berhasil panggil BE (health/ping). Fullstack (Next): app boot & route internal ke API sendiri jalan.

Semua ijo → tandai "siap di-`feature`". Ada merah → **STOP**, lapor akar masalah (sandar `systematic-debugging`), JANGAN tandai siap (anti-yes-man). Ini menutup dead-end loop `plan` (yang dulu cuma balik ke architect). App **non-Node** (Go/Python): ada server → HTTP ping; selain itu tanya definisi "boot ok" di Q&A.

## F. Brownfield & idempotency

- Deteksi state per app: belum ter-scaffold → scaffold penuh; ter-scaffold belum ter-wire → isi **HANYA** yang kurang; sudah ter-wire → **no-op**, lapor.
- **Idempotent:** re-run di app yang sudah jalan tidak merusak — deteksi yang ada, tambal celah. Jangan timpa kode / `.env` / migrasi existing.
- `wire(repair)` = pasangan operasional dari architect **CAPTURE** (existing).

## G. Multi-repo & git

- Kelompokkan app per **repo unik** via `git -C <path> rev-parse --show-toplevel` (monorepo/nested otomatis ciut) — sama seperti `build`/`ship`.
- FE↔BE lintas-repo lewat **env/URL** (API base URL), bukan import langsung.
- Eksekusi **sekuensial** per repo (no dua proses nulis tree sama serempak) → aman monorepo & multi-repo tanpa worktree.
- Commit skeleton boleh, TAPI **cek branch dulu — jangan mulai di `main`/`master` tanpa izin**. PR & merge = jatah pengguna/`ship`.

## H. Pinjam mesin `build`

wire meminjam mesin side-effect `build` (spec breakdown-build §7.1), bukan bikin dari nol:

- Actions `install` / `cmd` / `migrate` / `env` — bentuk eksekusi sama.
- Aturan **"`migrate` JANGAN auto + approve"**.
- Penulisan `.env` dari nilai `manual:`/prompt.
- Probe multi-repo `git -C <path> rev-parse --show-toplevel` + branching per-repo.
- Pola STOP `manual:`/`needs_human` untuk langkah tangan-manusia (creds managed).

**Beda dengan build:** wire = **SEKALI, fondasi** (skeleton kosong-tapi-jalan); build = **PER FITUR** (kode fitur ke skeleton). wire bikin **pipeline migrasi BERFUNGSI + baseline** (kosong table fitur); build bikin **TABLE fitur**. Dua-duanya gate `migrate`.

## I. Mode-package (unit `type: package`)

Shared package = kode bareng tanpa runtime sendiri → bring-up dipangkas. Dipanggil `add-package`.

- **Yang DIKERJAKAN:** scaffold skeleton library via tool resmi stack (mis. `tsup`/`tsc --init`, atau minimal `package.json` + `tsconfig` + `src/index`) + **register di workspace** (pnpm-workspace.yaml / turbo / `tsconfig` paths) sesuai topology.
- **Gate penutup = typecheck/lint hijau** (ganti smoke test runtime). Definisi "siap": package ke-build/typecheck tanpa error & ter-resolve dari workspace.
- **Yang DI-SKIP:** spin DB, ORM/migrasi, wiring FE↔BE, smoke HTTP. Package tak punya `db`/route.
- **Invarian:** package = CONSUMER invarian, bukan pengunci — prasyarat invarian (langkah 0) tetap berlaku sebagai backstop, tapi `wire` tak mengunci apa pun.
- **Multi-repo:** sama seperti app — `git -C <packages[pkg].path> rev-parse --show-toplevel`, branch per repo unik (§G).
