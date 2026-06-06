# context-vault — AI-First Product Boilerplate (Design Spec)

- **Tanggal:** 2026-05-24
- **Status:** Draft disetujui untuk masuk tahap perencanaan implementasi
- **Repo:** https://github.com/stevanus1997/context-vault

---

## 1. Ringkasan

`context-vault` adalah boilerplate yang **bukan berisi kode aplikasi** (pages, components, dll), melainkan **lapisan AI + knowledge** untuk mengelola sebuah produk yang terdiri dari banyak aplikasi/repo. Tujuannya: setiap memulai produk baru, cukup `init` dan langsung punya tooling AI + struktur knowledge yang konsisten.

Unit yang dikelola **bukan "satu project", tapi "satu produk = banyak app"**. Lapisan `control/` menyimpan knowledge yang hidup *di atas* masing-masing app, dan sekumpulan skill yang menjalankan alur kerja dari ide bisnis sampai siap-kirim.

## 2. Masalah yang Diselesaikan

Konteks: developer solo mengelola satu produk yang terpecah ke banyak repo (mis. web, mobile, cms-internal, cms-eksternal, dashboard, support). Tiga masalah inti:

- **P1 — Fan-out lintas repo.** Satu fitur menyebar ke banyak app, dan hanya developer yang menyimpan peta "fitur ini menyentuh repo mana saja dan melakukan apa". AI di tiap repo hanya tahu reponya sendiri.
- **P2 — Knowledge bisnis tidak punya rumah.** AI selalu mulai dari *kode*, padahal kode tidak menyimpan business process/flow. Akibatnya Q&A langsung melompat ke teknis. Yang diinginkan: dua fase — **Q&A bisnis dulu** (dibatasi yang feasible dengan codebase), baru **Q&A teknis**.
- **P3 — AI yes-man.** AI tidak menantang, tidak mengecek keselarasan dengan bisnis, hanya mengiyakan.

Benang merah: knowledge yang hidup *di atas* tiap repo tidak punya tempat, dan AI selalu mulai dari kode, bukan dari bisnis.

## 3. Tujuan & Non-Tujuan (Scope v1)

**Tujuan:**
- Struktur knowledge per-produk yang konsisten dan tumbuh seiring waktu.
- Pipeline dari ide → spec bisnis → peta lintas-app → plan teknis per-app.
- Disiplin anti-yes-man yang terstruktur (bukan sekadar instruksi).
- Dokumen human-readable yang selalu sinkron dengan knowledge (di-generate, bukan ditulis manual).
- Mendukung produk baru (greenfield) maupun adopsi repo yang sudah ada (brownfield), monorepo maupun multi-repo.

**Non-tujuan (v1):**
- Eksekusi/implementasi kode otomatis lintas app — pakai pola yang sudah ada (executing-plans / subagent). Pipeline berhenti di plan yang disetujui; `ship` menutup setelah implementasi manual.
- MCP knowledge server — kemungkinan upgrade berikutnya.
- Status `in-review` (membedakan "PR dibuka" vs "sudah merged").

## 4. Konsep Inti

- **Just-in-time knowledge.** Knowledge tidak ditulis tebal di depan. `init` hanya menanam "north star" tipis; knowledge tumbuh sebagai byproduct dari setiap fitur yang dikerjakan, di-update di setiap gate dan di-review user. Keputusan fondasi yang mahal di-refactor tetap dikunci tepat waktu oleh `critic` saat fitur pertama menyentuhnya.
- **Satu sumber kebenaran, banyak proyeksi.** Knowledge (yaml + markdown) dibaca AI langsung; dokumen HTML human-readable di-*generate* dari sumber yang sama — tidak pernah diedit manual, jadi tidak pernah drift.
- **Status sebagai byproduct.** Perubahan status fitur terjadi otomatis di gate atau sebagai hasil menjalankan skill (`ship`/`drop`), bukan flag manual yang mudah terlupa.
- **Program to an interface.** Skill membaca `workspace.yaml` (abstraksi), bukan path/topologi hardcoded — sehingga monorepo & multi-repo jalan dengan kualitas sama.

## 5. Arsitektur (Hybrid)

Repo `context-vault` punya dua bagian:

- **`plugin/`** — diinstall sekali (reusable lintas produk): skills + agent + rules. Didistribusikan sebagai Claude Code plugin via marketplace.
- **`template/`** — di-copy saat `init` (per produk): scaffold `control/`.

Pembagian: **knowledge → control (per produk)**, **skill → plugin (reusable)**.

## 6. Topologi

- **Default monorepo** untuk produk baru (greenfield) — ongkos migrasi nol, atomic cross-app change, akses AI terbaik.
- **Topology-agnostic** lewat `workspace.yaml`: perbedaan monorepo vs multi-repo hanya nilai `path` per app + flag `topology`. Skill membaca manifest, tidak hardcode.
- **`control/` konsisten** di kedua topologi: di monorepo ia subfolder; di multi-repo ia repo tersendiri (hub) yang `path`-nya menunjuk `../<app>`.

## 7. Model Knowledge (`control/`)

```
control/
├── workspace.yaml        # System Map (sumber kebenaran untuk AI)
├── business/
│   ├── domain.md         # aturan domain
│   ├── flows.md          # business process / flow
│   ├── glossary.md       # istilah
│   └── risks.md          # risiko compliance durable (M6; diisi discovery)
├── conventions.md        # konvensi & kontrak teknis lintas-app
├── invariants.md         # invarian platform (tenancy/money/idempotency/authz/PII-PCI/rate-limit; dikunci architect)
├── integrations.md       # kontrak SHAPE vendor eksternal (M5; diisi add-integration)
├── design-system.md      # fondasi visual: tokens+motion+komponen primitif per gaya (diisi design-system)
├── schema/               # proyeksi skema per app (generated wire/build dari skema/migrasi; M4; tak di-scaffold init)
│   └── <app>.md
├── features/
│   └── <nama-fitur>/
│       ├── feature.yaml  # status + metadata
│       ├── business.md   # output intake
│       ├── fanout.md     # output fanout
│       ├── plans/
│       │   ├── _shared.md   # kontrak lintas-app (mis. mekanisme token)
│       │   └── <app>.md     # plan teknis per app
│       └── mockups/        # mockup UI diserahkan user (byte opaque; ditulis plan, dibaca build), bila ada
├── fixes/                # lane bugfix (post-ship) — entitas first-class
│   └── <id>/
│       ├── fix.yaml      # status + severity + relates_to + root_cause
│       ├── notes.md      # repro + log root-cause
│       └── tasks.yaml    # mini (milestone-wrapped)
└── docs/
    └── site/index.html   # doc human-readable (generated)
```

### 7.1 `workspace.yaml` (skema)

```yaml
product: <nama-produk>
topology: monorepo            # atau: multi-repo
apps:
  - name: web
    path: apps/web            # monorepo: apps/web | multi-repo: ../web
    repo_url: git@…:web.git    # diisi untuk multi-repo
    type: fullstack           # fe | be | fullstack
    responsibility: "Builder landing page + dashboard"
    capabilities: [auth, workspace]   # tumbuh per fitur (fanout)
    stack: { framework: Next.js, db: Postgres }   # diisi architect
packages:                            # shared package (H2) — diisi add-package
  - name: money
    path: packages/money
    type: package
    responsibility: "format dan hitung uang"
    consumers: [web, api]            # diisi fanout; basis fan-IN
    mandatory_for: []                # app yang wajib pakai package ini
```

- `capabilities` = bahan bakar fan-out (P1). Diisi bertahap oleh `fanout` (greenfield) atau lebih awal oleh `architect` (brownfield).
- `packages` = shared code lintas-app (H2). Entri ditulis `add-package`; `consumers` (basis fan-IN) ditulis `fanout`. Lihat spec `2026-06-01-h2-shared-package-design.md`.
- `stack` = diisi `architect`. Untuk fitur berikutnya, `plan` membaca kode + `conventions.md`.

### 7.2 Pemisahan tulisan knowledge

Setiap stage menulis **dua jenis**:
1. **Artifact per-fitur** → selalu di `features/<nama>/`.
2. **Knowledge durable** (reusable, lintas-fitur) → dipromosikan ke `business/`, `workspace.yaml`, `conventions.md`.

Promosi dilakukan **konservatif** (hanya fakta yang benar lepas dari fitur), supaya `features/` yang di-drop jarang berdampak ke knowledge global. Semua promosi di-review user di gate.

## 8. Struktur Repo

**Repo boilerplate (yang dibangun & dirawat):**
```
context-vault/
├── plugin/
│   ├── .claude-plugin/plugin.json
│   ├── skills/   discovery· init· architect· wire· design-system· add-app· add-package· add-integration· extract· intake· fanout· plan· feature· breakdown· build· ship· drop· render-docs· fix· ask· debt
│   ├── agents/   critic.md· security-critic.md
│   └── rules/    anti-yes-man.md· debt-aware.md· schema-projection.md· migration-impact.md· compliance-risk.md   # anti-yes-man di-merge ke CLAUDE.md; sisanya dirujuk skill
├── template/
│   ├── control/  (workspace.yaml· business/· conventions.md· invariants.md· integrations.md· design-system.md· features/· docs/ theme warm)
│   └── .claude/  settings.json· CLAUDE.md (starter)
├── .claude-plugin/marketplace.json
└── README.md
```

**Produk hasil `init` (monorepo):**
```
my-product/
├── .claude/  settings.json· CLAUDE.md     # root (wajib di sini)
├── control/  …knowledge…
├── apps/  web/· api/· …
└── packages/  + tooling monorepo (turbo.json, package.json)
```

**Produk multi-repo (brownfield):** `control/` jadi repo hub; tiap app tetap repo terpisah sebagai sibling; `workspace.yaml` `path` menunjuk `../<app>`. Repo existing **tidak dimigrasi**.

## 9. Skills

Format tiap skill: **Tujuan · Input · Perilaku · Output · Gate.**

### `init`
- **Tujuan:** bootstrap produk (greenfield) atau adopsi (brownfield).
- **Input:** dijalankan di folder produk.
- **Perilaku:** inspect folder (kosong → greenfield; `apps/`+config monorepo → monorepo; banyak `.git` sibling → multi-repo) → konfirmasi topologi → scaffold `control/` dari template → seed `workspace.yaml` (greenfield: declare apps; brownfield: detect apps + auto-isi `stack` dari package.json) → seed `domain.md` dari framing singkat → merge `anti-yes-man.md` ke `CLAUDE.md`.
- **Output:** `control/` siap + `workspace.yaml` awal + `.claude/` terset.
- **Gate:** konfirmasi topologi & daftar app sebelum menulis.

### `architect`
- **Tujuan:** menetapkan/merekam fondasi teknis (eksplisit, terpisah dari fitur bisnis).
- **Perilaku:**
  - *Greenfield (mode setup):* Q&A teknikal untuk menetapkan stack tiap app + konvensi lintas-app → tulis `workspace.yaml.stack` + `conventions.md` (+ scaffold dasar).
  - *Brownfield (mode capture):* scan kode tiap repo → rekam stack + konvensi, **populate `capabilities`** dari nama route/module/folder, flag divergensi antar-repo (mis. ORM berbeda).
- **Output:** `workspace.yaml` (stack + capabilities) + `conventions.md` + `invariants.md` (invarian platform dikunci sekali, gated, `critic` wajib — sebelum `wire`).
- **Gate:** review stack/konvensi/capabilities.
- **Catatan:** bisa di-jalankan ulang saat menambah app/shared package.

### `extract` (brownfield, opsional)
- **Tujuan:** front-load `business/` dari kode existing untuk produk yang sudah besar.
- **Perilaku:** scan kode lintas repo + wawancara user → isi `business/` (domain/flows/glossary). Dijalankan **lewat gate + `critic`** (bukan dump mentah; critic mem-flag aturan spekulatif/belum terverifikasi).
- **Output:** `business/` ter-isi. **Format sama** dengan output `intake` — sehingga knowledge dari `extract` (upfront) dan `intake` (just-in-time) mendarat di tempat & format yang sama.

### `feature` (konduktor)
- **Tujuan:** menjalankan pipeline fitur bisnis end-to-end dengan gate.
- **Perilaku:** buat `features/<nama>/` (`feature.yaml` status `draft`) → jalankan `intake` →(gate)→ `fanout` →(gate)→ `plan` semua app yang kena →(gate). Setelah gate `plan` terakhir lulus → status otomatis `active`.
- **Output:** mengkoordinasi output ketiga sub-skill (tidak membuat file sendiri).

#### `intake` (P2 fase 1)
- **Input:** ide fitur + `business/*.md` + `workspace.yaml`.
- **Perilaku:** Q&A **level bisnis** (bukan teknis); cek feasibility kasar dari `capabilities`; jalankan **challenge checklist**; panggil `critic` di gate penting.
- **Output:** `features/<nama>/business.md` + promosi knowledge durable ke `business/` + usulan tag `sensitivity` (`payments`/`pii`, cross-check `invariants.md`) di `feature.yaml`.
- **Gate:** approve `business.md` + promosi knowledge + tag `sensitivity`.

#### `fanout` (P1)
- **Input:** `business.md` + `workspace.yaml` (capabilities).
- **Perilaku:** cocokkan kebutuhan fitur ke `capabilities`/`responsibility` tiap app → tentukan app yang kena & perannya; **adaptif**: bila hanya 1 app → konfirmasi cepat; bila banyak → breakdown penuh. Boleh menerima hint `--app`, tetapi **tetap memverifikasi** (bisa mengoreksi bila ternyata menyentuh app lain). Challenge: "ada app kelewat? dependency lintas-app? butuh vendor eksternal?". Baca `integrations.md` → tandai `VENDOR NEW`/`VENDOR TOUCHED`/`VENDOR TOUCHED — perlu UPDATE` (diwujudkan `add-integration`).
- **Output:** `features/<nama>/fanout.md` (+ penanda `VENDOR …`) + update `capabilities` di `workspace.yaml`.
- **Gate:** approve/koreksi (user paling tahu peta produk).
- **Prinsip:** "cuma 1 app" adalah **kesimpulan** fanout, bukan input — karena itu fanout tidak pernah di-skip.

#### `plan` (P2 fase 2)
- **Input:** `business.md` + `fanout.md` + **kode app** yang kena + `conventions.md` + `integrations.md` (kontrak vendor, read-only).
- **Perilaku:** selesaikan **kontrak lintas-app** dulu (mis. mekanisme token) + **promote kontrak vendor** dari `integrations.md` ke `_shared.md` (O(1), idempotent) → untuk tiap app: baca kode/konvensi, Q&A **teknis**, susun plan (file, endpoint, model data, test; baris kebutuhan receiver untuk webhook vendor inbound); challenge teknis. (Karena `architect` sudah jalan, `plan` selalu membaca stack yang ada — tidak menetapkan stack.)
- **Output:** `features/<nama>/plans/_shared.md` + `plans/<app>.md`.
- **Gate:** approve per app → siap dieksekusi.

### `ship` (finishing dev)
- **Tujuan:** gate kualitas + kirim, menjadikan `shipped` sebagai byproduct.
- **Perilaku:** dijalankan setelah implementasi (manual/pakai pola existing). Langkah:
  1. **Code review** atas diff fitur.
  2. **Quality gate** — test, lint, typecheck, build.
  2.5. **Security & Compliance gate** — berskala ke `sensitivity` fitur; `payments`/`pii` → subagent `security-critic` red-team diff (secret/PII/PCI/authz/webhook) terhadap `invariants.md` + `integrations.md` (baseline webhook) + `risks.md` (baseline compliance, M6); temuan high → STOP. PR menyertakan runbook integrasi (webhook-URL + secret-NAMA + test→live). Bila ada tugas `migrate`, PR juga menyertakan runbook urutan migrasi & deploy (advisory; H3).
  3. **Business alignment** — bandingkan kode yang jadi vs `business.md` + `plan` (pakai `critic`): apakah yang dibangun sesuai maksud bisnis? ada scope creep / requirement kelewat? *(Cek ini hanya mungkin karena ada `business.md` — payoff sistem knowledge, sekaligus jawaban P3.)*
  - Jika **semua hijau:** buat **PR** dengan deskripsi auto dari `business.md`+`fanout.md`+`plans`+diff (multi-repo → PR per app yang kena) → set status `shipped` → trigger `render-docs`.
  - Jika **ada merah:** laporkan kegagalan/misalignment, **stop — tidak ship** (anti-yes-man, tidak rubber-stamp).

### `drop`
- **Tujuan:** membatalkan fitur (`draft`/`active`).
- **Perilaku:** tanya alasan → set status `dropped` + reason + tanggal; review promosi knowledge fitur ini ("keep atau revert?" — `critic` membantu flag; bila fitur memperkenalkan vendor → pengingat tinjau entri `integrations.md`); folder **dikeep** sebagai memori keputusan; branch git diingatkan (urusan git user).

### `render-docs`
- **Tujuan:** knowledge → dokumen human-readable.
- **Input:** `workspace.yaml` + `business/` + `integrations.md` + `features/`.
- **Perilaku:** render ke single HTML (layout sidebar B1, tema Warm/Friendly), **filter by status** (fitur `dropped` tidak tampil / masuk section terpisah).
- **Output:** `control/docs/site/index.html`.
- **Trigger:** otomatis saat `shipped`; bisa dipanggil manual kapan saja untuk preview.

## 10. Agent: `critic` & `security-critic`

Agent terpisah (konteks sendiri) yang tugasnya **mencari celah/bentrok/blind-spot**. Dipanggil di gate penting (`intake` untuk keputusan fondasi, `architect` untuk kunci invarian, `ship` untuk business alignment). Mengembalikan daftar keberatan; agent utama wajib menanggapi sebelum gate lewat. Pemisahan ini menghilangkan bias "yang mengusulkan = yang menilai".

Agent kedua **`security-critic`** (read-only, konteks sendiri): dipanggil `ship` di Security & Compliance Gate untuk fitur ber-`sensitivity` — red-team DIFF mencari kerentanan (secret/PII/PCI/authz-tenant/webhook-signature/input). Sama prinsipnya: penilai ≠ pengusul.

## 11. Anti-Yes-Man (P3)

Tiga lapis bertumpuk:
1. **Baseline rule** (`anti-yes-man.md`, selalu di CLAUDE.md): sikap kritis, menantang yang bentrok aturan/berisiko, memunculkan tradeoff.
2. **Challenge checklist** — wajib diisi & ditampilkan tiap gate: *bentrok aturan mana? tradeoff? ada cara lebih simpel? apa yang bisa jebol?*
3. **`critic` sub-agent** di gate penting — red-team dengan mata fresh.

Alasannya struktural: yes-man muncul karena helpful-bias + tidak ada cek independen. Maka kritik dibuat sebagai **step**, bukan harapan.

## 12. Lifecycle & Status Fitur

```
Greenfield: init → architect(setup)  →                wire → /feature → breakdown → build → ship
Brownfield: init → architect(capture) → extract(opsi) → wire → /feature → breakdown → build → ship
```

**Cabang dipicu — fitur butuh app baru:** bila `fanout` mendeteksi tidak ada app existing yang menampung sebuah peran, `feature` otomatis invoke **`add-app`** (declare entri ke `workspace.yaml` → `architect` → `wire`) sebelum `plan`. `add-app` juga bisa dipanggil standalone. Lihat spec `2026-05-31-add-app-skill-design.md`.

**Cabang dipicu — fitur butuh shared package baru:** bila `fanout` menandai kode-bareng >1 app sebagai `PACKAGE NEW`, `feature` otomatis invoke **`add-package`** (declare entri ke `packages[]` → `architect` → `wire` mode-package, gate typecheck) sebelum `plan`. Saat API shared package berubah, `breakdown` menerbitkan update-task per consumer (fan-IN). Task hidup di `unit` (app ATAU package). Lihat spec `2026-06-01-h2-shared-package-design.md`.

**Cabang dipicu — fitur butuh vendor eksternal:** bila `fanout` menandai kebutuhan layanan pihak-ketiga sebagai `VENDOR NEW` (atau `VENDOR TOUCHED — perlu UPDATE`), `feature` otomatis invoke **`add-integration`** (declare kontrak SHAPE ke `control/integrations.md` → `wire` mode-integration buat stub webhook-receiver bila inbound) sebelum `plan`. `add-integration` TAK chain `architect` (vendor tak punya stack). Webhook inbound jadi task `unit:<app>` varian inbound-eksternal (verifikasi signature/idempotent/replay). Lihat spec `2026-06-01-m5-integrations-design.md`.

**Cabang dipicu — fitur UI butuh design system:** bila `fanout` menandai app peran-UI yang **belum terdaftar** di `control/design-system.md` sebagai `DESIGN-SYSTEM NEEDED`, `feature` otomatis invoke **`design-system`** (tentukan scope gaya → SETUP greenfield dari mockup / CAPTURE brownfield dari kode → tulis `control/design-system.md` + bangun token & komponen primitif via atom dispatch Spec A) sebelum `plan`. Dua-mode simetris `architect`. Standalone `/design-system` juga tersedia. Lihat spec `2026-06-05-design-system-bring-up-design.md`.

**Lane korektif — defect (bug):** untuk perilaku yang **sudah ada** & salah, **`/fix`** (auto-deteksi mode). **in-flight** (fitur `active`): corrective task `kind: fix` di `tasks.yaml` fitur, eksekusi lewat `build`, berhenti di ijo (ship nanti sekalian fitur). **post-ship** (fitur `shipped`/tanpa-fitur): `control/fixes/<id>/` first-class, berhenti di "siap ship" → `/ship <fix>` TERPISAH. `build`/`ship` di-generalisasi (work-item = fitur ATAU fix). Lihat spec `2026-06-02-fix-bugfix-lane-design.md`.

**Invarian platform & sensitivity:** `architect` mengunci invarian platform (`control/invariants.md`) **sekali sebelum `wire`** (gated, `critic` wajib); `intake` menandai `feature.yaml` `sensitivity` (`payments`/`pii`) yang menyetir kedalaman Security & Compliance Gate di `ship`. Lihat spec `2026-06-01-platform-invariants-security-gate-design.md`.

Status di `feature.yaml`:

| Status | Dipicu oleh | Otomatis/Manual |
|---|---|---|
| `draft` | `/feature` dimulai | otomatis |
| `active` | gate `plan` terakhir lulus | otomatis |
| `shipped` | `/ship` semua-hijau | hasil menjalankan skill |
| `dropped` | `/drop` | hasil menjalankan skill |

Status `fix.yaml` (post-ship): `open` (`/fix` mulai) → `diagnosed` (root_cause terisi) → `shipped` (`/ship` hijau) (+ `dropped` bila bukan-bug). Progress halus `fixing`/`done` dibaca dari `fixes/<id>/tasks.yaml`.

Status sengaja kasar (4); progress halus dalam `draft` dibaca dari artifact yang sudah ada (`business.md`/`fanout.md`/`plans/`).

## 13. Dokumen Human-Readable

- **Single HTML**, di-generate dari knowledge yang sama (no hand-edit → no drift).
- **Layout B1:** sidebar topik (Overview · Apps · Model Data · Kapabilitas · Flows · Glossary · Fix/Known Issues); menu "Apps" → daftar app → detail app (fungsi, kapabilitas, flow terkait, repo). (Section Model Data & Fix/Known Issues di-skip kalau kosong, per spec masing-masing.)
- **Gaya Warm/Friendly** (Notion-ish) — ramah pembaca non-teknis (PM, stakeholder).
- Karena manusia & AI membaca kebenaran yang sama, dokumen ini tidak mungkin bohong relatif terhadap yang AI tahu.

## 14. Greenfield vs Brownfield

| | Greenfield | Brownfield (adopt) |
|---|---|---|
| `init` | declare apps | detect apps + auto-isi stack |
| `architect` | setup stack | capture stack+konvensi, flag divergensi |
| `capabilities` | tumbuh per fitur | dipopulate awal dari scan kode |
| `business/` | dari nol, per fitur | tipis dulu (+ opsi `extract`), di-ekstrak pas `/feature` |
| repo | dibuat baru | dipakai apa adanya, tidak dimigrasi |

## 15. Pemetaan ke P1/P2/P3

- **P1** → `fanout` + `capabilities` di System Map; `plan` menangani kontrak lintas-app (`_shared.md`).
- **P2** → `intake`(bisnis) lalu `plan`(teknis); knowledge tumbuh just-in-time, di-update tiap gate; `business/` sebagai rumahnya.
- **P3** → baseline rule + challenge checklist + `critic`, puncaknya pada **business-alignment di `ship`**.

## 16. Scope v1 & Pengembangan Berikutnya

- **v1 (in):** struktur knowledge, pipeline `feature` (intake→fanout→plan), `init`/`architect`/`extract`, `ship`/`drop`, `render-docs`, `critic`, anti-yes-man.
- **Future:** eksekusi/implementasi otomatis lintas-app (orchestrator), MCP knowledge server, status `in-review` (PR dibuka vs merged), auto-detect merge untuk trigger `shipped`.

## 17. Komponen (ringkas)

- **Skills (21):** `discovery` · `init` · `architect` · `wire` · `design-system` · `add-app` · `add-package` · `add-integration` · `extract` · `feature` (→ `intake` · `fanout` · `plan`) · `breakdown` · `build` · `ship` · `drop` · `render-docs` · `fix` · `ask` · `debt`
- **Agent:** `critic` · `security-critic`
- **Rules:** `anti-yes-man.md` · `debt-aware.md` · `schema-projection.md` · `migration-impact.md` · `compliance-risk.md`
- **Knowledge (`control/`):** `workspace.yaml` (apps[] + packages[]) · `business/` · `conventions.md` · `invariants.md` · `integrations.md` · `design-system.md` · `schema/` · `features/` · `docs/`

## 18. Open Questions (untuk dipertimbangkan saat implementasi)

- Bentuk teknis "skill memanggil skill" (orchestrator `feature` → `intake/fanout/plan`) di Claude Code: skill vs command vs sub-agent.
- Cara `ship` mendeteksi app mana yang berubah untuk multi-repo (dari `fanout.md` vs dari diff git).
- Format `feature.yaml` final (field minimal).
- Mekanisme `render-docs`: generator murni (script) vs skill yang menulis HTML; di mana template/tema warm disimpan.
