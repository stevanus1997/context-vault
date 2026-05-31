# Pipeline Hardening (Structural) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tutup gap *kemampuan* pipeline `feature→breakdown→build→ship` — `tasks.yaml` bisa mewakili kerja non-file & langkah manusia (S1), kontrak lintas-app diuji end-to-end (S2), dan git aman di multi-repo/monorepo (S3).

**Architecture:** "Kode" yang diubah = **file skill markdown** (instruksi yang diikuti AI), bukan kode runtime. Kontraknya adalah skema `tasks.yaml` di `plugin/skills/breakdown/reference.md`; `breakdown` menulisnya, `build` mengeksekusinya, `ship` memverifikasinya — ketiganya harus sepakat. Tiga fase independen-shippable: A (skema + actions/manual/needs_human), B (task integrasi cross-app), C (git cross-repo), D (docs). Verifikasi per task = YAML-lint contoh skema + grep konsistensi + baca-ulang koherensi (bukan unit test — tak ada kode runtime).

**Tech Stack:** Claude Code plugin skills (Markdown), skema YAML, git, `python3 -c "import yaml"` untuk validasi contoh.

**Keputusan terkunci (spec §10):** (1) `install`/`cmd` auto, `migrate` lewat gate; (2) `needs_human` = stop SELURUH build; (3) base-branch = probe runtime; (4) lifecycle pasca-ship = spec terpisah (LUAR scope); (5) provenance = future (LUAR scope).

**Catatan baseline:** quick wins sudah terpasang di branch `pipeline-hardening` (commit-belum). Plan ini menumpuk di atasnya. Semua path relatif ke repo root `/Users/stevanus/Developer/ai-boilerplate`. Plan ini sudah lulus 1 putaran verifikasi adversarial (4 verifier + verdict); 5 defect blocking + NTH terkait sudah dikoreksi di bawah.

**Konvensi anchor (PENTING untuk executor):** banyak file punya >1 blok ```code fence``` dan label section berulang (`approach:`/`status:` muncul di skema §A DAN contoh §C). **Selalu match anchor pakai TEKS unik + section yang disebut, bukan kemunculan pertama / nomor baris.**

---

## FASE A — Skema `tasks.yaml` diperluas (`actions` / `manual` / `needs_human`)

### Task A1: Tambah field baru ke skema `breakdown/reference.md`

**Files:**
- Modify: `plugin/skills/breakdown/reference.md` (§A skema; §B aturan; tambah §D)

- [ ] **Step 1: Tambah `actions` + `manual` + status `needs_human` ke blok skema §A**

Di `plugin/skills/breakdown/reference.md`, **di blok skema §A SAJA** (BUKAN contoh §C yang juga punya `approach:`/`status:`). Match blok multi-baris dari baris placeholder unik:
`        approach: <1-2 baris HOW ringkas; boleh rujuk task lain, mis. "pakai util T1">`
sampai baris:
`        status: pending            # pending | in_progress | done | blocked`
Ganti seluruh blok itu menjadi:

```yaml
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
```

- [ ] **Step 2: Tambah bentuk task integrasi (`app: integration`) di skema §A**

Sisipkan tepat **SETELAH** baris yang baru dibuat di Step 1:
`        status: pending            # pending | in_progress | done | blocked | needs_human`
dan **SEBELUM** ``` penutup blok §A berikutnya. Tambahkan:

```yaml
      # Task integrasi cross-app (lihat §D-3 & spec S2): menjalankan >1 app bareng
      - id: T_INT
        app: integration           # pseudo-app — gate-nya membentang beberapa tree, tak punya path sendiri
        desc: <uji end-to-end flow lintas-app, mis. register via web → user di DB api>
        approach: boot app terkait (path/stack dari workspace.yaml) lalu jalankan flow nyata
        test:
          - <roundtrip nyata; shape data cocok di dua sisi kontrak _shared.md>
        deps: [<id sisi A>, <id sisi B>]   # KEDUA sisi kontrak
        status: pending
```

- [ ] **Step 3: Tambah aturan enrich §B + bagian §D baru**

Di `§B. Aturan granularitas & enrich`, tambah bullet di akhir list (tepat sebelum heading `## C. Contoh`):

```markdown
- **`actions:` untuk kerja non-file.** Migrasi DB, `npm install`, wiring env/secret, perintah infra TIDAK boleh terkubur di `approach` — taruh di `actions:` biar `build` eksekusi & verifikasi eksplisit. `install`/`cmd` auto; `migrate` (destruktif) lewat GATE; `env` ditulis `build` (nilai dari `manual:`/user).
- **`manual:` untuk langkah AI-nggak-bisa.** Bikin OAuth app, set secret produksi, provision DB → daftar di `manual:`; `build` pause (`needs_human`) & lapor checklist.
- **`test:` boleh non-unit.** Untuk task non-unit-testable (config, scaffold, shared types), `test:` boleh berisi kriteria seperti "typecheck hijau"/"build sukses"/"file ada & ke-import"; size-nya "satu artifact koheren".
```

Lalu tambah bagian baru di **akhir file** (setelah §C):

```markdown
## D. Kerja non-file, langkah manual, & task integrasi

1. **`actions` (kerja AI bisa, non-file).** Jenis: `install` (auto), `cmd` (auto), `migrate` (GATE — destruktif), `env` (build tulis ke `.env`). `build` mengeksekusi + memverifikasi tiap action sebagai bagian dari `done`.
2. **`manual` + status `needs_human` (kerja manusia).** Task ber-`manual:` yang belum beres → `build` set `status: needs_human`, **STOP SELURUH build**, lapor checklist; lanjut setelah user beresin. `needs_human` ≠ `blocked` (blocked = ada error/bug; needs_human = bener, nunggu manusia).
3. **Task integrasi (`app: integration`).** Untuk tiap dependency lintas-app di `_shared.md`/`fanout.md`, munculkan SATU task integrasi: `deps` ke KEDUA sisi kontrak, `test` = roundtrip end-to-end nyata. Pseudo-app `integration` tak punya `path`/repo sendiri (jalan di atas repo app-app di `deps`-nya). Fitur 1-app tanpa `_shared.md` → tidak perlu.
```

- [ ] **Step 4: Validasi contoh skema parse sebagai YAML**

Run:
```bash
python3 - <<'PY'
import yaml
doc = yaml.safe_load("""
feature: demo
milestones:
  - id: M1
    title: t
    tasks:
      - id: T1
        app: api
        desc: d
        files: [{create: a.ts}, {test: a.test.ts}]
        actions:
          - install: bcrypt
          - migrate: "tabel User"
          - env: [JWT_SECRET]
        manual: ["bikin OAuth app"]
        approach: x
        test: ["typecheck hijau"]
        deps: []
        status: needs_human
      - id: T2
        app: web
        desc: page
        files: [{create: p.tsx}]
        test: ["render ok"]
        deps: [T1]
        status: pending
      - id: T_INT
        app: integration
        desc: e2e
        test: ["roundtrip cocok dua sisi"]
        deps: [T1, T2]
        status: pending
""")
tasks = doc["milestones"][0]["tasks"]
assert tasks[0]["status"] == "needs_human"
assert tasks[-1]["app"] == "integration" and len(tasks[-1]["deps"]) == 2
print("OK schema parses")
PY
```
Expected: `OK schema parses`

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/breakdown/reference.md
git commit -m "feat(breakdown): schema tasks.yaml — actions/manual/needs_human + task integrasi"
```

---

### Task A2: `breakdown/SKILL.md` — enrich pakai actions/manual + coverage check

**Files:**
- Modify: `plugin/skills/breakdown/SKILL.md` (step 3 enrich; tambah step coverage; renumber)

- [ ] **Step 1: Perluas step 3 (enrich) dengan actions/manual**

Ganti seluruh isi heading `### 3. Enrich tiap task` (dari heading sampai sebelum `### 4.`) menjadi:

```markdown
### 3. Enrich tiap task
Isi tiap task: `files` (path create/modify/test — WHERE), `approach` (1-2 baris HOW ringkas), `test` (daftar kasus yang harus lulus — WHAT). **Kerja non-file** (migrasi DB, `npm install`, wiring env/secret, perintah infra) → taruh di **`actions:`** (jangan kubur di `approach`). **Langkah yang AI nggak bisa** (bikin OAuth app, set secret prod, provision DB) → **`manual:`**. **JANGAN tulis kode implementasi** — itu jatah `build`. `breakdown` **TIDAK** memanggil `writing-plans`. (Skema actions/manual: `reference.md` §A & §D.)
```

- [ ] **Step 2: Tambah step coverage + task integrasi (sisipkan sebagai step 4, geser nomor lama)**

Tepat **SETELAH** heading step 3 yang baru dan **SEBELUM** heading `### 4. Urutan & dependency`, sisipkan:

```markdown
### 4. Coverage check + task integrasi
- **Coverage:** tiap keputusan `_shared.md` ("env yang dibagi", mekanisme) & tiap baris Model/Schema di `plans/<app>.md` HARUS ke-map ke sebuah task/`action`/`manual` — jangan ada yang menguap. Tampilkan peta plan→task di gate.
- **Task integrasi:** untuk tiap dependency lintas-app di `_shared.md`/`fanout.md`, munculkan satu task `app: integration` (`deps` ke KEDUA sisi, `test` = roundtrip end-to-end). Fitur 1-app tanpa `_shared.md` → skip.
```

Lalu **renumber** heading lama dengan mencari TEKS-nya: `### 4. Urutan & dependency` → `### 5. Urutan & dependency`; `### 5. Critic (opsional)` → `### 6. Critic (opsional)`; `### 6. Tulis output (GATE)` → `### 7. Tulis output (GATE)`.

- [ ] **Step 3: Verifikasi tak ada nomor step dobel/lompat**

Run:
```bash
grep -nE '^### [0-9]+\.' plugin/skills/breakdown/SKILL.md
```
Expected: heading berurutan 1,2,3,4,5,6,7 tanpa lompat/dobel.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/breakdown/SKILL.md
git commit -m "feat(breakdown): enrich actions/manual + coverage check + task integrasi"
```

---

### Task A3: `build` — eksekusi & verifikasi `actions`, handle `needs_human`

**Files:**
- Modify: `plugin/skills/build/SKILL.md` (step 2 deteksi, step 3 actions, step 5 status, step 7 guard)
- Modify: `plugin/skills/build/reference.md` (§E status — tambah needs_human + actions)

- [ ] **Step 1: Deteksi `needs_human` pre-dispatch di `build/SKILL.md` step 2**

Di akhir `### 2. Pilih task` (setelah "Ambil task `pending` pertama yang seluruh `deps`-nya `done`."), tambah kalimat:

```markdown
Bila task terpilih punya `manual:` yang belum dikonfirmasi beres → set `status: needs_human`, **STOP SELURUH build**, lapor checklist langkah manual ke user; **jangan dispatch** (hemat ronde implementer). Lanjut setelah user konfirmasi beres.
```

- [ ] **Step 2: Tambah eksekusi actions ke `build/SKILL.md` step 3**

Di akhir `### 3. Dispatch implementer subagent`, tepat **SEBELUM** teks `(Detail rakitan prompt + matrix status balikan:`, sisipkan:

```markdown
**Actions task** (bila ada): `install`/`cmd` → `build` jalanin lalu verifikasi (paket masuk `package.json`, perintah exit 0); **`migrate` → JANGAN auto: tampilkan rencana migrasi + minta approve user dulu** (destruktif), baru apply; `env` → `build` tulis ke `.env` app (nilai dari `manual:`/prompt user). Actions terverifikasi = prasyarat task `done`.
```

- [ ] **Step 3: Tambah handle `needs_human` ke `build/SKILL.md` step 5**

Ganti seluruh isi `### 5. Tandai status` menjadi:

```markdown
### 5. Tandai status
Set `status`: `in_progress` saat mulai, `done` saat lulus DUA review + semua `actions` terverifikasi (atomik — tulis ke `tasks.yaml`). **Task ber-`manual:` belum beres → `needs_human` (sudah dideteksi di step 2: STOP + lapor checklist; bukan `blocked` — ini nunggu manusia, bukan error).** Buntu/error → `blocked`, **STOP**, laporkan (sandar `systematic-debugging`). **JANGAN** tandai `done` palsu.
```

- [ ] **Step 4: Sertakan `needs_human` di hard-guard step 7**

Di `### 7. Selesai`, ganti substring `bila masih ada `pending`/`in_progress`/`blocked`,` menjadi:
`bila masih ada `pending`/`in_progress`/`blocked`/`needs_human`,`

- [ ] **Step 5: Tambah matrix actions + needs_human ke `build/reference.md` §E**

Di **akhir** bagian `## E. Status & resume` (file `build/reference.md`; §E adalah bagian terakhir saat ini), tambah:

```markdown
- **Eksekusi `actions`:** `install`/`cmd` → jalankan + verifikasi (paket/exit-code). `migrate` → **GATE**: tampilkan + approve sebelum apply (destruktif). `env` → tulis ke `.env` app. Semua action terverifikasi = syarat `done`.
- **`needs_human`** (task ber-`manual:` belum beres): dideteksi di step 2 → STOP seluruh build, lapor checklist; resume setelah user konfirmasi langkah manual beres → jalankan `actions` terkait → `in_progress`. Hitung sebagai BELUM siap-ship.
```

- [ ] **Step 6: Verifikasi konsistensi enum status**

Run:
```bash
grep -rn "needs_human" plugin/skills/build plugin/skills/ship plugin/skills/breakdown
```
Expected: muncul di `build/SKILL.md` (step 2,5,7), `build/reference.md` (§E), dan nanti `ship` (Task A4) — tak ada salah ketik (`need_human`/`needshuman`).

- [ ] **Step 7: Commit**

```bash
git add plugin/skills/build/SKILL.md plugin/skills/build/reference.md
git commit -m "feat(build): eksekusi+verifikasi actions (migrate gate), handle needs_human (stop total, deteksi pre-dispatch)"
```

---

### Task A4: `ship` — `needs_human` belum-siap + checklist manual

**Files:**
- Modify: `plugin/skills/ship/SKILL.md` (step 1 cek kesiapan; step 3 checklist)

- [ ] **Step 1: Tambah `needs_human` di cek kesiapan step 1 — TANPA hapus catch-all**

Di `### 1. Baca fitur & cek kesiapan`, ganti substring `(`pending`/`in_progress`/`blocked`/status belum-selesai lain)` menjadi:
`(`pending`/`in_progress`/`blocked`/`needs_human`/status belum-selesai lain)`

(PENTING: `needs_human` jadi eksplisit TAPI `status belum-selesai lain` TETAP ADA — jangan persempit guard.)

- [ ] **Step 2: Tambah `manual:` outstanding ke Challenge Checklist**

Di heading Challenge Checklist `ship` (cari TEKS heading "Challenge Checklist (WAJIB sebelum ship)"), tambah bullet di akhir list-nya:
```markdown
- Ada langkah `manual:` (`tasks.yaml`) yang belum dikonfirmasi beres? (env/secret/OAuth app prod)
```

- [ ] **Step 3: Verifikasi**

Run:
```bash
grep -n "needs_human\|status belum-selesai lain\|manual:" plugin/skills/ship/SKILL.md
```
Expected: step 1 punya `needs_human` DAN `status belum-selesai lain`; Challenge Checklist punya `manual:`.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/ship/SKILL.md
git commit -m "feat(ship): needs_human dihitung belum-siap (catch-all tetap) + checklist langkah manual"
```

---

## FASE B — Task integrasi cross-app (eksekusi di build & ship)

> Skema `app: integration` & aturan emisi sudah di Fase A (Task A1 step 2, A2 step 2). Fase B = cara MENJALANKANNYA.

### Task B1: `build` — jalankan task `app: integration` (boot multi-app)

**Files:**
- Modify: `plugin/skills/build/SKILL.md` (step 3 cabang; step 4 verify; step 6 gate)
- Modify: `plugin/skills/build/reference.md` (§B dispatch)

- [ ] **Step 1: Tambah cabang integration di `build/SKILL.md` step 3**

Di **awal** isi `### 3. Dispatch implementer subagent` (sebelum "Rakit prompt LENGKAP..."), sisipkan:

```markdown
**Bila `app: integration`:** ini BUKAN edit satu app — dispatch subagent yang mem-boot app-app di `deps` (pakai `path`/`stack` `workspace.yaml`), jalankan `test` roundtrip nyata terhadap kontrak `_shared.md`, balik ringkasan + status. Gate-nya (step 6) membentang tree app-app terkait, bukan satu app.
```

- [ ] **Step 2: Special-case `app: integration` di step 4 (verify) & step 6 (gate)**

Di `build/SKILL.md` **step 4** (`### 4. Verifikasi + Review 2-tahap`), di awal paragraf verify, tambah kalimat:
```markdown
Untuk task `app: integration`: verify = commit maju di SETIAP repo app yang ada di `deps` + jalankan ulang `test` roundtrip (bukan satu "test app" tunggal).
```
Di `build/SKILL.md` **step 6** (`### 6. Gate per segmen (mode A adaptif)`), tambah kalimat:
```markdown
Task `app: integration` membentuk segmen gate sendiri yang membentang tree app-app di `deps`-nya (bukan satu app × milestone).
```

- [ ] **Step 3: Tambah panduan dispatch integration di `build/reference.md` §B**

Tepat **SEBELUM** heading `## C. Pilih model (hemat biaya & cepat)`, tambah:

```markdown
### Task integrasi (`app: integration`)
Controller merakit prompt: app mana yang di-boot (path/stack dari `workspace.yaml`), kontrak `_shared.md` yang diuji, kasus `test` roundtrip. Subagent menjalankan kedua app bareng (mis. start `api`, panggil dari `web`/HTTP), assert shape data cocok dua sisi. Status sama (DONE/BLOCKED/...). Konteks berat (boot+log) tetap di subagent.
```

- [ ] **Step 4: Verifikasi**

Run:
```bash
grep -n "app: integration\|integration" plugin/skills/build/SKILL.md plugin/skills/build/reference.md
```
Expected: cabang integration di SKILL **step 3, step 4, step 6** + reference §B.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/build/SKILL.md plugin/skills/build/reference.md
git commit -m "feat(build): jalankan task app:integration (boot multi-app, gate & verify khusus)"
```

---

### Task B2: `ship` — step integrasi cross-app sebelum PR

**Files:**
- Modify: `plugin/skills/ship/SKILL.md` (sisipkan step integrasi; renumber by text)

- [ ] **Step 1: Tambah step integrasi (sisip by heading TEXT, renumber by text)**

Cari heading TEKS `### 2. Per app yang kena` dan `### 3. Challenge Checklist` (JANGAN pakai nomor baris). Sisipkan **di antara akhir isi step 2 dan heading Challenge Checklist** step baru:

```markdown
### 3. Integrasi cross-app (bila fitur >1 app + ada `_shared.md`)
Boot app-app terkait bareng (path/stack `workspace.yaml`), jalankan contract/smoke test terhadap flow bersama (mis. login web↔api): cookie/format token/shape JSON cocok dua sisi. Gagal → STOP, jangan ship. (Loop per-app di step 2 hanya app NYATA dari `fanout.md`; roundtrip integrasi ditangani khusus oleh step ini. Fitur 1-app → lewati.)
```

Lalu **renumber by text**: `### 3. Challenge Checklist...` (yang sudah diisi bullet `manual:` oleh Task A4) → `### 4.`; `### 4. Putuskan` → `### 5.`; `### 5. Kirim & tandai (GATE)` → `### 6.`.

- [ ] **Step 2: Verifikasi penomoran**

Run:
```bash
grep -nE '^### [0-9]+\.' plugin/skills/ship/SKILL.md
```
Expected: 1..6 berurutan tanpa lompat/dobel (tak ada dua `### 3.`).

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/ship/SKILL.md
git commit -m "feat(ship): step integrasi cross-app sebelum PR"
```

---

## FASE C — Model git cross-repo (probe + branch/PR per repo)

### Task C1: `build` — probe repo + branch fitur per repo

**Files:**
- Modify: `plugin/skills/build/SKILL.md` (step 1 — ganti branch-check cwd jadi per-repo)
- Modify: `plugin/skills/build/reference.md` (tambah §F multi-repo)

- [ ] **Step 1: Ganti bullet "Cek branch git" di `build/SKILL.md` step 1**

Cari bullet yang diawali `- **Cek branch git** — kalau di `main`/`master`` dan ganti SELURUH bullet itu menjadi:

```markdown
- **Branch per repo (multi-repo aware):** untuk tiap app NYATA yang kena (dari `tasks.yaml`/`fanout.md`, **KECUALI pseudo-app `integration`** yang tak punya `path` sendiri), resolve `path` dari `workspace.yaml` lalu probe `git -C <path> rev-parse --show-toplevel`. Kelompokkan app per **repo unik** (toplevel sama = satu repo; monorepo/nested otomatis ciut). Untuk tiap repo unik: cek branch — kalau di `main`/`master`, minta izin lalu `git -C <path> checkout -b feature/<fitur>` (atau checkout bila sudah ada). **Jangan commit di `main`/`master` tanpa izin.** Probe error (belum git) → minta user init / skip git. (Detail: `reference.md` §F.)
```

- [ ] **Step 2: Tambah §F ke `build/reference.md` (akhir file)**

Di **akhir file** `build/reference.md` (setelah §E yang baru diperluas Task A3), tambah:

```markdown
## F. Multi-repo (probe & branch)

Probe identitas repo tiap app NYATA: `git -C <path> rev-parse --show-toplevel`.
- `toplevel(app) == toplevel(hub)` atau antar-app sama → **SAMA repo** (monorepo/nested) → satu branch `feature/<fitur>`, nanti 1 PR.
- `toplevel(app) != toplevel(hub)` → **repo TERPISAH** → branch `feature/<fitur>` sendiri per repo, nanti PR sendiri.
- probe error → belum git repo → minta user `git init`/skip.

Implementer subagent commit di repo app-nya (`git -C <path>`). `build` memastikan branch ada SEBELUM dispatch task yang nulis ke repo itu. **Pseudo-app `integration` dilewati** saat probe/branch (tak punya `path`/repo sendiri); ia jalan di atas repo app-app di `deps`-nya yang branch-nya sudah dibuat. Eksekusi tetap sekuensial sesuai `deps` (tak ada dua subagent nulis tree sama serempak).
```

- [ ] **Step 3: Verifikasi**

Run:
```bash
grep -n "show-toplevel\|feature/<fitur>\|repo unik" plugin/skills/build/SKILL.md plugin/skills/build/reference.md
```
Expected: muncul di SKILL step 1 + reference §F.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/build/SKILL.md plugin/skills/build/reference.md
git commit -m "feat(build): branch fitur per repo + probe toplevel (multi-repo aware, integration dikecualikan)"
```

---

### Task C2: `ship` — PR per repo unik berbasis probe

**Files:**
- Modify: `plugin/skills/ship/SKILL.md` (step "Kirim & tandai" — kini step 6 setelah B2 renumber — PR per repo unik)

- [ ] **Step 1: Ganti aturan PR di step "Kirim & tandai (GATE)"**

Cari bullet yang diawali `- Bikin PR: **multi-repo → satu PR per app yang kena**` (di dalam heading "Kirim & tandai (GATE)", step 6 setelah renumber B2) dan ganti SELURUH bullet menjadi:

```markdown
- Tentukan **repo unik** yang kena: probe `git -C <path> rev-parse --show-toplevel` tiap app NYATA, kelompokkan per toplevel. Bikin **satu PR per repo unik** (monorepo/nested → otomatis 1 PR karena toplevel sama; multi-repo → 1 PR per repo). Base = hasil deteksi `symbolic-ref` (di code-review step). Pakai `gh pr create`; bila `gh`/remote tak ada, tampilkan deskripsi PR untuk dibuat user.
```

- [ ] **Step 2: Verifikasi**

Run:
```bash
grep -n "repo unik\|show-toplevel\|symbolic-ref" plugin/skills/ship/SKILL.md
```
Expected: code-review step (base detect, dari quick win) + step "Kirim & tandai" (PR per repo unik).

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/ship/SKILL.md
git commit -m "feat(ship): PR per repo unik via probe toplevel + base symbolic-ref"
```

---

## FASE D — Dokumentasi

### Task D1: Update README + plugin.json description

**Files:**
- Modify: `README.md`
- Modify: `plugin/.claude-plugin/plugin.json`

- [ ] **Step 1: Tambah catatan kapabilitas baru di README**

Cari paragraf bagian "Bikin fitur" yang menyebut `/build` (baris yang berisi "implementer subagent per task (TDD)"). Tepat **setelah blok kode** bagian itu (sebelum heading `## Selesai & lifecycle`), tambah baris:

```markdown
> `breakdown` kini bisa wakili kerja non-file (`actions:` migrate/install/env) & langkah manusia (`manual:`/status `needs_human`); `build` jalanin+verifikasi actions (migrasi lewat gate) dan uji integrasi cross-app; `build`/`ship` sadar multi-repo (branch & PR per repo).
```

- [ ] **Step 2: Sesuaikan deskripsi plugin.json bila menyebut kapabilitas skill**

Run untuk lihat deskripsi sekarang:
```bash
grep -n "description" plugin/.claude-plugin/plugin.json
```
Bila `description` menyebut breakdown/build, tambah frasa "actions/manual + integrasi cross-app + multi-repo aware". Bila tidak menyebut detail skill, biarkan (jangan paksa).

- [ ] **Step 3: Commit**

```bash
git add README.md plugin/.claude-plugin/plugin.json
git commit -m "docs: catat actions/manual, integrasi cross-app, multi-repo di README + plugin.json"
```

---

## Self-Review (penulis plan) + status verifikasi

**Spec coverage:** S1 → A1-A4 ✓; S2 → A1/A2 (skema+emisi) + B1/B2 (eksekusi) ✓; S3 → C1 (build) + C2 (ship), base-detect = quick win ✓; S4.1/S4.2 LUAR scope (§10-4/5) ✓. Keputusan §10-1 (migrate gate) → A3 ✓; §10-2 (stop total + deteksi pre-dispatch) → A3 step1/3 ✓; §10-3 (probe runtime) → C1/C2 ✓.

**Verifikasi adversarial (1 putaran, 4 verifier + verdict) — 5 blocking sudah dikoreksi:**
1. C1 phantom app → step 1 & §F kini **kecualikan `integration`** dari probe path. ✓
2. B1 step 4/6 kontradiksi → ditambah **B1 Step 2** yang patch step 4 (verify per-repo + roundtrip) & step 6 (segmen gate sendiri). ✓
3. A4 hapus catch-all → A4 step 1 kini **pertahankan `status belum-selesai lain`**. ✓
4. A1 step 1 anchor ambigu → kini eksplisit **§A SAJA, bukan §C**, match baris placeholder unik. ✓
5. A1 step 2 fence ambigu → kini anchor pada **baris status `…| needs_human`** (bukan bare fence). ✓

**NTH terakomodasi:** A1 step4 YAML kini 2 `deps` di T_INT; B2 sisip+renumber by TEXT + klarifikasi loop per-app = app nyata; C2 prosa step→"Kirim & tandai" (bukan "step 5"); B1 step3 & C1 step2 pakai boundary line konkret (`## C.`, akhir file); A3 deteksi `needs_human` pindah ke **step 2 (pre-dispatch)** sesuai spec S1.3. Token `feature/<fitur>` dipakai seragam di plan (spec pakai `<nama>` — sinonim, sengaja).

**Catatan eksekusi:** edit skill markdown (bukan kode) → "test" = YAML-lint (A1 step4) + grep konsistensi + baca-ulang. Tiap task = commit terpisah → resumable & gampang di-review.
