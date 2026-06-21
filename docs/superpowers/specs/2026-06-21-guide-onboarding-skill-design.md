# context-vault — Skill `guide`: Onboarding & Q&A Plugin (read-only) (Design Spec)

- **Tanggal:** 2026-06-21
- **Status:** Draft disetujui untuk masuk tahap perencanaan implementasi (hasil brainstorming, semua keputusan perilaku terkunci)
- **Terkait:** spec induk `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`; `plugin/skills/ask/SKILL.md` (cermin: `ask` = scope **produk** read-only, dan Non-Tujuan-nya eksplisit menolak menjawab metodologi plugin — `guide` mengisi sisi itu); `README.md` & `plugin/.claude-plugin/plugin.json` (titik discoverability yang disentuh saat rollout).

---

## 1. Ringkasan

context-vault punya **~24 skill** yang menutup lifecycle penuh produk multi-app (`discovery → init → architect → wire → feature → breakdown → build → ship` + lane samping `fix`/`tweak`/`debt`/`ask` + scaffolding `add-app`/`add-package`/`add-integration`/`design-system` + `render-docs`/`extract`/`upgrade`/`drop`). Knowledge-nya lengkap di README & frontmatter tiap skill — **tapi padat**. User yang baru install (dan "males baca README") tak punya **satu pintu masuk** untuk ngerti "ada skill apa aja, flow-nya gimana, mulai dari mana".

Spec ini menambah **satu skill baru, `guide`** — **panduan plugin, 100% read-only**. Ia melakukan dua hal lewat satu trigger:
1. **Tur orientasi progresif** (tanpa argumen): kenalin context-vault, peta flow, cheatsheet, katalog skill — bertahap, bukan wall-of-text.
2. **Q&A soal plugin** (dengan argumen): jawab "skill X itu apa", "kapan pakai Y", "bedanya `/fix` & `/tweak`", "abis `/init` ngapain".

Prinsip inti: **satu pintu-paham plugin, nol tulisan, nol sentuhan produk.** `guide` adalah cermin `ask` — kalau `ask` menjawab tentang **produk** (`control/` + kode), `guide` menjawab tentang **plugin** (skill, flow, metodologi).

## 2. Masalah

- **M1 — Tak ada pintu masuk plugin.** User baru lihat ~24 command tanpa tahu urutan, ketergantungan, atau titik mulai. README menjawabnya tapi mensyaratkan baca dokumen panjang — friksi onboarding tinggi, persis keluhan lapangan.
- **M2 — `ask` sengaja menolak.** `ask/SKILL.md` (Non-Tujuan) eksplisit: scope = produk, **bukan** metodologi plugin; pertanyaan "skill apa saja" diarahkan keluar tanpa ada tujuan rute. Jadi ada pertanyaan yang **tak punya rumah**.
- **M3 — Drift dokumen orientasi.** README & plugin.json di-update manual tiap rilis; sudah padat & rawan basi. Onboarding yang murni mengandalkan teks statis bakal makin lama makin meleset dari skill yang sebenarnya ada.
- **M4 — Discoverability.** Bahkan kalau skill panduan ada, user "males baca" harus bisa **menebak** trigger-nya. Tanpa pointer di titik paling awal (marketplace/README/`/help` mental-model), skill-nya tak ketemu.

Akar: sistem punya banyak penulis-knowledge **produk** dan satu pembaca-produk (`ask`), tapi **nol pemandu-plugin**. Nilai 24 skill hilang kalau pintu masuknya curam.

## 3. Tujuan & Non-Tujuan

**Tujuan:**
- **Satu skill `guide`** sebagai pintu masuk tunggal untuk **memahami plugin** — tur orientasi + Q&A.
- **Mode tanpa-argumen = tur progresif** (§4.1): potongan singkat dulu → tawarkan dalami bagian tertentu; tidak menumpahkan semua sekaligus.
- **Mode dengan-argumen = Q&A plugin** (§4.2): jawab pertanyaan apa pun tentang skill/flow/metodologi context-vault.
- **Sumber hybrid** (§5): cheatsheet/peta/katalog **baked** di `reference.md` (instan, terkurasi) + **baca `SKILL.md` asli on-demand** untuk detail (akurat dari sumber, tahan drift).
- **Anti-drift ringan** (§5): "skill apa yang ADA" diturunkan dari listing folder skill tetangga (`ls ../`), bukan dipercaya buta dari katalog baked.
- **Read-only mutlak** (§6): tak pernah Write/Edit, tak menyentuh `control/` maupun kode produk. Satu-satunya efek = teks jawaban + pointer command.
- **Cermin `ask`** (§6): pertanyaan tentang **produk** user ("fitur gw apa aja", "status produk") → diarahkan ke `/ask`, tidak dijawab oleh `guide`.
- **Discoverability** (§7): README + plugin.json menunjuk `/guide` sebagai pintu masuk.

**Non-Tujuan (v1):**
- **Tidak deteksi state produk.** `guide` tak membaca `control/`/`workspace.yaml`, tak personalisasi "next step" berdasar fase produk. (Diputuskan: *pure guide, plugin-only*.) Jalan walau user belum punya produk apa pun.
- **Tidak menjalankan skill lain.** Hanya memberi pointer command (`/init`, `/feature`, …); user yang mengetik. Konsisten "pure guide".
- **Tidak menulis apa pun** — tidak `control/`, tidak kode, tidak file plugin. (Rollout README/plugin.json di §7 dikerjakan **sekali saat implementasi**, bukan perilaku runtime `guide`.)
- **Bukan AMA produk** — itu `ask`. `guide` tak menjawab "auth produk gw apa".
- **Bukan generator dokumen** — itu `render-docs`.
- **Tidak ada index/RAG/histori percakapan** — penjawaban via baked reference + baca-file terarah; stateless per pemanggilan.

## 4. Perilaku — Dua Mode

Trigger: `/guide` (tur) · `/guide <pertanyaan>` (Q&A). Deteksi mode = ada/tidaknya argumen bermakna.

### 4.1 Mode tur (tanpa argumen) — PROGRESIF

Tujuan: orientasi yang **scannable**, bukan dump 24 skill. Alur bertahap:

1. **Sapaan + 1 paragraf "apa itu context-vault"** — lapisan AI + knowledge (bukan kode) untuk mengelola produk multi-app dengan Claude Code.
2. **Peta flow ringkas** (1 diagram baris): `discovery → init → architect → wire → feature → breakdown → build → ship`, plus sebut lane samping (`fix`/`tweak`/`debt`/`ask`) dalam satu kalimat.
3. **Cheatsheet inti** — tabel pendek "mau X → pakai `/Y`" untuk aksi paling umum (mulai produk, bikin fitur, ada bug, perubahan kecil, tanya produk).
4. **Titik mulai eksplisit** — `/discovery` (ide masih mentah) atau `/init` (sudah jelas / brownfield).
5. **Tawaran dalami** (inti "progresif"): tutup dengan menu pilihan, mis. *"Mau gw dalemin yang mana? (1) pipeline fitur detail (2) lane samping fix/tweak/debt (3) scaffolding add-app/package/integration/design-system (4) docs & maintenance (5) tanya bebas"* — baru ekspansi bagian yang dipilih di giliran berikutnya.

Aturan progresif: **jangan** cetak seluruh katalog skill + deskripsi panjang di langkah pertama. Langkah 1–4 muat dalam layar; detail per-grup dikeluarkan **on-demand** lewat langkah 5.

### 4.2 Mode Q&A (dengan argumen)

Tiap pertanyaan tentang plugin:

1. **Cek boundary dulu** — kalau pertanyaan sebenarnya tentang **produk** user (status, fitur yang sudah jalan, auth produk, isi `control/`) → arahkan ke `/ask` dan berhenti (jangan dijawab sebagai guide).
2. **Jawab dari baked** (`reference.md`) untuk pertanyaan peta/cheatsheet/"kapan pakai apa"/perbandingan — instan & seragam.
3. **Drill on-demand** untuk pertanyaan dalam tentang **satu skill tertentu** ("`/build` detailnya gimana", "`/fanout` ngapain persisnya") → baca `../<skill>/SKILL.md` relatif ke folder `guide` sendiri, jawab dari sumber asli. (Path relatif → jalan di repo dev **dan** di cache plugin user.)
4. **Perbandingan** ("`/fix` vs `/tweak`", "`/feature` vs `/tweak`") → pakai tabel keputusan baked; bila perlu nuansa, baca dua `SKILL.md`.
5. **Anti-ngarang** — di luar pengetahuan plugin → bilang terus terang + arahkan; jangan menebak (selaras `rules/anti-yes-man.md`).

## 5. Sumber Konten — Hybrid + Anti-Drift Ringan

- **`reference.md` (baked, terkurasi):**
  - Peta flow lengkap (greenfield ide-mentah / greenfield ide-jelas / brownfield).
  - Tabel keputusan "kapan pakai apa" (termasuk `feature` vs `fix` vs `tweak`, `ask` vs `guide`, `add-app`/`add-package`/`add-integration`).
  - Katalog skill dikelompokkan (pipeline utama / lane samping / scaffolding / docs & maintenance) — **1-liner** per skill (diturunkan dari frontmatter `description` masing-masing, dijaga ringkas).
- **Drill on-demand:** untuk detail satu skill, baca `SKILL.md` asli sibling — selalu akurat dari sumber, tak perlu menduplikasi isi panjang ke `reference.md`.
- **Anti-drift ringan:** saat menampilkan katalog, "skill apa yang ADA" = listing folder `../*/` (sumber kebenaran), bukan dipercaya buta dari `reference.md`. `reference.md` menyediakan 1-liner terpoles; jika ada folder skill **tanpa** entri di katalog, `guide` menyebutnya apa adanya ("ada skill `X` yang belum ada ringkasannya — ketik `/guide X` buat detail") alih-alih diam-diam ketinggalan.
- **Catatan maintenance (untuk pengembang plugin, bukan runtime):** saat menambah skill baru, tambahkan satu baris 1-liner ke `reference.md`. Risiko basi terbatas pada **kerapian** 1-liner; "ADA/tidaknya" skill dan **detail**-nya selalu benar karena diturunkan dari sumber.

## 6. Guardrails

- **Read-only mutlak.** Tak pernah Write/Edit. Tak menyentuh `control/` maupun kode produk. Satu-satunya efek = teks + pointer command.
- **Tidak nge-launch.** Beri pointer command, user yang mengetik (tak meng-invoke skill lain).
- **Scope = plugin, bukan produk.** Cermin `ask`: pertanyaan tentang produk user → route ke `/ask`. Pertanyaan tentang plugin → dijawab di sini.
- **Anti-ngarang.** Pengetahuan plugin tak menjawab → bilang + arahkan; detail → baca `SKILL.md` asli, jangan menebak.
- **Bahasa = Indonesia santai**, samakan voice plugin (selaras skill lain).
- **Hemat konteks.** Mode tur progresif (§4.1) menjaga output ringkas; drill (§4.2/§5) hanya baca `SKILL.md` yang relevan, bukan scan seluruh `skills/`.

## 7. Rollout / Discoverability

Dikerjakan **sekali saat implementasi** (bukan perilaku runtime):

- **README.md** — tambah baris menonjol di paling atas (setelah judul/tagline, sebelum/di bagian Install): *"Baru install / males baca? Ketik `/guide` — panduan + tanya-jawab soal plugin ini."*
- **`plugin/.claude-plugin/plugin.json`** — selipkan `guide` ke `description` sebagai pintu masuk onboarding (mis. di awal: "… `guide` (panduan & Q&A onboarding plugin: tur progresif + tanya skill/flow), …").
- *(Opsional, di luar scope yang disepakati: `marketplace.json` description — bisa disusulkan terpisah bila mau muncul di listing pra-install.)*

## 8. Struktur File

```
plugin/skills/guide/
  SKILL.md        # frontmatter + perilaku dua mode + guardrails (§4, §6)
  reference.md    # baked: peta flow + tabel keputusan + katalog 1-liner (§5)
```
Plus edit: `README.md`, `plugin/.claude-plugin/plugin.json` (§7).

## 9. Draft Frontmatter `description`

> Use untuk ngerti/onboarding plugin context-vault sendiri (BUKAN produk yang lagi dibangun) — tur orientasi progresif + tanya-jawab soal skill, flow, metodologi. Tanpa argumen = tur (apa itu, peta flow, cheatsheet, mulai dari mana, lalu tawarin dalami bagian tertentu). Dengan argumen = jawab "skill X apa", "kapan pakai Y", "bedanya /fix & /tweak", "abis /init ngapain". Hybrid: cheatsheet baked + baca SKILL.md asli on-demand buat detail. Read-only, nggak nyentuh file, nggak nge-launch skill lain. Pertanyaan soal PRODUK (status/fitur/auth) → arahin ke /ask. Trigger — "guide", "panduan plugin", "cara pake plugin ini", "skill apa aja", "mulai dari mana", "onboarding". Bisa dipanggil dari mana saja (nggak butuh control/).

## 10. Keputusan Terkunci (dari brainstorming)

| # | Keputusan | Pilihan |
|---|---|---|
| 1 | Bentuk | Pure guide, **plugin-only** (tak deteksi state produk) |
| 2 | Cakupan | Onboarding **+** Q&A soal plugin (satu skill) |
| 3 | Sumber konten | **Hybrid** — cheatsheet baked + baca `SKILL.md` on-demand |
| 4 | Nama/trigger | **`guide`** (`/help` dihindari: bentrok bawaan) |
| 5 | Mode tur | **Progresif** (singkat dulu → tawarkan dalami) |
| 6 | Rollout | **README + plugin.json** (marketplace.json opsional) |
| 7 | Launch skill lain? | **Tidak** — hanya pointer command |

## 11. Risiko & Mitigasi

- **Tumpang tindih dengan `ask`** → dibatasi tegas lewat boundary (§4.2 langkah 1, §6): `ask` = produk, `guide` = plugin; saling-rute.
- **Katalog baked basi** → §5 anti-drift: ADA/tidaknya & detail dari sumber; baked hanya 1-liner kosmetik.
- **Tur kepanjangan** → §4.1 progresif: langkah 1–4 muat layar, sisanya on-demand.
- **Over-reach jadi nulis** → §6 read-only mutlak; rollout (§7) adalah edit satu-kali implementasi, bukan perilaku skill.
