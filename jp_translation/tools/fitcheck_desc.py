#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""説明文セクションが表示枠に収まるか確認する。

fitcheck.py は「折り返さない 1 行スロット」用。こちらは drawTextEx /
Window_UnformattedTextPokemon のように自動折り返しするスロット向けに、
Scripts/DrawText.rb の getLineBrokenChunks と同じ規則で行数を数える。

    python3 jp_translation/tools/fitcheck_desc.py            # 全スロット
    python3 jp_translation/tools/fitcheck_desc.py --slot move --show 20

ゲームルートから実行すること。
"""
import argparse
import json
import os
import re
import sys

from PIL import ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(HERE, "..", "work", "src")
FONT_PATH = "patch/Fonts/pokemonemerald.ttf"
FONT_SIZE = 32          # fitcheck.py と同じ: mkxp-z が font.size=36 を 32px で描く

# DrawText.rb の日本語行分割規則
JA_WIDE = re.compile(r"[　-〿぀-ヿㇰ-ㇿ㐀-䶿"
                     r"一-鿿＀-￯]")
JA_NO_HEAD = set("　、。，．・：；？！゛゜ー々〜…‥ぁぃぅぇぉっゃゅょゎ"
                 "ァィゥェォッャュョヮヵヶ)]}）］｝〉》」』】〕｣!?:;")
JA_NO_END = set("（［｛〈《「『【〔｢([{")

SLOTS = {
    "move": dict(
        file="06_move_descriptions.jsonl", width=238, lines=5,
        where="Summary.rb:854/887 — drawTextEx(overlay, 4, 218, 238, 5, ...)",
        note="技の説明。ステータス画面の技詳細。いちばん狭い。",
    ),
    "ability": dict(
        file="10_ability_descs.jsonl", width=282, lines=2,
        where="Summary.rb:575/658 — drawTextEx(overlay, 224, 316, 282, 2, ...)",
        note="特性の説明。2行しかないのでほとんどの公式文が入らない。",
    ),
    "item": dict(
        file="08_item_descriptions.jsonl", width=428, lines=4,
        where="Bag.rb:150- — itemtextwindow は width=Graphics.width-84, height=128",
        note="道具の説明。バッグ/ショップ。",
    ),
    "entry": dict(
        file="03_entries.jsonl", width=428, lines=4,
        where="PokedexScene.rb:752 — drawTextEx(bitmap, 42, 240, Graphics.width-84, 4, ...)",
        note="図鑑の説明文。",
    ),
}


def can_break_before(prev, cur):
    if not prev or not cur:
        return False
    if not JA_WIDE.search(prev) and not JA_WIDE.search(cur):
        return False
    if cur in JA_NO_HEAD:
        return False
    if prev in JA_NO_END:
        return False
    return True


def split_chunks(word):
    if not word or not JA_WIDE.search(word):
        return [word]
    out, cur = [], ""
    for i, ch in enumerate(word):
        if i > 0 and cur and can_break_before(word[i - 1], ch):
            out.append(cur)
            cur = ""
        cur += ch
    if cur:
        out.append(cur)
    return out


WORD_RE = re.compile(r"\n|\S*-+|\S*[ \r\t\f]?")


def count_lines(font, text, width):
    """getLineBrokenChunks と同じ手順で必要な行数を返す。"""
    x, lines = 0, 1
    pos = 0
    while pos < len(text):
        m = WORD_RE.match(text, pos)
        if not m or m.end() == pos:
            pos += 1
            continue
        word = m.group(0)
        pos = m.end()
        if word == "\n":
            x = 0
            lines += 1
            continue
        for chunk in split_chunks(word):
            if not chunk:
                continue
            w = font.getlength(chunk)
            if x > 0 and x + w >= width - 2:
                x = 0
                lines += 1
            x += w
    return lines


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--slot", choices=sorted(SLOTS))
    ap.add_argument("--show", type=int, default=10, help="あふれた例をいくつ出すか")
    a = ap.parse_args()

    try:
        font = ImageFont.truetype(FONT_PATH, FONT_SIZE)
    except OSError:
        sys.exit("font not found: %s (ゲームルートで実行すること)" % FONT_PATH)

    slots = [a.slot] if a.slot else sorted(SLOTS)
    worst_overall = 0
    for name in slots:
        spec = SLOTS[name]
        path = os.path.join(SRC_DIR, spec["file"])
        rows = [json.loads(l) for l in open(path, encoding="utf-8") if l.strip()]
        over = []
        worst = 0
        for d in rows:
            if not d.get("ja"):
                continue
            n = count_lines(font, d["ja"], spec["width"])
            worst = max(worst, n)
            if n > spec["lines"]:
                over.append((n, d["key"], d["ja"]))
        over.sort(reverse=True)
        print("== %s  %dpx x %d行  (%s)" % (name, spec["width"], spec["lines"], spec["where"]))
        print("   %d件中 %d件があふれ / 最大 %d行" % (len(rows), len(over), worst))
        for n, k, ja in over[:a.show]:
            print("   %2d行 key=%-5s %s" % (n, k, ja))
        worst_overall = max(worst_overall, len(over))
    return 1 if worst_overall else 0


if __name__ == "__main__":
    sys.exit(main() or 0)
