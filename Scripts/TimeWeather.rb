#===============================================================================
# ** Scene_TimeWeather
# ** Created by BlueTowel
# ** Featuring RestToWait by Waynolt
#-------------------------------------------------------------------------------
#  This class performs menu screen processing.
#===============================================================================
class Scene_TimeWeather
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
    @sprites["background"].setBitmap("Graphics/Pictures/Pokegear/TimeWeather/navbgtw")
    @sprites["background"].z = 255
    @sprites["header"] = Window_UnformattedTextPokemon.newWithSize(_INTL("Time & Weather"), -12, -18, 216, 64, @viewport)
    @sprites["header"].baseColor = Color.new(248, 248, 248)
    @sprites["header"].shadowColor = Color.new(0, 0, 0)
    @sprites["header"].windowskin = nil

    outdoor = $cache.mapdata[$game_map.map_id].Outdoor

    # These double as the tail of a bitmap filename (weather_Clear.png), so they
    # have to stay in English: translating them makes the path point at a file
    # that does not exist, and GifBitmap swallows the failure, so the icon just
    # silently disappears. Translate at the point of display instead.
    def getWeatherNow(weatherVar)
      return [
        "Clear", "Rain", "Thunderstorm", "Snow", "Sandstorm",
        "HarshSun", "Windy", "HeavyRain", "Blizzard", "Unknown"
      ][weatherVar]
    end

    !outdoor ? @weatherType = "Unknown" : @weatherType = getWeatherNow($game_variables[:Current_Weather])

    @sprites["weatherNow"] = IconSprite.new(112, 240)
    @sprites["weatherNow"].setBitmap(sprintf("Graphics/Pictures/Pokegear/TimeWeather/weather_%s", @weatherType))
    @sprites["weatherNow"].z = 255

    # English for the same reason as getWeatherNow above.
    def getWeatherNext(weatherVar)
      return [
        "Clear", "Rain", "Thunderstorm", "Snow", "Sandstorm",
        "HarshSun", "Windy", "HeavyRain", "Blizzard", "Unknown"
      ][weatherVar]
    end

    !outdoor ? @nextWeatherType = "Unknown" : @nextWeatherType = getWeatherNext($game_variables[:Set_Weather_1])

    @sprites["weatherNext"] = IconSprite.new(304, 240)
    @sprites["weatherNext"].setBitmap(sprintf("Graphics/Pictures/Pokegear/TimeWeather/weather_%s", @nextWeatherType))
    @sprites["weatherNext"].z = 255

    @sprites["timeFrame"] = IconSprite.new(182, 50)
    @sprites["timeFrame"].setBitmap(sprintf("Graphics/Pictures/Pokegear/TimeWeather/timeFrame"))
    @sprites["timeFrame"].z = 0

    @sprites["weatherFrame1"] = IconSprite.new(112, 240)
    @sprites["weatherFrame1"].setBitmap(sprintf("Graphics/Pictures/Pokegear/TimeWeather/weatherFrame"))
    @sprites["weatherFrame1"].z = 0

    @sprites["weatherFrame2"] = IconSprite.new(304, 240)
    @sprites["weatherFrame2"].setBitmap(sprintf("Graphics/Pictures/Pokegear/TimeWeather/weatherFrame"))
    @sprites["weatherFrame2"].z = 0

    pbTimeText
    # intro tts (for non-selectable things)
    time = pbGetTimeNow
    tts(time.strftime("%A %e %B"))
    tts("Current Time: " + time.strftime("%k %M"))
    tts("Location: " + $game_map.name.to_s)
    tts("Current Weather: " + @weatherType.to_s)
    tts("Weather at " + Time.at($game_variables[:Set_Weather_2]).strftime("%H:%M") + ": " + @nextWeatherType.to_s)
    @selection = 0

    # Execute transitionz
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
  # * Display Time
  #-----------------------------------------------------------------------------

  def pbTimeText
    @sprites["timenow"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport) if !@sprites["timenow"] || @sprites["timenow"].disposed?
    timenow = @sprites["timenow"].bitmap

    time = pbGetTimeNow
    timeOfDay = "Day"
    timeOfDay = "Night" if PBDayNight.isNight?(time)
    timeOfDay = "Evening" if PBDayNight.isEvening?(time)
    timeOfDay = "Morning" if PBDayNight.isMorning?(time)
    presentTime = time.strftime("%H:%M")
    # strftime only knows English weekday and month names, so the pieces go
    # through the message table and the template decides the order - Japanese
    # puts the month before the day and the weekday in brackets after it.
    todaysDate = _INTL("{1}  {2}  {3}",
                       _INTL(time.strftime("%a")),
                       time.strftime("%e").strip,
                       _INTL(time.strftime("%b")))
    todaysDate += "  -  " + _INTL(timeOfDay)

    baseColor = Color.new(248, 248, 248)
    textPositions = [[presentTime, 256, 44, 2, baseColor],]
    timenow.font.name = "PokemonEmerald"
    timenow.font.size = 80
    pbDrawTextPositions(timenow, textPositions)

    @sprites["datenow"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport) if !@sprites["datenow"] || @sprites["datenow"].disposed?
    datenow = @sprites["datenow"].bitmap
    baseColor = Color.new(248, 248, 248)
    textPositions = [[todaysDate, 256, 110, 2, baseColor],]
    datenow.font.name = "PokemonEmerald"
    datenow.font.size = 26
    pbDrawTextPositions(datenow, textPositions)

    currentLocation = _INTL('{1}', $game_map.name)

    @sprites["location"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport) if !@sprites["location"] || @sprites["location"].disposed?
    location = @sprites["location"].bitmap
    baseColor = Color.new(248, 248, 248)
    textPositions = [[currentLocation, 256, 153, 2, baseColor],]
    location.font.name = "PokemonEmerald"
    location.font.size = 42
    pbDrawTextPositions(location, textPositions)

    @sprites["locPin"] = IconSprite.new(256 - (location.text_size(currentLocation).width / 2) - 34, 153)
    @sprites["locPin"].setBitmap("Graphics/Pictures/Pokegear/TimeWeather/locPin")
    @sprites["locPin"].z = 255

    weatherChangeTime = Time.at($game_variables[:Set_Weather_2]).strftime("%H:%M")

    @sprites["weather"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport) if !@sprites["weather"] || @sprites["weather"].disposed?
    weather = @sprites["weather"].bitmap
    baseColor = Color.new(248, 248, 248)
    textPositions = [[weatherChangeTime, 391, 210, 0, baseColor]]
    weather.font.name = "PokemonEmerald"
    weather.font.size = 36
    pbDrawTextPositions(weather, textPositions)
  end

  #-----------------------------------------------------------------------------
  # * Rest to Wait
  #-----------------------------------------------------------------------------

  def pbRestTime
    if $Settings.unrealTimeDiverge == 0
      Kernel.pbMessage(_INTL('Enable Unreal Time in Options to use the waiting feature.'))
      return
    end

    timePast = getHowLongToRestFor() # Returns the number of real time seconds that are supposed to have been passed
    return nil if timePast == 0

    $gameTimeLastCheck -= timePast
    $game_screen.getTimeCurrent() # Will update the time
    pbFadeOutAndHide(@sprites)
    $scene = Scene_TimeWeather.new
    Kernel.pbMessage(_INTL('Please exit the area to properly update its events.'))
  end

  def getHowLongToRestFor
    choice = Kernel.pbMessage(
      _INTL('Do you wish to rest for a while or until some time?'),
      [
        _INTL('For a while.'),
        _INTL('Until some time.'),
        _INTL('I changed my mind.')
      ],
      3
    )
    return getHowLongToRestForAsPeriod if choice == 0
    return getHowLongToRestForAsPointInTime if choice == 1

    return 0
  end

  def getHowLongToRestForAsPeriod
    params = ChooseNumberParams.new
    params.setRange(0, 9999)
    params.setDefaultValue(0)
    hours = Kernel.pbMessageChooseNumber(_INTL('How many hours would you like to rest?'), params)
    seconds = hours * 3600
    return seconds.to_f / $game_screen.getTimeScale().to_f
  end

  def getHowLongToRestForAsPointInTime
    now = $game_screen.getTimeCurrent()
    # Get the target weekday
    choiceWday = Kernel.pbMessage(
      _INTL('When would you like to wake up?'),
      [
        _INTL('Sunday'),
        _INTL('Monday'),
        _INTL('Tuesday'),
        _INTL('Wednesday'),
        _INTL('Thursday'),
        _INTL('Friday'),
        _INTL('Saturday'),
        _INTL('Nevermind')
      ],
      8
    )
    if choiceWday == 7
      return 0
    end

    daysPast = choiceWday - now.wday
    while daysPast < 0
      daysPast += 7
    end
    # Get the target hour
    params = ChooseNumberParams.new
    params.setRange(0, 23)
    params.setDefaultValue(now.hour)
    choiceHour = Kernel.pbMessageChooseNumber(_INTL('At which hour?'), params)
    hoursPast = choiceHour - now.hour
    # Combine the two
    hours = daysPast * 24 + hoursPast
    while hours < 0
      # Go to the next week
      hours += 168 # 24*7 = 168
    end
    seconds = hours * 3600 # 60*60 = 3600
    return seconds.to_f / $game_screen.getTimeScale().to_f
  end

  def pbChangeWeather
    choiceWType = Kernel.pbMessage("Select weather type", [_INTL("Clear"), _INTL("Rain"), _INTL("Storm"), _INTL("Snow"), _INTL("Sandstorm"), _INTL("Sunny"), _INTL("Windy"), _INTL("Heavy rain"), _INTL("Blizzard"), _INTL("Cancel")], 10)
    return if choiceWType == 9

    $game_variables[9] = choiceWType
    $game_screen.ChangeWeatherPlan(choiceWType)
    playWeatherOrDiveBGS
  end

  def pbRerollWeather
    $game_screen.RerollWeather
    Kernel.pbMessage("Next week's weather: dry spell") if $game_variables[:Next_Weather_Archetype] == 1
    Kernel.pbMessage("Next week's weather: showers") if $game_variables[:Next_Weather_Archetype] == 2
    Kernel.pbMessage("Next week's weather: chilly") if $game_variables[:Next_Weather_Archetype] == 3
    Kernel.pbMessage("Next week's weather: wet") if $game_variables[:Next_Weather_Archetype] == 4
    Kernel.pbMessage("Next week's weather: blizzard") if $game_variables[:Next_Weather_Archetype] == 5
    Kernel.pbMessage("Next week's weather: variety") if $game_variables[:Next_Weather_Archetype] == 6
  end

  #-----------------------------------------------------------------------------
  # * Frame Update
  #-----------------------------------------------------------------------------
  def update
    # Update windows
    pbUpdateSpriteHash(@sprites)
    updateCustom
    return
  end
  #-----------------------------------------------------------------------------
  # * Frame Update (when command window is active)
  #-----------------------------------------------------------------------------

  # Commands

  def updateCustom
    update = false # for tts
    # selection (0=empty, 1=time, 2=current weather, 3=next weather)
    if Input.trigger?(Input::UP) || Input.repeat?(Input::UP)
      pbPlayCursorSE()
      @selection > 1 ? @selection -= 1 : @selection = 3
      update = true
    elsif Input.trigger?(Input::DOWN) || Input.repeat?(Input::DOWN)
      pbPlayCursorSE()
      @selection < 3 ? @selection += 1 : @selection = 1
      update = true
    elsif Input.trigger?(Input::LEFT) || Input.repeat?(Input::LEFT)
      pbPlayCursorSE()
      @selection > 1 ? @selection -= 1 : @selection = 3
      update = true
    elsif Input.trigger?(Input::RIGHT) || Input.repeat?(Input::RIGHT)
      pbPlayCursorSE()
      @selection < 3 ? @selection += 1 : @selection = 1
      update = true
    end

    if @selection == 1
      # display timeframe, hide other frames
      @sprites["timeFrame"].z = 255
      @sprites["weatherFrame1"].z = 0
      @sprites["weatherFrame2"].z = 0
      if update
        tts("Current Time: " + pbGetTimeNow.strftime("%k %M"))
      end
    elsif @selection == 2
      # display weatherframe at current, hide other frames
      @sprites["timeFrame"].z = 0
      @sprites["weatherFrame1"].z = 255
      @sprites["weatherFrame2"].z = 0
      if update
        tts("Current Weather: " + @weatherType)
      end
    elsif @selection == 3
      # display weatherframe at next, hide other frames
      @sprites["timeFrame"].z = 0
      @sprites["weatherFrame1"].z = 0
      @sprites["weatherFrame2"].z = 255
      if update
        tts("Weather at " + Time.at($game_variables[:Set_Weather_2]).strftime("%k:%M") + ": " + @nextWeatherType.to_s)
      end
    end

    if Input.trigger?(Input::B)
      pbPlayCancelSE()
      $scene = Scene_Pokegear.new(:weather)
      return
    end
    if Input.trigger?(Input::C)
      case @selection
        when 0
          if $game_switches[:Unreal_Time]
            pbRestTime
          else
            Kernel.pbMessage("Remember to take regular breaks!")
          end
        when 1
          if $game_switches[:Unreal_Time]
            pbRestTime
          else
            Kernel.pbMessage("Remember to take regular breaks!")
          end
        when 2
          if $game_switches[:Weather_password] || $DEBUG
            pbChangeWeather
          else
            Kernel.pbMessage(@weatherType)
          end
        when 3
          if $game_switches[:Weather_password] || $DEBUG
            pbRerollWeather
          else
            Kernel.pbMessage(@nextWeatherType)
          end
      end
    end
  end
end
