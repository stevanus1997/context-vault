---
name: roadmap
description: Use untuk menyusun / me-re-plan BACKLOG produk — jembatan konsep→fitur. Q&A gali flow produk + fitur inti (MVP vs nanti) + urutan dependency → tulis control/roadmap.md (penulis tunggal; status fitur TIDAK disimpan — turunan features/*/feature.yaml). Level bisnis murni, NOL teknis. Dipanggil dari ujung discovery (chain), standalone pasca-init, atau re-run kapan pun buat re-plan. Trigger — "roadmap", "susun backlog", "fitur apa dulu", "mulai dari mana", "re-plan backlog". Jalankan dari root produk yang punya control/.
---

# roadmap — Jembatan Konsep → Backlog

Tujuan: mengubah konsep produk jadi backlog fitur terurut yang bisa langsung dikonsumsi `feature` — flow produk + daftar fitur (tujuan · epic · depends_on · target), semua level BISNIS. Penulis tunggal `control/roadmap.md`. Re-runnable kapan pun untuk re-plan.

> Q&A ikuti `${CLAUDE_PLUGIN_ROOT}/rules/elicitation.md` (keputusan-bercabang satu per giliran, opsi bawa konsekuensi). Status fitur TIDAK pernah ditulis ke `roadmap.md` — selalu diturunkan dari `control/features/*/feature.yaml` saat dibaca (nol dual-write).

## Langkah

### 1. Baca konteks
`control/workspace.yaml` (apps + capabilities) + `control/business/*.md` (domain/flows/glossary) + `control/docs/discovery.html` (bila ada — konsep & verdict) + `control/features/*/feature.yaml` (status nyata tiap fitur) + `control/feedback/` (bila ada — sinyal lapangan, input SOFT advisory, cermin intake M8) + `control/roadmap.md` existing (bila re-run). Degrade: sumber absen dilewati diam-diam — produk pasca-init minimal punya `workspace.yaml`.

### 2. Q&A visi & backlog
Ikuti `elicitation.md`. Urutan gali:
1. **Flow pengguna inti** — happy-path dari pengguna datang sampai dapat nilai. Usulkan draft dari `flows.md`/discovery bila ada; operator koreksi.
2. **Kandidat fitur** — usulkan daftar DARI flow itu (tiap langkah flow → kandidat); operator koreksi/tambah/coret. JANGAN mengarang fitur yang tak berakar di flow/visi.
3. **MVP vs nanti** — mana yang WAJIB rilis pertama; sisanya dapat label target bebas (`v1.1`/`nanti`).
4. **Urutan & dependency** — fitur mana butuh fitur mana shipped dulu (1-hop, bahan `depends_on`); kelompokkan yang setema jadi `epic`.

**Re-run (re-plan):** diff-oriented — tampilkan dulu "sejak roadmap terakhir — X shipped, Y dropped, sinyal feedback Z" lalu tanya apa yang berubah (prioritas geser? fitur baru? coret?). BUKAN interogasi ulang dari nol.

### 3. Draft + gate (GATE)
Susun draft `roadmap.md` (format langkah 4) → tampilkan UTUH → minta approve/koreksi. JANGAN tulis sebelum sepakat. Run pertama produk / perombakan besar → invoke subagent `critic` atas draft (fitur bolong? urutan janggal? dependency mustahil? scope MVP melar?) dan tanggapi tiap keberatan bersama operator sebelum lanjut.

### 4. Tulis + promote
Tulis `control/roadmap.md`:
```markdown
# <PRODUCT> — Roadmap
> Ditulis skill roadmap. Status fitur TIDAK disimpan di sini — turunan control/features/*/feature.yaml.

## Flow produk
<jalur pengguna inti, berurutan: daftar → … → dapat nilai>

## Backlog terurut
| # | Fitur | Tujuan | Epic | depends_on | Target |
|---|-------|--------|------|------------|--------|

## Catatan prioritas
<alasan urutan/penundaan — opsional>
```
Nama fitur = calon nama folder `features/<fitur>/` (kebab-case). Lalu **promosikan fakta durable** secara idempotent (cermin intake step 7): flow produk → `business/flows.md`; pengguna/nilai yang tergali → `business/domain.md` (perkaya slot Produk/Pengguna/Nilai). Cek dulu apakah fakta serupa sudah ada — update, jangan duplikat.

### 5. Handoff
Sarankan fitur pertama yang belum shipped — "`/feature <fitur#1>`?". Bila dipanggil dari chain discovery (produk belum di-bring-up) → ingatkan `architect` → `wire` dulu sebelum build fitur.

## Catatan
- BUKAN dependency-engine — tak ada topo-sort/cycle-detection; `depends_on` tetap warn 1-hop di `feature` (M1). `epic` tetap string label, bukan entitas.
- `roadmap.md` BUKAN file template — lahir di sini; pembaca (`feature`) degrade diam-diam bila absen.
- Baris roadmap basi (fitur di-drop / prioritas geser) dibereskan re-run skill ini — `ship`/`drop` TIDAK menulis `roadmap.md`.
- NOL teknis — stack/arsitektur jatah `architect`; detail per-fitur jatah `intake`.
