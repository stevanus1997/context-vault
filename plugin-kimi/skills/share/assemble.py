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
