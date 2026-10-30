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
case "$1 $2" in
  "search prs") cat "$GH_DIR/search.json" ;;
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

# === lingkungan ===
[ -z "$(find "$ROOT/plugin" -name __pycache__ 2>/dev/null)" ] && ok "Z __pycache__ tak ada di plugin/" || bad "Z ada __pycache__ di plugin/"

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
