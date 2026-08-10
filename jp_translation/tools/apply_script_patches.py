# -*- coding: utf-8 -*-
"""Re-apply the Japanese-localization edits to the game's Ruby scripts.

The in-game updater extracts patch.zip over the game root (Updater.rb:321),
deleting and replacing every file the archive contains, so any edit made to a
base script is lost on update. Keeping the edits here as declarative
old -> new replacements makes them re-appliable to a freshly updated tree
instead of depending on stale file backups.

Each edit is idempotent: if `new` is already present the edit is reported as
already applied. If neither `old` nor `new` matches, the edit FAILS LOUDLY —
that means upstream changed the surrounding code and the edit needs review
rather than being silently skipped.

    python3 jp_translation/tools/apply_script_patches.py --check   # report only
    python3 jp_translation/tools/apply_script_patches.py           # apply

After an update, also re-run the translation pipeline so array indices that
shifted are rebuilt from the English source text:

    python3 jp_translation/tools/extract.py
    python3 jp_translation/tools/apply_glossary.py
    python3 jp_translation/tools/build_descriptions.py
    python3 jp_translation/tools/merge_speech.py jp_translation/work/speech_ja_*.json
    python3 jp_translation/tools/build.py
"""
import argparse
import os
import sys

HELPERS_FILE = 'jp_translation/tools/patches/drawtext_helpers.rb'

# The wrap loop in getFormattedTextFast and getFormattedText (two identical sites).
WRAP_OLD = '''    isspace = (textchars[position][/\\s/] || isWaitChar(textchars[position])) ? true : false
    if hadspace && !isspace
      # set last word to here
      lastword[0] = characters.length
      lastword[1] = x
      hadspace = false
      hadnonspace = true
    elsif isspace
      hadspace = true
    end
'''
WRAP_NEW = WRAP_OLD + '''    if !isspace && position > 0 &&
       pbJaCanBreakBefore?(textchars[position - 1], textchars[position])
      # Japanese: this character boundary is a legal break point
      lastword[0] = characters.length
      lastword[1] = x
      hadspace = false
      hadnonspace = true
    end
'''

# getLineBrokenChunks: split each whitespace-delimited word into JP pieces.
CHUNK_OLD = '''      word = words[i]
      if word && word != ""
        textSize = bitmap.text_size(word)
        textwidth = textSize.width
        if x > 0 && x + textwidth >= width - 2
          x = 0
          y += 32 # (textheight==0) ? bitmap.text_size("X").height : textheight
          textheight = 0
        end
        textheight = 32 # [textheight,textSize.height].max
        ret.push([word, x, y, textwidth, textheight, color])
        x += textwidth
        dims[0] = x if dims && dims[0] < x
      end
'''
CHUNK_NEW = '''      word = words[i]
      if word && word != ""
        # Japanese words carry no spaces, so break them into line-startable
        # pieces first. ASCII words yield a single piece and behave as before.
        for chunk in pbJaSplitChunks(word)
          textSize = bitmap.text_size(chunk)
          textwidth = textSize.width
          if x > 0 && x + textwidth >= width - 2
            x = 0
            y += 32 # (textheight==0) ? bitmap.text_size("X").height : textheight
            textheight = 0
          end
          textheight = 32 # [textheight,textSize.height].max
          ret.push([chunk, x, y, textwidth, textheight, color])
          x += textwidth
          dims[0] = x if dims && dims[0] < x
        end
      end
'''


def build_edits():
    """Each edit is (path, description, old, new, marker).

    `marker` decides whether the edit is already applied:
      * a string   -> applied when that string is present (normal edits)
      * None       -> applied when `old` is ABSENT (deletions, where the
                      resulting text is too generic to test for)
    Getting this wrong is not harmless: an edit whose `new` is something like
    "    ]" matches almost any Ruby file, so it silently reports "already"
    and the real change never lands.
    """
    helpers = open(HELPERS_FILE, encoding='utf-8').read()
    anchor = 'def getLineBrokenChunks(bitmap, value, width, dims, plain = false)'
    return [
        ('Scripts/DrawText.rb', '日本語改行ヘルパーを追加',
         anchor, helpers.rstrip('\n') + '\n\n' + anchor, 'pbJaSplitChunks'),
        ('Scripts/DrawText.rb', '折り返しループ2ヶ所に日本語の分割点を追加',
         WRAP_OLD, WRAP_NEW, 'Japanese: this character boundary'),
        ('Scripts/DrawText.rb', 'getLineBrokenChunks を日本語対応に',
         CHUNK_OLD, CHUNK_NEW, 'for chunk in pbJaSplitChunks(word)'),

        # 19.5.43 refactored the language handling into pbSetLanguage, which
        # startup calls on every launch (ClientData.rb#startup). Left alone it
        # asks the language question at each start and never stores the answer.
        ('Scripts/System.rb', '起動毎の言語選択を止め、選択を保存する',
         '''def pbSetLanguage
  if LANGUAGES.length >= 2
    $Settings.language = pbChooseLanguage
    pbLoadMessages("Data/" + LANGUAGES[$Settings.language][1])
  end
end''',
         '''def pbSetLanguage
  if LANGUAGES.length >= 2
    # The stock code called pbChooseLanguage here unconditionally, so the
    # language question appeared on every launch and the answer was never
    # saved. Fall back to the first entry and let the player switch from the
    # title screen's "Language" command (Scripts/Load.rb), which persists it.
    if !$Settings.language || $Settings.language < 0 ||
       $Settings.language >= LANGUAGES.length
      $Settings.language = 0
      saveSettings
    end
    pbLoadMessages("Data/" + LANGUAGES[$Settings.language][1])
  end
end''',
         # must be a substring that survives on ONE line — the comment wraps
         '# language question appeared on every launch'),

        ('Scripts/Load.rb', '言語選択を保存',
         '''        $Settings.language = pbChooseLanguage
        pbLoadMessages("Data/" + LANGUAGES[$Settings.language][1])''',
         '''        $Settings.language = pbChooseLanguage
        saveSettings # persist the choice across restarts
        pbLoadMessages("Data/" + LANGUAGES[$Settings.language][1])''',
         'saveSettings # persist the choice across restarts'),

        ('Scripts/PBIntl.rb', 'patch/Data/ のメッセージファイルを解決',
         '''  def loadMessageFile(filename)
    begin
      Kernel.pbRgssOpen(filename, "rb") { |f|''',
         '''  def loadMessageFile(filename)
    begin
      # Kernel.pbRgssOpen falls back to a plain File.open when there is no
      # Game.rgssad, and plain File.open does NOT see mkxp's "patches"
      # directories (see the fileExists? comment in Scripts/ScriptLoader.rb).
      # Message files shipped as a mod therefore have to be resolved by hand.
      if !safeExists?(filename) && safeExists?("patch/" + filename)
        filename = "patch/" + filename
      end
      Kernel.pbRgssOpen(filename, "rb") { |f|''',
         'Message files shipped as a mod'),

        ('Scripts/Reborn/Settings.rb', 'LANGUAGES に日本語を追加',
         '''LANGUAGES = [
  #  ["English","english.dat"],
  #  ["Deutsch","deutsch.dat"]
]''',
         '''LANGUAGES = [
  ["English", "messages.dat"],
  ["日本語", "japanese.dat"]
]''',
         '["日本語", "japanese.dat"]'),

        ('Scripts/SpriteWindow.rb', 'pbDrawTextFitted を追加',
         'def pbDrawImagePositions(bitmap, textpos)',
         '''# Draws a single left-aligned string into a fixed-width slot, stepping the font
# size down only when the string would otherwise run past `maxwidth`.
# Japanese names are about twice as wide per character as the English they
# replace, so slots sized for English can overflow; anything that already fits
# is drawn untouched at the current size.
def pbDrawTextFitted(bitmap, text, x, y, maxwidth, baseColor, shadowColor, minsize = 24)
  oldsize = bitmap.font.size
  while bitmap.font.size > minsize && bitmap.text_size(text).width > maxwidth
    bitmap.font.size = bitmap.font.size - 1
  end
  pbDrawTextPositions(bitmap, [[text, x, y, 0, baseColor, shadowColor]])
  bitmap.font.size = oldsize
end

def pbDrawImagePositions(bitmap, textpos)''',
         'def pbDrawTextFitted'),

        # marker=None: this one deletes a line, and the text left behind ("    ]")
        # is far too common to test for. Applied == the line is gone.
        ('Scripts/Summary.rb', '特性名をインライン描画から外す',
         '      [abilityname, 362, 284, 0, DarkBase, DarkShadow],\n',
         '', None),
        ('Scripts/DrawText.rb', 'drawTextExFitted を追加',
         '''def drawTextEx(bitmap, x, y, width, numlines, text, baseColor, shadowColor)
  normtext = getLineBrokenChunks(bitmap, text, width, nil, true)
  renderLineBrokenChunksWithShadow(bitmap, x, y, normtext, numlines * 32, baseColor, shadowColor)
end''',
         '''def drawTextEx(bitmap, x, y, width, numlines, text, baseColor, shadowColor)
  normtext = getLineBrokenChunks(bitmap, text, width, nil, true)
  renderLineBrokenChunksWithShadow(bitmap, x, y, normtext, numlines * 32, baseColor, shadowColor)
end

# Same as drawTextEx, but steps the font size down until the wrapped text fits
# in `numlines`. renderLineBrokenChunksWithShadow silently clips whatever runs
# past that height, so a slot sized for English quietly loses the tail of a
# longer translation instead of showing it. The ability description on the
# summary screen is only 282px x 2 lines, which even some English entries
# overflow; Japanese ones are wider still.
def drawTextExFitted(bitmap, x, y, width, numlines, text, baseColor, shadowColor, minsize = 24)
  oldsize = bitmap.font.size
  maxheight = numlines * 32
  dims = [0, 0]
  normtext = getLineBrokenChunks(bitmap, text, width, dims, true)
  # Line height is a fixed 32px regardless of font size, so a smaller font
  # means fewer wrapped lines, which is exactly what has to shrink here.
  while bitmap.font.size > minsize && dims[1] > maxheight
    bitmap.font.size = bitmap.font.size - 2
    dims = [0, 0]
    normtext = getLineBrokenChunks(bitmap, text, width, dims, true)
  end
  renderLineBrokenChunksWithShadow(bitmap, x, y, normtext, maxheight, baseColor, shadowColor)
  bitmap.font.size = oldsize
end''',
         'def drawTextExFitted'),

        ('Scripts/Summary.rb', '特性説明を縮小対応で描画',
         '    drawTextEx(overlay, 224, 316, 282, 2, abilitydesc, DarkBase, DarkShadow)',
         '    drawTextExFitted(overlay, 224, 316, 282, 2, abilitydesc, DarkBase, DarkShadow)',
         'drawTextExFitted(overlay, 224, 316'),

        ('Scripts/Summary.rb', '特性名を縮小対応で描画 (x=328, 178px)',
         '''    pbDrawTextPositions(overlay, textpos)
    drawTextEx(overlay, 224, 316, 282, 2, abilitydesc, DarkBase, DarkShadow)''',
         '''    pbDrawTextPositions(overlay, textpos)
    # The ability name is drawn on its own so the font can step down when a
    # Japanese name is wider than the slot English left room for.
    pbDrawTextFitted(overlay, abilityname, 328, 284, 178, DarkBase, DarkShadow)
    drawTextEx(overlay, 224, 316, 282, 2, abilitydesc, DarkBase, DarkShadow)''',
         'pbDrawTextFitted(overlay, abilityname'),
    ]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true', help='report without writing')
    a = ap.parse_args()

    if not os.path.isdir('Scripts'):
        sys.exit('run this from the game root (no Scripts/ here)')
    if not os.path.exists(HELPERS_FILE):
        sys.exit(f'missing {HELPERS_FILE}')

    applied = already = failed = 0
    cache = {}

    for path, desc, old, new, marker in build_edits():
        if path not in cache:
            if not os.path.exists(path):
                print(f'  MISSING FILE  {path}')
                failed += 1
                continue
            cache[path] = open(path, encoding='utf-8').read()
        s = cache[path]

        done = (old not in s) if marker is None else (marker in s)
        if done:
            print(f'  already   {path}: {desc}')
            already += 1
        elif old in s:
            cache[path] = s.replace(old, new)
            print(f'  APPLY     {path}: {desc}')
            applied += 1
        else:
            print(f'  ** FAIL   {path}: {desc}')
            print('              元のコードも適用後のコードも見つかりません。')
            print('              本家側でこの箇所が変わっています。手で確認してください。')
            failed += 1

    if not a.check and applied:
        for path, text in cache.items():
            open(path, 'w', encoding='utf-8').write(text)

    print(f'\n適用 {applied} / 適用済み {already} / 失敗 {failed}')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
