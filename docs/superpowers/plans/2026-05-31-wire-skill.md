# wire Skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **Setiap task yang menulis/mengedit file skill: load `superpowers:writing-skills` lebih dulu** (deliverable-nya SKILL.md markdown, bukan kode).

**Goal:** Tambahkan skill `wire` ke plugin context-vault — fase **bring-up** yang mengubah keputusan `architect` jadi skeleton kosong-tapi-jalan (scaffold app + DB nyala + wiring FE↔BE + env), menutup void manual antara `architect` dan `feature`.

**Architecture:** Satu skill baru di `plugin/skills/wire/` — `SKILL.md` ramping + `reference.md` detail (pola sama `discovery`/`breakdown`/`build`). `wire` = pelaksana operasional GENERIC: baca `stack` dari `workspace.yaml`, jalanin prosedur concern-driven (scaffold → DB → BE↔DB → FE↔BE → env → smoke) dengan command spesifik diturunkan agent saat runtime + GATE tiap aksi side-effecting. Plus edit integrasi di `plan`/`architect`/`feature`/`init`/`extract` SKILL.md, `README.md`, `plugin.json`. Sumber kebenaran desain: `docs/superpowers/specs/2026-05-31-wire-skill-design.md`.

**Tech Stack:** Claude Code plugin — file markdown (SKILL.md) + frontmatter YAML. Tidak ada runtime code. Verifikasi = parse YAML frontmatter + cek section/string wajib + JSON validity + dry-run manual. Tooling: `python3` (modul `yaml` via PyYAML; fallback `ruby -ryaml`), `grep`, `git`.

**Nature of work (penting):** Deliverable = instruksi markdown yang DIJALANKAN Claude (bukan kode mesin), jadi tidak ada "failing test" klasik. Tiap task: (1) tulis/edit file dengan konten yang sudah ditentukan di bawah, (2) verifikasi struktur dengan perintah konkret, (3) commit. Verifikasi perilaku end-to-end = Task 10 (dry-run + live `/plugin install`, sebagian diserahkan user — konsisten cara `discovery`/`breakdown`/`build` diverifikasi).

---

## Precheck: tooling YAML

- [ ] **Step 1: Pastikan ada parser YAML untuk verifikasi**

Run:
```bash
python3 -c "import yaml; print('pyyaml ok')" 2>/dev/null || echo "NO_PYYAML"
```
Expected: `pyyaml ok`. Bila `NO_PYYAML`, install (`python3 -m pip install pyyaml`) ATAU ganti tiap perintah verifikasi YAML di plan ini dengan `ruby -ryaml -e 'YAML.load_file(ARGV[0])' <file>` (Ruby default di macOS). Pakai pilihan tool konsisten.

- [ ] **Step 2: Pastikan di branch kerja (bukan langsung `main`)**

Run:
```bash
git branch --show-current
```
Expected: `wire-skill` (spec sudah di-commit di sini). Bila masih `main`, buat dulu: `git checkout -b wire-skill`.

---

## Task 1: `wire/reference.md` (detail bring-up)

Tulis reference dulu karena `SKILL.md` menunjuk ke sini (pola `discovery`/`build`).

**Files:**
- Create: `plugin/skills/wire/reference.md`

- [ ] **Step 1: Tulis `plugin/skills/wire/reference.md`**

````markdown
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
````

- [ ] **Step 2: Verifikasi struktur reference wire**

Run:
```bash
python3 - <<'PY'
src = open("plugin/skills/wire/reference.md").read()
for h in ["## A.", "## B.", "## C.", "## D.", "## E.", "## F.", "## G.", "## H.",
          "scaffolder resmi", "anti-yes-man", "docker-compose", "rev-parse --show-toplevel",
          "smoke query", "idempotent"]:
    assert h.lower() in src.lower(), f"hilang: {h}"
print("OK wire/reference.md")
PY
```
Expected: `OK wire/reference.md`

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/wire/reference.md
git commit -m "feat(wire): add reference (bring-up procedure, db, env, smoke, multi-repo)"
```

---

## Task 2: `wire/SKILL.md`

**Files:**
- Create: `plugin/skills/wire/SKILL.md`

- [ ] **Step 1: Tulis `plugin/skills/wire/SKILL.md`**

````markdown
---
name: wire
description: Use untuk bring-up fondasi teknis produk SETELAH architect — scaffold app via tool resmi + nyalain DB + wiring FE↔BE + env standar jadi skeleton KOSONG-tapi-JALAN, semua di-GATE. Generic: baca stack dari workspace.yaml (apa pun framework/db/orm-nya), bukan daftar tetap. Greenfield (scaffold penuh) & brownfield (repair, idempotent). Trigger — "wire", "bring-up", "nyalain project", "scaffold skeleton". Jalankan dari root produk yang punya control/.
---

# wire — Bring-Up Fondasi (skeleton kosong-tapi-jalan)

Tujuan: ubah KEPUTUSAN `architect` jadi skeleton yang JALAN — app ter-scaffold (tool resmi), DB nyala & nyambung, FE↔BE ter-wire, env standar terpasang — KOSONG dari kode fitur. Setelahnya `feature`/`build` tinggal "bikin table + panggil API". Jalankan dari root produk (punya `control/`).

`architect` = WHAT (mutusin stack). `wire` = HOW TO RUN (instansiasi). `wire` **GENERIC**: jalanin apa pun yang architect putuskan (Next/SolidStart/Go/ClickHouse/Supabase/…), bukan daftar stack tetap.

> Detail (batas architect/wire, prosedur generik, DB managed vs bare-engine, env contract, smoke test, brownfield, multi-repo, pinjam mesin `build`) ada di `${CLAUDE_PLUGIN_ROOT}/skills/wire/reference.md` — baca itu dulu.

## Prinsip (jangan dilanggar)
- **Delegasi ke scaffolder resmi.** Jangan tulis kode framework sendiri — panggil tool resmi (`create-*`, `nest new`, `django-admin`, dll). `wire` cuma nulis GLUE (env, base URL, CORS, client).
- **Tiap aksi side-effecting = GATE.** Scaffold, bikin DB, migrate, tulis secret → tampilkan rencana + dampak → minta approve dulu. `migrate` JANGAN auto.
- **Generic, tapi jujur.** Stack mainstream → tahu command resminya. Stack langka → ajukan tebakan terbaik + GATE konfirmasi (atau lookup). JANGAN diam-diam salah.
- **Jangan mutusin arsitektur.** Engine/framework/orm = jatah architect. Keputusan LOGICAL hilang → balikin ke architect.

## Langkah (per app, urut; penomoran cocok dengan reference)

### 0. Baca state & deteksi mode
Baca `control/workspace.yaml` (`apps[]`: path/type/stack/topology) + `control/conventions.md`. **Prasyarat:** architect sudah set `stack` logical (min framework + db + orm) per app; kalau belum → arahkan ke `architect`. Cek kode tiap `path`: kosong → **greenfield (scaffold penuh)**; ada kode → **brownfield (repair: lengkapi yang kurang, idempotent, jangan timpa)**.

### 0.5 Q&A operasional ("nutup architect")
Per app, tanya yang OPERASIONAL (bukan pilih arsitektur): DB bare-engine → **Docker lokal / URL remote?**; DB managed → minta creds (gated); package manager/runtime; nilai env/secret. Konfirmasi `stack` logical yang dibaca; field logical hilang/ambigu → STOP, balikin ke architect.

### 1. Scaffold app
Jalankan **tool resmi** framework (GATE sebelum eksekusi). Brownfield: lewati bila sudah ter-scaffold.

### 2. Nyalain DB
Sesuai hasil 0.5: bare-engine → spin Docker lokal (generate `docker-compose.yml`) / URL remote; managed → connect pakai creds (GATE). (reference C.)

### 3. Konek BE↔DB
Init ORM/driver (`stack.orm`), generate migrasi **baseline** (kosong dari table fitur), **apply** (GATE — migrate jangan auto), smoke query buktikan koneksi.

### 4. Wire FE↔BE
Fullstack → env + internal call; FE/BE kepisah → API base URL + CORS + (bila relevan) typed client. Ikut `conventions.md`. (reference A/B.)

### 5. Env standar
Tulis `.env` app (pastikan gitignored): DB_URL, API base URL, secret. Rekam SHAPE-nya (nama var + arti, tanpa nilai) ke `conventions.md`. Secret = GATE/manual. (Pinjam action `env` build — reference H.)

### 6. Smoke test (GATE penutup)
Boot? DB kebaca? FE→BE nyampe? Ijo → tutup gate, laporkan "**app <x> siap di-`feature`**". Merah → STOP + lapor akar masalah (sandar `systematic-debugging`); JANGAN klaim siap. (reference E.)

## Catatan
- `wire` sekali jalan (kayak `extract`), bisa di-rerun saat nambah app (kayak `architect`). Brownfield: bersifat **repair** — hanya bila wiring belum lengkap.
- TIDAK bikin table/skema fitur — itu jatah `build`. `wire` cuma bikin pipeline migrasi BERFUNGSI + baseline.
- TIDAK nyentuh `control/business/*`. PR & merge = jatah pengguna/`ship`; cek branch dulu (jangan mulai di `main` tanpa izin).
````

- [ ] **Step 2: Verifikasi frontmatter + section wajib**

Run:
```bash
python3 - <<'PY'
import re, yaml
src = open("plugin/skills/wire/SKILL.md").read()
fm = re.match(r"---\n(.*?)\n---\n", src, re.S)
assert fm, "frontmatter tidak ketemu"
meta = yaml.safe_load(fm.group(1))
assert meta.get("name") == "wire", meta.get("name")
assert "description" in meta and len(meta["description"]) > 30
for h in ["## Langkah", "### 0.5 Q&A operasional", "### 6. Smoke test",
          "Delegasi ke scaffolder resmi", "GENERIC", "siap di-`feature`"]:
    assert h in src, f"hilang: {h}"
print("OK wire/SKILL.md")
PY
```
Expected: `OK wire/SKILL.md`

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/wire/SKILL.md
git commit -m "feat(wire): add skill (bring-up empty-but-running skeleton)"
```

---

## Task 3: Edit `plan/SKILL.md` — redirect dead-end ke `wire`

Menutup dead-end loop (plan §40 dulu balik ke architect yang cuma gate).

**Files:**
- Modify: `plugin/skills/plan/SKILL.md`

- [ ] **Step 1: Ganti kalimat redirect di `## Catatan`**

Cari:
```
- JANGAN menetapkan stack/framework di sini — itu sudah ditetapkan `architect`. `plan` membaca yang ADA. Bila app belum punya fondasi, hentikan & arahkan user menjalankan `architect` dulu.
```
Ganti jadi:
```
- JANGAN menetapkan stack/framework di sini — itu sudah ditetapkan `architect`. `plan` membaca yang ADA. Bila app belum punya fondasi (skeleton belum jalan), hentikan & arahkan user menjalankan `wire` dulu (bring-up; `wire` jalan setelah `architect`).
```

- [ ] **Step 2: Verifikasi**

Run:
```bash
grep -q "menjalankan \`wire\` dulu (bring-up" plugin/skills/plan/SKILL.md && \
! grep -q "arahkan user menjalankan \`architect\` dulu" plugin/skills/plan/SKILL.md && \
echo "OK plan edit" || echo "FAIL plan edit"
```
Expected: `OK plan edit`

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/plan/SKILL.md
git commit -m "fix(plan): redirect missing-foundation stop to wire (close dead-end loop)"
```

---

## Task 4: Edit `architect/SKILL.md` — eksekusi bring-up = `wire`

Pertegas batas: architect = keputusan, `wire` = eksekusi. Tiga sentuhan kecil (tidak mengubah logika inti architect).

**Files:**
- Modify: `plugin/skills/architect/SKILL.md`

- [ ] **Step 1: Ubah langkah 3a (bootstrap = keputusan, eksekusi ke wire)**

Cari:
```
- Usulkan command bootstrap RESMI stack-nya (mis. `npx create-next-app@latest apps/web`) → **GATE: user yang jalanin.** `architect` TIDAK menulis kode framework sendiri — delegasi ke scaffolder resmi.
```
Ganti jadi:
```
- Catat command bootstrap RESMI stack-nya (mis. `npx create-next-app@latest apps/web`) sebagai bagian keputusan. **Eksekusi scaffold/bring-up = jatah `wire`** (gated), BUKAN di sini. `architect` TIDAK menulis/menjalankan kode framework — ia menetapkan, `wire` yang men-scaffold lewat scaffolder resmi.
```

- [ ] **Step 2: Tambah `wire` di saran next-step (langkah 6)**

Cari:
```
Tampilkan `stack` & `capabilities` per app (`workspace.yaml`) + isi `conventions.md` → minta **approve**. Sarankan langkah berikutnya: `extract` (brownfield, opsional) atau langsung `feature`.
```
Ganti jadi:
```
Tampilkan `stack` & `capabilities` per app (`workspace.yaml`) + isi `conventions.md` → minta **approve**. Sarankan langkah berikutnya: `wire` (bring-up: scaffold + DB + wiring + env jadi skeleton jalan) sebelum `feature`. (Brownfield: `extract` opsional dulu.)
```

- [ ] **Step 3: Pertegas catatan (eksekusi scaffolder = wire)**

Cari:
```
- `architect` = KNOWLEDGE fondasi (stack/konvensi/capabilities), BUKAN generator kode. Kode app dibuat scaffolder resmi (setup) atau sudah ada (capture).
```
Ganti jadi:
```
- `architect` = KNOWLEDGE fondasi (stack/konvensi/capabilities), BUKAN generator kode. Kode app dibuat scaffolder resmi (setup — **dijalankan `wire`**, gated) atau sudah ada (capture).
```

- [ ] **Step 4: Verifikasi**

Run:
```bash
grep -q "Eksekusi scaffold/bring-up = jatah \`wire\`" plugin/skills/architect/SKILL.md && \
grep -q "Sarankan langkah berikutnya: \`wire\`" plugin/skills/architect/SKILL.md && \
grep -q "setup — \*\*dijalankan \`wire\`\*\*" plugin/skills/architect/SKILL.md && \
! grep -q "GATE: user yang jalanin" plugin/skills/architect/SKILL.md && \
echo "OK architect edit" || echo "FAIL architect edit"
```
Expected: `OK architect edit`

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/architect/SKILL.md
git commit -m "feat(architect): defer scaffold execution to wire (decisions only)"
```

---

## Task 5: Edit `feature/SKILL.md` — prasyarat skeleton ter-wire

**Files:**
- Modify: `plugin/skills/feature/SKILL.md`

- [ ] **Step 1: Tambah bullet prasyarat di `## Catatan`**

Cari:
```
- `intake`/`fanout`/`plan` modular — bisa dipanggil sendiri untuk mengulang satu tahap (mis. `fanout` ulang setelah revisi `business.md`).
```
Ganti jadi (tambah satu bullet SETELAHNYA):
```
- `intake`/`fanout`/`plan` modular — bisa dipanggil sendiri untuk mengulang satu tahap (mis. `fanout` ulang setelah revisi `business.md`).
- Prasyarat: app sudah di-`wire` (skeleton jalan: DB nyambung, FE↔BE ke-wire). Kalau `plan` mentok karena fondasi belum ada, jalankan `wire` dulu (setelah `architect`).
```

- [ ] **Step 2: Verifikasi**

Run:
```bash
grep -q "Prasyarat: app sudah di-\`wire\`" plugin/skills/feature/SKILL.md && echo "OK feature edit" || echo "FAIL"
```
Expected: `OK feature edit`

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/feature/SKILL.md
git commit -m "docs(feature): note wired-skeleton prerequisite"
```

---

## Task 6: Edit `init/SKILL.md` — lifecycle sebut `wire`

**Files:**
- Modify: `plugin/skills/init/SKILL.md`

- [ ] **Step 1: Ubah bullet fondasi teknis di `## Catatan`**

Cari:
```
- `init` hanya men-scaffold + seed tipis. Knowledge bisnis tumbuh just-in-time lewat `feature`. Fondasi teknis ditangani `architect`.
```
Ganti jadi:
```
- `init` hanya men-scaffold + seed tipis. Knowledge bisnis tumbuh just-in-time lewat `feature`. Fondasi teknis ditangani `architect` (keputusan stack) lalu `wire` (bring-up: skeleton kosong-tapi-jalan).
```

- [ ] **Step 2: Verifikasi**

Run:
```bash
grep -q "lalu \`wire\` (bring-up" plugin/skills/init/SKILL.md && echo "OK init edit" || echo "FAIL"
```
Expected: `OK init edit`

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/init/SKILL.md
git commit -m "docs(init): mention wire bring-up after architect in lifecycle"
```

---

## Task 7: Edit `extract/SKILL.md` — catatan ordering vs `wire`

**Files:**
- Modify: `plugin/skills/extract/SKILL.md`

- [ ] **Step 1: Ubah bullet ordering di `## Catatan`**

Cari:
```
- Jalankan SETELAH `architect` (butuh path app; lebih baik bila `capabilities` sudah terisi).
```
Ganti jadi:
```
- Jalankan SETELAH `architect` (butuh path app; lebih baik bila `capabilities` sudah terisi). Independen dari `wire`: bila wiring app belum lengkap, `wire(repair)` yang menanganinya (bukan `extract`).
```

- [ ] **Step 2: Verifikasi**

Run:
```bash
grep -q "wire(repair)\` yang menanganinya" plugin/skills/extract/SKILL.md && echo "OK extract edit" || echo "FAIL"
```
Expected: `OK extract edit`

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/extract/SKILL.md
git commit -m "docs(extract): clarify ordering vs wire(repair)"
```

---

## Task 8: Edit `README.md` — lifecycle + entri `wire`

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Sebut `wire` di kalimat ringkas (line ~19)**

Cari:
```
Lalu `architect` (fondasi teknis), `feature` (bikin fitur), `ship`/`drop` (lifecycle), `render-docs` (doc human-readable).
```
Ganti jadi:
```
Lalu `architect` (fondasi teknis), `wire` (bring-up skeleton kosong-tapi-jalan), `feature` (bikin fitur), `ship`/`drop` (lifecycle), `render-docs` (doc human-readable).
```

- [ ] **Step 2: Tambah entri `/wire` di blok "Fondasi teknis"**

Cari:
```
/architect          # tetapkan stack (greenfield) / rekam stack+capabilities (brownfield) + konvensi
/extract            # (brownfield, opsional) front-load business/ dari kode existing
```
Ganti jadi:
```
/architect          # tetapkan stack (greenfield) / rekam stack+capabilities (brownfield) + konvensi
/wire               # bring-up: scaffold app + DB + wiring FE↔BE + env (skeleton kosong-tapi-jalan, gated)
/extract            # (brownfield, opsional) front-load business/ dari kode existing
```

- [ ] **Step 3: Sisipkan `/wire` di tiga baris Urutan**

Cari:
```
Urutan brownfield: `/init` -> `/architect` -> `/extract` (opsional) -> `/feature` -> `/breakdown` -> `/build` -> `/ship`.
Urutan greenfield (ide jelas): `/init` -> `/architect` -> `/feature` -> `/breakdown` -> `/build` -> `/ship`.
Urutan greenfield (ide mentah): `/discovery` -> `/init` -> `/architect` -> `/feature` -> `/breakdown` -> `/build` -> `/ship`.
```
Ganti jadi:
```
Urutan brownfield: `/init` -> `/architect` -> `/extract` (opsional) -> `/wire` -> `/feature` -> `/breakdown` -> `/build` -> `/ship`.
Urutan greenfield (ide jelas): `/init` -> `/architect` -> `/wire` -> `/feature` -> `/breakdown` -> `/build` -> `/ship`.
Urutan greenfield (ide mentah): `/discovery` -> `/init` -> `/architect` -> `/wire` -> `/feature` -> `/breakdown` -> `/build` -> `/ship`.
```

- [ ] **Step 4: Verifikasi**

Run:
```bash
grep -q "/wire               # bring-up" README.md && \
grep -q "\`wire\` (bring-up skeleton" README.md && \
[ "$(grep -c "architect\` -> \`/wire\` -> \`/feature" README.md)" = "2" ] && \
grep -q "(opsional) -> \`/wire\` -> \`/feature" README.md && \
echo "OK readme edit" || echo "FAIL readme edit"
```
Expected: `OK readme edit` (2 baris greenfield pakai `architect -> /wire -> /feature`; 1 baris brownfield pakai `(opsional) -> /wire -> /feature`).

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs(readme): add wire bring-up to lifecycle"
```

---

## Task 9: Edit `plugin.json` — deskripsi sebut `wire`

**Files:**
- Modify: `plugin/.claude-plugin/plugin.json`

- [ ] **Step 1: Update `description`**

Cari:
```
  "description": "AI-first product boilerplate: lapisan AI + knowledge untuk mengelola produk multi-app (init, feature pipeline, breakdown/build dengan actions/manual + integrasi cross-app + multi-repo aware, ship/drop, docs).",
```
Ganti jadi:
```
  "description": "AI-first product boilerplate: lapisan AI + knowledge untuk mengelola produk multi-app (init, architect + wire bring-up, feature pipeline, breakdown/build dengan actions/manual + integrasi cross-app + multi-repo aware, ship/drop, docs).",
```

- [ ] **Step 2: Verifikasi JSON tetap valid**

Run:
```bash
python3 -c "import json; d=json.load(open('plugin/.claude-plugin/plugin.json')); assert 'wire bring-up' in d['description']; print('OK plugin.json valid')"
```
Expected: `OK plugin.json valid`

- [ ] **Step 3: Commit**

```bash
git add plugin/.claude-plugin/plugin.json
git commit -m "docs(plugin): mention wire bring-up in description"
```

---

## Task 10: Verifikasi menyeluruh + dry-run

**Files:**
- (tidak ada file baru — verifikasi + dokumentasi dry-run)

- [ ] **Step 1: Cek struktur file wire & semua skill ke-discover**

Run:
```bash
ls plugin/skills/wire/SKILL.md plugin/skills/wire/reference.md
```
Expected: kedua path ada (tidak ada error "No such file").

- [ ] **Step 2: Validasi SEMUA frontmatter skill plugin (regresi)**

Run:
```bash
python3 - <<'PY'
import re, yaml, glob
bad = []
files = glob.glob("plugin/skills/*/SKILL.md")
for f in files:
    src = open(f).read()
    m = re.match(r"---\n(.*?)\n---\n", src, re.S)
    if not m: bad.append((f,"no frontmatter")); continue
    meta = yaml.safe_load(m.group(1))
    if not meta.get("name") or not meta.get("description"):
        bad.append((f,"missing name/description"))
assert not bad, bad
assert any(f.endswith("/wire/SKILL.md") for f in files), "wire skill tidak ke-discover"
print("OK semua SKILL.md frontmatter valid:", len(files), "skill")
PY
```
Expected: `OK semua SKILL.md frontmatter valid: 14 skill` (13 lama + `wire`).

- [ ] **Step 3: Cek konsistensi cross-ref `wire` di skill tetangga**

Run:
```bash
grep -q "wire" plugin/skills/plan/SKILL.md && \
grep -q "wire" plugin/skills/architect/SKILL.md && \
grep -q "wire" plugin/skills/feature/SKILL.md && \
grep -q "wire" plugin/skills/init/SKILL.md && \
grep -q "wire" plugin/skills/extract/SKILL.md && \
echo "OK semua tetangga sebut wire" || echo "FAIL: ada tetangga belum sebut wire"
```
Expected: `OK semua tetangga sebut wire`

- [ ] **Step 4: Dry-run wire (manual, pakai fixture greenfield)**

Buat fixture minimal (app greenfield kosong, stack sudah diputus architect) lalu telusuri instruksi `wire` manual (TIDAK butuh plugin ter-install — latihan baca-instruksi):
```bash
mkdir -p /tmp/cv-wire-dryrun/control
cat > /tmp/cv-wire-dryrun/control/workspace.yaml <<'YAML'
product: demo
topology: monorepo
apps:
  - name: web
    path: apps/web
    type: fullstack
    responsibility: "app utama"
    capabilities: []
    stack: { framework: Next.js, db: Postgres, orm: Prisma }
YAML
printf '# demo — Konvensi\nAuth: cookie session.\nFormat API: JSON problem+json.\n' > /tmp/cv-wire-dryrun/control/conventions.md
echo "fixture siap di /tmp/cv-wire-dryrun (apps/web BELUM ada = greenfield)"
```
Lalu (sebagai reviewer manusia/agent): baca `plugin/skills/wire/SKILL.md` + `reference.md`, dan **telusuri langkah 0→6 untuk app `web`**. Konfirmasi instruksinya cukup jelas untuk menghasilkan urutan bring-up yang benar: deteksi greenfield → Q&A operasional (Postgres: Docker lokal? pkg manager?) → scaffold `create-next-app` (GATE) → spin Docker Postgres → `prisma init` + migrasi baseline (GATE migrate) + smoke query → wiring env/internal → tulis `.env` + shape ke `conventions.md` → smoke test. Catat ambiguitas; bila ada, perbaiki SKILL.md/reference.md (lalu commit perbaikan di Step 6).

Cek juga satu skenario edge secara mental: **stack langka** (mis. `framework: SolidStart, db: ClickHouse`) — pastikan instruksi mengarahkan agent ke "ajukan command + GATE konfirmasi", bukan diam-diam nebak. Dan **brownfield** (apps/web sudah ada) — pastikan jalurnya jadi repair/idempotent, bukan menimpa.

- [ ] **Step 5: Bersihkan fixture**

Run:
```bash
rm -rf /tmp/cv-wire-dryrun
echo "cleaned"
```

- [ ] **Step 6: Commit (bila Step 4 menghasilkan perbaikan)**

```bash
git add -A plugin/skills/wire
git commit -m "fix(wire): clarify instructions from dry-run" || echo "no changes to commit"
```

- [ ] **Step 7: Live test (diserahkan ke user — sama seperti skill lain)**

Catat di ringkasan akhir bahwa verifikasi live butuh user:
```
/plugin marketplace add <path repo ini>   (atau update bila sudah ter-add)
/plugin install context-vault
# lalu di produk greenfield ber-control/ + stack ter-architect: /wire → review tiap gate → skeleton boot
```
Konsisten dengan cara `discovery`/`breakdown`/`build` diverifikasi (dry-run di repo; trigger `/plugin install` live oleh user).

---

## Catatan Eksekusi

- **Branch:** kerja di `wire-skill` (spec sudah di-commit di sana). Merge/PR ke `main` = keputusan user di akhir (repo ini terbiasa ff-merge branch ke `main`).
- **Urutan task:** Task 1→2 (skill wire; reference dulu karena SKILL menunjuk ke sana), lalu 3–9 (integrasi, independen satu sama lain), 10 (verifikasi) terakhir.
- **Skill authoring:** tiap task buat/edit SKILL.md → load `superpowers:writing-skills` (cek kualitas description/trigger, format konsisten dengan skill sibling).
- **Tidak ada perubahan ke `template/`** — fitur ini murni nambah skill `wire` + edit integrasi dok. (`wire` beroperasi di app `path`, bukan di `control/template`.)
- **Tidak ada runtime/test code baru** — verifikasi = struktur file + dry-run baca-instruksi + live `/plugin install` (user).
