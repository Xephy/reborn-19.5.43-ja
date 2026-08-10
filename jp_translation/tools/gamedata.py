# -*- coding: utf-8 -*-
"""Recover "which move/ability/item/species does this description belong to?".

Up to 19.5.0 the description sections of messages.dat were arrays whose index
matched the corresponding name section, so a description could be paired with
its owner by position. 19.5.43 turned every section into a hash keyed by the
English text itself, which drops that pairing entirely — a description entry
now only knows its own wording.

The compiled game data still holds both halves, so the mapping is rebuilt from
there: Data/moves.dat, abil.dat and items.dat each carry @name next to @desc,
and mons.dat carries @kind and @dexentry per form.

Descriptions are not unique (several items share wording), so each map is
description -> first owning name; that is enough to look up an official
Japanese translation for it.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rmarshal  # noqa: E402


def _field(obj, name):
    """Read @name-style ivars off a parsed Ruby object, tolerating Sym keys."""
    d = obj.data if hasattr(obj, 'data') else obj
    if not isinstance(d, dict):
        return None
    for k, v in d.items():
        if str(k) == name:
            return v
    return None


def _pairs(path, name_field='@name', desc_field='@desc'):
    out = {}
    if not os.path.exists(path):
        return out
    for entry in rmarshal.load(path).values():
        nm = _field(entry, name_field)
        ds = _field(entry, desc_field)
        if isinstance(nm, str) and isinstance(ds, str) and nm and ds:
            out.setdefault(ds.strip(), nm)
    return out


def move_desc_to_name(base='Data'):
    return _pairs(os.path.join(base, 'moves.dat'))


def ability_desc_to_name(base='Data'):
    return _pairs(os.path.join(base, 'abil.dat'))


def item_desc_to_name(base='Data'):
    return _pairs(os.path.join(base, 'items.dat'))


def species_maps(base='Data'):
    """(kind -> species name, dex entry -> species name).

    mons.dat nests per-form data under @pokemonData; the first form carries the
    canonical name, kind and dex entry.
    """
    kinds, entries = {}, {}
    path = os.path.join(base, 'mons.dat')
    if not os.path.exists(path):
        return kinds, entries
    for mon in rmarshal.load(path).values():
        forms = _field(mon, '@pokemonData')
        if not isinstance(forms, dict):
            continue
        for form in forms.values():
            nm = _field(form, '@name')
            if not isinstance(nm, str) or not nm:
                continue
            kd = _field(form, '@kind')
            en = _field(form, '@dexentry')
            if isinstance(kd, str) and kd:
                kinds.setdefault(kd.strip(), nm)
            if isinstance(en, str) and en:
                entries.setdefault(en.strip(), nm)
    return kinds, entries


if __name__ == '__main__':
    mv = move_desc_to_name()
    ab = ability_desc_to_name()
    it = item_desc_to_name()
    kd, de = species_maps()
    print(f'move descriptions    {len(mv)}')
    print(f'ability descriptions {len(ab)}')
    print(f'item descriptions    {len(it)}')
    print(f'species kinds        {len(kd)}')
    print(f'species dex entries  {len(de)}')
