# Pokémon Reborn 19.5.43 日本語化パッチ

> **有志による非公式のファンメイド翻訳パッチです。**
> 任天堂・株式会社ポケモン・ゲームフリーク・クリーチャーズ、および
> Pokémon Reborn 開発チームとは一切関係がありません。公式の日本語版でもありません。

Pokémon Reborn（RPG Maker XP / Pokémon Essentials, mkxp-z）を日本語で遊ぶためのパッチ。
ストーリー会話からバトルメッセージ、UI、フィールド効果の説明まで
**82,524 / 82,617 行（99.9%）** を翻訳してあります。

タイトル画面から英語 / 日本語をいつでも切り替えられます。英語に戻せば文章はすべて
元のまま表示されます（ゲーム全体のフォントだけは同梱のものに置き換わります）。

---

## 対象

| | |
|---|---|
| パッチのバージョン | **v19.5.43-ja.7** |
| 対象 | **Pokémon Reborn 19.5.43 専用** |
| 動作環境 | Windows 版 / Linux（AppImage）版 |
| 必要なもの | `mkxp.json` に `"patches": ["patch"]` があること（19.5.43 では標準で入っています） |

他のバージョンに当てないでください。マップIDと行インデックスに依存しているため、
別バージョンでは文章がずれます。

---

## 導入

### 1. ファイルをコピーする

Releases から `reborn-19.5.43-ja.7.zip` を取得し、ゲームのインストール先
（`Game.exe` / `Game.AppImage` のある場所）で展開します。中身は次のとおりで、
**同じ階層構造のまま**上書きされます。

```
patch/Data/japanese.dat                     翻訳データ
patch/Fonts/pokemonemerald.ttf              かな・漢字入りのフォント
patch/Graphics/Icons/ja/                    タイプアイコン 19枚
patch/Graphics/Pictures/PulseDex/ja/        パルス図鑑のページ 14枚
patch/Graphics/Pictures/Pokedex/ja/         図鑑のタイプバッジ 19枚
patch/Graphics/Pictures/Battle/ja/          バトルの行動選択ボタン
patch/Graphics/Pictures/Battle/typeeffect.png     タイプ相性のアイコン
patch/Graphics/Pictures/ja/                 状態異常バッジ（一覧用）
patch/Graphics/Pictures/Party/ja/           状態異常バッジ 6枚
patch/Graphics/Pictures/Pokegear/TimeWeather/ja/  「時間と天気」の背景

Scripts/Battle.rb              Scripts/OrgBattle.rb
Scripts/BattleData.rb          Scripts/PBIntl.rb
Scripts/BattleSwap.rb          Scripts/Party.rb
Scripts/Battle_Effects.rb      Scripts/PokedexScene.rb
Scripts/Battle_Inspect.rb      Scripts/PulseDex.rb
Scripts/Battle_Move.rb         Scripts/PurifyChamber.rb
Scripts/Battle_MoveEffects.rb  Scripts/Randomizer/RandomizerUtils.rb
Scripts/Battle_Scene.rb        Scripts/Reborn/FieldNoteCompiler.rb
Scripts/Battle_ZMove.rb        Scripts/Reborn/RebornPokegear.rb
Scripts/Battler.rb             Scripts/Reborn/RebornScripts.rb
Scripts/Controls.rb            Scripts/Reborn/Settings.rb
Scripts/DrawText.rb            Scripts/Reborn/TrainerSelect.rb
Scripts/Field.rb               Scripts/SpriteWindow.rb
Scripts/FieldNotes.rb          Scripts/Storage.rb
Scripts/Game_Map.rb            Scripts/Summary.rb
Scripts/ItemEffects.rb         Scripts/System.rb
Scripts/Items.rb               Scripts/TextEntry.rb
Scripts/Load.rb                Scripts/TimeWeather.rb
Scripts/Messages.rb            Scripts/Trainers.rb
Scripts/Options.rb             Scripts/Updater.rb
```

`patch/` 以下の10個と、`Scripts/` 以下の40ファイルです。
`patch/` はゲームが標準で読み込む差分フォルダなので、既存のファイルは消えません。

### 2. 言語を切り替える

ゲームを起動すると、タイトル画面に **`Language`** が増えています。
ここから「日本語」を選ぶと切り替わり、設定は保存されます。

初回起動時は英語で始まります。

---

## 元に戻す

書き換えたスクリプトを元に戻し、コピーした `patch/` 以下の10個を削除すれば元通りです。

改変前のスクリプトは**配布 zip には入っていません**。次のどちらかから入手してください。

- リポジトリの [`jp_translation/backup/19.5.43-scripts/`](jp_translation/backup/19.5.43-scripts)
- Reborn 公式の更新ファイル
  <https://www.rebornevo.com/downloads/rebornremote/Reborn_19.5/patch.zip>
  （ゲーム内のアップデータが使っているものと同じ。`Scripts/` 以下がそのまま入っています）

どちらも Reborn 19.5.43 の原本で、内容は同一です。

セーブデータは英語版と共通で、言語を切り替えても壊れません。

---

## 翻訳されている範囲

- ストーリー会話・イベント・NPCのセリフ（全マップ）
- ポケモン・わざ・とくせい・どうぐ・分類・タイプの名前（**公式日本語名**）
- わざ・とくせい・どうぐの説明文、図鑑の説明文
- バトル中のメッセージ、わざ選択画面、フィールド効果の発動メッセージ
- トレーナーの戦闘前後のセリフ（本編・バトルタワー系とも）
- ポケモン詳細画面、手持ち、バッグ、PCボックス、オプション、セーブ画面
- ポケモン図鑑（分類・図鑑説明・タイプバッジ）
- ポケギア（フィールドノート、パルス図鑑、タウンマップ、時間と天気）
- エリア移動時の地名表示
- タイプアイコン、パルス図鑑のページ、バトルの行動選択ボタン、状態異常バッジ（文字が絵に描き込まれているため画像を作り直しています）

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

## 独自の改善

翻訳以外に、本パッチが独自に加えている変更です。**ゲームバランスには影響しません。**

| 変更 | 内容 |
|---|---|
| 技を忘れさせる画面で **← / →** を押すと「つよさ」ページを確認できる | 覚えさせる技を選ぶときに、そのポケモンが物理寄りか特殊寄りかを確認できます。つよさページからは決定できないため、誤って技を消す心配はありません |
| ポケギアの**地方マップに地名の一覧**を追加 | 下記を参照 |
| バトル中に**タイプ相性のアイコン**を表示（既定は無効） | 下記を参照 |

つよさページの確認だけを無効にすることはできません。同じ `Scripts/Summary.rb` に
性格名・とくせい説明・出会った場所などの日本語化も入っているため、
書き戻すとポケモン詳細画面の翻訳ごと元に戻ります。

### 地方マップの地名一覧

**常に有効です。**ポケギアの「地方マップ」で、地図が左に寄り、右に**全54地名の一覧**が出ます。

本来の地方マップは、カーソルを1マスずつ動かして地名を読むしかありませんでした。
これが場所を確認する用途にはつらく、理由が2つあります。

- **カーソルが速すぎて細かく合わせられない。** 押した瞬間から連続で動き始め
  （キーリピートの待ちがない）、**毎秒10マス**進みます。横は15マスしかないので、
  端から端まで1.5秒で走り抜けてしまい、目的のマスで止めるのが難しい状態でした
- **地名を知っていても、地図のどこにあるかを探すのが大変。** 一覧が無いので、
  「アメトリン山はどのあたりか」を知るにはカーソルで総当たりするしかありませんでした

一覧を足すことで、この2つを両方とも回避できます。

- **一覧を ↑↓ で動かすと、地図のカーソルがその地点へ一発で飛びます。**
  探す必要がなくなります
- 逆に**地図を動かすと、一覧側でその場所の行が選ばれます。**
  今どこを見ているのかが名前で分かります
- **まだ行っていない場所はグレー**で表示されます
- **そらをとぶで飛べる場所には印**が付きます。そらをとぶの画面でも同じ一覧から選べます

地図カーソルを自由に動かす機能は残してあります。マス単位の地形や施設の説明を
読みたいときは、これまでどおり十字キーで動かせます。

操作は画面右上に常時表示されます。

| 場面 | キー |
|---|---|
| 一覧（開いた直後） | **↑↓** 選択 / **←** 地図へ / **C** とぶ（そらをとぶの画面） |
| 地図 | **十字キー** で移動 / **B** 一覧へ戻る |

この画面だけ元に戻したい場合は、[元に戻す](#元に戻す)の入手先から
`Scripts/RegionMap.rb` だけを差し戻してください。このファイルには翻訳そのものは
入っておらず、地名は `patch/Data/japanese.dat` から引かれるため、
**日本語表示を失わずに**本来の地方マップに戻せます。

### タイプ相性のアイコン

**既定では無効です。**パスワード入力画面で **`aishou`** と入力すると有効になり、
もう一度入力すると無効に戻ります。有効にするとパスワード一覧に `> aishou` と表示されます。

有効にすると、**バトルの技選択ボタン**と、**交代画面から開いた「つよさ」のわざページ**に、
相手への通り方が記号で出ます。

| 記号 | 倍率 |
|---|---|
| ★ | 4倍 |
| ◎ | 2倍 |
| ○ | 等倍 |
| △ | 1/2倍 |
| ▼ | 1/4倍 |
| × | 効果なし |

- 変化技には付きません。固定ダメージ技（サイコウェーブなど）は効果なしのときだけ出ます
- **とくせいは考慮しません。**「ふゆう」のポケモンにじめん技を撃っても ○ や ◎ が出ます。
  本家も見たことのないとくせいは教えてくれないため、相性表だけを見る基準に揃えています
- フィールドによるタイプ変化と、相性表を書き換えるフィールドは反映されます
- ダブルバトルでは正面の相手が基準です。技を選ぶ時点では対象が決まっていないためです

原作の難易度を変えたくない方は、有効にしないでください。

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
- ポケルスのバッジは `PKRS` のままです（44pxの枠に「ポケルス」の4文字が収まらず、
  読めるサイズになりませんでした）
- 表示崩れが残っている可能性があります。長い訳文は自動で縮小・改行するように
  していますが、全画面を網羅的に確認したわけではありません

見つけた場合は [Issues](https://github.com/Xephy/reborn-19.5.43-ja/issues) へ、
**その画面のスクリーンショットと場所**を添えて報告してもらえると助かります。

---

## 権利・免責

このパッチは**ファンによる非公式の翻訳**です。営利目的ではありません。

- **ポケモン**は任天堂・株式会社ポケモン・ゲームフリーク・クリーチャーズの登録商標です。
  訳文にはポケモン・わざ・とくせい・どうぐの**公式日本語名**を使用していますが、
  これらの権利は上記各社に帰属します。本パッチは各社が公認・提供するものではありません
- **Pokémon Reborn** は Amethyst 氏および Reborn 開発チームによるファンゲームです。
  本パッチはその翻訳であり、開発チームが制作・公認したものではありません。
  **翻訳に関する不具合は Reborn 公式フォーラムへ報告しないでください。**
  誤訳・表示崩れの報告は
  [このリポジトリの Issues](https://github.com/Xephy/reborn-19.5.43-ja/issues) へお願いします
- 本パッチの利用によって生じたいかなる損害についても責任を負いません

同梱物の内訳:

| | |
|---|---|
| `patch/Fonts/pokemonemerald.ttf` | 2つのフォントの合成。仮名・漢字は itouhiro 氏の **PixelMplus 20130602**（M+ BITMAP FONTS 由来、**M+ FONT LICENSE**）。英数字は Reborn 標準フォントと同一で、aztecwarrior28 氏が FontStruct で作成した **CC BY-SA 3.0** のもの。継承条件に従い、本フォントも CC BY-SA 3.0 で再配布します。詳細は [NOTICE](NOTICE) |
| `patch/Data/japanese.dat` | Pokémon Reborn の脚本の翻案物 |
| `patch/Graphics/**` | Reborn の画像を下敷きに文字を差し替えたもの |
| `Scripts/*.rb` | Reborn / Pokémon Essentials のソースの改変版 |
| `jp_translation/work/src/` | Reborn の英語スクリプト全文を含みます（リポジトリのみ。配布 zip には入りません） |
| `jp_translation/backup/` | Reborn のオリジナルファイルの控え（元に戻すため。リポジトリのみ） |

自作部分（`jp_translation/tools/`）は MIT ライセンスです。
それ以外の帰属は **[NOTICE](NOTICE)** にまとめてあります。

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
