# context-vault

[English](README.md) · **Bahasa Indonesia**

![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-8250df) ![Also runs on Kimi Code](https://img.shields.io/badge/also%20runs%20on-Kimi%20Code-0969da)

[Cara kerjanya](#cara-kerjanya) · [Susunan knowledge](#knowledge-yang-tersusun) · [Alur kerja](#alur-kerja) · [Skill](#isinya-apa-aja) · [Mulai cepat](#mulai-cepat)

### Produk lo bukan satu repo. AI lo juga nggak boleh nganggep begitu.

Ada storefront, API, admin panel, mungkin juga app mobile. Claude Code cuma ngeliat repo yang lagi lo buka, jadi tiap fitur mulainya sama: jelasin ulang aturan bisnis, kontrak API, konvensi. Lagi dan lagi.

**context-vault** ngasih Claude Code satu lapisan knowledge yang tersusun dan selalu up to date buat *seluruh* produk lo. Contohnya satu fitur, dari awal sampai akhir:

```text
> /feature checkout-v2
  intake  → business.md ditulis (aturan, flow, edge case)        ✔ di-review critic
            aturan yang awet dipromosikan ke control/business/
  fanout  → kena storefront, api, admin
  plan    → plans/storefront.md · plans/api.md · plans/admin.md

> /breakdown checkout-v2         → tasks.yaml (14 task kecil ber-test case + 1 task acceptance)
> /build checkout-v2 --unattended   # jalan semalaman, gate berisiko nunggu review lo
  acceptance → flow business.md dijalanin ke app hidup        ✔ 6/6 teramati

> /ship checkout-v2
  ✔ code review   ✔ security gate   ✔ sesuai business.md
  → PR: acme/web#212 · acme/api#87 · acme/admin#45   (in review)
  → halaman review buat rekan · doc produk di-render ulang

> /land checkout-v2              # sesi baru, nunggu di background
  → CI api#87 dibenerin · 2 komentar reviewer dibalas (tiap-tiapnya lo setujui)
  → 3 PR merge semua → checkout-v2 shipped
```
<sub>Contoh output.</sub>

## Cara kerjanya

```mermaid
flowchart LR
  HUB[("control/<br/>pusat knowledge")] <-->|baca & jaga tetap up to date| CV["Claude Code<br/>+ context-vault"]
  CV -->|plan, branch, satu PR per repo| W["storefront · Next.js"]
  CV --> A["api · Go"]
  CV --> AD["admin · React"]
  CV --> M["mobile · React Native"]
```

Monorepo atau multi-repo, dua-duanya jalan. Di setup multi-repo, `control/` jadi repo hub sendiri; repo app lo tetap di tempatnya dan nggak pernah dimigrasi.

## Knowledge yang tersusun

```text
control/
├─ workspace.yaml    # peta produk: app, repo, stack, shared package, database
├─ business/         # aturan domain, flow, glosarium, risiko
├─ invariants.md     # aturan platform yang nggak boleh dilanggar
├─ conventions.md    # konvensi lintas-app
├─ integrations.md   # kontrak vendor (pembayaran, email, kurir, …)
├─ design-system.md  # token, motion, komponen primitif
├─ roadmap.md        # backlog terurut
├─ debt.yaml         # catatan utang teknis
├─ sync.yaml         # patokan terakhir control/ nyusul branch utama tiap repo
├─ fixes/            # fix bug pasca-ship, satu folder per fix
└─ features/
   └─ checkout-v2/
      ├─ feature.yaml    # status: draft → active → in_review → shipped
      ├─ business.md     # alasan + aturannya
      ├─ fanout.md       # app mana aja yang kena
      ├─ plans/api.md    # satu plan per app
      ├─ tasks.yaml      # yang dieksekusi /build
      └─ gates.yaml      # gate yang diantriin build unattended
```

Skill-skillnya ngupdate file-file ini sambil kerja, jadi knowledge-nya ikut tumbuh tiap lo bikin fitur, bukan basi di wiki.

## Pengaman bawaan

- **Gate di tiap tahap.** Aturan bisnis, plan, kode, dan PR masing-masing nunggu approval lo dulu sebelum lanjut.
- **Agent red-team, bukan yes-man.** `critic` nyerang proposal di gate penting; `security-critic` me-review diff yang nyentuh pembayaran atau data pribadi.
- **Security gate sesuai tingkat risiko.** `/ship` nge-scan tiap fitur buat secret yang bocor dan PII di log, terus jalanin security review penuh kalau fiturnya ngurus uang atau data pribadi.
- **Knowledge yang nggak melenceng.** `/ask` jawab dari `control/` lengkap sama sumbernya, nandain catatan yang beda sama kode, terus nunjukin skill yang bisa benerin.
- **Dites ke app beneran.** Tiap fitur ditutup task acceptance: AI nyalain app-nya terus jalanin tiap flow `business.md`, dengan observasi nyata per kasus. Kasus yang gagal jadi task fix, dan acceptance diulang tiap kali kodenya berubah sesudahnya.
- **Build semalaman yang bisa dipercaya.** `/build --unattended` terus jalan, sementara langkah berisiko (migrasi destructive, perubahan sensitif keamanan) nunggu di antrian review buat pagi.
- **Ngerti kerja tim.** Kalau rekan merge kode tanpa nyentuh `control/`, cek di awal sesi bakal nyadar, dan skill yang mutusin sesuatu dari knowledge nawarin `/sync` dulu, jadi nggak ada yang dituduh "melanggar aturan" yang ternyata udah dilangkahi kodenya.

## Alur kerja

| Fase | Perintah&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Hasilnya |
|---|---|---|
| **1 · Bentuk produknya** | `/discovery` → `/init` → `/roadmap` | ide yang udah divalidasi, scaffold `control/`, backlog terurut |
| **2 · Pasang fondasi** | `/architect` → `/wire` | stack + invarian platform, skeleton kosong yang udah jalan |
| **3 · Kirim fitur** *(diulang)* | `/feature` → `/breakdown` → `/build` → `/ship` → `/land` | aturan bisnis, plan per app, kode yang lulus test, PR yang merge |

Udah punya kode? `/init` bisa ngadopsi monorepo atau multi-repo yang udah ada, dan `/extract` ngisi knowledge bisnis dari kodenya. Jalur samping, kapan aja: `/tweak` perubahan kecil · `/fix` bug · `/debt` utang teknis · `/drop` batalin fitur · `/ask` nanya. Kerja tim: `/sync` abis pull · `/review-pr` buat PR rekan.

## Isinya apa aja

29 skill (`/intake`, `/fanout`, dan `/plan` biasanya jalan di dalam `/feature`), 2 agent red-team, dan seperangkat rules yang bikin mereka tetap jujur.

**Mulai produk**

| Skill&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Fungsinya |
|---|---|
| `/discovery` | Validasi ide mentah: visi lo dulu, baru riset pasar, kompetitor, monetisasi, dan verdict go/no-go |
| `/init` | Mulai produk baru atau adopsi repo yang udah ada (monorepo atau multi-repo) |
| `/roadmap` | Ngubah konsep jadi backlog fitur terurut, lengkap sama epic dan dependensinya |
| `/architect` | Netapin (atau nyatet) stack per app, konvensi lintas-app, dan invarian platform |
| `/wire` | Nyalain skeleton yang jalan: scaffold app, database, wiring FE↔BE, env |
| `/extract` | Khusus kode yang udah ada: ngisi `control/business/` dari kode |

**Bikin fitur**

| Skill&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Fungsinya |
|---|---|
| `/feature` | Ngejalanin pipeline fitur, ada gate di tiap tahap: `/intake` (bisnis) → `/fanout` (app mana) → `/plan` (plan teknis per app) |
| `/breakdown` | Mecah plan jadi task kecil berurutan lengkap sama test case, ditutup task acceptance wajib: AI ngejalanin flow `business.md` di app yang lagi jalan |
| `/build` | Eksekusi task, satu subagent implementer per task (TDD) plus review; bisa dilanjut lintas sesi, bisa jalan tanpa diawasi |
| `/ship` | Gate review, kualitas, dan keamanan, cek keselarasan sama `business.md`, terus satu PR per repo |
| `/land` | Jagain PR itu dari sesi baru sampai merge: pipeline gagal yang wajar dibenerin sendiri, komentar reviewer dipilah dan dikonfirmasi ke lu sebelum push atau balas, terus tandai fitur shipped |
| `/drop` | Batalin fitur dan nyimpen alasannya sebagai catatan keputusan |

**Numbuhin produk**: `/feature` manggil ini otomatis kalau fanout nemu hal baru.

| Skill&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Fungsinya |
|---|---|
| `/add-app` | Nambah app baru (declare → architect → wire) |
| `/add-package` | Nambah shared package (ui-kit, types, utils) |
| `/add-integration` | Nambah vendor eksternal: kontrak di `integrations.md`, stub webhook kalau inbound |
| `/design-system` | Ngubah mockup jadi token + komponen primitif, atau dokumentasiin UI yang udah ada |

**Ubah & rawat**

| Skill&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Fungsinya |
|---|---|
| `/tweak` | Perubahan kecil yang tetap tercatat (threshold, kebijakan) tanpa pipeline penuh; otomatis naik kelas kalau ternyata gede |
| `/fix` | Bug di perilaku yang udah ada: reproduce → root cause → fix pakai TDD, waktu build atau sesudah ship |
| `/debt` | Catatan utang teknis: `/build` nyatet utang yang ditemuin; lo yang list, triase, promote, atau drop |
| `/upgrade` | Nyusulin produk yang dibikin pakai versi plugin lama ke template terbaru, tanpa nyentuh knowledge |

**Pahami & bagikan**

| Skill&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Fungsinya |
|---|---|
| `/ask` | Tanya apa aja soal produk lo; jawabannya nyebut sumber dari `control/` atau kode, read-only |
| `/guide` | Tur dan tanya-jawab soal plugin ini sendiri |
| `/render-docs` | Doc HTML seluruh produk yang gampang dibaca stakeholder |
| `/share` | Satu halaman review HTML per fitur buat rekan; paste balik feedback mereka buat ditriase |
| `/sync` | Kerja tim: nyusulin `control/` ke kode rekan yang udah merge di branch utama tiap repo; dicatat lengkap ke `control/`, lalu buka satu halaman ringkasan bisnis |
| `/review-pr` | Review PR rekan (plus PR satu tiket di repo lain) dalam empat lapis: konsistensi, best practice, alur lintas-repo, kontrak. Buka laporan HTML berisi vonis + draft komentar tinggal copy; nggak pernah posting ke GitHub |

## Mulai cepat

```text
/plugin marketplace add stevanus1997/context-vault
/plugin install context-vault
```

Terus:

```text
/guide                    # tur singkat: ada apa aja, mulai dari mana
/discovery                # ide masih mentah? validasi dulu (lanjut otomatis ke init)
/context-vault:init       # ide udah jelas atau repo udah ada? mulai dari sini
```

> `/context-vault:init` pakai nama lengkap karena Claude Code punya `/init` sendiri. Skill lainnya cukup pakai nama pendek.

## Perlu tau

<details>
<summary><b>Build semalaman (mode unattended)</b></summary>

`/build <fitur> --unattended` (atau `bash .claude/drive.sh <fitur>` biar terus jalan lintas sesi) nggak pernah berhenti gara-gara gate. Gate yang butuh mata manusia **diantriin** di `control/features/<fitur>/gates.yaml`, sementara task berikutnya tetap dibangun. Paginya, `/build <fitur>` (attended) nguras antrian itu: diff + test + `security-critic` + "kalau direvisi, apa aja yang kena", terus approve atau revisi per gate. Blocker beneran (migrasi destructive, langkah manual, error) cuma nahan subtree-nya sendiri; driver berhenti dengan `outcome: review` kalau udah nggak ada lagi yang bisa dibangun.

**Pantau progres:** di Claude Code, panel **🔨 build** kebuka sendiri waktu ada build jalan (`/cv-panel` buat buka/tutup manual): task ke berapa, lane yang jalan paralel, yang ketahan + alasannya, gate yang antri, dan estimasi sisa waktu (rentang, muncul sesudah 3 task kelar). Ada juga status line satu baris plus toast kalau ada yang nyangkut, dan `drive.sh` nampilin baris progres live di terminal. Read-only, butuh `python3`. Panelnya cuma ada di Claude Code (di Kimi cuma baris `drive.sh`).

`/breakdown` juga bisa nyatet kerja non-file (`actions:` buat migrasi, install, env) dan langkah manusia (`manual:` / `needs_human`). `/build` ngejalanin dan verifikasi semuanya (migrasi lewat gate; yang additive bisa auto-apply kalau lo opt-in) plus jalanin test integrasi lintas-app. `/build` dan `/ship` ngerti multi-repo: satu branch dan satu PR per repo.
</details>

<details>
<summary><b>Ngawal PR sampai merge (/land)</b></summary>

`/ship` berhenti di `in_review`; `/land <fitur>` lanjutin dari situ, idealnya di sesi baru. Dia nyalain watcher di background (nggak makan token selama nunggu) dan bangun kalau ada kejadian di PR-nya. Pipeline gagal yang fix-nya wajar dibenerin, dites, dan di-push sendiri, di worktree terpisah. Komentar reviewer dipilah dan dikonfirmasi ke lo dulu sebelum ada yang di-push atau dibalas di GitHub. Konflik merge ditawarin **Beresin** / **Biar gw aja**, nggak pernah di-rebase atau force-push. Begitu semua PR merge, fiturnya ditandai `shipped` dan doc di-render ulang.

- `/land <fitur> sekali` ngecek sekali terus selesai, tanpa watcher.
- `/land <link PR> …` jagain PR tanpa fitur (cuma jaga dan konfirmasi, nggak pernah push sendiri).
- Laptop ketutup? Jalanin `/land <fitur>` lagi; keadaannya disusul dari GitHub.
- Butuh `gh` yang udah login dan `python3`. Produk yang dibikin sebelum 0.30 perlu `/upgrade` dulu.
</details>

<details>
<summary><b>Kerja bareng tim</b></summary>

Rekan merge kode tanpa ngupdate `control/`, jadi catatannya pelan-pelan basi. `/sync` nyusulin: bandingin branch utama tiap repo sama patokan terakhir di `control/sync.yaml`, baca commit yang bukan dari bot aja, terus nyatet yang berubah (fitur baru, aturan bisnis, aturan coding) ke file knowledge yang pas, lalu buka ringkasan bisnis satu halaman. Catatan milik fitur yang belum merge nggak disentuh.

Nggak perlu inget buat jalanin: hook di awal sesi nyadar kalau `control/` ketinggalan (cuma git lokal, tanpa fetch), dan `/feature`, `/plan`, `/fix`, `/tweak`, `/review-pr` nawarin sinkron dulu sebelum mutusin apa pun. Kalau di-skip, temuan yang bersandar ke catatan basi dikasih label begitu.

`/review-pr` me-review PR rekan terhadap `control/` dan branch utama, ngegabungin PR satu tiket di repo lain jadi satu review, dan ngasih draft komentar tinggal copy. Nggak pernah posting ke GitHub.
</details>

<details>
<summary><b>Notif di HP (mode attended)</b></summary>

Nyetir sesi dari HP lewat Remote Control? Nyalain sekali di terminal: `/config` → **Push when actions required** (app Claude login di akun yang sama + izin notif OS). HP bunyi tiap ada skill yang nunggu lo: gate approve/revisi, pertanyaan keputusan, konfirmasi, permission prompt. Itu bisa karena titik tunggu attended ditanyain lewat kotak `AskUserQuestion` (`rules/ask-user.md`; `discovery`/`init` dikecualikan, tetap teks biasa). Push di-skip selama lo lagi fokus di terminal. Mode unattended tetap ngabarin lewat `notify.sh`.
</details>

<details>
<summary><b>Judul session otomatis</b></summary>

Session dikasih judul otomatis dari skill kerja yang lo panggil: `/build checkout-v2` → `build: checkout-v2` di `/resume`. Skill kerja terakhir yang menang; skill read-only (`/ask`, `/guide`, `/render-docs`, `/debt`) nggak ngubah judul. Butuh Claude Code v2.1.196+ (versi lama: no-op yang aman). Nama dari `/rename` manual bertahan sampai skill kerja berikutnya dipanggil, ini batasan hook Claude Code saat ini. Mekanisme `sessionTitle` lewat `UserPromptSubmit` udah diverifikasi empiris di v2.1.216; docs resmi baru nyebut itu buat `SessionStart`, jadi kalau CLI ke depannya berubah, hook-nya jadi no-op yang aman.
</details>

<details>
<summary><b>Kimi Code</b></summary>

Plugin ini juga jalan di [Kimi Code CLI](https://www.kimi.com/code/docs/en/) lewat tree hasil generate `plugin-kimi/`.

- **Install:** buka `kimi` → `/plugins` → tab **Custom** → install dari `<repo-ini>/plugin-kimi` → `/reload`.
- **Panggil:** `/skill:<nama>` (mis. `/skill:guide`, `/skill:build checkout-v2`).
- **Belum ada di Kimi:** judul session otomatis dan `build --unattended`. `kimi -p` auto-approve semua tool, jadi `build` versi Kimi nolak `--unattended`.
- **Hybrid:** state produk tinggal di disk (`control/`, `tasks.yaml`, git), jadi kerja interaktif bisa di tool mana aja; jalur unattended tetap lewat Claude Code: `bash .claude/drive.sh <fitur>`.

Maintainer: `plugin/` itu sumber kebenarannya. Cara regen `plugin-kimi/` ada di [docs/maintaining.md](docs/maintaining.md).
</details>

## Docs

- [Spec desain](docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md): rancangan awal sistemnya
- [docs/maintaining.md](docs/maintaining.md): ritual rilis dan riwayat milestone
- Semua spec dan plan: [docs/superpowers/](docs/superpowers/)
