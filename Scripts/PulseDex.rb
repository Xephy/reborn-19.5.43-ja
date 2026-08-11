# Pulse Dex class. Based on xLed's Jukebox Scene class.
class Scene_PulseDex
  #-----------------------------------------------------------------------------
  # * Object Initialization
  #     menu_index : command cursor's initial position
  #-----------------------------------------------------------------------------
  def initialize(menu_index = 0)
    @menu_index = menu_index
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
    @sprites["background"].z = 255
    @choices = pbPulseSeen
    @sprites["header"] = Window_UnformattedTextPokemon.newWithSize(_INTL("Pulse Dex"), 2, -18, 128, 64, @viewport)
    @sprites["header"].baseColor = Color.new(248, 248, 248)
    @sprites["header"].shadowColor = Color.new(0, 0, 0)
    @sprites["header"].windowskin = nil
    @sprites["command_window"] = Window_CommandPokemonWhiteArrow.new(@choices, 324)
    @sprites["command_window"].windowskin = nil
    @sprites["command_window"].baseColor = Color.new(248, 248, 248)
    @sprites["command_window"].shadowColor = Color.new(0, 0, 0)
    @sprites["command_window"].index = @menu_index
    @sprites["command_window"].setHW_XYZ(286, 324, 94, 46, 256)
    tts(@choices[@menu_index])
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
  #-----------------------------------------------------------------------------  #-----------------------------------------------------------------------------
  def update
    pbUpdateSpriteHash(@sprites)
    if Input.repeat?(Input::UP) || Input.repeat?(Input::L) || Input.repeat?(Input::DOWN) || Input.repeat?(Input::R)
      tts(@choices[@sprites["command_window"].index])
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
    index = @sprites["command_window"].index
    # If B button was pressed
    if Input.trigger?(Input::B) || (Input.trigger?(Input::C) && index == @choices.length - 1)
      # Switch to map screen
      pbPlayCancelSE()
      $scene = Scene_Pokegear.new(:pulse)
      return
    end
    # If C button was pressed
    if Input.trigger?(Input::C)
      pulse = PULSEDATA.keys[index]
      if $game_switches[pulse]
        pbPlayDecisionSE()
        $scene = Scene_PulseDex_Info.new(pulse, index)
      end
      return
    end
  end

  #-----------------------------------------------------------------------------
  # * Determines which Pulses the trainer has data for
  #-----------------------------------------------------------------------------
  def pbPulseSeen
    pulseSeen = []
    for pulse in PULSEDATA.keys
      # The entry names and the page images both carry text that never reaches
      # the message tables: the names are plain strings here, and every page is
      # a single 512x384 picture with the description drawn into it. The names
      # are looked up like any other line; the pictures have a Japanese copy in
      # Graphics/Pictures/PulseDex/ja/, which pbBitmapName picks up.
      pulseSeen.push($game_switches[pulse] ? _INTL(PULSEDATA[pulse][:name]) : "???")
    end
    pulseSeen.push(_INTL("Back"))
    return pulseSeen
  end
end

PULSEDATA = {
  :Pulse_Garbodor => {
    :name => "0. Garbodor",
    :desc => "Produced by a curious stray Pokémon finding an abandoned machine. Its function is to make wasteful byproduct. Anything it touches sticks to it and will eventually be turned into toxic waste.",
    :species => :GARBODOR,
    :form => "PULSE Form",
  },
  :Pulse_Magnezone => {
    :name => "1. Magnezone",
    :desc => "The very first PULSE Pokémon created. Its function is mass reproduction. Each of its eyes contains the energy of one of the people responsible for its creation. It obeys only them.",
    :species => :MAGNEZONE,
    :form => "PULSE Form",
  },
  :Pulse_Avalugg => {
    :name => "2. Avalugg",
    :desc => "Created by a once wild Pokémon evolving in reaction to erratic energy. Its function is endless generation. Part of its body was formed around the machine, making it unable to move at all.",
    :species => :AVALUGG,
    :form => "PULSE Form",
  },
  :Pulse_Swalot => {
    :name => "3. Swalot",
    :desc => "Engineered to be totally indestructible. Its function is endless regeneration. When it expands its body, it loses consciousness, becoming only a vessel for absorption and subsequent expulsion.",
    :species => :SWALOT,
    :form => "PULSE Form",
  },
  :Pulse_Muk => {
    :name => "4. Muk",
    :desc => "Created by repeated fusions. Its function is systematic contamination. By becoming one with substances of any kind, it is able to transmute the target of its union into toxic filth.",
    :species => :MUK,
    :form => "PULSE Form",
  },
  :Pulse_Tangrowth_A => {
    :name => "5A. Tangrowth",
    :desc => "Hybridized for erratic growth. Its function is to empower nature to reclaim stolen land. Its purification process is almost fully complete. At the end of its petrification, its organs also begin to harden and stop.",
    :species => :TANGROWTH,
    :form => "PULSE A",
  },
  :Pulse_Tangrowth_B => {
    :name => "5B. Tangrowth",
    :desc => "Hybridized for erratic growth. Its function is to empower nature to reclaim stolen land. After absorbing the latent corruption, it begins to purify the damage by petrifying and breaking down the toxic components.",
    :species => :TANGROWTH,
    :form => "PULSE B",
  },
  :Pulse_Tangrowth_C => {
    :name => "5C. Tangrowth",
    :desc => "Hybridized for erratic growth. Its function is to empower nature to reclaim stolen land. Using long, reaching vines, it absorbs corruption from all sources into its body to dispose of it.",
    :species => :TANGROWTH,
    :form => "PULSE C",
  },
  :Pulse_Camerupt => {
    :name => "6. Camerupt",
    :desc => "Created as a catalyst for purification. Its function is limitless amplification. Its body resonates with nearby heat, inciting reactive power. After eruption, it is unable to cool down, and will perish.",
    :species => :CAMERUPT,
    :form => "PULSE Form",
  },
  :Pulse_Abra => {
    :name => "7. Abra",
    :desc => "An experiment testing the effects of PULSE systems on unevolved Pokémon. Its function is seamless transportation. Its body seems to reject all machine input, at the apparent cost of its psyche.",
    :species => :ABRA,
    :form => ["PULSE Form", "PULSE2 Form"],
  },
  :Pulse_Hypno => {
    :name => "8. Hypno",
    :desc => "Digitally lobotomized for full efficiency. Its function is perfect control. It projects its unconsciousness onto target locations and can directly manipulate up to two individuals at a time.",
    :species => :HYPNO,
    :form => "PULSE Form",
  },
  :Pulse_Mime => {
    :name => "9. Mr. Mime",
    :desc => "Modified by repeated amputations and augmentations. Its function is impregnable defense. Its psychic power is amplified by the constant focus it requires to maintain control over its unattached limbs.",
    :species => :MRMIME,
    :form => "PULSE Form",
  },
  :Pulse_Clawitzer => {
    :name => "10. Clawitzer",
    :desc => "Mechanically sculpted via scripted process. Its function is endless offensive potential. Many bodily features such as the brain have been rendered vestigial to allow manual usage of the Pokemon similar to traditional artillery.",
    :species => :CLAWITZER,
    :form => "PULSE Form",
  },
  :Arc_Pulse => {
    :name => "11. Arceus",
    :desc => "World is deception, World is in pain, World should remake, World is competition, World is destruction, World is mistake, World is attack, World is unloved, World is deception, World is mistake, World is mistake, World is mistake, World is mistake",
    :species => :ARCEUS,
    :form => "PULSE Normal",
  },
}

def preparePulseDexInfo(pulse)
  sprites = {}
  viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
  viewport.z = 99999
  sprites["background"] = IconSprite.new(0, 0, viewport)
  sprites["background"].setBitmap(pbBitmapName("Graphics/Pictures/PulseDex/#{pulse.to_s}"))
  sprites["background"].z = 255
  return viewport, sprites
end

def ttsPulse(pulse)
  name = PULSEDATA[pulse][:name]
  species = PULSEDATA[pulse][:species]
  form = PULSEDATA[pulse][:form]
  desc = PULSEDATA[pulse][:desc]
  type1 = $cache.pkmn[species, form].Type1
  type2 = $cache.pkmn[species, form].Type2
  ability = $cache.pkmn[species, form].Abilities[0]
  basestats = $cache.pkmn[species, form].BaseStats.clone
  for i in 0...basestats.length
    basestats[i] = (basestats[i] / 255.0 * 100).round(0)
    basestats[i] = 1 if basestats[i] == 0
  end
  text = "PULSE #{name}. #{type1}#{type2 ? " and #{type2}" : ""} type. #{ability} ability. #{desc} "
  text += ", HP, #{basestats[0]} %. Attack, #{basestats[1]} %. Defense, #{basestats[2]} %. Special Attack, #{basestats[3]} %. Special Defense, #{basestats[4]} %. Speed, #{basestats[5]} %."
  tts(text)
end

# Class for information screen

class Scene_PulseDex_Info
  attr_accessor :background
  attr_accessor :index

  def initialize(pulse, index)
    @pulse      = pulse
    @index      = index
  end

  def main
    @viewport, @sprites = preparePulseDexInfo(@pulse)
    ttsPulse(@pulse)
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

  def update
    pbUpdateSpriteHash(@sprites)
    update_command
  end

  def update_command
    if Reborn
      if Input.trigger?(Input::RIGHT)
        changePulse(1)
      elsif Input.trigger?(Input::LEFT)
        changePulse(-1)
      end
    end
    if Input.trigger?(Input::B)
      # Switch to map screen
      pbPlayCancelSE()
      $scene = Scene_PulseDex.new(@index)
      return
    end
  end

  def changePulse(increment)
    oldindex = @index
    loop do
      @index += increment
      if @index >= PULSEDATA.keys.length
        @index = 0
      elsif @index < 0
        @index = PULSEDATA.keys.length - 1
      end
      break unless !$game_switches[PULSEDATA.keys[@index]]
    end
    return if @index == oldindex

    pbPlayDecisionSE()
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
    @pulse = PULSEDATA.keys[@index]
    @viewport, @sprites = preparePulseDexInfo(@pulse)
    ttsPulse(@pulse)
  end
end

class Scene_PulseDex_Battle
  def pbStartScene(pulses)
    @index = 0
    @pulses = pulses
    @viewport, @sprites = preparePulseDexInfo(@pulses[@index])
    @sprites["leftarrow"] = AnimatedSprite.new("Graphics/Pictures/leftarrow", 8, 40, 28, 2, @viewport)
    @sprites["leftarrow"].x = 0
    @sprites["leftarrow"].y = 178
    @sprites["leftarrow"].z = 256
    @sprites["leftarrow"].play
    @sprites["leftarrow"].visible = false
    @sprites["rightarrow"] = AnimatedSprite.new("Graphics/Pictures/rightarrow", 8, 40, 28, 2, @viewport)
    @sprites["rightarrow"].x = 472
    @sprites["rightarrow"].y = 178
    @sprites["rightarrow"].z = 256
    @sprites["rightarrow"].play
    @sprites["rightarrow"].visible = false
    tts("Pulse #{@index + 1} of #{@pulses.length}") if @pulses.length > 1
    ttsPulse(@pulses[@index])
    pbFadeInAndShow(@sprites)
    loop do
      Graphics.update
      Input.update
      self.update
      return if Input.trigger?(Input::B) || Input.trigger?(Input::Z)
    end
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites)
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end

  def pbSwitchPulseNotes
    @sprites["background"].setBitmap(pbBitmapName("Graphics/Pictures/PulseDex/#{@pulses[@index].to_s}"))
    tts("Pulse #{@index + 1} of #{@pulses.length}") if @pulses.length > 1
    ttsPulse(@pulses[@index])
  end

  def update
    pbUpdateSpriteHash(@sprites)
    # update command window and the info if it's active
    if Input.trigger?(Input::B) || Input.trigger?(Input::Z)
      pbPlayCancelSE()
      return
    end
    @sprites["leftarrow"].visible = @index != 0
    @sprites["rightarrow"].visible = @index != @pulses.length - 1
    if Input.trigger?(Input::LEFT) && @index != 0
      pbPlayDecisionSE()
      @index -= 1
      pbSwitchPulseNotes()
    elsif Input.trigger?(Input::RIGHT) && @index != @pulses.length - 1
      pbPlayDecisionSE()
      @index += 1
      pbSwitchPulseNotes()
    end
  end
end
