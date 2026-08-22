#!/usr/bin/env python3
"""日本語化パッチの翻訳データを、攻略サイトが読める
1枚の JSON 辞書に書き出す。

サイトの wt_generator.rb は Scripts/Reborn/*text.rb を eval して表を組み立てる。
そこに載る固有名詞は、このパッチが既に訳しているものと同一なので、カテゴリ別の
en -> ja 表を渡してやれば、生成側は文字列を差し替えるだけで日本語になる。

カテゴリを分けているのは、英語が同綴りでも文脈で訳が変わるものがあるため
(技の Metronome と道具の Metronome など)。素の一枚辞書にすると衝突する。

使い方:
    python3 export_web_dict.py [-o 出力先.json] [--scripts Scripts のパス]

出力先の既定は隣にある攻略サイトの _ja/dict.json (リポジトリ2つが兄弟にある前提)。
"""

import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent                       # Reborn-19.5.0-windows/
WORK = REPO / "jp_translation" / "work"
SRC = WORK / "src"

# カテゴリ名 -> (それを含む jsonl のファイル名, glossary.json 側のキー)
# glossary は後から重ねる。手で直した訳が入っているのはこちら側なので優先する。
CATEGORIES = {
    "species":       (["01_species"],                   "species"),
    "form_names":    (["04_form_names"],                None),
    "moves":         (["05_moves"],                     "moves"),
    "move_descs":    (["06_move_descriptions"],         None),
    "items":         (["07_items"],                     "items"),
    "item_descs":    (["08_item_descriptions"],         None),
    "abilities":     (["09_abilities"],                 "abilities"),
    "ability_descs": (["10_ability_descs"],             None),
    "types":         (["11_types"],                     "types"),
    "trainer_types": (["12_trainer_types"],             "trainer_types"),
    "trainer_names": (["13_trainer_names",
                       "13b_bt_trainer_names"],         None),
    # fields はここでは作らない。22b_field_notes には名前だけでなく解説文が
    # 800 行以上入っており、丸ごと取り込むと辞書が肥大して無関係な長文が混ざる。
    # 実際のフィールド名だけを build_fields() で組み立てる。
}

# マップ名だけは英語ではなくマップ ID をキーにする。サイト側の load_maps_hash も
# ID キーなので、同名マップ ("Grand Hall" が複数ある等) を取り違えずに済む。
MAP_FILE = "20_map_names"


def load_jsonl(name):
    path = SRC / f"{name}.jsonl"
    if not path.exists():
        sys.exit(f"元データが見つからない: {path}")
    with path.open(encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line:
                yield json.loads(line)


def build_categories(glossary):
    out, stats = {}, {}
    for cat, (files, gkey) in CATEGORIES.items():
        table = {}
        for name in files:
            for row in load_jsonl(name):
                en, ja = row.get("en"), row.get("ja")
                # ja が空 = 未訳、ja == en = 意図的に英語のまま残した行。
                # どちらも入れない。入れると生成側で無駄な置換が走る。
                if en and ja and ja != en:
                    table[en] = ja
        if gkey and gkey in glossary:
            for en, ja in glossary[gkey].items():
                if ja and ja != en:
                    table[en] = ja
        out[cat] = dict(sorted(table.items()))
        stats[cat] = len(table)
    return out, stats


# フィールド名は 37 個中 2 個 (Cave / Wasteland) だけが field_notes ではなく
# 汎用のスクリプト文字列側に入っている。fieldtext.rb から実際の名前を読み、
# 足りない分をこちらから補う。
FIELD_FALLBACK = ["22_script_texts", "22d_field_messages"]


def build_fields(scripts_dir):
    """fieldtext.rb に載っている実際のフィールド名だけを集める。

    訳は field_notes と汎用スクリプト文字列の両方から探す
    (Cave / Wasteland の 2 つだけ field_notes 側に無いため)。
    """
    path = scripts_dir / "Reborn" / "fieldtext.rb"
    if not path.exists():
        return {}
    names = {
        n for n in re.findall(
            r':name\s*=>\s*"((?:[^"\\]|\\.)*)"',
            path.read_text(encoding="utf-8", errors="replace"),
        ) if n.strip()
    }
    table = {}
    for src in ["22b_field_notes"] + FIELD_FALLBACK:
        for row in load_jsonl(src):
            en, ja = row.get("en"), row.get("ja")
            if en in names and ja and ja != en:
                table.setdefault(en, ja)
    return dict(sorted(table.items()))


def patch_fields(cats, scripts_dir):
    path = scripts_dir / "Reborn" / "fieldtext.rb"
    if not path.exists():
        return []
    names = {
        n for n in re.findall(
            r':name\s*=>\s*"((?:[^"\\]|\\.)*)"',
            path.read_text(encoding="utf-8", errors="replace"),
        ) if n.strip()
    }
    missing = names - cats["fields"].keys()
    if not missing:
        return []
    pool = {}
    for name in FIELD_FALLBACK:
        for row in load_jsonl(name):
            en, ja = row.get("en"), row.get("ja")
            if en in missing and ja and ja != en:
                pool.setdefault(en, ja)
    cats["fields"].update(pool)
    cats["fields"] = dict(sorted(cats["fields"].items()))
    return sorted(pool.items())


# 性格名 (がんばりや 等) は専用ファイルを持たず、汎用のスクリプト文字列の中に
# 25個の連続ブロックとして入っている。しかも "Hardy" はトレーナー名 (ハーディ)
# とも衝突するので、英語一致では引けない。naturetext.rb の並び順と一致する
# 連続部分列を探して位置で確定させる。
def build_natures(scripts_dir):
    path = scripts_dir / "Reborn" / "naturetext.rb"
    if not path.exists():
        return {}
    names = [
        n for n in re.findall(
            r':name\s*=>\s*"([^"]*)"',
            path.read_text(encoding="utf-8", errors="replace"),
        ) if n.strip()
    ]
    rows = list(load_jsonl("22_script_texts"))
    span = len(names)
    for i in range(len(rows) - span + 1):
        window = rows[i:i + span]
        if [r.get("en") for r in window] != names:
            continue
        return {
            r["en"]: r["ja"] for r in window
            if r.get("ja") and r["ja"] != r["en"]
        }
    return {}


# フィールドノート (ポケギア内アプリ「フィールドノート」の本文) は 880 行ほど
# あり、dict.json に混ぜると無関係な長文で辞書が肥大する。攻略サイト側でも
# 引く場所が1ページだけなので、別ファイルに書き出す。
#
# キーは英語の原文そのもの。サイト側は Data/fieldnotes.dat (英語のまま
# コンパイルされたもの) を読んでフィールドごとに束ね、この表で訳を当てる。
def build_field_notes():
    table = {}
    for row in load_jsonl("22b_field_notes"):
        en, ja = row.get("en"), row.get("ja")
        if en and ja and ja != en:
            table[en] = ja
    return dict(sorted(table.items()))


def build_map_names():
    table = {}
    for row in load_jsonl(MAP_FILE):
        en, ja = row.get("en"), row.get("ja")
        if isinstance(row.get("key"), int) and ja and ja != en:
            table[str(row["key"])] = ja
    return dict(sorted(table.items(), key=lambda kv: int(kv[0])))


def detect_conflicts(cats):
    """同じ英語がカテゴリ間で違う訳を持つものを洗い出す。

    カテゴリ分けが本当に必要かの裏付けであり、分け方を間違えたときの警報でもある。
    """
    seen = {}
    for cat, table in cats.items():
        if cat.endswith("_descs"):
            continue
        for en, ja in table.items():
            seen.setdefault(en, {})[cat] = ja
    return {
        en: v for en, v in seen.items()
        if len(v) > 1 and len(set(v.values())) > 1
    }


def verify(scripts_dir, cats, maps):
    """ゲーム本体の *text.rb から実際のキーを読み、辞書で引けるか数える。

    サイトが出力するのはこの *text.rb の中身そのものなので、ここが 100% なら
    生成物に英語が残らない。
    """
    d = scripts_dir / "Reborn"
    if not d.is_dir():
        print(f"  (検証をスキップ: {d} がない)")
        return

    def literals(fname, key):
        path = d / fname
        if not path.exists():
            return []
        text = path.read_text(encoding="utf-8", errors="replace")
        return re.findall(r':%s\s*=>\s*"((?:[^"\\]|\\.)*)"' % key, text)

    checks = [
        ("ポケモン名",     literals("montext.rb", "name"),      "species"),
        ("どうぐ名",       literals("itemtext.rb", "name"),     "items"),
        ("どうぐ説明",     literals("itemtext.rb", "desc"),     "item_descs"),
        ("わざ名",         literals("movetext.rb", "name"),     "moves"),
        ("わざ説明",       literals("movetext.rb", "desc"),     "move_descs"),
        ("とくせい名",     literals("abiltext.rb", "name"),     "abilities"),
        ("トレーナー種別", literals("ttypetext.rb", "title"),   "trainer_types"),
        ("フィールド名",   literals("fieldtext.rb", "name"),    "fields"),
    ]

    tn = re.findall(
        r':teamid\s*=>\s*\["((?:[^"\\]|\\.)*)"',
        (d / "trainertext.rb").read_text(encoding="utf-8", errors="replace"),
    )
    checks.append(("トレーナー名", tn, "trainer_names"))

    print("\n  ゲーム本体のキーに対するカバー率:")
    worst = 1.0
    for label, values, cat in checks:
        vals = sorted({v for v in values if v.strip()})
        if not vals:
            continue
        table = cats[cat]
        miss = [v for v in vals if v not in table]
        rate = 1 - len(miss) / len(vals)
        worst = min(worst, rate)
        mark = "OK " if not miss else "-- "
        print(f"    {mark}{label:14} {len(vals) - len(miss):5}/{len(vals):<5} {rate:6.1%}")
        if miss:
            print(f"         未収録: {miss[:5]}{' ...' if len(miss) > 5 else ''}")

    # マップ名は ID 突き合わせ。metatext.rb はマップ ID の直前行のコメントが名前。
    meta = (d / "metatext.rb").read_text(encoding="utf-8", errors="replace").split("\n")
    ids = [
        int(m.group(1))
        for i, line in enumerate(meta)
        if (m := re.match(r"^\s*(\d{1,3})\s*=>\s*\{", line))
    ]
    miss = [i for i in ids if str(i) not in maps]
    print(f"    {'OK ' if not miss else '-- '}{'マップ名':14} "
          f"{len(ids) - len(miss):5}/{len(ids):<5} {1 - len(miss) / len(ids):6.1%}")
    if miss:
        names = []
        for i, line in enumerate(meta):
            m = re.match(r"^\s*(\d{1,3})\s*=>\s*\{", line)
            if m and int(m.group(1)) in miss and i:
                c = re.search(r"#(.+)", meta[i - 1])
                names.append(c.group(1).strip() if c else f"id={m.group(1)}")
        print(f"         未収録: {names[:8]}")
        print("         (内部マップは意図的に英語のまま。NOTICE 参照)")


def default_output():
    """攻略サイト側の _ja/dict.json を探す。

    ディレクトリ名は環境によって違う (フォーク元の BIGJRA.github.io のまま
    clone している場合と、改名後の xephy.github.io の場合がある)。両方見て、
    実在する方を返す。どちらも無ければ -o で指定してもらう。
    """
    for name in ("xephy.github.io", "BIGJRA.github.io"):
        candidate = REPO.parent / name / "_ja"
        if candidate.is_dir():
            return candidate / "dict.json"
    return REPO.parent / "xephy.github.io" / "_ja" / "dict.json"


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("-o", "--output", type=Path, default=default_output())
    ap.add_argument("--scripts", type=Path, default=REPO / "Scripts")
    args = ap.parse_args()

    glossary = json.loads((WORK / "glossary.json").read_text(encoding="utf-8"))
    cats, stats = build_categories(glossary)
    cats["fields"] = build_fields(args.scripts)
    stats["fields"] = len(cats["fields"])
    filled = []
    cats["natures"] = build_natures(args.scripts)
    stats["natures"] = len(cats["natures"])
    maps = build_map_names()
    field_notes = build_field_notes()

    print("辞書を組み立てました:")
    for cat, n in stats.items():
        print(f"    {cat:16} {n:6}")
    print(f"    {'map_names':16} {len(maps):6}")
    print(f"    {'field_notes':16} {len(field_notes):6}  (別ファイル)")

    if filled:
        print("\n  フィールド名を補完: " + ", ".join(f"{en}={ja}" for en, ja in filled))

    conflicts = detect_conflicts(cats)
    if conflicts:
        print(f"\n  カテゴリ間で訳が割れる語 {len(conflicts)} 件 "
              f"(カテゴリ分けが効いている証拠。異常ではない):")
        for en, v in list(conflicts.items())[:8]:
            print(f"    {en!r}: " + ", ".join(f"{c}={j}" for c, j in v.items()))

    verify(args.scripts, cats, maps)

    payload = {
        "_comment": "jp_translation/tools/export_web_dict.py が生成。直接編集しないこと。",
        "_source": "Pokemon Reborn 日本語化パッチ (非公式ファン翻訳)",
        "_license": "翻訳テキストは MIT ではない。同梱リポジトリの NOTICE を参照。",
        "map_names": maps,
        **cats,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=1, sort_keys=False) + "\n",
        encoding="utf-8",
    )
    total = sum(stats.values()) + len(maps)
    size = args.output.stat().st_size
    print(f"\n  -> {args.output}  ({total:,} 語 / {size / 1024:.0f} KB)")

    notes_path = args.output.parent / "field-notes.json"
    notes_path.write_text(
        json.dumps(
            {
                "_comment": "jp_translation/tools/export_web_dict.py が生成。直接編集しないこと。",
                "_source": "Pokemon Reborn 日本語化パッチ (非公式ファン翻訳)",
                "_license": "翻訳テキストは MIT ではない。同梱リポジトリの NOTICE を参照。",
                "notes": field_notes,
            },
            ensure_ascii=False, indent=1, sort_keys=False,
        ) + "\n",
        encoding="utf-8",
    )
    print(f"  -> {notes_path}  ({len(field_notes):,} 行 / "
          f"{notes_path.stat().st_size / 1024:.0f} KB)")


if __name__ == "__main__":
    main()
