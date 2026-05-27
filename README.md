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
Lalu `architect` (fondasi teknis), `feature` (bikin fitur), `ship`/`drop` (lifecycle), `render-docs` (doc human-readable).

## Validasi ide (opsional, greenfield)
```
/discovery          # business consultant pra-init: riset pasar/kompetitor/monetisasi + verdict go/no-go
```
Buat ide yang masih mentah. Nol teknis. Output: dok strategis HTML (`control/docs/discovery.html`) + seed awal `control/business/`; di akhir otomatis panggil `/init`. Tiap klaim disitasi + dilabeli keyakinan; `critic` menantang sebelum kamu menerima.

## Fondasi teknis
```
/architect          # tetapkan stack (greenfield) / rekam stack+capabilities (brownfield) + konvensi
/extract            # (brownfield, opsional) front-load business/ dari kode existing
```
Urutan brownfield: `/init` -> `/architect` -> `/extract` (opsional) -> `/feature`.
Urutan greenfield (ide jelas): `/init` -> `/architect` -> `/feature`.
Urutan greenfield (ide mentah): `/discovery` -> `/init` -> `/architect` -> `/feature`.

## Bikin fitur
```
/feature <nama>     # konduktor: intake (bisnis) -> fanout (lintas-app) -> plan (teknis)
```
Sub-skill bisa dipanggil sendiri: `/intake`, `/fanout`, `/plan`. Tiap tahap ada gate; agent `critic` me-review di gate penting.

## Selesai & lifecycle
```
/ship <fitur>       # finishing: review + quality + cek alignment ke business -> PR -> tandai shipped
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
Selesai (Fase 1–5): init, pipeline fitur (feature/intake/fanout/plan + critic), architect/extract, lifecycle (ship/drop), render-docs. Boilerplate context-vault lengkap end-to-end. **Tambahan:** `discovery` — business consultant pra-`init` (validasi ide mentah → seed `business/` + HTML strategis).
