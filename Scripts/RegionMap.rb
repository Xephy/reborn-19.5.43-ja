class MapBottomSprite < SpriteWrapper
  attr_reader :mapname, :maplocation

  def initialize(viewport = nil)
    super(viewport)
    @mapname = ""
    @maplocation = ""
    @mapdetails = ""
    # Control hint, drawn top-right. Only the Region Map sets it; every other
    # user of this sprite (the Pokedex nest view) leaves it empty.
    @hint = ""
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

  def hint=(value)
    if @hint != value
      @hint = value
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
      [@mapdetails, Graphics.width - 16, 354, 1, Color.new(248, 248, 248), Color.new(0, 0, 0)],
      [@hint, Graphics.width - 16, -2, 1, Color.new(192, 208, 224), Color.new(0, 0, 0)]
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

# The place list on the Region Map. Places the player has not set foot in are
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

class PokemonRegionMapScene
  LEFT   = 0
  TOP    = 0
  RIGHT  = 14
  RIGHT  = 29 if Desolation
  BOTTOM = 18
  BOTTOM = 19 if Desolation
  SQUAREWIDTH  = 16
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
  LISTHIDEUNVISITED = false

  def initialize(region = -1, wallmap = true)
    @region = region
    @wallmap = wallmap
  end

  def pbUpdate
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
    @sprites["map"].x += MAPX
    @sprites["map"].y += MAPY
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
      @sprites["player"].x = -SQUAREWIDTH / 2 + (@mapX * SQUAREWIDTH) + MAPX
      @sprites["player"].y = -SQUAREHEIGHT / 2 + (@mapY * SQUAREHEIGHT) + MAPY
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
        @sprites["roaming#{i}"].x = SQUAREWIDTH / 2 - @sprites["roaming#{i}"].bitmap.width / 2 + (positiondata[1] * SQUAREWIDTH) + MAPX
        @sprites["roaming#{i}"].y = SQUAREHEIGHT / 2 - @sprites["roaming#{i}"].bitmap.height / 2 + (positiondata[2] * SQUAREHEIGHT) + MAPY
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
            @sprites["point#{k}"].x = -SQUAREWIDTH / 2 + (i * SQUAREWIDTH) + MAPX
            @sprites["point#{k}"].y = -SQUAREHEIGHT / 2 + (j * SQUAREHEIGHT) + MAPY
            @sprites["point#{k}"].play
            k += 1
          end
        end
      end
    end
    @sprites["cursor"] = AnimatedSprite.create("Graphics/Pictures/mapCursor", 2, 15)
    @sprites["cursor"].viewport = @viewport
    @sprites["cursor"].play
    @sprites["cursor"].x = -SQUAREWIDTH / 2 + (@mapX * SQUAREWIDTH) + MAPX
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
    @sprites["cursor"].x = -SQUAREWIDTH / 2 + (@mapX * SQUAREWIDTH) + MAPX
    @sprites["cursor"].y = -SQUAREHEIGHT / 2 + (@mapY * SQUAREHEIGHT) + MAPY
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
        pbSyncListToCursor # highlight the row for the area under the cursor
      end
      if Input.trigger?(Input::B)
        # The free map cursor is a sub-mode of the list, so B backs out to the
        # list; B on the list closes the screen. The editor keeps its prompts.
        if @sprites["placelist"] && !@editor
          pbSetFocus(:list, mode)
          pbPlayCancelSE
          next
        end
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
