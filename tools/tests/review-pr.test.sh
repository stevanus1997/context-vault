#!/usr/bin/env bash
# Test skill review-pr — prs.py (stub gh), assemble.py laporan, cek statis skill.
# Jalanin: bash tools/tests/review-pr.test.sh  (exit 0 = semua lulus)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SK="$ROOT/plugin/skills/review-pr"
FX="$ROOT/tools/tests/fixtures/review-pr"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL - $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; }
command -v python3 >/dev/null 2>&1 || { echo "butuh python3"; exit 1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PY="python3 -B"
PYABS="$(command -v python3)"
j() { $PY -c 'import json,sys; d=json.load(open(sys.argv[1])); r=eval(sys.argv[2]); print(json.dumps(r) if not isinstance(r,str) else r)' "$1" "$2" 2>/dev/null; }
check() { if [ "$(j "$2" "$3")" = "true" ]; then ok "$1"; else bad "$1" "$(head -c 600 "$2")"; fi; }

# --- stub gh: jawab dari $GH_DIR, GH_FAIL=<stderr> → exit 1 ---
mkdir -p "$T/bin" "$T/gh"
cat > "$T/bin/gh" <<'SH'
#!/usr/bin/env bash
if [ -n "${GH_FAIL:-}" ]; then echo "$GH_FAIL" >&2; exit 1; fi
repo=""; prev=""
for a in "$@"; do [ "$prev" = "--repo" ] && repo="$a"; prev="$a"; done
if [ "$1" = api ]; then
  [ -n "${GH_API_FAIL:-}" ] && [ "$2" != user ] && { echo "$GH_API_FAIL" >&2; exit 1; }
  [ "$2" = user ] && echo '{"login": "akun-pribadi"}' || echo '{"full_name": "ok"}'; exit 0
fi
if [ -n "${GH_FAIL_REPO:-}" ] && [ "$repo" = "$GH_FAIL_REPO" ]; then echo "HTTP 404: Not Found" >&2; exit 1; fi
case "$1 $2" in
  "search prs") cat "$GH_DIR/${GH_SEARCH:-search}.json" ;;
  "pr view")    cat "$GH_DIR/view-${repo//\//_}-$3.json" ;;
  "pr list")    f="$GH_DIR/list-${repo//\//_}.json"; [ -f "$f" ] && cat "$f" || echo '[]' ;;
  *) echo "stub gh: tak dikenal: $*" >&2; exit 1 ;;
esac
SH
chmod +x "$T/bin/gh"
export GH_DIR="$T/gh"
GHPATH="$T/bin:$PATH"

# --- produk: app api + web (repo git lokal) ---
P="$T/p"; mkdir -p "$P/control"
for a in api web; do git init -q -b main "$P/$a"; done
cat > "$P/control/workspace.yaml" <<'YAML'
product: Demo
apps:
  - name: api
    path: api
    repo_url: https://github.com/acme/api.git
  - name: web
    path: web
    repo_url: git@github.com:acme/web.git
packages: []
YAML
mkdir -p "$P/.claude/review"; : > "$P/.claude/review/web-7.html"

cat > "$T/gh/search.json" <<'JSON'
[{"number": 7, "title": "Rapikan form", "author": {"login": "bob"}, "createdAt": "2026-10-28T02:00:00Z",
  "url": "https://github.com/acme/web/pull/7", "repository": {"name": "web", "nameWithOwner": "acme/web"}},
 {"number": 3, "title": "BLCS-5302 jadwal ulang", "author": {"login": "jo"}, "createdAt": "2026-10-27T09:00:00Z",
  "url": "https://github.com/acme/api/pull/3", "repository": {"name": "api", "nameWithOwner": "acme/api"}},
 {"number": 9, "title": "BLCS-5302 lain", "author": {"login": "x"}, "createdAt": "2026-10-20T09:00:00Z",
  "url": "https://github.com/other/x/pull/9", "repository": {"name": "x", "nameWithOwner": "other/x"}}]
JSON
cat > "$T/gh/view-acme_api-3.json" <<'JSON'
{"number": 3, "title": "Jadwal ulang survey", "author": {"login": "jo"}, "url": "https://github.com/acme/api/pull/3",
 "headRefName": "feat/BLCS-5302/x", "headRefOid": "abc123", "baseRefName": "main"}
JSON
cat > "$T/gh/list-acme_api.json" <<'JSON'
[{"number": 3, "title": "Jadwal ulang survey", "author": {"login": "jo"}, "url": "https://github.com/acme/api/pull/3",
  "headRefName": "feat/BLCS-5302/x", "headRefOid": "abc123", "baseRefName": "main"},
 {"number": 4, "title": "Tanpa tiket", "author": {"login": "jo"}, "url": "https://github.com/acme/api/pull/4",
  "headRefName": "chore/z", "headRefOid": "abc124", "baseRefName": "main"}]
JSON
cat > "$T/gh/list-acme_web.json" <<'JSON'
[{"number": 8, "title": "Form jadwal ulang", "author": {"login": "jo"}, "url": "https://github.com/acme/web/pull/8",
  "headRefName": "feat/BLCS-5302-form", "headRefOid": "def456", "baseRefName": "master"},
 {"number": 10, "title": "BLCS-5302: copy", "author": {"login": "al"}, "url": "https://github.com/acme/web/pull/10",
  "headRefName": "copy", "headRefOid": "def457", "baseRefName": "master"},
 {"number": 11, "title": "Lain BLCS-53021", "author": {"login": "al"}, "url": "https://github.com/acme/web/pull/11",
  "headRefName": "lain", "headRefOid": "def458", "baseRefName": "master"}]
JSON
prs() { PATH="$GHPATH" $PY "$SK/prs.py" "$@"; }

# === P: prs.py ===
prs inbox --root "$P" > "$T/p1.json"; rc=$?
[ $rc -eq 0 ] && ok "P1 inbox exit 0" || bad "P1 inbox exit $rc" "$(cat "$T/p1.json")"
check "P1 hanya repo produk, urut lama→baru" "$T/p1.json" "[(x['owner_repo'],x['number']) for x in d]==[('acme/api',3),('acme/web',7)]"
check "P1 ticket dari judul + repo_key" "$T/p1.json" "d[0]['ticket']=='BLCS-5302' and d[1]['ticket'] is None and d[0]['repo_key']=='api' and d[1]['repo_key']=='web'"
check "P1 author/created/url/title" "$T/p1.json" "d[0]['author']=='jo' and d[0]['created']=='2026-10-27' and d[0]['url'].endswith('/pull/3') and d[0]['title']=='BLCS-5302 jadwal ulang'"
check "P1 reviewed_local" "$T/p1.json" "d[1]['reviewed_local'] is True and d[0]['reviewed_local'] is False"
prs view --root "$P" --pr 'acme/api#3' > "$T/p2.json"; rc=$?
[ $rc -eq 0 ] && ok "P2 view exit 0" || bad "P2 view exit $rc" "$(cat "$T/p2.json")"
check "P2 ticket dari head_ref + bentuk view" "$T/p2.json" \
  "d['ticket']=='BLCS-5302' and d['repo_key']=='api' and d['owner_repo']=='acme/api' and d['number']==3 and d['head_ref']=='feat/BLCS-5302/x' and d['head_sha']=='abc123' and d['base_ref']=='main' and d['author']=='jo'"
prs view --root "$P" --pr 'https://github.com/acme/api/pull/3' > "$T/p2b.json"
check "P2 --pr URL" "$T/p2b.json" "d['number']==3 and d['owner_repo']=='acme/api'"
prs view --root "$P" --pr 'api#3' > "$T/p2c.json"
check "P2 --pr repo-key#n" "$T/p2c.json" "d['number']==3 and d['owner_repo']=='acme/api'"
prs siblings --root "$P" --ticket BLCS-5302 --exclude 'acme/api#3' > "$T/p3.json"; rc=$?
[ $rc -eq 0 ] && ok "P3 siblings exit 0" || bad "P3 siblings exit $rc" "$(cat "$T/p3.json")"
check "P3 PR satu tiket (judul/branch), exclude & non-tiket terbuang" "$T/p3.json" \
  "sorted((x['owner_repo'],x['number']) for x in d)==[('acme/web',8),('acme/web',10)] and all(x['ticket']=='BLCS-5302' and x['repo_key']=='web' for x in d)"
GH_FAIL="HTTP 404: Not Found (https://api.github.com/graphql)" prs inbox --root "$P" > "$T/p4.json"; rc=$?
[ $rc -eq 5 ] && ok "P4 gh 404 → exit 5" || bad "P4 exit $rc (harap 5)"
check "P4 error gh-auth + hint gh auth switch" "$T/p4.json" "d['error']=='gh-auth' and 'gh auth switch' in d['hint'] and d['detail'].startswith('HTTP 404')"
GH_FAIL="Could not resolve to a Repository with the name 'acme/api'." prs view --root "$P" --pr 'acme/api#3' > /dev/null; rc=$?
[ $rc -eq 5 ] && ok "P4 Could not resolve → exit 5" || bad "P4 Could not resolve exit $rc"
GH_FAIL="timeout lain" prs inbox --root "$P" > /dev/null; rc=$?
[ $rc -eq 1 ] && ok "P4 error gh lain → exit 1" || bad "P4 error lain exit $rc"
mkdir -p "$T/nogh"
PATH="$T/nogh" "$PYABS" -B "$SK/prs.py" inbox --root "$P" > "$T/p5.json"; rc=$?
[ $rc -eq 4 ] && ok "P5 tanpa gh → exit 4" || bad "P5 exit $rc (harap 4)"
check "P5 error gh-missing" "$T/p5.json" "d['error']=='gh-missing'"
prs view --root "$P" --pr 'ngawur' > /dev/null 2>&1; rc=$?
[ $rc -eq 2 ] && ok "P6 --pr tak dikenal → exit 2" || bad "P6 exit $rc (harap 2)"

# === V: laporan review (assemble.py) ===
mut() { # mut <out.json> <kode python atas d>
  $PY - "$FX/report-ok.json" "$1" "$2" <<'PY2'
import json, sys
d = json.load(open(sys.argv[1], encoding='utf-8'))
exec(sys.argv[3])
json.dump(d, open(sys.argv[2], 'w', encoding='utf-8'), ensure_ascii=False)
PY2
}
asm() { $PY "$SK/assemble.py" --data "$1" --out "$2"; }
if asm "$FX/report-ok.json" "$T/v1.html" > "$T/v1.out" 2> "$T/v1.err"; then ok "V1 fixture lolos"
  for s in 'Perlu ubah' 'Copy komentar' 'survey_schedule_at' '<svg' 'class="map"' '2 hal harus dibenerin sebelum approve, 1 saran opsional.' \
           'Harus dibenerin' 'Saran' 'Info' 'Kontrak' 'Alur lintas-repo' 'Best practice' 'Konsistensi' 'BLCS-5302' 'LBOFE #1482' \
           'Struktur folder, nama datasource' 'boleh jadwal ulang' 'PR ini ikut izinin' 'Nama field beda sama sch'; do
    grep -qF -- "$s" "$T/v1.html" && ok "V1 memuat '$s'" || bad "V1 tanpa '$s'"; done
  grep -q '__' "$T/v1.html" && bad "V1 masih ada __" "$(grep -o '.\{20\}__.\{20\}' "$T/v1.html" | head -3)" || ok "V1 tanpa placeholder __"
  $PY - "$T/v1.html" <<'PY2' && ok "V1 urutan lapis kontrak→alur→best_practice→konsistensi & temuan harus→saran→info" || bad "V1 urutan"
import sys
s = open(sys.argv[1], encoding='utf-8').read()
lanes = [s.find('data-lane="%s"' % k) for k in ('kontrak', 'alur', 'best_practice', 'konsistensi')]
cards = [s.find('class="f %s' % k) for k in ('harus', 'saran', 'info')]
sys.exit(0 if -1 not in lanes + cards and lanes == sorted(lanes) and cards == sorted(cards) else 1)
PY2
else bad "V1 assemble gagal" "$(cat "$T/v1.err")"; fi
vo() { mut "$T/vo.json" "d['findings']=$1"; $PY "$SK/assemble.py" --data "$T/vo.json" --verdict-only 2>&1; }
[ "$(vo "[dict(lane='alur',level='saran',title='x')]")" = "Approve dengan saran" ] && ok "V2 [saran] → Approve dengan saran" || bad "V2 saran"
[ "$(vo "[dict(lane='alur',level='info',title='x')]")" = "Siap approve" ] && ok "V2 [info] → Siap approve" || bad "V2 info"
[ "$(vo "[]")" = "Siap approve" ] && ok "V2 [] → Siap approve" || bad "V2 kosong"
[ "$(vo "[dict(lane='alur',level='saran',title='x'),dict(lane='kontrak',level='harus',title='y')]")" = "Perlu ubah" ] && ok "V2 harus → Perlu ubah" || bad "V2 harus"
mut "$T/v2.json" "d['findings']=[f for f in d['findings'] if f['level']!='harus']"; asm "$T/v2.json" "$T/v2.html" >/dev/null 2>&1
grep -qF '1 saran opsional, aman di-approve.' "$T/v2.html" && ok "V2 subjudul hanya saran" || bad "V2 subjudul saran"
mut "$T/v2b.json" "d['findings']=[]"; asm "$T/v2b.json" "$T/v2b.html" >/dev/null 2>&1
grep -qF 'Nggak ada temuan.' "$T/v2b.html" && grep -qF 'Siap approve' "$T/v2b.html" && ok "V2 subjudul tanpa temuan" || bad "V2 subjudul kosong"
mut "$T/v3.json" "d['title']='<script>x</script>'; d['findings'][1]['comment']='<script>x</script> & </textarea>'; d['findings'][0]['evidence']['lines'][0]['text']='<script>x</script>'"
asm "$T/v3.json" "$T/v3.html" >/dev/null 2>&1
grep -qF '&lt;script&gt;x&lt;/script&gt;' "$T/v3.html" && ! grep -qF '<script>x' "$T/v3.html" && ! grep -qF '</textarea>' "$T/v3.html" \
  && ok "V3 judul/komentar/kode ter-escape" || bad "V3 escape"
mut "$T/v4.json" "d['findings'][0]['stale']=True; d['stale_repos']=['LBOFE']"; asm "$T/v4.json" "$T/v4.html" >/dev/null 2>&1
grep -qF 'mungkin karena catatan basi' "$T/v4.html" && ok "V4 chip catatan basi" || bad "V4 chip"
grep -qF 'Catatan control/ ketinggalan di LBOFE' "$T/v4.html" && ok "V4 banner stale_repos" || bad "V4 banner"
grep -qF 'mungkin karena catatan basi' "$T/v1.html" && bad "V4 chip muncul tanpa stale" || ok "V4 tanpa stale → tanpa chip"
mut "$T/v5.json" "d.pop('findings')"; asm "$T/v5.json" "$T/v5.html" >/dev/null 2>&1; rc=$?
[ $rc -eq 1 ] && [ ! -e "$T/v5.html" ] && ok "V5 tanpa findings → exit 1" || bad "V5 rc=$rc"
mut "$T/v5b.json" "d['findings'][0]['lane']='ngawur'"; asm "$T/v5b.json" "$T/v5b.html" >/dev/null 2>&1; rc=$?
[ $rc -eq 1 ] && ok "V5 lane tak dikenal → exit 1" || bad "V5 lane rc=$rc"
mut "$T/v6.json" "d.pop('map')"; asm "$T/v6.json" "$T/v6.html" >/dev/null 2>&1
grep -qF 'class="map"' "$T/v6.html" && bad "V6 peta muncul tanpa map" || ok "V6 map absen → tanpa peta"
mut "$T/v6b.json" "d['map']={'nodes':[{'id':'LBOFE','touched':True}],'edges':[]}"; asm "$T/v6b.json" "$T/v6b.html" >/dev/null 2>&1
grep -qF 'class="map"' "$T/v6b.html" && bad "V6 peta 1 node tetap dirender" || ok "V6 map 1 node → tanpa peta"

# === W: skill review-pr (statis) ===
SM="$SK/SKILL.md"
[ "$(sed -n 2p "$SM" 2>/dev/null)" = "name: review-pr" ] && ok "W1 frontmatter name: review-pr" || bad "W1 frontmatter"
for s in prs.py stale-guard.md feature-marker.md refs/cv-review assemble.py AskUserQuestion security-critic 'update-ref -d' 'gh pr diff' contracts_repos; do
  grep -qF -- "$s" "$SM" 2>/dev/null && ok "W2 SKILL.md memuat $s" || bad "W2 SKILL.md tanpa $s"; done
[ -f "$SK/reference.md" ] && grep -qF '"evidence"' "$SK/reference.md" && grep -qF '"lane_ok"' "$SK/reference.md" \
  && ok "W2 reference.md: skema laporan" || bad "W2 reference.md"
[ -f "$SM" ] && ! grep -F 'gh pr comment' "$SM" | grep -viqF 'tidak pernah' && ! grep -F 'gh pr review' "$SM" | grep -viqF 'tidak pernah' \
  && ok "W3 gh pr comment/review hanya di kalimat larangan" || bad "W3 gh pr comment/review di luar larangan"
grep -qE 'checkout|switch|stash' "$SM" 2>/dev/null && grep -E 'checkout|switch|stash' "$SM" | grep -vqiE 'dilarang|tidak pernah|jangan' \
  && bad "W3 checkout/switch/stash di luar larangan" || ok "W3 checkout/switch/stash hanya larangan"
grep -qF 'CLAUDE_PLUGIN_ROOT' "$SK"/*.py "$SK"/*.html && bad "W4 CLAUDE_PLUGIN_ROOT di script/template review-pr" || ok "W4 tanpa CLAUDE_PLUGIN_ROOT di .py/.html"

# === Q: perbaikan review akhir ===
echo '[]' > "$T/gh/empty.json"
GH_SEARCH=empty GH_API_FAIL="HTTP 404: Not Found" prs inbox --root "$P" > "$T/q1.json"; rc=$?
[ $rc -eq 5 ] && ok "Q1 inbox kosong + repo produk 404 → exit 5" || bad "Q1 exit $rc (harap 5)" "$(cat "$T/q1.json")"
check "Q1 gh-auth + hint + akun aktif" "$T/q1.json" "d['error']=='gh-auth' and 'gh auth switch' in d['hint'] and d.get('account')=='akun-pribadi'"
GH_SEARCH=empty prs inbox --root "$P" > "$T/q1b.json"; rc=$?
[ $rc -eq 0 ] && check "Q1 inbox kosong + repo terjangkau → [] exit 0" "$T/q1b.json" "d==[]" || bad "Q1b exit $rc"
P2="$T/p2"; mkdir -p "$P2/control"
for a in api web; do git init -q -b main "$P2/$a"; git -C "$P2/$a" remote add origin "https://github.com/acme/$a.git"; done
printf 'product: Mono\napps:\n  - name: api\n    path: api\n    repo_url: ""\n  - name: web\n    path: web\npackages: []\n' > "$P2/control/workspace.yaml"
prs inbox --root "$P2" > "$T/q2.json"; rc=$?
[ $rc -eq 0 ] && check "Q2 repo_url kosong → fallback remote origin" "$T/q2.json" "[(x['owner_repo'],x['repo_key']) for x in d]==[('acme/api','api'),('acme/web','web')]" || bad "Q2 exit $rc" "$(cat "$T/q2.json")"
GH_FAIL_REPO=acme/api prs siblings --root "$P" --ticket BLCS-5302 --exclude 'acme/web#99' > "$T/q3.json" 2> "$T/q3.err"; rc=$?
[ $rc -eq 0 ] && check "Q3 satu repo tak terjangkau → repo lain tetap" "$T/q3.json" "sorted(x['number'] for x in d)==[8,10]" || bad "Q3 exit $rc" "$(cat "$T/q3.json")"
grep -qF 'acme/api' "$T/q3.err" && ok "Q3 peringatan repo gagal di stderr" || bad "Q3 tanpa peringatan" "$(cat "$T/q3.err")"

# === X: perbaikan cek akhir ===
tk() { $PY -c 'import importlib.util,sys;sys.dont_write_bytecode=True;s=importlib.util.spec_from_file_location("p",sys.argv[1]);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);print(m.ticket_of(*sys.argv[2:]))' "$SK/prs.py" "$@"; }
[ "$(tk 'Handle UTF-8 BOM')" = None ] && [ "$(tk 'bump SHA-256' 'fix CVE-2024')" = None ] && ok "X1 UTF-8/SHA-256/CVE bukan tiket" || bad "X1 tiket palsu: $(tk 'Handle UTF-8 BOM')"
[ "$(tk 'feature_BLCS-12_x')" = BLCS-12 ] && [ "$(tk 'feat/TRO-5617-lanjut')" = TRO-5617 ] && ok "X2 tiket di branch ber-underscore/dash terbaca" || bad "X2 tiket branch: $(tk 'feature_BLCS-12_x')"
[ "$(tk 'UTF-8 dan BLCS-5302')" = BLCS-5302 ] && ok "X3 lewati UTF-8, ambil tiket asli" || bad "X3 $(tk 'UTF-8 dan BLCS-5302')"
GH_FAIL="HTTP 403: API rate limit exceeded for user" PATH="$GHPATH" $PY "$SK/prs.py" view --root "$P" --pr acme/api#3 > "$T/x4.json"; rc=$?
[ "$rc" -eq 1 ] && check "X4 rate limit bukan salah akun" "$T/x4.json" "d['error']=='gh-rate-limit' and 'auth switch' not in json.dumps(d)" || bad "X4 rate limit rc=$rc" "$(cat "$T/x4.json")"
GH_FAIL="To get started with GitHub CLI, please run:  gh auth login" PATH="$GHPATH" $PY "$SK/prs.py" view --root "$P" --pr acme/api#3 > "$T/x5.json"; rc=$?
[ "$rc" -eq 5 ] && check "X5 gh belum login → exit 5 + hint login" "$T/x5.json" "'gh auth login' in d['hint']" || bad "X5 belum login rc=$rc" "$(cat "$T/x5.json")"

# === lingkungan ===
[ -z "$(find "$ROOT/plugin" -name __pycache__ 2>/dev/null)" ] && ok "Z __pycache__ tak ada di plugin/" || bad "Z ada __pycache__ di plugin/"

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
