class MapBottomSprite < SpriteWrapper
  attr_reader :mapname, :maplocation

  def initialize(viewport = nil)
    super(viewport)
    @mapname = ""
    @maplocation = ""
    @mapdetails = ""
    @nonests = false
    @thisbitmap = BitmapWrapper.new(Graphics.width, Graphics.height)
    pbSetSystemFont(@thisbitmap)
    self.y = 0
    self.x = 0
    self.bitmap = @thisbitmap
    refresh
  end

  def dispose
    @thisbitmap.dispose
    super
  end

  def nonests=(value)
    @nonests = value
    refresh
  end

  def mapname=(value)
    if @mapname != value
      @mapname = value
      refresh
    end
  end

  def maplocation=(value)
    if @maplocation != value
      @maplocation = value
      refresh
    end
  end

  def mapdetails=(value) # From Wichu
    if @mapdetails != value
      @mapdetails = value
      refresh
    end
  end

  def refresh
    self.bitmap.clear
    if @nonests
      imagepos = [[sprintf("Graphics/Pictures/Pokedex/pokedexNestUnknown"), 108, 172, 0, 0, -1, -1]]
      pbDrawImagePositions(self.bitmap, imagepos)
    end
    textpos = [
      [@mapname, 18, -2, 0, Color.new(248, 248, 248), Color.new(0, 0, 0)],
      [@maplocation, 18, 354, 0, Color.new(248, 248, 248), Color.new(0, 0, 0)],
      [@mapdetails, Graphics.width - 16, 354, 1, Color.new(248, 248, 248), Color.new(0, 0, 0)]
    ]
    if @nonests
      textpos.push(
        [_INTL("Area Unknown"), Graphics.width / 2, Graphics.height / 2 - 16, 2, Color.new(88, 88, 80),
         Color.new(168, 184, 184)]
      )
    end
    pbDrawTextPositions(self.bitmap, textpos)
  end
end

class PokemonRegionMapScene
  LEFT   = 0
  TOP    = 0
  RIGHT  = 14
  RIGHT  = 29 if Desolation
  BOTTOM = 18
  BOTTOM = 19 if Desolation
  SQUAREWIDTH  = 16
  SQUAREHEIGHT = 16

  def initialize(region = -1, wallmap = true)
    @region = region
    @wallmap = wallmap
  end

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end

  def pbStartScene(aseditor = false, mode = 0)
    @editor = aseditor
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    @mapdata = $cache.town_map
    playerpos = $cache.mapdata[$game_map.map_id].MapPosition
    if !playerpos
      mapindex = 0
      @map = @mapdata[0]
      @mapX = LEFT
      @mapY = TOP
    elsif @region >= 0 && @region != playerpos[0] && @mapdata[@region]
      mapindex = @region
      @map = @mapdata[@region]
      @mapX = LEFT
      @mapY = TOP
    else
      mapindex = playerpos[0]
      @map = @mapdata[playerpos[0]]
      @mapX = playerpos[1]
      @mapY = playerpos[2]
      mapsize = $cache.mapdata[$game_map.map_id].MapSize
      if mapsize && mapsize[0] && mapsize[0] > 0
        sqwidth = mapsize[0]
        sqheight = (mapsize[1].length * 1.0 / mapsize[0]).ceil
        if sqwidth > 1
          @mapX += ($game_player.x * sqwidth / $game_map.width).floor
        end
        if sqheight > 1
          @mapY += ($game_player.y * sqheight / $game_map.height).floor
        end
      end
    end
    if !@map
      Kernel.pbMessage(_INTL("The map data cannot be found."))
      return false
    end
    addBackgroundOrColoredPlane(@sprites, "background", "mapbg", Color.new(0, 0, 0), @viewport)
    @sprites["map"] = IconSprite.new(0, 0, @viewport)
    @sprites["map"].setBitmap("Graphics/Pictures/#{@map[Reborn ? :filename : 1]}")
    @sprites["map"].x += (Graphics.width - @sprites["map"].bitmap.width) / 2
    @sprites["map"].y += (Graphics.height - @sprites["map"].bitmap.height) / 2
    for hidden in REGIONMAPEXTRAS
      if hidden[0] == mapindex && ((@wallmap && hidden[5]) ||
         (!@wallmap && hidden[1] > 0 && $game_switches[hidden[1]]))
        if !@sprites["map2"]
          @sprites["map2"] = BitmapSprite.new(480, 320, @viewport)
          @sprites["map2"].x = @sprites["map"].x; @sprites["map2"].y = @sprites["map"].y
        end
        pbDrawImagePositions(
          @sprites["map2"].bitmap,
          [
            ["Graphics/Pictures/#{hidden[4]}", hidden[2] * SQUAREWIDTH, hidden[3] * SQUAREHEIGHT, 0, 0, -1, -1]
          ]
        )
      end
    end
    @sprites["mapbottom"] = MapBottomSprite.new(@viewport)
    @sprites["mapbottom"].mapname = pbGetMessageFromHash(MessageTypes::RegionNames, $cache.town_map[mapindex][:name])
    @sprites["mapbottom"].maplocation = pbGetMapLocation(@mapX, @mapY)
    @sprites["mapbottom"].mapdetails = pbGetMapDetails(@mapX, @mapY)
    if playerpos && mapindex == playerpos[0] && (!Desolation || Desolation && @region < 4)
      @sprites["player"] = IconSprite.new(0, 0, @viewport)
      @sprites["player"].setBitmap(pbPlayerHeadFile($Trainer.trainertype))
      @sprites["player"].x = -SQUAREWIDTH / 2 + (@mapX * SQUAREWIDTH) + (Graphics.width - @sprites["map"].bitmap.width) / 2
      @sprites["player"].y = -SQUAREHEIGHT / 2 + (@mapY * SQUAREHEIGHT) + (Graphics.height - @sprites["map"].bitmap.height) / 2
    end
    for i in 0...RoamingSpecies.length
      if $game_switches[RoamingSpecies[i][:switch]] && $PokemonGlobal.roamPosition[i] && !$PokemonGlobal.roamPokemonCaught[i] && RoamingSpecies[i][:roamgraphic]
        positiondata = $cache.mapdata[$PokemonGlobal.roamPosition[i]].MapPosition
        mapsize = $cache.mapdata[$PokemonGlobal.roamPosition[i]].MapSize
        if mapsize && mapsize[0] && mapsize[0] > 0
          sqwidth = mapsize[0]
          sqheight = (mapsize[1].length * 1.0 / mapsize[0]).ceil
          if sqwidth > 1
            positiondata[1] += ($game_player.x * sqwidth / $game_map.width).floor
          end
          if sqheight > 1
            positiondata[2] += ($game_player.y * sqheight / $game_map.height).floor
          end
        end
        tts(_INTL("{1} - {2}", $cache.pkmn[RoamingSpecies[i][:species], 0].name, pbGetMapNameFromId($PokemonGlobal.roamPosition[i])))
        @sprites["roaming#{i}"] = IconSprite.new(0, 0, @viewport)
        @sprites["roaming#{i}"].setBitmap(RoamingSpecies[i][:roamgraphic])
        @sprites["roaming#{i}"].x = SQUAREWIDTH / 2 - @sprites["roaming#{i}"].bitmap.width / 2 + (positiondata[1] * SQUAREWIDTH) + (Graphics.width - @sprites["map"].bitmap.width) / 2
        @sprites["roaming#{i}"].y = SQUAREHEIGHT / 2 - @sprites["roaming#{i}"].bitmap.height / 2 + (positiondata[2] * SQUAREHEIGHT) + (Graphics.height - @sprites["map"].bitmap.height) / 2
      end
    end
    if mode > 0
      k = 0
      for i in LEFT..RIGHT
        for j in TOP..BOTTOM
          healspot = pbGetHealingSpot(i, j)
          if healspot && $PokemonGlobal.visitedMaps[healspot[0]]
            if Desolation && @region > 3
              @sprites["point#{k}"] = AnimatedSprite.create("Graphics/Pictures/mapBus", 2, 30)
            else
              @sprites["point#{k}"] = AnimatedSprite.create("Graphics/Pictures/mapFly", 2, 30)
            end
            @sprites["point#{k}"].viewport = @viewport
            @sprites["point#{k}"].x = -SQUAREWIDTH / 2 + (i * SQUAREWIDTH) + (Graphics.width - @sprites["map"].bitmap.width) / 2
            @sprites["point#{k}"].y = -SQUAREHEIGHT / 2 + (j * SQUAREHEIGHT) + (Graphics.height - @sprites["map"].bitmap.height) / 2
            @sprites["point#{k}"].play
            k += 1
          end
        end
      end
    end
    @sprites["cursor"] = AnimatedSprite.create("Graphics/Pictures/mapCursor", 2, 15)
    @sprites["cursor"].viewport = @viewport
    @sprites["cursor"].play
    @sprites["cursor"].x = -SQUAREWIDTH / 2 + (@mapX * SQUAREWIDTH) + (Graphics.width - @sprites["map"].bitmap.width) / 2
    @sprites["cursor"].y = -SQUAREHEIGHT / 2 + (@mapY * SQUAREHEIGHT) + (Graphics.height - @sprites["map"].bitmap.height) / 2
    @changed = false
    pbFadeInAndShow(@sprites) { pbUpdate }
    return true
  end

  def pbSaveMapData
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites)
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end

  def pbGetMapLocation(x, y)
    if Reborn
      maploc = @mapdata[[x, y]] ? pbGetMessageFromHash(MessageTypes::PlaceNames, @mapdata[[x, y]].name) : ""
      return maploc
    else
      return "" if !@map[2]

      for loc in @map[2]
        if loc[0] == x && loc[1] == y
          if !loc[7] || (!@wallmap && $game_switches[loc[7]])
            maploc = pbGetMessageFromHash(MessageTypes::PlaceNames, loc[2])
            return @editor ? loc[2] : maploc
          else
            return ""
          end
        end
      end
      return ""
    end
  end

  def pbChangeMapLocation(x, y)
    return if !@editor
    return "" if !@map[2]

    currentname = ""
    currentobj = nil
    for loc in @map[2]
      if loc[0] == x && loc[1] == y
        currentobj = loc
        currentname = loc[2]
        break
      end
    end
    currentname = Kernel.pbMessageFreeText(_INTL("Set the name for this point."), currentname, false, 256) { pbUpdate }
    if currentname
      if currentobj
        currentobj[2] = currentname
      else
        newobj = [x, y, currentname, ""]
        @map[2].push(newobj)
      end
      @changed = true
    end
  end

  def pbGetMapDetails(x, y) # From Wichu, with my help
    if Reborn
      mapdesc = @mapdata[[x, y]] ? pbGetMessageFromHash(MessageTypes::PlaceDescriptions, @mapdata[[x, y]].poi) : ""
      return mapdesc
    else
      return "" if !@map[2]

      for loc in @map[2]
        if loc[0] == x && loc[1] == y
          if !loc[7] || (!@wallmap && $game_switches[loc[7]])
            mapdesc = pbGetMessageFromHash(MessageTypes::PlaceDescriptions, loc[3])
            return @editor ? loc[3] : mapdesc
          else
            return ""
          end
        end
      end
      return ""
    end
  end

  def pbGetHealingSpot(x, y)
    if Reborn
      return nil if @mapdata[[x, y]].nil? || @mapdata[[x, y]].flyData.empty?

      healspot = @mapdata[[x, y]].flyData
      return healspot
    else
      return nil if !@map[2]

      for loc in @map[2]
        if loc[0] == x && loc[1] == y
          if !loc[4] || !loc[5] || !loc[6]
            return nil
          else
            return [loc[4], loc[5], loc[6]]
          end
        end
      end
      return nil
    end
  end

  def pbMapScene(mode = 0)
    xOffset = 0
    yOffset = 0
    newX = 0
    newY = 0
    @sprites["cursor"].x = -SQUAREWIDTH / 2 + (@mapX * SQUAREWIDTH) + (Graphics.width - @sprites["map"].bitmap.width) / 2
    @sprites["cursor"].y = -SQUAREHEIGHT / 2 + (@mapY * SQUAREHEIGHT) + (Graphics.height - @sprites["map"].bitmap.height) / 2
    lastreadlocation = nil
    loop do
      Graphics.update
      Input.update
      pbUpdate
      location = pbGetMapLocation(@mapX, @mapY)
      mapdetails = pbGetMapDetails(@mapX, @mapY)
      location += ", " + mapdetails if mapdetails
      if mode != 2 && location != lastreadlocation && location != ""
        lastreadlocation = location
        tts(location)
      end
      if xOffset != 0 || yOffset != 0
        xOffset += xOffset > 0 ? -4 : (xOffset < 0 ? 4 : 0)
        yOffset += yOffset > 0 ? -4 : (yOffset < 0 ? 4 : 0)
        @sprites["cursor"].x = newX - xOffset
        @sprites["cursor"].y = newY - yOffset
        next
      end
      @sprites["mapbottom"].maplocation = pbGetMapLocation(@mapX, @mapY)
      @sprites["mapbottom"].mapdetails = pbGetMapDetails(@mapX, @mapY)
      ox = 0
      oy = 0
      case Input.dir8
        when 1 # lower left
          oy = 1 if @mapY < BOTTOM
          ox = -1 if @mapX > LEFT
        when 2 # down
          oy = 1 if @mapY < BOTTOM
        when 3 # lower right
          oy = 1 if @mapY < BOTTOM
          ox = 1 if @mapX < RIGHT
        when 4 # left
          ox = -1 if @mapX > LEFT
        when 6 # right
          ox = 1 if @mapX < RIGHT
        when 7 # upper left
          oy = -1 if @mapY > TOP
          ox = -1 if @mapX > LEFT
        when 8 # up
          oy = -1 if @mapY > TOP
        when 9 # upper right
          oy = -1 if @mapY > TOP
          ox = 1 if @mapX < RIGHT
      end
      if ox != 0 || oy != 0
        @mapX += ox
        @mapY += oy
        xOffset = ox * SQUAREWIDTH
        yOffset = oy * SQUAREHEIGHT
        newX = @sprites["cursor"].x + xOffset
        newY = @sprites["cursor"].y + yOffset
      end
      if Input.trigger?(Input::B)
        if @editor && @changed
          if Kernel.pbConfirmMessage(_INTL("Save changes?")) { pbUpdate }
            pbSaveMapData
          end
          if Kernel.pbConfirmMessage(_INTL("Exit from the map?")) { pbUpdate }
            break
          end
        else
          break
        end
      elsif Input.trigger?(Input::C) && mode == 1 # Choosing an area to fly to
        healspot = pbGetHealingSpot(@mapX, @mapY)
        if healspot
          if $PokemonGlobal.visitedMaps[healspot[0]] ||
             ($DEBUG && Input.press?(Input::CTRL))
            return healspot
          end
        end
        # elsif Input.trigger?(Input::C) && @editor # Intentionally placed after other C button check
        # pbChangeMapLocation(@mapX, @mapY)
      end
    end
    return nil
  end
end

class PokemonRegionMap
  def initialize(scene)
    @scene = scene
  end

  def pbStartFlyScreen
    @scene.pbStartScene(false, 1)
    ret = @scene.pbMapScene(1)
    @scene.pbEndScene
    return ret
  end

  def pbStartScreen
    @scene.pbStartScene($DEBUG)
    @scene.pbMapScene
    @scene.pbEndScene
  end
end

def pbShowMap(region = -1, wallmap = true)
  pbFadeOutIn(99999) {
    scene = PokemonRegionMapScene.new(region, wallmap)
    screen = PokemonRegionMap.new(scene)
    screen.pbStartScreen
  }
end
