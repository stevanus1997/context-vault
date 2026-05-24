# context-vault

AI-first product boilerplate — lapisan AI + knowledge (bukan kode) untuk mengelola produk multi-app dengan Claude Code.

## Install
```
/plugin marketplace add <path-atau-url-repo-ini>
/plugin install context-vault
```

## Mulai produk
```
# di folder produk (baru atau existing)
/init
```
Lalu `architect` (fondasi teknis), `feature` (bikin fitur), `ship`/`drop` (lifecycle), `render-docs` (doc human-readable).

## Fondasi teknis
```
/architect          # tetapkan stack (greenfield) / rekam stack+capabilities (brownfield) + konvensi
/extract            # (brownfield, opsional) front-load business/ dari kode existing
```
Urutan brownfield: `/init` -> `/architect` -> `/extract` (opsional) -> `/feature`.
Urutan greenfield: `/init` -> `/architect` -> `/feature`.

## Bikin fitur
```
/feature <nama>     # konduktor: intake (bisnis) -> fanout (lintas-app) -> plan (teknis)
```
Sub-skill bisa dipanggil sendiri: `/intake`, `/fanout`, `/plan`. Tiap tahap ada gate; agent `critic` me-review di gate penting.

## Desain
Lihat `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`.

## Status
Fase 1 (foundation + init). Roadmap di `docs/superpowers/plans/`.
