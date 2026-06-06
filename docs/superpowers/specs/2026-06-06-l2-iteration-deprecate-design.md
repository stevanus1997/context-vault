# L2 — Iterasi-v2 / Deprecate Lifecycle (gap, fix-light)

> Langkah-3, gap **L2** (LOW) — iterasi/pensiun fitur pasca-`shipped`. Tanggal: **2026-06-06**. Repo `~/Developer/ai-boilerplate`, base `main`.
> **Status brainstorming:** spec ini MENGGANTI brainstorming 1-1 (§2 mendokumentasikan tiap fork desain biar user bisa veto). USULAN FIX awal (titik mula, BUKAN keputusan): "promosiin §S4.1 pipeline-hardening (immutable old-folder + `<nama>-v2` + status `deprecated`)". Hasil stress-test: **usulan itu MELAMPAUI fix-light** (§2 Decision-0, scopeFlags) → spec ini memilih jalur minimal-viable yang jujur dan men-FLAG sisanya sebagai spec terpisah.
> **Pemisahan dari L3:** gap **L3** (render-docs makna badge `shipped` ≠ "live") DULU di-bundel di sini, kini **di-split** jadi spec berdiri-sendiri `docs/superpowers/specs/2026-06-06-l3-render-docs-honest-label-design.md` (selaras handoff `handoff-2026-06-06-langkah-3-lanjut.md` Open questions yang mendaftarkan L2 & L3 sebagai DUA item terpisah). Spec L2 ini **tidak** lagi mengedit `template.html` line 73 maupun `render-docs/SKILL.md` §4 line 40 — semua edit render-docs/badge `shipped` **milik spec L3**. Spec L2 cukup CROSS-REF ke spec L3 (Decision-1). **Single source of truth (induk §4): hanya SATU spec yang memiliki tiap edit fisik.**

---

## 0. TL;DR (baca dulu)

**L2 (iterasi-v2 / deprecate) MELAMPAUI fix-light → di-FLAG.** Usulan handoff mempromosikan §S4.1 pipeline-hardening, TAPI §10-4 spec itu **sudah memutuskan** S4.1 = "spec TERPISAH … status-machine yang membentang `feature`/`ship`/`drop`/`render-docs`". Menambah enum `deprecated` + folder `<nama>-v2` immutable menyentuh sumber-kebenaran induk §12 + ≥5 skill. Itu fitur lifecycle penuh, bukan light.

**Pilihan minimal-viable yang spec ini SHIP: doc-hint murni** (catat workaround manual: iterasi fitur `shipped` = bikin fitur baru + `/fix` untuk bug) **tanpa machinery enum/folder**. Spec ini jujur bahwa doc-hint **tidak menutup gap inti** — gap inti tetap masuk daftar spec-terpisah (§4 amendment §16 future).

**Net:** L2 = ship doc-hint kecil (1 bullet di `feature/SKILL.md` `## Catatan`) + 1 item Future di induk §16 + FLAG sisanya. Skill tetap **21**. Tak ada enum status baru. Tak ada folder `-v2` machinery. **L3 di luar spec ini** (spec terpisah).

---

## 1. Masalah & konteks

### 1.1 Trigger konkret (ilustrasi Shopify, desain tetap generik)

Solo-dev full-AI sudah `ship` fitur `checkout-kupon` (status `feature.yaml: shipped`, PR dibuka). Beberapa minggu kemudian ingin `checkout-kupon` versi-2 (multi-kupon + kombinasi). Bukan bug (jadi bukan `/fix`), bukan fitur yang benar-benar baru (mau "lanjutkan" yang lama). **Disk hari ini tak punya jalur:** `feature` cuma membuat folder `draft` baru dari nol; `drop` hanya untuk `draft`/`active` (frontmatter `drop/SKILL.md` line 3 + step 4 set `dropped`) — **tak menangani `shipped`**; tak ada `deprecate`/`<nama>-v2`/`supersedes`. Fitur `shipped` adalah terminal de-facto tanpa jalur pensiun atau penerus.

> **Catatan L3 (di luar scope):** trigger ke-2 (stakeholder salah-baca badge `shipped` = "live di produksi" di render-docs) ditangani spec **L3** berdiri-sendiri (`2026-06-06-l3-render-docs-honest-label-design.md`). Spec L2 ini tidak menyentuhnya.

### 1.2 Kenapa LOW

L2 menyentuh permukaan kecil dan, dalam jalur minimal-viable, **doc-only** — nol logika baru, nol enum baru. Gap nyata tapi operasional ("apa yang harus kulakukan untuk v2?") bisa ditutup dengan catatan murah tanpa membangun status-machine penuh.

### 1.3 Apa yang TERVERIFIKASI di disk (anti-fiksi)

| Klaim | Disk | Bukti |
|---|---|---|
| Status enum hanya 4 (no `deprecated`) | **TIDAK ADA `deprecated`** | induk §12 tabel; `feature/SKILL.md` line 18 skeleton `status: draft` |
| Folder `<nama>-v2` / immutable / reopen / superseded | **TIDAK ADA** | grep `deprecated\|-v2\|reopen\|superseded` di `plugin/` = **nol** |
| `drop` menangani `shipped` | **TIDAK** | `drop/SKILL.md` line 3 frontmatter + step 4 = hanya `draft`/`active` |
| §S4.1 di-defer ke spec terpisah | **YA** | pipeline-hardening §S4.1 line 158 + §10-4 line 198 ("spec TERPISAH … status-machine membentang feature/ship/drop/render-docs") |
| `ship` set `shipped` = PR dibuka (bukan merged/live) | **ADA & TERKONFIRMASI** | `ship/SKILL.md` line 45 (`gh pr create`) + line 46 (set shipped) + line 8 ("byproduct") |
| Induk §16 future `in-review`/auto-merge | **ADA** | line 300 |
| `ask` baca status `draft/active/shipped` | **ADA** | `ask/SKILL.md` line 26 |
| `fix` mode-deteksi baca `shipped` | **ADA** | `fix/SKILL.md` line 20/23 |
| `feature.yaml` dirujuk banyak pembaca (argumen anti-balloon) | **≥10 file** | grep `feature.yaml` di `plugin/skills/` = ask, breakdown, build, debt, drop, fix/reference.md, intake, render-docs, ship (+ feature & intake sebagai PENULIS skeleton) |

---

## 2. Decisions (tiap fork + alternatif ditolak + alasan) — GANTI brainstorming

### Decision-0 — L2: ship doc-hint minimal, FLAG machinery penuh sebagai spec terpisah. (PALING PENTING — user bisa veto.)

**Konteks fork:** usulan handoff = promosiin §S4.1 (enum `deprecated` + folder `<nama>-v2` immutable + supersedes). ATURAN KERAS: "fix LOW = fix-light; kalau usulan jauh lebih besar dari light, FLAG, jangan balloon jadi skill penuh."

**Bukti balloon (dari disk):**
- §S4.1 (pipeline-hardening line 158) = folder `<nama>-v2` di-seed dari fitur lama + folder lama immutable + status `deprecated` + "`shipped` = PR dibuka bukan merged/live" + rollback/hotfix + "`drop` menstempel `tasks.yaml` terminal".
- §10-4 (line 198) **sudah memutuskan**: S4.1 = **"spec TERPISAH — di luar scope … (status-machine yang membentang `feature`/`ship`/`drop`/`render-docs`)."**
- Menambah enum `deprecated` ke `status` menyentuh SEMUA pembaca status: induk §12 tabel (sumber kebenaran), §16 future, render-docs §4, `ask/SKILL.md` line 26 (`draft/active/shipped`), `fix/SKILL.md` line 20/23 mode-deteksi, plus `feature`/`drop`/`ship` guard. Itu **jauh** dari light.

**Keputusan:** spec ini SHIP hanya **doc-hint murni** (no machinery):
1. `feature/SKILL.md` `## Catatan` (line 44, anchor "transisi `shipped`/`dropped` ditangani `ship`/`drop`") → tambah satu bullet workaround: fitur `shipped` yang mau diiterasi = **buat fitur baru** (mis. `<nama>-v2` sebagai nama biasa, bukan machinery) untuk perubahan substansial / `/fix` untuk perbaikan bug; jalur `deprecate`/penerus first-class = **future (spec terpisah)**.
2. Daftarkan lifecycle pasca-`shipped` (iterasi-v2/deprecate) sebagai item Future eksplisit di induk §16 (§4) — agar gap tercatat, bukan hilang.

**Alternatif ditolak:**
- **(A) Promosiin §S4.1 penuh sekarang** (usulan asli) — DITOLAK: balloon, kontradiksi keputusan §10-4 yang sudah mengunci "spec terpisah", menyentuh sumber-kebenaran §12 + ≥5 skill. Bukan light.
- **(B) Tambah enum `deprecated` saja (tanpa folder `-v2`)** — DITOLAK: enum sendiri sudah menyentuh semua pembaca status (induk §12, ask, fix, render-docs filter, drop/ship guard) → bukan light, dan setengah-jadi (status tanpa jalur seed/immutable = menggantung).
- **(C) Tambah field `supersedes:`/`deprecated_by:` ke `feature.yaml`** — DITOLAK untuk spec ini: `feature.yaml` dirujuk **≥9 pembaca** (ask/breakdown/build/debt/drop/fix/render-docs/ship/intake), `feature`+`intake` sebagai penulis skeleton; menambah field = kontrak baru lintas pembaca + overlap dengan Stream A (`sensitivity`). Bila kelak diambil, ditaruh **di bawah `sensitivity`** (kontrak §5) — tapi itu material spec-terpisah, bukan light.
- **(D) Tidak melakukan apa-apa untuk L2** — DITOLAK: gap nyata (fitur `shipped` terminal tanpa jalur penerus). Doc-hint murah menutup kasus operasional ("apa yang harus kulakukan untuk v2?") tanpa machinery, sambil JUJUR bahwa gap inti tetap future.

**Honesty (preseden M6 Lesson #18):** doc-hint **tidak menutup gap inti** (tak ada `deprecate` first-class, tak ada immutable-old-folder, render-docs tak tahu fitur mana men-supersede mana). Spec ini menyatakan itu apa adanya, tidak mengklaim "L2 selesai".

### Decision-1 — L3 (makna badge `shipped`) didelegasikan PENUH ke spec terpisah. (Single source of truth — induk §4.)

**Fork:** apakah spec L2 ini ikut memuat L3 (badge `shipped` ≠ live) atau menyerahkannya ke spec L3 berdiri-sendiri?

**Keputusan:** **delegasi penuh.** Spec L3 (`docs/superpowers/specs/2026-06-06-l3-render-docs-honest-label-design.md`) adalah **satu-satunya** pemilik edit ke `template.html` line 73 + `render-docs/SKILL.md` §4 line 40 + amendment induk §9 line 223. Spec L2 ini **tidak** mengedit anchor itu sama sekali; ia hanya CROSS-REF (untuk kontrak render-docs §4 lihat §5). Dengan begitu hanya SATU spec yang meng-emit task ke tiap anchor fisik — tak ada wording ganda/kontradiktif, tak ada anchor stale bila salah satu ship duluan.

**Alternatif ditolak:**
- **(A) Tetap bundel L3 di dalam spec L2 ini** (versi lama spec) — DITOLAK: melanggar induk §4 (single source of truth). DUA spec di disk akan mengedit anchor identik (`template.html` line 73 + render-docs §4 line 40) dengan wording berbeda; bila salah satu ship duluan, anchor spec kedua jadi STALE (`grep -Fc -e` = 0) atau menghasilkan legend ganda. Handoff sudah men-split L2 & L3 jadi dua item terpisah.
- **(B) Jadikan spec L2 sumber tunggal dan HAPUS spec L3 berdiri-sendiri** — DITOLAK: spec L3 lebih lengkap (sudah meng-amend induk §9 line 223 perilaku render-docs, sudah menangani carrier badge `shipped` ke-2 dari utang teknis yang share `<section id="fixes">`, sudah menetapkan render `<code>shipped</code>` via CSS `code{}` yang ada). Membuang itu = kehilangan kerja yang lebih matang; selaras handoff yang sudah memperlakukan L3 sebagai item sendiri.

### Decision-2 — Urutan & non-tabrakan dengan render-docs (anchor share).

**Keputusan:** L3 (spec terpisah) menyisip **makna badge `shipped`** ke render-docs §4 SETELAH "boleh tampil (mis. badge `.status`)" — di **kalimat `shipped`/fitur**. L2 (doc-hint spec ini) **tidak** menyentuh render-docs §4 sama sekali (tak ada enum `deprecated`). Bila L2 machinery kelak (spec-terpisah) menambah `deprecated`, ia menyisip bullet filter terpisah SESUDAH kalimat `dropped` — surface berbeda, **bukan** ke kalimat `shipped` (milik L3). Jadi: zero overlap antar-spec di anchor render-docs.

**Alternatif ditolak:** spec L2 ikut mengedit kalimat §4 line 40 yang sama dengan L3 — DITOLAK (tabrakan anchor; sudah diserahkan ke L3 oleh Decision-1).

### Decision-3 — Honesty: L2 = doc-hint, NOL perubahan perilaku.

**Keputusan:** L2 tak menambah status, tak menambah folder machinery, tak menambah gate. shipped-text (di `feature/SKILL.md` `## Catatan`) harus JUJUR: iterasi fitur `shipped` = bikin fitur baru manual / `/fix`; jalur penerus first-class = future. **Alternatif ditolak:** mengklaim "lifecycle pasca-ship sekarang didukung" — DITOLAK (over-claim; langgar preseden M6).

---

## 3. Design per-komponen (edit-map before→after, teks DISK SEKARANG verbatim)

> Catatan: edit-map yang nge-quote teks-lama = **dokumentasi target**, BUKAN pointer live (jangan salah-fix). Anchor diverifikasi `grep -Fc -e` (match=1) saat writing-plans. Tanggal value YAML/desc: hindari colon-space `: ` (pakai em-dash/kurung).
>
> **Spec L2 ini mengedit SATU file:** `plugin/skills/feature/SKILL.md` (1 bullet di `## Catatan`). Semua edit render-docs/template/badge `shipped` ada di **spec L3** (terpisah) — bukan di sini.

### 3.A `plugin/skills/feature/SKILL.md` — L2 (doc-hint workaround, 1 bullet `## Catatan`)

Tambah satu bullet di `## Catatan` SETELAH baris transisi (sub-bullet, **bukan** renumber).

BEFORE (line 44, verbatim — anchor `grep -Fc -e` match=1):
```
- Eksekusi implementasi ditangani `breakdown` → `build`; transisi `shipped`/`dropped` ditangani `ship`/`drop`.
```
AFTER (sisip bullet baru SESUDAHNYA):
```
- Eksekusi implementasi ditangani `breakdown` → `build`; transisi `shipped`/`dropped` ditangani `ship`/`drop`.
- **Iterasi fitur yang sudah `shipped`** — tak ada status `deprecate`/jalur penerus first-class (status sengaja kasar — induk §12). Untuk perubahan substansial, **buat fitur baru** (nama bebas, mis. `<nama>-v2`) lewat `/feature`; untuk perbaikan bug perilaku yang sudah ada, pakai `/fix`. Jalur penerus/pensiun otomatis (immutable old-folder + supersedes) = **future, spec terpisah** (lihat induk §16 + pipeline-hardening §S4.1/§10-4).
```

**Colon-space guard:** bold-label memakai **em-dash** (`** —`), BUKAN `:` — aman; ini teks prosa Markdown di `## Catatan` (bukan YAML value/`description:` frontmatter), konsisten dgn bullet existing. Tak ada `: ` baru di value YAML mana pun.

**Catatan anti-fiksi:** `<nama>-v2` di sini = **konvensi penamaan manual** (nama folder fitur biasa), BUKAN machinery (tak ada seed-dari-lama, tak ada immutable, tak ada field `supersedes`). Eksplisit agar tak dibaca sebagai fitur yang belum ada. **Mis-aimed-pointer:** "§S4.1/§10-4" → pipeline-hardening line 158/198 (TERVERIFIKASI); "induk §12/§16" → status table / future (TERVERIFIKASI).

### 3.B Tidak disentuh (eksplisit)

- **`feature.yaml` schema** — TAK disentuh (no enum `deprecated`, no field `supersedes`/`deprecated_by`). Decision-0 alt-(B)/(C) ditolak. → ≥9 pembaca `feature.yaml` tak berubah.
- **`drop/SKILL.md`** — TAK disentuh (tetap `draft`/`active` only; "drop fitur shipped" = future).
- **`ship/SKILL.md`** — TAK disentuh (`shipped` semantik PR-dibuka tetap).
- **`ask/SKILL.md` line 26 / `fix/SKILL.md` line 20/23** — TAK disentuh (tak ada enum baru untuk dibaca).
- **`render-docs/SKILL.md` §4 + `template.html`** — TAK disentuh OLEH SPEC L2 (semua edit makna badge `shipped` milik **spec L3** terpisah — Decision-1).
- **`plugin.json` / `marketplace.json` / README** — TAK disentuh (skill tetap 21, tak ada fase/skill baru).
- **Stream A `sensitivity:`** — TAK overlap (L2 tak menambah field ke `feature.yaml`). M6 §3 Non-Tujuan (line 42-43) sudah menegaskan mekanik `sensitivity` (line 42) & render-docs (line 43) tak diubah.

---

## 4. Parent-spec amendments (`docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`)

Minimal — karena jalur L2 yang di-ship adalah doc-hint, bukan machinery.

- **§16 Scope v1 & Pengembangan Berikutnya (line 297-300)** — tambahkan lifecycle pasca-`shipped` ke daftar Future agar gap L2 tercatat eksplisit (bukan hilang). Anchor (line 300, verbatim, verified):
  ```
  - **Future:** eksekusi/implementasi otomatis lintas-app (orchestrator), MCP knowledge server, status `in-review` (PR dibuka vs merged), auto-detect merge untuk trigger `shipped`.
  ```
  AFTER (append frasa di akhir bullet yang sama — sisip frasa, **bukan** bullet baru, agar selaras dengan `in-review` yang sudah ada di baris itu):
  ```
  - **Future:** eksekusi/implementasi otomatis lintas-app (orchestrator), MCP knowledge server, status `in-review` (PR dibuka vs merged), auto-detect merge untuk trigger `shipped`, **lifecycle pasca-`shipped` (iterasi-v2/deprecate/supersedes — status-machine lintas feature/ship/drop/render-docs; spec terpisah, lih. pipeline-hardening §S4.1/§10-4)**.
  ```

- **§12 Lifecycle & Status Fitur (tabel status, line ~263-272)** — **TIDAK diubah.** Status tetap 4 (`draft`/`active`/`shipped`/`dropped`). Spec ini sengaja TIDAK menambah `deprecated` (Decision-0). Catatan eksplisit di sini agar reviewer tahu §12 sengaja dibiarkan. (Bila L2 machinery kelak diambil di spec terpisah, §12 tabel adalah yang berubah — itu sinyal balloon yang mengonfirmasi keputusan defer.)

- **§9 Skills `### render-docs` (perilaku, line 223)** — **DI LUAR SPEC L2 INI.** Amendment perilaku render-docs (badge status diberi keterangan makna `shipped`) **dimiliki spec L3** terpisah. Spec L2 ini sengaja TIDAK menyentuh §9 line 223 agar tak ada dua sumber untuk satu amendment (induk §4). (Spec L2 doc-hint memakai `## Catatan` feature, bukan render-docs — tak ada perilaku render-docs yang berubah karena L2.)

- **§13 Dokumen Human-Readable (line 274+)** — **TIDAK diubah oleh L2** (L2 = catatan di `feature/SKILL.md`, bukan perubahan model dokumen human-readable). Disebut agar tak ada asumsi §13 berubah karena L2.

- **§17 Komponen** — **TIDAK diubah** (skill tetap 21; tak ada skill/fase baru; tak ada rule baru — L2 doc-hint memakai `## Catatan` feature, bukan rule file).

- **§7 control-tree / §8 repo-tree** — **TIDAK diubah** (tak ada file/dir baru; `<nama>-v2` = nama fitur biasa di `features/`, bukan struktur baru).

---

## 5. Kontrak bersama (bila L2 machinery kelak diambil — di luar scope spec ini)

Didokumentasikan agar spec-terpisah masa depan tak menabrak Stream A maupun L3:
- **render-docs §4 (milik L3):** L3 (spec terpisah) menyisip makna `shipped` SETELAH "(mis. badge `.status`)" di kalimat `shipped`/fitur. Filter `deprecated` masa depan menyisip bullet terpisah SESUDAH kalimat `dropped` — surface berbeda, tak menimpa klausa L3. Spec L2 **tidak** mengedit §4 (Decision-1/Decision-2).
- **`feature.yaml` field-order:** skeleton saat ini `name → status → created → sensitivity` (feature line 14-18; duplikat di `intake` §1). Field penerus masa depan (mis. `supersedes`/`deprecated_at`) ditaruh **di bawah `sensitivity`** agar Stream A tetap memodifikasi `sensitivity:` di posisi sama. DUA file menulis skeleton (feature §1 + intake §1) — kontrak identik di keduanya.
- **Enum `deprecated`:** bila ditambah, WAJIB sinkron di induk §12 tabel + §16 + render-docs §4 + `ask` line 26 + `fix` line 20/23 + `drop`/`ship` guard. (Daftar pembaca ini = bukti balloon → konfirmasi defer.)

---

## 6. Honesty-note (advisory vs gate; preseden M6)

- **L2 = doc-hint murni, NOL perubahan perilaku, NOL gate.** Tak ada status baru, tak ada folder machinery. shipped-text (di `feature/SKILL.md` `## Catatan`) harus JUJUR: "iterasi fitur `shipped` = bikin fitur baru manual / `/fix`; jalur penerus first-class = future". **Tidak** mengklaim "lifecycle pasca-ship sekarang didukung". Gap inti tetap terbuka & tercatat di induk §16.
- **Surface tempat logika beneran jalan:** L2 jalan di `feature/SKILL.md` `## Catatan` (tempat user membaca "apa langkah berikutnya"). shipped-text jujur ditaruh di SURFACE itu, bukan cuma di spec.
- **L3 di luar spec ini.** Honesty-note render-docs/badge `shipped` (alat buta status deploy) dipegang spec L3 terpisah — lihat L3 §5.
- **Tak ada palang keras baru.** Tak ada STOP/RED/gagal ditambah. (Satu-satunya gate keras di pipeline = Security Gate `ship` existing, tak disentuh.)

---

## 7. Self-review checklist awal

- [ ] **Single source of truth (induk §4, mustFix):** spec L2 ini TIDAK mengedit `template.html` line 73 maupun `render-docs/SKILL.md` §4 line 40 maupun induk §9 line 223 — semua itu milik spec L3 terpisah. Spec L2 cuma CROSS-REF (Decision-1). Hanya SATU spec per anchor fisik.
- [ ] **Anti-balloon (L2):** spec TIDAK menambah enum `deprecated`, TIDAK menambah folder `<nama>-v2` machinery, TIDAK menambah field `feature.yaml`. Hanya doc-hint `## Catatan` + 1 item Future §16. (scopeFlags-1)
- [ ] **Anti-fiksi:** tiap artefak yang dirujuk ADA di disk (feature line 44, ship line 45-46, induk §12/§16, pipeline-hardening §S4.1/§10-4). `<nama>-v2` ditandai eksplisit = nama manual, BUKAN machinery yang ada.
- [ ] **Honesty (preseden M6):** shipped-text di feature `## Catatan` menyatakan apa adanya (iterasi-v2 = workaround manual; gap inti future). Tak over-claim.
- [ ] **No-renumber:** sisipan = sub-bullet (feature `## Catatan`) + frasa (induk §16) — tak me-renumber step/section. Cross-ref "§X" tetap nunjuk target benar.
- [ ] **Mis-aimed-pointer:** "induk §12" = tabel status (line ~263); "induk §16" = future (line 300); "§S4.1/§10-4" = pipeline-hardening (line 158/198); "M6 §3 Non-Tujuan" = line 42-43. Semua TERVERIFIKASI match.
- [ ] **Colon-space guard:** bullet feature `## Catatan` bold-label pakai em-dash (`** —`), bukan `:`; teks prosa Markdown (bukan YAML value). render-docs `description:` TAK disentuh (di luar scope L2). Tak ada `: ` baru di value YAML/frontmatter.
- [ ] **Edit-map = dokumentasi, bukan pointer:** before→after yang nge-quote teks-lama tidak diperlakukan sebagai cross-ref live.
- [ ] **`grep -Fc -e` anchor (saat writing-plans):** feature line 44, induk line 300 — verifikasi verbatim match=1 sebelum edit. (Anchor L3 — template line 73, render-docs line 40, induk line 223 — diverifikasi di spec L3, BUKAN di sini.)
- [ ] **Skill-count tetap 21:** induk §17 line 304 (`Skills (21)`) + tak ada edit `plugin.json`/`marketplace.json`/README.
- [ ] **Stream A non-overlap:** L2 tak menyentuh `feature.yaml` `sensitivity` (M6 §3 Non-Tujuan line 42-43).
- [ ] **Generik:** tak ada apa pun ecommerce-specific; Shopify cuma ilustrasi §1.1.
