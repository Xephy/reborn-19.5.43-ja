# -*- coding: utf-8 -*-
"""Collect out_*.json (id->ja) into work/map_ja_g1_NNN.json ({en: ja}) for apply_map.py.

    python3 jp_translation/work/g1batch/collect.py 001 002 003   -> map_ja_g1_001.json ...
    python3 jp_translation/work/g1batch/collect.py all
"""
import glob, json, os, re, sys

D = 'jp_translation/work/g1batch'
pat = re.compile(r'\\PN|\{\d+\}|\\n|\\v\[\d+\]|\\G|\\wtnp?\[\d+\]|\\ch\[|\\tts\[|<[^>]+>')

nums = sys.argv[1:]
if nums == ['all']:
    nums = sorted(os.path.basename(p)[4:-5] for p in glob.glob(f'{D}/out_*.json'))

total = 0
for n in nums:
    fin, fout = f'{D}/in_{n}.jsonl', f'{D}/out_{n}.json'
    if not os.path.exists(fout):
        print(f'{n}: no output'); continue
    src = {}
    for l in open(fin, encoding='utf-8'):
        r = json.loads(l)
        src[str(r['id'])] = r['en']
    out = json.load(open(fout, encoding='utf-8'))
    d, skipped = {}, 0
    for k, ja in out.items():
        en = src.get(k)
        if en is None or not ja:
            skipped += 1; continue
        if sorted(pat.findall(en)) != sorted(pat.findall(ja)):
            skipped += 1; continue          # never write a placeholder-broken line
        d[en] = ja
    dest = f'jp_translation/work/map_ja_g1_{n}.json'
    json.dump(d, open(dest, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    total += len(d)
    print(f'{n}: {len(d)} ok, {skipped} skipped -> {dest}')
print('total', total)
