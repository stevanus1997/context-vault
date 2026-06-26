---
name: fix
description: Use untuk memperbaiki DEFECT — perilaku yang SUDAH ADA ternyata salah, bukan kapabilitas baru. Auto-deteksi mode — in-flight (bug saat build, fitur active → corrective task di tasks.yaml fitur) atau post-ship (bug produksi, fitur shipped → control/fixes/<id>/ first-class). Alur — reproduce → root-cause → TDD fix → verify; berhenti di IJO (ship TERPISAH). Trigger — "fix <x>", "ada bug <x>", "report bug <x>", "perbaiki <x>". Jalankan dari root produk yang punya control/.
---

# fix — Lane Bugfix (konduktor, dua mode)

Tujuan: koreksi perilaku yang **sudah ada** & salah — TANPA menyeret pipeline fitur penuh. `fix` = **KONDUKTOR**; reproduce, root-cause, dan implementasi ditulis subagent (konteks isolasi → sesi `fix` tetap ramping). **Satu mesin, dua pintu:** loop dalam sama; beda hanya entry/artifact/exit.

> Skema (`fix.yaml`, `tasks.yaml`-fix), dispatch deltas (reproduce/root-cause subagent), triage 3-arah + tripwire, drop → `${CLAUDE_PLUGIN_ROOT}/skills/fix/reference.md`. Mesin eksekusi dipinjam `build` → `${CLAUDE_PLUGIN_ROOT}/skills/build/reference.md`.

## Langkah

### 1. Deteksi mode + triage (GATE)
Tentukan target nyangkut apa, lalu pilih mode:

| Target | Mode | Aksi |
|---|---|---|
| 1 fitur `active` (punya `tasks.yaml`, branch hidup) | **in-flight** (§2) | corrective task ke `tasks.yaml` fitur |
| fitur `shipped` | **post-ship** (§3) | `control/fixes/<id>/` |
| TAK nyangkut fitur (bug skeleton `wire`/shared util) | **post-ship** (§3) | `fixes/<id>/`, `relates_to: []`, sensitivity dievaluasi dari nol |
| fitur `draft` (belum `build`, belum ada kode) | **TOLAK** | bukan bug — fitur belum dikerjakan; arahkan lanjut `/feature` |
| DUA fitur (`active` + `shipped`) | **TANYA** | bug di kode yang sedang di-build → in-flight; selain itu post-ship. Konfirmasi, jangan tebak diam-diam |

Lalu **triage guard** (reference §D): **kode salah** (lanjut) / **requirement baru** (STOP → `/feature`) / **doc salah** (koreksi knowledge, gated `critic`). Cek **tripwire** (butuh capability/vendor/unit baru → STOP → `/feature`). **Tiap titik TANYA/konfirmasi ke user (pilih mode bila DUA fitur, triage ambigu, unit-inference §3) ikuti `${CLAUDE_PLUGIN_ROOT}/rules/elicitation.md`: satu keputusan-bercabang per giliran, opsi bawa konsekuensi, jangan tebak diam-diam** (routing tabel mode & triage-guard tetap mekanis — elicitation hanya di momen klarifikasi).

**Visual-defect (sub-tag pada cabang "kode salah").** Bila triage memilih *kode salah* DAN `units` ∈ peran-UI (`fe`/`fullstack`-UI) DAN gejala/root-cause visual (layout/spacing/style/animasi/state-render) → tandai **`visual-defect`** → pintu mockup terbuka (reference §F: bawa/generate/degrade). Bug logika di app UI → tag tak diset (pintu tutup). Ambigu → tanya 1× (`${CLAUDE_PLUGIN_ROOT}/rules/elicitation.md`).

**Debt-aware (utang teknis di area bug).** Saat sudah tahu `units` bug, ikuti `${CLAUDE_PLUGIN_ROOT}/rules/debt-aware.md`: baca `control/debt.yaml`, saring utang `open` (`owner: feature`) di area yang sama — rider pada baca-kode area yang fix sudah lakukan. Tawarkan: *"sekalian beresin N utang di area ini?"*. Yang di-ACC → tambah task `kind: debt, pays_debt: <id>` (refactor, perilaku tetap; skema metadata reference §B) ke `tasks.yaml` work-item ini. Ditolak → biarkan `open`. `fix` tak menulis `control/debt.yaml`.

### 2. Mode in-flight
Konteks: fitur `active`, `tasks.yaml` ada, branch hidup. Bug = task `done` tapi hasil meleset / gap tak ke-cover.
1. **Reproduce (subagent)** — test/snapshot MERAH (reference §C.1).
2. **Root-cause (subagent, `systematic-debugging`)** — akar penyimpangan (reference §C.2).
2.5. **(bila `visual-defect`) Pintu Mockup** — reference §F: bawa/generate/degrade → set `mockup:` pada corrective task (langkah 3). Mockup baru → simpan `control/features/<fitur>/mockups/`; meleset-dari-mockup-existing → re-attach pointer file existing.
3. **Append corrective task** ke `control/features/<fitur>/tasks.yaml` (`kind: fix` + `corrects` + `observed`; skema milestone-wrapped — reference §B).
4. **Eksekusi** — pinjam `build`: ia mem-`pick` task `pending` ini (TDD merah→hijau + review 2-tahap + gate). `fix` panggil `build`; **`build` TIDAK pernah balik panggil `/fix`** (anti-rekursi).
5. **STOP** — ijo → selesai. Fitur **tetap `active`**. TIDAK ada `fixes/<id>/`. `ship` nanti, sekali, untuk seluruh fitur (sesi terpisah).

> Catatan: bila `build` SENDIRI mendeteksi penyimpangan di gate-nya, ia menjalankan disiplin fix **di-embed** (tulis corrective task, lanjut loopnya) — bukan invoke `/fix`. Skill `/fix` ini hanya entry dari LUAR.

### 3. Mode post-ship
Konteks: bug produksi; tak ada branch hidup; fitur `shipped` (atau tanpa-fitur).
1. **Triage + framing** — `severity` (`normal`/`urgent`); `relates_to`+`flow` dgn BACA `business.md`+`flows.md` (BUKAN intake dari nol); **RE-EVALUASI `sensitivity`** vs `invariants.md` (reference §D); `units` via inferensi+konfirmasi (lihat catatan).
2. **Record** — `control/fixes/<YYYY-MM-DD>-<slug>/`: `fix.yaml` (`status: open`, reference §A) + `notes.md` (repro + log).
3. **Reproduce (subagent)** — test regresi MERAH → `notes.md` (reference §C.1).
4. **Root-cause (subagent, `systematic-debugging`)** — isi `root_cause` → `status: diagnosed` (reference §C.2). Bila ungkap doc salah → cabang koreksi knowledge (reference §D.3).
4.5. **(bila `visual-defect`) Pintu Mockup** — reference §F: bawa/generate/degrade → simpan ke `control/fixes/<id>/mockups/` → set `mockup:` pada fix-task (langkah 5). Gate eyeball (jalur generate) = `plan/reference.md §D`.
5. **Tulis fix-task** — `control/fixes/<id>/tasks.yaml` (milestone-wrapped, 1–3 task; reference §B). Lintas-unit → `_shared.md` mini **wajib**.
6. **Eksekusi** — pinjam `build` (work-item `fixes/<id>/`; branch `fix/<id>` per repo): implementer (TDD) + review 2-tahap + gate per unit.
7. **Verify lokal + STOP** — quality (test/lint/typecheck/build) ijo → **STOP, "siap di-`ship`"**. `/ship <fix>` dijalankan TERPISAH (boleh nawarin "lanjut ship?", default STOP). Picu `render-docs` saat status berubah (`open`/`diagnosed`→ Known Issues tampil/ter-update). Reproduksi visual task ber-`mockup:` sudah ter-verifikasi gate segmen `build` (eyeball mockup-vs-render) — **tak ada gate visual baru** di sini.
8. **Drop path** — bukan-bug/wontfix/dup → self-set `status: dropped` + `reason`, folder dikeep (reference §E).

**Unit-inference (bukan fanout penuh):** infer `units` dari `fanout.md` fitur `relates_to` lalu **konfirmasi user**. Ini versi-lemah `fanout` (tak deteksi vendor/unit-kelewat penuh) — bila ternyata nyentuh unit di luar footprint / vendor baru → itu tripwire → `/feature` (reference §D).

## Catatan
- `fix` **tak pernah** auto-`ship` & tak bikin PR — jatah `/ship` (terpisah, eksplisit). `fix` cuma sampai IJO.
- Utang teknis (benar tapi jelek) **bukan** defect → bukan jatah `fix` untuk men-*catat*; itu `control/debt.yaml` (di-capture `build` pintu ke-4, dikelola `/debt`). `fix` hanya **melunasi** utang `open` yang kebetulan satu-area lewat task `kind: debt` (§1 debt-aware) — sibling `kind: fix`.
- BUKAN urusannya: kapabilitas/kontrak/vendor BARU (→ `/feature`); nentuin stack (→ `architect`); bikin PR/`shipped` (→ `ship`).
- Hemat konteks: reproduce + root-cause + implementasi semua di subagent; sesi `fix` cuma nampung kesimpulan + status.
- Perubahan kecil yang BUKAN defect (ganti kebijakan/konstanta) → `/tweak`, bukan `fix`.
