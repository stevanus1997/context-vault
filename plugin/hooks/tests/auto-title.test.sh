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

run "session_id aneh disanitasi (no traversal)" \
  "$(pj '/rename jahat' '../evil')" \
  ""
if [ -f "$HOME/.claude/context-vault/evil" ]; then
  FAIL=$((FAIL+1)); echo "FAIL - traversal kejadian (file di luar session-locks)"
elif [ -f "$HOME/.claude/context-vault/session-locks/.._evil" ]; then
  PASS=$((PASS+1)); echo "ok   - lock tersanitasi di dalam session-locks"
else
  FAIL=$((FAIL+1)); echo "FAIL - lock tersanitasi tidak ditemukan"
fi

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
