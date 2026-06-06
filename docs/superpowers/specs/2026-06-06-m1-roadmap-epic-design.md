# M1 — Roadmap / Epic Decomposition (epic + depends_on metadata, warn-gate fix-light)

> Langkah-3, gap **M1** (MEDIUM) — roadmap/epic decomposition. Tanggal: **2026-06-06**. Repo `~/Developer/ai-boilerplate`, base `main` @ `1dba8d1`.
> Fix-light **terkunci** ke titik-awal prompt: field `epic` + `depends_on[]` di `feature.yaml` + **warn-gate** (BUKAN hard-block) + **sizing-check** di intake. Skill `roadmap` penuh = **DEFER**.

## 1. Ringkasan

Entrypoint produk hari ini langsung lompat ke satu `/feature` — tak ada apa pun yang mengubah *visi/backlog* jadi urutan fitur sadar-dependency. `feature.yaml` punya `name`/`status`/`created`/`sensitivity` saja: tak ada konsep "fitur ini bagian dari epik X" atau "fitur ini butuh fitur Y shipped dulu". Akibatnya solo-dev / AI-builder mengerjakan fitur dalam urutan ad-hoc; dependency implisit (mis. "checkout butuh cart dulu") cuma hidup di kepala, dan ketika fitur kegedean (epik menyamar jadi satu fitur) tak ada yang menahannya jadi backlog terurut.

M1 menambah **dua field metadata** ke `feature.yaml` — `epic: ""` (pengelompokan lintas-fitur; `""` = standalone) dan `depends_on: []` (fitur lain yang idealnya shipped dulu) — plus **dua kewaspadaan ringan**: (a) **warn-gate** di `feature` step 2 yang **memperingatkan** (bukan memblokir) bila sebuah `depends_on` belum shipped, dan (b) **sizing-check** advisory di `intake` step 4 yang menanyakan "fitur ini kegedean → pecah jadi epik?" sebelum menulis spec. Tak ada skill baru, tak ada folder `control/epics/`, tak ada mesin dependency-graph. Field ditulis di **DUA tempat creation** `feature.yaml` yang ada (`intake` step 1 + `feature` step 1) agar tak drift. Skill tetap **21**; rules tetap **5**.

> **Catatan jujur (metadata + advisory, BUKAN gate keras).** `epic`/`depends_on` adalah **metadata traceability** — cermin `kind:`/`corrects:`/`pays_debt:` di `tasks.yaml` yang "tak mengubah eksekusi, cuma menjelaskan". Tak ada skill yang **memblokir** karena `epic` salah atau `depends_on` belum shipped: warn-gate `feature` step 2 **menampilkan peringatan + minta konfirmasi user** lalu **boleh lanjut** (solo-dev sering sengaja kerjakan dependency paralel). Sizing-check `intake` step 4 **murni advisory** — usulan, user putuskan. Surface tempat logika beneran jalan = `feature/SKILL.md` step 2 (warn) + `intake/SKILL.md` step 4 (sizing). Tulis kejujuran ini di sana.

M1 **tak menggandakan** apa pun: `epic` bukan entitas pertama-kelas (tak ada folder/status epik — itu skill roadmap penuh, DEFER); `depends_on` bukan dependency-resolver (tak ada topo-sort / cycle-detection — cuma warn 1-hop). Ini lapisan tipis metadata + dua nudge di seam yang ADA.

## 2. Masalah

- **Tak ada lapisan yang mengubah visi → backlog terurut.** Lifecycle induk (§12) = `init → architect → wire → /feature → breakdown → build → ship`. Entrypoint kerja = `/feature <nama>` tunggal. Tak ada artifact/skill yang menampung "ini 12 fitur yang membentuk produk, urutannya begini karena dependency begitu". Backlog ada cuma di kepala user.
- **Dependency antar-fitur implisit & tak tercatat.** `feature.yaml` (`intake` step 1, `feature` step 1) cuma `name`/`status`/`created`/`sensitivity`. Tak ada `depends_on`. "Checkout butuh cart shipped dulu" tak punya rumah → AI/solo-dev bisa keliru memulai fitur yang fondasinya belum ada, baru sadar di tengah `build`.
- **Tak ada pengelompokan fitur (epik).** Produk multi-app tumbuh jadi puluhan `features/<nama>/` flat. Tak ada cara melihat "fitur-fitur ini satu tema/epik". `ask`/`render-docs` membaca `feature.yaml` tapi tak punya field pengelompokan untuk ditampilkan.
- **Tak ada rem ukuran di hulu.** `intake` step 4 (Cek feasibility kasar) membandingkan kebutuhan fitur vs `capabilities` app — tapi tak pernah bertanya "apakah ini SATU fitur, atau sebenarnya epik yang harus dipecah?". Fitur kegedean lolos jadi satu `business.md` raksasa → `fanout`/`plan`/`build` membengkak tanpa peringatan awal.

> **Ilustrasi (alat uji, desainnya tetap generik):** solo-dev Shopify-builder full-AI ingin "bikin storefront". Itu bukan satu fitur — itu epik (katalog, cart, checkout, payment, order-history), dengan dependency (checkout depends cart; payment depends checkout). Hari ini ia ketik `/feature storefront`, intake menulis satu spec gemuk, build berjalan 17 segmen tanpa ada yang pernah bilang "pecah dulu" atau "payment-mu nunggu checkout yang belum ada". M1 = `epic: storefront` + `depends_on: [checkout]` di tiap `feature.yaml` + nudge sizing di intake + warn "checkout belum shipped" di feature. **Catatan timing jujur:** warn "checkout belum shipped" itu berbunyi pada run di mana `depends_on: [checkout]` **sudah** tertulis (mis. setelah sizing-check intake mengusulkan pecah & user mengisi field, lalu fitur dijalankan ulang, atau user mengetik dependency manual) — **bukan** pada `/feature payment` run-pertama yang `depends_on`-nya masih kosong (lihat §6b). **Desain generik:** tak ada apa pun ecommerce-specific; epic/depends_on = string field universal.

## 3. Tujuan & Non-Tujuan

**Tujuan**
- Tambah **2 field** ke skema `feature.yaml`: `epic: ""` (nama epik pengelompok; `""` = standalone) + `depends_on: []` (daftar `<nama-fitur>` yang idealnya shipped dulu). Ditulis di **KEDUA** blok creation (`intake/SKILL.md` step 1 + `feature/SKILL.md` step 1) agar fitur lewat jalur mana pun dapat field yang sama. Default kosong → **backward-compatible** (fitur lama tanpa field = standalone, no-dep).
- **Warn-gate `depends_on`** di `feature/SKILL.md` step 2 (sebelum invoke `intake`): bila ada entri `depends_on` yang **belum shipped** (atau `dropped`/tak ditemukan), **tampilkan peringatan + minta konfirmasi** → user boleh **lanjut** (warn, BUKAN block). Degrade anggun bila referensi dangling.
- **Sizing-check advisory** di `intake/SKILL.md` step 4 (Cek feasibility kasar): tambah klausa heuristik "fitur ini kelihatan sebesar epik? → usulkan pecah jadi beberapa fitur + isi `epic`/`depends_on`". Advisory; user putuskan. Tak memblokir.
- `epic`/`depends_on` dapat dibaca pembaca `feature.yaml` yang ADA (`ask` jawab "dependency fitur X / fitur apa di epik Y") **secara opsional/cosmetic** — bukan inti fix.

**Non-Tujuan (seam bersih, anti scope-creep)**
- **Tak ada skill baru**, tak ada `/roadmap`/`/epic`. Skill tetap **21**. Nol churn `plugin.json`/`marketplace.json`/README/induk §12 (lifecycle — tak ada fase baru). Rules tetap **5** (M1 tak butuh shared rule — tak ada "otak bersama" lintas-skill; logikanya dua nudge lokal di intake & feature).
- **`epic` BUKAN entitas pertama-kelas.** Tak ada folder `control/epics/`, tak ada `epic.yaml`, tak ada status epik, tak ada agregasi. `epic` = string field di `feature.yaml`, titik. (Folder/status epik = skill roadmap penuh → **DEFER**, lihat §FLAG.)
- **`depends_on` BUKAN dependency-resolver.** Tak ada topo-sort, tak ada cycle-detection, tak ada auto-ordering, tak ada "jalankan fitur dalam urutan dependency". Cuma **warn 1-hop** ("X belum shipped"). Siklus/dangling tak crash karena warn-only (lihat §6 degrade).
- **Tak ubah eksekusi.** `breakdown`/`build`/`ship`/`fanout`/`plan` TIDAK membaca `epic`/`depends_on` (kecuali bila kelak diinginkan — bukan M1). Field = metadata, tak menyetir build/gate apa pun. Cermin `kind:`/`corrects:` tasks.yaml.
- **Tak ada hard-block di mana pun.** Warn-gate = peringatan + lanjut. Sizing-check = usulan. Tak ada STOP baru. (Satu-satunya STOP di lifecycle tetap milik skill lain — `build` needs_human/migrate, `ship` Security Gate — M1 tak menyentuhnya.)
- **`drop` tak dapat mesin keras pembersih `depends_on`.** Bila fitur yang jadi `depends_on` fitur lain di-drop, dangling reference **ditangani oleh degrade warn-gate** (warn "tak ditemukan/dropped"), bukan oleh mesin keras di `drop` (itu balloon → §FLAG). Maksimum: pengingat lunak (opsional, cermin vendor-reminder `drop` step 3).
- **Tak render `epic`/`depends_on` sebagai badge/section baru di `render-docs`** sebagai kewajiban — paling jauh cosmetic bila trivial. Cermin preseden M6 (metadata durable dibaca skill, bukan dibikin doc baru). Bila penulis tergoda bikin "roadmap view" → §FLAG.
- **Tak menyentuh `fix.yaml`/`debt.yaml`.** Epic/dependency = konsep fitur. Fix/debt punya `relates_to`/`pays_debt` sendiri.

## 4. Skema — 2 field baru di `feature.yaml`

`feature.yaml` **tak punya file template** (diverifikasi `find plugin/template -name feature.yaml` → **tanpa hasil/no matches**) — ia di-CIPTAKAN di dua tempat dengan blok YAML hampir-kembar. M1 menambah field di **KEDUA** blok. Urutan field sepakat (kontrak Stream A — `sensitivity` JANGAN digeser; banyak skill grep-anchor ke barisnya; field baru DITAMBAH SETELAHnya):

```yaml
name: <fitur>
status: draft
created: <YYYY-MM-DD>
sensitivity: []        # (existing L1/M6 — JANGAN ubah posisi/teks)
epic: ""               # (M1) nama epik pengelompok; "" = standalone
depends_on: []         # (M1) [<nama-fitur>] yang idealnya shipped dulu; warn-gate (BUKAN block)
```

- **`epic: ""`** — string bebas. `""` (kosong) = fitur standalone, tak ikut epik. Diisi/diusulkan saat sizing-check `intake` step 4 (bila fitur dipecah dari epik) atau diketik user manual. **Bukan** enum, **bukan** referensi ke entitas — sekadar label pengelompok untuk `ask`/`render-docs` baca.
- **`depends_on: []`** — daftar nama fitur (string) yang idealnya `shipped` sebelum fitur ini dibangun. `[]` = tak ada dependency. Dipakai warn-gate `feature` step 2. **Bukan** dependency-graph — cuma daftar 1-hop yang di-warn.
- **BUG-GUARD colon-space:** `epic: ""` aman (value `""` tanpa `: `); `depends_on: []` aman (value `[]`). Komentar inline pakai **em-dash/kurung**, TANPA `: ` di dalam value. Verifikasi pasca-edit kedua blok bersih dari `: ` di posisi value.
- **Backward-compat:** field kosong/absen = standalone, no-dep. Pembaca degrade: `feature.yaml` lama tanpa `epic`/`depends_on` → perlakukan `epic` kosong & `depends_on []`. Tak error.
- **Default-write:** creation site SELALU menulis kedua field dengan default (`epic: ""`, `depends_on: []`) — biar fitur baru konsisten punya slotnya (cermin `sensitivity: []` yang selalu ditulis kosong).

**Asimetri vs `sensitivity`:** `sensitivity` (L1/M6) = APA yang sensitif → menyetir KEDALAMAN Security Gate `ship`. `epic`/`depends_on` (M1) = traceability/urutan → **TIDAK** menyetir gate mana pun; warn-only di `feature`. Beda konsumen, beda sifat (sensitivity = mempengaruhi gate; M1 = metadata + nudge). Tak overlap.

## 5. Decisions (tiap fork desain + alternatif ditolak — ganti brainstorming 1-1)

> Tiap keputusan di bawah adalah fork yang penulis spec putuskan sendiri. Plain-language biar user bisa veto.

### D1. Field di `feature.yaml` — BUKAN entitas epik pertama-kelas.
**Putusan:** `epic` & `depends_on` jadi string/list field di `feature.yaml`. Tak ada folder `control/epics/`, tak ada `epic.yaml`/status epik.
**Alternatif ditolak:** (a) folder `control/epics/<nama>/epic.yaml` dengan daftar fitur + status agregat. Ditolak: itu skill roadmap penuh (butuh skill penulis epik, agregasi status, sinkronisasi dua arah saat fitur drop/ship) = jauh melebihi "fix-light"; prompt eksplisit DEFER skill roadmap. (b) field `epic` sebagai referensi tervalidasi ke epik yang harus ada. Ditolak: butuh validator + registry epik = mesin baru. **Alasan pilih:** string field = nol mesin, langsung bisa dibaca `ask`/`render-docs`, cermin pola metadata `tasks.yaml` (`kind`/`corrects`).

### D2. `depends_on` = warn 1-hop, BUKAN dependency-graph.
**Putusan:** warn-gate `feature` step 2 cek tiap entri `depends_on` apakah `shipped`; bila tidak → warn + minta konfirmasi → lanjut. Tak ada transitive resolution, topo-sort, atau cycle-detection.
**Alternatif ditolak:** (a) topo-sort + auto-ordering backlog. Ditolak: roadmap-engine penuh, DEFER. (b) cycle-detection (deteksi A→B→A). Ditolak: butuh graph-walk; karena warn-only (tak deadlock) siklus jinak — cukup AKUI keterbatasan di spec. (c) hard-block sampai dependency shipped. Ditolak: prompt eksplisit "warn-gate BUKAN hard-block"; solo-dev sering sengaja kerjakan dependency paralel/out-of-order. **Alasan pilih:** warn 1-hop = sinyal cukup ("eh, fondasimu belum ada") tanpa mesin & tanpa memenjarakan user.

### D3. Sizing-check di `intake` step 4 (feasibility), BUKAN step 1.
**Putusan:** nudge "ini kegedean → pecah jadi epik?" hidup di `intake` step 4 (Cek feasibility kasar) — tempat intake sudah membandingkan kebutuhan vs kapabilitas.
**Alternatif ditolak:** (a) di `feature` step 1 (sebelum intake). Ditolak: feature step 1 cuma bikin folder + yaml; sizing butuh konteks kebutuhan fitur yang baru muncul di Q&A intake. (b) skill `sizing`/`triage` terpisah. Ditolak: skill baru, balloon. **Alasan pilih:** step 4 sudah punya konteks "apa yang dibutuhkan vs apa yang ada" — sizing-check menumpang konteks itu secara alami; advisory, tak ubah gate step 7.

### D4. Warn-gate di `feature`, BUKAN di `intake`.
**Putusan:** cek `depends_on`-belum-shipped terjadi di `feature/SKILL.md` step 2, tepat sebelum invoke `intake`.
**Alternatif ditolak:** (a) di `intake` step 2 (baca knowledge). Ditolak: `intake` bisa dipanggil standalone & fokus bisnis-1-fitur; pengecekan urutan antar-fitur adalah tanggung jawab konduktor (`feature`). (b) di `build`/`ship`. Ditolak: terlalu hilir — peringatan urutan paling berguna SEBELUM pipeline mulai. **Alasan pilih:** `feature` = konduktor pipeline (step 2 menjalankan tahap berurutan) → tempat alami untuk warn "fitur ini punya dependency belum shipped, lanjut?". Catatan: bila user panggil `intake` langsung (bypass feature), warn dilewati — itu wajar (warn = layanan konduktor, bukan invarian keras).

### D5. "Satisfied" = `shipped`. Selain itu = warn.
**Putusan:** `depends_on: [X]` dianggap terpenuhi HANYA bila `features/X/feature.yaml` `status: shipped`. `active`/`draft`/`dropped`/tak-ada → warn (pesan beda per kasus).
**Alternatif ditolak:** (a) `active` juga dianggap cukup. Ditolak: "active" = sedang dibangun, belum tentu jadi; fondasi yang belum shipped masih berisiko. (b) abaikan `dropped` diam-diam. Ditolak: `depends_on` ke fitur dropped = sinyal penting (rencanamu mungkin basi) → warn eksplisit "X dropped". **Alasan pilih:** `shipped` = satu-satunya status yang berarti "fondasi ini beneran ada & live"; selebihnya layak diperingatkan. Warn membedakan kasus (belum shipped / dropped / tak ditemukan) untuk degrade jelas.

### D6. `drop` TIDAK dapat mesin pembersih `depends_on`.
**Putusan:** saat fitur di-drop, M1 tak menambah logika ke `drop` untuk memburu & membersihkan `depends_on` di fitur lain. Dangling ditangani degrade warn-gate.
**Alternatif ditolak:** mesin keras di `drop` step 3 yang scan semua `feature.yaml` & strip nama yang di-drop dari `depends_on[]`. Ditolak: itu O(n) graph-mutation = balloon; lagipula menghapus diam-diam menghilangkan sinyal ("rencanamu basi"). **Alasan pilih:** warn-gate sudah degrade ("X dropped — lanjut?") → user diberi tahu, bukan disembunyikan. Maksimum yang boleh = pengingat lunak opsional (cermin vendor-reminder `drop`), TIDAK wajib M1.
**Catatan implementer (jangan tergoda "preserve"):** `drop/SKILL.md` step 4 (verified, baris ~24-31) **menulis ulang** `feature.yaml` jadi blok tetap 5-baris (`name`/`status: dropped`/`created`/`reason`/`dropped_at`) — pola **PRA-ADA** yang sudah membuang `sensitivity`, dan otomatis akan membuang `epic`/`depends_on` fitur yang di-drop juga. Ini **jinak**: fitur dropped tak pernah dibangun, dan warn-gate fitur lain membaca `status: dropped` X (yang **dipertahankan**), bukan `depends_on` X. M1 **tidak** meminta `drop` mempertahankan `epic`/`depends_on` — menambah logika "preserve" = balloon tanpa manfaat (§FLAG).

### D7. Tak ada shared rule baru.
**Putusan:** M1 tak menambah `rules/roadmap.md`. Logika hidup inline di dua surface (intake step 4, feature step 2).
**Alternatif ditolak:** shared rule "otak bersama" cermin `compliance-risk.md`. Ditolak: shared rule berguna ketika ≥3 skill berbagi resep yang sama (kasus M6). M1 cuma dua nudge lokal di dua skill berbeda dengan logika berbeda (sizing vs warn) — tak ada resep bersama untuk dipusatkan. **Alasan pilih:** rules tetap 5; tak ada churn induk §8/§17 rules. Hindari rule yang cuma dirujuk sekali (anti-overhead).

## 6. Wiring — di mana M1 nempel

### 6a. `feature.yaml` creation ×2 (skema — penulis: intake & feature)
Tambah `epic`/`depends_on` ke KEDUA blok creation (§4). Anchor verbatim BEDA per file (komentar `sensitivity` beda):
- `intake/SKILL.md` step 1: anchor `sensitivity: []        # [] | [payments] | [pii] | [payments, pii] — diusulkan di step 7, dikonfirmasi user`.
- `feature/SKILL.md` step 1: anchor `sensitivity: []        # [] | [payments] | [pii] | [payments, pii] — diusulkan intake, dikonfirmasi user`.
Di kedua tempat, sisip 2 baris field SETELAH baris `sensitivity` (no-renumber; field append). **WAJIB kedua tempat** (risiko drift utama: fitur lewat jalur lain kehilangan field).

### 6b. `feature` — warn-gate depends_on (konduktor, tempat logika warn jalan)
`feature/SKILL.md` step 2 (anchor heading `### 2. Jalankan tahap berurutan dengan gate`): sisip sub-klausa **sebelum** sub-langkah-1 (invoke intake) — "**Cek dependency (warn, bukan block):** bila `feature.yaml` punya `depends_on` non-kosong, untuk tiap `<dep>` baca `control/features/<dep>/feature.yaml`. Bila `status` ≠ `shipped` (atau `dropped`/tak ditemukan), **tampilkan peringatan** (mis. `dep <X> belum shipped (status active)` / `<X> dropped — rencana mungkin basi` / `<X> tak ditemukan`) + **minta konfirmasi lanjut**. Ini **peringatan, bukan palang** — user boleh lanjut (dependency sering dikerjakan paralel). Degrade: `depends_on` kosong/absen → skip diam-diam." Honest-note di sini (advisory/warn-only).
> **Kapan warn-gate ini beneran berbunyi (jujur soal timing):** warn-gate baca `feature.yaml.depends_on` di step 2 **sebelum** invoke intake. Pada `/feature <nama>` **run-pertama**, step 1 baru saja menulis `depends_on: []` (default kosong) dan satu-satunya yang mengisi `depends_on` adalah usulan sizing-check intake (step 4) yang jalan **belakangan** → jadi di run-pertama warn-gate **selalu** melihat `depends_on` kosong & skip diam-diam. Warn baru bermakna bila `depends_on` **sudah ter-deklarasi lebih dulu**: user mengisinya manual sebelum run, **atau** sesi/run berikutnya (feature step 1 mempertahankan yaml yang sudah ada). M1 **tak** meng-klaim `/feature` run-pertama auto-mendeteksi dependency belum-shipped — warn-gate menjaga run lanjutan / backlog yang sudah berisi urutan, bukan tebakan dari layar kosong.

### 6c. `intake` — sizing-check advisory (tempat logika sizing jalan)
`intake/SKILL.md` step 4 (anchor heading `### 4. Cek feasibility kasar` + baris isinya): tambah klausa SETELAH perbandingan kapabilitas — "**Sizing-check (advisory):** bila kebutuhan fitur terlihat sebesar epik (banyak app/flow/milestone independen, scope melar), **usulkan** pecah jadi beberapa fitur lebih kecil — isi `epic: <nama-epik>` (pengelompok) + `depends_on` (urutan) di tiap `feature.yaml`. Usulan saja; user putuskan. Tak memblokir." (Sub-klausa, BUKAN renumber step.)
> Catatan anchor: M6 sudah menyentuh intake step 2/5/7 (`risks.md`), TIDAK menyentuh step 4 → step 4 bersih untuk M1.

### 6d. `ask` — read-surface epic/depends_on (OPSIONAL, cosmetic)
`ask/SKILL.md` baris tabel `| Status: fitur apa saja, draft/active/shipped, perilaku 1 fitur | `features/*/feature.yaml` (+ `business.md`) |` (baris 26 — **backtick-eksak** pada path & `business.md`; `grep -Fc -e` byte-eksak = 1): ask sudah baca `feature.yaml` → BISA jawab "dependency fitur X / fitur apa saja di epik Y" dengan membaca `epic`/`depends_on`. **Opsional** (cosmetic, bukan inti fix). Bila ditambah: perluas frasa **sel-pertama** baris itu — yang bebas-backtick (mis. `…perilaku 1 fitur, epik & dependency`) — sel-kedua (path) JANGAN diutak-atik; TANPA baris tabel baru, TANPA `: ` di teks. Bila penulis-plan ragu → SKIP (jangan balloon).

### 6e. Parent-spec — lihat §7.

**TAK disentuh (eksplisit):** `breakdown`/`build`/`ship`/`fanout`/`plan` (tak baca epic/depends_on — field = metadata murni, tak menyetir eksekusi/gate); `drop` (no mesin pembersih — D6); `render-docs` (tak render roadmap view — Non-Tujuan); `fix.yaml`/`debt.yaml`; shared rules (D7 — tetap 5); skill-count (21); `plugin.json`/`marketplace.json`/README; mekanik `sensitivity` (tak digeser); `init` (feature.yaml tak punya template → init tak menyentuhnya).

## 7. Parent-spec amendments (`docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`)

- **§7 control-tree (anchor verified match=1, byte-eksak: `│       ├── feature.yaml  # status + metadata`):** perkaya komentar inline → `│       ├── feature.yaml  # status + metadata (sensitivity; epic/depends_on M1)`. **TANPA `: `** dalam komentar (pakai `;`/kurung). Tak ubah box-drawing/alignment (cuma perpanjang komentar setelah `#`). Tak menambah baris tree (epic BUKAN entitas → tak ada `epics/` dir).
- **§9 `intake` skill (anchor verified, line 190: `- **Output:** `features/<nama>/business.md` + promosi knowledge durable ke `business/` + usulan tag `sensitivity` (`payments`/`pii`, cross-check `invariants.md`) di `feature.yaml`.`):** tambah klausa Perilaku di entri `intake` — sisip baris/klausa "**sizing-check** advisory (fitur sebesar epik → usulkan pecah + isi `epic`/`depends_on`)" di bagian Perilaku intake (line 189, anchor `- **Perilaku:** Q&A **level bisnis** (bukan teknis); cek feasibility kasar dari `capabilities`; jalankan **challenge checklist**; panggil `critic` di gate penting.`) → append `; sizing-check advisory (epik → usulkan pecah)`. (Sisip frasa, BUKAN renumber/baris baru.)
- **§9 `feature` (konduktor) (anchor verified, line 184: `- **Perilaku:** buat `features/<nama>/` (`feature.yaml` status `draft`) → jalankan `intake` →(gate)→ `fanout` →(gate)→ `plan` semua app yang kena →(gate). Setelah gate `plan` terakhir lulus → status otomatis `active`.`):** sisip klausa warn-gate SESUDAH "status `draft`)" → "(... status `draft`; **warn bila `depends_on` belum shipped — bukan block, M1**) → jalankan `intake` ...". **TANPA `: `** dalam klausa. (Sisip frasa, BUKAN renumber.)
- **§12 Lifecycle:** **TAK ada fase baru** — M1 tak menambah langkah lifecycle (tak ada `roadmap` di rantai `init→architect→wire→/feature→…`). Tak ada edit §12. (Eksplisit dicatat agar reviewer tak mengira lifecycle berubah.)
- **§17 Komponen:** **Skills tetap 21** (line 304 — tak ada skill baru, tak ada edit). **Rules tetap 5** (line 306 — tak ada rule baru, tak ada edit). Knowledge `control/` (line 307) **tak berubah** (epic/depends_on = field DALAM `feature.yaml`, bukan node knowledge baru → tak masuk daftar §17). (Eksplisit dicatat: M1 tak menyentuh §17.)
- **§18 Open Questions (anchor line 313: `- Format `feature.yaml` final (field minimal).`):** M1 **menjawab sebagian** open-question ini (menambah `epic`/`depends_on` ke field minimal). Opsional: perbarui baris jadi mencatat `epic`/`depends_on` ditambahkan M1. Bila penulis-plan memilih edit: sisip catatan, TANPA `: ` problematik. (Opsional — boleh dilewati; field minimal toh masih bisa berevolusi.)

## 8. Generik (jaminan lintas-produk)

- `epic`/`depends_on` = string/list field universal → tak meng-hardcode domain/stack/jurisdiksi apa pun. "epik" & "dependency fitur" = konsep produk generik (berlaku ecommerce, SaaS, internal-tools, apa pun).
- Warn-gate by-understanding (baca status `feature.yaml` fitur lain), bukan rule hardcode.
- Sizing-check = heuristik bahasa-natural ("sebesar epik?"), bukan ambang numerik hardcode.
- **Degrade-anggun** di tiap titik: field kosong/absen → standalone/no-dep, jalan normal; `depends_on` dangling (dropped/tak ada) → warn jinak, tak crash; siklus `depends_on` → warn-only, tak deadlock (no topo-sort = no infinite loop).

## 9. Edge case & degrade

| Kasus | Perilaku |
|---|---|
| `feature.yaml` lama tanpa `epic`/`depends_on` | Pembaca degrade: `epic` kosong, `depends_on []` (standalone, no-dep). Tak error. Backward-compat. |
| `epic: ""` (default) | Fitur standalone, tak ikut epik. `ask`/`render-docs` tampilkan tanpa pengelompokan. |
| `depends_on: []` (default) | Warn-gate skip diam-diam (tak ada dep untuk dicek). |
| `depends_on: [X]`, X `shipped` | Terpenuhi (D5) → no warn, lanjut normal. |
| `depends_on: [X]`, X `active`/`draft` | Warn "dep X belum shipped (status active)" + konfirmasi → user boleh lanjut (warn, bukan block). |
| `depends_on: [X]`, X `dropped` | Warn "X dropped — rencana mungkin basi" + konfirmasi → lanjut. Sinyal eksplisit (D5). |
| `depends_on: [X]`, X tak ada (salah ketik / belum dibuat) | Warn "X tak ditemukan" + konfirmasi → lanjut (degrade, tak crash). |
| Siklus `depends_on` (A→B, B→A) | Warn-only → tak deadlock (no topo-sort). Spec AKUI keterbatasan: warn 1-hop, bukan cycle-detection. |
| Fitur X di-drop, X jadi `depends_on` fitur Y | Dangling ditangani warn-gate Y ("X dropped" — D6). `drop` TIDAK auto-strip. Pengingat lunak opsional. |
| Fitur X sendiri di-drop (punya `epic`/`depends_on`) | `drop` step 4 menulis ulang `feature.yaml` X jadi blok 5-baris (status `dropped`) → `epic`/`depends_on` X **ikut terbuang** (pola pra-ada, sama spt `sensitivity`). Jinak: fitur dropped tak dibangun & warn-gate lain baca `status: dropped` X, bukan field-nya. Implementer JANGAN tambah "preserve" (D6, §FLAG). |
| `intake` dipanggil standalone (bypass `feature`) | Warn-gate dilewati (warn = layanan konduktor `feature`, D4). Field tetap ditulis (intake step 1 creation). Wajar. |
| Sizing-check: fitur memang sebesar epik | `intake` step 4 **usulkan** pecah + isi epic/depends_on (advisory). User putuskan; tak memblokir. |
| Sizing-check: fitur ukuran wajar | Tak ada usulan; intake jalan normal. |

## 10. Honesty-note (advisory/metadata vs gate — preseden M6 §1)

- **`epic`/`depends_on` = METADATA traceability**, BUKAN field yang menyetir eksekusi/gate. Cermin `kind:`/`corrects:`/`pays_debt:` di `tasks.yaml` ("metadata, tak ubah eksekusi"). Tak ada skill yang menjalankan/menghalangi build berdasarkan field ini. Tulis jujur di komentar inline `feature.yaml` (kedua blok): `epic`/`depends_on` = pengelompok & urutan, bukan kontrol eksekusi.
- **Warn-gate `feature` step 2 = PERINGATAN, BUKAN palang keras.** Surface tempat logika beneran jalan = `feature/SKILL.md` step 2. Tulis eksplisit "warn, bukan block — user boleh lanjut". JANGAN gunakan kata "STOP"/"blokir"/"gagal" — pakai "peringatan"/"konfirmasi"/"boleh lanjut". (Cermin honesty M6: kalau advisory, katakan advisory.)
- **Warn-gate bermakna hanya bila `depends_on` ter-deklarasi lebih dulu (jujur soal timing — §6b).** Di `/feature` run-pertama, `depends_on` masih default `[]` saat step 2 mengeceknya (sizing-check yang mengisinya jalan belakangan di intake step 4) → warn skip. JANGAN klaim/tulis bahwa `/feature` run-pertama "auto-mendeteksi dependency belum-shipped"; warn menjaga run lanjutan / backlog yang sudah berisi urutan, atau `depends_on` yang user isi manual.
- **Sizing-check `intake` step 4 = USULAN murni.** Surface = `intake/SKILL.md` step 4. Tulis "usulkan/advisory; user putuskan; tak memblokir". Tak mengubah gate step 7 intake.
- **`depends_on` = warn 1-hop, BUKAN resolver.** Spec & shipped-text AKUI keterbatasan jujur: tak ada topo-sort/cycle-detection; siklus & dangling ditangani sebagai warn jinak. JANGAN klaim "dependency management" — klaim "warn dependency belum shipped".
- **Read-surface `ask` = cosmetic/opsional.** Bila ditambah, jangan klaim ask "mengelola roadmap" — ask sekadar BACA & jawab field yang ada.

## 11. Self-review checklist awal

- [ ] **2 field, 2 tempat:** `epic`/`depends_on` ditambah di KEDUA blok creation (`intake/SKILL.md` step 1 + `feature/SKILL.md` step 1), default `epic: ""` & `depends_on: []`, SETELAH baris `sensitivity` (no-geser). Anchor verbatim BEDA per file (komentar sensitivity beda — jangan salah-paste).
- [ ] **colon-space bersih:** `epic: ""` & `depends_on: []` aman; komentar inline & teks edit TANPA `: ` di value/qualifier. Cek pasca-edit kedua blok + parent §7/§9 edits.
- [ ] **no-renumber:** warn-gate = sub-klausa di `feature` step 2 (sebelum sub-1); sizing = sub-klausa di `intake` step 4. Tak renumber step mana pun. Cross-ref "step N" tetap valid.
- [ ] **warn-only language:** teks shipped di feature step 2 pakai "peringatan/konfirmasi/boleh lanjut" — TIDAK "STOP/blokir/gagal/hard". Sizing pakai "usulkan/advisory".
- [ ] **degrade verified:** field kosong/absen → standalone/no-dep; dangling/dropped/cycle → warn jinak tak crash; intake-standalone → warn dilewati wajar.
- [ ] **no scope-creep:** tak ada folder `control/epics/`, tak ada skill baru, tak ada shared rule baru (rules tetap 5), tak ada mesin pembersih di `drop`, tak ada topo-sort/cycle-detect, tak ada render-docs roadmap-view, `breakdown`/`build`/`ship` tak baca field. Kalau ada → FLAG.
- [ ] **parent-spec:** §7 komentar feature.yaml diperkaya (no baris tree baru); §9 intake (sizing) + §9 feature (warn) klausa disisip; §12 TAK berubah; §17 skills=21 & rules=5 TAK berubah (eksplisit). Anchor §7/§9 verified `grep -Fc -e` byte-eksak pra-commit.
- [ ] **honesty di surface benar:** metadata-note di komentar feature.yaml; warn-note di feature step 2; advisory-note di intake step 4 — di tempat logika beneran jalan (preseden M6 §1).
- [ ] **anti-fiksi:** semua artefak yang dirujuk ADA di disk (feature.yaml creation ×2, ask tabel feature.yaml, parent §7/§9 anchor) — `intake/reference.md` TAK ADA (jangan rujuk). `feature.yaml` tak punya template (jangan rujuk file template).
- [ ] **skill-count tetap 21**, no edit `plugin.json`/`marketplace.json`/README.
