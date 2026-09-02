/// @description Kolar's deterministic close-range and meaningful-ranged loadout.

#macro BLADE_KOLAR_CLOSE_SPEED 7.4
#macro BLADE_KOLAR_RANGED_SPEED 7.0
#macro BLADE_KOLAR_CLOSE_BAND 58
#macro BLADE_KOLAR_CLOSE_HIT_INTERVAL 8

/// @func BladeKolarOptionFormation(focused)
/// Returns the visible option centers shared by drawing and emission.
function BladeKolarOptionFormation(_focused) {
    if (_focused) {
        return [
            { x: -10, y: -2 },
            { x: 0, y: -7 },
            { x: 10, y: -2 },
        ];
    }
    return [
        { x: -18, y: 3 },
        { x: 0, y: 0 },
        { x: 18, y: 3 },
    ];
}
/// @func BladeKolarCloseBand()
/// Exposes the logical close band without tying it to sprite bounds or collision.
function BladeKolarCloseBand() {
    return BLADE_KOLAR_CLOSE_BAND;
}

/// @func BladeKolarVolley(focused, hyper_tier)
/// Builds an ordered volley with a strong close channel and useful fire at range.
function BladeKolarVolley(_focused, _hyper_tier = 0) {
    var _options = BladeKolarOptionFormation(_focused);
    var _damage_bonus = max(0, min(3, _hyper_tier));
    var _volley = [];
    for (var _index = 0; _index < array_length(_options); ++_index) {
        var _option = _options[_index];
        var _close = _focused
            ? (_index == 0 || _index == 2)
            : _index == 1;
        var _side = _index - 1;
        array_push(_volley, {
            order: _index,
            offset_x: _option.x,
            offset_y: _option.y - 7,
            velocity_x: _close ? _side * 0.14 : _side * 0.24,
            velocity_y: -(_close
                ? BLADE_KOLAR_CLOSE_SPEED
                : BLADE_KOLAR_RANGED_SPEED),
            speed: _close ? BLADE_KOLAR_CLOSE_SPEED : BLADE_KOLAR_RANGED_SPEED,
            channel: _close ? "close" : "ranged",
            damage: (_close
                ? (_focused ? 3.60 : 3.00)
                : (_focused ? 2.25 : 1.90)) + _damage_bonus * 0.24,
            range_limit: _close ? BLADE_KOLAR_CLOSE_BAND : -1,
            hit_interval: BLADE_KOLAR_CLOSE_HIT_INTERVAL,
        });
    }
    return _volley;
}

/// @func BladeKolarVolleyCanonical(focused, hyper_tier)
/// Encodes ordered projectile values for deterministic command and replay tests.
function BladeKolarVolleyCanonical(_focused, _hyper_tier = 0) {
    var _volley = BladeKolarVolley(_focused, _hyper_tier);
    var _text = _focused ? "BKV1|focused" : "BKV1|unfocused";
    for (var _index = 0; _index < array_length(_volley); ++_index) {
        var _shot = _volley[_index];
        _text += "|" + string(_shot.order)
            + "," + string(_shot.offset_x)
            + "," + string(_shot.offset_y)
            + "," + string(_shot.velocity_x)
            + "," + string(_shot.velocity_y)
            + "," + _shot.channel
            + "," + string(_shot.damage)
            + "," + string(_shot.range_limit)
            + "," + string(_shot.hit_interval);
    }
    return _text;
}

// Orders stable IDs bytewise, keeping target ties independent of locale rules.
function _BladeKolarStableIdCompare(_left, _right) {
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

// Compares squared distance, authored spawn order, and stable identity.
function _BladeKolarTargetComesFirst(_candidate, _current, _x, _y) {
    if (is_undefined(_current)) return true;
    var _candidate_x = _candidate.x - _x;
    var _candidate_y = _candidate.y - _y;
    var _candidate_distance = _candidate_x * _candidate_x
        + _candidate_y * _candidate_y;
    var _current_x = _current.x - _x;
    var _current_y = _current.y - _y;
    var _current_distance = _current_x * _current_x
        + _current_y * _current_y;
    if (_candidate_distance != _current_distance) {
        return _candidate_distance < _current_distance;
    }
    if (_candidate.spawn_order != _current.spawn_order) {
        return _candidate.spawn_order < _current.spawn_order;
    }
    return _BladeKolarStableIdCompare(
        _candidate.stable_id, _current.stable_id
    ) < 0;
}

/// @func BladeKolarChooseTarget(records, x, y, max_distance)
/// Returns the nearest eligible index using deterministic tie-breakers.
function BladeKolarChooseTarget(
    _records, _x, _y, _max_distance = -1
) {
    if (!is_array(_records)) {
        throw("BladeKolarLoadout: target records must be an array");
    }
    var _best = undefined;
    var _best_index = -1;
    var _max_distance_squared = _max_distance < 0
        ? -1
        : _max_distance * _max_distance;
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
            throw("BladeKolarLoadout: eligible target record is incomplete");
        }
        var _dx = _candidate.x - _x;
        var _dy = _candidate.y - _y;
        if (_max_distance_squared >= 0
            && _dx * _dx + _dy * _dy > _max_distance_squared) continue;
        if (_BladeKolarTargetComesFirst(_candidate, _best, _x, _y)) {
            _best = _candidate;
            _best_index = _index;
        }
    }
    return _best_index;
}

// Converts a live target into stable fields used by the pure ordering function.
function _BladeKolarTargetRecord(_target) {
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

/// @func BladeKolarAcquireTarget(x, y, collision_radius, max_distance)
/// Resolves one live target by the same ordering used by pure tests.
function BladeKolarAcquireTarget(
    _x, _y, _collision_radius = -1, _max_distance = -1
) {
    var _records = [];
    var _count = instance_number(o_blade_enemy_target);
    for (var _index = 0; _index < _count; ++_index) {
        var _target = instance_find(o_blade_enemy_target, _index);
        if (_target == noone) continue;
        var _record = _BladeKolarTargetRecord(_target);
        if (_record.eligible && _collision_radius >= 0
            && !BladeFirstBeatCirclesOverlap(
                _x, _y, _collision_radius,
                _target.x, _target.y, _target.hit_radius
            )) {
            _record.eligible = false;
        }
        array_push(_records, _record);
    }
    var _chosen = BladeKolarChooseTarget(
        _records, _x, _y, _max_distance
    );
    return _chosen < 0 ? noone : _records[_chosen].instance;
}

/// @func BladeKolarResolveTarget(stable_id)
/// Reacquires an eligible target without retaining a stale instance reference.
function BladeKolarResolveTarget(_stable_id) {
    if (!is_string(_stable_id) || string_length(_stable_id) == 0) return noone;
    var _count = instance_number(o_blade_enemy_target);
    for (var _index = 0; _index < _count; ++_index) {
        var _target = instance_find(o_blade_enemy_target, _index);
        if (_target == noone) continue;
        var _record = _BladeKolarTargetRecord(_target);
        if (_record.eligible && _record.stable_id == _stable_id) return _target;
    }
    return noone;
}
