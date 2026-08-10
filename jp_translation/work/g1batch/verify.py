# -*- coding: utf-8 -*-
"""Verify one batch: python3 jp_translation/work/g1batch/verify.py 007"""
import json, re, sys, os

n = sys.argv[1]
IN = f'jp_translation/work/g1batch/in_{n}.jsonl'
OUT = f'jp_translation/work/g1batch/out_{n}.json'
src = {}
for l in open(IN, encoding='utf-8'):
    r = json.loads(l)
    src[str(r['id'])] = r['en']
if not os.path.exists(OUT):
    sys.exit('missing ' + OUT)
out = json.load(open(OUT, encoding='utf-8'))

pat = re.compile(r'\\PN|\{\d+\}|\\n|\\v\[\d+\]|\\G|\\wtnp?\[\d+\]|\\ch\[|\\tts\[|<[^>]+>')
bad = []
for k, en in src.items():
    ja = out.get(k)
    if not ja:
        continue
    if sorted(pat.findall(en)) != sorted(pat.findall(ja)):
        bad.append((k, en, ja))
missing = sorted(set(src) - set(k for k, v in out.items() if v), key=int)
extra = sorted(set(out) - set(src))
print(f'items {len(src)}  translated {len([v for v in out.values() if v])}  missing {len(missing)}  unknown-ids {len(extra)}')
if missing:
    print('missing ids:', missing[:60], '...' if len(missing) > 60 else '')
if extra:
    print('unknown ids:', extra[:60])
print('placeholder mismatch', len(bad))
for b in bad[:25]:
    print('  id', b[0], '\n    EN', b[1], '\n    JA', b[2])

joyo = set(open('jp_translation/tools/joyo.txt', encoding='utf-8').read()) | set('丰')
bk = {}
for k, ja in out.items():
    for c in ja:
        if '一' <= c <= '\u9fff' and c not in joyo:
            bk.setdefault(c, (k, ja[:40]))
print('non-joyo kanji:', len(bk) or 'none')
for c, (k, s) in bk.items():
    print('  ', c, 'id', k, s)
sys.exit(1 if (bad or missing or extra or bk) else 0)
