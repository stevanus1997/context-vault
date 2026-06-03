# context-vault — Skill `ask`: AMA Produk (read-only) (Design Spec)

- **Tanggal:** 2026-06-03
- **Status:** Draft disetujui untuk masuk tahap perencanaan implementasi (hasil brainstorming, semua keputusan perilaku terkunci)
- **Terkait:** spec induk `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (mengisi sisi-BACA lifecycle — belum ada jalur tanya-jawab interaktif); `plugin/skills/render-docs/SKILL.md` (tetangga read-side: knowledge→HTML satu-arah; `ask` = tanya-jawab interaktif); `plugin/rules/anti-yes-man.md` (guard anti-ngarang); `plugin/skills/extract/SKILL.md` (brownfield: knowledge bisa tipis → code-fallback).

---

## 1. Ringkasan

Seluruh skill yang ada **action/write-oriented** — tiap satu menciptakan atau memodifikasi sesuatu:

```
discovery → init → architect → wire → feature(intake→fanout→plan) → breakdown → build → ship
                                                                                    ├ drop
                                                                                    └ fix
```

`render-docs` membaca `control/` tapi outputnya **satu-arah** (HTML statis buat stakeholder). **Tidak ada cara interaktif untuk bertanya** "apa pun" tentang produk yang sedang dikerjakan — baik produk **greenfield** (knowledge `control/` kaya) maupun **brownfield** (knowledge bisa tipis karena `extract` opsional, kode = kebenaran).

Spec ini menambah **satu skill baru, `ask`** — **AMA (ask-me-anything) produk, 100% read-only**. Ia menjawab pertanyaan apa pun tentang produk dengan **knowledge-first, code-fallback**: baca `control/` dulu, turun ke kode hanya saat perlu. Setiap jawaban **menyebut sumbernya**; saat menemukan knowledge yang **drift** (catatan basi vs kode), ia **flag eksplisit** lalu **route ke skill pemilik** untuk koreksi — `ask` sendiri **tidak pernah menulis apa pun**.

Prinsip inti: **satu pintu-baca, nol tulisan.** `ask` adalah satu-satunya skill pure-read; ia melengkapi `render-docs` di sisi konsumsi-knowledge tanpa menabrak skill lain.

## 2. Masalah

- **M1 — Tidak ada jalur tanya-jawab.** Untuk tahu "produk ini auth-nya apa", "fitur apa saja yang sudah jalan", "flow checkout langkahnya apa", "app `api` tanggung jawabnya apa" — user harus buka `control/` manual atau ngubek kode. Newcomer (atau diri-sendiri setelah jeda) tak punya pintu masuk.
- **M2 — `render-docs` bukan jawaban interaktif.** Ia generate HTML penuh, tidak menjawab satu pertanyaan spesifik, dan dioptimasi untuk **stakeholder non-teknis** (tidak menyentuh level implementasi/kode).
- **M3 — Brownfield: knowledge bisa diam.** `extract` opsional (induk: "knowledge tumbuh just-in-time"). Pertanyaan tentang produk brownfield yang belum di-`extract` tak terjawab dari `control/` saja — perlu turun ke kode.
- **M4 — Drift tak punya pendeteksi pasif.** Saat membaca kode untuk menjawab, sering ketahuan `control/` sudah basi (mis. `invariants.md` bilang email-password, `auth.ts` sudah OAuth). Tanpa skill yang mem-flag ini, drift menempel diam-diam dan justru menyesatkan skill downstream yang membaca `control/`.

Akar: sistem punya banyak penulis-knowledge, **nol pembaca-interaktif**. `control/` sebagai source-of-truth bernilai hanya kalau gampang ditanyai.

## 3. Tujuan & Non-Tujuan

**Tujuan:**
- **Satu skill `ask`** yang menjawab **pertanyaan apa pun tentang produk** yang sedang dikerjakan (greenfield & brownfield).
- **Knowledge-first, code-fallback** (§4): baca `control/` relevan dulu; turun ke kode hanya saat (a) pertanyaan level-implementasi, atau (b) knowledge diam/tipis.
- **Grounding wajib** (§5): tiap jawaban menyebut sumbernya (`control/` file mana / kode mana).
- **Drift-flag + route** (§5): saat code-fallback menyingkap knowledge basi → flag eksplisit; bila user mau betulin → **route ke skill pemilik**, `ask` tidak menulis.
- **Read-only mutlak** (§6): satu-satunya "aksi" = menyarankan/route skill lain. Tidak pernah menyentuh file.
- **Anti-ngarang** (§6): knowledge diam **dan** kode tak ketemu → bilang "belum tercatat / tak ditemukan", bukan menebak.

**Non-Tujuan (v1):**
- `ask` **tidak menulis** apa pun — tidak `control/`, tidak kode. Drift dikoreksi lewat skill pemilik (`/architect`, `/intake`|`/feature`, `/add-integration`).
- `ask` **tidak auto-menjalankan** skill lain — hanya memberi pointer; user yang memutuskan.
- **Bukan generator dokumen** — itu `render-docs`. `ask` menjawab pertanyaan spesifik, bukan bikin HTML.
- **Bukan tanya-jawab tentang metodologi plugin** ("skill apa saja yang ada", "cara kerja pipeline") — scope = **produk yang dikerjakan**, bukan context-vault sebagai sistem.
- **Tidak ada index/embedding/RAG** — penjawaban via baca-file terarah + grep, bukan infrastruktur pencarian baru.
- **Tidak ada histori/log percakapan** yang di-persist — `ask` stateless per pemanggilan.

## 4. Alur Penjawaban — Knowledge-First, Code-Fallback

Tiap pertanyaan melewati pipeline yang sama:

```
pertanyaan
  → 1. KLASIFIKASI domain  → tentukan file control/ relevan (bukan baca semua)
  → 2. BACA knowledge       → buka file relevan
  → 3. CODE-FALLBACK?        → turun baca/grep kode bila level-implementasi ATAU knowledge diam
  → 4. JAWAB + sumber        → ringkas, selalu sebut asal
  → 5. (bila drift) FLAG + route ke skill pemilik
  → 6. (bila nyiratkan aksi) SARAN skill (pointer, tidak auto-jalan)
```

**Langkah 1 — Klasifikasi → file relevan.** Map domain pertanyaan ke sumber knowledge (tabel ini juga jadi peta baca skill):

| Domain pertanyaan | Sumber `control/` |
|---|---|
| Bisnis: produk apa, pengguna, nilai, istilah, langkah flow | `business/domain.md` · `flows.md` · `glossary.md` |
| Arsitektur: app/package apa, tanggung jawab, stack, capability, topology | `workspace.yaml` |
| Aturan platform (tenancy/money/idempotency/authz/PII-PCI) | `invariants.md` |
| Konvensi lintas-app | `conventions.md` |
| Vendor eksternal (arah/mode/dipakai-di) | `integrations.md` |
| Status: fitur apa saja, draft/active/shipped, perilaku 1 fitur | `features/*/feature.yaml` (+ `business.md`) |
| Bug / known-issues / riwayat fix | `fixes/*/fix.yaml` (+ `notes.md`) |
| Implementasi: "fungsi X jalan gimana", "endpoint Y di mana" | **code-fallback** (§ langkah 3) |

**Langkah 2 — Baca knowledge.** Buka **hanya file relevan** (bukan semua `control/`) — hemat konteks, terarah. Pertanyaan lintas-domain boleh buka >1.

**Langkah 3 — Code-fallback (kapan turun ke kode).** Turun baca/grep kode **hanya bila salah satu**:
- **(a) Level-implementasi** — pertanyaan menanyakan *bagaimana kode bekerja* (alur fungsi, lokasi endpoint, struktur data nyata), bukan *apa keputusannya*.
- **(b) Knowledge diam/tipis** — file relevan tak ada / tak menjawab (khas brownfield belum `extract`).

Code-fallback memakai grep terarah + baca file (pola yang sama dengan `plan`/`extract` saat membaca kode app), **bukan** scan repo buta. Untuk multi-app, batasi ke app yang relevan dari `workspace.yaml`.

**Langkah 4 — Jawab + sumber.** Ringkas, langsung. **Selalu sebut asal**: `"dari control/invariants.md"`, `"dari baca apps/api/auth.ts:42"`. Bila menjawab dari knowledge yang mungkin stale tapi tak sempat dicek ke kode, **katakan demikian** ("ini dari catatan; belum gw verifikasi ke kode").

**Langkah 5 — Drift-flag + route** → §5.

**Langkah 6 — Saran skill** → §6.

## 5. Grounding & Drift

**Grounding wajib.** Tiap jawaban menyertakan sumber. Tiga tingkat kepercayaan eksplisit:
- **Dari kode** → ground truth ("dari baca `auth.ts`").
- **Dari knowledge, terverifikasi ke kode** → tertinggi ("`invariants.md`, cocok dengan `auth.ts`").
- **Dari knowledge saja, belum dicek kode** → tandai bisa-stale ("dari `invariants.md`; belum gw cek ke kode").

**Drift.** Saat **code-fallback** menyingkap kode yang **membantah** knowledge:
1. **Flag eksplisit** — sebut keduanya: *"`invariants.md` bilang email-password, tapi `auth.ts` pakai Google OAuth — catatannya kemungkinan basi."* Jawab pertanyaan dengan **kode sebagai kebenaran** (kode = realita), tapi tunjukkan konfliknya.
2. **Tawarkan koreksi → route, bukan tulis.** Tanya "mau dibetulin catatannya?". Bila **ya**, `ask` **mengarahkan ke skill pemilik** file itu (bukan menulis sendiri):

| File drift | Skill pemilik (tujuan route) |
|---|---|
| `invariants.md` · `workspace.yaml` (stack/capability) · `conventions.md` | `/architect` |
| `business/*` · perilaku fitur (`features/*/business.md`) | `/intake` (di dalam `/feature`) atau `/feature` |
| `integrations.md` (vendor) | `/add-integration` |
| `features/*/feature.yaml` status | (lifecycle skill terkait — `build`/`ship`/`drop`) |

`ask` **tidak menulis** koreksi; ia menjelaskan file mana yang punya & skill mana yang memperbaikinya, lalu berhenti. **Alasan desain:** menjaga **ownership bersih** (tiap file `control/` hanya disentuh skill pemiliknya, yang punya gate/`critic`-nya sendiri) dan menjaga `ask` sebagai pintu yang aman-dipercaya (tanya tak pernah diam-diam mengubah input skill downstream).

> **Catatan kejujuran (anti-yes-man):** route, bukan tulis, berarti **drift bisa menempel** kalau user malas meneruskan ke skill pemilik. Trade-off ini diterima sadar (lihat §9 Open Question — bisa dinaikkan ke write-back consent-gated bila drift sering terabaikan).

## 6. Guardrails

- **Read-only mutlak.** `ask` tidak pernah memanggil Write/Edit, tidak pernah menyentuh `control/` maupun kode. Satu-satunya efek = teks jawaban + (opsional) pointer skill.
- **Saran skill, bukan auto-jalan.** Bila pertanyaan menyiratkan aksi → beri pointer: *"nambah fitur → `/feature`"*, *"kedengeran bug → `/fix`"*, *"belum di-`extract` — `/extract` bakal isi knowledge brownfield"*. **Tidak** meng-invoke skill itu; user yang memutuskan.
- **Anti-ngarang.** Knowledge diam **dan** kode tak ketemu → jawab *"belum tercatat di `control/` dan gak gw temukan di kode"* + sarankan skill yang akan mengisinya. Jangan menebak (selaras `plugin/rules/anti-yes-man.md`).
- **Scope = produk.** Lintas semua app di `workspace.yaml`. Pertanyaan tentang metodologi plugin (di luar produk) → arahkan ke `README.md`, bukan dijawab sebagai "produk".
- **SHAPE-only untuk sensitif.** Sama seperti `render-docs`/`integrations.md`: jangan tampilkan nilai secret/PII/data kartu; cukup nama env var / bentuk kontrak bila perlu. Saat code-fallback kebetulan melihat secret, jangan kutip nilainya.

## 7. Trigger & Prasyarat

- **Trigger:** `ask <pertanyaan>`, "tanya <x>", "jelasin <x>", "<x> itu apa/gimana", "status produk", "fitur apa aja yang udah jalan", "auth-nya pake apa".
- **Prasyarat:** dijalankan dari **root produk yang punya `control/`**.
- **Tanpa `control/`** (folder mentah / belum init) → `ask` tidak menjawab sebagai-produk; arahkan: *"`control/` belum ada — `/init` dulu (atau `/discovery` kalau ide masih mentah)."*

## 8. Dampak ke Komponen Existing

- **Skill baru:** `plugin/skills/ask/SKILL.md`. (Kemungkinan **tanpa** `reference.md` — alurnya ringkas; tabel klasifikasi §4 + aturan drift §5 muat di SKILL.md.)
- **Tidak mengubah skill lain** — `ask` murni baca; tak ada generalisasi work-item / perubahan `build`/`ship`/dll (kontras dengan lane `fix`). Route hanya menyebut nama skill pemilik dalam teks, bukan kontrak baru.
- **`README.md`:** tambah `/ask` di bagian dokumentasi/lifecycle (sisi-baca, sebelah `render-docs`).
- **`plugin/.claude-plugin/plugin.json` + `marketplace.json`:** daftarkan `/ask`; naikkan hitung skill (+1).
- **spec induk:** §-dokumentasi tambah `ask` sebagai pintu-baca interaktif; §17 jumlah skill +1.
- **Tidak ada perubahan `control/` template** — `ask` tak butuh artifact baru (stateless, read-only).

## 9. Scope v1 & Open Questions

**v1 (in):** skill `ask` read-only; pipeline penjawaban knowledge-first + code-fallback (§4); grounding wajib + drift-flag + route-ke-pemilik (§5); guardrails read-only/anti-ngarang/SHAPE-only (§6); trigger + prasyarat `control/` (§7); registrasi plugin + README.

**Open Questions (untuk tahap perencanaan):**
- **`reference.md` terpisah?** Default: tidak (alur muat di SKILL.md). Tinjau saat implementasi bila tabel klasifikasi + contoh drift membengkak.
- **Code-fallback via subagent?** Untuk pertanyaan implementasi berat (baca banyak file), dispatch ke subagent agar konteks sesi `ask` ramping (pola sama `plan`/`fix`). Default usul: subagent untuk fallback yang menyentuh >2 file; inline untuk yang ringan.
- **Drift: route vs write-back consent-gated.** v1 = route (ownership bersih). Bila praktik menunjukkan drift sering terabaikan, naikkan ke koreksi 1-baris consent-gated (opsi yang sempat dibahas). Ditinjau setelah pemakaian nyata.
- **Batas scope "produk vs metodologi".** Pertanyaan campur (mis. "gimana cara nambah app di produk ini") — jawab sebagai pointer skill (`/add-app`) atau tolak sebagai metodologi? Default usul: beri pointer skill (itu tetap tentang produk), jangan jelaskan internal plugin.
- **Multi-repo code-fallback.** Saat produk multi-repo, fallback ke repo mana? Default: hanya repo app relevan dari `workspace.yaml`; bila repo tak ter-checkout lokal, katakan demikian (jangan menebak).
