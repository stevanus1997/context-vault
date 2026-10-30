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

# === M: range, markers, unmark ===
PM="$T/pm"; mkprod "$PM"; ss init --root "$PM" > /dev/null
remote_commit "$PM" api alice "feat: x (#12)"
remote_commit "$PM" api ci-bot "chore: bump"
git -C "$PM/api" fetch -q
ss range --root "$PM" --repo api > "$T/m1.json"; rc=$?
[ $rc -eq 0 ] && ok "M1 range exit 0" || bad "M1 range exit $rc"
check "M1 2 commit urut lama→baru" "$T/m1.json" "[c['subject'] for c in d['commits']]==['feat: x (#12)','chore: bump']"
check "M1 commit #12: pr 12, bot false, own false" "$T/m1.json" "d['commits'][0]['pr']==12 and d['commits'][0]['bot'] is False and d['commits'][0]['own'] is False and d['commits'][0]['author']=='alice'"
check "M1 commit bot: bot true, pr null" "$T/m1.json" "d['commits'][1]['bot'] is True and d['commits'][1]['pr'] is None"
check "M1 from/to/short/date" "$T/m1.json" "d['repo']=='api' and d['to']=='$(remote_head "$PM" api)' and d['commits'][1]['sha']==d['to'] and d['commits'][0]['short']==d['commits'][0]['sha'][:7] and d['commits'][0]['date']=='$TODAY' and d['fetch_error'] is None"
mkdir -p "$PM/control/features/f1"
printf 'name: f1\nstatus: shipped\nprs: ["api#12"]\n' > "$PM/control/features/f1/feature.yaml"
ss range --root "$PM" --repo api > "$T/m2.json"
check "M2 commit #12 own (feature.yaml prs)" "$T/m2.json" "d['commits'][0]['own'] is True and d['commits'][1]['own'] is False"
remote_commit "$PM" api alice "fix: y (#13)"; git -C "$PM/api" fetch -q
mkdir -p "$PM/control/fixes/x1"
printf 'id: x1\nstatus: shipped\nfix_pr: "https://github.com/acme/api/pull/13"\n' > "$PM/control/fixes/x1/fix.yaml"
ss range --root "$PM" --repo api > "$T/m2b.json"
check "M2 commit #13 own (fix.yaml fix_pr URL)" "$T/m2b.json" "d['commits'][2]['pr']==13 and d['commits'][2]['own'] is True"
git -C "$PM/api" remote set-url origin /nope
ss range --root "$PM" --repo api --fetch > "$T/m3.json"; rc=$?
[ $rc -eq 0 ] && ok "M3 range --fetch remote rusak exit 0" || bad "M3 exit $rc"
check "M3 fetch_error terisi, commits tetap" "$T/m3.json" "d['fetch_error'] is not None and len(d['commits'])==3"
mkdir -p "$PM/control/business" "$PM/control/features/f2"
printf '# Flows\n\n- Reschedule maks 3x <!-- feature:f2 -->\n- Aturan lama\n' > "$PM/control/business/flows.md"
$PY - "$PM/control/workspace.yaml" <<'PY2'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace('      - jadwal\n', '      - jadwal\n      - survey-reschedule # feature:f2\n')
open(p, 'w').write(s)
PY2
printf 'name: f2\nstatus: active\n' > "$PM/control/features/f2/feature.yaml"
printf 'catatan <!-- feature:f2 -->\n' > "$PM/control/features/f2/business.md"
ss markers --root "$PM" --status active,draft > "$T/m4.json"
check "M4 2 penanda f2 aktif (features/** tak dipindai)" "$T/m4.json" "len(d)==2 and all(m['feature']=='f2' and m['status']=='active' for m in d)"
check "M4 file/line/text" "$T/m4.json" "sorted((m['file'],m['line']) for m in d)==[('control/business/flows.md',3),('control/workspace.yaml',9)] and any(m['text']=='- Reschedule maks 3x' for m in d)"
ss markers --root "$PM" --feature f1 > "$T/m4b.json"
check "M4 --feature f1 → []" "$T/m4b.json" "d==[]"
ss markers --root "$PM" --status shipped > "$T/m4c.json"
check "M4 --status shipped → []" "$T/m4c.json" "d==[]"
ss unmark --root "$PM" --feature f2 > "$T/m5.json"
check "M5 removed 2" "$T/m5.json" "d['removed']==2"
grep -qxF -- '- Reschedule maks 3x' "$PM/control/business/flows.md" && ok "M5 teks aturan utuh tanpa token" || bad "M5 flows.md" "$(cat "$PM/control/business/flows.md")"
grep -qxF '      - survey-reschedule' "$PM/control/workspace.yaml" && ok "M5 capability utuh tanpa komentar" || bad "M5 workspace.yaml" "$(cat "$PM/control/workspace.yaml")"
parse_ok "$PM/control/workspace.yaml" && ok "M5 workspace.yaml tetap valid" || bad "M5 workspace.yaml rusak"
grep -q 'feature:f2' "$PM/control/features/f2/business.md" && ok "M5 features/** tak disentuh" || bad "M5 features/** ikut di-unmark"

# === T: penanda fitur (statis) ===
FM="$ROOT/plugin/rules/feature-marker.md"
[ -f "$FM" ] && grep -qF '<!-- feature:<fitur> -->' "$FM" && grep -qF '# feature:<fitur>' "$FM" \
  && ok "T1 rules/feature-marker.md + dua bentuk penanda" || bad "T1 rules/feature-marker.md"
for s in intake fanout ship drop; do
  grep -qE 'rules/feature-marker\.md|sync_status\.py' "$ROOT/plugin/skills/$s/SKILL.md" \
    && ok "T2 $s merujuk penanda" || bad "T2 $s tanpa rujukan penanda"; done
grep -qF 'prs: ["<repo-key>#<nomor>"' "$ROOT/plugin/skills/ship/SKILL.md" && ok "T3 ship mencatat prs" || bad "T3 ship tanpa prs"
grep -qF '"<repo-key>#<nomor>"' "$ROOT/plugin/skills/fix/reference.md" && ok "T3 fix_pr berformat repo-key#nomor" || bad "T3 fix/reference.md fix_pr"

# === R: ringkasan sinkron (assemble.py) ===
mut() { # mut <out.json> <kode python atas d>  — salinan summary-ok.json yang diubah
  $PY - "$FX/summary-ok.json" "$1" "$2" <<'PY2'
import json, sys
d = json.load(open(sys.argv[1], encoding='utf-8'))
exec(sys.argv[3])
json.dump(d, open(sys.argv[2], 'w', encoding='utf-8'), ensure_ascii=False)
PY2
}
asm() { $PY "$SK/assemble.py" --data "$1" --out "$2"; }
if asm "$FX/summary-ok.json" "$T/r1.html" > "$T/r1.out" 2> "$T/r1.err"; then ok "R1 fixture lolos"
  grep -qxF "$T/r1.html" "$T/r1.out" && ok "R1 cetak path output" || bad "R1 stdout" "$(cat "$T/r1.out")"
  for s in '5 hal baru sejak 21 Oktober' '2×' '3×' 'createDatasource()' 'Fitur baru' 'Aturan bisnis berubah' 'Aturan coding baru' \
           '47 commit masuk di 6 repo' 'cuma bot' '37 commit lain cuma bot, refactor, atau fix kecil' '/add-app' 'invariants.md' 'Ditulis ke control/'; do
    grep -qF -- "$s" "$T/r1.html" && ok "R1 memuat '$s'" || bad "R1 tanpa '$s'"; done
  grep -q '__' "$T/r1.html" && bad "R1 masih ada placeholder __" "$(grep -o '.\{20\}__.\{20\}' "$T/r1.html" | head -3)" || ok "R1 tanpa placeholder __"
  grep -qF 'Bentrok sama fitur lo' "$T/r1.html" && bad "R1 kartu bentrok muncul padahal kosong" || ok "R1 tanpa kartu bentrok"
else bad "R1 assemble gagal" "$(cat "$T/r1.err")"; fi
mut "$T/r2.json" "d['coding_rules']=[]"; asm "$T/r2.json" "$T/r2.html" >/dev/null 2>&1
grep -qF 'Aturan coding baru' "$T/r2.html" && bad "R2 kolom kosong tetap dirender" || ok "R2 kolom kosong tidak dirender"
grep -qF '4 hal baru sejak' "$T/r2.html" && ok "R2 N ikut berkurang" || bad "R2 N salah"
mut "$T/r2b.json" "d['features']=[]; d['business_rules']=[]; d['coding_rules']=[]"; asm "$T/r2b.json" "$T/r2b.html" >/dev/null 2>&1
grep -qF 'Nggak ada hal baru sejak 21 Oktober' "$T/r2b.html" && ok "R2 semua kosong → Nggak ada hal baru" || bad "R2 judul kosong"
mut "$T/r2c.json" "d['since']='2025-12-30'; d['repos']=[]; d['written']=[]; d['pointers']=[]; d.pop('other_commits')"
asm "$T/r2c.json" "$T/r2c.html" >/dev/null 2>&1 && grep -qF 'sejak 30 Desember 2025' "$T/r2c.html" \
  && ok "R2 tahun beda → tanggal pakai tahun; kunci opsional absen tetap lolos" || bad "R2 tanggal lintas tahun / opsional"
mut "$T/r3.json" "d['features'][0]['text']='<script>alert(1)</script> & </textarea>'; d['repos'][0]['label']='<b>x</b>'"
asm "$T/r3.json" "$T/r3.html" >/dev/null 2>&1
grep -qF '&lt;script&gt;alert(1)&lt;/script&gt; &amp; &lt;/textarea&gt;' "$T/r3.html" && ! grep -qF '<script>alert' "$T/r3.html" \
  && ! grep -qF '<b>x</b>' "$T/r3.html" && ok "R3 teks ter-escape" || bad "R3 escape"
mut "$T/r4.json" "d.pop('since')"; asm "$T/r4.json" "$T/r4.html" >/dev/null 2>&1; rc=$?
[ $rc -eq 1 ] && [ ! -e "$T/r4.html" ] && ok "R4 tanpa since → exit 1, output tak dibuat" || bad "R4 rc=$rc"
printf '{rusak' > "$T/r4b.json"; asm "$T/r4b.json" "$T/r4b.html" >/dev/null 2>&1; rc=$?
[ $rc -eq 1 ] && [ ! -e "$T/r4b.html" ] && ok "R4 JSON rusak → exit 1" || bad "R4 JSON rusak rc=$rc"
$PY "$SK/assemble.py" --data "$FX/summary-ok.json" >/dev/null 2>&1; rc=$?
[ $rc -eq 2 ] && ok "R4 argumen kurang → exit 2" || bad "R4 argumen rc=$rc"
mut "$T/r5.json" "d['conflicts']=[{'feature':'df4w-credit-task-detail','file':'business/flows.md','master':'maks 3x','yours':'maks 5x'}]"
asm "$T/r5.json" "$T/r5.html" >/dev/null 2>&1
grep -qF 'Bentrok sama fitur lo' "$T/r5.html" && grep -qF 'df4w-credit-task-detail' "$T/r5.html" && grep -qF 'maks 5x' "$T/r5.html" \
  && ok "R5 kartu bentrok + nama fitur" || bad "R5 bentrok"

# === K: skill sync + agent sync-reader (statis) ===
SM="$SK/SKILL.md"; AG="$ROOT/plugin/agents/sync-reader.md"
[ "$(sed -n 2p "$SM" 2>/dev/null)" = "name: sync" ] && ok "K1 frontmatter name: sync" || bad "K1 frontmatter"
for s in sync_status.py context-vault:sync-reader assemble.py advance feature-marker.md AskUserQuestion 'init --force --only' 'range' '--fetch' 'need_base'; do
  grep -qF -- "$s" "$SM" 2>/dev/null && ok "K2 SKILL.md memuat $s" || bad "K2 SKILL.md tanpa $s"; done
[ -f "$SK/reference.md" ] && grep -qF '"summary_item"' "$SK/reference.md" && grep -qF '"business_rules"' "$SK/reference.md" \
  && ok "K2 reference.md: skema usulan tulis + ringkasan" || bad "K2 reference.md"
[ -f "$AG" ] && grep -qxF 'tools: Read, Bash' "$AG" && grep -qF 'SendMessage' "$AG" && ok "K3 agent sync-reader" || bad "K3 agent sync-reader"
grep -qF 'CLAUDE_PLUGIN_ROOT' "$SK"/*.py "$SK"/*.html && bad "K4 CLAUDE_PLUGIN_ROOT di script/template sync" || ok "K4 tanpa CLAUDE_PLUGIN_ROOT di .py/.html"

# === lingkungan ===
[ -z "$(find "$ROOT/plugin" -name __pycache__ 2>/dev/null)" ] && ok "Z __pycache__ tak ada di plugin/" || bad "Z ada __pycache__ di plugin/"

# === RINGKASAN ===
echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
