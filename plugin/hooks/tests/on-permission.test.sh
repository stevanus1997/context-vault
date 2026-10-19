#!/usr/bin/env bash
# Test on-permission.sh (hook PermissionRequest) — notify.sh PALSU mencatat pesan ke file.
# Jalanin: bash plugin/hooks/tests/on-permission.test.sh  (exit 0 = semua lulus)
# Pola sama dengan auto-title.test.sh (counter PASS/FAIL).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$ROOT/plugin/template/.claude/hooks/on-permission.sh"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL - $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; }
command -v jq >/dev/null 2>&1 || { echo "butuh jq"; exit 1; }

# run <pakai-penanda:1|0> <payload>  → isi pesan yang dikirim ke notify.sh (kosong = tak ada notif)
run() {
  local prod; prod="$(mktemp -d)"
  mkdir -p "$prod/.claude"
  printf '#!/usr/bin/env bash\nprintf "%%s" "$1" > "%s/.claude/sent"\n' "$prod" > "$prod/.claude/notify.sh"
  chmod +x "$prod/.claude/notify.sh"
  [ "$1" = 1 ] && : > "$prod/.claude/.unattended"
  printf '%s' "$2" | CLAUDE_PROJECT_DIR="$prod" bash "$HOOK"
  cat "$prod/.claude/sent" 2>/dev/null || true
  rm -rf "$prod"
}

ASK='{"tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"Approve draft business.md di atas?","header":"Gate intake","options":[{"label":"Approve"},{"label":"Revisi"}]}]}}'
BASH_P='{"tool_name":"Bash","tool_input":{"command":"pnpm prisma migrate deploy"}}'

# 1. tanpa penanda .unattended → diam (sesi attended biasa tak di-spam)
out="$(run 0 "$ASK")"
[ -z "$out" ] && ok "tanpa penanda → diam" || bad "tanpa penanda → diam" "$out"

# 2. penanda + Bash → pesan BEKU lama tetap (tool + perintah)
out="$(run 1 "$BASH_P")"
[ "$out" = "build BEKU nunggu approval: Bash pnpm prisma migrate deploy" ] && ok "Bash → pesan BEKU" || bad "Bash → pesan BEKU" "$out"

# 3. penanda + AskUserQuestion → pesan beda, cuma header (isi pertanyaan TIDAK bocor ke kanal)
out="$(run 1 "$ASK")"
[ "$out" = "build nunggu jawaban (kotak): Gate intake" ] && ok "AskUserQuestion → nunggu jawaban + header" || bad "AskUserQuestion → nunggu jawaban + header" "$out"
grep -q 'business.md' <<<"$out" && bad "isi pertanyaan bocor ke notif" "$out" || ok "isi pertanyaan tak bocor ke notif"

# 4. penanda + payload rusak → tetap kabari (fallback BEKU, tool '?'), tak crash
out="$(run 1 'bukan json')"
[ "${out#build BEKU nunggu approval: }" != "$out" ] && ok "payload rusak → fallback BEKU" || bad "payload rusak → fallback BEKU" "$out"

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
