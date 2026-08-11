# Pokémon Reborn 19.5.43 日本語化パッチ

> **有志による非公式のファンメイド翻訳パッチです。**
> 任天堂・株式会社ポケモン・ゲームフリーク・クリーチャーズ、および
> Pokémon Reborn 開発チームとは一切関係がありません。公式の日本語版でもありません。

Pokémon Reborn（RPG Maker XP / Pokémon Essentials, mkxp-z）を日本語で遊ぶためのパッチ。
ストーリー会話からバトルメッセージ、UI、フィールド効果の説明まで
**80,598 / 80,691 行（99.9%）** を翻訳してあります。

タイトル画面から英語 / 日本語をいつでも切り替えられます。英語に戻せば文章はすべて
元のまま表示されます（ゲーム全体のフォントだけは同梱のものに置き換わります）。

---

## 対象

| | |
|---|---|
| パッチのバージョン | **v19.5.43-ja.1** |
| 対象 | **Pokémon Reborn 19.5.43 専用** |
| 動作環境 | Windows 版 / Linux（AppImage）版 |
| 必要なもの | `mkxp.json` に `"patches": ["patch"]` があること（19.5.43 では標準で入っています） |

他のバージョンに当てないでください。マップIDと行インデックスに依存しているため、
別バージョンでは文章がずれます。

---

## 導入

### 1. ファイルをコピーする

Releases から `reborn-19.5.43-ja.1.zip` を取得し、ゲームのインストール先
（`Game.exe` / `Game.AppImage` のある場所）で展開します。中身は次のとおりで、
**同じ階層構造のまま**上書きされます。

```
patch/Data/japanese.dat                     翻訳データ
patch/Fonts/pokemonemerald.ttf              かな・漢字入りのフォント
patch/Graphics/Icons/ja/                    タイプアイコン 19枚
patch/Graphics/Pictures/PulseDex/ja/        パルス図鑑のページ 14枚
patch/Graphics/Pictures/Pokedex/ja/         図鑑のタイプバッジ 19枚
patch/Graphics/Pictures/Battle/ja/          バトルの行動選択ボタン

Scripts/Battle.rb              Scripts/Options.rb
Scripts/Battle_Effects.rb      Scripts/Party.rb
Scripts/Battle_Move.rb         Scripts/PBIntl.rb
Scripts/Battle_MoveEffects.rb  Scripts/PokedexScene.rb
Scripts/Battle_Scene.rb        Scripts/PulseDex.rb
Scripts/Battle_ZMove.rb        Scripts/PurifyChamber.rb
Scripts/BattleData.rb          Scripts/SpriteWindow.rb
Scripts/Battler.rb             Scripts/Storage.rb
Scripts/BattleSwap.rb          Scripts/Summary.rb
Scripts/DrawText.rb            Scripts/System.rb
Scripts/Field.rb               Scripts/TextEntry.rb
Scripts/FieldNotes.rb          Scripts/Updater.rb
Scripts/Game_Map.rb            Scripts/Randomizer/RandomizerUtils.rb
Scripts/ItemEffects.rb         Scripts/Reborn/FieldNoteCompiler.rb
Scripts/Items.rb               Scripts/Reborn/RebornScripts.rb
Scripts/Load.rb                Scripts/Reborn/Settings.rb
Scripts/Messages.rb            Scripts/Reborn/TrainerSelect.rb
```

`patch/` 以下の6つと、`Scripts/` 以下の34ファイルです。
`patch/` はゲームが標準で読み込む差分フォルダなので、既存のファイルは消えません。

### 2. 言語を切り替える

ゲームを起動すると、タイトル画面に **`Language`** が増えています。
ここから「日本語」を選ぶと切り替わり、設定は保存されます。

初回起動時は英語で始まります。

---

## 元に戻す

`jp_translation/backup/19.5.43-scripts/` に改変前のスクリプトが入っています。
これらを `Scripts/` へ書き戻し、コピーした `patch/` 以下の4つを削除すれば元通りです。

セーブデータは英語版と共通で、言語を切り替えても壊れません。

---

## 翻訳されている範囲

- ストーリー会話・イベント・NPCのセリフ（全マップ）
- ポケモン・わざ・とくせい・どうぐ・分類・タイプの名前（**公式日本語名**）
- わざ・とくせい・どうぐの説明文、図鑑の説明文
- バトル中のメッセージ、わざ選択画面、フィールド効果の発動メッセージ
- ポケモン詳細画面、手持ち、バッグ、PCボックス、オプション、セーブ画面
- ポケモン図鑑（分類・図鑑説明・タイプバッジ）
- ポケギア（フィールドノート、パルス図鑑、タウンマップ）
- エリア移動時の地名表示
- タイプアイコン、パルス図鑑のページ、バトルの行動選択ボタン（文字が絵に描き込まれているため画像を作り直しています）

### 英語のまま残るもの

意図的に残している 93 行があります。いずれも訳すべきでない箇所です。

| 内容 | 行数 |
|---|---|
| `REMOVED` `Intro` など画面に出ない内部マップ名 | 44 |
| スタッフロールの実在の人名・ハンドル名 | 37 |
| Twitch Plays Pokémon パロディの入力コマンド列 | 4 |
| ラテン語の銘（`Tempus rerum imperator.` 等） | 3 |
| 伏せ字・顔文字・略号（`XXXXXxxxx`, `:wink:`, `LCCC`） | 4 |
| フィールドの文字化け演出（`.0P pl$ nerf!-//`） | 1 |

このほか、開発者向けのデバッグ画面・マップエディタ・オンライン通信のログは
対象外です。

---

## 注意点

- **名前の入力は英数字のみ。** 主人公名やニックネームの入力画面はゲーム側が
  A–Z・0–9 しか持っておらず、日本語は入力できません
- **ゲーム本体のアップデータを実行すると `Scripts/` が上書きされます。**
  更新後はスクリプトを再度コピーしてください（`patch/` 以下は残ります）
- **フォントが置き換わります。** かな・漢字を持つフォントが必要なため、英語表示のときも
  同梱の M+ FONTS で描画されます。元の書体に戻したい場合は
  `patch/Fonts/pokemonemerald.ttf` を削除してください（日本語は表示できなくなります）
- ポケモン図鑑と検索画面の枠に描かれた `EXIT` `NAV` `SEARCH` は英語のままです
  （絵の一部で、背景が単色でないため差し替えていません）
- 表示崩れが残っている可能性があります。長い訳文は自動で縮小・改行するように
  していますが、全画面を網羅的に確認したわけではありません

---

## 権利・免責

このパッチは**ファンによる非公式の翻訳**です。営利目的ではありません。

- **ポケモン**は任天堂・株式会社ポケモン・ゲームフリーク・クリーチャーズの登録商標です。
  訳文にはポケモン・わざ・とくせい・どうぐの**公式日本語名**を使用していますが、
  これらの権利は上記各社に帰属します。本パッチは各社が公認・提供するものではありません
- **Pokémon Reborn** は Amethyst 氏および Reborn 開発チームによるファンゲームです。
  本パッチはその翻訳であり、開発チームが制作・公認したものではありません。
  **翻訳に関する不具合は Reborn 公式フォーラムへ報告しないでください**
- 本パッチの利用によって生じたいかなる損害についても責任を負いません

同梱物の内訳:

| | |
|---|---|
| `patch/Fonts/pokemonemerald.ttf` | 実体は **M+ FONTS**（Copyright (C) 2013 M+ Font Project, 8,120グリフ）。改変・再配布を無制限に許可するライセンスで、著作権表示はフォント内部の name テーブルに保持しています |
| `patch/Data/japanese.dat` | Pokémon Reborn の脚本の翻案物 |
| `patch/Graphics/**` | Reborn の画像を下敷きに文字を差し替えたもの |
| `Scripts/*.rb` | Reborn / Pokémon Essentials のソースの改変版 |
| `jp_translation/work/src/` | Reborn の英語スクリプト全文を含みます（リポジトリのみ。配布 zip には入りません） |

**ゲーム本体は同梱していません。** 再配布する場合もパッチのみとし、
Reborn 本体は公式サイトから入手してください。
公開にあたっては Reborn 開発チームへ確認することを勧めます（他言語翻訳の前例があります）。

---

## 変更履歴

[CHANGELOG.md](CHANGELOG.md)。バージョンは `v<対象のRebornバージョン>-ja.<パッチの版>`
の形式で、Reborn 本体が更新されたら対象バージョンの部分を上げて振り直します。

---

## 開発者向け

翻訳データの構造、書き戻しツール、Reborn 特有の落とし穴（表を通らない文字列、
絵に焼き込まれた文字、一度だけコンパイルされるデータなど）は
**[jp_translation/DEVELOPMENT.md](jp_translation/DEVELOPMENT.md)** にまとめてあります。

翻訳の方針と口調表は
[jp_translation/work/TRANSLATE_GUIDE.md](jp_translation/work/TRANSLATE_GUIDE.md)。
