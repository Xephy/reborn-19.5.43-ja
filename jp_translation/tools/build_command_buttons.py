# -*- coding: utf-8 -*-
"""Redraw the battle command buttons in Japanese.

The Fight / Bag / Pokémon / Run menu is not text — it is one 260x414 sheet of
9 commands x 2 states (unselected, selected) with the word drawn into each
plate, so none of it can be translated through the message tables.

The plate is a stack of flat horizontal bands, so a row of it can be repainted
by sampling the band colour just outside the word. x=22..29 is plate on every
cell (the widest English word, FIGHT, starts at x=30) and so is x=101..107, so
the label is erased between them and redrawn centred.

Reborn already asks for this sheet through _INTL, which is Essentials' hook for
swapping art per language, so the Japanese copy is picked up by adding the path
to the message table - no code change.

    python3 jp_translation/tools/build_command_buttons.py
"""
import json
import os

from PIL import Image, ImageDraw, ImageFont

SRC = 'Graphics/Pictures/Battle/battleCommandButtons.png'
OUT = 'patch/Graphics/Pictures/Battle/ja/battleCommandButtons.png'
FONT = 'patch/Fonts/pokemonemerald.ttf'
SRC_DIR = 'jp_translation/work/src'

CELL_W, CELL_H = 130, 46
ROWS = 9
# The label and its shadow live between these columns, in this band of rows.
TEXT_X0, TEXT_X1 = 30, 100
BAND_Y0, BAND_Y1 = 12, 34
SAMPLE_X = 24                      # plate on every cell, left of the widest word
MAX_SIZE, MIN_SIZE = 26, 16
SHADOW_OFFSET = 2

# Row order of the sheet, and the English each row is keyed on. The Japanese
# comes from the message table so the buttons and the rest of the game agree.
COMMANDS = ['Fight', 'Pokémon', 'Bag', 'Run', 'Call', 'Ball', 'Rock', 'Bait', 'Ball']

# "Rock" is shared with the Rock type in the message table, where it has to stay
# いわ for the type filters. On the Safari button it means a thrown stone.
OVERRIDES = {'Rock': 'いし'}


def translations():
    out = {}
    for name in sorted(os.listdir(SRC_DIR)):
        if not name.endswith('.jsonl'):
            continue
        for line in open(os.path.join(SRC_DIR, name), encoding='utf-8'):
            if not line.strip():
                continue
            r = json.loads(line)
            if r['sec'] == 22 and r['ja']:
                out[r['key']] = r['ja']
    return out


def label_mask(text):
    for size in range(MAX_SIZE, MIN_SIZE - 1, -1):
        font = ImageFont.truetype(FONT, size)
        mask = Image.new('1', (256, 64), 0)
        d = ImageDraw.Draw(mask)
        d.fontmode = '1'
        d.text((8, 8), text, font=font, fill=1)
        box = mask.getbbox()
        if box and box[2] - box[0] <= TEXT_X1 - TEXT_X0 - SHADOW_OFFSET:
            return mask.crop(box)
    raise SystemExit(f'{text!r} does not fit even at {MIN_SIZE}px')


def main():
    ja = translations()
    im = Image.open(SRC).convert('RGBA')
    px = im.load()

    for row, english in enumerate(COMMANDS):
        text = OVERRIDES.get(english) or ja.get(english)
        if not text:
            raise SystemExit(f'no translation for {english!r}')
        mask = label_mask(text)
        for col in (0, 1):
            x0, y0 = col * CELL_W, row * CELL_H
            for y in range(BAND_Y0, BAND_Y1):
                plate = px[x0 + SAMPLE_X, y0 + y]
                for x in range(TEXT_X0, TEXT_X1):
                    px[x0 + x, y0 + y] = plate
            # The word sits on the light half of the plate, so it keeps the
            # original white-with-a-dark-shadow treatment.
            ox = x0 + TEXT_X0 + (TEXT_X1 - TEXT_X0 - mask.width - SHADOW_OFFSET) // 2
            oy = y0 + BAND_Y0 + (BAND_Y1 - BAND_Y0 - mask.height - SHADOW_OFFSET) // 2
            for dx, dy, colour in ((SHADOW_OFFSET, SHADOW_OFFSET, (19, 19, 21, 255)),
                                   (0, 0, (248, 248, 248, 255))):
                layer = Image.new('RGBA', im.size, (0, 0, 0, 0))
                layer.paste(colour, (ox + dx, oy + dy), mask)
                im = Image.alpha_composite(im, layer)
            px = im.load()
        print(f'  row {row}  {english:8} -> {text}')

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    im.save(OUT)
    print(f'wrote {OUT}')


if __name__ == '__main__':
    main()
