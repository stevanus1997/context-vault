# Lane Utang Teknis (Pintu ke-4 `build`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tambah pintu ke-4 `build` untuk tech debt out-of-scope — debt jadi warga kelas-satu (registry `control/debt.yaml`, status diturunkan) yang ditangkap murah saat `build` (atau STOP-decide-now bila fondasional) dan di-resurface by locality lewat `plan`/`fix` + jaring `render-docs`, dikelola skill tipis baru `/debt`.

**Architecture:** Semua artifact = dokumen plugin (SKILL.md markdown, rule markdown, YAML template, JSON manifest) — TIDAK ada kode runtime. Implementasi = (1) bikin 3 artifact baru (template `control/debt.yaml`, rule `debt-aware.md`, skill `/debt`); (2) sisipkan perilaku ke 5 skill existing (`build` pintu ke-4, `breakdown` `kind: debt`, `plan`+`fix` debt-aware, `render-docs` Known Issues, `ask` tabel klasifikasi) — semua **rider** pada perilaku yang sudah ada, bukan langkah baru yang berdiri sendiri; (3) registrasi (manifest + README + induk). "Test" = verifikasi struktural (frontmatter valid, `name`==dir, section wajib ada, JSON manifest valid, hitungan skill konsisten) — artifact-nya dokumen, bukan kode eksekusi (pola sama plan skill `ask`/`fix`).

**Tech Stack:** Markdown (SKILL.md + frontmatter YAML, rules), YAML (`control/debt.yaml` template), JSON (`plugin.json`, `marketplace.json`), `python3` (validator JSON, sudah ada di macOS), `grep`/`git`.

**Referensi spec:** `docs/superpowers/specs/2026-06-04-utang-teknis-flow-design.md` (§4 capture, §5 registry+status, §6 resurface/debt-aware, §7 skill `/debt`, §8 guardrails, §10 dampak komponen).

**Catatan dependency antar-task:** T1→T3 (skill `/debt` baca schema), T2→T6/T7 (`plan`/`fix` rujuk rule), T4→T5/T6/T7 (`kind: debt` dikenali sebelum yang menulisnya). Urutan di bawah sudah topologis — kerjakan berurutan; tiap task meninggalkan repo koheren.

---

### Task 1: Template `control/debt.yaml`

**Files:**
- Create: `plugin/template/control/debt.yaml`

Artifact registry. Lahir kosong + komentar penjelas (pola sama `plugin/template/control/integrations.md` & `invariants.md`: blok komentar = kontrak + ownership + bentuk entri, lalu data kosong).

- [ ] **Step 1: Tulis file lengkap**

Buat `plugin/template/control/debt.yaml` dengan isi PERSIS berikut:

```yaml
# <PRODUCT> — Registry Utang Teknis (Tech Debt)
#
# Rumah debt: hal yang secara arsitektur menyusahkan tapi SEKARANG masih benar
# (bukan defect → itu control/fixes/ lewat /fix; bukan kapabilitas baru → itu /feature).
# Pasif sampai ditarik. Pemilik schema = skill /debt. `build` APPEND entri `open`
# saat menemukannya (pintu ke-4); `/debt drop` menulis penanda `dropped`. Tak ada penulis lain.
# Dibaca: plan & fix (rules/debt-aware.md — by area), render-docs (Known Issues), ask.
#
# Status TIDAK ditulis tangan — DITURUNKAN (status-as-byproduct):
#   open      = tak ada task `pays_debt: <id>` aktif; dan `dropped` kosong
#   scheduled = ada task `pays_debt: <id>` pending/in_progress di host (feature/fix) aktif
#   shipped   = task `pays_debt: <id>` ada di feature/fix yang manifest-nya sudah shipped
#   dropped   = field `dropped` terisi (dari /debt drop)
#
# Belum ada utang — daftar tumbuh just-in-time lewat `build` (pintu ke-4) / `/debt`.
#
# Bentuk tiap entri (ditambah build/`/debt`):
#
#   - id: <area-slug>            # mis. api-cart-nplus1 — deterministik (area + ringkas observed); basis dedup
#     area: <app/module>         # taksonomi sama fanout/workspace.yaml.capabilities — basis matching plan/fix
#     owner: feature             # feature (kode app) | foundation (stack/convention/package/integration)
#     observed: "<apa yang jelek, 1 baris>"
#     why_drag: "<kenapa ini drag nyata, bukan selera>"   # wajib — saring preferensi
#     severity: normal           # normal | high  (high khas fondasional; urutan render-docs)
#     discovered_during: <feature/fix id>   # konteks asal saat build menemukannya
#     discovered_at: <YYYY-MM-DD>
#     dropped: null              # {at: <YYYY-MM-DD>, reason: "<...>"} — HANYA diisi /debt drop

debt: []
```

- [ ] **Step 2: Verifikasi struktur template**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
python3 - <<'PY'
import pathlib, re
t = pathlib.Path("plugin/template/control/debt.yaml").read_text()
assert t.rstrip().endswith("debt: []"), "harus diakhiri root list kosong `debt: []`"
for k in ["status-as-byproduct", "Pemilik schema = skill /debt", "pays_debt", "owner: feature"]:
    assert k in t, f"komentar kontrak hilang: {k}"
# tak boleh ada field status: tertulis tangan di contoh
assert re.search(r"^\s*status:", t, re.M) is None, "JANGAN tulis field status: (diturunkan)"
print("OK: template debt.yaml valid (kontrak lengkap, root kosong, tanpa field status manual)")
PY
```
Expected: `OK: template debt.yaml valid (kontrak lengkap, root kosong, tanpa field status manual)`

- [ ] **Step 3: Commit**

```bash
git add plugin/template/control/debt.yaml
git commit -m "feat(debt): template control/debt.yaml — registry utang teknis (status diturunkan)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Rule `plugin/rules/debt-aware.md`

**Files:**
- Create: `plugin/rules/debt-aware.md`

Aturan share (ditulis sekali, dirujuk `plan`+`fix` di T6/T7) — meniru gaya `plugin/rules/anti-yes-man.md` (judul + prosa bullet ringkas).

- [ ] **Step 1: Tulis file lengkap**

Buat `plugin/rules/debt-aware.md` dengan isi PERSIS berikut:

```markdown
# Debt-Aware — Resurface Utang Teknis by Locality (aturan share)

Dirujuk skill yang menetapkan SCOPE kerjaan di sebuah area kode (`plan`, `fix`). **BUKAN langkah baru** yang berdiri sendiri — ia **rider** pada read kode-per-area yang skill itu sudah lakukan. Tujuan: utang teknis di `control/debt.yaml` dilunasi **di tempat ia mengganggu**, tanpa nyangkut selamanya.

## Kontrak
- **Sebelum mulai kerja di area X**, baca `control/debt.yaml`; saring entri yang `area`-nya beririsan dengan footprint X (app/module yang akan disentuh).
- Ambil yang berstatus **`open`** (status diturunkan — lihat header `control/debt.yaml`).
- Untuk tiap utang `open` di area itu, **tawarkan melunasi di gate** skill ini: *"area ini punya N utang open: `<ringkas observed>`. Lipat ke kerjaan ini? (+N task)"*
- **Setuju** → buat task `kind: debt, pays_debt: <id>` (refactor — jaga perilaku TETAP sama, test regresi hijau; BUKAN ubah perilaku) di `tasks.yaml` host. **Tidak** → biarkan `open` (tetap muncul di render-docs "Known Issues" — tak hilang).

## Batas
- **Owner-aware.** Hanya tangani utang `owner: feature` (kode app). Utang `owner: foundation` (stack/convention/package/integration) **bukan** jatah `plan`/`fix` — itu sudah diputus saat capture (decide-now di `build`) & di-resurface saat skill fondasi (`architect`/`add-*`/`wire`) berjalan.
- **Bukan auto-fix.** Menawarkan, bukan memaksa. Pelunasan selalu lewat gate / persetujuan eksplisit — capture & resurface tak boleh diam-diam melebarkan scope.
- **Tidak menulis `debt.yaml`.** Status diturunkan; entri dimiliki skill `/debt`. Skill yang merujuk rule ini hanya MEMBACA registry + menulis task `kind: debt` ke `tasks.yaml`-nya sendiri.
```

- [ ] **Step 2: Verifikasi section wajib**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
for s in "# Debt-Aware" "## Kontrak" "## Batas" "kind: debt, pays_debt" "owner: feature" "owner: foundation" "Tidak menulis"; do
  grep -qF "$s" plugin/rules/debt-aware.md && echo "ada: $s" || echo "HILANG: $s"
done
```
Expected: tujuh baris `ada: …`, tidak ada `HILANG:`.

- [ ] **Step 3: Commit**

```bash
git add plugin/rules/debt-aware.md
git commit -m "feat(debt): rule debt-aware — resurface utang by locality (rider read per-area)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Skill `plugin/skills/debt/SKILL.md`

**Files:**
- Create: `plugin/skills/debt/SKILL.md`

Steward registry, 4 verb. Frontmatter `name: debt`, description ikut pola rumah (`Use untuk … — … Trigger — "…". Jalankan dari root produk yang punya control/.`). Tanpa `reference.md` (alur ringkas — sesuai spec §11).

- [ ] **Step 1: Buat folder + tulis file lengkap**

Buat `plugin/skills/debt/SKILL.md` dengan isi PERSIS berikut:

````markdown
---
name: debt
description: Use untuk mengelola UTANG TEKNIS produk — registry control/debt.yaml. Steward tipis read/triase: list (+ status diturunkan), triage (masih relevan? sesuaikan severity / buang kalau cuma selera), promote (tarik manual jadi task kind:debt), drop (decline + alasan, simpan jadi memori). build yang APPEND stub pas nemu di luar scope (pintu ke-4); /debt yang triage/promote/drop. TIDAK nulis kode. Trigger — "debt list", "ada utang teknis apa", "lunasin utang <x>", "drop utang <x>". Jalankan dari root produk yang punya control/.
---

# debt — Steward Utang Teknis (registry control/debt.yaml)

Tujuan: kelola registry utang teknis — hal yang secara arsitektur menyusahkan tapi **sekarang masih benar** (bukan defect → `/fix`; bukan kapabilitas baru → `/feature`). `/debt` **tidak** menulis kode & **tidak** memanggil `build` — pelunasan terjadi di host feature/fix (lewat task `kind: debt`). Satu-satunya pemilik schema `control/debt.yaml`.

## Prasyarat
- Jalankan dari root produk yang punya `control/`.
- **Tanpa `control/`** → belum ada produk; arahkan `/init`, lalu STOP.
- **`control/debt.yaml` belum ada** (produk lama) → buat dari template `${CLAUDE_PLUGIN_ROOT}/template/control/debt.yaml` (root kosong `debt: []`), lalu lanjut.

## Status diturunkan (jangan tulis flag manual)
Status TIDAK disimpan; hitung **on-read** dengan menyilang `pays_debt: <id>` di seluruh `control/features/*/tasks.yaml` + `control/fixes/*/tasks.yaml` dan status host (`feature.yaml`/`fix.yaml`):
- **open** = tak ada task `pays_debt: <id>` aktif & `dropped` kosong.
- **scheduled** = ada task `pays_debt: <id>` `pending`/`in_progress` di host aktif.
- **shipped** = task `pays_debt: <id>` di feature/fix yang sudah `shipped`.
- **dropped** = field `dropped` terisi.

## Verb

### `list` (default tanpa argumen)
Baca `control/debt.yaml`, hitung status tiap entri (di atas), tampilkan tabel: `id` · `area` · `owner` · `severity` · **status** · `observed`. Urut: `high`/`foundation` dulu, lalu `open` sebelum `scheduled`/`shipped`. Sembunyikan `dropped` (kecuali diminta `list --all`).

### `triage [<id>]`
Review utang `open` (atau `<id>` tertentu): masih relevan? Sesuaikan `severity` (`normal`/`high`). Bila ternyata **selera/kosmetik** (gagal bar "drag nyata") → arahkan `drop`. Bila ternyata **fondasional** (sentuh stack/`conventions.md`/shared package/`integrations.md`, ATAU lintas >1 app, ATAU ubah kontrak shared) tapi ter-`owner: feature` → betulkan `owner: foundation` + naikkan `severity`, ingatkan ini butuh `/architect`/`/add-*` (bukan dilunasi `plan`/`fix`). Tampilkan perubahan → minta approve sebelum tulis. (Opsional `critic` untuk registry besar — lihat spec §11.)

### `promote <id>`
Tarik manual sebuah utang jadi kerjaan — pelengkap jalur locality (`plan`/`fix`). Tentukan host: fitur/fix `active`/`open` yang relevan (`area` cocok), ATAU lane fix post-ship bila berdiri sendiri. **Arahkan** pembuatan task `kind: debt, pays_debt: <id>` ke host itu (lewat `breakdown`/`fix`) — `/debt` sendiri tak menulis `tasks.yaml`. Setelah ada task aktif, status entri otomatis jadi `scheduled` (diturunkan).

### `drop <id>`
Decline: tulis `dropped: {at: <YYYY-MM-DD>, reason: "<alasan>"}` ke entri (satu-satunya tulisan status eksplisit). **Entri dikeep** sebagai memori keputusan (precedent skill `drop`); `render-docs` menyaringnya dari Known Issues aktif. Minta alasan sebelum tulis.

## Guardrails
- **Pemilik tunggal.** Hanya `/debt` yang menulis schema/`dropped`; `build` cuma APPEND entri `open` (pintu ke-4). Tak ada penulis lain.
- **Tidak nulis kode / tidak panggil `build`.** Pelunasan di host feature/fix via task `kind: debt`. `/debt` murni read + edit-metadata ringan.
- **Status-as-byproduct.** Jangan pernah tulis field `status:`; selalu turunkan. Mencegah "nyangkut selamanya" terulang.
- **Bukan defect, bukan fitur.** Bug → `/fix`. Kapabilitas baru → `/feature`. `/debt` cuma untuk "benar tapi jelek, nanti".

## Catatan
- Capture (lahir entri) = otomatis di `build` pintu ke-4 — bukan di sini. `/debt` mulai dari entri yang sudah ada.
- Pelengkap: `render-docs` memproyeksikan utang `open`/`scheduled` ke "Known Issues / Utang Teknis" (jaring selalu-nyala — nol debt hilang walau areanya tak disentuh lagi).
````

- [ ] **Step 2: Verifikasi frontmatter valid & `name`==folder & pola rumah**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
python3 - <<'PY'
import re, pathlib
t = pathlib.Path("plugin/skills/debt/SKILL.md").read_text()
m = re.match(r"^---\n(.*?)\n---\n", t, re.S); assert m, "frontmatter --- tidak ditemukan"
fm = m.group(1)
name = re.search(r"^name:\s*(\S+)", fm, re.M).group(1)
assert name == "debt", f"name '{name}' != 'debt'"
assert "Trigger —" in fm and "Jalankan dari root produk yang punya control/" in fm, "description tidak ikut pola rumah"
print("OK: frontmatter valid, name=debt, description berpola rumah")
PY
```
Expected: `OK: frontmatter valid, name=debt, description berpola rumah`

- [ ] **Step 3: Verifikasi 4 verb + section wajib ada**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
for s in "### \`list\`" "### \`triage" "### \`promote" "### \`drop" "## Status diturunkan" "## Guardrails" "status-as-byproduct"; do
  grep -qF "$s" plugin/skills/debt/SKILL.md && echo "ada: $s" || echo "HILANG: $s"
done
```
Expected: tujuh baris `ada: …`, tidak ada `HILANG:`.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/debt/SKILL.md
git commit -m "feat(debt): skill /debt steward registry utang teknis (list/triage/promote/drop)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: `breakdown` — kenali & pertahankan `kind: debt` + `pays_debt`

**Files:**
- Modify: `plugin/skills/breakdown/SKILL.md` (§7 preservasi `kind`, §4 coverage)
- Modify: `plugin/skills/breakdown/reference.md` (§B aturan — dokumentasikan `kind: debt`)

`kind: debt` adalah saudara `kind: fix` (metadata). breakdown harus (a) tidak membuangnya saat regenerate, dan (b) membuat task `kind: debt` untuk tiap utang yang ditandai-dilunasi di plan (handoff dari `plan` T6).

- [ ] **Step 1: §7 — perluas preservasi `kind: fix` jadi `kind: fix`/`kind: debt`**

Di `plugin/skills/breakdown/SKILL.md`, cari teks PERSIS:
```
**Pertahankan task `kind: fix`** (corrective, dari lane `fix`/disiplin embed `build`) yang **tak punya asal-`plan`** — JANGAN buang saat regenerate dari plan (kalau dibuang, bug yang sudah di-fix bisa ter-regress diam-diam). Task `kind: fix` ikut dipertahankan statusnya seperti task `done`/`in_progress` lain.
```
Ganti dengan:
```
**Pertahankan task `kind: fix` dan `kind: debt`** (corrective dari lane `fix`/disiplin embed `build`; atau pelunasan utang teknis ber-`pays_debt`) yang **tak punya asal-`plan`** — JANGAN buang saat regenerate dari plan (kalau dibuang, bug yang sudah di-fix bisa ter-regress diam-diam, dan utang yang sudah dijadwalkan jadi hilang dari tracking). Task `kind: fix`/`kind: debt` ikut dipertahankan statusnya seperti task `done`/`in_progress` lain.
```

- [ ] **Step 2: §4 — tambah coverage untuk utang yang dilunasi**

Di `plugin/skills/breakdown/SKILL.md` §4 (Coverage check), cari teks PERSIS:
```
- **Coverage:** tiap keputusan `_shared.md` ("env yang dibagi", mekanisme) & tiap baris Model/Schema di `plans/<app>.md` HARUS ke-map ke sebuah task/`action`/`manual` — jangan ada yang menguap. Tampilkan peta plan→task di gate.
```
Ganti dengan:
```
- **Coverage:** tiap keputusan `_shared.md` ("env yang dibagi", mekanisme) & tiap baris Model/Schema di `plans/<app>.md` HARUS ke-map ke sebuah task/`action`/`manual` — jangan ada yang menguap. Tampilkan peta plan→task di gate.
- **Utang yang dilunasi:** untuk tiap utang yang ditandai-dilunasi di `plans/*` (baris "Utang dilunasi: `<id>`" yang ditulis `plan` lewat `rules/debt-aware.md`), munculkan satu task `kind: debt, pays_debt: <id>` (refactor — jaga perilaku TETAP sama, `test` = kasus regresi yang membuktikan perilaku tak berubah). `unit` = app pemilik area utang.
```

- [ ] **Step 3: reference.md §B — dokumentasikan `kind: debt`**

Di `plugin/skills/breakdown/reference.md`, cari teks PERSIS (bullet terakhir §B yang relevan):
```
- **`test:` boleh non-unit.** Untuk task non-unit-testable (config, scaffold, shared types), `test:` boleh berisi kriteria seperti "typecheck hijau"/"build sukses"/"file ada & ke-import"; size-nya "satu artifact koheren".
```
Ganti dengan:
```
- **`test:` boleh non-unit.** Untuk task non-unit-testable (config, scaffold, shared types), `test:` boleh berisi kriteria seperti "typecheck hijau"/"build sukses"/"file ada & ke-import"; size-nya "satu artifact koheren".
- **Metadata `kind:` (traceability, tak ubah eksekusi).** Task tanpa `kind` = implicit `feat`. `kind: fix` (+ `corrects: <id-task>` + `observed:`) = korektif defect (lane `fix`/embed `build`). `kind: debt` (+ `pays_debt: <id-debt>` + `observed:`) = pelunasan utang teknis dari `control/debt.yaml` (refactor: perilaku TETAP sama, `test` membuktikan tak ada regresi). `build` memperlakukan `kind`/`corrects`/`observed`/`pays_debt` sebagai metadata. Task `kind: fix`/`kind: debt` yang tak ber-asal-`plan` **dipertahankan** saat re-breakdown (SKILL.md §7).
```

- [ ] **Step 4: Verifikasi kedua file**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -qF "Pertahankan task \`kind: fix\` dan \`kind: debt\`" plugin/skills/breakdown/SKILL.md && echo "OK §7 preservasi" || echo "GAGAL §7"
grep -qF "Utang yang dilunasi:" plugin/skills/breakdown/SKILL.md && echo "OK §4 coverage" || echo "GAGAL §4"
grep -qF "kind: debt\` (+ \`pays_debt:" plugin/skills/breakdown/reference.md && echo "OK reference §B" || echo "GAGAL reference"
```
Expected: tiga baris `OK …`.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/breakdown/SKILL.md plugin/skills/breakdown/reference.md
git commit -m "feat(breakdown): kenali & pertahankan kind: debt + pays_debt (pelunasan utang)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: `build` — pintu ke-4 (capture utang teknis)

**Files:**
- Modify: `plugin/skills/build/SKILL.md` (§6 gate — tambah pintu ke-4; §3 dispatch — `kind: debt` metadata)

- [ ] **Step 1: §3 — perlakukan `kind: debt` seperti metadata (sejajar `kind: fix`)**

Di `plugin/skills/build/SKILL.md` §3, cari teks PERSIS:
```
Task ber-`kind: fix` (dari lane `fix`/disiplin embed) diperlakukan seperti task biasa — `kind`/`corrects`/`observed` adalah **metadata traceability**, tidak mengubah dispatch.
```
Ganti dengan:
```
Task ber-`kind: fix` atau `kind: debt` (dari lane `fix`/disiplin embed/pelunasan utang) diperlakukan seperti task biasa — `kind`/`corrects`/`observed`/`pays_debt` adalah **metadata traceability**, tidak mengubah dispatch. (Task `kind: debt` = refactor: implementer WAJIB jaga perilaku TETAP sama; `test` regresi membuktikan tak ada perubahan perilaku.)
```

- [ ] **Step 2: §6 — sisipkan pintu ke-4 setelah disiplin-fix embed**

Di `plugin/skills/build/SKILL.md` §6, cari teks PERSIS:
```
**JANGAN invoke skill `/fix`** (anti-rekursi `build`→fix→`build`); disiplinnya inline di sini. Skill `/fix` hanya entry dari luar.
```
Ganti dengan (menambah paragraf pintu ke-4 setelahnya):
```
**JANGAN invoke skill `/fix`** (anti-rekursi `build`→fix→`build`); disiplinnya inline di sini. Skill `/fix` hanya entry dari luar. **Pintu ke-4 — utang teknis out-of-scope.** Bila implementer/gate menemukan sesuatu DI LUAR intent task yang **bukan** penyimpangan-in-scope (di atas) & **bukan** langgar-invariant: terapkan **2-bar** — (a) drag nyata bukan selera, (b) benerin sekarang = keluar scope; gagal salah satu → abaikan/kerjakan-biasa. Lolos → tentukan **fondasional** (sentuh stack/`conventions.md`/shared package/`integrations.md`, ATAU lintas >1 app, ATAU ubah kontrak shared). **Fondasional → STOP**, minta keputusan eksplisit SEKARANG (route `/architect`·`/add-package`·`/wire`, ATAU catat sadar `owner: foundation`) — `rules/anti-yes-man.md`: keputusan mahal jangan ditunda diam-diam. **Cheap & lokal → APPEND** entri `open` ke `control/debt.yaml` (`area` dari task berjalan, `owner: feature`, `observed`, `why_drag`, `severity`; cek dedup vs entri `open` ber-`id` sama dulu) lalu **LANJUT** loop. **JANGAN invoke `/debt`** (anti-rekursi; `build` cuma APPEND, persis seperti nulis corrective task `kind: fix`). Pelunasan menyusul lewat `plan`/`fix` (`rules/debt-aware.md`) atau `/debt promote` — capture TIDAK melebarkan build ini.
```

- [ ] **Step 3: Verifikasi**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -qF "Pintu ke-4 — utang teknis out-of-scope." plugin/skills/build/SKILL.md && echo "OK pintu-4" || echo "GAGAL pintu-4"
grep -qF "kind: debt\` (dari lane" plugin/skills/build/SKILL.md && echo "OK §3 metadata" || echo "GAGAL §3"
grep -qF "APPEND** entri \`open\` ke \`control/debt.yaml\`" plugin/skills/build/SKILL.md && echo "OK append" || echo "GAGAL append"
grep -qF "JANGAN invoke \`/debt\`" plugin/skills/build/SKILL.md && echo "OK anti-rekursi" || echo "GAGAL anti-rekursi"
```
Expected: empat baris `OK …`.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/build/SKILL.md
git commit -m "feat(build): pintu ke-4 — capture utang teknis (2-bar + fondasional→decide-now / cheap→APPEND)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: `plan` — debt-aware rider (resurface saat scoping per-app)

**Files:**
- Modify: `plugin/skills/plan/SKILL.md` (§3 per-app — baca debt; §4 gate — surface + rekam ke plan)

- [ ] **Step 1: §3 — tambah bullet debt-aware di read per-app**

Di `plugin/skills/plan/SKILL.md` §3, cari teks PERSIS (bullet challenge teknis, baris terakhir §3):
```
- **Challenge teknis** sebelum gate: konsistensi dengan konvensi? risiko? cara lebih sederhana? Apakah plan ini melanggar invarian yang terkunci di `control/invariants.md` (tenancy/money/idempotency/authz/PII-PCI)? **Apakah app ini membuat logika yang seharusnya pakai mandatory package** (mis. format uang sendiri padahal `money` ada di `packages[].mandatory_for` app ini)? **Apakah fitur menyentuh vendor eksternal tapi kontraknya tak ada di `control/integrations.md`** (seam `fanout` terlewat)? → arahkan jalankan `add-integration`.
```
Ganti dengan (menambah bullet debt-aware setelahnya):
```
- **Challenge teknis** sebelum gate: konsistensi dengan konvensi? risiko? cara lebih sederhana? Apakah plan ini melanggar invarian yang terkunci di `control/invariants.md` (tenancy/money/idempotency/authz/PII-PCI)? **Apakah app ini membuat logika yang seharusnya pakai mandatory package** (mis. format uang sendiri padahal `money` ada di `packages[].mandatory_for` app ini)? **Apakah fitur menyentuh vendor eksternal tapi kontraknya tak ada di `control/integrations.md`** (seam `fanout` terlewat)? → arahkan jalankan `add-integration`.
- **Debt-aware (utang teknis di area ini).** Ikuti `${CLAUDE_PLUGIN_ROOT}/rules/debt-aware.md`: baca `control/debt.yaml`, saring utang `open` (`owner: feature`) yang `area`-nya ∈ app ini. Ini **rider** pada baca-kode app yang sudah dilakukan di atas, bukan langkah baru. Utang yang ketemu disodorkan di gate (langkah 4).
```

- [ ] **Step 2: §4 — surface di gate + rekam keputusan ke plan**

Di `plugin/skills/plan/SKILL.md` §4, cari teks PERSIS:
```
Tampilkan tiap plan → minta **approve per app**.
```
Ganti dengan:
```
Tampilkan tiap plan → minta **approve per app**. **Bila ada utang `open` di area app ini** (langkah 3 debt-aware): sodorkan di gate — *"area ini punya N utang open: `<ringkas>`. Lipat ke fitur ini? (+N task)"*. Untuk tiap utang yang di-ACC, tulis baris **`Utang dilunasi: <id>`** di `plans/<app>.md` (ini yang dibaca `breakdown` §4 untuk membuat task `kind: debt, pays_debt: <id>`). Yang ditolak biarkan `open` — tetap muncul di render-docs "Known Issues". `plan` **tidak** menulis `control/debt.yaml` (status diturunkan; pemiliknya `/debt`).
```

- [ ] **Step 3: Verifikasi**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -qF "Debt-aware (utang teknis di area ini)." plugin/skills/plan/SKILL.md && echo "OK §3 rider" || echo "GAGAL §3"
grep -qF "Utang dilunasi: <id>" plugin/skills/plan/SKILL.md && echo "OK §4 rekam" || echo "GAGAL §4"
grep -qF "rules/debt-aware.md" plugin/skills/plan/SKILL.md && echo "OK rujuk rule" || echo "GAGAL rujuk rule"
```
Expected: tiga baris `OK …`.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/plan/SKILL.md
git commit -m "feat(plan): debt-aware rider — tawarkan lunasi utang area saat scoping per-app

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: `fix` — debt-aware saat scoping + `kind: debt` sibling

**Files:**
- Modify: `plugin/skills/fix/SKILL.md` (§1 triage — debt-aware; Catatan — sibling)

- [ ] **Step 1: §1 — tambah debt-aware di akhir triage**

Di `plugin/skills/fix/SKILL.md` §1, cari teks PERSIS:
```
Lalu **triage guard** (reference §D): **kode salah** (lanjut) / **requirement baru** (STOP → `/feature`) / **doc salah** (koreksi knowledge, gated `critic`). Cek **tripwire** (butuh capability/vendor/unit baru → STOP → `/feature`).
```
Ganti dengan:
```
Lalu **triage guard** (reference §D): **kode salah** (lanjut) / **requirement baru** (STOP → `/feature`) / **doc salah** (koreksi knowledge, gated `critic`). Cek **tripwire** (butuh capability/vendor/unit baru → STOP → `/feature`).

**Debt-aware (utang teknis di area bug).** Saat sudah tahu `units` bug, ikuti `${CLAUDE_PLUGIN_ROOT}/rules/debt-aware.md`: baca `control/debt.yaml`, saring utang `open` (`owner: feature`) di area yang sama — rider pada baca-kode area yang fix sudah lakukan. Tawarkan: *"sekalian beresin N utang di area ini?"*. Yang di-ACC → tambah task `kind: debt, pays_debt: <id>` (refactor, perilaku tetap; skema metadata reference §B) ke `tasks.yaml` work-item ini. Ditolak → biarkan `open`. `fix` tak menulis `control/debt.yaml`.
```

- [ ] **Step 2: Catatan — `kind: debt` sibling `kind: fix`**

Di `plugin/skills/fix/SKILL.md`, cari teks PERSIS (bullet pertama Catatan):
```
- `fix` **tak pernah** auto-`ship` & tak bikin PR — jatah `/ship` (terpisah, eksplisit). `fix` cuma sampai IJO.
```
Ganti dengan:
```
- `fix` **tak pernah** auto-`ship` & tak bikin PR — jatah `/ship` (terpisah, eksplisit). `fix` cuma sampai IJO.
- Utang teknis (benar tapi jelek) **bukan** defect → bukan jatah `fix` untuk men-*catat*; itu `control/debt.yaml` (di-capture `build` pintu ke-4, dikelola `/debt`). `fix` hanya **melunasi** utang `open` yang kebetulan satu-area lewat task `kind: debt` (§1 debt-aware) — sibling `kind: fix`.
```

- [ ] **Step 3: Verifikasi**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -qF "Debt-aware (utang teknis di area bug)." plugin/skills/fix/SKILL.md && echo "OK §1 debt-aware" || echo "GAGAL §1"
grep -qF "sibling \`kind: fix\`" plugin/skills/fix/SKILL.md && echo "OK catatan sibling" || echo "GAGAL catatan"
grep -qF "rules/debt-aware.md" plugin/skills/fix/SKILL.md && echo "OK rujuk rule" || echo "GAGAL rujuk rule"
```
Expected: tiga baris `OK …`.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/fix/SKILL.md
git commit -m "feat(fix): debt-aware saat scoping + kind: debt sibling kind: fix

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: `render-docs` — Known Issues / Utang Teknis (jaring selalu-nyala)

**Files:**
- Modify: `plugin/skills/render-docs/SKILL.md` (§1 baca debt; §3 fixes slot — emit debt; §4 filter + status)

Debt di-render ke section "Known Issues" yang sudah ada (reuse class `.card`/`.sev`/`.status` — tak ubah `template.html`). Status diturunkan (sama §5.2 spec).

- [ ] **Step 1: §1 — baca `control/debt.yaml`**

Di `plugin/skills/render-docs/SKILL.md` §1, cari teks PERSIS:
```
- `control/fixes/*/fix.yaml` — kumpulkan defect (id, status, severity, reported, relates_to, flow). SHAPE-only, TANPA isi sensitif.
```
Ganti dengan:
```
- `control/fixes/*/fix.yaml` — kumpulkan defect (id, status, severity, reported, relates_to, flow). SHAPE-only, TANPA isi sensitif.
- `control/debt.yaml` — kumpulkan utang teknis (id, area, owner, severity, observed). **Status diturunkan** (bukan field): silang `pays_debt: <id>` di `control/features/*/tasks.yaml` + `control/fixes/*/tasks.yaml` & status host → `open`/`scheduled`/`shipped`; `dropped` dari field `dropped`. SHAPE-only.
```

- [ ] **Step 2: §3 — emit debt ke Known Issues**

Di `plugin/skills/render-docs/SKILL.md` §3, cari teks PERSIS:
```
- **fixes:** isi `<!-- SLOT:fixes -->`. Satu `.card` per fix dari `control/fixes/`: judul `id` + `.sev` (`severity`) + `.status` (`status`), `reported`, lalu `.meta` link `relates_to` (fitur) + `flow`. Urut: **Known Issues** (`open`/`diagnosed`) dulu, severity `urgent` di atas; lalu **Riwayat** (`shipped`). `dropped` JANGAN ditampilkan.
```
Ganti dengan:
```
- **fixes:** isi `<!-- SLOT:fixes -->`. Satu `.card` per fix dari `control/fixes/`: judul `id` + `.sev` (`severity`) + `.status` (`status`), `reported`, lalu `.meta` link `relates_to` (fitur) + `flow`. Urut: **Known Issues** (`open`/`diagnosed`) dulu, severity `urgent` di atas; lalu **Riwayat** (`shipped`). `dropped` JANGAN ditampilkan.
- **utang teknis (di slot yang sama, label "Known Issues / Utang Teknis"):** satu `.card` per utang dari `control/debt.yaml` (reuse class yang sama): judul `id` + `.sev` (`severity`) + `.status` (status **diturunkan**, §1), `observed`, lalu `.meta` `area` + `owner`. Urut: `open`/`scheduled` dulu (severity `high`/`owner: foundation` di atas) = bagian Known Issues; `shipped` masuk **Riwayat**. `dropped` JANGAN ditampilkan. Bila `debt.yaml` tak ada / `debt: []` → lewati (tak ada section kosong).
```

- [ ] **Step 3: §4 — filter + pemicu status debt**

Di `plugin/skills/render-docs/SKILL.md` §4, cari teks PERSIS:
```
Untuk fix: `dropped` JANGAN ditampilkan; `open`/`diagnosed` = "Known Issues"; `shipped` = "Riwayat". `render-docs` dipicu `ship` (fix shipped) **dan** oleh `fix` saat status fix berubah jadi `open`/`diagnosed` (biar Known Issues muncul tanpa nunggu ship lain).
```
Ganti dengan:
```
Untuk fix: `dropped` JANGAN ditampilkan; `open`/`diagnosed` = "Known Issues"; `shipped` = "Riwayat". `render-docs` dipicu `ship` (fix shipped) **dan** oleh `fix` saat status fix berubah jadi `open`/`diagnosed` (biar Known Issues muncul tanpa nunggu ship lain). Untuk utang teknis: `dropped` JANGAN ditampilkan; `open`/`scheduled` = "Known Issues / Utang Teknis" (jaring — utang `open` selalu kelihatan walau areanya tak disentuh `plan`/`fix` lagi); `shipped` = "Riwayat".
```

- [ ] **Step 4: Verifikasi**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -qF "control/debt.yaml\` — kumpulkan utang teknis" plugin/skills/render-docs/SKILL.md && echo "OK §1 baca" || echo "GAGAL §1"
grep -qF "Known Issues / Utang Teknis" plugin/skills/render-docs/SKILL.md && echo "OK §3 emit" || echo "GAGAL §3"
grep -qF "Untuk utang teknis: \`dropped\` JANGAN" plugin/skills/render-docs/SKILL.md && echo "OK §4 filter" || echo "GAGAL §4"
```
Expected: tiga baris `OK …`.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/render-docs/SKILL.md
git commit -m "feat(render-docs): Known Issues / Utang Teknis — proyeksi debt (status diturunkan, jaring)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: `ask` — baris klasifikasi utang teknis

**Files:**
- Modify: `plugin/skills/ask/SKILL.md` (tabel klasifikasi §1)

- [ ] **Step 1: Tambah baris debt ke tabel klasifikasi**

Di `plugin/skills/ask/SKILL.md`, cari teks PERSIS:
```
| Bug / known-issues / riwayat fix | `fixes/*/fix.yaml` (+ `notes.md`) |
```
Ganti dengan (menambah satu baris setelahnya):
```
| Bug / known-issues / riwayat fix | `fixes/*/fix.yaml` (+ `notes.md`) |
| Utang teknis (yang ditunda sadar — "ada utang apa", "kenapa belum dibenerin") | `control/debt.yaml` (status diturunkan: silang `pays_debt` di `tasks.yaml`) |
```

- [ ] **Step 2: Verifikasi baris masuk & tabel tetap valid (pipe konsisten)**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -qF "Utang teknis (yang ditunda sadar" plugin/skills/ask/SKILL.md && echo "OK baris debt" || echo "GAGAL baris"
# baris baru harus punya 2 pipe pembatas seperti baris tabel lain
awk -F'|' '/Utang teknis \(yang ditunda sadar/{print (NF==4)?"OK kolom":"GAGAL kolom"}' plugin/skills/ask/SKILL.md
```
Expected: `OK baris debt` lalu `OK kolom`.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/ask/SKILL.md
git commit -m "feat(ask): klasifikasi 'utang teknis' → control/debt.yaml (read-only)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: Registrasi `/debt` di dua manifest plugin

**Files:**
- Modify: `plugin/.claude-plugin/plugin.json` (field `description`)
- Modify: `.claude-plugin/marketplace.json` (`plugins[0].description`)

- [ ] **Step 1: `plugin.json` — sisip `debt` sebelum penutup**

Di `plugin/.claude-plugin/plugin.json`, cari substring PERSIS:
```
ask (AMA produk read-only: knowledge-first + code-fallback, flag drift→route), docs).
```
Ganti dengan:
```
ask (AMA produk read-only: knowledge-first + code-fallback, flag drift→route), debt (lane utang teknis: pintu ke-4 build + registry control/debt.yaml, status diturunkan, resurface by locality), docs).
```

- [ ] **Step 2: `marketplace.json` — sebut debt**

Di `.claude-plugin/marketplace.json`, cari substring PERSIS:
```
"description": "Skills (init→ship + lane bugfix fix + ask read-only), agent, dan rules untuk mengelola produk multi-app secara AI-first.",
```
Ganti dengan:
```
"description": "Skills (init→ship + lane bugfix fix + ask read-only + lane utang teknis debt), agent, dan rules untuk mengelola produk multi-app secara AI-first.",
```

- [ ] **Step 3: Verifikasi kedua JSON valid + debt tersebut**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
python3 - <<'PY'
import json
p = json.load(open("plugin/.claude-plugin/plugin.json"))
assert "debt (lane utang teknis" in p["description"], "plugin.json: debt tak tersebut"
m = json.load(open(".claude-plugin/marketplace.json"))
assert "lane utang teknis debt" in m["plugins"][0]["description"], "marketplace.json: debt tak tersebut"
print("OK: kedua manifest JSON valid & menyebut debt")
PY
```
Expected: `OK: kedua manifest JSON valid & menyebut debt`

- [ ] **Step 4: Commit**

```bash
git add plugin/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "feat(plugin): daftarkan skill debt di plugin.json + marketplace.json

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: README + spec induk §17 (skill 19→20)

**Files:**
- Modify: `README.md` (daftar skill side-lane + paragraf status)
- Modify: `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§17 daftar + hitungan skill; diagram tree)

- [ ] **Step 1: README — tambah baris `/debt` setelah `/fix`**

Di `README.md`, cari teks PERSIS (baris `/fix`, line ~53):
```
/fix <apa-yang-rusak>   # lane bugfix: auto-deteksi in-flight (fitur active) / post-ship (fixes/<id>/); berhenti di ijo, ship terpisah
```
Ganti dengan (menambah baris `/debt` setelahnya):
```
/fix <apa-yang-rusak>   # lane bugfix: auto-deteksi in-flight (fitur active) / post-ship (fixes/<id>/); berhenti di ijo, ship terpisah
/debt <list|promote|drop>  # lane utang teknis: build catat saat nemu (pintu ke-4) → control/debt.yaml; resurface by locality (plan/fix) + Known Issues
```

- [ ] **Step 2: README — tambah ke paragraf status**

Di `README.md`, cari substring PERSIS (akhir paragraf status, line ~73):
```
**Sisi-baca:** `ask` (AMA produk read-only — knowledge-first + code-fallback, grounding wajib, flag drift→route ke skill pemilik, tidak pernah nulis).
```
Ganti dengan:
```
**Sisi-baca:** `ask` (AMA produk read-only — knowledge-first + code-fallback, grounding wajib, flag drift→route ke skill pemilik, tidak pernah nulis). **Lane utang teknis:** `debt` — pintu ke-4 `build` menangkap tech debt out-of-scope ke `control/debt.yaml` (status diturunkan, status-as-byproduct); fondasional → decide-now (anti-yes-man); resurface by locality lewat `plan`/`fix` (`rules/debt-aware.md`) + jaring `render-docs` "Known Issues"; steward `/debt` (list/triage/promote/drop).
```

- [ ] **Step 3: induk §17 — hitungan skill 19→20 + tambah `debt`**

Di `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`, cari teks PERSIS (line ~297):
```
- **Skills (19):** `discovery` · `init` · `architect` · `wire` · `add-app` · `add-package` · `add-integration` · `extract` · `feature` (→ `intake` · `fanout` · `plan`) · `breakdown` · `build` · `ship` · `drop` · `render-docs` · `fix` · `ask`
```
Ganti dengan:
```
- **Skills (20):** `discovery` · `init` · `architect` · `wire` · `add-app` · `add-package` · `add-integration` · `extract` · `feature` (→ `intake` · `fanout` · `plan`) · `breakdown` · `build` · `ship` · `drop` · `render-docs` · `fix` · `ask` · `debt`
```

- [ ] **Step 4: induk — perbaiki diagram tree (tambah `ask`+`debt` yang kelewat)**

Di `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`, cari teks PERSIS (line ~131):
```
│   ├── skills/   discovery· init· architect· wire· add-app· add-package· add-integration· extract· intake· fanout· plan· feature· breakdown· build· ship· drop· render-docs· fix
```
Ganti dengan:
```
│   ├── skills/   discovery· init· architect· wire· add-app· add-package· add-integration· extract· intake· fanout· plan· feature· breakdown· build· ship· drop· render-docs· fix· ask· debt
```

- [ ] **Step 5: Verifikasi semua anchor**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
grep -qF "/debt <list|promote|drop>" README.md && echo "OK README baris" || echo "GAGAL README baris"
grep -qF "Lane utang teknis:** \`debt\`" README.md && echo "OK README status" || echo "GAGAL README status"
grep -qF "**Skills (20):**" docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md && echo "OK induk count" || echo "GAGAL induk count"
grep -qF "render-docs· fix· ask· debt" docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md && echo "OK induk tree" || echo "GAGAL induk tree"
# sanity: tidak ada lagi 'Skills (19)'
! grep -qF "**Skills (19):**" docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md && echo "OK no stale 19" || echo "GAGAL masih ada 19"
```
Expected: lima baris `OK …`.

- [ ] **Step 6: Commit**

```bash
git add README.md docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
git commit -m "docs: daftarkan /debt di README + induk §17 (skill 19→20)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Verifikasi Akhir (setelah semua task)

- [ ] **Smoke: semua skill punya frontmatter `name`==folder & description berpola rumah**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
python3 - <<'PY'
import re, pathlib
ok = True
for sk in pathlib.Path("plugin/skills").iterdir():
    f = sk / "SKILL.md"
    if not f.exists(): continue
    t = f.read_text(); m = re.match(r"^---\n(.*?)\n---\n", t, re.S)
    if not m: print(f"GAGAL {sk.name}: no frontmatter"); ok=False; continue
    name = re.search(r"^name:\s*(\S+)", m.group(1), re.M)
    if not name or name.group(1) != sk.name:
        print(f"GAGAL {sk.name}: name mismatch"); ok=False
print("OK: semua skill frontmatter name==folder" if ok else "ADA GAGAL")
PY
```
Expected: `OK: semua skill frontmatter name==folder`

- [ ] **Smoke: rujukan silang konsisten (`debt-aware` dirujuk plan+fix; `pays_debt` di semua titik)**

Run:
```bash
cd /Users/mac-098506/Developer/project/context-vault
echo "debt-aware dirujuk:"; grep -lF "rules/debt-aware.md" plugin/skills/plan/SKILL.md plugin/skills/fix/SKILL.md
echo "pays_debt muncul di:"; grep -lF "pays_debt" plugin/skills/build/SKILL.md plugin/skills/breakdown/SKILL.md plugin/skills/breakdown/reference.md plugin/skills/plan/SKILL.md plugin/skills/fix/SKILL.md plugin/skills/render-docs/SKILL.md plugin/skills/debt/SKILL.md
```
Expected: `plan/SKILL.md` & `fix/SKILL.md` ter-list untuk debt-aware; tujuh file ter-list untuk pays_debt.

- [ ] **Review:** `git log --oneline -11` menampilkan 11 commit task berurutan; working tree bersih (`git status`).
