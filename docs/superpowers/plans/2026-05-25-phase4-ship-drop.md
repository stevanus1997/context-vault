# Fase 4: Lifecycle (ship + drop) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) atau superpowers:executing-plans untuk eksekusi task-by-task. Gunakan **superpowers:writing-skills** saat menulis `SKILL.md`. Verifikasi bersifat **skenario** (jalankan skill pada produk temp ber-`control/`, cek artifact), bukan unit test.
>
> **PRASYARAT:** Fase 1–3 sudah merged + pushed. `feature.yaml` saat ini berformat `{name, status, created}` dengan status `draft`→`active` (di-set skill `feature`). Fase ini menambah transisi `shipped` (oleh `ship`) & `dropped` (oleh `drop`). Skill mengikuti pola yang ada (frontmatter `name`+`description`, body Bahasa Indonesia, operasi pada `control/`, Challenge Checklist + invoke subagent `critic`, GATE).

**Goal:** Membuat skill `ship` (finishing gate: code review + quality + cek keselarasan kode↔`business.md`, lalu PR + tandai `shipped`) dan `drop` (batalkan fitur: tandai `dropped` + alasan + review promosi knowledge, simpan folder).

**Architecture:** Dua skill di `plugin/skills/`. Keduanya beroperasi pada `control/features/<fitur>/` produk + memanipulasi `feature.yaml` (transisi status). `ship` membaca artifact fitur + diff kode app yang kena (dari `fanout.md` + `path` di `workspace.yaml`), memakai `critic` untuk cek alignment, lalu membuat PR & set `shipped`; gagal-keras bila ada yang merah (tidak rubber-stamp). `drop` menandai `dropped` + alasan, memakai `critic` untuk memilah knowledge yang perlu di-revert, dan menyimpan folder sebagai memori keputusan. `ship` memicu `render-docs` (Fase 5) bila tersedia.

**Tech Stack:** Claude Code Plugin (SKILL.md markdown), YAML (feature.yaml), git/gh (PR). Tidak ada runtime code.

**Konvensi commit:** tiap commit diakhiri trailer `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`. Tidak diulang di tiap blok.

---

## File Structure

Semua path relatif ke root repo `context-vault`:

- `plugin/skills/ship/SKILL.md` — finishing gate + kirim + set `shipped`.
- `plugin/skills/drop/SKILL.md` — batalkan fitur + set `dropped` + review knowledge.
- `README.md` — Modify: bump baris `## Status` (stale "Fase 1") + tambah `ship`/`drop`.

Tanggung jawab terpisah: `ship` = verifikasi-akhir + kirim; `drop` = pembatalan + memori. Keduanya menyentuh `feature.yaml` produk; tidak mengubah skill lain.

**`feature.yaml` setelah fase ini (ekstensi minimal, konsisten):**
```yaml
name: <fitur>
status: draft | active | shipped | dropped
created: <YYYY-MM-DD>
# ship menambah:  shipped_at: <YYYY-MM-DD>
# drop menambah:  reason: "<...>"   dan   dropped_at: <YYYY-MM-DD>
```

---

## Task 1: Skill `ship`

**Files:**
- Create: `plugin/skills/ship/SKILL.md`

- [ ] **Step 1: Tulis `plugin/skills/ship/SKILL.md`**

````markdown
---
name: ship
description: Use saat development sebuah fitur SELESAI — finishing gate (code review + quality + cek keselarasan kode vs business.md), lalu bikin PR & tandai fitur shipped. Trigger — "ship <fitur>", "kelarin fitur <fitur>", "finishing <fitur>". Jalankan dari root produk yang punya control/.
---

# ship — Finishing & Kirim

Tujuan: pastikan fitur yang sudah diimplementasi BENAR & selaras bisnis, lalu kirim (PR) + tandai `shipped`. Status `shipped` jadi byproduct, bukan flag manual.

## Langkah

### 1. Baca fitur
Baca `control/features/<fitur>/feature.yaml` (harus `status: active`), `business.md`, `fanout.md`, `plans/*`. Tentukan app yang kena dari `fanout.md` + `path`/`stack` dari `control/workspace.yaml`.

### 2. Per app yang kena
- **Code review:** review diff app (mis. `git -C <path> diff <base-branch>...HEAD`). Cari bug & inkonsistensi konvensi (`control/conventions.md`).
- **Quality gate:** jalankan test/lint/typecheck/build app (perintah sesuai `stack`).
- **Business alignment:** bandingkan kode yang jadi vs `business.md` + `plans/<app>.md` — invoke subagent `critic` dengan fokus: scope creep? requirement kelewat? menyimpang dari maksud bisnis?

### 3. Challenge Checklist (WAJIB sebelum ship)
- Semua test hijau? alignment ke `business.md` OK?
- Ada scope creep / requirement kelewat?
- Ada risiko yang belum ke-cover?

### 4. Putuskan
- **Semua hijau →** lanjut Step 5.
- **Ada merah →** laporkan kegagalan/misalignment ke user, **STOP — jangan ship.** Jangan rubber-stamp.

### 5. Kirim & tandai (GATE)
- Susun deskripsi PR dari `business.md` + `fanout.md` + `plans` + ringkasan diff (terhubung ke ALASAN bisnis, bukan cuma "what").
- Bikin PR: **multi-repo → satu PR per app yang kena**; **monorepo → satu PR**. Pakai `gh pr create`; bila `gh`/remote tak ada, tampilkan deskripsi PR untuk dibuat user sendiri.
- Set `feature.yaml` → `status: shipped` + tambah `shipped_at: <YYYY-MM-DD>`.
- Regenerate doc: invoke skill `render-docs` bila tersedia; bila belum ada (Fase 5), ingatkan user untuk regenerate nanti.

## Catatan
- `ship` TIDAK mengeksekusi/menulis fitur — implementasi dilakukan sebelumnya (pola executing-plans/subagent). `ship` = finishing gate + kirim.
- Hanya jalan pada fitur `status: active`. Bila belum, hentikan & jelaskan.
````

- [ ] **Step 2: Validasi frontmatter**

Run: `head -4 plugin/skills/ship/SKILL.md`
Expected: `---`, `name: ship`, `description: ...`, `---`.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/ship/SKILL.md
git commit -m "feat(skill): add ship (finishing gate + deliver) skill"
```

---

## Task 2: Skill `drop`

**Files:**
- Create: `plugin/skills/drop/SKILL.md`

- [ ] **Step 1: Tulis `plugin/skills/drop/SKILL.md`**

````markdown
---
name: drop
description: Use untuk membatalkan fitur yang lagi direncanakan/dibangun (status draft/active) — tandai dropped + alasan, review knowledge yang sempat dipromosikan, simpan folder sebagai memori keputusan. Trigger — "drop <fitur>", "batalin fitur <fitur>", "cancel <fitur>". Jalankan dari root produk yang punya control/.
---

# drop — Batalkan Fitur

Tujuan: batalkan fitur dengan rapi — `dropped` jadi byproduct + memori keputusan tersimpan.

## Langkah

### 1. Baca fitur
Baca `control/features/<fitur>/feature.yaml` + artifact yang ada (`business.md`, `fanout.md`, `plans/*`).

### 2. Tanya alasan
Tanya kenapa di-drop (singkat). WAJIB — ini jadi memori keputusan.

### 3. Review promosi knowledge
Identifikasi knowledge durable yang sempat disumbang fitur ini: aturan di `control/business/`, `capabilities` di `control/workspace.yaml`. Invoke subagent `critic` untuk bantu pilah: mana yang **feature-specific** (kandidat revert) vs **benar lepas dari fitur** (keep). Tanyakan ke user keep/revert per item, lalu terapkan.

### 4. Tandai dropped (GATE)
Set `control/features/<fitur>/feature.yaml`:
```yaml
name: <fitur>
status: dropped
created: <tetap>
reason: "<alasan>"
dropped_at: <YYYY-MM-DD>
```
**JANGAN hapus folder** — simpan sebagai memori keputusan (`render-docs` akan memfilter status `dropped` dari doc stakeholder).

### 5. Ingatkan kode/branch
Bila implementasi sudah mulai (status `active`), ingatkan user untuk revert/hapus branch terkait. `drop` TIDAK menyentuh kode app (git urusan user).

## Catatan
- Folder fitur `dropped` tetap ada agar keputusan & alasannya tidak dibahas ulang di kemudian hari.
````

- [ ] **Step 2: Validasi frontmatter**

Run: `head -4 plugin/skills/drop/SKILL.md`
Expected: `---`, `name: drop`, `description: ...`, `---`.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/drop/SKILL.md
git commit -m "feat(skill): add drop (cancel feature) skill"
```

---

## Task 3: Verifikasi end-to-end (skenario)

Setup `control/` manual agar tidak bergantung pada init/pipeline.

- [ ] **Step 1: Skenario SHIP — setup fitur `active` + kode minimal**

```bash
mkdir -p /tmp/cv-ship/control/features/auth-flow/plans /tmp/cv-ship/apps/web
cat > /tmp/cv-ship/control/workspace.yaml <<'YAML'
product: demo
topology: monorepo
apps:
  - name: web
    path: apps/web
    type: fullstack
    capabilities: [auth]
    stack: { framework: Next.js }
YAML
cat > /tmp/cv-ship/control/features/auth-flow/feature.yaml <<'YAML'
name: auth-flow
status: active
created: 2026-05-25
YAML
printf '# Auth Flow — Business Spec\nTujuan: login Google+email.\nOut of scope: SSO.\n' > /tmp/cv-ship/control/features/auth-flow/business.md
printf '# Auth Flow — Fan-out\nweb (auth): login + session\n' > /tmp/cv-ship/control/features/auth-flow/fanout.md
printf '# web\nModel: User\nLokasi: apps/web/src/auth\nTest: login\n' > /tmp/cv-ship/control/features/auth-flow/plans/web.md
printf 'export const login = () => {} // auth login\n' > /tmp/cv-ship/apps/web/auth.ts
echo "ship setup done"
```
Di sesi Claude Code (plugin ter-install), cwd `/tmp/cv-ship`, invoke `ship` untuk `auth-flow`. Verifikasi: ship baca artifact, jalankan cek alignment (invoke `critic` membandingkan `auth.ts` vs `business.md`/`plans/web.md`), dan karena tidak ada `gh`/remote, **tampilkan deskripsi PR** lalu set status. (render-docs belum ada → diingatkan.)

- [ ] **Step 2: Assert SHIP**

Run:
```bash
grep -q "status: shipped" /tmp/cv-ship/control/features/auth-flow/feature.yaml \
  && grep -q "shipped_at:" /tmp/cv-ship/control/features/auth-flow/feature.yaml \
  && echo "SHIP OK"
```
Expected: `SHIP OK`

- [ ] **Step 3: Skenario DROP — setup fitur + promosi knowledge**

```bash
mkdir -p /tmp/cv-drop/control/features/gamification /tmp/cv-drop/control/business
cat > /tmp/cv-drop/control/workspace.yaml <<'YAML'
product: demo
topology: monorepo
apps:
  - name: web
    path: apps/web
    capabilities: [auth, gamification-ui]
YAML
printf '# demo — Domain\n## Aturan\n- Poin expired 12 bulan (dari fitur gamification)\n' > /tmp/cv-drop/control/business/domain.md 2>/dev/null || (mkdir -p /tmp/cv-drop/control/business && printf '# demo — Domain\n## Aturan\n- Poin expired 12 bulan (dari fitur gamification)\n' > /tmp/cv-drop/control/business/domain.md)
cat > /tmp/cv-drop/control/features/gamification/feature.yaml <<'YAML'
name: gamification
status: active
created: 2026-05-25
YAML
printf '# Gamification — Business Spec\nTujuan: poin & badge.\n' > /tmp/cv-drop/control/features/gamification/business.md
echo "drop setup done"
```
cwd `/tmp/cv-drop`, invoke `drop` untuk `gamification`. Alasan: "liabilitas voucher kegedean". Verifikasi: drop tanya alasan, invoke `critic` untuk pilah promosi (capability `gamification-ui` & aturan "poin expired" → feature-specific, tawarkan revert), user putuskan, lalu tandai dropped.

- [ ] **Step 4: Assert DROP**

Run:
```bash
grep -q "status: dropped" /tmp/cv-drop/control/features/gamification/feature.yaml \
  && grep -q "reason:" /tmp/cv-drop/control/features/gamification/feature.yaml \
  && test -d /tmp/cv-drop/control/features/gamification \
  && echo "DROP OK"
```
Expected: `DROP OK` (status dropped + reason tercatat + folder TETAP ada)

- [ ] **Step 5: Bersihkan**

Run: `rm -rf /tmp/cv-ship /tmp/cv-drop && echo "cleaned"`
Expected: `cleaned`

---

## Task 4: Update README (+ bump Status)

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Tambah `ship`/`drop` ke alur**

Sisipkan ke bagian alur produk (setelah `/feature`):
```markdown
## Selesai & lifecycle
```
/ship <fitur>       # finishing: review + quality + cek alignment ke business -> PR -> tandai shipped
/drop <fitur>       # batalkan fitur (tandai dropped + alasan, simpan sebagai memori keputusan)
```
```

- [ ] **Step 2: Bump baris `## Status`**

Ganti baris status yang stale ("Fase 1") menjadi:
```markdown
## Status
Fase 1–4 selesai: init, pipeline fitur (feature/intake/fanout/plan + critic), architect/extract, lifecycle (ship/drop). Berikutnya Fase 5: render-docs (doc human-readable).
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: document ship/drop skills and bump status to Phase 4"
```

---

## Definition of Done (Fase 4)

- [ ] `plugin/skills/ship/SKILL.md` + `plugin/skills/drop/SKILL.md` ada, frontmatter valid, terdeteksi setelah plugin reload.
- [ ] `ship` pada fitur `active`: jalankan code review + quality + alignment (via `critic`); pada hijau → bikin/usulkan PR + set `status: shipped` + `shipped_at` (SHIP OK); pada merah → STOP tanpa ship.
- [ ] `drop`: set `status: dropped` + `reason` + `dropped_at`, review promosi knowledge via `critic`, **folder TIDAK dihapus** (DROP OK).
- [ ] `ship` memicu `render-docs` bila tersedia; bila belum (Fase 5), mengingatkan user (tidak error).
- [ ] README ter-update (ship/drop + Status di-bump); tidak ada placeholder tersisa.
```
