#!/usr/bin/env python3
"""Report characters the bundled font cannot draw.

    python3 jp_translation/tools/check_font.py [--dat patch/Data/japanese.dat]
                                               [--font patch/Fonts/pokemonemerald.ttf]

A missing glyph is invisible to proofreading: the text reads correctly in the
editor and turns into a blank box only in game. Worse, the usual culprits are
characters that look right and are simply the wrong code point - U+301C 〜 in
place of U+FF5E ～, or a stray U+202F where a kana belongs.

So every character of every translated string is checked against the font's
own cmap. Anything the font has no glyph for is reported with the entries it
appears in.

Exits non-zero when something is missing, so it can gate a build.
"""
import argparse
import os
import sys
import unicodedata
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rmarshal  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Control codes Essentials uses in message strings; they never reach the font.
IGNORED = set('\n\r\t\v\f\x00')


def font_coverage(path):
    from fontTools.ttLib import TTFont
    font = TTFont(path)
    covered = set()
    for table in font['cmap'].tables:
        covered |= set(table.cmap.keys())
    return covered


def walk(node, section, out):
    if isinstance(node, str):
        out.append((section, node))
    elif isinstance(node, dict):
        for value in node.values():
            walk(value, section, out)
    elif isinstance(node, (list, tuple)):
        for value in node:
            walk(value, section, out)
    elif hasattr(node, 'data'):
        walk(node.data, section, out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dat', default=os.path.join(ROOT, 'patch', 'Data', 'japanese.dat'))
    ap.add_argument('--font', default=os.path.join(ROOT, 'patch', 'Fonts',
                                                   'pokemonemerald.ttf'))
    ap.add_argument('--quiet', action='store_true')
    a = ap.parse_args()

    covered = font_coverage(a.font)
    strings = []
    for i, section in enumerate(rmarshal.load(a.dat)):
        walk(section, i, strings)

    missing = defaultdict(list)
    for section, text in strings:
        for ch in text:
            if ch in IGNORED or ord(ch) in covered:
                continue
            missing[ch].append((section, text))

    if not a.quiet:
        print('フォント収録グリフ {0} 字 / 検査した文字列 {1} 件'.format(
            len(covered), len(strings)))
    if not missing:
        print('フォントに無い文字: なし')
        return 0

    print('フォントに無い文字: {0} 種'.format(len(missing)))
    for ch, uses in sorted(missing.items(), key=lambda kv: -len(kv[1])):
        try:
            name = unicodedata.name(ch)
        except ValueError:
            name = '?'
        print('  U+{0:04X} {1!r} {2}  {3}件'.format(ord(ch), ch, name, len(uses)))
        for section, text in uses[:3]:
            print('      セクション{0}: {1!r}'.format(section, text[:60]))
    return 1


if __name__ == '__main__':
    sys.exit(main())
