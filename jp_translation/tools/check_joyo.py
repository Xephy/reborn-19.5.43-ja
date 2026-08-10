# -*- coding: utf-8 -*-
"""Flag kanji outside the joyo list in the translated text.

The project rule is joyo-only, so anything here is either a typo or a word that
needs a kana spelling (まひ, はがれる) or a joyo synonym (深淵 -> 奈落).
jp_translation/tools/joyo.txt holds the 2136-character list.

    python3 jp_translation/tools/check_joyo.py
"""
import collections, glob, json, os, sys

JOYO = 'jp_translation/tools/joyo.txt'

def main():
    if not os.path.exists(JOYO):
        sys.exit(f'missing {JOYO}')
    joyo = set(open(JOYO, encoding='utf-8').read())
    # Glitch/corrupted-text effects deliberately substitute look-alike CJK
    # characters for kana (ス丰ル for スキル), mirroring the English leetspeak.
    joyo |= set('丰')
    cnt, example = collections.Counter(), {}
    for path in sorted(glob.glob('jp_translation/work/src/*.jsonl')):
        base = os.path.basename(path)
        for line in open(path, encoding='utf-8'):
            r = json.loads(line)
            for c in r['ja']:
                if '一' <= c <= '鿿' and c not in joyo:
                    cnt[c] += 1
                    example.setdefault(c, (base, r['ja'][:40]))
    if not cnt:
        print('non-joyo kanji: none')
        return 0
    print(f'non-joyo kanji: {len(cnt)} distinct, {sum(cnt.values())} occurrences')
    for c, n in cnt.most_common():
        base, s = example[c]
        print(f'  {c} {n:4d}  {base:26s} {s}')
    return 1

if __name__ == '__main__':
    sys.exit(main())
