# context-vault — Platform Invariants + Security Gate (Design Spec)

- **Tanggal:** 2026-06-01
- **Status:** Draft disetujui untuk masuk tahap perencanaan implementasi
- **Terkait:** spec induk `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§4 just-in-time knowledge, §7 model `control/`, §9 skill `architect`/`intake`/`ship`, §10 agent `critic`, §11 anti-yes-man, §12 lifecycle, §17 komponen); spec `2026-05-31-wire-skill-design.md` (`wire` prasyarat stack logical); spec `2026-05-29-breakdown-build-execution-phase-design.md` (`build` mesin actions/migrate).
- **Asal:** audit adversarial pipeline (26 agent: 8 finder lensa-beda → cluster → skeptik per-gap → sintesis) terhadap skenario "solo dev bikin ecommerce-builder ala Shopify full-AI". 16 gap terkonfirmasi (0 dibantah). Spec ini mengerjakan **Langkah 1** = gap **H1** (invarian platform), **H4** (gate keamanan), **M2** (wiring invarian ke gate). Langkah 2 (H2 shared-package, M5 integrations, M4 schema-projection, H3 migration-governance) = spec terpisah berikutnya.

---

## 1. Ringkasan

Pipeline `discovery → init → architect → wire → feature(intake→fanout→plan) → breakdown → build → ship` sehat di sumbu "satu fitur, ide → PR", tapi bolong di sumbu "bangun PRODUK utuh berbasis uang + data pribadi". Spec ini menambal dua bolong paling fatal-tapi-murah, tanpa skill baru:

- **H1 — Invarian platform dikunci terlalu lambat.** Keputusan fondasi yang membentuk **bentuk setiap table & setiap query** (model tenancy, representasi uang, idempotency, authz/RBAC, PII/PCI, rate-limit) tak pernah dipaksa muncul di depan. `architect` (`SKILL.md:21-24`) cuma Q&A stack teknis (framework/db/orm); ia **tidak** menanya tenancy/money. Akibatnya keputusan ini kejadian diam-diam saat `feature` pertama bikin table — atau telat berbulan (baru muncul di payout/refund) → retrofit lintas puluhan table. Spec induk **men-desain** penundaan ini (§4 line 41, §10 line 208: "dikunci tepat waktu oleh `critic` saat fitur pertama menyentuhnya"), tapi `critic` cuma penasihat read-only (output keberatan, bukan blocker), dipanggil **kondisional** (bisa skip), dan kalau `conventions.md` kosong ia tak punya baseline.
- **H4 — Nol gate keamanan.** Yang di-ship adalah kode pembayaran + PII, tapi `ship` (`SKILL.md:16-32`) cuma review bug/konvensi + test/lint + alignment-bisnis. Challenge Checklist `ship` (`SKILL.md:24-28`) punya **nol** item PII/PCI/secret/authz/webhook-signature. `critic` menyebut "keamanan" sebagai lensa (`critic.md:16`) tapi di `ship` ia dipanggil khusus alignment-bisnis, read-only tanpa scan-diff, dan **bukan** gate pass/fail wajib.
- **M2 — Invarian tak ter-enforce.** Bahkan kalau invarian ditulis, tak ada gate hilir yang mengeceknya; ia jadi dokumen mati.

**Pendekatan:** invarian dikunci sekali di depan oleh **langkah baru di `architect`** (gated, `critic` wajib) ke **artifact baru `control/invariants.md`**; `wire` **menolak** bring-up DB kalau invarian belum terkunci; `ship` dapat **Security & Compliance Gate** ber-agent baru **`security-critic`**, kedalamannya **berskala** ke tag `sensitivity` fitur; dan satu baris challenge di `plan`/`breakdown`/`build` mengikat `invariants.md` ke mesin gate. **Tidak ada skill baru** — reuse mesin gate yang ada.

## 2. Tujuan & Non-Tujuan

**Tujuan:**
- Memaksa keputusan invarian platform **resolved (terisi atau N/A-dengan-alasan) sebelum `wire` bikin baseline DB**.
- Memberi `ship` gate keamanan **pass/fail** yang STOP-on-fail untuk fitur sensitif, murah untuk fitur receh.
- Mengikat `invariants.md` ke gate `plan`/`breakdown`/`build` lewat satu item challenge.
- **Tetap generic** — kategori invarian di-*elicit* (`architect` menyarankan; user/produk yang menentukan), bukan hardcode ecommerce. Skenario Shopify hanya alat uji.
- **Reuse, bukan nambah skill** — semua perubahan masuk skill/agent/template existing + satu agent baru.

**Non-Tujuan (spec ini):**
- Shared-package modeling (H2), integrations-as-entity (M5), schema-projection (M4), migration-governance lintas-fitur (H3) — **Langkah 2**, spec sendiri.
- Deploy/release/env, iterasi-v2, observability, graduated-autonomy — tetap defer (lihat audit + spec struktural `2026-05-31-pipeline-hardening-structural-design.md`).
- Eksekusi keamanan otomatis (auto-fix temuan) — `security-critic` **read-only**; perbaikan tetap lewat `build`/manual.

**Revisi terhadap spec induk:** spec induk menaruh penguncian invarian sebagai *reaktif lewat `critic`* (§4/§10). Spec ini menjadikannya **proaktif & terstruktur**: gate satu-kali di `architect` + artifact durable. `critic` reaktif **tetap berlaku** untuk invarian yang muncul belakangan — gate ini **melengkapi**, bukan menggantikan.

## 3. Prinsip yang Dijaga

- **Generic over prescriptive.** `invariants.md` template menyodorkan **slot saran** umum-SaaS; `architect` boleh menambah invarian spesifik-produk atau menandai yang tak relevan `N/A`. Tak ada asumsi "ini pasti ecommerce".
- **JIT tidak dilanggar.** Invarian = keputusan mahal-di-refactor yang memang harus di-depan (beda dari knowledge bisnis yang tumbuh per-fitur). Ini justru **wujud** kalimat spec induk §4: "keputusan fondasi yang mahal di-refactor tetap dikunci tepat waktu" — kita cuma memindahkan "tepat waktu" dari "fitur pertama yang nyentuh" ke "sebelum table pertama dibuat", dan menjadikannya gate, bukan harapan.
- **Status/knowledge sebagai byproduct gate.** `sensitivity` tag & invarian lahir di gate yang sudah ada (intake gate, architect gate), bukan flag manual terpisah.
- **Anti-yes-man diperkuat, bukan ditambah seremoni.** Gate keamanan **berskala** — fitur receh bayar murah; pajak galak hanya untuk fitur ber-`sensitivity`. Menghindari friksi gate yang justru jadi keluhan (audit M7).

## 4. Artifact Baru — `control/invariants.md`

### 4.1 Lokasi & lifecycle
- Template di **`plugin/template/control/invariants.md`**, di-copy `init` (step 4 scaffold `control/`) bersama `business/`+`conventions.md`. Placeholder `<PRODUCT>` di-replace `init` seperti file lain.
- **Diisi** oleh `architect` (§5). **Dibaca** oleh `wire` (prasyarat), `plan`/`breakdown`/`build` (challenge), `intake` (cross-check tag), opsional `render-docs`.
- Hidup di `control/` (lintas-fitur durable), bukan `features/<fitur>/`.

### 4.2 Bentuk (skeleton template)
```
# <PRODUCT> — Invarian Platform

> Keputusan fondasi yang berlaku ke SELURUH produk; mahal diubah belakangan.
> Dikunci SEKALI oleh `architect` (langkah "Kunci Invarian") sebelum `wire`.
> Tiap slot: ISI keputusannya, ATAU tulis "N/A — <alasan>". Jangan biarkan "<belum dikunci>".

## Tenancy
<belum dikunci>

## Money & Currency
<belum dikunci>

## Idempotency
<belum dikunci>

## Authz / RBAC
<belum dikunci>

## PII / PCI / Data Sensitif
<belum dikunci>

## Rate-limit / Abuse
<belum dikunci>
```

### 4.3 Semantik slot
- **Resolved** = isinya bukan lagi `<belum dikunci>`. Boleh keputusan nyata (mis. "shared-db + `tenant_id` tiap table, di-enforce RLS + middleware") **atau** `N/A — <alasan>` (mis. "N/A — single-tenant, satu org pakai").
- Enam slot = **default saran**, bukan wajib semua terisi-nyata. `architect` boleh **tambah** heading invarian baru (mis. `## Multi-region`, `## Audit Log`) atau `N/A`-kan yang tak relevan.
- **Wajib sebelum `wire`:** TIDAK ada slot yang masih `<belum dikunci>` (semua resolved). Inilah yang dicek `wire` (§6).

## 5. H1 — Langkah "Kunci Invarian" di `architect` + Prasyarat `wire`

### 5.1 `architect`: langkah baru (gated, sekali, level-produk)
Tambah langkah **"Kunci Invarian Platform"** di `plugin/skills/architect/SKILL.md`, **ditempatkan sebagai langkah 4.5** (setelah "Konvensi lintas-app" line 31-32, sebelum "Challenge Checklist" line 34) — **dipilih 4.5 (desimal) sengaja agar tak me-renumber langkah 5/6** (pelajaran renumber-cross-ref). Perilaku:
1. Baca `control/invariants.md`. **Idempotent:** kalau **semua slot sudah resolved** → tampilkan ringkas + konfirmasi, **jangan tanya ulang** (penting: `architect` di-rerun & dipanggil `add-app` per app baru — penguncian invarian level-produk **tidak** boleh terjadi tiap app).
2. Kalau ada slot `<belum dikunci>`: **ELICIT** per slot — tanya keputusannya (level fondasi, bukan stack); user boleh jawab `N/A — alasan`. Sodorkan slot saran; terima invarian tambahan spesifik-produk.
3. Tulis hasil ke `control/invariants.md` (replace `<belum dikunci>`).
4. **`critic` WAJIB** di gate ini (bukan kondisional) — red-team atas `invariants.md`: ada invarian fondasi kelewat? keputusan berisiko / over-engineered? bentrok antar-invarian? Tanggapi tiap keberatan sebelum gate lewat.
5. Gate `architect` (step 6 line 39-40) **diperluas**: tampilkan `stack` + `capabilities` + `conventions.md` + **`invariants.md`** untuk approve.

Catatan ordering: invarian dikunci di level-produk bersama `conventions.md`, **setelah** Q&A stack per-app (step 3). Idealnya tenancy menginformasikan pilihan DB per-app; untuk v1 cukup keduanya direview bareng di gate yang sama (kalau invarian mengubah keputusan per-app, itu muncul di gate). Penguatan ordering = refinement future.

### 5.2 `wire`: prasyarat baru (penolak)
Di `plugin/skills/wire/SKILL.md` **langkah 0** (line 22-23, yang kini menolak kalau `stack` logical belum diset), **tambah** cek: baca `control/invariants.md`; kalau **tidak ada** atau **masih ada slot `<belum dikunci>`** → **STOP**, arahkan ke `architect` ("kunci invarian dulu"). Konsisten dengan mekanisme penolakan yang sudah ada di `wire:23` (logical field hilang → balik ke architect). Ini backstop: normalnya gate `architect` sudah memastikan resolved.

## 6. H4 — Security & Compliance Gate di `ship`

### 6.1 Agent baru `plugin/agents/security-critic.md`
Meniru bentuk `critic.md` (read-only, tools `Read, Grep, Glob`, output keberatan bernomor + klausa anti-mengarang). Beda fokus: bukan alignment-bisnis, melainkan **red-team DIFF fitur** mencari:
- **Secret/credential hardcoded** ke-commit (API key, token, password, connstring).
- **PII di log / response** tak semestinya (email, nama, alamat, telp, gov-id).
- **Data kartu (PAN/CVV) disimpan** → pelanggaran PCI.
- **Webhook/endpoint masuk** tanpa verifikasi signature/origin.
- **Endpoint tanpa cek tenant/role** (bocor lintas-tenant / privilege escalation) — **bersilang dengan invarian Tenancy/Authz** di `invariants.md` (agent membacanya sebagai baseline).
- **Input tak divalidasi** (injection surface).

Input agent: diff fitur (path/SHA per repo dari `ship`) + `control/invariants.md` + `control/conventions.md`. Output: daftar temuan + severity (high/med/low), read-only.

### 6.2 Tag `sensitivity` (alir intake → feature.yaml → ship)
- **`feature.yaml` skema** nambah field `sensitivity: []` (lihat §7). Ditulis kosong saat folder fitur dibuat (`feature` step 1 line 12-18 / `intake` step 1 line 12-18).
- **`intake` (step 7, line 38-50, sesudah `business.md` jadi):** **usulkan** tag dari isi `business.md` secara heuristik — `payments` kalau fitur menggerakkan/menyimpan uang (bayar, billing, payout, refund, fee); `pii` kalau mengumpulkan/menyimpan/menampilkan data pribadi. **Cross-check ringan ke `invariants.md`** (kalau slot PII/PCI di-`N/A`, jangan ngotot tag `pii`). Tampilkan usulan di **gate intake** untuk **konfirmasi/koreksi** user; tulis ke `feature.yaml`. Kosong diperbolehkan.

### 6.3 `ship`: langkah "Security & Compliance Gate"
Tambah di `plugin/skills/ship/SKILL.md` sebagai **langkah 4.5** (setelah "Challenge Checklist" step 4 line 24-28, sebelum "Putuskan" step 5 line 30-32) — **desimal 4.5 sengaja agar tak me-renumber step 5/6 & tak memecah cross-ref internal "lanjut Step 6" di `ship:31`** (persis bug renumber `5520de5`; lihat §11). Perilaku:
1. Baca `feature.yaml` `sensitivity` (step 1 line 12-14 diperluas membacanya).
2. **`sensitivity` kosong →** **quick scan** murah: `ship` sendiri grep diff untuk secret hardcoded + PII di log. Temuan → angkat ke "Putuskan".
3. **`sensitivity` memuat `payments`/`pii` →** invoke **`security-critic`** atas diff penuh (lintas repo yang kena). Temuan **high** = **RED**.
4. Tambah **satu item** ke Challenge Checklist `ship` (step 4): "Ada temuan `security-critic`/quick-scan yang belum kelar? secret/PII/PCI/authz/webhook-signature?".
5. "Putuskan" (step 5/6) memperlakukan temuan high security sebagai **merah → STOP, jangan ship** (sebobot quality gate).

## 7. Perubahan Skema `feature.yaml`

Tambah satu field opsional:
```yaml
name: <fitur>
status: draft
created: <YYYY-MM-DD>
sensitivity: []        # [] | [payments] | [pii] | [payments, pii] — diusulkan intake, dikonfirmasi user
```
Penulis: `feature` step 1 + `intake` step 1 (kosong saat buat), `intake` step 7 (isi usulan). Pembaca: `ship` step 1/4.5. Field absen pada fitur lama = diperlakukan kosong (backward-compatible).

## 8. M2 — Ikat Invarian ke Gate (1 baris × 3 skill)

Tambah **satu item challenge** (di langkah "Challenge"/"Challenge Checklist" masing-masing):
> "Apakah plan/task ini melanggar invarian yang terkunci di `control/invariants.md`?"

- `plan/SKILL.md` step 3 "Challenge teknis" (line 26).
- `breakdown/SKILL.md` step 6 critic / coverage (sekitar line 30-34).
- `build/SKILL.md` step 6 "challenge checklist" gate per-segmen (line 42-43).

**Sengaja dipotong (Langkah 1):** klausa "membypass mandatory package" — saat itu butuh H2/`packages[]` yang belum ada. **Direalisasikan di H2** (`docs/superpowers/specs/2026-06-01-h2-shared-package-design.md` §9): field `packages[].mandatory_for` + 1 baris challenge "membypass mandatory package?" di `plan`/`breakdown`/`build`.

## 9. Permukaan Integrasi (peta edit file)

| File | Perubahan |
|---|---|
| `plugin/template/control/invariants.md` | **BARU** — skeleton §4.2 |
| `plugin/skills/init/SKILL.md` | Pastikan `invariants.md` ikut ter-copy + `<PRODUCT>` ter-replace (step 4 line 35-36 sudah `cp -R control/.` → otomatis ke-copy; verifikasi klausa replace `<PRODUCT>` mencakupnya) |
| `plugin/skills/architect/SKILL.md` | Langkah 4.5 "Kunci Invarian" (§5.1); gate step 6 tampilkan invariants.md; catatan idempotent untuk add-app |
| `plugin/skills/wire/SKILL.md` | Langkah 0 prasyarat baca invariants.md (§5.2) |
| `plugin/skills/intake/SKILL.md` | Step 1 tulis `sensitivity: []`; step 7 usulkan tag + cross-check invariants.md (§6.2) |
| `plugin/skills/feature/SKILL.md` | Step 1 skema feature.yaml + `sensitivity: []` (§7) |
| `plugin/skills/plan/SKILL.md` | 1 item challenge invarian (§8) |
| `plugin/skills/breakdown/SKILL.md` | 1 item challenge invarian (§8) |
| `plugin/skills/build/SKILL.md` | 1 item challenge invarian (§8) |
| `plugin/skills/ship/SKILL.md` | Langkah 4.5 Security Gate (§6.3); step 1 baca sensitivity; 1 item challenge keamanan |
| `plugin/agents/security-critic.md` | **BARU** — agent §6.1 |
| `plugin/skills/add-app/SKILL.md` | Catatan: `architect` yang dipanggil add-app **tidak** re-lock invarian (idempotent §5.1) |
| `plugin/skills/render-docs/SKILL.md` (+ template) | **Opsional/defer** — section "Invarian Platform" di doc; boleh tahap berikutnya |

## 10. Amandemen Spec Induk (`2026-05-24-…-design.md`)

- **§7 model `control/`** (line 63-81): tambah `invariants.md` ke pohon (sejajar `conventions.md`).
- **§9 `architect`** (line 148-155): tambah output `invariants.md` + langkah Kunci Invarian. **§9 `intake`** (line 167-172): tambah usulan `sensitivity`. **§9 `ship`** (line 186-193): tambah Security & Compliance Gate.
- **§10 Agent** (line 206-208): "Agent: `critic`" → "Agent: `critic`, `security-critic`".
- **§12 Lifecycle** (line 219-237): catatan invarian dikunci di `architect` sebelum `wire`; field `sensitivity` di feature.yaml.
- **§17 Komponen** (line 267-272): Agent (1→2); Knowledge `control/` tambah `invariants.md`.
- **README.md** + opsional `plugin/.claude-plugin/plugin.json` description: sebут invarian + security gate.

## 11. Rencana Verifikasi

Eksekusi via `writing-plans` → `executing-plans`. Setelah implement:
1. **YAML-lint / frontmatter:** tiap skill yang diedit masih valid (waspada colon-space di contoh YAML — bug berulang).
2. **Grep-battery konsistensi:** `invariants.md`, `sensitivity`, `security-critic`, `<belum dikunci>` muncul konsisten lintas file yang diklaim §9; tak ada pointer ke `packages[]`/`data-model.md`/`roadmap.yaml` (artifact fiktif).
3. **Renumber-cross-ref check (WAJIB):** karena kita menyisipkan langkah desimal di `architect` (4.5) & `ship` (4.5), pastikan **tidak** ada cross-ref internal "Step N" yang basi — khusus verifikasi `ship:31` "lanjut Step 6" tetap valid (step 6 = Kirim) setelah sisipan 4.5. (Bug ini lolos 2× sebelumnya: `5520de5`.)
4. **Dry-run skenario:** (a) `wire` dijalankan dengan `invariants.md` belum-lock → harus STOP balik ke architect; (b) `architect` rerun dengan invarian sudah resolved → harus skip-konfirmasi, tak tanya ulang; (c) `ship` fitur `sensitivity:[payments]` dengan secret hardcoded di diff → harus RED/STOP; (d) `ship` fitur `sensitivity:[]` → quick scan, tak panggil security-critic.
5. **1 ronde baca-adversarial di SESI TERPISAH** khusus mis-aimed pointer `skill→reference`/`§X` + staleness parent-spec — pelajaran berulang: mis-aimed pointer lolos verify sesi-eksekusi sendiri (sudah 4× kejadian, termasuk bug di SPEC bukan skill).

## 12. Out of Scope → Langkah 2 (pointer)

Spec berikutnya menggarap akar yang merembet & governance evolusi: **H2** (`packages[]` + skill `add-package` + fan-IN) — **sudah dispec & direalisasikan** (`2026-06-01-h2-shared-package-design.md`), termasuk M2-bagian "mandatory package". Berikutnya: **M5** (`control/integrations.md` + plan promote vendor + webhook-idempotency bar), **M4** (`control/schema/<app>.md` sebagai projeksi ter-generate dari migrations), **H3** (impact-analysis migrasi lintas-fitur + `migrate.kind/affects`).
