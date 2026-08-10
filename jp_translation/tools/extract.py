#!/usr/bin/env python3
"""Extract translatable strings from Data/messages.dat into per-section JSONL.

    python3 jp_translation/tools/extract.py [--base DAT] [--out DIR] [--force]

Output: jp_translation/work/src/<section>.jsonl, one JSON object per line:

    {"sec": 5,         "key": 14,        "en": "Swords Dance", "ja": ""}
    {"sec": "map:31",  "key": "Hello!",  "en": "Hello!",       "ja": ""}

* ``sec`` is the MessageTypes id (1..22) or ``"map:<mapid>"`` for map /
  common-event text (map id 0 = common events).
* ``key`` is the array index for list-typed sections, or the OrderedHash key
  (already ``Messages.stringToKey``-normalised) for hash-typed sections.
* ``en`` is the English text as stored in messages.dat.
* ``ja`` is what you fill in.  Leave it "" to keep the English text.

Existing files are preserved by default: already-translated ``ja`` values are
carried over, new/changed English lines are added, and lines whose English text
disappeared from messages.dat are dropped.  Use --force to rewrite from scratch.
"""

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rmarshal  # noqa: E402
import msgtypes  # noqa: E402


def entries_for_section(sec, data):
    """Yield (key, en) pairs for one section object."""
    if data is None:
        return
    if isinstance(data, dict):          # OrderedHash
        for k, v in data.items():
            if v is None or v == "":
                continue
            yield k, v
    elif isinstance(data, list):
        for i, v in enumerate(data):
            if v is None or v == "":
                continue
            yield i, v
    else:
        raise TypeError("unexpected section payload %r" % type(data))


def load_existing(path):
    """Return {json.dumps(key): (en, ja)} from an existing jsonl file."""
    old = {}
    if not os.path.exists(path):
        return old
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            old[json.dumps(rec.get("key"), ensure_ascii=False)] = (
                rec.get("en", ""), rec.get("ja", ""))
    return old


def write_section(path, sec, pairs, force):
    old = {} if force else load_existing(path)
    lines = []
    kept = 0
    stale = 0
    for key, en in pairs:
        ja = ""
        prev = old.get(json.dumps(key, ensure_ascii=False))
        if prev:
            prev_en, prev_ja = prev
            if prev_ja:
                if prev_en == en:
                    ja = prev_ja
                    kept += 1
                else:
                    stale += 1   # English changed -> drop the old translation
        lines.append(json.dumps(
            {"sec": sec, "key": key, "en": en, "ja": ja}, ensure_ascii=False))
    if not lines:
        if os.path.exists(path):
            os.remove(path)
        return 0, 0, 0
    with open(path, "w", encoding='utf-8', newline='\n') as f:
        f.write("\n".join(lines) + "\n")
    return len(lines), kept, stale


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default=msgtypes.BASE_DAT,
                    help="source messages.dat (read-only)")
    ap.add_argument("--out", default=msgtypes.SRC_DIR, help="output directory")
    ap.add_argument("--force", action="store_true",
                    help="ignore existing translations and rewrite everything")
    args = ap.parse_args()

    print("reading %s" % args.base)
    msgs = rmarshal.load(args.base)
    if not isinstance(msgs, list):
        sys.exit("unexpected top-level type %s" % type(msgs).__name__)
    os.makedirs(args.out, exist_ok=True)

    total_lines = total_kept = total_stale = 0
    files = 0

    # --- section 0: maps + common events -----------------------------------
    maps = msgs[0] or []
    for mapid, data in enumerate(maps):
        pairs = list(entries_for_section("map:%d" % mapid, data))
        if not pairs:
            continue
        sec = "map:%d" % mapid
        path = os.path.join(args.out, msgtypes.section_filename(sec) + ".jsonl")
        n, kept, stale = write_section(path, sec, pairs, args.force)
        if n:
            files += 1
            total_lines += n
            total_kept += kept
            total_stale += stale

    # --- sections 1..22 -----------------------------------------------------
    for sec in sorted(msgtypes.MESSAGE_TYPES):
        if sec >= len(msgs):
            continue
        pairs = list(entries_for_section(sec, msgs[sec]))
        path = os.path.join(args.out, msgtypes.section_filename(sec) + ".jsonl")
        n, kept, stale = write_section(path, sec, pairs, args.force)
        kind = type(msgs[sec]).__name__
        print("  %-24s %-12s %6d entries" % (
            msgtypes.section_filename(sec), kind, n))
        if n:
            files += 1
            total_lines += n
            total_kept += kept
            total_stale += stale

    print()
    print("wrote %d files, %d entries -> %s" % (files, total_lines, args.out))
    if not args.force:
        print("carried over %d existing translations (%d dropped: English changed)"
              % (total_kept, total_stale))


if __name__ == "__main__":
    main()
