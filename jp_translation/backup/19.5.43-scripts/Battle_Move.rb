class PokeBattle_Move
  attr_accessor   :move
  attr_reader     :battle
  attr_accessor   :name
  attr_accessor   :data
  attr_accessor   :basemove
  attr_accessor   :pp
  attr_accessor   :totalpp
  attr_accessor   :zmove
  attr_reader     :user
  attr_reader     :function
  attr_accessor   :type
  attr_reader     :category
  attr_accessor   :basedamage
  attr_reader     :accuracy
  attr_reader     :maxpp
  attr_reader     :target
  attr_reader     :desc
  attr_accessor   :priority
  attr_reader     :effect
  attr_reader     :moreeffect
  attr_reader     :recoil
  attr_accessor :fieldmessageshown
  attr_accessor :fieldmessageshown_type

  ################################################################################
  # Creating a move
  ################################################################################
  def initialize(battle, move, user, zbase = nil)
    @battle = battle
    @move = move.move
    @data = $cache.moves[@move]
    @name = @data.name
    @basemove   = move
    @pp         = move.pp # Can be changed with Mimic/Transform
    @zmove      = false
    if user.is_a?(PokeBattle_Battler)
      # Move instance is serialized and sent over network for Online battles.
      # As such it can't contain Battler because it contains Battle which is not serializable.
      raise "move user needs to be PokeBattle_Pokemon"
    end
    @user       = user
    if @data
      @function   = @data.function
      @type       = @data.type
      @category   = @data.category
      @basedamage = @data.basedamage
      @accuracy   = @data.accuracy
      @maxpp      = @data.maxpp
      @target     = @data.target
      @desc       = @data.desc
      @priority   = @data.priority ? @data.priority : 0
      @effect     = @data.checkFlag?(:effect, 0)
      @moreeffect = @data.checkFlag?(:moreeffect, 0)
      @recoil     = @data.checkFlag?(:recoil, 0)
    end
    if !zbase.nil?
      @zmove      = true
      if PBStuff::TYPETOZCRYSTAL[zbase.type] == user.item
        @category   = zbase.category
        @name       = "Z-" + @name if zbase.basedamage == 0
        @basedamage = ZMoveBaseDamage(zbase) if zbase.basedamage > 0
        @maxpp = 0
      end
    end
  end

  def contactMove?
    return hasFlag?(:contact)
  end

  def canProtect?
    return !hasFlag?(:bypassprotect)
  end

  def canMagicCoat?
    return hasFlag?(:magiccoat)
  end

  def canSnatch?
    return hasFlag?(:snatchable)
  end

  def canMirror?
    return !hasFlag?(:nonmirror)
  end

  def canFlinch?
    return false
  end

  def canThawUser?
    return hasFlag?(:defrost)
  end

  def highCritRate?
    return hasFlag?(:highcrit)
  end

  def isHealingMove?
    return hasFlag?(:healingmove)
  end

  def isDrainingMove?
    return hasFlag?(:drainingmove)
  end

  def punchMove?
    return hasFlag?(:punchmove)
  end

  def isSoundBased?
    return hasFlag?(:soundmove)
  end

  def unusableInGravity?
    return hasFlag?(:gravityblocked)
  end

  def isBeamMove?
    return hasFlag?(:beammove)
  end

  def sharpMove?
    return hasFlag?(:sharpmove)
  end

  def windMove?
    return hasFlag?(:windmove)
  end

  def powderMove?
    return hasFlag?(:powdermove)
  end

  def hasFlag?(flag)
    return @data.nil? ? false : @data.checkFlag?(flag)
  end

  # This is the code actually used to generate a PokeBattle_Move object.  The
  # object generated is a subclass of this one which depends on the move's
  # function code (found in the script section PokeBattle_MoveEffect).
  def PokeBattle_Move.pbFromPBMove(battle, move, user, zbase = nil)
    className = nil if !move
    className = sprintf("PokeBattle_Move_%03X", $cache.moves[move.move].function) if move
    if !className.nil?
      if Object.const_defined?(className)
        return Kernel.const_get(className).new(battle, move, user, zbase)
      else
        return PokeBattle_UnimplementedMove.new(battle, move, user, zbase)
      end
    else
      return nil
    end
  end

  ################################################################################
  # About the move
  ################################################################################
  def totalpp
    return @totalpp if @totalpp && @totalpp > 0
    return @basemove.totalpp if @basemove
  end

  def pbType(attacker, type = @type)
    case @battle.FE
      when :ASHENBEACH        then type = :FIGHTING   if @move == :STRENGTH
      when :GLITCH            then type = :NORMAL     if Glitchtypes.include?(type)
      when :WATERSURFACE      then type = :WATER      if @move == :SHOREUP
      when :MURKWATERSURFACE  then type = :WATER      if [:MUDSLAP, :MUDBOMB, :MUDBARRAGE, :MUDSHOT, :THOUSANDWAVES, :SHOREUP].include?(@move)
      when :FAIRYTALE         then type = :STEEL      if [:SACREDSWORD, :CUT, :SLASH, :SECRETSWORD].include?(@move)
      when :STARLIGHT         then type = :FAIRY      if !Rejuv && [:SOLARBEAM, :SOLARBLADE].include?(@move)
      when :DIMENSIONAL       then type = :DARK       if @move == :RAGE
      when :FROZENDIMENSION   then type = :DARK       if @move == :RAGE
      when :DRAGONSDEN        then type = :ROCK       if Rejuv && [:ROCKCLIMB, :STRENGTH].include?(@move)
      when :DEEPEARTH         then type = :GROUND     if @move == :TOPSYTURVY
    end
    if !PBStuff::ZMOVES.include?(@move)
      case attacker.ability
        when :NORMALIZE   then type = :NORMAL
        when :PIXILATE    then type = :FAIRY    if type == :NORMAL && @battle.FE != :GLITCH
        when :AERILATE    then type = :FLYING   if type == :NORMAL
        when :GALVANIZE   then type = :ELECTRIC if type == :NORMAL
        when :REFRIGERATE then type = :ICE      if type == :NORMAL
        when :DUSKILATE   then type = :DARK     if type == :NORMAL && @battle.FE != :GLITCH
        when :LIQUIDVOICE then type = @battle.FE == :ICY ? :ICE : :WATER if isSoundBased?
      end
    end
    case attacker.crested
      when :SIMISEAR  then type = :WATER    if type == :NORMAL
      when :SIMIPOUR  then type = :GRASS    if type == :NORMAL
      when :SIMISAGE  then type = :FIRE     if type == :NORMAL
      when :LUXRAY    then type = :ELECTRIC if type == :NORMAL
      when :SAWSBUCK
        case attacker.form
          when 0  then type = :WATER  if type == :NORMAL
          when 1  then type = :FIRE   if type == :NORMAL
          when 2  then type = :GROUND if type == :NORMAL
          when 3  then type = :ICE    if type == :NORMAL
        end
    end
    if attacker.effects[:Electrify] || (type == :NORMAL && @battle.state.effects[:IonDeluge])
      type = :ELECTRIC
    end
    return type
  end

  def pbIsPhysical?(attacker, type = @type)
    return !PBTypes.isSpecialType?(type) && @category != :status if @battle.FE == :GLITCH

    return @category == :physical
  end

  def pbIsSpecial?(attacker, type = @type)
    return PBTypes.isSpecialType?(type) && @category != :status if @battle.FE == :GLITCH

    return @category == :special
  end

  def pbIsStatus?
    return @category == :status
  end

  def betterCategory(attacker, type = @type)
    return :physical if pbIsPhysical?(attacker, type)
    return :special if pbIsSpecial?(attacker, type)
    return :status if pbIsStatus?
  end

  def pbHitsSpecialStat?(attacker, type = @type)
    return false if @function == 0x122  # Psyshock/Psystrike
    return true if @function == 0x204   # Matrix Shot

    return pbIsSpecial?(attacker, type)
  end

  def pbHitsPhysicalStat?(attacker, type = @type)
    return false if @function == 0x204
    return true if @function == 0x122

    return pbIsPhysical?(attacker, type)
  end

  def pbTargetsAll?(attacker)
    if attacker.pbTarget(self) == :AllOpposing
      # TODO: should apply even if partner faints during an attack
      numtargets = 0
      numtargets += 1 if !attacker.pbOpposing1.isFainted?
      numtargets += 1 if !attacker.pbOpposing2.isFainted?
      return numtargets > 1
    elsif attacker.pbTarget(self) == :AllNonUsers
      # TODO: should apply even if partner faints during an attack
      numtargets = 0
      numtargets += 1 if !attacker.pbOpposing1.isFainted?
      numtargets += 1 if !attacker.pbOpposing2.isFainted?
      numtargets += 1 if !attacker.pbPartner.isFainted?
      return numtargets > 1
    end
    return false
  end

  def pbDragonDartTargetting(attacker)
    opp1 = attacker.pbOpposing1
    opp2 = attacker.pbOpposing2
    return [opp1] if !@battle.doublebattle
    return [opp1] if opp2.isFainted?
    return [opp2] if opp1.isFainted?
    return [opp1] if !isValidDragonDartsTarget(attacker, opp2)
    return [opp2] if !isValidDragonDartsTarget(attacker, opp1)

    return [opp1, opp2]
  end

  def isValidDragonDartsTarget(attacker, opponent)
    darttype = pbType(attacker)
    typemod = self.pbTypeModifier(darttype, attacker, opponent)
    typemod = self.fieldTypeChange(attacker, opponent, typemod)
    typemod = self.overlayTypeChange(attacker, opponent, typemod)
    types = [darttype, *self.getSecondaryType(attacker)]

    # removing successful redirectors from the target list to ensure that darts only have 1 target to allow redirection
    unless [:STALWART, :PROPELLERTAIL].include?(attacker.ability)
      return false if opponent.effects[:RagePowder] && !(attacker.ability == :OVERCOAT || attacker.hasType?(:GRASS) || attacker.hasWorkingItem(:SAFETYGOGGLES))
      return false if opponent.effects[:FollowMe]

      unless [:MOLDBREAKER, :TERAVOLT, :TURBOBLAZE].include?(attacker.ability)
        return false if types.include?(:WATER) && opponent.ability == :STORMDRAIN
        return false if types.include?(:ELECTRIC) && opponent.ability == :LIGHTNINGROD
      end
    end

    return false if PBStuff::TWOTURNMOVE.include?(opponent.effects[:TwoTurnAttack])
    return false if opponent.effects[:SkyDrop]
    return false if opponent.effects[:Protect]
    return false if opponent.pbOwnSide.effects[:QuickGuard] && priorityCheck(attacker) > 0
    return false if typemod == 0

    unless [:MOLDBREAKER, :TERAVOLT, :TURBOBLAZE].include?(attacker.ability)
      # checking Storm drain and lightning rod as immunity here so that Stalwart and Propeller tail users avoid targeting into these mons directly
      # users without redirection immunity don't reach this point in the check
      return false if opponent.ability == :WONDERGUARD && typemod <= 4
      return false if types.include?(:WATER) && [:DRYSKIN, :WATERABSORB, :STORMDRAIN].include?(opponent.ability)
      return false if types.include?(:ELECTRIC) && [:MOTORDRIVE, :VOLTABSORB, :LIGHTNINGROD].include?(opponent.ability)
      return false if types.include?(:FIRE) && opponent.ability == :FLASHFIRE && @battle.FE != :FROZENDIMENSION
      return false if types.include?(:FIRE) && opponent.ability == :MAGMAARMOR && [:VOLCANICTOP, :DRAGONSDEN, :INFERNAL].include?(@battle.FE)
      return false if types.include?(:GRASS) && opponent.ability == :SAPSIPPER
    end

    if Rejuv && @battle.FE == :GLITCH && opponent.species == :GENESECT
      return false if types.include?(:WATER) && opponent.hasWorkingItem(:DOUSEDRIVE)
      return false if types.include?(:ELECTRIC) && opponent.hasWorkingItem(:SHOCKDRIVE)
      return false if types.include?(:FIRE) && opponent.hasWorkingItem(:BURNDRIVE)
      return false if types.include?(:ICE) && opponent.hasWorkingItem(:CHILLDRIVE)
    end

    return false if types.include?(:FIRE) && opponent.crested == :DRUDDIGON
    return false if types.include?(:GRASS) && opponent.crested == :WHISCASH
    return false if types.include?(:GROUND) && opponent.crested == :SKUNTANK
    return false if types.include?(:GROUND) && opponent.isAirborne?(moldbreakcheck: true)

    return false if attacker.ability == :PRANKSTER && opponent.hasType?(:DARK) && @battle.choices[attacker.index][2] != self && @battle.FE != :BEWITCHED

    return true
  end

  # i am so upset, i have no words for my utter disgust at this mess, god fuck this move, i'd rather deal with Dragon Darts
  def smartDamageCategory(attacker, opponent)
    if @battle.FE == :GLITCH
      @category = PBTypes.isSpecialType?(@type) ? :special : :physical
      return
    end
    # Calculates how much Attack and SpAtk attacker has
    calcattackstage = attacker.stages[PBStats::ATTACK] + 6
    # if photon geyser gets to be more accurate in calculation than normal, then shell side arm also gets to as well
    calcatkmult = 1.0
    calcatkmult *= 1.5 if attacker.hasWorkingItem(:CHOICEBAND)
    if attacker.ability == :HUSTLE
      calcatkmult *= [:BACKALLEY, :CITY].include?(@battle.FE) ? 1.75 : 1.5
    end
    calcatkmult *= 1.5 if attacker.ability == :TOXICBOOST && (attacker.status == :POISON || @battle.FE == :CORROSIVEMIST || ([:CORROSIVE, :WASTELAND, :MURKWATERSURFACE].include?(@battle.FE) && !attacker.isAirborne?))
    calcatkmult *= 1.5 if attacker.ability == :GUTS && !attacker.status.nil?
    calcatkmult *= 0.5 if attacker.ability == :SLOWSTART && attacker.turncount < 5 && @battle.FE != :DEEPEARTH
    calcatkmult *= 2 if (attacker.ability == :PUREPOWER && @battle.FE != :PSYTERRAIN) || attacker.ability == :HUGEPOWER
    if (@battle.pbWeather == :SUNNYDAY && !attacker.hasWorkingItem(:UTILITYUMBRELLA)) || @battle.ProgressiveFieldCheck(PBFields::FLOWERGARDEN) || @battle.FE == :BEWITCHED || attacker.crested == :CHERRIM
      calcatkmult *= 1.5 if attacker.ability == :FLOWERGIFT && attacker.species == :CHERRIM
      calcatkmult *= 1.5 if attacker.pbPartner.ability == :FLOWERGIFT && attacker.pbPartner.species == :CHERRIM
    end
    calcatkmult *= 2 if attacker.hasWorkingItem(:THICKCLUB) && (attacker.pokemon.species == :CUBONE || attacker.pokemon.species == :MAROWAK)
    calcatkmult *= 0.5 if attacker.status == :BURN && !(attacker.ability == :GUTS && !attacker.status.nil?)
    # end attack boosts
    calcattack = (attacker.attack * PBStats::StageMul[calcattackstage] * calcatkmult).floor
    calcspatkstage = attacker.stages[PBStats::SPATK] + 6
    # same for special attack
    calcspatkmult = 1.0
    calcspatkmult *= 1.5 if attacker.hasWorkingItem(:CHOICESPECS)
    calcspatkmult *= 2 if attacker.hasWorkingItem(:DEEPSEATOOTH) && attacker.pokemon.species == :CLAMPERL
    calcspatkmult *= 2 if attacker.hasWorkingItem(:LIGHTBALL) && attacker.pokemon.species == :PIKACHU
    calcspatkmult *= 1.5 if attacker.ability == :FLAREBOOST && (attacker.status == :BURN || [:BURNING, :VOLCANIC, :INFERNAL].include?(@battle.FE)) && @battle.FE != :FROZENDIMENSION
    calcspatkmult *= 1.5 if [:MINUS, :PLUS].include?(attacker.ability) && ([:MINUS, :PLUS].include?(attacker.pbPartner.ability) || @battle.FE == :SHORTCIRCUIT || (Rejuv && @battle.FE == :ELECTERRAIN))
    calcspatkmult *= 1.5 if attacker.ability == :SOLARPOWER && (@battle.pbWeather == :SUNNYDAY && !attacker.hasWorkingItem(:UTILITYUMBRELLA)) && @battle.FE != :FROZENDIMENSION
    calcspatkmult *= 1.3 if attacker.pbPartner.ability == :BATTERY && Rejuv
    calcspatkmult *= 2 if attacker.ability == :PUREPOWER && @battle.FE == :PSYTERRAIN
    # end spatk boosts
    calcspatk = (attacker.spatk * PBStats::StageMul[calcspatkstage] * calcspatkmult).floor
    # Calculates how much Defense and SpDef opponent has
    calcdefensestage = opponent.stages[PBStats::DEFENSE] + 6
    # aaaand Defense
    calcdefmult = 1.0
    calcdefmult *= 1.5 if @battle.FE == :SNOWYMOUNTAIN && opponent.hasType?(:ICE) && @battle.pbWeather == :HAIL
    calcdefmult *= 1.5 if @battle.FE == :ICY && opponent.hasType?(:ICE) && @battle.pbWeather == :HAIL
    calcdefmult *= 1.5 if opponent.ability == :MARVELSCALE && (!opponent.status.nil? || ([:MISTY, :RAINBOW, :FAIRYTALE, :DRAGONSDEN, :STARLIGHT].include?(@battle.FE) || @battle.state.effects[:MISTY] > 0)) && !opponent.moldbroken
    calcdefmult *= 1.5 if opponent.ability == :GRASSPELT && ([:GRASSY, :FOREST].include?(@battle.FE) || @battle.state.effects[:GRASSY] > 0) # Grassy Field
    calcdefmult *= 2.0 if opponent.ability == :FURCOAT && !opponent.moldbroken
    if @battle.FE == :CLOUDS
      calcdefmult *= 4.0 if opponent.ability == :FLUFFY && attacker.ability != :LONGREACH && !opponent.moldbroken
    else
      calcdefmult *= 2.0 if opponent.ability == :FLUFFY && attacker.ability != :LONGREACH && !opponent.moldbroken
    end
    calcdefmult *= 2.0 if opponent.hasWorkingItem(:METALPOWDER) && opponent.pokemon.species == :DITTO && !opponent.effects[:Transform]
    # end defense boosts
    calcdefense = (opponent.defense * PBStats::StageMul[calcdefensestage] * calcdefmult).floor
    calcspdefstage = opponent.stages[PBStats::SPDEF] + 6
    # don't forget spdef
    calcspdefmult = 1.0
    calcspdefmult *= 1.5 if @battle.FE == :DESERT && opponent.hasType?(:GROUND)
    calcspdefmult *= 1.5 if @battle.FE == :MISTY && opponent.hasType?(:FAIRY)
    if ((@battle.pbWeather == :SUNNYDAY && !opponent.hasWorkingItem(:UTILITYUMBRELLA)) || opponent.crested == :CHERRIM || @battle.ProgressiveFieldCheck(PBFields::FLOWERGARDEN) || @battle.FE == :BEWITCHED) && !opponent.moldbroken
      calcspdefmult *= 1.5 if opponent.ability == :FLOWERGIFT && opponent.species == :CHERRIM
      calcspdefmult *= 1.5 if opponent.pbPartner.ability == :FLOWERGIFT && opponent.pbPartner.species == :CHERRIM
    end
    calcspdefmult *= 2.0 if opponent.ability == :ICESCALES && !opponent.moldbroken
    calcspdefmult *= 1.5 if opponent.hasWorkingItem(:ASSAULTVEST)
    calcspdefmult *= 2.0 if opponent.hasWorkingItem(:DEEPSEASCALE) && opponent.pokemon.species == :CLAMPERL
    # end spdef boosts
    calcspdef = (opponent.spdef * PBStats::StageMul[calcspdefstage] * calcspdefmult).floor

    # Compares difference between Atk/Def and SpAtk/SpDef to determine Physical or Special
    @category = (calcattack - calcdefense > calcspatk - calcspdef) ? :physical : :special
    return
  end

  # These functions are intended to be subclassed
  def pbNumHits(attacker)
    return 1
  end

  def pbIsMultiHit # not the same as pbNumHits>1
    return false
  end

  def pbTwoTurnAttack(attacker, checking = false)
    return false
  end

  def pbAdditionalEffect(attacker, opponent)
  end

  def pbSecondAdditionalEffect(attacker, opponent)
  end

  def pbCanUseWhileAsleep?
    return false
  end

  ################################################################################
  # This move's type effectiveness
  ################################################################################
  def pbTypeModifier(type, attacker, opponent)
    atype = type # attack type
    otype1 = opponent.type1
    otype2 = opponent.type2
    if otype1 == :FLYING && opponent.effects[:Roost]
      otype1 = otype2.nil? ? :QMARKS : otype2
    end
    if otype2 == :FLYING && opponent.effects[:Roost]
      otype2 = nil
    end
    if otype1 == :FIRE && opponent.effects[:BurnUp]
      otype1 = otype2.nil? ? :QMARKS : otype2
    end
    if otype2 == :FIRE && opponent.effects[:BurnUp]
      otype2 = nil
    end
    mod1 = PBTypes.oneTypeEff(atype, otype1)
    mod2 = otype1 == otype2 || otype2.nil? ? 2 : PBTypes.oneTypeEff(atype, otype2)

    if attacker.ability == :SCRAPPY || opponent.effects[:Foresight]
      mod1 = 2 if otype1 == :GHOST && [:NORMAL, :FIGHTING].include?(atype)
      mod2 = 2 if otype2 == :GHOST && [:NORMAL, :FIGHTING].include?(atype)
    end
    if opponent.effects[:Ingrain] || opponent.effects[:SmackDown] || @battle.state.effects[:Gravity] != 0 || @battle.FE == :CAVE
      mod1 = 2 if otype1 == :FLYING && atype == :GROUND
      mod2 = 2 if otype2 == :FLYING && atype == :GROUND
    else
      return 4 if type == :GROUND && [otype1, otype2].include?(:FLYING) && (opponent.hasWorkingItem(:IRONBALL) || @move == :THOUSANDARROWS)
    end
    if @battle.FE == :HOLY
      mod1 = 4 if [:DARK, :GHOST].include?(otype1) && atype == :NORMAL
      mod2 = 4 if [:DARK, :GHOST].include?(otype2) && atype == :NORMAL
      mod1 = 4 if otype1 == :GHOST && @move == :SPIRITBREAK
      mod2 = 4 if otype2 == :GHOST && @move == :SPIRITBREAK
    end
    if @battle.FE == :UNDERWATER
      mod1 = 2 if otype1 == :WATER && atype == :WATER
      mod2 = 2 if otype2 == :WATER && atype == :WATER
    end
    if @battle.FE == :FAIRYTALE
      mod1 = 4 if otype1 == :DRAGON && atype == :STEEL
      mod2 = 4 if otype2 == :DRAGON && atype == :STEEL
    end
    if @battle.FE == :GLITCH
      mod1 = 2 if atype == :DRAGON
      mod2 = 2 if atype == :DRAGON
      mod1 = 0 if atype == :GHOST && otype1 == :PSYCHIC
      mod2 = 0 if atype == :GHOST && otype2 == :PSYCHIC
      mod1 = 4 if atype == :BUG && otype1 == :POISON
      mod2 = 4 if atype == :BUG && otype2 == :POISON
      mod1 = 4 if atype == :POISON && otype1 == :BUG
      mod2 = 4 if atype == :POISON && otype2 == :BUG
      mod1 = 2 if atype == :ICE && otype1 == :FIRE
      mod2 = 2 if atype == :ICE && otype2 == :FIRE
      mod1 = 1 if Rejuv && atype == :DARK && otype1 == :STEEL
      mod2 = 1 if Rejuv && atype == :DARK && otype2 == :STEEL
      mod1 = 1 if Rejuv && atype == :GHOST && otype1 == :STEEL
      mod2 = 1 if Rejuv && atype == :GHOST && otype2 == :STEEL
    end
    if @battle.FE == :HAUNTED
      mod1 = 2 if otype1 == :NORMAL && atype == :GHOST
      mod2 = 2 if otype2 == :NORMAL && atype == :GHOST
      mod1 = 4 if otype1 == :GHOST && @move == :SPIRITBREAK
      mod2 = 4 if otype2 == :GHOST && @move == :SPIRITBREAK
    end
    if @battle.FE == :BEWITCHED
      mod1 = 2 if otype1 == :GRASS && atype == :POISON
      mod2 = 2 if otype2 == :GRASS && atype == :POISON
      mod1 = 4 if otype1 == :STEEL && atype == :FAIRY
      mod2 = 4 if otype2 == :STEEL && atype == :FAIRY
      mod1 = 2 if otype1 == :DARK && atype == :FAIRY
      mod2 = 2 if otype2 == :DARK && atype == :FAIRY
      mod1 = 2 if otype1 == :FAIRY && atype == :DARK
      mod2 = 2 if otype2 == :FAIRY && atype == :DARK
    end
    if @battle.FE == :SKY
      mod1 = 4 if otype1 == :FLYING && @move == :BONEMERANG
      mod2 = 4 if otype2 == :FLYING && @move == :BONEMERANG
      mod1 = 4 if otype1 == :FLYING && attacker.ability == :LONGREACH
      mod2 = 4 if otype2 == :FLYING && attacker.ability == :LONGREACH
    end
    if (!Rejuv && @battle.FE == :FOREST) || @battle.ProgressiveFieldCheck(PBFields::FLOWERGARDEN, 2, 5)
      mod1 = 4 if otype1 == :GRASS && @move == :CUT
      mod2 = 4 if otype2 == :GRASS && @move == :CUT
    end
    if @battle.FE == :INFERNAL
      mod1 = 4 if otype1 == :GHOST && atype == :FIRE
      mod2 = 4 if otype2 == :GHOST && atype == :FIRE
    end
    if Rejuv && @battle.FE == :ELECTERRAIN
      mod1 = 2 if otype1 == :GROUND && atype == :ELECTRIC && attacker.ability == :TERAVOLT
      mod2 = 2 if otype2 == :GROUND && atype == :ELECTRIC && attacker.ability == :TERAVOLT
    end
    if opponent.effects[:MiracleEye]
      mod1 = 2 if otype1 == :DARK && atype == :PSYCHIC
      mod2 = 2 if otype2 == :DARK && atype == :PSYCHIC
    end
    if opponent.hasWorkingItem(:RINGTARGET)
      mod1 = 2 if mod1 == 0
      mod2 = 2 if mod2 == 0
    end
    mod2 = otype1 == otype2 ? 2 : mod2

    # Inversemode password/field
    if ($game_switches[:Inversemode] && !@battle.isOnline?) ^ (@battle.FE == :INVERSE)
      mod1 = 1 if mod1 == 0
      mod2 = 1 if mod2 == 0
      mod1 = 4 / mod1
      mod2 = 4 / mod2
    end
    if opponent.crested == :TORTERRA
      mod1 = 4 / mod1 if mod1 != 0
      mod2 = 4 / mod2 if mod2 != 0
    end
    # effects that remove type weaknesses, what is a type weakness changes if inverse battle applies or not so needs to be checked after
    if @battle.pbWeather == :STRONGWINDS
      mod1 = 2 if otype1 == :FLYING && mod1 > 2
      mod2 = 2 if otype2 == :FLYING && mod2 > 2
    end
    if @battle.FE == :DARKNESS3
      mod1 = 2 if [:DARK, :GHOST].include?(otype1) && mod1 > 2
      mod2 = 2 if [:DARK, :GHOST].include?(otype2) && mod2 > 2
    end
    if @battle.ProgressiveFieldCheck(PBFields::FLOWERGARDEN, 4, 5)
      mod1 = 2 if otype1 == :GRASS && mod1 > 2
      mod2 = 2 if otype2 == :GRASS && mod2 > 2
    end
    if @battle.FE == :SNOWYMOUNTAIN
      mod1 = 2 if otype1 == :ICE && opponent.ability == :ICESCALES && !opponent.moldbroken && mod1 > 2
      mod2 = 2 if otype2 == :ICE && opponent.ability == :ICESCALES && !opponent.moldbroken && mod2 > 2
    end
    if @battle.FE == :DRAGONSDEN
      mod1 = 2 if otype1 == :DRAGON && opponent.ability == :MULTISCALE && !opponent.moldbroken && mod1 > 2
      mod2 = 2 if otype2 == :DRAGON && opponent.ability == :MULTISCALE && !opponent.moldbroken && mod2 > 2
    end
    if @battle.FE == :BEWITCHED
      mod1 = 2 if otype1 == :FAIRY && (opponent.ability == :PASTELVEIL || opponent.pbPartner.ability == :PASTELVEIL) && !opponent.moldbroken && mod1 > 2
      mod2 = 2 if otype2 == :FAIRY && (opponent.ability == :PASTELVEIL || opponent.pbPartner.ability == :PASTELVEIL) && !opponent.moldbroken && mod2 > 2
    end
    # effects that ignore Inverse battles entirely
    if @move == :VENAMSKISS
      mod1 = 4 if otype1 == :STEEL
      mod2 = 4 if otype2 == :STEEL
    end
    if @move == :FREEZEDRY
      mod1 = 4 if otype1 == :WATER
      mod2 = 4 if otype2 == :WATER
    end
    return mod1 * mod2
  end

  def pbTypeModifierNonBattler(type, attacker, opponent)
    atype = type # attack type
    otype1 = opponent.type1
    otype2 = opponent.type2
    mod1 = PBTypes.oneTypeEff(atype, otype1)
    mod2 = otype1 == otype2 ? 2 : PBTypes.oneTypeEff(atype, otype2)

    if attacker.ability == :SCRAPPY
      mod1 = 2 if otype1 == :GHOST && [:NORMAL, :FIGHTING].include?(atype)
      mod2 = 2 if otype2 == :GHOST && [:NORMAL, :FIGHTING].include?(atype)
    end
    if @battle.FE == :CAVE || @battle.state.effects[:Gravity] != 0
      mod1 = 2 if otype1 == :FLYING && atype == :GROUND
      mod2 = 2 if otype2 == :FLYING && atype == :GROUND
    else
      return 4 if type == :GROUND && opponent.hasType?(:FLYING) && (opponent.item == :IRONBALL || @move == :THOUSANDARROWS)
    end
    if @battle.FE == :HOLY
      mod1 = 4 if [:DARK, :GHOST].include?(otype1) && atype == :NORMAL
      mod2 = 4 if [:DARK, :GHOST].include?(otype2) && atype == :NORMAL
      mod1 = 4 if otype1 == :GHOST && @move == :SPIRITBREAK
      mod2 = 4 if otype2 == :GHOST && @move == :SPIRITBREAK
    end
    if @battle.FE == :UNDERWATER
      mod1 = 2 if otype1 == :WATER && atype == :WATER
      mod2 = 2 if otype2 == :WATER && atype == :WATER
    end
    if @battle.FE == :FAIRYTALE
      mod1 = 4 if otype1 == :DRAGON && atype == :STEEL
      mod2 = 4 if otype2 == :DRAGON && atype == :STEEL
    end
    if @battle.FE == :GLITCH
      mod1 = 2 if atype == :DRAGON
      mod2 = 2 if atype == :DRAGON
      mod1 = 0 if atype == :GHOST && otype1 == :PSYCHIC
      mod2 = 0 if atype == :GHOST && otype2 == :PSYCHIC
      mod1 = 4 if atype == :BUG && otype1 == :POISON
      mod2 = 4 if atype == :BUG && otype2 == :POISON
      mod1 = 4 if atype == :POISON && otype1 == :BUG
      mod2 = 4 if atype == :POISON && otype2 == :BUG
      mod1 = 2 if atype == :ICE && otype1 == :FIRE
      mod2 = 2 if atype == :ICE && otype2 == :FIRE
      mod1 = 1 if Rejuv && atype == :DARK && otype1 == :STEEL
      mod2 = 1 if Rejuv && atype == :DARK && otype2 == :STEEL
      mod1 = 1 if Rejuv && atype == :GHOST && otype1 == :STEEL
      mod2 = 1 if Rejuv && atype == :GHOST && otype2 == :STEEL
    end
    if @battle.FE == :HAUNTED
      mod1 = 2 if otype1 == :NORMAL && atype == :GHOST
      mod2 = 2 if otype2 == :NORMAL && atype == :GHOST
      mod1 = 4 if otype1 == :GHOST && @move == :SPIRITBREAK
      mod2 = 4 if otype2 == :GHOST && @move == :SPIRITBREAK
    end
    if @battle.FE == :BEWITCHED
      mod1 = 2 if otype1 == :GRASS && atype == :POISON
      mod2 = 2 if otype2 == :GRASS && atype == :POISON
      mod1 = 4 if otype1 == :STEEL && atype == :FAIRY
      mod2 = 4 if otype2 == :STEEL && atype == :FAIRY
      mod1 = 2 if otype1 == :DARK && atype == :FAIRY
      mod2 = 2 if otype2 == :DARK && atype == :FAIRY
      mod1 = 2 if otype1 == :FAIRY && atype == :DARK
      mod2 = 2 if otype2 == :FAIRY && atype == :DARK
    end
    if @battle.FE == :SKY
      mod1 = 4 if otype1 == :FLYING && @move == :BONEMERANG
      mod2 = 4 if otype2 == :FLYING && @move == :BONEMERANG
      mod1 = 4 if otype1 == :FLYING && attacker.ability == :LONGREACH
      mod2 = 4 if otype2 == :FLYING && attacker.ability == :LONGREACH
    end
    if (!Rejuv && @battle.FE == :FOREST) || @battle.ProgressiveFieldCheck(PBFields::FLOWERGARDEN, 2, 5)
      mod1 = 4 if otype1 == :GRASS && @move == :CUT
      mod2 = 4 if otype2 == :GRASS && @move == :CUT
    end
    if @battle.FE == :INFERNAL
      mod1 = 4 if otype1 == :GHOST && atype == :FIRE
      mod2 = 4 if otype2 == :GHOST && atype == :FIRE
    end
    if opponent.item == :RINGTARGET
      mod1 = 2 if mod1 == 0
      mod2 = 2 if mod2 == 0
    end
    mod2 = otype1 == otype2 ? 2 : mod2

    # Inversemode password/field
    if ($game_switches[:Inversemode] && !@battle.isOnline?) ^ (@battle.FE == :INVERSE)
      mod1 = 1 if mod1 == 0
      mod2 = 1 if mod2 == 0
      mod1 = 4 / mod1
      mod2 = 4 / mod2
    end
    if opponent.species == :TORTERRA && opponent.item == :TORCREST
      mod1 = 4 / mod1 if mod1 != 0
      mod2 = 4 / mod2 if mod2 != 0
    end
    # effects that remove type weaknesses, what is a type weakness changes if inverse battle applies or not so needs to be checked after
    if @battle.pbWeather == :STRONGWINDS
      mod1 = 2 if otype1 == :FLYING && mod1 > 2
      mod2 = 2 if otype2 == :FLYING && mod2 > 2
    end
    if @battle.FE == :DARKNESS3
      mod1 = 2 if [:DARK, :GHOST].include?(otype1) && mod1 > 2
      mod2 = 2 if [:DARK, :GHOST].include?(otype2) && mod2 > 2
    end
    if @battle.ProgressiveFieldCheck(PBFields::FLOWERGARDEN, 4, 5)
      mod1 = 2 if otype1 == :GRASS && mod1 > 2
      mod2 = 2 if otype2 == :GRASS && mod2 > 2
    end
    if @battle.FE == :SNOWYMOUNTAIN
      mod1 = 2 if otype1 == :ICE && opponent.ability == :ICESCALES && mod1 > 2
      mod2 = 2 if otype2 == :ICE && opponent.ability == :ICESCALES && mod2 > 2
    end
    if @battle.FE == :DRAGONSDEN
      mod1 = 2 if otype1 == :DRAGON && opponent.ability == :MULTISCALE && mod1 > 2
      mod2 = 2 if otype2 == :DRAGON && opponent.ability == :MULTISCALE && mod2 > 2
    end
    if @battle.FE == :BEWITCHED
      mod1 = 2 if otype1 == :FAIRY && opponent.ability == :PASTELVEIL && mod1 > 2
      mod2 = 2 if otype2 == :FAIRY && opponent.ability == :PASTELVEIL && mod2 > 2
    end
    # effects that ignore Inverse battles entirely
    if @move == :VENAMSKISS
      mod1 = 4 if otype1 == :STEEL
      mod2 = 4 if otype2 == :STEEL
    end
    if @move == :FREEZEDRY
      mod1 = 4 if otype1 == :WATER
      mod2 = 4 if otype2 == :WATER
    end
    return mod1 * mod2
  end

  def pbStatusMoveAbsorption(type, attacker, opponent)
    if opponent.ability == :SAPSIPPER && !opponent.moldbroken && type == :GRASS
      if opponent.pbCanIncreaseStatStage?(PBStats::ATTACK)
        opponent.pbIncreaseStatBasic(PBStats::ATTACK, 1)
        @battle.pbCommonAnimation("StatUp", opponent, nil)
        @battle.pbDisplay(_INTL("{1}'s {2} raised its Attack!", opponent.pbThis, getAbilityName(opponent.ability)))
      else
        @battle.pbDisplay(_INTL("{1}'s {2} made {3} ineffective!", opponent.pbThis, getAbilityName(opponent.ability), self.name))
      end
      return 0
    end
    if ((opponent.ability == :STORMDRAIN && type == :WATER) || (opponent.ability == :LIGHTNINGROD && type == :ELECTRIC)) && !opponent.moldbroken
      if opponent.pbCanIncreaseStatStage?(PBStats::SPATK)
        if (Rejuv && @battle.FE == :SHORTCIRCUIT) && opponent.ability == :LIGHTNINGROD
          damageroll = @battle.field.getRoll(maximize_roll: (@battle.state.effects[:ELECTERRAIN] > 0))
          statboosts = [1, 2, 0, 1, 3]
          arrStatTexts = [
            _INTL("{1}'s {2} raised its Special Attack!", opponent.pbThis, getAbilityName(opponent.ability)),
            _INTL("{1}'s {2} sharply raised its Special Attack!", opponent.pbThis, getAbilityName(opponent.ability)),
            _INTL("{1}'s {2} drastically raised its Special Attack!", opponent.pbThis, getAbilityName(opponent.ability))
          ]
          statboost = statboosts[PBStuff::SHORTCIRCUITROLLS.find_index(damageroll)]
          if statboost != 0
            opponent.pbIncreaseStatBasic(PBStats::SPATK, statboost)
            @battle.pbCommonAnimation("StatUp", opponent, nil)
            @battle.pbDisplay(arrStatTexts[statboost - 1])
          else
            @battle.pbDisplay(_INTL("{1}'s {2} made {3} ineffective!", opponent.pbThis, getAbilityName(opponent.ability), self.name))
          end
        else
          opponent.pbIncreaseStatBasic(PBStats::SPATK, 1)
          @battle.pbCommonAnimation("StatUp", opponent, nil)
          @battle.pbDisplay(_INTL("{1}'s {2} raised its Special Attack!", opponent.pbThis, getAbilityName(opponent.ability)))
        end
      else
        @battle.pbDisplay(_INTL("{1}'s {2} made {3} ineffective!", opponent.pbThis, getAbilityName(opponent.ability), self.name))
      end
      return 0
    end
    if ((opponent.ability == :MOTORDRIVE && !opponent.moldbroken) ||
      (Rejuv && @battle.FE == :GLITCH && opponent.species == :GENESECT && opponent.hasWorkingItem(:SHOCKDRIVE))) &&
       type == :ELECTRIC
      negator = getAbilityName(opponent.ability)
      negator = getItemName(opponent.item) if (Rejuv && @battle.FE == :GLITCH && opponent.species == :GENESECT && opponent.hasWorkingItem(:SHOCKDRIVE))
      if opponent.pbCanIncreaseStatStage?(PBStats::SPEED)
        if @battle.FE == :FACTORY
          opponent.pbIncreaseStatBasic(PBStats::SPEED, 2)
          @battle.pbCommonAnimation("StatUp", opponent, nil)
          @battle.pbDisplay(_INTL("{1}'s {2} sharply raised its Speed!", opponent.pbThis, negator))
        elsif Rejuv && @battle.FE == :SHORTCIRCUIT
          damageroll = @battle.field.getRoll(maximize_roll: @battle.state.effects[:ELECTERRAIN] > 0)
          statboosts = [1, 2, 0, 1, 3]
          arrStatTexts = [
            _INTL("{1}'s {2} raised its Speed!", opponent.pbThis, negator),
            _INTL("{1}'s {2} sharply raised its Speed!", opponent.pbThis, negator),
            _INTL("{1}'s {2} drastically raised its Speed!", opponent.pbThis, negator)
          ]
          statboost = statboosts[PBStuff::SHORTCIRCUITROLLS.find_index(damageroll)]
          if statboost != 0
            opponent.pbIncreaseStatBasic(PBStats::SPEED, statboost)
            @battle.pbCommonAnimation("StatUp", opponent, nil)
            @battle.pbDisplay(arrStatTexts[statboost - 1])
          else
            @battle.pbDisplay(_INTL("{1}'s {2} made {3} ineffective!", opponent.pbThis, negator, self.name))
          end
        else
          opponent.pbIncreaseStatBasic(PBStats::SPEED, 1)
          @battle.pbCommonAnimation("StatUp", opponent, nil)
          @battle.pbDisplay(_INTL("{1}'s {2} raised its Speed!", opponent.pbThis, negator))
        end
      else
        @battle.pbDisplay(_INTL("{1}'s {2} made {3} ineffective!", opponent.pbThis, negator, self.name))
      end
      return 0
    end
    if (!opponent.moldbroken && (((opponent.ability == :DRYSKIN || opponent.ability == :WATERABSORB) && type == :WATER) || (opponent.ability == :VOLTABSORB && type == :ELECTRIC))) ||
       ((Rejuv && @battle.FE == :GLITCH && opponent.species == :GENESECT && opponent.hasWorkingItem(:DOUSEDRIVE)) && type == :WATER) ||
       ((Rejuv && @battle.FE == :GLITCH && opponent.species == :GENESECT && opponent.hasWorkingItem(:CHILLDRIVE)) && type == :ICE) ||
       ((Rejuv && @battle.FE == :DESERT) && (opponent.hasType?(:GRASS) || opponent.hasType?(:WATER)) && @battle.pbWeather == :SUNNYDAY && type == :WATER)
      if opponent.effects[:HealBlock] == 0
        negator = getAbilityName(opponent.ability)
        if ![:WATERABSORB, :VOLTABSORB, :DRYSKIN].include?(opponent.ability)
          negator = getItemName(opponent.item) if (Rejuv && @battle.FE == :GLITCH && opponent.species == :GENESECT && (opponent.item == :DOUSEDRIVE || opponent.item == :CHILLDRIVE))
          negator = "unquenchable thirst" if (Rejuv && @battle.FE == :DESERT) && (opponent.hasType?(:GRASS) || opponent.hasType?(:WATER)) && @battle.pbWeather == :SUNNYDAY
        end
        if (Rejuv && @battle.FE == :SHORTCIRCUIT) && opponent.ability == :VOLTABSORB
          damageroll = @battle.field.getRoll(maximize_roll: (@battle.state.effects[:ELECTERRAIN] > 0))
          if opponent.pbRecoverHP(((opponent.totalhp / 4.0) * damageroll).floor, true) > 0
            @battle.pbDisplay(_INTL("{1}'s {2} restored its HP!", opponent.pbThis, negator))
          else
            @battle.pbDisplay(_INTL("{1}'s {2} made {3} useless!", opponent.pbThis, negator, @name))
          end
        elsif opponent.pbRecoverHP((opponent.totalhp / 4.0).floor, true) > 0
          @battle.pbDisplay(_INTL("{1}'s {2} restored its HP!", opponent.pbThis, negator))
        else
          @battle.pbDisplay(_INTL("{1}'s {2} made {3} useless!", opponent.pbThis, negator, @name))
        end
        return 0
      end
    end
    if ((opponent.ability == :FLASHFIRE && !opponent.moldbroken) ||
       (Rejuv && @battle.FE == :GLITCH && opponent.species == :GENESECT && opponent.hasWorkingItem(:BURNDRIVE))) &&
       type == :FIRE && @battle.FE != :FROZENDIMENSION
      negator = getAbilityName(opponent.ability)
      negator = getItemName(opponent.item) if (Rejuv && @battle.FE == :GLITCH && opponent.species == :GENESECT && opponent.hasWorkingItem(:BURNDRIVE))
      if !opponent.effects[:FlashFire]
        opponent.effects[:FlashFire] = true
        @battle.pbDisplay(_INTL("{1}'s {2} activated!", opponent.pbThis, negator))
      else
        @battle.pbDisplay(_INTL("{1}'s {2} made {3} ineffective!", opponent.pbThis, negator, self.name))
      end
      return 0
    end
    if opponent.ability == :MAGMAARMOR && type == :FIRE && [:DRAGONSDEN, :VOLCANICTOP, :INFERNAL].include?(@battle.FE) && !opponent.moldbroken
      @battle.pbDisplay(_INTL("{1}'s {2} made {3} ineffective!", opponent.pbThis, getAbilityName(opponent.ability), self.name))
      return 0
    end
    # Immunity Crests
    case opponent.crested
      when :SKUNTANK
        if type == :GROUND
          if opponent.pbCanIncreaseStatStage?(PBStats::ATTACK)
            opponent.pbIncreaseStatBasic(PBStats::ATTACK, 1)
            @battle.pbCommonAnimation("StatUp", opponent, nil)
            @battle.pbDisplay(_INTL("{1}'s {2} raised its Attack!", opponent.pbThis, getItemName(opponent.item)))
          else
            @battle.pbDisplay(_INTL("{1}'s {2} made {3} ineffective!", opponent.pbThis, getItemName(opponent.item), self.name))
          end
          return 0
        end
      when :DRUDDIGON
        if type == :FIRE
          if opponent.effects[:HealBlock] == 0
            if opponent.pbRecoverHP((opponent.totalhp / 4.0).floor, true) > 0
              @battle.pbDisplay(_INTL("{1}'s {2} restored its HP!", opponent.pbThis, getItemName(opponent.item)))
            else
              @battle.pbDisplay(_INTL("{1}'s {2} made {3} useless!", opponent.pbThis, getItemName(opponent.item), @name))
            end
            return 0
          end
        end
      when :WHISCASH
        if type == :GRASS
          if opponent.pbCanIncreaseStatStage?(PBStats::ATTACK)
            opponent.pbIncreaseStatBasic(PBStats::ATTACK, 1)
            @battle.pbCommonAnimation("StatUp", opponent, nil)
            @battle.pbDisplay(_INTL("{1}'s {2} raised its Attack!", opponent.pbThis, getItemName(opponent.item)))
          else
            @battle.pbDisplay(_INTL("{1}'s {2} made {3} ineffective!", opponent.pbThis, getItemName(opponent.item), self.name))
          end
          return 0
        end
    end
    if self.powderMove?
      if opponent.hasType?(:GRASS)
        @battle.pbDisplay(_INTL("It doesn't affect {1}...", opponent.pbThis(true)))
        return 0
      elsif opponent.ability == :OVERCOAT && !opponent.moldbroken
        @battle.pbDisplay(_INTL("{1}'s {2} made the attack ineffective!", opponent.pbThis, getAbilityName(opponent.ability), self.name))
        return 0
      elsif opponent.hasWorkingItem(:SAFETYGOGGLES)
        @battle.pbDisplay(_INTL("{1} avoided the move with its {2}!", opponent.pbThis, getItemName(opponent.item), self.name))
        return 0
      end
    end
    return 4
  end

  def pbTypeModMessages(type, attacker, opponent)
    secondtype = getSecondaryType(attacker)
    if opponent.ability == :SAPSIPPER && !opponent.moldbroken && (type == :GRASS || (!secondtype.nil? && secondtype.include?(:GRASS)))
      if opponent.pbCanIncreaseStatStage?(PBStats::ATTACK)
        opponent.pbIncreaseStatBasic(PBStats::ATTACK, 1)
        @battle.pbCommonAnimation("StatUp", opponent, nil)
        @battle.pbDisplay(_INTL("{1}'s {2} raised its Attack!", opponent.pbThis, getAbilityName(opponent.ability)))
      else
        @battle.pbDisplay(_INTL("{1}'s {2} made {3} ineffective!", opponent.pbThis, getAbilityName(opponent.ability), self.name))
      end
      return 0
    end
    if ((opponent.ability == :STORMDRAIN && (type == :WATER || (!secondtype.nil? && secondtype.include?(:WATER)))) ||
       (opponent.ability == :LIGHTNINGROD && (type == :ELECTRIC || (!secondtype.nil? && secondtype.include?(:ELECTRIC))))) && !opponent.moldbroken
      if opponent.pbCanIncreaseStatStage?(PBStats::SPATK)
        if (Rejuv && @battle.FE == :SHORTCIRCUIT) && opponent.ability == :LIGHTNINGROD
          damageroll = @battle.field.getRoll(maximize_roll: (@battle.state.effects[:ELECTERRAIN] > 0))
          statboosts = [1, 2, 0, 1, 3]
          arrStatTexts = [
            _INTL("{1}'s {2} raised its Special Attack!", opponent.pbThis, getAbilityName(opponent.ability)),
            _INTL("{1}'s {2} sharply raised its Special Attack!", opponent.pbThis, getAbilityName(opponent.ability)),
            _INTL("{1}'s {2} drastically raised its Special Attack!", opponent.pbThis, getAbilityName(opponent.ability))
          ]
          statboost = statboosts[PBStuff::SHORTCIRCUITROLLS.find_index(damageroll)]
          if statboost != 0
            opponent.pbIncreaseStatBasic(PBStats::SPATK, statboost)
            @battle.pbCommonAnimation("StatUp", opponent, nil)
            @battle.pbDisplay(arrStatTexts[statboost - 1])
          else
            @battle.pbDisplay(_INTL("{1}'s {2} made {3} ineffective!", opponent.pbThis, getAbilityName(opponent.ability), self.name))
          end
        else
          opponent.pbIncreaseStatBasic(PBStats::SPATK, 1)
          @battle.pbCommonAnimation("StatUp", opponent, nil)
          @battle.pbDisplay(_INTL("{1}'s {2} raised its Special Attack!", opponent.pbThis, getAbilityName(opponent.ability)))
        end
      else
        @battle.pbDisplay(_INTL("{1}'s {2} made {3} ineffective!", opponent.pbThis, getAbilityName(opponent.ability), self.name))
      end
      if @function == 0xCB # Dive
        @battle.scene.pbUnVanishSprite(attacker)
      end
      return 0
    end
    if ((opponent.ability == :MOTORDRIVE && !opponent.moldbroken) ||
       (Rejuv && @battle.FE == :GLITCH && opponent.species == :GENESECT && opponent.hasWorkingItem(:SHOCKDRIVE))) &&
       (type == :ELECTRIC || (!secondtype.nil? && secondtype.include?(:ELECTRIC)))
      negator = getAbilityName(opponent.ability)
      negator = getItemName(opponent.item) if (Rejuv && @battle.FE == :GLITCH && opponent.species == :GENESECT && opponent.hasWorkingItem(:SHOCKDRIVE))
      if opponent.pbCanIncreaseStatStage?(PBStats::SPEED)
        if (!Rejuv && @battle.FE == :SHORTCIRCUIT) || (Rejuv && @battle.FE == :FACTORY)
          opponent.pbIncreaseStatBasic(PBStats::SPEED, 2)
          @battle.pbCommonAnimation("StatUp", opponent, nil)
          @battle.pbDisplay(_INTL("{1}'s {2} sharply raised its Speed!", opponent.pbThis, negator))
        elsif Rejuv && @battle.FE == :SHORTCIRCUIT
          damageroll = @battle.field.getRoll(maximize_roll: (@battle.state.effects[:ELECTERRAIN] > 0))
          statboosts = [1, 2, 0, 1, 3]
          arrStatTexts = [
            _INTL("{1}'s {2} raised its Speed!", opponent.pbThis, negator),
            _INTL("{1}'s {2} sharply raised its Speed!", opponent.pbThis, negator),
            _INTL("{1}'s {2} drastically raised its Speed!", opponent.pbThis, negator)
          ]
          statboost = statboosts[PBStuff::SHORTCIRCUITROLLS.find_index(damageroll)]
          if statboost != 0
            opponent.pbIncreaseStatBasic(PBStats::SPEED, statboost)
            @battle.pbCommonAnimation("StatUp", opponent, nil)
            @battle.pbDisplay(arrStatTexts[statboost - 1])
          else
            @battle.pbDisplay(_INTL("{1}'s {2} made {3} ineffective!", opponent.pbThis, negator, self.name))
          end
        else
          opponent.pbIncreaseStatBasic(PBStats::SPEED, 1)
          @battle.pbCommonAnimation("StatUp", opponent, nil)
          @battle.pbDisplay(_INTL("{1}'s {2} raised its Speed!", opponent.pbThis, negator))
        end
      else
        @battle.pbDisplay(_INTL("{1}'s {2} made {3} ineffective!", opponent.pbThis, negator, self.name))
      end
      return 0
    end
    if ((opponent.ability == :DRYSKIN && !opponent.moldbroken) && (type == :WATER || (!secondtype.nil? && secondtype.include?(:WATER)))) ||
       (opponent.ability == :VOLTABSORB && !opponent.moldbroken && (type == :ELECTRIC || (!secondtype.nil? && secondtype.include?(:ELECTRIC)))) ||
       (opponent.ability == :WATERABSORB && !opponent.moldbroken && (type == :WATER || (!secondtype.nil? && secondtype.include?(:WATER)))) ||
       ((Rejuv && @battle.FE == :GLITCH && opponent.species == :GENESECT && opponent.hasWorkingItem(:DOUSEDRIVE)) && (type == :WATER || (!secondtype.nil? && secondtype.include?(:WATER)))) ||
       ((Rejuv && @battle.FE == :GLITCH && opponent.species == :GENESECT && opponent.hasWorkingItem(:CHILLDRIVE)) && (type == :ICE || (!secondtype.nil? && secondtype.include?(:ICE)))) ||
       ((Rejuv && @battle.FE == :DESERT) && (opponent.hasType?(:GRASS) || opponent.hasType?(:WATER)) && @battle.pbWeather == :SUNNYDAY && (type == :WATER || (!secondtype.nil? && secondtype.include?(:WATER))))
      if opponent.effects[:HealBlock] == 0
        negator = getAbilityName(opponent.ability)
        if ![:WATERABSORB, :VOLTABSORB, :DRYSKIN].include?(opponent.ability)
          negator = getItemName(opponent.item) if (Rejuv && @battle.FE == :GLITCH && opponent.species == :GENESECT && (opponent.item == :DOUSEDRIVE || opponent.item == :CHILLDRIVE))
          negator = "unquenchable thirst" if (Rejuv && @battle.FE == :DESERT) && (opponent.hasType?(:GRASS) || opponent.hasType?(:WATER)) && @battle.pbWeather == :SUNNYDAY
        end
        if Rejuv && @battle.FE == :SHORTCIRCUIT && opponent.ability == :VOLTABSORB
          damageroll = @battle.field.getRoll(maximize_roll: (@battle.state.effects[:ELECTERRAIN] > 0))
          if opponent.pbRecoverHP(((opponent.totalhp / 4.0) * damageroll).floor, true) > 0
            @battle.pbDisplay(_INTL("{1}'s {2} restored its HP!", opponent.pbThis, negator))
          else
            @battle.pbDisplay(_INTL("{1}'s {2} made {3} useless!", opponent.pbThis, negator, @name))
          end
        elsif opponent.pbRecoverHP((opponent.totalhp / 4.0).floor, true) > 0
          @battle.pbDisplay(_INTL("{1}'s {2} restored its HP!", opponent.pbThis, negator))
        else
          @battle.pbDisplay(_INTL("{1}'s {2} made {3} useless!", opponent.pbThis, negator, @name))
        end
        if @function == 0xCB # Dive
          @battle.scene.pbUnVanishSprite(attacker)
        end
        return 0
      end
    end
    # Immunity Crests
    case opponent.crested
      when :SKUNTANK
        if type == :GROUND || (!secondtype.nil? && secondtype.include?(:GROUND))
          if opponent.pbCanIncreaseStatStage?(PBStats::ATTACK)
            opponent.pbIncreaseStatBasic(PBStats::ATTACK, 1)
            @battle.pbCommonAnimation("StatUp", opponent, nil)
            @battle.pbDisplay(_INTL("{1}'s {2} raised its Attack!", opponent.pbThis, getItemName(opponent.item)))
          else
            @battle.pbDisplay(_INTL("{1}'s {2} made {3} ineffective!", opponent.pbThis, getItemName(opponent.item), self.name))
          end
          return 0
        end
      when :DRUDDIGON
        if type == :FIRE || (!secondtype.nil? && secondtype.include?(:FIRE))
          if opponent.effects[:HealBlock] == 0
            if opponent.pbRecoverHP((opponent.totalhp / 4.0).floor, true) > 0
              @battle.pbDisplay(_INTL("{1}'s {2} restored its HP!", opponent.pbThis, getItemName(opponent.item)))
            else
              @battle.pbDisplay(_INTL("{1}'s {2} made {3} useless!", opponent.pbThis, getItemName(opponent.item), @name))
            end
            return 0
          end
        end
      when :WHISCASH
        if type == :GRASS || (!secondtype.nil? && secondtype.include?(:GRASS))
          if opponent.pbCanIncreaseStatStage?(PBStats::ATTACK)
            opponent.pbIncreaseStatBasic(PBStats::ATTACK, 1)
            @battle.pbCommonAnimation("StatUp", opponent, nil)
            @battle.pbDisplay(_INTL("{1}'s {2} raised its Attack!", opponent.pbThis, getItemName(opponent.item)))
          else
            @battle.pbDisplay(_INTL("{1}'s {2} made {3} ineffective!", opponent.pbThis, getItemName(opponent.item), self.name))
          end
          return 0
        end
    end
    if opponent.ability == :BULLETPROOF && !opponent.moldbroken
      if PBStuff::BULLETMOVE.include?(@move)
        @battle.pbDisplay(_INTL("{1}'s {2} blocked the attack!", opponent.pbThis, getAbilityName(opponent.ability), self.name))
        return 0
      end
    end
    if @battle.FE == :ROCKY && (opponent.effects[:Substitute] > 0 || opponent.stages[PBStats::DEFENSE] > 0)
      if PBStuff::BULLETMOVE.include?(@move)
        @battle.pbDisplay(_INTL("{1} hid behind a rock to dodge the attack!", opponent.pbThis, getAbilityName(opponent.ability), self.name))
        return 0
      end
    end
    if ((opponent.ability == :FLASHFIRE && !opponent.moldbroken) ||
       (Rejuv && @battle.FE == :GLITCH && opponent.species == :GENESECT && opponent.hasWorkingItem(:BURNDRIVE))) &&
       (type == :FIRE || (!secondtype.nil? && secondtype.include?(:FIRE))) && @battle.FE != :FROZENDIMENSION
      negator = getAbilityName(opponent.ability)
      negator = getItemName(opponent.item) if (Rejuv && @battle.FE == :GLITCH && opponent.species == :GENESECT && opponent.hasWorkingItem(:BURNDRIVE))
      if !opponent.effects[:FlashFire]
        opponent.effects[:FlashFire] = true
        @battle.pbDisplay(_INTL("{1}'s {2} activated!", opponent.pbThis, negator))
      else
        @battle.pbDisplay(_INTL("{1}'s {2} made {3} ineffective!", opponent.pbThis, negator, self.name))
      end
      return 0
    end
    if opponent.ability == :MAGMAARMOR && (type == :FIRE || (!secondtype.nil? && secondtype.include?(:FIRE))) &&
       [:DRAGONSDEN, :VOLCANICTOP, :INFERNAL].include?(@battle.FE) && !opponent.moldbroken
      @battle.pbDisplay(_INTL("{1}'s {2} made {3} ineffective!", opponent.pbThis, getAbilityName(opponent.ability), self.name))
      return 0
    end
    # Telepathy
    if ((opponent.ability == :TELEPATHY && !opponent.moldbroken) || @battle.FE == :HOLY) && @basedamage > 0
      if opponent.index == attacker.pbPartner.index
        @battle.pbDisplay(_INTL("{1} avoids attacks by its ally Pokémon!", opponent.pbThis))
        return 0
      end
    end
    typemod = pbTypeModifier(type, attacker, opponent)
    # Resistance-changing Crests
    typemod = irregularTypeMods(attacker, opponent, typemod, type)
    if @move == :FLYINGPRESS
      if @battle.FE == :SKY
        typemod *= 2 if $game_switches[:Inversemode] && !@battle.isOnline? ? PBTypes.oneTypeEff(:FLYING, opponent.type1) > 2 : PBTypes.oneTypeEff(:FLYING, opponent.type1) < 2
        typemod *= 2 if $game_switches[:Inversemode] && !@battle.isOnline? ? PBTypes.oneTypeEff(:FLYING, opponent.type2) > 2 : PBTypes.oneTypeEff(:FLYING, opponent.type2) < 2
      else
        typemod2 = pbTypeModifier(:FLYING, attacker, opponent)
        typemod2 = irregularTypeMods(attacker, opponent, typemod2, :FLYING)
        typemod = (typemod * typemod2) / 4
      end
    end
    # Field Effect second type changes
    typemod = fieldTypeChange(attacker, opponent, typemod)
    typemod = overlayTypeChange(attacker, opponent, typemod)

    if typemod == 0
      if @function == 0x111
        return 1
      else
        @battle.pbDisplay(_INTL("It doesn't affect {1}...", opponent.pbThis(true)))
        if PBStuff::TWOTURNMOVE.include?(@move)
          @battle.scene.pbUnVanishSprite(attacker)
        end
      end
    end
    return typemod
  end

  def irregularTypeMods(attacker, opponent, typemod, type)
    inverse = (($game_switches[:Inversemode] && !@battle.isOnline?) ^ (@battle.FE == :INVERSE))
    case opponent.crested
      when :GLACEON
        typemod = 2 if [:FIGHTING, :ROCK].include?(type)
      when :LEAFEON
        typemod = 2 if [:FIRE, :FLYING].include?(type)
      when :LUXRAY
        typemod /= 2 if inverse ? PBTypes.oneTypeEff(type, :DARK) > 2 : PBTypes.oneTypeEff(type, :DARK) < 2
        typemod = 0 if PBTypes.oneTypeEff(type, :DARK) == 0 && !inverse
      when :SAMUROTT
        typemod /= 2 if inverse ? PBTypes.oneTypeEff(type, :FIGHTING) > 2 : PBTypes.oneTypeEff(type, :FIGHTING) < 2
        typemod = 0 if PBTypes.oneTypeEff(type, :FIGHTING) == 0 && !inverse
      when :SIMISEAR
        typemod /= 2 if inverse ? PBTypes.oneTypeEff(type, :WATER) > 2 : (PBTypes.oneTypeEff(type, :WATER) < 2 && !(type == :WATER && @battle.FE == :UNDERWATER))
        typemod = 0 if PBTypes.oneTypeEff(type, :WATER) == 0 && !inverse
      when :SIMIPOUR
        typemod /= 2 if inverse ? PBTypes.oneTypeEff(type, :GRASS) > 2 : PBTypes.oneTypeEff(type, :GRASS) < 2
        typemod = 0 if PBTypes.oneTypeEff(type, :GRASS) == 0 && !inverse
      when :SIMISAGE
        typemod /= 2 if inverse ? PBTypes.oneTypeEff(type, :FIRE) > 2 : (PBTypes.oneTypeEff(type, :FIRE) < 2 && !(type == :ICE && @battle.FE == :GLITCH))
        typemod = 0 if PBTypes.oneTypeEff(type, :FIRE) == 0 && !inverse
    end
    typemod *= 2 if type == :FIRE && opponent.effects[:TarShot]
    return typemod
  end

  def fieldTypeChange(attacker, opponent, typemod, return_type = false)
    case @battle.FE
      when :RAINBOW # Rainbow Field
        if pbType(attacker) == :NORMAL && pbIsSpecial?(attacker, pbType(attacker))
          moddedtype = @battle.getRandomType(:NORMAL)
        end
      when :CORROSIVEMIST # Corrosive Mist Field
        if pbType(attacker) == :FLYING && !pbIsPhysical?(attacker, pbType(attacker))
          moddedtype = :POISON
        end
      when :SHORTCIRCUIT # Shortcircuit Field
        if pbType(attacker) == :STEEL && attacker.ability == :STEELWORKER
          moddedtype = :ELECTRIC
        end
      when :CRYSTALCAVERN # Crystal Cavern
        if pbType(attacker) == :ROCK || [:JUDGMENT, :ROCKCLIMB, :STRENGTH, :MULTIATTACK, :PRISMATICLASER].include?(@move)
          moddedtype = @battle.field.getRoll(
            update_roll: caller_locations.any? { |string|
              string.to_s.include?("pbCalcDamage")
            } && !return_type
          )
        end
    end
    if !moddedtype
      fieldmove = @battle.field.moveData(@move)
      moddedtype = fieldmove[:typemod] if fieldmove
    end
    if !moddedtype # if moddedtype is STILL nil
      currenttype = pbType(attacker)
      fieldtype = @battle.field.typeData(currenttype)
      moddedtype = fieldtype[:typemod] if fieldtype
    end
    if return_type
      return moddedtype ? moddedtype : nil
    else
      return typemod if !moddedtype

      newtypemod = pbTypeModifier(moddedtype, attacker, opponent)
      newtypemod = irregularTypeMods(attacker, opponent, newtypemod, moddedtype)
      typemod = ((typemod * newtypemod) * 0.25).ceil
      return typemod
    end
  end

  def overlayTypeChange(attacker, opponent, typemod, return_type = false)
    for field in $cache.FEData.keys
      next if !field.is_a?(Symbol)
      next if $cache.FEData[field].overlaymovedata.empty?
      next if @battle.state.effects[field] == 0

      overlaymove = $cache.FEData[field].overlaymovedata[@move]
      moddedtype = overlaymove[:typemod] if overlaymove
    end
    if return_type
      return moddedtype ? moddedtype : nil
    else
      return typemod if !moddedtype

      newtypemod = pbTypeModifier(moddedtype, attacker, opponent)
      newtypemod = irregularTypeMods(attacker, opponent, newtypemod, moddedtype)
      typemod = ((typemod * newtypemod) * 0.25).ceil
      return typemod
    end
  end

  def getSecondaryType(attacker)
    secondtype = []
    secondtype.push(:FLYING) if @move == :FLYINGPRESS
    fieldtype = fieldTypeChange(attacker, nil, nil, true)
    secondtype.push(fieldtype) if fieldtype
    overlaytype = overlayTypeChange(attacker, nil, nil, true)
    secondtype.push(overlaytype) if overlaytype
    secondtype = [secondtype[0], secondtype[1]] if secondtype.length > 2
    return secondtype.empty? ? nil : secondtype
  end

  ################################################################################
  # This move's accuracy check
  ################################################################################
  def pbAccuracyCheck(attacker, opponent, precheckedacc: nil)
    baseaccuracy = self.accuracy
    # Field Effects
    fieldmove = @battle.field.moveData(@move)
    baseaccuracy = fieldmove[:accmod] if fieldmove && fieldmove[:accmod]
    return precheckedacc if !precheckedacc.nil?
    return true if baseaccuracy == 0
    return true if attacker.ability == :NOGUARD || opponent.ability == :NOGUARD || (attacker.ability == :FAIRYAURA && @battle.FE == :FAIRYTALE)
    return true if opponent.effects[:Telekinesis] > 0
    return true if @function == 0x0D && @battle.pbWeather == :HAIL # Blizzard
    return true if (@function == 0x08 || @function == 0x15) && @battle.pbWeather == :RAINDANCE # Thunder, Hurricane
    return true if @type == :ELECTRIC && @battle.FE == :UNDERWATER
    return true if attacker.hasType?(:POISON) && @move == :TOXIC
    return true if (@function == 0x10 || @move == :BODYSLAM || @function == 0x137 || @function == 0x9B) && opponent.effects[:Minimize] # Flying Press, Stomp, DRush
    return true if @battle.FE == :MIRROR && (PBFields::BLINDINGMOVES + [:MIRRORSHOT]).include?(@move)

    # One-hit KO accuracy handled elsewhere
    if @function == 0x08 || @function == 0x15 # Thunder, Hurricane
      baseaccuracy = 50 if @battle.pbWeather == :SUNNYDAY && !attacker.hasWorkingItem(:UTILITYUMBRELLA)
    end
    accstage = attacker.stages[PBStats::ACCURACY]
    accstage = 0 if opponent.ability == :UNAWARE && !opponent.moldbroken
    evastage = opponent.stages[PBStats::EVASION]
    evastage = 0 if opponent.effects[:Foresight] || opponent.effects[:MiracleEye] || @function == 0xA9 || # Chip Away
                    [:UNAWARE, :KEENEYE].include?(attacker.ability)
    accstage -= evastage
    accstage = accstage.clamp(-6, 6)
    accuracy = accstage >= 0 ? (accstage + 3) * 100.0 / 3 : 300.0 / (3 - accstage)

    # accuracy modifiers
    accuracy *= 1.67 if @battle.state.effects[:Gravity] != 0
    if attacker.ability == :COMPOUNDEYES
      accuracy *= 1.3
    end
    if attacker.effects[:MicleBerry]
      if (attacker.ability == :GLUTTONY && attacker.hp <= (attacker.totalhp / 2.0).floor) ||
         attacker.hp <= (attacker.totalhp / 4.0).floor
        accuracy *= 1.2
        attacker.effects[:MicleBerry] = false
      end
    end
    if attacker.ability == :VICTORYSTAR
      accuracy *= 1.1
    end
    partner = attacker.pbPartner
    if partner && partner.ability == :VICTORYSTAR
      accuracy *= 1.1
    end
    if attacker.hasWorkingItem(:WIDELENS)
      accuracy *= 1.1
    end
    # Hypno Crest, Stantler Crest
    if [:HYPNO, :STANTLER, :WYRDEER].include?(attacker.crested)
      accuracy *= 1.5
    end
    if attacker.hasWorkingItem(:ZOOMLENS) && attacker.pbSpeed < opponent.pbSpeed
      accuracy *= 1.2
    end
    if attacker.ability == :HUSTLE && @basedamage > 0 && pbIsPhysical?(attacker, pbType(attacker))
      accuracy *= [:BACKALLEY, :CITY].include?(@battle.FE) ? 0.67 : 0.8
    end
    if attacker.ability == :LONGREACH && (@battle.FE == :ROCKY || (!Rejuv && @battle.FE == :FOREST)) # Rocky/ Forest Field
      accuracy *= 0.9
    end
    if (opponent.ability == :WONDERSKIN || (Rejuv && @battle.FE == :PSYTERRAIN && opponent.ability == :MAGICIAN)) &&
       @basedamage == 0 && attacker.pbIsOpposing?(opponent.index) && !opponent.moldbroken
      if @battle.FE == :RAINBOW
        accuracy *= 0
      else
        accuracy *= 0.5
      end
    end
    if opponent.ability == :TANGLEDFEET && opponent.effects[:Confusion] > 0 && !opponent.moldbroken
      accuracy *= 0.5
    end
    if opponent.ability == :SANDVEIL && (@battle.pbWeather == :SANDSTORM || [:DESERT, :ASHENBEACH].include?(@battle.FE)) && !opponent.moldbroken
      accuracy *= 0.8
    end
    if opponent.ability == :SNOWCLOAK && (@battle.pbWeather == :HAIL || [:ICY, :SNOWYMOUNTAIN, :FROZENDIMENSION].include?(@battle.FE)) && !opponent.moldbroken
      accuracy *= 0.8
    end
    if opponent.hasWorkingItem(:BRIGHTPOWDER)
      accuracy *= 0.9
    end
    if opponent.hasWorkingItem(:LAXINCENSE)
      accuracy *= 0.9
    end
    accuracy = 100.0 if @battle.FE == :ASHENBEACH && [:OWNTEMPO, :INNERFOCUS, :PUREPOWER, :SANDVEIL, :STEADFAST].include?(attacker.ability) && ![:UNNERVE, :ASONECHILLING, :ASONEGRIM].include?(opponent.ability)
    return @battle.pbRandom(100) < (baseaccuracy * accuracy / 100.0).floor
  end

  ################################################################################
  # Damage calculation and modifiers
  ################################################################################
  def pbCritRate?(attacker, opponent)
    return -1 if self.is_a?(PokeBattle_Confusion)
    return -1 if (opponent.ability == :BATTLEARMOR || opponent.ability == :SHELLARMOR) && !opponent.moldbroken
    return -1 if opponent.pbOwnSide.effects[:LuckyChant] > 0
    return 3 if attacker.effects[:LaserFocus] > 0 || @function == 0xA0 || @function == 0x319 # Frost Breath, Surging Strikes
    return 3 if @function == 0x201 && attacker.hp <= ((attacker.totalhp) * 0.5).floor # Gale Strike
    return 3 if attacker.ability == :MERCILESS && (opponent.status == :POISON || @battle.FE == :CORROSIVEMIST || ([:CORROSIVE, :WASTELAND, :MURKWATERSURFACE].include?(@battle.FE) && !attacker.isAirborne?))
    return 3 if (opponent.ability == :RATTLED || opponent.ability == :WIMPOUT) && @battle.FE == :COLOSSEUM
    return 3 if attacker.crested == :ARIADOS && (opponent.status == :POISON || opponent.stages[PBStats::SPEED] < 0) # ariados crest
    return 3 if (attacker.ability == :QUICKDRAW && attacker.effects[:QuickDrawSnipe])

    c = 0
    c += attacker.effects[:FocusEnergy]
    c += 1 if !@data.nil? && highCritRate?
    c += 1 if attacker.inHyperMode? && getMoveType(@move) == :SHADOW
    c += 1 if attacker.ability == :SUPERLUCK
    c += 2 if attacker.hasWorkingItem(:STICK) && (attacker.pokemon.species == :FARFETCHD || attacker.pokemon.species == :SIRFETCHD)
    c += 2 if attacker.hasWorkingItem(:LUCKYPUNCH) && (attacker.pokemon.species == :CHANSEY)
    if @battle.FE == :MIRROR
      buffs = 0
      buffs = attacker.stages[PBStats::EVASION] if attacker.stages[PBStats::EVASION] > 0
      buffs = buffs.to_i + attacker.stages[PBStats::ACCURACY] if attacker.stages[PBStats::ACCURACY] > 0
      buffs = buffs.to_i - opponent.stages[PBStats::EVASION] if opponent.stages[PBStats::EVASION] < 0
      buffs = buffs.to_i - opponent.stages[PBStats::ACCURACY] if opponent.stages[PBStats::ACCURACY] < 0
      buffs = buffs.to_i
      c += buffs if buffs > 0
    end
    c += 1 if attacker.hasWorkingItem(:RAZORCLAW)
    c += 1 if attacker.hasWorkingItem(:SCOPELENS)
    c += 3 if sharpMove? && attacker.crested == :SAMUROTT
    c += 1 if attacker.crested == :FEAROW # Fearow Crest
    c += 1 if attacker.speed > opponent.speed && @battle.FE == :GLITCH
    if Rejuv && @battle.FE == :CHESS
      c += 1 if (opponent.ability == :RECKLESS || opponent.ability == :GORILLATACTICS)
      c += 1 if [:STOMPINGTANTRUM, :THRASH, :OUTRAGE].include?(opponent.lastMoveUsed)
      if attacker.ability == :MERCILESS
        frac = (1.0 * opponent.hp) / (1.0 * opponent.totalhp)
        if frac < 0.8
          c += 1
        elsif frac < 0.6
          c += 2
        elsif frac < 0.4
          c += 3
        end
      end
    end
    c = 3 if c > 3
    return c
  end

  def pbBaseDamage(basedmg, attacker, opponent)
    return basedmg
  end

  def pbBaseDamageMultiplier(damagemult, attacker, opponent)
    return damagemult
  end

  def pbModifyDamage(damagemult, attacker, opponent)
    return damagemult
  end

  def pbCalcDamage(attacker, opponent, hitnum: 0)
    opponent.damagestate.critical = false
    opponent.damagestate.typemod = 0
    opponent.damagestate.calcdamage = 0
    basedmg = @basedamage # From PBS file
    basedmg = [attacker.happiness, 250].min if attacker.crested == :LUVDISC && basedmg != 0
    basedmg = pbBaseDamage(basedmg, attacker, opponent) # Some function codes alter base power
    return 0 if basedmg == 0

    basedmg = basedmg * 0.3 if attacker.crested == :CINCCINO && !pbIsMultiHit

    damage = 1.0 # variable for overall damage, defined early due to spread damaage modifiers, only used later
    # Multi-targeting attacks
    if pbTargetsAll?(attacker) || attacker.midwayThroughMove
      if attacker.pokemon.piece == :KNIGHT && battle.FE == :CHESS && attacker.pbTarget(self) == :AllOpposing
        @battle.pbDisplay(_INTL("The knight forked the opponents!")) if !attacker.midwayThroughMove
        damage *= 1.25
      else
        damage *= 0.75
      end
      attacker.midwayThroughMove = true
    end

    # Prevent third dart in case first dart killed an opponent in doubles.
    attacker.midwayThroughMove = true if attacker.pbTarget(self) == :DragonDarts

    # Type effectiveness
    type = pbType(attacker)
    typemod = pbTypeModMessages(type, attacker, opponent)
    opponent.damagestate.typemod = typemod
    if typemod == 0
      opponent.damagestate.calcdamage = 0
      opponent.damagestate.critical = false
      return 0
    end

    critchance = pbCritRate?(attacker, opponent)
    if critchance >= 0
      ratios = [24, 8, 2, 1]
      opponent.damagestate.critical = @battle.pbRandom(ratios[critchance]) == 0
    end
    ##### Calcuate base power of move #####

    basemult = 1.0
    # classic prep stuff
    attitemworks = attacker.itemWorks?(true)
    # oppitemworks = opponent.itemWorks?(true)
    case attacker.ability
      when :TECHNICIAN
        if basedmg <= 60
          basemult *= 1.5
        elsif (@battle.FE == :FACTORY || @battle.ProgressiveFieldCheck(PBFields::CONCERT)) && basedmg <= 80
          basemult *= 1.5
        end
      when :STRONGJAW     then basemult *= 1.5 if PBStuff::BITEMOVE.include?(@move)
      when :SHARPNESS     then basemult *= 1.5 if sharpMove?
      when :TRUESHOT      then basemult *= 1.3 if PBStuff::BULLETMOVE.include?(@move)
      when :TOUGHCLAWS    then basemult *= 1.3 if contactMove?
      when :IRONFIST
        if @battle.FE == :CROWD
          basemult *= 1.2 if punchMove?
        else
          basemult *= 1.2 if punchMove?
        end
      when :RECKLESS      then basemult *= 1.2 if @recoil > 0 || [0x130, 0x10B, 0x506].include?(@function) # Shadow End, High Jump Kick, Axe Kick
      when :FLAREBOOST    then basemult *= 1.5 if (attacker.status == :BURN || [:BURNING, :VOLCANIC, :INFERNAL].include?(@battle.FE)) && pbIsSpecial?(attacker, type) && @battle.FE != :FROZENDIMENSION
      when :TOXICBOOST
        if (attacker.status == :POISON || [:CORROSIVE, :CORROSIVEMIST, :WASTELAND, :MURKWATERSURFACE].include?(@battle.FE)) && pbIsPhysical?(attacker, type)
          if @battle.FE == :CORRUPTED
            basemult *= 2.0
          else
            basemult *= 1.5
          end
        end
      when :PUNKROCK
        if isSoundBased?
          case @battle.FE
            when :BIGTOP then basemult *= 1.5
            when :CAVE then basemult *= 1.5
            else
              basemult *= 1.3
          end
        end
      when :RIVALRY       then basemult *= attacker.gender == opponent.gender ? 1.25 : 0.75 if attacker.gender != 2
      when :MEGALAUNCHER  then basemult *= 1.5 if [:AURASPHERE, :DRAGONPULSE, :DARKPULSE, :WATERPULSE, :ORIGINPULSE, :TERRAINPULSE].include?(@move)
      when :SANDFORCE     then basemult *= 1.3 if (@battle.pbWeather == :SANDSTORM || [:DESERT, :ASHENBEACH].include?(@battle.FE)) && (type == :ROCK || type == :GROUND || type == :STEEL)
      when :ANALYTIC      then basemult *= 1.3 if (@battle.battlers.find_all { |battler| battler && battler.hp > 0 && !battler.hasMovedThisRound? && !@battle.switchedOut[battler.index] }).length == 0
      when :SHEERFORCE    then basemult *= 1.3 if effect > 0
      when :AERILATE
        if @type == :NORMAL && type == :FLYING
          case @battle.FE
            when :MOUNTAIN, :SNOWYMOUNTAIN, :SKY then basemult *= 1.5
            else
              basemult *= 1.2
          end
        end
      when :GALVANIZE
        if @type == :NORMAL && type == :ELECTRIC
          case @battle.FE
            when :ELECTERRAIN, :FACTORY then basemult *= 1.5
            when :SHORTCIRCUIT then basemult *= 2
            else
              if @battle.state.effects[:ELECTERRAIN] > 0
                basemult *= 1.5
              else
                basemult *= 1.2
              end
          end
        end
      when :REFRIGERATE
        if @type == :NORMAL && type == :ICE
          case @battle.FE
            when :ICY, :SNOWYMOUNTAIN, :FROZENDIMENSION then basemult *= 1.5
            else
              basemult *= 1.2
          end
        end
      when :PIXILATE
        if @type == :NORMAL && (type == :FAIRY || (type == :NORMAL && @battle.FE == :GLITCH))
          case @battle.FE
            when :MISTY then basemult *= 1.5
            else
              if @battle.state.effects[:MISTY] > 0
                basemult *= 1.5
              else
                basemult *= 1.2
              end
          end
        end
      when :DUSKILATE     then basemult *= 1.2 if @type == :NORMAL && (type == :DARK || (type == :NORMAL && @battle.FE == :GLITCH))
      when :NORMALIZE     then basemult *= 1.2 if !@zmove
      when :TRANSISTOR    then basemult *= 1.5 if type == :ELECTRIC
      when :DRAGONSMAW    then basemult *= 1.5 if type == :DRAGON
      when :STEELWORKER   then basemult *= @battle.FE == :FACTORY ? 2.0 : 1.5 if type == :STEEL
      when :SOLARIDOL     then basemult *= 1.5 if type == :FIRE
      when :LUNARIDOL     then basemult *= 1.5 if type == :ICE
      when :TERAVOLT      then basemult *= 1.5 if Rejuv && @battle.FE == :ELECTERRAIN && type == :ELECTRIC
      when :INEXORABLE    then basemult *= 1.3 if type == :DRAGON && (!opponent.hasMovedThisRound? || @battle.switchedOut[opponent.index])
    end
    case opponent.ability
      when :HEATPROOF     then basemult *= 0.5 if !opponent.moldbroken && type == :FIRE
      when :DRYSKIN       then basemult *= 1.25 if !opponent.moldbroken && type == :FIRE
      when :TRANSISTOR    then basemult *= 0.5 if (@battle.FE == :ELECTERRAIN && type == :GROUND) && !opponent.moldbroken
    end
    if attitemworks
      if $cache.items[attacker.item].checkFlag?(:typeboost) == type
        if $cache.items[attacker.item].checkFlag?(:gem)
          basemult *= 1.3
          @battle.pbDisplay(_INTL("The {1} strengthened {2}'s power!", getItemName(attacker.item), self.name)) unless attacker.takegem
          attacker.takegem = true
        else
          basemult *= 1.2
        end
      else
        case attacker.item
          when :MUSCLEBAND then basemult *= 1.1 if pbIsPhysical?(attacker, type)
          when :WISEGLASSES then basemult *= 1.1 if pbIsSpecial?(attacker, type)
          when :LUSTROUSORB then basemult *= 1.2 if attacker.pokemon.species == :PALKIA && [:DRAGON, :WATER].include?(type)
          when :ADAMANTORB then basemult *= 1.2 if attacker.pokemon.species == :DIALGA && [:DRAGON, :STEEL].include?(type)
          when :GRISEOUSORB then basemult *= 1.2 if attacker.pokemon.species == :GIRATINA && [:DRAGON, :GHOST].include?(type)
          when :SOULDEW then basemult *= 1.2 if [:LATIAS, :LATIOS].include?(attacker.pokemon.species) && [:DRAGON, :PSYCHIC].include?(type)
        end
      end
    end
    basemult = pbBaseDamageMultiplier(basemult, attacker, opponent)
    # standard crest damage multipliers
    case attacker.crested
      when :FERALIGATR then basemult *= 1.5 if PBStuff::BITEMOVE.include?(@move)
      when :CLAYDOL then basemult *= 1.5 if isBeamMove?
      when :DRUDDIGON then basemult *= 1.3 if type == :DRAGON || type == :FIRE
      when :BOLTUND then basemult *= 1.5 if PBStuff::BITEMOVE.include?(@move) && (!opponent.hasMovedThisRound? || @battle.switchedOut[opponent.index])
      when :FEAROW then basemult *= 1.5 if PBStuff::STABBINGMOVE.include?(@move)
      when :DUSKNOIR then basemult *= 1.5 if basedmg <= 60 || ((@battle.FE == :FACTORY || @battle.ProgressiveFieldCheck(PBFields::CONCERT)) && basedmg <= 80)
      when :CRABOMINABLE then basemult *= 1.5 if attacker.lastHPLost > 0
      when :AMPHAROS then basemult *= attacker.hasType?(type) ? 1.2 : 1.5 if attacker.moves[0] == self
      when :LUXRAY then basemult *= 1.2 if @type == :NORMAL && type == :ELECTRIC
      when :SAWSBUCK
        case attacker.form
          when 0 then basemult *= 1.2 if @type == :NORMAL && type == :WATER
          when 1 then basemult *= 1.2 if @type == :NORMAL && type == :FIRE
          when 2 then basemult *= 1.2 if @type == :NORMAL && type == :GROUND
          when 3 then basemult *= 1.2 if @type == :NORMAL && type == :ICE
        end
    end
    # type mods
    case type
      when :FIRE then basemult *= 0.33 if @battle.state.effects[:WaterSport] > 0
      when :ELECTRIC
        basemult *= 0.33 if @battle.state.effects[:MudSport] > 0
        basemult *= 2.0 if attacker.effects[:Charge] > 0
    end
    if type == :DARK && @battle.pbCheckGlobalAbility(:DARKAURA)
      auramult = 1.33
      case @battle.FE
        when :DARKNESS1 then auramult = 1.4
        when :DARKNESS2 then auramult = 1.5
        when :DARKNESS3 then auramult = 1.66
      end
      basemult *= @battle.pbCheckGlobalAbility(:AURABREAK) ? 2 - auramult : auramult
    end
    if type == :FAIRY && @battle.pbCheckGlobalAbility(:FAIRYAURA)
      auramult = 1.33
      case @battle.FE
        when :DARKNESS1 then auramult = 1.3
        when :DARKNESS2 then auramult = 1.2
        when :DARKNESS3 then auramult = 1.1
      end
      basemult *= @battle.pbCheckGlobalAbility(:AURABREAK) ? 2 - auramult : auramult
    end
    basemult *= 1.5 if attacker.effects[:HelpingHand]
    basemult *= 2.0 if opponent.effects[:Minimize] && @move == :MALICIOUSMOONSAULT # Minimize for z-move
    # Specific Field Effects
    if @battle.field.isFieldEffect?
      fieldmult = moveFieldBoost
      if fieldmult != 1
        basemult *= fieldmult
        fieldmessage = moveFieldMessage
        if fieldmessage && !@fieldmessageshown
          if [:LIGHTTHATBURNSTHESKY, :ICEHAMMER, :HAMMERARM, :CRABHAMMER].include?(@move) # some moves have a {1} in them and we gotta deal.
            @battle.pbDisplay(_INTL(fieldmessage, attacker.pbThis))
          elsif [:SMACKDOWN, :THOUSANDARROWS, :ROCKSLIDE, :VITALTHROW, :CIRCLETHROW, :STORMTHROW, :DOOMDUMMY, :BLACKHOLEECLIPSE, :TECTONICRAGE, :CONTINENTALCRUSH, :WHIRLWIND, :CUT].include?(@move)
            @battle.pbDisplay(_INTL(fieldmessage, opponent.pbThis))
          else
            @battle.pbDisplay(_INTL(fieldmessage))
          end
          @fieldmessageshown = true
        end
      end
    end
    case @battle.FE
      when :CHESS
        if CHESSMOVES.include?(@move)
          basemult *= 0.5 if [:ADAPTABILITY, :ANTICIPATION, :SYNCHRONIZE, :TELEPATHY].include?(opponent.ability)
          basemult *= 2.0 if [:OBLIVIOUS, :KLUTZ, :UNAWARE, :SIMPLE].include?(opponent.ability) || opponent.effects[:Confusion] > 0 || (Rejuv && opponent.ability == :DEFEATIST)
          @battle.pbDisplay(_INTL("The chess piece slammed forward!")) if !@fieldmessageshown
          @fieldmessageshown = true
        end
        # Queen piece boost
        if attacker.pokemon.piece == :QUEEN || attacker.ability == :QUEENLYMAJESTY
          basemult *= 1.5
          if attacker.pokemon.piece == :QUEEN
            @battle.pbDisplay(_INTL("The Queen is dominating the board!")) && !@fieldmessageshown
            @fieldmessageshown = true
          end
        end

        # Knight piece boost
        if attacker.pokemon.piece == :KNIGHT && opponent.pokemon.piece == :QUEEN
          basemult = (basemult * 3.0).round
          @battle.pbDisplay(_INTL("An unblockable attack on the Queen!")) if !@fieldmessageshown
          @fieldmessageshown = true
        end
      when :BIGTOP
        if (type == :FIGHTING && pbIsPhysical?(attacker, type)) || STRIKERMOVES.include?(@move) # Continental Crush
          striker = 1 + @battle.pbRandom(14)
          @battle.pbDisplay(_INTL("WHAMMO!")) if !@fieldmessageshown
          @fieldmessageshown = true
          if attacker.ability == :HUGEPOWER || attacker.ability == :GUTS || attacker.ability == :PUREPOWER || attacker.ability == :SHEERFORCE
            if striker >= 9
              striker = 15
            else
              striker = 14
            end
          end
          strikermod = attacker.stages[PBStats::ATTACK]
          striker = striker + strikermod
          if striker >= 15
            @battle.pbDisplay(_INTL("...OVER 9000!!!"))
            provimult = 3.0
          elsif striker >= 13
            @battle.pbDisplay(_INTL("...POWERFUL!"))
            provimult = 2.0
          elsif striker >= 9
            @battle.pbDisplay(_INTL("...NICE!"))
            provimult = 1.5
          elsif striker >= 3
            @battle.pbDisplay(_INTL("...OK!"))
            provimult = 1
          else
            @battle.pbDisplay(_INTL("...WEAK!"))
            provimult = 0.5
          end
          provimult = ((provimult - 1.0) / 2.0) + 1.0 if $game_variables[:DifficultyModes] == 1 && !$game_switches[:FieldFrenzy]
          provimult = ((provimult - 1.0) * 2.0) + 1.0 if $game_variables[:DifficultyModes] != 1 && $game_switches[:FieldFrenzy] && provimult > 1
          provimult = provimult / 2.0 if $game_variables[:DifficultyModes] != 1 && $game_switches[:FieldFrenzy] && provimult < 1
          basemult *= provimult
        end
        if isSoundBased?
          provimult = 1.5
          provimult = 1.25 if $game_variables[:DifficultyModes] == 1
          provimult = ((provimult - 1.0) * 2.0) + 1.0 if $game_switches[:FieldFrenzy]
          basemult *= provimult
          @battle.pbDisplay(_INTL("Loud and clear!")) if !@fieldmessageshown
          @fieldmessageshown = true
        end
      when :ICY
        if (@priority >= 1 && @basedamage > 0 && contactMove? && attacker.ability != :LONGREACH) || [:FEINT, :ROLLOUT, :DEFENSECURL, :STEAMROLLER, :LUNGE, :ICEBALL].include?(@move)
          if !attacker.isAirborne?
            if attacker.pbIncreaseStat(PBStats::SPEED, 1, statmessage: false)
              if attacker.ability == :CONTRARY
                @battle.pbDisplay(_INTL("{1} lost momentum on the ice!", attacker.pbThis)) if !@fieldmessageshown
              else
                @battle.pbDisplay(_INTL("{1} gained momentum on the ice!", attacker.pbThis)) if !@fieldmessageshown
              end
              @fieldmessageshown = true
            end
          end
        end
      when :SHORTCIRCUIT
        if type == :ELECTRIC
          damageroll = @battle.field.getRoll(maximize_roll: (@battle.state.effects[:ELECTERRAIN] > 0))
          messageroll = ["Bzzt.", "Bzzapp!", "Bzt...", "Bzap!", "BZZZAPP!"][PBStuff::SHORTCIRCUITROLLS.index(damageroll)]
          @battle.pbDisplay(messageroll) if !@fieldmessageshown
          damageroll = ((damageroll - 1.0) / 2.0) + 1.0 if $game_variables[:DifficultyModes] == 1 && !$game_switches[:FieldFrenzy]
          damageroll = ((damageroll - 1.0) * 2.0) + 1.0 if $game_variables[:DifficultyModes] != 1 && $game_switches[:FieldFrenzy] && damageroll > 1
          damageroll = damageroll / 2.0 if $game_variables[:DifficultyModes] != 1 && $game_switches[:FieldFrenzy] && damageroll < 1
          basemult *= damageroll

          @fieldmessageshown = true
        end
      when :CAVE
        if isSoundBased?
          provimult = 1.5
          provimult = 1.25 if $game_variables[:DifficultyModes] == 1
          provimult = ((provimult - 1.0) * 2.0) + 1.0 if $game_switches[:FieldFrenzy]
          basemult *= provimult
          @battle.pbDisplay(_INTL("ECHO-Echo-echo!", opponent.pbThis)) if !@fieldmessageshown
          @fieldmessageshown = true
        end
      when :MOUNTAIN
        if PBFields::WINDMOVES.include?(@move) && @battle.pbWeather == :STRONGWINDS
          provimult = 1.5
          provimult = 1.25 if $game_variables[:DifficultyModes] == 1
          provimult = ((provimult - 1.0) * 2.0) + 1.0 if $game_switches[:FieldFrenzy]
          basemult *= provimult
          @battle.pbDisplay(_INTL("The wind strengthened the attack!", opponent.pbThis)) if !@fieldmessageshown
          @fieldmessageshown = true
        end
      when :SNOWYMOUNTAIN
        if PBFields::WINDMOVES.include?(@move) && @battle.pbWeather == :STRONGWINDS
          provimult = 1.5
          provimult = 1.25 if $game_variables[:DifficultyModes] == 1
          provimult = ((provimult - 1.0) * 2.0) + 1.0 if $game_switches[:FieldFrenzy]
          basemult *= provimult
          @battle.pbDisplay(_INTL("The wind strengthened the attack!", opponent.pbThis)) if !@fieldmessageshown
          @fieldmessageshown = true
        end
      when :MIRROR
        if PBFields::MIRRORMOVES.include?(@move) && opponent.stages[PBStats::EVASION] > 0
          provimult = 2.0
          provimult = 1.5 if $game_variables[:DifficultyModes] == 1
          provimult = ((provimult - 1.0) * 2.0) + 1.0 if $game_switches[:FieldFrenzy]
          basemult *= provimult
          @battle.pbDisplay(_INTL("The beam was focused from the reflection!", opponent.pbThis)) if !@fieldmessageshown
          @fieldmessageshown = true
        end
        @battle.field.counter = 0
      when :DEEPEARTH
        if priorityCheck(attacker) > 0 && @basedamage > 0
          provimult = 0.7
          provimult = 0.85 if $game_variables[:DifficultyModes] == 1
          provimult = ((provimult - 1.0) * 2.0) + 1.0 if $game_switches[:FieldFrenzy]
          basemult *= provimult
          @battle.pbDisplay(_INTL("The intense pull slowed the attack...")) if !@fieldmessageshown
          @fieldmessageshown = true
        end
        if priorityCheck(attacker) < 0 && @basedamage > 0
          provimult = 1.3
          provimult = 1.15 if $game_variables[:DifficultyModes] == 1
          provimult = ((provimult - 1.0) * 2.0) + 1.0 if $game_switches[:FieldFrenzy]
          basemult *= provimult
          @battle.pbDisplay(_INTL("Slow and heavy!")) if !@fieldmessageshown
          @fieldmessageshown = true
        end
      when :CONCERT1, :CONCERT2, :CONCERT3, :CONCERT4
        if isSoundBased?
          provimult = 1.5
          provimult = 1.25 if $game_variables[:DifficultyModes] == 1
          provimult = ((provimult - 1.0) * 2.0) + 1.0 if $game_switches[:FieldFrenzy]
          basemult *= provimult
          @battle.pbDisplay(_INTL("Loud and clear!")) if !@fieldmessageshown
          @fieldmessageshown = true
        end
      when :DARKNESS3, :DARKNESS2
        if [:LIGHTTHATBURNSTHESKY].include?(@move)
          @battle.pbDisplay(_INTL("One brings Shadow, One brings the Light!")) if !@fieldmessageshown
          @fieldmessageshown = true
        end
    end
    if Rejuv
      for terrain in [:ELECTERRAIN, :GRASSY, :MISTY, :PSYTERRAIN]
        if @battle.state.effects[terrain] > 0
          overlaymult = moveOverlayBoost(terrain)
          if overlaymult != 1
            basemult *= overlaymult
            overlaymessage = moveOverlayMessage(terrain)
            @battle.pbDisplay(_INTL(overlaymessage)) if overlaymessage
          end
        end
      end
    end
    # End S.Field Effects
    ##### Calculate attacker's attack stat #####
    case @function
      when 0x121 # Foul Play
        atk = opponent.attack
        atkstage = opponent.stages[PBStats::ATTACK] + 6
      when 0x184 # Body Press
        atk = attacker.defense
        atkstage = attacker.stages[PBStats::DEFENSE] + 6
      else
        atk = attacker.attack
        atkstage = attacker.stages[PBStats::ATTACK] + 6
    end
    if pbIsSpecial?(attacker, type)
      atk = attacker.spatk
      atkstage = attacker.stages[PBStats::SPATK] + 6
      if @function == 0x121 # Foul Play
        atk = opponent.spatk
        atkstage = opponent.stages[PBStats::SPATK] + 6
      end
      if @battle.FE == :GLITCH
        atk = attacker.getSpecialStat(opponent.ability == :UNAWARE, attacker: true, crit: opponent.damagestate.critical)
        atkstage = 6 # getspecialstat handles unaware
      end
    end
    # Stat-Copy Crests, ala Claydol//Dedenne
    case attacker.crested
      when :CLAYDOL then atkstage = attacker.stages[PBStats::DEFENSE] + 6 if pbIsSpecial?(attacker, type)
      when :DEDENNE then atkstage = attacker.stages[PBStats::SPEED] + 6 if !pbIsSpecial?(attacker, type)
    end
    if opponent.ability != :UNAWARE || opponent.moldbroken
      atkstage = 6 if opponent.damagestate.critical && atkstage < 6
      atk = (atk * PBStats::StageMul[atkstage]).floor
    end
    if attacker.ability == :HUSTLE && pbIsPhysical?(attacker, type)
      atk = [:BACKALLEY, :CITY].include?(@battle.FE) ? (atk * 1.75).round : (atk * 1.5).round
    end
    atkmult = 1.0
    if [:HAUNTED, :BEWITCHED, :HOLY, :PSYTERRAIN, :DEEPEARTH].include?(@battle.FE)
      atkmult *= 1.5 if attacker.pbPartner.ability == :POWERSPOT
    else
      atkmult *= 1.3 if attacker.pbPartner.ability == :POWERSPOT
    end
    # pinch abilities
    if [:BURNING, :VOLCANIC, :INFERNAL].include?(@battle.FE) && attacker.ability == :BLAZE && type == :FIRE
      atkmult *= 1.5
    elsif @battle.FE == :VOLCANICTOP && attacker.ability == :BLAZE && type == :FIRE && attacker.effects[:Blazed]
      atkmult *= 1.5
    elsif (@battle.FE == :FOREST || (Rejuv && @battle.FE == :GRASSY)) && attacker.ability == :OVERGROW && type == :GRASS
      atkmult *= 1.5
    elsif @battle.FE == :FOREST && attacker.ability == :SWARM && type == :BUG
      atkmult *= 1.5
    elsif ((@battle.FE == :WATERSURFACE && !attacker.isAirborne?) || @battle.FE == :UNDERWATER) && attacker.ability == :TORRENT && type == :WATER
      atkmult *= 1.5
    elsif @battle.ProgressiveFieldCheck(PBFields::FLOWERGARDEN) && attacker.ability == :SWARM && type == :BUG
      atkmult *= 1.5 if @battle.ProgressiveFieldCheck(PBFields::FLOWERGARDEN, 1, 2)
      atkmult *= 1.8 if @battle.ProgressiveFieldCheck(PBFields::FLOWERGARDEN, 3, 4)
      atkmult *= 2.0 if @battle.FE == :FLOWERGARDEN5
    elsif @battle.ProgressiveFieldCheck(PBFields::FLOWERGARDEN, 2, 5) && attacker.ability == :OVERGROW && type == :GRASS
      case @battle.FE
        when :FLOWERGARDEN2 then atkmult *= 1.5 if attacker.hp <= (attacker.totalhp * 0.67).floor
        when :FLOWERGARDEN3 then atkmult *= 1.6
        when :FLOWERGARDEN4 then atkmult *= 1.8
        when :FLOWERGARDEN5 then atkmult *= 2.0
      end
    elsif attacker.hp <= (attacker.totalhp / 3.0).floor
      if (attacker.ability == :OVERGROW && type == :GRASS) || (attacker.ability == :BLAZE && type == :FIRE && @battle.FE != :FROZENDIMENSION) ||
         (attacker.ability == :TORRENT && type == :WATER) || (attacker.ability == :SWARM && type == :BUG)
        atkmult *= 1.5
      end
    end
    case attacker.ability
      when :GUTS then atkmult *= 1.5 if !attacker.status.nil? && pbIsPhysical?(attacker, type)
      when :PLUS, :MINUS
        if pbIsSpecial?(attacker, type) && @battle.FE != :GLITCH
          partner = attacker.pbPartner
          if partner.ability == :PLUS || partner.ability == :MINUS
            atkmult *= 1.5
          elsif @battle.FE == :SHORTCIRCUIT || (Rejuv && @battle.FE == :ELECTERRAIN) || @battle.state.effects[:ELECTERRAIN] > 0
            atkmult *= 1.5
          end
        end
      when :DEFEATIST then atkmult *= 0.5 if attacker.hp <= (attacker.totalhp / 2.0).floor
      when :HUGEPOWER then atkmult *= 2.0 if pbIsPhysical?(attacker, type)
      when :PUREPOWER
        if @battle.FE == :PSYTERRAIN || @battle.state.effects[:PSYTERRAIN] > 0
          atkmult *= 2.0 if pbIsSpecial?(attacker, type)
        else
          atkmult *= 2.0 if pbIsPhysical?(attacker, type)
        end
      when :SOLARPOWER then atkmult *= 1.5 if (@battle.pbWeather == :SUNNYDAY && !(attitemworks && attacker.item == :UTILITYUMBRELLA)) && pbIsSpecial?(attacker, type) && ![:GLITCH, :FROZENDIMENSION].include?(@battle.FE)
      when :SLOWSTART then atkmult *= 0.5 if attacker.turncount < 5 && pbIsPhysical?(attacker, type) && @battle.FE != :DEEPEARTH
      when :GORILLATACTICS then atkmult *= 1.5 if pbIsPhysical?(attacker, type)
      when :QUARKDRIVE then atkmult *= 1.3 if (attacker.effects[:Quarkdrive][0] == PBStats::ATTACK && pbIsPhysical?(attacker, type)) || (attacker.effects[:Quarkdrive][0] == PBStats::SPATK && pbIsSpecial?(attacker, type))
    end
    # Mid Battle stat multiplying crests; Spiritomb Crest, Castform Crest
    case attacker.crested
      when :CASTFORM then atkmult *= 1.5 if attacker.form == 1 && (@battle.pbWeather == :SUNNYDAY && !(attitemworks && attacker.item == :UTILITYUMBRELLA)) && pbIsSpecial?(attacker, type) && ![:GLITCH, :FROZENDIMENSION].include?(@battle.FE)
      when :SPIRITOMB
        allyfainted = attacker.pbFaintedPokemonCount
        modifier = (allyfainted * 0.2) + 1.0
        atkmult = (atkmult * modifier).round
    end
    if ((@battle.pbWeather == :SUNNYDAY && !(attitemworks && attacker.item == :UTILITYUMBRELLA)) || @battle.ProgressiveFieldCheck(PBFields::FLOWERGARDEN) || @battle.FE == :BEWITCHED) && pbIsPhysical?(attacker, type)
      atkmult *= 1.5 if attacker.ability == :FLOWERGIFT && attacker.species == :CHERRIM
      atkmult *= 1.5 if attacker.pbPartner.ability == :FLOWERGIFT && attacker.pbPartner.species == :CHERRIM
    end
    if @battle.pbWeather == :SUNNYDAY && pbIsPhysical?(attacker, type)
      atkmult *= 1.5 if attacker.ability == :SOLARIDOL
    end
    if @battle.pbWeather == :HAIL && pbIsSpecial?(attacker, type)
      atkmult *= 1.5 if attacker.ability == :LUNARIDOL
    end
    if attacker.pbPartner.ability == :BATTERY && pbIsSpecial?(attacker, type) && @battle.FE != :GLITCH
      if Rejuv && @battle.FE == :ELECTERRAIN
        atkmult *= 1.5
      else
        atkmult *= 1.3
      end
    end
    if @battle.FE == :FAIRYTALE
      atkmult *= 2.0 if (attacker.pbPartner.ability == :STEELYSPIRIT || attacker.ability == :STEELYSPIRIT) && type == :STEEL
    else
      atkmult *= 1.5 if (attacker.pbPartner.ability == :STEELYSPIRIT || attacker.ability == :STEELYSPIRIT) && type == :STEEL
    end
    atkmult *= 1.5 if attacker.effects[:FlashFire] && type == :FIRE && @battle.FE != :FROZENDIMENSION

    if attitemworks
      case attacker.item
        when :THICKCLUB then atkmult *= 2.0 if (attacker.pokemon.species == :CUBONE || attacker.pokemon.species == :MAROWAK) && pbIsPhysical?(attacker, type)
        when :DEEPSEATOOTH then atkmult *= 2.0 if attacker.pokemon.species == :CLAMPERL && pbIsSpecial?(attacker, type) && @battle.FE != :GLITCH
        when :LIGHTBALL then atkmult *= 2.0 if attacker.pokemon.species == :PIKACHU && @battle.FE != :GLITCH
        when :CHOICEBAND then atkmult *= 1.5 if pbIsPhysical?(attacker, type)
        when :CHOICESPECS then atkmult *= 1.5 if pbIsSpecial?(attacker, type) && @battle.FE != :GLITCH
      end
    end
    if @battle.FE != :INDOOR
      if [:STARLIGHT, :NEWWORLD].include?(@battle.FE)
        if attacker.ability == :VICTORYSTAR
          atkmult *= 1.5
        end
        partner = attacker.pbPartner
        if partner && partner.ability == :VICTORYSTAR
          atkmult *= 1.5
        end
      end
      if @battle.FE == :WATERSURFACE
        atkmult *= 1.5 if attacker.ability == :PROPELLERTAIL && @priority >= 1 && @basedamage > 0
      end
      if @battle.FE == :UNDERWATER
        atkmult *= 0.5 if (!Rejuv || !attacker.hasType?(:WATER)) && pbIsPhysical?(attacker, type) && type != :WATER && attacker.ability != :STEELWORKER && attacker.ability != :SWIFTSWIM
        atkmult *= 1.5 if attacker.ability == :PROPELLERTAIL && @priority >= 1 && @basedamage > 0
      end
      if Rejuv && @battle.FE == :CHESS
        atkmult *= 1.2 if attacker.ability == :GORILLATACTICS || attacker.ability == :RECKLESS
        atkmult *= 1.2 if attacker.ability == :ILLUSION && attacker.effects[:Illusion] != nil
        if attacker.ability == :COMPETITIVE
          frac = (1.0 * attacker.hp) / (1.0 * attacker.totalhp)
          multiplier = 1.0
          multiplier += ((1.0 - frac) / 0.8)
          if frac < 0.2
            multiplier = 2.0
          end
          atkmult *= multiplier
        end
      end
      case attacker.ability
        when :QUEENLYMAJESTY then atkmult *= 1.5 if @battle.FE == :FAIRYTALE
        when :LONGREACH then atkmult *= 1.5 if [:MOUNTAIN, :SNOWYMOUNTAIN, :SKY].include?(@battle.FE)
        when :CORROSION then atkmult *= 1.5 if [:CORROSIVE, :CORROSIVEMIST, :CORRUPTED].include?(@battle.FE)
        when :SKILLLINK then atkmult *= 1.2 if @battle.FE == :COLOSSEUM && (@function == 0xC0 || @function == 0x307 || (attacker.crested == :CINCCINO && !pbIsMultiHit)) # 0xC0: 2-5 hits; 0x307: Scale Shot
      end
    end
    atkmult *= 0.5 if opponent.ability == :THICKFAT && (type == :ICE || type == :FIRE) && !opponent.moldbroken

    ##### Calculate opponent's defense stat #####
    defense = opponent.defense
    defstage = opponent.stages[PBStats::DEFENSE] + 6
    # TODO: Wonder Room should apply around here

    applysandstorm = false
    if pbHitsSpecialStat?(attacker, type)
      defense = opponent.spdef
      defstage = opponent.stages[PBStats::SPDEF] + 6
      applysandstorm = true
      if @battle.FE == :GLITCH
        defense = opponent.getSpecialStat(attacker.ability == :UNAWARE, attacker: false, crit: opponent.damagestate.critical)
        defstage = 6 # getspecialstat handles unaware
        applysandstorm = false # getSpecialStat handles sandstorm
      end
    end
    if attacker.ability != :UNAWARE
      defstage = 6 if @function == 0xA9 # Chip Away (ignore stat stages)
      defstage = 6 if opponent.damagestate.critical && defstage > 6
      defense = (defense * PBStats::StageMul[defstage]).floor
    end
    if @battle.pbWeather == :SANDSTORM && opponent.hasType?(:ROCK) && applysandstorm
      defense = (defense * 1.5).round
    end
    defmult = 1.0
    defmult *= 0.5 if @battle.FE == :GLITCH && @function == 0xE0
    defmult *= 0.5 if attacker.crested == :ELECTRODE && pbHitsPhysicalStat?(attacker, type)
    # Field Effect defense boost
    defmult *= fieldDefenseBoost(type, attacker, opponent)

    # Abilities defense boost
    case opponent.ability
      when :ICESCALES then defmult *= 2.0 if pbIsSpecial?(attacker, type) && !opponent.moldbroken
      when :MARVELSCALE then defmult *= 1.5 if pbHitsPhysicalStat?(attacker, type) && (!opponent.status.nil? || ([:MISTY, :RAINBOW, :FAIRYTALE, :DRAGONSDEN, :STARLIGHT].include?(@battle.FE) || @battle.state.effects[:MISTY] > 0)) && !opponent.moldbroken
      when :GRASSPELT then defmult *= 1.5 if pbHitsPhysicalStat?(attacker, type) && ([:GRASSY, :FOREST].include?(@battle.FE) || @battle.state.effects[:GRASSY] > 0) # Grassy Field
      when :FURCOAT then defmult *= 2.0 if pbIsPhysical?(attacker, type) && !opponent.moldbroken
      when :PUNKROCK then defmult *= 2.0 if isSoundBased? && !opponent.moldbroken
      when :QUARKDRIVE then defmult *= 1.3 if (opponent.effects[:Quarkdrive][0] == PBStats::DEFENSE && pbHitsPhysicalStat?(attacker, type)) || (opponent.effects[:Quarkdrive][0] == PBStats::SPDEF && pbHitsSpecialStat?(attacker, type))
      when :FLUFFY
        defmult *= 2.0 if contactMove? && attacker.ability != :LONGREACH && !opponent.moldbroken
        defmult *= 4.0 if contactMove? && attacker.ability != :LONGREACH && @battle.FE == :CLOUDS && !opponent.moldbroken
        defmult *= 0.5 if type == :FIRE && !opponent.moldbroken
    end
    if ((@battle.pbWeather == :SUNNYDAY && !opponent.hasWorkingItem(:UTILITYUMBRELLA)) || opponent.crested == :CHERRIM || @battle.ProgressiveFieldCheck(PBFields::FLOWERGARDEN) || @battle.FE == :BEWITCHED) && !opponent.moldbroken && pbHitsSpecialStat?(attacker, type)
      defmult *= 1.5 if opponent.ability == :FLOWERGIFT && opponent.species == :CHERRIM
      defmult *= 1.5 if opponent.pbPartner.ability == :FLOWERGIFT && opponent.pbPartner.species == :CHERRIM
    end
    # Item defense boost
    if opponent.hasWorkingItem(:EVIOLITE) && !(@battle.FE == :GLITCH && pbHitsSpecialStat?(attacker, type))
      evos = pbGetEvolvedFormData(opponent.pokemon.species, opponent.pokemon)
      defmult *= 1.5 if evos && evos.length > 0
    end
    if opponent.hasWorkingItem(:PIKANIUMZ) && opponent.pokemon.species == :PIKACHU && !(@battle.FE == :GLITCH && pbHitsSpecialStat?(attacker, type))
      defmult *= 1.5
    end
    if opponent.hasWorkingItem(:LIGHTBALL) && opponent.pokemon.species == :PIKACHU && !(@battle.FE == :GLITCH && pbHitsSpecialStat?(attacker, type))
      defmult *= 1.5
    end
    if opponent.hasWorkingItem(:ASSAULTVEST) && pbHitsSpecialStat?(attacker, type) && @battle.FE != :GLITCH
      defmult *= 1.5
    end
    if opponent.hasWorkingItem(:DEEPSEASCALE) && @battle.FE != :GLITCH && opponent.pokemon.species == :CLAMPERL && pbHitsSpecialStat?(attacker, type)
      defmult *= 2.0
    end
    if opponent.hasWorkingItem(:METALPOWDER) && opponent.pokemon.species == :DITTO && !opponent.effects[:Transform] && pbHitsPhysicalStat?(attacker, type)
      defmult *= 2.0
    end

    # General damage modifiers
    # variable "damage" used from here on out
    # damage at this point is generaly 1 ; unless it's a spread move in which case it's 0.75 normally or 1.25 for knight pieces on chess

    # Field Effects
    fieldBoost = typeFieldBoost(type, attacker, opponent)
    overlayBoost, overlay = typeOverlayBoost(type, attacker, opponent)
    if fieldBoost != 1 || overlayBoost != 1
      if fieldBoost > 1 && overlayBoost > 1
        boost = [fieldBoost, overlayBoost].max
        if $game_variables[:DifficultyModes] == 1 && !$game_switches[:FieldFrenzy]
          boost = 1.25 if boost < 1.25
        elsif $game_variables[:DifficultyModes] != 1 && $game_switches[:FieldFrenzy]
          boost = 2.0 if boost < 2.0
        else
          boost = 1.5 if boost < 1.5
        end
      else
        boost = fieldBoost * overlayBoost
      end
      damage *= boost
      fieldmessage = typeFieldMessage(type) if fieldBoost != 1
      overlaymessage = typeOverlayMessage(type, overlay) if overlay
      if overlaymessage && !fieldmessage
        @battle.pbDisplay(_INTL(overlaymessage)) if !@fieldmessageshown_type
      else
        @battle.pbDisplay(_INTL(fieldmessage)) if fieldmessage && !@fieldmessageshown_type
      end
      @fieldmessageshown_type = true
    end
    case @battle.FE
      when :MOUNTAIN, :SNOWYMOUNTAIN
        if type == :FLYING && !pbIsPhysical?(attacker, type) && @battle.pbWeather == :STRONGWINDS
          provimult = 1.5
          provimult = 1.25 if $game_variables[:DifficultyModes] == 1
          provimult = ((provimult - 1.0) * 2.0) + 1.0 if $game_switches[:FieldFrenzy]
          damage *= provimult
        end
      when :DEEPEARTH
        if type == :GROUND && opponent.hasType?(:GROUND)
          provimult = 0.5
          provimult = 0.75 if $game_variables[:DifficultyModes] == 1 && !$game_switches[:FieldFrenzy]
          provimult = 0.25 if $game_variables[:DifficultyModes] != 1 && $game_switches[:FieldFrenzy]
          damage *= provimult
          @battle.pbDisplay(_INTL("The dense earth is difficult to mold...")) if !@fieldmessageshown_type
          @fieldmessageshown_type = true
        end
    end
    case @battle.pbWeather
      when :SUNNYDAY
        if @battle.state.effects[:HarshSunlight] && type == :WATER
          @battle.pbDisplay(_INTL("The Water-type attack evaporated in the harsh sunlight!"))
          @battle.scene.pbUnVanishSprite(attacker) if @function == 0xCB # Dive
          return 0
        end
      when :RAINDANCE
        if @battle.state.effects[:HeavyRain] && type == :FIRE
          @battle.pbDisplay(_INTL("The Fire-type attack fizzled out in the heavy rain!"))
          return 0
        end
    end

    # FIELD TRANSFORMATIONS
    if @battle.shouldApplyFieldChangeDamageBoost(self, attacker)
      provimult = 1.3
      provimult = 1.15 if $game_variables[:DifficultyModes] == 1
      provimult = ((provimult - 1.0) * 2.0) + 1.0 if $game_switches[:FieldFrenzy]
      damage *= provimult
    end

    case type
      when :FIRE
        damage *= 1.5 if @battle.pbWeather == :SUNNYDAY
        damage *= 0.5 if @battle.pbWeather == :RAINDANCE
        damage *= 0.5 if opponent.ability == :WATERBUBBLE
      when :WATER
        damage *= 1.5 if @battle.pbWeather == :RAINDANCE
        damage *= 0.5 if @battle.pbWeather == :SUNNYDAY
        damage *= 2 if attacker.ability == :WATERBUBBLE
    end
    # Critical hits
    if opponent.damagestate.critical
      damage *= 1.5
      damage *= 1.5 if attacker.ability == :SNIPER
    end
    # STAB-addition from Crests
    typecrest = false
    case attacker.crested
      when :EMPOLEON then typecrest = true if type == :ICE
      when :LUXRAY then typecrest = true if type == :DARK
      when :SAMUROTT then typecrest = true if type == :FIGHTING
      when :SIMISEAR then typecrest = true if type == :WATER
      when :SIMIPOUR then typecrest = true if type == :GRASS
      when :SIMISAGE then typecrest = true if type == :FIRE
      when :ZOROARK
        party = @battle.pbPartySingleOwner(attacker.index)
        party = party.find_all { |item| item && !item.egg? && item.hp > 0 }
        if party[party.length - 1] != attacker.pokemon
          typecrest = true if party[party.length - 1].hasType?(type)
        end
    end
    # STAB
    if (attacker.hasType?(type) && !attacker.effects[:DesertsMark]) || typecrest == true
      if attacker.ability == :ADAPTABILITY || (attacker.hasType?(type) && typecrest == true)
        damage *= 2.0
      else
        damage *= 1.5
      end
      if attacker.crested == :SILVALLY
        damage *= 1.2
      end
    end
    # Type Effectiveness (typemod has been calced earlier)
    damage = (damage * typemod / 4.0)

    damage *= 0.5 if attacker.status == :BURN && pbIsPhysical?(attacker, type) && attacker.ability != :GUTS && @move != :FACADE
    # Random Variance
    if !$game_switches[:No_Damage_Rolls] || @battle.isOnline?
      random = 85 + @battle.pbRandom(16)
    elsif $game_switches[:No_Damage_Rolls] || !@battle.isOnline?
      random = 93
    end
    random = 85 if @battle.FE == :CONCERT1
    random = 100 if @battle.FE == :CONCERT4
    damage = (damage * (random / 100.0))

    # Final damage modifiers
    finalmult = 1.0
    if !opponent.damagestate.critical && attacker.ability != :INFILTRATOR
      # Screens
      if @category != :status && opponent.pbOwnSide.screenActive?(betterCategory(attacker, type))
        finalmult *= @battle.doublebattle ? 0.66 : 0.5
      end
      if opponent.pbOwnSide.effects[:AreniteWall] > 0 && opponent.damagestate.typemod > 4
        finalmult *= 0.5
      end
    end
    finalmult *= 0.67 if opponent.crested == :BEHEEYEM && (!opponent.hasMovedThisRound? || @battle.switchedOut[opponent.index])
    secondtypes = self.getSecondaryType(attacker)
    finalmult *= 0.5 if opponent.effects[:Shelter] && @battle.FE != :INDOOR && (type == @battle.field.mimicry || (!secondtypes.nil? && secondtypes.include?(@battle.field.mimicry)))
    finalmult *= 0.5 if opponent.ability == :MULTISCALE && !opponent.moldbroken && opponent.hp == opponent.totalhp
    finalmult *= 0.5 if opponent.ability == :SHADOWSHIELD && (opponent.hp == opponent.totalhp || @battle.FE == :DIMENSIONAL)
    finalmult *= 0.66 if opponent.ability == :SHADOWSHIELD && opponent.hp == opponent.totalhp && [:DARKNESS2, :DARKNESS3].include?(@battle.FE)
    finalmult *= 2.0 if attacker.ability == :TINTEDLENS && opponent.damagestate.typemod < 4
    finalmult *= 2.0 if attacker.ability == :EXECUTION && opponent.hp <= (opponent.totalhp / 2).floor
    finalmult *= 0.75 if opponent.pbPartner.ability == :FRIENDGUARD && !opponent.moldbroken
    finalmult *= 0.5 if (opponent.ability == :PASTELVEIL || opponent.pbPartner.ability == :PASTELVEIL) && @type == :POISON && ([:MISTY, :RAINBOW].include?(@battle.FE) || @battle.state.effects[:MISTY] > 0)
    if @battle.ProgressiveFieldCheck(PBFields::FLOWERGARDEN, 3, 5)
      if (opponent.pbPartner.ability == :FLOWERVEIL && opponent.hasType?(:GRASS)) || (opponent.ability == :FLOWERVEIL && !opponent.moldbroken)
        finalmult *= 0.75
        @battle.pbDisplay(_INTL("The Flower Veil softened the attack!"))
      end
    end
    finalmult *= 0.75 if (((opponent.ability == :SOLIDROCK || opponent.ability == :FILTER) && !opponent.moldbroken) || opponent.ability == :PRISMARMOR) && opponent.damagestate.typemod > 4
    finalmult *= 0.75 if opponent.ability == :SHADOWSHIELD && [:STARLIGHT, :NEWWORLD, :DARKCRYSTALCAVERN].include?(@battle.FE) && opponent.damagestate.typemod > 4
    finalmult *= 0.70 if opponent.crested == :AMPHAROS && opponent.damagestate.typemod > 4
    finalmult *= 2.0 if attacker.ability == :STAKEOUT && @battle.switchedOut[opponent.index]
    finalmult *= [1.0 + attacker.effects[:Metronome] * 0.2, 2.0].min if attitemworks && attacker.item == :METRONOME && attacker.movesUsed[-2] == attacker.movesUsed[-1]
    finalmult *= [1.0 + attacker.effects[:Metronome] * 0.2, 2.0].min if @battle.FE == :CONCERT4 && attacker.movesUsed[-2] == attacker.movesUsed[-1]
    finalmult *= 1.2 if attitemworks && attacker.item == :EXPERTBELT && opponent.damagestate.typemod > 4
    finalmult *= 1.25 if attacker.ability == :NEUROFORCE && opponent.damagestate.typemod > 4
    finalmult *= 1.3 if attitemworks && attacker.item == :LIFEORB
    if opponent.damagestate.typemod > 4 && opponent.itemWorks?
      hasberry = false
      case type
        when :FIGHTING   then hasberry = opponent.item == :CHOPLEBERRY
        when :FLYING     then hasberry = opponent.item == :COBABERRY
        when :POISON     then hasberry = opponent.item == :KEBIABERRY
        when :GROUND     then hasberry = opponent.item == :SHUCABERRY
        when :ROCK       then hasberry = opponent.item == :CHARTIBERRY
        when :BUG        then hasberry = opponent.item == :TANGABERRY
        when :GHOST      then hasberry = opponent.item == :KASIBBERRY
        when :STEEL      then hasberry = opponent.item == :BABIRIBERRY
        when :FIRE       then hasberry = opponent.item == :OCCABERRY
        when :WATER      then hasberry = opponent.item == :PASSHOBERRY
        when :GRASS      then hasberry = opponent.item == :RINDOBERRY
        when :ELECTRIC   then hasberry = opponent.item == :WACANBERRY
        when :PSYCHIC    then hasberry = opponent.item == :PAYAPABERRY
        when :ICE        then hasberry = opponent.item == :YACHEBERRY
        when :DRAGON     then hasberry = opponent.item == :HABANBERRY
        when :DARK       then hasberry = opponent.item == :COLBURBERRY
        when :FAIRY      then hasberry = opponent.item == :ROSELIBERRY
      end
    end
    hasberry = true if opponent.hasWorkingItem(:CHILANBERRY) && type == :NORMAL
    hasberry = false if [:UNNERVE, :ASONECHILLING, :ASONEGRIM].intersect?([attacker.ability, attacker.pbPartner.ability])
    hasberry = false if opponent.effects[:Substitute] > 0 && attacker.ability != :INFILTRATOR && !isSoundBased? && ![:SPECTRALTHIEF, :HYPERSPACEHOLE, :HYPERSPACEFURY].include?(@move)
    if hasberry
      finalmult *= opponent.ability == :RIPEN ? 0.25 : 0.5
      opponent.pbDisposeItem(true, true, true, true)
      if !@battle.pbIsOpposing?(attacker.index)
        @battle.pbDisplay(_INTL("{2}'s {1} weakened the damage from the attack!", getItemName(opponent.pokemon.itemRecycle), opponent.pbThis))
      else
        @battle.pbDisplay(_INTL("The {1} weakened the damage to {2}!", getItemName(opponent.pokemon.itemRecycle), opponent.pbThis))
      end
    end
    finalmult *= 0.8 if opponent.crested == :MEGANIUM || opponent.pbPartner.crested == :MEGANIUM
    if attacker.crested == :SEVIPER
      multiplier = 0.5 * (opponent.pokemon.hp * 1.0) / (opponent.pokemon.totalhp * 1.0)
      multiplier += 1.0
      finalmult = (finalmult * multiplier)
    end
    if @zmove
      if opponent.pbOwnSide.effects[:MatBlock] || opponent.effects[:Protect] ||
         (opponent.pbOwnSide.effects[:WideGuard] && [:AllOpposing, :AllNonUsers].include?(attacker.pbTarget(self)))
        if @move == :UNLEASHEDPOWER
          @battle.pbDisplay(_INTL("The Interceptor's power broke through {1}'s Protect!", opponent.pbThis))
        elsif !opponent.effects[:ProtectNegation]
          @battle.pbDisplay(_INTL("{1} couldn't fully protect itself!", opponent.pbThis))
          finalmult /= 4
        end
      end
    end
    finalmult = pbModifyDamage(finalmult, attacker, opponent)
    ##### Main damage calculation #####
    basedmg *= basemult
    atk *= atkmult
    defense *= defmult
    totaldamage = (((((2.0 * attacker.level / 5 + 2).floor * basedmg * atk / defense).floor / 50.0).floor + 2) * damage * finalmult).round
    totaldamage = 1 if totaldamage < 1
    opponent.damagestate.calcdamage = totaldamage
    return totaldamage
  end

  def pbReduceHPDamage(damage, attacker, opponent)
    futureMoves = [:FUTUREDUMMY, :DOOMDUMMY, :HEXDUMMY]
    if futureMoves.include?(@move)
      damage = pbCalcDamage(attacker, opponent)
    end
    if opponent.effects[:Substitute] > 0 && (!attacker || attacker.index != opponent.index) &&
       attacker.ability != :INFILTRATOR && !isSoundBased? &&
       @move != :SPECTRALTHIEF && @move != :HYPERSPACEHOLE && @move != :HYPERSPACEFURY # spectral thief/ hyperspace hole/ hyperspace fury
      damage = opponent.effects[:Substitute] if damage > opponent.effects[:Substitute]
      opponent.effects[:Substitute] -= damage
      opponent.damagestate.substitute = true
      if damage > 0
        @battle.scene.pbDamageAnimation(opponent, 0)
        @battle.pbDisplay(_INTL("The substitute took damage for {1}!", opponent.name))
        if opponent.effects[:Substitute] <= 0
          opponent.effects[:Substitute] = 0
          @battle.scene.pbUnSubstituteSprite(opponent, opponent.pbIsOpposing?(1))
          @battle.pbDisplay(_INTL("{1}'s substitute faded!", opponent.name))
        end
      end
    elsif opponent.effects[:Disguise] && (!attacker || attacker.index != opponent.index) &&
          opponent.effects[:Substitute] <= 0 && opponent.damagestate.typemod != 0 && !opponent.moldbroken
      opponent.pbBreakDisguise
      opponent.damagestate.disguise = true
      opponent.pbReduceHP((opponent.totalhp / 8.0).floor) if Gen > 7
      @battle.pbDisplay(_INTL("{1}'s Disguise was busted!", opponent.name))
      opponent.effects[:Disguise] = false
      damage = 0
    elsif opponent.effects[:IceFace] && (pbIsPhysical?(attacker, type) || @battle.FE == :FROZENDIMENSION) && (!attacker || attacker.index != opponent.index) &&
          opponent.effects[:Substitute] <= 0 && opponent.damagestate.typemod != 0 && !opponent.moldbroken
      opponent.pbBreakDisguise
      opponent.damagestate.disguise = true
      @battle.pbDisplay(_INTL("{1} transformed!", opponent.name))
      opponent.effects[:IceFace] = false
      damage = 0
    else
      opponent.damagestate.substitute = false
      opponent.damagestate.disguise = false
      if damage >= opponent.hp
        damage = opponent.hp
        if @function == 0xE9 # False Swipe
          damage = damage - 1
        elsif opponent.effects[:Endure]
          damage = damage - 1
          opponent.damagestate.endured = true
        elsif damage == opponent.totalhp && @battle.FE == :CHESS && opponent.pokemon.piece == :PAWN && !opponent.damagestate.pawnsturdyused
          opponent.damagestate.pawnsturdyused = true
          opponent.damagestate.pawnsturdy = true
          damage = damage - 1
        elsif damage == opponent.totalhp && opponent.ability == :STURDY && !opponent.moldbroken
          opponent.damagestate.sturdy = true
          damage = damage - 1
        elsif opponent.damagestate.focussash && damage == opponent.totalhp && opponent.item
          opponent.damagestate.focussashused = true
          damage = damage - 1
          opponent.pbDisposeItem(false, true, true, true)
        elsif opponent.damagestate.focusband
          opponent.damagestate.focusbandused = true
          damage = damage - 1
        elsif opponent.damagestate.rampcrest && opponent.pokemon.rampCrestUsed == false
          opponent.damagestate.rampcrestused = true
          opponent.pokemon.rampCrestUsed = true
          damage = damage - 1
        elsif damage == opponent.totalhp && opponent.ability == :STALWART && @battle.FE == :COLOSSEUM && !opponent.moldbroken
          opponent.damagestate.stalwart = true
          damage = damage - 1
        end
        damage = 0 if damage < 0
      end
      return @battle.pbShieldDamage(opponent, damage) if opponent.isbossmon

      oldhp = opponent.hp
      opponent.hp -= damage
      effectiveness = 0
      if opponent.damagestate.typemod < 4
        effectiveness = 1   # "Not very effective"
      elsif opponent.damagestate.typemod > 4
        effectiveness = 2   # "Super effective"
      end
      if opponent.damagestate.typemod != 0
        @battle.scene.pbDamageAnimation(opponent, effectiveness)
      end
      @battle.scene.pbHPChanged([[opponent, oldhp]])
    end
    return damage
  end

  ################################################################################
  # Effects
  ################################################################################
  def pbEffectMessages(attacker, opponent, ignoretype = false)
    if opponent.damagestate.critical
      @battle.pbDisplay(_INTL("A critical hit!"))
      attacker.pokemon.landCritical = 0 if attacker.pokemon.landCritical.nil? # PLEASE ACTUALLY BE ASSIGNED GDI
      attacker.pokemon.landCritical += 1
      if @battle.ProgressiveFieldCheck(PBFields::CONCERT)
        @battle.growField("The critical hit", attacker)
      end
    end
    if !pbIsMultiHit && !attacker.effects[:ParentalBond]
      if opponent.damagestate.typemod > 4
        @battle.pbDisplay(_INTL("It's super effective!"))
      elsif opponent.damagestate.typemod >= 1 && opponent.damagestate.typemod < 4
        @battle.pbDisplay(_INTL("It's not very effective..."))
      end
    end
    if opponent.damagestate.endured
      @battle.pbDisplay(_INTL("{1} endured the hit!", opponent.pbThis))
    elsif opponent.damagestate.pawnsturdy
      opponent.damagestate.pawnsturdy = false
      @battle.pbDisplay(_INTL("{1} hung on the edge of the board!", opponent.pbThis))
    elsif opponent.damagestate.sturdy
      @battle.pbDisplay(_INTL("{1} hung on with Sturdy!", opponent.pbThis))
      opponent.damagestate.sturdy = false
    elsif opponent.damagestate.focussashused
      @battle.pbDisplay(_INTL("{1} hung on using its Focus Sash!", opponent.pbThis))
      opponent.damagestate.focussashused = false
    elsif opponent.damagestate.focusbandused
      @battle.pbDisplay(_INTL("{1} hung on using its Focus Band!", opponent.pbThis))
    elsif opponent.damagestate.rampcrestused
      @battle.pbDisplay(_INTL("{1} hung on using its Rampardos Crest!", opponent.pbThis))
      opponent.damagestate.rampcrestused = false
    elsif opponent.damagestate.stalwart
      @battle.pbDisplay(_INTL("{1} hung on with Stalwart in the Colosseum!", opponent.pbThis))
      opponent.damagestate.stalwart = false
    end
  end

  def pbEffectFixedDamage(damage, attacker, opponent, hitnum = 0, alltargets = nil, showanimation = true)
    type = pbType(attacker)
    typemod = pbTypeModMessages(type, attacker, opponent)
    opponent.damagestate.critical = false
    opponent.damagestate.typemod = 0
    opponent.damagestate.calcdamage = 0
    if typemod != 0
      opponent.damagestate.calcdamage = damage
      opponent.damagestate.typemod = 4
      pbShowAnimation(@move, attacker, opponent, hitnum, alltargets, showanimation)
      if @zmove
        if opponent.pbOwnSide.effects[:MatBlock] || opponent.effects[:Protect] ||
           (opponent.pbOwnSide.effects[:WideGuard] && [:AllOpposing, :AllNonUsers].include?(attacker.pbTarget(self)))
          if !opponent.effects[:ProtectNegation]
            @battle.pbDisplay(_INTL("{1} couldn't fully protect itself!", opponent.pbThis))
            damage = (damage / 4.0).floor
          end
        end
      end
      damage = 1 if damage < 1 # HP reduced can't be less than 1
      damage = pbReduceHPDamage(damage, attacker, opponent)
      pbEffectMessages(attacker, opponent)
      pbOnDamageLost(damage, attacker, opponent)
      return damage
    end
    return 0
  end

  def pbEffect(attacker, opponent, hitnum = 0, alltargets = nil, showanimation = true)
    return 0 if !opponent

    damage = pbCalcDamage(attacker, opponent, hitnum: hitnum)

    damage *= 1.5 if attacker.effects[:MeFirst]
    damage /= 4 if hitnum == 1 && attacker.effects[:ParentalBond] && pbNumHits(attacker) == 1
    damage *= 0.3 if hitnum == 1 && attacker.effects[:TyphBond] && pbNumHits(attacker) == 1
    if opponent.damagestate.typemod != 0
      pbShowAnimation(@move, attacker, opponent, hitnum, alltargets, showanimation)
      if self.function == 0xC9 || self.function == 0xCA || self.function == 0xCB ||
         self.function == 0xCC || self.function == 0xCD || self.function == 0xCE # Sprites for two turn moves
        @battle.scene.pbUnVanishSprite(attacker, false)
        if self.function == 0xCE
          @battle.scene.pbUnVanishSprite(opponent, false)
        end
      end
    end
    damage = pbReduceHPDamage(damage, attacker, opponent)
    pbEffectMessages(attacker, opponent)
    pbOnDamageLost(damage, attacker, opponent)
    return damage # The HP lost by the opponent due to this attack
  end

  def priorityCheck(attacker)
    pri = self.priority

    pri = 0 if @zmove && @basedamage > 0
    pri += 1 if @move == :GRASSYGLIDE && (@battle.FE == :GRASSY || @battle.state.effects[:GRASSY] > 0)
    pri += 1 if @move == :QUASH && @battle.FE == :DIMENSIONAL
    pri += 1 if @battle.FE == :CHESS && attacker.pokemon && attacker.pokemon.piece == :KING
    pri += 1 if attacker.crested == :FERALIGATR && @basedamage != 0 && attacker.turncount == 1 # Feraligatr Crest
    pri += 1 if attacker.ability == :PRANKSTER && @basedamage == 0 && attacker.effects[:TwoTurnAttack] == 0 # Is status move
    pri += 1 if attacker.ability == :GALEWINGS && @type == :FLYING && (attacker.hp == attacker.totalhp || @battle.FE == :SKY || ([:MOUNTAIN, :SNOWYMOUNTAIN, :VOLCANICTOP].include?(@battle.FE) && @battle.pbWeather == :STRONGWINDS))
    pri += 3 if attacker.ability == :TRIAGE && PBStuff::HEALFUNCTIONS.include?(@function)
    pri -= 1 if @battle.FE == :DEEPEARTH && @move == :COREENFORCER
    return pri
  end

  def pbIsPriorityMoveAI(attacker)
    if @move == :FAKEOUT || @move == :FIRSTIMPRESSION
      return false if attacker.turncount != 0
    end
    return priorityCheck(attacker) > 0
  end

  ################################################################################
  # cass's lazy field effect thingy section (i never said i knew what i was doing)
  ################################################################################
  def ignitecheck
    # Intentionally not using pbWeather so that Cloud Nine doesn't affect field interactions.
    return @battle.state.effects[:WaterSport] <= 0 && @battle.weather != :RAINDANCE
  end

  def suncheck
    return false
  end

  # def mistExplosion
  #  return !@battle.pbCheckGlobalAbility(:DAMP)
  # end

  ################################################################################
  # Using the move
  ################################################################################
  def pbOnStartUse(attacker)
    return true
  end

  def pbAddTarget(targets, attacker)
  end

  def pbDisplayUseMessage(attacker, choice)
    # Return values:
    # -1 if the attack should exit as a failure
    # 1 if the attack should exit as a success
    # 0 if the attack should proceed its effect
    # 2 if Bide is storing energy
    if choice[2].zmove
      if choice[2].hasFlag?(:intercept)
        @battle.pbDisplayBrief(_INTL("{1} is changing the flow of Fate!", attacker.pbThis))
        @battle.pbDisplayBrief(_INTL("{1}!", @name))
      else
        @battle.pbDisplayBrief(_INTL("{1} unleashed its full force Z-Move!", attacker.pbThis))
        @battle.pbDisplayBrief(_INTL("{1}!", getMoveUseName))
      end
    else
      @battle.pbDisplayBrief(_INTL("{1} used\r\n{2}!", attacker.pbThis, getMoveUseName))
    end
    return 0
  end

  def getMoveUseName
    if @data
      return (@data.checkFlag?(:longname, nil).nil?) ? @name : @data.checkFlag?(:longname, nil)
    else
      return @name
    end
  end

  def pbShowAnimation(id, attacker, opponent, hitnum = 0, alltargets = nil, showanimation = true)
    return if !showanimation

    @battle.pbAnimation(id, attacker, opponent, hitnum)
  end

  def pbOnDamageLost(damage, attacker, opponent)
    # Used by Counter/Mirror Coat/Revenge/Focus Punch/Bide
    type = pbType(attacker)
    if opponent.effects[:Bide] > 0
      opponent.effects[:BideDamage] += damage
      opponent.effects[:BideTarget] = attacker.index
    end
    if pbIsPhysical?(attacker, type) && opponent.effects[:ShellTrap] == true && attacker.pbOwnSide != opponent.pbOwnSide && !(attacker.ability == :SHEERFORCE && self.effect > 0)
      opponent.effects[:ShellTrapTarget] = attacker.index
    end
    if @function == 0x90 # Hidden Power
      type = :NORMAL
    end
    if pbIsPhysical?(attacker, type)
      opponent.effects[:Counter] = damage
      opponent.effects[:CounterTarget] = attacker.index
    end
    if pbIsSpecial?(attacker, type)
      opponent.effects[:MirrorCoat] = damage
      opponent.effects[:MirrorCoatTarget] = attacker.index
    end
    opponent.lastHPLost = damage # for Revenge/Focus Punch/Metal Burst
    opponent.lastAttacker = attacker.index # for Revenge/Metal Burst
  end

  def pbMoveFailed(attacker, opponent)
    # Called to determine whether the move failed
    return false
  end
end
