---
name: upgrade
description: Use untuk menyusulin produk LAMA (di-init pakai versi plugin sebelumnya) ke template terbaru — sinkron file scaffolding kubu-plugin (.claude/ hooks+drive.sh+settings, control/ skeleton yang HILANG) tanpa menyentuh knowledge. Idempoten, presence-based, GATE tiap tulis. BUKAN untuk produk baru (init terbaru sudah lengkap). Trigger — "upgrade", "sync template", "produk ketinggalan versi plugin", "aktifin unattended di produk lama". Jalankan dari root produk yang punya control/.
---

# upgrade — Susulin produk ke template terbaru (migrasi versi)

Tujuan: produk yang di-`init` pakai plugin versi LAMA ketinggalan file scaffolding yang ditambah versi baru (mis. `.claude/hooks/`, `drive.sh`, blok `hooks` di `settings.json`, file `control/` baru seperti `invariants.md`/`risks.md`). `upgrade` menyusulinnya — **hanya file kubu-plugin**, **tanpa pernah menyentuh knowledge/customisasi produk**. Produk BARU tak perlu ini (`init` terbaru sudah menyalin semua).

> `init` = bikin produk (sekali). `upgrade` = susulin produk yang SUDAH ada ke template terkini (kapan saja, idempoten). BUKAN re-init / re-wire.

## Prinsip (jangan dilanggar)
- **Idempoten + presence-based.** Cek KEBERADAAN tiap elemen template terkini; yang ADA & current → skip; yang HILANG/ketinggalan → susulin. Jalan berkali-kali aman (produk current = no-op). Tak butuh stempel versi (cek file nyata, bukan nebak nomor).
- **Pisahkan dua kubu — haram salah sentuh:**
  - **Kubu PLUGIN (boleh disusulin):** `.claude/hooks/*.sh`, `.claude/drive.sh`, bagian template `settings.json` (baseline `allow`/`deny` + blok `hooks` + perintah verifikasi per-stack), template `control/` skeleton.
  - **Kubu PRODUK (HARAM disentuh):** semua `control/*` yang SUDAH ADA (knowledge: `workspace.yaml`/`business/`/isi `invariants.md`/`tasks.yaml`/`feature.yaml`/…), `.claude/CLAUDE.md`, `.claude/notify.sh` (secret user), `.env`, kode.
- **Tiap tulis = GATE.** Tampilkan apa yang mau disusulin/di-merge → approve dulu.
- **Merge, bukan timpa, untuk file campuran.** `settings.json` & `.gitignore` di-MERGE (pertahankan entri custom user, tambah yang kurang, dedup). File generik murni (hooks/drive.sh) boleh diganti versi terkini (GATE + tampilkan diff bila beda).
- **`control/`: tambah-yang-HILANG saja.** File template `control/` yang absen di produk → tambahkan (ganti placeholder `<PRODUCT>`). File yang SUDAH ADA → JANGAN sentuh (itu knowledge milik skill lain).

## Prasyarat
- Jalankan dari root produk yang punya `control/`.
- **Tanpa `control/`** → bukan produk context-vault (atau belum init) → arahkan `/init`, STOP. (`upgrade` menyusulin produk yang SUDAH ada, bukan bikin baru.)

## Alur

### 1. Deteksi selisih (read-only dulu)
Bandingkan produk vs `${KIMI_SKILL_DIR}/../../template/`:
- `.claude/hooks/on-stop.sh`, `on-permission.sh` — ada? executable?
- `.claude/drive.sh` — ada? executable?
- `.claude/settings.json` — punya `permissions.allow` baseline (git read-only + `add`/`commit`)? `permissions.deny` foot-gun (force-push/reset --hard/clean/rm -rf)? blok `hooks` (`Stop` + `PermissionRequest`)? perintah verifikasi per-stack (test/lint/typecheck/build sesuai `workspace.yaml` `stack`)? **aturan multi-repo `git -C <path>` ter-enumerasi per unit path (BUKAN bentuk-mati `git -C *`)?** **workspace di-`trust`** (`hasTrustDialogAccepted: true` di `~/.claude.json` — tanpa ini `permissions.allow` produk DIABAIKAN saat headless)? **`includeCoAuthoredBy: false` + `attribution` (`commit`/`pr` kosong)** — matiin trailer co-author Claude di commit & body PR produk? **Opt-in apply-migrate additive** (`Bash(<perintah-apply-migrasi>:*)` + deny rollback cermin — HANYA bila user opt-in; absen = default konservatif, BUKAN cacat)?
- `.gitignore` — punya `.claude/notify.sh` + `.claude/.unattended*` + `.claude/build/` (scratch brief/report/paket-diff file-handoff `build`)?
- `control/` — file/dir template mana yang ABSEN di produk (mis. `invariants.md`, `integrations.md`, `design-system.md`, `business/risks.md`, `debt.yaml`, `fixes/`)? (CATATAN: `control/schema/` di-generate runtime oleh `wire`/`build` dari skema nyata — BUKAN skeleton template; jangan disync di sini.)
Susun **daftar selisih** + tampilkan ke user (apa yang akan disusulin, apa yang di-skip karena sudah-ada/itu-knowledge). Tak ada selisih → "produk sudah current" + STOP.

### 2. Sinkron `.claude/` (GATE)
- **hooks/ + drive.sh** hilang → copy dari template + `chmod +x`. Ada tapi beda → tampilkan diff, GATE ganti (file generik plugin).
- **`settings.json`** → MERGE: union baseline `allow` + `deny` + blok `hooks` ke yang ada (dedup, pertahankan entri custom user — JANGAN buang); lalu derive + tambah **perintah verifikasi per-stack** dari `workspace.yaml` `stack` (logika `wire` step 5.5: HANYA baca/verifikasi — test/lint/typecheck/build; JANGAN push/deploy/`rm`/jaringan-tulis; apply-migrate HANYA lewat opt-in). **Opt-in apply-migrate additive (amandemen 2026-08-27):** untuk unit ber-DB tawarkan pertanyaan terpisah persis `wire` 5.5 (*"Izinkan `build --unattended` apply migrasi `kind: additive` otomatis?"*, default skip) → bila ya, derive perintah apply dari `stack.orm` + deny rollback cermin; GATE. Tampilkan hasil merge → approve. File absen → copy utuh dari template lalu lanjut derive per-stack. **Atribusi commit:** pastikan top-level `includeCoAuthoredBy: false` + `attribution` (`commit`/`pr` kosong) ada — matiin trailer co-author Claude di commit & body PR produk; tambah kalau hilang, JANGAN timpa kalau user sudah set custom. **Migrasi bentuk-mati `git -C *` (kritis — produk lama PASTI kena):** bila produk punya entri legacy `Bash(git -C * …)` di `allow`/`deny`, itu **tak pernah match** (wildcard di-tengah mati — cuma `:*` di akhir yang wildcard) → **buang**, lalu **enumerasi ulang per unit path** `P` ∈ (`workspace.yaml` `apps[].path` ∪ `packages[].path`): `allow` 9 cermin polos `Bash(git -C <P> status|diff|log|show|rev-parse|branch|add|commit|checkout :*)` + `deny` foot-gun `Bash(git -C <P> push --force|push -f|reset --hard|clean|checkout -- :*)` (logika `wire` 5.5). Tanpa migrasi ini, `build`/`drive.sh` ber-`git -C <path>` tetap beku walau "ke-upgrade". Dedup; GATE.
- **`.gitignore`** → append baris yang kurang (`grep -qxF` dulu; idempoten).

### 3. Sinkron `control/` skeleton (GATE — tambah-yang-hilang)
Untuk tiap file/dir template `control/` yang **ABSEN** di produk: tambahkan (copy + ganti `<PRODUCT>` dengan nama produk dari `workspace.yaml`, seperti `init` step 4). File yang **SUDAH ADA**: SKIP — jangan baca/tulis (itu knowledge milik skill pemiliknya). Ini cuma skeleton kosong; ISI-nya tumbuh lewat skill pemilik (`architect`/`feature`/`add-integration`/…), BUKAN `upgrade`.

### 4. Ringkas (GATE penutup)
Laporkan: disusulin apa, di-merge apa, di-skip apa (+ alasan). Saran langkah lanjut:
- **Notif unattended belum diset → TAWARKAN setup sekarang** (di sini ada manusia): *"Setup notif buat `build --unattended`? (skip boleh)"* → bila ya, Q&A kanal (wording kanonik `build/reference.md` §G: ntfy/macOS/Telegram/no-op) → tulis `.claude/notify.sh` + `chmod +x` (sudah gitignored). GATE: tampilkan isi → approve. (Tetap nol-sentuh knowledge: `notify.sh` = file plugin/`.claude`, bukan `control/`.)
- **Cek allowlist verifikasi stack** sudah keisi (step 2 sudah derive per-stack dari `workspace.yaml`) — kalau belum lengkap, ingatkan `wire` step 5.5. Tanpa ini `drive.sh` precheck akan menahan.
- **Fitur lama ber-`risk:high`** — sejak amandemen 2026-08-27 `risk:high` BUKAN kill-switch: unattended tetap jalan, semua gate segmennya masuk antrian review pagi (`gates.yaml`); **nol pemulihan wajib**. Opsional: edit `feature.yaml` `risk: high → normal` bila ingin sebagian segmen auto-approve (fitur pii-only / payments read-only), atau re-run `intake` bila tag `sensitivity`-nya sendiri keliru. `upgrade` TIDAK menyentuh `feature.yaml` (knowledge).
- **Opt-in apply-migrate additive belum diset** (produk ber-DB, `permissions.allow` tanpa perintah apply migrasi) → ingatkan: tanpa opt-in, migrasi `kind: additive` saat unattended di-hold `needs_human` tiap pagi (`build` step 3); tawarkan via merge `settings.json` step 2.
- File `control/` baru lahir kosong (mis. `invariants.md`) → arahkan skill pemiliknya (`/architect` dll) untuk mengisinya.
- **`control/schema/` absen/stub pada app ber-DB (produk lama belum punya proyeksi)** → `upgrade` **TIDAK nge-seed** (charter nol-sentuh-knowledge; proyeksi = runtime-generated, lihat step 1). Cukup **ARAHKAN** user jalankan `wire` (brownfield-repair nge-seed proyeksi dari sumber existing, presence-based) — pola arahkan-skill-pemilik yang sama dgn baris di atas.

## Guardrails
- **Nol sentuh knowledge.** Tak pernah Edit/timpa file `control/` yang sudah ada, `CLAUDE.md`, `notify.sh`, `.env`, kode. Cuma TAMBAH file plugin yang hilang + MERGE settings/gitignore.
- **Bukan re-init/re-wire.** Tak men-scaffold app, tak nyalain DB, tak nyentuh stack/arsitektur. Cuma nyamain file scaffolding template.
- **Anti-ngarang versi.** Presence-based (cek file nyata), bukan nebak dari nomor versi — jalan walau produk tak punya stempel versi.
- **Aman diulang.** Jalan ke produk yang sudah current = no-op (semua elemen sudah ada).

## Catatan
- Produk BARU (di-`init` versi terkini) sudah lengkap → `upgrade` no-op. Skill ini KHUSUS migrasi produk yang di-init versi lama.
- Jalur maintenance resmi: tiap kali plugin nambah file template ke depan, `upgrade` cara nyusulin produk existing (punya sendiri & user lain) tanpa re-init.
