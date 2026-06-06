# M8 — Observability Feedback Loop (sinyal lapangan durable → dibaca intake sebagai input SOFT)

> Langkah-3, gap **M8** (LOW) — fix-light. Tanggal: **2026-06-06**. Repo `~/Developer/ai-boilerplate`, base `main` @ `1dba8d1`.
> Usulan awal (BUKAN keputusan final): "Produk live hasilkan incident tapi nggak ada jalan balik ke intake. Fix: `control/feedback/` (template dir) + intake baca sbg input SOFT (bukan gate)." Spec ini mengunci keputusan via section **Decisions** (§2) — tiap fork desain didokumentasikan plain-language agar user bisa veto (ganti brainstorming 1-1).

## 1. Ringkasan

Lifecycle hari ini **satu-arah** (`discovery → init → … → build → ship`), dengan satu lane balik untuk **defect terkonfirmasi** (`/fix` → `control/fixes/`). Tapi produk yang sudah live menghasilkan **sinyal lapangan mentah** — keluhan user, incident ops, request fitur, insight analytics — yang **belum tentu bug** dan **tak punya rumah**. Sinyal itu hilang: tak ada artifact durable, tak ada skill hilir yang membacanya saat merencanakan fitur berikutnya. "Jalan balik ke intake" putus.

M8 menambah **satu direktori durable** `control/feedback/` (template-dir kosong, cermin preseden `fixes/`/`docs/`/`features/` yang scaffold lewat `init`) tempat **manusia (operator/user) men-drop file sinyal lapangan** secara manual. `intake` membacanya di step 2 (Baca knowledge) sebagai **input SOFT** — memunculkan sinyal relevan saat merencanakan fitur, **bukan** gate, **bukan** blokir. Cermin pola M6 `risks.md`: input durable yang dibaca hulu, advisory, degrade-mulus bila kosong/absen.

> **Catatan jujur (advisory di hulu, BUKAN gate, BUKAN pipeline).** M8 **murni advisory** di `intake` — ia memperkaya elicitation (intake "baca + munculkan sinyal relevan"), **tak** memblokir fitur, **tak** menambah gate. **Penulis = manusia** (drop file manual); **TIDAK ADA skill penulis baru, tidak ada auto-ingest/observability-pipeline.** `control/feedback/` kosong/absen → `intake` jalan persis seperti sekarang (degrade-mulus). Logika ini ditulis jujur di surface tempat ia beneran jalan: `intake/SKILL.md` step 2 (baca SOFT) + step 5 Challenge Checklist (paksa-tampil sinyal relevan ke user — cermin M6).

M8 **tak menggandakan** lane `fix`: `feedback/` = **hulu mentah** (sinyal yang belum tentu bug — bisa feature-request/insight); `fixes/` = **defect terkonfirmasi** (reproduce → root-cause → TDD). Garis batas itu eksplisit di template + di klausa intake (§2 D5, §6).

**Tak ada skill baru** (skill tetap **21**); **tak ada rule baru** (rules tetap **5** — M8 cukup ringan untuk hidup sebagai klausa di `intake/SKILL.md` + README di template-dir, tak butuh "otak bersama" — lihat §2 D6). **Tak ada gate baru, tak ada fase lifecycle baru.**

## 2. Decisions (tiap fork desain + alternatif yang ditolak)

> Section ini **mengganti brainstorming 1-1**: dokumentasi plain-language setiap keputusan yang author putuskan sendiri, biar user bisa **veto**. Tiap keputusan menandai (▶ DIPILIH) vs (✗ DITOLAK + alasan).

### D1 — Penulis feedback: **manusia (drop manual)** vs skill auto-ingest
- ▶ **DIPILIH: penulis = manusia.** Operator/user men-drop file sinyal (mis. `control/feedback/2026-06-10-checkout-timeout.md`) secara manual. Pembaca = `intake`. Tak ada skill yang menulis ke `feedback/`.
- ✗ **DITOLAK: skill penulis baru / auto-ingest observability** (mis. `/feedback` yang nyedot Sentry/PagerDuty/analytics). Alasan: fix ini **LOW = fix-light**. Auto-ingest = pipeline observability penuh (integrasi vendor monitoring, dedup, severity-scoring) → balloon jadi sub-proyek, jauh dari "light". Plugin juga **generik** — tak boleh hardcode satu vendor monitoring. Manual drop = minimal-viable yang langsung menutup "jalan balik ke intake" tanpa mesin baru. (FLAG di §8: M8-FLAG-A.)

### D2 — Sifat: **input SOFT (advisory)** vs gate
- ▶ **DIPILIH: SOFT/advisory.** `intake` membaca `feedback/` dan **memunculkan** sinyal relevan ke user saat Q&A/Challenge — tak memblokir, tak menggagalkan. Cermin M6 (`risks.md` advisory).
- ✗ **DITOLAK: gate "intake BLOCK kalau ada feedback unresolved".** Alasan: usulan eksplisit bilang "input SOFT (bukan gate)". Gate baru langgar fix-light + nambah palang keras (preseden induk: satu-satunya STOP keras = Security Gate `ship`). Lagipula sinyal lapangan **belum tentu actionable** untuk fitur yang sedang di-intake — memaksa resolusi = friksi tanpa nilai. (FLAG di §8: M8-FLAG-C.)

### D3 — Rumah: **dir baru `control/feedback/`** vs nebeng `fixes/` vs file tunggal
- ▶ **DIPILIH: dir baru `control/feedback/`** (template-dir, cermin `fixes/`/`docs/`/`features/`). Banyak sinyal kecil → satu-file-per-sinyal lebih rapi & mudah di-drop manual; dir kosong scaffold otomatis lewat `init` step 4 `cp -R`.
- ✗ **DITOLAK: nebeng `control/fixes/`.** Alasan: `fixes/` = defect terkonfirmasi (ada `fix.yaml` status/severity/root_cause, lane ber-build/ship). Sinyal mentah belum tentu bug → mencampur bikin lane fix kotor & membingungkan "taruh di mana" (HOLE-12 grounding). Garis batas hulu-mentah vs defect-terkonfirmasi harus tajam.
- ✗ **DITOLAK: file tunggal `control/feedback.md`.** Alasan: sinyal lapangan datang sebagai banyak entri tak-terstruktur dari waktu-ke-waktu; satu file jadi monolit susah di-append manual & susah di-skim intake. Dir + file-per-sinyal lebih natural untuk drop manual.

### D4 — Format file sinyal: **bebas (markdown)** vs schema YAML kaku
- ▶ **DIPILIH: markdown bebas.** Manusia drop file `.md` bentuk apa pun (paste keluhan, ringkasan incident, link). Template-dir berisi `README.md` yang **menyarankan** (bukan mewajibkan) format ringan: judul + tanggal + sinyal + dugaan area dampak. Intake membaca by-understanding, bukan parse field.
- ✗ **DITOLAK: schema YAML kaku** (`feedback.yaml` dengan field wajib severity/source/status). Alasan: schema kaku menuntut penulis-manusia mengisi field → friksi drop manual + menggoda jadi "status machine" (resolved/open) yang menyeret ke arah gate. SOFT-input cukup dibaca by-understanding. (Konsisten: `risks.md` M6 juga prosa-bentuk-entri, bukan schema.)

### D5 — Garis batas feedback vs fix (vs `risks.md`)
- ▶ **DIPILIH: garis eksplisit di README template + klausa intake.**
  - `feedback/` = **sinyal lapangan HULU MENTAH** (keluhan/incident/request/insight) — belum tentu bug; dibaca `intake` sebagai inspirasi/konteks fitur.
  - `fixes/` = **defect TERKONFIRMASI** (reproduce → root-cause → TDD → ship). Bila sebuah sinyal feedback ternyata bug nyata → jalannya **lewat `/fix`** (bukan disimpan selamanya di feedback).
  - `risks.md` (M6) = **kewajiban compliance/regulasi durable** — beda domain (legal-obligation), bukan sinyal lapangan.
- ✗ **DITOLAK: membiarkan batas implisit.** Alasan: tanpa garis, user bingung taruh di mana (HOLE-12). Cermin carve-out tajam M6 (risks.md vs invariants.md vs market-HTML).

### D6 — "Otak bersama": **klausa inline** vs shared rule baru
- ▶ **DIPILIH: klausa inline di `intake/SKILL.md` + `README.md` template-dir.** M8 punya **satu pembaca WAJIB** (`intake`) dan **satu penulis** (manusia); `ask` cuma read-only cosmetic OPSIONAL (D7 — ringkas isi, tak punya logika sendiri). Kedua pembaca **tak berbagi resep yang bisa di-DRY-kan** (intake = elicitation+challenge; ask = lookup ringkas) → shared rule = over-engineering.
- ✗ **DITOLAK: `rules/feedback.md` baru** (cermin `compliance-risk.md`/`migration-impact.md`). Alasan: shared rule dibenarkan saat ≥2 skill berbagi resep (M6: discovery+architect+intake+ship). M8 single-reader → rule baru = churn tanpa manfaat; rules tetap **5**. (FLAG di §8 bila tergoda: M8-FLAG-D.)

### D7 — Read-surface tambahan: **intake-only** vs juga `ask`/`render-docs`
- ▶ **DIPILIH: intake-only sebagai surface WAJIB.** Usulan = "intake baca sbg input SOFT". `ask` **boleh** tambah baris read-surface (cosmetic, opsional — §3.E) supaya user bisa nanya "ada feedback lapangan apa?"; itu read-only & murah. **`render-docs` TIDAK** (lihat ✗).
- ✗ **DITOLAK: render `feedback/` di `render-docs`.** Alasan: preseden M6 — `risks.md` **sengaja tidak dirender** (M6 §3: "knowledge durable yang dibaca skill, bukan badge/doc yang di-render"). Feedback = input dibaca intake, bukan doc stakeholder. (FLAG di §8: M8-FLAG-B.)

### D8 — Penempatan di tree induk: **sibling top-level** vs di bawah `business/`
- ▶ **DIPILIH: sibling top-level `control/feedback/`** (sejajar `fixes/`/`docs/`/`features/`). Feedback = lane operasional/sinyal-lifecycle, bukan knowledge-bisnis-durable (`business/` = domain/flows/glossary/risks). Sejajar dengan `fixes/` (lane balik lain) secara konseptual.
- ✗ **DITOLAK: `control/business/feedback/`.** Alasan: `business/` rumah knowledge-bisnis yang di-promote `intake`/`extract` (aturan domain/flow/istilah/compliance). Sinyal lapangan mentah bukan kebenaran-bisnis-durable; menaruhnya di `business/` mengaburkan apa yang di-promote vs apa yang dibaca-mentah.

## 3. Masalah

- **Sinyal lapangan tak punya rumah.** `control/` punya `business/` (knowledge), `fixes/` (defect terkonfirmasi), `docs/` (HTML stakeholder), `features/` (work-item). **Tak ada** tempat untuk sinyal mentah dari produk live (keluhan user, incident ops, request, insight) yang belum naik jadi bug.
- **Loop balik ke intake putus.** `intake/SKILL.md` step 2 (Baca knowledge) hari ini baca `control/business/*.md` (domain, flows, glossary, **`risks.md`**) + `workspace.yaml`. **Tak ada** input sinyal lapangan → keputusan fitur berikutnya buta terhadap apa yang produk live ajarkan. Verbatim disk sekarang:
  > `Baca `control/business/*.md` (domain, flows, glossary, **`risks.md`** — kewajiban compliance, constraint per-fitur) + `control/workspace.yaml` (apps + capabilities).`
- **`/fix` hanya menangkap bug, bukan sinyal pra-bug.** Lane `fix` (`control/fixes/`) menuntut defect **terkonfirmasi** (reproduce/root-cause). Keluhan kabur / feature-request / "user sering kesulitan di X" tak punya tempat sampai (kalau pernah) jadi bug. Sinyal hulu hilang sebelum sempat menginformasikan fitur.

## 4. Tujuan & Non-Tujuan

**Tujuan**
- Direktori durable `control/feedback/` (template-dir kosong + `README.md` panduan), auto-scaffold `init` step 4 (`cp -R template/control/.` — sudah copy `fixes/`/`docs/`/`features/`; `feedback/` ikut otomatis).
- `README.md` template (di `control/feedback/`): jelaskan **apa yang masuk** (sinyal lapangan mentah), **siapa penulis** (manusia, drop manual), **format ringan disarankan** (judul · tanggal · sinyal · dugaan area), **garis batas** vs `fixes/` (defect) & `risks.md` (compliance), **sifat SOFT** (dibaca intake, bukan gate). **TANPA `<PRODUCT>` placeholder** (hindari sentuh daftar replace `init` — §3.F, HOLE-9).
- `intake/SKILL.md`: step 2 (Baca knowledge) tambah baca `control/feedback/` (bila ada) sebagai **input SOFT**; step 5 (Challenge Checklist WAJIB-tampil) tambah satu item yang **memaksa** munculkan sinyal relevan ke user (cermin M6 yang menaruh item compliance-nya di step 5). Advisory; degrade-mulus bila kosong/absen.
- (Opsional, cosmetic) `ask/SKILL.md` domain→sumber: +1 baris read-surface `feedback/` agar user bisa nanya sinyal lapangan.

**Non-Tujuan (seam bersih, anti scope-creep)**
- **Tak ada skill baru**, tak ada `/feedback`/`/observe`. Skill tetap **21**. Nol churn `plugin.json`/`marketplace.json`/README/induk §12 (lifecycle — tak ada fase baru).
- **Tak ada rule baru.** Rules tetap **5** (anti-yes-man/debt-aware/schema-projection/migration-impact/compliance-risk). M8 = klausa inline + README template (§2 D6).
- **Tak ada auto-ingest / observability-pipeline.** Penulis = manusia (drop manual). Tak ada integrasi Sentry/PagerDuty/analytics, tak ada dedup/severity-engine (§2 D1).
- **Tak ada gate baru, tak ada palang keras.** `intake` membaca SOFT — tak memblokir. Satu-satunya STOP keras tetap Security Gate `ship` existing (tak disentuh M8). (§2 D2)
- **Tak menggandakan lane `fix`.** `feedback/` = hulu mentah; `fixes/` = defect terkonfirmasi. Sinyal yang jadi bug nyata → naik lewat `/fix`. (§2 D5)
- **Tak menggandakan `risks.md`.** Beda domain: risks.md = compliance/legal; feedback = sinyal lapangan operasional. (§2 D5)
- **Tak ubah `render-docs`** (`feedback/` = input dibaca skill, bukan doc di-render; cermin preseden M6 risks.md tak dirender). (§2 D7)
- **Tak ubah** `feature.yaml` schema / mekanik `sensitivity` / `intake` step 1 (creation feature.yaml) / gate intake step 6/7. M8 hanya menyisipkan baca-SOFT di step 2 + satu item advisory di Challenge Checklist step 5 (keduanya non-gate; step 5 tetap "tampilkan", bukan "blokir").
- **Tak ubah** `init` daftar `<PRODUCT>`-replace (template feedback netral, tanpa `<PRODUCT>`). (§3.F)
- **Brownfield `extract` / produk tanpa feedback** degrade-mulus: dir kosong/absen → intake jalan seperti sekarang. Tak ada elicitation feedback baru (konsisten M6 tunda extract).

## 5. Artefak durable — `control/feedback/` (template-dir + README)

Cermin preseden template-dir: `plugin/template/control/{fixes,features,docs}/.gitkeep` (3 dir kosong, byte 0, ikut `cp -R` di `init` step 4). M8 menambah **dir keempat** `feedback/`, tapi **dengan `README.md`** (bukan `.gitkeep` kosong) — karena feedback butuh menjelaskan ke penulis-manusia apa yang masuk & bagaimana (fixes/docs/features tak butuh karena diisi skill, bukan manusia-drop). `README.md` itu sendiri jadi penanda dir (peran sama `.gitkeep`: bikin dir non-kosong agar ter-commit).

Template `plugin/template/control/feedback/README.md`:

```markdown
# Feedback — Sinyal Lapangan (input SOFT untuk intake)

Drop di sini sinyal MENTAH dari produk yang sudah live: keluhan user, incident ops, request fitur, insight analytics/support. Satu sinyal = satu file `.md` (mis. `2026-06-10-checkout-sering-timeout.md`).

**Penulis = MANUSIA (operator/user).** Drop manual — tak ada skill yang mengisi folder ini, tak ada auto-ingest. **Pembaca = `intake`** (saat merencanakan fitur, ia memunculkan sinyal relevan — sebagai INPUT SOFT, BUKAN gate; tak memblokir apa pun).

**Format ringan yang disarankan** (bebas, tak wajib):
- Judul singkat + tanggal.
- Sinyal: apa yang diamati di lapangan (kutip keluhan/incident apa adanya).
- Dugaan area dampak: app/fitur/flow yang relevan (bila tahu).

**Garis batas — apa yang BUKAN feedback:**
- **Bug terkonfirmasi** (bisa di-reproduce) → bukan di sini; jalankan `/fix` (lane `control/fixes/`).
- **Kewajiban compliance/regulasi** (PCI/GDPR/pajak/KYC) → bukan di sini; rumahnya `control/business/risks.md`.
- Feedback = sinyal HULU MENTAH yang belum tentu bug; ia menginformasikan fitur berikutnya, bukan eksekusi.

Folder boleh kosong (cuma README ini) — `intake` degrade mulus bila tak ada sinyal.
```

- **Tanpa `<PRODUCT>`** — konten generik; `init` step 4 me-replace `<PRODUCT>` hanya di file yang DISEBUT eksplisit (`business/*.md`, `conventions.md`, `invariants.md`, `integrations.md`, `design-system.md`). Template feedback netral → tak perlu menyentuh daftar itu (HOLE-9).
- **Peran README sebagai dir-keeper:** karena `README.md` non-kosong, dir `feedback/` ter-track Git tanpa `.gitkeep` terpisah. (Bila tooling butuh `.gitkeep` juga, boleh tambah — tapi README sudah cukup membuat dir non-kosong.)

## 6. Wiring — di mana M8 nempel

### 6a. `intake` — baca feedback sebagai input SOFT (pembaca WAJIB)
`intake` menyentuh feedback di **dua surface yang saling melengkapi** (cermin pola M6 `risks.md`: baca di step 2, paksa-tampil di step 5):
- **step 2 (Baca knowledge):** tambah klausa **baca** `control/feedback/` (bila ada) sebagai **input SOFT**. **Advisory:** memperkaya elicitation, **tak** memblokir, **tak** auto-resolve. Garis batas: feedback = sinyal mentah (belum tentu bug); bila sebuah sinyal ternyata defect → jalannya `/fix`, bukan diselesaikan di intake. **Degrade:** `feedback/` kosong (cuma README) / absen → step 2 jalan persis seperti sekarang.
- **step 5 (Challenge Checklist — `WAJIB tampilkan sebelum gate`):** tambah **satu item checklist** yang **memaksa** intake memunculkan sinyal feedback relevan ke user (mis. "ada 3 sinyal soal checkout timeout di `feedback/` — fitur ini menyentuh checkout?"). Cermin M6 yang menaruh item compliance `risks.md` justru di step 5 (tempat display di-paksa), bukan menggantung di step 2. Tetap advisory (`kutip + tanya`, bukan blokir).

> **Honesty (lihat §7):** klausa step 2 = "baca (SOFT)"; klausa step 5 = "kutip + tanya (advisory)", **bukan** "blokir/wajib-selesaikan". Surfacing ke user **di-paksa** di step 5 (checklist WAJIB-tampil) supaya janji "munculkan sinyal" mendarat di tempat display dijamin — bukan instruksi step-2 yang harus dibawa LLM maju sendiri.

### 6b. `ask` — read-surface opsional (cosmetic)
`ask/SKILL.md` tabel domain→sumber: +1 baris `| Feedback / sinyal lapangan (keluhan/incident/request) | `feedback/*.md` |` setelah baris fixes. Read-only, murah, biar user bisa nanya "ada sinyal lapangan apa". **Opsional** — bukan inti fix (inti = intake baca). Anchor verbatim disk sekarang:
> `| Bug / known-issues / riwayat fix | `fixes/*/fix.yaml` (+ `notes.md`) |`

### 6c. `init` — auto-scaffold (tanpa edit)
`init` step 4 sudah `cp -R "${CLAUDE_PLUGIN_ROOT}/template/control/." "<produk>/control/"` → dir `feedback/` + `README.md` ikut tersalin otomatis. **Tak ada edit `init`** — template feedback netral (tanpa `<PRODUCT>`) tak menyentuh daftar replace step 4 (HOLE-9). Verbatim disk sekarang:
> `Copy isi `${CLAUDE_PLUGIN_ROOT}/template/control/` ke `<produk>/control/` (mis. `cp -R "${CLAUDE_PLUGIN_ROOT}/template/control/." "<produk>/control/"`).`

## 7. Honesty-note (advisory vs gate; surface tempat shipped-text harus jujur)

Preseden M6 §1 (Catatan jujur): bila fitur cuma advisory / memperkaya seam existing, tulis jujur di surface tempat logika beneran jalan — jangan klaim lebih.

- **`intake/SKILL.md` step 2 + step 5 (surface utama, WAJIB jujur):** step 2 berkata "**baca** `control/feedback/` (bila ada) sebagai **input SOFT** (advisory)"; step 5 (Challenge Checklist WAJIB-tampil) berkata "**kutip + tanya** apakah fitur menanganinya (advisory)". Pemisahan baca-vs-tampil ini cermin M6 (baca risks.md di step 2, item compliance di step 5) dan menjamin janji "munculkan sinyal" mendarat di surface tempat display di-paksa. JANGAN tulis "blokir bila ada feedback unresolved" / "wajib selesaikan dulu" — itu gate, dilarang (§2 D2). Degrade-mulus disebut eksplisit ("kosong/absen → jalan seperti sekarang").
- **`README.md` template (surface penulis-manusia, WAJIB jujur):** nyatakan "penulis = manusia (drop manual), tak ada auto-ingest" + "dibaca intake sebagai INPUT SOFT, BUKAN gate". Mencegah ekspektasi pipeline/auto-pickup yang tak ada.
- **Tidak ada surface gate:** M8 **tak** menyentuh Security Gate `ship`, `build` segment-gate, atau gate apa pun. Beda dari M6 (yang memperkaya gate `ship` existing) — M8 **murni advisory di hulu**, blast-radius = nol terhadap gate. Tulis ini agar tak ada yang menyangka M8 bisa men-trigger STOP.

## 8. Scope-flags (tempat fix bisa diam-diam balloon dari "light")

- **M8-FLAG-A — skill penulis / auto-ingest observability** (`/feedback`, integrasi Sentry/PagerDuty/analytics, dedup/severity-engine) = pipeline penuh → balloon. **Fix-light = manual drop + intake baca SOFT** (§2 D1). Bila author/eksekutor tergoda bikin penulis otomatis → STOP, itu sub-proyek terpisah.
- **M8-FLAG-B — render `feedback/` di `render-docs`** = scope-creep (preseden M6: durable-input tak dirender). Jangan render (§2 D7).
- **M8-FLAG-C — `intake` BLOCK on unresolved feedback** = gate baru, langgar "SOFT". Jangan (§2 D2).
- **M8-FLAG-D — `rules/feedback.md` shared rule baru** = over-engineering untuk single-reader. Rules tetap 5; M8 = klausa inline + README (§2 D6).
- **M8-FLAG-E — schema YAML kaku `feedback.yaml` + status machine (open/resolved)** = menyeret ke arah gate & friksi drop manual. Format markdown bebas (§2 D4).

## 9. Generik (jaminan lintas-produk)

- `control/feedback/` = dir + markdown bebas = generik (cermin `fixes/`/`docs/` template-dir). Tak hardcode domain/vendor monitoring.
- "Sinyal lapangan" (keluhan/incident/request/insight) = universal lintas produk live — bukan ecommerce-specific. README pakai contoh netral (checkout-timeout cuma ilustrasi format, bukan domain-lock).
- `intake` baca by-understanding (cocokkan sinyal dengan fitur yang di-intake), bukan parse field hardcode.
- **Degrade-anggun** di tiap titik: `feedback/` kosong (cuma README) / absen / produk tanpa drop → intake best-effort ("tak ada sinyal lapangan relevan"), jalan seperti sekarang. Tak pernah error/blokir.

## 10. Edge case & degrade

| Kasus | Perilaku |
|---|---|
| `feedback/` kosong (cuma README) | `intake` step 2 degrade: "tak ada sinyal lapangan" — jalan seperti sekarang. Tak error/blokir. |
| `feedback/` absen (produk lama / extract / belum re-init) | `intake` degrade: skip baca feedback, lanjut normal. |
| Sinyal relevan dengan fitur yang di-intake | `intake` **munculkan** ke user saat Q&A/Challenge (advisory) → user putuskan apakah fitur menanganinya. Tak auto-scope. |
| Sinyal ternyata bug terkonfirmasi | Garis batas (§2 D5): jalannya `/fix` (lane `fixes/`), bukan diselesaikan di intake. README + klausa intake mengarahkan. |
| Sinyal = kewajiban compliance | Bukan rumah feedback (§2 D5); rumahnya `risks.md` (M6). README mengarahkan. |
| Banyak sinyal (folder gemuk) | `intake` baca by-understanding, fokus yang relevan dengan fitur di-intake (hemat konteks, cermin `ask` "baca yang nyambung saja"). |
| Sinyal usang / sudah ter-ship | M8 fix-light tak punya status-machine (§2 D4); sinyal usang dibiarkan (manusia boleh hapus file manual). Intake cukup mengabaikan yang tak relevan. |
| `ask` ditanya "ada feedback apa" | (Bila §6b dipasang) `ask` baca `feedback/*.md` read-only, ringkas + sebut sumber. Bila §6b tak dipasang → `ask` tak tahu, degrade biasa. |

## 11. Parent-spec amendments (induk `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`)

- **§7 control-tree** (anchor byte-eksak, verified match=1: baris `├── fixes/                # lane bugfix (post-ship) — entitas first-class`): sisip baris baru **SEBELUM** `fixes/` — `├── feedback/              # sinyal lapangan mentah (M8; di-drop manusia, dibaca intake SOFT)`. Penempatan sibling top-level (§2 D8), sebelum `fixes/` (sinyal hulu sebelum lane defect). **Alignment kolom `#`:** samakan dengan baris sekitarnya — `fixes/` (6 char) punya **16 spasi** sebelum `#` (verified). `feedback/` = 9 char (3 lebih panjang) → **13 spasi** sebelum `#` (16 − 3) agar kolom `#` rata dgn `fixes/`. Verifikasi byte-eksak `grep -Fc -e` baris baru pra-commit.
- **§17 Komponen — Knowledge (`control/`)** (anchor verbatim, verified match=1: `- **Knowledge (`control/`):** `workspace.yaml` (apps[] + packages[]) · `business/` · `conventions.md` · `invariants.md` · `integrations.md` · `design-system.md` · `schema/` · `features/` · `docs/``): tambah ` · `feedback/`` SETELAH `features/` (sebelum `docs/`) → `…· `features/` · `feedback/` · `docs/``. Separator ` · ` (spasi-middot-spasi + backtick) — ikuti gaya lokal baris ini.
- **§ intake skill-description — baris `Input` (anchor byte-eksak, verified match=1 di line 188: `- **Input:** ide fitur + `business/*.md` + `workspace.yaml`.`):** ini **satu-satunya** deskriptor sumber-tunggal tentang apa yang dibaca `intake`. M6 `risks.md` ter-cover implisit karena `risks.md` hidup **di bawah** `business/*.md`; tapi `feedback/` = **sibling top-level** (§2 D8), **bukan** di bawah `business/` → tak ter-cover. **FIX (SOFT):** tambah ` + `feedback/` (SOFT, opsional)` di akhir baris (sebelum titik) → `- **Input:** ide fitur + `business/*.md` + `workspace.yaml` + `feedback/` (SOFT, opsional).`. Penanda `(SOFT, opsional)` menjaga sifat advisory di descriptor (bukan input kanonik wajib). Verifikasi `grep -Fc -e` byte-eksak pra-commit. (Bila author lebih suka deskriptor tetap ringkas, alternatif = catat di "TAK disentuh" dengan alasan "feedback = read SOFT opsional, bukan input kanonik" — tapi DIPILIH menyentuhnya karena baris ini = single-source dan kelalaian-nya yang ditemukan reviewer.)
- **§13 Dokumen Human-Readable (negatif — TAK disentuh, dokumentasikan kenapa):** layout HTML sidebar (Overview · Apps · … · Fix/Known Issues) **TIDAK** dapat section Feedback. Konsisten preseden M6 (durable-input tak dirender, §2 D7). Tak ada edit §13.

**TAK disentuh (eksplisit):** skill-count (tetap **21** di §17 line 304 + §8 line 136), rules-count (tetap **5** di §8 line 138 + §17 — M8 tak nambah rule), `plugin.json`, `marketplace.json`, README, §8 repo-tree `template/control/` listing (line 140 sudah pakai bentuk ringkas "`features/· docs/` theme warm" yang menyebut sebagian dir saja — tak wajib tambah `feedback/` di sana karena bukan listing lengkap; bila author mau konsisten boleh sisip `feedback/·` sebelum `features/·`, tapi OPSIONAL & tak mengubah makna), §12 (lifecycle — tak ada fase baru), §9 ship gate (M8 tak sentuh gate apa pun), `feature.yaml` schema / mekanik `sensitivity`, threshold Security Gate, M6 `risks.md` / `rules/compliance-risk.md`.

## 12. Edit-map (anchor diverifikasi `grep -Fc -e` saat writing-plans)

**NEW**
- `plugin/template/control/feedback/README.md` — template §5 lengkap (apa yang masuk + penulis-manusia + format ringan disarankan + garis batas vs fixes/risks + sifat SOFT + boleh-kosong). **Netral, TANPA `<PRODUCT>`.**

**MODIFY skill**
- `plugin/skills/intake/SKILL.md` — step 2 (anchor verbatim disk sekarang, verified match=1):
  > `Baca `control/business/*.md` (domain, flows, glossary, **`risks.md`** — kewajiban compliance, constraint per-fitur) + `control/workspace.yaml` (apps + capabilities).`
  
  Tambah kalimat baru SETELAH baris itu (sisip baris, **bukan** renumber step): "**Feedback (M8):** bila ada, baca `control/feedback/` (sinyal lapangan mentah dari produk live — keluhan/incident/request) sebagai **input SOFT** (advisory, **bukan** gate; tak memblokir). Sinyal yang ternyata bug → arahkan ke `/fix`, bukan diselesaikan di sini. Degrade: kosong/absen → lanjut seperti biasa." (Surfacing ke user di-paksa di step 5 — lihat entri berikut.)
  - **Catatan anti-tabrak:** M8 sisip di step 2 SETELAH baris risks.md (M6). M1 (sizing-check) menyasar step 4/1, M7 (risk) menyasar step 7 — surface BERBEDA, tak tabrakan (lihat grounding §2b). Bila M6/M8/M1/M7 dieksekusi berurutan, anchor step-2 ini tetap unik (frasa `(domain, flows, glossary, **`risks.md`**` tak muncul di tempat lain).

- `plugin/skills/intake/SKILL.md` — step 5 Challenge Checklist (anchor verbatim disk sekarang, verified match=1, cermin tempat M6 menaruh item compliance-nya):
  > `- Menyentuh kewajiban compliance di `risks.md`? (PCI/GDPR/pajak/KYC) — kutip + pastikan tertangani (advisory).`
  
  Tambah satu item checklist baru SETELAH baris itu (sisip baris dalam list step 5, **bukan** renumber step): `- Ada sinyal lapangan relevan di `feedback/`? — kutip + tanya apakah fitur ini menanganinya (advisory).`. **Kenapa di step 5:** step 5 = "Challenge Checklist (WAJIB tampilkan sebelum gate)" → display ke user **dijamin** (Lesson #16: janji "munculkan sinyal" harus mendarat di surface tempat tampil di-paksa, bukan menggantung di instruksi step-2). Cermin M6 yang menaruh item `risks.md`-nya tepat di step 5. **Tetap advisory** (`kutip + tanya`, bukan blokir). Anchor step-5 risks.md (M6) tetap utuh sebelum sisipan.

- **(OPSIONAL) `plugin/skills/ask/SKILL.md`** — tabel domain→sumber (anchor verbatim disk sekarang, verified match=1):
  > `| Bug / known-issues / riwayat fix | `fixes/*/fix.yaml` (+ `notes.md`) |`
  
  Tambah baris baru SETELAH itu: `| Feedback / sinyal lapangan (keluhan/incident/request) | `feedback/*.md` |`. Cosmetic read-surface (§6b) — boleh di-skip tanpa merusak fix inti.

**MODIFY parent spec** `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`
- §7 control-tree — sisip baris `feedback/` SEBELUM `fixes/` (anchor + alignment di §11).
- §17 Komponen Knowledge — tambah ` · `feedback/`` setelah `features/` (anchor di §11).
- intake skill-description baris `Input` (line 188) — tambah ` + `feedback/` (SOFT, opsional)` sebelum titik (anchor + alasan di §11). Single-source descriptor intake reads; `feedback/` = sibling, tak ter-cover oleh `business/*.md`.

**TAK disentuh (eksplisit):** `init/SKILL.md` (template netral → `cp -R` otomatis, tak edit daftar replace), `render-docs` (tak render), `feature/SKILL.md` (M8 tak sentuh feature.yaml creation), `fix`/`build`/`ship` (tak ada gate/lane baru), rules (tak nambah file), `feature.yaml` schema, `sensitivity` mekanik.

## 13. Verifikasi & bug-guard

**Grep-battery (post-exec):**
- V0 `plugin/template/control/feedback/README.md` ADA + memuat: penulis-manusia (`MANUSIA`/`drop manual`), sifat SOFT (`INPUT SOFT`/`BUKAN gate`), garis batas (`/fix`, `risks.md`), boleh-kosong. **TANPA `<PRODUCT>`** (cek `grep -Fc '<PRODUCT>' README.md` = **0**). (Prosa by-read.)
- V1 dir `feedback/` ter-scaffold lewat `init`: konfirmasi `cp -R template/control/.` menyertakannya (by-read step 4 — tak ada edit init, jadi cek template ADA cukup).
- V2 `intake/SKILL.md` step 2 memuat klausa feedback (`control/feedback/` + `input SOFT` + degrade); step 5 Challenge Checklist memuat item `feedback/` baru (`kutip + tanya` + `advisory`). Anchor risks.md (M6) di step 2 **dan** step 5 tetap utuh sebelum tiap sisipan.
- V3 (bila §6b dipasang) `ask/SKILL.md` tabel memuat baris `feedback/*.md`.
- V4 skill-count tetap **21** (induk §17 line 304 + §8 line 136); rules tetap **5** (§8 line 138 + §17) — tak ada edit `plugin.json`/`marketplace.json`/README.
- V5 induk §7 tree memuat baris `feedback/` (byte-eksak) + §17 Knowledge memuat `feedback/` + intake skill-description baris `Input` (line 188) memuat `+ `feedback/` (SOFT, opsional)`. (Cek tiga tempat induk biar tak stale vs §7.)
- V6 **anti-gate:** klausa M8 di intake berkata "baca/munculkan/SOFT/advisory", **bukan** "blokir/STOP/wajib/gagal". Tak ada gate baru di mana pun.
- V7 **anti-pipeline:** tak ada skill baru, tak ada referensi auto-ingest/vendor-monitoring di mana pun. Penulis = manusia (eksplisit di README).
- V8 **anti-render:** `render-docs` tak disentuh (cermin M6 risks.md tak dirender).
- V9 **garis batas utuh:** README + intake klausa nyatakan feedback ≠ fix (defect→`/fix`) & feedback ≠ risks.md (compliance). Tak overlap.

**Bug-guard pre-bake (untuk plan):**
- **colon-space:** M8 **tak** mengubah `description:` SKILL.md mana pun (cuma body step 2 intake + tabel ask + template README baru). Tak ada value YAML baru ber-`: `. README markdown prosa — colon di prosa (mis. "Sinyal:") aman karena bukan value YAML/description.
- **no-renumber:** sisipan intake step 2 = baris baru DALAM step 2 (bukan step baru) → step 3-7 tetap nomornya. ask = baris tabel baru. Verifikasi cross-ref "step N" intake tetap nunjuk target benar.
- **mis-aimed-pointer:** tiap `§X`/"(lihat …)" di spec ini nunjuk seksi yang beneran punya kontennya (D1-D8 di §2; HOLE-9 = referensi grounding scout, bukan section spec ini — sebutkan sebagai "grounding" agar tak mis-aim). Edit-map before→after yang nge-quote teks-lama = dokumentasi, **bukan** pointer live.
- **`grep -Fc -e` anchor:** tiap find/replace diverifikasi verbatim SEBELUM commit. Anchor intake step 2 memuat metachar (backtick, `**`, `*`, `()`) — pakai `-F` (fixed-string). Anchor §7 tree memuat box-drawing `├`/`└` + padding-spasi → byte-eksak, awas kolom `#`.
- **template-dir keeper:** `README.md` non-kosong membuat `feedback/` ter-track Git (peran sama `.gitkeep`). Pastikan file beneran ada di `template/control/feedback/` (bukan cuma dir kosong yang Git buang).
- **tree-alignment (§7 induk):** baris baru `feedback/` box-drawing `├──`; samakan kolom `#` dengan baris `fixes/` di bawahnya (keduanya komentar `# lane…`/`# sinyal…`). Verifikasi `grep -Fc -e` byte-eksak pra-commit. **Jangan** ubah `└──`/`├──` baris lain (feedback disisip di tengah top-level, bukan jadi anak terakhir — `docs/` tetap `└──`).
- **dup-phrase scope:** anchor `control/business/*.md`/`fixes/*/fix.yaml` dicek unik per file target (intake step 2; ask tabel). `feedback` kata baru → match=0 expected di disk pra-exec untuk MODIFY-anchor (file feedback baru → cek scope ke file target).
- **one-file-per-task:** plan satu task = satu file; tiap anchor diverifikasi vs file SEKARANG.
- **literal-scan sentinel:** M8 tak menambah token sentinel (`<…>`) baru; README prosa bebas. Aman.

## 14. Self-review checklist (awal)

- [ ] **Fix-light terjaga?** Tak ada skill baru (21), tak ada rule baru (5), tak ada gate baru, tak ada fase lifecycle baru, tak ada auto-ingest. (§4 Non-Tujuan; §8 FLAG)
- [ ] **SOFT, bukan gate?** Klausa intake step 2 = "baca (advisory)" + step 5 = "kutip/tanya (advisory)"; tak ada "blokir/wajib". README nyatakan "BUKAN gate". (§2 D2; §7)
- [ ] **Janji surfacing mendarat di surface yang di-paksa-tampil?** Item "munculkan sinyal" ada di step 5 (Challenge Checklist WAJIB-tampil), bukan menggantung di step 2 — cermin M6. (Lesson #16; §6a; §12)
- [ ] **Penulis = manusia, eksplisit?** README + spec nyatakan drop manual, tak ada skill penulis. (§2 D1; §7)
- [ ] **Garis batas tajam?** feedback (hulu mentah) ≠ fixes (defect→`/fix`) ≠ risks.md (compliance). Di README + klausa intake. (§2 D5)
- [ ] **Template netral (tanpa `<PRODUCT>`)?** Tak menyentuh daftar replace `init` step 4. (§3.F; §5; grounding HOLE-9)
- [ ] **Degrade-mulus?** `feedback/` kosong/absen → intake jalan seperti sekarang, tak error/blokir. (§9; §10)
- [ ] **Tak dirender?** `render-docs`/§13 induk tak disentuh (cermin M6). (§2 D7; §11)
- [ ] **Anchor verbatim diverifikasi?** intake step 2 (risks.md M6 line), intake step 5 (risks.md compliance-item), ask fixes-row, §7 tree fixes-line, §17 Knowledge, induk Input-line (line 188) — semua `grep -Fc -e` match=1 pra-edit. (§12; §13)
- [ ] **Anti-tabrak Stream A?** M8 surface = intake step 2 + ask tabel + template-dir; tak bentrok M1 (step 4/1) / M7 (step 7) / M6 (step 2 risks.md tetap utuh). (§12 catatan)
- [ ] **Generik?** Tak ada hardcode domain/vendor; contoh README netral. (§9)
- [ ] **Tiap fork desain ber-alternatif-ditolak?** D1-D8 punya ▶/✗ + alasan (ganti brainstorming). (§2)
