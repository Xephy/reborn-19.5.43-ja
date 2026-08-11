# Pokémon Reborn 19.5.43 日本語化パッチ

Pokémon Reborn（RPG Maker XP / Pokémon Essentials, mkxp-z）の日本語化。
マップ会話・UI・システムテキストを含む **80,598 / 80,691 行（99.9%）** を翻訳済み。

**対象バージョン: 19.5.43 専用。** マップIDと行インデックスに依存しているため、
他のバージョンに当てると内容がずれる。

---

## 導入

ゲームのインストール先に、次の28ファイルと2ディレクトリを同じ階層構造で上書きコピーする。

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
Scripts/FieldNotes.rb
Scripts/Reborn/FieldNoteCompiler.rb
Scripts/Messages.rb
Scripts/TextEntry.rb
Scripts/Options.rb
Scripts/Storage.rb
Scripts/Party.rb
Scripts/PurifyChamber.rb
Scripts/Updater.rb
Scripts/Reborn/RebornScripts.rb
Scripts/Reborn/TrainerSelect.rb
Scripts/Randomizer/RandomizerUtils.rb
Scripts/PulseDex.rb
patch/Graphics/Icons/ja/                （タイプアイコン19枚）
patch/Graphics/Pictures/PulseDex/ja/    （パルス図鑑14枚）
```

ゲーム内のオプションで言語を「日本語」に切り替える。
選択肢は `Scripts/Reborn/Settings.rb` の `LANGUAGES` で定義している。

```ruby
LANGUAGES = [
  ["English", "messages.dat"],
  ["日本語",  "japanese.dat"]
]
```

`jp_translation/tools/sync.sh` は、これらを Windows 版と Linux（AppImage）版の
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

### 文字が絵に焼き込まれているもの（タイプアイコン）

タイプは文字列ではなく 64x28 の画像で、`Graphics/Icons/typeFIRE.png` のように
タイプ名が絵に描き込まれている。メッセージ表の対象外なので、日本語版の画像を
`patch/Graphics/Icons/ja/` に置き、`pbResolveBitmap` が日本語のときだけ
同名ファイルの `ja/` 版を先に探すようにした。呼び出し側（約30箇所）を1つも触らずに
すみ、フィールドノートの `<icon=typeFIRE>` にも同時に効く。結果はセッション中
キャッシュするので、画像1枚につきディスクを見るのは1回だけ。

同じ理由でパルス図鑑のページも1件1枚の 512x384 画像で、タイトル・タイプ・とくせい・
説明文がすべて絵に描き込まれている。`build_pulsedex_images.py` が英語版を下敷きに
3つの文字領域だけを地の色で塗りつぶして描き直す。種族名・タイプ名・とくせい名は
`work/src` の翻訳から引くのでゲーム内の表記と食い違わない。説明文だけ
`tools/pulsedex_ja.json` に持たせてある。アルセウスのページは意図的に枠外へ
はみ出す演出なので、行間と溢れ方をそのまま再現している。

画像は `jp_translation/tools/build_type_icons.py` が英語版から生成する。
文字の乗る範囲（6〜21行 x 2〜61列）を地の色で塗りつぶし、同じ白＋1pxの影で
日本語名を描き直す。タイプ名は `work/src/11_types.jsonl` から読むので、
アイコンとバトル中の文字表示が食い違うことはない。`???` は訳が原文と同じなので
生成しない（`ja/` に無ければ英語版にフォールバックする）。

### `_INTL` を通っていない文字列

`messages.dat` に載るのは、スクリプト中の `_INTL("...")` / `_ISPRINTF("...")` の
**リテラル**をコンパイル時に拾ったものだけ。つまり素の文字列をそのまま
`Kernel.pbMessage("...")` に渡している箇所は、表にキーが存在せず永久に英語のままになる。
Reborn には実際にそういう箇所が150件ほどあった。

- `Kernel.pbMessage` / `pbMessageChooseNumber` / `pbMessageFreeText` は、受け取った
  文字列（と選択肢の配列）を表で引き直すようにした（`Kernel.pbLocalize`）。
  訳済みの文字列はキーではないのでそのまま返る。これで呼び出し側を触らずに83件を回収できる
- オプション画面の説明文はオプションに素の文字列として持たせてあるので、
  テキストボックスへ渡す直前で引く
- チャンピオン防衛戦の挑戦者のセリフは `$game_variables` に代入されてから
  `\v[n]` で表示されるので、代入時に `_INTL` を通す
- 文字列連結や `#{}` で組み立てているものは、どうやってもキーにならないので
  `_INTL("...{1}...", 変数)` の形に書き換えた

追加したキーは `work/src/22c_system_texts.jsonl`（セクション22）。

同じ理由で、`Data/fields.dat` に焼き込まれているバトル中のフィールドメッセージ
（フィールド発動時の一文、わざ・タイプが強化／弱体化されたときの一文、フィールドが
変化したときの一文）も表にキーが無く英語のままだった。これは `_INTL(変数)` の形で
表示されているので、キーを `work/src/22d_field_messages.jsonl` に足すだけで直る。
229件。言い回しは旧版の館内資料（map_0428）に合わせてある。
同じ検査は `python3 jp_translation/tools/find_untranslated.py` で再現できる。
Reborn が更新されたときはこれを走らせれば、英語のまま残る箇所が一覧で出る。

### 一度だけコンパイルされるデータ（フィールドノート）

フィールドノートの本文は `Scripts/Reborn/FieldNoteCompiler.rb` の中の英語リテラルで、
初回起動時に `Data/fieldnotes.dat` へ書き出されて以降は再生成されない。フィールド名も
同様に `Data/fields.dat` に固まる。**この2つは全言語で共有される**ので、中身が言語に
依存してはいけない。素の実装は本文の一部を `getMoveName` / `getTypeName` で埋めており、
日本語で初回起動すると訳語が焼き付くうえ、`<icon=typeでんき>` という存在しない
アイコン名になってタイプアイコンが消える。英語で固定するよう直してある
（`feMoveName` / `feTypeIcon`。パッチ後も出力が既存の .dat とバイト一致することを
Ruby で確認済み）。

そのうえで、表示直前に `_INTL` を通して訳す（`fieldNoteName` / `fieldNoteText` /
`fieldNoteElaboration`）。キーは英語の原文そのままで、訳は
`work/src/22b_field_notes.jsonl` にセクション22として入れている。本文847件
（見出し547・詳細300）とフィールド名37件。`Wasteland` と `Cave` はPCボックスの
壁紙名として既にセクション22にあるので、そちらの訳を共有している。

### 未訳の92行について

未訳のまま残しているものは、いずれも訳すべきでない行。

| 内容 | 行数 |
|---|---|
| `REMOVED` `Intro` など画面に出ない内部マップ名 | 44 |
| スタッフロールの実在の人名・ハンドル名 | 37 |
| Twitch Plays Pokémon パロディの入力コマンド列 | 4 |
| ラテン語の銘（`Tempus rerum imperator.` 等） | 3 |
| 伏せ字・顔文字・略号（`XXXXXxxxx`, `:wink:`, `LCCC`） | 4 |
| フィールドの文字化け演出（`.0P pl$ nerf!-//`） | 1 |

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
| `find_untranslated.py` | 表を通らず英語のまま出る文字列を検出 |
| `fitcheck.py` / `fit_lines.py` | メッセージウィンドウ幅の検証と自動改行 |
| `build_glossary.py` | ゲームデータから公式日本語名の用語集を生成 |
| `build_type_icons.py` | 日本語のタイプアイコンを英語版から生成 |
| `build_pulsedex_images.py` | 日本語のパルス図鑑ページを英語版から生成 |
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
26ファイルだけを名指しで許可している。ルートに新しいファイルを置くときは
`.gitignore` に `!` 付きで追記しないと無視されるので注意。
