# -*- coding: utf-8 -*-
"""Redraw the Pokegear "Time & Weather" background labels in Japanese.

navbgtw.png is the whole screen: the frame, the black panel and two labels
painted straight into it - CURRENT WEATHER above the left icon and WEATHER AT
above the right one, with the changeover time drawn next to the latter by the
script. There is no string to translate, so the image is rebuilt.

The panel behind the labels is a vertical gradient with a faint dither, uniform
across x, so each row is refilled with the colour it already has at a column the
text never reaches, and the Japanese is drawn back on top.

The frame's own NAV / RBRN / SHUTDOWN are left alone: they are part of the
Pokegear chrome shared with the other apps, and NAV is already documented as
staying English.

    python3 jp_translation/tools/build_timeweather_bg.py
"""
import os

from PIL import Image, ImageDraw, ImageFont

SRC = 'Graphics/Pictures/Pokegear/TimeWeather/navbgtw.png'
OUT = 'patch/Graphics/Pictures/Pokegear/TimeWeather/ja/navbgtw.png'
FONT = 'patch/Fonts/pokemonemerald.ttf'

# The band the two baked labels occupy, measured off the original.
BAND_Y0, BAND_Y1 = 216, 233
BAND_X0, BAND_X1 = 74, 385
CLEAN_X = 30                       # inside the panel, left of the first label

# Both labels sit on the same baseline. "CURRENT WEATHER" is centred over the
# left weather icon (x=112..208); "WEATHER AT" is right-aligned so the time the
# script draws at x=391 follows it, and the Japanese keeps that arrangement.
LEFT_LABEL = '現在の天気'
RIGHT_LABEL = '次の天気'
LEFT_CENTRE = 160                  # centre of the left 96x96 icon frame
RIGHT_END = 385                    # last column before the drawn time
# The baked English caps are 18px tall. 24 renders 16px here, the closest match
# whose strokes still come out even - at 26 and above the pixel font is being
# scaled past its grid and the verticals stop being uniform.
SIZE = 24
TEXT_RGB = (248, 248, 248)


def label_mask(text, size):
    """The text as an alpha mask, drawn crisply at the design size."""
    img = Image.new('L', (400, 64), 0)
    d = ImageDraw.Draw(img)
    d.fontmode = '1'               # no antialiasing: this is a pixel font
    d.text((10, 10), text, font=ImageFont.truetype(FONT, size), fill=255)
    return img.crop(img.getbbox())


def main():
    im = Image.open(SRC).convert('RGBA')
    px = im.load()

    # Wipe the band, one row at a time, with that row's own panel colour.
    for y in range(BAND_Y0, BAND_Y1 + 1):
        fill = px[CLEAN_X, y]
        for x in range(BAND_X0, BAND_X1 + 1):
            px[x, y] = fill

    layer = Image.new('RGBA', im.size, (0, 0, 0, 0))
    for text, anchor, mode in ((LEFT_LABEL, LEFT_CENTRE, 'centre'),
                               (RIGHT_LABEL, RIGHT_END, 'right')):
        mask = label_mask(text, SIZE)
        x = anchor - mask.width // 2 if mode == 'centre' else anchor - mask.width
        y = BAND_Y0 + (BAND_Y1 - BAND_Y0 + 1 - mask.height) // 2
        if x < BAND_X0 or x + mask.width > BAND_X1 + 1:
            raise SystemExit(f'{text!r} ({mask.width}px) does not fit the cleared band')
        layer.paste(TEXT_RGB + (255,), (x, y), mask)
        print(f'  {text}  {mask.width}x{mask.height}px at ({x}, {y})')

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.alpha_composite(im, layer).save(OUT)
    print(f'  wrote {OUT}')


if __name__ == '__main__':
    main()
