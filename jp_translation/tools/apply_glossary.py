# -*- coding: utf-8 -*-
"""Fill the name sections of work/src/*.jsonl from the glossary.

The glossary already resolves Pokémon, move, item, ability, type and trainer-class
names, so those sections can be filled mechanically instead of translated by hand.
Only entries whose `ja` is still empty are touched, so hand edits are never lost.

    python3 jp_translation/tools/apply_glossary.py            # write
    python3 jp_translation/tools/apply_glossary.py --dry-run  # report only
"""
import argparse
import json
import os

SRC = 'jp_translation/work/src'
GLOSSARY = 'jp_translation/work/glossary.json'

# jsonl file -> glossary category
SECTIONS = {
    '01_species.jsonl':       'species',
    '05_moves.jsonl':         'moves',
    '07_items.jsonl':         'items',
    '09_abilities.jsonl':     'abilities',
    '11_types.jsonl':         'types',
    '12_trainer_types.jsonl': 'trainer_types',
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry-run', action='store_true')
    a = ap.parse_args()

    gloss = json.load(open(GLOSSARY, encoding='utf-8'))
    total_filled = total_missing = 0
    missing_samples = []

    for fname, cat in SECTIONS.items():
        path = os.path.join(SRC, fname)
        if not os.path.exists(path):
            print(f'  skip (not found): {fname}')
            continue
        table = gloss[cat]
        rows = [json.loads(l) for l in open(path, encoding='utf-8') if l.strip()]

        filled = kept = missing = 0
        for r in rows:
            if r['ja']:
                kept += 1
                continue
            ja = table.get(r['en'])
            if ja:
                r['ja'] = ja
                filled += 1
            elif r['en'].strip():
                missing += 1
                if len(missing_samples) < 20:
                    missing_samples.append(f"{cat}: {r['en']!r}")

        if not a.dry_run:
            with open(path, 'w', encoding='utf-8') as f:
                for r in rows:
                    f.write(json.dumps(r, ensure_ascii=False) + '\n')

        total_filled += filled
        total_missing += missing
        print(f'  {fname:24s} {len(rows):5d} entries   filled {filled:5d}   '
              f'already-translated {kept:4d}   no-match {missing:4d}')

    print(f'\nfilled {total_filled}, no glossary match for {total_missing}')
    if missing_samples:
        print('unmatched samples:')
        for s in missing_samples:
            print('   ', s)
    if a.dry_run:
        print('\n(dry run — nothing written)')


if __name__ == '__main__':
    main()
