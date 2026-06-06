# M3 — Platform-Capability Nudge (peran cross-cutting → usul unit worker, advisory)

> Langkah-3, gap **M3** (MEDIUM, fix-light). Tanggal: **2026-06-06**. Repo `~/Developer/ai-boilerplate`, base `main`.
> Brainstorming GANTI 1-1: setiap fork desain didokumentasikan di §2 (Decisions) dgn alternatif yang ditolak + alasan — user bisa veto per keputusan. Format spec meniru `2026-06-06-m6-compliance-risk-design.md`.

## 1. Ringkasan

`fanout` (P1) sudah memetakan fitur ke app + mengusulkan **5 pola unit baru**: APP BARU, SHARED PACKAGE, VENDOR EKSTERNAL, DESIGN-SYSTEM, dan `consumers`. Tapi ada **pola ke-6 yang hilang**: peran **cross-cutting / platform** — queue / job-runner / background-processing / audit-log — yaitu kerja yang **bukan milik satu app**, melainkan infrastruktur runtime lintas-app. Hari ini peran semacam itu diam-diam "ditempelkan" ke app fitur terdekat (mis. logika kirim-email-batch nyangkut di app `web`), padahal kandidat alami-nya adalah **unit worker terpisah**.

M3 menambah **satu pola nudge ke-6** di `fanout` step 2 (sejajar 5 nudge yang ada, bentuk identik: tantang anti-yes-man → tandai output `NEW` → realizer `add-app`) + **1 baris Challenge Checklist** (step 3) + **opsional 1 sub-clause advisory** di `architect` step 4.5. Itu saja. **Murni advisory** — `fanout` MENGUSULKAN; user/`add-app` yang memutuskan. **Tak ada `platform:` block** di workspace.yaml, **tak ada skill `/platform`**, **type enum `fe|be|fullstack` tak berubah** (worker = `type: be` dgn responsibility cross-cutting), **skill tetap 21**, **rules tetap 5**.

> **Catatan jujur (advisory, bukan gate).** M3 **tak menambah palang keras**. Nudge cross-cutting hidup di `fanout` sebagai usulan yang HARUS lolos tantangan anti-yes-man (sama seperti APP-BARU / PACKAGE / VENDOR), lalu cuma ditandai `NEW` di `fanout.md` — yang **mewujudkan** (nulis entri ke `workspace.yaml` + bring-up) tetap `add-app`, lewat gate-nya sendiri. Sub-clause `architect` step 4.5 (bila dipakai) juga advisory: "pertimbangkan apakah butuh unit worker", bukan "blokir kalau tak ada worker". Satu-satunya STOP di pipeline tetap Security Gate `ship` yang sudah ada — M3 tak menyentuhnya.

## 2. Masalah

- **`fanout` tak punya pola untuk peran cross-cutting.** Step 2 menantang 5 kemungkinan unit baru (APP / PACKAGE / VENDOR / DESIGN-SYSTEM / consumers), tapi tak ada yang menanyakan: *"apakah peran ini infrastruktur runtime lintas-app — queue / job / audit / background — yang lebih cocok jadi worker terpisah ketimbang nyangkut di app fitur?"*. Tanpa nudge, peran cross-cutting **default-nya tertelan** ke app terdekat tanpa pertimbangan eksplisit.
- **Konsekuensi: System Map jadi keliru sejak P1.** Bila kerja background di-claim oleh app `web`, maka `capabilities`/`responsibility` `web` membengkak dgn peran yang sebenarnya bukan miliknya → `plan`/`build`/`breakdown` hilir mewarisi pemetaan yang salah, dan refactor "pisahkan worker" jadi mahal belakangan.
- **Trigger konkret (ilustrasi, desain tetap generik).** Skenario solo-dev full-AI bikin produk multi-app (uji-alat saja). Fitur "kirim notifikasi order + retry": logika retry/queue/back-pressure bukan urusan `web` (FE+thin BE) maupun `api` (request-response sinkron) — itu **background-worker**. Tanpa nudge, `fanout` akan menempelkan "kirim notifikasi" ke `api` (sinkron, rapuh saat volume tinggi). Nudge ke-6 memunculkan pertanyaan: "peran ini cross-cutting → butuh unit worker terpisah?" — user lolos-kan tantangan → `fanout` usul app `worker` (`type: be`) bertanda `NEW` → `add-app` wujudkan. **Bukan ecommerce-specific**: queue/job/audit berlaku lintas-domain.

## 3. Tujuan & Non-Tujuan

**Tujuan**
- `fanout` step 2: **+1 bullet nudge (pola ke-6)** — "kalau ADA peran cross-cutting / platform (queue / job-runner / audit-log / background-processing) yang bukan milik satu app → tantang (anti-yes-man): beneran butuh unit worker terpisah, atau bisa ditampung app existing? Lolos → usulkan app worker (`type: be`, responsibility cross-cutting) bertanda `NEW`; diwujudkan `add-app`." Bentuk **identik** 5 nudge existing.
- `fanout` step 3 Challenge Checklist: **+1 baris** "Ada peran cross-cutting / platform (queue/job/audit/background) yang bukan milik satu app → butuh unit worker terpisah? (beneran perlu, atau bisa ditampung app existing / scope-creep?)".
- `architect` step 4.5 (**opsional, advisory**): **sub-clause kecil** di bawah klausa ELICIT — saat mengisi slot `invariants.md` Authz/RBAC & Rate-limit, bila kebutuhan bersifat **runtime cross-cutting** (queue/job/audit) pertimbangkan apakah butuh unit worker; usul app lewat `fanout`→`add-app`, **bukan** kunci slot invarian baru. JANGAN edit string M6 yang sudah ada di step 4.5.
- (Opsional) Induk §9 fanout-prose (line 195): tambah "peran cross-cutting?" ke daftar Challenge yang dicontohkan, bila ingin induk sinkron dgn perilaku SKILL.

**Non-Tujuan (seam bersih, anti scope-creep — cermin M6 §3)**
- **Tak ada `platform:` block** di `workspace.yaml` shape (init §5 + induk §7.1). DEFER.
- **Tak ada skill baru** `/platform` / `/capability` / `/worker`. **Skill tetap 21.** Nol churn `plugin.json`/`marketplace.json`/README/induk §12 (lifecycle — tak ada fase baru).
- **Type enum `fe|be|fullstack` TAK berubah.** Worker = `type: be` dgn `responsibility` cross-cutting (mis. "queue/job runner lintas-app"). TIDAK menambah `worker` ke enum (yang akan menyentuh init L49 + add-app L15/L30/L45 + mungkin `wire` mode-skip = bukan-light). Bila author/eksekutor yakin butuh type baru → **FLAG di scopeFlags**, jangan diam-diam balloon.
- **Tak ada palang keras baru.** Nudge = advisory; diksi "tantang/usulkan/pertimbangkan", BUKAN "blokir/wajib/STOP". Satu-satunya STOP tetap Security Gate `ship` existing.
- **`fanout` TAK menulis entri app worker ke `workspace.yaml`.** Sama seperti APP-BARU/PACKAGE-NEW: `fanout` cuma MENGUSULKAN (tandai `NEW`); penulis entri = `add-app` (dipanggil otomatis `feature`). `fanout` hanya update `capabilities` + `consumers` unit **existing** (aturan step 4 yang ADA — tak diubah).
- **Tak menambah slot baru ke `invariants.md`.** RBAC/Rate-limit/Webhook/Idempotency **sudah punya slot** (template L17/L23/L26/L14). M3 tak menggandakannya. Nudge cross-cutting menunjuk ke slot existing / unit worker, bukan bikin invarian baru.
- **Tak menyentuh `wire` — TAPI jujur soal lubang headless-worker.** `wire` punya mode-skip TERDOKUMENTASI hanya untuk `type: package` (mode-package — reference §I) & `add-integration` inbound (mode-integration — reference §J). **Tak ada mode headless-worker di disk:** smoke gate `wire` (reference §E L44-46) mengasumsikan BE yang melayani request — `FE→BE` (FE boot & berhasil panggil BE health/ping) atau BE punya health endpoint. **Worker `type: be` murni-background TANPA route inbound** (queue/job/audit) tak punya jawaban bersih ke gate itu. Konsekuensi nyata: worker yang diusulkan nudge ke-6 lewat `feature`→`add-app`→`architect`→`wire` (feature/SKILL.md L25 men-dispatch app `NEW` apa pun) **akan kemungkinan besar mentok di smoke** dan butuh jalur scopeFlag (checklist 4d "wire mode baru"). **Itu outcome yang DIHARAPKAN untuk worker pure-background, BUKAN edge-case.** M3 sendiri TIDAK menambah mode itu (di luar fix-light) — ia hanya MENGUSULKAN unit worker; siapa pun yang menjalankan `wire` untuk worker routeless WAJIB FLAG (4d) saat smoke tak bisa dijawab. Worker yang KEBETULAN punya route (mis. health/admin endpoint) bisa lolos jalur app biasa — tapi jangan asumsikan itu default.
- **Tak menyentuh** induk §7.1 (skema workspace.yaml) & §17 Knowledge listing (shape tak berubah) & §8 repo-tree (tak ada file/dir baru). Lihat §4-RISIKO-F.

## 4. Decisions (tiap fork + alternatif ditolak + alasan)

### D1 — Surface nudge = `fanout`, BUKAN `architect`
- **Keputusan:** Nudge "peran cross-cutting?" hidup di **`fanout` step 2** (sejajar 5 nudge). `architect` cuma opsional re-confirm advisory di step 4.5.
- **Alternatif ditolak (dari handoff):** "rekomendasi app worker **di architect**".
- **Alasan:** Disk membuktikan `architect` **tak punya seam usul-app**. `architect/SKILL.md` Catatan L53 eksplisit: "ia **tidak** nulis entri app/package baru ke `workspace.yaml`"; step 3a/3b/3c cuma set `stack` unit yang SUDAH terdaftar. Seam usul-app = **`fanout`** (step 2 bullet APP-BARU → realizer `add-app`). Menulis "architect rekomendasi app worker" akan bikin eksekutor mencari seam yang tak ada → spec menggantung. (Grounding RISIKO-A.)

### D2 — Gap dipersempit ke mekanisme runtime cross-cutting; RBAC/rate-limit DIKELUARKAN
- **Keputusan:** Pola ke-6 hanya menjaring **queue / job-runner / audit-log / background-processing** (mekanisme runtime yang BELUM punya rumah). **RBAC / rate-limit / webhook / idempotency TIDAK** masuk klaim "nggak punya tempat".
- **Alternatif ditolak (brief mentah):** "workspace.yaml nggak punya tempat utk queue/job-runner/RBAC/audit/rate-limit lintas-app".
- **Alasan:** RBAC (`## Authz / RBAC` L17), rate-limit (`## Rate-limit / Abuse` L23), webhook (`## Integrasi & Webhook Eksternal` L26), idempotency (`## Idempotency` L14) **SUDAH punya slot** di `invariants.md` sebagai *keputusan-fondasi-terkunci*. Klaim mentah "tak punya tempat utk RBAC/rate-limit" **over-claim** → akan men-trigger eksekutor bikin tempat-baru → duplikat `invariants.md` (persis anti-pola yang M6 hindari: "tak menggandakan invariants.md PII/PCI"). Yang benar-benar yatim = **mekanisme runtime cross-cutting** → itulah gap M3. (Grounding RISIKO-B.)

### D3 — Worker = `type: be`, enum TAK diubah
- **Keputusan:** Unit worker yang diusulkan pakai `type: be` (background service tanpa FE) dgn `responsibility` menyebut sifat cross-cutting. Enum `fe|be|fullstack` tak disentuh.
- **Alternatif ditolak:** Tambah `worker` ke enum.
- **Alasan:** `type` enum di-hardcode di **3 surface** (init L49 `type: <fe|be|fullstack>`; add-app L15/L30/L45 `fe/be/fullstack`; induk §7.1 L104 `type: fullstack  # fe | be | fullstack`). (§17 induk L302-307 BUKAN salah satunya — itu listing Skills(21)/Rules(5)/Knowledge, tak memuat enum; jangan dijadikan pointer enum.) Menambah `worker` = sentuh init + add-app (+ mungkin `wire` mode-skip) + induk §7.1 = **jauh dari light**. Worker = background `be` muat tanpa nilai enum baru. Bila eksekutor menemukan worker BENAR-benar butuh type tersendiri → **scopeFlag**, bukan diam-diam. (Grounding RISIKO-C.)

### D4 — Advisory, bukan gate
- **Keputusan:** Diksi nudge = "tantang / usulkan / pertimbangkan / mungkin butuh". Tak ada "blokir/wajib/STOP". `fanout` MENGUSULKAN; user approve/koreksi (gate `fanout` existing); `add-app` wujudkan (gate-nya sendiri).
- **Alternatif ditolak:** Nudge keras "STOP kalau peran cross-cutting tak punya app worker".
- **Alasan:** Fix MEDIUM/light = advisory. Gate keras langgar fix-light + langgar preseden M6 (advisory; satu-satunya STOP = Security Gate existing). Shipped-text harus jujur: "fanout MENGUSULKAN; user/add-app yang putuskan". (Grounding RISIKO-D; Honesty-note §6.)

### D5 — `platform:` block + skill `/platform` = DEFER (eksplisit di Non-Tujuan)
- **Keputusan:** Tak ada `platform:` block di workspace.yaml; tak ada skill `/platform`. Ditulis eksplisit di Non-Tujuan (§3) sebagai pagar, cermin M6 Non-Tujuan ("skill tetap 21, nol churn plugin.json").
- **Alternatif ditolak:** Bikin `platform:` block + skill penuh sekarang.
- **Alasan:** Brief eksplisit DEFER. Tanpa pagar Non-Tujuan, fix light gampang "kepleset" nambah block/skill → balloon. (Grounding RISIKO-E.)

### D6 — Diksi "cross-cutting / platform", BUKAN "lintas-app"
- **Keputusan:** Pola ke-6 pakai istilah **"cross-cutting / platform"** (queue/job/audit/background).
- **Alternatif ditolak:** Pakai "lintas-app".
- **Alasan:** Istilah **"lintas-app" SUDAH dipakai** di Challenge Checklist L31 (`dependency/kontrak lintas-app (mis. issuer↔validator)`) untuk **dependency antar-app-existing** — konsep BEDA dari "peran yang bukan milik satu app". Memakai "lintas-app" lagi = ambigu/tabrakan diksi. (Grounding §1a overlap + RISIKO-A diksi.)

### D7 — Induk §7.1/§17/§8 TIDAK disentuh; §9 fanout-prose opsional
- **Keputusan:** Karena shape workspace.yaml & enum & skill-count & file-tree TAK berubah, induk §7.1 (skema L95-115), §17 (Knowledge/Skills/Rules L302-307), §8 (repo-tree) **tak perlu disentuh**. Hanya §9 fanout-prose (line 195) **opsional** disinkronkan bila ingin induk mencerminkan nudge ke-6.
- **Alternatif ditolak:** Sentuh §7.1/§17 untuk "mendokumentasikan" worker.
- **Alasan:** Tak ada perubahan shape/enum/count → menyentuh listing itu = drift tanpa sebab. Default light: jangan. (Grounding RISIKO-F.)

## 5. Design per-komponen (edit-map before→after; teks-lama = verbatim disk SEKARANG, dari grounding)

> **Catatan baca:** baris `before` adalah kutipan VERBATIM disk saat ini (anchor `grep -Fc -e` = 1, diverifikasi). Baris `after` = hasil sisip. Semua sisipan = **sub-bullet / baris baru**, **TANPA renumber** step (step 2 & 3 pakai bullet, bukan nomor → aman). Edit-map yang nge-quote teks-lama = dokumentasi, **bukan** pointer live.

### 5a. `plugin/skills/fanout/SKILL.md` — SURFACE UTAMA (pola nudge ke-6)

**Sisip-1 — step 2, bullet nudge ke-6.** Sisip sebagai sibling SESUDAH bullet PACKAGE (current L20), SEBELUM bullet VENDOR (current L21). (Boleh juga sesudah APP-BARU L19; pilih sesudah PACKAGE agar APP-BARU & cross-cutting tak berdempet membingungkan — keduanya soal "unit baru". Eksekutor pilih satu posisi; verifikasi anchor.) **Apa pun posisi yang dipilih:** bullet baru WAJIB pertahankan bentuk-nudge existing (tantang anti-yes-man → tandai `NEW` → realizer `add-app`); dan anchor bullet PACKAGE (L20) tetap target sisip yang TERVERIFIKASI (`grep -Fc` = 1) kecuali eksekutor pindah posisi & me-`grep` ulang anchor baru. Jangan free-hand posisi tanpa re-grep.

before (anchor, match=1):
```
- **Kalau ADA kode-bareng yang dipakai >1 app** (mis. format uang, tipe domain bersama) → mungkin **SHARED PACKAGE**. Tantang (anti-yes-man): beneran shared >1 app, atau cukup 1 app saja? Lolos → tandai `PACKAGE NEW: <nama>` (langkah 4); diwujudkan `add-package` (dipanggil otomatis `feature`). **Kalau fitur menyentuh API package yang SUDAH ADA** → tandai `PACKAGE TOUCHED: <nama>` + tarik daftar consumer dari `packages[<nama>].consumers` (basis fan-IN; `plan` yang memutuskan BREAKING).
```
after (bullet baru disisipkan SESUDAH baris di atas):
```
- **Kalau ADA kode-bareng yang dipakai >1 app** (mis. format uang, tipe domain bersama) → mungkin **SHARED PACKAGE**. Tantang (anti-yes-man): beneran shared >1 app, atau cukup 1 app saja? Lolos → tandai `PACKAGE NEW: <nama>` (langkah 4); diwujudkan `add-package` (dipanggil otomatis `feature`). **Kalau fitur menyentuh API package yang SUDAH ADA** → tandai `PACKAGE TOUCHED: <nama>` + tarik daftar consumer dari `packages[<nama>].consumers` (basis fan-IN; `plan` yang memutuskan BREAKING).
- **Kalau ADA peran cross-cutting / platform** (queue, job-runner, background-processing, audit-log) yang bukan milik satu app — kerja runtime lintas-app, bukan dependency antar-app existing — mungkin butuh **UNIT WORKER terpisah**. Tantang (anti-yes-man): beneran perlu unit worker sendiri, atau bisa ditampung app existing / scope-creep? Lolos → usulkan app worker bertanda `NEW` (langkah 4) dengan `type` `be` + responsibility cross-cutting (mis. "queue/job runner lintas-app"); diwujudkan `add-app` (dipanggil otomatis `feature`). `fanout` cuma **MENGUSULKAN** — yang nulis entri + bring-up = `add-app`. (RBAC/rate-limit/webhook/idempotency BUKAN ini — itu invarian fondasi, sudah punya slot di `invariants.md`; jangan diusulkan jadi worker.)
```

**Sisip-2 — step 3 Challenge Checklist, +1 baris.** Sisip SESUDAH baris "dependency/kontrak lintas-app" (current L31), agar konsep cross-cutting berdampingan tapi terbedakan dari dependency-lintas-app.

before (anchor, match=1):
```
- Ada dependency/kontrak lintas-app (mis. issuer↔validator)?
```
after:
```
- Ada dependency/kontrak lintas-app (mis. issuer↔validator)?
- Ada peran cross-cutting/platform (queue/job/audit/background) yang bukan milik satu app → butuh unit worker terpisah? (beneran perlu, atau bisa ditampung app existing / scope-creep?)
```

**Catatan output-template (step 4):** unit worker memakai penanda `NEW` yang SUDAH ADA — baris template `<usulan-nama> (NEW — belum ada) : <peran>      # app baru; diwujudkan add-app` (current L40) **cukup** untuk worker (worker = app `type: be`). **TIDAK** menambah baris template baru. Aturan step 4 yang ADA — "Unit bertanda `NEW`/`PACKAGE NEW` **JANGAN** ditulis ke `workspace.yaml` di sini — itu jatah `add-app`/`add-package`" — otomatis berlaku ke worker (worker = `NEW`). **Tak ada edit di step 4.**

> **Bug-guard colon-space:** baris bullet baru = **prose**, bukan value YAML/description → `: ` di dalamnya (mis. "type `be`") DIHINDARI dgn backtick + kata-hubung. Nudge baru TIDAK menambah baris ke output-template `fanout.md` (yang memang pakai ` : ` sebagai format-display existing). Jadi M3 tak menambah `: ` baru ke konteks YAML mana pun.

### 5b. `plugin/skills/architect/SKILL.md` — sub-clause advisory (OPSIONAL, HOTSPOT bersama M6/Stream-A)

> **PERINGATAN KONTRAK:** step 4.5 sudah memuat klausa **M6** (anchor verbatim `**Compliance constraint (M6):** baca `control/business/risks.md` ...` — match=1, diverifikasi). Stream-A (sensitivity) juga mungkin menyentuh 4.5. **JANGAN edit string M6.** Sisip M3 sebagai **sub-clause terpisah** di akhir bullet ELICIT (sesudah kalimat M6), bukan modifikasi kalimat M6. Verifikasi anchor M6 tetap match=1 setelah edit.

before (anchor bullet ELICIT, match=1 — kutipan ringkas baris L40; akhir baris ini memuat klausa M6):
```
... Lihat `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`.
```
after (sub-clause M3 ditambahkan SESUDAH kalimat M6, masih dalam bullet ELICIT yang sama):
```
... Lihat `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`. **Cross-cutting (M3, advisory):** bila kebutuhan bersifat runtime lintas-app (queue/job/audit/background) — bukan invarian fondasi — pertimbangkan apakah butuh **unit worker** terpisah; usul lewat `fanout`→`add-app`, **bukan** kunci slot invarian baru (Authz/Rate-limit sudah punya slot). Tak memblokir.
```

> **Sifat OPSIONAL:** sub-clause 5b memperkaya elicitation tapi BUKAN inti M3 — nudge utama ada di `fanout` (5a). Bila eksekutor ingin minimal-viable absolut, 5b boleh di-skip; pipeline tetap koheren (fanout sudah menjaring cross-cutting). Bila dipakai, ia advisory murni (cermin sifat M6 di seam yang sama).

### 5c. TAK disentuh (eksplisit)

- `plugin/skills/init/SKILL.md` — shape workspace.yaml & enum L49 tak berubah.
- `plugin/skills/add-app/SKILL.md` — worker masuk jalur app biasa (`type: be`); enum L15/L30/L45 tak berubah. (add-app sudah jadi realizer `NEW` apa pun, termasuk worker — tak perlu edit.)
- `plugin/skills/wire/SKILL.md` — TIDAK diedit oleh M3, tapi BUKAN "jalur app normal yang mulus" untuk worker. `wire` tak punya mode headless-worker di disk (mode-skip hanya `type: package` reference §I + `add-integration` inbound reference §J); smoke gate (reference §E L44-46) mengasumsikan BE melayani request (`FE→BE`/health-ping). Worker `type: be` murni-background TANPA route inbound **kemungkinan besar mentok di smoke** → jalur scopeFlag 4d ("wire mode baru"), yang EXPECTED untuk worker pure-background. Lihat §3 Non-Tujuan ("Tak menyentuh `wire`") untuk detail. Worker yang punya health/admin route bisa lolos biasa.
- `plugin/template/control/invariants.md` — tak menambah slot (RBAC/rate-limit/webhook/idempotency sudah ada).
- `plugin/template/control/workspace.yaml` — **FIKSI** (tak ada file template; di-generate `init` step 5). M3 tak merujuknya.
- `plugin.json` / `marketplace.json` / README — nol churn (skill tetap 21).

## 6. Parent-spec amendments (induk `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`)

**Default: induk shape TAK disentuh** (D7). Berikut peta seksi + status:

| Seksi induk | Konten | Status M3 |
|---|---|---|
| §7 repo-tree (L64-93) | tree `control/` | **TAK disentuh** — tak ada file/dir baru (worker = entri di workspace.yaml apps[], bukan file control/). |
| §7.1 workspace.yaml skema (L95-115) | shape apps[]/packages[] + enum `type` L104 | **TAK disentuh** — worker = `type: be` (enum existing), tak ada `platform:` block. |
| §8 repo-tree rules/template (L137-140) | listing rules/dir | **TAK disentuh** — rules tetap 5, tak ada file baru. |
| §9 `fanout` prose (L193-198) | Input/Perilaku/Output/Gate fanout | **OPSIONAL** — lihat amendment di bawah. |
| §12 lifecycle | fase | **TAK disentuh** — tak ada fase baru. |
| §17 Komponen (L302-307) | Skills(21)/Rules(5)/Knowledge | **TAK disentuh** — skill 21, rules 5, shape knowledge tak berubah. |

**Amendment OPSIONAL — §9 fanout-prose (sinkron perilaku SKILL):**

before (anchor, match=1, line 195):
```
Challenge: "ada app kelewat? dependency lintas-app? butuh vendor eksternal?".
```
after:
```
Challenge: "ada app kelewat? dependency lintas-app? peran cross-cutting (queue/job/audit) → unit worker? butuh vendor eksternal?".
```
> **Mis-aimed-pointer guard:** ini §9 (`#### fanout (P1)`, line ~193), BUKAN §17. Bila eksekutor skip sub-clause 5b (architect), §9 tetap boleh disinkronkan (ia hanya mencerminkan fanout). Bila ingin minimal absolut, §9 boleh di-skip juga — perilaku-of-record ada di `fanout/SKILL.md`. Sisip frasa, **bukan** renumber.

## 7. Honesty-note (advisory vs gate — preseden M6)

- **Surface tempat logika beneran jalan = `fanout/SKILL.md` step 2/3.** Di sinilah nudge ke-6 hidup. Shipped-text harus jujur: bullet menyebut `fanout` cuma **MENGUSULKAN** (`NEW`) — yang nulis entri + bring-up = `add-app` (cermin frasa identik 5 nudge existing: "`fanout` cuma **MENGUSULKAN**"). Tak ada klaim "fanout bikin worker".
- **`architect` step 4.5 (bila 5b dipakai) = murni advisory.** Diksi "pertimbangkan / usul lewat fanout / tak memblokir / bukan kunci slot baru". Tak ada STOP. Sejajar sifat M6 di seam yang sama.
- **Tak ada gate baru di mana pun.** Satu-satunya STOP pipeline tetap Security Gate `ship` existing (tak disentuh M3). Nudge cross-cutting tunduk ke gate `fanout` (approve/koreksi user) yang SUDAH ADA — bukan gate baru.
- **Jujur soal scope:** M3 **memperkaya seam yang ADA** (`fanout` pola unit-baru), bukan bikin mesin baru. Worker = app `type: be` biasa lewat realizer `add-app` existing. Tak ada `platform:` block / skill / type-enum baru — itu DEFER, ditulis di Non-Tujuan agar tak bocor.

## 8. Self-review checklist awal

- [ ] **Anchor verbatim:** fanout L20 (PACKAGE), L31 (dependency lintas-app), L40 (output-template NEW) + architect L40 (M6 clause) + induk §9 L195 — semua `grep -Fc -e` = 1 SEBELUM edit. (Diverifikasi saat writing spec; ulang saat writing-plans.)
- [ ] **No-renumber:** sisipan = bullet/baris baru di step 2 & 3 (bullet, bukan nomor) → tak ada step ter-renumber. architect 4.5 = sub-clause di akhir bullet ELICIT, bukan bullet/step baru.
- [ ] **M6 string utuh:** setelah edit 5b, anchor `**Compliance constraint (M6):**` + `compliance-risk.md` di architect masih match=1 (M3 nempel SESUDAHNYA, tak menimpa).
- [ ] **Diksi advisory:** nudge baru pakai "tantang/usulkan/mungkin/pertimbangkan" — NOL "blokir/wajib/STOP/gagal". Grep negatif di baris baru.
- [ ] **Diksi cross-cutting ≠ lintas-app:** baris baru pakai "cross-cutting / platform"; istilah "lintas-app" L31 existing tak diutak-atik (tetap untuk dependency antar-app). Tak ada tabrakan makna.
- [ ] **Enum bersih:** baris baru menyebut worker `type` `be` (backtick, bukan `type: be` polos) — TIDAK menambah `worker` ke enum mana pun (init/add-app/induk). Grep `worker` tak muncul di enum-list.
- [ ] **colon-space guard:** baris bullet baru = prose; tiap `be`/`type` dibungkus backtick + kata-hubung → tak ada ` : ` baru di konteks YAML/value/description. (fanout description frontmatter TAK disentuh.)
- [ ] **No `platform:` leak:** tak ada `platform:` block ditambah ke workspace.yaml shape (init §5 / induk §7.1). Tak ada skill `/platform` / file baru. Skill tetap 21, rules tetap 5.
- [ ] **Realizer benar:** nudge merujuk `add-app` sebagai penulis entri (bukan architect). architect 5b merujuk `fanout`→`add-app`, bukan "architect nulis app".
- [ ] **Induk shape tak drift:** §7.1/§17/§8 tak disentuh (shape/enum/count tak berubah); hanya §9 fanout-prose opsional. Bila §9 di-skip, induk tetap konsisten.
- [ ] **scopeFlags bila menyimpang:** (a) nambah `worker` ke enum; (b) nambah `platform:` block; (c) gate keras; (d) `wire` mode headless-worker baru — keempatnya bukan-light → WAJIB FLAG, jangan diam-diam. **CATATAN (d):** untuk worker `type: be` murni-background TANPA route inbound, smoke gate `wire` (reference §E) tak bisa dijawab → 4d adalah outcome yang DIHARAPKAN, bukan edge-case (lihat §3 "Tak menyentuh `wire`" + §5c). M3 sendiri tak menambah mode itu.
- [ ] **Generik:** queue/job/audit/background = lintas-domain; nudge tak meng-hardcode ecommerce/skenario uji. Worker = pola umum.
