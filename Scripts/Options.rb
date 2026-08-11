class Window_PokemonOption < Window_DrawableCommand
  attr_reader :mustUpdateOptions
  attr_accessor :options

  def initialize(options, x, y, width, height)
    @options = options
    @nameBaseColor = Color.new(24 * 8, 15 * 8, 0)
    @nameShadowColor = Color.new(31 * 8, 22 * 8, 10 * 8)
    @selBaseColor = Color.new(31 * 8, 6 * 8, 3 * 8)
    @selShadowColor = Color.new(31 * 8, 17 * 8, 16 * 8)
    @optvalues = []
    @mustUpdateOptions = false
    for i in 0...@options.length
      @optvalues[i] = 0
    end
    super(x, y, width, height)
  end

  def [](i)
    return @optvalues[i]
  end

  def []=(i, value)
    @optvalues[i] = value
    refresh
  end

  def itemCount
    return @options.length + 1
  end

  def drawItem(index, count, rect)
    rect = drawCursor(index, rect)
    optionname = (index == @options.length) ? _INTL("Confirm") : @options[index].name
    optionwidth = (rect.width * 9 / 20)
    pbDrawShadowText(self.contents, rect.x, rect.y, optionwidth, rect.height, optionname, @nameBaseColor, @nameShadowColor)
    self.contents.draw_text(rect.x, rect.y, optionwidth, rect.height, optionname)
    return if index == @options.length

    if @options[index].is_a?(EnumOption)
      if @options[index].values.length > 1
        totalwidth = 0
        for value in @options[index].values
          totalwidth += self.contents.text_size(value).width
        end
        spacing = (optionwidth - totalwidth) / (@options[index].values.length - 1)
        spacing = 0 if spacing < 0
        xpos = optionwidth + rect.x
        ivalue = 0
        for value in @options[index].values
          pbDrawShadowText(
            self.contents, xpos, rect.y, optionwidth, rect.height, value,
            (ivalue == self[index]) ? @selBaseColor : self.baseColor,
            (ivalue == self[index]) ? @selShadowColor : self.shadowColor
          )
          self.contents.draw_text(xpos, rect.y, optionwidth, rect.height, value)
          xpos += self.contents.text_size(value).width
          xpos += spacing
          ivalue += 1
        end
      else
        pbDrawShadowText(self.contents, rect.x + optionwidth, rect.y, optionwidth, rect.height, optionname, self.baseColor, self.shadowColor)
      end
    elsif @options[index].is_a?(NumberOption)
      value = _ISPRINTF("{1:d}", @options[index].optstart + self[index])
      value = _ISPRINTF("{1:.1f}x", @options[index].optstart + self[index]) if @options[index].optinc < 1
      xpos = optionwidth + rect.x
      pbDrawShadowText(self.contents, xpos, rect.y, optionwidth, rect.height, value, @selBaseColor, @selShadowColor)
    else
      value = @options[index].values[self[index]]
      xpos = optionwidth + rect.x
      pbDrawShadowText(self.contents, xpos, rect.y, optionwidth, rect.height, value, @selBaseColor, @selShadowColor)
      self.contents.draw_text(xpos, rect.y, optionwidth, rect.height, value)
    end
  end

  def update
    oldindex = self.index
    @mustUpdateOptions = false
    super
    dorefresh = self.index != oldindex
    if self.active && self.index < @options.length
      if Input.repeat?(Input::LEFT)
        self[self.index] = @options[self.index].prev(self[self.index])
        dorefresh = true
        @mustUpdateOptions = true
      elsif Input.repeat?(Input::RIGHT)
        self[self.index] = @options[self.index].next(self[self.index])
        dorefresh = true
        @mustUpdateOptions = true
      end
    end
    if self.active && self.index <= @options.length
      if Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
        @mustUpdateOptions = true
      end
    end
    refresh if dorefresh
  end
end

module PropertyMixin
  def get
    @getProc ? @getProc.call() : nil
  end

  def set(value)
    @setProc.call(value) if @setProc
  end
end

class EnumOption
  include PropertyMixin
  attr_reader :values
  attr_reader :name
  attr_reader :description

  def initialize(name, options, getProc, setProc, description = "")
    @values = options
    @name = name
    @getProc = getProc
    @setProc = setProc
    @description = description
  end

  def next(current)
    index = current + 1
    index = @values.length - 1 if index > @values.length - 1
    tts(@values[index])
    return index
  end

  def prev(current)
    index = current - 1
    index = 0 if index < 0
    tts(@values[index])
    return index
  end

  def current(index)
    tts(@values[index])
  end
end

class NumberOption
  include PropertyMixin
  attr_reader :name
  attr_reader :optstart
  attr_reader :optinc
  attr_reader :description

  def initialize(name, format, optstart, optend, optinc, getProc, setProc, description = "")
    @name = name
    @format = format
    @optstart = optstart
    @optend = optend
    @optinc = optinc
    @getProc = getProc
    @setProc = setProc
    @description = description
  end

  def next(current)
    index = current + @optstart
    index += @optinc
    if index > @optend
      index = @optstart
    end
    tts(index.to_s)
    return index - @optstart
  end

  def prev(current)
    index = current + @optstart
    index -= @optinc
    if index < @optstart
      index = @optend
    end
    tts(index.to_s)
    return index - @optstart
  end

  def current(index)
    tts((index + @optstart).to_s)
  end
end

def pbSettingToTextSpeed(speed)
  return 2 if speed == 0
  return 1 if speed == 1
  return -2 if speed == 2
  return MessageConfig::TextSpeed if MessageConfig::TextSpeed

  return Graphics.frame_rate > 40 ? -2 : 1
end

module MessageConfig
  def self.pbDefaultSystemFrame
    return pbResolveBitmap(TextFrames[$Settings.frame]) || ""
  end

  def self.pbDefaultSpeechFrame
    return pbResolveBitmap("Graphics/Windowskins/" + SpeechFrames[$Settings.textskin]) || ""
  end

  def self.pbDefaultSystemFontName
    return MessageConfig.pbTryFonts(VersionStyles[0][0], "Arial Narrow", "Arial")
  end

  def self.pbDefaultTextSpeed
    return pbSettingToTextSpeed($Settings.textspeed)
  end

  def pbGetSystemTextSpeed
    return $Settings.textspeed
  end
end

class PokemonOptions
  attr_accessor :textspeed
  attr_accessor :textskipwait
  attr_accessor :volume
  attr_accessor :sevolume
  attr_accessor :bagsorttype
  attr_accessor :battlescene
  attr_accessor :battlestyle
  attr_accessor :nicknames
  attr_accessor :frame
  attr_accessor :textskin
  attr_accessor :font
  attr_accessor :screensize
  attr_accessor :language
  attr_accessor :border
  attr_accessor :backup
  attr_accessor :maxBackup
  attr_accessor :field_effects_highlights
  attr_accessor :remember_commands
  attr_accessor :photosensitive
  attr_accessor :autosave
  attr_accessor :autorunning
  attr_accessor :bike_and_surf_music
  attr_accessor :streamermode
  attr_accessor :unrealTimeDiverge
  attr_accessor :unrealTimeClock
  attr_accessor :unrealTimeTimeScale
  attr_accessor :audiotype
  attr_accessor :turboSpeedMultiplier
  attr_accessor :discordRPC
  attr_accessor :frameskip
  attr_accessor :keyboard
  attr_accessor :performanceMode
  attr_accessor :dynamicTextbox

  def initialize
    fixMissingValues
  end

  def fixMissingValues
    @textspeed      = 1 if @textspeed.nil? # Text speed (0=slow, 1=mid, 2=fast)
    @textskipwait   = 0 if @textskipwait.nil? # Wait for text skip (0 is on, 1 is off)
    @volume              = 100 if @volume.nil? # Volume (0 - 100)
    @sevolume            = 100 if @sevolume.nil? # Volume (0 - 100)
    @audiotype   = 0 if @audiotype.nil? # Stereo / Mono audio (0 / 1)
    @battlescene = 0 if @battlescene.nil? # Battle scene (animations) (0=on, 1=off)
    @battlestyle = 0 if @battlestyle.nil? # Battle style (0=shift, 1=set)
    @nicknames   = 0 if @nicknames.nil? # Give nicknames (0=on, 1=off)
    @frame       = 0 if @frame.nil? # Default window frame (see also TextFrames)
    @textskin    = 0 if @textskin.nil? # Speech frame
    @font        = 0 if @font.nil? # Font (see also VersionStyles)
    @screensize  = DEFAULTSCREENZOOM.floor.to_i if @screensize.nil? # 0=half size, 1=full size, 2=double size
    @border      = 0 if @border.nil? # Screen border (0=off, 1=on)
    @language    = 0 if @language.nil? # Language (see also LANGUAGES in script PokemonSystem)
    @backup      = 0 if @backup.nil? # Backup on/off
    @maxBackup   = 50 if @maxBackup.nil?
    @field_effects_highlights = 0 if @field_effects_highlights.nil? # Field effect UI highlights on/off
    @remember_commands        = 0 if @remember_commands.nil?
    @photosensitive           = 0 if @photosensitive.nil? # a mode that disables flashes and shakes (0=off, 1=on)
    @autorunning              = 0 if @autorunning.nil? # 0 is on, 1 is off
    @bike_and_surf_music      = 0 if @bike_and_surf_music.nil? # 0 is off, 1 is on
    @streamermode             = 0 if @streamermode.nil?
    @unrealTimeDiverge        = 1 if @unrealTimeDiverge.nil? # Unreal Time (0=off, 1=on)
    @unrealTimeClock          = 2 if @unrealTimeClock.nil? # Unreal Time Clock (0=always, 1=pause menu, 2=pokegear only)
    @unrealTimeTimeScale      = 30 if @unrealTimeTimeScale.nil? # Unreal Time Timescale (default 30x real time)
    @turboSpeedMultiplier     = 3.0 if @turboSpeedMultiplier.nil? # Game speed multiplier in turbo mode
    @discordRPC               = 1 if @discordRPC.nil? # Controls Discord rich presence updates (0=off, 1=on)
    @frameskip                = 0 if @frameskip.nil? # mkxp-z frameskip feature (0=off, 1=on)
    @keyboard                 = 0 if @keyboard.nil? # 0 is on, 1 is off
    @performanceMode          = 1 if @performanceMode.nil? # 0 is on, 1 is off
    @dynamicTextbox           = 0 if @dynamicTextbox.nil? # textbox height adjusts to text (0=off, 1=on)
  end

  def useKeyboard?
    return $Settings.keyboard == 0
  end
end

class PokemonOptionScene
  def initialize
    @title = "Options"
  end

  def initOptions
    optionList = []
    if $joiplay
      optionList.push EnumOption.new(
        _INTL("Use Keyboard"), [_INTL("On"), _INTL("Off")],
        proc { $Settings.keyboard },
        proc { |value| $Settings.keyboard = value }
      )
      optionList.push EnumOption.new(
        _INTL("Performance Mode"), [_INTL("On"), _INTL("Off")],
        proc { $Settings.performanceMode },
        proc { |value| $Settings.performanceMode = value },
        "Disables animated tiles and day/night tint to prevent lag. Requires a reload to take effect."
      )
    end
    optionList.push EnumOption.new(
      _INTL("Autorunning"), [_INTL("On"), _INTL("Off")],
      proc { $Settings.autorunning },
      proc { |value| $Settings.autorunning = value }
    )
    optionList.push EnumOption.new(
      _INTL("Text Speed"), [_INTL("Normal"), _INTL("Fast"), _INTL("Max")],
      proc { $Settings.textspeed },
      proc { |value|
        $Settings.textspeed = value
        MessageConfig.pbSetTextSpeed(pbSettingToTextSpeed(value))
      }
    )
    optionList.push EnumOption.new(
      _INTL("Text Skip Wait"), [_INTL("On"), _INTL("Off")],
      proc { $Settings.textskipwait },
      proc { |value| $Settings.textskipwait = value },
      "Enables a delay before text skipping begins."
    )
    optionList.push NumberOption.new(
      _INTL("BGM Volume"), _INTL("Type %d"), 0, 100, 1,
      proc { $Settings.volume },
      proc { |value|
        $Settings.volume = value
        if $game_map && $game_system.playing_bgm
          bgm_new_volume = $game_system.playing_bgm
          bgm_new_volume.volume = $Settings.volume
          $game_system.bgm_play_internal(bgm_new_volume, $game_system.bgm_position)
        end
      },
      "Volume of Background Music."
    )
    optionList.push NumberOption.new(
      _INTL("SE Volume"), _INTL("Type %d"), 0, 100, 1,
      proc { $Settings.sevolume },
      proc { |value| $Settings.sevolume = value },
      "Volume of Sound Effects."
    )
    optionList.push EnumOption.new(
      _INTL("Sound"), [_INTL("Stereo"), _INTL("Mono")],
      proc { $Settings.audiotype },
      proc { |value| $Settings.audiotype = value },
      "Audio plays from both or one ear"
    )
    optionList.push EnumOption.new(
      _INTL("Bike and Surf Music"), [_INTL("Off"), _INTL("On")],
      proc { $Settings.bike_and_surf_music },
      proc { |value| $Settings.bike_and_surf_music = value },
      "Enables bike and surf music to play"
    )
    optionList.push EnumOption.new(
      _INTL("Battle Scene"), [_INTL("On"), _INTL("Off")],
      proc { $Settings.battlescene },
      proc { |value| $Settings.battlescene = value },
      "Show animations during battle."
    )
    optionList.push EnumOption.new(
      _INTL("Battle Style"), [_INTL("Shift"), _INTL("Set")],
      proc { $Settings.battlestyle },
      proc { |value| $Settings.battlestyle = value }
    )
    optionList.push EnumOption.new(
      _INTL("Give Nicknames"), [_INTL("On"), _INTL("Off")],
      proc { $Settings.nicknames },
      proc { |value| $Settings.nicknames = value },
      "Choose whether to be prompted to give a nickname to a Pokémon when you obtain it."
    )
    optionList.push EnumOption.new(
      _INTL("Photosensitivity"), [_INTL("Off"), _INTL("On")],
      proc { $Settings.photosensitive },
      proc { |value| $Settings.photosensitive = value },
      "Disables battle animations, screen flashes and shakes for photosensitivity."
    )
    optionList.push EnumOption.new(
      _INTL("Streamer Mode"), [_INTL("Off"), _INTL("On")],
      proc { $Settings.streamermode },
      proc { |value| $Settings.streamermode = value },
      "Hides private information for safety and compatibility."
    )
    # options currently running every time the user accesses the options menu and does anything
    if defined?(DiscordAppID) && DiscordAppID && !$joiplay
      optionList.push EnumOption.new(
        _INTL("Discord Activity"), [_INTL("Off"), _INTL("On")],
        proc { $Settings.discordRPC },
        proc { |value| $Settings.discordRPC = value },
        "Controls Discord rich presence. If on, shows game info on Discord."
      )
    end
    # JoiPlay version is always in Portable mode
    unless $joiplay
      optionList.push EnumOption.new(
        _INTL("Portable Mode"), [_INTL("Off"), _INTL("On")],
        proc { RTP.isPortable ? 1 : 0 },
        proc { |value|
          value == 1 ? RTP.makePortable : RTP.makeNonPortable
        },
        "Keeps save data in the game EXE folder."
      )
      optionList.push EnumOption.new(
        _INTL("Frame skip"), [_INTL("Off"), _INTL("On")],
        proc { $Settings.frameskip },
        proc { |value|
          $Settings.frameskip = value
          Graphics.frameskip = value == 1
        },
        "Allows turbo speed to go beyond refresh rate by skipping frames."
      )
    end
    optionList.push NumberOption.new(
      _INTL("Turbo Speed"), _INTL("Type %d"), 1, 10, 0.1,
      proc { $Settings.turboSpeedMultiplier - 1 },
      proc { |value|
        $Settings.turboSpeedMultiplier = value + 1
        if $speed_up
          # Intentionally calling it twice to apply the change without toggling turbo
          Graphics.toggleTurbo
          Graphics.toggleTurbo
        end
      },
      "Game speed multiplier while in Turbo Mode. Higher values require Frame skip to work."
    )
    optionList.push NumberOption.new(
      _INTL("Speech Frame"), _INTL("Type %d"), 1, SpeechFrames.length, 1,
      proc { $Settings.textskin },
      proc { |value|
        $Settings.textskin = value
        MessageConfig.pbSetSpeechFrame(
          "Graphics/Windowskins/" + SpeechFrames[value]
        )
      },
      proc { _INTL("Speech frame {1}.", 1 + $Settings.textskin) }
    )
    optionList.push NumberOption.new(
      _INTL("Menu Frame"), _INTL("Type %d"), 1, TextFrames.length, 1,
      proc { $Settings.frame },
      proc { |value|
        $Settings.frame = value
        MessageConfig.pbSetSystemFrame(TextFrames[value])
      },
      proc { _INTL("Menu frame {1}.", 1 + $Settings.frame) }
    )
    optionList.push EnumOption.new(
      _INTL("Dynamic Textbox"), [_INTL("Off"), _INTL("On")],
      proc { $Settings.dynamicTextbox },
      proc { |value| $Settings.dynamicTextbox = value },
      "Adjusts textbox height according to text."
    )
    optionList.push EnumOption.new(
      _INTL("Field UI Highlights"), [_INTL("On"), _INTL("Off")],
      proc { $Settings.field_effects_highlights },
      proc { |value| $Settings.field_effects_highlights = value },
      "Shows boxes around move if boosted or decreased by field effect."
    )
    optionList.push EnumOption.new(
      _INTL("Battle Cursor"), [_INTL("Fight"), _INTL("Last Used")],
      proc { $Settings.remember_commands },
      proc { |value| $Settings.remember_commands = value },
      "Sets default position of cursor in battle."
    )
    optionList.push EnumOption.new(
      _INTL("Backup"), [_INTL("On"), _INTL("Off")],
      proc { $Settings.backup },
      proc { |value| $Settings.backup = value },
      "Preserves overwritten files on each save for later recovery."
    )
    optionList.push NumberOption.new(
      _INTL("Max Backup Number"), _INTL("Type %d"), 1, 101, 1,
      proc { $Settings.maxBackup == 999_999 ? 100 : $Settings.maxBackup },
      proc { |value| $Settings.maxBackup = value == 100 ? 999_999 : value }, # +1
      "The maximum number of backup save files to keep. (101 is infinite)"
    )
    unless $joiplay
      optionList.push EnumOption.new(
        _INTL("Screen Size"), [_INTL("XS"), _INTL("S"), _INTL("M"), _INTL("L"), _INTL("XL"), _INTL("XXL"), _INTL("Full")],
        proc { $Settings.screensize },
        proc { |value|
          oldvalue = $Settings.screensize
          $Settings.screensize = value
          if value != oldvalue
            pbSetResizeFactor($Settings.screensize)
          end
        }
      )
      unless Desolation
        optionList.push EnumOption.new(
          _INTL("Screen Border"), [_INTL("Off"), _INTL("On")],
          proc { $Settings.border },
          proc { |value|
            oldvalue = $Settings.border
            $Settings.border = value
            if value != oldvalue
              pbSetResizeFactor($Settings.screensize)
            end
          }
        )
      end
    end
    if $game_switches && $game_switches[:Unreal_Time]
      optionList.push EnumOption.new(
        _INTL("Show Clock"), [_INTL("Always"), _INTL("Menu"), _INTL("Gear")],
        proc { $Settings.unrealTimeClock },
        proc { |value| $Settings.unrealTimeClock = value },
        "Shows an in-game clock that displays the current time."
      )
      optionList.push EnumOption.new(
        _INTL("Unreal Time"), [_INTL("Off"), _INTL("On")],
        proc { $Settings.unrealTimeDiverge },
        proc { |value| $Settings.unrealTimeDiverge = value },
        "Uses in-game time instead of computer clock."
      )
      optionList.push NumberOption.new(
        _INTL("Unreal Time Scale"), _INTL("Type %d"), 1, 60, 1,
        proc { $Settings.unrealTimeTimeScale - 1 },
        proc { |value| $Settings.unrealTimeTimeScale = value + 1 },
        "Sets the rate at which unreal time passes."
      )
    end
    return optionList
  end

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end

  def pbStartScene
    @optionList = initOptions
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL(@title), 0, 0, Graphics.width, 64, @viewport
    )
    @sprites["textbox"] = Kernel.pbCreateMessageWindow
    @sprites["textbox"].letterbyletter = false
    # @sprites["textbox"].text=_INTL("Speech frame {1}.",1+$Settings.textskin)
    @sprites["option"] = Window_PokemonOption.new(
      @optionList, 0,
      @sprites["title"].height, Graphics.width,
      Graphics.height - @sprites["title"].height - @sprites["textbox"].height
    )
    @sprites["option"].viewport = @viewport
    @sprites["option"].visible = true
    # Get the values of each option
    for i in 0...@optionList.length
      @sprites["option"][i] = (@optionList[i].get || 0)
    end
    pbDeactivateWindows(@sprites)
    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  def pbOptions
    pbActivateWindow(@sprites, "option") {
      lastread = nil
      if @sprites["option"].options
        opt = @sprites["option"].options[0]
        tts(opt.name)
        opt.current(@sprites["option"][0])
        lastread = opt.name
      end
      loop do
        Graphics.update
        Input.update
        pbUpdate
        if @sprites["option"].mustUpdateOptions
          # Set the values of each option
          for i in 0...@optionList.length
            @optionList[i].set(@sprites["option"][i])
          end
          @sprites["textbox"].setSkin(MessageConfig.pbGetSpeechFrame())
          @sprites["textbox"].width = @sprites["textbox"].width # Necessary evil
          pbSetSystemFont(@sprites["textbox"].contents)
          opt = @sprites["option"].options[@sprites["option"].index]
          unless opt.nil?
            # The help line for each option is stored as a plain string on the
            # option, not run through _INTL where it is written, so it is
            # translated on the way to the textbox instead.
            if opt.description.is_a?(Proc)
              @sprites["textbox"].text = Kernel.pbLocalize(opt.description.call)
            else
              @sprites["textbox"].text = Kernel.pbLocalize(opt.description)
            end
            if opt.name != lastread
              tts(opt.name)
              opt.current(@sprites["option"][@sprites["option"].index])
              tts(@sprites["textbox"].text)
              lastread = opt.name
            end
          else
            lastread = "Confirm"
            @sprites["textbox"].text = _INTL("Exit and save selected settings.")
            tts("Confirm")
          end
        end
        if Input.trigger?(Input::B)
          saveClientData
          saveSettings

          if defined?(DiscordRPC) && !$joiplay
            if $Settings.discordRPC == 0
              DiscordRPC.end
            elsif $Settings.discordRPC == 1
              DiscordRPC.start
            end
          end

          break
        end
        if Input.trigger?(Input::C) && @sprites["option"].index == @optionList.length
          saveClientData
          saveSettings

          if defined?(DiscordRPC) && !$joiplay
            if $Settings.discordRPC == 0
              DiscordRPC.end
            elsif $Settings.discordRPC == 1
              DiscordRPC.start
            end
          end
          break
        end
      end
    }
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    # Set the values of each option
    for i in 0...@optionList.length
      @optionList[i].set(@sprites["option"][i])
    end
    Kernel.pbDisposeMessageWindow(@sprites["textbox"])
    pbDisposeSpriteHash(@sprites)
    pbRefreshSceneMap
    @viewport.dispose
  end
end

class PokemonOption
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen
    @scene.pbStartScene
    @scene.pbOptions
    @scene.pbEndScene
  end
end
