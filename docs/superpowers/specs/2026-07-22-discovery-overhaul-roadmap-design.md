# Discovery Overhaul + Skill `/roadmap` — elicit-first, compliance conditional, jembatan konsep→backlog

> Asal: feedback operator pemakaian nyata (produk baru "sinyal trading crypto"). Tanggal: **2026-07-22**. Repo `~/Developer/project/context-vault`, base `main` @ `fb2c474`.
> Membayar defer M1 (`2026-06-06-m1-roadmap-epic-design.md` §FLAG — "skill roadmap penuh = DEFER"). Terkait spec induk `2026-05-24-ai-first-boilerplate-design.md` §12 (lifecycle — dapat 1 fase opsional baru).

## 1. Ringkasan

Empat keluhan lapangan atas jalur produk-baru: (1) **terlalu berurusan dengan hukum** — discovery menjalankan asesmen compliance terstruktur (PCI/GDPR/pajak/KYC) di tahap ide, untuk semua produk; (2) **terlalu cepat menyimpulkan** — tidak ada sesi Q&A produk, discovery lompat dari cerita-1-kalimat ke riset web ke verdict; (3) **sering miss dari maksud operator** — konsep diusulkan AI dari riset pasar, bukan digali dari visi operator; (4) **tidak ada gambaran fitur/flow & bingung mulai dari mana** — tidak ada lapisan yang mengubah konsep jadi backlog terurut (gap yang M1 sengaja defer; M1 cuma menanam metadata `epic`/`depends_on` tanpa sumber pengisinya).

Fix = tiga komponen: **(A)** rombak `/discovery` — step Q&A visi produk di depan (kontrak `elicitation.md`, yang selama ini justru tak di-wire ke discovery), prinsip MENYETIR dibelah (visi = operator nyetir; riset = AI nyetir), asesmen compliance jadi **conditional opt-in** (default skip); **(B)** skill baru **`/roadmap`** (ke-25) — pengampu artifact hidup `control/roadmap.md` (flow produk + backlog terurut), re-runnable untuk re-plan, posisi `init → roadmap → architect`, di-chain dari ujung discovery; **(C)** integrasi tipis `/feature` — baca `roadmap.md` bila ada: saran fitur berikutnya + prefill `epic`/`depends_on` (slot M1 akhirnya berisi otomatis). Semua degrade anggun: tanpa `roadmap.md` / tanpa discovery / `risks.md` skeleton → perilaku hari ini, nol blokir.

> **Catatan jujur (asumsi persona dikoreksi, bukan dibuang).** Desain discovery lama berasumsi "operator mungkin BUKAN orang produk/bisnis" → AI mengusulkan semuanya. Feedback membuktikan persona sebaliknya juga nyata (operator datang dengan visi terbentuk). Fix-nya bukan membalik asumsi, tapi **membelah per-ranah**: visi produk selalu digali dulu dari operator (jawaban "gak tau" → AI fallback mengusulkan, persona lama tetap terlayani); riset pasar/kompetitor tetap AI yang menyetir.

## 2. Masalah (akar per keluhan, file:line era `fb2c474`)

- **Hukum di tahap ide, unconditional.** `discovery/reference.md` §A (Risiko) mewajibkan asesmen terstruktur PCI · GDPR/privasi · pajak · KYC/AML + regulasi sektor untuk SEMUA produk, lalu seed `risks.md` (carve-out M6, `rules/compliance-risk.md`). Untuk ide fintech-adjacent (crypto signal) model menyelam ke regulasi sektor — terasa legal review, padahal operator baru mau ngobrolin produk.
- **Tidak ada kontrak Q&A di discovery.** `discovery/SKILL.md` step 1 = "cerita bebas → konfirmasi 1 kalimat", step 2 langsung riset→usulkan. `rules/elicitation.md` daftar perujuknya `intake, fanout, plan, tweak, fix` — discovery, satu-satunya skill elicitation murni, justru absen. Prinsip `reference.md` §A ("JANGAN tanya kosong ke operator") menyapu rata semua ranah.
- **Sumber kebenaran visi = 1 kalimat.** `template/control/business/domain.md` = 3 slot (Produk/Pengguna/Nilai); jalur init-langsung malah membiarkannya skeleton (init step 4: "Greenfield: biarkan business/ tetap skeleton"). Tak ada skill yang tugasnya memperdalam goal → AI mengisi gap dengan asumsi → miss.
- **Konsep → backlog tak punya lapisan.** Lifecycle: discovery (kelayakan bisnis, charter "NOL fitur") → init (1 kalimat + apps) → architect/wire (teknis) → `/feature <nama>` menunggu operator menyebut nama fitur sendiri. Spec M1 §2 sudah mengakui: *"Backlog ada cuma di kepala user"* — konsumen metadata (`epic`/`depends_on` + warn-gate) ditanam, sumber pengisinya di-defer. Feedback ini = tagihan defer itu jatuh tempo.

## 3. Tujuan & Non-Tujuan

**Tujuan**
- Discovery: step **Q&A visi produk** sebelum riset (kontrak `elicitation.md`); prinsip MENYETIR dibelah per-ranah di `reference.md` §A; compliance **conditional opt-in** (heuristik pemicu + SATU pertanyaan; skip → `risks.md` tetap skeleton); ujung skill menawarkan chain `/roadmap`.
- Skill baru **`/roadmap`** — penulis tunggal `control/roadmap.md` (flow produk + backlog terurut: fitur · tujuan 1-kalimat · epic · depends_on · target). Status fitur TIDAK disimpan (turunan `features/*/feature.yaml`). Re-runnable (re-plan). Posisi `init → roadmap → architect`, opsional.
- `/feature`: bila `roadmap.md` ada → saran fitur berikutnya (dipanggil tanpa nama) + prefill `epic`/`depends_on` dari baris roadmap (dipanggil dengan nama); fitur di luar roadmap → advisory, BUKAN palang.
- Registrasi lengkap (§8) + bump **0.22.0**.

**Non-Tujuan (anti-balon, seam bersih)**
- **BUKAN dependency-engine.** Warn 1-hop M1 tak berubah; tak ada topo-sort/cycle-detection/auto-ordering eksekusi.
- **`epic` tetap BUKAN entitas pertama-kelas.** Tak ada `control/epics/`, tak ada status epik/agregasi (posisi M1 D1 dipertahankan; roadmap.md = dokumen rencana, bukan registry entitas).
- **Tak ada auto-update `roadmap.md` dari `ship`/`drop`/`build`.** Body hanya ditulis `/roadmap`; status selalu derived — nol dual-write, nol penulis kedua.
- **`render-docs`/`ask` tak WAJIB berubah.** `ask` sudah membaca `control/` menyeluruh (nol edit); roadmap-view di `render-docs` = kosmetik bila trivial, selebihnya §FLAG.
- **Tak sentuh** `breakdown`/`build`/`ship`/`debt`/`fix`/`fanout`/`plan`/`wire`/`architect`/`upgrade` (roadmap.md bukan file template → `upgrade` nol churn).
- **Charter discovery tetap: NOL teknis, NOL fitur.** Fitur kini resmi jatah `/roadmap` — pemisahan malah makin tegas.
- **M6 tidak dibongkar.** `risks.md`, pembaca (`architect`/`intake`/`ship`/`security-critic`), dan degrade-best-effort-nya utuh; yang berubah cuma: penulisan seed jadi kondisional.

## 4. Komponen A — rombak `/discovery`

Urutan step baru (SKILL.md ditulis ulang bagian Langkah):

1. **Tangkap ide mentah** (tetap) — cerita bebas + konfirmasi 1 kalimat.
2. **★ Q&A visi produk (BARU)** — ikuti `rules/elicitation.md` (satu keputusan-bercabang per giliran, opsi bawa konsekuensi, selalu ada "ceritain versimu"). Gali dari operator: masalah versi dia · siapa penggunanya menurut dia · hasil/nilai yang diincar · batasan/keharusan yang sudah ia tetapkan · gambaran sukses. **Riset web DILARANG di step ini.** Operator menjawab "gak tau/terserah" pada suatu slot → tandai slot itu `AI-usul`, dijawab di step 3 (fallback persona lama).
3. **Riset validasi + kembangkan konsep** (ex-step 2) — per seksi `reference.md` §A, AI menyetir riset (pasar/kompetitor/monetisasi), tapi tiap usulan **diikat balik ke jawaban visi step 2**; riset bertentangan dengan visi → tunjukkan bukti, operator yang putuskan (jangan diam-diam menimpa). Aturan sitasi §B + label §C tetap WAJIB.
4. **Risiko + compliance conditional** — risiko bisnis (pasar jenuh, switching cost, eksekusi berat) tetap untuk semua produk. **Asesmen compliance terstruktur** (PCI/GDPR/pajak/KYC + sektor) hanya bila ide kena heuristik pemicu — menggerakkan/menyimpan uang · PII berat (gov-id/kesehatan/finansial) · sektor regulated (keuangan, kesehatan, pendidikan-anak, dst.) — dan itu pun lewat **SATU pertanyaan opt-in**: "produk ini kena sinyal <X> — mau kucek kewajiban regulasinya sekali jalan?". Default/decline → skip; seksi Risiko HTML memuat baris "compliance: dilewati atas pilihan operator".
5–8. **Draft strategis → critic (GATE) → render HTML → review loop SEPAKAT** — tetap seperti sekarang (critic + sitasi + label = penjaga anti-halu, bukan sumber keluhan).
9. **Sepakat → init + seed + tawaran `/roadmap`** — seperti step 7 lama, dengan dua perubahan: seed `risks.md` **hanya bila asesmen compliance dijalankan** (skip → skeleton, jalur degrade M6 yang memang ada); setelah init selesai, **tawarkan chain `/roadmap`** ("konteks lagi hangat — lanjut susun backlog?") sebelum saran `architect`.

Perubahan file pendamping:
- `discovery/reference.md` — §A ditambah seksi **"Visi (dari operator)"** paling atas (slot-slot step 2); prinsip pembuka dibelah: *"Visi produk: operator menyetir, AI menggali & merekam. Riset pasar: AI menyetir, operator memutuskan."*; seksi Risiko dapat klausa conditional + heuristik pemicu; §D seed `risks.md` diberi prasyarat "bila asesmen dijalankan".
- `rules/elicitation.md` — daftar perujuk: + `discovery` (step 2), + `roadmap`.
- `rules/compliance-risk.md` — "Penulis tunggal = discovery" tetap, ditambah: *"penulisan kondisional (opt-in operator); `risks.md` skeleton = jalur normal, bukan anomali — pembaca pakai degrade-best-effort existing."*

## 5. Komponen B — skill baru `/roadmap`

**Charter:** pengampu jembatan konsep→backlog. Level bisnis murni (NOL teknis — stack jatah `architect`). Jalankan dari root produk ber-`control/`. Dipanggil: (a) chain dari ujung discovery, (b) standalone pasca-init, (c) re-run kapan pun untuk re-plan.

**Langkah:**
1. **Baca konteks** — `workspace.yaml`, `business/*.md`, `control/docs/discovery.html` (bila ada), `features/*/feature.yaml` (status nyata), `control/feedback/` (bila ada — sinyal lapangan sebagai input SOFT, cermin intake M8), `roadmap.md` existing (bila re-run).
2. **Q&A visi & backlog** — ikuti `elicitation.md`. Urutan gali: flow pengguna inti (happy-path dari daftar → dapat nilai) → kandidat fitur (AI mengusulkan daftar DARI flow itu, operator koreksi/tambah/coret) → mana MVP vs nanti → urutan & dependency antar-fitur. Re-run → diff-oriented ("sejak roadmap terakhir: 2 shipped, feedback X masuk — apa yang berubah?"), bukan interogasi ulang dari nol.
3. **Draft + gate (GATE)** — tampilkan draft `roadmap.md` utuh → approve/koreksi; JANGAN tulis sebelum sepakat. Run pertama produk / perombakan besar → invoke subagent `critic` atas draft (fitur bolong? urutan janggal? dependency mustahil?) dan tanggapi tiap keberatan bersama operator (cermin gate intake step 6).
4. **Tulis + promote** — tulis `control/roadmap.md`; promote durable secara **idempotent** (cermin intake step 7): flow produk → `business/flows.md`; pengguna/nilai yang tergali → `business/domain.md` (slot Produk/Pengguna/Nilai diperkaya dari 3-baris-tipis).
5. **Handoff** — saran fitur pertama yang belum shipped: "`/feature <fitur#1>`?". Bila di-chain dari discovery → sebut lanjutan `architect` → `wire` dulu (skeleton belum ada).

**Artifact `control/roadmap.md`** (bukan file template — lahir saat skill jalan; penulis tunggal `/roadmap`):

```markdown
# <PRODUCT> — Roadmap
> Ditulis skill roadmap. Status fitur TIDAK disimpan di sini — turunan control/features/*/feature.yaml.

## Flow produk
<jalur pengguna inti, berurutan: daftar → … → dapat nilai>

## Backlog terurut
| # | Fitur | Tujuan | Epic | depends_on | Target |
|---|-------|--------|------|------------|--------|

## Catatan prioritas
<alasan urutan/penundaan — opsional>
```

`Target` = label bebas (`MVP`/`v1.1`/`nanti`) — bukan enum, bukan mesin rilis. Nama fitur di tabel = calon nama folder `features/<fitur>/` (kebab-case).

## 6. Komponen C — integrasi tipis `/feature` (+1 kalimat intake)

- `feature/SKILL.md` step 1: **sebelum** membuat folder — bila dipanggil TANPA nama & `roadmap.md` ada → tampilkan backlog + status derived, sarankan fitur berikutnya yang belum shipped (operator tetap bebas milih lain). Bila dipanggil DENGAN nama: nama ada di roadmap → prefill `epic`/`depends_on` `feature.yaml` dari baris roadmap (operator konfirmasi di gate intake seperti biasa); tidak ada di roadmap → catatan advisory *"tak tercatat di roadmap — lanjut saja; re-run `/roadmap` bila mau dicatat"* lalu jalan normal. `roadmap.md` absen → step 1 persis hari ini (degrade diam).
- `intake/SKILL.md` step 4 (sizing-check): +1 kalimat — bila usul pecah-epik diterima & `roadmap.md` ada → sarankan re-run `/roadmap` agar pecahannya tercatat (advisory).
- Jalur intake-dipanggil-langsung (tanpa via feature): TIDAK diubah — default `epic: ""`/`depends_on: []` seperti sekarang (prefill cuma di seam feature; diakui sebagai batas sadar, bukan bug).

## 7. Decisions (fork + alternatif ditolak)

### D1. Compliance discovery = conditional opt-in — BUKAN take-out total, BUKAN demote-1-paragraf. *(keputusan operator)*
Take-out total ditolak: produk regulated beneran baru tahu kewajibannya di ship — telat bila kewajiban merombak desain; investasi M6 terbuang. Demote ditolak: tetap muncul tiap run — keluhannya soal keberadaan di produk non-regulated, bukan porsinya. Conditional = kasus umum bersih (1 pertanyaan, skip), jalur regulated tetap ada, degrade M6 existing menampung skeleton tanpa sentuhan pembaca.

### D2. Rumah jembatan = skill baru `/roadmap` — BUKAN seksi discovery, BUKAN perluasan init. *(keputusan operator)*
Alasan inti: **backlog = artifact hidup, dan artifact hidup di plugin ini selalu punya skill pengampu** (`debt.yaml`←`/debt`, `integrations.md`←`add-integration`, `design-system.md`←`design-system`). Discovery & init dua-duanya one-shot (discovery malah pra-init, syarat folder-kosong — mustahil re-run buat re-plan) → backlog numpang di sana = yatim sejak lahir + produk tanpa-discovery tetap kena gap. Keunggulan "konteks hangat" opsi-discovery tidak hilang: discovery nge-chain ke `/roadmap` (persis pola chain ke `init`).

### D3. `roadmap.md` markdown — BUKAN `roadmap.yaml`.
Konsisten `business/*.md` (dokumen dibaca manusia+AI, bukan config mesin); tabel md cukup ter-parse untuk prefill (konsumennya LLM-skill, bukan parser kaku); rumah mesin `epic`/`depends_on` tetap `feature.yaml` (YAML) — md = rencana, yaml = state. Alternatif yaml ditolak: menggandakan rumah state → godaan dual-write.

### D4. Status fitur derived — TIDAK disimpan di roadmap.md.
Disimpan = dual-write (ship/drop harus ikut menulis roadmap) → drift pasti. Derived dari `features/*/feature.yaml` = satu sumber, pembaca (`feature` step 1, `ask`) merakit pandangan saat baca. Konsekuensi sadar: baca-roadmap perlu glob kecil feature.yaml — murah.

### D5. Bukan file template & `upgrade` nol churn.
`roadmap.md` lahir via skill (cermin `features/`, `debt.yaml`), bukan `template/control/` (cermin-tandingan `integrations.md` yang memang template). Alasan: file skeleton kosong tanpa skill yang mengisinya = kebisingan; degrade pembaca sudah menangani absen. Efek: produk lama tak butuh `upgrade` untuk adopsi — panggil `/roadmap` kapan pun.

### D6. Posisi lifecycle `init → roadmap → architect`, opsional — BUKAN wajib, BUKAN sesudah wire.
Sebelum architect karena peta fitur menajamkan keputusan stack/capabilities (notif realtime → sinyal websocket). Opsional karena produk brownfield/eksperimen kecil sah tanpa roadmap (degrade). Ditolak "sesudah wire": rencana bisnis tak butuh skeleton; makin awal makin murah koreksi.

### D7. Prinsip MENYETIR dibelah per-ranah — BUKAN dibalik total.
Membalik ("selalu interview") mematahkan persona operator-bukan-orang-bisnis yang jadi alasan desain lama. Belahan: visi = operator (fallback `AI-usul` per-slot bila "gak tau"), riset = AI. Dua persona terlayani satu mekanisme.

### D8. Q&A visi = step baru discovery — BUKAN skill terpisah "product-brief".
Skill terpisah = balon (skill ke-26 yang selalu jalan bareng discovery). Visi memang bahan bakar riset discovery — satu atap; jembatan fitur yang butuh rumah sendiri (D2), bukan visinya.

## 8. Churn registrasi (mekanis, sekali bayar)

1. `plugin/skills/roadmap/SKILL.md` — baru (single-file; framework Q&A kecil, tak butuh reference.md).
2. `plugin/skills/discovery/SKILL.md` + `reference.md` — rombak §4.
3. `plugin/rules/elicitation.md` + `rules/compliance-risk.md` — klausa §4.
4. `plugin/skills/feature/SKILL.md` + `intake/SKILL.md` — integrasi §6.
5. `plugin/.claude-plugin/plugin.json` — description + `0.22.0`; `.claude-plugin/marketplace.json` — description.
6. `README.md` root — seksi skill + lifecycle + ritual rilis; `plugin/skills/guide/reference.md` — cheatsheet + peta pipeline (baris `init → roadmap? → architect`).
6b. `plugin/hooks/auto-title.sh` — whitelist skill kerja (case-list hardcoded) + `|roadmap` — temuan implementasi 2026-07-22; roadmap = skill kerja, wajib ikut judul session.
7. Regen `plugin-kimi/` via `tools/build-kimi.sh` (skills ter-copy utuh — roadmap ikut otomatis; verifikasi hitungan skill di output).
8. Spec induk §12 TIDAK diedit — spec ini = addendum (pola addendum kimi `72ec743`).

## 9. Degrade & kompatibilitas

- `roadmap.md` absen → `feature`/`ask` persis hari ini (advisory/saran tak muncul). JANGAN error, JANGAN nyuruh-nyuruh bikin.
- Produk tanpa discovery → `/roadmap` tetap jalan (domain.md tipis justru diperkaya step 4-nya).
- `risks.md` skeleton (compliance di-skip) → pembaca M6 best-effort — mekanisme yang SUDAH ada (`compliance-risk.md` Degrade), bukan jalur baru.
- Produk lama pre-0.22 → nol migrasi; semua penambahan presence-based.
- Dangling: fitur di roadmap yang di-`drop` → tampak dari status derived (`dropped`); baris roadmap basi dibereskan re-run `/roadmap` (bukan mesin di `drop` — cermin M1 non-tujuan).

## 10. Acceptance (walkthrough)

1. **Greenfield via discovery (kasus keluhan):** ide "sinyal trading crypto" → step 2 menggali visi ≥3 giliran SEBELUM riset apa pun; step 4 memicu heuristik sektor-finansial → SATU pertanyaan compliance → operator skip → `risks.md` skeleton, tanpa selaman regulasi; verdict tetap bersitasi; init → tawaran chain `/roadmap` → `roadmap.md` lahir ber-backlog terurut.
2. **Konsumsi:** `/feature` tanpa nama → saran `auth-onboarding`; `/feature watchlist` → `feature.yaml` ter-prefill `epic: fondasi`, `depends_on: [auth-onboarding]`; warn-gate M1 berbunyi bila dep belum shipped (mesin lama, kini berbahan-bakar).
3. **Re-plan:** 2 fitur shipped + feedback masuk → re-run `/roadmap` → Q&A diff-oriented → tabel ter-update; status tetap derived (tak ada kolom status tertulis).
4. **Degrade:** produk tanpa `roadmap.md` → `/feature` normal; produk lama → nol keharusan.

## FLAG (defer eksplisit)

- Roadmap-view di `render-docs` (halaman HTML backlog) — kosmetik bila trivial, selebihnya spec terpisah.
- Dependency-engine (topo-sort/cycle/auto-order) — tetap defer M1.
- Prefill `epic`/`depends_on` di jalur intake-langsung — batas sadar §6; angkat bila kepakai nyata.
