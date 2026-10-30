#!/usr/bin/env bash
# Hook `SessionStart` (level PLUGIN, bukan template produk) — deteksi control/ basi tanpa LLM:
# bandingkan patokan control/sync.yaml dengan branch utama tiap repo (git lokal, tanpa fetch).
# Ada selisih → satu baris additionalContext; skill feature/plan/fix/tweak/review-pr yang menawarkan /sync.
# Diam di luar produk context-vault / produk yang belum pernah sinkron (sync.yaml absen).
# SELALU exit 0 — gagal apa pun = diam, jangan pernah ganggu buka sesi.
# Spec: docs/superpowers/specs/2026-10-29-team-sync-review-pr-design.md (D4, D14)
set -uo pipefail

INPUT="$(cat 2>/dev/null)" || INPUT=""
CWD=""
if command -v jq >/dev/null 2>&1; then
  CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)" || CWD=""
fi
[ -n "$CWD" ] || CWD="$PWD"

[ -f "$CWD/control/workspace.yaml" ] && [ -f "$CWD/control/sync.yaml" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

OUT="$(python3 -B "$(dirname "$0")/../skills/sync/sync_status.py" status --root "$CWD" --format hook 2>/dev/null)" || exit 0
[ -n "$OUT" ] && printf '%s\n' "$OUT"
exit 0
