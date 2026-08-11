#===============================================================================
# This script implements items included by default in Pokemon Essentials.
#===============================================================================

#===============================================================================
# UseFromBag handlers
# Return values: 0 = not used
#                1 = used, item not consumed
#                2 = close the Bag to use, item not consumed
#                3 = used, item consumed
#                4 = close the Bag to use, item consumed
#===============================================================================

def pbRepel(item, steps)
  if Desolation
    return 0
  elsif $PokemonGlobal.repel > 0
    Kernel.pbMessage(_INTL("But the effects of a Repel lingered from earlier."))
    return 0
  else
    Kernel.pbMessage(_INTL("{1} used the {2}.", $Trainer.name, getItemName(item)))
    $PokemonGlobal.repel = steps
    return 3
  end
end

def pbNecrozmaMoves(pokemon)
  form = pokemon.form

  moves = [
    :SUNSTEELSTRIKE,  # Dusk Mane
    :MOONGEISTBEAM    # Dawn Wings
  ]
  if pokemon.form != 3
    moves.each { |move|
      pbDeleteMoveByID(pokemon, move, false)
    }
    if form > 0
      pbLearnMove(pokemon, moves[form - 1])
    end
    if pokemon.moves.find_all { |i| i.move != 0 }.length == 0
      pbLearnMove(pokemon, :CONFUSION)
    end
  end
end

def pbKyuremMoves(pokemon)
  form = pokemon.form

  icemoves = [
    :GLACIATE,        # Normal
    :ICEBURN,         # White
    :FREEZESHOCK      # Black
  ]
  fusionmoves = [
    :SCARYFACE,       # Normal
    :FUSIONFLARE,     # White
    :FUSIONBOLT       # Black
  ]
  for i in 0...pokemon.moves.length
    if icemoves.include?(pokemon.moves[i].move)
      pokemon.moves[i] = PBMove.new(icemoves[form])
    end
    if fusionmoves.include?(pokemon.moves[i].move)
      pokemon.moves[i] = PBMove.new(fusionmoves[form])
    end
  end
end

if !Desolation
  ItemHandlers::UseFromBag.add(:REPEL, proc { |item| pbRepel(item, 200) })

  ItemHandlers::UseFromBag.add(:SUPERREPEL, proc { |item| pbRepel(item, 400) })

  ItemHandlers::UseFromBag.add(:MAXREPEL, proc { |item| pbRepel(item, 500) })
end

if Reborn
  def rainbowScent
    if !$game_switches[:FirstUse] || $game_variables[:EncounterRateModifier] == 1
      Kernel.pbMessage(_INTL('Rainbow Scent is not active.'))
    else
      Kernel.pbMessage(_INTL('Wild encounters are set to {1}%.', ($game_variables[:EncounterRateModifier] * 100).round))
    end
    selection = Kernel.pbMessage(
      _INTL('Would you like to change it?'),
      [
        _INTL('0%'),
        _INTL('10%'),
        _INTL('25%'),
        _INTL('50%'),
        _INTL('100%'),
        _INTL('10000%'),
        _INTL('Cancel'),
      ],
      -1
    )
    case selection
      when 0 then $game_variables[:EncounterRateModifier] = 0
      when 1 then $game_variables[:EncounterRateModifier] = 0.1
      when 2 then $game_variables[:EncounterRateModifier] = 0.25
      when 3 then $game_variables[:EncounterRateModifier] = 0.5
      when 4 then $game_variables[:EncounterRateModifier] = 1
      when 5 then $game_variables[:EncounterRateModifier] = 100
      else return
    end
    Kernel.pbMessage(_INTL('Wild encounters are now set to {1}%.', ($game_variables[:EncounterRateModifier] * 100).round))
    $game_switches[:FirstUse] = true
  end

  ItemHandlers::UseFromBag.add(:RAINBOWSCENT, proc { |item|
    rainbowScent
  })

  ItemHandlers::UseInField.add(:RAINBOWSCENT, proc { |item|
    rainbowScent
    next 1
  })
end

Events.onStepTaken += proc {
  if $game_player.terrain_tag != PBTerrain::Ice # Shouldn't count down if on ice
    if $PokemonGlobal.repel > 0
      $PokemonGlobal.repel -= 1
      if $PokemonGlobal.repel <= 0
        $game_switches[:Stop_Arrows_Shooting] = true
        $game_switches[:Stop_Icycle_Falling] = true
        Kernel.pbMessage(_INTL("Repel's effect wore off..."))
        if !Desolation
          ret = pbChooseItemFromList(_INTL("Do you want to use another Repel?"), 1, :REPEL, :SUPERREPEL, :MAXREPEL)
        else
          ret = nil
        end
        if ret
          pbUseItem($PokemonBag, ret)
          $game_variables[1] = 0
        end
        $game_switches[:Stop_Arrows_Shooting] = false
        $game_switches[:Stop_Icycle_Falling] = false
      end
    end
  end
}

ItemHandlers::UseFromBag.add(:BLACKFLUTE, proc { |item|
  Kernel.pbMessage(_INTL("{1} used the {2}.", $Trainer.name, getItemName(item)))
  Kernel.pbMessage(_INTL("Wild Pokémon will be repelled."))
  $PokemonMap.blackFluteUsed = true
  $PokemonMap.whiteFluteUsed = false
  next 1
})

ItemHandlers::UseFromBag.add(:WHITEFLUTE, proc { |item|
  Kernel.pbMessage(_INTL("{1} used the {2}.", $Trainer.name, getItemName(item)))
  Kernel.pbMessage(_INTL("Wild Pokémon will be lured."))
  $PokemonMap.blackFluteUsed = false
  $PokemonMap.whiteFluteUsed = true
  next 1
})

ItemHandlers::UseFromBag.add(:HONEY, proc { |item| next 4 })

ItemHandlers::UseFromBag.add(:ESCAPEROPE, proc { |item|
  if $game_player.pbHasDependentEvents?
    Kernel.pbMessage(_INTL("It can't be used when you have someone with you."))
    next
  end
  if ($PokemonGlobal.escapePoint rescue false) && $PokemonGlobal.escapePoint.length > 0
    next 4 # End screen and consume item
  else
    Kernel.pbMessage(_INTL("Can't use that here."))
    next
  end
})

ItemHandlers::UseFromBag.add(:SACREDASH, proc { |item|
  revived = 0
  if $Trainer.pokemonCount == 0
    Kernel.pbMessage(_INTL("There is no Pokémon."))
    next 0
  end
  pbFadeOutIn(99999) {
    scene = PokemonScreen_Scene.new
    screen = PokemonScreen.new(scene, $Trainer.party)
    screen.pbStartScene(_INTL("Using item..."), false)
    for i in $Trainer.party
      if i.hp <= 0 && !i.isEgg?
        revived += 1
        i.heal
        screen.pbDisplay(_INTL("{1}'s HP was restored.", i.name))
      end
   end
    if revived == 0
      screen.pbDisplay(_INTL("It won't have any effect."))
    end
    screen.pbEndScene
  }
  next (revived == 0) ? 0 : 3
})


# 0 not used, 1 used but not consumed
ItemHandlers::UseFromBag.add(:EXPALL, proc { |item|
  if Kernel.pbConfirmMessage(_INTL("Exp. All is currently ON. Would you like to turn it OFF?"))
    $game_switches[:Exp_All_On] = false
    $PokemonBag.pbChangeItem(:EXPALL, :EXPALLOFF)
    next 1
  end
})


ItemHandlers::UseFromBag.add(:EXPALLOFF, proc { |item|
  if Kernel.pbConfirmMessage(_INTL("Exp. All is currently OFF. Would you like to turn it ON?"))
    $game_switches[:Exp_All_On] = true
    $PokemonBag.pbChangeItem(:EXPALLOFF, :EXPALL)
    next 1
  end
})


ItemHandlers::UseFromBag.add(:BICYCLE, proc { |item|
  next pbBikeCheck ? 2 : nil
})

ItemHandlers::UseFromBag.add(:REMOTEPC, proc { |item|
  if $game_variables[:E4_Tracker] > 0
    Kernel.pbMessage(_INTL("Cannot use the Remote PC here."))
    next 0
  end
  if $game_switches[:NotPlayerCharacter] && !$game_switches[:InterceptorsWish]
    Kernel.pbMessage(_INTL("Cannot use the Remote PC right now."))
    next 0
  end
  if Rejuv && $game_variables[650] > 0
    Kernel.pbMessage(_INTL("ERIN: {1}, can you get off that PC and get on with the battle?", $Trainer.name))
    next 0
  end
  if $game_switches[:Free_Remote_PC]
    pbPokeCenterPC
    next 1
  end
  if $PokemonBag.pbQuantity(:CELLBATTERY) > 0
    Kernel.pbMessage(_INTL("Used a Cell Battery to power the PC."))
    $PokemonBag.pbDeleteItem(:CELLBATTERY)
    pbPokeCenterPC
    next 1
  else
    Kernel.pbMessage(_INTL("No Cell Battery to power the PC."))
    next 0
  end
})

# ItemHandlers::UseFromBag.copy(:BICYCLE,:MACHBIKE,:ACROBIKE)

ItemHandlers::UseFromBag.add(:OLDROD, proc { |item|
  terrain = Kernel.pbFacingTerrainTag
  notCliff = $game_map.passable?($game_player.x, $game_player.y, $game_player.direction)
  if ((pbIsWaterTag?(terrain) || pbIsGrimeTag?(terrain)) && !$PokemonGlobal.surfing && notCliff) ||
     (pbIsWaterTag?(terrain) && $PokemonGlobal.surfing)
    next 2
  else # lavasurfing here if lavasurfing/lavafishing
    Kernel.pbMessage(_INTL("Can't use that here."))
    next
  end
})
ItemHandlers::UseFromBag.copy(:OLDROD, :GOODROD, :SUPERROD)

ItemHandlers::UseFromBag.add(:ITEMFINDER, proc { |item| next 2 })

ItemHandlers::UseFromBag.copy(:ITEMFINDER, :DOWSINGMCHN)

ItemHandlers::UseFromBag.add(:TOWNMAP, proc { |item|
  pbShowMap(-1, false)
  next 1 # Continue
})

ItemHandlers::UseFromBag.add(:MEMBERSHIPCARD, proc { |item|
  $game_switches[:Show_Department_Card] = true
  next 2 # Close without consuming
})

ItemHandlers::UseFromBag.add(:BLUEORB3, proc { |item|
  $game_switches[:Blue_Orb_Quest] = true
  next 2 # Close without consuming
})

ItemHandlers::UseFromBag.add(:COINCASE, proc { |item|
  Kernel.pbMessage(_INTL("Coins: {1}", $PokemonGlobal.coins))
  next 1 # Continue
})

ItemHandlers::UseFromBag.add(:MONEYBAG, proc { |item|
  Kernel.pbMessage(_INTL("Rob's Funds: ${1}", $game_variables[:MoneyBag]))
  next 1 # Continue
})

ItemHandlers::UseFromBag.add(:GATHERCUBE, proc { |item|
  if Rejuv
    next 2
  else
    Kernel.pbMessage(_INTL("Z-cells gathered: {1}", $game_variables[:Z_Cells]))
  end

  next 1 # Continue
})

ItemHandlers::UseFromBag.add(:ACHIEVEMENTCARD, proc { |item|
  Kernel.pbMessage(_INTL("AP: {1}", pbCommaNumber($game_variables[:APPoints])))
  next 1 # Continue
})


ItemHandlers::UseFromBag.add(:GOLDENWINGS, proc { |item|
  if !(HIDDENMOVESCOUNTBADGES ? $Trainer.numbadges >= BADGEFORFLY : $Trainer.badges[BADGEFORFLY])
    Kernel.pbMessage(_INTL("You need more badges to use this!"))
    next
  end
  if !$PokemonBag.pbHasItem?(:HM02)
    Kernel.pbMessage(_INTL("You don't have this HM!"))
    next
  end
  if inPast?
    Kernel.pbMessage(_INTL("You are unable to fly in the past!"))
    next
  end
  if $game_switches[:NoFlyZone]
    Kernel.pbMessage(_INTL("You can't use this right now!"))
    next
  end
  if $game_player.pbHasDependentEvents?
    Kernel.pbMessage(_INTL("You can't fly when you have someone with you."))
    next
  end
  if $game_switches[:Riding_Tauros]
    Kernel.pbMessage(_INTL("You can't fly while riding a Pokemon."))
    next
  end
  if !$cache.mapdata[$game_map.map_id].Outdoor
    Kernel.pbMessage(_INTL("Can't use that here."))
    next
  end
  if $game_switches[:NotPlayerCharacter]
    Kernel.pbMessage(_INTL("Golden items cannot be used at this time."))
    next
  end
  next 2
})

ItemHandlers::UseFromBag.add(:GOLDENLANTERN, proc { |item|
  if !(HIDDENMOVESCOUNTBADGES ? $Trainer.numbadges >= BADGEFORFLASH : $Trainer.badges[BADGEFORFLASH])
    Kernel.pbMessage(_INTL("You need more badges to use this!"))
    next
  end
  if !$PokemonBag.pbHasItem?(:TM70)
    Kernel.pbMessage(_INTL("You don't have this TM!"))
    next
  end
  if !$cache.mapdata[$game_map.map_id].DarkMap
    Kernel.pbMessage(_INTL("Can't use that here."))
    next
  end
  if $PokemonGlobal.flashUsed
    Kernel.pbMessage(_INTL("This is in use already."))
    next
  end
  if $game_switches[:NotPlayerCharacter]
    Kernel.pbMessage(_INTL("Golden items cannot be used at this time."))
    next
  end
  next 2
})

#===============================================================================
# UseOnPokemon handlers
#===============================================================================

ItemHandlers::UseOnPokemon.add(:FIRESTONE, proc { |item, pokemon, scene|
  if item != :LINKSTONE && item != :LINKHEART
    newspecies = checkEvolution(pokemon, item)
  else
    newspecies = pbTradeCheckEvolution(pokemon, item)
  end
  if (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  end
  if newspecies.nil?
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pbFadeOutInWithMusic(99999) {
      evo = PokemonEvolutionScene.new
      evo.pbStartScreen(pokemon, newspecies, item)
      evo.pbEvolution(false, item)
      evo.pbEndScreen
      if item != :LINKSTONE && item != :LINKHEART
        scene.pbRefreshAnnotations(proc { |p| !checkEvolution(p, item).nil? })
      else
        scene.pbRefreshAnnotations(proc { |p| !pbTradeCheckEvolution(p, item, true).nil? })
      end
      scene.pbRefresh
    }
    next true
  end
})

ItemHandlers::UseOnPokemon.copy(
  :FIRESTONE, :THUNDERSTONE, :WATERSTONE, :LEAFSTONE, :MOONSTONE,
  :SUNSTONE, :DUSKSTONE, :DAWNSTONE, :SHINYSTONE, :LINKSTONE, :LINKHEART, :ICESTONE,
  :SWEETAPPLE, :TARTAPPLE, :CRACKEDPOT, :CHIPPEDPOT, :GALARICACUFF, :GALARICATWIG, :GALARICAWREATH,
  :BLACKAUGURITE, :PEATBLOCK, :APOPHYLLPAN, :XENWASTE, :NIGHTMAREFUEL, :ANCIENTTEACH
)

ItemHandlers::UseOnPokemon.add(:POTION, proc { |item, pokemon, scene|
  next pbHPItem(pokemon, 20, scene)
})

ItemHandlers::UseOnPokemon.add(:SUPERPOTION, proc { |item, pokemon, scene|
  next pbHPItem(pokemon, 60, scene)
})

ItemHandlers::UseOnPokemon.add(:HYPERPOTION, proc { |item, pokemon, scene|
  next pbHPItem(pokemon, 120, scene)
})

ItemHandlers::UseOnPokemon.add(:ULTRAPOTION, proc { |item, pokemon, scene|
  next pbHPItem(pokemon, 200, scene)
})

ItemHandlers::UseOnPokemon.add(:MAXPOTION, proc { |item, pokemon, scene|
  next pbHPItem(pokemon, pokemon.totalhp, scene)
})

ItemHandlers::UseOnPokemon.add(:CHINESEFOOD, proc { |item, pokemon, scene|
  next pbHPItem(pokemon, 300, scene)
})

ItemHandlers::UseOnPokemon.add(:BERRYJUICE, proc { |item, pokemon, scene|
  next pbHPItem(pokemon, 20, scene)
})

ItemHandlers::UseOnPokemon.add(:RAGECANDYBAR, proc { |item, pokemon, scene|
  if pokemon.hp <= 0 || pokemon.status.nil?
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} became healthy.", pokemon.name))
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:SWEETHEART, proc { |item, pokemon, scene|
  next pbHPItem(pokemon, 20, scene)
})

ItemHandlers::UseOnPokemon.add(:FRESHWATER, proc { |item, pokemon, scene|
  next pbHPItem(pokemon, 30, scene)
})

ItemHandlers::UseOnPokemon.add(:SODAPOP, proc { |item, pokemon, scene|
  next pbHPItem(pokemon, 50, scene)
})

ItemHandlers::UseOnPokemon.add(:LEMONADE, proc { |item, pokemon, scene|
  next pbHPItem(pokemon, 70, scene)
})

ItemHandlers::UseOnPokemon.add(:BUBBLETEA, proc { |item, pokemon, scene|
  next pbHPItem(pokemon, 180, scene)
})

ItemHandlers::UseOnPokemon.add(:MEMEONADE, proc { |item, pokemon, scene|
  next pbHPItem(pokemon, 103, scene)
})

ItemHandlers::UseOnPokemon.add(:VANILLAIC, proc { |item, pokemon, scene|
  if pbHPItem(pokemon, 30, scene)
    pokemon.changeHappiness("candy")
    next true
  end
  next false
})

ItemHandlers::UseOnPokemon.add(:CHOCOLATEIC, proc { |item, pokemon, scene|
  if pbHPItem(pokemon, 70, scene)
    pokemon.changeHappiness("candy")
    next true
  end
  next false
})

ItemHandlers::UseOnPokemon.add(:STRAWBIC, proc { |item, pokemon, scene|
  if pbHPItem(pokemon, 90, scene)
    pokemon.changeHappiness("candy")
    next true
  end
  next false
})

ItemHandlers::UseOnPokemon.add(:STRAWCAKE, proc { |item, pokemon, scene|
  next pbHPItem(pokemon, 150, scene)
})

ItemHandlers::UseOnPokemon.add(:BLUEMIC, proc { |item, pokemon, scene|
  if pbHPItem(pokemon, 200, scene)
    pokemon.changeHappiness("bluecandy")
    next true
  end
  next false
})

ItemHandlers::UseOnPokemon.add(:MOOMOOMILK, proc { |item, pokemon, scene|
  next pbHPItem(pokemon, 100, scene)
})

ItemHandlers::UseOnPokemon.add(:MAGICMILK, proc { |item, pokemon, scene|
  next pbHPItem(pokemon, 150, scene)
})

ItemHandlers::UseOnPokemon.add(:ORANBERRY, proc { |item, pokemon, scene|
  next pbHPItem(pokemon, 10, scene)
})

ItemHandlers::UseOnPokemon.add(:SITRUSBERRY, proc { |item, pokemon, scene|
  next pbHPItem(pokemon, (pokemon.totalhp / 4.0).floor, scene)
})

ItemHandlers::UseOnPokemon.add(:FIGYBERRY, proc { |item, pokemon, scene|
  next pbHPItem(pokemon, (pokemon.totalhp / (Gen <= 7 ? 2.0 : 3.0)).floor, scene)
})

ItemHandlers::UseOnPokemon.copy(:FIGYBERRY, :WIKIBERRY, :MAGOBERRY, :AGUAVBERRY, :IAPAPABERRY)

ItemHandlers::UseOnPokemon.add(:AWAKENING, proc { |item, pokemon, scene|
  if pokemon.hp <= 0 || pokemon.status != :SLEEP
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} woke up.", pokemon.name))
    next true
  end
})

ItemHandlers::UseOnPokemon.copy(:AWAKENING, :CHESTOBERRY)

ItemHandlers::UseOnPokemon.add(:BLUEFLUTE, proc { |item, pokemon, scene|
  if pokemon.hp <= 0 || pokemon.status != :SLEEP
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} woke up.", pokemon.name))
    next false
  end
})

ItemHandlers::UseOnPokemon.copy(:BLUEFLUTE, :POKEFLUTE)

ItemHandlers::UseOnPokemon.add(:ANTIDOTE, proc { |item, pokemon, scene|
  if pokemon.hp <= 0 || pokemon.status != :POISON
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} was cured of its poisoning.", pokemon.name))
    next true
  end
})

ItemHandlers::UseOnPokemon.copy(:ANTIDOTE, :PECHABERRY)

ItemHandlers::UseOnPokemon.add(:BURNHEAL, proc { |item, pokemon, scene|
  if pokemon.hp <= 0 || pokemon.status != :BURN
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s burn was healed.", pokemon.name))
    next true
  end
})

ItemHandlers::UseOnPokemon.copy(:BURNHEAL, :RAWSTBERRY)

ItemHandlers::UseOnPokemon.add(:PARLYZHEAL, proc { |item, pokemon, scene|
  if pokemon.hp <= 0 || pokemon.status != :PARALYSIS
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} was cured of paralysis.", pokemon.name))
    next true
  end
})

ItemHandlers::UseOnPokemon.copy(:PARLYZHEAL, :CHERIBERRY)

ItemHandlers::UseOnPokemon.add(:ICEHEAL, proc { |item, pokemon, scene|
  if pokemon.hp <= 0 || pokemon.status != :FROZEN
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} was thawed out.", pokemon.name))
    next true
  end
})

ItemHandlers::UseOnPokemon.copy(:ICEHEAL, :ASPEARBERRY)

ItemHandlers::UseOnPokemon.add(:FULLHEAL, proc { |item, pokemon, scene|
  if pokemon.hp <= 0 || pokemon.status.nil?
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} became healthy.", pokemon.name))
    next true
  end
})

ItemHandlers::UseOnPokemon.copy(:FULLHEAL, :LAVACOOKIE, :OLDGATEAU, :CASTELIACONE, :BIGMALASADA, :LUMBERRY, :MEDICINE)

ItemHandlers::UseOnPokemon.add(:FULLRESTORE, proc { |item, pokemon, scene|
  if pokemon.hp <= 0 || (pokemon.status.nil? && pokemon.hp == pokemon.totalhp)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    hpgain = pbItemRestoreHP(pokemon, pokemon.totalhp)
    pokemon.status = nil
    pokemon.statusCount = 0
    scene.pbRefresh
    if hpgain > 0
      scene.pbDisplay(_INTL("{1}'s HP was restored by {2} points.", pokemon.name, hpgain))
    else
      scene.pbDisplay(_INTL("{1} became healthy.", pokemon.name))
    end
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:REVIVE, proc { |item, pokemon, scene|
  if pokemon.hp > 0 || $game_switches[:Nuzlocke_Mode]
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.hp = [(pokemon.totalhp / 2.0).floor, 1].max
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s HP was restored.", pokemon.name))
    next true
  end
})

ItemHandlers::UseOnPokemon.copy(:REVIVE, :FUNNELCAKE)

ItemHandlers::UseOnPokemon.add(:PEPPERMINT, proc { |item, pokemon, scene|
  if pokemon.hp <= 0 || pokemon.status != :POISON
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    pokemon.changeHappiness("candy")
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} was cured of its poisoning.", pokemon.name))
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:CHEWINGGUM, proc { |item, pokemon, scene|
  if pokemon.hp <= 0 || pokemon.status != :PARALYSIS
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    pokemon.changeHappiness("candy")
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} was cured of its paralysis.", pokemon.name))
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:REDHOTS, proc { |item, pokemon, scene|
  if pokemon.hp <= 0 || pokemon.status != :FROZEN
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    pokemon.changeHappiness("candy")
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} thawed out.", pokemon.name))
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:SALTWATERTAFFY, proc { |item, pokemon, scene|
  if pokemon.hp <= 0 || pokemon.status != :BURN
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    pokemon.changeHappiness("candy")
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s burn was healed.", pokemon.name))
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:POPROCKS, proc { |item, pokemon, scene|
  if pokemon.hp <= 0 || pokemon.status != :SLEEP
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    pokemon.changeHappiness("candy")
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} woke up.", pokemon.name))
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:COTTONCANDY, proc { |item, pokemon, scene|
  if pokemon.hp > 0 || $game_switches[:Nuzlocke_Mode]
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.hp = [(pokemon.totalhp / 2.0).floor, 1].max
    pokemon.changeHappiness("candy")
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s HP was restored.", pokemon.name))
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:POKESNAX, proc { |item, pokemon, scene|
  if pokemon.happiness == 255
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.changeHappiness("level up")
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} ate the Pokesnax happily!", pokemon.name))
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:GOURMETTREAT, proc { |item, pokemon, scene|
  if pokemon.happiness == 255
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.changeHappiness("level up")
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} ate the Poké Candy happily!", pokemon.name))
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:MAXREVIVE, proc { |item, pokemon, scene|
  if pokemon.hp > 0 || $game_switches[:Nuzlocke_Mode]
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.hp = pokemon.totalhp
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s HP was restored.", pokemon.name))
    next true
  end
})

ItemHandlers::UseOnPokemon.copy(:MAXREVIVE, :HERBALTEA)

ItemHandlers::UseOnPokemon.add(:ENERGYPOWDER, proc { |item, pokemon, scene|
  if pbHPItem(pokemon, 60, scene)
    pokemon.changeHappiness("powder")
    next true
  end
  next false
})

ItemHandlers::UseOnPokemon.add(:ENERGYROOT, proc { |item, pokemon, scene|
  if pbHPItem(pokemon, 120, scene)
    pokemon.changeHappiness("Energy Root")
    next true
  end
  next false
})

ItemHandlers::UseOnPokemon.add(:HEALPOWDER, proc { |item, pokemon, scene|
  if pokemon.hp <= 0 || pokemon.status.nil?
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    pokemon.changeHappiness("powder")
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} became healthy.", pokemon.name))
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:REVIVALHERB, proc { |item, pokemon, scene|
  if pokemon.hp > 0 || $game_switches[:Nuzlocke_Mode]
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.hp = pokemon.totalhp
    pokemon.changeHappiness("Revival Herb")
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s HP was restored.", pokemon.name))
    next true
  end
})


ItemHandlers::BattleUseOnPokemon.add(:PEPPERMINT, proc { |item, pokemon, battler, scene|
  if pokemon.hp <= 0 || pokemon.status != :POISON
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    battler.status = nil if battler
    pokemon.changeHappiness("candy")
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} was cured of its poisoning.", pokemon.name))
    next true
  end
})

ItemHandlers::BattleUseOnPokemon.add(:CHEWINGGUM, proc { |item, pokemon, battler, scene|
  if pokemon.hp <= 0 || pokemon.status != :PARALYSIS
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    battler.status = nil if battler
    pokemon.changeHappiness("candy")
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} was cured of its paralysis.", pokemon.name))
    next true
  end
})

ItemHandlers::BattleUseOnPokemon.add(:REDHOTS, proc { |item, pokemon, battler, scene|
  if pokemon.hp <= 0 || pokemon.status != :FROZEN
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    battler.status = nil if battler
    pokemon.changeHappiness("candy")
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} thawed out.", pokemon.name))
    next true
  end
})

ItemHandlers::BattleUseOnPokemon.add(:SALTWATERTAFFY, proc { |item, pokemon, battler, scene|
  if pokemon.hp <= 0 || pokemon.status != :BURN
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    battler.status = nil if battler
    pokemon.changeHappiness("candy")
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s burn was healed.", pokemon.name))
    next true
  end
})

ItemHandlers::BattleUseOnPokemon.add(:POPROCKS, proc { |item, pokemon, battler, scene|
  if pokemon.hp <= 0 || pokemon.status != :SLEEP
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    battler.status = nil if battler
    pokemon.changeHappiness("candy")
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} woke up.", pokemon.name))
    next true
  end
})

ItemHandlers::BattleUseOnPokemon.add(:COTTONCANDY, proc { |item, pokemon, battler, scene|
  if pokemon.hp > 0 || $game_switches[:Nuzlocke_Mode]
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.hp = (pokemon.totalhp / 2.0)
    for i in 0...$Trainer.party.length
      if $Trainer.party[i] == pokemon
        battler.pbReset if battler
        # battler.pbInitialize(pokemon,i,false) if battler
        break
      end
    end
    pokemon.changeHappiness("candy")
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s HP was restored.", pokemon.name))
    next true
  end
})
ItemHandlers::UseOnPokemon.add(:ETHER, proc { |item, pokemon, scene|
  move = scene.pbChooseMove(pokemon, _INTL("Restore which move?"))
  if move >= 0
    if pbRestorePP(pokemon, move, 10) == 0
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    else
      scene.pbDisplay(_INTL("PP was restored."))
      next true
    end
  end
  next false
})

ItemHandlers::UseOnPokemon.copy(:ETHER, :LEPPABERRY)

ItemHandlers::UseOnPokemon.add(:MAXETHER, proc { |item, pokemon, scene|
  move = scene.pbChooseMove(pokemon, _INTL("Restore which move?"))
  if move >= 0
    if pbRestorePP(pokemon, move, pokemon.moves[move].totalpp - pokemon.moves[move].pp) == 0
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    else
      scene.pbDisplay(_INTL("PP was restored."))
      next true
    end
  end
  next false
})

ItemHandlers::UseOnPokemon.add(:ELIXIR, proc { |item, pokemon, scene|
  pprestored = 0
  for i in 0...pokemon.moves.length
    pprestored += pbRestorePP(pokemon, i, 10)
  end
  if pprestored == 0
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    scene.pbDisplay(_INTL("PP was restored."))
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:ROSETEA, proc { |item, pokemon, scene|
  pprestored = 0
  for i in 0...pokemon.moves.length
    pprestored += pbRestorePP(pokemon, i, 10)
  end
  if pprestored == 0
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    scene.pbDisplay(_INTL("PP was restored."))
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:MAXELIXIR, proc { |item, pokemon, scene|
  pprestored = 0
  for i in 0...pokemon.moves.length
    pprestored += pbRestorePP(pokemon, i, pokemon.moves[i].totalpp - pokemon.moves[i].pp)
  end
  if pprestored == 0
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    scene.pbDisplay(_INTL("PP was restored."))
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:PPUP, proc { |item, pokemon, scene|
  move = scene.pbChooseMove(pokemon, _INTL("Boost PP of which move?"))
  if move >= 0
    if pokemon.moves[move].totalpp == 0 || pokemon.moves[move].ppup >= 3
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    else
      pokemon.moves[move].ppup += 1
      movename = getMoveName(pokemon.moves[move].move)
      scene.pbDisplay(_INTL("{1}'s PP increased.", movename))
      next true
    end
  end
})

ItemHandlers::UseOnPokemon.add(:PPMAX, proc { |item, pokemon, scene|
  move = scene.pbChooseMove(pokemon, _INTL("Boost PP of which move?"))
  if move >= 0
    if pokemon.moves[move].totalpp == 0 || pokemon.moves[move].ppup >= 3
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    else
      pokemon.moves[move].ppup = 3
      movename = getMoveName(pokemon.moves[move].move)
      scene.pbDisplay(_INTL("{1}'s PP increased.", movename))
      next true
    end
  end
})

ItemHandlers::UseOnPokemon.add(:PPALL, proc { |item, pokemon, scene|
  numMoves = pokemon.moves.length
  for i in 0...numMoves
    hasmoves = true if pokemon.moves[i].totalpp != 0 && pokemon.moves[i].ppup < 3
  end
  if !hasmoves
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    for i in 0...numMoves
      next if pokemon.moves[i].totalpp == 0

      pokemon.moves[i].ppup = 3
    end
    scene.pbDisplay(_INTL("The PP of {1}'s moves was maximized.", pokemon.name))
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:PRISONBOTTLE, proc { |item, pokemon, scene|
  if pokemon.species == :HOOPA && pokemon.form == 0 && pokemon.hp >= 0
    pokemon.form = 1
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} changed Forme!", pokemon.name))
    next true
  elsif pokemon.species == :HOOPA && pokemon.form == 1 && pokemon.hp >= 0
    pokemon.form = 0
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} changed Forme!", pokemon.name))
    next true
  else
    scene.pbDisplay(_INTL("It had no effect."))
    next false
  end
})

##################################################################################
# Z Crystals                                                                     #
##################################################################################
ItemHandlers::UseOnPokemon.add(:NORMALIUMZ, proc { |item, pokemon, scene|
  if pokemon.item != item
    if Rejuv && $game_variables[650] > 0
      scene.pbDisplay(_INTL("You are not allowed to change the rental team's items."))
      next false
    end
    scene.pbDisplay(_INTL("The {1} will be given to {2} so that it can use its Z-Power!", getItemName(item), pokemon.name))
    if pokemon.item
      itemname = getItemName(pokemon.item)
      scene.pbDisplay(_INTL("{1} is already holding one {2}.\1", pokemon.name, itemname))
      if scene.pbConfirm(_INTL("Would you like to switch the two items?"))
        if !$PokemonBag.pbStoreItem(pokemon.item)
          scene.pbDisplay(_INTL("The Bag is full. The Pokémon's item could not be removed."))
        else
          pokemon.setItem(item)
          scene.pbDisplay(_INTL("The {1} was taken and replaced with the {2}.", itemname, getItemName(item)))
          pokemon.form = pokemon.getForm(pokemon)
          pokemon.initZmoves(item, true)
          next true
        end
      end
    else
      pokemon.setItem(item)
      scene.pbDisplay(_INTL("{1} was given the {2} to hold.", pokemon.name, getItemName(item)))
      pokemon.form = pokemon.getForm(pokemon)
      pokemon.initZmoves(item, true)
      next true
    end
  else
    itemname = getItemName(pokemon.item)
    scene.pbDisplay(_INTL("{1} is already holding one {2}.", pokemon.name, itemname))
    next false
  end
})

ItemHandlers::UseOnPokemon.copy(
  :NORMALIUMZ, :FLYINIUMZ, :GROUNDIUMZ, :BUGINIUMZ, :STEELIUMZ,
  :WATERIUMZ, :ELECTRIUMZ, :ICIUMZ, :DARKINIUMZ, :FIGHTINIUMZ, :POISONIUMZ, :ROCKIUMZ, :GHOSTIUMZ,
  :FIRIUMZ, :GRASSIUMZ, :PSYCHIUMZ, :DRAGONIUMZ, :FAIRIUMZ
)

ItemHandlers::UseOnPokemon.copy(
  :NORMALIUMZ, :ALORAICHIUMZ, :DECIDIUMZ, :INCINIUMZ, :PRIMARIUMZ,
  :EEVIUMZ, :PIKANIUMZ, :SNORLIUMZ, :MEWNIUMZ, :TAPUNIUMZ, :MARSHADIUMZ, :KOMMONIUMZ, :LYCANIUMZ,
  :MIMIKIUMZ, :SOLGANIUMZ, :LUNALIUMZ, :ULTRANECROZIUMZ, :INTERCEPTZ
)


##################################################################################

def pbChangeLevel(pokemon, newlevel, scene)
  newlevel = 1 if newlevel < 1
  newlevel = MAXIMUMLEVEL if newlevel > MAXIMUMLEVEL
  return Kernel.pbMessage(_INTL("{1}'s level remained unchanged.", pokemon.name)) if pokemon.level == newlevel

  # Stat differences
  oldlevel = pokemon.level
  attackdiff  = pokemon.attack
  defensediff = pokemon.defense
  speeddiff   = pokemon.speed
  spatkdiff   = pokemon.spatk
  spdefdiff   = pokemon.spdef
  totalhpdiff = pokemon.totalhp


  # General new level stuff
  pokemon.level = newlevel
  pokemon.exp = PBExp.startExperience(pokemon.level, pokemon.growthrate)
  pokemon.calcStats
  scene.pbRefresh

  # Change in stats
  attackdiff = pokemon.attack - attackdiff
  defensediff = pokemon.defense - defensediff
  speeddiff = pokemon.speed - speeddiff
  spatkdiff = pokemon.spatk - spatkdiff
  spdefdiff = pokemon.spdef - spdefdiff
  totalhpdiff = pokemon.totalhp - totalhpdiff

  # Message
  if oldlevel > newlevel
    Kernel.pbMessage(_INTL("{1} was downgraded to Level {2}!", pokemon.name, pokemon.level))
  else
    pokemon.changeHappiness("level up")
    Kernel.pbMessage(_INTL("{1} was elevated to Level {2}!", pokemon.name, pokemon.level))
  end

  # Show stat changes
  pbTopRightWindow(
    _INTL("Max. HP<r>{1}\r\nAttack<r>{2}\r\nDefense<r>{3}\r\nSp. Atk<r>{4}\r\nSp. Def<r>{5}\r\nSpeed<r>{6}",
          totalhpdiff, attackdiff, defensediff, spatkdiff, spdefdiff, speeddiff)
  )
  pbTopRightWindow(
    _INTL(
      "Max. HP<r>{1}\r\nAttack<r>{2}\r\nDefense<r>{3}\r\nSp. Atk<r>{4}\r\nSp. Def<r>{5}\r\nSpeed<r>{6}",
      pokemon.totalhp, pokemon.attack, pokemon.defense, pokemon.spatk, pokemon.spdef, pokemon.speed
    )
  )


  if newlevel > oldlevel
    # New moves learned in region
    movelist = pokemon.getMoveList
    for i in movelist
      if i[0] <= pokemon.level && i[0] > oldlevel
        pbLearnMove(pokemon, i[1], true)
      end
    end

    # Possible evolution
    newspecies = checkEvolution(pokemon)
    if newspecies != nil
      pbFadeOutInWithMusic(99999) {
        evo = PokemonEvolutionScene.new
        evo.pbStartScreen(pokemon, newspecies)
        evo.pbEvolution
        evo.pbEndScreen
      }
    end
  end
end

def IncreaseExp(pokemon, exp, scene) # For Exp Candies
  newexp = PBExp.addExperience(pokemon.exp, exp, pokemon.growthrate)
  exp = (newexp - pokemon.exp)
  oldlevel = pokemon.level
  if exp > 0
    scene.pbDisplay(_INTL("{1} gained {2} Exp. Points!", pokemon.name, exp))
    newlevel = PBExp.levelFromExperience(newexp, pokemon.growthrate)
    tempexp = 0
    curlevel = pokemon.level
    if newlevel < curlevel
      debuginfo = "#{pokemon.name}: #{pokemon.level}/#{newlevel} | #{pokemon.exp}/#{newexp} | gain: #{exp}"
      raise RuntimeError.new(
        _INTL(
          "The new level ({1}) is less than the Pokémon's\r\ncurrent level ({2}), which shouldn't happen.\r\n[Debug: {3}]",
          newlevel, curlevel, debuginfo
        )
      )
      return
    end
    attackdiff = pokemon.attack
    defensediff = pokemon.defense
    speeddiff = pokemon.speed
    spatkdiff = pokemon.spatk
    spdefdiff = pokemon.spdef
    totalhpdiff = pokemon.totalhp
    passedlevels = []
    loop do
      # EXP Bar increment
      startexp = PBExp.startExperience(curlevel, pokemon.growthrate)
      endexp = PBExp.startExperience(curlevel + 1, pokemon.growthrate)
      tempexp2 = (endexp < newexp) ? endexp : newexp
      pokemon.exp = tempexp2
      tempexp1 = tempexp2
      curlevel += 1
      if curlevel > newlevel
        pokemon.calcStats
        break
      else
        passedlevels.push(curlevel)
      end
      pokemon.level = newlevel
      pokemon.changeHappiness("level up")
      pokemon.calcStats
    end
    if pokemon.level > oldlevel
      attackdiff = pokemon.attack - attackdiff
      defensediff = pokemon.defense - defensediff
      speeddiff = pokemon.speed - speeddiff
      spatkdiff = pokemon.spatk - spatkdiff
      spdefdiff = pokemon.spdef - spdefdiff
      totalhpdiff = pokemon.totalhp - totalhpdiff
      scene.pbDisplay(_INTL("{1} grew to Level {2}!", pokemon.name, newlevel))
      pbTopRightWindow(
        _INTL(
          "Max. HP<r>+{1}\r\nAttack<r>+{2}\r\nDefense<r>+{3}\r\nSp. Atk<r>+{4}\r\nSp. Def<r>+{5}\r\nSpeed<r>+{6}",
          totalhpdiff, attackdiff, defensediff, spatkdiff, spdefdiff, speeddiff
        )
      )
      pbTopRightWindow(
        _INTL(
          "Max. HP<r>{1}\r\nAttack<r>{2}\r\nDefense<r>{3}\r\nSp. Atk<r>{4}\r\nSp. Def<r>{5}\r\nSpeed<r>{6}",
          pokemon.totalhp, pokemon.attack, pokemon.defense, pokemon.spatk, pokemon.spdef, pokemon.speed
        )
      )

      # New moves learned
      movelist = pokemon.getMoveList
      for j in passedlevels
        for i in movelist
          if i[0] == j
            pbLearnMove(pokemon, i[1], true)
          end
        end
      end

      # Evolution
      newspecies = checkEvolution(pokemon)
      if newspecies
        pbFadeOutInWithMusic(99999) {
          evo = PokemonEvolutionScene.new
          evo.pbStartScreen(pokemon, newspecies)
          evo.pbEvolution
          evo.pbEndScreen
        }
      end
    end
  end
end

ItemHandlers::UseOnPokemon.add(:RARECANDY, proc { |item, pokemon, scene, amount = 1|
  finallevelcap = 100 + $game_variables[:Extended_Max_Level]
  if (pokemon.isShadow? rescue false) || noExp?
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false, 0
  elsif pokemon.level >= MAXIMUMLEVEL || pokemon.level >= finallevelcap
    if checkEvolution(pokemon)
      newspecies = checkEvolution(pokemon)
      if newspecies
        pbFadeOutInWithMusic(99999) {
          evo = PokemonEvolutionScene.new
          evo.pbStartScreen(pokemon, newspecies)
          evo.pbEvolution
          evo.pbEndScreen
        }
      end
      next true, 1
    else
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false, 0
    end
  else
    amount = amount
    amount = MAXIMUMLEVEL - pokemon.level if MAXIMUMLEVEL - pokemon.level < amount
    amount = finallevelcap - pokemon.level if finallevelcap - pokemon.level < amount
    pbChangeLevel(pokemon, pokemon.level + amount, scene)
    scene.pbHardRefresh
    next true, amount
  end
})

ItemHandlers::UseOnPokemon.add(:COMMONCANDY, proc { |item, pokemon, scene, amount = 1|
  if pokemon.level == 1 || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false, 0
  else
    amount = pokemon.level - 1 if amount >= pokemon.level
    pbChangeLevel(pokemon, pokemon.level - amount, scene)
    pokemon.changeHappiness("badcandy")
    scene.pbHardRefresh
    next true, amount
  end
})
ItemHandlers::UseOnPokemon.copy(:COMMONCANDY, :REVERSECANDY)
ItemHandlers::UseOnPokemon.add(:ABILITYCAPSULE, proc { |item, pokemon, scene|
  form       = pokemon.form
  tempabil   = pokemon.abilityIndex
  abilid     = pokemon.ability
  abillist   = pokemon.getAbilityList
  name       = pokemon.getFormName

  if abillist.length == 1 || pokemon.species == :ZYGARDE
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  end

  commands = []
  command_option = []
  abils = []
  for i in 0...abillist.length
    next if abillist[i] == abilid
    next if abils.include?(abillist[i])

    commands.push((i == 0 || abillist[i] != $cache.pkmn[pokemon.species, pokemon.form].HiddenAbility ? "" : "(H) ") + getAbilityName(abillist[i]))
    command_option.push(i)
    abils.push(abillist[i])
  end

  cmd = scene.pbShowCommands(_INTL("Which ability would you like to change to?"), commands)
  next false if cmd == -1

  pokemon.setAbility(abillist[command_option[cmd]])
  scene.pbDisplay(_INTL("{1}'s ability was changed to {2}!", pokemon.name, getAbilityName(pokemon.ability)))
  next true
})

def pbResetEVStat(pokemon, scene, ev, messages)
  if pokemon.ev[ev] == 0 && messages[0] != "skip"
    scene.pbDisplay(_INTL("It won't have any effect."))
    return false
  else
    pokemon.ev[ev] = 0
    pokemon.calcStats
    scene.pbRefresh
    if messages[0] != "skip"
      scene.pbDisplay(messages[0])
    end
    return true
  end
end

ItemHandlers::UseOnPokemon.add(:HPRESETBAG, proc { |item, pokemon, scene|
  next pbResetEVStat(
    pokemon,
    scene,
    PBStats::HP,
    [
      _INTL("{1} forgot it's HP training!\nIt's base HP was reset!", pokemon.name),
    ]
  )
})

ItemHandlers::UseOnPokemon.add(:ATKRESETBAG, proc { |item, pokemon, scene|
  next pbResetEVStat(
    pokemon,
    scene,
    PBStats::ATTACK,
    [
      _INTL("{1} forgot its Attack training!\nIts base Attack was reset!", pokemon.name),
    ]
  )
})

ItemHandlers::UseOnPokemon.add(:DEFRESETBAG, proc { |item, pokemon, scene|
  next pbResetEVStat(
    pokemon,
    scene,
    PBStats::DEFENSE,
    [
      _INTL("{1} forgot its Defense training!\nIts base Defense was reset!", pokemon.name),
    ]
  )
})

ItemHandlers::UseOnPokemon.add(:SPARESETBAG, proc { |item, pokemon, scene|
  next pbResetEVStat(
    pokemon,
    scene,
    PBStats::SPATK,
    [
      _INTL("{1} forgot its Sp. Attack training!\nIts base Sp. Attack was reset!", pokemon.name),
    ]
  )
})

ItemHandlers::UseOnPokemon.add(:SPDRESETBAG, proc { |item, pokemon, scene|
  next pbResetEVStat(
    pokemon,
    scene,
    PBStats::SPDEF,
    [
      _INTL("{1} forgot its Sp. Defense training!\nIts base Sp. Defense was reset!", pokemon.name),
    ]
  )
})

ItemHandlers::UseOnPokemon.add(:SPERESETBAG, proc { |item, pokemon, scene|
  next pbResetEVStat(
    pokemon,
    scene,
    PBStats::SPEED,
    [
      _INTL("{1} forgot its Speed training!\nIts base Speed was reset!", pokemon.name),
    ]
  )
})

ItemHandlers::UseOnPokemon.add(:FULLRESETBAG, proc { |item, pokemon, scene|
  pbResetEVStat(pokemon, scene, 0, ["skip"])
  pbResetEVStat(pokemon, scene, 1, ["skip"])
  pbResetEVStat(pokemon, scene, 2, ["skip"])
  pbResetEVStat(pokemon, scene, 3, ["skip"])
  pbResetEVStat(pokemon, scene, 4, ["skip"])
  pbResetEVStat(pokemon, scene, 5, ["skip"])
  scene.pbDisplay(_INTL("{1} forgot all its training!\nIts base stats were reset!", pokemon.name))
})

ItemHandlers::UseOnPokemon.add(:EVTUNER, proc { |item, pokemon, scene|
  # make stat list
  # STATSTRINGS is a plain English constant, so it is translated on the way in.
  stats = STATSTRINGS.map { |n| _INTL(n) }
  evcommands = []
  ret = false
  loop do
    for i in 0...stats.length
      evcommands.push(stats[i] + " (#{pokemon.ev[i]})")
    end
    cmd = 0
    # Show menu with stats to chose from
    cmd = scene.pbShowCommands(_INTL("Select first EV stat to swap."), evcommands)
    if cmd == -1 # cancelled
      break
    elsif cmd >= 0 && cmd < stats.length # choose first stat
      evcommands2 = []
      loop do
        for i in 0...stats.length
          if i == cmd
            evcommands2.push("[X]" + stats[i] + " (#{pokemon.ev[i]})")
          else
            evcommands2.push(stats[i] + " (#{pokemon.ev[i]})")
          end
        end
        cmd2 = 0
        # Show menu with stats to chose from
        cmd2 = scene.pbShowCommands(_INTL("Select second EV stat to swap with first one."), evcommands2)
        if cmd2 == -1 # cancelled
          break
        elsif cmd == cmd2 # chose same stat
          scene.pbDisplay(_INTL("Can't swap a stat with itself!"))
          break
        elsif cmd2 >= 0 && cmd2 < stats.length # chose second stat
          if Kernel.pbConfirmMessage(_INTL("Do you want to swap #{pokemon.name}'s #{stats[cmd]} stat with its #{stats[cmd2]} stat?"))
            pokemon.ev[cmd], pokemon.ev[cmd2] = pokemon.ev[cmd2], pokemon.ev[cmd]
            scene.pbDisplay(_INTL("Swapped the two stats EVs around!"))
            pbTopRightWindow(
              _INTL(
                "Max. HP<r>{1}\r\nAttack<r>{2}\r\nDefense<r>{3}\r\nSp. Atk<r>{4}\r\nSp. Def<r>{5}\r\nSpeed<r>{6}",
                pokemon.ev[0], pokemon.ev[1], pokemon.ev[2], pokemon.ev[3], pokemon.ev[4], pokemon.ev[5]
              )
            )
            ret = true
            pokemon.calcStats
          end
          break
        end
      end
      break
    end
  end
  next ret
})

ItemHandlers::UseOnPokemon.add(:EVBOOSTER, proc { |item, pokemon, scene|
  # make stat list
  # STATSTRINGS is a plain English constant, so it is translated on the way in.
  stats = STATSTRINGS.map { |n| _INTL(n) }
  ret = false
  if pokemon.ev.sum >= 510 && !$game_switches[:No_Total_EV_Cap]
    scene.pbDisplay(_INTL("{1} already reached its max EVs!", pokemon.name))
    next ret
  elsif pokemon.ev.sum >= 1512 && $game_switches[:No_Total_EV_Cap]
    scene.pbDisplay(_INTL("{1} already reached its max EVs!", pokemon.name))
    next ret
  end
  loop do
    evcommands = []
    for i in 0...stats.length
      evcommands.push(stats[i] + " (#{pokemon.ev[i]})")
    end
    cmd = 0
    # Show menu with stats to chose from
    cmd = scene.pbShowCommands(_INTL("Select which EV stat to boost."), evcommands)
    if cmd == -1 # cancelled
      break
    elsif cmd >= 0 && cmd < stats.length # choose first stat
      if pokemon.ev[cmd] >= 252
        scene.pbDisplay(_INTL("The {1} stat is already maxed!", stats[cmd]))
        next
      end
      if Kernel.pbConfirmMessage(_INTL("Do you want to boost #{pokemon.name}'s #{stats[cmd]} stat?"))
        evs_left = 510 - pokemon.ev.sum
        if evs_left > 252 - pokemon.ev[cmd] || $game_switches[:No_Total_EV_Cap]
          pokemon.ev[cmd] = 252
        else
          pokemon.ev[cmd] += evs_left
        end
        scene.pbDisplay(_INTL("Boosted the {1} stat!", stats[cmd]))
        scene.pbSetHelpText(_INTL("Use on which Pokémon?"))
        pbTopRightWindow(
          _INTL(
            "Max. HP<r>{1}\r\nAttack<r>{2}\r\nDefense<r>{3}\r\nSp. Atk<r>{4}\r\nSp. Def<r>{5}\r\nSpeed<r>{6}",
            pokemon.ev[0], pokemon.ev[1], pokemon.ev[2], pokemon.ev[3], pokemon.ev[4], pokemon.ev[5]
          )
        )
        ret = true
        pokemon.calcStats
      end
      break
    end
  end
  next ret
})

def useVitamin(pokemon, scene, amount, stat)
  consumed = 0
  # "stopgains" password is intentionally ignored
  while consumed < amount
    break if pbRaiseEffortValues(pokemon, stat) == 0

    pokemon.changeHappiness("vitamin")
    consumed += 1
  end

  if consumed == 0
    scene.pbDisplay(_INTL("It won't have any effect."))
    return false, 0
  end

  scene.pbRefresh
  scene.pbDisplay(_INTL("{1}'s {2} increased.", pokemon.name, _INTL(STATSTRINGS[stat])))
  return true, consumed
end

ItemHandlers::UseOnPokemon.add(:HPUP, proc { |item, pokemon, scene, amount = 1|
  next useVitamin(pokemon, scene, amount, PBStats::HP)
})

ItemHandlers::UseOnPokemon.add(:PROTEIN, proc { |item, pokemon, scene, amount = 1|
  next useVitamin(pokemon, scene, amount, PBStats::ATTACK)
})

ItemHandlers::UseOnPokemon.add(:IRON, proc { |item, pokemon, scene, amount = 1|
  next useVitamin(pokemon, scene, amount, PBStats::DEFENSE)
})

ItemHandlers::UseOnPokemon.add(:CALCIUM, proc { |item, pokemon, scene, amount = 1|
  next useVitamin(pokemon, scene, amount, PBStats::SPATK)
})

ItemHandlers::UseOnPokemon.add(:ZINC, proc { |item, pokemon, scene, amount = 1|
  next useVitamin(pokemon, scene, amount, PBStats::SPDEF)
})

ItemHandlers::UseOnPokemon.add(:CARBOS, proc { |item, pokemon, scene, amount = 1|
  next useVitamin(pokemon, scene, amount, PBStats::SPEED)
})

def useWing(pokemon, scene, amount, stat)
  consumed = 0
  # "stopgains" password is intentionally ignored
  while consumed < amount
    break if pbRaiseEffortValues(pokemon, stat, 4, false) == 0

    pokemon.changeHappiness("wing")
    consumed += 1
  end

  if consumed == 0
    scene.pbDisplay(_INTL("It won't have any effect."))
    return false, 0
  end

  scene.pbRefresh
  scene.pbDisplay(_INTL("{1}'s {2} increased.", pokemon.name, _INTL(STATSTRINGS[stat])))
  return true, consumed
end

ItemHandlers::UseOnPokemon.add(:HEALTHWING, proc { |item, pokemon, scene, amount = 1|
  next useWing(pokemon, scene, amount, PBStats::HP)
})

ItemHandlers::UseOnPokemon.add(:MUSCLEWING, proc { |item, pokemon, scene, amount = 1|
  next useWing(pokemon, scene, amount, PBStats::ATTACK)
})

ItemHandlers::UseOnPokemon.add(:RESISTWING, proc { |item, pokemon, scene, amount = 1|
  next useWing(pokemon, scene, amount, PBStats::DEFENSE)
})

ItemHandlers::UseOnPokemon.add(:GENIUSWING, proc { |item, pokemon, scene, amount = 1|
  next useWing(pokemon, scene, amount, PBStats::SPATK)
})

ItemHandlers::UseOnPokemon.add(:CLEVERWING, proc { |item, pokemon, scene, amount = 1|
  next useWing(pokemon, scene, amount, PBStats::SPDEF)
})

ItemHandlers::UseOnPokemon.add(:SWIFTWING, proc { |item, pokemon, scene, amount = 1|
  next useWing(pokemon, scene, amount, PBStats::SPEED)
})

def useEVBerry(pokemon, scene, amount, stat)
  originalev = pokemon.ev[stat]
  consumed = 0
  while consumed < amount
    break if pokemon.happiness == 255 && pokemon.ev[stat] == 0

    pokemon.changeHappiness("EV berry")
    pokemon.ev[stat] -= 20
    pokemon.ev[stat] = 0 if pokemon.ev[stat] < 0
    consumed += 1
  end

  if consumed == 0
    scene.pbDisplay(_INTL("It won't have any effect."))
    return false, 0
  end

  pokemon.calcStats
  scene.pbRefresh

  if pokemon.happiness == 255 && originalev > pokemon.ev[stat]
    scene.pbDisplay(_INTL("{1} adores you!\nThe base {2} fell!", pokemon.name, _INTL(STATSTRINGS[stat])))
  elsif pokemon.happiness == 255
    scene.pbDisplay(_INTL("{1} adores you!\nThe base {2} can't fall!", pokemon.name, _INTL(STATSTRINGS[stat])))
  elsif originalev > pokemon.ev[stat]
    scene.pbDisplay(_INTL("{1} turned friendly.\nThe base {2} fell!", pokemon.name, _INTL(STATSTRINGS[stat])))
  else
    scene.pbDisplay(_INTL("{1} turned friendly.\nThe base {2} can't fall!", pokemon.name, _INTL(STATSTRINGS[stat])))
  end

  return true, consumed
end

ItemHandlers::UseOnPokemon.add(:POMEGBERRY, proc { |item, pokemon, scene, amount = 1|
  next useEVBerry(pokemon, scene, amount, PBStats::HP)
})

ItemHandlers::UseOnPokemon.add(:KELPSYBERRY, proc { |item, pokemon, scene, amount = 1|
  next useEVBerry(pokemon, scene, amount, PBStats::ATTACK)
})

ItemHandlers::UseOnPokemon.add(:QUALOTBERRY, proc { |item, pokemon, scene, amount = 1|
  next useEVBerry(pokemon, scene, amount, PBStats::DEFENSE)
})

ItemHandlers::UseOnPokemon.add(:HONDEWBERRY, proc { |item, pokemon, scene, amount = 1|
  next useEVBerry(pokemon, scene, amount, PBStats::SPATK)
})

ItemHandlers::UseOnPokemon.add(:GREPABERRY, proc { |item, pokemon, scene, amount = 1|
  next useEVBerry(pokemon, scene, amount, PBStats::SPDEF)
})

ItemHandlers::UseOnPokemon.add(:TAMATOBERRY, proc { |item, pokemon, scene, amount = 1|
  next useEVBerry(pokemon, scene, amount, PBStats::SPEED)
})

##################################################################################
# New Gen 8 Items
##################################################################################

def ExpCandy(pokemon, scene, amount, value)
  if pokemon.level >= MAXIMUMLEVEL || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    return false, 0
  end
  exp = value * amount
  exp = (exp * $game_variables[:Exp_Percent] / 100).floor if $game_switches[:Percent_Exp_Gains]
  result = LevelLimitExpGain(pokemon, exp)

  if result == -1
    scene.pbDisplay(_INTL("It won't have any effect."))
    return false, 0
  end

  exp = result
  amount_consumed = (result / (value * 1.0)).ceil
  IncreaseExp(pokemon, exp, scene)

  scene.pbHardRefresh
  return true, amount_consumed
end

ItemHandlers::UseOnPokemon.add(:EXPCANDYXS, proc { |item, pokemon, scene, amount = 1|
  next ExpCandy(pokemon, scene, amount, 100)
})

ItemHandlers::UseOnPokemon.add(:EXPCANDYS, proc { |item, pokemon, scene, amount = 1|
  next ExpCandy(pokemon, scene, amount, 800)
})

ItemHandlers::UseOnPokemon.copy(:EXPCANDYS, :PHANTOMCANDYS)

ItemHandlers::UseOnPokemon.add(:EXPCANDYM, proc { |item, pokemon, scene, amount = 1|
  next ExpCandy(pokemon, scene, amount, 3000)
})

ItemHandlers::UseOnPokemon.copy(:EXPCANDYM, :PHANTOMCANDYM)

ItemHandlers::UseOnPokemon.add(:EXPCANDYL, proc { |item, pokemon, scene, amount = 1|
  next ExpCandy(pokemon, scene, amount, 10000)
})

ItemHandlers::UseOnPokemon.add(:EXPCANDYXL, proc { |item, pokemon, scene, amount = 1|
  next ExpCandy(pokemon, scene, amount, 30000)
})

ItemHandlers::UseOnPokemon.add(:ADAMANTMINT, proc { |item, pokemon, scene|
  if pokemon.nature == :ADAMANT || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.setNature(:ADAMANT)
    scene.pbDisplay(_INTL("{1} becomes Adamant!", pokemon.name))
    scene.pbHardRefresh
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:LONELYMINT, proc { |item, pokemon, scene|
  if pokemon.nature == :LONELY || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.setNature(:LONELY)
    scene.pbDisplay(_INTL("{1} feels Lonely!", pokemon.name))
    scene.pbHardRefresh
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:NAUGHTYMINT, proc { |item, pokemon, scene|
  if pokemon.nature == :NAUGHTY || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.setNature(:NAUGHTY)
    scene.pbDisplay(_INTL("{1} becomes Naughty!", pokemon.name))
    scene.pbHardRefresh
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:BRAVEMINT, proc { |item, pokemon, scene|
  if pokemon.nature == :BRAVE || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.setNature(:BRAVE)
    scene.pbDisplay(_INTL("{1} becomes Brave!", pokemon.name))
    scene.pbHardRefresh
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:BOLDMINT, proc { |item, pokemon, scene|
  if pokemon.nature == :BOLD || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.setNature(:BOLD)
    scene.pbDisplay(_INTL("{1} becomes Bold!", pokemon.name))
    scene.pbHardRefresh
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:IMPISHMINT, proc { |item, pokemon, scene|
  if pokemon.nature == :IMPISH || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.setNature(:IMPISH)
    scene.pbDisplay(_INTL("{1} becomes Impish!", pokemon.name))
    scene.pbHardRefresh
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:LAXMINT, proc { |item, pokemon, scene|
  if pokemon.nature == :LAX || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.setNature(:LAX)
    scene.pbDisplay(_INTL("{1} becomes Lax!", pokemon.name))
    scene.pbHardRefresh
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:RELAXEDMINT, proc { |item, pokemon, scene|
  if pokemon.nature == :RELAXED || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.setNature(:RELAXED)
    scene.pbDisplay(_INTL("{1} feels Relaxed!", pokemon.name))
    scene.pbHardRefresh
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:MODESTMINT, proc { |item, pokemon, scene|
  if pokemon.nature == :MODEST || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.setNature(:MODEST)
    scene.pbDisplay(_INTL("{1} becomes Modest!", pokemon.name))
    scene.pbHardRefresh
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:MILDMINT, proc { |item, pokemon, scene|
  if pokemon.nature == :MILD || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.setNature(:MILD)
    scene.pbDisplay(_INTL("{1} becomes Mild!", pokemon.name))
    scene.pbHardRefresh
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:RASHMINT, proc { |item, pokemon, scene|
  if pokemon.nature == :RASH || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.setNature(:RASH)
    scene.pbDisplay(_INTL("{1} becomes Rash!", pokemon.name))
    scene.pbHardRefresh
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:QUIETMINT, proc { |item, pokemon, scene|
  if pokemon.nature == :QUIET || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.setNature(:QUIET)
    scene.pbDisplay(_INTL("{1} becomes Quiet!", pokemon.name))
    scene.pbHardRefresh
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:CALMMINT, proc { |item, pokemon, scene|
  if pokemon.nature == :CALM || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.setNature(:CALM)
    scene.pbDisplay(_INTL("{1} feels Calm!", pokemon.name))
    scene.pbHardRefresh
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:GENTLEMINT, proc { |item, pokemon, scene|
  if pokemon.nature == :GENTLE || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.setNature(:GENTLE)
    scene.pbDisplay(_INTL("{1} becomes Gentle!", pokemon.name))
    scene.pbHardRefresh
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:CAREFULMINT, proc { |item, pokemon, scene|
  if pokemon.nature == :CAREFUL || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.setNature(:CAREFUL)
    scene.pbDisplay(_INTL("{1} becomes Careful!", pokemon.name))
    scene.pbHardRefresh
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:SASSYMINT, proc { |item, pokemon, scene|
  if pokemon.nature == :SASSY || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.setNature(:SASSY)
    scene.pbDisplay(_INTL("{1} becomes Sassy!", pokemon.name))
    scene.pbHardRefresh
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:TIMIDMINT, proc { |item, pokemon, scene|
  if pokemon.nature == :TIMID || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.setNature(:TIMID)
    scene.pbDisplay(_INTL("{1} becomes Timid!", pokemon.name))
    scene.pbHardRefresh
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:HASTYMINT, proc { |item, pokemon, scene|
  if pokemon.nature == :HASTY || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.setNature(:HASTY)
    scene.pbDisplay(_INTL("{1} becomes Hasty!", pokemon.name))
    scene.pbHardRefresh
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:JOLLYMINT, proc { |item, pokemon, scene|
  if pokemon.nature == :JOLLY || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.setNature(:JOLLY)
    scene.pbDisplay(_INTL("{1} feels Jolly!", pokemon.name))
    scene.pbHardRefresh
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:NAIVEMINT, proc { |item, pokemon, scene|
  if pokemon.nature == :NAIVE || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.setNature(:NAIVE)
    scene.pbDisplay(_INTL("{1} becomes Naive!", pokemon.name))
    scene.pbHardRefresh
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:SERIOUSMINT, proc { |item, pokemon, scene|
  if pokemon.nature == :SERIOUS || (pokemon.isShadow? rescue false)
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.setNature(:SERIOUS)
    scene.pbDisplay(_INTL("{1} becomes Serious!", pokemon.name))
    scene.pbHardRefresh
    next true
  end
})

ItemHandlers::UseOnPokemon.add(:CELLIMPRINT, proc { |item, pokemon, scene|
  ivsmaxed = true
  ivnames = STATSTRINGS.map { |n| _INTL(n) }
  ivorder = [0, 1, 2, 3, 4, 5]
  listindexes = []
  possible_ivs = []
  for i in ivorder
    if pokemon.iv[i] != 31
      ivsmaxed = false
      listindexes.push(i)
      possible_ivs.push(ivnames[i] + ": " + pokemon.iv[i].to_s)
    end
  end
  if $game_switches[:Empty_IVs_Password]
    scene.pbDisplay(_INTL("It won't have any effect!", pokemon.name))
    next false
  end
  if ivsmaxed
    scene.pbDisplay(_INTL("All of {1}'s IVs are already maxed out.", pokemon.name))
    next false
  else
    possible_ivs.push("Cancel")
    ret = Kernel.pbMessage(_INTL("Which IV would you like to max?"), possible_ivs, possible_ivs.length)
    if ret == possible_ivs.length - 1
      next false
    else
      pokemon.iv[listindexes[ret]] = 31
      scene.pbDisplay(_INTL("{1}'s {2} was maxed out!", pokemon.name, ivnames[listindexes[ret]]))
      pokemon.calcStats
      next true
    end
  end
})

ItemHandlers::UseOnPokemon.add(:NEGATIVEIMPRINT, proc { |item, pokemon, scene|
  ivsminned = true
  ivnames = STATSTRINGS.map { |n| _INTL(n) }
  ivorder = [0, 1, 2, 3, 4, 5]
  listindexes = []
  possible_ivs = []
  for i in ivorder
    if pokemon.iv[i] != 0
      ivsminned = false
      listindexes.push(i)
      possible_ivs.push(ivnames[i] + ": " + pokemon.iv[i].to_s)
    end
  end
  if ivsminned
    scene.pbDisplay(_INTL("All of {1}'s IVs are already minimized.", pokemon.name))
    next false
  else
    possible_ivs.push("Cancel")
    ret = Kernel.pbMessage(_INTL("Which IV would you like to minimize?"), possible_ivs, possible_ivs.length)
    if ret == possible_ivs.length - 1
      next false
    else
      pokemon.iv[listindexes[ret]] = 0
      scene.pbDisplay(_INTL("{1}'s {2} was minimized!", pokemon.name, ivnames[listindexes[ret]]))
      pokemon.calcStats
      next true
    end
  end
})

##################################################################################
# New Gen 8 Items end
##################################################################################

ItemHandlers::UseOnPokemon.add(:GRACIDEA, proc { |item, pokemon, scene|
  if pokemon.species == :SHAYMIN && pokemon.hp >= 0 && pokemon.status != :FROZEN
    if pokemon.form == 0
      pokemon.form = 1
      pokemon.initAbility
      pokemon.calcStats
    elsif pokemon.form == 1
      pokemon.form = 0
      pokemon.initAbility
      pokemon.calcStats
    end
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} changed Forme!", pokemon.name))
    next true
  else
    scene.pbDisplay(_INTL("It had no effect."))
    next false
  end
})

ItemHandlers::UseOnPokemon.add(:REVEALGLASS, proc { |item, pokemon, scene|
  if [:TORNADUS, :THUNDURUS, :LANDORUS, :ENAMOROUS].include?(pokemon.species) && pokemon.hp >= 0
    pokemon.form = (pokemon.form == 0) ? 1 : 0
    scene.pbRefresh
    if pokemon.form == 1
      pokemon.originalAbility = pokemon.ability
      pokemon.initAbility
    elsif pokemon.form == 0 && !pokemon.originalAbility.nil?
      pokemon.ability = pokemon.originalAbility
      pokemon.originalAbility = nil
    else
      pokemon.initAbility
    end
    pokemon.calcStats
    scene.pbDisplay(_INTL("{1} changed Forme!", pokemon.name))
    next true
  else
    scene.pbDisplay(_INTL("It had no effect."))
    next false
  end
})

ItemHandlers::UseOnPokemon.add(:DNASPLICERS, proc { |item, pokemon, scene|
  if pokemon.species == :KYUREM && pokemon.hp >= 0
    if pokemon.fused != nil
      if $Trainer.party.length >= 6
        scene.pbDisplay(_INTL("Your party is full! You can't unfuse {1}.", pokemon.name))
        next false
      else
        $Trainer.party[$Trainer.party.length] = pokemon.fused
        pokemon.fused = nil
        pokemon.form = 0
        pokemon.initAbility
        pokemon.calcStats
        scene.pbHardRefresh
        scene.pbDisplay(_INTL("{1} changed Forme!", pokemon.name))
        pbKyuremMoves(pokemon)
        next true
      end
    else
      chosen = scene.pbChoosePokemon(_INTL("Fuse with which Pokémon?"))
      if chosen >= 0
        poke2 = $Trainer.party[chosen]
        if poke2.species == :RESHIRAM || poke2.species == :ZEKROM && poke2.hp >= 0
          pokemon.form = 1 if poke2.species == :RESHIRAM
          pokemon.form = 2 if poke2.species == :ZEKROM
          pokemon.initAbility
          pokemon.calcStats
          pokemon.fused = poke2
          pbRemovePokemonAt(chosen)
          scene.pbHardRefresh
          scene.pbDisplay(_INTL("{1} changed Forme!", pokemon.name))
          pbKyuremMoves(pokemon)
          next true
        elsif pokemon == poke2
          scene.pbDisplay(_INTL("{1} can't be fused with itself!", pokemon.name))
        else
          scene.pbDisplay(_INTL("{1} can't be fused with {2}.", poke2.name, pokemon.name))
        end
      else
        next false
      end
    end
  else
    scene.pbDisplay(_INTL("It had no effect."))
    next false
  end
})

ItemHandlers::UseOnPokemon.add(:NSOLARIZER, proc { |item, pokemon, scene|
  if pokemon.species == :NECROZMA && pokemon.hp >= 0
    if pokemon.fused != nil
      if $Trainer.party.length >= 6
        scene.pbDisplay(_INTL("Your party is full! You can't unfuse {1}.", pokemon.name))
        next false
      else
        $Trainer.party[$Trainer.party.length] = pokemon.fused
        pokemon.fused = nil
        pokemon.form = 0
        pokemon.initAbility
        pokemon.calcStats
        scene.pbHardRefresh
        scene.pbDisplay(_INTL("{1} changed Forme!", pokemon.name))
        pbNecrozmaMoves(pokemon)
        next true
      end
    else
      chosen = scene.pbChoosePokemon(_INTL("Fuse with which Pokémon?"))
      if chosen >= 0
        poke2 = $Trainer.party[chosen]
        if poke2.species == :SOLGALEO && poke2.hp >= 0
          pokemon.form = 1
          pokemon.initAbility
          pokemon.calcStats
          pokemon.fused = poke2
          pbRemovePokemonAt(chosen)
          scene.pbHardRefresh
          scene.pbDisplay(_INTL("{1} changed Forme!", pokemon.name))
          pbNecrozmaMoves(pokemon)
          next true
        elsif pokemon == poke2
          scene.pbDisplay(_INTL("{1} can't be fused with itself!", pokemon.name))
        elsif poke2.species == :LUNALA
          scene.pbDisplay(_INTL("This item can't fuse {1} with {2}.", poke2.name, pokemon.name))
        else
          scene.pbDisplay(_INTL("{1} can't be fused with {2}.", poke2.name, pokemon.name))
        end
      else
        next false
      end
    end
  else
    scene.pbDisplay(_INTL("It had no effect."))
    next false
  end
})

ItemHandlers::UseOnPokemon.add(:NLUNARIZER, proc { |item, pokemon, scene|
  if pokemon.species == :NECROZMA && pokemon.hp >= 0
    if pokemon.fused != nil
      if $Trainer.party.length >= 6
        scene.pbDisplay(_INTL("Your party is full! You can't unfuse {1}.", pokemon.name))
        next false
      else
        $Trainer.party[$Trainer.party.length] = pokemon.fused
        pokemon.fused = nil
        pokemon.form = 0
        pokemon.initAbility
        pokemon.calcStats
        scene.pbHardRefresh
        scene.pbDisplay(_INTL("{1} changed Forme!", pokemon.name))
        pbNecrozmaMoves(pokemon)
        next true
      end
    else
      chosen = scene.pbChoosePokemon(_INTL("Fuse with which Pokémon?"))
      if chosen >= 0
        poke2 = $Trainer.party[chosen]
        if poke2.species == :LUNALA && poke2.hp >= 0
          pokemon.form = 2
          pokemon.initAbility
          pokemon.calcStats
          pokemon.fused = poke2
          pbRemovePokemonAt(chosen)
          scene.pbHardRefresh
          scene.pbDisplay(_INTL("{1} changed Forme!", pokemon.name))
          pbNecrozmaMoves(pokemon)
          next true
        elsif pokemon == poke2
          scene.pbDisplay(_INTL("{1} can't be fused with itself!", pokemon.name))
        elsif poke2.species == :SOLGALEO
          scene.pbDisplay(_INTL("This item can't fuse {1} with {2}.", poke2.name, pokemon.name))
        else
          scene.pbDisplay(_INTL("{1} can't be fused with {2}.", poke2.name, pokemon.name))
        end
      else
        next false
      end
    end
  else
    scene.pbDisplay(_INTL("It had no effect."))
    next false
  end
})

ItemHandlers::UseOnPokemon.add(:REDNECTAR, proc { |item, pokemon, scene|
  if pokemon.species == :ORICORIO && pokemon.form != 0 && pokemon.hp >= 0
    pokemon.form = 0
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} transformed!", pokemon.name))
    next true
  else
    scene.pbDisplay(_INTL("It had no effect."))
    next false
  end
})

ItemHandlers::UseOnPokemon.add(:YELLOWNECTAR, proc { |item, pokemon, scene|
  if pokemon.species == :ORICORIO && pokemon.form != 1 && pokemon.hp >= 0
    pokemon.form = 1
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} transformed!", pokemon.name))
    next true
  else
    scene.pbDisplay(_INTL("It had no effect."))
    next false
  end
})

ItemHandlers::UseOnPokemon.add(:PINKNECTAR, proc { |item, pokemon, scene|
  if pokemon.species == :ORICORIO && pokemon.form != 2 && pokemon.hp >= 0
    pokemon.form = 2
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} transformed!", pokemon.name))
    next true
  else
    scene.pbDisplay(_INTL("It had no effect."))
    next false
  end
})

ItemHandlers::UseOnPokemon.add(:PURPLENECTAR, proc { |item, pokemon, scene|
  if pokemon.species == :ORICORIO && pokemon.form != 3 && pokemon.hp >= 0
    pokemon.form = 3
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} transformed!", pokemon.name))
    next true
  else
    scene.pbDisplay(_INTL("It had no effect."))
    next false
  end
})

ItemHandlers::UseOnPokemon.add(:PINKPETAL, proc { |item, pokemon, scene|
  if (pokemon.species == :DEERLING || pokemon.species == :SAWSBUCK) && pokemon.form != 0 && pokemon.hp >= 0
    pokemon.form = 0
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} transformed!", pokemon.name))
    next true
  else
    scene.pbDisplay(_INTL("It had no effect."))
    next false
  end
})

ItemHandlers::UseOnPokemon.add(:GREENPETAL, proc { |item, pokemon, scene|
  if (pokemon.species == :DEERLING || pokemon.species == :SAWSBUCK) && pokemon.form != 1 && pokemon.hp >= 0
    pokemon.form = 1
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} transformed!", pokemon.name))
    next true
  else
    scene.pbDisplay(_INTL("It had no effect."))
    next false
  end
})

ItemHandlers::UseOnPokemon.add(:ORANGEPETAL, proc { |item, pokemon, scene|
  if (pokemon.species == :DEERLING || pokemon.species == :SAWSBUCK) && pokemon.form != 2 && pokemon.hp >= 0
    pokemon.form = 2
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} transformed!", pokemon.name))
    next true
  else
    scene.pbDisplay(_INTL("It had no effect."))
    next false
  end
})

ItemHandlers::UseOnPokemon.add(:BLUEPETAL, proc { |item, pokemon, scene|
  if (pokemon.species == :DEERLING || pokemon.species == :SAWSBUCK) && pokemon.form != 3 && pokemon.hp >= 0
    pokemon.form = 3
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} transformed!", pokemon.name))
    next true
  else
    scene.pbDisplay(_INTL("It had no effect."))
    next false
  end
})

ItemHandlers::UseOnPokemon.add(:PAINTJAR, proc { |item, pokemon, scene|
  if !pokemon.isShiny?
    scene.pbDisplay(_INTL("{1} is now shiny!", pokemon.name))
    next pokemon.makeShiny
  else
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  end
})

ItemHandlers::UseOnPokemon.add(:PHASEDIAL, proc { |item, pokemon, scene|
  if (pokemon.species == :SOLROCK || pokemon.species == :LUNATONE) && pokemon.hp >= 0
    if pokemon.fused != nil
      if $Trainer.party.length >= 6
        scene.pbDisplay(_INTL("Your party is full! You can't unfuse {1}.", pokemon.name))
        next false
      else
        $Trainer.party[$Trainer.party.length] = pokemon.fused
        pokemon.fused = nil
        pokemon.form = 0
        pokemon.initAbility
        pokemon.calcStats
        scene.pbHardRefresh
        scene.pbDisplay(_INTL("{1} changed Forme!", pokemon.name))
        next true
      end
    else
      chosen = scene.pbChoosePokemon(_INTL("Fuse with which Pokémon?"))
      if chosen >= 0
        poke2 = $Trainer.party[chosen]
        if ((poke2.species == :LUNATONE && pokemon.species == :SOLROCK) ||
          (poke2.species == :SOLROCK && pokemon.species == :LUNATONE) && poke2.hp >= 0)
          pokemon.form = 1
          pokemon.initAbility
          pokemon.calcStats
          pokemon.fused = poke2
          pbRemovePokemonAt(chosen)
          scene.pbHardRefresh
          scene.pbDisplay(_INTL("{1} changed Forme!", pokemon.name))
          next true
        elsif pokemon == poke2
          scene.pbDisplay(_INTL("{1} can't be fused with itself!", pokemon.name))
        else
          scene.pbDisplay(_INTL("{1} can't be fused with {2}.", poke2.name, pokemon.name))
        end
      else
        next false
      end
    end
  else
    scene.pbDisplay(_INTL("It had no effect."))
    next false
  end
})
#===============================================================================
# UseInField handlers
#===============================================================================

ItemHandlers::UseInField.add(:HONEY, proc { |item|
  Kernel.pbMessage(_INTL("{1} used the {2}!", $Trainer.name, getItemName(item)))
  pbSweetScent
})

ItemHandlers::UseInField.add(:ESCAPEROPE, lambda { |item|
  escape = ($PokemonGlobal.escapePoint rescue nil)
  if !escape || escape == []
    Kernel.pbMessage(_INTL("Can't use that here."))
    next
  end
  if $game_player.pbHasDependentEvents?
    Kernel.pbMessage(_INTL("It can't be used when you have someone with you."))
    next
  end
  Kernel.pbMessage(_INTL("{1} used the Escape Rope.", $Trainer.name))
  hookBeforeEscapeRope
  pbFadeOutIn(99999) {
    Kernel.pbCancelVehicles
    $game_temp.player_new_map_id = escape[0]
    $game_temp.player_new_x = escape[1]
    $game_temp.player_new_y = escape[2]
    $game_temp.player_new_direction = escape[3]
    pbToneChangeAll(Tone.new(-255, -255, -255), 0)
    $scene.transfer_player
    pbToneChangeAll(Tone.new(0, 0, 0), 8)
    $game_map.autoplay
    $game_map.refresh
    if pbIsWaterTag?(Kernel.pbFacingTerrainTag) && !$PokemonGlobal.surfing
      $PokemonEncounters.clearStepCount
      $PokemonGlobal.surfing = true
      $game_switches[:Faux_Surf] = true
      $game_map.refresh
      Kernel.pbUpdateVehicle
    end
    if pbIsLavaTag?(Kernel.pbFacingTerrainTag) && !$PokemonGlobal.lavasurfing
      $PokemonEncounters.clearStepCount
      $PokemonGlobal.lavasurfing = true
      $game_switches[:Faux_Surf] = true
      $game_map.refresh
      Kernel.pbUpdateVehicle
    end
    $game_variables[:Forced_Field_Effect] = 0
    $game_variables[:Forced_BaseField] = 0
    $game_variables[:AltFieldGraphic] = 0
  }
  hookAfterEscapeRope
  pbEraseEscapePoint
})

def hookBeforeEscapeRope
  # Intentionally empty, added as a hook for mod overrides since overriding escape rope handling isn't easy.
end

def hookAfterEscapeRope
  # Intentionally empty, added as a hook for mod overrides since overriding escape rope handling isn't easy.
end

ItemHandlers::UseInField.add(:BICYCLE, proc { |item|
  if pbBikeCheck
    if $PokemonGlobal.bicycle
      Kernel.pbDismountBike
    else
      Kernel.pbMountBike
    end
  end
})

ItemHandlers::UseInField.add(:REMOTEPC, proc { |item|
  if $game_variables[:E4_Tracker] > 0
    Kernel.pbMessage(_INTL("Cannot use the Remote PC here."))
    next 0
  end
  if $game_switches[:NotPlayerCharacter] && !$game_switches[:InterceptorsWish]
    Kernel.pbMessage(_INTL("Cannot use the Remote PC right now."))
    next 0
  end
  if Rejuv && $game_variables[650] > 0
    Kernel.pbMessage(_INTL("ERIN: {1}, can you get off that PC and get on with the battle?", $Trainer.name))
    next 0
  end
  if $game_switches[:Free_Remote_PC]
    pbPokeCenterPC
    next 1
  end
  if $PokemonBag.pbQuantity(:CELLBATTERY) > 0
    Kernel.pbMessage(_INTL("Used a Cell Battery to power the PC."))
    $PokemonBag.pbDeleteItem(:CELLBATTERY)
    pbPokeCenterPC
    next 1
  else
    Kernel.pbMessage(_INTL("No Cell Battery to power the PC."))
    next 0
  end
})

# ItemHandlers::UseInField.copy(:BICYCLE,:MACHBIKE,:ACROBIKE)

ItemHandlers::UseInField.add(:OLDROD, proc { |item|
  terrain = Kernel.pbFacingTerrainTag
  notCliff = $game_map.passable?($game_player.x, $game_player.y, $game_player.direction)
  if (!pbIsWaterTag?(terrain) && !pbIsGrimeTag?(terrain)) ||
     (!notCliff && !$PokemonGlobal.surfing) # lavasurfing if needed
    Kernel.pbMessage(_INTL("Can't use that here."))
    next
  end
  encounter = $PokemonEncounters.hasEncounter?(EncounterTypes::OldRod)
  if pbFishing(encounter, 1)
    pbEncounter(EncounterTypes::OldRod)
  end
})

ItemHandlers::UseInField.add(:GOODROD, proc { |item|
  terrain = Kernel.pbFacingTerrainTag
  notCliff = $game_map.passable?($game_player.x, $game_player.y, $game_player.direction)
  if (!pbIsWaterTag?(terrain) && !pbIsGrimeTag?(terrain)) ||
     (!notCliff && !$PokemonGlobal.surfing) # lavasurfing if needed
    Kernel.pbMessage(_INTL("Can't use that here."))
    next
  end
  encounter = $PokemonEncounters.hasEncounter?(EncounterTypes::GoodRod)
  if pbFishing(encounter, 2)
    pbEncounter(EncounterTypes::GoodRod)
  end
})

ItemHandlers::UseInField.add(:SUPERROD, proc { |item|
  terrain = Kernel.pbFacingTerrainTag
  notCliff = $game_map.passable?($game_player.x, $game_player.y, $game_player.direction)
  if (!pbIsWaterTag?(terrain) && !pbIsGrimeTag?(terrain)) ||
     (!notCliff && !$PokemonGlobal.surfing) # lavasurfing if needed
    Kernel.pbMessage(_INTL("Can't use that here."))
    next
  end
  encounter = $PokemonEncounters.hasEncounter?(EncounterTypes::SuperRod)
  if pbFishing(encounter, 3)
    pbEncounter(EncounterTypes::SuperRod)
  end
})

ItemHandlers::UseInField.add(:ITEMFINDER, proc { |item|
  event = pbClosestHiddenItem
  pbSEPlay("itemfinder1")
  if !event
    Kernel.pbMessage(_INTL("... ... ... ...Nope!\r\nThere's no response."))
  else
    offsetX = event.x - $game_player.x
    offsetY = event.y - $game_player.y
    if offsetX == 0 && offsetY == 0
      for i in 0...32
        Graphics.update
        Input.update
        $game_player.turn_right_90 if (i & 7) == 0
        pbUpdateSceneMap
      end
      $scene.spriteset.addEventAnimation(PLANT_SPARKLE_ANIMATION_ID, event, true)
      Kernel.pbMessage(_INTL("The {1}'s indicating something right underfoot!\1", getItemName(item)))
    else
      direction = $game_player.direction
      if offsetX.abs > offsetY.abs
        direction = (offsetX < 0) ? 4 : 6
      else
        direction = (offsetY < 0) ? 8 : 2
      end
      for i in 0...8
        Graphics.update
        Input.update
        if i == 0
          $game_player.turn_down if direction == 2
          $game_player.turn_left if direction == 4
          $game_player.turn_right if direction == 6
          $game_player.turn_up if direction == 8
        end
        pbUpdateSceneMap
      end
      $scene.spriteset.addEventAnimation(PLANT_SPARKLE_ANIMATION_ID, event, true)
      # Kernel.pbMessage(_INTL("Huh?\nThe {1}'s responding!\1",getItemName(item)))
      # Kernel.pbMessage(_INTL("There's an item buried around here!"))
      if $game_switches[:Blindstep]
        message = "There's an item "
        if offsetX < 0
          message += (-1 * offsetX).to_s + " tile"
          message += offsetX != -1 ? "s" : ""
          message += " left"
          message += offsetY != 0 ? " and " : ""
        elsif offsetX > 0
          message += (offsetX).to_s + " tile"
          message += offsetX != 1 ? "s" : ""
          message += " right"
          message += offsetY != 0 ? " and " : ""
        end
        if offsetY < 0
          message += (-1 * offsetY).to_s + " tile"
          message += offsetY != -1 ? "s" : ""
          message += " up"
        elsif offsetY > 0
          message += (offsetY).to_s + " tile"
          message += offsetY != 1 ? "s" : ""
          message += " down"
        end
        message += " from here!"
        Kernel.pbMessage(_INTL(message))
      end
    end
  end
})

ItemHandlers::UseInField.copy(:ITEMFINDER, :DOWSINGMCHN)

ItemHandlers::UseInField.add(:TOWNMAP, proc { |item|
  pbShowMap(-1, false)
})

ItemHandlers::UseInField.add(:COINCASE, proc { |item|
  Kernel.pbMessage(_INTL("Coins: {1}", $PokemonGlobal.coins))
  next 1 # Continue
})

ItemHandlers::UseInField.add(:MONEYBAGS, proc { |item|
  Kernel.pbMessage(_INTL("Money: {1}$", $game_variables[:MoneyBags]))
  next 1 # Continue
})

ItemHandlers::UseInField.add(:MEMBERSHIPCARD, proc { |item|
  # Kernel.pbMessage(_INTL("Stickers: {1}",$game_variables[175]))
  $game_switches[:Show_Department_Card] = true
  next 2 # Close without consuming
})

ItemHandlers::UseInField.add(:SPIRITTRACKER, proc { |item|
  Kernel.pbMessage(_INTL("Spirits Released: {1}", $game_variables[548]))
  next 1 # Continue
})

# ItemHandlers::UseInField.add(:POKEBLOCKCASE,proc{|item|
#   Kernel.pbMessage(_INTL("Can't use that here."))
# })

ItemHandlers::UseInField.add(:BLUEORB3, proc { |item|
  $game_switches[:Blue_Orb_Quest] = true
  next 2 # Close without consuming
})

ItemHandlers::UseInField.add(:GATHERCUBE, proc { |item|
  if Rejuv
    pbInfoBox(2)
  else
    Kernel.pbMessage(_INTL("Z-cells gathered: {1}", $game_variables[:Z_Cells]))
  end
  next 2 # Continue
})

ItemHandlers::UseInField.add(:GOLDENWINGS, proc { |item|
  if !(HIDDENMOVESCOUNTBADGES ? $Trainer.numbadges >= BADGEFORFLY : $Trainer.badges[BADGEFORFLY])
    Kernel.pbMessage(_INTL("You need more badges to use this!"))
    next
  end
  if !$PokemonBag.pbHasItem?(:HM02)
    Kernel.pbMessage(_INTL("You don't have this HM!"))
    next
  end
  if inPast?
    Kernel.pbMessage(_INTL("You are unable to fly in the past!"))
    next
  end
  if $game_switches[:NoFlyZone]
    Kernel.pbMessage(_INTL("You can't use this right now!"))
    next
  end
  if $game_player.pbHasDependentEvents?
    Kernel.pbMessage(_INTL("You can't fly when you have someone with you."))
    next
  end
  if $game_switches[:Riding_Tauros]
    Kernel.pbMessage(_INTL("You can't fly while riding a Pokemon."))
    next
  end
  if !$cache.mapdata[$game_map.map_id].Outdoor
    Kernel.pbMessage(_INTL("Can't use that here."))
    next
  end
  if $game_switches[:NotPlayerCharacter]
    Kernel.pbMessage(_INTL("Golden items cannot be used at this time."))
    next
  end

  if $cache.mapdata[$game_map.map_id].MapPosition.is_a?(Hash)
    region = pbUnpackMapHash[0]
  else
    region = $cache.mapdata[$game_map.map_id].MapPosition[0]
  end
  scene = PokemonRegionMapScene.new(region, false)
  screen = PokemonRegionMap.new(scene)
  ret = screen.pbStartFlyScreen
  if ret
    $PokemonTemp.flydata = ret
  end
  if !$PokemonTemp.flydata
    next
  end

  Kernel.pbMessage(_INTL("{1} used the {2}!", $Trainer.name, getItemName(item)))
  pbFlyAnimation
  pbSEPlay("PRSFX- Fly2")
  pbFadeOutIn(99999) {
    Kernel.pbCancelVehicles
    $game_temp.player_new_map_id = $PokemonTemp.flydata[0]
    $game_temp.player_new_x = $PokemonTemp.flydata[1]
    $game_temp.player_new_y = $PokemonTemp.flydata[2]
    $PokemonTemp.flydata = nil
    $game_temp.player_new_direction = 2
    $game_player.direction_fix = false
    pbToneChangeAll(Tone.new(-255, -255, -255), 0)
    $scene.transfer_player
    pbToneChangeAll(Tone.new(0, 0, 0), 8)
    $game_map.autoplay
    $game_map.refresh
    $game_variables[:Forced_Field_Effect] = 0
    # for rage/sleep powder
    $game_switches[:Rage_Powder_Vial] = false
    $game_switches[:Sleep_Powder_Vial] = false
  }
  pbFlyAnimation(true)
  pbEraseEscapePoint
})

ItemHandlers::UseInField.add(:GOLDENLANTERN, proc { |item|
  if !(HIDDENMOVESCOUNTBADGES ? $Trainer.numbadges >= BADGEFORFLASH : $Trainer.badges[BADGEFORFLASH])
    Kernel.pbMessage(_INTL("You need more badges to use this!"))
    next
  end
  if !$PokemonBag.pbHasItem?(:TM70)
    Kernel.pbMessage(_INTL("You don't have this TM!"))
    next
  end
  if !$cache.mapdata[$game_map.map_id].DarkMap
    Kernel.pbMessage(_INTL("Can't use that here."))
    next
  end
  if $PokemonGlobal.flashUsed
    Kernel.pbMessage(_INTL("This is in use already."))
    next
  end
  if $game_switches[:NotPlayerCharacter]
    Kernel.pbMessage(_INTL("Golden items cannot be used at this time."))
    next
  end
  darkness = $PokemonTemp.darknessSprite
  return false if !darkness || darkness.disposed?

  Kernel.pbMessage(_INTL("{1} used the {2}!", $Trainer.name, getItemName(item)))
  $PokemonGlobal.flashUsed = true
  while darkness.radius < 192
    Graphics.update
    Input.update
    pbUpdateSceneMap
    darkness.radius += 4
  end
})

#===============================================================================
# BattleUseOnPokemon handlers
#===============================================================================

ItemHandlers::BattleUseOnPokemon.add(:POTION, proc { |item, pokemon, battler, scene|
  next pbBattleHPItem(pokemon, battler, 20, scene)
})

ItemHandlers::BattleUseOnPokemon.add(:SUPERPOTION, proc { |item, pokemon, battler, scene|
  next pbBattleHPItem(pokemon, battler, 60, scene)
})

ItemHandlers::BattleUseOnPokemon.add(:CHINESEFOOD, proc { |item, pokemon, battler, scene|
  next pbBattleHPItem(pokemon, battler, 300, scene)
})

ItemHandlers::BattleUseOnPokemon.add(:HYPERPOTION, proc { |item, pokemon, battler, scene|
  next pbBattleHPItem(pokemon, battler, 120, scene)
})

ItemHandlers::BattleUseOnPokemon.add(:ULTRAPOTION, proc { |item, pokemon, battler, scene|
  next pbBattleHPItem(pokemon, battler, 200, scene)
})

ItemHandlers::BattleUseOnPokemon.add(:MAXPOTION, proc { |item, pokemon, battler, scene|
  next pbBattleHPItem(pokemon, battler, pokemon.totalhp, scene)
})

ItemHandlers::BattleUseOnPokemon.add(:BERRYJUICE, proc { |item, pokemon, battler, scene|
  next pbBattleHPItem(pokemon, battler, 20, scene)
})

ItemHandlers::BattleUseOnPokemon.add(:RAGECANDYBAR, proc { |item, pokemon, battler, scene|
  if pokemon.hp <= 0 || (pokemon.status.nil? && (!battler || battler.effects[:Confusion] == 0))
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    battler.status = nil if battler
    battler.effects[:Confusion] = 0 if battler
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} became healthy.", pokemon.name))
    next true
  end
})

ItemHandlers::BattleUseOnPokemon.add(:SWEETHEART, proc { |item, pokemon, battler, scene|
  next pbBattleHPItem(pokemon, battler, 20, scene)
})

ItemHandlers::BattleUseOnPokemon.add(:FRESHWATER, proc { |item, pokemon, battler, scene|
  next pbBattleHPItem(pokemon, battler, 30, scene)
})

ItemHandlers::BattleUseOnPokemon.add(:SODAPOP, proc { |item, pokemon, battler, scene|
  next pbBattleHPItem(pokemon, battler, 50, scene)
})

ItemHandlers::BattleUseOnPokemon.add(:VANILLAIC, proc { |item, pokemon, battler, scene|
  if pbBattleHPItem(pokemon, battler, 30, scene)
    pokemon.changeHappiness("candy")
    next true
  end
  next false
})

ItemHandlers::BattleUseOnPokemon.add(:CHOCOLATEIC, proc { |item, pokemon, battler, scene|
  if pbBattleHPItem(pokemon, battler, 70, scene)
    pokemon.changeHappiness("candy")
    next true
  end
  next false
})

ItemHandlers::BattleUseOnPokemon.add(:STRAWBIC, proc { |item, pokemon, battler, scene|
  if pbBattleHPItem(pokemon, battler, 90, scene)
    pokemon.changeHappiness("candy")
    next true
  end
  next false
})

ItemHandlers::BattleUseOnPokemon.add(:BLUEMIC, proc { |item, pokemon, battler, scene|
  if pbBattleHPItem(pokemon, battler, 200, scene)
    pokemon.changeHappiness("bluecandy")
    next true
  end
  next false
})

ItemHandlers::BattleUseOnPokemon.add(:LEMONADE, proc { |item, pokemon, battler, scene|
  next pbBattleHPItem(pokemon, battler, 70, scene)
})

ItemHandlers::BattleUseOnPokemon.add(:BUBBLETEA, proc { |item, pokemon, battler, scene|
  next pbBattleHPItem(pokemon, battler, 180, scene)
})

ItemHandlers::BattleUseOnPokemon.add(:MEMEONADE, proc { |item, pokemon, battler, scene|
  next pbBattleHPItem(pokemon, battler, 103, scene)
})

ItemHandlers::BattleUseOnPokemon.add(:MOOMOOMILK, proc { |item, pokemon, battler, scene|
  next pbBattleHPItem(pokemon, battler, 100, scene)
})

ItemHandlers::BattleUseOnPokemon.add(:MAGICMILK, proc { |item, pokemon, battler, scene|
  next pbBattleHPItem(pokemon, battler, 100, scene)
})

ItemHandlers::BattleUseOnPokemon.add(:STRAWCAKE, proc { |item, pokemon, battler, scene|
  next pbBattleHPItem(pokemon, battler, 150, scene)
})

ItemHandlers::BattleUseOnPokemon.add(:ORANBERRY, proc { |item, pokemon, battler, scene|
  next pbBattleHPItem(pokemon, battler, 10, scene)
})

ItemHandlers::BattleUseOnPokemon.add(:SITRUSBERRY, proc { |item, pokemon, battler, scene|
  next pbBattleHPItem(pokemon, battler, (pokemon.totalhp / 4.0).floor, scene)
})

ItemHandlers::BattleUseOnPokemon.add(:FIGYBERRY, proc { |item, pokemon, battler, scene|
  next pbBattleHPItem(pokemon, battler, (pokemon.totalhp / (Gen <= 7 ? 2.0 : 3.0)).floor, scene)
})

ItemHandlers::BattleUseOnPokemon.copy(:FIGYBERRY, :WIKIBERRY, :MAGOBERRY, :AGUAVBERRY, :IAPAPABERRY)

ItemHandlers::BattleUseOnPokemon.add(:AWAKENING, proc { |item, pokemon, battler, scene|
  if pokemon.hp <= 0 || pokemon.status != :SLEEP
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    battler.status = nil if battler
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} woke up.", pokemon.name))
    next true
  end
})

ItemHandlers::BattleUseOnPokemon.copy(:AWAKENING, :CHESTOBERRY)

ItemHandlers::BattleUseOnPokemon.add(:BLUEFLUTE, proc { |item, pokemon, battler, scene|
  if pokemon.hp <= 0 || pokemon.status != :SLEEP
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    battler.status = nil if battler
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} woke up.", pokemon.name))
    next false
  end
})

ItemHandlers::BattleUseOnPokemon.copy(:BLUEFLUTE, :POKEFLUTE)

ItemHandlers::BattleUseOnPokemon.add(:ANTIDOTE, proc { |item, pokemon, battler, scene|
  if pokemon.hp <= 0 || pokemon.status != :POISON
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    battler.status = nil if battler
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} was cured of its poisoning.", pokemon.name))
    next true
  end
})

ItemHandlers::BattleUseOnPokemon.copy(:ANTIDOTE, :PECHABERRY)

ItemHandlers::BattleUseOnPokemon.add(:BURNHEAL, proc { |item, pokemon, battler, scene|
  if pokemon.hp <= 0 || pokemon.status != :BURN
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    battler.status = nil if battler
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s burn was healed.", pokemon.name))
    next true
  end
})

ItemHandlers::BattleUseOnPokemon.copy(:BURNHEAL, :RAWSTBERRY)

ItemHandlers::BattleUseOnPokemon.add(:PARLYZHEAL, proc { |item, pokemon, battler, scene|
  if pokemon.hp <= 0 || pokemon.status != :PARALYSIS
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    battler.status = nil if battler
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} was cured of paralysis.", pokemon.name))
    next true
  end
})

ItemHandlers::BattleUseOnPokemon.copy(:PARLYZHEAL, :CHERIBERRY)

ItemHandlers::BattleUseOnPokemon.add(:ICEHEAL, proc { |item, pokemon, battler, scene|
  if pokemon.hp <= 0 || pokemon.status != :FROZEN
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    battler.status = nil if battler
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} was thawed out.", pokemon.name))
    next true
  end
})

ItemHandlers::BattleUseOnPokemon.copy(:ICEHEAL, :ASPEARBERRY)

ItemHandlers::BattleUseOnPokemon.add(:FULLHEAL, proc { |item, pokemon, battler, scene|
  if pokemon.hp <= 0 || (pokemon.status.nil? && (!battler || battler.effects[:Confusion] == 0))
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    battler.status = nil if battler
    battler.effects[:Confusion] = 0 if battler
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} became healthy.", pokemon.name))
    next true
  end
})

ItemHandlers::BattleUseOnPokemon.copy(
  :FULLHEAL, :LAVACOOKIE, :OLDGATEAU, :CASTELIACONE, :BIGMALASADA, :LUMBERRY, :MEDICINE, :RAZZTART
)

ItemHandlers::BattleUseOnPokemon.add(:FULLRESTORE, proc { |item, pokemon, battler, scene|
  if pokemon.hp <= 0 || (pokemon.status.nil? && pokemon.hp == pokemon.totalhp &&
     (!battler || battler.effects[:Confusion] == 0))
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    hpgain = pbItemRestoreHP(pokemon, pokemon.totalhp)
    battler.hp = pokemon.hp if battler
    pokemon.status = nil
    pokemon.statusCount = 0
    battler.status = nil if battler
    battler.effects[:Confusion] = 0 if battler
    scene.pbRefresh
    if hpgain > 0
      scene.pbDisplay(_INTL("{1}'s HP was restored by {2} points.", pokemon.name, hpgain))
    else
      scene.pbDisplay(_INTL("{1} became healthy.", pokemon.name))
    end
    next true
  end
})

ItemHandlers::BattleUseOnPokemon.add(:REVIVE, proc { |item, pokemon, battler, scene|
  if pokemon.hp > 0 || $game_switches[:Nuzlocke_Mode]
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.hp = [(pokemon.totalhp / 2.0).floor, 1].max
    for i in 0...$Trainer.party.length
      if $Trainer.party[i] == pokemon
        battler.pbReset if battler
        # battler.pbInitialize(pokemon,i,false) if battler
        break
      end
    end
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s HP was restored.", pokemon.name))
    next true
  end
})

ItemHandlers::BattleUseOnPokemon.copy(:REVIVE, :FUNNELCAKE)

ItemHandlers::BattleUseOnPokemon.add(:MAXREVIVE, proc { |item, pokemon, battler, scene|
  if pokemon.hp > 0 || $game_switches[:Nuzlocke_Mode]
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.hp = pokemon.totalhp
    for i in 0...$Trainer.party.length
      if $Trainer.party[i] == pokemon
        battler.pbReset if battler
        # battler.pbInitialize(pokemon,i,false) if battler
        break
      end
    end
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s HP was restored.", pokemon.name))
    next true
  end
})

ItemHandlers::BattleUseOnPokemon.copy(:MAXREVIVE, :HERBALTEA)

ItemHandlers::BattleUseOnPokemon.add(:GOURMETTREAT, proc { |item, pokemon, scene|
  if pokemon.happiness == 255
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.changeHappiness("level up")
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} ate the Gourmet Treat happily!", pokemon.name))
    next true
  end
})

ItemHandlers::BattleUseOnPokemon.add(:ENERGYPOWDER, proc { |item, pokemon, battler, scene|
  if pbBattleHPItem(pokemon, battler, 60, scene)
    pokemon.changeHappiness("powder")
    next true
  end
  next false
})

ItemHandlers::BattleUseOnPokemon.add(:ENERGYROOT, proc { |item, pokemon, battler, scene|
  if pbBattleHPItem(pokemon, battler, 120, scene)
    pokemon.changeHappiness("Energy Root")
    next true
  end
  next false
})

ItemHandlers::BattleUseOnPokemon.add(:HEALPOWDER, proc { |item, pokemon, battler, scene|
  if pokemon.hp <= 0 || (pokemon.status.nil? && (!battler || battler.effects[:Confusion] == 0))
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.statusCount = 0
    battler.status = nil if battler
    battler.effects[:Confusion] = 0 if battler
    pokemon.changeHappiness("powder")
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} became healthy.", pokemon.name))
    next true
  end
})

ItemHandlers::BattleUseOnPokemon.add(:REVIVALHERB, proc { |item, pokemon, battler, scene|
  if pokemon.hp > 0 || $game_switches[:Nuzlocke_Mode]
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    pokemon.status = nil
    pokemon.hp = pokemon.totalhp
    for i in 0...$Trainer.party.length
      if $Trainer.party[i] == pokemon
        battler.pbReset if battler
        # battler.pbInitialize(pokemon,i,false) if battler
        break
      end
    end
    pokemon.changeHappiness("Revival Herb")
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s HP was restored.", pokemon.name))
    next true
  end
})

ItemHandlers::BattleUseOnPokemon.add(:ETHER, proc { |item, pokemon, battler, scene|
  #   move=scene.pbChooseMove(pokemon,_INTL("Restore which move?"))
  #   if move>=0
  #     if pbBattleRestorePP(pokemon,battler,move,10)==0
  #       scene.pbDisplay(_INTL("It won't have any effect."))
  #       next false
  #     else
  scene.pbDisplay(_INTL("PP was restored."))
  next true
  #     end
  #   end
  #   next false
})

ItemHandlers::BattleUseOnPokemon.copy(:ETHER, :LEPPABERRY)

ItemHandlers::BattleUseOnPokemon.add(:MAXETHER, proc { |item, pokemon, battler, scene|
  #   move=scene.pbChooseMove(pokemon,_INTL("Restore which move?"))
  #   if move>=0
  #     if pbBattleRestorePP(pokemon,battler,move,pokemon.moves[move].totalpp-pokemon.moves[move].pp)==0
  #       scene.pbDisplay(_INTL("It won't have any effect."))
  #       next false
  #     else
  scene.pbDisplay(_INTL("PP was restored."))
  next true
  #     end
  #   end
  #   next false
})
ItemHandlers::BattleUseOnPokemon.add(:ELIXIR, proc { |item, pokemon, battler, scene|
  pprestored = 0
  for i in 0...pokemon.moves.length
    pprestored += pbBattleRestorePP(pokemon, battler, i, 10)
  end
  if pprestored == 0
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    scene.pbDisplay(_INTL("PP was restored."))
    next true
  end
})

ItemHandlers::BattleUseOnPokemon.add(:MAXELIXIR, proc { |item, pokemon, battler, scene|
  pprestored = 0
  for i in 0...pokemon.moves.length
    pprestored += pbBattleRestorePP(pokemon, battler, i, pokemon.moves[i].totalpp - pokemon.moves[i].pp)
  end
  if pprestored == 0
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  else
    scene.pbDisplay(_INTL("PP was restored."))
    next true
  end
})

ItemHandlers::BattleUseOnPokemon.add(:REDFLUTE, proc { |item, pokemon, battler, scene|
  if battler && battler.effects[:Attract] >= 0
    battler.effects[:Attract] = -1
    scene.pbDisplay(_INTL("{1} got over its infatuation.", pokemon.name))
    next false # :consumed:
  else
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  end
})

ItemHandlers::BattleUseOnPokemon.add(:YELLOWFLUTE, proc { |item, pokemon, battler, scene|
  if battler && battler.effects[:Confusion] > 0
    battler.effects[:Confusion] = 0
    scene.pbDisplay(_INTL("{1} snapped out of confusion.", pokemon.name))
    next false # :consumed:
  else
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  end
})

ItemHandlers::BattleUseOnPokemon.copy(:YELLOWFLUTE, :PERSIMBERRY)

#===============================================================================
# BattleUseOnBattler handlers
#===============================================================================

ItemHandlers::BattleUseOnBattler.add(:XATTACK, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::ATTACK, 2, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})


ItemHandlers::BattleUseOnBattler.add(:XATTACK2, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::ATTACK, 2, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:XATTACK3, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::ATTACK, 3, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:XATTACK6, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::ATTACK, 6, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:XDEFEND, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::DEFENSE, 2, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:XDEFEND2, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::DEFENSE, 2, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:XDEFEND3, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::DEFENSE, 3, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:XDEFEND6, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::DEFENSE, 6, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:XSPECIAL, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::SPATK, 2, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:XSPECIAL2, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::SPATK, 2, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:XSPECIAL3, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::SPATK, 3, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:XSPECIAL6, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::SPATK, 6, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:XSPDEF, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::SPDEF, 2, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:XSPDEF2, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::SPDEF, 2, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:XSPDEF3, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::SPDEF, 3, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:XSPDEF6, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::SPDEF, 6, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:XSPEED, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::SPEED, 2, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:XSPEED2, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::SPEED, 2, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:XSPEED3, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::SPEED, 3, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:XSPEED6, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::SPEED, 6, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:XACCURACY, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::ACCURACY, 2, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:XACCURACY2, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::ACCURACY, 2, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:XACCURACY3, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::ACCURACY, 3, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:XACCURACY6, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbIncreaseStat(PBStats::ACCURACY, 6, statmessage: true)
    return true
  else
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  end
})

ItemHandlers::BattleUseOnBattler.add(:DIREHIT, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.effects[:FocusEnergy] >= 2
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  else
    battler.effects[:FocusEnergy] = 2
    scene.pbDisplay(_INTL("{1} is getting pumped!", battler.pbThis))
    return true
  end
})

ItemHandlers::BattleUseOnBattler.add(:DIREHIT2, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.effects[:FocusEnergy] >= 2
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  else
    battler.effects[:FocusEnergy] = 2
    scene.pbDisplay(_INTL("{1} is getting pumped!", battler.pbThis))
    return true
  end
})

ItemHandlers::BattleUseOnBattler.add(:DIREHIT3, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.effects[:FocusEnergy] >= 3
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  else
    battler.effects[:FocusEnergy] = 3
    scene.pbDisplay(_INTL("{1} is getting pumped!", battler.pbThis))
    return true
  end
})

ItemHandlers::BattleUseOnBattler.add(:GUARDSPEC, lambda { |item, battler, scene|
  playername = battler.battle.pbPlayer.name
  itemname = getItemName(item)
  scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
  if battler.pbOwnSide.effects[:Mist] > 0
    scene.pbDisplay(_INTL("But it had no effect!"))
    return false
  else
    battler.pbOwnSide.effects[:Mist] = 5
    if !battler.pbIsOpposing?(battler.index) # Item not implemented for enemies. Messages may be incorrect for them if it is.
      scene.pbDisplay(_INTL("Your team became shrouded in mist!"))
    else
      scene.pbDisplay(_INTL("The foe's team became shrouded in mist!"))
    end
    return true
  end
})

ItemHandlers::BattleUseOnBattler.add(:POKEDOLL, lambda { |item, battler, scene|
  battle = battler.battle
  if battle.opponent || battler.pbOpposing1.isbossmon || battler.pbOpposing2.isbossmon
    scene.pbDisplay(_INTL("Can't use that here."))
    return false
  else
    playername = battle.pbPlayer.name
    itemname = getItemName(item)
    scene.pbDisplay(_INTL("{1} used the {2}.", playername, itemname))
    return true
  end
})

ItemHandlers::BattleUseOnBattler.copy(:POKEDOLL, :FLUFFYTAIL, :POKETOY)

ItemHandlers::BattleUseOnBattler.addIf(lambda { |item|
  pbIsPokeBall?(item)
}, lambda { |item, battler, scene| # Any Poké Ball
     battle = battler.battle
     if !battler.pbOpposing1.isFainted? && !battler.pbOpposing2.isFainted?
       if (!Reborn && !pbIsSnagBall?(item)) || (Reborn && (!battle.opponent || !$game_switches[:SnagMachine_Password]))
         scene.pbDisplay(_INTL("It's no good!  It's impossible to aim when there are two Pokémon!"))
         return false
       end
     end
     if battle.pbPlayer.party.length >= 6 && $PokemonStorage.full?
       scene.pbDisplay(_INTL("There is no room left in the PC!"))
       return false
     end
     return true
   })

#===============================================================================
# UseInBattle handlers
#===============================================================================

ItemHandlers::UseInBattle.add(:POKEDOLL, proc { |item, battler, battle|
  battle.decision = 3
  pbSEPlay("escape", 100)
  battle.pbDisplayPaused(_INTL("Got away safely!"))
})

ItemHandlers::UseInBattle.copy(:POKEDOLL, :FLUFFYTAIL, :POKETOY)

ItemHandlers::UseInBattle.addIf(proc { |item|
  pbIsPokeBall?(item)
}, proc { |item, battler, battle| # Any Poké Ball
     battle.pbThrowPokeBall(battler.index, item)
     $PokemonBag.pbDeleteItem(item)
   })
