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
#
# Baris progres: selama `claude -p` jalan, proses latar (ticker) memanggil
# .claude/build_status.py tiap DRIVE_TICK detik (default 5) dan menulis SATU baris yang
# update di tempat (`\r`; bukan TTY → baris baru hanya saat isinya berubah) — angka sama
# dengan panel mod di sesi Claude Code. Heartbeat .claude/build/<fitur>/drive.json
# (putaran, mulai, MAX_JAM, PID) ditulis tiap awal putaran → panel tahu "unattended · putaran N";
# dihapus waktu keluar lewat jalur mana pun (trap). Butuh python3 (DRIVE_PYTHON untuk override).
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
  # hitung rule VERIFIKASI: bukan git, bukan apply-migrate (opt-in wire 5.5 — dikecualikan best-effort by nama tool;
  # rule migrate sendirian BUKAN bukti test/lint ada → jangan bikin precheck "puas" palsu)
  nongit="$(jq -r '[.permissions.allow[]? | select((test("^Bash\\(git")|not) and (test("migrat|alembic|goose|drizzle-kit|supabase db|db push|dbmate|flyway|liquibase"; "i")|not))] | length' "$SETTINGS" 2>/dev/null || echo 0)"
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

# --- Precheck pembaca status (baris progres). Kurang → instruksi + EXIT, jangan jalan diam-diam
#     tanpa baris progres. ---
PY="${DRIVE_PYTHON:-python3}"
TICK="${DRIVE_TICK:-5}"
BS="$ROOT/.claude/build_status.py"
if ! "$PY" -c 'import json' >/dev/null 2>&1; then
  echo "[drive] STOP — butuh python3 buat baris progres (.claude/build_status.py)." >&2
  echo "        Install python3 (macOS: xcode-select --install), lalu ulang drive.sh." >&2
  exit 1
fi
if [ ! -f "$BS" ]; then
  echo "[drive] STOP — .claude/build_status.py belum ada; jalankan 'upgrade' dulu." >&2
  exit 1
fi

# --- Heartbeat + ticker baris progres ---
HB_DIR="$ROOT/.claude/build/$FITUR"
HB="$HB_DIR/drive.json"
STARTED="$(date +%s)"
TICKER_PID=""
write_hb() {   # tulis-ke-tmp lalu mv → pembaca tak pernah lihat file setengah jadi
  mkdir -p "$HB_DIR"
  printf '{"round":%s,"started":%s,"round_started":%s,"max_hours":%s,"pid":%s}\n' \
    "$ronde" "$STARTED" "$(date +%s)" "$MAX_JAM" "$$" > "$HB.tmp" && mv "$HB.tmp" "$HB"
}
ticker() {     # jalan di subshell latar; TERM → bunuh sleep anaknya dulu supaya stdout tak ketahan
  local line last=""
  TSLEEP=""
  trap '[ -n "$TSLEEP" ] && kill "$TSLEEP" 2>/dev/null; exit 0' TERM
  while :; do
    line="$("$PY" "$BS" --root "$ROOT" --work-item "control/features/$FITUR" --format drive 2>/dev/null)" || line=""
    if [ -n "$line" ]; then
      if [ -t 1 ]; then printf '\r\033[K[drive] %s' "$line"
      elif [ "$line" != "$last" ]; then printf '[drive] %s\n' "$line"; fi
      last="$line"
    fi
    sleep "$TICK" & TSLEEP=$!
    wait "$TSLEEP"; TSLEEP=""
  done
}
stop_ticker() {
  [ -n "$TICKER_PID" ] || return 0
  kill "$TICKER_PID" 2>/dev/null; wait "$TICKER_PID" 2>/dev/null; TICKER_PID=""
  if [ -t 1 ]; then printf '\n'; fi
}
trap 'stop_ticker; rm -f "$HB" "$HB.tmp"' EXIT
trap 'exit 130' INT TERM

prev_done=-1
ronde=0
while :; do
  ronde=$(( ronde + 1 ))
  echo "[drive] putaran $ronde — build $FITUR (proses fresh)…"
  write_hb
  ticker & TICKER_PID=$!
  out="$(cd "$ROOT" && claude -p "build $FITUR --unattended" --permission-mode acceptEdits)" || true   # proses BARU; auto file-edit, Bash tetap allowlist; resume dari tasks.yaml
  stop_ticker
  [ -n "$out" ] && printf '%s\n' "$out"   # dicetak sesudah ticker berhenti — tak tabrakan dengan baris \r

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
