#!/usr/bin/env bash
# Test skill sync — sync_status.py (patokan/selisih/penanda), assemble.py ringkasan, cek statis skill & rule.
# Jalanin: bash tools/tests/sync.test.sh  (exit 0 = semua lulus)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SK="$ROOT/plugin/skills/sync"
FX="$ROOT/tools/tests/fixtures/sync"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL - $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; }
command -v python3 >/dev/null 2>&1 || { echo "butuh python3"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "butuh git"; exit 1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PY="python3 -B"
. "$ROOT/tools/tests/lib/sync-fixture.sh"

ss() { $PY "$SK/sync_status.py" "$@"; }
j() { # j <file-json> <ekspresi python atas d> → cetak hasil
  $PY -c 'import json,sys; d=json.load(open(sys.argv[1])); r=eval(sys.argv[2]); print(json.dumps(r) if not isinstance(r,str) else r)' "$1" "$2" 2>/dev/null
}
check() { # check <nama> <file-json> <ekspresi bool>
  if [ "$(j "$2" "$3")" = "true" ]; then ok "$1"; else bad "$1" "$(head -c 600 "$2")"; fi
}
parse_ok() { # parse_ok <file-yaml> → exit 0 bila parse_yaml build_status.py membacanya
  $PY - "$ROOT/plugin/template/.claude/build_status.py" "$1" <<'PY'
import importlib.util, sys
sys.dont_write_bytecode = True
s = importlib.util.spec_from_file_location('bs', sys.argv[1]); m = importlib.util.module_from_spec(s); s.loader.exec_module(m)
m.parse_yaml(open(sys.argv[2], encoding='utf-8').read())
PY
}
repo() { echo "[r for r in d['repos'] if r['key']=='$1'][0]"; }
TODAY="$($PY -c 'import datetime;print(datetime.date.today().isoformat())')"
TOMORROW="$($PY -c 'import datetime;print((datetime.date.today()+datetime.timedelta(days=1)).isoformat())')"

# === S: patokan (init/status/advance) ===
P="$T/p"; mkprod "$P"

# S1 — belum pernah sinkron
ss status --root "$P" > "$T/s1.json"; rc=$?
[ $rc -eq 0 ] && check "S1 initialized false + reason belum pernah sinkron" "$T/s1.json" \
  "d['initialized'] is False and d['reason']=='belum pernah sinkron'" || bad "S1 status exit $rc"
out="$(ss status --root "$P" --format hook)"; rc=$?
[ $rc -eq 0 ] && [ -z "$out" ] && ok "S1 --format hook diam" || bad "S1 hook tak diam (rc=$rc)" "$out"

# S2 — init
ss init --root "$P" --contracts api > "$T/s2.json"; rc=$?
if [ $rc -eq 0 ]; then ok "S2 init exit 0"; else bad "S2 init exit $rc" "$(cat "$T/s2.json")"; fi
Y="$P/control/sync.yaml"
grep -qxF 'contracts_repos: [api]' "$Y" && ok "S2 contracts_repos: [api]" || bad "S2 contracts_repos" "$(cat "$Y" 2>/dev/null)"
grep -qE '^    base_ref: origin/main$' "$Y" && ok "S2 base_ref origin/main" || bad "S2 base_ref" "$(cat "$Y" 2>/dev/null)"
grep -E '^bot_authors:' "$Y" | grep -q 'ci-bot' && ok "S2 bot_authors memuat ci-bot" || bad "S2 bot_authors" "$(cat "$Y" 2>/dev/null)"
grep -E '^bot_authors:' "$Y" | grep -q 'alice' && bad "S2 alice ikut jadi bot" || ok "S2 alice bukan bot"
head -1 "$Y" | grep -qF '# control/sync.yaml' && ok "S2 header komentar" || bad "S2 header" "$(head -2 "$Y")"
parse_ok "$Y" && ok "S2 parse_yaml membaca ulang" || bad "S2 parse_yaml gagal"
ss status --root "$P" > "$T/s2b.json"
check "S2 status: initialized, stale kosong" "$T/s2b.json" "d['initialized'] is True and d['stale']==[]"
check "S2 status: api apps/base_ref/behind 0" "$T/s2b.json" "$(repo api)['apps']==['api'] and $(repo api)['base_ref']=='origin/main' and $(repo api)['behind']==0"

# S3 — commit rekan masuk origin, lalu fetch
for m in a1 a2; do remote_commit "$P" api alice "feat: $m"; done
for m in b1 b2 b3; do remote_commit "$P" api ci-bot "chore: $m"; done
git -C "$P/api" fetch -q
ss status --root "$P" > "$T/s3.json"
check "S3 api behind 2 / behind_all 5" "$T/s3.json" "$(repo api)['behind']==2 and $(repo api)['behind_all']==5"
check "S3 stale == [api]" "$T/s3.json" "d['stale']==['api']"
ss status --root "$P" --format hook > "$T/s3h.json"
check "S3 hook: hookEventName SessionStart" "$T/s3h.json" "d['hookSpecificOutput']['hookEventName']=='SessionStart'"
check "S3 hook: teks diawali + memuat api (2)" "$T/s3h.json" \
  "d['hookSpecificOutput']['additionalContext'].startswith('[context-vault] control/ ketinggalan 2 commit') and 'api (2)' in d['hookSpecificOutput']['additionalContext']"
check "S3 --repos web → api tak ikut" <(ss status --root "$P" --repos web) "[r['key'] for r in d['repos']]==['web'] and d['stale']==[]"

# S4 — advance
H="$(remote_head "$P" api)"
ss advance --root "$P" --repo api --sha "$H" >/dev/null; rc=$?
[ $rc -eq 0 ] && ok "S4 advance exit 0" || bad "S4 advance exit $rc"
ss status --root "$P" > "$T/s4.json"
check "S4 stale kosong + synced_at hari ini" "$T/s4.json" "d['stale']==[] and $(repo api)['synced_at']=='$TODAY' and $(repo api)['synced_sha']=='$H'"

# S5 — app bukan git + repo tanpa remote
mkdir -p "$P/doc"
git init -q -b main "$P/local"; gcommit "$P/local" alice "init local"
cat >> "$P/control/workspace.yaml" <<'YAML'
  - name: doc
    path: doc
  - name: local
    path: local
YAML
$PY - "$P/control/workspace.yaml" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
# pindahkan baris packages: [] ke ujung supaya doc/local tetap di bawah apps
s = s.replace('packages: []\n', '') + 'packages: []\n'
open(p, 'w').write(s)
PY
ss status --root "$P" > "$T/s5.json"; rc=$?
[ $rc -eq 0 ] && ok "S5 status exit 0" || bad "S5 status exit $rc"
check "S5 doc.error bukan repo git" "$T/s5.json" "$(repo doc)['error']=='bukan repo git'"
check "S5 local.error terisi" "$T/s5.json" "$(repo local)['error'] is not None"
check "S5 api/web tetap terhitung" "$T/s5.json" "$(repo api)['error'] is None and $(repo api)['behind']==0 and $(repo web)['behind']==0"
rm "$Y"
ss init --root "$P" > "$T/s5i.json"; rc=$?
[ $rc -eq 3 ] && ok "S5 init tanpa base → exit 3" || bad "S5 init exit $rc (harap 3)" "$(cat "$T/s5i.json")"
check "S5 need_base memuat local" "$T/s5i.json" "'local' in d['need_base'] and 'api' not in d['need_base']"
[ -f "$Y" ] && bad "S5 sync.yaml tertulis padahal need_base" || ok "S5 sync.yaml tidak ditulis"
ss init --root "$P" --contracts api --base local=main > "$T/s5j.json"; rc=$?
[ $rc -eq 0 ] && ok "S5 init --base local=main exit 0" || bad "S5 init --base exit $rc" "$(cat "$T/s5j.json")"
check "S5 local terdaftar base main" "$T/s5j.json" "$(repo local)['base_ref']=='main' and $(repo local)['error'] is None"

# S6 — master di-force-push
W="$P.work/api"
ROOTC="$(git -C "$W" rev-list --max-parents=0 HEAD | tail -1)"
git -C "$W" reset -q --hard "$ROOTC"; gcommit "$W" alice "riwayat baru"
git -C "$W" push -q --force origin HEAD:main 2>/dev/null
git -C "$P/api" fetch -q 2>/dev/null
WEB_BEFORE="$(grep -A4 '^  web:' "$Y" | grep synced_sha)"
ss status --root "$P" > "$T/s6.json"
check "S6 api error patokan hilang + behind null" "$T/s6.json" \
  "$(repo api)['error']=='patokan hilang dari riwayat' and $(repo api)['behind'] is None and $(repo api)['behind_all'] is None and 'api' not in d['stale']"
H2="$(remote_head "$P" api)"
ss advance --root "$P" --repo api --sha "$H2" >/dev/null 2>&1; rc=$?
[ $rc -eq 1 ] && ok "S6 advance ke riwayat baru ditolak (exit 1)" || bad "S6 advance exit $rc (harap 1)"
ss init --root "$P" --force --only api > "$T/s6i.json"; rc=$?
[ $rc -eq 0 ] && ok "S6 init --force --only api exit 0" || bad "S6 --only exit $rc" "$(cat "$T/s6i.json")"
check "S6 api pulih" "$T/s6i.json" "$(repo api)['error'] is None and $(repo api)['synced_sha']=='$H2'"
[ "$(grep -A4 '^  web:' "$Y" | grep synced_sha)" = "$WEB_BEFORE" ] && ok "S6 synced_sha web tak berubah" || bad "S6 web berubah"
grep -qxF 'contracts_repos: [api]' "$Y" && ok "S6 contracts_repos tetap" || bad "S6 contracts_repos hilang" "$(cat "$Y")"
ss init --root "$P" --only api > /dev/null 2>&1; rc=$?
[ $rc -ne 0 ] && ok "S6 --only tanpa --force ditolak" || bad "S6 --only tanpa --force lolos"

# S7 — bukan produk
mkdir -p "$T/kosong"
ss status --root "$T/kosong" > "$T/s7.json"
check "S7 reason bukan produk" "$T/s7.json" "d['initialized'] is False and d['reason']=='bukan produk context-vault' and d['repos']==[]"
out="$(ss status --root "$T/kosong" --format hook)"; rc=$?
[ $rc -eq 0 ] && [ -z "$out" ] && ok "S7 hook diam" || bad "S7 hook (rc=$rc)" "$out"

# S8 — --since
P8="$T/p8"; mkprod "$P8"
ss init --root "$P8" --since "$TOMORROW" > "$T/s8.json"
check "S8 --since besok → HEAD" "$T/s8.json" "$(repo api)['synced_sha']=='$(remote_head "$P8" api)'"
ss init --root "$P8" --force --since 2000-01-01 > "$T/s8b.json"
check "S8 --since 2000-01-01 → commit akar" "$T/s8b.json" "$(repo api)['synced_sha']=='$(git -C "$P8/api" rev-list --max-parents=0 origin/main | tail -1)'"
ss init --root "$P8" --force --since kemarin > /dev/null 2>&1; rc=$?
[ $rc -eq 2 ] && ok "S8 --since format salah → exit 2" || bad "S8 --since salah exit $rc"

# === lingkungan ===
[ -z "$(find "$ROOT/plugin" -name __pycache__ 2>/dev/null)" ] && ok "Z __pycache__ tak ada di plugin/" || bad "Z ada __pycache__ di plugin/"

# === RINGKASAN ===
echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
