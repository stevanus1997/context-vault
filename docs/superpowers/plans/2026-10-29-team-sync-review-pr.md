# Kerja tim: `sync` + `review-pr` — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dua skill baru di plugin context-vault:
- `sync`: menyusulkan `control/` ke kode yang sudah merge di branch utama tiap repo, lalu menampilkan ringkasan bisnis HTML.
- `review-pr`: mereview PR rekan lintas-repo per tiket dalam empat lapis, lalu menampilkan laporan HTML.

Pendukungnya: hook deteksi basi, penjaga basi di skill yang membaca knowledge, dan penanda fitur aktif.

**Architecture:** Kerja deterministik dikerjakan script Python stdlib di folder skill, dan semuanya bisa dites:
- `sync_status.py`: patokan, selisih commit, penanda fitur
- `prs.py`: membungkus `gh`
- dua `assemble.py`: JSON → HTML

Claude menulis penilaian (klasifikasi commit, temuan review, isi JSON laporan). Hook `SessionStart` level plugin dan penjaga di skill memanggil script yang sama (`sync_status.py status`). Penanda `feature:<f>` di knowledge ditulis `intake`/`fanout`, dilepas `ship`/`drop`, dan dihormati `sync`/`review-pr`.

**Tech Stack:** Skill Markdown (Claude Code plugin) · Python 3 stdlib (parser YAML dipinjam dari `plugin/template/.claude/build_status.py`) · bash + jq (hook) · `git` · `gh` CLI · HTML/CSS/JS vanilla · test bash pola counter PASS/FAIL (`tools/tests/*.test.sh`, `plugin/hooks/tests/*.test.sh`).

**Spec:** `docs/superpowers/specs/2026-10-29-team-sync-review-pr-design.md` (keputusan D1–D25). Mockup yang disetujui ada di `docs/superpowers/specs/2026-10-29-sync-review-pr-mockup.html`. Baca keduanya sebelum mulai: plan ini berargumen dari spec.

## Global Constraints

- Nama skill `sync` (`plugin/skills/sync/`) dan `review-pr` (`plugin/skills/review-pr/`). Agent baru `plugin/agents/sync-reader.md`.
- Patokan: `control/sync.yaml`, satu-satunya penulisnya `sync_status.py`. User hanya boleh mengedit tangan `bot_authors` dan `contracts_repos`.
- Output HTML: `.claude/sync/<YYYY-MM-DD-HHMM>.html` dan `.claude/review/<repo-key>-<nomor>.html`, keduanya di-gitignore.
- Penanda fitur persis: Markdown `<!-- feature:<f> -->`, YAML `# feature:<f>` (komentar di ujung baris). Jejak sinkron: Markdown `<!-- sync <sha7> <YYYY-MM-DD> -->`, YAML `# sync <sha7> <YYYY-MM-DD>`.
- Bot default: nama author cocok regex `(-bot|\[bot\])$`.
- Kode tiket: regex `\b[A-Z][A-Z0-9]+-\d+\b`. Nomor PR di subjek commit: `\(#(\d+)\)\s*$` atau `^Merge pull request #(\d+)`.
- Vonis review persis: `Perlu ubah` (≥1 temuan `harus`) · `Approve dengan saran` (0 `harus`, ≥1 `saran`) · `Siap approve`. Temuan `info` tidak memengaruhi vonis.
- Lapis review (kunci → label): `konsistensi` → "Konsistensi", `best_practice` → "Best practice", `alur` → "Alur lintas-repo", `kontrak` → "Kontrak". Tingkat: `harus` → "Harus dibenerin", `saran` → "Saran", `info` → "Info".
- Label skip sinkron persis: **"mungkin karena catatan basi"**.
- Visual laporan mengikuti mockup: token `--bg #E9EDF1`, `--surface #FFFFFF`, `--ink #17222D`, `--soft #5B6876`, `--line #D3DAE1`, `--blue #2D5BD3`, `--red #C2362F`, `--amber #A8701A`, `--green #2F7D5B`. Font Schibsted Grotesk (teks), JetBrains Mono (kode saja, `font-variant-ligatures:none`). Merah/amber/hijau hanya untuk status.
- **Nol string `CLAUDE_PLUGIN_ROOT`** di `.py`/`.html`/`.sh` milik skill. Script menemukan saudaranya lewat `__file__`. Hook (`plugin/hooks/`) boleh memakai `${CLAUDE_PLUGIN_ROOT}` karena tidak ikut ke `plugin-kimi/`.
- Test memanggil script sebagai proses `python3 -B …`, dan script yang meng-import `build_status.py` wajib mengeset `sys.dont_write_bytecode = True` sebelum import. Jangan sampai ada `__pycache__` di `plugin/`.
- Dokumen dan pesan berbahasa Indonesia (santai di SKILL/reference, seperti skill lain). Draft komentar review berbentuk pertanyaan/usulan. Commit tanpa trailer `Co-Authored-By`.
- `review-pr` tidak pernah menulis ke `control/` maupun ke working tree repo. Membaca PR lewat `gh pr diff` dan `git fetch origin pull/<n>/head:refs/cv-review/<n>` (ref dihapus setelah selesai).
- Hook dan penjaga tidak pernah memblokir. Kalau gagal, diam (hook) atau lanjut tanpa tawaran (penjaga).

## Review Focus

1. **Repo tanpa remote / tanpa `origin/HEAD` / bukan git, di samping repo yang sehat.** Entri bermasalah dapat `error`, repo lain tetap dihitung, dan hook tidak crash. Pin: Task 1 test S5.
2. **Master di-force-push sehingga `synced_sha` bukan leluhur `base_ref` lagi.** `status` melaporkan `error: "patokan hilang dari riwayat"` + `behind: null`, `advance` menolak, dan skill menawarkan baseline ulang untuk repo itu. Pin: Task 1 test S6.
3. **Sesi dibuka di subfolder repo (`lora/lora-task-service`) atau di folder bukan produk.** Hook diam. Pin: Task 3 test H3.
4. **Subjek commit / judul PR / baris kode berisi `<script>`, `</textarea>`, `&`.** Teks ter-escape dan halaman tetap utuh. Pin: Task 5 test R3 dan Task 9 test V3.
5. **`gh` login di akun pribadi (repo kantor 404).** `prs.py` exit 5 dengan pesan `gh auth switch`, bukan daftar kosong yang menyesatkan. Pin: Task 8 test P4.

---

## File Structure

| Path | Tanggung jawab |
|---|---|
| `plugin/skills/sync/sync_status.py` | CLI: `init`, `status`, `range`, `advance`, `markers`, `unmark`. Membaca `workspace.yaml`, menulis `sync.yaml`. |
| `plugin/skills/sync/assemble.py` + `template.html` | Ringkasan sinkron JSON → HTML. |
| `plugin/skills/sync/SKILL.md` + `reference.md` | Alur sinkron, aturan tulis ke knowledge, skema JSON ringkasan. |
| `plugin/agents/sync-reader.md` | Subagent analisis satu repo: klasifikasi + usulan tulis. |
| `plugin/hooks/sync-check.sh` + `hooks.json` | Hook `SessionStart`: deteksi basi. |
| `plugin/rules/stale-guard.md` | Prosedur penjaga basi (dirujuk 5 skill). |
| `plugin/rules/feature-marker.md` | Konvensi penanda fitur (dirujuk intake/fanout/ship/drop/sync/review-pr). |
| `plugin/skills/review-pr/prs.py` | CLI: `inbox`, `view`, `siblings` (bungkus `gh`). |
| `plugin/skills/review-pr/assemble.py` + `template.html` | Laporan review JSON → HTML (vonis/lapis diturunkan). |
| `plugin/skills/review-pr/SKILL.md` + `reference.md` | Alur review, empat lapis, skema JSON laporan. |
| `plugin/skills/{intake,fanout,ship,drop,feature,plan,fix,tweak,ask,init,upgrade,guide}/…` | Sisipan rujukan/aturan. |
| `plugin/hooks/auto-title.sh` | Whitelist `sync`, `review-pr`. |
| `tools/tests/sync.test.sh`, `tools/tests/review-pr.test.sh`, `plugin/hooks/tests/sync-check.test.sh` | Test. |
| `README.md`, `README.id.md`, `plugin/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `plugin-kimi/` | Rilis 0.29.0. |

---

### Task 1: `sync_status.py`: patokan, `init`, `status`, `advance`

**Files:**
- Create: `plugin/skills/sync/sync_status.py`
- Create: `tools/tests/lib/sync-fixture.sh` (fungsi `mkprod`, dipakai `sync.test.sh` dan test hook Task 3)
- Create: `tools/tests/sync.test.sh` (bagian S)

**Interfaces:**
- Produces (CLI, semua output JSON ke stdout, exit 0 kecuali disebut):
  - `status --root DIR [--repos k1,k2] [--format json|hook]`
    - `json` → `{"initialized": bool, "reason": str|null, "repos": [Repo], "stale": [key]}`.
    - `Repo` = `{"key": str, "path": str, "apps": [str], "base_ref": str|null, "synced_sha": str|null, "head_sha": str|null, "behind": int|null, "behind_all": int|null, "synced_at": str|null, "error": str|null}`. `behind` = commit non-bot, `behind_all` = semua. `stale` = key dengan `behind > 0`. `--repos` mencocokkan key **atau** nama app.
    - `hook` → stdout kosong bila tak ada yang basi. Bila ada: `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"<teks>"}}`, dengan teks persis `[context-vault] control/ ketinggalan <total> commit (di luar bot) sejak <synced_at paling lama>: <key> (<n>), <key> (<n>). Jangan sinkron sendiri — skill feature/plan/fix/tweak/review-pr akan menawarkan /sync dulu.`
    - Root tanpa `control/workspace.yaml` → `{"initialized": false, "reason": "bukan produk context-vault", "repos": [], "stale": []}`. Tanpa `control/sync.yaml` → `initialized: false`, `reason: "belum pernah sinkron"`.
  - `init --root DIR [--since YYYY-MM-DD] [--contracts a,b] [--base KEY=REF ...] [--force] [--only KEY]`
    - Menulis `control/sync.yaml` lalu mencetak bentuk `status --format json`.
    - `sync.yaml` sudah ada tanpa `--force` → exit 1.
    - Ada repo yang base-nya tak terdeteksi dan tanpa `--base` → exit 3, stdout `{"need_base": [key]}`, dan file tidak ditulis.
    - `--only KEY` (wajib bersama `--force`) = baseline ulang SATU repo (patokan = `base_ref` sekarang, atau `--since`). Entri lain, `bot_authors`, dan `contracts_repos` dipertahankan.
  - `advance --root DIR --repo KEY --sha SHA` → set `synced_sha`, `synced_at` = hari ini. `SHA` bukan keturunan `synced_sha` atau bukan leluhur `base_ref` → exit 1.
- Consumes: `parse_yaml(text) -> dict|list|str|None` dari `plugin/template/.claude/build_status.py` (di-load lewat `importlib` dari `Path(__file__).resolve().parents[2] / 'template/.claude/build_status.py'`).

Aturan yang harus diikuti:
- **Repo** = toplevel git (`git -C <root>/<path> rev-parse --show-toplevel`) tiap `apps[]` dan `packages[]` di `workspace.yaml`, dikelompokkan per toplevel. `key` = path toplevel relatif ke root (`.` untuk monorepo di root). `apps` = nama-nama unit di repo itu. Path yang bukan git → entri dengan `error: "bukan repo git"`.
- **base_ref** = `git symbolic-ref --short refs/remotes/origin/HEAD` (mis. `origin/master`), atau `--base KEY=REF`.
- **synced_sha awal** = `rev-parse <base_ref>`. Dengan `--since D` = `git rev-list -1 --before="D 00:00" <base_ref>`; kosong → commit paling awal (`git rev-list --max-parents=0 <base_ref> | tail -1`).
- **bot_authors awal** = nama author unik dari `git log -500 --format=%an <base_ref>` semua repo yang cocok regex bot.
- **Format `sync.yaml`** persis (urutan kunci tetap, repo urut key):
  ```yaml
  # control/sync.yaml — patokan sinkron control/ ↔ branch utama tiap repo.
  # Ditulis skill sync (sync_status.py). Boleh edit tangan: bot_authors, contracts_repos.
  bot_authors: [bfibravo-bot, "github-actions[bot]"]
  contracts_repos: [lora-schema-service]
  repos:
    lora-gateway-service:
      apps: [lora-gateway-service]
      base_ref: origin/master
      synced_sha: <40 heksa>
      synced_at: "2026-10-29"
  ```
  Skalar yang memuat `[`, `]`, `:`, `#`, atau spasi diberi kutip ganda.
- `status` **tidak** melakukan `fetch`. `behind_all` = `git rev-list --count --first-parent synced..base`. `behind` = jumlah baris `git log --first-parent --format=%an synced..base` yang bukan anggota `bot_authors` (first-parent = satu entri per PR yang merge/squash ke branch utama). Bila `git merge-base --is-ancestor synced base` gagal → `error: "patokan hilang dari riwayat"`, `behind`/`behind_all` null, dan tidak masuk `stale`.
- Setiap pemanggilan git memakai `subprocess.run(..., capture_output=True, timeout=5)`. Error per repo masuk `error` dan tidak pernah dilempar keluar.

- [ ] **Step 1: Tulis fixture-builder dan test bagian S** di `tools/tests/sync.test.sh`. Ikuti pola `share.test.sh` (`ok`/`bad`, `T=$(mktemp -d)`, `PY="python3 -B"`).
  - Helper `mkprod <dir>` (di `tools/tests/lib/sync-fixture.sh`, di-`source`) membuat produk: `control/workspace.yaml` dengan `apps` `api` (path `api`) dan `web` (path `web`) plus `packages: []`. Masing-masing repo git dibuat dari bare `origin` lokal: `git init --bare`, clone, commit, push, lalu `git remote set-head origin -a`.
  - Commit dibuat dengan `git -c user.name=<n> -c user.email=<n>@x commit`. Author `alice` (manusia) dan `ci-bot` (bot).

  | Test | Skenario | Assertions |
  |---|---|---|
  | S1 | `status` tanpa `sync.yaml` | `initialized` false, `reason` "belum pernah sinkron". `--format hook` stdout kosong. |
  | S2 | `init --contracts api` | Exit 0. `sync.yaml` memuat `contracts_repos: [api]`, `base_ref: origin/main`, `bot_authors` memuat `ci-bot`, dan `parse_yaml` membaca ulang tanpa error. `status` menghasilkan `stale` kosong. |
  | S3 | Push 2 commit `alice` + 3 commit `ci-bot` ke origin `api`, lalu `git -C api fetch` | `status` → `api.behind == 2`, `api.behind_all == 5`, `stale == ["api"]`. `--format hook` → JSON yang `additionalContext`-nya diawali `[context-vault] control/ ketinggalan 2 commit` dan memuat `api (2)`. |
  | S4 | `advance --repo api --sha <head>` | Sesudahnya `status` → `stale` kosong dan `synced_at` = hari ini. |
  | S5 | Tambah app `doc` (path `doc`) yang bukan repo git, dan app `local` repo tanpa remote | `status` exit 0. `doc.error == "bukan repo git"`, `local.error` tidak null, `api`/`web` tetap terhitung. `init` di produk ini (setelah hapus `sync.yaml`) exit 3 dengan `need_base` memuat `local`. Dengan `--base local=main` → exit 0. |
  | S6 | Force-push origin `api` ke riwayat baru (reset ke commit awal + commit lain), fetch | `status` → `api.error == "patokan hilang dari riwayat"` dan `api.behind` null. `advance --repo api --sha <head baru>` exit 1. `init --force --only api` exit 0 → `api` tak error lagi, `synced_sha` entri `web` tidak berubah, `contracts_repos` tetap. |
  | S7 | `status` dengan `--root` folder tanpa `control/` | `reason` "bukan produk context-vault". `--format hook` stdout kosong, exit 0. |
  | S8 | `init --since <besok>` di produk baru | `synced_sha` = HEAD. `--since 2000-01-01` → `synced_sha` = commit akar. |

- [ ] **Step 2: Jalankan, pastikan gagal.** Run `bash tools/tests/sync.test.sh`. Expected: FAIL karena `sync_status.py` belum ada.
- [ ] **Step 3: Implementasikan `plugin/skills/sync/sync_status.py`** (argparse subcommand: `cmd_init(args) -> int`, `cmd_status(args) -> int`, `cmd_advance(args) -> int`; helper `load_workspace(root) -> list[Repo]`, `read_sync(root) -> dict|None`, `write_sync(root, data) -> None`) sesuai aturan di atas.
- [ ] **Step 4: Jalankan, pastikan lulus.** Run `bash tools/tests/sync.test.sh`. Expected: semua `ok`, `fail=0`. Pastikan `find plugin -name __pycache__` kosong.
- [ ] **Step 5: Commit** — `git add plugin/skills/sync/sync_status.py tools/tests/sync.test.sh && git commit -m "feat(sync): sync_status.py — patokan per repo (init/status/advance) + test"`

---

### Task 2: `sync_status.py`: `range`, `markers`, `unmark`

**Files:**
- Modify: `plugin/skills/sync/sync_status.py`
- Modify: `tools/tests/sync.test.sh` (bagian M)

**Interfaces:**
- Consumes: helper Task 1.
- Produces:
  - `range --root DIR --repo KEY [--fetch]` → `{"repo": KEY, "from": sha, "to": sha, "fetch_error": str|null, "commits": [{"sha", "short", "author", "date": "YYYY-MM-DD", "subject", "pr": int|null, "bot": bool, "own": bool}]}`, dari `git log --first-parent --reverse synced..base` (satu entri per squash/merge PR, urut lama → baru; `to` = `rev-parse base` setelah fetch). `--fetch` = `git fetch --quiet origin` dulu; gagal → `fetch_error`, lanjut dari ref lokal.
  - **`own`** = PR `<key>#<pr>` tercantum di `control/features/*/feature.yaml` `prs:` (flow list `"<key>#<n>"`) atau di `control/fixes/*/fix.yaml` `fix_pr` (string/list berisi `"<key>#<n>"` atau URL `…/<nama-repo>/pull/<n>`; nama repo dicocokkan ke basename key).
  - `markers --root DIR [--feature F] [--status s1,s2]` → `[{"file": "control/…", "line": int, "feature": str, "status": str|null, "text": str}]`. Memindai `control/**/*.md` dan `control/**/*.yaml` kecuali `control/features/**` dan `control/fixes/**`. `status` diambil dari `control/features/<f>/feature.yaml`.
  - `unmark --root DIR --feature F` → menghapus token penanda F (beserta satu spasi di depannya) dari file yang sama. Cetak `{"removed": int}`.

- [ ] **Step 1: Tulis test bagian M.**

  | Test | Skenario | Assertions |
  |---|---|---|
  | M1 | Commit `alice` "feat: x (#12)", `ci-bot` "chore: bump", lalu fetch | `range --repo api` → 2 commit urut. Yang pertama `pr == 12`, `bot == false`. Yang kedua `bot == true`, `pr == null`. |
  | M2 | Tulis `control/features/f1/feature.yaml` dengan `status: shipped` + `prs: ["api#12"]` | M1 diulang → commit #12 `own == true`. |
  | M3 | `range --fetch` dengan remote dibuat rusak (`git remote set-url origin /nope`) | Exit 0, `fetch_error` tidak null, `commits` tetap terisi dari ref lokal. |
  | M4 | `control/business/flows.md` berisi `- Reschedule maks 3x <!-- feature:f2 -->`. `workspace.yaml` punya baris capability `      - survey-reschedule # feature:f2`. `features/f2/feature.yaml` `status: active`. | `markers --status active,draft` → 2 entri `feature == "f2"`, `status == "active"`. `markers --feature f1` → `[]`. |
  | M5 | `unmark --feature f2` | `removed == 2`. File tetap memuat teks aturan tanpa token. `parse_yaml(workspace.yaml)` tetap valid dan capability masih ada. |

- [ ] **Step 2: Jalankan, pastikan gagal.** Run `bash tools/tests/sync.test.sh`. Expected: M1–M5 FAIL.
- [ ] **Step 3: Implementasikan `cmd_range`, `cmd_markers`, `cmd_unmark`.** Regex penanda: `<!-- feature:([a-z0-9][a-z0-9-]*) -->` dan `#\s*feature:([a-z0-9][a-z0-9-]*)\s*$`.
- [ ] **Step 4: Jalankan, pastikan lulus.** Expected `fail=0`.
- [ ] **Step 5: Commit** — `feat(sync): range commit (bot/PR/own) + markers/unmark penanda fitur`

---

### Task 3: Hook `SessionStart` + whitelist auto-title

**Files:**
- Create: `plugin/hooks/sync-check.sh`
- Create: `plugin/hooks/tests/sync-check.test.sh`
- Modify: `plugin/hooks/hooks.json` (tambah `SessionStart`)
- Modify: `plugin/hooks/auto-title.sh` (whitelist)
- Modify: `plugin/hooks/tests/auto-title.test.sh`

**Interfaces:**
- Consumes: `sync_status.py status --root DIR --format hook` (Task 1).
- Produces: entri `hooks.json`:
  ```json
  "SessionStart": [{"hooks": [{"type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}\"/hooks/sync-check.sh", "timeout": 5}]}]
  ```

`sync-check.sh`:
- Baca stdin JSON. `cwd` = `.cwd` via `jq`; tanpa jq atau field kosong → `$PWD`.
- `[ -f "$cwd/control/workspace.yaml" ] && [ -f "$cwd/control/sync.yaml" ]` atau exit 0.
- `exec python3 -B "$(dirname "$0")/../skills/sync/sync_status.py" status --root "$cwd" --format hook`, tapi output dibuang bila exit ≠ 0. **Selalu exit 0.** Gaya header komentar ikuti `auto-title.sh`.

- [ ] **Step 1: Tulis test.** Fixture: `source tools/tests/lib/sync-fixture.sh` (`mkprod`, Task 1).
  - H1: produk basi → stdout JSON valid, `.hookSpecificOutput.hookEventName == "SessionStart"`.
  - H2: produk tidak basi → stdout kosong, exit 0.
  - H3: `cwd` = subfolder `api/` produk, dan `cwd` = folder kosong → stdout kosong, exit 0.
  - H4: stdin bukan JSON → exit 0 tanpa stdout. Bila `$PWD` bukan produk, tetap diam.
  - H5: `jq empty plugin/hooks/hooks.json` lolos, dan `.hooks.SessionStart[0].hooks[0].timeout == 5`.
  - Di `auto-title.test.sh` tambahkan: `/context-vault:sync` → judul `sync`, dan `/context-vault:review-pr bfi/lbofe#1482` → `review-pr: bfi/lbofe#1482`.
- [ ] **Step 2: Jalankan, pastikan gagal.** Run `bash plugin/hooks/tests/sync-check.test.sh && bash plugin/hooks/tests/auto-title.test.sh`. Expected: FAIL.
- [ ] **Step 3: Implementasikan.** Buat `sync-check.sh` (chmod +x), sisipkan entri `SessionStart` di `hooks.json` di samping `UserPromptSubmit`, dan tambahkan `|sync|review-pr` ke `case` whitelist `auto-title.sh`.
- [ ] **Step 4: Jalankan semua test hook + `bash tools/tests/sync.test.sh`.** Expected `fail=0`.
- [ ] **Step 5: Commit** — `feat(hooks): SessionStart sync-check — deteksi control/ basi tanpa LLM; auto-title sync/review-pr`

---

### Task 4: Penanda fitur (D25) + `ship` mencatat PR (D12)

**Files:**
- Create: `plugin/rules/feature-marker.md`
- Modify: `plugin/skills/intake/SKILL.md` (langkah 7, paragraf "Lalu **promosikan fakta DURABLE**")
- Modify: `plugin/skills/fanout/SKILL.md` (langkah 4, paragraf "Lalu **update `capabilities`**")
- Modify: `plugin/skills/ship/SKILL.md` (langkah 6, bullet "Set manifest work-item")
- Modify: `plugin/skills/drop/SKILL.md` (langkah 3)
- Modify: `plugin/skills/fix/reference.md` (komentar `fix_pr`)
- Test: `tools/tests/sync.test.sh` (bagian statis T)

**Interfaces:**
- Consumes: `markers`/`unmark` (Task 2).
- Produces: konvensi yang dirujuk Task 6, 7, dan 10.

Isi persis `plugin/rules/feature-marker.md`:

```markdown
# Penanda fitur di knowledge bersama

Knowledge bersama (`control/business/*`, `invariants.md`, `conventions.md`, `integrations.md`, `workspace.yaml` capabilities) kadang ditulis **sebelum** kodenya merge (intake/fanout). Supaya `sync` tidak menimpanya dengan perilaku master yang lama, dan `review-pr` tidak memakainya untuk menuduh PR rekan, tiap entri yang ditulis atas nama fitur yang belum ship diberi penanda.

- Markdown: tambahkan ` <!-- feature:<fitur> -->` di ujung baris/bullet entri (entri multi-baris: di ujung baris pertamanya).
- YAML: tambahkan ` # feature:<fitur>` di ujung baris nilai yang ditambahkan.
- Update entri yang sudah ada atas nama fitur → penanda ikut ditambahkan ke baris itu.
- Penulis penanda: `intake` (promosi ke `business/*`) dan `fanout` (`capabilities`/`consumers`).
- Pelepas penanda: `ship` (setelah PR dibuat, karena kode = realita) → `python3 -B ${CLAUDE_PLUGIN_ROOT}/skills/sync/sync_status.py unmark --root . --feature <fitur>`. `drop` → lihat langkah 3 drop.
- Pembaca: `sync` (jangan timpa entri ber-penanda fitur `draft`/`active` → tampilkan "bentrok sama fitur lo") dan `review-pr` (entri ber-penanda fitur yang belum ship **bukan** dasar tuduhan → kartu Info).
- Daftar penanda: `python3 -B ${CLAUDE_PLUGIN_ROOT}/skills/sync/sync_status.py markers --root . [--feature <f>] [--status active,draft]`.
```

Sisipan per skill (tambahkan kalimat, jangan ubah yang lain):
- **intake**, di akhir paragraf "Lalu **promosikan fakta DURABLE** …": ` Tiap entri yang ditambah/diubah diberi penanda fitur (` + "`<!-- feature:<fitur> -->`" + `) — lihat ${CLAUDE_PLUGIN_ROOT}/rules/feature-marker.md.`
- **fanout**, di akhir paragraf "Lalu **update `capabilities`** …": ` Tiap baris capability/consumer yang ditambah diberi komentar ` + "`# feature:<fitur>`" + ` (${CLAUDE_PLUGIN_ROOT}/rules/feature-marker.md).`
- **ship**, ganti bullet "Set manifest work-item → …" jadi: `- Set manifest work-item → \`status: shipped\` + \`shipped_at: <YYYY-MM-DD>\` + \`prs: ["<repo-key>#<nomor>", …]\` (repo-key = path toplevel relatif root, \`.\` untuk monorepo; dipakai \`sync\` agar commit hasil ship sendiri tidak dicatat dobel). Untuk fix: \`fix.yaml\`, isi \`fix_pr\` dengan format yang sama. Fitur: lepas penanda fitur → \`python3 -B ${CLAUDE_PLUGIN_ROOT}/skills/sync/sync_status.py unmark --root . --feature <fitur>\` (${CLAUDE_PLUGIN_ROOT}/rules/feature-marker.md).`
- **drop** langkah 3, sisipkan di awal paragraf: `Daftar kandidat diambil dari penanda: \`python3 -B ${CLAUDE_PLUGIN_ROOT}/skills/sync/sync_status.py markers --root . --feature <fitur>\` (plus pemindaian manual untuk entri lama tanpa penanda). ` Lalu di akhir paragraf: ` Item keep → lepas penandanya (\`unmark\`); item revert → hapus barisnya.`
- **fix/reference.md**: komentar `fix_pr` → `# diisi saat shipped (oleh ship) — "<repo-key>#<nomor>" atau list-nya`.

- [ ] **Step 1: Tulis test statis T** di `sync.test.sh`:
  - T1: `rules/feature-marker.md` ada dan memuat `<!-- feature:<fitur> -->` dan `# feature:<fitur>`.
  - T2: intake, fanout, ship, dan drop masing-masing memuat `rules/feature-marker.md` atau `sync_status.py`.
  - T3: ship memuat `prs: ["<repo-key>#<nomor>"`.
- [ ] **Step 2: Jalankan, pastikan T1–T3 gagal.**
- [ ] **Step 3: Tulis rule dan sisipan.**
- [ ] **Step 4: Jalankan, pastikan lulus.**
- [ ] **Step 5: Commit** — `feat(knowledge): penanda feature:<f> di intake/fanout, dilepas ship/drop; ship catat prs`

---

### Task 5: Ringkasan sinkron — `template.html` + `assemble.py`

**Files:**
- Create: `plugin/skills/sync/template.html`
- Create: `plugin/skills/sync/assemble.py`
- Create: `tools/tests/fixtures/sync/summary-ok.json`
- Modify: `tools/tests/sync.test.sh` (bagian R)

**Interfaces:**
- Produces: `assemble.py --data FILE.json --out FILE.html`. Exit 0 → cetak path. Exit 1 → JSON tidak valid / kunci wajib hilang (pesan ke stderr, output tidak ditulis). Exit 2 → argumen salah.
- Skema input (kunci wajib: `since`, `generated`, `repos`). Lainnya opsional dengan default `[]`/`0`:
  ```json
  {"product": "BFI LORA", "since": "2026-10-21", "generated": "2026-10-29 09:12",
   "repos": [{"key": "lora-gateway-service", "label": "LGS", "human": 14, "bot": 11, "people": 3}],
   "features": [{"app": "LGS", "text": "…"}],
   "business_rules": [{"app": "LTS", "text": "…", "before": "2×", "after": "3×"}, {"app": "LSS", "text": "…", "pill": "+ reason_code wajib"}],
   "coding_rules": [{"app": "LBOFE", "text": "…", "pill": "createDatasource()"}],
   "conflicts": [{"feature": "df4w-credit-task-detail", "file": "business/flows.md", "master": "…", "yours": "…"}],
   "pointers": [{"text": "Repo belum terdaftar: lora-tools", "skill": "/add-app"}],
   "written": [{"file": "invariants.md", "change": "1 diubah"}],
   "other_commits": 37, "stale_note": null}
  ```
  Perubahan kontrak masuk `business_rules`.

Aturan render (selain itu ikuti mockup tab "Ringkasan sinkron"):
- **Judul.** `N = len(features) + len(business_rules) + len(coding_rules)`. Judul `"<N> hal baru sejak <D>"`, dengan `<D>` = tanggal Indonesia `21 Oktober`, plus tahun bila beda dari tahun `generated`. `N == 0` → `"Nggak ada hal baru sejak <D>"`.
- **Subjudul.** `"<total commit> commit masuk di <jumlah repo> repo. Semua udah dicatat ke control/. Di bawah ini cuma yang perlu lo tau."`
- **Kartu repo.** Bar = `human` (biru) dan `bot` (abu), proporsional terhadap repo terbesar. Repo dengan `human == 0` diredupkan dengan teks "cuma bot".
- **Kolom.** Kolom tanpa item **tidak dirender**. `before`/`after` → visual coret→baru. `pill` → chip kode.
- **Bentrok.** `conflicts` → kartu merah "Bentrok sama fitur lo" di atas kolom (fitur, file, "master: …" vs "fitur lo: …").
- **Bawah.** `pointers` → baris pointer. Baris "Ditulis ke control/" + `"<other_commits> commit lain cuma bot, refactor, atau fix kecil"`.
- **Escape.** Semua teks di-escape `html.escape`. Tidak ada placeholder `__X__` yang tersisa.
- **Desain.** Saat membuat `template.html`, **invoke skill `frontend-design:frontend-design`** dengan brief "ringkasan sinkron, ikut mockup + token Global Constraints". Hasilnya harus responsif ≤760px, focus ring terlihat, dan menghormati `prefers-reduced-motion`. Dark mode opsional.

- [ ] **Step 1: Tulis fixture + test R:**
  - R1: fixture lolos. Output memuat `5 hal baru sejak 21 Oktober`, `2×`, `3×`, `createDatasource()`, dan tanpa `__`.
  - R2: fixture dengan `coding_rules: []` → string `Aturan coding baru` tidak ada. Dengan semua list kosong → `Nggak ada hal baru sejak`.
  - R3: `text` berisi `<script>alert(1)</script> & </textarea>` → output memuat `&lt;script&gt;` dan tidak memuat `<script>alert`.
  - R4: tanpa `since` → exit 1, file output tidak dibuat.
  - R5: `conflicts` terisi → output memuat `Bentrok sama fitur lo` dan nama fiturnya.
- [ ] **Step 2: Jalankan, pastikan gagal.**
- [ ] **Step 3: Implementasikan template (via frontend-design) + `assemble.py`.** Fungsi `render(data: dict) -> str` dan `main(argv) -> int`, template dibaca dari `Path(__file__).with_name('template.html')`, slot `<!-- CONTENT -->` dan `__TITLE__`.
- [ ] **Step 4: Jalankan, pastikan lulus. Buka output fixture di browser** (playwright screenshot atau `open`) dan cocokkan secara visual dengan mockup.
- [ ] **Step 5: Commit** — `feat(sync): ringkasan sinkron HTML (template + assemble)`

---

### Task 6: Skill `sync` + agent `sync-reader`

**Files:**
- Create: `plugin/skills/sync/SKILL.md`
- Create: `plugin/skills/sync/reference.md`
- Create: `plugin/agents/sync-reader.md`
- Modify: `tools/tests/sync.test.sh` (bagian K, statis)

**Interfaces:**
- Consumes: `sync_status.py` (Task 1–2), `assemble.py` (Task 5), `rules/feature-marker.md` (Task 4).
- Produces: skill `sync`, yang dipanggil oleh penjaga (Task 7) dan oleh user.

Frontmatter persis:
```yaml
---
name: sync
description: Use untuk NYUSULIN control/ ke kode yang sudah merge di branch utama tiap repo (kerja tim — rekan/squad lain commit tanpa update control/). Hitung selisih sejak patokan control/sync.yaml, analisis per repo (subagent sync-reader), catat LENGKAP ke file knowledge pemiliknya tanpa gate per item, lalu buka ringkasan bisnis HTML (fitur baru · aturan bisnis berubah · aturan coding baru). Tidak menimpa catatan bertanda fitur aktif. Dipanggil penjaga basi skill lain atau manual. Trigger — "sync", "sinkron control", "nyusulin knowledge", "abis pull". Jalankan dari root produk yang punya control/.
---
```

`SKILL.md` wajib memuat langkah berikut (gaya ringkas, seperti `share`/`ask`; detail ke `reference.md`):
- **Baris `AskUserQuestion`** seperti skill lain (salin blok kutipan "Titik tunggu attended" dari `ask`/`share`).
- **Baseline (D5).** `sync.yaml` absen → tanya dua opsi: "anggap control/ sekarang sudah sinkron" / "sinkron sejak tanggal …". Usulkan `contracts_repos` dari `responsibility` di `workspace.yaml` dan minta konfirmasi (boleh kosong). Jalankan `init`. `need_base` → tanya base per repo, lalu `--base`. Sebut fitur `active` yang ada: "catatan dari fitur ini yang ditulis sebelum penanda ada nggak bisa dikenali — cek manual" (spec §7). Opsi pertama → selesai tanpa ringkasan.
- **Hitung.** `status` lalu `range --fetch` per repo basi. Repo `error: "patokan hilang dari riwayat"` → tawarkan baseline ulang khusus repo itu (`init --force --only <key>`) atau skip.
- **Analisis.** Dispatch `context-vault:sync-reader` **paralel, satu per repo basi**. Kirim: root, key, path file JSON `range` (tulis dulu ke `.claude/sync/work/<key>-range.json`), daftar file knowledge, output `markers --status active,draft`, dan `contracts_repos`. Commit `bot`/`own` tidak dikirim untuk dibaca, cukup dihitung. Range > 60 commit non-bot → pecah per 60 commit, lebih dari satu dispatch per repo.
- **Tulis.** Controller menerapkan usulan tulis (bentuk di `reference.md`) ke file pemilik, dengan jejak `<!-- sync <sha7> <tgl> -->` / `# sync …`.
  - Usulan yang mengenai baris ber-penanda fitur `draft`/`active` **tidak diterapkan**: tulis versi master **di baris baru di sampingnya** dengan jejak sync, lalu masukkan ke `conflicts`.
  - Larangan D8: jangan menambah entri app/package/vendor (jadikan `pointers`) dan jangan menyentuh `control/features/**` / `control/fixes/**`.
- **Majukan.** `advance` per repo setelah semua tulisan repo itu sukses (D11).
- **Laporan.** Rakit JSON ringkasan, `assemble.py`, lalu buka (`open <file>` di macOS, `xdg-open` di Linux, gagal → cetak path). Terakhir, satu kalimat ringkas di chat + path.
- **Dipanggil penjaga.** Setelah selesai, kembali ke skill pemanggil (jangan berhenti).
- **Guardrails.**
  - Hanya mencatat perilaku yang terbukti di diff (anti-ngarang, `rules/anti-yes-man.md`).
  - SHAPE-only untuk secret/PII.
  - Unattended/headless → jangan pernah sinkron otomatis.

`reference.md` memuat:
- Skema usulan tulis dari sync-reader: `{"kind": "feature|business_rule|coding_rule|contract|other", "app": str, "summary": str, "writes": [{"file": "control/…", "op": "add|update", "anchor": str|null, "old": str|null, "new": str, "sha": str}], "summary_item": {…bentuk item ringkasan Task 5…}}`.
- Peta file → jenis perubahan:
  - aturan domain/status → `business/domain.md` · `flows.md`
  - istilah → `glossary.md`
  - batasan lintas-app → `invariants.md`
  - pola coding → `conventions.md`
  - kapabilitas → `workspace.yaml` capabilities
  - migrasi → `schema/<app>.md`
  - vendor existing → `integrations.md`
  - token/komponen → `design-system.md`
- Skema JSON ringkasan (salin dari Task 5).
- Aturan label repo (`label` = singkatan di komentar `workspace.yaml` bila ada, mis. `# LGS`, selain itu nama app).

`plugin/agents/sync-reader.md` (frontmatter `tools: Read, Bash`, `model: inherit`; gaya `brief-writer.md`):
- **Input.** Root, key, file range, daftar knowledge, penanda aktif.
- **Kerja.**
  - Per PR/commit, baca `git -C <path> show --stat` lalu diff yang relevan (lewati lockfile/generated/vendor).
  - Bandingkan dengan knowledge yang ada.
  - Klasifikasikan.
  - Usulkan tulis **hanya** bila diff membuktikan perubahan perilaku/aturan/pola.
- **Larangan.** Tidak menulis file apa pun, tidak `git fetch`/`checkout`.
- **Balikan.** JSON list sesuai skema `reference.md`, dikirim **sekali** via `SendMessage` ke `main`, lalu teks akhir persis `.` (pelajaran 0.28.1).

- [ ] **Step 1: Tulis test statis K:**
  - K1: frontmatter `name: sync`.
  - K2: SKILL.md memuat `sync_status.py`, `context-vault:sync-reader`, `assemble.py`, `advance`, dan `feature-marker.md`.
  - K3: `agents/sync-reader.md` ada dengan `tools: Read, Bash` dan memuat `SendMessage`.
  - K4: tidak ada `CLAUDE_PLUGIN_ROOT` di `plugin/skills/sync/*.py` / `*.html`.
- [ ] **Step 2: Jalankan, pastikan K gagal.**
- [ ] **Step 3: Tulis `SKILL.md`, `reference.md`, `sync-reader.md`.**
- [ ] **Step 4: Jalankan, pastikan lulus.**
- [ ] **Step 5: Commit** — `feat(sync): skill sync + agent sync-reader`

---

### Task 7: Penjaga basi (D6) di `feature`/`plan`/`fix`/`tweak` + route `ask`

**Files:**
- Create: `plugin/rules/stale-guard.md`
- Modify: `plugin/skills/feature/SKILL.md` (awal "### 2. Jalankan tahap berurutan")
- Modify: `plugin/skills/plan/SKILL.md` (awal "### 1. Baca input")
- Modify: `plugin/skills/fix/SKILL.md` (awal "### 1. Deteksi mode + triage")
- Modify: `plugin/skills/tweak/SKILL.md` (akhir "### 1. Baca state minimal")
- Modify: `plugin/skills/ask/SKILL.md` (tabel §5)
- Modify: `tools/tests/sync.test.sh` (bagian G, statis)

Isi persis `plugin/rules/stale-guard.md`:

```markdown
# Penjaga basi — tawarkan /sync sebelum memutuskan pakai knowledge

Dipakai skill yang membaca `control/` untuk MEMUTUSKAN sesuatu (feature, plan, fix, tweak, review-pr). Tujuannya: jangan menuduh "melanggar aturan" berdasarkan catatan yang sudah dilangkahi kode rekan.

1. Jalankan `python3 -B ${CLAUDE_PLUGIN_ROOT}/skills/sync/sync_status.py status --root . --format json --repos <repo relevan>` (tanpa `--repos` = semua). Script absen / exit ≠ 0 / `initialized: false` → lanjut tanpa tawaran (boleh satu kalimat: "belum pernah sinkron — `/sync` kapan-kapan").
2. `stale` kosong → lanjut.
3. `stale` terisi → tampilkan "control/ ketinggalan <n> commit di <repo> (<n>)…" lalu `AskUserQuestion`: **Sinkron sekarang** (jalankan skill `sync`, lalu LANJUTKAN skill ini dari langkah yang sama) / **Skip** (lanjut pakai catatan apa adanya).
4. Skip → ingat daftar repo basi. Setiap temuan/tuduhan "melanggar aturan/invariant/konvensi" yang bersandar pada knowledge yang menyangkut repo basi itu diberi label **"mungkin karena catatan basi"** dan disebut repo-nya.
5. Unattended/headless → jangan pernah bertanya dan jangan sinkron: perlakukan sebagai Skip (label tetap berlaku).
6. Entri knowledge ber-penanda fitur lain yang belum ship (`${CLAUDE_PLUGIN_ROOT}/rules/feature-marker.md`) = aturan yang belum berlaku di master. Jangan jadikan dasar tuduhan terhadap kode master/PR rekan.
```

Sisipan (satu baris tiap skill):
- **feature:** `**Penjaga basi:** sebelum tahap pertama, jalankan ${CLAUDE_PLUGIN_ROOT}/rules/stale-guard.md (repo relevan = semua).`
- **plan:** `**Penjaga basi:** ${CLAUDE_PLUGIN_ROOT}/rules/stale-guard.md dengan repo relevan = app di fanout.md (dilewati bila dipanggil feature dan penjaga sudah jalan di sesi ini).`
- **fix:** `**Penjaga basi:** ${CLAUDE_PLUGIN_ROOT}/rules/stale-guard.md (repo relevan = semua; dipersempit ke repo bug bila sudah jelas).`
- **tweak:** `**Penjaga basi:** ${CLAUDE_PLUGIN_ROOT}/rules/stale-guard.md (repo relevan = app yang diubah).`
- **ask**, tabel §5: tambah baris `| Drift karena kode rekan yang sudah merge (repo basi menurut \`sync_status.py status\`) | \`/sync\` |`.

- [ ] **Step 1: Tulis test statis G:**
  - G1: rule ada dan memuat `mungkin karena catatan basi` dan `--format json`.
  - G2: feature, plan, fix, dan tweak masing-masing memuat `rules/stale-guard.md`.
  - G3: ask memuat `` `/sync` ``.
- [ ] **Step 2: Jalankan, pastikan gagal.**
- [ ] **Step 3: Tulis rule dan sisipan.**
- [ ] **Step 4: Jalankan, pastikan lulus.**
- [ ] **Step 5: Commit** — `feat(guard): penjaga basi (stale-guard) di feature/plan/fix/tweak + route ask → /sync`

---

### Task 8: `prs.py`: inbox, view, siblings

**Files:**
- Create: `plugin/skills/review-pr/prs.py`
- Create: `tools/tests/review-pr.test.sh` (bagian P) + stub `gh` dibuat di temp dir oleh test

**Interfaces:**
- Produces (stdout JSON):
  - `inbox --root DIR` → `[{"repo_key", "owner_repo", "number": int, "title", "author", "created": "YYYY-MM-DD", "url", "ticket": str|null, "reviewed_local": bool}]`, urut `created` lama → baru.
    - gh: `gh search prs --review-requested=@me --state=open --limit 100 --json number,title,author,createdAt,url,repository`. Filter: `repository.nameWithOwner` cocok dengan `repo_url` app/package di `workspace.yaml` (`github.com[/:]<owner>/<name>(\.git)?`).
    - `repo_key` = key `sync.yaml`-style (path toplevel relatif). `reviewed_local` = `.claude/review/<repo_key>-<number>.html` ada.
  - `view --root DIR --pr OWNER/REPO#N` → `{"repo_key", "owner_repo", "number", "title", "author", "url", "head_ref", "head_sha", "base_ref", "ticket"}`. gh: `gh pr view N --repo OWNER/REPO --json number,title,author,url,headRefName,headRefOid,baseRefName`. `ticket` dari `head_ref` dulu, baru judul.
  - `siblings --root DIR --ticket T --exclude OWNER/REPO#N` → list bentuk `view`. Untuk tiap repo produk: `gh pr list --repo O/R --state open --search T --json number,title,author,url,headRefName,headRefOid,baseRefName`. Ambil yang `T` muncul di `headRefName` atau `title`.
- Error:
  - `gh` tidak ada → exit 4, `{"error": "gh-missing"}`.
  - gh exit ≠ 0 dengan stderr memuat `Could not resolve`, `404`, `403`, atau `HTTP 401` → exit 5, `{"error": "gh-auth", "detail": <stderr baris pertama>, "hint": "Akun gh aktif mungkin bukan akun kerja — coba \`gh auth switch\`."}`.
  - Error gh lain → exit 1.

- [ ] **Step 1: Tulis test P.** Stub `gh` (bash) di `$T/bin`, dengan `PATH="$T/bin:$PATH"`. Stub membaca argumen, mengembalikan JSON kalengan dari `$T/gh/<subcmd>.json`, dan memakai `GH_FAIL=…` untuk mensimulasikan error. Workspace fixture punya dua app dengan `repo_url` `https://github.com/acme/api.git` dan `https://github.com/acme/web.git`.
  - P1: inbox → hanya PR repo `acme/api` dan `acme/web`, sedangkan PR `other/x` terbuang. `ticket` dari judul `"BLCS-5302 jadwal ulang"` = `BLCS-5302`.
  - P2: view → `ticket` dari `head_ref` `feat/BLCS-5302/x`.
  - P3: siblings → PR yang judul atau branch-nya memuat tiket ikut, PR `--exclude` tidak.
  - P4: `GH_FAIL="HTTP 404: Not Found"` → exit 5, JSON `error == "gh-auth"`, `hint` memuat `gh auth switch`.
  - P5: `PATH` tanpa `gh` → exit 4.
- [ ] **Step 2: Jalankan, pastikan gagal.**
- [ ] **Step 3: Implementasikan** (`cmd_inbox`, `cmd_view`, `cmd_siblings`; `load_repos(root)` memakai parser yang sama seperti `sync_status.py`, di-import dari `../sync/sync_status.py` lewat `importlib`).
- [ ] **Step 4: Jalankan, pastikan lulus.**
- [ ] **Step 5: Commit** — `feat(review-pr): prs.py — inbox/view/siblings via gh`

---

### Task 9: Laporan review — `template.html` + `assemble.py`

**Files:**
- Create: `plugin/skills/review-pr/template.html`
- Create: `plugin/skills/review-pr/assemble.py`
- Create: `tools/tests/fixtures/review-pr/report-ok.json`
- Modify: `tools/tests/review-pr.test.sh` (bagian V)

**Interfaces:**
- Produces: `assemble.py --data FILE.json --out FILE.html`, dengan exit code seperti Task 5. Fungsi `verdict(findings) -> str` (D22) diekspos untuk dites lewat CLI `--verdict-only` (cetak vonis).
- Skema input (wajib: `title`, `prs`, `findings`):
  ```json
  {"title": "Jadwal ulang survey dari backoffice", "author": "jocelyntjahyadi26", "opened": "2 hari lalu", "ticket": "BLCS-5302",
   "prs": [{"label": "LBOFE", "number": 1482, "url": "…"}],
   "stale_repos": [],
   "map": {"nodes": [{"id": "LBOFE", "sub": "#1482", "touched": true, "problem": true}, {"id": "LGS", "touched": false}],
           "edges": [{"from": "LBOFE", "to": "LTS", "label": "surveyDate", "problem": true}]},
   "lane_ok": {"konsistensi": "Struktur folder, nama datasource, dan pola form ikut yang udah ada di LBOFE."},
   "findings": [
     {"lane": "kontrak", "level": "harus", "title": "…", "location": "LBOFE src/…:88", "comment": "…", "stale": false,
      "evidence": {"type": "contract", "left": "LBOFE ngirim", "right": "LSS minta", "rows": [{"l": "surveyDate", "r": "survey_schedule_at wajib", "bad": true}]}},
     {"lane": "alur", "level": "harus", "…": "…",
      "evidence": {"type": "states", "states": [{"name": "NEW", "ok": true}, {"name": "SUBMITTED", "flag": true}], "ok_label": "boleh jadwal ulang", "flag_label": "PR ini ikut izinin"}},
     {"lane": "best_practice", "level": "saran", "…": "…",
      "evidence": {"type": "code", "lines": [{"n": 41, "text": "  .catch(() => null)", "hl": true}]}}
   ]}
  ```

Aturan render (selain itu ikuti mockup tab "Laporan review PR" dan bentuk "A"):
- **Vonis** diturunkan dengan `verdict()`. Subjudulnya:
  - `"<h> hal harus dibenerin sebelum approve, <s> saran opsional."`
  - `"<s> saran opsional, aman di-approve."`
  - `"Nggak ada temuan."`
- **Empat kotak lapis** urut `kontrak`, `alur`, `best_practice`, `konsistensi`.
  - Angkanya = jumlah temuan `harus` + `saran` lapis itu. Warnanya: merah bila ada `harus`, amber bila hanya `saran`, hijau ✓ bila nol.
  - Subteks dari judul temuan pertama (dipotong 28 karakter), atau "aman" bila nol.
- **Peta**: SVG yang di-layout otomatis.
  - Node `touched` sejajar di satu baris (maks 5, zigzag y ±30). Node lain kecil di baris bawah.
  - Edge: garis lurus. `problem` → merah putus-putus dengan lingkaran "!" di tengah dan label mono di bawahnya.
  - Node `problem` → bingkai merah.
  - Peta dilewati bila `map` absen atau hanya ada 1 node.
- **Kartu temuan** urut `harus` → `saran` → `info`.
  - Tombol "Copy komentar" menyalin `comment` (berubah "Tersalin" 1,5 detik).
  - Evidence `contract` → tabel, `states` → rantai SVG, `code` → blok kode bernomor. Tanpa evidence → kartu satu kolom.
- **Label basi.** `stale: true` → chip "mungkin karena catatan basi". `stale_repos` tidak kosong → banner tipis di bawah kepala: "Catatan control/ ketinggalan di <repo> — temuan bertanda mungkin keliru".
- **Lapis aman.** Lapis tanpa temuan dan ada `lane_ok[lapis]` → satu baris ✓ di bawah.
- **Escape & desain.** Escape semua teks. Saat membuat `template.html`, **invoke `frontend-design:frontend-design`** dengan brief "laporan review PR bentuk A, ikut mockup + token Global Constraints". Kualitas minimumnya sama seperti Task 5.

- [ ] **Step 1: Tulis fixture + test V:**
  - V1: fixture → output memuat `Perlu ubah`, `Copy komentar`, `survey_schedule_at`, `<svg`, dan tanpa `__`.
  - V2: `--verdict-only` dengan findings `[saran]` → `Approve dengan saran`. `[info]` → `Siap approve`. `[]` → `Siap approve`.
  - V3: `title`/`comment`/baris kode memuat `<script>x</script>` → ter-escape.
  - V4: temuan `stale: true` → output memuat `mungkin karena catatan basi`.
  - V5: tanpa `findings` → exit 1.
  - V6: `map` absen → tidak ada `<svg` peta (selector `class="map"` tidak ada).
- [ ] **Step 2: Jalankan, pastikan gagal.**
- [ ] **Step 3: Implementasikan.**
- [ ] **Step 4: Jalankan, pastikan lulus, lalu cek visual vs mockup.**
- [ ] **Step 5: Commit** — `feat(review-pr): laporan review HTML (vonis/lapis/peta/temuan)`

---

### Task 10: Skill `review-pr`

**Files:**
- Create: `plugin/skills/review-pr/SKILL.md`
- Create: `plugin/skills/review-pr/reference.md`
- Modify: `tools/tests/review-pr.test.sh` (bagian W, statis)

**Interfaces:**
- Consumes: `prs.py` (Task 8), `assemble.py` (Task 9), `rules/stale-guard.md` (Task 7), `rules/feature-marker.md` (Task 4), `sync_status.py markers` (Task 2), agent `security-critic` (sudah ada).

Frontmatter persis:
```yaml
---
name: review-pr
description: Use untuk mereview PR REKAN (bukan fitur sendiri — itu ship) lintas-repo — tanpa argumen tampilkan PR yang minta review lo di semua repo produk lalu pilih; dengan argumen langsung ke PR itu. PR satu tiket di repo lain digabung jadi satu review. Empat lapis — konsistensi, best practice, alur lintas-repo, kontrak — dicek ke control/ + kontrak di branch utama & PR saudara. Hasil satu laporan HTML (vonis, skor per lapis, temuan + draft komentar tinggal copy). Read-only, tidak pernah posting ke GitHub. Trigger — "review-pr", "review PR <x>", "PR mana yang harus gw review". Jalankan dari root produk yang punya control/.
---
```

`SKILL.md` wajib memuat:
- **Blok kutipan "Titik tunggu attended".**
- **Penjaga basi** (`rules/stale-guard.md`, repo relevan = repo PR yang dipilih + saudaranya. Jalankan setelah langkah pilih PR).
- **Pilih.** Tanpa argumen → `prs.py inbox`, tampilkan tabel ringkas, lalu `AskUserQuestion` (maks 4 opsi; >4 → tampilkan tabel dan minta ketik nomor). Argumen URL/`owner/repo#n`/`repo-key#n` → `view`. Exit 4/5 → sampaikan `hint`, lalu STOP.
- **Gabung.** `ticket` ada → `siblings`. Tampilkan daftar PR gabungan dalam satu kalimat, lalu lanjut tanpa bertanya.
- **Kumpulkan.** Per PR: `gh pr diff N --repo O/R`, dan untuk membaca berkas utuh: `git -C <path> fetch --quiet origin pull/N/head:refs/cv-review/N`, lalu `git show refs/cv-review/N:<file>`. **Dilarang** checkout/switch/stash. Hapus ref di akhir (`git update-ref -d`). Kontrak: berkas repo `contracts_repos` (dari `control/sync.yaml`; absen → anggap tidak ada repo kontrak dan sarankan `/sync`) di `origin/<base>` **ditambah** versi di PR saudara bila ada.
- **Empat lapis** (detail cek per lapis di `reference.md`):
  - (1) `conventions.md` + kode sekitar.
  - (2) best practice. `security-critic` dipanggil bila diff menyentuh data pribadi/uang/auth/role/tenant/secret/vendor di `integrations.md` (D18).
  - (3) alur: `business/flows.md`, `invariants.md`, consumer/producer lain di `workspace.yaml`.
  - (4) kontrak: kejelasan (bila PR di repo kontrak) dan kepatuhan consumer.
- **Penanda fitur.** Entri ber-penanda fitur `draft`/`active` (`markers`) tidak dipakai menuduh. Bentrok dengannya → temuan `level: info` "bakal bentrok sama fitur lo".
- **Tingkat temuan.** `harus` = salah perilaku / langgar aturan / kontrak putus. `saran` = mutu. Selera bukan temuan (`rules/anti-yes-man.md`).
- **Draft komentar** (D24): Indonesia santai-sopan, berbentuk pertanyaan/usulan, 1–2 kalimat, menyebut file/field konkret.
- **Laporan.** Tulis JSON ke `.claude/review/work/<repo_key>-<n>.json`, `assemble.py` → `.claude/review/<repo_key>-<n>.html`, lalu buka (seperti sync). Di chat: vonis + jumlah temuan + path, maksimal 3 baris.
- **Guardrails.**
  - Read-only terhadap `control/` dan working tree.
  - Tidak pernah `gh pr review`/`gh pr comment`.
  - Tidak pernah `gh auth switch` sendiri.
  - SHAPE-only untuk secret/PII.

`reference.md` memuat:
- Checklist per lapis.
- Contoh temuan yang baik dan buruk per lapis (pakai contoh mockup).
- Skema JSON laporan (salin dari Task 9).
- Cara memilih `evidence.type`.
- Cara membangun `map` (node = app yang disentuh tiket + tetangga langsung di `workspace.yaml`, edge = arah panggilan yang diketahui dari `responsibility`/kontrak).

- [ ] **Step 1: Tulis test statis W:**
  - W1: frontmatter `name: review-pr`.
  - W2: SKILL.md memuat `prs.py`, `stale-guard.md`, `feature-marker.md`, `refs/cv-review`, `assemble.py`.
  - W3: SKILL.md **tidak** memuat `gh pr review --approve` atau `gh pr comment` kecuali di kalimat larangan. Test: setiap baris yang memuat `gh pr comment` juga memuat `tidak pernah`.
  - W4: tidak ada `CLAUDE_PLUGIN_ROOT` di `plugin/skills/review-pr/*.py` / `*.html`.
- [ ] **Step 2: Jalankan, pastikan gagal.**
- [ ] **Step 3: Tulis `SKILL.md` + `reference.md`.**
- [ ] **Step 4: Jalankan, pastikan lulus.**
- [ ] **Step 5: Commit** — `feat(review-pr): skill review-pr — PR rekan lintas-repo per tiket, empat lapis, laporan HTML`

---

### Task 11: Integrasi & rilis 0.29.0

**Files:**
- Modify: `plugin/skills/init/SKILL.md` (daftar baris `.gitignore`), `plugin/skills/upgrade/SKILL.md` (cek + append `.gitignore`)
- Modify: `plugin/skills/guide/reference.md` (peta flow lane samping + tabel "mau apa → skill" + entri `/sync`, `/review-pr`)
- Modify: `README.md`, `README.id.md` (tabel skill, bagian "Understand & share"/padanannya)
- Modify: `plugin/.claude-plugin/plugin.json` (`version` `0.29.0`, `description` tambah frasa `sync (nyusulin control/ dari kode rekan yang sudah merge: patokan per repo, hook deteksi basi, penjaga di skill, ringkasan bisnis HTML) + review-pr (review PR rekan lintas-repo per tiket, empat lapis, laporan HTML)`)
- Modify: `.claude-plugin/marketplace.json` (`metadata.version` + entri plugin `version` → `0.29.0`, description entri tambah `+ sync & review-pr (kerja tim)`)
- Regenerate: `plugin-kimi/`

Isi perubahan:
- **init/upgrade**: tambahkan `.claude/sync/` dan `.claude/review/` ke daftar baris `.gitignore` yang sudah ada (pola `grep -qxF` yang sama), lengkap dengan alasannya: "hasil generate laporan sync/review-pr + file kerja, bukan knowledge". `control/sync.yaml` **tidak** di-gitignore.
- **guide**: `sync` dan `review-pr` masuk "Lane samping bisa kapan saja", plus baris tabel `| Abis pull, susulin catatan dari kerjaan rekan | /sync |` dan `| Review PR rekan | /review-pr |`.

- [ ] **Step 1: Terapkan perubahan teks di atas.**
- [ ] **Step 2: Regen Kimi.** Run `bash tools/build-kimi.sh && bash tools/tests/build-kimi.test.sh`. Expected: lulus. `plugin-kimi/skills/sync/` dan `plugin-kimi/skills/review-pr/` ada, dan `plugin-kimi/hooks` tidak ada.
- [ ] **Step 3: Jalankan seluruh suite.** Run `for t in tools/tests/*.test.sh plugin/hooks/tests/*.test.sh; do bash "$t" || echo "GAGAL: $t"; done`. Expected: tidak ada baris `GAGAL:`. (`panel.test.tsx` dijalankan dengan cara yang sama seperti sebelumnya bila ada runner-nya; tidak disentuh plan ini.)
- [ ] **Step 4: Uji asap manual di LORA (read-only sampai user setuju).**
  - Jalankan `python3 -B plugin/skills/sync/sync_status.py status --root ~/Developer/BFI/lora --format json`. Expected: `initialized: false`, `reason: "belum pernah sinkron"`.
  - Jalankan `prs.py inbox --root ~/Developer/BFI/lora`. Expected: daftar PR atau exit 5 dengan hint akun.
  - **Jangan** menjalankan `init` di LORA tanpa izin user.
- [ ] **Step 5: Commit** — `feat: sync + review-pr (kerja tim) — gitignore init/upgrade, guide, README, 0.29.0; regen plugin-kimi`
