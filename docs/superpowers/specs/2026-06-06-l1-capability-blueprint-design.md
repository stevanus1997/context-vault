# L1 — Capability Blueprint (declare semua app target sekaligus saat init, opsional)

> Langkah-3, gap **L1** (LOW) — fix-light. Tanggal: **2026-06-06**. Repo `~/Developer/ai-boilerplate`, base `main`.
> Brainstorming diganti section **Decisions** (b) di bawah — tiap fork desain didokumentasikan plain-language agar user bisa veto sebelum plan.

## 1. Ringkasan

`init` Langkah 3 (Framing Q&A) sudah menanya **"App apa saja yang sudah kebayang?"** dan sudah menutupnya dengan **"Boleh mulai dari satu, tambah app lain nanti lewat skill `add-app`."** (baris 32). Skema `workspace.yaml` `apps[]` sudah **multi-entri** (list `- name:`, baris 45-52) — init secara teknis sudah bisa men-seed >1 app. Yang **hilang** adalah *dorongan eksplisit* bagi user produk-besar untuk men-declare **semua app target di awal** sebagai blueprint, ketimbang menemukannya satu per satu lewat `add-app` belakangan.

L1 = **memperkaya prompt yang SUDAH ADA** di baris 32 dengan satu klausa OPSIONAL/kondisional: *"produk besar & app target sudah jelas → boleh declare semua app target sekarang sebagai blueprint"*. Tidak ada langkah baru, tidak ada section baru, tidak ada field skema baru. Surface utama: `plugin/skills/init/SKILL.md` Langkah 3 + Langkah 5 (satu komentar marker). Skema `apps[]` cukup di-seed lebih dari satu entri (struktur tak berubah). **Plus** satu baris di `plugin/skills/ask/SKILL.md` agar pembaca `apps[]` yang read-only melaporkan app blueprint apa adanya ("declared, belum di-bring-up") — lihat §5a-bis (alasan: marker harus benar-benar *dibaca* oleh reader, bukan diandaikan; lihat §3 D4 yang DIREVISI).

> **Catatan jujur (advisory, opsional, 1 jalur).** L1 **bukan gate**, **bukan field baru**, **bukan skill baru**. Ia prompt advisory di **jalur init langsung**. Via `discovery` (yang men-skip Framing Q&A init, baris 27/33), L1 **tidak dieksekusi** — tapi itu OK karena app target di jalur itu sudah berasal dari konsep tervalidasi riset discovery. **Declare ≠ scaffold:** men-declare app di `apps[]` hanya menulis entri YAML (dengan `stack: {}`); bring-up (architect SETUP + wire) tetap **just-in-time** per app saat app itu betul-betul digarap. L1 **tidak** menjadwalkan kerja berat hilir sekaligus. **Marker, bukan flag baru:** app blueprint dibedakan dari app riil bukan oleh skema baru tapi oleh **penanda yang dibaca**: (i) nilai `responsibility` membawa frasa `(blueprint — belum di-bring-up)`, dan (ii) komentar inline `# blueprint, belum di-bring-up` di entri `apps[]`. Penanda ini ditambah karena `stack: {}` saja **TIDAK** terbedakan oleh pembaca `apps[]` riil (`ask`/`design-system`/`fanout` membaca `type`/`responsibility`, bukan kekosongan `stack`) — lihat §3 D4. Skill tetap **21**; rules tetap **5**; tak ada churn `plugin.json`/`marketplace.json`/README.

## 2. Masalah & konteks (a)

### 2a. Masalah

`init` baris 32 hari ini condong ke **"mulai dari satu"**: *"Boleh mulai dari satu, tambah app lain nanti lewat skill `add-app`."* Ini frame yang tepat untuk produk kecil/belum-jelas. Tapi untuk **produk besar yang topologinya sudah jelas sejak awal** (mis. operator sudah tahu produk butuh storefront + admin-dashboard + payment-service + worker), pola "mulai satu lalu `add-app` empat kali" punya gesekan:

- **Blueprint topologi tidak terekam di System Map sejak awal.** `workspace.yaml` `apps[]` baru terisi satu; sisanya implisit di kepala operator. Tak ada satu tempat yang menyatakan "ini peta app target produk".
- **`add-app` adalah jalur transaksional, bukan deklaratif.** `add-app` per desain meng-chain `architect` lalu `wire` (skeleton kosong-tapi-jalan) tiap kali (add-app/SKILL.md baris 8/52-56). Untuk app yang belum mau di-bring-up sekarang, tidak ada jalur ringan "cuma declare niat-nya dulu".
- **Hilang sinyal scope ke skill hilir.** `fanout` mencocokkan kebutuhan fitur ke `responsibility`/`capabilities` app yang **terdaftar** (fanout/SKILL.md baris 16). App yang belum di-declare tak bisa jadi target fan-out → cenderung memicu cabang `add-app` mendadak saat fitur, padahal topologinya sudah diketahui dari awal.

### 2b. Trigger konkret (ilustrasi Shopify-builder; desain tetap generik)

Operator solo-dev full-AI bikin "produk besar": platform jualan multi-permukaan. Sejak hari pertama dia sudah tahu petanya: **storefront (fe)**, **admin-dashboard (fe)**, **order-api (be)**, **payment-worker (be)**. Dengan init hari ini, dia declare `storefront` saja, lalu nanti `add-app admin-dashboard`, `add-app order-api`, `add-app payment-worker` satu per satu — tiap kali memicu architect+wire. Niat topologi penuh tak pernah terekam sebagai blueprint; fanout fitur pertama yang menyentuh order-api harus menunggu cabang `add-app`.

Dengan L1: di Langkah 3 init, init **menawarkan** "produk ini terdengar besar & app target sudah jelas — mau declare semua sekarang sebagai blueprint?". Operator declare keempat app → `apps[]` ter-seed 4 entri (`stack: {}` semua, `responsibility` ditandai `(blueprint — belum di-bring-up)`, komentar marker per entri). Bring-up tetap per app: `architect`/`wire` jalan saat tiap app betul-betul digarap (saat itu marker dilepas dari `responsibility`). Blueprint topologi sekarang hidup di System Map sejak awal, **dan terbaca apa adanya** oleh `ask`/`design-system`/`fanout`.

> Ini ilustrasi. Desain **generik**: tak ada apa pun ecommerce-specific. Konsep yang digenerikkan = "produk besar dengan topologi app yang sudah jelas sejak bootstrap".

## 3. Decisions (b) — tiap fork desain + alternatif yang ditolak

> Section ini **mengganti** brainstorming 1-1. Tiap keputusan yang penulis ambil sendiri ditulis plain-language agar user bisa veto sebelum plan.

### D1 — Perkaya prompt yang ADA, bukan langkah/section baru
**Keputusan:** L1 = satu klausa/sub-bullet OPSIONAL di **bawah baris 32** (Langkah 3 init), pada bullet yang sudah membahas "declare app".
**Alternatif ditolak:**
- *(A) Langkah init baru "Capability Blueprint".* Ditolak — over-engineering untuk LOW; init sudah punya surface yang tepat (baris 32). Langkah baru = renumber + scope balloon.
- *(B) Prompt terpisah di luar bullet baris 32.* Ditolak — akan **kontradiksi** dengan kalimat "boleh mulai dari satu" di baris yang sama (lihat R1, §7). Menempel di bullet yang sama menjaga dua-jalan tetap koheren.

### D2 — OPSIONAL & dikondisikan "produk besar", bukan default
**Keputusan:** L1 dibingkai sebagai **opsi kondisional**: "produk besar & app target sudah jelas → boleh declare semua; produk kecil/belum jelas → mulai satu, sisanya lewat `add-app`". Dua jalan tetap setara-valid.
**Alternatif ditolak:**
- *(A) Selalu tanya "sebutkan SEMUA app target sekarang".* Ditolak — memicu **over-declare** pada produk kecil: user bikin 5 entri `stack:{}` yang lalu memaksa architect SETUP 5x + wire 5 skeleton nganggur (R1/R2, §7). Melanggar prinsip induk sec.4 "just-in-time".
- *(B) Auto-deteksi "produk besar" dari heuristik.* Ditolak — tak ada sinyal andal di init untuk menebak "besar"; menambah logika tebakan = scope balloon. Cukup tawarkan kondisi ke user, biar **user yang menilai** produknya besar/jelas.

### D3 — Declare = entri YAML saja; bring-up tetap just-in-time
**Keputusan:** L1 hanya men-seed `apps[]` dengan entri ber-`stack: {}` (dan `capabilities: []`), `responsibility` ber-marker `(blueprint — belum di-bring-up)`, plus komentar inline `# blueprint, belum di-bring-up`. **Tidak** memicu architect/wire untuk app yang baru di-declare. Bring-up tetap per app saat app itu digarap (architect 3a + wire), persis seperti app pertama; saat bring-up, marker `(blueprint — belum di-bring-up)` di `responsibility` dilepas.
**Alternatif ditolak:**
- *(A) Declare semua + langsung wire semua jadi skeleton.* Ditolak keras — itu menjadwalkan kerja berat hilir (architect 3a per app + wire per app) sekaligus, untuk app yang mungkin belum dibutuhkan berbulan-bulan. Melanggar just-in-time (sec.4) dan menghasilkan skeleton nganggur. **L1 = declare INTENT/blueprint, bukan scaffold.**

### D4 — Skema `workspace.yaml` `apps[]` tidak diubah, TAPI app blueprint WAJIB bawa penanda yang dibaca (DIREVISI)
**Keputusan:** Tidak ada **field** baru. `apps[]` sudah list multi-entri (init baris 45-52, parent sec.7.1 baris 100-115). Tetapi app yang di-declare-tapi-belum-di-bring-up **TIDAK** terbedakan secara alami oleh `stack: {}` kosong — karena pembaca `apps[]` riil tidak meng-key pada kekosongan `stack`:
- **`ask/SKILL.md` baris 22** me-route pertanyaan arsitektur ("app/package, tanggung jawab, stack, capability, topology") langsung ke `workspace.yaml`. Tanpa penanda, `ask "app apa aja di produk ini"` melaporkan SEMUA entri blueprint sebagai app riil — `ask` read-only & langsung dibaca user → ini regresi kejujuran yang DIPERKENALKAN L1 (sebelum L1, init seed tepat 1 app riil).
- **`design-system/SKILL.md` baris 26** + **`fanout/SKILL.md` baris 22** mem-filter target dari `apps[]` berdasarkan `type` (fe/fullstack), bukan kekosongan `stack`. App blueprint type fe (mis. admin-dashboard) jadi kandidat SKIP/target `design-system` & kandidat `DESIGN-SYSTEM NEEDED` `fanout` meski path-nya dir kosong.

Karena >1 pembaca tak bisa membedakan niat-vs-realita dari `stack: {}`, L1 mewajibkan **penanda yang dibaca** (bukan field/state-machine baru):
1. **`responsibility` membawa frasa** `(blueprint — belum di-bring-up)` — field yang DIBACA semua pembaca `apps[]` (ask route arsitektur, fanout matching, design-system target). Inilah penanda load-bearing.
2. **Komentar inline** `# blueprint, belum di-bring-up` pada entri `apps[]` — penanda yang persist past sesi init untuk pembaca-manusia/skill yang men-scan YAML.
3. **Satu baris di `ask/SKILL.md`** (§5a-bis): saat melaporkan `apps[]`, app ber-marker dilaporkan sebagai "declared, belum di-bring-up", bukan sebagai app riil.

**Alternatif ditolak:**
- *(A) Tambah field `blueprint: true` / `status: declared` per app.* Ditolak — bikin pembaca harus paham state-machine baru di skema; over-engineering untuk LOW. Penanda di **nilai `responsibility`** mencapai tujuan yang sama (terbaca oleh pembaca yang memang sudah membaca `responsibility`) tanpa field baru. Jika di kemudian hari penanda-string terbukti rapuh, field eksplisit ini adalah eskalasi yang jujur.
- *(B) Andalkan `stack: {}` kosong saja (klaim "terbedakan secara alami").* **Ditolak — keliru** (inilah revisi). Diverifikasi di disk: tak satu pun pembaca `apps[]` meng-key pada kekosongan `stack`; semua key pada `type`/`responsibility`. `stack: {}` juga normal untuk app riil greenfield sebelum `architect` jalan (komentar `# diisi architect`), jadi `stack: {}` **tidak** sinonim "blueprint". Penanda di `responsibility` perlu agar intent vs realita bisa dibedakan reader.

### D5 — `capabilities` TIDAK di-pre-fill
**Keputusan:** L1 hanya soal **app** (`name`/`type`/`responsibility`). `capabilities` tetap `[]`, diisi `fanout`/`architect` (workspace.yaml baris 51 comment; parent sec.7.1 baris 117 "tumbuh per fitur (fanout)").
**Alternatif ditolak:**
- *(A) "Capability blueprint" = declare semua capability sekarang juga.* Ditolak — nama gap ("capability blueprint") **bukan** berarti pre-fill capabilities; itu melanggar P1 fan-out just-in-time (sec.7.1 baris 117). L1 = blueprint **app/topologi**, bukan blueprint capability. Nama "capability blueprint" di sini berarti "peta unit/app yang akan punya capability", bukan daftar capability itu sendiri.

### D6 — Hanya sentuh init + satu baris ask; discovery TIDAK diedit
**Keputusan:** L1 hidup di init Langkah 3/5 + satu baris di `ask` (D4). Via discovery (yang men-skip Framing Q&A, baris 27 init / baris 33 discovery), L1 tidak dieksekusi — diterima sebagai batasan jujur.
**Alternatif ditolak:**
- *(A) Tambah klausa L1 di discovery Langkah 2/7 supaya berlaku via discovery juga.* Ditolak untuk fix-light — itu **melebarkan ke file tambahan** (scopeFlags). Tidak perlu: discovery sudah men-declare app target lewat risetnya (baris 33 "apps yang kebayang"), jadi "declare semua app" sudah de-facto terjadi di jalur discovery. Honesty-note (§7) menulis batasan ini jujur.

### D7 — Tidak melanggar otoritas `add-app`
**Keputusan:** L1 dibingkai sebagai "declare app target **awal/saat bootstrap**", konsisten dengan add-app baris 64 ("init cuma declare app AWAL pas bootstrap"). L1 **tidak** mendorong re-run init untuk nambah app belakangan. App blueprint yang sudah ada di `apps[]` aman dari double-declare karena add-app baris 16 STOP pada duplikat (idempotent).
**Alternatif ditolak:**
- *(A) Wording yang menyiratkan "init bisa nambah app kapan saja".* Ditolak — itu jatah `add-app` (penulis tunggal entri app **pasca-init**, add-app baris 3/64). Init Langkah 1-2 (deteksi topologi) tak menjamin idempotency pada re-run. L1 wajib eksplisit: "declare semua **sekarang** (init pertama); nambah **belakangan** tetap lewat `add-app`".

## 4. Tujuan & Non-Tujuan

**Tujuan**
- Perkaya init Langkah 3 baris 32 dengan klausa OPSIONAL: produk besar + app target jelas → boleh declare semua app target sekarang sebagai blueprint (semua masuk `apps[]` dengan `stack: {}` + `responsibility` ber-marker `(blueprint — belum di-bring-up)` + komentar inline marker).
- Jaga DUA jalan tetap setara-valid: (i) mulai satu → `add-app` belakangan, ATAU (ii) declare semua sekarang.
- Eksplisitkan: declare = entri YAML; bring-up (architect/wire) tetap just-in-time per app; marker dilepas saat bring-up.
- Pastikan pembaca `apps[]` read-only (`ask`) melaporkan app blueprint apa adanya ("declared, belum di-bring-up"), bukan sebagai app riil (D4).

**Non-Tujuan (anti scope-creep)**
- **Tak ada skill baru / langkah init baru / section baru.** Skill tetap **21**. Nol churn `plugin.json`/`marketplace.json`/README/induk §12 lifecycle.
- **Tak ubah skema `workspace.yaml` `apps[]`** (sudah list; cukup di-seed >1 entri + penanda di nilai/komentar, BUKAN field baru). Tak ada field `blueprint`/`status`.
- **Tak pre-fill `capabilities`** (tetap diisi fanout/architect; P1 just-in-time).
- **Tak picu architect/wire** untuk app yang baru di-declare (bring-up just-in-time).
- **Tak edit `discovery`** (D6 — jalur discovery sudah declare app dari riset; via discovery L1 di-skip, jujur di §7).
- **Tak edit `add-app`** (L1 = bootstrap-awal; add-app tetap penulis tunggal entri app pasca-init; idempotency add-app baris 16 dipakai apa-adanya, tak diubah).
- **Tak ubah perilaku gate `design-system`/`fanout`** (penanda `responsibility` cuma membuat intent terbaca; ambang/aksi mereka tak diubah).
- **Tak sentuh `packages[]`** (beda kelas unit; package tumbuh lewat `add-package`, init baris 55).
- **Tak sentuh `feature.yaml`/`sensitivity`** (domain stream lain; L1 hidup di init, bukan intake).

## 5. Design per-komponen (c) — edit-map before→after (verbatim disk)

**File disentuh:** (1) `plugin/skills/init/SKILL.md` Langkah 3 (sisip sub-bullet) + Langkah 5 (komentar marker pada skema); (2) `plugin/skills/ask/SKILL.md` (satu baris pelaporan blueprint). Dua file — naik dari "satu file" rencana awal karena D4 mengharuskan penanda BENAR-BENAR dibaca reader (lihat scopeFlags).

### 5a. `plugin/skills/init/SKILL.md` — Langkah 3 (anchor verbatim, `grep -Fc -e` match=1)

**BEFORE (teks disk sekarang, baris 32 verbatim):**
```
- App apa saja yang sudah kebayang? (greenfield: declare; existing: konfirmasi yang terdeteksi). Boleh mulai dari satu, tambah app lain nanti lewat skill `add-app`.
```

**AFTER (sisip satu sub-bullet OPSIONAL di bawah baris 32 — bukan renumber, bukan ubah bullet existing):**
```
- App apa saja yang sudah kebayang? (greenfield: declare; existing: konfirmasi yang terdeteksi). Boleh mulai dari satu, tambah app lain nanti lewat skill `add-app`.
  - **(Opsional — blueprint app)** Kalau produk terdengar besar & app target sudah jelas sejak sekarang, boleh declare SEMUA app target sekaligus (semua masuk `apps[]` dengan `stack: {}` — lihat langkah 5). Tandai tiap app blueprint dengan menambah frasa `(blueprint — belum di-bring-up)` di akhir `responsibility`-nya + komentar `# blueprint, belum di-bring-up` pada entri-nya (lihat langkah 5), supaya pembaca seperti `ask`/`design-system`/`fanout` tahu app itu baru niat, belum dibangun. Ini cuma men-declare niat/topologi; bring-up (architect lalu wire) tetap per app saat app itu digarap — saat itu marker `(blueprint — belum di-bring-up)` dilepas. Produk kecil/belum jelas → cukup mulai satu, sisanya belakangan lewat `add-app`. (Nambah app sesudah init pertama tetap lewat `add-app`, bukan re-run init.)
```

**Catatan implementasi untuk plan (BUG-GUARD):**
- **No-renumber.** Sisipan = sub-bullet (indentasi 2 spasi) di bawah bullet baris 32 yang ADA. Bullet "Nama produk?" (baris 30) & "Satu kalimat..." (baris 31) tak disentuh; tak ada step yang di-renumber.
- **Colon-space `: ` guard.** Sub-bullet ini **prose body**, bukan value YAML/`description:` frontmatter — `: ` di prose aman. Token `stack: {}` di prose adalah **kode YAML inline** yang mereferensi skema langkah 5 (baris 52 sudah memuat `stack: {}` verbatim) — bukan value-pair frontmatter; aman. Frasa marker `(blueprint — belum di-bring-up)` & komentar `# blueprint, belum di-bring-up` **tak memuat** `: ` (pakai em-dash & koma) → aman dimasukkan ke nilai YAML/komentar di langkah 5. Tidak ada `description:` SKILL.md yang diubah (frontmatter init baris 3 tak disentuh).
- **Anchor unik.** Baris 32 verbatim = `grep -Fc -e` match=1 (diverifikasi). Robust leading-dash `- ` + backtick `` `add-app` `` + tanda kurung `(...)`.
- **Cross-ref "langkah 5".** Sub-bullet merujuk "langkah 5" (Generate workspace.yaml, baris 40-56) — pointer benar: di situlah `apps[]` (dengan `stack: {}` baris 52) mendarat & di mana komentar marker disisipkan. Verifikasi langkah 5 masih bernomor 5 pasca-edit (sisipan di langkah 3 tak menggesernya).

### 5a-bis. `plugin/skills/ask/SKILL.md` — laporkan app blueprint apa adanya (anchor verbatim, `grep -Fc -e` match=1)

Pembaca `apps[]` paling kritis adalah `ask` (read-only, output langsung ke user). Tanpa baris ini, `ask` melaporkan app blueprint sebagai app riil → regresi kejujuran (D4). Sisip satu baris di bawah baris tabel arsitektur.

**BEFORE (teks disk sekarang, baris 22 verbatim):**
```
| Arsitektur: app/package, tanggung jawab, stack, capability, topology | `workspace.yaml` |
```

**AFTER (sisip satu baris note di bawah tabel, atau satu klausa pada baris 22 — plan pilih yang anchor-aman; rekomendasi: baris note terpisah agar tabel tak rusak):**
```
| Arsitektur: app/package, tanggung jawab, stack, capability, topology | `workspace.yaml` |
```
Lalu tambah **satu baris prose** tepat di bawah blok tabel klasifikasi (sesudah baris 31 "Pertanyaan lintas-domain → buka >1 sumber."):
```
> App ber-`responsibility` bertanda `(blueprint — belum di-bring-up)` (atau komentar `# blueprint, belum di-bring-up`) = baru di-declare, **belum dibangun**. Laporkan apa adanya ("declared, belum di-bring-up"), jangan sajikan sebagai app riil.
```

**Catatan implementasi (BUG-GUARD):**
- **Anchor-aman.** Plan TIDAK mengubah sel tabel baris 22 (rapuh: pipe-delimited). Yang disisipkan = **baris prose terpisah** sesudah baris 31 (verbatim `Pertanyaan lintas-domain → buka >1 sumber.`, `grep -Fc -e` match=1). Sisipan di luar tabel → tabel utuh, tak ada renumber kolom.
- **Colon-space `: ` guard.** Baris note ini **prose**; `: ` aman. Frasa `(blueprint — belum di-bring-up)` & `# blueprint, belum di-bring-up` tak memuat `: `.
- **Konsisten read-only.** Note ini cuma mengatur *cara melaporkan*; tak menyuruh `ask` menulis apa pun (selaras Guardrails ask baris 72 "Read-only mutlak").

### 5b. `plugin/skills/init/SKILL.md` Langkah 5 — komentar marker pada app blueprint (edit ringan)

Langkah 5 (init baris 40-56) skema `apps[]` **tak perlu ubah struktur** (tetap list multi-entri). Yang ditambah = **satu kalimat instruksi** sesudah blok YAML skema (sesudah baris 55, sebelum Langkah 6) agar init meninggalkan penanda durable pada entri blueprint:

**BEFORE (teks disk sekarang, baris 55 verbatim — anchor `grep -Fc -e` match=1):**
```
Untuk existing, isi `stack` per app dari hasil deteksi `package.json` (framework, db bila terbaca). Biarkan `packages: []` kosong — package tumbuh lewat `add-package`, bukan di-declare saat init.
```

**AFTER (sisip satu kalimat sesudah baris 55):**
```
Untuk existing, isi `stack` per app dari hasil deteksi `package.json` (framework, db bila terbaca). Biarkan `packages: []` kosong — package tumbuh lewat `add-package`, bukan di-declare saat init.
Untuk app yang di-declare sebagai blueprint (opsi blueprint langkah 3 — di-declare tapi belum di-bring-up) → tambahkan frasa `(blueprint — belum di-bring-up)` di akhir `responsibility`-nya DAN komentar inline `# blueprint, belum di-bring-up` pada baris entri (mis. baris `- name:`), supaya pembaca `apps[]` (`ask`/`design-system`/`fanout`) tahu app itu baru niat. `architect`/`wire` melepas frasa marker dari `responsibility` saat app betul-betul di-bring-up.
```

**Catatan implementasi (BUG-GUARD):**
- **Colon-space.** Kalimat AFTER ini prose; ditulis dengan arrow `→` (bukan `): `) agar tak ada colon-space sama sekali. Frasa marker `(blueprint — belum di-bring-up)` & komentar `# blueprint, belum di-bring-up` keduanya TANPA `: ` (pakai em-dash & koma). Plan copy AFTER apa adanya — tak ada sentinel/typo yang perlu dikoreksi.
- **Komentar inline vs value.** Komentar `# blueprint, belum di-bring-up` adalah komentar YAML (sesudah `#`) → bukan value-pair, `: ` tak relevan. Frasa di `responsibility` masuk ke DALAM string ber-kutip `"..."` → tetap satu value, tak memecah YAML.
- **`capabilities: []` & `stack: {}` comment baris 51-52 tak disentuh** — sudah benar untuk app blueprint greenfield (D5). `packages: []` baris 53/55 tak disentuh (beda kelas unit).
- **Durable past-sesi.** Komentar inline + frasa `responsibility` adalah artefak yang tetap terlihat reader sesudah sesi init selesai (menjawab Lesson #16: promise "blueprint, bring-up just-in-time" persist, bukan cuma di Q&A transient).

### 5c. File yang WAJIB tidak dikontradiksi (tak diedit)

- `plugin/skills/add-app/SKILL.md` — klaim eksklusivitas baris 3 ("satu-satunya penulis entri app baru pasca-`init`") & baris 64 ("init cuma declare app AWAL pas bootstrap"). Wording L1 **konsisten**: declare-banyak = masih "saat bootstrap"; "nambah app sesudah init pertama tetap lewat `add-app`" (klausa terakhir sub-bullet). **Idempotency add-app baris 16/24 ("App yang sudah ada di `workspace.yaml` → STOP, jangan re-declare") adalah mekanisme yang membuat app blueprint aman:** kalau `fanout` belakangan mengusulkan app yang ternyata sudah di-declare sebagai blueprint, `add-app` STOP pada duplikat → tak ada double-declare. L1 **tidak** menyiratkan init bisa nambah app belakangan.
- **Interaksi `fanout` ↔ app blueprint (intended path, bukan mis-fire NEW).** `fanout` baris 19 mengusulkan app `NEW` HANYA bila "peran nggak ketampung app mana pun". App blueprint punya `responsibility` (kini ber-marker) → `fanout` baris 16 mencocokkan peran fitur ke `responsibility` app blueprint yang ADA, **bukan** menandai `NEW`. Inilah jalur yang dikehendaki: app blueprint dengan `capabilities: []`/`stack: {}` tetap ter-match by-responsibility, lalu `fanout` mengisi `capabilities`-nya (fanout baris 50) — persis seperti app riil greenfield yang `capabilities`-nya masih kosong. Marker `(blueprint — belum di-bring-up)` di `responsibility` justru membantu `fanout`/user menyadari app itu butuh `add-app` bring-up bila benar tersentuh fitur ini.
- `plugin/skills/discovery/SKILL.md` baris 27/33 — discovery men-skip Framing Q&A init. L1 tidak diedit ke discovery (D6); di jalur discovery L1 tak jalan (jujur di §7).
- `plugin/skills/architect/SKILL.md` baris 21 (3a SETUP) & baris 39 (invarian dikunci sekali, idempotent) — L1 tak mengubah ini. Declare-banyak-app **tidak** memicu 3a; bring-up tetap per app. Invarian platform tetap dikunci sekali (bukan per app declare). Catatan plan: architect/wire melepas frasa marker dari `responsibility` saat bring-up (instruksi di §5b), tapi ini **tak menambah kewajiban baru** ke architect SKILL.md — pelepasan marker terjadi natural saat architect mengisi `responsibility`/`stack` riil app itu. (Bila plan menilai perlu satu baris eksplisit di architect, FLAG — itu file ke-3.)

## 6. Parent-spec amendments (d)

Parent: `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`.

**Verdict: NOL amandemen wajib.** L1 tidak mengubah skema, lifecycle, daftar skill, daftar rule, atau struktur tree. Penanda blueprint = nilai/komentar di entri `apps[]` existing, bukan field skema → §7.1 tak berubah. Verifikasi per section relevan:

| Section parent | Status terkait L1 | Aksi |
|---|---|---|
| §7.1 `workspace.yaml` skema (baris 95-119) | `apps[]` sudah list multi-entri; `capabilities`/`stack` comment sudah benar; marker blueprint = nilai `responsibility` + komentar, BUKAN field baru | **Tak berubah** — L1 cuma men-seed >1 entri + penanda, struktur sama |
| §7 control-tree (baris 61-94) | tak ada file/dir baru | **Tak berubah** |
| §9 `init` (baris 161-166) | "Perilaku — ... seed `workspace.yaml` (greenfield: declare apps; ...)" — sudah bilang **declare apps** (plural) | **Tak berubah** — L1 = penajaman *prompt opsional* + penanda di SKILL.md, bukan kapabilitas baru. Parent "declare apps" sudah mengakomodasi >1 app |
| §12 lifecycle (baris 242-272) | tak ada fase baru; cabang `add-app` (baris 249) tetap utuh | **Tak berubah** |
| §14 greenfield table (baris 285) | "`init` \| declare apps" — sudah plural | **Tak berubah** |
| §17 Komponen (baris 302-307) | skill 21, rules 5 | **Tak berubah** — diverifikasi 21 dir di disk; parent §17 = 21 |

**Catatan (opsional, BUKAN wajib — VERIFY-BEFORE-EDIT):** Bila tim ingin parent menyebut blueprint secara eksplisit, satu klausa advisory boleh disisipkan di §9 `init` Perilaku. Pada disk, baris 164 berbunyi (verbatim, sertakan teks-flow sekitarnya): `... → seed `workspace.yaml` (greenfield: declare apps; brownfield: detect apps + auto-isi `stack` dari package.json) → seed `domain.md` ...`. Anchor yang dipakai = parenthetical `(greenfield: declare apps; brownfield: detect apps + auto-isi `stack` dari package.json)` — **plan WAJIB `grep -Fc -e` parenthetical itu dulu** (ia bagian dari arrow-flow baris 164, bukan baris berdiri-sendiri) sebelum menyisipkan: usulan klausa `(produk besar — boleh declare semua app target sekaligus sebagai blueprint; bring-up tetap just-in-time)` sesudah "declare apps". Pakai em-dash, JANGAN `: ` (ini prose §9, tapi tetap hindari colon-space agar konsisten BUG-GUARD). Ini **kosmetik/dokumentatif**, bukan perubahan kapabilitas. **Default penulis: SKIP** — SKILL.md adalah surface kebenaran perilaku; parent sudah benar. Flag di scopeFlags bila reviewer mau.

## 7. Honesty-note (e) — advisory vs gate; surface kejujuran

Preseden M6: tulis jujur di **surface tempat logika beneran jalan**. L1 logika berada di: (i) sub-bullet init Langkah 3 (tawaran), (ii) instruksi marker init Langkah 5 (penanda durable), (iii) baris pelaporan `ask` (reader jujur).

- **Advisory murni, bukan gate.** L1 **tidak menambah gate**, tidak memblokir apa pun. Init Langkah 2 (konfirmasi topologi) & Langkah 7 (ringkas hasil) tetap gate yang ADA; L1 tak menyentuhnya. Sub-bullet adalah **tawaran**, bukan paksaan — user bebas abaikan & mulai satu app.
- **Opsional & 1 jalur.** Shipped-text di SKILL.md baris 32 sub-bullet harus mengatakan **"(Opsional ...)"** secara literal (sudah di edit-map §5a) — jangan klaim L1 wajib/selalu jalan. Via `discovery`, Framing Q&A init di-skip (baris 27/33) → L1 **tidak dieksekusi**; itu OK (app target dari riset discovery) tapi **jangan klaim L1 berlaku universal**. Honesty hidup di: spec ini §1 (Catatan jujur) + §3 D6.
- **Declare ≠ scaffold (jujur di shipped-text).** Sub-bullet §5a eksplisit: *"Ini cuma men-declare niat/topologi; bring-up (architect lalu wire) tetap per app saat app itu digarap"*. Penanda durable §5b (frasa `responsibility` + komentar) memastikan janji ini **persist past sesi init** — bukan cuma kalimat Q&A yang dibaca sekali. Surface kejujuran = baris-baris itu sendiri.
- **Penanda blueprint terbaca, bukan "terbedakan secara alami".** §1/§3 D4 TIDAK lagi mengklaim `stack: {}` membedakan blueprint secara alami — itu keliru & terverifikasi di disk. Yang membedakan = penanda di `responsibility` + komentar, yang **benar-benar dibaca** minimal oleh `ask` (§5a-bis). `design-system`/`fanout` membaca `responsibility` yang sama → penanda terlihat oleh mereka juga (mereka interaktif/ber-gate, jadi cukup *terlihat*; L1 tak mengubah aksi mereka).
- **R1-R6 (stress-test) dijinakkan oleh wording/penanda, bukan gate baru:**
  - **R1 self-contradiction baris 32:** dijinakkan dengan menempel sub-bullet di bawah bullet yang sama + kata "(Opsional)" + klausa "Produk kecil/belum jelas → cukup mulai satu" — dua jalan koheren.
  - **R2 cascade ke architect/wire:** dijinakkan oleh kalimat "bring-up tetap per app" (declare ≠ scaffold). Tak ada kerja hilir dijadwalkan sekaligus.
  - **R3 tabrakan otoritas add-app:** dijinakkan oleh klausa "(Nambah app sesudah init pertama tetap lewat `add-app`, bukan re-run init.)" + idempotency add-app baris 16 (§5c).
  - **R4 discovery skip:** jujur di §1/§3 D6 — bukan bug, batasan yang disadari.
  - **R5 capabilities overlap palsu:** dijinakkan oleh D5 — L1 declare **app**, bukan capability; `capabilities: []` tetap diisi fanout/architect.
  - **R6 (BARU) reader truthfulness:** app blueprint tampil sebagai app riil ke pembaca `apps[]`. Dijinakkan oleh penanda `responsibility` + komentar + baris `ask` (D4/§5a-bis) — bukan oleh `stack: {}` (yang ternyata tak dibaca siapa pun sebagai sinyal blueprint).

## 8. Self-review checklist awal (f)

- [ ] **Anchor verbatim match=1 (init L3).** `grep -Fc -e '- App apa saja yang sudah kebayang? (greenfield: declare; existing: konfirmasi yang terdeteksi). Boleh mulai dari satu, tambah app lain nanti lewat skill \`add-app\`.' plugin/skills/init/SKILL.md` = 1 (diverifikasi pra-spec).
- [ ] **Anchor verbatim match=1 (init L5).** `grep -Fc -e 'Untuk existing, isi \`stack\` per app dari hasil deteksi \`package.json\` (framework, db bila terbaca). Biarkan \`packages: []\` kosong — package tumbuh lewat \`add-package\`, bukan di-declare saat init.' plugin/skills/init/SKILL.md` = 1 (diverifikasi).
- [ ] **Anchor verbatim match=1 (ask).** `grep -Fc -e 'Pertanyaan lintas-domain → buka >1 sumber.' plugin/skills/ask/SKILL.md` = 1 (diverifikasi). Sel tabel baris 22 TIDAK diubah (rapuh).
- [ ] **No-renumber.** Sisipan init = sub-bullet di bawah baris 32 + kalimat sesudah baris 55; bullet "Nama produk?"/"Satu kalimat..." (baris 30-31) utuh; Langkah 4/5/6/7 tetap bernomor sama. Sisipan ask = baris prose di luar tabel; tabel utuh.
- [ ] **Dua file (bukan satu).** `plugin/skills/init/SKILL.md` + `plugin/skills/ask/SKILL.md` diedit (D4 mengharuskan reader jujur). discovery/add-app/architect/workspace-schema/parent TIDAK diedit. (Naik dari "satu file" — di-flag di scopeFlags.)
- [ ] **Skema tak berubah.** `apps[]` tetap list; tak ada field `blueprint`/`status` baru (D4). Penanda = nilai `responsibility` + komentar inline, bukan field. `capabilities`/`stack` comment baris 51-52 tak disentuh (D5).
- [ ] **Penanda blueprint terbaca.** Frasa `(blueprint — belum di-bring-up)` masuk ke `responsibility`; komentar `# blueprint, belum di-bring-up` per entri; baris `ask` melaporkannya apa adanya (D4/§5a-bis). Tak mengklaim `stack: {}` membedakan secara alami.
- [ ] **Declare ≠ scaffold.** Sub-bullet eksplisit "bring-up tetap per app"; tak memicu architect/wire untuk app yang di-declare (D3). Marker dilepas saat bring-up.
- [ ] **Advisory, bukan gate.** Sub-bullet pakai "(Opsional)" + "boleh"; tak ada "wajib/STOP/blokir". Init gate (Langkah 2/7) tak berubah. `design-system`/`fanout` aksi/ambang tak diubah.
- [ ] **Otoritas add-app utuh.** Klausa "nambah app sesudah init pertama tetap lewat `add-app`" ada; idempotency add-app baris 16 dipakai apa-adanya (§5c); tak menyiratkan init nambah app belakangan (D7, vs add-app baris 3/64).
- [ ] **fanout match-by-responsibility = intended.** App blueprint ter-match fanout baris 16 (by responsibility), bukan mis-fire `NEW` baris 19 (§5c). Tak ubah fanout.
- [ ] **Dua jalan koheren.** "mulai satu" (existing) & "declare semua" (L1) sama-sama valid; tak kontradiksi dalam satu bullet (R1).
- [ ] **Colon-space.** Tak ada `description:` SKILL.md (init/ask) diubah; `: ` di sub-bullet/baris-ask = prose/kode-YAML-inline (aman). Frasa marker & komentar marker TANPA `: ` (pakai em-dash/koma). `sed -n 's/^description: //p' plugin/skills/init/SKILL.md | grep ': '` tetap seperti sebelum-edit (frontmatter tak disentuh).
- [ ] **capabilities tak di-pre-fill.** L1 declare app saja; `capabilities: []` tetap diisi fanout/architect (D5, sec.7.1 baris 117).
- [ ] **Parent NOL amandemen wajib.** §7.1/§7/§9/§12/§14/§17 tak berubah (§6 tabel). §9 klausa kosmetik opsional = SKIP default + VERIFY-BEFORE-EDIT.
- [ ] **Skill-count 21, rules 5.** Tak ada churn `plugin.json`/`marketplace.json`/README; tak ada skill/rule baru.
- [ ] **discovery-skip jujur.** §1/§3 D6/§7 menulis bahwa L1 tak jalan via discovery; tak klaim universal.
- [ ] **scope = fix-light (2 file).** Plan menyentuh 2 file (init + ask) — masih fix-light tapi naik dari 1; di-flag. Bila plan ternyata perlu file ke-3 (mis. architect untuk pelepasan marker eksplisit, atau discovery/parent), FLAG — jangan diam-diam balloon.
