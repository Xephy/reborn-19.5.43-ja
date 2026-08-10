class PokemonLoadPanel < SpriteWrapper
  attr_reader :selected

  def initialize(index, title, isContinue, trainer, framecount, mapid, viewport = nil)
    super(viewport)
    @index = index
    @title = title
    @isContinue = isContinue
    @trainer = trainer
    @totalsec = (framecount || 0) / 40 # Graphics.frame_rate #Because Turbo exists
    @mapid = mapid
    @selected = (index == 0)
    @bgbitmap = AnimatedBitmap.new("Graphics/Pictures/loadPanels")
    @refreshBitmap = true
    @refreshing = false
    refresh
  end

  def dispose
    @bgbitmap.dispose
    self.bitmap.dispose
    super
  end

  def selected=(value)
    if @selected != value
      @selected = value
      @refreshBitmap = true
      refresh
    end
  end

  def pbRefresh
    # Draw contents
    @refreshBitmap = true
    refresh
  end

  def refresh
    return if @refreshing
    return if disposed?

    @refreshing = true
    if !self.bitmap || self.bitmap.disposed?
      self.bitmap = BitmapWrapper.new(@bgbitmap.width, 111 * 2)
      pbSetSystemFont(self.bitmap)
    end
    if @refreshBitmap
      @refreshBitmap = false
      self.bitmap.clear if self.bitmap
      if @isContinue
        self.bitmap.blt(0, 0, @bgbitmap.bitmap, Rect.new(0, (@selected ? 111 * 2 : 0), @bgbitmap.width, 111 * 2))
      else
        self.bitmap.blt(0, 0, @bgbitmap.bitmap, Rect.new(0, 111 * 2 * 2 + (@selected ? 23 * 2 : 0), @bgbitmap.width, 23 * 2))
      end
      textpos = []
      color1 = Color.new(232, 232, 232)
      color2 = Color.new(136, 136, 136)
      if @isContinue
        textpos.push([@title, 16 * 2, 4 * 2, 0, color1, color2])
        if @trainer.postgame != nil
          textpos.push([_INTL("Legendaries"), 16 * 2, 112, 0, color1, color2])
          textpos.push([@trainer.postgame.to_s, 120 * 2, 112, 1, color1, color2])
        else
          textpos.push([_INTL("Badges"), 16 * 2, 112, 0, color1, color2])
          textpos.push([@trainer.numbadges.to_s, 120 * 2, 112, 1, color1, color2])
        end
        textpos.push([_INTL("Pokédex"), 16 * 2, 72 * 2, 0, color1, color2])
        if [true, false].include?(@trainer.pokedex)
          seencount = 0
          for bool in @trainer.seen
            seencount += 1 if bool
          end
          textpos.push([seencount.to_s, 103 * 2, 72 * 2, 1, color1, color2])
        else
          if !@trainer.pokedex || !@trainer.pokedex.dexList
            textpos.push([0.to_s, 103 * 2, 72 * 2, 1, color1, color2])
          else
            textpos.push([_INTL("{1}/{2}", @trainer.pokedex.getOwnedCount, @trainer.pokedex.getSeenCount), 120 * 2, 72 * 2, 1, color1, color2])
          end
        end
        textpos.push([_INTL("Time"), 16 * 2, 88 * 2, 0, color1, color2])
        hour = @totalsec / 60 / 60
        min = @totalsec / 60 % 60
        if hour > 0
          textpos.push([_INTL("{1}h {2}m", hour, min), 120 * 2, 88 * 2, 1, color1, color2])
        else
          textpos.push([_INTL("{1}m", min), 120 * 2, 88 * 2, 1, color1, color2])
        end
        # if @trainer.isMale?
        #   textpos.push([@trainer.name,112,32*2,0,Color.new(56,160,248),Color.new(56,104,168)])
        # else
        textpos.push([@trainer.name, 112, 32 * 2, 0, Color.new(240, 72, 88), Color.new(100, 40, 40)])
        # end
        mapname = pbGetMapNameFromId(@mapid)
        mapname2 = ""
        if mapname.length > 24
          splits = mapname.split(/ /, mapname[0, 24].split(/ /).length)
          mapname2 = splits.delete_at(-1)
          mapname = splits.join(" ")
        end
        textpos.push([mapname, 193 * 2, 4 * 2, 1, color1, color2])
        textpos.push([mapname2, 193 * 2, 14 * 2, 1, color1, color2]) if mapname2 != ""
      elsif @title == "Other Save Files" && $game_switches != nil && $game_switches[:A_Fervent_Wish]
        textpos.push([@title, 16 * 2, 4 * 2, 0, Color.new(219, 203, 236), Color.new(142, 126, 159)])
      elsif @title.start_with?("Update available")
        textpos.push([@title, 16 * 2, 4 * 2, 0, Color.new(50, 190, 50), Color.new(40, 90, 40)])
      elsif @title.start_with?("Major update")
        textpos.push([@title, 16 * 2, 4 * 2, 0, Color.new(240, 72, 88), Color.new(100, 40, 40)])
      else
        textpos.push([@title, 16 * 2, 4 * 2, 0, color1, color2])
      end
      pbDrawTextPositions(self.bitmap, textpos)
    end
    @refreshing = false
  end
end

class PokemonLoadScene
  def pbUpdate
    oldi = @sprites["cmdwindow"].index rescue 0
    pbUpdateSpriteHash(@sprites)
    newi = @sprites["cmdwindow"].index rescue 0
    if oldi != newi
      @sprites["panel#{oldi}"].selected = false
      @sprites["panel#{oldi}"].pbRefresh
      @sprites["panel#{newi}"].selected = true
      @sprites["panel#{newi}"].pbRefresh
      while @sprites["panel#{newi}"].y > Graphics.height - 80
        for i in 0...@commands.length
          @sprites["panel#{i}"].y -= 48
        end
        for i in 0...6
          break if !@sprites["party#{i}"]

          @sprites["party#{i}"].y -= 48
        end
        @sprites["player"].y -= 48 if @sprites["player"]
      end
      while @sprites["panel#{newi}"].y < 32
        for i in 0...@commands.length
          @sprites["panel#{i}"].y += 48
        end
        for i in 0...6
          break if !@sprites["party#{i}"]

          @sprites["party#{i}"].y += 48
        end
        @sprites["player"].y += 48 if @sprites["player"]
      end
    end
  end

  def pbStartScene(commands, showContinue, trainer, framecount, mapid)
    @commands = commands
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99998
    @textviewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @textviewport.z = @viewport.z + 1
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @textviewport)
    @sprites["overlay2"] = BitmapSprite.new(Graphics.width, Graphics.height, @textviewport)

    if GAMEVERSION != 'dev'
      version = GAMEVERSION
      @sprites["overlay2"].bitmap.font.size = 17
      @sprites["overlay2"].bitmap.font.bold = true
      @sprites["overlay2"].bitmap.font.name = "PokemonEmerald"
      @sprites["overlay2"].bitmap.font.color = Color.new(175, 175, 175)
      if version.index("-") != nil
        prerelease = version[version.index("-") + 1..]
        version = version[0...version.index("-")]
        @sprites["overlay2"].bitmap.draw_text(-6, Graphics.height - 44, Graphics.width, 30, version, 2)
        @sprites["overlay2"].bitmap.draw_text(-6, Graphics.height - 26, Graphics.width, 30, prerelease, 2)
      else
        @sprites["overlay2"].bitmap.draw_text(-6, Graphics.height - 26, Graphics.width, 30, version, 2)
      end
    end

    addBackgroundOrColoredPlane(@sprites, "background", "loadbg", Color.new(248, 248, 248), @viewport)
    y = 16 * 2
    for i in 0...commands.length
      @sprites["panel#{i}"] =
        PokemonLoadPanel.new(i, commands[i], showContinue && i == 0, trainer, framecount, mapid, @viewport)
      @sprites["panel#{i}"].pbRefresh
      @sprites["panel#{i}"].x = 48
      @sprites["panel#{i}"].y = y
      y += showContinue && i == 0 ? 224 : 48
    end
    @sprites["cmdwindow"] = Window_CommandPokemon.new([], tts: false)
    @sprites["cmdwindow"].x = Graphics.width
    @sprites["cmdwindow"].y = 0
    @sprites["cmdwindow"].viewport = @viewport
    @sprites["cmdwindow"].visible = false
  end

  def pbStartScene2
    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  def pbMoveSprites(xoffset)
    @sprites["cmdwindow"].x -= xoffset
    @sprites["player"].x -= xoffset if @sprites["player"]
    for i in 0..6
      @sprites["party#{i}"].x -= xoffset if @sprites["party#{i}"]
    end
    for i in 0..6
      @sprites["panel#{i}"].x -= xoffset if @sprites["panel#{i}"]
    end
  end

  def pbDrawSaveCommands(savefiles)
    @savefiles = savefiles
    @sprites["overlay"].bitmap.clear
    textpos = []
    if savefiles.length >= 9
      numsavebuttons = 9
    else
      numsavebuttons = savefiles.length
    end
    for i in 0...numsavebuttons
      @sprites["savefile#{i}"] = IconSprite.new(Graphics.width / 2 - 384 / 2, i * 45, @viewport)
      @sprites["savefile#{i}"].setBitmap("Graphics/Pictures/loadsavepanel")
      @sprites["savefile#{i}"].zoom_x = 0.5
      @sprites["savefile#{i}"].zoom_y = 0.5
      Graphics.update
      loop do
        @sprites["savefile#{i}"].zoom_x += 0.5
        @sprites["savefile#{i}"].zoom_y += 0.5
        Graphics.update
        break if @sprites["savefile#{i}"].zoom_x == 1
      end
      if i < 10
        if savefiles[i][1].start_with?("Anna's Wish")
          textpos.push([savefiles[i][1], Graphics.width / 2 - savefiles[i][1].length * 4.5, i * 45 + 12, 0, Color.new(218, 182, 214), Color.new(139, 131, 148)])
        else
          textpos.push([savefiles[i][1], Graphics.width / 2 - savefiles[i][1].length * 4.5, i * 45 + 12, 0, Color.new(255, 255, 255), Color.new(125, 125, 125)])
        end
        pbDrawTextPositions(@sprites["overlay"].bitmap, textpos)
      end
    end
    pbDrawSaveText(savefiles)
    @sprites["saveselect"] = IconSprite.new(Graphics.width / 2 - 384 / 2, 0, @viewport)
    @sprites["saveselect"].setBitmap("Graphics/Pictures/loadsavepanel_1")
    Graphics.update
    pbToggleSelecting
    tts(@savefiles[0][1])
  end

  def pbRemoveSaveCommands
    @sprites["overlay"].bitmap.clear
    @index = 0 if !@index
    Graphics.update

    pbDisposeSprite(@sprites, "saveselect")
    Graphics.update
    for i in 0...@savefiles.length
      pbDisposeSprite(@sprites, "savefile#{i}")
      Graphics.update
    end
  end

  def pbChooseAutoSubFile(index, arrayindex)
    if !@sprites["autosavefile"]
      @sprites["overlay"].bitmap.clear
      @sprites["newsavefile1"] = IconSprite.new(20, Graphics.height / 3, @viewport)
      @sprites["newsavefile1"].setBitmap("Graphics/Pictures/loadsavepanel")
      @sprites["autosavefile"] = IconSprite.new(300, Graphics.height / 3, @viewport)
      @sprites["autosavefile"].setBitmap("Graphics/Pictures/loadsavepanel")
      @sprites["saveselect"] = IconSprite.new(20, Graphics.height / 3, @viewport)
      @sprites["saveselect"].setBitmap("Graphics/Pictures/loadsavepanel_1")
      @sprites["autosavefile"].zoom_x = 0.5
      @sprites["newsavefile1"].zoom_x = 0.5
      @sprites["newsavefile1"].zoom_y = 1.5
      @sprites["autosavefile"].zoom_y = 1.5
      @sprites["saveselect"].zoom_x = 0.5
      @sprites["saveselect"].zoom_y = 1.5
      @sprites["overlay2"].bitmap.font.size = 22
      textpos = []
      textpos.push([@savefiles[arrayindex][1], Graphics.width / 2 - @savefiles[arrayindex][1].length / 2 * 10, 30, 0, Color.new(0, 0, 0), Color.new(125, 125, 125)])
      textpos.push(["Normal Save", 55, Graphics.height / 3 + 12, 0, Color.new(255, 255, 255), Color.new(125, 125, 125)])
      textpos.push(["Autosave", 350, Graphics.height / 3 + 12, 0, Color.new(255, 255, 255), Color.new(125, 125, 125)])
      textpos.push([@savefiles[arrayindex][4], 30, Graphics.height / 3 + 35, 0, Color.new(255, 255, 255), Color.new(125, 125, 125)])
      textpos.push([@savefiles[arrayindex][5], 315, Graphics.height / 3 + 35, 0, Color.new(255, 255, 255), Color.new(125, 125, 125)])
      pbDrawTextPositions(@sprites["overlay"].bitmap, textpos)
    end
    if index == 0
      @sprites["saveselect"].x = 20
    else
      @sprites["saveselect"].x = 300
    end
  end

  def pbClearOverlay2
    @sprites["overlay2"].bitmap.clear
  end

  def pbDrawCurrentSaveFile(savename = "", auto = nil)
    @sprites["overlay2"].bitmap.clear
    textpos = []
    if auto == nil
      textpos.push([savename, 0, 0, 0, Color.new(255, 255, 255), Color.new(125, 125, 125)])
    else
      textpos.push([savename + " Auto Save", 0, 0, 0, Color.new(255, 255, 255), Color.new(125, 125, 125)])
    end
    pbDrawTextPositions(@sprites["overlay2"].bitmap, textpos)
  end

  def pbDrawSaveText(savefiles, xoffset = 0, yoffset = 0)
    @sprites["overlay"].bitmap.clear
    textpos = []
    # @savefiles=savefiles
    for i in 0...savefiles.length
      if !((i * 45 + 12 - yoffset) < 0) && !(i * 45 + 12 - yoffset > 9 * 45)
        if savefiles[i][1].start_with?("Anna's Wish")
          textpos.push([savefiles[i][1], Graphics.width / 2 - savefiles[i][1].length * 4.5 + xoffset, i * 45 + 12 - yoffset, 0, Color.new(218, 182, 214), Color.new(139, 131, 148)])
        else
          textpos.push([savefiles[i][1], Graphics.width / 2 - savefiles[i][1].length * 4.5 + xoffset, i * 45 + 12 - yoffset, 0, Color.new(255, 255, 255), Color.new(125, 125, 125)])
        end
      end
     end
    pbDrawTextPositions(@sprites["overlay"].bitmap, textpos)
  end

  def pbToggleSelecting
    if @saveselecting
      @saveselecting = !@saveselecting
    else
      @saveselecting = true
    end
  end

  def pbMoveSaveSel(index)
    tts(@savefiles[index][1])
    @index = index
    if index <= 7
      @sprites["saveselect"].y = index * 45
      pbDrawSaveText(@savefiles)
    elsif index == @savefiles.length - 1
      @sprites["saveselect"].y = 7 * 45
      pbDrawSaveText(@savefiles, 0, 45 * (index - 7))
    else
      pbDrawSaveText(@savefiles, 0, 45 * (index - 7))
    end
    if index == (@savefiles.length - 1) && @savefiles.length - 1 >= 8
      @sprites["savefile8"].visible = false if @sprites["savefile8"]
    else
      @sprites["savefile8"].visible = true if @sprites["savefile8"]
    end
    Graphics.update
  end

  def pbStartDeleteScene
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99998
    addBackgroundOrColoredPlane(@sprites, "background", "loadbg", Color.new(248, 248, 248), @viewport)
  end

  def pbSetParty(trainer)
    return if !trainer || !trainer.party

    filename = pbGetPlayerCharset(:walk, trainer)
    @sprites["player"] = TrainerWalkingCharSprite.new(filename, @viewport)
    charwidth = @sprites["player"].bitmap.width
    charheight = @sprites["player"].bitmap.height
    @sprites["player"].x = 112 - charwidth / 8
    @sprites["player"].y = 112 - charheight / 8
    @sprites["player"].src_rect = Rect.new(0, 0, charwidth / 4, charheight / 4)
    for i in 0...trainer.party.length
      @sprites["party#{i}"] = PokemonIconSprite.new(trainer.party[i], @viewport)
      @sprites["party#{i}"].z = 99999
      @sprites["party#{i}"].x = 306 + 66 * (i & 1)
      @sprites["party#{i}"].y = 72 + 50 * (i / 2)
    end
  end

  def pbChoose(commands)
    @sprites["cmdwindow"].commands = commands
    lastread = nil
    loop do
      Graphics.update
      Input.update
      tts(commands[@sprites["cmdwindow"].index]) if @sprites["cmdwindow"].index != lastread
      lastread = @sprites["cmdwindow"].index
      pbUpdate
      if Input.trigger?(Input::C) && (!@saveselecting || @saveselecting == false)
        return @sprites["cmdwindow"].index
      end
    end
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites) # { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
    @commands = nil
    @textviewport.dispose
  end

  def pbCloseScene
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

class PokemonLoad
  attr_accessor :currentsave

  def initialize(scene)
    @scene = scene
  end

  def pbTryLoadFile(savefile)
    begin
      File.open(savefile, "rb") { |f|
        @currentsave = Marshal.load(f)
      }
      if !@currentsave.is_a?(Hash)
        convertSaveFolder
        File.open(savefile, "rb") { |f|
          @currentsave = Marshal.load(f)
        }
      end
      return
    rescue => e
      @currentsave = nil
      raise sprintf("Corrupted save file:\n%s\n%s: %s", File.realpath(savefile), e.class, e.message)
    end
  end

  def pbStartDeleteScreen
    savefile = RTP.getSaveFileName("Game.rxdata")
    @scene.pbStartDeleteScene
    @scene.pbStartScene2
    if safeExists?(savefile)
      if Kernel.pbConfirmMessageSerious(_INTL("Delete all saved data?"))
        Kernel.pbMessage(_INTL("Once data has been deleted, there is no way to recover it.\1"))
        if Kernel.pbConfirmMessageSerious(_INTL("Delete the saved data anyway?"))
          Kernel.pbMessage(_INTL("Deleting all data.\r\nDon't turn off the power.\\wtnp[0]"))
          begin; File.delete(savefile); rescue; end
          begin; File.delete(savefile + ".bak"); rescue; end
          Kernel.pbMessage(_INTL("The save file was deleted."))
        end
      end
    else
      Kernel.pbMessage(_INTL("No save file was found."))
    end
    @scene.pbEndScene
    $scene = pbCallTitle
  end

  def pbStartLoadScreen
    $PokemonTemp   = PokemonTemp.new
    $game_temp     = Game_Temp.new
    $game_map = nil
    Input.text_input = false
    cmdContinue    = -1
    cmdNewGame     = -1
    cmdControls    = -1
    cmdSaveDir     = -1
    cmdChooseSaveFile = -1
    cmdOption      = -1
    cmdLanguage    = -1
    cmdQuit        = -1
    cmdDeleteSaveFile = -1
    cmdPatchUpdate = -1
    cmdMajorUpdate = -1
    commands       = []
    trainer        = nil
    savefile = RTP.getSaveSlotPath($Unidata[:saveslot])

    if safeExists?(savefile)
      begin
        pbTryLoadFile(savefile)
      rescue => e
        print e.message
      end
      if @currentsave.is_a?(Hash)
        trainer = @currentsave[:Trainer]
        framecount = @currentsave[:playtime]
        $game_system = @currentsave[:system]
        mapid = @currentsave[:map_id]

        commands[cmdContinue = commands.length] = _INTL("Continue")
      end
    end

    Updater.waitForVersionCheck
    if Updater.shouldUseBuiltInUpdater?
      versionStatus = Updater.getVersionStatus
      if versionStatus == 3
        commands[cmdPatchUpdate = commands.length] = _INTL("Update available: {1}", Updater.getAvailableVersion)
      elsif versionStatus == 4
        commands[cmdMajorUpdate = commands.length] = _INTL("Major update: {1}", Updater.getAvailableVersion)
      end
    end

    commands[cmdNewGame = commands.length] = _INTL("New Game")
    commands[cmdChooseSaveFile = commands.length] = _INTL("Other Save Files")

    if safeExists?(savefile)
      commands[cmdDeleteSaveFile = commands.length] = _INTL("Delete This Save File")
    end

    commands[cmdOption = commands.length] = _INTL("Options")
    commands[cmdSaveDir = commands.length] = _INTL("Save Directory")
    commands[cmdControls = commands.length] = _INTL("Controls")

    if LANGUAGES.length >= 2
      commands[cmdLanguage = commands.length] = _INTL("Language")
    end
    # commands[cmdQuit=commands.length]=_INTL("Quit Game")
    @scene.pbStartScene(commands, @currentsave.is_a?(Hash), trainer, framecount, mapid)
    @scene.pbSetParty(trainer)
    @scene.pbStartScene2
    loop do
      command = @scene.pbChoose(commands)
      deleting = false
      if cmdDeleteSaveFile >= 0 && command == cmdDeleteSaveFile
        if Kernel.pbConfirmMessageSerious(_INTL("Are you sure you want to delete this save file?"))
          if Kernel.pbConfirmMessageSerious(_INTL("All data will be lost.  Confirm once more to proceed."))
            begin; File.delete(savefile); rescue; end
            deleting = true
            @scene.pbClearOverlay2
            @scene.pbEndScene
            return
            pbSetUpSystem
            pbSetLanguage
            scene = PokemonLoadScene.new
            screen = PokemonLoad.new(scene)
            screen.pbStartLoadScreen
          end
        end
        redo if deleting == false
      elsif cmdContinue >= 0 && command == cmdContinue
        next if !startPlayingSaveFile(savefile)

        return
      elsif cmdNewGame >= 0 && command == cmdNewGame
        @scene.pbEndScene
        if $game_map && $game_map.events
          for event in $game_map.events.values
            event.clear_starting
          end
        end
        $game_temp.common_event_id = 0 if $game_temp
        $scene               = Scene_Map.new
        Graphics.frame_count = 0
        Graphics.start_playing = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        $game_system         = Game_System.new
        $game_switches       = Game_Switches.new
        $game_variables      = Game_Variables.new
        $game_self_switches  = Game_SelfSwitches.new
        $game_screen         = Game_Screen.new
        $game_player         = Game_Player.new
        $PokemonMap          = PokemonMapMetadata.new
        $PokemonGlobal       = PokemonGlobalMetadata.new
        $PokemonStorage      = PokemonStorage.new
        $PokemonEncounters   = PokemonEncounters.new
        $PokemonTemp.begunNewGame = true
        $MapFactory = PokemonMapFactory.new()
        $MapFactory.setup($cache.RXsystem.start_map_id) # calls setMapChanged
        $game_player.moveto($cache.RXsystem.start_x, $cache.RXsystem.start_y)
        $game_player.refresh
        $game_map.autoplay
        $game_map.update

        # find next available slot
        createSaveSlot
        return
      elsif cmdChooseSaveFile >= 0 && command == cmdChooseSaveFile
        # convertSaveFolder
        saveslots = []
        # Finding Other Save Files
        d = Dir.new(RTP.getSaveFolder)
        begin
          d.children.each do |file|
            next if !/^Game_[0-9]+.rxdata$/.match(file) && !/^Game.rxdata$/.match(file)
            next if !safeExists?(d.path + "/" + file)

            t = File.mtime(d.path + "/" + file) rescue pbGetTimeNow
            savetime = t.strftime("%c")
            info = saveinfo(d.path + file)
            savenumber = file.scan(/\d+/)[0].to_i
            savenumber = 1 if savenumber == 0
            slotname = "Save Slot #{savenumber}" + info
            saveslots.push([savenumber, slotname, false, true, savetime, file])
          end
        rescue
          pbPrintException($!)
        ensure
          d.close
        end

        # Specific Anna Smiles code
        anna_saves = []
        if Reborn
          d = Dir.new(RTP.getSaveFolder)
          begin
            d.children.each do |file|
              next if !file.start_with?("Anna's Wish")
              next if !safeExists?(d.path + "/" + file)

              info = saveinfo(d.path + file)
              savenumber = file.scan(/\d+/)[0].to_i
              slotname = "Anna's Wish" + info
              anna_saves.push([savenumber, slotname, false, true, nil, file])
            end
          rescue
            pbPrintException($!)
          ensure
            d.close
          end
          anna_saves.sort_by! { |arr| arr[0] }
          saveslots += anna_saves
        end

        if saveslots.length == 0
          Kernel.pbMessage(_INTL("You don't have any other save files"))
          next
        end
        saveslots.sort_by! { |arr| arr[0] }
        for i in 1..21 # move the commands and other graphics
          @scene.pbMoveSprites(i * 2)
          Graphics.update
        end
        @scene.pbDrawSaveCommands(saveslots)
        # @scene.pbDrawSaveText(saveslots)
        @selected = 0
        loop do
          Input.update
          Graphics.update
          if Input.repeat?(Input::DOWN)
            @selected = (@selected + 1) % saveslots.length
            @scene.pbMoveSaveSel(@selected)
          elsif Input.repeat?(Input::UP)
            @selected = (@selected - 1) % saveslots.length
            @scene.pbMoveSaveSel(@selected)
          elsif Input.repeat?(Input::PAGEUP)
            @selected = [@selected - 7, 0].max
            @scene.pbMoveSaveSel(@selected)
          elsif Input.repeat?(Input::PAGEDOWN)
            @selected = [@selected + 7, saveslots.length - 1].min
            @scene.pbMoveSaveSel(@selected)
          elsif Input.trigger?(Input::B)
            @scene.pbRemoveSaveCommands
            Graphics.update
            for i in 1..21 # move the commands and other graphics
              @scene.pbMoveSprites(i * -2)
              Graphics.update
            end
            @scene.pbToggleSelecting
            break
          elsif Input.trigger?(Input::C)
            @scene.pbRemoveSaveCommands
            tempsave = saveslots[@selected][0]
            savefile = saveslots[@selected][5]
            if savefile.start_with?("Anna's Wish")
              createSaveSlot
              return startPlayingSaveFile(RTP.getSaveFileName(savefile))
            end

            $Unidata[:saveslot] = tempsave
            @scene.pbEndScene
            pbSetUpSystem
            pbSetLanguage
            scene = PokemonLoadScene.new
            screen = PokemonLoad.new(scene)
            screen.pbStartLoadScreen
            return
          end
        end
      elsif cmdOption >= 0 && command == cmdOption
        scene = PokemonOptionScene.new
        screen = PokemonOption.new(scene)
        pbFadeOutIn(99999) { screen.pbStartScreen }

      elsif cmdControls >= 0 && command == cmdControls
        controlsDialogue
      elsif cmdSaveDir >= 0 && command == cmdSaveDir
        folderpath = RTP.getSaveFolder
        if $joiplay
          Kernel.pbMessage(Dir.pwd + folderpath)
        elsif System.platform[/Windows/]
          folderpath.gsub!('\\', '\\\\')
          folderpath.gsub!('/', '\\\\')
          system("explorer #{folderpath}")
        elsif System.platform[/macOS/]
          # pathstr = "~\\Library\\Application Support\\#{GAMETITLE}\\"
          system("open '#{folderpath}'")
        elsif System.platform[/Linux/]
          # System.open(folderpath)
          system("xdg-open '#{folderpath}'")
        end
      elsif cmdLanguage >= 0 && command == cmdLanguage
        @scene.pbEndScene
        $Settings.language = pbChooseLanguage
        saveSettings # persist the choice across restarts
        pbLoadMessages("Data/" + LANGUAGES[$Settings.language][1])
        $scene = pbCallTitle
        return
      elsif cmdPatchUpdate >= 0 && command == cmdPatchUpdate
        Updater.handlePatchUpdate
      elsif cmdMajorUpdate >= 0 && command == cmdMajorUpdate
        Updater.handleMajorUpdate
      end
    end
    @scene.pbEndScene
    return
  end

  def startPlayingSaveFile(savefile)
    unless safeExists?(savefile)
      pbPlayBuzzerSE()
      return false
    end
    pbTryLoadFile(savefile) # Needed for Anna's Wish
    startTimer
    @scene.pbEndScene
    $Trainer = @currentsave[:Trainer]
    playtime = @currentsave[:playtime]
    if playtime.bit_length < 31
      Graphics.frame_count  = playtime
      playtime              = 0
    end
    $game_system            = @currentsave[:system]
    $game_switches          = @currentsave[:switches]
    $game_variables         = @currentsave[:variable]
    $game_self_switches     = @currentsave[:self_switches]
    $game_screen            = @currentsave[:game_screen]
    $game_player            = @currentsave[:game_player]
    $PokemonGlobal          = @currentsave[:PokemonGlobal]
    $PokemonMap             = @currentsave[:PokemonMap]
    $PokemonBag             = @currentsave[:PokemonBag]
    $PokemonStorage         = @currentsave[:PokemonStorage]
    map = @currentsave[:Map]


    $MapFactory = PokemonMapFactory.new()
    $MapFactory.setup(@currentsave[:map_id], true)
    if Input.pressex?(:L) # && $INTERNAL
      # LOAD NEW MAP INSTANCE
    else
      if pbBattleChallenge.pbInChallenge?
        $game_system.newInterp
        $MapFactory.setup(@currentsave[:map_id])
      else
        $MapFactory.loadMap(map)
      end
    end
    $game_map = $MapFactory.map

    Graphics.time_passed = Graphics.frame_count.clone + playtime
    Graphics.start_playing = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    checkConversions
    getNGPData
    $PokemonBag.initTrackerData if !$PokemonBag.itemtracker

    if $PokemonGlobal.safesave
      if pbMapInterpreterRunning?
        pbMapInterpreter.setup(nil, 0)
      end
      $MapFactory.setup($game_map.map_id) # calls setMapChanged
      # $game_player.center($game_player.x, $game_player.y)
    else
      $MapFactory.setMapChanged($game_map.map_id)
    end
    if !$game_map.events # Map wasn't set up
      $game_map = nil
      $scene = nil
      Kernel.pbMessage(_INTL("The map is corrupt. The game cannot continue."))
      return true
    end
    $PokemonMap.updateMap
    $PokemonEncounters = PokemonEncounters.new
    $PokemonEncounters.setup($game_map.map_id)
    pbAutoplayOnSave
    $game_map.update
    # some bullshit, don't worry about it
    if $game_variables[:Some_Bullshit] > 0
      $game_variables[:Some_Bullshit] += 1
      $game_map.need_refresh = true
    end
    if $game_variables[:ItsALuckyNumber] == 3
      $game_variables[:ItsALuckyNumber] = 4
      $game_map.need_refresh = true
      $game_screen.tone.red = -255
      $game_screen.tone.blue = -255
      $game_screen.tone.green = -255
      $game_screen.tone.gray = 0
      $game_mute = true
    end
    if Reborn && $game_switches[1305] # postgame active
      $Trainer.postgame = $game_variables[569]
    end
    if !$game_screen.shakeX || !$game_screen.shakeY
      $game_screen.initAddedVars
    end
    # end bullshit
    for event in $game_map.events.values
      event.unlock
    end
    $game_switches[:Mid_quicksave] = false
    $game_switches[:Stop_Icycle_Falling] = false
    stopTimer
    $scene = Scene_Map.new
    $game_player.center($game_player.x, $game_player.y)
    return true
  end

  def createSaveSlot
    j = 0
    loop do
      j += 1
      checksave = RTP.getSaveSlotPath(j)
      if !safeExists?(checksave)
        $Unidata[:saveslot] = j
        saveClientData
        break
      end
    end
  end
end

def saveinfo(savefile)
  begin
    data = nil
    File.open(savefile, "rb") { |f|
      data = Marshal.load(f)
    }
    if data.is_a?(Hash)
      trainer = data[:Trainer]
      if trainer.postgame != nil
        info = " - #{trainer.name} - #{trainer.postgame} legendaries"
      else
        info = " - #{trainer.name} - #{trainer.numbadges} badges"
      end
      return info
    else
      info = " - legacy save file"
    end
  rescue
    if data.is_a?(Hash)
      info = " - save corrupted"
    else
      info = " - legacy save file"
    end
  end
  return info
end

def pbStoredLastPlayed(savenum)
  $Unidata[:saveslot] = savenum
  saveClientData
end

def restrictOnlineFeatures
  $game_switches[:No_Online_Randbats] = true if [$game_switches[:No_Total_EV_Cap], $game_switches[:MiniDebug_Pass], $game_switches[:SnagMachine_Password], $game_switches[:Randomized_Challenge], $game_switches[:Disabled_Randomizer]].any?
  $game_switches[:No_Online_Trades] = true if [$game_switches[:Full_IVs], $game_switches[:No_Total_EV_Cap], $game_switches[:MiniDebug_Pass], $game_switches[:SnagMachine_Password], $game_switches[:Randomized_Challenge], $game_switches[:Disabled_Randomizer]].any?
end

def checkConversions
  # This method is used for system changes that require saved data to be altered in some way,
  # regardless of whether or not it's game breaking.

  if $Trainer.trainertype.is_a?(Integer)
    enforceTrainerType
  end

  # Last check through for old temp conversions, most of these methods should be able to be
  # safely removed after a while.
  if !$game_system.game_version || (Reborn && $game_system.game_version == "e19.16")
    # updating storage boxes, can be removed after a while
    if $PokemonStorage && $PokemonStorage.boxes.length < STORAGEBOXES
      $PokemonStorage.upTotalBoxes(STORAGEBOXES)
    end
    tempConvertNatures
    if Rejuv
      $Trainer.achievements = Achievements.new() if !$Trainer.achievements
    end
    $Trainer.pokedex.updateGenderFormEntries # ensure things are updated, remove after a bit ig

    if $game_switches[:Randomized_Challenge]
      Kernel.pbMessage("Note: The game has detected you were previously playing a randomizer. Your old randomizer data will no longer function.")
      if Kernel.pbConfirmMessage("Would you like to re-randomize your game?")
        pbFadeOutIn(99999) {
          RandomizerScene.new(RandomizerSettings.new)
          $Randomizer.randomize if $game_switches[:Randomized_Challenge]
        }
      else
        if Kernel.pbConfirmMessageSerious("You will still be unable to access any online features. Are you sure you wish to continue without randomizing?")
          $game_switches[:Disabled_Randomizer] = true
          $game_switches[:Randomized_Challenge] = false
        else
          pbFadeOutIn(99999) {
            RandomizerScene.new(RandomizerSettings.new)
            $Randomizer.randomize if $game_switches[:Randomized_Challenge]
          }
        end
      end
    end
  end

  if Reborn && $game_switches[:Randomized_Challenge] && checkVersionOlderThan("19.5.9")
    $game_switches[:Randomizer_Wonder_Guard_Fix] = true
  end

  if !$game_switches[:Disabled_Randomizer] && $game_switches[:Randomized_Challenge]
    $rndcache = nil
    if File.exist?("Randomizer Data/settings.txt")
      str = File.read("Randomizer Data/settings.txt")
      settings = RandomizerSettings.new()
      settings.load(str)
      regenerate = (settings.to_s != $game_variables[:Randomizer_Settings] || settings.random.seed != $game_variables[:Randomizer_Seed])
      $Randomizer = Randomizer.new(settings)
      if regenerate
        Kernel.pbMessage("The game will now generate your randomizer files.")
        $Randomizer.randomize
        Kernel.pbMessage("The game has finished generating your randomizer files.")
      end
    else
      settings = RandomizerSettings.new()
      str = "#{$game_variables[:Randomizer_Settings]}\n#{$game_variables[:Randomizer_Seed]}\n#{$game_variables[:Randomizer_Items]}"
      settings.load(str)
      $Randomizer = Randomizer.new(settings)
      Kernel.pbMessage("The game will now generate your randomizer files.")
      $Randomizer.randomize
      Kernel.pbMessage("The game has finished generating your randomizer files.")
    end
    $rndcache = Cache_Randomizer.new()
  end

  # Restrict online play
  restrictOnlineFeatures

  # New conversions based on game version.
  if Reborn
    # Relocating the Red and Blue Orbs to the Enhancements pocket (Mega Stones, Z-Crystals, Crests)
    if $PokemonBag.pockets[1].include?(:REDORB)
      $PokemonBag.pockets[1].delete(:REDORB)
      $PokemonBag.pockets[6].push(:REDORB)
    end
    if $PokemonBag.pockets[1].include?(:BLUEORB)
      $PokemonBag.pockets[1].delete(:BLUEORB)
      $PokemonBag.pockets[6].push(:BLUEORB)
    end

    # Moving tutored move IDs into Trainer tutor list, convert into symbols
    $Trainer.tutorlist = [] if !$Trainer.tutorlist
    if $PokemonGlobal.tutoredMoves && !$PokemonGlobal.tutoredMoves.empty?
      $PokemonGlobal.tutoredMoves.length().times do
        $Trainer.tutorlist.push($PokemonGlobal.tutoredMoves.shift())
      end
    end
    if $Trainer.tutorlist.any? { |i| i.is_a?(Integer) }
      for i in 0...$Trainer.tutorlist.length
        next if !$Trainer.tutorlist[i].is_a?(Integer)

        for j in $cache.moves.keys
          if $cache.moves[j].checkFlag?(:ID) == $Trainer.tutorlist[i]
            $Trainer.tutorlist[i] = $cache.moves[j].move
          end
        end
      end
    end
    reorderTutorMoves

    # Convert the stored movesets from the Moveset Restorer
    if $PokemonGlobal.storedMovesets && !$PokemonGlobal.storedMovesets.empty?
      for moveset in $PokemonGlobal.storedMovesets
        moveset[:moves].each_with_index { |move, i|
          next if move.is_a?(Hash)

          found = $cache.moves.find { |m, data|
            hasID = data.checkFlag?(:ID) == move.instance_variable_get(:@id) # 19.0.16
            hasmove = m == move.move # 19.5.0-rc.13
            hasID || hasmove
          }

          if found
            movename = found[1].checkFlag?(:ID) == move.instance_variable_get(:@id) ? found[1].move : move.move
            moveset[:moves][i] = { move: movename, ppup: move.ppup }
          end
        }
        $cache.pkmn.each { |mon, data|
          if data[0].dexnum == moveset[:id]
            moveset[:id] = mon
            break
          end
        }
      end
    end

    for mon in findAllPokemon
      # Migrate legacy mon data
    end
  end

  if Rejuv

  end

  if Desolation

  end
end

def checkVersionOlderThan(version)
  # currentVersion = Gem::Version.new(GAMEVERSION)
  checkVersion = Gem::Version.new(version)
  saveVersion = Gem::Version.new($game_system.game_version)

  return saveVersion <= checkVersion
end
