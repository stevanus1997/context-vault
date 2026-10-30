#!/usr/bin/env bash
# Test unit sync-check.sh — hook SessionStart deteksi control/ basi. Feed stdin JSON, assert stdout.
# Jalanin: bash plugin/hooks/tests/sync-check.test.sh  (exit 0 = semua lulus)
set -uo pipefail
HOOKS="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$HOOKS/sync-check.sh"
ROOT="$(cd "$HOOKS/../.." && pwd)"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL - $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
. "$ROOT/tools/tests/lib/sync-fixture.sh"
SS="python3 -B $ROOT/plugin/skills/sync/sync_status.py"

hook() { # hook <stdin> [cwd-proses] → stdout di $out, exit code di $RC
  ( cd "${2:-$T}" && printf '%s' "$1" | bash "$HOOK" 2>/dev/null ) > "$T/hook.out"; RC=$?
  out="$(cat "$T/hook.out")"
}
cwdj() { jq -cn --arg c "$1" '{session_id:"s", hook_event_name:"SessionStart", source:"startup", cwd:$c}'; }

P="$T/p"; mkprod "$P"; $SS init --root "$P" > /dev/null

# H2 — produk tidak basi
hook "$(cwdj "$P")"
[ $RC -eq 0 ] && [ -z "$out" ] && ok "H2 produk sinkron → diam" || bad "H2 (rc=$RC)" "$out"

# H1 — produk basi
remote_commit "$P" api alice "feat: a (#1)"; git -C "$P/api" fetch -q
hook "$(cwdj "$P")"
[ $RC -eq 0 ] && printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' >/dev/null 2>&1 \
  && ok "H1 basi → JSON SessionStart" || bad "H1 (rc=$RC)" "$out"
printf '%s' "$out" | jq -er '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q 'api (1)' \
  && ok "H1 additionalContext menyebut api (1)" || bad "H1 teks" "$out"

# H3 — subfolder repo & folder kosong
hook "$(cwdj "$P/api")"
[ $RC -eq 0 ] && [ -z "$out" ] && ok "H3 cwd subfolder repo → diam" || bad "H3 subfolder (rc=$RC)" "$out"
mkdir -p "$T/kosong"
hook "$(cwdj "$T/kosong")"
[ $RC -eq 0 ] && [ -z "$out" ] && ok "H3 cwd folder kosong → diam" || bad "H3 kosong (rc=$RC)" "$out"

# H4 — stdin bukan JSON: jatuh ke $PWD
hook 'bukan json' "$T/kosong"
[ $RC -eq 0 ] && [ -z "$out" ] && ok "H4 stdin rusak + PWD bukan produk → diam" || bad "H4 (rc=$RC)" "$out"
hook 'bukan json' "$P"
[ $RC -eq 0 ] && printf '%s' "$out" | jq -e '.hookSpecificOutput' >/dev/null 2>&1 \
  && ok "H4 stdin rusak + PWD produk basi → tetap lapor" || bad "H4 PWD produk (rc=$RC)" "$out"

# H6 — sync.yaml rusak / script gagal → diam, exit 0
printf 'repos:\n  - [rusak\n' > "$P/control/sync.yaml"
hook "$(cwdj "$P")"
[ $RC -eq 0 ] && [ -z "$out" ] && ok "H6 sync.yaml rusak → diam" || bad "H6 (rc=$RC)" "$out"

# H5 — hooks.json
jq empty "$HOOKS/hooks.json" 2>/dev/null && ok "H5 hooks.json valid" || bad "H5 hooks.json tak valid"
[ "$(jq -r '.hooks.SessionStart[0].hooks[0].timeout' "$HOOKS/hooks.json" 2>/dev/null)" = "5" ] \
  && ok "H5 SessionStart timeout 5" || bad "H5 SessionStart timeout"
jq -r '.hooks.SessionStart[0].hooks[0].command' "$HOOKS/hooks.json" 2>/dev/null | grep -qF '/hooks/sync-check.sh' \
  && ok "H5 SessionStart → sync-check.sh" || bad "H5 command"
[ -x "$HOOK" ] && ok "H5 sync-check.sh executable" || bad "H5 sync-check.sh tak executable"
[ -z "$(find "$ROOT/plugin" -name __pycache__ 2>/dev/null)" ] && ok "Z tanpa __pycache__" || bad "Z ada __pycache__"

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
