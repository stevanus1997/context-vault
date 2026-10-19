#!/usr/bin/env bash
# Test skill share — assemble.py, capture.py, perilaku halaman, cek statis.
# Jalanin: bash tools/tests/share.test.sh  (exit 0 = semua lulus; bagian butuh Chrome di-skip bila Chrome tak ada)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SK="$ROOT/plugin/skills/share"
FX="$ROOT/tools/tests/fixtures/share"
PASS=0; FAIL=0; SKIP=0
ok()   { PASS=$((PASS+1)); echo "ok   - $1"; }
bad()  { FAIL=$((FAIL+1)); echo "FAIL - $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; }
skip() { SKIP=$((SKIP+1)); echo "skip - $1"; }
command -v python3 >/dev/null 2>&1 || { echo "butuh python3"; exit 1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PY="python3 -B"

# PNG 1x1 untuk gambar contoh
mkdir -p "$T/img"
$PY -c 'import base64,sys;open(sys.argv[1],"wb").write(base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="))' "$T/img/shot.png"

asm() { # asm <body> <out> [args tambahan...]
  local body="$1" out="$2"; shift 2
  $PY "$SK/assemble.py" --feature-dir "$FX/demo" --body "$body" --images "$T/img" --mode rancangan --generated 2026-10-19 --out "$out" "$@"
}
mutate() { # mutate <cari> <ganti> <out>  — salinan body-ok dengan satu penggantian (literal)
  $PY - "$FX/body-ok.html" "$1" "$2" "$3" <<'PY'
import sys
s=open(sys.argv[1],encoding='utf-8').read()
assert sys.argv[2] in s, 'pola mutasi tak ada: '+sys.argv[2]
open(sys.argv[4],'w',encoding='utf-8').write(s.replace(sys.argv[2],sys.argv[3],1))
PY
}

# === assemble ===
if asm "$FX/body-ok.html" "$T/ok.html" > "$T/ok.out" 2> "$T/ok.err"; then
  H="$(awk '{print $2}' "$T/ok.out")"
  ok "A1 rakit body-ok lolos (hash $H)"
  grep -qE '__IMG:|__MOCK:|__HASH__|__META__|__TITLE__|<!-- BODY -->|<!-- MOCKS -->' "$T/ok.html" \
    && bad "A1 masih ada placeholder" || ok "A1 semua placeholder terganti"
  grep -q 'data:image/png;base64,' "$T/ok.html" && ok "A1 gambar tersemat" || bad "A1 gambar tak tersemat"
  grep -q 'id="mock-demo-html"' "$T/ok.html" && grep -q 'data-mock="mock-demo-html"' "$T/ok.html" \
    && ok "A1 mockup tersemat + tombol menunjuk id" || bad "A1 mockup demo.html tak tersemat"
  grep -q 'id="mock-second-screen-html"' "$T/ok.html" && ok "A1 mockup bernama spasi tersemat" || bad "A1 mockup 'Second Screen.html' gagal"
  grep -q '<title>Demo: fitur contoh — Review</title>' "$T/ok.html" && ok "A1 title dari h1" || bad "A1 title salah"
  grep -q "\"revision\": 2" "$T/ok.html" && ok "A1 revisi dihitung dari kepala business.md (2)" || bad "A1 revisi bukan 2"
  grep -q "versi $H" "$T/ok.html" && ok "A1 __HASH__ di footer" || bad "A1 footer tanpa hash"
else
  bad "A1 rakit body-ok gagal" "$(cat "$T/ok.err")"; H=""
fi

H2="$(asm "$FX/body-ok.html" "$T/ok2.html" | awk '{print $2}')"
[ -n "$H" ] && [ "$H" = "$H2" ] && ok "A2 hash stabil" || bad "A2 hash tak stabil ($H vs $H2)"
HO="$($PY "$SK/assemble.py" --hash-only --feature-dir "$FX/demo")"
[ "$HO" = "$H" ] && ok "A2 --hash-only = hash rakit" || bad "A2 --hash-only beda ($HO vs $H)"

cp -R "$FX/demo" "$T/demo3"; printf ' ' >> "$T/demo3/business.md"
H3="$($PY "$SK/assemble.py" --hash-only --feature-dir "$T/demo3")"
[ "$H3" != "$H" ] && ok "A3 hash berubah saat business.md berubah" || bad "A3 hash tak berubah"

cp -R "$FX/demo" "$T/demo4"; printf 'x' > "$T/demo4/mockups/.DS_Store"; printf '# Review\n' > "$T/demo4/reviews.md"
H4="$($PY "$SK/assemble.py" --hash-only --feature-dir "$T/demo4")"
[ "$H4" = "$H" ] && ok "A4 .DS_Store & reviews.md tak mengubah hash" || bad "A4 hash berubah karena .DS_Store/reviews.md"

fails() { # fails <nama> <body> <pola-stderr>
  printf 'OLD' > "$T/f.html"
  if asm "$2" "$T/f.html" > /dev/null 2> "$T/f.err"; then bad "$1 — harusnya gagal"
  elif ! grep -q "$3" "$T/f.err"; then bad "$1 — pesan tak memuat '$3'" "$(cat "$T/f.err")"
  elif [ "$(cat "$T/f.html")" != "OLD" ]; then bad "$1 — output lama tertimpa"
  else ok "$1"; fi
}
mutate '__IMG:shot__" alt="Layar"' '__IMG:nope__" alt="Layar"' "$T/b5.html";        fails "A5 gambar hilang ditolak" "$T/b5.html" "gambar tak ada: nope"
mutate '__MOCK:demo.html__' '__MOCK:nope.html__' "$T/b6.html";                      fails "A6 mockup hilang ditolak" "$T/b6.html" "mockup tak ada: mockups/nope.html"
mutate 'data-fb="keputusan/1"' 'data-fb="cerita/1-mulai"' "$T/b7.html";             fails "A7 data-fb ganda ditolak" "$T/b7.html" "data-fb ganda"
mutate '#35;1 siap' '#1 siap' "$T/b8.html";                                         fails "A8 #angka di Mermaid ditolak" "$T/b8.html" "#35;1"
mutate '"Meja #35;1 siap"' 'baris1\nbaris2' "$T/b9.html";                           fails "A9 \\n di label Mermaid ditolak" "$T/b9.html" "pakai <br/>"
mutate 'class="lede"' 'class="lede label"' "$T/b10.html";                           fails "A10 kelas label ditolak" "$T/b10.html" 'kelas "label"'
mutate 'versi __HASH__' 'versi __FOO__' "$T/b11.html";                              fails "A11 placeholder tak dikenal ditolak" "$T/b11.html" "placeholder tak dikenal: __FOO__"
mkdir -p "$T/nobiz"; printf 'OLD' > "$T/f.html"
if $PY "$SK/assemble.py" --feature-dir "$T/nobiz" --body "$FX/body-ok.html" --mode rancangan --out "$T/f.html" 2> "$T/f.err"; then bad "A12 tanpa business.md harusnya gagal"
else grep -q 'business.md tak ada' "$T/f.err" && ok "A12 tanpa business.md ditolak" || bad "A12 pesan salah" "$(cat "$T/f.err")"; fi

# === capture ===
MOCK="$FX/demo/mockups/demo.html"
SUM0="$(shasum "$MOCK" | awk '{print $1}')"; LS0="$(ls -a "$FX/demo/mockups")"
SHARE_CHROME=/nonexistent/chrome $PY "$SK/capture.py" --mockup "$MOCK" --out "$T/cap" --name x --select '#f1 .frame' >/dev/null 2>&1
[ $? -eq 3 ] && ok "C6 Chrome tak ada → exit 3" || bad "C6 exit code bukan 3"
CHROME="$($PY "$SK/capture.py" --find-chrome 2>/dev/null || true)"
HAS_PIL="$($PY -c 'import PIL' 2>/dev/null && echo 1 || echo 0)"
imgw() { $PY - "$1" <<'PY'
import sys,struct
p=sys.argv[1]
try:
    from PIL import Image; print(Image.open(p).size[0])
except ImportError:
    b=open(p,'rb').read(24); print(struct.unpack('>I',b[16:20])[0] if b[:8]==b'\x89PNG\r\n\x1a\n' else 0)
PY
}
if [ -z "$CHROME" ]; then
  skip "C1–C9 capture (Chrome tak ditemukan)"
else
  ok "C7 --find-chrome → $CHROME"
  O1="$($PY "$SK/capture.py" --mockup "$MOCK" --out "$T/cap" --name f1 --select '#f1 .frame' --device tablet 2>"$T/c.err")"
  if [ -s "$O1" ]; then
    ok "C1 selector statis → $(basename "$O1")"
    if [ "$HAS_PIL" = 1 ]; then W="$(imgw "$O1")"; [ "$W" = 600 ] && ok "C1 dipangkas ke lebar frame (600)" || bad "C1 lebar $W, harusnya 600"; fi
  else bad "C1 tak ada hasil" "$(cat "$T/c.err")"; fi
  O2="$($PY "$SK/capture.py" --mockup "$MOCK" --out "$T/cap" --name f2 --select '#f2 .phone' --device phone 2>"$T/c.err")"
  if [ -s "$O2" ]; then
    W="$(imgw "$O2")"; [ "$W" -gt 0 ] && [ "$W" -le 420 ] && ok "C2 ponsel lebar $W ≤ 420" || bad "C2 lebar ponsel $W"
  else bad "C2 tak ada hasil" "$(cat "$T/c.err")"; fi
  $PY "$SK/capture.py" --mockup "$MOCK" --out "$T/cap" --name nope --select '#nope' >/dev/null 2>"$T/c.err"; RC=$?
  [ $RC -eq 4 ] && [ ! -e "$T/cap/nope.jpg" ] && [ ! -e "$T/cap/nope.png" ] && ok "C3 selector tak ketemu → exit 4, tanpa berkas" || bad "C3 rc=$RC" "$(cat "$T/c.err")"
  O4="$($PY "$SK/capture.py" --mockup "$MOCK" --out "$T/cap" --name stb --hash b --device tablet 2>"$T/c.err")"
  [ -s "$O4" ] && ok "C4 mode hash → berkas ada" || bad "C4 mode hash gagal" "$(cat "$T/c.err")"
  [ "$(shasum "$MOCK" | awk '{print $1}')" = "$SUM0" ] && [ "$(ls -a "$FX/demo/mockups")" = "$LS0" ] \
    && ok "C5 mockup asli utuh, nol berkas sementara di folder mockup" || bad "C5 mockup/folder berubah"
  if [ "$HAS_PIL" = 1 ]; then
    $PY "$SK/capture.py" --mockup "$MOCK" --out "$T/cap" --name blank --select '#blank' >/dev/null 2>"$T/c.err"; RC=$?
    [ $RC -eq 1 ] && grep -q 'tangkapan kosong' "$T/c.err" && ok "C8 tangkapan putih → exit 1 'tangkapan kosong'" || bad "C8 rc=$RC" "$(cat "$T/c.err")"
    O9="$($PY "$SK/capture.py" --mockup "$MOCK" --out "$T/cap" --name f1h --select '#f1 .frame' --hide '.fold' 2>/dev/null)"
    RED() { $PY - "$1" <<'PY'
import sys
from PIL import Image
im=Image.open(sys.argv[1]).convert('RGB')
d=im.tobytes(); print(sum(1 for i in range(0,len(d),3) if d[i]>200 and d[i+1]<80 and d[i+2]<80))
PY
}
    R1="$(RED "$O1")"; R9="$(RED "$O9")"
    [ "$R1" -gt 50 ] && [ "$R9" -lt 10 ] && ok "C9 --hide menyembunyikan garis (merah $R1 → $R9)" || bad "C9 --hide tak bekerja (merah $R1 → $R9)"
  else
    skip "C8/C9 butuh Pillow"
  fi
fi

# === halaman ===
if [ -z "${CHROME:-}" ]; then
  skip "P1–P2 halaman (Chrome tak ditemukan)"
else
  asm "$FX/body-ok.html" "$T/page.html" > "$T/pg.out" 2>&1 || bad "P0 rakit halaman gagal" "$(cat "$T/pg.out")"
  HP="$(awk '{print $2}' "$T/pg.out")"
  page_test() { # page_test <out-html> <blokir-storage 0|1>
    $PY - "$T/page.html" "$1" "$2" <<'PY'
import sys
s=open(sys.argv[1],encoding='utf-8').read()
block = sys.argv[3]=='1'
pre = "<script>Object.defineProperty(window,'localStorage',{get(){throw new Error('blocked')}});</script>" if block else ''
T = '''<script>
window.addEventListener('load',()=>setTimeout(()=>{
 const R={};
 const pick=v=>document.querySelector('.opt[data-val="'+v+'"] .pick').click();
 const comment=(id,text,act)=>{const b=[...document.querySelectorAll('.fb-btn')].find(x=>x.dataset.for===id);b.click();const box=document.querySelector('.fb-box.open');box.querySelector('textarea').value=text;box.querySelector('[data-act="'+(act||'ok')+'"]').click();};
 pick('A');pick('B');R.radio=[...document.querySelectorAll('.opt.sel')].map(o=>o.dataset.val).join(',');
 comment('pilihan/layout','B lebih enak');
 comment('cerita/1-mulai','Langkah ini jelas\\nTapi <b>tombol</b> "kecil" | ya');
 comment('keputusan/1','hapus nanti');comment('keputusan/1','','del');
 document.getElementById('fb-name').value='Tester';
 R.count=document.getElementById('fb-count').textContent;
 R.key=window.__shareKey;
 R.text=window.__shareBuildText();
 R.injected=!!document.querySelector('.fb-box b');
 comment('pilihan/layout','','del');
 const t2=window.__shareBuildText();R.afterDel=t2.includes('pilih: B')&&!t2.includes('B lebih enak');
 pick('B');R.unpick=document.querySelectorAll('.opt.sel').length;
 const pre=document.createElement('pre');pre.id='OUT';pre.textContent=JSON.stringify(R);document.body.appendChild(pre);
},300));
</script>'''
s=s.replace('<head>','<head>'+pre,1)
i=s.rfind('</body>');open(sys.argv[2],'w',encoding='utf-8').write(s[:i]+T+s[i:])
PY
  }
  check_page() { # check_page <nama> <html>
    "$CHROME" --headless=new --disable-gpu --no-first-run --user-data-dir="$T/prof-$1" --virtual-time-budget=5000 --dump-dom "file://$2" 2>/dev/null > "$T/dom-$1.html"
    $PY - "$T/dom-$1.html" "$HP" "$1" <<'PY'
import sys,re,json,html
d=open(sys.argv[1],encoding='utf-8').read(); h=sys.argv[2]; name=sys.argv[3]
m=re.search(r'<pre id="OUT">(.*?)</pre>',d,re.S)
if not m: print('FAIL - %s: hasil uji tak muncul (JS error?)'%name); sys.exit(1)
R=json.loads(html.unescape(m.group(1)))
exp='\n'.join(['=== FEEDBACK share:demo ===','versi: rancangan · revisi 2 · 2026-10-19 · '+h,'reviewer: Tester','---',
 '[pilihan/layout] Tata letak (A/B)','sumber: plans/app.md#Layout','pilih: B','> B lebih enak','---',
 '[cerita/1-mulai] Pengguna mulai','sumber: business.md#Flow 1','> Langkah ini jelas','> Tapi <b>tombol</b> "kecil" | ya','=== END ==='])
checks=[('radio: A lalu B → cuma B',R['radio']=='B'),('jumlah komentar 2',R['count']=='2'),
 ('kunci storage memuat hash',R['key']=='share-fb:demo:'+h),('blok feedback persis format',R['text']==exp),
 ('komentar tak jadi HTML',not R['injected']),('hapus komentar grup, pilihan tetap',R['afterDel']),
 ('klik pilihan yang sama = batal',R['unpick']==0)]
bad=0
for n,c in checks:
    print(('ok   - ' if c else 'FAIL - ')+name+' '+n); bad+=0 if c else 1
if R['text']!=exp: print('      dapat:\n'+R['text'])
sys.exit(1 if bad else 0)
PY
  }
  page_test "$T/p1.html" 0
  if check_page P1 "$T/p1.html" > "$T/p1.res"; then ok "P1 perilaku halaman"; else bad "P1 perilaku halaman" "$(cat "$T/p1.res")"; fi
  page_test "$T/p2.html" 1
  if check_page P2 "$T/p2.html" > "$T/p2.res"; then ok "P2 localStorage diblokir → tetap jalan"; else bad "P2 localStorage diblokir" "$(cat "$T/p2.res")"; fi
fi

# === statis ===
SKMD="$SK/SKILL.md"
if [ -f "$SKMD" ] && [ "$(head -1 "$SKMD")" = "---" ] && sed -n '2,5p' "$SKMD" | grep -qx 'name: share' \
   && sed -n '2,6p' "$SKMD" | grep -q '^description: .\{40,\}'; then ok "S1 frontmatter SKILL.md"; else bad "S1 frontmatter SKILL.md (name: share + description)"; fi
grep -qi 'subagent' "$SKMD" 2>/dev/null && bad "S2 SKILL.md memuat 'subagent' (memicu pointer kimi)" || ok "S2 SKILL.md tanpa 'subagent'"
grep -l 'CLAUDE_PLUGIN_ROOT' "$SK"/*.py "$SK"/*.html 2>/dev/null | grep -q . && bad "S3 residu CLAUDE_PLUGIN_ROOT di .py/.html" || ok "S3 nol CLAUDE_PLUGIN_ROOT di .py/.html"
for f in assemble capture; do $PY -c 'import ast,sys;ast.parse(open(sys.argv[1]).read())' "$SK/$f.py" && ok "S4 $f.py sintaks valid" || bad "S4 $f.py sintaks"; done
for slot in '__TITLE__' '__META__' '<!-- BODY -->' '<!-- MOCKS -->'; do
  n="$(grep -o -F "$slot" "$SK/template.html" | wc -l | tr -d ' ')"; [ "$n" = 1 ] && ok "S5 slot $slot tepat 1x" || bad "S5 slot $slot muncul ${n}x"; done
for f in reference.md template.html capture.py assemble.py; do
  grep -q "$f" "$SKMD" 2>/dev/null && ok "S6 SKILL.md menyebut $f" || bad "S6 SKILL.md tak menyebut $f"; done
find "$ROOT/plugin" -name __pycache__ | grep -q . && bad "S7 ada __pycache__ di plugin/" || ok "S7 nol __pycache__ di plugin/"
# Cuplikan katalog reference.md (blok ```html … ```) dirakit bareng harus lolos validasi
$PY - "$SK/reference.md" "$T/ref-body.html" <<'PY'
import re,sys
s=open(sys.argv[1],encoding='utf-8').read()
blocks=re.findall(r'```html\n(.*?)```',s,re.S)
body='\n'.join(blocks)
body=re.sub(r'__MOCK:[^"<>]+?__','__MOCK:demo.html__',body)
open(sys.argv[2],'w',encoding='utf-8').write(body)
PY
for n in $(grep -o '__IMG:[A-Za-z0-9_.-]*__' "$T/ref-body.html" | sed 's/__IMG:\(.*\)__/\1/' | sort -u); do cp "$T/img/shot.png" "$T/img/$n.png"; done
if asm "$T/ref-body.html" "$T/ref.html" > /dev/null 2> "$T/ref.err"; then ok "S8 semua cuplikan katalog reference.md lolos validasi"; else bad "S8 cuplikan reference.md gagal validasi" "$(cat "$T/ref.err")"; fi

# === RINGKASAN ===
echo "---"; echo "pass=$PASS fail=$FAIL skip=$SKIP"
[ "$FAIL" -eq 0 ]
