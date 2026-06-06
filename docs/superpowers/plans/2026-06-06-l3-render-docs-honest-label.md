# L3 — render-docs label jujur (`shipped` ≠ live/deployed) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (sesi terpisah, per handoff). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** L3 = **wording-only, NOL perubahan perilaku.** Tambah **legend/disclaimer statis** yang memperjelas makna badge `shipped` di `render-docs` (= sudah di-PR / siap-kirim via `ship`, **bukan** indikator merged / ter-deploy / live). `render-docs` ditargetkan ke audiens non-teknis (SKILL.md line 3), dan teks badge `shipped` bisa dibaca "sudah live di produksi" — padahal `ship` cuma `gh pr create` (PR dibuka). L3 menutup gap komunikasi LOW tanpa menambah status, rule, atau file. Spec sumber: `docs/superpowers/specs/2026-06-06-l3-render-docs-honest-label-design.md`.

**Architecture:** L3 menyentuh **2 file render-docs** + **1 frasa induk**. (1) `plugin/skills/render-docs/template.html` — legend statis di `<p class="meta">` slot fixes (line 73), tempat DUA carrier `shipped` terjamin (fix + utang teknis, share `<section id="fixes">`) PASTI dirender. (2) `plugin/skills/render-docs/SKILL.md` — §4 (line 40): bila badge fitur `shipped` dirender (carrier opsional ke-3), sertakan keterangan makna. (3) Induk §9 `### render-docs` (line 223): sync frasa perilaku. **Bukan** mengganti kata "live" (string `live` tak pernah dirender — grep nol); **bukan** "merged" (`shipped` = PR dibuka, belum tentu merged). Selaras induk §3-non-tujuan (line 37) & §16 Future (line 300) yang sudah mendaftarkan `in-review` sebagai future — L3 = label interim, **tidak** menambah status.

**Tech Stack:** Markdown skill + HTML template + Markdown spec. Tak ada kode runtime. "Test" = grep-battery anchor verification + coherence read.

**Branch:** branch kerja sekarang (sudah punya 7 spec committed + semua skill dari main). Commit spec L3 (bila belum) lewat Task 0. Eksekusi & post-exec verify = **sesi terpisah**.

**Bug-guard pre-bake (berlaku semua task):**
- **colon-space frontmatter:** L3 **TIDAK** menyentuh `description:` mana pun (D6). render-docs `description:` (SKILL.md line 3) TAK diedit. AFTER §4 (Task 2) memuat `: ` natural di **BODY prose** ("(legend statis dekat badge): `shipped`") — itu BUKAN value YAML; **JANGAN** hapus demi "patuh guard" (spec §4b catatan colon-space). Guard hanya untuk value `description:`.
- **byte-trap em-dash:** legend pakai em-dash **`—` (U+2014)**, BUKAN arrow `->`/`→` (U+2192), BUKAN middot `·` (U+00B7). COPY REPLACE verbatim dari plan ini; jangan ketik-ulang dash.
- **no-renumber:** semua sisipan = klausa/kalimat tambahan dalam baris yang ADA. Template = sisip kalimat dalam `<p class="meta">` line 73 (tak menambah `<section>`/slot). §4 SKILL = sisip sub-clause (tetap di kalimat fitur, bukan kalimat `dropped`/fix). Induk §9 = sisip frasa SESUDAH "(fitur `dropped` ... section terpisah)". TAK menggeser nomor step/section.
- **mis-aimed-pointer:** induk §9 render-docs = **line 220-225** (`### render-docs`), BUKAN §17; `in-review` Future = line 37 (§3) + line 300 (§16); §12 status table proper = lines 263-268 — TAK disentuh. Pointer "(cermin induk §3/§16 Future 'in-review')" di REPLACE §4 menunjuk section yang beneran punya kontennya.
- **literal-scan sentinel:** legend = prose biasa; tak ada sentinel baru (`<belum ...>`) yang bisa bocor ke scan literal skill lain.
- **render `<code>` vs backtick:** template (Task 1) pakai **`<code>shipped</code>`** (memanfaatkan CSS `code{}` line 33 yang ADA — terverifikasi grep=1). §4 SKILL & induk §9 pakai backtick markdown (`` `shipped` ``) karena itu file `.md`.
- **anti-status-baru:** L3 tak menambah enum status (`in-review`/`deprecated`), tak menyentuh §12 tabel status, `feature.yaml` schema, `ship`/`sensitivity`/`drop`/`feature`/`intake`. Skill TETAP 21; `plugin.json`/`marketplace.json`/README TAK disentuh.
- Tiap commit diakhiri trailer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

**Anchor pre-verify (semua `grep -Fc -e` = 1, terverifikasi vs disk saat penulisan plan):**

| Anchor | File | grep -Fc -e |
|---|---|---|
| `    <p class="meta">Defect dari control/fixes/. Known Issues (open/diagnosed) di atas, Riwayat (shipped) di bawah.</p>` | `plugin/skills/render-docs/template.html` (line 73) | **1** |
| `Fitur \`active\`/\`shipped\` boleh tampil (mis. badge \`.status\`). Untuk fix:` | `plugin/skills/render-docs/SKILL.md` (line 40) | **1** |
| `- **Perilaku:** render ke single HTML (layout sidebar B1, tema Warm/Friendly), **filter by status** (fitur \`dropped\` tidak tampil / masuk section terpisah).` | `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (line 223) | **1** |
| `code{` (CSS `code{}` ada → render `<code>shipped</code>` aman) | `plugin/skills/render-docs/template.html` (line 33) | **1** |

Byte-trap confirmed: line 73 template **tak ada em-dash multibyte** (pakai titik/kurung); legend yang ditambah memakai **em-dash `—` U+2014**; line 223 induk **tak ada em-dash** (anchor murni ASCII + backtick), amendment menambah em-dash `—` sebelum "L3".

---

### Task 0: Commit spec L3 (bila belum ter-commit)

**Files:**
- Add (bila belum): `docs/superpowers/specs/2026-06-06-l3-render-docs-honest-label-design.md`
- Add: `docs/superpowers/plans/2026-06-06-l3-render-docs-honest-label.md` (file ini)

- [ ] **Step 1: Cek status & commit**

```bash
git status --short docs/superpowers/specs/2026-06-06-l3-render-docs-honest-label-design.md docs/superpowers/plans/2026-06-06-l3-render-docs-honest-label.md
git add docs/superpowers/specs/2026-06-06-l3-render-docs-honest-label-design.md docs/superpowers/plans/2026-06-06-l3-render-docs-honest-label.md
git commit -m "docs(l3): spec + plan render-docs honest label (shipped ≠ live; wording-only legend statis)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

> Bila spec sudah ter-commit di branch ini, `git add` cuma me-stage plan baru — commit tetap jalan.

---

### Task 1: `render-docs/template.html` — legend `shipped` di meta slot fixes (line 73)

**Files:**
- Modify: `plugin/skills/render-docs/template.html` (line 73, `<p class="meta">` slot fixes)
- Test: grep anchor

Spec §4a / D3-1 / D4. Slot fixes sudah punya kalimat meta penjelas; tambah klausa makna `shipped` di akhir kalimat itu. Klausa **generik per-makna-badge** ("Badge `shipped` = …") sehingga mencakup DUA carrier terjamin yang share `<section id="fixes">`: fix `shipped` (§3 line 31) + utang teknis `shipped` (§3 line 32). Pakai `<code>shipped</code>` (CSS `code{}` line 33 ADA). Em-dash `—` (U+2014), bukan `: `.

- [ ] **Step 1: Edit** (sisip kalimat dalam `<p class="meta">` yang ada — no-renumber, tak tambah section)

FIND (verbatim):
```
    <p class="meta">Defect dari control/fixes/. Known Issues (open/diagnosed) di atas, Riwayat (shipped) di bawah.</p>
```
REPLACE WITH:
```
    <p class="meta">Defect dari control/fixes/. Known Issues (open/diagnosed) di atas, Riwayat (shipped) di bawah. Badge <code>shipped</code> = sudah di-PR / siap-kirim — bukan indikator sudah merged / ter-deploy / live.</p>
```

- [ ] **Step 2: Verify**

```bash
f=plugin/skills/render-docs/template.html
grep -Fc -e 'Badge <code>shipped</code> = sudah di-PR / siap-kirim — bukan indikator sudah merged / ter-deploy / live.' "$f"  # expect 1 (legend)
grep -Fc -e 'Known Issues (open/diagnosed) di atas, Riwayat (shipped) di bawah. Badge <code>shipped</code>' "$f"  # expect 1 (klausa nempel kalimat induk)
# byte-trap: em-dash U+2014 hadir, arrow → / -> TIDAK di legend baru
grep -Fc -e 'siap-kirim — bukan indikator' "$f"  # expect 1 (em-dash, bukan arrow)
grep -Fc -e 'siap-kirim -> bukan' "$f"  # expect 0 (no ASCII arrow)
# no-renumber: tetap satu <p class="meta"> di slot fixes; <section id="fixes"> utuh
grep -Fc -e '<section id="fixes"><h2>Riwayat Fix / Known Issues</h2>' "$f"  # expect 1
```
Expected: 1 / 1 / 1 / 0 / 1.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/render-docs/template.html
git commit -m "feat(l3): render-docs template legend statis — badge shipped = siap-kirim, bukan merged/deploy/live (meta slot fixes)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `render-docs/SKILL.md` — §4 instruksi makna badge fitur (line 40)

**Files:**
- Modify: `plugin/skills/render-docs/SKILL.md` (§4 FILTER status, line 40, dalam kalimat fitur)
- Test: grep anchor + colon-space guard (frontmatter TAK tersentuh)

Spec §4b / D3-2. Saat §4 mengizinkan badge fitur `shipped`, tambah sub-clause agar render-docs juga menulis disclaimer makna (legend) — bukan badge telanjang. **Sub-clause, BUKAN renumber §4.** Tetap di kalimat fitur (bukan kalimat `dropped`/fix) supaya bila gap L2 (status `deprecated`) kelak diambil, ia menyisip di kalimat `dropped` — tak bentrok. Pointer "(cermin induk §3/§16 Future 'in-review')" menunjuk section induk yang beneran punya kontennya (line 37 + 300). Em-dash `—` (U+2014). **CATATAN colon-space:** AFTER memuat `: ` natural di "(legend statis dekat badge): `shipped`" — ini BODY prose (banyak `: ` prosa normal di body), BUKAN value YAML; JANGAN dihapus. **CATATAN idempotency:** FIND menyertakan trailing ` Untuk fix:` (kata berikutnya di baris yang sama) supaya anchor = bentuk **pre-edit** yang unik; sub-clause disisipkan DI ANTARA "." dan " Untuk fix:", REPLACE mempertahankan ` Untuk fix:` di akhir. Ini mencegah Edit-tool men-substring-match baris post-edit (yang masih memuat `…(mis. badge \`.status\`).`) saat re-run → no double-insert.

- [ ] **Step 1: Edit** (sisip sub-clause SETELAH "boleh tampil (mis. badge `.status`).", tetap di kalimat fitur — no-renumber)

> **Idempotency:** FIND sengaja menyertakan trailing ` Untuk fix:` (kata di baris yang sama, SETELAH titik) supaya anchor unik = bentuk **pre-edit**. Tanpa itu, substring `...(mis. badge \`.status\`).` masih cocok di baris **post-edit** → re-run bisa sisip-ganda. Dengan ` Untuk fix:`, REPLACE menyelipkan sub-clause DI ANTARA "." dan " Untuk fix:", jadi string kontigu FIND lenyap pasca-edit (re-run = 0 match, no-op). Verify Step 2 grep "nempel sub-clause" juga jaga (akan =2 bila ganda).

FIND (verbatim):
```
Fitur `active`/`shipped` boleh tampil (mis. badge `.status`). Untuk fix:
```
REPLACE WITH:
```
Fitur `active`/`shipped` boleh tampil (mis. badge `.status`). **Bila badge `shipped` ditampilkan, sertakan keterangan makna** (legend statis dekat badge): `shipped` = sudah di-PR / siap-kirim, **bukan** indikator merged / ter-deploy / live (cermin induk §3/§16 Future "in-review"). `render-docs` tak punya sinyal CI/deploy — jangan klaim status produksi. Untuk fix:
```

- [ ] **Step 2: Verify** (+ colon-space guard)

```bash
f=plugin/skills/render-docs/SKILL.md
grep -Fc -e '**Bila badge `shipped` ditampilkan, sertakan keterangan makna** (legend statis dekat badge): `shipped` = sudah di-PR / siap-kirim, **bukan** indikator merged / ter-deploy / live' "$f"  # expect 1 (sub-clause)
grep -Fc -e '`render-docs` tak punya sinyal CI/deploy — jangan klaim status produksi.' "$f"  # expect 1 (honesty CI/deploy)
grep -Fc -e '(cermin induk §3/§16 Future "in-review")' "$f"  # expect 1 (pointer)
# anchor kalimat fitur masih utuh & nempel sub-clause (no-renumber + anti-double-insert: HARUS =1, kalau =2 berarti sisip-ganda)
grep -Fc -e 'Fitur `active`/`shipped` boleh tampil (mis. badge `.status`). **Bila badge `shipped` ditampilkan' "$f"  # expect 1
# idempotency: bentuk pre-edit FIND sudah lenyap pasca-edit (re-run aman, no-op)
grep -Fc -e 'Fitur `active`/`shipped` boleh tampil (mis. badge `.status`). Untuk fix:' "$f"  # expect 0
# sub-clause langsung nyambung ke " Untuk fix:" (tail asli baris utuh, tak ke-clobber)
grep -Fc -e 'jangan klaim status produksi. Untuk fix: `dropped` JANGAN ditampilkan' "$f"  # expect 1
# byte-trap em-dash, bukan arrow
grep -Fc -e 'CI/deploy — jangan klaim' "$f"  # expect 1
grep -Fc -e 'CI/deploy -> jangan' "$f"  # expect 0
# colon-space guard: value description (frontmatter) TAK tersentuh & tetap bersih
sed -n 's/^description: //p' "$f" | grep ': ' && echo "BOCOR colon-space di frontmatter!" || echo "desc clean ✓"
# §4 heading masih nomor 4 (no-renumber)
grep -Fc -e '### 4. FILTER status fitur' "$f"  # expect 1
```
Expected: 1 / 1 / 1 / 1 / 0 / 1 / 1 / 0 / desc clean ✓ / 1.

> Catatan guard: `desc clean ✓` di sini hanya konfirmasi frontmatter `description:` render-docs tetap bebas `: ` (TAK kita sentuh). Sub-clause body BOLEH punya `: ` natural — itu prose, bukan YAML.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/render-docs/SKILL.md
git commit -m "feat(l3): render-docs §4 — bila badge shipped dirender, sertakan keterangan makna (siap-kirim ≠ live; tool buta CI/deploy)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Induk spec — §9 `### render-docs` perilaku sync (line 223)

**Files:**
- Modify: `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§9 `### render-docs`, line 223)
- Test: grep anchor + skill-count guard (21 tetap) + no-churn guard

Spec §6. Induk = sumber kebenaran; sync agar tak stale-vs-perilaku render-docs nyata. Sisip frasa SESUDAH "(fitur `dropped` tidak tampil / masuk section terpisah)" — **bukan renumber**, bukan section baru. Em-dash `—` (U+2014) sebelum "L3", bukan `: `, bukan arrow. §3 line 37 / §16 line 300 / §13 line 274-279 / §12 lines 263-268 = TAK diubah (hanya dirujuk di spec).

- [ ] **Step 1: Edit** (sisip frasa dalam baris perilaku yang ada — no-renumber)

FIND (verbatim):
```
- **Perilaku:** render ke single HTML (layout sidebar B1, tema Warm/Friendly), **filter by status** (fitur `dropped` tidak tampil / masuk section terpisah).
```
REPLACE WITH:
```
- **Perilaku:** render ke single HTML (layout sidebar B1, tema Warm/Friendly), **filter by status** (fitur `dropped` tidak tampil / masuk section terpisah); badge status diberi keterangan makna (`shipped` = siap-kirim, bukan live/deploy — L3).
```

- [ ] **Step 2: Verify** (+ skill-count & no-churn guard)

```bash
f=docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
grep -Fc -e 'masuk section terpisah); badge status diberi keterangan makna (`shipped` = siap-kirim, bukan live/deploy — L3).' "$f"  # expect 1 (amendment §9)
# byte-trap em-dash, bukan arrow
grep -Fc -e 'bukan live/deploy — L3' "$f"  # expect 1 (em-dash)
grep -Fc -e 'bukan live/deploy -> L3' "$f"  # expect 0 (no arrow)
# skill-count TETAP 21
grep -Fc -e '**Skills (21):**' "$f"  # expect 1
# §12 enum status TAK ditambah in-review/deprecated (no-churn) — masih 4 status proper
grep -Fc -e 'in-review' "$f"  # expect 2 (line 37 §3 + line 300 §16, future — TAK bertambah)
# §3 non-tujuan in-review (dirujuk, tak diubah)
grep -Fc -e 'Status `in-review` (membedakan "PR dibuka" vs "sudah merged").' "$f"  # expect 1
```
Expected: 1 / 1 / 0 / 1 / 2 / 1.

> `in-review` grep = **2** memastikan L3 tak menambah okurensi `in-review` baru (Future induk tetap apa adanya: §3 line 37 + §16 line 300).

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
git commit -m "docs(spec): sync induk §9 render-docs — badge status diberi keterangan makna (shipped = siap-kirim, bukan live/deploy; L3); enum status tetap 4, skills 21

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Verifikasi akhir (grep-battery L0–L7 + coherence) — sesi eksekusi

**Files:** (read-only; commit hanya bila ada fix)

- [ ] **Step 1: Grep-battery** (dari root repo)

```bash
echo "L0 template legend ada (em-dash, <code>):"; grep -Fc -e 'Badge <code>shipped</code> = sudah di-PR / siap-kirim — bukan indikator sudah merged / ter-deploy / live.' plugin/skills/render-docs/template.html
echo "L1 SKILL §4 sub-clause makna badge fitur:"; grep -Fc -e '**Bila badge `shipped` ditampilkan, sertakan keterangan makna**' plugin/skills/render-docs/SKILL.md; grep -Fc -e '`render-docs` tak punya sinyal CI/deploy — jangan klaim status produksi.' plugin/skills/render-docs/SKILL.md
echo "L2 induk §9 perilaku sync:"; grep -Fc -e '; badge status diberi keterangan makna (`shipped` = siap-kirim, bukan live/deploy — L3).' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md
echo "L3 NO arrow leak (semua em-dash, bukan -> / →) di 3 sisipan:"; grep -Fc -e 'siap-kirim -> bukan' plugin/skills/render-docs/template.html; grep -Fc -e 'CI/deploy -> jangan' plugin/skills/render-docs/SKILL.md; grep -Fc -e 'live/deploy -> L3' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md   # expect 0/0/0
echo "L4 colon-space frontmatter render-docs bersih (TAK disentuh):"; sed -n 's/^description: //p' plugin/skills/render-docs/SKILL.md | grep ': ' && echo "BOCOR!" || echo "desc clean ✓"
echo "L5 NO status baru (enum tetap 4; in-review okurensi tetap 2):"; grep -Fc -e 'in-review' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md   # expect 2
echo "L6 skill-count 21 + plugin.json/marketplace/README TAK tersentuh:"; grep -Fc -e '**Skills (21):**' docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md; git diff --name-only main..HEAD | grep -E 'plugin.json|marketplace.json|README' && echo "BOCOR!" || echo "clean ✓"
echo "L7 'live' string TIDAK dirender render-docs sbg badge (cuma legend prose):"; grep -rn 'live' plugin/skills/render-docs/ | grep -v 'siap-kirim' | grep -v 'ter-deploy / live' | grep -v 'live/deploy' || echo "no stray live ✓"
echo "L7b no file/section/slot baru — diff hanya 2 file render-docs + 1 spec induk + plan/spec L3:"; git diff --name-only main..HEAD
```
Expected: L0 1 · L1 1+1 · L2 1 · L3 0/0/0 · L4 desc clean ✓ · L5 2 · L6 1 + clean ✓ · L7 no stray live ✓ · L7b hanya {template.html, render-docs/SKILL.md, induk spec, spec L3, plan L3}.

> **Catatan L5 scope (anti-bingung):** guard `in-review` = **2** ini men-scan **HANYA induk spec** (`2026-05-24-…-design.md`, line 37 §3 + line 300 §16). Task 2 SECARA TERPISAH menyuntik literal `in-review` ke **`render-docs/SKILL.md`** (di dalam pointer `(cermin induk §3/§16 Future "in-review")`). Dua hal ini **tak saling ganggu** karena beda file — L5 sengaja tak grep `render-docs/`. Jadi setelah L3, SKILL.md memang akan memuat string `in-review` (by design), TANPA menaikkan hitungan induk.
> **Catatan L7 filter (informasional):** filter `-v siap-kirim` cukup karena KEDUA carrier `live` baru (template + SKILL §4) juga memuat `siap-kirim`. Bila kelak ada edit menambah sebut `live` TANPA `siap-kirim`, L7 akan memunculkannya — itu **perilaku yang diinginkan** (memaksa review). Tak ada aksi sekarang.

- [ ] **Step 2: Coherence read** — baca diff `main..HEAD`, pastikan: (a) legend template generik per-makna-badge (mencakup fix + utang teknis yang share `<section id="fixes">`, bukan defect-fix saja); (b) §4 sub-clause tetap di kalimat fitur (tak bentrok kalimat `dropped` untuk L2 future); (c) wording = "siap-kirim/di-PR", BUKAN "merged" BUKAN "live" (D1/D4), konsisten `ship` PR-dibuka; (d) honesty — legend menyatakan tool buta CI/deploy, tak ada klaim "menampilkan status live/produksi" (§5); (e) induk §9 sync benar (pointer §3/§16/§13 tak stale), enum §12 tetap 4, skills 21; (f) NOL file/section/slot/status/rule baru. Catat temuan.

- [ ] **Step 3: Selesai (sesi ini)** — JANGAN merge/push. Lapor: plan tereksekusi, N commit (1 spec/plan + 1 template + 1 SKILL + 1 induk = ~4), tree clean. **Post-exec adversarial verify = sesi LAIN** (fresh-eyes: faithful-exec / byte-trap em-dash / mis-aimed-pointer §3/§16/§13 / parent-doc-staleness §9 / honesty-in-shipped-text "siap-kirim ≠ live & tool buta deploy" / design-hole RISK-2 legend di carrier terjamin), baru integrasi sesuai `superpowers:finishing-a-development-branch`.

---

## Self-Review (penulis plan)

**1. Spec coverage** (tiap edit-map spec → task):
- §4a template.html legend `<p class="meta">` line 73 (pilihan render `<code>shipped</code>`, em-dash) → **Task 1**.
- §4b SKILL.md §4 line 40 sub-clause makna badge fitur (no-renumber, colon-space body OK) → **Task 2**.
- §4c sidebar legend global (line 39) → **OPSIONAL, default TIDAK diambil** (D3-a, hindari scope creep); dicatat di sini agar bisa diminta user — bukan task.
- §6 parent amendment §9 line 223 (sisip frasa perilaku) → **Task 3**. §3 line 37 / §16 line 300 / §13 line 274-279 / §12 lines 263-268 = TAK diubah, hanya dirujuk (tak butuh task).
- §5 honesty-note (legend nyatakan tool buta deploy; ship-text jujur "siap-kirim ≠ live") → tertanam di teks Task 1/2 + verify L1 + Task 4 coherence (d).
- §7 self-review checklist (anchor verbatim / no-renumber / colon-space / wording akurat / honesty / RISK-2 / mis-aimed-pointer / generik / scope-light / literal-scan / pilihan render) → bug-guard header + per-task verify + Task 4 L0-L7.
→ **Tak ada gap.**

**2. Placeholder scan:** tiap step punya isi nyata (find/replace verbatim Task 1-3; grep konkret Task 4). Tak ada TBD/TODO/"similar to". ✓

**3. Anchor consistency & byte-trap:** tiap FIND diambil verbatim dari disk & di-`grep -Fc -e`-verify = **1** saat penulisan plan (template:73, SKILL:40, induk:223; CSS `code{` line 33 ada=1). Em-dash `—` (U+2014) di SEMUA legend (verify L3 = 0 arrow). Line 73 template asli tak ada em-dash multibyte (titik/kurung), line 223 induk anchor murni ASCII+backtick — em-dash baru hanya muncul di REPLACE. Colon-space: legend pakai em-dash/`=`; `: ` di §4 AFTER hanya BODY prose (frontmatter `description:` TAK disentuh — verify L4). No-renumber: 3 sisipan = klausa/frasa dalam baris ADA; §4 heading tetap "4", `<section id="fixes">` utuh. Mis-aimed-pointer: §9=line 220-225, §3 line 37, §16 line 300, §13 line 274-279, §12 lines 263-268 (verify L5 `in-review` tetap 2). Skills 21 (verify L6). ✓
