class MoveSelectionSprite < SpriteWrapper
  attr_reader :preselected
  attr_reader :index

  def initialize(viewport = nil, fifthmove = false)
    super(viewport)
    @movesel = AnimatedBitmap.new("Graphics/Pictures/Summary/summarymovesel")
    @frame = 0
    @index = 0
    @fifthmove = fifthmove
    @preselected = false
    @updating = false
    @spriteVisible = true
    refresh
  end

  def dispose
    @movesel.dispose
    super
  end

  def index=(value)
    @index = value
    refresh
  end

  def preselected=(value)
    @preselected = value
    refresh
  end

  def visible=(value)
    super
    @spriteVisible = value if !@updating
  end

  def refresh
    w = @movesel.width
    h = @movesel.height / 2
    self.x = 240
    self.y = 92 + (self.index * 64)
    self.y -= 76 if @fifthmove
    self.y += 20 if @fifthmove && self.index == 4
    self.bitmap = @movesel.bitmap
    if self.preselected
      self.src_rect.set(0, h, w, h)
    else
      self.src_rect.set(0, 0, w, h)
    end
  end

  def update
    @updating = true
    super
    @movesel.update
    @updating = false
    refresh
  end
end

class PokemonSummaryScene
  LightBase = Color.new(248, 248, 248)
  LightShadow = Color.new(104, 104, 104)
  DarkBase = Color.new(64, 64, 64)
  DarkShadow = Color.new(176, 176, 176)
  ShinyBase = Color.new(248, 56, 32)
  ShinyShadow = Color.new(224, 152, 144)
  MissingAbilDesc = "Ability description missing!"
  MissingAbilName = "Name missing!"
  NoAbilDesc = "No effect."
  NoAbilName = "No ability"
  NotRealAbil = "Ability does not exist!"

  def pbPokerus(pkmn)
    return pkmn.pokerusStage
  end

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end

  def pbStartScene(party, partyindex)
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @party = party
    @partyindex = partyindex
    @pokemon = @party[@partyindex]
    @sprites = {}
    @sprites["background"] = IconSprite.new(0, 0, @viewport)
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["pokemon"] = PokemonSprite.new(@viewport)
    @sprites["pokemon"].setPokemonBitmap(@pokemon)
    @sprites["pokemon"].mirror = false
    @sprites["pokemon"].color = Color.new(0, 0, 0, 0)
    pbPositionPokemonSprite(@sprites["pokemon"], 40, 144)
    @sprites["pokeicon"] = PokemonBoxIcon.new(@pokemon, @viewport)
    @sprites["pokeicon"].x = 14
    @sprites["pokeicon"].y = 52
    @sprites["pokeicon"].mirror = false
    @sprites["pokeicon"].visible = false
    @sprites["movepresel"] = MoveSelectionSprite.new(@viewport)
    @sprites["movepresel"].visible = false
    @sprites["movepresel"].preselected = true
    @sprites["movesel"] = MoveSelectionSprite.new(@viewport)
    @sprites["movesel"].visible = false
    if @pokemon.species == :EXEGGUTOR && @pokemon.form == 1
      @sprites["pokemon"].y += 100
    end
    @page = 0
    @abilpage = false
    @zmovepage = false
    drawPageOne(@pokemon)
    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  def pbStartForgetScene(party, partyindex, moveToLearn)
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @party = party
    @partyindex = partyindex
    @pokemon = @party[@partyindex]
    @sprites = {}
    @page = 3
    @sprites["background"] = IconSprite.new(0, 0, @viewport)
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["pokeicon"] = PokemonBoxIcon.new(@pokemon, @viewport)
    @sprites["pokeicon"].x = 14
    @sprites["pokeicon"].y = 52
    @sprites["pokeicon"].mirror = false
    @sprites["movesel"] = MoveSelectionSprite.new(@viewport, moveToLearn != 0)
    @sprites["movesel"].visible = false
    @sprites["movesel"].visible = true
    @sprites["movesel"].index = 0
    drawSelectedMove(@pokemon, moveToLearn, @pokemon.moves[0].move)
    pbFadeInAndShow(@sprites)
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end

  def drawMarkings(bitmap, x, y, width, height, markings)
    totaltext = ""
    oldfontname = bitmap.font.name
    oldfontsize = bitmap.font.size
    oldfontcolor = bitmap.font.color
    bitmap.font.size = 24
    bitmap.font.name = "Arial"
    PokemonStorage::MARKINGCHARS.each { |item| totaltext += item }
    totalsize = bitmap.text_size(totaltext)
    realX = x + (width / 2) - (totalsize.width / 2)
    realY = y + (height / 2) - (totalsize.height / 2)
    i = 0
    PokemonStorage::MARKINGCHARS.each { |item|
      marked = (markings & (1 << i)) != 0
      bitmap.font.color = (marked) ? Color.new(72, 64, 56) : Color.new(184, 184, 160)
      itemwidth = bitmap.text_size(item).width
      bitmap.draw_text(realX, realY, itemwidth + 2, totalsize.height, item)
      realX += itemwidth
      i += 1
    }
    bitmap.font.name = oldfontname
    bitmap.font.size = oldfontsize
    bitmap.font.color = oldfontcolor
  end

  def drawPageOne(pokemon)
    if pokemon.isEgg?
      drawPageOneEgg(pokemon)
      return
    end
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    @sprites["background"].setBitmap("Graphics/Pictures/Summary/summary1")
    imagepos = []
    if pbPokerus(pokemon) == 1 || pokemon.hp == 0 || !@pokemon.status.nil?
      status = :POKERUS if pbPokerus(pokemon) == 1
      status = @pokemon.status if !@pokemon.status.nil?
      status = :FAINTED if pokemon.hp == 0
      imagepos.push([sprintf("Graphics/Pictures/Party/status%s", status), 120, 100, 0, 0, 44, 16])
    end
    if pokemon.isShiny?
      imagepos.push([sprintf("Graphics/Pictures/shiny"), 2, 134, 0, 0, -1, -1])
    end
    if pbPokerus(pokemon) == 2
      imagepos.push([sprintf("Graphics/Pictures/Summary/statusPKRS"), 176, 100, 0, 0, -1, -1])
    end
    ballused = @pokemon.ballused ? @pokemon.ballused : :POKEBALL
    ballimage = sprintf("Graphics/Pictures/Summary/summaryball" + @pokemon.ballused.to_s)
    imagepos.push([ballimage, 14, 60, 0, 0, -1, -1])
    if (pokemon.isShadow? rescue false)
      imagepos.push(["Graphics/Pictures/Summary/summaryShadow", 224, 240, 0, 0, -1, -1])
      shadowfract = pokemon.heartgauge * 1.0 / PokeBattle_Pokemon::HEARTGAUGESIZE
      imagepos.push(["Graphics/Pictures/Summary/summaryShadowBar", 242, 280, 0, 0, (shadowfract * 248).floor, -1])
    end
    pbDrawImagePositions(overlay, imagepos)
    pbSetSystemFont(overlay)
    numberbase = (pokemon.isShiny?) ? ShinyBase : DarkBase
    numbershadow = (pokemon.isShiny?) ? ShinyShadow : DarkShadow
    publicID = pokemon.publicID
    speciesname = getMonName(pokemon.species, pokemon.form)
    itemname = pokemon.hasAnItem? ? getItemName(pokemon.item) : _INTL("None")
    growthrate = pokemon.growthrate
    startexp = PBExp.startExperience(pokemon.level, growthrate)
    endexp = PBExp.startExperience(pokemon.level + 1, growthrate)
    pokename = @pokemon.name
    textpos = [
      [_INTL("INFO"), 26, 16, 0, LightBase, LightShadow],
      [pokename, 46, 62, 0, LightBase, LightShadow],
      [pokemon.level.to_s, 46, 92, 0, DarkBase, DarkShadow],
      [_INTL("Item"), 16, 320, 0, LightBase, LightShadow],
      [itemname, 16, 352, 0, DarkBase, DarkShadow],
      [_ISPRINTF("Dex No."), 238, 80, 0, LightBase, LightShadow],
      [sprintf("%03d", pokemon.dexnum), 435, 80, 2, numberbase, numbershadow],
      [_INTL("Species"), 238, 112, 0, LightBase, LightShadow],
      [speciesname, 435, 112, 2, DarkBase, DarkShadow],
      [_INTL("Type"), 238, 144, 0, LightBase, LightShadow],
      [_INTL("OT"), 238, 176, 0, LightBase, LightShadow],
      [_INTL("ID No."), 238, 208, 0, LightBase, LightShadow],
    ]
    if (pokemon.isShadow? rescue false)
      textpos.push([_INTL("Heart Gauge"), 238, 240, 0, LightBase, LightShadow])
      heartmessage = [
        _INTL("The door to its heart is open! Undo the final lock!"),
        _INTL("The door to its heart is almost fully open."),
        _INTL("The door to its heart is nearly open."),
        _INTL("The door to its heart is opening wider."),
        _INTL("The door to its heart is opening up."),
        _INTL("The door to its heart is tightly shut.")
      ][pokemon.heartStage]
      memo = sprintf("<c3=404040,B0B0B0>%s\n", heartmessage)
      drawFormattedTextEx(overlay, 238, 304, 276, memo)
    else
      textpos.push([_INTL("Exp. Points"), 238, 240, 0, LightBase, LightShadow])
      textpos.push([sprintf("%d", pokemon.exp), 488, 272, 1, DarkBase, DarkShadow])
      textpos.push([_INTL("To Next Lv."), 238, 304, 0, LightBase, LightShadow])
      textpos.push([sprintf("%d", endexp - pokemon.exp), 488, 336, 1, DarkBase, DarkShadow])
    end
    idno = (pokemon.ot == "") ? sprintf("%05d", $Trainer.publicID($Trainer.id)) : sprintf("%05d", publicID)
    if !pokemon.personalID(true).is_a?(Numeric)
      idno[rand(idno.length)] = rand(33..126).chr
      idno[rand(idno.length)] = rand(33..126).chr
    end
    textpos.push([idno, 435, 208, 2, DarkBase, DarkShadow])
    if pokemon.ot == ""
      textpos.push([$Trainer.name, 435, 176, 2, DarkBase, DarkShadow])
    elsif pokemon.fakeOT == true
      ownerbase = DarkBase
      ownershadow = DarkShadow
      name = pokemon.ot
      name = sprintf("%05s", name)
      name[rand(name.length)] = rand(33..126).chr
      name[rand(name.length)] = rand(33..126).chr
      textpos.push([name, 435, 176, 2, ownerbase, ownershadow])
    else
      ownerbase = DarkBase
      ownershadow = DarkShadow
      textpos.push([pokemon.ot, 435, 176, 2, ownerbase, ownershadow])
    end
    if pokemon.isMale?
      textpos.push([_INTL("♂"), 178, 62, 0, Color.new(24, 112, 216), Color.new(136, 168, 208)])
    elsif pokemon.isFemale?
      textpos.push([_INTL("♀"), 178, 62, 0, ShinyBase, ShinyShadow])
    end
    pbDrawTextPositions(overlay, textpos)
    drawMarkings(overlay, 15, 291, 72, 20, pokemon.markings)
    imagepos = []
    if pokemon.type2.nil?
      imagepos.push([sprintf("Graphics/Icons/type%s", pokemon.type1), 402, 146, 0, 0, 64, 28])
    else
      imagepos.push([sprintf("Graphics/Icons/type%s", pokemon.type1), 370, 146, 0, 0, 64, 28])
      imagepos.push([sprintf("Graphics/Icons/type%s", pokemon.type2), 436, 146, 0, 0, 64, 28])
    end
    pbDrawImagePositions(overlay, imagepos)
    if pokemon.level < MAXIMUMLEVEL
      overlay.fill_rect(362, 372, ((pokemon.exp - startexp) * 130 / (endexp - startexp)).clamp(0, 130), 2, Color.new(72, 120, 160))
      overlay.fill_rect(362, 374, ((pokemon.exp - startexp) * 130 / (endexp - startexp)).clamp(0, 130), 4, Color.new(24, 144, 248))
    end
  end

  def drawPageOneEgg(pokemon)
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    @sprites["background"].setBitmap("Graphics/Pictures/Summary/summaryEgg")
    imagepos = []
    ballused = @pokemon.ballused ? @pokemon.ballused : :POKEBALL
    ballimage = sprintf("Graphics/Pictures/Summary/summaryball" + @pokemon.ballused.to_s)
    imagepos.push([ballimage, 14, 60, 0, 0, -1, -1])
    pbDrawImagePositions(overlay, imagepos)
    pbSetSystemFont(overlay)
    itemname = pokemon.hasAnItem? ? getItemName(pokemon.item) : _INTL("None")
    textpos = [
      [_INTL("TRAINER MEMO"), 26, 16, 0, LightBase, LightShadow],
      [pokemon.name, 46, 62, 0, LightBase, LightShadow],
      [_INTL("Item"), 16, 320, 0, LightBase, LightShadow],
      [itemname, 16, 352, 0, DarkBase, DarkShadow],
    ]
    pbDrawTextPositions(overlay, textpos)
    memo = ""
    if pokemon.timeReceived
      month = pbGetAbbrevMonthName(pokemon.timeReceived.mon)
      date = pokemon.timeReceived.day
      year = pokemon.timeReceived.year
      memo += _INTL("<c3=404040,B0B0B0>{1} {2}, {3}\n", month, date, year)
    end
    mapname = pbGetMapNameFromId(pokemon.obtainMap)
    if (pokemon.obtainText rescue false) && pokemon.obtainText != ""
      mapname = pokemon.obtainText
    end
    if mapname && mapname != ""
      memo += _INTL("<c3=404040,B0B0B0>A mysterious Pokémon Egg received from <c3=F83820,E09890>{1}<c3=404040,B0B0B0>.\n", mapname)
    end
    memo += "<c3=404040,B0B0B0>\n"
    memo += _INTL("<c3=404040,B0B0B0>\"The Egg Watch\"\n")
    eggstate = _INTL("It looks like this Egg will take a long time to hatch.")
    eggstate = _INTL("What will hatch from this? It doesn't seem close to hatching.") if pokemon.eggsteps < 10200
    eggstate = _INTL("It appears to move occasionally. It may be close to hatching.") if pokemon.eggsteps < 2550
    eggstate = _INTL("Sounds can be heard coming from inside! It will hatch soon!") if pokemon.eggsteps < 1275
    memo += sprintf("<c3=404040,B0B0B0>%s\n", eggstate)
    drawFormattedTextEx(overlay, 232, 78, 276, memo)
    drawMarkings(overlay, 15, 291, 72, 20, pokemon.markings)
  end

  def drawAbilPage(pokemon)
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    @sprites["background"].setBitmap("Graphics/Pictures/Summary/summaryAbility")
    imagepos = []
    if pbPokerus(pokemon) == 1 || pokemon.hp == 0 || !@pokemon.status.nil?
      status = :POKERUS if pbPokerus(pokemon) == 1
      status = @pokemon.status if !@pokemon.status.nil?
      status = :FAINTED if pokemon.hp == 0
      imagepos.push([sprintf("Graphics/Pictures/Party/status%s", status), 120, 100, 0, 0, 44, 16])
    end
    if pokemon.isShiny?
      imagepos.push([sprintf("Graphics/Pictures/shiny"), 2, 134, 0, 0, -1, -1])
    end
    if pbPokerus(pokemon) == 2
      imagepos.push([sprintf("Graphics/Pictures/Summary/statusPKRS"), 176, 100, 0, 0, -1, -1])
    end
    ballused = @pokemon.ballused ? @pokemon.ballused : :POKEBALL
    ballimage = sprintf("Graphics/Pictures/Summary/summaryball" + @pokemon.ballused.to_s)
    imagepos.push([ballimage, 14, 60, 0, 0, -1, -1])
    pbDrawImagePositions(overlay, imagepos)
    pbSetSystemFont(overlay)
    naturename = $cache.natures[@pokemon.nature].name
    itemname = pokemon.hasAnItem? ? getItemName(pokemon.item) : _INTL("None")
    pokename = @pokemon.name
    textpos = [
      [_INTL("ABILITY"), 26, 16, 0, LightBase, LightShadow],
      [pokename, 46, 62, 0, LightBase, LightShadow],
      [pokemon.level.to_s, 46, 92, 0, DarkBase, DarkShadow],
      [_INTL("Item"), 16, 320, 0, LightBase, LightShadow],
      [itemname, 16, 352, 0, DarkBase, DarkShadow],
    ]
    if pokemon.isMale?
      textpos.push([_INTL("♂"), 178, 62, 0, Color.new(24, 112, 216), Color.new(136, 168, 208)])
    elsif pokemon.isFemale?
      textpos.push([_INTL("♀"), 178, 62, 0, ShinyBase, ShinyShadow])
    end
    pbDrawTextPositions(overlay, textpos)
    memo = ""
    abil = $cache.abil[@pokemon.ability]
    abilname = abil.nil? ? (@pokemon.ability.nil? ? NoAbilName : @pokemon.ability.to_s) : abil.name.nil? ? MissingAbilName : getAbilityName(@pokemon.ability)
    abildesc = abil.nil? ? (@pokemon.ability.nil? ? NoAbilDesc : NotRealAbil) : abil.desc.nil? ? MissingAbilDesc : abil.fullDesc
    memo += _INTL("<c3=F8F8F8,686868>Ability:<c3=404040,B0B0B0>\n")
    memo += _INTL("<c3=404040,B0B0B0>{1}\n", abilname)
    memo += _INTL("<c3=F8F8F8,686868>Description:\n")
    memo += _INTL("<c3=404040,B0B0B0>{1}", abildesc)
    drawFormattedTextEx(overlay, 232, 78, 272, memo)
    drawMarkings(overlay, 15, 291, 72, 20, pokemon.markings)
  end

  def drawPageTwo(pokemon)
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    @sprites["background"].setBitmap("Graphics/Pictures/Summary/summary2")
    imagepos = []
    if pbPokerus(pokemon) == 1 || pokemon.hp == 0 || !@pokemon.status.nil?
      status = :POKERUS if pbPokerus(pokemon) == 1
      status = @pokemon.status if !@pokemon.status.nil?
      status = :FAINTED if pokemon.hp == 0
      imagepos.push([sprintf("Graphics/Pictures/Party/status%s", status), 120, 100, 0, 0, 44, 16])
    end
    if pokemon.isShiny?
      imagepos.push([sprintf("Graphics/Pictures/shiny"), 2, 134, 0, 0, -1, -1])
    end
    if pbPokerus(pokemon) == 2
      imagepos.push([sprintf("Graphics/Pictures/Summary/statusPKRS"), 176, 100, 0, 0, -1, -1])
    end
    ballused = @pokemon.ballused ? @pokemon.ballused : :POKEBALL
    ballimage = sprintf("Graphics/Pictures/Summary/summaryball" + @pokemon.ballused.to_s)
    imagepos.push([ballimage, 14, 60, 0, 0, -1, -1])
    pbDrawImagePositions(overlay, imagepos)
    pbSetSystemFont(overlay)
    naturename = $cache.natures[@pokemon.nature].name
    itemname = pokemon.hasAnItem? ? getItemName(pokemon.item) : _INTL("None")
    pokename = @pokemon.name
    textpos = [
      [_INTL("TRAINER MEMO"), 26, 16, 0, LightBase, LightShadow],
      [pokename, 46, 62, 0, LightBase, LightShadow],
      [pokemon.level.to_s, 46, 92, 0, DarkBase, DarkShadow],
      [_INTL("Item"), 16, 320, 0, LightBase, LightShadow],
      [itemname, 16, 352, 0, DarkBase, DarkShadow],
    ]
    if pokemon.isMale?
      textpos.push([_INTL("♂"), 178, 62, 0, Color.new(24, 112, 216), Color.new(136, 168, 208)])
    elsif pokemon.isFemale?
      textpos.push([_INTL("♀"), 178, 62, 0, ShinyBase, ShinyShadow])
    end
    pbDrawTextPositions(overlay, textpos)
    memo = ""
    shownature = (!(pokemon.isShadow? rescue false)) || pokemon.heartStage <= 3
    if shownature
      memo += _INTL("<c3=F83820,E09890>{1}<c3=404040,B0B0B0> nature.\n", naturename)
    end
    if pokemon.timeReceived
      month = pbGetAbbrevMonthName(pokemon.timeReceived.mon)
      date = pokemon.timeReceived.day
      year = pokemon.timeReceived.year
      memo += _INTL("<c3=404040,B0B0B0>{1} {2}, {3}\n", month, date, year)
    end
    mapname = pbGetMapNameFromId(pokemon.obtainMap)
    if (pokemon.obtainText rescue false) && pokemon.obtainText != ""
      mapname = pokemon.obtainText
    end
    if mapname && mapname != ""
      memo += sprintf("<c3=F83820,E09890>%s\n", mapname)
    else
      memo += _INTL("<c3=F83820,E09890>Faraway place\n")
    end
    if pokemon.obtainMode
      mettext = [_INTL("Met at Lv. {1}.", pokemon.obtainLevel),
                 _INTL("Egg received."),
                 _INTL("Traded at Lv. {1}.", pokemon.obtainLevel),
                 "",
                 _INTL("Had a fateful encounter at Lv. {1}.", pokemon.obtainLevel)][pokemon.obtainMode]
      memo += sprintf("<c3=404040,B0B0B0>%s\n", mettext)
      if pokemon.obtainMode == 1 # hatched
        if pokemon.timeEggHatched
          month = pbGetAbbrevMonthName(pokemon.timeEggHatched.mon)
          date = pokemon.timeEggHatched.day
          year = pokemon.timeEggHatched.year
          memo += _INTL("<c3=404040,B0B0B0>{1} {2}, {3}\n", month, date, year)
        end
        mapname = pbGetMapNameFromId(pokemon.hatchedMap)
        if mapname && mapname != ""
          memo += sprintf("<c3=F83820,E09890>%s\n", mapname)
        else
          memo += _INTL("<c3=F83820,E09890>Faraway place\n")
        end
        memo += _INTL("<c3=404040,B0B0B0>Egg hatched.\n")
      else
        memo += "<c3=404040,B0B0B0>\n"
      end
    end
    if shownature
      bestiv = 0
      tiebreaker = pokemon.personalID % 6
      for i in 0...6
        if pokemon.iv[i] == pokemon.iv[bestiv]
          bestiv = i if i >= tiebreaker && bestiv < tiebreaker
        elsif pokemon.iv[i] > pokemon.iv[bestiv]
          bestiv = i
        end
      end
      characteristic = [_INTL("Loves to eat."),
                        _INTL("Often dozes off."),
                        _INTL("Often scatters things."),
                        _INTL("Scatters things often."),
                        _INTL("Likes to relax."),
                        _INTL("Proud of its power."),
                        _INTL("Likes to thrash about."),
                        _INTL("A little quick tempered."),
                        _INTL("Likes to fight."),
                        _INTL("Quick tempered."),
                        _INTL("Sturdy body."),
                        _INTL("Capable of taking hits."),
                        _INTL("Highly persistent."),
                        _INTL("Good endurance."),
                        _INTL("Good perseverance."),
                        _INTL("Likes to run."),
                        _INTL("Alert to sounds."),
                        _INTL("Impetuous and silly."),
                        _INTL("Somewhat of a clown."),
                        _INTL("Quick to flee."),
                        _INTL("Highly curious."),
                        _INTL("Mischievous."),
                        _INTL("Thoroughly cunning."),
                        _INTL("Often lost in thought."),
                        _INTL("Very finicky."),
                        _INTL("Strong willed."),
                        _INTL("Somewhat vain."),
                        _INTL("Strongly defiant."),
                        _INTL("Hates to lose."),
                        _INTL("Somewhat stubborn.")][bestiv * 5 + pokemon.iv[bestiv] % 5]
      memo += sprintf("<c3=404040,B0B0B0>%s\n", characteristic)
      # if $cache.natures[pokemon.nature].like != $cache.natures[pokemon.nature].dislike
      #  memo+=sprintf("<c3=404040,B0B0B0>It likes <c3=F83820,E09890>%s<c3=404040,B0B0B0> food.\n",$cache.natures[pokemon.nature].like)
      #  memo+=sprintf("<c3=404040,B0B0B0>It dislikes <c3=F83820,E09890>%s<c3=404040,B0B0B0> food.\n",$cache.natures[pokemon.nature].dislike)
      # else
      #  memo+=sprintf("<c3=404040,B0B0B0>It does not particularly favor any food.\n")
      # end
    end
    drawFormattedTextEx(overlay, 232, 78, 276, memo)
    drawMarkings(overlay, 15, 291, 72, 20, pokemon.markings)
  end

  def drawPageThree(pokemon)
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    @sprites["background"].setBitmap("Graphics/Pictures/Summary/summary3")
    imagepos = []
    if pbPokerus(pokemon) == 1 || pokemon.hp == 0 || !@pokemon.status.nil?
      status = :POKERUS if pbPokerus(pokemon) == 1
      status = @pokemon.status if !@pokemon.status.nil?
      status = :FAINTED if pokemon.hp == 0
      imagepos.push([sprintf("Graphics/Pictures/Party/status%s", status), 120, 100, 0, 0, 44, 16])
    end
    if pokemon.isShiny?
      imagepos.push([sprintf("Graphics/Pictures/shiny"), 2, 134, 0, 0, -1, -1])
    end
    if pbPokerus(pokemon) == 2
      imagepos.push([sprintf("Graphics/Pictures/Summary/statusPKRS"), 176, 100, 0, 0, -1, -1])
    end
    ballused = @pokemon.ballused ? @pokemon.ballused : :POKEBALL
    ballimage = sprintf("Graphics/Pictures/Summary/summaryball" + @pokemon.ballused.to_s)
    imagepos.push([ballimage, 14, 60, 0, 0, -1, -1])
    pbDrawImagePositions(overlay, imagepos)
    statshadows = []
    for i in 0...6; statshadows[i] = LightShadow; end
    if !(pokemon.isShadow? rescue false) || pokemon.heartStage <= 3
      natup = $cache.natures[pokemon.nature].incStat
      natdn = $cache.natures[pokemon.nature].decStat
      statshadows[natup] = Color.new(136, 96, 72) if natup != natdn
      statshadows[natdn] = Color.new(64, 120, 152) if natup != natdn
    end
    pbSetSystemFont(overlay)
    abil = $cache.abil[pokemon.ability]
    abilityname = abil.nil? ? (pokemon.ability.nil? ? NoAbilName : pokemon.ability.to_s) : abil.name.nil? ? MissingAbilName : getAbilityName(pokemon.ability, true)
    abilitydesc = abil.nil? ? (@pokemon.ability.nil? ? NoAbilDesc : NotRealAbil) : abil.desc.nil? ? MissingAbilDesc : abil.desc
    itemname = pokemon.hasAnItem? ? getItemName(pokemon.item) : _INTL("None")
    pokename = @pokemon.name
    textpos = [
      [_INTL("SKILLS"), 26, 16, 0, LightBase, LightShadow],
      [pokename, 46, 62, 0, LightBase, LightShadow],
      [pokemon.level.to_s, 46, 92, 0, DarkBase, DarkShadow],
      [_INTL("Item"), 16, 320, 0, LightBase, LightShadow],
      [itemname, 16, 352, 0, DarkBase, DarkShadow],
      [_INTL("HP"), 292, 76, 2, LightBase, LightShadow],
      [sprintf("%3d/%3d", pokemon.hp, pokemon.totalhp), 462, 76, 1, DarkBase, DarkShadow],
      [_INTL("Attack"), 248, 120, 0, LightBase, statshadows[PBStats::ATTACK]],
      [sprintf("%d", pokemon.attack), 456, 120, 1, DarkBase, DarkShadow],
      [_INTL("Defense"), 248, 152, 0, LightBase, statshadows[PBStats::DEFENSE]],
      [sprintf("%d", pokemon.defense), 456, 152, 1, DarkBase, DarkShadow],
      [_INTL("Sp. Atk"), 248, 184, 0, LightBase, statshadows[PBStats::SPATK]],
      [sprintf("%d", pokemon.spatk), 456, 184, 1, DarkBase, DarkShadow],
      [_INTL("Sp. Def"), 248, 216, 0, LightBase, statshadows[PBStats::SPDEF]],
      [sprintf("%d", pokemon.spdef), 456, 216, 1, DarkBase, DarkShadow],
      [_INTL("Speed"), 248, 248, 0, LightBase, statshadows[PBStats::SPEED]],
      [sprintf("%d", pokemon.speed), 456, 248, 1, DarkBase, DarkShadow],
      [_INTL("Ability"), 224, 284, 0, LightBase, LightShadow],
      [abilityname, 362, 284, 0, DarkBase, DarkShadow],
    ]
    if pokemon.isMale?
      textpos.push([_INTL("♂"), 178, 62, 0, Color.new(24, 112, 216), Color.new(136, 168, 208)])
    elsif pokemon.isFemale?
      textpos.push([_INTL("♀"), 178, 62, 0, ShinyBase, ShinyShadow])
    end
    pbDrawTextPositions(overlay, textpos)
    drawTextEx(overlay, 224, 316, 282, 2, abilitydesc, DarkBase, DarkShadow)
    drawMarkings(overlay, 15, 291, 72, 20, pokemon.markings)
    if pokemon.hp > 0
      hpcolors = [
        Color.new(24, 192, 32), Color.new(0, 144, 0), # Green
        Color.new(248, 184, 0), Color.new(184, 112, 0),   # Orange
        Color.new(240, 80, 32), Color.new(168, 48, 56)    # Red
      ]
      hpzone = 0
      hpzone = 1 if pokemon.hp <= (@pokemon.totalhp / 2.0).floor
      hpzone = 2 if pokemon.hp <= (@pokemon.totalhp / 4.0).floor
      overlay.fill_rect(360, 110, pokemon.hp * 96 / pokemon.totalhp, 2, hpcolors[hpzone * 2 + 1])
      overlay.fill_rect(360, 112, pokemon.hp * 96 / pokemon.totalhp, 4, hpcolors[hpzone * 2])
    end
  end

  def drawPageFour(pokemon)
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    @sprites["background"].setBitmap("Graphics/Pictures/Summary/summary4")
    imagepos = []
    if pbPokerus(pokemon) == 1 || pokemon.hp == 0 || !@pokemon.status.nil?
      status = :POKERUS if pbPokerus(pokemon) == 1
      status = @pokemon.status if !@pokemon.status.nil?
      status = :FAINTED if pokemon.hp == 0
      imagepos.push([sprintf("Graphics/Pictures/Party/status%s", status), 120, 100, 0, 0, 44, 16])
    end
    if pokemon.isShiny?
      imagepos.push([sprintf("Graphics/Pictures/shiny"), 2, 134, 0, 0, -1, -1])
    end
    if pbPokerus(pokemon) == 2
      imagepos.push([sprintf("Graphics/Pictures/Summary/statusPKRS"), 176, 100, 0, 0, -1, -1])
    end
    ballused = @pokemon.ballused ? @pokemon.ballused : :POKEBALL
    ballimage = sprintf("Graphics/Pictures/Summary/summaryball" + @pokemon.ballused.to_s)
    imagepos.push([ballimage, 14, 60, 0, 0, -1, -1])
    pbDrawImagePositions(overlay, imagepos)
    statshadows = []
    for i in 0...6; statshadows[i] = LightShadow; end
    if !(pokemon.isShadow? rescue false) || pokemon.heartStage <= 3
      natup = $cache.natures[pokemon.nature].incStat
      natdn = $cache.natures[pokemon.nature].decStat
      statshadows[natup] = Color.new(136, 96, 72) if natup != natdn
      statshadows[natdn] = Color.new(64, 120, 152) if natup != natdn
    end
    pbSetSystemFont(overlay)
    abil = $cache.abil[pokemon.ability]
    abilityname = abil.nil? ? (pokemon.ability.nil? ? NoAbilName : pokemon.ability.to_s) : abil.name.nil? ? MissingAbilName : getAbilityName(pokemon.ability, true)
    abilitydesc = abil.nil? ? (pokemon.ability.nil? ? NoAbilDesc : NotRealAbil) : abil.desc.nil? ? MissingAbilDesc : abil.desc
    itemname = pokemon.item.nil? ? _INTL("None") : getItemName(pokemon.item)
    pokename = @pokemon.name
    if @pokemon.name.split().last == "?" || @pokemon.name.split().last == "!"
      pokename = @pokemon.name[0..-2]
    end
    textpos = [
      [_INTL("EV & IV"), 26, 16, 0, LightBase, LightShadow],
      [pokename, 46, 62, 0, LightBase, LightShadow],
      [_INTL("{1}", pokemon.level), 46, 92, 0, DarkBase, DarkShadow],
      [_INTL("Item"), 16, 320, 0, LightBase, LightShadow],
      [itemname, 16, 352, 0, DarkBase, DarkShadow],
      [_INTL("HP"), 292, 76, 2, LightBase, LightShadow],
      [_ISPRINTF("{1:3d}/{2:3d}", pokemon.ev[0], pokemon.iv[0]), 462, 76, 1, DarkBase, DarkShadow],
      [_INTL("Attack"), 248, 120, 0, LightBase, statshadows[PBStats::ATTACK]],
      [_ISPRINTF("{1:3d}/{2:3d}", pokemon.ev[1], pokemon.iv[1]), 456, 120, 1, DarkBase, DarkShadow],
      [_INTL("Defense"), 248, 152, 0, LightBase, statshadows[PBStats::DEFENSE]],
      [_ISPRINTF("{1:3d}/{2:3d}", pokemon.ev[2], pokemon.iv[2]), 456, 152, 1, DarkBase, DarkShadow],
      [_INTL("Sp. Atk"), 248, 184, 0, LightBase, statshadows[PBStats::SPATK]],
      [_ISPRINTF("{1:3d}/{2:3d}", pokemon.ev[3], pokemon.iv[3]), 456, 184, 1, DarkBase, DarkShadow],
      [_INTL("Sp. Def"), 248, 216, 0, LightBase, statshadows[PBStats::SPDEF]],
      [_ISPRINTF("{1:3d}/{2:3d}", pokemon.ev[4], pokemon.iv[4]), 456, 216, 1, DarkBase, DarkShadow],
      [_INTL("Speed"), 248, 248, 0, LightBase, statshadows[PBStats::SPEED]],
      [_ISPRINTF("{1:3d}/{2:3d}", pokemon.ev[5], pokemon.iv[5]), 456, 248, 1, DarkBase, DarkShadow],
      [_INTL("Ability"), 224, 284, 0, LightBase, LightShadow],
      [abilityname, 362, 284, 0, DarkBase, DarkShadow],
    ]
    if pokemon.isMale?
      textpos.push([_INTL("♂"), 178, 62, 0, Color.new(24, 112, 216), Color.new(136, 168, 208)])
    elsif pokemon.isFemale?
      textpos.push([_INTL("♀"), 178, 62, 0, ShinyBase, ShinyShadow])
    end
    pbDrawTextPositions(overlay, textpos)
    drawTextEx(overlay, 224, 316, 282, 2, abilitydesc, DarkBase, DarkShadow)
    drawMarkings(overlay, 15, 291, 72, 20, pokemon.markings)
    if pokemon.hp > 0
      hpcolors = [
        Color.new(24, 192, 32), Color.new(0, 144, 0), # Green
        Color.new(248, 184, 0), Color.new(184, 112, 0),   # Orange
        Color.new(240, 80, 32), Color.new(168, 48, 56)    # Red
      ]
      hpzone = 0
      hpzone = 1 if pokemon.hp <= (@pokemon.totalhp / 2.0).floor
      hpzone = 2 if pokemon.hp <= (@pokemon.totalhp / 4.0).floor
      overlay.fill_rect(360, 110, pokemon.hp * 96 / pokemon.totalhp, 2, hpcolors[hpzone * 2 + 1])
      overlay.fill_rect(360, 112, pokemon.hp * 96 / pokemon.totalhp, 4, hpcolors[hpzone * 2])
    end
  end

  def drawPageFive(pokemon)
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    @sprites["background"].setBitmap("Graphics/Pictures/Summary/summary5")
    @sprites["pokemon"].visible = true
    @sprites["pokeicon"].visible = false
    imagepos = []
    if pbPokerus(pokemon) == 1 || pokemon.hp == 0 || !@pokemon.status.nil?
      status = :POKERUS if pbPokerus(pokemon) == 1
      status = @pokemon.status if !@pokemon.status.nil?
      status = :FAINTED if pokemon.hp == 0
      imagepos.push([sprintf("Graphics/Pictures/Party/status%s", status), 120, 100, 0, 0, 44, 16])
    end
    if pokemon.isShiny?
      imagepos.push([sprintf("Graphics/Pictures/shiny"), 2, 134, 0, 0, -1, -1])
    end
    if pbPokerus(pokemon) == 2
      imagepos.push([sprintf("Graphics/Pictures/Summary/statusPKRS"), 176, 100, 0, 0, -1, -1])
    end
    ballused = @pokemon.ballused ? @pokemon.ballused : :POKEBALL
    ballimage = sprintf("Graphics/Pictures/Summary/summaryball" + @pokemon.ballused.to_s)
    imagepos.push([ballimage, 14, 60, 0, 0, -1, -1])
    pbDrawImagePositions(overlay, imagepos)
    pbSetSystemFont(overlay)
    itemname = pokemon.hasAnItem? ? getItemName(pokemon.item) : _INTL("None")
    pokename = @pokemon.name
    textpos = [
      [_INTL("MOVES"), 26, 16, 0, LightBase, LightShadow],
      [pokename, 46, 62, 0, LightBase, LightShadow],
      [pokemon.level.to_s, 46, 92, 0, DarkBase, DarkShadow],
      [_INTL("Item"), 16, 320, 0, LightBase, LightShadow],
      [itemname, 16, 352, 0, DarkBase, DarkShadow],
    ]
    if pokemon.isMale?
      textpos.push([_INTL("♂"), 178, 62, 0, Color.new(24, 112, 216), Color.new(136, 168, 208)])
    elsif pokemon.isFemale?
      textpos.push([_INTL("♀"), 178, 62, 0, ShinyBase, ShinyShadow])
    end
    pbDrawTextPositions(overlay, textpos)
    imagepos = []
    yPos = 98
    for i in 0...pokemon.moves.length
      if pokemon.moves[i].move != nil
        imagepos.push([sprintf("Graphics/Icons/type%s", pokemon.moves[i].type), 248, yPos + 2, 0, 0, 64, 28])
        textpos.push([getMoveShortName(pokemon.moves[i].move), 316, yPos, 0, DarkBase, DarkShadow])
        if pokemon.moves[i].totalpp > 0
          textpos.push([_ISPRINTF("PP"), 342, yPos + 32, 0, DarkBase, DarkShadow])
          textpos.push([sprintf("%d/%d", pokemon.moves[i].pp, pokemon.moves[i].totalpp), 460, yPos + 32, 1, DarkBase, DarkShadow])
        end
      else
        textpos.push(["-", 316, yPos, 0, DarkBase, DarkShadow])
        textpos.push(["--", 442, yPos + 32, 1, DarkBase, DarkShadow])
      end
      yPos += 64
    end
    imagepos.push(["Graphics/Pictures/Summary/summary5zmovebtn", 324, 60, 0, 0, -1, -1]) if pokemon.zmoves != nil && pokemon.zmoves.any? {|x| x != nil}
    pbDrawTextPositions(overlay, textpos)
    pbDrawImagePositions(overlay, imagepos)
    drawMarkings(overlay, 15, 291, 72, 20, pokemon.markings)
  end

  def drawZMovePage(pokemon)
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    @sprites["background"].setBitmap("Graphics/Pictures/Summary/summary5")
    @sprites["pokemon"].visible = true
    @sprites["pokeicon"].visible = false
    imagepos = []
    if pbPokerus(pokemon) == 1 || pokemon.hp == 0 || !@pokemon.status.nil?
      status = :POKERUS if pbPokerus(pokemon) == 1
      status = @pokemon.status if !@pokemon.status.nil?
      status = :FAINTED if pokemon.hp == 0
      imagepos.push([sprintf("Graphics/Pictures/Party/status%s", status), 120, 100, 0, 0, 44, 16])
    end
    if pokemon.isShiny?
      imagepos.push([sprintf("Graphics/Pictures/shiny"), 2, 134, 0, 0, -1, -1])
    end
    if pbPokerus(pokemon) == 2
      imagepos.push([sprintf("Graphics/Pictures/Summary/statusPKRS"), 176, 100, 0, 0, -1, -1])
    end
    ballused = @pokemon.ballused ? @pokemon.ballused : :POKEBALL
    ballimage = sprintf("Graphics/Pictures/Summary/summaryball" + @pokemon.ballused.to_s)
    imagepos.push([ballimage, 14, 60, 0, 0, -1, -1])
    pbDrawImagePositions(overlay, imagepos)
    pbSetSystemFont(overlay)
    itemname = pokemon.hasAnItem? ? getItemName(pokemon.item) : _INTL("None")
    pokename = @pokemon.name
    textpos = [
      [_INTL("MOVES"), 26, 16, 0, LightBase, LightShadow],
      [pokename, 46, 62, 0, LightBase, LightShadow],
      [pokemon.level.to_s, 46, 92, 0, DarkBase, DarkShadow],
      [_INTL("Item"), 16, 320, 0, LightBase, LightShadow],
      [itemname, 16, 352, 0, DarkBase, DarkShadow],
    ]
    if pokemon.isMale?
      textpos.push([_INTL("♂"), 178, 62, 0, Color.new(24, 112, 216), Color.new(136, 168, 208)])
    elsif pokemon.isFemale?
      textpos.push([_INTL("♀"), 178, 62, 0, ShinyBase, ShinyShadow])
    end
    pbDrawTextPositions(overlay, textpos)
    imagepos = []
    yPos = 98
    for i in 0...pokemon.moves.length
      if pokemon.zmoves[i] != nil && pokemon.zmoves[i].move != nil
        imagepos.push([sprintf("Graphics/Icons/type%s", pokemon.zmoves[i].type), 248, yPos + 2, 0, 0, 64, 28])
        name = getMoveName(pokemon.zmoves[i].move)
        name = "Menace Moonraze Maelstrom" if pokemon.zmoves[i].move == :MENACINGMOONRAZEMAELSTROM
        name = "Z-" + name if $cache.moves[pokemon.zmoves[i].move].category == :status && ![:EXTREMEEVOBOOST, :ELYSIANSHIELD, :CHTHONICMALADY, :DOMAINSHIFT].include?(pokemon.zmoves[i].move)
        drawTextEx(overlay, 316, yPos - 3, 174, 2, name, DarkBase, DarkShadow)
      elsif pokemon.moves[i].move != nil
        imagepos.push([sprintf("Graphics/Icons/type%s", pokemon.moves[i].type), 248, yPos + 2, 0, 0, 64, 28])
        textpos.push([getMoveShortName(pokemon.moves[i].move), 316, yPos, 0, DarkBase, DarkShadow])
        if pokemon.moves[i].totalpp > 0
          textpos.push([_ISPRINTF("PP"), 342, yPos + 32, 0, DarkBase, DarkShadow])
          textpos.push([sprintf("%d/%d", pokemon.moves[i].pp, pokemon.moves[i].totalpp), 460, yPos + 32, 1, DarkBase, DarkShadow])
        end
      else
        textpos.push(["-", 316, yPos, 0, DarkBase, DarkShadow])
        textpos.push(["--", 442, yPos + 32, 1, DarkBase, DarkShadow])
      end
      yPos += 64
    end
    imagepos.push(["Graphics/Pictures/Summary/summary5movebtn", 324, 60, 0, 0, -1, -1])
    pbDrawTextPositions(overlay, textpos)
    pbDrawImagePositions(overlay, imagepos)
    drawMarkings(overlay, 15, 291, 72, 20, pokemon.markings)
  end

  def moveToString(move, moveobj)
    movedata = $game_switches[:Randomized_Challenge] && $Randomizer.randomMoves ? $rndcache.moves[move] : $cache.moves[move]
    string = movedata.name
    string = string + ", " + movedata.type.name + " type, "
    if movedata.category == :physical
      string = string + "Physical, "
      string = string + movedata.basedamage.to_s + " power, "
    end
    if movedata.category == :special
      string = string + "Special, "
      string = string + movedata.basedamage.to_s + " power, "
    end
    if movedata.category == :status
      string = string + "Status, "
    end
    if movedata.accuracy == 0
      string = string + "Perfect accuracy, "
    else
      string = string + movedata.accuracy.to_s + " accuracy, "
    end
    string = string + moveobj.pp.to_s + " out of " + moveobj.totalpp.to_s + " PP, "
    string = string + movedata.desc
  end

  def drawSelectedMove(pokemon, moveToLearn, move)
    overlay = @sprites["overlay"].bitmap
    @sprites["pokemon"].visible = false if @sprites["pokemon"]
    @sprites["pokeicon"].bitmap = pbPokemonIconBitmap(pokemon, pokemon.isEgg?)
    @sprites["pokeicon"].src_rect = Rect.new(0, 0, 64, 64)
    @sprites["pokeicon"].visible = true
    movedata = $game_switches[:Randomized_Challenge] && $Randomizer.randomMoves ? $rndcache.moves[move] : $cache.moves[move]
    basedamage = movedata.basedamage
    type = movedata.type
    category = movedata.category
    accuracy = movedata.accuracy
    drawMoveSelection(pokemon, moveToLearn)
    pbSetSystemFont(overlay)
    textpos = [
      [basedamage <= 1 ? basedamage == 1 ? "???" : "---" : sprintf("%d", basedamage), 216, 154, 1, DarkBase, DarkShadow],
      [accuracy == 0 ? "---" : sprintf("%d", accuracy), 216, 186, 1, DarkBase, DarkShadow]
    ]
    pbDrawTextPositions(overlay, textpos)
    cattype = 2
    case category
      when :physical then cattype = 0
      when :special  then cattype = 1
      when :status   then cattype = 2
    end
    imagepos = [["Graphics/Pictures/category", 166, 124, 0, cattype * 28, 64, 28]]
    z = @zmovepage ? "" : "z"
    imagepos.push(["Graphics/Pictures/Summary/summary5#{z}movebtn", 324, 60, 0, 0, -1, -1]) if pokemon.zmoves != nil && pokemon.zmoves.any? {|x| x != nil} && moveToLearn == 0
    pbDrawImagePositions(overlay, imagepos)
    drawTextEx(overlay, 4, 218, 238, 5, getMoveDesc(move), DarkBase, DarkShadow)
  end

  def drawSelectedZeeMove(pokemon, basemove, zmove)
    overlay = @sprites["overlay"].bitmap
    @sprites["pokemon"].visible = false if @sprites["pokemon"]
    @sprites["pokeicon"].bitmap = pbPokemonIconBitmap(pokemon, pokemon.isEgg?)
    @sprites["pokeicon"].src_rect = Rect.new(0, 0, 64, 64)
    @sprites["pokeicon"].visible = true
    basemovedata = $game_switches[:Randomized_Challenge] && $Randomizer.randomMoves ? $rndcache.moves[basemove] : $cache.moves[basemove]
    zmovedata = $game_switches[:Randomized_Challenge] && $Randomizer.randomMoves ? $rndcache.moves[zmove] : $cache.moves[zmove]
    isTypeSpecificZMove = PBStuff::TYPETOZCRYSTAL.values.include?(PBStuff::CRYSTALTOZMOVE.invert[zmove])
    basedamage = isTypeSpecificZMove ? ZMoveBaseDamage(PBMove.new(basemove)) : zmovedata.basedamage
    type = zmovedata.type
    category = isTypeSpecificZMove ? basemovedata.category : zmovedata.category
    accuracy = zmovedata.accuracy
    drawMoveSelection(pokemon, 0)
    pbSetSystemFont(overlay)
    textpos = [
      [basedamage <= 1 ? basedamage == 1 ? "???" : "---" : sprintf("%d", basedamage), 216, 154, 1, DarkBase, DarkShadow],
      [accuracy == 0 ? "---" : sprintf("%d", accuracy), 216, 186, 1, DarkBase, DarkShadow]
    ]
    pbDrawTextPositions(overlay, textpos)
    cattype = 2
    case category
      when :physical then cattype = 0
      when :special  then cattype = 1
      when :status   then cattype = 2
    end
    imagepos = [["Graphics/Pictures/category", 166, 124, 0, cattype * 28, 64, 28]]
    imagepos.push(["Graphics/Pictures/Summary/summary5movebtn", 324, 60, 0, 0, -1, -1])
    pbDrawImagePositions(overlay, imagepos)
    desc = (category != :status || [:EXTREMEEVOBOOST, :ELYSIANSHIELD, :CHTHONICMALADY, :DOMAINSHIFT].include?(zmove)) ? getMoveDesc(zmove) : getStatusZMoveDesc(basemove)
    drawTextEx(overlay, 4, 218, 238, 5, desc, DarkBase, DarkShadow)
  end

  def drawMoveSelection(pokemon, moveToLearn)
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    @sprites["background"].setBitmap("Graphics/Pictures/Summary/summary5details")
    if moveToLearn != 0
      @sprites["background"].setBitmap("Graphics/Pictures/Summary/summary5learning")
    end
    pbSetSystemFont(overlay)
    textpos = [
      [_INTL("MOVES"), 26, 16, 0, LightBase, LightShadow],
      [_INTL("CATEGORY"), 20, 122, 0, LightBase, LightShadow],
      [_INTL("POWER"), 20, 154, 0, LightBase, LightShadow],
      [_INTL("ACCURACY"), 20, 186, 0, LightBase, LightShadow]
    ]
    type1rect = Rect.new(0, 0, 64, 28)
    type2rect = Rect.new(0, 0, 64, 28)
    if pokemon.type2.nil? || pokemon.type1 == pokemon.type2
      type1image = AnimatedBitmap.new(sprintf("Graphics/Icons/type%s", pokemon.type1))
      overlay.blt(130, 78, type1image.bitmap, type1rect)
    else
      type1image = AnimatedBitmap.new(sprintf("Graphics/Icons/type%s", pokemon.type1))
      type2image = AnimatedBitmap.new(sprintf("Graphics/Icons/type%s", pokemon.type2))
      overlay.blt(96, 78, type1image.bitmap, type1rect)
      overlay.blt(166, 78, type2image.bitmap, type2rect)
    end
    imagepos = []
    yPos = 98
    yPos -= 76 if moveToLearn != 0
    for i in 0...5
      moveobject = nil
      if i == 4
        moveobject = PBMove.new(moveToLearn) if moveToLearn != 0
        yPos += 20
      else
        moveobject = (@zmovepage && !pokemon.zmoves[i].nil?) ? pokemon.zmoves[i] : pokemon.moves[i]
      end
      if moveobject
        if @zmovepage && !pokemon.zmoves[i].nil? && moveobject.move != nil
          imagepos.push([sprintf("Graphics/Icons/type%s", moveobject.type), 248, yPos + 2, 0, 0, 64, 28])
          name = getMoveName(moveobject.move)
          name = "Menace Moonraze Maelstrom" if moveobject.move == :MENACINGMOONRAZEMAELSTROM
          name = "Z-" + name if $cache.moves[moveobject.move].category == :status && ![:EXTREMEEVOBOOST, :ELYSIANSHIELD, :CHTHONICMALADY, :DOMAINSHIFT].include?(moveobject.move)
          drawTextEx(overlay, 316, yPos - 3, 174, 2, name, DarkBase, DarkShadow)
        elsif moveobject.move != nil
          imagepos.push([sprintf("Graphics/Icons/type%s", moveobject.type), 248, yPos + 2, 0, 0, 64, 28])
          textpos.push([getMoveShortName(moveobject.move), 316, yPos, 0, DarkBase, DarkShadow])
          if moveobject.totalpp > 0
            textpos.push([_ISPRINTF("PP"), 342, yPos + 32, 0, DarkBase, DarkShadow])
            textpos.push([sprintf("%d/%d", moveobject.pp, moveobject.totalpp), 460, yPos + 32, 1, DarkBase, DarkShadow])
          end
        else
          textpos.push(["-", 316, yPos, 0, DarkBase, DarkShadow])
          textpos.push(["--", 442, yPos + 32, 1, DarkBase, DarkShadow])
        end
      end
      yPos += 64
    end
    pbDrawTextPositions(overlay, textpos)
    pbDrawImagePositions(overlay, imagepos)
  end

  def pbChooseMoveToForget(moveToLearn)
    selmove = 0
    ret = 0
    maxmove = (moveToLearn != 0) ? 4 : 3
    lastread = nil
    loop do
      Graphics.update
      Input.update
      pbUpdate
      if lastread != selmove
        if selmove == 4
          readobj = PBMove.new(moveToLearn) if moveToLearn != 0
        else
          readobj = @pokemon.moves[selmove]
        end
        reading = (selmove == 4) ? moveToLearn : @pokemon.moves[selmove].move
        tts(moveToString(reading, readobj))
        lastread = selmove
      end
      if Input.trigger?(Input::B)
        ret = 4
        break
      end
      if Input.trigger?(Input::C)
        break
      end

      if Input.trigger?(Input::DOWN)
        selmove += 1
        if selmove < 4 && selmove >= @pokemon.numMoves
          selmove = (moveToLearn > 0) ? maxmove : 0
        end
        selmove = 0 if selmove > maxmove
        @sprites["movesel"].index = selmove
        newmove = (selmove == 4) ? moveToLearn : @pokemon.moves[selmove].move
        drawSelectedMove(@pokemon, moveToLearn, newmove)
        ret = selmove
      end
      if Input.trigger?(Input::UP)
        selmove -= 1
        selmove = maxmove if selmove < 0
        if selmove < 4 && selmove >= @pokemon.numMoves
          selmove = @pokemon.numMoves - 1
        end
        @sprites["movesel"].index = selmove
        newmove = (selmove == 4) ? moveToLearn : @pokemon.moves[selmove].move
        drawSelectedMove(@pokemon, moveToLearn, newmove)
        ret = selmove
      end
    end
    return (ret == 4) ? -1 : ret
  end

  def pbMoveSelection
    @sprites["movesel"].visible = true
    @sprites["movesel"].index = 0
    selmove = 0
    oldselmove = 0
    switching = false
    moves = @pokemon.moves # Remember this is a shallow copy
    zmoves = @pokemon.zmoves # Remember this is a shallow copy
    @zmovepage && !zmoves[selmove].nil? ? drawSelectedZeeMove(@pokemon, moves[selmove].move, zmoves[selmove].move) : drawSelectedMove(@pokemon, 0, moves[selmove].move)
    loop do
      Graphics.update
      Input.update
      pbUpdate
      @sprites["movepresel"].z = @sprites["movesel"].z
      @sprites["movepresel"].z += 1 if @sprites["movepresel"].index == @sprites["movesel"].index
      if Input.trigger?(Input::B)
        break if !switching
        @sprites["movepresel"].visible = false
        switching = false
      end
      if Input.trigger?(Input::C) && !(@pokemon.isShadow? rescue false)
        if !switching
          @sprites["movepresel"].index = selmove
          oldselmove = selmove
          @sprites["movepresel"].visible = true
          switching = true
        else
          tmpmove = moves[oldselmove]
          moves[oldselmove] = moves[selmove]
          moves[selmove] = tmpmove
          if !(zmoves.nil? || @pokemon.item == :INTERCEPTZ)
            tmpmove = zmoves[oldselmove]
            zmoves[oldselmove] = zmoves[selmove]
            zmoves[selmove] = tmpmove
          end
          @sprites["movepresel"].visible = false
          switching = false
          @zmovepage && !zmoves[selmove].nil? ? drawSelectedZeeMove(@pokemon, moves[selmove].move, zmoves[selmove].move) : drawSelectedMove(@pokemon, 0, moves[selmove].move)
        end
      end
      if Input.trigger?(Input::X) && zmoves != nil && zmoves.any? {|x| x != nil}
        @zmovepage = !@zmovepage
        @zmovepage && !zmoves[selmove].nil? ? drawSelectedZeeMove(@pokemon, moves[selmove].move, zmoves[selmove].move) : drawSelectedMove(@pokemon, 0, moves[selmove].move)
      end
      if Input.trigger?(Input::DOWN)
        selmove += 1
        selmove = 0 if selmove >= @pokemon.numMoves
        @sprites["movesel"].index = selmove
        pbPlayCursorSE()
        @zmovepage && !zmoves[selmove].nil? ? drawSelectedZeeMove(@pokemon, moves[selmove].move, zmoves[selmove].move) : drawSelectedMove(@pokemon, 0, moves[selmove].move)
      end
      if Input.trigger?(Input::UP)
        selmove -= 1
        selmove = @pokemon.numMoves - 1 if selmove < 0
        @sprites["movesel"].index = selmove
        pbPlayCursorSE()
        @zmovepage && !zmoves[selmove].nil? ? drawSelectedZeeMove(@pokemon, moves[selmove].move, zmoves[selmove].move) : drawSelectedMove(@pokemon, 0, moves[selmove].move)
      end
    end
    @sprites["movesel"].visible = false
  end

  def pbGoToPrevious
    newindex = @partyindex
    if newindex > 0
      while newindex > 0
        newindex -= 1
        if @party[newindex] # && !@party[newindex].isEgg?
          @partyindex = newindex
          if @party[newindex].isEgg?
            @page =  0
          end
          break
        end
        if newindex == 0
          newindex = @party.length
        end
      end
    else
      newindex = @party.length - 1
      while newindex
        if @party[newindex] # && !@party[newindex].isEgg?
          @partyindex = newindex
          if @party[newindex].isEgg?
            @page =  0
          end
          break
        end
        newindex -= 1
      end
    end
  end

  def pbGoToNext
    newindex = @partyindex
    if newindex < @party.length - 1
      while newindex < @party.length # -1
        newindex += 1
        if @party[newindex] # && !@party[newindex].isEgg?
          @partyindex = newindex
          if @party[newindex].isEgg?
            @page =  0
          end
          break
        end
        if newindex == @party.length
          newindex = -1
        end
      end
    else
      newindex = 0
      while newindex
        if @party[newindex] # && !@party[newindex].isEgg?
          @partyindex = newindex
          if @party[newindex].isEgg?
            @page =  0
          end
          break
        end
        newindex += 1
      end
    end
  end

  def pbScene
    if !@party[@partyindex].isEgg?
      pbPlayCry(@pokemon)
    end
    loop do
      Graphics.update
      Input.update
      pbUpdate
      dorefresh = false
      if Input.trigger?(Input::B)
        if @abilpage == true
          @abilpage = false
          @page == 2 ? drawPageThree(@pokemon) : drawPageFour(@pokemon)
        else
          break
        end
      end
      if Input.trigger?(Input::C)
        if @page == 0
          break
        elsif (@page == 2 || @page == 3) && !@abilpage
          @abilpage = true
          drawAbilPage(@pokemon)
        elsif @abilpage
          @abilpage = false
          @page == 2 ? drawPageThree(@pokemon) : drawPageFour(@pokemon)
        elsif @page == 4
          pbMoveSelection
          @zmovepage ? drawZMovePage(@pokemon) : drawPageFive(@pokemon)
        end
      end
      if Input.trigger?(Input::X)
        if @page == 4 && !@zmovepage && @pokemon.zmoves != nil && @pokemon.zmoves.any? {|x| x != nil}
          @zmovepage = true
          drawZMovePage(@pokemon)
        elsif @zmovepage
          @zmovepage = false
          drawPageFive(@pokemon)
        end
      end
      if Input.trigger?(Input::UP) && !@abilpage # && @partyindex>0
        pbGoToPrevious
        @pokemon = @party[@partyindex]
        @sprites["pokemon"].setPokemonBitmap(@pokemon)
        @sprites["pokemon"].color = Color.new(0, 0, 0, 0)
        pbPositionPokemonSprite(@sprites["pokemon"], 40, 144)
        if @pokemon.species == :EXEGGUTOR && @pokemon.form == 1
          @sprites["pokemon"].y += 100
        end
        dorefresh = true
        @zmovepage = false
        if !@party[@partyindex].isEgg?
          pbPlayCry(@pokemon)
        end
      end
      if Input.trigger?(Input::DOWN) && !@abilpage # && @partyindex<@party.length-1
        pbGoToNext
        @pokemon = @party[@partyindex]
        @sprites["pokemon"].setPokemonBitmap(@pokemon)
        @sprites["pokemon"].color = Color.new(0, 0, 0, 0)
        pbPositionPokemonSprite(@sprites["pokemon"], 40, 144)
        if @pokemon.species == :EXEGGUTOR && @pokemon.form == 1
          @sprites["pokemon"].y += 100
        end
        dorefresh = true
        @zmovepage = false
        if !@party[@partyindex].isEgg?
          pbPlayCry(@pokemon)
        end
      end
      if Input.trigger?(Input::LEFT) && !@pokemon.isEgg? && !@abilpage
        oldpage = @page
        @page -= 1
        @page = 4 if @page < 0
        pbPlayCursorSE()
        dorefresh = true
        @zmovepage = false
      end
      if Input.trigger?(Input::RIGHT) && !@pokemon.isEgg? && !@abilpage
        oldpage = @page
        @page += 1
        @page = 0 if @page > 4
        pbPlayCursorSE()
        dorefresh = true
        @zmovepage = false
      end
      if dorefresh
        case @page
          when 0
            drawPageOne(@pokemon)
          when 1
            drawPageTwo(@pokemon)
          when 2
            drawPageThree(@pokemon)
          when 3
            drawPageFour(@pokemon)
          when 4
            drawPageFive(@pokemon)
        end
      end
    end
    return @partyindex
  end
end

class PokemonSummary
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen(party, partyindex)
    @scene.pbStartScene(party, partyindex)
    ret = @scene.pbScene
    @scene.pbEndScene
    return ret
  end

  def pbStartForgetScreen(party, partyindex, moveToLearn)
    ret = -1
    @scene.pbStartForgetScene(party, partyindex, moveToLearn)
    loop do
      ret = @scene.pbChooseMoveToForget(moveToLearn)
      if ret >= 0 && moveToLearn != 0 && pbIsHiddenMove?(party[partyindex].moves[ret].move) && !$DEBUG
        Kernel.pbMessage(_INTL("HM moves can't be forgotten now.")) { @scene.pbUpdate }
      else
        break
      end
    end
    @scene.pbEndScene
    return ret
  end

  def pbStartChooseMoveScreen(party, partyindex, message)
    ret = -1
    @scene.pbStartForgetScene(party, partyindex, 0)
    Kernel.pbMessage(message) { @scene.pbUpdate }
    loop do
      ret = @scene.pbChooseMoveToForget(0)
      break
    end
    @scene.pbEndScene
    return ret
  end
end

def getStatusZMoveDesc(move)
  effect = PBStuff::ZSTATUSEFFECTS[move]
  if effect.length == 2
    statname = [nil, "Attack", "Defense", "Sp. Atk", "Sp. Def", "Speed", "Accuracy", "Evasion"][effect[0]]
    statamount = [nil, "", "sharply ", "drastically "][effect[1]]
    desc = "Z-Power additionally " + statamount + "raises the user's " + statname + " stat."
  elsif effect[0] == :allstat1
    desc = "Z-Power additionally raises all of the user's stats."
  elsif effect[0] == :crit1
    desc = "Z-Power additionally raises the user's critical-hit rate."
  elsif effect[0] == :reset
    desc = "Z-Power additionally eliminates any stat drops applied to the user."
  elsif effect[0] == :heal
    desc = "Z-Power additionally fully restores the user's HP."
  elsif effect[0] == :heal2
    desc = "Z-Power additionally fully restores the HP of the ally the user switches into."
  elsif effect[0] == :centre
    desc = "Z-Power additionally causes the user to become the centre of attention."
  else
    desc = "Z-Power does not grant any additional effects."
  end
  if move == :CURSE
    desc += " Ghost-type user is fully healed instead."
  elsif [:COPYCAT, :MEFIRST, :MIRRORMOVE].include?(move)
    desc += " Copied damaging move becomes a Z-Move."
  elsif [:ASSIST, :METRONOME, :NATUREPOWER, :SLEEPTALK].include?(move)
    desc += " Called damaging move becomes a Z-Move."
  end
  return desc
end
