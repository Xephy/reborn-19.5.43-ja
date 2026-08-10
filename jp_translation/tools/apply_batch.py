# -*- coding: utf-8 -*-
"""Write `id<TAB>japanese` batch answers back into work/src/*.jsonl.

Ids are file+row addresses produced by make_batch.py, so this touches exactly
the rows that were handed out — no English-text matching, no cross-file leakage.

Every row is checked before it is written:
  * placeholders and control codes ({1}, \\PN, \\c[3], \\v[12] ...) must match
    the English side exactly, as a multiset
  * the answer must not still be the English text
Rejected rows are reported and left untranslated rather than written.

    python3 jp_translation/tools/apply_batch.py jp_translation/work/answers/g1_0001.tsv
    python3 jp_translation/tools/apply_batch.py jp_translation/work/answers/g1_*.tsv
"""
import argparse
import collections
import glob
import json
import os
import re
import sys

SRC = 'jp_translation/work/src'
# RPG Maker / Essentials control codes. The multi-letter ones must be listed
# before the single-letter fallback, and the fallback must consume exactly one
# letter: a greedy \\[A-Za-z]+ turns "\GCommon Candy" into the token "\GCommon",
# so the same line reads as a placeholder mismatch against its own translation.
TOKEN = re.compile(
    r'\\(?:wtnp|tts|wt|wm|PN|ch|se|me|[A-Za-z])(?:\[[^\]]*\])?'
    r'|\\[.|^/!]'
    r'|\{\d+\}|\[\d+\]'
)


TTS = re.compile(r'\\tts\[[^\]]*\]')
# \ch[event,default,label,label,...] draws a choice menu; the labels after the
# two leading numbers are on-screen text and get translated with the line.
# Everything inside \ch[...] after the two leading numbers is on-screen menu
# text that gets translated with the line, so the argument is dropped from the
# comparison the same way \tts is. The leading numbers are not checked either:
# the source writes them inconsistently ("\ch[62,- 1,...]", "\ch[385,-\n \n1,...]")
# and any pattern tight enough to validate them rejects real source data.
CH = re.compile(r'\\ch\[[^\]]*\]')

# Markup tags: <icon=fieldUp>, <c=green>, </c>, <fs=28>, <b>. Only the field
# notes are dense enough in these for a dropped tag to go unnoticed, so the
# check is opt-in via --tags rather than folded into the placeholder rule.
TAG = re.compile(r'<[^<>]*>')

# Established convention in the approved text: halfwidth ! and ?, which also
# cost half the width of the fullwidth forms in the message window.
WIDE_PUNCT = str.maketrans('！？', '!?')


def normalize(s):
    return s.translate(WIDE_PUNCT)


def tokens(s):
    # \tts[...] carries an alternate reading of the line for text-to-speech, so
    # its argument is translated along with the line and must not be compared.
    # Every other bracketed argument is an index or an asset name and must match.
    s = TTS.sub(r'\\tts[]', s)
    s = CH.sub(r'\\ch[]', s)
    return collections.Counter(TOKEN.findall(s))


def compatible(ja, en):
    """True when the answer keeps every control code the English line carries.

    Exact equality except for \\PN: it expands to the player's name at display
    time with no argument to get wrong, and Japanese word order often wants the
    name where English wrote "you". Extra \\PN is therefore allowed; a missing
    one still fails, because that silently drops the player's name.
    """
    a, b = tokens(ja), tokens(en)
    if a == b:
        return True
    extra = a - b
    return not (b - a) and set(extra) <= {'\\PN'}


ROW_START = re.compile(r'[^\t]+#\d+\t')


def records(path):
    """Yield (line number, row) from an answer file, one row per id.

    A handful of source strings contain a newline of their own (the ability
    descriptions on the field-note detail pages list one clause per line), so a
    row is not always a line. Anything that does not open with an `id<TAB>` is
    a continuation of the row above it.
    """
    rows = []
    for ln, line in enumerate(open(path, encoding='utf-8'), 1):
        line = line.rstrip('\n')
        if ROW_START.match(line) or not rows:
            rows.append([ln, line])
        else:
            rows[-1][1] += '\n' + line
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('files', nargs='+')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--tags', action='store_true',
                    help='also require <...> markup tags to match the English')
    a = ap.parse_args()

    paths = []
    for f in a.files:
        paths.extend(sorted(glob.glob(f)) or [f])

    answers = {}
    dupes = 0
    for p in paths:
        for ln, line in records(p):
            line = line.rstrip('\n')
            if not line.strip():
                continue
            if '\t' not in line:
                print(f'  ! {os.path.basename(p)}:{ln} no tab, skipped')
                continue
            rid, ja = line.split('\t', 1)
            rid = rid.strip()
            ja = normalize(ja.strip())
            if not ja:
                continue
            if rid in answers:
                dupes += 1
            answers[rid] = ja
    print(f'{len(answers)} answers loaded from {len(paths)} file(s)'
          + (f' ({dupes} duplicate id(s), last wins)' if dupes else ''))

    by_file = collections.defaultdict(dict)
    bad_id = 0
    for rid, ja in answers.items():
        if '#' not in rid:
            bad_id += 1
            continue
        stem, idx = rid.rsplit('#', 1)
        if not idx.isdigit():
            bad_id += 1
            continue
        by_file[stem + '.jsonl'][int(idx)] = ja

    applied = skipped = rejected = 0
    problems = []
    for name, wanted in sorted(by_file.items()):
        path = os.path.join(SRC, name)
        if not os.path.exists(path):
            problems.append(f'{name}: no such file')
            continue
        rows = [json.loads(l) for l in open(path, encoding='utf-8') if l.strip()]
        n = 0
        for idx, ja in wanted.items():
            if idx >= len(rows):
                problems.append(f'{name}#{idx}: out of range')
                continue
            r = rows[idx]
            if r['ja']:
                skipped += 1
                continue
            if not compatible(ja, r['en']):
                problems.append(f'{name}#{idx}: placeholder mismatch | {r["en"]} | {ja}')
                rejected += 1
                continue
            if a.tags and collections.Counter(TAG.findall(ja)) != collections.Counter(TAG.findall(r['en'])):
                problems.append(f'{name}#{idx}: tag mismatch | {r["en"]} | {ja}')
                rejected += 1
                continue
            # Identity is the right answer for symbols, digits, acronyms and the
            # game's garbled/ciphered text ("\PN!", "GTS", "Kzzzzzztttt--",
            # "-- X? X7'F 5MJH K5XMK"). Real English prose that came back
            # untouched has both spaces and lowercase words; the noise strings
            # are missing one or the other.
            plain = TOKEN.sub('', r['en'])
            if ja == r['en'] and ' ' in plain.strip() and re.search(r'[a-z]{3}', plain):
                problems.append(f'{name}#{idx}: untranslated (echoed English)')
                rejected += 1
                continue
            r['ja'] = ja
            n += 1
        if n and not a.dry_run:
            with open(path, 'w', encoding='utf-8', newline='\n') as f:
                for r in rows:
                    f.write(json.dumps(r, ensure_ascii=False) + '\n')
        applied += n

    print(f'applied {applied}; already-filled {skipped}; rejected {rejected}; bad id {bad_id}'
          + (' (dry run)' if a.dry_run else ''))
    for p in problems[:40]:
        print('  ! ' + p)
    if len(problems) > 40:
        print(f'  ... {len(problems) - 40} more')


if __name__ == '__main__':
    main()
