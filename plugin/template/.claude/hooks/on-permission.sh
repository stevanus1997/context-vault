#!/usr/bin/env bash
# Hook `PermissionRequest` — dipanggil HARNESS saat sebuah tool minta approval.
# Hanya kabari bila lagi mode unattended (penanda .unattended ada) → run hands-off
# BEKU nunggu manusia (kasus perintah tak ter-allowlist; lihat build reference §D).
# Build tak bisa kabari diri sendiri saat beku — makanya ini tugas hook.
# Di sesi interaktif (tanpa penanda) → DIAM, jangan spam.
# TIDAK auto-approve/deny — cuma kabari; manusia yang putuskan.
set -uo pipefail
DIR="${CLAUDE_PROJECT_DIR:-.}"
[ -f "$DIR/.claude/.unattended" ] || exit 0      # bukan run hands-off → diam
PAYLOAD="$(cat 2>/dev/null || true)"
TOOL="?"; CMD=""
if command -v jq >/dev/null 2>&1; then
  TOOL="$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // "?"' 2>/dev/null || echo '?')"
  CMD="$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
fi
CMD="${CMD:0:60}"                                # ringkas: kecilkan paparan ke kanal notif (lihat reference §G)
NOTIFY="$DIR/.claude/notify.sh"
[ -x "$NOTIFY" ] && "$NOTIFY" "build BEKU nunggu approval: $TOOL ${CMD}" || true
exit 0
