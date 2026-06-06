# L3 — render-docs label jujur: badge `shipped` ≠ live/deployed

> Langkah-3, gap **L3** (LOW) — fix-light wording-only. Tanggal: **2026-06-06**. Repo `~/Developer/ai-boilerplate`, base `main`. Stream D (grounding scout terverifikasi: semua anchor `grep -Fc -e` match=1; tak ada logika v2/deprecated/reopen di disk).

## 1. Ringkasan

`render-docs` memproyeksikan knowledge `control/` ke satu HTML untuk PM/stakeholder non-teknis. Untuk fitur & fix, ia memakai badge `.status` dengan teks = nilai status literal (`active`/`shipped`/`open`/`diagnosed`). Masalahnya: teks badge `shipped` **bisa dibaca stakeholder sebagai "sudah live/ada di produksi"**, padahal makna `shipped` di disk = **PR dibuka** (`ship` step 6 line 46: `gh pr create` + set `status: shipped`; "byproduct, bukan flag manual"). Antara `shipped` dan "live" ada DUA langkah yang tak diketahui alat: PR di-merge, lalu deploy. `render-docs` tak punya sinyal CI/deploy apa pun.

L3 = **wording-only**, nol perubahan perilaku: menambahkan **legend/disclaimer statis** yang menjelaskan makna badge `shipped` (= sudah di-PR / siap-kirim, **bukan** indikator merged/deployed/live), sehingga proyeksi HTML tidak menyesatkan stakeholder. Alat tetap buta status deploy — L3 jujur tentang itu, tidak mengklaim menampilkan status live.

**Bukan "ganti kata live→merged".** String `live` **tidak pernah dirender** `render-docs` (grep `live` di `plugin/skills/render-docs/` = nol; kata "live" cuma muncul di integrations/add-integration/design-system konteks "Mode test/live", bukan badge). Yang ada cuma teks `shipped`. Jadi L3 **memperjelas makna badge `shipped`**, bukan mengganti kata yang tak pernah ada.

**Bukan "merged".** Usulan handoff awal pakai "merged ≠ deployed". Itu **tidak presisi**: `shipped` = PR **dibuka** (belum tentu merged). Wording interim yang akurat = **"sudah di-PR / siap-kirim"**, BUKAN "merged" dan BUKAN "live". L3 selaras dengan induk §3-non-tujuan (line 37) & §16-Future (line 300) yang sudah mendaftarkan status `in-review` ("PR dibuka vs merged") sebagai future — L3 **tidak** menambah status, cuma memperjelas label yang ada sambil menunggu `in-review`.

**Skill tetap 21. Tak ada rule baru. Tak ada file baru.** L3 menyentuh 2 file: `plugin/skills/render-docs/SKILL.md` (§4 + §3) dan `plugin/skills/render-docs/template.html` (legend statis). Tak menyentuh `feature.yaml` schema, `ship`, `sensitivity`, atau status enum.

## 2. Masalah & konteks

### 2.1 Trigger konkret (ilustrasi Shopify; desain generik)

Solo-dev membangun Shopify-app. Fitur `checkout-kupon` selesai di-`ship` → `gh pr create` jalan, `feature.yaml.status` jadi `shipped`, `render-docs` ter-trigger. Stakeholder/klien membuka `control/docs/site/index.html`, melihat badge biru **"shipped"** di samping fitur (atau di slot Riwayat Fix). Pembacaan natural non-teknis: **"fitur ini sudah jalan di produksi / pelanggan sudah bisa pakai."**

Faktanya: PR baru **dibuka**, belum tentu di-merge oleh reviewer, dan **pasti** belum di-deploy (boilerplate ini berhenti di PR — induk §3 non-tujuan line 35: "Pipeline berhenti di plan yang disetujui; `ship` menutup setelah implementasi manual"). Stakeholder mengambil keputusan (mis. mengumumkan ke pelanggan) berdasarkan badge yang menyesatkan. Ini bug komunikasi, LOW-severity, tapi nyata karena `render-docs` justru ditargetkan ke audiens non-teknis (SKILL.md line 3: "untuk PM/stakeholder non-teknis").

Desain L3 generik: tak ada apa pun ecommerce-specific — cuma memperjelas semantik label status yang dipakai SEMUA produk.

### 2.2 Bukti disk (anchor verbatim, `grep -Fc -e` = match 1)

- **Badge teks = nilai status literal.** `template.html` line 74 (contoh fix): `<span class="status open">open</span>` — teks badge persis nilai status. Untuk fitur/fix `shipped`, badge menampilkan teks "shipped".
- **CSS badge** `template.html` line 28: `.status.active{background:#e6efe1;color:#4a7a3f} .status.shipped{background:#dfeaf6;color:#3a6ea5}` — `.status.shipped` dipakai BERSAMA fitur & fix.
- **§4 menyuruh render badge fitur (opsional).** `SKILL.md` line 40: `Fitur \`active\`/\`shipped\` boleh tampil (mis. badge \`.status\`).` — kata "boleh / mis." = opsional.
- **Makna `shipped` = PR dibuka.** `ship/SKILL.md` line 45 (`gh pr create`) + line 46 (`Set manifest work-item → \`status: shipped\` + \`shipped_at: <YYYY-MM-DD>\``) + line 8 ("`shipped` jadi byproduct, bukan flag manual"). Bukan merged, bukan deployed.
- **Induk sudah tahu gap ini, sebagai Future.** §3 non-tujuan line 37: `- Status \`in-review\` (membedakan "PR dibuka" vs "sudah merged").` dan §16 Future line 300: `status \`in-review\` (PR dibuka vs merged)`. L3 = label interim yang selaras, BUKAN status baru.

### 2.3 Design-hole yang harus diperhatikan (RISK-2 dari scout)

Slot **apps** di template (line 53-58) **TIDAK** merender badge `.status` sama sekali; `SKILL.md §3` bullet apps (line 27) tak menyebut badge status fitur. Yang benar-benar merender `.status` hari ini ada DUA, dan keduanya berbagi `<section id="fixes">` yang sama (template line 71-77):
1. **Slot fixes** (`SKILL.md §3` line 31; template line 74) — fix ber-`status: shipped` masuk "Riwayat" → badge `.status.shipped`. **Carrier terjamin #1.**
2. **Slot utang teknis** (`SKILL.md §3` line 32) — utang dengan `status` **diturunkan** (§1) jadi `shipped` juga masuk "Riwayat", merender `.status.shipped`, **di dalam `<section id="fixes">` yang sama** (reuse class). **Carrier terjamin #2.** Inilah yang membuat klausa makna `shipped` perlu **generik per-makna-badge**, bukan terikat hanya pada "Defect dari control/fixes/".

Slot **fitur** (§4 line 40, "fitur boleh tampil (mis. badge `.status`)") = opsional & tak diwujudkan di template contoh — carrier ke-3 yang **tidak terjamin**. **Konsekuensi desain:** kalau L3 hanya menambah tooltip per-badge-fitur, ia memperbaiki badge yang **mungkin tak pernah dirender**, sementara DUA carrier terjamin (fix + utang, share slot fixes) tak tersentuh. Maka L3 harus pakai **legend STATIS** di meta slot fixes (tak bergantung pada apakah badge fitur dirender) — satu klausa di `<p class="meta">` line 73 sekaligus mencakup fix **dan** utang teknis karena keduanya share `<section id="fixes">`. Klausa yang ditambahkan (4a) berbunyi makna-badge-generik ("Badge `shipped` = …"), jadi ia menjelaskan `shipped` di SEMUA tempat `.status.shipped` bisa muncul, bukan defect-fix saja. Lihat Decision D2/D3.

## 3. Decisions (tiap fork desain + alternatif ditolak + alasan)

> Ini menggantikan brainstorming 1-1. Tiap keputusan plain-language; user bisa veto mana pun.

### D1 — Apa yang sebenarnya diperbaiki: makna `shipped`, bukan kata "live"

**Putusan:** L3 memperjelas bahwa badge `shipped` = "sudah di-PR / siap-kirim", BUKAN merged/deployed/live.

**Alternatif ditolak:**
- *(a) "Ganti kata live → merged" (usulan handoff awal).* DITOLAK: kata "live" tak pernah dirender `render-docs` (grep nol). Tak ada yang bisa diganti. Fix yang benar = perjelas `shipped`.
- *(b) Pakai kata "merged" sebagai label baru.* DITOLAK: `shipped` = PR **dibuka**, belum tentu merged (`ship` cuma `gh pr create`). Melabeli "merged" = salah-klaim. Wording akurat = "sudah di-PR / siap-kirim".

### D2 — Bentuk fix: legend statis, bukan tooltip per-badge

**Putusan:** Tambah **legend/disclaimer statis** (teks tetap di HTML) yang menerangkan makna `shipped`. Legend hidup di tempat yang PASTI dirender, tak bergantung pada badge fitur opsional.

**Alternatif ditolak:**
- *(a) `title="..."` tooltip pada tiap badge `shipped`.* DITOLAK 2 alasan: (i) tooltip hanya muncul saat hover (stakeholder mungkin tak hover) — tak terpercaya untuk audiens non-teknis; (ii) badge fitur mungkin tak dirender sama sekali (RISK-2), jadi tooltip-per-badge memperbaiki sesuatu yang absen. Legend statis selalu terlihat dan tak bergantung pada badge fitur.
- *(b) Mengubah label CSS class `shipped` → `siap-kirim`.* DITOLAK: class CSS adalah selector teknis, bukan teks tampilan; mengganti nama class = churn tanpa manfaat (warna tetap sama) dan menyentuh fix + fitur + debt sekaligus. Legend menjelaskan tanpa menyentuh class.
- *(c) Mengubah teks badge dari "shipped" → "siap-kirim" di tiap kartu.* DITOLAK (untuk fix ini): teks badge = nilai status literal dari YAML; mengubahnya per-render berarti memetakan status→label di banyak titik (fitur, fix, debt) dan memutus simetri "teks badge = status". Legend menjelaskan makna tanpa memutus mapping. (Bisa jadi pekerjaan terpisah bila user mau penuh.)

### D3 — Di mana legend ditaruh

**Putusan:** DUA sisipan kecil yang saling menguatkan, di tempat yang sudah punya pola "meta penjelasan":
1. **Slot fixes** sudah punya kalimat meta (`template.html` line 73: "Known Issues (open/diagnosed) di atas, Riwayat (shipped) di bawah."). Tambah klausa makna `shipped` di situ. Slot ini menampung DUA carrier `shipped` terjamin yang share `<section id="fixes">` yang sama: (a) fix `shipped` (§3 line 31) dan (b) utang teknis dengan `status` diturunkan jadi `shipped` (§3 line 32) — keduanya masuk "Riwayat" dan merender `.status.shipped`. Karena `<p class="meta">` line 73 adalah meta bersama slot tersebut, **satu klausa di sini mencakup fix dan utang sekaligus**. Maka teks klausa dibuat **generik per-makna-badge** ("Badge `shipped` = …"), bukan terikat pada "Defect dari control/fixes/" — kalimat induk meta tetap defect-spesifik, tapi klausa makna `shipped` yang ditambahkan berlaku untuk semua badge `shipped` di slot itu (lihat §2.3 carrier #1/#2).
2. **§4 SKILL.md** (instruksi render) — sisip klausa makna SETELAH "boleh tampil (mis. badge `.status`)" agar saat render-docs MENULIS badge fitur (carrier opsional ke-3), ia juga menulis disclaimer makna (legend) yang sama, bukan badge telanjang.

**Alternatif ditolak:**
- *(a) Legend global tunggal di sidebar (`<div class="tag">`).* DITOLAK sebagai satu-satunya tempat: sidebar tag = "auto-generated" caption, terlalu jauh dari badge; legend dekat badge lebih efektif. (Boleh sebagai tambahan, tapi tak wajib — hindari scope creep, pilih yang paling dekat ke badge.)
- *(b) Section disclaimer terpisah.* DITOLAK: section baru = lebih dari "light" untuk fix LOW; reuse pola meta yang ada.

### D4 — Wording yang dipakai (jujur, akurat vs perilaku ship)

**Putusan:** Teks legend (generik, non-domain):
> `shipped` = perubahan sudah **di-PR / siap-kirim** (PR dibuka via `ship`) — **bukan** indikator sudah merged / ter-deploy / live di produksi.

**Alternatif ditolak:** wording "sudah live" / "sudah rilis" / "sudah merged" — DITOLAK, semua mengklaim lebih dari yang alat tahu (D1-b). Honesty-note §5.

### D5 — Selaras induk, bukan menambah status

**Putusan:** L3 = label interim. Tak menambah enum status, tak menyentuh §12 tabel status. Spec merujuk induk §3-non-tujuan line 37 + §16 Future line 300 (`in-review`) sebagai arah jangka panjang; L3 menutup gap komunikasi sementara.

**Alternatif ditolak:** mengimplementasikan `in-review` sekarang (status baru "PR dibuka vs merged") — DITOLAK: itu Future induk, menyentuh enum status + ≥5 skill + butuh sinyal merge yang tak ada. Jauh dari fix-light. Lihat scopeFlags (di luar spec ini, terkait L2).

### D6 — Tidak menyentuh `description:` frontmatter

**Putusan:** L3 hanya mengedit BODY (§4, §3) + template.html. Tak menyentuh `description:` (line 3) — tetap bersih dari `: ` extra (colon-space guard). Tak ada churn deskripsi.

## 4. Design per-komponen (edit-map; before = teks DISK SEKARANG, verbatim)

> Semua sisipan = klausa/kalimat tambahan dalam baris yang ADA. **Tak ada renumber step**, tak ada section/slot baru, tak ada file baru.

### 4a. `plugin/skills/render-docs/template.html` — legend di meta slot fixes

Slot fixes sudah punya kalimat meta penjelas. Tambah klausa makna `shipped` di akhir kalimat itu.

**Anchor (line 73, `grep -Fc -e` = 1):**
```
    <p class="meta">Defect dari control/fixes/. Known Issues (open/diagnosed) di atas, Riwayat (shipped) di bawah.</p>
```

**Before → After:**
- BEFORE: `Known Issues (open/diagnosed) di atas, Riwayat (shipped) di bawah.`
- AFTER: `Known Issues (open/diagnosed) di atas, Riwayat (shipped) di bawah. Badge \`shipped\` = sudah di-PR / siap-kirim — bukan indikator sudah merged / ter-deploy / live.`

Catatan: ini HTML `<p class="meta">` — teks biasa, bukan atribut YAML; aman dari colon-space (em-dash dipakai, bukan `: `). Backtick `\`shipped\`` di prose HTML ditampilkan apa adanya (konsisten dgn gaya meta lain yang pakai inline code visual — opsional bisa dibungkus `<code>shipped</code>`; pilih plain backtick agar selaras pola SKILL, atau `<code>` agar konsisten CSS `code{}` line 33 — **rekomendasi: `<code>shipped</code>`** karena template punya style `code`). 

> **Pilihan render final (penulis plan tetapkan SATU):** gunakan `<code>shipped</code>` (memanfaatkan CSS `code{}` yang ADA, line 33) supaya konsisten visual. Teks: `Riwayat (shipped) di bawah. Badge <code>shipped</code> = sudah di-PR / siap-kirim — bukan indikator sudah merged / ter-deploy / live.`

### 4b. `plugin/skills/render-docs/SKILL.md` — §4 instruksi makna badge fitur

Saat §4 mengizinkan badge fitur `shipped`, tambahkan instruksi agar render-docs juga menyertakan disclaimer makna (legend) — bukan badge telanjang. Ini memastikan: bila implementasi MEMANG merender badge fitur `shipped`, maknanya ikut dijelaskan.

**Anchor (line 40, dalam kalimat, `grep -Fc -e` = 1):**
```
Fitur `active`/`shipped` boleh tampil (mis. badge `.status`).
```

**Before → After:**
- BEFORE: `Fitur \`active\`/\`shipped\` boleh tampil (mis. badge \`.status\`).`
- AFTER: `Fitur \`active\`/\`shipped\` boleh tampil (mis. badge \`.status\`). **Bila badge \`shipped\` ditampilkan, sertakan keterangan makna** (legend statis dekat badge): \`shipped\` = sudah di-PR / siap-kirim, **bukan** indikator merged / ter-deploy / live (cermin induk §3/§16 Future "in-review"). \`render-docs\` tak punya sinyal CI/deploy — jangan klaim status produksi.`

Sub-clause, **bukan** renumber §4. Tetap di kalimat fitur (bukan kalimat `dropped`/fix), sehingga bila gap L2 (status `deprecated`) suatu hari diambil, ia menyisip di tempat berbeda (kalimat `dropped`) — tak bertabrakan. (Kontrak share-surface render-docs lihat §6.)

> **Catatan colon-space (jangan salah-fix):** AFTER di atas memuat `: ` natural di "(legend statis dekat badge): `shipped`". Ini **BODY prose** SKILL.md (body sudah punya banyak `: ` prosa normal), BUKAN value YAML/`description:`. Colon-space guard (D6, checklist §7) hanya berlaku untuk value `description:` di **frontmatter** — yang TAK disentuh L3. Penulis plan **jangan** menghapus `: ` natural ini demi "patuh guard"; itu akan menurunkan keterbacaan tanpa manfaat.

### 4c. (OPSIONAL, tidak wajib — flag bila user mau) sidebar legend global

`template.html` line 39 `<div class="tag">Product Docs · auto-generated</div>` bisa diperluas jadi `... auto-generated · badge "shipped" = siap-kirim, bukan live`. **Default: TIDAK diambil** (D3-a) — legend dekat-badge (4a/4b) lebih efektif & menghindari menumpuk dua tempat. Dicatat agar user bisa memintanya bila ingin disclaimer global.

## 5. Honesty-note (advisory vs gate; di surface mana shipped-text jujur)

**L3 = wording-only, NOL perubahan perilaku. Bukan gate, bukan advisory-logic — murni proyeksi yang lebih jujur.** Tak ada keputusan/blokir baru; `render-docs` tetap menjalankan filter status yang sama (§4 tak berubah perilakunya, cuma menambah keterangan).

Surface tempat shipped-text harus jujur (preseden M6 Lesson #18 — tulis apa adanya di tempat logika beneran jalan):
- **Di legend HTML (4a/4b)** — surface tempat stakeholder membaca. Teks WAJIB menyatakan keterbatasan: `shipped` = di-PR / siap-kirim, **alat tak tahu status deploy**. JANGAN tulis "sekarang menampilkan status live/produksi" — itu klaim palsu (alat tetap buta CI/deploy).
- **Di ringkasan ship-text PR (bila L3 dikirim via `ship`):** jujur — "render-docs: badge `shipped` kini diberi keterangan makna (siap-kirim ≠ live); render-docs tetap tak tahu status deploy. Wording-only, nol perubahan perilaku/filter." Jangan klaim "menambah status" atau "deteksi deploy".

Konsistensi dengan induk: §3 non-tujuan (line 37) & §16 Future (line 300) tetap menyatakan `in-review` (PR-dibuka-vs-merged) sebagai Future yang **belum** diimplementasi. L3 tidak mengubah itu — ia label interim yang selaras, bukan implementasi `in-review`.

## 6. Parent-spec amendments

`docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`:

- **§9 `### render-docs` (line 220-225) — perilaku.** Saat ini line 223: `**Perilaku:** render ke single HTML (layout sidebar B1, tema Warm/Friendly), **filter by status** (fitur \`dropped\` tidak tampil / masuk section terpisah).` 
  - **Amendment (sisip frasa, bukan renumber):** SETELAH `**filter by status** (fitur \`dropped\` tidak tampil / masuk section terpisah)` → tambah `; badge status diberi keterangan makna (\`shipped\` = siap-kirim, bukan live/deploy — L3).` 
  - Anchor verifikasi `grep -Fc -e` baris 223 = match 1 (terverifikasi). Ini menjaga induk (sumber kebenaran) tak stale-vs-perilaku render-docs nyata.
- **§3 non-tujuan v1 (line 37) & §16 Future (line 300) — TAK diubah, hanya DIRUJUK.** Keduanya sudah mencatat `in-review` (PR-dibuka-vs-merged) sebagai Future. L3 = label interim; tidak menambah/menghapus item Future. Spec L3 merujuk keduanya agar jelas L3 ≠ status baru.
- **§13 "Dokumen Human-Readable" (line 274-279) — TAK diubah, hanya DIRUJUK.** Line 279 menyatakan "dokumen ini tidak mungkin bohong relatif terhadap yang AI tahu" — klaim itu tentang **drift** (HTML = proyeksi sumber yang sama, tak ada hand-edit), BUKAN tentang status deploy. L3 **memperkuat**, bukan membantah, klaim itu: tanpa legend, badge `shipped` bisa menyesatkan pembaca non-teknis (mereka baca "live") tentang sesuatu yang **alat sendiri tak tahu** (status deploy) — yang justru melanggar semangat "tidak bohong relatif terhadap yang AI tahu". Legend L3 menutup celah itu, sehingga §13 tetap akurat. Dirujuk di sini agar pembaca §13 di masa depan tak mengira "tidak mungkin bohong" bertentangan dengan masalah "badge bisa menyesatkan" yang L3 perbaiki.

**TAK disentuh (eksplisit):**
- §12 status table (heading line 242; tabel enum proper lines 263-268) — enum tetap 4 (`draft`/`active`/`shipped`/`dropped`); L3 tak menambah `in-review`/`deprecated`. (Lines 270/272 = prosa fix-status + catatan "kasar (4)", bukan tabel enum.)
- §7 control-tree, §8 repo-tree, §17 komponen, skill-count (**21**), `plugin.json`/`marketplace.json`/README — nol churn.
- `feature.yaml` schema, `sensitivity` (Stream A), `ship`/`drop`/`feature`/`intake` SKILL — tak disentuh.
- L2 (status `deprecated` / iterasi-v2) — **di luar L3** (lihat scopeFlags); L3 menyisip di kalimat `shipped` (§4), L2 (jika kelak diambil) di kalimat `dropped` — surface berbeda, tak bentrok.

## 7. Self-review checklist awal

- [ ] **Anchor verbatim:** §4 line 40 (`Fitur \`active\`/\`shipped\` boleh tampil (mis. badge \`.status\`).`), template line 73 (`Known Issues (open/diagnosed) di atas, Riwayat (shipped) di bawah.`), parent §9 line 223 — semua `grep -Fc -e` = 1 sebelum edit (terverifikasi saat grounding).
- [ ] **No-renumber:** §4 & §3 SKILL = sisip klausa; tak menggeser nomor step. Template = sisip kalimat dalam `<p class="meta">` yang ada; tak menambah `<section>`/slot.
- [ ] **Colon-space guard:** legend pakai em-dash/`=`, **tak** ada `: ` di dalam value YAML mana pun. `description:` render-docs (line 3) TAK disentuh (D6). Cek pasca-edit: tak ada `: ` baru di frontmatter.
- [ ] **Wording akurat:** label = "sudah di-PR / siap-kirim", BUKAN "merged", BUKAN "live" (D1/D4). Konsisten dgn `ship` (PR dibuka) line 45-46.
- [ ] **Honesty:** legend menyatakan alat buta status deploy; tak ada klaim "menampilkan status live/produksi" (§5).
- [ ] **Design-hole (RISK-2) ditangani:** legend ditaruh di slot fixes (PASTI render badge `shipped`) + §4 instruksi (bila badge fitur dirender, sertakan makna). Tak bergantung semata pada badge fitur opsional.
- [ ] **Mis-aimed pointer:** §9 render-docs = line 220-225 (`### render-docs`), BUKAN §17; `in-review` Future = line 37 (§3) + line 300 (§16); §12 status table proper = lines 263-268 (heading §12 = line 242; lines 270/272 = prosa, bukan tabel enum). Diverifikasi.
- [ ] **Generik, non-domain:** legend tak menyebut Shopify/ecommerce; berlaku semua produk. Skenario Shopify cuma ilustrasi §2.1.
- [ ] **Scope-light:** 2 file render-docs + 1 frasa parent. Tak ada file/skill/rule/status baru. Skill tetap 21.
- [ ] **Literal-scan:** tak ada sentinel baru (mis. `<belum ...>`); teks legend prose biasa, tak bocor ke scan literal skill lain.
- [ ] **Pilihan render `<code>shipped</code>` vs backtick** (4a) ditetapkan SATU di plan (rekomendasi `<code>` memakai CSS `code{}` line 33 yang ada).
