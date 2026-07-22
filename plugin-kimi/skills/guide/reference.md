# guide — Referensi baked (peta + cheatsheet + katalog)

Lapisan terkurasi untuk jawaban instan. Untuk **detail** satu skill, `guide` baca `SKILL.md` asli skill itu (jangan duplikasi isi panjang ke sini).

## Peta flow

**Greenfield (ide masih mentah):**
```
discovery → init → roadmap? → architect → wire → feature → breakdown → build → ship
```
**Greenfield (ide sudah jelas):**
```
init → roadmap? → architect → wire → feature → breakdown → build → ship
```
**Brownfield (repo existing):**
```
init → architect → extract(opsional) → wire → feature → breakdown → build → ship
```
`feature` = konduktor yang menjalankan `intake → fanout → plan`. `roadmap?` = opsional — susun/re-plan backlog fitur terurut (`control/roadmap.md`); brownfield pun boleh panggil standalone kapan saja. Lane samping bisa kapan saja: `fix` (bug), `tweak` (perubahan kecil), `debt` (utang teknis), `ask` (tanya produk), `drop` (batalin fitur).

## Cheatsheet — kapan pakai apa

| Mau… | Pakai |
|---|---|
| Validasi ide yang masih mentah | `/discovery` |
| Mulai produk (ide jelas / adopsi repo existing) | `/init` |
| Tetapkan stack & fondasi teknis | `/architect` |
| Nyalain skeleton project (kosong-tapi-jalan) | `/wire` |
| Susun / re-plan backlog fitur (mulai dari mana) | `/roadmap` |
| Bikin kapabilitas/fitur baru | `/feature` |
| Pecah plan → task kecil | `/breakdown` |
| Eksekusi task → kode | `/build` |
| Selesaikan + PR fitur | `/ship` |
| Perbaiki bug (perilaku lama yang salah) | `/fix` |
| Perubahan kecil (bukan bug, bukan fondasi) | `/tweak` |
| Lihat/triase utang teknis | `/debt` |
| Tanya soal **produk lu** (status/fitur/auth) | `/ask` |
| Tanya soal **plugin ini** (skill/flow/cara kerja) | `/guide` |
| Batalin fitur | `/drop` |
| Nambah app / shared package / vendor eksternal | `/add-app` · `/add-package` · `/add-integration` |
| Bring-up fondasi visual (tokens+komponen) | `/design-system` |
| Front-load knowledge dari kode (brownfield) | `/extract` |
| Doc HTML buat stakeholder | `/render-docs` |
| Susulin produk lama ke template terbaru | `/upgrade` |

### `/feature` vs `/fix` vs `/tweak`

| Skill | Kapan |
|---|---|
| `/tweak` | perubahan KECIL, bukan bug, nggak fondasional — raih duluan |
| `/fix` | perilaku lama yang *salah* (defect) |
| `/feature` | kapabilitas baru / gede / lintas-app / fondasional |

### `/ask` vs `/guide`

| | `/ask` | `/guide` |
|---|---|---|
| Scope | **Produk** lu (baca `control/` + kode) | **Plugin** context-vault (skill/flow/metodologi) |
| Contoh | "fitur gw apa aja", "auth produk apa" | "/fanout itu apa", "abis /init ngapain" |

## Katalog skill

### Pipeline utama (lifecycle produk)
- `/discovery` — validasi ide mentah pra-init: Q&A visi operator dulu, baru riset pasar/kompetitor/monetisasi + verdict go/no-go (compliance conditional opt-in), lalu auto lanjut `/init` + tawaran `/roadmap`.
- `/init` — mulai produk baru (greenfield) atau adopsi repo existing (monorepo / multi-repo alias polyrepo) ke context-vault.
- `/roadmap` — (opsional) jembatan konsep→backlog: Q&A flow produk + fitur inti (MVP vs nanti) + urutan → `control/roadmap.md` (fitur · epic · depends_on · target; status turunan `feature.yaml`); re-runnable buat re-plan.
- `/architect` — tetapkan (greenfield) / rekam (brownfield) fondasi teknis: stack per app + capabilities + konvensi + kunci invarian platform.
- `/wire` — bring-up skeleton kosong-tapi-jalan: scaffold app + DB + wiring FE↔BE + env (gated).
- `/feature` — konduktor fitur end-to-end: `intake → fanout → plan` dengan gate tiap tahap.
- `/intake` — fase bisnis fitur: Q&A level bisnis → `business.md` (+ slot Flow/Skenario).
- `/fanout` — petakan fitur ke app yang kena lintas-repo → `fanout.md` + update capabilities.
- `/plan` — fase teknis per-app: baca kode tiap app + Q&A teknis → plan implementasi.
- `/breakdown` — pecah plan flat → `tasks.yaml` (task kecil berurutan, tanpa kode).
- `/build` — eksekusi `tasks.yaml` → kode lulus-test: implementer subagent per task (TDD) + review + gate; resumable; ada mode `--unattended`.
- `/ship` — finishing gate: review + quality + security (sensitivity-scaled) + cek alignment ke business → PR → tandai shipped.

### Lane samping
- `/fix` — lane bugfix: auto-deteksi in-flight (fitur active) / post-ship (`control/fixes/<id>/`); reproduce → root-cause → TDD fix → verify.
- `/tweak` — perubahan kecil berjejak: capture keputusan/kebijakan kecil ke `control/` tanpa pipeline berat; tripwire auto naik-kelas.
- `/debt` — lane utang teknis: registry `control/debt.yaml`; list/triage/promote/drop.
- `/ask` — AMA produk read-only: knowledge-first + code-fallback, sebut sumber, flag drift → route.
- `/drop` — batalkan fitur: tandai dropped + alasan, simpan jadi memori keputusan.

### Scaffolding / numbuhin produk
- `/add-app` — nambah app baru pasca-init (declare → `architect` → `wire`).
- `/add-package` — nambah shared package (fan-IN).
- `/add-integration` — nambah vendor eksternal: tulis kontrak SHAPE ke `control/integrations.md`, scaffold stub webhook bila inbound.
- `/design-system` — bring-up fondasi visual: tokens+motion+komponen primitif dari mockup → `control/design-system.md` (dua-mode SETUP/CAPTURE).

### Docs & maintenance
- `/extract` — (brownfield, opsional) front-load `control/business/` dari kode existing.
- `/render-docs` — generate doc HTML human-readable dari knowledge → `control/docs/site/index.html`.
- `/upgrade` — susulin produk lama (di-init versi plugin sebelumnya) ke template terbaru tanpa menyentuh knowledge.
- `/guide` — (skill ini) panduan & Q&A plugin: tur orientasi progresif + tanya skill/flow/metodologi.
