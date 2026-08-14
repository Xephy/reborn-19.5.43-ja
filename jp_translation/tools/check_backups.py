# -*- coding: utf-8 -*-
"""Check the untouched copies kept for the "revert" instructions in the README.

Every engine script this patch replaces has a copy of Reborn's original under
jp_translation/backup/<version>-scripts/, and the README tells players to put
those back to undo the patch. A copy that is missing, or that is left over from
an older Reborn, makes that instruction wrong in a way nothing else notices:
restoring a stale copy silently rolls the game back to the older code.

    python3 jp_translation/tools/check_backups.py            # present?
    python3 jp_translation/tools/check_backups.py --download  # ... and genuine?
    python3 jp_translation/tools/check_backups.py --patch /path/to/patch.zip

Without --download or --patch only the presence check runs, because proving a
copy is genuine means comparing it against Reborn's own distribution.

Reborn's updater serves the current scripts as one zip, and the same URLs the
game itself uses are read out of Bootstrap.rb rather than repeated here.
"""
import argparse
import io
import os
import re
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_release import listed_paths  # noqa: E402

BOOTSTRAP = 'Scripts/Reborn/Bootstrap.rb'
BACKUP_ROOT = 'jp_translation/backup'


def backup_dir():
    """The <version>-scripts directory, and the version it claims to hold."""
    dirs = [d for d in os.listdir(BACKUP_ROOT) if d.endswith('-scripts')]
    if not dirs:
        sys.exit(f'no <version>-scripts directory under {BACKUP_ROOT}')
    # 19.5.43 sorts after 19.5.0 only if the parts are compared as numbers.
    def key(name):
        return [int(p) for p in re.findall(r'\d+', name)]
    newest = max(dirs, key=key)
    return os.path.join(BACKUP_ROOT, newest), newest.replace('-scripts', '')


def game_urls():
    """(version_url, patch_url) as the game's own updater uses them."""
    src = open(BOOTSTRAP, encoding='utf-8').read()
    def const(name):
        m = re.search(rf"^{name}\s*=\s*'([^']+)'", src, re.M)
        if not m:
            sys.exit(f'{name} not found in {BOOTSTRAP}')
        return m.group(1)
    return const('VERSION_URL'), const('PATCH_URL')


def replaced_scripts():
    """The engine scripts the patch ships, straight out of sync.sh."""
    files, _ = listed_paths()
    return [f for f in files if f.startswith('Scripts/')]


def check_present(directory):
    """Returns the scripts that have no untouched copy."""
    return [s for s in replaced_scripts()
            if not os.path.exists(os.path.join(directory, s[len('Scripts/'):]))]


def official_scripts(patch, version_url, expect):
    """{path: bytes} for the scripts in Reborn's own patch zip."""
    if patch == '--download':
        import urllib.request
        with urllib.request.urlopen(version_url, timeout=30) as r:
            served = r.read().decode('utf-8', 'replace').strip()
        if served != expect:
            sys.exit(f'the update server now serves {served}, not {expect} - '
                     f'a copy of the {expect} patch.zip is needed instead '
                     f'(--patch)')
        _, patch_url = game_urls()
        with urllib.request.urlopen(patch_url, timeout=300) as r:
            data = r.read()
        z = zipfile.ZipFile(io.BytesIO(data))
    else:
        z = zipfile.ZipFile(patch)
    return {n: z.read(n) for n in z.namelist() if n.startswith('Scripts/')}


def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group()
    g.add_argument('--download', action='store_true',
                   help="fetch Reborn's patch.zip and compare against it")
    g.add_argument('--patch', help='compare against a local patch.zip instead')
    a = ap.parse_args()

    directory, version = backup_dir()
    scripts = replaced_scripts()

    missing = check_present(directory)
    if missing:
        print(f'{len(missing)} script(s) have no untouched copy in {directory}:')
        for s in missing:
            print(f'  {s}')
        return 1
    print(f'{len(scripts)} script(s): every one has a copy in {directory}')

    if not (a.download or a.patch):
        return 0

    version_url, _ = game_urls()
    official = official_scripts(a.patch or '--download', version_url, version)

    stale, unknown = [], []
    for s in scripts:
        if s not in official:
            unknown.append(s)
            continue
        kept = open(os.path.join(directory, s[len('Scripts/'):]), 'rb').read()
        if kept != official[s]:
            stale.append(s)

    if unknown:
        print(f'{len(unknown)} script(s) are not in the patch zip - '
              f'they ship with the base game and cannot be checked here:')
        for s in unknown:
            print(f'  {s}')
    if stale:
        print(f'{len(stale)} copy/copies do not match Reborn {version} - '
              f'restoring them would roll the game back:')
        for s in stale:
            print(f'  {s}')
        return 1
    print(f'{len(scripts) - len(unknown)} copy/copies match Reborn {version}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
