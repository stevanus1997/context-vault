#!/usr/bin/env bash
# Test skill land — land_watch.py (stub gh + git bare lokal) dan cek statis dokumen.
# Jalanin: bash tools/tests/land.test.sh  (exit 0 = semua lulus)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/plugin/template/.claude"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL - $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; }
command -v python3 >/dev/null 2>&1 || { echo "butuh python3"; exit 1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PY="python3 -B"
PYABS="$(command -v python3)"
j() { $PY -c 'import json,sys; d=json.load(open(sys.argv[1])); r=eval(sys.argv[2]); print(json.dumps(r) if not isinstance(r,str) else r)' "$1" "$2" 2>/dev/null; }
check() { if [ "$(j "$2" "$3")" = "true" ]; then ok "$1"; else bad "$1" "$(head -c 800 "$2")"; fi; }
source "$ROOT/tools/tests/lib/sync-fixture.sh"

# --- stub gh: jawab dari $GH_DIR, tiap panggilan dicatat di $GH_DIR/log ---
mkdir -p "$T/bin" "$T/gh"
cat > "$T/bin/gh" <<'SH'
#!/usr/bin/env bash
echo "$*" >> "$GH_DIR/log"
n="$(cat "$GH_DIR/round" 2>/dev/null || echo 0)"; n=$((n+1)); echo "$n" > "$GH_DIR/round"
GH_ROUND="$n"
if [ -n "${GH_FAIL:-}" ]; then echo "$GH_FAIL" >&2; exit 1; fi
if [ -n "${GH_FAIL_ROUNDS:-}" ] && [ "$n" -le "$GH_FAIL_ROUNDS" ]; then echo "HTTP 502: Bad Gateway" >&2; exit 1; fi
repo=""; prev=""
for a in "$@"; do [ "$prev" = "--repo" ] && repo="$a"; prev="$a"; done
if [ "$1" = api ]; then
  case "$2" in
    user) echo '{"login": "me"}'; exit 0 ;;
    repos/*/pulls/*/comments)
      key="${2#repos/}"; r="${key%/pulls/*}"; pr="${key#*/pulls/}"; pr="${pr%/comments}"
      f="$GH_DIR/inline-${r//\//_}-$pr.ndjson"; [ -f "$f" ] && cat "$f"; exit 0 ;;
  esac
fi
case "$1 $2" in
  "pr view")
    f="$GH_DIR/view-${repo//\//_}-$3"
    if [ -f "$f.$GH_ROUND.json" ]; then cat "$f.$GH_ROUND.json"; else cat "$f.json"; fi ;;
  *) echo "stub gh: tak dikenal: $*" >&2; exit 1 ;;
esac
SH
chmod +x "$T/bin/gh"
export GH_DIR="$T/gh"
GHPATH="$T/bin:$PATH"

view() { # view <acme_web-7> [kode python atas d]
  $PY - "$GH_DIR/view-$1.json" "$1" "${2:-pass}" <<'PY2'
import json, sys
name = sys.argv[2]
repo, n = name.rsplit('-', 1)
d = dict(number=int(n), state='OPEN', url='https://github.com/%s/pull/%s' % (repo.replace('_', '/'), n),
         headRefName='feat/x', headRefOid='sha1', baseRefName='main', mergeable='MERGEABLE',
         reviewDecision='', isCrossRepository=False, comments=[], reviews=[], statusCheckRollup=[])
exec(sys.argv[3])
json.dump(d, open(sys.argv[1], 'w'))
PY2
}
reset_gh() { rm -f "$GH_DIR"/*; view acme_web-7; view acme_api-3; }

# --- produk: app api + web, origin terbaca github.com/acme/*, push tetap ke bare lokal ---
P="$T/p"; mkprod "$P"
for a in api web; do
  git -C "$P/$a" config url."$P.origin/$a.git".insteadOf "https://github.com/acme/$a.git"
  git -C "$P/$a" remote set-url origin "https://github.com/acme/$a.git"
done
mkdir -p "$P/.claude" "$P/control/features/f1" "$P/control/fixes/y"
cp "$SRC/land_watch.py" "$SRC/build_status.py" "$P/.claude/" 2>/dev/null
LW="$P/.claude/land_watch.py"
printf 'bot_authors: [ci-bot, "renovate[bot]"]\ncontracts_repos: []\nrepos: {}\n' > "$P/control/sync.yaml"
manifest() { printf 'status: in_review\nprs: %s\n' "$1" > "$P/control/features/f1/feature.yaml"; }
manifest '["web#7", "api#3"]'
printf 'status: in_review\nfix_pr: ""\n' > "$P/control/fixes/y/fix.yaml"
STATE="$P/.claude/land/f1"
W1=(--root "$P" --work-item features/f1)
lw() { PATH="$GHPATH" $PY "$LW" "$@"; }
fresh() { rm -rf "$STATE"; reset_gh; }

# === L: baca PR + deteksi kejadian ===
fresh
manifest '["web#7", "https://github.com/acme/api/pull/3"]'
lw scan "${W1[@]}" > "$T/l1.json"; rc=$?
[ $rc -eq 0 ] && ok "L1 scan exit 0" || bad "L1 scan exit $rc" "$(cat "$T/l1.json")"
check "L1 ref dari key#n dan URL" "$T/l1.json" "sorted(p['ref'] for p in d['prs'])==['api#3','web#7']"
manifest '"web#7"'
lw scan "${W1[@]}" > "$T/l1b.json"
check "L1 prs satu string" "$T/l1b.json" "[p['ref'] for p in d['prs']]==['web#7']"
manifest '[]'
lw scan "${W1[@]}" > "$T/l2.json"; rc=$?
[ $rc -eq 0 ] && check "L2 prs kosong → need_pr" "$T/l2.json" "d['need_pr'] is True and d['kinds']==[]" || bad "L2 exit $rc" "$(cat "$T/l2.json")"
lw scan --root "$P" --work-item fixes/y > "$T/l2b.json"; rc=$?
[ $rc -eq 0 ] && check "L2 fix_pr kosong → need_pr" "$T/l2b.json" "d['need_pr'] is True and d['kinds']==[]" || bad "L2b exit $rc" "$(cat "$T/l2b.json")"
manifest '["web#7", "api#3"]'

fresh
view acme_api-3 "d['statusCheckRollup']=[{'__typename':'CheckRun','name':'test','status':'COMPLETED','conclusion':'FAILURE','detailsUrl':'https://github.com/acme/api/actions/runs/123/job/9'}]"
lw scan "${W1[@]}" > "$T/l3.json"
check "L3 check gagal + run_id" "$T/l3.json" "'checks_failed' in d['kinds'] and d['prs'][1]['failed_checks'][0]['run_id']=='123'"
[ -f "$STATE/event.json" ] && ok "L3 event.json ditulis" || bad "L3 event.json absen"

fresh
view acme_api-3 "d['statusCheckRollup']=[{'__typename':'StatusContext','context':'ext/ci','state':'ERROR','targetUrl':'https://ci.example/1'}]"
lw scan "${W1[@]}" > "$T/l4.json"
check "L4 StatusContext eksternal tanpa run_id" "$T/l4.json" "d['prs'][1]['failed_checks'][0]['run_id'] is None and d['prs'][1]['failed_checks'][0]['link']=='https://ci.example/1'"

fresh
view acme_api-3 "d['statusCheckRollup']=[{'__typename':'CheckRun','name':'test','status':'IN_PROGRESS','conclusion':'','detailsUrl':''}]"
lw scan "${W1[@]}" > "$T/l5.json"
check "L5 check jalan bukan kejadian" "$T/l5.json" "d['kinds']==[] and d['prs'][1]['pending_checks']==1"

fresh
view acme_web-7 "d['comments']=[dict(id='IC_1',author=dict(login='bob'),body='umum',createdAt='2026-10-30T01:00:00Z',url='https://x/i1'),dict(id='IC_2',author=dict(login='me'),body='saya',createdAt='2026-10-30T01:00:00Z',url='https://x/i2'),dict(id='IC_3',author=dict(login='renovate'),body='bump',createdAt='2026-10-30T01:00:00Z',url='https://x/i3')]; d['reviews']=[dict(id='PRR_1',author=dict(login='bob'),body='ubah ya',state='CHANGES_REQUESTED',submittedAt='2026-10-30T01:00:00Z'),dict(id='PRR_2',author=dict(login='bob'),body='',state='COMMENTED',submittedAt='2026-10-30T01:00:00Z')]"
cat > "$GH_DIR/inline-acme_web-7.ndjson" <<'JSON'
{"id": 55, "user": {"login": "bob"}, "body": "ganti", "path": "a.ts", "line": 8, "html_url": "https://x/c55", "created_at": "2026-10-30T01:00:00Z"}
{"id": 56, "user": {"login": "ci-bot"}, "body": "lint", "path": "a.ts", "line": 9, "html_url": "https://x/c56", "created_at": "2026-10-30T01:00:00Z"}
JSON
lw scan "${W1[@]}" > "$T/l6.json"
check "L6 tiga komentar dari reviewer" "$T/l6.json" "len(d['prs'][0]['comments'])==3 and 'comments' in d['kinds']"
check "L6 id berawalan c/i/r" "$T/l6.json" "sorted(c['id'][0] for c in d['prs'][0]['comments'])==['c','i','r']"
check "L6 tanpa akun sendiri/bot (termasuk bot GraphQL tanpa [bot])" "$T/l6.json" "not {c['author'] for c in d['prs'][0]['comments']} & {'me','ci-bot','renovate'}"
check "L6 inline bawa path/line" "$T/l6.json" "[c for c in d['prs'][0]['comments'] if c['id']=='c55'][0]['path']=='a.ts' and [c for c in d['prs'][0]['comments'] if c['id']=='c55'][0]['line']==8"
lw ack "${W1[@]}" > /dev/null
lw scan "${W1[@]}" > "$T/l7.json"
check "L7 sesudah ack tak muncul lagi" "$T/l7.json" "d['kinds']==[]"
cat >> "$GH_DIR/inline-acme_web-7.ndjson" <<'JSON'
{"id": 57, "in_reply_to_id": 55, "user": {"login": "me"}, "body": "done", "path": "a.ts", "line": 8, "html_url": "https://x/c57", "created_at": "2026-10-30T02:00:00Z"}
{"id": 60, "user": {"login": "bob"}, "body": "yang ini belum", "path": "b.ts", "line": 3, "html_url": "https://x/c60", "created_at": "2026-10-30T02:00:00Z"}
JSON
rm -f "$STATE/state.json"
lw scan "${W1[@]}" > "$T/l7b.json"
check "L7 tanpa state: thread terjawab sendiri tak muncul, yang belum muncul" "$T/l7b.json" \
  "(lambda ids: 'c55' not in ids and 'c60' in ids)([c['id'] for c in d['prs'][0]['comments']])"
lw ack "${W1[@]}" > /dev/null
lw scan "${W1[@]}" > "$T/l7c.json"
check "L7 thread terjawab tetap diam sesudah ack pertama" "$T/l7c.json" "d['kinds']==[]"

fresh
ROLL="[{'__typename':'CheckRun','name':'test','status':'COMPLETED','conclusion':'FAILURE','detailsUrl':'https://github.com/acme/api/actions/runs/123/job/9'}]"
view acme_api-3 "d['statusCheckRollup']=$ROLL"
lw scan "${W1[@]}" > /dev/null; lw ack "${W1[@]}" > /dev/null
lw scan "${W1[@]}" > "$T/l8a.json"
check "L8 sha sama sudah di-ack → diam" "$T/l8a.json" "d['kinds']==[]"
view acme_api-3 "d['statusCheckRollup']=$ROLL; d['headRefOid']='sha2'"
lw scan "${W1[@]}" > "$T/l8.json"
check "L8 sha baru, check sama gagal lagi → kejadian" "$T/l8.json" "'checks_failed' in d['kinds']"

fresh
view acme_web-7 "d['state']='MERGED'"
lw scan "${W1[@]}" > "$T/l9.json"
check "L9 sebagian merge" "$T/l9.json" "'merged' in d['kinds'] and d['all_merged'] is False"
lw ack "${W1[@]}" > /dev/null
lw scan "${W1[@]}" > "$T/l9b.json"
check "L9 sesudah ack kosong" "$T/l9b.json" "d['kinds']==[]"
view acme_api-3 "d['state']='MERGED'"
lw scan "${W1[@]}" > "$T/l10.json"
check "L10 semua merge" "$T/l10.json" "d['all_merged'] is True and 'merged' in d['kinds']"
lw ack "${W1[@]}" > /dev/null
lw scan "${W1[@]}" > "$T/l10b.json"
check "L10 semua merge tetap kejadian walau sudah di-ack (jangan nunggu selamanya)" "$T/l10b.json" "d['all_merged'] is True and 'merged' in d['kinds']"
fresh
view acme_api-3 "d['state']='CLOSED'"
lw scan "${W1[@]}" > "$T/l10c.json"
check "L10 ditutup" "$T/l10c.json" "'closed' in d['kinds'] and d['any_closed'] is True and d['all_merged'] is False"
lw ack "${W1[@]}" > /dev/null
view acme_api-3
lw scan "${W1[@]}" > /dev/null
view acme_api-3 "d['state']='CLOSED'"
lw scan "${W1[@]}" > "$T/l10d.json"
check "L10 dibuka lalu ditutup lagi → kejadian lagi" "$T/l10d.json" "'closed' in d['kinds']"
fresh
view acme_web-7 "d['mergeable']='CONFLICTING'"
lw scan "${W1[@]}" > "$T/l10e.json"
check "L10 konflik" "$T/l10e.json" "'conflict' in d['kinds']"

fresh
PATH="$GHPATH" $PY "$LW" watch "${W1[@]}" --interval 30 > "$T/l11a.json" & W_OLD=$!
for _ in $(seq 1 100); do [ -s "$STATE/watch.pid" ] && break; sleep 0.05; done
OLDPID="$(cat "$STATE/watch.pid" 2>/dev/null)"
PATH="$GHPATH" $PY "$LW" watch "${W1[@]}" --interval 2 --max-rounds 2 > "$T/l11b.json" & W_NEW=$!
for _ in $(seq 1 100); do NEWPID="$(cat "$STATE/watch.pid" 2>/dev/null)"; [ -n "$NEWPID" ] && [ "$NEWPID" != "$OLDPID" ] && break; sleep 0.05; done
[ -n "$OLDPID" ] && [ -n "$NEWPID" ] && [ "$NEWPID" != "$OLDPID" ] && ok "L11 watch.pid berisi pid terbaru" || bad "L11 watch.pid" "old=$OLDPID new=$NEWPID"
kill -0 "$OLDPID" 2>/dev/null && bad "L11 watcher lama masih hidup" || ok "L11 watcher lama mati"
wait "$W_OLD" 2>/dev/null
check "L11 watcher lama pamit tanpa kejadian" "$T/l11a.json" "d['kinds']==[] and d['replaced'] is True"
wait "$W_NEW"; rc=$?
[ $rc -eq 0 ] && check "L11 max-rounds habis → kinds kosong" "$T/l11b.json" "d['kinds']==[]" || bad "L11 watch baru exit $rc"
[ ! -e "$STATE/watch.pid" ] && ok "L11 watch.pid dihapus saat exit" || bad "L11 watch.pid tertinggal"
echo 99999 > "$STATE/watch.pid"; sleep 300 & SL=$!; echo "$SL" > "$STATE/watch.pid"
lw watch "${W1[@]}" --interval 0 --max-rounds 1 > /dev/null
kill -0 "$SL" 2>/dev/null && ok "L11 pid daur ulang (bukan watcher) tidak dibunuh" || bad "L11 proses lain terbunuh"
kill "$SL" 2>/dev/null; wait "$SL" 2>/dev/null

fresh
view acme_web-7 "d['state']='MERGED'"
GH_FAIL_ROUNDS=2 lw watch "${W1[@]}" --interval 0 --max-rounds 5 > "$T/l12.json"; rc=$?
[ $rc -eq 0 ] && check "L12 gangguan sementara dilewati, kejadian tetap keluar" "$T/l12.json" "'merged' in d['kinds']" || bad "L12 exit $rc" "$(cat "$T/l12.json")"

fresh
GH_FAIL='HTTP 404: Not Found' lw watch "${W1[@]}" --interval 0 --max-rounds 2 > "$T/l13.json"; rc=$?
[ $rc -eq 0 ] && check "L13 watch: auth jadi kejadian + hint" "$T/l13.json" "d['kinds']==['auth'] and bool(d['hint'])" || bad "L13 watch exit $rc" "$(cat "$T/l13.json")"
check "L13 event.json berisi auth" "$STATE/event.json" "d['kinds']==['auth']"
GH_FAIL='HTTP 404: Not Found' lw scan "${W1[@]}" > "$T/l13b.json"; rc=$?
[ $rc -eq 5 ] && ok "L13 scan exit 5" || bad "L13 scan exit $rc (harap 5)"

fresh
lw attempt "${W1[@]}" --pr web#7 --check test > "$T/a1.json"
lw attempt "${W1[@]}" --pr web#7 --check test > "$T/a2.json"
lw attempt "${W1[@]}" --pr web#7 --check test --reset > "$T/a3.json"
check "L14 attempt 1" "$T/a1.json" "d['count']==1"
check "L14 attempt 2" "$T/a2.json" "d['count']==2"
check "L14 attempt reset" "$T/a3.json" "d['count']==0"

fresh
lw scan --root "$P" --links https://github.com/acme/web/pull/7 > "$T/l15.json"; rc=$?
[ $rc -eq 0 ] && check "L15 mode link: ref" "$T/l15.json" "d['prs'][0]['ref']=='web#7'" || bad "L15 exit $rc" "$(cat "$T/l15.json")"
lw scan --root "$P" --links https://github.com/other/x/pull/1 > "$T/l15b.json"; rc=$?
[ $rc -eq 2 ] && check "L15 repo luar produk" "$T/l15b.json" "d['error']=='unknown-repo'" || bad "L15b exit $rc (harap 2)"
mkdir -p "$T/nogh"
PATH="$T/nogh" "$PYABS" -B "$LW" scan "${W1[@]}" > "$T/l16.json"; rc=$?
[ $rc -eq 4 ] && check "L16 tanpa gh → exit 4" "$T/l16.json" "d['error']=='gh-missing'" || bad "L16 exit $rc (harap 4)"
lw scan --root "$P" --work-item 'features/../../x' > /dev/null; rc=$?
[ $rc -eq 2 ] && ok "L17 work-item ngawur → exit 2" || bad "L17 exit $rc (harap 2)"

# === lingkungan ===
[ -z "$(find "$ROOT/plugin" -name __pycache__ 2>/dev/null)" ] && ok "Z __pycache__ tak ada di plugin/" || bad "Z ada __pycache__ di plugin/"

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
