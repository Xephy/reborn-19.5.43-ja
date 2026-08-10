#!/usr/bin/env python3
"""Round-trip test for rmarshal.py.

    python3 jp_translation/tools/test_roundtrip.py [path/to/messages.dat]

Reads Data/messages.dat, writes it back out with our own dumper, reads the
result again and asserts that the two object graphs are structurally identical
(types included: list vs OrderedHash vs dict, key order, every string).
Also runs a set of small unit round-trips for the primitive types.
"""

import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rmarshal  # noqa: E402
from rmarshal import OrderedHash, Sym, RObj, deep_equal  # noqa: E402

GAME_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))


def test_primitives():
    cases = [
        None, True, False,
        0, 1, 122, 123, 255, 256, -1, -123, -124, -256, 70000, -70000,
        2 ** 30, -(2 ** 30),
        "", "hello", u"日本語", u"café ♪",
        "line1\nline2\r\n\ttab",
        [], [1, 2, 3], [None, True, False, "x", [1, ["y"]]],
        {}, {"a": 1, "b": [2, 3]},
        Sym("foo"),
        OrderedHash(),
    ]
    oh = OrderedHash()
    oh["z first"] = "Z"
    oh["a second"] = "A"
    oh[u"キー"] = u"値"
    cases.append(oh)
    cases.append([oh, {"nested": oh}, "tail"])

    failures = 0
    for c in cases:
        back = rmarshal.loads(rmarshal.dumps(c))
        ok, why = deep_equal(c, back)
        if not ok:
            failures += 1
            print("  FAIL %r -> %r  (%s)" % (c, back, why))
    print("primitives: %d cases, %d failures" % (len(cases), failures))
    return failures == 0


def test_ordered_hash_key_order():
    oh = OrderedHash()
    for i in range(50):
        oh["k%02d" % (49 - i)] = "v%d" % i
    back = rmarshal.loads(rmarshal.dumps(oh))
    ok = isinstance(back, OrderedHash) and list(back.keys()) == list(oh.keys())
    print("ordered-hash key order preserved: %s" % ok)
    return ok


def test_messages_dat(path):
    if not os.path.exists(path):
        print("SKIP: %s not found" % path)
        return False
    orig_bytes = os.path.getsize(path)
    print("reading %s (%d bytes) ..." % (path, orig_bytes))
    a = rmarshal.load(path)

    tmp = tempfile.NamedTemporaryFile(suffix=".dat", delete=False)
    tmp.close()
    try:
        n = rmarshal.dump(a, tmp.name)
        print("wrote %d bytes (original %d)" % (n, orig_bytes))
        b = rmarshal.load(tmp.name)
    finally:
        os.unlink(tmp.name)

    ok, why = deep_equal(a, b)
    print("round-trip structural equality: %s%s" % (ok, "" if ok else "  <- " + why))

    # a second dump of the re-read object must be byte-identical to the first
    ok2 = rmarshal.dumps(a) == rmarshal.dumps(b)
    print("re-dump byte-identical: %s" % ok2)

    # summary of the top-level layout, so regressions are visible
    print("top-level sections: %d" % len(a))
    kinds = {}
    for i, sec in enumerate(a):
        kinds[i] = type(sec).__name__
    print("  section types:", kinds)
    return ok and ok2


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        GAME_ROOT, "Data", "messages.dat")
    results = [
        test_primitives(),
        test_ordered_hash_key_order(),
        test_messages_dat(target),
    ]
    print()
    if all(results):
        print("ALL TESTS PASSED")
        sys.exit(0)
    print("TESTS FAILED")
    sys.exit(1)
