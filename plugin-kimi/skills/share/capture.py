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
