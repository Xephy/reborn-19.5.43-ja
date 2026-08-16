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

Everything this run touches is passed through `ruby -c` BEFORE any of it is
written. A script that does not parse stops Reborn from booting entirely, so a
bad edit aborts the whole run rather than leaving a half-patched tree. The pass
is skipped with a note when no ruby is on PATH; see DEVELOPMENT.md for the
sudo-free install.

    python3 jp_translation/tools/apply_script_patches.py --check   # report only
    python3 jp_translation/tools/apply_script_patches.py           # apply
    RUBY=/path/to/ruby python3 jp_translation/tools/apply_script_patches.py

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
import shutil
import subprocess
import sys
import tempfile

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


# `_INTL("... #{expr} ...")` — Ruby expands #{} BEFORE _INTL sees the string, so
# the key the compiler registered (with the literal "#{expr}" in it) can never
# match the key looked up at runtime. See DEVELOPMENT.md "2d". The fix is always
# the same: move the expression out into a {n} argument. The English output is
# byte-identical; only the lookup key changes.
#
# The Japanese for these already existed in 22_script_texts.jsonl keyed by the
# unreachable #{} form; 22h_interp_keys.jsonl carries it over to the new keys.
INTERP_EDITS = [
    ('Scripts/Battler.rb',
     '''_INTL("#{target.pbThis}'s Red Card activates!")''',
     '''_INTL("{1}'s Red Card activates!", target.pbThis)'''),
    ('Scripts/Battler.rb',
     '''_INTL("#{target.pbThis}'s Eject Button activates!")''',
     '''_INTL("{1}'s Eject Button activates!", target.pbThis)'''),
    ('Scripts/Battler.rb',
     '''_INTL("#{target.pbThis}'s Eject Pack activates!")''',
     '''_INTL("{1}'s Eject Pack activates!", target.pbThis)'''),
    # two sites (Eject Button / Eject Pack), both on the Colosseum field
    ('Scripts/Battler.rb',
     '''_INTL("But #{target.pbThis} cannot retreat.")''',
     '''_INTL("But {1} cannot retreat.", target.pbThis)'''),
    ('Scripts/Battler.rb',
     '''_INTL("#{user.pbThis}'s Eject Pack activates!")''',
     '''_INTL("{1}'s Eject Pack activates!", user.pbThis)'''),
    ('Scripts/Battler.rb',
     '''_INTL("But #{user.pbThis} cannot retreat.")''',
     '''_INTL("But {1} cannot retreat.", user.pbThis)'''),
    ('Scripts/Battler.rb',
     '''_INTL("The Blunder Policy harshly lowered #{user.pbThis}'s Speed!")''',
     '''_INTL("The Blunder Policy harshly lowered {1}'s Speed!", user.pbThis)'''),
    ('Scripts/Battler.rb',
     '''_INTL("The Blunder Policy sharply raised #{user.pbThis}'s Speed!")''',
     '''_INTL("The Blunder Policy sharply raised {1}'s Speed!", user.pbThis)'''),
    ('Scripts/Battler.rb',
     '''_INTL("The Throat Spray lowered #{user.pbThis}'s Special Attack!")''',
     '''_INTL("The Throat Spray lowered {1}'s Special Attack!", user.pbThis)'''),
    ('Scripts/Battler.rb',
     '''_INTL("The Throat Spray raised #{user.pbThis}'s Special Attack!")''',
     '''_INTL("The Throat Spray raised {1}'s Special Attack!", user.pbThis)'''),

    ('Scripts/Battle_MoveEffects.rb',
     '''_INTL("Congratulations, #{$Trainer.name}!")''',
     '''_INTL("Congratulations, {1}!", $Trainer.name)'''),
    ('Scripts/Battle_MoveEffects.rb',
     '''_INTL("The Aroma Veil protects #{opponent.pbThis} from infatuation!")''',
     '''_INTL("The Aroma Veil protects {1} from infatuation!", opponent.pbThis)'''),
    # two sites: Taunt and Torment's second guard
    ('Scripts/Battle_MoveEffects.rb',
     '''_INTL("The Aroma Veil protects #{opponent.pbThis} from being taunted!")''',
     '''_INTL("The Aroma Veil protects {1} from being taunted!", opponent.pbThis)'''),
    ('Scripts/Battle_MoveEffects.rb',
     '''_INTL("The Aroma Veil protects #{opponent.pbThis} from torment!")''',
     '''_INTL("The Aroma Veil protects {1} from torment!", opponent.pbThis)'''),
    ('Scripts/Battle_MoveEffects.rb',
     '''_INTL("The Aroma Veil protects #{opponent.pbThis} from disabling!")''',
     '''_INTL("The Aroma Veil protects {1} from disabling!", opponent.pbThis)'''),
    # "being blocked" is Heal Block (PokeBattle_Move_0BB), not Block
    ('Scripts/Battle_MoveEffects.rb',
     '''_INTL("The Aroma Veil protects #{opponent.pbThis} from being blocked!")''',
     '''_INTL("The Aroma Veil protects {1} from being blocked!", opponent.pbThis)'''),
    ('Scripts/Battle_MoveEffects.rb',
     '''_INTL("The Aroma Veil protects #{opponent.pbThis} from the encore!")''',
     '''_INTL("The Aroma Veil protects {1} from the encore!", opponent.pbThis)'''),
    # This key already exists and is translated (five other sites use it), so
    # the replacement text alone is NOT a usable marker — it is already in the
    # file and the edit would report "already" without ever landing. The
    # enclosing `if` is what makes this site unique.
    ('Scripts/Battle_MoveEffects.rb',
     '''if pbMoveFailed(attacker, opponent)
      @battle.pbDisplay(_INTL("#{opponent.pbThis} protected itself!"))''',
     '''if pbMoveFailed(attacker, opponent)
      @battle.pbDisplay(_INTL("{1} protected itself!", opponent.pbThis))'''),
    ('Scripts/Battle_MoveEffects.rb',
     '''_INTL("It doesn't affect foe #{opponent.pbThis}!")''',
     '''_INTL("It doesn't affect foe {1}!", opponent.pbThis)'''),
    ('Scripts/Battle_MoveEffects.rb',
     '''_INTL("The Room Service raised #{i.pbThis}'s Speed!")''',
     '''_INTL("The Room Service raised {1}'s Speed!", i.pbThis)'''),
    ('Scripts/Battle_MoveEffects.rb',
     '''_INTL("The Room Service lowered #{i.pbThis}'s Speed!")''',
     '''_INTL("The Room Service lowered {1}'s Speed!", i.pbThis)'''),

    ('Scripts/ItemEffects.rb',
     '''_INTL("Do you want to swap #{pokemon.name}'s #{stats[cmd]} stat with its #{stats[cmd2]} stat?")''',
     '''_INTL("Do you want to swap {1}'s {2} stat with its {3} stat?", pokemon.name, stats[cmd], stats[cmd2])'''),
    ('Scripts/ItemEffects.rb',
     '''_INTL("Do you want to boost #{pokemon.name}'s #{stats[cmd]} stat?")''',
     '''_INTL("Do you want to boost {1}'s {2} stat?", pokemon.name, stats[cmd])'''),

    # The box-sort prompt picked its wording with a ternary INSIDE the _INTL
    # literal, so neither branch could ever be looked up. Split into two calls.
    ('Scripts/Storage.rb',
     '''    command = pbShowCommands(_INTL("How would you like to sort\\n#{minbox == maxbox ? $PokemonStorage[minbox].name : "{1} to {2}"}?", $PokemonStorage[minbox].name, $PokemonStorage[maxbox].name), commands)''',
     '''    prompt = if minbox == maxbox
               _INTL("How would you like to sort\\n{1}?", $PokemonStorage[minbox].name)
             else
               _INTL("How would you like to sort\\n{1} to {2}?",
                     $PokemonStorage[minbox].name, $PokemonStorage[maxbox].name)
             end
    command = pbShowCommands(prompt, commands)'''),
]


# --- Region Map: map on the left, place list on the right -------------------
# Order matters: the MAPX/MAPY substitutions must run after the constants block
# is in place but before the edits whose `old` text already contains MAPX/MAPY.
RM = 'Scripts/RegionMap.rb'
REGIONMAP_EDITS = [
    ('レイアウト定数を追加', RM,
     """  SQUAREWIDTH  = 16
  SQUAREHEIGHT = 16""",
     """  SQUAREWIDTH  = 16
  SQUAREHEIGHT = 16

  # Map on the left, place list on the right. The stock screen centred Map.png
  # (240x304) on a 512x384 screen and left 136px unused on either side, so the
  # list fits without shrinking the map.
  MAPX = 8
  MAPY = 40
  LISTX = 256
  LISTY = 40
  LISTWIDTH = 248
  LISTHEIGHT = 304
  # Places the player has not reached are listed but dimmed. true drops them.
  LISTHIDEUNVISITED = false""",
     'LISTHIDEUNVISITED = false'),

    ('地図の横位置を MAPX に (6ヶ所)', RM,
     '(Graphics.width - @sprites["map"].bitmap.width) / 2', 'MAPX',
     '@sprites["map"].x += MAPX'),
    ('地図の縦位置を MAPY に (6ヶ所)', RM,
     '(Graphics.height - @sprites["map"].bitmap.height) / 2', 'MAPY',
     '@sprites["map"].y += MAPY'),

    ('下部スプライトに操作ヒント欄を追加', RM,
     """    @mapdetails = ""
    @nonests = false""",
     """    @mapdetails = ""
    # Control hint, drawn top-right. Only the Region Map sets it; every other
    # user of this sprite (the Pokedex nest view) leaves it empty.
    @hint = ""
    @nonests = false""",
     '@hint = ""'),

    ('操作ヒントの setter', RM,
     """  def mapdetails=(value) # From Wichu
    if @mapdetails != value
      @mapdetails = value
      refresh
    end
  end""",
     """  def mapdetails=(value) # From Wichu
    if @mapdetails != value
      @mapdetails = value
      refresh
    end
  end

  def hint=(value)
    if @hint != value
      @hint = value
      refresh
    end
  end""",
     'def hint=(value)'),

    ('操作ヒントを右上に描画', RM,
     """      [@mapdetails, Graphics.width - 16, 354, 1, Color.new(248, 248, 248), Color.new(0, 0, 0)]
    ]""",
     """      [@mapdetails, Graphics.width - 16, 354, 1, Color.new(248, 248, 248), Color.new(0, 0, 0)],
      [@hint, Graphics.width - 16, -2, 1, Color.new(192, 208, 224), Color.new(0, 0, 0)]
    ]""",
     '[@hint, Graphics.width - 16, -2, 1,'),

    ('地名一覧ウィンドウのクラスを追加', RM,
     'class PokemonRegionMapScene',
     """# The place list on the Region Map. Places the player has not set foot in are
# drawn dimmed, and the mapFly marker is put on the rows that can be flown to,
# so one list doubles as an index of the region and a fly menu.
class Window_RegionPlaceList < Window_CommandPokemon
  attr_accessor :dimmed
  attr_accessor :flyable

  DIMCOLOR = Color.new(144, 144, 152)
  # Reserved on EVERY row so names wrap at the same width whether or not the
  # place can be flown to. mapFly's 32x32 frame is only inked in its middle
  # 20x20, so just that part is blitted, 4px clear on each side of it.
  ICONWIDTH = 28
  # 248 wide - 32 window border - 16 selection arrow - ICONWIDTH = 172px for
  # the name. At the system font's 36px a Japanese glyph is 24px wide, so
  # anything past 7 characters has to step down; 20 fits 12.
  MINFONTSIZE = 20

  def drawItem(index, count, rect)
    # Unconditionally, not `if @starting` like the parent: refresh can hand
    # back a freshly allocated bitmap, and the loop below needs to start from
    # a known font size on every row rather than from the previous row's.
    pbSetSystemFont(self.contents)
    rect = drawCursor(index, rect)
    text = @commands[index]
    textwidth = rect.width - ICONWIDTH
    while self.contents.font.size > MINFONTSIZE &&
          self.contents.text_size(text).width > textwidth
      self.contents.font.size -= 1
    end
    color = (@dimmed && @dimmed[index]) ? DIMCOLOR : self.baseColor
    pbDrawShadowText(self.contents, rect.x, rect.y, textwidth, rect.height,
                     text, color, self.shadowColor)
    return if !@flyable || !@flyable[index]

    pbDrawImagePositions(
      self.contents,
      [["Graphics/Pictures/mapFly", rect.x + rect.width - 24, rect.y + 6, 6, 6, 20, 20]]
    )
  end
end

class PokemonRegionMapScene""",
     'class Window_RegionPlaceList'),

    ('一覧の構築・同期・ヒント更新メソッドを追加', RM,
     """  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end""",
     """  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end

  def pbCellX(x)
    return MAPX - SQUAREWIDTH / 2 + (x * SQUAREWIDTH)
  end

  def pbCellY(y)
    return MAPY - SQUAREHEIGHT / 2 + (y * SQUAREHEIGHT)
  end

  # Which town-map cells the player has actually stood on. Every game map
  # declares where it sits on the town map, so this covers the 29 places that
  # have no fly point at all. (MapSize is never set in Reborn's metadata, so
  # one map contributes exactly one cell.)
  def pbReachedCells(mapindex)
    reached = {}
    $cache.mapdata.each_with_index { |data, mapid|
      next if !data || !$PokemonGlobal.visitedMaps[mapid]

      mp = data.MapPosition
      next if !mp || mp[0] != mapindex

      reached[[mp[1], mp[2]]] = true
    }
    return reached
  end

  # One row per place name. :x/:y is where the cursor parks - the fly cell when
  # there is one, otherwise the first cell the name occupies.
  def pbBuildPlaceList(mapindex)
    @places = []
    return if !Reborn

    reached = pbReachedCells(mapindex)
    byname = {}
    $cache.town_map.each { |key, value|
      next if !value.is_a?(TownMapData)
      next if value.region != mapindex

      entry = byname[value.name]
      if !entry
        entry = { :name => value.name, :x => value.pos[0], :y => value.pos[1],
                  :fly => nil, :canfly => false, :visited => false }
        byname[value.name] = entry
        @places.push(entry)
      end
      entry[:visited] = true if reached[[value.pos[0], value.pos[1]]]
      next if value.flyData.nil? || value.flyData.empty?

      # MapPosition and the town map disagree by a cell here and there (Tanzan
      # Cove is at [10,9] but map 232 reports [10,10]), so a reachable fly
      # point also counts as having been there.
      entry[:fly] = value.flyData
      entry[:x] = value.pos[0]
      entry[:y] = value.pos[1]
      if $PokemonGlobal.visitedMaps[value.flyData[0]]
        entry[:canfly] = true
        entry[:visited] = true
      end
    }
    @places.reject! { |v| !v[:visited] } if LISTHIDEUNVISITED
    @places.sort_by! { |v| pbGetMessageFromHash(MessageTypes::PlaceNames, v[:name]) }
  end

  def pbPlaceNames
    return @places.map { |v| pbGetMessageFromHash(MessageTypes::PlaceNames, v[:name]) }
  end

  # Which side the D-pad drives. The list is what the screen is for, so it
  # holds focus on open and the free map cursor is the sub-mode.
  def pbSetFocus(focus, mode = 0)
    @focus = focus
    if @sprites["placelist"]
      @sprites["placelist"].active = (focus == :list)
      @listindex = @sprites["placelist"].index
    end
    pbRefreshHint(mode)
  end

  def pbRefreshHint(mode = 0)
    return if !@sprites["mapbottom"]

    if !@sprites["placelist"]
      @sprites["mapbottom"].hint = ""
    elsif @focus == :list
      @sprites["mapbottom"].hint = (mode == 1) ?
        _INTL("←:Map / ↑↓:Select / C:Fly") : _INTL("←:Map / ↑↓:Select")
    else
      @sprites["mapbottom"].hint = _INTL("B:List / Arrows:Move")
    end
  end

  # Cursor -> list. Matched on the place name rather than the exact cell, so
  # anywhere inside a multi-cell area keeps that area's row selected.
  def pbSyncListToCursor
    return if !@sprites["placelist"] || @places.nil? || @places.empty?

    here = @mapdata[[@mapX, @mapY]]
    return if !here

    index = @places.index { |v| v[:name] == here.name }
    return if !index || index == @sprites["placelist"].index

    @sprites["placelist"].index = index
    @listindex = index
  end

  # List -> cursor.
  def pbSyncCursorToList
    return if !@sprites["placelist"] || @places.nil?

    place = @places[@sprites["placelist"].index]
    return if !place

    @mapX = place[:x]
    @mapY = place[:y]
    @sprites["cursor"].x = pbCellX(@mapX)
    @sprites["cursor"].y = pbCellY(@mapY)
  end""",
     'def pbReachedCells(mapindex)'),

    ('一覧ウィンドウを生成し、初期フォーカスを一覧にする', RM,
     """    @sprites["cursor"].x = -SQUAREWIDTH / 2 + (@mapX * SQUAREWIDTH) + MAPX
    @sprites["cursor"].y = -SQUAREHEIGHT / 2 + (@mapY * SQUAREHEIGHT) + MAPY
    @changed = false""",
     """    @sprites["cursor"].x = -SQUAREWIDTH / 2 + (@mapX * SQUAREWIDTH) + MAPX
    @sprites["cursor"].y = -SQUAREHEIGHT / 2 + (@mapY * SQUAREHEIGHT) + MAPY
    @focus = :map
    @listindex = -1
    pbBuildPlaceList(mapindex)
    if !@places.empty?
      @sprites["placelist"] = Window_RegionPlaceList.newWithSize(
        pbPlaceNames, LISTX, LISTY, LISTWIDTH, LISTHEIGHT, @viewport
      )
      @sprites["placelist"].dimmed = @places.map { |v| !v[:visited] }
      @sprites["placelist"].flyable = @places.map { |v| v[:canfly] }
      @sprites["placelist"].index = 0
      @sprites["placelist"].refresh
      pbSyncListToCursor
    end
    pbSetFocus(@sprites["placelist"] ? :list : :map, mode)
    @changed = false""",
     'Window_RegionPlaceList.newWithSize('),

    ('一覧にフォーカスがある間の操作', RM,
     """      @sprites["mapbottom"].maplocation = pbGetMapLocation(@mapX, @mapY)
      @sprites["mapbottom"].mapdetails = pbGetMapDetails(@mapX, @mapY)
      ox = 0
      oy = 0""",
     """      @sprites["mapbottom"].maplocation = pbGetMapLocation(@mapX, @mapY)
      @sprites["mapbottom"].mapdetails = pbGetMapDetails(@mapX, @mapY)
      if @sprites["placelist"] && @focus == :list
        # pbUpdate already advanced the window's index for this frame.
        if @sprites["placelist"].index != @listindex
          @listindex = @sprites["placelist"].index
          pbSyncCursorToList
          pbPlayCursorSE
        end
        if Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
          pbSetFocus(:map, mode)
          pbPlayCursorSE
        elsif Input.trigger?(Input::B)
          break
        elsif Input.trigger?(Input::C) && mode == 1 # Choosing an area to fly to
          place = @places[@sprites["placelist"].index]
          if place && (place[:canfly] ||
             ($DEBUG && Input.press?(Input::CTRL) && place[:fly]))
            return place[:fly]
          end
          pbPlayBuzzerSE
        end
        next
      end
      ox = 0
      oy = 0""",
     'if @sprites["placelist"] && @focus == :list'),

    ('地図側で一覧を追従させる', RM,
     """      if ox != 0 || oy != 0
        @mapX += ox
        @mapY += oy
        xOffset = ox * SQUAREWIDTH
        yOffset = oy * SQUAREHEIGHT
        newX = @sprites["cursor"].x + xOffset
        newY = @sprites["cursor"].y + yOffset
      end""",
     """      if ox != 0 || oy != 0
        @mapX += ox
        @mapY += oy
        xOffset = ox * SQUAREWIDTH
        yOffset = oy * SQUAREHEIGHT
        newX = @sprites["cursor"].x + xOffset
        newY = @sprites["cursor"].y + yOffset
        pbSyncListToCursor # highlight the row for the area under the cursor
      end""",
     'pbSyncListToCursor # highlight the row'),

    ('地図側では B で一覧へ戻る', RM,
     """      if Input.trigger?(Input::B)
        if @editor && @changed""",
     """      if Input.trigger?(Input::B)
        # The free map cursor is a sub-mode of the list, so B backs out to the
        # list; B on the list closes the screen. The editor keeps its prompts.
        if @sprites["placelist"] && !@editor
          pbSetFocus(:list, mode)
          pbPlayCancelSE
          next
        end
        if @editor && @changed""",
     'pbSetFocus(:list, mode)'),
]


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
    edits = [
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

    # `new` doubles as the marker: each replacement text is unique, and a
    # replace() covers every site sharing the same literal (Eject Button and
    # Eject Pack both print "But ... cannot retreat.", Taunt and Torment both
    # print the Aroma Veil taunt line).
    edits += [(path, '#{} を {n} 引数に移す', old, new, new)
              for path, old, new in INTERP_EDITS]
    edits += [(path, desc, old, new, marker)
              for desc, path, old, new, marker in REGIONMAP_EDITS]
    return edits


def find_ruby():
    """A ruby that can parse the game's scripts, or None.

    Only `ruby -c` is ever run, so any 3.x parses these files the same way, but
    mkxp-z embeds 3.1 (x64-msvcrt-ruby310.dll) and matching it removes the last
    doubt. See DEVELOPMENT.md for the sudo-free install.
    """
    return os.environ.get('RUBY') or shutil.which('ruby')


def syntax_errors(ruby, path, text):
    """`ruby -c` the patched text. Returns the error output, or '' if it parses.

    The text is checked before it is written, so a broken edit never reaches
    the game: a syntax error in a script file stops Reborn from booting at all.
    """
    with tempfile.NamedTemporaryFile('w', suffix='.rb', encoding='utf-8',
                                     delete=False) as f:
        f.write(text)
        tmp = f.name
    try:
        r = subprocess.run([ruby, '-c', tmp], capture_output=True, text=True)
        if r.returncode == 0 and r.stdout.strip() == 'Syntax OK':
            return ''
        # ruby reports against the temp path; point at the real file instead
        return (r.stdout + r.stderr).replace(tmp, path).strip()
    finally:
        os.unlink(tmp)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true', help='report without writing')
    ap.add_argument('--no-syntax-check', action='store_true',
                    help='skip the ruby -c pass over the patched files')
    a = ap.parse_args()

    if not os.path.isdir('Scripts'):
        sys.exit('run this from the game root (no Scripts/ here)')
    if not os.path.exists(HELPERS_FILE):
        sys.exit(f'missing {HELPERS_FILE}')

    applied = already = failed = 0
    cache = {}
    edited = set()

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
            edited.add(path)
            print(f'  APPLY     {path}: {desc}')
            applied += 1
        else:
            print(f'  ** FAIL   {path}: {desc}')
            print('              元のコードも適用後のコードも見つかりません。')
            print('              本家側でこの箇所が変わっています。手で確認してください。')
            failed += 1

    # --- ruby -c over everything this run changed, BEFORE anything is written -
    broken = 0
    if edited and not a.no_syntax_check:
        ruby = find_ruby()
        if not ruby:
            print('\n  ruby が見つからないため構文検査を飛ばしました。')
            print('  導入方法は jp_translation/DEVELOPMENT.md「Ruby の構文検査」を参照。')
        else:
            print()
            for path in sorted(edited):
                err = syntax_errors(ruby, path, cache[path])
                if err:
                    print(f'  ** 構文エラー  {path}')
                    for line in err.split('\n'):
                        print(f'                 {line}')
                    broken += 1
                else:
                    print(f'  Syntax OK  {path}')

    if broken:
        # Nothing is written: a script that does not parse stops Reborn from
        # booting, and a half-written tree is worse than an unpatched one.
        print(f'\n{broken} ファイルが壊れているため、書き込みを中止しました。')
        print('パッチ定義 (build_edits) を直してから再実行してください。')
        return 1

    if not a.check and applied:
        for path, text in cache.items():
            open(path, 'w', encoding='utf-8').write(text)

    print(f'\n適用 {applied} / 適用済み {already} / 失敗 {failed}')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
