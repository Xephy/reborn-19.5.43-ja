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

# Printed on the train ticket in the opening, alongside the codes "8R750" and
# "5D". They are stub abbreviations - most likely one-way and single - and read
# as printing on a ticket rather than as a sentence, so they stay as they are.
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
    print(f'{len(raw_name)} data-object name(s) used without their message section')
    for where, text in raw_name:
        print(f'  {where:44} {text}')
    print()
    print(f'{len(runtime_key)} key(s) assembled at run time (cannot be looked up)')
    for where, text in runtime_key:
        print(f'  {where:44} {text[:96]}')
    return 1 if (no_key or untranslated or unreachable or raw_name) else 0


if __name__ == '__main__':
    sys.exit(main())
