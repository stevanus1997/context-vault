# context-vault — Pengerasan Pipeline Eksekusi (Structural Design Spec)

- **Tanggal:** 2026-05-31
- **Status:** Draft — menunggu approve user (lihat §10 Open Questions dulu)
- **Terkait:** spec induk `2026-05-24-ai-first-boilerplate-design.md` + spec fase eksekusi `2026-05-29-breakdown-build-execution-phase-design.md` (ini melanjutkan keduanya)
- **Sumber:** audit adversarial pipeline `feature → breakdown → build → ship` (2026-05-31): 47 temuan diangkat, 40 terkonfirmasi. Quick wins (reliability) sudah dikerjakan di branch `pipeline-hardening`; spec ini menutup gap **kemampuan (capability)** yang butuh keputusan desain.

---

## 1. Ringkasan

Quick wins membuat pipeline **andal** untuk yang sudah diklaim (resume nggak ilang state, ship nggak ngirim setengah jadi, review nggak loop selamanya). Spec ini membuat pipeline **mampu** mewakili & menjalankan kerja produk NYATA. Tiga perubahan struktural (semua menyentuh ≥2 skill yang harus sepakat, makanya butuh spec):

- **S1 — Schema `tasks.yaml` diperluas:** `actions:` (kerja non-file: migrate/install/env/config/cmd), `manual:` (langkah yang AI nggak bisa), dan status task baru `needs_human` (beda dari `blocked`).
- **S2 — Task integrasi cross-app:** `breakdown` memunculkan task integrasi per kontrak `_shared.md`; `build` & `ship` menjalankan uji end-to-end yang menjalankan banyak app **bareng** (bukan tiap app sendiri-sendiri).
- **S3 — Model git cross-repo:** `build` bikin/verifikasi branch fitur **per repo terkena**; `ship` deteksi base-branch & buka PR **per repo**; probe `git rev-parse --show-toplevel` membedakan multi-repo / monorepo / nested / non-repo.

Plus **S4 (sebagian future)**: lifecycle pasca-`shipped`, provenance task→plan untuk staleness presisi, blast-radius shared-package.

**Prinsip:** semua dibangun **di atas** quick wins (forward-compatible), tetap di bawah gate + anti-yes-man, tetap handoff lewat file `control/`, tetap resumable & hemat konteks.

## 2. Masalah (dari audit)

- **C-schema:** schema task cuma bisa wakili "edit file + unit test". Migrasi DB, `npm install`, wiring env/secret, dan **langkah manusia** (bikin OAuth app, set secret prod, provision DB) nggak punya slot → kebawa prosa `approach` → di-skip TDD implementer (nggak ada test merah yang maksa) → fitur ke-ship tapi mati di fresh checkout. Status "nyangkut" satu-satunya (`blocked`) salah semantik untuk "benar tapi nunggu manusia".
- **C-integrasi:** tiap task punya tepat 1 `app`; gate per-app; `ship` quality per-app. **Nggak ada yang pernah jalanin `web` lawan `api` beneran.** Mismatch kontrak (nama cookie, shape JSON, mekanisme token) lolos semua gate hijau → jebol di produksi. Ini gap paling bahaya untuk use-case multi-app — alasan utama pipeline ini ada.
- **C-git:** `build` cek branch di cwd (repo hub), padahal subagent commit ke repo app (`../api`, `../web`) → commit nyasar ke `main` tiap app, tanpa branch buat di-PR. `ship` pakai `<base-branch>` placeholder literal. Tipe repo (multi/mono/nested/non-git) dicampur buta.

## 3. Tujuan & Non-Tujuan

**Tujuan:**
- `tasks.yaml` bisa mewakili **seluruh** kerja sebuah fitur: kode + infra + langkah manusia.
- Kontrak lintas-app diuji **end-to-end** sebelum ship, bukan diasumsikan dari unit test per app.
- `build`/`ship` **sadar batas repo** — aman untuk monorepo & multi-repo tanpa nyasar ke `main`.
- Tetap selaras prinsip: gate, anti-yes-man, handoff file, sesi terpisah, resumable, hemat konteks.

**Non-Tujuan (v1 structural):**
- Eksekusi paralel lintas-app via worktree (tetap sekuensial sesuai `deps` — future, warisan spec induk §16).
- Orchestrator/CI deploy & rollback otomatis (lihat S4 — di luar scope).
- Mengubah model status fitur jadi granular (tetap kasar; `needs_human` adalah status **task** di `tasks.yaml`, BUKAN status fitur di `feature.yaml`).

---

## S1. Schema `tasks.yaml` Diperluas

### S1.1 Field baru

```yaml
- id: T1
  app: api
  desc: User model + util hashing
  files:                          # WHERE (tetap) — kerja yang ngedit file sumber
    - create: src/lib/hash.ts
    - test:   test/lib/hash.test.ts
  actions:                        # BARU — kerja non-file yang AI BISA jalanin sendiri
    - install: bcrypt             #   → build jalanin `npm install`, verifikasi ada di package.json
    - migrate: "tabel User(email unik, passwordHash)"   # → DESTRUKTIF: selalu lewat gate sebelum apply (§10-1)
    - env:     [JWT_SECRET]       #   → build tulis ke .env (nilai dari manual:/prompt)
    - cmd:     "npx prisma generate"   # escape hatch perintah lain
  manual:                         # BARU — langkah yang AI NGGAK BISA (butuh manusia)
    - "Set JWT_SECRET di .env (generate rahasia 32-byte)"
  approach: bcrypt cost 12
  test: [hash↔verify ok, email dup ditolak DB]
  deps: []
  status: pending                 # pending | in_progress | done | blocked | needs_human  ← +needs_human
```

- **`actions:`** — daftar operasi non-file, ber-tag jenis. `build` **mengeksekusi + memverifikasi** tiap action sebagai bagian dari `done` (mis. cek paket masuk `package.json`, migration apply tanpa error). Bikin migrasi/install/env **eksplisit & bisa dicek**, bukan terkubur prosa.
- **`manual:`** — daftar **apa** yang manusia harus kerjain (deskripsi). Ditampilkan di gate `build` & di laporan "siap di-ship" sebagai checklist.
- **`needs_human`** (status task) — task yang **nyangkut nunggu** item `manual:` beres. Beda dari `blocked` (= ada yang error, sandar `systematic-debugging`); `needs_human` = "kodenya bener, giliran manusia" → `build` **pause sopan & lapor**, bukan treat sebagai kegagalan.

### S1.2 `test:` untuk kerja non-unit-testable

Aturan "satu task = unit testable terkecil" dilonggarkan: `test:` boleh memuat **kriteria verifikasi non-unit** (mis. "typecheck hijau", "build sukses", "migration apply bersih", "file ada & ke-import"), dan task semacam itu di-size sebagai "satu artifact koheren". Menutup kasus config/scaffold/shared-types yang sekarang maksa AI bikin test hampa.

### S1.3 Alur `build` dengan `needs_human`

1. Pilih task `pending` yang `deps`-nya `done`.
2. Bila task punya `manual:` yang belum beres → set `needs_human`, **pause SELURUH build** (§10-2: stop total), lapor checklist ke user; lanjut setelah user beresin.
3. User kasih nilai/konfirmasi → `build` jalanin `actions` terkait (mis. tulis `env`) → status balik `in_progress` → lanjut normal.
4. Hard guard step 7 & cek kesiapan `ship` (quick win) **diperluas**: `needs_human` juga = belum siap ship.

### S1.4 Skill yang berubah

- **`breakdown`** (`reference.md` skema + SKILL step 3 enrich): tambah `actions`/`manual`; tiap keputusan `_shared.md` "env dibagi" & tiap baris Model/Schema plan **wajib** jadi action/task (coverage check — lihat S4.2).
- **`build`** (SKILL step 3-5 + `reference.md` §B/§E): eksekusi+verifikasi `actions`; handle `needs_human` (pause/resume); matrix status sudah ada dari quick win.
- **`ship`** (step 1 + Challenge): `needs_human` dihitung belum-siap; `manual:` yang belum beres muncul di checklist.
- **`render-docs`** (opsional): boleh nampilin item `manual:` outstanding.

---

## S2. Task Integrasi Cross-App

### S2.1 Konsep

`breakdown` memunculkan **task integrasi** untuk tiap dependency lintas-app yang disebut `_shared.md`/`fanout.md`:

```yaml
- id: T_INT
  app: integration              # pseudo-app — gate-nya membentang dua tree
  desc: E2E register→login dari web ke api beneran
  deps: [T6, T3]                # kedua sisi kontrak
  test:
    - register via web → user kebuat di DB api
    - login → cookie session valid roundtrip, shape JSON cocok dua sisi
  status: pending
```

- **`app: integration`** = pseudo-app; `build` menjalankannya dengan **mem-boot app-app terkait** (sesuai `path`/`stack`) lalu uji flow nyata. Gate-nya membentang dua tree (bukan satu app).
- Default: 1 task integrasi per kontrak `_shared.md`. Untuk fitur 1-app tanpa `_shared.md` → tidak ada (nggak maksa overhead).

### S2.2 `ship` step integrasi

Setelah loop quality per-app, bila fitur menyentuh >1 app dengan `_shared.md`: tambah **step integrasi** — boot app-app terkait / jalanin contract atau smoke test terhadap flow bersama, SEBELUM challenge checklist. (Plus typecheck app konsumen shared-package — lihat S4.3.)

### S2.3 Skill yang berubah

- **`breakdown`**: aturan "munculkan task integrasi per kontrak `_shared.md`" + `app: integration` di skema.
- **`build`**: cara dispatch/menjalankan task `integration` (boot multi-app); gate-nya membentang banyak tree.
- **`ship`**: step integrasi cross-app sebelum PR.

---

## S3. Model Git Cross-Repo

### S3.1 Probe identitas repo

Kunci: untuk tiap app dari `workspace.yaml`, jalankan `git -C <path> rev-parse --show-toplevel`. Bandingkan toplevel:

| Hasil | Arti | Aksi |
|---|---|---|
| `toplevel(app) != toplevel(hub)` | repo TERPISAH (multi-repo) | branch sendiri + PR sendiri |
| `toplevel(app) == toplevel(hub)` atau antar-app sama | SAMA repo (monorepo/nested) | 1 branch, 1 PR bareng |
| probe error | belum git repo | init dulu / minta user / skip git |

### S3.2 `build` — branch guard per repo

Sebelum dispatch task apa pun yang nulis ke sebuah app: resolve `path` app, probe, **kelompokin app per repo unik**. Untuk tiap repo unik yang kena fitur, cek/bikin branch `feature/<nama>` (`git -C <path> checkout -b feature/<nama>`, atau checkout bila sudah ada). **Jangan commit di `main`/`master` repo mana pun tanpa izin.** (Mengganti branch-check cwd-only yang lama.)

### S3.3 `ship` — base-branch & PR per repo

- Deteksi base per repo: `git -C <path> symbolic-ref refs/remotes/origin/HEAD` (sudah jadi quick win di `ship` step 2). Diff `feature/<nama>` lawan base itu.
- PR per **repo unik** (bukan per app) — bikin aturan lama "multi-repo → 1 PR/app, monorepo → 1 PR" jadi grounded ke identitas repo asli: monorepo otomatis ciut jadi 1 PR karena toplevel-nya sama.

### S3.4 (Opsional) `default_branch` per app di `workspace.yaml`

Keputusan §10-3: **probe runtime** (`ship` step 2 quick win) jadi default. Merekam `default_branch` per app saat `architect` = **future** (deterministik tapi nambah field).

### S3.5 Skill yang berubah

- **`build`** (SKILL step 1): branch guard per-repo + probe.
- **`ship`** (step 2 & 5): PR per repo unik berbasis probe.
- **`architect`** (opsional): rekam `default_branch`.

---

## S4. Scoped / Sebagian Future

- **S4.1 Lifecycle pasca-`shipped`** (§10-4: **spec TERPISAH**, di luar scope ini): jalur iterasi v2/bugfix dari fitur `shipped` (mis. folder `<nama>-v2` di-seed dari fitur lama; folder lama immutable sebagai memori). Plus klarifikasi `shipped` = **PR dibuka**, bukan merged/live; rollback/hotfix nyandar ke jalur ini. `drop` pada fitur ber-`tasks.yaml` menstempel `tasks.yaml` terminal.
- **S4.2 Provenance task→plan (staleness presisi):** tiap task simpan `provenance:` (section plan/`_shared` asalnya). Saat regenerate, **re-pending HANYA** task `done` yang section asalnya berubah (bukan blanket). Menggantikan staleness check mtime kasar (quick win) dengan presisi. — kandidat v1 kalau murah.
- **S4.3 Blast-radius shared-package:** `fanout` enumerasi app konsumen shared-package yang berubah (dari deps/imports `workspace.yaml`) sebagai "perlu re-verify"; `ship` ikut build/typecheck mereka. Butuh representasi dependency antar-app di `workspace.yaml` yang mungkin belum ada. — kandidat future.

---

## §5. Dampak ke Komponen Existing

| Komponen | Perubahan |
|---|---|
| `breakdown/reference.md` | skema: `actions`, `manual`, status `needs_human`, `app: integration`, (`provenance`) |
| `breakdown/SKILL.md` | enrich dgn actions/manual; coverage check; munculkan task integrasi |
| `build/SKILL.md` + `reference.md` | eksekusi+verifikasi actions; handle `needs_human`; jalankan task integrasi; branch per-repo + probe |
| `ship/SKILL.md` | `needs_human` belum-siap; step integrasi cross-app; PR per repo unik |
| `architect/SKILL.md` | (opsional) rekam `default_branch` per app |
| `render-docs` | (opsional) tampilkan `manual:` outstanding & progres |
| `plugin/.claude-plugin/plugin.json` | deskripsi (kapabilitas baru) |
| `README.md` | catat actions/manual + integrasi cross-app + git multi-repo |

## §6. Hubungan dengan Quick Wins (branch `pipeline-hardening`)

Structural ini **dibangun di atas**, tidak membatalkan, quick wins:
- Quick win `build` step 1 staleness mtime → dipertajam S4.2 (provenance).
- Quick win `breakdown` step 6 "pertahankan status" → fondasi merge S4.2.
- Quick win `ship` base-branch detection → dipakai utuh oleh S3.3.
- Quick win matrix status balikan subagent → tetap; `needs_human` (S1) adalah status **task**, terpisah.
- Quick win hard-guard all-done (`build` step 7) & cek kesiapan `ship` → diperluas: `needs_human` juga = belum siap.

## §7. Scope v1 vs Future

- **v1 (rekomendasi in):** S1 (schema actions/manual/needs_human), S2 (task integrasi + step ship), S3 (git cross-repo). Opsional: S4.2 (provenance) bila murah.
- **Future:** S4.1 (lifecycle pasca-ship), S4.3 (blast-radius), eksekusi paralel worktree, deploy/rollback.

---

## §10. Keputusan (terkunci 2026-05-31)

1. **`actions` eksekusi:** `install`/`cmd` dijalanin `build` otomatis lalu diverifikasi; **`migrate` (destruktif) SELALU lewat gate** — tampilkan + minta approve sebelum apply.
2. **`needs_human`:** **stop SELURUH build** sampai user beresin langkah `manual:`, baru lanjut (bukan lanjut task independen). Lebih simpel & predictable.
3. **Base-branch:** **probe runtime** (`ship` step 2). Merekam `default_branch` per app di `workspace.yaml` saat `architect` = **future**.
4. **Lifecycle pasca-ship (S4.1):** **spec TERPISAH** — di luar scope spec ini (status-machine yang membentang `feature`/`ship`/`drop`/`render-docs`).
5. **S4.2 provenance:** **future** — quick-win staleness mtime sudah nutup kasus dasar; jaga scope v1 fokus ke S1/S2/S3.
