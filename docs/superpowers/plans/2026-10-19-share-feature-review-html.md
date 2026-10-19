# `share` — File HTML Review Fitur — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Skill baru `share` di plugin context-vault. Skill ini menghasilkan satu file `share.html` per fitur yang bisa dikirim ke rekan (storyboard tangkapan layar mockup, keputusan, diagram, 💬 + Copy feedback), dan mentriase blok feedback yang dikirim balik.

**Architecture:** Claude menulis *isi* halaman (body HTML dari katalog komponen tetap). Kerja mekanis dikerjakan dua script stdlib Python yang ikut di folder skill:
- `capture.py`: tangkap layar frame mockup lewat headless Chrome
- `assemble.py`: tempel body ke `template.html`, sematkan gambar & mockup base64, hitung hash versi, validasi

`feature` (langkah 4) dan `ship` (langkah 6) memanggil skill ini. Kegagalannya tidak pernah menghalangi.

**Tech Stack:** Markdown skill (Claude Code plugin) · Python 3 stdlib (Pillow opsional) · Google Chrome/Chromium headless · HTML/CSS/JS vanilla · Mermaid 11.4.1 via jsDelivr · test bash (`tools/tests/*.test.sh`, pola counter PASS/FAIL).

**Spec:** `docs/superpowers/specs/2026-10-19-share-feature-review-html-design.md`. Baca dulu: plan ini berargumen dari spec itu.

## Global Constraints

- Nama skill `share`, folder `plugin/skills/share/` berisi `SKILL.md`, `reference.md`, `template.html`, `capture.py`, `assemble.py`.
- Output `control/features/<f>/share.html` (di-gitignore). Log triase `control/features/<f>/reviews.md` (di-commit). Scratch `.claude/share/<f>/` (di-gitignore).
- Mermaid persis `https://cdn.jsdelivr.net/npm/mermaid@11.4.1/dist/mermaid.min.js`.
- Kunci localStorage komentar: `share-fb:<fitur>:<hash>`. Nama reviewer: `share-fb:name`.
- Hash versi = 8 heksa pertama SHA-256 atas `business.md`, `fanout.md`, `plans/*.md`, `mockups/*` (urut nama, dotfile diabaikan). `reviews.md` TIDAK ikut.
- Format blok feedback (kontrak triase) persis:
  ```
  === FEEDBACK share:<fitur> ===
  versi: <rancangan|dibangun> · revisi <n> · <YYYY-MM-DD> · <hash>
  reviewer: <nama | (tanpa nama)>
  ---
  [<bagian>/<id>] <judul>
  sumber: <data-src>
  pilih: <opsi>
  > <baris komentar>
  === END ===
  ```
- **Nol string `CLAUDE_PLUGIN_ROOT`** di `.py`/`.html` skill ini. Script menemukan saudaranya lewat `__file__`. `tools/build-kimi.sh` cuma me-rewrite `.md` dan self-check-nya gagal bila ada residu.
- `SKILL.md` share **jangan memuat kata "subagent"**. Generator kimi menyisipkan pointer harness ke SKILL.md yang memuatnya, dan skill ini tidak men-dispatch subagent.
- Jangan biarkan `__pycache__` muncul di `plugin/`, karena ikut tersalin ke `plugin-kimi/`. Test memanggil script sebagai proses (`python3 -B …`), bukan `import`.
- Bahasa dokumen & pesan: Indonesia (santai di SKILL/reference, sesuai skill lain). Commit tanpa trailer `Co-Authored-By`.
- Kegagalan `share` saat dipanggil `feature`/`ship` = catatan, **bukan** penghalang.

## Review Focus

1. **Finder macOS menaruh `.DS_Store` di `mockups/`, dan user mencatat triase ke `reviews.md`.** Keduanya tidak boleh mengganti hash versi (kalau berganti, komentar rekan "hilang" walau rancangan tak berubah). Pin: Task 1 test A4.
2. **Selector ketemu tapi elemennya belum tergambar / putih semua.** `capture.py` harus gagal keras (exit 1 "tangkapan kosong"), bukan menyerahkan JPEG putih yang lalu tampil sebagai kotak kosong di storyboard. Pin: Task 2 test C8.
3. **localStorage diblokir** (file:// di mode privat / browser ketat). Halaman tetap jalan, dan pilihan + komentar tetap bisa di-Copy selama tab terbuka. Pin: Task 3 test P2.
4. **Komentar multi-baris / berisi `<`, `"`, `|`.** Tiap baris jadi `> …` sendiri, tanpa injeksi HTML. Pin: Task 3 test P1 (komentar 2 baris berisi `<b>`).
5. **Nama berkas mockup berspasi / huruf besar** (`Second Screen.html`). `__MOCK:` tetap tersemat dengan id yang aman. Pin: Task 1 test A1 (fixture memuat `Second Screen.html`).

---

## File Structure

| Path | Tanggung jawab |
|---|---|
| `plugin/skills/share/template.html` | Kerangka halaman v4: CSS, JS (💬, pilihan, Copy feedback, lightbox, tab, mockup, Mermaid). Slot `__TITLE__`, `__META__`, `<!-- BODY -->`, `<!-- MOCKS -->`. |
| `plugin/skills/share/assemble.py` | Rakit + hash + validasi. CLI `--hash-only` untuk triase. |
| `plugin/skills/share/capture.py` | Cari Chrome, isolasi frame, screenshot, pangkas (Pillow opsional). |
| `plugin/skills/share/SKILL.md` | Alur mode Generate & Triase, guardrails. |
| `plugin/skills/share/reference.md` | Sumber per bagian, aturan bahasa, strategi tangkap, katalog komponen, Mermaid, format feedback & `reviews.md`, mode dibangun, pemeriksaan visual. |
| `tools/tests/share.test.sh` | Satu runner: bagian assemble, capture, halaman, statis. |
| `tools/tests/fixtures/share/demo/…` | Fitur mini untuk test (business.md "Revisi 2", plan, 2 mockup). |
| `tools/tests/fixtures/share/body-ok.html` | Body contoh yang lolos validasi. |
| `plugin/skills/feature/SKILL.md`, `plugin/skills/ship/SKILL.md` | Panggil `share`. |
| `plugin/skills/init/SKILL.md`, `plugin/skills/upgrade/SKILL.md` | Baris `.gitignore`. |
| `plugin/skills/guide/reference.md`, `README.md` | Cheatsheet/katalog. |
| `plugin-kimi/` | Regenerate. |

---

### Task 1: Template halaman + `assemble.py`

**Files:**
- Create: `plugin/skills/share/template.html`
- Create: `plugin/skills/share/assemble.py`
- Create: `tools/tests/fixtures/share/demo/feature.yaml`, `…/demo/business.md`, `…/demo/plans/app.md`, `…/demo/mockups/demo.html`, `…/demo/mockups/Second Screen.html`
- Create: `tools/tests/fixtures/share/body-ok.html`
- Create: `tools/tests/share.test.sh`

**Interfaces:**
- Produces:
  - `assemble.py --feature-dir DIR --body FILE --mode rancangan|dibangun --out FILE [--images DIR] [--revision N] [--generated YYYY-MM-DD]` → stdout `ok <hash> <bytes> <out>`, exit 0. Validasi gagal → `error: …` per baris di stderr, exit 1, output tak ditulis (file lama utuh). Argumen salah → exit 2.
  - `assemble.py --hash-only --feature-dir DIR` → stdout `<hash>`.
  - Template slot: `__TITLE__`, `__META__` (JSON `{feature, mode, revision, generated, hash}`), `<!-- BODY -->`, `<!-- MOCKS -->`.
  - Placeholder body: `__IMG:<nama>__` (dicari `<nama>.jpg|.jpeg|.png|.webp|.gif` di `--images`), `__MOCK:<berkas>__` (berkas di `mockups/`, diganti id `mock-<slug>`), `__HASH__`.
  - JS halaman: `window.__shareKey` (string kunci storage), `window.__shareBuildText()` (string blok feedback).

- [ ] **Step 1: Buat fixture fitur demo**

`tools/tests/fixtures/share/demo/feature.yaml`:
```yaml
name: demo
status: active
created: 2026-10-19
sensitivity: []
epic: ""
depends_on: []
risk: normal
```

`tools/tests/fixtures/share/demo/business.md`:
```markdown
# demo — Business Spec

> Revisi 2 (intake ulang 2026-10-19): tombol dibesarin.
>
> Revisi 1: versi awal.

Tujuan       : Pengguna bisa mulai lebih cepat.
Flow/Skenario:
  1. Pengguna buka app → tap Mulai.
Keputusan:
  1. Siapa yang nyalain? Owner.
  2. Tombol dibesarin.
```

`tools/tests/fixtures/share/demo/plans/app.md`:
```markdown
# app

Layout: SATU dari 2 opsi (A kartu / B daftar), dipilih user di gate.
Alur: Pengguna → App.
```

`tools/tests/fixtures/share/demo/mockups/demo.html`:
```html
<!doctype html><html><head><meta charset="utf-8"><title>demo mockup</title>
<style>
body{margin:0;background:#f5f2ea;font:14px sans-serif}
.pg{padding:30px}
.frame{width:600px;height:300px;background:#1f6f5c;color:#fff;position:relative}
.phone{width:300px;height:500px;background:#a4580f;color:#fff}
.fold{position:absolute;left:0;right:0;top:250px;border-top:3px dashed #ff0000}
.state{display:none;width:400px;height:200px;background:#333;color:#fff}
.state.on{display:block}
#blank{width:100px;height:100px;background:#fff}
</style></head><body>
<svg style="display:none"><symbol id="i-dot" viewBox="0 0 10 10"><circle cx="5" cy="5" r="4"/></symbol></svg>
<div class="pg">
<h1>Demo mockup</h1>
<section id="f1"><div class="frame">Frame satu <svg width="20" height="20"><use href="#i-dot"/></svg><div class="fold"></div></div></section>
<figure id="f2"><div class="phone">Ponsel dua</div></figure>
<div id="blank"></div>
<div class="state" id="st-a">State A</div><div class="state" id="st-b">State B</div>
</div>
<script>
function route(){document.querySelectorAll('.state').forEach(function(s){s.classList.toggle('on','#'+s.id.slice(3)===location.hash)})}
window.addEventListener('hashchange',route);route();
</script>
</body></html>
```

`tools/tests/fixtures/share/demo/mockups/Second Screen.html` (nama berspasi, Review Focus 5):
```html
<!doctype html><html><head><meta charset="utf-8"><title>second</title></head><body><p>Layar kedua</p></body></html>
```

- [ ] **Step 2: Buat body contoh yang lolos validasi**

`tools/tests/fixtures/share/body-ok.html`:
```html
<header class="hero">
  <div class="eyebrow">Review rancangan · sebelum dibangun · revisi 2</div>
  <h1>Demo: fitur contoh</h1>
  <p class="lede">Satu kalimat.</p>
  <div class="ask">👀 <span><b>Yang gw minta:</b> klik <b>💬</b>.</span></div>
</header>
<h2 class="h" style="margin-top:28px">Masukan kemarin → jadinya</h2>
<div class="chg">
  <div class="chg-row" data-fb="berubah/tombol" data-src="business.md#Keputusan 2"><span class="from">"tombolnya kekecilan"</span><span class="arr">→</span><span class="to">Tombol dibesarin.</span><a href="#s1">lihat ①</a></div>
</div>
<h2 class="h">Ceritanya</h2>
<div class="story">
  <div class="step" id="s1" data-fb="cerita/1-mulai" data-src="business.md#Flow 1">
    <div class="txt"><span class="num">1</span><span class="time">10.00</span><h3>Pengguna mulai</h3><p>Keterangan.</p></div>
    <img class="shot" src="__IMG:shot__" alt="Layar">
  </div>
</div>
<h2 class="h" id="pilih">Pilih satu: tata letak</h2>
<div class="opts" data-choice="pilihan/layout" data-fb="pilihan/layout" data-title="Tata letak (A/B)" data-src="plans/app.md#Layout">
  <div class="opt" data-val="A"><img class="shot" src="__IMG:shot__" alt="A"><h3>A · Kartu</h3><p class="pro">Plus</p><p class="con">Minus</p><button class="btn pick">Pilih A</button></div>
  <div class="opt" data-val="B"><img class="shot" src="__IMG:shot__" alt="B"><h3>B · Daftar</h3><p class="pro">Plus</p><p class="con">Minus</p><button class="btn pick">Pilih B</button></div>
</div>
<h2 class="h">Keputusan yang udah diambil</h2>
<div class="decs"><div class="dec" data-fb="keputusan/1" data-src="business.md#Keputusan 1"><span class="q">Siapa yang nyalain?</span><span class="a">Owner</span><span class="tag">baru</span></div></div>
<h2 class="h">Di balik layar</h2>
<div class="tabs" role="tablist"><button data-tab="seq-1" aria-selected="true">Alur</button></div>
<div class="diagram" id="seq-1" data-panel data-fb="balik-layar/alur" data-src="plans/app.md#Alur">
<pre class="mermaid">
sequenceDiagram
  actor U as Pengguna
  participant A as App
  U->>A: buka
  A-->>U: "Meja #35;1 siap"
</pre>
</div>
<details class="detail"><summary>Mockup interaktif lengkap</summary><div class="body">
  <button class="btn" data-mock="__MOCK:demo.html__">Demo ↗</button>
  <button class="btn" data-mock="__MOCK:Second Screen.html__">Kedua ↗</button>
</div></details>
<footer>Dibuat otomatis dari <code>control/features/demo/</code> · versi __HASH__</footer>
```

- [ ] **Step 3: Tulis runner test dengan bagian assemble (failing)**

`tools/tests/share.test.sh`:
```bash
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
```

- [ ] **Step 4: Jalankan, pastikan gagal**

Run: `bash tools/tests/share.test.sh`
Expected: `FAIL - A1 rakit body-ok gagal` (assemble.py belum ada) dan exit ≠ 0.

- [ ] **Step 5: Tulis `template.html`**

`plugin/skills/share/template.html`:
```html
<!doctype html>
<html lang="id">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>__TITLE__ — Review</title>
<style>
:root{--bg:#f6f5f1;--surface:#fff;--ink:#1d1d1b;--muted:#6b6a65;--line:#e4e2db;--accent:#1f6f5c;--accent-soft:#e3f0ec;--warn:#a4580f;--warn-soft:#fbefe1;--chip:#efeee9;--r:14px}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",Inter,Roboto,sans-serif}
code{font:13px ui-monospace,Menlo,monospace;background:var(--chip);padding:1px 5px;border-radius:5px}
.wrap{max-width:1100px;margin:0 auto;padding:0 20px 140px}

.hero{padding:44px 0 28px}
.eyebrow{font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted)}
.hero h1{font-size:40px;line-height:1.15;margin:8px 0 10px;letter-spacing:-.01em}
.hero .lede{font-size:20px;margin:0 0 18px;color:#3c3b37}
.chips{display:flex;flex-wrap:wrap;gap:6px}
.chip{background:var(--chip);border-radius:99px;padding:3px 10px;font-size:13px;color:var(--muted)}
.chip.warn{background:var(--warn-soft);color:var(--warn)}
.ask{margin-top:22px;display:flex;gap:12px;align-items:center;background:var(--ink);color:#fff;border-radius:var(--r);padding:14px 18px;font-size:15px}
.ask b{font-size:15px}
.ask a{color:#fff}

h2.h{font-size:26px;margin:56px 0 4px;letter-spacing:-.01em}
.hsub{color:var(--muted);margin:0 0 20px}

/* masukan kemarin → jadinya */
.chg{background:var(--surface);border:1px solid var(--line);border-radius:var(--r)}
.chg-row{display:grid;grid-template-columns:1fr 22px 1.4fr auto auto;gap:12px;align-items:center;padding:12px 18px;border-top:1px solid var(--line)}
.chg-row:first-child{border-top:0}
.chg-row .from{color:var(--muted);font-style:italic;font-size:15px}
.chg-row .arr{color:var(--muted)}
.chg-row .to{font-weight:600}
.chg-row a{font-size:13px;color:var(--accent);white-space:nowrap;text-decoration:none}
@media (max-width:800px){.chg-row{grid-template-columns:1fr auto}.chg-row .arr{display:none}.chg-row .from,.chg-row .to{grid-column:1/-1}}

/* apa & kenapa */
.why{display:grid;grid-template-columns:1fr 40px 1fr;align-items:stretch}
.why-col{border-radius:var(--r);padding:18px 20px}
.why-col.before{background:#f3e9e4;border:1px solid #ead7cf}
.why-col.after{background:var(--accent-soft);border:1px solid #c9e1d9}
.why-tag{font-size:12px;letter-spacing:.08em;text-transform:uppercase;font-weight:700;margin-bottom:8px}
.before .why-tag{color:#a33a2c}.after .why-tag{color:var(--accent)}
.why-col ul{margin:0;padding-left:18px}.why-col li{margin:6px 0}
.why-arrow{display:grid;place-items:center;font-size:24px;color:var(--muted)}
.facts{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:10px;margin-top:12px}
.facts div{background:var(--surface);border:1px solid var(--line);border-radius:var(--r);padding:12px 14px}
.facts span{display:block;font-size:12px;color:var(--muted);text-transform:uppercase;letter-spacing:.06em}
.facts b{font-size:15px}
@media (max-width:800px){.why{grid-template-columns:1fr}.why-arrow{transform:rotate(90deg);height:32px}}

/* storyboard */
.story{display:grid;gap:28px}
.step{display:grid;grid-template-columns:260px 1fr;gap:24px;align-items:start}
.step .txt{position:sticky;top:20px;padding-top:6px}
.step .num{display:inline-grid;place-items:center;width:34px;height:34px;border-radius:50%;background:var(--accent);color:#fff;font-weight:700;font-size:15px}
.step .time{font:600 14px ui-monospace,Menlo,monospace;color:var(--muted);margin-left:8px}
.step .same{font-size:11px;text-transform:uppercase;letter-spacing:.06em;background:var(--chip);color:var(--muted);border-radius:99px;padding:2px 8px;margin-left:8px}
.step h3{font-size:21px;line-height:1.3;margin:12px 0 6px}
.step p{margin:0;color:var(--muted);font-size:15px}
.shot{display:block;width:100%;border-radius:var(--r);border:1px solid var(--line);box-shadow:0 2px 14px rgba(0,0,0,.06);cursor:zoom-in;background:#fff}
.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px;max-width:620px}
.pair.wide{grid-template-columns:2.6fr 1fr;max-width:none;align-items:start}
.pair figure{margin:0}.pair figcaption{font-size:14px;color:var(--muted);margin-top:6px}
@media (max-width:800px){.step{grid-template-columns:1fr;gap:10px}.step .txt{position:static}.hero h1{font-size:30px}.pair,.pair.wide{grid-template-columns:1fr}}

/* pilih satu */
.opts{display:grid;grid-template-columns:repeat(3,1fr);gap:16px}
.opt{background:var(--surface);border:2px solid var(--line);border-radius:var(--r);padding:12px;display:flex;flex-direction:column}
.opt.sel{border-color:var(--accent);box-shadow:0 0 0 4px var(--accent-soft)}
.opt h3{margin:12px 0 6px;font-size:18px}
.opt .pro,.opt .con{font-size:14px;margin:3px 0}
.opt .pro:before{content:"+ ";color:var(--accent);font-weight:700}
.opt .con:before{content:"− ";color:#a33a2c;font-weight:700}
.opt .pick{width:100%;margin-top:12px}
.opt.sel .pick{background:var(--accent);color:#fff;border-color:var(--accent)}
@media (max-width:800px){.opts{grid-template-columns:1fr}}

/* kalau nggak beres */
.oops{display:grid;grid-template-columns:1fr 1fr;gap:18px}
.oops figure{margin:0}
.oops figcaption{font-size:15px;margin-top:8px}
.oops figcaption b{display:block;font-size:16px}
.oops figcaption span{color:var(--muted)}
@media (max-width:800px){.oops{grid-template-columns:1fr}}
.list1{list-style:none;padding:0;margin:14px 0 0;display:grid;grid-template-columns:1fr 1fr;gap:6px 24px}
.list1 li{font-size:15px;padding:6px 0;border-bottom:1px solid var(--line)}
.list1 li span{color:var(--muted)}
@media (max-width:800px){.list1{grid-template-columns:1fr}}
details.more>summary{cursor:pointer;color:var(--accent);font-size:15px;margin-top:16px;list-style:none}
details.more>summary::-webkit-details-marker{display:none}

/* keputusan */
.decs{background:var(--surface);border:1px solid var(--line);border-radius:var(--r)}
.dec{display:flex;gap:14px;align-items:center;padding:13px 18px;border-top:1px solid var(--line)}
.dec:first-child{border-top:0}
.dec .q{color:var(--muted);font-size:15px;width:44%}
.dec .a{flex:1;font-weight:600}
.dec .a:before{content:"✓ ";color:var(--accent)}
.dec .tag{font-size:11px;text-transform:uppercase;letter-spacing:.06em;background:var(--warn-soft);color:var(--warn);border-radius:99px;padding:2px 8px}
@media (max-width:800px){.dec{flex-wrap:wrap}.dec .q{width:100%}}

/* diagram */
.diagram{background:var(--surface);border:1px solid var(--line);border-radius:var(--r);padding:18px;overflow-x:auto}
pre.mermaid{margin:0;font:12px/1.5 ui-monospace,Menlo,monospace;color:var(--muted);white-space:pre-wrap}
.tabs{display:flex;gap:6px;margin-bottom:12px;flex-wrap:wrap}
.tabs button{border:1px solid var(--line);background:var(--surface);border-radius:99px;padding:6px 14px;font:inherit;font-size:14px;cursor:pointer}
.tabs button[aria-selected=true]{background:var(--ink);color:#fff;border-color:var(--ink)}
.note{font-size:13px;color:var(--muted);margin-top:10px}

/* detail */
details.detail{background:var(--surface);border:1px solid var(--line);border-radius:var(--r);margin-bottom:10px}
details.detail>summary{cursor:pointer;padding:15px 18px;font-weight:600;display:flex;gap:10px;align-items:center}
details.detail>summary .hint{font-weight:400;color:var(--muted);font-size:14px}
details.detail .body{padding:0 18px 18px;font-size:15px}
ol.rules{margin:0;padding-left:22px}ol.rules li{margin:5px 0}

/* lightbox */
.lb{position:fixed;inset:0;background:rgba(20,20,18,.85);display:none;place-items:center;z-index:20;cursor:zoom-out;padding:24px}
.lb.open{display:grid}.lb img{max-width:100%;max-height:100%;border-radius:10px}

/* feedback */
.fb-btn{border:1px solid var(--line);background:var(--surface);border-radius:99px;font-size:13px;padding:3px 10px;cursor:pointer;color:var(--muted);white-space:nowrap}
.fb-btn:hover{border-color:var(--accent);color:var(--accent)}
.fb-btn.has{background:var(--accent);border-color:var(--accent);color:#fff}
.fb-box{margin-top:10px;display:none}.fb-box.open{display:block}
.fb-box textarea{width:100%;min-height:72px;border:1px solid var(--accent);border-radius:8px;padding:8px 10px;font:inherit;font-size:14px;resize:vertical}
.fb-box .row{display:flex;gap:8px;justify-content:flex-end;margin-top:6px}
.btn{border:1px solid var(--line);background:var(--surface);border-radius:8px;padding:6px 12px;font:inherit;font-size:14px;cursor:pointer}
.btn.primary{background:var(--accent);color:#fff;border-color:var(--accent)}
.fbar{position:fixed;left:50%;transform:translateX(-50%);bottom:16px;z-index:10;background:var(--ink);color:#fff;border-radius:14px;padding:10px 12px 10px 16px;display:flex;gap:10px;align-items:center;box-shadow:0 8px 30px rgba(0,0,0,.25);font-size:14px;max-width:calc(100% - 32px)}
.fbar input{border:0;border-radius:8px;padding:6px 10px;font:inherit;font-size:14px;width:140px}
.fbar .btn{border:0}
.toast{position:fixed;left:50%;bottom:84px;transform:translateX(-50%);background:var(--accent);color:#fff;padding:8px 14px;border-radius:8px;font-size:14px;opacity:0;transition:opacity .2s;pointer-events:none;z-index:11}
.toast.show{opacity:1}
footer{color:var(--muted);font-size:13px;margin-top:48px;border-top:1px solid var(--line);padding-top:14px}
</style>
</head>
<body>
<div class="wrap">
<!-- BODY -->
</div>

<div class="lb" id="lb"><img alt=""></div>
<div class="fbar">
  <span>💬 <b id="fb-count">0</b></span>
  <input id="fb-name" placeholder="Nama kamu">
  <button class="btn" type="button" id="fb-general">Komentar umum</button>
  <button class="btn primary" type="button" id="fb-copy">Copy feedback</button>
</div>
<div class="toast" id="toast"></div>
<!-- MOCKS -->
<script>
const META=__META__;
const FEATURE=META.feature, HASH=META.hash;
const KEY=`share-fb:${FEATURE}:${HASH}`;
window.__shareKey=KEY;
let store={}; try{store=JSON.parse(localStorage.getItem(KEY)||"{}")||{}}catch(e){store={}}
const save=()=>{try{localStorage.setItem(KEY,JSON.stringify(store))}catch(e){}};
const has=k=>!!store[k]&&(!!(store[k].text||'').trim()||!!store[k].choice);
const nameEl=document.getElementById('fb-name');
try{nameEl.value=localStorage.getItem('share-fb:name')||''}catch(e){}
nameEl.oninput=()=>{try{localStorage.setItem('share-fb:name',nameEl.value)}catch(e){}};
function toast(m){const t=document.getElementById('toast');t.textContent=m;t.classList.add('show');setTimeout(()=>t.classList.remove('show'),1800)}
function titleOf(el){if(el.dataset.title)return el.dataset.title;const t=el.querySelector('h3,b,.q,.from')||el;return(t.textContent||'').trim().replace(/\s+/g,' ').slice(0,70)}
function refresh(){
  document.getElementById('fb-count').textContent=Object.keys(store).filter(has).length;
  document.querySelectorAll('.fb-btn').forEach(b=>{const s=store[b.dataset.for];const h=!!s&&!!(s.text||'').trim();b.classList.toggle('has',h);b.textContent=h?'💬 ✓':'💬'});
}
function buildText(){
  const L=[`=== FEEDBACK share:${FEATURE} ===`,`versi: ${META.mode} · revisi ${META.revision} · ${META.generated} · ${HASH}`,`reviewer: ${nameEl.value.trim()||'(tanpa nama)'}`];
  Object.keys(store).filter(has).forEach(id=>{const c=store[id];L.push('---',`[${id}] ${c.title}`);if(c.src)L.push(`sumber: ${c.src}`);if(c.choice)L.push(`pilih: ${c.choice}`);const t=(c.text||'').trim();if(t)t.split('\n').forEach(l=>L.push('> '+l))});
  L.push('=== END ===');return L.join('\n');
}
window.__shareBuildText=buildText;

// lightbox
const lb=document.getElementById('lb');
document.querySelectorAll('img.shot').forEach(i=>i.onclick=()=>{lb.querySelector('img').src=i.src;lb.classList.add('open')});
lb.onclick=()=>lb.classList.remove('open');

// tab diagram (satu grup per halaman)
document.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>{
  document.querySelectorAll('[data-tab]').forEach(x=>x.setAttribute('aria-selected',String(x===b)));
  document.querySelectorAll('[data-panel]').forEach(p=>p.hidden=p.id!==b.dataset.tab);
});

// mockup lengkap (base64 → tab baru)
document.querySelectorAll('[data-mock]').forEach(b=>b.onclick=()=>{
  const src=document.getElementById(b.dataset.mock); if(!src) return;
  const w=window.open('','_blank'); if(!w) return;
  w.document.open(); w.document.write(new TextDecoder().decode(Uint8Array.from(atob(src.textContent.trim()),c=>c.charCodeAt(0)))); w.document.close();
});

// 💬 per [data-fb]
document.querySelectorAll('[data-fb]').forEach(el=>{
  const id=el.dataset.fb;
  const b=document.createElement('button'); b.className='fb-btn'; b.type='button'; b.textContent='💬'; b.dataset.for=id;
  const box=document.createElement('div'); box.className='fb-box';
  box.innerHTML='<textarea placeholder="Tulis komentar…"></textarea><div class="row"><button class="btn" type="button" data-act="del">Hapus</button><button class="btn primary" type="button" data-act="ok">Simpan</button></div>';
  const row=css=>{const r=document.createElement('div');r.style.cssText=css;r.appendChild(b);return r};
  if(el.classList.contains('dec')||el.classList.contains('chg-row')){el.appendChild(b);el.after(box)}
  else if(el.classList.contains('why')||el.classList.contains('opts')||el.classList.contains('facts')){const r=row('display:flex;justify-content:flex-end;margin-top:8px');el.after(r);r.after(box)}
  else if(el.tagName==='LI'){el.append(' ',b);el.appendChild(box)}
  else if(el.classList.contains('diagram')){el.prepend(row('display:flex;justify-content:flex-end;margin-bottom:6px'));el.appendChild(box)}
  else{const slot=el.querySelector('.txt')||el.querySelector('figcaption')||el;slot.appendChild(row('margin-top:10px'));slot.appendChild(box)}
  const ta=box.querySelector('textarea');
  b.onclick=e=>{e.stopPropagation();box.classList.toggle('open');ta.value=(store[id]&&store[id].text)||'';ta.focus()};
  box.onclick=e=>{const a=e.target.dataset.act;if(!a)return;e.stopPropagation();
    if(a==='ok'&&ta.value.trim())store[id]=Object.assign({},store[id]||{},{text:ta.value,src:el.dataset.src||'',title:titleOf(el)});
    else if(store[id]&&store[id].choice)store[id].text='';
    else delete store[id];
    save();refresh();box.classList.remove('open')};
});

// pilihan (radio per grup; data-choice == data-fb grup yang sama)
document.querySelectorAll('[data-choice]').forEach(g=>{
  const id=g.dataset.choice;
  const paint=()=>g.querySelectorAll('.opt').forEach(o=>{const s=!!store[id]&&store[id].choice===o.dataset.val;o.classList.toggle('sel',s);o.querySelector('.pick').textContent=s?'✓ Pilihan kamu':'Pilih '+o.dataset.val});
  g.querySelectorAll('.opt').forEach(o=>o.querySelector('.pick').onclick=()=>{
    const c=store[id]||{text:'',src:g.dataset.src||'',title:titleOf(g)};
    if(c.choice===o.dataset.val)delete c.choice;else c.choice=o.dataset.val;
    if(!c.choice&&!(c.text||'').trim())delete store[id];else store[id]=c;
    save();refresh();paint();if(c.choice)toast('Pilihan '+c.choice+' disimpan');
  });
  paint();
});

document.getElementById('fb-general').onclick=()=>{
  const t=prompt('Komentar umum:',(store['umum']&&store['umum'].text)||'');
  if(t!==null){if(t.trim())store['umum']={text:t,src:'',title:'Komentar umum'};else delete store['umum'];save();refresh()}
};
document.getElementById('fb-copy').onclick=async()=>{
  const n=Object.keys(store).filter(has).length;
  if(!n)return toast('Belum ada komentar');
  const text=buildText();
  try{await navigator.clipboard.writeText(text);toast(`${n} komentar disalin. Kirim ke pemilik fitur.`)}catch(e){prompt('Salin teks ini:',text)}
};
refresh();
</script>
<script src="https://cdn.jsdelivr.net/npm/mermaid@11.4.1/dist/mermaid.min.js"></script>
<script>
if(window.mermaid){
  mermaid.initialize({startOnLoad:false,theme:'neutral',fontFamily:'inherit'});
  const run=r=>{const n=[...r.querySelectorAll('pre.mermaid:not([data-processed])')];if(n.length)mermaid.run({nodes:n}).catch(()=>{})};
  document.querySelectorAll('[data-panel]:not([hidden])').forEach(run);
  document.querySelectorAll('pre.mermaid').forEach(p=>{if(!p.closest('[data-panel],details'))run(p.parentElement)});
  document.querySelectorAll('[data-tab]').forEach(b=>b.addEventListener('click',()=>{const p=document.getElementById(b.dataset.tab);if(p)run(p)}));
  document.querySelectorAll('details').forEach(d=>d.addEventListener('toggle',()=>d.open&&run(d)));
}
</script>
</body>
</html>
```

- [ ] **Step 6: Tulis `assemble.py`**

`plugin/skills/share/assemble.py`:
```python
#!/usr/bin/env python3
"""assemble.py — rakit share.html dari template + body + gambar + mockup.

Bagian dari skill `share` (context-vault). template.html dicari di folder yang
sama dengan script ini. Exit: 0 ok · 1 validasi gagal (output tak ditulis) · 2 argumen salah.
"""
import argparse
import base64
import datetime
import hashlib
import html
import json
import os
import re
import sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
TEMPLATE = os.path.join(HERE, 'template.html')
MIME = {'.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png',
        '.webp': 'image/webp', '.gif': 'image/gif'}
WARN_BYTES = 16 * 1024 * 1024
UNKNOWN_PH = re.compile(r'__[A-Z][A-Z0-9]*(?::[^\s"<>]*?)?__')


def source_files(feature_dir):
    """Berkas sumber versi, urut tetap. Dotfile & reviews.md tidak ikut."""
    out = []
    for rel in ('business.md', 'fanout.md'):
        p = os.path.join(feature_dir, rel)
        if os.path.isfile(p):
            out.append(p)
    for sub, only_md in (('plans', True), ('mockups', False)):
        d = os.path.join(feature_dir, sub)
        if not os.path.isdir(d):
            continue
        for n in sorted(os.listdir(d)):
            p = os.path.join(d, n)
            if n.startswith('.') or not os.path.isfile(p):
                continue
            if only_md and not n.endswith('.md'):
                continue
            out.append(p)
    return out


def source_hash(feature_dir):
    h = hashlib.sha256()
    for p in source_files(feature_dir):
        h.update(os.path.relpath(p, feature_dir).replace(os.sep, '/').encode('utf-8') + b'\0')
        with open(p, 'rb') as f:
            h.update(f.read())
        h.update(b'\0')
    return h.hexdigest()[:8]


def revision_of(feature_dir):
    """Angka 'Revisi N' tertinggi di kepala business.md (baris #, >, kosong di awal). Tak ada → 1."""
    try:
        with open(os.path.join(feature_dir, 'business.md'), encoding='utf-8') as f:
            lines = f.read().splitlines()
    except OSError:
        return 1
    head = []
    for line in lines:
        if line.strip() == '' or line.startswith('#') or line.startswith('>'):
            head.append(line)
            continue
        break
    nums = [int(n) for n in re.findall(r'\bRevisi\s+(\d+)', '\n'.join(head), re.I)]
    return max(nums) if nums else 1


def lint_body(body):
    errs = []
    for k, n in sorted(Counter(re.findall(r'data-fb="([^"]+)"', body)).items()):
        if n > 1:
            errs.append(f'data-fb ganda: "{k}" ({n}x)')
    if re.search(r'class="[^"]*(?<![\w-])label(?![\w-])', body):
        errs.append('kelas "label" bentrok dengan kelas internal Mermaid — pakai nama lain (mis. "lbl")')
    blocks = re.findall(r'<pre class="mermaid"[^>]*>(.*?)</pre>', body, re.S)
    for i, block in enumerate(blocks, 1):
        m = re.search(r'#\d+(?![\d;])', block)
        if m:
            errs.append(f'diagram {i}: "{m.group(0)}" harus ditulis "#35;{m.group(0)[1:]}" (Mermaid memotong teks setelah #angka)')
        if '\\n' in block:
            errs.append(f'diagram {i}: "\\n" di label — pakai <br/>')
    return errs


def assemble(feature_dir, body, images_dir, mode, revision, generated):
    """Return (html|None, hash, errors)."""
    errs = lint_body(body)
    feature = os.path.basename(os.path.normpath(feature_dir))
    h = source_hash(feature_dir)

    def img(mt):
        name = mt.group(1)
        if images_dir:
            for ext, mime in MIME.items():
                p = os.path.join(images_dir, name + ext)
                if os.path.isfile(p):
                    with open(p, 'rb') as f:
                        return f'data:{mime};base64,' + base64.b64encode(f.read()).decode('ascii')
        errs.append(f'gambar tak ada: {name} (cari {name}.jpg/.png/… di {images_dir or "(tanpa --images)"})')
        return mt.group(0)

    mocks = {}

    def mock(mt):
        fname = mt.group(1)
        p = os.path.join(feature_dir, 'mockups', fname)
        if not os.path.isfile(p):
            errs.append(f'mockup tak ada: mockups/{fname}')
            return mt.group(0)
        mid = 'mock-' + re.sub(r'[^a-z0-9]+', '-', fname.lower()).strip('-')
        mocks[mid] = p
        return mid

    body = re.sub(r'__IMG:([A-Za-z0-9_.-]+?)__', img, body)
    body = re.sub(r'__MOCK:([^"<>]+?)__', mock, body)
    body = body.replace('__HASH__', h)
    for ph in sorted(set(UNKNOWN_PH.findall(body))):
        if not (ph.startswith('__IMG:') or ph.startswith('__MOCK:')):
            errs.append(f'placeholder tak dikenal: {ph}')
    if errs:
        return None, h, errs

    m = re.search(r'<h1[^>]*>(.*?)</h1>', body, re.S)
    title = html.unescape(re.sub(r'<[^>]+>', '', m.group(1))).strip() if m else feature
    meta = json.dumps({'feature': feature, 'mode': mode, 'revision': revision,
                       'generated': generated, 'hash': h}, ensure_ascii=False).replace('</', '<\\/')
    mock_tags = ''
    for mid, p in mocks.items():
        with open(p, 'rb') as f:
            mock_tags += f'<script type="text/plain" id="{mid}">{base64.b64encode(f.read()).decode("ascii")}</script>\n'
    with open(TEMPLATE, encoding='utf-8') as f:
        tpl = f.read()
    out = (tpl.replace('__TITLE__', html.escape(title, quote=False))
              .replace('__META__', meta)
              .replace('<!-- MOCKS -->', mock_tags)
              .replace('<!-- BODY -->', body))
    return out, h, []


def main(argv=None):
    ap = argparse.ArgumentParser(description='Rakit share.html (skill share).')
    ap.add_argument('--feature-dir', required=True)
    ap.add_argument('--hash-only', action='store_true', help='cetak hash versi sumber lalu keluar')
    ap.add_argument('--body')
    ap.add_argument('--images')
    ap.add_argument('--mode', choices=('rancangan', 'dibangun'))
    ap.add_argument('--revision', type=int)
    ap.add_argument('--generated', help='YYYY-MM-DD (default: hari ini)')
    ap.add_argument('--out')
    a = ap.parse_args(argv)
    if a.hash_only:
        print(source_hash(a.feature_dir))
        return 0
    if not (a.body and a.mode and a.out):
        ap.error('--body, --mode, --out wajib (kecuali --hash-only)')
    if not os.path.isfile(os.path.join(a.feature_dir, 'business.md')):
        print(f'error: business.md tak ada di {a.feature_dir} — jalankan /intake dulu', file=sys.stderr)
        return 1
    gen = a.generated or datetime.date.today().isoformat()
    if not re.fullmatch(r'\d{4}-\d{2}-\d{2}', gen):
        ap.error('--generated harus YYYY-MM-DD')
    with open(a.body, encoding='utf-8') as f:
        body = f.read()
    rev = a.revision or revision_of(a.feature_dir)
    out, h, errs = assemble(a.feature_dir, body, a.images, a.mode, rev, gen)
    if errs:
        for e in errs:
            print('error: ' + e, file=sys.stderr)
        return 1
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    tmp = a.out + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f:
        f.write(out)
    os.replace(tmp, a.out)
    size = os.path.getsize(a.out)
    if size > WARN_BYTES:
        print(f'peringatan: {size / 1048576:.1f}MB > 16MB — bisa ditolak sebagai lampiran', file=sys.stderr)
    print(f'ok {h} {size} {a.out}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
```

- [ ] **Step 7: Jalankan test, pastikan lulus**

Run: `bash tools/tests/share.test.sh`
Expected: semua baris `ok` untuk A1–A12, ringkasan `fail=0`, exit 0. Kalau A9 gagal karena pola: body mutasi berisi literal backslash-n (`baris1\nbaris2`, dua karakter `\` `n`), dan `lint_body` mencari `'\\n'` (string Python = backslash + n). Keduanya harus cocok.

- [ ] **Step 8: Pastikan tak ada `__pycache__` / residu di plugin**

Run: `git status --porcelain plugin/ tools/ && find plugin -name __pycache__`
Expected: hanya berkas baru Task 1, tanpa `__pycache__`.

- [ ] **Step 9: Commit**

```bash
git add plugin/skills/share/template.html plugin/skills/share/assemble.py tools/tests/share.test.sh tools/tests/fixtures/share
git commit -m "feat(share): template halaman review + assemble.py (rakit, hash versi, validasi)"
```

---

### Task 2: `capture.py`, tangkap layar frame mockup

**Files:**
- Create: `plugin/skills/share/capture.py`
- Modify: `tools/tests/share.test.sh` (sisip bagian `# === capture ===` tepat di atas baris `# === RINGKASAN ===`)

**Interfaces:**
- Consumes: fixture `tools/tests/fixtures/share/demo/mockups/demo.html` (Task 1). Isinya: `#f1 .frame` 600×300 hijau dengan `.fold` garis merah, `#f2 .phone` 300×500, `#blank` putih, state hash `#a`/`#b`.
- Produces:
  - `capture.py --find-chrome` → stdout path Chrome, exit 0. Tak ada → exit 3.
  - `capture.py --mockup FILE --out DIR --name NAME (--select CSS | --hash FRAG | --full) [--device tablet|phone] [--hide CSS]... [--clean-css FILE] [--window WxH]` → stdout path hasil (`<out>/<name>.jpg`, atau `.png` bila Pillow tak ada), exit 0.
  - Exit codes: `1` Chrome gagal / tangkapan kosong · `2` argumen · `3` Chrome tak ada · `4` selector tak ketemu.
  - Env `SHARE_CHROME` menimpa deteksi Chrome. Dipakai test dan user dengan Chrome di lokasi aneh.

- [ ] **Step 1: Tulis bagian test capture (failing)**

Sisipkan di `tools/tests/share.test.sh` tepat di atas `# === RINGKASAN ===`:
```bash
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

```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `bash tools/tests/share.test.sh`
Expected: `FAIL - C6 exit code bukan 3` (capture.py belum ada → python exit 2), exit ≠ 0.

- [ ] **Step 3: Tulis `capture.py`**

`plugin/skills/share/capture.py`:
```python
#!/usr/bin/env python3
"""capture.py — tangkap layar satu frame mockup HTML lewat headless Chrome.

Bagian dari skill `share` (context-vault). Mockup asli tak pernah diubah: skrip
isolasi disuntik ke salinan sementara (di luar folder mockup, dengan <base> ke folder asli).
Exit: 0 ok · 1 Chrome gagal / tangkapan kosong · 2 argumen · 3 Chrome tak ada · 4 selector tak ketemu.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import quote

DEVICES = {'tablet': {'window': (1260, 1100), 'width': 1100},
           'phone': {'window': (460, 1700), 'width': 420}}
CHROME_PATHS = ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
                '/Applications/Chromium.app/Contents/MacOS/Chromium']
CHROME_NAMES = ['google-chrome', 'google-chrome-stable', 'chromium', 'chromium-browser', 'chrome']

ISOLATE = '''<script>
window.addEventListener('load',function(){
var t=document.querySelector(%s);
if(!t){document.body.setAttribute('data-capture','missing');return}
var keep=[].slice.call(document.querySelectorAll('svg')).filter(function(s){return s.querySelector('symbol')});
document.body.innerHTML='';
document.body.style.cssText='margin:0;padding:20px;background:#fff;width:max-content';
keep.forEach(function(s){document.body.appendChild(s)});
t.style.transform='none';t.style.margin='0';
document.body.appendChild(t);
document.body.setAttribute('data-capture','ok');
});
</script>'''


def find_chrome():
    env = os.environ.get('SHARE_CHROME')
    if env:
        return env if (os.path.isfile(env) or shutil.which(env)) else None
    for p in CHROME_PATHS:
        if os.path.isfile(p):
            return p
    for n in CHROME_NAMES:
        p = shutil.which(n)
        if p:
            return p
    return None


def inject(src, head_extra, body_extra):
    low = src.lower()
    i = low.find('<head')
    if i >= 0:
        j = low.find('>', i) + 1
        src = src[:j] + head_extra + src[j:]
    else:
        src = head_extra + src
    low = src.lower()
    k = low.rfind('</body>')
    return src[:k] + body_extra + src[k:] if k >= 0 else src + body_extra


def chrome_cmd(chrome, profile, window, extra):
    cmd = [chrome, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--no-first-run',
           '--no-default-browser-check', '--allow-file-access-from-files',
           f'--user-data-dir={profile}', f'--window-size={window[0]},{window[1]}',
           '--virtual-time-budget=3000'] + extra
    if hasattr(os, 'geteuid') and os.geteuid() == 0:
        cmd.insert(1, '--no-sandbox')
    return cmd


def finish(png, out_dir, name, width):
    try:
        from PIL import Image, ImageChops
    except ImportError:
        dst = os.path.join(out_dir, name + '.png')
        shutil.copyfile(png, dst)
        print('peringatan: Pillow tak ada — PNG tanpa pangkas', file=sys.stderr)
        return dst
    im = Image.open(png).convert('RGB')
    bbox = ImageChops.difference(im, Image.new('RGB', im.size, (255, 255, 255))).getbbox()
    if not bbox:
        return None
    im = im.crop(bbox)
    if im.width > width:
        resample = getattr(Image, 'Resampling', Image).LANCZOS
        im = im.resize((width, max(1, round(im.height * width / im.width))), resample)
    dst = os.path.join(out_dir, name + '.jpg')
    im.save(dst, 'JPEG', quality=82, optimize=True)
    return dst


def main(argv=None):
    ap = argparse.ArgumentParser(description='Tangkap layar frame mockup (skill share).')
    ap.add_argument('--find-chrome', action='store_true')
    ap.add_argument('--mockup')
    ap.add_argument('--out')
    ap.add_argument('--name')
    g = ap.add_mutually_exclusive_group()
    g.add_argument('--select', help='selector CSS elemen yang diisolasi')
    g.add_argument('--hash', help='fragmen URL tanpa # (mockup ber-routing hash)')
    g.add_argument('--full', action='store_true', help='halaman penuh tanpa isolasi')
    ap.add_argument('--device', choices=sorted(DEVICES), default='tablet')
    ap.add_argument('--hide', action='append', default=[], help='selector yang disembunyikan (boleh berulang)')
    ap.add_argument('--clean-css', help='berkas CSS tambahan yang disuntik')
    ap.add_argument('--window', help='WxH, menimpa ukuran jendela device')
    a = ap.parse_args(argv)

    chrome = find_chrome()
    if a.find_chrome:
        if not chrome:
            print('error: Chrome/Chromium tak ditemukan (set SHARE_CHROME=<path>)', file=sys.stderr)
            return 3
        print(chrome)
        return 0
    if not (a.mockup and a.out and a.name) or not (a.select or a.hash is not None or a.full):
        ap.error('--mockup, --out, --name, dan salah satu --select/--hash/--full wajib')
    if not chrome:
        print('error: Chrome/Chromium tak ditemukan (set SHARE_CHROME=<path>)', file=sys.stderr)
        return 3
    mockup = os.path.abspath(a.mockup)
    if not os.path.isfile(mockup):
        print(f'error: mockup tak ada: {a.mockup}', file=sys.stderr)
        return 2
    dev = DEVICES[a.device]
    window = dev['window']
    if a.window:
        w, h = a.window.lower().split('x')
        window = (int(w), int(h))

    css = ''.join(f'{sel}{{display:none!important}}\n' for sel in a.hide)
    if a.clean_css:
        with open(a.clean_css, encoding='utf-8') as f:
            css += f.read()
    base = 'file://' + quote(os.path.dirname(mockup)) + '/'
    head = f'<base href="{base}">' + (f'<style>{css}</style>' if css else '')
    body = ISOLATE % json.dumps(a.select).replace('</', '<\\/') if a.select else ''
    with open(mockup, encoding='utf-8', errors='replace') as f:
        src = inject(f.read(), head, body)

    os.makedirs(a.out, exist_ok=True)
    tmpdir = tempfile.mkdtemp(prefix='share-cap-')
    try:
        page = os.path.join(tmpdir, 'page.html')
        with open(page, 'w', encoding='utf-8') as f:
            f.write(src)
        url = 'file://' + quote(page) + ('#' + a.hash if a.hash is not None else '')
        profile = os.path.join(tmpdir, 'profile')
        if a.select:
            dom = subprocess.run(chrome_cmd(chrome, profile, window, ['--dump-dom', url]),
                                 capture_output=True, text=True, timeout=120)
            if 'data-capture="missing"' in dom.stdout:
                print(f'error: selector tak ketemu: {a.select}', file=sys.stderr)
                return 4
            if 'data-capture="ok"' not in dom.stdout:
                print('error: Chrome gagal memuat mockup (isolasi tak jalan)', file=sys.stderr)
                return 1
        png = os.path.join(tmpdir, 'shot.png')
        subprocess.run(chrome_cmd(chrome, profile, window, [f'--screenshot={png}', url]),
                       capture_output=True, timeout=120)
        if not os.path.isfile(png) or os.path.getsize(png) == 0:
            print('error: Chrome tak menghasilkan screenshot', file=sys.stderr)
            return 1
        dst = finish(png, a.out, a.name, dev['width'])
        if not dst:
            print('error: tangkapan kosong (putih semua) — elemen belum tergambar / salah elemen', file=sys.stderr)
            return 1
        print(dst)
        return 0
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main())
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `bash tools/tests/share.test.sh`
Expected: A1–A12 + C1–C9 `ok` (atau `skip` untuk bagian yang butuh Chrome/Pillow yang tak ada), `fail=0`. Kalau C1 lebar ≠ 600: periksa body `padding:20px` (dipangkas `finish` karena putih) dan `--hide-scrollbars`.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/share/capture.py tools/tests/share.test.sh
git commit -m "feat(share): capture.py — tangkap layar frame mockup via headless Chrome"
```

---

### Task 3: Perilaku halaman (💬, pilihan, Copy feedback)

Task ini menguji JS `template.html` dari Task 1 di Chrome sungguhan. Kalau ada test gagal, perbaiki `template.html`.

**Files:**
- Modify: `tools/tests/share.test.sh` (sisip bagian `# === halaman ===` di atas `# === RINGKASAN ===`)
- Modify (bila test menemukan bug): `plugin/skills/share/template.html`

**Interfaces:**
- Consumes: `assemble.py` (Task 1), `capture.py --find-chrome` (Task 2), `window.__shareKey`, `window.__shareBuildText()` (template Task 1).

- [ ] **Step 1: Tulis bagian test halaman**

Sisipkan di atas `# === RINGKASAN ===`:
```bash
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

```

Catatan uji: komentar kedua mengandung baris baru. Di dalam string Python `'''…'''`, `\\n` ditulis ke JS sebagai `\n` (escape baris baru JS). Jadi textarea menerima dua baris.

- [ ] **Step 2: Jalankan**

Run: `bash tools/tests/share.test.sh`
Expected: `ok - P1 perilaku halaman` dan `ok - P2 localStorage diblokir → tetap jalan`. Kalau ada yang gagal, baca detail cek di output (`FAIL - P1 …` + `dapat:`), lalu perbaiki `template.html`. Titik rawan:
- urutan baris blok
- `has()` untuk entri yang punya pilihan tapi tanpa teks
- `localStorage` diblokir: `nameEl.value` saat restore harus tetap dibungkus `try`

Jalankan ulang sampai `fail=0`.

- [ ] **Step 3: Commit**

```bash
git add tools/tests/share.test.sh plugin/skills/share/template.html
git commit -m "test(share): perilaku halaman — 💬, pilihan radio, Copy feedback, storage diblokir"
```

---

### Task 4: `SKILL.md` + `reference.md`

**Files:**
- Create: `plugin/skills/share/SKILL.md`
- Create: `plugin/skills/share/reference.md`
- Modify: `tools/tests/share.test.sh` (sisip bagian `# === statis ===` di atas `# === RINGKASAN ===`)

**Interfaces:**
- Consumes: CLI `assemble.py` & `capture.py` persis seperti Task 1–2; slot/placeholder template Task 1.
- Produces: skill `share` yang bisa dipanggil `feature`/`ship` (Task 5) dengan argumen `share <fitur>` (mode dari status/pemanggil).

- [ ] **Step 1: Tulis test statis (failing)**

Sisipkan di atas `# === RINGKASAN ===`:
```bash
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

```

Catatan S8: cuplikan dirakit bersama, jadi **`data-fb` antar-cuplikan wajib unik** di seluruh `reference.md`. Diagram Mermaid di cuplikan juga harus patuh aturan `#35;`/`<br/>`.

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `bash tools/tests/share.test.sh`
Expected: `FAIL - S1 …`, `FAIL - S6 …`, `FAIL - S8 …` (berkas belum ada).

- [ ] **Step 3: Tulis `SKILL.md`**

`plugin/skills/share/SKILL.md`:
````markdown
---
name: share
description: Use untuk bikin SATU file HTML review fitur yang bisa dikirim ke rekan (storyboard tangkapan layar mockup, keputusan, diagram, tombol 💬 + Copy feedback), atau untuk mentriase blok feedback yang dikirim balik. Dipanggil otomatis di akhir feature (rancangan) & ship (dibangun), atau manual kapan saja setelah business.md ada. Trigger — "share <fitur>", "bikin file review <fitur>", "kirim rancangan ke rekan", paste teks berawalan "=== FEEDBACK share:". Jalankan dari root produk yang punya control/.
---

# share — File review fitur buat rekan

Tujuan: rekan yang dikirimi **satu file `.html`** langsung paham fiturnya **dari gambar**, bisa komentar per bagian + milih opsi yang masih terbuka, lalu ngirim balik blok teks yang ditriase ke pipeline. Beda dengan `render-docs`: itu tingkat **produk** buat stakeholder; `share` per **fitur** buat **reviewer**.

Isi, katalog komponen, strategi tangkap layar, Mermaid, format feedback & `reviews.md` ada di `${CLAUDE_PLUGIN_ROOT}/skills/share/reference.md`. **Baca dulu sebelum generate maupun triase.** Kerangka halaman = `${CLAUDE_PLUGIN_ROOT}/skills/share/template.html` (jangan disunting per fitur). Helper: `capture.py` (tangkap layar) & `assemble.py` (rakit) di folder yang sama.

## Deteksi mode
- Argumen memuat `=== FEEDBACK share:` → **Mode Triase** (§B).
- `share <fitur> feedback` → minta user paste blok, lalu Mode Triase.
- `share <fitur>` → **Mode Generate** (§A). Mode halaman `dibangun` bila dipanggil `ship` atau `feature.yaml` `status: shipped`; selain itu `rancangan`.
- Tanpa nama fitur → daftar fitur di `control/features/` yang punya `business.md`, minta pilih.

## A. Mode Generate

### 1. Baca
`control/features/<f>/`: `feature.yaml`, `business.md` (**wajib**; absen → STOP, arahkan `/intake <f>`), lalu bila ada: `fanout.md`, `plans/*.md`, `mockups/*`, `reviews.md`. Mode dibangun: juga `tasks.yaml` + bukti gate dari `ship` (§A.8). **Jangan** baca kode, `.env`, atau apa pun di luar folder fitur. Halaman ini dikirim ke luar tim.

### 2. Rencanakan isi
Ikuti `reference.md` §1–§3. Tentukan:
- bagian yang tampil (bagian tanpa data DILEWATI utuh)
- skenario cerita (5–7 langkah dari Flow `business.md`)
- kasus gagal, keputusan, keputusan terbuka (Pilih satu), dan 2–4 diagram

Tulis dulu **daftar frame**: `nama → mockup + selector/hash + device`.

### 3. Tangkap layar
Scratch: `.claude/share/<f>/img/`. Per frame:
```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/share/capture.py" --mockup "control/features/<f>/mockups/<m>.html" \
  --out ".claude/share/<f>/img" --name <nama> --select '<css>' --device tablet   # atau --hash <frag> / --full; --device phone; --hide '<css>'
```
Strategi isolasi: `reference.md` §4.
- Exit 4 (selector tak ketemu) → periksa mockup, perbaiki selector.
- Exit 1 "tangkapan kosong" → elemen salah / belum tergambar.
- **Exit 3 (Chrome tak ada)** → lanjut TANPA gambar (`reference.md` §4.5) dan sebut terus terang di ringkasan.

### 4. Tulis body
Tulis `.claude/share/<f>/body.html` HANYA dari komponen katalog `reference.md` §5. Nol CSS/JS baru. Patuhi §2 (isi & bahasa) dan §6 (Mermaid). Gambar `__IMG:<nama>__`, tombol mockup `__MOCK:<berkas>__`, versi di footer `__HASH__`.

### 5. Rakit
```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/share/assemble.py" --feature-dir "control/features/<f>" \
  --body ".claude/share/<f>/body.html" --images ".claude/share/<f>/img" --mode rancangan \
  --out "control/features/<f>/share.html"
```
- Exit 1 = validasi gagal: tiap masalah satu baris `error:` di stderr, output TIDAK ditulis. Perbaiki body, rakit ulang.
- Sukses: stdout `ok <hash> <bytes> <path>`.

### 6. Periksa
Render seluruh halaman (`reference.md` §9) dan **lihat** hasilnya: gambar terbaca? urutan benar? teks kepanjangan? ada yang kosong? Perbaiki, rakit ulang. Jangan menyerahkan file yang belum kamu lihat.

### 7. `.gitignore` (self-heal)
Untuk baris `control/features/*/share.html` dan `.claude/share/`: cek `grep -qxF` di `<produk>/.gitignore`. Belum ada → `printf '%s\n' '<baris>' >> .gitignore` (buat file bila absen).

### 8. Ringkas
- **Lokasi:** path + ukuran file, dan `open control/features/<f>/share.html`.
- **Cara kirim:** buka dengan dobel-klik di browser (bukan pratinjau WA/Slack). Diagram butuh internet (offline → teks). Rekan klik 💬 / **Pilih**, isi nama, **Copy feedback**, kirim balik, lalu paste ke sini.
- **Data sensitif:** `sensitivity` memuat `pii`/`payments` → ingatkan SEKALI: "isi rancangan & mockup ikut terkirim — pastikan nggak ada data asli."
- **Mode dibangun dari `ship`:** bagian **Hasilnya** (`reference.md` §8) memakai bukti yang SUDAH dirakit `ship` untuk PR (link PR per repo, hasil gate, temuan alignment `critic`). Jangan menjalankan ulang gate.

## B. Mode Triase
1. **Parse** semua blok `=== FEEDBACK share:<f> === … === END ===` (bisa beberapa reviewer sekaligus). Fitur tak ada → STOP.
2. **Cek versi.** Hash di baris `versi:` dibandingkan `python3 "${CLAUDE_PLUGIN_ROOT}/skills/share/assemble.py" --hash-only --feature-dir control/features/<f>`. Beda → peringatkan "feedback buat versi lama (`<hash>`, `<tanggal>`)". Tetap triase, tandai **basi** baris yang bagiannya sudah berubah.
3. **Tabel triase** (bagian · isi ringkas · sumber · tahap saran · rekomendasi), aturan tahap `reference.md` §7.2. Baris `pilih:` = **suara** per grup, bukan keputusan.
4. **User putuskan per baris:** `terima` / `tolak` (+alasan) / `diskusi`. Rekomendasimu jujur (`${CLAUDE_PLUGIN_ROOT}/rules/anti-yes-man.md`): masukan yang bentrok dengan aturan/keputusan tercatat → tandai + rujuk nomornya.
5. **Catat** (append) ke `control/features/<f>/reviews.md`, format `reference.md` §7.3. Kutipan verbatim.
6. **Arahkan:** sebut SATU tahap paling awal di antara butir `terima`. User menjalankannya, lalu `/share <f>` lagi (bagian "Masukan kemarin → jadinya" terisi dari `reviews.md`). Nol butir terima → cukup catat.

## Guardrails
- **Nol tulis ke artefak tahap.** `share` hanya menulis `share.html`, `reviews.md`, scratch `.claude/share/`, dan `.gitignore`. `business.md`/`fanout.md`/`plans`/`mockups` milik `intake`/`fanout`/`plan`.
- **Nggak ngarang.** Kotak "Sekarang" hanya bila `business.md` menyatakan masalahnya. Kutipan masukan verbatim, atau ditulis sebagai topik. Tiap bagian ber-`data-src` ke sumbernya.
- **Nggak menghalangi.** Dipanggil `feature`/`ship`: gagal apa pun (Chrome, validasi yang tak beres) = catatan di ringkasan, status fitur tetap jalan.
- **Template tetap.** Kebutuhan komponen baru = ubah `template.html` di plugin (+ test), bukan CSS/JS di body.
- Lane `fix`/`tweak`/`debt` tidak di-share.
````

- [ ] **Step 4: Tulis `reference.md`**

`plugin/skills/share/reference.md`:
````markdown
# share — Referensi isi, komponen & triase

Dibaca `SKILL.md` sebelum generate/triase. Prototipe acuan: review `venue-tables` revisi 3 (KuyMahjong, 2026-10-13). Desain: `docs/superpowers/specs/2026-10-19-share-feature-review-html-design.md` di repo plugin.

## §1 Bagian, sumber, kapan dilewati

Urutan tetap. Bagian tanpa data **dilewati utuh** (tanpa judul kosong, tanpa "TBD").

| # | Bagian | Sumber | Dilewati bila |
|---|---|---|---|
| 1 | Hero + "Yang gw minta" | `feature.yaml` (nama, `risk`), `fanout.md` (app), revisi kepala `business.md` | tak pernah |
| — | Hasilnya (mode dibangun) | bukti `ship`, `tasks.yaml` | mode rancangan |
| 2 | Masukan kemarin → jadinya | butir `terima` di `reviews.md` sesi ber-hash ≠ hash sekarang. Tak ada → kutipan masukan yang tercatat di `business.md`/`fanout.md`/`plans` | belum pernah ada review/masukan |
| 3 | Apa & kenapa | `business.md` Tujuan, Hasil/Reward, Pengguna | tak pernah (kotak "Sekarang" bisa absen) |
| 4 | Ceritanya | `business.md` Flow/Skenario + `mockups/` | tak ada Flow |
| 5 | Pilih satu | opsi yang **tertulis** menunggu pilihan user (plan/mockup: "dipilih user di gate") | tak ada keputusan terbuka |
| 6 | Kalau ada yang nggak beres | `business.md` Edge/gagal + frame mockup error | tak ada Edge |
| 7 | Keputusan | `business.md` Keputusan (tag revisi) | tak ada Keputusan |
| 8 | Di balik layar | `plans/_shared.md` + `plans/<app>.md` | belum ada plan |
| 9 | Detail | Aturan, `fanout.md`, Out of scope, `mockups/` | per butir: dilewati bila sumbernya tak ada |
| 10 | Footer | — | tak pernah |

"Yang gw minta": ≤ 3 butir bernomor sesuai bagian yang ADA, misalnya ① pilih tata letak (bila §5 ada) ② cek masukan kemarin udah kejawab (bila §2 ada) ③ klik 💬 di mana aja.

## §2 Aturan isi & bahasa

- **Gambar dulu, kata belakangan.** Judul langkah ≤ 1 kalimat, keterangan ≤ 1 kalimat, baris keputusan `pertanyaan → jawaban` pendek. Paragraf = salah.
- Bahasa Indonesia santai ("nggak", "udah", "lo/gw" boleh bila produk memakai gaya itu). Istilah teknis diterjemahkan: "jatah meja", bukan `capacity`. **Nol nama RPC/tabel/kolom/kode error** di luar bagian Detail.
- Nama, jam, tempat, angka **sama dengan dokumen sumber**. Jangan bikin contoh baru.
- **"Sekarang"** (kotak merah) hanya bila `business.md` menyatakan masalah/keadaan sekarang. Kalau tidak, tampilkan cuma "Sesudah fitur ini".
- **Kutipan** (`"…"`, miring) wajib verbatim dari `reviews.md`/dokumen. Masukan tanpa kutipan → tulis sebagai topik, tanpa tanda kutip.
- Tiap elemen ber-`data-fb` WAJIB punya `data-src` yang menunjuk sumbernya: `business.md#Keputusan 18 · Aturan 18`, `plans/venue.md#BoardScreen · mockup venue-tables #opsi-a`.
- `data-fb` = `<bagian>/<slug>`, unik sehalaman. Prefiks bagian: `hasil`, `berubah`, `ringkasan`, `cerita`, `pilihan`, `masalah`, `keputusan`, `balik-layar`, `detail`.
- Risiko yang diterima ditebalkan (`<b>risiko diterima</b>`) di daftar kasus.
- Kelas `label` dilarang di body (bentrok dengan Mermaid). Pakai nama lain.

## §3 Storyboard

- Satu skenario konkret dari Flow `business.md` (venue-tables: "Sabtu 24 Okt di Arkam Mahjong: Meja 1–4 otomatis, 5–6 manual"). Sebut skenarionya di `hsub`.
- **5–7 langkah**, urut waktu. Satu langkah = satu momen yang mengubah sesuatu bagi pengguna. Langkah persiapan sekali jalan boleh jadi langkah 1 (`time`: "sekali di awal").
- Gambar per langkah:
  - 1 tangkapan tablet/desktop **atau**
  - `pair` (2 ponsel) **atau**
  - `pair wide` (tablet + ponsel, misalnya aksi kasir + yang dilihat pemain)
- Langkah yang tak berubah dari revisi sebelumnya → `<span class="same">sama kayak kemarin</span>`.
- Revisi > 1 dengan banyak perubahan: dahulukan langkah yang menunjukkan perubahan. Langkah lama yang masih penting cukup 1.
- Bagian "Masukan kemarin → jadinya" menautkan ke langkah (`<a href="#s3">lihat ③</a>`), jadi tiap langkah ber-`id="sN"`.

## §4 Tangkap layar

Periksa struktur mockup dulu (cari `id` frame, kelas bingkai, routing hash, elemen dekorasi), baru pilih cara.

1. **Frame statis** (paling umum di mockup `plan`): halaman panjang berisi banyak bingkai ber-`id`.
   - tablet: `--select '#f5a .frame' --device tablet`
   - ponsel: `--select '#f10b .phone' --device phone`
   Skrip memindah elemen ke body kosong, mempertahankan sprite `<svg><symbol>`, dan me-reset `transform` (bingkai yang di-*scale* agar muat).
2. **Elemen dekorasi mockup** (garis "batas layar", label anotasi, toolbar): `--hide '.fold' --hide '.g-cap'`. Contoh venue-tables: `.fold` = garis merah putus-putus batas layar tablet.
3. **Routing hash** (mockup satu-layar-banyak-state, misalnya `#atur`, `#walkin/rebut/L`): `--hash 'walkin/rebut/L'`. Chrome mockup (header state, catatan) disembunyikan lewat `--clean-css <file>` atau `--hide`.
4. **Tak bisa diisolasi:** `--full` (halaman penuh, dipangkas).
5. **Mockup berupa gambar** (`.png/.jpg` di `mockups/`): tidak ditangkap. Salin ke `.claude/share/<f>/img/<nama>.<ext>`.
6. Nama gambar: `v-<id>` (tablet/venue), `p-<id>` (ponsel/pemain), atau `<app>-<id>`. Pendek dan stabil.

### §4.5 Tanpa Chrome
Storyboard tetap ditulis, tapi tanpa `<img>`: tiap langkah memakai tombol `<button class="btn" data-mock="__MOCK:<berkas>__">Lihat layar ↗</button>`. `hsub` Ceritanya: "Gambar nggak tersedia di versi ini — buka layarnya lewat tombol." Bagian "Pilih satu" tanpa gambar memakai tombol yang sama per opsi. Sebutkan di ringkasan bahwa Chrome tak ada.

## §5 Katalog komponen

Salin cuplikan apa adanya, lalu ganti isinya. Semua cuplikan di bawah lolos `assemble.py` bila dirakit bersama (diuji `tools/tests/share.test.sh` S8), jadi `data-fb`-nya unik antar-cuplikan.

### Hero
```html
<header class="hero">
  <div class="eyebrow">Review rancangan · sebelum dibangun · revisi 3</div>
  <h1>Papan meja: walk-in &amp; room online satu hitungan</h1>
  <p class="lede">Revisi 3 nambahin jenis meja, room ber-4, dan "Kabari aku", dari masukan kemarin.</p>
  <div class="chips"><span class="chip">venue-tables</span><span class="chip">app pemain + venue + admin + database</span><span class="chip warn">risiko tinggi</span></div>
  <div class="ask">👀 <span><b>Yang gw minta:</b> ① <a href="#pilih">pilih tata letak papan</a> A/B/C ② cek masukan kemarin udah kejawab ③ klik <b>💬</b> di mana aja.</span></div>
</header>
```
Mode dibangun: eyebrow `Udah dibangun · cek sebelum merge · revisi N`, ask `cek hasilnya sebelum merge`. `chip warn` hanya untuk `risk: high`.

### Masukan kemarin → jadinya
```html
<h2 class="h" style="margin-top:28px">Masukan kemarin → jadinya</h2>
<p class="hsub">Yang berubah sejak revisi 2.</p>
<div class="chg">
  <div class="chg-row" data-fb="berubah/saklar" data-src="business.md#Keputusan 17 · Aturan 15"><span class="from">"gak bisa on/off meja, harus on"</span><span class="arr">→</span><span class="to">Owner nggak punya tombol nyala/mati lagi. Papan dinyalain tim KuyMahjong.</span><a href="#s1">lihat ①</a></div>
  <div class="chg-row" data-fb="berubah/kabari" data-src="business.md#Keputusan 19 · Aturan 19"><span class="from">Jam penuh, terus gimana?</span><span class="arr">→</span><span class="to">Tombol "Kabari aku": dapat notif kalau mejanya kebuka lagi.</span><a href="#s4">lihat ④</a></div>
</div>
```

### Apa & kenapa
```html
<h2 class="h">Apa &amp; kenapa</h2>
<p class="hsub">Biar pemain online &amp; tamu yang datang langsung bener-bener sinkron.</p>
<div class="why" data-fb="ringkasan/kenapa" data-src="business.md#Tujuan + Hasil/Reward">
  <div class="why-col before">
    <div class="why-tag">Sekarang</div>
    <ul><li>Walk-in dan room online <b>dihitung terpisah</b></li></ul>
  </div>
  <div class="why-arrow">→</div>
  <div class="why-col after">
    <div class="why-tag">Sesudah fitur ini</div>
    <ul><li><b>Satu jatah meja</b> dipakai bareng walk-in &amp; room online</li></ul>
  </div>
</div>
<div class="facts">
  <div><span>Kasir &amp; owner</span><b>Papan meja + tab "Per meja"</b></div>
  <div><span>Pemain</span><b>Pilih durasi, jenis meja, "Udah ber-4"</b></div>
</div>
```
Tanpa "Sekarang": hapus `why-col before` + `why-arrow`, sisakan `after`.

### Ceritanya
```html
<h2 class="h">Ceritanya</h2>
<p class="hsub">Sabtu 24 Okt di Arkam Mahjong: Meja 1–4 otomatis, Meja 5–6 manual. Klik gambar buat perbesar.</p>
<div class="story">
  <div class="step" id="s1" data-fb="cerita/1-atur-meja" data-src="business.md#R1 + Aturan 15 · mockup venue-tables #f5a">
    <div class="txt"><span class="num">1</span><span class="time">sekali di awal</span>
      <h3>Owner daftarin meja + jenisnya. Papan dinyalain tim KuyMahjong.</h3><p>Owner nggak punya tombol nyala/mati lagi.</p></div>
    <img class="shot" src="__IMG:v-f5a__" alt="Atur meja">
  </div>
  <div class="step" id="s2" data-fb="cerita/2-ber-4" data-src="business.md#R2 · mockup player f10b, venue-tables #f7a">
    <div class="txt"><span class="num">2</span><span class="time">10.00</span>
      <h3>Gita udah ber-4: room langsung terkunci</h3><p>Nggak muncul di feed.</p></div>
    <div class="pair wide">
      <figure><img class="shot" src="__IMG:v-f7a__" alt="Ada meja"><figcaption>Kasir pilih meja</figcaption></figure>
      <figure><img class="shot" src="__IMG:p-f10b__" alt="Udah ber-4"><figcaption>Gita pilih "Udah ber-4"</figcaption></figure>
    </div>
  </div>
  <div class="step" id="s3" data-fb="cerita/3-penuh" data-src="business.md#R3 · mockup player f1, f4">
    <div class="txt"><span class="num">3</span><span class="time">14.00</span><span class="same">sama kayak kemarin</span>
      <h3>Hendra: meja otomatis penuh, manual masih ada</h3><p>Dia tap "Kabari aku".</p></div>
    <div class="pair">
      <figure><img class="shot" src="__IMG:p-f1__" alt="Penuh"><figcaption>Satu baris status</figcaption></figure>
      <figure><img class="shot" src="__IMG:p-f4__" alt="Kabari aku"><figcaption>"Kabari aku" aktif</figcaption></figure>
    </div>
  </div>
</div>
```

### Pilih satu
`data-choice` WAJIB sama dengan `data-fb` grup itu. `data-title` = judul di blok feedback. Maks 2 grup per halaman.
```html
<h2 class="h" id="pilih">Pilih satu: tata letak papan</h2>
<p class="hsub">Datanya sama persis, cuma cara gambarnya beda.</p>
<div class="opts" data-choice="pilihan/papan" data-fb="pilihan/papan" data-title="Tata letak papan (A/B/C)" data-src="plans/venue.md#BoardScreen · mockup venue-tables #opsi-a/b/c">
  <div class="opt" data-val="A">
    <img class="shot" src="__IMG:v-opsi-a__" alt="Opsi A">
    <h3>A · Kartu per jenis</h3>
    <p class="pro">Mirip kemarin, paling cepat dibangun</p>
    <p class="con">Janji berikutnya baru kelihatan kalau di-tap</p>
    <button class="btn pick">Pilih A</button>
  </div>
  <div class="opt" data-val="B">
    <img class="shot" src="__IMG:v-opsi-b__" alt="Opsi B">
    <h3>B · Daftar baris</h3>
    <p class="pro">Padat: 12 meja muat tanpa scroll</p>
    <p class="con">Kurang kebaca dari jauh</p>
    <button class="btn pick">Pilih B</button>
  </div>
</div>
```

### Kalau ada yang nggak beres
```html
<h2 class="h">Kalau ada yang nggak beres</h2>
<p class="hsub">Papan selalu jujur, nggak pernah pura-pura berhasil.</p>
<div class="oops">
  <figure data-fb="masalah/ubah-jenis-ditolak" data-src="business.md#Edge revisi 3 · mockup #f5c">
    <img class="shot" src="__IMG:v-f5c__" alt="Ditolak">
    <figcaption><b>Ubah jenis meja ditolak kalau bikin jatah kurang</b><span>Pindahin dulu room yang udah dijanjiin.</span></figcaption>
  </figure>
  <figure data-fb="masalah/perpanjang-ditolak" data-src="business.md#Edge Case 3 · mockup #r2-extend">
    <img class="shot" src="__IMG:v-r2-extend__" alt="+1 jam ditolak">
    <figcaption><b>+1 jam ditolak kalau semua meja udah kepakai</b><span>Contohnya room 4/4 yang datang jam 20.00.</span></figcaption>
  </figure>
</div>
<details class="more"><summary>▸ 2 kasus lain</summary>
  <ul class="list1">
    <li data-fb="masalah/ber-4-palsu">1 akun ngaku ber-4 <span>→ <b>risiko diterima</b>, venue boleh jawab "Gak ada meja"</span></li>
    <li data-fb="masalah/meja-terakhir">Owner nonaktifin meja terakhir <span>→ ditolak</span></li>
  </ul>
</details>
```

### Keputusan
Tag: `baru` / `dibalik` (keputusan revisi terakhir). Keputusan lama yang tetap → `details.more` + `list1`.
```html
<h2 class="h">Keputusan yang udah diambil</h2>
<p class="hsub">Yang baru di revisi 3.</p>
<div class="decs">
  <div class="dec" data-fb="keputusan/17" data-src="business.md#Keputusan 17"><span class="q">Siapa nyalain papan?</span><span class="a">Tim KuyMahjong, bukan owner</span><span class="tag">dibalik</span></div>
  <div class="dec" data-fb="keputusan/18" data-src="business.md#Keputusan 18"><span class="q">Room ber-4 dikunci kapan?</span><span class="a">Langsung pas dibuat</span><span class="tag">baru</span></div>
</div>
<details class="more"><summary>▸ 1 keputusan sebelumnya yang tetap</summary>
  <ul class="list1">
    <li data-fb="keputusan/9">App pemain ikut baca papan <span>→ jam penuh nggak bisa dipilih</span></li>
  </ul>
</details>
```

### Di balik layar
Satu grup tab per halaman. Panel pertama tanpa `hidden`, sisanya `hidden`. Id `seq-1…seq-n`. Aturan diagram: §6.
```html
<h2 class="h">Di balik layar</h2>
<p class="hsub">Siapa ngomong ke siapa.</p>
<div class="tabs" role="tablist">
  <button data-tab="seq-1" aria-selected="true">Room ber-4</button>
  <button data-tab="seq-2" aria-selected="false">Kabari aku</button>
</div>
<div class="diagram" id="seq-1" data-panel data-fb="balik-layar/ber-4" data-src="plans/_shared.md#12 Room 4 orang">
<pre class="mermaid">
sequenceDiagram
  actor G as Gita
  participant A as App pemain
  participant DB as Database
  G->>A: Udah ber-4, 19.00, 3 jam
  A->>DB: bikin room ber-4
  alt HP belum ada
    DB-->>A: ditolak + alasannya
  else lolos
    DB-->>A: "Meja #35;1 siap · otomatis"
  end
</pre>
</div>
<div class="diagram" id="seq-2" data-panel hidden data-fb="balik-layar/kabari" data-src="plans/_shared.md#11 Kabari aku">
<pre class="mermaid">
sequenceDiagram
  actor H as Hendra
  participant DB as Database
  H->>DB: Kabari aku (19.00 otomatis)
  DB-->>H: notif "Meja kebuka lagi"<br/>(ke semua penunggu)
</pre>
</div>
<p class="note">Disederhanain dari <code>plans/</code>.</p>
```

### Detail
```html
<h2 class="h">Detail</h2>
<p class="hsub">Buat yang mau gali lebih dalam.</p>
<details class="detail"><summary>Semua aturan <span class="hint">2</span></summary><div class="body"><ol class="rules">
  <li>Meja: nama pendek unik, nggak bisa dihapus.</li>
  <li><b>Jatah meja</b>: walk-in + room ≤ jumlah meja, per jenis.</li>
</ol></div></details>
<details class="detail"><summary>App yang kena <span class="hint">2: database duluan</span></summary><div class="body">
  <b>1. Database</b>: meja + jenis, jatah per jenis.<br>
  <b>2. App pemain</b>: durasi, jenis meja, "Udah ber-4".
</div></details>
<details class="detail"><summary>Nggak dikerjain sekarang <span class="hint">2</span></summary><div class="body">
  Harga per jenis meja · pilihan "terserah"
</div></details>
<details class="detail"><summary>Mockup interaktif lengkap <span class="hint">buat yang teliti</span></summary><div class="body">
  <button class="btn" data-mock="__MOCK:venue-tables.html__">App venue (26 frame) ↗</button>
</div></details>
```

### Footer
```html
<footer>Dibuat otomatis dari <code>control/features/venue-tables/</code> · 13 Okt 2026, revisi 3 · versi __HASH__</footer>
```

## §6 Mermaid

- Hanya `sequenceDiagram`, 2–4 diagram. Peserta pakai nama awam (`actor K as Kasir`, `participant DB as Database`). **Nol nama RPC/tabel.**
- `#` diikuti angka WAJIB `#35;` (`"Meja #35;1 siap"`). Mermaid membaca `#1…` sebagai entitas dan memotong teks. Divalidasi `assemble.py`.
- Baris baru di label: `<br/>`, bukan `\n` (divalidasi).
- Cabang sukses/gagal pakai `alt … else … end`, singkat.
- Satu diagram ≤ ~12 pesan. Kalau lebih, pecah jadi dua tab.

## §7 Feedback & triase

### §7.1 Blok dari halaman
```
=== FEEDBACK share:<fitur> ===
versi: <rancangan|dibangun> · revisi <n> · <YYYY-MM-DD> · <hash>
reviewer: <nama | (tanpa nama)>
---
[<bagian>/<id>] <judul>
sumber: <data-src>
pilih: <opsi>            # hanya grup pilihan
> <baris komentar>
=== END ===
```
`[umum]` = Komentar umum (tanpa `sumber:`).

### §7.2 Tahap yang disarankan
Tahap **paling awal** yang memiliki artefak terdampak:

| Komentar menyentuh | Tahap |
|---|---|
| tujuan, pengguna, flow, aturan, keputusan, kasus gagal, scope | `/intake <f>` |
| app/package/vendor yang kena | `/fanout <f>` |
| kontrak, UI, mockup, urutan rilis, diagram | `/plan <f>` |
| penyajian halaman saja (salah ketik, gambar kurang jelas, urutan) | regenerate `/share <f>` |
| `pilih:` | suara untuk gate tahap pemilik opsi (biasanya `/plan`). Catat rekapnya, user yang memutuskan di gate |

### §7.3 `reviews.md`
Append. Satu sesi per paste. Kutipan verbatim; komentar multi-baris digabung dengan ` / `, dan `|` di-escape `\|`.
```markdown
# Review — <fitur>

## 2026-10-14 · Rina · versi 77b1e9f9 (revisi 3, rancangan)
Suara: `pilihan/papan` → B

| Bagian | Komentar | Keputusan | Alasan | Tahap |
|---|---|---|---|---|
| berubah/ber-4 | "Mantap, tapi HP wajib agak ribet" | tolak | HP wajib = Keputusan 24(b), venue harus bisa hubungi rombongan | — |
| cerita/4-kabari | "Notifnya kirim juga ke WA?" | diskusi | butuh kanal baru, di luar scope | — |
| masalah/meja-terakhir | "Owner tetap perlu cara berhenti" | terima | — | /intake |

Arahan: `/intake venue-tables` dulu (1 butir mengubah aturan); `fanout`/`plan` ikut ulang sesudahnya, lalu `/share venue-tables`.
```
Bagian "Masukan kemarin → jadinya" generate berikutnya mengambil baris `terima` dari sesi terakhir yang hash-nya ≠ hash sekarang. Kolom Komentar dipakai sebagai kutipan, dan hasilnya diambil dari artefak yang sudah direvisi.

## §8 Mode dibangun — Hasilnya
Setelah Hero. Sumber: bukti yang dirakit `ship` untuk PR. Manual pada fitur `shipped`: `tasks.yaml` + `feature.yaml` `shipped_at`. PR/gate yang tak diketahui dilewati, bukan ditebak.
```html
<h2 class="h" style="margin-top:28px">Hasilnya</h2>
<p class="hsub">Yang udah dibangun dibanding rancangan.</p>
<div class="facts" data-fb="hasil/ringkas" data-title="Hasilnya" data-src="tasks.yaml · PR · gate ship">
  <div><span>Task</span><b>18/18 selesai</b></div>
  <div><span>PR</span><b><a href="https://github.com/org/repo/pull/12">repo#12</a></b></div>
  <div><span>Gate</span><b>Test, lint, security ✓</b></div>
</div>
<div class="decs" style="margin-top:12px">
  <div class="dec" data-fb="hasil/beda-1" data-src="ship · alignment critic"><span class="q">Rancangan: tab "Per meja" tersembunyi saat papan mati</span><span class="a">Jadinya: tetap tampil, kosong</span><span class="tag">beda</span></div>
</div>
<details class="detail" style="margin-top:12px"><summary>Berkas berubah <span class="hint">2 app</span></summary><div class="body">
  <b>kuymahjong</b>: 14 berkas (+820 −40)<br>
  <b>venue</b>: 22 berkas (+1.310 −95)
</div></details>
```
Tak ada beda → satu baris `dec`: "Beda dari rancangan?" → "Nggak ada".

## §9 Pemeriksaan visual
```bash
CHROME="$(python3 "${CLAUDE_PLUGIN_ROOT}/skills/share/capture.py" --find-chrome)"
"$CHROME" --headless=new --disable-gpu --hide-scrollbars --user-data-dir="$(mktemp -d)" \
  --window-size=1280,12000 --virtual-time-budget=8000 \
  --screenshot="$PWD/.claude/share/<f>/page.png" "file://$PWD/control/features/<f>/share.html"
python3 - ".claude/share/<f>/page.png" <<'PY'
import sys
from PIL import Image
im=Image.open(sys.argv[1]); w,h=im.size; n=0
for y in range(0,h,2400):
    im.crop((0,y,w,min(y+2400,h))).resize((w//2,(min(y+2400,h)-y)//2)).save(sys.argv[1].replace('.png',f'-{n}.jpg'),quality=80); n+=1
PY
```
Lihat tiap potongan (`page-0.jpg`, …). Ruang kosong panjang di bawah = tinggi jendela kelebihan, bukan bug. Cek juga lebar ponsel (`--window-size=390,12000`): satu kolom, tanpa scroll ke samping. Tanpa Pillow → lihat `page.png` utuh.
````

- [ ] **Step 5: Jalankan test, pastikan lulus**

Run: `bash tools/tests/share.test.sh`
Expected: S1–S8 `ok`, `fail=0`. Kalau S8 gagal karena `data-fb` ganda / `#angka`, perbaiki cuplikan di `reference.md`, bukan validatornya.

- [ ] **Step 6: Commit**

```bash
git add plugin/skills/share/SKILL.md plugin/skills/share/reference.md tools/tests/share.test.sh
git commit -m "feat(share): SKILL.md + reference.md — mode generate & triase, katalog komponen"
```

---

### Task 5: Sambungan ke `feature`/`ship`, `.gitignore`, guide, README, kimi

**Files:**
- Modify: `plugin/skills/feature/SKILL.md` (bagian `### 4. Ringkas`)
- Modify: `plugin/skills/ship/SKILL.md` (bagian `### 6. Kirim & tandai (GATE)`, bullet terakhir)
- Modify: `plugin/skills/init/SKILL.md:79`
- Modify: `plugin/skills/upgrade/SKILL.md:32`
- Modify: `plugin/skills/guide/reference.md` (tabel cheatsheet + bagian "Docs & maintenance")
- Modify: `README.md:32` dan blok `## Dokumentasi`
- Modify: `tools/tests/share.test.sh` (sisip bagian `# === sambungan ===`)
- Regenerate: `plugin-kimi/`

**Interfaces:**
- Consumes: skill `share` (Task 4): `share <fitur>` (mode dari pemanggil/status).

- [ ] **Step 1: Tulis test sambungan (failing)**

Sisipkan di atas `# === RINGKASAN ===`:
```bash
# === sambungan ===
grep -q 'share <nama>' "$ROOT/plugin/skills/feature/SKILL.md" && ok "W1 feature langkah 4 memanggil share" || bad "W1 feature tak memanggil share"
grep -q 'share <fitur>' "$ROOT/plugin/skills/ship/SKILL.md" && ok "W2 ship langkah 6 memanggil share" || bad "W2 ship tak memanggil share"
$PY - "$ROOT/plugin/skills/ship/SKILL.md" <<'PY' && ok "W3 ship: share sebelum render-docs" || bad "W3 urutan share/render-docs di ship"
import sys
s=open(sys.argv[1],encoding='utf-8').read()
a=s.find('share <fitur>'); b=s.find('Regenerate doc')
sys.exit(0 if 0<=a<b else 1)
PY
for f in init upgrade; do
  grep -q 'control/features/\*/share.html' "$ROOT/plugin/skills/$f/SKILL.md" && grep -q '.claude/share/' "$ROOT/plugin/skills/$f/SKILL.md" \
    && ok "W4 $f menyebut baris .gitignore share" || bad "W4 $f tanpa baris .gitignore share"; done
grep -q '/share' "$ROOT/plugin/skills/guide/reference.md" && ok "W5 guide/reference.md menyebut /share" || bad "W5 guide tanpa /share"
grep -q '/share' "$ROOT/README.md" && ok "W6 README menyebut /share" || bad "W6 README tanpa /share"
[ -f "$ROOT/plugin-kimi/skills/share/SKILL.md" ] && [ -f "$ROOT/plugin-kimi/skills/share/assemble.py" ] \
  && ok "W7 plugin-kimi memuat skill share" || bad "W7 plugin-kimi belum diregen"

```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `bash tools/tests/share.test.sh`
Expected: W1–W7 `FAIL`.

- [ ] **Step 3: `feature/SKILL.md` langkah 4**

Ganti:
```
### 4. Ringkas
Tampilkan artifact yang dihasilkan (`business.md`, `fanout.md`, `plans/*`). Sarankan langkah berikutnya:
```
dengan:
```
### 4. Ringkas
Invoke skill **`share <nama>`** (mode rancangan) → file review `control/features/<nama>/share.html` yang bisa dikirim ke rekan; feedback mereka di-paste balik ke `/share` untuk ditriase. Gagal (mis. Chrome tak ada) = catatan di ringkasan, **BUKAN** penghalang — status tetap `active`.

Tampilkan artifact yang dihasilkan (`business.md`, `fanout.md`, `plans/*`, `share.html`). Sarankan langkah berikutnya:
```

- [ ] **Step 4: `ship/SKILL.md` langkah 6**

Ganti:
```
- Regenerate doc: invoke skill `render-docs` bila tersedia; bila belum ada (Fase 5), ingatkan user untuk regenerate nanti.
```
dengan:
```
- **File review fitur:** invoke skill `share <fitur>` (mode dibangun) dengan bukti yang sudah dirakit untuk PR (link PR per repo, hasil gate step 2–4.5, temuan alignment `critic`) — rekan bisa cek hasilnya sebelum merge. Gagal = catatan, BUKAN penghalang. Hanya fitur; fix tidak di-share.
- Regenerate doc: invoke skill `render-docs` bila tersedia; bila belum ada (Fase 5), ingatkan user untuk regenerate nanti.
```

- [ ] **Step 5: `init/SKILL.md:79`**

Dua penggantian di baris 79 (paragraf panjang; ganti substring persis).

Ganti:
```
baris `.claude/notify.sh`, `.claude/.unattended*`, dan `.claude/build/` ke `<produk>/.gitignore`
```
dengan:
```
baris `.claude/notify.sh`, `.claude/.unattended*`, `.claude/build/`, `.claude/share/`, dan `control/features/*/share.html` ke `<produk>/.gitignore`
```

Ganti:
```
`.claude/build/` = scratch brief/report/paket-diff per-task `build` (file-handoff), bukan knowledge.
```
dengan:
```
`.claude/build/` = scratch brief/report/paket-diff per-task `build` (file-handoff), bukan knowledge; `.claude/share/` + `share.html` = scratch & hasil generate skill `share` (±2MB per fitur, bisa digenerate ulang), bukan knowledge.
```

- [ ] **Step 6: `upgrade/SKILL.md:32`**

Ganti:
```
- `.gitignore` — punya `.claude/notify.sh` + `.claude/.unattended*` + `.claude/build/` (scratch brief/report/paket-diff file-handoff `build`)?
```
dengan:
```
- `.gitignore` — punya `.claude/notify.sh` + `.claude/.unattended*` + `.claude/build/` (scratch brief/report/paket-diff file-handoff `build`) + `.claude/share/` + `control/features/*/share.html` (scratch & hasil generate `share`)?
```

- [ ] **Step 7: `guide/reference.md`**

Di tabel cheatsheet, ganti:
```
| Doc HTML buat stakeholder | `/render-docs` |
```
dengan:
```
| Doc HTML buat stakeholder | `/render-docs` |
| File review fitur buat rekan + triase feedback-nya | `/share <fitur>` |
```

Di bagian `### Docs & maintenance`, ganti:
```
- `/render-docs` — generate doc HTML human-readable dari knowledge → `control/docs/site/index.html`.
```
dengan:
```
- `/render-docs` — generate doc HTML human-readable dari knowledge → `control/docs/site/index.html`.
- `/share` — satu file HTML review per fitur buat rekan (storyboard mockup, keputusan, 💬 + Copy feedback) → `control/features/<f>/share.html`; paste blok feedback balik → triase ke `reviews.md`. Beda `/render-docs`: per-fitur buat reviewer vs tingkat produk buat stakeholder. Otomatis di akhir `/feature` & `/ship`.
```

- [ ] **Step 8: `README.md`**

Baris 32: ganti `` `render-docs` (doc human-readable).`` dengan `` `render-docs` (doc human-readable), `share` (file review per fitur buat rekan).``

Blok `## Dokumentasi`: ganti
````
```
/render-docs        # generate doc HTML human-readable dari knowledge -> control/docs/site/index.html
```
Otomatis dipanggil `ship`; bisa juga manual untuk preview.
````
dengan
````
```
/render-docs        # generate doc HTML human-readable dari knowledge -> control/docs/site/index.html
/share <fitur>      # satu file HTML review fitur buat rekan -> control/features/<fitur>/share.html
```
`render-docs` otomatis dipanggil `ship`; bisa juga manual untuk preview. `share` otomatis di akhir `feature` (rancangan) & `ship` (dibangun); paste blok "Copy feedback" dari rekan ke `/share` untuk triase.
````

- [ ] **Step 9: Regenerate kimi**

Run: `bash tools/build-kimi.sh && bash tools/tests/build-kimi.test.sh`
Expected: `[build-kimi] OK — plugin-kimi/ regenerated (26 skills)` (25 → 26) dan `fail=0`. Gagal "residu CLAUDE_PLUGIN_ROOT" → ada string itu di `.py`/`.html` share, hapus.

- [ ] **Step 10: Jalankan seluruh test**

Run: `bash tools/tests/share.test.sh && bash plugin/hooks/tests/auto-title.test.sh && bash plugin/hooks/tests/drive.test.sh`
Expected: semua `fail=0`, exit 0.

- [ ] **Step 11: Commit**

```bash
git add plugin/skills/feature/SKILL.md plugin/skills/ship/SKILL.md plugin/skills/init/SKILL.md plugin/skills/upgrade/SKILL.md plugin/skills/guide/reference.md README.md tools/tests/share.test.sh plugin-kimi
git commit -m "feat(share): sambung ke feature & ship, .gitignore init/upgrade, guide, README, regen kimi"
```

---

## Uji penerimaan (manual, sesudah plugin di-reload)

Tidak di-commit. Dijalankan user/eksekutor di produk KuyMahjong (`/Users/mac-098506/Developer/project/mahjong`) setelah plugin versi baru aktif:

1. `/share venue-tables`. Hasil `control/features/venue-tables/share.html` setara prototipe v4:
   - Hero + "Masukan kemarin → jadinya" berisi kutipan verbatim
   - Apa & kenapa, cerita 7 langkah, Pilih satu A/B/C, kasus gagal, keputusan revisi 3, 4 diagram, Detail
   - footer menyebut hash
2. Buka di browser: 💬, Pilih, Copy feedback menghasilkan blok sesuai format.
3. Paste blok contoh berikut ke `/share`. Hasil yang diharapkan:
   - tabel triase dengan `pilihan/papan` sebagai suara
   - `reviews.md` tercatat
   - arahan satu tahap

   ```
   === FEEDBACK share:venue-tables ===
   versi: rancangan · revisi 3 · 2026-10-13 · 77b1e9f9
   reviewer: Tester
   ---
   [pilihan/papan] Tata letak papan (A/B/C)
   sumber: plans/venue.md#BoardScreen · mockup venue-tables #opsi-a/b/c
   pilih: B
   > B paling enak buat kasir
   ---
   [masalah/meja-terakhir] Owner nonaktifin meja terakhir
   > Owner tetap perlu cara berhenti sendiri
   === END ===
   ```
4. `git status` di produk: `share.html` & `.claude/share/` tidak muncul (ter-gitignore), `reviews.md` muncul.
