# Milestone Smoke + "Coba Sendiri" di Gate `build` — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gate `build` per-milestone proaktif nyodorin test-case lulus + resep verifikasi manual ("Coba sendiri"), dan beneran boot+drive surface yang dibangun (self-smoke) buat milestone ber-surface — dengan `fix` keikut gratis & `tweak` dapet Part-A doang.

**Architecture:** Semua perubahan = **edit prose skill markdown** (tak ada kode ber-test-harness). `build/SKILL.md` step 6 dapet section "Coba sendiri" (Part A selalu + Part B smoke-subagent kondisional), di-back oleh detail di `build/reference.md` §D. `fix` **tak disentuh** (pinjam gate `build`). `tweak/SKILL.md` step 5 dapet Part-A doang (tanpa boot), di-back `tweak/reference.md` §E/§F.

**Tech Stack:** Markdown (skill-authoring plugin context-vault). Verifikasi = `rg`/`grep` (teks tersisip) + baca-cek konsistensi lintas-file. Tak ada unit-test runtime; "test" tiap task = assertion tekstual atas file yang diedit.

**Spec:** `docs/superpowers/specs/2026-07-03-build-milestone-smoke-design.md` (11 keputusan D1–D11).

## Global Constraints

Copy verbatim dari spec — implicit di SETIAP task:

- **Anti-rekursi:** JANGAN invoke `/verify`·`/run`·`/fix`·`/debt` sebagai skill dari `build`. Pinjam **pola** inline (konsisten arsitektur `build` yang minjem template `subagent-driven-development` tanpa invoke). (D5/D9)
- **Anti-dobel:** smoke SKIP surface yang sudah di-cover `unit: integration` (boot+roundtrip) / `mockup:` (eyeball+buka app) / roundtrip `ship` step 3. (D9)
- **Trigger Part B nangkep `create` DAN `modify`** surface — bukan cuma route baru (kalau cuma `create`, `fix` yang ngedit endpoint existing tak akan pernah ter-smoke). (D3/D10)
- **Ragu ada-surface → skip Part B** (advisory, bukan palang; false-skip = balik perilaku lama, aman). (D4)
- **`fix` = NOL perubahan file** (keikut via pinjam gate `build`). (D10)
- **`tweak` = Part A doang** (TANPA auto-boot; jaga inline/single-session/non-resumable). (D11)
- **Bobot cap-volume unattended TIDAK berubah** (bobot = look-ahead per-task; smoke per-segmen di gate). (D8)
- **Voice:** padat, bilingual-Indonesia sesuai skill existing; heading/marker konsisten ("Coba sendiri", "Part A"/"Part B", "M-smoke", "smoke subagent").

## File Structure

| File | Tanggung jawab perubahan |
|---|---|
| `plugin/skills/build/reference.md` §D | **Detail kontrak M-smoke** — Part A/B, tabel trigger, mekanisme boot, environment, failure, unattended, anti-dobel, contoh before/after. (Task 1) |
| `plugin/skills/build/SKILL.md` step 6 | **Perilaku gate** — sisipkan clause "Coba sendiri" (Part A + Part B + failure→deviasi) + pointer ke `reference.md` §D. (Task 2) |
| `plugin/skills/tweak/SKILL.md` step 5 | **Gate tweak** — sisipkan blok "Coba sendiri" (Part A doang). (Task 3) |
| `plugin/skills/tweak/reference.md` §E + §F | **Detail + acceptance** — penurunan resep di gate + 1 baris eval. (Task 3) |
| `plugin/skills/fix/*` | **NOL** (keikut gratis). |

**Urutan:** Task 1 (reference §D = fondasi yang di-pointer) → Task 2 (SKILL step 6) → Task 3 (tweak, independen; dilakukan terakhir biar penamaan "Coba sendiri"/"Part A" terkunci konsisten).

---

### Task 1: `build/reference.md` §D — detail kontrak M-smoke + contoh

**Files:**
- Modify: `plugin/skills/build/reference.md` (§D, sisip bullet baru sebelum `## E. Status & resume`)

**Interfaces:**
- Produces: section referensi ber-anchor **"M-smoke"** yang di-pointer `build/SKILL.md` step 6 (Task 2) via "`reference.md` §D".

- [ ] **Step 1: Sisipkan bullet M-smoke di akhir §D**

Edit — `old_string` (baris terakhir §D, bullet simplify pass; ambil ekor uniknya):

```
Anti-rekursi: inline, JANGAN invoke `/simplify`/`/debt`/`/fix`. Subagent: `code-simplifier` (dibekali diff + `conventions.md` + slice `control/schema/<unit>.md`).
```

`new_string` (teks di atas + bullet baru):

```
Anti-rekursi: inline, JANGAN invoke `/simplify`/`/debt`/`/fix`. Subagent: `code-simplifier` (dibekali diff + `conventions.md` + slice `control/schema/<unit>.md`).
- **Milestone smoke + section "Coba sendiri" (M-smoke, SKILL step 6).** Tiap gate segmen menampilkan section **"Coba sendiri"** di samping diff/test/challenge:
  - **Part A (SELALU, murah, tanpa boot):** (a) **test-case lulus** eksplisit dari `test:` task-task segmen (bukan cuma "N/N ijo"); (b) **resep verifikasi manual** — `curl`/URL "buka …" untuk surface yang dibangun, diturunkan dari **diff + `files` + port env-contract** (`wire` `.env`). Milestone logika-murni (tanpa surface) → resep kosong "no runnable surface", test-case tetap tampil.
  - **Part B (self-smoke, KONDISIONAL — auto+lapor):** dispatch **smoke subagent** bila trigger (tabel bawah) terpenuhi. Brief smoke (pola file-handoff, sama `unit: integration`): app mana yang di-boot (path/stack `workspace.yaml`) + resep Part A + path report. Subagent: boot app (mekanisme SAMA boot `unit: integration` — BUKAN invoke skill `/run`/`/verify`; pinjam polanya) → jalankan resep terhadap app hidup → tangkap **observasi** (status+shape response untuk API; screenshot/render-check untuk UI page) → tulis report → balikan ringkas. Gate menampilkan observasi di sebelah resep. Model smoke subagent = **tier rendah** (boot+probe, bukan judgment).
  - **Trigger Part B (semua harus IYA):**

    | syarat | lolos bila |
    |---|---|
    | ada runnable surface | diff segmen `create` **ATAU** `modify` HTTP route / UI page (`modify` penting — `fix` ngedit endpoint existing) |
    | belum di-boot integration | surface tak di-cover task `unit: integration` di segmen |
    | bukan mockup | task **tanpa** `mockup:` (yang ber-`mockup:` sudah eyeball+buka app) |
    | unit runnable | `unit ∈ apps[]` (package/`integration` → skip) |

    Deteksi "runnable surface" = **heuristik ringan** atas `unit`+`files`+diff (cocok konvensi routing/page app). **Ragu → skip Part B** + catat "surface tak jelas — smoke di-skip" (advisory, BUKAN palang; false-skip = balik perilaku lama, aman).
  - **Environment:** di titik gate env lokal DIJAMIN ada (DB ter-`wire`; `manual:` env/secret sudah lewat `needs_human` step 2). Smoke HANYA melawan env lokal ter-wire — tak pernah prod; boleh memutasi DB dev lokal (mis. `register` bikin row uji).
  - **Failure:** boot-fail / endpoint 5xx / crash / render rusak **PADAHAL unit-test ijo** = **penyimpangan** → masuk **disiplin fix embed** step 6 (reproduce→root-cause→corrective `kind: fix`); karena "penyimpangan" = HARD floor, auto-approve unattended TIDAK nyala. Boot-fail karena prereq lingkungan yang mestinya ada → **blocker lingkungan** (`halt`), bukan corrective task. Observasi plausible → tampil gate (attended) / ringkas `last-run.md` (unattended).
  - **Unattended (M7):** Part B tetap jalan (tujuannya). Observasi → prosa `last-run.md`. Ongkos = **satu boot per segmen qualifying** — TIDAK mengubah model bobot cap-volume (bobot = look-ahead per-task; smoke per-segmen di gate). Floor-scan tak terpengaruh (smoke tak nambah diff).
  - **Anti-dobel:** smoke SKIP surface yang sudah di-cover `unit: integration` / `mockup:` / roundtrip `ship` step 3. M-smoke = lebih dini, per-milestone, single-surface.
  - **Contoh (gate M2 `auth`):**
    ```
    ── Coba sendiri ──────────────────────────────
    test case lulus:
      • register sukses → 201 + set-cookie
      • register email kepake → 409 · pw lemah → 422
      • login sukses → 200 · pw salah → 401 · user ∅ → 401
    verifikasi manual (localhost:3000):
      curl -i -X POST localhost:3000/auth/register -d '{"email":"a@b.co","password":"secret12"}'
      curl -i -X POST localhost:3000/auth/login    -d '{"email":"a@b.co","password":"salah"}'
    smoke (auto):
      ✓ POST /auth/register → 201 {id,email} + Set-Cookie: sid=…
      ✓ POST /auth/login (pw salah) → 401 {error:"invalid_credentials"}
    ──────────────────────────────────────────────
    ```
    M1 (`hash`/`session`) → resep+smoke kosong ("no runnable surface"), test-case tetap tampil. M3 (`login` UI ber-`mockup:`) → Part B skip (sudah eyeball via mockup).
```

- [ ] **Step 2: Verifikasi teks tersisip & anchor ada**

Run:
```bash
rg -n "M-smoke|Coba sendiri|Trigger Part B" plugin/skills/build/reference.md
```
Expected: minimal 3 hit; "M-smoke" muncul di §D (bukan §E/§lain).

- [ ] **Step 3: Baca-cek konsistensi**

Baca §D hasil edit. Assert: (a) tabel trigger punya 4 baris (surface/integration/mockup/unit); (b) klausa "`create` **ATAU** `modify`" ada; (c) failure me-route ke "disiplin fix embed"; (d) contoh before/after utuh (register+login). Tak ada `TBD`/`TODO`.

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/build/reference.md
git commit -m "feat(build): reference §D — kontrak milestone smoke + Coba sendiri"
```

---

### Task 2: `build/SKILL.md` step 6 — clause "Coba sendiri" (Part A + Part B + failure)

**Files:**
- Modify: `plugin/skills/build/SKILL.md` (step 6, dalam presentasi gate — sisip sebelum "→ minta **approve/revisi**")

**Interfaces:**
- Consumes: anchor `reference.md` §D "M-smoke" (Task 1).
- Produces: perilaku gate step 6 yang `fix` warisi otomatis (pinjam gate) — **tak ada file `fix` disentuh**.

- [ ] **Step 1: Sisipkan clause di presentasi gate step 6**

Edit — `old_string` (ekor unik challenge checklist step 6; "tak-terindeks" cuma muncul sekali, di step 6):

```
**query — data-access reuse repo/query-layer existing & hindari N+1/lookup tak-terindeks?**) → minta **approve/revisi**.
```

`new_string`:

```
**query — data-access reuse repo/query-layer existing & hindari N+1/lookup tak-terindeks?**) **+ section "Coba sendiri" (M-smoke, `reference.md` §D):** **Part A (selalu):** daftar **test-case lulus** eksplisit (`test:` task segmen) + **resep verifikasi manual** (`curl`/URL, diturunkan diff+`files`+port env-contract) — milestone logika-murni → resep kosong, test-case tetap tampil. **Part B (kondisional, auto+lapor):** bila segmen nyentuh runnable surface (HTTP route / UI page, **`create` ATAU `modify`**) DAN belum di-boot `unit: integration` DAN bukan task `mockup:` → **dispatch smoke subagent** (pola file-handoff; boot app via path/stack `workspace.yaml` seperti `unit: integration` — BUKAN invoke `/run`/`/verify`, pinjam pola) → jalankan resep terhadap app hidup → observasi (status+shape / screenshot) tampil di sebelah resep. Ragu ada-surface / `unit` package·`integration` → skip Part B (Part A tetap). **Smoke gagal PADAHAL unit-test ijo** (boot-fail/5xx/crash/render rusak) = **penyimpangan** → jalankan disiplin fix embed yang SAMA (HARD floor: auto-approve unattended tak nyala); boot-fail prereq-lingkungan → blocker lingkungan (`halt`). Anti-dobel: SKIP yang di-cover `integration`/`mockup:`/roundtrip `ship`. → minta **approve/revisi**.
```

- [ ] **Step 2: Verifikasi clause tersisip di step 6 (bukan step 7a)**

Run:
```bash
rg -n "Coba sendiri.*M-smoke|dispatch smoke subagent" plugin/skills/build/SKILL.md
```
Expected: hit berada di baris step 6 (yang memuat "challenge checklist"/"auto-approve segmen"), BUKAN step 7a (simplify).

- [ ] **Step 3: Verifikasi pointer ke §D resolve + tak nabrak anti-rekursi**

Run:
```bash
rg -n "reference.md. §D|invoke .?/run|invoke .?/verify" plugin/skills/build/SKILL.md
```
Expected: pointer "`reference.md` §D" ada (Task 1 sudah nulis §D). Assert manual: teks berkata **BUKAN** invoke `/run`/`/verify` (pinjam pola) — konsisten Global Constraint anti-rekursi.

- [ ] **Step 4: Baca-cek — `fix` tetap nol perubahan**

Konfirmasi tak ada file di `plugin/skills/fix/` yang perlu diubah (D10). `git status` cuma nunjukin `build/SKILL.md`.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/build/SKILL.md
git commit -m "feat(build): step 6 gate — section Coba sendiri (Part A) + self-smoke (Part B)"
```

---

### Task 3: `tweak` — Part A doang di gate step 5 (+ reference §E/§F)

**Files:**
- Modify: `plugin/skills/tweak/SKILL.md` (step 5, sisip blok "Coba sendiri" sebelum "→ minta **approve/revisi**")
- Modify: `plugin/skills/tweak/reference.md` (§E — penurunan resep; §F — 1 baris eval)

**Interfaces:**
- Consumes: penamaan "Coba sendiri"/"Part A" yang dikunci Task 1–2 (konsistensi lintas-skill).

- [ ] **Step 1: Sisip blok "Coba sendiri" di gate `tweak` step 5**

Edit `plugin/skills/tweak/SKILL.md` — `old_string`:

```
`Bentrok aturan: <isi> · Tradeoff: <isi> · Alternatif simpel: <isi> · Yang bisa jebol: <isi>`) → minta **approve/revisi**. (Challenge Checklist = output terisi, BUKAN interogasi 4-ronde.)
```

`new_string`:

```
`Bentrok aturan: <isi> · Tradeoff: <isi> · Alternatif simpel: <isi> · Yang bisa jebol: <isi>`) **+ section "Coba sendiri" (Part A, cermin gate `build`):** **test-case lulus** (dari test TDD step 3) + **resep verifikasi manual** (`curl`/URL untuk perilaku yang diubah, diturunkan dari diff). **TANPA auto-boot** — Part B (self-smoke) khusus `build`; tweak tetap inline/single-session. Kosmetik murni (tak ada test step 3) → blok di-skip. → minta **approve/revisi**. (Challenge Checklist = output terisi, BUKAN interogasi 4-ronde.)
```

- [ ] **Step 2: Tambah penurunan resep di `tweak/reference.md` §E**

Edit `plugin/skills/tweak/reference.md` — `old_string` (kalimat floor-scan §E):

```
**Floor-scan (step 5, WAJIB, mekanis):** grep diff final — (a) secret hardcoded (API key/token/password/connstring di luar env) + PII di log/response (persis quick-scan `ship` sensitivity-kosong); (b) pola security-loosening: `auth`/flag → `false`, penghapusan middleware auth/validasi, TTL membesar, penghapusan signature-check. Kena → STOP, lapor.
```

`new_string`:

```
**Floor-scan (step 5, WAJIB, mekanis):** grep diff final — (a) secret hardcoded (API key/token/password/connstring di luar env) + PII di log/response (persis quick-scan `ship` sensitivity-kosong); (b) pola security-loosening: `auth`/flag → `false`, penghapusan middleware auth/validasi, TTL membesar, penghapusan signature-check. Kena → STOP, lapor.
**Section "Coba sendiri" (step 5, Part A — cermin gate `build`):** setelah floor-scan lolos, gate menampilkan (a) **test-case lulus** dari test yang ditulis TDD (step 3); (b) **resep verifikasi manual** (`curl`/URL untuk perilaku yang diubah, diturunkan dari diff). **TANPA Part B/auto-boot** (khusus `build` — tweak inline/single-session/non-resumable). Kosmetik murni (tak ada test) → skip.
```

- [ ] **Step 3: Tambah baris acceptance di `tweak/reference.md` §F**

Edit `plugin/skills/tweak/reference.md` — `old_string` (baris tabel "Gate + finish"):

```
| gate | nampilin Challenge Checklist TERISI (bukan "approve?" doang) |
```

`new_string`:

```
| gate | nampilin Challenge Checklist TERISI (bukan "approve?" doang) |
| gate perubahan berperilaku | nampilin "Coba sendiri": test-case lulus + resep `curl`/URL (Part A, TANPA auto-boot) |
```

- [ ] **Step 4: Verifikasi tersisip + batas no-boot eksplisit**

Run:
```bash
rg -n "Coba sendiri|TANPA auto-boot|TANPA Part B" plugin/skills/tweak/SKILL.md plugin/skills/tweak/reference.md
```
Expected: "Coba sendiri" muncul di SKILL step 5 + reference §E + §F; batas "TANPA auto-boot"/"TANPA Part B" eksplisit di SKILL & §E (jaga DNA tweak).

- [ ] **Step 5: Baca-cek konsistensi penamaan lintas-skill**

Assert "Coba sendiri"/"Part A" di tweak identik ejaannya dengan `build` (Task 1–2). `fix` tetap tak tersentuh.

- [ ] **Step 6: Commit**

```bash
git add plugin/skills/tweak/SKILL.md plugin/skills/tweak/reference.md
git commit -m "feat(tweak): gate step 5 — section Coba sendiri (Part A doang, tanpa auto-boot)"
```

---

## Self-Review (diisi penulis plan)

**1. Spec coverage:** D1(Part A)→T2/T1 · D2–D5(Part B/boot)→T1/T2 · D6(env)→T1 · D7(failure)→T1/T2 · D8(unattended)→T1 · D9(anti-dobel/rekursi)→T1/T2+Global · D10(fix gratis)→T2 step 4 (nol perubahan, di-assert) · D11(tweak Part A)→T3. Contoh §5→T1 step 1. **Tak ada D tanpa task.**

**2. Placeholder scan:** Nol `TBD`/`TODO`/"handle edge cases" — semua insertion teks final verbatim.

**3. Konsistensi penamaan:** "Coba sendiri" · "Part A"/"Part B" · "M-smoke" · "smoke subagent" · "`create` ATAU `modify`" dipakai identik di T1/T2/T3. Pointer "`reference.md` §D" (T2) → anchor ditulis T1. `fix` = nol edit di ketiga task (D10).
