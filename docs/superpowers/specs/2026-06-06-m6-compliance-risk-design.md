# M6 — Compliance-Risk Discovery (risiko compliance durable + dibaca hulu→hilir)

> Langkah-3, gap **M6** (MEDIUM) — kandidat quick-win Langkah-3. Tanggal: **2026-06-06**. Repo `~/Developer/ai-boilerplate`, base `main` @ `10ea486`.
> Brainstorming **terkunci** lewat 3 AskUserQuestion: strictness=**advisory (peringatan saja, bukan gate baru)**; cakupan=**inti compliance (PCI · GDPR/Privasi · Pajak · KYC/AML) + baris bebas**; consumer=**discovery (penulis) → architect + intake + ship/security-critic (pembaca)**.

## 1. Ringkasan

`discovery` **sudah meriset** risiko regulasi (`discovery/reference.md` §A "Risiko" memuat regulasi), tapi §D-nya **membuang SEMUA analisis risiko ke HTML** (`discovery-draft.html`) dan **melarang** menyeberang ke `control/business/` ("SEMUA analisis pasar (… risiko …) TINGGAL di HTML"). Akibatnya pengetahuan **compliance** (PCI/GDPR/pajak/KYC) hilang begitu discovery selesai — tak ada artifact durable, tak ada skill hilir yang membacanya.

M6 menambah **satu file durable** `control/business/risks.md` (carve-out: hanya kewajiban **compliance/regulasi** yang durable; risiko pasar/kompetitor/monetisasi/verdict **tetap di HTML**). Logika "apa yang durable vs apa yang tinggal di HTML + sifat advisory + cara baca" generik tinggal di **satu shared rule** `rules/compliance-risk.md` (cermin `rules/migration-impact.md`). Penulis = `discovery`; pembaca = `architect` (saat mengunci invarian PII/PCI), `intake` (constraint per-fitur + perkuat usulan `sensitivity`), `ship`/`security-critic` (baseline red-team). Semuanya **advisory** — memperkaya keputusan & gate yang ADA, **bukan** palang keras baru (satu-satunya stop tetap Security Gate `ship` yang sudah ada). **Tak ada skill baru** (skill tetap **21**); rules **4→5** (anti-yes-man/debt-aware/schema-projection/migration-impact → +compliance-risk = **5** file rules).

> **Catatan jujur (advisory di hulu, gate existing di hilir).** Di `architect`/`intake`/`discovery`, M6 **murni advisory** — memperkaya elicitation, tak memblokir apa pun. Di `ship`, M6 **tak menambah gate** tapi **memperkaya input gate yang SUDAH ADA** (Security Gate Langkah-1): memberi `security-critic` peta regulasi + lensa compliance dapat membuat fitur yang tadinya GREEN jadi RED bila diff-nya melanggar kewajiban yang kini diketahui. Ini **konsekuensi yang dikehendaki** dari memberi red-team konteks regulasi (sejajar dgn menambah invarian ke `invariants.md`) — **ambang RED tak diubah**, yang melebar adalah *himpunan* temuan yang ter-deteksi. **Blast-radius terbatas:** `security-critic` cuma di-invoke utk fitur ber-`sensitivity` `payments`/`pii` (`ship` step 4.5) → risks.md tak pernah bisa men-trigger RED utk fitur non-sensitif.

M6 **tak menggandakan** mesin yang ada: `risks.md` = *lanskap regulasi hulu* yang **memberi makan** slot `invariants.md` PII/PCI (keputusan teknis terkunci) & tag `sensitivity` (per-fitur), **bukan** saingannya.

## 2. Masalah

- **Riset compliance dibuang.** `discovery/reference.md` §A meriset "Risiko — … regulasi …", tapi §D ("Yang nyebrang ke business/") eksplisit: hanya `domain.md`/`glossary.md`/`flows.md` yang durable; "yang `asumsi`/`spekulatif` & SEMUA analisis pasar (pasar, kompetitor, monetisasi, **risiko**, verdict) TINGGAL di HTML — JANGAN masuk `business/`." Carve-out compliance belum ada → analisis regulasi yang valid ikut terbuang.
- **Tak ada rumah durable buat kewajiban compliance.** `control/business/` cuma `domain.md`/`flows.md`/`glossary.md`. Tak ada tempat menampung "produk ini kena PCI karena simpan kartu / kena GDPR karena PII / kena pajak jurisdiksi X / kena KYC".
- **Hulu (architect) ngunci invarian PII/PCI tanpa bahan compliance.** `architect` step 4.5 mengisi slot `invariants.md` "PII / PCI / Data Sensitif" (& "Money & Currency") dari Q&A, tanpa input lanskap regulasi yang sudah diriset discovery → keputusan fondasi bisa luput regulasi yang sebenarnya sudah diketahui.
- **Per-fitur (intake) nebak sensitivity dari heuristik teks doang.** `intake` step 7 mengusulkan tag `sensitivity: payments|pii` dari heuristik isi `business.md` + cross-check `invariants.md`. Tak ada constraint compliance durable yang memperkuat/membenarkan usulan itu ("fitur ini nyimpan kartu → kewajiban PCI di risks.md → tag payments + kutip").
- **Cek terakhir (ship/security-critic) red-team tanpa peta regulasi.** `security-critic` (dipanggil `ship` step 4.5) menerima `invariants.md`/`conventions.md`/`integrations.md` sebagai baseline, **tak** menerima daftar kewajiban compliance yang relevan → red-team bisa lewatkan "diff ini langgar GDPR/PCI yang sudah diketahui di hulu".

## 3. Tujuan & Non-Tujuan

**Tujuan**
- File durable `control/business/risks.md` (cermin gaya `invariants.md`): slot saran **PCI · GDPR/Privasi · Pajak · KYC/AML** + baris bebas; tiap slot **isi ATAU `N/A — alasan`**; sentinel `<belum dinilai>`; bentuk entri *pemicu · kewajiban · [label keyakinan] · sumber* (slot heading = area). Auto-scaffold `init` (sudah copy `business/*.md` + ganti `<PRODUCT>`).
- Shared rule `rules/compliance-risk.md` (cermin `migration-impact.md`): dokumentasikan **sekali** batas carve-out (compliance durable vs pasar di HTML), bentuk entri, sifat **advisory**, cara tiap pembaca pakai, klausa **degrade** (sentinel/kosong → best-effort, jangan error/blokir), anti-fiksi (sumber dari riset discovery, bukan dikarang).
- `discovery` carve-out: risiko **compliance** → `risks.md` (durable, ikut aturan label/sitasi yang ada); risiko pasar/kompetitor/monetisasi/verdict **tetap di HTML**. SKILL.md step 7 seed `risks.md`.
- `intake` baca `risks.md` (constraint per-fitur) + Challenge Checklist +1 baris + heuristik `sensitivity` diperkuat kewajiban yang cocok (+kutip). Advisory.
- `architect` step 4.5 baca `risks.md` sebagai **constraint** saat mengisi slot invarian PII/PCI (& Money). Advisory.
- `ship`/`security-critic` terima `risks.md` sebagai **baseline** red-team; lensa "diff langgar kewajiban compliance di `risks.md`?". Temuan high-sev tetap RED (mekanisme existing).

**Non-Tujuan (seam bersih, anti scope-creep)**
- **Tak ada skill baru**, tak ada `/compliance`/`/risk`. Skill tetap **21**. Nol churn `plugin.json`/`marketplace.json`/README/induk §12 (lifecycle — tak ada fase baru).
- **Tak ada palang keras baru.** Strictness = **advisory** (pilihan user): kewajiban compliance dimunculkan sebagai constraint/catatan, **tidak** memblokir architect/intake/feature. Satu-satunya STOP tetap Security Gate `ship` step 4.5 yang **sudah ada** (high-sev → RED) — M6 cuma memberinya baseline lebih kaya, **tak** menambah gate.
- **Tak menggandakan `invariants.md` PII/PCI.** `risks.md` = lanskap regulasi hulu (apa yang berlaku & kenapa); `invariants.md` = keputusan teknis terkunci (bagaimana ditangani). `risks.md` **memberi makan** slot itu (§6b), bukan menyalin.
- **Tak menggandakan tag `sensitivity`.** `risks.md` = **input** yang memperkuat usulan `sensitivity` intake, bukan penggantinya. Heuristik teks intake tetap jalan tanpa `risks.md`.
- **Risiko pasar/kompetitor/operasional TIDAK masuk.** Tetap di `discovery-draft.html` → `control/docs/discovery.html` (cermin §D existing). `risks.md` **hanya** compliance/regulasi.
- **Tak menyimpan analisis pasar/verdict** ke `business/` (aturan §D existing tetap, M6 cuma menambah carve-out compliance).
- **Tak ubah** `domain.md`/`flows.md`/`glossary.md` (compliance bukan aturan domain/flow/istilah — rumahnya sendiri).
- **Tak ubah** mekanik `sensitivity`/`feature.yaml` schema, `security-critic` *output* format (cuma tambah 1 input baseline), Security Gate threshold (high→RED tetap).
- **Tak ubah** `render-docs` (`risks.md` = knowledge durable yang dibaca skill, bukan badge/doc yang di-render; konsisten alasan invariants/integrations tak di-render terpisah).
- **Brownfield `extract`** ditunda (konsisten M4/H2/H3): produk tanpa discovery dapat sentinel template dari `init`; pembaca degrade mulus. Tak ada elicitation compliance di `extract` (sub-proyek terpisah).

## 4. File durable — `control/business/risks.md`

Cermin gaya `invariants.md` (slot saran + sentinel + "isi ATAU N/A"). Template `plugin/template/control/business/risks.md`:

```markdown
# <PRODUCT> — Risiko Compliance

> Kewajiban hukum/regulasi DURABLE yang berlaku ke produk; di-seed `discovery` (carve-out compliance), dibaca `architect` (kunci invarian PII/PCI), `intake` (constraint per-fitur), `ship` (baseline red-team).
> Cuma compliance/regulasi di sini — risiko pasar/kompetitor TINGGAL di `docs/discovery.html`.
> Tiap slot: ISI kewajibannya, ATAU tulis "N/A — <alasan>" — jangan tinggalkan pada penanda kosong sebelum produk jalan.
> Bentuk entri tiap slot: pemicu (apa yang mengaktifkan) — kewajiban (apa yang harus dilakukan) — [label keyakinan] — sumber. Tambah baris bebas untuk regulasi spesifik-produk.

## PCI (kartu / pembayaran)
<belum dinilai>

## GDPR / Privasi (data pribadi)
<belum dinilai>

## Pajak (jurisdiksi / PPN)
<belum dinilai>

## KYC / AML (verifikasi identitas)
<belum dinilai>
```

- **Slot saran** (4) = kategori paling sering kena produk uang+data; `discovery` boleh menandai `N/A — alasan` (mis. "Pajak — N/A: produk non-transaksional") dan **menambah baris bebas** untuk regulasi lain (mis. PSD2/open-banking, HIPAA sektor kesehatan, regulasi sektor/jurisdiksi spesifik) bila riset menemukannya.
- **Bentuk entri** mengikuti aturan label/sitasi `discovery` yang ADA (`reference.md` §B/§C): `terverifikasi`/`asumsi`/`spekulatif` + sumber (URL+tanggal). **Hanya `terverifikasi`/`asumsi` (dengan sumber/alasan) yang durable ke risks.md**; `spekulatif` tinggal di HTML. **Catatan (melonggarkan §D secara sadar & terbatas):** §D existing izinkan **hanya `terverifikasi`** nyebrang ke `business/` (`asumsi` eksplisit JANGAN). Carve-out compliance **sengaja melonggarkan** ini ke `terverifikasi`+`asumsi` **khusus sub-kelas compliance** — karena (i) M6 advisory (false-positive = sekadar peringatan, murah) dan (ii) **under-detect compliance lebih bahaya** dari over-detect. Pelonggaran ini diwujudkan eksplisit di edit §D (§6a/§9), bukan diam-diam.
- **Sentinel `<belum dinilai>`** = belum diisi (cermin `<belum dikunci>` invariants). Pembaca memperlakukan sentinel = "best-effort, tak ada kewajiban diketahui" (degrade, §5/§8) — **bukan** error.
- **`init` auto-scaffold:** `init` step 4 sudah `cp -R template/control/.` + ganti `<PRODUCT>` di "SEMUA file `business/*.md`" (glob) → `risks.md` ikut otomatis; greenfield biarkan skeleton (tumbuh lewat discovery). Tak perlu langkah init baru.

**Asimetri sengaja vs `invariants.md`:** keduanya level-produk, durable, slot+sentinel. Bedanya: `invariants.md` dikunci `architect` (keputusan **teknis** fondasi); `risks.md` di-seed `discovery` (temuan **regulasi** pra-init). `risks.md` adalah salah satu **input** yang membentuk slot PII/PCI invariants (§6b) — hulu dari invariants, bukan duplikatnya.

## 5. Otak bersama — shared rule `rules/compliance-risk.md`

Satu file resep generik (cermin `rules/migration-impact.md`), dirujuk via `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`. **Bukan langkah berdiri sendiri** — dokumentasi + prosedur ringan yang dipanggil penulis (`discovery`) & pembaca (`architect`/`intake`/`ship`). **Read-only bagi pembaca**; penulis tunggal `risks.md` = `discovery` (cermin "penulis tunggal" pola yang ada). Semua **advisory**.

**Isi rule:**
- **Batas carve-out (definisi tunggal).** DURABLE ke `risks.md`: kewajiban **compliance/regulasi** yang lepas-dari-fitur (PCI/GDPR/pajak/KYC + sejenis spesifik-produk), label `terverifikasi`/`asumsi` + sumber/alasan. **TINGGAL di HTML** (`docs/discovery.html`): pasar, kompetitor, monetisasi, verdict, dan risiko ber-label `spekulatif`. Ini **melonggarkan** aturan §D discovery secara sadar & terbatas (§D existing izinkan hanya `terverifikasi` nyebrang; carve-out compliance izinkan `terverifikasi`+`asumsi` utk sub-kelas compliance saja — alasan §4).
- **Aturan-batas overlap (compliance vs market-risk).** Satu temuan regulasi bisa punya **dua dimensi**: (i) *compliance-obligation* (apa yang HARUS dilakukan agar legal) dan (ii) *market-risk* (apakah regulasi mengancam viabilitas bisnis). Pembagi: **kewajibannya nyebrang ke `risks.md`; analisis dampak-pasarnya tetap di HTML.** Mis. "GDPR bikin biaya compliance tinggi (risiko pasar) + wajib consent+DSAR (kewajiban)" → kewajiban consent/DSAR ke `risks.md`, narasi "biaya tinggi mengancam margin" tetap HTML.
- **Bentuk entri:** pemicu — kewajiban — [label] — sumber. Per slot kategori (§4); baris bebas untuk regulasi lain.
- **Sifat advisory (untuk pembaca):** kewajiban compliance dimunculkan sebagai **constraint/catatan** untuk dipertimbangkan; rule **TAK memblokir** architect/intake/feature. Satu-satunya STOP = Security Gate `ship` existing (high-sev → RED) — itu mekanisme yang ada, bukan gate baru M6.
- **Cara tiap pembaca pakai** (ringkas; detail wiring §6):
  - `architect` (kunci invarian): saat mengisi slot `invariants.md` PII/PCI & Money, **cocokkan** dengan kewajiban di `risks.md` → pastikan keputusan teknis menutup regulasi yang diketahui.
  - `intake` (per-fitur): cocokkan fitur dengan pemicu di `risks.md` → bila cocok, **perkuat** usulan `sensitivity` + **kutip** kewajibannya di Challenge Checklist.
  - `ship`/`security-critic`: pakai daftar kewajiban relevan sebagai **baseline** red-team diff ("diff menyentuh pemicu X → apakah kewajibannya dipenuhi?").
- **Anti-fiksi (penulis tunggal = discovery):** kewajiban berasal dari **riset `discovery` yang bersumber** (aturan label/sitasi `discovery/reference.md` §B/§C), **bukan** dikarang pembaca. **Tak ada pembaca yang menulis `risks.md`** — berlaku utk SEMUA pembaca. Tapi **efek "gap compliance baru" beda per kelas pembaca:**
  - **Pembaca-elicitation (`architect`/`intake`):** gap baru → **angkat ke user (advisory)**, lalu lanjut; tak menulis `risks.md`.
  - **Pembaca-gate (`security-critic` di `ship`):** ia subagent read-only yang OUTPUT-nya daftar temuan ber-severity; gap compliance yang dinilai **high TETAP jadi temuan → RED** lewat mekanisme `ship` existing (memang fungsinya), **bukan** "angkat lalu lanjut". Tetap tak menulis `risks.md`.
- **Degrade-ke-best-effort:** `risks.md` tak ada / semua slot `<belum dinilai>` / produk tanpa discovery → pembaca jalan "best-effort, tak ada kewajiban compliance diketahui" + tetap pakai mekanisme existing (heuristik sensitivity intake, Q&A architect, scan security-critic). **Jangan error, jangan blokir.**
- **Generik:** kategori PCI/GDPR/pajak/KYC = lintas-domain; rule tak meng-hardcode jurisdiksi/stack tertentu; baris bebas menampung regulasi spesifik-produk.
- **Batas (sadar):** `risks.md` hanya selengkap riset discovery; produk yang skip discovery / regulasi yang luput riset tak tertangkap → gate manusia (architect/ship) tetap jaring akhir.

## 6. Wiring — di mana M6 nempel

### 6a. `discovery` — carve-out compliance (penulis)
- `discovery/reference.md` §A (bullet "Risiko"): tambah **sub-prompt compliance** — saat riset Risiko, **secara terstruktur** nilai empat kategori kewajiban (PCI · GDPR/privasi · pajak · KYC/AML) + regulasi sektor/jurisdiksi spesifik. (Hari ini §A cuma menyebut "regulasi" sebagai SATU contoh risiko-kegagalan komersial — terlalu tipis utk mengisi slot `risks.md`; sub-prompt ini memperdalamnya.)
- `discovery/reference.md` §D: tambah baris carve-out — "`risks.md` (compliance durable): kewajiban regulasi `terverifikasi`/`asumsi` + sumber/alasan dari seksi Risiko (PCI/GDPR/pajak/KYC + spesifik-produk). **SEMUA analisis pasar lain (pasar/kompetitor/monetisasi/verdict) + risiko ber-label `spekulatif` TETAP di HTML**." Ini **melonggarkan §D** (yang tadinya hanya `terverifikasi` nyebrang) **khusus sub-kelas compliance** — bukan membatalkan larangan analisis-pasar §D. Aturan-batas overlap = §5.
- `discovery/SKILL.md` step 7.2 (SEED `business/`): tambah `risks.md` ke daftar yang di-seed — "seed `control/business/risks.md` (compliance carve-out, lihat `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`): isi slot dari seksi Risiko yang `terverifikasi`/`asumsi`+sumber; sisanya `N/A — alasan`."

### 6b. `architect` — kunci invarian sadar-compliance (pembaca)
`architect/SKILL.md` step 4.5 (Kunci Invarian, GATE): saat ELICIT slot `invariants.md` PII/PCI (& Money & Currency), **baca `control/business/risks.md`** (bila ada) sebagai constraint → cocokkan keputusan teknis dengan kewajiban regulasi yang diketahui (mis. "risks.md sebut PCI → slot PII/PCI harus menutup penanganan kartu"). Advisory: memperkaya elicitation, **tak** memblokir. Degrade: `risks.md` sentinel/absen → step 4.5 jalan seperti sekarang (Q&A + critic). `critic` di gate ini (yang sudah WAJIB) bisa silang ke `risks.md` bila ada.

### 6c. `intake` — constraint per-fitur + perkuat sensitivity (pembaca)
- `intake/SKILL.md` step 2 (Baca knowledge): tambah `risks.md` ke yang dibaca (`control/business/*.md` sudah glob — tambah penyebutan eksplisit `risks.md` + tujuannya: constraint compliance).
- step 5 (Challenge Checklist): +1 baris "Menyentuh kewajiban compliance di `risks.md`? (PCI/GDPR/pajak/KYC) — bila ya, kutip + pastikan tertangani."
- step 7 (usulan `sensitivity`): tambah klausa — bila fitur cocok dengan pemicu di `risks.md`, **perkuat** usulan tag (`payments`/`pii`) + **sebut kewajiban** sebagai alasan. Advisory; heuristik teks existing tetap jalan bila `risks.md` kosong.

### 6d. `ship` + `security-critic` — baseline red-team (pembaca)
- `plugin/agents/security-critic.md`: tambah `control/business/risks.md` ke set input baseline (sejajar `invariants.md`/`conventions.md`/`integrations.md`) + 1 lensa "Silang dengan `risks.md`: diff menyentuh pemicu kewajiban (kartu→PCI, PII→GDPR, dst) → apakah kewajibannya dipenuhi?". Read-only tetap; temuan high-sev tetap dilaporkan (threshold RED ada di `ship`).
- `ship/SKILL.md` step 4.5 (Security & Compliance Gate): saat invoke `security-critic` (sensitivity `payments`/`pii`), **sertakan `control/business/risks.md`** ke baseline yang dioper (sejajar `invariants.md`/`integrations.md`). Ambang RED (high-sev) **tak berubah**. Degrade: `risks.md` absen → security-critic jalan seperti sekarang.
- **Honesty + blast-radius (lihat Catatan jujur §1):** di seam ini M6 **bukan murni advisory** — ia memperkaya gate existing, jadi diff yang melanggar kewajiban compliance yang kini diketahui **bisa jadi RED** yang sebelumnya lolos. **Dikehendaki** (red-team sadar-regulasi). **Terbatas:** `security-critic` cuma di-invoke utk fitur ber-`sensitivity` `payments`/`pii` (step 4.5); fitur `sensitivity` kosong hanya kena quick-scan (tak invoke critic) → `risks.md` **tak** bisa men-trigger RED di jalur itu.

## 7. Generik (jaminan lintas-produk)

- Kategori PCI/GDPR/pajak/KYC = universal lintas produk uang+data; baris bebas menampung regulasi sektor/jurisdiksi spesifik → tak meng-hardcode satu domain.
- `risks.md` = markdown slot+sentinel = generik (cermin `invariants.md`/`integrations.md`).
- Pembaca pakai by-understanding (cocokkan fitur/diff ke pemicu), bukan rule hardcode per-stack.
- **Degrade-anggun** di tiap titik: `risks.md` absen/sentinel / produk tanpa discovery → best-effort, mekanisme existing (heuristik intake, Q&A architect, scan security-critic) tetap jalan; tak pernah error/blokir.

## 8. Edge case & degrade

| Kasus | Perilaku |
|---|---|
| Greenfield via `discovery` | `discovery` seed `risks.md` dari riset Risiko (compliance `terverifikasi`/`asumsi`); slot tak relevan → `N/A — alasan`. Pembaca pakai sebagai constraint/baseline. |
| Produk **tanpa** discovery (init manual / `extract`) | `init` scaffold `risks.md` sentinel `<belum dinilai>`. Pembaca degrade: best-effort, "tak ada kewajiban compliance diketahui" — mekanisme existing tetap jalan. Tak error/blokir. |
| Slot `<belum dinilai>` (belum diisi) | Pembaca perlakukan = best-effort kosong (degrade, §5). Bukan error. |
| Slot `N/A — alasan` | Pembaca anggap kategori itu tak berlaku (mis. "Pajak — N/A: non-transaksional") → skip; tetap baca slot lain. |
| Fitur menyentuh pemicu compliance, tag sensitivity belum ada | `intake` step 7 **perkuat** usulan `sensitivity` + kutip kewajiban (advisory) → user putuskan. Tak auto-set tanpa konfirmasi (mekanik approve existing). |
| Diff `ship` langgar kewajiban di `risks.md` | `security-critic` laporkan sebagai temuan; high-sev → RED (mekanisme `ship` existing). M6 cuma menambah baseline, ambang tak berubah. |
| Compliance gap baru ditemukan pembaca (tak ada di `risks.md`) | Pembaca **angkat ke user** (advisory) — **tak** menulis ke `risks.md` (penulis tunggal = discovery). Anti-fiksi (§5). |
| Risiko pasar/kompetitor | Tetap di `docs/discovery.html` (carve-out: tak masuk `risks.md`). |
| Regulasi spesifik-produk (mis. PSD2/open-banking, HIPAA sektor kesehatan) | `discovery` tambah **baris bebas** di `risks.md` bila riset menemukannya; pembaca baca sama seperti slot saran. |
| `risks.md` ada tapi discovery riset-nya tipis (regulasi luput) | `risks.md` hanya selengkap riset (§5 batas); gate architect/ship = jaring akhir manusia. Degradasi anggun, bukan fatal. |

## 9. Edit-map (anchor diverifikasi `grep -Fc -e` saat writing-plans)

**NEW**
- `plugin/template/control/business/risks.md` — template §4 lengkap (slot PCI/GDPR/Pajak/KYC + sentinel `<belum dinilai>` + guidance entri/carve-out + `<PRODUCT>` placeholder).
- `plugin/rules/compliance-risk.md` — resep §5 lengkap (carve-out, bentuk entri, advisory, cara pembaca, anti-fiksi, degrade, generik, batas).

**MODIFY skill/agent**
- `plugin/skills/discovery/reference.md` — §A (anchor `- **Risiko** — Apa yang bisa bikin gagal (pasar jenuh, switching cost tinggi, regulasi, beratnya eksekusi)?`): tambah sub-bullet/klausa "nilai terstruktur 4 kategori compliance (PCI · GDPR/privasi · pajak · KYC/AML) + regulasi sektor/jurisdiksi" (sisip sub-line, **bukan** renumber). Memperdalam "regulasi" yang tadinya cuma satu contoh risiko-kegagalan → cukup utk mengisi slot `risks.md`.
- `plugin/skills/discovery/reference.md` — §D (anchor `Yang `asumsi`/`spekulatif` & SEMUA analisis pasar (pasar, kompetitor, monetisasi, risiko, verdict) TINGGAL di HTML — JANGAN masuk `business/`.`): tambah baris carve-out compliance SESUDAH baris itu (sisip bullet, **bukan** renumber) — "**Pengecualian compliance:** kewajiban regulasi (PCI/GDPR/pajak/KYC + spesifik-produk) ber-label `terverifikasi`/`asumsi`+sumber **nyebrang ke `risks.md`** (lihat `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`); pasar/kompetitor/monetisasi/verdict + risiko `spekulatif` tetap HTML." **Ini MELONGGARKAN §D** (yang tadinya hanya `terverifikasi` & melarang `asumsi`) khusus sub-kelas compliance — bullet pengecualian harus eksplisit menyebut `asumsi`-compliance boleh, agar tak kontradiksi dgn klausa "asumsi JANGAN" di baris larat (yang tetap berlaku utk analisis-pasar). Aturan-batas overlap = §5.
- `plugin/skills/discovery/SKILL.md` — step 7 sub-2 (anchor `2. SEED `business/` (KONSERVATIF, hanya `terverifikasi` & durable — `reference.md` bagian D): `domain.md` (...)`): tambah `risks.md` ke daftar seed + rujuk `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md` (sisip klausa di kalimat seed, bukan step baru). **Catatan:** kalimat ini juga memuat "hanya `terverifikasi` & durable" — seed `risks.md` ikut pengecualian compliance (terverifikasi+asumsi); pastikan klausa sisipan tak bikin kontradiksi (kualifikasi: "kecuali compliance ke `risks.md`").
- `plugin/skills/architect/SKILL.md` — step 4.5 (anchor `- Kalau ada slot `<belum dikunci>`: **ELICIT** per slot keputusannya (level fondasi, bukan stack).`): tambah klausa "baca `control/business/risks.md` (bila ada) sebagai constraint saat ELICIT slot PII/PCI & Money — cocokkan keputusan dengan kewajiban regulasi; advisory, degrade bila absen (lihat `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`)". Sub-clause, **bukan** renumber gate.
- `plugin/skills/intake/SKILL.md` — (1) step 2 (anchor `Baca `control/business/*.md` (domain, flows, glossary) + `control/workspace.yaml` (apps + capabilities).`): tambah `risks.md` (constraint compliance). (2) step 5 Challenge Checklist (anchor `- Apa yang bisa jebol / risiko?`): +1 bullet "Menyentuh kewajiban compliance di `risks.md`? (PCI/GDPR/pajak/KYC) — kutip bila ya." (3) step 7 sensitivity (anchor `**Usulkan tag `sensitivity`** dari isi `business.md` (heuristik):`): tambah klausa "cocok dengan pemicu di `control/business/risks.md` → perkuat usulan + sebut kewajiban (advisory; lihat rule `compliance-risk`)".
- `plugin/agents/security-critic.md` — (1) baris input (anchor `Kamu menerima: diff fitur (path + range/SHA per repo) + `control/invariants.md` (baseline invarian Tenancy/Authz/PII-PCI + Integrasi/Webhook) + `control/conventions.md` + `control/integrations.md` (kontrak SHAPE vendor — baseline webhook signature/mode/idempotency).`): tambah `+ `control/business/risks.md` (baseline kewajiban compliance: PCI/GDPR/pajak/KYC)`. (2) langkah 1 (anchor `1. Baca diff + `control/invariants.md` + `control/conventions.md` + `control/integrations.md`.`): tambah `+ `control/business/risks.md``. (3) langkah 2 list lensa: tambah bullet "**Langgar kewajiban compliance** — silang `risks.md`: diff menyentuh pemicu (kartu→PCI, PII→GDPR, identitas→KYC) → kewajibannya tak dipenuhi." (sisip bullet di list, bukan renumber). (4) **frontmatter `description:`** (anchor `Diberi diff + invariants.md/conventions.md/integrations.md, tugasnya MENCARI`): tambah `risks.md` ke daftar baseline → `...invariants.md/conventions.md/integrations.md/risks.md, tugasnya MENCARI` (separator `/`, **TANPA `: `** — colon-space guard; description disk saat ini bersih dari `: `, jaga tetap bersih). Cegah description stale-vs-body.
- `plugin/skills/ship/SKILL.md` — step 4.5 (anchor `**`sensitivity` memuat `payments`/`pii` →** invoke subagent **`security-critic`** atas diff penuh (lintas repo yang kena, path/SHA dari code-review step 2) + `control/invariants.md` + `control/integrations.md` (baseline webhook signature/mode/idempotency per vendor).`): tambah `+ `control/business/risks.md` (baseline kewajiban compliance; memperkaya gate ini — pelanggaran high tetap RED)` ke daftar baseline yang dioper (honest-in-isolation, lihat §1/§6d). Sub-clause, **bukan** renumber.

**MODIFY parent spec** `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`
- §7 control-tree (anchor byte-eksak **7 spasi** sebelum `#`: `│   └── glossary.md       # istilah` — verified match=1): ubah `└──`→`├──` pada baris glossary + tambah baris `│   └── risks.md          # risiko compliance durable (M6; diisi discovery)` SESUDAHNYA. **Alignment baris baru: `risks.md` + 10 spasi sebelum `#`** (samakan kolom `#` dgn `glossary.md` yg 7 spasi; `risks.md` lebih pendek 3 char → +3 spasi = 10). Verifikasi byte-eksak `grep -Fc -e` kedua baris.
- §8 repo-tree rules (anchor middot-tanpa-spasi-depan, verified match=1: `anti-yes-man.md· debt-aware.md· schema-projection.md· migration-impact.md`): append `· compliance-risk.md` → `…· migration-impact.md· compliance-risk.md`. **Separator = middot+spasi `· ` (U+00B7, TANPA spasi-depan) — BEDA dari §17 Rules (` · ` spasi-middot-spasi); ikuti gaya lokal masing-masing baris.** Tanpa edit ini §8 (4 rule) ↔ §17 (5 rule) jadi inkonsisten.
- §9 ship Security & Compliance gate (parent **line ~210**, di bawah `### ship` — **bukan** §17/Komponen) (anchor `red-team diff (secret/PII/PCI/authz/webhook) terhadap `invariants.md` + `integrations.md` (baseline webhook); temuan high → STOP.`): sisip `risks.md` **SETELAH** `(baseline webhook)` → "...terhadap `invariants.md` + `integrations.md` (baseline webhook) + `risks.md` (baseline compliance, M6); temuan high → STOP." (Jangan taruh sebelum `(baseline webhook)` — bikin qualifier menggantung.) **Parent-doc completeness — perilaku nyata di `security-critic.md`/`ship/SKILL.md` (sudah di edit-map).** (Sisip frasa, bukan renumber.)
- §17 Rules (anchor `- **Rules:** `anti-yes-man.md` · `debt-aware.md` · `schema-projection.md` · `migration-impact.md``): tambah ` · `compliance-risk.md`` di akhir. (Separator ` · ` spasi-middot-spasi + backtick — ikuti gaya lokal.)

**TAK disentuh (eksplisit):** skill-count (tetap **21**), `plugin.json`, `marketplace.json`, README, induk §8 repo-tree **dir** `business/` (sudah collapsed — tak ada perubahan struktur dir; **TAPI baris `rules/` di §8 DISENTUH** — lihat edit-map di atas), §12 (lifecycle — tak ada fase baru), `render-docs`, `domain.md`/`flows.md`/`glossary.md`, `feature.yaml` schema / mekanik `sensitivity`, threshold Security Gate (high→RED tetap), M4 `rules/schema-projection.md`, H3 `rules/migration-impact.md`, brownfield `extract` (ditunda).

## 10. Verifikasi & bug-guard

**Grep-battery (post-exec):**
- V0 `plugin/template/control/business/risks.md` ADA + memuat 4 heading slot (`## PCI`, `## GDPR / Privasi`, `## Pajak`, `## KYC / AML`) + sentinel `<belum dinilai>` + placeholder `<PRODUCT>`. (Guidance/carve-out prosa diverifikasi by-read.)
- V0b `plugin/rules/compliance-risk.md` ADA + memuat klausa §5 (carve-out compliance-vs-HTML, advisory, anti-fiksi penulis-tunggal-discovery, degrade best-effort, generik). (By-read.)
- V1 `compliance-risk` rule direferensi `discovery` + `architect` + `intake` (idiom `${CLAUDE_PLUGIN_ROOT}/rules/compliance-risk.md`; ≥3 surface). (security-critic/ship rujuk `risks.md` langsung sebagai baseline — boleh tak rujuk file rule.)
- V2 `risks.md` direferensi `discovery/SKILL.md` (seed) + `discovery/reference.md` (§D carve-out) + `architect/SKILL.md` (step 4.5) + `intake/SKILL.md` (step 2/5/7) + `security-critic.md` (input+lensa) + `ship/SKILL.md` (step 4.5 baseline). (≥6 surface pembaca/penulis.)
- V3 `intake/SKILL.md` Challenge Checklist memuat baris compliance; step 7 memuat klausa perkuat-sensitivity.
- V4 `security-critic.md` memuat `risks.md` di baris input + langkah 1 + 1 lensa compliance.
- V5 skill-count tetap **21** di induk §17 (line 303) + tak ada edit `plugin.json`/`marketplace.json`/README.
- V6 induk **§17 Rules DAN §8 repo-tree rules** memuat `compliance-risk.md` (**5 file rules** di KEDUA tempat — disk saat ini 4: anti-yes-man/debt-aware/schema-projection/migration-impact) + §7 tree memuat baris `risks.md` + §9 ship gate (line ~210) memuat `risks.md`. (Cek dua listing rules biar tak stale.)
- V7 **anti-duplikasi (scope ke surface M6):** `risks.md` di-frame sebagai *constraint/baseline/input* (advisory), **bukan** pengganti `invariants.md` PII/PCI atau tag `sensitivity`. Cek hanya surface yang M6 tambah — bukan grep telanjang se-repo.
- V8 **anti-palang-keras:** klausa M6 di architect/intake/discovery berkata "advisory/constraint/perkuat/baca", bukan "blokir/STOP/gagal". Satu-satunya STOP = Security Gate `ship` existing (high→RED) — **tak diubah** ambangnya.
- V9 **carve-out utuh:** `discovery/reference.md` §D tetap melarang pasar/kompetitor/monetisasi/verdict masuk `business/`; cuma compliance yang carve-out. Risiko pasar **tak** ke `risks.md`.

**Bug-guard pre-bake (untuk plan):**
- **colon-space frontmatter:** M6 **tak** mengubah `description:` SKILL.md mana pun. **TAPI MENGUBAH `description:` `security-critic.md`** (edit-map §9 sub-4): tambah `risks.md` pakai separator `/` (`…/integrations.md/risks.md, tugasnya…`), **TANPA `: `**. Wajib cek pasca-edit `sed -n 's/^description: //p' plugin/agents/security-critic.md | grep ': '` tetap **kosong** (disk saat ini bersih). Skill lain: edit body, bukan description.
- **no-renumber:** semua sisipan = sub-line/sub-bullet/klausa/heading/baris-tree baru — **jangan** renumber step skill (architect 4.5, intake 2/5/7, ship 4.5, discovery 7, security-critic langkah 1/2 = sisip, bukan renumber). Verifikasi cross-ref "step N"/"langkah N" tetap nunjuk target benar.
- **mis-aimed-pointer:** verifikasi tiap `§X`/`reference §D`/`(lihat rule …)` nunjuk seksi benar — di rule, skill, agent, DAN spec ini. **Khusus induk:** ship-gate prose ada di **§9 (### ship, line ~210)** BUKAN §17; rules muncul di DUA tempat (§8 tree line 137 + §17 Rules line 305); tree business/ di §7. Edit-map before→after di §9 yang nge-quote teks-lama = dokumentasi, **bukan** pointer live.
- **`grep -Fc -e` anchor:** tiap find/replace diverifikasi verbatim SEBELUM commit (robust leading-dash `- `, metachar `[]`/`**`/backtick/`·`; awas middot `·` U+00B7 di §17 Rules/§7 tree vs em-dash `—` vs titik biasa — byte-trap).
- **dup-phrase scope:** anchor `control/business/*.md`/`risks.md`/`sensitivity` dicek unik per file target (mis. `risks.md` belum ada di disk pra-exec → match=0 expected untuk anchor file-baru; untuk MODIFY, scope grep ke file target). **`risiko`** kata umum — anchor §D via baris larat penuh, bukan kata `risiko` telanjang.
- **tree-alignment (§7 induk):** baris tree box-drawing `│`/`├`/`└`; kolom `#` parent **TAK rata** (domain=9 spasi, flows=10, glossary=7) → JANGAN "cermin" ambigu. **Target eksplisit:** anchor glossary = **7 spasi** sebelum `#` (verified match=1); baris baru `risks.md` = **10 spasi** sebelum `#` (samakan kolom `#` dgn glossary); ubah `└──`→`├──` pada glossary agar `risks.md` jadi anak terakhir. Verifikasi `grep -Fc -e` byte-eksak kedua baris pra-commit.
- **one-file-per-task:** plan satu task = satu file; tiap anchor diverifikasi vs file SEKARANG.
- **literal-scan sentinel:** token `<belum dinilai>` baru — pastikan tak nabrak scan literal skill lain (cermin `<belum dikunci>` invariants yang sudah aman); kata `risks`/`compliance` aman.

## 11. Hubungan

- **← `discovery` (penulis):** M6 mengaktifkan output compliance discovery yang selama ini dibuang (§D). Disentuh: §A (sub-prompt 4-kategori compliance, memperdalam riset Risiko), §D (carve-out melonggarkan utk compliance), SKILL step 7 (seed `risks.md`).
- **→ `invariants.md` (hilir architect):** `risks.md` = lanskap regulasi hulu yang **memberi makan** slot PII/PCI & Money saat `architect` mengunci invarian. Asimetri sengaja: `risks.md` (regulasi, di-seed discovery) → `invariants.md` (keputusan teknis, dikunci architect). **Bukan** duplikasi; arah hulu→hilir.
- **→ `sensitivity`/`intake` (hilir):** `risks.md` = **input** yang memperkuat heuristik usulan `sensitivity` per-fitur, bukan penggantinya. Heuristik teks existing tetap jalan tanpa `risks.md`.
- **→ Security Gate `ship` (hilir):** `risks.md` = **baseline** tambahan untuk `security-critic` (sejajar `invariants.md`/`integrations.md`). Ambang RED (high-sev) **tak berubah** & **tak ada gate baru** — tapi *himpunan* temuan yang ke-deteksi **melebar** (diff yang langgar kewajiban yg kini diketahui bisa jadi RED) → di seam ini M6 bukan murni advisory (lihat Catatan jujur §1). **Terbatas** ke fitur ber-`sensitivity` `payments`/`pii` (security-critic cuma di-invoke di situ).
- **vs M4/H3 (`control/schema/`, `migration-impact`):** ortogonal — M4/H3 = integritas skema/migrasi; M6 = compliance/regulasi. Pola arsitektur **dicermin** (durable file + shared rule + advisory + degrade), domain beda. Tak overlap.
- **vs Langkah-1 (security gate/`security-critic`):** M6 **memperkuat** lapis yang sama (security-critic dapat baseline compliance), **tak** menambah gate. Ortogonal ke invariants-lock (M6 = input ke lock, bukan lock baru).
- **Lifecycle:** tak ada fase baru. M6 = pengetahuan durable (`risks.md`) + kewaspadaan yang nempel di `discovery`/`architect`/`intake`/`ship`. Skill tetap **21**; rules **5** (4 existing + compliance-risk).
- **→ Langkah berikutnya:** M6 = kandidat quick-win Langkah-3. Sisa Langkah-3 (M1/M3/M7/M8/L1-3 + deferred, lihat handoff `2026-06-01-langkah-2-sisa-3.md` §4) + **live `/plugin install` end-to-end test** (belum pernah, semua fase — risiko tertua).
