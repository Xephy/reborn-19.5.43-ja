# -*- coding: utf-8 -*-
"""Apply a flat {english: japanese} JSON across every work/src/*.jsonl file.

Version-independent by design: it matches on the English text, never on a
section id or an array index. 19.5.43 converted every array section of
messages.dat into a hash keyed by the English string and moved the trainer
defeat lines out of trainers.dat into section 16, so anything keyed by
position stops working across versions — this does not.

    python3 jp_translation/tools/apply_translations.py jp_translation/work/speech_ja_batch1.json

Existing non-empty `ja` values are left alone unless --overwrite is given.
"""
import argparse
import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import msgtypes  # noqa: E402

SRC = 'jp_translation/work/src'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('files', nargs='+', help='JSON files of {english: japanese}')
    ap.add_argument('--only', action='append', metavar='NAME',
                    help='restrict to these work/src files (repeatable). '
                         'Without it every file is scanned, which is what keeps '
                         'a line worded the same in battle and in dialogue — but '
                         'it also lets a short entry like "Ugh..." leak into '
                         'hundreds of map files. Use --only when translating a '
                         'section that contains short, generic strings.')
    ap.add_argument('--overwrite', action='store_true')
    ap.add_argument('--dry-run', action='store_true')
    a = ap.parse_args()

    trans = {}
    for path in a.files:
        for k, v in json.load(open(path, encoding='utf-8')).items():
            if k.startswith('_') or not v:
                continue
            trans[msgtypes.string_to_key(k)] = v
    print(f'{len(trans)} translations loaded')

    applied = 0
    used = set()
    per_file = {}
    paths = sorted(glob.glob(os.path.join(SRC, '*.jsonl')))
    if a.only:
        wanted = {os.path.basename(x) for x in a.only}
        paths = [p for p in paths if os.path.basename(p) in wanted]
        missing = wanted - {os.path.basename(p) for p in paths}
        if missing:
            sys.exit('no such file(s) under %s: %s' % (SRC, ', '.join(sorted(missing))))
        print('restricted to: ' + ', '.join(os.path.basename(p) for p in paths))

    for path in paths:
        rows = [json.loads(l) for l in open(path, encoding='utf-8') if l.strip()]
        n = 0
        for r in rows:
            if r['ja'] and not a.overwrite:
                continue
            ja = trans.get(msgtypes.string_to_key(r['en']))
            if ja and r['ja'] != ja:
                r['ja'] = ja
                used.add(msgtypes.string_to_key(r['en']))
                n += 1
        if n:
            per_file[os.path.basename(path)] = n
            applied += n
            if not a.dry_run:
                with open(path, 'w', encoding='utf-8', newline='\n') as f:
                    for r in rows:
                        f.write(json.dumps(r, ensure_ascii=False) + '\n')

    for k, v in sorted(per_file.items()):
        print(f'  {k:28s} +{v}')
    unused = len(trans) - len(used)
    print(f'\napplied {applied}; {unused} translation(s) matched nothing in this version')
    if a.dry_run:
        print('(dry run — nothing written)')


if __name__ == '__main__':
    main()
