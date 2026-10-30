#!/usr/bin/env python3
"""assemble.py — rakit ringkasan sinkron HTML dari JSON data (skill `sync`, context-vault).

Claude menulis isi (JSON, skema di reference.md); script ini merakit, meng-escape, dan menyematkan
ke template.html (folder yang sama). Exit: 0 ok (cetak path) · 1 JSON tak valid / kunci wajib hilang
(output tak ditulis) · 2 argumen salah.
"""
from __future__ import annotations

import argparse
import datetime
import html
import json
import os
import sys
from pathlib import Path

TEMPLATE = Path(__file__).with_name('template.html')
REQUIRED = ('since', 'generated', 'repos')
MONTHS = ('Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September',
          'Oktober', 'November', 'Desember')
GROUPS = (('features', 'Fitur baru', 'f', '✦'),
          ('business_rules', 'Aturan bisnis berubah', 'r', '⚑'),
          ('coding_rules', 'Aturan coding baru', 'c', '⌘'))


class DataError(ValueError):
    pass


def e(x) -> str:
    return html.escape('' if x is None else str(x), quote=True)


def _list(d: dict, k: str) -> list:
    v = d.get(k)
    if v is None:
        return []
    if not isinstance(v, list):
        raise DataError(f'`{k}` harus list')
    return [x for x in v if isinstance(x, dict)]


def _int(x) -> int:
    try:
        return max(0, int(x))
    except (TypeError, ValueError):
        return 0


def id_date(iso: str, ref_year: int | None) -> str:
    d = datetime.date.fromisoformat(iso)
    s = f'{d.day} {MONTHS[d.month - 1]}'
    return s if d.year == ref_year else f'{s} {d.year}'


def validate(data) -> None:
    if not isinstance(data, dict):
        raise DataError('data harus objek JSON')
    for k in REQUIRED:
        if k not in data:
            raise DataError(f'kunci wajib hilang: {k}')
    if not isinstance(data['repos'], list):
        raise DataError('`repos` harus list')
    try:
        datetime.date.fromisoformat(str(data['since']))
    except ValueError:
        raise DataError(f"`since` harus YYYY-MM-DD: {data['since']}") from None
    for k in ('features', 'business_rules', 'coding_rules', 'conflicts', 'pointers', 'written'):
        _list(data, k)


def _repo_cards(repos: list) -> str:
    if not repos:
        return ''
    top = max((_int(r.get('human')) + _int(r.get('bot')) for r in repos), default=0) or 1
    cards = []
    for r in repos:
        h, b, people = _int(r.get('human')), _int(r.get('bot')), _int(r.get('people'))
        label = r.get('label') or r.get('key')
        bar = ''.join(f'<i class="{c}" style="width:{n * 100 / top:.1f}%"></i>' for c, n in (('h', h), ('b', b)) if n)
        if h == 0:
            note = 'cuma bot'
        else:
            note = f'{people} orang' if people else f'{h} commit orang'
            note += f', {b} bot' if b else ''
        cards.append(f'<li class="repo{" quiet" if h == 0 else ""}" title="{e(r.get("key"))}"><b>{e(label)}</b>'
                     f'<div class="bar" role="img" aria-label="{h} commit orang, {b} commit bot">{bar}</div>'
                     f'<small>{e(note)}</small></li>')
    return (f'<ul class="repos">{"".join(cards)}</ul>'
            '<div class="legend"><span>commit orang</span><span class="b">commit bot / bump versi</span></div>')


def _item(it: dict) -> str:
    out = f'<div class="item"><span class="app">{e(it.get("app"))}</span><p>{e(it.get("text"))}</p>'
    if it.get('before') not in (None, '') or it.get('after') not in (None, ''):
        out += (f'<div class="ba"><span class="old">{e(it.get("before"))}</span><span aria-hidden="true">→</span>'
                f'<span class="new">{e(it.get("after"))}</span></div>')
    if it.get('pill'):
        pill = str(it['pill'])
        out += f'<span class="pill{" add" if pill.startswith("+") else ""}">{e(pill)}</span>'
    return out + '</div>'


def _conflicts(items: list) -> str:
    if not items:
        return ''
    cards = ''.join(
        f'<article class="cf"><h2>Bentrok sama fitur lo</h2>'
        f'<p class="where">Fitur <code>{e(c.get("feature"))}</code> di <code>{e(c.get("file"))}</code></p>'
        f'<div class="vs"><div><b>master</b>{e(c.get("master"))}</div><div><b>fitur lo</b>{e(c.get("yours"))}</div></div>'
        f'</article>' for c in items)
    return f'<section class="conflicts" aria-label="Bentrok">{cards}</section>'


def render(data: dict) -> str:
    validate(data)
    gen = str(data['generated'])
    try:
        ref_year = int(gen[:4])
    except ValueError:
        ref_year = None
    since = id_date(str(data['since']), ref_year)
    groups = [(k, label, cls, ic, _list(data, k)) for k, label, cls, ic in GROUPS]
    n = sum(len(items) for *_, items in groups)
    title = f'{n} hal baru sejak {since}' if n else f'Nggak ada hal baru sejak {since}'
    repos = data['repos']
    total = sum(_int(r.get('human')) + _int(r.get('bot')) for r in repos if isinstance(r, dict))
    repos = [r for r in repos if isinstance(r, dict)]

    parts = ['<header class="sync-head">']
    if data.get('product'):
        parts.append(f'<p class="prod">Ringkasan sinkron {e(data["product"])}</p>')
    parts.append(f'<h1>{e(title)}</h1>')
    parts.append(f'<p class="sub">{total} commit masuk di {len(repos)} repo. Semua udah dicatat ke '
                 '<code>control/</code>. Di bawah ini cuma yang perlu lo tau.</p>')
    if data.get('stale_note'):
        parts.append(f'<p class="stale">{e(data["stale_note"])}</p>')
    parts.append(_repo_cards(repos))
    parts.append('</header>')
    parts.append(_conflicts(_list(data, 'conflicts')))

    cols = [g for g in groups if g[4]]
    if cols:
        parts.append(f'<div class="groups" style="--cols:{len(cols)}">')
        for _k, label, cls, ic, items in cols:
            parts.append(f'<section class="g"><h2><span class="ic {cls}" aria-hidden="true">{ic}</span>{e(label)}</h2>'
                         + ''.join(_item(it) for it in items) + '</section>')
        parts.append('</div>')

    pointers = _list(data, 'pointers')
    if pointers:
        parts.append('<section class="pointers" aria-label="Perlu skill lain">' + ''.join(
            f'<div class="ptr"><span>{e(p.get("text"))}</span>'
            + (f'<code>{e(p.get("skill"))}</code>' if p.get('skill') else '') + '</div>' for p in pointers)
            + '</section>')

    written, other = _list(data, 'written'), _int(data.get('other_commits'))
    if written or other:
        row = '<section class="written"><h2>Ditulis ke control/</h2>'
        row += ''.join(f'<span class="file">{e(w.get("file"))}<em>{e(w.get("change"))}</em></span>' for w in written)
        if other:
            row += f'<span class="rest">{other} commit lain cuma bot, refactor, atau fix kecil</span>'
        parts.append(row + '</section>')
    parts.append(f'<p class="foot">Dibuat {e(gen)} oleh /sync context-vault.</p>')

    tpl = TEMPLATE.read_text(encoding='utf-8')
    page_title = f'{title} — {data["product"]}' if data.get('product') else title
    return tpl.replace('__TITLE__', e(page_title)).replace('<!-- CONTENT -->', '\n'.join(p for p in parts if p))


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog='assemble.py', description='Rakit ringkasan sinkron HTML.')
    ap.add_argument('--data', required=True)
    ap.add_argument('--out', required=True)
    args = ap.parse_args(argv)
    try:
        with open(args.data, encoding='utf-8') as f:
            data = json.load(f)
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
