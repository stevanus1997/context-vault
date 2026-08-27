#!/usr/bin/env bash
# drive.sh — outer-loop driver (pola Ralph) untuk `build <fitur> --unattended`.
# Pakai:  bash .claude/drive.sh <fitur> [maks-jam]   (jalankan dari root produk)
#
# Tiap putaran = PROSES `claude` BARU → context window FRESH; memori hidup di
# tasks.yaml (disk), bukan di kepala model. Build self-cap per putaran (cap-volume
# build reference §D = budget BOBOT, default 10 poin — task berat ber-mockup/integration
# makan jatah lebih cepat, bukan sekadar hitung jumlah task) supaya tiap proses kecil &
# mati sebelum context membengkak; driver ini = rem KERAS di luar model.
#
# Berhenti saat: outcome=done (selesai) / outcome=review (gate/blocker nunggu manusia —
# drain pagi via `build <fitur>` attended, lalu jalankan lagi) / outcome=halt (ABNORMAL:
# circuit-breaker/env/allowlist/state — TAK di-restart) / satu putaran nol-kemajuan (mandek)
# / lewat batas waktu. Sinyal dibaca dari header mesin di control/features/<fitur>/last-run.md
# (lihat build reference §G, §H, §I). Gate yang butuh manusia TIDAK menghentikan build —
# ia diantrikan ke gates.yaml; build lanjut sampai tak ada task yang bisa dibangun.
#
# Prasyarat: plugin context-vault ter-install + `claude` CLI di PATH + allowlist harness
# sudah diisi (wire 5.5 + `git -C <path>` ENUMERASI per-path, BUKAN `git -C *` yg mati) +
# workspace di-trust supaya Bash tak beku di prompt.
# Flag --permission-mode acceptEdits = auto-terima Edit/Write file (tasks.yaml+kode) tanpa
# prompt, TAPI Bash tetap tunduk allowlist (push/rm tetap diblok deny). Tanpa flag ini,
# headless beku di tool Edit.
set -uo pipefail

FITUR="${1:?usage: bash .claude/drive.sh <fitur> [maks-jam]}"
MAX_JAM="${2:-6}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"          # root produk (.claude/ ada di sini)
REPORT="$ROOT/control/features/$FITUR/last-run.md"
DEADLINE=$(( $(date +%s) + MAX_JAM * 3600 ))

# --- Precheck prasyarat unattended (backstop "Y") — dijalankan saat MANUSIA masih di
#     terminal, supaya tak freeze headless di tengah loop. Kurang → instruksi + EXIT. ---
SETTINGS="$ROOT/.claude/settings.json"
NOTIFY="$ROOT/.claude/notify.sh"
if [ ! -x "$NOTIFY" ]; then
  echo "[drive] STOP — notify.sh belum diset; loop unattended butuh kanal notif." >&2
  echo "        Setup: jalankan 'wire'/'upgrade', ATAU 'build $FITUR --unattended' sekali interaktif." >&2
  exit 1
fi
if command -v jq >/dev/null 2>&1; then
  nongit="$(jq -r '[.permissions.allow[]? | select(test("^Bash\\(git")|not)] | length' "$SETTINGS" 2>/dev/null || echo 0)"
else
  nongit=1   # tanpa jq: jangan false-block, lewati cek allowlist
fi
if [ ! -f "$SETTINGS" ] || [ "${nongit:-0}" -eq 0 ]; then
  echo "[drive] STOP — allowlist verifikasi stack belum keisi di .claude/settings.json." >&2
  echo "        Tanpa ini build beku di permission prompt headless. Jalankan 'wire' step 5.5 dulu." >&2
  exit 1
fi

# --- Precheck TRUST workspace (backstop RC2) — `permissions.allow` produk DIABAIKAN saat
#     headless bila workspace belum di-trust (perintah read-only find/ls tetap jalan via
#     sandbox → gejalanya "git ke-blok tapi yang lain jalan"). Manusia masih di terminal
#     → instruksi + EXIT, jangan biarkan loop headless beku diam-diam di permission prompt. ---
CLAUDE_JSON="$HOME/.claude.json"
if command -v jq >/dev/null 2>&1 && [ -f "$CLAUDE_JSON" ]; then
  trusted="$(jq -r --arg p "$ROOT" '.projects[$p].hasTrustDialogAccepted // false' "$CLAUDE_JSON" 2>/dev/null || echo false)"
  if [ "$trusted" != "true" ]; then
    echo "[drive] STOP — workspace belum di-trust; allowlist .claude/settings.json bakal DIABAIKAN headless." >&2
    echo "        Fix: buka 'claude' interaktif sekali di root produk ini & terima dialog trust, lalu ulang drive.sh." >&2
    exit 1
  fi
fi

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
  rev_n="$(grep -m1 '^review:'   "$REPORT" | awk '{print $2}')"   # opsional (header lama tak punya) → "?"
  blk_n="$(grep -m1 '^blockers:' "$REPORT" | awk '{print $2}')"
  [[ "${rev_n:-}" =~ ^[0-9]+$ ]] || rev_n="?"
  [[ "${blk_n:-}" =~ ^[0-9]+$ ]] || blk_n="?"

  case "$outcome" in
    done)   echo "[drive] outcome=done → SELESAI, fitur siap di-ship 🎉"; break ;;
    review) echo "[drive] outcome=review → ${rev_n} gate + ${blk_n} blocker nunggu lo 🔔 — pagi jalankan 'build $FITUR' (attended) buat drain, lalu drive.sh lagi (TIDAK di-restart otomatis)"; break ;;
    halt)   echo "[drive] outcome=halt → ABNORMAL (circuit-breaker/env/allowlist/state) — cek last-run.md; TIDAK di-restart"; break ;;
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
