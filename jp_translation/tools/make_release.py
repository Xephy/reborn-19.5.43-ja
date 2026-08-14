# -*- coding: utf-8 -*-
"""Pack the installable patch into dist/reborn-19.5.43-ja-<version>.zip.

The file list is read straight out of sync.sh, so the archive and the copy that
gets pushed to the play environments can never drift apart: whenever a script
starts being part of the patch it only has to be added in one place.

Everything lands at its game-relative path, so the archive is extracted over
the game folder as-is. The working files under jp_translation/ are not
included - the archive is what a player installs, not the sources.

The finished archive is scanned for anything that would identify whoever built
it - see scan_for_personal_data - and is deleted rather than shipped if it
finds something.

    python3 jp_translation/tools/make_release.py v19.5.43-ja.1
    -> dist/reborn-19.5.43-ja.1.zip
"""
import argparse
import getpass
import os
import re
import sys
import zipfile

SYNC = 'jp_translation/tools/sync.sh'
OUT_DIR = 'dist'
EXTRA = ['README.md']
BUILT_DAT = 'patch/Data/japanese.dat'
SRC_DIR = 'jp_translation/work/src'

# Shapes of an absolute path that carries a person's account name. These are
# matched rather than the names themselves: this file is published, so spelling
# out the very strings that must not escape would defeat the point. The account
# name is whatever follows, so a hit is reported with its surrounding bytes.
PATH_SHAPES = [
    rb'/home/[A-Za-z0-9._-]+',
    rb'/Users/[A-Za-z0-9._-]+',
    rb'[A-Za-z]:\\+Users\\+[A-Za-z0-9._-]+',
    rb'/mnt/[a-z]/Users/[A-Za-z0-9._-]+',
    rb'\\\\+wsl(\.localhost|\$)',
]


def listed_paths():
    """(files, dirs) exactly as sync.sh pushes them."""
    src = open(SYNC, encoding='utf-8').read()

    def block(name):
        body = src.split(f'{name}=(', 1)[1].split('\n)', 1)[0]
        # Comment lines in the array quote things too ("sharply"/"harshly"), so
        # they are dropped before the paths are picked out.
        lines = [l for l in body.split('\n') if not l.strip().startswith('#')]
        return re.findall(r'"([^"]+)"', '\n'.join(lines))

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


def check_backups_present():
    """The README's revert instructions have to work for everything shipped.

    Only presence is checked here; whether a kept copy is still the one Reborn
    ships needs Reborn's own patch.zip, which check_backups.py will fetch.
    """
    from check_backups import backup_dir, check_present
    directory, _ = backup_dir()
    missing = check_present(directory)
    if missing:
        sys.exit('no untouched copy kept in %s, so the patch cannot be undone:'
                 '\n  %s' % (directory, '\n  '.join(missing)))


def scrub_terms():
    """Literal strings that must not appear, worked out at run time.

    The person building the release is the person the archive must not name, so
    their account name is taken from the machine instead of being written down.
    REBORN_JA_SCRUB adds comma-separated extras - a Windows user name that
    differs from the WSL one, a real name, a host name - without any of them
    having to be committed here.
    """
    terms = set()
    for term in (getpass.getuser(), os.path.basename(os.path.expanduser('~'))):
        if term and len(term) > 2:
            terms.add(term)
    for term in os.environ.get('REBORN_JA_SCRUB', '').split(','):
        if term.strip():
            terms.add(term.strip())
    return sorted(terms)


def scan_for_personal_data(path):
    """Every byte that ships, checked for who built it. Returns the hits.

    Member names and member contents both, over the finished archive rather
    than the working tree, because the archive is what reaches other people.
    Everything is searched as raw bytes: japanese.dat and the PNGs are binary,
    and a leak in one of them counts just as much as a leak in a comment.
    """
    patterns = list(PATH_SHAPES)
    patterns += [re.escape(t.encode()) for t in scrub_terms()]
    rx = re.compile(b'|'.join(patterns), re.IGNORECASE)

    hits = []
    with zipfile.ZipFile(path) as z:
        for name in z.namelist():
            for m in rx.finditer(name.encode()):
                hits.append((name, 'name', m.group(0).decode('utf-8', 'replace')))
            data = z.read(name)
            for m in rx.finditer(data):
                around = data[max(0, m.start() - 30):m.end() + 30]
                hits.append((name, 'body', around.decode('utf-8', 'replace')))
    return hits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('version', help='release tag, e.g. v19.5.43-ja.1')
    a = ap.parse_args()

    check_dat_is_current()
    check_backups_present()
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

    hits = scan_for_personal_data(out)
    if hits:
        os.remove(out)
        print(f'{out} was deleted - it identified whoever built it:',
              file=sys.stderr)
        for name, where, text in hits[:20]:
            print(f'  {name} ({where}): {text!r}', file=sys.stderr)
        if len(hits) > 20:
            print(f'  ... and {len(hits) - 20} more', file=sys.stderr)
        sys.exit(1)

    scripts = sum(1 for m in members if m.startswith('Scripts/'))
    images = sum(1 for m in members if m.endswith('.png'))
    size = os.path.getsize(out)
    print(f'{out}  ({size / 1024 / 1024:.1f} MB)')
    print(f'  {len(members)} entries: {scripts} scripts, {images} images, '
          f'{len(members) - scripts - images} other')
    print(f'  no personal data ({len(scrub_terms())} terms + '
          f'{len(PATH_SHAPES)} path shapes)')


if __name__ == '__main__':
    main()
