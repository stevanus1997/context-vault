# context-vault — Skill `add-app`: Nambah App Mid-Product (Design Spec)

- **Tanggal:** 2026-05-31
- **Status:** Draft disetujui untuk masuk tahap perencanaan implementasi
- **Terkait:** spec induk `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (mewujudkan kebutuhan "nambah app" yang disinggung `architect` §13/line 155 + greenfield table §14/line 248, tapi tak pernah punya pelaksana setelah `init`); spec `2026-05-31-wire-skill-design.md` (`add-app` men-chain `wire` buat bring-up); spec `2026-05-29-breakdown-build-execution-phase-design.md` (lewat `wire`, pinjam mesin side-effect `build`)

---

## 1. Ringkasan

Pipeline sekarang: `discovery → init → architect → wire → feature → breakdown → build → ship`. Seluruh fase setelah `init` — `architect`, `wire`, dan pipeline `feature` (`intake → fanout → plan`) — **mengasumsikan semua app sudah terdaftar** di `control/workspace.yaml`. Satu-satunya yang pernah **menulis entri app baru** ke `workspace.yaml` adalah **`init` (step 5)**, di awal produk.

Akibatnya ada **blind spot**: bila sebuah fitur ternyata butuh **app yang belum ada**, tidak ada satu skill pun yang (a) mendeteksinya, (b) merutekan keluar untuk mendeklarasi app itu, atau (c) menulis entri app baru. Pipeline `feature` diam-diam mentok atau crash di hilir (`breakdown`/`build` me-resolve `path` dari `workspace.yaml` yang tidak ada). Workaround de-facto — edit `workspace.yaml` tangan → rerun `architect` → `wire` → balik `feature` — **tidak terdokumentasi di mana pun**.

Spec ini mengisi blind spot itu dengan **satu skill baru, `add-app`**: konduktor tipis yang menjadi **pintu kanonik "numbuhin produk dengan satu app baru, setelah `init`"**. `add-app` adalah satu-satunya penulis entri app baru pasca-`init`, lalu men-chain `architect` (stack) → `wire` (bring-up) sampai app jadi skeleton kosong-tapi-jalan, semua **di-GATE**. Plus, `fanout` diberi **deteksi** "fitur butuh app baru" dan `feature` **auto-invoke** `add-app` saat itu terjadi.

Lifecycle tetap sama untuk jalur lurus; `add-app` adalah **cabang yang dipicu** (oleh `feature` saat butuh, atau standalone).

## 2. Masalah

Audit adversarial (4 finder + 3 skeptik, 0 refutation) atas pipeline `feature` mengonfirmasi tiga celah:

- **C1 — Deteksi: NIHIL.** `fanout/SKILL.md` step 2 (line 15–18) cuma *"cocokkan kebutuhan fitur ke `capabilities`/`responsibility` tiap app → tentukan app yang kena"* — mengasumsikan **minimal 1 app existing cocok**. Adaptifnya hanya "1 app vs banyak app"; **tidak ada cabang "0 app cocok → butuh app baru"**. Challenge Checklist (line 21) menanya *"Ada app yang kelewat?"* (= ada app *existing* yang kelupaan?), **bukan** "butuh app baru?". `intake` step 4 cuma mencatat gap *capability* ("didukung vs baru"), bukan gap *app*.
- **C2 — Routing: NIHIL untuk app baru.** `plan/SKILL.md` (line 40) cuma meng-handle *"app belum punya fondasi (skeleton belum jalan) → jalankan `wire`"* — itu app yang **sudah terdaftar tapi belum di-wire**. Tidak ada skill yang merutekan "app belum ada sama sekali di `workspace.yaml`".
- **C3 — Deklarasi: HANYA `init`.** `init/SKILL.md` step 5 satu-satunya yang menulis entri `apps[]` ke `workspace.yaml`. `architect`/`wire` bilang *"bisa di-rerun saat nambah app"* (`architect/SKILL.md` line 44, `wire/SKILL.md` line 47) tetapi keduanya **membaca** entri app — **tidak membuatnya**. `fanout` step 4 cuma meng-**update `capabilities`** app existing (add-only-if-absent), tak pernah menambah entri app.

Akar: spec induk §16 (line 262–263) menaruh "orchestrator" lintas-app sebagai *future* dan **tak pernah menyebut** "nambah app mid-product" — bukan v1, bukan future. Benar untuk v1 awal; kini jadi friksi struktural karena hilir (`breakdown` reference line 15 wajib `task.app` cocok `apps[].name`; `build` line 18 `git -C <path>` dari `workspace.yaml`) **gagal/crash** kalau app tak terdaftar.

## 3. Tujuan & Non-Tujuan

**Tujuan:**
- Menutup blind spot "fitur butuh app baru" dengan satu skill `add-app` yang menjadi **satu-satunya penulis entri app baru ke `workspace.yaml` pasca-`init`**.
- `add-app` = **konduktor tipis**: declare entri app → invoke `architect` (stack) → invoke `wire` (bring-up) → balikin ke `feature`. **Tiap tahap memakai gate skill yang dipanggil**; berat-beratnya tetap milik skill existing.
- **Deteksi di `fanout`** + **anti-yes-man challenge** ("beneran butuh app baru, atau scope-creep / bisa ditampung app existing?") sebelum app baru diusulkan.
- **Auto-invoke oleh `feature`**: saat `fanout` menandai app baru, `feature` invoke `add-app` (gated) lalu lanjut `plan` — satu alur nyambung, tapi `feature` menyetir `add-app` (bukan `architect`/`wire` langsung).
- **Bisa standalone** — `add-app <name>` dipicu sendiri untuk numbuhin produk di luar pipeline fitur.
- **Idempotent** — app yang sudah ada di `workspace.yaml` → STOP, jangan re-declare.

**REVISI terhadap spec induk:** spec induk **tidak pernah** mendefinisikan jalur "nambah app setelah `init`" (§16 line 262–263 hanya v1 + future-orchestrator). Spec ini **menjadikan "nambah app mid-product" in-scope** sebagai skill tersendiri — terbatas pada **deklarasi + bring-up satu app**, bukan eksekusi kode fitur (itu `build`).

**Non-Tujuan:**
- `add-app` **bukan** `init`. Ia tidak bootstrap produk, tidak deteksi topologi, tidak scaffold `control/`. Ia mengasumsikan `control/` sudah ada (kalau belum → arahkan ke `init`).
- `add-app` **tidak** memutuskan stack (itu `architect`) dan **tidak** scaffold/DB/wiring/smoke sendiri (itu `wire`). Ia delegasi.
- `add-app` **tidak** men-handle **shared package** (ui-kit/types/dll) di v1. Shared package tak punya DB/FE↔BE/smoke — beda cabang. Di-defer (lihat §12 Future). Catatan `architect` "nambah app/shared package" tetap; `add-app` fokus **app** (fe/be/fullstack).
- `add-app` **tidak** membuat repo fisik untuk multi-repo. Ia mencatat `path` + `repo_url`; bring-up fisik di-defer ke `wire` + user (gated) — konsisten prinsip `init` "repo app TIDAK dimigrasi/dikelola hub".
- **Tidak** ada eksekusi kode fitur. App baru keluar dari `add-app` sebagai **skeleton kosong-tapi-jalan**; table/endpoint fitur = jatah `build`.

## 4. Lifecycle: `add-app` sebagai cabang yang dipicu

```
Jalur lurus (tak berubah):
  … → architect → wire → feature(intake → fanout → plan) → breakdown → build → ship

Cabang "fitur butuh app baru" (auto, via feature):
  feature → intake → fanout ──(flag: app baru)──▶ add-app <Y> ──▶ plan(X + Y) → …
                                                     │
                                            (declare entri → architect → wire)

Standalone (numbuhin produk langsung):
  add-app <name>   → declare → architect → wire → "siap di-feature"
```

`add-app` **dipicu** — bukan tahap wajib di jalur lurus. Dipanggil otomatis oleh `feature` saat `fanout` menandai app baru, atau eksplisit oleh user.

## 5. Identitas & Batas (dedup `init` / `architect` / `wire` / `fanout`)

Sumbu konseptual spec: **siapa yang menulis entri app, dan kapan.**

| Dimensi | Pemilik | Catatan |
|---|---|---|
| Bootstrap produk + declare app **awal** | `init` | sekali, di awal; deteksi topologi + scaffold `control/` |
| Declare entri app **baru pasca-init** | **`add-app`** | satu-satunya penulis entri baru setelah `init` |
| Pilih stack (framework/db/orm) | `architect` | dipanggil `add-app`; juga jalan standalone (set/recapture) |
| Scaffold / DB / wiring / env / smoke | `wire` | dipanggil `add-app`; bring-up skeleton |
| Mapping fitur→app + **deteksi butuh app baru** | `fanout` | mengusulkan, **tidak** menulis entri |

Pemisahan bersih:
- **`init` vs `add-app`:** `init` = bootstrap produk (topologi + `control/` + app **awal**). `add-app` = numbuhin produk **existing** dengan **satu** app. Tidak tumpang tindih: `add-app` menolak jalan bila `control/` belum ada.
- **`add-app` vs `architect`/`wire`:** `add-app` menulis **identitas** app (name/path/type/responsibility) lalu **memanggil** `architect` (stack) + `wire` (bring-up). `architect`/`wire` tetap bisa jalan standalone, tapi cara **kanonik** nambah app = lewat `add-app`. Catatan "bisa di-rerun saat nambah app" di `architect`/`wire` diklarifikasi mengarah ke `add-app` (§11).
- **`add-app` vs `fanout`:** `fanout` **mengusulkan** app baru (nama + peran, ditandai `NEW`); `add-app` yang **mewujudkan** (tulis entri + bring-up). `fanout` tak pernah menulis entri app.

## 6. Skill `add-app` — Prosedur

- **Tujuan:** mendeklarasi satu app baru ke `workspace.yaml` lalu men-chain fondasinya hingga skeleton kosong-tapi-jalan, di bawah gate, lalu menyatakan app **"siap di-`feature`"**.
- **Input:** nama app (arg/usulan `fanout`) + `control/workspace.yaml` (`topology` + apps existing). Dijalankan dari root produk yang punya `control/`.
- **Prasyarat:** `control/workspace.yaml` ada. Bila tidak → ini bukan `add-app`; arahkan ke `init`.
- **Perilaku (urut; tahap berat memakai gate skill yang dipanggil):**
  - **(0) Baca state.** Baca `topology` + apps existing dari `workspace.yaml`.
  - **(1) Cek duplikat (idempotent).** Kalau `<name>` sudah ada di `apps[]` → **STOP**, jangan re-declare. Bila user cuma mau melengkapi → arahkan ke `architect`/`wire`.
  - **(2) Q&A identitas app (singkat — level DEKLARASI, bukan stack).** Tanya: `name`, `type` (fe/be/fullstack), `responsibility` (1 kalimat). **Derive `path` dari `topology`:** monorepo → `apps/<name>`; multi-repo → `../<name>` + minta `repo_url` (boleh kosong bila repo belum dibuat). **JANGAN** tanya framework/db/orm di sini — itu jatah `architect` di langkah 4.
  - **(3) Tulis entri ke `workspace.yaml` (GATE).** Tambah entri app baru dengan `capabilities: []`, `stack: {}` (diisi tahap berikut). **Add-only-if-absent.** Tampilkan diff `workspace.yaml` → minta **approve**.
  - **(4) Invoke `architect` untuk app ini** (pakai gate-nya `architect`, SETUP mode). Q&A teknikal → tulis `stack`, cek divergensi konvensi vs app lain, update `conventions.md` bila perlu. `add-app` **tidak** menetapkan stack — `architect` yang punya.
  - **(5) Invoke `wire` untuk app ini** (pakai gate-gate `wire`, greenfield). Scaffold (tool resmi) → DB → BE↔DB → FE↔BE → env → smoke test → skeleton kosong-tapi-jalan.
  - **(6) Tutup & balikin.** Lapor "app `<name>` siap di-`feature`". Dipanggil `feature` → kembalikan kontrol ke `feature` (lanjut `plan`). Standalone → saran langkah berikutnya.
- **Output:** entri app baru di `workspace.yaml` (stack terisi oleh architect, capabilities masih `[]`) + skeleton kosong-tapi-jalan di `path`-nya (hasil `wire`). `add-app` sendiri **tidak** menulis kode framework, DB, atau `business/*`.
- **Gate:** GATE sendiri di langkah 3 (tulis entri); langkah 4 & 5 memakai gate `architect`/`wire`. `add-app` tidak menambah gate baru di atas itu.
- **File:** hanya `plugin/skills/add-app/SKILL.md` (skill tipis — tanpa `reference.md`; prosedur berat ada di `architect`/`wire`).

## 7. Deteksi di `fanout`

Tambahan minimal di `fanout/SKILL.md`, menjaga `fanout` tetap "P1 mapping, bukan penulis entri":

- **Step 2 (Petakan ke app) — cabang baru:** setelah mencocokkan kebutuhan fitur ke `capabilities`/`responsibility` app existing, bila ada **peran yang tidak tertampung app mana pun**:
  - **Challenge (anti-yes-man):** "beneran butuh app baru, atau scope-creep / bisa ditampung app existing?" App baru itu mahal — jangan gampang menelurkannya.
  - Lolos challenge → tandai di output: `<usulan-nama> (NEW — belum ada) : <peran>`.
- **Step 3 (Challenge Checklist) — tambah 1 baris:** *"Ada peran yang tidak tertampung app mana pun → butuh app baru? (beneran perlu, atau scope-creep?)"*
- **Step 4 (output):** `fanout.md` boleh memuat app bertanda `NEW`. `fanout` **tetap tidak** menulis entri ke `workspace.yaml` (itu `add-app`); update `capabilities` tetap hanya untuk app existing.

## 8. Auto-invoke di `feature`

Sisipan di `feature/SKILL.md` step 2 (urutan tahap), di antara gate `fanout` dan `plan`:

> **2.5 — Bila `fanout.md` menandai app `NEW`:** untuk tiap app baru, **invoke `add-app <name>`** (yang declare → `architect` → `wire`, semua gated) → tunggu beres → **baru lanjut `plan`**.

Saat `plan` jalan, app baru sudah ada di `workspace.yaml` **dan** sudah di-wire, jadi `plan` (yang "membaca yang ADA") menemukan fondasi siap. Guard `plan` line 40 ("app belum punya fondasi → `wire`") tetap sebagai safety net.

## 9. Kasus Campuran (app lama + app baru dalam 1 fitur)

Natural, tanpa logika khusus:
- `fanout.md` mendaftar mis. `X (existing, peran)` + `Y (NEW, peran)`.
- `feature` invoke `add-app` **hanya** untuk `Y`; `X` jalan biasa.
- `plan` mem-plan `X` **dan** `Y`; kontrak lintas-app `X↔Y` ditangani `plans/_shared.md` (mekanisme `plan` step 2 yang sudah ada).

## 10. Topology / Multi-repo

- **Monorepo:** `path = apps/<name>` (atau konvensi yang terbaca). Folder app dibuat oleh scaffolder di langkah `wire`; `add-app` cuma mencatat `path`.
- **Multi-repo:** `add-app` mencatat `path: ../<name>` + `repo_url` (boleh kosong bila belum ada). **Pembuatan repo fisik (git init / remote) di-defer ke `wire` + user** (gated), bersandar pada penanganan multi-repo `wire` (`wire-skill-design` §13) dan prinsip `init` "repo app tidak dimigrasi/dikelola hub". `add-app` tidak membuat repo sendiri.

## 11. Dampak ke Komponen Existing

- **Skill baru:** `plugin/skills/add-app/SKILL.md` (SKILL.md saja, tanpa reference.md).
- **`fanout/SKILL.md`:** tambah cabang deteksi (step 2) + 1 baris Challenge Checklist (step 3) + izinkan marker `NEW` di output (step 4); pertegas "fanout mengusulkan, tidak menulis entri".
- **`feature/SKILL.md`:** sisip step 2.5 auto-invoke `add-app` untuk app `NEW` sebelum `plan`; sesuaikan baris prasyarat.
- **`architect/SKILL.md` (line 44):** klarifikasi catatan "bisa di-rerun saat nambah app" → cara kanonik nambah app = `add-app` (yang memanggil architect); architect standalone tetap untuk set/recapture stack, **tidak** menulis entri app baru.
- **`wire/SKILL.md` (line 47):** klarifikasi "bisa di-rerun saat nambah app" → dipanggil oleh `add-app` untuk app baru.
- **`init/SKILL.md` (step 3, "boleh mulai dari satu, tambah nanti"):** "tambah nanti **via `add-app`**". `init` tetap declare app **awal** saat bootstrap.
- **`plan/SKILL.md`:** tidak berubah (app sudah ada + wired saat plan jalan); guard "app belum punya fondasi → wire" tetap.
- **`README.md`:** tambah `add-app` ke daftar skill + gambarkan cabang mid-`feature` di lifecycle.
- **`plugin/.claude-plugin/plugin.json`:** sebut `add-app` di deskripsi (sejajar penambahan `wire`).
- **Spec induk `2026-05-24-…-design.md`:** §12 Lifecycle — tambah catatan cabang-dipicu (`feature` → `add-app` saat butuh app baru); §17 Komponen — tambah `add-app` (Skills 14 → 15). (§9 detail per-skill & §16 v1-list **dibiarkan** seperti perlakuan saat `wire` ditambahkan — tidak ditambah subsection/entri baru; §16 sudah stale sejak sebelum `wire`. Status "in-scope" dinyatakan konseptual di §3 spec ini.)

## 12. Scope v1 & Future

- **v1 (in):** skill `add-app` (prosedur §6, identitas/batas §5), deteksi `fanout` (§7), auto-invoke `feature` (§8), kasus campuran (§9), topology/multi-repo (§10), edit dedup + doc (§11). **App fe/be/fullstack saja.**
- **Future:**
  - **Shared package** (ui-kit/types/dll) lewat cabang khusus tanpa DB/FE↔BE/smoke.
  - **Pembuatan repo multi-repo otomatis** (gh repo create / git init + push) ketimbang manual.
  - **Penghapusan/penggabungan app** (kebalikan `add-app`) — saat ini di luar scope.
  - Multi-app sekaligus dalam satu run `add-app` (default v1: satu app per invocation; `feature` loop untuk beberapa `NEW`).

## 13. Open Questions (untuk tahap perencanaan)

- **Konfirmasi nama vs usulan `fanout`.** Saat `feature` auto-invoke, apakah `add-app` menerima `name` usulan `fanout` apa adanya atau selalu re-konfirmasi nama+type+responsibility ke user di langkah 2? Default usul: **selalu konfirmasi singkat** (identitas app krusial & murah).
- **Granularitas gate saat dipanggil `feature`.** Karena `add-app` men-chain `architect`+`wire` (masing-masing punya banyak gate), apakah perlu satu "ringkasan rencana app baru" di awal sebelum semua gate, agar user tahu komitmennya? Default usul: tampilkan ringkasan (app + path + rencana chain) sekali, lalu gate per-skill berjalan normal.
- **Posisi `add-app` saat `feature` punya beberapa app `NEW`.** Eksekusi sekuensial (satu `add-app` per app baru) — dikonfirmasi v1. Apakah perlu memesan urutan (mis. BE sebelum FE bila ada kontrak)? Default usul: ikuti "Urutan" yang sudah ditulis `fanout.md` bila ada.
- **Apakah `add-app` perlu mencatat artifact** (mis. menandai app `pending`/`wired`) atau cukup deteksi dari `workspace.yaml` + kode. Diputuskan saat implementasi (sejajar open question `wire`).
