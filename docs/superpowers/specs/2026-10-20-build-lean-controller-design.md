# Desain — controller `build` ramping (context awal kecil, nggak numpuk per task)

**Tanggal:** 2026-10-20
**Status:** Draft → review user
**Scope:** `plugin/skills/build/` (SKILL.md + pecah `reference.md`) · agent baru `plugin/agents/brief-writer.md` · `plugin/template/.claude/build_status.py` (format output baru) · `plugin/template/.claude/settings.json` (allowlist) · `plugin/skills/ship/SKILL.md` (baca titipan `ship`) · `plugin/skills/upgrade/SKILL.md` (susulin) · rujukan silang (`template/control/conventions.md`, `rules/ask-user.md`, `guide/`) · test (`tools/tests/*`, `plugin/hooks/tests/*`) · `tools/build-kimi.sh` + regen `plugin-kimi/` · alat ukur baru `tools/measure-build-context.py` · `plugin.json` versi 0.28.0

---

## 1. Masalah

Tiap `/context-vault:build` jalan, context sesi controller langsung gede dan terus numpuk per task. Kata user: "langsung makan context sampai 170K".

Diukur dari **42 sesi build** di produk mahjong (transcript `~/.claude/projects/-Users-mac-098506-Developer-project-mahjong/*.jsonl`):

| Angka | Nilai |
|---|---|
| Median context saat dispatch implementer PERTAMA | **181.5K** (rentang 109K–252K) |
| Median pertumbuhan context per dispatch implementer | **~30K** |
| Rasio dispatch reviewer / implementer | 1.0 |

Dari mana asalnya (sesi `851eddc2`, `77291987`, `9a7ff9b9`, `5c38a3f9`, `c7c7cfe6`, dibagi per jenis hasil tool):

| Komponen | Kira-kira | Sebab |
|---|---|---|
| Baseline sesi sebelum skill jalan | ~55–60K | system prompt, tools, listing skill semua plugin, hook. **Di luar scope** (§5). |
| `SKILL.md` build | ~14K | 43.5K karakter, kebaca semua saat skill dipanggil |
| `reference.md` | ~15–20K | SKILL.md:12 "baca itu dulu" → 50KB kebaca semua, kadang 2× |
| Baca state | ~37K **tiap sesi** (paling konsisten) | grep/sed potongan `tasks.yaml` (150KB di venue-tables), `plans/*` (~140KB), `_carry-notes.md` (76KB), `_rules-*`, `last-run.md`, `workspace.yaml`, memory |
| Baca kode buat rakit brief | ~11–65K per sesi, **berulang per task** | Step 3 + reference §B nyuruh controller sendiri baca file dep, slice skema, mockup, migrasi. Di `851eddc2`: 128K → 193K cuma buat nulis brief T50. |
| Baca template superpowers | ~5–15K | controller `cat` `implementer-prompt.md` / `task-reviewer-prompt.md` |
| Baca laporan reviewer | ~3–12K per task | reviewer balikin laporan panjang, controller sed potongannya |

Ini bertentangan sama tujuan skill-nya sendiri (SKILL.md:10: "konteks isolasi → sesi build tetap ramping & resumable").

### 1.1 Tiga file tak resmi yang ternyata dipakai

Di produk mahjong, model controller bikin tiga file sendiri di `.claude/build/<fitur>/`. Nggak ada satu pun di spec atau git history plugin.

- **`_rules-<repo>.md`** (pertama 2026-10-06, sesi `7112a599`). Aturan yang sama buat semua task di satu repo: stack, pointer konvensi, TDD, aturan migrasi lokal-only, "jangan baca tasks.yaml". Brief merujuk ke sini. Implementer dan reviewer membacanya.
- **`_carry-notes.md`** (sesi yang sama). **Titipan antar-task**: temuan pre-flight yang harus masuk ke brief task tertentu, temuan reviewer yang wajib diikuti task berikutnya ("Titipan T75: …"), agenda gate, catatan buat ship dan simplify, kandidat debt. File ini cuma ditambah terus, nggak pernah dibersihin. Di venue-tables isinya 193 baris (76KB), cuma 34 baris (~18KB) yang masih nyebut task yang belum `done`. Tiap sesi baru baca ulang.
- **`_review-instructions.md`** (2026-10-14, sesi `9a7ff9b9`). Versi ringkas template reviewer superpowers, ditambah aturan "baca diff sekali, buka kode di luar diff hanya untuk risiko konkret yang disebut".

User konfirmasi ketiganya diresmikan, bukan dibuang.

## 2. Hasil yang diharapkan

1. Context controller saat dispatch implementer pertama turun ke **≤ 95K median** (dari 181.5K).
2. Pertumbuhan context per task turun ke **≤ 10K median** (dari ~30K). Controller cuma nampung status ringkas, verdict ringkas, dan hasil cek deterministik.
3. Controller **tetap paham keseluruhan** task yang diorkestrasi: tetap bisa nyambungin temuan ke task lain, menilai gate, jawab pertanyaan implementer, dan ngobrol soal progres (§4.2).
4. Kualitas nggak turun (§4.10): ronde review per task, NEEDS_CONTEXT per task, dan task `blocked` nggak lebih buruk dari baseline.
5. Tiga file tak resmi (§1.1) jadi mekanisme resmi yang terdokumentasi.

## 3. Keputusan desain

| # | Keputusan | Asal |
|---|---|---|
| D1 | Scope = brief-writer subagent + `reference.md` lazy per section + ringkasan state lewat script + template superpowers by-path + verdict reviewer ringkas. Mirror ke Kimi lewat regen. | user (pilih dari 3 opsi) |
| D2 | Memisahkan cabang unattended di SKILL.md jadi file tersendiri → **ditunda**, spec terpisah. Hematnya paling kecil (~5–8K), risiko regresinya paling tinggi (teks hasil amandemen 2026-08-27/28 berkali-kali). | rekomendasi, user setuju |
| D3 | `_rules-<repo>.md`, `_carry-notes.md`, `_review-instructions.md` **diresmikan**, bukan dibuang. | user ("aman") |
| D4 | Controller tetap memegang **peta** (1 baris per task, selalu dimuat). Yang dipangkas cuma kode mentah dan baca-ulang file. Detail dibaca saat dibutuhkan. | rekomendasi menjawab kekhawatiran user "controller jadi bego?"; user ikut |
| D5 | Brief-writer pakai **model yang sama dengan controller** (`model: inherit`), bukan model murah. Kualitas brief itu yang selama ini dijaga controller. | rekomendasi, user ikut |
| D6 | Aturan baru: keputusan yang ngaruh ke task lain **wajib** dicatat ke `carry.yaml` sebelum dispatch berikutnya. | rekomendasi, user ikut |
| D7 | Titipan pindah ke `<work-item>/carry.yaml` di `control/` (ikut ke-commit), bukan scratch `.claude/build/` yang di-gitignore. Ini state yang dibutuhin buat resume, setara `tasks.yaml`/`gates.yaml`. | rekomendasi, user ikut |
| D8 | Ringkasan state = **format output baru di `build_status.py`** yang sudah ada (stdlib-only, sudah ke-copy ke tiap produk lewat init/upgrade, sudah punya parser YAML). Bukan script baru. | keputusan desainer |
| D9 | Pengaman kualitas: ukur sebelum vs sesudah pakai alat ukur yang di-commit (`tools/measure-build-context.py`). | rekomendasi, user ikut |
| D10 | Target titipan `debt` **tidak** dipakai. Kandidat debt tetap langsung APPEND ke `control/debt.yaml` lewat pintu ke-4 (aturan yang sudah ada). Di carry-notes lama, kandidat debt adalah duplikasi. | keputusan desainer |
| D11 | Drift superpowers sejak 6.2.0 (audit terakhir repo ini = 6.1). Di rilis ini **hanya bug-nya yang dibenerin**: `review-package` sejak 6.2.0 minta `PLAN_FILE` di argumen pertama, jadi panggilan build gagal "no such plan file" (muncul di 18 sesi mahjong). Paket diff sekarang **selalu** lewat fallback git di semua mode. Adopsi re-review scoped, resume implementer, dan audit penuh 6.2–7.0 → spec terpisah, diukur sendiri. | rekomendasi; user minta penjelasan efek, lalu menegaskan batas ronde memang desainnya |
| D12 | **Batas review 3 ronde tidak diubah**, juga tidak di spec nyusul kecuali user sendiri yang memutuskan. Ini keputusan desain (commit `c12678b` 2026-05-31, dipakai lagi di spec lanes 2026-07-21 dan antrian gate 2026-08-27), bukan turunan superpowers. Re-review tetap review penuh dari nol. | user |

## 4. Desain

### 4.1 Gambaran alur baru (per task)

```
controller                                   subagent
──────────                                   ────────
build_status.py --format controller  ──►  (peta + READY + hold + gate + staleness)
pilih task (READY per repo)
set in_progress, rekam base SHA
dispatch brief-writer(task id, base SHA repo sibuk) ──► baca task, plans, _shared slice,
                                                        signature dep, slice skema, mockup,
                                                        titipan for:<task>, tulis _rules-<repo>
                                                        (bila basi) + task-<id>-brief.md
  ◄── ringkasan ≤10 baris (path, titipan dipakai, DRIFT, ambigu, saran tier model)
jawab ambiguitas (peta + baca plan section tertarget) → titipan / re-dispatch brief-writer
dispatch implementer (pointer brief + report)     ──► TDD, commit, report file
  ◄── status + SHA + 1 baris test + concern
verifikasi deterministik (HEAD maju, re-run test)
review-package → dispatch reviewer (path template) ──► baca brief+report+diff, tulis review file
  ◄── verdict ringkas (spec/quality/⚠️ 1 baris per item)
⚠️ butuh baca kode? → subagent read-only            ──► verdict per item + bukti 1 baris
temuan yang ngaruh ke task lain → APPEND carry.yaml
set done + commits
```

Gate (step 6), lanes, unattended, drain, simplify (7a): **semantik tidak berubah.** Yang berubah cuma *dari mana* controller dapet informasinya.

### 4.2 Peta tetap di controller (menjawab "controller jadi bego?")

Kepinteran controller dipakai buat empat hal. Desain ini menjaga keempatnya:

| Kebutuhan | Sumber setelah perubahan |
|---|---|
| Nyambungin antar-task ("temuan T52 ngaruh ke T75") | Peta 1 baris per task di ringkasan state, selalu dimuat. Venue-tables (96 task) ≈ 12KB ≈ 4K token, milestone kelar dilipat jadi 1 baris. Ini **lebih lengkap** dari sekarang: transcript nunjukin controller sekarang cuma grep potongan `tasks.yaml`. |
| Gate (dibangun vs maksud, challenge checklist) | `build_status.py --format task --task <id segmen>` (detail lengkap task segmen) + titipan `gate:<milestone>` + diff segmen (seperti sekarang) |
| Jawab implementer / brief-writer yang balik nanya | Peta + baca **section** plan yang relevan saja |
| Ngobrol progres & keputusan sama user | Peta + gate antri + hold |

### 4.3 Agent `brief-writer` (D5)

File baru `plugin/agents/brief-writer.md`. Frontmatter mengikuti pola `critic.md` (`name`, `description`, `tools`) + `model: inherit`. Tools: `Read, Grep, Glob, Bash, Write`. Write **hanya** ke `<root>/.claude/build/<work-item>/`.

**Aturan rakit brief tetap bersumber tunggal di §B** (`reference/b-brief.md` setelah dipecah, §4.6): slice skema fail-open UNION + cap ~15 tabel, listing dir cap ~30, directive reuse, degrade proyeksi stub, `schema_owner`, mockup verbatim/gambar/Figma + motion vocab design-system, signature dep dari disk, dari base-SHA bila repo dep sibuk (`git -C <path-unit-literal> show <base7>:./<file>`), cek DRIFT vs `produces:`, task `unit: integration`, larangan suruh implementer baca `tasks.yaml`. §B tidak dipindah ke file agent karena `design-system` (atom mockup-dispatch) dan `fix` (rakit brief) meminjamnya. **Yang membaca §B sekarang brief-writer, bukan controller.** Badan agent cuma memuat yang khas brief-writer: input, `_rules-<repo>.md`, kontrak balikan, dan aturan "jangan menebak, laporkan ambigu". *(keputusan desainer setelah builder check)*

**Input (prompt dispatch dari controller):** root produk, path work-item, id task, path absolut `reference/b-brief.md`, daftar `repo → base7` untuk repo yang sedang punya task in-flight (controller yang tahu lane), path brief keluaran.

**Yang dibaca brief-writer sendiri dari disk:**
- entri task: `python3 .claude/build_status.py --format task --task <id>` (bukan baca `tasks.yaml` 150KB utuh);
- section `plans/<unit>.md` dan `_shared.md` yang relevan;
- `control/conventions.md`, `workspace.yaml` (stack), `control/schema/<schema_owner(unit)>.md`;
- file dep di disk / base-SHA;
- mockup;
- titipan: `python3 .claude/build_status.py --format carry --for <id>` (+ fallback legacy §4.4).

**`_rules-<repo>.md` resmi (D3).** Path `<root>/.claude/build/<work-item>/_rules-<repo>.md`, satu per repo unik (nama toplevel). Isi: stack repo, pointer section konvensi + invarian yang mengikat, aturan migrasi (hanya lewat `actions: migrate`; DDL di luar itu dilarang), TDD, commit hanya file task (bukan `git add -A`), "jangan baca `tasks.yaml`". Brief-writer **menulis ulang** file ini bila belum ada ATAU mtime salah satu sumbernya (`conventions.md`, `invariants.md`, `workspace.yaml`, `.claude/settings.json`) lebih baru. Brief merujuk file ini, tidak menyalin isinya.

**Kontrak balikan (≤ 10 baris):**
```
brief: .claude/build/<wi>/task-T50-brief.md
rules: _rules-kuymahjong.md (dipakai | ditulis ulang)
titipan: C12, C31 (atau: none)
deps: T45 signature ok · T47 DRIFT (produces: ≠ disk)
ambigu: <pertanyaan verbatim per baris> (atau: none)
tier: mid | high (saran per reference §C; controller yang memutuskan)
```

**Ambiguitas.** Controller menjawab dari peta + section plan yang relevan, lalu: jawaban yang cuma relevan buat task ini → re-dispatch brief-writer dengan jawabannya ditempel (atau append ke brief kalau 1–2 baris). Jawaban yang ngaruh ke task lain → titipan dulu (D6). Controller nggak bisa jawab: attended → tanya user (`AskUserQuestion`); unattended → `needs_human` + `hold: "NEEDS_CONTEXT: <pertanyaan>"` (kosakata yang sudah ada, reference §I).

**Panel tetap benar.** `build_status.py` memakai mtime `task-<id>-brief.md` sebagai awal fase `impl` dan ETA. Brief-writer menulis brief tepat sebelum implementer di-dispatch, jadi semantiknya tetap. Waktu brief-writer tidak masuk durasi task. Itu diterima.

### 4.4 Titipan resmi: `carry.yaml` (D3, D6, D7, D10)

**Path:** `control/features/<f>/carry.yaml` atau `control/fixes/<id>/carry.yaml`. Ikut ke-commit.

**Skema:**
```yaml
# carry.yaml — titipan antar-task build. Penulis tunggal: controller build.
notes:
  - id: C12
    for: T75            # id task | gate:<milestone> | ship | simplify
    from: review T66    # review Tn | preflight | gate <M> | drain | user <tanggal>
    at: 2026-10-20
    note: "pratinjau daftar nama sebelum simpan (\"Meja 1–5\" = satu nama)"
    closed: 2026-10-21  # opsional; diisi controller saat titipan gate/ship/simplify sudah dipakai
```

**Penulis tunggal = controller** (sama kayak `tasks.yaml`). Brief-writer, reviewer, dan `ship` cuma baca. Satu-satunya pengecualian adalah subagent konversi legacy (di bawah): jalan sekali, attended, sebelum dispatch apa pun, jadi nggak ada penulis lain yang bersamaan.

**Target `gate:<milestone>`** berlaku untuk semua segmen gate di milestone itu. Pakai `gate:<milestone>/<unit>` kalau titipannya cuma buat satu segmen app×milestone. *(keputusan desainer)*

**`ship`** menampilkan titipan `for: ship` yang aktif di finishing gate sebagai item checklist. Yang relevan buat reviewer PR (misal urutan deploy) ikut masuk body PR. *(keputusan desainer)*

**Kapan ditulis (D6).** Sebelum scheduler tick berikutnya, setiap kali ada keputusan atau temuan yang ngaruh ke task lain, ke gate, ke ship, atau ke simplify. Sumbernya: temuan pre-flight sweep, verdict reviewer, gate, drain pagi, jawaban user. Yang cuma relevan buat task berjalan nggak perlu dititip.

**Siapa baca apa:**
- brief-writer: `--for <task>` saja;
- gate step 6: `--for gate:<milestone>`;
- 7a simplify: `--for simplify`;
- `ship`: `--for ship` (titik baca baru di `ship/SKILL.md`; carry-notes lama berisi catatan ship yang selama ini nggak pernah sampai ke `ship`);
- controller: cuma **jumlah** per target di ringkasan state, nggak pernah isi utuh.

**Otomatis nggak kebaca lagi.** `--format carry` nggak mengeluarkan titipan ber-`for:` task yang statusnya `done`, dan titipan yang punya `closed:`. Entri tetap ada di file sebagai jejak audit, nggak dipindah.

**Legacy `_carry-notes.md`.** Fitur in-flight (venue-tables: 30 task belum done) nggak boleh kehilangan titipan.
- **Attended, pertama kali** build ketemu `_carry-notes.md` tanpa `carry.yaml`: dispatch subagent konversi. Subagent ngambil baris yang menyebut task belum-done + agenda gate/ship/simplify yang belum lewat, nulis `carry.yaml`, lalu balikin jumlah per target. Controller nunjukin ringkasan jumlahnya (bukan isinya). File lama tetap ada sebagai arsip.
- **Unattended** (atau konversi belum jalan): brief-writer grep `_carry-notes.md` untuk `\b<id task>\b` sebagai fallback, dan ringkasan state nandain "legacy carry-notes aktif".

### 4.5 Ringkasan state: `build_status.py` format baru (D8)

Tambah tiga nilai `--format`. Read-only, stdlib-only, Python ≥ 3.9, sama seperti sekarang:

**`--format controller [--work-item <dir>]`** — teks ringkas buat controller, gantiin baca eager di step 1:
```
work-item: control/features/venue-tables (feature · risk normal · sensitivity —)
staleness: OK | STALE plans/kuymahjong.md > tasks.yaml | WARN business.md > tasks.yaml
repos: kuymahjong (kuymahjong/, feature/venue-tables) · venue (venue/, …) · admin (…)
READY: kuymahjong T50 · venue T61 · admin —
in_progress: —
hold: T66 needs_human "migrate destructive — nunggu approve (affects: …)"
blocked: —
gates queued: G3 M4 "floor-scan T52 (session/token)"
reuse basi: T19 table venue_tbl (tak ada di control/schema/kuymahjong.md)
carry: T75×2 · T70×1 · gate:M6×1 · ship×3 · simplify×1   [legacy carry-notes aktif]
map:
  M1 ✓ 12/12 · M2 ✓ 18/18 · M3 ✓ 20/20
  M4 8/14
    T50 kuymahjong pending  deps T45      Kabari aku: tombol …
    …
```
Semua baris itu deterministik. Cek staleness (mtime), reconcile `reuse:` vs nama tabel proyeksi / file di pohon, dan pengelompokan repo (reuse `_lane_keys`) pindah dari "controller baca lalu nalar" ke script. Keputusan atas hasilnya (WARN/STOP/hold) tetap di controller, sesuai aturan SKILL step 1 yang ada.

**`--format task --task <id>[,<id>…]`** — entri task lengkap (desc, files, approach, test, deps, actions, manual, mockup, reuse, produces, status, hold, commits) sebagai YAML/JSON. Dipakai brief-writer dan gate.

**`--format carry --for <target>[,<target>…]`** — titipan aktif untuk target itu (sudah difilter §4.4). Membaca `carry.yaml` (dan menandai bila hanya legacy yang ada).

**Format lama (`json`/`status`/`drive`) tidak berubah.** Panel dan `drive.sh` harus mengeluarkan output yang persis sama, dan test yang sudah ada tetap hijau.

**Allowlist.** Tambah `Bash(python3 .claude/build_status.py:*)` ke `plugin/template/.claude/settings.json` (prefix dengan wildcard di ujung, satu-satunya bentuk yang bekerja). `upgrade` menyusulkannya lewat merge allowlist yang sudah ada.

**Degrade.** `build_status.py` versi lama menolak format baru (argparse → exit 2). Controller mendeteksi ini, jalan dengan cara lama, dan WARN "jalankan `/upgrade` biar build hemat context". "Cara lama" = perilaku step 1 dan step 3 sebelum rilis ini: controller baca `tasks.yaml`/`plans/*`/`_shared.md` sendiri dan merakit brief sendiri. **Unattended:** produk yang belum di-upgrade juga belum punya entri allowlist baru, jadi memanggil script itu bakal memunculkan permission prompt dan run beku. Karena itu controller cek dulu `.claude/settings.json` (Read) memuat prefix `Bash(python3 .claude/build_status.py:*)`. Kalau nggak ada, langsung degrade tanpa memanggil. Catat di prosa `last-run.md`. *(keputusan desainer)*

**Pre-flight conflict sweep** (step 1) butuh `tasks.yaml` utuh vs `invariants.md` + `mandatory_for`. Ini didelegasikan ke subagent read-only (pola `critic`). Subagent balikin daftar konflik yang sudah di-batch, controller tetap yang menyajikan satu pertanyaan ke user (attended) atau set `hold:` (unattended). Transcript `9a7ff9b9` menunjukkan model sudah melakukan ini secara improvisasi.

### 4.6 `reference.md` dipecah, dibaca per step

- `plugin/skills/build/reference.md` jadi **indeks** pendek: tabel `§ | file | baca saat`.
- Badan tiap section pindah ke `plugin/skills/build/reference/<huruf>-<slug>.md`. Huruf §A–§I dipertahankan supaya semua rujukan "§D" dsb. tetap bermakna.
- §B (rakit brief) tetap di `reference/b-brief.md` sebagai sumber tunggal (§4.3). Pembacanya brief-writer, `design-system`, dan `fix`, bukan controller build. Contoh prompt dispatch implementer ramping (yang dipakai controller) dipindah ke section yang dibaca controller saat dispatch.
- Section baru buat `carry.yaml` (skema + kapan tulis + legacy) — huruf berikutnya, §J.
- SKILL.md:12 "baca itu dulu" diganti "baca indeks; baca section saat sampai di step yang menyebutnya". Run attended biasa nggak perlu §G/§H/§I kecuali ada drain/antrian.
- Semua rujukan silang ikut diperbarui. Yang diketahui: `template/control/conventions.md:29` (§B), `rules/ask-user.md:68` (§G), `skills/design-system/SKILL.md:12` + `skills/design-system/reference.md:33` (§B, §C), `skills/fix/reference.md:3` + `:86` (§B, §D, §E), string yang di-grep `tools/tests/ask-user.test.sh` dan `tools/tests/build-kimi.test.sh`, injeksi catatan Kimi di `tools/build-kimi.sh` ("setelah heading unattended pertama" di `reference.md`). Builder wajib grep ulang semuanya.

### 4.7 Template superpowers by-path

- Controller **tidak membaca isi** `implementer-prompt.md` / `task-reviewer-prompt.md`.
- Prompt implementer = bentuk ramping yang sudah didokumentasikan di §B (pointer brief + report + kontrak balikan) **+ path `implementer-prompt.md`** yang dibaca implementer sendiri. Dengan begitu implementer tetap dapat aturan eskalasi, checklist self-review, status DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT, dan aturan append report saat fix. Metrik NEEDS_CONTEXT dan `blocked` di §4.10 bergantung pada ini. *(keputusan desainer setelah builder check)*
- Prompt reviewer = path template `task-reviewer-prompt.md` (subagent yang membacanya) + tiga path (brief, report, diff) + blok global constraints + kontrak balikan ringkas (§4.8).
- Path direktori `subagent-driven-development` di-resolve sekali per run, hanya lewat perintah yang aman di jalur unattended (§6).
- Prinsip "pinjam by-reference" tetap (reference §A). Isi template superpowers tidak di-fork.

### 4.8 Verdict reviewer ringkas (menggantikan `_review-instructions.md`)

- Reviewer menulis review lengkap ke `<root>/.claude/build/<wi>/task-<id>-review-r<n>.md`.
- Balikan chat ≤ 12 baris:
  ```
  spec: ✅ | ❌ <1 baris>
  quality: ✅ | ❌ (Critical n · Important n · Minor n)
  ⚠️: n
    - <item 1 baris>
  review: .claude/build/<wi>/task-T50-review-r1.md
  ```
- Aturan dari `_review-instructions.md` masuk ke blok global constraints prompt reviewer (≤ 10 baris): baca diff sekali; kode di luar diff hanya untuk risiko konkret yang disebut (sebut risikonya + apa yang dicek); klaim report = belum terverifikasi.
- `task-reviewer-prompt.md` (superpowers ≥ 6.2) bilang "pesan terakhir = laporan itu sendiri". Prompt dispatch reviewer **meng-override** aturan ini secara eksplisit: laporan lengkap ke file review, pesan terakhir = verdict ringkas di atas.
- **Paket diff selalu lewat git** (D11): `git -C <path> log --oneline base..head` + `git -C <path> diff --stat base..head` + `git -C <path> diff -U10 base..head`, di-redirect ke `<root>/.claude/build/<wi>/review-<base7>..<head7>.diff`. Isinya setara output `review-package`, dan bentuk ini sudah di-allowlist `wire` 5.5. `scripts/review-package` tidak dipanggil lagi. Semua teks yang menyebutnya (SKILL step 4, reference §A) ikut diperbarui.
- Re-dispatch fix ke implementer menunjuk **path file review**, bukan menyalin temuan ke prompt. Re-review tetap review penuh dari nol, batas 3 ronde (D12).
- Paranoia controller tetap. Controller tetap verifikasi HEAD maju + re-run test sendiri (reference §A "yang tidak dipinjam").

### 4.9 Resolusi ⚠️ "Cannot verify from diff"

Keputusannya tetap di controller (gap nyata → perlakukan spec ❌ → re-dispatch). Pengumpulan buktinya yang pindah:
- Controller boleh cek tertarget sendiri (grep/sed yang outputnya kecil, kira-kira ≤ 2K karakter per item).
- Lebih dari itu → dispatch subagent read-only. Input: id task, item ⚠️, path brief + diff. Balikan: per item `gap nyata | aman` + bukti 1 baris (file:baris).

### 4.10 Alat ukur + pengaman kualitas (D9)

**Alat ukur `tools/measure-build-context.py`** (di-commit, stdlib, jalan di transcript lokal `~/.claude/projects/<produk>/*.jsonl`). Per sesi build, keluarkan:
- context saat dispatch implementer pertama;
- median pertumbuhan per dispatch implementer;
- atribusi per jenis hasil tool (skill/reference, state, kode, agent, lain);
- ronde review per task (dispatch reviewer ÷ task unik);
- NEEDS_CONTEXT per task (dihitung dari **balikan subagent** saja, bukan teks skill);
- item ⚠️ per review;
- task `blocked`.

Baseline dihitung dari transcript yang sudah ada **sebelum** perubahan di-merge, lalu disimpan di bagian akhir spec ini (§9).

**Kriteria lulus**, dari ≥ 3 sesi build nyata sesudah rilis:
- median context dispatch pertama ≤ 95K;
- median pertumbuhan per dispatch ≤ 10K;
- ronde review/task, NEEDS_CONTEXT/task, dan rasio `blocked` masing-masing tidak lebih buruk dari baseline lebih dari ~20%.

Kalau angka kualitas lebih buruk, periksa brief yang dihasilkan brief-writer dulu sebelum lanjut.

### 4.11 Kimi

- `plugin-kimi/` tidak diedit langsung. `tools/build-kimi.sh` regen, lalu `tools/tests/build-kimi.test.sh` dijalankan.
- Tambah baris mapping di `rules/kimi-harness.md` (generate dari `build-kimi.sh`): `context-vault:brief-writer` → sub-agent `coder` (perlu nulis file brief); prompt = seluruh isi `agents/brief-writer.md` + konteks tugas.
- Di Kimi, controller membaca file agent untuk dipaste ke prompt, jadi hemat context-nya lebih kecil. Ini diterima (§5).

## 5. Non-goals

- Memisahkan cabang unattended di SKILL.md (D2). Spec terpisah nanti.
- Baseline sesi ~55–60K (plugin/MCP yang aktif di produk). Itu setting di repo produk, misal `enabledPlugins` di `.claude/settings.json` mahjong. User yang ngatur.
- Mengubah semantik gate, scheduler lane, unattended, drain, simplify, migrate, floor-scan. Ini refactor *lokalitas context* + peresmian tiga file, bukan perubahan perilaku.
- Mengoptimalkan context di Kimi.
- Prompt smoke Part B (step 6). Tetap dirakit controller seperti sekarang.
- Adopsi `re-review-prompt.md` (re-review scoped), resume implementer di ronde fix, dan audit penuh klaim pinjaman superpowers 6.2–7.0 (D11). Spec terpisah sesudah rilis ini diukur.
- Mengubah batas review 3 ronde (D12).

## 6. Constraint

- `build_status.py` tetap read-only, stdlib-only, Python ≥ 3.9. Output `json`/`status`/`drive` byte-identik untuk state yang sama.
- Jalur unattended nggak boleh memunculkan permission prompt baru. Di Claude Code, hanya wildcard `:*` di ujung yang bekerja, dan path plugin-cache yang bernomor versi nggak bisa di-allowlist. Semua perintah Bash baru di jalur unattended harus cocok dengan prefix di template allowlist. Allowlist project baru berlaku setelah workspace di-trust.
- Subagent membaca file di luar root produk **lewat tool Read, bukan Bash**: brief-writer membaca `reference/b-brief.md` (plugin root), implementer membaca `implementer-prompt.md`, reviewer membaca `task-reviewer-prompt.md` (plugin-cache superpowers). Apakah Read ke luar root produk dari subagent memicu prompt di sesi headless **wajib diverifikasi** (`claude -p` dengan HOME terisolasi, pola di memori "old CC compat testing"). Kalau ternyata memicu prompt, fallback ke perilaku sekarang khusus bagian itu, dan catat.
- Tool Edit butuh file sudah di-Read di sesi itu. Controller menulis status ke `tasks.yaml` (150KB) dan append ke `carry.yaml` tanpa membaca file utuh (misal Read tertarget offset/limit lalu Edit, atau penulis deterministik kecil). Mekanismenya diserahkan ke builder, asal nggak memunculkan permission prompt baru di unattended.
- Semua test yang ada (`tools/tests/*.test.sh`, `plugin/hooks/tests/*`) tetap hijau. String yang dipindah, grep di test-nya ikut dipindah.
- `plugin.json` hanya berubah nilai `version` (+ deskripsi). Jangan tambah key. Key tambahan mematikan plugin di Claude Code lama.
- Fitur in-flight (venue-tables) harus bisa di-resume mulus di versi baru: `in_progress`, `hold:`, `gates.yaml`, legacy carry-notes.
- Commit tanpa trailer `Co-Authored-By`.

## 7. Diserahkan ke builder

- Format teks persis `--format controller` (yang penting: deterministik, ringkas, memuat semua baris di §4.5).
- Nama file di `reference/` dan pembagian sisa §B.
- Kata-kata badan `agents/brief-writer.md`, selama seluruh aturan §B lama terbawa.
- Mekanisme resolve path `subagent-driven-development` yang aman di unattended.
- Mekanik konversi legacy carry-notes.
- Tambahan test untuk format baru `build_status.py` (fixture di `tools/tests/fixtures/build-status/` bisa dipakai ulang + fixture `carry.yaml`).
- Update `guide/` (cheatsheet/reference) dan README bila menyebut perilaku yang berubah.

## 8. Rilis

- Versi `0.28.0`.
- Regen Kimi + test sync (ritual `docs/maintaining.md`).
- Produk lama butuh `/upgrade` (susulin `build_status.py` + allowlist). Tanpa itu, build tetap jalan dengan cara lama + WARN (§4.5 Degrade).

## 9. Baseline (diisi sebelum merge)

| Metrik | Baseline | Sesudah |
|---|---|---|
| Median context dispatch pertama | 181.5K (42 sesi, hitungan kasar sesi ini) | |
| Median pertumbuhan per dispatch | ~30K | |
| Ronde review / task | | |
| NEEDS_CONTEXT / task | | |
| Rasio `blocked` | | |
