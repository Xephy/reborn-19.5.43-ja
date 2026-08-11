# -*- coding: utf-8 -*-
"""Redraw the status-condition badges in Japanese.

SLP / PSN / BRN / PAR / FRZ / KO / PKRS are 44x16 images with the abbreviation
painted on, shown on the party screen, the summary and in the PC. The 7-cell sheet is
loaded by the party screen and the individual files under Party/ are drawn by
the party and summary screens; both sets are rebuilt here.

The plate is a stack of flat rows, so each row is repainted with the colour it
already has at x=3 (the label never reaches the first three columns) and the
Japanese name is drawn back on top.

    python3 jp_translation/tools/build_status_badges.py
"""
import os

from PIL import Image, ImageDraw, ImageFont

FONT = 'patch/Fonts/pokemonemerald.ttf'
CELL_W, CELL_H = 44, 16
SAMPLE_X = 3                       # plate on every row of every badge
TEXT_X0, TEXT_X1 = 4, 41
MAX_SIZE, MIN_SIZE = 16, 9

# Official Japanese status names. The sheet's row order is fixed by the engine.
LABELS = {
    'SLEEP': 'ねむり', 'SLP': 'ねむり',
    'POISON': 'どく', 'POISONED': 'どく', 'PSN': 'どく',
    'BURN': 'やけど', 'BRN': 'やけど',
    'PARALYSIS': 'まひ', 'PAR': 'まひ',
    'FROZEN': 'こおり', 'FRZ': 'こおり',
    'FAINTED': 'ひんし', 'KO': 'ひんし',
}
# ポケルス is four characters and the badge is 44px wide: at the size that fits,
# this pixel font runs the strokes together into a blob, and antialiasing it
# leaves white-on-lavender that cannot be read. PKRS stays as it is - it is an
# abbreviation of an invented word, and legible.
KEEP_ENGLISH = {'POKERUS', 'PKRS'}
SHEET_ROWS = ['SLP', 'PSN', 'BRN', 'PAR', 'FRZ', 'KO', 'PKRS']

TARGETS = [
    ('Graphics/Pictures/statuses.png', 'patch/Graphics/Pictures/ja/statuses.png', SHEET_ROWS),
    ('Graphics/Pictures/Party/status{}.png', 'patch/Graphics/Pictures/Party/ja/status{}.png',
     ['BURN', 'FAINTED', 'FROZEN', 'PARALYSIS', 'POISON', 'POKERUS', 'SLEEP']),
    # Graphics/Pictures/Summary/ has its own copies, but only statusPKRS is ever
    # drawn from there, and that one stays English - so there is nothing to do.
]


def label_image(text):
    """The label, drawn as small as it has to be to fit the badge.

    The font is a pixel design: at its full size it renders crisply with
    antialiasing off, which is what the English art looks like. Below that the
    strokes of a four-character name run together into a blob, so anything that
    has to be shrunk is antialiased instead - legibility wins over purity, and
    only ポケルス is affected.
    """
    for size in range(MAX_SIZE, MIN_SIZE - 1, -1):
        font = ImageFont.truetype(FONT, size)
        crisp = size == MAX_SIZE
        img = Image.new('L', (128, 32), 0)
        d = ImageDraw.Draw(img)
        if crisp:
            d.fontmode = '1'
        d.text((8, 8), text, font=font, fill=255)
        box = img.getbbox()
        if box and box[2] - box[0] <= TEXT_X1 - TEXT_X0 and box[3] - box[1] <= CELL_H - 4:
            return img.crop(box)
    raise SystemExit(f'{text!r} does not fit even at {MIN_SIZE}px')


def redraw(im, cell, text):
    """Repaint one 44x16 cell, `cell` rows down, with the Japanese name."""
    px = im.load()
    y0 = cell * CELL_H
    for y in range(CELL_H):
        plate = px[SAMPLE_X, y0 + y]
        for x in range(TEXT_X0, TEXT_X1):
            px[x, y0 + y] = plate
    mask = label_image(text)
    ox = TEXT_X0 + (TEXT_X1 - TEXT_X0 - mask.width) // 2
    oy = y0 + (CELL_H - mask.height) // 2
    # White with no shadow, as the originals are drawn.
    layer = Image.new('RGBA', im.size, (0, 0, 0, 0))
    layer.paste((248, 248, 248, 255), (ox, oy), mask)
    return Image.alpha_composite(im, layer)


def main():
    written = 0
    for src, out, statuses in TARGETS:
        if '{}' in src:
            for s in statuses:
                if s in KEEP_ENGLISH:
                    continue
                path = src.format(s)
                if not os.path.exists(path):
                    print(f'  skip (missing) {path}')
                    continue
                im = redraw(Image.open(path).convert('RGBA'), 0, LABELS[s])
                dest = out.format(s)
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                im.save(dest)
                print(f'  {dest:52} {LABELS[s]}')
                written += 1
        else:
            im = Image.open(src).convert('RGBA')
            for i, s in enumerate(statuses):
                if s in KEEP_ENGLISH:
                    continue
                im = redraw(im, i, LABELS[s])
            os.makedirs(os.path.dirname(out), exist_ok=True)
            im.save(out)
            print(f'  {out:52} {" ".join(LABELS.get(s, s) for s in statuses)}')
            written += 1
    print(f'{written} file(s) written')


if __name__ == '__main__':
    main()
