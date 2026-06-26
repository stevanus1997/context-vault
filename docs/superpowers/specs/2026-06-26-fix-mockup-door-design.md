# Design — Pintu Mockup buat `/fix`

**Tanggal:** 2026-06-26
**Status:** Disetujui (siap masuk implementation plan)
**Skill terdampak:** `context-vault:fix` (utama) — `plan`/`build`/`breakdown` TAK disentuh.

---

## 1. Masalah

Mockup adalah warga kelas-satu **hanya** di pipeline fitur: `plan` (slot `Mockup:` 3-jalur + UI-Contract) → `breakdown` (peta mockup→task) → `build` (reproduksi-visual + gate eyeball). Lane `fix` lompat langsung **reproduce → root-cause → tulis fix-task → eksekusi → verify** tanpa jalur mockup sama sekali (`grep` ke `fix/` & `tweak/` = nol untuk `mockup`/`ui-contract`/`visual`/`frontend-design`/`eyeball`).

Akibatnya: bug **visual** (layout kepotong, spacing rusak, state error gak nongol) gak punya pintu buat nyodorin mockup target ke `/fix`, padahal alur fitur bisa.

## 2. Wawasan kunci — gap-nya cuma di sisi authoring

Engine eksekusi sudah **generik** terhadap `mockup:`:

- `build/reference.md §B` (baris 31): task ber-`mockup:` → baca file → **teks** (HTML/CSS) paste verbatim · **gambar** (PNG/JPG) minta subagent buka/lihat · **URL Figma** fetch via Figma MCP → instruksi reproduksi-visual tech-agnostic.
- `build/SKILL.md:34`: task `kind: fix` "diperlakukan seperti task biasa — `kind`/`corrects`/`observed` adalah **metadata traceability**, tidak mengubah dispatch." Penanganan `mockup:` **per-field, kind-agnostic**.
- `build/SKILL.md:50`: gate segmen sudah **eyeball render UI vs mockup** untuk task ber-`mockup:`.
- `build/reference.md §C/§D`: task ber-`mockup:` otomatis **bobot 3 (berat)** + **model terkuat**.

**Konsekuensi:** kalau fix-task membawa field `mockup:`, eksekusi + verifikasi visual + bobot + pilihan model **datang GRATIS** lewat engine yang `fix` sudah pinjam (`fix/reference.md:3`). Yang perlu dibangun **hanya sisi authoring** — pintu yang menghasilkan field `mockup:` di fix-task.

## 3. Keputusan desain (terkunci)

| # | Keputusan | Pilihan |
|---|---|---|
| 1 | Cakupan mode | **Dua-duanya** — post-ship (intake penuh) + in-flight (re-attach) |
| 2 | Jalur intake | **Bawa + generate + degrade** (paritas penuh dengan `plan`) |
| 3 | Trigger | **Auto-deteksi + konfirmasi** (unit UI ∧ gejala/root-cause visual) |
| 4 | Sumber UI-Contract | **Reuse read-only** dari `plans/<app>.md`; `fix` tak pernah menulis UI-Contract |
| 5 | Cara bangun | **Pinjam `plan` by-reference** (`plan/reference.md §B–§E`) + tulis hanya delta fix |

## 4. Arsitektur

### 4.1 Trigger — tag `visual-defect` pada cabang "kode salah"

Nempel sebagai **tag pada outcome "kode salah"** di triage guard (`fix/SKILL.md:25`, `fix/reference.md §D`) — **bukan** outcome ke-4; triage 3-arah (kode salah / requirement baru / doc salah) tetap utuh. Setelah triage memilih "kode salah" dan `units` diketahui:

- unit ∈ peran-UI (`fe` / `fullstack`-UI per `workspace.yaml`) **DAN** gejala/root-cause bersifat visual (layout · spacing · style · animasi · state-render tak muncul) → set tag **`visual-defect`** → pintu mockup tersedia.
- Ambigu → tanya 1× mengikuti `rules/elicitation.md` (satu keputusan-bercabang per giliran).
- Bug logika di app UI (mis. perhitungan salah di `fullstack`) → pintu **tetap tutup** (tag tidak diset).

### 4.2 Mekanik 3-jalur — pinjam `plan` by-reference

Section baru **`fix/reference.md §F` ("Pintu Mockup — defect visual")** menunjuk `plan/reference.md §B–§E` untuk mekanik **bawa / generate / degrade + cross-check + round-trip** (persis pola "Mesin eksekusi dipinjam build" di `fix/reference.md:3`), lalu menulis **HANYA delta fix**:

**Delta A — UI-Contract (read-only):**
- Reuse dari `control/features/<fitur>/plans/<app>.md` (persist setelah ship). `fix` **TAK PERNAH** menulis UI-Contract — `plan` tetap pemilik tunggal (jaga single-writer).
- Absen (fitur lama ambil jalur degrade / bug tanpa-fitur `relates_to: []`) **dan** user pilih **generate** → turunkan UI-Contract **sekali-pakai inline** semata sebagai input generate; **jangan dipersist**.
- Absen **dan** user pilih **bawa** → cross-check turun jadi **murni konfirmasi-manusia** (`plan/reference.md §C` jalur non-teks).

**Delta B — lokasi simpan mockup:**
- post-ship (bawa/generate) → `control/fixes/<id>/mockups/` (artifact milik fix, sejajar `fix.yaml`/`notes.md`).
- in-flight, bawa mockup **baru** → `control/features/<fitur>/mockups/` (in-flight memang menulis ke folder fitur).
- in-flight, **re-attach** mockup existing → set `mockup:` menunjuk file existing di `control/features/<fitur>/mockups/<file>` (read-only, **tanpa menyalin**).

**Delta C — output:** set pointer `mockup:` pada fix-task (lihat §4.4).

### 4.3 Guard anti-backdoor

Cross-check (`plan/reference.md §C`) bukan sekadar cek coverage — ia **early-warning**. Bila mockup yang dibawa/digenerate memperkenalkan **field/action/state BARU** yang tak ada di UI-Contract → itu sinyal **requirement baru**, bukan defect → kena **tripwire existing** (`fix/reference.md §D`: butuh capability/unit/vendor baru → STOP → `/feature`). Pintu mockup **tidak boleh** menjadi pintu belakang menambah scope UI.

### 4.4 Skema fix-task

`fix/reference.md §B` menambah field **opsional** `mockup:` ke skema fix-task (cermin `breakdown`/`plan`):

```yaml
- id: fix-<slug>
  kind: fix
  corrects: <id-task-asal>
  observed: "<apa yang menyimpang>"
  unit: <app/pkg>
  files: [ ... ]
  approach: "reproduce dulu (<test>), baru perbaiki"
  test: ["<kasus regresi>"]
  mockup: <path ke mockups/ ATAU kosong>   # BARU — opsional, hanya saat visual-defect
  deps: []
  status: pending
```

`build` sudah menelan `mockup:` secara generik + memperlakukan `kind: fix` sebagai metadata → **nol perubahan `build`**.

## 5. Alur (penempatan di `fix/SKILL.md`)

**§1 Triage:** tambah satu baris sub-klasifikasi `visual-defect` (+ pointer ke §F) pada cabang "kode salah".

**§2 Mode in-flight** — sisip **langkah 2.5** antara root-cause (langkah 2) dan append corrective task (langkah 3):
> 2.5 (bila `visual-defect`) Pintu Mockup (§F) → set `mockup:` pada corrective task.

**§3 Mode post-ship** — sisip **langkah 4.5** antara root-cause (langkah 4) dan tulis fix-task (langkah 5):
> 4.5 (bila `visual-defect`) Pintu Mockup (§F) → set `mockup:` pada fix-task. Gate eyeball (jalur generate) = sama `plan/reference.md §D`.

**§3 langkah 7 (verify):** catat reproduksi visual sudah ter-cover gate segmen `build` (`build/SKILL.md:50`) — **tak ada gate baru**.

**`plan`:** TAK disentuh (by design — pinjam by-reference).

## 6. Error handling & edge cases

- **Mockup non-teks tanpa Figma MCP** → engine `build` sudah handle (perlakukan sebagai gambar/screenshot). Nol kerja baru.
- **`plans/<app>.md` absen** (bug tanpa-fitur / fitur lama) → §4.2 Delta A fallback (throwaway-derive untuk generate; pure-confirm untuk bawa).
- **Re-attach menunjuk file mockup yang sudah dihapus** → palang fidelitas path (sejajar cek path `breakdown`) saat menulis fix-task; mismatch → minta koreksi.
- **User pilih degrade** → `mockup:` kosong, perilaku fix sekarang (nol regresi).
- **Interupsi/resume** → fix sudah resumable lewat `build`; mockup tersimpan di disk (`mockups/`) jadi tahan sesi-fresh, persis alasan `plan`/`design-system` mempersist verbatim.

## 7. Validasi (eval scenario — ini spec-prompt, bukan kode)

1. **Post-ship + bawa:** app web shipped, "tombol checkout kepotong di mobile", user serahkan mockup HTML → fix-task ber-`mockup:` di `fixes/<id>/mockups/`, `build` reproduksi + eyeball. ✅
2. **In-flight + re-attach:** hasil `build` meleset dari mockup existing → corrective task carry `mockup:` menunjuk file existing, nol authoring baru. ✅
3. **Bug logika di app UI:** "total diskon salah" di app `fullstack` → tag `visual-defect` tak diset → pintu **tetap tutup**. ✅
4. **Backdoor scope:** mockup bawaan punya field "kupon" yang tak ada di UI-Contract → cross-check menandai → tripwire → STOP → `/feature`. ✅
5. **Generate tanpa UI-Contract:** bug tanpa-fitur, user pilih generate → UI-Contract throwaway inline → `frontend-design` dispatch → mockup-reference → gate eyeball. ✅

## 8. Blast radius

- **Diubah:** `plugin/skills/fix/reference.md` (skema §B + section §F baru) · `plugin/skills/fix/SKILL.md` (3 sisipan kecil: triage tag + langkah 2.5 + langkah 4.5 + catatan verify).
- **Tak disentuh:** `plan`, `build`, `breakdown`, `design-system`, `tweak`.
- **Gratis (pinjam engine):** eksekusi visual, gate eyeball, bobot-3, model terkuat — semua dari `build`.
