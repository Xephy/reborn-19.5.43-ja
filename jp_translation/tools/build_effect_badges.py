# -*- coding: utf-8 -*-
"""Draw the type-effectiveness badges for the battle move buttons.

Reborn already marks a move the field boosts or weakens by outlining the whole
button (fieldUp.png / fieldDown.png), so effectiveness cannot use an outline
too - the two would have to be readable at the same time. A small badge in the
button's top-right corner stays out of the way of both the outline and the
move name.

The symbols follow Pokémon Champions: ★ ◎ ○ △ ▼ ×. They are drawn as shapes
rather than set from the bundled font, which is a pixel face built for 10 and
12 pixels: blown up to badge size its ○ and ◎ turn into blocky rings. Each
symbol also carries a colour, so nobody has to tell ★ from ◎ by shape alone at
24 pixels.

Output: patch/Graphics/Pictures/Battle/typeeffect.png
        24x144, six 24x24 frames stacked in the order the drawing code uses:
        0 = 4x, 1 = 2x, 2 = 1x, 3 = 1/2x, 4 = 1/4x, 5 = no effect.

Usage: python3 jp_translation/tools/build_effect_badges.py
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'patch', 'Graphics', 'Pictures', 'Battle', 'typeeffect.png')

SIZE = 24
C = SIZE / 2.0
OUTLINE = (16, 16, 24, 255)

# Red for more damage, blue for less, the way every Pokémon UI reads. The
# quadruple steps take the deeper shade of each pair.
COLOURS = [
    (236, 64, 64, 255),     # ★ 4x
    (248, 152, 48, 255),    # ◎ 2x
    (248, 248, 248, 255),   # ○ 1x
    (120, 184, 240, 255),   # △ 1/2x
    (72, 112, 224, 255),    # ▼ 1/4x
    (176, 180, 188, 255),   # × no effect
]


def star_points(outer, inner):
    pts = []
    for i in range(10):
        r = outer if i % 2 == 0 else inner
        a = math.radians(-90 + i * 36)
        pts.append((C + r * math.cos(a), C + r * math.sin(a)))
    return pts


def triangle(down):
    if down:
        return [(C - 9, C - 7), (C + 9, C - 7), (C, C + 8)]
    return [(C, C - 8), (C + 9, C + 7), (C - 9, C + 7)]


def ring(d, box, colour):
    """A hollow ring: the dark stroke is laid down wider, then the colour is
    drawn inside it, so the hole in the middle stays a hole."""
    d.ellipse(box, outline=OUTLINE, width=4)
    d.ellipse(box, outline=colour, width=2)


def frame(kind, colour):
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if kind == 0:                                    # ★
        d.polygon(star_points(11.5, 4.8), fill=colour, outline=OUTLINE, width=1)
    elif kind == 1:                                  # ◎
        ring(d, (2, 2, SIZE - 3, SIZE - 3), colour)
        ring(d, (8, 8, SIZE - 9, SIZE - 9), colour)
    elif kind == 2:                                  # ○
        ring(d, (3, 3, SIZE - 4, SIZE - 4), colour)
    elif kind == 3:                                  # △
        # Traced as a closed line rather than a polygon outline: at this size
        # polygon joins pile up inside the sharp corners and leave a blot.
        path = triangle(False) + [triangle(False)[0]]
        d.line(path, fill=OUTLINE, width=5, joint='curve')
        d.line(path, fill=colour, width=3, joint='curve')
    elif kind == 4:                                  # ▼
        d.polygon(triangle(True), fill=colour, outline=OUTLINE, width=2)
    else:                                            # ×
        for a, b in (((4, 4), (SIZE - 5, SIZE - 5)), ((SIZE - 5, 4), (4, SIZE - 5))):
            d.line([a, b], fill=OUTLINE, width=7)
        for a, b in (((4, 4), (SIZE - 5, SIZE - 5)), ((SIZE - 5, 4), (4, SIZE - 5))):
            d.line([a, b], fill=colour, width=4)
    return img


def main():
    sheet = Image.new('RGBA', (SIZE, SIZE * len(COLOURS)), (0, 0, 0, 0))
    for i, colour in enumerate(COLOURS):
        sheet.paste(frame(i, colour), (0, i * SIZE))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT)
    print('wrote {0} ({1}x{2})'.format(
        os.path.relpath(OUT, ROOT), sheet.width, sheet.height))


if __name__ == '__main__':
    main()
