# context-vault — Fase Bring-Up: `wire` (Design Spec)

- **Tanggal:** 2026-05-31
- **Status:** Draft disetujui untuk masuk tahap perencanaan implementasi
- **Terkait:** spec induk `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (mewujudkan "(+ scaffold dasar)" §9/line 151 yang tak pernah dijabarkan, dan mengambil potongan **bring-up** dari "orchestrator" future §16/line 263); spec `2026-05-29-breakdown-build-execution-phase-design.md` (`wire` meminjam mesin side-effect `build`)

---

## 1. Ringkasan

Pipeline sekarang: `discovery → init → architect → feature → breakdown → build → ship`. Seluruh layer `control/` adalah **pengetahuan/AI murni** (markdown + `workspace.yaml`) — sengaja **"bukan berisi kode aplikasi"** (spec induk line 11). `architect` menetapkan **keputusan** teknis (`stack` per app + `conventions.md`) tapi by-design **menolak menghasilkan kode** ("`architect` = KNOWLEDGE fondasi, BUKAN generator kode" — `architect/SKILL.md` line 43). Akibatnya, antara `architect` dan `feature` ada **void**: bikin project beneran, bikin/nyalain DB, nyambung FE↔BE, set env standar, konek BE↔DB — semua **manual**.

Spec ini mengisi void itu dengan **satu skill baru, `wire`** (nama kerja), yang duduk di antara `architect` dan `feature`:

- **`wire`** — **pelaksana operasional** yang mengubah keputusan `architect` jadi **skeleton kosong-tapi-jalan**: app ter-scaffold lewat tool resmi, DB nyala & nyambung, FE↔BE ter-wire, env standar terpasang. Semua **di-GATE** dan **kosong dari kode fitur**. Setelahnya `feature`/`build` tinggal "bikin table + panggil API".

Pembagian peran inti: **`architect` = WHAT (keputusan logical), `wire` = HOW TO RUN (instansiasi operasional).** `wire` **generic** — ia mengeksekusi *apa pun* yang `architect` putuskan (Next.js / SolidStart / Go / ClickHouse / Supabase / …), bukan daftar stack yang dikurasi.

Lifecycle menjadi: `… → architect → wire → feature → breakdown → build → ship`.

## 2. Masalah

- **C1 — Void bring-up.** Lima kerja manual pengguna — (a) bikin project, (b) bikin/nyalain DB, (c) sambung FE↔BE, (d) set env standar, (e) konek BE↔DB — jatuh di celah antara gate `architect` dan asumsi `plan`/`build` bahwa "kode app sudah jalan & nyambung". Tidak ada satu skill pun yang mengisinya.
- **C2 — Dead-end loop di `plan`.** `plan/SKILL.md` line 40: *"Bila app belum punya fondasi, hentikan & arahkan user menjalankan `architect` dulu."* Tapi `architect` cuma mengeluarkan **gate** lagi (line 24: *"GATE: user yang jalanin"*), tak pernah membangun wiring. Pengguna muter: plan → "balik ke architect" → architect → "lo jalanin sendiri" → manual. Pain manual itu jadi **struktural**.
- **C3 — Hilir mengasumsikan skeleton sudah hidup.** `plan` membaca kode hidup app (line 23); `build` menulis kode fitur ke app yang **diasumsikan sudah ter-scaffold, ter-wire, bootable**; `ship` mem-boot app untuk integration test. Tak ada yang membangun fondasinya.

Akar: fase bring-up tidak punya pelaksana. `architect` sengaja berhenti di keputusan (menjaga layer `control/` tetap bersih dari kode), dan spec induk menaruh eksekusi otomatis sebagai future (line 263) — benar untuk v1, kini jadi friksi utama.

## 3. Tujuan & Non-Tujuan

**Tujuan:**
- Menutup void `architect → feature` dengan satu skill `wire` yang menghasilkan **skeleton kosong-tapi-jalan** (FE↔BE↔DB ter-wire, env terpasang).
- **Generic by design** — `wire` mengeksekusi apa pun `stack` yang `architect` putuskan; **tidak** ada daftar stack tetap. Command spesifik-stack diisi agent **saat runtime** (pola yang sama dengan `actions` di `build`), bukan di-hardcode.
- **Eksekusi beneran, di bawah GATE** — `wire` benar-benar menjalankan scaffolder/Docker/migrate/tulis `.env`, tapi tiap aksi destruktif/ireversibel **STOP minta approve** (disiplin gate yang sama dengan `build`).
- **Greenfield + brownfield** — scaffold app baru *dan* melengkapi/memperbaiki app existing yang setengah-jadi secara **idempotent** (tidak menimpa yang sudah ada).
- **Hormati batas `architect`** — `wire` tidak menulis kode framework sendiri; ia **mendelegasikan ke scaffolder resmi** dan hanya menulis **glue** (env, API base URL, CORS, client setup). Bedanya dengan `architect`: `wire` yang **MENJALANKAN** (gated), bukan menyuruh pengguna.
- Menutup dead-end loop `plan` line 40 dengan **smoke test** akhir: skeleton boot + DB kebaca + FE→BE nyampe → `plan`/`feature` boleh percaya fondasinya.

**REVISI terhadap spec induk:** spec induk §9 (line 151) menyebut `architect` "(+ scaffold dasar)" tanpa pernah menjabarkannya, dan §16 (line 263) menaruh "eksekusi/implementasi otomatis lintas-app (orchestrator)" sebagai future. Spec ini **mewujudkan** "scaffold dasar" itu sebagai skill tersendiri dan **mengambil potongan _bring-up_** dari orchestrator future — **terbatas pada fondasi** (scaffold + DB + wiring + env), **bukan** eksekusi kode fitur (itu domain `build`).

**Non-Tujuan:**
- `wire` **bukan** generator kode framework — ia orchestrator scaffolder resmi + penulis glue. Menulis kode framework sendiri = melanggar batas yang seluruh proyek ini definisikan.
- `wire` **tidak** bikin table/skema fitur. Ia menyiapkan **pipeline migrasi yang berfungsi** + migrasi **baseline** (kosong dari table fitur). Table fitur = jatah `build` ("tinggal bikin table").
- `wire` **tidak** memilih/mengubah keputusan arsitektur. Engine/service DB, framework, ORM = jatah `architect`. Bila keputusan **logical** itu hilang, `wire` konfirmasi/balikin ke `architect` — ia tidak diam-diam memutuskannya.
- **Deploy/provisioning produksi** (CI, cloud infra, domain) di luar scope — `wire` fokus skeleton **dev** yang jalan lokal. (Cloud DB managed boleh disambung, tapi provisioning-nya di luar `wire`.)
- **Paralelisasi lintas-app** (worktree serempak) — default `wire` sekuensial per repo. Paralel = future.

## 4. Lifecycle Baru

```
Greenfield: init → architect(setup)   →                wire        → /feature → breakdown → build → ship
Brownfield: init → architect(capture) → extract(opsi) → wire(repair) → /feature → breakdown → build → ship

wire <produk|app>:
   0.   Baca stack LOGICAL dari architect + deteksi mode per app (greenfield/brownfield)
   0.5  Q&A OPERASIONAL (nutup architect): DB Docker/managed/remote? package manager? nilai env/secret?
   1.   Scaffold app via tool RESMI framework-nya            →(GATE per aksi)
   2.   Nyalain DB sesuai hasil 0.5 (Docker spin / connect)  →(GATE: creds/destruktif)
   3.   Konek BE↔DB: init ORM, migrasi baseline, smoke query →(GATE: migrate jangan auto)
   4.   Wire FE↔BE: API base URL / CORS / client (ikut conventions.md)
   5.   Tulis .env app (gitignored); rekam SHAPE-nya di conventions.md
   6.   Smoke test: boot + DB kebaca + FE→BE → tutup gate, "siap /feature"
```

`wire` **dipanggil eksplisit** (tidak di-auto-chain), **sekali jalan** seperti `extract`, dan **bisa di-rerun** saat nambah app/package (seperti `architect`). Untuk brownfield ia bersifat **repair** (opsional — hanya bila wiring belum lengkap).

## 5. Batas `architect` (WHAT) vs `wire` (HOW)

Ini sumbu konseptual spec. Pemisahannya bersih:

| Dimensi | `architect` (WHAT — keputusan/knowledge) | `wire` (HOW — instansiasi/operasional) |
|---|---|---|
| Framework | "Next.js" / "SolidStart" / "Django" | jalankan scaffolder resminya |
| Engine/service DB | "Postgres" / "ClickHouse" / **"Supabase"** | bring-up: Docker lokal / managed-connect / remote URL |
| ORM/data layer | "Prisma" / "Drizzle" / "raw" | init + migrasi baseline + smoke query |
| Kontrak lintas-app | auth, format API, shared package (`conventions.md`) | eksekusi kontrak itu (CORS, base URL, client, env shape) |
| Hosting/runtime | **—** (bukan urusan arsitektur) | **Q&A `wire`**: Docker apa nggak, port, package manager |

- **`architect` menyebut engine/service; `wire` menentukan cara instansiasi + nyambungnya.** "Docker-or-not" **bukan** keputusan arsitektur → ia jatuh ke **Q&A operasional `wire`** (langkah 0.5) yang "menutup kerja `architect`".
- **Nuansa managed service:** memilih **Supabase/Neon/PlanetScale** di `architect` *sebagian* keputusan arsitektur (mengikat ke auth/storage/realtime mereka), tapi *cara nyambungnya* (project mana, key apa, region) tetap Q&A `wire`. Aturan: **identitas service = `architect`; koneksi/instansiasi = `wire`.**
- **Konsekuensi:** `architect` **kemungkinan besar tidak diubah** — `wire` membaca `stack` logical lalu Q&A-nya menutup sisa operasional. Bila yang hilang adalah keputusan **logical** (mis. ORM belum diputuskan), `wire` konfirmasi/balikin ke `architect`; tapi hal operasional (Docker dll) **selalu** `wire`. (Lihat §15 untuk satu penyesuaian doc kecil di `architect` line 24.)

## 6. Skill `wire` — Prosedur

- **Tujuan:** menjadikan keputusan `architect` sebagai skeleton kosong-tapi-jalan, di bawah gate, lalu menyatakan app **"siap di-`feature`"**.
- **Input:** `control/workspace.yaml` (`apps[]`: `path`/`type`/`stack`/topology) + `control/conventions.md` (kontrak lintas-app) + **state kode** tiap app di `path`-nya.
- **Prasyarat:** `architect` sudah menetapkan `stack` logical per app (minimal framework + db + orm). Bila belum, hentikan & arahkan ke `architect` dulu.
- **Perilaku (per app, urut, tiap aksi destruktif = GATE). Penomoran cocok dengan diagram §4:**
  - **(0) Baca + deteksi mode.** Baca `stack` tiap app. Cek kode di `path`: **kosong → greenfield (scaffold penuh)**; **ada kode → brownfield (repair: hanya lengkapi yang kurang, idempotent, jangan timpa).**
  - **(0.5) Q&A operasional ("nutup `architect`").** Lihat §7.
  - **(1) Scaffold app.** Jalankan **tool resmi** framework-nya (apa pun: `create-next-app`, `npm create vite`, `nest new`, `npx degit solidjs/templates/...`, `django-admin startproject`, `go mod init`). `wire` **tidak** menulis kode framework sendiri — sama prinsip `architect`, bedanya `wire` **yang menjalankan** (GATE sebelum eksekusi). Brownfield: lewati bila app sudah ter-scaffold.
  - **(2) Nyalain DB** sesuai hasil 0.5: bare-engine → spin Docker lokal (generate `docker-compose.yml`) atau pakai URL remote; managed → connect pakai creds (**GATE**: pengguna masukin key). Lihat §9.
  - **(3) Konek BE↔DB.** Init ORM/driver sesuai `stack.orm`, generate **migrasi baseline** (kosong dari table fitur), **apply** (**GATE — migrate JANGAN auto**, pinjam aturan `build`), jalankan **smoke query** untuk membuktikan koneksi.
  - **(4) Wire FE↔BE** sesuai topologi: fullstack (mis. Next) → cukup env + internal call; FE/BE kepisah → set **API base URL** + **CORS** + (bila relevan) **typed client**. Ikuti kontrak `conventions.md`. Lihat §8.
  - **(5) Env standar.** Tulis `.env` app (gitignored) — DB_URL, API base URL, secret. **Shape**-nya direkam ke `conventions.md` (committed). Nilai secret = **GATE/manual**. Lihat §10. (Pinjam action `env` `build`.)
  - **(6) Smoke test** (§11). Ijo → tutup gate, laporkan "**app `<x>` siap di-`feature`**". Merah → STOP, laporkan (sandar `systematic-debugging`), **jangan** klaim selesai (anti-yes-man).
- **Output:** skeleton kosong-tapi-jalan di tiap app `path` (kode framework dari scaffolder resmi + glue wiring + `.env` + DB hidup) + shape env di `conventions.md`. `wire` **tidak** menyentuh `control/business/*` dan **tidak** bikin feature/table.
- **Gate:** **per app, sebelum tiap aksi side-effecting** (scaffold, bikin DB, migrate, tulis secret). Tampilkan rencana aksi + dampaknya → **approve/koreksi**. Untuk keputusan fondasi besar boleh invoke `critic` (konsisten `architect` §4).

## 7. Q&A Operasional (langkah 0.5 — "nutup `architect`")

Inti yang pengguna sebut: **"ada Q&A di `wire` yang menutup kerja `architect`".** `architect` berhenti di level arsitektur; `wire` menanyakan yang operasional, **per app**:

- **DB bring-up:** untuk `stack.db` bare-engine → **Docker lokal / URL remote?** Untuk managed → minta **creds** (URL + key, gated). (Bila `architect` sudah jelas managed, lewati pertanyaan engine.)
- **Package manager / runtime:** npm / pnpm / yarn / bun (deteksi default dari lockfile bila brownfield).
- **Nilai env/secret** yang dibutuhkan bring-up (DB creds managed, JWT secret, dll) — diisi pengguna (gated, tidak di-commit).
- **Konfirmasi `stack` logical** yang dibaca dari `architect`. Bila ada field **logical** yang hilang/ambigu (mis. ORM belum diputuskan), **STOP & balikin ke `architect`** — `wire` tidak memutuskan arsitektur diam-diam.

Q&A ini ringkas dan hanya soal "cara nyalain", bukan "pilih apa".

## 8. Generic by Design (tanpa daftar resep)

`wire` **tidak** punya registry resep per stack. Ia skill **agent** — persis seperti `build` yang command spesifiknya diisi agent saat runtime, bukan di-hardcode. Yang universal adalah **prosedurnya** (urutan *concern*: scaffold → DB up → BE↔DB → FE↔BE → env → smoke), bukan command-nya. Agent menurunkan command spesifik dari `stack` yang dibaca.

- **Delegasi ke scaffolder resmi** (batas `architect` line 24/43 dijaga): `wire` memanggil tool resmi (`create-*`, `prisma init`, `nest new`, dll) dan **hanya menulis glue** (env, base URL, CORS, client). Tidak mereimplementasi internal framework.
- **Caveat jujur (anti-yes-man):** "generic" = **prosedurnya** universal, bukan sulap yang pasti benar tiap stack. Stack mainstream → agent tahu command resminya persis. Stack langka → agent **mengajukan tebakan terbaik + GATE minta konfirmasi** (atau lookup dulu). Jadi `wire` **tidak pernah diam-diam salah** — paling banter bertanya. Itu harga dari "no list", dan trade yang dipilih.

## 9. Database: managed vs bare-engine

Cara "bikin DB" ditentukan **hasil Q&A 0.5**, bukan hardcode:

- **Bare-engine** (Postgres / MariaDB·MySQL / ClickHouse / Mongo / …): default **Docker lokal** — `wire` generate `docker-compose.yml` + connection string, bisa nyaris 100% otomatis (tanpa creds cloud). Alternatif: pengguna kasih **URL remote**.
- **Managed** (Supabase / Neon / PlanetScale / …): `wire` **connect** pakai creds yang dimasukkan pengguna (**GATE/manual** — out-of-band). Provisioning project-nya di luar scope (§3 Non-Tujuan).
- Connection string masuk `.env` (gated bila secret). Migrasi baseline + smoke query (§6 langkah 3) membuktikan DB hidup & nyambung sebelum gate ditutup.

## 10. Env Contract & Secrets

- **Shape env** (nama variabel + arti, **tanpa nilai**) per app type direkam di `conventions.md` (committed) — mis. BE: `DB_URL`, `JWT_SECRET`, `PORT`, `CORS_ORIGINS`; FE: `API_BASE_URL`, public keys. Ini menjadikan kontrak env **knowledge yang versioned**.
- **Nilai asli** ditulis ke `.env` app yang **gitignored**; secret diisi via **GATE/manual** (pinjam pola `manual:`/`needs_human` + action `env` `build`). Secret **tidak pernah** masuk `control/` atau git.
- `wire` memastikan `.env` ada di `.gitignore` app (tambahkan bila belum).

## 11. Smoke Test — definisi "wired" (menutup `plan` line 40)

Gate akhir `wire` punya **acceptance bar konkret** agar `plan`/`feature` boleh **percaya** fondasinya:

1. **BE boot** — proses start; bila ada health endpoint, ia merespons.
2. **DB reachable** — ORM connect, migrasi baseline ter-apply, smoke query balik ijo.
3. **FE→BE** — FE boot dan **berhasil memanggil** BE (health/ping). Fullstack (Next): app boot & route internal ke API-nya sendiri jalan.

Semua ijo → `wire` menutup gate dan menandai app **"siap di-`feature`"**. Ada yang merah → **STOP**, laporkan akar masalah (`systematic-debugging`), **jangan** tandai siap (anti-yes-man). Dengan ini, dead-end loop `plan` line 40 berubah dari "balik ke `architect`" (yang cuma gate) menjadi "jalankan `wire`" (yang benar-benar membangun + membuktikan).

## 12. Brownfield & Idempotency

- **Deteksi state per app** (§6 langkah 0): belum ter-scaffold → scaffold penuh; ter-scaffold tapi belum ter-wire → isi **hanya** bagian yang kurang; sudah ter-wire → **no-op**, laporkan.
- **Idempotent:** re-run `wire` di app yang sudah jalan tidak merusak apa pun — ia mendeteksi yang sudah ada dan hanya menambal celah. Tidak menimpa kode, `.env`, atau migrasi existing.
- Sejalan dengan dikotomi `architect` SETUP (greenfield) vs CAPTURE (existing). `wire(repair)` adalah pasangan operasional CAPTURE.

## 13. Multi-repo & Git

- **Reuse probe `build`:** kelompokkan app per **repo unik** via `git -C <path> rev-parse --show-toplevel` (monorepo/nested otomatis ciut). FE↔BE wiring lintas-repo jalan lewat env/URL (API base URL), bukan import langsung.
- **Eksekusi sekuensial** per repo (tidak ada dua proses menulis tree sama serempak) → aman monorepo & multi-repo tanpa worktree. Paralel = future.
- **Git:** `wire` boleh commit skeleton di branch yang sesuai (cek branch dulu — **jangan mulai di `main`/`master` tanpa izin**, pola `build`). **PR & merge tetap jatah pengguna/`ship`.**

## 14. Reuse dari `build`

`wire` **meminjam mesin side-effect `build`** ketimbang bikin dari nol (spec `2026-05-29` §7.1):

- **Actions** `install` / `cmd` / `migrate` / `env` — `wire` memakai bentuk eksekusi yang sama.
- **Aturan "`migrate` JANGAN auto + approve"** (build line 29) — dipakai di §6 langkah 3.
- **Penulisan `.env`** dari nilai `manual:`/prompt (build line 29) — dipakai di §10.
- **Probe multi-repo `git -C <path> rev-parse --show-toplevel`** + branching per-repo (build line 18) — dipakai di §13.
- **Pola STOP `manual:`/`needs_human`** untuk langkah yang butuh tangan manusia (creds managed, dll).

Bedanya dengan `build`: `wire` = **sekali, fondasi** (skeleton kosong-tapi-jalan); `build` = **per fitur** (kode fitur ke skeleton yang sudah jalan). `wire` bikin pipeline migrasi **berfungsi** + baseline; `build` bikin **table fitur**. Keduanya gate `migrate`.

## 15. Dampak ke Komponen Existing

- **Skill baru:** `plugin/skills/wire/SKILL.md`.
- **`plan/SKILL.md` line 40:** ubah *"arahkan user menjalankan `architect` dulu"* → *"…menjalankan `wire` dulu (setelah `architect`)"* — menutup dead-end loop.
- **`architect/SKILL.md` line 24 (SETUP, 3a):** penyesuaian doc kecil — alih-alih *"GATE: user yang jalanin"* bootstrap, arahkan *"fondasi teknis dijalankan oleh `wire`"*. Ini **menguatkan** batas (architect = keputusan, wire = eksekusi), bukan mengubah logika architect. Langkah 6 (saran next step) tambahkan `wire` sebelum `feature`.
- **`feature/SKILL.md` / `init` / `extract`:** update baris lifecycle agar memuat `wire` di antara `architect` dan `feature`.
- **`README.md`** & **spec induk §12/§17:** tambahkan `wire` ke diagram lifecycle; jumlah skill +1.
- **`plugin/.claude-plugin/plugin.json`:** deskripsi memuat `wire` (bring-up).
- **`render-docs`** (opsional, future): boleh menampilkan status wiring per app.

## 16. Scope v1 & Future

- **v1 (in):** skill `wire` (prosedur §6, Q&A §7, generic §8, DB §9, env §10, smoke §11, brownfield §12, multi-repo §13), reuse mesin `build` (§14), integrasi gate + anti-yes-man, update doc lifecycle (§15).
- **Future:** bring-up **paralel** lintas-app via worktree; provisioning cloud DB managed otomatis (bukan cuma connect); auto-detect skeleton siap untuk nyaris-mulus ke `feature`; resep ter-cache untuk stack yang sering dipakai (akselerasi, tetap fallback ke generic).

## 17. Open Questions (untuk tahap perencanaan)

- **Granularitas gate:** apakah satu gate per aksi (paling aman, paling cerewet) vs satu gate per app per fase (scaffold/db/wire) — bisa di-dial pengguna seperti `build` mode A? Default usul: **gate per aksi destruktif**, dengan opsi gabung.
- **Smoke test untuk app non-Node** (Go/Python): apakah `wire` menjalankan health-check generik (HTTP ping) atau menyerahkan definisi "boot ok" ke Q&A? Default usul: HTTP ping bila ada server; selain itu tanya.
- **Apakah `wire` boleh menawarkan bring-up multi-app sekaligus** (satu run untuk semua app di workspace) vs per-app eksplisit — default usul: tawarkan semua app `pending`, tapi eksekusi tetap sekuensial per repo.
- **Format manifest opsional:** apakah hasil bring-up dicatat ke artifact (mis. `control/wiring.yaml`: app → status wired, db mode, env shape) agar idempotency/brownfield lebih andal — vs cukup deteksi dari kode. Diputuskan saat implementasi.
