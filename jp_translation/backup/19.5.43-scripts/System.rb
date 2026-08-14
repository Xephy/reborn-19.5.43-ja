def pbChooseLanguage
  commands = []
  for lang in LANGUAGES
    commands.push(lang[0])
  end
  return Kernel.pbShowCommands(nil, commands)
end

def pbSetUpSystem
  if defined?($game_system)
    offsetX = [0, BORDERWIDTH][$Settings.border]
    offsetY = [0, BORDERHEIGHT][$Settings.border]
    setScreenBorderName("border")
    if Graphics.width != DEFAULTSCREENWIDTH || Graphics.height != DEFAULTSCREENHEIGHT || offsetX != $ResizeOffsetX || offsetY != $ResizeOffsetY
      $ResizeOffsetX = offsetX
      $ResizeOffsetY = offsetY
      $game_system = Game_System
      pbSetResizeFactor($Settings.screensize)
    end
    $random_dex = nil
    $random_items = nil
    $random_moveset = nil
    $random_typeChart = nil
    $random_movedata = nil
  else
    $game_system = Game_System
    $ResizeOffsetX = 0
    $ResizeOffsetY = 0
    pbSetResizeFactor($Settings.screensize)
  end
  MessageConfig.pbSetSystemFontName("PokemonEmerald")
end

def pbSetLanguage
  if LANGUAGES.length >= 2
    $Settings.language = pbChooseLanguage
    pbLoadMessages("Data/" + LANGUAGES[$Settings.language][1])
  end
end

def pbScreenCapture
  capturefile = nil
  5000.times { |i|
    filename = RTP.getSaveFileName(sprintf("capture%03d.bmp", i))
    if !safeExists?(filename)
      capturefile = filename
      break
    end
  }
  begin
    Graphics.snap_to_bitmap.to_file(capturefile)
    pbSEPlay("expfull") if FileTest.audio_exist?("Audio/SE/expfull")
  rescue
    nil
  end
end

module Input
  # JoiPlay doesn't support symbols so we need to use constants
  KEY_RETURN = $joiplay ? 0x42 : 0x0D
  KEY_ESCAPE = $joiplay ? 0x6f : 0x1B
  KEY_BACKSPACE = $joiplay ? 0x04 : 0x08

  unless defined?(update_KGC_ScreenCapture)
    class << Input
      alias update_KGC_ScreenCapture update
    end
  end

  def self.triggerexAny?(keys)
    keys.each do |key|
      return true if triggerex?(key)
    end
    return false
  end

  def self.update
    update_KGC_ScreenCapture

    # Screen capture seems to no longer work and I intend to use F8 for follower toggle.
    # Actually it's easy to revive this, it just needs to use triggerex? instead of trigger?
    # if trigger?(:F8)
    #   pbScreenCapture
    # end

    # JoiPlay doesn't accept literals but only key codes. 84 is the key code for T which I use for turbo on JoiPlay.
    # Alt is force-disabled from triggering turbo if blindstep is active since they use Alt+Tab often and can't unbind it.
    if (!$joiplay && !Input.text_input && defined?(Input::E) && trigger?(Input::E) && (!$game_switches || !$game_switches[:Blindstep] || !triggerex?(:LALT))) || ($joiplay && triggerex?(84))
      Graphics.toggleTurbo
      Graphics.turboIcon
    end

    # JoiPlay doesn't accept literals but only key codes. 77 is the key code for M which I use for mute on JoiPlay.
    if (!$joiplay && !Input.text_input && defined?(Input::F) && trigger?(Input::F)) || ($joiplay && triggerex?(77))
      $game_system.toggle_mute if $game_system
    end

    unless $joiplay
      # Use turbo while Gamepad L2 button is pressed.
      pbDynamicTurbo(Input::Controller.axes_trigger[0])
    end

    if $DEBUG
      if triggerex?(:F10)
        if $profiling
          CP_Profiler.print
          Kernel.pbMessage("Results printed to Profiler.txt.")
          $profiling = false
        else
          Kernel.pbMessage("Begin profiling")
          $profiling = true
          CP_Profiler.begin
        end
      end
      if triggerex?(:F6)
        begin
          Input.text_input = true
          $past_texts = [] if !$past_texts
          code = Kernel.pbMessageFreeText(_INTL("What code would you like to run?"), "", false, 999, 500, $past_texts)
          $past_texts.unshift(code) unless code == ""
          $past_texts.uniq!
          eval(code)
          Input.text_input = false
        rescue
          pbPrintException($!)
          Input.text_input = false
        end
      end
    end
  end
end

# for a soft-reset, let the speed-up persist
Graphics.frame_rate = 40 * $Settings.turboSpeedMultiplier if $speed_up

def pbDynamicTurbo(value)
  value = 1.0 - value if $speed_up
  Graphics.frame_rate = 40 * (1 + (value * ($Settings.turboSpeedMultiplier - 1)))
end

module Graphics
  @@turboIcon = Sprite.new(nil)
  @@turboIcon.ox = 0
  @@turboIcon.oy = 0
  @@turboIcon.x = 450
  @@turboIcon.y = 320
  @@turboIcon.z = 100000

  if defined?(@@opacity)
    self.autoToggleTurbo(@@overworldTurbo) if $speed_up != @@overworldTurbo
  else
    $speed_up = false
    @@opacity = 0
    @@battleTurbo = false
    @@overworldTurbo = false
  end

  class << self
    alias __turbo_update update unless method_defined?(:__turbo_update)
  end

  def self.toggleTurbo
    # Enabling turbo in battle only affects battles.
    # Disabling turbo in battle or toggling it in overworld affects both.
    if $game_switches && $game_switches[:In_Battle]
      @@battleTurbo = !@@battleTurbo
      @@overworldTurbo = false if !@@battleTurbo
      @@overworldTurbo = @@battleTurbo unless Reborn
      self.autoToggleTurbo(@@battleTurbo)
    else
      @@overworldTurbo = !@@overworldTurbo
      @@battleTurbo = @@overworldTurbo
      self.autoToggleTurbo(@@overworldTurbo)
    end
  end

  def self.turboIcon
    icon = $speed_up ? "Graphics/Icons/turbo_on.png" : "Graphics/Icons/turbo_off.png"
    @@turboIcon.bitmap = RPG::Cache.load_bitmap(icon) if fileExists?(icon)
    @@turboIcon.opacity = 255
    @@opacity = 255
    pbSEPlay($speed_up ? "turbo_on" : "turbo_off", 80)
  end

  def self.autoToggleTurbo(turbo)
    if turbo
      Graphics.frame_rate = 40 * $Settings.turboSpeedMultiplier
      $speed_up = true
    else
      Graphics.frame_rate = 40
      $speed_up = false
    end
  end

  def self.update
    adjustment = $speed_up ? 1.0 / $Settings.turboSpeedMultiplier : 1
    adjustment *= 3.5
    @@opacity = [0, @@opacity - adjustment].max
    @@turboIcon.opacity = @@opacity
    __turbo_update
  end

  Events.onStartBattle += proc { |sender, e|
    if $speed_up != @@battleTurbo
      self.autoToggleTurbo(@@battleTurbo)
      self.turboIcon
    end
  }

  Events.onEndBattle += proc { |sender, e|
    if $speed_up != @@overworldTurbo
      self.autoToggleTurbo(@@overworldTurbo)
      self.turboIcon
    end
  }
end

def pbSetWindowText(string = System.game_title)
  System.set_window_title(string)
end

# I don't think this does anything, but the game doesn't load if I don't add it
class ControlConfig
  attr_reader :controlAction
  attr_accessor :keyCode

  def initialize(controlAction, defaultKey)
    @controlAction = controlAction
    @keyCode = Keys.getKeyCode(defaultKey)
  end

  def keyName
    return Keys.getKeyName(@keyCode)
  end
end
