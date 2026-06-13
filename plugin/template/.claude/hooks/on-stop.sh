#!/usr/bin/env bash
# Hook `Stop` — dipanggil HARNESS Claude Code tiap turn berakhir.
# Hanya bertindak bila ada penanda stop unattended (ditulis `build` di tiap titik STOP).
# Sumber kebenaran = laporan disk (`<work-item>/last-run.md`). Notifikasi = best-effort.
# Generik: sama untuk semua produk; kanal notif ada di notify.sh (punya user).
set -uo pipefail
DIR="${CLAUDE_PROJECT_DIR:-.}"
MARKER="$DIR/.claude/.unattended-stop"
[ -f "$MARKER" ] || exit 0                       # bukan stop unattended → diam
REASON="$(cat "$MARKER" 2>/dev/null)"
[ -n "$REASON" ] || REASON="build berhenti"
rm -f "$MARKER" "$DIR/.claude/.unattended"       # konsumsi sekali + matikan mode flag (run paused/selesai)
NOTIFY="$DIR/.claude/notify.sh"
[ -x "$NOTIFY" ] && "$NOTIFY" "build: $REASON" || true
exit 0
