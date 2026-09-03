/// Concrete score, reward, bomb, Hyper, life, and respawn rules for playable Blade.

enum BladeSurvivalPlayerPhase {
    Active = 0,
    HitResponse = 1,
    Respawning = 2
}

enum BladeSurvivalEnemyExitReason {
    Defeated = 1,
    Cleanup = 2
}

enum BladeSurvivalItemKind {
    Point = 1,
    Bomb = 2
}

enum BladeSurvivalPowerAction {
    None = 0,
    Hyper = 1,
    Bomb = 2,
    EmergencyBomb = 3,
    DeathBombHyper = 4
}

#macro BLADE_SURVIVAL_STARTING_LIVES 2
#macro BLADE_SURVIVAL_STARTING_BOMBS 3
#macro BLADE_SURVIVAL_BOMB_CAP 5
#macro BLADE_SURVIVAL_STARTING_POINT_VALUE 1000
#macro BLADE_SURVIVAL_POINT_VALUE_STEP 250
#macro BLADE_SURVIVAL_POINT_VALUE_CAP 5000
#macro BLADE_SURVIVAL_ITEM_VACUUM_NORMAL_RADIUS 64
#macro BLADE_SURVIVAL_ITEM_VACUUM_FOCUS_RADIUS 128
#macro BLADE_SURVIVAL_ITEM_VACUUM_NORMAL_SPEED 3.6
#macro BLADE_SURVIVAL_ITEM_VACUUM_FOCUS_SPEED 5.2
#macro BLADE_SURVIVAL_GRAZE_RADIUS 20
#macro BLADE_SURVIVAL_LIFE_THRESHOLD_1 100000
#macro BLADE_SURVIVAL_LIFE_THRESHOLD_2 500000
#macro BLADE_SURVIVAL_LIFE_THRESHOLD_3 1500000
#macro BLADE_SURVIVAL_HYPER_TIER_1 100
#macro BLADE_SURVIVAL_HYPER_TIER_2 200
#macro BLADE_SURVIVAL_HYPER_TIER_3 300
#macro BLADE_SURVIVAL_HIT_RESPONSE_TICKS 40
#macro BLADE_SURVIVAL_RESPAWN_TICKS 60
#macro BLADE_SURVIVAL_INVULNERABLE_TICKS 180
#macro BLADE_SURVIVAL_NORMAL_BOMB_TICKS 300
#macro BLADE_SURVIVAL_EMERGENCY_BOMB_TICKS 360
#macro BLADE_SURVIVAL_PLAYER_START_X 320
#macro BLADE_SURVIVAL_PLAYER_START_Y 314
#macro BLADE_SURVIVAL_BOMB_CARRIER_ID "enemy.bomb_carrier"
#macro BLADE_SURVIVAL_CARRIER_BOMB_ITEM_COUNT 1

/// Returns the three authored one-shot extend thresholds in score order.
function BladeSurvivalLifeThresholds() {
    return [
        BLADE_SURVIVAL_LIFE_THRESHOLD_1,
        BLADE_SURVIVAL_LIFE_THRESHOLD_2,
        BLADE_SURVIVAL_LIFE_THRESHOLD_3,
    ];
}

/// Identifies the one current ordinary enemy archetype that owns bomb drops.
function BladeSurvivalEnemyIsBombCarrier(_archetype_id) {
    return _archetype_id == BLADE_SURVIVAL_BOMB_CARRIER_ID;
}

/// Creates the full attempt-local economy used by the room controller and retry.
function BladeSurvivalEconomyCreate(_difficulty_id = BLADE_DIFFICULTY_NORMAL_ID) {
    _difficulty_id = _BladeDifficultyRankRequireId(_difficulty_id, "economy.difficulty_id");
    return {
        difficulty_id: _difficulty_id,
        rank_state: BladeDifficultyRankStateCreate(),
        score: 0,
        point_value: BLADE_SURVIVAL_STARTING_POINT_VALUE,
        lives: BLADE_SURVIVAL_STARTING_LIVES,
        bombs: BLADE_SURVIVAL_STARTING_BOMBS,
        hyper_meter: 0,
        active_hyper_tier: 0,
        hyper_ticks: 0,
        bomb_ticks: 0,
        awarded_life_mask: 0,
        shot_strength: 1,
    };
}

/// Returns the selected identity carried by this attempt's economy.
function BladeSurvivalEconomyDifficulty(_economy) {
    return _BladeDifficultyRankRequireId(_economy.difficulty_id, "economy.difficulty_id");
}

/// Returns the current attempt-local rank used by authored Stage 1 consumers.
function BladeSurvivalEconomyRank(_economy) {
    return BladeDifficultyRankValue(_economy.rank_state);
}

/// Returns the next point item's actual score value without mutating the economy.
function BladeSurvivalCurrentPointValue(_economy) {
    return BladeDifficultyRewardValue(
        _economy.point_value,
        BladeSurvivalEconomyDifficulty(_economy),
        BladeSurvivalEconomyRank(_economy)
    );
}

/// Returns the authored item-attraction reach for the current player stance.
function BladeSurvivalItemVacuumRadius(_focused) {
    return _focused
        ? BLADE_SURVIVAL_ITEM_VACUUM_FOCUS_RADIUS
        : BLADE_SURVIVAL_ITEM_VACUUM_NORMAL_RADIUS;
}

/// Returns the authored item-attraction speed for the current player stance.
function BladeSurvivalItemVacuumSpeed(_focused) {
    return _focused
        ? BLADE_SURVIVAL_ITEM_VACUUM_FOCUS_SPEED
        : BLADE_SURVIVAL_ITEM_VACUUM_NORMAL_SPEED;
}

/// Emits attempt economy, effective reward value, and rank for gameplay snapshots.
function BladeSurvivalEconomyCanonical(_economy) {
    return BladeCanonicalRecord("BSE1", [
        BladeSurvivalEconomyDifficulty(_economy),
        string(_economy.score),
        string(_economy.point_value),
        string(BladeSurvivalCurrentPointValue(_economy)),
        string(_economy.lives),
        string(_economy.bombs),
        string(_economy.hyper_meter),
        string(_economy.active_hyper_tier),
        string(_economy.hyper_ticks),
        string(_economy.bomb_ticks),
        string(_economy.awarded_life_mask),
        string(_economy.shot_strength),
        BladeDifficultyRankCanonical(_economy.rank_state),
    ]);
}

function BladeSurvivalEconomyHash(_economy) {
    return BladeCanonicalHashUtf8(BladeSurvivalEconomyCanonical(_economy));
}

/// Maps stocked meter to the highest Hyper tier currently ready to activate.
function BladeSurvivalHyperTierForMeter(_meter) {
    if (_meter >= BLADE_SURVIVAL_HYPER_TIER_3) return 3;
    if (_meter >= BLADE_SURVIVAL_HYPER_TIER_2) return 2;
    if (_meter >= BLADE_SURVIVAL_HYPER_TIER_1) return 1;
    return 0;
}

/// Gives stocked Hyper first claim in normal play and as a death-bomb response.
function BladeSurvivalPowerActionForX(_economy, _during_hit_response = false) {
    if (_economy.active_hyper_tier == 0
        && BladeSurvivalHyperTierForMeter(_economy.hyper_meter) > 0) {
        return _during_hit_response
            ? BladeSurvivalPowerAction.DeathBombHyper
            : BladeSurvivalPowerAction.Hyper;
    }
    if (_economy.bombs <= 0 || _economy.bomb_ticks > 0) {
        return BladeSurvivalPowerAction.None;
    }
    return _during_hit_response
        ? BladeSurvivalPowerAction.EmergencyBomb
        : BladeSurvivalPowerAction.Bomb;
}

/// Returns the authored duration for one valid Hyper tier.
function BladeSurvivalHyperDuration(_tier) {
    switch (_tier) {
        case 1: return 300;
        case 2: return 360;
        case 3: return 420;
    }
    return 0;
}

/// Returns the direct shot-damage multiplier supplied by active Hyper.
function BladeSurvivalHyperDamageMultiplier(_tier) {
    return clamp(_tier + 1, 1, 4);
}

/// Returns the direct score multiplier supplied by active Hyper.
function BladeSurvivalHyperScoreMultiplier(_tier) {
    return clamp(_tier + 1, 1, 4);
}

/// Raises new hostile-bullet speed while Hyper is active.
function BladeSurvivalHyperHostileBulletSpeed(_base_speed, _tier) {
    var _strength = clamp(floor(_tier), 0, 3);
    return max(0, _base_speed) * (1 + _strength * 0.2);
}

/// Returns how quickly enemy fire cooldowns advance during active Hyper.
function BladeSurvivalHyperHostileFireRate(_tier) {
    return 1 + clamp(floor(_tier), 0, 3) * 0.25;
}

/// Shortens a pattern interval without allowing a zero-tick firing loop.
function BladeSurvivalHyperHostileFireInterval(_base_ticks, _tier) {
    return max(
        1,
        round(max(1, _base_ticks) / BladeSurvivalHyperHostileFireRate(_tier))
    );
}

/// Adds stocked Hyper from active play, but does not restock during an active Hyper.
function BladeSurvivalAddHyper(_economy, _amount) {
    if (_economy.active_hyper_tier > 0) return 0;
    var _before = _economy.hyper_meter;
    _economy.hyper_meter = clamp(
        _before + max(0, _amount), 0, BLADE_SURVIVAL_HYPER_TIER_3
    );
    return _economy.hyper_meter - _before;
}

/// Awards score once, applies active Hyper, and grants every newly crossed extend once.
function BladeSurvivalApplyScore(_economy, _base_score) {
    var _authored_score = max(0, round(_base_score));
    var _scaled_score = BladeDifficultyRewardValue(
        _authored_score,
        BladeSurvivalEconomyDifficulty(_economy),
        BladeSurvivalEconomyRank(_economy)
    );
    var _multiplier = BladeSurvivalHyperScoreMultiplier(
        _economy.active_hyper_tier
    );
    var _awarded = _scaled_score * _multiplier;
    _economy.score += _awarded;

    var _life_awards = 0;
    var _thresholds = BladeSurvivalLifeThresholds();
    for (var _index = 0; _index < array_length(_thresholds); ++_index) {
        var _bit = 1 << _index;
        if (_economy.score >= _thresholds[_index]
            && (_economy.awarded_life_mask & _bit) == 0) {
            _economy.awarded_life_mask |= _bit;
            _economy.lives += 1;
            _life_awards += 1;
        }
    }
    return { score: _awarded, life_awards: _life_awards };
}

/// Converts one point pickup into score, a larger next item value, and stocked Hyper.
function BladeSurvivalCollectPointItem(_economy) {
    var _authored_value = _economy.point_value;
    var _reward = BladeSurvivalApplyScore(_economy, _authored_value);
    _economy.point_value = min(
        BLADE_SURVIVAL_POINT_VALUE_CAP,
        _economy.point_value + BLADE_SURVIVAL_POINT_VALUE_STEP
    );
    BladeSurvivalAddHyper(_economy, 20);
    _reward.collected_value = _reward.score;
    return _reward;
}

/// Awards the small exactly-once graze score and meter gain for one hostile bullet.
function BladeSurvivalAwardGraze(_economy) {
    var _reward = BladeSurvivalApplyScore(_economy, 100);
    BladeSurvivalAddHyper(_economy, 25);
    return _reward;
}

/// Claims one bullet's graze flag before granting its reward.
function BladeSurvivalTryGrazeBullet(_economy, _bullet) {
    if (_bullet.grazed) return false;
    _bullet.grazed = true;
    BladeSurvivalAwardGraze(_economy);
    return true;
}

/// Converts actual enemy damage into immediate score and stocked Hyper.
function BladeSurvivalAwardEnemyHit(_economy, _applied_damage) {
    var _damage = max(0, _applied_damage);
    var _reward = BladeSurvivalApplyScore(_economy, _damage * 25);
    BladeSurvivalAddHyper(_economy, _damage * 10);
    return _reward;
}

/// Rewards only an HP defeat and declares its concrete point and carrier drops.
function BladeSurvivalResolveEnemyExit(
    _economy, _reason, _is_bomb_carrier
) {
    var _result = {
        rewarded: false,
        score: 0,
        point_item_count: 0,
        bomb_item_count: 0,
    };
    if (_reason != BladeSurvivalEnemyExitReason.Defeated) return _result;

    var _reward = BladeSurvivalApplyScore(_economy, 10000);
    BladeSurvivalAddHyper(_economy, 20);
    _result.rewarded = true;
    _result.score = _reward.score;
    _result.point_item_count = 5;
    _result.bomb_item_count = _is_bomb_carrier
        ? BLADE_SURVIVAL_CARRIER_BOMB_ITEM_COUNT
        : 0;
    return _result;
}

/// Adds one bomb up to the cap, then converts a full-stock pickup into score.
function BladeSurvivalCollectBomb(_economy) {
    if (_economy.bombs < BLADE_SURVIVAL_BOMB_CAP) {
        _economy.bombs += 1;
        return { stocked: true, overflow_score: 0 };
    }
    var _reward = BladeSurvivalApplyScore(_economy, 10000);
    return { stocked: false, overflow_score: _reward.score };
}

/// Starts the highest stocked Hyper tier and spends the stocked meter once.
function BladeSurvivalTryActivateHyper(_economy) {
    if (_economy.active_hyper_tier > 0) return { activated: false, tier: 0 };
    var _tier = BladeSurvivalHyperTierForMeter(_economy.hyper_meter);
    if (_tier == 0) return { activated: false, tier: 0 };

    _economy.hyper_meter = 0;
    _economy.active_hyper_tier = _tier;
    _economy.hyper_ticks = BladeSurvivalHyperDuration(_tier);
    _economy.bomb_ticks = 0;
    return { activated: true, tier: _tier };
}

/// Spends a normal or all-stock emergency bomb, cancels Hyper, and applies its score cost.
function BladeSurvivalUseBomb(_economy, _emergency = false) {
    if (_economy.bombs <= 0 || _economy.bomb_ticks > 0) {
        return { used: false, spent: 0 };
    }
    var _spent = _emergency ? _economy.bombs : 1;
    _economy.bombs -= _spent;
    _economy.score = floor(_economy.score * 80 / 100);
    _economy.active_hyper_tier = 0;
    _economy.hyper_ticks = 0;
    _economy.bomb_ticks = _emergency
        ? BLADE_SURVIVAL_EMERGENCY_BOMB_TICKS
        : BLADE_SURVIVAL_NORMAL_BOMB_TICKS;
    return { used: true, spent: _spent };
}

/// Advances the two visible timed power states by one presentation frame.
function BladeSurvivalAdvancePowerTimers(_economy) {
    if (_economy.bomb_ticks > 0) _economy.bomb_ticks -= 1;
    if (_economy.hyper_ticks > 0) {
        _economy.hyper_ticks -= 1;
        if (_economy.hyper_ticks == 0) {
            _economy.active_hyper_tier = 0;
        }
    }
}

/// Applies one committed death without changing Ciela's retained shot strength.
function BladeSurvivalCommitDeath(_economy) {
    var _shot_strength = _economy.shot_strength;
    _economy.lives = max(0, _economy.lives - 1);
    _economy.score = floor(_economy.score * 50 / 100);
    _economy.bombs = BLADE_SURVIVAL_STARTING_BOMBS;
    _economy.hyper_meter = 0;
    _economy.active_hyper_tier = 0;
    _economy.hyper_ticks = 0;
    _economy.bomb_ticks = 0;
    _economy.shot_strength = _shot_strength;
    return { game_over: _economy.lives == 0 };
}

/// Reports whether ordinary gameplay objects may advance this frame.
function BladeSurvivalGameplayAdvances(_controller) {
    return (_controller.state == BladeFirstBeatState.Playing
            || _controller.state == BladeFirstBeatState.Rewarding)
        && _controller.player_phase == BladeSurvivalPlayerPhase.Active;
}

/// Lets collectibles fall during response, death, and Game Over, but not after clear.
function BladeSurvivalItemMotionAdvances(_controller) {
    return _controller.state == BladeFirstBeatState.Playing
        || _controller.state == BladeFirstBeatState.Rewarding
        || _controller.state == BladeFirstBeatState.Failed;
}

/// Starts the single readable hit-response window when protection is absent.
function BladeSurvivalBeginPlayerHit(_controller) {
    if (!BladeSurvivalGameplayAdvances(_controller)
        || _controller.invulnerable_ticks > 0
        || _controller.economy.bomb_ticks > 0) {
        return false;
    }
    _controller.player_phase = BladeSurvivalPlayerPhase.HitResponse;
    _controller.hit_response_ticks = BLADE_SURVIVAL_HIT_RESPONSE_TICKS;
    _controller.feedback_text = "HIT!\nCHOOSE NOW";
    _controller.feedback_ticks = BLADE_SURVIVAL_HIT_RESPONSE_TICKS;
    BladeStage1AudioPlayForController(
        _controller, BladeStage1AudioSfx.PlayerHit, 0.82
    );
    return true;
}

/// Returns Ciela's current concrete projectile damage after shot strength and Hyper.
function BladeSurvivalPlayerShotDamage(_economy) {
    return 2 * _economy.shot_strength
        * BladeSurvivalHyperDamageMultiplier(_economy.active_hyper_tier);
}
