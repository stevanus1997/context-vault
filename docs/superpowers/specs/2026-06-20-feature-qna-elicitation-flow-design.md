# Q&A Elicitation & Flow-Awareness pada Pipeline Fitur — Design

**Goal:** Tutup tiga lubang UX di Q&A pipeline fitur yang bikin user "asal pilih recommended" lalu hasil akhir meleset dari harapan: (1) pertanyaan keborong jadi satu tembakan, (2) opsi tanpa konsekuensi sehingga membingungkan, (3) **alur/flow fitur tak punya rumah** di artifact mana pun sehingga keskip dari elicitation dan dari gate.

**Architecture:** Editan PROMPT/markdown pada skill context-vault (BUKAN kode runtime). Satu file aturan baru `plugin/rules/elicitation.md` (sibling `anti-yes-man.md`) jadi sumber-tunggal konvensi Q&A; lima skill Q&A (`intake`, `fanout`, `plan`, `tweak`, `fix`) mengganti prosa lemahnya dengan referensi tipis ke aturan itu; `intake` dapat slot `Flow/Skenario` first-class di template `business.md` + langkah elicit-nya.

**Tech Stack:** Markdown skill files di `/Users/stevanus/Developer/ai-boilerplate/plugin/`. TIDAK ADA runtime/test executable — "verifikasi" tiap perubahan = (a) `rg`/grep bahwa teks instruksi baru hadir di anchor benar, (b) cek konsistensi lintas-file (path `${CLAUDE_PLUGIN_ROOT}/rules/elicitation.md` resolve, tak ada referensi yatim), (c) read-back koheren section + sekitarnya, (d) satu walkthrough mental `intake`. Git untuk commit.

---

## 1. Latar & Diagnosis (grounded)

Keluhan user: di pipeline fitur, Q&A "sering nimpa beberapa pertanyaan jadi 1", "kasih pilihan gak detail" → bingung → "asal pilih recommended", dan terutama "flow feature yang mau dibangun suka keskip" → "hasil akhir gak sesuai harapan".

Pembacaan kode menemukan ketiganya BUKAN desain sengaja, melainkan gap enforcement + lubang struktural:

- **Q&A keborong.** Niat aslinya satu-per-satu — `intake/SKILL.md:29` eksplisit *"Tanya satu per satu"* — tapi cuma prosa lembut, dan hanya di `intake`. Tahap lain longgar: `plan/SKILL.md:42` *"Q&A teknis seperlunya"*, `fanout/SKILL.md:17` *"konfirmasi cepat"*. Tanpa mekanisme penegak → drift ke borong.
- **Opsi tipis.** Tidak ada satu pun spec (di skill mana pun maupun `conventions.md`) yang mengatur kekayaan opsi — tiap pilihan wajib bawa konsekuensi, atau "jangan auto-recommend untuk keputusan impactful". Pola yang BENAR sebetulnya sudah ada di repo: slot `Mockup:` 3-jalur (`plan/SKILL.md:45` + `plan/reference.md` §B) menjelaskan konsekuensi tiap jalur. Tinggal diangkat jadi konvensi.
- **Flow tak punya rumah.** Template `business.md` (`intake/SKILL.md:47-54`) cuma `Tujuan / Pengguna / Aturan / Hasil-Reward / Out of scope` — TIDAK ada slot Flow/Skenario. `control/business/flows.md` adalah flow level-PRODUK (yang `intake` baca & *promote* ke situ — `intake:55`), bukan flow spesifik fitur. Karena flow tak ada barisnya di `business.md`, ia juga tak tampil di gate approve (`intake:59`) → gampang lolos tanpa di-review. Ketiga gap saling memperburuk: Q&A keborong + opsi tipis memeras nuansa flow yang ada di kepala user.

## 2. Keputusan yang Dikunci (hasil brainstorming)

- **D-scope:** Kerjakan ketiga lever sekaligus dalam satu desain (konvensi Q&A + slot Flow saling menguatkan, menyentuh file yang sama).
- **D-strictness:** Aturan "satu pertanyaan per giliran" jadi **HARD rule TAPI hanya untuk keputusan bercabang** (yang mengubah arah hasil). Konfirmasi sepele BOLEH digabung.
- **D-mekanisme:** Konvensi ditaruh di **file aturan plugin** `plugin/rules/elicitation.md` (niru pola `rules/` existing), dirujuk tipis dari skill — BUKAN inline di tiap skill (rawan drift), BUKAN di `conventions.md` produk (salah lapisan; perilaku skill, bukan kebijakan produk).
- **D-cakupan-wiring:** Lima skill Q&A: `intake`, `fanout`, `plan`, **plus `tweak` & `fix`** (atas permintaan user). Skill Q&A lain (`discovery`, `architect`) di luar scope ronde ini (follow-on murah: tambah 1 baris).

## 3. Komponen Desain

### D1 — File aturan baru `plugin/rules/elicitation.md`

File baru, register sama persis dengan `anti-yes-man.md` (pendek, bullet tebal, `## Kontrak` + `## Batas`). Isi final:

```markdown
# Elicitation — Aturan Q&A & Penyajian Opsi

Dirujuk skill yang meng-elicit keputusan dari user lewat Q&A discovery/design
(intake, fanout, plan, tweak, fix). Berlaku saat skill MENANYAKAN keputusan ke
user — BUKAN ke routing mekanis (mis. triage verba-list tweak/fix). Tujuan:
keputusan yang MENYETIR hasil diambil sadar oleh user — bukan keborong jadi satu
tembakan, bukan "asal pilih recommended".

## Kontrak
- **Keputusan-bercabang = satu pertanyaan per giliran.** Keputusan yang MENGUBAH
  ARAH hasil (siapa pengguna, flow/skenario, aturan bisnis, reuse-vs-NEW tabel,
  app/package/vendor baru, jalur Mockup) ditanya SATU per giliran. JANGAN gabung
  2+ keputusan-bercabang dalam satu tembakan. Konfirmasi sepele (ejaan nama,
  yes/no kecil, "ada lagi?") BOLEH digabung.
- **Tiap opsi bawa konsekuensi.** Tiap pilihan disertai 1 baris akibat/tradeoff
  ("kalau ini → ..."), BUKAN label telanjang. User harus bisa milih tanpa nebak
  maksud opsi.
- **Selalu sediakan jalan keluar dari menu.** Selain opsi yang ditawarkan, selalu
  beri ruang "ceritain versimu sendiri" — opsi bukan kurungan.
- **Jangan tandai *recommended* untuk keputusan ber-impact tinggi/ireversibel.**
  Sajikan tradeoff lalu minta user yang putuskan; default-recommend malah mancing
  "asal pilih". (Selaras `anti-yes-man.md`: persetujuan harus berdasar.)
- **Surface di gate.** Keputusan-bercabang yang sudah diambil HARUS kelihatan di
  artifact yang ditampilkan saat gate (slot di business.md/fanout.md/plans) — biar
  bisa di-review, bukan terkubur.

## Batas
- **Bukan pelarangan batch di mana-mana.** Skill yang sengaja mem-batch demi biaya
  manusia (mis. pre-flight conflict sweep `build`, build/SKILL.md:18) TIDAK
  dilanggar — itu konfirmasi-borong disengaja, bukan Q&A discovery bercabang.
- **Gate ≠ interogasi.** Gate yang menampilkan Challenge Checklist/diff TERISI untuk
  di-review (mis. `tweak` step 5 — "output terisi, BUKAN interogasi 4-ronde",
  tweak/SKILL.md:40; gate `intake`/`build`) BUKAN sasaran aturan ini. "Satu
  pertanyaan per giliran" mengatur Q&A discovery, bukan mengubah gate jadi
  tanya-jawab beruntun.
- **Proporsional.** Fitur 1-app/sepele tak perlu diregang jadi 10 giliran — aturan
  ini menyerang keputusan yang benar-benar bercabang, bukan bikin birokrasi.
```

Catatan: `elicitation.md` **TIDAK** di-merge ke CLAUDE.md oleh `init` (beda dari `anti-yes-man.md` di `init/SKILL.md:63`). Ini perilaku Q&A skill, bukan sikap global — referensi per-skill cukup, hindari over-reach.

### D2 — Slot `Flow/Skenario` di `business.md` + langkah elicit (`intake`)

**D2a — Template `business.md`** (`intake/SKILL.md:47-54`): tambah satu baris setelah `Pengguna` (urutan logis: siapa → ngapain → di bawah aturan apa → hasilnya apa):

```
# <Fitur> — Business Spec
Tujuan       : <...>
Pengguna     : <...>
Flow/Skenario: <happy-path: langkah 1 → 2 → 3 …;
                + minimal 1 skenario edge/gagal: <kondisi> → <yang terjadi>>
Aturan       : <... + referensi business/ bila relevan>
Hasil/Reward : <...>
Out of scope : <...>
```

**D2b — Langkah Q&A** (`intake/SKILL.md:29`): tambah flow ke daftar yang ditanya + rujuk D1. Jadi kira-kira:
> "Q&A ikuti `${CLAUDE_PLUGIN_ROOT}/rules/elicitation.md`. Tanya level bisnis: siapa pengguna, **alur yang dilewati pengguna (happy-path) + minimal 1 skenario edge/gagal**, aturan/kebijakan, hasil, batasan."

**D2c — Relasi ke `flows.md` (diperkuat, bukan diubah).** Langkah promote durable (`intake:55`) tetap; sekarang slot `Flow/Skenario` jadi **sumber eksplisit** yang dipromote ke `business/flows.md` (sebelumnya sumbernya ngambang). Pembagian peran: `business.md Flow` = flow spesifik fitur (di-review di gate); `flows.md` = flow domain lintas-fitur (hasil promote). Tak ada duplikasi.

**Wajib minimal 1 skenario edge/gagal:** happy-path mudah terbayang; yang biasanya bocor & bikin hasil meleset justru jalur gagalnya.

### D3 — Wiring referensi tipis (5 skill)

Ganti prosa lemah dengan rujukan ke D1, di titik yang benar-benar MENANYAKAN user:

| File / anchor | Sekarang | Jadi |
|---|---|---|
| `intake/SKILL.md:29` | "Tanya satu per satu: …" | rujuk `elicitation.md` + tambah flow (D2b) |
| `fanout/SKILL.md:17` | "konfirmasi cepat" | rujuk `elicitation.md` — challenge app/package/vendor/design-system baru = keputusan bercabang |
| `plan/SKILL.md:42` | "Q&A teknis seperlunya" | rujuk `elicitation.md` — reuse-vs-NEW tabel & jalur Mockup = keputusan bercabang |
| `tweak/SKILL.md:27` | cabang-C ambigu "tanya satu pertanyaan" | rujuk `elicitation.md` di titik tanya — **BUKAN** ke routing verba-list (mekanis) |
| `fix/SKILL.md:23,25,50` | "DUA fitur → TANYA / konfirmasi"; triage guard; unit-inference "konfirmasi user" | rujuk `elicitation.md` di titik konfirmasi mode/triage/unit |

### D4 — Carve-out (anti-tabrakan dengan desain existing)

Sudah ter-encode di `## Batas` D1, tapi dicatat eksplisit sebagai invarian desain:
1. **`build:18` sengaja mem-batch** ("SATU pertanyaan batched") demi biaya manusia → tidak dilanggar.
2. **`tweak:40` Challenge Checklist = "output terisi, BUKAN interogasi 4-ronde"** → elicitation tak mengubah gate tweak jadi tanya-jawab beruntun.
3. **Triage `tweak`/`fix` itu verb-list-driven (mekanis), bukan menu pilihan** → elicitation tak menyentuh logika routing B/C/A; hanya momen klarifikasi ke user.

### D5 — Idempotency / retrofit

Perubahan template `business.md` (D2a) hanya kena **intake run baru + re-run** (intake idempotent per `intake:55`). Fitur lama yang `business.md`-nya sudah ada **tidak dipaksa migrasi** — slot `Flow/Skenario` muncul kalau intake-nya di-re-run. Tidak ada script migrasi; tidak ada artifact yang basi. Wiring D3 + file D1 langsung berlaku untuk semua run berikutnya.

### D6 — Verifikasi

Perubahan markdown-spec only (tak ada kode/test). Gate verifikasi:
1. `plugin/rules/elicitation.md` ada; semua rujukan di 5 skill mengeja path `${CLAUDE_PLUGIN_ROOT}/rules/elicitation.md` benar (`rg` tak menemukan referensi yatim).
2. Template `business.md` di `intake` punya baris `Flow/Skenario`; langkah Q&A `intake:29` menyebut flow + edge-case.
3. Read-back koheren tiap anchor + ~10 baris sekitarnya; voice konsisten (Bahasa Indonesia teknis, istilah teknis Inggris).
4. Walkthrough mental satu `intake` fitur kecil: flow ditanya satu giliran, opsi (bila ada) bawa konsekuensi, `Flow/Skenario` muncul di gate.

## 4. Invarian / Constraint

- **Nol palang keras baru.** Semua tambahan = disiplin Q&A + show-at-gate; tidak ada STOP/block baru.
- **Sumber-tunggal konvensi.** Isi aturan HANYA di `elicitation.md`; skill merujuk, tidak menyalin (hindari drift 5-salinan).
- **Degrade proporsional.** Fitur 1-app/sepele tidak diregang jadi banyak giliran.
- **Pertahankan voice + minimalisme skill.** Editan tipis; SKILL.md tetap ramping.
- **Editan markdown, bukan kode.** "TDD" klasik tak berlaku; verifikasi via grep-assertion + read-back, lalu commit.

## 5. Out of Scope (YAGNI)

- Skill Q&A lain (`discovery`, `architect`) — follow-on murah (tambah 1 baris rujukan).
- Merge `elicitation.md` ke CLAUDE.md via `init` — sengaja tidak (perilaku skill, bukan sikap global).
- Mengubah cara pakai tool `AskUserQuestion` / tooling baru — aturan modality-agnostic.
- File artifact flow terpisah — flow hidup sebagai baris di `business.md`, bukan file.
- Migrasi paksa `business.md` fitur lama — muncul saat re-run intake.
