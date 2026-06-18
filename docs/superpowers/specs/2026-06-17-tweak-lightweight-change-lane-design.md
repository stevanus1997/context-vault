# Desain: skill `/tweak` — jalur ringan berjejak

**Tanggal:** 2026-06-17 (rev.3 2026-06-18 pasca 2× red-team)
**Status:** Draft untuk review
**Asal:** Feedback user plugin (#1 dari beberapa) — "build kelamaan buat hal simpel, jadi user kabur; tapi pas kabur, perubahan kecil-tapi-berdampak nggak ke-capture di `control/`."

> **Revisi:** rev.1 → rev.2 (5 blocker: ownership `control/`, floor-scan, tripwire-leak, greenfield-invariant, decision-home) → rev.3 (semua blocker resolved & terverifikasi ke source; rev.3 mempertajam tripwire jadi **daftar-verba mekanis + precedence cabang** dan ngerapihin kontradiksi internal: `rate-limit` dobel-klasifikasi, contoh diskon vs file-sensitivity, urutan cek, idempotensi multi-writer).

---

## 1. Konteks & Masalah

Plugin `context-vault` punya value: nangkep keputusan & knowledge produk ke `control/` (sumber kebenaran yang dibaca skill lain). Tapi satu-satunya jalur naro perubahan ke produk lewat plugin adalah pipeline berat: `feature → fanout → plan → breakdown → build → ship` — **overkill buat perubahan kecil**, jadi user kabur ke plain Claude Code. **Kerugian sebenernya bukan kecepatan — tapi capture yang ilang.** Perubahan kecil sering kasus **(c): diff kecil tapi sekaligus keputusan bisnis berdampak** (mis. "diskon maks 20%→30%"). Pas user kabur, jejaknya ilang dari `control/`; pas fitur berat berikutnya, konteks keputusannya udah ilang.

**Akar masalah:** value (capture) ke-*bundle* sama cost (eksekusi berat). Pilihan cuma "mesin penuh atau nggak sama sekali". **Nggak ada jalur ringan yang tetep ninggalin jejak.**

## 2. Tujuan & Non-Tujuan

**Tujuan:** jalur **cepat** buat perubahan kecil yang **tetep capture ke `control/`**; bikin user yang kadung trauma "berat" balik pake plugin (**sukses = user yang biasa kabur TETAP di skill sampai capture kejadian**); jaga bar kualitas (TDD + anti-yes-man + floor keamanan) — cepet karena buang **birokrasi**, bukan nurunin bar; aman jadi default (tripwire auto naik-kelas).

**Non-Tujuan:** ❌ surface `control/` baru (`decisions.yaml` ditunda) · ❌ `fanout`/`plan`/`breakdown`/`tasks.yaml`, manifest, nandai `shipped` · ❌ review 2-tahap, gate per-segmen, unattended, orkestrasi subagent per-task · ❌ nulis ke `conventions.md`/`integrations.md`/`invariants.md` (single-owner skill lain) · ❌ lane defect (→`fix`) / kerjaan gede-fondasional (→`feature`) · ❌ resumable (single-session by design, §10).

## 3. Posisi vs `fix` / `feature`

| Skill | Kapan | Manifest? |
|---|---|---|
| **`tweak`** | perubahan **kecil**, bukan bug, nggak fondasional — raih duluan | ❌ atomik, nggak di-track |
| `fix` | perilaku lama yang *salah* (defect) | ✅ `fix.yaml` (open→diagnosed→shipped) |
| `feature` | kapabilitas baru / gede / lintas-app / fondasional | ✅ `feature.yaml` (active→shipped) |

Model mental: *"ada perubahan? raih `tweak` dulu. Dia sendiri yang bilang 'eh ini feature/bug, naik kelas yuk' lewat tripwire."*

## 4. Alur `/tweak <apa>`

Jalan dari root produk yang punya `control/`.

1. **Baca state minimal.** `control/workspace.yaml` (apps + stack + path) + cek branch. `business/*`/`glossary` dibaca **lazy** (pas capture perlu). **Pengecualian:** `invariants.md` **WAJIB** dibaca buat evaluasi tripwire cabang-B (kecuali perubahan lolos sebagai murni-kosmetik) — lazy-read TIDAK berlaku buat cabang-B. Hormatin "jangan commit di `main`/`master` tanpa izin" (§10).
2. **Triage + Tripwire (3 cabang, precedence tetap) — SEBELUM nyentuh kode.** Lihat §5.
3. **Bikin perubahan — TDD otomatis, inline.** Skill yang **nulis test sendiri** (merah→implement→ijo), bukan nyuruh user. Edit **inline** (tanpa orkestrasi subagent per-task). Pengecualian sempit: murni nggak-berperilaku (copy/format/rename) → nggak ada yang dites (≠ "boleh logika tanpa test"). **TDD = jaminan KOREKTIFITAS, bukan keamanan** (§9).
4. **Capture keputusan (kalau ada).** Lihat §6.
5. **Gate (anti-yes-man).** **Floor-scan WAJIB dulu** (§9): scan diff buat (a) **secret hardcoded** + **PII di log/response**, (b) **pola security-loosening** (toggle auth→false, hapus middleware auth/validasi, TTL membesar, hapus signature-check). Kena → STOP. Lalu tampilin diff + update knowledge + alasan + hasil test + **Challenge Checklist TERISI** (`Bentrok aturan: <isi> · Tradeoff: <isi> · Alternatif simpel: <isi> · Yang bisa jebol: <isi>`) → **approve/revisi**.
6. **Finish — sampai PR (§8).** Commit (rasionale di pesan) → buka PR. Satu perintah.

## 5. Tripwire — 3 cabang + precedence (pengaman utama)

**Precedence algoritmik (urutan: B → C → A):**
- **Cabang B (keamanan) & C (defect) SELALU dievaluasi & TIDAK bisa di-override** user.
- **Override-sadar HANYA buat cabang A**, dan HANYA buat sub-trigger judgment **"revamp gede / kapabilitas baru"** — **BUKAN** buat sub-trigger ">1 unit/app", "ubah kontrak shared", atau "sentuh stack/conventions/integrations" (itu yang bikin multi-repo & nyentuh single-owner → **hard-escalate**, nggak bisa override).
- Lolos B + C + A → jalur ringan.

Dua sumbu: **UKURAN** (cabang A — "kecil apa gede", axis utama) & **RISIKO** (cabang B — jaring buat "kecil-secara-diff TAPI bahaya", mis. `requireAuth:true→false` 1 baris). Jaring B ada *justru karena* user mikir ukuran → cek-nya **mekanis (daftar verba), bukan judgment**.

### Cabang A — ukuran/fondasional → `/feature`
Definisi **sejalan `build` step 6** (`>1 app`), digeneralisasi ke **unit nyata** (app *atau* package, konsisten grouping `ship`): sentuh **stack** / `conventions.md` / **shared package** / `integrations.md`, ATAU **lintas >1 unit**, ATAU **ubah kontrak shared**, ATAU **kapabilitas baru / revamp gede**. (Bukan klaim "verbatim" — digeneralisasi.)
→ Kena: berhenti, jelasin, **invoke `/feature`** seedin konteks. Override-sadar: lihat precedence (cuma sub-trigger revamp/kapabilitas).

### Cabang B — keamanan → HARD-STOP (nggak bisa di-talk-out)
Cek **mekanis** lewat daftar verba eksplisit (ditulis di SKILL.md). Kena salah satu = STOP; satu-satunya maju = `/feature` → `ship` Security Gate.
- **Verba-keamanan:** authentication/authorization · session/token/TTL · CORS/origin · role/permission check · **rate-limit/throttle/quota (semua yang fungsinya abuse/DoS-prevention)** · validasi input · **serialization/deserialization & query-building (surface injection)** · **tenant/tenancy isolation filter** · **mode test/live vendor** · secret/credential.
- **Verba-uang (PLUMBING):** charge/capture · refund · payout/settlement/transfer · simpan PAN/instrumen-bayar/token-kartu. (Heuristik sensitivity `intake` + `rules/compliance-risk.md` = **PENGUAT**, bukan classifier utama — daftar verba di atas yang operasional.)
- **PII:** kumpulin/simpan/tampilin data pribadi, ATAU **MEMPERLUAS surface PII yang udah ada** (un-masking, nurunin redaction, nambah audience, propagate ke log/analytics/response/pihak-ketiga). (Bukan cuma "data baru".)
- **Invariants:** keputusan yang **rumahnya `invariants.md`** → eskalasi (tweak nggak boleh nulis `invariants.md`). **Degrade pesimis:** slot relevan masih `<belum dikunci>` (belum di-`architect`) → treat **fondasi-belum-dikunci** → eskalasi.
- **Fail-safe:** ragu apakah suatu perubahan/limit punya fungsi keamanan → treat sebagai keamanan (eskalasi).

### Garis ANGKA-KEBIJAKAN vs PLUMBING (decidable — biar contoh diskon nggak ketabrak)
**Lolos** cabang-B = ngubah **angka kebijakan bisnis** dari daftar-putih: **diskon maks, threshold gratis-ongkir, page-size**, dan angka sejenis yang **murni kebijakan, bukan fungsi keamanan**. → di-capture ke `domain.md`; risiko bisnisnya dijaga **Challenge Checklist** (§6), bukan Security Gate.
- **`rate-limit`/`throttle`/`quota` BUKAN di sini** — itu cabang-B (keamanan).
- **Precedence file-sensitivity:** "diff nyentuh file/modul ber-sensitivity" memicu STOP **HANYA bila diff nyentuh PLUMBING** (verba-uang/kolom-data), **BUKAN** bila cuma ngubah angka kebijakan. → diskon-cap di file pricing yang payments-sensitive **tetep lolos** (ganti angka kebijakan, bukan plumbing).

### Cabang C — defect → `/fix`
Triage **by framing user**: "salah / harusnya / bug" → `/fix`; "naikin / ganti / ubah jadi" → `tweak`; **ambigu → tanya satu pertanyaan** ("ini perilaku lama yang *salah*, atau keputusan baru?"). Beda kunci: tweak = ngubah keputusan (lama nggak salah); fix = lama salah (punya disiplin reproduce→root-cause).

## 6. Capture — ownership-correct, no-new-surface

`tweak` make ulang **pola idempotent** `intake` step 7, dengan batas ownership ketat:
- **Tulis langsung HANYA ke `business/domain.md · flows.md · glossary.md`.** Ketiga file ini memang **multi-writer** (`intake` step 7 **dan** `extract` sudah nulis ke sini) — jadi `tweak` = penulis sah ke-3, bukan nyerobot. Beda dari `conventions.md`/`integrations.md`/`invariants.md` yang **single-owner-gated** → `tweak` **route/eskalasi**, nggak nulis (100% pola `ask`).
- **Format alasan inline** = marker eksplisit, mis. `<!-- tweak: <YYYY-MM-DD> — <kenapa> -->` di sebelah fakta. **Ini aturan BARU `tweak`**, bukan warisan `intake` (intake cuma idempotent, tanpa alasan-inline).
- **Idempotensi bandingin FAKTA saja** (abaikan blok alasan) → re-run `tweak`/`intake`/`extract` nggak duplikat.
- **Rule-change vs konstanta (decidable):** ngubah **ANGKA pada aturan yang SUDAH ADA** di `domain.md` = **konstanta** → cukup **Challenge Checklist** (anti-yes-man udah cukup nantang). **Bikin aturan BARU / restruktur aturan** = **rule-change** → **critic independen** nilai usulan SEBELUM ditulis (anti-circular, §9). (Diskon 20→30 = konstanta → Checklist — nurunin friksi, tetep anti-circular di tempat yang penting.)
- **No-home fallback (deterministik):** pilih kandidat by jenis fakta (aturan→`domain`, langkah→`flows`, istilah→`glossary`); jenis nggak jelas → default `domain.md` **TAPI** tampilin di gate step 5 ("capture ke domain.md — pindahin?"). Jangan diam-diam drop.
- Murni kosmetik tanpa keputusan → skip capture.

Truth terkini kejaga + cerita kejaga (alasan inline + commit). **Nol surface baru.**

## 7. TDD — wajib, otomatis, korektifitas-saja

TDD bukan sumber berat `build`; di `tweak` malah makin penting (kasus c: kecil tapi berdampak = paling rawan regresi). Friksi ditekan via **TDD otomatis** (skill nulis test, bukan user), bukan dengan ngebuang test. **TDD ngebuktiin kode ngelakuin yang test minta — TIDAK ngejamin perubahannya aman** (kalau perubahannya sendiri bahaya, test ijo malah ngesahin). Keamanan = cabang-B + floor-scan, bukan TDD.

## 8. Finish sampai PR + batas vs `ship`

`tweak` finish sendiri sampai PR (satu perintah) supaya perubahan kecil nggak nyangkut "ke-commit tapi nggak ke-ship".

**Kenapa boleh nge-PR padahal `fix` nggak (BUKAN inkonsistensi):** `ship` pemilik **siklus status manifest** — satu-satunya yang majuin `status: shipped` (ship/SKILL.md:46,50). `fix` punya `fix.yaml` berlifecycle → **butuh `ship` nutup lifecycle** (fix/SKILL.md:53). `tweak` **nggak punya manifest** (atomik) → nggak ada lifecycle buat ditutup → finish sendiri. Buka PR sendiri = perilaku baru yang **sah karena beda jenis**, bukan nyerobot `ship`.

**Visibility (dua kanal, jujur):** (a) **`ask` = baca-live** → tweak-capture di `business/*.md` langsung kelihatan ✅. (b) **`render-docs` = generate HTML satu-arah, default-skip** → **bisa STALE** sampai di-regen. Diakui eksplisit; user boleh `render-docs` manual / kita bikin refresh non-opsional kalau ada capture (lihat §12). Tweak kosmetik tanpa-capture = git history aja (wajar).

**Mekanik PR (reuse `ship`):** branch `tweak/<slug>` (kalau di `main`/`master` → izin/checkout dulu); base-branch ala `ship` (symbolic-ref; **tanya** kalau ambigu); **multi-repo:** karena override-sadar TIDAK berlaku buat ">1 unit", tweak paling banyak nyentuh **1 unit app** → kode di repo app + capture di repo hub `control/` → **PR di repo app**; **NGGAK** pakai `finishing-a-development-branch` (jatah `ship`).

**Batas vs `ship`:** `ship` tetep buat `feature`/`fix` (gate berat + alignment + nutup `shipped` + render-docs). `tweak` finish tipis (commit→PR) — sah karena nggak ada lifecycle buat ditutup, BUKAN karena gate ship nggak penting.

## 9. Keamanan finish — berlapis, dipisah dari TDD

Klaim "lolos tripwire + TDD-ijo = aman" **dibuang**. Keamanan ditegakkan berlapis & mekanis:
1. **Cabang-B tripwire** (daftar verba, §5) — di niat, sebelum kode.
2. **Floor-scan WAJIB** atas diff final (step 5): (a) secret hardcoded + PII di log/response (persis quick-scan `ship` sensitivity-kosong), **(b) pola security-loosening** (auth toggle→false, hapus middleware auth/validasi, TTL membesar, hapus signature-check) — karena floor-scan secret/PII saja TIDAK nangkep pelonggaran.
3. **Critic** di-trigger **mekanis** (bukan "borderline" yang dinilai-sendiri): SELALU buat **rule-change** (bikin/restruktur aturan, §6) ATAU diff nyentuh **verba-keamanan/uang**. Konstanta angka-kebijakan → cukup Challenge Checklist.
4. **Alignment-to-business BUKAN otomatis** (anti-circular): penulis-aturan ≠ penilai → rule-change lewat critic independen dulu.

Apa pun yang butuh Security & Compliance Gate penuh udah dieskalasi cabang-B → `feature` → `ship`.

## 10. State/resume & multi-repo
- **NON-resumable, single-session by design.** Nggak ada manifest/state. Interupsi → **re-run dari awal**, sandar git (ter-commit kelihatan, capture idempotent, un-committed dibuang). Eksplisit.
- **Multi-repo:** §8 (split `control/`+app; max 1 unit app karena cabang-A).

## 11. Testing & verifikasi skill
- **Front-matter `description`:** disambiguasi eksplisit dari `fix` (*"BUKAN koreksi perilaku salah → `/fix`"*) & `feature` (*"BUKAN kapabilitas baru/lintas-app/fondasional → `/feature`"*).
- **Triggering (+):** "naikin diskon maks 30%", "ganti default page size" → `tweak`. **(−):** "X-nya salah, harusnya Y" → `/fix`; "tambah login SSO" → `/feature`.
- **Tripwire:** `requireAuth true→false`/ubah TTL/longgarin validasi/**naikin rate-limit** → cabang-B hard-stop; produk belum-`architect` (invariants `<belum dikunci>`) di area relevan → eskalasi; ubah refund/charge → eskalasi; **diskon-cap di file payments-sensitive → LOLOS** (angka kebijakan, bukan plumbing); un-masking PII existing → cabang-B.
- **Precedence:** diff yang nyalain A (override-able revamp) + B sekaligus → **B menang (hard-stop)**.
- **Capture:** rule-change → critic dipanggil; konstanta → Checklist saja; re-run nggak duplikat (idempotensi fakta-saja); `conventions/integrations/invariants` → route, bukan tulis.
- **Floor-scan:** secret hardcoded / PII di log / `auth=false` → STOP step 5.
- **Anti-yes-man:** gate nampilin Challenge Checklist **terisi**.

## 12. Pertanyaan terbuka / ditunda
- **Jurnal keputusan** (`decisions.yaml`) — ditunda sampai catatan inline kebukti berantakan.
- **`render-docs` refresh** step 6 — sekarang default-skip (akui stale, §8); bisa dijadiin non-opsional saat ada capture kalau stakeholder butuh HTML selalu segar.
- **Nama final** — `tweak` (terpilih).
