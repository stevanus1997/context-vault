---
name: ask
description: Use untuk nanya APA PUN tentang produk yang lagi dikerjain (greenfield/brownfield) — AMA read-only. Knowledge-first, code-fallback — baca control/ dulu, turun ke kode cuma saat level-implementasi atau knowledge tipis. Tiap jawaban sebut sumber; flag drift (catatan vs kode) lalu route ke skill pemilik. TIDAK pernah nulis. Trigger — "ask <pertanyaan>", "tanya <x>", "jelasin <x>", "status produk", "fitur apa aja yang udah jalan". Jalankan dari root produk yang punya control/.
---

# ask — Tanya apa pun tentang produk (read-only)

Tujuan: jawab pertanyaan apa pun tentang PRODUK yang sedang dikerjakan, dari knowledge `control/` (sumber kebenaran) dengan fallback ke kode saat perlu. **100% read-only** — `ask` tidak pernah menyentuh file; satu-satunya "aksi" = menyarankan/route ke skill lain.

## Prasyarat
- Jalankan dari root produk yang punya `control/`.
- **Tanpa `control/`** (folder mentah / belum init) → jangan jawab sebagai-produk: arahkan `/init` (atau `/discovery` kalau ide masih mentah), lalu STOP.

## Alur (tiap pertanyaan)

### 1. Klasifikasi → file relevan
Tentukan domain pertanyaan, buka **hanya** file yang relevan (bukan semua `control/`):

| Domain pertanyaan | Sumber `control/` |
|---|---|
| Bisnis: produk apa, pengguna, nilai, istilah, langkah flow | `business/domain.md` · `flows.md` · `glossary.md` |
| Arsitektur: app/package, tanggung jawab, stack, capability, topology | `workspace.yaml` |
| Aturan platform (tenancy/money/idempotency/authz/PII-PCI) | `invariants.md` |
| Konvensi lintas-app | `conventions.md` |
| Vendor eksternal (arah/mode/dipakai-di) | `integrations.md` |
| Status: fitur apa saja, draft/active/shipped, perilaku 1 fitur | `features/*/feature.yaml` (+ `business.md`) |
| Bug / known-issues / riwayat fix | `fixes/*/fix.yaml` (+ `notes.md`) |
| Implementasi: "fungsi X jalan gimana", "endpoint Y di mana" | → code-fallback (langkah 3) |

Pertanyaan lintas-domain → buka >1 sumber.

### 2. Baca knowledge
Buka file relevan. Hemat konteks — baca yang nyambung saja, bukan seluruh `control/`.

### 3. Code-fallback (kapan turun ke kode)
Turun baca/grep kode **hanya bila salah satu**:
- **(a) Level-implementasi** — pertanyaan menanyakan *bagaimana kode bekerja* (alur fungsi, lokasi endpoint, struktur data nyata), bukan *apa keputusannya*.
- **(b) Knowledge diam/tipis** — file relevan tak ada / tak menjawab (khas brownfield belum `extract`).

Pakai **grep terarah + baca file** (pola sama `plan`/`extract`), bukan scan repo buta. Multi-app → batasi ke app relevan dari `workspace.yaml`. Fallback berat (>2 file) → **dispatch subagent** agar konteks sesi `ask` ramping; fallback ringan → inline. Multi-repo: hanya repo app relevan; bila repo tak ter-checkout lokal, katakan demikian (jangan menebak).

### 4. Jawab + sumber (WAJIB)
Ringkas, langsung. **Selalu sebut asal**: "dari `control/invariants.md`", "dari baca `apps/api/auth.ts:42`". Tiga tingkat keyakinan, nyatakan eksplisit:
- dari **kode** → ground truth.
- dari **knowledge, terverifikasi ke kode** → tertinggi.
- dari **knowledge saja, belum dicek ke kode** → tandai bisa-stale ("ini dari catatan; belum gw cek ke kode").

### 5. Flag drift → route (BUKAN nulis)
Kalau code-fallback menyingkap kode yang **membantah** knowledge:
1. **Flag eksplisit** — sebut keduanya: "`invariants.md` bilang X, tapi `auth.ts` pakai Y — catatannya kemungkinan basi." Jawab pertanyaan dengan **kode sebagai kebenaran** (kode = realita), tapi tunjukkan konfliknya.
2. **Tawarkan koreksi → route ke skill pemilik** (`ask` **tidak** menulis):

| File drift | Skill pemilik (route) |
|---|---|
| `invariants.md` · `workspace.yaml` (stack/capability) · `conventions.md` | `/architect` |
| `business/*` · perilaku fitur (`features/*/business.md`) | `/intake` (di dalam `/feature`) atau `/feature` |
| `integrations.md` (vendor) | `/add-integration` |
| `features/*/feature.yaml` status | lifecycle terkait (`/build` · `/ship` · `/drop`) |

Jelaskan file mana yang punya & skill mana yang memperbaikinya, lalu berhenti. **Jangan menulis koreksi sendiri** — menjaga ownership bersih (tiap file `control/` hanya disentuh skill pemiliknya, yang punya gate/`critic`-nya).

### 6. Saran skill (pointer, BUKAN auto-jalan)
Kalau pertanyaan menyiratkan aksi → beri pointer:
- mau nambah kapabilitas/fitur → `/feature`
- kedengeran bug (perilaku ada tapi salah) → `/fix`
- brownfield, knowledge kosong → `/extract` bakal isi `business/`

**Jangan** meng-invoke skill itu; user yang memutuskan.

## Guardrails
- **Read-only mutlak.** Tidak pernah Write/Edit. Tidak menyentuh `control/` maupun kode. Satu-satunya efek = teks jawaban + (opsional) pointer skill.
- **Anti-ngarang.** Knowledge diam **dan** kode tak ketemu → bilang "belum tercatat di `control/` dan gak ketemu di kode" + sarankan skill pengisi. Jangan menebak (selaras `rules/anti-yes-man.md`).
- **Scope = produk** (lintas semua app di `workspace.yaml`), bukan metodologi plugin. Pertanyaan soal "cara nambah app" dsb → beri pointer skill (`/add-app`), jangan jelaskan internal plugin.
- **SHAPE-only untuk sensitif.** Jangan tampilkan nilai secret/PII/data kartu; cukup nama env var / bentuk kontrak. Saat code-fallback kebetulan melihat secret, jangan kutip nilainya.

## Catatan
- Sumber kebenaran = `control/`; **kode = realita** saat keduanya beda (drift).
- `ask` pelengkap **read-side** dari `render-docs` (knowledge→HTML satu-arah, untuk stakeholder). `ask` = tanya-jawab interaktif, untuk siapa saja, kapan saja.
