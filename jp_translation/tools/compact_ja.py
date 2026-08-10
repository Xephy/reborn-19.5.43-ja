# -*- coding: utf-8 -*-
"""Tighten Japanese description text so it fits the game's fixed slots.

Two transforms, in this order:

1. Kana -> kanji for a fixed vocabulary of game terms. Restricted to joyo
   kanji, and to multi-character readings that are unambiguous in this domain
   (こうげき is always 攻撃; かえる is not touched because タマゴがかえる is 孵る,
   which is not joyo, and 帰る/変える are equally plausible readings).
2. Removal of the U+3000 word separators. Pokemon games use them because the
   text is otherwise all kana; once the content words carry kanji the word
   boundaries are visible without them.

Type names are deliberately left alone: they double as glossary entries
(ほのお, みず, ...) and must match the type list exactly.

    python3 jp_translation/tools/compact_ja.py --dry-run
    python3 jp_translation/tools/compact_ja.py
"""
import argparse
import glob
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Sections whose text is prose shown in a fixed-size box.
TARGETS = [
    '02_kinds.jsonl',
    '03_entries.jsonl',
    '06_move_descriptions.jsonl',
    '08_item_descriptions.jsonl',
    '10_ability_descs.jsonl',
]

# Never rewritten: these are also glossary entries and must match the type list.
TYPE_WORDS = [
    'ノーマル', 'ほのお', 'みず', 'でんき', 'くさ', 'こおり', 'かくとう', 'どく',
    'じめん', 'ひこう', 'エスパー', 'むし', 'いわ', 'ゴースト', 'ドラゴン', 'あく',
    'はがね', 'フェアリー',
]

# Longest-first so そうび does not eat そうびする etc.
TERMS = [
    ('とくこうと とくぼう', '特攻と特防'),
    ('こうげきと ぼうぎょ', '攻撃と防御'),
    ('めいちゅうりつ', '命中率'),
    ('ついかこうか', '追加効果'),
    ('せっしょく', '接触'),
    ('せんせいわざ', '先制技'),
    ('へんかわざ', '変化技'),
    ('とくしゅこうげき', '特殊攻撃'),
    ('ぶつりこうげき', '物理攻撃'),
    ('こうげき', '攻撃'),
    ('ぼうぎょ', '防御'),
    ('とくこう', '特攻'),
    ('とくぼう', '特防'),
    ('すばやさ', '素早さ'),
    ('いりょく', '威力'),
    ('めいちゅう', '命中'),
    ('じょうたい', '状態'),
    ('とくせい', '特性'),
    ('きゅうしょ', '急所'),
    ('かいふく', '回復'),
    ('はんげん', '半減'),
    ('はんぶん', '半分'),
    ('りょうほう', '両方'),
    ('あいて', '相手'),
    ('じぶん', '自分'),
    ('みかた', '味方'),
    ('ばあい', '場合'),
    ('こうか', '効果'),
    ('どうぐ', '道具'),
    ('もちもの', '持ち物'),
    ('せんとう', '戦闘'),
    ('とうじょう', '登場'),
    ('こうたい', '交代'),
    ('たいりょく', '体力'),
    ('ぜったいに', '絶対に'),
    ('かならず', '必ず'),
    ('ときどき', '時々'),
    ('すべて', '全て'),
    ('おわりに', '終わりに'),
    ('つかう', '使う'),
    ('つかった', '使った'),
    ('うける', '受ける'),
    ('うけると', '受けると'),
    ('うけた', '受けた'),
    ('あたえる', '与える'),
    ('ふせぐ', '防ぐ'),
    ('へらす', '減らす'),
    ('ふやす', '増やす'),
    ('あがる', '上がる'),
    ('さがる', '下がる'),
    ('あげる', '上げる'),
    ('さげる', '下げる'),
    ('たおす', '倒す'),
    ('たおされる', '倒される'),
    ('たおされた', '倒された'),
    ('ひろってくる', '拾ってくる'),
    ('まもる', '守る'),
    ('つよく', '強く'),
    ('よわく', '弱く'),
    ('おおきく', '大きく'),
    ('すこし', '少し'),
    ('ほかの', '他の'),
    ('からだ', '体'),
    ('あたま', '頭'),
    ('ちから', '力'),
    # --- second pass: everything the first table left as kana -------------
    ('すばやく', '素早く'),
    ('たおされない', '倒されない'),
    ('たおされると', '倒されると'),
    ('たおれる', '倒れる'),
    ('あたらない', '当たらない'),
    ('あたりやすく', '当たりやすく'),
    ('あたると', '当たると'),
    ('あたった', '当たった'),
    ('あたる', '当たる'),
    ('ばくはつ', '爆発'),
    ('いちげき', '一撃'),
    ('だれも', '誰も'),
    ('だれか', '誰か'),
    ('あめを', '雨を'),
    ('あめが', '雨が'),
    ('あめの', '雨の'),
    ('ひざし', '日差し'),
    ('すなあらし', '砂嵐'),
    ('のうりょく', '能力'),
    ('へんか', '変化'),
    ('かくりつ', '確率'),
    ('さいだい', '最大'),
    ('ぜんいん', '全員'),
    ('こんらん', '混乱'),
    ('ねむって', '眠って'),
    ('ねむった', '眠った'),
    ('ねむり', '眠り'),
    ('ねむる', '眠る'),
    ('たたかう', '戦う'),
    ('こうどう', '行動'),
    ('じゅんばん', '順番'),
    ('とくべつ', '特別'),
    ('ひつよう', '必要'),
    ('おなじ', '同じ'),
    ('おおい', '多い'),
    ('すくない', '少ない'),
    ('つづく', '続く'),
    ('つづけて', '続けて'),
    ('すがた', '姿'),
    ('おもさ', '重さ'),
    ('たかさ', '高さ'),
    ('ながさ', '長さ'),
    ('まわり', '周り'),
    ('ばしょ', '場所'),
    ('じかん', '時間'),
    ('てんき', '天気'),
    ('ひかり', '光'),
    ('かぜ', '風'),
    ('とばす', '飛ばす'),
    ('とんで', '飛んで'),
    ('はしる', '走る'),
    ('ふらす', '降らす'),
    ('ふると', '降ると'),
    ('ふらせる', '降らせる'),
    ('なおす', '治す'),
    ('なおる', '治る'),
    ('ふせいで', '防いで'),
    ('まもって', '守って'),
    ('つよい', '強い'),
    ('よわい', '弱い'),
    ('はやく', '速く'),
    ('おそく', '遅く'),
]


def convert(text):
    if not text:
        return text
    # Protect type names from the kana->kanji pass.
    holes = {}
    for i, w in enumerate(TYPE_WORDS):
        tok = '\x00%d\x00' % i
        if w in text:
            text = text.replace(w, tok)
            holes[tok] = w
    # Terms may be written with or without the U+3000 separator inside them.
    for kana, kanji in TERMS:
        text = text.replace(kana, kanji)
        if ' ' in kana or '　' in kana:
            continue
        text = text.replace(kana.replace(' ', '　'), kanji)
    text = text.replace('　', '')
    for tok, w in holes.items():
        text = text.replace(tok, w)
    return text


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--samples', type=int, default=6)
    a = ap.parse_args()

    sys.path.insert(0, 'jp_translation/tools')
    from fit_lines import best_size

    total = changed = 0
    samples = []
    for name in TARGETS:
        path = os.path.join('jp_translation/work/src', name)
        if not os.path.exists(path):
            continue
        rows = [json.loads(l) for l in open(path, encoding='utf-8') if l.strip()]
        n = 0
        for r in rows:
            if not r['ja']:
                continue
            new = convert(r['ja'])
            total += 1
            if new != r['ja']:
                if len(samples) < a.samples and name == '10_ability_descs.jsonl':
                    samples.append((r['ja'], new))
                r['ja'] = new
                n += 1
        changed += n
        if not a.dry_run and n:
            with open(path, 'w', encoding='utf-8', newline='\n') as f:
                for r in rows:
                    f.write(json.dumps(r, ensure_ascii=False) + '\n')
        # ability descriptions are the tight slot; report the fit
        if name == '10_ability_descs.jsonl':
            over = sum(1 for r in rows
                       if r['ja'] and best_size(r['ja'], 282, 2) is None)
            full = sum(1 for r in rows
                       if r['ja'] and best_size(r['ja'], 282, 2) == 36)
            print(f'  {name}: 溢れ {over}件 / 縮小不要 {full}件')
        else:
            print(f'  {name}: {n} 件を変換')

    print(f'\n{changed}/{total} 件を変換')
    for a_, b_ in samples:
        print(f'\n  前: {a_}\n  後: {b_}')
    if a.dry_run:
        print('\n(dry run — 書き込みなし)')


if __name__ == '__main__':
    main()
