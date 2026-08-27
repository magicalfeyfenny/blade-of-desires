/// Direct gameplay rules shared by the first combat room and its focused tests.

enum BladeFirstBeatState {
    Playing = 0,
    Won = 1,
    Failed = 2
}

enum BladeFirstBeatEvent {
    EnemyDefeated = 1,
    PlayerHit = 2,
    Retry = 3
}

/// Applies one visible room event without allowing a finished beat to change outcome.
function BladeFirstBeatTransition(_state, _event) {
    if (_event == BladeFirstBeatEvent.Retry) {
        return BladeFirstBeatState.Playing;
    }
    if (_state != BladeFirstBeatState.Playing) {
        return _state;
    }
    switch (_event) {
        case BladeFirstBeatEvent.EnemyDefeated:
            return BladeFirstBeatState.Won;
        case BladeFirstBeatEvent.PlayerHit:
            return BladeFirstBeatState.Failed;
    }
    return _state;
}

/// Moves Ciela at her focused or unfocused speed and keeps her body inside the playfield.
function BladeFirstBeatMovePlayer(_x, _y, _move_x, _move_y, _focused) {
    var _horizontal = clamp(_move_x, -1, 1);
    var _vertical = clamp(_move_y, -1, 1);
    var _length = point_distance(0, 0, _horizontal, _vertical);
    if (_length > 0) {
        _horizontal /= _length;
        _vertical /= _length;
    }

    var _speed = _focused ? 1.35 : 2.75;
    return {
        x: clamp(_x + _horizontal * _speed, 191, 449),
        y: clamp(_y + _vertical * _speed, 6, 354),
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

/// Advances Ciela's eight-frame repeat cadence and reports this frame's volley.
function BladeFirstBeatFireCadence(_cooldown, _fire_held) {
    var _remaining = max(0, _cooldown - 1);
    var _fires = _fire_held && _remaining == 0;
    return {
        fires: _fires,
        cooldown: _fires ? 8 : _remaining,
    };
}

/// Checks a projectile anchor against the authoritative half-open gameplay plane.
function BladeFirstBeatPointInsidePlane(_x, _y) {
    return _x >= 185 && _x < 455 && _y >= 0 && _y < 360;
}

/// Checks the current enemy hurtbox against the authoritative half-open gameplay plane.
function BladeFirstBeatHurtboxCanFire(_x, _y, _radius) {
    return _radius > 0
        && _x - _radius >= 185
        && _x + _radius <= 455
        && _y - _radius >= 0
        && _y + _radius <= 360;
}

/// Resolves positive damage once and reports whether the target was defeated.
function BladeFirstBeatDamageResult(_health, _damage) {
    var _remaining = max(0, _health - max(0, _damage));
    return {
        remaining: _remaining,
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
