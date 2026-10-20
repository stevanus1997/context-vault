#!/usr/bin/env python3
"""build_status.py — pembaca status build context-vault (READ-ONLY, Python 3 stdlib saja).

Membaca tasks.yaml / gates.yaml / last-run.md work-item aktif + file kerja .claude/build/,
lalu mengeluarkan snapshot JSON v1 dan teks ringkas (status line, baris progres drive.sh).
Satu pembaca untuk semua permukaan: mod panel plugin (lewat $.process.run, dari folder plugin)
dan drive.sh (salinan di <produk>/.claude/) — jadi angkanya pasti sama.
Skrip ini TIDAK PERNAH menulis file apa pun. Python >= 3.9, tanpa PyYAML.
Spec: docs/superpowers/specs/2026-10-19-build-status-panel-design.md (repo plugin context-vault).
"""
from __future__ import annotations

import argparse
import json
import os
import math
import re
import subprocess
import sys
import time
from pathlib import Path


# --- Parser YAML subset ------------------------------------------------------------------
# Cukup untuk tasks.yaml/gates.yaml/feature.yaml: map & sequence blok, flow sequence skalar,
# skalar polos/ber-kutip (boleh multi-baris), block scalar | > (+ chomping). Semua skalar
# tetap string; key tanpa nilai dan tanpa blok → None. Nilai yang diawali '{' = string mentah.

class YamlError(Exception):
    path: Path | None = None               # file yang rusak (diisi load_yaml)


_BLOCK_HEADER = re.compile(r'^([|>])([+-]?)([1-9]?)([+-]?)\s*(#.*)?$')
_ESCAPES = {'n': '\n', 't': '\t', 'r': '\r', '"': '"', '\\': '\\', '/': '/', '0': '\0',
            ' ': ' ', 'e': '\x1b', 'b': '\b', 'a': '\a', 'f': '\f', 'v': '\v', '\t': '\t'}


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip(' '))


def _is_dash(s: str) -> bool:
    return s == '-' or s.startswith('- ')


def _cut_comment(s: str) -> str:
    """Skalar polos: komentar mulai di '#' yang didahului spasi/tab."""
    m = re.search(r'[ \t]#', s)
    return (s[:m.start()] if m else s).strip()


def _token_start(s: str, i: int) -> bool:
    j = i - 1
    while j >= 0 and s[j] in ' \t':
        j -= 1
    return j < 0 or s[j] in '[{,:'


def _quoted_end(s: str) -> int:
    """s diawali kutip; indeks sesudah kutip penutup, -1 kalau belum ditutup."""
    q, i = s[0], 1
    while i < len(s):
        c = s[i]
        if q == '"' and c == '\\':
            i += 2
            continue
        if c == q:
            if q == "'" and s[i + 1:i + 2] == "'":
                i += 2
                continue
            return i + 1
        i += 1
    return -1


def _fold_lines(inner: str) -> str:
    """Line break mentah di dalam skalar ber-kutip: dilipat jadi spasi, baris kosong = '\\n'."""
    if '\n' not in inner:
        return inner
    parts = inner.split('\n')
    out = parts[0].rstrip(' \t')
    blanks = 0
    for k, p in enumerate(parts[1:], 1):
        last = k == len(parts) - 1
        t = p.lstrip(' \t') if last else p.strip(' \t')
        if t == '' and not last:
            blanks += 1
            continue
        out += ('\n' * blanks if blanks else ' ') + t
        blanks = 0
    return out


def _unescape(s: str) -> str:
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c != '\\' or i + 1 >= len(s):
            out.append(c)
            i += 1
            continue
        e = s[i + 1]
        width = {'x': 2, 'u': 4, 'U': 8}.get(e)
        if width:
            try:
                out.append(chr(int(s[i + 2:i + 2 + width], 16)))
                i += 2 + width
                continue
            except ValueError:
                pass
        out.append(_ESCAPES.get(e, '\\' + e))
        i += 2
    return ''.join(out)


def _unquote(tok: str) -> str:
    inner = _fold_lines(tok[1:-1])
    if tok[0] == "'":
        return inner.replace("''", "'")
    return _unescape(inner)


def _split_key(s: str):
    """'key: sisa' → (key, sisa); None kalau s bukan entri map."""
    if s[:1] in ('"', "'"):
        end = _quoted_end(s)
        if end < 0:
            return None
        tail = s[end:].lstrip(' ')
        if tail == ':' or tail.startswith(': '):
            return _unquote(s[:end]), tail[1:].lstrip(' ')
        return None
    if s[:1] in '[{#' or s == '':
        return None
    body = _cut_comment(s)
    for i, c in enumerate(body):
        if c == ':' and (i + 1 == len(body) or body[i + 1] in ' \t'):
            if i == 0:
                return None
            return body[:i].rstrip(), s[i + 1:].lstrip(' \t')
    return None


def _flow_end(s: str) -> int:
    """s diawali '[' atau '{'; indeks sesudah penutup yang sepadan, -1 kalau belum ditutup."""
    depth, i, q = 0, 0, None
    while i < len(s):
        c = s[i]
        if q:
            if q == '"' and c == '\\':
                i += 2
                continue
            if c == q:
                if q == "'" and s[i + 1:i + 2] == "'":
                    i += 2
                    continue
                q = None
        elif c in '"\'' and _token_start(s, i):
            q = c
        elif c in '[{':
            depth += 1
        elif c in ']}':
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return -1


def _flow_items(inner: str) -> list:
    items, buf, depth, q, i = [], '', 0, None, 0
    while i < len(inner):
        c = inner[i]
        if q:
            if q == '"' and c == '\\':
                buf += inner[i:i + 2]
                i += 2
                continue
            if c == q:
                if q == "'" and inner[i + 1:i + 2] == "'":
                    buf += "''"
                    i += 2
                    continue
                q = None
        elif c in '"\'' and buf.strip() == '':
            q = c
        elif c in '[{':
            depth += 1
        elif c in ']}':
            depth -= 1
        elif c == ',' and depth == 0:
            items.append(buf)
            buf = ''
            i += 1
            continue
        buf += c
        i += 1
    items.append(buf)
    out = []
    for raw in items:
        t = raw.strip()
        if t == '':
            continue
        if t[0] in '"\'' and _quoted_end(t) == len(t):
            out.append(_unquote(t))
        elif t[0] == '[' and _flow_end(t) == len(t):
            out.append(_flow_items(t[1:-1]))
        else:
            out.append(t)
    return out


class _Parser:
    def __init__(self, text: str):
        self.lines = text.replace('\r\n', '\n').replace('\r', '\n').split('\n')
        self.i = 0

    def _tabcheck(self, k: int, upto: int | None = None) -> None:
        ln = self.lines[k]
        lead = ln[:len(ln) - len(ln.lstrip(' \t'))] if upto is None else ln[:upto]
        if '\t' in lead:
            raise YamlError(f"baris {k + 1}: tab di indentasi")

    def _sig(self):
        """Maju ke baris bermakna berikutnya (lewati kosong/komentar); indeksnya atau None."""
        while self.i < len(self.lines):
            ln = self.lines[self.i]
            st = ln.strip()
            if st == '' or st.startswith('#') or (st in ('---', '...') and ln[:1] in '-.'):
                self.i += 1
                continue
            self._tabcheck(self.i)
            return self.i
        return None

    def parse(self):
        j = self._sig()
        if j is None:
            return None
        out = self.block(_indent(self.lines[j]))
        j = self._sig()
        if j is not None:
            raise YamlError(f"baris {j + 1}: indentasi tak terduga")
        return out

    def node(self, pind: int):
        """Blok yang lebih dalam dari pind; None kalau nggak ada."""
        j = self._sig()
        if j is None:
            return None
        ind = _indent(self.lines[j])
        return self.block(ind) if ind > pind else None

    def block(self, ind: int):
        j = self.i
        content = self.lines[j][ind:]
        if _is_dash(content):
            return self.seq(ind)
        if _split_key(content) is not None:
            return self.map(ind)
        self.i = j + 1
        return self.value(content, ind - 1, j, False)

    def map(self, ind: int) -> dict:
        out = {}
        while True:
            j = self._sig()
            if j is None:
                break
            ln = self.lines[j]
            li = _indent(ln)
            if li < ind:
                break
            if li > ind:
                raise YamlError(f"baris {j + 1}: indentasi tak terduga")
            content = ln[ind:]
            if _is_dash(content):
                raise YamlError(f"baris {j + 1}: item list di tengah map")
            kv = _split_key(content)
            if kv is None:
                raise YamlError(f"baris {j + 1}: butuh 'key: nilai'")
            self.i = j + 1
            out[kv[0]] = self.value(kv[1], ind, j, True)
        return out

    def seq(self, ind: int) -> list:
        out = []
        while True:
            j = self._sig()
            if j is None:
                break
            ln = self.lines[j]
            li = _indent(ln)
            if li < ind:
                break
            if li > ind:
                raise YamlError(f"baris {j + 1}: indentasi tak terduga")
            content = ln[ind:]
            if not _is_dash(content):
                break                      # key berikutnya milik map induk (list se-indent key-nya)
            rest = content[1:]
            item_ind = ind + 1 + _indent(rest)
            rest = rest.lstrip(' ')
            if rest == '' or rest.startswith('#'):
                self.i = j + 1
                out.append(self.node(ind))
            elif _is_dash(rest) or _split_key(rest) is not None:
                self.lines[j] = ' ' * item_ind + rest   # '- key: v' membuka koleksi di indent item
                out.append(self.block(item_ind))
            else:
                self.i = j + 1
                out.append(self.value(rest, ind, j, False))
        return out

    def value(self, rest: str, pind: int, j: int, in_map: bool):
        s = rest.strip()
        if s == '' or s.startswith('#'):
            k = self._sig()
            if k is None:
                return None
            ln = self.lines[k]
            li = _indent(ln)
            if li > pind:
                return self.block(li)
            if in_map and li == pind and _is_dash(ln[li:]):
                return self.seq(li)
            return None
        if s[0] in '|>':
            return self.block_scalar(s, pind, j)
        if s[0] in '"\'':
            return self.quoted(s, pind, j)
        if s[0] == '[':
            return self.flow(s, j)
        return self.plain(s, pind)

    def block_scalar(self, header: str, pind: int, j: int) -> str:
        m = _BLOCK_HEADER.match(header)
        if not m:
            raise YamlError(f"baris {j + 1}: header block scalar tak dikenal: {header}")
        folded = m.group(1) == '>'
        chomp = m.group(2) or m.group(4)
        n, k = len(self.lines), self.i
        bi = pind + int(m.group(3)) if m.group(3) else None
        if bi is None:
            t = k
            while t < n and self.lines[t].strip() == '':
                t += 1
            if t < n and _indent(self.lines[t]) > pind:
                bi = _indent(self.lines[t])
        lines = []
        while k < n:
            ln = self.lines[k]
            if ln.strip() == '':
                lines.append('')
                k += 1
                continue
            if bi is None or _indent(ln) < bi:
                break
            self._tabcheck(k, bi)
            lines.append(ln[bi:])
            k += 1
        self.i = k
        end = len(lines)
        while end > 0 and lines[end - 1] == '':
            end -= 1
        body, trailing = lines[:end], len(lines) - end
        if not folded:
            text = '\n'.join(body)
        else:
            chunks, prev, breaks = [], None, 0
            for line in body:
                if line == '':
                    breaks += 1
                    continue
                if prev is None:
                    chunks.append('\n' * breaks)
                elif prev[0] not in ' \t' and line[0] not in ' \t':
                    chunks.append('\n' * breaks if breaks else ' ')
                else:
                    chunks.append('\n' * (breaks + 1))
                chunks.append(line)
                prev, breaks = line, 0
            text = ''.join(chunks)
        if not body:
            return '\n' * trailing if chomp == '+' else ''
        if chomp == '-':
            return text
        if chomp == '+':
            return text + '\n' * (1 + trailing)
        return text + '\n'

    def quoted(self, s: str, pind: int, j: int) -> str:
        buf, k = s, self.i
        while (end := _quoted_end(buf)) < 0:
            if k >= len(self.lines):
                raise YamlError(f"baris {j + 1}: kutip tak ditutup")
            buf += '\n' + self.lines[k]
            k += 1
        tail = buf[end:].strip()
        if tail and not tail.startswith('#'):
            return self.plain(s, pind)     # `"a" + b`: YAML tak valid, tapi ada di tasks.yaml nyata → teks apa adanya
        self.i = k
        return _unquote(buf[:end])

    def flow(self, s: str, j: int) -> list:
        buf, k = s, self.i
        while (end := _flow_end(buf)) < 0:
            if k >= len(self.lines):
                raise YamlError(f"baris {j + 1}: '[' tak ditutup")
            buf += ' ' + self.lines[k].strip()
            k += 1
        self.i = k
        tail = buf[end:].strip()
        if tail and not tail.startswith('#'):
            raise YamlError(f"baris {j + 1}: ada teks sesudah ']'")
        return _flow_items(buf[1:end - 1])

    def plain(self, s: str, pind: int) -> str:
        out, k, blanks = _cut_comment(s), self.i, 0
        while k < len(self.lines):
            ln = self.lines[k]
            st = ln.strip()
            if st == '':
                blanks += 1
                k += 1
                continue
            if _indent(ln) <= pind or st.startswith('#'):
                break
            self._tabcheck(k)
            out += ('\n' * blanks if blanks else ' ') + _cut_comment(st)
            blanks = 0
            k += 1
            self.i = k
        return out


def parse_yaml(text: str):
    """Parse subset YAML → dict/list/str/None (semua skalar string). Rusak → YamlError."""
    return _Parser(text).parse()


def load_yaml(path: Path):
    """None kalau file nggak ada; YamlError (memuat path) kalau rusak/nggak kebaca."""
    path = Path(path)
    try:
        return parse_yaml(path.read_text(encoding='utf-8'))
    except FileNotFoundError:
        return None
    except (OSError, UnicodeDecodeError, YamlError) as e:
        err = YamlError(f"{path}: {e}")
        err.path = path
        raise err from None


# --- Snapshot v1 ---------------------------------------------------------------------------
# Skema dikunci (dicerminkan plugin/types/index.d.ts). Aturan: spec §5.

HELD = ('blocked', 'needs_human')
FRESH_ERROR_S = 60     # file rusak yang baru diubah = mungkin setengah tertulis → exit 2 (mod pakai hasil terakhir)
HB_FRESH_S = 120       # ticker drive.sh men-touch drive.json tiap tick; lebih lama dari ini = basi (crash/reboot, PID bisa kepakai ulang)
QUIET_MIN = 90         # menit tanpa aktivitas file sebelum task in_progress dianggap diam — implementer attended baru
                       # nulis report saat selesai; 30 mnt menandai ~14% task nyata yang masih jalan sebagai diam


def _dict(x) -> dict:
    return x if isinstance(x, dict) else {}


def _list(x) -> list:
    if isinstance(x, list):
        return x
    return [] if x is None or x == '' else [x]


def _str(x) -> str:
    return x if isinstance(x, str) else ''


def _mtime(p: Path) -> float | None:
    try:
        return p.stat().st_mtime
    except OSError:
        return None


def fmt_dur(seconds: float) -> str:
    s = int(seconds)
    if s < 60:
        return '<1m'
    if s < 3600:
        return f"{s // 60}m"
    h, m = divmod(s // 60, 60)
    return f"{h}j{m}m" if m else f"{h}j"


def weight(task: dict) -> int:
    """Bobot cap-volume build (reference §D)."""
    nfiles = len(_list(task.get('files')))
    if task.get('mockup') or task.get('unit') == 'integration' or nfiles > 4:
        return 3
    return 2 if nfiles >= 3 else 1


def _heartbeat(scratch: Path, now: float):
    """drive.json hidup → dict-nya; file absen/rusak/basi/PID mati → None."""
    mt = _mtime(scratch / 'drive.json')
    if mt is None or now - mt > HB_FRESH_S:
        return None
    try:
        hb = json.loads((scratch / 'drive.json').read_text(encoding='utf-8'))
        pid = int(hb['pid'])
        if pid <= 0:
            return None
        os.kill(pid, 0)
    except PermissionError:
        return hb                          # proses ada, cuma bukan milik kita
    except (OSError, ValueError, KeyError, TypeError):
        return None
    return hb


def _scratch(root: Path, kind: str, name: str) -> Path:
    base = root / '.claude' / 'build'
    if kind == 'fix' and (base / 'fixes' / name).is_dir():
        return base / 'fixes' / name
    return base / name


def _item(root: Path, kind: str, wdir: Path, now: float, quiet_min: int) -> dict:
    name = wdir.name
    tasks_path = wdir / 'tasks.yaml'
    raw = load_yaml(tasks_path)
    mt = _mtime(tasks_path)
    if mt is not None and now - mt <= FRESH_ERROR_S and not isinstance(_dict(raw).get('milestones'), list):
        # baru ditulis tapi kosong / tanpa milestones = kemungkinan besar setengah tertulis (parse-nya "valid")
        err = YamlError(f"{tasks_path}: kosong / tanpa milestones — mungkin setengah tertulis")
        err.path = tasks_path
        raise err
    doc = _dict(raw)
    gates_doc = _dict(load_yaml(wdir / 'gates.yaml'))
    scratch = _scratch(root, kind, name)
    hb = _heartbeat(scratch, now) if kind == 'feature' else None

    stamps = [_mtime(wdir / f) for f in ('tasks.yaml', 'gates.yaml', 'last-run.md')]
    if scratch.is_dir():
        stamps += [_mtime(f) for f in scratch.iterdir() if f.is_file()]
    last_activity = max([s for s in stamps if s is not None], default=0.0)
    quiet = hb is None and now - last_activity > quiet_min * 60

    milestones = [m for m in _list(doc.get('milestones')) if isinstance(m, dict)]
    tasks = [t for m in milestones for t in _list(m.get('tasks')) if isinstance(t, dict)]
    status = {_str(t.get('id')): _str(t.get('status')) for t in tasks}

    def deps_of(t: dict) -> list:
        return [d for d in _list(t.get('deps')) if isinstance(d, str)]

    deps = {_str(t.get('id')): deps_of(t) for t in tasks}

    def reaches(tid: str, target: str) -> bool:
        seen, stack = set(), list(deps.get(tid, []))
        while stack:
            d = stack.pop()
            if d == target:
                return True
            if d not in seen:
                seen.add(d)
                stack.extend(deps.get(d, []))
        return False

    held, held_reason = [], {}
    for t in tasks:
        tid, st = _str(t.get('id')), _str(t.get('status'))
        if st not in HELD:
            continue
        manual = [x for x in _list(t.get('manual')) if isinstance(x, str)]
        reason = t.get('hold') if isinstance(t.get('hold'), str) and t.get('hold') else (manual[0] if manual else None)
        held_reason[tid] = reason
        blocks = [_str(o.get('id')) for o in tasks
                  if o is not t and o.get('status') != 'done' and reaches(_str(o.get('id')), tid)]
        held.append({'id': tid, 'unit': _str(t.get('unit')), 'status': st, 'reason': reason, 'blocks': blocks})

    blocked = {h['id'] for h in held} | {b for h in held for b in h['blocks']}
    samples, pre = [], []                  # bahan estimasi: detik per poin bobot + (unit, bobot, elapsed)
    for t in tasks:
        tid, st = _str(t.get('id')), _str(t.get('status'))
        brief = _mtime(scratch / f"task-{tid}-brief.md")
        if st == 'done':
            report = _mtime(scratch / f"task-{tid}-report.md")
            if brief is not None and report is not None and report > brief:
                samples.append((report - brief) / weight(t))
        elif tid not in blocked:
            # task diam (sesi crash / nunggu jawaban): elapsed-nya basi → hitung bobot penuh, jangan dikurangi
            el = now - brief if st == 'in_progress' and brief is not None and not quiet else None
            pre.append((_str(t.get('unit')), weight(t), el))

    lanes, out_ms = [], []
    for m in milestones:
        rows = []
        for t in (x for x in _list(m.get('tasks')) if isinstance(x, dict)):
            tid, st = _str(t.get('id')), _str(t.get('status'))
            row = {'id': tid, 'unit': _str(t.get('unit')), 'desc': _str(t.get('desc')), 'status': st,
                   'elapsed': None, 'phase': None, 'quiet': False, 'quiet_for': None,
                   'reason': held_reason.get(tid) if st in HELD else None, 'waiting_on': []}
            if st == 'in_progress':
                brief = _mtime(scratch / f"task-{tid}-brief.md")
                report = _mtime(scratch / f"task-{tid}-report.md")
                row['elapsed'] = fmt_dur(now - brief) if brief is not None else None
                row['phase'] = 'impl' if brief is not None and report is None else None
                if quiet:
                    row['quiet'], row['quiet_for'] = True, fmt_dur(now - last_activity)
                lanes.append({k: row[k] for k in ('id', 'unit', 'desc', 'elapsed', 'phase', 'quiet', 'quiet_for')})
            elif st == 'pending':
                row['waiting_on'] = [d for d in deps_of(t) if status.get(d) != 'done']
            rows.append(row)
        out_ms.append({'id': _str(m.get('id')), 'title': _str(m.get('title')),
                       'done': sum(r['status'] == 'done' for r in rows), 'total': len(rows), 'tasks': rows})

    gates = [{'id': _str(g.get('id')), 'segment': _str(g.get('segment')), 'reason': _str(g.get('reason'))}
             for g in _list(gates_doc.get('gates')) if isinstance(g, dict) and g.get('status') == 'queued']
    drive = None
    if hb is not None:
        try:
            drive = {'round': int(hb.get('round', 0)), 'elapsed': fmt_dur(now - float(hb.get('started', now))),
                     'max': f"{hb.get('max_hours', '?')}j"}
        except (TypeError, ValueError):
            drive = {'round': 0, 'elapsed': '', 'max': f"{hb.get('max_hours', '?')}j"}
    try:
        rel = wdir.relative_to(root).as_posix()
    except ValueError:
        rel = wdir.as_posix()
    return {
        'kind': kind, 'name': name, 'dir': rel,
        'mode': 'unattended' if hb is not None else 'attended', 'drive': drive,
        'done': sum(t.get('status') == 'done' for t in tasks), 'total': len(tasks),
        'running': hb is not None or any(not ln['quiet'] for ln in lanes),
        'lanes': lanes, 'held': held, 'gates': gates, 'eta': None,
        'milestones': out_ms, 'drive_line': '',
        '_show': bool(lanes or hb is not None or gates or held),
        '_mtime': _mtime(wdir / 'tasks.yaml') or 0.0,
        '_has_tasks': (wdir / 'tasks.yaml').is_file(),
        '_wdir': wdir, '_eta': (samples, pre),
    }


def _active_items(root: Path, guard) -> list[tuple[str, Path]]:
    out = []
    for kind, sub, manifest, ok in (('feature', 'features', 'feature.yaml', ('active',)),
                                    ('fix', 'fixes', 'fix.yaml', ('open', 'diagnosed'))):
        for mf in sorted((root / 'control' / sub).glob(f'*/{manifest}')):
            if _dict(guard(lambda: load_yaml(mf), mf.parent)).get('status') in ok:
                out.append((kind, mf.parent))
    return out


def _lane_keys(root: Path, guard):
    """unit → kunci lane: '__integration__', toplevel git repo unit (1 task in-flight per repo), atau 'root'."""
    paths, cache = None, {}

    def key(unit: str) -> str:
        nonlocal paths
        if unit == 'integration':
            return '__integration__'
        if unit not in cache:
            if paths is None:
                ws = _dict(guard(lambda: load_yaml(root / 'control' / 'workspace.yaml'), root / 'control'))
                paths = {e['name']: e['path'] for e in _list(ws.get('apps')) + _list(ws.get('packages'))
                         if isinstance(e, dict) and isinstance(e.get('name'), str) and isinstance(e.get('path'), str)}
            cache[unit] = 'root'
            if unit in paths:
                try:
                    r = subprocess.run(['git', '-C', str(root / paths[unit]), 'rev-parse', '--show-toplevel'],
                                       capture_output=True, text=True, timeout=5)
                    if r.returncode == 0 and r.stdout.strip():
                        cache[unit] = r.stdout.strip()
                except (OSError, subprocess.SubprocessError):
                    pass
        return cache[unit]
    return key


def estimate(rows: list[tuple[str, int, float | None]], samples: list[float]) -> tuple[float, float] | None:
    """Rentang sisa (detik): per lane jumlah bobot × laju − elapsed; ambil lane terberat + integration."""
    if len(samples) < 3 or not rows:
        return None
    xs, n = sorted(samples), len(samples)

    def q(p: float) -> float:
        pos = p * (n - 1)
        i = int(pos)
        return xs[i] if i + 1 >= n else xs[i] + (xs[i + 1] - xs[i]) * (pos - i)

    low_rate = q(0.25) * max(0.5, 1 - 1 / n)
    high_rate = q(0.75) * (1 + 1 / n)
    lanes = {}
    for key, w, el in rows:
        acc = lanes.setdefault(key, [0.0, 0.0])
        acc[0] += max(0.0, w * low_rate - (el or 0))
        acc[1] += max(0.0, w * high_rate - (el or 0))
    integ = lanes.pop('__integration__', [0.0, 0.0])
    return (max((v[0] for v in lanes.values()), default=0.0) + integ[0],
            max((v[1] for v in lanes.values()), default=0.0) + integ[1])


def eta_text(low_s: float, high_s: float) -> str:
    lo = max(1, math.floor(low_s / 60 / 5) * 5)
    hi = max(lo + 5, math.ceil(high_s / 60 / 5) * 5)
    if hi < 60:
        return f"~{lo}–{hi}m"

    def mins(m: int) -> str:
        if m < 60:
            return f"{m}m"
        h, r = divmod(m, 60)
        return f"{h}j{r}m" if r else f"{h}j"
    return f"~{mins(lo)}–{mins(hi)}"


def status_line(item: dict, others: int) -> str:
    parts = [f"{item['name']} {item['done']}/{item['total']}"]
    lane = 'lane' if any(not ln['quiet'] for ln in item['lanes']) else 'diam'
    for n, label in ((len(item['lanes']), lane), (len(item['held']), 'ketahan'), (len(item['gates']), 'gate')):
        if n:
            parts.append(f"{n} {label}")
    if item['eta']:
        parts.append(item['eta']['text'])
    if others:
        parts.append(f"+{others} build lain")
    return ' · '.join(parts)


def drive_line(item: dict) -> str:
    drive, eta = item['drive'], item['eta']
    no_tasks = item['total'] == 0 and not item.get('_has_tasks', True)
    parts = [
        f"putaran {drive['round']}" if drive else '',
        'tasks.yaml belum ada' if no_tasks else f"{item['done']}/{item['total']}",
        '▸ ' + ', '.join(f"{ln['id']} {ln['unit']}" for ln in item['lanes']) if item['lanes'] else '',
        f"⏸ {len(item['held'])}" if item['held'] else '',
        f"◆ {len(item['gates'])}" if item['gates'] else '',
        drive['elapsed'] if drive else '',
        (f"sisa {eta['text']}" if eta['text'].startswith('~') else eta['text']) if eta else '',
    ]
    return ' · '.join(p for p in parts if p)


def _last_run(path: Path) -> dict | None:
    """Header mesin last-run.md (baris `key: nilai` teratas); field absen → None."""
    mt = _mtime(path)
    if mt is None:
        return None
    try:
        text = path.read_text(encoding='utf-8', errors='replace')
    except OSError:
        return None
    out = {'outcome': None, 'review': None, 'blockers': None, 'reason': None, 'mtime': mt}
    for line in text.splitlines():
        m = re.match(r'^([a-z_]+):\s*(.*?)\s*$', line)
        if not m:
            break
        k, v = m.groups()
        if k == 'reason':
            out[k] = v
        elif k in ('outcome', 'review', 'blockers') and v:
            out[k] = v.split()[0]
    return out


def alerts_for(name: str, dir: str, held: list[dict], gates: list[dict], last_run: dict | None) -> list[dict]:
    """Kejadian yang butuh perhatian (spec D6); key stabil supaya mod bisa dedup toast."""
    out = []
    for h in held:
        text = f"⏸ {name} · {h['id']} {h['status']}"
        if h['reason']:
            text += f" — {h['reason']}"
        if h['blocks']:
            text += f", nahan {len(h['blocks'])} task"
        out.append({'key': f"held|{dir}|{h['id']}|{h['status']}|{h['reason'] or ''}", 'text': text})
    for g in gates:
        out.append({'key': f"gate|{dir}|{g['id']}",
                    'text': f"◆ {name} · gate {g['id']} antri — {g['segment']}: {g['reason']}"})
    oc = (last_run or {}).get('outcome')
    if oc in ('done', 'review', 'halt'):
        if oc == 'done':
            text = f"✓ {name} · build selesai — siap /ship"
        elif oc == 'review':
            rv, bl = last_run['review'] or '?', last_run['blockers'] or '?'
            text = f"🔔 {name} · build berhenti — {rv} gate + {bl} blocker nunggu lo"
        else:
            text = f"⚠ {name} · build halt — {last_run['reason'] or '?'}"
        out.append({'key': f"stop|{dir}|{oc}|{int(last_run['mtime'])}", 'text': text})
    return out


def snapshot(root: Path, now: float, work_item: str | None = None, quiet_min: int = QUIET_MIN) -> dict:
    root = Path(root).resolve()
    errors = []

    def guard(load, wdir: Path):
        """File rusak di satu work-item tak boleh menggelapkan yang lain: rusak & LAMA → lewati + catat;
        rusak & baru diubah (mungkin setengah tertulis) → YamlError → exit 2, mod pakai hasil terakhir."""
        try:
            return load()
        except YamlError as e:
            mt = _mtime(e.path) if e.path else None
            if work_item or mt is None or now - mt <= FRESH_ERROR_S:
                raise
            errors.append({'dir': wdir.relative_to(root).as_posix(), 'message': str(e).replace(f"{root}/", '')})
            return None

    if work_item:
        wdir = Path(work_item)
        wdir = (wdir if wdir.is_absolute() else root / wdir).resolve()
        kind = 'fix' if wdir.parent.name == 'fixes' else 'feature'
        every = shown = [_item(root, kind, wdir, now, quiet_min)]
    else:
        every = [it for kind, d in _active_items(root, guard)
                 if (it := guard(lambda: _item(root, kind, d, now, quiet_min), d)) is not None]
        shown = sorted((it for it in every if it['_has_tasks'] and it['_show']), key=lambda it: -it['_mtime'])
    alerts = [a for it in every
              for a in alerts_for(it['name'], it['dir'], it['held'], it['gates'], _last_run(it['_wdir'] / 'last-run.md'))]
    lane = _lane_keys(root, guard)
    for it in shown:
        samples, pre = it['_eta']
        est = estimate([(lane(u), w, el) for u, w, el in pre], samples) if len(samples) >= 3 and pre else None
        if est is not None:
            note = '+ ' + ', '.join(h['id'] for h in it['held']) + ' nunggu lo' if it['held'] else None
            # batas atas 0 = yang tersisa cuma task jalan yang sudah lewat estimasi → jangan nyangkut di "~1–6m"
            it['eta'] = {'text': eta_text(*est) if est[1] > 0 else 'lewat estimasi', 'held_note': note}
        it['drive_line'] = drive_line(it)
    for it in every:
        for k in [k for k in it if k.startswith('_')]:
            del it[k]
    return {'v': 1, 'items': shown, 'alerts': alerts,
            'status_line': status_line(shown[0], len(shown) - 1) if shown else None, 'errors': errors}


# --- Ringkasan state controller build (--format task|carry) --------------------------------
# Controller build pegang PETA, bukan isi file: entri task & titipan dibaca lewat sini.
# Spec: docs/superpowers/specs/2026-10-20-build-lean-controller-design.md §4.4–§4.5.

LEGACY_CARRY = '_carry-notes.md'


def _work_item(root: Path, work_item: str) -> tuple[str, Path]:
    wdir = Path(work_item)
    wdir = (wdir if wdir.is_absolute() else root / wdir).resolve()
    return ('fix' if wdir.parent.name == 'fixes' else 'feature'), wdir


def _rel(root: Path, p: Path) -> str:
    try:
        return p.relative_to(root).as_posix()
    except ValueError:
        return p.as_posix()


def _tasks(doc: dict) -> list[tuple[dict, dict]]:
    """Pasangan (milestone, task) urut dokumen."""
    return [(m, t) for m in _list(doc.get('milestones')) if isinstance(m, dict)
            for t in _list(m.get('tasks')) if isinstance(t, dict)]


def task_entries(root: Path, work_item: str, ids: list[str]) -> dict:
    root = Path(root).resolve()
    _, wdir = _work_item(root, work_item)
    pairs = {_str(t.get('id')): (m, t) for m, t in _tasks(_dict(load_yaml(wdir / 'tasks.yaml')))}
    out = []
    for i in ids:
        if i not in pairs:
            raise YamlError(f"task tak dikenal: {i}")
        m, t = pairs[i]
        out.append({**t, 'milestone': _str(m.get('id'))})
    return {'work_item': _rel(root, wdir), 'tasks': out}


def _carry_hits(note_for: str, want: str) -> bool:
    """Titipan ber-`for:` note_for relevan buat target want? gate:<M> ⊇ gate:<M>/<unit>."""
    if note_for == want:
        return True
    if want.startswith('gate:'):
        ms, _, unit = want[5:].partition('/')
        return note_for == f"gate:{ms}" if unit else note_for.startswith(f"gate:{ms}/")
    return False


def _legacy_token(target: str, done: set):
    if target.startswith('gate:'):
        return re.compile(rf"\b{re.escape(target[5:].partition('/')[0])}\b")
    if target == 'ship':
        return re.compile(r'(?i)\bship\b')
    if target == 'simplify':
        return re.compile(r'(?i)\b(simplify|7a)\b')
    return None if target in done else re.compile(rf"\b{re.escape(target)}\b")


def _carry_doc(root: Path, work_item: str):
    """(rel, done-ids, entri carry.yaml | None, baris legacy | None). Legacy tetap dibaca selama carry.yaml
    belum ber-`legacy_converted:` — titipan pertama yang ditulis sebelum konversi tak boleh menggelapkannya."""
    root = Path(root).resolve()
    kind, wdir = _work_item(root, work_item)
    done = {_str(t.get('id')) for _, t in _tasks(_dict(load_yaml(wdir / 'tasks.yaml'))) if t.get('status') == 'done'}
    entries, converted = None, False
    if (wdir / 'carry.yaml').is_file():
        doc = _dict(load_yaml(wdir / 'carry.yaml'))
        entries = [n for n in _list(doc.get('notes')) if isinstance(n, dict)]
        converted = bool(doc.get('legacy_converted'))
    lines = None
    legacy = _scratch(root, kind, wdir.name) / LEGACY_CARRY
    if not converted and legacy.is_file():
        raw = [ln.rstrip() for ln in legacy.read_text(encoding='utf-8', errors='replace').splitlines()]
        lines = [ln for ln in raw if ln.strip() and not ln.lstrip().startswith('#')]
    return _rel(root, wdir), done, entries, lines


def _active(note: dict, done: set) -> bool:
    return not note.get('closed') and _str(note.get('for')) not in done


def carry_notes(root: Path, work_item: str, targets: list[str]) -> dict:
    rel, done, entries, lines = _carry_doc(root, work_item)
    notes = [n for n in entries or [] if _active(n, done) and any(_carry_hits(_str(n.get('for')), t) for t in targets)]
    toks = [tok for tok in (_legacy_token(t, done) for t in targets) if tok is not None]
    notes += [{'line': ln} for ln in lines or [] if any(tok.search(ln) for tok in toks)]
    source = '+'.join(s for s, x in (('carry.yaml', entries), ('legacy', lines)) if x is not None) or 'none'
    return {'work_item': rel, 'source': source, 'notes': notes}


# --- Ringkasan state controller build (--format controller) --------------------------------
# Peta 1 baris/task + READY per repo + hold/gate + staleness + reuse basi + jumlah titipan.
# Keputusan atas hasilnya (WARN/STOP/hold) tetap di controller (SKILL build step 1).

DESC_MAX = 80


def _flow_map(s: str) -> dict:
    """'{ db: main, orm: x }' → {'db': 'main', 'orm': 'x'}; bukan flow map → {}."""
    s = s.strip()
    if not (s.startswith('{') and _flow_end(s) == len(s)):
        return {}
    out = {}
    for raw in _flow_items(s[1:-1]):
        kv = _split_key(raw.strip()) if isinstance(raw, str) else None
        if kv is None:
            continue
        k, v = kv
        v = v.strip()
        out[k] = _unquote(v) if v[:1] in '"\'' and _quoted_end(v) == len(v) else v
    return out


def _as_map(x) -> dict:
    """Map blok, atau flow map yang oleh parser subset dibiarkan string mentah."""
    return x if isinstance(x, dict) else _flow_map(x) if isinstance(x, str) else {}


def schema_owner(ws: dict, unit: str) -> str:
    """plugin/rules/db-ownership.md: databases[name == app.stack.db].owner, selainnya unit (legacy)."""
    for app in _list(ws.get('apps')):
        if isinstance(app, dict) and app.get('name') == unit:
            db = _as_map(app.get('stack')).get('db')
            for d in _list(ws.get('databases')):
                if isinstance(d, dict) and isinstance(db, str) and db and d.get('name') == db:
                    owner = d.get('owner')
                    return owner if isinstance(owner, str) and owner else unit
    return unit


def effective_risk(feature: dict) -> str:
    """risk low|normal|high (absen/typo → normal); sensitivity payments = floor high (hard)."""
    risk = _str(feature.get('risk'))
    risk = risk if risk in ('low', 'normal', 'high') else 'normal'
    if risk != 'high' and 'payments' in _list(feature.get('sensitivity')):
        return 'high (payments)'
    return risk


def staleness(wdir: Path, kind: str) -> str:
    tm = _mtime(wdir / 'tasks.yaml')
    if tm is None:
        return '—'
    if kind == 'fix':
        newer = [f for f in ('fix.yaml', 'notes.md') if (_mtime(wdir / f) or 0) > tm]
        return 'STALE ' + ', '.join(f"{f} > tasks.yaml" for f in newer) if newer else 'OK'
    newer = [p for p in sorted((wdir / 'plans').glob('*.md')) if (_mtime(p) or 0) > tm]
    if newer:
        return 'STALE ' + ', '.join(f"plans/{p.name} > tasks.yaml" for p in newer)
    return 'WARN business.md > tasks.yaml' if (_mtime(wdir / 'business.md') or 0) > tm else 'OK'


def _schema_tables(root: Path, owner: str):
    """Nama tabel (heading '## ') di proyeksi control/schema/<owner>.md; absen/stub (nol heading) → None."""
    p = root / 'control' / 'schema' / f"{owner}.md"
    try:
        text = p.read_text(encoding='utf-8', errors='replace')
    except OSError:
        return None
    names = {ln[3:].split()[0].strip('`') for ln in text.splitlines() if ln.startswith('## ') and ln[3:].split()}
    return names or None


def controller_text(root: Path, work_item: str) -> str:
    root = Path(root).resolve()
    kind, wdir = _work_item(root, work_item)
    rel = _rel(root, wdir)
    doc = _dict(load_yaml(wdir / 'tasks.yaml'))
    ws = _dict(load_yaml(root / 'control' / 'workspace.yaml'))
    tasks = [t for _, t in _tasks(doc)]
    tid = lambda t: _str(t.get('id'))  # noqa: E731
    unit = lambda t: _str(t.get('unit'))  # noqa: E731
    st = {tid(t): _str(t.get('status')) for t in tasks}
    deps = lambda t: [d for d in _list(t.get('deps')) if isinstance(d, str)]  # noqa: E731
    lane = _lane_keys(root, lambda load, _wdir: load())
    root_repo = []                                 # lazy: toplevel git root produk (monorepo) — dihitung sekali

    def label(u: str) -> str:
        """Nama repo = lane dispatch (1 task in-flight per repo). Unit tanpa path git sendiri tinggal di repo
        root produk kalau root itu git (monorepo) — jangan jadi lane 'root' terpisah dari app di repo yang sama."""
        k = lane(u)
        if k == '__integration__':
            return 'integration'
        if k != 'root':
            return Path(k).name
        if not root_repo:
            try:
                r = subprocess.run(['git', '-C', str(root), 'rev-parse', '--show-toplevel'],
                                   capture_output=True, text=True, timeout=5)
                root_repo.append(Path(r.stdout.strip()).name if r.returncode == 0 and r.stdout.strip() else 'root')
            except (OSError, subprocess.SubprocessError):
                root_repo.append('root')
        return root_repo[0]

    def join(items: list) -> str:
        return ' · '.join(items) or '—'

    if kind == 'fix':
        lines = [f"work-item: {rel} (fix)"]
    else:
        feat = _dict(load_yaml(wdir / 'feature.yaml'))
        sens = ','.join(s for s in _list(feat.get('sensitivity')) if isinstance(s, str)) or '—'
        lines = [f"work-item: {rel} (feature · risk {effective_risk(feat)} · sensitivity {sens})"]
    lines.append(f"staleness: {staleness(wdir, kind)}")

    units = list(dict.fromkeys(unit(t) for t in tasks if unit(t) and unit(t) != 'integration'))
    lines.append(f"repos: {join([f'{u}={label(u)}' for u in units])}")

    ready, busy = {}, {}
    for t in tasks:
        if st[tid(t)] == 'pending' and all(st.get(d) == 'done' for d in deps(t)):
            ready.setdefault(label(unit(t)), []).append(tid(t))
        elif st[tid(t)] == 'in_progress':
            busy.setdefault(label(unit(t)), []).append(tid(t))
    lines.append('READY: ' + join([f"{lb} {' '.join(ids)}" + (f" (sibuk {','.join(busy[lb])})" if lb in busy else '')
                                   for lb, ids in ready.items()]))
    lines.append('in_progress: ' + join([f"{tid(t)} {unit(t) or '-'}" for t in tasks if st[tid(t)] == 'in_progress']))

    def reason(t: dict):
        manual = [x for x in _list(t.get('manual')) if isinstance(x, str)]
        r = t.get('hold') if isinstance(t.get('hold'), str) and t.get('hold') else (manual[0] if manual else None)
        return f' "{r}"' if r else ''
    lines.append('hold: ' + join([f"{tid(t)} needs_human{reason(t)}" for t in tasks if st[tid(t)] == 'needs_human']))
    lines.append('blocked: ' + join([f"{tid(t)} {unit(t) or '-'}{reason(t)}" for t in tasks if st[tid(t)] == 'blocked']))

    gates = [g for g in _list(_dict(load_yaml(wdir / 'gates.yaml')).get('gates'))
             if isinstance(g, dict) and g.get('status') == 'queued']
    lines.append('gates queued: ' + join([f"{_str(g.get('id'))} {_str(g.get('segment'))}"
                                          + (f' "{_str(g.get("reason"))}"' if _str(g.get('reason')) else '') for g in gates]))

    paths = {e['name']: e.get('path') for e in _list(ws.get('apps')) + _list(ws.get('packages'))
             if isinstance(e, dict) and isinstance(e.get('name'), str)}
    apps = {e['name'] for e in _list(ws.get('apps')) if isinstance(e, dict) and isinstance(e.get('name'), str)}
    stale = []
    for t in tasks:
        if st[tid(t)] == 'done':
            continue
        for r in map(_as_map, _list(t.get('reuse'))):
            tbl, f = r.get('table'), r.get('file')
            if isinstance(tbl, str) and tbl and unit(t) in apps:
                names = _schema_tables(root, schema_owner(ws, unit(t)))
                if names is not None and tbl not in names:
                    stale.append(f"{tid(t)} table {tbl}")
            if isinstance(f, str) and f and isinstance(paths.get(unit(t)), str) and not (root / paths[unit(t)] / f).exists():
                stale.append(f"{tid(t)} file {f}")
    lines.append('reuse basi: ' + join(stale))

    _, done, entries, legacy = _carry_doc(root, work_item)
    if entries is not None:
        counts = {}
        for n in entries:
            if _active(n, done) and _str(n.get('for')):
                counts[_str(n.get('for'))] = counts.get(_str(n.get('for')), 0) + 1
        nums = [int(m.group(1)) for n in entries if (m := re.fullmatch(r'C(\d+)', _str(n.get('id'))))]
        carry = f"carry: {join([f'{k}×{v}' for k, v in counts.items()])} · next C{max(nums, default=0) + 1}"
        lines.append(carry + (f" · legacy {LEGACY_CARRY} aktif ({len(legacy)} baris)" if legacy is not None else ''))
    elif legacy is not None:
        lines.append(f"carry: legacy {LEGACY_CARRY} ({len(legacy)} baris) · next C1")
    else:
        lines.append('carry: — · next C1')

    lines.append('map:')
    for m in (m for m in _list(doc.get('milestones')) if isinstance(m, dict)):
        ts = [t for t in _list(m.get('tasks')) if isinstance(t, dict)]
        d = sum(st.get(tid(t)) == 'done' for t in ts)
        if ts and d == len(ts):
            lines.append(f"  {_str(m.get('id'))} ✓ {d}/{len(ts)} {_str(m.get('title'))}".rstrip())
            continue
        lines.append(f"  {_str(m.get('id'))} {d}/{len(ts)} {_str(m.get('title'))}".rstrip())
        for t in ts:
            row = f"    {tid(t)} {unit(t) or '-'} {_str(t.get('status')) or '-'}"
            if deps(t):
                row += f" deps {','.join(deps(t))}"
            desc = ' '.join(_str(t.get('desc')).split())
            if desc:
                row += ' · ' + (desc if len(desc) <= DESC_MAX else desc[:DESC_MAX - 1] + '…')
            lines.append(row)
    return '\n'.join(lines) + '\n'


# --- CLI -----------------------------------------------------------------------------------

def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog='build_status.py', description='Pembaca status build context-vault (read-only).')
    ap.add_argument('--parse-yaml', metavar='FILE', help='parse FILE dengan parser subset, cetak JSON')
    ap.add_argument('--root', default='.', help='root produk (folder yang punya control/)')
    ap.add_argument('--format', choices=('json', 'status', 'drive', 'controller', 'task', 'carry'),
                    help='json = snapshot v1 · status = status line · drive = baris progres drive.sh (item pertama) · '
                         'controller = ringkasan state + peta · task = entri task lengkap (--task) · '
                         'carry = titipan aktif (--for); controller/task/carry butuh --work-item')
    ap.add_argument('--task', metavar='IDS', help='task: id dipisah koma, mis. T1,T2')
    ap.add_argument('--for', dest='targets', metavar='TARGETS', help='carry: target dipisah koma (id task, gate:<M>[/<unit>], ship, simplify)')
    ap.add_argument('--work-item', metavar='DIR', help='hanya work-item ini (relatif root), mis. control/features/<f>')
    ap.add_argument('--now', type=float, help='epoch "sekarang" (untuk test)')
    ap.add_argument('--quiet-min', type=int, default=QUIET_MIN, help=f'ambang menit "diam" (default {QUIET_MIN})')
    ap.add_argument('--width', type=int, help='status/drive: potong teks ke N karakter (+ "…") supaya muat satu baris')
    args = ap.parse_args(argv)
    try:
        if args.parse_yaml:
            p = Path(args.parse_yaml)
            if not p.is_file():
                raise YamlError(f"{p}: file tidak ada")
            print(json.dumps(load_yaml(p), ensure_ascii=False))
            return 0
        if args.format in ('controller', 'task', 'carry'):
            if not args.work_item:
                raise YamlError(f"--format {args.format} butuh --work-item")
            if args.format == 'controller':
                print(controller_text(Path(args.root), args.work_item), end='')
                return 0
            raw = args.task if args.format == 'task' else args.targets
            ids = [x.strip() for x in (raw or '').split(',') if x.strip()]
            if not ids:
                raise YamlError(f"--format {args.format} butuh {'--task' if args.format == 'task' else '--for'}")
            out = (task_entries if args.format == 'task' else carry_notes)(Path(args.root), args.work_item, ids)
            print(json.dumps(out, ensure_ascii=False))
            return 0
        if args.format:
            now = args.now if args.now is not None else time.time()
            snap = snapshot(Path(args.root), now, args.work_item, args.quiet_min)
            if args.format == 'json':
                print(json.dumps(snap, ensure_ascii=False))
                return 0
            if args.format == 'status':
                line = snap['status_line'] or ''
            else:
                line = snap['items'][0]['drive_line'] if snap['items'] else ''
            if args.width and len(line) > args.width:
                line = line[:max(0, args.width - 1)] + '…'
            print(line)
            return 0
    except YamlError as e:
        print(f"build_status: {e}", file=sys.stderr)
        return 2
    ap.print_usage(sys.stderr)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
