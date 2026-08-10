# -*- coding: utf-8 -*-
"""Check that translated strings still fit the UI slots that draw them.

Japanese is roughly twice as wide per character as the English it replaces, so
short fixed-width slots (move buttons, the ability field on the summary screen)
overflow long before the message box does. This measures candidate strings with
the real game font and reports the ones that will not fit.

Usage
-----
    python3 jp_translation/tools/fitcheck.py --slot move  "かえんほうしゃ" "エレキフィールド"
    python3 jp_translation/tools/fitcheck.py --slot move  --json moves.json
    python3 jp_translation/tools/fitcheck.py --list-slots

Run it from the game root.
"""
import argparse
import json
import sys

from PIL import ImageFont

FONT_PATH = 'patch/Fonts/pokemonemerald.ttf'

# pbSetSystemFont() asks for font.size = 36 (SpriteWindow.rb:1058), but mkxp-z
# rasterises that at 32px. Measured in-game via patch/Mods self-test:
#   text_size("漢字") = 42px  (36 would give 48)
#   text_size("AB")   = 24px  (36 would give 27)
# Use the size the engine actually renders at, or every budget is 12.5% off.
FONT_SIZE = 32

# Verified against the drawing code. `budget` is the usable pixel width.
SLOTS = {
    'move': dict(
        budget=186,
        where='Battle_Scene.rb:439 — fight menu button is 192px wide, text centred',
        note='技名。4つ並ぶボタン。全角7文字=168px までが安全圏',
    ),
    'ability': dict(
        budget=178,
        where='Summary.rb:574,657 — pbDrawTextFitted at x=328, 178px slot',
        note='特性名。元は x=362 の146pxで82件あふれていたので左に寄せた',
    ),
    'message': dict(
        budget=480,
        where='Messages.rb:1160 + SpriteWindow.rb:1847 — 512px window minus 32px border',
        note='会話文。自動改行されるので基本は超過しない',
    ),
}


def load_font():
    try:
        return ImageFont.truetype(FONT_PATH, FONT_SIZE)
    except OSError:
        sys.exit(f'font not found: {FONT_PATH} (run from the game root)')


def width_of(font, text):
    return font.getlength(text)


def check(font, slot, strings):
    spec = SLOTS[slot]
    budget = spec['budget']
    rows = []
    for s in strings:
        w = width_of(font, s)
        rows.append((s, w, w <= budget))
    return spec, rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--slot', default='move', choices=sorted(SLOTS))
    ap.add_argument('--json', help='JSON file: a list of strings, or an object whose values are strings')
    ap.add_argument('--quiet', action='store_true', help='only print the overflowing entries')
    ap.add_argument('--list-slots', action='store_true')
    ap.add_argument('strings', nargs='*')
    a = ap.parse_args()

    if a.list_slots:
        for name, spec in sorted(SLOTS.items()):
            print(f"{name:10s} {spec['budget']:4d}px  {spec['note']}")
            print(f"{'':10s}       {spec['where']}")
        return

    strings = list(a.strings)
    if a.json:
        data = json.load(open(a.json, encoding='utf-8'))
        strings += list(data.values()) if isinstance(data, dict) else list(data)
    if not strings:
        sys.exit('nothing to check: pass strings or --json')

    font = load_font()
    spec, rows = check(font, a.slot, strings)
    over = [r for r in rows if not r[2]]

    print(f"slot={a.slot}  budget={spec['budget']}px  ({spec['where']})")
    for s, w, ok in rows:
        if a.quiet and ok:
            continue
        print(f"  {'OK ' if ok else 'OVER'}  {w:6.1f}px  {s}")
    print(f"\n{len(rows)} checked, {len(over)} overflow")
    return 1 if over else 0


if __name__ == '__main__':
    sys.exit(main() or 0)
