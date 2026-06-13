#!/usr/bin/env bash
# drive.sh — outer-loop driver (pola Ralph) untuk `build <fitur> --unattended`.
# Pakai:  bash .claude/drive.sh <fitur> [maks-jam]   (jalankan dari root produk)
#
# Tiap putaran = PROSES `claude` BARU → context window FRESH; memori hidup di
# tasks.yaml (disk), bukan di kepala model. Build self-cap per putaran (cap-volume
# build reference §D, default 10 task) supaya tiap proses kecil & mati sebelum
# context membengkak; driver ini = rem KERAS di luar model.
#
# Berhenti saat: outcome=done (selesai) / outcome=halt (butuh manusia — TAK di-restart) /
# satu putaran nol-kemajuan (mandek) / lewat batas waktu. Sinyal dibaca dari header
# mesin di control/features/<fitur>/last-run.md (lihat build reference §G & §H).
#
# Prasyarat: plugin context-vault ter-install + `claude` CLI di PATH + allowlist harness
# sudah diisi (wire 5.5 + bentuk multi-repo `git -C *`) supaya Bash tak beku di prompt.
# Flag --permission-mode acceptEdits = auto-terima Edit/Write file (tasks.yaml+kode) tanpa
# prompt, TAPI Bash tetap tunduk allowlist (push/rm tetap diblok deny). Tanpa flag ini,
# headless beku di tool Edit.
set -uo pipefail

FITUR="${1:?usage: bash .claude/drive.sh <fitur> [maks-jam]}"
MAX_JAM="${2:-6}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"          # root produk (.claude/ ada di sini)
REPORT="$ROOT/control/features/$FITUR/last-run.md"
DEADLINE=$(( $(date +%s) + MAX_JAM * 3600 ))

prev_done=-1
ronde=0
while :; do
  ronde=$(( ronde + 1 ))
  echo "[drive] putaran $ronde — build $FITUR (proses fresh)…"
  ( cd "$ROOT" && claude -p "build $FITUR --unattended" --permission-mode acceptEdits ) || true   # proses BARU; auto file-edit, Bash tetap allowlist; resume dari tasks.yaml

  if [ ! -f "$REPORT" ]; then
    echo "[drive] last-run.md tak ada — build tak lapor; STOP (cek manual)"; break
  fi
  outcome="$(grep -m1 '^outcome:' "$REPORT" | awk '{print $2}')"
  done_now="$(grep -m1 '^done:'    "$REPORT" | awk '{print $2}')"
  [[ "$done_now" =~ ^[0-9]+$ ]] || done_now=0   # header malformed/non-numerik → 0 (fail-safe: nol-kemajuan bakal nge-bail)

  case "$outcome" in
    done) echo "[drive] outcome=done → SELESAI, fitur siap di-ship 🎉"; break ;;
    halt) echo "[drive] outcome=halt → butuh manusia 🔔 (floor; TIDAK di-restart)"; break ;;
    continue) : ;;                                                   # ada pending, aman lanjut
    *)    echo "[drive] outcome tak dikenal ('$outcome') → STOP (fail-safe)"; break ;;
  esac

  if [ "$done_now" -le "$prev_done" ]; then
    echo "[drive] putaran ini NOL kemajuan (done=$done_now) → mandek, STOP"; break
  fi
  prev_done="$done_now"

  if [ "$(date +%s)" -ge "$DEADLINE" ]; then
    echo "[drive] lewat batas ${MAX_JAM} jam → STOP (backstop waktu)"; break
  fi
done
