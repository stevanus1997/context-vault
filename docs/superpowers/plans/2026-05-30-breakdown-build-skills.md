# breakdown + build Skills — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **Setiap task yang menulis/mengedit file skill: load `superpowers:writing-skills` lebih dulu** (deliverable-nya adalah SKILL.md markdown, bukan kode).

**Goal:** Tambahkan Fase Eksekusi (`breakdown` + `build`) ke plugin context-vault yang menjembatani `plan` (status `active`) ke `ship`.

**Architecture:** Dua skill baru di `plugin/skills/` — `breakdown` (plan flat → `tasks.yaml` enriched) dan `build` (orchestrator: dispatch implementer subagent per task → review 2-tahap → gate per segmen → serah ke `ship`). Tiap skill = `SKILL.md` ramping + `reference.md` detail (pola sama seperti skill `discovery` yang ada). Plus edit handoff di `feature`/`plan`/`ship` SKILL.md, `README.md`, dan `plugin.json`. Sumber kebenaran desain: `docs/superpowers/specs/2026-05-29-breakdown-build-execution-phase-design.md`.

**Tech Stack:** Claude Code plugin — file markdown (SKILL.md) + frontmatter YAML. Tidak ada runtime code. Verifikasi = parse YAML frontmatter + cek section wajib + parse contoh skema `tasks.yaml` sebagai YAML valid + dry-run manual. Tooling cek: `python3` (modul `yaml` via PyYAML; bila tak ada, pakai `ruby -ryaml` atau `node`), `grep`, `git`.

**Nature of work (penting):** Karena deliverable = instruksi markdown yang DIJALANKAN oleh Claude (bukan kode yang dijalankan mesin), tidak ada "failing test" klasik. Tiap task: (1) tulis/edit file dengan konten yang sudah ditentukan di bawah, (2) verifikasi struktur dengan perintah konkret, (3) commit. Verifikasi perilaku end-to-end = Task 10 (dry-run + live `/plugin install`, sebagian diserahkan ke user — konsisten dengan cara skill `discovery` diverifikasi).

---

## Precheck: tooling YAML

- [ ] **Step 1: Pastikan ada parser YAML untuk verifikasi**

Run:
```bash
python3 -c "import yaml; print('pyyaml ok')" 2>/dev/null || echo "NO_PYYAML"
```
Expected: `pyyaml ok`. Bila `NO_PYYAML`, install (`python3 -m pip install pyyaml`) ATAU ganti semua perintah verifikasi YAML di plan ini dengan `ruby -ryaml -e 'YAML.load_file(ARGV[0])' <file>` (Ruby ada default di macOS). Catat pilihan tool-nya dan pakai konsisten.

---

## Task 1: `breakdown/reference.md` (skema tasks.yaml + aturan)

Tulis reference dulu karena `SKILL.md` menunjuk ke sini. Detail "skema + aturan granularitas" ditaruh di reference agar SKILL.md ramping (pola skill `discovery`).

**Files:**
- Create: `plugin/skills/breakdown/reference.md`

- [ ] **Step 1: Tulis `plugin/skills/breakdown/reference.md`**

````markdown
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
        desc: <satu baris: apa yang dibangun>
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
````

- [ ] **Step 2: Verifikasi blok-blok YAML di reference valid**

Run:
```bash
python3 - <<'PY'
import re, yaml, sys
src = open("plugin/skills/breakdown/reference.md").read()
blocks = re.findall(r"```yaml\n(.*?)```", src, re.S)
assert blocks, "tidak ada blok yaml"
for i, b in enumerate(blocks):
    yaml.safe_load(b)
print(f"OK: {len(blocks)} blok yaml valid")
PY
```
Expected: `OK: 2 blok yaml valid`

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/breakdown/reference.md
git commit -m "feat(breakdown): add reference (tasks.yaml schema + rules)"
```

---

## Task 2: `breakdown/SKILL.md`

**Files:**
- Create: `plugin/skills/breakdown/SKILL.md`

- [ ] **Step 1: Tulis `plugin/skills/breakdown/SKILL.md`**

````markdown
---
name: breakdown
description: Use untuk memecah plan flat sebuah fitur (status active) jadi tasks.yaml — daftar task kecil berurutan (files + approach + test cases, TANPA kode) yang nanti dieksekusi build. Trigger — "breakdown <fitur>", "pecah task <fitur>", "bikin tasks <fitur>". Jalankan dari root produk yang punya control/.
---

# breakdown — Plan Flat → Task List (`tasks.yaml`)

Tujuan: ubah `plans/*.md` (flat) jadi rencana kerja siap-eksekusi: task kecil, berurutan, ber-dependency, dengan `files` + `approach` + kasus `test` — TANPA kode. Output dimakan `build`. Jalankan dari root produk (punya `control/`).

> Skema lengkap `tasks.yaml` + aturan granularitas + contoh ada di `${CLAUDE_PLUGIN_ROOT}/skills/breakdown/reference.md` — baca itu dulu.

## Langkah

### 1. Baca input
Baca `control/features/<fitur>/plans/_shared.md` + `plans/<app>.md` + `fanout.md` (untuk Urutan lintas-app) + `control/workspace.yaml` (app/path/stack). **Prasyarat:** `feature.yaml` `status: active`. Bila belum, hentikan & arahkan ke `feature`/`plan`. (Boleh mengintip ringan struktur kode untuk menakar granularitas; baca-kode mendalam = jatah `build`.)

### 2. Iris milestone + task
Iris jadi **milestone** (slice logis: fondasi dulu, turunan menyusul) lalu **task** di dalamnya. Granularitas: **satu task = unit testable terkecil**. Rasionalisasi hierarki fitur (mis. "register by google" = flow OAuth yang sama dengan "login by google" → satu milestone OAuth per provider).

### 3. Enrich tiap task
Isi tiap task: `files` (path create/modify/test — WHERE), `approach` (1-2 baris HOW ringkas), `test` (daftar kasus yang harus lulus — WHAT). **JANGAN tulis kode implementasi** — itu jatah `build` (just-in-time, lawan kode terkini). `breakdown` **TIDAK** memanggil `writing-plans`.

### 4. Urutan & dependency
Tentukan `deps` tiap task dari: kontrak `_shared.md` (fondasi paling dulu), Urutan `fanout.md` (lintas-app, mis. `api` sebelum `web`), dependency logis intra-app.

### 5. Critic (opsional)
Untuk fitur besar/berisiko, invoke subagent `critic` atas peta task: urutan keliru? milestone kegedean? dependency kelewat?

### 6. Tulis output (GATE)
Tulis `control/features/<fitur>/tasks.yaml` sesuai skema reference, semua `status: pending`. Tampilkan **PETA TASK** (milestone × app × task + `deps` + `files` + kasus `test`) → minta **approve/koreksi**. Di gate ini pengguna belum melihat kode — hanya menyetujui rencana kerja. Murah & cepat.

## Catatan
- Output = input `build`. JANGAN nulis kode di sini.
- `tasks.yaml` `status` jadi sumber progres + mekanisme resume `build`.
- `plan` tetap flat; `breakdown` yang menambah struktur task.
````

- [ ] **Step 2: Verifikasi frontmatter + section wajib**

Run:
```bash
python3 - <<'PY'
import re, yaml
src = open("plugin/skills/breakdown/SKILL.md").read()
fm = re.match(r"---\n(.*?)\n---\n", src, re.S)
assert fm, "frontmatter tidak ketemu"
meta = yaml.safe_load(fm.group(1))
assert meta.get("name") == "breakdown", meta.get("name")
assert "description" in meta and len(meta["description"]) > 30
for h in ["## Langkah", "### 6. Tulis output (GATE)", "TANPA kode", "writing-plans"]:
    assert h in src, f"hilang: {h}"
print("OK breakdown/SKILL.md")
PY
```
Expected: `OK breakdown/SKILL.md`

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/breakdown/SKILL.md
git commit -m "feat(breakdown): add skill (flat plan -> tasks.yaml)"
```

---

## Task 3: `build/reference.md` (panduan dispatch)

**Files:**
- Create: `plugin/skills/build/reference.md`

- [ ] **Step 1: Tulis `plugin/skills/build/reference.md`**

````markdown
# build — Reference (panduan dispatch subagent)

Dibaca oleh skill `build`. Cara menyusun prompt implementer dari satu task, template yang dipinjam, pilih model, dan cadence gate.

## A. Pinjam dari `subagent-driven-development`

`build` TIDAK meng-invoke skill `subagent-driven-development` (itu mengeksekusi plan `writing-plans` secara continuous + diakhiri `finishing-a-development-branch` — bentrok dengan gate kita & `ship`). `build` **meminjam** template & polanya:
- `implementer-prompt.md` — struktur prompt implementer.
- `spec-reviewer-prompt.md` — reviewer kepatuhan-spec.
- `code-quality-reviewer-prompt.md` — reviewer kualitas (pakai template `requesting-code-review`).
- Panduan pilih-model & penanganan status (DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT).

Kunci dari template implementer: *controller mem-paste teks task ke prompt; subagent TIDAK membaca file plan.* Maka sumber teks task kita = `tasks.yaml` (bukan file `writing-plans`).

## B. Menyusun prompt implementer dari satu task

Dari satu entri `tasks.yaml`, controller (`build`) merakit prompt berisi:
- **Task:** `desc` + `app`.
- **Files:** isi `files` (path create/modify/test).
- **Approach:** `approach`.
- **Test cases:** daftar `test` → "tulis test ini dulu (TDD), pastikan merah, baru implementasi sampai hijau".
- **Kontrak:** potongan `_shared.md` yang relevan.
- **Konvensi & stack:** dari `conventions.md` + `workspace.yaml` `stack` app.
- **Pointer pola:** tunjuk 1-2 file existing sebagai contoh gaya (mis. route sejenis).
- **Instruksi:** pakai `test-driven-development`; commit setelah hijau; self-review; balik **ringkasan + status**.

JANGAN suruh subagent membaca `tasks.yaml` — paste teksnya.

### Contoh (task T3 `auth`)
```
Task: POST /auth/register (app: api)
Files: create src/routes/auth/register.ts; modify src/routes/index.ts;
       test test/auth/register.test.ts
Approach: hash(util T1, src/lib/hash.ts) -> simpan User -> session(T2, src/lib/session.ts)
          -> 201 + set-cookie
Test cases (tulis dulu, TDD): sukses 201+cookie; email kepake 409; pw lemah 422
Kontrak (_shared): session = cookie httpOnly JWT HS256 TTL 7d
Konvensi: error problem+json; validasi zod (pola: src/routes/auth/login.ts)
Stack: Express + Prisma + Postgres
-> Pakai test-driven-development. Commit setelah hijau. Balik ringkasan + status.
```

## C. Pilih model (hemat biaya & cepat)
- Task mekanikal (1-2 file, spec jelas) → model murah/cepat.
- Integrasi multi-file / pattern-matching → model standar.
- Butuh judgment desain → model paling kuat.

## D. Cadence gate (mode A adaptif)
- **Default:** gate per **app × milestone** — semua task satu app dalam satu milestone hijau → BERHENTI, tampilkan diff + test + "dibangun vs task" + challenge checklist → approve/revisi.
- **Lebih rapat:** app pemegang kontrak `_shared.md` / ditandai berisiko (milestone fondasi) → checkpoint per-task.
- **Lebih longgar:** milestone bermotif mapan (OAuth provider ke-2/ke-3) → gabung gate.
- **Fitur 1-app** → ciut jadi 1 gate.
- Selalu hormati `deps` + Urutan `fanout` (mis. `web` dibangun setelah `api` nyata, bukan yang direncanakan).

## E. Status & resume
- `build` set `status` task: `in_progress` → `done` (atomik, tulis ke `tasks.yaml`) setelah lulus DUA review.
- Buntu → `blocked` + STOP + lapor (sandar `systematic-debugging`). Jangan `done` palsu.
- Resume: sesi baru baca `tasks.yaml`, lewati `done`, lanjut `pending` berikut.
````

- [ ] **Step 2: Verifikasi struktur reference build**

Run:
```bash
python3 - <<'PY'
src = open("plugin/skills/build/reference.md").read()
for h in ["## A.", "## B.", "## C.", "## D.", "## E.", "implementer-prompt.md",
          "spec-reviewer-prompt.md", "code-quality-reviewer-prompt.md",
          "don", "paste"]:
    assert h.lower() in src.lower(), f"hilang: {h}"
print("OK build/reference.md")
PY
```
Expected: `OK build/reference.md`

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/build/reference.md
git commit -m "feat(build): add reference (subagent dispatch guide)"
```

---

## Task 4: `build/SKILL.md`

**Files:**
- Create: `plugin/skills/build/SKILL.md`

- [ ] **Step 1: Tulis `plugin/skills/build/SKILL.md`**

````markdown
---
name: build
description: Use untuk mengeksekusi tasks.yaml sebuah fitur (status active) jadi kode lulus-test — dispatch implementer subagent per task (TDD), review 2-tahap, gate per app/milestone, lalu siap di-ship. Resumable lintas-sesi. Trigger — "build <fitur>", "implement <fitur>", "kerjain <fitur>". Jalankan dari root produk yang punya control/.
---

# build — Eksekusi `tasks.yaml` (orchestrator)

Tujuan: jalanin `tasks.yaml` jadi kode yang lulus test, di bawah gate, lalu nyatakan fitur siap di-`ship`. `build` = **KONDUKTOR**; kode ditulis subagent (konteks isolasi → sesi build tetap ramping & resumable).

> Panduan dispatch (rakit prompt implementer dari satu task, template yang dipinjam, pilih model, cadence gate, resume) ada di `${CLAUDE_PLUGIN_ROOT}/skills/build/reference.md` — baca itu dulu.

## Langkah

### 1. Baca state & cek branch
Baca `control/features/<fitur>/tasks.yaml` + `plans/*` + `_shared.md` + `control/conventions.md` + `control/workspace.yaml` (path/stack). **Prasyarat:** `tasks.yaml` ada (kalau belum → suruh jalankan `breakdown` dulu, sebaiknya sesi terpisah); `feature.yaml` `status: active`. **Cek branch git** — kalau di `main`/`master`, minta konfirmasi / bikin branch fitur dulu (jangan mulai di main tanpa izin).

### 2. Pilih task
Ambil task `pending` pertama yang seluruh `deps`-nya `done`.

### 3. Dispatch implementer subagent
Rakit prompt LENGKAP dari task (paste teks task; **jangan** suruh subagent baca `tasks.yaml`): `desc` + `files` + `approach` + kasus `test` + potongan `_shared.md` + konvensi + stack + pointer file pola. Pilih model sesuai kompleksitas. Subagent menulis kode **TDD** (test dari kasus dulu → hijau), commit, self-review → balik **ringkasan + status**. (Detail rakitan prompt: `reference.md` bagian B.)

### 4. Review 2-tahap
Dispatch **spec-reviewer** ("verifikasi dengan baca kode, jangan percaya report") → bila lulus, **code-quality-reviewer**. Reviewer nemu masalah → implementer (subagent sama) perbaiki → review ulang sampai lulus.

### 5. Tandai status
Set `status`: `in_progress` saat mulai, `done` saat lulus DUA review (atomik — tulis ke `tasks.yaml`). Buntu → `blocked`, **STOP**, laporkan (sandar `systematic-debugging`). **JANGAN** tandai `done` palsu.

### 6. Gate per segmen (mode A adaptif)
Semua task satu segmen (default **app × milestone**) `done` → **BERHENTI**: tampilkan diff segmen + hasil test + "dibangun vs task" + **challenge checklist** → minta **approve/revisi**. Adaptif: app pemegang `_shared.md`/berisiko → boleh per-task; milestone mapan → boleh gabung; fitur 1-app → 1 gate. (Detail: `reference.md` bagian D.)

### 7. Selesai
Ulang sampai semua task `done` → laporkan **"fitur <fitur> siap di-`ship`"**. Serahkan ke `ship` — **JANGAN** jalankan `finishing-a-development-branch` (itu jatah `ship`). `feature.yaml` `status` tetap `active`.

## Catatan
- `build` BUKAN urusannya: nentuin stack (→ `architect`), mecah task (→ `breakdown`), bikin PR / tandai `shipped` (→ `ship`).
- Hemat konteks: kerja berat di subagent; sesi `build` cuma nampung ringkasan + status → bisa dicicil lintas sesi (resume dari `tasks.yaml`).
- Commit per task di branch fitur; PR & merge tetap jatah `ship`.
````

- [ ] **Step 2: Verifikasi frontmatter + section wajib**

Run:
```bash
python3 - <<'PY'
import re, yaml
src = open("plugin/skills/build/SKILL.md").read()
fm = re.match(r"---\n(.*?)\n---\n", src, re.S)
assert fm, "frontmatter tidak ketemu"
meta = yaml.safe_load(fm.group(1))
assert meta.get("name") == "build", meta.get("name")
assert "description" in meta and len(meta["description"]) > 30
for h in ["### 3. Dispatch implementer subagent", "Review 2-tahap",
          "Gate per segmen", "siap di-`ship`", "finishing-a-development-branch"]:
    assert h in src, f"hilang: {h}"
print("OK build/SKILL.md")
PY
```
Expected: `OK build/SKILL.md`

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/build/SKILL.md
git commit -m "feat(build): add skill (execute tasks.yaml via subagents)"
```

---

## Task 5: Edit `feature/SKILL.md` — handoff ke breakdown→build

**Files:**
- Modify: `plugin/skills/feature/SKILL.md`

- [ ] **Step 1: Ganti saran langkah 4**

Cari blok (langkah 4 "Ringkas"):
```
### 4. Ringkas
Tampilkan artifact yang dihasilkan (`business.md`, `fanout.md`, `plans/*`). Sarankan langkah berikutnya: implementasi (pakai pola executing-plans/subagent), lalu `ship` (Fase 4) saat selesai.
```
Ganti jadi:
```
### 4. Ringkas
Tampilkan artifact yang dihasilkan (`business.md`, `fanout.md`, `plans/*`). Sarankan langkah berikutnya: jalankan `breakdown` (pecah plan jadi `tasks.yaml`) lalu `build` (eksekusi) — sebaiknya masing-masing sesi terpisah — baru `ship` saat selesai.
```

- [ ] **Step 2: Update catatan transisi**

Cari:
```
- Transisi `shipped`/`dropped` ditangani skill `ship`/`drop` (Fase 4).
```
Ganti jadi:
```
- Eksekusi implementasi ditangani `breakdown` → `build`; transisi `shipped`/`dropped` ditangani `ship`/`drop`.
```

- [ ] **Step 3: Verifikasi**

Run:
```bash
grep -q "jalankan `breakdown`" plugin/skills/feature/SKILL.md && \
grep -q "breakdown` → `build`" plugin/skills/feature/SKILL.md && \
! grep -q "pola executing-plans/subagent), lalu" plugin/skills/feature/SKILL.md && \
echo "OK feature edit" || echo "FAIL feature edit"
```
Expected: `OK feature edit`

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/feature/SKILL.md
git commit -m "feat(feature): hand off to breakdown -> build after plan"
```

---

## Task 6: Edit `plan/SKILL.md` — catatan dekomposisi = breakdown

**Files:**
- Modify: `plugin/skills/plan/SKILL.md`

- [ ] **Step 1: Tambah satu baris di `## Catatan`**

Cari baris terakhir di `## Catatan`:
```
- Setelah semua plan di-approve, kontrol kembali ke `feature` (yang menandai status `active`).
```
Tambahkan baris baru SETELAHNYA:
```
- `plan` tetap FLAT. Dekomposisi jadi task kecil (siap-eksekusi) = jatah skill `breakdown`, bukan di sini.
```

- [ ] **Step 2: Verifikasi**

Run:
```bash
grep -q "Dekomposisi jadi task kecil" plugin/skills/plan/SKILL.md && echo "OK plan edit" || echo "FAIL"
```
Expected: `OK plan edit`

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/plan/SKILL.md
git commit -m "docs(plan): note task decomposition is breakdown's job"
```

---

## Task 7: Edit `ship/SKILL.md` — catatan implementasi via build

**Files:**
- Modify: `plugin/skills/ship/SKILL.md`

- [ ] **Step 1: Ganti baris catatan implementasi**

Cari (di `## Catatan`):
```
- `ship` TIDAK mengeksekusi/menulis fitur — implementasi dilakukan sebelumnya (pola executing-plans/subagent). `ship` = finishing gate + kirim.
```
Ganti jadi:
```
- `ship` TIDAK mengeksekusi/menulis fitur — implementasi dilakukan sebelumnya oleh `build` (atau manual). `ship` = finishing gate + kirim, dan yang membuat PR / menandai `shipped` (bukan `build`).
```

- [ ] **Step 2: Verifikasi**

Run:
```bash
grep -q "sebelumnya oleh `build`" plugin/skills/ship/SKILL.md && \
! grep -q "sebelumnya (pola executing-plans/subagent)" plugin/skills/ship/SKILL.md && \
echo "OK ship edit" || echo "FAIL"
```
Expected: `OK ship edit`

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/ship/SKILL.md
git commit -m "docs(ship): note implementation comes from build"
```

---

## Task 8: Edit `README.md` — lifecycle

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update bagian "Bikin fitur"**

Cari blok ini (pagar kode ``` di bawah milik README):

````markdown
## Bikin fitur
```
/feature <nama>     # konduktor: intake (bisnis) -> fanout (lintas-app) -> plan (teknis)
```
Sub-skill bisa dipanggil sendiri: `/intake`, `/fanout`, `/plan`. Tiap tahap ada gate; agent `critic` me-review di gate penting.
````

Ganti jadi:

````markdown
## Bikin fitur
```
/feature <nama>     # konduktor: intake (bisnis) -> fanout (lintas-app) -> plan (teknis)
/breakdown <nama>   # pecah plan flat -> tasks.yaml (task kecil berurutan, tanpa kode)
/build <nama>       # eksekusi tasks.yaml: implementer subagent per task (TDD) + review + gate
```
Sub-skill bisa dipanggil sendiri: `/intake`, `/fanout`, `/plan`. Tiap tahap ada gate; agent `critic` me-review di gate penting. `breakdown` & `build` dipanggil eksplisit (boleh sesi terpisah) sebelum `ship`.
````

- [ ] **Step 2: Update tiga baris "Urutan" greenfield/brownfield**

Cari di bagian "Fondasi teknis":
```
Urutan brownfield: `/init` -> `/architect` -> `/extract` (opsional) -> `/feature`.
Urutan greenfield (ide jelas): `/init` -> `/architect` -> `/feature`.
Urutan greenfield (ide mentah): `/discovery` -> `/init` -> `/architect` -> `/feature`.
```
Ganti tiap akhir `-> /feature` jadi `-> /feature -> /breakdown -> /build -> /ship`:
```
Urutan brownfield: `/init` -> `/architect` -> `/extract` (opsional) -> `/feature` -> `/breakdown` -> `/build` -> `/ship`.
Urutan greenfield (ide jelas): `/init` -> `/architect` -> `/feature` -> `/breakdown` -> `/build` -> `/ship`.
Urutan greenfield (ide mentah): `/discovery` -> `/init` -> `/architect` -> `/feature` -> `/breakdown` -> `/build` -> `/ship`.
```

- [ ] **Step 3: Verifikasi**

Run:
```bash
grep -q "/breakdown <nama>" README.md && \
grep -q "/build <nama>" README.md && \
grep -c "breakdown\` -> \`/build\` -> \`/ship" README.md && \
echo "OK readme edit"
```
Expected: angka `3` lalu `OK readme edit` (tiga baris urutan ter-update).

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs(readme): add breakdown -> build to feature lifecycle"
```

---

## Task 9: Edit `plugin.json` — deskripsi

**Files:**
- Modify: `plugin/.claude-plugin/plugin.json`

- [ ] **Step 1: Update `description`**

Cari:
```
  "description": "AI-first product boilerplate: lapisan AI + knowledge untuk mengelola produk multi-app (init, feature pipeline, ship/drop, docs).",
```
Ganti jadi:
```
  "description": "AI-first product boilerplate: lapisan AI + knowledge untuk mengelola produk multi-app (init, feature pipeline, breakdown/build, ship/drop, docs).",
```

- [ ] **Step 2: Verifikasi JSON tetap valid**

Run:
```bash
python3 -c "import json; d=json.load(open('plugin/.claude-plugin/plugin.json')); assert 'breakdown/build' in d['description']; print('OK plugin.json valid')"
```
Expected: `OK plugin.json valid`

- [ ] **Step 3: Commit**

```bash
git add plugin/.claude-plugin/plugin.json
git commit -m "docs(plugin): mention breakdown/build in description"
```

---

## Task 10: Verifikasi menyeluruh + dry-run

**Files:**
- (tidak ada file baru — verifikasi + dokumentasi dry-run)

- [ ] **Step 1: Cek struktur file & semua skill ke-discover**

Run:
```bash
ls plugin/skills/breakdown/SKILL.md plugin/skills/breakdown/reference.md \
   plugin/skills/build/SKILL.md plugin/skills/build/reference.md
```
Expected: keempat path ada (tidak ada error "No such file").

- [ ] **Step 2: Validasi SEMUA frontmatter skill plugin (regresi)**

Run:
```bash
python3 - <<'PY'
import re, yaml, glob
bad = []
for f in glob.glob("plugin/skills/*/SKILL.md"):
    src = open(f).read()
    m = re.match(r"---\n(.*?)\n---\n", src, re.S)
    if not m: bad.append((f,"no frontmatter")); continue
    meta = yaml.safe_load(m.group(1))
    if not meta.get("name") or not meta.get("description"):
        bad.append((f,"missing name/description"))
assert not bad, bad
print("OK semua SKILL.md frontmatter valid:", len(glob.glob('plugin/skills/*/SKILL.md')), "skill")
PY
```
Expected: `OK semua SKILL.md frontmatter valid: 13 skill` (11 lama + breakdown + build).

- [ ] **Step 3: Dry-run breakdown (manual, pakai fixture)**

Buat fixture minimal lalu telusuri instruksi `breakdown` secara manual (TIDAK butuh plugin ter-install — ini latihan baca-instruksi):
```bash
mkdir -p /tmp/cv-dryrun/control/features/demo/plans
cat > /tmp/cv-dryrun/control/workspace.yaml <<'YAML'
product: demo
topology: monorepo
apps:
  - { name: api, path: apps/api, type: be, responsibility: "backend", capabilities: [], stack: { framework: Express } }
YAML
cat > /tmp/cv-dryrun/control/features/demo/feature.yaml <<'YAML'
name: demo
status: active
created: 2026-05-30
YAML
printf '# demo\nModel/Schema : Note(id, text)\nAPI/Komponen : POST /notes, GET /notes\nLokasi : apps/api/src/routes/notes\nTest : create note; list notes\n' > /tmp/cv-dryrun/control/features/demo/plans/api.md
echo "fixture siap di /tmp/cv-dryrun"
```
Lalu (sebagai reviewer manusia/agent): baca `plugin/skills/breakdown/SKILL.md` + `reference.md`, dan **tulis tangan** `tasks.yaml` yang DIHARAPKAN untuk fixture ini. Konfirmasi instruksi cukup jelas untuk menghasilkan task ber-`files`/`approach`/`test`, `deps` benar, semua `status: pending`. Catat ambiguitas yang ditemukan; bila ada, perbaiki SKILL.md/reference.md (lalu commit perbaikan).

- [ ] **Step 4: Bersihkan fixture**

Run:
```bash
rm -rf /tmp/cv-dryrun
echo "cleaned"
```

- [ ] **Step 5: Live test (diserahkan ke user — sama seperti skill lain)**

Catat di ringkasan akhir bahwa verifikasi live butuh user:
```
/plugin marketplace add <path repo ini>   (atau update bila sudah ter-add)
/plugin install context-vault
# lalu di sebuah produk ber-control/: /breakdown <fitur> → review tasks.yaml → /build <fitur>
```
Ini konsisten dengan cara skill `discovery` diverifikasi (dry-run di repo; trigger `/plugin install` live oleh user).

- [ ] **Step 6: Commit (bila Step 3 menghasilkan perbaikan)**

```bash
git add -A plugin/skills/breakdown plugin/skills/build
git commit -m "fix(breakdown,build): clarify instructions from dry-run" || echo "no changes to commit"
```

---

## Catatan Eksekusi

- **Branch:** mulai dari branch fitur (mis. `feat/execution-phase`), bukan `main`, kecuali user setuju langsung `main` (repo ini solo & terbiasa commit ke `main` — konfirmasi saat eksekusi).
- **Urutan task:** Task 1→2 (breakdown), 3→4 (build), lalu 5–9 (integrasi, independen satu sama lain), 10 (verifikasi) terakhir. reference (1,3) sebelum SKILL (2,4) karena SKILL menunjuk reference.
- **Skill authoring:** tiap task pembuatan/edit SKILL.md → load `superpowers:writing-skills` (cek kualitas description/trigger, format konsisten dengan skill sibling).
- **Tidak ada perubahan ke `template/`** — fitur ini murni nambah skill di `plugin/skills/` + edit dok.
