# -*- coding: utf-8 -*-
"""Merge story-trainer line translations into the map:0 section.

Trainer ace/defeat lines live in Data/trainers.dat, not in messages.dat, so they
never appear in the extracted sections. They are still routed through
_MAPINTL($game_map.map_id, message) at display time (Scripts/Messages.rb:527),
and getFromMapHash falls back to map 0 for any map, so putting them in map:0
makes them resolve everywhere. Verified in-game:
    _MAPINTL(0/31/999, "Tch. Whatever.") -> "ちっ。どうでもいいさ"

    python3 jp_translation/tools/merge_speech.py jp_translation/work/speech_ja_batch1.json
"""
import json
import sys
import os

MAP0 = 'jp_translation/work/src/map_0000.jsonl'
SPEAKERS = 'jp_translation/work/speaker_map.json'


def main():
    if len(sys.argv) < 2:
        sys.exit('usage: merge_speech.py <translations.json> [more.json ...]')

    known = set(json.load(open(SPEAKERS, encoding='utf-8'))) if os.path.exists(SPEAKERS) else set()

    trans = {}
    for path in sys.argv[1:]:
        for k, v in json.load(open(path, encoding='utf-8')).items():
            if k.startswith('_'):        # notes
                continue
            trans[k] = v

    rows = [json.loads(l) for l in open(MAP0, encoding='utf-8') if l.strip()]
    by_key = {r['key']: r for r in rows}

    added = updated = unknown = 0
    for en, ja in trans.items():
        if not ja:
            continue
        if en not in known:
            unknown += 1
        r = by_key.get(en)
        if r is None:
            rows.append({'sec': 'map:0', 'key': en, 'en': en, 'ja': ja})
            added += 1
        elif r['ja'] != ja:
            r['ja'] = ja
            updated += 1

    with open(MAP0, 'w', encoding='utf-8') as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + '\n')

    total = sum(1 for r in rows if r['ja'])
    print(f'{len(trans)} translations: added {added}, updated {updated}')
    if unknown:
        print(f'  warning: {unknown} keys are not in speaker_map.json '
              f'(typo in the English, or not a trainer line)')
    print(f'map:0 now has {total} translated / {len(rows)} entries')


if __name__ == '__main__':
    main()
