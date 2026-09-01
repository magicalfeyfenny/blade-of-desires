/// @description Maynii's deterministic tracking and forward-fire loadout.

#macro BLADE_MAYNII_TRACKING_SPEED 6.4
#macro BLADE_MAYNII_TRACKING_TURN_DEGREES 8
#macro BLADE_MAYNII_FORWARD_SPEED 8

/// @func BladeMayniiOptionFormation(focused)
/// Returns the exact visual and muzzle offsets for one focus state.
function BladeMayniiOptionFormation(_focused) {
    if (_focused) {
        return [
            { x: -8, y: -2 },
            { x: 0, y: -6 },
            { x: 8, y: -2 },
        ];
    }
    return [
        { x: -15, y: 3 },
        { x: 15, y: 3 },
    ];
}

/// @func BladeMayniiVolley(focused, hyper_tier)
/// Builds one ordered volley without creating objects, so replay tests can hash it.
function BladeMayniiVolley(_focused, _hyper_tier = 0) {
    var _options = BladeMayniiOptionFormation(_focused);
    var _volley = [];
    var _damage_bonus = max(0, min(3, _hyper_tier));
    for (var _index = 0; _index < array_length(_options); ++_index) {
        var _option = _options[_index];
        if (_focused) {
            array_push(_volley, {
                order: _index,
                offset_x: _option.x,
                offset_y: _option.y - 7,
                velocity_x: (_index - 1) * 0.18,
                velocity_y: -BLADE_MAYNII_FORWARD_SPEED,
                speed: BLADE_MAYNII_FORWARD_SPEED,
                tracking: false,
                damage: 2.15 + _damage_bonus * 0.22,
            });
        } else {
            array_push(_volley, {
                order: _index,
                offset_x: _option.x,
                offset_y: _option.y - 6,
                velocity_x: (_index == 0) ? -0.42 : 0.42,
                velocity_y: -BLADE_MAYNII_TRACKING_SPEED,
                speed: BLADE_MAYNII_TRACKING_SPEED,
                tracking: true,
                damage: 2.45 + _damage_bonus * 0.25,
            });
        }
    }
    return _volley;
}

/// @func BladeMayniiVolleyCanonical(focused, hyper_tier)
/// Encodes ordered projectile values for deterministic command/event comparison.
function BladeMayniiVolleyCanonical(_focused, _hyper_tier = 0) {
    var _volley = BladeMayniiVolley(_focused, _hyper_tier);
    var _text = _focused ? "BMV1|focused" : "BMV1|tracking";
    for (var _index = 0; _index < array_length(_volley); ++_index) {
        var _shot = _volley[_index];
        _text += "|" + string(_shot.order)
            + "," + string(_shot.offset_x)
            + "," + string(_shot.offset_y)
            + "," + string(_shot.velocity_x)
            + "," + string(_shot.velocity_y)
            + "," + string(_shot.damage);
    }
    return _text;
}

// Orders ASCII stable IDs bytewise without relying on engine or locale collation.
function _BladeMayniiStableIdCompare(_left, _right) {
    var _shared = min(string_length(_left), string_length(_right));
    for (var _index = 1; _index <= _shared; ++_index) {
        var _left_byte = string_ord_at(_left, _index);
        var _right_byte = string_ord_at(_right, _index);
        if (_left_byte < _right_byte) return -1;
        if (_left_byte > _right_byte) return 1;
    }
    if (string_length(_left) < string_length(_right)) return -1;
    if (string_length(_left) > string_length(_right)) return 1;
    return 0;
}

// Compares squared distance, then spawn order, then stable identity.
function _BladeMayniiTargetComesFirst(_candidate, _current, _x, _y) {
    if (is_undefined(_current)) return true;
    var _candidate_x = _candidate.x - _x;
    var _candidate_y = _candidate.y - _y;
    var _candidate_distance = _candidate_x * _candidate_x
        + _candidate_y * _candidate_y;
    var _current_x = _current.x - _x;
    var _current_y = _current.y - _y;
    var _current_distance = _current_x * _current_x + _current_y * _current_y;
    if (_candidate_distance != _current_distance) {
        return _candidate_distance < _current_distance;
    }
    if (_candidate.spawn_order != _current.spawn_order) {
        return _candidate.spawn_order < _current.spawn_order;
    }
    return _BladeMayniiStableIdCompare(
        _candidate.stable_id, _current.stable_id
    ) < 0;
}

/// @func BladeMayniiChooseTarget(records, x, y)
/// Returns the deterministic index of the nearest eligible stable record.
function BladeMayniiChooseTarget(_records, _x, _y) {
    if (!is_array(_records)) {
        throw("BladeMayniiLoadout: target records must be an array");
    }
    var _best = undefined;
    var _best_index = -1;
    for (var _index = 0; _index < array_length(_records); ++_index) {
        var _candidate = _records[_index];
        if (!is_struct(_candidate)
            || !variable_struct_exists(_candidate, "eligible")
            || !_candidate.eligible) continue;
        if (!variable_struct_exists(_candidate, "stable_id")
            || !is_string(_candidate.stable_id)
            || string_length(_candidate.stable_id) == 0
            || !variable_struct_exists(_candidate, "spawn_order")
            || !variable_struct_exists(_candidate, "x")
            || !variable_struct_exists(_candidate, "y")) {
            throw("BladeMayniiLoadout: eligible target record is incomplete");
        }
        if (_BladeMayniiTargetComesFirst(_candidate, _best, _x, _y)) {
            _best = _candidate;
            _best_index = _index;
        }
    }
    return _best_index;
}

// Converts one real target into the stable fields used by deterministic ordering.
function _BladeMayniiTargetRecord(_target) {
    var _stable_id = "";
    if (variable_instance_exists(_target, "stage_instance_id")) {
        _stable_id = _target.stage_instance_id;
    }
    var _eligible = variable_instance_exists(_target, "targetable")
        && _target.targetable
        && variable_instance_exists(_target, "hit_radius")
        && _target.hit_radius > 0
        && is_string(_stable_id)
        && string_length(_stable_id) > 0;
    return {
        eligible: _eligible,
        stable_id: _stable_id,
        spawn_order: variable_instance_exists(_target, "spawn_order")
            ? _target.spawn_order
            : 0,
        x: _target.x,
        y: _target.y,
        instance: _target,
    };
}

/// @func BladeMayniiAcquireTarget(x, y, collision_radius)
/// Resolves a live target by the same stable order used by pure target tests.
function BladeMayniiAcquireTarget(_x, _y, _collision_radius = -1) {
    var _records = [];
    var _count = instance_number(o_blade_enemy_target);
    for (var _index = 0; _index < _count; ++_index) {
        var _target = instance_find(o_blade_enemy_target, _index);
        if (_target == noone) continue;
        var _record = _BladeMayniiTargetRecord(_target);
        if (_record.eligible && _collision_radius >= 0
            && !BladeFirstBeatCirclesOverlap(
                _x, _y, _collision_radius,
                _target.x, _target.y, _target.hit_radius
            )) {
            _record.eligible = false;
        }
        array_push(_records, _record);
    }
    var _chosen = BladeMayniiChooseTarget(_records, _x, _y);
    return _chosen < 0 ? noone : _records[_chosen].instance;
}

/// @func BladeMayniiResolveTarget(stable_id)
/// Reacquires one exact live target and rejects defeated or cleaned-up instances.
function BladeMayniiResolveTarget(_stable_id) {
    if (!is_string(_stable_id) || string_length(_stable_id) == 0) return noone;
    var _count = instance_number(o_blade_enemy_target);
    for (var _index = 0; _index < _count; ++_index) {
        var _target = instance_find(o_blade_enemy_target, _index);
        if (_target == noone) continue;
        var _record = _BladeMayniiTargetRecord(_target);
        if (_record.eligible && _record.stable_id == _stable_id) return _target;
    }
    return noone;
}

/// @func BladeMayniiForwardFallback(speed)
/// Returns useful straight fire whenever no eligible tracking target exists.
function BladeMayniiForwardFallback(_speed) {
    return { x: 0, y: -abs(_speed) };
}

/// @func BladeMayniiSteerVelocity(vx, vy, x, y, target_x, target_y, speed, turn)
/// Turns by a bounded angle, producing repeatable first-N-tick trajectories.
function BladeMayniiSteerVelocity(
    _velocity_x, _velocity_y, _x, _y, _target_x, _target_y, _speed, _turn
) {
    var _current = point_direction(0, 0, _velocity_x, _velocity_y);
    var _desired = point_direction(_x, _y, _target_x, _target_y);
    var _delta = clamp(angle_difference(_desired, _current), -_turn, _turn);
    var _direction = _current + _delta;
    return {
        x: lengthdir_x(_speed, _direction),
        y: lengthdir_y(_speed, _direction),
        direction: _direction,
    };
}
