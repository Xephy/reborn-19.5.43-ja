class Scene_Pokegear
  def main
    setup()
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @button = AnimatedBitmap.new("Graphics/Pictures/Pokegear/pokegearButton")
    @sprites = {}
    @sprites["background"] = IconSprite.new(0, 0)
    @sprites["background"].setBitmap("Graphics/Pictures/Pokegear/pokegearbg")
    @sprites["command_window"] = Window_CommandPokemon.new(@buttons, 160)
    @sprites["command_window"].index = default_index
    @sprites["command_window"].x = Graphics.width
    @sprites["command_window"].y = -3000 # 0
    for i in 0...@buttons.length
      x = 118
      y = 206 - (@buttons.length * 24) + (i * 44)
      @sprites["button#{i}"] = PokegearButton.new(x, y, @buttons[i], i, @viewport)
      @sprites["button#{i}"].selected = i == @sprites["command_window"].index
      @sprites["button#{i}"].update
    end
    Graphics.transition
    loop do
      Graphics.update
      Input.update
      update
      break if $scene != self
    end
    Graphics.freeze
    pbDisposeSpriteHash(@sprites)
  end

  def default_index
    idx = 0
    case @menu_index
      when :notes then idx = @cmdNotes
      when :pulse then idx = @cmdPulse
      when :tutor then idx = @cmdTutor
      when :map then idx = @cmdMap
      when :jukebox then idx = @cmdJukebox
      when :online then idx = @cmdOnline
      when :weather then idx = @cmdWeather
      when :tracker then idx = @cmdTracker
      when :phone then idx = @cmdPhone
      else idx = @menu_index
    end
    return idx
  end

  def refresh
    self.bitmap.clear
    self.bitmap.blt(0, 0, @button.bitmap, Rect.new(0, 0, @button.width, @button.height))
    pbSetSystemFont(self.bitmap)
    textpos = [          # Name is written on both unselected and selected buttons
      [@name, self.bitmap.width / 2, 10, 2, Color.new(248, 248, 248), Color.new(40, 40, 40)],
      [@name, self.bitmap.width / 2, 62, 2, Color.new(248, 248, 248), Color.new(40, 40, 40)],
    ]
    pbDrawTextPositions(self.bitmap, textpos)
    icon = sprintf("Graphics/Pictures/Pokegear/pokegear" + @name)
    imagepos = [         # Icon is put on both unselected and selected buttons
      [icon, 20, 10, 0, 0, -1, -1],
      [icon, 20, 62, 0, 0, -1, -1],
    ]
    pbDrawImagePositions(self.bitmap, imagepos)
  end

  def setup
    @buttons = []
    @cmdMap = -1
    @cmdPhone = -1
    @cmdJukebox = -1
    @cmdOnline = -1
    @cmdPulse = -1
    @cmdNotes = -1
    @cmdTutor = -1
    @cmdWeather = -1
    @cmdTracker = -1
    @buttons[@cmdNotes = @buttons.length] = _INTL("Field Notes") if $game_switches[:Field_Notes]
    @buttons[@cmdPulse = @buttons.length] = _INTL("PULSE Dex") if $game_switches[:Pulse_Dex]
    @buttons[@cmdTutor = @buttons.length] = _INTL("Move Tutor")
    @buttons[@cmdMap = @buttons.length] = _INTL("Region Map")
    @buttons[@cmdOnline = @buttons.length] = _INTL("Online Play")
    @buttons[@cmdJukebox = @buttons.length] = _INTL("Jukebox")
    @buttons[@cmdWeather = @buttons.length] = _INTL("Time & Weather")
    # @buttons[@cmdTracker=@buttons.length]=_INTL("Item Tracker")
  end

  def checkChoice
    if @cmdMap >= 0 && @sprites["command_window"].index == @cmdMap
      pbPlayDecisionSE()
      pbShowMap(-1, false)
    end
    if @cmdJukebox >= 0 && @sprites["command_window"].index == @cmdJukebox
      pbPlayDecisionSE()
      $scene = Scene_Jukebox.new
    end
    if @cmdOnline >= 0 && @sprites["command_window"].index == @cmdOnline
      pbPlayDecisionSE()
      if Kernel.pbConfirmMessage(_INTL("Would you like to save the game?"))
        if pbSave
          Kernel.pbMessage("Saved the game!")
          tryConnect
        else
          Kernel.pbMessage("Save failed.")
        end
      end
    end
    if @cmdPulse >= 0 && @sprites["command_window"].index == @cmdPulse
      pbPlayDecisionSE()
      $scene = Scene_PulseDex.new
    end
    if @cmdNotes >= 0 && @sprites["command_window"].index == @cmdNotes
      pbPlayDecisionSE()
      $scene = Scene_FieldNotes.new
    end
    if @cmdTutor >= 0 && @sprites["command_window"].index == @cmdTutor
      pbPlayDecisionSE()
      pbRelearnMoveTutorScreen
    end
    if @cmdWeather >= 0 && @sprites["command_window"].index == @cmdWeather
      pbPlayDecisionSE()
      $scene = Scene_TimeWeather.new
    end
    # if @cmdTracker>=0 && @sprites["command_window"].index==@cmdTracker
    #   pbPlayDecisionSE()
    #   $scene = Scene_ItemTracker.new
    # end
  end

  def tryConnect
    $scene = Connect.new
  end
end

FIELD_NOTES_MENU = {
  "<c3=5fade2,1b4f72>Elemental Fields" => [
    :ELECTERRAIN,
    :MISTY,
    :CORROSIVEMIST,
    :GRASSY,
    :BURNING,
    :ICY,
    :WATERSURFACE,
    :MURKWATERSURFACE,
    :UNDERWATER,
    :DRAGONSDEN,
  ],
  "<c3=52dc5c,006205>Telluric Fields" => [
    :DESERT,
    :FOREST,
    :CORROSIVE,
    :CAVE,
    :ASHENBEACH,
    :SUPERHEATED,
    :SWAMP,
    :WASTELAND,
    :ROCKY,
    :MOUNTAIN,
    :SNOWYMOUNTAIN,
  ],
  "<c3=ec7063,7b241c>Synthetic Fields" => [
    :FACTORY,
    :SHORTCIRCUIT,
    :MIRROR,
    :CHESS,
    :BIGTOP,
    :GLITCH,
    :FLOWERGARDEN1,
  ],
  "<c3=bb8fce,5b2c6f>Magical Fields" => [
    :RAINBOW,
    :CRYSTALCAVERN,
    :DARKCRYSTALCAVERN,
    :PSYTERRAIN,
    :HOLY,
    :INVERSE,
    :FAIRYTALE,
    :STARLIGHT,
    :NEWWORLD,
  ],
}

class Scene_FieldNotes
  def buildFieldMenu
    seenFields = checkSeenFields.keys.collect { |i| fieldIDToSym(i) }
    menu = []
    general = {
      label: "<c3=f8c471,8a461e>General",
      field: :INDOOR,
    }
    menu.push(general)
    FIELD_NOTES_MENU.each do |category, fields|
      item = {
        label: category,
        skip: true,
      }
      menu.push(item)
      fields.each do |field|
        if seenFields.include?(field)
          item = {
            label: "      <c3=f8f8f8,5c5c5c>" + $cache.FEData[field].name,
            field: field,
          }
        else
          item = {
            label: "      ???",
          }
        end
        menu.push(item)
      end
    end
    back = {
      label: "<c3=a7a7a7,4e4e4e>Back",
      back: true,
    }
    menu.push(back)
    menu
  end
end
