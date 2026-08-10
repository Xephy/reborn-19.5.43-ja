=begin
-  def pbChooseNewEnemy(index,party)
Use this method to choose a new Pokémon for the enemy
The enemy's party is guaranteed to have at least one
choosable member.
index - Index to the battler to be replaced (use e.g. @battle.battlers[index] to
access the battler)
party - Enemy's party

- def pbWildBattleSuccess
This method is called when the player wins a wild Pokémon battle.
This method can change the battle's music for example.

- def pbTrainerBattleSuccess
This method is called when the player wins a Trainer battle.
This method can change the battle's music for example.

- def pbFainted(pkmn)
This method is called whenever a Pokémon faints.
pkmn - PokeBattle_Battler object indicating the Pokémon that fainted

- def pbChooseEnemyCommand(index)
Use this method to choose a command for the enemy.
index - Index of enemy battler (use e.g. @battle.battlers[index] to
access the battler)

- def pbCommandMenu(index)
Use this method to display the list of commands and choose
a command for the player.
index - Index of battler (use e.g. @battle.battlers[index] to
access the battler)
Return values:
0 - Fight
1 - Pokémon
2 - Bag
3 - Run
=end

#===============================================================================
# Command menu (Fight/Pokémon/Bag/Run)
#===============================================================================
class CommandMenuDisplay
  attr_accessor :mode

  def initialize(viewport = nil)
    @display = nil
    if PBScene::USECOMMANDBOX
      @display = IconSprite.new(0, Graphics.height - 96, viewport)
      @display.setBitmap("Graphics/Pictures/Battle/battleCommand")
    end
    @window = Window_CommandPokemon.newWithSize([], Graphics.width - 240, Graphics.height - 96, 240, 96, viewport)
    @window.columns = 2
    @window.columnSpacing = 4
    @window.ignore_input = true
    @msgbox = Window_UnformattedTextPokemon.newWithSize("", 16, Graphics.height - 96 + 2, 220, 96, viewport)
    @msgbox.baseColor = PBScene::MESSAGEBASE
    @msgbox.shadowColor = PBScene::MESSAGESHADOW
    @msgbox.windowskin = nil
    @title = ""
    @buttons = nil
    if PBScene::USECOMMANDBOX
      @window.opacity = 0
      @window.x = Graphics.width
      @buttons = CommandMenuButtons.new(self.index, self.mode, viewport)
    end
  end

  def x; @window.x; end

  def x=(value)
    @window.x = value
    @msgbox.x = value
    @display.x = value if @display
    @buttons.x = value if @buttons
  end

  def y; @window.y; end

  def y=(value)
    @window.y = value
    @msgbox.y = value
    @display.y = value if @display
    @buttons.y = value if @buttons
  end

  def z; @window.z; end

  def z=(value)
    @window.z = value
    @msgbox.z = value
    @display.z = value if @display
    @buttons.z = value + 1 if @buttons
  end

  def ox; @window.ox; end

  def ox=(value)
    @window.ox = value
    @msgbox.ox = value
    @display.ox = value if @display
    @buttons.ox = value if @buttons
  end

  def oy; @window.oy; end

  def oy=(value)
    @window.oy = value
    @msgbox.oy = value
    @display.oy = value if @display
    @buttons.oy = value if @buttons
  end

  def visible; @window.visible; end

  def visible=(value)
    @window.visible = value
    @msgbox.visible = value
    @display.visible = value if @display
    @buttons.visible = value if @buttons
  end

  def color; @window.color; end

  def color=(value)
    @window.color = value
    @msgbox.color = value
    @display.color = value if @display
    @buttons.color = value if @buttons
  end

  def disposed?
    return @msgbox.disposed? || @window.disposed?
  end

  def dispose
    return if disposed?

    @msgbox.dispose
    @window.dispose
    @display.dispose if @display
    @buttons.dispose if @buttons
  end

  def index; @window.index; end
  def index=(value); @window.index = value; end

  def setTexts(value)
    @msgbox.text = value[0]
    commands = []
    for i in 1..4
      commands.push(value[i]) if value[i] && value[i] != nil
    end
    @window.commands = commands
  end

  def refresh
    @msgbox.refresh
    @window.refresh
    @buttons.refresh(self.index, self.mode) if @buttons
  end

  def update
    @msgbox.update
    @window.update
    @display.update if @display
    @buttons.update(self.index, self.mode) if @buttons
  end
end

class CommandMenuButtons < BitmapSprite
  def initialize(index = 0, mode = 0, viewport = nil)
    super(260, 96, viewport)
    self.x = Graphics.width - 260
    self.y = Graphics.height - 96
    @mode = mode
    @buttonbitmap = AnimatedBitmap.new(_INTL("Graphics/Pictures/Battle/battleCommandButtons"))
    refresh(index, mode)
  end

  def dispose
    @buttonbitmap.dispose
    super
  end

  def update(index = 0, mode = 0)
    refresh(index, mode)
  end

  def refresh(index, mode = 0)
    self.bitmap.clear
    @mode = mode
    cmdarray = [0, 2, 1, 3]
    case @mode
      when 1
        cmdarray = [0, 2, 1, 4] # Use "Call"
      when 2
        cmdarray = [5, 7, 6, 3] # Safari Zone battle
      when 3
        cmdarray = [0, 8, 1, 3] # Bug Catching Contest
    end
    for i in 0...4
      next if i == index

      x = ((i % 2) == 0) ? 0 : 126
      y = ((i / 2) == 0) ? 6 : 48
      self.bitmap.blt(x, y, @buttonbitmap.bitmap, Rect.new(0, cmdarray[i] * 46, 130, 46))
    end
    for i in 0...4
      next if i != index

      x = ((i % 2) == 0) ? 0 : 126
      y = ((i / 2) == 0) ? 6 : 48
      self.bitmap.blt(x, y, @buttonbitmap.bitmap, Rect.new(130, cmdarray[i] * 46, 130, 46))
    end
  end
end

class FightMenuDisplay
  attr_reader :battler
  attr_reader :index
  attr_accessor :megaButton
  attr_accessor :ultraButton
  attr_accessor :zButton

  def initialize(battler, viewport = nil)
    @display = nil
    if PBScene::USEFIGHTBOX
      @display = IconSprite.new(0, Graphics.height - 96, viewport)
      @display.setBitmap("Graphics/Pictures/Battle/battleFight")
    end
    @window = Window_CommandPokemon.newWithSize([], 0, Graphics.height - 96, 320, 96, viewport)
    @window.tts = false
    @window.columns = 2
    @window.columnSpacing = 4
    @window.ignore_input = true
    pbSetNarrowFont(@window.contents)
    @info = Window_AdvancedTextPokemon.newWithSize(
      "", 320, Graphics.height - 96, Graphics.width - 320, 96, viewport
    )
    pbSetNarrowFont(@info.contents)
    @ctag = shadowctag(PBScene::MENUBASE, PBScene::MENUSHADOW)
    @buttons = nil
    @battler = battler
    @index = 0
    @megaButton = 0 # 0=don't show, 1=show, 2=pressed
    @ultraButton = 0 # 0=don't show, 1=show, 2=pressed
    @zButton = 0 # 0=don't show, 1=show, 2=pressed
    if PBScene::USEFIGHTBOX
      @window.opacity = 0
      @window.x = Graphics.width
      @info.opacity = 0
      @info.x = Graphics.width + Graphics.width - 96
      @buttons = FightMenuButtons.new(self.index, nil, viewport)
    end
    refresh
  end

  def x; @window.x; end

  def x=(value)
    @window.x = value
    @info.x = value
    @display.x = value if @display
    @buttons.x = value if @buttons
  end

  def y; @window.y; end

  def y=(value)
    @window.y = value
    @info.y = value
    @display.y = value if @display
    @buttons.y = value if @buttons
  end

  def z; @window.z; end

  def z=(value)
    @window.z = value
    @info.z = value
    @display.z = value if @display
    @buttons.z = value + 1 if @buttons
  end

  def ox; @window.ox; end

  def ox=(value)
    @window.ox = value
    @info.ox = value
    @display.ox = value if @display
    @buttons.ox = value if @buttons
  end

  def oy; @window.oy; end

  def oy=(value)
    @window.oy = value
    @info.oy = value
    @display.oy = value if @display
    @buttons.oy = value if @buttons
  end

  def visible; @window.visible; end

  def visible=(value)
    @window.visible = value
    @info.visible = value
    @display.visible = value if @display
    @buttons.visible = value if @buttons
  end

  def color; @window.color; end

  def color=(value)
    @window.color = value
    @info.color = value
    @display.color = value if @display
    @buttons.color = value if @buttons
  end

  def disposed?
    return @info.disposed? || @window.disposed?
  end

  def dispose
    return if disposed?

    @info.dispose
    @display.dispose if @display
    @buttons.dispose if @buttons
    @window.dispose
  end

  def battler=(value)
    @battler = value
    refresh
  end

  def setIndex(value)
    if @battler && @battler.moves[value]
      @index = value
      @window.index = value
      refresh
      return true
    end
    return false
  end

  def refresh
    return if !@battler

    commands = []
    for i in 0...@battler.moves.length
      break if !@battler.moves[i]

      commands.push(@battler.moves[i].name)
    end
    @window.commands = commands
    selmove = @battler.moves[@index] ? @battler.moves[@index] : @battler.moves[0]
    movetype = getTypeName(selmove.type)
    if selmove.totalpp == 0
      @info.text = _ISPRINTF("{1:s}PP: ---<br>TYPE/{2:s}", @ctag, movetype)
    else
      @info.text = _ISPRINTF("{1:s}PP: {2: 2d}/{3: 2d}<br>TYPE/{4:s}", @ctag, selmove.pp, selmove.totalpp, movetype)
    end
  end

  def update
    @info.update
    @window.update
    @display.update if @display
    if @buttons
      @buttons.update(self.index, @battler, @megaButton, @zButton, @ultraButton)
    end
  end
end

class FightMenuButtons < BitmapSprite
  UPPERGAP = 46

  def initialize(index = 0, moves = nil, viewport = nil)
    super(Graphics.width, 96 + UPPERGAP, viewport)
    self.x = 0
    self.y = Graphics.height - 96 - UPPERGAP
    pbSetNarrowFont(self.bitmap)
    @megaevobitmap = AnimatedBitmap.new(_INTL("Graphics/Pictures/Battle/battleMegaEvo"))
    @ultraburstbitmap = AnimatedBitmap.new(_INTL("Graphics/Pictures/Battle/battleMegaEvo"))
    @zmovebitmap = AnimatedBitmap.new(_INTL("Graphics/Pictures/Battle/battleZMove"))
    @goodmovebitmap = AnimatedBitmap.new(_INTL("Graphics/Pictures/Battle/fieldUp"))
    @badmovebitmap = AnimatedBitmap.new(_INTL("Graphics/Pictures/Battle/fieldDown"))
    refresh(index, moves, 0, 0, 0)
  end

  def dispose
    @megaevobitmap.dispose
    @ultraburstbitmap.dispose
    @zmovebitmap.dispose
    @goodmovebitmap.dispose
    @badmovebitmap.dispose
    super
  end

  def update(index = 0, battler = nil, megaButton = 0, zButton = 0, ultraButton = 0)
    refresh(index, battler, megaButton, zButton, ultraButton)
  end

  def refresh(index, battler, megaButton, zButton, ultraButton)
    return if !battler

    moves = nil
    if battler.moves
      moves = []
      for move in battler.moves
        moves.push(move)
      end
    end
    if zButton == 2 && !battler.zmoves.nil?
      for i in 0...battler.zmoves.length
        next if battler.zmoves[i].nil?

        moves[i] = battler.zmoves[i]
      end
    end
    return if !moves

    self.bitmap.clear
    textpos = []
    for i in 0...4
      next if i == index
      next if !moves[i]

      x = ((i % 2) == 0) ? 4 : 192
      y = ((i / 2) == 0) ? 6 : 48
      y += UPPERGAP
      imagepos = []
      movetype = moves[i].pbType(battler, moves[i].type)
      imagepos.push([sprintf("Graphics/Pictures/Battle/battleFightButtons%s", movetype), x, y, 0, 0, 192, 46])
      pbDrawImagePositions(self.bitmap, imagepos)
      textpos.push([_INTL("{1}", moves[i].name), x + 96, y + 12, 2, PBScene::MENUBASE, PBScene::MENUSHADOW])
    end
    ppcolors = [
      PBScene::PPBASE, PBScene::PPSHADOW,
      PBScene::PPBASE, PBScene::PPSHADOW,
      PBScene::PPBASEYELLOW, PBScene::PPSHADOWYELLOW,
      PBScene::PPBASEORANGE, PBScene::PPSHADOWORANGE,
      PBScene::PPBASERED, PBScene::PPSHADOWRED
    ]
    for i in 0...4
      next if i != index
      next if !moves[i]

      x = ((i % 2) == 0) ? 4 : 192
      y = ((i / 2) == 0) ? 6 : 48
      y += UPPERGAP
      imagepos = []
      movetype = moves[i].pbType(battler, moves[i].type)
      secondtype = moves[i].getSecondaryType(battler)
      secondtype = [:RAINBOW] if !secondtype.nil? && moves[i].move != :FLYINGPRESS && moves[i].battle.FE == :RAINBOW
      secondtype = [:CRYSTAL] if !secondtype.nil? && moves[i].move != :FLYINGPRESS && moves[i].battle.FE == :CRYSTALCAVERN
      if secondtype.nil? || secondtype.include?(movetype)
        imagepos.push([sprintf("Graphics/Icons/type%s", movetype), 416, 20 + UPPERGAP, 0, 0, 64, 28])
      elsif secondtype.length == 1
        imagepos.push([sprintf("Graphics/Icons/type%s", movetype), 402, 20 + UPPERGAP, 0, 0, 64, 28])
        imagepos.push([sprintf("Graphics/Icons/minitype%s", secondtype[0]), 466, 20 + UPPERGAP, 0, 0, 28, 28])
      else
        imagepos.push([sprintf("Graphics/Icons/minitype%s", movetype), 404, 20 + UPPERGAP, 0, 0, 64, 28])
        imagepos.push([sprintf("Graphics/Icons/minitype%s", secondtype[0]), 432, 20 + UPPERGAP, 0, 0, 28, 28])
        imagepos.push([sprintf("Graphics/Icons/minitype%s", secondtype[1]), 460, 20 + UPPERGAP, 0, 0, 28, 28])
      end
      imagepos.push([sprintf("Graphics/Pictures/Battle/battleFightButtons%s", movetype), x, y, 192, 0, 192, 46])
      textpos.push([_INTL("{1}", moves[i].name), x + 96, y + 12, 2, PBScene::MENUBASE, PBScene::MENUSHADOW])
      if moves[i].totalpp > 0
        ppfraction = (4.0 * moves[i].pp / moves[i].totalpp).ceil
        textpos.push([_INTL("PP: {1}/{2}", moves[i].pp, moves[i].totalpp), 448, 50 + UPPERGAP, 2, ppcolors[(4 - ppfraction) * 2], ppcolors[(4 - ppfraction) * 2 + 1]])
      end
    end
    pbDrawImagePositions(self.bitmap, imagepos)
    for i in 0...4
      next if !moves[i]

      x = ((i % 2) == 0) ? 4 : 192
      y = ((i / 2) == 0) ? 6 : 48
      y += UPPERGAP
      y -= 2 if Rejuv
      case pbFieldNotesBattle(moves[i])
        when 1 then self.bitmap.blt(x + 2, y + 2, @goodmovebitmap.bitmap, Rect.new(0, 0, @goodmovebitmap.bitmap.width, @goodmovebitmap.bitmap.height))
        when 2 then self.bitmap.blt(x + 2, y + 2, @badmovebitmap.bitmap, Rect.new(0, 0, @badmovebitmap.bitmap.width, @badmovebitmap.bitmap.height))
      end
    end
    pbDrawTextPositions(self.bitmap, textpos)
    if megaButton > 0
      self.bitmap.blt(146, 0, @megaevobitmap.bitmap, Rect.new(0, (megaButton - 1) * 46, 96, 46))
    end
    if ultraButton > 0
      self.bitmap.blt(146, 0, @megaevobitmap.bitmap, Rect.new(0, (ultraButton - 1) * 46, 96, 46))
    end
    if zButton > 0
      self.bitmap.blt(146, 0, @zmovebitmap.bitmap, Rect.new(0, (zButton - 1) * 46, 96, 46))
    end
  end
end

class PokemonBattlerSprite < RPG::Sprite
  attr_accessor :selected
  attr_reader :index

  def initialize(doublebattle, index, viewport = nil)
    super(viewport)
    @selected = 0
    @frame = 0
    @index = index
    @updating = false
    @doublebattle = doublebattle
    @index = index
    @spriteX = 0
    @spriteY = 0
    @spriteXExtra = 0
    @spriteYExtra = 0
    @spriteVisible = false
    @_iconbitmap = nil
    self.visible = false
  end

  def x
    return @spriteX
  end

  def y
    return @spriteY
  end

  def x=(value)
    @spriteX = value
    super(value + @spriteXExtra)
  end

  def y=(value)
    @spriteY = value
    super(value + @spriteYExtra)
  end

  def width; return (self.bitmap) ? self.bitmap.width : 0; end
  def height; return (self.bitmap) ? self.bitmap.height : 0; end

  def dispose
    @_iconbitmap.dispose if @_iconbitmap
    @_iconbitmap = nil
    self.bitmap = nil if !self.disposed?
    super
  end

  def selected=(value)
    if @selected == 1 && value != 1 && @spriteYExtra > 0
      @spriteYExtra = 0
      self.y = @spriteY
    end
    @selected = value
  end

  def visible=(value)
    @spriteVisible = value if !@updating
    super
  end

  def setPokemonBitmap(pokemon, back = false)
    @_iconbitmap.dispose if @_iconbitmap
    self.bitmap = pbLoadPokemonBitmap(pokemon, back)
  end

  def setPokemonBitmapSpecies(pokemon, species, back = false)
    @_iconbitmap.dispose if @_iconbitmap
    self.bitmap = pbLoadPokemonBitmapSpecies(pokemon, species, back)
  end

  def update
    @frame += 1
    @updating = true
    @spriteYExtra = 0
    # Pokémon sprite bobbing while Pokémon is selected
    if ((@frame / 10).floor & 1) == 1 && @selected == 1 # When choosing commands for this Pokémon
      @spriteYExtra = 2
    end
    self.x = @spriteX
    self.y = @spriteY
    self.visible = @spriteVisible
    # Pokémon sprite blinking when targeted or damaged
    if @selected == 2 # When targeted or damaged
      self.visible = (@frame % 10 < 7)
    end
    if @_iconbitmap
      @_iconbitmap.update
      self.bitmap = @_iconbitmap.bitmap
    end
    @updating = false
  end
end

class SafariDataBox < SpriteWrapper
  attr_accessor :selected
  attr_reader :appearing

  def initialize(battle, viewport = nil)
    super(viewport)
    @selected = 0
    @battle = battle
    @databox = AnimatedBitmap.new("Graphics/Pictures/Battle/battlePlayerSafari")
    @spriteX = PBScene::SAFARIBOX_X
    @spriteY = PBScene::SAFARIBOX_Y
    @appearing = false
    @contents = BitmapWrapper.new(@databox.width, @databox.height)
    self.bitmap = @contents
    self.visible = false
    self.z = 50
    refresh
  end

  def appear
    refresh
    self.visible = true
    self.opacity = 255
    self.x = @spriteX + 240
    self.y = @spriteY
    @appearing = true
  end

  def refresh
    self.bitmap.clear
    self.bitmap.blt(0, 0, @databox.bitmap, Rect.new(0, 0, @databox.width, @databox.height))
    pbSetSystemFont(self.bitmap)
    textpos = []
    base = PBScene::BOXBASE
    shadow = PBScene::BOXSHADOW
    textpos.push([_INTL("Safari Balls"), 30, 8, false, base, shadow])
    textpos.push([_INTL("Left: {1}", @battle.ballcount), 30, 38, false, base, shadow])
    pbDrawTextPositions(self.bitmap, textpos)
  end

  def update
    super
    if @appearing
      self.x -= 8
      @appearing = false if self.x <= @spriteX
      self.y = @spriteY
      return
    end
    self.x = @spriteX
    self.y = @spriteY
  end
end

class PokemonDataBox < SpriteWrapper
  attr_reader :battler
  attr_accessor :selected
  attr_accessor :appearing
  attr_reader :animatingHP
  attr_reader :animatingEXP
  attr_accessor :doublebattle

  @@statsBoostsData = nil # Force the reloading of disposed graphics on soft resetting

  def initialize(battler, doublebattle, viewport = nil)
    super(viewport)
    @explevel = 0
    @battler = battler
    @selected = 0
    @frame = 0
    @showhp = false
    @showexp = false
    @appearing = false
    @animatingHP = false
    @animatingScale = 0 # add this line
    @starthp = 0
    @currenthp = 0
    @endhp = 0
    @expflash = 0
    @doublebattle = doublebattle
    if (@battler.index & 1) == 0 # if player's Pokémon
      @spritebaseX = 34
    else
      @spritebaseX = 16
    end
    @spritebaseY = 0
    if doublebattle
      case @battler.index
        when 0
          @databox = AnimatedBitmap.new("Graphics/Pictures/Battle/battlePlayerBoxD")
          @spriteX = PBScene::PLAYERBOXD1_X
          @spriteY = PBScene::PLAYERBOXD1_Y
        when 1
          if @battler.issossmon
            @databox = AnimatedBitmap.new("Graphics/Pictures/Battle/boss_bar_sos")
            @spriteX = PBScene::FOEBOXD1_X - 12
            @spriteY = PBScene::FOEBOXD1_Y - 24
          else
            @databox = AnimatedBitmap.new("Graphics/Pictures/Battle/battleFoeBoxD")
            @spriteX = PBScene::FOEBOXD1_X
            @spriteY = PBScene::FOEBOXD1_Y
          end
        when 2
          @databox = AnimatedBitmap.new("Graphics/Pictures/Battle/battlePlayerBoxD")
          @spriteX = PBScene::PLAYERBOXD2_X
          @spriteY = PBScene::PLAYERBOXD2_Y
        when 3
          if @battler.issossmon
            @databox = AnimatedBitmap.new("Graphics/Pictures/Battle/boss_bar_sos")
            @spriteX = PBScene::FOEBOXD2_X + 4
            @spriteY = PBScene::FOEBOXD2_Y + 24
          else
            @databox = AnimatedBitmap.new("Graphics/Pictures/Battle/battleFoeBoxD")
            @spriteX = PBScene::FOEBOXD2_X
            @spriteY = PBScene::FOEBOXD2_Y
          end
      end
    else
      case @battler.index
        when 0
          @databox = AnimatedBitmap.new("Graphics/Pictures/Battle/battlePlayerBoxS")
          @spriteX = PBScene::PLAYERBOX_X
          @spriteY = PBScene::PLAYERBOX_Y
          @showhp = true
          @showexp = true
        when 1
          @databox = AnimatedBitmap.new("Graphics/Pictures/Battle/battleFoeBoxS")
          @spriteX = PBScene::FOEBOX_X
          @spriteY = PBScene::FOEBOX_Y
      end
    end
    @contents = BitmapWrapper.new(@databox.width, @databox.height)
    self.bitmap = @contents
    self.visible = false
    self.z = 50
    refreshExpLevel
    refresh
  end

  def dispose
    @databox.dispose
    @contents.dispose
    super
  end

  def refreshExpLevel
    if !@battler.pokemon
      @explevel = 0
    else
      growthrate = @battler.pokemon.growthrate
      startexp = PBExp.startExperience(@battler.pokemon.level, growthrate)
      endexp = PBExp.startExperience(@battler.pokemon.level + 1, growthrate)
      if startexp == endexp
        @explevel = 0
      else
        @explevel = (@battler.pokemon.exp - startexp) * PBScene::EXPGAUGESIZE / (endexp - startexp)
      end
    end
  end

  def exp
    return @animatingEXP ? @currentexp : @explevel
  end

  def hp
    return @animatingHP ? @currenthp : @battler.hp
  end

  def animateHP(oldhp, newhp)
    @starthp = oldhp
    @currenthp = oldhp
    @endhp = newhp
    @animatingHP = true
  end

  def animateEXP(oldexp, newexp)
    @currentexp = oldexp
    @endexp = newexp
    @animatingEXP = true
  end

  def appear
    refreshExpLevel
    refresh
    self.visible = true
    self.opacity = 255
    if (@battler.index & 1) == 0 # if player's Pokémon
      self.x = @spriteX + 320
    else
      self.x = @spriteX - 320
    end
    self.y = @spriteY
    @appearing = true
  end

  def refresh(loopstop = false)
    self.bitmap.clear
    return if !@battler.pokemon

    self.bitmap.blt(0, 0, @databox.bitmap, Rect.new(0, 0, @databox.width, @databox.height))
    base = PBScene::BOXBASE
    shadow = PBScene::BOXSHADOW
    pokename = @battler.name
    pbSetSystemFont(self.bitmap)
    textpos = [
      [pokename, @spritebaseX + 8, @spritebaseY + 6, false, base, shadow]
    ]
    genderX = self.bitmap.text_size(pokename).width
    genderX += @spritebaseX + 14
    if genderX > 165 && !@doublebattle && (@battler.index & 1) == 1 # opposing pokemon
      genderX = 224
    end
    gendertarget = @battler.effects[:Illusion] ? @battler.effects[:Illusion] : @battler
    if gendertarget.gender == 0 # Male
      textpos.push([_INTL("♂"), genderX, @spritebaseY + 6, false, Color.new(48, 96, 216), shadow])
    elsif gendertarget.gender == 1 # Female
      textpos.push([_INTL("♀"), genderX, @spritebaseY + 6, false, Color.new(248, 88, 40), shadow])
    end
    pbDrawTextPositions(self.bitmap, textpos)
    pbSetSmallFont(self.bitmap)
    textpos = [[_INTL("Lv{1}", $game_switches[:Level_999] && (@battler.index % 2) == 1 ? 999 : @battler.level), @spritebaseX + 202, @spritebaseY + 12, true, base, shadow]]
    if @showhp
      hpstring = _ISPRINTF("{1: 2d}/{2: 2d}", self.hp, @battler.totalhp)
      textpos.push([hpstring, @spritebaseX + 188, @spritebaseY + 52, true, base, shadow])
    end
    pbDrawTextPositions(self.bitmap, textpos)
    imagepos = []
    if (@battler.pokemon.isShiny? && @battler.effects[:Illusion].nil?) || (!@battler.effects[:Illusion].nil? && @battler.effects[:Illusion].pokemon.isShiny?)
      shinyX = 206
      shinyX = 6 if (@battler.index & 1) == 0 # If player's Pokémon
      imagepos.push(["Graphics/Pictures/shiny.png", @spritebaseX + shinyX, @spritebaseY + 36, 0, 0, -1, -1])
    end
    megaY = 34
    megaY = 38 if (@battler.index & 1) == 0 # If player's Pokémon
    megaX = 8
    megaX = -8 if (@battler.index & 1) == 0 # If player's Pokémon
    if @battler.pokemon.isPulse?
      imagepos.push(["Graphics/Pictures/Battle/battlePulseEvoBox.png", @spritebaseX + megaX, @spritebaseY + megaY, 0, 0, -1, -1])
    elsif @battler.pokemon.isRift?
      imagepos.push(["Graphics/Pictures/Battle/battleRiftEvoBox.png", @spritebaseX + megaX, @spritebaseY + megaY, 0, 0, -1, -1])
    elsif @battler.pokemon.isPerfection?
      imagepos.push(["Graphics/Pictures/Battle/battlePerfectionEvoBox.png", @spritebaseX + megaX, @spritebaseY + megaY, 0, 0, -1, -1])
    elsif @battler.isMega?
      imagepos.push(["Graphics/Pictures/Battle/battleMegaEvoBox.png", @spritebaseX + megaX, @spritebaseY + megaY, 0, 0, -1, -1])
    elsif @battler.isUltra? # Maybe temporary until new icon
      imagepos.push(["Graphics/Pictures/Battle/battleMegaEvoBox.png", @spritebaseX + megaX, @spritebaseY + megaY, 0, 0, -1, -1])
    end
    if @battler.owned && (@battler.index & 1) == 1
      imagepos.push(["Graphics/Pictures/Battle/battleBoxOwned.png", @spritebaseX + 8, @spritebaseY + 36, 0, 0, -1, -1])
    end
    pbDrawImagePositions(self.bitmap, imagepos)
    statuses = { :SLEEP => 0, :POISON => 1, :BURN => 2, :PARALYSIS => 3, :FROZEN => 4 }
    if !@battler.status.nil?
      imagepos = []
      if Reborn
        imagepos.push(["Graphics/Pictures/Battle/BattleStatuses", @spritebaseX + 24, @spritebaseY + 36, 0, 16 * statuses[@battler.status], 64, 16])
      else
        imagepos.push([sprintf("Graphics/Pictures/Battle/BattleStatuses%s", @battler.status), @spritebaseX + 24, @spritebaseY + 36, 0, 0, 64, 28])
      end
      pbDrawImagePositions(self.bitmap, imagepos)
    end
    hpGaugeSize = PBScene::HPGAUGESIZE
    hpgauge = @battler.totalhp == 0 ? 0 : (self.hp * hpGaugeSize / @battler.totalhp)
    hpgauge = 2 if hpgauge == 0 && self.hp > 0
    hpzone = 0
    hpzone = 1 if self.hp <= (@battler.totalhp / 2.0).floor
    hpzone = 2 if self.hp <= (@battler.totalhp / 4.0).floor
    hpcolors = [
      PBScene::HPGREENDARK,
      PBScene::HPGREEN,
      PBScene::HPYELLOWDARK,
      PBScene::HPYELLOW,
      PBScene::HPREDDARK,
      PBScene::HPRED
    ]
    # fill with black (shows what the HP used to be)
    hpGaugeX = PBScene::HPGAUGE_X
    hpGaugeY = PBScene::HPGAUGE_Y
    if @animatingHP && self.hp > 0
      self.bitmap.fill_rect(@spritebaseX + hpGaugeX, @spritebaseY + hpGaugeY, @starthp * hpGaugeSize / @battler.totalhp, 6, Color.new(0, 0, 0))
    end
    # fill with HP color
    self.bitmap.fill_rect(@spritebaseX + hpGaugeX, @spritebaseY + hpGaugeY, hpgauge, 2, hpcolors[hpzone * 2])
    self.bitmap.fill_rect(@spritebaseX + hpGaugeX, @spritebaseY + hpGaugeY + 2, hpgauge, 4, hpcolors[hpzone * 2 + 1])
    if @showexp
      # fill with EXP color
      expGaugeX = PBScene::EXPGAUGE_X
      expGaugeY = PBScene::EXPGAUGE_Y
      self.bitmap.fill_rect(@spritebaseX + expGaugeX, @spritebaseY + expGaugeY, self.exp.clamp(0, PBScene::EXPGAUGESIZE), 2, PBScene::EXPCOLORSHADOW)
      self.bitmap.fill_rect(@spritebaseX + expGaugeX, @spritebaseY + expGaugeY + 2, self.exp.clamp(0, PBScene::EXPGAUGESIZE), 2, PBScene::EXPCOLORBASE)
    end
    pbShowStatsBoosts if loopstop == false
  end

  def pbShowStatsBoosts
    return nil if !pbShouldShowStatsBoosts?

    pbUpdateStatsBoostsBitmap if pbShouldUpdateStatsBoostsBitmap?
    pbDrawStatsBoostsTab
  end

  def pbShouldShowStatsBoosts?
    return true if !defined?($doShowStatBoosts)

    return $doShowStatBoosts
  end

  def pbShouldUpdateStatsBoostsBitmap?
    return true if !defined?(@@statsBoostsData)
    return true if !@@statsBoostsData
    return true if !@@statsBoostsData[:battlers][@battler.index]
    return true if @@statsBoostsData[:battlers][@battler.index][:bitmap].disposed?

    for pos in 0...@@statsBoostsData[:battlers][@battler.index][:stats].length
      lastVal = @@statsBoostsData[:battlers][@battler.index][:stats][pos]
      currVal = pbGetCurrentStatStage(pos)
      return true if lastVal != currVal
    end
    return false
  end

  def pbGetCurrentStatStage(statPosition)
    mapping = pbGetStatsBoostsDisplayMap
    stat = mapping[statPosition]
    return @battler.stages[stat]
  end

  def pbGetStatsBoostsDisplayMap
    return [
      PBStats::ACCURACY,
      PBStats::ATTACK, PBStats::SPATK,
      PBStats::SPEED,
      PBStats::DEFENSE, PBStats::SPDEF,
      PBStats::EVASION
    ]
  end

  def pbGetStatsBoostsPositionCoordinatesMapping
    return [
      [14, 0],
      [2, 10], [26, 10],
      [14, 20],
      [2, 30], [26, 30],
      [14, 40]
    ]
  end

  def pbGetStatsBoostsTabCoords
    rect = @@statsBoostsData[:battlers][@battler.index][:bitmap].rect
    case @battler.index
      # Player's mon in singles
      when 0
        offset = Desolation ? 20 : 28
        return offset - rect.width, -4
      # Foe's mon in singles
      when 1
        offset = Desolation ? 22 : 10
        return @databox.width - offset, -4
      # Player's other mon in doubles
      when 2
        return 28 - rect.width, -4
      # Foe's other mon in doubles
      else
        return @databox.width - 10, -4
    end
  end

  def pbUpdateStatsBoostsBitmap
    if !defined?(@@statsBoostsData) || !@@statsBoostsData
      @@statsBoostsData = {
        'battlers': []
      }
    end
    # Get the current stages
    if @@statsBoostsData[:battlers][@battler.index]
      len = @@statsBoostsData[:battlers][@battler.index][:stats].length
    else
      @@statsBoostsData[:battlers][@battler.index] = {
        'stats': []
      }
      mapping = pbGetStatsBoostsDisplayMap
      len = mapping.length
    end
    for pos in 0...len
      @@statsBoostsData[:battlers][@battler.index][:stats][pos] = pbGetCurrentStatStage(pos)
    end
    # Get the bitmap
    @@statsBoostsData[:battlers][@battler.index][:bitmap] = pbBuildStatsBoostsBitmap
  end

  def pbBuildStatsBoostsBitmap
    pbEnsureStatsBoostsGraphicsLoaded
    bitmap = @@statsBoostsData[:background].bitmap
    result = Bitmap.new(bitmap.rect.width, bitmap.rect.height)
    result.blt(0, 0, bitmap, bitmap.rect)
    coordsMapping = pbGetStatsBoostsPositionCoordinatesMapping
    for pos in 0...@@statsBoostsData[:battlers][@battler.index][:stats].length
      val = @@statsBoostsData[:battlers][@battler.index][:stats][pos]
      stage = "#{val}"
      next if !@@statsBoostsData[:stages][stage]

      x, y = coordsMapping[pos]
      result.blt(x, y, @@statsBoostsData[:stages][stage], @@statsBoostsData[:stages][stage].rect)
    end
    return result
  end

  def pbEnsureStatsBoostsGraphicsLoaded
    if !@@statsBoostsData[:background] || @@statsBoostsData[:background].disposed?
      @@statsBoostsData[:background] = AnimatedBitmap.new('Graphics/Pictures/Battle/statdis1.png')
    end
    @@statsBoostsData[:stages] = {} if !@@statsBoostsData[:stages]
    stagesToBeLoaded = []
    for i in -6..6
      stage = "#{i}"
      next if @@statsBoostsData[:stages][stage] && !@@statsBoostsData[:stages][stage].disposed?

      stagesToBeLoaded.push(i)
    end
    return nil if stagesToBeLoaded.length <= 0

    rawBmp = AnimatedBitmap.new('Graphics/Pictures/Battle/statdis2.png')
    for i in stagesToBeLoaded
      stage = "#{i}"
      if i == 0
        @@statsBoostsData[:stages][stage] = nil
        next
      end
      rect = pbGetStatsBoostsRect(i)
      bitmap = Bitmap.new(rect.width, rect.height)
      bitmap.blt(0, 0, rawBmp.bitmap, rect)
      @@statsBoostsData[:stages][stage] = bitmap
    end
  end

  def pbGetStatsBoostsRect(stageId)
    stageWidth = 22
    stageHeight = 22
    paddingTop = 0
    if stageId > 0
      i = stageId
      x = 0
    else
      i = -stageId
      x = stageWidth
    end
    y = i * (stageHeight + paddingTop) - stageHeight
    return Rect.new(x, y, stageWidth, stageHeight)
  end

  def pbDrawStatsBoostsTab
    statsBitmap = @@statsBoostsData[:battlers][@battler.index][:bitmap]
    x, y = pbGetStatsBoostsTabCoords
    x, y = pbEnsureStatsBoostsOffsets(x, y)
    refresh(true)
    self.bitmap.blt(x, y, statsBitmap, statsBitmap.rect)
  end

  def pbEnsureStatsBoostsOffsets(x, y)
    offsetX = [-1 * x, 0].max
    offsetY = [-1 * y, 0].max
    rect = @@statsBoostsData[:battlers][@battler.index][:bitmap].rect
    # Save the old positions
    type = @doublebattle ? 'doubleBattle' : 'singleBattle'
    @@statsBoostsData[:battlers][@battler.index][:oldGeometry] = {} if !@@statsBoostsData[:battlers][@battler.index][:oldGeometry]
    @@statsBoostsData[:battlers][@battler.index][:oldGeometry][type] = {} if !@@statsBoostsData[:battlers][@battler.index][:oldGeometry][type]
    old = @@statsBoostsData[:battlers][@battler.index][:oldGeometry][type]
    old[:bitmap_width] = self.bitmap.width if !old[:bitmap_width]
    old[:bitmap_height] = self.bitmap.height if !old[:bitmap_height]
    old[:spritebaseX] = @spritebaseX if !old[:spritebaseX]
    old[:spritebaseY] = @spritebaseY if !old[:spritebaseY]
    old[:spriteX] = @spriteX if !old[:spriteX]
    old[:spriteY] = @spriteY if !old[:spriteY]
    # Extend in the positive
    rect = @@statsBoostsData[:battlers][@battler.index][:bitmap].rect
    targetX = [old[:bitmap_width] + offsetX, offsetX + x + rect.width].max
    targetY = [old[:bitmap_height] + offsetY, offsetY + y + rect.height].max
    if self.bitmap.width < targetX || self.bitmap.height < targetY
      temp = Bitmap.new(targetX, targetY)
      temp.blt(0, 0, self.bitmap, self.bitmap.rect)
      self.bitmap = temp
    end
    # Extend in the negative
    if !defined?(@statsBoostsOffsetApplied) || !@statsBoostsOffsetApplied
      if (offsetX != 0 || offsetY != 0)
        bitmap = Bitmap.new(@databox.bitmap.width + 2 * offsetX, @databox.bitmap.height + 2 * offsetY)
        bitmap.blt(offsetX, offsetY, @databox.bitmap, @databox.bitmap.rect)
        @databox.setBitmap(bitmap)

        @spritebaseX = old[:spritebaseX] + offsetX
        @spritebaseY = old[:spritebaseY] + offsetY
        @spriteX = old[:spriteX] - offsetX
        @spriteY = old[:spriteY] - offsetY
      end
      @statsBoostsOffsetApplied = true
    end

    # Fin
    return x + offsetX, y + offsetY
  end

  def update
    super
    @frame += 1
    if @animatingHP
      if @currenthp < @endhp
        @currenthp += [4, (@battler.totalhp.to_f / PBScene::HPGAUGESIZE).floor].max
        @currenthp = @endhp if @currenthp > @endhp
      elsif @currenthp > @endhp
        @currenthp -= [4, (@battler.totalhp.to_f / PBScene::HPGAUGESIZE).floor].max
        @currenthp = @endhp if @currenthp < @endhp
      end
      @animatingHP = false if @currenthp == @endhp
      refresh
    end
    if @animatingEXP
      if !@showexp
        @currentexp = @endexp
      elsif @currentexp < @endexp   # Gaining Exp
        if @endexp >= PBScene::EXPGAUGESIZE ||
           @endexp - @currentexp >= PBScene::EXPGAUGESIZE / 4
          @currentexp += 6
        else
          @currentexp += 3
        end
        @currentexp = @endexp if @currentexp > @endexp
      elsif @currentexp > @endexp   # Losing Exp
        if @endexp <= 0 ||
           @currentexp - @endexp >= PBScene::EXPGAUGESIZE / 4
          @currentexp -= 6
        elsif @currentexp > @endexp
          @currentexp -= 3
        end
        @currentexp = @endexp if @currentexp < @endexp
      end
      refresh
      if @currentexp == @endexp
        if (@currentexp == PBScene::EXPGAUGESIZE && (posExp? || noExp?)) || (@currentexp == 0 && negExp?)
          if @expflash == 0
            pbSEPlay("expfull")
            self.flash(Color.new(64, 200, 248), 8)
            @expflash = 8
          else
            @expflash -= 1
            if @expflash == 0
              @animatingEXP = false
              refreshExpLevel
            end
          end
        else
          @animatingEXP = false
        end
      end
    end
    if @appearing
      if (@battler.index & 1) == 0 # if player's Pokémon
        self.x -= 8
        @appearing = false if self.x <= @spriteX
      else
        self.x += 8
        @appearing = false if self.x >= @spriteX
      end
      self.y = @spriteY
      return
    end
    self.x = @spriteX
    self.y = @spriteY
    # Data box bobbing while Pokémon is selected
    if ((@frame / 10).floor & 1) == 1 && @selected == 1 # Choosing commands for this Pokémon
      self.y = @spriteY + 2
    elsif ((@frame / 5).floor & 1) == 1 && @selected == 2 # When targeted or damaged
      self.y = @spriteY + 2
    end
  end
end

def showShadow?(species, form)
  return $cache.pkmn[species, form].BattlerAltitude > 0 || $cache.pkmn[species, form].BattlerShadow
end

# Shows the enemy trainer(s)'s Pokémon being thrown out.  It appears at coords
# (@spritex,@spritey), and moves in y to @endspritey where it stays for the rest
# of the battle, i.e. the latter is the more important value.
# Doesn't show the ball itself being thrown.
class PokeballSendOutAnimation
  SPRITESTEPS = 10
  STARTZOOM = 0.125

  def initialize(sprite, spritehash, pkmn, doublebattle, illusionpoke)
    @disposed = false
    @ballused = pkmn.pokemon ? pkmn.pokemon.ballused : :POKEBALL
    @PokemonBattlerSprite = sprite
    @PokemonBattlerSprite.visible = false
    @PokemonBattlerSprite.tone = Tone.new(248, 248, 248, 248)
    @pokeballsprite = IconSprite.new(0, 0, sprite.viewport)
    @pokeballsprite.setBitmap(sprintf("Graphics/Pictures/Battle/%s", @ballused))
    if doublebattle && pkmn.battle.party2.length != 1
      @spritex = PBScene::FOEBATTLERD1_X if pkmn.index == 1
      @spritex = PBScene::FOEBATTLERD2_X if pkmn.index == 3
    else
      @spritex = PBScene::FOEBATTLER_X
    end
    @spritey = 0
    @illusionpoke = illusionpoke
    if illusionpoke != nil
      @endspritey = adjustBattleSpriteY(sprite, illusionpoke.species, illusionpoke.form, pkmn.index)
    else
      @endspritey = adjustBattleSpriteY(sprite, pkmn.species, pkmn.form, pkmn.index)
    end
    # if a battle tagged as doubles only has a single opposing pokemon use singles position
    if doublebattle && pkmn.battle.party2.length != 1
      @spritey = PBScene::FOEBATTLERD1_Y if pkmn.index == 1
      @spritey = PBScene::FOEBATTLERD2_Y if pkmn.index == 3
      @endspritey += PBScene::FOEBATTLERD1_Y if pkmn.index == 1
      @endspritey += PBScene::FOEBATTLERD2_Y if pkmn.index == 3
    else
      @spritey = PBScene::FOEBATTLER_Y
      @endspritey += PBScene::FOEBATTLER_Y
    end
    @spritehash = spritehash
    @pokeballsprite.x = @spritex - @pokeballsprite.bitmap.width / 2
    @pokeballsprite.y = @spritey - @pokeballsprite.bitmap.height / 2 - 4
    @pokeballsprite.z = @PokemonBattlerSprite.z + 1
    @pkmn = pkmn
    @shadowX = @spritex
    @shadowY = @spritey
    if @spritehash["shadow#{@pkmn.index}"] && @spritehash["shadow#{@pkmn.index}"].bitmap != nil
      @shadowX -= @spritehash["shadow#{@pkmn.index}"].bitmap.width / 2
      @shadowY -= @spritehash["shadow#{@pkmn.index}"].bitmap.height / 2
    end
    if illusionpoke != nil # ILLUSION
      @shadowVisible = showShadow?(illusionpoke.species, illusionpoke.form)
    else
      @shadowVisible = showShadow?(pkmn.species, pkmn.form)
    end # ILLUSION
    @stepspritey = (@spritey - @endspritey)
    @zoomstep = (1.0 - STARTZOOM) / SPRITESTEPS
    @animdone = false
    @frame = 0
  end

  def disposed?
    return @disposed
  end

  def animdone?
    return @animdone
  end

  def dispose
    return if disposed?

    @pokeballsprite.dispose
    @disposed = true
  end

  def update
    return if disposed?

    @pokeballsprite.update
    @frame += 1
    if @frame == 2
      pbSEPlay("recall")
    end
    if @frame == 4
      @PokemonBattlerSprite.visible = true
      @PokemonBattlerSprite.zoom_x = STARTZOOM
      @PokemonBattlerSprite.zoom_y = STARTZOOM
      pbSpriteSetCenter(@PokemonBattlerSprite, @spritex, @spritey)
      if @illusionpoke != nil
        pbPlayCry(@illusionpoke.pokemon)
      else
        pbPlayCry(@pkmn.pokemon ? @pkmn.pokemon : @pkmn.species)
      end
      @pokeballsprite.setBitmap(sprintf("Graphics/Pictures/Battle/%s_open", @ballused))
    end
    if @frame == 8
      @pokeballsprite.visible = false
    end
    if @frame > 8 && @frame <= 16
      color = Color.new(248, 248, 248, 256 - (16 - @frame) * 32)
      @spritehash["enemybase"].color = color if $Settings.photosensitive != 1
      @spritehash["playerbase"].color = color if $Settings.photosensitive != 1
      @spritehash["battlebg"].color = color if $Settings.photosensitive != 1
      for i in 0...4
        @spritehash["shadow#{i}"].color = color if @spritehash["shadow#{i}"]
      end
    end
    if @frame > 16 && @frame <= 24
      color = Color.new(248, 248, 248, (24 - @frame) * 32)
      tone = (24 - @frame) * 32
      @PokemonBattlerSprite.tone = Tone.new(tone, tone, tone, tone)
      @spritehash["enemybase"].color = color if $Settings.photosensitive != 1
      @spritehash["playerbase"].color = color if $Settings.photosensitive != 1
      @spritehash["battlebg"].color = color if $Settings.photosensitive != 1
      for i in 0...4
        @spritehash["shadow#{i}"].color = color if @spritehash["shadow#{i}"]
      end
    end
    if @frame > 5 && @PokemonBattlerSprite.zoom_x < 1.0
      @PokemonBattlerSprite.zoom_x += @zoomstep
      @PokemonBattlerSprite.zoom_y += @zoomstep
      @PokemonBattlerSprite.zoom_x = 1.0 if @PokemonBattlerSprite.zoom_x > 1.0
      @PokemonBattlerSprite.zoom_y = 1.0 if @PokemonBattlerSprite.zoom_y > 1.0
      currentY = @spritey - (@stepspritey * @PokemonBattlerSprite.zoom_y)
      pbSpriteSetCenter(@PokemonBattlerSprite, @spritex, currentY)
      @PokemonBattlerSprite.y = currentY
    end
    if @PokemonBattlerSprite.tone.gray <= 0 && @PokemonBattlerSprite.zoom_x >= 1.0
      @animdone = true
      if @spritehash["shadow#{@pkmn.index}"]
        @spritehash["shadow#{@pkmn.index}"].x = @shadowX
        @spritehash["shadow#{@pkmn.index}"].y = @shadowY
        @spritehash["shadow#{@pkmn.index}"].visible = @shadowVisible
      end
    end
  end
end

# Shows the player's (or partner's) Pokémon being thrown out.  It appears at
# (@spritex,@spritey), and moves in y to @endspritey where it stays for the rest
# of the battle, i.e. the latter is the more important value.
# Doesn't show the ball itself being thrown.
class PokeballPlayerSendOutAnimation
  #  Ball curve: 8,52; 22,44; 52, 96
  #  Player: Color.new(16*8,23*8,30*8)
  SPRITESTEPS = 10
  STARTZOOM = 0.125

  def initialize(sprite, spritehash, pkmn, doublebattle, illusionpoke, battle)
    @disposed = false
    @PokemonBattlerSprite = sprite
    @pkmn = pkmn
    @PokemonBattlerSprite.visible = false
    @PokemonBattlerSprite.tone = Tone.new(248, 248, 248, 248)
    @spritehash = spritehash
    playerpos = battle.sosbattle == 3 ? [PBScene::PLAYERBATTLER_X, PBScene::PLAYERBATTLER_Y] : [PBScene::PLAYERBATTLERD1_X, PBScene::PLAYERBATTLERD1_Y]
    if doublebattle
      @spritex = playerpos[0] if pkmn.index == 0
      @spritex = PBScene::PLAYERBATTLERD2_X if pkmn.index == 2
    else
      @spritex = PBScene::PLAYERBATTLER_X
    end
    @spritey = 0
    @illusionpoke = illusionpoke
    if illusionpoke != nil
      @endspritey = adjustBattleSpriteY(sprite, illusionpoke.species, illusionpoke.form, pkmn.index)
    else
      @endspritey = adjustBattleSpriteY(sprite, pkmn.species, pkmn.form, pkmn.index)
    end
    if doublebattle
      @spritey += playerpos[1] if pkmn.index == 0
      @spritey += PBScene::PLAYERBATTLERD2_Y if pkmn.index == 2
      @endspritey += playerpos[1] if pkmn.index == 0
      @endspritey += PBScene::PLAYERBATTLERD2_Y if pkmn.index == 2
    else
      @spritey += PBScene::PLAYERBATTLER_Y
      @endspritey += PBScene::PLAYERBATTLER_Y
    end
    @animdone = false
    @frame = 0
  end

  def disposed?
    return @disposed
  end

  def animdone?
    return @animdone
  end

  def dispose
    return if disposed?

    @disposed = true
  end

  def update
    return if disposed?

    @frame += 1
    if @frame == 4
      @PokemonBattlerSprite.visible = true
      @PokemonBattlerSprite.zoom_x = STARTZOOM
      @PokemonBattlerSprite.zoom_y = STARTZOOM
      pbSEPlay("recall")
      pbSpriteSetCenter(@PokemonBattlerSprite, @spritex, @spritey)
      if @illusionpoke != nil
        pbPlayCry(@illusionpoke.pokemon)
      else
        pbPlayCry(@pkmn.pokemon ? @pkmn.pokemon : @pkmn.species)
      end
    end
    if @frame > 8 && @frame <= 16
      color = Color.new(248, 248, 248, 256 - (16 - @frame) * 32)
      @spritehash["enemybase"].color = color if $Settings.photosensitive != 1
      @spritehash["playerbase"].color = color if $Settings.photosensitive != 1
      @spritehash["battlebg"].color = color if $Settings.photosensitive != 1
      for i in 0...4
        @spritehash["shadow#{i}"].color = color if @spritehash["shadow#{i}"]
      end
    end
    if @frame > 16 && @frame <= 24
      color = Color.new(248, 248, 248, (24 - @frame) * 32)
      tone = (24 - @frame) * 32
      @PokemonBattlerSprite.tone = Tone.new(tone, tone, tone, tone)
      @spritehash["enemybase"].color = color if $Settings.photosensitive != 1
      @spritehash["playerbase"].color = color if $Settings.photosensitive != 1
      @spritehash["battlebg"].color = color if $Settings.photosensitive != 1
      for i in 0...4
        @spritehash["shadow#{i}"].color = color if @spritehash["shadow#{i}"]
      end
    end
    if @frame > 5 && @PokemonBattlerSprite.zoom_x < 1.0
      @PokemonBattlerSprite.zoom_x += 0.1
      @PokemonBattlerSprite.zoom_y += 0.1
      @PokemonBattlerSprite.zoom_x = 1.0 if @PokemonBattlerSprite.zoom_x > 1.0
      @PokemonBattlerSprite.zoom_y = 1.0 if @PokemonBattlerSprite.zoom_y > 1.0
      pbSpriteSetCenter(@PokemonBattlerSprite, @spritex, 0)
      @PokemonBattlerSprite.y = @spritey + (@endspritey - @spritey) * @PokemonBattlerSprite.zoom_y
    end
    if @PokemonBattlerSprite.tone.gray <= 0 && @PokemonBattlerSprite.zoom_x >= 1.0
      @animdone = true
    end
  end
end

# Slide the pokemon in from the side because it is already out of the ball.
class FollowerPlayerSendOutAnimation
  def initialize(sprite, spritehash, pkmn, doublebattle, illusionpoke, battle)
    @disposed = false
    @PokemonBattlerSprite = sprite
    @pkmn = pkmn
    @PokemonBattlerSprite.visible = false
    @PokemonBattlerSprite.tone = Tone.new(248, 248, 248, 248)
    @spritehash = spritehash
    if doublebattle
      @spritex = PBScene::PLAYERBATTLERD1_X if pkmn.index == 0
      @spritex = PBScene::PLAYERBATTLERD2_X if pkmn.index == 2
    else
      @spritex = PBScene::PLAYERBATTLER_X
    end
    @spritey = 0
    @illusionpoke = illusionpoke
    if illusionpoke != nil
      @endspritey = adjustBattleSpriteY(sprite, illusionpoke.species, illusionpoke.form, pkmn.index)
    else
      @endspritey = adjustBattleSpriteY(sprite, pkmn.species, pkmn.form, pkmn.index)
    end
    if doublebattle
      @spritey += PBScene::PLAYERBATTLERD1_Y if pkmn.index == 0
      @spritey += PBScene::PLAYERBATTLERD2_Y if pkmn.index == 2
      @endspritey += PBScene::PLAYERBATTLERD1_Y if pkmn.index == 0
      @endspritey += PBScene::PLAYERBATTLERD2_Y if pkmn.index == 2
    else
      @spritey += PBScene::PLAYERBATTLER_Y
      @endspritey += PBScene::PLAYERBATTLER_Y
    end
    @animdone = false
    @frame = 0
    @spritex -= 240
  end

  def disposed?
    return @disposed
  end

  def animdone?
    return @animdone
  end

  def dispose
    return if disposed?

    @disposed = true
  end

  def update
    return if disposed?

    @frame += 1
    if @frame == 4
      @PokemonBattlerSprite.visible = true
      pbSEPlay("recall")
      pbSpriteSetCenter(@PokemonBattlerSprite, @spritex, @spritey)
      if @illusionpoke != nil
        pbPlayCry(@illusionpoke)
      else
        pbPlayCry(@pkmn.pokemon ? @pkmn.pokemon : @pkmn.species)
      end
      @PokemonBattlerSprite.tone = Tone.new(0, 0, 0, 0)
      @PokemonBattlerSprite.y = @endspritey
      color = Color.new(248, 248, 248, 0)
      for i in 0...4
        @spritehash["shadow#{i}"].color = color if @spritehash["shadow#{i}"]
      end
    end
    if @frame > 5 && @frame <= 36
      @PokemonBattlerSprite.x += 8
    end
    if @frame >= 36
      @animdone = true
    end
  end
end

# Shows the enemy trainer(s) and the enemy party lineup sliding off screen.
# Doesn't show the ball thrown or the Pokémon.
class TrainerFadeAnimation
  def initialize(sprites)
    @frame = 0
    @sprites = sprites
    @animdone = false
  end

  def animdone?
    return @animdone
  end

  def update
    return if @animdone

    @frame += 1
    @sprites["trainer"].x += 8
    @sprites["trainer2"].x += 8 if @sprites["trainer2"]
    @sprites["partybarfoe"].x += 8
    @sprites["partybarfoe"].opacity -= 12
    if @sprites["partybarfoepartner"]
      @sprites["partybarfoepartner"].x += 8
      @sprites["partybarfoepartner"].opacity -= 12
    end
    for i in 0...6
      @sprites["enemy#{i}"].opacity -= 12
      @sprites["enemy#{i}"].x += 8 if @frame >= i * 4
      if @sprites["enemypartner#{i}"]
        @sprites["enemypartner#{i}"].opacity -= 12
        @sprites["enemypartner#{i}"].x += 8 if @frame >= i * 4
      end
    end
    @animdone = true if @sprites["trainer"].x >= Graphics.width && (!@sprites["trainer2"] || @sprites["trainer2"].x >= Graphics.width)
  end
end

# Shows the player (and partner) and the player party lineup sliding off screen.
# Shows the player's/partner's throwing animation (if they have one).
# Doesn't show the ball thrown or the Pokémon.
class PlayerFadeAnimation
  def initialize(sprites, playerthrow = true)
    @frame = 0
    @sprites = sprites
    @animdone = false
    @playerthrow = playerthrow
  end

  def animdone?
    return @animdone
  end

  def update
    return if @animdone

    @frame += 1
    @sprites["player"].x -= 8
    @sprites["playerB"].x -= 8 if @sprites["playerB"]
    @sprites["partybarplayer"].x -= 8
    @sprites["partybarplayer"].opacity -= 12
    if @sprites["partybarpartner"]
      @sprites["partybarpartner"].x -= 8
      @sprites["partybarpartner"].opacity -= 12
    end
    for i in 0...6
      if @sprites["player#{i}"]
        @sprites["player#{i}"].opacity -= 12
        @sprites["player#{i}"].x -= 8 if @frame >= i * 4
      end
      if @sprites["partner#{i}"]
        @sprites["partner#{i}"].opacity -= 12
        @sprites["partner#{i}"].x -= 8 if @frame >= i * 4
      end
    end
    pa = @sprites["player"]
    pb = @sprites["playerB"]
    pawidth = 128
    pbwidth = 128
    if pa && pa.bitmap && !pa.bitmap.disposed?
      if pa.bitmap.height < pa.bitmap.width
        numframes = pa.bitmap.width / pa.bitmap.height # Number of frames
        pawidth = pa.bitmap.width / numframes # Width per frame
        if @playerthrow
          @sprites["player"].src_rect.x = pawidth * 1 if @frame > 0
          @sprites["player"].src_rect.x = pawidth * 2 if @frame > 8
          @sprites["player"].src_rect.x = pawidth * 3 if @frame > 12
          @sprites["player"].src_rect.x = pawidth * 4 if @frame > 16
        end
        @sprites["player"].src_rect.width = pawidth
      else
        pawidth = pa.bitmap.width
        @sprites["player"].src_rect.x = 0
        @sprites["player"].src_rect.width = pawidth
      end
    end
    if pb && pb.bitmap && !pb.bitmap.disposed?
      if pb.bitmap.height < pb.bitmap.width
        numframes = pb.bitmap.width / pb.bitmap.height # Number of frames
        pbwidth = pb.bitmap.width / numframes # Width per frame
        @sprites["playerB"].src_rect.x = pbwidth * 1 if @frame > 0
        @sprites["playerB"].src_rect.x = pbwidth * 2 if @frame > 8
        @sprites["playerB"].src_rect.x = pbwidth * 3 if @frame > 12
        @sprites["playerB"].src_rect.x = pbwidth * 4 if @frame > 16
        @sprites["playerB"].src_rect.width = pbwidth
      else
        pbwidth = pb.bitmap.width
        @sprites["playerB"].src_rect.x = 0
        @sprites["playerB"].src_rect.width = pbwidth
      end
    end
    if pb
      @animdone = true if pb.x <= -pbwidth
    else
      @animdone = true if pa.x <= -pawidth
    end
  end
end

# Shows the player's Poké Ball being thrown to capture a Pokémon.
def pokeballThrow(ball, shakes, critical, critsuccess, targetBattler, scene, battler, burst = -1, showplayer = false)
  animtrainer = false
  if showplayer && @sprites["player"].bitmap.width > @sprites["player"].bitmap.height
    animtrainer = true
  end
  oldvisible = @sprites["shadow#{targetBattler}"].visible
  @sprites["shadow#{targetBattler}"].visible = false
  ballopen = sprintf("Graphics/Pictures/Battle/%s_open", ball.to_s)
  ball = sprintf("Graphics/Pictures/Battle/%s", ball.to_s)
  # sprites
  spritePoke = @sprites["pokemon#{targetBattler}"]
  spriteBall = IconSprite.new(0, 0, @viewport)
  spriteBall.visible = false
  spritePlayer = @sprites["player"] if animtrainer
  # pictures
  pictureBall = PictureEx.new(spritePoke.z + 1)
  picturePoke = PictureEx.new(spritePoke.z)
  dims = [spritePoke.x, spritePoke.y]
  center = getSpriteCenter(@sprites["pokemon#{targetBattler}"])
  if @battle.doublebattle
    ballendy = PBScene::FOEBATTLERD1_Y - 4 if targetBattler == 1
    ballendy = PBScene::FOEBATTLERD2_Y - 4 if targetBattler == 3
  else
    ballendy = PBScene::FOEBATTLER_Y - 4
  end
  if animtrainer
    picturePlayer = PictureEx.new(spritePoke.z + 2)
    playerpos = [@sprites["player"].x, @sprites["player"].y]
  end
  # starting positions
  pictureBall.moveVisible(1, true)
  pictureBall.moveName(1, ball)
  pictureBall.moveOrigin(1, PictureOrigin::Center)
  if animtrainer
    pictureBall.moveXY(0, 1, 64, 256)
  else
    pictureBall.moveXY(0, 1, 10, 180)
  end
  picturePoke.moveVisible(1, true)
  picturePoke.moveOrigin(1, PictureOrigin::Center)
  picturePoke.moveXY(0, 1, center[0], center[1])
  if animtrainer
    picturePlayer.moveVisible(1, true)
    picturePlayer.moveName(1, spritePlayer.name)
    picturePlayer.moveOrigin(1, PictureOrigin::TopLeft)
    picturePlayer.moveXY(0, 1, playerpos[0], playerpos[1])
  end
  # directives
  picturePoke.moveSE(1, "Audio/SE/throw")
  if animtrainer
    pictureBall.moveCurve(30, 1, 64, 256, 30 + Graphics.width / 2, 10, center[0], center[1])
    pictureBall.moveAngle(30, 1, -720)
  else
    pictureBall.moveCurve(30, 1, 150, 70, 30 + Graphics.width / 2, 10, center[0], center[1])
    pictureBall.moveAngle(30, 1, -1080)
  end
  pictureBall.moveAngle(0, pictureBall.totalDuration, 0)
  delay = pictureBall.totalDuration + 4
  picturePoke.moveTone(10, delay, Tone.new(0, -224, -224, 0))
  delay = picturePoke.totalDuration
  picturePoke.moveSE(delay, "Audio/SE/recall")
  pictureBall.moveName(delay + 4, ballopen)
  if animtrainer
    picturePlayer.moveSrc(1, @sprites["player"].bitmap.height, 0)
    picturePlayer.moveXY(0, 1, playerpos[0] - 14, playerpos[1])
    picturePlayer.moveSrc(4, @sprites["player"].bitmap.height * 2, 0)
    picturePlayer.moveXY(0, 4, playerpos[0] - 12, playerpos[1])
    picturePlayer.moveSrc(8, @sprites["player"].bitmap.height * 3, 0)
    picturePlayer.moveXY(0, 8, playerpos[0] + 20, playerpos[1])
    picturePlayer.moveSrc(16, @sprites["player"].bitmap.height * 4, 0)
    picturePlayer.moveXY(0, 16, playerpos[0] + 16, playerpos[1])
    picturePlayer.moveSrc(40, 0, 0)
    picturePlayer.moveXY(0, 40, playerpos[0], playerpos[1])
  end
  loop do
    pictureBall.update
    picturePoke.update
    picturePlayer.update if animtrainer
    setPictureIconSprite(spriteBall, pictureBall)
    setPictureSprite(spritePoke, picturePoke)
    setPictureIconSprite(spritePlayer, picturePlayer) if animtrainer
    pbGraphicsUpdate
    Input.update
    break if !pictureBall.running? && !picturePoke.running?
  end
  # Burst animation here
  if burst >= 0 && scene.battle.battlescene
    scene.pbCommonAnimation("BallBurst#{burst}", battler, nil)
  end
  pictureBall.clearProcesses
  picturePoke.clearProcesses
  delay = 0
  picturePoke.moveZoom(15, delay, 0)
  picturePoke.moveXY(15, delay, center[0], center[1])
  picturePoke.moveSE(delay + 10, "Audio/SE/jumptoball")
  picturePoke.moveVisible(delay + 15, false)
  pictureBall.moveName(picturePoke.totalDuration + 2, ball)
  delay = picturePoke.totalDuration + 6
  if critical
    pictureBall.moveSE(delay, "Audio/SE/ballshake")
    pictureBall.moveXY(2, delay, center[0] + 4, center[1])
    pictureBall.moveXY(4, pictureBall.totalDuration, center[0] - 4, center[1])
    pictureBall.moveSE(pictureBall.totalDuration, "Audio/SE/ballshake")
    pictureBall.moveXY(4, pictureBall.totalDuration, center[0] + 4, center[1])
    pictureBall.moveXY(4, pictureBall.totalDuration, center[0] - 4, center[1])
    pictureBall.moveXY(2, pictureBall.totalDuration, center[0], center[1])
    delay = pictureBall.totalDuration + 4
  end
  pictureBall.moveXY(10, delay, center[0], ballendy)
  pictureBall.moveSE(pictureBall.totalDuration, "Audio/SE/balldrop")
  pictureBall.moveXY(5, pictureBall.totalDuration + 2, center[0], ballendy - ((ballendy - center[1]) / 2))
  pictureBall.moveXY(5, pictureBall.totalDuration + 2, center[0], ballendy)
  pictureBall.moveSE(pictureBall.totalDuration, "Audio/SE/balldrop")
  pictureBall.moveXY(3, pictureBall.totalDuration + 2, center[0], ballendy - ((ballendy - center[1]) / 4))
  pictureBall.moveXY(3, pictureBall.totalDuration + 2, center[0], ballendy)
  pictureBall.moveSE(pictureBall.totalDuration, "Audio/SE/balldrop")
  pictureBall.moveXY(1, pictureBall.totalDuration + 2, center[0], ballendy - ((ballendy - center[1]) / 8))
  pictureBall.moveXY(1, pictureBall.totalDuration + 2, center[0], ballendy)
  pictureBall.moveSE(pictureBall.totalDuration, "Audio/SE/balldrop")
  picturePoke.moveXY(0, pictureBall.totalDuration, center[0], ballendy)
  delay = pictureBall.totalDuration + 18 # if shakes==0
  [shakes, 3].min.times do
    pictureBall.moveSE(delay, "Audio/SE/ballshake")
    pictureBall.moveXY(3, delay, center[0] - 8, ballendy)
    pictureBall.moveAngle(3, delay, 20) # positive means counterclockwise
    delay = pictureBall.totalDuration
    pictureBall.moveXY(6, delay, center[0] + 8, ballendy)
    pictureBall.moveAngle(6, delay, -20) # negative means clockwise
    delay = pictureBall.totalDuration
    pictureBall.moveXY(3, delay, center[0], ballendy)
    pictureBall.moveAngle(3, delay, 0)
    delay = pictureBall.totalDuration + 18
  end
  if shakes < 4 && !critsuccess
    picturePoke.moveSE(delay, "Audio/SE/recall")
    pictureBall.moveName(delay, ballopen)
    pictureBall.moveVisible(delay + 10, false)
    picturePoke.moveVisible(delay, true)
    picturePoke.moveZoom(15, delay, 100)
    picturePoke.moveXY(15, delay, center[0], center[1])
    picturePoke.moveTone(0, delay, Tone.new(248, 248, 248, 248))
    picturePoke.moveTone(24, delay, Tone.new(0, 0, 0, 0))
    delay = picturePoke.totalDuration
  end
  pictureBall.moveXY(0, delay, center[0], ballendy)
  picturePoke.moveOrigin(picturePoke.totalDuration, PictureOrigin::TopLeft)
  picturePoke.moveXY(0, picturePoke.totalDuration, dims[0], dims[1])
  loop do
    pictureBall.update
    picturePoke.update
    setPictureIconSprite(spriteBall, pictureBall)
    setPictureSprite(spritePoke, picturePoke)
    pbGraphicsUpdate
    Input.update
    break if !pictureBall.running? && !picturePoke.running?
  end
  if shakes < 4 && !critsuccess
    @sprites["shadow#{targetBattler}"].visible = oldvisible
    spriteBall.dispose
  else
    spriteBall.tone = Tone.new(-64, -64, -64, 128)
    pbSEPlay("catchclick", 100)
    @sprites["capture"] = spriteBall
    spritePoke.visible = false
  end
end



####################################################

class PokeBattle_Scene
  attr_reader :viewport
  attr_reader :sprites

  BLANK      = 0
  MESSAGEBOX = 1
  COMMANDBOX = 2
  FIGHTBOX   = 3

  def initialize
    @battle = nil
    @lastcmd = [0, 0, 0, 0]
    @lastmove = [0, 0, 0, 0]
    @pkmnwindows = [nil, nil, nil, nil]
    @sprites = {}
    @battlestart = true
    @messagemode = false
    @aborted = false
  end

  def pbUpdate
    partyAnimationUpdate
    @sprites["battlebg"].update if @sprites["battlebg"].respond_to?("update")
    @sprites["battlebg2"].update if @sprites["battlebg2"] != nil && @sprites["battlebg2"].respond_to?("update")
  end

  def pbGraphicsUpdate(shift = false, oppside = true, playerside = true)
    partyAnimationUpdate(shift, oppside, playerside)
    @sprites["battlebg"].update if @sprites["battlebg"] != nil && @sprites["battlebg"].respond_to?("update")
    @sprites["battlebg2"].update if @sprites["battlebg2"] != nil && @sprites["battlebg2"].respond_to?("update")
    @sprites["enemybase"].update if @sprites["enemybase"] != nil && @sprites["enemybase"].respond_to?("update")
    @sprites["playerbase"].update if @sprites["playerbase"] != nil && @sprites["playerbase"].respond_to?("update")
    Graphics.update
  end

  def pbApplyBGSprite(sprite, filename)
    @sprites[sprite].setBitmap(filename)
  end

  def pbShowWindow(windowtype)
    @sprites["messagebox"].visible = (windowtype == MESSAGEBOX || windowtype == COMMANDBOX || windowtype == FIGHTBOX || windowtype == BLANK)
    @sprites["messagewindow"].visible = (windowtype == MESSAGEBOX)
    @sprites["commandwindow"].visible = (windowtype == COMMANDBOX)
    @sprites["fightwindow"].visible = (windowtype == FIGHTBOX)
  end

  def pbSetMessageMode(mode)
    @messagemode = mode
    msgwindow = @sprites["messagewindow"]
    if mode # Within Pokémon command
      msgwindow.baseColor = PBScene::MENUBASE
      msgwindow.shadowColor = PBScene::MENUSHADOW
      msgwindow.opacity = 255
      msgwindow.setHW_XYZ(96, Graphics.width - 32, 16, Graphics.height - 94)
    else
      msgwindow.baseColor = PBScene::MESSAGEBASE
      msgwindow.shadowColor = PBScene::MESSAGESHADOW
      msgwindow.opacity = 0
      msgwindow.setHW_XYZ(96, Graphics.width - 32, 16, Graphics.height - 94)
    end
  end

  def pbWaitMessage
    if @briefmessage
      pbShowWindow(MESSAGEBOX)
      cw = @sprites["messagewindow"]
      40.times do
        pbGraphicsUpdate
        Input.update
      end
      cw.text = ""
      cw.visible = false
      @briefmessage = false
    end
  end

  def pbDisplay(msg, brief = false)
    pbDisplayMessage(msg, brief)
  end

  def pbDisplayMessage(msg, brief = false)
    # Display old message
    pbWaitMessage
    pbRefresh
    pbShowWindow(MESSAGEBOX)

    # Set new message
    tts(msg)
    cw = @sprites["messagewindow"]
    cw.text = msg
    i = 0
    loop do
      pbGraphicsUpdate
      Input.update
      cw.update
      if i == 40
        cw.text = ""
        cw.visible = false
        return
      end
      if Input.trigger?(Input::C)
        if cw.pausing?
          pbPlayDecisionSE()
          cw.resume
        end
      end
      if !cw.busy?
        if brief
          @briefmessage = true
          20.times do
            pbGraphicsUpdate
            Input.update
          end
          return
        end
        i += 1
      end
    end
  end

  def pbDisplayPausedMessage(msg)
    pbWaitMessage
    pbRefresh
    pbShowWindow(MESSAGEBOX)
    tts(msg)
    if @messagemode
      @switchscreen.pbDisplay(msg)
      return
    end
    cw = @sprites["messagewindow"]
    cw.text = _ISPRINTF("{1:s}\1", msg)
    loop do
      pbGraphicsUpdate
      Input.update
      if Input.trigger?(Input::C)
        if cw.busy?
          pbPlayDecisionSE() if cw.pausing?
          cw.resume
        elsif !inPartyAnimation?
          cw.text = ""
          pbPlayDecisionSE()
          cw.visible = false if @messagemode
          return
        end
      end
      cw.update
    end
  end

  def pbDisplayConfirmMessage(msg)
    return pbShowCommands(msg, [_INTL("Yes"), _INTL("No")], 1) == 0
  end

  def pbShowCommands(msg, commands, defaultValue)
    pbWaitMessage
    pbRefresh
    tts(msg)
    pbShowWindow(MESSAGEBOX)
    dw = @sprites["messagewindow"]
    dw.text = msg
    cw = Window_CommandPokemon.new(commands, tts: false)
    cw.x = Graphics.width - cw.width
    cw.y = Graphics.height - cw.height - dw.height
    cw.index = 0
    cw.viewport = @viewport
    pbRefresh
    update_menu = true
    lastread = nil
    loop do
      cw.visible = !dw.busy?
      pbGraphicsUpdate
      Input.update
      pbFrameUpdate(cw, update_menu)
      update_menu = false
      dw.update
      tts(commands[cw.index]) if commands[cw.index] != lastread
      lastread = commands[cw.index]
      if Input.trigger?(Input::B) && defaultValue >= 0
        update_menu = true
        if dw.busy?
          pbPlayDecisionSE() if dw.pausing?
          dw.resume
        else
          cw.dispose
          dw.text = ""
          return defaultValue
        end
      end
      if Input.trigger?(Input::C)
        update_menu = true
        if dw.busy?
          pbPlayDecisionSE() if dw.pausing?
          dw.resume
        else
          cw.dispose
          dw.text = ""
          return cw.index
        end
      end
      if Input.trigger?(Input::DOWN)
        update_menu = true
        cw.index = (cw.index + 1) % commands.length
      end
      if Input.trigger?(Input::UP)
        update_menu = true
        cw.index = (cw.index - 1) % commands.length
      end
    end
  end

  def pbFrameUpdate(cw, update_cw = true)
    cw.update if cw && update_cw
    for i in 0...4
      if @sprites["battlebox#{i}"]
        @sprites["battlebox#{i}"].update
      end
      if @sprites["pokemon#{i}"]
        @sprites["pokemon#{i}"].update
      end
    end
  end

  def pbRefresh
    for i in 0...4
      if @sprites["battlebox#{i}"]
        @sprites["battlebox#{i}"].refresh
      end
    end
  end

  def pbAddSprite(id, x, y, filename, viewport)
    sprite = IconSprite.new(x, y, viewport)
    if filename
      sprite.setBitmap(filename) rescue nil
    end
    @sprites[id] = sprite
    return sprite
  end

  def pbAddPlane(id, filename, viewport)
    sprite = AnimatedPlane.new(viewport)
    if filename
      sprite.setBitmap(filename)
    end
    @sprites[id] = sprite
    return sprite
  end

  def pbDisposeSprites
    pbDisposeSpriteHash(@sprites)
  end

  def pbBeginCommandPhase
    # Called whenever a new round begins.
    @battlestart = false
  end

  def pbShowOpponent(index)
    if @battle.opponent
      if @battle.opponent.is_a?(Array)
        trainerfile = pbTrainerSpriteFile(@battle.opponent[index].trainertype, @battle.opponent[index].outfit)
      else
        trainerfile = pbTrainerSpriteFile(@battle.opponent.trainertype, @battle.opponent.outfit)
      end
    else
      trainerfile = "Graphics/Characters/trfront"
    end
    pbAddSprite("trainer", Graphics.width, PBScene::FOETRAINER_Y, trainerfile, @viewport)
    if @sprites["trainer"].bitmap
      @sprites["trainer"].y -= @sprites["trainer"].bitmap.height
      @sprites["trainer"].z = 8
    end
    20.times do
      pbGraphicsUpdate
      Input.update
      @sprites["trainer"].x -= 6
    end
  end

  def pbHideOpponent
    20.times do
      pbGraphicsUpdate
      Input.update
      @sprites["trainer"].x += 6
    end
  end

  def pbShowHelp(text)
    @sprites["helpwindow"].resizeToFit(text, Graphics.width)
    @sprites["helpwindow"].y = 0
    @sprites["helpwindow"].x = 0
    @sprites["helpwindow"].text = text
    @sprites["helpwindow"].visible = true
  end

  def pbHideHelp
    @sprites["helpwindow"].visible = false
  end

  def pbBackdrop
    backdrop = @battle.field.backdrop
    # Choose bases
    environ = @battle.environment
    base = ""
    if environ == :Grass || environ == :TallGrass
      base = "Grass"
    elsif environ == :Sand
      base = "Sand"
    elsif $PokemonGlobal.surfing
      base = "WaterSurface"
      # elsif $PokemonGlobal.lavasurfing
    end
    base = "" if !pbResolveBitmap(sprintf("Graphics/Battlebacks/playerbase" + backdrop + base))
    # Choose time of day
    time = ""
    timenow = pbGetTimeNow
    if PBDayNight.isNight?(timenow)
      time = "Night"
    elsif PBDayNight.isEvening?(timenow)
      time = "Eve"
    end
    time = "" if !pbResolveBitmap(sprintf("Graphics/Battlebacks/battlebg" + backdrop + time))
    battlebg = "Graphics/Battlebacks/battlebg" + backdrop + time
    enemybase = "Graphics/Battlebacks/enemybase" + backdrop + base + time
    playerbase = "Graphics/Battlebacks/playerbase" + backdrop + base + time
    enemybase = "Graphics/Battlebacks/enemybaseDummy" if !pbResolveBitmap(sprintf(enemybase))
    playerbase = "Graphics/Battlebacks/playerbaseDummy" if !pbResolveBitmap(sprintf(playerbase))
    pbAddPlane("battlebg", battlebg, @viewport)
    pbAddSprite("playerbase", PBScene::PLAYERBASEX, PBScene::PLAYERBASEY, playerbase, @viewport)
    @sprites["playerbase"].x -= @sprites["playerbase"].bitmap.width / 2 if @sprites["playerbase"].bitmap != nil
    @sprites["playerbase"].y -= @sprites["playerbase"].bitmap.height if @sprites["playerbase"].bitmap != nil
    pbAddSprite("enemybase", PBScene::FOEBASEX, PBScene::FOEBASEY, enemybase, @viewport)
    @sprites["enemybase"].x -= @sprites["enemybase"].bitmap.width / 2 if @sprites["enemybase"].bitmap != nil
    @sprites["enemybase"].y -= @sprites["enemybase"].bitmap.height / 2 if @sprites["enemybase"].bitmap != nil
    @sprites["battlebg"].z = 0
    @sprites["playerbase"].z = 2
    @sprites["enemybase"].z = 1
  end

  # Returns whether the party line-ups are currently appearing on-screen
  def inPartyAnimation?
    return @enablePartyAnim && @partyAnimPhase < 3
  end

  def partyBetweenKO1(oppside = true)
    if oppside
      pbAddSprite("partybarfoe", foePartyBarX, foePartyBarY, "Graphics/Pictures/Battle/battleLineup", @viewport)
    end
    pbAddSprite("partybarplayer", playerPartyBarX, playerPartyBarY, "Graphics/Pictures/Battle/battleLineup", @viewport)
    @sprites["partybarfoe"].x -= @sprites["partybarfoe"].bitmap.width unless !oppside
    @sprites["partybarplayer"].mirror = true
    @sprites["partybarfoe"].z = 40 unless !oppside
    @sprites["partybarplayer"].z = 40
    @sprites["partybarfoe"].visible = false unless !oppside
    @sprites["partybarplayer"].visible = false
    ballmovedist = 16 # How far a ball moves each frame
    # Bar slides on
    @sprites["partybarfoe"].x += ballmovedist unless !oppside
    @sprites["partybarplayer"].x -= ballmovedist
    if oppside && @sprites["partybarfoe"].x + @sprites["partybarfoe"].bitmap.width >= foePartyBarX
      @sprites["partybarfoe"].x = foePartyBarX - @sprites["partybarfoe"].bitmap.width
      @sprites["partybarplayer"].x = playerPartyBarX
    end
    @enablePartyAnim = true
    @partyAnimPhase = 1
    loop do
      pbGraphicsUpdate(true, oppside, !oppside)
      break if @partyAnimPhase == 3
    end
    return
  end

  def partyBetweenKO2(oppside = true)
    if @sprites["partybarfoe"]
      @sprites["partybarfoe"].x -= foePartyBarX unless !oppside
    end
    if @sprites["partybarplayer"]
      @sprites["partybarplayer"].x += Graphics.width - playerPartyBarX
    end
    for i in 0...6
      pbDisposeSprite(@sprites, "enemy#{i}") unless !oppside
      pbDisposeSprite(@sprites, "player#{i}")
    end
  end

  # Shows the party line-ups appearing on-screen
  def partyAnimationUpdate(shift = false, oppside = true, playerside = true)
    return if !inPartyAnimation?

    ballmovedist = 16 # How far a ball moves each frame
    # Bar slides on
    if @partyAnimPhase == 0
      @sprites["partybarfoe"].x += 16
      @sprites["partybarfoepartner"].x += 16 if @battle.opponent.is_a?(Array)
      @sprites["partybarplayer"].x -= 16
      @sprites["partybarpartner"].x -= 16 if @battle.player.is_a?(Array)
      if @sprites["partybarfoe"].x + @sprites["partybarfoe"].bitmap.width >= foePartyBarX
        @sprites["partybarfoe"].x = foePartyBarX - @sprites["partybarfoe"].bitmap.width
        @sprites["partybarplayer"].x = playerPartyBarX
        @sprites["partybarfoepartner"].x = foePartyBarX - 20 - @sprites["partybarfoepartner"].bitmap.width if @battle.opponent.is_a?(Array)
        @sprites["partybarpartner"].x = playerPartyBarX + 20 if @battle.player.is_a?(Array)
        @partyAnimPhase = 1
      end
      return
    end
    # Set up all balls ready to slide on
    if @partyAnimPhase == 1
      @xposplayer = playerPartyBallOneX
      counter = 0
      # Make sure the ball starts off-screen
      while @xposplayer < Graphics.width
        counter += 1; @xposplayer += ballmovedist
      end
      @xposenemy = foePartyBallOneX - counter * ballmovedist
      for i in 0...6
        # Choose the ball's graphic (player's side)
        if playerside
          # Player
          ballgraphic = "Graphics/Pictures/Battle/ballempty"
          if @battle.party1[i]
            if @battle.party1[i].hp <= 0 || @battle.party1[i].isEgg?
              ballgraphic = "Graphics/Pictures/Battle/ballfainted"
            elsif !@battle.party1[i].status.nil?
              ballgraphic = "Graphics/Pictures/Battle/ballstatus"
            else
              ballgraphic = "Graphics/Pictures/Battle/ballnormal"
            end
          end
          pbAddSprite("player#{i}", @xposplayer + i * ballmovedist * 6, playerPartyBallOneY, ballgraphic, @viewport)
          @sprites["player#{i}"].z = 41
          # Player's partner
          if @battle.player.is_a?(Array)
            ballgraphic = "Graphics/Pictures/Battle/ballempty"
            partnerindex = i + 6
            if @battle.party1[partnerindex]
              if @battle.party1[partnerindex].hp <= 0 || @battle.party1[partnerindex].isEgg?
                ballgraphic = "Graphics/Pictures/Battle/ballfainted"
              elsif !@battle.party1[partnerindex].status.nil?
                ballgraphic = "Graphics/Pictures/Battle/ballstatus"
              else
                ballgraphic = "Graphics/Pictures/Battle/ballnormal"
              end
            end
            pbAddSprite("partner#{i}", @xposplayer + 20 + i * ballmovedist * 6, playerPartyBallOneY + 40, ballgraphic, @viewport)
            @sprites["partner#{i}"].z = 41
          end
        end
        # Choose the ball's graphic (opponent's side)
        if oppside
          # Opponent
          ballgraphic = "Graphics/Pictures/Battle/ballempty"
          if @battle.party2[i]
            if @battle.party2[i].hp <= 0 || @battle.party2[i].isEgg?
              ballgraphic = "Graphics/Pictures/Battle/ballfainted"
            elsif !@battle.party2[i].status.nil?
              ballgraphic = "Graphics/Pictures/Battle/ballstatus"
            else
              ballgraphic = "Graphics/Pictures/Battle/ballnormal"
            end
          end
          y = shift ? foePartyBallOneY - 30 : foePartyBallOneY
          pbAddSprite("enemy#{i}", @xposenemy - i * ballmovedist * 6, y, ballgraphic, @viewport)
          @sprites["enemy#{i}"].z = 41
          # Opponent's partner
          if @battle.opponent.is_a?(Array)
            ballgraphic = "Graphics/Pictures/Battle/ballempty"
            partnerindex = i + 6
            if @battle.party2[partnerindex]
              if @battle.party2[partnerindex].hp <= 0 || @battle.party2[partnerindex].isEgg?
                ballgraphic = "Graphics/Pictures/Battle/ballfainted"
              elsif !@battle.party2[partnerindex].status.nil?
                ballgraphic = "Graphics/Pictures/Battle/ballstatus"
              else
                ballgraphic = "Graphics/Pictures/Battle/ballnormal"
              end
            end
            y = shift ? foePartyBallOneY - 30 : foePartyBallOneY
            pbAddSprite("enemypartner#{i}", @xposenemy - 20 - i * ballmovedist * 6, y + 40, ballgraphic, @viewport)
            @sprites["enemypartner#{i}"].z = 41
          end
        end
      end
      @partyAnimPhase = 2
    end
    # Balls slide on
    if @partyAnimPhase == 2
      for i in 0...6
        if oppside
          if @sprites["enemy#{i}"].x < foePartyBallOneX - i * PBScene::FOEPARTYBALL_GAP
            @sprites["enemy#{i}"].x += ballmovedist
            @sprites["player#{i}"].x -= ballmovedist if playerside
            @sprites["enemypartner#{i}"].x += ballmovedist if @battle.opponent.is_a?(Array)
            @sprites["partner#{i}"].x -= ballmovedist if playerside && @battle.player.is_a?(Array)
            if @sprites["enemy#{i}"].x >= foePartyBallOneX - i * PBScene::FOEPARTYBALL_GAP
              @sprites["enemy#{i}"].x = foePartyBallOneX - i * PBScene::FOEPARTYBALL_GAP
              @sprites["player#{i}"].x = playerPartyBallOneX + i * PBScene::PLAYERPARTYBALL_GAP if playerside
              @sprites["enemypartner#{i}"].x = foePartyBallOneX - 20 - i * PBScene::FOEPARTYBALL_GAP if @battle.opponent.is_a?(Array)
              @sprites["partner#{i}"].x = playerPartyBallOneX + 20 + i * PBScene::PLAYERPARTYBALL_GAP if playerside && @battle.player.is_a?(Array)
              if i == 5
                @partyAnimPhase = 3
              end
              pbSEPlay(@sprites["enemy#{i}"].name.split("/")[-1]) rescue nil
            end
          end
        else
          if @sprites["player#{i}"].x > playerPartyBallOneX + i * PBScene::PLAYERPARTYBALL_GAP
            @sprites["player#{i}"].x -= ballmovedist
            @sprites["partner#{i}"].x -= ballmovedist if @battle.player.is_a?(Array)
            if @sprites["player#{i}"].x <= playerPartyBallOneX + i * PBScene::PLAYERPARTYBALL_GAP
              @sprites["player#{i}"].x = playerPartyBallOneX + i * PBScene::PLAYERPARTYBALL_GAP
              @sprites["partner#{i}"].x = playerPartyBallOneX + 20 + i * PBScene::PLAYERPARTYBALL_GAP if @battle.player.is_a?(Array)
              if i == 5
                @partyAnimPhase = 3
              end
              pbSEPlay(@sprites["player#{i}"].name.split("/")[-1]) rescue nil
            end
          end
        end
      end
    end
  end

  def createPokemonDataBox(battler, doublebattle, viewport, battle)
    if battle.pbIsEnemy(battler.index)
      if battler.isbossmon
        return BossPokemonDataBox.new(battler, doublebattle, viewport, battler.index, battle)
      end
    end
    return PokemonDataBox.new(battler, doublebattle, viewport)
  end

  def pbStartBattle(battle)
    # Called whenever the battle begins
    @battle = battle
    @lastcmd = [0, 0, 0, 0]
    @lastmove = [0, 0, 0, 0]
    @showingplayer = true
    @showingenemy = true
    @sprites.clear
    @viewport = Viewport.new(0, Graphics.height / 2, Graphics.width, 0)
    @viewport.z = 99999
    @traineryoffset = (Graphics.height - 320) # Adjust player's side for screen size
    @foeyoffset = (@traineryoffset * 3 / 4).floor # Adjust foe's side for screen size
    pbBackdrop
    # Add opponent's party bar
    pbAddSprite(
      "partybarfoe",
      foePartyBarX,
      foePartyBarY,
      "Graphics/Pictures/Battle/battleLineup",
      @viewport
    )
    @sprites["partybarfoe"].x -= @sprites["partybarfoe"].bitmap.width
    @sprites["partybarfoe"].z = 40
    @sprites["partybarfoe"].visible = false
    # Add player's party bar
    pbAddSprite(
      "partybarplayer",
      playerPartyBarX,
      playerPartyBarY,
      "Graphics/Pictures/Battle/battleLineup",
      @viewport
    )
    @sprites["partybarplayer"].mirror = true
    @sprites["partybarplayer"].z = 40
    @sprites["partybarplayer"].visible = false
    # Add opponent partner's party bar
    if @battle.opponent.is_a?(Array)
      pbAddSprite(
        "partybarfoepartner",
        foePartyBarX - 20,
        foePartyBarY + 40,
        "Graphics/Pictures/Battle/battleLineup",
        @viewport
      )
      @sprites["partybarfoepartner"].x -= @sprites["partybarfoepartner"].bitmap.width
      @sprites["partybarfoepartner"].z = 40
      @sprites["partybarfoepartner"].visible = false
    end
    # Add player partner's party bar
    if @battle.player.is_a?(Array)
      pbAddSprite(
        "partybarpartner",
        playerPartyBarX + 20,
        playerPartyBarY + 40,
        "Graphics/Pictures/Battle/battleLineup",
        @viewport
      )
      @sprites["partybarpartner"].mirror = true
      @sprites["partybarpartner"].z = 40
      @sprites["partybarpartner"].visible = false
    end
    if @battle.player.is_a?(Array)
      trainerfile = pbPlayerSpriteBackFile(@battle.player[0].trainertype)
      pbAddSprite("player", PBScene::PLAYERTRAINERD1_X, PBScene::PLAYERTRAINERD1_Y, trainerfile, @viewport)
      trainerfile = pbTrainerSpriteBackFile(@battle.player[1].trainertype)
      pbAddSprite("playerB", PBScene::PLAYERTRAINERD2_X, PBScene::PLAYERTRAINERD2_Y, trainerfile, @viewport)
      if @sprites["player"].bitmap
        if @sprites["player"].bitmap.width > @sprites["player"].bitmap.height
          @sprites["player"].src_rect.x = 0
          @sprites["player"].src_rect.width = @sprites["player"].bitmap.width / 5
        end
        @sprites["player"].x -= (@sprites["player"].src_rect.width / 2)
        @sprites["player"].y -= @sprites["player"].bitmap.height
        @sprites["player"].z = 30
      end
      if @sprites["playerB"].bitmap
        if @sprites["playerB"].bitmap.width > @sprites["playerB"].bitmap.height
          @sprites["playerB"].src_rect.x = 0
          @sprites["playerB"].src_rect.width = @sprites["playerB"].bitmap.width / 5
        end
        @sprites["playerB"].x -= (@sprites["playerB"].src_rect.width / 2)
        @sprites["playerB"].y -= @sprites["playerB"].bitmap.height
        @sprites["playerB"].z = 31
      end
    else
      trainerfile = pbPlayerSpriteBackFile(@battle.player.trainertype)
      pbAddSprite("player", PBScene::PLAYERTRAINER_X, PBScene::PLAYERTRAINER_Y, trainerfile, @viewport)
      if @sprites["player"].bitmap
        if @sprites["player"].bitmap.width > @sprites["player"].bitmap.height
          @sprites["player"].src_rect.x = 0
          @sprites["player"].src_rect.width = @sprites["player"].bitmap.width / 5
        end
        @sprites["player"].x -= (@sprites["player"].src_rect.width / 2)
        @sprites["player"].y -= @sprites["player"].bitmap.height
        @sprites["player"].z = 30
      end
    end
    if @battle.opponent
      if @battle.opponent.is_a?(Array)
        trainerfile = pbTrainerSpriteFile(@battle.opponent[1].trainertype, @battle.opponent[1].outfit)
        pbAddSprite("trainer2", PBScene::FOETRAINERD2_X, PBScene::FOETRAINERD2_Y, trainerfile, @viewport)
        trainerfile = pbTrainerSpriteFile(@battle.opponent[0].trainertype, @battle.opponent[0].outfit)
        pbAddSprite("trainer", PBScene::FOETRAINERD1_X, PBScene::FOETRAINERD1_Y, trainerfile, @viewport)
      else
        trainerfile = pbTrainerSpriteFile(@battle.opponent.trainertype, @battle.opponent.outfit)
        pbAddSprite("trainer", PBScene::FOETRAINER_X, PBScene::FOETRAINER_Y, trainerfile, @viewport)
      end
    else
      trainerfile = "Graphics/Characters/trfront"
      pbAddSprite("trainer", PBScene::FOETRAINER_X, PBScene::FOETRAINER_Y, trainerfile, @viewport)
    end
    if @sprites["trainer"].bitmap
      @sprites["trainer"].x -= (@sprites["trainer"].bitmap.width / 2)
      @sprites["trainer"].y -= @sprites["trainer"].bitmap.height
      @sprites["trainer"].z = 8
    end
    if @sprites["trainer2"] && @sprites["trainer2"].bitmap
      @sprites["trainer2"].x -= (@sprites["trainer2"].bitmap.width / 2)
      @sprites["trainer2"].y -= @sprites["trainer2"].bitmap.height
      @sprites["trainer2"].z = 7
    end
    @sprites["shadow0"] = IconSprite.new(0, 0, @viewport)
    @sprites["shadow0"].z = 3
    pbAddSprite("shadow1", 0, 0, "Graphics/Pictures/Battle/battleShadow", @viewport)
    @sprites["shadow1"].z = 3
    @sprites["shadow1"].visible = false
    @sprites["pokemon0"] = PokemonBattlerSprite.new(battle.doublebattle, 0, @viewport)
    @sprites["pokemon0"].z = 21
    @sprites["pokemon1"] = PokemonBattlerSprite.new(battle.doublebattle, 1, @viewport)
    @sprites["pokemon1"].z = 16
    if battle.doublebattle
      @sprites["shadow2"] = IconSprite.new(0, 0, @viewport)
      @sprites["shadow2"].z = 3
      pbAddSprite("shadow3", 0, 0, "Graphics/Pictures/Battle/battleShadow", @viewport)
      @sprites["shadow3"].z = 3
      @sprites["shadow3"].visible = false
      @sprites["pokemon2"] = PokemonBattlerSprite.new(battle.doublebattle, 2, @viewport)
      @sprites["pokemon2"].z = 26 # Editing to see
      @sprites["pokemon3"] = PokemonBattlerSprite.new(battle.doublebattle, 3, @viewport)
      @sprites["pokemon3"].z = 11
    end
    @sprites["battlebox0"] = createPokemonDataBox(battle.battlers[0], battle.doublebattle, @viewport, battle)
    @sprites["battlebox1"] = createPokemonDataBox(battle.battlers[1], battle.doublebattle, @viewport, battle)
    if battle.doublebattle
      @sprites["battlebox2"] = createPokemonDataBox(battle.battlers[2], battle.doublebattle, @viewport, battle)
      @sprites["battlebox3"] = createPokemonDataBox(battle.battlers[3], battle.doublebattle, @viewport, battle)
    end
    pbAddSprite("messagebox", 0, Graphics.height - 96, "Graphics/Pictures/Battle/battleMessage", @viewport)
    @sprites["messagebox"].z = 90
    @sprites["helpwindow"] = Window_UnformattedTextPokemon.newWithSize("", 0, 0, 32, 32, @viewport)
    @sprites["helpwindow"].visible = false
    @sprites["helpwindow"].z = 90
    @sprites["messagewindow"] = Window_AdvancedTextPokemon.new("")
    @sprites["messagewindow"].letterbyletter = true
    @sprites["messagewindow"].viewport = @viewport
    @sprites["messagewindow"].z = 100
    @sprites["commandwindow"] = CommandMenuDisplay.new(@viewport)
    @sprites["commandwindow"].z = 100
    @sprites["fightwindow"] = FightMenuDisplay.new(nil, @viewport)
    @sprites["fightwindow"].z = 100
    pbShowWindow(MESSAGEBOX)
    pbSetMessageMode(false)
    trainersprite1 = @sprites["trainer"]
    trainersprite2 = @sprites["trainer2"]
    if !@battle.opponent
      @sprites["trainer"].visible = false
      if @battle.party2.length >= 1
        if @battle.party2.length == 1
          species = @battle.party2[0].species
          form = @battle.party2[0].form
          @sprites["pokemon1"].setPokemonBitmap(@battle.party2[0], false)
          @sprites["pokemon1"].tone = Tone.new(-128, -128, -128, -128)
          @sprites["pokemon1"].x = PBScene::FOEBATTLER_X
          @sprites["pokemon1"].x -= @sprites["pokemon1"].width / 2
          @sprites["pokemon1"].y = PBScene::FOEBATTLER_Y
          @sprites["pokemon1"].y += adjustBattleSpriteY(@sprites["pokemon1"], species, form, 1)
          @sprites["pokemon1"].visible = true
          @sprites["shadow1"].x = PBScene::FOEBATTLER_X
          @sprites["shadow1"].y = PBScene::FOEBATTLER_Y
          @sprites["shadow1"].x -= @sprites["shadow1"].bitmap.width / 2 if @sprites["shadow1"].bitmap != nil
          @sprites["shadow1"].y -= @sprites["shadow1"].bitmap.height / 2 if @sprites["shadow1"].bitmap != nil
          @sprites["shadow1"].visible = showShadow?(species, form)
          trainersprite1 = @sprites["pokemon1"]
        elsif @battle.party2.length == 2
          species = @battle.party2[0].species
          form = @battle.party2[0].form
          @sprites["pokemon1"].setPokemonBitmap(@battle.party2[0], false)
          @sprites["pokemon1"].tone = Tone.new(-128, -128, -128, -128)
          @sprites["pokemon1"].x = PBScene::FOEBATTLERD1_X
          @sprites["pokemon1"].x -= @sprites["pokemon1"].width / 2
          @sprites["pokemon1"].y = PBScene::FOEBATTLERD1_Y
          @sprites["pokemon1"].y += adjustBattleSpriteY(@sprites["pokemon1"], species, form, 1)
          @sprites["pokemon1"].visible = true
          @sprites["shadow1"].x = PBScene::FOEBATTLERD1_X
          @sprites["shadow1"].y = PBScene::FOEBATTLERD1_Y
          @sprites["shadow1"].x -= @sprites["shadow1"].bitmap.width / 2 if @sprites["shadow1"].bitmap != nil
          @sprites["shadow1"].y -= @sprites["shadow1"].bitmap.height / 2 if @sprites["shadow1"].bitmap != nil
          @sprites["shadow1"].visible = showShadow?(species, form)
          trainersprite1 = @sprites["pokemon1"]
          species = @battle.party2[1].species
          form = @battle.party2[1].form
          @sprites["pokemon3"].setPokemonBitmap(@battle.party2[1], false)
          @sprites["pokemon3"].tone = Tone.new(-128, -128, -128, -128)
          @sprites["pokemon3"].x = PBScene::FOEBATTLERD2_X
          @sprites["pokemon3"].x -= @sprites["pokemon3"].width / 2
          @sprites["pokemon3"].y = PBScene::FOEBATTLERD2_Y
          @sprites["pokemon3"].y += adjustBattleSpriteY(@sprites["pokemon3"], species, form, 3)
          @sprites["pokemon3"].visible = true
          @sprites["shadow3"].x = PBScene::FOEBATTLERD2_X
          @sprites["shadow3"].y = PBScene::FOEBATTLERD2_Y
          @sprites["shadow3"].x -= @sprites["shadow3"].bitmap.width / 2 if @sprites["shadow3"].bitmap != nil
          @sprites["shadow3"].y -= @sprites["shadow3"].bitmap.height / 2 if @sprites["shadow3"].bitmap != nil
          @sprites["shadow3"].visible = showShadow?(species, form)
          trainersprite2 = @sprites["pokemon3"]
        end
      end
    end
    #################
    # Move trainers/bases/etc. off-screen
    oldx = []
    oldx[0] = @sprites["playerbase"].x; @sprites["playerbase"].x += Graphics.width
    oldx[1] = @sprites["player"].x; @sprites["player"].x += Graphics.width
    if @sprites["playerB"]
      oldx[2] = @sprites["playerB"].x; @sprites["playerB"].x += Graphics.width
    end
    oldx[3] = @sprites["enemybase"].x; @sprites["enemybase"].x -= Graphics.width
    oldx[4] = trainersprite1.x; trainersprite1.x -= Graphics.width
    if trainersprite2
      oldx[5] = trainersprite2.x; trainersprite2.x -= Graphics.width
    end
    oldx[6] = @sprites["shadow1"].x; @sprites["shadow1"].x -= Graphics.width
    if @sprites["shadow3"]
      oldx[7] = @sprites["shadow3"].x; @sprites["shadow3"].x -= Graphics.width
    end
    @sprites["partybarfoe"].x -= foePartyBarX
    @sprites["partybarplayer"].x += Graphics.width - playerPartyBarX
    @sprites["partybarfoepartner"].x -= foePartyBarX - 20 if @battle.opponent.is_a?(Array)
    @sprites["partybarpartner"].x += Graphics.width - (playerPartyBarX + 20) if @battle.player.is_a?(Array)
    #################
    appearspeed = 12
    (1 + Graphics.width / appearspeed).times do
      tobreak = true
      if @viewport.rect.y > 0
        @viewport.rect.y -= appearspeed / 2
        @viewport.rect.y = 0 if @viewport.rect.y < 0
        @viewport.rect.height += appearspeed
        @viewport.rect.height = Graphics.height if @viewport.rect.height > Graphics.height
        tobreak = false
      end
      if !tobreak
        for i in @sprites
          i[1].ox = @viewport.rect.x
          i[1].oy = @viewport.rect.y
        end
      end
      if @sprites["playerbase"].x > oldx[0]
        @sprites["playerbase"].x -= appearspeed; tobreak = false
        @sprites["playerbase"].x = oldx[0] if @sprites["playerbase"].x < oldx[0]
      end
      if @sprites["player"].x > oldx[1]
        @sprites["player"].x -= appearspeed; tobreak = false
        @sprites["player"].x = oldx[1] if @sprites["player"].x < oldx[1]
      end
      if @sprites["playerB"] && @sprites["playerB"].x > oldx[2]
        @sprites["playerB"].x -= appearspeed; tobreak = false
        @sprites["playerB"].x = oldx[2] if @sprites["playerB"].x < oldx[2]
      end
      if @sprites["enemybase"].x < oldx[3]
        @sprites["enemybase"].x += appearspeed; tobreak = false
        @sprites["enemybase"].x = oldx[3] if @sprites["enemybase"].x > oldx[3]
      end
      if trainersprite1.x < oldx[4]
        trainersprite1.x += appearspeed; tobreak = false
        trainersprite1.x = oldx[4] if trainersprite1.x > oldx[4]
      end
      if trainersprite2 && trainersprite2.x < oldx[5]
        trainersprite2.x += appearspeed; tobreak = false
        trainersprite2.x = oldx[5] if trainersprite2.x > oldx[5]
      end
      if @sprites["shadow1"].x < oldx[6]
        @sprites["shadow1"].x += appearspeed; tobreak = false
        @sprites["shadow1"].x = oldx[6] if @sprites["shadow1"].x > oldx[6]
      end
      if @sprites["shadow3"] && @sprites["shadow3"].x < oldx[7]
        @sprites["shadow3"].x += appearspeed; tobreak = false
        @sprites["shadow3"].x = oldx[7] if @sprites["shadow3"].x > oldx[7]
      end
      pbGraphicsUpdate
      Input.update
      break if tobreak
    end
    # Play cry for wild Pokémon
    if !@battle.opponent
      if !@battle.doublebattle
        pbPlayCry(@battle.party2[0])
      else
        pbPlayCry(@battle.party2[0])
        pbPlayCry(@battle.party2[1])
      end
    end
    if @battle.opponent
      @enablePartyAnim = true
      @partyAnimPhase = 0
      @sprites["partybarfoe"].visible = true
      @sprites["partybarplayer"].visible = true
      @sprites["partybarfoepartner"].visible = true if @battle.opponent.is_a?(Array)
      @sprites["partybarpartner"].visible = true if @battle.player.is_a?(Array)
    else
      @sprites["battlebox1"].appear
      @sprites["battlebox3"].appear if @battle.party2.length == 2
      appearing = true
      begin
        pbGraphicsUpdate
        Input.update
        @sprites["battlebox1"].update
        @sprites["pokemon1"].tone.red += 8 if @sprites["pokemon1"].tone.red < 0
        @sprites["pokemon1"].tone.blue += 8 if @sprites["pokemon1"].tone.blue < 0
        @sprites["pokemon1"].tone.green += 8 if @sprites["pokemon1"].tone.green < 0
        @sprites["pokemon1"].tone.gray += 8 if @sprites["pokemon1"].tone.gray < 0
        appearing = @sprites["battlebox1"].appearing
        if @battle.party2.length == 2
          @sprites["battlebox3"].update
          @sprites["pokemon3"].tone.red += 8 if @sprites["pokemon3"].tone.red < 0
          @sprites["pokemon3"].tone.blue += 8 if @sprites["pokemon3"].tone.blue < 0
          @sprites["pokemon3"].tone.green += 8 if @sprites["pokemon3"].tone.green < 0
          @sprites["pokemon3"].tone.gray += 8 if @sprites["pokemon3"].tone.gray < 0
          appearing = (appearing || @sprites["battlebox3"].appearing)
        end
      end while appearing
      # Show shiny animation for wild Pokémon
      if @battle.party2[0].isShiny? && @battle.battlescene
        pbCommonAnimation("Shiny", @battle.battlers[1], nil)
      end
      if @battle.party2.length == 2
        if @battle.party2[1].isShiny? && @battle.battlescene
          pbCommonAnimation("Shiny", @battle.battlers[3], nil)
        end
      end
    end
  end

  def pbEndBattle(result)
    pbShowWindow(BLANK)
    # Fade out all sprites
    pbBGMFade(1.0)
    pbFadeOutAndHide(@sprites)
    pbDisposeSprites
  end

  def pbDisableShadowTemp(battler)
    if showShadow?(battler.species, battler.form) && battler.index.odd?
      @sprites["shadow#{battler.index}"].visible = false
    end
  end

  def pbReAbleShadow(battler)
    if showShadow?(battler.species, battler.form) && battler.index.odd?
      @sprites["shadow#{battler.index}"].visible = true
    end
  end

  def pbRecall(battlerindex)
    @briefmessage = false
    if @battle.pbIsOpposing?(battlerindex)
      origin = PBScene::FOEBATTLER_Y
      if @battle.doublebattle
        origin = PBScene::FOEBATTLERD1_Y if battlerindex == 1
        origin = PBScene::FOEBATTLERD2_Y if battlerindex == 3
      end
      @sprites["shadow#{battlerindex}"].visible = false
    else
      origin = PBScene::PLAYERBATTLER_Y
      if @battle.doublebattle
        origin = PBScene::PLAYERBATTLERD1_Y if battlerindex == 0
        origin = PBScene::PLAYERBATTLERD2_Y if battlerindex == 2
      end
    end
    spritePoke = @sprites["pokemon#{battlerindex}"]
    picturePoke = PictureEx.new(spritePoke.z)
    center = getSpriteCenter(spritePoke)
    # starting positions
    picturePoke.moveVisible(1, true)
    picturePoke.moveOrigin(1, PictureOrigin::Center)
    picturePoke.moveXY(0, 1, center[0], center[1])
    # directives
    #    picturePoke.moveTone(10,1,Tone.new(0,-224,-224,0))
    picturePoke.moveTone(10, 1, Tone.new(248, 248, 248, 248))
    delay = picturePoke.totalDuration
    picturePoke.moveSE(delay, "Audio/SE/recall")
    picturePoke.moveZoom(15, delay, 0)
    picturePoke.moveXY(15, delay, center[0], origin)
    picturePoke.moveVisible(picturePoke.totalDuration, false)
    picturePoke.moveTone(0, picturePoke.totalDuration, Tone.new(0, 0, 0, 0))
    picturePoke.moveOrigin(picturePoke.totalDuration, PictureOrigin::TopLeft)
    loop do
      picturePoke.update
      setPictureSprite(spritePoke, picturePoke)
      pbGraphicsUpdate
      Input.update
      break if !picturePoke.running?
    end
  end

  def pbTrainerSendOut(battlerindex, pkmn)
    @briefmessage = false
    fadeanim = nil
    while inPartyAnimation?; end
    if @showingenemy
      fadeanim = TrainerFadeAnimation.new(@sprites)
    end
    frame = 0
    @sprites["pokemon#{battlerindex}"].setPokemonBitmap(pkmn, false)
    if @battle.battlers[battlerindex].effects[:Illusion] != nil # Illusion
      @sprites["pokemon#{battlerindex}"].setPokemonBitmap(
        @battle.battlers[battlerindex].effects[:Illusion].pokemon, false
      )
    end
    sendout = PokeballSendOutAnimation.new(
      @sprites["pokemon#{battlerindex}"],
      @sprites, @battle.battlers[battlerindex], @battle.doublebattle,
      @battle.battlers[battlerindex].effects[:Illusion]
    ) # Illusion
    @sprites["pokemon#{battlerindex}"].opacity = 255
    @sprites["battlebox#{battlerindex}"].visible = false
    pbDisposeSprite(@sprites, ["battlebox#{battlerindex}"])
    @sprites["battlebox#{battlerindex}"] = createPokemonDataBox(@battle.battlers[battlerindex], @battle.doublebattle, @viewport, @battle)
    loop do
      pbGraphicsUpdate
      Input.update
      fadeanim.update if fadeanim
      frame += 1
      if frame == 1
        @sprites["battlebox#{battlerindex}"].appear
      end
      if frame >= 10
        sendout.update
      end
      @sprites["battlebox#{battlerindex}"].update
      break if (!fadeanim || fadeanim.animdone?) && sendout.animdone? &&
               !@sprites["battlebox#{battlerindex}"].appearing
    end
    if @battle.battlescene && ((@battle.battlers[battlerindex].pokemon.isShiny? &&
      @battle.battlers[battlerindex].effects[:Illusion].nil?) ||
       (@battle.battlers[battlerindex].effects[:Illusion] != nil &&
       @battle.battlers[battlerindex].effects[:Illusion].pokemon.isShiny?))
      pbCommonAnimation("Shiny", @battle.battlers[battlerindex], nil)
    end
    sendout.dispose
    if @showingenemy
      @showingenemy = false
      pbDisposeSprite(@sprites, "trainer")
      pbDisposeSprite(@sprites, "partybarfoe")
      for i in 0...6
        pbDisposeSprite(@sprites, "enemy#{i}")
      end
    end
    pbRefresh
  end

  def pbSendOut(battlerindex, pkmn, slidein = false) # Player sending out Pokémon
    while inPartyAnimation?; end
    unless slidein
      balltype = pkmn.ballused
      ballbitmap = sprintf("Graphics/Pictures/Battle/%s", balltype)
      pictureBall = PictureEx.new(32)
      delay = 1
      pictureBall.moveVisible(delay, true)
      pictureBall.moveName(delay, ballbitmap)
      pictureBall.moveOrigin(delay, PictureOrigin::Center)
      # Setting the ball's movement path
      path = [[0, 146], [10, 134], [21, 122], [30, 112],
              [39, 104], [46, 99], [53, 95], [61, 93],
              [68, 93], [75, 96], [82, 102], [89, 111],
              [94,  121], [100, 134], [106, 150], [111, 166],
              [116, 183], [120, 199], [124, 216], [127, 238]]
      spriteBall = IconSprite.new(0, 0, @viewport)
      spriteBall.visible = false
      angle = 0
      multiplier = 1.0
      if @battle.doublebattle
        multiplier = (battlerindex == 0) ? 0.7 : 1.3
      end
      for coord in path
        delay = pictureBall.totalDuration
        pictureBall.moveAngle(0, delay, angle)
        pictureBall.moveXY(1, delay, coord[0] * multiplier, coord[1])
        angle += 40
        angle %= 360
      end
      pictureBall.adjustPosition(0, @traineryoffset)
    end
    @sprites["battlebox#{battlerindex}"].visible = false
    @briefmessage = false
    fadeanim = nil
    if @showingplayer
      fadeanim = PlayerFadeAnimation.new(@sprites, !slidein)
    end
    frame = 0
    @sprites["pokemon#{battlerindex}"].setPokemonBitmap(pkmn, true)
    if @battle.battlers[battlerindex].effects[:Illusion] != nil
      @sprites["pokemon#{battlerindex}"].setPokemonBitmap(
        @battle.battlers[battlerindex].effects[:Illusion].pokemon, true
      )
    end
    if slidein
      sendout = FollowerPlayerSendOutAnimation.new(
        @sprites["pokemon#{battlerindex}"],
        @sprites, @battle.battlers[battlerindex], @battle.doublebattle,
        @battle.battlers[battlerindex].effects[:Illusion], @battle
      )
    else
      sendout = PokeballPlayerSendOutAnimation.new(
        @sprites["pokemon#{battlerindex}"],
        @sprites, @battle.battlers[battlerindex], @battle.doublebattle,
        @battle.battlers[battlerindex].effects[:Illusion], @battle
      )
    end
    @sprites["pokemon#{battlerindex}"].opacity = 255
    loop do
      fadeanim.update if fadeanim
      frame += 1
      if frame > 1 && (slidein || !pictureBall.running?) && !@sprites["battlebox#{battlerindex}"].appearing
        @sprites["battlebox#{battlerindex}"].appear
      end
      if frame >= 3 && (slidein || !pictureBall.running?)
        sendout.update
      end
      if !slidein && (frame >= 10 || !fadeanim) && pictureBall.running?
        pictureBall.update
        setPictureIconSprite(spriteBall, pictureBall)
      end
      @sprites["battlebox#{battlerindex}"].update
      pbGraphicsUpdate
      Input.update
      break if (!fadeanim || fadeanim.animdone?) && sendout.animdone? &&
               !@sprites["battlebox#{battlerindex}"].appearing
    end
    unless slidein
      spriteBall.dispose
      sendout.dispose
    end
    if @battle.battlescene && ((@battle.battlers[battlerindex].pokemon.isShiny? &&
      @battle.battlers[battlerindex].effects[:Illusion].nil?) ||
       (@battle.battlers[battlerindex].effects[:Illusion] != nil &&
       @battle.battlers[battlerindex].effects[:Illusion].pokemon.isShiny?))
      pbCommonAnimation("Shiny", @battle.battlers[battlerindex], nil)
    end
    if @showingplayer
      @showingplayer = false
      pbDisposeSprite(@sprites, "player")
      pbDisposeSprite(@sprites, "partybarplayer")
      for i in 0...6
        pbDisposeSprite(@sprites, "player#{i}")
      end
    end
    if @battle.battlers[battlerindex].effects[:Substitute] > 0
      move = PokeBattle_Move.pbFromPBMove(@battle, PBMove.new(:SUBSTITUTE), @battle.battlers[battlerindex].pokemon)
      @battle.battlers[battlerindex].effects[:UsingSubstituteRightNow] = true
      # move.pbShowAnimation(:SUBSTITUTE,@battle.battlers[battlerindex],nil)
      @battle.scene.pbAnimation(move, @battle.battlers[battlerindex], nil)
      @battle.battlers[battlerindex].effects[:UsingSubstituteRightNow] = false
    end
    @battle.seedCheck if @battle.turncount != 0
    pbRefresh
  end

  def pbTrainerWithdraw(battle, pkmn)
    pbRefresh
  end

  def pbWithdraw(battle, pkmn)
    pbRefresh
  end

  def pbMoveString(move)
    ret = _INTL("{1}", move.name)
    typename = getTypeName(move.type)
    ret += _INTL(" ({1}) PP: {2}/{3}", typename, move.pp, move.totalpp)
    return ret
  end

  def pbBeginAttackPhase
    pbSelectBattler(-1)
    pbGraphicsUpdate
  end

  def pbSafariStart
    @briefmessage = false
    @sprites["battlebox0"] = SafariDataBox.new(@battle, @viewport)
    @sprites["battlebox0"].appear
    loop do
      @sprites["battlebox0"].update
      pbGraphicsUpdate
      Input.update
      break if !@sprites["battlebox0"].appearing
    end
    pbRefresh
  end

  def pbResetCommandIndices
    @lastcmd = [0, 0, 0, 0]
  end

  def pbResetMoveIndex(index)
    @lastmove[index] = 0
  end

  def pbSafariCommandMenu(index)
    pbCommandMenuEx(
      index,
      [
        _INTL("What will\n{1} throw?", @battle.pbPlayer.name),
        _INTL("Ball"),
        _INTL("Bait"),
        _INTL("Rock"),
        _INTL("Run")
      ],
      2
    )
  end

  # Use this method to display the list of commands.
  # Return values: 0=Fight, 1=Bag, 2=Pokémon, 3=Run, 4=Call
  def pbCommandMenu(index)
    shadowTrainer = false
    if @battle.battlers[0].isShadow?
      shadowTrainer = true
    end
    if @battle.doublebattle && $Trainer.ablePokemonCount > 1
      if @battle.battlers[2].isShadow?
        shadowTrainer = true
      end
    end
    ret = pbCommandMenuEx(
      index,
      [
        _INTL("What will\n{1} do?", @battle.battlers[index].name),
        _INTL("Fight"),
        _INTL("Bag"),
        _INTL("Pokémon"),
        shadowTrainer ? _INTL("Call") : _INTL("Run")
      ],
      (shadowTrainer ? 1 : 0)
    )
    ret = 4 if ret == 3 && shadowTrainer # Convert "Run" to "Call"
    return ret
  end

  def pbToggleStatsBoostsVisibility
    $doShowStatBoosts = true if !defined?($doShowStatBoosts)
    $doShowStatBoosts = !$doShowStatBoosts
    for i in 0..3
      tmp = "battlebox#{i}"
      @sprites[tmp].refresh if @sprites[tmp]
    end
  end

  def pbCommandMenuEx(index, texts, mode = 0) # Mode: 0 - regular battle
    pbShowWindow(COMMANDBOX) #       1 - Shadow Pokémon battle
    cw = @sprites["commandwindow"] #       2 - Safari Zone
    cw.setTexts(texts) #       3 - Bug Catching Contest
    cw.index = 0 if @lastcmd[index] == 2 || $Settings.remember_commands == 0
    cw.mode = mode
    fieldnotes = readableFieldNotes()
    pulsenotes = readablePulseNotes(@battle) if Reborn
    pbSelectBattler(index)
    pbRefresh
    update_menu = true
    tts(texts[0])
    loop do
      pbGraphicsUpdate
      Input.update
      pbFrameUpdate(cw, update_menu)
      update_menu = false
      # Update selected command
      if Input.trigger?(Input::CTRL)
        pbToggleStatsBoostsVisibility
        pbPlayCursorSE()
        update_menu = true
      elsif Input.trigger?(Input::LEFT) && (cw.index & 1) == 1
        pbPlayCursorSE()
        cw.index -= 1
        tts(texts[cw.index + 1])
        update_menu = true
      elsif Input.trigger?(Input::RIGHT) && (cw.index & 1) == 0
        pbPlayCursorSE()
        cw.index += 1
        tts(texts[cw.index + 1])
        update_menu = true
      elsif Input.trigger?(Input::UP) && (cw.index & 2) == 2
        pbPlayCursorSE()
        cw.index -= 2
        tts(texts[cw.index + 1])
        update_menu = true
      elsif Input.trigger?(Input::DOWN) && (cw.index & 2) == 0
        pbPlayCursorSE()
        cw.index += 2
        tts(texts[cw.index + 1])
        update_menu = true
      elsif Input.trigger?(Input::Y) && canCheckFieldApp?(fieldnotes)
        pbPlayCursorSE()
        infoscene = Scene_FieldNotes_Battle.new
        pbCheckPokegearScene(infoscene, fieldnotes)
        update_menu = true
      elsif Input.trigger?(Input::Z) && canCheckPulseDex?(pulsenotes)
        pbPlayCursorSE()
        infoscene = Scene_PulseDex_Battle.new
        backgrounds = pulsenotes
        pbCheckPokegearScene(infoscene, backgrounds)
        update_menu = true
      elsif Input.trigger?(Input::L) # Show Battle Stats feature made by DemICE, Trainer Pokemon
        if !pbInSafari?
          pbShowBattleStats(@battle.battlers[index])
        end
        return -1
      elsif Input.trigger?(Input::R) # Show Battle Stats feature made by DemICE, Opponent Pokemon
        if !pbInSafari?
          battleindex = 3
          battleindex = 1 if !@battle.doublebattle || @battle.battlers[battleindex].isFainted?
          pbShowBattleStats(@battle.battlers[battleindex])
        end
        return -1
      end
      if Input.trigger?(Input::C) # Confirm choice
        pbPlayDecisionSE()
        ret = cw.index
        @lastcmd[index] = ret
        return ret
      elsif Input.trigger?(Input::B) && index == 2 # && @lastcmd[0]!=2 # Cancel #Commented out for cancelling switches in doubles
        pbPlayDecisionSE()
        return -1
      end
    end
  end

  # Use this method to display the list of moves for a Pokémon
  def pbFightMenu(index)
    pbShowWindow(FIGHTBOX)
    cw = @sprites["fightwindow"]
    battler = @battle.battlers[index]
    cw.battler = battler
    lastIndex = @lastmove[index]
    if battler.moves[lastIndex]
      cw.setIndex(lastIndex)
    else
      cw.setIndex(0)
    end
    cw.megaButton = 0
    cw.megaButton = 1 if (@battle.pbCanMegaEvolve?(index) && !@battle.pbCanZMove?(index))
    cw.megaButton = 2 if @battle.megaEvolution[(@battle.pbIsOpposing?(index)) ? 1 : 0][@battle.pbGetOwnerIndex(index)] == index && @battle.battlers[index].hasMega?
    cw.ultraButton = 0
    cw.ultraButton = 1 if @battle.pbCanUltraBurst?(index)
    cw.ultraButton = 2 if @battle.ultraBurst[(@battle.pbIsOpposing?(index)) ? 1 : 0][@battle.pbGetOwnerIndex(index)] == index && @battle.battlers[index].hasUltra?
    cw.zButton = 0
    cw.zButton = 1 if @battle.pbCanZMove?(index)
    # cw.zButton=2 if @battle.zMove[(@battle.pbIsOpposing?(index)) ? 1 : 0][@battle.pbGetOwnerIndex(index)] == index && @battle.battlers[index].hasZMove?
    fieldnotes = readableFieldNotes()
    pulsenotes = readablePulseNotes(@battle) if Reborn
    showingMoveDetails = false
    pbSelectBattler(index)
    pbRefresh
    update_menu = true
    ttsMove(battler, cw.index, cw.zButton == 2)
    loop do
      Graphics.update
      Input.update
      pbFrameUpdate(cw, update_menu)
      update_menu = false
      # Update selected command
      if Input.trigger?(Input::CTRL)
        pbToggleStatsBoostsVisibility
        pbPlayCursorSE()
        update_menu = true
      elsif Input.trigger?(Input::LEFT) && (cw.index & 1) == 1
        pbPlayCursorSE() if cw.setIndex(cw.index - 1)
        ttsMove(battler, cw.index, cw.zButton == 2)
        pbDrawMoveDetails(battler, cw.index, cw.zButton == 2) if showingMoveDetails
        update_menu = true
      elsif Input.trigger?(Input::RIGHT) && (cw.index & 1) == 0
        pbPlayCursorSE() if cw.setIndex(cw.index + 1)
        ttsMove(battler, cw.index, cw.zButton == 2)
        pbDrawMoveDetails(battler, cw.index, cw.zButton == 2) if showingMoveDetails
        update_menu = true
      elsif Input.trigger?(Input::UP) && (cw.index & 2) == 2
        pbPlayCursorSE() if cw.setIndex(cw.index - 2)
        ttsMove(battler, cw.index, cw.zButton == 2)
        pbDrawMoveDetails(battler, cw.index, cw.zButton == 2) if showingMoveDetails
        update_menu = true
      elsif Input.trigger?(Input::DOWN) && (cw.index & 2) == 0
        pbPlayCursorSE() if cw.setIndex(cw.index + 2)
        ttsMove(battler, cw.index, cw.zButton == 2)
        pbDrawMoveDetails(battler, cw.index, cw.zButton == 2) if showingMoveDetails
        update_menu = true
      elsif Input.trigger?(Input::Y) && canCheckFieldApp?(fieldnotes)
        pbPlayCursorSE()
        infoscene = Scene_FieldNotes_Battle.new
        pbCheckPokegearScene(infoscene, fieldnotes)
        update_menu = true
      elsif Input.trigger?(Input::Z) && canCheckPulseDex?(pulsenotes)
        pbPlayCursorSE()
        infoscene = Scene_PulseDex_Battle.new
        backgrounds = pulsenotes
        pbCheckPokegearScene(infoscene, backgrounds)
        update_menu = true
      elsif Input.trigger?(Input::L) # Show Battle Stats feature made by DemICE, Trainer Pokemon
        pbDisposeMoveDetails if showingMoveDetails
        pbShowBattleStats(@battle.battlers[index])
        return -1
      elsif Input.trigger?(Input::R) # Show Battle Stats feature made by DemICE, Opponent Pokemon
        pbDisposeMoveDetails if showingMoveDetails
        battleindex = 3
        battleindex = 1 if !@battle.doublebattle || @battle.battlers[battleindex].isFainted?
        pbShowBattleStats(@battle.battlers[battleindex])
        return -1
      elsif Input.trigger?(Input::A) && Reborn
        showingMoveDetails = !showingMoveDetails
        showingMoveDetails ? pbDrawMoveDetails(battler, cw.index, cw.zButton == 2, new: true) : pbDisposeMoveDetails
        pbPlayCursorSE()
        update_menu = true
      end
      if Input.trigger?(Input::C) # Confirm choice
        pbDisposeMoveDetails if showingMoveDetails
        ret = cw.index
        if cw.zButton == 2
          if battler.pbCompatibleZMoveFromMove?(ret, true)
            pbPlayDecisionSE()
            @lastmove[index] = ret
            return ret
          else
            @battle.pbDisplay(_INTL("{1} is not compatible with {2}!", battler.moves[ret].name, getItemName(battler.item)))
            @lastmove[index] = cw.index
            return -1
          end
        else
          pbPlayDecisionSE()
          @lastmove[index] = ret
          return ret
        end
      elsif Input.trigger?(Input::X)   # Use Mega Evolution
        if @battle.pbCanMegaEvolve?(index) && !pbIsZCrystal?(battler.item)
          if cw.megaButton == 2
            tts("Mega Evolution deactivated")
            @battle.pbUnRegisterMegaEvolution(index)
            cw.megaButton = 1
            pbPlayCancelSE()
          else
            tts("Mega Evolution activated")
            @battle.pbRegisterMegaEvolution(index)
            cw.megaButton = 2
            pbPlayDecisionSE()
          end
        end
        if @battle.pbCanUltraBurst?(index)
          if cw.ultraButton == 2
            tts("Ultra Burst deactivated")
            @battle.pbUnRegisterUltraBurst(index)
            cw.ultraButton = 1
            pbPlayCancelSE()
          else
            tts("Ultra Burst activated")
            @battle.pbRegisterUltraBurst(index)
            cw.ultraButton = 2
            pbPlayDecisionSE()
          end
        end
        if @battle.pbCanZMove?(index)  # Use Z Move
          if cw.zButton == 2
            tts("Z-Moves deactivated")
            @battle.pbUnRegisterZMove(index)
            cw.zButton = 1
            pbPlayCancelSE()
          else
            tts("Z-Moves activated")
            @battle.pbRegisterZMove(index)
            cw.zButton = 2
            pbPlayDecisionSE()
          end
          if battler.zmoves[cw.index]
            ttsMove(battler, cw.index, cw.zButton == 2)
            pbDrawMoveDetails(battler, cw.index, cw.zButton == 2) if showingMoveDetails
          end
        end
        update_menu = true
      elsif Input.trigger?(Input::B)   # Cancel fight menu
        pbDisposeMoveDetails if showingMoveDetails
        @lastmove[index] = cw.index
        pbPlayCancelSE()
        return -1
      end
    end
  end

  def ttsMove(battler, moveIndex, zmove)
    move = zmove && battler.pbCompatibleZMoveFromMove?(moveIndex, true) ? battler.zmoves[moveIndex] : battler.moves[moveIndex]
    name = getMoveName(move.move)
    name = "Z-" + name if zmove && battler.pbCompatibleZMoveFromMove?(moveIndex, true) && move.category == :status && ![:EXTREMEEVOBOOST, :ELYSIANSHIELD, :CHTHONICMALADY, :DOMAINSHIFT].include?(move.move)
    secondtype = move.getSecondaryType(battler)
    secondtypephrase = ""
    ppphrase = ""
    fieldboostphrase = ""
    if !secondtype.nil? && move.move != :FLYINGPRESS && battler.battle.FE == :RAINBOW
      secondtypephrase = sprintf(" and a random")
    elsif !secondtype.nil? && move.move != :FLYINGPRESS && battler.battle.FE == :CRYSTALCAVERN
      secondtypephrase = sprintf(" and a crystal")
    elsif !secondtype.nil? && !secondtype.include?(move.pbType(battler))
      for i in 0...secondtype.length
        secondtypephrase = secondtypephrase + sprintf(" and %s", secondtype[i].name)
      end
    end
    if !zmove
      ppphrase = sprintf(", %d out of %d pp left", move.pp, move.totalpp)
    end
    if pbFieldNotesBattle(move) == 1
      fieldboostphrase = ", field-boosted"
    elsif pbFieldNotesBattle(move) == 2
      fieldboostphrase = ", field-diminished"
    end
    tts(sprintf("%s, %s%s type%s%s", name, move.pbType(battler).name, secondtypephrase, ppphrase, fieldboostphrase))
  end

  def pbDrawMoveDetails(battler, moveIndex, zmove, new: false)
    pbDisposeMoveDetails unless new

    move = zmove && battler.pbCompatibleZMoveFromMove?(moveIndex, true) ? battler.zmoves[moveIndex] : battler.moves[moveIndex]
    moveIsRegularStatusZMove = zmove && battler.pbCompatibleZMoveFromMove?(moveIndex, true) && move.category == :status && ![:EXTREMEEVOBOOST, :ELYSIANSHIELD, :CHTHONICMALADY, :DOMAINSHIFT].include?(move.move)
    cattype = { :physical => 0, :special => 1, :status => 2 }[move.category]
    powstring = move.basedamage <= 1 ? (move.basedamage == 0 ? "---" : "???") : move.basedamage.to_s
    accstring = move.accuracy == 0 ? "---" : move.accuracy.to_s
    desc = moveIsRegularStatusZMove ? getStatusZMoveDesc(move.move) : getMoveDesc(move.move)

    @mdviewport = Viewport.new(0, 134, Graphics.width, Graphics.height - 96)
    @mdviewport.z = 999999
    @sprites["card"] = IconSprite.new(0, 0, @mdviewport)
    @sprites["card"].setBitmap("Graphics/Pictures/Battle/battleMoveDetails")
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height - 230, @mdviewport)
    overlay = @sprites["overlay"].bitmap
    pbSetSystemFont(overlay)
    baseForDarkBG = Color.new(248, 248, 248)
    shadowForDarkBG = Color.new(104, 104, 104)
    baseForLightBG = Color.new(64, 64, 64)
    shadowForLightBG = Color.new(176, 176, 176)
    textpos = [
      [_INTL(move.name), 8, 20, 0, baseForDarkBG, shadowForDarkBG],
      [_INTL("CATEGORY"), 8, 56, 0, baseForDarkBG, shadowForDarkBG],
      [_INTL("POWER"), 8, 88, 0, baseForDarkBG, shadowForDarkBG],
      [_INTL("ACCURACY"), 8, 120, 0, baseForDarkBG, shadowForDarkBG],
      [_INTL(powstring), 142, 88, 0, baseForLightBG, shadowForLightBG],
      [_INTL(accstring), 142, 120, 0, baseForLightBG, shadowForLightBG]
    ]
    pbDrawTextPositions(overlay, textpos)
    @sprites["category"] = IconSprite.new(128, 58, @mdviewport)
    @sprites["category"].setBitmap("Graphics/Pictures/category")
    @sprites["category"].src_rect.set(0, cattype * 28, 64, 28)
    drawTextEx(overlay, 210, 23, Graphics.width - 218, 4, desc, baseForLightBG, shadowForLightBG)

    ttsString = ""
    ttsString += (moveIsRegularStatusZMove ? "Z-" + getMoveName(move.move) : getMoveName(move.move)) + ", " if new
    ttsString += move.category.to_s.capitalize + ", "
    ttsString += (move.basedamage == 1 ? "Unknown" : move.basedamage.to_s) + " power, " if move.category != :status
    ttsString += (move.accuracy == 0 ? "Perfect" : move.accuracy.to_s) + " accuracy, "
    ttsString += desc
    tts(ttsString)
  end

  def pbDisposeMoveDetails
    pbDisposeSprite(@sprites, "card")
    pbDisposeSprite(@sprites, "overlay")
    pbDisposeSprite(@sprites, "category")
    @mdviewport.dispose
  end

  def pbFightMenuEncore(index, encored_move)
    pbShowWindow(FIGHTBOX)
    cw = @sprites["fightwindow"]
    battler = @battle.battlers[index]
    cw.battler = battler
    cw.setIndex(encored_move)
    pbFrameUpdate(cw, true)
    Graphics.update
    Input.update
  end

  # Use this method to display the inventory
  # The return value is the item chosen, or 0 if the choice was canceled.
  def pbItemMenu(index)
    ret = nil
    retindex = -1
    endscene = true

    posmod = @battle.pbOwnedByAIPartner?(index) ? 6 : 0
    oldsprites = pbFadeOutAndHide(@sprites)
    itemscene = PokemonBag_Scene.new
    itemscene.pbStartScene($PokemonBag)
    loop do
      item = itemscene.pbChooseItem
      break if item.nil?

      usetype = $cache.items[item].checkFlag?(:noUseInBattle) ? 0 : pbGetPocket(item)
      cmdUse = -1
      commands = []
      if usetype == 0
        commands[commands.length] = _INTL("Cancel")
      else
        commands[cmdUse = commands.length] = _INTL("Use")
        commands[commands.length] = _INTL("Cancel")
      end
      itemname = getItemName(item)
      command = itemscene.pbShowCommands(_INTL("{1} is selected.", itemname), commands)
      if cmdUse >= 0 && command == cmdUse
        if $game_switches[:No_Items_Password] == true && (usetype == 1 || usetype == 2 || usetype == 5)
          Kernel.pbMessage("The 'No Items' password is on, so items can't be used in battle.")
        elsif usetype != 3 && !$cache.items[item].checkFlag?(:battleitem)
          modparty = []
          for i in posmod...(posmod + 6)
            modparty.push(@battle.party1[@battle.partyorder[i]])
          end
          pkmnlist = PokemonScreen_Scene.new
          pkmnscreen = PokemonScreen.new(pkmnlist, modparty)
          itemscene.pbEndScene
          pkmnscreen.pbStartScene(_INTL("Use on which Pokémon?"), @battle.doublebattle)
          activecmd = pkmnscreen.pbChoosePokemon
          pkmnid = @battle.partyorder[activecmd + posmod]
          if activecmd != -1 && !pbCanUseBattleItem(pkmnid, item, pkmnscreen)
          else
            if activecmd >= 0 && pkmnid >= 0 && ItemHandlers.hasBattleUseOnPokemon(item)
              pkmnlist.pbEndScene
              ret = item
              retindex = pkmnid
              endscene = false
              break
            end
          end
          pkmnlist.pbEndScene
          itemscene.pbStartScene($PokemonBag)
        else
          if ItemHandlers.hasBattleUseOnBattler(item)
            ret = item
            retindex = index
            break
          end
        end
      end
    end
    if !ret.nil?
      pbConsumeItemInBattle($PokemonBag, ret)
    end
    itemscene.pbEndScene if endscene
    pbFadeInAndShow(@sprites, oldsprites)
    return [ret, retindex]
  end

  # Tests whether or not the battle item will have any effect
  def pbCanUseBattleItem(pkmnid, item, pkmnscreen)
    pokemon = @battle.party1[pkmnid]
    battler = false
    for i in @battle.battlers
      moncheck = i.pokemon
      if pokemon == moncheck
        battler = i
      end
    end
    if battler && battler.effects[:SkyDrop]
      return false
    end
    if battler && battler.effects[:Embargo] > 0
      return false
    end
    return true if pokemon.hp < pokemon.totalhp && pokemon.hp > 0 && PBStuff::HPITEMS.include?(item)
    return true if pokemon.status == :POISON && PBStuff::POISONITEMS.include?(item)
    return true if pokemon.status == :PARALYSIS && PBStuff::PARAITEMS.include?(item)
    return true if pokemon.status == :BURN && PBStuff::BURNITEMS.include?(item)
    return true if pokemon.status == :SLEEP && PBStuff::SLEEPITEMS.include?(item)
    return true if pokemon.status == :FROZEN && PBStuff::FREEZEITEMS.include?(item)
    return true if pokemon.status == :PETRIFIED && PBStuff::PETRIFYITEMS.include?(item)
    return true if battler && battler.effects[:Confusion] > 0 && PBStuff::CONFUITEMS.include?(item)
    return true if pokemon.hp <= 0 && PBStuff::REVIVEITEMS.include?(item)
    return true if battler && battler.effects[:Attract] >= 0 && PBStuff::INFATUATIONITEMS.include?(item)

    if PBStuff::PPITEMS.include?(item)
      ppcheck = false
      movecheck = false
      for i in pokemon.moves
        next if i.pp == i.totalpp

        movecheck = true
        break
      end
      if movecheck
        if ((item == :ETHER) || (item == :LEPPABERRY))
          move = pbChooseMove(pokemon, _INTL("Restore which move?"))
          if move >= 0
            if pbBattleRestorePP(pokemon, battler, move, 10) == 0
              ppcheck = false
              pkmnscreen.pbDisplay(_INTL("It won't have any effect."))
            else
              return true # ppcheck=true
            end
          else
            ppcheck = false
          end
        elsif (item == :MAXETHER)
          move = pbChooseMove(pokemon, _INTL("Restore which move?"))
          if move >= 0
            if pbBattleRestorePP(pokemon, battler, move, pokemon.moves[move].totalpp - pokemon.moves[move].pp) == 0
              ppcheck = false
              pkmnscreen.pbDisplay(_INTL("It won't have any effect."))
            else
              return true # ppcheck=true
            end
          else
            ppcheck = false
          end
        else
          ppcheck = true
        end
      else
        pkmnscreen.pbDisplay(_INTL("It won't have any effect."))
      end
      return ppcheck
    end
    pkmnscreen.pbDisplay(_INTL("It won't have any effect."))
    return false
  end

  # Called whenever a Pokémon should forget a move.  It should return -1 if the
  # selection is canceled, or 0 to 3 to indicate the move to forget.  The function
  # should not allow HM moves to be forgotten.
  def pbForgetMove(pokemon, moveToLearn)
    ret = -1
    pbFadeOutIn(99999) {
      scene = PokemonSummaryScene.new
      screen = PokemonSummary.new(scene)
      ret = screen.pbStartForgetScreen([pokemon], 0, moveToLearn)
    }
    return ret
  end

  # Called whenever a Pokémon needs one of its moves chosen. Used for Ether.
  def pbChooseMove(pokemon, message)
    ret = -1
    pbFadeOutIn(99999) {
      scene = PokemonSummaryScene.new
      screen = PokemonSummary.new(scene)
      ret = screen.pbStartChooseMoveScreen([pokemon], 0, message)
    }
    return ret
  end

  def pbNameEntry(helptext, pokemon)
    return pbEnterPokemonName(helptext, 0, 12, "", pokemon)
  end

  def pbSelectBattler(index, selectmode = 1)
    numwindows = @battle.doublebattle ? 4 : 2
    for i in 0...numwindows
      sprite = @sprites["battlebox#{i}"]
      next if !sprite

      sprite.selected = (i == index) ? selectmode : 0
      sprite = @sprites["pokemon#{i}"]
      next if !sprite

      sprite.selected = (i == index) ? selectmode : 0
    end
  end

  def pbFirstTarget(index)
    for i in 0...4
      if i != index && !@battle.battlers[i].isFainted? &&
         @battle.battlers[index].pbIsOpposing?(i)
        return i
      end
    end
    return -1
  end

  def pbAcupressureTarget(index)
    for i in 0...4
      if (index & 1) == (i & 1) && !@battle.battlers[i].isFainted?
        !@battle.battlers[index].pbIsOpposing?(i)
        return i
      end
    end
    return -1
  end

  def pbUpdateSelected(index)
    numwindows = @battle.doublebattle ? 4 : 2
    for i in 0...numwindows
      next if !@sprites["battlebox#{i}"]
      next if !@sprites["pokemon#{i}"]

      if i == index
        @sprites["battlebox#{i}"].selected = 2
        @sprites["pokemon#{i}"].selected = 2
      else
        @sprites["battlebox#{i}"].selected = 0
        @sprites["pokemon#{i}"].selected = 0
      end
      @sprites["battlebox#{i}"].update
      @sprites["pokemon#{i}"].update
    end
  end

  # Use this method to make the player choose a target
  # for certain moves in double battles.
  def pbChooseTarget(index)
    pbShowWindow(FIGHTBOX)
    curwindow = pbFirstTarget(index)
    if curwindow == -1
      raise RuntimeError.new(_INTL("No targets somehow..."))
    end
    tts(@battle.battlers[curwindow].name, true) if !@battle.battlers[curwindow].isFainted?

    loop do
      pbGraphicsUpdate
      Input.update
      pbUpdateSelected(curwindow)
      if Input.trigger?(Input::C)
        pbUpdateSelected(-1)
        return curwindow
      end
      if Input.trigger?(Input::B)
        pbUpdateSelected(-1)
        return -1
      end
      if curwindow >= 0
        if Input.trigger?(Input::RIGHT) || Input.trigger?(Input::DOWN)
          loop do
            newcurwindow = 3 if curwindow == 0
            newcurwindow = 1 if curwindow == 3
            newcurwindow = 2 if curwindow == 1
            newcurwindow = 0 if curwindow == 2
            curwindow = newcurwindow
            next if curwindow == index
            break if !@battle.battlers[curwindow].isFainted?
          end
          tts(@battle.battlers[curwindow].name, true) if !@battle.battlers[curwindow].isFainted?
        elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::UP)
          loop do
            newcurwindow = 2 if curwindow == 0
            newcurwindow = 1 if curwindow == 2
            newcurwindow = 3 if curwindow == 1
            newcurwindow = 0 if curwindow == 3
            curwindow = newcurwindow
            next if curwindow == index
            break if !@battle.battlers[curwindow].isFainted?
          end
          tts(@battle.battlers[curwindow].name, true) if !@battle.battlers[curwindow].isFainted?
        end
      end
    end
  end

  def pbChooseTargetOneSide(index, target)
    pbShowWindow(FIGHTBOX)
    curwindow = target == :SingleOpposing ? pbFirstTarget(index) : pbAcupressureTarget(index)
    if curwindow == -1
      raise RuntimeError.new(_INTL("No targets somehow..."))
    end

    loop do
      pbGraphicsUpdate
      Input.update
      pbUpdateSelected(curwindow)
      if Input.trigger?(Input::C)
        pbUpdateSelected(-1)
        return curwindow
      end
      if Input.trigger?(Input::B)
        pbUpdateSelected(-1)
        return -1
      end
      if curwindow >= 0
        if Input.trigger?(Input::RIGHT) || Input.trigger?(Input::DOWN)
          loop do
            newcurwindow = 2 if curwindow == 0
            newcurwindow = 1 if curwindow == 3
            newcurwindow = 3 if curwindow == 1
            newcurwindow = 0 if curwindow == 2
            curwindow = newcurwindow
            break if !@battle.battlers[curwindow].isFainted?
          end
          tts(@battle.battlers[curwindow].name) if !@battle.battlers[curwindow].isFainted?
        elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::UP)
          loop do
            newcurwindow = 2 if curwindow == 0
            newcurwindow = 0 if curwindow == 2
            newcurwindow = 3 if curwindow == 1
            newcurwindow = 1 if curwindow == 3
            curwindow = newcurwindow
            break if !@battle.battlers[curwindow].isFainted?
          end
          tts(@battle.battlers[curwindow].name) if !@battle.battlers[curwindow].isFainted?
        end
      end
    end
  end

  def pbChooseBallTarget(index)
    curwindow = pbFirstTarget(index)
    if curwindow == -1
      raise RuntimeError.new(_INTL("No targets somehow..."))
    end

    loop do
      pbGraphicsUpdate
      Input.update
      pbUpdateSelected(curwindow)
      if Input.trigger?(Input::C)
        pbUpdateSelected(-1)
        return curwindow
      end
      if curwindow >= 0
        if Input.trigger?(Input::RIGHT) || Input.trigger?(Input::DOWN)
          loop do
            newcurwindow = 2 if curwindow == 0
            newcurwindow = 1 if curwindow == 3
            newcurwindow = 3 if curwindow == 1
            newcurwindow = 0 if curwindow == 2
            curwindow = newcurwindow
            break if !@battle.battlers[curwindow].isFainted?
          end
          tts(@battle.battlers[curwindow].name) if !@battle.battlers[curwindow].isFainted?
        elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::UP)
          loop do
            newcurwindow = 2 if curwindow == 0
            newcurwindow = 0 if curwindow == 2
            newcurwindow = 3 if curwindow == 1
            newcurwindow = 1 if curwindow == 3
            curwindow = newcurwindow
            break if !@battle.battlers[curwindow].isFainted?
          end
          tts(@battle.battlers[curwindow].name) if !@battle.battlers[curwindow].isFainted?
        end
      end
    end
  end

  def pbSwitch(index, lax, cancancel)
    party = @battle.pbParty(index)
    partypos = @battle.partyorder
    ret = -1
    pbShowWindow(BLANK)
    pbSetMessageMode(true)
    modparty = []
    posmod = @battle.pbOwnedByAIPartner?(index) ? 6 : 0
    for i in posmod...(posmod + 6)
      modparty.push(party[partypos[i]])
    end
    visiblesprites = pbFadeOutAndHide(@sprites)
    scene = PokemonScreen_Scene.new
    @switchscreen = PokemonScreen.new(scene, modparty)
    @switchscreen.pbStartScene(_INTL("Choose a Pokémon."), @battle.doublebattle && !@battle.fullparty1)
    tts("Choose a Pokémon.")
    loop do
      scene.pbSetHelpText(_INTL("Choose a Pokémon."))
      activecmd = @switchscreen.pbChoosePokemon(shortcut_keys: true)
      if cancancel && activecmd == -1
        ret = -1
        break
      end
      if activecmd.is_a?(Array) && activecmd[0] == 3 # Summary
        scene.pbSummary(activecmd[1])
        next
      end
      if activecmd >= 0 && !party[partypos[activecmd + posmod]].nil?
        commands = []
        cmdShift = -1
        cmdSummary = -1
        pkmnindex = partypos[activecmd + posmod]
        commands[cmdShift = commands.length] = _INTL("Switch In") if !party[pkmnindex].isEgg?
        commands[cmdSummary = commands.length] = _INTL("Summary")
        commands[commands.length] = _INTL("Cancel")
        command = scene.pbShowCommands(_INTL("Do what with {1}?", party[pkmnindex].name), commands)
        if cmdShift >= 0 && command == cmdShift
          canswitch = lax ? @battle.pbCanSwitchLax?(index, pkmnindex, true) : @battle.pbCanSwitch?(index, pkmnindex, true)
          if canswitch
            ret = pkmnindex
            break
          end
        elsif cmdSummary >= 0 && command == cmdSummary
          scene.pbSummary(activecmd)
        end
      end
    end
    @switchscreen.pbEndScene
    @switchscreen = nil
    pbShowWindow(BLANK)
    pbSetMessageMode(false)
    # back to main battle screen
    pbFadeInAndShow(@sprites, visiblesprites)
    @battle.logSwitch(index, ret) if ret >= 0
    return ret
  end

  def pbDamageAnimation(mons, effectiveness, quick: false)
    return if mons == []

    mons = [mons] unless mons.is_a?(Array)

    @briefmessage = false
    (quick ? 0 : 6).times do
      pbGraphicsUpdate
      Input.update
    end

    $Settings.audiotype = 0 if !$Settings.audiotype
    if $Settings.audiotype != 0 || mons.length > 1
      case effectiveness
        when 0 then pbSEPlay("normaldamage")
        when 1 then pbSEPlay("notverydamage")
        when 2 then pbSEPlay("superdamage")
      end
    else
      pkmn = mons[0]
      case effectiveness
        when 0 then @battle.pbIsOpposing?(pkmn.index) ? pbSEPlay("normaldamage_R") : pbSEPlay("normaldamage_L")
        when 1 then @battle.pbIsOpposing?(pkmn.index) ? pbSEPlay("notverydamage_R") : pbSEPlay("notverydamage_L")
        when 2 then @battle.pbIsOpposing?(pkmn.index) ? pbSEPlay("superdamage_R") : pbSEPlay("superdamage_L")
      end
    end

    blinksprites = []
    sprites = []
    mons.each do |pkmn|
      pkmnsprite = @sprites["pokemon#{pkmn.index}"]
      shadowsprite = @sprites["shadow#{pkmn.index}"]
      sprite = @sprites["battlebox#{pkmn.index}"]
      sprite.selected = 2
      sprites.push [sprite, sprite.visible]
      blinksprites.push pkmnsprite
      blinksprites.push shadowsprite if shadowsprite.visible
    end

    8.times do
      blinksprites.each { |s| s.visible = !s.visible }
      4.times do
        pbGraphicsUpdate
        Input.update
        sprites.each { |pair| pair[0].update }
      end
    end

    sprites.each do |pair|
      sprite, oldvisible = pair
      sprite.selected = 0
      sprite.visible = oldvisible
    end
  end

  # This method is called whenever a Pokémon's HP changes.
  # Used to animate the HP bar.
  # Accepts an array with the following format: [[pkmn1, oldhp], [pkmn2, oldhp]]
  def pbHPChanged(mons, anim = false)
    @briefmessage = false
    sprites = []
    mons.each do |pair|
      pkmn, oldhp = pair
      hpchange = pkmn.hp - oldhp
      if hpchange < 0
        hpchange = -hpchange
        PBDebug.log("[#{pkmn.pbThis} lost #{hpchange} HP, now has #{pkmn.hp} HP]") if $INTERNAL
      else
        PBDebug.log("[#{pkmn.pbThis} gained #{hpchange} HP, now has #{pkmn.hp} HP]") if $INTERNAL
      end
      if anim && @battle.battlescene
        if pkmn.hp > oldhp
          pbCommonAnimation("HealthUp", pkmn, nil)
        elsif pkmn.hp < oldhp
          pbCommonAnimation("HealthDown", pkmn, nil)
        end
      end
      sprite = @sprites["battlebox#{pkmn.index}"]
      sprite.animateHP(oldhp, pkmn.hp)
      sprites.push sprite
    end

    while sprites.any? { |sprite| sprite.animatingHP }
      pbGraphicsUpdate
      Input.update
      pbFrameUpdate(nil)
      sprites.each { |sprite| sprite.update }
    end
  end

  # This method is called whenever a Pokémon faints.
  def pbFainted(pkmn)
    # frames=pbCryFrameLength(pkmn.pokemon)
    pbPlayCry(pkmn.pokemon)
    # frames.times do
    #  pbGraphicsUpdate
    #  Input.update
    # end
    @sprites["shadow#{pkmn.index}"].visible = false
    pkmnsprite = @sprites["pokemon#{pkmn.index}"]
    ycoord = 0
    if @battle.doublebattle
      ycoord = PBScene::PLAYERBATTLERD1_Y if pkmn.index == 0
      ycoord = PBScene::FOEBATTLERD1_Y if pkmn.index == 1
      ycoord = PBScene::PLAYERBATTLERD2_Y if pkmn.index == 2
      ycoord = PBScene::FOEBATTLERD2_Y if pkmn.index == 3
    else
      if @battle.pbIsOpposing?(pkmn.index)
        ycoord = PBScene::FOEBATTLER_Y
      else
        ycoord = PBScene::PLAYERBATTLER_Y
      end
    end
    @battle.pbIsOpposing?(pkmn.index) ? pbSEPlay("faint#{$Settings.audiotype == 0 ? "_R" : ""}") : pbSEPlay("faint#{$Settings.audiotype == 0 ? "_L" : ""}")
    heightsave = pkmnsprite.src_rect.height
    loop do
      pkmnsprite.y += 8
      if pkmnsprite.y - pkmnsprite.oy + pkmnsprite.src_rect.height >= ycoord
        pkmnsprite.src_rect.height = ycoord - pkmnsprite.y + pkmnsprite.oy
      end
      pbGraphicsUpdate
      Input.update
      break if pkmnsprite.y >= ycoord
    end
    pkmnsprite.visible = false
    pkmnsprite.src_rect.height = heightsave
    8.times do
      @sprites["battlebox#{pkmn.index}"].opacity -= 32
      pbGraphicsUpdate
      Input.update
    end
    @sprites["battlebox#{pkmn.index}"].visible = false
    pkmn.pbResetForm
  end

  def pbVanishSprite(pkmn)
    pkmn.vanished = true
    pkmnsprite = @sprites["pokemon#{pkmn.index}"]
    pkmnsprite.opacity -= 1000
    pbGraphicsUpdate
    Input.update
  end

  def pbUnVanishSprite(pkmn, fade = true)
    pkmn.vanished = false
    @battle.pbCommonAnimation("Fade in", pkmn, nil) if fade
    pkmnsprite = @sprites["pokemon#{pkmn.index}"]
    pkmnsprite.opacity += 1000
    pbGraphicsUpdate
    Input.update
  end

  def pbSyncronousVanish(array)
    return if !array || array.length == 0

    10.times do
      array.each { |pkmn| @sprites["pokemon#{pkmn.index}"].opacity -= 30 }
      pbGraphicsUpdate
      Input.update
    end
  end

  def pbSyncronousUnvanish(array)
    return if !array || array.length == 0

    10.times do
      array.each { |pkmn| @sprites["pokemon#{pkmn.index}"].opacity += 30 }
      pbGraphicsUpdate
      Input.update
    end
  end

  def pbSubstituteSprite(pkmn, back)
    pkmnsprite = @sprites["pokemon#{pkmn.index}"]
    pkmnsprite.setPokemonBitmapSpecies("substitute", pkmn.species, back)
    pkmnsprite.opacity += 1000
  end

  def pbUnSubstituteSprite(pkmn, back)
    pkmnsprite = @sprites["pokemon#{pkmn.index}"]
    pkmnsprite.setPokemonBitmapSpecies(pkmn.battlerToPokemon, pkmn.species, back)
    pkmnsprite.opacity += 1000
  end

  # Use this method to choose a command for the enemy.
  def pbChooseEnemyCommand
    @battle.ai.processAIturn
  end

  # Use this method to choose a new Pokémon for the enemy
  # The enemy's party is guaranteed to have at least one choosable member.
  def pbChooseNewEnemy(index, party)
    $ai_log_data[index].reset(@battle.battlers[index])
    ret = @battle.ai.pbDefaultChooseNewEnemy(index, party)
    $ai_log_data[index].logAISwitching() if @battle.ai.aimondata[index].skill >= PokeBattle_AI::MEDIUMSKILL
    return ret
  end

  # This method is called when the player wins a wild Pokémon battle.
  # This method can change the battle's music for example.
  def pbWildBattleSuccess
    pbBGMPlay(pbGetWildVictoryME())
  end

  # This method is called when the player wins a Trainer battle.
  # This method can change the battle's music for example.
  def pbTrainerBattleSuccess
    pbBGMPlay(pbGetTrainerVictoryME(@battle.opponent))
  end

  def pbEXPBar(pokemon, battler, startexp, endexp, tempexp1, tempexp2)
    if battler
      @sprites["battlebox#{battler.index}"].refreshExpLevel
      exprange = (endexp - startexp)
      startexplevel = 0
      endexplevel = 0
      if exprange != 0
        startexplevel = (tempexp1 - startexp) * PBScene::EXPGAUGESIZE / exprange
        endexplevel = (tempexp2 - startexp) * PBScene::EXPGAUGESIZE / exprange
      end
      @sprites["battlebox#{battler.index}"].animateEXP(startexplevel, endexplevel)
      while @sprites["battlebox#{battler.index}"].animatingEXP
        pbGraphicsUpdate
        Input.update
        @sprites["battlebox#{battler.index}"].update
      end
    end
  end

  def pbShowPokedex(species)
    pbFadeOutIn(99999) {
      scene = PokemonPokedexScene.new
      screen = PokemonPokedex.new(scene)
      screen.pbDexEntry(species)
    }
  end

  def pbChangeSpecies(attacker, species, form)
    pkmn = @sprites["pokemon#{attacker.index}"]
    shadow = @sprites["shadow#{attacker.index}"]
    back = !@battle.pbIsOpposing?(attacker.index)
    pkmn.setPokemonBitmapSpecies(attacker.pokemon, species, back)
    pkmn.x = -pkmn.bitmap.width / 2
    pkmn.y = adjustBattleSpriteY(pkmn, species, form, attacker.index)
    if @battle.doublebattle
      case attacker.index
        when 0
          pkmn.x += @battle.sosbattle == 3 ? PBScene::PLAYERBATTLER_X : PBScene::PLAYERBATTLERD1_X
          pkmn.y += PBScene::PLAYERBATTLERD1_Y
        when 1
          pkmn.x += PBScene::FOEBATTLERD1_X
          pkmn.y += PBScene::FOEBATTLERD1_Y
        when 2
          pkmn.x += PBScene::PLAYERBATTLERD2_X
          pkmn.y += PBScene::PLAYERBATTLERD2_Y
        when 3
          pkmn.x += PBScene::FOEBATTLERD2_X
          pkmn.y += PBScene::FOEBATTLERD2_Y
      end
    else
      pkmn.x += PBScene::PLAYERBATTLER_X if attacker.index == 0
      pkmn.y += PBScene::PLAYERBATTLER_Y if attacker.index == 0
      pkmn.x += PBScene::FOEBATTLER_X if attacker.index == 1
      pkmn.y += PBScene::FOEBATTLER_Y if attacker.index == 1
    end
    if shadow && !back
      shadow.visible = showShadow?(species, form)
    end
  end

  def pbChangePokemon(attacker, pokemon)
    return if attacker.effects[:Substitute] != 0

    pkmn = @sprites["pokemon#{attacker.index}"]
    shadow = @sprites["shadow#{attacker.index}"]
    back = !@battle.pbIsOpposing?(attacker.index)
    pkmn.setPokemonBitmap(pokemon, back)
    pkmn.x = -pkmn.bitmap.width / 2
    pkmn.y = adjustBattleSpriteY(pkmn, pokemon.species, pokemon.form, attacker.index)
    if @battle.doublebattle
      case attacker.index
        when 0
          pkmn.x += @battle.sosbattle == 3 ? PBScene::PLAYERBATTLER_X : PBScene::PLAYERBATTLERD1_X
          pkmn.y += PBScene::PLAYERBATTLERD1_Y
        when 1
          pkmn.x += PBScene::FOEBATTLERD1_X
          pkmn.y += PBScene::FOEBATTLERD1_Y
        when 2
          pkmn.x += PBScene::PLAYERBATTLERD2_X
          pkmn.y += PBScene::PLAYERBATTLERD2_Y
        when 3
          pkmn.x += PBScene::FOEBATTLERD2_X
          pkmn.y += PBScene::FOEBATTLERD2_Y
      end
    else
      pkmn.x += PBScene::PLAYERBATTLER_X if attacker.index == 0
      pkmn.y += PBScene::PLAYERBATTLER_Y if attacker.index == 0
      pkmn.x += PBScene::FOEBATTLER_X if attacker.index == 1
      pkmn.y += PBScene::FOEBATTLER_Y if attacker.index == 1
    end
    if shadow && !back
      shadow.visible = showShadow?(pokemon.species, pokemon.form)
    end
  end

  def pbSaveShadows
    shadows = []
    for i in 0...4
      s = @sprites["shadow#{i}"]
      shadows[i] = s ? s.visible : false
      s.visible = false if s
    end
    yield
    for i in 0...4
      s = @sprites["shadow#{i}"]
      s.visible = shadows[i] if s
    end
  end

  def pbFindAnimation(move, userIndex, hitnum)
    begin
      noflip = false
      if (userIndex & 1) == 0 # On player's side
        anim = $cache.move2anim[0].fetch(move.intern)
      else # On opposing side
        anim = $cache.move2anim[1].fetch(move.intern) if $cache.move2anim[1].key?(move.intern)
        noflip = true if anim
        anim = $cache.move2anim[0].fetch(move.intern) if !anim
      end
      return [anim + hitnum, noflip] if move == :BONEMERANG
      return [anim, noflip] if anim

      anim = $cache.move2anim[0].fetch(:TACKLE)
      return [anim, false] if anim
    rescue
      return nil
    end
    return nil
  end

  def pbCommonAnimation(animname, user = nil, target = nil, hitnum = 0)
    unless defined?(user.vanished).nil?
      return if user.vanished
    end
    unless defined?(target.vanished).nil?
      return if target.vanished
    end
    $cache.animations = load_data("Data/battleanims.dat") if !$cache.animations
    for i in 0...$cache.animations.length
      if $cache.animations[i] && $cache.animations[i].name == "Common:" + animname
        pbAnimationCore($cache.animations[i], user, (target != nil) ? target : user)
        return
      end
    end
  end

  def pbAnimation(move, user, target, hitnum = 0)
    return if move.nil?

    if move.is_a? PokeBattle_Move
      move = move.move
    elsif !move.is_a? Symbol
      move = move.upcase.strip.gsub(/[^0-9a-z]/i, '')
    end
    animid = pbFindAnimation(move, user.index, hitnum)
    return if !animid

    anim = animid[0]
    autoopp = user.index.odd?
    $cache.animations = load_data("Data/battleanims.dat") if !$cache.animations
    pbSaveShadows {
      if animid[1] # On opposing side and using OppMove animation
        pbAnimationCore($cache.animations[anim], target, user, move, true)
      else         # On player's side, and/or using Move animation
        pbAnimationCore($cache.animations[anim], user, target, move, autoopp)
      end
    }
  end

  def pbAnimationCore(animation, user, target, move = nil, oppmove = false)
    return if !animation

    @briefmessage = false
    usersprite = (user) ? @sprites["pokemon#{user.index}"] : nil
    targetsprite = (target) ? @sprites["pokemon#{target.index}"] : nil
    olduserx = usersprite ? usersprite.x : 0
    oldusery = usersprite ? usersprite.y : 0
    oldtargetx = targetsprite ? targetsprite.x : 0
    oldtargety = targetsprite ? targetsprite.y : 0
    if !targetsprite
      target = user if !target
      animplayer = PBAnimationPlayerX.new(animation, user, target, self, move, oppmove)
      userwidth = (!usersprite || !usersprite.bitmap || usersprite.bitmap.disposed?) ? 128 : usersprite.bitmap.width
      userheight = (!usersprite || !usersprite.bitmap || usersprite.bitmap.disposed?) ? 128 : usersprite.bitmap.height
      animplayer.setLineTransform(
        PBScene::FOCUSUSER_X, PBScene::FOCUSUSER_Y,
        PBScene::FOCUSTARGET_X, PBScene::FOCUSTARGET_Y,
        olduserx + (userwidth / 2), oldusery + (userheight / 2),
        olduserx + (userwidth / 2), oldusery + (userheight / 2)
      )
    else
      animplayer = PBAnimationPlayerX.new(animation, user, target, self, move, oppmove)
      userwidth = (!usersprite || !usersprite.bitmap || usersprite.bitmap.disposed?) ? 128 : usersprite.bitmap.width
      userheight = (!usersprite || !usersprite.bitmap || usersprite.bitmap.disposed?) ? 128 : usersprite.bitmap.height
      targetwidth = (!targetsprite.bitmap || targetsprite.bitmap.disposed?) ? 128 : targetsprite.bitmap.width
      targetheight = (!targetsprite.bitmap || targetsprite.bitmap.disposed?) ? 128 : targetsprite.bitmap.height
      animplayer.setLineTransform(
        PBScene::FOCUSUSER_X, PBScene::FOCUSUSER_Y,
        PBScene::FOCUSTARGET_X, PBScene::FOCUSTARGET_Y,
        olduserx + (userwidth / 2), oldusery + (userheight / 2),
        oldtargetx + (targetwidth / 2), oldtargety + (targetheight / 2)
      )
    end
    animplayer.start
    while animplayer.playing?
      animplayer.update
      pbGraphicsUpdate
      Input.update
    end
    pbSyncronousUnvanish(animplayer.hide_partners)
    usersprite.ox = 0 if usersprite
    usersprite.oy = 0 if usersprite
    usersprite.x = olduserx if usersprite
    usersprite.y = oldusery if usersprite
    targetsprite.ox = 0 if targetsprite
    targetsprite.oy = 0 if targetsprite
    targetsprite.x = oldtargetx if targetsprite
    targetsprite.y = oldtargety if targetsprite
    if animplayer.targetSwitch
      animplayer.realtargetsprite.x = animplayer.realtargetOldCoords[0]
      animplayer.realtargetsprite.y = animplayer.realtargetOldCoords[1]
      animplayer.realtargetsprite.ox = animplayer.realtargetOldCoords[2]
      animplayer.realtargetsprite.oy = animplayer.realtargetOldCoords[3]
    end
    if animplayer.partnerbs
      animplayer.animpartner.x = animplayer.partnerOldCoords[0]
      animplayer.animpartner.y = animplayer.partnerOldCoords[1]
      animplayer.animpartner.ox = animplayer.partnerOldCoords[2]
      animplayer.animpartner.oy = animplayer.partnerOldCoords[3]
    end
    if animplayer.allmonbs
      animplayer.target1sprite.x = animplayer.target1OldCoords[0]
      animplayer.target1sprite.y = animplayer.target1OldCoords[1]
      animplayer.target1sprite.ox = animplayer.target1OldCoords[2]
      animplayer.target1sprite.oy = animplayer.target1OldCoords[3]
      if animplayer.target2sprite
        animplayer.target2sprite.x = animplayer.target2OldCoords[0]
        animplayer.target2sprite.y = animplayer.target2OldCoords[1]
        animplayer.target2sprite.ox = animplayer.target2OldCoords[2]
        animplayer.target2sprite.oy = animplayer.target2OldCoords[3]
      end
    end
    animplayer.dispose
  end

  def pbLevelUp(pokemon, battler, oldtotalhp, oldattack, olddefense, oldspeed, oldspatk, oldspdef)
    pbTopRightWindow(
      _INTL(
        "Max. HP<r>+{1}\r\nAttack<r>+{2}\r\nDefense<r>+{3}\r\nSp. Atk<r>+{4}\r\nSp. Def<r>+{5}\r\nSpeed<r>+{6}",
        pokemon.totalhp - oldtotalhp, pokemon.attack - oldattack, pokemon.defense - olddefense,
        pokemon.spatk - oldspatk, pokemon.spdef - oldspdef, pokemon.speed - oldspeed
      )
    )
    pbTopRightWindow(
      _INTL(
        "Max. HP<r>{1}\r\nAttack<r>{2}\r\nDefense<r>{3}\r\nSp. Atk<r>{4}\r\nSp. Def<r>{5}\r\nSpeed<r>{6}",
        pokemon.totalhp, pokemon.attack, pokemon.defense, pokemon.spatk, pokemon.spdef, pokemon.speed
      )
    )
  end

  def pbLevelDown(pokemon, battler, oldtotalhp, oldattack, olddefense, oldspeed, oldspatk, oldspdef)
    pbTopRightWindow(
      _INTL(
        "Max. HP<r>-{1}\r\nAttack<r>-{2}\r\nDefense<r>-{3}\r\nSp. Atk<r>-{4}\r\nSp. Def<r>-{5}\r\nSpeed<r>-{6}",
        -1 * (pokemon.totalhp - oldtotalhp), -1 * (pokemon.attack - oldattack), -1 * (pokemon.defense - olddefense),
        -1 * (pokemon.spatk - oldspatk), -1 * (pokemon.spdef - oldspdef), -1 * (pokemon.speed - oldspeed)
      )
    )
    pbTopRightWindow(
      _INTL(
        "Max. HP<r>{1}\r\nAttack<r>{2}\r\nDefense<r>{3}\r\nSp. Atk<r>{4}\r\nSp. Def<r>{5}\r\nSpeed<r>{6}",
        pokemon.totalhp, pokemon.attack, pokemon.defense, pokemon.spatk, pokemon.spdef, pokemon.speed
      )
    )
  end

  def pbThrowAndDeflect(ball, targetBattler)
    @briefmessage = false
    ball = sprintf("Graphics/Pictures/Battle/%s", ball.to_s)
    # sprite
    spriteBall = IconSprite.new(0, 0, @viewport)
    spriteBall.visible = false
    # picture
    pictureBall = PictureEx.new(@sprites["pokemon#{targetBattler}"].z + 1)
    center = getSpriteCenter(@sprites["pokemon#{targetBattler}"])
    # starting positions
    pictureBall.moveVisible(1, true)
    pictureBall.moveName(1, ball)
    pictureBall.moveOrigin(1, PictureOrigin::Center)
    pictureBall.moveXY(0, 1, 10, 180)
    # directives
    pictureBall.moveSE(1, "Audio/SE/throw")
    pictureBall.moveCurve(30, 1, 150, 70, 30 + Graphics.width / 2, 10, center[0], center[1])
    pictureBall.moveAngle(30, 1, -1080)
    pictureBall.moveAngle(0, pictureBall.totalDuration, 0)
    delay = pictureBall.totalDuration
    pictureBall.moveSE(delay, "Audio/SE/balldrop")
    pictureBall.moveXY(20, delay, 0, Graphics.height)
    loop do
      pictureBall.update
      setPictureIconSprite(spriteBall, pictureBall)
      pbGraphicsUpdate
      Input.update
      break if !pictureBall.running?
    end
    spriteBall.dispose
  end

  def pbThrow(ball, shakes, critical, critsuccess, targetBattler, showplayer = false)
    @briefmessage = false
    burst = -1
    $cache.animations = load_data("Data/battleanims.dat") if !$cache.animations
    for i in 0...2
      t = i == 0 ? ball : 0
      for j in 0...$cache.animations.length
        if $cache.animations[j]
          if $cache.animations[j].name == "Common:BallBurst#{t}"
            burst = t if burst < 0
            break
          end
        end
      end
      break if burst >= 0
    end
    pokeballThrow(ball, shakes, critical, critsuccess, targetBattler, self, @battle.battlers[targetBattler], burst, showplayer)
  end

  def pbThrowSuccess
    if !@battle.opponent
      @briefmessage = false
      #      pbMEPlay("Jingle - HMTM")
      #      120.times do
      pbGraphicsUpdate
      Input.update
    end
  end

  def pbHideCaptureBall
    if @sprites["capture"]
      loop do
        break if @sprites["capture"].opacity <= 0

        @sprites["capture"].opacity -= 12
        pbGraphicsUpdate
        Input.update
      end
    end
  end

  def pbThrowBait
    ball = sprintf("Graphics/Pictures/Battle/battleBait")
    armanim = false
    if @sprites["player"].bitmap.width > @sprites["player"].bitmap.height
      armanim = true
    end
    # sprites
    spritePoke = @sprites["pokemon1"]
    spritePlayer = @sprites["player"]
    spriteBall = IconSprite.new(0, 0, @viewport)
    spriteBall.visible = false
    # pictures
    pictureBall = PictureEx.new(spritePoke.z + 1)
    picturePoke = PictureEx.new(spritePoke.z)
    picturePlayer = PictureEx.new(spritePoke.z + 2)
    pokecenter = getSpriteCenter(@sprites["pokemon1"])
    playerpos = [@sprites["player"].x, @sprites["player"].y]
    # starting positions
    pictureBall.moveVisible(1, true)
    pictureBall.moveName(1, ball)
    pictureBall.moveOrigin(1, PictureOrigin::Center)
    pictureBall.moveXY(0, 1, 64, 256)
    picturePoke.moveVisible(1, true)
    picturePoke.moveOrigin(1, PictureOrigin::Center)
    picturePoke.moveXY(0, 1, pokecenter[0], pokecenter[1])
    picturePlayer.moveVisible(1, true)
    picturePlayer.moveName(1, @sprites["player"].name)
    picturePlayer.moveOrigin(1, PictureOrigin::TopLeft)
    picturePlayer.moveXY(0, 1, playerpos[0], playerpos[1])
    # directives
    picturePoke.moveSE(1, "Audio/SE/throw")
    pictureBall.moveCurve(30, 1, 64, 256, Graphics.width / 2, 48, PBScene::FOEBATTLER_X - 48, PBScene::FOEBATTLER_Y)
    pictureBall.moveAngle(30, 1, -720)
    pictureBall.moveAngle(0, pictureBall.totalDuration, 0)
    if armanim
      picturePlayer.moveSrc(1, @sprites["player"].bitmap.height, 0)
      picturePlayer.moveXY(0, 1, playerpos[0] - 14, playerpos[1])
      picturePlayer.moveSrc(4, @sprites["player"].bitmap.height * 2, 0)
      picturePlayer.moveXY(0, 4, playerpos[0] - 12, playerpos[1])
      picturePlayer.moveSrc(8, @sprites["player"].bitmap.height * 3, 0)
      picturePlayer.moveXY(0, 8, playerpos[0] + 20, playerpos[1])
      picturePlayer.moveSrc(16, @sprites["player"].bitmap.height * 4, 0)
      picturePlayer.moveXY(0, 16, playerpos[0] + 16, playerpos[1])
      picturePlayer.moveSrc(40, 0, 0)
      picturePlayer.moveXY(0, 40, playerpos[0], playerpos[1])
    end
    # Show Pokémon jumping before eating the bait
    picturePoke.moveSE(50, "Audio/SE/jump")
    picturePoke.moveXY(8, 50, pokecenter[0], pokecenter[1] - 8)
    picturePoke.moveXY(8, 58, pokecenter[0], pokecenter[1])
    pictureBall.moveVisible(66, false)
    picturePoke.moveSE(66, "Audio/SE/jump")
    picturePoke.moveXY(8, 66, pokecenter[0], pokecenter[1] - 8)
    picturePoke.moveXY(8, 74, pokecenter[0], pokecenter[1])
    # TODO: Show Pokémon eating the bait (pivots at the bottom right corner)
    loop do
      pictureBall.update
      picturePoke.update
      picturePlayer.update
      setPictureIconSprite(spriteBall, pictureBall)
      setPictureSprite(spritePoke, picturePoke)
      setPictureIconSprite(spritePlayer, picturePlayer)
      pbGraphicsUpdate
      Input.update
      break if !pictureBall.running? && !picturePoke.running? && !picturePlayer.running?
    end
    spriteBall.dispose
  end

  def pbThrowRock
    ball = sprintf("Graphics/Pictures/Battle/battleRock")
    anger = sprintf("Graphics/Pictures/Battle/battleAnger")
    armanim = false
    if @sprites["player"].bitmap.width > @sprites["player"].bitmap.height
      armanim = true
    end
    # sprites
    spritePoke = @sprites["pokemon1"]
    spritePlayer = @sprites["player"]
    spriteBall = IconSprite.new(0, 0, @viewport)
    spriteBall.visible = false
    spriteAnger = IconSprite.new(0, 0, @viewport)
    spriteAnger.visible = false
    # pictures
    pictureBall = PictureEx.new(spritePoke.z + 1)
    picturePoke = PictureEx.new(spritePoke.z)
    picturePlayer = PictureEx.new(spritePoke.z + 2)
    pictureAnger = PictureEx.new(spritePoke.z + 1)
    pokecenter = getSpriteCenter(@sprites["pokemon1"])
    playerpos = [@sprites["player"].x, @sprites["player"].y]
    # starting positions
    pictureBall.moveVisible(1, true)
    pictureBall.moveName(1, ball)
    pictureBall.moveOrigin(1, PictureOrigin::Center)
    pictureBall.moveXY(0, 1, 64, 256)
    picturePoke.moveVisible(1, true)
    picturePoke.moveOrigin(1, PictureOrigin::Center)
    picturePoke.moveXY(0, 1, pokecenter[0], pokecenter[1])
    picturePlayer.moveVisible(1, true)
    picturePlayer.moveName(1, @sprites["player"].name)
    picturePlayer.moveOrigin(1, PictureOrigin::TopLeft)
    picturePlayer.moveXY(0, 1, playerpos[0], playerpos[1])
    pictureAnger.moveVisible(1, false)
    pictureAnger.moveName(1, anger)
    pictureAnger.moveXY(0, 1, pokecenter[0] - 56, pokecenter[1] - 48)
    pictureAnger.moveOrigin(1, PictureOrigin::Center)
    pictureAnger.moveZoom(0, 1, 100)
    # directives
    picturePoke.moveSE(1, "Audio/SE/throw")
    pictureBall.moveCurve(30, 1, 64, 256, Graphics.width / 2, 48, pokecenter[0], pokecenter[1])
    pictureBall.moveAngle(30, 1, -720)
    pictureBall.moveAngle(0, pictureBall.totalDuration, 0)
    pictureBall.moveSE(30, "Audio/SE/notverydamage")
    if armanim
      picturePlayer.moveSrc(1, @sprites["player"].bitmap.height, 0)
      picturePlayer.moveXY(0, 1, playerpos[0] - 14, playerpos[1])
      picturePlayer.moveSrc(4, @sprites["player"].bitmap.height * 2, 0)
      picturePlayer.moveXY(0, 4, playerpos[0] - 12, playerpos[1])
      picturePlayer.moveSrc(8, @sprites["player"].bitmap.height * 3, 0)
      picturePlayer.moveXY(0, 8, playerpos[0] + 20, playerpos[1])
      picturePlayer.moveSrc(16, @sprites["player"].bitmap.height * 4, 0)
      picturePlayer.moveXY(0, 16, playerpos[0] + 16, playerpos[1])
      picturePlayer.moveSrc(40, 0, 0)
      picturePlayer.moveXY(0, 40, playerpos[0], playerpos[1])
    end
    pictureBall.moveVisible(40, false)
    # Show Pokémon being angry
    pictureAnger.moveSE(48, "Audio/SE/jump")
    pictureAnger.moveVisible(48, true)
    pictureAnger.moveZoom(8, 48, 130)
    pictureAnger.moveZoom(8, 56, 100)
    pictureAnger.moveXY(0, 64, pokecenter[0] + 56, pokecenter[1] - 64)
    pictureAnger.moveSE(64, "Audio/SE/jump")
    pictureAnger.moveZoom(8, 64, 130)
    pictureAnger.moveZoom(8, 72, 100)
    pictureAnger.moveVisible(80, false)
    loop do
      pictureBall.update
      picturePoke.update
      picturePlayer.update
      pictureAnger.update
      setPictureIconSprite(spriteBall, pictureBall)
      setPictureSprite(spritePoke, picturePoke)
      setPictureIconSprite(spritePlayer, picturePlayer)
      setPictureIconSprite(spriteAnger, pictureAnger)
      pbGraphicsUpdate
      Input.update
      break if !pictureBall.running? && !picturePoke.running? &&
               !picturePlayer.running? && !pictureAnger.running?
    end
    spriteBall.dispose
  end

  def playerPartyBarX
    return @battle.player.is_a?(Array) ? PBScene::PLAYERPARTYBAR_X - 20 : PBScene::PLAYERPARTYBAR_X
  end

  def playerPartyBarY
    return @battle.player.is_a?(Array) ? PBScene::PLAYERPARTYBAR_Y - 20 : PBScene::PLAYERPARTYBAR_Y
  end

  def playerPartyBallOneX
    return @battle.player.is_a?(Array) ? PBScene::PLAYERPARTYBALL1_X - 20 : PBScene::PLAYERPARTYBALL1_X
  end

  def playerPartyBallOneY
    return @battle.player.is_a?(Array) ? PBScene::PLAYERPARTYBALL1_Y - 20 : PBScene::PLAYERPARTYBALL1_Y
  end

  def foePartyBarX
    return @battle.opponent.is_a?(Array) ? PBScene::FOEPARTYBAR_X + 20 : PBScene::FOEPARTYBAR_X
  end

  def foePartyBarY
    return @battle.opponent.is_a?(Array) ? PBScene::FOEPARTYBAR_Y - 40 : PBScene::FOEPARTYBAR_Y
  end

  def foePartyBallOneX
    return @battle.opponent.is_a?(Array) ? PBScene::FOEPARTYBALL1_X + 20 : PBScene::FOEPARTYBALL1_X
  end

  def foePartyBallOneY
    return @battle.opponent.is_a?(Array) ? PBScene::FOEPARTYBALL1_Y - 40 : PBScene::FOEPARTYBALL1_Y
  end

  # to update databox shield display every hit
  def pbUpdateShield(shield, index)
    return false if !@battle.battlers[index]

    @battle.battlers[index].pokemon.shieldCount = shield
    @sprites["battlebox#{index}"].shieldCount = shield
    @sprites["battlebox#{index}"].refresh
    if @battle.battlers[index].lastAttacker
      opponentindex = @battle.battlers[index].lastAttacker
    else
      opponentindex = @battle.battlers[index].pbOppositeOpposing.index
    end
    @battle.battlers[index].shieldsBrokenThisTurn[opponentindex] += 1
    if @battle.battlers[index].capturable
      if @battle.battlers[index].shieldCount == 0
        @battle.pbDisplayPaused(_INTL("{1}'s guard is low! Try capturing it!", @battle.battlers[index].pbThis))
      end
    end
  end

  # to update @battle.shieldCount in case mon enters as rift form
  # no shield due to transformation
  def pbUpdateBattleShield(index)
    @battle.shieldCount = @sprites["battlebox#{index}"].shieldCount
  end

  def adjustBattlerPositionsBossFight(battle)
    for i in 0..3
      if @sprites["battlebox#{i}"]
        @sprites["battlebox#{i}"].doublebattle = (battle.sosbattle) > 3 ? true : false
        if i == 0
          @sprites["battlebox#{i}"].x = PBScene::PLAYERBOXD1_X
          @sprites["battlebox#{i}"].y = PBScene::PLAYERBOXD1_Y
        end
      end
    end
  end

  def pbIntroBoss(battle, sosmonindex = nil)
    # Called whenever the battle begins
    @battle = battle
    @lastcmd = [0, 0, 0, 0]
    @lastmove = [0, 0, 0, 0]
    if @battle.opponent
      if @battle.opponent.is_a?(Array)
        trainerfile = pbTrainerSpriteFile(@battle.opponent[1].trainertype, @battle.opponent[1].outfit)
        pbAddSprite(
          "trainer2",
          PBScene::FOETRAINERD2_X,
          PBScene::FOETRAINERD2_Y,
          trainerfile, @viewport
        )
        trainerfile = pbTrainerSpriteFile(@battle.opponent[0].trainertype, @battle.opponent[0].outfit)
        pbAddSprite(
          "trainer",
          PBScene::FOETRAINERD1_X,
          PBScene::FOETRAINERD1_Y,
          trainerfile, @viewport
        )
        @sprites["trainer2"].visible = false
      else
        trainerfile = pbTrainerSpriteFile(@battle.opponent.trainertype, @battle.opponent.outfit)
        pbAddSprite(
          "trainer",
          PBScene::FOETRAINER_X,
          PBScene::FOETRAINER_Y,
          trainerfile, @viewport
        )
      end
      @sprites["trainer"].visible = false

    else
      trainerfile = "Graphics/Characters/trfront"
      pbAddSprite(
        "trainer",
        PBScene::FOETRAINER_X,
        PBScene::FOETRAINER_Y,
        trainerfile, @viewport
      )
      @sprites["trainer"].visible = false
    end
    pbAddSprite("shadow3", 0, 0, "Graphics/Pictures/Battle/battleShadow", @viewport)
    for i in @battle.battlers
      battler = i if i.isbossmon
    end
    battlerIndex = battler.index
    sosIndex = sosmonindex
    # @sprites["shadow3"].z=3
    @sprites["shadow3"].visible = false
    species = @battle.party2[0].species
    form = @battle.party2[0].form
    bossposition = battlerIndex == 1 ? [PBScene::FOEBATTLERD1_X, PBScene::FOEBATTLERD1_Y] : [PBScene::FOEBATTLERD2_X, PBScene::FOEBATTLERD2_Y]
    if sosIndex != 2
      sosposition = sosIndex == 1 ? [PBScene::FOEBATTLERD1_X, PBScene::FOEBATTLERD1_Y] : [PBScene::FOEBATTLERD2_X, PBScene::FOEBATTLERD2_Y]
    else
      sosposition = [PBScene::PLAYERBATTLERD2_X, PBScene::PLAYERBATTLERD2_Y]
    end
    @sprites["pokemon" + battlerIndex.to_s].x = bossposition[0]
    @sprites["pokemon" + battlerIndex.to_s].x -= @sprites["pokemon" + battlerIndex.to_s].width / 2
    @sprites["pokemon" + battlerIndex.to_s].y = bossposition[1]
    @sprites["pokemon" + battlerIndex.to_s].y += adjustBattleSpriteY(@sprites["pokemon" + battlerIndex.to_s], species, form, battlerIndex)
    @sprites["shadow" + battlerIndex.to_s].x = bossposition[0]
    @sprites["shadow" + battlerIndex.to_s].y = bossposition[1]
    @sprites["shadow" + battlerIndex.to_s].x -= @sprites["shadow" + battlerIndex.to_s].bitmap.width / 2 if @sprites["shadow" + battlerIndex.to_s].bitmap != nil
    @sprites["shadow" + battlerIndex.to_s].y -= @sprites["shadow" + battlerIndex.to_s].bitmap.height / 2 if @sprites["shadow" + battlerIndex.to_s].bitmap != nil
    @sprites["shadow" + battlerIndex.to_s].visible = showShadow?(species, form)
    if @battle.party2.length >= 1
      species = @battle.party2[-1].species
      form = @battle.party2[-1].form
      # another line to account for me running absolute BS for one battle; double check that the battler on the battler box is actually the battler on that index
      @sprites["battlebox" + sosIndex.to_s].dispose if @sprites["battlebox" + sosIndex.to_s] && @sprites["battlebox" + sosIndex.to_s].battler != battle.battlers[sosIndex]
      @sprites["battlebox" + sosIndex.to_s] =
        createPokemonDataBox(battle.battlers[sosIndex], battle.doublebattle, @viewport, battle) if !@sprites["battlebox" + sosIndex.to_s] || @sprites["battlebox" + sosIndex.to_s].disposed?
      @sprites["pokemon" + sosIndex.to_s] =
        PokemonBattlerSprite.new(battle.doublebattle, sosIndex, @viewport) if !@sprites["pokemon" + sosIndex.to_s]
      if sosIndex == 2
        @sprites["pokemon" + sosIndex.to_s].setPokemonBitmap(@battle.party2[-1], true)
      else
        @sprites["pokemon" + sosIndex.to_s].setPokemonBitmap(@battle.party2[-1], false)
      end
      @sprites["pokemon" + sosIndex.to_s].tone = Tone.new(-128, -128, -128, -128)
      @sprites["pokemon" + sosIndex.to_s].x = sosposition[0]
      @sprites["pokemon" + sosIndex.to_s].x -= @sprites["pokemon" + sosIndex.to_s].width / 2
      @sprites["pokemon" + sosIndex.to_s].y = sosposition[1]
      @sprites["pokemon" + sosIndex.to_s].y += adjustBattleSpriteY(@sprites["pokemon" + sosIndex.to_s], species, form, sosIndex)
      case sosIndex
        when 1
          @sprites["pokemon" + sosIndex.to_s].z = 16
        when 2
          @sprites["pokemon" + sosIndex.to_s].z = 26
        when 3
          @sprites["pokemon" + sosIndex.to_s].z = 11
      end
      @sprites["pokemon" + sosIndex.to_s].visible = true
      if sosIndex == 2
        @sprites["shadow" + sosIndex.to_s] = IconSprite.new(0, 0, @viewport) if !@sprites["shadow" + sosIndex.to_s]
      end
      @sprites["shadow" + sosIndex.to_s].x = sosposition[0]
      @sprites["shadow" + sosIndex.to_s].y = sosposition[1]
      @sprites["shadow" + sosIndex.to_s].x -= @sprites["shadow" + sosIndex.to_s].bitmap.width / 2 if @sprites["shadow" + sosIndex.to_s].bitmap != nil
      @sprites["shadow" + sosIndex.to_s].y -= @sprites["shadow" + sosIndex.to_s].bitmap.height / 2 if @sprites["shadow" + sosIndex.to_s].bitmap != nil
      @sprites["shadow" + sosIndex.to_s].visible = showShadow?(species, form)
      trainersprite2 = @sprites["pokemon" + sosIndex.to_s]
    end
    #################
    appearspeed = 12
    (1 + Graphics.width / appearspeed).times do
      tobreak = true
      if @viewport.rect.y > 0
        @viewport.rect.y -= appearspeed / 2
        @viewport.rect.y = 0 if @viewport.rect.y < 0
        @viewport.rect.height += appearspeed
        @viewport.rect.height = Graphics.height if @viewport.rect.height > Graphics.height
        tobreak = false
      end
      if !tobreak
        for i in @sprites
          next if i[1].nil?

          i[1].ox = @viewport.rect.x
          i[1].oy = @viewport.rect.y
        end
      end
      pbGraphicsUpdate
      Input.update
      break if tobreak
    end
    # Play cry for wild Pokémon
    pbPlayCry(@battle.party2[-1])
    @sprites["battlebox" + sosIndex.to_s].appear if @battle.party2.length >= 2
    appearing = true
    begin
      pbGraphicsUpdate
      Input.update
      @sprites["battlebox" + sosIndex.to_s].update
      @sprites["pokemon" + sosIndex.to_s].tone.red += 8 if @sprites["pokemon" + sosIndex.to_s].tone.red < 0
      @sprites["pokemon" + sosIndex.to_s].tone.blue += 8 if @sprites["pokemon" + sosIndex.to_s].tone.blue < 0
      @sprites["pokemon" + sosIndex.to_s].tone.green += 8 if @sprites["pokemon" + sosIndex.to_s].tone.green < 0
      @sprites["pokemon" + sosIndex.to_s].tone.gray += 8 if @sprites["pokemon" + sosIndex.to_s].tone.gray < 0
      appearing = (@sprites["battlebox" + sosIndex.to_s].appearing)
    end while appearing
    # Show shiny animation for wild Pokémon
    if @battle.party2[-1].isShiny? && @battle.battlescene
      pbCommonAnimation("Shiny", @battle.battlers[3], nil)
    end
  end

  def pbBossBattleSuccess(bossname = nil)
    if Rejuv && bossname == "Tiempa"
      return
    else
      pbBGMPlay("Victory!")
    end
  end
end

def pbFieldNotesBattle(move)
  return 0 if $Settings.field_effects_highlights == 1
  return 0 if !move.battle.field.isFieldEffect?
  return 0 if $cache.FEData[move.battle.FE].fieldAppSwitch.nil?
  return 0 if !$game_switches[$cache.FEData[move.battle.FE].fieldAppSwitch]

  battle = move.battle
  return 1 if battle.field.statusMoves && battle.field.statusMoves.include?(move.move)

  typeBoost = 1
  moveBoost = 1
  attacker = battle.battlers.find { |battler|
    battler.moves.include?(move) || (battler.zmoves && battler.zmoves.include?(move))
  }
  opponent = attacker.pbOppositeOpposing
  movetype = move.pbType(attacker)
  if move.basedamage > 0 && !((0x6A..0x73).include?(move.function) || [0xD4, 0xE1].include?(move.function))
    typeBoost = move.typeFieldBoost(movetype, attacker, opponent)
    moveBoost = move.moveFieldBoost
    moveBoost = 1.5 if move.isSoundBased? && move.basedamage > 0 && [:CAVE, :BIGTOP, :CONCERT1, :CONCERT2, :CONCERT3, :CONCERT4].include?(battle.FE)
  end
  moveBoost = 1.5 if move.move == :SONICBOOM && battle.FE == :RAINBOW
  moveBoost = 1.5 if move.move == :NATURESMADNESS && [:GRASSY, :FOREST, :HOLY, :NEWWORLD].include?(battle.FE)
  moveBoost = 1.5 if move.move == :GUARDIANOFALOLA && battle.FE == :NEWWORLD
  # Failing moves
  case battle.FE
    when :UNDERWATER, :NEWWORLD
      moveBoost = 0 if [:ELECTRICTERRAIN, :GRASSYTERRAIN, :MISTYTERRAIN, :PSYCHICTERRAIN].include?(move.move)
      moveBoost = 0 if [:RAINDANCE, :SUNNYDAY, :HAIL, :SANDSTORM].include?(move.move)
    when :ELECTERRAIN
      moveBoost = 0 if move.move == :FOCUSPUNCH
    when :CAVE
      moveBoost = 0 if move.move == :SKYDROP
    when :DARKNESS1, :DARKNESS2, :DARKNESS3
      moveBoost = 0 if [:MOONLIGHT, :SYNTHESIS, :MORNINGSUN].include?(move.move)
  end
  totalboost = typeBoost * moveBoost
  if totalboost > 1
    return 1
  elsif totalboost < 1
    return 2
  end

  return 0
end

def pbPokemonString(pkmn)
  if pkmn.is_a?(PokeBattle_Battler) && !pkmn.pokemon
    return ""
  end

  info = []
  info.push pkmn.name
  info.push "Level #{pkmn.level}"

  if pkmn.hp <= 0
    info.push " Status: Fainted"
  else
    case pkmn.status
      when :SLEEP
        info.push " Status: Asleep"
      when :FROZEN
        info.push " Status: Frozen"
      when :BURN
        info.push " Status: Burned"
      when :PARALYSIS
        info.push " Status: Paralyzed"
      when :POISON
        info.push " Status: Poisoned"
    end
  end

  info.push(pkmn.hp == pkmn.totalhp ? "Full Health" : "HP: #{pkmn.hp} out of #{pkmn.totalhp}") if pkmn.hp > 0

  if pkmn.type2.nil?
    info.push "Type: #{getTypeName(pkmn.type1)}"
  else
    info.push "Type: #{getTypeName(pkmn.type1)} / #{getTypeName(pkmn.type2)}"
  end

  info.push "Ability: #{getAbilityName(pkmn.ability)}"
  info.push "Item: #{pkmn.item ? getItemName(pkmn.item) : "None"}"
  info.push "Gender: #{["Male", "Female"][pkmn.gender]}" if pkmn.gender < 2

  return info.join(", ")
end

def pbEnemyPokemonString(pkmn)
  if pkmn.is_a?(PokeBattle_Battler) && !pkmn.pokemon
    return ""
  end

  status = ""
  if pkmn.hp <= 0
    status = " Status: Fainted"
  else
    case pkmn.status
      when :SLEEP
        status = " Status: Asleep"
      when :FROZEN
        status = " Status: Frozen"
      when :BURN
        status = " Status: Burned"
      when :PARALYSIS
        status = " Status: Paralyzed"
      when :POISON
        status = " Status: Poisoned"
    end
  end
  return "#{pkmn.name} (Level #{pkmn.level})#{status} HP: #{(pkmn.hp.to_f / pkmn.totalhp.to_f * 1000).to_i / 10.0} %"
end
