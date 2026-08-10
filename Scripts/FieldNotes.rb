# Field Catalogue class. Based on xLed's Jukebox Scene class.
class Scene_FieldNotes
  #-----------------------------------------------------------------------------
  # * Object Initialization
  #     menu_index : command cursor's initial position
  #-----------------------------------------------------------------------------
  def initialize(menu_index = 0)
    @menu_index = menu_index
    @menu = self.buildFieldMenu
    @menu_index += 1 if @menu[@menu_index][:skip]
  end

  def buildFieldMenu
    seenFields = checkSeenFields.keys.collect { |i| fieldIDToSym(i) }
    menu = []
    general = {
      label: _INTL("General"),
      field: :INDOOR,
    }
    menu.push(general)
    for i in 1..TOTALFIELDS
      field = fieldIDToSym(i)
      if seenFields.include?(field)
        item = {
          label: i.to_s + ". " + fieldNoteName(field),
          field: field,
        }
      else
        item = {
          label: "???",
        }
      end
      menu.push(item)
    end
    back = {
      label: _INTL("Back"),
      back: true,
    }
    menu.push(back)
    menu
  end

  #-----------------------------------------------------------------------------
  # * Main Processing
  #-----------------------------------------------------------------------------
  def main
    # Makes the text window
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites["background"] = IconSprite.new(0, 0)
    @sprites["background"].setBitmap("Graphics/Pictures/navbg")
    @sprites["background"].setBitmap("Graphics/Pictures/navbgFieldNotes") if Desolation
    @sprites["background"].z = 255
    @choices = @menu.collect { |field| field[:label] }
    @sprites["header"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Field Notes"),
      2, -18, 256, 64, @viewport
    )
    @sprites["header"].baseColor = Color.new(248, 248, 248)
    @sprites["header"].shadowColor = Color.new(0, 0, 0)
    @sprites["header"].windowskin = nil
    @sprites["command_window"] = Window_CommandPokemonWhiteArrow.new(@choices, 324)
    @sprites["command_window"].windowskin = nil
    @sprites["command_window"].baseColor = Color.new(248, 248, 248)
    @sprites["command_window"].shadowColor = Color.new(0, 0, 0)
    @sprites["command_window"].index = @menu_index
    @sprites["command_window"].setHW_XYZ(286, 324, 94, 46, 256)
    tts(@choices[@menu_index].gsub(/<\/?c3(?:=[0-f]+,[0-f]+)?>/, ""))
    # Execute transition
    Graphics.transition
    # Main loop
    loop do
      # Update game screen
      Graphics.update
      # Update input information
      Input.update
      # Frame update
      update
      # Abort loop if screen is changed
      if $scene != self
        break
      end
    end
    # Prepares for transition
    Graphics.freeze
    # Disposes the windows
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end

  #-----------------------------------------------------------------------------
  # * Frame Update
  #-----------------------------------------------------------------------------
  def update
    pbUpdateSpriteHash(@sprites)

    # Skip category labels
    if Input.repeat?(Input::UP) || Input.repeat?(Input::L)
      menuindex = @sprites["command_window"].index
      item = @menu[menuindex]
      if item[:skip]
        @sprites["command_window"].index -= 1
        @sprites["command_window"].index = Input.trigger?(Input::UP) ? @menu.size - 1 : 1 if menuindex == 0
      end
      tts(@choices[@sprites["command_window"].index].gsub(/<\/?c3(?:=[0-f]+,[0-f]+)?>/, ""))
    end
    if Input.repeat?(Input::DOWN) || Input.repeat?(Input::R)
      menuindex = @sprites["command_window"].index
      item = @menu[menuindex]
      if item[:skip]
        @sprites["command_window"].index += 1
      end
      tts(@choices[@sprites["command_window"].index].gsub(/<\/?c3(?:=[0-f]+,[0-f]+)?>/, ""))
    end

    # update command window and the info if it's active
    if @sprites["command_window"].active
      update_command
      return
    end
  end

  #-----------------------------------------------------------------------------
  # * Command controls
  #-----------------------------------------------------------------------------
  def update_command
    # If B button was pressed
    if Input.trigger?(Input::B)
      # Switch to map screen
      pbPlayCancelSE()
      $scene = Scene_Pokegear.new(:notes)
      return
    end
    # If C button was pressed
    if Input.trigger?(Input::C)
      # Branch by command window cursor position
      menuindex = @sprites["command_window"].index
      item = @menu[menuindex]
      if item[:back]
        # Switch to map screen
        pbPlayCancelSE()
        $scene = Scene_Pokegear.new(:notes)
        return
      elsif item[:field]
        pbPlayDecisionSE()
        $scene = Scene_FieldNotes_Info.new(@menu, menuindex)
      else
        pbPlayBuzzerSE()
      end
    end
  end
end

#-----------------------------------------------------------------------------
# * Determines which Fields the trainer has data for
#-----------------------------------------------------------------------------
def checkSeenFields
  # puts $Unidata[:fieldNotes]
  fieldSeen = {}
  for i in 1..TOTALFIELDS
    if $game_switches[$cache.FEData[fieldIDToSym(i)].fieldAppSwitch]
      fieldSeen.store(i, true)
    end
  end
  if $Unidata[:fieldNotes] != nil
    fieldSeen.merge!($Unidata[:fieldNotes])
    if fieldSeen.length > $Unidata[:fieldNotes].length
      $Unidata[:fieldNotes] = fieldSeen
    end
    if Desolation
      for i in 1..TOTALFIELDS
        $game_switches[$cache.FEData[fieldIDToSym(i)].fieldAppSwitch] = $Unidata[:fieldNotes].keys.include?(i)
      end
    end
  end
  return fieldSeen
end

def prepareFieldNoteInit(fe)
  fe = :FLOWERGARDEN4 if fe == :FLOWERGARDEN1
  return fe
end

# Field names and note bodies live in fields.dat / fieldnotes.dat, which are
# compiled once and shared by every language, so they are always English there
# and get translated on the way to the screen. The keys are registered in the
# script-text section (see jp_translation/work/src/22b_field_notes.jsonl); an
# untranslated one falls back to the English wording it was keyed on.
def fieldNoteName(fieldeffect)
  return _INTL($cache.FEData[fieldeffect].name)
end

def fieldNoteText(note)
  # PBFieldNote pads the body with a trailing space so a note ending in an icon
  # still renders it. That padding is not part of the sentence, so it stays out
  # of the message key and is put back afterwards.
  return _INTL(note.text.rstrip) + " "
end

def fieldNoteElaboration(note)
  return _INTL(note.elaboration.strip)
end

def prepareFieldNoteInfo(fieldeffect)
  fieldnotes = $cache.FENotes.find_all { |note| note.fieldeffect == fieldeffect }
  f = []
  fieldnotes.each { |note| f.push(fieldNoteText(note)) }
  choices = f
  return fieldnotes, choices
end

def prepareFieldNoteCommand(fieldnotes, viewport)
  sprite = Window_FieldEffectNotes.newWithSize(fieldnotes, 8, 46, Graphics.width - 8, 286, viewport)
  sprite.windowskin = nil
  sprite.baseColor = Color.new(248, 248, 248)
  sprite.shadowColor = Color.new(0, 0, 0)
  sprite.z = 256
  return sprite
end

def prepareFieldNoteSprites(viewport, fieldnotes, fieldeffect)
  sprites = {}
  sprites["fieldbackground"] = IconSprite.new(0, 30, viewport)
  background = $cache.FEData[fieldeffect].graphic[0]
  sprites["fieldbackground"].setBitmap("Graphics/Battlebacks/battlebg" + background)
  sprites["fieldbackground"].z = 254
  sprites["fieldbackground"].opacity -= 200
  sprites["background"] = IconSprite.new(0, 0, viewport)
  sprites["background"].setBitmap("Graphics/Pictures/fieldapp")
  sprites["background"].z = 255
  sprites["header"] = Window_UnformattedTextPokemon.newWithSize(fieldNoteName(fieldeffect), 2, -18, 256, 64, viewport)
  sprites["header"].baseColor = Color.new(248, 248, 248)
  sprites["header"].shadowColor = Color.new(0, 0, 0)
  sprites["header"].windowskin = nil
  sprites["header"].z = 256
  sprites["command_window"] = prepareFieldNoteCommand(fieldnotes, viewport)
  return sprites
end

def ttsNote(note)
  return unless Reborn

  text = note
  text = text.gsub(/<\/?c(?:=\w+)?>/, "") # Remove opening and closing color tags

  defaults = {
    "fieldChange" => "changes to",
    "fieldUp" => "boosted by",
    "fieldRedUp" => "boosted",
    "fieldDown" => "lowered by",
    "fieldPlus" => "additionally",
    "fieldNoSleep" => "unable to sleep",
    "fieldNoFreeze" => "unable to freeze",
    "fieldAllStat" => "random status",
    "fieldBurn" => "Burn status",
    "fieldFaint" => "faint",
    "fieldFreeze" => "Freeze status",
    "fieldParalyze" => "Paralyze status",
    "fieldPoisonStatus" => "Poison status",
    "fieldSleep" => "Sleep status",
  }
  $cache.types.each { |type, data| defaults["type#{type}"] = "#{data.name} type" }
  pattern = /<icon=(\w+)(.*?)>/
  text = text.gsub(pattern) do |match|
    icon = $1
    tts = $2
    tts_content = tts[/,tts="([^"]*)"/, 1]
    default = defaults[icon] || "#{icon}"
    tts_content ? tts_content : default
  end
  text = noteReplace(text)
  tts(text)
end

def noteReplace(note)
  text = note

  strings = {
    "\. \. \." => "", # Remove ". . .", "Read more" message is handled in-scene
    "Sp.Atk" => "Special Attack",
    "Sp.Def" => "Special Defense",
    "Atk" => "Attack",
    "Def" => "Defense",
    "???" => "Question marks",
    " vs " => " versus ",
  }
  text = strings.inject(text) { |str, (word, replace)| str.gsub(word, replace) }
  text = text.gsub(/x(\d+\.?\d*)/) { |match| "#{$1} times" } # Replace multipliers
  text = text.gsub(/Defense(?![\/s]\b)/, "Def") # Fix Defense text

  return text
end

class Window_FieldEffectNotes < Window_AdvancedCommandPokemon
  attr_accessor :notes

  def initialize(notes, width)
    @notes = notes
    super(notes.map { |note| fieldNoteText(note) }, width)
  end

  def drawCursor(index, rect)
    selarrow = AnimatedBitmap.new("Graphics/Pictures/selarrowwhite")
    if self.index == index
      pbCopyBitmap(self.contents, selarrow.bitmap, rect.x, rect.y)
    end
    return Rect.new(rect.x + 24, rect.y, rect.width - 24, rect.height)
  end

  def render_command(cmd)
    choicebmp = Bitmap.new(@text_width, @row_height)
    pbSetSystemFont(choicebmp)
    shadow = 1.0 / 4.0
    if cmd == toUnformattedText(cmd).gsub(/\n/, "")
      shadowColor = Color.new(
        self.baseColor.red * shadow,
        self.baseColor.green * shadow,
        self.baseColor.blue * shadow,
        self.baseColor.alpha,
      )
      pbDrawShadowText(choicebmp, 0, 0, @text_width, @row_height, cmd, self.baseColor, shadowColor)
    else
      formattedText = getFormattedText(self.contents, 0, 0, @text_width, @row_height, cmd, @row_height, true, true)
      formattedText.each { |ch|
        ch[9] = Color.new(
          ch[8].red * shadow,
          ch[8].green * shadow,
          ch[8].blue * shadow,
          ch[8].alpha,
        )
      }
      drawFormattedChars(choicebmp, formattedText)
    end
    return choicebmp
  end

  def refresh
    @item_max = itemCount()
    dwidth = self.width - self.borderX
    dheight = self.height - self.borderY
    self.contents = pbDoEnsureBitmap(self.contents, dwidth, dheight)
    self.contents.clear
    for i in 0...@item_max
      if i < self.top_item || i > self.top_item + self.page_item_max
        next
      end

      drawItem(i, @item_max, itemRect(i))
      drawCogWheel(i, cogwheelRect(i))
    end
  end

  def cogwheelRect(item)
    note = @notes[item]
    if item < 0 || item >= @item_max || item < self.top_item || item > self.top_item + self.page_item_max || note.elaboration == "" && note.cogwheeltext == ""
      return Rect.new(0, 0, 0, 0)
    else
      x = 414
      y = item / @column_max * @row_height - @virtualOy
      return Rect.new(x, y, 40, @row_height)
    end
  end

  def drawCogWheel(item, rect)
    pbSetSystemFont(self.contents)
    note = @notes[item]
    return if note.elaboration == "" && note.cogwheeltext == ""

    if note.elaboration != "" && note.cogwheeltext == ""
      cogwheel = AnimatedBitmap.new("Graphics/Icons/fieldTabStar")
      pbCopyBitmap(self.contents, cogwheel.bitmap, rect.x, rect.y)
      return
    end
    if note.elaboration != "" && note.cogwheeltext != ""
      text = " <fs=28><b>" + note.cogwheeltext + "</b><icon=fieldTabStarEmpty> "
    else
      text = " <fs=28><b>" + note.cogwheeltext + "</b>"
    end
    chars = getFormattedText(self.contents, rect.x, rect.y - 2, rect.width, rect.height, text, rect.height, true, true)
    case chars.length
      when 1, 2 then boxtype = "fieldTab1"
      when 3, 4 then boxtype = "fieldTab2"
      when 5, 6 then boxtype = "fieldTab3"
      else
        boxtype = "fieldTab4"
    end
    textbox = AnimatedBitmap.new("Graphics/Icons/#{boxtype}")
    pbCopyBitmap(self.contents, textbox.bitmap, rect.x, rect.y)
    drawFormattedChars(self.contents, chars)
  end
end

class Scene_FieldNotes_Info
  attr_accessor :from_index

  #-----------------------------------------------------------------------------
  # * Object Initialization
  #     menu_index : command cursor's initial position
  #-----------------------------------------------------------------------------
  def initialize(menu, menu_index)
    @menu = menu
    @fieldeffect = prepareFieldNoteInit(menu[menu_index][:field])
    @menu_index = menu_index
  end

  #-----------------------------------------------------------------------------
  # * Main Processing
  #-----------------------------------------------------------------------------
  def main
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @fieldnotes, @choices = prepareFieldNoteInfo(@fieldeffect)
    @sprites = prepareFieldNoteSprites(@viewport, @fieldnotes, @fieldeffect)
    ttsNote(@choices[0])
    Graphics.transition
    loop do
      Graphics.update
      Input.update
      update
      if $scene != self
        break
      end
    end
    Graphics.freeze
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end

  #-----------------------------------------------------------------------------
  # * Frame Update
  #-----------------------------------------------------------------------------
  def update
    pbUpdateSpriteHash(@sprites)
    # update command window and the info if it's active
    if Input.trigger?(Input::B)
      # Switch to map screen
      pbPlayCancelSE()
      $scene = Scene_FieldNotes.new(@menu_index)
      return
    end
    if Input.trigger?(Input::C)
      # Branch by command window cursor position
      fieldindex = @sprites["command_window"].index
      if !@fieldnotes[fieldindex].nil? && @choices[fieldindex] != @choices.length && @fieldnotes[fieldindex].elaboration != ""
        tts(noteReplace(@fieldnotes[fieldindex].elaboration))
        Kernel.pbMessage(fieldNoteElaboration(@fieldnotes[fieldindex]), tts: false)
      elsif @choices[fieldindex] == @choices.length
        # Switch to map screen
        $scene = Scene_Pokegear.new(:notes)
        return
      end
    end
    if Input.trigger?(Input::RIGHT) || Input.repeat?(Input::RIGHT)
      changeField(1)
    elsif Input.trigger?(Input::LEFT) || Input.repeat?(Input::LEFT)
      changeField(-1)
    end
    if Input.repeat?(Input::UP) || Input.repeat?(Input::L) || Input.repeat?(Input::DOWN) || Input.repeat?(Input::R)
      fieldindex = @sprites["command_window"].index
      ttsNote("#{@choices[fieldindex]}, #{"Press to read more" if @fieldnotes[fieldindex].elaboration != ""}")
    end
  end

  def changeField(increment)
    oldindex = @menu_index
    loop do
      @menu_index += increment
      if @menu_index >= @menu.length
        @menu_index = 0
      elsif @menu_index < 0
        @menu_index = @menu.length - 1
      end
      break unless @menu[@menu_index][:field].nil?
    end
    return if @menu_index == oldindex

    pbPlayDecisionSE()
    @fieldeffect = prepareFieldNoteInit(@menu[@menu_index][:field])
    pbDisposeSpriteHash(@sprites)
    @fieldnotes, @choices = prepareFieldNoteInfo(@fieldeffect)
    @sprites = prepareFieldNoteSprites(@viewport, @fieldnotes, @fieldeffect)
    tts(@menu[@menu_index][:label].gsub(/<\/?c3(?:=[0-f]+,[0-f]+)?>/, ""))
    ttsNote(@choices[0])
  end
end

class Scene_FieldNotes_Battle
  def pbStartScene(fieldlayers)
    @index = 0
    @commandindex = []
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @fieldlayers = fieldlayers
    @fieldlayers -= [:INDOOR]
    @fieldlayers.map! { |field|
      [:FLOWERGARDEN1, :FLOWERGARDEN2, :FLOWERGARDEN3, :FLOWERGARDEN5].include?(field) ? :FLOWERGARDEN4 : field
    }
    @fieldlayers.reverse!
    @fieldnotes = []
    @choices = []
    for i in 0..@fieldlayers.length
      @fieldnotes[i], @choices[i] = prepareFieldNoteInfo(@fieldlayers[i])
    end
    @sprites = prepareFieldNoteSprites(@viewport, @fieldnotes[0], @fieldlayers[0])
    @sprites["leftarrow"] = AnimatedSprite.new("Graphics/Pictures/leftarrow", 8, 40, 28, 2, @viewport)
    @sprites["leftarrow"].x = 8
    @sprites["leftarrow"].y = 176
    @sprites["leftarrow"].z = 256
    @sprites["leftarrow"].play
    @sprites["leftarrow"].visible = false
    @sprites["rightarrow"] = AnimatedSprite.new("Graphics/Pictures/rightarrow", 8, 40, 28, 2, @viewport)
    @sprites["rightarrow"].x = 456
    @sprites["rightarrow"].y = 176
    @sprites["rightarrow"].z = 256
    @sprites["rightarrow"].play
    @sprites["rightarrow"].visible = false
    tts("#{$cache.FEData[@fieldlayers[@index]].name}, #{"Field 1 of #{@fieldlayers.length}" if @fieldlayers.length > 1}")
    ttsNote(@choices[@index][0])
    pbFadeInAndShow(@sprites)
    loop do
      Graphics.update
      Input.update
      self.update
      return if Input.trigger?(Input::B)
    end
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites)
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end

  #-----------------------------------------------------------------------------
  # * Frame Update
  #-----------------------------------------------------------------------------
  def update
    pbUpdateSpriteHash(@sprites)
    # update command window and the info if it's active
    if Input.trigger?(Input::B) || Input.trigger?(Input::Y)
      pbPlayCancelSE()
      return
    end
    if Input.trigger?(Input::C)
      # Branch by command window cursor position
      fieldindex = @sprites["command_window"].index
      if !@fieldnotes[@index][fieldindex].nil? && @choices[@index][fieldindex] != @choices[@index].length && @fieldnotes[@index][fieldindex].elaboration != ""
        tts(noteReplace(@fieldnotes[@index][fieldindex].elaboration))
        Kernel.pbMessage(fieldNoteElaboration(@fieldnotes[@index][fieldindex]), tts: false)
      elsif @choices[@index][fieldindex] == @choices[@index].length
        return
      end
    end
    @sprites["leftarrow"].visible = @index != 0
    @sprites["rightarrow"].visible = @index != @fieldlayers.length - 1
    if Input.trigger?(Input::LEFT) && @index != 0
      pbPlayDecisionSE()
      @commandindex[@index] = @sprites["command_window"].index
      @index -= 1
      pbSwitchFieldNotes()
    elsif Input.trigger?(Input::RIGHT) && @index != @fieldlayers.length - 1
      pbPlayDecisionSE()
      @commandindex[@index] = @sprites["command_window"].index
      @index += 1
      pbSwitchFieldNotes()
    end
    if Input.repeat?(Input::UP) || Input.repeat?(Input::L) || Input.repeat?(Input::DOWN) || Input.repeat?(Input::R)
      fieldindex = @sprites["command_window"].index
      ttsNote(@choices[@index][fieldindex])
      tts("Press to read more") if @fieldnotes[@index][fieldindex].elaboration != ""
    end
  end

  def pbSwitchFieldNotes()
    background = $cache.FEData[@fieldlayers[@index]].graphic[0]
    @sprites["fieldbackground"].setBitmap("Graphics/Battlebacks/battlebg" + background)
    @sprites["header"].text = fieldNoteName(@fieldlayers[@index])
    @sprites["command_window"].dispose
    @sprites["command_window"] = prepareFieldNoteCommand(@fieldnotes[@index], @viewport)
    @sprites["command_window"].index = @commandindex[@index] if @commandindex[@index]
    tts("#{$cache.FEData[@fieldlayers[@index]].name}, Field #{@index + 1} of #{@fieldlayers.length}")
    ttsNote(@choices[@index][@sprites["command_window"].index])
  end
end
