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

# === RINGKASAN ===
echo "---"; echo "pass=$PASS fail=$FAIL skip=$SKIP"
[ "$FAIL" -eq 0 ]
