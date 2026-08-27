/// Direct gameplay rules shared by the first combat room and its focused tests.

enum BladeFirstBeatState {
    Playing = 0,
    Rewarding = 1,
    Won = 2,
    Failed = 3
}

enum BladeFirstBeatEvent {
    EnemyDefeated = 1,
    RewardsCollected = 2,
    PlayerOutOfLives = 3,
    Retry = 4
}

#macro BLADE_FIRST_BEAT_PRODUCT_CONTRACT_PATH "content/product_contract.json"

/// Reads one bundled text file completely and always closes its GameMaker handle.
function _BladeFirstBeatReadBundledText(_path) {
    var _resolved_path = _path;
    if (!file_exists(_resolved_path)
        && file_exists(working_directory + _resolved_path)) {
        _resolved_path = working_directory + _resolved_path;
    }
    if (!file_exists(_resolved_path)) {
        throw("BladeFirstCombatBeat: bundled file does not exist: " + _path);
    }

    var _file = -1;
    try {
        _file = file_text_open_read(_resolved_path);
        if (_file < 0) {
            throw("BladeFirstCombatBeat: bundled file could not be opened: " + _path);
        }
        var _text = "";
        var _first_line = true;
        while (!file_text_eof(_file)) {
            if (!_first_line) _text += "\n";
            _text += file_text_read_string(_file);
            file_text_readln(_file);
            _first_line = false;
        }
        return _text;
    } finally {
        if (_file >= 0) file_text_close(_file);
    }
}

/// Loads the playable room's plane from the bundled canonical product contract.
function BladeFirstBeatLoadGameplayPlane(
    _path = BLADE_FIRST_BEAT_PRODUCT_CONTRACT_PATH
) {
    var _contract;
    try {
        _contract = json_parse(
            _BladeFirstBeatReadBundledText(_path), undefined, true
        );
    } catch (_caught) {
        throw("BladeFirstCombatBeat: product contract could not be decoded");
    }
    if (!is_struct(_contract)
        || !variable_struct_exists(_contract, "runtime_geometry")
        || !is_struct(_contract.runtime_geometry)
        || !variable_struct_exists(_contract.runtime_geometry, "gameplay_plane")) {
        throw("BladeFirstCombatBeat: product contract has no gameplay plane");
    }
    return BladeCombatPlaneCreate(_contract.runtime_geometry.gameplay_plane);
}

/// Removes every attempt-local actor, projectile, and reward before retry restarts.
function BladeFirstBeatCleanupTransientInstances() {
    with (o_blade_first_beat_enemy_bullet) instance_destroy();
    with (o_ciela_first_beat_shot) instance_destroy();
    with (o_blade_reward_item) instance_destroy();
    with (o_blade_first_beat_enemy) instance_destroy();
    with (o_ciela_first_beat_player) instance_destroy();
}

/// Applies one visible room event without allowing a finished beat to change outcome.
function BladeFirstBeatTransition(_state, _event) {
    if (_event == BladeFirstBeatEvent.Retry) {
        return BladeFirstBeatState.Playing;
    }
    if (_state == BladeFirstBeatState.Playing) {
        switch (_event) {
            case BladeFirstBeatEvent.EnemyDefeated:
                return BladeFirstBeatState.Rewarding;
            case BladeFirstBeatEvent.PlayerOutOfLives:
                return BladeFirstBeatState.Failed;
        }
    } else if (_state == BladeFirstBeatState.Rewarding
        && _event == BladeFirstBeatEvent.RewardsCollected) {
        return BladeFirstBeatState.Won;
    }
    return _state;
}

/// Moves Ciela at her focused or unfocused speed and keeps her body inside the playfield.
function BladeFirstBeatMovePlayer(
    _plane, _x, _y, _move_x, _move_y, _focused, _body_radius
) {
    var _horizontal = clamp(_move_x, -1, 1);
    var _vertical = clamp(_move_y, -1, 1);
    var _length = point_distance(0, 0, _horizontal, _vertical);
    if (_length > 0) {
        _horizontal /= _length;
        _vertical /= _length;
    }

    var _speed = _focused ? 1.35 : 2.75;
    var _bounds = BladeCombatPlanePixelBounds(_plane);
    return {
        x: clamp(
            _x + _horizontal * _speed,
            _bounds.left + _body_radius,
            _bounds.right_exclusive - _body_radius
        ),
        y: clamp(
            _y + _vertical * _speed,
            _bounds.top + _body_radius,
            _bounds.bottom_exclusive - _body_radius
        ),
        speed: _speed,
    };
}

/// Returns Ciela's five-shot upward spread, tightened while she is focused.
function BladeFirstBeatCielaSpread(_focused) {
    var _offsets = _focused
        ? [-6, -3, 0, 3, 6]
        : [-18, -9, 0, 9, 18];
    var _velocities = [];
    for (var _index = 0; _index < array_length(_offsets); ++_index) {
        var _direction = 90 + _offsets[_index];
        array_push(_velocities, {
            x: lengthdir_x(7, _direction),
            y: lengthdir_y(7, _direction),
        });
    }
    return _velocities;
}

/// Advances Ciela's repeat cadence, which active Hyper tiers shorten, and reports a volley.
function BladeFirstBeatFireCadence(_cooldown, _fire_held, _hyper_tier = 0) {
    var _remaining = max(0, _cooldown - 1);
    var _fires = _fire_held && _remaining == 0;
    var _repeat_ticks = max(4, 8 - max(0, _hyper_tier));
    return {
        fires: _fires,
        cooldown: _fires ? _repeat_ticks : _remaining,
    };
}

/// Resolves positive damage once and reports whether the target was defeated.
function BladeFirstBeatDamageResult(_health, _damage) {
    var _remaining = max(0, _health - max(0, _damage));
    return {
        remaining: _remaining,
        applied: max(0, _health - _remaining),
        defeated: _health > 0 && _remaining == 0,
    };
}

/// Uses circle bounds for the simple sprite-free collision shapes in this beat.
function BladeFirstBeatCirclesOverlap(_left_x, _left_y, _left_radius,
    _right_x, _right_y, _right_radius) {
    var _distance_x = _right_x - _left_x;
    var _distance_y = _right_y - _left_y;
    var _combined_radius = _left_radius + _right_radius;
    return _distance_x * _distance_x + _distance_y * _distance_y
        <= _combined_radius * _combined_radius;
}
