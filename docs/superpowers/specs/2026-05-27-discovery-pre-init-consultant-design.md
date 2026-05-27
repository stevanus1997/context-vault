# discovery — Pre-Init Business Consultant (Design Spec)

- **Tanggal:** 2026-05-27
- **Status:** Draft disetujui untuk masuk tahap perencanaan implementasi
- **Repo:** https://github.com/stevanus1997/context-vault
- **Memperluas:** `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`

---

## 1. Ringkasan

`discovery` adalah skill **pra-`init`** yang berperan sebagai *business consultant*: mengubah ide produk yang masih mentah menjadi konsep produk yang tervalidasi — sebelum satu baris kode pun (atau bahkan `control/`) ada. Outputnya **dua**: (a) fakta produk durable yang di-*seed* ke `control/business/`, dan (b) dokumen strategis HTML standalone yang enak dibaca orang awam.

Skill ini menutup lubang di alur existing. `init` mengasumsikan operator sudah datang dengan minimal satu kalimat "ngapain & buat siapa", dan `intake` mendalami bisnis **per-fitur** (butuh `business/` sudah terisi). Tidak ada yang menangani level *strategi/konsep seluruh produk* dari ide mentah. `discovery` mengisi itu.

## 2. Masalah yang Diselesaikan

- **Ide mentah tidak punya rumah.** Alur sekarang mulai dari asumsi "produk sudah jelas". Operator yang baru punya ide kasar tidak punya langkah untuk menjawab: ini produk apa, buat siapa, layak dibangun atau tidak.
- **Operator belum tentu orang produk/bisnis.** Solo dev (apalagi yang teknis) sering tidak punya kacamata produk/pasar. Wawancara pasif ("siapa kompetitor lo?") gagal — operator memang tidak tahu. Yang dibutuhkan: AI yang **menyetir** analisis bisnis, bukan sekadar mentranskrip jawaban.
- **`business/` mulai kosong.** Setelah `init`, `business/` cuma placeholder; fitur-fitur pertama yang di-`intake` mulai dari nol. `discovery` membuat otak produk non-kosong sejak hari pertama.

## 3. Tujuan & Non-Tujuan

**Tujuan:**
- Dari ide mentah → konsep produk tervalidasi (level **strategi**, bukan fitur).
- Analisis bisnis "berat" yang **disetir AI + berbasis riset web nyata**: kompetitor, pasar, monetisasi, risiko, verdict go/no-go.
- Anti-halusinasi struktural (riset → sitasi+label → `critic`) karena operator tidak bisa mengecek klaim bisnis sendiri.
- Output ganda yang **nyambung ke sistem**: seed `business/` + HTML standalone.
- Handoff mulus ke `init`.

**Non-Tujuan:**
- **Nol teknis** — stack/arsitektur tetap jatah `architect`/`plan`.
- **Bukan level fitur** — itu `intake`. `discovery` berhenti di konsep produk.
- **Bukan untuk brownfield berkode** — produk dengan kode existing pakai `extract`. `discovery` untuk tahap-ide/greenfield.
- **Bukan generator dokumen investor formal** (proyeksi keuangan mendetail, cap table, dll) — fokus ke validasi konsep + viability.

## 4. Konsep Inti

- **AI menyetir, bukan mewawancara.** Operator mungkin bukan orang bisnis; `discovery` proaktif mengusulkan kompetitor, segmen, model monetisasi, lalu menjelaskan *kenapa*-nya — bukan menuntut operator yang menyediakan.
- **Tiga saringan anti-halusinasi (bertumpuk).** Riset web (lawan ngarang total) → sitasi + label keyakinan (bikin sisa risiko keliatan) → `critic` (serang logika/sumber/bias). Tidak ada yang sempurna; ditumpuk baru cukup rendah — tapi **tidak pernah nol**, jadi verdict selalu berbentuk *"ini alasan + sumber, operator yang putuskan"*, bukan *"percaya saya"*.
- **HTML = superset, `business/` = subset durable.** Dokumen strategis memuat semua (termasuk analisis pasar); hanya fakta produk yang **durable & cukup yakin** yang nyebrang ke `business/` (konservatif, niru `intake`) supaya `business/` tidak terkotori spekulasi pasar.
- **Output nyambung, bukan yatim.** Kerja `discovery` jadi bahan bakar `init` + `intake` berikutnya, bukan dokumen mati.

## 5. Penempatan & Alur

- **Nama (tentatif):** `discovery`. **Kapan:** paling awal, dari ide mentah, sebelum `init`. **Scope:** produk baru / tahap-ide.
- **Pola:** satu skill utuh, langkah bernomor + GATE, `critic` sebagai step internal (persis `intake`/`extract`) — bukan konduktor.

| # | Langkah | Inti | Gate |
|---|---------|------|------|
| 1 | **Tangkap ide mentah** | Rekam ide operator dalam kata-katanya sebagai bibit. | — |
| 2 | **Riset + kembangkan konsep** *(loop)* | AI menyetir: riset web → usulkan segmen, kompetitor, pasar, monetisasi. Tiap klaim **wajib sitasi + label** (terverifikasi/asumsi/spekulatif). | — |
| 3 | **Susun draft dok strategis** | Masalah · pengguna/segmen · value prop · pasar · kompetitor · monetisasi · risiko. | — |
| 4 | **`critic`** | Serang: cherry-pick? sumber lemah? lompatan logika? → verdict go/no-go jujur. Tanggapi tiap keberatan sebelum lanjut. | **GATE** |
| 5 | **Render HTML** | Reuse aset `template.html` → dok standalone enak dibaca awam. | — |
| 6 | **Review loop** | Operator baca HTML → feedback → balik ke langkah 2/3 → regen. Ulang **sampai sepakat**. | **GATE** |
| 7 | **Sepakat → `init` + seed** | Panggil `init` (framing sudah ada), seed `business/`, finalize HTML ke `control/docs/`. Saran lanjut: `architect`. | **GATE** |

Inti loop ada di langkah 2–3–4–5 sampai konsepnya mateng; langkah 4 & 6 dua gate utamanya (critic menantang sebelum apa pun diterima; operator yang pegang kendali kapan "sepakat").

## 6. Tiga Saringan Anti-Halusinasi

Riset web **mengurangi** halusinasi, tidak **menghapus**. Ia memindahkan risiko dari "ngarang total" → ke "salah tafsir, data basi, bias, sintesis ngawur". Maka tiga saringan bertumpuk:

| Saringan | Melawan | Sisa risiko yang lolos |
|----------|---------|------------------------|
| Riset web | ngarang total | salah tafsir, data basi, cherry-pick |
| Sitasi + label keyakinan | sisa risiko tak terlihat | logika & bias di verdict |
| `critic` | logika/sumber lemah/cherry-pick | tinggal keputusan manusia |

- Setiap klaim faktual **wajib menempel sumber**; tanpa sumber → otomatis dicap "asumsi/spekulatif".
- **Label keyakinan 3-tingkat:** `terverifikasi` (sumber kuat) · `asumsi` (nalar wajar, belum tervalidasi) · `spekulatif` (tebakan, perlu konfirmasi).
- Hanya yang **terverifikasi & durable** yang boleh nyebrang ke `business/`. Asumsi/spekulatif tinggal di HTML.

## 7. Output: HTML vs `business/`

HTML adalah **superset**; `business/` mengambil **subset durable**.

| Konten | Masuk ke |
|--------|----------|
| Masalah · value · pengguna/segmen | HTML **+** seed `domain.md` |
| Aturan domain awal (yang sudah jelas & terverifikasi) | HTML **+** seed `domain.md` (`## Aturan Domain`) |
| Istilah | HTML **+** seed `glossary.md` |
| Flow kunci (kalau sudah kebayang) | HTML **+** seed `flows.md` |
| Pasar · kompetitor · monetisasi · risiko · verdict | **HTML saja** |

Aturan promosi **konservatif** (niru `intake`): hanya fakta durable & cukup yakin yang nyebrang; spekulasi pasar tidak pernah masuk `business/`.

## 8. Integrasi dengan `init`

Urutan langkah 7:

```
sepakat
 └→ discovery PANGGIL init  (framing sudah ada: nama + 1-liner + apps)
      └→ init: deteksi topologi (GATE) → scaffold control/ → workspace.yaml + CLAUDE.md
              [SKIP Q&A framing-nya — colekan di init]
 └→ balik ke discovery: control/business/ sudah ada (masih placeholder)
      └→ SEED fakta durable → domain.md / glossary.md / flows.md
      └→ finalize HTML → control/docs/discovery.html
 └→ GATE ringkas → saran lanjut: architect
```

**Colekan di `init`:** skill = instruksi untuk AI, bukan kode — jadi "handoff" sebenarnya: AI yang menjalankan `discovery` sudah memegang nama + 1-liner, lalu saat lanjut ke `init` tinggal dipakai. Yang ditambahkan ke `init` cukup **satu klausa** di langkah 3 (Framing Q&A): *"kalau framing sudah tersedia (mis. dari `discovery`), pakai itu — skip nanya, cukup konfirmasi ringkas."* Tidak merusak `init` dipakai sendiri (tanpa framing → nanya seperti biasa).

## 9. File & Lokasi

- **Selama loop review (sebelum `init`):** `control/` belum ada, jadi draft HTML numpang di root folder produk (mis. `./discovery-draft.html`).
- **Setelah sepakat + `init`:** HTML final dipindah ke `control/docs/discovery.html`.
- **Seed `business/`:** `domain.md` (Produk/Pengguna/Nilai + Aturan Domain awal), `glossary.md` (istilah), `flows.md` (flow kunci).

## 10. Dibangun vs Dipakai Ulang

- **Reuse:** `critic` (langkah 4) · aset `template.html` (langkah 5) · `init` (langkah 7).
- **Baru:** `plugin/skills/discovery/SKILL.md` (orkestrasi) + 1 file aset (framework pertanyaan konsultan + aturan sitasi/label + struktur seksi HTML) supaya SKILL.md tetap ramping.
- **Disenggol:** 1 klausa di `plugin/skills/init/SKILL.md` (skip framing kalau sudah ada) · update `README.md`.

## 11. Open Questions (untuk dipertimbangkan saat implementasi)

- **Nama final** skill: `discovery` vs `consult`/`vet`/`pitch`.
- **Mekanisme render HTML:** `render-docs` membaca `control/` dan menulis `control/docs/site/index.html` — tidak pas dipakai `discovery` karena (a) `control/` belum ada saat loop, (b) kontennya strategis, bukan dump knowledge `control/`. Kemungkinan `discovery` punya render sendiri yang **reuse aset `template.html`**, bukan memanggil skill `render-docs`. Konfirmasi saat implementasi.
- **Live preview vs file statis:** apakah draft HTML perlu di-serve live (seperti pola `.superpowers/brainstorm/`) atau cukup file statis yang dibuka manual.
- **Tool riset web:** WebSearch bawaan vs skill `firecrawl` yang tersedia di environment — dan bagaimana sitasi disimpan/ditampilkan di HTML.
- **Kedalaman seed:** sejauh mana `discovery` boleh menulis `## Aturan Domain` awal vs membiarkannya tumbuh lewat `intake`.
