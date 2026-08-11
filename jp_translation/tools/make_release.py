# -*- coding: utf-8 -*-
"""Pack the installable patch into dist/reborn-19.5.43-ja-<version>.zip.

The file list is read straight out of sync.sh, so the archive and the copy that
gets pushed to the play environments can never drift apart: whenever a script
starts being part of the patch it only has to be added in one place.

Everything lands at its game-relative path, so the archive is extracted over
the game folder as-is. The working files under jp_translation/ are not
included - the archive is what a player installs, not the sources.

    python3 jp_translation/tools/make_release.py v19.5.43-ja.1
    -> dist/reborn-19.5.43-ja.1.zip
"""
import argparse
import os
import re
import sys
import zipfile

SYNC = 'jp_translation/tools/sync.sh'
OUT_DIR = 'dist'
EXTRA = ['README.md']
BUILT_DAT = 'patch/Data/japanese.dat'
SRC_DIR = 'jp_translation/work/src'


def listed_paths():
    """(files, dirs) exactly as sync.sh pushes them."""
    src = open(SYNC, encoding='utf-8').read()

    def block(name):
        body = src.split(f'{name}=(', 1)[1].split('\n)', 1)[0]
        return re.findall(r'"([^"]+)"', body)

    return block('FILES'), block('DIRS')


def check_dat_is_current():
    """The .dat is a build product; warn rather than ship a stale one."""
    if not os.path.exists(BUILT_DAT):
        sys.exit(f'{BUILT_DAT} is missing - run build.py first')
    built = os.path.getmtime(BUILT_DAT)
    newer = [f for f in os.listdir(SRC_DIR)
             if f.endswith('.jsonl')
             and os.path.getmtime(os.path.join(SRC_DIR, f)) > built]
    if newer:
        sys.exit('translation sources are newer than %s - run build.py first:\n  %s'
                 % (BUILT_DAT, '\n  '.join(sorted(newer))))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('version', help='release tag, e.g. v19.5.43-ja.1')
    a = ap.parse_args()

    check_dat_is_current()
    files, dirs = listed_paths()

    members = list(files)
    for d in dirs:
        if not os.path.isdir(d):
            sys.exit(f'{d} is missing')
        members += sorted(os.path.join(d, f) for f in os.listdir(d)
                          if os.path.isfile(os.path.join(d, f)))
    members += EXTRA

    missing = [m for m in members if not os.path.exists(m)]
    if missing:
        sys.exit('missing:\n  ' + '\n  '.join(missing))

    os.makedirs(OUT_DIR, exist_ok=True)
    # v19.5.43-ja.1 -> reborn-19.5.43-ja.1.zip
    out = os.path.join(OUT_DIR, f'reborn-{a.version.lstrip("v")}.zip')
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        for m in members:
            z.write(m, m)

    scripts = sum(1 for m in members if m.startswith('Scripts/'))
    images = sum(1 for m in members if m.endswith('.png'))
    size = os.path.getsize(out)
    print(f'{out}  ({size / 1024 / 1024:.1f} MB)')
    print(f'  {len(members)} entries: {scripts} scripts, {images} images, '
          f'{len(members) - scripts - images} other')


if __name__ == '__main__':
    main()
