# context-vault — Design Fidelity di Pipeline (`mockup-thread`) — Design Spec

- **Tanggal:** 2026-06-04
- **Status:** Draft disetujui untuk masuk tahap perencanaan implementasi (hasil brainstorming, semua keputusan perilaku terkunci)
- **Terkait:** spec induk `docs/superpowers/specs/2026-05-24-ai-first-boilerplate-design.md` (§4 just-in-time knowledge + "satu sumber kebenaran banyak proyeksi", §9 skill `plan`/`breakdown`/`build`, §12 lifecycle); `plugin/skills/plan/SKILL.md` (fase teknis per-app — tempat CAPTURE dipasang); `plugin/skills/breakdown/SKILL.md` + `plugin/skills/breakdown/reference.md` (skema `tasks.yaml` — tempat THREAD); `plugin/skills/build/SKILL.md` + `plugin/skills/build/reference.md` (dispatch implementer §B + pilih-model §C + gate §6 — tempat DISPATCH + eyeball); pola opsional-degrade-ke-noop `actions:`/`manual:`/`kind:` (`breakdown/reference.md` §A & §D) yang **ditiru** `mockup:`.
- **Asal:** test end-to-end pengguna (project board game). Pengguna merancang UI lewat "Claude design", men-generate mockup HTML+CSS, lalu handoff ke Claude Code via `/feature`. Hasil `/build`: **layout beda total, animasi hilang**, walau komponen aman (design system sudah ada di kode). Tiap fitur UI menuntut satu ronde `/fix` manual → kerja dobel, boros token. Akar-masalah diverifikasi lewat workflow 11-agent (4 lensa adversarial, **refuted 0/4**).
- **Grounding:** empat lensa verifikasi terhadap file nyata semua mengonfirmasi gap (tak ada satu pun yang ter-refute). **(capture)** tak ada field/artifact di `feature.yaml`/`business.md`/`fanout.md`/`workspace.yaml`/`plans/*` yang menampung mockup UI; `intake` eksplisit melarang Q&A teknis. **(threading)** `plans/<app>.md` cuma `Model/Schema·API/Komponen·Lokasi·Test` (Komponen = identitas, bukan tampilan); `tasks.yaml` `files/approach/test` "TANPA kode" — nol pixel. **(dispatch)** prompt implementer (`build/reference.md` §B) = `desc+files+approach+test+_shared+conventions+stack+pointer-pola+signature-dep+instruksi`; mockup BUKAN salah satunya; "pointer pola" menunjuk file KODE existing (contoh: "route sejenis"), bukan mockup. **(verify)** dua reviewer (`critic`/`security-critic`, tools `Read/Grep/Glob`) struktural buta-render; gate §6 membanding "dibangun vs task" (prosa), bukan "render vs mockup"; `test` = asersi TDD fungsional.

---

## 1. Ringkasan

Mockup UI yang pengguna serahkan **tidak punya rumah di mana pun** sepanjang pipeline `feature → plan → breakdown → build`. Akibatnya `build` merekonstruksi UI dari prosa `approach` 1–2 baris + kasus `test` fungsional — bukan dari mockup, yang tak pernah ia lihat. Dua hal yang **hanya hidup di mockup** dan tak ada di kode — **komposisi layout halaman** + **animasi/transisi** — selalu hilang; yang **sudah ada di kode** (design system + komponen) selamat karena `build` membaca kode existing lewat "pointer pola". Drift lolos semua gate (test fungsional ijo, dua reviewer buta-render, gate membanding prosa) sampai **manusia** membuka app → memanggil `/fix`. Satu ronde `/fix` per fitur UI.

Spec ini menambah **jalur tipis end-to-end untuk mockup** sebagai **byte opaque**:
- **CAPTURE** (`plan`): mockup (format apa pun) disimpan verbatim ke artifact baru `control/features/<f>/mockups/`, dirujuk dengan pointer `Mockup:` di `plans/<app>.md`.
- **THREAD** (`breakdown`): task UI membawa key opsional `mockup: <path>`; **coverage check** memastikan tiap mockup yang dirujuk plan ke-map ke ≥1 task.
- **DISPATCH** (`build`): implementer menerima **isi/pointer mockup** + instruksi **tech-agnostic** — reproduksi *hasil visual* (layout/spacing/hierarki/animasi) memakai stack & komponen project, **jangan transplant markup mentah**; task ber-`mockup:` = "judgment desain" → model terkuat.
- **EYEBALL** (`build` gate §6): satu item challenge-checklist baru — "render UI cocok mockup (layout + animasi)?" di gate yang **sudah ada**.

Prinsip inti: **mockup ditangkap sebagai byte opaque, di-thread tak-berubah, diterjemahkan ke idiom project oleh implementer — bukan ditiru mentah, bukan diprosa-kan.**

## 2. Masalah

- **M1 — Capture: nol slot.** Tak ada field/pertanyaan/artifact yang menampung mockup UI. `feature.yaml` hanya `name/status/created/sensitivity`; `business.md` lima slot prosa bisnis; `intake` **melarang** Q&A teknis (`intake/SKILL.md`). Mockup yang di-paste di chat `/feature` **menguap** — tak pernah ditulis ke file `control/`.
- **M2 — Cross-session killer.** Pipeline sengaja jalan per-fase, **resumable lewat artifact `control/`**. `/build` adalah sesi fresh yang hanya membaca `tasks.yaml` + `plans/*` + `conventions.md`. Apa pun yang tak ditulis ke `control/` **hilang antar-sesi**. Maka `build` tak pernah punya akses ke mockup — bahkan secara prinsip.
- **M3 — Threading: pixel terbuang by-design.** `plans/<app>.md` = `Model/Schema·API/Komponen·Lokasi·Test`; `tasks.yaml` = `files`(path)+`approach`(1–2 baris)+`test`(kasus), eksplisit "TANPA kode". Tak ada field yang bisa membawa layout/spacing/warna/tipografi/motion.
- **M4 — Dispatch: implementer merekonstruksi dari prosa.** Prompt implementer tak memuat mockup. "Pointer pola" menunjuk **file kode existing** sebagai contoh gaya — itu sebabnya **komponen aman** (design system di kode → ditiru benar) tapi **layout & animasi** (hanya di mockup) **hilang total**.
- **M5 — Verify: drift lolos senyap.** Reviewer (`critic`/`security-critic`) hanya `Read/Grep/Glob` (buta-render); gate §6 membanding "dibangun vs task" (prosa task), bukan "render vs mockup"; `test` = fungsional. Mismatch baru ketahuan saat manusia membuka app → `/fix` manual = kerja dobel + boros token.

Akar: pipeline murni **perilaku + data**. Mockup — spec visual terkaya & terpresisi yang dimiliki pengguna — dibuang di gate pertama dan direkonstruksi jadi parafrase prosa yang lossy.

## 3. Tujuan & Non-Tujuan

**Tujuan:**
- **Artifact `control/features/<f>/mockups/`** (§4): rumah durable mockup, format apa pun, byte opaque.
- **CAPTURE di `plan`** (§5): simpan mockup verbatim + pointer `Mockup:` di `plans/<app>.md`; minta mockup bila `/plan` standalone & app UI tapi belum tersimpan.
- **THREAD di `breakdown`** (§6): key opsional `mockup:` di task + **coverage check** (tiap mockup yang dirujuk → ≥1 task).
- **DISPATCH + EYEBALL di `build`** (§7): implementer menerima isi/pointer mockup + instruksi reproduksi-hasil tech-agnostic; model terkuat untuk task ber-`mockup:`; satu item eyeball di gate §6 yang sudah ada.
- **Generik & degrade-ke-noop** (§8–§9): mockup = byte opaque (plugin tak pernah menulis CSS / mengasumsi framework); semua field opsional → fitur non-UI/backend-only nol biaya.

**Non-Tujuan (Spec A — diserahkan ke Spec B / iterasi lain):**
- **Bukan design-system bring-up greenfield.** Project dari-0 (komponen belum ada → tak ada yang ditunjuk pointer-pola) = **Spec B** (`design-system bring-up`: tokens + komponen primitif dari mockup, `control/design-system.md`, motion token). Spec A mengasumsikan komponen sudah ada di kode (steady-state) ATAU implementer membangun ad-hoc dari mockup.
- **Bukan verify render-compare otomatis.** Tak ada subagent render→screenshot→diff, tak ada agent `design-critic`. Verifikasi = **eyeball manusia di gate §6 yang sudah ada**. (Alasan: animasi menolak verifikasi screenshot; komponen pengguna sudah aman → eyeball cukup.)
- **Bukan mekanisme region/anchor formal.** `mockup:` = pointer **path** ke file; layar mana = dari `desc` task; banyak task boleh berbagi satu file. Tak ada `#anchor`.
- **`feature`/`intake`/`fanout`/`workspace.yaml` TIDAK disentuh.** Deteksi permukaan-UI di `fanout` + auto-prompt di `feature` = kandidat Spec B; Spec A menaruh capture sepenuhnya di `plan`.
- **Bukan parse mockup.** Plugin tak pernah membaca/mem-validasi isi mockup; ia byte opaque yang di-paste/dilampirkan apa adanya.

## 4. Artifact: `control/features/<f>/mockups/`

- **Lokasi:** `control/features/<fitur>/mockups/` (sejajar `plans/`, `business.md`, `fanout.md`, `tasks.yaml`).
- **Isi:** satu atau lebih file mockup yang diserahkan pengguna, **format apa pun** — `.html`, `.css`, `.png`/`.jpg` (screenshot), folder, atau catatan berisi URL Figma. Pengguna mengorganisir bebas (per-layar atau satu file gabungan berisi banyak layar).
- **Sifat:** **byte opaque.** Plugin tak pernah parse, edit, atau mengasumsi teknologinya. Disimpan **verbatim**.
- **Penulis:** `plan` (CAPTURE, §5). Pembaca: `build` (DISPATCH, §7). `breakdown` hanya meneruskan pointer (path), tak membaca isi.
- **Tidak ada** bila fitur tak punya permukaan UI atau pengguna tak menyerahkan mockup — folder tak dibuat; seluruh jalur dorman.

## 5. CAPTURE — di `plan`

Mockup ditangkap di fase **teknis** (`plan`) — fase yang memang memutuskan komponen/layout per-app dan, dalam satu run `/feature` (yang menjalankan `intake→fanout→plan` satu sesi), masih memegang mockup di context.

### 5.1 Baca (step 1)
`plan` step "Baca input" **mengecek keberadaan** `control/features/<f>/mockups/` (di samping input existing) — sekadar tahu app mana sudah punya mockup. `plan` **tidak mem-parse isi** mockup (isi diserahkan ke `build`); penyimpanan file dilakukan di step 3 (§5.2).

### 5.2 Simpan + minta (step 3, per app)
Saat memproses app yang punya **permukaan UI**:
- Bila pengguna menyerahkan mockup (HTML/CSS/gambar/URL Figma) untuk app ini → **simpan verbatim** ke `control/features/<f>/mockups/` (format apa pun; **JANGAN** inline ke plan, **JANGAN** diprosa-kan jadi deskripsi), catat path-nya.
- Bila `/plan` dijalankan **standalone** & app punya UI tapi **belum ada mockup tersimpan** → **minta** mockup ke pengguna dulu (jangan jalan diam-diam tanpa). Bila pengguna sengaja tak punya mockup (mis. UI akan dibangun ad-hoc) → lanjut tanpa `Mockup:` (degrade ke perilaku sekarang).

### 5.3 Pointer (step 4, template `plans/<app>.md`)
Tambah satu slot **opsional** ke template output:
```
# <app>
Model/Schema : <...>
API/Komponen : <...>
Lokasi       : <path konkret di app>
Mockup       : <path(s) ke control/features/<f>/mockups/… ATAU kosong>
Test         : <...>
```
`->` (atau baris dihilangkan) = tak ada mockup. `plan` tetap **FLAT** — `Mockup:` adalah **pointer**, bukan prosa visual.

## 6. THREAD — di `breakdown`

### 6.1 Skema task (`reference.md` §A)
Tambah satu key **opsional** ke entri task, sebagai sub-key (BUKAN renumber field lain):
```yaml
        mockup: <path>             # OPSIONAL — pointer file mockup UI (dari plans/<app>.md "Mockup:");
                                   #   build mem-paste/melampirkan VERBATIM ke prompt implementer
```
Aturan (`reference.md` §D, bullet baru): task UI yang `plans/<app>.md`-nya memuat `Mockup:` membawa `mockup:` ke task. **Banyak task boleh berbagi satu path** (satu file mockup berisi banyak layar); **layar mana** ditentukan dari `desc` task — tak ada mekanisme region. `mockup:` adalah metadata seperti `kind:`/`actions:` — **dipertahankan** saat re-breakdown bila plan tak berubah.

### 6.2 Coverage check (`SKILL.md` step 4)
Tambah satu baris ke coverage check existing:
- **UI coverage:** tiap file mockup yang dirujuk `plans/<app>.md` (baris `Mockup:`) **WAJIB** ke-map ke ≥1 task ber-`mockup:`. Tampilkan **peta mockup→task** di gate (di samping peta plan→task existing).

## 7. DISPATCH + EYEBALL — di `build`

### 7.1 Isi prompt implementer (`reference.md` §B)
Tambah satu bullet **setelah** "Pointer pola":
- **Mockup (bila task ber-`mockup:`):** baca file di path → **teks** (HTML/CSS) di-**paste VERBATIM**; **gambar** (PNG/JPG) → sertakan path & minta subagent **membuka/melihat**-nya; **URL Figma** → fetch via Figma MCP bila tersedia, kalau tidak → perlakukan sebagai screenshot/gambar. **Instruksi (tech-agnostic):** *"Reproduksi HASIL VISUAL — layout, spacing, hierarki, dan animasi/transisi — memakai stack app (`workspace.yaml`) + komponen pada file 'pointer pola'. JANGAN transplant markup mentah mockup; terjemahkan ke idiom komponen project. BAWA transisi/animasi yang ada di mockup — jangan dibuang sebagai dekoratif."*

### 7.2 Pilih model (`reference.md` §C)
Tambah: task ber-`mockup:` membutuhkan **judgment desain** (menerjemahkan mockup-tech ≠ project-tech ke komponen existing) → pilih **model paling kuat**.

### 7.3 Rakit prompt (`SKILL.md` step 3)
Tambah ke daftar prompt LENGKAP: `+ (bila task ber-mockup:) isi/pointer file mockup + instruksi reproduksi-visual` (rujuk `reference.md` §B).

### 7.4 Eyeball di gate (`SKILL.md` step 6, challenge checklist)
Tambah satu item ke challenge-checklist gate yang **sudah ada**:
- **task ber-`mockup:`:** hasil render UI cocok dengan mockup (layout + animasi)? (eyeball + buka app)

Ini menumpang gate `build` yang sudah meminta pengguna meng-approve diff — tak ada gate baru.

## 8. Prinsip generik (jangan dilanggar)

- **Mockup = byte opaque user.** Plugin tak pernah menulis CSS, tak pernah mengasumsi framework/CSS-lib. Stack dibaca dari `workspace.yaml`.
- **Reproduksi hasil, jangan transplant markup.** Satu kalimat ini membuat semua format seragam: Claude-design HTML, CSS biasa, export Figma (yang justru WAJIB tak ditiru mentah karena div absolute-position), screenshot — semua jadi "tiru tampilannya, bangun pakai komponen project". Ini juga melindungi design-system existing dari di-bypass.
- **Percabangan format hanya di SATU titik:** `build` dispatch (§7.1) — teks vs gambar vs URL. Capture (§5) & thread (§6) buta-format (pointer path).
- **Translasi sandar pada yang sudah ada:** `conventions.md` + `stack` + "pointer pola" (file komponen NYATA). Tak ada slot "pendekatan desain" baru di Spec A.

## 9. Edge case & degrade-ke-noop

- **Tak ada mockup / fitur non-UI / app backend-only / package** → `mockup:` & `Mockup:` absen; folder `mockups/` tak ada; seluruh jalur **dorman, nol biaya** (opsional di setiap titik, persis `actions:`/`manual:`/`kind:`).
- **`/plan` standalone tanpa mockup tersimpan & app UI** → `plan` minta dulu (§5.2); jangan jalan diam-diam.
- **mockup-tech ≠ project-tech** → instruksi "reproduksi hasil, jangan transplant" + pointer-pola komponen nyata (§7.1/§8).
- **Greenfield (komponen belum ada)** → di luar scope; pointer-pola tak punya yang ditunjuk → implementer membangun ad-hoc dari mockup (lebih baik dari nol referensi, tapi konsistensi lintas-fitur = urusan **Spec B**).
- **Animasi** → ke-carry via paste verbatim + instruksi eksplisit "bawa animasi"; di-verify **eyeball** (§7.4). Tak ada cek otomatis (screenshot buta-motion).
- **Re-breakdown** (`breakdown` SKILL.md §7) → `mockup:` bagian definisi task dari plan; dipertahankan seperti field lain saat plan tak berubah.
- **Banyak layar dalam satu file mockup** → banyak task berbagi `mockup:` path; `desc` membedakan layar (§6.1).

## 10. Edit-map persis (5 file, nol file/skill/agent baru)

> Anchor di bawah dikutip dari current-state; `writing-plans` memverifikasi verbatim ke disk sebelum commit. Semua perubahan **additif**; tak ada renumber heading/step/list.

1. **`plugin/skills/plan/SKILL.md`**
   - **Step 1 ("Baca input"):** sisipkan `control/features/<fitur>/mockups/` (bila ada) ke daftar baca.
   - **Step 3 ("Per app"):** tambah klausa CAPTURE (§5.2) — simpan mockup verbatim ke `mockups/` bila app UI & user menyerahkannya; minta bila standalone & belum ada.
   - **Step 4 (template `plans/<app>.md`):** sisipkan baris `Mockup       : <path… ATAU kosong>` antara `Lokasi` dan `Test` (slot opsional, §5.3).
   - **Catatan:** tambah satu kalimat — `plan` tetap flat; mockup = pointer, bukan prosa.

2. **`plugin/skills/breakdown/reference.md`**
   - **§A skema:** tambah key opsional `mockup: <path>` (sub-key task, komentar inline — §6.1). Letakkan dekat `actions:`/`manual:` agar pola "opsional metadata" konsisten; **bukan** mengubah `files/approach/test/deps/status`.
   - **§D:** tambah bullet — aturan thread `mockup:` (dari `plans` "Mockup:" → task; banyak task share path; layar dari `desc`; dipertahankan saat re-breakdown).

3. **`plugin/skills/breakdown/SKILL.md`**
   - **Step 4 ("Coverage check + task integrasi"):** tambah satu sub-bullet "UI coverage" (§6.2) + sebut "peta mockup→task" di gate.

4. **`plugin/skills/build/reference.md`**
   - **§B (isi prompt implementer):** tambah bullet "Mockup (bila task ber-`mockup:`)" **setelah** "Pointer pola" (§7.1).
   - **§C (Pilih model):** tambah baris — task ber-`mockup:` = judgment desain → model terkuat (§7.2).

5. **`plugin/skills/build/SKILL.md`**
   - **Step 3 ("Dispatch"):** tambah ke daftar prompt LENGKAP — isi/pointer mockup + instruksi reproduksi-visual, rujuk `reference.md` §B (§7.3).
   - **Step 6 ("Gate per segmen", challenge checklist):** tambah item eyeball "task ber-`mockup:`: render cocok mockup (layout+animasi)?" (§7.4).

## 11. Verifikasi & bug-guard

**Verifikasi implementasi** (ini edit dokumen-skill, bukan kode → "test" = grep-battery + coherence):
- `mockup:`/`Mockup:` muncul konsisten di 5 titik: plan template + plan step-3 klausa, breakdown schema §A, breakdown coverage §4, build dispatch §B + SKILL step-3, build gate §6.
- Instruksi dispatch §7.1 **tech-agnostic** & memuat frasa "jangan transplant markup" + "bawa animasi".
- Sifat **opsional-degrade-ke-noop** terbaca di tiap titik (tak ada yang mewajibkan `mockup:`).
- Tiap pointer silang ("rujuk §B/§C/§4") menunjuk seksi yang benar (cek anti-mis-aimed-pointer).
- **Validasi nyata** (post-merge): jalankan satu fitur UI end-to-end → ronde `/fix` hilang/menyusut.

**Bug-guard di-prebake** (pelajaran berulang dari riwayat eksekusi):
- `mockup:` ditambah sebagai **sub-key / baris baru**, **BUKAN** renumber list field.
- `build/SKILL.md` + `breakdown/SKILL.md`: edit **in-place** pada step existing; **JANGAN** renumber step (pakai sisipan sub-bullet / kalimat, bukan langkah baru).
- **Nol** frontmatter/skill/agent baru → **nol** staleness skill-count, **nol** risiko colon-space frontmatter, **nol** update `plugin.json`/`marketplace.json`/`README`/spec-induk §17.
- Grep verifikasi pakai **single-quote** untuk pola berisi backtick.
- Verifikasi setiap "reference §X" menunjuk seksi yang **menyimpan** kontennya — trap mis-aimed-pointer yang lolos verify sesi-eksekusi berkali-kali; baca fresh di sesi terpisah.

## 12. Hubungan ke Spec B (`design-system bring-up`)

Spec A = **atom universal**: kemampuan "implementer melihat mockup & mereproduksinya dengan stack project". **Spec B dibangun DI ATAS Spec A** — fase fondasional (skill baru atau `wire` mode-design) yang, untuk project dari-0, menurunkan mockup awal jadi (a) `control/design-system.md` durable (tokens warna/type/spacing + **motion vocab** + inventory komponen + pointer mockup kanonik) dan (b) kode tokens + komponen primitif (di `ui-kit`/app) — **memakai mekanisme dispatch Spec A**. Setelah Spec B jalan, project dari-0 masuk ke steady-state (komponen di kode) tempat Spec A menangani layout+animasi per-fitur. **Urutan: Spec A dulu** (universal, additif), Spec B menyusul sebagai Langkah terpisah.
