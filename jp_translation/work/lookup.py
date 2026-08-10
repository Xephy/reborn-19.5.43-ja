#!/usr/bin/env python3
"""Quick lookup helper for translators.
Usage:
  python3 lookup.py name <term>       # search names_ja.json (substring, case-insens)
  python3 lookup.py place <term>      # search places_ja.json
  python3 lookup.py gloss <term>      # search glossary.json across all sections
  python3 lookup.py speaker <text>    # search speaker_map.json exact/substring
  python3 lookup.py joyo <file.tsv>   # check non-joyo kanji in a 2-col answer tsv
"""
import json, sys, os

BASE = os.path.dirname(os.path.abspath(__file__))

def load(name):
    with open(os.path.join(BASE, name), encoding='utf-8') as f:
        return json.load(f)

def cmd_name(term):
    d = load('names_ja.json')
    term_l = term.lower()
    for k, v in d.items():
        if term_l in k.lower():
            print(repr(k), '->', v)

def cmd_place(term):
    d = load('places_ja.json')
    term_l = term.lower()
    for k, v in d.items():
        if k.startswith('_'):
            continue
        if term_l in k.lower():
            print(repr(k), '->', v)

def cmd_gloss(term):
    d = load('glossary.json')
    term_l = term.lower()
    for sec, table in d.items():
        for k, v in table.items():
            if term_l in k.lower():
                print(sec, repr(k), '->', v)

def cmd_speaker(term):
    d = load('speaker_map.json')
    term_l = term.lower()
    for k, v in d.items():
        if term_l in k.lower():
            print(repr(k), '->', v)

def cmd_joyo(path):
    joyo_path = os.path.join(BASE, '..', 'tools', 'joyo.txt')
    joyo = set(open(joyo_path, encoding='utf-8').read())
    joyo |= set('丰')
    bad = {}
    for ln, line in enumerate(open(path, encoding='utf-8'), 1):
        line = line.rstrip('\n')
        if not line.strip() or '\t' not in line:
            continue
        rid, ja = line.split('\t', 1)
        for c in ja:
            if '一' <= c <= '鿿' and c not in joyo:
                bad.setdefault(c, []).append((ln, rid, ja[:40]))
    if not bad:
        print('OK: no non-joyo kanji')
    else:
        for c, occ in bad.items():
            print(f'NON-JOYO {c!r} x{len(occ)}')
            for ln, rid, s in occ[:5]:
                print(f'   line {ln} {rid}: {s}')

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    cmd, term = sys.argv[1], ' '.join(sys.argv[2:])
    fn = globals().get(f'cmd_{cmd}')
    if not fn:
        print('unknown command', cmd)
        sys.exit(1)
    fn(term)
