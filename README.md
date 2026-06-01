# context-vault

AI-first product boilerplate — lapisan AI + knowledge (bukan kode) untuk mengelola produk multi-app dengan Claude Code.

## Install
```
/plugin marketplace add <path-atau-url-repo-ini>
/plugin install context-vault
```

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

> Kalau sebuah fitur butuh **app baru** (belum ada di `workspace.yaml`), `fanout` nandain dan `feature` otomatis panggil `add-app` (declare entri → `architect` → `wire`) sebelum `plan`. `add-app <nama>` juga bisa dipanggil standalone buat numbuhin produk pasca-`init`. Hal serupa untuk **shared package baru** (`add-package`, mode-package) dan **vendor eksternal** (`add-integration` — tulis kontrak SHAPE ke `control/integrations.md`, scaffold stub webhook bila inbound).

## Selesai & lifecycle
```
/ship <fitur>       # finishing: review + quality + security gate (sensitivity-scaled) + cek alignment ke business -> PR -> tandai shipped
/drop <fitur>       # batalkan fitur (tandai dropped + alasan, simpan sebagai memori keputusan)
```

## Dokumentasi
```
/render-docs        # generate doc HTML human-readable dari knowledge -> control/docs/site/index.html
```
Otomatis dipanggil `ship`; bisa juga manual untuk preview.

## Desain
Lihat `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`.

## Status
Selesai (Fase 1–5): init, pipeline fitur (feature/intake/fanout/plan + critic), architect/extract, lifecycle (ship/drop), render-docs. Boilerplate context-vault lengkap end-to-end. **Tambahan (live di main):** `discovery` (business consultant pra-`init`), `wire` (bring-up skeleton kosong-tapi-jalan), `add-app` (nambah app baru pasca-init), `breakdown`+`build` (fase eksekusi plan→kode). **Hardening (Langkah 1 — audit ecommerce-builder):** invarian platform dikunci `architect` sebelum `wire` (di `control/invariants.md`) + **Security & Compliance Gate** di `ship` (berskala `sensitivity`, agent `security-critic`). **Langkah 2:** shared package end-to-end + fan-IN (`add-package`, `packages[]` — H2) + vendor eksternal durable (`add-integration`, `control/integrations.md`, webhook inbound + baseline `security-critic` — M5).
