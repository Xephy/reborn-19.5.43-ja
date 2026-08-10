"""Shared constants/helpers for the Reborn JP translation pipeline.

MESSAGE_TYPES mirrors ``module MessageTypes`` in Scripts/PBIntl.rb:607-628.
Index 0 of the top-level array is reserved for map / common-event text.
"""

import os
import re

# id -> Ruby constant name (Scripts/PBIntl.rb)
MESSAGE_TYPES = {
    1: "Species",
    2: "Kinds",
    3: "Entries",
    4: "FormNames",
    5: "Moves",
    6: "MoveDescriptions",
    7: "Items",
    8: "ItemDescriptions",
    9: "Abilities",
    10: "AbilityDescs",
    11: "Types",
    12: "TrainerTypes",
    13: "TrainerNames",
    14: "BeginSpeech",
    15: "EndSpeechWin",
    16: "EndSpeechLose",
    17: "RegionNames",
    18: "PlaceNames",
    19: "PlaceDescriptions",
    20: "MapNames",
    21: "PhoneMessages",
    22: "ScriptTexts",
}

GAME_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
SRC_DIR = os.path.join(GAME_ROOT, "jp_translation", "work", "src")
BASE_DAT = os.path.join(GAME_ROOT, "Data", "messages.dat")
OUT_DAT = os.path.join(GAME_ROOT, "patch", "Data", "japanese.dat")


def _snake(name):
    s = re.sub(r'(.)([A-Z][a-z]+)', r'\1_\2', name)
    return re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', s).lower()


def section_filename(sec):
    """'map:31' -> 'map_0031'; 5 -> '05_moves'."""
    if isinstance(sec, str) and sec.startswith("map:"):
        return "map_%04d" % int(sec[4:])
    return "%02d_%s" % (int(sec), _snake(MESSAGE_TYPES[int(sec)]))


# --- Messages.stringToKey (Scripts/PBIntl.rb:377-386) -----------------------
# Ruby \s is [ \t\r\n\f\v]; Ruby's ^/$ are always line anchors -> re.MULTILINE.
_WS = r'[ \t\r\n\f\v]'
_NEEDS_KEY = re.compile(r'[\r\n\t\x01]|^' + _WS + r'+|' + _WS + r'+$|' + _WS + r'{2,}',
                        re.MULTILINE)
_LEAD = re.compile(r'^' + _WS + r'+', re.MULTILINE)
_TRAIL = re.compile(_WS + r'+$', re.MULTILINE)
_RUNS = re.compile(_WS + r'{2,}')


def string_to_key(s):
    """Python port of Messages.stringToKey - the hash key used at lookup time."""
    if _NEEDS_KEY.search(s):
        k = _LEAD.sub('', s)
        k = _TRAIL.sub('', k)
        k = _RUNS.sub(' ', k)
        return k
    return s
