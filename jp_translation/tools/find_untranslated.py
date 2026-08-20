# -*- coding: utf-8 -*-
"""Report text the game can display but the message tables cannot translate.

messages.dat only ever contains what the compiler scraped out of the scripts:
the literal inside `_INTL("...")` / `_ISPRINTF("...")`. Two things escape that
net and stay English forever:

  * a bare literal handed straight to a message function, e.g.
    `Kernel.pbMessage("Saved the game!")` - no key is ever registered for it
  * an `_INTL` whose key is built at run time by string concatenation or `#{}`
    interpolation - the key that gets looked up never matches the one that was
    scraped
  * an `_INTL` literal containing an escaped backslash - the compiler unescapes
    with blind gsubs, so it registers a different key from the one Ruby builds,
    and the line is stuck in English however it is translated
  * an `_INTL` written with single quotes - the compiler only scrapes double
    quoted literals, so no key is registered for it either
  * an `_INTL` / `_I` written inside a map event's Script command - the
    compiler scrapes the script files and the maps' message commands, but
    never the Ruby that map events carry, so again no key is registered

Both are reported here, along with `_INTL` literals that simply have no
translation yet. Run it after touching the scripts, or against a new Reborn
release, to see what a rebuild would leave in English.

    python3 jp_translation/tools/find_untranslated.py
    python3 jp_translation/tools/find_untranslated.py --all   # include dev tools
"""
import argparse
import collections
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import msgtypes  # noqa: E402
import rmarshal  # noqa: E402

SRC = 'jp_translation/work/src'
BOOTSTRAP = 'Scripts/Reborn/Bootstrap.rb'

# Editors, compilers and the profiler are developer tools; their text is never
# on screen during play.
DEV_TOOLS = {
    'Editor', 'AnimEditor', 'Compiler', 'Debug', 'Validator', 'System',
    'DataObjects - Yeeters', 'DataObjects - Compilers', 'Battle_TestEnvironment',
    'Online/Network', 'Online/DiscordRichPresence',
}

STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')
# Same shape as pbAddRgssScriptTexts, so the same literals are picked up.
INTL_LITERAL = re.compile(r'(?:_INTL|_ISPRINTF)\s*\(\s*"((?:[^\\"]*\\"?)*[^"]*)"')
# `(_INTL "x", y)` is a legal call the compiler's own scraper misses, so the key
# is never registered even though the line is translated at run time.
INTL_NO_PAREN = re.compile(r'(?:_INTL|_ISPRINTF)\s+"((?:[^\\"]*\\"?)*[^"]*)"')
# Single quotes are a legal Ruby literal but pbAddRgssScriptTexts only scans for
# double quoted ones, so these never reach the table either. Ruby does not
# process escapes inside them beyond \' and \\.
SQ_MESSAGE = re.compile(
    r"\b(?:Kernel\.)?(?:pbMessage|pbConfirmMessage|pbConfirmMessageSerious|"
    r"pbChoice|pbMessageChooseNumber|pbMessageFreeText|pbDisplay\w*)\s*\(\s*"
    r"'((?:[^'\\]|\\.)*)'")
SQ_INTL = re.compile(r"(?:_INTL|_ISPRINTF)\s*\(?\s*'((?:[^'\\]|\\.)*)'")
# Prompt helpers take their text somewhere other than the first argument
# (UIHelper.pbChooseNumber(window, "text", max)), so the first-argument rules
# above miss them. On a line that calls one, look at every literal.
HELPER_CALL = re.compile(
    r'\b(?:UIHelper\.)?(?:pbChooseNumber|pbInputNumber|pbShowCommands|'
    r'pbChooseList|pbChooseItemFromList)\s*\(')
ANY_LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"' + r"|'((?:[^'\\]|\\.)*)'")
# Text drawn straight onto a bitmap never goes near a message function, so the
# checks above cannot see it. The drawing helpers take ["text", x, y, ...]
# tuples, so look for an array literal that starts with a displayable string in
# any file that draws.
DRAW_TUPLE = re.compile(r'\[\s*"((?:[^"\\]|\\.)*)"\s*,\s*[\w@$(]')
# The same tuple shape carries image paths for pbDrawImagePositions; those are
# asset keys, not text.
ASSET_PATH = re.compile(r'/|\.(?:png|jpg|gif|bmp)$')
DRAWS_TEXT = re.compile(r'pbDrawTextPositions|pbDrawImagePositions|drawTextEx')
INTL_CALL = re.compile(r'(?:_INTL|_ISPRINTF)\s*\(\s*$')
MESSAGE_CALL = re.compile(
    r'\b(?:Kernel\.)?(?:pbMessage|pbConfirmMessage|pbConfirmMessageSerious|'
    r'pbChoice|pbMessageChooseNumber|pbMessageFreeText)\s*\(')
# An _INTL whose key is assembled at run time can never match what was scraped.
BUILT_KEY = re.compile(r'(?:_INTL|_ISPRINTF)\s*\(\s*(?:"[^"]*"\s*\+|[A-Za-z_@$])')
HAS_LETTERS = re.compile(r'[A-Za-z]{2}')

# A map event can carry Ruby of its own (command code 355, continued by 655).
# Nothing scrapes that, so a localization call written there registers no key.
# `_I` reads the map's own hash and `_INTL` reads section 22, so the two routes
# are captured separately - group 1 is the map route, group 2 section 22.
EVENT_LITERAL = r'(?:"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\')'
EVENT_INTL = re.compile(
    r'(?:\b_I\(|\b_MAPINTL\(\s*[^,]+,)\s*(' + EVENT_LITERAL + r')'
    r'|\b_(?:INTL|ISPRINTF)\s*\(\s*(' + EVENT_LITERAL + r')', re.S)

# Printed on the train ticket in the opening, alongside the codes "8R750" and
# "5D". They are stub abbreviations - most likely one-way and single - and read
# as printing on a ticket rather than as a sentence, so they stay as they are.
# Trainer Pokemon nicknames whose glyphs are the joke: leetspeak, an emoticon,
# or a plain number. Katakana would destroy what they are, so they stay.
NICKNAMES_AS_IS = {':)', 'CL:4R1-C3', 'HOW2BASIC', 'Hottie ;)', 'MEGAZ0RD',
                   'No.1', 'No.2', 'No.3', 'No.4', 'No.5', 'No.6'}

INTENTIONAL_ENGLISH = {'ONE', 'SGL'}

# Names held by the data objects ($cache.items[x].name and friends) are the
# English ones; only the get*Name accessors put them through their message
# section. A raw reference that reaches the screen stays English, and
# Kernel.pbMessage cannot rescue it - that retries the script-text section,
# not the item/species/move sections. Flag every raw reference, minus the
# places that legitimately want English.
DATA_NAME = re.compile(r'\$cache\.(?:items|moves|pkmn|abil|ttypes|types)\[[^\]]*\]\.(?:name|fullName)')
DATA_NAME_OK = {
    # The accessors themselves - this is where the lookup happens.
    'Items:19', 'Items:42', 'Items:73', 'Items:104', 'Items:110',
    # Sort comparators: they parse the number out of "TM94"/"HM03".
    'Bag:607', 'Bag:610', 'Bag:613', 'Bag:616',
    # Randomizer writes developer export files, not screen text.
    'Randomizer/Randomizer:533', 'Randomizer/Randomizer:550',
    'Randomizer/Randomizer:660',
    # Screen reader output, which is English throughout.
    'PokedexScene:808', 'PokedexScene:810',
}


def hand_added_map_keys():
    """Map-section keys this project invented, and whether section 22 backs them.

    Reborn's own compiler registers a key for every message command in a map,
    and those always resolve. A key added by hand does not go through that
    compiler, and at least once it did not resolve at run time even though the
    built file contained it - the Grand Hall sparring speeches, which are
    assigned to a game variable by a script line rather than shown by a message
    command.

    The reliable second path is the script-text section: pbTrainerSpeech falls
    back to _INTL when the end-speech section misses. So a hand-added map key
    has to be mirrored there, and this reports any that are not.
    """
    orig = rmarshal.load('Data/messages.dat')[0]
    sec22 = {}
    unbacked = []
    for path in sorted(os.listdir(SRC)):
        if not path.endswith('.jsonl'):
            continue
        for line in open(os.path.join(SRC, path), encoding='utf-8'):
            if not line.strip():
                continue
            r = json.loads(line)
            if r['sec'] == 22 and isinstance(r['key'], str):
                sec22[msgtypes.string_to_key(r['key'])] = True
    for path in sorted(os.listdir(SRC)):
        if not path.startswith('map_') or not path.endswith('.jsonl'):
            continue
        mid = int(path[4:-6])
        known = orig[mid] if isinstance(orig, list) and mid < len(orig) and orig[mid] else {}
        known = set(known.keys()) if hasattr(known, 'keys') else set()
        for line in open(os.path.join(SRC, path), encoding='utf-8'):
            if not line.strip():
                continue
            r = json.loads(line)
            if not isinstance(r.get('key'), str):
                continue
            key = msgtypes.string_to_key(r['key'])
            if key not in known and key not in sec22:
                unbacked.append((f'map:{mid}', r['key']))
    return unbacked


def event_script_keys():
    """`_INTL` / `_I` literals written inside a map event's Script command.

    Reborn's compiler scrapes the script files and the *message* commands of
    every map. A map event can also carry Ruby (command code 355, continued by
    655), and nothing scrapes that, so a localization call written there has no
    key in messages.dat however correct the call is.

    Which table answers depends on the call: `_INTL` reads section 22, while
    `_I` is `_MAPINTL($game_map.map_id, ...)` and reads only that map's hash -
    section 22 is not a fallback for it. So each literal is checked against the
    table its own call site will look in.
    """
    sec22 = {}
    permap = {}
    for path in sorted(os.listdir(SRC)):
        if not path.endswith('.jsonl'):
            continue
        for line in open(os.path.join(SRC, path), encoding='utf-8'):
            if not line.strip():
                continue
            r = json.loads(line)
            if not isinstance(r.get('key'), str):
                continue
            key = msgtypes.string_to_key(r['key'])
            sec = r['sec']
            if sec == 22:
                sec22[key] = r['ja']
            elif isinstance(sec, str) and sec.startswith('map:'):
                permap.setdefault(int(sec[4:]), {})[key] = r['ja']

    missing, untranslated = [], []
    for name in sorted(os.listdir('Data')):
        m = re.fullmatch(r'Map(\d+)\.rxdata', name)
        if not m:
            continue
        mid = int(m.group(1))
        for where, script in event_scripts(os.path.join('Data', name), mid):
            for call in EVENT_INTL.finditer(script):
                raw = call.group(1) or call.group(2)
                if raw is None or '#{' in raw:
                    continue
                body = raw[1:-1]
                if raw[0] == '"':
                    body = unescape(body)
                else:
                    body = body.replace("\\'", "'").replace('\\\\', '\\')
                key = msgtypes.string_to_key(body)
                if not key or not HAS_LETTERS.search(key):
                    continue
                table = permap.get(mid, {}) if call.group(1) is not None else sec22
                if key not in table:
                    missing.append((where, key))
                elif not table[key]:
                    untranslated.append((where, key))
    return missing, untranslated


def event_scripts(path, mid):
    """Yield (where, ruby) for every Script command block in a map's events."""
    out = []
    events = robj_attr(rmarshal.load(path), '@events') or {}
    for eid, ev in events.items():
        label = f'map{mid}/ev{eid} {robj_attr(ev, "@name")}'
        for page in robj_attr(ev, '@pages') or []:
            block = []
            for cmd in robj_attr(page, '@list') or []:
                if robj_attr(cmd, '@code') in (355, 655):
                    block.append(robj_attr(cmd, '@parameters')[0])
                elif block:
                    out.append((label, '\n'.join(block)))
                    block = []
            if block:
                out.append((label, '\n'.join(block)))
    return out


def robj_attr(obj, name):
    """Read one instance variable off an rmarshal RObj (keys are symbols)."""
    for key, value in obj.data.items():
        if str(key) == name:
            return value
    return None


def unescape(s):
    """Ruby's double-quote escapes, in the order pbAddRgssScriptTexts undoes them."""
    return (s.replace('\\r', '\r').replace('\\n', '\n').replace('\\1', '\1')
             .replace('\\"', '"').replace('\\\\', '\\'))


def ruby_value(raw):
    """What the literal actually evaluates to at run time.

    The compiler's unescaping above is a series of blind gsubs, so a literal
    containing an escaped backslash comes out differently from the string Ruby
    builds - "...\\n..." is backslash-n to Ruby but is turned into a newline by
    the compiler. The key that gets registered then never matches the key that
    is looked up, and the line is stuck in English however it is translated.
    """
    out = []
    i = 0
    while i < len(raw):
        c = raw[i]
        if c == '\\' and i + 1 < len(raw):
            n = raw[i + 1]
            if n in 'nrte':
                out.append({'n': '\n', 'r': '\r', 't': '\t', 'e': '\x1b'}[n])
            elif n.isdigit():
                j, digits = i + 1, ''
                while j < len(raw) and len(digits) < 3 and raw[j] in '01234567':
                    digits += raw[j]
                    j += 1
                out.append(chr(int(digits, 8)))
                i = j
                continue
            else:
                out.append(n)
            i += 2
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def script_list():
    src = open(BOOTSTRAP, encoding='utf-8').read()
    block = src.split('SCRIPTS = [', 1)[1].split('\n]', 1)[0]
    return [s for s in re.findall(r"'([^']+)'", block)
            if os.path.exists(f'Scripts/{s}.rb')]


def known_keys():
    keys = {}
    for path in sorted(os.listdir(SRC)):
        if not path.endswith('.jsonl'):
            continue
        for line in open(os.path.join(SRC, path), encoding='utf-8'):
            if not line.strip():
                continue
            r = json.loads(line)
            if r['sec'] != 22:
                continue
            keys[msgtypes.string_to_key(r['key'])] = r['ja']
    return keys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--all', action='store_true', help='include developer tools')
    a = ap.parse_args()

    keys = known_keys()
    no_key = {}          # displayable literal with no entry at all
    unreachable = []     # registered under a key the game never looks up
    untranslated = {}    # entry exists but ja is empty
    runtime_key = []     # _INTL whose key is assembled at run time
    raw_name = []        # data-object name that never reaches its message section

    for script in script_list():
        if not a.all and script in DEV_TOOLS:
            continue
        path = f'Scripts/{script}.rb'
        src = open(path, encoding='utf-8', errors='replace').read()
        draws = bool(DRAWS_TEXT.search(src))
        for n, line in enumerate(src.split('\n'), 1):
            if line.lstrip().startswith('#'):
                continue
            if HELPER_CALL.search(line):
                for m in ANY_LITERAL.finditer(line):
                    if INTL_CALL.search(line[:m.start() + 1]):
                        continue
                    # A literal used as a subscript is a hash key, not text.
                    if line[:m.start()].rstrip().endswith('['):
                        continue
                    lit = m.group(1) if m.group(1) is not None else m.group(2)
                    key = msgtypes.string_to_key(unescape(lit))
                    if not key or not HAS_LETTERS.search(key) or '#{' in key:
                        continue
                    if ASSET_PATH.search(key) or key in INTENTIONAL_ENGLISH:
                        continue
                    if key not in keys:
                        no_key.setdefault(key, f'{script}:{n}')
                    elif not keys[key]:
                        untranslated.setdefault(key, f'{script}:{n}')
            for m in DATA_NAME.finditer(line):
                if f'{script}:{n}' not in DATA_NAME_OK:
                    raw_name.append((f'{script}:{n}', line.strip()[:90]))
            if draws:
                for m in DRAW_TUPLE.finditer(line):
                    if INTL_CALL.search(line[:m.start() + 1]):
                        continue
                    key = msgtypes.string_to_key(unescape(m.group(1)))
                    if not key or not HAS_LETTERS.search(key) or '#{' in key:
                        continue
                    if ASSET_PATH.search(key) or key in INTENTIONAL_ENGLISH:
                        continue
                    if key not in keys:
                        no_key.setdefault(key, f'{script}:{n}')
                    elif not keys[key]:
                        untranslated.setdefault(key, f'{script}:{n}')
            for m in SQ_INTL.finditer(line):
                key = msgtypes.string_to_key(m.group(1).replace("\\'", "'"))
                if key and HAS_LETTERS.search(key):
                    if key not in keys:
                        no_key.setdefault(key, f'{script}:{n}')
                    elif not keys[key]:
                        untranslated.setdefault(key, f'{script}:{n}')
            for m in list(INTL_LITERAL.finditer(line)) + list(INTL_NO_PAREN.finditer(line)):
                raw = m.group(1)
                if '\\\\' in raw:
                    compiled = msgtypes.string_to_key(unescape(raw))
                    runtime = msgtypes.string_to_key(ruby_value(raw))
                    if compiled != runtime and runtime not in keys:
                        unreachable.append((f'{script}:{n}', runtime))
                key = msgtypes.string_to_key(unescape(raw))
                if not key or not HAS_LETTERS.search(key):
                    continue
                if key not in keys:
                    no_key.setdefault(key, f'{script}:{n}')
                elif not keys[key]:
                    untranslated.setdefault(key, f'{script}:{n}')
            if BUILT_KEY.search(line):
                runtime_key.append((f'{script}:{n}', line.strip()))
            if not MESSAGE_CALL.search(line):
                continue
            for m in SQ_MESSAGE.finditer(line):
                key = msgtypes.string_to_key(m.group(1).replace("\\'", "'"))
                if key and HAS_LETTERS.search(key) and '#{' not in key:
                    if key not in keys:
                        no_key.setdefault(key, f'{script}:{n}')
                    elif not keys[key]:
                        untranslated.setdefault(key, f'{script}:{n}')
            for m in STRING.finditer(line):
                if INTL_CALL.search(line[:m.start()]):
                    continue
                raw = m.group(1)
                if '#{' in raw:
                    runtime_key.append((f'{script}:{n}', raw))
                    continue
                key = msgtypes.string_to_key(unescape(raw))
                if not key or not HAS_LETTERS.search(key):
                    continue
                if key not in keys:
                    no_key.setdefault(key, f'{script}:{n}')
                elif not keys[key]:
                    untranslated.setdefault(key, f'{script}:{n}')

    print(f'{len(no_key)} string(s) with no entry in section 22')
    for key in sorted(no_key):
        print(f'  {no_key[key]:44} {key!r}')
    print()
    print(f'{len(untranslated)} entry/entries still untranslated')
    for key in sorted(untranslated):
        print(f'  {untranslated[key]:44} {key!r}')
    print()
    print(f'{len(unreachable)} literal(s) registered under a key the game never looks up')
    for where, key in unreachable:
        print(f'  {where:44} {key!r}')
    print()
    unbacked = hand_added_map_keys()
    print(f'{len(unbacked)} hand-added map key(s) with no section-22 backup')
    for where, key in unbacked:
        print(f'  {where:44} {key[:70]!r}')
    print()
    ev_missing, ev_untranslated = event_script_keys()
    print(f'{len(ev_missing)} literal(s) in a map event script with no key')
    for where, key in ev_missing:
        print(f'  {where:44} {key[:70]!r}')
    print()
    print(f'{len(ev_untranslated)} literal(s) in a map event script still untranslated')
    for where, key in ev_untranslated:
        print(f'  {where:44} {key[:70]!r}')
    print()
    print(f'{len(raw_name)} data-object name(s) used without their message section')
    for where, text in raw_name:
        print(f'  {where:44} {text}')
    print()
    print(f'{len(runtime_key)} key(s) assembled at run time (cannot be looked up)')
    for where, text in runtime_key:
        print(f'  {where:44} {text[:96]}')
    return 1 if (no_key or untranslated or unreachable or raw_name
                 or unbacked or ev_missing or ev_untranslated) else 0


if __name__ == '__main__':
    sys.exit(main())
