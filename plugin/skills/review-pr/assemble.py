#!/usr/bin/env python3
"""assemble.py — rakit laporan review PR HTML dari JSON data (skill `review-pr`, context-vault).

Claude menulis penilaian (JSON, skema di reference.md); script ini menurunkan vonis & skor lapis,
me-layout peta, meng-escape, lalu menyematkan ke template.html (folder yang sama).
Exit: 0 ok (cetak path) · 1 JSON tak valid / kunci wajib hilang (output tak ditulis) · 2 argumen salah.
`--verdict-only` → cetak vonis saja (cukup kunci `findings`).
"""
from __future__ import annotations

import argparse
import html
import json
import os
import re
import sys
from pathlib import Path

TEMPLATE = Path(__file__).with_name('template.html')
REQUIRED = ('title', 'prs', 'findings')
LANES = (('kontrak', 'Kontrak'), ('alur', 'Alur lintas-repo'), ('best_practice', 'Best practice'),
         ('konsistensi', 'Konsistensi'))
LANE_LABEL = dict(LANES)
LEVELS = (('harus', 'Harus dibenerin'), ('saran', 'Saran'), ('info', 'Info'))
LEVEL_LABEL = dict(LEVELS)
LEVEL_ORDER = {k: i for i, (k, _) in enumerate(LEVELS)}
STALE = 'mungkin karena catatan basi'


class DataError(ValueError):
    pass


def e(x) -> str:
    return html.escape('' if x is None else str(x), quote=True)


def inline(x) -> str:
    """Escape, lalu `kode` → <code>kode</code>."""
    return re.sub(r'`([^`]+)`', r'<code>\1</code>', e(x))


def verdict(findings: list) -> str:
    levels = [f.get('level') for f in findings if isinstance(f, dict)]
    if 'harus' in levels:
        return 'Perlu ubah'
    if 'saran' in levels:
        return 'Approve dengan saran'
    return 'Siap approve'


def validate_findings(findings) -> list:
    if not isinstance(findings, list):
        raise DataError('`findings` harus list')
    for i, f in enumerate(findings):
        if not isinstance(f, dict):
            raise DataError(f'findings[{i}] harus objek')
        if f.get('lane') not in LANE_LABEL:
            raise DataError(f'findings[{i}].lane tak dikenal: {f.get("lane")} (pakai {", ".join(LANE_LABEL)})')
        if f.get('level') not in LEVEL_LABEL:
            raise DataError(f'findings[{i}].level tak dikenal: {f.get("level")} (pakai harus/saran/info)')
    return findings


def validate(data) -> None:
    if not isinstance(data, dict):
        raise DataError('data harus objek JSON')
    for k in REQUIRED:
        if k not in data:
            raise DataError(f'kunci wajib hilang: {k}')
    if not isinstance(data['prs'], list):
        raise DataError('`prs` harus list')
    validate_findings(data['findings'])


# --- kepala & vonis --------------------------------------------------------------------------

def _head(data: dict) -> str:
    who = []
    if data.get('author'):
        who.append(f'oleh {e(data["author"])}')
    if data.get('opened'):
        who.append(f'dibuka {e(data["opened"])}')
    out = f'<header class="pr"><h1>{e(data["title"])}</h1>'
    if who:
        out += f'<span class="who">{", ".join(who)}</span>'
    if data.get('ticket'):
        out += f'<span class="tag">{e(data["ticket"])}</span>'
    for p in data['prs']:
        if not isinstance(p, dict):
            continue
        label = f'{e(p.get("label"))} #{e(p.get("number"))}'
        out += (f'<a class="tag" href="{e(p["url"])}" target="_blank" rel="noopener">{label}</a>' if p.get('url')
                else f'<span class="tag">{label}</span>')
    return out + '</header>'


def _subtitle(findings: list) -> str:
    h = sum(1 for f in findings if f['level'] == 'harus')
    s = sum(1 for f in findings if f['level'] == 'saran')
    if h:
        return f'{h} hal harus dibenerin sebelum approve, {s} saran opsional.'
    if s:
        return f'{s} saran opsional, aman di-approve.'
    return 'Nggak ada temuan.'


def _lanes(findings: list) -> str:
    out = []
    for key, label in LANES:
        mine = [f for f in findings if f['lane'] == key and f['level'] in ('harus', 'saran')]
        harus = any(f['level'] == 'harus' for f in mine)
        if not mine:
            dot, cls, sub = '✓', 'd-green', 'aman'
        else:
            first = next(f for f in sorted(mine, key=lambda f: LEVEL_ORDER[f['level']]))
            t = str(first.get('title') or '')
            dot, cls, sub = str(len(mine)), 'd-red' if harus else 'd-amber', t if len(t) <= 28 else t[:27].rstrip() + '…'
        out.append(f'<div class="lane" data-lane="{key}"><span class="dot {cls}">{dot}</span>'
                   f'<div>{e(label)}<small>{e(sub)}</small></div></div>')
    return '<div class="lanes">' + ''.join(out) + '</div>'


# --- peta ------------------------------------------------------------------------------------

def _clip(cx, cy, hw, hh, dx, dy):
    """Titik di tepi kotak (pusat cx,cy) searah (dx,dy)."""
    tx = hw / abs(dx) if dx else float('inf')
    ty = hh / abs(dy) if dy else float('inf')
    t = min(tx, ty)
    return cx + dx * t, cy + dy * t


def map_svg(m) -> str:
    if not isinstance(m, dict):
        return ''
    nodes = [n for n in (m.get('nodes') or []) if isinstance(n, dict) and n.get('id')]
    if len(nodes) < 2:
        return ''
    touched = [n for n in nodes if n.get('touched')][:5]
    others = [n for n in nodes if n not in touched]
    TW, TH, SW, SH = 92, 44, 70, 26
    W = max(400, len(touched) * 104 + 16, len(others) * 80 + 16)
    H = 262 if others else 186
    pos = {}
    for i, n in enumerate(touched):
        step = W / len(touched)
        pos[n['id']] = (step * i + step / 2, 132 if i % 2 else 52, TW / 2, TH / 2)   # zigzag: garis antar-node miring & panjang
    for i, n in enumerate(others):
        step = W / len(others)
        pos[n['id']] = (step * i + step / 2, 230, SW / 2, SH / 2)

    def free(x, y, w):  # label (lebar w, tinggi ±8) tidak menimpa kotak node mana pun
        return all(abs(x - cx) > hw + w / 2 + 2 or abs(y - 4 - cy) > hh + 8 for cx, cy, hw, hh in pos.values())
    parts = [f'<svg viewBox="0 0 {W:.0f} {H}" role="img" aria-label="Peta repo yang disentuh tiket ini">',
             '<defs><marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto">'
             '<path d="M0 0L10 5L0 10z" class="fb"/></marker>'
             '<marker id="ahr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto">'
             '<path d="M0 0L10 5L0 10z" class="fr"/></marker></defs>']
    marks = []
    for ed in m.get('edges') or []:
        if not isinstance(ed, dict) or ed.get('from') not in pos or ed.get('to') not in pos:
            continue
        ax, ay, ahw, ahh = pos[ed['from']]
        bx, by, bhw, bhh = pos[ed['to']]
        dx, dy = bx - ax, by - ay
        if not dx and not dy:
            continue
        x1, y1 = _clip(ax, ay, ahw + 2, ahh + 2, dx, dy)
        x2, y2 = _clip(bx, by, bhw + 4, bhh + 4, -dx, -dy)
        both = ed['from'] in {n['id'] for n in touched} and ed['to'] in {n['id'] for n in touched}
        if ed.get('problem'):
            parts.append(f'<path d="M{x1:.0f} {y1:.0f} L{x2:.0f} {y2:.0f}" class="er" stroke-width="3" '
                         f'stroke-dasharray="6 4" fill="none" marker-end="url(#ahr)"/>')
            mx, my = (x1 + x2) / 2, (y1 + y2) / 2
            marks.append(f'<circle cx="{mx:.0f}" cy="{my:.0f}" r="11" class="fr"/>'
                         f'<text x="{mx:.0f}" y="{my + 4:.0f}" fill="#fff" font-size="13" font-weight="800" '
                         f'text-anchor="middle" font-family="Schibsted Grotesk,system-ui,sans-serif">!</text>')
            if ed.get('label'):
                lw = len(str(ed['label'])) * 7
                lx, ly = next(((mx + ox, my + oy) for ox, oy in ((0, 28), (0, -18), (-lw / 2 - 16, 4), (lw / 2 + 16, 4))
                               if free(mx + ox, my + oy, lw)), (mx, my + 28))
                marks.append(f'<text x="{lx:.0f}" y="{ly:.0f}" class="tr" font-size="11" text-anchor="middle" '
                             f'font-family="JetBrains Mono,ui-monospace,monospace">{e(ed["label"])}</text>')
        else:
            cls, w, mk = ('eb', 2.5, ' marker-end="url(#ah)"') if both else ('eg', 1.5, '')
            parts.append(f'<path d="M{x1:.0f} {y1:.0f} L{x2:.0f} {y2:.0f}" class="{cls}" stroke-width="{w}" fill="none"{mk}/>')
    for n in others:
        x, y, hw, hh = pos[n['id']]
        parts.append(f'<rect x="{x - hw:.0f}" y="{y - hh:.0f}" width="{hw * 2:.0f}" height="{hh * 2:.0f}" rx="8" '
                     f'class="nb sk-g" stroke-width="1.5"/><text x="{x:.0f}" y="{y + 4:.0f}" class="tm" font-size="11" '
                     f'text-anchor="middle" font-family="Schibsted Grotesk,system-ui,sans-serif">{e(n["id"])}</text>')
    for n in touched:
        x, y, hw, hh = pos[n['id']]
        sk = 'sk-r' if n.get('problem') else 'sk-b'
        parts.append(f'<rect x="{x - hw:.0f}" y="{y - hh:.0f}" width="{hw * 2:.0f}" height="{hh * 2:.0f}" rx="10" '
                     f'class="nb {sk}" stroke-width="2.5"/>')
        ty = y + (0 if n.get('sub') else 5)
        parts.append(f'<text x="{x:.0f}" y="{ty:.0f}" class="tx" font-size="14" font-weight="800" text-anchor="middle" '
                     f'font-family="Schibsted Grotesk,system-ui,sans-serif">{e(n["id"])}</text>')
        if n.get('sub'):
            parts.append(f'<text x="{x:.0f}" y="{y + 15:.0f}" class="ts" font-size="10" text-anchor="middle" '
                         f'font-family="Schibsted Grotesk,system-ui,sans-serif">{e(n["sub"])}</text>')
    parts += marks
    parts.append('</svg>')
    return '<div class="map"><p class="cap">Repo yang disentuh tiket ini</p>' + ''.join(parts) + '</div>'


# --- bukti -----------------------------------------------------------------------------------

def _ev_contract(ev: dict) -> str:
    bad = ' class="bad"'
    rows = ''.join(f'<tr{bad if r.get("bad") else ""}><td>{e(r.get("l"))}</td><td>{e(r.get("r"))}</td></tr>'
                   for r in ev.get('rows') or [] if isinstance(r, dict))
    return (f'<table class="cmp"><thead><tr><th>{e(ev.get("left"))}</th><th>{e(ev.get("right"))}</th></tr></thead>'
            f'<tbody>{rows}</tbody></table>')


def _ev_states(ev: dict) -> str:
    states = [s for s in ev.get('states') or [] if isinstance(s, dict) and s.get('name')]
    if not states:
        return ''
    boxes, x = [], 4
    for s in states:
        w = max(70, len(str(s['name'])) * 8 + 22)
        boxes.append((s, x, w))
        x += w + 14
    W = x - 10
    out = [f'<svg viewBox="0 0 {W} 120" role="img" aria-label="Rantai status">']
    for (s, bx, w), nxt in zip(boxes, boxes[1:]):
        out.append(f'<path d="M{bx + w} 56H{nxt[1]}" class="eg" stroke-width="1.5"/>')
    for s, bx, w in boxes:
        cls, tcls = ('st-ok', 'tg') if s.get('ok') else ('st-flag', 'tr') if s.get('flag') else ('st-n', 'tm')
        sw = 2 if s.get('flag') else 1
        out.append(f'<rect x="{bx}" y="40" width="{w}" height="32" rx="8" class="{cls}" stroke-width="{sw}"/>'
                   f'<text x="{bx + w / 2:.0f}" y="61" class="{tcls}" font-size="12" font-weight="600" text-anchor="middle" '
                   f'font-family="Schibsted Grotesk,system-ui,sans-serif">{e(s["name"])}</text>')

    def span(pred):
        sel = [(bx, w) for s, bx, w in boxes if pred(s)]
        return (sel[0][0], sel[-1][0] + sel[-1][1]) if sel else None

    ok, flag = span(lambda s: s.get('ok')), span(lambda s: s.get('flag'))
    if ok and ev.get('ok_label'):
        out.append(f'<path d="M{ok[0]} 30 H{ok[1]}" class="lg" stroke-width="3"/>'
                   f'<text x="{(ok[0] + ok[1]) / 2:.0f}" y="22" class="tg" font-size="11" text-anchor="middle" '
                   f'font-family="Schibsted Grotesk,system-ui,sans-serif">{e(ev["ok_label"])}</text>')
    if flag and ev.get('flag_label'):
        out.append(f'<path d="M{flag[0]} 88 H{flag[1]}" class="er" stroke-width="3" stroke-dasharray="5 4"/>'
                   f'<text x="{(flag[0] + flag[1]) / 2:.0f}" y="106" class="tr" font-size="11" text-anchor="middle" '
                   f'font-family="Schibsted Grotesk,system-ui,sans-serif">{e(ev["flag_label"])}</text>')
    return ''.join(out) + '</svg>'


def _ev_code(ev: dict) -> str:
    hl = ' class="hl"'
    lines = ''.join(f'<div{hl if ln.get("hl") else ""}><span class="n">{e(ln.get("n"))}</span>{e(ln.get("text"))}</div>'
                    for ln in ev.get('lines') or [] if isinstance(ln, dict))
    return f'<div class="code">{lines}</div>' if lines else ''


EVIDENCE = {'contract': _ev_contract, 'states': _ev_states, 'code': _ev_code}


def _finding(f: dict) -> str:
    ev = f.get('evidence')
    body = EVIDENCE.get(ev.get('type'), lambda _: '')(ev) if isinstance(ev, dict) else ''
    txt = (f'<div class="txt"><h3><span class="lv">{LEVEL_LABEL[f["level"]]}</span>{e(f.get("title"))}</h3>'
           f'<p class="loc"><span class="ln">{e(LANE_LABEL[f["lane"]])}</span>{inline(f.get("location"))}</p>')
    if f.get('stale'):
        txt += f'<span class="chip-stale">{STALE}</span>'
    if f.get('comment'):
        txt += (f'<div class="draft"><q>{inline(f["comment"])}</q>'
                f'<button class="copy" type="button" data-copy="{e(f["comment"])}">Copy komentar</button></div>')
    txt += '</div>'
    solo = '' if body else ' solo'
    return f'<article class="f {f["level"]}{solo}">{txt}' + (f'<div class="ev">{body}</div>' if body else '') + '</article>'


def render(data: dict) -> str:
    validate(data)
    findings = data['findings']
    v = verdict(findings)
    vcls = {'Perlu ubah': 'v-red', 'Approve dengan saran': 'v-amber', 'Siap approve': 'v-green'}[v]
    parts = [_head(data)]
    stale = [str(r) for r in data.get('stale_repos') or []]
    if stale:
        parts.append(f'<p class="banner">Catatan control/ ketinggalan di {e(", ".join(stale))} — temuan bertanda mungkin keliru</p>')
    mp = map_svg(data.get('map'))
    parts.append(f'<section class="hero{"" if mp else " solo"}"><div class="verdict {vcls}">'
                 f'<div class="big">{v}</div><p>{_subtitle(findings)}</p>{_lanes(findings)}</div>{mp}</section>')
    ordered = sorted(findings, key=lambda f: LEVEL_ORDER[f['level']])
    if ordered:
        parts.append('<section class="findings">' + ''.join(_finding(f) for f in ordered) + '</section>')
    lane_ok = data.get('lane_ok') if isinstance(data.get('lane_ok'), dict) else {}
    for key, label in LANES:
        busy = any(f['lane'] == key and f['level'] in ('harus', 'saran') for f in findings)
        if not busy and lane_ok.get(key):
            parts.append(f'<div class="ok-row"><b>✓ {e(label)}</b><span>{inline(lane_ok[key])}</span></div>')
    parts.append('<p class="foot">Dibuat oleh /review-pr context-vault. Draft komentar tinggal di-copy, nggak ada yang diposting otomatis.</p>')
    tpl = TEMPLATE.read_text(encoding='utf-8')
    return tpl.replace('__TITLE__', e(f'{v} — {data["title"]}')).replace('<!-- CONTENT -->', '\n'.join(parts))


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog='assemble.py', description='Rakit laporan review PR HTML.')
    ap.add_argument('--data', required=True)
    ap.add_argument('--out')
    ap.add_argument('--verdict-only', action='store_true')
    args = ap.parse_args(argv)
    if not args.verdict_only and not args.out:
        ap.error('--out wajib (kecuali --verdict-only)')
    try:
        with open(args.data, encoding='utf-8') as f:
            data = json.load(f)
        if args.verdict_only:
            if not isinstance(data, dict) or 'findings' not in data:
                raise DataError('kunci wajib hilang: findings')
            print(verdict(validate_findings(data['findings'])))
            return 0
        page = render(data)
    except (OSError, json.JSONDecodeError, DataError) as err:
        print(f'assemble.py: {err}', file=sys.stderr)
        return 1
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, 'w', encoding='utf-8') as f:
        f.write(page)
    print(args.out)
    return 0


if __name__ == '__main__':
    sys.exit(main())
