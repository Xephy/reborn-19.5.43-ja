# -*- coding: utf-8 -*-
"""Report translations that would hide a password the player has to type.

Two ways a password stops being typeable:

The passwords menu builds each line as "#{mark}#{password}" and hands the
whole list to Kernel.pbMessage, which runs every command through pbLocalize -
that is `_INTL`, so each line is looked up in the script-text section. A
password is a lowercase English word, so a translation registered under that
same key replaces it on screen and the player can no longer read what to type.

The lookup key is what Messages.stringToKey makes of the displayed line, so the
inactive mark (four spaces) is stripped and only the bare password is left,
while the active mark ("> ") stays part of the key. Both shapes are checked.

This actually happened: the mono-type challenge password `normal` was showing
as 通常, translated for a Shininess label in Debug.rb that the patch does not
even ship.

The second way is the NPCs who hand a password out in conversation ("tell them
\"nuzlocke\""). The quoted word is what the player has to type into the entry
box, so it has to survive translation letter for letter. Fifteen of them had
been turned into Japanese, which reads fine and cannot be entered.

    python3 jp_translation/tools/check_passwords.py
"""
import glob
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import msgtypes  # noqa: E402

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'work', 'src')
REBORN_SCRIPTS = 'Scripts/Reborn/RebornScripts.rb'

# How pbPasswordsToList marks a line, from the player's point of view.
MARKS = [('    ', 'inactive'), ('> ', 'active')]

# Words that match a password but are not one being handed to the player.
# map 428 is the field-note index, whose headings collide with the terrain
# passwords; Blindstep is the name of the accessibility mode, not an
# instruction to type it (the same map spells it out in katakana elsewhere).
NOT_A_HINT = {
    ('map:428', 'water'), ('map:428', 'underwater'),
    ('map:428', 'cave'), ('map:428', 'mountain'),
    ('map:689', 'blindstep'),
}

# A password quoted in dialogue, in any of the quote marks the corpus uses.
QUOTED = re.compile(r'["\u201c\u201d\'\u2018\u2019\u300c\u300e`]([A-Za-z0-9_.\- ]{2,30})["\u201c\u201d\'\u2018\u2019\u300d\u300f`]')
TALKS_ABOUT = re.compile(r'password|passcode', re.I)

# The tables the passwords menu accepts an entry from. JA_PASSWORD_HASH holds
# the ones this patch added, and they are typed the same way.
TABLES = ('PASSWORD_HASH', 'BULK_PASSWORDS', 'JA_PASSWORD_HASH')


def hash_body(src, name):
    """The braces of `NAME = { ... }`, matched by depth so nesting is safe."""
    start = src.index(name + ' = {')
    open_at = src.index('{', start)
    depth, i = 0, open_at
    while True:
        if src[i] == '{':
            depth += 1
        elif src[i] == '}':
            depth -= 1
            if depth == 0:
                return src[open_at:i + 1]
        i += 1


def passwords():
    src = open(REBORN_SCRIPTS, encoding='utf-8', errors='replace').read()
    found = set()
    for name in TABLES:
        body = hash_body(src, name)
        found |= set(re.findall(r'["\']([a-zA-Z0-9_.\-]+)["\']\s*=>', body))
        if name == 'BULK_PASSWORDS':
            # the values are lists of passwords, not switch ids
            found |= set(re.findall(r'["\']([a-zA-Z0-9_.\-]+)["\']', body))
    return found


def script_texts():
    keys = {}
    for path in sorted(glob.glob(os.path.join(SRC, '*.jsonl'))):
        for line in open(path, encoding='utf-8'):
            if not line.strip():
                continue
            r = json.loads(line)
            if r['sec'] != 22 or not isinstance(r['key'], str) or not r['ja']:
                continue
            keys[msgtypes.string_to_key(r['key'])] = (r['ja'], os.path.basename(path))
    return keys


def dialogue_hints(pws):
    """NPC lines that quote a password whose letters did not survive the translation."""
    bad = []
    for path in sorted(glob.glob(os.path.join(SRC, 'map_*.jsonl'))):
        for line in open(path, encoding='utf-8'):
            if not line.strip():
                continue
            r = json.loads(line)
            if not r['ja']:
                continue
            found = {t for m in QUOTED.finditer(r['en'])
                     for t in [m.group(1).strip()] if t.lower() in pws}
            if TALKS_ABOUT.search(r['en']):
                found |= {t for t in re.findall(r'\b[A-Za-z0-9]{4,20}\b', r['en'])
                          if t.lower() in pws}
            for t in sorted(found):
                if (r['sec'], t.lower()) in NOT_A_HINT:
                    continue
                if t.lower() not in r['ja'].lower():
                    bad.append((r['sec'], t, r['en'], r['ja']))
    return bad


def main():
    keys = script_texts()
    pws = passwords()
    hits = []
    for pw in sorted(pws):
        for mark, state in MARKS:
            key = msgtypes.string_to_key(mark + pw)
            if key in keys:
                hits.append((pw, state, key, keys[key]))

    dialogue = dialogue_hints({p.lower() for p in pws})

    print(f'passwords: {len(pws)}   script-text keys: {len(keys)}')
    if hits:
        print(f'translations hiding a password: {len(hits)}')
        for pw, state, key, (ja, path) in hits:
            print(f'  {pw:20} ({state})  key {key!r} -> {ja!r}   [{path}]')
        print('  -> clear the ja for those keys; the password has to stay readable.')
    else:
        print('translations hiding a password: none')

    if dialogue:
        print(f'NPC hints whose password did not survive translation: {len(dialogue)}')
        for sec, pw, en, ja in dialogue:
            print(f'  [{sec}] {pw}')
            print(f'      en: {en}')
            print(f'      ja: {ja}')
        print('  -> put the English password back; it is what the player types.')
    else:
        print('NPC hints whose password did not survive translation: none')

    return 1 if (hits or dialogue) else 0


if __name__ == '__main__':
    sys.exit(main())
