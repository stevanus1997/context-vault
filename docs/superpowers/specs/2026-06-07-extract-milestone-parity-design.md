# EX1 — extract milestone parity: brownfield front-loader nyusul M1/M5/M6/L1 + konvensi share

> Gap **EX1** — campuran severity: **1 MEDIUM** (idempotency re-run) + sisanya **LOW/fix-light** (wording, klausa guard, cross-ref). Tanggal: **2026-06-07**. Repo `~/Developer/ai-boilerplate`, base `main`. Grounding terverifikasi via audit fan-out (10 dimensi, adversarial-verified) + grep anchor verbatim semua = match 1.

## 1. Ringkasan

`extract` = skill **brownfield-only, opsional, sekali-jalan** yang front-load `control/business/` (domain/flows/glossary) dari kode existing + wawancara. Terakhir disentuh **2026-05-31** — file **terkecil** (32 baris) — dan **tak terbawa satu pun** gelombang milestone Jun 1–6 (M1/M3/M4/M5/M6/M7/M8/H2/H3/L1/L2/L3/debt) yang merework hampir semua skill lain. Audit fan-out (adversarial-verified) menyimpulkan: ketinggalannya **campuran** — sebagian **sengaja ditunda** oleh milestone itu sendiri (M4/M5/M6/H2/H3 masing-masing menulis "brownfield extract X = sub-proyek terpisah, defer"), sebagian **drift beneran** yang in-lane & murah ditutup.

EX1 menutup HANYA yang **terbukti in-lane** (tak melanggar sole-writer skill lain, tak ngambil sub-proyek yang ditunda):

1. **[MEDIUM] Idempotency re-run** — extract satu-satunya penulis knowledge-bersama TANPA guard dedup. Re-run → numpuk aturan/flow/istilah ganda. Semua sibling penulis (`intake`/`add-app`/`add-integration`/`architect`/`wire`/`fanout`/`plan`/`design-system`) sudah punya. Ini satu-satunya **defect fungsional**.
2. **[LOW] Degrade clause** — tak ada fail-safe bila `capabilities` kosong / `path` app hilang; sibling semua punya `Degrade:`.
3. **[LOW] Klaim "format sama dengan intake" menyesatkan** — extract cermin **promosi durable** intake (`business/{domain,flows,glossary}.md`), BUKAN `features/<f>/business.md` (yang kini punya epic/depends_on/risk/sensitivity — M1/M7/M8). Perjelas.
4. **[LOW] Blueprint-skip (L1)** — extract nge-loop SEMUA app buta; app blueprint (declared-belum-di-bring-up, dir kosong) bisa bikin extract "mengarang aturan dari kode yang bukan produk". extract memang **tak masuk edit-map L1** (reader-set hanya `ask`/`design-system`/`fanout`).
5. **[LOW] Deteksi vendor (M5)** — detect-and-flag SDK vendor → saran `/add-integration` (BUKAN nulis `integrations.md`).
6. **[LOW] Cross-ref batas design-system CAPTURE** — disclaimer sibling kini sepihak (design-system bilang "TIDAK nyentuh business/", extract diam).
7. **[LOW] Cross-ref deferral compliance (M6)** — catat `risks.md` bukan jatah extract + angkat advisory bila ketemu.

**Yang SENGAJA TIDAK diambil** (verifier menolak sebagai overreach/sub-proyek ditunda — lihat §3 D8): nulis `control/schema/` (sole-writer rule `schema-projection` via wire/build; brownfield sudah ter-handle `(pra-M4)`), seed `debt.yaml` (spec eksplisit menolak deteksi-debt berbasis-scan; two-writer lock), nyentuh `feedback/` (human-only), jadi **penulis** `risks.md` (sole-writer `discovery`).

**Skill tetap 21. Tak ada rule baru. Tak ada file baru. Tak ada status/enum baru.** EX1 menyentuh: `plugin/skills/extract/SKILL.md` (utama) + 3 parent-sync (`induk §9`/`§14`, `rules/compliance-risk.md`, `skills/init/SKILL.md` reader-list). `description:` frontmatter extract **TAK disentuh**.

## 2. Masalah & konteks

### 2.1 Trigger konkret (ilustrasi; desain generik)

Solo-dev mengadopsi monorepo SaaS existing (brownfield besar). Jalur kanonik: `init → architect(capture) → extract(opsi) → wire`. Dia jalankan `/extract business`. Empat hal terjadi yang **tak ideal**:

- extract nge-scan SEMUA `apps[]`, termasuk app yang baru **di-declare blueprint** di `init` (opsi blueprint Langkah 3) — dir-nya kosong/template. extract bisa salah-baca scaffold/template sebagai "aturan domain" → **mengarang**, justru melanggar guarantee "TERBUKTI di kode".
- Kode jelas-jelas meng-import klien Stripe/SendGrid, tapi extract **buta total** — nol sinyal ke user buat `/add-integration`.
- Beberapa minggu kemudian user **re-run** `/extract` (lupa udah pernah, atau mau lengkapi app baru). extract **numpuk** aturan/flow/glossary ganda di `business/*.md` — tak ada cek "fakta serupa sudah ada?" yang dimiliki kembarannya `intake`.
- Wawancara memunculkan kewajiban GDPR nyata; extract tak punya rumah/arahan untuk itu (risks.md sentinel selamanya, tak ada saran "angkat advisory").

Generik: nol vendor/stack-specific; berlaku semua produk brownfield.

### 2.2 Bukti disk (anchor verbatim, semua `grep`/`sed` = match 1)

- **Klaim format imprecise (2×).** `extract/SKILL.md:8` "Output FORMAT SAMA dengan output `intake`." + `:28` "(format sama dengan `intake`)". TAPI `intake/SKILL.md:55` menunjukkan output PRIMER intake = `features/<fitur>/business.md` (Tujuan/Pengguna/Aturan/…) + metadata `feature.yaml`; baru SEKUNDER promosi durable ke `business/{domain,flows,glossary}.md`. extract cuma mirror yang SEKUNDER. Plus `feature.yaml` kini punya `sensitivity/epic/depends_on/risk` (M1/M7) — footprint "output intake" didominasi artefak fitur yang extract tak pernah hasilkan.
- **Tak ada idempotency.** `extract/SKILL.md:13` cuma "jangan timpa membabi buta"; `:28` cuma "Konservatif — jangan mengarang" — **tak ada** "cek apakah fakta serupa sudah ada → jangan duplikat". Kontras `intake/SKILL.md:55`: "**Idempotent:** sebelum nambah, cek apakah fakta serupa sudah ada di file tujuan — update yang ada, jangan duplikat (re-run intake nggak boleh numpuk aturan ganda)." extract di-deklarasi "sekali jalan" (`:31`) tapi user **bisa** re-run; satu-satunya penulis `business/*` yang tanpa guard ini.
- **Tak ada Degrade clause.** `extract/SKILL.md:13/16` baca `workspace.yaml`+`path` tapi diam soal `capabilities` kosong / `path` hilang / architect belum jalan. Sibling punya `Degrade:` (architect/build/intake/plan/feature/design-system).
- **Blueprint buta.** `extract/SKILL.md:16` "Untuk tiap app, baca kode di `path`-nya. Identifikasi yang **TERBUKTI di kode**" — loop semua app, nol kesadaran marker. `init/SKILL.md:33`+`:57` menetapkan marker blueprint (`(blueprint — belum di-bring-up)` di `responsibility` + komentar `# blueprint, belum di-bring-up`) dan menyebut pembaca = "`ask`/`design-system`/`fanout`" — **extract absen**. Pola reader kanonik ada di `ask/SKILL.md:34`.
- **Vendor buta.** `extract/SKILL.md:16-19` cuma deteksi domain/flow/glossary; `:28` cuma nulis 3 file. `add-integration/SKILL.md:17` "**Satu-satunya penulis entri `integrations.md`.**" → extract tak boleh nulis, tapi DETECT-and-flag in-lane (pola "deteksi di sini, write = jatah owner" persis `architect/SKILL.md:24`).
- **design-system asimetri.** `design-system/SKILL.md:50` "TIDAK nyentuh `control/business/*`" (disclaimer sepihak). extract tak punya disclaimer balik.
- **Compliance sole-writer.** `rules/compliance-risk.md` "Hanya `discovery` yang menulis `risks.md` … Tak ada pembaca yang menulis `risks.md`. Bila pembaca menemukan gap compliance baru → angkat ke user (advisory)". `:26` degrade "produk tanpa discovery → best-effort … JANGAN error, JANGAN blokir". `discovery` greenfield-only → brownfield tanpa jalur seed (by-design).
- **Induk co-stale.** `§9:181` "**Format sama** dengan output `intake`" — drift sama seperti SKILL.md. `§14:289` "tipis dulu (+ opsi `extract`)" tak menyebut risks.md/blueprint.

### 2.3 Kenapa MEDIUM cuma idempotency (kalibrasi severity dari verifier)

Audit awal sempat menandai risks.md sebagai "gap paling kritis"; verifier adversarial **menurunkannya** ke LOW/cross-ref (sole-writer + deferral eksplisit M6 — §3 D8). Yang **benar-benar** bisa meng-korup knowledge secara senyap = **re-run duplication** (D2): tak ada gate yang menangkapnya, kembaran `intake` dipatch justru untuk ini. Blueprint (D4) LOW karena common-case (dir kosong → "TERBUKTI di kode" nemu nol → degrade mulus) + 3 jaring existing (TERBUKTI-only, critic WAJIB, GATE per-bagian); bahaya cuma di konjungsi sempit (kode nyasar di dir blueprint).

## 3. Decisions (tiap fork + alternatif ditolak + alasan) — menggantikan brainstorming 1-1

> Plain-language; user bisa veto mana pun.

### D1 — Perjelas "format sama dengan intake" (jangan hapus, presisikan)
**Putusan:** Ganti klaim telanjang jadi: extract mirror **promosi durable** intake step 7 (`business/{domain,flows,glossary}.md`), BUKAN feature-spec `business.md`; extract tak punya konteks fitur (tak nulis business.md per-fitur, tak isi metadata feature.yaml).
**Ditolak:** *(a) hapus klaim sepenuhnya* — DITOLAK: relasi extract↔intake nyata & berguna (mendarat di tempat sama). Yang salah cuma presisinya. *(b) bikin extract ikut nulis `business.md`/metadata fitur* — DITOLAK: extract product-wide one-shot, nol konteks fitur; epic/depends_on/risk/sensitivity = jatah `intake` per-fitur (M1/M7).

### D2 — [MEDIUM] Idempotency re-run (cermin intake:55)
**Putusan:** Tambah klausa idempotent di step 5: sebelum nambah, cek fakta/flow/istilah serupa sudah ada → perkaya/koreksi, JANGAN duplikat.
**Ditolak:** *(a) andalkan "sekali jalan" + "jangan timpa membabi buta"* — DITOLAK: "sekali jalan" = default niat, bukan kunci; user bisa re-run; `business/*` bisa sudah ter-seed JIT lewat `feature` sebelum extract jalan. *(b) bikin extract non-re-runnable (refuse kalau business/* terisi)* — DITOLAK: bertentangan dgn step 1 yang justru baca existing buat melengkapi; merge-dedup lebih benar dari refuse.

### D3 — Degrade clause eksplisit
**Putusan:** step 1 tambah `Degrade:` — `business/*` kosong → seed dari nol; `capabilities` kosong → scan tetap jalan (best-effort); `path` hilang/tanpa kode → SKIP+lapor, jangan error.
**Ditolak:** *(biarkan implisit)* — DITOLAK: tiap sibling modern eksplisitkan fail-safe; implisit = sumber inkonsistensi perilaku.

### D4 — [LOW] Blueprint-skip (cermin ask:34)
**Putusan:** step 2 LEWATI app bertanda blueprint sebelum scan.
**Ditolak:** *(a) tak usah — common case aman)* — DITOLAK: konjungsi sempit (kode template/scaffold nyasar di dir blueprint) → fabrikasi aturan, langgar guarantee inti extract; biaya tutup = 1 klausa. *(b) bikin extract nulis/lepas marker)* — DITOLAK: marker dilepas `architect`/`wire` saat bring-up (`init:57`) — sole-owner; extract cuma READER.

### D5 — [LOW] Deteksi vendor (detect-and-flag, BUKAN write)
**Putusan:** step 2 tambah bullet: detect import SDK vendor → JANGAN tulis integrations.md → saran `/add-integration <vendor>`.
**Ditolak:** *(a) extract nulis integrations.md)* — DITOLAK: `add-integration` sole-writer (`:17`). *(b) inferensi SHAPE penuh dari kode)* — DITOLAK: M5 §14 eksplisit defer ("integration-inference, sub-proyek tersendiri"); EX1 cuma flag-keberadaan (murah, dalam scan yang sudah ada), self-dokumentasi "inferensi penuh = future, di luar scope".

### D6 — [LOW] Cross-ref batas design-system CAPTURE
**Putusan:** Catatan tambah 1 baris: extract = `business/` SAJA; visual = lane `design-system` CAPTURE; extract TIDAK nyentuh `design-system.md`.
**Ditolak:** *(buat extract baca/ekstrak visual)* — DITOLAK: design-system CAPTURE sole-owner visual; cuma tutup asimetri disclaimer (`design-system:50` sudah disclaim balik).

### D7 — [LOW] Cross-ref deferral compliance (M6)
**Putusan:** Catatan tambah 1 baris: `risks.md` bukan jatah extract (sole-writer `discovery`, greenfield-only); brownfield pakai sentinel + pembaca degrade; bila scan/wawancara nemu kewajiban compliance durable → **angkat advisory ke user**, JANGAN tulis. Rujuk `rules/compliance-risk.md`.
**Ditolak:** *(a) bikin extract jadi penulis kedua risks.md — "discovery (greenfield) ATAU extract (brownfield)")* — DITOLAK (refutasi verifier): butuh REWRITE sole-writer rule di file LAIN; M6 defer eksplisit di 3 tempat (§3-Non-Tujuan, edge-case table, "TAK disentuh" list). Edit yang tak bisa ship tanpa ngedit authority-doc skill lain = di luar lane extract HARI INI. *(b) tambah klausa interview compliance penuh)* — DITOLAK alasan sama; cukup cross-ref + advisory-raise (pola reader `compliance-risk.md`).

### D8 — Yang TIDAK diambil (verifier menolak — sole-writer/sub-proyek ditunda)
- **`control/schema/<app>.md`** — sole-writer rule `schema-projection` (`:6` "Jangan ada skill lain menulis"); dipanggil `wire(baseline)`/`build`. Brownfield SUDAH ter-handle: `wire(repair)` generate proyeksi `(pra-M4)` dari file sumber tanpa DB hidup. M4 spec eksplisit defer "brownfield extract populasi skema". **no-change** (cross-ref ke wire sudah ada di `:32`).
- **`debt.yaml`** — spec utang `§3` eksplisit: "Tak ada deteksi debt otomatis lintas-repo / linter — capture berbasis temuan implementer saat build, bukan pemindaian." extract ADALAH pemindaian → persis yang ditolak. Two-writer lock (build append / `/debt` drop). Entri butuh konteks task (discovered_during/owner/area) yang extract tak punya. **no-change.**
- **`feedback/`** — human-only, nol writer-skill (template README). **no-change.**
- **Pipeline-ordering** — `init→architect→extract→wire` masih akurat (extract baca kode langsung, tak butuh `schema/` yang lahir di wire). **no-change.**

### D9 — Tidak menyentuh `description:` frontmatter
**Putusan:** EX1 cuma edit BODY + parent-sync. `description:` (`extract:3`) tetap bersih (colon-space guard). Trigger/when-to-use tak berubah.

## 4. Design per-komponen (edit-map; before = teks DISK SEKARANG, verbatim)

> Semua = sisip klausa/baris dalam struktur yang ADA. **Tak ada renumber step**, tak ada section/file baru. Semua AFTER = BODY prose (colon-space guard hanya untuk `description:` frontmatter — TAK disentuh).

### 4a. `extract/SKILL.md:8` — perjelas format (D1)
- BEFORE: `Tujuan: isi \`control/business/\` dari kode yang sudah ada, untuk produk besar yang perlu knowledge lengkap di awal. Output FORMAT SAMA dengan output \`intake\`.`
- AFTER: `Tujuan: isi \`control/business/\` dari kode yang sudah ada, untuk produk besar yang perlu knowledge lengkap di awal. Output mendarat di \`business/{domain,flows,glossary}.md\` dengan format = **promosi knowledge durable** \`intake\` (step 7) — BUKAN feature-spec \`features/<fitur>/business.md\`. extract tak punya konteks fitur: tak nulis \`business.md\` per-fitur, tak isi metadata \`feature.yaml\` (sensitivity/epic/depends_on/risk — itu jatah \`intake\`).`

### 4b. `extract/SKILL.md:13` — Degrade clause (D3)
- BEFORE: `Baca \`control/workspace.yaml\` (apps + path) + \`control/business/*\` (lihat yang sudah ada, jangan timpa membabi buta).`
- AFTER: `Baca \`control/workspace.yaml\` (apps + path) + \`control/business/*\` (lihat yang sudah ada, jangan timpa membabi buta). **Degrade:** \`business/*\` kosong/absen → seed dari nol; \`capabilities\` kosong → scan kode tetap jalan (best-effort, capabilities cuma mempersempit); app \`path\` hilang/tanpa kode → SKIP app itu + lapor, jangan error.`

### 4c. `extract/SKILL.md:16` — blueprint-skip (D4)
- BEFORE: `Untuk tiap app, baca kode di \`path\`-nya. Identifikasi yang **TERBUKTI di kode**:`
- AFTER: `Untuk tiap app, baca kode di \`path\`-nya. **LEWATI app yang masih blueprint** — \`responsibility\`-nya bertanda \`(blueprint — belum di-bring-up)\` atau entri-nya berkomentar \`# blueprint, belum di-bring-up\`: app itu baru di-declare, belum di-bring-up (path kosong/belum ada), TAK ada perilaku riil untuk diekstrak — mengekstrak "aturan" dari dir blueprint = mengarang dari kode yang bukan produk. Untuk app riil, identifikasi yang **TERBUKTI di kode**:`

### 4d. `extract/SKILL.md:19` — bullet deteksi vendor (D5)
Sisip bullet ke-4 SETELAH baris glossary (`:19`):
- AFTER (baris baru): `- SDK/klien vendor eksternal yang di-import (mis. klien pembayaran/email/kurir/pajak) → **JANGAN tulis \`integrations.md\`** (itu jatah \`add-integration\`, satu-satunya penulis). Catat sebagai temuan & sarankan user jalankan \`/add-integration <vendor>\` per vendor terdeteksi (SHAPE penuh di-elicit di sana). Inferensi SHAPE penuh dari kode = future (M5 §14), di luar scope extract.`

### 4e. `extract/SKILL.md:28` — idempotency + format presisi (D2 + D1)
- BEFORE: `Tulis ke \`control/business/domain.md\`, \`flows.md\`, \`glossary.md\` (format sama dengan \`intake\`). Konservatif — jangan mengarang. Tampilkan draft → minta **approve per bagian**.`
- AFTER: `Tulis ke \`control/business/domain.md\`, \`flows.md\`, \`glossary.md\` (format = promosi durable \`intake\` step 7: domain.md aturan-per-heading, flows.md per-flow, glossary.md \`**istilah** — definisi\`). Konservatif — jangan mengarang. **Idempotent (re-run aman):** sebelum nambah fakta, cek apakah aturan/flow/istilah serupa SUDAH ada di file tujuan — perkaya/koreksi yang ada, JANGAN tambah duplikat (cermin \`intake\` step 7; extract "sekali jalan" tapi user bisa re-run & \`business/*\` bisa sudah ter-seed just-in-time lewat \`feature\`). Tampilkan draft → minta **approve per bagian**.`

### 4f. `extract/SKILL.md:32` — 2 bullet cross-ref di Catatan (D6 + D7)
Sisip 2 bullet SETELAH `:32`:
- AFTER (baris baru): `- Scope = \`business/\` SAJA (domain/flows/glossary). Knowledge VISUAL (tokens/komponen/motion) dari kode existing = lane \`design-system\` mode CAPTURE — \`extract\` TIDAK nyentuh \`design-system.md\`. Sibling front-loader brownfield: \`extract\`=bisnis, \`design-system\`(CAPTURE)=visual.`
- AFTER (baris baru): `- Compliance \`risks.md\` (M6) BUKAN jatah \`extract\` — penulis tunggalnya \`discovery\` (greenfield-only); brownfield tanpa discovery pakai sentinel \`init\` + pembaca (architect/intake/ship) degrade aman. Bila scan/wawancara memunculkan kewajiban compliance durable (PCI/GDPR/pajak/KYC), **angkat ke user sbg advisory** — JANGAN tulis \`risks.md\` (lihat \`${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md\`). Seeding compliance brownfield = sub-proyek terpisah yang sengaja ditunda.`

## 5. Honesty-note (advisory vs gate)

EX1 = **mayoritas wording + klausa-guard, nol gate baru, nol perubahan kontrol eksekusi.** Yang mengubah PERILAKU nyata cuma dua, dan keduanya **memperketat ke arah aman**: (D2) idempotent = hindari korup knowledge senyap; (D4) blueprint-skip = hindari fabrikasi. (D3) degrade = kodifikasi fail-safe (no-op vs error). (D5/D6/D7) = advisory/cross-ref murni — extract TIDAK menulis `integrations.md`/`design-system.md`/`risks.md` (semua sole-writer skill lain).

Surface jujur: bila EX1 dikirim via `ship`, ringkasan PR jujur — "extract nyusul M1/M5/M6/L1 + konvensi share: idempotent re-run, degrade, blueprint-skip, format presisi, cross-ref vendor/visual/compliance. Tak ngambil sub-proyek yang ditunda (schema/debt/integrations-inference/risks-write). Skill tetap 21, nol rule/file/status baru." Jangan klaim extract kini "nyeed compliance" atau "nulis integrations".

## 6. Parent-spec amendments

### `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`

- **§9 `### extract` (`:180` Perilaku).**
  - BEFORE (`:180`): `- **Perilaku:** scan kode lintas repo + wawancara user → isi \`business/\` (domain/flows/glossary). Dijalankan **lewat gate + \`critic\`** (bukan dump mentah; critic mem-flag aturan spekulatif/belum terverifikasi).`
  - AFTER (sisip frasa, no-renumber): tambah di akhir kalimat → `… belum terverifikasi). **Idempotent** (re-run tak numpuk; cermin \`intake\`); **lewati app blueprint**; vendor ke-detect → advisory \`/add-integration\` (tak nulis \`integrations.md\`); compliance \`risks.md\` di luar scope (sole-writer \`discovery\` — angkat advisory).`
- **§9 `### extract` (`:181` Output).**
  - BEFORE (`:181`): `- **Output:** \`business/\` ter-isi. **Format sama** dengan output \`intake\` — sehingga knowledge dari \`extract\` (upfront) dan \`intake\` (just-in-time) mendarat di tempat & format yang sama.`
  - AFTER: `- **Output:** \`business/{domain,flows,glossary}.md\` ter-isi — format = **promosi knowledge durable** \`intake\` (step 7), BUKAN feature-spec \`business.md\`/metadata \`feature.yaml\`. Knowledge \`extract\` (upfront) & \`intake\` (just-in-time) mendarat di tempat & format yang sama.`
- **§14 tabel greenfield-vs-brownfield (`:289` row `business/`).**
  - BEFORE (`:289`): `| \`business/\` | dari nol, per fitur | tipis dulu (+ opsi \`extract\`), di-ekstrak pas \`/feature\` |`
  - AFTER: `| \`business/\` | dari nol, per fitur | tipis dulu (+ opsi \`extract\` utk domain/flows/glossary; \`risks.md\` compliance = sentinel, seed-brownfield ditunda), di-ekstrak pas \`/feature\` |`

### `plugin/rules/compliance-risk.md` (catat deferral terlacak — `:30` "Batas (sadar)")
- BEFORE (`:30`): `- **Batas (sadar):** \`risks.md\` hanya selengkap riset discovery; produk yang skip discovery / regulasi yang luput riset tak tertangkap → gate manusia (architect/ship) = jaring akhir.`
- AFTER: tambah kalimat → `… = jaring akhir. **Brownfield (pakai \`extract\`, tanpa \`discovery\`) TAK punya jalur seed \`risks.md\` — by-design (sub-proyek terpisah, ditunda); \`extract\` mengangkat temuan compliance sbg advisory ke user, tak menulis. Pembaca tetap degrade aman.**`

### `plugin/skills/init/SKILL.md` (reader-list blueprint — `:33` & `:57`)
extract kini READER marker blueprint → tambahkan ke daftar pembaca biar konsisten (cegah drift balik).
- `:33` BEFORE: `… supaya pembaca seperti \`ask\`/\`design-system\`/\`fanout\` tahu app itu baru niat …`
- `:33` AFTER: `… supaya pembaca seperti \`ask\`/\`design-system\`/\`fanout\`/\`extract\` tahu app itu baru niat …`
- `:57` BEFORE: `… supaya pembaca \`apps[]\` (\`ask\`/\`design-system\`/\`fanout\`) tahu app itu baru niat.`
- `:57` AFTER: `… supaya pembaca \`apps[]\` (\`ask\`/\`design-system\`/\`fanout\`/\`extract\`) tahu app itu baru niat.`

**TAK disentuh (eksplisit):** `schema-projection.md`/`debt.yaml`/`feedback/` (D8); `feature.yaml` schema; `sensitivity`/status enum (§12); §7/§8/§17/skill-count (**21**)/`plugin.json`/README; `description:` extract (D9); `wire`/`add-integration`/`design-system`/`discovery` SKILL (cuma DIRUJUK read-only).

## 7. Self-review checklist

- [ ] **Anchor verbatim** — `extract:8/13/16/19/28/32`, `intake:55`, `ask:34`, `add-integration:17`, `design-system:50`, `init:33/57`, induk `§9:180-181`/`§14:289`, `compliance-risk.md:30` — semua `grep -Fc -e`/`sed` = 1 sebelum edit.
- [ ] **No-renumber** — semua sisip klausa/bullet dalam struktur ADA; step 1-5 & §-numbering tak bergeser.
- [ ] **Sole-writer dihormati** — extract TAK nulis `integrations.md`/`design-system.md`/`risks.md`/`schema/`/`debt.yaml`. Cuma detect/flag/advisory/cross-ref.
- [ ] **Colon-space guard** — semua AFTER = BODY prose; `description:` (extract:3) TAK disentuh.
- [ ] **Idempotency (D2)** — klausa "cek serupa → jangan duplikat" identik semangat `intake:55`; "sekali jalan" tetap, tapi re-run aman.
- [ ] **Blueprint (D4)** — wording cermin `ask:34`; extract READER, tak lepas marker.
- [ ] **Severity jujur** — 1 MEDIUM (D2) + sisanya LOW; bukan over-claim.
- [ ] **Generik** — nol vendor/stack/domain-specific; ilustrasi §2.1 cuma contoh.
- [ ] **Scope-light** — 1 file utama + 3 parent-sync; skill tetap 21; nol rule/file/status baru.
- [ ] **D8 didokumentasi** — alasan TIDAK-ambil (schema/debt/feedback/risks-write) tercatat biar maintainer berikut tak salah "lengkapi".
