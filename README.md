# context-vault

AI-first product boilerplate — lapisan AI + knowledge (bukan kode) untuk mengelola produk multi-app dengan Claude Code.

> **Baru install / males baca?** Ketik `/guide` — panduan + tanya-jawab soal plugin ini (ada skill apa aja, flow-nya gimana, mulai dari mana).

## Install
```
/plugin marketplace add <path-atau-url-repo-ini>
/plugin install context-vault
```

## Kimi Code

Plugin ini juga bisa dipakai di [Kimi Code CLI](https://www.kimi.com/code/docs/en/) (MoonshotAI) lewat tree hasil generate `plugin-kimi/`. Source of truth tetap `plugin/` (format Claude Code) — **jangan edit `plugin-kimi/` langsung**; edit `plugin/` lalu regen.

- **Install:** buka `kimi` → `/plugins` → tab **Custom** → install dari path `<repo-ini>/plugin-kimi` → `/reload`.
- **Invokasi:** `/skill:<nama>` (mis. `/skill:guide`, `/skill:build checkout-v2`) — namespace beda dari Claude Code (`/context-vault:<nama>`).
- **Belum tersedia di Kimi (fase 2):** auto-title session (`sessionTitle` = fitur Claude-only) dan `build --unattended` — `kimi -p` auto-approve SEMUA tool, rem allowlist/deny belum terbukti berlaku di mode itu, jadi skill `build` versi Kimi akan MENOLAK `--unattended`.
- **Pola hybrid:** state produk hidup di disk (`control/`, `tasks.yaml`, git) — kerja interaktif bebas di Kimi/Claude; lane unattended tetap via Claude Code: `bash .claude/drive.sh <fitur>`.
- **Ritual rilis:** tiap rilis plugin → `bash tools/build-kimi.sh` (regen) + `bash tools/tests/build-kimi.test.sh` (jaga sync) → commit `plugin-kimi/`.
- Spec & keputusan desain: `docs/superpowers/specs/2026-07-21-kimi-code-port-design.md`.

## Mulai produk
```
# punya ide masih MENTAH? mulai dari sini (business consultant, lalu auto lanjut ke init)
/discovery

# produk sudah jelas (atau existing)? langsung:
/init
```
Lalu `architect` (fondasi teknis), `wire` (bring-up skeleton kosong-tapi-jalan), `feature` (bikin fitur), `ship`/`drop` (lifecycle), `render-docs` (doc human-readable).

## Validasi ide (opsional, greenfield)
```
/discovery          # business consultant pra-init: riset pasar/kompetitor/monetisasi + verdict go/no-go
```
Buat ide yang masih mentah. Nol teknis. Output: dok strategis HTML (`control/docs/discovery.html`) + seed awal `control/business/`; di akhir otomatis panggil `/init`. Tiap klaim disitasi + dilabeli keyakinan; `critic` menantang sebelum kamu menerima.

## Fondasi teknis
```
/architect          # tetapkan stack (greenfield) / rekam stack+capabilities (brownfield) + konvensi + kunci invarian platform
/wire               # bring-up: scaffold app + DB + wiring FE↔BE + env (skeleton kosong-tapi-jalan, gated)
/extract            # (brownfield, opsional) front-load business/ dari kode existing
```
Urutan brownfield: `/init` -> `/architect` -> `/extract` (opsional) -> `/wire` -> `/feature` -> `/breakdown` -> `/build` -> `/ship`.
Urutan greenfield (ide jelas): `/init` -> `/architect` -> `/wire` -> `/feature` -> `/breakdown` -> `/build` -> `/ship`.
Urutan greenfield (ide mentah): `/discovery` -> `/init` -> `/architect` -> `/wire` -> `/feature` -> `/breakdown` -> `/build` -> `/ship`.

## Bikin fitur
```
/feature <nama>     # konduktor: intake (bisnis) -> fanout (lintas-app) -> plan (teknis)
/breakdown <nama>   # pecah plan flat -> tasks.yaml (task kecil berurutan, tanpa kode)
/build <nama>       # eksekusi tasks.yaml: implementer subagent per task (TDD) + review + gate
```
Sub-skill bisa dipanggil sendiri: `/intake`, `/fanout`, `/plan`. Tiap tahap ada gate; agent `critic` me-review di gate penting. `breakdown` & `build` dipanggil eksplisit (boleh sesi terpisah) sebelum `ship`.

> `breakdown` kini bisa wakili kerja non-file (`actions:` migrate/install/env) & langkah manusia (`manual:`/status `needs_human`); `build` jalanin+verifikasi actions (migrasi lewat gate) dan uji integrasi cross-app; `build`/`ship` sadar multi-repo (branch & PR per repo).

> Kalau sebuah fitur butuh **app baru** (belum ada di `workspace.yaml`), `fanout` nandain dan `feature` otomatis panggil `add-app` (declare entri → `architect` → `wire`) sebelum `plan`. `add-app <nama>` juga bisa dipanggil standalone buat numbuhin produk pasca-`init`. Hal serupa untuk **shared package baru** (`add-package`, mode-package) dan **vendor eksternal** (`add-integration` — tulis kontrak SHAPE ke `control/integrations.md`, scaffold stub webhook bila inbound). Dan kalau fitur UI nyentuh app yang **belum punya design system**, `fanout` nandai `DESIGN-SYSTEM NEEDED` dan `feature` otomatis panggil `design-system` (turunin mockup jadi `control/design-system.md` + token & komponen primitif; dua-mode SETUP/CAPTURE) sebelum `plan`. `design-system` juga bisa standalone.

## Selesai & lifecycle
```
/ship <fitur>       # finishing: review + quality + security gate (sensitivity-scaled) + cek alignment ke business -> PR -> tandai shipped
/drop <fitur>       # batalkan fitur (tandai dropped + alasan, simpan sebagai memori keputusan)
/fix <apa-yang-rusak>   # lane bugfix: auto-deteksi in-flight (fitur active) / post-ship (fixes/<id>/); berhenti di ijo, ship terpisah
/debt <list|promote|drop>  # lane utang teknis: build catat saat nemu (pintu ke-4) → control/debt.yaml; resurface by locality (plan/fix) + Known Issues
```
> `/fix` = koreksi perilaku yang **sudah ada** (bukan `/feature` yang buat kapabilitas baru). in-flight → corrective task di `tasks.yaml` fitur; post-ship → `control/fixes/<id>/` first-class. `build`/`ship` work-item-aware (fitur ATAU fix).

## Perubahan kecil (jalur ringan)
```
/tweak <apa>        # perubahan KECIL berjejak: keputusan/kebijakan kecil → capture ke control/ tanpa pipeline berat; tripwire auto naik-kelas
```
| Skill | Kapan |
|---|---|
| `/tweak` | perubahan kecil, bukan bug, nggak fondasional — raih duluan |
| `/fix` | perilaku lama yang *salah* (defect) |
| `/feature` | kapabilitas baru / gede / lintas-app / fondasional |

## Auto-title session
Session Claude Code otomatis di-judul dari skill kerja yang dipanggil — `/build checkout-v2` → session `build: checkout-v2` di `/resume`. Skill kerja terakhir menang; skill read-only (`/ask`, `/guide`, `/render-docs`, `/debt`) tidak mengubah judul. Butuh Claude Code v2.1.196+ (versi lama: no-op aman). Catatan: nama hasil `/rename` manual bertahan sampai skill kerja berikutnya dipanggil (batasan hook Claude Code saat ini). Mekanisme `sessionTitle` via `UserPromptSubmit` diverifikasi empiris di v2.1.216 — docs resmi baru mencantumkannya untuk `SessionStart`; kalau CLI mendatang berubah, hook jadi no-op aman.

## Tanya produk (read-only)
```
/ask <pertanyaan>   # tanya APA PUN soal produk (greenfield/brownfield): knowledge-first, code-fallback
```
`ask` baca `control/` dulu (sumber kebenaran), turun ke kode cuma saat level-implementasi / knowledge tipis. Tiap jawaban sebut sumbernya; pas nemu catatan basi vs kode (drift) di-flag lalu di-route ke skill pemilik (`/architect`, `/intake`|`/feature`, `/add-integration`). **Tidak pernah nulis** — cuma jawab + (opsional) saran skill. Pelengkap read-side dari `render-docs`.

## Dokumentasi
```
/render-docs        # generate doc HTML human-readable dari knowledge -> control/docs/site/index.html
```
Otomatis dipanggil `ship`; bisa juga manual untuk preview.

## Maintenance / migrasi
```
/upgrade            # susulin produk LAMA (di-init versi plugin sebelumnya) ke template terbaru
```
`upgrade` menyamakan file scaffolding kubu-plugin ke template terkini — `.claude/` (hooks/ + drive.sh + merge settings.json + .gitignore) + file `control/` skeleton yang HILANG — **tanpa menyentuh knowledge** (control/ yang sudah ada, CLAUDE.md, notify.sh, kode). Idempoten + presence-based + GATE tiap tulis; **bukan** re-init/re-wire. Produk baru tak perlu (`init` terkini sudah lengkap).

## Desain
Lihat `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`.

## Status
Selesai (Fase 1–5): init, pipeline fitur (feature/intake/fanout/plan + critic), architect/extract, lifecycle (ship/drop), render-docs. Boilerplate context-vault lengkap end-to-end. **Tambahan (live di main):** `discovery` (business consultant pra-`init`), `wire` (bring-up skeleton kosong-tapi-jalan), `add-app` (nambah app baru pasca-init), `breakdown`+`build` (fase eksekusi plan→kode). **Hardening (Langkah 1 — audit ecommerce-builder):** invarian platform dikunci `architect` sebelum `wire` (di `control/invariants.md`) + **Security & Compliance Gate** di `ship` (berskala `sensitivity`, agent `security-critic`). **Langkah 2:** shared package end-to-end + fan-IN (`add-package`, `packages[]` — H2) + vendor eksternal durable (`add-integration`, `control/integrations.md`, webhook inbound + baseline `security-critic` — M5). **Lane bugfix:** `fix` (dua-mode in-flight/post-ship, `control/fixes/` first-class, work-item generalization `build`/`ship`). **Sisi-baca:** `ask` (AMA produk read-only — knowledge-first + code-fallback, grounding wajib, flag drift→route ke skill pemilik, tidak pernah nulis). **Lane utang teknis:** `debt` — pintu ke-4 `build` menangkap tech debt out-of-scope ke `control/debt.yaml` (status diturunkan, status-as-byproduct); fondasional → decide-now (anti-yes-man); resurface by locality lewat `plan`/`fix` (`rules/debt-aware.md`) + jaring `render-docs` "Known Issues"; steward `/debt` (list/triage/promote/drop). **Design-fidelity:** `design-system` (bring-up fondasi visual — turunin mockup awal jadi `control/design-system.md` tokens+motion + bangun komponen primitif via atom dispatch Spec A; dua-mode SETUP greenfield / CAPTURE brownfield; N design system per-scope; dipicu `fanout`/`feature` atau standalone). **Autonomy (Langkah 3 — M7):** `build --unattended` auto-approve segmen risk rendah (`feature.yaml` `risk`); HARD floor (`migrate`/`needs_human`/`blocked`/risk tinggi/Security) tetap attended; allowlist harness + rem run-level (circuit breaker + cap volume); lapor-keluar via hook (`template/.claude/` `on-stop.sh`/`on-permission.sh`/`notify.sh`, sumber-kebenaran laporan disk); outer-loop driver dua-engkol (`drive.sh` bash grind kontinu + `/schedule` cloud) buat `build --unattended` berkelanjutan lintas-sesi (sinyal `outcome` di `last-run.md`). **Q&A quality (elicitation + flow):** `rules/elicitation.md` (konvensi Q&A sumber-tunggal — keputusan-bercabang 1-per-giliran, tiap opsi bawa konsekuensi, jangan auto-`recommend` keputusan impactful, surface di gate) dirujuk `intake`/`fanout`/`plan`/`tweak`/`fix`; slot `Flow/Skenario` first-class di `business.md` (happy-path + ≥1 skenario edge/gagal) biar alur fitur tak keskip dari elicitation maupun gate. **Onboarding:** `guide` — pintu masuk read-only buat user baru: tur orientasi **progresif** (apa itu → peta flow → cheatsheet → mulai dari mana → menu dalami) + Q&A soal skill/flow/metodologi (hybrid: cheatsheet baked + baca `SKILL.md` asli on-demand; "skill apa yang ADA" dari listing folder biar tahan drift); **cermin `/ask`** (ask=produk, guide=plugin) dengan saling-rute di batas scope; ditunjuk di README + plugin.json + marketplace sebagai pintu masuk.
