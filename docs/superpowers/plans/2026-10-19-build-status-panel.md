# Panel Status Build — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Progres `/build` kelihatan tanpa buka `tasks.yaml` dan tanpa nanya orchestrator. Ada tiga permukaan: panel + status line + toast di sesi Claude Code (mod di plugin context-vault), dan satu baris progres yang update di tempat di terminal `drive.sh`.

**Architecture:** Satu pembaca bersama, `plugin/template/.claude/build_status.py` (Python 3 stdlib saja). Skrip ini mem-parse `tasks.yaml`/`gates.yaml`/`last-run.md` + file kerja `.claude/build/`, lalu mengeluarkan **snapshot JSON v1** dan teks siap pakai (`status_line`, `drive_line`). Mod TypeScript (`plugin/hooks/register.tsx`) menjalankan skrip itu dari folder plugin tiap 3 detik lewat `$.process.run`, lalu menggambar panel dari JSON. `drive.sh` menjalankan salinan skrip yang sama di produk (`.claude/build_status.py`) dengan `--format drive`. Karena semua angka dan teks ringkas lahir dari satu fungsi Python, panel, status line, dan `drive.sh` pasti sama.

**Tech Stack:** Python 3 stdlib (tanpa PyYAML) · Bash · TypeScript hooks module Claude Code (`claude plugin validate`, `claude plugin test`, import dari `'claude-code'` dan `'claude-code/testing'`) · test bash pola counter PASS/FAIL · `tools/build-kimi.sh`.

**Spec:** `docs/superpowers/specs/2026-10-19-build-status-panel-design.md`. Baca dulu; rujukan `§N` di bawah menunjuk section spec itu.

## Global Constraints

- **Working dir:** `/Users/mac-098506/Developer/project/context-vault`. Basis `main` sesudah `1cfa1f4` (commit spec). Kerjakan di branch `feat/build-status-panel`. Plan lain (`2026-10-19-attended-ask-push.md`) mungkin landed duluan dan menyentuh README/guide/`plugin.json`. Karena itu semua edit prosa di plan ini di-anchor ke **kutipan teks**, bukan nomor baris. Sebelum tiap Edit prosa: `grep -Fc -e '<old_string>' <file>` HARUS `1`. Kalau `0` atau `>1`, STOP dan lapor, jangan tebak.
- **Commit tiap task:** pesan Indonesian + prefix conventional-commits, **TANPA** trailer `Co-Authored-By`.
- **Jangan edit `plugin-kimi/`** dengan tangan. Regen lewat `bash tools/build-kimi.sh` di Task 8.
- **Read-only total (spec D3):** `build_status.py` dan mod **tidak pernah menulis** file apa pun, di `control/` maupun `.claude/build/`. Yang menulis cuma `drive.sh` (file heartbeat-nya sendiri).
- **Mod nggak memanggil model** (`$.model` dilarang) dan nggak berbuat apa pun di `claude -p` (`e.isInteractive === false`).
- **Python:** stdlib saja, jalan di Python ≥3.9. Mod memanggil `python3` (argv, tanpa shell).
- **Fakta API mod yang dipakai** (Claude Code 2.1.303, sudah diverifikasi lewat probe):
  - `$.process.run(argv, { cwd, timeoutMs })` → `{ exitCode, stdout, stderr, … }`, reject kalau command nggak bisa start atau kena timeout.
  - `$.fs.exists(path)`, dengan path relatif = cwd sesi.
  - `$.clock.every(ms, fn)` → `{ cancel }`. Timer mati waktu reload, jadi di-arm ulang di `session.start`.
  - `$.state` (per sesi, tahan reload) lewat `atom`/`read`/`update` dari `'claude-code'`.
  - `$.ui.open({ id, title })` → `{ isPlaced }`; `$.ui.close({ id })`; `$.ui.panes()`; `$.ui.status(text | undefined)`; `$.ui.toast(text, { timeoutMs })`.
  - `$.command.register({ name, description })` + `on('command.run', { command }, …)`. Nama command **tidak** di-namespace.
  - `$.plugin.root` = folder plugin (yang berisi `.claude-plugin/`).
  - Di test, `fs`/`process` dijawab dengan `on('fs.exists', …)`/`on('process.run', …)`. `mock.clock(on)` + `clock.advance(ms)`. Pane di-mount dengan `$.ui.mount({...})`. Hook yang memanggil `$` tanpa jawaban di-skip diam-diam, jadi tiap test wajib menjawab semua op yang dipanggil.
- **Keputusan plan yang menajamkan/menyimpang dari spec** (reviewer: ini disengaja):
  1. Sinyal akhir durasi task = **mtime `task-<id>-report.md`**, bukan waktu commit `head` (spec §5 mengizinkan sinyal lain yang setara). Kualitasnya sama karena keduanya terjadi sebelum review final, dan nggak butuh git atau pemetaan multi-repo.
  2. Footer panel `jalan 1j12m / maks 6j` = lama sejak `drive.sh` mulai, dibanding `MAX_JAM`. Spec menulis `putaran …`, padahal batas jamnya berlaku untuk seluruh run `drive.sh`.
  3. Karena pembacanya file template baru, `upgrade/SKILL.md` dan `init/SKILL.md` dapat edit kecil (Task 5) supaya `build_status.py` ikut tersalin. Spec §7 bilang `upgrade` nggak berubah; asumsi itu cuma berlaku untuk `drive.sh`.
  4. Nama slash command: **`/cv-panel`** (deskripsi diawali `context-vault:`), karena nama command nggak di-namespace.
  5. Folder kerja fix = `.claude/build/fixes/<id>/` (terverifikasi di produk nyata), fallback `.claude/build/<id>/`.
- **Nilai yang dipatok (dipakai lintas task, jangan drift):**
  - Interval poll mod 3000 ms; `timeoutMs` 5000.
  - Interval baris `drive.sh` default 5 detik (env `DRIVE_TICK`).
  - Ambang "diam" 30 menit (`--quiet-min 30`). **Direvisi review akhir → 90 menit**: 30 menit menandai ~14% task attended nyata yang masih jalan sebagai diam.
  - ETA tampil setelah ≥3 sampel.
  - Bobot task: 3 kalau ada `mockup:` ATAU `unit: integration` ATAU `files` > 4; 2 kalau `files` 3–4; 1 selainnya.
  - Pane id `cv-build`, judul `context-vault · build`. Toast `timeoutMs` 8000. Nama plugin di `PluginState`: `'context-vault'`.

## Review Focus

1. **`tasks.yaml` nyata penuh blok `|`/`>`, header komentar panjang, dan string ber-kutip berisi `: { } #`.** Parser harus menghasilkan field yang sama dengan PyYAML. Dipatok di Task 2 (fixture konstruksi) dan Task 9 (bandingkan 36 file nyata dengan PyYAML).
2. **`drive.sh` keluar lewat jalur mana pun** (Ctrl-C, `claude` gagal, tiap `break`) harus mematikan ticker **beserta `sleep` anaknya**, lalu menghapus heartbeat. Ticker yang tersisa menahan stdout dan bikin pemanggil hang. Dipatok di Task 5 (test durasi + heartbeat hilang).
3. **Heartbeat basi** (`drive.sh` di-`kill -9`): `drive.json` ada tapi PID mati → anggap nggak jalan (mode `attended`, tanpa putaran). Dipatok di Task 3.
4. **Toast spam** waktu sesi baru dibuka atau mod reload: poll pertama cuma jadi baseline, alert yang sama nggak pernah di-toast dua kali, dan banyak alert baru sekaligus digabung jadi satu toast. Dipatok di Task 6.
5. **Data yang belum lengkap:** `tasks.yaml` belum ada, `gates.yaml` absen, header `last-run.md` lama tanpa `review:`/`blockers:`, task tanpa `unit`/`desc`, `deps` yang merujuk id tak dikenal, fix (tanpa `gates.yaml`). Semua itu nggak boleh crash dan harus menghasilkan keluaran yang masuk akal. Dipatok di Task 3 dan Task 4.

---

## File Structure

| file | tanggung jawab | task |
|---|---|---|
| `plugin/template/.claude/build_status.py` **(BARU)** | parser YAML subset, snapshot v1, ETA, teks `status_line`/`drive_line`/alert, CLI | T2–T4 |
| `tools/tests/build-status.test.sh` **(BARU)** + `tools/tests/fixtures/build-status/**` | test pembaca (CLI + fungsi murni) | T2–T4 |
| `plugin/template/.claude/drive.sh` | precheck python, heartbeat `drive.json`, ticker baris progres | T5 |
| `plugin/hooks/tests/drive.test.sh` | test baru + setup salin `build_status.py` | T5 |
| `plugin/skills/upgrade/SKILL.md`, `plugin/skills/init/SKILL.md` | ikut menyalin `build_status.py` | T5 |
| `plugin/types/index.d.ts` **(BARU)** | tipe snapshot + kontrak `PluginState['context-vault']` | T6 |
| `plugin/hooks/panel/snapshot.ts`, `plugin/hooks/panel/alerts.ts` **(BARU)** | parse/validasi JSON, dedup alert | T6 |
| `plugin/hooks/register.tsx` **(BARU)** | `session.start`, poll, status, toast, auto-open, command, render | T6–T7 |
| `plugin/hooks/panel/rows.ts` **(BARU)** | snapshot → baris panel (murni) | T7 |
| `plugin/hooks/tests/panel.test.tsx` **(BARU)** | test mod (`claude plugin test`) | T6–T7 |
| `plugin/hooks/hooks.json`, `plugin/.claude-plugin/plugin.json` | `modules`, `types`, versi, deskripsi | T6, T8 |
| `README.md`, `plugin/skills/guide/reference.md` | dokumentasi | T8 |
| `plugin-kimi/**` | regen (mod nggak ikut, `build_status.py` ikut via template) | T8 |

Urutan: T1 dulu (bisa membatalkan pengemasan). T2 → T3 → T4 berurutan (satu file). T5 butuh T4. T6 butuh T3 (skema JSON). T7 butuh T6. T8 sesudah semuanya hijau. T9 terakhir.

---

### Task 1: Uji kompatibilitas `modules` di Claude Code versi lama (spike, nggak di-ship)

Spec §10.2. Hasilnya menentukan apakah mod boleh tinggal di plugin utama.

**Files:**
- Modify: `docs/superpowers/specs/2026-10-19-build-status-panel-design.md` (catat hasil di §10 butir 2)

- [ ] **Step 1: Siapkan salinan plugin dengan module dummy**

```bash
S="$(mktemp -d)/cv"; mkdir -p "$S"; cp -R plugin/. "$S/"
jq '. + {modules: ["./register.ts"]}' "$S/hooks/hooks.json" > "$S/hooks/h.tmp" && mv "$S/hooks/h.tmp" "$S/hooks/hooks.json"
printf '%s\n' "import type { Register } from 'claude-code'" \
  "export const register: Register = (on) => { on('session.start', async (\$, e, next) => { \$.ui.status('cv compat'); return next(e) }) }" > "$S/hooks/register.ts"
claude plugin validate "$S"
```
Expected: `✔ Validation passed`, dan module terbaca (`session.start`, `$.ui.status`).

- [ ] **Step 2: Pilih versi lama**

Run: `npm view @anthropic-ai/claude-code versions --json | jq -r '.[]' | grep -E '^(1\.0|2\.0|2\.1)\.' | sort -V`
Pilih tiga: patch terakhir `1.0.x`, patch terakhir `2.0.x`, dan `2.1.0`. Kalau `2.1.0` nggak ada, ambil `2.1.x` pertama yang ada.

- [ ] **Step 3: Uji tiap versi**

Untuk tiap versi `V`:
```bash
npx -y "@anthropic-ai/claude-code@$V" --version
npx -y "@anthropic-ai/claude-code@$V" plugin validate "$S" 2>&1 | tail -5     # boleh "unknown command" di versi lama
npx -y "@anthropic-ai/claude-code@$V" -p "balas persis: ok" --plugin-dir "$S" --debug 2>&1 | grep -iE 'plugin|hooks|module|error' | head -20
npx -y "@anthropic-ai/claude-code@$V" -p "balas persis: ok" --plugin-dir "$S"
```
LULUS untuk versi itu: perintah `-p` terakhir mencetak `ok`, dan debug nggak memuat error pemuatan plugin atau hooks (misalnya `Failed to load`, `Invalid hooks`). `plugin validate` yang menolak key `modules` di versi lama juga dihitung GAGAL.

- [ ] **Step 4: Catat hasil dan putuskan**

Tambahkan paragraf `**Hasil uji (Task 1):**` di akhir butir 2 §10 spec: versi yang diuji, LULUS/GAGAL per versi, dan potongan output yang relevan.
- **Semua LULUS:** lanjut Task 2.
- **Ada yang GAGAL:** commit catatan ini, lalu **STOP**. Lapor ke user bahwa rencana cadangan spec (plugin saudara di marketplace yang sama) perlu plan susulan. Jangan lanjut ke Task 6–8.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-10-19-build-status-panel-design.md
git commit -m "docs(spec): hasil uji kompatibilitas modules di Claude Code lama"
```

---

### Task 2: Parser YAML subset + CLI `--parse-yaml`

**Files:**
- Create: `plugin/template/.claude/build_status.py`
- Create: `tools/tests/build-status.test.sh`
- Create: `tools/tests/fixtures/build-status/yaml/constructs.yaml`, `constructs.json`, `tab.yaml`

**Interfaces:**
- Produces: `class YamlError(Exception)` · `parse_yaml(text: str) -> object` (dict/list/str/None, **semua skalar tetap string**) · `load_yaml(path: Path) -> object | None` (None kalau file nggak ada; `YamlError` kalau rusak) · CLI `python3 build_status.py --parse-yaml FILE` (cetak JSON, exit 0; `YamlError` → pesan ke stderr yang memuat nama file, exit 2).

Konstruksi yang wajib didukung: komentar baris penuh dan komentar di belakang nilai (`#` di luar kutip, didahului spasi); map blok bersarang; sequence blok, termasuk item `- key: val` yang membuka map (key berikutnya di indent item); flow sequence skalar `[a, "b, c", 'd']` dan `[]`; skalar ber-kutip ganda (escape `\"` `\\` `\n`) dan tunggal (`''` = `'`); skalar polos (spasi pinggir dibuang); block scalar `|`, `|-`, `>`, `>-`; key tanpa nilai yang diikuti blok lebih dalam → isi blok itu, kalau nggak ada blok → `None`. Nilai polos yang diawali `{` dikembalikan **sebagai string mentah** (toleran). Karakter tab di indentasi → `YamlError`.

Algoritma (parser berbasis indentasi, satu lintasan): pecah jadi baris, buang baris kosong dan komentar penuh (kecuali di dalam block scalar), lalu turun secara rekursif dengan `parse_block(indent)`. Baris pertama blok menentukan apakah blok itu sequence (`- `) atau map (`key:`). Block scalar mengumpulkan baris yang indentasinya lebih dalam dari key-nya (baris kosong di dalam blok ikut sebagai `\n`). Untuk `|`: baris digabung dengan `\n` + `\n` di akhir. Untuk `>`: baris digabung dengan spasi + `\n` di akhir. Varian `-` membuang `\n` akhir.

- [ ] **Step 1: Tulis fixture `constructs.yaml`**

```yaml
# komentar penuh di atas
feature: demo   # komentar di belakang
kosong:
quoted: "a: {b} # bukan komentar"
single: 'it''s'
flow: [T1, "a, b", 'c']
flow_empty: []
mentah: {x: 1}
nested:
  child:
    leaf: v
items:
  - create: src/a.ts
  - modify: src/b.ts
tasks:
  - id: T1
    deps: [T0]
    approach: |
      baris satu: ada titik dua
      baris dua - [bukan list]
    note: >-
      dilipat
      jadi satu
  - id: T2
    manual:
      - langkah satu
```

- [ ] **Step 2: Tulis `constructs.json` (hasil yang diharapkan)**

```json
{"feature":"demo","kosong":null,"quoted":"a: {b} # bukan komentar","single":"it's",
 "flow":["T1","a, b","c"],"flow_empty":[],"mentah":"{x: 1}",
 "nested":{"child":{"leaf":"v"}},
 "items":[{"create":"src/a.ts"},{"modify":"src/b.ts"}],
 "tasks":[{"id":"T1","deps":["T0"],"approach":"baris satu: ada titik dua\nbaris dua - [bukan list]\n","note":"dilipat jadi satu"},
          {"id":"T2","manual":["langkah satu"]}]}
```

`tab.yaml`: dua baris, `a:` lalu `<TAB>b: 1`.

- [ ] **Step 3: Tulis test `tools/tests/build-status.test.sh`**

Kerangka sama dengan `tools/tests/share.test.sh`: `ROOT`, `PASS`/`FAIL`, `ok`/`bad`, `PY="python3 -B"`, `BS="$ROOT/plugin/template/.claude/build_status.py"`, `FX="$ROOT/tools/tests/fixtures/build-status"`, exit 1 kalau ada yang gagal. Kasus:
```bash
# 1. konstruksi → JSON sama persis (bandingkan sebagai objek, bukan teks)
out="$($PY "$BS" --parse-yaml "$FX/yaml/constructs.yaml")"
$PY -c 'import json,sys; sys.exit(0 if json.loads(sys.argv[1])==json.load(open(sys.argv[2])) else 1)' "$out" "$FX/yaml/constructs.json" \
  && ok "parse-yaml konstruksi" || bad "parse-yaml konstruksi" "$out"
# 2. tab di indentasi → exit 2, stderr sebut nama file
err="$($PY "$BS" --parse-yaml "$FX/yaml/tab.yaml" 2>&1 >/dev/null)"; rc=$?
[ "$rc" = 2 ] && grep -q 'tab.yaml' <<<"$err" && ok "tab → exit 2" || bad "tab → exit 2" "rc=$rc $err"
```

- [ ] **Step 4: Jalankan test, pastikan GAGAL**

Run: `bash tools/tests/build-status.test.sh`
Expected: FAIL (file `build_status.py` belum ada).

- [ ] **Step 5: Implementasi `YamlError`, `parse_yaml`, `load_yaml`, dan `main(argv: list[str]) -> int` dengan `--parse-yaml`** di `plugin/template/.claude/build_status.py`

Header file: docstring singkat (tujuan, read-only, stdlib, dipakai mod + `drive.sh`, spec path). `if __name__ == "__main__": sys.exit(main(sys.argv[1:]))`. Pakai `argparse`.

- [ ] **Step 6: Jalankan test, pastikan LULUS**

Run: `bash tools/tests/build-status.test.sh`
Expected: `ok - parse-yaml konstruksi`, `ok - tab → exit 2`, exit 0.

- [ ] **Step 7: Commit**

```bash
git add plugin/template/.claude/build_status.py tools/tests/build-status.test.sh tools/tests/fixtures/build-status/yaml
git commit -m "feat(build-status): parser YAML subset stdlib + CLI --parse-yaml"
```

---

### Task 3: Snapshot v1 (`--format json`)

**Files:**
- Modify: `plugin/template/.claude/build_status.py`
- Modify: `tools/tests/build-status.test.sh`
- Create: `tools/tests/fixtures/build-status/prod/**` (pohon produk palsu, isinya di Step 1)

**Interfaces:**
- Consumes: `load_yaml` (Task 2).
- Produces: `snapshot(root: Path, now: float, work_item: str | None = None, quiet_min: int = 30) -> dict` · `weight(task: dict) -> int` · `fmt_dur(seconds: float) -> str` · CLI `--root PATH --format json [--work-item DIR] [--now EPOCH] [--quiet-min N]`. **Skema JSON v1 (dikunci; Task 6 mencerminkannya di TypeScript):**

```text
Snapshot  = { v: 1, items: Item[], alerts: Alert[], status_line: str|null }
Item      = { kind: "feature"|"fix", name, dir (relatif root), mode: "unattended"|"attended",
              drive: null | { round: int, elapsed: str, max: str },
              done: int, total: int, running: bool,
              lanes: Lane[], held: Held[], gates: Gate[],
              eta: null | { text: str, held_note: str|null },
              milestones: Milestone[], drive_line: str }
Milestone = { id, title, done: int, total: int, tasks: Task[] }
Task      = { id, unit, desc, status, elapsed: str|null, phase: "impl"|null, quiet: bool,
              quiet_for: str|null, reason: str|null, waiting_on: str[] }
Lane      = { id, unit, desc, elapsed, phase, quiet, quiet_for }        # task in_progress, urut dokumen
Held      = { id, unit, status: "blocked"|"needs_human", reason: str|null, blocks: str[] }
Gate      = { id, segment, reason }                                      # hanya status: queued
Alert     = { key: str, text: str }
```
`eta`, `status_line`, `drive_line`, dan `alerts` diisi Task 4. Di task ini isi `eta: null`, `drive_line: ""`, `alerts: []`, `status_line: null`. Field string yang absen di YAML → `""` (untuk `unit`/`desc`/`title`) atau `null` (untuk `reason`).

Aturan (spec §5):
- **Work-item:** `control/features/*/feature.yaml` `status: active` → kind `feature`, name = nama folder. `control/fixes/*/fix.yaml` `status` ∈ {`open`,`diagnosed`} → kind `fix`. Item butuh `tasks.yaml`.
- **Perlu ditampilkan** = minimal satu dari: ada task `in_progress`; heartbeat hidup; ada gate `queued`; ada task `blocked`/`needs_human`.
- `items` = yang perlu ditampilkan, urut mtime `tasks.yaml` terbaru dulu. Dengan `--work-item DIR`, `items` = persis item itu saja (walau nggak perlu ditampilkan, dan walau `tasks.yaml` belum ada: `total 0`, `milestones []`).
- **Scratch:** feature → `.claude/build/<name>/`. Fix → `.claude/build/fixes/<id>/`, fallback `.claude/build/<id>/`. Brief `task-<id>-brief.md`, report `task-<id>-report.md`.
- `elapsed` (task `in_progress`) = `fmt_dur(now − mtime brief)`; brief nggak ada → `null`.
- `phase` = `"impl"` hanya kalau brief ada **dan** report belum ada; selain itu `null`.
- **Heartbeat** `.claude/build/<name>/drive.json` (feature saja): `{"round","started","round_started","max_hours","pid"}`. Hidup = file ada **dan** `os.kill(pid, 0)` nggak melempar `ProcessLookupError` (`PermissionError` = hidup). Hidup → `mode "unattended"`, `drive = {round, elapsed: fmt_dur(now − started), max: f"{max_hours}j"}`. Selain itu `mode "attended"`, `drive null`.
- **Diam:** heartbeat nggak hidup **dan** `now − last_activity > quiet_min × 60`. `last_activity` = mtime terbesar dari `tasks.yaml`, `gates.yaml`, `last-run.md`, dan semua file langsung di folder scratch. Task `in_progress` yang diam → `quiet true`, `quiet_for = fmt_dur(now − last_activity)`.
- `running` = heartbeat hidup ATAU ada `in_progress` yang nggak diam.
- **Ketahan:** `held` = task `blocked`/`needs_human`. `reason` = `hold:`, kalau nggak ada pakai item pertama `manual:`, kalau nggak ada juga `null`. `blocks` = semua task belum-`done` yang `deps`-nya **transitif** mencapai task itu, urut dokumen. Task ber-status held di pohon dapat `reason` yang sama.
- `waiting_on` (task `pending`) = `deps` langsung yang belum `done`, urut seperti ditulis. Id yang nggak dikenal tetap masuk (dianggap belum done).
- Parse error file apa pun yang dibutuhkan → CLI exit 2 dan stderr memuat path file. Jangan ada keluaran parsial di stdout.
- `fmt_dur`: `< 60` detik → `"<1m"`; `< 3600` → `f"{m}m"` (m = floor menit); selainnya `f"{h}j{m}m"`, atau `f"{h}j"` kalau m = 0.

- [ ] **Step 1: Tulis fixture `prod/`**

- `control/workspace.yaml`: `topology: multi-repo`, `apps:` `{name: api, path: api}`, `{name: web, path: web}`; `packages: []`.
- `control/features/checkout-v2/feature.yaml`: `status: active`.
- `control/features/checkout-v2/tasks.yaml`: `feature: checkout-v2`, header komentar, lalu:
  - **M1 `Fondasi auth`:** T1 api "schema users", T2 api "session token" (ber-`approach: |` dua baris, `deps: [T1]`), T3 money "format uang", T4 web "login page" (`deps: [T2]`). Semua `done`.
  - **M2 `Checkout`:** T5 api "cart totals service", T6 api "session-bound cart", T7 web "cart page shell" (`done`); T8 api "checkout endpoint" (`in_progress`); T9 api "migrate orders" (`needs_human`, `hold: "migrate destructive — nunggu lo"`, `actions: [ {migrate: orders, kind: destructive} ]` dalam bentuk blok); T11 web "cart summary UI" (`in_progress`); T12 web "checkout button" (`pending`, `deps: [T9, T11]`); T13 `integration` "checkout roundtrip" (`pending`, `deps: [T8, T12]`).
  - Semua task punya `files:` 1–2 entri (bobot 1), kecuali T13.
- `control/features/checkout-v2/gates.yaml`: G1 `segment: api×M1` `status: approved`; G3 `segment: api×M2` `status: queued` `reason: "floor-scan T6 (token)"`.
- `control/features/checkout-v2/last-run.md`: header `outcome: review` / `done: 7` / `pending: 5` / `review: 1` / `blockers: 1` / `reason: gate antri`, lalu satu baris prosa.
- `control/features/old-done/`: `feature.yaml` `status: active`, `tasks.yaml` satu milestone dua task `done`, tanpa gates.
- `control/features/shipped-x/`: `feature.yaml` `status: shipped`, `tasks.yaml` satu task `in_progress`.
- `control/fixes/2026-10-01-null-guard/`: `fix.yaml` `status: open`, `tasks.yaml` satu milestone berisi dua task: `fix-null-guard` (unit web, `in_progress`), lalu `fix-cleanup` **tanpa** `unit` dan `desc` (`pending`, `deps: [T99]` — id yang nggak ada). Nggak ada `gates.yaml`.
- `.claude/build/checkout-v2/`: brief + report untuk T5, T6, T7, T11; brief saja untuk T8.
- `.claude/build/fixes/2026-10-01-null-guard/task-fix-null-guard-brief.md`.
- Folder `api/` dan `web/` masing-masing berisi `.keep`.

- [ ] **Step 2: Tambah helper test dan kasus snapshot di `build-status.test.sh`**

Helper: `mkprod` menyalin `$FX/prod` ke `$T/prod`, menjalankan `git init -q` di `api` dan `web`, lalu menyetel mtime lewat `setm <file> <detik-sebelum-NOW>` (`python3 -c 'import os,sys; t=int(sys.argv[2]); os.utime(sys.argv[1],(t,t))'`). Pakai `NOW=1800000000`, dan `snap() { $PY "$BS" --root "$T/prod" --format json --now $NOW "$@"; }`. Assertion dibaca dengan `jq`.

mtime (detik sebelum NOW):
- checkout `tasks.yaml` 60; T5 brief 4000 / report 3400; T6 brief 3300 / report 2580; T7 brief 2500 / report 1660; T8 brief 720; T11 brief 420 / report 120; `last-run.md` 100.
- fix `tasks.yaml` 3000; fix brief 3000.
- Dua kasus heartbeat: `drive.json` dengan `"pid": $$` (hidup) dan `"pid": 999999` (mati); isi lain `{"round":2,"started":NOW-4320,"round_started":NOW-600,"max_hours":6}`.

Kasus (masing-masing satu `ok`/`bad`):
```text
items[].name                         == ["checkout-v2","2026-10-01-null-guard"]   # old-done & shipped-x nggak ikut
items[0] .done/.total                == 7 / 12
items[0].lanes[].id                  == ["T8","T11"]
items[0].lanes[0] .phase/.elapsed    == "impl" / "12m"
items[0].lanes[1] .phase/.elapsed    == null / "7m"
items[0].held                        == [{"id":"T9","unit":"api","status":"needs_human","reason":"migrate destructive — nunggu lo","blocks":["T12","T13"]}]
items[0].gates                       == [{"id":"G3","segment":"api×M2","reason":"floor-scan T6 (token)"}]
items[0].milestones[] .done/.total   == [4,4] dan [3,8]
waiting_on T12 / T13                 == ["T9","T11"] / ["T8","T12"]
heartbeat hidup  → .mode/.drive      == "unattended" / {"round":2,"elapsed":"1j12m","max":"6j"}
heartbeat mati   → .mode/.drive      == "attended" / null
tanpa drive.json → items[1] (fix)    : lanes[0].quiet == true, quiet_for == "50m", running == false
items[1] task fix-cleanup            : unit == "", desc == "", waiting_on == ["T99"]; items[1].gates == []
--work-item control/features/old-done → items[].name == ["old-done"]
--work-item control/features/belum-ada (folder kosong + feature.yaml active) → total 0, milestones []
tasks.yaml checkout diberi baris ber-tab → exit 2, stderr memuat "checkout-v2/tasks.yaml"
gates.yaml checkout dihapus → items[0].gates == [] (nggak crash)
```

- [ ] **Step 3: Jalankan test, pastikan kasus baru GAGAL**

Run: `bash tools/tests/build-status.test.sh` → FAIL di kasus snapshot.

- [ ] **Step 4: Implementasi `snapshot`, `weight`, `fmt_dur`, dan `--format json`**

`weight` belum dipakai sampai Task 4, tapi didefinisikan di sini. Field `files` dihitung dari jumlah entri list `files:`.

- [ ] **Step 5: Jalankan test, pastikan LULUS semua**

Run: `bash tools/tests/build-status.test.sh` → exit 0.

- [ ] **Step 6: Commit**

```bash
git add plugin/template/.claude/build_status.py tools/tests/build-status.test.sh tools/tests/fixtures/build-status/prod
git commit -m "feat(build-status): snapshot v1 — work-item aktif, lane, ketahan, gate, heartbeat, diam"
```

---

### Task 4: ETA, teks ringkas, alert (`--format status|drive`)

**Files:**
- Modify: `plugin/template/.claude/build_status.py`
- Modify: `tools/tests/build-status.test.sh`

**Interfaces:**
- Consumes: `snapshot`, `weight`, `fmt_dur` (Task 3).
- Produces:
  - `estimate(rows: list[tuple[str, int, float | None]], samples: list[float]) -> tuple[float, float] | None`
  - `eta_text(low_s: float, high_s: float) -> str`
  - `status_line(item: dict, others: int) -> str`
  - `drive_line(item: dict) -> str`
  - `alerts_for(name: str, dir: str, held: list[dict], gates: list[dict], last_run: dict | None) -> list[dict]`, dengan `last_run` = `{"outcome", "review", "blockers", "reason", "mtime"}` hasil parse header `last-run.md` (field yang absen → `None`), atau `None` kalau file nggak ada
  - CLI `--format status` (cetak `status_line` atau baris kosong) dan `--format drive` (cetak `drive_line` item pertama atau baris kosong).
  - `snapshot` kini mengisi `eta`, `drive_line`, `status_line`, dan `alerts`.

Aturan (spec §6, D6):
- **Sampel** = untuk tiap task `done` yang punya brief **dan** report dengan mtime report > brief: `(report − brief) / weight(task)`.
- **`rows`** = task belum-`done` yang **bukan** held dan **bukan** anggota `blocks` held mana pun. Isinya `(lane_key, weight, elapsed_s)`; `elapsed_s` = `now − brief` untuk `in_progress`, `None` untuk `pending`.
- **`lane_key`:** `"__integration__"` kalau `unit == "integration"`. Selain itu toplevel git dari `<root>/<path unit>` (`git -C … rev-parse --show-toplevel`, path dari `apps[]`/`packages[]` di `workspace.yaml`, di-cache per pemanggilan). Gagal atau unit nggak dikenal → `"root"`.
- **`estimate`:** `None` kalau `len(samples) < 3` atau `rows` kosong.
  - Sampel diurutkan. `q(p)` = interpolasi linear di posisi `p × (n − 1)`.
  - `low_rate = q(0.25) × max(0.5, 1 − 1/n)`, `high_rate = q(0.75) × (1 + 1/n)`.
  - Per row: `low = max(0, w × low_rate − (elapsed or 0))`, `high = max(0, w × high_rate − (elapsed or 0))`.
  - Jumlahkan per `lane_key`. Hasil = `max` lane biasa + total `__integration__` (masing-masing untuk low dan high).
- **`eta_text`:** `lo = max(1, floor(low/60/5)×5)`, `hi = max(lo + 5, ceil(high/60/5)×5)` (dalam menit). Kalau `hi < 60` → `f"~{lo}–{hi}m"`. Kalau nggak → `f"~{M(lo)}–{M(hi)}"`, dengan `M(m)` = `"{m}m"` kalau < 60, selainnya `"{h}j{r}m"` atau `"{h}j"`.
- **`eta`** = `{text, held_note}`. `held_note = "+ " + ", ".join(id held) + " nunggu lo"` kalau ada held; selainnya `null`.
- **`status_line(item, others)`** = `f"{name} {done}/{total}"`, lalu bagian berikut kalau nonzero, masing-masing diawali `" · "`: `"{n} lane"`, `"{n} ketahan"`, `"{n} gate"`, `eta.text`, `"+{others} build lain"`. `snapshot.status_line` = untuk `items[0]` dengan `others = len(items) − 1`; `null` kalau `items` kosong.
- **`drive_line(item)`** = bagian-bagian berikut digabung `" · "`:
  1. `"putaran {round}"` (kalau ada `drive`)
  2. `"{done}/{total}"`, atau `"tasks.yaml belum ada"` kalau `total == 0` dan file-nya nggak ada
  3. `"▸ " + ", ".join(f"{id} {unit}")` untuk lanes
  4. `"⏸ {n}"` (held)
  5. `"◆ {n}"` (gates)
  6. `drive.elapsed`
  7. `"sisa " + eta.text`

  Bagian yang kosong dibuang.
- **Alert:** dihitung untuk **semua** work-item aktif (bukan cuma yang tampil), digabung di `snapshot.alerts`.
  - Held: key `held|{dir}|{id}|{status}|{reason or ''}`, text `⏸ {name} · {id} {status}` + `" — {reason}"` (kalau ada) + `", nahan {n} task"` (kalau n > 0).
  - Gate queued: key `gate|{dir}|{id}`, text `◆ {name} · gate {id} antri — {segment}: {reason}`.
  - Stop dari `last-run.md` dengan `outcome` ∈ {done, review, halt}: key `stop|{dir}|{outcome}|{int(mtime)}`. Text-nya:
    - `done` → `✓ {name} · build selesai — siap /ship`
    - `review` → `🔔 {name} · build berhenti — {review} gate + {blockers} blocker nunggu lo` (`?` kalau header absen)
    - `halt` → `⚠ {name} · build halt — {reason}`

- [ ] **Step 1: Tulis test fungsi murni** (impor modul lewat `importlib.util.spec_from_file_location` di `python3 -B -c`). Hasil `estimate` dibandingkan dengan toleransi `abs(a − b) < 1e-6` per komponen, bukan `==`, karena `1 − 1/3` nggak eksak di float.

```text
estimate([("api",1,None),("api",1,None)], [600,720,840])           == (880.0, 2080.0)
eta_text(880, 2080)                                                  == "~10–35m"
estimate([("api",1,720.0),("web",1,420.0)], [600,720,840])          == (20.0, 620.0)
eta_text(20, 620)                                                    == "~1–15m"
estimate([("api",1,None),("__integration__",3,None)], [600,600,600]) == (1600.0, 3200.0)
eta_text(1600, 3200)                                                 == "~25–55m"
eta_text(3000, 6000)                                                 == "~50m–1j40m"
estimate([("api",1,None)], [600,600])                                is None
fmt_dur(4320)=="1j12m"; fmt_dur(3600)=="1j"; fmt_dur(45)=="<1m"; fmt_dur(720)=="12m"
```

- [ ] **Step 2: Tulis test CLI terhadap fixture `prod/`** (mtime dan heartbeat hidup seperti Task 3)

```text
items[0].eta              == {"text":"~1–15m","held_note":"+ T9 nunggu lo"}
--format status           == "checkout-v2 7/12 · 2 lane · 1 ketahan · 1 gate · ~1–15m · +1 build lain"
--format drive --work-item control/features/checkout-v2
                          == "putaran 2 · 7/12 · ▸ T8 api, T11 web · ⏸ 1 · ◆ 1 · 1j12m · sisa ~1–15m"
--format drive --work-item control/features/belum-ada (+ drive.json hidup round 1, started NOW-30, di scratch-nya)
                          == "putaran 1 · tasks.yaml belum ada · <1m"
alerts[].key  ⊇ "held|control/features/checkout-v2|T9|needs_human|migrate destructive — nunggu lo",
                "gate|control/features/checkout-v2|G3",
                "stop|control/features/checkout-v2|review|1799999900"
alert stop .text          == "🔔 checkout-v2 · build berhenti — 1 gate + 1 blocker nunggu lo"
alert held .text          == "⏸ checkout-v2 · T9 needs_human — migrate destructive — nunggu lo, nahan 2 task"
last-run.md tanpa baris review:/blockers: → text stop memuat "? gate + ? blocker"
```

- [ ] **Step 3: Jalankan test, pastikan kasus baru GAGAL**

Run: `bash tools/tests/build-status.test.sh`

- [ ] **Step 4: Implementasi fungsi di Interfaces dan sambungkan ke `snapshot` + CLI**

- [ ] **Step 5: Jalankan test, pastikan LULUS semua**

Run: `bash tools/tests/build-status.test.sh` → exit 0.

- [ ] **Step 6: Commit**

```bash
git add plugin/template/.claude/build_status.py tools/tests/build-status.test.sh
git commit -m "feat(build-status): estimasi rentang, status_line, drive_line, alert"
```

---

### Task 5: `drive.sh` — precheck python, heartbeat, baris progres

**Files:**
- Modify: `plugin/template/.claude/drive.sh`
- Modify: `plugin/hooks/tests/drive.test.sh`
- Modify: `plugin/skills/upgrade/SKILL.md`, `plugin/skills/init/SKILL.md`

**Interfaces:**
- Consumes: CLI `build_status.py --root R --work-item control/features/<f> --format drive` (Task 4).
- Produces: `.claude/build/<fitur>/drive.json` = `{"round":N,"started":E,"round_started":E,"max_hours":H,"pid":P}` (dibaca Task 3). Env untuk test: `DRIVE_PYTHON` (default `python3`) dan `DRIVE_TICK` (default `5`).

Perilaku:
- **Precheck** (sesudah precheck yang sudah ada, sebelum loop):
  - `"$PY" -c 'import json'` gagal → stderr `[drive] STOP — butuh python3 buat baris progres (.claude/build_status.py).` + baris instruksi `Install python3 (macOS: xcode-select --install), lalu ulang drive.sh.` → `exit 1`.
  - `.claude/build_status.py` nggak ada → stderr `[drive] STOP — .claude/build_status.py belum ada; jalankan 'upgrade' dulu.` → `exit 1`.
- **Heartbeat:** ditulis di awal tiap putaran, lewat tulis ke `drive.json.tmp` lalu `mv`. Dihapus di trap `EXIT`.
- **Ticker:** dijalankan di latar sebelum `claude -p`, lalu dimatikan sesudahnya. Tiap `DRIVE_TICK` detik, ticker memanggil pembaca. Kalau stdout TTY (`[ -t 1 ]`): `printf '\r\033[K[drive] %s'`. Kalau bukan: cetak `[drive] %s\n` hanya waktu isinya berubah. Keluaran kosong atau gagal → jangan cetak apa pun.
  - `sleep` di ticker dijalankan sebagai `sleep "$TICK" & wait $!`, dengan `trap` TERM yang membunuh `sleep` itu. Tujuannya supaya stdout nggak tertahan.
  - `stop_ticker` = `kill` + `wait`, lalu `printf '\n'` kalau TTY.
- **Output `claude -p`** ditampung dulu (`out="$(…)" || true`), lalu dicetak sesudah ticker berhenti (kalau nggak kosong). Ini supaya nggak tabrakan dengan baris `\r`.
- `trap 'stop_ticker; rm -f "$HB" "$HB.tmp"' EXIT` dan `trap 'exit 130' INT TERM`.
- Komentar header `drive.sh` ditambah satu paragraf soal baris progres + heartbeat (gaya komentar yang sudah ada).

- [ ] **Step 1: Ubah `setup()` di `drive.test.sh`**

Tambahkan: salin `$ROOT/plugin/template/.claude/build_status.py` ke `$PROD/.claude/`, tulis `control/features/fitur-x/feature.yaml` (`status: active`), dan tulis `tasks.yaml` minimal (satu milestone, T1 `done`, T2 `pending`). Jalankan test lama dan pastikan semuanya masih `ok`.

- [ ] **Step 2: Tulis test baru**

```text
a. claude palsu (mode "slow": sleep 1.2 lalu tulis last-run done:2) + DRIVE_TICK=0.3, stdout ke file (non-TTY)
   → output memuat baris diawali "[drive] putaran 1 · 1/2"
b. claude palsu menyalin drive.json ke $PROD/.claude/hb-seen saat dipanggil
   → hb-seen ada, jq .round == 1, .max_hours == 1; SESUDAH drive selesai: $PROD/.claude/build/fitur-x/drive.json TIDAK ada
c. drive dijalankan di latar dengan stdout ke file; sesudah `wait` PID-nya, tunggu 1 detik
   → ukuran file nggak berubah lagi (ticker & sleep-nya sudah mati), dan drive selesai < 5 detik
d. DRIVE_PYTHON=/nonexistent → exit ≠ 0, output memuat "butuh python3", calls == 0
e. build_status.py dihapus dari $PROD/.claude → output memuat "jalankan 'upgrade'", calls == 0
```
Untuk mode lambat, perluas `claude` palsu: token skenario boleh berawalan `slow:`. Sebelum menulis last-run, `claude` palsu tidur 1.2 detik dan menyalin `drive.json` (kalau ada) ke `.claude/hb-seen`.

- [ ] **Step 3: Jalankan test, pastikan kasus baru GAGAL**

Run: `bash plugin/hooks/tests/drive.test.sh`

- [ ] **Step 4: Implementasi di `drive.sh`**

- [ ] **Step 5: Jalankan test, pastikan LULUS semua (lama + baru)**

Run: `bash plugin/hooks/tests/drive.test.sh` → exit 0.

- [ ] **Step 6: Edit prosa `upgrade/SKILL.md` (tiga anchor, cek `grep -Fc` = 1 dulu)**

- Old: `` `.claude/hooks/*.sh`, `.claude/drive.sh`, bagian template `settings.json` ``
  New: `` `.claude/hooks/*.sh`, `.claude/drive.sh`, `.claude/build_status.py` (pembaca status build — dipakai baris progres `drive.sh`), bagian template `settings.json` ``
- Old: ``- `.claude/drive.sh` — ada? executable?``
  New: ``- `.claude/drive.sh` — ada? executable?`` + baris baru ``- `.claude/build_status.py` — ada? (dipanggil `drive.sh` lewat `python3`; tak perlu executable)``
- Old: ``- **hooks/ + drive.sh** hilang → copy dari template + `chmod +x`. Ada tapi beda → tampilkan diff, GATE ganti (file generik plugin).``
  New: ``- **hooks/ + drive.sh + build_status.py** hilang → copy dari template (`chmod +x` untuk `.sh`). Ada tapi beda → tampilkan diff, GATE ganti (file generik plugin). `drive.sh` baru menolak jalan tanpa `build_status.py` — susulin berdua.``

- [ ] **Step 7: Edit prosa `init/SKILL.md` (satu anchor)**

- Old: ``**dan** `drive.sh` (outer-loop driver bash untuk `build --unattended` berkelanjutan — build reference §H).``
  New: ``**dan** `drive.sh` (outer-loop driver bash untuk `build --unattended` berkelanjutan — build reference §H) + `build_status.py` (pembaca status build untuk baris progres `drive.sh` & panel; butuh `python3`).``

- [ ] **Step 8: Commit**

```bash
git add plugin/template/.claude/drive.sh plugin/hooks/tests/drive.test.sh plugin/skills/upgrade/SKILL.md plugin/skills/init/SKILL.md
git commit -m "feat(drive): baris progres live + heartbeat drive.json + precheck python3"
```

---

### Task 6: Mod inti — poll, status line, toast, auto-open

**Files:**
- Create: `plugin/types/index.d.ts`, `plugin/hooks/panel/snapshot.ts`, `plugin/hooks/panel/alerts.ts`, `plugin/hooks/register.tsx`, `plugin/hooks/tests/panel.test.tsx`
- Modify: `plugin/hooks/hooks.json` (tambah `"modules": ["./register.tsx"]`, pertahankan blok `hooks` auto-title apa adanya)
- Modify: `plugin/.claude-plugin/plugin.json` (tambah `"types": "./types/index.d.ts"`)

**Interfaces:**
- Consumes: skema JSON v1 (Task 3/4). Skrip ada di `${$.plugin.root}/template/.claude/build_status.py`.
- Produces:
  - `types/index.d.ts` meng-export `SnapTask`, `SnapLane`, `SnapHeld`, `SnapGate`, `SnapMilestone`, `SnapItem`, `Alert`, `Snapshot` (cermin persis skema Task 3, `v: 1`), plus `declare module 'claude-code' { interface PluginState { 'context-vault': { snapshot: Snapshot | null; error: string | null; seen: string[] | null; wasRunning: boolean } } }`.
  - `parseSnapshot(stdout: string): Snapshot | null` (`snapshot.ts`): `JSON.parse`, lalu valid hanya kalau `v === 1` dan `items` serta `alerts` berupa array. Gagal → `null`.
  - `nextAlerts(seen: string[] | null, alerts: Alert[]): { toast: string | null; seen: string[] }` (`alerts.ts`):
    - `seen === null` → `toast null`, `seen` = semua key (baseline).
    - Selainnya, `fresh` = alert yang key-nya belum ada di `seen`. `toast` = `null` kalau `fresh` kosong; `fresh[0].text` kalau satu; `` `${fresh[0].text} (+${fresh.length - 1} lagi)` `` kalau lebih. `seen` = `[...seen, ...key fresh].slice(-500)`.
  - Konstanta `PANE = 'cv-build'`, `TITLE = 'context-vault · build'`, `POLL_MS = 3000`.
  - Atom: `{ plugin: 'context-vault', key: 'snapshot' | 'error' | 'seen' | 'wasRunning' } as const`.

Perilaku `register.tsx`:
- **`session.start`:**
  - `e.isInteractive === false` → `return next(e)` (nol op lain).
  - `!(await $.fs.exists('control/workspace.yaml'))` → `return next(e)`.
  - Selainnya: `$.command.register({ name: 'cv-panel', description: 'context-vault: buka/tutup panel status build' })`, **await** satu `poll()`, arm `$.clock.every(POLL_MS, …)` dengan guard `busy` (lewati tick kalau poll sebelumnya belum selesai), lalu `return next(e)`.
- **`poll()`:**
  - `$.process.run(['python3', script, '--root', e.cwd, '--format', 'json'], { cwd: e.cwd, timeoutMs: 5000 })`.
  - Reject → set `error = 'butuh python3'`, `$.ui.status(undefined)`, selesai.
  - `exitCode !== 0` atau `parseSnapshot` null → biarkan state lama (jangan ubah snapshot/status), selesai.
  - Sukses → set `snapshot`, set `error = null`, lalu `$.ui.status(snap.status_line ?? undefined)`.
  - Alert: `nextAlerts(seen, snap.alerts)` → simpan `seen`; kalau ada `toast` → `$.ui.toast(toast, { timeoutMs: 8000 })`.
  - Auto-open: `running = snap.items[0]?.running ?? false`. Kalau `running && !wasRunning` → `$.ui.open({ id: PANE, title: TITLE })`. Simpan `wasRunning = running`.
- **`command.run` (`cv-panel`):** dibuat di Task 7. Di task ini cukup register.

- [ ] **Step 1: Tulis `panel.test.tsx` — kasus inti**

Pola test mengikuti contoh yang sudah terverifikasi: jawab `session.start`, `fs.exists`, `process.run`, `ui.status`, `ui.toast`, `ui.open`, `command.register` dengan `on(...)`. `mock.clock(on)`. Snapshot fixture ditulis sebagai konstanta TS di file test, yaitu objek `Snapshot` minimal plus `JSON.stringify` untuk stdout `process.run`. `process.run` dijawab berurutan lewat antrian di closure.
```text
1. headless: $.session.start({cwd:'/p', surface:null, isInteractive:false}) → process.run dipanggil 0×, command.register 0×
2. bukan produk: fs.exists → false → process.run 0×
3. poll pertama: status terakhir == snapA.status_line; toasts == [] (baseline walau snapA.alerts tidak kosong)
4. alert baru: tick ke-2 → snapB (alert snapA + 1 baru) → toasts == [teks alert baru]; tick ke-3 snapB lagi → toasts tetap 1
5. dua alert baru sekaligus → satu toast diakhiri " (+1 lagi)"
6. exitCode 2 sesudah snapA → status nggak berubah (tetap snapA.status_line), state snapshot tetap snapA
7. process.run reject → state error == 'butuh python3', status terakhir undefined
8. auto-open: snap running:true → ui.open 1×; tick running:true lagi → tetap 1×; running:false lalu true → 2×
9. nextAlerts murni: (null, [a]) → toast null; (['a'], [a,b]) → toast b.text, seen ['a','b']
```
Tick dipicu dengan `await clock.advance(3000)`, ditambah `await clock.settle()` kalau perlu.

- [ ] **Step 2: Jalankan test, pastikan GAGAL**

Run: `claude plugin test plugin`
Expected: FAIL (module belum ada).

- [ ] **Step 3: Implementasi `types/index.d.ts`, `snapshot.ts`, `alerts.ts`, `register.tsx`, dan edit `hooks.json` + `plugin.json`**

- [ ] **Step 4: Validasi dan test**

Run: `claude plugin validate plugin` → `✔ Validation passed`, daftar hooks memuat `session.start`, dan blok `UserPromptSubmit` auto-title tetap terbaca.
Run: `claude plugin test plugin` → semua kasus Task 6 lulus.
Run: `bash plugin/hooks/tests/auto-title.test.sh` → tetap lulus.

- [ ] **Step 5: Commit**

```bash
git add plugin/types plugin/hooks/panel/snapshot.ts plugin/hooks/panel/alerts.ts plugin/hooks/register.tsx plugin/hooks/tests/panel.test.tsx plugin/hooks/hooks.json plugin/.claude-plugin/plugin.json
git commit -m "feat(panel): mod context-vault — poll build_status, status line, toast dedup, auto-open"
```

---

### Task 7: Isi panel + `/cv-panel`

**Files:**
- Create: `plugin/hooks/panel/rows.ts`
- Modify: `plugin/hooks/register.tsx`, `plugin/hooks/tests/panel.test.tsx`

**Interfaces:**
- Consumes: atom `snapshot`/`error`, tipe `Snapshot` (Task 6).
- Produces:
  - `type Row = { text: string; color?: string; dim?: boolean }`
  - `paneRows(snap: Snapshot | null, error: string | null): Row[]`
  - `bar(done: number, total: number, width: number): string` = `'█'.repeat(f) + '░'.repeat(width − f)`, dengan `f = total ? round(done / total × width) : 0` (di-clamp).

`paneRows` (spec §4, D4a). Dari `items[0]` = `it`:
- `error` ≠ null → `[{ text: 'Panel butuh python3 — install dulu (macOS: xcode-select --install).', color: 'warning' }]`.
- `snap` null → `[{ text: 'Nunggu data…', dim: true }]`.
- `items` kosong → `[{ text: 'Nggak ada build jalan.', dim: true }]`.
- **Header:** `` `${it.name}  ${it.drive ? `unattended · putaran ${it.drive.round}` : 'attended'}` ``. Kalau `items.length > 1`, tambah baris `` `+${items.length - 1} build lain` `` (dim).
- **Progres:** `` `${bar(done, total, 12)} ${done}/${total}` `` + (eta ? `` `  sisa ${eta.text}` `` : '') + (eta?.held_note ? `` ` ${eta.held_note}` `` : '').
- **Ringkasan** (baris yang nol dihilangkan):
  - `` `▸ ${lanes.length} jalan ${lanes.map(l => `${l.id} ${l.unit}`).join(' · ')}` `` (color `suggestion`).
  - Per held: `` `⏸ ${id} ketahan` `` + (blocks.length ? `` ` · nahan ${blocks.join(', ')}` `` : '') (color `warning`).
  - `` `◆ ${gates.length} gate antri` `` (color `permission`).
- **Baris kosong.**
- **Milestone:**
  - Semua `done` → `` `✓ ${id} ${title}  ${done}/${total}` `` (color `success`).
  - Selainnya `` `${id} ${title}  ${bar(done, total, 8)}  ${done}/${total}` ``, lalu semua task-nya: `` ` ${icon} ${id.padEnd(4)} ${u.padEnd(4)} ${desc}` `` + akhiran. `u` = `'int'` untuk `integration`, selainnya unit.
  - Ikon: `✓` done (success), `▸` in_progress (suggestion), `⏸` blocked/needs_human (warning), `·` pending (dim).
  - Akhiran: in_progress → quiet ? `` ` diam ${quiet_for}` `` : `` ` ${phase ? phase + ' ' : ''}${elapsed ?? ''}` `` (trim kanan). Held → `` ` ${status}` ``, lalu baris tambahan `` `          ${reason}` `` (dim) kalau ada reason. Pending dengan `waiting_on` → `` ` nunggu ${waiting_on.join(', ')}` ``.
- **Gate:** baris kosong lalu per gate `` `◆ ${id} ${segment}  ${reason}` `` (color `permission`).
- **Footer:** `drive` → `` `jalan ${drive.elapsed} / maks ${drive.max}` `` (dim).

Render: hook `ui.render` `{ component: 'Pane', requestId: PANE }` → baca atom `snapshot` dan `error`, lalu `<Box flexDirection="column">` berisi satu `<Text wrap="truncate-end" color={r.color} dimColor={r.dim}>` per row. Kalau `text` kosong, isi spasi satu.

`command.run` `cv-panel`: `const shown = (await $.ui.panes()).some(p => p.id === PANE && p.isShown)`. Kalau `shown` → `$.ui.close({ id: PANE })` dan kembalikan `{ text: 'Panel build ditutup.' }`. Selainnya → `$.ui.open({ id: PANE, title: TITLE })` dan kembalikan `{ text: 'Panel build dibuka.' }`.

- [ ] **Step 1: Tulis test**

```text
paneRows murni (snapshot fixture = data contoh spec §4 tengah build, + items[1] supaya "+1 build lain"):
  - ada row text == "checkout-v2  unattended · putaran 2"
  - ada row text == "+1 build lain"
  - ada row diawali "✓ M1 Fondasi auth" dan diakhiri "4/4"; nggak ada row yang memuat " T1 " (milestone kelar dilipat)
  - ada row text == "          migrate destructive — nunggu lo"
  - row T12 diakhiri "nunggu T9, T11"
  - row T13 memuat " int  "
  - ubah T8 jadi quiet:true, quiet_for:"40m" → row T8 diakhiri "diam 40m"
  - ada row text == "jalan 1j12m / maks 6j"
  - paneRows(null,'butuh python3')[0].text diawali "Panel butuh python3"
  - snapshot items [] → [{text:'Nggak ada build jalan.', dim:true}]
  - bar(3,8,8) == "███░░░░░"; bar(0,0,4) == "░░░░"
mount: sesudah poll snapA → $.ui.mount({plugin:'context-vault', surface:'terminal', component:'Pane', requestId:'cv-build',
       props:{title:'context-vault · build', isFocused:false, bodyColumns:60, placement:'inline', scroll:{offset:0, bodyRows:30}, view:{}}})
       → find({type:'Text', text:/^checkout-v2  /}) ada
command: panes() → [] → $.command.run({command:'cv-panel'}).text == 'Panel build dibuka.' dan ui.open dipanggil;
         panes() → [{id:'cv-build', isShown:true, …}] → text == 'Panel build ditutup.' dan ui.close dipanggil
```

- [ ] **Step 2: Jalankan test, pastikan GAGAL**

Run: `claude plugin test plugin`

- [ ] **Step 3: Implementasi `rows.ts`, hook render, dan `command.run`**

- [ ] **Step 4: Validasi dan test**

Run: `claude plugin validate plugin` → passed.
Run: `claude plugin test plugin` → semua lulus (Task 6 + 7).

- [ ] **Step 5: Commit**

```bash
git add plugin/hooks/panel/rows.ts plugin/hooks/register.tsx plugin/hooks/tests/panel.test.tsx
git commit -m "feat(panel): isi panel per milestone + perintah /cv-panel"
```

---

### Task 8: Dokumentasi, versi, regen Kimi

**Files:**
- Modify: `README.md`, `plugin/skills/guide/reference.md`, `plugin/.claude-plugin/plugin.json`
- Regenerate: `plugin-kimi/**`

- [ ] **Step 1: README — sisip paragraf sesudah paragraf "Mode tanpa pengawasan"**

Anchor (cek `grep -Fc` = 1): ``driver berhenti dengan `outcome: review` saat tak ada lagi yang bisa dibangun.``
Sisipkan sesudah baris itu, dipisah baris kosong:
```markdown
> **Pantau progres build:** di sesi Claude Code, panel **context-vault · build** kebuka sendiri waktu ada build jalan (`/cv-panel` buka/tutup manual) — task ke berapa, lane yang jalan paralel, yang ketahan + alasannya, gate antri, dan estimasi sisa (rentang, muncul sesudah 3 task kelar). Status line satu baris + toast waktu ada yang nyangkut. Di terminal `drive.sh` ada satu baris progres yang update di tempat. Read-only, butuh `python3`. Panel cuma ada di Claude Code (Kimi: baris `drive.sh` saja).
```

- [ ] **Step 2: guide/reference.md — tambah kalimat di entri `/build`**

Anchor: ``blocker cuma nahan subtree-nya.`` di baris yang diawali ``- `/build` —`` (cek `grep -Fc` = 1 terhadap kutipan baris penuh).
New: tambahkan di akhir baris itu: `` Pantau progres: panel `context-vault · build` (auto saat build jalan, `/cv-panel` manual) + status line + toast; unattended: baris progres live di terminal `drive.sh`. ``

- [ ] **Step 3: plugin.json — versi + deskripsi**

- Bump **minor** dari `version` yang ada di HEAD saat ini (0.24.0 → 0.25.0; kalau plan lain sudah bump, naikkan minor sekali lagi).
- Di `description`, sisipkan `panel status build (mod: panel + status line + toast, /cv-panel; baris progres live drive.sh), ` tepat sebelum `auto-title session`.
- Validasi: `jq . plugin/.claude-plugin/plugin.json`.

- [ ] **Step 4: Regen Kimi dan jalankan semua test**

```bash
bash tools/build-kimi.sh
bash tools/tests/build-kimi.test.sh
test -f plugin-kimi/template/.claude/build_status.py && echo ok-template
test ! -e plugin-kimi/hooks && test ! -e plugin-kimi/types && echo ok-no-mod
bash tools/tests/build-status.test.sh
bash plugin/hooks/tests/drive.test.sh
bash plugin/hooks/tests/auto-title.test.sh
claude plugin validate plugin
claude plugin test plugin
```
Expected: semua exit 0, ditambah `ok-template` dan `ok-no-mod`.

- [ ] **Step 5: Commit**

```bash
git add README.md plugin/skills/guide/reference.md plugin/.claude-plugin/plugin.json plugin-kimi
git commit -m "chore(release): panel status build + baris progres drive.sh — docs, versi, regen plugin-kimi"
```

---

### Task 9: Acceptance terhadap produk nyata (read-only)

Nggak ada file yang diubah di produk mana pun. Semua perintah cuma membaca.

- [ ] **Step 1: Bandingkan parser dengan PyYAML di semua file nyata**

```bash
python3 -B - <<'PY'
import glob, importlib.util, os, yaml
spec = importlib.util.spec_from_file_location("bs", "plugin/template/.claude/build_status.py"); bs = importlib.util.module_from_spec(spec); spec.loader.exec_module(bs)
def view(doc):
    out = []
    for m in (doc or {}).get("milestones") or []:
        for t in m.get("tasks") or []:
            out.append((str(m.get("id")), str(m.get("title")), str(t.get("id")), str(t.get("unit")), str(t.get("status")),
                        [str(d) for d in (t.get("deps") or [])], str(t.get("hold")), len(t.get("files") or []), bool(t.get("mockup"))))
    for g in (doc or {}).get("gates") or []:
        out.append((str(g.get("id")), str(g.get("segment")), str(g.get("status")), str(g.get("reason"))))
    return out
files = sorted(glob.glob(os.path.expanduser("~/Developer/project/*/control/features/*/tasks.yaml")) +
               glob.glob(os.path.expanduser("~/Developer/project/*/control/fixes/*/tasks.yaml")) +
               glob.glob(os.path.expanduser("~/Developer/project/*/control/features/*/gates.yaml")))
bad = [f for f in files if view(bs.parse_yaml(open(f).read())) != view(yaml.safe_load(open(f)))]
print(len(files), "file;", len(bad), "beda"); [print("BEDA", f) for f in bad]
PY
```
Expected: `0 beda` (saat plan ditulis, ada 36 file). Kalau ada yang beda: perbaiki parser + tambah kasus ke `constructs.yaml` (Task 2), jalankan ulang semua test, lalu commit `fix(build-status): …`.

- [ ] **Step 2: Jalankan pembaca di tiap produk nyata**

```bash
for d in ~/Developer/project/*/; do [ -f "$d/control/workspace.yaml" ] || continue
  printf '%s: ' "$(basename "$d")"
  python3 -B plugin/template/.claude/build_status.py --root "$d" --format json >/dev/null && \
    python3 -B plugin/template/.claude/build_status.py --root "$d" --format status; done
```
Expected: nggak ada exit ≠ 0 dan nggak ada traceback. Tiap baris berisi status line atau kosong.

- [ ] **Step 3: Cek manual oleh user (catat hasilnya di laporan, jangan diklaim lulus tanpa konfirmasi)**

Minta user menjalankan `claude --plugin-dir /Users/mac-098506/Developer/project/context-vault/plugin` dari root produk nyata (misal KuyMahjong), lalu `/cv-panel`. Yang dicek:
- panel tampil, dengan milestone kelar terlipat;
- status line muncul kalau ada work-item yang perlu ditampilkan;
- nggak ada toast waktu sesi baru dibuka.

Kedua, cek jalur install yang dipakai sehari-hari (spec §10.3). Di sesi biasa (tanpa `--plugin-dir`), jalankan `/plugin marketplace update` untuk marketplace context-vault (yang menunjuk ke repo ini, dengan branch ini ter-checkout), lalu update atau install ulang plugin `context-vault`, restart sesi, dan buka `/cv-panel`. Panel harus tampil dengan cara yang sama. Kalau nggak tampil, padahal `--plugin-dir` jalan, berarti hooks module nggak termuat dari plugin terinstall. Catat itu sebagai temuan blocker.

Laporkan hasil kedua cek apa adanya.
