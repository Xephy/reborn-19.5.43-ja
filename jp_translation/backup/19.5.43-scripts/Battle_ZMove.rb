################################################################################
# Z-Move damage
################################################################################
def ZMoveBaseDamage(oldmove)
  case oldmove.move
    when :MEGADRAIN      then return 120
    when :WEATHERBALL    then return 160
    when :HEX            then return 160
    when :GEARGRIND      then return 180
    when :VCREATE        then return 220
    when :FLYINGPRESS    then return 170
    when :COREENFORCER   then return 140
    # Variable Power Moves from now
    when :CRUSHGRIP      then return 190
    when :FLAIL          then return 160
    when :FRUSTRATION    then return 160
    when :NATURALGIFT    then return 160
    when :PRESENT        then return 100
    when :RETURN         then return 160
    when :SPITUP         then return 100
    when :TRUMPCARD      then return 160
    when :WRINGOUT       then return 190
    when :BEATUP         then return 100
    when :FLING          then return 100
    when :POWERTRIP      then return 160
    when :PUNISHMENT     then return 160
    when :ELECTROBALL    then return 160
    when :ERUPTION       then return 200
    when :HEATCRASH      then return 160
    when :GRASSKNOT      then return 160
    when :GYROBALL       then return 160
    when :HEAVYSLAM      then return 160
    when :LOWKICK        then return 160
    when :REVERSAL       then return 160
    when :MAGNITUDE      then return 140
    when :STOREDPOWER    then return 160
    when :WATERSPOUT     then return 200
    # Multi-hit moves with base Z power above 100
    when :TRIPLEKICK     then return 120
    when :DOUBLEHIT      then return 140
    when :BONERUSH       then return 140
    when :BULLETSEED     then return 140
    when :ICICLESPEAR    then return 140
    when :PINMISSILE     then return 140
    when :ROCKBLAST      then return 140
    when :TAILSLAP       then return 140
    # OHKO moves
    when :FISSURE        then return 180
    when :GUILLOTINE     then return 180
    when :HORNDRILL      then return 180
    when :SHEERCOLD      then return 180
  end
  check = oldmove.basedamage
  if check < 56
    return 100
  elsif check < 66
    return 120
  elsif check < 76
    return 140
  elsif check < 86
    return 160
  elsif check < 96
    return 175
  elsif check < 101
    return 180
  elsif check < 111
    return 185
  elsif check < 126
    return 190
  elsif check < 131
    return 195
  elsif check > 139
    return 200
  end
end

################################################################################
# Status Move Z-Power effects
################################################################################
def pbZStatus(battle, move, attacker)
  z_effect = PBStuff::ZSTATUSEFFECTS[move]

  # Curse normally boosts attack, but if ghost type it heals instead.
  if move == :CURSE && attacker.hasType?(:GHOST)
    z_effect = [:heal]
  end

  # Single stat boosting z-move
  if z_effect.length == 2
    if attacker.pbCanIncreaseStatStage?(z_effect[0], false, ignoreContrary: true)
      attacker.pbIncreaseStat(z_effect[0], z_effect[1], abilitymessage: false, ignoreContrary: true)
      boostlevel = ["", "sharply ", "drastically "]
      battle.pbDisplayBrief(_INTL("{1}'s Z-Power {2}boosted its {3}!", attacker.pbThis, boostlevel[z_effect[1] - 1], attacker.pbGetStatName(z_effect[0])))
      return
    end
  end

  # Special effect
  case z_effect[0]
    when :allstat1
      increment = 1
      increment = 2 if battle.FE == :CITY && [:CONVERSION, :HAPPYHOUR, :CELEBRATE].include?(move)
      increment = 2 if battle.FE == :BACKALLEY && move == :CONVERSION
      for stat in [PBStats::ATTACK, PBStats::DEFENSE, PBStats::SPATK, PBStats::SPDEF, PBStats::SPEED]
        if attacker.pbCanIncreaseStatStage?(stat, false, ignoreContrary: true)
          attacker.pbIncreaseStat(stat, increment, abilitymessage: false, ignoreContrary: true)
        end
      end
      battle.pbDisplayBrief(_INTL("{1}'s Z-Power boosted its stats!", attacker.pbThis)) if increment == 1
      battle.pbDisplayBrief(_INTL("{1}'s Z-Power sharply boosted its stats!", attacker.pbThis)) if increment == 2
    when :crit1
      if attacker.effects[:FocusEnergy] < 3
        attacker.effects[:FocusEnergy] += 2
        attacker.effects[:FocusEnergy] = 3 if attacker.effects[:FocusEnergy] > 3
        battle.pbDisplayBrief(_INTL("{1}'s Z-Power is getting it pumped!", attacker.pbThis))
      end
    when :reset
      for i in [PBStats::ATTACK, PBStats::DEFENSE, PBStats::SPEED, PBStats::SPATK, PBStats::SPDEF, PBStats::EVASION, PBStats::ACCURACY]
        if attacker.stages[i] < 0
          attacker.stages[i] = 0
        end
      end
      battle.pbDisplayBrief(_INTL("{1}'s Z-Power returned its decreased stats to normal!", attacker.pbThis))
    when :heal
      attacker.pbRecoverHP(attacker.totalhp, false)
      battle.pbDisplayBrief(_INTL("{1}'s Z-Power restored its health!", attacker.pbThis))
    when :heal2
      attacker.effects[:ZHeal] = true
    when :centre
      attacker.effects[:FollowMe] = true
      if !attacker.pbPartner.isFainted?
        attacker.pbPartner.effects[:FollowMe] = false
        attacker.pbPartner.effects[:RagePowder] = false
        battle.pbDisplayBrief(_INTL("{1}'s Z-Power made it the centre of attention!", attacker.pbThis))
      end
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
    desc += " A Ghost-type user is fully healed instead."
  elsif [:COPYCAT, :MEFIRST, :MIRRORMOVE].include?(move)
    desc += " A copied damaging move becomes a Z-Move."
  elsif [:ASSIST, :METRONOME, :NATUREPOWER, :SLEEPTALK].include?(move)
    desc += " A called damaging move becomes a Z-Move."
  end
  return desc
end

################################################################################
# Acid Downpour
################################################################################
class PokeBattle_Move_800 < PokeBattle_Move
  def pbEffect(attacker, opponent, hitnum = 0, alltargets = nil, showanimation = true)
    ret = super(attacker, opponent, hitnum, alltargets, showanimation)
    if @battle.FE == :WASTELAND &&
       !opponent.isFainted? && opponent.damagestate.calcdamage > 0 && !opponent.damagestate.substitute &&
       ((!opponent.hasType?(:POISON) && !opponent.hasType?(:STEEL)) || opponent.corroded) &&
       (opponent.ability != :IMMUNITY || opponent.moldbroken) &&
       (opponent.ability != :SHIELDDUST || opponent.moldbroken)
      rnd = @battle.pbRandom(4)
      # Poison Heal, Toxic Boost and Crested Zangoose ignore the random status and instead get poisoned.
      rnd = 3 if opponent.ability == :POISONHEAL || opponent.ability == :TOXICBOOST || opponent.crested == :ZANGOOSE
      case rnd
        when 0
          if opponent.pbCanBurn?(false)
            opponent.pbBurn(attacker)
            @battle.pbDisplay(_INTL("{1} was burned!", opponent.pbThis))
          end
        when 1
          if opponent.pbCanFreeze?(false)
            opponent.pbFreeze
            @battle.pbDisplay(_INTL("{1} was frozen solid!", opponent.pbThis))
          end
        when 2
          if opponent.pbCanParalyze?(false)
            opponent.pbParalyze(attacker)
            @battle.pbDisplay(_INTL("{1} is paralyzed! It may be unable to move!", opponent.pbThis))
          end
        when 3
          if opponent.pbCanPoison?(false)
            opponent.pbPoison(attacker)
            @battle.pbDisplay(_INTL("{1} was poisoned!", opponent.pbThis))
          end
      end
    end
    return ret
  end
end

################################################################################
# Bloom Doom
################################################################################
class PokeBattle_Move_801 < PokeBattle_Move
  def pbEffect(attacker, opponent, hitnum = 0, alltargets = nil, showanimation = true)
    ret = super(attacker, opponent, hitnum, alltargets, showanimation)
    if @battle.canChangeFE?([:GRASSY, :FOREST, :FLOWERGARDEN1, :FLOWERGARDEN2, :FLOWERGARDEN3, :FLOWERGARDEN4, :FLOWERGARDEN5])
      @battle.setField(:GRASSY, 3)
      @battle.pbDisplay(_INTL("The terrain became grassy!"))
    end
    return ret
  end
end

################################################################################
# Shattered Psyche
################################################################################
class PokeBattle_Move_802 < PokeBattle_Move
  def pbEffect(attacker, opponent, hitnum = 0, alltargets = nil, showanimation = true)
    ret = super(attacker, opponent, hitnum, alltargets, showanimation)
    if @battle.FE == :PSYTERRAIN
      if opponent.pbCanConfuse?(false, inflictor: attacker)
        opponent.effects[:Confusion] = 2 + @battle.pbRandom(4)
        @battle.pbCommonAnimation("Confusion", opponent, nil)
        @battle.pbDisplay(_INTL("The field got too weird for {1}!", opponent.pbThis(true)))
      end
    end
    return ret
  end
end

################################################################################
# Stoked Sparksurfer
################################################################################
class PokeBattle_Move_803 < PokeBattle_Move
  def pbEffect(attacker, opponent, hitnum = 0, alltargets = nil, showanimation = true)
    ret = super(attacker, opponent, hitnum, alltargets, showanimation)
    if @battle.canChangeFE?(:ELECTERRAIN)
      @battle.setField(:ELECTERRAIN, 3)
      @battle.pbDisplay(_INTL("The terrain became electrified!"))
    end
    return ret
  end

  def pbAdditionalEffect(attacker, opponent)
    return false if !opponent.pbCanParalyze?(false)

    opponent.pbParalyze(attacker)
    @battle.pbDisplay(_INTL("{1} was paralyzed! It may be unable to move!", opponent.pbThis))
    return true
  end
end

################################################################################
# Extreme Evoboost
################################################################################
class PokeBattle_Move_804 < PokeBattle_Move
  def pbEffect(attacker, opponent, hitnum = 0, alltargets = nil, showanimation = true)
    if !attacker.pbCanIncreaseStatStage?(PBStats::SPATK, false) &&
       !attacker.pbCanIncreaseStatStage?(PBStats::SPDEF, false) &&
       !attacker.pbCanIncreaseStatStage?(PBStats::SPEED, false) &&
       !attacker.pbCanIncreaseStatStage?(PBStats::ATTACK, false) &&
       !attacker.pbCanIncreaseStatStage?(PBStats::DEFENSE, false)
      @battle.pbDisplay(_INTL("{1}'s stats won't go any higher!", attacker.pbThis))
      return -1
    end
    pbShowAnimation(@move, attacker, nil, hitnum, alltargets, showanimation)
    for stat in 1..5
      attacker.pbIncreaseStat(stat, 2, abilitymessage: false, statsource: attacker)
    end
    return 0
  end
end

################################################################################
# Genesis Supernova
################################################################################
class PokeBattle_Move_805 < PokeBattle_Move
  def pbEffect(attacker, opponent, hitnum = 0, alltargets = nil, showanimation = true)
    ret = super(attacker, opponent, hitnum, alltargets, showanimation)
    if @battle.canChangeFE?(:PSYTERRAIN)
      @battle.setField(:PSYTERRAIN, 5)
      @battle.pbDisplay(_INTL("The terrain became mysterious!"))
    end
    return ret
  end
end

################################################################################
# Malicious Moonsault
################################################################################
class PokeBattle_Move_806 < PokeBattle_Move
  def pbModifyDamage(damagemult, attacker, opponent)
    damagemult *= 2.0 if opponent.effects[:Minimize]
    return damagemult
  end
end

################################################################################
# Splintered Stormshards
################################################################################
class PokeBattle_Move_807 < PokeBattle_Move
  def pbEffect(attacker, opponent, hitnum = 0, alltargets = nil, showanimation = true)
    ret = super(attacker, opponent, hitnum, alltargets, showanimation)
    if @battle.canChangeFE?
      @battle.breakField
      @battle.pbDisplay(_INTL("The field was devastated!"))
    end
    return ret
  end
end

################################################################################
# Clangorous Soulblaze
################################################################################
class PokeBattle_Move_808 < PokeBattle_Move
  def pbOnStartUse(attacker)
    @loopcount = 0
    @totaldamage = 0
    return true
  end

  def pbEffect(attacker, opponent, hitnum = 0, alltargets = nil, showanimation = true)
    ret = super(attacker, opponent, hitnum, alltargets, showanimation)
    @loopcount += 1
    @totaldamage += ret
    if @totaldamage > 0 && (!attacker.midwayThroughMove || @loopcount == alltargets.length)
      if !attacker.pbCanIncreaseStatStage?(PBStats::SPATK, false) &&
         !attacker.pbCanIncreaseStatStage?(PBStats::SPDEF, false) &&
         !attacker.pbCanIncreaseStatStage?(PBStats::SPEED, false) &&
         !attacker.pbCanIncreaseStatStage?(PBStats::ATTACK, false) &&
         !attacker.pbCanIncreaseStatStage?(PBStats::DEFENSE, false)
        @battle.pbDisplay(_INTL("{1}'s stats won't go any higher!", attacker.pbThis))
      end
      for stat in 1..5
        attacker.pbIncreaseStat(stat, 1, abilitymessage: false, statsource: attacker)
      end
    end
    return ret
  end
end

################################################################################
# Guardian of Alola
################################################################################
class PokeBattle_Move_809 < PokeBattle_Move
  def pbEffect(attacker, opponent, hitnum = 0, alltargets = nil, showanimation = true)
    hploss = (opponent.hp * 0.75).floor
    hploss = (opponent.totalhp * 0.75).floor if @battle.FE == :NEWWORLD
    return pbEffectFixedDamage(hploss, attacker, opponent, hitnum, alltargets, showanimation)
  end

  def pbShowAnimation(id, attacker, opponent, hitnum = 0, alltargets = nil, showanimation = true)
    return if !showanimation

    case attacker.species
      when :TAPULELE
        @battle.pbAnimation(:GUARDIANOFALOLALELE, attacker, opponent, hitnum)
      when :TAPUBULU
        @battle.pbAnimation(:GUARDIANOFALOLABULU, attacker, opponent, hitnum)
      when :TAPUFINI
        @battle.pbAnimation(:GUARDIANOFALOLAFINI, attacker, opponent, hitnum)
      else
        @battle.pbAnimation(id, attacker, opponent, hitnum) # Tapu Koko
    end
  end
end
