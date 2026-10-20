# Controller `build` Ramping — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sesi controller `/build` mulai kecil (median ≤ 95K di dispatch implementer pertama, sekarang ~181K) dan nggak numpuk per task (≤ 10K/dispatch, sekarang ~30K), tanpa bikin controller kehilangan peta seluruh task.

**Architecture:** Controller berhenti membaca isi file besar. (1) `build_status.py` (sudah ke-copy ke tiap produk) dapat tiga format baru: `controller` (peta + READY + hold + gate + staleness + reuse basi + jumlah titipan), `task` (entri task lengkap), `carry` (titipan aktif). (2) Agent baru `brief-writer` yang merakit brief per task; controller nggak lagi baca kode/skema/mockup/plan. (3) `reference.md` dipecah jadi indeks + file per section yang dibaca saat step-nya. (4) Titipan antar-task diresmikan jadi `<work-item>/carry.yaml`. (5) Template superpowers diserahkan by-path ke subagent, reviewer balikin verdict ringkas, paket diff selalu lewat git (benerin drift `review-package` superpowers 6.2).

**Tech Stack:** Python 3 stdlib (≥ 3.9, tanpa PyYAML) · Bash · prosa skill Markdown · test bash pola counter `ok`/`bad` · `jq` · `tools/build-kimi.sh`.

**Spec:** `docs/superpowers/specs/2026-10-20-build-lean-controller-design.md` (commit `d446eff`). Baca dulu; `D<n>` dan `§<n>` di bawah menunjuk spec itu.

## Global Constraints

- **Working dir:** `/Users/mac-098506/Developer/project/context-vault`. Branch `feat/build-lean-controller` dari `main` (≥ `d446eff`).
- **Anchor:** semua edit prosa di-anchor ke kutipan teks, bukan nomor baris. Sebelum tiap Edit: `grep -Fc -- '<old_string>' <file>` HARUS `1` (untuk old_string multi-baris: `python3 -c 'import sys;print(open(sys.argv[1]).read().count(sys.argv[2]))' <file> "<old>"`). `0` atau `>1` → STOP dan lapor, jangan tebak. Semua anchor di plan ini sudah diverifikasi = 1 di `d446eff`.
- **Commit tiap task:** pesan Indonesian + prefix conventional-commits, **TANPA** trailer `Co-Authored-By`.
- **Jangan edit `plugin-kimi/`** dengan tangan. Regen di Task 9.
- **`build_status.py`:** tetap read-only total (nggak menulis file apa pun), stdlib-only, Python ≥ 3.9. Output `--format json|status|drive` dan `--parse-yaml` **byte-identik** untuk input yang sama: `bash tools/tests/build-status.test.sh` lulus TANPA mengubah satu baris pun test/fixture lamanya.
- **Unattended nggak boleh dapat permission prompt baru.** Di Claude Code hanya wildcard `:*` di ujung yang bekerja. Path plugin-cache bernomor versi NGGAK pernah muncul di perintah Bash.
- **`plugin.json`:** cuma nilai `version` dan `description` yang berubah. Jangan tambah key.
- **Batas review 3 ronde tidak diubah, dan re-review tetap review penuh dari nol (D12).** `re-review-prompt.md` dan resume implementer upstream NGGAK diadopsi (D11).
- **Nilai yang dipatok (dipakai lintas task):**
  - Format baru: `--format controller|task|carry`. Ketiganya WAJIB `--work-item <dir>` (relatif root), absen → exit 2, stderr `build_status: --format <f> butuh --work-item`.
  - Desc di peta dipotong ke 80 karakter: >80 → 79 karakter pertama + `…`.
  - Header `carry.yaml` (baris pertama, persis): `# carry.yaml — titipan antar-task build. Penulis tunggal: controller build. Entri terbaru di ATAS.`
  - Target titipan: id task · `gate:<M>` · `gate:<M>/<unit>` · `ship` · `simplify`.
  - Agent: `name: brief-writer` (dipanggil `context-vault:brief-writer`), `model: inherit`. Balikan ≤ 10 baris, kunci `brief`/`rules`/`titipan`/`deps`/`ambigu`/`tier`.
  - Verdict reviewer ≤ 12 baris, file review `<root>/.claude/build/<work-item>/task-<id>-review-r<n>.md`.
  - Bukti ⚠️ dicek controller sendiri kalau ≲ 2K karakter per item. Lebih dari itu → subagent read-only.
  - Allowlist: `Bash(python3 .claude/build_status.py:*)`.
  - Versi rilis `0.28.0`.
- **Keputusan plan yang menajamkan/menyimpang dari spec** (reviewer: ini disengaja):
  1. **Rujukan silang di skill lain nggak diedit** (spec §4.6 mendaftar `conventions.md`, `ask-user.md`, `design-system`, `fix`). `reference.md` jadi indeks yang memetakan §A–§K ke file, jadi semua rujukan "`build/reference.md` §X" tetap sah. Yang diedit cuma test yang nge-grep **isi** `reference.md`.
  2. **§J = ringkasan state + titipan** (spec menyebut §J = carry), dan ada **§K baru = bentuk prompt dispatch** tiap subagent. Spec meminta contoh prompt implementer dipindah ke section yang dibaca controller; §K itu tempatnya.
  3. **`carry.yaml` entri terbaru di ATAS.** Tujuannya biar controller bisa nambah entri cuma dengan Read `limit: 3` + Edit baris `notes:`, tanpa baca file utuh. Spec menyerahkan mekanisme tulis ke builder (§6).
  4. **`<sdd>`** (folder `subagent-driven-development` superpowers) di-resolve pakai tool **Glob**, bukan Bash.
  5. **`_rules-<repo>.md`** tinggal di folder scratch work-item yang sama dengan brief. `<repo>` = basename toplevel git unit.
  6. **Tulis status `tasks.yaml` tanpa baca utuh** = Grep `- id: <id>$` → Read rentang → Edit blok (reference §E).

## Review Focus

1. **Data nyata yang nggak rapi** bikin peta salah atau crash: task tanpa `unit`/`desc`, `deps` ke id tak dikenal, `reuse:` di unit yang nggak ada di `workspace.yaml`, proyeksi skema absen/stub, `stack` berbentuk flow map `{ db: main }`. Harapannya nggak crash dan nggak ada "reuse basi" palsu. Dipatok di Task 3 (kasus fixture `lean`).
2. **Produk lama** (salinan `build_status.py` lama, atau allowlist tanpa entri baru) di run unattended: controller NGGAK memanggil script (permission prompt = beku), jalan cara lama, dan WARN di `last-run.md`. Dipatok di Task 7 (grep kontrak SKILL) dan Task 10 Step 2 (salinan lama mahjong → exit 2).
3. **Fitur in-flight dengan `_carry-notes.md` lama** (venue-tables, 30 task belum done): titipan tetap sampai ke brief, titipan buat task yang udah done nggak muncul. Dipatok di Task 2 (fixture legacy) dan Task 10 Step 3 (venue-tables nyata).
4. **Ambiguitas yang nggak bisa dijawab controller saat unattended** → task `needs_human` + `hold: "NEEDS_CONTEXT: …"`, bukan dibiarkan `in_progress`, bukan nebak. Dipatok di Task 7 (grep kontrak).
5. **Output lama berubah tanpa sengaja** (panel/`drive.sh` beda angka). Dipatok di tiap task yang menyentuh `build_status.py`: test lama lulus tanpa diubah, dan dua kali `--format controller` identik (Task 3).

---

## File Structure

| file | tanggung jawab | task |
|---|---|---|
| `tools/measure-build-context.py` **(BARU)** + `tools/tests/measure-build-context.test.sh` **(BARU)** | ukur context & kualitas sesi build dari transcript | T1 |
| `plugin/template/.claude/build_status.py` | + `--format task|carry|controller` | T2, T3 |
| `tools/tests/build-status.test.sh` + `tools/tests/fixtures/build-status/lean/**` **(BARU)** | test format baru (fixture terpisah dari `prod/`) | T2, T3 |
| `plugin/template/.claude/settings.json`, `plugin/skills/upgrade/SKILL.md` | allowlist + catatan susulan | T3 |
| `plugin/skills/build/reference.md` → indeks; `plugin/skills/build/reference/{a..i}-*.md` **(BARU, isi dipindah)** | pecah reference | T4 |
| `tools/tests/build-lean.test.sh` **(BARU)** | kontrak prosa (grep) | T4–T8 |
| `tools/tests/ask-user.test.sh`, `tools/build-kimi.sh`, `tools/tests/build-kimi.test.sh` | ikut pecahan reference + mapping brief-writer | T4, T5 |
| `plugin/agents/brief-writer.md` **(BARU)**, `reference/k-prompt-dispatch.md` **(BARU)**, `reference/b-brief.md` | brief-writer + bentuk prompt dispatch | T5 |
| `reference/j-state-titipan.md` **(BARU)**, `plugin/skills/build/SKILL.md` (step 1 legacy, 2, 6, 7a), `plugin/skills/ship/SKILL.md` | titipan resmi | T6 |
| `plugin/skills/build/SKILL.md` (step 1–3, catatan), `reference/e-status-resume.md` | controller pakai peta + brief-writer | T7 |
| `plugin/skills/build/SKILL.md` (step 4), `reference/a-pinjam-sdd.md`, `reference/e-status-resume.md` | jalur review | T8 |
| `plugin/skills/guide/reference.md`, `plugin/.claude-plugin/plugin.json`, `plugin-kimi/**` | rilis | T9 |
| — | acceptance read-only + probe headless | T10 |

---

### Task 1: Alat ukur context build + baseline

**Files:**
- Create: `tools/measure-build-context.py`
- Create: `tools/tests/measure-build-context.test.sh`
- Modify: `docs/superpowers/specs/2026-10-20-build-lean-controller-design.md` (§9)

**Interfaces:**
- Produces: CLI `python3 tools/measure-build-context.py [--json] PATH...`. PATH berupa file `.jsonl` atau direktori (diambil `*.jsonl` langsung di dalamnya, non-rekursif). Dipakai Task 10 dan pengukuran "sesudah".
  - `classify(tool_name: str, tool_input: dict) -> str` → `skillref|state|code|agent|other`.
  - `analyze_session(path: Path) -> dict | None` → `None` kalau bukan sesi build.
  - `summarize(sessions: list[dict]) -> dict`.
  - JSON: `{"sessions": [Session], "summary": Summary}`
    - `Session = {id, ctx_first_impl: int|null, growth_median: int|null, impl_dispatches, tasks, review_dispatches, brief_writer_dispatches, needs_context_tasks, blocked_tasks, cannot_verify, attribution: {skillref, state, code, agent, other}}`. Nilai `attribution` dalam karakter.
    - `Summary = {sessions, median_ctx_first_impl, median_growth, review_rounds_per_task, needs_context_per_task, blocked_per_task, cannot_verify_per_review}`.

Aturan:
- **Sesi build** = ada record `user` yang isinya memuat `<command-name>/context-vault:build`, ATAU ada `tool_use` `Skill` dengan `input.skill == "context-vault:build"`.
- **ctx** sebuah record assistant = `input_tokens + cache_read_input_tokens + cache_creation_input_tokens` dari `message.usage` record itu.
- **Dispatch** (`tool_use` bernama `Agent`):
  - brief-writer = `input.subagent_type == "context-vault:brief-writer"`.
  - reviewer = prompt memuat `.diff` DAN `-brief.md`.
  - implementer = bukan dua di atas, dan prompt cocok `task-([A-Za-z0-9_.-]+)-brief\.md` DAN memuat `-report.md`. Id task diambil dari group 1.
- **Hasil subagent:**
  - teks `tool_result` untuk `tool_use_id` itu;
  - DITAMBAH, kalau `tool_result` memuat `agentId: <id>`, isi tiap record `user` berikutnya yang memuat `<agent-message from="<id>">` (agent background).
- **Metrik:**
  - `ctx_first_impl` = ctx pada dispatch implementer pertama.
  - `growth_median` = median selisih ctx antar dispatch implementer berurutan (butuh ≥ 2 dispatch), dibulatkan ke int.
  - `needs_context_tasks` / `blocked_tasks` = jumlah id task unik yang hasil implementernya cocok `(?m)^\s*(?:Status:\s*)?NEEDS_CONTEXT\b` / `(?m)^\s*(?:Status:\s*)?BLOCKED\b`.
  - `cannot_verify` = jumlah, per hasil reviewer: angka dari `(?m)^\s*⚠️:\s*(\d+)`. Kalau baris itu nggak ada, hitung kemunculan `Cannot verify from diff`.
- **Atribusi** = panjang teks `tool_result` (+ pesan agent background, masuk `agent`) per kelas `classify`, diuji berurutan terhadap `json.dumps(tool_input)`:
  - `Agent` → `agent`;
  - memuat `skills/build/` atau `SKILL.md` → `skillref`;
  - cocok `tasks\.yaml|feature\.yaml|last-run|gates\.yaml|carry|_rules|workspace\.yaml|conventions|invariants|plans/|_shared|fanout|report\.md|review-r|notify|memory/|build_status\.py` → `state`;
  - cocok `/src/|migrations|mockups/|\.tsx?\b|\.sql\b|\.html\b|\.css\b|\.go\b|\.py\b|-brief\.md|/schema/|package\.json` → `code`;
  - selainnya `other`.
- **Summary:**
  - `median_ctx_first_impl` = median dari sesi yang punya implementer.
  - `median_growth` = median dari `growth_median` yang non-null.
  - `review_rounds_per_task` = Σ`review_dispatches` / Σ`tasks`; `needs_context_per_task` = Σ`needs_context_tasks` / Σ`tasks`; `blocked_per_task` = Σ`blocked_tasks` / Σ`tasks`; `cannot_verify_per_review` = Σ`cannot_verify` / Σ`review_dispatches`.
  - Semua dibulatkan 2 desimal; pembagi 0 → `null`.
- **Teks (tanpa `--json`):**
  - satu baris per sesi: `<id8> ctx@impl1=<n>K growth=<n>K impl=<n> tasks=<n> review/task=<x> needs_ctx=<n> blocked=<n> ⚠️=<n>`;
  - lalu satu baris `median ctx@impl1=<n>K · median growth=<n>K · review/task=<x> · needs_ctx/task=<x> · blocked/task=<x> · ⚠️/review=<x> · sessions=<n>`.
  - `K` = ribuan dibulatkan.

- [ ] **Step 1: Tulis test `tools/tests/measure-build-context.test.sh`**

Pola sama dengan `tools/tests/build-status.test.sh` (`ok`/`bad`, `jq`, `mktemp -d`). Test menulis dua file fixture lewat `python3 - <<'PY'`.

`build.jsonl` berisi record berurutan berikut. Semua usage `{input_tokens: 0, cache_creation_input_tokens: 0, cache_read_input_tokens: N}`; teks tool_result = string polos.
1. user: `<command-message>context-vault:build</command-message>\n<command-name>/context-vault:build</command-name>\n<command-args>x</command-args>`
2. assistant N=40000: tool_use `u1` `Read` `{file_path: "/p/plugin/skills/build/reference.md"}` → tool_result `"A"*3200`
3. assistant N=50000: `u2` `Bash` `{command: "sed -n 1,40p control/features/x/tasks.yaml"}` → `"B"*6400`
4. assistant N=60000: `u3` `Agent` `{description: "Implement T1", prompt: "Baca brief: .claude/build/x/task-T1-brief.md\nReport: .claude/build/x/task-T1-report.md"}` → `"Async agent launched successfully.\nagentId: aaa1 (internal)"`
5. user (string): `Another Claude session sent a message:\n<agent-message from="aaa1">\n  Status: NEEDS_CONTEXT\n  butuh nama tabel\n</agent-message>`
6. assistant N=62000: `u4` `Agent` (prompt sama dengan u3) → `"Status: DONE\nCommit abc1234"`
7. assistant N=65000: `u5` `Agent` `{description: "Review T1", prompt: ".claude/build/x/task-T1-brief.md .claude/build/x/task-T1-report.md .claude/build/x/review-abc1234..def5678.diff"}` → `"spec: ✅\nquality: ✅ (Critical 0 · Important 0 · Minor 1)\n⚠️: 2\n  - a\n  - b\nreview: r.md"`
8. assistant N=70000: `u6` `Bash` `{command: "cat src/app/page.tsx"}` → `"C"*9600`
9. assistant N=80000: `u7` `Agent` `{description: "Implement T2", prompt: ".claude/build/x/task-T2-brief.md .claude/build/x/task-T2-report.md"}` → `"Status: BLOCKED\nalasan"`
10. assistant N=81000: `u8` `Agent` `{subagent_type: "context-vault:brief-writer", prompt: "Tulis brief ke: .claude/build/x/task-T3-brief.md"}` → `"brief: x"`

`plain.jsonl`: satu user `halo` + satu assistant tanpa tool. Ini bukan sesi build.

Assertion (`J=$(python3 tools/measure-build-context.py --json "$T")`):
```text
.sessions|length                         == 1
.sessions[0].ctx_first_impl              == 60000
.sessions[0].growth_median               == 10000
.sessions[0] .impl_dispatches/.tasks     == 3 / 2
.sessions[0] .review_dispatches          == 1
.sessions[0] .brief_writer_dispatches    == 1
.sessions[0] .needs_context_tasks        == 1
.sessions[0] .blocked_tasks              == 1
.sessions[0] .cannot_verify              == 2
.sessions[0].attribution .skillref/.state/.code == 3200 / 6400 / 9600
.sessions[0].attribution.agent > 0
.summary .review_rounds_per_task/.needs_context_per_task/.blocked_per_task == 0.5 / 0.5 / 0.5
.summary.cannot_verify_per_review        == 2
tanpa --json → stdout memuat "ctx@impl1=60K" dan "sessions=1"
```

- [ ] **Step 2: Jalankan, pastikan GAGAL**

Run: `bash tools/tests/measure-build-context.test.sh` → FAIL (script belum ada).

- [ ] **Step 3: Implementasi `tools/measure-build-context.py`** (stdlib; baris rusak di `.jsonl` dilewati; direktori `subagents/` nggak ikut).

- [ ] **Step 4: Jalankan test, pastikan LULUS**

Run: `bash tools/tests/measure-build-context.test.sh` → exit 0.

- [ ] **Step 5: Ukur baseline dan isi spec §9**

Run: `python3 tools/measure-build-context.py ~/.claude/projects/-Users-mac-098506-Developer-project-mahjong`

Isi kolom **Baseline** tabel §9 spec dengan angka summary dan jumlah sesinya, misal `181.5K (42 sesi, measure-build-context 2026-10-xx)`. Ganti dua baris yang tadinya bertanda "hitungan kasar". Hitungan kasar sesi desain: median ~181K, growth ~30K. Kalau hasilnya beda > 25%, cek aturan deteksi implementer dulu sebelum lanjut.

- [ ] **Step 6: Commit**

```bash
git add tools/measure-build-context.py tools/tests/measure-build-context.test.sh docs/superpowers/specs/2026-10-20-build-lean-controller-design.md
git commit -m "feat(tools): measure-build-context — ukur context & kualitas sesi build dari transcript + isi baseline spec §9"
```

---

### Task 2: `build_status.py --format task|carry` + fixture `lean`

**Files:**
- Modify: `plugin/template/.claude/build_status.py`
- Modify: `tools/tests/build-status.test.sh` (tambah blok baru di AKHIR, sebelum ringkasan pass/fail; blok lama nggak disentuh)
- Create: `tools/tests/fixtures/build-status/lean/**`

**Interfaces:**
- Consumes: `load_yaml`, `_dict`, `_list`, `_str`, `_scratch(root, kind, name)` (yang sudah ada).
- Produces (dipakai Task 3, brief-writer, gate, ship):
  - `_work_item(root: Path, work_item: str) -> tuple[str, Path]` → `(kind, wdir)`. kind `fix` kalau parent folder bernama `fixes`.
  - `_tasks(doc: dict) -> list[tuple[dict, dict]]` → pasangan `(milestone, task)` urut dokumen.
  - `task_entries(root: Path, work_item: str, ids: list[str]) -> dict` → `{"work_item": <rel>, "tasks": [<task dict + "milestone": <id>>]}`, urut sesuai `ids`. Id tak dikenal → `YamlError("task tak dikenal: <id>")` → exit 2.
  - `carry_notes(root: Path, work_item: str, targets: list[str]) -> dict` → `{"work_item": <rel>, "source": "carry.yaml"|"legacy"|"none", "notes": [...]}`.
  - CLI: `--format task --task T1,T2 --work-item <dir>` dan `--format carry --for T75,gate:M4/api --work-item <dir>`. Output JSON satu baris (`ensure_ascii=False`).

Aturan `carry_notes`:
- **Sumber.** `<wdir>/carry.yaml` ada → `source "carry.yaml"`, notes = entri `notes:` (dict mentah) yang cocok target, urut file. Kalau nggak ada, `_scratch(root, kind, name) / "_carry-notes.md"` ada → `"legacy"`. Kalau dua-duanya nggak ada → `"none"`, `[]`.
- **Cocok target (carry.yaml).**
  - `for` == target;
  - minta `gate:M4/api` → cocok `gate:M4` dan `gate:M4/api`;
  - minta `gate:M4` → cocok `gate:M4` dan semua `gate:M4/*`.
- **Nggak aktif** (nggak dikeluarkan): entri punya `closed`, ATAU `for` = id task yang statusnya `done` di `tasks.yaml`.
- **Legacy.** Notes = `{"line": <teks baris>}` untuk tiap baris non-kosong yang nggak diawali `#`, dengan token per target:
  - id task → `\b<id>\b`, dan dilewati kalau task itu `done`;
  - `gate:M4` atau `gate:M4/x` → `\bM4\b`;
  - `ship` → `(?i)\bship\b`;
  - `simplify` → `(?i)\b(simplify|7a)\b`.
  - Satu baris cocok beberapa target → keluar sekali.

- [ ] **Step 1: Tulis fixture `tools/tests/fixtures/build-status/lean/`**

- `control/workspace.yaml`:
  ```yaml
  topology: multi-repo
  databases:
    - name: main
      engine: Postgres
      migrations: api/migrations
      owner: api
  apps:
    - name: api
      path: api
      stack:
        db: main
    - name: web
      path: web
      stack: { db: main }
  packages: []
  ```
- `control/schema/api.md`:
  ```markdown
  # api — Schema (proyeksi; JANGAN edit tangan — di-generate dari skema/migrasi app)

  ## users
  Kolom  : id uuid [pk] · email text [unique]

  ## orders
  Kolom  : id uuid [pk] · user_id uuid [fk→users]
  ```
- `api/src/users.ts` (isi 1 baris komentar) dan `web/.keep`.
- `control/features/lean-x/feature.yaml`: `status: active`, `risk: low`, `sensitivity: [payments]`.
- `control/features/lean-x/business.md`, `plans/_shared.md`, `plans/api.md`: masing-masing satu baris judul.
- `control/features/lean-x/tasks.yaml` (`feature: lean-x`):
  - **M1 `Fondasi`:** T1 api `done` "users base"; T2 web `done` "layout".
  - **M2 `Inti`:**
    - T3 api `pending` `deps: [T1]` "orders endpoint", `reuse: [ {table: users} ]` dalam bentuk blok;
    - T4 web `pending` `deps: [T2]` "orders page", reuse blok `- table: carts` dan `- file: src/ghost.ts`;
    - T5 api `pending` `deps: [T3]` "orders totals";
    - T6 web `in_progress` "cart badge";
    - T7 api `needs_human` `hold: "migrate destructive — nunggu approve"` "drop legacy cols";
    - T8 api `blocked` "flaky seed";
    - T9 api `pending` `deps: [T1]`, reuse blok `- file: src/users.ts`, `desc` = `"tambah endpoint ringkasan pesanan per pengguna dengan paginasi kursor dan filter status yang bisa digabung"` (> 80 karakter);
    - T10 tanpa `unit` dan `desc`, `pending`, `deps: [T99]`.
- `control/features/lean-x/gates.yaml`: `gates:` → G1 `segment: api×M1` `status: queued` `reason: "risk:high"`.
- `control/features/lean-x/carry.yaml` (header persis Global Constraints, lalu `notes:`, terbaru di atas):
  - C5 `for: gate:M2` `closed: 2026-10-01`;
  - C4 `for: ship` `from: review T2` `note: "urutan deploy: api dulu"`;
  - C3 `for: gate:M2/api` `from: review T1` `note: "cek index orders.user_id"`;
  - C2 `for: T1` `note: "lama"`;
  - C1 `for: T3` `from: preflight` `note: "pakai helper paginate()"`.
  - Semua punya `at: 2026-10-20` dan `from`.
- `control/fixes/2026-10-02-legacy/fix.yaml` `status: open`; `tasks.yaml` M1 berisi F1 web `pending` "null guard" dan F0 web `done` "repro".
- `.claude/build/fixes/2026-10-02-legacy/_carry-notes.md`:
  ```markdown
  # Carry notes (legacy)
  - F1: jangan ubah signature parse()
  - F0: catatan lama
  - gate M1: cek log error
  - SHIP: catat env baru FOO_URL
  - 7a: helper kembar formatDate
  ```

- [ ] **Step 2: Tambah kasus di `build-status.test.sh`**

Helper `mklean`: copy `$FX/lean` ke `$T/lean`, lalu `git -C api init -q` dan `git -C web init -q`. Kasus:
```text
--format task --task T9,T3 --work-item control/features/lean-x
   → .tasks[].id == ["T9","T3"]; .tasks[1].milestone == "M2"; .tasks[1].reuse == [{"table":"users"}]; .work_item == "control/features/lean-x"
--format task --task T42 …               → exit 2, stderr memuat "task tak dikenal: T42"
--format task --task T3 (tanpa --work-item) → exit 2, stderr memuat "butuh --work-item"
--format carry --for T3 …                → .source == "carry.yaml"; .notes[].id == ["C1"]
--format carry --for T1 …                → .notes == []                       (task done)
--format carry --for gate:M2/api …       → .notes[].id == ["C3"]              (C5 closed)
--format carry --for gate:M2 …           → .notes[].id == ["C3"]
--format carry --for ship,T3 …           → .notes[].id == ["C4","C1"]
--format carry --for F1 --work-item control/fixes/2026-10-02-legacy
   → .source == "legacy"; .notes == [{"line":"- F1: jangan ubah signature parse()"}]
… --for F0 (fix legacy)                  → .notes == []
… --for ship,simplify,gate:M1 (fix)      → .notes[].line == ["- gate M1: cek log error","- SHIP: catat env baru FOO_URL","- 7a: helper kembar formatDate"]
carry.yaml diberi baris ber-tab          → exit 2, stderr memuat "carry.yaml"
work-item tanpa carry & tanpa legacy (control/features/lean-x dengan carry.yaml dihapus) → .source == "none", .notes == []
```

- [ ] **Step 3: Jalankan, pastikan kasus baru GAGAL**

Run: `bash tools/tests/build-status.test.sh` → FAIL di kasus baru, kasus lama tetap ok.

- [ ] **Step 4: Implementasi** fungsi di Interfaces + choices `--format` ditambah `task`/`carry` + argumen `--task IDS` dan `--for TARGETS` (dipisah koma, spasi di-trim). `main` untuk format baru: exit 2 + `build_status: --format <f> butuh --work-item` kalau `--work-item` absen. `YamlError` → exit 2 seperti format lain.

- [ ] **Step 5: Jalankan, pastikan LULUS semua (lama + baru)**

Run: `bash tools/tests/build-status.test.sh` → exit 0. `git diff --stat main -- tools/tests/fixtures/build-status/prod` → kosong.

- [ ] **Step 6: Commit**

```bash
git add plugin/template/.claude/build_status.py tools/tests/build-status.test.sh tools/tests/fixtures/build-status/lean
git commit -m "feat(build-status): --format task|carry — entri task lengkap & titipan aktif (carry.yaml + fallback _carry-notes.md legacy)"
```

---

### Task 3: `build_status.py --format controller` + allowlist

**Files:**
- Modify: `plugin/template/.claude/build_status.py`
- Modify: `tools/tests/build-status.test.sh`
- Create: `tools/tests/fixtures/build-status/lean/expected-controller.txt`
- Modify: `plugin/template/.claude/settings.json`
- Modify: `plugin/skills/upgrade/SKILL.md`

**Interfaces:**
- Consumes: `_work_item`, `_tasks`, `carry_notes` (Task 2); `_lane_keys(root, guard)` yang sudah ada (pakai `guard = lambda load, wdir: load()`).
- Produces:
  - `_flow_map(s: str) -> dict` (`"{ db: main, orm: x }"` → `{"db": "main", "orm": "x"}`; pakai `_flow_items` + `_split_key` + `_unquote` yang ada).
  - `schema_owner(ws: dict, unit: str) -> str` (aturan `plugin/rules/db-ownership.md`: `stack` dict atau flow map string; `stack.db` cocok `databases[].name` → `owner`, selainnya `unit`).
  - `effective_risk(feature: dict) -> str`.
  - `staleness(wdir: Path, kind: str) -> str`.
  - `controller_text(root: Path, work_item: str) -> str`.
  - CLI `--format controller --work-item <dir>` → teks, diakhiri satu `\n`.

**Format `controller_text`** (baris persis, urutan tetap; `—` = kosong; pemisah antar-item ` · `):
```text
work-item: <rel> (feature · risk <R> · sensitivity <S>)      # fix: "work-item: <rel> (fix)"
staleness: OK | STALE <relpath> > tasks.yaml[, <relpath> > tasks.yaml…] | WARN business.md > tasks.yaml | —
repos: <unit>=<label> · …
READY: <label> <id> <id> · <label> <id> (sibuk <id>[,<id>]) · … | —
in_progress: <id> <unit> · … | —
hold: <id> needs_human "<alasan>" · … | —
blocked: <id> <unit>[ "<hold>"] · … | —
gates queued: <id> <segment> "<reason>" · … | —
reuse basi: <id> table <T> · <id> file <f> · … | —
carry: <target>×<n> · … · next C<n>    |    carry: legacy _carry-notes.md (<n> baris) · next C1    |    carry: — · next C1
map:
  <Mid> ✓ <d>/<t> <title>                                    # milestone yang semua task-nya done (t > 0)
  <Mid> <d>/<t> <title>
    <id> <unit|-> <status>[ deps <a>,<b>][ · <desc ≤80>]          # desc kosong → tanpa " · "
```
Aturan:
- **risk** = `risk` ∈ {low, normal, high}, selainnya `normal`. `sensitivity` memuat `payments` dan risk ≠ high → `high (payments)`.
- **sensitivity** = list digabung `,` atau `—`.
- **staleness (feature):**
  - semua `plans/*.md` (urut nama) yang mtime-nya > `tasks.yaml` → `STALE …`;
  - kalau nggak ada, `business.md` lebih baru → `WARN …`;
  - kalau nggak ada juga → `OK`.
- **staleness (fix):** `fix.yaml`/`notes.md` lebih baru → `STALE`. `tasks.yaml` absen → `—`.
- **repos:** unit unik urut kemunculan pertama di dokumen. `integration` dilewati, unit kosong juga.
  - `<label>` = basename toplevel git (`_lane_keys`);
  - `root` kalau bukan git;
  - `integration` untuk `__integration__`.
- **READY** = task `pending` yang semua `deps`-nya `done` (id tak dikenal = belum done).
  - Dikelompokkan per label, urutan grup = kemunculan task READY pertama, dan task dalam grup urut dokumen.
  - `(sibuk …)` = id task `in_progress` di label yang sama.
- **hold** = task `needs_human`. Alasannya `hold:`, kalau nggak ada pakai item pertama `manual:`, kalau nggak ada juga tanpa `"…"`.
- **reuse basi** = untuk task ≠ `done`, tiap entri `reuse`:
  - `table: T` → hanya kalau unit ∈ `apps[]`, `control/schema/<schema_owner>.md` ada dan punya ≥ 1 heading `## `, dan `T` bukan salah satu heading itu;
  - `file: f` → hanya kalau unit ∈ `apps[]` ∪ `packages[]` dan `<root>/<path>/<f>` nggak ada.
- **carry** = jumlah titipan AKTIF per target `for`, urut kemunculan pertama di file. `next` = 1 + id `C<n>` terbesar di file, termasuk yang `closed`.

`expected-controller.txt` (fixture `lean`, mtime diset test: `tasks.yaml` NOW−600, `plans/api.md` NOW−60, `plans/_shared.md` NOW−900, `business.md` NOW−30):
```text
work-item: control/features/lean-x (feature · risk high (payments) · sensitivity payments)
staleness: STALE plans/api.md > tasks.yaml
repos: api=api · web=web
READY: api T3 T9 · web T4 (sibuk T6)
in_progress: T6 web
hold: T7 needs_human "migrate destructive — nunggu approve"
blocked: T8 api
gates queued: G1 api×M1 "risk:high"
reuse basi: T4 table carts · T4 file src/ghost.ts
carry: ship×1 · gate:M2/api×1 · T3×1 · next C6
map:
  M1 ✓ 2/2 Fondasi
  M2 0/8 Inti
    T3 api pending deps T1 · orders endpoint
    T4 web pending deps T2 · orders page
    T5 api pending deps T3 · orders totals
    T6 web in_progress · cart badge
    T7 api needs_human · drop legacy cols
    T8 api blocked · flaky seed
    T9 api pending deps T1 · tambah endpoint ringkasan pesanan per pengguna dengan paginasi kursor dan filte…
    T10 - pending deps T99
```
Catatan: desc kosong → bagian ` · <desc>` dihilangkan (tanpa spasi di ujung baris). T10 nggak masuk READY karena `T99` nggak dikenal.

- [ ] **Step 1: Tulis `expected-controller.txt` dan kasus test**

```text
controller lean-x (mtime di atas)                 == expected-controller.txt (diff byte)
dijalankan dua kali                               → output identik
plans/api.md diset NOW−900                        → baris 2 == "staleness: WARN business.md > tasks.yaml"
… lalu business.md NOW−900                        → baris 2 == "staleness: OK"
control/schema/api.md dihapus                     → baris "reuse basi: T4 file src/ghost.ts"   (cek tabel dilewati, nggak palsu)
--work-item control/fixes/2026-10-02-legacy       → baris 1 == "work-item: control/fixes/2026-10-02-legacy (fix)";
                                                    baris carry == "carry: legacy _carry-notes.md (5 baris) · next C1"
tanpa --work-item                                 → exit 2
fixture prod (checkout-v2), --format controller   → exit 0, baris "READY: —" dan "gates queued: G3 api×M2 \"floor-scan T6 (token)\""
```
`(5 baris)` = jumlah baris non-kosong yang nggak diawali `#`.

- [ ] **Step 2: Jalankan, pastikan kasus baru GAGAL**

Run: `bash tools/tests/build-status.test.sh` → FAIL di kasus controller.

- [ ] **Step 3: Implementasi** fungsi di Interfaces + choice `controller`.

- [ ] **Step 4: Jalankan, pastikan LULUS semua**

Run: `bash tools/tests/build-status.test.sh && bash plugin/hooks/tests/drive.test.sh` → exit 0.

- [ ] **Step 5: Allowlist template**

`plugin/template/.claude/settings.json`. Ganti:
```text
      "Bash(git checkout:*)"
    ],
```
dengan:
```text
      "Bash(git checkout:*)",
      "Bash(python3 .claude/build_status.py:*)"
    ],
```
Validasi: `jq . plugin/template/.claude/settings.json >/dev/null`.

- [ ] **Step 6: `upgrade/SKILL.md`**

Ganti:
```text
`.claude/build_status.py` — ada? (dipanggil `drive.sh` lewat `python3`; tak perlu executable)
```
dengan:
```text
`.claude/build_status.py` — ada? versi terbaru? (dipanggil `drive.sh` lewat `python3`, dan oleh `build` untuk ringkasan state `--format controller|task|carry`; tak perlu executable — salinan lama bikin `build` jalan cara lama yang boros context. Allowlist `Bash(python3 .claude/build_status.py:*)` ikut merge baseline `allow` di step 2.)
```

- [ ] **Step 7: Commit**

```bash
git add plugin/template/.claude/build_status.py tools/tests/build-status.test.sh tools/tests/fixtures/build-status/lean plugin/template/.claude/settings.json plugin/skills/upgrade/SKILL.md
git commit -m "feat(build-status): --format controller — peta + READY per repo + hold/gate + staleness + reuse basi + jumlah titipan; allowlist template + catatan upgrade"
```

---

### Task 4: Pecah `reference.md` jadi indeks + file per section

**Files:**
- Modify: `plugin/skills/build/reference.md` (jadi indeks)
- Create: `plugin/skills/build/reference/{a-pinjam-sdd,b-brief,c-model,d-gate,e-status-resume,f-multi-repo,g-lapor-keluar,h-driver,i-antrian-gate}.md`
- Create: `tools/tests/build-lean.test.sh`
- Modify: `tools/tests/ask-user.test.sh`, `tools/build-kimi.sh`, `tools/tests/build-kimi.test.sh`

**Interfaces:**
- Produces: path file section yang dipakai Task 5–8 dan oleh indeks. Isi tiap file = section lama **byte-identik** (heading `## X.` di baris pertama), dengan trailing whitespace di-strip + satu `\n`.

- [ ] **Step 1: Pindahkan isi (script, jangan diketik ulang)**

```bash
python3 - <<'PY'
import re, pathlib
src = pathlib.Path('plugin/skills/build/reference.md'); text = src.read_text()
names = dict(A='a-pinjam-sdd', B='b-brief', C='c-model', D='d-gate', E='e-status-resume',
             F='f-multi-repo', G='g-lapor-keluar', H='h-driver', I='i-antrian-gate')
parts = re.split(r'(?m)^(?=## [A-I]\. )', text)
secs = parts[1:]
assert [s[3] for s in secs] == list('ABCDEFGHI'), [s[:6] for s in secs]
out = pathlib.Path('plugin/skills/build/reference'); out.mkdir()
for s in secs:
    (out / f"{names[s[3]]}.md").write_text(s.rstrip() + '\n')
assert '\n\n'.join(s.rstrip() for s in secs) == text[len(parts[0]):].rstrip()
print('ok', len(secs))
PY
```
Expected: `ok 9`.

- [ ] **Step 2: Tulis indeks `plugin/skills/build/reference.md`** (ganti seluruh isi file)

````markdown
# build — Reference (indeks)

Dibaca oleh skill `build`. **Jangan baca semua section di depan** — baca section §X saat sampai di step SKILL yang menyebutnya. Rujukan "`build/reference.md` §X" dari skill lain juga diselesaikan lewat tabel ini.

| § | File | Isi | Dibaca saat |
|---|---|---|---|
| A | `reference/a-pinjam-sdd.md` | Yang dipinjam dari `subagent-driven-development` | dispatch implementer/reviewer pertama di run (step 3–4) |
| B | `reference/b-brief.md` | Aturan isi brief implementer | **brief-writer** (bukan controller); dipinjam `design-system` & `fix`; controller hanya di jalur degrade |
| C | `reference/c-model.md` | Pilih model | memilih model implementer/reviewer (step 3) |
| D | `reference/d-gate.md` | Cadence gate (mode A adaptif) + smoke | gate segmen (step 6) |
| E | `reference/e-status-resume.md` | Status, resume, status balikan subagent, actions | tulis status (step 5), resume (step 1) |
| F | `reference/f-multi-repo.md` | Probe & branch multi-repo, lane | branch per repo (step 1), scheduler lane (step 2) |
| G | `reference/g-lapor-keluar.md` | Lapor-keluar / notifikasi unattended | mode unattended / tiap titik STOP (`last-run.md`) |
| H | `reference/h-driver.md` | Outer-loop driver lintas-sesi | mode unattended berkelanjutan |
| I | `reference/i-antrian-gate.md` | Antrian `gates.yaml` + drain pagi | ada gate `queued` / task `needs_human` / unattended |
````

- [ ] **Step 3: Tulis `tools/tests/build-lean.test.sh`**

```bash
#!/usr/bin/env bash
# Kontrak prosa build hemat-context (spec docs/superpowers/specs/2026-10-20-build-lean-controller-design.md).
# Jalanin: bash tools/tests/build-lean.test.sh  (exit 0 = semua lulus)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
B="$ROOT/plugin/skills/build"
PASS=0; FAIL=0
ok()    { PASS=$((PASS+1)); echo "ok   - $1"; }
bad()   { FAIL=$((FAIL+1)); echo "FAIL - $1"; }
has()   { grep -qF -- "$2" "$1" && ok "$3" || bad "$3"; }   # has <file> <string> <label>
hasnt() { grep -qF -- "$2" "$1" && bad "$3" || ok "$3"; }

# === T4: reference dipecah ===
grep -qE '^## [A-I]\. ' "$B/reference.md" && bad "reference.md masih memuat badan section" || ok "reference.md = indeks saja"
for f in $(grep -oE '`reference/[a-z]-[a-z-]+\.md`' "$B/reference.md" | tr -d '`'); do
  L="$(basename "$f" | cut -c1 | tr a-z A-Z)"
  [ -f "$B/$f" ] && head -1 "$B/$f" | grep -qE "^## $L\. " && ok "indeks → $f" || bad "indeks → $f (hilang / heading salah)"
done

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 4: Arahkan `ask-user.test.sh` ke file section**

Ganti:
```text
grep -qF 'JANGAN PERNAH akhiri turn dengan pertanyaan interaktif' "$SRC/skills/build/reference.md"
```
dengan:
```text
grep -qF 'JANGAN PERNAH akhiri turn dengan pertanyaan interaktif' "$SRC/skills/build/reference/g-lapor-keluar.md"
```
Ganti:
```text
grep -qF 'Satu gate = satu panggilan `AskUserQuestion`' "$SRC/skills/build/reference.md"
```
dengan:
```text
grep -qF 'Satu gate = satu panggilan `AskUserQuestion`' "$SRC/skills/build/reference/i-antrian-gate.md"
```

- [ ] **Step 5: `build-kimi.sh` — catatan unattended per file section**

Ganti blok mulai `# --- 8b. Note D5 — build/reference.md, sesudah heading pertama ber-'unattended' ---` sampai `  { print }' "$REF" > "$REF.tmp" && mv "$REF.tmp" "$REF"` (inklusif) dengan:
```bash
# --- 8b. Note D5 — build/reference/*.md, sesudah heading pertama ber-'unattended' di tiap file ---
n_ref=0
for REF in "$DST"/skills/build/reference/*.md; do
  grep -qiE '^#{1,6} .*unattended' "$REF" || continue
  awk '
    done==0 && /^#/ && tolower($0) ~ /unattended/ {
      print; print ""
      print "> ⛔ **Harness Kimi Code:** bagian unattended di file ini BELUM berlaku di Kimi — lihat banner di `SKILL.md` (fase 2)."
      done=1; next
    }
    { print }' "$REF" > "$REF.tmp" && mv "$REF.tmp" "$REF"
  n_ref=$((n_ref+1))
done
[ "$n_ref" -gt 0 ] || die "anchor heading 'unattended' di build/reference/*.md tak ketemu — source berubah, sesuaikan generator"
```

- [ ] **Step 6: `build-kimi.test.sh`**

Ganti:
```text
grep -q 'Harness Kimi Code' "$DST/skills/build/reference.md" \
  && ok "note unattended di build/reference.md" || bad "note unattended hilang di build/reference.md"
```
dengan:
```text
grep -q 'Harness Kimi Code' "$DST/skills/build/reference/g-lapor-keluar.md" && grep -q 'Harness Kimi Code' "$DST/skills/build/reference/h-driver.md" \
  && ok "note unattended di build/reference/{g,h}-*.md" || bad "note unattended hilang di build/reference/{g,h}-*.md"
```

- [ ] **Step 7: Jalankan semua test terkait**

```bash
bash tools/tests/build-lean.test.sh && bash tools/tests/ask-user.test.sh && bash tools/build-kimi.sh && bash tools/tests/build-kimi.test.sh
```
Expected: semua exit 0. Hasil regen `plugin-kimi/` dibiarkan (JANGAN di-`git add`); dikomit resmi di Task 9.

- [ ] **Step 8: Commit**

```bash
git add plugin/skills/build/reference.md plugin/skills/build/reference tools/tests/build-lean.test.sh tools/tests/ask-user.test.sh tools/build-kimi.sh tools/tests/build-kimi.test.sh
git commit -m "refactor(build): pecah reference.md jadi indeks + file per section (isi dipindah byte-identik) — dibaca saat step-nya, bukan di depan"
```

---

### Task 5: Agent `brief-writer` + §K prompt dispatch + §B

**Files:**
- Create: `plugin/agents/brief-writer.md`
- Create: `plugin/skills/build/reference/k-prompt-dispatch.md`
- Modify: `plugin/skills/build/reference/b-brief.md`, `plugin/skills/build/reference.md` (baris K), `tools/build-kimi.sh`, `tools/tests/build-kimi.test.sh`, `tools/tests/build-lean.test.sh`

**Interfaces:**
- Consumes: `--format task|carry` (Task 2), file section (Task 4).
- Produces: agent `context-vault:brief-writer`; §K (bentuk prompt yang dirujuk SKILL di Task 6–8); placeholder `<sdd>`, `<abs>`, `<root>`, `<work-item>`.

- [ ] **Step 1: Tambah kontrak di `build-lean.test.sh`** (sisipkan sebelum baris `echo "---"; echo "pass=$PASS fail=$FAIL"`)

```bash
# === T5: brief-writer + §K ===
A="$ROOT/plugin/agents/brief-writer.md"
has "$A" "name: brief-writer" "agent: name"
has "$A" "model: inherit" "agent: model inherit (D5)"
has "$A" "tools: Read, Grep, Glob, Bash, Write" "agent: tools"
for k in "brief:" "rules:" "titipan:" "deps:" "ambigu:" "tier:"; do has "$A" "$k" "agent: kunci balikan $k"; done
has "$A" "Jangan menebak." "agent: lapor ambigu, bukan nebak"
K="$B/reference/k-prompt-dispatch.md"
has "$K" "Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT" "§K: status implementer"
has "$K" "OVERRIDE format balikan template" "§K: override format reviewer"
has "$K" "task-<id>-review-r<n>.md" "§K: file review"
has "$K" "cap 3 ronde" "§K: cap 3 ronde tetap (D12)"
has "$B/reference/b-brief.md" "**brief-writer**" "§B: perakit = brief-writer"
has "$B/reference.md" "reference/k-prompt-dispatch.md" "indeks: §K"
```
Run: `bash tools/tests/build-lean.test.sh` → FAIL di blok T5.

- [ ] **Step 2: Tulis `plugin/agents/brief-writer.md`**

````markdown
---
name: brief-writer
description: Perakit brief implementer untuk skill build context-vault. Diberi id task + work-item, ia membaca entri task, plan, kontrak, konvensi, skema, signature dep, mockup, dan titipan dari disk, lalu menulis task-<id>-brief.md (+ _rules-<repo>.md bila basi) ke .claude/build/. Controller build sengaja tidak membaca kode demi brief. Balikan ringkas ≤10 baris. Tidak menulis kode, tidak commit.
tools: Read, Grep, Glob, Bash, Write
model: inherit
---

Kamu BRIEF-WRITER untuk skill `build` context-vault. Tugasmu satu: merakit brief LENGKAP untuk SATU task, supaya implementer bisa kerja tanpa membaca `tasks.yaml` atau plan, dan tanpa menebak. Kamu yang membaca file-file besar. Controller sengaja tidak, supaya context-nya tetap kecil. Jadi kelengkapan dan ketepatan brief sepenuhnya tanggung jawabmu.

## Input (dari prompt dispatch)
root produk · work-item (`control/features/<f>` / `control/fixes/<id>`) · id task · path aturan isi brief (`reference/b-brief.md`) · repo sibuk → base7 · path brief keluaran.

## Langkah
1. Baca aturan isi brief (path dari prompt). Itu spesifikasi isi brief, jadi ikuti SEMUA bagiannya.
2. Ambil entri task: `python3 .claude/build_status.py --root <root> --format task --task <id> --work-item <work-item>`. JANGAN Read `tasks.yaml` utuh (bisa >100KB). Butuh entri deps → panggil lagi dengan id deps.
3. Titipan: `python3 .claude/build_status.py --root <root> --format carry --for <id> --work-item <work-item>`. Masukkan semuanya ke blok **Titipan** brief (id + asal + isi, apa adanya). Kalau `source: legacy`, ambil baris `_carry-notes.md` yang dikembalikan.
4. Baca section `plans/<unit>.md` / `plans/_shared.md` yang relevan (Grep heading/kata kunci lalu Read rentangnya, bukan file utuh kalau besar), `control/conventions.md`, `control/workspace.yaml` (stack/path), proyeksi skema, dan listing dir (pakai **Glob**, bukan `ls`). Baca juga file pola, mockup, dan signature dep. Signature dep dibaca dari disk. Kalau repo-nya sibuk, pakai `git -C <path-unit-literal> show <base7>:./<file>`.
5. `_rules-<repo>.md` (lihat bawah): tulis ulang bila absen atau basi.
6. Tulis brief ke path keluaran. Brief merujuk `_rules-<repo>.md` lewat path, tidak menyalin isinya.
7. Kirim balikan (format di bawah). Jangan tulis file lain selain brief + `_rules-<repo>.md`.

## `_rules-<repo>.md`
Path: folder yang sama dengan brief. `<repo>` = basename toplevel git repo unit (`git -C <path-unit> rev-parse --show-toplevel`). Kalau bukan git, pakai nama unit. Tulis ulang bila file absen ATAU mtime salah satu sumber lebih baru: `control/conventions.md`, `control/invariants.md`, `control/workspace.yaml`, `.claude/settings.json`. Isinya ringkas (≤ 60 baris):
- repo, branch work-item (jangan pindah branch), stack unit di repo ini;
- pointer section `conventions.md` & `invariants.md` yang mengikat (nama section, bukan salinan);
- migrasi: DDL HANYA lewat task ber-`actions: migrate`, jangan pernah apply migrasi ke DB di luar itu; sebut perintah apply yang ada di allowlist `.claude/settings.json` bila ada;
- TDD (test merah dulu → hijau); commit HANYA file task per `files:` (bukan `git add -A`);
- "JANGAN baca `tasks.yaml` — brief = requirement-mu".

## Aturan
- **Jangan menebak.** Kalau info yang dibutuhkan brief tidak ada atau kontradiktif (plan vs `_shared.md`, `produces:` vs disk, titipan bentrok dengan `approach`), tulis bagian yang pasti, lalu laporkan di `ambigu:`. Controller yang menjawab.
- `produces:` dep ≠ signature disk → tandai **DRIFT** di brief dan di `deps:` balikan. Disk selalu menang.
- Hanya tulis di `<root>/.claude/build/`. Tidak edit kode, `control/`, atau `tasks.yaml`, dan tidak commit.
- Bash hanya untuk `python3 .claude/build_status.py …` dan `git -C <path-unit-literal> show|log|rev-parse …`.

## Balikan (≤10 baris, persis kunci ini)
```
brief: <path>
rules: _rules-<repo>.md (dipakai | ditulis ulang)
titipan: <id, …> | none
deps: <id> ok · <id> DRIFT (<1 baris>) | none
ambigu: <pertanyaan verbatim; satu per baris> | none
tier: low | mid | high   (saran model implementer per reference §C)
```
````

- [ ] **Step 3: Tulis `plugin/skills/build/reference/k-prompt-dispatch.md`**

````markdown
## K. Bentuk prompt dispatch (controller → subagent)

Controller TIDAK membaca isi template superpowers maupun §B. Path-nya diserahkan ke subagent yang butuh. Artefak bulky lewat file di `<root>/.claude/build/<work-item>/`. Tiap subagent membalas sesuai kontrak di bawah.

**`<sdd>`** = folder `skills/subagent-driven-development` superpowers terpasang. Resolve SEKALI per run pakai tool **Glob** (bukan Bash, karena path plugin-cache bernomor versi tak bisa di-allowlist): `path` = `~/.claude/plugins/cache` (HOME user), pattern `*/superpowers/*/skills/subagent-driven-development/implementer-prompt.md`, lalu ambil versi tertinggi. Tidak ketemu → hapus baris "Ikuti template" dari prompt. Kontrak ringkas di bawah tetap lengkap tanpanya. **`<abs>`** = `${CLAUDE_PLUGIN_ROOT}` (absolut).

### Brief-writer (step 3) — `subagent_type: context-vault:brief-writer`
```
Rakit brief task <id> (work-item <work-item>, root <root>).
Aturan isi brief: <abs>/skills/build/reference/b-brief.md
Repo sibuk (baca signature dep dari base-SHA ini): <repo>=<base7>, … | none
Tulis brief ke: <root>/.claude/build/<work-item>/task-<id>-brief.md
Balikan ≤10 baris sesuai kontrak di file agent-mu.
```
Ambiguitas sudah dijawab controller → tambahkan `Jawaban controller: <jawaban>` lalu dispatch ulang.

### Implementer (step 3)
```
Baca brief dulu — itu requirement-mu, nilai eksaknya dipakai verbatim:
  <root>/.claude/build/<work-item>/task-<id>-brief.md
Ikuti template (baca sendiri): <sdd>/implementer-prompt.md
Pakai test-driven-development. Commit HANYA file task (bukan git add -A). Self-review.
Tulis report detail (apa yang dibangun + bukti test TDD + concern) ke:
  <root>/.claude/build/<work-item>/task-<id>-report.md   (ronde fix: APPEND)
Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT (spec kurang → tanya dulu, jangan nebak).
Balikan chat: status + commit SHA + 1 baris hasil test + concern.
```
Ronde fix: tambahkan `Temuan review: <root>/.claude/build/<work-item>/task-<id>-review-r<n>.md` + SHA/file yang disentuh.

### Task-reviewer (step 4)
```
Ikuti template (baca sendiri): <sdd>/task-reviewer-prompt.md
BRIEF:  <root>/.claude/build/<work-item>/task-<id>-brief.md
REPORT: <root>/.claude/build/<work-item>/task-<id>-report.md
DIFF:   <root>/.claude/build/<work-item>/review-<base7>..<head7>.diff
Global constraints: <invarian/konvensi yang mengikat task>
Aturan baca: baca DIFF SEKALI. Kode di luar diff HANYA untuk risiko konkret yang kamu sebut (nama risiko + apa yang dicek). Klaim REPORT = belum terverifikasi.
OVERRIDE format balikan template: tulis laporan LENGKAP ke <root>/.claude/build/<work-item>/task-<id>-review-r<n>.md. Pesan terakhirmu HANYA:
  spec: ✅|❌ <1 baris>
  quality: ✅|❌ (Critical n · Important n · Minor n)
  ⚠️: n
    - <item ⚠️, 1 baris per item>
  review: <path file review>
```
Re-review ronde fix = review penuh dari nol dengan paket diff FRESH (BUKAN `re-review-prompt.md` upstream), cap 3 ronde (SKILL step 4; keputusan desain user).

### Bukti ⚠️ (step 4) — subagent read-only (`Explore`)
```
Task <id>. Item ⚠️ dari reviewer:
  - <item per baris>
Brief: …-brief.md   Diff: …/review-<base7>..<head7>.diff   Repo (read-only): <path>
Per item balas 1 baris: <item> → gap nyata | aman — bukti <file:baris>
```
Keputusan tetap di controller.

### Pre-flight conflict sweep (step 1) — `subagent_type: context-vault:critic`
```
Pre-flight sweep build <work-item>: scan SELURUH <work-item>/tasks.yaml vs control/invariants.md (tenancy/money/idempotency/authz/PII-PCI) + packages[].mandatory_for di control/workspace.yaml. Kumpulkan SEMUA konflik: task yang bakal melanggar invarian, mem-bypass mandatory package, atau saling bentrok.
Balikan: satu baris per konflik — <task> · <invarian/package> · <1 baris>; atau "nol konflik".
```

### Konversi legacy `_carry-notes.md` (step 1, attended, sekali) — general-purpose
```
Konversi <root>/.claude/build/<work-item>/_carry-notes.md → <work-item>/carry.yaml (format: <abs>/skills/build/reference/j-state-titipan.md).
Task belum-done: <daftar id dari ringkasan state>. Ambil HANYA baris yang menyebut task itu atau agenda gate/ship/simplify yang belum lewat. Satu entri per titipan: from: legacy, at: <hari ini>, id C1.. (terbaru di atas). Jangan ubah _carry-notes.md.
Balikan: jumlah entri per target (mis. T75×2 · gate:M6×1 · ship×3).
```
````

- [ ] **Step 4: Edit `reference/b-brief.md`**

Ganti ``Dari satu entri `tasks.yaml`, controller (`build`) merakit **brief**`` dengan:
```text
Dari satu entri `tasks.yaml`, **brief-writer** (`${CLAUDE_PLUGIN_ROOT}/agents/brief-writer.md`, didispatch controller `build` — SKILL step 3; jalur degrade: controller sendiri; peminjam `design-system`/`fix` memakai aturan isi ini apa adanya) merakit **brief**
```
Ganti `- **Pointer pola:**` dengan:
```text
- **Titipan (`reference.md` §J):** semua titipan AKTIF task ini (`--format carry --for <id>`) — id + asal + isi apa adanya, di blok "Titipan" brief. Implementer mematuhinya seperti requirement.
- **Aturan repo:** rujuk `_rules-<repo>.md` lewat path (aturan yang sama untuk semua task di repo itu — `agents/brief-writer.md`); jangan salin isinya ke brief.
- **Pointer pola:**
```
Ganti `- **Instruksi (ditaruh di PROMPT dispatch, bukan brief):**` dengan:
```text
- **Instruksi (ditaruh di PROMPT dispatch, bukan brief — bentuk lengkap §K):**
```
Ganti `Pakai test-driven-development. Commit setelah hijau. Self-review.` dengan:
```text
Ikuti template (baca sendiri): <sdd>/implementer-prompt.md
Pakai test-driven-development. Commit setelah hijau. Self-review.
```
Ganti `Controller merakit brief-nya (pola file-handoff sama)` dengan `Brief-writer merakit brief-nya (pola file-handoff sama)`.

- [ ] **Step 5: Indeks — tambah baris K** (sesudah baris `| I | …`)

```text
| K | `reference/k-prompt-dispatch.md` | Bentuk prompt dispatch tiap subagent | tiap dispatch subagent (step 1, 3, 4) |
```

- [ ] **Step 6: Mapping Kimi**

Di heredoc `kimi-harness.md` dalam `tools/build-kimi.sh`, ganti:
```text
| subagent `context-vault:security-critic` | sub-agent `explore`; prompt = SELURUH isi `agents/security-critic.md` di root plugin + diff/konteks |
```
dengan:
```text
| subagent `context-vault:security-critic` | sub-agent `explore`; prompt = SELURUH isi `agents/security-critic.md` di root plugin + diff/konteks |
| subagent `context-vault:brief-writer` | sub-agent `coder` (perlu menulis file brief); prompt = SELURUH isi `agents/brief-writer.md` di root plugin + prompt dispatch |
```
Di `tools/tests/build-kimi.test.sh`, sesudah baris yang memuat `ok "kimi-harness.md mencatat AskUserQuestion + fallback"`, sisipkan:
```bash
grep -q 'context-vault:brief-writer' "$DST/rules/kimi-harness.md" && [ -f "$DST/agents/brief-writer.md" ] \
  && ok "kimi-harness.md memetakan brief-writer + agent ikut" || bad "brief-writer belum dipetakan / agent tak ikut"
```

- [ ] **Step 7: Jalankan**

```bash
bash tools/tests/build-lean.test.sh && bash tools/build-kimi.sh && bash tools/tests/build-kimi.test.sh && claude plugin validate plugin
```
Expected: semua exit 0. `plugin-kimi/` tetap nggak di-`git add` (Task 9).

- [ ] **Step 8: Commit**

```bash
git add plugin/agents/brief-writer.md plugin/skills/build/reference plugin/skills/build/reference.md tools/build-kimi.sh tools/tests/build-kimi.test.sh tools/tests/build-lean.test.sh
git commit -m "feat(build): agent brief-writer + reference §K bentuk prompt dispatch (template superpowers by-path, verdict reviewer ringkas) — §B dibaca brief-writer"
```

---

### Task 6: Titipan resmi — §J, step 1/2/6/7a, `ship`

**Files:**
- Create: `plugin/skills/build/reference/j-state-titipan.md`
- Modify: `plugin/skills/build/reference.md` (baris J), `plugin/skills/build/SKILL.md`, `plugin/skills/ship/SKILL.md`, `tools/tests/build-lean.test.sh`

**Interfaces:**
- Consumes: `--format controller|carry` (Task 2–3), §K konversi legacy (Task 5).
- Produces: §J (dirujuk SKILL di Task 7).

- [ ] **Step 1: Tambah kontrak di `build-lean.test.sh`**

```bash
# === T6: titipan ===
J="$B/reference/j-state-titipan.md"
has "$J" "# carry.yaml — titipan antar-task build. Penulis tunggal: controller build. Entri terbaru di ATAS." "§J: header carry.yaml"
has "$J" "Kandidat debt BUKAN titipan" "§J: debt tetap ke debt.yaml (D10)"
has "$B/reference.md" "reference/j-state-titipan.md" "indeks: §J"
has "$B/SKILL.md" "--format carry --for gate:<M>/<unit>" "SKILL gate: agenda titipan"
has "$B/SKILL.md" "--format carry --for simplify" "SKILL 7a: titipan simplify"
has "$B/SKILL.md" "**Titipan legacy (sekali, attended):**" "SKILL step 1: konversi legacy"
has "$B/SKILL.md" "WAJIB sebelum tick: brief-writer cuma tahu yang tertulis" "SKILL step 2: titipan sebelum tick (D6)"
has "$ROOT/plugin/skills/ship/SKILL.md" "--format carry --for ship" "ship: titipan ship"
```
Run → FAIL di blok T6.

- [ ] **Step 2: Tulis `reference/j-state-titipan.md`**

`````markdown
## J. Ringkasan state (`build_status.py`) + titipan (`carry.yaml`)

### Ringkasan state — controller pegang PETA, bukan isi file
`python3 .claude/build_status.py --root . --format <f> --work-item <work-item>` (read-only, stdlib; salinan template di produk lewat `init`/`upgrade`):
- `controller` — teks ringkas. Baris:
  - `work-item:` (kind · risk efektif · sensitivity);
  - `staleness:` (`STALE <file> > tasks.yaml` / `WARN business.md > tasks.yaml` / `OK`);
  - `repos:`;
  - `READY:` per repo, urut dokumen; `(sibuk <id>)` = repo punya task in-flight;
  - `in_progress:`, `hold:`, `blocked:`, `gates queued:`, `reuse basi:`;
  - `carry:` (jumlah titipan aktif per target + `next C<n>`, atau `legacy`);
  - `map:` — milestone kelar dilipat 1 baris, sisanya 1 baris per task: id · unit · status · deps · desc ≤ 80 karakter.
  Jalankan ulang tiap scheduler tick (murah).
- `task --task <id>[,<id>…]` — JSON entri task lengkap (+ `milestone`). Dipakai brief-writer, gate step 6, dan waktu controller butuh detail satu task.
- `carry --for <target>[,<target>…]` — JSON titipan AKTIF untuk target itu.

Kalau exit ≠ 0 (salinan lama), atau mode unattended tanpa entri allowlist `Bash(python3 .claude/build_status.py:*)`, controller degrade ke cara lama (SKILL step 1).

### Titipan — `<work-item>/carry.yaml`
Isinya keputusan/temuan yang ngaruh ke task LAIN, ke gate, ke `ship`, atau ke simplify 7a. File ini ikut ke-commit, karena ini state resume, setara `tasks.yaml`/`gates.yaml`. Controller membuatnya waktu ada titipan pertama, dengan header persis ini:
```yaml
# carry.yaml — titipan antar-task build. Penulis tunggal: controller build. Entri terbaru di ATAS.
notes:
  - id: C2
    for: T75            # id task | gate:<M> | gate:<M>/<unit> | ship | simplify
    from: review T66    # review Tn | preflight | gate <M> | drain | user <YYYY-MM-DD> | legacy
    at: 2026-10-20
    note: "pratinjau daftar nama sebelum simpan"
  - id: C1
    for: gate:M4
    from: review T52
    at: 2026-10-19
    note: "urutan deploy: migrasi PR-1 terbukti di production dulu"
    closed: 2026-10-20  # opsional — titipan gate/ship/simplify yang sudah dipakai
```
- **Kapan tulis (WAJIB).** Sebelum scheduler tick berikutnya (urutan atomik SKILL step 2), tiap ada keputusan/temuan yang ngaruh ke task/gate/ship/simplify lain. Sumbernya: pre-flight sweep, verdict reviewer, gate, drain pagi, jawaban user, atau jawaban ambigu brief-writer. Yang cuma relevan buat task berjalan → JANGAN dititip. Brief-writer cuma tahu yang tertulis di sini.
- **Cara tulis (tanpa baca file utuh).**
  - Titipan pertama → Write file dengan header di atas.
  - Selanjutnya → Read `limit: 3` (Edit butuh file sudah di-Read), lalu Edit ganti baris `notes:` dengan `notes:` + entri baru. Id-nya = `next` dari baris `carry:` ringkasan state.
  - Menutup entri: `Grep -n 'id: C<n>$'` → Read rentang entri → Edit tambah baris `closed: <tanggal>`.
- **Siapa baca.** Brief-writer `--for <task>`; gate step 6 `--for gate:<M>/<unit>`; 7a `--for simplify`; `ship` `--for ship`. Controller cuma melihat JUMLAH (baris `carry:`).
- **Target gate.** `gate:<M>` berlaku untuk semua segmen milestone itu; `gate:<M>/<unit>` cuma segmen itu. Minta `--for gate:M4/api` → dapat `gate:M4` + `gate:M4/api`.
- **Aktif.** Titipan ber-`for:` task yang sudah `done`, dan titipan ber-`closed:`, tidak dikeluarkan `--format carry`. Entrinya tetap di file sebagai jejak audit.
- **Penulis tunggal = controller.** Satu-satunya pengecualian: subagent konversi legacy (sekali, attended, sebelum dispatch apa pun).
- **Kandidat debt BUKAN titipan** → langsung `control/debt.yaml` (pintu ke-4, SKILL step 6).

### Legacy `_carry-notes.md`
`.claude/build/<work-item>/_carry-notes.md` (catatan bebas buatan run lama, belum resmi) yang ada tanpa `carry.yaml` → baris `carry:` bertanda `legacy`.
- **Attended:** SEKALI, sebelum dispatch pertama. Dispatch subagent konversi (prompt §K) → `carry.yaml` (`from: legacy`) → balik jumlah per target. Tunjukkan JUMLAH-nya ke user, bukan isinya. File lama tetap ada sebagai arsip.
- **Unattended, atau belum dikonversi:** `--format carry` mengambil baris `_carry-notes.md` yang menyebut token target (`T75`; `gate:M4` → `M4`; `ship`; `simplify` → `simplify`/`7a`) dengan `source: legacy`.
`````

- [ ] **Step 3: Indeks — tambah baris J** (antara baris I dan K)

```text
| J | `reference/j-state-titipan.md` | Ringkasan state `build_status.py` + titipan `carry.yaml` | step 1 (ringkasan state), tiap ada titipan, gate step 6, 7a |
```

- [ ] **Step 4: SKILL.md — bullet legacy di step 1**

Ganti `- **Lapor-keluar (mode unattended — M7):**` dengan:
```text
- **Titipan legacy (sekali, attended):** baris `carry:` ringkasan state bertanda `legacy` (ada `.claude/build/<work-item>/_carry-notes.md` tanpa `<work-item>/carry.yaml`) DAN attended → SEBELUM dispatch pertama, dispatch subagent konversi (prompt `reference.md` §K) → `carry.yaml` (`from: legacy`) → tampilkan JUMLAH per target ke user (bukan isi). Unattended → jangan konversi; brief-writer & `--format carry` membaca legacy (§J).
- **Lapor-keluar (mode unattended — M7):**
```

- [ ] **Step 5: SKILL.md — urutan atomik step 2**

Ganti `(1) proses completion (verify + review + status, step 4–5)` dengan:
```text
(1) proses completion (verify + review + status, step 4–5) + APPEND titipan untuk keputusan/temuan yang ngaruh ke task/gate/ship/simplify lain (`reference.md` §J — WAJIB sebelum tick: brief-writer cuma tahu yang tertulis)
```

- [ ] **Step 6: SKILL.md — gate step 6**

Ganti `Lalu: tampilkan diff segmen + hasil test + "dibangun vs task" + **challenge checklist**` dengan:
```text
Lalu: tampilkan diff segmen + hasil test + "dibangun vs task" (detail task segmen: `--format task --task <id segmen>`; agenda titipan: `--format carry --for gate:<M>/<unit>` → tampilkan, lalu set `closed:` yang terpakai sesudah gate lolos, §J) + **challenge checklist**
```

- [ ] **Step 7: SKILL.md — 7a**

Ganti `Jalankan SATU pass simplifikasi atas **diff fitur utuh**` dengan:
```text
Ambil titipan `--format carry --for simplify` (masukan tambahan; set `closed:` sesudah dipakai, §J). Jalankan SATU pass simplifikasi atas **diff fitur utuh**
```

- [ ] **Step 8: `ship/SKILL.md`**

Ganti `**Guard diff kosong:** kalau tidak ada perubahan kode terhadap base, jangan bikin PR — laporkan.` dengan:
```text
**Guard diff kosong:** kalau tidak ada perubahan kode terhadap base, jangan bikin PR — laporkan. **Titipan build (`for: ship`):** jalankan `python3 .claude/build_status.py --root . --format carry --for ship --work-item <work-item>` (absen / exit ≠ 0 → baca `<work-item>/carry.yaml` sendiri: entri `for: ship` tanpa `closed:`; atau legacy `.claude/build/<work-item>/_carry-notes.md`: baris ber-kata `ship`) → tampilkan tiap titipan sebagai item checklist finishing gate; yang menyangkut reviewer PR (urutan deploy, prasyarat migrasi/env) masuk body PR.
```

- [ ] **Step 9: Jalankan + commit**

```bash
bash tools/tests/build-lean.test.sh && bash tools/tests/ask-user.test.sh
git add plugin/skills/build plugin/skills/ship/SKILL.md tools/tests/build-lean.test.sh
git commit -m "feat(build): titipan antar-task resmi — carry.yaml (§J), konversi legacy _carry-notes.md, wajib tulis sebelum tick, dibaca gate/7a/ship"
```

---

### Task 7: Controller pakai peta + brief-writer (SKILL step 1–3, §E)

**Files:**
- Modify: `plugin/skills/build/SKILL.md`, `plugin/skills/build/reference/e-status-resume.md`, `tools/tests/build-lean.test.sh`

**Interfaces:**
- Consumes: `--format controller|task|carry` (Task 2–3), agent + §K (Task 5), §J (Task 6).

- [ ] **Step 1: Tambah kontrak di `build-lean.test.sh`**

```bash
# === T7: controller pakai peta + brief-writer ===
S="$B/SKILL.md"
has "$S" "= **indeks**" "SKILL: reference = indeks, baca per step"
has "$S" "--format controller --work-item <work-item>" "SKILL step 1: ringkasan state"
has "$S" 'Bash(python3 .claude/build_status.py:*)' "SKILL step 1: cek allowlist sebelum panggil (unattended)"
has "$S" 'jalankan `/upgrade` biar build hemat context' "SKILL step 1: WARN degrade"
has "$S" "**Brief dirakit subagent \`context-vault:brief-writer\`**" "SKILL step 3: brief-writer"
has "$S" '`hold: "NEEDS_CONTEXT: <pertanyaan verbatim>"`, lanjut task lain' "SKILL step 3: ambigu unattended → hold"
hasnt "$S" "Rakit **BRIEF** LENGKAP dari task" "SKILL: controller tak merakit brief lagi"
has "$S" "dispatch SATU subagent \`context-vault:critic\`" "SKILL step 1: pre-flight via subagent"
has "$B/reference/e-status-resume.md" "**Tanpa membaca file utuh**" "§E: tulis status tanpa baca utuh"
```
Run → FAIL di blok T7.

- [ ] **Step 2: SKILL.md — baris panduan (atas)**

Ganti:
```text
> Panduan dispatch (rakit prompt implementer dari satu task, template yang dipinjam, pilih model, cadence gate, resume) ada di `${CLAUDE_PLUGIN_ROOT}/skills/build/reference.md` — baca itu dulu.
```
dengan:
```text
> Panduan (dispatch, model, gate, resume, unattended, ringkasan state & titipan) ada di `${CLAUDE_PLUGIN_ROOT}/skills/build/reference.md` = **indeks** → baca indeksnya, lalu baca section §X (`reference/<x>-*.md`) **hanya saat sampai di step yang menyebutnya** — jangan baca semua di depan. §B (isi brief) dibaca brief-writer, BUKAN controller.
```

- [ ] **Step 3: SKILL.md — pembuka step 1**

Ganti (persis, satu span):
```text
Baca `<work-item>/tasks.yaml` (work-item = `control/features/<fitur>/` ATAU `control/fixes/<id>/`) + (fitur) `plans/*` + `_shared.md` + `control/conventions.md` + `control/workspace.yaml` (path/stack). **Read-set dari manifest:** bila `tasks.yaml` punya `generated_from` versi MANIFEST ter-resolve (daftar read-set eksplisit — `breakdown/reference.md` §A), pakai itu sebagai daftar-baca otoritatif (manifest = file MANA yang dibaca; *kapan* `control/schema/<unit>.md` di-load tetap LAZY per-task — lihat kalimat berikut). Manifest absen / `generated_from` tak memuat entri `control/` (format lama — cuma daftar `plans/*`) → **degrade**: derive read-set dari konvensi seperti di kalimat ini. Baca `control/schema/<unit>.md` **LAZY per-task** (hanya slice yang akan ditulis ke brief task berjalan, `reference.md` §B — bukan load penuh semua unit di depan; jaga sesi build ramping & resumable).
```
dengan:
```text
**Ringkasan state DULU — controller pegang PETA, bukan isi file** (work-item = `control/features/<fitur>/` ATAU `control/fixes/<id>/`): `python3 .claude/build_status.py --root . --format controller --work-item <work-item>` → peta 1 baris/task (milestone kelar dilipat) + READY per repo + in_progress + hold + blocked + gate antri + staleness + risk efektif + reuse basi + jumlah titipan (format `reference.md` §J). JANGAN baca `tasks.yaml`/`plans/*`/`_shared.md` utuh di awal — detail dibaca SAAT DIBUTUHKAN: entri task lewat `--format task --task <id,…> --work-item <work-item>` (gate step 6, jawab ambigu), section `plans/<unit>.md`/`_shared.md` yang relevan (jawab pertanyaan implementer/brief-writer), titipan lewat `--format carry --for <target> --work-item <work-item>`. **Read-set dari manifest:** `generated_from` versi MANIFEST (`breakdown/reference.md` §A) tetap otoritatif soal file MANA yang relevan (dipakai brief-writer & saat controller butuh detail); `control/schema/<unit>.md` dibaca brief-writer per-task (slice, `reference.md` §B), bukan controller. **Degrade = cara lama:** (a) mode unattended DAN `.claude/settings.json` tak memuat `Bash(python3 .claude/build_status.py:*)` → JANGAN panggil (permission prompt = run beku); (b) panggilan exit ≠ 0 (salinan lama tanpa format ini) → baca `<work-item>/tasks.yaml` + (fitur) `plans/*` + `_shared.md` + `control/conventions.md` + `control/workspace.yaml` sendiri, hitung READY/staleness/reuse sendiri, dan rakit brief SENDIRI per `reference.md` §B (tanpa brief-writer, tanpa titipan resmi) + WARN "jalankan `/upgrade` biar build hemat context" (unattended: catat di prosa `last-run.md`).
```

- [ ] **Step 4: SKILL.md — risk, gates, staleness, reuse, pre-flight**

| Ganti | dengan |
|---|---|
| ``bila work-item fitur, baca juga `feature.yaml` `risk` `` | ``bila work-item fitur, ambil `risk` efektif dari baris `work-item:` ringkasan state (degrade: baca `feature.yaml` `risk`)`` |
| ``**Baca `<work-item>/gates.yaml`** (absen → kosong)`` | ``**Gate antri:** baris `gates queued:` ringkasan state (degrade: baca `<work-item>/gates.yaml`; absen → kosong)`` |
| ``- **Staleness check:** bila `plans/*` `` | ``- **Staleness check:** (sumber: baris `staleness:` ringkasan state — `STALE …` / `WARN business.md …` / `OK`; degrade: cek mtime sendiri) bila `plans/*` `` |
| ``Cukup baca **daftar-nama** tabel/file (bukan slice penuh — slice tetap lazy per-task di step 3).`` | ``Sumber = baris `reuse basi:` ringkasan state (deterministik: nama `## <Tabel>` di proyeksi pemilik + keberadaan file di pohon unit; proyeksi absen/stub → tak dilaporkan); degrade: baca **daftar-nama** tabel/file sendiri (bukan slice penuh).`` |
| ``scan SELURUH `tasks.yaml` sekali jalan vs `control/invariants.md` `` | ``dispatch SATU subagent `context-vault:critic` (prompt `reference.md` §K — controller TIDAK membaca `tasks.yaml` utuh) yang scan SELURUH `tasks.yaml` sekali jalan vs `control/invariants.md` `` |
| ``lalu sodorkan jadi **SATU pertanyaan batched** ke user sebelum task-1.`` | ``lalu sodorkan jadi **SATU pertanyaan batched** ke user sebelum task-1. Keputusan per konflik → titipan `for: <task>` (`from: preflight`, §J) supaya masuk brief task itu.`` |

(Isi sel tabel = teks persis di dalam pembungkus ``…``. Spasi tepat sebelum `` penutup — ada di sel yang teksnya berakhir dengan backtick — cuma syarat penulisan Markdown, BUKAN bagian teks, baik di kolom kiri maupun kanan.)

- [ ] **Step 5: SKILL.md — READY step 2**

Ganti:
```text
Hitung **READY-SET** = SEMUA task `pending` yang seluruh `deps`-nya `done`; kelompokkan per **repo** (toplevel dari probe step 1, `reference.md` §F).
```
dengan:
```text
**READY-SET** = baris `READY:` ringkasan state — jalankan ulang `--format controller` tiap scheduler tick (murah, deterministik; repo bertanda `sibuk <id>` sedang punya task in-flight). Degrade: hitung sendiri = SEMUA task `pending` yang seluruh `deps`-nya `done`, kelompokkan per **repo** (toplevel dari probe step 1, `reference.md` §F).
```

- [ ] **Step 6: SKILL.md — rakit brief step 3**

Ganti (persis, satu span):
```text
Rakit **BRIEF** LENGKAP dari task lalu **TULIS ke file** `<root>/.claude/build/<work-item>/task-<id>-brief.md` (scratch; sekali per run pastikan `.claude/build/` ter-gitignore — self-heal, pola sama `notify.sh`); **jangan** suruh subagent baca `tasks.yaml`: `desc` + `files` + `approach` + kasus `test` + potongan `_shared.md` + konvensi + stack + **(bila unit app & proyeksi non-stub) blok skema & struktur existing (slice control/schema/<schema_owner(unit)>.md + listing dir + directive reuse, `reference.md` §B)** + pointer file pola + **(bila task ber-`mockup:`) isi/pointer file mockup + instruksi reproduksi-visual (`reference.md` §B)**. **Untuk tiap `deps`: baca file dep yang sudah ada di disk & tulis signature/ekspor ASLINYA** ke brief — jangan biarkan implementer nebak dari teks `approach`. **Prompt dispatch = RAMPING (pola file-handoff `subagent-driven-development` ≥6.0):** pointer brief ("baca ini dulu — ini requirement-mu, nilai eksak dipakai verbatim") + path report `task-<id>-report.md` (sebelah brief) + kontrak balikan.
```
dengan:
```text
**Brief dirakit subagent `context-vault:brief-writer`** (`${CLAUDE_PLUGIN_ROOT}/agents/brief-writer.md`, model = model controller), BUKAN controller — controller tak membaca kode/skema/mockup/plan demi brief. Dispatch (prompt `reference.md` §K) dengan: root, work-item, id task, path absolut `${CLAUDE_PLUGIN_ROOT}/skills/build/reference/b-brief.md`, peta `repo → base7` repo yang SIBUK (punya task in-flight), dan path brief `<root>/.claude/build/<work-item>/task-<id>-brief.md` (scratch; sekali per run pastikan `.claude/build/` ter-gitignore — self-heal, pola sama `notify.sh`). Brief-writer menulis brief LENGKAP per §B — `desc` + `files` + `approach` + kasus `test` + potongan `_shared.md` + konvensi + stack + (unit app & proyeksi non-stub) skema & struktur existing + pointer pola + (task ber-`mockup:`) mockup + instruksi reproduksi-visual + **signature/ekspor ASLI tiap `deps` dari disk** + titipan task ini — dan `_rules-<repo>.md` bila basi, lalu balik ≤10 baris (`brief`/`rules`/`titipan`/`deps`/`ambigu`/`tier`). **`ambigu:` ≠ `none` → JANGAN dispatch implementer dulu:** jawab dari peta + section plan yang relevan → jawaban khusus task ini: re-dispatch brief-writer dengan jawaban ditempel (atau append ≤2 baris ke brief); jawaban yang ngaruh task lain: titipan DULU (§J). Controller tak bisa jawab → attended: tanya user (`AskUserQuestion`); unattended: `needs_human` + `hold: "NEEDS_CONTEXT: <pertanyaan verbatim>"`, lanjut task lain. `deps:` ber-`DRIFT` → catat buat gate. **Prompt dispatch implementer = RAMPING** (bentuk `reference.md` §K; pola file-handoff `subagent-driven-development` ≥6.0): pointer brief ("baca ini dulu — ini requirement-mu, nilai eksak dipakai verbatim") + path template `implementer-prompt.md` (implementer yang membaca, controller TIDAK) + path report `task-<id>-report.md` (sebelah brief) + kontrak balikan.
```

- [ ] **Step 7: SKILL.md — signature dep, pointer detail, catatan, atomik**

| Ganti | dengan |
|---|---|
| ``**Signature dep saat repo dep SIBUK:** baca dari base-SHA task in-flight repo itu`` | ``**Signature dep saat repo dep SIBUK:** controller menyerahkan `repo → base7` in-flight ke brief-writer, yang membaca dari base-SHA task in-flight repo itu`` |
| ``(Detail rakitan brief + matrix status balikan: `reference.md` bagian B & E.)`` | ``(Rakitan brief: `agents/brief-writer.md` + `reference.md` §B — dibaca brief-writer, BUKAN controller. Bentuk prompt dispatch: §K. Matrix status balikan: §E.)`` |
| ``- Hemat konteks: kerja berat di subagent;`` | ``- Hemat konteks: controller pegang PETA (ringkasan state `build_status.py`, §J), bukan isi file/kode; kerja berat (rakit brief, implementasi, review, bukti ⚠️, sweep pre-flight, konversi legacy) di subagent;`` |
| ``(atomik — tulis ke `tasks.yaml`)`` | ``(atomik — tulis ke `tasks.yaml` tanpa membaca file utuh, prosedur `reference.md` §E)`` |

- [ ] **Step 8: `reference/e-status-resume.md`**

Ganti `` `tasks.yaml` ikut ke-commit, jadi versi korup bisa dipulihkan dari git.`` dengan:
```text
`tasks.yaml` ikut ke-commit, jadi versi korup bisa dipulihkan dari git. **Tanpa membaca file utuh** (`tasks.yaml` bisa >100KB; controller pegang ringkasan state, bukan isi file): `Grep -n '- id: <id>$'` → Read rentang blok task itu (`offset`/`limit`, cukup sampai baris `status:`) → Edit dengan `old_string` dari baris `- id:` sampai baris `status:` (unik per task).
```
Ganti ``**Resume (sesi baru):** baca `tasks.yaml`.`` dengan ``**Resume (sesi baru):** ringkasan state (SKILL step 1; degrade: baca `tasks.yaml`).``

- [ ] **Step 9: Jalankan + commit**

```bash
bash tools/tests/build-lean.test.sh && bash tools/tests/ask-user.test.sh
git add plugin/skills/build tools/tests/build-lean.test.sh
git commit -m "feat(build): controller pegang peta (ringkasan state build_status.py), brief via brief-writer, pre-flight via subagent, degrade cara lama + WARN upgrade"
```

---

### Task 8: Jalur review — paket diff git, reviewer by-path, verdict ringkas, bukti ⚠️

**Files:**
- Modify: `plugin/skills/build/SKILL.md`, `plugin/skills/build/reference/a-pinjam-sdd.md`, `plugin/skills/build/reference/e-status-resume.md`, `tools/tests/build-lean.test.sh`

- [ ] **Step 1: Tambah kontrak di `build-lean.test.sh`**

```bash
# === T8: jalur review ===
has "$S" "SELALU lewat git di SEMUA mode" "SKILL step 4: paket diff via git (D11)"
has "$S" "**override format balikan**" "SKILL step 4: override format reviewer"
has "$S" 'path file review `task-<id>-review-r<n>.md`' "SKILL step 4: re-dispatch tunjuk file review"
has "$S" "controller MEMUTUSKAN tiap item ⚠️ sendiri" "SKILL step 4: keputusan ⚠️ tetap controller"
has "$S" "**Cap maksimal 3 ronde**" "SKILL step 4: cap 3 ronde tak berubah (D12)"
has "$B/reference/a-pinjam-sdd.md" "cap 3 ronde = keputusan desain user" "§A: re-review scoped/resume tidak diadopsi"
n="$(grep -rlF 'scripts/review-package' "$B" | grep -v 'a-pinjam-sdd.md' | wc -l | tr -d ' ')"
[ "$n" = 0 ] && ok "review-package hanya disebut di §A (tidak dipakai)" || bad "review-package masih dipanggil di luar §A ($n file)"
hasnt "$B/reference/e-status-resume.md" 'diff via `review-package`' "§E: paket review via git"
```
Run → FAIL di blok T8.

- [ ] **Step 2: SKILL.md — paket diff (step 4)**

Ganti (persis, satu span):
```text
(3) **paket diff** — jalankan `scripts/review-package <base> <head> <root>/.claude/build/<work-item>/review-<base7>..<head7>.diff` milik `subagent-driven-development` (`base` = SHA yang DIREKAM step 3, BUKAN `HEAD~1`; **OUTFILE arg-3 WAJIB diisi** — tanpa itu script sejak superpowers 6.0.3 default ke `.superpowers/sdd/` di repo APP (via `sdd-workspace`) → scratch nyebar ke dua dir; penamaan per-range dijaga di OUTFILE → re-review pasca-fix otomatis dapat file fresh; parent dir sudah ada sejak brief step 3 — script TIDAK mkdir); script tak tersedia → fallback: `git log --oneline base..head` + `git diff --stat` + `git diff -U10` di-redirect ke path+penamaan OUTFILE yang SAMA. **Unattended/headless: LANGSUNG pakai fallback git** — path script di plugin-cache ber-nomor-versi tak mungkin di-allowlist (wildcard-tengah mati), sedangkan bentuk `git -C <P> log/diff` sudah dienumerasi `wire` 5.5; jangan biarkan run beku di permission prompt.
```
dengan:
```text
(3) **paket diff** — SELALU lewat git di SEMUA mode: `git -C <path> log --oneline <base>..<head>` + `git -C <path> diff --stat <base>..<head>` + `git -C <path> diff -U10 <base>..<head>` di-redirect ke `<root>/.claude/build/<work-item>/review-<base7>..<head7>.diff` (`base` = SHA yang DIREKAM step 3, BUKAN `HEAD~1`; penamaan per-range → re-review pasca-fix otomatis dapat file fresh; parent dir sudah ada sejak brief step 3; bentuk `git -C <P> log/diff` sudah dienumerasi `wire` 5.5). Script `review-package` upstream TIDAK dipakai lagi: sejak superpowers 6.2 ia minta `PLAN_FILE BASE HEAD [OUTFILE]` (panggilan 3-arg lama gagal "no such plan file"), dan path plugin-cache bernomor versi tak bisa di-allowlist.
```

- [ ] **Step 3: SKILL.md — reviewer, ⚠️, re-dispatch**

Ganti:
```text
Lalu dispatch **task-reviewer** — SATU subagent, template `task-reviewer-prompt.md` `subagent-driven-development` (superpowers ≥6.0 menggabungkan spec-reviewer + code-quality-reviewer lama), prompt = tiga path di atas + global constraints (invarian/konvensi yang mengikat task);
```
dengan:
```text
Lalu dispatch **task-reviewer** — SATU subagent (prompt `reference.md` §K): path template `task-reviewer-prompt.md` `subagent-driven-development` (REVIEWER yang membacanya, controller TIDAK; superpowers ≥6.0 menggabungkan spec-reviewer + code-quality-reviewer lama) + tiga path di atas + global constraints (invarian/konvensi yang mengikat task + aturan baca-diff-sekali §K) + **override format balikan** (template ≥6.2 bilang "pesan terakhir = laporan" → di sini laporan LENGKAP ke `<root>/.claude/build/<work-item>/task-<id>-review-r<n>.md`, pesan terakhir = verdict ringkas ≤12 baris);
```
Ganti ``controller resolve TIAP item ⚠️ **sendiri** (ia yang pegang `tasks.yaml` + plans + kode)`` dengan:
```text
controller MEMUTUSKAN tiap item ⚠️ sendiri (ia yang pegang peta + titipan) — buktinya: cek tertarget sendiri bila kecil (grep/sed, output ≲2K karakter per item), selebihnya dispatch subagent read-only (prompt §K → per item `gap nyata | aman` + bukti `file:baris`)
```
Ganti `pointer brief + temuan reviewer + SHA/file yang disentuh` dengan:
```text
pointer brief + path file review `task-<id>-review-r<n>.md` (temuan lengkap ada di sana — JANGAN salin ke prompt) + SHA/file yang disentuh
```

- [ ] **Step 4: `reference/a-pinjam-sdd.md`**

| Ganti | dengan |
|---|---|
| ``- `implementer-prompt.md` — struktur prompt implementer (≥6.0: ber-placeholder `[BRIEF_FILE]` + `[REPORT_FILE]`, bukan slot teks-task).`` | ``- `implementer-prompt.md` — struktur prompt implementer (≥6.0: ber-placeholder `[BRIEF_FILE]` + `[REPORT_FILE]`, bukan slot teks-task). Controller TIDAK membaca isinya — path-nya diserahkan ke implementer (§K).`` |
| ``(superpowers ≥6.0 menggabungkan `spec-reviewer-prompt.md` + `code-quality-reviewer-prompt.md` lama — dua file itu sudah TIDAK ada, jangan dirujuk.)`` | ``(superpowers ≥6.0 menggabungkan `spec-reviewer-prompt.md` + `code-quality-reviewer-prompt.md` lama — dua file itu sudah TIDAK ada, jangan dirujuk.) Controller TIDAK membaca isinya — path ke reviewer (§K); format balikan template ≥6.2 ("pesan terakhir = laporan") di-OVERRIDE: laporan lengkap ke file review + verdict ringkas.`` |
| ``Paranoia controller tidak dilonggarkan.`` | ``Paranoia controller tidak dilonggarkan. Juga TIDAK dipinjam (sampai ada keputusan terpisah): `re-review-prompt.md` (re-review scoped, ≥6.2) & resume implementer di ronde fix — `build` tetap review penuh dari nol dengan paket diff fresh, **cap 3 ronde = keputusan desain user** (bukan turunan upstream yang 5 ronde).`` |
| ``→ `build` **menulis brief-nya SENDIRI**`` | ``→ brief ditulis **brief-writer** (`agents/brief-writer.md`) per §B`` |
| ``; `scripts/review-package` tetap dipakai karena git-based).`` | ``; `scripts/review-package` juga tidak lagi — lihat bullet di atas).`` |

Ganti (satu baris penuh):
```text
- `scripts/review-package BASE HEAD OUTFILE` — generator paket diff reviewer (commit list + stat + `diff -U10`). Git-based → dipakai langsung, TAPI **OUTFILE (arg-3) selalu diisi** `<root>/.claude/build/<work-item>/review-<base7>..<head7>.diff` (penamaan per-range dijaga manual); tanpa arg-3, sejak 6.0.3 script default ke `<repo-root>/.superpowers/sdd/` repo app (via `sdd-workspace`, self-gitignore) — dir scratch KEDUA di luar `.claude/build/`, jangan.
```
dengan:
```text
- `scripts/review-package` — TIDAK dipakai lagi. Sejak superpowers 6.2 signature-nya `PLAN_FILE BASE HEAD [OUTFILE]` (panggilan 3-arg lama gagal "no such plan file"), dan path plugin-cache bernomor versi tak bisa di-allowlist. Paket diff dirakit lewat git di semua mode (SKILL step 4) — isi setara: commit list + stat + `diff -U10`, ke `<root>/.claude/build/<work-item>/review-<base7>..<head7>.diff`.
```

- [ ] **Step 5: `reference/e-status-resume.md`**

| Ganti | dengan |
|---|---|
| ``rakit paket review (brief + report + diff via `review-package`)`` | ``rakit paket review (brief + report + diff via git, SKILL step 4)`` |
| ``controller resolve tiap item sendiri (SKILL step 4)`` | ``controller memutuskan tiap item (bukti: cek kecil sendiri atau subagent read-only §K, SKILL step 4)`` |

- [ ] **Step 6: Jalankan + commit**

```bash
bash tools/tests/build-lean.test.sh && bash tools/tests/ask-user.test.sh
git add plugin/skills/build tools/tests/build-lean.test.sh
git commit -m "fix(build): paket diff selalu via git (review-package superpowers 6.2 minta PLAN_FILE), reviewer by-path + verdict ringkas ke file, bukti ⚠️ via subagent — cap 3 ronde tetap"
```

---

### Task 9: Dokumentasi, versi, regen Kimi, semua test

**Files:**
- Modify: `plugin/skills/guide/reference.md`, `plugin/.claude-plugin/plugin.json`
- Regenerate: `plugin-kimi/**`

- [ ] **Step 1: `guide/reference.md`**

Ganti `` unattended: baris progres live di terminal `drive.sh`.`` dengan:
```text
unattended: baris progres live di terminal `drive.sh`. Hemat context (0.28): controller pegang peta dari `build_status.py`, brief dirakit subagent `brief-writer`, titipan antar-task di `carry.yaml`; produk lama → `/upgrade`.
```

- [ ] **Step 2: `plugin.json`**

- `"version": "0.27.1"` → `"version": "0.28.0"`. Kalau plan lain sudah bump, naikkan minor sekali lagi dari HEAD.
- Di `description`, sisipkan `build hemat context (brief-writer subagent + ringkasan state build_status.py + titipan carry.yaml), ` tepat sebelum `panel status build (mod:`.
- Validasi: `jq . plugin/.claude-plugin/plugin.json >/dev/null`.

- [ ] **Step 3: Regen Kimi + semua test**

```bash
bash tools/build-kimi.sh
for t in tools/tests/*.test.sh plugin/hooks/tests/*.test.sh; do bash "$t" >/dev/null 2>&1 && echo "ok $t" || echo "FAIL $t"; done
claude plugin validate plugin
claude plugin test plugin
test -f plugin-kimi/agents/brief-writer.md && test -f plugin-kimi/skills/build/reference/k-prompt-dispatch.md && echo ok-kimi
```
Expected: semua `ok`, validate/test exit 0, `ok-kimi`.

- [ ] **Step 4: Grep sisa**

```bash
grep -rn 'baca itu dulu' plugin/skills/build || echo ok-no-eager
grep -rln 'scripts/review-package' plugin/skills | grep -v 'build/reference/a-pinjam-sdd.md' || echo ok-no-rp
```
Expected: `ok-no-eager` dan `ok-no-rp`.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/guide/reference.md plugin/.claude-plugin/plugin.json plugin-kimi
git commit -m "chore(release): build hemat context — 0.28.0, guide, regen plugin-kimi"
```

---

### Task 10: Acceptance (read-only) + probe headless

Nggak ada file produk yang diubah. Hasil tiap step dicatat apa adanya di laporan akhir.

- [ ] **Step 1: Format baru di produk nyata**

```bash
BS=plugin/template/.claude/build_status.py; M=~/Developer/project/mahjong
python3 -B $BS --root $M --format controller --work-item control/features/venue-tables | tee /tmp/vt.txt | head -20; wc -c /tmp/vt.txt
python3 -B $BS --root $M --format task --task "$(grep -oE 'T[0-9]+' /tmp/vt.txt | sed -n 1p)" --work-item control/features/venue-tables | head -c 400; echo
for d in ~/Developer/project/*/; do [ -f "$d/control/workspace.yaml" ] || continue
  for w in "$d"control/features/*/ "$d"control/fixes/*/; do [ -f "$w/tasks.yaml" ] || continue
    python3 -B $BS --root "$d" --format controller --work-item "${w#$d}" >/dev/null || echo "EXIT≠0 $w"; done; done
```
Expected:
- ukuran `/tmp/vt.txt` ≤ 16000 karakter (laporkan angkanya);
- baris `carry:` venue-tables bertanda `legacy`;
- nggak ada `EXIT≠0` dan nggak ada traceback.

- [ ] **Step 2: Salinan lama di produk → exit ≠ 0 (pemicu degrade)**

Run: `python3 -B ~/Developer/project/mahjong/.claude/build_status.py --root ~/Developer/project/mahjong --format controller --work-item control/features/venue-tables; echo "rc=$?"`

Expected: `rc=2` (argparse menolak), selama mahjong belum di-`/upgrade`.

- [ ] **Step 3: Titipan legacy venue-tables**

Ambil satu id `pending` dari `/tmp/vt.txt` yang disebut di `.claude/build/venue-tables/_carry-notes.md` (cek `grep -c '\bT<id>\b'`). Lalu jalankan `--format carry --for <id> --work-item control/features/venue-tables`.

Expected: `source: legacy`, ada ≥ 1 baris. Jalankan juga satu id `done` → `notes: []`.

- [ ] **Step 4: Probe headless — Read & Glob di luar root produk** (butuh auth nyata, biaya kecil)

```bash
P=$(mktemp -d); git -C "$P" init -q
SDD=$(ls -d ~/.claude/plugins/cache/*/superpowers/*/skills/subagent-driven-development | sort -V | tail -1)
CVB=$(ls -d ~/.claude/plugins/cache/*/context-vault/*/skills/build | sort -V | tail -1)
for f in "$SDD/implementer-prompt.md" "$CVB/reference.md"; do
  (cd "$P" && claude -p "Pakai tool Agent (subagent_type general-purpose). Suruh subagent membaca file $f dengan tool Read lalu membalas HANYA baris pertamanya. Balas persis balasan subagent itu." --permission-mode acceptEdits); echo "== $f"; done
(cd "$P" && claude -p "Pakai tool Glob dengan path $HOME/.claude/plugins/cache dan pattern */superpowers/*/skills/subagent-driven-development/implementer-prompt.md. Balas daftar path-nya saja." --permission-mode acceptEdits)
```
Expected: baris pertama tiap file (bukan pesan izin ditolak) dan daftar path dari Glob.

**Kalau ada yang ditolak** (balasan menyebut permission/denied/izin):
- Read superpowers ditolak → di `reference/k-prompt-dispatch.md` paragraf `<sdd>`, tambahkan kalimat: `**Unattended:** hapus baris "Ikuti template" dari prompt (probe <tanggal>: Read plugin-cache dari subagent ditolak di headless).`
- Read `reference.md` plugin ditolak → di SKILL step 1 Degrade tambahkan butir (c): `mode unattended → rakit brief SENDIRI (cara lama), brief-writer tak bisa membaca §B di headless (probe <tanggal>)`.
- Glob ditolak → paragraf `<sdd>`: `**Unattended:** jangan resolve <sdd>; hapus baris "Ikuti template".`
- Lalu tambah assertion yang cocok di `build-lean.test.sh`, jalankan semua test, regen Kimi, dan commit `fix(build): fallback headless hasil probe — …`.

- [ ] **Step 5: Catat langkah ukur "sesudah" (dikerjakan user nanti)**

Di laporan akhir, tulis instruksi buat user:
1. Jalankan `/upgrade` di mahjong (susulin `build_status.py` + allowlist).
2. Jalankan ≥ 3 sesi `/context-vault:build` nyata.
3. Jalankan `python3 tools/measure-build-context.py ~/.claude/projects/-Users-mac-098506-Developer-project-mahjong`, lalu isi kolom **Sesudah** di spec §9.

Kriteria lulus spec §4.10:
- median context di dispatch pertama ≤ 95K;
- pertumbuhan per dispatch ≤ 10K;
- review/task, NEEDS_CONTEXT/task, dan blocked/task nggak lebih buruk dari baseline lebih dari ~20%.
