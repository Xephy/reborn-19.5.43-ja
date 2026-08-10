# -*- coding: utf-8 -*-
"""Rebuild work/src/*.jsonl translations from an already-built japanese.dat.

Array sections in messages.dat are keyed by integer index, so a translation
file only means anything next to the messages.dat it was built from. To move
translations onto a newer game version, the pair (old messages.dat,
old japanese.dat) is turned back into English -> Japanese and re-matched
against the new English text.

    python3 jp_translation/tools/recover_from_dat.py \
        --old-base jp_translation/backup/recover/messages_19.5.0.dat \
        --old-ja   jp_translation/backup/recover/japanese_6900.dat

Existing non-empty `ja` values in work/src are never overwritten.
"""
import argparse
import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rmarshal      # noqa: E402
import msgtypes      # noqa: E402

SRC = 'jp_translation/work/src'


def pairs_from(old_en, old_ja):
    """English text -> Japanese text, for one section object."""
    out = {}
    if old_ja is None:
        return out
    if isinstance(old_ja, dict):
        # Hash sections are keyed by the English text itself.
        for k, ja in old_ja.items():
            if ja:
                out[msgtypes.string_to_key(k)] = ja
    elif isinstance(old_ja, list):
        # Array sections: index into the English side to recover the pairing.
        if not isinstance(old_en, list):
            return out
        for i, ja in enumerate(old_ja):
            if ja and i < len(old_en) and old_en[i]:
                out[msgtypes.string_to_key(old_en[i])] = ja
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--old-base', required=True)
    ap.add_argument('--old-ja', required=True)
    ap.add_argument('--dry-run', action='store_true')
    a = ap.parse_args()

    old_en = rmarshal.load(a.old_base)
    old_ja = rmarshal.load(a.old_ja)

    # section id -> {english: japanese}; map sections share one pool because
    # map ids can be renumbered between versions.
    by_sec = {}
    map_pool = {}
    for sec in range(1, len(old_ja)):
        e = old_en[sec] if sec < len(old_en) else None
        by_sec[sec] = pairs_from(e, old_ja[sec])
    if old_ja and old_ja[0]:
        old_maps = old_en[0] if old_en and old_en[0] else []
        for mapid, data in enumerate(old_ja[0]):
            e = old_maps[mapid] if mapid < len(old_maps) else None
            map_pool.update(pairs_from(e, data))

    total_recovered = total_missing = 0
    for path in sorted(glob.glob(os.path.join(SRC, '*.jsonl'))):
        rows = [json.loads(l) for l in open(path, encoding='utf-8') if l.strip()]
        if not rows:
            continue
        sec = rows[0]['sec']
        pool = map_pool if isinstance(sec, str) and sec.startswith('map:') \
            else by_sec.get(sec, {})
        if not pool:
            continue

        n = 0
        for r in rows:
            if r['ja']:
                continue
            ja = pool.get(msgtypes.string_to_key(r['en']))
            if ja:
                r['ja'] = ja
                n += 1
        if n and not a.dry_run:
            with open(path, 'w', encoding='utf-8', newline='\n') as f:
                for r in rows:
                    f.write(json.dumps(r, ensure_ascii=False) + '\n')
        if n:
            print(f'  {os.path.basename(path):28s} +{n}')
        total_recovered += n
        total_missing += sum(1 for r in rows if not r['ja'])

    print(f'\nrecovered {total_recovered} translations; {total_missing} entries still untranslated')
    if a.dry_run:
        print('(dry run — nothing written)')


if __name__ == '__main__':
    main()
