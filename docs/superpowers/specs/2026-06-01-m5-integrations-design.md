# context-vault — Integrasi Vendor Eksternal (M5) — Design Spec

- **Tanggal:** 2026-06-01
- **Status:** Draft disetujui untuk masuk tahap perencanaan implementasi
- **Terkait:** spec induk `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§4 just-in-time knowledge + "satu sumber kebenaran banyak proyeksi", §7 model `control/`, §9 skill `fanout`/`feature`/`plan`/`ship`/`drop`/`render-docs`, §12 lifecycle, §17 komponen); spec Langkah-1 `2026-06-01-platform-invariants-security-gate-design.md` (`invariants.md` + slot, agent `security-critic`, `ship` Security Gate 4.5 berskala `sensitivity`); spec H2 `2026-06-01-h2-shared-package-design.md` (pola conductor `add-app`/`add-package` yang **ditiru** `add-integration`, `task.unit`, `packages[]`/`consumers[]` yang **TIDAK** di-overload); spec `2026-05-31-wire-skill-design.md` (`wire` generic-from-stack, mode-package §I); spec `2026-05-29-breakdown-build-execution-phase-design.md` (mesin `task`/`actions`/pseudo-unit `integration`).
- **Asal:** audit adversarial pipeline (26 agent) terhadap skenario "solo dev bikin ecommerce-builder ala Shopify full-AI". 16 gap terkonfirmasi (0 dibantah). Spec ini mengerjakan gap **M5** (vendor eksternal tak punya rumah durable) — gap Langkah-2 setelah H2 (DONE). M4/H3 = spec terpisah berikutnya.
- **Grounding:** sebelum desain, current-state diverifikasi ulang ke file nyata (bukan ringkasan handoff) lewat 9-agent read+sintesis adversarial. Empat klaim handoff terkonfirmasi: (a) tak ada entitas vendor di `control/`; (b) kontrak vendor di-derive ulang tiap fitur di `plans/_shared.md`/`plans/<app>.md`; (c) `fanout` cuma punya penanda app/package, nol kolom vendor; (d) webhook **inbound** + mode test/live tak dimodelkan. Refinement: `security-critic` (Langkah-1) **sudah** punya lensa "webhook tanpa verifikasi signature" (`security-critic.md:17`) tapi membaca `invariants.md` yang **kosong** soal webhook → mengecek aturan yang tak pernah ditulis. `intake`/`feature.yaml` **sengaja tidak diubah** (lihat §3).

---

## 1. Ringkasan

Seluruh pipeline **buta terhadap vendor eksternal** (pembayaran, email, kurir, pajak). Susuri lifecycle dengan "fitur #3 menambah pembayaran lewat sebuah payment-provider":

- **`intake`** mengumpulkan Q&A bisnis dan menandai `sensitivity:[payments]` — tapi tak pernah merekam *"ini pakai vendor X"*. Vendor terkubur di prosa outcome ("proses pembayaran").
- **`fanout`** memetakan kerja ke app/package — tapi tak punya slot untuk layanan luar. Kebutuhan pihak-ketiga merosot jadi baris bebas "Dependency lintas-app" yang tak dibaca hilir.
- **`plan`** adalah tempat kontrak vendor **di-derive ulang tiap fitur** (idempotency-key, signature webhook, mode test/live) di `plans/_shared.md`. Fitur #8 yang juga menyentuh vendor itu menderivasinya lagi dari nol. Tak ada promosi O(1)/vendor.
- **`wire`** men-scaffold `.env` generik tapi **tak ada stub webhook-receiver** dan **tak memodelkan mode test/live** (cuma satu `.env`).
- **`ship`** Security Gate (4.5) memanggil `security-critic` yang lensanya persis *"webhook masuk tanpa verifikasi — signature/origin/HMAC tak dicek"* — tapi ia me-red-team diff terhadap `invariants.md` yang **kosong** soal webhook/secret/idempotency. Jadi ia mengecek hal yang pipeline tak pernah definisikan.

**Pendekatan:** jadikan vendor eksternal **entitas kelas-satu durable** dengan meniru pola `add-app`/`add-package` yang sudah terbukti. (a) File baru `control/integrations.md` — deklarasi **SHAPE-only** per vendor (TANPA nilai secret), sejajar `conventions.md`/`invariants.md`; (b) skill baru **`add-integration`** (sibling `add-app`/`add-package`, conductor) — **satu-satunya penulis entri `integrations.md`** — di-auto-invoke `feature` saat `fanout` menandai **`VENDOR NEW`**; (c) `plan` membaca `integrations.md` → **promote kontrak vendor O(1)** ke `plans/_shared.md`/app, bukan derive ulang; (d) **varian task "inbound eksternal"** (verifikasi signature + idempotent + replay) sebagai task pada `unit:<app-penerima>`; (e) **`wire` mode-integration** — scaffold stub webhook-receiver + rekam SHAPE env; (f) silang Langkah-1: **slot invarian baru** ("Integrasi & Webhook Eksternal", dikunci `architect`) + `security-critic` membaca `integrations.md` sebagai **baseline ketiga**. Plugin tetap **generic** — Shopify hanya alat uji; field di-*elicit*, tak ada skema khusus Stripe.

## 2. Tujuan & Non-Tujuan

**Tujuan:**
- Vendor eksternal punya **representasi durable** (`control/integrations.md`) dan **entrypoint resmi** (`add-integration`), sejajar `apps[]`/`add-app` & `packages[]`/`add-package`.
- Kontrak vendor ditulis **sekali** dan dibaca **O(1) per vendor** oleh `plan`, bukan di-derive ulang tiap fitur.
- Webhook **inbound** dimodelkan eksplisit: ada **stub receiver** (`wire`) + **varian task** verifikasi signature/idempotent/replay (`breakdown`/`build`) + **test-case keamanan** baku.
- Mode **test/live** punya rumah durable (field per vendor) — secret tetap GATE/manual, tak pernah masuk `control/`/git.
- `security-critic` (Langkah-1) akhirnya punya **baseline konkret**: aturan webhook lintas-cutting terkunci di `invariants.md`, spesifik per-vendor di `integrations.md`.
- **Reuse maksimal:** tiru `add-app`/`add-package`; perluas `wire` (mode baru), `plans/_shared.md`, mesin `task` — bukan bikin mesin baru.
- **Tetap generic:** vendor di-*elicit* (`fanout` mengusulkan, `add-integration` tanya SHAPE, user menentukan); tak ada asumsi ecommerce/Stripe.

**Non-Tujuan (spec ini):**
- **Vendor fan-IN / contract-versioning.** Saat kontrak vendor berubah (mis. bump versi API vendor), TIDAK ada mesin enumerasi-consumer + retest seperti fan-IN package (H2). v1: vendor **menanggung versioning-nya sendiri**. `VENDOR TOUCHED` biasa hanya informatif (promote kontrak existing). **Beda dgn perluasan SHAPE:** kalau fitur butuh arah/SHAPE yang belum tercakup entri (mis. nambah `inbound` ke vendor `outbound`-only), itu **UPDATE deklaratif sekali** lewat `add-integration` (`VENDOR TOUCHED — perlu UPDATE`, §7.1/§7.2) — **bukan** fan-IN. Vendor fan-IN (enumerasi app yang memanggil vendor + retest saat kontrak berubah) = Langkah 3 (butuh melacak vendor-consumers — sengaja dihindari di v1, lihat §3).
- **`packages[].consumers` TIDAK di-overload jadi vendor-consumers.** "App mana mengimpor package" (H2) ≠ "app mana memanggil vendor" — relasi berbeda. v1 tak melacak vendor-consumers sama sekali (hanya pointer 1-arah opsional `Wrapped by`, §4).
- **Provisioning vendor** (bikin akun, daftar webhook di console vendor, rotasi secret). Out-of-band; `ship` cuma **mengagregasi runbook** langkah manual (§9), tak mengeksekusinya.
- **`feature.yaml vendor:[]` field.** TIDAK ditambah — `intake` tetap murni bisnis (§3); relasi fitur↔vendor hidup di `fanout.md` (penanda) + `integrations.md` (durable).
- **Skema khusus per-vendor** (OAuth-flow, rate-limit detail, payout-schedule). `integrations.md` = SHAPE minimal + signature; detail implementasi tetap di `plans/`/kode.
- **Deploy/release/env-model penuh.** Runbook `ship` (§9) hanya jembatan minimal khusus integrasi; full post-ship lifecycle ikut defer (spec struktural `2026-05-31-pipeline-hardening-structural-design.md` §S4.1).
- **`extract` brownfield integration-inference** (nebak vendor dari scan kode existing). Sub-proyek tersendiri; defer.
- **M4/H3** — gap Langkah-2 lain; spec sendiri. M5 **TIDAK** menyandar `control/schema/` (M4) maupun migration-governance (H3) — keduanya belum ada (lihat §3 + §13).

**Revisi terhadap spec induk & Langkah-1:** spec induk §7 model `control/` **tidak** memuat `integrations.md` — spec ini **menambahkannya** sebagai knowledge top-level durable ketiga (di samping `conventions.md` + `invariants.md`). Langkah-1 (`security-critic.md` lensa webhook + slot `invariants.md`) di-*lengkapi*: lensa webhook yang ada **akhirnya dapat baseline**, dan ditambah satu slot invarian baru.

## 3. Prinsip yang Dijaga

- **Tiru yang terbukti.** `add-integration` = cermin `add-app`/`add-package` (conductor: declare → bring-up, semua gated). Bedanya: **vendor tak punya stack** → `add-integration` TIDAK memanggil `architect` (tak ada keputusan lang/build-tool), hanya `wire` (stub + SHAPE env). Lebih ramping dari `add-app`/`add-package`.
- **Satu sumber kebenaran, banyak proyeksi (induk §4).** `integrations.md` adalah **SUMBER hand-authored**, BUKAN proyeksi ter-generate. Sengaja beda dari M4 (skema = proyeksi dari migrations): kontrak vendor **tak punya sumber hulu untuk diproyeksikan** (versi API/signature/idempotency-key adalah keputusan yang dideklarasi, bukan turunan kode). Aturan §4 "jangan edit proyeksi" mengikat HTML ter-generate, bukan file sumber — jadi `integrations.md` boleh hand-authored seperti `conventions.md`/`invariants.md`. *(Catat eksplisit asimetri ini: integrations = sumber; schema (M4) = proyeksi.)*
- **JIT tidak dilanggar.** `integrations.md` ada (kosong) sejak `init`, tapi **entri-nya tumbuh just-in-time** saat fitur pertama butuh vendor (lewat `add-integration`), persis seperti `apps[]`/`packages[]`. Tak ada deklarasi vendor di muka.
- **Anti-yes-man.** `fanout` meng-*challenge* sebelum menandai `VENDOR NEW`: "beneran butuh layanan luar, atau bisa in-house / sudah ada vendor yang menanggung?" — cegah vendor prematur & duplikasi.
- **Aturan lintas-cutting di-LOCK, spesifik per-vendor di-DECLARE.** Aturan "semua webhook inbound verifikasi signature; staging pakai mode test" = invarian level-produk (dikunci `architect` sekali). Algo/endpoint/mode tiap vendor = entri `integrations.md` (just-in-time). Generic tetap platform-wide; detail tetap JIT.
- **Sole-writer-per-artifact.** `add-integration` = **satu-satunya** penulis entri `integrations.md` (cermin "add-app satu-satunya penulis `apps[]`"). `fanout` hanya **menandai** (`VENDOR NEW/TOUCHED`), tak menulis `integrations.md`. `plan`/`security-critic`/`ship` **hanya membaca**. Cegah double-writer drift.
- **wire/build split dijaga.** `wire` bikin webhook endpoint **JALAN** (stub kosong, route ter-register, env ada). `build` bikin endpoint **BEKERJA** (logika verifikasi signature + idempotent + replay + test). Sama persis dengan split di seluruh pipeline.
- **Secret tak pernah durable.** `integrations.md` menyimpan **NAMA** env var, tak pernah nilainya. Nilai → `.env` (gitignored) lewat GATE/manual (aturan `wire` §D existing).

## 4. Entitas data — `control/integrations.md`

### 4.1 Bentuk file
File markdown baru `control/integrations.md`, sejajar `conventions.md`/`invariants.md` di root `control/`. **Hand-authored SHAPE** (§3). Template (di-seed `init`, §4.3):

```
# <PRODUCT> — Integrasi Vendor Eksternal

> Kontrak SHAPE tiap layanan pihak-ketiga (pembayaran, email, kurir, pajak, dst).
> TANPA nilai secret — hanya NAMA env var. Entri diisi `add-integration` saat sebuah
> fitur butuh vendor baru (dipicu `fanout` → VENDOR NEW). Dibaca `plan` (promote kontrak),
> `security-critic` (baseline), `ship` (runbook deploy).
>
> Belum ada vendor — daftar tumbuh just-in-time lewat add-integration.
```

Tiap entri vendor (ditambah `add-integration`, §5):

```
## <vendor>
Arah         : outbound | inbound | both
Dipakai      : <ringkas; mis. proses pembayaran & payout>
Endpoint     : <base URL pattern (outbound) / path webhook (inbound) — SHAPE, bukan rahasia>
Receiver app : <nama app dari apps[] yang menerima webhook — hanya bila Arah memuat inbound>
Idempotency  : <bentuk key; mis. header Idempotency-Key tiap request outbound>
Mode         : test | live (per environment)
Secret env   : <NAMA env var; mis. PAYMENTS_API_KEY, PAYMENTS_WEBHOOK_SECRET — tanpa nilai>
Retry        : <kebijakan; mis. backoff eksponensial 3x>
Signature    : <algo verifikasi inbound; mis. HMAC-SHA256 di header X-Signature>   (hanya bila Arah memuat inbound)
Wrapped by   : <package opsional; mis. money — pointer 1-arah ke H2 packages[]>     (opsional)
```

Gaya `Field : value` mengikuti konvensi `plans/<pkg>.md` (`plan` H2) yang sudah ada — markdown body, **bukan** YAML frontmatter, jadi colon-space aman (bug-guard colon-space hanya mengikat `description:` frontmatter + contoh YAML; lihat §13).

### 4.2 Semantik
- **`Arah`** menentukan task & scaffold: `outbound` (kita panggil vendor) butuh API-key shape + idempotency-key + retry; `inbound` (vendor panggil kita) butuh receiver endpoint + `Signature` + handling replay/idempotent + stub `wire`; `both` = keduanya.
- **`Signature`** hanya untuk `inbound`/`both`. Field inilah yang mengubah `security-critic` dari lensa-buta jadi cek-konkret ("`integrations.md` bilang HMAC-SHA256 → apakah diff memverifikasinya?"). Ini alasan field signature dimasukkan (vs SHAPE telanjang).
- **`Receiver app`** (hanya `inbound`/`both`) = nama app dari `apps[]` yang menerima webhook. **Disimpan durable di sini** supaya `plan` (sesi terpisah, read-only) tahu `plans/<app>.md` mana yang dapat task receiver (§7.3) **tanpa menebak ulang** — `add-integration` menanyakannya saat declare (§5 step 2). Nama app = topologi, bukan secret.
- **`Secret env`** = NAMA env var saja (mis. `PAYMENTS_WEBHOOK_SECRET`). Nilai tak pernah di sini (§3). `wire` merekam SHAPE ini ke `conventions.md`; nilai diisi `.env` via GATE/manual.
- **`Mode test|live`** = kontrak durable mode. `security-critic` memakainya untuk asersi "staging pakai secret mode test". Pemilihan nilai mode = concern env (`wire`/`build`), bukan di `control/`. **Jujur soal scope:** v1 **tidak** meng-*enforce* pemilihan secret per-mode otomatis saat deploy — itu langkah manual di runbook `ship` (§9.1). `integrations.md` cuma **kontrak durable + baseline asersi** `security-critic`, bukan enforcer runtime.
- **`Wrapped by`** = pointer 1-arah OPSIONAL ke sebuah package H2 (mis. vendor pembayaran dibungkus package `payments`). **TIDAK** pakai `packages[].consumers` (relasi beda — §2; handoff §3 menandai overload ini sebagai jebakan H3). v1 tak melacak "app mana memanggil vendor".
- **Tak ada di `workspace.yaml`.** Vendor hidup di file markdown sendiri (`integrations.md`), bukan stanza `workspace.yaml`. Alasan: vendor adalah kontrak SHAPE prosa (signature/idempotency/retry deskriptif), bukan struktur topologi seperti `apps[]`/`packages[]`; menaruhnya di markdown sejajar `conventions.md`/`invariants.md` lebih jujur ke isinya & menghindari beban skema YAML.

### 4.3 Inisialisasi
`integrations.md` adalah **file template** baru `plugin/template/control/integrations.md`. `init` langkah 4 sudah `cp -R` seluruh `template/control/` + replace placeholder `<PRODUCT>`; cukup **tambahkan `integrations.md` ke daftar file yang di-`<PRODUCT>`-replace** (kini "semua `business/*.md`, `conventions.md`, dan `invariants.md`"). Hasilnya: tiap produk baru punya `control/integrations.md` kosong (header saja) — pembaca hilir mengasumsikan file ADA, "kosong = belum ada vendor". Tak ada nilai mengandung pola yang merusak sed (`<PRODUCT>`-replace adalah string-replace polos).

## 5. Skill baru — `add-integration` (conductor, cermin `add-app`/`add-package`)

File baru `plugin/skills/add-integration/SKILL.md` (**tanpa** `reference.md` — thin conductor seperti `add-package`). **Satu-satunya penulis entri `integrations.md` pasca-init.** Spine meniru `add-package`, tapi **tanpa langkah `architect`** (vendor tak punya stack):

```
add-integration <vendor>
  0  Prasyarat : baca control/integrations.md + control/workspace.yaml (apps[]) +
                 control/invariants.md. Backstop invarian (sama add-app/add-package/wire):
                 kalau slot "Integrasi & Webhook Eksternal" di invariants.md masih
                 <belum dikunci> → STOP, arahkan ke architect "Kunci Invarian" dulu
                 (bukan deadlock — sekadar arah-ulang). Normalnya invarian sudah terkunci
                 sebelum fitur pertama, jadi cek ini jarang menyala.
  1  Idempotent: kalau <vendor> sudah ada di integrations.md → ini UPDATE (boleh perluas
                 SHAPE, mis. tambah arah inbound ke vendor outbound-only) atau STOP bila tak
                 ada perubahan.
  2  Q&A SHAPE  : Arah (outbound/inbound/both), Dipakai, Endpoint (SHAPE), Idempotency,
                 Mode (test/live), Secret env (NAMA var), Retry, Signature (bila inbound).
                 Bila inbound → tanya juga "app mana yang menerima webhook?" → isi field
                 Receiver app (dari apps[] existing; app pasti sudah ada karena loop add-app
                 jalan lebih dulu, §7.2). Field Receiver app DURABLE supaya plan (sesi lain)
                 tak perlu menebak (§4.2).
  3  GATE       : tulis entri ke integrations.md (diff → approve). Tetap SHAPE-only (validasi:
                 tak ada nilai yang terlihat seperti secret asli; cuma NAMA env var).
  4  Rekam SHAPE env (NAMA var) ke conventions.md lewat pola env wire (wire/reference.md §D)
                 — SELALU (outbound & inbound; satu mekanisme yang sama, bukan dua penulis).
                 LALU, HANYA bila Arah memuat inbound: invoke wire (MODE-INTEGRATION, §6)
                 untuk scaffold stub webhook-receiver di Receiver app → GATE = app tetap boot +
                 route ter-register + typecheck. Outbound-only berhenti di perekaman SHAPE env
                 (tak ada receiver untuk di-scaffold).
  5  Close      : kembali ke feature (kalau dipanggil feature) untuk lanjut plan; else sarankan
                 langkah berikut (feature <nama-fitur>).
```

- **TIDAK memanggil `architect`** (beda dari `add-app`/`add-package`) — vendor tak punya keputusan stack. Dicatat eksplisit di SKILL.md.
- **`add-integration` satu-satunya penulis entri `integrations.md`** pasca-init. `fanout`/`plan`/`security-critic`/`ship`/`render-docs` hanya membaca.
- **Bisa dipanggil manual** (`/add-integration <vendor>`) atau **auto oleh `feature`** (§7.2).
- **Frontmatter `description:` WAJIB colon-space-free** (bug-guard §13).

## 6. `wire` — mode-integration

> Catatan notasi: semua referensi `§`-huruf di section ini (§D, §H, §I, §J) menunjuk **`plugin/skills/wire/reference.md`**, bukan section M5 (yang bernomor §1–§14). §D/§H/§I sudah ADA; §J **ditambah** M5.

`wire` sudah generic-from-stack + punya mode-package (§I). Tambah **§J mode-integration** (section BARU di `wire/reference.md`; subset bring-up, dipanggil `add-integration` step 4, hanya untuk vendor inbound):

- **Yang DIKERJAKAN:** scaffold **stub** route webhook-receiver di app penerima (route ter-register di framework app, handler mengembalikan placeholder mis. 200/501 — BELUM ada logika verifikasi) + rekam SHAPE env (NAMA var, mis. `<VENDOR>_WEBHOOK_SECRET`) ke `conventions.md` (pola §D existing).
- **Gate penutup mode-integration** = app tetap boot + route ter-register + typecheck/lint hijau. (Tak ada smoke HTTP penuh; logika nyata = `build`.)
- **Yang DI-SKIP:** verifikasi signature, idempotent/replay, test keamanan — itu **task `build`** (§7.4). Secret = tetap GATE/manual (§D); JANGAN masuk `control/`/git.
- Reuse scaffolder & mesin env `build` yang sama (§H existing); tak ada duplikasi.
- **Outbound-only** tak menyentuh mode-integration (tak ada receiver) — `add-integration` cukup merekam SHAPE env.

## 7. Seam fan-OUT (mendeklarasi & memakai vendor)

### 7.1 `fanout` — deteksi `VENDOR NEW` / `VENDOR TOUCHED`
- Baca `control/integrations.md` (tambahan dari kini membaca `workspace.yaml`).
- Saat memetakan peran fitur: kalau ada kebutuhan **layanan pihak-ketiga** (pembayaran/email/kurir/pajak/dst) → **challenge anti-yes-man** ("beneran butuh vendor luar, atau in-house / sudah ada vendor existing?"). Lolos, bandingkan kebutuhan fitur (arah: kita panggil vendor? vendor panggil kita?) dengan `integrations.md`:
  - vendor **belum ada** di `integrations.md` → tandai **`VENDOR NEW: <vendor>`** (simetris `APP NEW`/`PACKAGE NEW`); diwujudkan `add-integration` (dipanggil otomatis `feature`).
  - vendor **sudah ada & `Arah`-nya sudah mencakup** yang dibutuhkan fitur → tandai **`VENDOR TOUCHED: <vendor>`** (informatif — `plan` promote kontrak existing; **tak ada fan-IN**, §2).
  - vendor **sudah ada TAPI `Arah`/SHAPE belum mencakup** kebutuhan fitur (mis. entri `outbound`-only, fitur butuh webhook `inbound`) → tandai **`VENDOR TOUCHED — perlu UPDATE: <vendor> (butuh <arah>)`**; `feature` invoke `add-integration` mode UPDATE (§5 step 1) untuk memperluas SHAPE sekali. (Ini **bukan** fan-IN/versioning yang ditunda §2 — perluasan SHAPE deklaratif lewat sole-writer yang sama.)
- Seperti `APP NEW`/`PACKAGE NEW`, entri **tidak** ditulis ke `integrations.md` di sini — itu jatah `add-integration`. `fanout` cuma **menandai** (bukan penulis `integrations.md`).

### 7.2 `feature` — auto-invoke `add-integration`
Urutan `feature` step 2 (kini: intake → fanout → [add-app per `APP NEW`] → [add-package per `PACKAGE NEW`] → plan) disisipi loop ketiga: setelah loop `add-package`, tambah loop **`add-integration`** — untuk tiap `VENDOR NEW` **dan tiap `VENDOR TOUCHED — perlu UPDATE`** di `fanout.md`, invoke `add-integration <vendor>` (CREATE untuk NEW, UPDATE untuk perlu-UPDATE; declare → wire mode-integration bila inbound, gated) → tunggu beres → baru lanjut `plan`. **Plain `VENDOR TOUCHED`** (tanpa perlu-UPDATE) TIDAK di-loop — cukup `plan` promote kontrak existing. Urutan: **add-app → add-package → add-integration → plan** (app & package ada lebih dulu agar `add-integration` bisa menunjuk `Receiver app` webhook). Cermin persis seam `APP NEW`→`add-app`.

### 7.3 `plan` — promote kontrak vendor (O(1))
- Baca `control/integrations.md` (read-only) selain input sekarang.
- Untuk tiap vendor yang kena fitur (`VENDOR NEW`/`VENDOR TOUCHED`/`…perlu UPDATE`) → **promote** kontrak vendor (dari `integrations.md`) ke `plans/_shared.md` (kontrak lintas-app non-package yang sudah ada) — **referensikan**, bukan derive ulang. **Idempotent:** sebelum nulis, cek apakah kontrak vendor itu sudah ada di `_shared.md` (mis. fitur lebih awal sudah promote) → kalau ada, reuse/referensikan, **jangan tulis ulang** (disiplin reconcile `_shared.md` yang sama seperti H2). Mis. "Pembayaran via `<vendor>` — outbound dgn Idempotency-Key per request; inbound webhook di `<Receiver app>` path `<...>`, verifikasi `<Signature>`."
- Untuk vendor **inbound**/**both** → ambil **`Receiver app`** dari entri `integrations.md` (field durable §4.1) → tulis di `plans/<Receiver app>.md` satu baris **kebutuhan receiver**: "Webhook masuk `<vendor>` di `<path>`: verifikasi signature (`<algo>`), idempotent (dedup), tahan replay." → basis varian task `breakdown` (§7.4). (`plan` jalan **sesi terpisah & read-only** → `Receiver app` HARUS dari `integrations.md`, bukan ditebak ulang.)
- **Challenge teknis tambahan** (di samping challenge invarian/mandatory-package Langkah-1/H2): "Fitur ini menyentuh vendor tapi kontraknya tak ada di `integrations.md`?" → arahkan jalankan `add-integration` (jaring kalau seam `fanout` terlewat).

### 7.4 `breakdown` — varian task "inbound eksternal"
- **Tanpa field skema baru.** Webhook receiver hidup di app NYATA (punya route/handler/test) → task biasa pada **`unit:<app-penerima>`** (bukan pseudo-unit `integration`; itu tetap khusus roundtrip internal — handoff melarang overload konsep). Gate validasi `task.unit` (H2) tetap: app/package/`integration` — tak berubah.
- Saat `plans/<app>.md` memuat kebutuhan receiver (§7.3), `breakdown` menerbitkan task `unit:<app>` dengan **pola varian inbound-eksternal**:
  - `approach` — "terima webhook `<vendor>`: verifikasi signature per `integrations.md`, idempotent (dedup key), tahan replay."
  - `actions` — boleh `env:[<VENDOR>_WEBHOOK_SECRET]` (NAMA var; `build` tulis ke `.env`, nilai GATE/manual).
  - `test` (test-case keamanan **baku**) — `signature salah → tolak (401/403)`; `id/event duplikat → respons sama, tak proses 2×` (idempotent/replay).
- Vendor **outbound** = task biasa pada app pemanggil (panggil API vendor + idempotency-key + retry sesuai `integrations.md`); tak butuh varian khusus, cukup `approach`/`test` mengacu kontrak.

### 7.5 `build` — eksekusi
- Task inbound-eksternal = jalankan seperti task app biasa (kode app + test) pada `path` app; stub route sudah ada dari `wire` mode-integration (§6) → `build` mengisi logika verifikasi/idempotent + test keamanan. Tak ada infra khusus.
- Mesin `actions`/`env`/gate yang ada dipakai apa adanya; secret tetap GATE/manual.

## 8. Keamanan — baseline untuk `security-critic`

### 8.1 Slot invarian baru (dikunci `architect`)
- Tambah slot **`## Integrasi & Webhook Eksternal`** ke `plugin/template/control/invariants.md` (sentinel `<belum dikunci>` — sama seperti 6 slot lain; **tak ada sentinel baru**, bug-guard §13). Aturan lintas-cutting yang dikunci: mis. "semua webhook inbound WAJIB verifikasi signature; staging selalu mode test; idempotent terhadap replay."
- `architect` langkah 4.5 (Kunci Invarian) sudah iterasi semua slot `<belum dikunci>` secara generik → slot baru ter-elicit otomatis. Cukup **tambahkan frasa "integrasi/webhook eksternal"** ke daftar contoh di kalimat pembuka 4.5 ("model tenancy, representasi uang, idempotency, authz, PII/PCI, rate-limit") supaya `architect` menyodorkannya. **Tanpa renumber** (4.5 tetap 4.5; cuma nambah slot di template + frasa contoh).

### 8.2 `security-critic` — input ketiga
- Tambah `control/integrations.md` ke input agent (kini: diff + `invariants.md` + `conventions.md`).
- Lensa webhook existing (`security-critic.md:17`) di-*ground* ke baseline: "vendor `<X>` di `integrations.md` ber-`Signature: HMAC-SHA256` — apakah diff memverifikasinya (timing-safe)?"; "vendor `<X>` `Mode: test` di staging — apakah kode merutekan secret mode-test, bukan live?"; "idempotency-key shape sesuai kontrak?".
- **Frontmatter `description:` `security-critic.md` WAJIB tetap colon-space-free** saat diedit (bug-guard §13).

### 8.3 `ship` Security Gate 4.5 — feed baseline
- Step 4.5 (invoke `security-critic` untuk `sensitivity` payments/pii) menambahkan `control/integrations.md` ke input yang diberikan ke agent (kini cuma `invariants.md`). Tanpa renumber (tetap di desimal 4.5).

## 9. Hygiene skills

### 9.1 `ship` — runbook integrasi (deploy)
Di step 6 (susun deskripsi PR), tambahkan **seksi "Integrasi & langkah manual"** yang mengagregasi, per vendor yang kena fitur (dari `fanout.md`/`integrations.md`) + langkah `manual:` di `tasks.yaml`:
- URL webhook yang perlu didaftarkan di console vendor (dari `Endpoint`/path receiver),
- env secret yang perlu di-set (NAMA var dari `Secret env`),
- switch mode test→live.
Ini menutup gap "hasil langkah manual tak mendarat" — masuk ke deskripsi PR sebagai runbook, melengkapi challenge step 4 ("langkah `manual:` belum beres?"). **Scoped ke integrasi** (full release-runbook = Langkah 3).

### 9.2 `render-docs` — kartu integrasi
Baca `control/integrations.md`; render **kartu integrasi** di HTML (vendor, Arah, Dipakai, Mode) — SHAPE-only, **tanpa secret**. Dibedakan dari kartu app/package. (Tanpa ini, doc integration-blind.)

### 9.3 `drop` — pengingat provenance
Saat `drop` sebuah fitur, bila fitur itu memperkenalkan vendor (cek `fanout.md` fitur) → **pengingat lunak** ke user: "fitur ini memperkenalkan `<vendor>`; tinjau apakah entri `integrations.md` masih dipakai fitur lain sebelum dibersihkan." **Tanpa mesin keras** (v1 tak melacak vendor-consumers presisi, §2) — sekadar provenance reminder. Drop entri `integrations.md` = aksi manual user.

### 9.4 `conventions.md`
SHAPE env vendor (NAMA var) ditulis ke `conventions.md` lewat pola env `wire` (`wire/reference.md` §D), dipanggil dari `add-integration` step 4 (§5) — satu mekanisme yang sama untuk outbound & inbound. Boleh siapkan heading "Konvensi Integrasi" di template `plugin/template/control/conventions.md` (opsional; diisi saat `add-integration`/`wire` jalan).

## 10. Permukaan Integrasi (peta edit file)

| File | Perubahan |
|---|---|
| `plugin/template/control/integrations.md` | **BARU** — template SHAPE kosong (§4.1) |
| `plugin/skills/init/SKILL.md` | Tambah `integrations.md` ke daftar file yang di-`<PRODUCT>`-replace di langkah 4 (§4.3) |
| `plugin/skills/add-integration/SKILL.md` | **BARU** — conductor §5 (tanpa `reference.md`) |
| `plugin/skills/wire/reference.md` | §J mode-integration: stub receiver + SHAPE env, gate boot+route+typecheck (§6) |
| `plugin/skills/wire/SKILL.md` | Deteksi mode-integration (dipanggil `add-integration`); baca `integrations.md` saat relevan |
| `plugin/skills/fanout/SKILL.md` | Baca `integrations.md`; challenge + tandai `VENDOR NEW`/`VENDOR TOUCHED`/`VENDOR TOUCHED — perlu UPDATE` (§7.1); tambah baris challenge checklist + marker di template output langkah 4 |
| `plugin/skills/feature/SKILL.md` | Loop auto-invoke `add-integration` per `VENDOR NEW` + `VENDOR TOUCHED — perlu UPDATE`, setelah loop `add-package`, sebelum `plan` (§7.2) |
| `plugin/skills/plan/SKILL.md` | Baca `integrations.md`; promote kontrak vendor ke `_shared.md`/app O(1); baris kebutuhan receiver di `plans/<app>.md`; 1 challenge "vendor tanpa kontrak" (§7.3) |
| `plugin/skills/breakdown/SKILL.md` (+ `reference.md`) | Varian task inbound-eksternal pada `unit:<app>` + test-case keamanan baku; vendor outbound = task app biasa (§7.4). Tanpa field skema baru |
| `plugin/skills/build/SKILL.md` | (Minimal) catat: task inbound-eksternal = task app biasa di atas stub `wire`; env secret GATE/manual (§7.5) |
| `plugin/template/control/invariants.md` | Slot baru `## Integrasi & Webhook Eksternal` + `<belum dikunci>` (§8.1) |
| `plugin/skills/architect/SKILL.md` | Tambah frasa "integrasi/webhook eksternal" ke daftar contoh kalimat pembuka langkah 4.5 (§8.1). Tanpa renumber |
| `plugin/agents/security-critic.md` | Tambah `control/integrations.md` ke input + ground lensa webhook (signature/mode); jaga `description:` colon-space-free (§8.2) |
| `plugin/skills/ship/SKILL.md` | Step 4.5 feed `integrations.md` ke `security-critic` (§8.3); step 6 seksi runbook integrasi (§9.1) |
| `plugin/skills/render-docs/SKILL.md` (+ template) | Kartu integrasi di HTML (§9.2) |
| `plugin/skills/drop/SKILL.md` | Pengingat provenance vendor saat drop fitur (§9.3) |
| `plugin/template/control/conventions.md` | (Opsional) heading "Konvensi Integrasi" (§9.4) |

## 11. Amandemen Spec

### 11.1 Spec induk (`2026-05-24-ai-first-boilerplate-design.md`)
- **§7 model `control/`:** tambah `integrations.md` sebagai knowledge top-level durable (di samping `conventions.md` + `invariants.md`).
- **§9 Skill (subsection yang ADA di parent):** `fanout` (tandai `VENDOR NEW/TOUCHED`), `feature` (loop auto-invoke `add-integration`), `plan` (promote kontrak vendor), `ship` (feed baseline + runbook integrasi), `drop` (pengingat provenance), `render-docs` (kartu integrasi). **Catatan:** `breakdown`/`build`/`wire`/`add-integration`/`security-critic` **tak punya** subsection §9 di parent (didokumentasi di spec masing-masing) → perilaku M5-nya dicatat di spec INI, bukan amandemen §9 (sama seperti H2 §12.1).
- **Cabang lifecycle (§12, note "Cabang dipicu"):** tambah **cabang sibling** — fitur butuh vendor eksternal → `feature` auto-invoke `add-integration` saat `VENDOR NEW`. Diagram lifecycle tambah cabang `add-integration` sejajar `add-app`/`add-package`.
- **§17 Komponen:** jumlah skill **16 → 17** (tambah `add-integration`); catat `integrations.md` di model `control/`; sebut `wire` mode-integration + slot invarian "Integrasi & Webhook Eksternal".

### 11.2 Spec Langkah-1 (`2026-06-01-platform-invariants-security-gate-design.md`)
- Lensa webhook `security-critic` (Langkah-1) yang selama ini membaca `invariants.md` **kosong soal webhook** → **dilengkapi** spec ini: M5 **menambah** slot invarian `Integrasi & Webhook Eksternal` (§8.1) + memberi `security-critic` `integrations.md` sebagai **input ketiga** (§8.2). Lensa yang sudah ada akhirnya punya baseline konkret.

## 12. Staging untuk Plan (eksekusi bertahap — di level *plan*)

Desain utuh di spec ini, tapi `writing-plans` boleh memecah eksekusi/merge:
- **Stage 1 — deklarasi & promote (mergeable sendiri):** template `integrations.md` (init) · `add-integration` · `fanout` `VENDOR NEW/TOUCHED` · `feature` auto-invoke · `plan` promote · `render-docs` kartu · `drop` reminder · `conventions` heading. → vendor bisa **dideklarasi, dipromote, didokumentasikan**.
- **Stage 2 — inbound & keamanan:** `wire` mode-integration (stub) · `breakdown` varian task inbound-eksternal + test-case · `build` · slot invarian (`invariants.md` + `architect` 4.5) · `security-critic` baseline · `ship` 4.5 feed + runbook. → webhook inbound **ter-scaffold, ter-build, ter-red-team**.

## 13. Rencana Verifikasi

Eksekusi via `writing-plans` → `executing-plans` (biasanya sesi terpisah). Setelah implement:
1. **YAML-lint / frontmatter + colon-space guard:** tiap skill diedit valid; **`description:` value (semua skill baru/diedit, termasuk `add-integration` + `security-critic`) tak mengandung `": "`** — `sed -n 's/^description: //p' FILE | grep ': '` harus kosong (bug berulang 4×).
2. **Grep-battery konsistensi:** `integrations.md`/`add-integration`/`VENDOR NEW`/`VENDOR TOUCHED`/`perlu UPDATE`/`mode-integration`/`inbound`/`Signature`/`Receiver app` muncul konsisten lintas file yang diklaim §10.
3. **Coherence guard (CRITICAL):** **tak ada** pointer ke artifact Langkah-2 yang **belum ada** — `control/schema/` (M4), migration-governance/`data-model.md` (H3). M5 hanya menyandar primitif yang ADA (`apps[]`, `packages[]`, `plans/_shared.md`, `invariants.md`, `conventions.md`) + yang M5 bikin (`integrations.md`). **`packages[].consumers` TIDAK di-overload** jadi vendor-consumers (cek tiap penyebutan consumers tetap bermakna "app impor package").
4. **Sole-writer guard:** verifikasi **hanya `add-integration`** yang menulis entri `integrations.md`; `fanout`/`plan`/`security-critic`/`ship`/`render-docs` hanya membaca (grep "tulis/write integrations.md" → cuma add-integration).
5. **Renumber-cross-ref check (WAJIB):** `feature` (sisip loop), `fanout` (sisip bullet), `architect` 4.5 (cuma nambah frasa — JANGAN renumber), `ship` (cuma perluas 4.5/step 6 — JANGAN renumber, jaga cross-ref "lanjut Step 6"). Tiap "step N"/"langkah N" masih menunjuk target benar (bug `5520de5` lolos 2×).
6. **Mis-aimed pointer check:** tiap "§X"/"reference Y"/"(lihat …)" di skill DAN spec menunjuk section yang benar-benar memuat kontennya (lolos verify-eksekusi 5-6×; bug pernah di SPEC). Khusus: pointer `wire` "§J", `breakdown` varian, `integrations.md` SHAPE.
7. **Literal-scan sentinel:** `integrations.md` **tidak** memperkenalkan sentinel baru yang di-scan skill; slot invarian baru pakai `<belum dikunci>` yang SUDAH ada (bukan token baru). Pastikan tak ada token penanda baru muncul di prosa instruksi skill.
8. **Generic guard:** field/contoh `integrations.md` + `add-integration` + slot invarian **vendor-agnostic** (tak ada `stripe`/`sk_test_` hardcoded sebagai skema; boleh sebagai *contoh* berlabel jelas). Plugin bukan ecommerce.
9. **Dry-run skenario:** (a) `fanout` deteksi kebutuhan layanan luar → `VENDOR NEW` + challenge; `feature` auto-invoke `add-integration`; (a2) vendor existing tapi `Arah` belum mencakup (outbound-only, fitur butuh inbound) → `fanout` tandai `VENDOR TOUCHED — perlu UPDATE` → `feature` invoke `add-integration` UPDATE → SHAPE diperluas + stub inbound ter-scaffold; (b) `add-integration` outbound-only → rekam SHAPE env, lewati wire; inbound → tulis entri (termasuk `Receiver app`) + `wire` mode-integration stub; (c) `add-integration` idempotent (vendor sudah ada & tak berubah → STOP); (d) plain `VENDOR TOUCHED` → `plan` promote kontrak existing tanpa derive ulang (idempotent vs `_shared.md`); (e) fitur inbound → `plan` ambil `Receiver app` dari `integrations.md` → `breakdown` terbitkan task `unit:<Receiver app>` varian inbound-eksternal + test signature-salah/duplikat; (f) `build` isi logika di atas stub; (g) `security-critic` baca `integrations.md` → flag webhook tanpa verifikasi signature; (h) `architect` 4.5 elicit slot "Integrasi & Webhook Eksternal"; (i) `ship` runbook agregasi webhook-URL + secret-NAMA + test→live; (j) `drop` fitur ber-vendor → pengingat provenance.
10. **1 ronde baca-adversarial di SESI TERPISAH** (seam/pointer/rename/design-hole/staleness parent+Langkah-1) — pelajaran berulang: verify sesi-eksekusi sendiri melewatkan kelas-bug ini (mis-aimed pointer + staleness, kadang di SPEC).

## 14. Out of Scope → sisa Langkah 2 (pointer)

Gap Langkah-2 berikutnya (spec sendiri, urutan dari audit): **M4** (`control/schema/<app>.md` sebagai **proyeksi ter-generate dari migrations** — beda paradigma dari `integrations.md` yang hand-authored; M4 memberi basis "consumer skema" untuk H3), lalu **H3** (impact-analysis migrasi lintas-fitur + `migrate.kind/affects` — re-anchor basis consumer ke **M4** `control/schema/`, **BUKAN** `packages[].consumers` H2 maupun `integrations.md` M5). **Future M5 sendiri (Langkah 3):** vendor fan-IN / contract-versioning (enumerasi app yang memanggil vendor + retest saat kontrak vendor berubah — butuh melacak vendor-consumers), provisioning otomatis, full deploy/release runbook, `extract` brownfield integration-inference.
