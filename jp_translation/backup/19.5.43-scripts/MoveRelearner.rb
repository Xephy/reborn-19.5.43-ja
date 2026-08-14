def pbEachNaturalMove(pokemon)
  movelist = pokemon.getMoveList
  for i in movelist
    yield i[1], i[0]
  end
end

def pbHasRelearnableMove?(pokemon)
  return pbGetRelearnableMoves(pokemon).length > 0
end

def pbGetRelearnableMoves(pokemon)
  return [] if !pokemon || pokemon.isEgg? || (pokemon.isShadow? rescue false)

  moves = []
  relearnmoves = pokemon.getRelearnList
  for move in relearnmoves
    if !pokemon.knowsMove?(move)
      moves.push(move) if !moves.include?(move)
    end
  end

  pbEachNaturalMove(pokemon) { |move, level|
    if level <= pokemon.level && !pokemon.knowsMove?(move)
      moves.push(move) if !moves.include?(move)
    end
  }
  tmoves = []
  if pokemon.firstmoves
    for i in pokemon.firstmoves
      tmoves.push(i) if !pokemon.knowsMove?(i) && !moves.include?(i)
    end
  end
  moves = tmoves + moves
  moves = tmoves + pokemon.getEggMoveList(true) + moves if Rejuv && $PokemonBag.pbHasItem?(:HM02)
  return moves | [] # remove duplicates
end

################################################################################
# Scene class for handling appearance of the screen
################################################################################
class MoveRelearnerScene
  VISIBLEMOVES = 4

  def pbDisplay(msg, brief = false)
    UIHelper.pbDisplay(@sprites["msgwindow"], msg, brief) { pbUpdate }
  end

  def pbConfirm(msg)
    UIHelper.pbConfirm(@sprites["msgwindow"], msg) { pbUpdate }
  end

  # Update the scene here, this is called once each frame
  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end

  def pbStartScene(pokemon, moves)
    @pokemon = pokemon
    @moves = moves
    moveCommands = []
    moves.each { |i| moveCommands.push(getMoveShortName(i)) }
    # Create sprite hash
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    addBackgroundPlane(@sprites, "bg", "reminderbg", @viewport)
    @sprites["pokeicon"] = PokemonIconSprite.new(@pokemon, @viewport)
    @sprites["pokeicon"].x = 288
    @sprites["pokeicon"].y = 44
    @sprites["background"] = IconSprite.new(0, 0, @viewport)
    @sprites["background"].setBitmap("Graphics/Pictures/reminderSel")
    @sprites["background"].y = 78
    @sprites["background"].src_rect = Rect.new(0, 72, 258, 72)
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    pbSetSystemFont(@sprites["overlay"].bitmap)
    @sprites["commands"] = Window_CommandPokemon.new(moveCommands, 32)
    @sprites["commands"].x = Graphics.width
    @sprites["commands"].height = 32 * (VISIBLEMOVES + 1)
    @sprites["msgwindow"] = Window_AdvancedTextPokemon.new("")
    @sprites["msgwindow"].visible = false
    @sprites["msgwindow"].viewport = @viewport
    pbDrawMoveList
    pbDeactivateWindows(@sprites)
    # Fade in all sprites
    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  def pbDrawMoveList
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    imagepos = []
    type1rect = Rect.new(0, 0, 64, 28)
    type2rect = Rect.new(0, 0, 64, 28)
    if @pokemon.type2.nil? || @pokemon.type1 == @pokemon.type2
      type1image = AnimatedBitmap.new(sprintf("Graphics/Icons/type%s", @pokemon.type1))
      overlay.blt(400, 70, type1image.bitmap, type1rect)
    else
      type1image = AnimatedBitmap.new(sprintf("Graphics/Icons/type%s", @pokemon.type1))
      overlay.blt(366, 70, type1image.bitmap, type1rect)
      type2image = AnimatedBitmap.new(sprintf("Graphics/Icons/type%s", @pokemon.type2))
      overlay.blt(436, 70, type2image.bitmap, type2rect)
    end
    textpos = [
      [_INTL("Teach which move?"), 16, 8, 0, Color.new(88, 88, 80), Color.new(168, 184, 184)]
    ]
    yPos = 82
    for i in 0...VISIBLEMOVES
      moveobject = @moves[@sprites["commands"].top_item + i]
      if moveobject
        movedata = $cache.moves[moveobject]
        if movedata
          typeimage = AnimatedBitmap.new(sprintf("Graphics/Icons/type%s", movedata.type))
          overlay.blt(12, yPos + 2, typeimage.bitmap, type1rect)
          textpos.push([getMoveShortName(moveobject), 80, yPos, 0, Color.new(248, 248, 248), Color.new(0, 0, 0)])
          if movedata.maxpp > 0
            textpos.push([_INTL("PP"), 112, yPos + 32, 0, Color.new(64, 64, 64), Color.new(176, 176, 176)])
            textpos.push([_ISPRINTF("{1:d}/{2:d}", movedata.maxpp, movedata.maxpp), 230, yPos + 32, 1, Color.new(64, 64, 64), Color.new(176, 176, 176)])
          end
        else
          textpos.push(["-", 80, yPos, 0, Color.new(64, 64, 64), Color.new(176, 176, 176)])
          textpos.push(["--", 228, yPos + 32, 1, Color.new(64, 64, 64), Color.new(176, 176, 176)])
        end
      end
      yPos += 64
    end
    imagepos.push(["Graphics/Pictures/reminderSel", 0, 78 + (@sprites["commands"].index - @sprites["commands"].top_item) * 64, 0, 0, 258, 72])
    selmovedata = $cache.moves[@moves[@sprites["commands"].index]]
    basedamage = selmovedata.basedamage
    category = selmovedata.category
    accuracy = selmovedata.accuracy

    textpos.push([_INTL("CATEGORY"), 272, 114, 0, Color.new(248, 248, 248), Color.new(0, 0, 0)])
    textpos.push([_INTL("POWER"), 272, 146, 0, Color.new(248, 248, 248), Color.new(0, 0, 0)])
    textpos.push([basedamage <= 1 ? basedamage == 1 ? "???" : "---" : sprintf("%d", basedamage), 468, 146, 2, Color.new(64, 64, 64), Color.new(176, 176, 176)])
    textpos.push([_INTL("ACCURACY"), 272, 178, 0, Color.new(248, 248, 248), Color.new(0, 0, 0)])
    textpos.push([accuracy == 0 ? "---" : sprintf("%d", accuracy), 468, 178, 2, Color.new(64, 64, 64), Color.new(176, 176, 176)])
    pbDrawTextPositions(overlay, textpos)
    case category
      when :physical then cattype = 0
      when :special  then cattype = 1
      when :status   then cattype = 2
    end
    imagepos.push(["Graphics/Pictures/category", 436, 116, 0, cattype * 28, 64, 28])
    if @sprites["commands"].index < @moves.length - 1
      imagepos.push(["Graphics/Pictures/reminderButtons", 48, 350, 0, 0, 76, 32])
    end
    if @sprites["commands"].index > 0
      imagepos.push(["Graphics/Pictures/reminderButtons", 134, 350, 76, 0, 76, 32])
    end
    pbDrawImagePositions(overlay, imagepos)
    drawTextEx(
      overlay, 272, 210, 238, 5,
      getMoveDesc(selmovedata.move),
      Color.new(64, 64, 64), Color.new(176, 176, 176)
    )
  end

  # Processes the scene
  def pbChooseMove
    oldcmd = -1
    pbActivateWindow(@sprites, "commands") {
      loop do
        oldcmd = @sprites["commands"].index
        Graphics.update
        Input.update
        pbUpdate
        if @sprites["commands"].index != oldcmd
          @sprites["background"].x = 0
          @sprites["background"].y = 78 + (@sprites["commands"].index - @sprites["commands"].top_item) * 64
          pbDrawMoveList
        end
        if Input.trigger?(Input::B)
          return 0
        end
        if Input.trigger?(Input::C)
          return @moves[@sprites["commands"].index]
        end
      end
    }
  end

  # End the scene here
  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate } # Fade out all sprites
    pbDisposeSpriteHash(@sprites) # Dispose all sprites
    @viewport.dispose # Dispose the viewport
  end
end

# Screen class for handling game logic
class MoveRelearnerScreen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen(pokemon)
    if $game_variables[:E4_Tracker] > 0
      Kernel.pbMessage(_INTL("Cannot use the Move Relearn here."))
      return false
    end

    unless pbHasRelearnableMove?(pokemon)
      Kernel.pbMessage(_INTL("There are no moves this Pokémon can relearn."))
      return false
    end

    moves = pbGetRelearnableMoves(pokemon)
    @scene.pbStartScene(pokemon, moves)
    loop do
      move = @scene.pbChooseMove
      if !move.is_a?(Symbol)
        if @scene.pbConfirm(
          _INTL("Give up trying to teach a new move to {1}?", pokemon.name)
        )
          @scene.pbEndScene
          return false
        end
      else
        if @scene.pbConfirm(_INTL("Teach {1}?", getMoveName(move)))
          if pbLearnMove(pokemon, move)
            pokemon.updateRelearnBar if !pokemon.canRelearnAll? && !Desolation
            @scene.pbEndScene
            return true
          end
        end
      end
    end
  end
end

def pbRelearnMoveScreen(pokemon)
  retval = true
  pbFadeOutIn(99999) {
    scene = MoveRelearnerScene.new
    screen = MoveRelearnerScreen.new(scene)
    retval = screen.pbStartScreen(pokemon)
  }
  return retval
end
