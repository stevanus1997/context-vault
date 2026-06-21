---
name: guide
description: Use untuk ngerti/onboarding plugin context-vault sendiri (BUKAN produk yang lagi dibangun) — tur orientasi progresif + tanya-jawab soal skill, flow, metodologi. Tanpa argumen = tur (apa itu, peta flow, cheatsheet, mulai dari mana, lalu tawarin dalami bagian tertentu). Dengan argumen = jawab "skill X apa", "kapan pakai Y", "bedanya /fix & /tweak", "abis /init ngapain". Hybrid: cheatsheet baked + baca SKILL.md asli on-demand buat detail. Read-only, nggak nyentuh file, nggak nge-launch skill lain. Pertanyaan soal PRODUK (status/fitur/auth) → arahin ke /ask. Trigger — "guide", "panduan plugin", "cara pake plugin ini", "skill apa aja", "mulai dari mana", "onboarding". Bisa dipanggil dari mana saja (nggak butuh control/).
---

# guide — Panduan & Q&A plugin context-vault (read-only)

Tujuan: bantu siapa pun **paham plugin context-vault** — ada skill apa aja, flow-nya gimana, mulai dari mana, dan jawab pertanyaan soal cara kerjanya. **100% read-only** — nggak pernah nyentuh file, nggak nge-launch skill lain; satu-satunya efek = teks jawaban + pointer command.

## Prasyarat & scope
- Bisa dipanggil **dari mana saja** — nggak butuh `control/` (jalan walau user belum punya produk).
- **Scope = PLUGIN** (skill/flow/metodologi context-vault), **BUKAN produk** yang lagi dibangun. Ini cermin `/ask` (yang scope-nya produk). Pertanyaan soal produk → arahin `/ask`.

## Deteksi mode
- **Tanpa argumen bermakna** → **Mode Tur** (progresif).
- **Dengan argumen** (pertanyaan/topik) → **Mode Q&A**.

## Mode Tur (progresif — JANGAN dump semua sekaligus)
Keluarkan langkah 1–4 saja dulu (ringkas, muat layar), lalu tawarkan dalami:

1. **Sapaan + apa itu** (1 paragraf): context-vault = lapisan AI + knowledge (bukan kode) buat ngelola produk multi-app bareng Claude Code.
2. **Peta flow ringkas** (1 baris): `discovery → init → architect → wire → feature → breakdown → build → ship`, plus sebut sekilas lane samping (`fix`/`tweak`/`debt`/`ask`). (Detail tiga varian flow ada di `reference.md`.)
3. **Cheatsheet inti** — tabel pendek "mau X → pakai `/Y`" buat aksi paling umum (mulai produk, bikin fitur, ada bug, perubahan kecil, tanya produk vs tanya plugin). Ambil dari `reference.md`, potong yang paling sering dipakai.
4. **Mulai dari mana**: `/discovery` (ide masih mentah) atau `/init` (udah jelas / brownfield).
5. **Tawarkan dalami** (menu): "Mau gw dalemin yang mana? (1) pipeline fitur (2) lane samping fix/tweak/debt (3) scaffolding add-app/package/integration/design-system (4) docs & maintenance (5) tanya bebas". Baru di giliran berikutnya, tarik grup katalog terkait dari `reference.md` dan jelasin.

**Aturan:** jangan cetak seluruh katalog + deskripsi panjang di langkah pertama. Detail per-grup keluar **on-demand** lewat langkah 5.

## Mode Q&A (ada argumen)
1. **Boundary check dulu.** Kalau pertanyaan sebenarnya soal **produk** user (status, fitur yang udah jalan, auth produk, isi `control/`) → bilang itu ranah `/ask`, arahin ke sana, **stop**. Jangan jawab sebagai guide.
2. **Jawab dari baked** (`reference.md`) buat pertanyaan peta/cheatsheet/"kapan pakai apa"/perbandingan — instan.
3. **Drill on-demand** buat pertanyaan dalam soal **satu skill** ("/build detailnya gimana", "/fanout ngapain persisnya"): baca `SKILL.md` skill itu lewat base-dir skill ini sendiri → `<base-dir-guide>/../<skill>/SKILL.md`. Jawab dari sumber asli. (Path relatif → jalan di repo dev maupun cache plugin user.)
4. **Perbandingan** ("/fix vs /tweak", "/feature vs /tweak"): pakai tabel keputusan di `reference.md`; kalau butuh nuansa, baca dua `SKILL.md`-nya.
5. **Anti-ngarang**: di luar pengetahuan plugin → bilang terus terang + arahin; jangan nebak (selaras `rules/anti-yes-man.md`).

## Sumber & anti-drift
- `reference.md` = lapisan **baked** (peta flow + tabel keputusan + katalog 1-liner) — buat jawaban cepat & seragam.
- **"Skill apa yang ADA" = listing folder**, bukan percaya buta `reference.md`. Saat nampilin katalog penuh, lihat folder tetangga (`<base-dir-guide>/../`) sebagai sumber kebenaran daftar skill. Kalau ada folder skill **tanpa** entri di katalog, sebut apa adanya: "ada skill `X` yang belum ada ringkasannya — ketik `/guide X` buat detail."
- **Detail** selalu dari `SKILL.md` asli (jangan duplikasi isi panjang ke sini).

## Guardrails
- **Read-only mutlak.** Nggak pernah Write/Edit. Nggak nyentuh `control/` maupun kode. Efek = teks + pointer command.
- **Nggak nge-launch.** Kasih pointer command (mis. `/init`, `/feature`); user yang ngetik. Jangan invoke skill lain.
- **Scope = plugin, bukan produk** (cermin `/ask`): pertanyaan produk → route `/ask`.
- **Anti-ngarang.** Pengetahuan plugin diam → bilang + arahin; detail → baca `SKILL.md` asli.
- **Bahasa Indonesia santai.** Hemat konteks — tur progresif & drill cuma baca `SKILL.md` relevan, bukan scan seluruh `skills/`.

## Catatan
- `guide` cermin `/ask`: `ask` jawab soal **produk** (`control/` + kode), `guide` jawab soal **plugin** (skill/flow/metodologi). Keduanya saling-rute di batas scope.
- Pintu masuk buat user baru "males baca README" — satu trigger buat orientasi + tanya-jawab.
