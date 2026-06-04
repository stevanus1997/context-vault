# HANDOFF — Spec B: `design-system bring-up` (greenfield design fidelity)

> **Buat sesi baru: BACA INI DULU.** Dokumen ini self-contained — kamu tak perlu konteks chat sesi sebelumnya. Sumber kebenaran = spec + plan + memory di repo (di-link di §6). Tanggal handoff: **2026-06-05**. Repo: `~/Developer/ai-boilerplate` (github.com/stevanus1997/context-vault), branch kerja: `main`.
>
> **Prasyarat:** Spec A `mockup-thread` SUDAH **LIVE di `main` @ `4585f40`** (lihat §2). Spec B **depends on A** — A adalah atom yang B pakai. Jangan ulang A.

---

## 0. TL;DR — apa yang harus dilakukan

1. **Spec A (`mockup-thread`) = SELESAI & LIVE di `main`** (@ `4585f40`). Jangan ulang. A nutup design-fidelity buat project yang **komponen/design-system-nya UDAH ADA di kode** (steady-state).
2. **Spec B = gap yang BELUM dikerjain:** project **DARI 0** (belum ada design system / komponen) — mockup awal itu sumber buat **fondasi design system** (tokens + komponen primitif), bukan cuma layout per-fitur. Pipeline **gak punya fase** buat ini.
3. **Cara kerja WAJIB** (§5): `brainstorming → tulis spec → 6-dim adversarial spec self-review → writing-plans → executing-plans (sesi terpisah) → post-exec fresh-eyes verify (sesi LAIN) → FF-merge+push`. JANGAN skip brainstorming. Plugin ini **GENERIC** (bukan khusus framework/CSS-lib apa pun).
4. **Desain Spec B udah DIEKSPLOR sebagian** (§3) tapi **BELUM dikunci** — beberapa fork nyata harus diputus di brainstorming (§4). Jangan langsung nulis spec; mulai brainstorming dari §4.
5. **Bedanya dari A yang penting buat scope:** B **bikin skill/agent baru atau wire-mode baru** → beda dari A yang murni additif. Artinya B **AKAN ngubah skill-count** → wajib update `plugin.json` + `marketplace.json` + `README` + parent-spec §17 (lihat bug-guard §5).

---

## 1. Problem & konteks

**Apa itu context-vault:** Claude Code plugin + template yang nyediain **lapisan AI + knowledge (BUKAN kode)** buat ngelola produk multi-app. Knowledge hidup di `control/` (`workspace.yaml`, `business/`, `conventions.md`, `invariants.md`, `integrations.md`, `features/`, `fixes/`, `debt.yaml`), tumbuh just-in-time. Lifecycle:

```
discovery → init → architect → wire → feature(intake→fanout→plan) → breakdown → build → ship
            (+ add-app / add-package / add-integration saat fitur butuh app/package/vendor baru)
            (+ lane fix & debt; ask read-only; drop; extract; render-docs)
```
**20 skill** + 2 agent (`critic`, `security-critic`). Desain induk: `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md`.

**Asal Spec A & B:** user (solo dev, BUKAN orang produk/bisnis — drive proaktif) test end-to-end di project **board game**. `/build` gak pernah reproduce mockup HTML/CSS (hasil "Claude design") 1:1 — **layout beda total + animasi hilang**, TAPI komponen aman (design system udah ada di kode). RCA (workflow 11-agent, 4 lensa adversarial, refuted 0/4): **mockup gak punya rumah di mana pun** sepanjang `feature→plan→breakdown→build` (capture gap + cross-session killer + thread-buang-pixel + dispatch-tanpa-mockup + verify-buta-render).

**Insight kunci yang ngelahirin Spec B:** masalah user (komponen aman, cuma layout+animasi yang ilang) = **steady-state**. Yang **selamat** = apa yang udah ada DI KODE (design system, komponen → build niru lewat "pointer pola"). Yang **mati** = apa yang cuma ada DI MOCKUP (layout per-halaman + animasi). **Spec A** nutup yang kedua buat steady-state. **Tapi project DARI 0 belum punya design system di kode sama sekali** — itu Spec B.

---

## 2. STATUS — Spec A (`mockup-thread`) LIVE @ `4585f40`

**Yang A lakukan** (5 file skill, additif, nol skill/agent baru): mockup user di-thread sebagai **byte opaque** lewat pipeline.
- **CAPTURE @ `plan`**: mockup (format apa pun: HTML/CSS/gambar/URL Figma) disimpan verbatim ke `control/features/<f>/mockups/` + slot `Mockup:` di `plans/<app>.md`.
- **THREAD @ `breakdown`**: key opsional `mockup: <path>` di task (schema §A) + aturan (§D-6) + coverage check (tiap mockup → ≥1 task).
- **DISPATCH @ `build`**: implementer dikasih isi/pointer mockup + instruksi **tech-agnostic** *"reproduksi HASIL VISUAL (layout+animasi) pakai stack+komponen project, JANGAN transplant markup mentah, BAWA animasi"* (`build/reference.md` §B) + model terkuat (§C); item eyeball di gate §6.
- **GENERIC**: plugin tak pernah nulis CSS / asumsi framework. Translasi sandar ke `conventions.md` + `stack` + "pointer pola" (file komponen existing).

Spec A: `docs/superpowers/specs/2026-06-04-mockup-thread-design-fidelity-design.md` · Plan: `docs/superpowers/plans/2026-06-04-mockup-thread.md`. Post-exec verify: MINOR_FIXES, 0 must-fix (streak bug mis-aimed-pointer 7× akhirnya putus karena plan pre-bake guard verifikasi-pointer).

**B dibangun DI ATAS A:** mekanisme dispatch A (`build/reference.md §B` — paste/lampir mockup + instruksi reproduksi) = **atom** yang B pakai buat bangun komponen primitif dari mockup. Itu sebabnya A duluan.

---

## 3. Spec B — gap, dan desain yang sudah dieksplor

### 3.1 Gap (yang B harus tutup)
Project **dari 0**: belum ada design system, belum ada komponen di kode. Mockup awal (Claude-design / Figma) adalah sumber buat:
- **Design tokens**: palet warna, skala tipografi, spacing, radius, shadow, **+ motion vocab (easing & durasi)**.
- **Komponen primitif**: Button / Input / Card / dst — cocok bahasa visual mockup.

Pipeline sekarang **gak handle ini sama sekali** (bukan cuma "bocor" kayak A — emang gak ada fasenya):
- `architect` cuma mutusin stack + "lib kunci" (bisa pilih Tailwind/shadcn) — gak nangkep bahasa visual.
- `wire` cuma skeleton teknis (scaffold+DB+API wiring) — nol concern design.
- `add-package ui-kit` bisa bikin package, tapi cuma nangkep **kontrak exports** — bukan tampilan (gap capture yang sama + nol token dikunci).

**Kalau dibiarin:** fitur UI PERTAMA nginvent design system ad-hoc dari mockup-nya → tiap fitur drift. Lebih parah dari masalah A.

### 3.2 Desain yang sudah dieksplor (BELUM dikunci — konfirmasi di brainstorming)
- **Design-system bring-up = fase FONDASIONAL**, duduk sebaris `invariants.md`/`conventions.md`/`wire` (dikunci sekali di awal, seperti invarian).
- Menghasilkan **DUA hal**: (a) durable `control/design-system.md` (tokens + **motion vocab** + inventory komponen + pointer mockup kanonik); (b) **KODE** — tokens + komponen primitif di `ui-kit` package atau app, lewat mesin `add-package`/`build` yang ada, **dengan mockup di-thread ke implementer** (mekanisme Spec A).
- Jalan **setelah `architect`** (stack UI ketauan), di layer bring-up.
- **Setelah B jalan → project dari-0 masuk steady-state** (komponen di kode) tempat Spec A handle layout+animasi per-fitur. **B = bootstrap sekali-jalan** yang bikin project dari-0 nyampe ke kondisi project user sekarang.
- **GENERIC**: bahasa visual di-*elicit* dari mockup; nol lock-in framework/CSS-lib; stack dari `workspace.yaml`/architect.
- Pola Proposal 3 dari panel juri RCA awal ("design-system / tokens, gaya invariants").

---

## 4. Open questions — PUTUSKAN di brainstorming (jangan pre-decide)

1. **Skill baru `design-system` vs `wire` mode-design?** `wire` udah generic-from-stack & punya mode (mode-package §I, mode-integration §J) → "mode-design" nyatu. TAPI generate design-system dari mockup itu **judgment-heavy** (kayak `discovery`/`add-package`) → mungkin layak skill sendiri. (Timbang surface vs kohesi.)
2. **Posisi di lifecycle:** setelah `architect`, sebelum/barengan `wire`, atau **setelah `wire`** (karena butuh skeleton jalan dulu buat render/preview komponen)? Hubungan ke "empty-but-running skeleton" wire.
3. **Interaksi sama `add-package ui-kit`:** design system itu **shared package** (consumers/mandatory_for) atau komponen app-lokal? Reuse mesin `add-package` + thread mockup, atau jalur sendiri?
4. **Motion token:** gimana nangkep/representasiin di `control/design-system.md`, dan gimana animasi per-fitur (Spec A) ngreferensiinnya.
5. **`control/design-system.md` = SHAPE hand-authored** (kayak `integrations.md` M5, gak ada upstream selain mockup) atau projeksi? (Kemungkinan besar hand-authored dari mockup.)
6. **Brownfield (kasus user sekarang):** project yang komponennya UDAH ada — B jalan mode CAPTURE (dokumentasiin tokens/komponen existing ke design-system.md, kayak architect/extract/wire brownfield)? Atau B greenfield-only?
7. **Apakah `architect` perlu langkah baru** mutusin design-approach/bahasa-visual eksplisit (sekarang cuma "lib kunci")? Apakah B butuh keputusan architect dulu?
8. **Scope v1:** tokens + komponen primitif aja? Defer komposit/page-level (itu wilayah per-fitur Spec A).

---

## 5. Cara kerja WAJIB + bug-guard

**Proses** (jangan skip brainstorming): `brainstorming` (eksplor §4 satu-satu) → tulis spec ke `docs/superpowers/specs/2026-06-XX-design-system-bring-up-design.md` → **6-dim adversarial spec self-review** (workflow: seam/coherence/scope/ambiguity/genericness/staleness) → `writing-plans` (**one-file-per-task, tiap anchor grep-verified verbatim SEBELUM commit**) → `executing-plans` di branch (`design-system-bringup`) → **post-exec fresh-eyes adversarial verify di sesi LAIN** (5-lensa: seam-coherence / spec-faithful / mis-aimed-pointer / parent-doc-staleness / prose-casing → adjudikasi skeptis) → FF-merge + push + hapus branch.

**Bug-guard pre-bake** (pelajaran berulang — lihat memory):
- **B BIKIN skill/agent baru / mode baru** → **WAJIB** update `plugin/.claude-plugin/plugin.json` + `marketplace.json` + `README` + parent-spec **§17 + §8 (repo-tree) + §12 (lifecycle) skill-count** (beda dari A yang additif murni; staleness skill-count = kelas bug ke-2 yang konsisten).
- **colon-space** di description frontmatter skill/agent baru (`name:`/`description:` — kasus `Generic:`→`Generic —` kejadian berkali).
- **mis-aimed-pointer**: tiap "reference §X" / "SKILL §Y" diverifikasi nunjuk seksi yang BENER (streak 7× baru putus di A karena guard ini di-prebake — PERTAHANKAN; fresh-eyes read di sesi lain tetap wajib).
- **parent-doc-tree staleness**: kalau B nambah artifact `control/` baru (mis. `design-system.md`), update control-tree parent-spec §7 (ini yang lolos di A, ke-8×).
- **no-renumber**: tambah sebagai sub-bullet / step desimal, jangan renumber list/step existing.
- **sentinel literal-scan trap**: kalau ada sentinel di template (preseden `<belum dikunci>` di invariants.md yang sempat mecahin literal-scan wire/architect).
- **coherence guard**: jangan source dari artifact fiktif; B nyandar A (LIVE) + mungkin add-package (LIVE) — dua-duanya nyata.
- Plugin **GENERIC** — bahasa visual elicited, jangan hardcode Tailwind/shadcn/dll.

---

## 6. Pointer file kunci

- **Spec A (yang B reuse):** `docs/superpowers/specs/2026-06-04-mockup-thread-design-fidelity-design.md` — **§12 = hubungan ke B**; §4-8 = mekanisme mockup-thread (artifact `mockups/`, dispatch `build §B`) yang B pakai. Plan: `docs/superpowers/plans/2026-06-04-mockup-thread.md`.
- **Parent spec:** `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§7 control-tree, §8 repo-tree, §12 lifecycle, §17 komponen/skill-count).
- **wire:** `plugin/skills/wire/SKILL.md` + `reference.md` (mode-package §I, mode-integration §J; "empty-but-running"; generic-from-stack). Kandidat host "mode-design".
- **architect:** `plugin/skills/architect/SKILL.md` ("lib kunci"; langkah 4.5 kunci-invarian — preseden fase fondasional gated+idempotent+critic).
- **add-package (preseden ui-kit + conductor):** `plugin/skills/add-package/SKILL.md` + spec `docs/superpowers/specs/2026-06-01-h2-shared-package-design.md` (pola conductor declare→architect→wire; gate typecheck; `packages[]`/`consumers[]`/`mandatory_for`).
- **build dispatch (atom Spec A):** `plugin/skills/build/reference.md` §B (sekarang ada bullet Mockup) + §C (model terkuat).
- **add-integration (preseden SHAPE hand-authored + conductor tanpa architect):** `plugin/skills/add-integration/SKILL.md` + spec `docs/superpowers/specs/2026-06-01-m5-integrations-design.md` (kalau `design-system.md` mau hand-authored kayak `integrations.md`).
- **Memory:** `~/.claude/projects/-Users-stevanus-Developer-ai-boilerplate/memory/MEMORY.md` + `context-vault-project.md` (riwayat lengkap + 9 pelajaran eksekusi).

---

## 7. Catatan

- **Antrean lain yang juga pending** (jangan campur ke Spec B — masing-masing spec terpisah): Langkah-2 **M4 (schema-projection) → H3 (migration-governance)**; tes live `/plugin install` end-to-end (belum pernah, semua fase).
- **User context:** solo dev, bukan orang produk/bisnis → drive keputusan desain proaktif, insist sumber. Casual register (Bahasa Indonesia "gw/lo"). Pola: tiap gap dieksekusi + diverifikasi di **sesi terpisah**.
- **Validasi nyata Spec A** masih nunggu user nyobain 1 fitur UI board-game end-to-end (lihat ronde `/fix` ilang). Kalau A ternyata masih bocor → mungkin perlu tier verify-otomatis (§G di spec A, di-defer). Itu bukan blocker buat B.
