# Data structure representing mail that the Pokémon can hold
class PokemonMail
  attr_accessor :item, :message, :sender, :poke1, :poke2, :poke3

  def initialize(item, message, sender, poke1 = nil, poke2 = nil, poke3 = nil)
    @item = item # Item represented by this mail
    @message = message # Message text
    @sender = sender # Name of the message's sender
    @poke1 = poke1 # [species,gender,shininess,form,shadowness,is egg]
    @poke2 = poke2
    @poke3 = poke3
  end
end

def pbMoveToMailbox(pokemon)
  $PokemonGlobal.mailbox = [] if !$PokemonGlobal.mailbox
  return false if $PokemonGlobal.mailbox.length >= 10
  return false if !pokemon.mail

  $PokemonGlobal.mailbox.push(pokemon.mail)
  pokemon.mail = nil
  return true
end

def pbStoreMail(pkmn, item, message, poke1 = nil, poke2 = nil, poke3 = nil)
  raise _INTL("Pokémon already has mail") if pkmn.mail

  pkmn.mail = PokemonMail.new(item, message, $Trainer.name, poke1, poke2, poke3)
end

def pbDisplayMail(mail, bearer = nil)
  sprites = {}
  viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
  viewport.z = 99999
  addBackgroundPlane(sprites, "background", "mailbg", viewport)
  sprites["card"] = IconSprite.new(0, 0, viewport)
  sprites["card"].setBitmap(pbMailBackFile(mail.item))
  sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, viewport)
  overlay = sprites["overlay"].bitmap
  pbSetSystemFont(overlay)
  if mail.poke1 != nil
    sprites["bearer"] = IconSprite.new(64, 288, viewport)
    sprites["bearer"].bitmap = pbIconBitmap(mail.poke1[0], mail.poke1[3], mail.poke1[2], mail.poke1[1] == 1, mail.poke1[5], mail.poke1[4])
    sprites["bearer"].src_rect.set(0, 0, 64, 64)
  end
  if mail.poke2 != nil
    sprites["bearer2"] = IconSprite.new(144, 288, viewport)
    sprites["bearer2"].bitmap = pbIconBitmap(mail.poke2[0], mail.poke2[3], mail.poke2[2], mail.poke2[1] == 1, mail.poke2[5], mail.poke2[4])
    sprites["bearer2"].src_rect.set(0, 0, 64, 64)
  end
  if mail.poke3 != nil
    sprites["bearer3"] = IconSprite.new(224, 288, viewport)
    sprites["bearer3"].bitmap = pbIconBitmap(mail.poke3[0], mail.poke3[3], mail.poke3[2], mail.poke3[1] == 1, mail.poke3[5], mail.poke3[4])
    sprites["bearer3"].src_rect.set(0, 0, 64, 64)
  end
  baseForDarkBG = Color.new(248, 248, 248)
  shadowForDarkBG = Color.new(72, 80, 88)
  baseForLightBG = Color.new(80, 80, 88)
  shadowForLightBG = Color.new(168, 168, 176)
  if mail.message && mail.message != ""
    isDark = isDarkBackground(sprites["card"].bitmap, Rect.new(48, 48, Graphics.width - 96, 32 * 7))
    drawTextEx(
      overlay, 48, 48, Graphics.width - 96, 7, mail.message,
      isDark ? baseForDarkBG : baseForLightBG,
      isDark ? shadowForDarkBG : shadowForLightBG
    )
  end
  if mail.sender && mail.sender != ""
    isDark = isDarkBackground(sprites["card"].bitmap, Rect.new(336, 322, 144, 32 * 1))
    drawTextEx(
      overlay, 336, 322, 144, 1, _INTL("{1}", mail.sender),
      isDark ? baseForDarkBG : baseForLightBG,
      isDark ? shadowForDarkBG : shadowForLightBG
    )
  end
  pbFadeInAndShow(sprites)
  loop do
    Graphics.update
    Input.update
    pbUpdateSpriteHash(sprites)
    if Input.trigger?(Input::B) || Input.trigger?(Input::C)
      break
    end
  end
  pbFadeOutAndHide(sprites)
  pbDisposeSpriteHash(sprites)
  viewport.dispose
end


###########################


class PokeSelectionPlaceholderSprite < SpriteWrapper
  attr_accessor :text

  def initialize(pokemon, index, viewport = nil)
    super(viewport)
    xvalues = [0, 256, 0, 256, 0, 256]
    yvalues = [0, 16, 96, 112, 192, 208]
    @pbitmap = AnimatedBitmap.new("Graphics/Pictures/Party/partyPanelBlank")
    self.bitmap = @pbitmap.bitmap
    self.x = xvalues[index]
    self.y = yvalues[index]
    @text = nil
  end

  def update
    super
    @pbitmap.update
    self.bitmap = @pbitmap.bitmap
  end

  def selected
    return false
  end

  def selected=(value)
  end

  def preselected
    return false
  end

  def preselected=(value)
  end

  def switching
    return false
  end

  def switching=(value)
  end

  def refresh
  end

  def dispose
    @pbitmap.dispose
    super
  end
end

class PokeSelectionConfirmCancelSprite < SpriteWrapper
  attr_reader :selected

  def initialize(text, x, y, narrowbox = false, viewport = nil)
    super(viewport)
    @refreshBitmap = true
    @bgsprite = ChangelingSprite.new(0, 0, viewport)
    if narrowbox
      @bgsprite.addBitmap("deselbitmap", "Graphics/Pictures/Party/partyCancelNarrow")
      @bgsprite.addBitmap("selbitmap", "Graphics/Pictures/Party/partyCancelSelNarrow")
    else
      @bgsprite.addBitmap("deselbitmap", "Graphics/Pictures/Party/partyCancel")
      @bgsprite.addBitmap("selbitmap", "Graphics/Pictures/Party/partyCancelSel")
    end
    @bgsprite.changeBitmap("deselbitmap")
    @overlaysprite = BitmapSprite.new(@bgsprite.bitmap.width, @bgsprite.bitmap.height, viewport)
    @yoffset = 8
    ynarrow = narrowbox ? -6 : 0
    pbSetSystemFont(@overlaysprite.bitmap)
    textpos = [[text, 56, 8 + ynarrow, 2, Color.new(248, 248, 248), Color.new(40, 40, 40)]]
    pbDrawTextPositions(@overlaysprite.bitmap, textpos)
    @overlaysprite.z = self.z + 1 # For compatibility with RGSS2
    self.x = x
    self.y = y
  end

  def dispose
    @overlaysprite.bitmap.dispose
    @overlaysprite.dispose
    @bgsprite.dispose
    super
  end

  def viewport=(value)
    super
    refresh
  end

  def color=(value)
    super
    refresh
  end

  def x=(value)
    super
    refresh
  end

  def y=(value)
    super
    refresh
  end

  def selected=(value)
    @selected = value
    refresh
  end

  def refresh
    @bgsprite.changeBitmap((@selected) ? "selbitmap" : "deselbitmap")
    if @bgsprite && !@bgsprite.disposed?
      @bgsprite.x = self.x
      @bgsprite.y = self.y
      @overlaysprite.x = self.x
      @overlaysprite.y = self.y
      @bgsprite.color = self.color
      @overlaysprite.color = self.color
    end
  end
end

class PokeSelectionCancelSprite < PokeSelectionConfirmCancelSprite
  def initialize(viewport = nil)
    super(_INTL("CANCEL"), 398, 328, false, viewport)
  end
end

class PokeSelectionConfirmSprite < PokeSelectionConfirmCancelSprite
  def initialize(viewport = nil)
    super(_INTL("CONFIRM"), 398, 308, true, viewport)
  end
end

class PokeSelectionCancelSprite2 < PokeSelectionConfirmCancelSprite
  def initialize(viewport = nil)
    super(_INTL("CANCEL"), 398, 346, true, viewport)
  end
end

class ChangelingSprite < SpriteWrapper
  def initialize(x = 0, y = 0, viewport = nil)
    super(viewport)
    self.x = x
    self.y = y
    @bitmaps = {}
    @currentBitmap = nil
  end

  def addBitmap(key, path)
    if @bitmaps[key]
      @bitmaps[key].dispose
    end
    @bitmaps[key] = AnimatedBitmap.new(path)
  end

  def changeBitmap(key)
    @currentBitmap = @bitmaps[key]
    self.bitmap = @currentBitmap ? @currentBitmap.bitmap : nil
  end

  def dispose
    return if disposed?

    for bm in @bitmaps.values; bm.dispose; end
    @bitmaps.clear
    super
  end

  def update
    return if disposed?

    for bm in @bitmaps.values; bm.update; end
    self.bitmap = @currentBitmap ? @currentBitmap.bitmap : nil
  end
end

class PokeSelectionSprite < SpriteWrapper
  attr_reader :selected
  attr_reader :preselected
  attr_reader :switching
  attr_reader :pokemon
  attr_reader :active
  attr_accessor :text

  def initialize(pokemon, index, viewport = nil)
    super(viewport)
    @pokemon = pokemon
    active = (index == 0)
    @active = active
    @deselbitmap = AnimatedBitmap.new("Graphics/Pictures/Party/partyPanel")
    @selbitmap = AnimatedBitmap.new("Graphics/Pictures/Party/partyPanelSel")
    @deselfntbitmap = AnimatedBitmap.new("Graphics/Pictures/Party/partyPanelFnt")
    @selfntbitmap = AnimatedBitmap.new("Graphics/Pictures/Party/partyPanelSelFnt")
    @deselswapbitmap = AnimatedBitmap.new("Graphics/Pictures/Party/partyPanel")
    @selswapbitmap = AnimatedBitmap.new("Graphics/Pictures/Party/partyPanelSel")
    @deselswapfntbitmap = AnimatedBitmap.new("Graphics/Pictures/Party/partyPanelFnt")
    @selswapfntbitmap = AnimatedBitmap.new("Graphics/Pictures/Party/partyPanelSelFnt")
    @spriteXOffset = 28
    @spriteYOffset = 0
    @pokeballXOffset = 10
    @pokeballYOffset = 0
    @pokenameX = 96
    @pokenameY = 16
    @levelX = 20
    @levelY = 68
    @statusX = 80
    @statusY = 68
    @genderX = 224
    @genderY = 16
    @hpX = 224
    @hpY = 60
    @hpbarX = 96
    @hpbarY = 50
    @gaugeX = 128
    @gaugeY = 52
    @itemXOffset = 62
    @itemYOffset = 48
    @annotX = 96
    @annotY = 58
    xvalues = [0, 256, 0, 256, 0, 256]
    yvalues = [0, 16, 96, 112, 192, 208]
    @text = nil
    @pkmnsprite = PokemonIconSprite.new(pokemon, viewport)
    @pkmnsprite.active = active
    @statuses = AnimatedBitmap.new(_INTL("Graphics/Pictures/statuses"))
    @hpbar = AnimatedBitmap.new("Graphics/Pictures/Party/partyHP")
    @hpbarfnt = AnimatedBitmap.new("Graphics/Pictures/Party/partyHPfnt")
    @hpbarswap = AnimatedBitmap.new("Graphics/Pictures/Party/partyHP")
    @hpbarswapfnt = AnimatedBitmap.new("Graphics/Pictures/Party/partyHPfnt")
    @pokeballsprite = ChangelingSprite.new(0, 0, viewport)
    @pokeballsprite.addBitmap("pokeballdesel", "Graphics/Pictures/Party/partyBall")
    @pokeballsprite.addBitmap("pokeballsel", "Graphics/Pictures/Party/partyBallSel")
    @itemsprite = ChangelingSprite.new(0, 0, viewport)
    @itemsprite.addBitmap("itembitmap", "Graphics/Pictures/Party/item")
    @itemsprite.addBitmap("mailbitmap", "Graphics/Pictures/Party/mail")
    @spriteX = xvalues[index]
    @spriteY = yvalues[index]
    @refreshBitmap = true
    @refreshing = false
    @preselected = false
    @switching = false
    @pkmnsprite.z = self.z + 2 # For compatibility with RGSS2
    @itemsprite.z = self.z + 3 # For compatibility with RGSS2
    @pokeballsprite.z = self.z + 1 # For compatibility with RGSS2
    self.selected = false
    self.x = @spriteX
    self.y = @spriteY
    refresh
  end

  def dispose
    @selbitmap.dispose
    @statuses.dispose
    @hpbar.dispose
    @deselbitmap.dispose
    @itemsprite.dispose
    @pkmnsprite.dispose
    @pokeballsprite.dispose
    self.bitmap.dispose
    super
  end

  def selected=(value)
    @selected = value
    @refreshBitmap = true
    refresh
  end

  def text=(value)
    @text = value
    @refreshBitmap = true
    refresh
  end

  def pokemon=(value)
    @pokemon = value
    if @pkmnsprite && !@pkmnsprite.disposed?
      @pkmnsprite.pokemon = value
    end
    @refreshBitmap = true
    refresh
  end

  def preselected=(value)
    if value != @preselected
      @preselected = value
      refresh
    end
  end

  def switching=(value)
    if value != @switching
      @switching = value
      refresh
    end
  end

  def color=(value)
    super
    refresh
  end

  def x=(value)
    super
    refresh
  end

  def y=(value)
    super
    refresh
  end

  def hp
    return @pokemon.hp
  end

  def refresh
    return if @refreshing
    return if disposed?

    @refreshing = true
    if !self.bitmap || self.bitmap.disposed?
      self.bitmap = BitmapWrapper.new(@selbitmap.width, @selbitmap.height)
    end
    if @pkmnsprite && !@pkmnsprite.disposed?
      @pkmnsprite.x = self.x + @spriteXOffset
      @pkmnsprite.y = self.y + @spriteYOffset
      @pkmnsprite.color = pbSrcOver(@pkmnsprite.color, self.color)
      @pkmnsprite.selected = self.selected
    end
    if @pokeballsprite && !@pokeballsprite.disposed?
      @pokeballsprite.x = self.x + @pokeballXOffset
      @pokeballsprite.y = self.y + @pokeballYOffset
      @pokeballsprite.color = self.color
      @pokeballsprite.changeBitmap(self.selected ? "pokeballsel" : "pokeballdesel")
    end
    if @itemsprite && !@itemsprite.disposed?
      @itemsprite.visible = (!@pokemon.item.nil?)
      if @itemsprite.visible
        @itemsprite.changeBitmap(@pokemon.mail ? "mailbitmap" : "itembitmap")
        @itemsprite.x = self.x + @itemXOffset
        @itemsprite.y = self.y + @itemYOffset
        @itemsprite.color = self.color
      end
    end
    if @refreshBitmap
      @refreshBitmap = false
      self.bitmap.clear if self.bitmap
      if self.selected
        if self.preselected
          if @pokemon.hp <= 0 && !@pokemon.isEgg?
            self.bitmap.blt(0, 0, @selswapfntbitmap.bitmap, Rect.new(0, 0, @selswapfntbitmap.width, @selswapfntbitmap.height))
            self.bitmap.blt(0, 0, @deselswapfntbitmap.bitmap, Rect.new(0, 0, @deselswapfntbitmap.width, @deselswapfntbitmap.height))
          else
            self.bitmap.blt(0, 0, @selswapbitmap.bitmap, Rect.new(0, 0, @selswapbitmap.width, @selswapbitmap.height))
            self.bitmap.blt(0, 0, @deselswapbitmap.bitmap, Rect.new(0, 0, @deselswapbitmap.width, @deselswapbitmap.height))
          end
        elsif @switching
          if @pokemon.hp <= 0 && !@pokemon.isEgg?
            self.bitmap.blt(0, 0, @selswapfntbitmap.bitmap, Rect.new(0, 0, @selswapfntbitmap.width, @selswapfntbitmap.height))
          else
            self.bitmap.blt(0, 0, @selswapbitmap.bitmap, Rect.new(0, 0, @selswapbitmap.width, @selswapbitmap.height))
          end
        elsif @pokemon.hp <= 0 && !@pokemon.isEgg?
          self.bitmap.blt(0, 0, @selfntbitmap.bitmap, Rect.new(0, 0, @selfntbitmap.width, @selfntbitmap.height))
        else
          self.bitmap.blt(0, 0, @selbitmap.bitmap, Rect.new(0, 0, @selbitmap.width, @selbitmap.height))
        end
      else
        if self.preselected
          if @pokemon.hp <= 0 && !@pokemon.isEgg?
            self.bitmap.blt(0, 0, @deselswapfntbitmap.bitmap, Rect.new(0, 0, @deselswapfntbitmap.width, @deselswapfntbitmap.height))
          else
            self.bitmap.blt(0, 0, @deselswapbitmap.bitmap, Rect.new(0, 0, @deselswapbitmap.width, @deselswapbitmap.height))
          end
        elsif @pokemon.hp <= 0 && !@pokemon.isEgg?
          self.bitmap.blt(0, 0, @deselfntbitmap.bitmap, Rect.new(0, 0, @deselfntbitmap.width, @deselfntbitmap.height))
        else
          self.bitmap.blt(0, 0, @deselbitmap.bitmap, Rect.new(0, 0, @deselbitmap.width, @deselbitmap.height))
        end
      end
      base = Color.new(248, 248, 248)
      shadow = Color.new(40, 40, 40)
      pbSetSystemFont(self.bitmap)
      pokename = @pokemon.name
      textpos = [[pokename, @pokenameX, @pokenameY, 0, base, shadow]]
      if !@pokemon.isEgg?
        if !@text || @text.length == 0
          tothp = @pokemon.totalhp
          textpos.push([_ISPRINTF("{1: 3d}/{2: 3d}", @pokemon.hp, tothp), @hpX, @hpY, 1, base, shadow])
          barbg = (@pokemon.hp <= 0) ? @hpbarfnt : @hpbar
          barbg = (self.preselected || (self.selected && @switching)) ? @hpbarswap : barbg
          barbg = ((self.preselected || (self.selected && @switching)) && @pokemon.hp <= 0) ? @hpbarswapfnt : barbg
          self.bitmap.blt(@hpbarX, @hpbarY, barbg.bitmap, Rect.new(0, 0, @hpbar.width, @hpbar.height))
          hpgauge = @pokemon.totalhp == 0 ? 0 : (self.hp * 96 / @pokemon.totalhp)
          hpgauge = 1 if hpgauge == 0 && self.hp > 0
          hpzone = 0
          hpzone = 1 if self.hp <= (@pokemon.totalhp / 2.0).floor
          hpzone = 2 if self.hp <= (@pokemon.totalhp / 4.0).floor
          hpcolors = [
            Color.new(24, 192, 32), Color.new(96, 248, 96), # Green
            Color.new(232, 168, 0), Color.new(248, 216, 0),   # Orange
            Color.new(248, 72, 56), Color.new(248, 152, 152)  # Red
          ]
          # fill with HP color
          self.bitmap.fill_rect(@gaugeX, @gaugeY, hpgauge, 2, hpcolors[hpzone * 2])
          self.bitmap.fill_rect(@gaugeX, @gaugeY + 2, hpgauge, 4, hpcolors[hpzone * 2 + 1])
          self.bitmap.fill_rect(@gaugeX, @gaugeY + 6, hpgauge, 2, hpcolors[hpzone * 2])
          if @pokemon.hp == 0 || !@pokemon.status.nil?
            status = (@pokemon.hp == 0) ? :FAINTED : @pokemon.status
            imagepos = []
            imagepos.push([sprintf("Graphics/Pictures/Party/status%s", status), @statusX, @statusY, 0, 0, 44, 16])
            pbDrawImagePositions(self.bitmap, imagepos)
          end
        end
        if @pokemon.isMale?
          textpos.push([_INTL("♂"), @genderX, @genderY, 0, Color.new(0, 112, 248), Color.new(120, 184, 232)])
        elsif @pokemon.isFemale?
          textpos.push([_INTL("♀"), @genderX, @genderY, 0, Color.new(232, 32, 16), Color.new(248, 168, 184)])
        end
      end
      pbDrawTextPositions(self.bitmap, textpos)
      if !@pokemon.isEgg?
        pbSetSmallFont(self.bitmap)
        leveltext = [([_INTL("Lv.{1}", @pokemon.level), @levelX, @levelY, 0, base, shadow])]
        pbDrawTextPositions(self.bitmap, leveltext)
      end
      if @text && @text.length > 0
        pbSetSystemFont(self.bitmap)
        annotation = [[@text, @annotX, @annotY, 0, base, shadow]]
        pbDrawTextPositions(self.bitmap, annotation)
      end
    end
    @refreshing = false
  end

  def update
    super
    @pokeballsprite.update if @pokeballsprite && !@pokeballsprite.disposed?
    @itemsprite.update if @itemsprite && !@itemsprite.disposed?
    if @pkmnsprite && !@pkmnsprite.disposed?
      @pkmnsprite.update
    end
  end
end


##############################


class PokemonScreen_Scene
  attr_accessor :sprites

  def pbShowCommands(helptext, commands, index = 0)
    tts(helptext)
    ret = -1
    helpwindow = @sprites["helpwindow"]
    helpwindow.visible = true
    using_block(cmdwindow = Window_CommandPokemon.new(commands)) {
      cmdwindow.z = @viewport.z + 1
      cmdwindow.index = index
      pbBottomRight(cmdwindow)
      helpwindow.text = ""
      helpwindow.resizeHeightToFit(helptext, Graphics.width - cmdwindow.width)
      helpwindow.text = helptext
      pbBottomLeft(helpwindow)
      loop do
        Graphics.update
        Input.update
        cmdwindow.update
        self.update
        if Input.trigger?(Input::B)
          pbPlayCancelSE()
          ret = -1
          break
        end
        if Input.trigger?(Input::C)
          pbPlayDecisionSE()
          ret = cmdwindow.index
          break
        end
      end
    }
    return ret
  end

  def update
    pbUpdateSpriteHash(@sprites)
  end

  def pbSetHelpText(helptext)
    helpwindow = @sprites["helpwindow"]
    pbBottomLeftLines(helpwindow, 1)
    tts(helptext) if helpwindow.text != helptext
    helpwindow.text = helptext
    helpwindow.width = 398
    helpwindow.visible = true
  end

  def pbStartScene(party, starthelptext, annotations = nil, multiselect = false)
    @sprites = {}
    @party = party
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @multiselect = multiselect
    addBackgroundPlane(@sprites, "partybg", "Party/partybg", @viewport)
    @sprites["messagebox"] = Window_AdvancedTextPokemon.new("")
    @sprites["helpwindow"] = Window_UnformattedTextPokemon.new("")
    @sprites["messagebox"].viewport = @viewport
    @sprites["messagebox"].visible = false
    @sprites["messagebox"].letterbyletter = true
    @sprites["helpwindow"].viewport = @viewport
    @sprites["helpwindow"].visible = true
    pbBottomLeftLines(@sprites["messagebox"], 2)
    pbBottomLeftLines(@sprites["helpwindow"], 1)
    pbSetHelpText(starthelptext)
    # Add party Pokémon sprites
    for i in 0...6
      if @party[i]
        @sprites["pokemon#{i}"] = PokeSelectionSprite.new(@party[i], i, @viewport)
      else
        @sprites["pokemon#{i}"] = PokeSelectionPlaceholderSprite.new(@party[i], i, @viewport)
      end
      if annotations
        @sprites["pokemon#{i}"].text = annotations[i]
      end
    end
    if @multiselect
      @sprites["pokemon6"] = PokeSelectionConfirmSprite.new(@viewport)
      @sprites["pokemon7"] = PokeSelectionCancelSprite2.new(@viewport)
    else
      @sprites["pokemon6"] = PokeSelectionCancelSprite.new(@viewport)
    end
    # Select first Pokémon
    @activecmd = 0
    @sprites["pokemon0"].selected = true
    pbFadeInAndShow(@sprites) { update }
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites) { update }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end

  def pbChangeSelection(key, currentsel)
    numsprites = (@multiselect) ? 8 : 7
    case key
      when Input::LEFT
        begin
          currentsel -= 1
        end while currentsel > 0 && currentsel < @party.length && !@party[currentsel]
        if currentsel >= @party.length && currentsel < 6
          currentsel = @party.length - 1
        end
        currentsel = numsprites - 1 if currentsel < 0
      when Input::RIGHT
        begin
          currentsel += 1
        end while currentsel < @party.length && !@party[currentsel]
        if currentsel == @party.length
          currentsel = 6
        elsif currentsel == numsprites
          currentsel = 0
        end
      when Input::UP
        if currentsel == 7
          currentsel -= 1
        elsif currentsel >= 6
          begin
            currentsel -= 1
          end while currentsel > 0 && !@party[currentsel]
        else
          begin
            currentsel -= 2
          end while currentsel > 0 && !@party[currentsel]
        end
        if currentsel >= @party.length && currentsel < 6
          currentsel = @party.length - 1
        end
        currentsel = numsprites - 1 if currentsel < 0
      when Input::DOWN
        if currentsel >= 5
          currentsel += 1
        else
          currentsel += 2
          currentsel = 6 if currentsel < 6 && !@party[currentsel]
        end
        if currentsel >= @party.length && currentsel < 6
          currentsel = 6
        elsif currentsel >= numsprites
          currentsel = 0
        end
    end
    return currentsel
  end

  def pbRefresh
    for i in 0...6
      sprite = @sprites["pokemon#{i}"]
      if sprite
        if sprite.is_a?(PokeSelectionSprite)
          sprite.pokemon = sprite.pokemon
        else
          sprite.refresh
        end
      end
    end
  end

  def pbRefreshSingle(i)
    sprite = @sprites["pokemon#{i}"]
    if sprite
      if sprite.is_a?(PokeSelectionSprite)
        sprite.pokemon = sprite.pokemon
      else
        sprite.refresh
      end
    end
  end

  def pbHardRefresh
    oldtext = []
    lastselected = -1
    for i in 0...6
      oldtext.push(@sprites["pokemon#{i}"].text)
      lastselected = i if @sprites["pokemon#{i}"].selected
      @sprites["pokemon#{i}"].dispose
    end
    lastselected = @party.length - 1 if lastselected >= @party.length
    lastselected = 0 if lastselected < 0
    for i in 0...6
      if @party[i]
        @sprites["pokemon#{i}"] = PokeSelectionSprite.new(@party[i], i, @viewport)
      else
        @sprites["pokemon#{i}"] = PokeSelectionPlaceholderSprite.new(@party[i], i, @viewport)
      end
      @sprites["pokemon#{i}"].text = oldtext[i]
    end
    pbSelect(lastselected)
  end

  def pbPreSelect(pkmn)
    @activecmd = pkmn
  end

  def pbChoosePokemon(switching = false, allow_party_switch = false, canswitch = 0, shortcut_keys: false)
    for i in 0...6
      @sprites["pokemon#{i}"].preselected = (switching && i == @activecmd)
      @sprites["pokemon#{i}"].switching = switching
    end
    pbRefresh
    lastread = nil
    if @activecmd == 6 && @multiselect
      tts('Confirm')
    elsif @activecmd >= 6
      tts('Cancel')
    else
      tts(pbPokemonString(@sprites["pokemon#{@activecmd}"].pokemon))
    end
    loop do
      Graphics.update
      Input.update
      self.update
      oldsel = @activecmd
      key = -1
      key = Input::DOWN if Input.repeat?(Input::DOWN)
      key = Input::RIGHT if Input.repeat?(Input::RIGHT)
      key = Input::LEFT if Input.repeat?(Input::LEFT)
      key = Input::UP if Input.repeat?(Input::UP)
      if key >= 0
        @activecmd = pbChangeSelection(key, @activecmd)
      end
      if @activecmd != oldsel # Changing selection
        pbPlayCursorSE()
        numsprites = (@multiselect) ? 8 : 7
        for i in 0...numsprites
          @sprites["pokemon#{i}"].selected = (i == @activecmd)
        end
        if @activecmd == 6 && @multiselect
          tts('Confirm')
        elsif @activecmd >= 6
          tts('Cancel')
        else
          tts(pbPokemonString(@sprites["pokemon#{@activecmd}"].pokemon))
        end
      end
      if allow_party_switch && canswitch == 0 && Input.trigger?(Input::X) && @activecmd < 6
        return [1, @activecmd]
      elsif allow_party_switch && canswitch == 1 && Input.trigger?(Input::X) && @activecmd < 6
        return @activecmd
      end
      if Input.trigger?(Input::B)
        return -1
      end

      if Input.trigger?(Input::C)
        pbPlayDecisionSE()
        cancelsprite = (@multiselect) ? 7 : 6
        return (@activecmd == cancelsprite) ? -1 : @activecmd
      end

      if shortcut_keys && canswitch == 0 && @activecmd < 6
        # Item command is not allowed in battle
        if Input.trigger?(Input::Y) && allow_party_switch
          # Item
          return [2, @activecmd]
        end
        if Input.trigger?(Input::Z)
          # Summary
          return [3, @activecmd]
        end
      end
    end
  end

  def pbSelect(item)
    @activecmd = item
    numsprites = (@multiselect) ? 8 : 7
    for i in 0...numsprites
      @sprites["pokemon#{i}"].selected = (i == @activecmd)
    end
  end

  def pbDisplay(text)
    @sprites["messagebox"].text = text
    @sprites["messagebox"].visible = true
    @sprites["helpwindow"].visible = false
    tts(text)
    pbPlayDecisionSE()
    loop do
      Graphics.update
      Input.update
      self.update
      if @sprites["messagebox"].busy? && Input.trigger?(Input::C)
        pbPlayDecisionSE() if @sprites["messagebox"].pausing?
        @sprites["messagebox"].resume
      end
      if !@sprites["messagebox"].busy? &&
         (Input.trigger?(Input::C) || Input.trigger?(Input::B))
        break
      end
    end
    @sprites["messagebox"].visible = false
    @sprites["helpwindow"].visible = true
  end

  def pbSwitchBegin(oldid, newid)
    oldsprite = @sprites["pokemon#{oldid}"]
    newsprite = @sprites["pokemon#{newid}"]
    22.times do
      oldsprite.x += (oldid & 1) == 0 ? -12 : 12
      newsprite.x += (newid & 1) == 0 ? -12 : 12
      Graphics.update
      Input.update
      self.update
    end
  end

  def pbSwitchEnd(oldid, newid)
    oldsprite = @sprites["pokemon#{oldid}"]
    newsprite = @sprites["pokemon#{newid}"]
    oldsprite.pokemon = @party[oldid]
    newsprite.pokemon = @party[newid]
    22.times do
      oldsprite.x -= (oldid & 1) == 0 ? -12 : 12
      newsprite.x -= (newid & 1) == 0 ? -12 : 12
      Graphics.update
      Input.update
      self.update
    end
    for i in 0...6
      @sprites["pokemon#{i}"].preselected = false
      @sprites["pokemon#{i}"].switching = false
    end
    pbRefresh
  end

  def pbDisplayConfirm(text)
    ret = -1
    @sprites["messagebox"].text = text
    @sprites["messagebox"].visible = true
    @sprites["helpwindow"].visible = false
    tts(text)
    using_block(cmdwindow = Window_CommandPokemon.new([_INTL("Yes"), _INTL("No")])) {
      cmdwindow.z = @viewport.z + 1
      cmdwindow.visible = false
      pbBottomRight(cmdwindow)
      cmdwindow.y -= @sprites["messagebox"].height
      loop do
        Graphics.update
        Input.update
        cmdwindow.visible = true if !@sprites["messagebox"].busy?
        cmdwindow.update
        self.update
        if Input.trigger?(Input::B) && !@sprites["messagebox"].busy?
          ret = false
          break
        end
        if Input.trigger?(Input::C) && @sprites["messagebox"].resume && !@sprites["messagebox"].busy?
          ret = (cmdwindow.index == 0)
          break
        end
      end
    }
    @sprites["messagebox"].visible = false
    @sprites["helpwindow"].visible = true
    return ret
  end

  def pbConfirm(text)
    return pbDisplayConfirm(text)
  end

  def pbAnnotate(annot, also_if_not_exist)
    return unless annot

    for i in 0...6
      # Make sure there are annotation needed
      next if !also_if_not_exist && (@sprites["pokemon#{i}"].text.nil? || @sprites["pokemon#{i}"].text == "")

      @sprites["pokemon#{i}"].text = annot[i]
    end
  end

  def pbSummary(pkmnid)
    oldsprites = pbFadeOutAndHide(@sprites)
    scene = PokemonSummaryScene.new
    screen = PokemonSummary.new(scene)
    screen.pbStartScreen(@party, pkmnid)
    pbFadeInAndShow(@sprites, oldsprites)
  end

  def pbChooseItem(bag, from_bag: false)
    oldsprites = pbFadeOutAndHide(@sprites)
    @sprites["helpwindow"].visible = false
    @sprites["messagebox"].visible = false
    scene = PokemonBag_Scene.new
    screen = PokemonBagScreen.new(scene, bag)
    ret = screen.pbGiveItemScreen(from_bag)
    pbFadeInAndShow(@sprites, oldsprites)
    return ret
  end
end


######################################


class PokemonScreen
  attr_accessor :scene

  def initialize(scene, party)
    @party = party
    @scene = scene
  end

  def pbHardRefresh
    @scene.pbHardRefresh
  end

  def pbRefresh
    @scene.pbRefresh
  end

  def pbRefreshSingle(i)
    @scene.pbRefreshSingle(i)
  end

  def pbDisplay(text)
    @scene.pbDisplay(text)
  end

  def pbShowCommands(helptext, commands, index = 0)
    @scene.pbShowCommands(helptext, commands, index)
  end

  def pbConfirm(text)
    return @scene.pbDisplayConfirm(text)
  end

  def pbSwitch(oldid, newid)
    if oldid != newid
      @scene.pbSwitchBegin(oldid, newid)
      tmp = @party[oldid]
      @party[oldid] = @party[newid]
      @party[newid] = tmp
      @scene.pbSwitchEnd(oldid, newid)
    end
  end

  def pbMailScreen(item, pkmn, pkmnid)
    message = ""
    loop do
      message = Kernel.pbMessageFreeText(
        _INTL("Please enter a message (max. {1} characters).", 256),
        "", false, 256, Graphics.width
      ) { @scene.update }
      if message != ""
        # Store mail if a message was written
        poke1 = poke2 = poke3 = nil
        if $Trainer.party[pkmnid + 2]
          p = $Trainer.party[pkmnid + 2]
          poke1 = [p.species, p.gender, p.isShiny?, (p.form rescue 0), (p.isShadow? rescue false)]
          poke1.push(true) if p.isEgg?
        end
        if $Trainer.party[pkmnid + 1]
          p = $Trainer.party[pkmnid + 1]
          poke2 = [p.species, p.gender, p.isShiny?, (p.form rescue 0), (p.isShadow? rescue false)]
          poke2.push(true) if p.isEgg?
        end
        poke3 = [pkmn.species, pkmn.gender, pkmn.isShiny?, (pkmn.form rescue 0), (pkmn.isShadow? rescue false)]
        poke3.push(true) if pkmn.isEgg?
        pbStoreMail(pkmn, item, message, poke1, poke2, poke3)
        return true
      else
        return false if pbConfirm(_INTL("Stop giving the Pokémon Mail?"))
      end
    end
  end

  def pbTakeItem(pkmn)
    if !pkmn.hasAnItem?
      pbDisplay(_INTL("{1} isn't holding anything.", pkmn.name))
    elsif !$PokemonBag.pbCanStore?(pkmn.item)
      pbDisplay(_INTL("The Bag is full.  The Pokémon's item could not be removed."))
    elsif pkmn.mail
      # if pbConfirm(_INTL("Send the removed mail to your PC?"))
      #   if !pbMoveToMailbox(pkmn)
      #     pbDisplay(_INTL("Your PC's Mailbox is full."))
      #   else
      #     pbDisplay(_INTL("The mail was sent to your PC."))
      #     pkmn.setItem(nil)
      #   end
      # els
      if pbConfirm(_INTL("If the mail is removed, the message will be lost.  OK?"))
        pbDisplay(_INTL("Mail was taken from the Pokémon."))
        $PokemonBag.pbStoreItem(pkmn.item)
        pkmn.setItem(nil)
        pkmn.mail = nil
      end
    else
      $PokemonBag.pbStoreItem(pkmn.item)
      itemname = getItemName(pkmn.item)
      pbDisplay(_INTL("Received the {1} from {2}.", itemname, pkmn.name))
      pkmn.setItem(nil)
      check = pkmn.form
      pkmn.form = pkmn.getForm(pkmn)
      if check != pkmn.form
        if pkmn.getAbilityList.length > 1
          if pkmn.getAbilityList.include?(pkmn.originalAbility)
            pkmn.ability = pkmn.originalAbility
            pkmn.originalAbility = nil
          else
            pkmn.initAbility
          end
        else
          pkmn.originalAbility = pkmn.originalAbility.nil? ? pkmn.ability : nil
          pkmn.initAbility
        end
      end
    end
  end

  def pbGiveItem(item, pkmn, pkmnid = 0)
    thisitemname = getItemName(item)
    if pkmn.isEgg?
      pbDisplay(_INTL("Eggs can't hold items."))
      return false
    end
    if pkmn.mail
      pbDisplay(_INTL("Mail must be removed before holding an item."))
      return false
    end
    if thisitemname == "Blue Orb" && pkmn.species != :KYOGRE
      pbDisplay(_INTL("The Blue Orb can't be held!"))
      return false
    end
    if thisitemname == "Red Orb" && pkmn.species != :GROUDON
      pbDisplay(_INTL("The Red Orb can't be held!"))
      return false
    end
    if pkmn.item
      itemname = getItemName(pkmn.item)
      pbDisplay(_INTL("{1} is already holding one {2}.\1", pkmn.name, itemname))
      if pbConfirm(_INTL("Would you like to switch the two items?"))
        $PokemonBag.pbDeleteItem(item)
        if !$PokemonBag.pbStoreItem(pkmn.item)
          if !$PokemonBag.pbStoreItem(item) # Compensate
            raise _INTL("Can't re-store deleted item in bag")
          end

          pbDisplay(_INTL("The Bag is full.  The Pokémon's item could not be removed."))
        else
          if pbIsMail?(item)
            if pbMailScreen(item, pkmn, pkmnid)
              pkmn.setItem(item)
              pbDisplay(_INTL("The {1} was taken and replaced with the {2}.", itemname, thisitemname))
              return true
            else
              if !$PokemonBag.pbStoreItem(item) # Compensate
                raise _INTL("Can't re-store deleted item in bag")
              end
            end
          else
            pkmn.setItem(item)
            pbDisplay(_INTL("The {1} was taken and replaced with the {2}.", itemname, thisitemname))
            check = pkmn.form
            pkmn.form = pkmn.getForm(pkmn)
            if check != pkmn.form
              if pkmn.getAbilityList.length > 1
                if pkmn.getAbilityList.include?(pkmn.originalAbility)
                  pkmn.ability = pkmn.originalAbility
                  pkmn.originalAbility = nil
                else
                  pkmn.initAbility
                end
              else
                pkmn.originalAbility = pkmn.originalAbility.nil? ? pkmn.ability : nil
                pkmn.initAbility
              end
            end
            return true
          end
        end
      end
    else
      if !pbIsMail?(item) || pbMailScreen(item, pkmn, pkmnid) # Open the mail screen if necessary
        $PokemonBag.pbDeleteItem(item)
        pkmn.setItem(item)
        pbDisplay(_INTL("{1} was given the {2} to hold.", pkmn.name, thisitemname))
        check = pkmn.form
        pkmn.form = pkmn.getForm(pkmn)
        if check != pkmn.form
          if pkmn.getAbilityList.length > 1
            if pkmn.getAbilityList.include?(pkmn.originalAbility)
              pkmn.ability = pkmn.originalAbility
              pkmn.originalAbility = nil
            else
              pkmn.initAbility
            end
          else
            pkmn.originalAbility = pkmn.originalAbility.nil? ? pkmn.ability : nil
            pkmn.initAbility
          end
        end
        return true
      end
    end
    return false
  end

  def pbPokemonGiveScreen(item)
    @scene.pbStartScene(@party, _INTL("Give to which Pokémon?"))
    pkmnid = @scene.pbChoosePokemon
    ret = false
    if pkmnid >= 0
      ret = pbGiveItem(item, @party[pkmnid], pkmnid)
    end
    pbRefreshSingle(pkmnid)
    @scene.pbEndScene
    return ret
  end

  def pbPokemonGiveMailScreen(mailIndex)
    @scene.pbStartScene(@party, _INTL("Give to which Pokémon?"))
    pkmnid = @scene.pbChoosePokemon
    if pkmnid >= 0
      pkmn = @party[pkmnid]
      if !pkmn.item.nil? || pkmn.mail
        pbDisplay(_INTL("This Pokémon is holding an item.  It can't hold mail."))
      elsif pkmn.isEgg?
        pbDisplay(_INTL("Eggs can't hold mail."))
      else
        pbDisplay(_INTL("Mail was transferred from the Mailbox."))
        pkmn.mail = $PokemonGlobal.mailbox[mailIndex]
        pkmn.setItem(pkmn.mail.item)
        $PokemonGlobal.mailbox.delete_at(mailIndex)
        pbRefreshSingle(pkmnid)
      end
    end
    @scene.pbEndScene
  end

  def pbStartScene(helptext, doublebattle, annotations = nil)
    @scene.pbStartScene(@party, helptext, annotations)
  end

  def pbSetHelpText(helptext)
    @scene.pbSetHelpText(helptext)
  end

  def pbChoosePokemon(helptext = nil, shortcut_keys: false)
    @scene.pbSetHelpText(helptext) if helptext
    return @scene.pbChoosePokemon(shortcut_keys: shortcut_keys)
  end

  def pbChooseMove(pokemon, helptext)
    movenames = []
    for i in pokemon.moves
      break if i.move.nil?

      if i.totalpp == 0
        movenames.push(_INTL("{1} (PP: ---)", getMoveName(i.move), i.pp, i.totalpp))
      else
        movenames.push(_INTL("{1} (PP: {2}/{3})", getMoveName(i.move), i.pp, i.totalpp))
      end
    end
    return @scene.pbShowCommands(helptext, movenames)
  end

  def pbEndScene
    @scene.pbEndScene
  end

  def pbHideCommands
    @scene.sprites["helpwindow"].visible = false
  end

  # Checks for identical species
  def pbCheckSpecies(array)
    for i in 0...array.length
      for j in i + 1...array.length
        return false if array[i].species == array[j].species
      end
    end
    return true
  end

  # Checks for identical held items
  def pbCheckItems(array)
    for i in 0...array.length
      next if !array[i].hasAnItem?

      for j in i + 1...array.length
        return false if array[i].item == array[j].item
      end
    end
    return true
  end

  def pbPokemonMultipleEntryScreenEx(ruleset)
    annot = []
    statuses = []
    ordinals = [
      _INTL("INELIGIBLE"),
      _INTL("NOT ENTERED"),
      _INTL("BANNED"),
      _INTL("FIRST"),
      _INTL("SECOND"),
      _INTL("THIRD"),
      _INTL("FOURTH"),
      _INTL("FIFTH"),
      _INTL("SIXTH")
    ]
    if !ruleset.hasValidTeam?(@party)
      return nil
    end

    ret = nil
    addedEntry = false
    for i in 0...@party.length
      if ruleset.isPokemonValid?(@party[i])
        statuses[i] = 1
      else
        statuses[i] = 2
      end
    end
    for i in 0...@party.length
      annot[i] = ordinals[statuses[i]]
    end
    if Rejuv
      if ruleset.minLength == ruleset.number
        @scene.pbStartScene(@party, _INTL("Choose {1} Pokémon and confirm.", ruleset.number), annot, true)
      else
        @scene.pbStartScene(@party, _INTL("Choose up to {1} Pokémon and confirm.", ruleset.number), annot, true)
      end
    else
      @scene.pbStartScene(@party, _INTL("Choose Pokémon and confirm."), annot, true)
    end
    loop do
      realorder = []
      for i in 0...@party.length
        for j in 0...@party.length
          if statuses[j] == i + 3
            realorder.push(j)
            break
          end
        end
      end
      for i in 0...realorder.length
        statuses[realorder[i]] = i + 3
      end
      for i in 0...@party.length
        annot[i] = ordinals[statuses[i]]
      end
      @scene.pbAnnotate(annot, true)
      if realorder.length == ruleset.number && addedEntry
        @scene.pbSelect(6)
      end
      if Rejuv
        if ruleset.minLength == ruleset.number
          @scene.pbSetHelpText(_INTL("Choose {1} Pokémon and confirm.", ruleset.number))
        else
          @scene.pbSetHelpText(_INTL("Choose up to {1} Pokémon and confirm.", ruleset.number))
        end
      else
        @scene.pbSetHelpText(_INTL("Choose Pokémon and confirm."))
      end
      pkmnid = @scene.pbChoosePokemon
      addedEntry = false
      if pkmnid == 6 # Confirm was chosen
        ret = []
        for i in realorder
          ret.push(@party[i])
        end
        error = []
        if !ruleset.isValid?(ret, error)
          pbDisplay(error[0])
          ret = nil
        else
          break
        end
      end
      if pkmnid < 0 # Canceled
        break
      end

      cmdEntry = -1
      cmdNoEntry = -1
      cmdSummary = -1
      commands = []
      if (statuses[pkmnid] || 0) == 1
        commands[cmdEntry = commands.length] = _INTL("Entry")
      elsif (statuses[pkmnid] || 0) > 2
        commands[cmdNoEntry = commands.length] = _INTL("No Entry")
      end
      pkmn = @party[pkmnid]
      commands[cmdSummary = commands.length] = _INTL("Summary")
      commands[commands.length] = _INTL("Cancel")
      command = @scene.pbShowCommands(_INTL("Do what with {1}?", pkmn.name), commands) if pkmn
      if cmdEntry >= 0 && command == cmdEntry
        if realorder.length >= ruleset.number && ruleset.number > 0
          pbDisplay(_INTL("No more than {1} Pokémon may enter.", ruleset.number))
        else
          statuses[pkmnid] = realorder.length + 3
          addedEntry = true
          pbRefreshSingle(pkmnid)
        end
      elsif cmdNoEntry >= 0 && command == cmdNoEntry
        statuses[pkmnid] = 1
        pbRefreshSingle(pkmnid)
      elsif cmdSummary >= 0 && command == cmdSummary
        @scene.pbSummary(pkmnid)
      end
    end
    @scene.pbEndScene
    return ret
  end

  def pbChooseAblePokemon(ableProc, allowIneligible = false, giveAway = true)
    annot = []
    eligibility = []
    for pkmn in @party
      elig = ableProc.call(pkmn)
      eligibility.push(elig)
      annot.push(elig ? _INTL("ABLE") : _INTL("NOT ABLE"))
    end
    ret = -1
    @scene.pbStartScene(@party, @party.length > 1 ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."), annot)
    loop do
      @scene.pbSetHelpText(@party.length > 1 ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."))
      pkmnid = @scene.pbChoosePokemon
      if pkmnid < 0
        break
      elsif !eligibility[pkmnid] && !allowIneligible
        pbDisplay(_INTL("This Pokémon can't be chosen."))
      else
        if giveAway
          hasOtherAblePokemon = false
          for i in 0...@party.length
            next if i == pkmnid

            hasOtherAblePokemon = true if @party[i] && !@party[i].isEgg? && @party[i].hp > 0
          end
          unless hasOtherAblePokemon
            pbDisplay(_INTL("You can't give away your last non-fainted Pokémon."))
            next
          end
        end
        ret = pkmnid
        break
      end
    end
    @scene.pbEndScene
    return ret
  end

  def pbRefreshAnnotations(ableProc) # For after using an evolution stone
    annot = []
    for pkmn in @party
      elig = ableProc.call(pkmn)
      annot.push(elig ? _INTL("ABLE") : _INTL("NOT ABLE"))
    end
    @scene.pbAnnotate(annot, false)
  end

  def duplicatePokemon(pkmn, selected)
    if pbConfirm(_INTL("Are you sure you want to copy this Pokémon?"))
      clonedpkmn = Marshal.load(Marshal.dump(pkmn))
      pbStorePokemon(clonedpkmn)
      pbHardRefresh
      pbDisplay(_INTL("The Pokémon was duplicated."))
    end
  end

  def deletePokemon(pkmnid, selected, heldpoke)
    if pbConfirm(_INTL("Are you sure you want to delete this Pokémon?"))
      @party[pkmnid] = nil
      @party.compact!
      pbHardRefresh
      pbDisplay(_INTL("The Pokémon was deleted."))
    end
  end

  def passwordUseTMX(pkmn)
    # Find TMs
    aMoves = []
    aCmds = []
    for machine in $PokemonBag.pockets[4]
      atk = pbGetTM(machine)
      if HiddenMoveHandlers.hasHandler(atk)
        aMoves.push(atk)
        # aCmds.push(_INTL("{1}: {2}", $cache.items[aItem][ITEMNAME], getMoveName(atk)))
        aCmds.push(_INTL("{1}", getMoveName(atk)))
      end
    end

    # There is no Headbutt TM
    atk = :HEADBUTT
    aMoves.push(atk)
    aCmds.push(_INTL("{1}", getMoveName(atk)))

    if Reborn
      # Adding Dig to the list
      atk = :DIG
      aMoves.push(atk)
      aCmds.push(_INTL("{1}", getMoveName(atk)))

      # Adding Teleport to the list
      atk = :TELEPORT
      aMoves.push(atk)
      aCmds.push(_INTL("{1}", getMoveName(atk)))
    end

    # Adding Sweet Scent to the list
    atk = :SWEETSCENT
    aMoves.push(atk)
    aCmds.push(_INTL("{1}", getMoveName(atk)))

    # Sort TMs
    counter = 1
    while counter < aCmds.length
      index = counter
      while index > 0
        indexPrev = index - 1

        firstName  = getMoveName(aMoves[indexPrev])
        secondName = getMoveName(aMoves[index])

        firstName = "AAAA" if firstName == "Fly"
        secondName = "AAAA" if secondName == "Fly"

        if firstName > secondName
          aux               = aCmds[index]
          aCmds[index]      = aCmds[indexPrev]
          aCmds[indexPrev]  = aux

          aux               = aMoves[index]
          aMoves[index]     = aMoves[indexPrev]
          aMoves[indexPrev] = aux
        end
        index -= 1
      end
      counter += 1
    end

    # Add "None"
    aMoves = aMoves + [-1]
    aCmds = aCmds + ["None"]

    iC = Kernel.pbMessage(_INTL("Which TM should be used?"), aCmds, aCmds.length)
    if !(aCmds[iC] == "None")
      atk = aMoves[iC]
      if Kernel.pbCanUseHiddenMove?(pkmn, atk)
        @scene.pbEndScene
        if atk == :FLY
          if $cache.mapdata[$game_map.map_id].MapPosition.is_a?(Hash)
            region = pbUnpackMapHash[0]
          else
            region = $cache.mapdata[$game_map.map_id].MapPosition[0]
          end

          if $game_switches[:Blindstep]
            ret = Blindstep.flyMenu
          else
            scene = PokemonRegionMapScene.new(region, false)
            screen = PokemonRegionMap.new(scene)
            ret = screen.pbStartFlyScreen
          end

          if ret
            $PokemonTemp.flydata = ret
            return [pkmn, atk]
          end
          @scene.pbStartScene(@party, @party.length > 1 ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."))
        else
          return [pkmn, atk]
        end
      end
    end

    return []
  end

  def pbPokemonScreen
    @scene.pbStartScene(@party, @party.length > 1 ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."), nil)
    loop do
      @scene.pbSetHelpText(@party.length > 1 ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."))
      pkmnid = @scene.pbChoosePokemon(false, true, shortcut_keys: true)
      if pkmnid.is_a?(Array) && pkmnid[0] == 1 # Switch
        @scene.pbSetHelpText(_INTL("Move to where?"))
        oldpkmnid = pkmnid[1]
        pkmnid = @scene.pbChoosePokemon(true, true, 1)
        if pkmnid >= 0 && pkmnid != oldpkmnid
          pbSwitch(oldpkmnid, pkmnid)
        end
        next
      end
      if pkmnid.is_a?(Array) && pkmnid[0] == 2 # Item
        pkmn = @party[pkmnid[1]]
        itemMenu(pkmnid[1], pkmn)
        next
      end
      if pkmnid.is_a?(Array) && pkmnid[0] == 3 # Summary
        @scene.pbSummary(pkmnid[1])
        next
      end
      if pkmnid < 0
        break
      end

      pkmn = @party[pkmnid]
      commands = []
      cmdSummary = -1
      cmdRelearn = -1
      cmdSwitch = -1
      cmdItem = -1
      cmdDebug = -1
      cmdMail = -1
      cmdRename = -1
      # Build the commands
      commands[cmdSummary = commands.length] = _INTL("Summary")
      pkmn.relearner = [pkmn.relearner, 0] if !pkmn.relearner.is_a?(Array)
      commands[cmdRelearn = commands.length] = _INTL("Relearn") if pkmn.relearner[0] == true
      if $DEBUG || (Reborn && $game_switches[:MiniDebug_Pass])
        # Commands for debug mode only
        commands[cmdDebug = commands.length] = _INTL("Debug")
      end
      if $game_switches[:EasyHMs_Password]
        acmdTMX = -1
        commands[acmdTMX = commands.length] = _INTL("Use TMX")
      end
      cmdMoves = [-1, -1, -1, -1]
      for i in 0...pkmn.moves.length
        move = pkmn.moves[i]
        # Check for hidden moves and add any that were found
        if !pkmn.isEgg? && (
           move.move == :MILKDRINK ||
           move.move == :SOFTBOILED ||
           HiddenMoveHandlers.hasHandler(move.move)
         )
          commands[cmdMoves[i] = commands.length] = getMoveName(move.move)
        end
      end
      commands[cmdSwitch = commands.length] = _INTL("Switch") if @party.length > 1
      if !pkmn.isEgg?
        if pkmn.mail
          commands[cmdMail = commands.length] = _INTL("Mail")
        else
          commands[cmdItem = commands.length] = _INTL("Item")
        end
        commands[cmdRename = commands.length] = _INTL("Rename")
      end
      commands[commands.length] = _INTL("Cancel")
      command = @scene.pbShowCommands(_INTL("Do what with {1}?", pkmn.name), commands)
      havecommand = false
      for i in 0...4
        if cmdMoves[i] >= 0 && command == cmdMoves[i]
          havecommand = true
          if pkmn.moves[i].move == :SOFTBOILED || pkmn.moves[i].move == :MILKDRINK
            if pkmn.hp <= (pkmn.totalhp / 5.0).floor
              pbDisplay(_INTL("Not enough HP..."))
              break
            end
            @scene.pbSetHelpText(_INTL("Use on which Pokémon?"))
            oldpkmnid = pkmnid
            loop do
              @scene.pbPreSelect(oldpkmnid)
              pkmnid = @scene.pbChoosePokemon(true)
              break if pkmnid < 0

              newpkmn = @party[pkmnid]
              if newpkmn.isEgg? || newpkmn.hp == 0 || newpkmn.hp == newpkmn.totalhp || pkmnid == oldpkmnid
                pbDisplay(_INTL("This item can't be used on that Pokémon."))
              else
                pkmn.hp -= (pkmn.totalhp / 5.0).floor
                hpgain = pbItemRestoreHP(newpkmn, (pkmn.totalhp / 5.0).floor)
                @scene.pbDisplay(_INTL("{1}'s HP was restored by {2} points.", newpkmn.name, hpgain))
                pbRefresh
              end
            end
            break
          elsif Kernel.pbCanUseHiddenMove?(pkmn, pkmn.moves[i].move)
            @scene.pbEndScene
            if pkmn.moves[i].move == :FLY
              if $cache.mapdata[$game_map.map_id].MapPosition.is_a?(Hash)
                region = pbUnpackMapHash[0]
              else
                region = $cache.mapdata[$game_map.map_id].MapPosition[0]
              end

              if $game_switches[:Blindstep]
                ret = Blindstep.flyMenu
              else
                scene = PokemonRegionMapScene.new(region, false)
                screen = PokemonRegionMap.new(scene)
                ret = screen.pbStartFlyScreen
              end

              if ret
                $PokemonTemp.flydata = ret
                $game_system.bgs_stop
                $game_screen.weather(0, 0, 0)
                return [pkmn, pkmn.moves[i].move]
              end
              @scene.pbStartScene(@party, @party.length > 1 ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."))
              break
            end
            return [pkmn, pkmn.moves[i].move]
          else
            break
          end
        end
      end
      if $game_switches[:EasyHMs_Password] && !pkmn.isEgg?
        if acmdTMX >= 0 && command == acmdTMX
          aRetArr = passwordUseTMX(pkmn)
          if aRetArr.length > 0
            havecommand = true
            return aRetArr
          end
        end
      end
      next if havecommand

      if cmdSummary >= 0 && command == cmdSummary
        @scene.pbSummary(pkmnid)
      elsif cmdRelearn >= 0 && command == cmdRelearn
        pbRelearnMoveScreen(pkmn)
      elsif cmdSwitch >= 0 && command == cmdSwitch
        @scene.pbSetHelpText(_INTL("Move to where?"))
        oldpkmnid = pkmnid
        pkmnid = @scene.pbChoosePokemon(true)
        if pkmnid >= 0 && pkmnid != oldpkmnid
          pbSwitch(oldpkmnid, pkmnid)
        end
      elsif cmdDebug >= 0 && command == cmdDebug
        pbPokemonDebug(self, pkmn, pkmnid)
      elsif cmdMail >= 0 && command == cmdMail
        command = @scene.pbShowCommands(_INTL("Do what with the mail?"), [_INTL("Read"), _INTL("Take"), _INTL("Cancel")])
        case command
          when 0 # Read
            pbFadeOutIn(99999) {
              pbDisplayMail(pkmn.mail, pkmn)
            }
          when 1 # Take
            pbTakeItem(pkmn)
            pbRefreshSingle(pkmnid)
        end
      elsif cmdItem >= 0 && command == cmdItem
        itemMenu(pkmnid, pkmn)
      elsif cmdRename >= 0 && command == cmdRename
        species = getMonName(pkmn.species, pkmn.form)
        $game_variables[5] = Kernel.pbMessageFreeText("#{species}'s nickname?", _INTL(""), false, 12)
        if pbGet(5) == ""
          pkmn.name = getMonName(pkmn.species, pkmn.form)
          pbSet(5, pkmn.name)
        end
        if pbGet(5) != pkmn.name
          pkmn.name = pbGet(5)
          pbDisplay(_INTL("{1} was renamed to {2}.", species, pkmn.name))
        end
      end
    end
    @scene.pbEndScene
    return nil
  end

  def itemMenu(pkmnid, pkmn)
    command = @scene.pbShowCommands(_INTL("Do what with an item?"), [_INTL("Use"), _INTL("Give"), _INTL("Take"), _INTL("Cancel")])
    case command
      when 0 # Use
        item = @scene.pbChooseItem($PokemonBag, from_bag: true)
        if !item.nil?
          pbUseItemOnPokemon(item, pkmn, self)
          pbRefreshSingle(pkmnid)
        end
      when 1 # Give
        item = @scene.pbChooseItem($PokemonBag, from_bag: true)
        if !item.nil?
          if pbIsZCrystal?(item)
            pbUseItemOnPokemon(item, pkmn, self)
          else
            pbGiveItem(item, pkmn, pkmnid)
          end
          pbRefreshSingle(pkmnid)
        end
      when 2 # Take
        pbTakeItem(pkmn)
        pbRefreshSingle(pkmnid)
    end
  end
end
