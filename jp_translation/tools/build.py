#!/usr/bin/env python3
"""Build patch/Data/japanese.dat from the translated JSONL files.

    python3 jp_translation/tools/build.py [--src DIR] [--base DAT] [--out DAT]

* Entries whose ``ja`` is empty are skipped - Essentials falls back to English
  for them (list sections via MessageTypes.get's messagesFallback, hash
  sections because getFromHash/getFromMapHash return the key unchanged).
* The structure and the per-section type of the original messages.dat are
  preserved (Array stays Array, OrderedHash stays OrderedHash).
* After writing, the file is read back with our own parser and verified, then
  the translated counts are printed.

Data/messages.dat is only ever read, never written.
"""

import argparse
import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rmarshal  # noqa: E402
import msgtypes  # noqa: E402
from rmarshal import OrderedHash  # noqa: E402


def parse_sec(sec):
    """'map:31' -> (0, 31) ; 5 -> (5, None)"""
    if isinstance(sec, str):
        if sec.startswith("map:"):
            return 0, int(sec[4:])
        return int(sec), None
    return int(sec), None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=msgtypes.SRC_DIR)
    ap.add_argument("--base", default=msgtypes.BASE_DAT)
    ap.add_argument("--out", default=msgtypes.OUT_DAT)
    args = ap.parse_args()

    base = rmarshal.load(args.base)
    if not isinstance(base, list):
        sys.exit("unexpected top-level type in %s" % args.base)
    n_sections = len(base)
    base_maps = base[0] if isinstance(base[0], list) else []

    # ---- allocate an output skeleton with the same shape/types -------------
    out = [None] * n_sections
    out[0] = [None] * len(base_maps)
    for i in range(1, n_sections):
        if isinstance(base[i], OrderedHash):
            out[i] = OrderedHash()
        elif isinstance(base[i], dict):
            out[i] = {}
        elif isinstance(base[i], list):
            out[i] = [""] * len(base[i])
        # else: leave nil -> Essentials falls back to messages.dat

    counts = {}
    warnings = []
    files = sorted(glob.glob(os.path.join(args.src, "**", "*.jsonl"),
                             recursive=True))
    if not files:
        sys.exit("no .jsonl files under %s (run extract.py first)" % args.src)

    total_lines = 0
    for path in files:
        rel = os.path.relpath(path, args.src)
        with open(path, encoding='utf-8') as f:
            for lineno, line in enumerate(f, 1):
                line = line.strip()
                if not line or line.startswith("//"):
                    continue
                total_lines += 1
                try:
                    rec = json.loads(line)
                except ValueError as e:
                    warnings.append("%s:%d: bad JSON (%s)" % (rel, lineno, e))
                    continue
                ja = rec.get("ja") or ""
                if not ja:
                    continue
                try:
                    sec, mapid = parse_sec(rec["sec"])
                except (KeyError, ValueError):
                    warnings.append("%s:%d: bad 'sec' %r" % (rel, lineno, rec.get("sec")))
                    continue
                key = rec.get("key")

                if sec == 0:                      # map / common-event text
                    if mapid is None or mapid >= len(out[0]):
                        warnings.append("%s:%d: map id %r out of range" % (rel, lineno, mapid))
                        continue
                    if not isinstance(key, str):
                        warnings.append("%s:%d: map key must be a string" % (rel, lineno))
                        continue
                    if out[0][mapid] is None:
                        out[0][mapid] = OrderedHash()
                    out[0][mapid][msgtypes.string_to_key(key)] = ja
                    counts["map:%d" % mapid] = counts.get("map:%d" % mapid, 0) + 1
                    continue

                if sec >= n_sections or out[sec] is None:
                    warnings.append("%s:%d: unknown section %r" % (rel, lineno, sec))
                    continue
                if isinstance(out[sec], list):
                    if not isinstance(key, int):
                        warnings.append("%s:%d: section %d needs an integer key, got %r"
                                        % (rel, lineno, sec, key))
                        continue
                    if key < 0 or key >= len(out[sec]):
                        warnings.append("%s:%d: index %d out of range for section %d (len %d)"
                                        % (rel, lineno, key, sec, len(out[sec])))
                        continue
                    out[sec][key] = ja
                else:
                    if not isinstance(key, str):
                        warnings.append("%s:%d: section %d needs a string key, got %r"
                                        % (rel, lineno, sec, key))
                        continue
                    out[sec][msgtypes.string_to_key(key)] = ja
                counts[sec] = counts.get(sec, 0) + 1

    # drop empty map hashes so the file stays small (nil -> English fallback)
    out[0] = [h if h else None for h in out[0]]

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    size = rmarshal.dump(out, args.out)

    # ---- verify by reading our own output back -----------------------------
    check = rmarshal.load(args.out)
    ok, why = rmarshal.deep_equal(out, check)
    if not ok:
        sys.exit("VERIFY FAILED: %s" % why)
    if len(check) != n_sections:
        sys.exit("VERIFY FAILED: section count %d != %d" % (len(check), n_sections))
    for i in range(1, n_sections):
        if base[i] is None:
            continue
        if isinstance(base[i], OrderedHash) and not isinstance(check[i], OrderedHash):
            sys.exit("VERIFY FAILED: section %d should be OrderedHash" % i)
        if isinstance(base[i], list) and not isinstance(check[i], list):
            sys.exit("VERIFY FAILED: section %d should be Array" % i)
        if isinstance(base[i], list) and len(check[i]) != len(base[i]):
            sys.exit("VERIFY FAILED: section %d length %d != %d"
                     % (i, len(check[i]), len(base[i])))
    if len(check[0]) != len(base_maps):
        sys.exit("VERIFY FAILED: map array length %d != %d"
                 % (len(check[0]), len(base_maps)))

    # ---- report ------------------------------------------------------------
    map_total = sum(v for k, v in counts.items() if isinstance(k, str))
    map_files = sum(1 for k, v in counts.items() if isinstance(k, str) and v)
    print("scanned %d files / %d lines under %s" % (len(files), total_lines, args.src))
    print()
    for sec in sorted(k for k in counts if not isinstance(k, str)):
        print("  %-24s %6d translated" % (msgtypes.section_filename(sec), counts[sec]))
    if map_total:
        print("  %-24s %6d translated (%d maps)" % ("map:* (maps/commons)",
                                                    map_total, map_files))
    print()
    print("total translated entries: %d" % (sum(counts.values())))
    print("wrote %s (%d bytes) - verified by re-reading" % (args.out, size))
    if warnings:
        print()
        print("%d warning(s):" % len(warnings))
        for w in warnings[:30]:
            print("  " + w)
        if len(warnings) > 30:
            print("  ... and %d more" % (len(warnings) - 30))


if __name__ == "__main__":
    main()
