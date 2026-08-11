# -*- coding: utf-8 -*-
"""Draw the Japanese type badges into patch/Graphics/*/ja/.

Two sets: the 64x28 badges used in battle and on the summary screen, and the
96x32 ones the Pokédex draws on an entry. Both have the type name painted into
the image, and both are rebuilt the same way — the label band is repainted with
the badge's own fill colour and the Japanese name is drawn back in.

The badges are a flat bar. Rows 6..21 x columns 2..61 hold nothing but the
label and the fill behind it (verified against typeICE, whose label is narrow
enough to leave that whole span a single colour), so repainting exactly that
rectangle erases the English word without touching the bevel or the rounded
corners.

Names come from the translated type list rather than being repeated here, so
the badge and the text in battle can never disagree.

    python3 jp_translation/tools/build_type_icons.py
"""
import collections
import json
import os

from PIL import Image, ImageDraw, ImageFont

SRC = 'Graphics/Icons'
OUT = 'patch/Graphics/Icons/ja'
DEX_SRC = 'Graphics/Pictures/Pokedex'
DEX_OUT = 'patch/Graphics/Pictures/Pokedex/ja'
FONT = 'patch/Fonts/pokemonemerald.ttf'
TYPES_JSONL = 'jp_translation/work/src/11_types.jsonl'

WHITE = (248, 248, 248, 255)
SHADOW = (128, 120, 112, 255)
# The label sits in this rectangle and nothing else does.
BOX = (2, 6, 62, 22)          # x0, y0, x1, y1 (exclusive ends)
MAX_TEXT_WIDTH = BOX[2] - BOX[0] - 2
MAX_SIZE = 18
MIN_SIZE = 12

# The Pokédex badge is the same design at twice the scale: a 2px black border,
# a 2px bevel inside it, and the label on the flat fill between them.
DEX_BOX = (4, 4, 92, 28)
DEX_MAX_TEXT_WIDTH = DEX_BOX[2] - DEX_BOX[0] - 4
DEX_MAX_SIZE = 24
DEX_MIN_SIZE = 16
DEX_SHADOW_OFFSET = 2


def type_names():
    """{'FIRE': 'ほのお', ...} from the translated section 11."""
    out = {}
    for line in open(TYPES_JSONL, encoding='utf-8'):
        if not line.strip():
            continue
        r = json.loads(line)
        if not r['ja'] or r['ja'] == r['en']:
            continue      # '???' needs no badge of its own
        out[r['en'].upper()] = r['ja']
    # The file spells the internal names out in English; a few differ from the
    # constant used in the filename.
    out['QMARKS'] = None
    return out


def fill_colour(px):
    counts = collections.Counter(px[x, y] for x in range(64) for y in range(28)
                                 if px[x, y][3] != 0)
    return counts.most_common(1)[0][0]


def render_label(text, max_width=MAX_TEXT_WIDTH, max_size=MAX_SIZE, min_size=MIN_SIZE):
    """The label as a 1-bit mask, stepped down until it fits the badge."""
    for size in range(max_size, min_size - 1, -1):
        font = ImageFont.truetype(FONT, size)
        mask = Image.new('1', (192, 48), 0)
        d = ImageDraw.Draw(mask)
        d.fontmode = '1'                      # no antialiasing: the art is flat
        d.text((8, 4), text, font=font, fill=1)
        box = mask.getbbox()
        if box and box[2] - box[0] <= max_width:
            return mask.crop(box)
    raise SystemExit(f'{text!r} does not fit even at {min_size}px')


def build_dex(name, label):
    im = Image.open(f'{DEX_SRC}/pokedex{name}.png').convert('RGBA')
    px = im.load()
    # Sample the two rows above the label rather than the whole box: on a badge
    # with a long English word the white of the text outnumbers the fill.
    counts = collections.Counter(px[x, y] for x in range(DEX_BOX[0], DEX_BOX[2])
                                 for y in range(DEX_BOX[1], DEX_BOX[1] + 2))
    fill = counts.most_common(1)[0][0]
    for x in range(DEX_BOX[0], DEX_BOX[2]):
        for y in range(DEX_BOX[1], DEX_BOX[3]):
            px[x, y] = fill

    mask = render_label(label, DEX_MAX_TEXT_WIDTH, DEX_MAX_SIZE, DEX_MIN_SIZE)
    ox = DEX_BOX[0] + (DEX_BOX[2] - DEX_BOX[0] - mask.width - DEX_SHADOW_OFFSET) // 2
    oy = DEX_BOX[1] + (DEX_BOX[3] - DEX_BOX[1] - mask.height - DEX_SHADOW_OFFSET) // 2
    for dx, dy, colour in ((DEX_SHADOW_OFFSET, DEX_SHADOW_OFFSET, (112, 120, 120, 255)),
                           (0, 0, WHITE)):
        layer = Image.new('RGBA', im.size, (0, 0, 0, 0))
        layer.paste(colour, (ox + dx, oy + dy), mask)
        im = Image.alpha_composite(im, layer)
    return im


def build(name, label):
    im = Image.open(f'{SRC}/type{name}.png').convert('RGBA')
    px = im.load()
    fill = fill_colour(px)
    for x in range(BOX[0], BOX[2]):
        for y in range(BOX[1], BOX[3]):
            px[x, y] = fill

    mask = render_label(label)
    # Centre the ink in the label box; the shadow adds a pixel on each far side.
    ox = BOX[0] + (BOX[2] - BOX[0] - mask.width - 1) // 2
    oy = BOX[1] + (BOX[3] - BOX[1] - mask.height - 1) // 2
    for dx, dy, colour in ((1, 1, SHADOW), (0, 0, WHITE)):
        layer = Image.new('RGBA', im.size, (0, 0, 0, 0))
        layer.paste(colour, (ox + dx, oy + dy), mask)
        im = Image.alpha_composite(im, layer)
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    names = type_names()
    written = skipped = 0
    for path in sorted(os.listdir(SRC)):
        if not path.startswith('type') or not path.endswith('.png'):
            continue
        name = path[len('type'):-len('.png')]
        label = names.get(name.upper())
        if not label:
            skipped += 1
            continue
        build(name, label).save(f'{OUT}/{path}')
        print(f'  {path:20} {label}')
        written += 1
    print(f'{written} badge(s) written to {OUT}; {skipped} left in English')

    os.makedirs(DEX_OUT, exist_ok=True)
    written = skipped = 0
    for path in sorted(os.listdir(DEX_SRC)):
        if not path.startswith('pokedex') or not path.endswith('.png'):
            continue
        name = path[len('pokedex'):-len('.png')]
        if not name.isupper():
            continue          # backgrounds and widgets, not type badges
        label = names.get(name)
        if not label:
            skipped += 1
            continue
        build_dex(name, label).save(f'{DEX_OUT}/{path}')
        print(f'  {path:20} {label}')
        written += 1
    print(f'{written} badge(s) written to {DEX_OUT}; {skipped} left in English')


if __name__ == '__main__':
    main()
