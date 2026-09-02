/// @description Authored Stage 1 difficulty tuning and attempt-local dynamic rank.

enum BladeDifficultyRankReason {
    ActivePlay = 1,
    DefensiveRecovery = 2,
    NormalBomb = 3,
    LifeLoss = 4,
    NormalHyper = 5,
    DeathBombHyper = 6,
    EmergencyBomb = 7
}

#macro BLADE_DIFFICULTY_EASY_ID "difficulty.easy"
#macro BLADE_DIFFICULTY_NORMAL_ID "difficulty.normal"
#macro BLADE_DIFFICULTY_HARD_ID "difficulty.hard"
#macro BLADE_DIFFICULTY_RANK_MIN 0
#macro BLADE_DIFFICULTY_RANK_MAX 50
#macro BLADE_DIFFICULTY_RANK_ACTIVE_PERIOD 30

// Fixed deltas make every rank transition auditable and replayable.
#macro BLADE_DIFFICULTY_RANK_ACTIVE_DELTA 1
#macro BLADE_DIFFICULTY_RANK_DEFENSIVE_DELTA -3
#macro BLADE_DIFFICULTY_RANK_BOMB_DELTA -6
#macro BLADE_DIFFICULTY_RANK_LIFE_DELTA -10
#macro BLADE_DIFFICULTY_RANK_HYPER_DELTA 4
#macro BLADE_DIFFICULTY_RANK_DEATH_BOMB_HYPER_DELTA -4
#macro BLADE_DIFFICULTY_RANK_EMERGENCY_DELTA -8

function _BladeDifficultyRankFail(_field, _reason) {
    throw("BladeDifficultyRank: " + _field + ": " + _reason);
}

function _BladeDifficultyRankInteger(_value, _minimum, _maximum, _field) {
    return BladeCanonicalRequireInteger(_value, _minimum, _maximum, _field);
}

function _BladeDifficultyRankRequireId(_difficulty_id, _field = "difficulty_id") {
    if (_difficulty_id != BLADE_DIFFICULTY_EASY_ID
        && _difficulty_id != BLADE_DIFFICULTY_NORMAL_ID
        && _difficulty_id != BLADE_DIFFICULTY_HARD_ID) {
        _BladeDifficultyRankFail(_field, "must be one of the three playable difficulty IDs");
    }
    return _difficulty_id;
}

function _BladeDifficultyRankRequireReason(_reason, _field = "reason") {
    return _BladeDifficultyRankInteger(_reason, 1, 7, _field);
}

function _BladeDifficultyRankReasonToken(_reason) {
    switch (_reason) {
        case BladeDifficultyRankReason.ActivePlay: return "active_play";
        case BladeDifficultyRankReason.DefensiveRecovery: return "defensive_recovery";
        case BladeDifficultyRankReason.NormalBomb: return "normal_bomb";
        case BladeDifficultyRankReason.LifeLoss: return "life_loss";
        case BladeDifficultyRankReason.NormalHyper: return "normal_hyper";
        case BladeDifficultyRankReason.DeathBombHyper: return "death_bomb_hyper";
        case BladeDifficultyRankReason.EmergencyBomb: return "emergency_bomb";
    }
    _BladeDifficultyRankFail("reason", "has no canonical token");
    return "";
}

function _BladeDifficultyRankPriority(_reason) {
    switch (_reason) {
        case BladeDifficultyRankReason.ActivePlay: return 10;
        case BladeDifficultyRankReason.NormalHyper: return 20;
        case BladeDifficultyRankReason.DefensiveRecovery:
        case BladeDifficultyRankReason.NormalBomb:
        case BladeDifficultyRankReason.DeathBombHyper:
        case BladeDifficultyRankReason.EmergencyBomb: return 30;
        case BladeDifficultyRankReason.LifeLoss: return 40;
    }
    _BladeDifficultyRankFail("reason", "has no same-tick ordering priority");
    return 0;
}

/// Returns the only difficulty identities accepted by the Stage 1 selector.
function BladeDifficultyIds() {
    return [
        BLADE_DIFFICULTY_EASY_ID,
        BLADE_DIFFICULTY_NORMAL_ID,
        BLADE_DIFFICULTY_HARD_ID,
    ];
}

/// Returns the short selector label while the product contract owns its flavor name.
function BladeDifficultyPlayerName(_difficulty_id) {
    _BladeDifficultyRankRequireId(_difficulty_id);
    if (_difficulty_id == BLADE_DIFFICULTY_EASY_ID) return "Easy";
    if (_difficulty_id == BLADE_DIFFICULTY_HARD_ID) return "Hard";
    return "Normal";
}

/// Returns the contract display name for one identity-only difficulty record.
function BladeDifficultyContractName(_difficulty_id) {
    _BladeDifficultyRankRequireId(_difficulty_id);
    if (_difficulty_id == BLADE_DIFFICULTY_EASY_ID) return "Breeze";
    if (_difficulty_id == BLADE_DIFFICULTY_HARD_ID) return "Storm";
    return "Arcade";
}

/// Returns authored Stage 1 multipliers. The product contract intentionally remains identity-only.
function BladeDifficultyProfile(_difficulty_id) {
    _BladeDifficultyRankRequireId(_difficulty_id);
    if (_difficulty_id == BLADE_DIFFICULTY_EASY_ID) {
        return {
            difficulty_id: _difficulty_id,
            hostile_speed_per_mille: 850,
            hostile_fire_per_mille: 820,
            enemy_health_per_mille: 850,
            reward_per_mille: 900,
        };
    }
    if (_difficulty_id == BLADE_DIFFICULTY_HARD_ID) {
        return {
            difficulty_id: _difficulty_id,
            hostile_speed_per_mille: 1150,
            hostile_fire_per_mille: 1200,
            enemy_health_per_mille: 1150,
            reward_per_mille: 1100,
        };
    }
    return {
        difficulty_id: _difficulty_id,
        hostile_speed_per_mille: 1000,
        hostile_fire_per_mille: 1000,
        enemy_health_per_mille: 1000,
        reward_per_mille: 1000,
    };
}

/// Builds selector records from the canonical three IDs without retaining contract arrays.
function BladeDifficultySelectionEntries() {
    var _ids = BladeDifficultyIds();
    var _entries = [];
    for (var _index = 0; _index < array_length(_ids); ++_index) {
        array_push(_entries, {
            difficulty_id: _ids[_index],
            display_name: BladeDifficultyPlayerName(_ids[_index]),
            contract_display_name: BladeDifficultyContractName(_ids[_index]),
        });
    }
    return _entries;
}

function _BladeDifficultyRankValue(_rank, _field = "rank") {
    return _BladeDifficultyRankInteger(
        _rank, BLADE_DIFFICULTY_RANK_MIN, BLADE_DIFFICULTY_RANK_MAX, _field
    );
}

/// Returns the authored rank multipliers in permille, avoiding floating-point policy state.
function BladeDifficultyRankMultipliers(_rank) {
    var _value = _BladeDifficultyRankValue(_rank);
    return {
        rank: _value,
        hostile_speed_per_mille: 1000 + _value * 4,
        hostile_fire_per_mille: 1000 + _value * 6,
        reward_per_mille: 1000 + _value * 10,
    };
}

/// Composes difficulty, rank, and the existing Hyper speed multiplier exactly once.
function BladeDifficultyHostileBulletSpeed(_base_speed, _difficulty_id, _rank, _hyper_tier = 0) {
    var _profile = BladeDifficultyProfile(_difficulty_id);
    var _rank_profile = BladeDifficultyRankMultipliers(_rank);
    return max(0, _base_speed)
        * _profile.hostile_speed_per_mille
        * _rank_profile.hostile_speed_per_mille
        / 1000000
        * BladeSurvivalHyperHostileBulletSpeed(1, _hyper_tier);
}

/// Returns the composed hostile fire rate used by ordinary, midboss, and boss emitters.
function BladeDifficultyHostileFireRate(_difficulty_id, _rank, _hyper_tier = 0) {
    var _profile = BladeDifficultyProfile(_difficulty_id);
    var _rank_profile = BladeDifficultyRankMultipliers(_rank);
    return _profile.hostile_fire_per_mille
        * _rank_profile.hostile_fire_per_mille
        / 1000000
        * BladeSurvivalHyperHostileFireRate(_hyper_tier);
}

/// Converts one authored emitter interval to the composed deterministic interval.
function BladeDifficultyHostileFireInterval(_base_ticks, _difficulty_id, _rank, _hyper_tier = 0) {
    return max(
        1,
        round(max(1, _base_ticks)
            / BladeDifficultyHostileFireRate(_difficulty_id, _rank, _hyper_tier))
    );
}

/// Scales authored health without changing the baseline source value.
function BladeDifficultyEnemyHealth(_base_health, _difficulty_id, _rank) {
    var _profile = BladeDifficultyProfile(_difficulty_id);
    _BladeDifficultyRankValue(_rank);
    return max(1, round(max(1, _base_health) * _profile.enemy_health_per_mille / 1000));
}

/// Scales authored score and point rewards with a monotonic rank multiplier.
function BladeDifficultyRewardValue(_base_value, _difficulty_id, _rank) {
    var _profile = BladeDifficultyProfile(_difficulty_id);
    var _rank_profile = BladeDifficultyRankMultipliers(_rank);
    return max(
        0,
        round(max(0, _base_value)
            * _profile.reward_per_mille
            * _rank_profile.reward_per_mille
            / 1000000)
    );
}

/// Exposes deterministic permille pressure data for HUDs, tests, and replay snapshots.
function BladeDifficultyPressureSnapshot(_difficulty_id, _rank, _hyper_tier = 0) {
    var _profile = BladeDifficultyProfile(_difficulty_id);
    var _rank_profile = BladeDifficultyRankMultipliers(_rank);
    var _hyper_value = _BladeDifficultyRankInteger(_hyper_tier, 0, 3, "hyper_tier");
    var _hyper_speed_per_mille = 1000 + _hyper_value * 200;
    var _hyper_fire_per_mille = 1000 + _hyper_value * 250;
    return {
        difficulty_id: _difficulty_id,
        rank: _rank_profile.rank,
        hyper_tier: _hyper_value,
        hostile_speed_per_mille: _profile.hostile_speed_per_mille
            * _rank_profile.hostile_speed_per_mille
            * _hyper_speed_per_mille / 1000000,
        hostile_fire_per_mille: _profile.hostile_fire_per_mille
            * _rank_profile.hostile_fire_per_mille
            * _hyper_fire_per_mille / 1000000,
        reward_per_mille: _profile.reward_per_mille
            * _rank_profile.reward_per_mille / 1000,
    };
}

/// Returns one stable canonical record for composed pressure values.
function BladeDifficultyPressureCanonical(_difficulty_id, _rank, _hyper_tier = 0) {
    var _pressure = BladeDifficultyPressureSnapshot(_difficulty_id, _rank, _hyper_tier);
    return BladeCanonicalRecord("BDP1", [
        _pressure.difficulty_id,
        string(_pressure.rank),
        string(_pressure.hyper_tier),
        string(_pressure.hostile_speed_per_mille),
        string(_pressure.hostile_fire_per_mille),
        string(_pressure.reward_per_mille),
    ]);
}

function BladeDifficultyPressureHash(_difficulty_id, _rank, _hyper_tier = 0) {
    return BladeCanonicalHashUtf8(
        BladeDifficultyPressureCanonical(_difficulty_id, _rank, _hyper_tier)
    );
}

/// Creates fresh attempt-local rank state; retries recreate this state at rank zero.
function BladeDifficultyRankStateCreate() {
    return {
        __blade_difficulty_rank_state_version: 1,
        value: BLADE_DIFFICULTY_RANK_MIN,
        active_play_ticks: 0,
        event_ordinal: 0,
        last_tick: -1,
        last_reason: "attempt_start",
        last_delta: 0,
        last_priority: 0,
        events: [],
    };
}

function _BladeDifficultyRankRequireState(_state) {
    if (!is_struct(_state)
        || !variable_struct_exists(_state, "__blade_difficulty_rank_state_version")
        || _state.__blade_difficulty_rank_state_version != 1) {
        _BladeDifficultyRankFail("state", "must be a rank-state version 1 struct");
    }
    var _expected_keys = [
        "__blade_difficulty_rank_state_version", "value", "active_play_ticks",
        "event_ordinal", "last_tick", "last_reason", "last_delta",
        "last_priority", "events",
    ];
    var _actual_keys = variable_struct_get_names(_state);
    if (array_length(_actual_keys) != array_length(_expected_keys)) {
        _BladeDifficultyRankFail("state", "has unknown or missing fields");
    }
    for (var _key_index = 0; _key_index < array_length(_expected_keys); ++_key_index) {
        if (!variable_struct_exists(_state, _expected_keys[_key_index])) {
            _BladeDifficultyRankFail("state", "requires " + _expected_keys[_key_index]);
        }
    }
    _BladeDifficultyRankValue(_state.value, "state.value");
    _BladeDifficultyRankInteger(_state.active_play_ticks, 0, BLADE_DIFFICULTY_RANK_ACTIVE_PERIOD - 1, "state.active_play_ticks");
    _BladeDifficultyRankInteger(_state.event_ordinal, 0, 2147483647, "state.event_ordinal");
    _BladeDifficultyRankInteger(_state.last_tick, -1, 9007199254740991, "state.last_tick");
    _BladeDifficultyRankInteger(_state.last_delta, -50, 50, "state.last_delta");
    _BladeDifficultyRankInteger(_state.last_priority, 0, 40, "state.last_priority");
    if (!is_string(_state.last_reason) || string_length(_state.last_reason) == 0) {
        _BladeDifficultyRankFail("state.last_reason", "must be canonical text");
    }
    if (!is_array(_state.events)) _BladeDifficultyRankFail("state.events", "must be an array");
    if (array_length(_state.events) != _state.event_ordinal) {
        _BladeDifficultyRankFail("state.events", "must contain every rank event exactly once");
    }
    if (_state.event_ordinal == 0 && _state.last_reason != "attempt_start") {
        _BladeDifficultyRankFail("state.last_reason", "must be attempt_start before the first event");
    }
    var _previous_tick = -1;
    var _previous_priority = 0;
    for (var _event_index = 0; _event_index < array_length(_state.events); ++_event_index) {
        var _event = _state.events[_event_index];
        if (!is_struct(_event)
            || array_length(variable_struct_get_names(_event)) != 7
            || !variable_struct_exists(_event, "ordinal")
            || !variable_struct_exists(_event, "tick")
            || !variable_struct_exists(_event, "reason")
            || !variable_struct_exists(_event, "delta")
            || !variable_struct_exists(_event, "before")
            || !variable_struct_exists(_event, "after")
            || !variable_struct_exists(_event, "clamped")) {
            _BladeDifficultyRankFail("state.events[" + string(_event_index) + "]", "has invalid fields");
        }
        _BladeDifficultyRankInteger(
            _event.ordinal, _event_index + 1, _event_index + 1,
            "state.events[" + string(_event_index) + "].ordinal"
        );
        var _event_tick = _BladeDifficultyRankInteger(
            _event.tick, 0, 9007199254740991,
            "state.events[" + string(_event_index) + "].tick"
        );
        if (_event_tick < _previous_tick) {
            _BladeDifficultyRankFail("state.events", "ticks must be monotonic");
        }
        if (!is_string(_event.reason) || string_length(_event.reason) == 0) {
            _BladeDifficultyRankFail("state.events", "reasons must be canonical tokens");
        }
        var _event_reason_valid = false;
        for (var _reason_index = 1; _reason_index <= 7; ++_reason_index) {
            if (_event.reason == _BladeDifficultyRankReasonToken(_reason_index)) {
                _event_reason_valid = true;
                break;
            }
        }
        if (!_event_reason_valid) {
            _BladeDifficultyRankFail("state.events", "contains an unknown reason");
        }
        _BladeDifficultyRankInteger(
            _event.delta, -50, 50,
            "state.events[" + string(_event_index) + "].delta"
        );
        _BladeDifficultyRankValue(
            _event.before, "state.events[" + string(_event_index) + ".before"
        );
        _BladeDifficultyRankValue(
            _event.after, "state.events[" + string(_event_index) + ".after"
        );
        if (typeof(_event.clamped) != "bool") {
            _BladeDifficultyRankFail("state.events", "clamped must be a boolean");
        }
        var _event_priority = _BladeDifficultyRankPriority(_reason_index);
        if (_event_tick == _previous_tick && _event_priority < _previous_priority) {
            _BladeDifficultyRankFail("state.events", "same-tick priorities must be monotonic");
        }
        _previous_tick = _event_tick;
        _previous_priority = _event_priority;
    }
    return _state;
}

/// Returns the current integer rank after validating the state boundary.
function BladeDifficultyRankValue(_state) {
    _BladeDifficultyRankRequireState(_state);
    return _state.value;
}

/// Returns the documented one-shot delta for a rank reason.
function BladeDifficultyRankReasonDelta(_reason) {
    _BladeDifficultyRankRequireReason(_reason);
    switch (_reason) {
        case BladeDifficultyRankReason.ActivePlay: return BLADE_DIFFICULTY_RANK_ACTIVE_DELTA;
        case BladeDifficultyRankReason.DefensiveRecovery: return BLADE_DIFFICULTY_RANK_DEFENSIVE_DELTA;
        case BladeDifficultyRankReason.NormalBomb: return BLADE_DIFFICULTY_RANK_BOMB_DELTA;
        case BladeDifficultyRankReason.LifeLoss: return BLADE_DIFFICULTY_RANK_LIFE_DELTA;
        case BladeDifficultyRankReason.NormalHyper: return BLADE_DIFFICULTY_RANK_HYPER_DELTA;
        case BladeDifficultyRankReason.DeathBombHyper: return BLADE_DIFFICULTY_RANK_DEATH_BOMB_HYPER_DELTA;
        case BladeDifficultyRankReason.EmergencyBomb: return BLADE_DIFFICULTY_RANK_EMERGENCY_DELTA;
    }
    return 0;
}

/// Applies one ordered action exactly once and records clamping in the attempt transcript.
function BladeDifficultyRankApplyReason(_state, _reason, _tick) {
    _BladeDifficultyRankRequireState(_state);
    _BladeDifficultyRankRequireReason(_reason);
    var _ordered_tick = _BladeDifficultyRankInteger(_tick, 0, 9007199254740991, "tick");
    var _priority = _BladeDifficultyRankPriority(_reason);
    if (_ordered_tick < _state.last_tick) {
        _BladeDifficultyRankFail("tick", "must not move backwards");
    }
    if (_ordered_tick == _state.last_tick && _priority < _state.last_priority) {
        _BladeDifficultyRankFail("same-tick ordering", "received an earlier priority after a later one");
    }
    var _delta = BladeDifficultyRankReasonDelta(_reason);
    var _before = _state.value;
    var _after = clamp(_before + _delta, BLADE_DIFFICULTY_RANK_MIN, BLADE_DIFFICULTY_RANK_MAX);
    var _clamped = _after != _before + _delta;
    _state.event_ordinal += 1;
    array_push(_state.events, {
        ordinal: _state.event_ordinal,
        tick: _ordered_tick,
        reason: _BladeDifficultyRankReasonToken(_reason),
        delta: _delta,
        before: _before,
        after: _after,
        clamped: _clamped,
    });
    _state.value = _after;
    _state.last_tick = _ordered_tick;
    _state.last_reason = _BladeDifficultyRankReasonToken(_reason);
    _state.last_delta = _delta;
    _state.last_priority = _priority;
    return {
        reason: _state.last_reason,
        delta: _delta,
        before: _before,
        after: _after,
        clamped: _clamped,
        ordinal: _state.event_ordinal,
    };
}

/// Advances rank only after an active gameplay caller explicitly grants one eligible tick.
function BladeDifficultyRankAdvanceActive(_state, _tick) {
    _BladeDifficultyRankRequireState(_state);
    _state.active_play_ticks += 1;
    if (_state.active_play_ticks < BLADE_DIFFICULTY_RANK_ACTIVE_PERIOD) {
        return {
            advanced: false,
            rank: _state.value,
        };
    }
    _state.active_play_ticks = 0;
    var _event = BladeDifficultyRankApplyReason(
        _state, BladeDifficultyRankReason.ActivePlay, _tick
    );
    _event.advanced = true;
    _event.rank = _state.value;
    return _event;
}

/// Grants rank-active ticks only while a live Stage 1 target is actually playable.
function BladeDifficultyRankGameplayEligible(_controller) {
    if (!instance_exists(_controller)
        || _controller.state != BladeFirstBeatState.Playing
        || _controller.player_phase != BladeSurvivalPlayerPhase.Active
        || _controller.boss_warning_active
        || _controller.economy.bomb_ticks > 0) {
        return false;
    }
    if (instance_number(o_blade_first_beat_enemy) > 0) return true;
    if (variable_instance_exists(_controller, "midboss_state")) {
        var _members = _controller.midboss_state.members;
        for (var _index = 0; _index < array_length(_members); ++_index) {
            if (instance_exists(_members[_index]) && _members[_index].targetable) {
                return true;
            }
        }
    }
    if (variable_instance_exists(_controller, "boss_instance")
        && _controller.boss_instance != noone
        && instance_exists(_controller.boss_instance)
        && _controller.boss_instance.targetable) {
        return true;
    }
    return false;
}

/// Emits rank state and its ordered event log for deterministic route snapshots.
function BladeDifficultyRankCanonical(_state) {
    _BladeDifficultyRankRequireState(_state);
    var _events = [];
    for (var _index = 0; _index < array_length(_state.events); ++_index) {
        var _event = _state.events[_index];
        array_push(_events, BladeCanonicalRecord("BDRE1", [
            string(_event.ordinal),
            string(_event.tick),
            _event.reason,
            string(_event.delta),
            string(_event.before),
            string(_event.after),
            _event.clamped ? "1" : "0",
        ]));
    }
    return BladeCanonicalRecord("BDR1", [
        string(_state.__blade_difficulty_rank_state_version),
        string(_state.value),
        string(_state.active_play_ticks),
        string(_state.event_ordinal),
        string(_state.last_tick),
        _state.last_reason,
        string(_state.last_delta),
        string(_state.last_priority),
        BladeCanonicalRecord("BDRL1", _events),
    ]);
}

function BladeDifficultyRankHash(_state) {
    return BladeCanonicalHashUtf8(BladeDifficultyRankCanonical(_state));
}
