SEEDS = [:ELEMENTALSEED, :MAGICALSEED, :TELLURICSEED, :SYNTHETICSEED]
GEMS = [:FIREGEM, :WATERGEM, :ELECTRICGEM, :GRASSGEM,
        :ICEGEM, :FIGHTINGGEM, :POISONGEM, :GROUNDGEM,
        :FLYINGGEM, :PSYCHICGEM, :BUGGEM, :ROCKGEM,
        :GHOSTGEM, :DRAGONGEM, :DARKGEM, :STEELGEM,
        :NORMALGEM, :FAIRYGEM]
EVOSTONES = [:FIRESTONE, :THUNDERSTONE, :WATERSTONE,
             :LEAFSTONE, :MOONSTONE, :SUNSTONE, :DUSKSTONE,
             :DAWNSTONE, :SHINYSTONE, :LINKSTONE, :ICESTONE,
             :SWEETAPPLE, :TARTAPPLE, :CHIPPEDPOT, :CRACKEDPOT, :NIGHTMAREFUEL, :XENWASTE,
             :GALARICACUFF, :GALARICAWREATH, :BLACKAUGURITE, :PEATBLOCK]
MULCH = [:GROWTHMULCH, :DAMPMULCH, :STABLEMULCH, :GOOEYMULCH]

def getMonName(species, form = 0)
  form = 0 if !species.is_a?(Numeric) && !species.is_a?(Symbol)
  if species.is_a?(Integer)
    species = $cache.pkmn.keys[species - 1]
  end
  name = $cache.pkmn[species, form].name
  return pbGetMessageFromHash(MessageTypes::Species, name)
end

# The Pokédex classification ("Seed Pokémon") and the dex entry have their own
# message sections, but the dex screen was reading them straight off the data
# object, so both stayed English no matter what was translated.
def getMonKind(species, form = 0)
  return "" if $cache.pkmn[species, form].nil?

  return pbGetMessageFromHash(MessageTypes::Kinds, $cache.pkmn[species, form].kind)
end

def getMonDexEntry(species, form = 0)
  return "" if $cache.pkmn[species, form].nil?

  return pbGetMessageFromHash(MessageTypes::Entries, $cache.pkmn[species, form].dexentry)
end

def getItemName(item)
  if item.is_a?(Integer)
    item = $cache.items.keys[item - 1]
  end
  return pbGetMessageFromHash(MessageTypes::Items, $cache.items[item].name)
end

def getItemDescription(item)
  if item.is_a?(Integer)
    item = $cache.items.keys[item - 1]
  end
  return if item.nil?
  if pbIsTM?(item)
    return getMoveDesc(pbGetTM(item))
  end

  return pbGetMessageFromHash(MessageTypes::ItemDescriptions, $cache.items[item].desc)
end

def getTMFromMove(move)
  for item in $cache.items.keys
    next if !pbIsTM?(item)
    return $cache.items[item] if $cache.items[item].flags[:tm] == move
  end
  return nil
end

def getMoveName(move)
  movedata = $cache.moves[move]
  longname = movedata.checkFlag?(:longname, nil)
  name = longname.nil? ? movedata.name : longname
  return pbGetMessageFromHash(MessageTypes::Moves, name)
end

def getMoveShortName(move)
  return pbGetMessageFromHash(MessageTypes::Moves, $cache.moves[move].name)
end

def getMoveType(move)
  return :QMARKS if move == :FAKEMOVE

  return $cache.moves[move].type
end

def getMoveCategory(move)
  return $cache.moves[move].category
end

def getNatureName(nature)
  return "" if $cache.natures[nature].nil?

  # Natures have no message section of their own — compileNatures writes
  # natures.dat and registers nothing — but the nature-selection menu spells
  # every name out as an _INTL literal, so the script-text hash carries them.
  return pbGetMessageFromHash(MessageTypes::ScriptTexts, $cache.natures[nature].name)
end

def getMoveDesc(move)
  return "" if $cache.moves[move].nil?

  return pbGetMessageFromHash(MessageTypes::MoveDescriptions, $cache.moves[move].desc)
end

def getTypeName(type)
  return "" if $cache.types[type].nil?

  return pbGetMessageFromHash(MessageTypes::Types, $cache.types[type].name)
end

def getAbilityName(abil, short = false)
  return "" if $cache.abil[abil].nil?

  ret = short ? $cache.abil[abil].name : $cache.abil[abil].fullName
  ret = pbGetMessageFromHash(MessageTypes::Abilities, ret)
  ret = ret.gsub(/\\[Pp][Nn]/, $Trainer.name) if $Trainer
  return ret
end

# `short` picks the one-line description the stat pages use, mirroring the
# same argument on getAbilityName. Both wordings are registered in the message
# section, so either can be translated.
def getAbilityDesc(abil, short = false)
  return "" if $cache.abil[abil].nil?

  ret = short ? $cache.abil[abil].desc : $cache.abil[abil].fullDesc
  return pbGetMessageFromHash(MessageTypes::AbilityDescs, ret)
end

def pbIsHiddenMove?(move)
  return false if !$cache.items

  for i in 0...$cache.items.length
    next if !$cache.items[i]

    atk = pbGetTM(item)
    next if !atk
    return true if move == atk
  end
  return false
end

def pbGetPrice(item)
  return $cache.items[item][:price]
end

def pbGetPocket(item)
  itemdata = $cache.items[item]
  return 2 if itemdata.checkFlag?(:medicine) || itemdata.checkFlag?(:battleitem)
  return 3 if itemdata.checkFlag?(:ball)
  return 4 if itemdata.checkFlag?(:tm)
  return 5 if itemdata.checkFlag?(:berry)
  return 6 if itemdata.checkFlag?(:crystal) || itemdata.checkFlag?(:crest)
  return 7 if false
  return 8 if itemdata.checkFlag?(:keyitem)

  return 1
end

# Important items can't be sold, given to hold, or tossed.
def pbIsImportantItem?(item)
  return pbIsKeyItem?(item) || pbIsTM?(item) || pbIsZCrystal?(item) || $cache.items[item].checkFlag?(:repeatableUse)
end

def pbIsTM?(item)
  return item.nil? ? false : $cache.items[item].checkFlag?(:tm) ? true : false
end

def pbGetTM(item)
  return item.nil? ? false : $cache.items[item].checkFlag?(:tm)
end

def pbGetMachineMoveName(machine)
  return getMoveName(pbGetTM(machine))
end

def pbIsMail?(item)
  return item.nil? ? false : $cache.items[item].checkFlag?(:mail)
end

def pbIsSnagBall?(item)
  return false if $game_switches[:NotPlayerCharacter]

  return item.nil? ? false : pbIsPokeBall?(item) && $PokemonGlobal.snagMachine
end

def pbIsPokeBall?(item)
  return item.nil? ? false : $cache.items[item].checkFlag?(:ball)
end

def pbIsBerry?(item)
  return item.nil? ? false : $cache.items[item].checkFlag?(:berry)
end

def pbIsSeed?(item)
  return false if item.nil?
  return true if SEEDS.include?(item)

  return false
end

def pbIsTypeGem?(item)
  return item.nil? ? false : $cache.items[item].checkFlag?(:gem)
end

def pbIsKeyItem?(item)
  return item.nil? ? false : $cache.items[item].checkFlag?(:keyitem)
end

def pbIsZCrystal?(item)
  return item.nil? ? false : $cache.items[item].checkFlag?(:zcrystal)
end

def pbIsMegaStone?(item)
  return item.nil? ? false : $cache.items[item].checkFlag?(:crystal) && !$cache.items[item].checkFlag?(:zcrystal)
end

def pbIsEvolutionStone?(item)
  return item.nil? ? false : true if EVOSTONES.include?(item)

  return false
end

def pbIsMulch?(item)
  return item.nil? ? false : true if MULCH.include?(item)

  return false
end

def pbIsGoodItem(item)
  return false if item.nil?

  return [:CHOICEBAND, :CHOICESCARF, :CHOICESPECS, :FOCUSSASH,
          :LUCKYEGG, :EXPSHARE, :LIFEORB, :LEFTOVERS, :EVIOLITE,
          :ASSAULTVEST, :ROCKYHELMET].include?(item) || pbIsMegaStone?(item)
end

def pbTopRightWindow(text)
  return if $game_switches[:Blindstep] || $game_switches[:SpeedSkip_Password]

  window = Window_AdvancedTextPokemon.new(text)
  window.z = 99999
  window.width = 198
  window.y = 0
  window.x = Graphics.width - window.width
  pbPlayDecisionSE()
  loop do
    Graphics.update
    Input.update
    window.update
    if Input.trigger?(Input::C)
      break
    end
  end
  window.dispose
end

class ItemHandlerHash < HandlerHash
  def initialize
    super(:PBItems)
  end
end

module ItemHandlers
  UseFromBag = ItemHandlerHash.new
  UseInField = ItemHandlerHash.new
  UseOnPokemon = ItemHandlerHash.new
  BattleUseOnBattler = ItemHandlerHash.new
  BattleUseOnPokemon = ItemHandlerHash.new
  UseInBattle = ItemHandlerHash.new
  MultipleAtOnce = [
    :EXPCANDYL, :EXPCANDYXL, :EXPCANDYM, :EXPCANDYS, :EXPCANDYXS,
    :COMMONCANDY, :REVERSECANDY, :RARECANDY,
    :PHANTOMCANDYS, :PHANTOMCANDYM,
    :HPUP, :PROTEIN, :IRON, :CALCIUM, :ZINC, :CARBOS,
    :HEALTHWING, :MUSCLEWING, :RESISTWING, :GENIUSWING, :CLEVERWING, :SWIFTWING,
    :POMEGBERRY, :KELPSYBERRY, :QUALOTBERRY, :HONDEWBERRY, :GREPABERRY, :TAMATOBERRY,
  ]

  def self.addUseFromBag(item, proc)
    UseFromBag.add(item, proc)
  end

  def self.addUseInField(item, proc)
    UseInField.add(item, proc)
  end

  def self.addUseOnPokemon(item, proc)
    UseOnPokemon.add(item, proc)
  end

  def self.addBattleUseOnBattler(item, proc)
    BattleUseOnBattler.add(item, proc)
  end

  def self.addBattleUseOnPokemon(item, proc)
    BattleUseOnPokemon.add(item, proc)
  end

  def self.hasOutHandler(item) # Shows "Use" option in Bag
    return !UseFromBag[item].nil? || !UseOnPokemon[item].nil?
  end

  def self.hasKeyItemHandler(item) # Shows "Register" option in Bag
    return !UseInField[item].nil?
  end

  def self.hasBattleUseOnBattler(item)
    return !BattleUseOnBattler[item].nil?
  end

  def self.hasBattleUseOnPokemon(item)
    return !BattleUseOnPokemon[item].nil?
  end

  def self.hasUseInBattle(item)
    return !UseInBattle[item].nil?
  end

  def self.triggerUseFromBag(item)
    # Return value:
    # 0 - Item not used
    # 1 - Item used, don't end screen
    # 2 - Item used, end screen
    # 3 - Item used, consume item
    # 4 - Item used, end screen, consume item
    if !UseFromBag[item]
      # Check the UseInField handler if present
      if UseInField[item]
        UseInField.trigger(item)
        return 1 # item was used
      end
      return 0 # item was not used
    else
      UseFromBag.trigger(item)
    end
  end

  def self.triggerUseInField(item)
    # No return value
    if !UseInField[item]
      return false
    else
      UseInField.trigger(item)
      return true
    end
  end

  def self.triggerUseOnPokemon(item, pokemon, scene)
    # Returns whether item was used
    if !UseOnPokemon[item]
      return false
    else
      return UseOnPokemon.trigger(item, pokemon, scene)
    end
  end

  def self.triggerBattleUseOnBattler(item, battler, scene)
    # Returns whether item was used
    if !BattleUseOnBattler[item]
      return false
    else
      return BattleUseOnBattler.trigger(item, battler, scene)
    end
  end

  def self.triggerBattleUseOnPokemon(item, pokemon, battler, scene)
    # Returns whether item was used
    if !BattleUseOnPokemon[item]
      return false
    else
      return BattleUseOnPokemon.trigger(item, pokemon, battler, scene)
    end
  end

  def self.triggerUseInBattle(item, battler, battle)
    # Returns whether item was used
    if !UseInBattle[item]
      return
    else
      UseInBattle.trigger(item, battler, battle)
    end
  end
end

def pbItemRestoreHP(pokemon, restorehp)
  newhp = pokemon.hp + restorehp
  newhp = pokemon.totalhp if newhp > pokemon.totalhp
  hpgain = newhp - pokemon.hp
  pokemon.hp = newhp
  return hpgain
end

def pbHPItem(pokemon, restorehp, scene)
  if pokemon.hp <= 0 || pokemon.hp == pokemon.totalhp || pokemon.isEgg?
    scene.pbDisplay(_INTL("It won't have any effect."))
    return false
  else
    hpgain = pbItemRestoreHP(pokemon, restorehp)
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s HP was restored by {2} points.", pokemon.name, hpgain))
    return true
  end
end

def pbBattleHPItem(pokemon, battler, restorehp, scene)
  if pokemon.hp <= 0 || pokemon.hp == pokemon.totalhp || pokemon.isEgg?
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  else
    hpgain = pbItemRestoreHP(pokemon, restorehp)
    battler.hp = pokemon.hp if battler
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s HP was restored.", pokemon.name, hpgain))
    return true
  end
end

def pbRaiseEffortValues(pokemon, ev, evgain = 32, evlimit = true)
  totalev = pokemon.ev.sum
  evgain = 510 - totalev if totalev + evgain > 510 && !$game_switches[:No_Total_EV_Cap]
  evgain = 252 - pokemon.ev[ev] if pokemon.ev[ev] + evgain > 252
  if evgain > 0
    pokemon.ev[ev] += evgain
    pokemon.calcStats
  end
  return evgain
end

def pbRestorePP(pokemon, move, pp)
  return 0 if pokemon.moves[move].move.nil?
  return 0 if pokemon.moves[move].totalpp == 0

  newpp = pokemon.moves[move].pp + pp
  if newpp > pokemon.moves[move].totalpp
    newpp = pokemon.moves[move].totalpp
  end
  oldpp = pokemon.moves[move].pp
  pokemon.moves[move].pp = newpp
  return newpp - oldpp
end

def pbBattleRestorePP(pokemon, battler, move, pp)
  ret = pbRestorePP(pokemon, move, pp)
  if ret > 0
    battler.pbSetPP(battler.moves[move], pokemon.moves[move].pp) if battler
  end
  return ret
end

def pbBikeCheck
  if $PokemonGlobal.surfing || $PokemonGlobal.lavasurfing ||
     (!$PokemonGlobal.bicycle && (pbGetTerrainTag == PBTerrain::TallGrass || pbGetTerrainTag == PBTerrain::SandDune))
    Kernel.pbMessage(_INTL("Can't use that here."))
    return false
  end
  if $game_player.pbHasDependentEvents?
    Kernel.pbMessage(_INTL("It can't be used when you have someone with you."))
    return false
  end
  if $PokemonGlobal.bicycle
    return true
  else
    val = $cache.mapdata[$game_map.map_id].Bicycle
    val = $cache.mapdata[$game_map.map_id].Outdoor if val == nil
    if !val
      Kernel.pbMessage(_INTL("Can't use that here."))
      return false
    end
    return true
  end
end

def pbClosestHiddenItem
  result = []
  playerX = $game_player.x
  playerY = $game_player.y
  for event in $game_map.events.values
    blindstepItem = false
    if $game_switches[:Blindstep]
      character = event.nil? ? "" : event.character_name
      blindstepItem = character.start_with?("itemball") || character == "zycell"
    end
    next unless event.name == "HiddenItem" || blindstepItem
    next if (playerX - event.x).abs >= 8
    next if (playerY - event.y).abs >= 6
    next if $game_self_switches[[$game_map.map_id, event.id, "A"]]
    next if $game_self_switches[[$game_map.map_id, event.id, "B"]]
    next if $game_self_switches[[$game_map.map_id, event.id, "C"]]
    next if $game_self_switches[[$game_map.map_id, event.id, "D"]]

    result.push(event)
  end
  return nil if result.length == 0

  ret = nil
  retmin = 0
  for event in result
    dist = (playerX - event.x).abs + (playerY - event.y).abs
    if !ret || retmin > dist
      ret = event
      retmin = dist
    end
  end
  return ret
end

def Kernel.pbUseKeyItemInField(item)
  if !ItemHandlers.triggerUseInField(item)
    Kernel.pbMessage(_INTL("Can't use that here.")) if $game_switches[:Application_Applied] == false
  end
end

def pbForgetMove(pokemon, moveToLearn)
  ret = -1
  pbFadeOutIn(99999) {
    scene = PokemonSummaryScene.new
    screen = PokemonSummary.new(scene)
    ret = screen.pbStartForgetScreen([pokemon], 0, moveToLearn)
  }
  return ret
end

def pbLearnMove(pokemon, move, ignoreifknown = false, bymachine = false)
  return false if !pokemon

  movename = getMoveName(move)
  if pokemon.isEgg? && !$DEBUG
    Kernel.pbMessage(_INTL("{1} can't be taught to an Egg.", movename))
    return false
  end
  if pokemon.respond_to?("isShadow?") && pokemon.isShadow?
    Kernel.pbMessage(_INTL("{1} can't be taught to this Pokémon.", movename))
    return false
  end
  pkmnname = pokemon.name
  pkmnname["\\"] = "\\" + 00.chr if pkmnname.include?("\\")
  for i in 0...4
    if pokemon.moves[i].nil?
      pokemon.moves[i] = PBMove.new(move)
      if !(pokemon.zmoves.nil? || pokemon.item == :INTERCEPTZ)
        pokemon.updateZMoveIndex(i)
      end
      Kernel.pbMessage(_INTL("{1} learned {2}!\\se[itemlevel]", pkmnname, movename))
      return true
    end
    if pokemon.moves[i].move == move
      Kernel.pbMessage(_INTL("{1} already knows\r\n{2}.", pkmnname, movename)) if !ignoreifknown
      return false
    end
  end
  loop do
    Kernel.pbMessage(_INTL("{1} is trying to\r\nlearn {2}.\1", pkmnname, movename))
    Kernel.pbMessage(_INTL("But {1} can't learn more than four moves.\1", pkmnname))
    if Kernel.pbConfirmMessage(_INTL("Delete a move to make\r\nroom for {1}?", movename))
      Kernel.pbMessage(_INTL("Which move should be forgotten?"))
      forgetmove = pbForgetMove(pokemon, move)
      if forgetmove >= 0
        oldmovename = getMoveName(pokemon.moves[forgetmove].move)
        oldmovepp = pokemon.moves[forgetmove].pp
        pokemon.moves[forgetmove] = PBMove.new(move) # Replaces current/total PP
        if !(pokemon.zmoves.nil? || pokemon.item == :INTERCEPTZ)
          pokemon.updateZMoveIndex(forgetmove)
        end
        pokemon.moves[forgetmove].pp = [oldmovepp, pokemon.moves[forgetmove].totalpp].min if bymachine
        Kernel.pbMessage(_INTL("\\se[]1,\\wt[4] 2,\\wt[4] and...\\wt[8] ...\\wt[8] ...\\wt[8] Poof!\\se[balldrop]\1"))
        Kernel.pbMessage(_INTL("{1} forgot how to\r\nuse {2}.\1", pkmnname, oldmovename))
        Kernel.pbMessage(_INTL("And...\1"))
        Kernel.pbMessage(_INTL("\\se[]{1} learned {2}!\\se[itemlevel]", pkmnname, movename))
        return true
      elsif Kernel.pbConfirmMessage(_INTL("Should {1} stop learning {2}?", pkmnname, movename))
        Kernel.pbMessage(_INTL("{1} did not learn {2}.", pkmnname, movename))
        return false
      end
    elsif Kernel.pbConfirmMessage(_INTL("Should {1} stop learning {2}?", pkmnname, movename))
      Kernel.pbMessage(_INTL("{1} did not learn {2}.", pkmnname, movename))
      return false
    end
  end
end

def pbCheckUseOnPokemon(item, pokemon, screen)
  return pokemon && !pokemon.isEgg?
end

def pbConsumeItemInBattle(bag, item)
  if item != 0 && pbGetPocket(item) != 3 && pbGetPocket(item) != 4 && pbGetPocket(item) != 0 && pbGetPocket(item) != 6 && pbGetPocket(item) != 8
    # Delete the item just used from stock
    $PokemonBag.pbDeleteItem(item)
  end
end

def pbUseItemOnPokemon(item, pokemon, scene)
  if pbIsTM?(item)
    machine = pbGetTM(item)
    return false if machine == nil

    movename = getMoveName(machine)
    if (pokemon.isShadow? rescue false)
      Kernel.pbMessage(_INTL("Shadow Pokémon can't be taught any moves."))
    elsif !pokemon.isCompatibleWithMove?(machine)
      Kernel.pbMessage(_INTL("{1} and {2} are not compatible.", pokemon.name, movename))
      Kernel.pbMessage(_INTL("{1} can't be learned.", movename))
    else
      if $cache.items[item].checkFlag?(:tmx)
        Kernel.pbMessage(_INTL("\\se[accesspc]Booted up a TMX."))
        Kernel.pbMessage(_INTL("It contained {1}.\1", movename))
      else
        Kernel.pbMessage(_INTL("\\se[accesspc]Booted up a TM."))
        Kernel.pbMessage(_INTL("It contained {1}.\1", movename))
      end
      if Kernel.pbConfirmMessage(_INTL("Teach {1} to {2}?", movename, pokemon.name))
        if pbLearnMove(pokemon, machine, false, true)
          $PokemonBag.pbDeleteItem(item) if pbIsTM?(item) && !INFINITETMS
          return true
        end
      end
    end
    return false
  else
    ret = ItemHandlers.triggerUseOnPokemon(item, pokemon, scene)
    if ret && !pbIsZCrystal?(item)
      $PokemonBag.pbDeleteItem(item)
    end
    if $PokemonBag.pbQuantity(item) <= 0
      Kernel.pbMessage(_INTL("You used your last {1}.", getItemName(item)))
    end
    return ret
  end
  Kernel.pbMessage(_INTL("Can't use that on {1}.", pokemon.name))
  return false
end

def pbUseItem(bag, item, bagscene = nil)
  found = false
  intret = ItemHandlers.triggerUseFromBag(item)
  case intret
    when 0
      if pbGetTM(item)
        ret = true
        if $Trainer.pokemonCount == 0
          Kernel.pbMessage(_INTL("There is no Pokémon."))
          return 0
        end
        movename = pbGetMachineMoveName(item)
        if $cache.items[item].checkFlag?(:tmx)
          Kernel.pbMessage(_INTL("\\se[accesspc]Booted up a TMX."))
          Kernel.pbMessage(_INTL("It contained {1}.\1", movename))
        else
          Kernel.pbMessage(_INTL("\\se[accesspc]Booted up a TM."))
          Kernel.pbMessage(_INTL("It contained {1}.\1", movename))
        end
        if !Kernel.pbConfirmMessage(_INTL("Teach {1} to a Pokémon?", movename))
          return 0
        elsif pbMoveTutorChoose(pbGetTM(item), nil, true)
          bag.pbDeleteItem(item) if pbIsTM?(item) && !INFINITETMS
          return 1
        else
          return 0
        end
      elsif !$cache.items[item].checkFlag?(:noUse) # Item is usable on a Pokémon
        if $Trainer.pokemonCount == 0
          Kernel.pbMessage(_INTL("There is no Pokémon."))
          return 0
        end
        ret = false
        annot = nil
        if pbIsEvolutionStone?(item)
          annot = []
          for pkmn in $Trainer.party
            if item != :LINKSTONE
              elig = (!checkEvolution(pkmn, item).nil?)
              annot.push(elig ? _INTL("ABLE") : _INTL("NOT ABLE"))
            else
              elig = (!pbTradeCheckEvolution(pkmn, item, true).nil?)
              annot.push(elig ? _INTL("ABLE") : _INTL("NOT ABLE"))
            end
          end
        end
        pbFadeOutIn(99999) {
          scene = PokemonScreen_Scene.new
          screen = PokemonScreen.new(scene, $Trainer.party)
          screen.pbStartScene(_INTL("Use on which Pokémon?"), false, annot)
          loop do
            scene.pbSetHelpText(_INTL("Use on which Pokémon?"))
            chosen = screen.pbChoosePokemon
            if chosen >= 0
              pokemon = $Trainer.party[chosen]
              if !pbCheckUseOnPokemon(item, pokemon, screen)
                pbPlayBuzzerSE()
                next
              end
              # Option to use multiple of the item at once
              if ItemHandlers::MultipleAtOnce.include?(item)
                # Asking how many
                viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
                viewport.z = 99999
                helpwindow = Window_UnformattedTextPokemon.new("")
                helpwindow.viewport = viewport
                amount = UIHelper.pbChooseNumber(helpwindow, _INTL("How many do you want to use?"), bag.pbQuantity(item))
                helpwindow.dispose
                viewport.dispose
                ret = true

                # Applying it
                ret, amount_consumed = ItemHandlers::UseOnPokemon.trigger(item, pokemon, scene, amount)
                if ret # Usable on Pokémon, consumed
                  bag.pbDeleteItem(item, amount_consumed)
                end
                if bag.pbQuantity(item) <= 0
                  Kernel.pbMessage(_INTL("You used your last {1}.", getItemName(item))) if bag.pbQuantity(item) <= 0
                  break
                end
                break if !ret
              else
                ret = ItemHandlers.triggerUseOnPokemon(item, pokemon, screen)
                if ret && pbGetPocket(item) != 6 && pbGetPocket(item) != 8 && !$cache.items[item].checkFlag?(:repeatableUse)
                  bag.pbDeleteItem(item)
                end
                if bag.pbQuantity(item) <= 0
                  Kernel.pbMessage(_INTL("You used your last {1}.", getItemName(item))) if bag.pbQuantity(item) <= 0
                  break
                end
              end
            else
              ret = false
              break
            end
          end
          screen.pbEndScene
          bagscene.pbRefresh if bagscene
        }
        return ret ? 1 : 0
      end
    when 1 # Item used
      return 1
    when 2 # Item used, end screen
      return 2
    when 3 # Item used, consume item
      bag.pbDeleteItem(item)
      return 1
    when 4 # Item used, end screen and consume item
      bag.pbDeleteItem(item)
      return 2
  end
end

def Kernel.pbChooseItem(var = 0)
  ret = 0
  scene = PokemonBag_Scene.new
  screen = PokemonBagScreen.new(scene, $PokemonBag)
  pbFadeOutIn(99999) {
    ret = screen.pbChooseItemScreen
  }
  $game_variables[var] = ret if var > 0
  return ret
end

# Shows a list of items to choose from, with the chosen item's ID being stored
# in the given Global Variable. Only items which the player has are listed.
def pbChooseItemFromList(message, variable, *args)
  commands = []
  items = []
  for item in args
    if $PokemonBag.pbQuantity(item) > 0
      # The data object holds the English name; getItemName looks it up in the
      # item message section. Kernel.pbMessage cannot rescue this one - it only
      # retries through the script-text section, not the item section.
      commands.push(getItemName(item))
      items.push(item)
    end
  end
  if commands.length == 0
    $game_variables[variable] = 0
    return nil
  end
  commands.push(_INTL("Cancel"))
  items.push(nil)
  ret = Kernel.pbMessage(message, commands, -1)
  if ret < 0 || ret >= commands.length - 1
    $game_variables[variable] = -1
    return nil
  else
    $game_variables[variable] = items[ret]
    return items[ret]
  end
end
