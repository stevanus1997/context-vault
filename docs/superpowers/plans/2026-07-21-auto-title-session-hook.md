# Auto-Title Session via Hook Plugin — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Session Claude Code otomatis ke-judul dari skill context-vault yang dipanggil (`/build checkout-v2` → `build: checkout-v2`), di-ship sebagai hook level plugin.

**Architecture:** Satu hook `UserPromptSubmit` yang didaftarkan lewat `plugin/hooks/hooks.json` (aktif otomatis di semua project yang enable plugin, TANPA menyentuh template produk). Script `auto-title.sh` parse prompt (tag expansion `<command-name>`/`<command-args>`, fallback slash mentah), cocokkan whitelist skill kerja, emit `hookSpecificOutput.sessionTitle`. Lock-file per-session menghormati `/rename` manual (best-effort, D5 spec).

**Tech Stack:** bash + jq (sama dengan hook template existing). Tanpa dependensi baru.

**Spec:** `docs/superpowers/specs/2026-07-21-auto-title-session-hook-design.md`

## Global Constraints

- Script **selalu `exit 0`** — kegagalan apa pun tidak boleh mengganggu prompt user (spec D7).
- Output JSON dibangun **pakai `jq`**, tidak pernah string-concat manual (spec D7).
- Truncate argumen judul di **48 karakter** + `…` (spec D3).
- Lock dir: `~/.claude/context-vault/session-locks/`, prune file >30 hari (spec D5).
- Whitelist PERSIS (spec D3) — ber/tanpa argumen sama-sama pakai aturan seragam `skill` + (`: args` bila ada): `feature intake fanout plan breakdown build fix tweak ship drop add-app add-package add-integration init architect wire design-system extract upgrade discovery`. Di luar itu (termasuk `ask guide render-docs debt`) → diam.
- Gaya bash ikut hook template existing: `#!/usr/bin/env bash`, `set -uo pipefail`, komentar bahasa Indonesia ringkas (contoh: `plugin/template/.claude/hooks/on-stop.sh`).
- **`plugin/template/` TIDAK disentuh sama sekali.**
- Versi plugin dicatat di DUA file: `plugin/.claude-plugin/plugin.json` dan `.claude-plugin/marketplace.json` (2 occurrence). Bump keduanya di Task 4.

---

### Task 1: Parser inti `auto-title.sh` + test harness

**Files:**
- Create: `plugin/hooks/auto-title.sh`
- Test: `plugin/hooks/tests/auto-title.test.sh`

**Interfaces:**
- Consumes: stdin JSON `UserPromptSubmit` — field `prompt` (string), `session_id` (string).
- Produces: stdout `{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","sessionTitle":"<judul>"}}` (compact, satu baris) ATAU kosong (skip). Exit code selalu 0. Task 2 menambah blok lock di script yang sama; Task 3 mendaftarkan script ini di `hooks.json`.

- [ ] **Step 1: Tulis test harness + test parser (failing)**

Tulis `plugin/hooks/tests/auto-title.test.sh`:

```bash
#!/usr/bin/env bash
# Test unit auto-title.sh — feed stdin JSON, assert stdout persis.
# Jalanin: bash plugin/hooks/tests/auto-title.test.sh  (exit 0 = semua lulus)
set -uo pipefail
HOOK="$(cd "$(dirname "$0")/.." && pwd)/auto-title.sh"
PASS=0; FAIL=0

run() { # run <nama> <json-stdin> <expected-stdout>
  local name="$1" input="$2" expected="$3" actual
  actual="$(printf '%s' "$input" | bash "$HOOK" 2>/dev/null)" || true
  if [ "$actual" = "$expected" ]; then PASS=$((PASS+1)); echo "ok   - $name"
  else FAIL=$((FAIL+1)); echo "FAIL - $name"; echo "    expected: $expected"; echo "    actual:   $actual"; fi
}

title() { jq -cn --arg t "$1" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",sessionTitle:$t}}'; }
pj() { jq -cn --arg p "$1" --arg s "${2:-sess-default}" '{session_id:$s, hook_event_name:"UserPromptSubmit", prompt:$p}'; }

export HOME="$(mktemp -d)"   # isolasi lock dir (~/.claude/context-vault/session-locks)

EXP_BUILD='<command-message>build is running…</command-message>
<command-name>/context-vault:build</command-name>
<command-args>checkout-v2</command-args>'

run "expansion: skill + args" \
  "$(pj "$EXP_BUILD")" \
  "$(title 'build: checkout-v2')"

run "expansion: nama tanpa slash/prefix" \
  "$(pj '<command-name>build</command-name>
<command-args>checkout-v2</command-args>')" \
  "$(title 'build: checkout-v2')"

run "expansion: skill tanpa args (tag absen)" \
  "$(pj '<command-name>/context-vault:wire</command-name>')" \
  "$(title 'wire')"

run "expansion: args tag kosong" \
  "$(pj '<command-name>/context-vault:wire</command-name>
<command-args></command-args>')" \
  "$(title 'wire')"

A60="$(printf 'a%.0s' $(seq 1 60))"
A48="$(printf 'a%.0s' $(seq 1 48))"
run "truncate args >48 char" \
  "$(pj "<command-name>/context-vault:tweak</command-name>
<command-args>${A60}</command-args>")" \
  "$(title "tweak: ${A48}…")"

run "args ber-kutip tetap JSON valid" \
  "$(pj '<command-name>/context-vault:tweak</command-name>
<command-args>naikin fee "admin" 5rb</command-args>')" \
  "$(title 'tweak: naikin fee "admin" 5rb')"

run "read-only skill (ask) → diam" \
  "$(pj '<command-name>/context-vault:ask</command-name>
<command-args>status produk</command-args>')" \
  ""

run "prompt biasa → diam" \
  "$(pj 'gimana status produk sekarang?')" \
  ""

run "fallback slash mentah" \
  "$(pj '/build checkout-v2')" \
  "$(title 'build: checkout-v2')"

run "fallback slash mentah non-whitelist → diam" \
  "$(pj '/help')" \
  ""

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `bash plugin/hooks/tests/auto-title.test.sh`
Expected: `pass=3 fail=7`, exit code 1. (Script belum ada → `actual` selalu kosong, jadi 3 kasus yang memang expect kosong — `ask`, `prompt biasa`, `/help` — lulus duluan; 7 kasus ber-judul FAIL.)

- [ ] **Step 3: Implement `plugin/hooks/auto-title.sh`**

```bash
#!/usr/bin/env bash
# Hook `UserPromptSubmit` (level PLUGIN, bukan template produk) — auto-judul session
# dari skill context-vault yang dipanggil: /build checkout-v2 → "build: checkout-v2".
# Last-skill-wins; skill read-only (ask/guide/render-docs/debt) tidak menyentuh judul.
# SELALU exit 0 — gagal parse = diam, jangan pernah ganggu prompt user.
# Spec: docs/superpowers/specs/2026-07-21-auto-title-session-hook-design.md
set -uo pipefail

INPUT="$(cat)" || exit 0
command -v jq >/dev/null 2>&1 || exit 0
PROMPT="$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)" || exit 0
[ -n "$PROMPT" ] || exit 0

# Lapis 1: tag expansion <command-name>/<command-args>; Lapis 2: fallback slash mentah (spec D6)
SKILL=""; ARGS=""
if printf '%s' "$PROMPT" | grep -q '<command-name>'; then
  SKILL="$(printf '%s' "$PROMPT" | sed -n 's/.*<command-name>\([^<]*\)<\/command-name>.*/\1/p' | head -n1)"
  ARGS="$(printf '%s' "$PROMPT" | sed -n 's/.*<command-args>\([^<]*\)<\/command-args>.*/\1/p' | head -n1)"
else
  case "$PROMPT" in
    /*) FIRST_LINE="${PROMPT%%$'\n'*}"
        SKILL="${FIRST_LINE%% *}"
        [ "$SKILL" = "$FIRST_LINE" ] && ARGS="" || ARGS="${FIRST_LINE#* }" ;;
    *)  exit 0 ;;
  esac
fi

# normalisasi: buang leading '/' + prefix plugin 'context-vault:'
SKILL="${SKILL#/}"; SKILL="${SKILL#context-vault:}"

# whitelist skill kerja (spec D3) — di luar ini (termasuk ask/guide/render-docs/debt) → diam
case "$SKILL" in
  feature|intake|fanout|plan|breakdown|build|fix|tweak|ship|drop|add-app|add-package|add-integration|init|architect|wire|design-system|extract|upgrade|discovery) ;;
  *) exit 0 ;;
esac

# judul = skill (+ ": args" bila ada); args dirapikan + truncate 48 char (spec D3)
ARGS="$(printf '%s' "$ARGS" | tr '\n' ' ' | sed 's/^ *//; s/ *$//')"
TITLE="$SKILL"
if [ -n "$ARGS" ]; then
  [ "${#ARGS}" -gt 48 ] && ARGS="${ARGS:0:48}…"
  TITLE="$SKILL: $ARGS"
fi

jq -cn --arg t "$TITLE" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",sessionTitle:$t}}'
exit 0
```

Lalu: `chmod +x plugin/hooks/auto-title.sh`

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `bash plugin/hooks/tests/auto-title.test.sh`
Expected: 10× `ok   - ...`, `pass=10 fail=0`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add plugin/hooks/auto-title.sh plugin/hooks/tests/auto-title.test.sh
git commit -m "feat(hooks): auto-title session — parser skill → sessionTitle (UserPromptSubmit)"
```

---

### Task 2: Lock `/rename` manual (spec D5 tingkat 1)

**Files:**
- Modify: `plugin/hooks/auto-title.sh` (sisip blok lock setelah validasi `PROMPT`)
- Test: `plugin/hooks/tests/auto-title.test.sh` (tambah 3 kasus)

**Interfaces:**
- Consumes: `session_id` dari stdin JSON (Task 1 sudah membacanya dari input yang sama).
- Produces: lock-file kosong `~/.claude/context-vault/session-locks/<session_id>`. Kalau lock ada → script diam untuk session itu. Catatan spec D5: kalau `/rename` built-in ternyata TIDAK lewat hook (dicek Task 3), blok ini no-op alami — TIDAK dibongkar.

- [ ] **Step 1: Tambah 3 test lock (failing)**

Sisipkan di `plugin/hooks/tests/auto-title.test.sh`, SEBELUM baris `echo "---"; ...`:

```bash
# --- lock /rename (spec D5) ---
run "/rename → diam + tulis lock" \
  "$(pj '/rename eksperimen-gw' 'sess-lock')" \
  ""
if [ -f "$HOME/.claude/context-vault/session-locks/sess-lock" ]; then
  PASS=$((PASS+1)); echo "ok   - lock file kebentuk"
else
  FAIL=$((FAIL+1)); echo "FAIL - lock file kebentuk (tidak ada)"
fi

run "session ke-lock → skill kerja diam" \
  "$(pj '/build checkout-v2' 'sess-lock')" \
  ""

run "session lain tetap ke-judul" \
  "$(pj '/build checkout-v2' 'sess-bebas')" \
  "$(title 'build: checkout-v2')"
```

- [ ] **Step 2: Jalankan test, pastikan 4 kasus baru gagal**

Run: `bash plugin/hooks/tests/auto-title.test.sh`
Expected: `pass=12 fail=2`, exit code 1. Yang FAIL persis dua: `lock file kebentuk` (belum ada blok lock) dan `session ke-lock → skill kerja diam` (script masih nge-judul). Dua kasus baru lainnya lulus duluan: `/rename → diam` (rename bukan whitelist, memang diam) dan `session lain tetap ke-judul`.

- [ ] **Step 3: Sisip blok lock di `auto-title.sh`**

Sisipkan SETELAH baris `[ -n "$PROMPT" ] || exit 0` dan SEBELUM komentar `# Lapis 1: ...`:

```bash
SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)" || SESSION_ID="unknown"
LOCK_DIR="$HOME/.claude/context-vault/session-locks"
LOCK_FILE="$LOCK_DIR/$SESSION_ID"

# /rename manual → kunci session ini, auto-judul berhenti (spec D5 tingkat 1).
# Kalau /rename built-in tak pernah lewat hook, blok ini no-op alami (degradasi tingkat 2).
case "$PROMPT" in
  "/rename "*|"/rename")
    mkdir -p "$LOCK_DIR" 2>/dev/null && : > "$LOCK_FILE" 2>/dev/null
    find "$LOCK_DIR" -type f -mtime +30 -delete 2>/dev/null   # prune opportunistik
    exit 0 ;;
esac
[ -f "$LOCK_FILE" ] && exit 0
```

- [ ] **Step 4: Jalankan test, pastikan lulus semua**

Run: `bash plugin/hooks/tests/auto-title.test.sh`
Expected: `pass=14 fail=0`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add plugin/hooks/auto-title.sh plugin/hooks/tests/auto-title.test.sh
git commit -m "feat(hooks): auto-title — lock per-session hormati /rename manual (best-effort)"
```

---

### Task 3: Registrasi `hooks.json` + probe empiris format prompt

**Files:**
- Create: `plugin/hooks/hooks.json`
- Modify (kondisional, hasil probe): `plugin/hooks/auto-title.sh` + test (pola sed lapis-1)
- Scratch (tidak di-commit): `<scratchpad>/probe-log.sh`, `<scratchpad>/probe-settings.json`, `<scratchpad>/probe.log`

**Interfaces:**
- Consumes: `auto-title.sh` dari Task 1–2.
- Produces: hook terdaftar di level plugin; kepastian empiris (a) bentuk prompt expansion nyata, (b) apakah `/rename` lewat hook — menentukan wording README di Task 4 (tingkat 1 vs tingkat 2).

- [ ] **Step 1: Tulis `plugin/hooks/hooks.json`**

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}\"/hooks/auto-title.sh"
          }
        ]
      }
    ]
  }
}
```

Validasi: `jq . plugin/hooks/hooks.json` → Expected: JSON ke-print tanpa error.

- [ ] **Step 2: Probe — logging hook sekali jalan**

Tulis `<scratchpad>/probe-log.sh` (ganti `<scratchpad>` dengan path scratchpad session, absolut):

```bash
#!/usr/bin/env bash
cat >> "<scratchpad>/probe.log"; echo "" >> "<scratchpad>/probe.log"
exit 0
```

`chmod +x <scratchpad>/probe-log.sh`, lalu `<scratchpad>/probe-settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command", "command": "<scratchpad>/probe-log.sh" } ] }
    ]
  }
}
```

Jalankan DARI ROOT REPO INI (skill context-vault aktif di sini):

```bash
claude -p --settings <scratchpad>/probe-settings.json --max-turns 1 "/context-vault:build coba-probe"
claude -p --settings <scratchpad>/probe-settings.json --max-turns 1 "/rename coba-nama"
jq -r '.prompt' <scratchpad>/probe.log
```

(Kalau flag `--settings` tidak dikenali versi CLI: fallback — tambahkan entri hook yang sama sementara ke `.claude/settings.json` repo ini, ulangi dua perintah `claude -p`, lalu kembalikan file persis seperti semula sebelum lanjut; cek `git diff .claude/settings.json` bersih.)

- [ ] **Step 3: Interpretasi probe + penyesuaian (kondisional)**

- **Prompt skill:** kalau bentuknya tag `<command-name>`/`<command-args>` dan parser Task 1 sudah cocok → tidak ada perubahan. Kalau formatnya BEDA (tag lain / raw): sesuaikan pola `sed` lapis-1 di `auto-title.sh` DAN update fixture `EXP_BUILD` + kasus expansion di test supaya niru bentuk NYATA; jalankan ulang test sampai `fail=0`.
- **`/rename`:** kalau kejadian `/rename coba-nama` MUNCUL di `probe.log` → tingkat 1 terverifikasi (catat untuk README Task 4). Kalau TIDAK muncul → tingkat 2 berlaku (catat untuk README Task 4). Dua-duanya: blok lock TETAP dipertahankan.
- Catat kesimpulan probe (2–3 baris) di pesan commit step berikut.

- [ ] **Step 4: Jalankan seluruh test, commit**

Run: `bash plugin/hooks/tests/auto-title.test.sh` → Expected: `fail=0`.

```bash
git add plugin/hooks/hooks.json plugin/hooks/auto-title.sh plugin/hooks/tests/auto-title.test.sh
git commit -m "feat(hooks): registrasi auto-title di hooks.json level plugin (+hasil probe empiris)"
```

---

### Task 4: Docs + bump versi 0.19.0 + smoke manual

**Files:**
- Modify: `plugin/.claude-plugin/plugin.json` (version + description)
- Modify: `.claude-plugin/marketplace.json` (2× version)
- Modify: `README.md` (section baru)

**Interfaces:**
- Consumes: kesimpulan probe Task 3 (pilih wording caveat A/B di bawah).
- Produces: rilis 0.19.0 siap dipropagasi; user cukup update plugin.

- [ ] **Step 1: Bump versi di dua file**

Di `plugin/.claude-plugin/plugin.json`: `"version": "0.18.0"` → `"version": "0.19.0"`.
Di `.claude-plugin/marketplace.json`: DUA occurrence `"version": "0.18.0"` → `"version": "0.19.0"`.
Verifikasi: `grep -rn '"0.18.0"' plugin/.claude-plugin/plugin.json .claude-plugin/marketplace.json` → Expected: kosong.

- [ ] **Step 2: Update description `plugin.json`**

Di string description, ganti penutup `, docs).` menjadi:

```
, auto-title session (judul session otomatis dari skill yang dipanggil — hook UserPromptSubmit level plugin, last-skill-wins, read-only skip), docs).
```

(Cek dulu `, docs).` unik di file itu; kalau tidak, pakai konteks lebih panjang.)

- [ ] **Step 3: Tambah section README**

Tambahkan SETELAH section `## Perubahan kecil (jalur ringan)` (sebelum section berikutnya):

```markdown
## Auto-title session
Session Claude Code otomatis di-judul dari skill kerja yang dipanggil — `/build checkout-v2` → session `build: checkout-v2` di `/resume`. Skill kerja terakhir menang; skill read-only (`/ask`, `/guide`, `/render-docs`, `/debt`) tidak mengubah judul. Butuh Claude Code v2.1.196+ (versi lama: no-op aman).
```

Lalu tambahkan SATU kalimat caveat sesuai hasil probe Task 3:
- **Wording A (tingkat 1 — `/rename` terdeteksi hook):** `Rename manual dihormati: setelah kamu `/rename`, auto-title berhenti untuk session itu.`
- **Wording B (tingkat 2 — `/rename` tidak lewat hook):** `Catatan: nama hasil `/rename` manual bertahan sampai skill kerja berikutnya dipanggil (batasan hook Claude Code saat ini).`

- [ ] **Step 4: Smoke manual (butuh manusia, sesi interaktif)**

1. Update instalasi plugin dari marketplace lokal (mis. `claude plugin update context-vault`, atau uninstall+install ulang dari marketplace repo ini).
2. Di sebuah produk ber-`control/` (atau scratch product), buka sesi interaktif → jalankan `/build coba-x`.
3. Verifikasi: judul di prompt bar / `/resume` = `build: coba-x`; lalu `/ask status` → judul TIDAK berubah.

Kalau implementer = subagent tanpa akses sesi interaktif: tandai langkah ini `needs_human` di laporan akhir, JANGAN klaim lulus.

- [ ] **Step 5: Commit rilis**

```bash
git add plugin/.claude-plugin/plugin.json .claude-plugin/marketplace.json README.md
git commit -m "chore(release): bump 0.19.0 — auto-title session via hook plugin (UserPromptSubmit)"
```
