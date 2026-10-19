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
import re
import sys
from pathlib import Path


# --- Parser YAML subset ------------------------------------------------------------------
# Cukup untuk tasks.yaml/gates.yaml/feature.yaml: map & sequence blok, flow sequence skalar,
# skalar polos/ber-kutip (boleh multi-baris), block scalar | > (+ chomping). Semua skalar
# tetap string; key tanpa nilai dan tanpa blok → None. Nilai yang diawali '{' = string mentah.

class YamlError(Exception):
    pass


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
            return self.quoted(s, j)
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

    def quoted(self, s: str, j: int) -> str:
        buf, k = s, self.i
        while (end := _quoted_end(buf)) < 0:
            if k >= len(self.lines):
                raise YamlError(f"baris {j + 1}: kutip tak ditutup")
            buf += '\n' + self.lines[k]
            k += 1
        self.i = k
        tail = buf[end:].strip()
        if tail and not tail.startswith('#'):
            raise YamlError(f"baris {j + 1}: ada teks sesudah kutip penutup")
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
        text = path.read_text(encoding='utf-8')
    except FileNotFoundError:
        return None
    except (OSError, UnicodeDecodeError) as e:
        raise YamlError(f"{path}: {e}") from None
    try:
        return parse_yaml(text)
    except YamlError as e:
        raise YamlError(f"{path}: {e}") from None


# --- CLI -----------------------------------------------------------------------------------

def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog='build_status.py', description='Pembaca status build context-vault (read-only).')
    ap.add_argument('--parse-yaml', metavar='FILE', help='parse FILE dengan parser subset, cetak JSON')
    args = ap.parse_args(argv)
    try:
        if args.parse_yaml:
            p = Path(args.parse_yaml)
            if not p.is_file():
                raise YamlError(f"{p}: file tidak ada")
            print(json.dumps(load_yaml(p), ensure_ascii=False))
            return 0
    except YamlError as e:
        print(f"build_status: {e}", file=sys.stderr)
        return 2
    ap.print_usage(sys.stderr)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
