"""Minimal Ruby Marshal 4.8 reader/writer, enough for Pokemon Essentials messages.dat.

Supported types
---------------
    nil / true / false / Integer / String / Symbol / Array / Hash
    user-defined ``u`` objects (only ``OrderedHash`` is understood natively)
    generic ``o`` objects (read only, kept as :class:`RObj`)

Notes on fidelity
-----------------
*   Ruby's Marshal keeps an object reference table and emits ``@`` links for
    repeated objects.  When *writing* we never emit links (every object is
    written out in full).  That is still perfectly valid Marshal data - Ruby
    reads it back fine, it is only slightly larger.  Symbols *are* deduplicated
    (``;`` links) because that is trivial and keeps the file small.
*   Strings are always written as ``I"..."`` with the ``:E => true`` instance
    variable, i.e. UTF-8, which is what Essentials expects.
*   ``OrderedHash`` is an Essentials class (Scripts/PBIntl.rb) that defines
    ``_dump`` / ``_load``.  On the wire it is a ``u`` object whose payload is
    ``Marshal.dump([keys, values])``.  Ruby additionally wraps it in an ``I``
    node carrying the ``@keys`` ivar (OrderedHash < Hash, so it has ivars);
    that wrapper is redundant because ``_load`` rebuilds ``@keys`` itself, so
    we do not emit it.
"""

import io

MARSHAL_MAJOR = 4
MARSHAL_MINOR = 8
HEADER = bytes([MARSHAL_MAJOR, MARSHAL_MINOR])


class OrderedHash(dict):
    """Marker type: a dict that must be serialised as Essentials' OrderedHash."""

    def __repr__(self):
        return "OrderedHash(%s)" % dict.__repr__(self)


class Sym(str):
    """Marker type: a Ruby Symbol (distinguishes ``:foo`` from ``"foo"``)."""

    def __repr__(self):
        return ":" + str.__repr__(self)


class RObj(object):
    """A generic Ruby object (``o`` node) or an unknown ``u`` payload."""

    def __init__(self, cls, data, kind="o"):
        self.cls = cls
        self.data = data
        self.kind = kind

    def __repr__(self):
        return "<%s %s %r>" % (self.kind, self.cls, self.data)

    def __eq__(self, other):
        return (isinstance(other, RObj) and self.cls == other.cls
                and self.kind == other.kind and self.data == other.data)

    def __ne__(self, other):
        return not self.__eq__(other)


# --------------------------------------------------------------------------
# Reader
# --------------------------------------------------------------------------

class Bignum(int):
    """A Ruby Bignum.

    Marshal stores integers outside roughly +/-2**30 as 'l' rather than 'i', so
    the distinction has to survive a load/dump round trip - writing one back as
    'i' would silently corrupt it. Behaves as an ordinary int otherwise.
    """
    __slots__ = ()


def _hashable(k):
    """Ruby lets an Array be a Hash key; Python does not, so use a tuple.

    The writer emits a tuple as an Array, so the round trip is unaffected.
    """
    if isinstance(k, list):
        return tuple(_hashable(x) for x in k)
    return k


class Reader(object):
    def __init__(self, b):
        self.b = b
        self.i = 0
        self.symbols = []
        self.objects = []
        if b[0:2] != HEADER:
            raise ValueError("not Marshal 4.8 (got %r)" % (b[0:2],))
        self.i = 2

    def byte(self):
        c = self.b[self.i]
        self.i += 1
        return c

    def long(self):
        c = self.byte()
        if c == 0:
            return 0
        if c > 127:
            c -= 256
        # Ruby r_long: 4 < c < 128  ->  c - 5 ;  -129 < c < -4  ->  c + 5
        if 4 < c <= 127:
            return c - 5
        if -128 <= c < -4:
            return c + 5
        n = abs(c)
        result = 0
        for j in range(n):
            result |= self.byte() << (8 * j)
        if c < 0:
            result -= 1 << (8 * n)
        return result

    def bytestr(self):
        n = self.long()
        s = self.b[self.i:self.i + n]
        self.i += n
        return s

    def parse(self):
        t = self.byte()
        if t == 0x30:                                    # '0' nil
            return None
        if t == 0x54:                                    # 'T'
            return True
        if t == 0x46:                                    # 'F'
            return False
        if t == 0x69:                                    # 'i' Integer
            return self.long()
        if t == 0x6c:                                    # 'l' Bignum
            neg = self.byte() == 0x2d                     # '+' or '-'
            words = self.long()                           # count of 16-bit words
            raw = self.b[self.i:self.i + words * 2]
            self.i += words * 2
            v = Bignum(-int.from_bytes(raw, 'little') if neg
                       else int.from_bytes(raw, 'little'))
            self.objects.append(v)
            return v
        if t == 0x3a:                                    # ':' Symbol
            s = Sym(self.bytestr().decode('utf-8', 'replace'))
            self.symbols.append(s)
            return s
        if t == 0x3b:                                    # ';' symlink
            return self.symbols[self.long()]
        if t == 0x40:                                    # '@' objlink
            return self.objects[self.long()]
        if t == 0x22:                                    # '"' String
            v = self.bytestr().decode('utf-8', 'replace')
            self.objects.append(v)
            return v
        if t == 0x49:                                    # 'I' ivar wrapper
            v = self.parse()
            n = self.long()
            for _ in range(n):
                self.parse()   # ivar name
                self.parse()   # ivar value  (:E => true, @keys => [...])
            return v
        if t == 0x5b:                                    # '[' Array
            n = self.long()
            arr = []
            self.objects.append(arr)
            for _ in range(n):
                arr.append(self.parse())
            return arr
        if t == 0x7b:                                    # '{' Hash
            n = self.long()
            h = {}
            self.objects.append(h)
            for _ in range(n):
                k = _hashable(self.parse())
                h[k] = self.parse()
            return h
        if t == 0x75:                                    # 'u' user-defined
            cls = self.parse()
            payload = self.bytestr()
            if cls == 'OrderedHash':
                sub = Reader(payload).parse()
                keys, vals = sub[0], sub[1]
                od = OrderedHash()
                for k, v in zip(keys, vals):
                    od[k] = v
                self.objects.append(od)
                return od
            obj = RObj(cls, payload, kind="u")
            self.objects.append(obj)
            return obj
        if t == 0x43:                                    # 'C' subclass of a builtin
            self.parse()                                 # class name (unused)
            return self.parse()                          # the wrapped value
        if t == 0x66:                                    # 'f' float
            s = self.bytestr().decode('ascii', 'replace')
            if s == 'inf':
                v = float('inf')
            elif s == '-inf':
                v = float('-inf')
            elif s == 'nan':
                v = float('nan')
            else:
                v = float(s)
            self.objects.append(v)
            return v
        if t == 0x6f:                                    # 'o' plain object
            cls = self.parse()
            d = {}
            obj = RObj(cls, d, kind="o")
            self.objects.append(obj)
            n = self.long()
            for _ in range(n):
                k = self.parse()
                d[k] = self.parse()
            return obj
        raise ValueError("unhandled marshal type %r at offset %d"
                         % (chr(t), self.i - 1))


def loads(data):
    return Reader(data).parse()


def load(path):
    with open(path, 'rb') as f:
        return Reader(f.read()).parse()


# --------------------------------------------------------------------------
# Writer
# --------------------------------------------------------------------------

def _w_long(out, x):
    """Ruby's Marshal w_long."""
    if x == 0:
        out.write(b'\x00')
        return
    if 0 < x < 123:
        out.write(bytes([x + 5]))
        return
    if -124 < x < 0:
        out.write(bytes([(x - 5) & 0xff]))
        return
    buf = []
    v = x
    for i in range(1, 9):
        buf.append(v & 0xff)
        v >>= 8            # Python >> on negatives is arithmetic, like RSHIFT
        if v == 0:
            out.write(bytes([i]))
            break
        if v == -1:
            out.write(bytes([(-i) & 0xff]))
            break
    else:
        raise ValueError("integer too large for Marshal: %d" % x)
    out.write(bytes(buf))


class Writer(object):
    def __init__(self):
        self.out = io.BytesIO()
        self.symbols = {}

    def result(self):
        return HEADER + self.out.getvalue()

    def symbol(self, name):
        idx = self.symbols.get(name)
        if idx is not None:
            self.out.write(b';')
            _w_long(self.out, idx)
            return
        self.symbols[name] = len(self.symbols)
        raw = name.encode('utf-8')
        self.out.write(b':')
        _w_long(self.out, len(raw))
        self.out.write(raw)

    def write(self, obj):
        out = self.out
        if obj is None:
            out.write(b'0')
        elif obj is True:
            out.write(b'T')
        elif obj is False:
            out.write(b'F')
        elif isinstance(obj, Sym):
            self.symbol(str(obj))
        elif isinstance(obj, Bignum):
            out.write(b'l')
            out.write(b'-' if obj < 0 else b'+')
            v = abs(int(obj))
            n = max(1, (v.bit_length() + 15) // 16)
            _w_long(out, n)
            out.write(v.to_bytes(n * 2, 'little'))
        elif isinstance(obj, int):
            out.write(b'i')
            _w_long(out, obj)
        elif isinstance(obj, str):
            raw = obj.encode('utf-8')
            out.write(b'I"')
            _w_long(out, len(raw))
            out.write(raw)
            _w_long(out, 1)          # 1 ivar
            self.symbol('E')
            out.write(b'T')          # :E => true  (UTF-8)
        elif isinstance(obj, (list, tuple)):
            out.write(b'[')
            _w_long(out, len(obj))
            for item in obj:
                self.write(item)
        elif isinstance(obj, OrderedHash):
            keys = list(obj.keys())
            values = [obj[k] for k in keys]
            payload = dumps([keys, values])
            out.write(b'u')
            self.symbol('OrderedHash')
            _w_long(out, len(payload))
            out.write(payload)
        elif isinstance(obj, dict):
            out.write(b'{')
            _w_long(out, len(obj))
            for k, v in obj.items():
                self.write(k)
                self.write(v)
        elif isinstance(obj, RObj):
            if obj.kind == 'u':
                if not isinstance(obj.data, (bytes, bytearray)):
                    raise TypeError("RObj(u) payload must be bytes")
                out.write(b'u')
                self.symbol(str(obj.cls))
                _w_long(out, len(obj.data))
                out.write(bytes(obj.data))
            else:
                out.write(b'o')
                self.symbol(str(obj.cls))
                _w_long(out, len(obj.data))
                for k, v in obj.data.items():
                    self.write(Sym(k) if not isinstance(k, Sym) else k)
                    self.write(v)
        else:
            raise TypeError("cannot marshal %r (%s)" % (obj, type(obj).__name__))


def dumps(obj):
    w = Writer()
    w.write(obj)
    return w.result()


def dump(obj, path):
    data = dumps(obj)
    with open(path, 'wb') as f:
        f.write(data)
    return len(data)


# --------------------------------------------------------------------------
# Structural comparison (used by the round-trip test)
# --------------------------------------------------------------------------

def deep_equal(a, b, path="$"):
    """Return (True, None) or (False, "where/why"). Type-sensitive."""
    if type(a) is not type(b):
        # bool must not be conflated with int, OrderedHash not with dict, etc.
        if not (isinstance(a, str) and isinstance(b, str)
                and type(a) is str and type(b) is str):
            return False, "%s: type %s != %s" % (path, type(a).__name__,
                                                 type(b).__name__)
    if isinstance(a, (list, tuple)):
        if len(a) != len(b):
            return False, "%s: length %d != %d" % (path, len(a), len(b))
        for i, (x, y) in enumerate(zip(a, b)):
            ok, why = deep_equal(x, y, "%s[%d]" % (path, i))
            if not ok:
                return ok, why
        return True, None
    if isinstance(a, dict):
        ka, kb = list(a.keys()), list(b.keys())
        if ka != kb:
            return False, "%s: key set/order differs (%d vs %d)" % (
                path, len(ka), len(kb))
        for k in ka:
            ok, why = deep_equal(a[k], b[k], "%s[%r]" % (path, k))
            if not ok:
                return ok, why
        return True, None
    if isinstance(a, RObj):
        if a.cls != b.cls or a.kind != b.kind:
            return False, "%s: RObj header differs" % path
        return deep_equal(a.data, b.data, path + ".data")
    if a != b:
        return False, "%s: %r != %r" % (path, a, b)
    return True, None
