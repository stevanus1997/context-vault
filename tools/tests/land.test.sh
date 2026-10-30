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
j() { $PY -c 'import json,os,sys; d=json.load(open(sys.argv[1])); r=eval(sys.argv[2]); print(json.dumps(r) if not isinstance(r,str) else r)' "$1" "$2" 2>/dev/null; }
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
    */replies) echo '{"id": 99, "html_url": "https://x/c99"}'; exit 0 ;;
    repos/*/pulls/*/comments)
      key="${2#repos/}"; r="${key%/pulls/*}"; pr="${key#*/pulls/}"; pr="${pr%/comments}"
      f="$GH_DIR/inline-${r//\//_}-$pr.ndjson"; [ -f "$f" ] && cat "$f"; exit 0 ;;
  esac
fi
case "$1 $2" in
  "pr view")
    f="$GH_DIR/view-${repo//\//_}-$3"
    if [ -f "$f.$GH_ROUND.json" ]; then cat "$f.$GH_ROUND.json"; else cat "$f.json"; fi ;;
  "run view") for i in $(seq 1 500); do echo "baris-$i"; done ;;
  "pr comment") echo "https://x/i99" ;;
  "pr create") echo "https://github.com/acme/api/pull/12" ;;
  "repo view") echo '{"defaultBranchRef": {"name": "main"}}' ;;
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

# === W: tulis ke repo dan GitHub, dengan batas ===
reset_gh
rm -rf "$STATE"
for a in api web; do git -C "$P/$a" config user.name tester; git -C "$P/$a" config user.email t@x; done
BARE="$P.origin/web.git"
git -C "$P/web" switch -q -c feat/x
gcommit "$P/web" bob "feat: x"
git -C "$P/web" push -q origin feat/x 2>/dev/null
git -C "$P/web" switch -q main
PRSHA="$(git -C "$P/web" rev-parse feat/x)"
pv() { view acme_web-7 "d['headRefOid']='$PRSHA'${1:+; $1}"; }
pv
git clone -q "$BARE" "$T/oth" 2>/dev/null
git -C "$T/oth" config user.name other; git -C "$T/oth" config user.email o@x
bare_sha() { git --git-dir="$BARE" rev-parse "${1:-feat/x}"; }
oth_push() { # commit lain langsung ke branch PR di remote
  git -C "$T/oth" fetch -q origin; git -C "$T/oth" switch -q feat/x 2>/dev/null; git -C "$T/oth" merge -q --ff-only origin/feat/x
  echo "$1" >> "$T/oth/lain.txt"; git -C "$T/oth" add lain.txt; git -C "$T/oth" commit -q -m "lain: $1"; git -C "$T/oth" push -q origin feat/x 2>/dev/null
}
WT="$P/.land/f1/web"
msg="$T/msg.txt"; echo "fix: test" > "$msg"
BEFORE_ST="$(git -C "$P/web" status --porcelain=v1 -b)"
lw worktree "${W1[@]}" --pr web#7 > "$T/w1.json"; rc=$?
[ $rc -eq 0 ] && check "W1 worktree di .land/f1/web" "$T/w1.json" "os.path.realpath(d['dir'])==os.path.realpath('$WT')" 2>/dev/null || bad "W1 exit $rc" "$(cat "$T/w1.json")"
[ "$(git -C "$WT" rev-parse HEAD 2>/dev/null)" = "$PRSHA" ] && ok "W1 HEAD = head PR" || bad "W1 HEAD"
[ "$(git -C "$P/web" status --porcelain=v1 -b)" = "$BEFORE_ST" ] && ok "W1 checkout user tak berubah" || bad "W1 checkout berubah"
(cd "$P" && lw worktree --root . --work-item features/f1 --pr web#7) > "$T/w1r.json"; rc=$?
[ $rc -eq 0 ] && check "W1 --root . tetap di .land produk" "$T/w1r.json" "os.path.isabs(d['dir']) and d['dir'].endswith('/.land/f1/web')" || bad "W1 --root . exit $rc" "$(cat "$T/w1r.json")"
echo "kode" >> "$WT/a.txt"
lw commit "${W1[@]}" --dir "$WT" --message-file "$msg" > "$T/w2a.json"; rc=$?
[ $rc -eq 0 ] && ok "W2 commit" || bad "W2 commit exit $rc" "$(cat "$T/w2a.json")"
lw commit "${W1[@]}" --dir "$WT" --message-file "$msg" > "$T/w2b.json"; rc=$?
[ $rc -eq 6 ] && check "W2 tanpa perubahan exit 6" "$T/w2b.json" "d['error']=='no-changes'" || bad "W2 tanpa perubahan exit $rc"
lw push "${W1[@]}" --pr web#7 --dir "$WT" > "$T/w2c.json"; rc=$?
[ $rc -eq 0 ] && ok "W2 push exit 0" || bad "W2 push exit $rc" "$(cat "$T/w2c.json")"
[ "$(bare_sha)" = "$(git -C "$WT" rev-parse HEAD)" ] && ok "W2 bare = HEAD worktree" || bad "W2 bare beda"

echo "lagi" >> "$WT/a.txt"; lw commit "${W1[@]}" --dir "$WT" --message-file "$msg" > /dev/null
KEEP="$(bare_sha)"
push_refused() { # push_refused <nama> <error> <kode python view>
  pv "$3"
  lw push "${W1[@]}" --pr web#7 --dir "$WT" > "$T/w.json"; rc=$?
  [ $rc -eq 6 ] && check "$1" "$T/w.json" "d['error']=='$2'" || bad "$1 exit $rc" "$(cat "$T/w.json")"
  [ "$(bare_sha)" = "$KEEP" ] && ok "$1: bare tak berubah" || bad "$1: bare berubah"
}
push_refused "W3 head = base" protected-branch "d['baseRefName']='feat/x'"
push_refused "W3 head = default branch" protected-branch "d['headRefName']='main'; d['baseRefName']='rel'"
push_refused "W3 PR tidak open" not-open "d['state']='MERGED'"
push_refused "W4 PR dari fork" fork "d['isCrossRepository']=True"
pv
oth_push satu; KEEP="$(bare_sha)"
push_refused "W5 remote maju" non-fast-forward "pass"
lw push "${W1[@]}" --pr web#7 --dir "$T" > "$T/w6.json"; rc=$?
[ $rc -eq 2 ] && check "W6 dir di luar .land" "$T/w6.json" "d['error']=='dir'" || bad "W6 exit $rc" "$(cat "$T/w6.json")"
lw commit "${W1[@]}" --dir "$P/web" --message-file "$msg" > "$T/w6b.json"; rc=$?
[ $rc -eq 2 ] && ok "W6 commit di checkout user ditolak" || bad "W6b exit $rc"
view acme_api-3
lw push "${W1[@]}" --pr api#3 --dir "$WT" > "$T/w6c.json"; rc=$?
[ $rc -eq 2 ] && check "W6 worktree repo lain ditolak" "$T/w6c.json" "d['error']=='dir'" || bad "W6c exit $rc" "$(cat "$T/w6c.json")"

rm -rf "$P/.land"; git -C "$P/web" worktree prune
PRSHA="$(bare_sha)"; pv
lw worktree "${W1[@]}" --pr web#7 > /dev/null
oth_push dua
lw worktree "${W1[@]}" --pr web#7 > "$T/w1b.json"
[ "$(git -C "$WT" rev-parse HEAD)" = "$(bare_sha)" ] && ok "W1 worktree disusulkan ke head terbaru" || bad "W1 tak disusulkan"
echo "x" >> "$WT/a.txt"; lw commit "${W1[@]}" --dir "$WT" --message-file "$msg" > /dev/null
LOCAL="$(git -C "$WT" rev-parse HEAD)"
lw worktree "${W1[@]}" --pr web#7 > "$T/w1c.json"
check "W1 commit belum di-push dibiarkan" "$T/w1c.json" "d['ahead']==1"
[ "$(git -C "$WT" rev-parse HEAD)" = "$LOCAL" ] && ok "W1 HEAD tetap" || bad "W1 HEAD dibuang"

rm -rf "$P/.land"; git -C "$P/web" worktree prune
lw worktree "${W1[@]}" --pr web#7 > /dev/null
git -C "$T/oth" switch -q main; git -C "$T/oth" pull -q --ff-only origin main 2>/dev/null
echo b > "$T/oth/b.txt"; git -C "$T/oth" add b.txt; git -C "$T/oth" commit -q -m "base: b"; git -C "$T/oth" push -q origin main 2>/dev/null
lw merge-base "${W1[@]}" --pr web#7 --dir "$WT" > "$T/w7a.json"; rc=$?
[ $rc -eq 0 ] && check "W7 merge bersih" "$T/w7a.json" "d['clean'] is True and d['conflicts']==[]" || bad "W7 exit $rc" "$(cat "$T/w7a.json")"
[ -f "$WT/b.txt" ] && ok "W7 isi base masuk" || bad "W7 isi base absen"
echo beda >> "$T/oth/log.txt"; git -C "$T/oth" add log.txt; git -C "$T/oth" commit -q -m "base: log"; git -C "$T/oth" push -q origin main 2>/dev/null
echo konflik >> "$WT/log.txt"; lw commit "${W1[@]}" --dir "$WT" --message-file "$msg" > /dev/null
lw merge-base "${W1[@]}" --pr web#7 --dir "$WT" > "$T/w7b.json"; rc=$?
[ $rc -eq 0 ] && check "W7 konflik" "$T/w7b.json" "d['clean'] is False and d['conflicts']==['log.txt']" || bad "W7b exit $rc" "$(cat "$T/w7b.json")"
[ -f "$WT/.git" ] && git -C "$WT" rev-parse -q --verify MERGE_HEAD >/dev/null && ok "W7 konflik tidak di-abort" || bad "W7 merge di-abort"
sed -i.bak '/^<<<<<<<\|^=======\|^>>>>>>>/d' "$WT/log.txt" 2>/dev/null; rm -f "$WT/log.txt.bak"
printf 'selesai\n' > "$WT/log.txt"
lw commit "${W1[@]}" --dir "$WT" --message-file "$msg" > "$T/w7c.json"; rc=$?
[ $rc -eq 0 ] && [ -z "$(git -C "$WT" rev-parse -q --verify MERGE_HEAD)" ] && ok "W7 commit menutup merge" || bad "W7c exit $rc" "$(cat "$T/w7c.json")"

reply="$T/reply.txt"; echo "Done" > "$reply"
cat > "$GH_DIR/inline-acme_web-7.ndjson" <<'JSON'
{"id": 55, "user": {"login": "bob"}, "body": "ganti", "path": "a.ts", "line": 8, "html_url": "https://x/c55", "created_at": "2026-10-30T01:00:00Z"}
{"id": 58, "in_reply_to_id": 55, "user": {"login": "bob"}, "body": "tambah", "path": "a.ts", "line": 8, "html_url": "https://x/c58", "created_at": "2026-10-30T01:00:00Z"}
JSON
: > "$GH_DIR/log"
lw reply "${W1[@]}" --pr web#7 --to c55 --body-file "$reply" > "$T/w8.json"; rc=$?
[ $rc -eq 0 ] && grep -qF 'pulls/7/comments/55/replies --method POST -F body=@' "$GH_DIR/log" && ok "W8 balas thread inline" || bad "W8 exit $rc" "$(cat "$T/w8.json"; cat "$GH_DIR/log")"
: > "$GH_DIR/log"
lw reply "${W1[@]}" --pr web#7 --to c58 --body-file "$reply" > /dev/null
grep -qF 'pulls/7/comments/55/replies' "$GH_DIR/log" && ok "W8 balas komentar balasan → ke akar thread" || bad "W8 akar thread" "$(cat "$GH_DIR/log")"
lw reply "${W1[@]}" --pr web#7 --to c999 --body-file "$reply" > "$T/w8b.json"; rc=$?
[ $rc -eq 2 ] && ok "W8 komentar di luar PR ditolak" || bad "W8b exit $rc"
: > "$GH_DIR/log"
lw reply "${W1[@]}" --pr web#7 --to i9 --body-file "$reply" > /dev/null; rc=$?
[ $rc -eq 0 ] && grep -qF 'pr comment 7' "$GH_DIR/log" && ok "W8 balas percakapan" || bad "W8 i9 exit $rc" "$(cat "$GH_DIR/log")"
lw reply "${W1[@]}" --pr web#8 --to c55 --body-file "$reply" > /dev/null; rc=$?
[ $rc -eq 2 ] && ok "W8 PR tak terdaftar exit 2" || bad "W8 --pr exit $rc"

pv "d['statusCheckRollup']=[{'__typename':'CheckRun','name':'test','status':'COMPLETED','conclusion':'FAILURE','detailsUrl':'https://github.com/acme/web/actions/runs/123/job/9'},{'__typename':'StatusContext','context':'ext/ci','state':'ERROR','targetUrl':'https://ci.example/1'}]"
lw log "${W1[@]}" --pr web#7 --check test > "$T/w9.json"; rc=$?
[ $rc -eq 0 ] && check "W9 log terisi, dipotong 400 baris" "$T/w9.json" "'baris-500' in d['log'] and 'baris-50\n' not in d['log'] and len(d['log'].splitlines())==400" || bad "W9 exit $rc" "$(head -c 300 "$T/w9.json")"
lw log "${W1[@]}" --pr web#7 --check ext/ci > "$T/w9b.json"; rc=$?
[ $rc -eq 6 ] && check "W9 check eksternal → link" "$T/w9b.json" "d['error']=='no-log' and d['link']=='https://ci.example/1'" || bad "W9b exit $rc"

ABARE="$P.origin/api.git"
lw worktree "${W1[@]}" --repo-key api --base main > "$T/w10a.json"; rc=$?
AWT="$P/.land/f1/api"
[ $rc -eq 0 ] && [ -d "$AWT" ] && ok "W10 worktree repo baru" || bad "W10 worktree exit $rc" "$(cat "$T/w10a.json")"
echo baru > "$AWT/n.txt"; lw commit "${W1[@]}" --dir "$AWT" --message-file "$msg" > /dev/null
body="$T/body.txt"; echo "isi PR" > "$body"
: > "$GH_DIR/log"
OP=(open-pr "${W1[@]}" --repo-key api --dir "$AWT" --base main --title Judul --body-file "$body")
lw "${OP[@]}" --head feat/baru > "$T/w10.json"; rc=$?
[ $rc -eq 0 ] && check "W10 ref PR baru" "$T/w10.json" "d['ref']=='api#12'" || bad "W10 exit $rc" "$(cat "$T/w10.json")"
[ "$(git --git-dir="$ABARE" rev-parse feat/baru 2>/dev/null)" = "$(git -C "$AWT" rev-parse HEAD)" ] && ok "W10 branch ada di bare" || bad "W10 branch absen"
grep -qF 'pr create' "$GH_DIR/log" && ok "W10 pr create" || bad "W10 pr create" "$(cat "$GH_DIR/log")"
MAINSHA="$(git --git-dir="$ABARE" rev-parse main)"
lw "${OP[@]}" --head main > "$T/w10b.json"; rc=$?
[ $rc -eq 6 ] && check "W10 --head main ditolak" "$T/w10b.json" "d['error']=='protected-branch'" || bad "W10b exit $rc" "$(cat "$T/w10b.json")"
[ "$(git --git-dir="$ABARE" rev-parse main)" = "$MAINSHA" ] && ok "W10 main bare tak berubah" || bad "W10 main berubah"
lw "${OP[@]}" --head feat/baru > "$T/w10c.json"; rc=$?
[ $rc -eq 6 ] && check "W10 branch yang sudah ada ditolak" "$T/w10c.json" "d['error']=='branch-exists'" || bad "W10c exit $rc" "$(cat "$T/w10c.json")"

echo tertinggal >> "$WT/a.txt"
mkdir -p "$STATE"; echo '{}' > "$STATE/state.json"
lw cleanup "${W1[@]}" > "$T/w11.json"; rc=$?
[ $rc -eq 0 ] && ok "W11 cleanup exit 0" || bad "W11 exit $rc" "$(cat "$T/w11.json")"
[ ! -e "$P/.land/f1" ] && [ ! -e "$STATE" ] && ok "W11 .land/f1 dan .claude/land/f1 hilang" || bad "W11 sisa folder"
[ "$(git -C "$P/web" worktree list | wc -l | tr -d ' ')" = 1 ] && [ "$(git -C "$P/api" worktree list | wc -l | tr -d ' ')" = 1 ] && ok "W11 worktree terdaftar bersih" || bad "W11 worktree" "$(git -C "$P/web" worktree list)"

n="$(grep -cE -- "--force|-f'|'merge', '--|pr', '(merge|close|review)'" "$SRC/land_watch.py")"
[ "$n" = 0 ] && ok "W12 tanpa perintah merge/force/close/review" || bad "W12 ada $n baris terlarang" "$(grep -nE -- "--force|-f'|'merge', '--|pr', '(merge|close|review)'" "$SRC/land_watch.py")"
[ "$(grep -c CLAUDE_PLUGIN_ROOT "$SRC/land_watch.py")" = 0 ] && ok "W12 tanpa CLAUDE_PLUGIN_ROOT" || bad "W12 CLAUDE_PLUGIN_ROOT"

# === lingkungan ===
[ -z "$(find "$ROOT/plugin" -name __pycache__ 2>/dev/null)" ] && ok "Z __pycache__ tak ada di plugin/" || bad "Z ada __pycache__ di plugin/"

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
