# -*- coding: utf-8 -*-
"""Apply {english: japanese} to a fixed set of map files only.

Story dialogue is split across agents by map file. apply_translations.py scans
every file by design (so a line reads the same in battle and in dialogue), but
for map work that lets a short generic line leak into other agents' files and
overwrite work in flight. This restricts writes to one group's manifest.

    python3 jp_translation/tools/apply_map.py --group 1 work/map_ja_001.json
"""
import argparse, glob, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import msgtypes

SRC = 'jp_translation/work/src'

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--group', required=True, help='manifest under work/assign/group<N>.txt')
    ap.add_argument('files', nargs='+')
    ap.add_argument('--dry-run', action='store_true')
    a = ap.parse_args()

    manifest = f'jp_translation/work/assign/group{a.group}.txt'
    if not os.path.exists(manifest):
        sys.exit(f'no manifest: {manifest}')
    allowed = {l.strip() for l in open(manifest) if l.strip()}

    trans = {}
    for p in a.files:
        for k, v in json.load(open(p, encoding='utf-8')).items():
            if not k.startswith('_') and v:
                trans[msgtypes.string_to_key(k)] = v
    print(f'{len(trans)} translations, {len(allowed)} files in group {a.group}')

    applied = 0
    for name in sorted(allowed):
        path = os.path.join(SRC, name)
        if not os.path.exists(path):
            continue
        rows = [json.loads(l) for l in open(path, encoding='utf-8') if l.strip()]
        n = 0
        for r in rows:
            if r['ja']:
                continue
            ja = trans.get(msgtypes.string_to_key(r['en']))
            if ja:
                r['ja'] = ja
                n += 1
        if n and not a.dry_run:
            with open(path, 'w', encoding='utf-8', newline='\n') as f:
                for r in rows:
                    f.write(json.dumps(r, ensure_ascii=False) + '\n')
        applied += n
    print(f'applied {applied}' + (' (dry run)' if a.dry_run else ''))

if __name__ == '__main__':
    main()
