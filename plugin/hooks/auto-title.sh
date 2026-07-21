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
