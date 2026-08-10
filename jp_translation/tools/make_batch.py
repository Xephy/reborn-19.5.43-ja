# -*- coding: utf-8 -*-
"""Emit untranslated map rows as numbered TSV batches.

Why not the {english: japanese} JSON the earlier passes used: that format makes
the agent re-emit every English line it was given, so roughly 40% of the output
tokens are a copy of the input. Here each row gets an id and the agent writes
back only `id<TAB>japanese`.

The id addresses a row directly (file + row index), so a batch can never write
into another agent's file the way an English-text match could — the --only /
--group guards exist to work around exactly that, and are unnecessary here.

    python3 jp_translation/tools/make_batch.py --group 1 --size 400
    -> jp_translation/work/batch/g1/g1_0001.tsv ...

Columns: id, speaker (may be empty), english.
"""
import argparse
import glob
import json
import os
import sys

SRC = 'jp_translation/work/src'
OUT = 'jp_translation/work/batch'


def load_speakers():
    path = 'jp_translation/work/speaker_map.json'
    if not os.path.exists(path):
        return {}
    return {k: v[0] for k, v in json.load(open(path, encoding='utf-8')).items()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--group', required=True)
    ap.add_argument('--size', type=int, default=400, help='rows per batch file')
    ap.add_argument('--files', nargs='*', help='override the group manifest')
    a = ap.parse_args()

    if a.files:
        names = [os.path.basename(f) for f in a.files]
    else:
        manifest = f'jp_translation/work/assign/group{a.group}.txt'
        if not os.path.exists(manifest):
            sys.exit(f'no manifest: {manifest}')
        names = sorted(l.strip() for l in open(manifest) if l.strip())

    speakers = load_speakers()
    outdir = os.path.join(OUT, f'g{a.group}')
    os.makedirs(outdir, exist_ok=True)
    for old in glob.glob(os.path.join(outdir, '*.tsv')):
        os.remove(old)

    rows = []
    for name in names:
        path = os.path.join(SRC, name)
        if not os.path.exists(path):
            continue
        stem = name[:-6]  # strip .jsonl
        for i, line in enumerate(open(path, encoding='utf-8')):
            if not line.strip():
                continue
            r = json.loads(line)
            if r.get('ja'):
                continue
            en = r['en'].replace('\t', ' ')
            rows.append((f'{stem}#{i}', speakers.get(r['en'], ''), en))

    n = 0
    for start in range(0, len(rows), a.size):
        n += 1
        chunk = rows[start:start + a.size]
        p = os.path.join(outdir, f'g{a.group}_{n:04d}.tsv')
        with open(p, 'w', encoding='utf-8', newline='\n') as f:
            for rid, spk, en in chunk:
                f.write(f'{rid}\t{spk}\t{en}\n')

    chars = sum(len(r[2]) for r in rows)
    print(f'group {a.group}: {len(rows)} rows / {chars:,} chars -> {n} batches in {outdir}')


if __name__ == '__main__':
    main()
