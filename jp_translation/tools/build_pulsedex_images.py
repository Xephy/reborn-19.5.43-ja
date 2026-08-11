# -*- coding: utf-8 -*-
"""Redraw the PULSE Dex pages in Japanese into patch/Graphics/Pictures/PulseDex/ja/.

Each entry is a single 512x384 image with the title, the type badges, the
ability and the description all drawn into it, so none of it can be reached
through the message tables. The English page is reused as the plate: the three
text areas are painted over with the panel colour and redrawn.

The geometry below was measured off the shipped art (see the constants), and
the colours are the game's own: the badge fill is the same colour as the
matching Graphics/Icons/type*.png, the border and text shadow are #807870, and
the text is #DDDDDD, exactly as in the English pages.

Species, type and ability names come from the translated sources so the page
can never disagree with the rest of the game; only the flavour text is held
separately, in pulsedex_ja.json.

    python3 jp_translation/tools/build_pulsedex_images.py
"""
import collections
import json
import os
import re

from PIL import Image, ImageDraw, ImageFont

SRC = 'Graphics/Pictures/PulseDex'
ICONS = 'Graphics/Icons'
OUT = 'patch/Graphics/Pictures/PulseDex/ja'
FONT = 'patch/Fonts/pokemonemerald.ttf'
TEXT_JSON = 'jp_translation/tools/pulsedex_ja.json'
PULSEDEX_RB = 'Scripts/PulseDex.rb'
SRC_DIR = 'jp_translation/work/src'

PANEL = (59, 59, 59, 255)      # flat background behind every text area
INK = (221, 221, 221, 255)     # body text
BADGE_INK = (248, 248, 248, 255)
EDGE = (128, 120, 112, 255)    # badge border and text shadow

TITLE_BOX = (20, 32, 500, 77)  # x0, y0, x1, y1
TITLE_TOP, TITLE_SIZE = 38, 40
ROW_BOX = (20, 86, 500, 119)
BADGE_Y, BADGE_W, BADGE_H, BADGE_GAP = 90, 64, 24, 6
ABILITY_X, ABILITY_TOP, ABILITY_SIZE = 162, 92, 22
DESC_BOX = (20, 128, 252, 350)
DESC_TOP, DESC_PITCH, DESC_SIZE = 132, 27, 22
# Arceus' page deliberately runs off the bottom of the panel, one clause per
# line, and that overflow is the point of it. Keep the tighter spacing.
GLITCH_PITCH, GLITCH_SIZE = 20, 18
CHROME_DONOR = 'Pulse_Garbodor'    # any page whose chrome is not painted over

# Line may not start with these.
NO_LINE_START = '。、」）!?・…ー'


def translations(filename, key='en'):
    out = {}
    for line in open(os.path.join(SRC_DIR, filename), encoding='utf-8'):
        if not line.strip():
            continue
        r = json.loads(line)
        if r['ja']:
            out[r[key]] = r['ja']
    return out


def pulse_entries():
    """[(key, number, species, form)] in the order the dex lists them."""
    src = open(PULSEDEX_RB, encoding='utf-8').read()
    table = src.split('PULSEDATA = {', 1)[1]
    out = []
    for m in re.finditer(r':(\w+) => \{\s*:name => "([^"]*)",\s*:desc => "(?:[^"\\]|\\.)*",\s*'
                         r':species => :(\w+),\s*:form => (?:"([^"]*)"|\[([^\]]*)\])', table):
        key, name, species, form, formlist = m.groups()
        if form is None:
            form = re.findall(r'"([^"]*)"', formlist)[0]
        # "5A. Tangrowth" -> "05A", matching the plate's own numbering.
        number = name.split('.')[0]
        digits = ''.join(c for c in number if c.isdigit())
        out.append((key, number.replace(digits, digits.zfill(2), 1), species, form))
    return out


def badge_fill(type_name):
    im = Image.open(f'{ICONS}/type{type_name}.png').convert('RGBA')
    px = im.load()
    counts = collections.Counter(px[x, y] for x in range(im.width) for y in range(im.height)
                                 if px[x, y][3] != 0)
    return counts.most_common(1)[0][0]


def fit_font(text, max_width, start, floor=12):
    for size in range(start, floor - 1, -1):
        font = ImageFont.truetype(FONT, size)
        if font.getlength(text) <= max_width:
            return font
    return ImageFont.truetype(FONT, floor)


def wrap(text, font, width):
    lines, line = [], ''
    for ch in text:
        if font.getlength(line + ch) > width and line:
            if ch in NO_LINE_START:
                line += ch          # never strand punctuation at a line start
                lines.append(line)
                line = ''
                continue
            lines.append(line)
            line = ch
        else:
            line += ch
    if line:
        lines.append(line)
    return lines


def draw_text(draw, xy, text, font, colour=INK):
    """Body text is drawn flat with a one-pixel shadow, like the English art."""
    draw.text((xy[0] + 1, xy[1] + 1), text, font=font, fill=EDGE)
    draw.text(xy, text, font=font, fill=colour)


def build(key, number, species, form, types, ability, desc, names):
    im = Image.open(f'{SRC}/{key}.png').convert('RGBA')
    d = ImageDraw.Draw(im)
    d.fontmode = '1'                       # the plate is flat pixel art
    if isinstance(desc, list):
        # Arceus' page overruns the panel and is drawn over the chrome at the
        # bottom of the screen, so the chrome there is already painted out in
        # the source. Any other page still has it intact; borrow that strip
        # before drawing the Japanese overflow back over it.
        clean = Image.open(f'{SRC}/{CHROME_DONOR}.png').convert('RGBA')
        im.paste(clean.crop((0, DESC_BOX[3], im.width, im.height)), (0, DESC_BOX[3]))
    for box in (TITLE_BOX, ROW_BOX, DESC_BOX):
        d.rectangle((box[0], box[1], box[2] - 1, box[3] - 1), fill=PANEL)

    title = f'PULSE {number} - {names["species"]}'
    draw_text(d, (TITLE_BOX[0], TITLE_TOP),
              title, fit_font(title, TITLE_BOX[2] - TITLE_BOX[0] - 4, TITLE_SIZE, 20))

    x = ROW_BOX[0]
    for t in types:
        d.rectangle((x, BADGE_Y, x + BADGE_W - 1, BADGE_Y + BADGE_H - 1),
                    fill=badge_fill(t), outline=EDGE, width=2)
        label = names['types'][t]
        font = fit_font(label, BADGE_W - 8, 18, 11)
        w = font.getlength(label)
        draw_text(d, (x + (BADGE_W - w) / 2, BADGE_Y + 3), label, font, BADGE_INK)
        x += BADGE_W + BADGE_GAP

    line = f'とくせい: {names["ability"]}'
    draw_text(d, (ABILITY_X, ABILITY_TOP),
              line, fit_font(line, ROW_BOX[2] - ABILITY_X - 4, ABILITY_SIZE, 14))

    width = DESC_BOX[2] - DESC_BOX[0] - 4
    if isinstance(desc, list):
        font = ImageFont.truetype(FONT, GLITCH_SIZE)
        lines, pitch = desc, GLITCH_PITCH
    else:
        font = ImageFont.truetype(FONT, DESC_SIZE)
        lines, pitch = wrap(desc, font, width), DESC_PITCH
        rows = (DESC_BOX[3] - DESC_TOP) // pitch
        size = DESC_SIZE
        while len(lines) > rows and size > 13:
            size -= 1
            font = ImageFont.truetype(FONT, size)
            lines = wrap(desc, font, width)
    for i, line in enumerate(lines):
        draw_text(d, (DESC_BOX[0], DESC_TOP + i * pitch), line, font)
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    species_ja = translations('01_species.jsonl')
    ability_ja = translations('09_abilities.jsonl')
    type_ja = translations('11_types.jsonl')
    text = json.load(open(TEXT_JSON, encoding='utf-8'))
    meta = json.load(open('jp_translation/tools/pulsedex_meta.json', encoding='utf-8'))

    for key, number, species, form in pulse_entries():
        info = meta[key]
        types = [info['t1']] + ([info['t2']] if info['t2'] else [])
        english_species = info['species_en']
        names = {
            'species': species_ja.get(english_species, english_species),
            'ability': ability_ja.get(info['ability_en'], info['ability_en']),
            'types': {t: type_ja.get(info['type_en'][t], t) for t in types},
        }
        im = build(key, number, species, form, types, info['ability_en'],
                   text[key], names)
        im.save(f'{OUT}/{key}.png')
        print(f'  {key:20} {names["species"]}  {"/".join(names["types"][t] for t in types)}  '
              f'{names["ability"]}')
    print(f'{len(pulse_entries())} page(s) written to {OUT}')


if __name__ == '__main__':
    main()
