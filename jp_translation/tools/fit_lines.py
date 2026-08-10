# -*- coding: utf-8 -*-
"""Report which translations overflow a wrapped, fixed-height slot.

Mirrors getLineBrokenChunks + drawTextExFitted: chunks are packed greedily at
legal Japanese break points, and the font steps down until the text fits or
hits `minsize`. Anything still over needs shortening in the translation.
"""
import argparse, json, re, sys
from PIL import ImageFont

FONT = 'patch/Fonts/pokemonemerald.ttf'
WIDE = re.compile(r'[　-〿぀-ヿ㐀-䶿一-鿿＀-￯]')
HEAD = re.compile(r'[　、。，．・：；？！ー々〜…‥ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶ)\]}）］｝〉》」』】〕｣!?:;]')
END  = re.compile(r'[（［｛〈《「『【〔｢(\[{]')

def _brk(p, c):
    if not WIDE.search(p) and not WIDE.search(c):
        return False
    return not (HEAD.search(c) or END.search(p))

def chunks(s):
    out, cur = [], ''
    for i, ch in enumerate(s):
        if i and cur and _brk(s[i - 1], ch):
            out.append(cur); cur = ''
        cur += ch
    if cur:
        out.append(cur)
    return out

def line_count(text, size, width):
    # mkxp renders font.size at 8/9 of the requested value (measured in-game)
    f = ImageFont.truetype(FONT, round(size * 8 / 9))
    x, n = 0.0, 1
    for c in chunks(text):
        w = f.getlength(c)
        if x > 0 and x + w >= width - 2:
            n += 1; x = 0.0
        x += w
    return n

def best_size(text, width, lines, maxsize=36, minsize=24):
    s = maxsize
    while s >= minsize:
        if line_count(text, s, width) <= lines:
            return s
        s -= 2
    return None

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('jsonl')
    ap.add_argument('--width', type=int, default=282)
    ap.add_argument('--lines', type=int, default=2)
    ap.add_argument('--minsize', type=int, default=24)
    a = ap.parse_args()
    rows = [json.loads(l) for l in open(a.jsonl, encoding='utf-8') if l.strip()]
    over = []
    for r in rows:
        if not r['ja']:
            continue
        if best_size(r['ja'], a.width, a.lines, minsize=a.minsize) is None:
            over.append(r)
    print(f"{sum(1 for r in rows if r['ja'])} translated, {len(over)} overflow "
          f"({a.width}px x {a.lines} lines, down to size {a.minsize})")
    for r in over:
        print(f"  {len(r['ja']):3d}字 {r['ja']}")
    return 1 if over else 0

if __name__ == '__main__':
    sys.exit(main())
