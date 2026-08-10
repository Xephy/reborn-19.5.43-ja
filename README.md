# Pokémon Reborn 19.5.43 日本語化パッチ

Pokémon Reborn（RPG Maker XP / Pokémon Essentials, mkxp-z）の日本語化。
マップ会話・UI・システムテキストを含む **79,335 / 79,427 行（99.9%）** を翻訳済み。

**対象バージョン: 19.5.43 専用。** マップIDと行インデックスに依存しているため、
他のバージョンに当てると内容がずれる。

---

## 導入

ゲームのインストール先に、次の15ファイルを同じ階層構造で上書きコピーする。

```
patch/Data/japanese.dat
patch/Fonts/pokemonemerald.ttf
Scripts/DrawText.rb
Scripts/System.rb
Scripts/Load.rb
Scripts/PBIntl.rb
Scripts/Summary.rb
Scripts/SpriteWindow.rb
Scripts/Items.rb
Scripts/Reborn/Settings.rb
Scripts/Battle_Move.rb
Scripts/Battle_MoveEffects.rb
Scripts/Battle_Scene.rb
Scripts/Battler.rb
Scripts/BattleData.rb
```

ゲーム内のオプションで言語を「日本語」に切り替える。
選択肢は `Scripts/Reborn/Settings.rb` の `LANGUAGES` で定義している。

```ruby
LANGUAGES = [
  ["English", "messages.dat"],
  ["日本語",  "japanese.dat"]
]
```

`jp_translation/tools/sync.sh` は、この15ファイルを Windows 版と Linux（AppImage）版の
両方へ配る。配布先のパスはスクリプト冒頭の `WIN` / `LIN` を書き換える。

### 元に戻す

`jp_translation/backup/` に改変前のスクリプトと、オリジナルの
`recover/messages_19.5.0.dat` が入っている。これらを戻せば英語版に復帰できる。

---

## 翻訳データの構造

`jp_translation/work/src/*.jsonl` が翻訳のソース。1行1エントリ。

```json
{"sec": "map:37", "key": "AME: Thank goodness, you're okay!", "en": "AME: Thank goodness, you're okay!", "ja": "アメ: よかった、無事だったのね!"}
```

- `sec` — messages.dat 内のセクション。数値は固定セクション（1=種族名, 5=わざ名 …）、
  `map:N` はマップ N の会話
- `key` — 元の英語文字列。Essentials の `_INTL` / `_MAPINTL` はこれをキーに実行時に引く
- `ja` — 訳文。空なら未訳で、その行は英語のまま表示される

**すべてのセクションが「英語テキストをキーにした Hash」**なので、インデックスのずれが
構造的に起こらない。部分的な翻訳のまま出荷しても壊れない。

### データ由来の名前（わざ名・とくせい名など）

ポケモン名・わざ名・どうぐ名は会話文と違って `_INTL` を通らない。ゲームデータ側の
オブジェクトが英語名を持っていて、表示のたびに `getMoveName` などが
messages.dat のハッシュを引き直す仕組みになっている。

**この引き直しを飛ばして英語名を直接描いている箇所があると、そこだけ英語のまま残る。**
バトルのわざ選択がまさにそれで、`PokeBattle_Move#name`（生成時にデータの英語名を
コピーしたもの）を描いていた。`Scripts/Battle_Move.rb` で生成時に翻訳名を入れるよう
変更し、英語名が必要な2箇所——ボスのチャージ技の一致判定と `BattleData` の
わざ使用回数の集計キー——だけ新しい `englishName` を参照するようにしてある。

もう1つの落とし穴がフォント。ナロー体（`Power Green Narrow`）は英字しか持たないので、
翻訳した文字列をそのまま描くと空白の箱になる。`pbNarrowFontName` は日本語のときだけ
システムフォント（かな・漢字を持つ唯一のフォント）を返す。スモール体は
`Lv.` と HP の数字しか描かないので触っていない。

### 未訳の92行について

未訳のまま残しているものは、いずれも訳すべきでない行。

| 内容 | 行数 |
|---|---|
| `REMOVED` `Intro` など画面に出ない内部マップ名 | 44 |
| スタッフロールの実在の人名・ハンドル名 | 37 |
| Twitch Plays Pokémon パロディの入力コマンド列 | 4 |
| ラテン語の銘（`Tempus rerum imperator.` 等） | 3 |
| 伏せ字・顔文字・略号（`XXXXXxxxx`, `:wink:`, `LCCC`） | 4 |

---

## 作業フロー

```
extract.py      messages.dat  →  work/src/*.jsonl
make_batch.py   未訳行を抽出  →  work/batch/gN/gN_XXXX.tsv   (id, 話者, 英文)
                （翻訳作業）  →  work/answers/gN_XXXX.tsv    (id, 訳文)
apply_batch.py  訳文を書き戻し（id指定なので他ファイルを汚さない）
dejoyo.py       常用外漢字を一括で仮名／常用漢字の同義語へ
build.py        work/src/*.jsonl  →  patch/Data/japanese.dat（書き出し後に読み直して検証）
sync.sh         パッチ一式を実機へ配布
```

チェックポイントは必ず `apply_batch.py → dejoyo.py → build.py → sync.sh` の順。

### 主なツール

| ツール | 役割 |
|---|---|
| `rmarshal.py` | Ruby Marshal 4.8 の読み書き（Ruby 非依存の純 Python 実装） |
| `extract.py` / `build.py` | messages.dat ⇄ JSONL |
| `make_batch.py` / `apply_batch.py` | 翻訳バッチの発行と書き戻し |
| `dejoyo.py` | 常用外漢字の正規化。残ったものは報告して exit 1 |
| `check_joyo.py` | 常用漢字チェック |
| `fitcheck.py` / `fit_lines.py` | メッセージウィンドウ幅の検証と自動改行 |
| `build_glossary.py` | ゲームデータから公式日本語名の用語集を生成 |
| `recover_from_dat.py` | 既存の .dat から JSONL を復元 |

### 書き戻し時の検証

`apply_batch.py` は各行について次を検査し、通らない行は**書き込まずに報告**する。

- プレースホルダ・制御コード（`\PN` `\v[12]` `\c[3]` `\ch[...]` `{1}` …）が
  英文と同じ多重集合であること
- 訳文が英文のままでないこと（記号・数字・略号・ゲーム内の文字化け演出は除外）

例外が2つある。**`\PN`（主人公名）は原文より多く使ってよい**——引数を持たず表示時に
名前へ展開されるだけで、日本語の語順では英語の "you" の位置に名前を置くほうが自然な
ため。逆に欠けている場合は従来どおり拒否する。**`\tts[...]`（読み上げ用の別読み）と
`\ch[...]`（選択肢メニュー）の括弧内は比較対象外**——どちらも画面に出る本文であり、
訳文と一緒に翻訳されるため。

---

## 翻訳の方針

`jp_translation/work/TRANSLATE_GUIDE.md` に全文。要点のみ:

- ポケモン・わざ・どうぐ・分類名は**公式日本語名**。用語集は
  `work/glossary.json`（ゲームデータから生成）と `work/glossary_extra.json`（会話にしか
  出ない補遺）。**用語集に無くても実在するものは公式名を使う**——glossary.json は
  ゲームのデータから作っているので、会話中でしか言及されない第9世代のポケモンなどは
  載っていない
- Reborn オリジナルの固有名詞は自然な日本語に訳す
- **常用漢字のみ。** 表外漢字は `dejoyo.py` が一括処理するので手で直さない
- 全角スペース（U+3000）を単語区切りに使わない（表示幅の節約）
- 口調は `TRANSLATE_GUIDE.md` の表に確定分をまとめてある
- メッセージウィンドウは2〜3行。原文が短ければ訳も短く
- 罵倒・下品な表現は強度を落とさない（原作の性格描写のため）

---

## ライセンス・権利

- **フォント** `patch/Fonts/pokemonemerald.ttf` の実体は
  **M+ FONTS**（Copyright (C) 2013 M+ Font Project, 8,120グリフ）。M+ のライセンスは
  改変・再配布ともに無制限に許可しており、著作権表示はフォント内部の name テーブルに
  保持されている
- **`patch/Data/japanese.dat`** は Pokémon Reborn の脚本の翻案物。加えてポケモン名等の
  公式日本語名（任天堂／ゲームフリーク／クリーチャーズの商標）を含む
- **`Scripts/*.rb`** は Reborn / Pokémon Essentials のソースの改変版。改変前のものは
  `jp_translation/backup/19.5.43-scripts/` にある（`19.5.0-scripts/` は旧版のもの）
- **`jp_translation/work/src/`** は Reborn の英語スクリプト全文を含む

公開する場合は、ゲーム本体を同梱せず、パッチのみを配布すること。
配布前に Reborn 開発チームへ確認するのが望ましい（他言語翻訳の前例がある）。

---

## リポジトリの構成

リポジトリのルートはゲームのインストール先そのもの。`.gitignore` はホワイトリスト方式で、
`/*` で全体を除外してから必要なパスだけを戻している。ゲーム本体（Audio / Graphics /
Data / エンジンDLL）は含まれない。`Scripts/` もディレクトリごとではなく、改変した
13ファイルだけを名指しで許可している。ルートに新しいファイルを置くときは
`.gitignore` に `!` 付きで追記しないと無視されるので注意。
