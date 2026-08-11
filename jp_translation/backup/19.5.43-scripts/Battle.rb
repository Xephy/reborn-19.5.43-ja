# Results of battle:
#    0 - Undecided or aborted
#    1 - Player won
#    2 - Player lost
#    3 - Player or wild Pokémon ran from battle, or player forfeited the match
#    4 - Wild Pokémon was caught
#    5 - Draw

class PokeBattle_RealBattlePeer
  def pbOnEnteringBattle(battle, pokemon)
  end
end

################################################################################
# Catching and storing Pokémon.
################################################################################
module PokeBattle_BattleCommon
  def pbStorePokemon(pokemon)
    if !(pokemon.isShadow? rescue false) && $Settings.nicknames == 0
      if pbDisplayConfirm(_INTL("Would you like to give a nickname to {1}?", pokemon.name))
        species = getMonName(pokemon.species, pokemon.form)
        nickname = @scene.pbNameEntry(_INTL("{1}'s nickname?", species), pokemon)
        pokemon.name = nickname if nickname != ""
      end
    end
    oldcurbox = @peer.pbCurrentBox()
    storedbox = @peer.pbStorePokemon(self.pbPlayer, pokemon)
    creator = @peer.pbGetStorageCreator()
    return if storedbox < 0

    curboxname = @peer.pbBoxName(oldcurbox)
    boxname = @peer.pbBoxName(storedbox)
    if storedbox != oldcurbox
      if creator
        pbDisplayPaused(_INTL("Box \"{1}\" on {2}'s PC was full.", curboxname, creator))
      else
        pbDisplayPaused(_INTL("Box \"{1}\" on someone's PC was full.", curboxname))
      end
      pbDisplayPaused(_INTL("{1} was transferred to box \"{2}\".", pokemon.name, boxname))
    else
      if creator
        pbDisplayPaused(_INTL("{1} was transferred to {2}'s PC.", pokemon.name, creator))
      else
        pbDisplayPaused(_INTL("{1} was transferred to someone's PC.", pokemon.name))
      end
      pbDisplayPaused(_INTL("It was stored in box \"{1}\".", boxname))
    end
  end

  def pbBallFetch(pokeball)
    for i in 0...4
      if self.battlers[i].ability == :BALLFETCH && self.battlers[i].item.nil?
        self.battlers[i].effects[:BallFetch] = pokeball
      end
    end
  end

  def pbThrowPokeBall(idxPokemon, ball, rareness = nil, showplayer = false)
    itemname = getItemName(ball)
    battler = nil
    if pbIsOpposing?(idxPokemon)
      battler = self.battlers[idxPokemon]
    else
      battler = self.battlers[idxPokemon].pbOppositeOpposing
    end
    if battler.isFainted?
      battler = battler.pbPartner
    elsif !battler.pbPartner.isFainted?
      idxPokemon = self.scene.pbChooseBallTarget(idxPokemon)
      return if idxPokemon == -1

      battler = self.battlers[idxPokemon]
    end
    oldform = battler.form
    battler.form = battler.pokemon.getForm(battler.pokemon)
    pbDisplayBrief(_INTL("{1} threw a {2}!", self.pbPlayer.name, itemname))
    if battler.isFainted?
      pbDisplay(_INTL("But there was no target..."))
      pbBallFetch(ball)
      return
    end
    snag = pbIsSnagBall?(ball) && battler.isShadow?
    # "yoink" password only allows one snag per battle
    snag = true if $game_switches[:SnagMachine_Password] && @snaggedpokemon == [] &&
                   !$cache.pkmn[battler.species, battler.form].checkFlag?(:ExcludeDex) && battler.ev.all? { |ev| ev <= 252 }
    snag = false if isOnline?
    if @opponent && !snag
      @scene.pbThrowAndDeflect(ball, 1)
      if $game_switches[:No_Catching] || battler.isbossmon || battler.issossmon
        pbDisplay(_INTL("The Pokémon knocked the ball away!"))
      else
        pbDisplay(_INTL("The Trainer blocked the Ball!\nDon't be a thief!"))
      end
    else
      if !snag
        if $game_switches[:No_Catching] || battler.issossmon || (battler.isbossmon && (!battler.capturable || battler.shieldCount > 0))
          pbDisplay(_INTL("The Pokémon knocked the ball away!"))
          pbBallFetch(ball)
          return
        end
      end
      pokemon = battler.pokemon
      species = pokemon.species
      rareness = pokemon.catchRate if !rareness
      rareness /= 2 if $game_variables[:LuckMoves] != 0
      a = battler.totalhp
      b = battler.hp
      rareness = BallHandlers.modifyCatchRate(ball, rareness, self, battler)
      rareness += 1 if $PokemonBag.pbQuantity(:CATCHINGCHARM) > 0
      rareness += 1 if Reborn && $PokemonBag.pbQuantity(:CATCHINGCHARM2) > 0
      rareness += 1 if Reborn && $PokemonBag.pbQuantity(:CATCHINGCHARM3) > 0
      rareness += 1 if Reborn && $PokemonBag.pbQuantity(:CATCHINGCHARM4) > 0
      if battler.isbossmon && battler.capturable && battler.shieldCount == 0
        rareness += 3
      end
      x = (((a * 3 - b * 2) * rareness) / (a * 3))
      if battler.status == :SLEEP || battler.status == :FROZEN
        x = (x * 2.5)
      elsif !battler.status.nil?
        x = (x * 3 / 2)
      end
      # Critical Capture chances based on caught species'
      c = 0
      if $Trainer
        mod = -3
        mod += 0.5 if $Trainer.pokedex.getOwnedCount > 500
        mod += 0.5 if $Trainer.pokedex.getOwnedCount > 400
        mod += 0.5 if $Trainer.pokedex.getOwnedCount > 300
        mod += 0.5 if $Trainer.pokedex.getOwnedCount > 200
        mod += 0.5 if $Trainer.pokedex.getOwnedCount > 100
        mod += 0.5 if $Trainer.pokedex.getOwnedCount > 30
        c = (x * (2**mod)).floor
      end
      shakes = 0; critical = false; critsuccess = false
      if x > 255 || BallHandlers.isUnconditional?(ball, self, battler)
        shakes = 4
      else
        x = 1 if x == 0
        y = (65536 / ((255.0 / x)**0.1875)).floor
        puts "c = #{c}; x = #{x}"
        percentage = (1 / ((255.0 / x)**0.1875))**4
        puts "Catch chance: #{percentage * 100}%"
        percentage = c / 256.0 * (1 / ((255.0 / x)**0.1875))
        puts "Crit chance: #{percentage * 100}%"
        if pbRandom(256) < c
          critical = true
          if pbRandom(65536) < y
            critsuccess = true
            shakes = 4
          end
        else
          shakes += 1 if pbRandom(65536) < y
          shakes += 1 if pbRandom(65536) < y
          shakes += 1 if pbRandom(65536) < y
          shakes += 1 if pbRandom(65536) < y
        end
      end
      shakes = 4 if $DEBUG && Input.press?(Input::CTRL)
      @scene.pbThrow(ball, critical ? 1 : shakes, critical, critsuccess, battler.index, showplayer)
      case shakes
        when 0
          pbDisplay(_INTL("Oh no! The Pokémon broke free!"))
          pbBallFetch(ball)
          BallHandlers.onFailCatch(ball, self, pokemon)
          battler.form = oldform
        when 1
          pbDisplay(_INTL("Aww... It appeared to be caught!"))
          pbBallFetch(ball)
          BallHandlers.onFailCatch(ball, self, pokemon)
          battler.form = oldform
        when 2
          pbDisplay(_INTL("Aargh! Almost had it!"))
          pbBallFetch(ball)
          BallHandlers.onFailCatch(ball, self, pokemon)
          battler.form = oldform
        when 3
          pbDisplay(_INTL("Shoot! It was so close, too!"))
          pbBallFetch(ball)
          BallHandlers.onFailCatch(ball, self, pokemon)
          battler.form = oldform
        when 4
          # shadow catch should not be segmented like this
          @scene.pbWildBattleSuccess if !@opponent && battler.pbPartner.isFainted?
          pbDisplayPaused(_INTL("Gotcha! {1} was caught!", pokemon.name))
          @scene.pbThrowSuccess
          if @opponent
            if snag
              8.times do
                @scene.sprites["battlebox#{battler.index}"].opacity -= 32
                @scene.pbGraphicsUpdate
              end
              pbRemoveFromParty(battler.index, battler.pokemonIndex)
              battler.pbReset
              battler.participants = []
            end
          else
            @decision = 4
          end
          pokemon.obtainMode = 3 # caught
          if @opponent && snag
            # Snagged shadow mons apparently use player as OT in canon
            owner = !Reborn && battler.isShadow? ? pbPlayer : pbGetOwner(battler.index)
            pokemon.ot = owner.name
            pokemon.trainerID = owner.id
            pokemon.obtainMode = 5 # snagged
          end
          BallHandlers.onCatch(ball, self, pokemon)
          pokemon.ballused = ball
          pokemon.pbRecordFirstMoves
          if !$Trainer.pokedex.dexList[species][:owned?]
            $Trainer.pokedex.setOwned(pokemon)
            if $Trainer.pokedex.canViewDex && !snag
              pbDisplayPaused(_INTL("{1}'s data was added to the Pokédex.", pokemon.name))
              @scene.pbShowPokedex(species)
            end
          end
          $Trainer.pokedex.setFormOwned(pokemon)
          @scene.pbHideCaptureBall
          pbGainEXP
          pokemon.form = pokemon.getForm(pokemon)
          addFusion(pokemon)
          if snag && @opponent
            pokemon.pbUpdateShadowMoves rescue nil
            @snaggedpokemon.push(pokemon)
            @scene.partyBetweenKO1 unless @battle.doublebattle
          else
            pbStorePokemon(pokemon)
          end
      end
    end
  end

  def addFusion(pokemon)
    if pokemon.species == :KYUREM && pokemon.form == 1
      pokemon.fused = PokeBattle_Pokemon.new(:RESHIRAM, pokemon.level)
    elsif pokemon.species == :KYUREM && pokemon.form == 2
      pokemon.fused = PokeBattle_Pokemon.new(:ZEKROM, pokemon.level)
    elsif pokemon.species == :NECROZMA && pokemon.form == 1
      pokemon.fused = PokeBattle_Pokemon.new(:SOLGALEO, pokemon.level)
    elsif pokemon.species == :NECROZMA && pokemon.form == 2
      pokemon.fused = PokeBattle_Pokemon.new(:LUNALA, pokemon.level)
    elsif pokemon.species == :CALYREX && pokemon.form == 1
      pokemon.fused = PokeBattle_Pokemon.new(:GLASTRIER, pokemon.level)
    elsif pokemon.species == :CALYREX && pokemon.form == 2
      pokemon.fused = PokeBattle_Pokemon.new(:SPECTRIER, pokemon.level)
    elsif Rejuv && pokemon.species == :LUNATONE && pokemon.form == 1
      pokemon.fused = PokeBattle_Pokemon.new(:SOLROCK, pokemon.level)
    elsif Rejuv && pokemon.species == :SOLROCK && pokemon.form == 1
      pokemon.fused = PokeBattle_Pokemon.new(:LUNATONE, pokemon.level)
    end
    if pokemon.fused
      pokemon.fused.ot = pokemon.ot
      pokemon.fused.trainerID = pokemon.trainerID
    end
  end
end

################################################################################
# Main battle class.
################################################################################
class PokeBattle_Battle
  attr_reader(:scene)             # Scene object for this battle
  attr_accessor(:decision)        # Decision: 0=undecided; 1=win; 2=loss; 3=escaped; 4=caught
  attr_accessor(:internalbattle)  # Internal battle flag
  attr_accessor(:doublebattle)    # Double battle flag
  attr_accessor(:cantescape)      # True if player can't escape
  attr_accessor(:shiftStyle)      # Shift/Set "battle style" option
  attr_accessor(:battlescene)     # "Battle scene" option
  attr_reader(:player)            # Player trainer(s)
  attr_reader(:opponent)          # Opponent trainer(s)
  attr_accessor(:party1)          # player's (combined) Pokémon party
  attr_accessor(:party2)          # opponent's (combined) Pokémon party
  attr_reader(:partyorder)        # Order of Pokémon in player's party
  attr_accessor(:fullparty1)      # True if party1's max size is 12 instead of 6 (2 trainers instead of 1)
  attr_accessor(:fullparty2)      # True if party2's max size is 12 instead of 6 (2 trainers instead of 1)
  attr_reader(:battlers)          # Currently active Pokémon
  attr_reader(:priority)          # Move order of active Pokémon
  attr_accessor(:items)           # Items held by opponents
  attr_accessor(:partneritems)    # Items held by AI partners :)
  attr_accessor(:sides)           # Effects common to each side of a battle
  attr_accessor(:state)
  attr_accessor(:field)           # Effects common to the whole of a battle
  attr_accessor(:environment)     # Battle surroundings
  attr_accessor(:weather)         # Current weather, custom methods should use pbWeather instead
  attr_accessor(:weatherduration) # Duration of current weather, or -1 if indefinite
  attr_accessor(:weatherbackup) # The original weather of the area, if it exists.  #### DemICE - persistentweather
  attr_accessor(:weatherbackupanim) # Easy loading for original weather's animation.  #### DemICE - persistentweather
  attr_reader(:switching)         # True if during the switching phase of the round
  attr_accessor(:struggle)        # The Struggle move
  # Array of 4 arrays, one for each battler
  # Inner array can have the following values:
  # Nothing: [0, 0, nil, -1]
  # Move:    [1, moveIndex, PokeBattle_Move, targetIndex]
  # Switch:  [2, partyIndex, nil, -1]
  # Item:    [3, itemSymbol, partyIndex, -1]
  # Call:    [4, 0, nil, -1]
  # Run:     [5, 0, nil, -1]
  attr_accessor(:choices)         # Choices made by each Pokémon this round
  attr_accessor(:lastMoveUsed)    # Last move used
  attr_accessor(:lastMoveUser)    # Last move user
  attr_accessor(:synchronize)     # Synchronize state
  attr_accessor(:pickupA)         # Pickup stack A (not during attack)
  attr_accessor(:pickupB)         # Pickup stack B (during attack)
  attr_accessor(:permanenteffects) # Effects that persist through switches
  # The following 3 arrays @megaEvolution, @ultraBurst and @zMove all have the same format.
  # It's an array of [sideIndex => [ownerIndex => partyIndex]]
  # sideIndex:    0 = player's side, 1 = opponent's side
  # ownerIndex:   0 in singles, 0 or 1 in doubles - index of the trainer on their respective side
  # battlerIndex: 0-3 which slot is using the mega/ultra/zmove, -1 when not yet used, -2 used before
  attr_accessor(:megaEvolution)   # Battle index of each trainer's Pokémon to Mega Evolve
  attr_accessor(:ultraBurst)      # Battle index of each trainer's Pokémon to Ultra Burst
  attr_accessor(:zMove)           # Battle index of each trainer's Pokémon to use A Z-move
  attr_accessor(:amuletcoin)      # Whether Amulet Coin's effect applies
  attr_accessor(:echoedVoice)     # Echoed Voice counter
  attr_accessor(:echoedThisRound) # Whether or not was Echoed Voice used this round
  attr_accessor(:happyhour)       # Whether Happy Hour's effect applies
  attr_accessor(:extramoney)      # Money gained in battle by using Pay Day
  attr_accessor(:endspeech)       # Speech by opponent when player wins
  attr_accessor(:endspeech2)      # Speech by opponent when player wins
  attr_accessor(:endspeechwin)    # Speech by opponent when opponent wins
  attr_accessor(:endspeechwin2)   # Speech by opponent when opponent wins
  attr_accessor(:trickroom)
  attr_accessor(:switchedOut)
  attr_accessor(:previousMove)    # Move used directly previously
  attr_accessor(:previousMoveUser) # User of above
  attr_accessor(:ai)              # our baby who's gonna throw a lot of tantrums...
  attr_accessor(:midturn)
  attr_accessor(:rules)
  attr_reader(:turncount)
  attr_accessor :controlPlayer
  attr_accessor(:disableExpGain)  # True id no exp gain during this battle
  attr_accessor(:fainted_mons)    # Store which pokemon were fainted at the start of the battle
  attr_accessor(:ace_message)     # True if ace message should be displayed
  attr_accessor(:ace_message_handled) # True if ace message has been delivered
  attr_accessor(:commandphase)    # True if during the command phase of battle

  include PokeBattle_BattleCommon
  attr_accessor(:recorded)
  attr_accessor(:sosbattle)       # Stores fight is an sos battle or not
  attr_accessor(:eruption)        # Eruption variable for Volcano Top field
  attr_accessor(:storm9)          # Controll attribute for Tempest being active (for shutoff check)
  attr_accessor(:battleRandom)
  attr_accessor(:seed)

  #boss mechanics
  attr_accessor :snapshot

  MAXPARTYSIZE = 6
  MAXPARTYSIZE2 = 12

  #### YUMIL - 4 - NPC REACTION MOD - START
  def createNewBattleRecord
    if $game_variables[:BattleDataArray].nil? || !$game_variables[:BattleDataArray].kind_of?(Array)
      $game_variables[:BattleDataArray] = []
    end
    if @opponent.kind_of?(Array)
      $game_variables[:BattleDataArray] << Battle_Data.new([@opponent[0].name, @opponent[1].name], @party1, @party2)
    else
      $game_variables[:BattleDataArray] << Battle_Data.new(@opponent.name, @party1, @party2)
    end
  end
  #### YUMIL - 4 - NPC REACTION MOD - END

  def pbRandom(x)
    return @battleRandom.rand(x)
  end

  def sample(array)
    return array[pbRandom(array.length)]
  end

  def isOnline?
    return false
  end

  ################################################################################
  # Initialise battle class.
  ################################################################################
  #### YUMIL - 4.5 - NPC REACTION MOD - START
  def initialize(scene, p1, p2, player, opponent, recorded = false)
    #### YUMIL - 4.5 - NPC REACTION MOD - END
    $battle          = self # Make current battle globally available for debugging
    @seed            = Time.now.to_i # Set the seed to the value from battle log file to reproduce the same battle scenario
    @battleRandom    = Random.new(@seed)
    @battle          = self
    @scene           = scene
    @decision        = 0
    @internalbattle  = true
    @doublebattle    = false
    @cantescape      = false
    @shiftStyle      = true
    @battlescene     = true
    #### YUMIL - 5 - NPC REACTION MOD - START
    @recorded        = recorded
    #### YUMIL - 5 - NPC REACTION MOD - END
    if opponent && player.is_a?(Array) && player.length == 0
      player = player[0]
    end
    if opponent && opponent.is_a?(Array) && opponent.length == 0
      opponent = opponent[0]
    end
    @player          = player                # PokeBattle_Trainer object
    @opponent        = opponent              # PokeBattle_Trainer object
    @party1          = p1
    @party2          = p2
    @partyorder = @player.is_a?(Array) ? (0...12).to_a : (0...6).to_a
    @fullparty1      = false
    @fullparty2      = false
    @battlers        = []
    @items           = nil
    @partneritems    = nil
    @sides           = [
      Battle_Side.new,   # Player's side
      Battle_Side.new,   # Foe's side
    ]
    @state           = Battle_Global.new # Whole field (gravity/rooms)
    @field           = PokeBattle_Field.new
    @environment     = :None # e.g. Tall grass, cave, still water
    @weather         = 0
    @weatherduration = 0
    @weatherbackup   = 0 #### DemICE - persistentweather
    @weatherbackupanim = nil #### DemICE  - persistentweather
    @storm9          = false
    @switching       = false
    @choices         = [[nil], [nil], [nil], [nil]]
    @successStates   = []
    @lastMoveUsed    = -1
    @lastMoveUser    = -1
    @synchronize     = [-1, -1, 0]
    @pickupA         = []
    @pickupB         = []
    @permanenteffects = Hash.new { |hash, key| hash[key] = {} }
    @megaEvolution   = []
    @ultraBurst      = []
    @zMove           = []
    if @player.is_a?(Array)
      @megaEvolution[0] = [-1] * @player.length
      @ultraBurst[0] = [-1] * @player.length
      @zMove[0] = [-1] * @player.length
    else
      @megaEvolution[0] = [-1]
      @ultraBurst[0] = [-1]
      @zMove[0] = [-1]
    end
    if @opponent.is_a?(Array)
      @megaEvolution[1] = [-1] * @opponent.length
      @ultraBurst[1] = [-1] * @opponent.length
      @zMove[1] = [-1] * @opponent.length
    else
      @megaEvolution[1] = [-1]
      @ultraBurst[1] = [-1]
      @zMove[1] = [-1]
    end
    @amuletcoin      = false
    @echoedVoice     = 0
    @echoedThisRound = false
    @happyhour       = false
    @switchedOut     = []
    @extramoney      = 0
    @ace_message     = false
    @ace_message_handled = false
    @endspeech       = ""
    @endspeech2      = ""
    @endspeechwin    = ""
    @endspeechwin2   = ""
    @rules           = {}
    @turncount       = 0
    @peer            = PokeBattle_BattlePeer.create()
    @trickroom       = 0
    @priority        = []
    @usepriority     = false
    @snaggedpokemon  = []
    @runCommand      = 0
    @disableExpGain  = false
    @commandphase    = false
    @eruption        = false # Volcanictop Eruption check
    @sosbattle       = 2
    @struggle = PokeBattle_Move.pbFromPBMove(self, PBMove.new(:STRUGGLE), nil)
    @struggle.pp = -1
    for i in 0...4
      @battlers[i] = PokeBattle_Battler.new(self, i)
    end
    if !isOnline?
      for i in @party1
        next if !i
        next if i.nil?

        i.obedient = i.level <= LEVELCAPS[pbPlayer.numbadges]
      end
    end
    for i in @party1
      next if !i

      i.itemRecycle = nil
      i.itemInitial = i.item
      i.itemReallyInitialHonestlyIMeanItThisTime = i.item
      i.belch       = false
      i.piece       = nil
    end
    for i in @party2
      next if !i

      i.itemRecycle = nil
      i.itemInitial = i.item
      i.belch       = false
      i.piece       = nil
    end
    #### YUMIL - 6 - NPC REACTION MOD - START
    if @recorded || @battle.FE == :CROWD
      createNewBattleRecord
    end
    #### YUMIL - 6 - NPC REACTION MOD - END
  end

  ################################################################################
  # Info about battle.
  ################################################################################
  def pbIsWild?
    return !@opponent ? true : false
  end

  def pbDoubleBattleAllowed?
    return true
  end

  def pbCheckSideAbility(a, pkmn) # checks to see if your side has a pokemon with a certain ability.
    for i in 0...4 # in order from own first, opposing first, own second, opposing second
      if @battlers[i].ability == (a)
        if @battlers[i] == pkmn || @battlers[i] == pkmn.pbPartner
          return @battlers[i]
        end
      end
    end
    return nil
  end

  def pbWeather
    for i in 0...4
      if @battlers[i].ability == :CLOUDNINE || @battlers[i].ability == :AIRLOCK || @field.effect == :UNDERWATER || @field.effect == :NEWWORLD
        return 0
      end
    end
    return @weather
  end

  def quarkdriveCheck
    priority = pbPriority
    if @field.effect == :ELECTERRAIN || @state.effects[:ELECTERRAIN] > 0
      for i in priority
        next if i.isFainted?
        next if i.ability != :QUARKDRIVE
        next if i.effects[:Quarkdrive][0] > 0

        aBoost = (i.attack * PBStats::StageMul[i.stages[PBStats::ATTACK]]).floor
        dBoost = (i.defense * PBStats::StageMul[i.stages[PBStats::DEFENSE]]).floor
        saBoost = (i.spatk * PBStats::StageMul[i.stages[PBStats::SPATK]]).floor
        sdBoost = (i.spdef * PBStats::StageMul[i.stages[PBStats::SPDEF]]).floor
        spdBoost = (i.speed * PBStats::StageMul[i.stages[PBStats::SPEED]]).floor
        stats = [aBoost, dBoost, saBoost, sdBoost, spdBoost]
        boostStat = stats.index(stats.max) + 1
        i.effects[:Quarkdrive] = [boostStat, false]
        @battle.pbDisplay(_INTL("{1}'s Quark Drive heightened its {2}!", i.pbThis, i.pbGetStatName(boostStat)))
      end
    end
    if @field.effect != :ELECTERRAIN && @state.effects[:ELECTERRAIN] < 1
      for i in priority
        next if i.isFainted?
        next if i.effects[:Quarkdrive][0] == 0
        next if i.effects[:Quarkdrive][1]

        i.effects[:Quarkdrive] = [0, false]
        pbDisplay(_INTL("{1}'s Quark Drive shut off!", i.pbThis))
        if i.item == :BOOSTERENERGY
          i.pbDisposeItem(false)
          @battle.pbDisplay(_INTL("{1}'s Booster Energy was used up...", i.pbThis))
          aBoost = (i.attack * PBStats::StageMul[i.stages[PBStats::ATTACK]]).floor
          dBoost = (i.defense * PBStats::StageMul[i.stages[PBStats::DEFENSE]]).floor
          saBoost = (i.spatk * PBStats::StageMul[i.stages[PBStats::SPATK]]).floor
          sdBoost = (i.spdef * PBStats::StageMul[i.stages[PBStats::SPDEF]]).floor
          spdBoost = (i.speed * PBStats::StageMul[i.stages[PBStats::SPEED]]).floor
          stats = [aBoost, dBoost, saBoost, sdBoost, spdBoost]
          boostStat = stats.index(stats.max) + 1
          i.effects[:Quarkdrive] = [boostStat, true]
          @battle.pbDisplay(_INTL("{1}'s Quark Drive heightened its {2}!", i.pbThis, i.pbGetStatName(boostStat)))
        end
      end
    end
  end

  def seedCheck
    for battler in pbPriority
      next if battler.hp == 0 || !battler.item
      next if !battler.itemWorks?

      seeddata = @field.seeds
      next if battler.item != seeddata[:seedtype]

      boostlevel = ["", "", "sharply ", "drastically "]

      # Stat boost from seed
      statupanimplayed = false
      statdownanimplayed = false
      seeddata[:stats].each_pair { |stat, statval|
        statval *= -1 if battler.ability == :CONTRARY
        if statval > 0 && !battler.pbTooHigh?(stat, ignoreContrary: true)
          battler.pbIncreaseStatBasic(stat, statval)
          @battle.pbCommonAnimation("StatUp", battler) if !statupanimplayed
          statupanimplayed = true
          pbDisplay(_INTL("{1}'s {2} {3}boosted its {4}!", battler.pbThis, getItemName(battler.item), boostlevel[statval.abs], battler.pbGetStatName(stat)))
        elsif statval < 0 && !battler.pbTooLow?(stat, ignoreContrary: true)
          battler.pbReduceStatBasic(stat, -statval)
          @battle.pbCommonAnimation("StatDown", battler) if !statdownanimplayed
          statdownanimplayed = true
          pbDisplay(_INTL("{1}'s {2} {3}lowered its {4}!", battler.pbThis, getItemName(battler.item), boostlevel[statval.abs], battler.pbGetStatName(stat)))
        end
      }

      # Special effect from seed that need specific code
      case @field.effect
        when :MISTY, :RAINBOW, :STARLIGHT
          if battler.effects[:Wish] == 0
            battler.effects[:Wish] = 2
            battler.effects[:WishAmount] = ((battler.totalhp + 1) * 0.75).floor
            battler.effects[:WishMaker] = battler.pokemonIndex
            pbAnimation(:WISH, battler, nil)
            pbDisplay(_INTL("A wish was made for {1}!", battler.pbThis(true)))
          end

        when :BURNING, :DESERT, :VOLCANIC
          battler.effects[:MultiTurn] = 4
          battler.effects[:MultiTurnUser] = battler.index

        when :SWAMP
          if Rejuv
            battler.changeAbility(:CLEARBODY)
          end

        when :CORROSIVEMIST, :MURKWATERSURFACE, :CORRUPTED
          if battler.pbCanPoison?(true, true, battler.ability == :CORROSION)
            battler.pbPoison(battler, true)
            pbDisplay(_INTL("{1} was badly poisoned!", battler.pbThis))
          end

        when :ICY
          if !battler.isAirborne? && battler.ability != :MAGICGUARD
            spikesdiv = [8, 8, 6, 4][battler.pbOwnSide.effects[:Spikes]]
            @scene.pbDamageAnimation(battler, 0)
            battler.pbReduceHP([(battler.totalhp.to_f / spikesdiv).floor, 1].max)
            pbDisplay(_INTL("{1} was hurt by icy Spikes!", battler.pbThis))
          end

        when :ROCKY, :CAVE
          if battler.ability != :MAGICGUARD
            atype = :ROCK
            eff = PBTypes.twoTypeEff(atype, battler.type1, battler.type2)
            if eff > 0
              eff = eff * 2
              @scene.pbDamageAnimation(battler, 0)
              battler.pbReduceHP([(battler.totalhp * eff / 32).floor, 1].max)
              pbDisplay(_INTL("{1} was hurt by Stealth Rocks!", battler.pbThis))
            end
          end

        when :WASTELAND
          battler.pbOwnSide.effects[:StealthRock] = true
          battler.pbOpposingSide.effects[:StealthRock] = true
          pbDisplay(_INTL("{1} laid Stealth Rocks everywhere!", battler.pbThis))

        when :UNDERWATER
          battler.type1 = :WATER
          battler.type2 = nil

        when :GLITCH
          battler.type1 = :QMARKS
          battler.type2 = nil

        when :NEWWORLD
          battler.currentMove = 0

        when :INVERSE
          if Rejuv
            battler.type1 = :NORMAL
            battler.type2 = nil
            battler.changeAbility(:NORMALIZE)
          else
            battler.currentMove = 0
          end

        when :PSYTERRAIN
          if battler.pbCanConfuseSelf?(false)
            battler.effects[:Confusion] = 2 + pbRandom(4)
            pbCommonAnimation("Confusion", battler, nil)
            pbDisplay(_INTL("{1} became confused!", battler.pbThis))
          end

        when :DIMENSIONAL
          if @trickroom == 0
            rnd = pbRandom(6)
            @trickroom = 3 + rnd
            pbAnimation(:TRICKROOM, battler, nil)
            pbDisplay(_INTL("{1} twisted the dimensions!", battler.pbThis))
          else
            @trickroom = 0
            pbAnimation(:TRICKROOM, battler, nil)
            pbDisplay(_INTL("The twisted dimensions returned to normal!", battler.pbThis))
          end

        when :HAUNTED
          if battler.pbCanBurn?(false)
            battler.pbBurn(battler)
            pbDisplay(_INTL("{1} was burned!", battler.pbThis))
          end

        when :INFERNAL
          battler.effects[:MeanLook] = battler.index

        when :DEEPEARTH
          w = battler.battlerToPokemon ? battler.battlerToPokemon.weight : 500
          battler.effects[:WeightModifier] += w

        when :CROWD
          battler.cheer
          battler.pbOppositeOpposing.effects[:LockOn] = 2
          battler.pbOppositeOpposing.effects[:LockOnPos] = battler.index
          battler.pbCrossOpposing.effects[:LockOn] = 2
          battler.pbCrossOpposing.effects[:LockOnPos] = battler.index

        when :DANCEFLOOR
          battler.changeAbility(:DANCER)
      end

      # Special effect from seed that doesn't need specific code
      battler.effects[seeddata[:effect]] = seeddata[:duration] if seeddata[:effect].is_a?(Symbol)

      pbCommonAnimation(seeddata[:animation], battler, nil) if seeddata[:animation].is_a?(String)
      pbAnimation(seeddata[:animation], battler, nil) if seeddata[:animation].is_a?(Symbol)

      if seeddata[:message].is_a?(String) && seeddata[:message] != ""
        if seeddata[:message].start_with?("{1}")
          pbDisplay(_INTL(seeddata[:message], battler.pbThis))
        else
          pbDisplay(_INTL(seeddata[:message], battler.pbThis(true)))
        end
      end

      battler.pbDisposeItem(false)

      if @battle.ProgressiveFieldCheck(PBFields::FLOWERGARDEN, 1, 4)
        growField("The synthetic seed", battler)
      end
      if @field.effect == :DARKNESS1
        growField('The shadows grow...', battler)
      end
      if @field.effect == :DARKNESS2
        growField('The shadows engulf the surroundings!', battler)
      end

      battler.pbFaint if battler.isFainted?
    end
  end

  ################################################################################
  # Get battler info.
  ################################################################################
  def pbIsOpposing?(index)
    return (index % 2) == 1
  end

  def pbOwnedByPlayer?(index)
    return false if pbIsOpposing?(index)
    return false if @player.is_a?(Array) && index == 2
    return false if @battle.battlers[index].issossmon

    return true
  end

  def pbOwnedByAIPartner?(index)
    # primarily a check for multi-battles.
    return @player.is_a?(Array) && index == 2
  end

  def pbIsDoubleBattler?(index)
    return index >= 2
  end

  def pbThisEx(battlerindex, pokemonindex)
    party = pbParty(battlerindex)
    if pbIsOpposing?(battlerindex)
      if @opponent || party[pokemonindex].sosmon
        return _INTL("The foe's {1}", party[pokemonindex].name)
      elsif Rejuv && party[pokemonindex].isbossmon && party[pokemonindex].bossID != :SHADOWDEN
        return _INTL("{1}", party[pokemonindex].name)
      else
        return _INTL("The wild {1}", party[pokemonindex].name)
      end
    else
      return _INTL("{1}", party[pokemonindex].name)
    end
  end

  # Checks whether an item can be removed from a Pokémon.
  def pbIsUnlosableItem(pkmn, item)
    # return true if pbIsMail?(item)
    return true if pbIsZCrystal?(item)
    return false if pkmn.effects[:Transform]

    if pkmn.species == :ARCEUS && pkmn.ability == :MULTITYPE
      if PBStuff::PLATEITEMS.include?(item)
        return true
      end
    end
    if pkmn.species == :SILVALLY && pkmn.ability == :RKSSYSTEM
      if [:FIGHTINGMEMORY,  :FLYINGMEMORY,    :POISONMEMORY,  :GROUNDMEMORY,  :ROCKMEMORY,
          :BUGMEMORY,       :GHOSTMEMORY,     :STEELMEMORY,   :FIREMEMORY,    :WATERMEMORY,
          :GRASSMEMORY,     :ELECTRICMEMORY,  :PSYCHICMEMORY, :ICEMEMORY,     :DRAGONMEMORY,
          :FAIRYMEMORY,     :DARKMEMORY, :GLITCHMEMORY].include?(item)
        return true
      end
    end
    return true if PBStuff::POKEMONTOMEGASTONE[pkmn.species].include?(item)
    return true if Rejuv && (PBStuff::POKEMONTOCREST[pkmn.species] == item || item == :BLKPRISM)
    return true if Rejuv && item == :ZOROCREST && pkmn.effects[:Illusion]
    return true if pkmn.species == :GENESECT && (item == :SHOCKDRIVE || item == :BURNDRIVE || item == :CHILLDRIVE || item == :DOUSEDRIVE)
    return true if pkmn.species == :GROUDON && item == :REDORB
    return true if pkmn.species == :KYOGRE && item == :BLUEORB
    return true if pkmn.species == :GIRATINA && item == :GRISEOUSORB

    return false
  end

  def pbCheckGlobalAbility(a)
    for i in 0...@battlers.length
      return @battlers[i] if @battlers[i].ability == a
    end
    return nil
  end

  # stupid code for a stupid ability
  def neutralizingGasDisable(index)
    gasactive = false
    for i in 0...4
      gasactive = true if @battlers[i].ability == :NEUTRALIZINGGAS && i != index
    end
    if !gasactive
      pbDisplay(_INTL("{1}'s neutralizing gas wore off!", @battlers[index].pbThis))
      for i in 0...4
        pkmn = @battlers[i]
        if !pkmn.effects[:GastroAcid] && pkmn.ability.nil? && i != index && !pkmn.backupability.nil?
          pkmn.ability = pkmn.backupability
          pkmn.pbAbilitiesOnSwitchIn(true)
        end
      end
    end
  end

  ################################################################################
  # Player-related info.
  ################################################################################
  def pbPlayer
    if @player.is_a?(Array)
      return @player[0]
    else
      return @player
    end
  end

  def pbGetOwnerItems(battlerIndex)
    if pbIsOpposing?(battlerIndex)
      return [] if !@items
      if @opponent.is_a?(Array)
        return (battlerIndex == 1) ? @items[0] : @items[1]
      else
        return @items
      end
    elsif @player.is_a?(Array) && battlerIndex == 2
      return [] if !@partneritems

      return @partneritems
    else
      return []
    end
  end

  def items=(items)
    @items = items.clone
  end

  def pbGetMegaRingName(battlerIndex)
    if pbBelongsToPlayer?(battlerIndex)
      rings = [:MEGARING, :MEGABRACELET, :MEGACUFF, :MEGACHARM]
      for i in rings
        return getItemName(i) if $PokemonBag.pbQuantity(i) > 0
      end
    end
    if (@battlers[battlerIndex].isbossmon || @battlers[battlerIndex].issossmon) && !@opponent
      return _INTL("bursting energy")
    end

    return _INTL("Mega Ring")
  end

  def pbHasMegaRing(battlerIndex)
    return true if !pbBelongsToPlayer?(battlerIndex)

    rings = [:MEGARING, :MEGABRACELET, :MEGACUFF, :MEGACHARM]
    for i in rings
      return true if $PokemonBag.pbQuantity(i) > 0
    end
    return false
  end

  def pbHasZRing(battlerIndex)
    return true if !pbBelongsToPlayer?(battlerIndex)

    rings = [:MEGARING, :MEGABRACELET, :MEGACUFF, :MEGACHARM]
    for i in rings
      return true if $PokemonBag.pbQuantity(i) > 0
    end
    return false
  end

  ################################################################################
  # Get party info, manipulate parties.
  ################################################################################
  def pbPokemonCount(party)
    count = 0
    for i in party
      next if !i

      count += 1 if (i.hp > 0 && !i.isEgg?) || (i.isbossmon && i.shieldCount > 0)
    end
    return count
  end

  def pbAllFainted?(party)
    pbPokemonCount(party) == 0
  end

  def pbMaxLevelFromIndex(index)
    party = pbParty(index)
    owner = pbIsOpposing?(index) ? @opponent : @player
    maxlevel = 0
    if owner.is_a?(Array)
      start = 0
      limit = pbSecondPartyBegin(index)
      start = limit if pbIsDoubleBattler?(index)
      for i in start...start + limit
        next if !party[i]

        maxlevel = party[i].level if maxlevel < party[i].level
      end
    else
      for i in party
        next if !i

        maxlevel = i.level if maxlevel < i.level
      end
    end
    return maxlevel
  end

  def pbMaxLevel(party)
    lv = 0
    for i in party
      next if !i

      lv = i.level if lv < i.level
    end
    return lv
  end

  def pbParty(index)
    return pbIsOpposing?(index) ? @party2 : @party1
  end

  def pbSecondPartyBegin(battlerIndex)
    if pbIsOpposing?(battlerIndex)
      return @fullparty2 ? 6 : 3
    else
      return @fullparty1 ? 6 : 3
    end
  end

  def pbFindNextUnfainted(party, start, finish = -1)
    finish = party.length if finish < 0
    for i in start...finish
      next if !party[i]
      return i if party[i].hp > 0 && !party[i].isEgg?
    end
    return -1
  end

  def pbFindPlayerBattler(pkmnIndex)
    battler = nil
    for k in 0...4
      if !pbIsOpposing?(k) && @battlers[k].pokemonIndex == pkmnIndex
        battler = @battlers[k]
        break
      end
    end
    return battler
  end

  def pbIsOwner?(battlerIndex, partyIndex)
    secondParty = pbSecondPartyBegin(battlerIndex)
    if !pbIsOpposing?(battlerIndex)
      return true if !@player || !@player.is_a?(Array)

      return battlerIndex == 0 ? partyIndex < secondParty : partyIndex >= secondParty
    else
      return true if !@opponent || !@opponent.is_a?(Array)

      return battlerIndex == 1 ? partyIndex < secondParty : partyIndex >= secondParty
    end
  end

  def pbGetOwner(battlerIndex)
    if pbIsOpposing?(battlerIndex)
      if @opponent.is_a?(Array)
        return battlerIndex == 1 ? @opponent[0] : @opponent[1]
      else
        return @opponent
      end
    else
      if @player.is_a?(Array)
        return battlerIndex == 0 ? @player[0] : @player[1]
      else
        return @player
      end
    end
  end

  def pbGetOwnerPartner(battlerIndex)
    if pbIsOpposing?(battlerIndex)
      if @opponent.is_a?(Array)
        return battlerIndex == 1 ? @opponent[1] : @opponent[0]
      else
        return @opponent
      end
    else
      if @player.is_a?(Array)
        return battlerIndex == 0 ? @player[1] : @player[0]
      else
        return @player
      end
    end
  end

  def pbPartySingleOwner(battlerIndex)
    party = pbParty(battlerIndex)
    ownerparty = []
    for i in 0...party.length
      ownerparty.push(party[i]) if pbIsOwner?(battlerIndex, i) && !party[i].nil?
    end
    return ownerparty
  end

  def pbPartySingleOwnerNonBattler(battler)
    party = pbPartySingleOwner(battler.index)
    party = party.find_all { |mon| !mon.nil? && battler.pokemon != mon }
    return party
  end

  def pbGetOwnerIndex(battlerIndex)
    if pbIsOpposing?(battlerIndex)
      return @opponent.is_a?(Array) ? (battlerIndex == 1 ? 0 : 1) : 0
    else
      return @player.is_a?(Array) ? (battlerIndex == 0 ? 0 : 1) : 0
    end
  end

  def pbBelongsToPlayer?(battlerIndex)
    if @player.is_a?(Array) && @player.length > 1
      return battlerIndex == 0
    end

    return battlerIndex % 2 == 0
  end

  def pbPartyGetOwner(battlerIndex, partyIndex)
    secondParty = pbSecondPartyBegin(battlerIndex)
    if !pbIsOpposing?(battlerIndex)
      return @player if !@player || !@player.is_a?(Array)

      return partyIndex < secondParty ? @player[0] : @player[1]
    else
      return @opponent if !@opponent || !@opponent.is_a?(Array)

      return partyIndex < secondParty ? @opponent[0] : @opponent[1]
    end
  end

  def pbAddToPlayerParty(pokemon)
    party = pbParty(0)
    for i in 0...party.length
      party[i] = pokemon if pbIsOwner?(0, i) && !party[i]
    end
  end

  def pbRemoveFromParty(battlerIndex, partyIndex)
    party = pbParty(battlerIndex)
    party[partyIndex] = nil
    # The code for doubles doesn't work correctly but it doesn't seem to be actually necessary to move the indexes.
    # side = pbIsOpposing?(battlerIndex) ? @opponent : @player
    # if !side || !side.is_a?(Array) # Wild or single opponent
    #   party.compact!
    #   battler = @battlers[battlerIndex].pbPartner
    #   battler.pokemonIndex -= 1 if battler && battler.pokemonIndex > partyIndex
    #   # for i in battlerIndex...party.length
    #   #   for j in 0..3
    #   #     next if !@battlers[j]
    #   #     if pbGetOwner(j) == side && @battlers[j].pokemonIndex == i
    #   #       @battlers[j].pokemonIndex -= 1
    #   #       break
    #   #     end
    #   #   end
    #   # end
    # else
    #   if battlerIndex < pbSecondPartyBegin(battlerIndex) - 1
    #     for i in battlerIndex...pbSecondPartyBegin(battlerIndex)
    #       if i >= pbSecondPartyBegin(battlerIndex) - 1
    #         party[i] = nil
    #       else
    #         party[i] = party[i + 1]
    #       end
    #     end
    #   else
    #     for i in battlerIndex...party.length
    #       if i >= party.length - 1
    #         party[i] = nil
    #       else
    #         party[i] = party[i + 1]
    #       end
    #     end
    #   end
    # end
  end

  def pbIsEnemy(battlerIndex)
    return (battlerIndex % 2) != 0
  end

  def pieceAssignment(party, trainer_array)
    return if party.length == 0

    pkmnparty = party.find_all { |mon| !mon.nil? && !mon.isEgg? }
    pkmnparty.each { |pkmn| pkmn.piece = nil }
    # Queen
    pkmnparty.last.piece = :QUEEN
    # Pawn
    sendoutorder = pkmnparty.find_all { |mon| mon.hp > 0 }
    sendoutorder[0].piece = :PAWN if sendoutorder[0].piece.nil?
    sendoutorder[1].piece = :PAWN if sendoutorder[1] && @doublebattle && !trainer_array && sendoutorder[1].piece.nil?
    # King
    king_piece = pkmnparty.sort_by { |mon| [mon.piece.nil? ? 0 : 1, mon.item == :KINGSROCK ? 0 : 1, mon.totalhp] }.first
    king_piece.piece = :KING if king_piece && king_piece.piece.nil?
    # Knight / Bishop / Rook
    pkmnparty.each do |pkmn|
      next if pkmn.piece != nil

      pkmn.piece = :KNIGHT if [pkmn.speed, pkmn.attack, pkmn.spatk, pkmn.defense, pkmn.spdef].max == pkmn.speed
      pkmn.piece = :BISHOP if [pkmn.speed, pkmn.attack, pkmn.spatk, pkmn.defense, pkmn.spdef].max == [pkmn.attack, pkmn.spatk].max
      pkmn.piece = :ROOK   if [pkmn.speed, pkmn.attack, pkmn.spatk, pkmn.defense, pkmn.spdef].max == [pkmn.defense, pkmn.spdef].max
    end
  end

  def pbAceMessage
    trainer = @opponent
    ace_text = trainer.aceline == "" ? nil : trainer.aceline
    if Desolation && $game_switches[:LastMon]
      Audio.bgm_play("Audio/BGM/" + $game_variables[:LastMonMusic], $Settings.volume, 100)
    end
    if Desolation && $game_switches[:LastMonButMore]
      Audio.bgm_play("Audio/BGM/Battle - Fenrir", $Settings.volume, 100)
    end
    if Rejuv && trainer.trainertype.to_s.include?("LEADER_")
      Audio.bgm_play("Audio/BGM/Battle - Gyms", $Settings.volume, 105)
    end
    return if ace_text == nil

    if ace_text.is_a?(String)
      ace_text = pbGetMessageFromHash(MessageTypes::AceSpeech, ace_text)
      @scene.pbShowOpponent(0) if trainer.trainertype != :HEATHER && trainer.trainertype != :ANNA
      pbDisplayAutoPaused(ace_text)
      @scene.pbHideOpponent if trainer.trainertype != :HEATHER && trainer.trainertype != :ANNA
    end
    @ace_message_handled = true
  end

  ################################################################################
  # Check whether actions can be taken.
  ################################################################################
  def pbCanShowCommands?(idxPokemon)
    thispkmn = @battlers[idxPokemon]
    return false if thispkmn.isFainted?
    return false if thispkmn.effects[:TwoTurnAttack] != 0
    return false if thispkmn.effects[:HyperBeam] > 0
    return false if thispkmn.effects[:Rollout] > 0
    return false if thispkmn.effects[:Outrage] > 0
    return false if thispkmn.effects[:Rage] && @field.effect == :GLITCH
    return false if thispkmn.effects[:Uproar] > 0
    return false if thispkmn.effects[:Bide] > 0

    return thispkmn.chargeTurns? == true ? false : true
  end

  def zMove
    return @zMove
  end

  ################################################################################
  # Attacking.
  ################################################################################
  def pbCanShowFightMenu?(idxPokemon)
    if !pbCanShowCommands?(idxPokemon)
      return false
    end
    # No moves that can be chosen
    if !pbCanChooseMove?(idxPokemon, 0, false) &&
       !pbCanChooseMove?(idxPokemon, 1, false) &&
       !pbCanChooseMove?(idxPokemon, 2, false) &&
       !pbCanChooseMove?(idxPokemon, 3, false)
      return false
    end

    return true
  end

  def pbCanChooseMove?(idxPokemon, idxMove, showMessages, flags = { sleeptalk: false, instructed: false })
    sleeptalk = flags.fetch(:sleeptalk, false)
    instructed = flags.fetch(:instructed, false)
    thispkmn = @battlers[idxPokemon]
    side = pbIsOpposing?(idxPokemon) ? 1 : 0
    owner = pbGetOwnerIndex(idxPokemon)
    zpower = @zMove[side][owner] == idxPokemon
    basemove = zpower ? thispkmn.zmoves[idxMove] : thispkmn.moves[idxMove]
    opp1 = thispkmn.pbOpposing1
    opp2 = thispkmn.pbOpposing2
    return false if !basemove

    if (!zpower && basemove.pp <= 0 && basemove.totalpp > 0 && !sleeptalk) || (zpower && thispkmn.moves[idxMove].pp <= 0 && thispkmn.moves[idxMove].totalpp > 0 && !sleeptalk)
      if showMessages
        pbDisplayPaused(_INTL("There's no PP left for this move!"))
      end
      return false
    end
    if thispkmn.effects[:ChoiceBand] != nil && thispkmn.itemWorks? && [:CHOICEBAND, :CHOICESPECS, :CHOICESCARF].include?(thispkmn.item)
      if thispkmn.moves.any? { |moveloop| moveloop.move == thispkmn.effects[:ChoiceBand] }
        if basemove.move != thispkmn.effects[:ChoiceBand] && sleeptalk == false
          if showMessages
            pbDisplayPaused(_INTL("{1} allows the use of only {2}!", getItemName(thispkmn.item), getMoveName(thispkmn.effects[:ChoiceBand])))
          end
          return false
        end
      else
        thispkmn.effects[:ChoiceBand] = nil
      end
    end
    if thispkmn.effects[:GorillaLock] != nil && thispkmn.ability == :GORILLATACTICS
      if thispkmn.moves.any? { |moveloop| moveloop.move == thispkmn.effects[:GorillaLock] }
        if basemove.move != thispkmn.effects[:GorillaLock] && sleeptalk == false
          if showMessages
            pbDisplayPaused(_INTL("Gorilla Tactics allows the use of only {2}!", getMoveName(thispkmn.effects[:GorillaLock])))
          end
          return false
        end
      else
        thispkmn.effects[:GorillaLock] = nil
      end
    end
    if thispkmn.hasWorkingItem(:ASSAULTVEST) && !instructed && basemove.betterCategory(thispkmn, basemove.type) == :status && basemove.move != :MEFIRST
      if showMessages
        pbDisplayPaused(_INTL("{1} doesn't allow use of non-attacking moves!", getItemName(thispkmn.item)))
      end
      return false
    end
    if opp1.effects[:Imprison] && !basemove.zmove
      if basemove.move == opp1.moves[0]&.move || basemove.move == opp1.moves[1]&.move || basemove.move == opp1.moves[2]&.move || basemove.move == opp1.moves[3]&.move
        if showMessages
          pbDisplayPaused(_INTL("{1} can't use the sealed {2}!", thispkmn.pbThis, basemove.name))
        end
        return false
      end
    end
    if opp2.effects[:Imprison] && !basemove.zmove
      if basemove.move == opp2.moves[0]&.move || basemove.move == opp2.moves[1]&.move || basemove.move == opp2.moves[2]&.move || basemove.move == opp2.moves[3]&.move
        if showMessages
          pbDisplayPaused(_INTL("{1} can't use the sealed {2}!", thispkmn.pbThis, basemove.name))
        end
        return false
      end
    end
    if thispkmn.effects[:Taunt] > 0 && basemove.betterCategory(thispkmn, basemove.type) == :status && !basemove.zmove
      if showMessages
        pbDisplayPaused(_INTL("{1} can't use {2} after the Taunt!", thispkmn.pbThis, basemove.name))
      end
      return false
    end
    if thispkmn.effects[:Torment] && !instructed && !basemove.zmove
      if basemove.move == thispkmn.lastRegularMoveUsed
        if showMessages
          pbDisplayPaused(_INTL("{1} can't use the same move in a row due to the torment!", thispkmn.pbThis))
        end
        return false
      end
    end
    if basemove.hasFlag?(:heavymove) && !instructed && !basemove.zmove
      if basemove.move == thispkmn.lastRegularMoveUsed
        if showMessages
          pbDisplayPaused(_INTL("{1} can't use {2} twice in a row!", thispkmn.pbThis, basemove.name))
        end
        return false
      end
    end
    if thispkmn.effects[:Disable] > 0 && basemove.move == thispkmn.effects[:DisableMove] && !sleeptalk && !basemove.zmove
      if showMessages
        pbDisplayPaused(_INTL("{1}'s {2} is disabled!", thispkmn.pbThis, basemove.name))
      end
      return false
    end
    if PBStuff::HEALFUNCTIONS.include?(basemove.function) && !basemove.zmove && thispkmn.effects[:HealBlock] > 0
      if showMessages
        pbDisplayPaused(_INTL("{1} can't use {2} after the Heal Block!", thispkmn.pbThis, basemove.name))
      end
      return false
    end
    if basemove.isSoundBased? && thispkmn.effects[:ThroatChop] > 0 && !basemove.zmove
      if showMessages
        pbDisplayPaused(_INTL("{1} can't use {2} because of it's throat damage!", thispkmn.pbThis, basemove.name))
      end
      return false
    end
    if thispkmn.effects[:Encore] > 0 && idxMove != thispkmn.effects[:EncoreIndex] && !basemove.zmove
      if showMessages
        pbDisplayPaused(_INTL("{1} can only use {2}!", thispkmn.pbThis, getMoveName(thispkmn.effects[:EncoreMove])))
      end
      return false
    end

    return true
  end

  def pbAutoChooseMove(idxPokemon, showMessages = true)
    thispkmn = @battlers[idxPokemon]
    if thispkmn.isFainted?
      @choices[idxPokemon] = [nil]
      return true
    end
    if thispkmn.effects[:Encore] > 0 && pbCanChooseMove?(idxPokemon, thispkmn.effects[:EncoreIndex], false)
      PBDebug.log("[Auto choosing Encore move...]") if $INTERNAL
      # move choice array: [:move, idxmove, obj, idxtarget]
      @choices[idxPokemon] = [:move, thispkmn.effects[:EncoreIndex], thispkmn.moves[thispkmn.effects[:EncoreIndex]], -1] # No target chosen yet
      if thispkmn.effects[:EncoreMove] == :ACUPRESSURE
        @choices[idxPokemon][3] = idxPokemon
      elsif @doublebattle
        basemove = thispkmn.moves[thispkmn.effects[:EncoreIndex]]
        if thispkmn.pbTarget(basemove) == :SingleNonUser
          @scene.pbFightMenuEncore(idxPokemon, thispkmn.effects[:EncoreIndex])
          target = @scene.pbChooseTarget(idxPokemon)
          pbRegisterTarget(idxPokemon, target) if target >= 0
          return false if target < 0
        elsif thispkmn.pbTarget(basemove) == :SingleOpposing
          @scene.pbFightMenuEncore(idxPokemon, thispkmn.effects[:EncoreIndex])
          target = @scene.pbChooseTargetOneSide(idxPokemon, thispkmn.pbTarget(basemove))
          pbRegisterTarget(idxPokemon, target) if target >= 0 && (target & 1) != (idxPokemon & 1)
          return false if target < 0
        elsif thispkmn.pbTarget(basemove) == :UserOrPartner
          @scene.pbFightMenuEncore(idxPokemon, thispkmn.effects[:EncoreIndex])
          target = @scene.pbChooseTarget(idxPokemon)
          pbRegisterTarget(idxPokemon, target) if target >= 0 && (target & 1) == (idxPokemon & 1)
          return false if target < 0
        else
          target = thispkmn.pbTarget(basemove)
          pbRegisterTarget(idxPokemon, target)
        end
      end
      return true
    else
      if !pbIsOpposing?(idxPokemon)
        pbDisplay(_INTL("{1} has no moves left!", thispkmn.name)) if showMessages
      end
      @choices[idxPokemon] = [:move, -1, @struggle, -1]
      return true
    end
  end

  def pbRegisterMove(idxPokemon, idxMove, showMessages = true)
    return false if idxMove.nil?
    thispkmn = @battlers[idxPokemon]
    side = pbIsOpposing?(idxPokemon) ? 1 : 0
    owner = pbGetOwnerIndex(idxPokemon)
    basemove = @zMove[side][owner] == idxPokemon ? thispkmn.zmoves[idxMove] : thispkmn.moves[idxMove]
    thispkmn.selectedMove = basemove.move
    return false if !pbCanChooseMove?(idxPokemon, idxMove, showMessages)

    @choices[idxPokemon] = [:move, idxMove, basemove, -1]
    return true
  end

  def pbChoseMoveFunctionCode?(i, code)
    return false if @battlers[i].isFainted?

    if @choices[i][0] == :move && @choices[i][1] >= 0
      choice = @choices[i][1]
      return @battlers[i].zmoves[choice].function == code if @choices[i][2].zmove

      return @battlers[i].moves[choice].function == code
    end
    return false
  end

  def pbRegisterTarget(idxPokemon, idxTarget)
    @choices[idxPokemon][3] = idxTarget # Set target of move
    return true
  end

  # Needs to be overridable for online battles.
  def pbTieBreak
    return 1
  end

  def pbPriority(ignorequickclaw = true, megacalc = false)
    return @priority if @usepriority && !megacalc # use stored priority if round isn't over yet (best ged rid of this in gen 8)

    @priority.clear
    priorityarray = []
    quickclawarray = [0, 0, 0, 0]
    # -Move priority take precedence(stored as priorityarray[i][0])
    # -Then Items  (stored as priorityarray[i][1])
    # -Then speed (stored as priorityarray[i][2]) (trick room is applied by just making speed negative.)
    # -The last element is just the battler index (which is otherwise lost when sorting)
    for i in 0..3
      priorityarray[i] = [0, 0, 0, i] # initializes the array and stores the battler index

      # Move priority
      pri = 0
      if @choices[i][0] == :switch || @battle.switchedOut[i] # If switching or has switched
        pri = 12
      end
      if @choices[i][0] == :item # Used item
        pri = 11
      end
      if @choices[i][0] == :move # Is a move
        pri = @choices[i][2].priority # Base move priority
        pri -= 1 if @battle.FE == :DEEPEARTH && @choices[i][2].move == :COREENFORCER
        pri += 1 if @field.effect == :CHESS && @battlers[i].pokemon && @battlers[i].pokemon.piece == :KING
        pri += 1 if @battlers[i].ability == :PRANKSTER && @choices[i][2].basedamage == 0 && @battlers[i].effects[:TwoTurnAttack] == 0 # Is status move
        pri += 1 if @battlers[i].ability == :GALEWINGS && @choices[i][2].type == :FLYING && (@battlers[i].hp == @battlers[i].totalhp || ((@field.effect == :MOUNTAIN || @field.effect == :SNOWYMOUNTAIN) && pbWeather == :STRONGWINDS))
        pri += 1 if @choices[i][2].move == :GRASSYGLIDE && (@field.effect == :GRASSY || @battle.state.effects[:GRASSY] > 0)
        pri += 1 if @choices[i][2].move == :QUASH && @field.effect == :DIMENSIONAL
        pri += 1 if @choices[i][2].basedamage != 0 && @battlers[i].crested == :FERALIGATR && @battlers[i].turncount == 1 # Feraligatr Crest
        pri += 3 if @battlers[i].ability == :TRIAGE && PBStuff::HEALFUNCTIONS.include?(@choices[i][2].function)
      end
      priorityarray[i][0] = pri

      # Item/stall priority (all items overwrite stall priority)
      priorityarray[i][1] = -1 if @battlers[i].ability == :STALL
      if !ignorequickclaw && @choices[i][0] == :move # Is a move
        if @battlers[i].ability == :QUICKDRAW && pbRandom(100) < 30
          priorityarray[i][1] = 1
          quickclawarray[i] = :QUICKDRAW
        elsif @battlers[i].itemWorks? && @battlers[i].item == :QUICKCLAW && pbRandom(100) < 20
          priorityarray[i][1] = 1
          quickclawarray[i] = :QUICKCLAW
        elsif @battlers[i].custap
          priorityarray[i][1] = 1
          quickclawarray[i] = :CUSTAPBERRY
        end
      end
      priorityarray[i][1] = -2 if (@battlers[i].itemWorks? && (@battlers[i].item == :LAGGINGTAIL || @battlers[i].item == :FULLINCENSE))

      # speed priority
      priorityarray[i][2] = @battlers[i].pbSpeed if @trickroom == 0
      priorityarray[i][2] = -@battlers[i].pbSpeed if @trickroom > 0

    end
    priorityarray.sort!

    # Speed ties. Only works correctly if two pokemon speed tie
    for i in 0..2
      for j in (i + 1)..3
        if priorityarray[i][0] == priorityarray[j][0] && priorityarray[i][1] == priorityarray[j][1] && priorityarray[i][2] == priorityarray[j][2]
          if pbRandom(2) == pbTieBreak
            priorityarray[i], priorityarray[j] = priorityarray[j], priorityarray[i]
          end
        end
      end
    end
    priorityarray.reverse!

    # Quick claw battle message
    for i in 0..3
      battler = @battlers[priorityarray[i][3]]
      @priority[i] = battler
      if battler.ability == :QUICKDRAW && quickclawarray[priorityarray[i][3]] == :QUICKDRAW
        if priorityarray[i][1] == 1 && !ignorequickclaw
          battler.effects[:QuickDrawSnipe] if @battle.FE == :COLOSSEUM
          pbDisplayBrief(_INTL("{1}'s Quick Draw let it move first!", battler.pbThis))
        end
      elsif battler.itemWorks? && battler.item == :QUICKCLAW && quickclawarray[priorityarray[i][3]] == :QUICKCLAW
        pbDisplayBrief(_INTL("{1}'s Quick Claw let it move first!", battler.pbThis)) if priorityarray[i][1] == 1 && !ignorequickclaw
      end
    end

    @usepriority = true
    return @priority
  end

  # Makes target pokemon move last
  def pbMoveLast(target)
    priorityTarget = pbGetPriority(target)
    priority = @priority
    case priorityTarget
      when 0
        # Opponent has likely already moved
        return false
      when 1
        priority[1], priority[2], priority[3] = priority[2], priority[3], target
        @priority = priority
        return true
      when 2
        priority[2], priority[3] = priority[3], priority[2]
        @priority = priority
        return true
      when 3
        return false
    end
  end

  # Makes the second pokemon move after the first.
  def pbMoveAfter(first, second)
    priorityFirst = pbGetPriority(first)
    priority = @priority
    case priorityFirst
      when 0
        if second == priority[1]
          # Nothing to do here
          return false
        elsif second == priority[2]
          priority[1], priority[2] = second, priority[1]
          @priority = priority
          return true
        elsif second == priority[3]
          priority[1], priority[2], priority[3] = second, priority[1], priority[2]
          @priority = priority
          return true
        end
      when 1
        if second == priority[0] || second == priority[2]
          # Nothing to do here
          return false
        elsif second == priority[3]
          priority[2], priority[3] = priority[3], priority[2]
          @priority = priority
          return true
        end
      when 2
        return false
      when 3
        return false
    end
  end

  def pbGetPriority(mon)
    for i in 0..3
      if @priority[i] == mon
        return i
      end
    end
    return -1
  end

  def pbClearChoices(index)
    @choices[index] = [nil]
  end

  ################################################################################
  # Switching Pokémon.
  ################################################################################
  def pbCanSwitchLax?(idxPokemon, pkmnidxTo, showMessages)
    if pkmnidxTo >= 0
      party = pbParty(idxPokemon)
      if pkmnidxTo >= party.length
        return false
      end
      if !party[pkmnidxTo]
        return false
      end
      if party[pkmnidxTo].nil?
        return false
      end

      if party[pkmnidxTo].isEgg?
        pbDisplayPaused(_INTL("An Egg can't battle!")) if showMessages
        return false
      end
      if Rejuv
        if party[pkmnidxTo].sosmon
          return false
        end
      end
      if !pbIsOwner?(idxPokemon, pkmnidxTo)
        owner = pbPartyGetOwner(idxPokemon, pkmnidxTo)
        pbDisplayPaused(_INTL("You can't switch {1}'s Pokémon with one of yours!", owner.name)) if showMessages
        return false
      end
      if party[pkmnidxTo].hp <= 0
        pbDisplayPaused(_INTL("{1} has no energy left to battle!", party[pkmnidxTo].name)) if showMessages
        return false
      end
      if !@opponent && pbIsOpposing?(idxPokemon) # Wild Battle
        return false
      end

      if @battlers[idxPokemon].pokemonIndex == pkmnidxTo
        pbDisplayPaused(_INTL("{1} is already in battle!", party[pkmnidxTo].name)) if showMessages
        return false
      end
      if @battlers[idxPokemon].pbPartner.pokemonIndex == pkmnidxTo
        pbDisplayPaused(_INTL("{1} is already in battle!", party[pkmnidxTo].name)) if showMessages
        return false
      end
    end
    return true
  end

  def pbCanSwitch?(idxPokemon, pkmnidxTo, showMessages, ai_phase = false, running: false)
    thispkmn = @battlers[idxPokemon]
    # Multi-Turn Attacks/Mean Look
    if !pbCanSwitchLax?(idxPokemon, pkmnidxTo, showMessages)
      return false
    end

    isOpposing = pbIsOpposing?(idxPokemon)
    party = pbParty(idxPokemon)
    for i in 0...4
      next if isOpposing != pbIsOpposing?(i)

      if @choices[i][0] == :switch && @choices[i][1] == pkmnidxTo && !ai_phase
        pbDisplayPaused(_INTL("{1} has already been selected.", party[pkmnidxTo].name)) if showMessages
        return false
      end
    end
    if @field.effect == :COLOSSEUM
      pbDisplayPaused(_INTL("{1} can't be switched out while on Colosseum Field!", thispkmn.pbThis)) if showMessages
      return false
    end
    if thispkmn.effects[:SkyDrop] # lía
      pbDisplayPaused(_INTL("{1} can't be switched out!", thispkmn.pbThis)) if showMessages
      return false
    end
    if thispkmn.hasType?(:GHOST) && (@field.effect != :DIMENSIONAL || !(thispkmn.pbOpposing1.ability == :SHADOWTAG || thispkmn.pbOpposing2.ability == :SHADOWTAG))
      return true
    end
    if thispkmn.hasWorkingItem(:SHEDSHELL)
      return true
    end

    if @field.effect == :INFERNAL && thispkmn.status == :SLEEP && (thispkmn.pbOpposing1.ability == :BADDREAMS || thispkmn.pbOpposing2.ability == :BADDREAMS)
      pbDisplayPaused(_INTL("{1}'s terrible dreams prevent it from being switched out!", thispkmn.pbThis)) if showMessages
      return false
    end
    if thispkmn.effects[:MultiTurn] > 0 || thispkmn.effects[:MeanLook] >= 0 || @state.effects[:FairyLock] == 1 || thispkmn.effects[:Octolock] >= 0
      pbDisplayPaused(_INTL("{1} can't be switched out!", thispkmn.pbThis)) if showMessages
      return false
    end
    # Ingrain
    if thispkmn.effects[:Ingrain]
      pbDisplayPaused(_INTL("{1} can't be switched out!", thispkmn.pbThis)) if showMessages
      return false
    end
    # Embargo
    if @field.effect == :DIMENSIONAL && thispkmn.effects[:Embargo] > 0
      pbDisplayPaused(_INTL("{1} can't be switched out due to Embargo!", thispkmn.pbThis)) if showMessages
      return false
    end
    opp1 = thispkmn.pbOpposing1
    opp2 = thispkmn.pbOpposing2
    opp = nil
    if thispkmn.hasType?(:STEEL)
      opp = opp1 if opp1.ability == :MAGNETPULL
      opp = opp2 if opp2.ability == :MAGNETPULL
    end
    if !thispkmn.isAirborne?
      opp = opp1 if opp1.ability == :ARENATRAP
      opp = opp2 if opp2.ability == :ARENATRAP
    end
    unless thispkmn.ability == :SHADOWTAG
      opp = opp1 if opp1.ability == :SHADOWTAG
      opp = opp2 if opp2.ability == :SHADOWTAG
    end
    if opp
      abilityname = getAbilityName(opp.ability)
      pbDisplayPaused(_INTL("{1}'s {2} prevents switching!", opp.pbThis, abilityname)) if showMessages
      pbDisplayPaused(_INTL("{1} prevents escaping with {2}!", opp.pbThis, abilityname)) if (showMessages || running) && pkmnidxTo == -1
      return false
    end
    return true
  end

  def pbRegisterSwitch(idxPokemon, idxOther)
    return false if !pbCanSwitch?(idxPokemon, idxOther, false)

    @choices[idxPokemon] = [:switch, idxOther]
    side = pbIsOpposing?(idxPokemon) ? 1 : 0
    owner = pbGetOwnerIndex(idxPokemon)
    if @megaEvolution[side][owner] == idxPokemon
      @megaEvolution[side][owner] = -1
    end
    if @ultraBurst[side][owner] == idxPokemon
      @ultraBurst[side][owner] = -1
    end
    if @zMove[side][owner] == idxPokemon
      @zMove[side][owner] = -1
    end
    return true
  end

  def pbCanChooseNonActive?(index)
    party = pbParty(index)
    for i in 0..party.length - 1
      return true if pbCanSwitchLax?(index, i, false)
    end
    return false
  end

  def pbJudgeSwitch(favorDraws = false)
    if !favorDraws
      return if @decision > 0

      pbJudge()
      return if @decision > 0
    else
      return if @decision == 5

      pbJudge()
      return if @decision > 0
    end
  end

  def pbSwitch(favorDraws = false, hazardFaint = false)
    if !favorDraws
      return if @decision > 0

      pbJudge()
      return if @decision > 0
    else
      return if @decision == 5

      pbJudge()
      return if @decision > 0
    end
    firstbattlerhp = @battlers[0].hp
    switched = []
    for index in 0...4
      next if (!@doublebattle && pbIsDoubleBattler?(index)) || (@battle.sosbattle == 3 && index == 2)
      next if @battlers[index] && !@battlers[index].isFainted?
      next if !pbCanChooseNonActive?(index)
      next if @decision > 0

      if !pbOwnedByPlayer?(index)
        if !pbIsOpposing?(index) || @opponent && pbIsOpposing?(index)
          newenemy = pbSwitchInBetween(index, true, false)
          newname = pbSwitchInName(index, newenemy) # Illusion
          opponent = pbGetOwner(index)
          if !@doublebattle && firstbattlerhp > 0 && @shiftStyle && @opponent && @internalbattle && pbCanChooseNonActive?(0) && pbIsOpposing?(index) && @battlers[0].effects[:Outrage] == 0 && !@controlPlayer
            pbDisplayPaused(_INTL("{1} is about to send in {2}.", opponent.fullname, newname))
            if pbDisplayConfirm(_INTL("Will {1} change Pokémon?", self.pbPlayer.name))
              newpoke = pbSwitchPlayer(0, true, true)
              if newpoke >= 0
                pbDisplayBrief(_INTL("{1}, that's enough!  Come back!", @battlers[0].name))
                pbRecallAndReplace(0, newpoke)
                switched.push(0)
              end
            end
          end
          pbRecallAndReplace(index, newenemy)
          switched.push(index)
        end
      elsif @opponent || @battlers.any? { |battler| battler.isbossmon }
        newpoke = pbSwitchInBetween(index, true, false)
        pbRecallAndReplace(index, newpoke)
        switched.push(index)
      else
        switch = true
        if !pbDisplayConfirm(_INTL("Use next Pokémon?"))
          switch = pbRun(index, true) <= 0
        end
        if switch
          newpoke = pbSwitchInBetween(index, true, false)
          pbRecallAndReplace(index, newpoke)
          switched.push(index)
        end
      end
      if newpoke != nil
        for j in 0..index
          if @battlers[j].ability == :TRACE && @battlers[j].turncount > 0
            @battlers[j].pbAbilitiesOnSwitchIn(true)
          end
        end
      end
    end
    if switched.length > 0
      priority = pbPriority
      for i in priority
        i.pbAbilitiesOnSwitchIn(true) if switched.include?(i.index)
      end
      seedCheck
    end
  end

  def pbSendOut(index, pokemon, slidein = false)
    # AI CHANGES
    @ai.addMonToMemory(pokemon, index)
    $Trainer.pokedex.setSeen(pokemon)
    @peer.pbOnEnteringBattle(self, pokemon)
    if pbIsOpposing?(index)
      #  in-battle text
      @scene.pbTrainerSendOut(index, pokemon)
      pbCrestEffects(index, pokemon) if @battlers[index].crested
      # Last Pokemon script; credits to venom12 and HelioAU
      if !@opponent.is_a?(Array) && pbPokemonCount(@party2) == 1 && !@ace_message_handled
        pbAceMessage()
      end
    else
      @scene.pbSendOut(index, pokemon, slidein)
      pbCrestEffects(index, pokemon) if @battlers[index].crested
    end
    @scene.pbResetMoveIndex(index)
  end

  def pbReplace(index, newpoke, batonpass = false)
    if @battlers[index].effects[:Illusion]
      @battlers[index].effects[:Illusion] = nil
    end
    if @battlers[index].unburdened
      @battlers[index].unburdened = false
      @battlers[index].speed /= 2
    end
    party = pbParty(index)
    if pbOwnedByPlayer?(index) || pbOwnedByAIPartner?(index)
      # Reorder the party for this battle
      bpo = -1
      bpn = -1
      for i in 0...@partyorder.length
        bpo = i if @partyorder[i] == @battlers[index].pokemonIndex
        bpn = i if @partyorder[i] == newpoke
      end
      if bpo != -1
        poke1 = @partyorder[bpo]
        @partyorder[bpo] = @partyorder[bpn]
        @partyorder[bpn] = poke1
      end
    else
      partyNameOverwrite(party, newpoke) if $game_switches[:NameOverwrite]
      $Trainer.pokedex.setSeen(party[newpoke])
    end
    @battlers[index].pbInitialize(party[newpoke], newpoke, batonpass)
    pbSendOut(index, party[newpoke])
  end

  def partyNameOverwrite(party, newpoke)
  end

  def pbRecallAndReplace(index, newpoke, batonpass = false)
    if @battlers[index].effects[:Illusion]
      @battlers[index].effects[:Illusion] = nil
    end
    if @battlers[index].unburdened
      @battlers[index].unburdened = false
      @battlers[index].speed /= 2
    end
    neutralizingGasDisable(index) if @battlers[index].ability == :NEUTRALIZINGGAS
    @battlers[index].vanished = false if @battlers[index].vanished
    @switchedOut[index] = true
    pbClearChoices(index)
    @battlers[index].pbResetForm
    if !@battlers[index].isFainted?
      @scene.pbRecall(index)
    end
    pbMessagesOnReplace(index, newpoke)
    pbReplace(index, newpoke, batonpass)
    @scene.partyBetweenKO2(!pbOwnedByPlayer?(index)) unless @doublebattle
    return pbOnActiveOne(@battlers[index])
  end

  def pbMessagesOnReplace(index, newpoke)
    newname = pbSwitchInName(index, newpoke)
    if pbOwnedByPlayer?(index)
      opposing = @battlers[index].pbOppositeOpposing
      if opposing.hp <= 0 || opposing.hp == opposing.totalhp
        pbDisplayBrief(_INTL("Go! {1}!", newname))
      elsif opposing.hp >= (opposing.totalhp / 2.0)
        pbDisplayBrief(_INTL("Do it! {1}!", newname))
      elsif opposing.hp >= (opposing.totalhp / 4.0)
        pbDisplayBrief(_INTL("Go for it, {1}!", newname))
      else
        pbDisplayBrief(_INTL("Your foe's weak!\nGet 'em, {1}!", newname))
      end
    else
      owner = pbGetOwner(index)
      pbDisplayBrief(_INTL("{1} sent\r\nout {2}!", owner.fullname, newname))
    end
  end

  def pbSwitchInBetween(index, lax, cancancel)
    if !pbOwnedByPlayer?(index) && !(pbOwnedByAIPartner?(index) && $game_switches[:Control_Partners])
      PBDebug.log("[AI made a switch]\n")
      return @scene.pbChooseNewEnemy(index, pbParty(index))
    else
      PBDebug.log("[Player made a switch]\n")
      return pbSwitchPlayer(index, lax, cancancel)
    end
  end

  def pbSwitchPlayer(index, lax, cancancel)
    if $testing || @controlPlayer
      return @scene.pbChooseNewEnemy(index, pbParty(index))
    else
      return @scene.pbSwitch(index, lax, cancancel)
    end
  end

  def pbSwitchInName(index, newpoke) # Illusion
    partynumber = pbParty(index)
    party = pbPartySingleOwner(index)
    if partynumber[newpoke].ability == :ILLUSION
      party2 = party.find_all { |item| item && !item.egg? && item.hp > 0 }
      if party2[-1] != partynumber[newpoke] # last mon isn't the same illusion mon
        illusionpoke = party2[-1]
      end
    end
    enemyname = getMonName(partynumber[newpoke].species, partynumber[newpoke].form)
    if pbIsOpposing?(index)
      newname = illusionpoke != nil ? getMonName(illusionpoke.species, illusionpoke.form) : enemyname
    else
      newname = illusionpoke != nil ? illusionpoke.name : partynumber[newpoke].name
    end
    return newname
  end

  ################################################################################
  # Using an item.
  ################################################################################
  # Uses an item on a Pokémon in the player's party.
  def pbUseItemOnPokemon(item, pkmnIndex, userPkmn, scene)
    pokemon = @party1[pkmnIndex]
    battler = nil
    name = pbGetOwner(userPkmn.index).fullname
    name = pbGetOwner(userPkmn.index).name if pbBelongsToPlayer?(userPkmn.index)
    pbDisplayBrief(_INTL("{1} used the\r\n{2}.", name, getItemName(item)))
    PBDebug.log("[Player used #{getItemName(item)}]")
    ret = false
    if pokemon.isEgg?
      pbDisplay(_INTL("But it had no effect!"))
    else
      for i in 0...4
        if !pbIsOpposing?(i) && @battlers[i].pokemonIndex == pkmnIndex
          battler = @battlers[i]
        end
      end
      ret = ItemHandlers.triggerBattleUseOnPokemon(item, pokemon, battler, scene)
      #### YUMIL - 7 - NPC REACTION MOD - START
      if @recorded
        $game_variables[:BattleDataArray].last().playerUsedAnItem
      end
      #### YUMIL - 7 - NPC REACTION MOD - END
    end
    if !ret && pbBelongsToPlayer?(userPkmn.index)
      if $PokemonBag.pbCanStore?(item)
        $PokemonBag.pbStoreItem(item)
      else
        raise _INTL("Couldn't return unused item to Bag somehow.")
      end
    end
    return ret
  end

  # Uses an item on an active Pokémon.
  def pbUseItemOnBattler(item, index, userPkmn, scene)
    PBDebug.log("[Player used #{getItemName(item)}]")
    ret = ItemHandlers.triggerBattleUseOnBattler(item, @battlers[index], scene)
    if !ret && pbBelongsToPlayer?(userPkmn.index)
      if $PokemonBag.pbCanStore?(item)
        $PokemonBag.pbStoreItem(item)
      else
        raise _INTL("Couldn't return unused item to Bag somehow.")
      end
      #### YUMIL - 8 - NPC REACTION MOD - START
      if @recorded
        $game_variables[:BattleDataArray].last().playerUsedAnItem
      end
      #### YUMIL - 8 -NPC REACTION MOD - END
    end
    return ret
  end

  def pbRegisterItem(idxPokemon, item, idxTarget = nil)
    if ItemHandlers.hasUseInBattle(item)
      if idxPokemon == 0 || @battlers[0].isFainted?
        if ItemHandlers.triggerBattleUseOnBattler(item, @battlers[idxPokemon], self)
          ItemHandlers.triggerUseInBattle(item, @battlers[idxPokemon], self)
          if @doublebattle && idxPokemon == 0 && !@battlers[2].isFainted?
            @choices[2] = [:skip]
          end
        else
          return false
        end
      else
        if ItemHandlers.triggerBattleUseOnBattler(item, @battlers[idxPokemon], self)
          pbDisplayPaused(_INTL("It's impossible to aim without being focused!"))
        end
        return false
      end
    end
    @choices[idxPokemon] = [:item, item, idxTarget]
    side = pbIsOpposing?(idxPokemon) ? 1 : 0
    owner = pbGetOwnerIndex(idxPokemon)
    if @megaEvolution[side][owner] == idxPokemon
      @megaEvolution[side][owner] = -1
    end
    if @ultraBurst[side][owner] == idxPokemon
      @ultraBurst[side][owner] = -1
    end
    if @zMove[side][owner] == idxPokemon
      @zMove[side][owner] = -1
    end
    return true
  end

  def pbEnemyUseItem(item, battler)
    return 0 if !@internalbattle
    return 0 if pbIsPokeBall?(item) # the AI has no balls

    items = pbGetOwnerItems(battler.index)
    return if !items

    opponent = pbGetOwner(battler.index)
    for i in 0...items.length
      if items[i] == item
        items.delete_at(i)
        break
      end
    end
    #### YUMIL - 9 - NPC REACTION MOD - START
    if @recorded
      $game_variables[:BattleDataArray].last().opponentUsedAnItem
    end
    #### YUMIL - 9 - NPC REACTION MOD - END
    itemname = getItemName(item)
    if opponent && opponent.fullname
      if opponent.fullname.length < 30 # bennett and laura potion usage line break (their length = 35)
        pbDisplayBrief(_INTL("{1} used the\r\n{2}!", opponent.fullname, itemname))
      else
        pbDisplayBrief(_INTL("{1} used the\r{2}!", opponent.fullname, itemname))
      end
    end
    case item
      when :ORANBERRY
        battler.pbRecoverHP(10, true)
        pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
      when :SITRUSBERRY
        battler.pbRecoverHP((battler.totalhp / 4.0).floor, true)
        pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
      when :POTION, :SWEETHEART, :BERRYJUICE
        battler.pbRecoverHP(20, true)
        pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
      when :SUPERPOTION, :ENERGYPOWDER
        battler.pbRecoverHP(60, true)
        pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
      when :HYPERPOTION, :ENERGYROOT
        battler.pbRecoverHP(120, true)
        pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
      when :ULTRAPOTION, :BLUEMIC
        battler.pbRecoverHP(200, true)
        pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
      when :MOOMOOMILK, :MAGICMILK
        battler.pbRecoverHP(100, true)
        pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
      when :STRAWBIC
        battler.pbRecoverHP(90, true)
        pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
      when :CHOCOLATEIC, :LEMONADE
        battler.pbRecoverHP(70, true)
        pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
      when :FRESHWATER, :VANILLAIC
        battler.pbRecoverHP(30, true)
        pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
      when :SODAPOP
        battler.pbRecoverHP(50, true)
        pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
      when :CHINESEFOOD
        battler.pbRecoverHP(300, true)
        pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
      when :BUBBLETEA
        battler.pbRecoverHP(180, true)
        pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
      when :STRAWCAKE
        battler.pbRecoverHP(150, true)
        pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
      when :MAXPOTION
        battler.pbRecoverHP(battler.totalhp, true)
        pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
      when :FULLRESTORE
        fullhp = (battler.hp == battler.totalhp)
        battler.pbRecoverHP(battler.totalhp, true)
        battler.status = nil
        battler.statusCount = 0
        battler.effects[:Confusion] = 0
        if fullhp
          pbDisplay(_INTL("{1} became healthy!", battler.pbThis))
        else
          pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
        end
      when :FULLHEAL, :LAVACOOKIE, :OLDGATEAU, :CASTELIACONE, :BIGMALASADA, :LUMBERRY, :MEDICINE, :RAZZTART, :HEALPOWDER
        battler.status = nil
        battler.statusCount = 0
        battler.effects[:Confusion] = 0
        pbDisplay(_INTL("{1} became healthy!", battler.pbThis))
      when :XATTACK
        battler.pbIncreaseStat(PBStats::ATTACK, 2)
      when :XDEFEND
        battler.pbIncreaseStat(PBStats::DEFENSE, 2)
      when :XSPEED
        battler.pbIncreaseStat(PBStats::SPEED, 2)
      when :XSPECIAL
        battler.pbIncreaseStat(PBStats::SPATK, 2)
      when :XSPDEF
        battler.pbIncreaseStat(PBStats::SPDEF, 2)
      when :XACCURACY
        battler.pbIncreaseStat(PBStats::ACCURACY, 2)
    end
  end

  ################################################################################
  # Fleeing from battle.
  ################################################################################
  def pbCanRun?(idxPokemon)
    return false if @opponent

    if @battlers.any? { |battler| battler.isbossmon }
      return true if @battlers.any? { |battler| battler.canrun }
    end
    return false if @battlers.any? { |battler| battler.isbossmon && !@cantescape }

    thispkmn = @battlers[idxPokemon]
    return true if thispkmn.hasWorkingItem(:SMOKEBALL)
    return true if thispkmn.hasWorkingItem(:MAGNETICLURE)
    return true if thispkmn.hasWorkingItem(:MIRRORLURE)
    return true if thispkmn.ability == :RUNAWAY

    return pbCanSwitch?(idxPokemon, -1, false)
  end

  def pbRun(idxPokemon, duringBattle = false)
    thispkmn = @battlers[idxPokemon]
    if pbIsOpposing?(idxPokemon)
      return 0 if @opponent

      @choices[i] = [:run]
      return -1
    end
    if @opponent
      if ($DEBUG && Input.press?(Input::CTRL)) || $game_switches[:No_Battles_Pass]
        if pbDisplayConfirm(_INTL("Treat this battle as a win?"))
          @decision = 1
          return 1
        elsif pbDisplayConfirm(_INTL("Treat this battle as a loss?"))
          @decision = 2
          return 1
        end
      elsif @internalbattle
        if pbDisplayConfirm(_INTL("Would you like to forfeit the battle?"))
          pbDisplay(_INTL("{1} forfeited the match!", self.pbPlayer.name))
          @decision = 2
          return 1
        end
      elsif pbDisplayConfirm(_INTL("Would you like to forfeit the match and quit now?"))
        pbDisplay(_INTL("{1} forfeited the match!", self.pbPlayer.name))
        @decision = 3
        return 1
      end
      return 0
    end
    if $DEBUG && Input.press?(Input::CTRL)
      pbSEPlay("escape", 100)
      pbDisplayPaused(_INTL("Got away safely!"))
      @decision = 3
      return 1
    end
    if @cantescape || $game_switches[:Never_Escape]
      pbDisplayPaused(_INTL("Can't escape!"))
      return 0
    end
    if thispkmn.hasType?(:GHOST)
      pbSEPlay("escape", 100)
      pbDisplayPaused(_INTL("Got away safely!"))
      @decision = 3
      return 1
    end
    if thispkmn.hasWorkingItem(:SMOKEBALL) || thispkmn.hasWorkingItem(:MAGNETICLURE) || thispkmn.hasWorkingItem(:MIRRORLURE)
      if duringBattle
        pbSEPlay("escape", 100)
        pbDisplayPaused(_INTL("Got away safely!"))
      else
        pbSEPlay("escape", 100)
        pbDisplayPaused(_INTL("{1} fled using its {2}!", thispkmn.pbThis, getItemName(thispkmn.item)))
      end
      @decision = 3
      return 1
    end
    if thispkmn.ability == :RUNAWAY
      if duringBattle
        pbSEPlay("escape", 100)
        pbDisplayPaused(_INTL("Got away safely!"))
      else
        pbSEPlay("escape", 100)
        pbDisplayPaused(_INTL("{1} fled using Run Away!", thispkmn.pbThis))
      end
      @decision = 3
      return 1
    end
    if !duringBattle && !pbCanSwitch?(idxPokemon, -1, false, running: true) # TODO: Use real messages
      pbDisplayPaused(_INTL("Can't escape!"))
      return 0
    end
    # Note: not pbSpeed, because using unmodified Speed
    speedPlayer = @battlers[idxPokemon].speed
    opposing = @battlers[idxPokemon].pbOppositeOpposing
    if opposing.isFainted?
      opposing = opposing.pbPartner
    end
    if !opposing.isFainted?
      speedEnemy = opposing.speed
      if speedPlayer > speedEnemy
        rate = 256
      else
        speedEnemy = 1 if speedEnemy <= 0
        rate = speedPlayer * 128 / speedEnemy
        rate += @runCommand * 30
        rate &= 0xFF
      end
    else
      rate = 256
    end
    ret = 1
    if pbRandom(256) < rate
      pbSEPlay("escape", 100)
      pbDisplayPaused(_INTL("Got away safely!"))
      @decision = 3
    else
      pbDisplayPaused(_INTL("Can't escape!"))
      ret = -1
    end
    if !duringBattle
      @runCommand += 1
    end
    return ret
  end

  ################################################################################
  # Mega Evolve battler.
  ################################################################################
  def pbCanMegaEvolve?(index)
    return false if $game_switches[:No_Mega_Evolution] == true
    return false if !@battlers[index].hasMega?
    return false if !pbHasMegaRing(index)

    side = pbIsOpposing?(index) ? 1 : 0
    owner = pbGetOwnerIndex(index)
    return true if @megaEvolution[side][owner] == -1
    return false if @megaEvolution[side][owner] != index

    return true
  end

  def pbCanMegaEvolveAI?(i, index)
    return false if $game_switches[:No_Mega_Evolution] == true

    if i.class == PokeBattle_Battler
      return false if !i.pokemon.hasMegaForm?
    else
      return false if !i.hasMegaForm?
    end
    return false if !pbHasMegaRing(index)

    side = 1
    owner = pbGetOwnerIndex(index)
    return false if @megaEvolution[side][owner] != -1

    return true
  end

  def pbRegisterMegaEvolution(index)
    side = pbIsOpposing?(index) ? 1 : 0
    owner = pbGetOwnerIndex(index)
    @megaEvolution[side][owner] = index
  end

  def pbUnRegisterMegaEvolution(index)
    side = pbIsOpposing?(index) ? 1 : 0
    owner = pbGetOwnerIndex(index)
    @megaEvolution[side][owner] = -1
  end

  def pbMegaEvolve(index)
    # Things that disallow mega-evolution
    return if !@battlers[index] || !@battlers[index].pokemon
    return if !(@battlers[index].hasMega? rescue false)
    return if (@battlers[index].isMega? rescue true)
    return if !pbGetOwner(index)

    # Battle message start
    if @battlers[index].issossmon
      ownername = @battlers[index].pbPartner.isbossmon ? @battlers[index].pbPartner.name : @battlers[index].name
    elsif @battlers[index].isbossmon
      ownername = @battlers[index].name
    elsif pbBelongsToPlayer?(index)
      ownername = pbGetOwner(index).name
    else
      ownername = pbGetOwner(index).fullname
    end
    if @battlers[index].species == :RAYQUAZA
      pbDisplay(_INTL("{1}'s fervent wish has reached {2}!", ownername, @battlers[index].pbThis))
    else
      pbDisplay(_INTL("{1}'s {2} is reacting to {3}'s {4}!", @battlers[index].pbThis, getItemName(@battlers[index].item), ownername, pbGetMegaRingName(index)))
    end

    # Animation
    if @battlers[index].species == :RAYQUAZA
      pbCommonAnimation("MegaEvolutionRayquaza", @battlers[index], nil)
    else
      pbCommonAnimation("MegaEvolution", @battlers[index], nil)
    end

    # Update battler
    @battlers[index].pokemon.makeMega
    @battlers[index].form = @battlers[index].pokemon.form
    @battlers[index].pbUpdate(true)
    @scene.pbChangePokemon(@battlers[index], @battlers[index].pokemon) if @battlers[index].effects[:Substitute] == 0

    # Battle message finish
    formname = $cache.pkmn[@battlers[index].pokemon.species].forms[@battlers[index].form]
    if formname.include?("Form")
      formname = formname.split("Form")[0].strip
    end
    meganame = formname + " " + getMonName(@battlers[index].pokemon.species, @battlers[index].pokemon.form)
    if @battlers[index].item == :DEMONSTONE
      pbDisplay(_INTL("{1} mutated into {2}!", @battlers[index].pbThis, meganame))
    else
      pbDisplay(_INTL("{1} Mega Evolved into {2}!", @battlers[index].pbThis, meganame))
    end

    # Remember trainer has mega-evolved
    side = pbIsOpposing?(index) ? 1 : 0
    owner = pbGetOwnerIndex(index)
    @megaEvolution[side][owner] = -2

    # Re-update ability of mega-evolved mon
    @battlers[index].pbAbilitiesOnSwitchIn(true)
  end

  ################################################################################
  # Ultra Burst battler.
  ################################################################################
  def pbCanUltraBurst?(index)
    return false if $game_switches[:No_Mega_Evolution]
    return false if !@battlers[index].hasUltra?
    return false if !pbHasZRing(index)

    side = pbIsOpposing?(index) ? 1 : 0
    owner = pbGetOwnerIndex(index)
    return true if @ultraBurst[side][owner] == -1
    return false if @ultraBurst[side][owner] != index

    return true
  end

  def pbRegisterUltraBurst(index)
    side = pbIsOpposing?(index) ? 1 : 0
    owner = pbGetOwnerIndex(index)
    @ultraBurst[side][owner] = index
  end

  def pbUnRegisterUltraBurst(index)
    side = pbIsOpposing?(index) ? 1 : 0
    owner = pbGetOwnerIndex(index)
    @ultraBurst[side][owner] = -1
  end

  def pbUltraBurst(index)
    # Things that disallow ultra bursting
    return if !@battlers[index] || !@battlers[index].pokemon
    return if !(@battlers[index].hasUltra? rescue false)
    return if (@battlers[index].isUltra? rescue true)

    # Battle message start
    pbDisplay(_INTL("Bright light is about to burst out of {1}!", @battlers[index].pbThis))

    # Animation
    pbCommonAnimation("UltraBurst", @battlers[index], nil)

    # Update battler
    @battlers[index].pokemon.makeUltra
    @battlers[index].form = @battlers[index].pokemon.form
    @battlers[index].pbUpdate(true)
    @scene.pbChangePokemon(@battlers[index], @battlers[index].pokemon)

    # Battle message finish
    pbDisplay(_INTL("{1} regained its true power with Ultra Burst!", @battlers[index].pbThis))

    # Remember trainer has ultra bursted
    side = pbIsOpposing?(index) ? 1 : 0
    owner = pbGetOwnerIndex(index)
    @ultraBurst[side][owner] = -2

    # Re-update ability of ultra bursted mon
    @battlers[index].pbAbilitiesOnSwitchIn(true)
  end

  ################################################################################
  # Use Z-Move.
  ################################################################################
  def pbCanZMove?(index)
    return true if @battlers[index].effects[:IgnoreZflag] == true
    return false if $game_switches[:No_Z_Move]
    return false if !@battlers[index].hasZMove?
    return false if !pbHasZRing(index)

    side = pbIsOpposing?(index) ? 1 : 0
    owner = pbGetOwnerIndex(index)
    return true if @zMove[side][owner] == -1
    return false if @zMove[side][owner] != index

    return true
  end

  def pbRegisterZMove(index)
    side = pbIsOpposing?(index) ? 1 : 0
    owner = pbGetOwnerIndex(index)
    @zMove[side][owner] = index
  end

  def pbUnRegisterZMove(index)
    side = pbIsOpposing?(index) ? 1 : 0
    owner = pbGetOwnerIndex(index)
    @zMove[side][owner] = -1
  end

  def pbUseZMove(index, choice, crystal, specialZ = false)
    # Things that disallow z-move
    return if !@battlers[index] || !@battlers[index].pokemon

    if !specialZ
      return if !(@battlers[index].hasZMove? rescue false)
    end

    # Battle message
    if choice[2].hasFlag?(:intercept)
      owner = pbGetOwner(index)
      if owner
        pbDisplay(_INTL("{1} is drawing from the Core's power!", owner.name))
      else
        pbDisplay(_INTL("{1} is drawing from the Core's power!", @battlers[index].pbThis))
      end
    else
      pbDisplay(_INTL("{1} surrounded itself with its Z-Power!", @battlers[index].pbThis))
    end

    # Animation
    pbCommonAnimation("ZPower", @battlers[index], nil)
  end

  ################################################################################
  # Call battler.
  ################################################################################
  def pbCall(index)
    owner = pbGetOwner(index)
    pbDisplay(_INTL("{1} called {2}!", owner.name, @battlers[index].name))
    pbDisplay(_INTL("{1}!", @battlers[index].name))
    if @battlers[index].isShadow?
      if @battlers[index].inHyperMode?
        @battlers[index].pokemon.hypermode = false
        @battlers[index].pokemon.adjustHeart(-300)
        pbDisplay(_INTL("{1} came to its senses from the Trainer's call!", @battlers[index].pbThis))
      else
        pbDisplay(_INTL("But nothing happened!"))
      end
    elsif @battlers[index].status != :SLEEP && @battlers[index].pbCanIncreaseStatStage?(PBStats::ACCURACY)
      @battlers[index].pbIncreaseStat(PBStats::ACCURACY, 1)
    else
      pbDisplay(_INTL("But nothing happened!"))
    end
  end

  ################################################################################
  # Gaining Experience.
  ################################################################################
  def pbGainEXP
    return if !@internalbattle || @disableExpGain

    # Find who died and get their base EXP & level
    for i in 0...4 # Not ordered by priority
      if !@doublebattle && pbIsDoubleBattler?(i)
        @battlers[i].participants = []
        next
      end
      next unless pbIsOpposing?(i) && @battlers[i].participants.length > 0 && (@battlers[i].isFainted? || @decision == 4)

      baseexp = @battlers[i].baseExp
      level = @battlers[i].level
      mon_order = [] # order that the mons should be given EXP in
      # find who fought
      partic = 0
      for j in @battlers[i].participants
        next if !@party1[j] || !pbIsOwner?(0, j) || @party1[j].isEgg?
        next if @party1[j].hp <= 0 && !($game_switches[:Exp_All_On] && $game_switches[:Exp_All_Upgrade])

        partic += 1
        mon_order.push(j)
      end
      next if partic == 0 && $game_switches[:Exp_All_On] && $game_switches[:Exp_All_Upgrade]

      # push the rest of the party on that array
      for j in 0...@party1.length
        next if !@party1[j] || !pbIsOwner?(0, j) || @party1[j].isEgg?
        next if @party1[j].hp <= 0 && !($game_switches[:Exp_All_On] && $game_switches[:Exp_All_Upgrade])

        mon_order.push(j) if !mon_order.include?(j)
      end

      # get the base participant EXP
      partic = 1 if partic == 0
      partic_exp = (level * baseexp / partic).floor
      partic_exp = (partic_exp * 3 / 2).floor if @opponent

      # distribute EXP to each mon in the party
      messageskip = false
      for j in mon_order
        thispoke = @party1[j]

        # pokemon information for messages
        hasEXPshare = thispoke.item == :EXPSHARE || thispoke.itemInitial == :EXPSHARE
        boostedEXP = ((thispoke.trainerID != self.pbPlayer.id && thispoke.trainerID != 0) || (thispoke.language != 0 && thispoke.language != self.pbPlayer.language))
        mon_fought = @battlers[i].participants.include?(j)

        # did this mon fight?
        if mon_fought
          exp = partic_exp
        elsif hasEXPshare || $game_switches[:Exp_All_On] # didn't participate- has EXP Share or EXP All is on
          exp = (partic_exp / 3).floor # reduced
          exp = (partic_exp / 2).floor if $game_switches[:Exp_All_Upgrade]
        else # does not get EXP
          next
        end

        # Gain effort value points, using RS effort values
        pbGainEvs(thispoke, i) if mon_fought || hasEXPshare

        # reborn-added EXP booster: 8% per level over 100
        exp *= (1 + ((thispoke.level - 100) * 0.08)) if thispoke.level > 100
        if USENEWEXPFORMULA   # Use new (Gen 5) Exp. formula
          leveladjust = ((2 * level + 10.0) / (level + thispoke.level + 10.0))**2.5
          exp = (exp * leveladjust / 5).floor
        else                  # Use old (Gen 1-4) Exp. formula
          exp = (exp / 7).floor
        end

        # Trade EXP; different language EXP
        if boostedEXP
          exp *= (thispoke.language != 0 && thispoke.language != self.pbPlayer.language) ? 1.7 : 1.5
        end
        exp = (exp * 3 / 2).floor if thispoke.item == :LUCKYEGG || thispoke.itemInitial == :LUCKYEGG
        exp = (exp * $game_variables[:Exp_Percent] / 100).floor if $game_switches[:Percent_Exp_Gains]
        exp = [-1, exp.floor].min if exp < 0
        exp = [0, exp.floor].max if exp >= 0 # Includes NoExp in formula

        # We have the EXP that this mon can gain.
        growthrate = thispoke.growthrate
        if $game_switches[:Hard_Level_Cap] || $game_switches[:Exp_All_On] || !Reborn # Rejuv-style Level Cap
          badgenum = pbPlayer.numbadges
          if thispoke.level >= LEVELCAPS[badgenum] && !negExp? # Allows negative exp to keep going down
            exp = 0
          elsif thispoke.level < LEVELCAPS[badgenum]
            totalExpNeeded = PBExp.startExperience(LEVELCAPS[badgenum], growthrate)
            currExpNeeded = totalExpNeeded - thispoke.exp
            exp = [currExpNeeded, exp].min
          end
        end
        newexp = PBExp.addExperience(thispoke.exp, exp, growthrate)
        exp = (newexp - thispoke.exp).floor
        exp = 0 if noExp?
        next if exp == 0

        if mon_fought || (hasEXPshare && !$game_switches[:Exp_All_On])
          # EXP All text is handled at the end
          if boostedEXP || thispoke.item == :LUCKYEGG
            # Combine into tertiary statements as alternate
            pbDisplay(_INTL("{1} lost a boosted {2} Exp. Points!", thispoke.name, -1 * exp)) if negExp?
            pbDisplay(_INTL("{1} gained a boosted {2} Exp. Points!", thispoke.name, exp)) if posExp? || noExp?
          else
            # Combine into tertiary statements as alternate
            pbDisplay(_INTL("{1} lost {2} Exp. Points!", thispoke.name, -1 * exp)) if negExp?
            pbDisplay(_INTL("{1} gained {2} Exp. Points!", thispoke.name, exp)) if posExp? || noExp?
          end
        elsif $game_switches[:Exp_All_On]
          # Combine into tertiary statements as alternate
          pbDisplay(_INTL("The rest of your team lost Exp. Points thanks to the Exp. All!")) if !messageskip && negExp?
          pbDisplay(_INTL("The rest of your team gained Exp. Points thanks to the Exp. All!")) if !messageskip && (posExp? || noExp?)
          messageskip = true
        end

        # actually add the EXP
        newlevel = PBExp.levelFromExperience(newexp, growthrate)
        oldlevel = thispoke.level
        if thispoke.respond_to?("isShadow?") && thispoke.isShadow?
          thispoke.exp += exp
          next
        end
        # Find battler
        battler = pbFindPlayerBattler(j)
        battler = nil if battler && battler.pokemon != thispoke
        curlevel = oldlevel
        oldtotalhp = thispoke.totalhp
        oldattack = thispoke.attack
        olddefense = thispoke.defense
        oldspeed = thispoke.speed
        oldspatk = thispoke.spatk
        oldspdef = thispoke.spdef
        tempexp1 = thispoke.exp
        loop do
          # EXP Bar animation
          startexp = PBExp.startExperience(curlevel, growthrate)
          endexp = PBExp.startExperience(curlevel + 1, growthrate)
          tempexp2 = (endexp < newexp) ? endexp : newexp if posExp? || noExp?
          tempexp2 = (startexp > newexp) ? startexp : newexp if negExp?
          thispoke.exp = tempexp2
          @scene.pbEXPBar(thispoke, battler, startexp, endexp, tempexp1, tempexp2)
          tempexp1 = tempexp2
          curlevel += 1 if posExp? || noExp?
          curlevel -= 1 if negExp?
          if (curlevel > newlevel && (posExp? || noExp?)) || (curlevel < newlevel && negExp?)
            @scene.pbRefresh
            break
          end
          thispoke.level = curlevel
          thispoke.changeHappiness("level up")
        end
        next if newlevel == oldlevel

        # leveled up! or lvl down! :(
        thispoke.calcStats
        battler.pbUpdate(false) if battler
        @scene.pbRefresh
        noevo = false
        if posExp? || noExp?
          pbDisplayAutoPaused(_INTL("{1} grew to Level {2}!", thispoke.name, newlevel))
          @scene.pbLevelUp(thispoke, battler, oldtotalhp, oldattack, olddefense, oldspeed, oldspatk, oldspdef)
        elsif negExp?
          pbDisplayAutoPaused(_INTL("{1} fell to Level {2}!", thispoke.name, newlevel))
          @scene.pbLevelDown(thispoke, battler, oldtotalhp, oldattack, olddefense, oldspeed, oldspatk, oldspdef)
          noevo = true
        end

        # Finding all moves learned at this level
        movelist = thispoke.getMoveList
        for lvl in oldlevel + 1..newlevel
          for k in movelist
            if k[0] == lvl # Learned a new move
              pbLearnMove(j, k[1])
            end
          end
        end

        # evolve if able to
        newspecies = checkEvolution(thispoke)
        next if newspecies.nil?

        # make sure that evo DOESN'T HAPPEN ON LVL DOWN
        next if noevo

        pbFadeOutInWithMusic(99999) {
          evo = PokemonEvolutionScene.new
          evo.pbStartScreen(thispoke, newspecies)
          evolved = evo.pbEvolution
          evo.pbEndScreen
          $game_map.autoplayAsCue
          if evolved && battler
            @scene.pbChangePokemon(@battlers[battler.index], @battlers[battler.index].pokemon)
            battler.species = thispoke.species
            battler.form = thispoke.form
            battler.pbUpdate(true)
            @scene.sprites["battlebox#{battler.index}"].refresh
            battler.name = thispoke.name
            for ii in 0...thispoke.moves.length
              battler.moves[ii] = PokeBattle_Move.pbFromPBMove(self, thispoke.moves[ii], battler.pokemon)
            end
          end
        }
      end

      # Now clear the participants array
      @battlers[i].participants = []
    end
  end

  def pbGainEvs(thispoke, i)
    # Gain effort value points, using RS effort values
    totalev = 0
    for k in 0..5
      totalev += thispoke.ev[k]
    end
    # Original species, not current species
    evyield = @battlers[i].evYield
    for k in 0..5
      evgain = evyield[k]
      evgain *= 8 if thispoke.item == :MACHOBRACE || thispoke.itemInitial == :MACHOBRACE
      evgain = 0 if [:POWERWEIGHT, :POWERBRACER, :POWERBELT, :POWERANKLET, :POWERLENS, :POWERBAND].include?(thispoke.item)
      case k
        when 0 then evgain += 32 if thispoke.item == :POWERWEIGHT
        when 1 then evgain += 32 if thispoke.item == :POWERBRACER
        when 2 then evgain += 32 if thispoke.item == :POWERBELT
        when 3 then evgain += 32 if thispoke.item == :POWERLENS
        when 4 then evgain += 32 if thispoke.item == :POWERBAND
        when 5 then evgain += 32 if thispoke.item == :POWERANKLET
      end
      case k
        when 0 then evgain += 8 if thispoke.item == :CANONPOWERWEIGHT
        when 1 then evgain += 8 if thispoke.item == :CANONPOWERBRACER
        when 2 then evgain += 8 if thispoke.item == :CANONPOWERBELT
        when 3 then evgain += 8 if thispoke.item == :CANONPOWERLENS
        when 4 then evgain += 8 if thispoke.item == :CANONPOWERBAND
        when 5 then evgain += 8 if thispoke.item == :CANONPOWERANKLET
      end
      evgain *= 4 if thispoke.pokerusStage >= 1 # Infected or cured
      evgain = 0 if $game_switches[:Stop_Ev_Gain]
      if evgain > 0
        # Can't exceed overall limit
        evgain -= totalev + evgain - 510 if totalev + evgain > 510 && !$game_switches[:No_Total_EV_Cap]
        # Can't exceed stat limit
        evgain -= thispoke.ev[k] + evgain - 252 if thispoke.ev[k] + evgain > 252
        evgain = 0 if evgain < 0
        # Add EV gain
        thispoke.ev[k] += evgain
        if thispoke.ev[k] > 252
          print "Single-stat EV limit 252 exceeded.\r\nStat: #{k}  EV gain: #{evgain}  EVs: #{thispoke.ev.inspect}"
          thispoke.ev[k] = 252
        end
        totalev += evgain
        if totalev > 510 && !$game_switches[:No_Total_EV_Cap] && !$game_switches[:SnagMachine_Password]
          print "EV limit 510 exceeded.\r\nTotal EVs: #{totalev} EV gain: #{evgain}  EVs: #{thispoke.ev.inspect}"
        end
      end
    end
  end

  ################################################################################
  # Learning a move.
  ################################################################################
  def pbLearnMove(pkmnIndex, move)
    pokemon = @party1[pkmnIndex]
    return if !pokemon

    pkmnname = pokemon.name
    battler = pbFindPlayerBattler(pkmnIndex)
    movename = getMoveName(move)
    for i in 0...4
      if !pokemon.moves[i]
        pokemon.moves[i] = PBMove.new(move)
        battler.moves[i] = PokeBattle_Move.pbFromPBMove(self, pokemon.moves[i], battler.pokemon) if battler
        if !pokemon.zmoves.nil? && pokemon.item != :INTERCEPTZ
          pokemon.updateZMoveIndex(i)
          updateZMoveIndexBattler(i, battler) if battler
        end
        pbDisplayPaused(_INTL("{1} learned {2}!", pkmnname, movename))
        return
      end
      checkdupe = pokemon.moves[i].move
      if checkdupe == move
        return
      end
    end
    loop do
      pbDisplayPaused(_INTL("{1} is trying to learn {2}.", pkmnname, movename))
      pbDisplayPaused(_INTL("But {1} can't learn more than four moves.", pkmnname))
      if pbDisplayConfirm(_INTL("Delete a move to make room for {1}?", movename))
        pbDisplayPaused(_INTL("Which move should be forgotten?"))
        forgetmove = @scene.pbForgetMove(pokemon, move)
        if forgetmove >= 0
          oldmovename = getMoveName(pokemon.moves[forgetmove].move)
          pokemon.moves[forgetmove] = PBMove.new(move) # Replaces current/total PP
          battler.moves[forgetmove] = PokeBattle_Move.pbFromPBMove(self, pokemon.moves[forgetmove], battler.pokemon) if battler
          if !pokemon.zmoves.nil? && pokemon.item != :INTERCEPTZ
            pokemon.updateZMoveIndex(forgetmove)
            updateZMoveIndexBattler(forgetmove, battler) if battler
          end
          pbDisplayPaused(_INTL("1,  2, and... ... ..."))
          pbDisplayPaused(_INTL("Poof!"))
          pbDisplayPaused(_INTL("{1} forgot {2}.", pkmnname, oldmovename))
          pbDisplayPaused(_INTL("And..."))
          pbDisplayPaused(_INTL("{1} learned {2}!", pkmnname, movename))
          return
        elsif pbDisplayConfirm(_INTL("Should {1} stop learning {2}?", pkmnname, movename))
          pbDisplayPaused(_INTL("{1} did not learn {2}.", pkmnname, movename))
          return
        end
      elsif pbDisplayConfirm(_INTL("Should {1} stop learning {2}?", pkmnname, movename))
        pbDisplayPaused(_INTL("{1} did not learn {2}.", pkmnname, movename))
        return
      end
    end
  end

  def updateZMoveIndexBattler(index, battler, ignore = false)
    if PBStuff::ZCRYSTALTOTYPE[battler.item]
      if battler.moves[index].type != PBStuff::ZCRYSTALTOTYPE[battler.item]
        battler.zmoves[index] = nil
      else
        zmove = battler.moves[index].category == :status ? PBMove.new(battler.moves[index].move) : PBMove.new(PBStuff::CRYSTALTOZMOVE[battler.item])
        battler.zmoves[index] = PokeBattle_Move.pbFromPBMove(self, zmove, battler.pokemon, battler.moves[index])
      end
    elsif ignore
      zmove = battler.moves[index].category == :status ? PBMove.new(battler.moves[index].move) : PBMove.new(PBStuff::CRYSTALTOZMOVE[PBStuff::TYPETOZCRYSTAL[battler.moves[index].type]])
      battler.zmoves[index] = PokeBattle_Move.pbFromPBMove(self, zmove, battler.pokemon, battler.moves[index])
    elsif PBStuff::MOVETOZCRYSTAL.invert[battler.item]
      speciesblock = false
      case battler.item
        when :ALORAICHIUMZ then speciesblock = true if !(battler.species == :RAICHU && battler.form == 1)
        when :DECIDIUMZ then speciesblock = true if !(battler.species == :DECIDUEYE && battler.form == 0)
        when :INCINIUMZ then speciesblock = true if battler.species != :INCINEROAR
        when :PRIMARIUMZ then speciesblock = true if battler.species != :PRIMARINA
        when :EEVIUMZ then speciesblock = true if battler.species != :EEVEE
        when :PIKANIUMZ then speciesblock = true if battler.species != :PIKACHU
        when :SNORLIUMZ then speciesblock = true if battler.species != :SNORLAX
        when :MEWNIUMZ then speciesblock = true if battler.species != :MEW
        when :TAPUNIUMZ then speciesblock = true if !(battler.species == :TAPUKOKO || battler.species == :TAPULELE || battler.species == :TAPUFINI || battler.species == :TAPUBULU)
        when :MARSHADIUMZ then speciesblock = true if battler.species != :MARSHADOW
        when :KOMMONIUMZ then speciesblock = true if battler.species != :KOMMOO
        when :LYCANIUMZ then speciesblock = true if battler.species != :LYCANROC
        when :MIMIKIUMZ then speciesblock = true if battler.species != :MIMIKYU
        when :SOLGANIUMZ then speciesblock = true if !((battler.species == :NECROZMA && battler.form == 1) || battler.species == :SOLGALEO)
        when :LUNALIUMZ then speciesblock = true if !((battler.species == :NECROZMA && battler.form == 2) || battler.species == :LUNALA)
        when :ULTRANECROZIUMZ then speciesblock = true if !(battler.species == :NECROZMA && battler.form != 0)
      end
      if battler.item != PBStuff::MOVETOZCRYSTAL[battler.moves[index].move] || speciesblock
        battler.zmoves[index] = nil
      else
        zmove = PBMove.new(PBStuff::CRYSTALTOZMOVE[battler.item])
        battler.zmoves[index] = PokeBattle_Move.pbFromPBMove(self, zmove, battler.pokemon, battler.moves[index])
      end
    end
  end

  ################################################################################
  # Abilities.
  ################################################################################
  def pbOnActiveAll
    for i in 0...4 # Currently unfainted participants will earn EXP even if they faint afterwards
      @battlers[i].pbUpdateParticipants if pbIsOpposing?(i)
      @amuletcoin = true if !pbIsOpposing?(i) && ((@battlers[i].item == :AMULETCOIN) || (@battlers[i].item == :LUCKINCENSE))
    end

    # Weather-inducing abilities, Trace, Imposter, etc.
    @usepriority = false
    priority = pbPriority
    for i in priority
      pbOnActiveOne(i) # might cause weird ability behaviour on first turn
      i.pbAbilitiesOnSwitchIn(true)
    end

    # Check forms are correct
    for i in 0...4
      @battlers[i].pbCheckWeatherForm
    end
    pbJudge
  end

  def pbOnActiveOne(pkmn, onlyabilities = false)
    return false if pkmn.isFainted?

    # Neutralizing Gas
    if pbCheckGlobalAbility(:NEUTRALIZINGGAS) && !(PBStuff::FIXEDABILITIES + [:NEUTRALIZINGGAS]).include?(pkmn.ability)
      pkmn.changeAbility(:suppress)
    end
    if !onlyabilities
      for i in 0...4 # Currently unfainted participants will earn EXP even if they faint afterwards
        @battlers[i].pbUpdateParticipants if pbIsOpposing?(i)
        @amuletcoin = true if !pbIsOpposing?(i) && ((@battlers[i].item == :AMULETCOIN) || (@battlers[i].item == :LUCKINCENSE))
      end
      # Chess Field piece boosts
      if @field.effect == :CHESS
        case pkmn.pokemon.piece
          when :PAWN
            pbDisplay(_INTL("{1} became a Pawn and stormed up the board!", pkmn.pbThis))
          when :KING
            pbDisplay(_INTL("{1} became a King and exposed itself!", pkmn.pbThis))
          when :KNIGHT
            pbDisplay(_INTL("{1} became a Knight and readied its position!", pkmn.pbThis)) # oo they shmovin' but i gotta change this im sry
          when :BISHOP
            pbDisplay(_INTL("{1} became a Bishop and took the diagonal!", pkmn.pbThis))
            pkmn.pbIncreaseStat(PBStats::ATTACK, 1, statsource: pkmn)
            pkmn.pbIncreaseStat(PBStats::SPATK, 1, statsource: pkmn)
          when :ROOK
            pbDisplay(_INTL("{1} became a Rook and took the open file!", pkmn.pbThis))
            pkmn.pbIncreaseStat(PBStats::DEFENSE, 1, statsource: pkmn)
            pkmn.pbIncreaseStat(PBStats::SPDEF, 1, statsource: pkmn)
          when :QUEEN
            pbDisplay(_INTL("{1} became a Queen and was placed on the center of the board!", pkmn.pbThis))
            pkmn.pbIncreaseStat(PBStats::DEFENSE, 1, statsource: pkmn)
            pkmn.pbIncreaseStat(PBStats::SPDEF, 1, statsource: pkmn)

        end
      elsif @field.effect == :CROWD
        scoreToCompare = $game_variables[:BattleDataArray].last().getScoreAndSide(pkmn)
        highestOpposingScore = [0, nil, ""]
        for b in 0...@battlers.length
          battlerArray = $game_variables[:BattleDataArray].last().getScoreAndSide(@battlers[b])
          if battlerArray[1] != scoreToCompare[1] && battlerArray[0].to_i > highestOpposingScore[0].to_i
            highestOpposingScore = battlerArray
          end
        end
        oppScore = highestOpposingScore[0].to_i
        pkmn.tempBoosts = []
        message = ""
        buffs = []
        if oppScore >= 3
          $overscored = highestOpposingScore[2]
          buffs.push("pkmn.pbIncreaseStatBasic(PBStats::ATTACK,1)")
          buffs.push("pkmn.pbIncreaseStatBasic(PBStats::SPATK,1)")
          buffs.push("pkmn.pbIncreaseStatBasic(PBStats::SPEED,1)")
          pkmn.tempBoosts.push("self.pbReduceStatBasic(PBStats::ATTACK,1)")
          pkmn.tempBoosts.push("self.pbReduceStatBasic(PBStats::SPATK,1)")
          pkmn.tempBoosts.push("self.pbReduceStatBasic(PBStats::SPEED,1)")
          message = _INTL("The crowd begins rooting for an underdog to take {1} down a peg!", highestOpposingScore[2])
        end
        if oppScore >= 4
          $overscored = highestOpposingScore[2]
          buffs.push("pkmn.pbIncreaseStatBasic(PBStats::SPDEF,1)")
          buffs.push("pkmn.pbIncreaseStatBasic(PBStats::DEFENSE,1)")
          buffs.push("pkmn.pbIncreaseStatBasic(PBStats::SPEED,1)")
          pkmn.tempBoosts.push("self.pbReduceStatBasic(PBStats::SPDEF,1)")
          pkmn.tempBoosts.push("self.pbReduceStatBasic(PBStats::DEFENSE,1)")
          pkmn.tempBoosts.push("self.pbReduceStatBasic(PBStats::SPEED,1)")
          message = _INTL("{1} has overstayed its welcome for the crowd!", highestOpposingScore[2])
        end
        if oppScore >= 5
          $overscored = highestOpposingScore[2]
          buffs.push("pkmn.pbIncreaseStatBasic(PBStats::SPDEF,1)")
          buffs.push("pkmn.pbIncreaseStatBasic(PBStats::DEFENSE,1)")
          buffs.push("pkmn.pbIncreaseStatBasic(PBStats::SPEED,1)")
          buffs.push("pkmn.pbIncreaseStatBasic(PBStats::ATTACK,1)")
          buffs.push("pkmn.pbIncreaseStatBasic(PBStats::SPATK,1)")
          pkmn.tempBoosts.push("self.pbReduceStatBasic(PBStats::ATTACK,1)")
          pkmn.tempBoosts.push("self.pbReduceStatBasic(PBStats::SPATK,1)")
          pkmn.tempBoosts.push("self.pbReduceStatBasic(PBStats::SPEED,1)")
          pkmn.tempBoosts.push("self.pbReduceStatBasic(PBStats::DEFENSE,1)")
          pkmn.tempBoosts.push("self.pbReduceStatBasic(PBStats::SPDEF,1)")
          message = _INTL("\"DON'T GIVE UP NOW, {1}!!\"", scoreToCompare[2].upcase)
        end
        buffs.push("@battle.pbCommonAnimation(\"StatUp\",pkmn,nil)") if (buffs.length > 0)
        for i in 0...buffs.length
          eval(buffs[i])
        end
        pbDisplay(message) if (message != "")
      end
      # Balloon
      if pkmn.hasWorkingItem(:AIRBALLOON)
        @battle.pbDisplay(_INTL("{1} is floating on its balloon!", pkmn.pbThis))
      end
      # Deep earth item entries
      if @battle.FE == :DEEPEARTH
        if pkmn.hasWorkingItem(:IRONBALL)
          pkmn.pbReduceStat(PBStats::SPEED, 2, statdropper: pkmn)
        end
        if pkmn.hasWorkingItem(:MAGNET)
          pkmn.pbReduceStat(PBStats::SPEED, 1, statmessage: false, statdropper: pkmn)
          pkmn.pbIncreaseStat(PBStats::SPATK, 1, statmessage: false)
          @battle.pbDisplay(_INTL("{1}'s {2} is affected by the magnetic field!", pkmn.pbThis, getItemName(pkmn.item)))
        end
      end
      # Shadow Pokemon
      if pkmn.isShadow? && pbIsOpposing?(pkmn.index)
        pbCommonAnimation("Shadow", pkmn, nil)
        pbDisplay(_INTL("Oh!\nA Shadow Pokémon!"))
      end
      # Black Prism Rage
      if Rejuv
        if pkmn.item == :BLKPRISM && !@battle.pbOwnedByPlayer?(pkmn.index)
          for stat in 1..5
            if !pkmn.pbTooHigh?(stat)
              pkmn.pbIncreaseStatBasic(stat, 2)
            end
          end
          @battle.pbCommonAnimation("StatUp", pkmn, nil)
          @battle.pbDisplay(_INTL("{1} is in a wild rage!", pkmn.pokemon.name))
        end
      end
      # Healing Wish
      if pkmn.effects[:HealingWish]
        if Gen <= 7 || pkmn.hp != pkmn.totalhp || pkmn.status != nil
          pkmn.pbRecoverHP(pkmn.totalhp, true)
          pkmn.status = nil
          pkmn.statusCount = 0
          if @field.effect == :FAIRYTALE || @field.effect == :STARLIGHT
            pkmn.pbIncreaseStat(PBStats::ATTACK, 1)
            pkmn.pbIncreaseStat(PBStats::SPATK, 1)
          end
          pbDisplay(_INTL("The healing wish came true for {1}!", pkmn.pbThis(true)))
          pkmn.effects[:HealingWish] = false
        end
      end
      # Lunar Dance
      if pkmn.effects[:LunarDance]
        if Gen <= 7 || pkmn.hp != pkmn.totalhp || pkmn.status != nil ||
           (pkmn.moves[0] && pkmn.moves[0].pp != pkmn.moves[0].totalpp) ||
           (pkmn.moves[1] && pkmn.moves[1].pp != pkmn.moves[1].totalpp) ||
           (pkmn.moves[2] && pkmn.moves[2].pp != pkmn.moves[2].totalpp) ||
           (pkmn.moves[3] && pkmn.moves[3].pp != pkmn.moves[3].totalpp)
          pkmn.pbRecoverHP(pkmn.totalhp, true)
          pkmn.status = nil
          pkmn.statusCount = 0
          if @field.effect == :STARLIGHT || @field.effect == :NEWWORLD || @field.effect == :DANCEFLOOR
            stats = [PBStats::ATTACK, PBStats::SPATK] if @field.effect == :STARLIGHT
            stats = *(1..5) if @field.effect == :NEWWORLD || @field.effect == :DANCEFLOOR
            for stat in stats
              pkmn.pbIncreaseStat(stat, 1)
            end
          end
          for i in 0...4
            next if !pkmn.moves[i]

            pkmn.moves[i].pp = pkmn.moves[i].totalpp
          end
          pbDisplay(_INTL("{1} became cloaked in mystical moonlight!", pkmn.pbThis))
          pkmn.effects[:LunarDance] = false
        end
      end
      # Z-Memento/Parting Shot
      if pkmn.effects[:ZHeal]
        pkmn.pbRecoverHP(pkmn.totalhp, false)
        pbDisplay(_INTL("The Z-Power healed {1}!", pkmn.pbThis(true)))
        pkmn.effects[:ZHeal] = false
      end
      # Spikes
      pkmn.pbOwnSide.effects[:Spikes] = 0 if @field.effect == :WATERSURFACE || @field.effect == :MURKWATERSURFACE || @field.effect == :SKY || @field.effect == :CLOUDS
      if pkmn.pbOwnSide.effects[:Spikes] > 0 && @field.effect != :WASTELAND
        if (!pkmn.isAirborne? || (Rejuv && @field.effect == :ELECTERRAIN)) && !pkmn.hasWorkingItem(:HEAVYDUTYBOOTS)
          if pkmn.ability != :MAGICGUARD && !(pkmn.ability == :WONDERGUARD && @battle.FE == :COLOSSEUM)
            spikesdiv = [8, 8, 6, 4][pkmn.pbOwnSide.effects[:Spikes]]
            if Rejuv && @battle.FE == :ELECTERRAIN
              atype = :ELECTRIC
              eff = PBTypes.twoTypeEff(atype, pkmn.type1, pkmn.type2)
              if ($game_switches[:Inversemode] && !@battle.isOnline?) ^ (@field.effect == :INVERSE)
                switcheff = { 16 => 1, 8 => 2, 4 => 4, 2 => 8, 1 => 16, 0 => 16 }
                eff = switcheff[eff]
              end
              if eff > 0
                @scene.pbDamageAnimation(pkmn, 0)
                pkmn.pbReduceHP([((pkmn.totalhp * eff) / (4 * spikesdiv)).floor, 1].max)
                pbDisplay(_INTL("{1} was hurt by electrified Spikes!", pkmn.pbThis))
              end
            else
              @scene.pbDamageAnimation(pkmn, 0)
              pkmn.pbReduceHP([(pkmn.totalhp.to_f / spikesdiv).floor, 1].max)
              pbDisplay(_INTL("{1} was hurt by Spikes!", pkmn.pbThis))
            end
          end
        end
      end
      if pkmn.isFainted?
        pkmn.pbFaint
        pkmn.pbOwnSide.effects[:Retaliate] = true
        if !@midturn
          pbGainEXP
          10.times do
            # loop in case the new mon immediately dies to hazards
            pbSwitch(false, true)
          end
          return if @decision > 0

          priority = pbPriority
          for i in priority
            next if i.isFainted?

            i.pbAbilitiesOnSwitchIn(false)
          end
        else
          pbJudge
          return if @decision > 0
        end
        return
      end
      # Stealth Rock
      if pkmn.pbOwnSide.effects[:StealthRock] && @field.effect != :WASTELAND
        if pkmn.ability != :MAGICGUARD && !(pkmn.ability == :WONDERGUARD && @battle.FE == :COLOSSEUM) && !pkmn.hasWorkingItem(:HEAVYDUTYBOOTS)
          atype = :ROCK
          atype = @field.getRoll if @field.effect == :CRYSTALCAVERN
          atype = :FIRE if @field.effect == :VOLCANICTOP || @field.effect == :INFERNAL || (Rejuv && @field.effect == :DRAGONSDEN)
          atype = :POISON if @field.effect == :CORRUPTED
          eff = PBTypes.twoTypeEff(atype, pkmn.type1, pkmn.type2)
          if ($game_switches[:Inversemode] && !@battle.isOnline?) ^ (@field.effect == :INVERSE)
            switcheff = { 16 => 1, 8 => 2, 4 => 4, 2 => 8, 1 => 16, 0 => 16 }
            eff = switcheff[eff]
          end
          if eff > 0
            if @field.effect == :ROCKY || @field.effect == :CAVE
              eff = eff * 2
            end
            @scene.pbDamageAnimation(pkmn, 0)
            pkmn.pbReduceHP([(pkmn.totalhp * eff / 32).floor, 1].max)
            if @field.effect == :CRYSTALCAVERN
              pbDisplay(_INTL("{1} was hurt by the crystalized stealth rocks!", pkmn.pbThis))
            elsif @field.effect == :VOLCANICTOP || @field.effect == :INFERNAL || (Rejuv && @field.effect == :DRAGONSDEN)
              pbDisplay(_INTL("{1} was hurt by the molten stealth rocks!", pkmn.pbThis))
            elsif @field.effect == :CORRUPTED
              pbDisplay(_INTL("{1} was hurt by the corrupted stealth rocks!", pkmn.pbThis))
            else
              pbDisplay(_INTL("{1} was hurt by Stealth Rocks!", pkmn.pbThis))
            end
          end
        end
      end
      if pkmn.isFainted?
        pkmn.pbFaint
        pkmn.pbOwnSide.effects[:Retaliate] = true
        if !@midturn
          pbGainEXP
          10.times do
            # loop in case the new mon immediately dies to hazards
            pbSwitch(false, true)
          end
          return if @decision > 0

          priority = pbPriority
          for i in priority
            next if i.isFainted?

            i.pbAbilitiesOnSwitchIn(false)
          end
        else
          pbJudge
          return if @decision > 0
        end
        return
      end
      # Corrosive Field Entry
      if @field.effect == :CORROSIVE
        if !pkmn.isAirborne? && !pkmn.hasType?(:POISON) && !pkmn.hasType?(:STEEL) && !pkmn.hasWorkingItem(:HEAVYDUTYBOOTS) &&
           ![:MAGICGUARD, :POISONHEAL, :IMMUNITY, :WONDERGUARD, :TOXICBOOST, :PASTELVEIL].include?(pkmn.ability) &&
           pkmn.crested != :ZANGOOSE && !(pkmn.isbossmon && pkmn.immunities[:fieldEffectDamage].include?(@field.effect))
          atype = :POISON
          eff = PBTypes.twoTypeEff(atype, pkmn.type1, pkmn.type2)
          if eff > 0
            eff = eff * 2
            @scene.pbDamageAnimation(pkmn, 0)
            pkmn.pbReduceHP([(pkmn.totalhp * eff / 32).floor, 1].max)
            pbDisplay(_INTL("{1} was seared by the corrosion!", pkmn.pbThis))
          end
        end
      end
      if ProgressiveFieldCheck(PBFields::CONCERT, 3, 4)
        if pkmn.status == :SLEEP || pkmn.ability == :COMATOSE
          pkmn.status = nil if pkmn.status == :SLEEP
          pkmn.changeAbility(nil) if pkmn.ability == :COMATOSE
          pkmn.pbReduceHP(pkmn.totalhp / 4)
          pbDisplay(_INTL("The Concert's noise could wake up even the dead!"))
        end
      end
      if pkmn.isFainted?
        pkmn.pbFaint
        pkmn.pbOwnSide.effects[:Retaliate] = true
        if !@midturn
          pbGainEXP
          10.times do
            # loop in case the new mon immediately dies to hazards
            pbSwitch(false, true)
          end
          return if @decision > 0

          priority = pbPriority
          for i in priority
            next if i.isFainted?

            i.pbAbilitiesOnSwitchIn(false)
          end
        else
          pbJudge
          return if @decision > 0
        end
        return
      end
      # Sticky Web
      pkmn.pbOwnSide.effects[:StickyWeb] = false if @field.effect == :SKY || @field.effect == :CLOUDS
      if pkmn.pbOwnSide.effects[:StickyWeb] && @field.effect != :WASTELAND
        if !pkmn.isAirborne? && !pkmn.hasWorkingItem(:HEAVYDUTYBOOTS)
          stat = @field.effect == :FOREST ? 2 : 1
          pbDisplay(_INTL("{1} was caught in a sticky web!", pkmn.pbThis))
          pkmn.pbReduceStat(PBStats::SPEED, stat)
        end
      end
      # Toxic Spikes
      pkmn.pbOwnSide.effects[:ToxicSpikes] = 0 if @field.effect == :WATERSURFACE || @field.effect == :MURKWATERSURFACE || @field.effect == :SKY || @field.effect == :CLOUDS
      if pkmn.pbOwnSide.effects[:ToxicSpikes] > 0 && !pkmn.isAirborne? && @field.effect != :WASTELAND
        if pkmn.hasType?(:POISON) && @field.effect != :CORROSIVE
          pkmn.pbOwnSide.effects[:ToxicSpikes] = 0
          pbDisplay(_INTL("{1} absorbed the poison spikes!", pkmn.pbThis))
        elsif pkmn.pbCanPoisonSpikes?(true) && !pkmn.hasWorkingItem(:HEAVYDUTYBOOTS)
          if pkmn.pbOwnSide.effects[:ToxicSpikes] == 2
            pkmn.pbPoison(pkmn, true)
            pbDisplay(_INTL("{1} was badly poisoned!", pkmn.pbThis))
          else
            pkmn.pbPoison(pkmn)
            pbDisplay(_INTL("{1} was poisoned!", pkmn.pbThis))
          end
        end
      end
    end
    if pkmn.status == :PETRIFIED
      pkmn.effects[:Petrification] = pkmn.pbOppositeOpposing.index
    end
    pkmn.pbAbilityCureCheck
    if !onlyabilities
      pkmn.pbCheckWeatherForm
      pkmn.pbBerryHerbCheck
    end
    # Emergency exit caused by taking hazard damage
    if pkmn.userSwitch
      pkmn.userSwitch = false
      neutralizingGasDisable(pkmn.index) if pkmn.ability == :NEUTRALIZINGGAS
      pbDisplay(_INTL("{1} went back to {2}!", pkmn.pbThis, pbGetOwner(pkmn.index).name))
      newpoke = pbSwitchInBetween(pkmn.index, true, false)
      pbMessagesOnReplace(pkmn.index, newpoke)
      pkmn.vanished = false
      pkmn.pbResetForm
      pbReplace(pkmn.index, newpoke)
      pbOnActiveOne(pkmn)
      pkmn.pbAbilitiesOnSwitchIn(true)
    end
    # Imposter (should activate only when pokemon is sent out)
    if pkmn.ability == :IMPOSTER && !pkmn.effects[:Transform] && pkmn.pbOppositeOpposing.hp > 0
      choice = pkmn.pbOppositeOpposing
      if !(choice.effects[:Substitute] > 0 ||
         choice.effects[:Transform] ||
         choice.effects[:SkyDrop] ||
         PBStuff::TWOTURNMOVE.include?(choice.effects[:TwoTurnAttack]) ||
         choice.effects[:Illusion])
        pkmn.pbTransform(choice)
      end
    end
    runtrainerskills(pkmn)
    return true
  end

  ################################################################################
  # Judging.
  ################################################################################
  def pbJudgeCheckpoint(attacker, move = 0)
  end

  def pbDecisionOnTime
    count1 = 0
    count2 = 0
    hptotal1 = 0
    hptotal2 = 0
    for i in @party1
      next if !i

      if i.hp > 0 && !i.isEgg?
        count1 += 1
        hptotal1 += i.hp
      end
    end
    for i in @party2
      next if !i

      if i.hp > 0 && !i.isEgg?
        count2 += 1
        hptotal2 += i.hp
      end
    end
    return 1 if count1 > count2     # win
    return 2 if count1 < count2     # loss
    return 1 if hptotal1 > hptotal2 # win
    return 2 if hptotal1 < hptotal2 # loss

    return 5 # draw
  end

  def pbDecisionOnTime2
    count1 = 0
    count2 = 0
    hptotal1 = 0
    hptotal2 = 0
    for i in @party1
      next if !i

      if i.hp > 0 && !i.isEgg?
        count1 += 1
        hptotal1 += (i.hp * 100 / i.totalhp)
      end
    end
    hptotal1 /= count1 if count1 > 0
    for i in @party2
      next if !i

      if i.hp > 0 && !i.isEgg?
        count2 += 1
        hptotal2 += (i.hp * 100 / i.totalhp)
      end
    end
    hptotal2 /= count2 if count2 > 0
    return 1 if count1 > count2     # win
    return 2 if count1 < count2     # loss
    return 1 if hptotal1 > hptotal2 # win
    return 2 if hptotal1 < hptotal2 # loss

    return 5 # draw
  end

  def pbDecisionOnDraw
    return 5 # draw
  end

  def pbJudge
    #   PBDebug.log("[Counts: #{pbPokemonCount(@party1)}/#{pbPokemonCount(@party2)}]")
    if pbAllFainted?(@party1) && pbAllFainted?(@party2)
      @decision = pbDecisionOnDraw() # Draw
      return
    end
    if pbAllFainted?(@party1)
      @decision = 2 # Loss
      return
    end
    if pbAllFainted?(@party2)
      @decision = 1 # Win
      return
    end
  end

  ################################################################################
  # Messages and animations.
  ################################################################################
  def pbApplySceneBG(sprite, filename)
    @scene.pbApplyBGSprite(sprite, filename)
  end

  def pbDisplay(msg)
    @scene.pbDisplayMessage(msg)
  end

  def pbDisplayPaused(msg)
    @scene.pbDisplayPausedMessage(msg)
  end

  def pbDisplayAutoPaused(msg)
    if @controlPlayer || $game_switches[:SpeedSkip_Password]
      @scene.pbDisplayMessage(msg)
    else
      @scene.pbDisplayPausedMessage(msg)
    end
  end

  def pbDisplayBrief(msg)
    @scene.pbDisplayMessage(msg, true)
  end

  def pbDisplayConfirm(msg)
    @scene.pbDisplayConfirmMessage(msg)
  end

  def pbShowCommands(msg, commands, cancancel = true)
    @scene.pbShowCommands(msg, commands, cancancel)
  end

  def pbAnimation(moveid, attacker, opponent, hitnum = 0)
    if @battlescene || moveid == :SUBSTITUTE
      @scene.pbAnimation(moveid, attacker, opponent, hitnum)
    end
  end

  def pbCommonAnimation(name, attacker = nil, opponent = nil, hitnum = 0)
    if @battlescene
      @scene.pbCommonAnimation(name, attacker, opponent, hitnum)
    end
  end

  def pbChangeBGSprite
    filename = @field.backdrop
    path = "Graphics/Battlebacks/battlebg" + filename + ".png"
    pbApplySceneBG("battlebg", path)
    path = "Graphics/Battlebacks/playerbase" + filename + ".png"
    path = "Graphics/Battlebacks/playerbaseDummy" if !pbResolveBitmap(sprintf(path))
    pbApplySceneBG("playerbase", path)
    path = "Graphics/Battlebacks/enemybase" + filename + ".png"
    path = "Graphics/Battlebacks/enemybaseDummy" if !pbResolveBitmap(sprintf(path))
    pbApplySceneBG("enemybase", path)
  end

  ################################################################################
  # Trainereffects (Rejuv Xen Mage style on entry effects cause by trainer)
  ################################################################################

  def runtrainerskills(pkmn, delay = false)
    party = @battle.pbParty(pkmn.index)
    monindex = party.index(pkmn.pokemon)
    trainer = pbPartyGetOwner(pkmn.index, monindex)
    return if trainer.nil?
    return if trainer.trainereffect.nil?
    return if trainer.trainereffect[:effectmode].nil?

    if !delay
      trainer.trainereffectused = [] if !trainer.trainereffectused && trainer.trainereffect[:buffactivation] == :Limited
      if trainer.trainereffect[:effectmode] == :Party
        monindex = monindex - 6 if monindex > 5 && @opponent.is_a?(Array)
        trainereffect = trainer.trainereffect[monindex]
        if trainer.trainereffect[:buffactivation] == :Limited
          return if trainer.trainereffectused.include?(monindex)

          trainer.trainereffectused.push(monindex)
        end
      # on god if someone tries to use Fainted effect mode on a Multibattle heads will roll
      elsif trainer.trainereffect[:effectmode] == :Fainted
        trainereffect = trainer.trainereffect[pkmn.pbFaintedPokemonCount]
        if trainer.trainereffect[:buffactivation] == :Limited
          return if trainer.trainereffectused.include?(pkmn.pbFaintedPokemonCount)

          trainer.trainereffectused.push(pkmn.pbFaintedPokemonCount)
        end
      end
    else
      trainereffect = trainer.trainerdelayedeffect
    end
    return if trainereffect.nil?

    if @opponent.is_a?(Array)
      if @opponent.include?(trainer)
        opponent = @opponent.index(trainer)
        @scene.pbShowOpponent(opponent)
        showtrainer = true
      end
    else
      if @opponent == trainer
        @scene.pbShowOpponent(0)
        showtrainer = true
      end
    end
    if trainereffect[:message] && trainereffect[:message] != ""
      if trainereffect[:message].is_a?(Array)
        for message in trainereffect[:message]
          pbDisplayAutoPaused(_INTL(message))
        end
      else
        pbDisplayAutoPaused(_INTL(trainereffect[:message]))
      end
    end
    if trainereffect[:animation]
      pbAnimation(trainereffect[:animation], pkmn, nil)
    end
    if trainereffect[:fieldChange] && trainereffect[:fieldChange][0] != @field.effect
      pbAnimation(:MAGICROOM, pkmn, nil)
      setField(trainereffect[:fieldChange][0], trainereffect[:fieldChange][2])
      fieldmessage = (trainereffect[:fieldChange][1] != "") ? trainereffect[:fieldChange][1] : "The field was changed!"
      pbDisplay(_INTL("{1}", fieldmessage))
    end
    if trainereffect[:typeChange]
      pkmn.type1 = trainereffect[:typeChange][0]
      pkmn.type2 = trainereffect[:typeChange][1] if trainereffect[:typeChange][1]
      typechangeMessage = trainereffect[:typeChangeMessage]
      pbDisplay(_INTL(typechangeMessage, pkmn.pbThis)) if typechangeMessage
    end
    trainereffect[:pokemonEffect].each_pair { |effect, effectval|
      pkmn.effects[effect] = effectval[0]
      pbAnimation(effectval[1], pkmn, nil) if !effectval[1].nil?
      effectmessage = effectval[2] != "" ? effectval[2] : "An effect was put up by {1}!"
      pbDisplay(_INTL(effectmessage, trainer.name, pkmn.pbThis(true)))
    } if trainereffect[:pokemonEffect]
    trainereffect[:opposingEffects].each_pair { |effect, effectval|
      if !pkmn.pbOpposing1.isFainted?
        pkmn.pbOpposing1.effects[effect] = effectval[0]
        pbAnimation(effectval[1], pkmn.pbOpposing1, nil) if !effectval[1].nil?
      end
      if !pkmn.pbOpposing2.isFainted?
        pkmn.pbOpposing2.effects[effect] = effectval[0]
        pbAnimation(effectval[1], pkmn.pbOpposing2, nil) if !effectval[1].nil?
      end
      effectmessage = effectval[2] != "" ? effectval[2] : "An effect was put up by {1}!"
      pbDisplay(_INTL(effectmessage, trainer.name, pkmn.pbThis(true)))
    } if trainereffect[:opposingEffects]
    trainereffect[:stateChanges].each_pair { |effect, effectval|
      @battle.state.effects[effect] = effectval[0]
      pbAnimation(effectval[1], pkmn, nil) if !effectval[1].nil?
      statemessage = effectval[2] != "" ? effectval[2] : "The state of the battle was changed!"
      pbDisplay(_INTL(statemessage, trainer.name))
    } if trainereffect[:stateChanges]
    side = pkmn.pbOwnSide
    trainereffect[:trainersideChanges].each_pair { |effect, effectval|
      side.effects[effect] = effectval[0]
      pbAnimation(effectval[1], pkmn, nil) if !effectval[1].nil?
      statemessage = effectval[2] != "" ? effectval[2] : "An effect was put up by {1}!"
      pbDisplay(_INTL(statemessage, trainer.name))
    } if trainereffect[:trainersideChanges]
    side = pkmn.pbOpposingSide
    trainereffect[:opposingsideChanges].each_pair { |effect, effectval|
      side.effects[effect] = effectval[0]
      pbAnimation(effectval[1], pkmn, nil) if !effectval[1].nil?
      statemessage = effectval[2] != "" ? effectval[2] : "An effect was put up by {1}!"
      pbDisplay(_INTL(statemessage, trainer.name))
    } if trainereffect[:opposingsideChanges]
    trainereffect[:pokemonStatChanges].each_pair { |stat, statval|
      statval *= -1 if pkmn.ability == :CONTRARY
      if statval > 0 && !pkmn.pbTooHigh?(stat, ignoreContrary: true)
        pkmn.pbIncreaseStatBasic(stat, statval)
        @battle.pbCommonAnimation("StatUp", pkmn) if !pkmn.statupanimplayed
        pkmn.statupanimplayed = true
        pbDisplay(_INTL("{1}'s {2} rose!", pkmn.pbThis, pkmn.pbGetStatName(stat)))
      elsif statval < 0 && !pkmn.pbTooLow?(stat, ignoreContrary: true)
        pkmn.pbReduceStatBasic(stat, -statval)
        @battle.pbCommonAnimation("StatDown", pkmn) if !pkmn.statdownanimplayed
        pkmn.statdownanimplayed = true
        pbDisplay(_INTL("{1}'s {2} fell!", pkmn.pbThis, pkmn.pbGetStatName(stat)))
      end
    } if trainereffect[:pokemonStatChanges]
    pkmn.statupanimplayed = false
    pkmn.statdownanimplayed = false
    trainereffect[:opposingSideStatChanges].each_pair { |stat, statval|
      for i in @battlers
        next if i.isFainted?
        next if !pkmn.pbIsOpposing?(i.index)

        statval *= -1 if i.ability == :CONTRARY
        if statval > 0 && !i.pbTooHigh?(stat, ignoreContrary: true)
          i.pbIncreaseStatBasic(stat, statval)
          @battle.pbCommonAnimation("StatUp", i) if !i.statupanimplayed
          i.statupanimplayed = true
          pbDisplay(_INTL("{1} boosted {2}'s {3}!", trainer.name, i.name, i.pbGetStatName(stat)))
        elsif statval < 0 && !i.pbTooLow?(stat, ignoreContrary: true)
          i.pbReduceStatBasic(stat, -statval)
          @battle.pbCommonAnimation("StatDown", i) if !i.statdownanimplayed
          i.statdownanimplayed = true
          pbDisplay(_INTL("{1} lowered {2}'s {3}!", trainer.name, i.name, i.pbGetStatName(stat)))
        end
        i.statupanimplayed = false
        i.statdownanimplayed = false
      end
    } if trainereffect[:opposingSideStatChanges]
    if trainereffect[:instantMove]
      pkmn.pbUseMoveSimple(trainereffect[:instantMove][0], -1, trainereffect[:instantMove][1], false, true)
    end
    if trainereffect[:reuseZMovePlayer]
      # @party1.zMove          = -1
      @battle.zMove[0][0] = -1
      for i in @battlers
        next if !pkmn.pbIsOpposing?(i.index) || i.hp <= 0

        i.zmoves = [nil, nil, nil, nil]
        for j in 0...4
          @battle.updateZMoveIndexBattler(j, i, true)
        end
        # mon gets a flag to allow it to use zmoves with it
        i.effects[:IgnoreZflag] = true
        pbCommonAnimation("ZPower", i, nil)
      end
    end
    if delay
      if trainereffect[:repeat]
        trainer.trainerdelaycounter = trainereffect[:delay]
      else
        trainer.trainerdelayedeffect = nil
        trainer.trainerdelaycounter = nil
      end
    end
    if trainereffect[:delayedaction]
      trainer.trainerdelayedeffect = trainereffect[:delayedaction]
      trainer.trainerdelaycounter = (trainereffect[:delayedaction][:delay])
    end
    @scene.pbHideOpponent if showtrainer
  end

  def delayedaction
    actionsrun = []
    for i in priority
      next if i.isFainted?

      party = @battle.pbParty(i.index)
      monindex = party.index(i.pokemon)
      trainer = pbPartyGetOwner(i.index, monindex)
      battler = i
      if battler.isbossmon
        next if !battler.bossdelayedeffect
        next if battler.bossdelaycounter.nil?

        battler.bossdelaycounter -= 1
        actionsrun.push(battler)
        if battler.bossdelaycounter == 0
          pbShieldEffects(battler, battler.bossdelayedeffect, false, true)
        end
      else
        next if !trainer
        next if trainer.trainerdelaycounter.nil?
        next if actionsrun.include?(trainer)

        trainer.trainerdelaycounter -= 1
        actionsrun.push(trainer)
        if trainer.trainerdelaycounter == 0
          runtrainerskills(battler, true)
        end
      end
    end
  end

  ################################################################################
  # Battle core.
  ################################################################################
  def pbStartBattle(canlose = false)
    if !@fullparty1 && @party1.length > MAXPARTYSIZE
      raise ArgumentError.new(_INTL("Party 1 has more than {1} Pokémon.", MAXPARTYSIZE))
    end
    if !@fullparty2 && @party2.length > MAXPARTYSIZE2
      raise ArgumentError.new(_INTL("Party 2 has more than {1} Pokémon.", MAXPARTYSIZE2))
    end

    #========================
    # Initialize AI in battle
    #========================
    @ai = pbInstantiateAI
    $ai_log_data = [PokeBattle_AI_Info.new, PokeBattle_AI_Info.new, PokeBattle_AI_Info.new, PokeBattle_AI_Info.new] unless isOnline?
    if !@opponent
      #========================
      # Initialize wild Pokémon
      #========================
      if @party2.length == 1
        wildpoke = @party2[0]
        @battlers[1].pbInitialize(wildpoke, 0, false)
        @peer.pbOnEnteringBattle(self, wildpoke)
        $Trainer.pokedex.setSeen(wildpoke)
        @scene.pbStartBattle(self)
        if !@battlers[1].isbossmon
          pbDisplayBrief(_INTL("A wild {1} appeared!", wildpoke.name))
        else
          if @battlers[1].entryText != nil
            pbDisplayPaused(_INTL(@battlers[1].entryText))
          else
            pbDisplayPaused(_INTL("A wild {1} appeared!", wildpoke.name))
          end
        end
      elsif @party2.length == 2
        @battlers[1].pbInitialize(@party2[0], 0, false)
        @battlers[3].pbInitialize(@party2[1], 0, false)

        @peer.pbOnEnteringBattle(self, @party2[0])
        @peer.pbOnEnteringBattle(self, @party2[1])
        $Trainer.pokedex.setSeen(@party2[0])
        $Trainer.pokedex.setSeen(@party2[1])
        @scene.pbStartBattle(self)
        pbDisplayBrief(_INTL("A wild {1} and\r\n{2} appeared!", @party2[0].name, @party2[1].name))
      else
        raise _INTL("Only one or two wild Pokémon are allowed")
      end
    elsif @doublebattle
      #=======================================
      # Initialize opponents in double battles
      #=======================================
      if @opponent.is_a?(Array)
        if @opponent.length == 1
          @opponent = @opponent[0]
        elsif @opponent.length != 2
          raise _INTL("Opponents with zero or more than two people are not allowed")
        end
      end
      if @player.is_a?(Array)
        if @player.length == 1
          @player = @player[0]
        elsif @player.length != 2
          raise _INTL("Player trainers with zero or more than two people are not allowed")
        end
      end
      @scene.pbStartBattle(self)
      if @opponent.is_a?(Array)
        pbDisplayAutoPaused(_INTL("{1} and {2} would like to battle!", @opponent[0].fullname, @opponent[1].fullname))
        sendout1 = pbFindNextUnfainted(@party2, 0, pbSecondPartyBegin(1))
        raise _INTL("Opponent 1 has no unfainted Pokémon") if sendout1 < 0

        sendout2 = pbFindNextUnfainted(@party2, pbSecondPartyBegin(1))
        raise _INTL("Opponent 2 has no unfainted Pokémon") if sendout2 < 0

        @battlers[1].pbInitialize(@party2[sendout1], sendout1, false)
        @battlers[3].pbInitialize(@party2[sendout2], sendout2, false)
        leadname = pbSwitchInName(1, sendout1) # Illusion
        pbDisplayBrief(_INTL("{1} sent\r\nout {2}!", @opponent[0].fullname, leadname))
        pbSendOut(1, @party2[sendout1])
        leadname = pbSwitchInName(3, sendout2) # Illusion
        pbDisplayBrief(_INTL("{1} sent\r\nout {2}!", @opponent[1].fullname, leadname))
        pbSendOut(3, @party2[sendout2])
      else
        pbDisplayAutoPaused(_INTL("{1}\r\nwould like to battle!", @opponent.fullname))
        sendout1 = pbFindNextUnfainted(@party2, 0)
        sendout2 = pbFindNextUnfainted(@party2, sendout1 + 1)
        if sendout1 < 0 || sendout2 < 0
          # raise _INTL("Opponent doesn't have two unfainted Pokémon")
          sendout2 = nil
          leadname = pbSwitchInName(1, sendout1) # Illusion
          pbDisplayBrief(_INTL("{1} sent\r\nout {2}!", @opponent.fullname, leadname))
          @battlers[1].pbInitialize(@party2[sendout1], sendout1, false)
          pbSendOut(1, @party2[sendout1])
        else
          @battlers[1].pbInitialize(@party2[sendout1], sendout1, false)
          @battlers[3].pbInitialize(@party2[sendout2], sendout2, false)
          leadname1 = pbSwitchInName(1, sendout1) # Illusion
          leadname2 = pbSwitchInName(3, sendout2) # Illusion
          pbDisplayBrief(_INTL("{1} sent\r\nout {2} and {3}!", @opponent.fullname, leadname1, leadname2))
          pbSendOut(1, @party2[sendout1])
          pbSendOut(3, @party2[sendout2])
        end
      end
    else
      #======================================
      # Initialize opponent in single battles
      #======================================
      sendout = pbFindNextUnfainted(@party2, 0)
      raise _INTL("Trainer has no unfainted Pokémon") if sendout < 0

      if @opponent.is_a?(Array)
        raise _INTL("Opponent trainer must be only one person in single battles") if @opponent.length != 1

        @opponent = @opponent[0]
      end
      if @player.is_a?(Array)
        raise _INTL("Player trainer must be only one person in single battles") if @player.length != 1

        @player = @player[0]
      end
      trainerpoke = @party2[sendout]
      @scene.pbStartBattle(self)
      pbDisplayAutoPaused(_INTL("{1}\r\nwould like to battle!", @opponent.fullname))

      @battlers[1].pbInitialize(trainerpoke, sendout, false)
      leadname = pbSwitchInName(1, sendout) # Illusion
      pbDisplayBrief(_INTL("{1} sent\r\nout {2}!", @opponent.fullname, leadname))

      pbSendOut(1, trainerpoke)
    end
    #=====================================
    # Initialize players in double battles
    #=====================================
    if @doublebattle
      if @player.is_a?(Array)
        sendout1 = pbFindNextUnfainted(@party1, 0, pbSecondPartyBegin(0))
        raise _INTL("Player 1 has no unfainted Pokémon") if sendout1 < 0

        sendout2 = pbFindNextUnfainted(@party1, pbSecondPartyBegin(0))
        raise _INTL("Player 2 has no unfainted Pokémon") if sendout2 < 0

        @battlers[0].pbInitialize(@party1[sendout1], sendout1, false)
        @battlers[2].pbInitialize(@party1[sendout2], sendout2, false)
        leadname1 = pbSwitchInName(0, sendout1) # Illusion
        leadname2 = pbSwitchInName(2, sendout2) # Illusion
        pbDisplayBrief(_INTL("{1} sent\r\nout {2}! Go! {3}!", @player[1].fullname, leadname2, leadname1))
        $Trainer.pokedex.setSeen(@party1[sendout1])
        $Trainer.pokedex.setSeen(@party1[sendout2])
      else
        sendout1 = pbFindNextUnfainted(@party1, 0)
        sendout2 = pbFindNextUnfainted(@party1, sendout1 + 1)
        @battlers[0].pbInitialize(@party1[sendout1], sendout1, false)
        @battlers[2].pbInitialize(@party1[sendout2], sendout2, false) unless sendout2 == -1
        if sendout2 > -1
          leadname1 = pbSwitchInName(0, sendout1) # Illusion
          leadname2 = pbSwitchInName(2, sendout2) # Illusion
          pbDisplayBrief(_INTL("Go! {1} and {2}!", leadname1, leadname2))
        else
          leadname = pbSwitchInName(0, sendout1) # Illusion
          pbDisplayBrief(_INTL("Go! {1}!", leadname))
        end
      end
      pbSendOut(0, @party1[sendout1])
      if @player.is_a?(Array)
        pbSendOut(2, @party1[sendout2], $cache.trainertypes[@player[1].trainertype].checkFlag?(:slideIn)) unless sendout2 == -1
      else
        pbSendOut(2, @party1[sendout2]) unless sendout2 == -1
      end
    else
      #====================================
      # Initialize player in single battles
      #====================================
      sendout = pbFindNextUnfainted(@party1, 0)
      if sendout < 0
        raise _INTL("Player has no unfainted Pokémon")
      end

      playerpoke = @party1[sendout]
      @battlers[0].pbInitialize(playerpoke, sendout, false)
      leadname = pbSwitchInName(0, sendout) # Illusion
      pbDisplayBrief(_INTL("Go! {1}!", leadname))
      pbSendOut(0, playerpoke)
    end
    #=======================================================
    # Keep track of who fainted in battle + piece assignment
    #=======================================================
    @fainted_mons = Array.new($Trainer.party.length) { |i| $Trainer.party[i].hp <= 0 }
    if @doublebattle
      if @player.is_a?(Array)
        pieceAssignment(pbPartySingleOwner(0), true)
        pieceAssignment(pbPartySingleOwner(2), true)
      else
        pieceAssignment(@party1, false)
      end
      if @opponent.is_a?(Array)
        pieceAssignment(pbPartySingleOwner(1), true)
        pieceAssignment(pbPartySingleOwner(3), true)
      else
        pieceAssignment(@party2, false)
      end
    else
      pieceAssignment(@party1, false)
      pieceAssignment(@party2, false)
    end

    #==================
    # Initialize battle
    #==================
    noWeather
    if @weather == :SUNNYDAY
      pbCommonAnimation("Sunny")
      pbDisplay(_INTL("The sunlight is strong."))
    elsif @weather == :RAINDANCE
      pbCommonAnimation("Rain")
      pbDisplay(_INTL("It is raining."))
    elsif @weather == :SANDSTORM
      pbCommonAnimation("Sandstorm")
      pbDisplay(_INTL("A sandstorm is raging."))
    elsif @weather == :HAIL
      pbCommonAnimation("Hail")
      pbDisplay(_INTL("Hail is falling."))
    elsif @weather == :STRONGWINDS
      pbCommonAnimation("Wind")
      pbDisplay(_INTL("The wind is strong."))
    elsif @weather == :SHADOWSKY
      pbCommonAnimation("ShadowSky")
      pbDisplay(_INTL("The sky is dark."))
    end
    # Field Effects BEGIN UPDATE
    if @field.introMessage
      fieldmessage = @field.introMessage
      fieldmessage = ["The dawn of a New World shines down upon the broken land."] if pbCheckGlobalAbility(:WORLDOFNIGHTMARES) && @field.effect == :STARLIGHT
      for i in 0...fieldmessage.length do
        pbDisplay(_INTL(fieldmessage[i]))
      end
      @state.effects[:Gravity] = -1 if @field.effect == :DEEPEARTH
      $game_variables[:Cave_Collapse] = 0
    end
    # END OF UPDATE
    priority = pbPriority
    if Rejuv
      for i in priority
        next if !i.isbossmon

        pbShieldEffects(i, i.onEntryEffects, true) if i.onEntryEffects
      end
    end
    seedCheck # Pre-surge seed check
    pbOnActiveAll # Abilities
    seedCheck # Post-surge seed check

    # Fix Charge, Laser Focus and Lock-On duration from seeds
    for i in priority
      i.effects[:LockOn] -= 1 if i.effects[:LockOn] > 0
      i.effects[:Charge] -= 1 if i.effects[:Charge] > 0
      i.effects[:LaserFocus] -= 1 if i.effects[:LaserFocus] > 0
    end

    @turncount = 1
    return pbBattleLoop(canlose)
  end

  def pbInstantiateAI # Overridden by tests
    return PokeBattle_AI.new(self)
  end

  def pbBattleLoop(canlose)
    if !isOnline? # for subclassing- online processing continues separately
      catch(:decision) do
        loop do # Now begin the battle loop
          pbRunTurn
        end
      end
      return pbEndOfBattle(canlose)
    end
  end

  def pbRunTurn
    fakeOutBattleEnd if Rejuv && @decision == 1
    throw(:decision) if @decision > 0

    PBDebug.log("************************** Round #{@turncount} *******************************") if $INTERNAL

    PBDebug.logonerr {
      pbCommandPhase
    }
    fakeOutBattleEnd if Rejuv && @decision == 1
    throw(:decision) if @decision > 0

    PBDebug.logonerr {
      @midturn = true
      pbAttackPhase()
      @midturn = false
    }
    fakeOutBattleEnd if Rejuv && @decision == 1
    throw(:decision) if @decision > 0

    PBDebug.logonerr {
      pbEndOfRoundPhase
    }
    fakeOutBattleEnd if Rejuv && @decision == 1
    throw(:decision) if @decision > 0

    @turncount += 1
  end

  ################################################################################
  # Command phase.
  ################################################################################
  def pbCommandMenu(i)
    return @scene.pbCommandMenu(i)
  end

  def pbItemMenu(i)
    return @scene.pbItemMenu(i)
  end

  def pbAutoFightMenu(i)
    return false
  end

  def pbCommandPhase(delay = true)
    pbAceMessage() if @ace_message && !@ace_message_handled && Reborn
    delayedaction if delay == true
    @scene.pbBeginCommandPhase
    @scene.pbResetCommandIndices if $Settings.remember_commands == 0
    tts("Battlers: ")
    for i in 0...4
      tts(pbPokemonString(battlers[i])) if !pbIsEnemy(i)
      tts(pbEnemyPokemonString(battlers[i])) if pbIsEnemy(i)
      break if !@doublebattle && i >= 1
    end
    for i in 0...4 # Reset choices if commands can be shown
      if pbCanShowCommands?(i) || @battlers[i].isFainted?
        @choices[i] = [nil]
      else
        battler = @battlers[i]
        unless !@doublebattle && pbIsDoubleBattler?(i)
          PBDebug.log("[reusing commands for #{battler.pbThis(true)}]") if $INTERNAL
        end
      end
    end
    for i in 0..3
      @switchedOut[i] = false
    end
    # Reset choices to perform Mega Evolution/Z-Moves/Ultra Burst if it wasn't done somehow
    for i in 0...@megaEvolution[0].length
      @megaEvolution[0][i] = -1 if @megaEvolution[0][i] >= 0
    end
    for i in 0...@megaEvolution[1].length
      @megaEvolution[1][i] = -1 if @megaEvolution[1][i] >= 0
    end
    for i in 0...@ultraBurst[0].length
      @ultraBurst[0][i] = -1 if @ultraBurst[0][i] >= 0
    end
    for i in 0...@ultraBurst[1].length
      @ultraBurst[1][i] = -1 if @ultraBurst[1][i] >= 0
    end
    for i in 0...@zMove[0].length
      @zMove[0][i] = -1 if @zMove[0][i] >= 0
    end
    for i in 0...@zMove[1].length
      @zMove[1][i] = -1 if @zMove[1][i] >= 0
    end
    pbJudge # juuuust in case we don't want to be here
    return if @decision > 0

    @commandphase = true
    for i in 0...4
      break if @decision != 0
      next if !@choices[i][0].nil?
      # AI CHANGES
      next if (!pbOwnedByPlayer?(i) && !(pbOwnedByAIPartner?(i) && $game_switches[:Control_Partners])) || @controlPlayer || @battlers[i].issossmon

      commandDone = false
      if pbCanShowCommands?(i)
        loop do
          cmd = pbCommandMenu(i)
          if cmd == 0 # Fight
            if pbCanShowFightMenu?(i)
              commandDone = true if pbAutoFightMenu(i)
              until commandDone
                index = @scene.pbFightMenu(i)
                if index < 0
                  side = pbIsOpposing?(i) ? 1 : 0
                  owner = pbGetOwnerIndex(i)
                  if @megaEvolution[side][owner] == i
                    @megaEvolution[side][owner] = -1
                  end
                  if @ultraBurst[side][owner] == i
                    @ultraBurst[side][owner] = -1
                  end
                  if @zMove[side][owner] == i
                    @zMove[side][owner] = -1
                  end
                  break
                end
                if !pbRegisterMove(i, index)
                  @zMove[0][0] = -1 if @zMove[0][0] >= 0
                  @zMove[1][0] = -1 if @zMove[1][0] >= 0
                  next
                end
                if @doublebattle
                  side = pbIsOpposing?(i) ? 1 : 0
                  owner = pbGetOwnerIndex(i)
                  basemove = @zMove[side][owner] == i ? @battlers[i].zmoves[index] : @battlers[i].moves[index]
                  target = @battlers[i].pbTarget(basemove)
                  if target == :SingleNonUser
                    target = @scene.pbChooseTarget(i)
                    if target < 0
                      @zMove[0][0] = -1 if @zMove[0][0] == i
                      @zMove[1][0] = -1 if @zMove[1][0] == i
                      next
                    end
                    pbRegisterTarget(i, target)
                  elsif [:SingleOpposing, :UserOrPartner].include?(target)
                    target = @scene.pbChooseTargetOneSide(i, target)
                    if target < 0
                      @zMove[0][0] = -1 if @zMove[0][0] == i
                      @zMove[1][0] = -1 if @zMove[1][0] == i
                      next
                    end
                    pbRegisterTarget(i, target)
                  end
                end
                commandDone = true
              end
            else
              commandDone = pbAutoChooseMove(i)
            end
          elsif cmd == 1 # Bag
            if !@internalbattle
              if pbOwnedByPlayer?(i)
                pbDisplay(_INTL("Items can't be used here."))
              end
            elsif @battlers[i].effects[:SkyDrop]
              pbDisplay(_INTL("Sky Drop won't let {1} go!", @battlers[i].name))
            else
              item = pbItemMenu(i)
              if item[0]
                if pbRegisterItem(i, item[0], item[1])
                  commandDone = true
                end
              end
            end
          elsif cmd == 2 # Pokémon
            pkmn = pbSwitchPlayer(i, false, true)
            if pkmn >= 0
              commandDone = true if pbRegisterSwitch(i, pkmn)
            end
          elsif cmd == 3   # Run
            run = pbRun(i)
            if run > 0
              commandDone = true
              return
            elsif run < 0
              commandDone = true
              side = pbIsOpposing?(i) ? 1 : 0
              owner = pbGetOwnerIndex(i)
              if @megaEvolution[side][owner] == i
                @megaEvolution[side][owner] = -1
              end
              if @ultraBurst[side][owner] == i
                @ultraBurst[side][owner] = -1
              end
              if @zMove[side][owner] == i
                @zMove[side][owner] = -1
              end
            end
          elsif cmd == 4   # Call
            @choices[i] = [:call]
            side = pbIsOpposing?(i) ? 1 : 0
            owner = pbGetOwnerIndex(i)
            if @megaEvolution[side][owner] == i
              @megaEvolution[side][owner] = -1
            end
            if @ultraBurst[side][owner] == i
              @ultraBurst[side][owner] = -1
            end
            if @zMove[side][owner] == i
              @zMove[side][owner] = -1
            end
            commandDone = true
          elsif cmd == -1 # Go back to first battler's choice
            @megaEvolution[0][0] = -1 if @megaEvolution[0][0] >= 0
            @megaEvolution[1][0] = -1 if @megaEvolution[1][0] >= 0
            @ultraBurst[0][0] = -1 if @ultraBurst[0][0] >= 0
            @ultraBurst[1][0] = -1 if @ultraBurst[1][0] >= 0
            @zMove[0][0] = -1 if @zMove[0][0] >= 0
            @zMove[1][0] = -1 if @zMove[1][0] >= 0
            # Restore the item the player's first Pokémon was due to use
            if @choices[0][0] == :item && $PokemonBag && $PokemonBag.pbCanStore?(@choices[0][1])
              $PokemonBag.pbStoreItem(@choices[0][1])
            end
            pbCommandPhase(false)
            return
          end
          break if commandDone
        end
      end
    end

    logPlayerChoices()
    @scene.pbChooseEnemyCommand if !isOnline?
    # AI Data collection perry
    for i in 0...4
      $ai_log_data[i].logAIScorings() if !isOnline? && @battlers[i].hp > 0 && (!pbOwnedByPlayer?(i) || @controlPlayer)
    end
    if $game_variables[:LuckShinies] != 0
      for battler in @battlers
        if self.pbIsWild? && battler.index.odd? && !battler.isFainted? && battler.pokemon.isShiny? && !battler.isbossmon && !battler.issossmon && !@decision == 4
          if pbRandom(100) < 10
            pbSEPlay("escape", 100)
            pbDisplay(_INTL("{1} fled!", battler.name))
            @decision = 3
            PBDebug.log("Wild Pokemon Escaped") if $INTERNAL
          end
        end
      end
    end
    @commandphase = false
  end

  def logPlayerChoices()
    PBDebug.log("")
    PBDebug.log("Player's choices:")
    logExtraAction(0)
    logExtraAction(1) if @player.is_a?(Array)
    logBattlerChoice(0)
    logBattlerChoice(2) if doublebattle
    PBDebug.log("")
  end

  def logExtraAction(ownerIndex)
    if @megaEvolution[0][ownerIndex] >= 0
      PBDebug.log(sprintf("%s: mega evolve", @battlers[@megaEvolution[0][ownerIndex]].name))
    end
    if @ultraBurst[0][ownerIndex] >= 0
      PBDebug.log(sprintf("%s: Ultra burst", @battlers[@ultraBurst[0][ownerIndex]].name))
    end
    if @zMove[0][ownerIndex] >= 0
      PBDebug.log(sprintf("%s: Z-move", @battlers[@zMove[0][ownerIndex]].name))
    end
  end

  def logBattlerChoice(battlerIndex)
    choice = @choices[battlerIndex]
    name = @battlers[battlerIndex].name
    case choice[0]
      when :move   then PBDebug.log(sprintf("%s: use %s against %s", name, choice[2] ? choice[2].name : "???", choice[3].is_a?(Integer) ? @battlers[choice[3]].name : ""))
      when :switch then PBDebug.log(sprintf("%s: switch to %s", name, pbPartySingleOwner(battlerIndex)[choice[1] % 6].name))
      when :item   then PBDebug.log(sprintf("%s: use item %s on %s", name, getItemName(choice[1]), pbPartySingleOwner(battlerIndex)[choice[2] % 6].name))
      when :call   then PBDebug.log(sprintf("%s: call", name))
      when :run    then PBDebug.log(sprintf("%s: run", name))
    end
  end

  def logSwitch(battlerIndex, partyIndex)
    PBDebug.log("")
    PBDebug.log("Player switch:")
    name = @battlers[battlerIndex].name
    PBDebug.log(sprintf("%s: switch to %s", name, pbPartySingleOwner(battlerIndex)[partyIndex % 6].name))
    PBDebug.log("")
  end

  ################################################################################
  # Attack phase.
  ################################################################################
  def pbAttackPhase
    @scene.pbBeginAttackPhase
    for i in 0...4
      if @choices[i][0] != :move && @choices[i][0] != :switch
        # @battlers[i].effects[:DestinyBond]=false # Effect gets removed on move use, NOT move choice
        @battlers[i].effects[:Grudge] = false
      end
      if !@battlers[i].isFainted?
        @battlers[i].turncount += 1
        @battlers[i].turncount += 1 if @battlers[i].ability == :SLOWSTART && @field.effect == :ELECTERRAIN
        @battlers[i].missAcc = false
      end
      @battlers[i].effects[:Rage] = false if @choices[i][0] != :move || @choices[i][2].move != :RAGE
      # @battlers[i].pbCustapBerry # Moved to later, timing was incorrect here
    end
    # Calculate priority at this time
    @usepriority = false
    priority = pbPriority
    # Call at Pokémon
    for i in priority
      pbCall(i.index) if @choices[i.index][0] == :call
    end
    # Switch out Pokémon
    @switching = true
    switched = []
    for i in priority
      if @choices[i.index][0] == :switch
        index = @choices[i.index][1] # party position of Pokémon to switch to
        self.lastMoveUser = i.index
        if !pbOwnedByPlayer?(i.index)
          owner = pbGetOwner(i.index)
          pbDisplayBrief(_INTL("{1} withdrew {2}!", owner.fullname, getMonName(i.species, i.form)))
        else
          pbDisplayBrief(_INTL("{1}, that's enough!\r\nCome back!", i.name))
        end
        for j in priority
          next if !i.pbIsOpposing?(j.index)

          # if Pursuit was chosen (regardless of target)
          if pbChoseMoveFunctionCode?(j.index, 0x88) && !j.effects[:Pursuit]
            newpoke = pbPursuitInterrupt(j, i, hardswitch: true)
            return if @decision > 0
          end
          break if i.isFainted?
        end
        if defined?(newpoke) && !newpoke.nil?
          index = newpoke
        end
        newpoke = nil
        if pbRecallAndReplace(i.index, index)
          switched.push(i.index)
        end
      end
    end
    if switched.length > 0
      for i in priority
        i.pbAbilitiesOnSwitchIn(true) if switched.include?(i.index)
      end
    end
    @switching = false
    for i in 0...4
      if !switched.include?(i)
        @battlers[i].pbCustapBerry
      end
    end
    # Use items
    for i in priority
      next unless @choices[i.index][0] == :item

      if !pbOwnedByPlayer?(i.index) && !(pbOwnedByAIPartner?(i.index) && $game_switches[:Control_Partners])
        pbEnemyUseItem(@choices[i.index][1], i)
        i.itemUsed = true
        i.itemUsed2 = true
      else
        # Player use item
        item = @choices[i.index][1]
        if item
          i.itemUsed = true
          i.itemUsed2 = true
          if !pbIsPokeBall?(item)
            if @choices[i.index][2] >= 0 && !$cache.items[item].checkFlag?(:battleitem)
              pbUseItemOnPokemon(item, @choices[i.index][2], i, @scene)
            elsif !ItemHandlers.hasUseInBattle(item)
              pbUseItemOnBattler(item, @choices[i.index][2], i, @scene)
            end
          end
        end
      end

      pbSendOutRevivedBattler(i, @choices[i.index][2])
    end
    # Mega Evolution
    for i in priority
      next if @choices[i.index][0] != :move

      side = pbIsOpposing?(i.index) ? 1 : 0
      owner = pbGetOwnerIndex(i.index)
      if @megaEvolution[side][owner] == i.index
        pbMegaEvolve(i.index)
      end
    end
    # Ultra Burst
    for i in priority
      next if @choices[i.index][0] != :move

      side = pbIsOpposing?(i.index) ? 1 : 0
      owner = pbGetOwnerIndex(i.index)
      if @ultraBurst[side][owner] == i.index
        pbUltraBurst(i.index)
      end
    end
    # Reuni crest type switch
    for i in priority
      next if @choices[i.index][0] != :move || @choices[i.index][1] < 0
      next if i.crested != :REUNICLUS

      protypes = [i.moves[@choices[i.index][1]].pbIsPhysical?(i), i.moves[@choices[i.index][1]].pbIsSpecial?(i)]
      if protypes[0] == true || protypes[1] == true
        protype = :FIGHTING if protypes[0] == true
        protype = :PSYCHIC if protypes[1] == true
        if !i.hasType?(protype) || (!i.type2.nil? && i.type1 != i.type2)
          i.type1 = protype
          i.type2 = nil
          if i.species == :REUNICLUS
            i.pbUpdate(false)
          end
          pbDisplay(_INTL("{1} had its type changed to {2}!", i.pbThis, protype.capitalize))
        end
      end
    end
    # Goth crest type switch
    for i in priority
      next if @choices[i.index][0] != :move || @choices[i.index][1] < 0
      next if i.crested != :GOTHITELLE

      protype = i.moves[@choices[i.index][1]].type
      next unless [:PSYCHIC, :DARK].include?(protype)

      if !i.hasType?(protype) || (!i.type2.nil? && i.type1 != i.type2)
        i.type1 = protype
        i.type2 = nil

        pbDisplay(_INTL("{1} had its type changed to {2}!", i.pbThis, protype.capitalize))
      end
    end
    priority = pbPriority(false, true) # Turn order recalc from Gen VII

    # move animations before main move processing
    for i in priority
      if pbChoseMoveFunctionCode?(i.index, 0x115) # Focus Punch
        pbCommonAnimation("FocusPunch", i, nil)
        pbDisplay(_INTL("{1} is tightening its focus!", i.pbThis))
      elsif pbChoseMoveFunctionCode?(i.index, 0x15D) # Beak Blast
        pbCommonAnimation("BeakBlast", i, nil)
        i.effects[:BeakBlast] = true
        pbDisplay(_INTL("{1} is heating up!", i.pbThis))
      elsif pbChoseMoveFunctionCode?(i.index, 0x16B) # Shell Trap
        pbCommonAnimation("ShellTrap", i, nil)
        i.effects[:ShellTrap] = true
        pbDisplay(_INTL("{1} set a shell trap!", i.pbThis))
      end
    end

    # Use attacks
    for i in 0...priority.length
      battler = priority[i]
      battler.pbProcessTurn(@choices[battler.index])

      if @state.effects[:Round]
        for j in (i + 1)...priority.length
          b = priority[j]
          if !b.hasMovedThisRound? && !@battle.switchedOut[b.index] && @choices[b.index][0] == :move && @choices[b.index][2].move == :ROUND
            pbMoveAfter(battler, b)
            break
          end
        end
      end

      # Shell Trap
      for ii in 0...4
        if !@battlers[ii].effects[:ShellTrapTarget].nil? && @battlers[ii].effects[:ShellTrapTarget] != -1 &&
           !@battlers[ii].effects[:ShellTrap]
          if pbChoseMoveFunctionCode?(ii, 0x16B)
            pbMoveAfter(battler, @battlers[ii])
          else # Via seed
            target = @battlers[ii].effects[:ShellTrapTarget]
            @battlers[ii].pbUseMoveSimple(:SHELLTRAP, -1, target, false)
            @battlers[ii].effects[:ShellTrapTarget] = -1
          end
        end
      end

      return if @decision > 0
    end
  end

  # Send out second battler in doubles after using a Revive if a battler slot is free.
  def pbSendOutRevivedBattler(battler, pkmnIndex)
    return unless @doublebattle && @battle.pbGetOwner(battler.index) == @battle.pbGetOwner(battler.pbPartner.index) && battler.pbPartner.isFainted?
    return if @sosbattle == 3
    return if pkmnIndex.nil? || battler.pokemonIndex == pkmnIndex

    mon = @party1[pkmnIndex]
    return if mon.nil? || mon.isEgg? || mon.hp <= 0

    @battle.pbMessagesOnReplace(battler.pbPartner.index, pkmnIndex)
    battler.pbPartner.pbResetForm
    @battle.pbReplace(battler.pbPartner.index, pkmnIndex)
    @battle.pbOnActiveOne(battler.pbPartner)
    battler.pbPartner.pbAbilitiesOnSwitchIn(true)
  end

  def pbPursuitInterrupt(pursuiter, switcher, hardswitch: false)
    newpoke = nil
    if pursuiter.status != :SLEEP && pursuiter.status != :FROZEN && !pursuiter.effects[:Truant]
      @switching = true
      # Try to Mega-evolve/Ultra-burst before using pursuit
      side = pbIsOpposing?(pursuiter.index) ? 1 : 0
      owner = pbGetOwnerIndex(pursuiter.index)
      if @megaEvolution[side][owner] == pursuiter.index
        pbMegaEvolve(pursuiter.index)
      end
      if @ultraBurst[side][owner] == pursuiter.index
        pbUltraBurst(pursuiter.index)
      end
      # Goth crest type switch
      if pursuiter.crested == :GOTHITELLE && pursuiter.moves[@choices[pursuiter.index][1]].type == :DARK
        protype = :DARK
        if !pursuiter.hasType?(protype)
          pursuiter.type1 = protype
          pursuiter.type2 = nil
          pbDisplay(_INTL("{1} had its type changed to {2}!", pbThis, protype.capitalize))
        end
      end
      # Change target to switcher and then use pursuit on it
      @choices[pursuiter.index][3] = switcher.index
      pursuiter.pbUseMove(@choices[pursuiter.index])
      pursuiter.effects[:Pursuit] = true
      # Send out new pokemon immediately if switcher faints and it was a hard switch
      if switcher.isFainted? && hardswitch
        newpoke = pbSwitchInBetween(switcher.index, false, false)
      end
      @switching = false
    end
    return newpoke
  end

  ################################################################################
  # End of round.
  ################################################################################
  def pbEndOfRoundPhase
    if @echoedThisRound
      @echoedVoice = [@echoedVoice + 1, 4].min
      @echoedThisRound = false
    else
      @echoedVoice = 0
    end
    for i in 0...4
      if @battlers[i].effects[:ShellTrap] && !pbChoseMoveFunctionCode?(i, 0x16B)
        pbDisplay(_INTL("{1}'s Shell Trap didn't work.", @battlers[i].name))
      end
    end
    for i in 0...4
      @battlers[i].forcedSwitchEarlier = false
      next if @battlers[i].hp <= 0

      @battlers[i].damagestate.reset
      @battlers[i].midwayThroughMove = false
      @battlers[i].forcedSwitchEarlier = false
      @battlers[i].effects[:Protect] = false
      @battlers[i].effects[:ProtectNegation] = false
      @battlers[i].effects[:Endure] = false
      @battlers[i].effects[:HyperBeam] -= 1 if @battlers[i].effects[:HyperBeam] > 0
      @battlers[i].effects[:BeakBlast] = false
      @battlers[i].effects[:ShellTrap] = false
      @battlers[i].effects[:ShellTrapTarget] = -1
      if (@field.effect == :BURNING || @field.effect == :VOLCANIC || @field.effect == :INFERNAL) && @battlers[i].effects[:BurnUp] # Burning/Volcanic Field
        @battlers[i].type1 = @battlers[i].pokemon.type1
        @battlers[i].type2 = @battlers[i].pokemon.type2
        @battlers[i].effects[:BurnUp] = false
      end
      @battlers[i].effects[:Powder] = false
      @battlers[i].effects[:MeFirst] = false
      @battlers[i].effects[:Jealousy] = false
      @battlers[i].effects[:LashOut] = false
      @battlers[i].effects[:HelpingHand] = false
      @battlers[i].effects[:MagicCoat] = false
      @battlers[i].effects[:QuickDrawSnipe] = false
      @battlers[i].effects[:ThroatChop] -= 1 if @battlers[i].effects[:ThroatChop] > 0
      @battlers[i].itemUsed = false
    end
    @state.effects[:IonDeluge] = false
    @state.effects[:Round] = false
    for i in 0...2
      sides[i].resetProtect
    end
    @usepriority = false # recalculate priority
    priority = pbPriority
    if @trickroom > 0
      @trickroom = @trickroom - 1 if @field.effect != :FROZENDIMENSION
      if @trickroom == 0
        pbDisplay(_INTL("The twisted dimensions returned to normal!"))
      end
    end
    if @state.effects[:WonderRoom] > 0
      @state.effects[:WonderRoom] -= 1 if @field.effect != :FROZENDIMENSION
      if @state.effects[:WonderRoom] == 0
        for i in @battlers
          if i.wonderroom
            i.pbSwapDefenses
          end
        end
        pbDisplay(_INTL("Wonder Room wore off, and the Defense and Sp. Def stats returned to normal!"))
      end
    end
    priority = pbPriority
    # Field Effects
    endmessage = false
    for i in priority
      next if i.isFainted?

      if i.crested == :VESPIQUEN
        mon = i
        if mon.effects[:VespiCrest] == false
          if mon.totalhp != mon.hp
            pbDisplay(_INTL("Vespiquen's swarm patched up her injuries!", i.pbThis)) if endmessage == false
            endmessage = true
            hpgain = (mon.totalhp / 16).floor
            hpgain = mon.pbRecoverHP(hpgain, true)
          end
        end
      end
    end
    for i in priority
      next if i.isFainted?

      case @field.effect
        when :ELECTERRAIN # Electric Terrain
          next if i.hp <= 0

          if i.ability == :VOLTABSORB && i.effects[:HealBlock] == 0 && Rejuv
            hpgain = (i.totalhp / 16.0).floor
            hpgain = i.pbRecoverHP(hpgain, true)
            pbDisplay(_INTL("{1} absorbed stray electricity!", i.pbThis)) if hpgain > 0
          end
        when :GRASSY # Grassy Field
          next if i.hp <= 0

          if !i.isAirborne? && i.effects[:HealBlock] == 0 && !PBStuff::TWOTURNMOVE.include?(i.effects[:TwoTurnAttack]) && i.totalhp != i.hp
            pbDisplay(_INTL("The grassy terrain healed the Pokémon on the field.", i.pbThis)) if !endmessage
            endmessage = true
            hpgain = (i.totalhp / 16.0).floor
            hpgain = i.pbRecoverHP(hpgain, true)
          end
          if i.ability == :SAPSIPPER && i.effects[:HealBlock] == 0
            hpgain = (i.totalhp / 16.0).floor
            hpgain = i.pbRecoverHP(hpgain, true)
            pbDisplay(_INTL("{1} drank tree sap to recover!", i.pbThis)) if hpgain > 0
          end
        when :BURNING, :VOLCANIC, :INFERNAL # Burning Field
          next if i.hp <= 0

          if i.ability == :FLASHFIRE
            if !i.effects[:FlashFire]
              i.effects[:FlashFire] = true
              pbDisplay(_INTL("{1}'s {2} raised its Fire power!", i.pbThis, getAbilityName(i.ability)))
            end
          end
          if i.burningFieldPassiveDamage?
            eff = PBTypes.twoTypeEff(:FIRE, i.type1, i.type2)
            if eff > 0
              @scene.pbDamageAnimation(i, 0)
              if [:LEAFGUARD, :ICEBODY, :FLUFFY, :GRASSPELT].include?(i.ability)
                eff = eff * 2
              end
              eff = eff * 2 if i.effects[:TarShot]
              pbDisplay(_INTL("The Pokémon were burned by the field!", i.pbThis)) if !endmessage
              endmessage = true
              i.pbReduceHP([(i.totalhp * eff / 32).floor, 1].max)
              if i.hp <= 0
                return if !i.pbFaint
              end
            end
          end
          if @field.effect == :INFERNAL
            if i.effects[:Torment] == true
              @scene.pbDamageAnimation(i, 0)
              i.pbReduceHP((i.totalhp / 8).floor)
              pbDisplay(_INTL("{1} is damaged by Torment!", i.pbThis))
            end
          end
        when :CORROSIVE # Corrosive Field
          next if i.hp <= 0

          if i.ability == :GRASSPELT
            @scene.pbDamageAnimation(i, 0)
            i.pbReduceHP((i.totalhp / 8.0).floor)
            pbDisplay(_INTL("{1}'s Pelt was corroded!", i.pbThis))
            if i.hp <= 0
              return if !i.pbFaint
            end
          end
        when :CORROSIVEMIST # Corrosive Mist Field
          if i.pbCanPoison?(false, true) && !@battle.pbCheckGlobalAbility(:NEUTRALIZINGGAS)
            pbDisplay(_INTL("The Pokémon were poisoned by the corrosive mist!", i.pbThis)) if !endmessage
            endmessage = true
            i.pbPoison(i)
          end
        when :FOREST # Forest Field
          next if i.hp <= 0

          if i.ability == :SAPSIPPER && i.effects[:HealBlock] == 0
            hpgain = (i.totalhp / 16.0).floor
            hpgain = i.pbRecoverHP(hpgain, true)
            pbDisplay(_INTL("{1} drank tree sap to recover!", i.pbThis)) if hpgain > 0
          end
        when :VOLCANICTOP
          eruptionChecker if @state.effects[:HarshSunlight]
          # eruption check - insane, too much, but makes typh op, so i no question
          next if i.hp <= 0

          if @eruption
            if i.hasType?(:FIRE) ||
               i.ability == :MAGMAARMOR || i.ability == :FLASHFIRE ||
               i.ability == :FLAREBOOST || i.ability == :BLAZE ||
               i.ability == :FLAMEBODY || i.ability == :SOLIDROCK ||
               i.ability == :STURDY || i.ability == :BATTLEARMOR ||
               i.ability == :SHELLARMOR || i.ability == :WATERBUBBLE ||
               i.ability == :MAGICGUARD || i.ability == :WONDERGUARD ||
               i.ability == :PRISMARMOR || i.effects[:AquaRing] ||
               i.pbOwnSide.effects[:WideGuard] || (i.pbOwnSide.effects[:AreniteWall] > 0)
              pbDisplay(_INTL("{1} is immune to the eruption!", i.pbThis))
            else
              eff = PBTypes.twoTypeEff(:FIRE, i.type1, i.type2)
              eff /= 2 if i.ability == :THICKFAT
              eff *= 2 if i.effects[:TarShot]
              @scene.pbDamageAnimation(i, 0)
              i.pbReduceHP([(i.totalhp * (eff / 32.0)).floor, 1].max)
              pbDisplay(_INTL("{1} is hurt by the eruption!", i.pbThis))
              if i.hp <= 0
                return if !i.pbFaint
              end
            end
            if i.ability == :MAGMAARMOR
              boost = false
              if !i.pbTooHigh?(PBStats::DEFENSE)
                i.pbIncreaseStatBasic(PBStats::DEFENSE, 1)
                pbCommonAnimation("StatUp", i, nil)
                boost = true
              end
              if !i.pbTooHigh?(PBStats::SPDEF)
                i.pbIncreaseStatBasic(PBStats::SPDEF, 1)
                pbCommonAnimation("StatUp", i, nil)
                boost = true
              end
              if boost
                pbDisplay(_INTL("{1}'s Magma Armor raised its defenses!", i.pbThis))
              end
            end
            if i.ability == :FLAREBOOST
              if !i.pbTooHigh?(PBStats::SPATK)
                i.pbIncreaseStatBasic(PBStats::SPATK, 1)
                pbCommonAnimation("StatUp", i, nil)
                pbDisplay(_INTL("{1}'s Flare Boost raised its Sp. Attack!", i.pbThis))
              end
            end
            if i.ability == :FLASHFIRE
              if !i.effects[:FlashFire]
                i.effects[:FlashFire] = true
                pbDisplay(_INTL("{1}'s {2} raised its Fire power!", i.pbThis, getAbilityName(i.ability)))
              end
            end
            if i.ability == :BLAZE
              if !i.effects[:Blazed]
                i.effects[:Blazed] = true
                pbDisplay(_INTL("{1}'s {2} raised its Fire power!", i.pbThis, getAbilityName(i.ability)))
              end
            end
            if i.status == :SLEEP && i.ability != :SOUNDPROOF
              i.pbCureStatus
              pbDisplay(_INTL("{1} woke up due to the eruption!", i.pbThis))
            end
            if i.effects[:LeechSeed] >= 0
              i.effects[:LeechSeed] = -1
              pbDisplay(_INTL("{1}'s Leech Seed burned away in the eruption!", i.pbThis))
            end
          end
        # eruption check - insane, too much, but makes typh op, so i no question
        when :SHORTCIRCUIT # Shortcircuit Field
          next if i.hp <= 0

          if i.ability == :VOLTABSORB && i.effects[:HealBlock] == 0
            hpgain = (i.totalhp / 16.0).floor
            hpgain = i.pbRecoverHP(hpgain, true)
            pbDisplay(_INTL("{1} absorbed stray electricity!", i.pbThis)) if hpgain > 0
          end
        when :WATERSURFACE # Water Surface
          next if i.hp <= 0

          if (i.ability == :WATERABSORB || i.ability == :DRYSKIN) && i.effects[:HealBlock] == 0 && !i.isAirborne?
            hpgain = (i.totalhp / 16.0).floor
            hpgain = i.pbRecoverHP(hpgain, true)
            pbDisplay(_INTL("{1} absorbed some of the water!", i.pbThis)) if hpgain > 0
          end
          if i.effects[:TarShot] == true
            i.effects[:TarShot] = false
            pbDisplay(_INTL("The tar washed off {1} in the water!", i.pbThis))
          end
        when :UNDERWATER
          next if i.hp <= 0

          if i.effects[:TarShot] == true
            i.effects[:TarShot] = false
            pbDisplay(_INTL("The tar washed off {1} in the water!", i.pbThis))
          end
          if (i.ability == :WATERABSORB || i.ability == :DRYSKIN) && i.effects[:HealBlock] == 0
            hpgain = (i.totalhp / 16.0).floor
            hpgain = i.pbRecoverHP(hpgain, true)
            pbDisplay(_INTL("{1} absorbed some of the water!", i.pbThis)) if hpgain > 0
          end
          if i.underwaterFieldPassiveDamamge?
            eff = PBTypes.twoTypeEff(:WATER, i.type1, i.type2)
            if eff > 4
              @scene.pbDamageAnimation(i, 0)
              if i.ability == :FLAMEBODY || i.ability == :MAGMAARMOR
                eff = eff * 2
              end
              i.pbReduceHP([(i.totalhp * eff / 32).floor, 1].max)
              pbDisplay(_INTL("{1} struggled in the water!", i.pbThis))
              if i.hp <= 0
                return if !i.pbFaint
              end
            end
          end
        when :MURKWATERSURFACE # Murkwater Surface
          if i.murkyWaterSurfacePassiveDamage?
            eff = PBTypes.twoTypeEff(:POISON, i.type1, i.type2)
            if i.ability == :FLAMEBODY || i.ability == :MAGMAARMOR || i.ability == :DRYSKIN || i.ability == :WATERABSORB
              eff = eff * 2
            end
            if !$cache.moves[i.effects[:TwoTurnAttack]].nil? &&
               $cache.moves[i.effects[:TwoTurnAttack]].function == 0xCB # Dive
              @scene.pbDamageAnimation(i, 0)
              i.pbReduceHP([(i.totalhp * eff / 8).floor, 1].max)
              pbDisplay(_INTL("{1} suffocated underneath the toxic water!", i.pbThis))
            elsif !i.isAirborne?
              @scene.pbDamageAnimation(i, 0)
              i.pbReduceHP([(i.totalhp * eff / 32).floor, 1].max)
              pbDisplay(_INTL("{1} is hurt by the toxic water!", i.pbThis))
            end
          end
          if i.isFainted?
            return if !i.pbFaint
          end
          if (i.hasType?(:POISON) && (i.ability == :DRYSKIN || i.ability == :WATERABSORB)) && !i.isAirborne? && i.effects[:HealBlock] == 0 && i.hp < i.totalhp
            pbCommonAnimation("Poison", i, nil)
            i.pbRecoverHP((i.totalhp / 8.0).floor, true)
            pbDisplay(_INTL("{1} is healed by the poisoned water!", i.pbThis))
          end
        when :DIMENSIONAL # Dimension Field (Rejuv)
          if i.effects[:HealBlock] != 0
            @scene.pbDamageAnimation(i, 0)
            i.pbReduceHP((i.totalhp / 16).floor)
            pbDisplay(_INTL("{1} is damaged by the Heal Block!", i.pbThis))
            if i.hp <= 0
              return if !i.pbFaint
            end
          end
        when :CORRUPTED # Corrupted Cave Field (Rejuv)
          next if i.hp <= 0

          if i.ability == :GRASSPELT || i.ability == :LEAFGUARD || i.ability == :FLOWERVEIL
            @scene.pbDamageAnimation(i, 0)
            i.pbReduceHP((i.totalhp / 8).floor)
            pbDisplay(_INTL("{1}'s foliage caused harm!", i.pbThis))
            if i.hp <= 0
              return if !i.pbFaint
            end
          end
          if !i.isAirborne? && !i.hasType?(:POISON) && i.ability != :WONDERSKIN && i.ability != :IMMUNITY && i.ability != :PASTELVEIL
            if i.pbCanPoison?(false, true)
              pbDisplay(_INTL("{1} was poisoned!", i.pbThis)) if endmessage == false
              endmessage = true
              i.pbPoison(i)
            end
          end
        when :BEWITCHED # Bewitched Woods (Rejuv)
          next if i.hp <= 0

          if !i.isAirborne? && i.hasType?(:GRASS) && i.effects[:HealBlock] == 0 && i.totalhp != i.hp
            pbDisplay(_INTL("The woods healed the grass Pokemon on the field.", i.pbThis)) if !endmessage
            endmessage = true
            hpgain = (i.totalhp / 16.0).floor
            hpgain = i.pbRecoverHP(hpgain, true)
          end
          if i.ability == :NATURALCURE
            i.status = nil
          end
      end
      if @state.effects[:ELECTERRAIN] > 0
        next if i.hp <= 0

        if i.ability == :VOLTABSORB && i.effects[:HealBlock] == 0
          hpgain = (i.totalhp / 16.0).floor
          hpgain = i.pbRecoverHP(hpgain, true)
          pbDisplay(_INTL("{1} absorbed stray electricity!", i.pbThis)) if hpgain > 0
        end
      end
      if @state.effects[:GRASSY] > 0
        next if i.hp <= 0

        if !i.isAirborne? && i.effects[:HealBlock] == 0 && !PBStuff::TWOTURNMOVE.include?(i.effects[:TwoTurnAttack]) && i.totalhp != i.hp
          pbDisplay(_INTL("The grassy terrain healed the Pokémon on the field.", i.pbThis)) if !endmessage
          endmessage = true
          hpgain = (i.totalhp / 16.0).floor
          hpgain = i.pbRecoverHP(hpgain, true)
        end
        if i.ability == :SAPSIPPER && i.effects[:HealBlock] == 0
          hpgain = (i.totalhp / 16.0).floor
          hpgain = i.pbRecoverHP(hpgain, true)
          pbDisplay(_INTL("{1} drank tree sap to recover!", i.pbThis)) if hpgain > 0
        end
      end
    end
    # eruption check 2 (having the hazard removal in the main loop above causes the messaging to malfunction)
    if @field.effect == :VOLCANICTOP
      if @eruption
        hazardsOnSide = false
        for i in priority
          if i.pbOwnSide.effects[:Spikes] > 0
            i.pbOwnSide.effects[:Spikes] = 0
            hazardsOnSide = true
          end
          if i.pbOwnSide.effects[:ToxicSpikes] > 0
            i.pbOwnSide.effects[:ToxicSpikes] = 0
            hazardsOnSide = true
          end
          if i.pbOwnSide.effects[:StealthRock]
            i.pbOwnSide.effects[:StealthRock] = false
            hazardsOnSide = true
          end
          if i.pbOwnSide.effects[:StickyWeb]
            i.pbOwnSide.effects[:StickyWeb] = false
            hazardsOnSide = true
          end
        end
        if hazardsOnSide
          pbDisplay(_INTL("The eruption removed all hazards from the field!"))
        end
      end
    end
    # End Field stuff
    # Weather
    # Unsure what this is really doing, cass thinks it's probably nothing. But just in case ?? ~a
    # if @field.effect != :UNDERWATER
    #  @field.counter = 0 if @weather != :HAIL && @field.effect == :MOUNTAIN
    # end
    for i in priority
      if i.ability == :TEMPEST
        weathers = pbRandom(5)
        rainbowhold = 0
        case weathers
          when 0
            if @weather == :SUNNYDAY
              rainbowhold = 8
            end
            @weather = :RAINDANCE
            @weatherduration = 8
            pbCommonAnimation("Rain", nil, nil)
            pbDisplay(_INTL("Storm-9 created a downpour!"))
            if rainbowhold != 0
              fieldbefore = @field.effect
              setField(:RAINBOW, rainbowhold)
              if fieldbefore != :RAINBOW
                pbDisplay(_INTL("The weather created a rainbow!"))
              else
                pbDisplay(_INTL("The weather refreshed the rainbow!"))
              end
            end
          when 1
            @weather = :HAIL
            @weatherduration = 8
            pbCommonAnimation("Hail", nil, nil)
            pbDisplay(_INTL("Storm-9 brought hailfall!"))
            for facemon in @battlers
              if facemon.species == :EISCUE && facemon.ability == :ICEFACE && facemon.form == 1 # Eiscue
                facemon.pbRegenFace
                pbDisplay(_INTL("{1} transformed!", facemon.name))
              end
            end
          when 2
            @weather = :SANDSTORM
            @weatherduration = 8
            pbCommonAnimation("Sandstorm", nil, nil)
            pbDisplay(_INTL("Storm-9 whipped up a duststorm!"))
          when 3
            @weather = :STRONGWINDS
            @weatherduration = 8
            pbCommonAnimation("Wind", nil, nil)
            pbDisplay(_INTL("Storm-9 whipped up terrible winds!"))
          when 4
            @weather = :SHADOWSKY
            @weatherduration = 8
            pbCommonAnimation("ShadowSky", nil, nil)
            pbDisplay(_INTL("Storm-9 shrouded the sky in a dark aura..."))
        end
      end
    end
    if @storm9 && !pbCheckGlobalAbility(:TEMPEST)
      @storm9 = false
      noWeather
    end
    case @weather
      when :SUNNYDAY
        @weatherduration = @weatherduration - 1 if @weatherduration > 0
        if @weatherduration == 0
          pbDisplay(_INTL("The sunlight faded."))
          pbDisplay(_INTL("The starry sky shone through!")) if @field.effect == :STARLIGHT
          @weather = 0
          persistentWeather
        else
          pbCommonAnimation("Sunny")
          if @field.effect == :DARKCRYSTALCAVERN # Dark Crystal Cavern
            duration = @weatherduration + 1
            setField(:CRYSTALCAVERN, duration)
            @field.duration_condition = proc { |battle| battle.weather == :SUNNYDAY }
            @field.permanent_condition = proc { |battle| battle.FE != :CRYSTALCAVERN }
            pbDisplay(_INTL("The sun lit up the crystal cavern!"))
          end
          if pbWeather == :SUNNYDAY
            for i in priority
              next if i.isFainted?

              if (i.ability == :SOLARPOWER || (i.crested == :CASTFORM && i.form == 1)) && @field.effect != :FROZENDIMENSION
                pbDisplay(_INTL("{1} was hurt by the sunlight!", i.pbThis))
                @scene.pbDamageAnimation(i, 0)
                i.pbReduceHP((i.totalhp / 8.0).floor)
                if i.isFainted?
                  return if !i.pbFaint
                end
              end
              if Rejuv && @field.effect == :DESERT && (i.hasType?(:GRASS) || i.hasType?(:WATER)) && !(i.ability == :SOLARPOWER || i.ability == :CHLOROPHYLL)
                pbDisplay(_INTL("{1} was hurt by the sunlight!", i.pbThis))
                @scene.pbDamageAnimation(i, 0)
                i.pbReduceHP((i.totalhp / 8.0).floor)
                if i.isFainted?
                  return if !i.pbFaint
                end
              end
            end
          end
        end
      when :RAINDANCE
        @weatherduration = @weatherduration - 1 if @weatherduration > 0
        if @weatherduration == 0
          pbDisplay(_INTL("The rain stopped."))
          pbDisplay(_INTL("The starry sky shone through!")) if @field.effect == :STARLIGHT
          @weather = 0
          persistentWeather
        else
          pbCommonAnimation("Rain")
          if @field.effect == :BURNING
            breakField
            pbDisplay(_INTL("The rain snuffed out the flame!"))
          end
          if @field.effect == :VOLCANIC
            setField(:CAVE)
            pbDisplay(_INTL("The rain snuffed out the flame!"))
          end
        end
      when :SANDSTORM
        @weatherduration = @weatherduration - 1 if @weatherduration > 0
        if @weatherduration == 0
          pbDisplay(_INTL("The sandstorm subsided."))
          pbDisplay(_INTL("The starry sky shone through!")) if @field.effect == :STARLIGHT
          @weather = 0
          persistentWeather
        else
          pbCommonAnimation("Sandstorm")
          if @field.effect == :BURNING
            breakField
            pbDisplay(_INTL("The sand snuffed out the flame!"))
          end
          if @field.effect == :VOLCANIC
            setField(:CAVE)
            pbDisplay(_INTL("The sand snuffed out the flame!"))
          end
          if @field.effect == :RAINBOW
            breakField if @field.duration == 0
            endTempField if @field.duration > 0
            pbDisplay(_INTL("The weather blocked out the rainbow!"))
          end
          if pbWeather == :SANDSTORM
            endmessage = false
            reductions = []
            for i in priority
              next if i.isFainted?

              if (!i.hasType?(:GROUND) && !i.hasType?(:ROCK) && !i.hasType?(:STEEL) && i.item != :SAFETYGOGGLES &&
                 ![:SANDVEIL, :SANDRUSH, :SANDFORCE, :MAGICGUARD, :TEMPEST, :OVERCOAT].include?(i.ability) &&
                 !(i.ability == :WONDERGUARD && @field.effect == :COLOSSEUM) &&
                 ($cache.moves[i.effects[:TwoTurnAttack]].nil? || ![0xCA, 0xCB].include?($cache.moves[i.effects[:TwoTurnAttack]].function))) || # Dig, Dive
                 (i.effects[:DesertsMark] && i.ability != :MAGICGUARD) # Desert's mark sand immunity negation
                pbDisplay(_INTL("The Pokémon were buffeted by the sandstorm!", i.pbThis)) if !endmessage
                endmessage = true
                @scene.pbDamageAnimation(i, 0, quick: true)
                if Rejuv && @field.effect == :DESERT
                  reductions.push [i, (i.totalhp / 8.0).floor]
                else
                  reductions.push [i, (i.totalhp / 16.0).floor]
                end
              end
            end
            pbReduceBattlersHP(reductions)
          end
        end
      when :HAIL
        @weatherduration = @weatherduration - 1 if @weatherduration > 0
        if @weatherduration == 0
          pbDisplay(_INTL("The hail stopped."))
          pbDisplay(_INTL("The starry sky shone through!")) if @field.effect == :STARLIGHT
          @weather = 0
          persistentWeather
        else
          pbCommonAnimation("Hail")
          if @field.effect == :RAINBOW
            breakField if @field.duration == 0
            endTempField if @field.duration > 0
            pbDisplay(_INTL("The weather blocked out the rainbow!"))
          end
          if pbWeather == :HAIL
            endmessage = false
            reductions = []
            for i in priority
              next if i.isFainted?

              if !i.hasType?(:ICE) && i.item != :SAFETYGOGGLES &&
                 ![:TEMPEST, :ICEBODY, :SNOWCLOAK, :SLUSHRUSH, :LUNARIDOL, :MAGICGUARD, :OVERCOAT].include?(i.ability) &&
                 i.crested != :EMPOLEON && !(i.crested == :CASTFORM && i.form == 3) && !(i.ability == :WONDERGUARD && @battle.FE == :COLOSSEUM) &&
                 ($cache.moves[i.effects[:TwoTurnAttack]].nil? || ![0xCA, 0xCB].include?($cache.moves[i.effects[:TwoTurnAttack]].function)) # Dig, Dive
                pbDisplay(_INTL("The Pokémon were buffeted by the hail!", i.pbThis)) if !endmessage
                endmessage = true
                @scene.pbDamageAnimation(i, 0, quick: true)
                if @field.effect == :FROZENDIMENSION
                  reductions.push [i, (i.totalhp / 8.0).floor]
                else
                  reductions.push [i, (i.totalhp / 16.0).floor]
                end
              end
            end
            pbReduceBattlersHP(reductions)
            if @field.effect == :MOUNTAIN
              @field.counter += 1
              if @field.counter == 3
                setField(:SNOWYMOUNTAIN)
                pbDisplay(_INTL("The mountain was covered in snow!"))
              end
            end
          end
        end
      when :STRONGWINDS
        @weatherduration = @weatherduration - 1 if @weatherduration > 0
        if @weatherduration == 0
          pbDisplay(_INTL("The strong wind petered out."))
          @weather = 0
          persistentWeather
        else
          pbCommonAnimation("Wind")
        end
      when :SHADOWSKY
        @weatherduration = @weatherduration - 1 if @weatherduration > 0
        if @weatherduration == 0
          pbDisplay(_INTL("The shadow sky faded."))
          pbDisplay(_INTL("The starry sky shone through!")) if @field.effect == :STARLIGHT
          @weather = 0
          persistentWeather
        else
          pbCommonAnimation("ShadowSky")
          if @weather == :SHADOWSKY
            endmessage = false
            reductions = []
            for i in priority
              next if i.isFainted?

              if !i.isShadow? && i.item != :SAFETYGOGGLES &&
                 ![:TEMPEST, :MAGICGUARD, :OVERCOAT].include?(i.ability) &&
                 !(i.ability == :WONDERGUARD && @battle.FE == :COLOSSEUM) &&
                 ($cache.moves[i.effects[:TwoTurnAttack]].nil? || ![0xCA, 0xCB].include?($cache.moves[i.effects[:TwoTurnAttack]].function)) # Dig, Dive
                pbDisplay(_INTL("The Pokémon were hurt by the shadow sky!", i.pbThis)) if !endmessage
                endmessage = true
                @scene.pbDamageAnimation(i, 0, quick: true)
                if @field.effect == :DIMENSIONAL || @field.effect == :FROZENDIMENSION
                  reductions.push [i, (i.totalhp / 8.0).floor]
                else
                  reductions.push [i, (i.totalhp / 16.0).floor]
                end
              end
            end
            pbReduceBattlersHP(reductions)
          end
        end
    end
    # Temporal Shift
    for i in priority
      next if i.isFainted?

      if i.ability == :TEMPORALSHIFT
        for j in priority
          next if j.isFainted?

          if !(i == j || i.pbPartner == j || j.hasType?(:NORMAL)) && j.effects[:FutureSight] == 0
            j.effects[:FutureSight] = 3
            j.effects[:FutureSightMove] = :HEX
            j.effects[:FutureSightUser] = i.index
            j.effects[:FutureSightPokemonIndex] = i.pokemonIndex
            pbDisplay(_INTL("{1} casts a hex!", i.pbThis))
            break
          end
        end
      end
    end
    # Future Sight/Doom Desire
    for i in battlers # not priority
      next if i.effects[:FutureSight] <= 0

      i.effects[:FutureSight] -= 1
      next if i.isFainted? || i.effects[:FutureSight] != 0

      moveuser = nil
      # check if battler on the field
      move, moveuser, disabled_items = i.pbFutureSightUserPlusMove
      type = move.pbType(moveuser)
      pbDisplay(_INTL("{1} took the {2} attack!", i.pbThis, move.name))
      typemod = move.pbTypeModifier(type, moveuser, i)
      typemod = move.irregularTypeMods(moveuser, i, typemod, type)
      typemod = move.fieldTypeChange(moveuser, i, typemod)
      typemod = move.overlayTypeChange(moveuser, i, typemod, false)
      twoturninvul = PBStuff::TWOTURNMOVE.include?(i.effects[:TwoTurnAttack])
      if (i.isFainted? || move.pbAccuracyCheck(moveuser, i) && !(i.ability == :WONDERGUARD && typemod <= 4)) && !twoturninvul
        i.damagestate.reset
        damage = nil
        if i.effects[:FutureSightMove] == :FUTURESIGHT && !i.hasType?(:DARK)
          moveuser.hp != 0 ? pbAnimation(:FUTUREDUMMY, moveuser, i) : pbAnimation(:FUTUREDUMMY, i, i)
        elsif i.effects[:FutureSightMove] == :DOOMDESIRE
          moveuser.hp != 0 ? pbAnimation(:DOOMDUMMY, moveuser, i) : pbAnimation(:DOOMDUMMY, i, i)
        elsif i.effects[:FutureSightMove] == :HEX && !i.hasType?(:NORMAL)
          moveuser.hp != 0 ? pbAnimation(:HEXDUMMY, moveuser, i) : pbAnimation(:HEXDUMMY, i, i)
        end
        move.pbReduceHPDamage(damage, moveuser, i)
        move.pbEffectMessages(moveuser, i)
      elsif i.ability == :WONDERGUARD && typemod <= 4 && !twoturninvul
        pbDisplay(_INTL("{1} avoided damage with Wonder Guard!", i.pbThis))
      else
        pbDisplay(_INTL("But it failed!"))
      end
      i.effects[:FutureSight] = 0
      i.effects[:FutureSightMove] = 0
      i.effects[:FutureSightUser] = -1
      i.effects[:FutureSightPokemonIndex] = -1
      if !disabled_items.empty?
        moveuser.item = disabled_items[:item]
        moveuser.ability = disabled_items[:ability]
      end
      if i.isFainted?
        return if !i.pbFaint

        next
      end
    end
    for i in priority
      next if !i.isbossmon
      next if i.isFainted?

      if i.chargeAttack
        next if i.status == :SLEEP || i.status == :FROZEN

        chargeAttack = i.chargeAttack
        if i.turncount % chargeAttack[:turns] == 0
          if i.chargeTurns? == false && i.turncount % chargeAttack[:turns] == 0
            for m in @party1
              m.status = :FAINTED
              m.hp = 0
            end
            pbDisplay(_INTL("{1} unleashed it's power!", i.pbThis))
            pbAnimation(:EXPLOSION, i, i)
            for j in priority
              next if j.isFainted?
              next if j.isbossmon

              j.pbReduceHP(j.hp, true)
              j.pbFaint if j.isFainted?
            end
            @decision = 2
            return
          end
        else
          if chargeAttack[:intermediateattack]
            if chargeAttack[:canIntermediateAttack] == true
              newmove = PokeBattle_BossMove.new(self, i.pokemon, chargeAttack[:intermediateattack])
              i.pbUseMoveSimpleBoss(newmove, -1)
            else
              chargeAttack[:canIntermediateAttack] = true
            end
          end
        end
      end
    end
    for i in priority
      next if i.isFainted?

      # Meganium + Meganium Crest
      if i.crested == :MEGANIUM || (i.pbPartner.crested == :MEGANIUM && !i.pbPartner.isFainted?)
        hpgain = i.pbRecoverHP((i.totalhp / 16).floor, true)
        pbDisplay(_INTL("The Meganium Crest restored {1}'s HP a little!", i.pbThis(true))) if hpgain > 0
      end
      # Rain Dish
      if ((i.ability == :RAINDISH || (i.crested == :CASTFORM && i.form == 2)) && (pbWeather == :RAINDANCE && !i.hasWorkingItem(:UTILITYUMBRELLA))) && i.effects[:HealBlock] == 0
        hpgain = i.pbRecoverHP((i.totalhp / 16.0).floor, true)
        pbDisplay(_INTL("{1}'s Rain Dish restored its HP a little!", i.pbThis)) if hpgain > 0
      end

      # Dry Skin
      if i.ability == :DRYSKIN
        if pbWeather == :RAINDANCE
          if !i.hasWorkingItem(:UTILITYUMBRELLA) && i.effects[:HealBlock] == 0
            hpgain = i.pbRecoverHP((i.totalhp / 8.0).floor, true)
            pbDisplay(_INTL("{1}'s Dry Skin was healed by the rain!", i.pbThis)) if hpgain > 0
          end
        elsif pbWeather == :SUNNYDAY
          if !i.hasWorkingItem(:UTILITYUMBRELLA)
            @scene.pbDamageAnimation(i, 0)
            hploss = i.pbReduceHP((i.totalhp / 8.0).floor)
            pbDisplay(_INTL("{1}'s Dry Skin was hurt by the sunlight!", i.pbThis)) if hploss > 0
          end
        elsif @field.effect == :CORROSIVEMIST || @field.effect == :CORRUPTED
          if !i.hasType?(:STEEL)
            if !i.hasType?(:POISON)
              @scene.pbDamageAnimation(i, 0)
              hploss = i.pbReduceHP((i.totalhp / 8.0).floor)
              pbDisplay(_INTL("{1}'s Dry Skin absorbed the poison!", i.pbThis)) if hploss > 0
            elsif i.effects[:HealBlock] == 0
              hpgain = i.pbRecoverHP((i.totalhp / 8.0).floor, true)
              pbDisplay(_INTL("{1}'s Dry Skin was healed by the poison!", i.pbThis)) if hpgain > 0
            end
          end
        elsif @field.effect == :DESERT
          @scene.pbDamageAnimation(i, 0)
          hploss = i.pbReduceHP((i.totalhp / 8.0).floor)
          pbDisplay(_INTL("{1}'s Dry Skin was hurt by the desert air!", i.pbThis)) if hploss > 0
        elsif @field.effect == :MISTY || @battle.state.effects[:MISTY] > 0
          if i.effects[:HealBlock] == 0
            hpgain = (i.totalhp / 16.0).floor
            hpgain = i.pbRecoverHP(hpgain, true)
            pbDisplay(_INTL("{1}'s Dry Skin was healed by the mist!", i.pbThis)) if hpgain > 0
          end
        elsif @field.effect == :SWAMP # Swamp Field
          if i.effects[:HealBlock] == 0
            hpgain = (i.totalhp / 16.0).floor
            hpgain = i.pbRecoverHP(hpgain, true)
            pbDisplay(_INTL("{1}'s Dry Skin was healed by the murk!", i.pbThis)) if hpgain > 0
          end
        end
      end
      # Ice Body
      if i.ability == :ICEBODY && (pbWeather == :HAIL || [:ICY, :SNOWYMOUNTAIN, :FROZENDIMENSION].include?(@field.effect)) && i.effects[:HealBlock] == 0
        hpgain = i.pbRecoverHP((i.totalhp / 16.0).floor, true)
        pbDisplay(_INTL("{1}'s Ice Body restored its HP a little!", i.pbThis)) if hpgain > 0
      end
      if i.crested == :DRUDDIGON && pbWeather == :SUNNYDAY && i.effects[:HealBlock] == 0
        hpgain = i.pbRecoverHP((i.totalhp / 16.0).floor, true)
        pbDisplay(_INTL("{1}'s Crest restored its HP a little!", i.pbThis)) if hpgain > 0
      end
      if i.isFainted?
        return if !i.pbFaint

        next
      end
    end
    # Wish
    for i in priority
      if i.effects[:Wish] > 0
        i.effects[:Wish] -= 1
        if i.effects[:Wish] == 0
          next if i.isFainted?

          hpgain = i.pbRecoverHP(i.effects[:WishAmount], true)
          if hpgain > 0
            wishmaker = pbThisEx(i.index, i.effects[:WishMaker])
            pbDisplay(_INTL("{1}'s wish came true!", wishmaker))
          end
        end
      end
    end
    # Fire Pledge + Grass Pledge combination damage - should go here
    for i in priority
      next if i.isFainted?

      # Shed Skin
      if i.ability == :SHEDSKIN
        if (pbRandom(10) < 3 || @field.effect == :DRAGONSDEN) && !i.status.nil?
          pbDisplay(_INTL("{1}'s Shed Skin cured its {2} problem!", i.pbThis, i.status.downcase))
          i.status = nil
          i.statusCount = 0
          if @field.effect == :DRAGONSDEN
            pbDisplay(_INTL("{1}'s scaled sheen glimmers brightly!", i.pbThis))
            if i.effects[:HealBlock] == 0
              hpgain = (i.totalhp / 4.0).floor
              hpgain = i.pbRecoverHP(hpgain, true)
            end
            pbCommonAnimation("StatUp", i, nil) unless i.pbTooHigh?(PBStats::SPEED) && i.pbTooHigh?(PBStats::SPATK)
            i.pbIncreaseStatBasic(PBStats::SPEED, 1) unless i.pbTooHigh?(PBStats::SPEED)
            i.pbIncreaseStatBasic(PBStats::SPATK, 1) unless i.pbTooHigh?(PBStats::SPATK)
            pbCommonAnimation("StatDown", i, nil) unless i.pbTooLow?(PBStats::DEFENSE) && i.pbTooLow?(PBStats::SPDEF)
            i.pbReduceStatBasic(PBStats::DEFENSE, 1) unless i.pbTooLow?(PBStats::DEFENSE)
            i.pbReduceStatBasic(PBStats::SPDEF, 1) unless i.pbTooLow?(PBStats::SPDEF)
          end
        end
      end
      # Hydration
      if i.ability == :HYDRATION && ((pbWeather == :RAINDANCE && !i.hasWorkingItem(:UTILITYUMBRELLA)) || (@field.effect == :WATERSURFACE && !i.isAirborne?) || @field.effect == :UNDERWATER)
        if !i.status.nil?
          pbDisplay(_INTL("{1}'s Hydration cured its {2} problem!", i.pbThis, i.status.downcase))
          i.status = nil
          i.statusCount = 0
        end
        if @field.effect == :CLOUDS && pbWeather == :RAINDANCE && i.hp != i.totalhp
          i.pbRecoverHP((i.totalhp / 16.0).floor, true)
          pbDisplay(_INTL("{1}'s Hydration restored its health!", i.pbThis))
        end
      end
      if i.ability == :WATERVEIL && (@field.effect == :WATERSURFACE || @field.effect == :UNDERWATER)
        if !i.status.nil?
          pbDisplay(_INTL("{1}'s Water Veil cured its {2} problem!", i.pbThis, i.status.downcase))
          i.status = nil
          i.statusCount = 0
        end
      end
      # Healer
      if i.ability == :HEALER
        partner = i.pbPartner
        if pbRandom(10) < 3 && partner.hp > 0 && !partner.status.nil?
          pbDisplay(_INTL("{1}'s Healer cured its partner's {2} problem!", i.pbThis, partner.status.downcase))
          partner.status = nil
          partner.statusCount = 0
        end
      end
    end
    # Held berries/Leftovers/Black Sludge
    for i in priority
      next if i.isFainted?

      i.pbPassiveItemHP
      i.pbBerryHerbCheck
      if i.isFainted?
        return if !i.pbFaint

        next
      end
    end
    # Aqua Ring
    for i in priority
      next if i.hp <= 0

      if i.effects[:AquaRing]
        if @field.effect == :CORROSIVEMIST && !i.hasType?(:STEEL) && !i.hasType?(:POISON)
          @scene.pbDamageAnimation(i, 0)
          i.pbReduceHP((i.totalhp / 16.0).floor)
          pbDisplay(_INTL("{1}'s Aqua Ring absorbed poison!", i.pbThis))
          if i.hp <= 0
            return if !i.pbFaint
          end
        elsif i.effects[:HealBlock] == 0
          hpgain = (i.totalhp / 16.0).floor
          if Rejuv && @battle.FE == :GRASSY
            hpgain = (hpgain * 1.6).floor if i.hasWorkingItem(:BIGROOT)
          else
            hpgain = (hpgain * 1.3).floor if i.hasWorkingItem(:BIGROOT)
          end
          hpgain = (hpgain * 1.3).floor  if i.crested == :SHIINOTIC
          hpgain = (hpgain * 2).floor if [:MISTY, :SWAMP, :WATERSURFACE, :UNDERWATER].include?(@field.effect)
          hpgain = i.pbRecoverHP(hpgain, true)
          pbDisplay(_INTL("{1}'s Aqua Ring restored its HP a little!", i.pbThis)) if hpgain > 0
        end
      end
    end
    # Ingrain
    for i in priority
      next if i.hp <= 0

      if i.effects[:Ingrain]
        if ((!Rejuv && @field.effect == :SWAMP) || @field.effect == :CORROSIVE || @field.effect == :CORRUPTED) && (!i.hasType?(:STEEL) && !i.hasType?(:POISON))
          unless i.ability == :MAGICGUARD
            @scene.pbDamageAnimation(i, 0)
            i.pbReduceHP((i.totalhp / 16.0).floor)
            pbDisplay(_INTL("{1} absorbed foul nutrients with its roots!", i.pbThis))
            if i.hp <= 0
              return if !i.pbFaint
            end
          end
        else
          if @battle.ProgressiveFieldCheck(PBFields::FLOWERGARDEN, 4, 5)
            hpgain = (i.totalhp / 4.0).floor
          elsif @field.effect == :FOREST || @battle.ProgressiveFieldCheck(PBFields::FLOWERGARDEN, 2, 5) || (Rejuv && @field.effect == :GRASSY) || @state.effects[:GRASSY] > 0
            hpgain = (i.totalhp / 8.0).floor
          elsif i.effects[:HealBlock] == 0
            hpgain = (i.totalhp / 16.0).floor
          end
          if i.effects[:HealBlock] == 0
            if Rejuv && @battle.FE == :GRASSY
              hpgain = (hpgain * 1.6).floor if i.hasWorkingItem(:BIGROOT)
            else
              hpgain = (hpgain * 1.3).floor if i.hasWorkingItem(:BIGROOT)
            end
            hpgain = (hpgain * 1.3).floor if i.crested == :SHIINOTIC
            hpgain = i.pbRecoverHP(hpgain, true)
            pbDisplay(_INTL("{1} absorbed nutrients with its roots!", i.pbThis)) if hpgain > 0
          end
        end
      end
    end
    # Leech Seed
    for i in priority
      if i.effects[:LeechSeed] >= 0
        recipient = @battlers[i.effects[:LeechSeed]]
        if recipient && !recipient.isFainted? && i.ability != :MAGICGUARD && !(i.ability == :WONDERGUARD && @battle.FE == :COLOSSEUM) # if recipient exists
          hploss = (i.totalhp / 8.0).floor
          hploss = hploss * 2 if @field.effect == :WASTELAND
          hploss = [hploss, i.hp].min
          pbCommonAnimation("LeechSeed", recipient, i)
          i.pbReduceHP(hploss, true)
          next if recipient.isFainted?

          if i.ability == :LIQUIDOOZE
            hploss = hploss * 2 if @field.effect == :MURKWATERSURFACE || @field.effect == :CORRUPTED || @field.effect == :WASTELAND
            if Rejuv && @battle.FE == :GRASSY
              hploss = (hploss * 1.3).floor
              hploss = (hploss * 1.6).floor if recipient.hasWorkingItem(:BIGROOT)
            else
              hploss = (hploss * 1.3).floor if recipient.hasWorkingItem(:BIGROOT)
            end
            hploss = (hploss * 1.3).floor if recipient.crested == :SHIINOTIC
            recipient.pbReduceHP(hploss, true)
            pbDisplay(_INTL("{1} sucked up the liquid ooze!", recipient.pbThis))
          else
            if recipient.effects[:HealBlock] == 0
              if Rejuv && @battle.FE == :GRASSY
                hploss = (hploss * 1.3).floor
                hploss = (hploss * 1.6).floor if recipient.hasWorkingItem(:BIGROOT)
              else
                hploss = (hploss * 1.3).floor if recipient.hasWorkingItem(:BIGROOT)
              end
              hploss = (hploss * 1.3).floor if recipient.crested == :SHIINOTIC
              recipient.pbRecoverHP(hploss, true)
            end
            pbDisplay(_INTL("{1}'s health was sapped by Leech Seed!", i.pbThis))
          end
          if i.isFainted?
            return if !i.pbFaint
          end
          if recipient.isFainted?
            return if !recipient.pbFaint
          end
          if Rejuv && @field.effect == :SWAMP
            stat = sample([PBStats::ATTACK, PBStats::DEFENSE, PBStats::SPATK, PBStats::SPDEF, PBStats::SPEED])
            i.pbReduceStat(stat, 1, abilitymessage: true, statdropper: recipient)
          end
        end
      end
    end
    for i in priority
      next if i.isFainted?

      # Petrification
      if i.status == :PETRIFIED && (i.effects[:Petrification] >= 0)
        recipient = @battlers[i.effects[:Petrification]]
        if recipient && !recipient.isFainted? && i.ability != :MAGICGUARD && !(i.ability == :WONDERGUARD && @battle.FE == :COLOSSEUM) # if recipient exists
          pbCommonAnimation("Petrification", recipient, i)
          hploss = i.pbReduceHP((i.totalhp / 8).floor, true)
          next if recipient.isFainted?

          if i.ability == :LIQUIDOOZE
            hploss = hploss * 2 if @field.effect == :MURKWATERSURFACE || @field.effect == :CORRUPTED || @field.effect == :WASTELAND
            if Rejuv && @battle.FE == :GRASSY
              hploss = (hploss * 1.6).floor if recipient.hasWorkingItem(:BIGROOT)
            else
              hploss = (hploss * 1.3).floor if recipient.hasWorkingItem(:BIGROOT)
            end
            hploss = (hploss * 1.3).floor if recipient.crested == :SHIINOTIC
            recipient.pbReduceHP(hploss, true)
            pbDisplay(_INTL("{1} sucked up the liquid ooze!", recipient.pbThis))
          else
            if recipient.effects[:HealBlock] == 0
              if Rejuv && @battle.FE == :GRASSY
                hploss = (hploss * 1.6).floor if recipient.hasWorkingItem(:BIGROOT)
              else
                hploss = (hploss * 1.3).floor if recipient.hasWorkingItem(:BIGROOT)
              end
              hploss = (hploss * 1.3).floor if recipient.crested == :SHIINOTIC
              recipient.pbRecoverHP(hploss, true)
            end
            pbDisplay(_INTL("{1}'s health was drained by {2}!", i.pbThis, recipient.pbThis))
          end
          if i.isFainted?
            return if !i.pbFaint
          end
          if recipient.isFainted?
            return if !recipient.pbFaint
          end
        end
      end
      # Poison/Bad poison
      if i.ability != :MAGICGUARD && !(i.ability == :WONDERGUARD && @battle.FE == :COLOSSEUM) && !(i.ability == :GUTS && @battle.FE == :CROWD)
        if (i.ability == :POISONHEAL || i.crested == :ZANGOOSE) &&
           (i.status == :POISON || [:CORROSIVEMIST, :CORRUPTED].include?(@battle.FE) || ([:CORROSIVE, :MURKWATERSURFACE, :WASTELAND].include?(@battle.FE) && !i.isAirborne?))
          if i.effects[:HealBlock] == 0
            if i.hp < i.totalhp
              pbCommonAnimation("Poison", i, nil)
              i.pbRecoverHP((i.totalhp / 8.0).floor, true)
              pbDisplay(_INTL("{1} is healed by poison!", i.pbThis))
            end
            if i.statusCount > 0
              i.effects[:Toxic] += 1
              i.effects[:Toxic] = [15, i.effects[:Toxic]].min
            end
          end
        elsif i.status == :POISON
          i.pbContinueStatus
          if i.statusCount == 0
            i.pbReduceHP((i.totalhp / 8.0).floor)
          else
            i.effects[:Toxic] += 1
            i.effects[:Toxic] = [15, i.effects[:Toxic]].min
            i.pbReduceHP((i.totalhp / 16.0).floor * i.effects[:Toxic])
          end
          if pbCheckGlobalAbility(:STOPPN)
            showMessage = false
            if i.pbReduceStat(PBStats::DEFENSE, 1, abilitymessage: false)
              showMessage = true
            end
            if i.pbReduceStat(PBStats::SPDEF, 1, abilitymessage: false)
              showMessage = true
            end
            if showMessage
              if i.ability == :CONTRARY
                pbDisplay(_INTL("{1}'s defenses increased!", i.pbThis))
              else
                pbDisplay(_INTL("{1}'s defenses were corroded...", i.pbThis))
              end
            end
          end
        end
      end
      # Burn
      if i.status == :BURN && i.ability != :MAGICGUARD && !(i.ability == :WONDERGUARD && @battle.FE == :COLOSSEUM)
        i.pbContinueStatus
        if !(i.ability == :GUTS && @battle.FE == :CROWD)
          if i.ability == :HEATPROOF || @field.effect == :ICY
            i.pbReduceHP((i.totalhp / 32.0).floor)
          else
            i.pbReduceHP((i.totalhp / 16.0).floor)
          end
        end
      end
      # Shiinotic Crest
      if i.crested == :SHIINOTIC
        for j in priority
          next if j == i
          next if j.isFainted?
          next if j.status.nil?

          hploss = (j.totalhp / 16.0).floor
          hploss = hploss * 2 if @field.effect == :WASTELAND
          pbCommonAnimation("LeechSeed", i, j)
          j.pbReduceHP(hploss, true)
          if j.ability == :LIQUIDOOZE
            hploss = hploss * 2 if @field.effect == :MURKWATERSURFACE || @field.effect == :CORRUPTED || @field.effect == :WASTELAND
            if Rejuv && @battle.FE == :GRASSY
              hploss = (hploss * 1.6).floor if i.hasWorkingItem(:BIGROOT)
            else
              hploss = (hploss * 1.3).floor if i.hasWorkingItem(:BIGROOT)
            end
            hploss = (hploss * 1.3).floor if i.crested == :SHIINOTIC
            i.pbReduceHP(hploss, true)
            pbDisplay(_INTL("{1} sucked up the liquid ooze!", i.pbThis))
          else
            if i.effects[:HealBlock] == 0
              if Rejuv && @battle.FE == :GRASSY
                hploss = (hploss * 1.6).floor if i.hasWorkingItem(:BIGROOT)
              else
                hploss = (hploss * 1.3).floor if i.hasWorkingItem(:BIGROOT)
              end
              hploss = (hploss * 1.3).floor if i.crested == :SHIINOTIC
              i.pbRecoverHP(hploss, true)
            end
            pbDisplay(_INTL("{1}'s health was sapped by {2}'s Crest!", i.pbThis, i.pbThis))
          end
          if j.isFainted?
            return if !j.pbFaint
          end
          if i.isFainted?
            return if !i.pbFaint
          end
        end
      end
      # Nightmare
      if i.effects[:Nightmare] && i.ability != :MAGICGUARD && !(i.ability == :WONDERGUARD && @battle.FE == :COLOSSEUM) && @field.effect != :RAINBOW
        if ((i.status == :SLEEP || (i.ability == :COMATOSE && @battle.FE != :ELECTERRAIN)) || @battle.FE == :INFERNAL || i.pbOpposing1.ability == :WORLDOFNIGHTMARES || i.pbOpposing2.ability == :WORLDOFNIGHTMARES)
          pbCommonAnimation("Nightmare", i, nil)
          pbDisplay(_INTL("{1} is locked in a nightmare!", i.pbThis))
          hploss = (i.totalhp / 4.0).floor
          hploss = (i.totalhp / 3.0).floor if @field.effect == :HAUNTED || @field.effect == :DARKNESS3
          i.pbReduceHP(hploss, true)
        else
          i.effects[:Nightmare] = false
        end
      end
      if i.isFainted?
        return if !i.pbFaint

        next
      end
    end
    # Curse
    for i in priority
      next if i.isFainted?
      next if !i.effects[:Curse]

      if @field.effect == :HOLY
        i.effects[:Curse] = false
        pbDisplay(_INTL("{1}'s curse was lifted!", i.pbThis))
      end
      if i.ability != :MAGICGUARD && !(i.ability == :WONDERGUARD && @battle.FE == :COLOSSEUM)
        pbCommonAnimation("Curse", i, nil)
        pbDisplay(_INTL("{1} is afflicted by the curse!", i.pbThis))
        i.pbReduceHP((i.totalhp / 4.0).floor, true)
      end
      if i.isFainted?
        return if !i.pbFaint

        next
      end
    end
    # Multi-turn attacks (Bind/Clamp/Fire Spin/Magma Storm/Sand Tomb/Whirlpool/Wrap)
    for i in priority
      next if i.isFainted?

      i.pbBerryHerbCheck
      if i.effects[:MultiTurn] > 0
        i.effects[:MultiTurn] -= 1
        movename = getMoveName(i.effects[:MultiTurnAttack])
        if i.effects[:MultiTurn] == 0
          pbDisplay(_INTL("{1} was freed from {2}!", i.pbThis, movename))
          i.effects[:BindingBand] = false
        elsif i.ability != :MAGICGUARD && !(i.ability == :WONDERGUARD && @battle.FE == :COLOSSEUM)
          pbDisplay(_INTL("{1} is hurt by {2}!", i.pbThis, movename))
          if i.effects[:MultiTurnAttack] == :BIND
            pbCommonAnimation("Bind", i, nil)
          elsif i.effects[:MultiTurnAttack] == :CLAMP
            pbCommonAnimation("Clamp", i, nil)
          elsif i.effects[:MultiTurnAttack] == :FIRESPIN
            pbCommonAnimation("FireSpin", i, nil)
          elsif i.effects[:MultiTurnAttack] == :MAGMASTORM
            pbCommonAnimation("Magma Storm", i, nil)
          elsif i.effects[:MultiTurnAttack] == :SANDTOMB || i.effects[:MultiTurnAttack] == :DESERTSMARK
            pbCommonAnimation("SandTomb", i, nil)
          elsif i.effects[:MultiTurnAttack] == :WRAP
            pbCommonAnimation("Wrap", i, nil)
          elsif i.effects[:MultiTurnAttack] == :INFESTATION
            pbCommonAnimation("Infestation", i, nil)
          elsif i.effects[:MultiTurnAttack] == :WHIRLPOOL
            pbCommonAnimation("Whirlpool", i, nil)
          else
            pbCommonAnimation("Wrap", i, nil)
          end
          @scene.pbDamageAnimation(i, 0)
          binddamage = 0
          if i.effects[:BindingBand]
            binddamage += 1
          end
          if i.effects[:MultiTurnAttack] == :MAGMASTORM && @field.effect == :DRAGONSDEN
            binddamage += 1
          elsif i.effects[:MultiTurnAttack] == :SANDTOMB && @field.effect == :DESERT
            binddamage += 1
          elsif i.effects[:MultiTurnAttack] == :WHIRLPOOL && (@field.effect == :WATERSURFACE || @field.effect == :UNDERWATER)
            binddamage += 1
          elsif i.effects[:MultiTurnAttack] == :INFESTATION && @field.effect == :FOREST
            binddamage += 1
          elsif i.effects[:MultiTurnAttack] == :FIRESPIN && (@field.effect == :BURNING || @field.effect == :HAUNTED)
            binddamage += 1
          elsif i.effects[:MultiTurnAttack] == :INFESTATION && @battle.ProgressiveFieldCheck(PBFields::FLOWERGARDEN, 3, 5)
            case @battle.FE
              when :FLOWERGARDEN3 then binddamage += 1
              when :FLOWERGARDEN4 then binddamage += 2
              when :FLOWERGARDEN5 then binddamage += 3
            end
          elsif i.effects[:MultiTurnAttack] == :THUNDERCAGE && @field.effect == :ELECTERRAIN
            binddamage += 1
          elsif i.effects[:MultiTurnAttack] == :SNAPTRAP && @field.effect == :GRASSY
            binddamage += 1
          end
          i.pbReduceHP((i.totalhp / [8.0, 6.0, 4.0, 3.0, 2.0][binddamage]).floor)
          if i.effects[:MultiTurnAttack] == :SANDTOMB && @field.effect == :ASHENBEACH
            i.pbReduceStat(PBStats::ACCURACY, 1, abilitymessage: true)
          end
          if Rejuv && @field.effect == :SWAMP && (i.effects[:MultiTurnAttack] == :SNAPTRAP || i.effects[:MultiTurnAttack] == :INFESTATION)
            stat = sample([PBStats::ATTACK, PBStats::DEFENSE, PBStats::SPATK, PBStats::SPDEF, PBStats::SPEED])
            i.pbReduceStat(stat, 1, abilitymessage: true)
          end
        end
      end
      if i.hp <= 0
        return if !i.pbFaint

        next
      end
      i.pbBerryHerbCheck
    end
    # Taunt
    for i in priority
      next if i.isFainted?
      next if i.effects[:Taunt] == 0

      i.effects[:Taunt] -= 1
      if i.effects[:Taunt] == 0
        pbDisplay(_INTL("{1} recovered from the taunting!", i.pbThis))
      end
    end
    # Encore
    for i in priority
      next if i.isFainted?
      next if i.effects[:Encore] == 0

      if i.moves[i.effects[:EncoreIndex]].move != i.effects[:EncoreMove]
        i.effects[:Encore] = 0
        i.effects[:EncoreIndex] = 0
        i.effects[:EncoreMove] = 0
      else
        i.effects[:Encore] -= 1
        if i.effects[:Encore] == 0 || i.moves[i.effects[:EncoreIndex]].pp == 0
          i.effects[:Encore] = 0
          pbDisplay(_INTL("{1}'s encore ended!", i.pbThis))
        end
      end
    end
    # Disable/Cursed Body
    for i in priority
      next if i.isFainted?
      next if i.effects[:Disable] == 0

      i.effects[:Disable] -= 1
      if i.effects[:Disable] == 0
        i.effects[:DisableMove] = 0
        pbDisplay(_INTL("{1} is disabled no more!", i.pbThis))
      end
    end
    # Magnet Rise
    for i in priority
      next if i.isFainted?

      if i.effects[:MagnetRise] > 0
        i.effects[:MagnetRise] -= 1
        if i.effects[:MagnetRise] == 0
          pbDisplay(_INTL("{1} stopped levitating.", i.pbThis))
        end
      end
    end
    # ChtonicMalady
    for i in priority
      next if i.isFainted?
      next if i.effects[:Torment] == false

      if i.effects[:ChtonicMalady] > 0
        i.effects[:ChtonicMalady] -= 1
        if i.effects[:ChtonicMalady] == 0
          i.effects[:Torment] = false
          pbDisplay(_INTL("{1}'s torment wore off.", i.pbThis))
        end
      end
    end
    # Telekinesis
    for i in priority
      next if i.isFainted?

      if i.effects[:Telekinesis] > 0
        i.effects[:Telekinesis] -= 1
        if i.effects[:Telekinesis] == 0
          pbDisplay(_INTL("{1} stopped levitating.", i.pbThis))
        end
      end
    end
    # Heal Block
    for i in priority
      next if i.isFainted?

      if i.effects[:HealBlock] > 0
        i.effects[:HealBlock] -= 1
        if i.effects[:HealBlock] == 0
          pbDisplay(_INTL("The heal block on {1} ended.", i.pbThis))
        end
      end
    end
    # Embargo
    for i in priority
      next if i.isFainted?

      if i.effects[:Embargo] > 0
        i.effects[:Embargo] -= 1
        if i.effects[:Embargo] == 0
          pbDisplay(_INTL("The embargo on {1} was lifted.", i.pbThis(true)))
        end
      end
    end
    # Yawn
    for i in priority
      next if i.isFainted?

      if i.effects[:Yawn] > 0
        i.effects[:Yawn] -= 1
        if i.effects[:Yawn] == 0 && i.pbCanSleepYawn?
          i.pbSleep
          pbDisplay(_INTL("{1} fell asleep!", i.pbThis))
          i.pbBerryHerbCheck
        end
      end
    end
    # Perish Song
    perishSongUsers = []
    for i in priority
      next if i.isFainted?

      if i.effects[:PerishSong] > 0
        if (i.isbossmon && i.immunities[:moves].include?(:PERISHSONG))
          pbDisplay(_INTL("{1} grew resistant to the Perish Song!", i.pbThis))
          i.effects[:PerishSong] = 0
          next
        end
        i.effects[:PerishSong] -= 1
        pbDisplay(_INTL("{1}'s Perish count fell to {2}!", i.pbThis, i.effects[:PerishSong]))
        if i.effects[:PerishSong] == 0
          i.immunities[:moves].push(:PERISHSONG) if i.isbossmon
          perishSongUsers.push(i.effects[:PerishSongUser])
          i.pbReduceHP(i.hp, true)
        end
      end
      if i.isFainted?
        return if !i.pbFaint
      end
    end
    if perishSongUsers.length > 0
      # If all remaining Pokemon fainted by a Perish Song triggered by a single side
      if (perishSongUsers.find_all { |item| pbIsOpposing?(item) }.length == perishSongUsers.length) ||
         (perishSongUsers.find_all { |item| !pbIsOpposing?(item) }.length == perishSongUsers.length)
        pbJudgeCheckpoint(@battlers[perishSongUsers[0]])
      end
    end
    if @decision > 0
      pbGainEXP
      return
    end
    texts = ["Your", "The opposing"]
    # Reflect
    for i in 0...2
      next if sides[i].effects[:Reflect] == 0

      sides[i].effects[:Reflect] -= 1
      pbDisplay(_INTL("#{texts[i]} team's Reflect faded!")) if sides[i].effects[:Reflect] == 0
    end
    # Light Screen
    for i in 0...2
      next if sides[i].effects[:LightScreen] == 0

      sides[i].effects[:LightScreen] -= 1
      pbDisplay(_INTL("#{texts[i]} team's Light Screen faded!")) if sides[i].effects[:LightScreen] == 0
    end
    # Aurora Veil
    for i in 0...2
      next if sides[i].effects[:AuroraVeil] == 0

      sides[i].effects[:AuroraVeil] -= 1
      pbDisplay(_INTL("#{texts[i]} team's Aurora Veil faded!")) if sides[i].effects[:AuroraVeil] == 0
    end
    for i in 0...2
      next if sides[i].effects[:AreniteWall] == 0

      sides[i].effects[:AreniteWall] -= 1
      pbDisplay(_INTL("#{texts[i]} team's Arenite Wall faded!")) if sides[i].effects[:AreniteWall] == 0
    end
    # Safeguard
    for i in 0...2
      next if sides[i].effects[:Safeguard] == 0

      sides[i].effects[:Safeguard] -= 1
      pbDisplay(_INTL("#{texts[i]} team is no longer protected by Safeguard!")) if sides[i].effects[:Safeguard] == 0
    end
    # Mist
    for i in 0...2
      next if sides[i].effects[:Mist] == 0

      sides[i].effects[:Mist] -= 1
      pbDisplay(_INTL("#{texts[i]} team's Mist faded!")) if sides[i].effects[:Mist] == 0
    end
    # Tailwind
    for i in 0...2
      next if sides[i].effects[:Tailwind] == 0

      sides[i].effects[:Tailwind] -= 1
      pbDisplay(_INTL("#{texts[i]} team's tailwind stopped blowing!")) if sides[i].effects[:Tailwind] == 0
    end
    # Lucky Chant
    for i in 0...2
      next if sides[i].effects[:LuckyChant] == 0

      sides[i].effects[:LuckyChant] -= 1
      pbDisplay(_INTL("#{texts[i]} team's Lucky Chant faded!")) if sides[i].effects[:LuckyChant] == 0
    end
    # Mud Sport
    if @state.effects[:MudSport] > 0
      @state.effects[:MudSport] -= 1
      if @state.effects[:MudSport] == 0
        if Rejuv && @field.backup == :ELECTERRAIN && @field.effect != :ELECTERRAIN
          breakField
          pbDisplay(_INTL("The field electrified again!"))
        else
          pbDisplay(_INTL("The effects of Mud Sport faded."))
        end
      end
    end
    # Water Sport
    if @state.effects[:WaterSport] > 0
      @state.effects[:WaterSport] -= 1
      pbDisplay(_INTL("The effects of Water Sport faded.")) if @state.effects[:WaterSport] == 0
    end
    # Gravity
    if @state.effects[:Gravity] > 0
      @state.effects[:Gravity] -= 1 if @field.effect != :FROZENDIMENSION
      if @state.effects[:Gravity] == 0
        if @field.backup == :NEWWORLD && @field.effect != :NEWWORLD
          breakField
          pbDisplay(_INTL("The world broke apart again!"))
        else
          pbDisplay(_INTL("Gravity returned to normal."))
        end
      end
    end

    # Terrain
    if @field.duration > 0
      @field.checkPermCondition(self)
    end
    if @field.duration > 0
      @field.duration -= 1
      @field.duration = 0 if @field.duration_condition && !@field.duration_condition.call(self)
      if @field.duration == 0 && @field.effect != :INDOOR
        endTempField
        pbDisplay(_INTL("The terrain returned to normal."))
      end
    end
    # Terrain overlays
    if @state.effects[:ELECTERRAIN] > 0
      @state.effects[:ELECTERRAIN] -= 1 if @field.effect != :FROZENDIMENSION
      pbDisplay(_INTL("The surging electricity dissipated.")) if @state.effects[:ELECTERRAIN] == 0
      quarkdriveCheck
    end
    if @state.effects[:GRASSY] > 0
      @state.effects[:GRASSY] -= 1 if @field.effect != :FROZENDIMENSION
      pbDisplay(_INTL("The surrounding grass withered.")) if @state.effects[:GRASSY] == 0
    end
    if @state.effects[:MISTY] > 0
      @state.effects[:MISTY] -= 1 if @field.effect != :FROZENDIMENSION
      pbDisplay(_INTL("The surrounding mist dispersed.")) if @state.effects[:MISTY] == 0
    end
    if @state.effects[:PSYTERRAIN] > 0
      @state.effects[:PSYTERRAIN] -= 1 if @field.effect != :FROZENDIMENSION
      pbDisplay(_INTL("The psychic energy left as mysteriously as it came.")) if @state.effects[:PSYTERRAIN] == 0
    end
    if @state.effects[:RAINBOW] > 0
      @state.effects[:RAINBOW] -= 1 if @field.effect != :FROZENDIMENSION
      pbDisplay(_INTL("The rainbow disappeared.")) if @state.effects[:RAINBOW] == 0
    end
    # Trick Room - should go here
    # Wonder Room - should go here
    # Magic Room
    if @state.effects[:MagicRoom] > 0
      @state.effects[:MagicRoom] -= 1 if @field.effect != :FROZENDIMENSION
      pbDisplay(_INTL("The area returned to normal.")) if @state.effects[:MagicRoom] == 0
    end
    # Fairy Lock
    if @state.effects[:FairyLock] > 0
      @state.effects[:FairyLock] -= 1
      # Fairy Lock seems to have no end-of-effect text so I've added some.
      pbDisplay(_INTL("The Fairy Lock was released.")) if @state.effects[:FairyLock] == 0
    end
    # Uproar
    for i in priority
      next if i.isFainted?

      if i.effects[:Uproar] > 0
        for j in priority
          if !j.isFainted? && j.status == :SLEEP && !j.ability == :SOUNDPROOF
            j.effects[:Nightmare] = false
            j.status = nil
            j.statusCount = 0
            pbDisplay(_INTL("{1} woke up in the uproar!", j.pbThis))
          end
        end
        i.effects[:Uproar] -= 1
        if i.effects[:Uproar] == 0
          pbDisplay(_INTL("{1} calmed down.", i.pbThis))
        else
          pbDisplay(_INTL("{1} is making an uproar!", i.pbThis))
        end
      end
    end

    # Slow Start's end message
    for i in priority
      next if i.isFainted?

      if i.ability == :SLOWSTART && i.turncount == 4 && @battle.FE != :DEEPEARTH
        pbDisplay(_INTL("{1} finally got its act together!", i.pbThis))
      end
    end

    # Wasteland hazard interaction
    if @field.effect == :WASTELAND
      for i in priority
        is_fainted_before = i.isFainted?
        partner_fainted_before = @doublebattle && i.pbPartner.isFainted?
        # Stealth Rock
        if i.pbOwnSide.effects[:StealthRock]
          pbDisplay(_INTL("The waste swallowed up the pointed stones!"))
          i.pbOwnSide.effects[:StealthRock] = false
          pbDisplay(_INTL("...Rocks spewed out from the ground below!"))
          for mon in [i, i.pbPartner]
            next if mon.isFainted? || PBStuff::TWOTURNMOVE.include?(mon.effects[:TwoTurnAttack]) || mon.ability == :MAGICGUARD

            eff = PBTypes.twoTypeEff(:ROCK, mon.type1, mon.type2)
            next if eff <= 0

            @scene.pbDamageAnimation(mon, 0)
            mon.pbReduceHP([(mon.totalhp * eff / 16).floor, 1].max)
          end
        end

        # Spikes
        if i.pbOwnSide.effects[:Spikes] > 0
          pbDisplay(_INTL("The waste swallowed up the spikes!"))
          spikescount = i.pbOwnSide.effects[:Spikes]
          i.pbOwnSide.effects[:Spikes] = 0
          pbDisplay(_INTL("...Stalagmites burst up from the ground!"))
          for mon in [i, i.pbPartner]
            next if mon.isFainted? || mon.isAirborne? || PBStuff::TWOTURNMOVE.include?(mon.effects[:TwoTurnAttack]) || mon.ability == :MAGICGUARD

            @scene.pbDamageAnimation(mon, 0)
            mon.pbReduceHP([(spikescount * mon.totalhp / 3.0).floor, 1].max)
          end
        end

        # Toxic Spikes
        if i.pbOwnSide.effects[:ToxicSpikes] > 0
          pbDisplay(_INTL("The waste swallowed up the toxic spikes!"))
          tspikescount = i.pbOwnSide.effects[:ToxicSpikes]
          i.pbOwnSide.effects[:ToxicSpikes] = 0
          pbDisplay(_INTL("...Poison needles shot up from the ground!"))
          for mon in [i, i.pbPartner]
            next if mon.isFainted? || mon.isAirborne? || mon.hasType?(:STEEL) || mon.hasType?(:POISON)
            next if PBStuff::TWOTURNMOVE.include?(mon.effects[:TwoTurnAttack])

            if mon.ability != :MAGICGUARD
              @scene.pbDamageAnimation(mon, 0)
              mon.pbReduceHP([(tspikescount * mon.totalhp / 8.0).floor, 1].max)
            end
            if mon.status.nil? && mon.pbCanPoison?(false)
              mon.status = :POISON
              if tspikescount > 1
                mon.statusCount = 1
                mon.effects[:Toxic] = 0
              else
                mon.statusCount = 0
              end
              pbCommonAnimation("Poison", mon, nil)
            end
          end
        end

        # Sticky Web
        if i.pbOwnSide.effects[:StickyWeb]
          pbDisplay(_INTL("The waste swallowed up the sticky web!"))
          i.pbOwnSide.effects[:StickyWeb] = false
          pbDisplay(_INTL("...Sticky string shot out of the ground!"))
          for mon in [i, i.pbPartner]
            next if mon.isFainted? && !PBStuff::TWOTURNMOVE.include?(mon.effects[:TwoTurnAttack])

            if mon.ability == :CONTRARY
              if !mon.pbTooHigh?(PBStats::SPEED, ignoreContrary: true)
                mon.pbIncreaseStatBasic(PBStats::SPEED, 4)
                pbCommonAnimation("StatUp", mon, nil)
                pbDisplay(_INTL("{1}'s Speed went way up!", mon.pbThis))
              end
            else
              if !mon.pbTooLow?(PBStats::SPEED, ignoreContrary: true)
                mon.pbReduceStatBasic(PBStats::SPEED, 4)
                pbCommonAnimation("StatDown", mon, nil)
                pbDisplay(_INTL("{1}'s Speed was severely lowered!", mon.pbThis))
              end
            end
          end
        end

        # Fainting
        if @doublebattle && !partner_fainted_before
          partner = i.pbPartner
          if partner && partner.hp <= 0
            partner.pbFaint
          end
        end
        if i.hp <= 0 && !is_fainted_before
          return if !i.pbFaint

          next
        end
      end
    end
    # End Wasteland hazards
    for i in priority
      next if i.isFainted?

      # Mimicry
      if i.ability == :MIMICRY
        protype = -1
        case @field.effect
          when :CRYSTALCAVERN
            protype = @field.getRoll
          when :NEWWORLD
            protype = @battle.getRandomType
          else
            protype = @field.mimicry if @field.mimicry
        end
        camotype = protype
        if !camotype.nil? && !i.hasType?(camotype)
          i.type1 = camotype
          i.type2 = nil
          pbDisplay(_INTL("{1} had its type changed to {2}!", i.pbThis, camotype.capitalize))
        end
      end
      # Speed Boost
      # A Pokémon's turncount is 0 if it became active after the beginning of a round
      if i.turncount > 0 && (i.ability == :SPEEDBOOST || (@field.effect == :ELECTERRAIN && i.ability == :MOTORDRIVE) ||
        ([:VOLCANIC, :VOLCANICTOP, :WATERSURFACE, :UNDERWATER, :INFERNAL].include?(@field.effect) && i.ability == :STEAMENGINE))
        if !i.pbTooHigh?(PBStats::SPEED)
          i.pbIncreaseStatBasic(PBStats::SPEED, 1)
          pbCommonAnimation("StatUp", i, nil)
          pbDisplay(_INTL("{1}'s {2} raised its Speed!", i.pbThis, getAbilityName(i.ability)))
        end
      end
      if i.ability == :ACCUMULATION && i.turncount > 0 && i.lastMoveUsed != :SPITUP && i.lastMoveUsed != :SWALLOW
        if i.effects[:Stockpile] < 3
          i.effects[:Stockpile] += 1
          i.pbIncreaseStatBasic(PBStats::DEFENSE, 1)
          i.effects[:StockpileDef] += 1
          i.pbIncreaseStatBasic(PBStats::SPDEF, 1)
          i.effects[:StockpileSpDef] += 1
          pbDisplay(_INTL("{1} stockpiled with Accumulation!", i.pbThis))
        end
      end
      if @field.effect == :SWAMP && i.item != :HEAVYDUTYBOOTS && !i.isAirborne? &&
         ![:WHITESMOKE, :CLEARBODY, :QUICKFEET, :SWIFTSWIM, :PROPELLERTAIL, :STEAMENGINE].include?(i.ability)
        statdrop = 1
        statdrop = 2 if i.effects[:MultiTurn] > 0 && Rejuv
        if i.pbReduceStat(PBStats::SPEED, statdrop, statmessage: false)
          if i.ability == :CONTRARY
            pbDisplay(_INTL("{1}'s Speed rose!", i.pbThis))
          else
            pbDisplay(_INTL("{1}'s Speed sank...", i.pbThis))
          end
        end
      end
      if (@field.effect == :DESERT || @field.effect == :HAUNTED) && i.ability == :WANDERINGSPIRIT
        if !i.pbTooLow?(PBStats::SPEED)
          i.pbReduceStat(PBStats::SPEED, 1, statmessage: false)
          pbDisplay(_INTL("{1}'s Wandering Spirit lowered its Speed!", i.pbThis))
        end
      end
      # sleepyswamp #sleepydimension #spookydreams #fairyringsleep #sleepycorro
      if (i.status == :SLEEP || (i.ability == :COMATOSE && @battle.FE != :ELECTERRAIN)) && i.ability != :MAGICGUARD
        if @field.effect == :SWAMP # Swamp Field
          if i.effects[:MultiTurn] > 0 && Rejuv
            hploss = i.pbReduceHP((i.totalhp / 8.0).floor, true)
          else
            hploss = i.pbReduceHP((i.totalhp / 16.0).floor, true)
          end
          pbDisplay(_INTL("{1}'s strength is sapped by the swamp!", i.pbThis)) if hploss > 0
        elsif @field.effect == :DIMENSIONAL # Dimensional Field (Rejuv)
          hploss = i.pbReduceHP((i.totalhp / 16.0).floor, true)
          pbDisplay(_INTL("{1}'s dream is corrupted by the dimension!", i.pbThis)) if hploss > 0
        elsif @field.effect == :HAUNTED && !i.hasType?(:GHOST) # Haunted Field (Rejuv)
          hploss = i.pbReduceHP((i.totalhp / 16.0).floor, true)
          pbDisplay(_INTL("{1}'s dream is corrupted by the evil spirits!", i.pbThis)) if hploss > 0
        elsif @field.effect == :BEWITCHED # Bewitched Woods (Rejuv)
          hploss = i.pbReduceHP((i.totalhp / 16.0).floor, true)
          pbDisplay(_INTL("{1}'s dream is corrupted by the evil in the woods!", i.pbThis)) if hploss > 0
        elsif @field.effect == :CORROSIVE && !i.isAirborne? && !i.hasType?(:STEEL) && !i.hasType?(:POISON) &&
              ![:POISONHEAL, :TOXICBOOST, :WONDERGUARD, :IMMUNITY, :PASTELVEIL].include?(i.ability) && i.crested != :ZANGOOSE
          hploss = i.pbReduceHP((i.totalhp / 16.0).floor, true)
          pbDisplay(_INTL("{1} is seared by the corrosion!", i.pbThis)) if hploss > 0
        end
      end
      if i.hp <= 0
        return if !i.pbFaint

        next
      end
      # sleepyrainbow
      if i.status == :SLEEP || (i.ability == :COMATOSE && @battle.FE != :ELECTERRAIN)
        if @field.effect == :RAINBOW && i.effects[:HealBlock] == 0 # Rainbow Field
          hpgain = (i.totalhp / 16.0).floor
          hpgain = i.pbRecoverHP(hpgain, true)
          pbDisplay(_INTL("{1} recovered health in its peaceful sleep!", i.pbThis))
        end
      end
      # Check HP berry after sleep damage from fields
      i.pbBerryHerbCheck
      # Water Compaction on Water-based Fields
      if i.ability == :WATERCOMPACTION
        if @field.effect == :UNDERWATER || ([:SWAMP, :WATERSURFACE, :MURKWATERSURFACE].include?(@field.effect) && !i.isAirborne?)
          if !i.pbTooHigh?(PBStats::DEFENSE)
            i.pbIncreaseStatBasic(PBStats::DEFENSE, 2)
            pbCommonAnimation("StatUp", i, nil)
            pbDisplay(_INTL("{1}'s Water Compaction sharply raised its defense!", i.pbThis))
          end
        end
      end
      if i.effects[:Octolock] >= 0
        if i.pbCanReduceStatStage?(PBStats::DEFENSE, false) || i.pbCanReduceStatStage?(PBStats::SPDEF, false)
          pbCommonAnimation("Bind", i, nil)
          showMessage = false
          if i.pbReduceStat(PBStats::DEFENSE, 1, abilitymessage: false, statdropper: @battlers[i.effects[:Octolock]])
            showMessage = true
          end
          if i.pbReduceStat(PBStats::SPDEF, 1, abilitymessage: false, statdropper: @battlers[i.effects[:Octolock]])
            showMessage = true
          end
          if showMessage
            if i.ability == :CONTRARY
              pbDisplay(_INTL("The Octolock increased {1}'s defenses!", i.pbThis))
            else
              pbDisplay(_INTL("The Octolock lowered {1}'s defenses!", i.pbThis))
            end
          end
        end
      end
      if Rejuv && i.effects[:SwampWeb]
        if @battle.FE == :SWAMP
          stat = sample([PBStats::ATTACK, PBStats::DEFENSE, PBStats::SPATK, PBStats::SPDEF, PBStats::SPEED])
          i.pbReduceStat(stat, 1, abilitymessage: true)
        end
      end
      # Bad Dreams
      if (i.status == :SLEEP || (i.ability == :COMATOSE && @battle.FE != :ELECTERRAIN)) && i.ability != :MAGICGUARD && !(i.ability == :WONDERGUARD && @battle.FE == :COLOSSEUM) && @field.effect != :RAINBOW
        if i.pbOpposing1.ability == :BADDREAMS || i.pbOpposing2.ability == :BADDREAMS
          hpdrain = (i.totalhp / 8.0).floor
          hpdrain = (i.totalhp / 6.0).floor if @battle.FE == :DARKNESS2
          hpdrain = (i.totalhp / 4.0).floor if [:INFERNAL, :DARKNESS3].include?(@battle.FE)
          hploss = i.pbReduceHP(hpdrain, true)
          pbDisplay(_INTL("{1} is having a bad dream!", i.pbThis)) if hploss > 0
        end
      end
      if i.isFainted?
        return if !i.pbFaint

        next
      end
      # World of Nightmares
      if i.pbOpposing1.ability == :WORLDOFNIGHTMARES || i.pbOpposing2.ability == :WORLDOFNIGHTMARES
        nightmarechip = [64, i.turncount].min
        nightmarechip * 2 if @battle.FE == :NEWWORLD
        hploss = i.pbReduceHP(((i.totalhp / 32).floor) * nightmarechip, true)
        pbDisplay(_INTL("{1}'s nightmares are becoming a reality!", i.pbThis)) if hploss > 0
      end
      if i.isFainted?
        return if !i.pbFaint

        next
      end
      # Pickup (help me -Orsan).
      # tested on SV and in showdown, it deprioritizes items that activate during an attack, such as type berries, focus sashes, and presumably gems. thats represented here as pickupB.
      if i.ability == :PICKUP && i.item.nil?
        pickedup = false
        for pickuptarget in pickupA
          if !pickedup && i.index != pickuptarget && battlers[pickuptarget].pokemon.itemRecycle && !battlers[pickuptarget].isFainted?
            i.item = battlers[pickuptarget].pokemon.itemRecycle
            battlers[pickuptarget].pokemon.itemRecycle = nil
            pbDisplay(_INTL("{1} found one {2}!", i.pbThis, getItemName(i.item)))
            pickedup = true
          end
        end
        for pickuptarget in pickupB
          if !pickedup && i.index != pickuptarget && battlers[pickuptarget].pokemon.itemRecycle && !battlers[pickuptarget].isFainted?
            i.item = battlers[pickuptarget].pokemon.itemRecycle
            battlers[pickuptarget].pokemon.itemRecycle = nil
            pbDisplay(_INTL("{1} found one {2}!", i.pbThis, getItemName(i.item)))
            pickedup = true
          end
        end
        i.pbPassiveItemHP
        i.pbBerryHerbCheck
        seedCheck
      end
      # Harvest
      if i.ability == :HARVEST && i.item.nil? && i.pokemon.itemRecycle # if an item was recycled, check
        if pbIsBerry?(i.pokemon.itemRecycle) && (pbRandom(100) > 50 || (pbWeather == :SUNNYDAY && !i.hasWorkingItem(:UTILITYUMBRELLA)) ||
           @battle.ProgressiveFieldCheck(PBFields::FLOWERGARDEN, 2, 5) || (Rejuv && @battle.FE == :GRASSY))
          i.item = i.pokemon.itemRecycle
          i.pokemon.itemInitial = i.pokemon.itemRecycle
          i.pokemon.itemRecycle = nil
          firstberryletter = getItemName(i.item).split(//).first
          if firstberryletter == "A" || firstberryletter == "E" || firstberryletter == "I" ||
             firstberryletter == "O" || firstberryletter == "U"
            pbDisplay(_INTL("{1} harvested an {2}!", i.pbThis, getItemName(i.item)))
          else
            pbDisplay(_INTL("{1} harvested a {2}!", i.pbThis, getItemName(i.item)))
          end
          i.pbBerryHerbCheck
        end
      end
      # Ball Fetch
      if i.ability == :BALLFETCH && !i.effects[:BallFetch].nil? && i.item.nil?
        pokeball = i.effects[:BallFetch]
        i.item = pokeball
        i.pokemon.itemInitial = pokeball
        PBDebug.log("[Ability triggered] #{i.pbThis}'s Ball Fetch found #{getItemName(pokeball)}")
        pbDisplay(_INTL("{1} fetched a {2}!", i.pbThis, getItemName(pokeball)))
      end
      # Moody
      if i.ability == :CLOUDNINE && @field.effect == :RAINBOW
        incstats = []
        for stat in 1..7
          incstats.push(stat) if !i.pbTooHigh?(stat)
        end
        if !incstats.empty?
          incstat = @battle.sample(incstats)
          i.pbIncreaseStatBasic(incstat, 1)
          pbCommonAnimation("StatUp", i, nil)
          pbDisplay(_INTL("{1}'s Cloud Nine raised its {2}!", i.pbThis, i.pbGetStatName(incstat)))
        end
      end
      if i.ability == :MOODY
        incstats = []
        decstats = []
        for stat in 1..(Gen <= 7 ? 7 : 5)
          incstats.push(stat) if !i.pbTooHigh?(stat)
          decstats.push(stat) if !i.pbTooLow?(stat)
        end
        if !incstats.empty?
          incstat = @battle.sample(incstats)
          initial = i.stages[incstat]
          i.pbIncreaseStatBasic(incstat, 2)
          pbCommonAnimation("StatUp", i, nil)
          str = initial < 5 ? "sharply " : ""
          pbDisplay(_INTL("{1}'s Moody #{str}raised its {2}!", i.pbThis, i.pbGetStatName(incstat)))
          decstats -= [incstat]
        end
        if !decstats.empty?
          decstat = @battle.sample(decstats)
          i.pbReduceStatBasic(decstat, 1)
          pbCommonAnimation("StatDown", i, nil)
          pbDisplay(_INTL("{1}'s Moody lowered its {2}!", i.pbThis, i.pbGetStatName(decstat)))
        end
      end
      i.pbBerryHerbCheck
    end
    for i in priority
      next if i.isFainted?
      next if !i.itemWorks?

      # Toxic Orb
      if i.item == :TOXICORB && i.status.nil? && i.pbCanPoison?(false, true, i.ability == :CORROSION)
        i.status = :POISON
        i.statusCount = 1
        i.effects[:Toxic] = 0
        pbCommonAnimation("Poison", i, nil)
        pbDisplay(_INTL("{1} was poisoned by its {2}!", i.pbThis, getItemName(i.item)))
      end
      # Flame Orb
      if i.item == :FLAMEORB && i.status.nil? && i.pbCanBurn?(false, true)
        i.status = :BURN
        i.statusCount = 0
        pbCommonAnimation("Burn", i, nil)
        pbDisplay(_INTL("{1} was burned by its {2}!", i.pbThis, getItemName(i.item)))
      end
      # Sticky Barb
      if i.item == :STICKYBARB && i.ability != :MAGICGUARD && !(i.ability == :WONDERGUARD && @battle.FE == :COLOSSEUM)
        pbDisplay(_INTL("{1} is hurt by its {2}!", i.pbThis, getItemName(i.item)))
        @scene.pbDamageAnimation(i, 0)
        i.pbReduceHP((i.totalhp / 8.0).floor)
      end
      if i.isFainted?
        return if !i.pbFaint

        next
      end
    end
    # Emergency exit caused by passive end of turn damage
    for i in priority
      if i.userSwitch
        i.userSwitch = false
        neutralizingGasDisable(i.index) if i.ability == :NEUTRALIZINGGAS
        pbDisplay(_INTL("{1} went back to {2}!", i.pbThis, pbGetOwner(i.index).name))
        newpoke = pbSwitchInBetween(i.index, true, false)
        pbMessagesOnReplace(i.index, newpoke)
        i.vanished = false
        i.pbResetForm
        pbReplace(i.index, newpoke)
        pbOnActiveOne(i)
        i.pbAbilitiesOnSwitchIn(true)
      end
    end
    # Hunger Switch
    for i in priority
      next if i.isFainted?

      if i.ability == :HUNGERSWITCH && i.species == :MORPEKO && @battle.FE != :FROZENDIMENSION
        i.form = (i.form == 0) ? 1 : 0
        i.pbUpdate(true)
        scene.pbChangePokemon(i, i.pokemon)
        pbDisplay(_INTL("{1} transformed!", i.pbThis))
      end
    end
    # Form checks
    for i in 0...4
      next if @battlers[i].isFainted?

      @battlers[i].pbCheckWeatherForm
      @battlers[i].pbCheckFormRoundEnd
    end
    pbGainEXP

    # Checks if a pokemon on either side has fainted on this turn
    # for retaliate
    player   = priority[0]
    opponent = priority[1]
    player.pbOwnSide.effects[:Retaliate] = player.isFainted? || (@doublebattle && player.pbPartner.isFainted?)
    opponent.pbOwnSide.effects[:Retaliate] = opponent.isFainted? || (@doublebattle && opponent.pbPartner.isFainted?)
    for i in priority
      next if i.isFainted?
      next if i.nil?
      next if !Rejuv
      next if @party2[0].nil?

      @state.effects[:sosBuffer] = 3 if @state.effects[:sosBuffer] == 0 && (@doublebattle && i.isbossmon && i.pbPartner.issossmon)
      @state.effects[:sosBuffer] = 4 if @state.effects[:sosBuffer] == 0 && $cache.bosses[@party2[0].bossID] && $cache.bosses[@party2[0].bossID].name == "Spacea"
    end
    # sosBuffer
    if @state.effects[:sosBuffer] > 0
      @state.effects[:sosBuffer] -= 1
    end
    pbBossSOS(priority) if Rejuv && @state.effects[:sosBuffer] == 0
    pbSwitch
    return if @decision > 0

    for i in priority
      next if i.isFainted?

      i.pbAbilitiesOnSwitchIn(false)
    end
    for i in 0...4
      if @battlers[i].turncount > 0
        if @battlers[i].ability == :TRUANT
          @battlers[i].effects[:Truant] = !@battlers[i].effects[:Truant]
        else
          @battlers[i].effects[:Truant] = false
        end
      end
      if @battlers[i].effects[:LockOn] > 0 # Also Mind Reader
        @battlers[i].effects[:LockOn] -= 1
        @battlers[i].effects[:LockOnPos] = -1 if @battlers[i].effects[:LockOn] == 0
      end
      @battlers[i].effects[:Roost] = false
      @battlers[i].effects[:Flinch] = false
      @battlers[i].effects[:FollowMe] = false
      @battlers[i].effects[:RagePowder] = false
      @battlers[i].effects[:Charge] -= 1 if @battlers[i].effects[:Charge] > 0
      @battlers[i].effects[:LaserFocus] -= 1 if @battlers[i].effects[:LaserFocus] > 0
      @battlers[i].effects[:Snatch] = false
      @battlers[i].effects[:Electrify] = false
      @battlers[i].lastHPLost = 0
      @battlers[i].lastAttacker = -1
      @battlers[i].effects[:Counter] = -1
      @battlers[i].effects[:CounterTarget] = -1
      @battlers[i].effects[:MirrorCoat] = -1
      @battlers[i].effects[:MirrorCoatTarget] = -1
    end
    @pickupA = []
    @pickupB = []
    # invalidate stored priority
    @usepriority = false
    @eruption = false
  end

  ################################################################################
  # End of battle.
  ################################################################################
  def pbEndOfBattle(canlose = false)
    $position = Audio.bgm_pos
    case @decision
      ##### WIN #####
      when 1
        $game_variables[:Egg_Battle_Count] += 1 if Desolation && $game_variables[:Egg_Battle_Count] > 0 && $game_variables[:Egg_Battle_Count] < 1000
        if @opponent
          @scene.pbTrainerBattleSuccess
          if @opponent.is_a?(Array)
            pbDisplayPaused(_INTL("{1} defeated {2} and {3}!", self.pbPlayer.name, @opponent[0].fullname, @opponent[1].fullname))
          else
            pbDisplayPaused(_INTL("{1} defeated\r\n{2}!", self.pbPlayer.name, @opponent.fullname))
          end
          @scene.pbShowOpponent(0)
          pbDisplayAutoPaused(@endspeech.gsub(/\\[Pp][Nn]/, self.pbPlayer.name))
          if @opponent.is_a?(Array)
            @scene.pbHideOpponent
            @scene.pbShowOpponent(1)
            pbDisplayAutoPaused(@endspeech2.gsub(/\\[Pp][Nn]/, self.pbPlayer.name))
          end
          # Calculate money gained for winning
          if @internalbattle
            tmoney = 0
            if @opponent.is_a?(Array) # Double battles
              maxlevel1 = 0
              maxlevel2 = 0
              limit = pbSecondPartyBegin(1)
              for i in 0...limit
                if @party2[i]
                  maxlevel1 = @party2[i].level if maxlevel1 < @party2[i].level
                end
                if @party2[i + limit]
                  maxlevel2 = @party2[i + limit].level if maxlevel1 < @party2[i + limit].level
                end
              end
              maxlevel1 = [100, maxlevel1].min
              maxlevel2 = [100, maxlevel2].min
              tmoney += maxlevel1 * @opponent[0].moneyEarned
              tmoney += maxlevel2 * @opponent[1].moneyEarned
            else
              maxlevel = 0
              for i in @party2
                next if !i

                maxlevel = i.level if maxlevel < i.level
              end
              tmoney += maxlevel * @opponent.moneyEarned
            end
            # If Amulet Coin/Luck Incense's effect applies, double money earned
            badgemultiplier = (1 + (self.pbPlayer.numbadges / 3)).floor
            badgemultiplier = (1 + (self.pbPlayer.numbadges / 2)).floor if Desolation || Rejuv
            tmoney *= badgemultiplier
            tmoney *= 2 if @amuletcoin
            tmoney *= 2 if @happyhour
            tmoney *= 2 if $game_switches[:Moneybags]
            if $game_switches[:Grinding_Trainer_Money_Cut] || $game_switches[:Penniless_Mode] # grinding trainers
              tmoney *= 0.2
              tmoney = tmoney.floor
            end
            tmoney *= 2 if $game_variables[:LuckMoney] != 0
            tmoney = 0 if $game_variables[:LuckMoney] > 10 || $game_variables[:LuckMoney] < -10
            oldmoney = self.pbPlayer.money
            if $game_variables[:LuckMoney] < 0
              self.pbPlayer.money -= tmoney
              moneylost = oldmoney - self.pbPlayer.money
              if moneylost > 0
                pbDisplayAutoPaused(_INTL("{1} paid ${2}\r\nfor winning!", self.pbPlayer.name, tmoney))
              end
            else
              self.pbPlayer.money += tmoney
              moneygained = self.pbPlayer.money - oldmoney
              if moneygained > 0
                pbDisplayAutoPaused(_INTL("{1} got ${2}\r\nfor winning!", self.pbPlayer.name, tmoney))
              end
            end
          end
        elsif @party2[0].isbossmon
          bossname = $cache.bosses[@party2[0].bossID].name
          @scene.pbBossBattleSuccess(bossname)
          pbDisplayPaused(_INTL("{1} defeated\r\n{2}!", self.pbPlayer.name, bossname))
        end
        if @internalbattle && @extramoney > 0
          @extramoney *= 2 if @amuletcoin
          @extramoney *= 2 if @happyhour
          oldmoney = self.pbPlayer.money
          self.pbPlayer.money += @extramoney
          moneygained = self.pbPlayer.money - oldmoney
          if moneygained > 0
            pbDisplayAutoPaused(_INTL("{1} picked up ${2}!", self.pbPlayer.name, @extramoney))
          end
        end
        for pkmn in @snaggedpokemon
          pbStorePokemon(pkmn)
          # self.pbPlayer.shadowcaught=[] if !self.pbPlayer.shadowcaught
          # self.pbPlayer.shadowcaught[pkmn.species]=true
        end
        @snaggedpokemon.clear
        if Rejuv
          returnStolenPokemon(true, nil)
        end
        # Update Healingitem
        if $PokemonGlobal.partner && @player.is_a?(Array)
          $PokemonGlobal.partner[4] = @partneritems if $PokemonGlobal.partner[4] = @partneritems
        end
      ##### LOSE, DRAW #####
      when 2, 5
        if @internalbattle
          pbDisplayAutoPaused(_INTL("{1} is out of usable Pokémon!", self.pbPlayer.name))
          moneylost = pbMaxLevelFromIndex(0)
          multiplier = [8, 16, 24, 36, 48, 64, 80, 100, 120, 140, 160, 180, 190, 200, 210, 220, 230, 240, 250, 250] # Badge no. multiplier for money lost
          moneylost *= multiplier[[multiplier.length - 1, self.pbPlayer.numbadges].min]
          moneylost = self.pbPlayer.money if moneylost > self.pbPlayer.money
          moneylost = 0 if $game_switches[:No_Money_Loss]
          self.pbPlayer.money -= moneylost
          if @opponent
            if @opponent.is_a?(Array)
              pbDisplayPaused(_INTL("{1} lost against {2} and {3}!", self.pbPlayer.name, @opponent[0].fullname, @opponent[1].fullname))
            else
              pbDisplayPaused(_INTL("{1} lost against\r\n{2}!", self.pbPlayer.name, @opponent.fullname))
            end
            if moneylost > 0
              pbDisplayAutoPaused(_INTL("{1} paid ${2}\r\nas the prize money...", self.pbPlayer.name, moneylost))
              pbDisplayAutoPaused(_INTL("...")) if !canlose
            end
          else
            if moneylost > 0
              pbDisplayAutoPaused(_INTL("{1} panicked and lost\r\n${2}...", self.pbPlayer.name, moneylost))
              pbDisplayAutoPaused(_INTL("...")) if !canlose
            end
          end
          pbDisplayAutoPaused(_INTL("{1} blacked out!", self.pbPlayer.name)) if !canlose
        elsif @decision == 2
          @scene.pbShowOpponent(0)
          pbDisplayAutoPaused(@endspeechwin.gsub(/\\[Pp][Nn]/, self.pbPlayer.name))
          if @opponent.is_a?(Array)
            @scene.pbHideOpponent
            @scene.pbShowOpponent(1)
            pbDisplayAutoPaused(@endspeechwin2.gsub(/\\[Pp][Nn]/, self.pbPlayer.name))
          end
        elsif @decision == 5
          PBDebug.log("***[Draw game]") if $INTERNAL
        end
        if Rejuv
          returnStolenPokemon(true, nil)
        end
        $game_screen.weather(0, 0, 0)
    end
    # Change bad poison to normal poison
    for i in $Trainer.party
      next if i.nil?

      if i.statusCount > 0 && i.status == :POISON
        i.statusCount = 0
      end
    end

    # Pass on Pokérus within the party
    infected = []
    for i in 0...$Trainer.party.length
      if $Trainer.party[i].pokerusStage == 1
        infected.push(i)
      end
    end
    if infected.length >= 1
      for i in infected
        strain = $Trainer.party[i].pokerus / 16
        if i > 0 && $Trainer.party[i - 1].pokerusStage == 0
          $Trainer.party[i - 1].givePokerus(strain) if pbRandom(3) == 0
        end
        if i < $Trainer.party.length - 1 && $Trainer.party[i + 1].pokerusStage == 0
          $Trainer.party[i + 1].givePokerus(strain) if pbRandom(3) == 0
        end
      end
    end
    if $game_variables[:LuckMoney] != 0 && @opponent && !@battle.isOnline?
      $game_variables[:LuckMoney] -= 1 if $game_variables[:LuckMoney] > 0
      $game_variables[:LuckMoney] += 1 if $game_variables[:LuckMoney] < 0
      pbDisplayPaused(_INTL("Mr Luck's money contract lost its effect!")) if $game_variables[:LuckMoney] == 0
    end
    if $game_variables[:LuckShinies] != 0 && !@opponent && !@party2[0].isbossmon && !@battle.isOnline?
      $game_variables[:LuckShinies] -= 1 if $game_variables[:LuckShinies] > 0
      $game_variables[:LuckShinies] += 1 if $game_variables[:LuckShinies] < 0
      pbDisplayPaused(_INTL("Mr Luck's shiny contract lost its effect!")) if $game_variables[:LuckShinies] == 0
    end
    if $game_variables[:LuckMoves] != 0 && !@opponent && !@party2[0].isbossmon && !@battle.isOnline?
      $game_variables[:LuckMoves] -= 1 if $game_variables[:LuckMoves] > 0
      $game_variables[:LuckMoves] += 1 if $game_variables[:LuckMoves] < 0
      pbDisplayPaused(_INTL("Mr Luck's technique contract lost its effect!")) if $game_variables[:LuckMoves] == 0
    end
    @scene.pbEndBattle(@decision)

    # Resetting all the temporary forms
    for i in @battlers
      i.pbResetForm
    end
    for i in @party1
      next if i.nil?

      i.makeUnmega if i.isMega?
      i.makeUnprimal if i.isPrimal?
      i.makeUnultra if i.isUltra?
      if i.species == :ZYGARDE && !i.originalForm.nil?
        hpbackup = i.hp
        i.form = i.originalForm
        i.originalForm = nil
        i.hp = [hpbackup, i.totalhp].min
      end
      i.form = 0 if i.species == :MIMIKYU || i.species == :EISCUE
      if Rejuv
        i.form = 1 if (i.species == :PARAS || i.species == :PARASECT) && i.form == 2
        i.prismPower = false
        i.rampCrestUsed = false
      end
    end
    for i in $Trainer.party
      i.setItem(i.itemInitial)
      i.setItem(i.itemReallyInitialHonestlyIMeanItThisTime) if Rejuv && $game_switches[:NotPlayerCharacter]
      i.itemInitial = i.itemRecycle = nil
      i.form = i.getForm(i)
      i.calcStats
    end
    # Set variables to field effect values
    $game_variables[:Field_Effect_End_Of_Battle] = @field.effect
    $game_variables[:Field_Counter_End_Of_Battle] = @field.counter
    $game_variables[:Weather_End_Of_Battle] = @weather

    PBDebug.close # close log file at end of battle (also transfers any leftover logs from buffer to file)
    return @decision
  end

  # Accepts array of [[battler, hploss]]
  # Inspired by Battler.pbReduceHP + faint check
  def pbReduceBattlersHP(mons, anim = false)
    return if mons == []

    changes = []
    mons.each do |pair|
      battler, amount = pair
      if amount >= battler.hp
        amount = battler.hp
      elsif amount <= 0 && !battler.isFainted?
        amount = 1
      end
      oldhp = battler.hp
      battler.hp -= amount
      raise _INTL("HP less than 0") if battler.hp < 0
      raise _INTL("HP greater than total HP") if battler.hp > battler.totalhp

      changes.push [battler, oldhp] if amount > 0
    end
    @battle.scene.pbHPChanged(changes, anim) if changes.length > 0
    changes.each do |pair|
      battler = pair[0]
      battler.pbFaint if battler.isFainted?
    end
  end
end
