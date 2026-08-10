#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Pokemon Reborn 日本語化: 公式日本語名の用語集(glossary.json)を生成する。

- ゲーム内の英語名は Data/messages.dat (Ruby Marshal) から取得
- 公式日本語名は PokeAPI の CSV (ja-Hrkt = カタカナ表記, language_id=1) から取得
- 英語名(language_id=9)を正規化キーにして突き合わせ
- マッチしなかったものは manual_overrides.json の独自訳を使い、
  glossary_unmatched.md に記録する

使い方:
    python3 jp_translation/tools/build_glossary.py [--csv-dir DIR] [--game-dir DIR]
CSV が無ければ GitHub から自動ダウンロードする。
"""
import argparse
import csv
import json
import os
import re
import sys
import unicodedata
import urllib.request

CSV_BASE = "https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv/"
CSV_FILES = [
    "languages.csv",
    "pokemon_species_names.csv",
    "move_names.csv",
    "ability_names.csv",
    "item_names.csv",
    "type_names.csv",
]

LANG_JA_HRKT = 1   # カタカナ表記 (ゲーム内表記に一致)
LANG_EN = 9

# messages.dat の添字 (Scripts/PBIntl.rb の MessageTypes)
IDX = {
    "species": 1,
    "moves": 5,
    "items": 7,
    "abilities": 9,
    "types": 11,
    "trainer_types": 12,
}

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_GAME_DIR = os.path.abspath(os.path.join(HERE, "..", ".."))
DEFAULT_CSV_DIR = os.path.join(HERE, "pokeapi_csv")
WORK_DIR = os.path.abspath(os.path.join(HERE, "..", "work"))
MANUAL_PATH = os.path.join(HERE, "manual_overrides.json")


# ---------------------------------------------------------------- 正規化
def normalize(name: str) -> str:
    """英語名の表記ゆれを吸収して比較用キーにする。

    é -> e, ♀ -> f, ♂ -> m, 大文字小文字/空白/ハイフン/アポストロフィ/ピリオド/コロンを除去。
    """
    s = unicodedata.normalize("NFKD", name)
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = s.replace("♀", "f").replace("♂", "m")   # ♀ ♂
    s = s.replace("’", "'").replace("é", "e")
    s = s.lower()
    s = re.sub(r"[^a-z0-9]+", "", s)
    return s


# 全角英数字/記号 -> 半角 (PokeAPI の日本語名には全角が混ざる: わざマシン０１ 等)
FULLWIDTH = {}
for _c in range(0xFF01, 0xFF5F):
    FULLWIDTH[_c] = _c - 0xFEE0


def to_halfwidth(s: str) -> str:
    return s.translate(FULLWIDTH)


# ゲーム側の英語名 -> PokeAPI 側の正式英語名 (世代間のリネーム/表記違いを吸収)
ALIASES = {
    "moves": {
        "Vice Grip": "Vise Grip",              # 第8世代でリネーム
        "Nature Madness": "Nature's Madness",  # アポストロフィ無し表記
        "Stomp Tantrum": "Stomping Tantrum",
    },
    "abilities": {
        "Alchemy Power": "Power of Alchemy",
        "Queen Majesty": "Queenly Majesty",
        "Water Compact": "Water Compaction",
        "Power Constr.": "Power Construct",
    },
    "items": {
        "Pretty Wing": "Pretty Feather",       # Wing 系は公式では Feather
        "Health Wing": "Health Feather",
        "Muscle Wing": "Muscle Feather",
        "Resist Wing": "Resist Feather",
        "Genius Wing": "Genius Feather",
        "Clever Wing": "Clever Feather",
        "Swift Wing": "Swift Feather",
        "Stick": "Leek",                       # 第8世代でリネーム
        "X Defend": "X Defense",
        "Itemfinder": "Dowsing Machine",       # 日本語名はどちらも ダウジングマシン
        "Dowsing MCHN": "Dowsing Machine",
        "Membership Card": "Member Card",
    },
    "species": {},
    "types": {},
    "trainer_types": {},
}


# 前置きフォルム修飾語 (ゲーム側にこの形が現れた場合の分解用)
FORM_PREFIXES = {
    "mega": "メガ{}",
    "megax": "メガ{}X",
    "megay": "メガ{}Y",
    "primal": "ゲンシ{}",
    "alolan": "アローラ{}",
    "galarian": "ガラル{}",
    "hisuian": "ヒスイ{}",
    "paldean": "パルデア{}",
    "gigantamax": "キョダイマックス{}",
    "aevian": "エイビア{}",  # Reborn 独自リージョンフォルム
}


# ---------------------------------------------------------------- 入力
def ensure_csv(csv_dir):
    os.makedirs(csv_dir, exist_ok=True)
    for f in CSV_FILES:
        path = os.path.join(csv_dir, f)
        if not os.path.exists(path):
            sys.stderr.write("downloading %s\n" % f)
            urllib.request.urlretrieve(CSV_BASE + f, path)
    return csv_dir


def load_pair_map(csv_dir, fname, id_col, en_lang=LANG_EN, ja_lang=LANG_JA_HRKT):
    """英語名(正規化) -> 日本語名 の辞書と、素の英語名 -> 日本語名 を返す。"""
    en, ja = {}, {}
    with open(os.path.join(csv_dir, fname), encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            lang = int(row["local_language_id"])
            key = row[id_col]
            if lang == en_lang:
                en[key] = row["name"]
            elif lang == ja_lang:
                ja[key] = row["name"]
    out = {}
    for key, ename in en.items():
        if key in ja:
            out.setdefault(normalize(ename), ja[key])
    return out


def load_game_names(game_dir, scratch):
    sys.path.insert(0, scratch)
    import rmarshal  # noqa: E402
    d = rmarshal.load(os.path.join(game_dir, "Data", "messages.dat"))
    out = {}
    for cat, i in IDX.items():
        seen, names = set(), []
        for n in d[i]:
            if not n or not n.strip():
                continue
            if n in seen:
                continue
            seen.add(n)
            names.append(n)
        out[cat] = names
    return out


# ---------------------------------------------------------------- 突き合わせ
def lookup(official, name, aliases=None):
    """公式辞書から日本語名を引く。別名表・フォルム接頭辞にも対応。"""
    key = normalize(name)
    if key in official:
        return official[key], "exact"
    if aliases and name in aliases:
        akey = normalize(aliases[name])
        if akey in official:
            return official[akey], "alias"
    # "Mega Charizard X" のようなフォルム名を分解
    parts = name.replace("-", " ").split()
    if len(parts) >= 2:
        for cut in range(1, len(parts)):
            pre = normalize("".join(parts[:cut]))
            rest = normalize("".join(parts[cut:]))
            if pre in FORM_PREFIXES and rest in official:
                return FORM_PREFIXES[pre].format(official[rest]), "form"
            # 後置き ("Charizard Mega X")
            pre2 = normalize("".join(parts[cut:]))
            rest2 = normalize("".join(parts[:cut]))
            if pre2 in FORM_PREFIXES and rest2 in official:
                return FORM_PREFIXES[pre2].format(official[rest2]), "form"
    return None, None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--game-dir", default=DEFAULT_GAME_DIR)
    ap.add_argument("--csv-dir", default=DEFAULT_CSV_DIR)
    ap.add_argument("--scratch", default=os.environ.get("RMARSHAL_DIR", HERE))
    ap.add_argument("--report-only", action="store_true",
                    help="unmatched の一覧だけを標準出力に出す")
    args = ap.parse_args()

    csv_dir = ensure_csv(args.csv_dir)
    game = load_game_names(args.game_dir, args.scratch)

    official = {
        "species": load_pair_map(csv_dir, "pokemon_species_names.csv", "pokemon_species_id"),
        "moves": load_pair_map(csv_dir, "move_names.csv", "move_id"),
        "items": load_pair_map(csv_dir, "item_names.csv", "item_id"),
        "abilities": load_pair_map(csv_dir, "ability_names.csv", "ability_id"),
        "types": load_pair_map(csv_dir, "type_names.csv", "type_id"),
        "trainer_types": {},   # 公式データなし
    }

    manual = {}
    if os.path.exists(MANUAL_PATH):
        with open(MANUAL_PATH, encoding="utf-8") as fh:
            manual = json.load(fh)

    glossary, unmatched, stats = {}, {}, {}
    for cat, names in game.items():
        g, um = {}, []
        n_official = n_manual = 0
        for name in names:
            ja, how = lookup(official[cat], name, ALIASES.get(cat))
            if ja and cat != "trainer_types":
                g[name] = to_halfwidth(ja)
                n_official += 1
            else:
                m = manual.get(cat, {}).get(name)
                if m:
                    g[name] = m["ja"] if isinstance(m, dict) else m
                    n_manual += 1
                um.append(name)
        glossary[cat] = g
        unmatched[cat] = um
        stats[cat] = {
            "total": len(names),
            "official": n_official,
            "custom": n_manual,
            "missing": len(um) - n_manual,
        }

    os.makedirs(WORK_DIR, exist_ok=True)
    if args.report_only:
        for cat, um in unmatched.items():
            print("### %s (%d)" % (cat, len(um)))
            for n in um:
                print(n)
            print()
        return

    with open(os.path.join(WORK_DIR, "glossary.json"), "w", encoding="utf-8") as fh:
        json.dump(glossary, fh, ensure_ascii=False, indent=1, sort_keys=True)
        fh.write("\n")

    write_unmatched_md(unmatched, manual, stats)

    print("category        total official  custom missing")
    for cat, s in stats.items():
        print("%-15s %5d %7d %7d %7d"
              % (cat, s["total"], s["official"], s["custom"], s["missing"]))


CAT_LABEL = {
    "species": "ポケモン (Species)",
    "moves": "技 (Moves)",
    "items": "道具 (Items)",
    "abilities": "特性 (Abilities)",
    "types": "タイプ (Types)",
    "trainer_types": "トレーナー種別 (TrainerTypes)",
}


def write_unmatched_md(unmatched, manual, stats):
    path = os.path.join(WORK_DIR, "glossary_unmatched.md")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("# 公式日本語名が存在しない項目 (独自翻訳)\n\n")
        fh.write("PokeAPI (ja-Hrkt) に対応する公式名が無かったため、"
                 "Reborn 独自要素として翻訳したもの。\n\n")
        fh.write("| 種別 | 総数 | 公式名マッチ | 独自翻訳 | 未訳 |\n")
        fh.write("|---|---:|---:|---:|---:|\n")
        for cat, s in stats.items():
            fh.write("| %s | %d | %d | %d | %d |\n"
                     % (CAT_LABEL[cat], s["total"], s["official"], s["custom"], s["missing"]))
        fh.write("\n")
        for cat, um in unmatched.items():
            if not um:
                continue
            fh.write("\n## %s — %d件\n\n" % (CAT_LABEL[cat], len(um)))
            fh.write("| 英語名 | 日本語訳 | 根拠 |\n|---|---|---|\n")
            for n in um:
                m = manual.get(cat, {}).get(n)
                if isinstance(m, dict):
                    ja, note = m.get("ja", ""), m.get("note", "")
                elif m:
                    ja, note = m, ""
                else:
                    ja, note = "(未訳)", ""
                fh.write("| %s | %s | %s |\n"
                         % (n.replace("|", "\\|"), ja, note.replace("|", "\\|")))


if __name__ == "__main__":
    main()
