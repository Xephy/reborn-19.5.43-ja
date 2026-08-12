def pbLoadTrainer(type, name, id)
  trainer = findParty(type, name, id)
  print "Team could not be loaded, please report this: #{type}, #{name}, #{id} \n ty <3" if !trainer
  return nil if !trainer

  items = trainer[2]
  opponent = PokeBattle_Trainer.new(name, type)
  opponent.setForeignID($Trainer) if $Trainer
  opponent.aceline = trainer[3]
  opponent.defeatline = trainer[4] ? trainer[4] : ""
  opponent.trainereffect = trainer[5]
  party = []
  bossdata = $cache.bosses
  for poke in trainer[1]
    boss = poke[:boss] ? bossdata[poke[:boss]] : nil
    bossid = poke[:boss]
    poke = boss.moninfo if boss
    species = poke[:species]
    level = poke[:level]
    # The password only applies once you have more than one badge.
    # Ignore F.E.A.R. Pokemon
    if $game_switches[:Level_Floor_Password] && $Trainer.numbadges > 0 && level != 1
      # If the opponent Pokemon's level is less than the previous non-postgame level cap (caps at 95), plus the
      # extended maximum level from the postgame, then it increased to equal that
      if level < LEVELCAPS[$Trainer.numbadges - 1] + $game_variables[:Extended_Max_Level]
        level = LEVELCAPS[$Trainer.numbadges - 1] + $game_variables[:Extended_Max_Level]
      end
    end
    form = poke[:form] ? poke[:form] : 0
    pokemon = PokeBattle_Pokemon.new(species, level, opponent, false, form)
    bossFunction(boss, bossid, pokemon) if boss
    pokemon.setItem(poke[:item])
    pokemon.form = pokemon.getForm(pokemon)
    if poke[:moves]
      k = 0
      for move in poke[:moves]
        next if move.nil?

        pokemon.moves[k] = PBMove.new(move)
        if level >= 100 && opponent.skill >= PokeBattle_AI::BESTSKILL
          pokemon.moves[k].ppup = 3
          pokemon.moves[k].pp = pokemon.moves[k].totalpp
        end
        k += 1
      end
    else
      pokemon.resetMoves
    end
    pokemon.initZmoves(pokemon.item, false) if $cache.items[pokemon.item] && $cache.items[pokemon.item].checkFlag?(:zcrystal)
    pokemon.setAbility(poke.fetch(:ability, pokemon.getAbilityList[0]))
    case poke[:gender]
      when "M" then pokemon.setGender(0)
      when "F" then pokemon.setGender(1)
      when "N" then pokemon.setGender(2)
      else
        pokemon.setGender(rand(2))
    end
    pokemon.shinyflag = poke[:shiny] || false
    pokemon.setNature(poke.fetch(:nature, :HARDY))
    iv = poke.fetch(:iv, 10)
    if iv == 32 # Trick room IVS
      pokemon.iv = Array.new(6, 31)
      pokemon.iv[5] = 0
    else
      iv = 0 if $game_switches[:Empty_IVs_And_EVs_Password]
      iv = 31 if $game_switches[:Max_Trainer_IVs_Password]
      pokemon.iv = Array.new(6, iv)
    end
    evs = poke[:ev].clone
    evs = Array.new(6, [85, level * 3 / 2].min) if !evs
    evs = Array.new(6, 252) if $game_switches[:Only_Pulse_2] # pulse 2 mode
    evs = Array.new(6, 85) if $game_switches[:Flat_EV_Password]
    evs = Array.new(6, 0) if $game_switches[:Empty_IVs_And_EVs_Password]
    pokemon.ev = evs
    if poke[:ev]
      for i in 0...6
        pokemon.ev[i] = poke[:ev][i] if poke[:ev][i] > 252
      end
    end
    pokemon.ev[PBStats::SPEED] = 0 if iv == 32 # TR team, just to make sure!
    pokemon.happiness = poke.fetch(:happiness, 70)
    # Nicknames live in trainers.dat as bare English, and the constructor's
    # translated name is overwritten here. The compiler cannot scrape a key out
    # of a variable, so the keys are added to the script-text section by hand;
    # a nickname with no entry comes back unchanged.
    pokemon.name = _INTL(poke[:name]) if poke[:name]
    if poke[:shadow] # if this is a Shadow Pokémon
      pokemon.makeShadow rescue nil
      pokemon.pbUpdateShadowMoves(true) rescue nil
      pokemon.makeNotShiny
    end
    pokemon.ballused = poke.fetch(:ball, :POKEBALL)
    pokemon.calcStats
    pokemon.hp = pokemon.totalhp
    pokemon.trainerID = poke[:trainerID] if poke[:trainerID]
    pokemon.hptype = poke[:hptype] if poke[:hptype]
    party.push(pokemon)
  end
  return [opponent, items, party]
end

def findParty(type, name, id)
  trainerarray = $cache.trainers.dig(type, name)
  for trainer in trainerarray
    return trainer if trainer[0] == id
  end
  return nil
end

def pbLoadCopiedTrainer(trainerid, trainername, partyid, party)
  opponent = PokeBattle_Trainer.new(trainername, trainerid)
  items = []
  for trainer in $cache.trainers
    next if trainerid != trainer[0] || partyid != trainer[4]

    items = trainer[2].clone
  end
  return [opponent, items, party]
end

def pbMissingTrainer(trainerid, trainername, trainerparty)
  traineridstring = "#{trainerid}"
  if $DEBUG
    if trainerparty != 0
      message = _INTL("Add new trainer ({1}, {2}, ID {3})?", traineridstring, trainername, trainerparty)
    else
      message = _INTL("Add new trainer ({1}, {2})?", traineridstring, trainername)
    end
    cmd = Kernel.pbMessage(message, [_INTL("Yes"), _INTL("No")], 2)
    if cmd == 0
      pbNewTrainer(trainerid, trainername, trainerparty)
    end
    return cmd
  else
    raise _INTL("Can't find trainer ({1}, {2}, ID {3})", traineridstring, trainername, trainerparty)
  end
end

# pbDoubleTrainerBattle(:AsterKnight,"Aster",0,_I("Dammit! Eclipse, are you even trying?!"),:EclipseDame,"Eclipse",0,_I("Not really, no."),switch_sprites: true)
def pbDoubleTrainerBattle(
  trainerid1, trainername1, trainerparty1, endspeech1,
  trainerid2, trainername2, trainerparty2, endspeech2,
  canlose = false, variable = Variables[:BattleResult],
  vsoutfit1: 0, vsoutfit2: 0, switch_sprites: false, recorded: false, noexp: false
)
  $game_switches[:In_Battle] = true
  trainer1 = pbLoadTrainer(trainerid1, trainername1, trainerparty1)
  Events.onTrainerPartyLoad.trigger(nil, trainer1)
  if !trainer1
    pbMissingTrainer(trainerid1, trainername1, trainerparty1)
  end
  trainer2 = pbLoadTrainer(trainerid2, trainername2, trainerparty2)
  Events.onTrainerPartyLoad.trigger(nil, trainer2)
  if !trainer2
    pbMissingTrainer(trainerid2, trainername2, trainerparty2)
  end
  if !trainer1 || !trainer2
    $game_switches[:In_Battle] = false
    return false
  end
  trainer1[0].outfit = vsoutfit1 if vsoutfit1 > 0
  trainer2[0].outfit = vsoutfit2 if vsoutfit2 > 0
  if $PokemonGlobal.partner
    othertrainer = PokeBattle_Trainer.new($PokemonGlobal.partner[1], $PokemonGlobal.partner[0])
    othertrainer.id = $PokemonGlobal.partner[2]
    othertrainer.party = $PokemonGlobal.partner[3]
    playerparty = []
    for i in 0...$Trainer.party.length
      playerparty[i] = $Trainer.party[i]
    end
    for i in 0...othertrainer.party.length
      playerparty[6 + i] = othertrainer.party[i]
    end
    fullparty1 = true
    playertrainer = [$Trainer, othertrainer]
  else
    playerparty = $Trainer.party
    playertrainer = $Trainer
    fullparty1 = false
  end
  combinedParty = []
  for i in 0...trainer1[2].length
    combinedParty[i] = trainer1[2][i]
  end
  for i in 0...trainer2[2].length
    combinedParty[6 + i] = trainer2[2][i]
  end
  scene = pbNewBattleScene
  # ##Yumil - 15 - NPC Reaction - Begin
  battle = PokeBattle_Battle.new(scene, playerparty, combinedParty, playertrainer, [trainer1[0], trainer2[0]], recorded)
  # ##Yumil - 15 - NPC Reaction - End
  battle.controlPlayer = $game_switches[:AI_Play] || $game_switches[:Forced_AI_Play]
  trainerbgm = pbGetTrainerBattleBGM([trainer1[0], trainer2[0]])
  battle.fullparty1 = fullparty1
  battle.fullparty2 = true
  battle.doublebattle = true
  battle.endspeech = trainer1[0].defeatline == "" ? endspeech1 : trainer1[0].defeatline
  battle.endspeech2 = trainer2[0].defeatline == "" ? endspeech2 : trainer2[0].defeatline
  battle.endspeech = $game_variables[:Theme_Team_Defeat_Line] if $game_switches[:Theme_Team_Execution]
  battle.endspeech = $game_variables[:MnM_Defeat_Line] if $game_switches[:MnM_Execution]
  battle.endspeech2 = $game_variables[:Theme_Team_Defeat_Line] if $game_switches[:MnM_Execution]
  trainer1[1].nil? ? trainer1items = [] : trainer1items = trainer1[1]
  trainer2[1].nil? ? trainer2items = [] : trainer2items = trainer2[1]
  if $PokemonGlobal.partner
    battle.partneritems = $PokemonGlobal.partner[4]
  end
  battle.items = [trainer1items, trainer2items]
  if Input.press?(Input::CTRL) && $DEBUG
    Kernel.pbMessage(_INTL("SKIPPING BATTLE..."))
    Kernel.pbMessage(_INTL("AFTER LOSING..."))
    Kernel.pbMessage(pbGetMessageFromHash(MessageTypes::EndSpeechLose, battle.endspeech))
    Kernel.pbMessage(pbGetMessageFromHash(MessageTypes::EndSpeechLose, battle.endspeech2)) if battle.endspeech2 && battle.endspeech2 != ""
    $game_switches[:In_Battle] = false
    return true
  end
  if $game_switches[:No_Battles_Pass] && Kernel.pbConfirmMessage("Skip battle?")
    Kernel.pbMessage("After losing: ")
    Kernel.pbMessage(pbGetMessageFromHash(MessageTypes::EndSpeechLose, battle.endspeech))
    Kernel.pbMessage(pbGetMessageFromHash(MessageTypes::EndSpeechLose, battle.endspeech2)) if battle.endspeech2 && battle.endspeech2 != ""
    $game_switches[:In_Battle] = false
    return true
  end
  battle.disableExpGain = true if noexp
  Events.onStartBattle.trigger(nil, nil)
  Events.onDoubleBattleLoad.trigger("trainer", trainer1, trainer2)
  battle.internalbattle = true
  pbPrepareBattle(battle)
  decision = 0
  pbBattleAnimation(trainerbgm, [trainerid1, trainerid2], [trainer1[0].name, trainer2[0].name], switch_sprites, [vsoutfit1, vsoutfit2]) {
    pbSceneStandby {
      decision = battle.pbStartBattle(canlose)
    }
    if $PokemonGlobal.partner
      pbHealAll
      for i in $PokemonGlobal.partner[3]
        i.heal
     end
    end
    if decision == 2 || decision == 5
      if canlose
        for i in $Trainer.party; i.heal; end
        for i in 0...10
          Graphics.update
        end
      else
        $game_system.bgm_unpause
        $game_system.bgs_unpause
        Kernel.pbStartOver
      end
    end
    Events.onEndBattle.trigger(nil, decision)
  }
  Input.update
  pbSet(variable, decision)
  $game_switches[:In_Battle] = false
  return decision == 1
end

def pbTrainerBattle(trainerid, trainername, endspeech, doublebattle = false, trainerparty = 0, canlose = false, variable = Variables[:BattleResult], opponent_team: [], recorded: false, items_overwrite: nil, noexp: false, vsoutfit: 0)
  $game_switches[:In_Battle] = true
  if $Trainer.pokemonCount == 0
    Kernel.pbMessage(_INTL("SKIPPING BATTLE...")) if $DEBUG
    $game_switches[:In_Battle] = false
    return false
  end
  if !$PokemonTemp.waitingTrainer && pbMapInterpreterRunning?
    thisEvent = pbMapInterpreter.get_character(0)
    triggeredEvents = $game_player.pbTriggeredTrainerEvents([2], false)
    otherEvent = []
    for i in triggeredEvents
      if i.id != thisEvent.id && !$game_self_switches[[$game_map.map_id, i.id, "A"]]
        otherEvent.push(i)
      end
    end
    if otherEvent.length == 1
      trainer = opponent_team.length == 0 ? pbLoadTrainer(trainerid, trainername, trainerparty) : pbLoadCopiedTrainer(trainerid, trainername, trainerparty, opponent_team)
      Events.onTrainerPartyLoad.trigger(nil, trainer)
      if !trainer
        pbMissingTrainer(trainerid, trainername, trainerparty)
        $game_switches[:In_Battle] = false
        return false
      end
      if trainer[2].length <= 6 # 3
        $PokemonTemp.waitingTrainer = [trainer, thisEvent.id]
        $game_switches[:In_Battle] = false
        return false
      end
    end
  end
  trainer = opponent_team.length == 0 ? pbLoadTrainer(trainerid, trainername, trainerparty) : pbLoadCopiedTrainer(trainerid, trainername, trainerparty, opponent_team)
  Events.onTrainerPartyLoad.trigger(nil, trainer)
  if !trainer
    pbMissingTrainer(trainerid, trainername, trainerparty)
    $game_switches[:In_Battle] = false
    return false
  end
  doublebattle = true if Reborn && makeDoubles?(opponent_team.length > 0 ? opponent_team : trainer[2])
  trainer[0].outfit = vsoutfit if vsoutfit > 0
  if $PokemonGlobal.partner && ($PokemonTemp.waitingTrainer || doublebattle)
    othertrainer = PokeBattle_Trainer.new($PokemonGlobal.partner[1], $PokemonGlobal.partner[0])
    othertrainer.id = $PokemonGlobal.partner[2]
    othertrainer.party = $PokemonGlobal.partner[3]
    playerparty = []
    for i in 0...$Trainer.party.length
      playerparty[i] = $Trainer.party[i]
    end
    for i in 0...othertrainer.party.length
      playerparty[6 + i] = othertrainer.party[i]
    end
    fullparty1 = true
    playertrainer = [$Trainer, othertrainer]
    doublebattle = true
  else
    playerparty = $Trainer.party
    playertrainer = $Trainer
    fullparty1 = false
  end
  if $PokemonTemp.waitingTrainer
    combinedParty = []
    for i in 0...$PokemonTemp.waitingTrainer[0][2].length
      combinedParty[i] = $PokemonTemp.waitingTrainer[0][2][i]
    end
    for i in 0...trainer[2].length
      combinedParty[6 + i] = trainer[2][i]
    end
    fullparty2 = true
    scene = pbNewBattleScene
    battle = PokeBattle_Battle.new(scene, playerparty, combinedParty, playertrainer, [$PokemonTemp.waitingTrainer[0][0], trainer[0]], recorded)
    trainerbgm = pbGetTrainerBattleBGM([$PokemonTemp.waitingTrainer[0][0], trainer[0]])
    battle.controlPlayer = $game_switches[:AI_Play] || $game_switches[:Forced_AI_Play]
    battle.fullparty1 = fullparty1
    battle.fullparty2 = fullparty2
    battle.doublebattle = true
    battle.endspeech = $PokemonTemp.waitingTrainer[0][0].defeatline
    battle.endspeech2 = trainer[0].defeatline == "" ? endspeech : trainer[0].defeatline
    battle.endspeech = $game_variables[:Theme_Team_Defeat_Line] if $game_switches[:Theme_Team_Execution]
    battle.endspeech = $game_variables[:MnM_Defeat_Line] if $game_switches[:MnM_Execution]
    battle.endspeech2 = $game_variables[:Theme_Team_Defeat_Line] if $game_switches[:MnM_Execution]
    $PokemonTemp.waitingTrainer[0][1].nil? ? trainer1items = [] : trainer1items = $PokemonTemp.waitingTrainer[0][1]
    trainer[1].nil? ? trainer2items = [] : trainer2items = trainer[1]
    if $PokemonGlobal.partner
      battle.partneritems = $PokemonGlobal.partner[4]
    end
    battle.items = [trainer1items, trainer2items]
  else
    scene = pbNewBattleScene
    if opponent_team.length > 0
      battle = PokeBattle_Battle.new(scene, playerparty, opponent_team, playertrainer, trainer[0], recorded)
    else
      battle = PokeBattle_Battle.new(scene, playerparty, trainer[2], playertrainer, trainer[0], recorded)
    end
    battle.controlPlayer = $game_switches[:AI_Play] || $game_switches[:Forced_AI_Play]
    battle.fullparty1 = fullparty1
    battle.doublebattle = doublebattle ? true : false
    battle.endspeech = trainer[0].defeatline == "" ? endspeech : trainer[0].defeatline
    battle.endspeech = $game_variables[:Theme_Team_Defeat_Line] if $game_switches[:Theme_Team_Execution] || $game_switches[:MnM_Execution]
    battle.items = trainer[1]
    battle.items = items_overwrite if items_overwrite
    if $PokemonGlobal.partner
      battle.partneritems = $PokemonGlobal.partner[4]
    end
    trainerbgm = pbGetTrainerBattleBGM(trainer[0])
  end
  if Input.press?(Input::CTRL) && $DEBUG
    Kernel.pbMessage(_INTL("SKIPPING BATTLE..."))
    Kernel.pbMessage(_INTL("AFTER LOSING..."))
    Kernel.pbMessage(pbGetMessageFromHash(MessageTypes::EndSpeechLose, battle.endspeech))
    Kernel.pbMessage(pbGetMessageFromHash(MessageTypes::EndSpeechLose, battle.endspeech2)) if battle.endspeech2 && battle.endspeech2 != ""
    if $PokemonTemp.waitingTrainer
      pbMapInterpreter.pbSetSelfSwitch($PokemonTemp.waitingTrainer[1], "A", true)
      $PokemonTemp.waitingTrainer = nil
    end
    $game_switches[:In_Battle] = false
    return true
  end
  if $game_switches[:No_Battles_Pass] && Kernel.pbConfirmMessage("Skip battle?")
    Kernel.pbMessage(_INTL("After losing: "))
    Kernel.pbMessage(pbGetMessageFromHash(MessageTypes::EndSpeechLose, battle.endspeech))
    Kernel.pbMessage(pbGetMessageFromHash(MessageTypes::EndSpeechLose, battle.endspeech2)) if battle.endspeech2 && battle.endspeech2 != ""
    if $PokemonTemp.waitingTrainer
      pbMapInterpreter.pbSetSelfSwitch($PokemonTemp.waitingTrainer[1], "A", true)
      $PokemonTemp.waitingTrainer = nil
    end
    $game_switches[:In_Battle] = false
    return true
  end
  battle.disableExpGain = true if noexp
  Events.onStartBattle.trigger(nil, nil)
  battle.internalbattle = true
  pbPrepareBattle(battle)
  decision = 0
  pbBattleAnimation(trainerbgm, trainer[0].trainertype, trainer[0].name, false, vsoutfit) {
    pbSceneStandby {
      decision = battle.pbStartBattle(canlose)
    }
    if $PokemonGlobal.partner
      pbHealAll
      for i in $PokemonGlobal.partner[3]
        i.heal
     end
    end
    if decision == 2 || decision == 5
      if canlose
        for i in 0...$Trainer.party.length
          $Trainer.party[i].heal if !$game_switches[:Nuzlocke_Mode] || !battle.fainted_mons[i]
        end
        for i in 0...10
          Graphics.update
        end
      else
        $game_system.bgm_unpause
        $game_system.bgs_unpause
        Kernel.pbStartOver
      end
    elsif decision == 1 && $PokemonTemp.waitingTrainer
      pbMapInterpreter.pbSetSelfSwitch($PokemonTemp.waitingTrainer[1], "A", true)
      # Activate the D switch on both trainers if the player beats them in a double battle.
      # Used for teasing the colosseum password in Reborn.
      pbMapInterpreter.pbSetSelfSwitch(pbMapInterpreter.get_character(0).id, "D", true)
      pbMapInterpreter.pbSetSelfSwitch($PokemonTemp.waitingTrainer[1], "D", true)
    end
    Events.onEndBattle.trigger(nil, decision)
  }
  Input.update
  pbSet(variable, decision)
  $PokemonTemp.waitingTrainer = nil
  $game_switches[:In_Battle] = false
  return decision == 1
end

def pbTrainerBattle100(trainerid, trainername, endspeech, doublebattle = false, trainerparty = 0, canlose = false, variable = Variables[:BattleResult])
  if $Trainer.pokemonCount == 0
    Kernel.pbMessage(_INTL("SKIPPING BATTLE...")) if $DEBUG
    return false
  end
  if !$PokemonTemp.waitingTrainer && pbMapInterpreterRunning?
    thisEvent = pbMapInterpreter.get_character(0)
    triggeredEvents = $game_player.pbTriggeredTrainerEvents([2], false)
    otherEvent = []
    for i in triggeredEvents
      if i.id != thisEvent.id && !$game_self_switches[[$game_map.map_id, i.id, "A"]]
        otherEvent.push(i)
      end
    end
    if otherEvent.length == 1
      trainer = pbLoadTrainer(trainerid, trainername, trainerparty)
      Events.onTrainerPartyLoad.trigger(nil, trainer)
      if !trainer
        pbMissingTrainer(trainerid, trainername, trainerparty)
        return false
      end
      if trainer[2].length <= 6 # 3
        $PokemonTemp.waitingTrainer = [trainer, thisEvent.id]
        return false
      end
    end
  end
  trainer = pbLoadTrainer(trainerid, trainername, trainerparty)
  Events.onTrainerPartyLoad.trigger(nil, trainer)
  if !trainer
    pbMissingTrainer(trainerid, trainername, trainerparty)
    return false
  end
  doublebattle = true if Reborn && makeDoubles?(trainer[2])
  # creating player party
  if $PokemonGlobal.partner && ($PokemonTemp.waitingTrainer || doublebattle)
    othertrainer = PokeBattle_Trainer.new($PokemonGlobal.partner[1], $PokemonGlobal.partner[0])
    othertrainer.id = $PokemonGlobal.partner[2]
    othertrainer.party = $PokemonGlobal.partner[3]
    playerparty = []
    for i in 0...$Trainer.party.length
      playerparty[i] = $Trainer.party[i]
    end
    for i in 0...othertrainer.party.length
      playerparty[6 + i] = othertrainer.party[i]
    end
    fullparty1 = true
    playertrainer = [$Trainer, othertrainer]
    doublebattle = true
  else
    playerparty = []
    for i in 0...$Trainer.party.length
      playerparty[i] = $Trainer.party[i]
    end
    playertrainer = $Trainer
    fullparty1 = false
  end
  olditems = $Trainer.party.transform { |p| p.item }
  if $PokemonTemp.waitingTrainer
    combinedParty = []
    for i in 0...$PokemonTemp.waitingTrainer[0][2].length
      combinedParty[i] = $PokemonTemp.waitingTrainer[0][2][i]
    end
    for i in 0...trainer[2].length
      combinedParty[6 + i] = trainer[2][i]
    end
    fullparty2 = true
    scene = pbNewBattleScene
    battle = PokeBattle_Battle.new(scene, playerparty, combinedParty, playertrainer, [$PokemonTemp.waitingTrainer[0][0], trainer[0]])
    trainerbgm = pbGetTrainerBattleBGM([$PokemonTemp.waitingTrainer[0][0], trainer[0]])
    battle.controlPlayer = $game_switches[:AI_Play] || $game_switches[:Forced_AI_Play]
    battle.fullparty1 = fullparty1
    battle.fullparty2 = fullparty2
    battle.doublebattle = true
    battle.endspeech = $PokemonTemp.waitingTrainer[0][0].defeatline
    battle.endspeech2 = trainer[0].defeatline == "" ? endspeech : trainer[0].defeatline
    battle.endspeech = $game_variables[:Theme_Team_Defeat_Line] if $game_switches[:Theme_Team_Execution]
    battle.endspeech = $game_variables[:MnM_Defeat_Line] if $game_switches[:MnM_Execution]
    battle.endspeech2 = $game_variables[:Theme_Team_Defeat_Line] if $game_switches[:MnM_Execution]
    $PokemonTemp.waitingTrainer[0][1].nil? ? trainer1items = [] : trainer1items = $PokemonTemp.waitingTrainer[0][1]
    trainer[1].nil? ? trainer2items = [] : trainer2items = trainer[1]
    if $PokemonGlobal.partner
      battle.partneritems = $PokemonGlobal.partner[4]
    end
    battle.items = [trainer1items, trainer2items]
  else
    scene = pbNewBattleScene
    battle = PokeBattle_Battle.new(scene, playerparty, trainer[2], playertrainer, trainer[0])
    battle.controlPlayer = $game_switches[:AI_Play] || $game_switches[:Forced_AI_Play]
    battle.fullparty1 = fullparty1
    battle.doublebattle = doublebattle ? true : false
    battle.endspeech = trainer[0].defeatline == "" ? endspeech : trainer[0].defeatline
    battle.endspeech = $game_variables[:Theme_Team_Defeat_Line] if $game_switches[:Theme_Team_Execution] || $game_switches[:MnM_Execution]
    battle.items = trainer[1]
    if $PokemonGlobal.partner
      battle.partneritems = $PokemonGlobal.partner[4]
    end
    trainerbgm = pbGetTrainerBattleBGM(trainer[0])
  end
  if Input.press?(Input::CTRL) && $DEBUG
    Kernel.pbMessage(_INTL("SKIPPING BATTLE..."))
    Kernel.pbMessage(_INTL("AFTER LOSING..."))
    Kernel.pbMessage(pbGetMessageFromHash(MessageTypes::EndSpeechLose, battle.endspeech))
    Kernel.pbMessage(pbGetMessageFromHash(MessageTypes::EndSpeechLose, battle.endspeech2)) if battle.endspeech2 && battle.endspeech2 != ""
    if $PokemonTemp.waitingTrainer
      pbMapInterpreter.pbSetSelfSwitch($PokemonTemp.waitingTrainer[1], "A", true)
      $PokemonTemp.waitingTrainer = nil
    end
    return true
  end
  if $game_switches[:No_Battles_Pass] && Kernel.pbConfirmMessage("Skip battle?")
    Kernel.pbMessage(_INTL("After losing: "))
    Kernel.pbMessage(pbGetMessageFromHash(MessageTypes::EndSpeechLose, battle.endspeech))
    Kernel.pbMessage(pbGetMessageFromHash(MessageTypes::EndSpeechLose, battle.endspeech2)) if battle.endspeech2 && battle.endspeech2 != ""
    if $PokemonTemp.waitingTrainer
      pbMapInterpreter.pbSetSelfSwitch($PokemonTemp.waitingTrainer[1], "A", true)
      $PokemonTemp.waitingTrainer = nil
    end
    return true
  end
  # disable exp gain for this battle
  battle.disableExpGain = true
  # making all pokemon lvl 100
  pokemonexp = []
  pokemonlevels = []
  for i in playerparty
    next if i.nil?

    unless i.isEgg?
      pokemonexp.push(i.exp)
      pokemonlevels.push(i.level)
      i.level = 100
      i.exp = PBExp.startExperience(100, i.growthrate)
      i.calcStats
    end
  end
  Events.onStartBattle.trigger(nil, nil)
  battle.internalbattle = true
  pbPrepareBattle(battle)
  decision = 0
  pbBattleAnimation(trainerbgm, trainer[0].trainertype, trainer[0].name) {
    pbSceneStandby {
      decision = battle.pbStartBattle(canlose)
    }
    partyindex = 0
    for i in playerparty
      next if i.nil?

      unless i.isEgg?
        i.level = pokemonlevels[partyindex]
        i.exp = pokemonexp[partyindex]
        i.calcStats
        partyindex += 1
      end
    end
    for i in 0...$Trainer.party.length; $Trainer.party[i].setItem(olditems[i]); end
    if $PokemonGlobal.partner
      pbHealAll
      for i in $PokemonGlobal.partner[3]
        i.heal
      end
    end
    if decision == 2 || decision == 5
      if canlose
        for i in $Trainer.party; i.heal; end
        for i in 0...10
          Graphics.update
        end
      else
        $game_system.bgm_unpause
        $game_system.bgs_unpause
        Kernel.pbStartOver
      end
    else
      Events.onEndBattle.trigger(nil, decision)
      if decision == 1
        if $PokemonTemp.waitingTrainer
          pbMapInterpreter.pbSetSelfSwitch($PokemonTemp.waitingTrainer[1], "A", true)
        end
      end
    end
  }
  Input.update
  pbSet(variable, decision)
  $PokemonTemp.waitingTrainer = nil
  return decision == 1
end

def pbDoubleTrainerBattle100(
  trainerid1, trainername1, trainerparty1, endspeech1,
  trainerid2, trainername2, trainerparty2, endspeech2,
  canlose = false, variable = Variables[:BattleResult], switch_sprites: false
)
  trainer1 = pbLoadTrainer(trainerid1, trainername1, trainerparty1)
  Events.onTrainerPartyLoad.trigger(nil, trainer1)
  if !trainer1
    pbMissingTrainer(trainerid1, trainername1, trainerparty1)
  end
  trainer2 = pbLoadTrainer(trainerid2, trainername2, trainerparty2)
  Events.onTrainerPartyLoad.trigger(nil, trainer2)
  if !trainer2
    pbMissingTrainer(trainerid2, trainername2, trainerparty2)
  end
  if !trainer1 || !trainer2
    return false
  end

  if $PokemonGlobal.partner
    othertrainer = PokeBattle_Trainer.new($PokemonGlobal.partner[1], $PokemonGlobal.partner[0])
    othertrainer.id = $PokemonGlobal.partner[2]
    othertrainer.party = $PokemonGlobal.partner[3]
    playerparty = []
    for i in 0...$Trainer.party.length
      playerparty[i] = $Trainer.party[i]
    end
    for i in 0...othertrainer.party.length
      playerparty[6 + i] = othertrainer.party[i]
    end
    fullparty1 = true
    playertrainer = [$Trainer, othertrainer]
  else
    playerparty = []
    for i in 0...$Trainer.party.length
      playerparty[i] = $Trainer.party[i]
    end
    playertrainer = $Trainer
    fullparty1 = false
  end
  olditems = $Trainer.party.transform { |p| p.item }
  pokemonexp = []
  pokemonlevels = []
  combinedParty = []
  for i in 0...trainer1[2].length
    combinedParty[i] = trainer1[2][i]
  end
  for i in 0...trainer2[2].length
    combinedParty[6 + i] = trainer2[2][i]
  end
  scene = pbNewBattleScene
  battle = PokeBattle_Battle.new(scene, playerparty, combinedParty, playertrainer, [trainer1[0], trainer2[0]])
  trainerbgm = pbGetTrainerBattleBGM([trainer1[0], trainer2[0]])
  battle.controlPlayer = $game_switches[:AI_Play] || $game_switches[:Forced_AI_Play]
  battle.fullparty1 = fullparty1
  battle.fullparty2 = true
  battle.doublebattle = true
  battle.endspeech = trainer1[0].defeatline == "" ? endspeech1 : trainer1[0].defeatline
  battle.endspeech2 = trainer2[0].defeatline == "" ? endspeech2 : trainer2[0].defeatline
  battle.endspeech = $game_variables[:Theme_Team_Defeat_Line] if $game_switches[:Theme_Team_Execution]
  battle.endspeech = $game_variables[:MnM_Defeat_Line] if $game_switches[:MnM_Execution]
  battle.endspeech2 = $game_variables[:Theme_Team_Defeat_Line] if $game_switches[:MnM_Execution]
  trainer1[1].nil? ? trainer1items = [] : trainer1items = trainer1[1]
  trainer2[1].nil? ? trainer2items = [] : trainer2items = trainer2[1]
  if $PokemonGlobal.partner
    battle.partneritems = $PokemonGlobal.partner[4]
  end
  battle.items = [trainer1items, trainer2items]
  if Input.press?(Input::CTRL) && $DEBUG
    Kernel.pbMessage(_INTL("SKIPPING BATTLE..."))
    Kernel.pbMessage(_INTL("AFTER LOSING..."))
    Kernel.pbMessage(pbGetMessageFromHash(MessageTypes::EndSpeechLose, battle.endspeech))
    Kernel.pbMessage(pbGetMessageFromHash(MessageTypes::EndSpeechLose, battle.endspeech2)) if battle.endspeech2 && battle.endspeech2 != ""
    return true
  end
  if $game_switches[:No_Battles_Pass] && Kernel.pbConfirmMessage("Skip battle?")
    Kernel.pbMessage("After losing: ")
    Kernel.pbMessage(pbGetMessageFromHash(MessageTypes::EndSpeechLose, battle.endspeech))
    Kernel.pbMessage(pbGetMessageFromHash(MessageTypes::EndSpeechLose, battle.endspeech2)) if battle.endspeech2 && battle.endspeech2 != ""
    return true
  end
  # disable exp gain for this battle
  battle.disableExpGain = true
  for i in playerparty
    next if i.nil?

    unless i.isEgg?
      pokemonexp.push(i.exp)
      pokemonlevels.push(i.level)
      i.level = 100
      i.exp = PBExp.startExperience(100, i.growthrate)
      i.calcStats
    end
  end
  Events.onStartBattle.trigger(nil, nil)
  Events.onDoubleBattleLoad.trigger("trainer", trainer1, trainer2)
  battle.internalbattle = true
  pbPrepareBattle(battle)
  decision = 0
  pbBattleAnimation(trainerbgm, [trainerid1, trainerid2], [trainer1[0].name, trainer2[0].name], switch_sprites) {
    pbSceneStandby {
      decision = battle.pbStartBattle(canlose)
    }
    partyindex = 0
    for i in playerparty
      next if i.nil?

      unless i.isEgg?
        i.level = pokemonlevels[partyindex]
        i.exp = pokemonexp[partyindex]
        partyindex += 1
        i.calcStats
      end
    end
    for i in 0...$Trainer.party.length; $Trainer.party[i].setItem(olditems[i]); end

    if $PokemonGlobal.partner
      pbHealAll
      for i in $PokemonGlobal.partner[3]
        i.heal
      end
    end
    if decision == 2 || decision == 5
      if canlose
        for i in $Trainer.party; i.heal; end
        for i in 0...10
          Graphics.update
        end
      else
        $game_system.bgm_unpause
        $game_system.bgs_unpause
        Kernel.pbStartOver
      end
    end
    Events.onEndBattle.trigger(nil, decision)
  }
  Input.update
  pbSet(variable, decision)
  return decision == 1
end
