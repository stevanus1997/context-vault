# context-vault — Pintu ke-4 `build`: Lane Utang Teknis (Tech Debt) (Design Spec)

- **Tanggal:** 2026-06-04
- **Status:** Draft disetujui untuk masuk tahap perencanaan implementasi (hasil brainstorming, semua keputusan perilaku terkunci)
- **Terkait:** spec induk `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (prinsip *status-as-byproduct* §43, *single-source-of-truth* §42); lane `fix` `docs/superpowers/specs/2026-06-02-fix-bugfix-lane-design.md` + `plugin/skills/fix/reference.md` (mesin work-item + skema `kind:`/`corrects:`/`observed:` yang di-reuse); `plugin/skills/build/SKILL.md` §6 (gate + disiplin-fix embed tempat pintu ke-4 dipasang); `plugin/skills/breakdown/reference.md` (skema `tasks.yaml`, preservasi `kind:`); `plugin/skills/drop/SKILL.md` (precedent *decline-as-memory*); `plugin/skills/render-docs/SKILL.md` (proyeksi "Known Issues"); `plugin/rules/anti-yes-man.md` §13 (keputusan fondasional **tak boleh** ditunda diam-diam).

---

## 1. Ringkasan

Saat `build` mengeksekusi `tasks.yaml`, implementer kadang menemukan **tech debt** — sesuatu yang *secara arsitektur menyusahkan* tapi **bukan** defect (perilaku sekarang masih benar) dan **bukan** kapabilitas baru. Memperbaikinya di tempat membuat build **melebar keluar intent task**; membiarkannya membuat kerjaan ke depan makin susah.

`build` hari ini cuma punya **tiga pintu keluar** saat gate menemukan masalah (SKILL.md §6):
1. **Penyimpangan in-scope** (test ijo tapi meleset dari intent) → disiplin-fix embed inline → task `kind: fix` di `tasks.yaml` yang sama → lanjut.
2. **Langgar invariant / mandatory-package** → **BLOKER keras**, STOP + revisi.
3. **Kapabilitas baru** (scope creep) → STOP, route `/feature`.

**Tak ada pintu ke-4** untuk kategori "debt beneran". Kategori ini jatuh ke celah; akibatnya pengguna mengarang workaround (mencatat "Utang Sadar" di `control/conventions.md`) yang **secara struktural buntu** — `conventions.md` tak punya pembaca yang memperlakukannya sebagai kerjaan, tak punya status, dan salah-pemilik (cuma `architect`/`add-*` yang boleh menulisnya). Catatannya jadi *write-only memory*: nyangkut selamanya sampai manusia ingat.

Spec ini menambah **pintu ke-4**: sebuah **lane utang teknis** — debt jadi **warga kelas-satu yang pasif-sampai-ditarik**, dengan:
- **Capture** murah saat `build` menemukannya (atau **STOP-decide-now** bila fondasional);
- **Registry** `control/debt.yaml` (consumer + status + owner) — bukan catatan teks bebas;
- **Resurface** otomatis lewat *locality*: `plan` & `fix` menawarkan melunasi utang di area yang sedang mereka sentuh, dengan `render-docs` ("Known Issues") sebagai **jaring selalu-nyala** sehingga **nol debt pernah nyangkut diam-diam**;
- **Status diturunkan** dari kenyataan (status-as-byproduct), bukan flag manual.

Prinsip inti: **debt ditangkap di mana ia ditemukan, dilunasi di mana ia mengganggu.**

## 2. Masalah

- **M1 — Tak ada kategori "debt".** `build` hanya mengenali fix-inline / bloker / fitur-baru. Debt sejati (benar tapi jelek, di luar intent task) tak punya jalur — implementer terpaksa diam-diam menelannya (melebarkan scope) atau melupakannya.
- **M2 — Workaround `conventions.md` = buntu struktural.** Empat sebab menumpuk: **(a) tak ada consumer** (tak ada skill membacanya sebagai kerjaan); **(b) tak ada status machine** (tak bisa `open`/`scheduled`/`closed` — flag manual yang "mudah terlupa", justru yang dilarang prinsip status-as-byproduct, induk §43); **(c) salah-pemilik** (`conventions.md` milik `architect`/`add-*`; tulisan `build` ke situ out-of-owner, tanpa gate, drift, tak diproyeksikan `render-docs`); **(d) drift senyap** (catatan tangan di file generated-adjacent — persis yang single-source-of-truth, induk §42, cegah).
- **M3 — Tak ada backlog-puller.** Semua kerjaan di sistem *human-initiated per-invocation*; tak ada antrean yang menarik kerjaan berikutnya. Maka "bagaimana item debt **akhirnya ditarik**" adalah satu-satunya bagian yang genuinely baru — dan itu yang menentukan apakah debt nyangkut lagi.
- **M4 — Debt fondasional rawan ditunda diam-diam.** Justru debt yang mahal-di-refactor (lintas-app, ubah kontrak shared) yang paling berbahaya bila diparkir. `anti-yes-man.md` §13 mewajibkan keputusan fondasional diminta **eksplisit sekarang**, bukan ditunda — solusi tak boleh jadi pintu belakang untuk memarkir keputusan mahal.

Akar: sistem punya banyak penulis-kerjaan, **nol jalur untuk kerjaan-tertunda yang bukan fitur/bug**. `control/` sebagai source-of-truth tak punya tempat sah untuk "benar tapi jelek, nanti".

## 3. Tujuan & Non-Tujuan

**Tujuan:**
- **Pintu ke-4 di `build`** (§4): 2-bar capture + heuristik fondasional → **APPEND stub + lanjut** (cheap) atau **STOP-decide-now** (fondasional).
- **Registry `control/debt.yaml`** (§5): rumah debt dengan **status diturunkan** (status-as-byproduct), satu pemilik (`/debt`).
- **Resurface by locality** (§6): `plan` & `fix` **nebeng read area yang sudah mereka lakukan** (lewat aturan share `debt-aware`) untuk menawarkan pelunasan; `render-docs` "Known Issues" = jaring selalu-nyala.
- **Skill `/debt` tipis** (§7): steward `debt.yaml` — `list` | `triage` | `promote` | `drop`.
- **Ownership bersih + anti-recursion** (§8): `/debt` satu-satunya pemilik schema; `build` hanya **APPEND** stub (precedent: `build` meng-`append` `kind: fix` ke `tasks.yaml` milik `breakdown`); `build` **tak** memanggil `/debt`.
- **Fondasi tak pernah ditunda diam-diam** (§4, §8): debt fondasional wajib lewat pintu decide-now.

**Non-Tujuan (v1):**
- **Bukan scheduler / auto-backlog-puller.** Tak ada proses yang otomatis menjadwalkan debt. Penarikan = *opportunistic* (locality) atau manual (`/debt promote`). Status-as-byproduct, bukan antrean aktif.
- **Bukan generalisasi `build`/`fix`.** `kind: debt` adalah metadata task (seperti `kind: fix`); `build` mengeksekusinya tanpa perubahan mesin. Tak ada sub-pipeline baru di `build`.
- **`architect`/`wire`/`add-*` TIDAK disentuh** — debt fondasi sudah diputus di capture (decide-now); tak butuh reader.
- **Bukan auto-fix.** Menemukan/menarik debt **tak pernah** otomatis melebarkan build; pelunasan selalu lewat gate (plan/fix) atau perintah manusia.
- **Tak ada folder per-item** (`control/debt/<id>/`) — overkill untuk item pasif-sampai-ditarik; registry flat cukup.
- **Tak ada deteksi debt otomatis lintas-repo / linter** — capture berbasis temuan implementer saat `build`, bukan pemindaian.

## 4. Pintu ke-4 di `build` — Capture

Dipasang di gate `build` (SKILL.md §6), bersisian dengan disiplin-fix embed. Saat implementer/gate menemukan sesuatu **di luar intent task** yang bukan penyimpangan-in-scope (pintu 1) dan bukan langgar-invariant (pintu 2):

### 4.1 Dua-bar (saring dulu, biar registry tak banjir trivia)

Catat sebagai debt **hanya bila lolos keduanya**:
- **Bar A — drag nyata, bukan selera.** Membuat kerjaan ke depan **lebih susah/lambat/rawan** (mis. N+1 yang memburuk dengan skala, abstraksi bocor yang dicopy berulang) — **bukan** preferensi gaya/kosmetik. Bila cuma selera → **abaikan, jangan catat**.
- **Bar B — melunasi sekarang = keluar scope.** Memperbaikinya di task ini mendorong build keluar intent task yang disetujui.

Gagal Bar A → buang. Gagal Bar B (masih di dalam footprint task) → itu bagian task, kerjakan biasa (bukan debt).

### 4.2 Heuristik fondasional (checkable, bukan feeling)

Setelah lolos 2-bar, tentukan **fondasional atau cheap** secara mekanis. **Fondasional** bila **salah satu**:
- menyentuh **fondasi**: `stack` / `conventions.md` / shared `package` / `integrations.md`; **ATAU**
- **lintas >1 app**; **ATAU**
- mengubah **kontrak shared** (skema lintas-app, kontrak API/event yang dipakai >1 konsumen).

Selain itu → **cheap & lokal**.

### 4.3 Dua pintu

```
lolos 2-bar (§4.1)?
        │ ya
   fondasional (§4.2)?
   ┌────┴─────────────────────┐
   │ ya                       │ tidak (cheap & lokal)
   ▼                          ▼
build STOP → minta keputusan  build APPEND stub ke control/debt.yaml
EKSPLISIT sekarang:            { area, owner: feature, observed,
 a) route /architect +          why_drag, severity, ... } → status: open
    /add-package|/wire skrng    → LANJUT build (momentum aman)
    (stop fitur ini)            → muncul terus di Known Issues (jaring)
 b) APPEND stub
    owner: foundation +
    severity tinggi + lanjut,
    SADAR risikonya
```

- **Cheap → APPEND + lanjut.** `build` menulis stub minimal langsung (§5.1) dan **melanjutkan loop** — meniru disiplin-fix embed (record-and-continue), `build` tetap konduktor tipis & resumable. **Anti-recursion: `build` tak memanggil `/debt`** — ia hanya menambah baris ke `debt.yaml` (precedent: `build` meng-`append` `kind: fix` ke `tasks.yaml`).
- **Fondasional → STOP-decide-now** (memenuhi `anti-yes-man.md` §13). `build` menyajikan temuan + opsi; manusia memilih. Bila (b) dipilih, stub ditulis `owner: foundation` dan ditandai keras di Known Issues; ia di-resurface saat `architect`/`add-*`/`wire` berjalan lagi (bukan oleh `plan` fitur — `plan` tak menyentuh fondasi).

> **Catatan:** "fondasional" hampir selalu memilih pintu decide-now justru karena mahal-di-refactor. Inilah jawaban "kalau debt menyentuh ranah `architect`/`wire` bagaimana": ia tak lewat pintu stub-diam-diam, ia lewat pintu putusin-sekarang.

## 5. Registry `control/debt.yaml`

Rumah debt. **Pasif sampai ditarik.** Pemilik tunggal schema = skill `/debt`; `build` hanya **APPEND** entri `open` baru; `/debt drop` menulis penanda `dropped`. **Tak ada penulis lain.**

### 5.1 Skema entri

```yaml
# control/debt.yaml — list item debt; pemilik: /debt ; build APPEND-only
- id: <area-slug>            # mis. api-cart-nplus1 (deterministik dari area+ringkasan → basis dedup)
  area: <app/module>         # taksonomi SAMA dgn fanout/capabilities (lihat §11) — basis matching plan/fix
  owner: feature             # feature | foundation  (siapa yang berhak melunasi → siapa yang menagih)
  observed: "<apa yang jelek, 1 baris>"          # mis. "query N+1 di list cart"
  why_drag: "<kenapa ini drag nyata, bukan selera>"  # Bar A — wajib, justifikasi
  severity: normal           # normal | high   (urutan render-docs + sinyal; high khas fondasional)
  discovered_during: <feature/fix id>   # konteks asal (fitur/fix saat build menemukannya)
  discovered_at: <YYYY-MM-DD>
  dropped: null              # diisi {at, reason} HANYA oleh /debt drop (satu-satunya field status eksplisit)
  # CATATAN: TIDAK ADA field `status:` yang ditulis tangan — status DITURUNKAN (§5.2)
```

### 5.2 Status diturunkan (status-as-byproduct, induk §43)

`status` **tidak disimpan**; dihitung **on-read** oleh `/debt list` & `render-docs` dengan menyilang-referensi task `pays_debt: <id>` (§6.2) di seluruh `features/*/tasks.yaml` + `fixes/*/tasks.yaml` dan status host-nya:

| Status terhitung | Diturunkan dari |
|---|---|
| `open` | tak ada task ber-`pays_debt: <id>` yang aktif; `dropped == null` |
| `scheduled` | ada task `pays_debt: <id>` berstatus `pending`/`in_progress` di host aktif |
| `shipped` | task `pays_debt: <id>` berada di feature/fix yang `feature.yaml`/`fix.yaml`-nya `shipped` |
| `dropped` | field `dropped` terisi (dari `/debt drop`) |

Hanya **dua tulisan eksplisit** ke registry sepanjang hidup item: **`build` APPEND** (lahir `open`) + **`/debt drop`** (tandai `dropped`). Sisanya terhitung. Tak ada checkbox yang harus diingat.

### 5.3 Dedup

Sebelum APPEND, `build` cek apakah sudah ada entri **open** dengan `id` (deterministik dari `area` + tanda-tangan `observed`) yang sama → bila ada, **skip** (jangan duplikat saat build di-resume atau debt yang sama ketemu 2×). Detail algoritma id/tanda-tangan → §11.

## 6. Resurface — `debt-aware` (locality) + jaring `render-docs`

Tak ada daemon yang mengintip. Resurface terjadi lewat **read yang sudah dilakukan skill scoping**, plus proyeksi `render-docs` yang selalu nyala.

### 6.1 Aturan share `debt-aware`

`plugin/rules/debt-aware.md` — ditulis **sekali**, dirujuk oleh `plan` & `fix` (BUKAN di-copy, pola sama `anti-yes-man.md`). Isinya satu kontrak:

> Sebelum mulai kerja di area X, baca `control/debt.yaml` yang `area`-nya beririsan dengan footprint X. Untuk tiap entri `open` (status terhitung), **tawarkan melunasi di gate** skill ini. Bila pengguna setuju → buat task `kind: debt, pays_debt: <id>` (§6.2). Bila tidak → biarkan `open` (tetap muncul di Known Issues).

**Penting:** ini **rider** di read yang sudah inheren ada di tugas skill, **bukan langkah baru** yang bisa terlupa. `plan` memang sudah "baca kode tiap app yang kena"; `fix` sudah membaca kode area untuk root-cause. `debt-aware` cuma menambah **+1 file** (`debt.yaml` ter-filter area) ke read itu.

**Pull-point (owner: feature):**
- **`plan`** (fase teknis per-app `/feature`) — saat scoping app+module, surface debt `open` area itu di **gate plan** ("area ini punya N utang open — lipat ke fitur? +N task"). Item yang di-ACC → `breakdown` menuliskannya sebagai task `kind: debt`.
- **`fix`** (scoping bug) — saat membaca area bug, tawarkan melunasi debt di area yang sama ("sekalian beresin utang di sini?").

**Pull-point (owner: foundation):** `architect`/`add-*`/`wire` saat berjalan lagi (di luar v1 untuk reader — sebagian besar sudah ditangani decide-now §4.3; reader foundation = open question §11).

### 6.2 Task pelunas — `kind: debt`

Saudara kandung `kind: fix`. Saat debt ditarik (oleh `plan`→`breakdown`, `fix`, atau `/debt promote`), ditulis sebagai task di `tasks.yaml` host (skema milestone-wrapped, `breakdown/reference.md` §A):

```yaml
- id: debt-<area-slug>
  kind: debt                 # default TANPA kind = implicit "feat"; "fix"=korektif-defect; "debt"=lunasi utang
  pays_debt: <id-debt>       # cross-ref ke control/debt.yaml — basis komputasi status (§5.2)
  observed: "<ringkas dari debt.observed>"
  unit: <app/pkg>
  files: [ ... ]
  approach: "<refactor; tetap hijau — bukan ubah perilaku>"
  test: ["<regresi: perilaku TETAP sama, debt hilang>"]
  deps: []
  status: pending
```

`build` memperlakukan `kind`/`pays_debt`/`observed` sebagai **metadata** (sama seperti `kind: fix`) — eksekusi tak berubah. **`breakdown` mempertahankan task `kind: debt`** saat regenerate dari plan (sama seperti perlakuan `kind: fix`-nya sekarang) agar utang yang sudah dijadwalkan tak hilang diam-diam.

### 6.3 Jaring `render-docs`

`render-docs` memunculkan debt `open` + `scheduled` di section **"Known Issues / Utang Teknis"** (di samping fix open yang sudah ia render), `high`/`foundation` di atas. **Ini yang menjamin nol-stuck** terlepas dari pilihan reader: walau area sebuah debt tak pernah disentuh `plan`/`fix` lagi, ia tetap terlihat manusia tiap render → bisa di-`/debt promote` manual.

## 7. Skill `/debt` (steward, tipis)

Pemilik tunggal `control/debt.yaml`. Empat verb, semua read/triase ringan (tak meminjam mesin build — pelunasan terjadi di host feature/fix):

- **`list`** — tampilkan debt + **status terhitung** (§5.2), urut `high`/`foundation` dulu. Tanpa argumen = ringkasan.
- **`triage [<id>]`** — review: masih relevan? sesuaikan `severity`; bila ternyata **selera/kosmetik** (gagal Bar A surut) → arahkan `drop`. Gate ringan (opsional `critic` "ini debt nyata atau preferensi/fondasional?" — open question §11).
- **`promote <id>`** — tarik manual menjadi task `kind: debt` (§6.2) ke host yang dipilih (fitur/fix relevan, atau lane fix post-ship bila berdiri sendiri). Jalur eksplisit-manusia, melengkapi locality.
- **`drop <id>`** — decline: tulis `dropped: {at, reason}` (satu-satunya tulisan status eksplisit). Entri **dikeep sebagai memori keputusan** (precedent `drop/SKILL.md`); `render-docs` menyaringnya dari Known Issues aktif.

`/debt` **tidak** dipanggil `build` (anti-recursion). Trigger manusia: `debt list`, `debt promote <x>`, `debt drop <x>`, "ada utang apa aja", "lunasin utang <x>".

## 8. Guardrails

- **Ownership bersih.** `control/debt.yaml` punya satu pemilik-schema (`/debt`); `build` **APPEND-only** entri `open` (precedent meng-`append` `kind: fix` ke `tasks.yaml` milik `breakdown`); `/debt drop` satu-satunya penulis `dropped`. Tak ada penulis lain.
- **Anti-recursion.** `build` **tak** memanggil `/debt`/`/fix`/`/feature`; ia menulis stub langsung & lanjut. Pelunasan dieksekusi `build` lewat task `kind: debt` di host — bukan sub-pipeline.
- **Fondasi → decide-now (anti-yes-man §13).** Debt fondasional **tak boleh** diparkir diam-diam; `build` STOP minta keputusan eksplisit. Solusi bukan pintu belakang penundaan.
- **Scope discipline terjaga.** Capture **tak** melebarkan build (cheap = catat-lanjut). Pelunasan **selalu** lewat gate (plan/fix) atau perintah manusia (`promote`) — `build` tak pernah diam-diam menyerap kerjaan out-of-scope.
- **Status-as-byproduct.** Tak ada flag status manual; diturunkan (§5.2). Mencegah "nyangkut selamanya" terulang dengan baju baru.
- **Bukan selera.** Bar A + `why_drag` wajib + `triage` menjaga registry dari banjir preferensi gaya.

## 9. Trigger & Prasyarat

- **Capture:** otomatis di dalam `build` (gate §6) — bukan trigger manusia.
- **`/debt`:** `debt <verb>`, "lunasin utang <x>", "ada utang apa aja", "drop utang <x>". Dijalankan dari **root produk yang punya `control/`**.
- **Tanpa `control/`** → `/debt` tak relevan (belum ada produk) → arahkan `/init`.

## 10. Dampak ke Komponen Existing

- **Baru:** `plugin/skills/debt/SKILL.md` (steward 4-verb; kemungkinan tanpa `reference.md` — alur ringkas). `plugin/rules/debt-aware.md` (aturan share). `control/debt.yaml` ditambah ke **template** `plugin/template/control/` (lahir kosong/komentar, seperti file control lain).
- **`build`:** tambah pintu ke-4 di gate (§4) — 2-bar + heuristik fondasional → STOP-decide-now / APPEND stub + dedup. Disiplin record-and-continue, mesin tak berubah.
- **`plan`:** rujuk `debt-aware` di read per-app; surface di gate plan.
- **`fix`:** rujuk `debt-aware` di scoping; tambah `kind: debt` ke daftar kind yang dikenali (sejajar tripwire-nya).
- **`breakdown`:** kenali & **pertahankan** `kind: debt` + `pays_debt` (near-zero: perluasan slot `kind:`/preservasi yang sudah ada untuk `kind: fix`).
- **`render-docs`:** section "Known Issues / Utang Teknis" + komputasi status debt (§5.2, §6.3).
- **`ask`:** tabel klasifikasi (§4 spec `ask`) tambah baris "utang/known-issues → `debt.yaml`" agar pertanyaan "ada utang teknis apa" terjawab read-only.
- **Registrasi:** `plugin/.claude-plugin/plugin.json` + `marketplace.json` daftarkan `/debt` (+1). **spec induk §17** jumlah skill **19 → 20**. `README.md` tambah `/debt` (sisi lifecycle, sebelah `fix`).

## 11. Scope v1 & Open Questions

**v1 (in):** pintu ke-4 `build` (§4); registry `control/debt.yaml` + status diturunkan (§5); `debt-aware` di `plan` + `fix` + jaring `render-docs` (§6); skill `/debt` 4-verb (§7); `kind: debt`/`pays_debt` di `breakdown`/`build`; guardrails (§8); registrasi plugin + README + induk.

**Open Questions (untuk tahap perencanaan):**
- **Taksonomi `area` & matching.** Pakai taksonomi yang **sudah** dipakai `fanout`/`workspace.yaml.capabilities` (mis. `<app>/<module>`), jangan bikin baru. Granularitas matching `plan`/`fix` ↔ `debt.area` (per-app? per-module? per-file?) → tetapkan di plan; `build` mengambil `area` dari task yang sedang dieksekusi.
- **Algoritma dedup (`id`/tanda-tangan §5.3).** `id` deterministik dari `area`+slug ringkas `observed`? Cukup vs risiko tabrakan/duplikat halus. Finalisasi di plan.
- **Komputasi `shipped` (§5.2).** Cara `render-docs`/`/debt` menyilang `pays_debt: <id>` → status host (`feature.yaml`/`fix.yaml`). Biaya scan vs caching ringan.
- **Reader foundation.** v1: `owner: foundation` mengandalkan decide-now + Known Issues. Bila praktik menunjukkan debt fondasi cheap (jarang, tapi ada — mis. nama env var inkonsisten non-urgent) menumpuk, tambah `debt-aware` ke `architect`/`add-*`. Ditinjau setelah pemakaian.
- **Manual capture oleh manusia.** v1 capture = `build`-only. Bila manusia ingin mencatat debt di luar `build` (mis. saat review), tambah verb `/debt add` (steward menulis stub) — kandidat v1.1.
- **`critic` di `triage`.** Apakah `triage` butuh `critic`-pass ("debt nyata vs preferensi vs sebenarnya fondasional") seperti `intake`/`ship`, atau cukup penilaian inline. Default usul: inline; naikkan bila registry mulai banjir.
- **`reference.md` untuk `/debt`?** Default tidak (4-verb ringkas). Tinjau bila skema + aturan promote membengkak.
