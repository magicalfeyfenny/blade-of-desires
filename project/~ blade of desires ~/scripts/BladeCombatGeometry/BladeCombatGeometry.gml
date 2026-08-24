/// @description Pure combat geometry, gameplay-plane gating, and projectile pair rules.

enum BladeCombatFaction {
    Player = 1,
    Enemy = 2
}

enum BladeCombatCancellationPolicy {
    Ignore = 0,
    Symmetric = 1
}

enum BladeCombatGateKind {
    Point = 1,
    Hurtbox = 2
}

/// Throws one field-specific combat-geometry diagnostic.
function _BladeCombatGeometryFail(_field, _reason) {
    throw("BladeCombatGeometry: " + _field + ": " + _reason);
}

/// Converts one exact numeric value to int64 inside inclusive bounds.
function _BladeCombatGeometryInteger(_value, _minimum, _maximum, _field) {
    var _type = typeof(_value);
    var _integer;
    if (_type == "int32" || _type == "int64") {
        _integer = int64(_value);
    } else if (_type == "number"
        && !is_nan(_value)
        && !is_infinity(_value)
        && floor(_value) == _value
        && abs(_value) <= 9007199254740991) {
        _integer = int64(_value);
    } else {
        _BladeCombatGeometryFail(_field, "must be an exact integer");
    }
    if (_integer < _minimum || _integer > _maximum) {
        _BladeCombatGeometryFail(_field, "is outside its supported range");
    }
    return _integer;
}

/// Reads one required struct field without treating absence as zero.
function _BladeCombatGeometryField(_source, _field) {
    if (!is_struct(_source) || !variable_struct_exists(_source, _field)) {
        _BladeCombatGeometryFail(_field, "is required");
    }
    return variable_struct_get(_source, _field);
}

/// Validates one nonempty contract policy token.
function _BladeCombatGeometryPolicy(_source, _field) {
    var _value = _BladeCombatGeometryField(_source, _field);
    if (!is_string(_value) || string_length(_value) == 0) {
        _BladeCombatGeometryFail(_field, "must be a nonempty string");
    }
    return _value;
}

/// Validates and copies one compiled q10 gameplay plane.
function _BladeCombatGeometryPlaneCopy(_plane) {
    if (!is_struct(_plane)
        || !variable_struct_exists(_plane, "__blade_combat_plane_version")
        || _plane.__blade_combat_plane_version != 1) {
        _BladeCombatGeometryFail("plane", "expected a version 1 plane");
    }
    var _minimum = int64("-536870911");
    var _maximum = int64("536870911");
    var _left = _BladeCombatGeometryInteger(
        _plane.left_q10, _minimum, _maximum, "plane left"
    );
    var _top = _BladeCombatGeometryInteger(
        _plane.top_q10, _minimum, _maximum, "plane top"
    );
    var _right = _BladeCombatGeometryInteger(
        _plane.right_q10_exclusive, _minimum, _maximum, "plane right"
    );
    var _bottom = _BladeCombatGeometryInteger(
        _plane.bottom_q10_exclusive, _minimum, _maximum, "plane bottom"
    );
    if (_right <= _left || _bottom <= _top) {
        _BladeCombatGeometryFail("plane", "must have positive half-open extent");
    }
    return {
        __blade_combat_plane_version: 1,
        left_q10: _left,
        top_q10: _top,
        right_q10_exclusive: _right,
        bottom_q10_exclusive: _bottom,
    };
}

/// @func BladeCombatPlaneCreate(decoded_gameplay_plane)
/// Derives immutable q10 bounds from the decoded authoritative product-contract plane.
function BladeCombatPlaneCreate(_decoded_gameplay_plane) {
    var _limit = int64(524287);
    var _x_min = _BladeCombatGeometryInteger(
        _BladeCombatGeometryField(_decoded_gameplay_plane, "x_min"),
        -_limit, _limit, "x_min"
    );
    var _x_max = _BladeCombatGeometryInteger(
        _BladeCombatGeometryField(_decoded_gameplay_plane, "x_max_exclusive"),
        -_limit, _limit, "x_max_exclusive"
    );
    var _y_min = _BladeCombatGeometryInteger(
        _BladeCombatGeometryField(_decoded_gameplay_plane, "y_min"),
        -_limit, _limit, "y_min"
    );
    var _y_max = _BladeCombatGeometryInteger(
        _BladeCombatGeometryField(_decoded_gameplay_plane, "y_max_exclusive"),
        -_limit, _limit, "y_max_exclusive"
    );
    var _width = _BladeCombatGeometryInteger(
        _BladeCombatGeometryField(_decoded_gameplay_plane, "width"),
        1, _limit, "width"
    );
    var _height = _BladeCombatGeometryInteger(
        _BladeCombatGeometryField(_decoded_gameplay_plane, "height"),
        1, _limit, "height"
    );
    if (_x_max - _x_min != _width || _y_max - _y_min != _height) {
        _BladeCombatGeometryFail("plane", "width and height must match its bounds");
    }
    if (_BladeCombatGeometryPolicy(_decoded_gameplay_plane, "anchor_containment")
            != "point_inside_half_open_plane"
        || _BladeCombatGeometryPolicy(_decoded_gameplay_plane, "hurtbox_containment")
            != "fully_contained_in_half_open_plane"
        || _BladeCombatGeometryPolicy(_decoded_gameplay_plane, "coordinate_grid")
            != "binary_fixed_1_1024_logical_pixel"
        || _BladeCombatGeometryPolicy(_decoded_gameplay_plane, "right_bottom_clamp")
            != "exclusive_max_minus_one_grid_step") {
        _BladeCombatGeometryFail("plane", "contains unsupported policy tokens");
    }
    _BladeCombatGeometryPolicy(_decoded_gameplay_plane, "containment");
    return _BladeCombatGeometryPlaneCopy({
        __blade_combat_plane_version: 1,
        left_q10: _x_min * int64(1024),
        top_q10: _y_min * int64(1024),
        right_q10_exclusive: _x_max * int64(1024),
        bottom_q10_exclusive: _y_max * int64(1024),
    });
}

/// @func BladeCombatPlaneCopy(plane)
/// Returns a detached compiled plane suitable for a fresh run attempt.
function BladeCombatPlaneCopy(_plane) {
    return _BladeCombatGeometryPlaneCopy(_plane);
}

/// @func BladeCombatAabbCreate(left, top, right_exclusive, bottom_exclusive)
/// Creates one bounded positive half-open q10 box.
function BladeCombatAabbCreate(
    _left_q10, _top_q10, _right_q10_exclusive, _bottom_q10_exclusive
) {
    var _minimum = int64("-536870911");
    var _maximum = int64("536870911");
    var _left = _BladeCombatGeometryInteger(_left_q10, _minimum, _maximum, "AABB left");
    var _top = _BladeCombatGeometryInteger(_top_q10, _minimum, _maximum, "AABB top");
    var _right = _BladeCombatGeometryInteger(
        _right_q10_exclusive, _minimum, _maximum, "AABB right"
    );
    var _bottom = _BladeCombatGeometryInteger(
        _bottom_q10_exclusive, _minimum, _maximum, "AABB bottom"
    );
    if (_right <= _left || _bottom <= _top) {
        _BladeCombatGeometryFail("AABB", "must have positive half-open extent");
    }
    return {
        left_q10: _left,
        top_q10: _top,
        right_q10_exclusive: _right,
        bottom_q10_exclusive: _bottom,
    };
}

/// Copies and validates one q10 AABB.
function _BladeCombatGeometryAabbCopy(_box) {
    return BladeCombatAabbCreate(
        _BladeCombatGeometryField(_box, "left_q10"),
        _BladeCombatGeometryField(_box, "top_q10"),
        _BladeCombatGeometryField(_box, "right_q10_exclusive"),
        _BladeCombatGeometryField(_box, "bottom_q10_exclusive")
    );
}

/// @func BladeCombatPlaneContainsPoint(plane, x_q10, y_q10)
/// Applies the product contract's exact half-open point rule.
function BladeCombatPlaneContainsPoint(_plane, _x_q10, _y_q10) {
    var _copy = _BladeCombatGeometryPlaneCopy(_plane);
    var _minimum = int64("-536870911");
    var _maximum = int64("536870911");
    var _x = _BladeCombatGeometryInteger(_x_q10, _minimum, _maximum, "point x");
    var _y = _BladeCombatGeometryInteger(_y_q10, _minimum, _maximum, "point y");
    return _x >= _copy.left_q10 && _x < _copy.right_q10_exclusive
        && _y >= _copy.top_q10 && _y < _copy.bottom_q10_exclusive;
}

/// @func BladeCombatPlaneContainsHurtbox(plane, hurtbox)
/// Requires a positive hurtbox fully contained by the half-open product plane.
function BladeCombatPlaneContainsHurtbox(_plane, _hurtbox) {
    var _copy = _BladeCombatGeometryPlaneCopy(_plane);
    var _box = _BladeCombatGeometryAabbCopy(_hurtbox);
    return _box.left_q10 >= _copy.left_q10
        && _box.right_q10_exclusive <= _copy.right_q10_exclusive
        && _box.top_q10 >= _copy.top_q10
        && _box.bottom_q10_exclusive <= _copy.bottom_q10_exclusive;
}

/// @func BladeCombatEmissionGateAllows(plane, gate_kind, geometry)
/// Routes every enemy emission attempt through its declared point or hurtbox gate.
function BladeCombatEmissionGateAllows(_plane, _gate_kind, _geometry) {
    var _kind = _BladeCombatGeometryInteger(
        _gate_kind, BladeCombatGateKind.Point, BladeCombatGateKind.Hurtbox, "gate kind"
    );
    if (_kind == BladeCombatGateKind.Point) {
        return BladeCombatPlaneContainsPoint(
            _plane,
            _BladeCombatGeometryField(_geometry, "x_q10"),
            _BladeCombatGeometryField(_geometry, "y_q10")
        );
    }
    return BladeCombatPlaneContainsHurtbox(_plane, _geometry);
}

/// @func BladeCombatAabbIntersectsPlane(plane, box)
/// Reports any positive overlap, allowing runtime offscreen cleanup without another rectangle.
function BladeCombatAabbIntersectsPlane(_plane, _box) {
    var _compiled = _BladeCombatGeometryPlaneCopy(_plane);
    var _aabb = _BladeCombatGeometryAabbCopy(_box);
    return _aabb.left_q10 < _compiled.right_q10_exclusive
        && _aabb.right_q10_exclusive > _compiled.left_q10
        && _aabb.top_q10 < _compiled.bottom_q10_exclusive
        && _aabb.bottom_q10_exclusive > _compiled.top_q10;
}

/// @func BladeCombatAabbOverlaps(left, right)
/// Applies positive half-open overlap to two current q10 boxes.
function BladeCombatAabbOverlaps(_left, _right) {
    var _a = _BladeCombatGeometryAabbCopy(_left);
    var _b = _BladeCombatGeometryAabbCopy(_right);
    return _a.left_q10 < _b.right_q10_exclusive
        && _a.right_q10_exclusive > _b.left_q10
        && _a.top_q10 < _b.bottom_q10_exclusive
        && _a.bottom_q10_exclusive > _b.top_q10;
}

/// Extracts a canonical positive numeric ordinal from one typed run-local ID.
function _BladeCombatGeometryIdOrdinal(_id, _prefix, _field) {
    if (!is_string(_id)) {
        _BladeCombatGeometryFail(_field, "must be a string");
    }
    var _parts = string_split(_id, ":");
    if (array_length(_parts) != 2 || _parts[0] != _prefix
        || string_length(_parts[1]) == 0 || string_char_at(_parts[1], 1) == "0") {
        _BladeCombatGeometryFail(_field, "must be a canonical " + _prefix + " ID");
    }
    for (var _index = 1; _index <= string_length(_parts[1]); ++_index) {
        var _byte = string_ord_at(_parts[1], _index);
        if (_byte < 48 || _byte > 57) {
            _BladeCombatGeometryFail(_field, "must be a canonical " + _prefix + " ID");
        }
    }
    var _ordinal = int64(_parts[1]);
    if (_ordinal <= 0 || string(_ordinal) != _parts[1]) {
        _BladeCombatGeometryFail(_field, "must be a canonical " + _prefix + " ID");
    }
    return _ordinal;
}

/// Computes a positive greatest common divisor for fraction normalization.
function _BladeCombatGeometryGcd(_left, _right) {
    var _a = abs(_left);
    var _b = abs(_right);
    while (_b != 0) {
        var _remainder = _a mod _b;
        _a = _b;
        _b = _remainder;
    }
    return max(int64(1), _a);
}

/// Normalizes one exact rational value to a positive denominator.
function _BladeCombatGeometryFraction(_numerator, _denominator) {
    if (_denominator == 0) {
        _BladeCombatGeometryFail("fraction", "denominator cannot be zero");
    }
    var _n = _numerator;
    var _d = _denominator;
    if (_d < 0) {
        _n = -_n;
        _d = -_d;
    }
    var _divisor = _BladeCombatGeometryGcd(_n, _d);
    return { numerator: _n div _divisor, denominator: _d div _divisor };
}

/// Compares two bounded exact fractions without converting to Real.
function _BladeCombatGeometryCompareFraction(_left, _right) {
    var _left_product = _left.numerator * _right.denominator;
    var _right_product = _right.numerator * _left.denominator;
    if (_left_product < _right_product) return -1;
    if (_left_product > _right_product) return 1;
    return 0;
}

/// Returns the exact entry and exit window for one relative-motion axis.
function _BladeCombatGeometryAxisWindow(_relative, _delta, _minimum, _maximum) {
    if (_delta == 0) {
        if (_relative < _minimum || _relative > _maximum) {
            return { hit: false };
        }
        return {
            hit: true,
            enter: _BladeCombatGeometryFraction(0, 1),
            exit: _BladeCombatGeometryFraction(1, 1),
        };
    }
    var _first = _BladeCombatGeometryFraction(_minimum - _relative, _delta);
    var _second = _BladeCombatGeometryFraction(_maximum - _relative, _delta);
    if (_BladeCombatGeometryCompareFraction(_first, _second) <= 0) {
        return { hit: true, enter: _first, exit: _second };
    }
    return { hit: true, enter: _second, exit: _first };
}

/// @func BladeCombatGeometrySweep(projectile_id, target_id, previous_projectile, current_projectile, previous_target, current_target)
/// Discovers one exact swept hit candidate without applying damage.
function BladeCombatGeometrySweep(
    _projectile_id, _target_id,
    _previous_projectile, _current_projectile,
    _previous_target, _current_target
) {
    var _projectile_ordinal = _BladeCombatGeometryIdOrdinal(
        _projectile_id, "blt", "projectile ID"
    );
    var _target_ordinal = _BladeCombatGeometryIdOrdinal(
        _target_id, "ins", "target ID"
    );
    var _source_before = _BladeCombatGeometryAabbCopy(_previous_projectile);
    var _source_after = _BladeCombatGeometryAabbCopy(_current_projectile);
    var _target_before = _BladeCombatGeometryAabbCopy(_previous_target);
    var _target_after = _BladeCombatGeometryAabbCopy(_current_target);
    var _source_width = _source_before.right_q10_exclusive - _source_before.left_q10;
    var _source_height = _source_before.bottom_q10_exclusive - _source_before.top_q10;
    var _target_width = _target_before.right_q10_exclusive - _target_before.left_q10;
    var _target_height = _target_before.bottom_q10_exclusive - _target_before.top_q10;
    if (_source_width != _source_after.right_q10_exclusive - _source_after.left_q10
        || _source_height != _source_after.bottom_q10_exclusive - _source_after.top_q10
        || _target_width != _target_after.right_q10_exclusive - _target_after.left_q10
        || _target_height != _target_after.bottom_q10_exclusive - _target_after.top_q10) {
        _BladeCombatGeometryFail("sweep", "boxes may translate but cannot resize within a tick");
    }
    var _relative_x = _source_before.left_q10 - _target_before.left_q10;
    var _relative_y = _source_before.top_q10 - _target_before.top_q10;
    var _delta_x = (_source_after.left_q10 - _source_before.left_q10)
        - (_target_after.left_q10 - _target_before.left_q10);
    var _delta_y = (_source_after.top_q10 - _source_before.top_q10)
        - (_target_after.top_q10 - _target_before.top_q10);
    var _x = _BladeCombatGeometryAxisWindow(
        _relative_x, _delta_x, -(_source_width - 1), _target_width - 1
    );
    var _y = _BladeCombatGeometryAxisWindow(
        _relative_y, _delta_y, -(_source_height - 1), _target_height - 1
    );
    if (!_x.hit || !_y.hit) return undefined;

    var _enter = _BladeCombatGeometryFraction(0, 1);
    if (_BladeCombatGeometryCompareFraction(_x.enter, _enter) > 0) _enter = _x.enter;
    if (_BladeCombatGeometryCompareFraction(_y.enter, _enter) > 0) _enter = _y.enter;
    var _exit = _BladeCombatGeometryFraction(1, 1);
    if (_BladeCombatGeometryCompareFraction(_x.exit, _exit) < 0) _exit = _x.exit;
    if (_BladeCombatGeometryCompareFraction(_y.exit, _exit) < 0) _exit = _y.exit;
    if (_BladeCombatGeometryCompareFraction(_enter, _exit) > 0) return undefined;
    return {
        projectile_id: _projectile_id,
        target_id: _target_id,
        projectile_ordinal: _projectile_ordinal,
        target_ordinal: _target_ordinal,
        impact_numerator: _enter.numerator,
        impact_denominator: _enter.denominator,
    };
}

/// Validates and detaches one swept candidate before ordering.
function _BladeCombatGeometryCandidateCopy(_candidate) {
    var _projectile_id = _BladeCombatGeometryField(_candidate, "projectile_id");
    var _target_id = _BladeCombatGeometryField(_candidate, "target_id");
    var _projectile_ordinal = _BladeCombatGeometryIdOrdinal(
        _projectile_id, "blt", "candidate projectile ID"
    );
    var _target_ordinal = _BladeCombatGeometryIdOrdinal(
        _target_id, "ins", "candidate target ID"
    );
    var _fraction = _BladeCombatGeometryFraction(
        _BladeCombatGeometryField(_candidate, "impact_numerator"),
        _BladeCombatGeometryField(_candidate, "impact_denominator")
    );
    if (_BladeCombatGeometryCompareFraction(_fraction, _BladeCombatGeometryFraction(0, 1)) < 0
        || _BladeCombatGeometryCompareFraction(_fraction, _BladeCombatGeometryFraction(1, 1)) > 0) {
        _BladeCombatGeometryFail("candidate impact", "must lie between zero and one");
    }
    return {
        projectile_id: _projectile_id,
        target_id: _target_id,
        projectile_ordinal: _projectile_ordinal,
        target_ordinal: _target_ordinal,
        impact_numerator: _fraction.numerator,
        impact_denominator: _fraction.denominator,
    };
}

/// Compares candidates by exact impact time, projectile ID, then target ID.
function _BladeCombatGeometryCompareCandidates(_left, _right) {
    var _time = _BladeCombatGeometryCompareFraction(
        _BladeCombatGeometryFraction(_left.impact_numerator, _left.impact_denominator),
        _BladeCombatGeometryFraction(_right.impact_numerator, _right.impact_denominator)
    );
    if (_time != 0) return _time;
    if (_left.projectile_ordinal < _right.projectile_ordinal) return -1;
    if (_left.projectile_ordinal > _right.projectile_ordinal) return 1;
    if (_left.target_ordinal < _right.target_ordinal) return -1;
    if (_left.target_ordinal > _right.target_ordinal) return 1;
    return 0;
}

/// @func BladeCombatGeometrySortCandidates(candidates)
/// Returns detached candidates in deterministic exact-impact and numeric-ID order.
function BladeCombatGeometrySortCandidates(_candidates) {
    if (!is_array(_candidates) || array_length(_candidates) > 4096) {
        _BladeCombatGeometryFail("candidates", "must be an array of at most 4096 entries");
    }
    var _sorted = [];
    for (var _index = 0; _index < array_length(_candidates); ++_index) {
        var _candidate = _BladeCombatGeometryCandidateCopy(_candidates[_index]);
        var _insert = array_length(_sorted);
        for (var _scan = 0; _scan < array_length(_sorted); ++_scan) {
            if (_BladeCombatGeometryCompareCandidates(_candidate, _sorted[_scan]) < 0) {
                _insert = _scan;
                break;
            }
        }
        array_insert(_sorted, _insert, _candidate);
    }
    return _sorted;
}

/// Validates the cancellation-facing subset of one active projectile record.
function _BladeCombatCancellationParticipant(_projectile) {
    var _id = _BladeCombatGeometryField(_projectile, "projectile_id");
    var _ordinal = _BladeCombatGeometryIdOrdinal(_id, "blt", "projectile ID");
    var _faction = _BladeCombatGeometryInteger(
        _BladeCombatGeometryField(_projectile, "faction"),
        BladeCombatFaction.Player, BladeCombatFaction.Enemy, "faction"
    );
    var _policy = _BladeCombatGeometryInteger(
        _BladeCombatGeometryField(_projectile, "cancellation_policy"),
        BladeCombatCancellationPolicy.Ignore,
        BladeCombatCancellationPolicy.Symmetric,
        "cancellation policy"
    );
    return {
        projectile_id: _id,
        ordinal: _ordinal,
        faction: _faction,
        policy: _policy,
        power: _BladeCombatGeometryInteger(
            _BladeCombatGeometryField(_projectile, "cancellation_power"),
            0, int64("2147483647"), "cancellation power"
        ),
        penetration: _BladeCombatGeometryInteger(
            _BladeCombatGeometryField(_projectile, "penetration_remaining"),
            0, int64("2147483647"), "penetration remaining"
        ),
    };
}

/// Builds one detached cancellation outcome without mutating a projectile.
function _BladeCombatCancellationOutcome(_participant, _cancelled, _after, _consumed) {
    return {
        projectile_id: _participant.projectile_id,
        cancelled: _cancelled,
        penetration_before: _participant.penetration,
        penetration_after: _after,
        penetration_consumed: _consumed,
    };
}

/// @func BladeCombatCancellationResolve(left, right)
/// Applies one symmetric pair rule and normalizes output by numeric projectile ID.
function BladeCombatCancellationResolve(_left_projectile, _right_projectile) {
    var _left = _BladeCombatCancellationParticipant(_left_projectile);
    var _right = _BladeCombatCancellationParticipant(_right_projectile);
    if (_left.ordinal == _right.ordinal) {
        _BladeCombatGeometryFail("cancellation", "a projectile cannot cancel itself");
    }
    var _first = _left;
    var _second = _right;
    if (_second.ordinal < _first.ordinal) {
        _first = _right;
        _second = _left;
    }
    if (_first.faction == _second.faction
        || _first.policy == BladeCombatCancellationPolicy.Ignore
        || _second.policy == BladeCombatCancellationPolicy.Ignore) {
        return {
            interacted: false,
            equal_power: false,
            reason: "",
            first: _BladeCombatCancellationOutcome(_first, false, _first.penetration, 0),
            second: _BladeCombatCancellationOutcome(_second, false, _second.penetration, 0),
        };
    }
    if (_first.power == _second.power) {
        return {
            interacted: true,
            equal_power: true,
            reason: "cancel.projectile_collision",
            first: _BladeCombatCancellationOutcome(_first, true, _first.penetration, 0),
            second: _BladeCombatCancellationOutcome(_second, true, _second.penetration, 0),
        };
    }
    var _stronger = _first.power > _second.power ? _first : _second;
    var _weaker = _first.power > _second.power ? _second : _first;
    var _stronger_cancelled = _stronger.penetration == 0;
    var _stronger_after = _stronger.penetration;
    var _consumed = int64(0);
    if (!_stronger_cancelled) {
        _stronger_after -= int64(1);
        _consumed = int64(1);
    }
    var _stronger_result = _BladeCombatCancellationOutcome(
        _stronger, _stronger_cancelled, _stronger_after, _consumed
    );
    var _weaker_result = _BladeCombatCancellationOutcome(
        _weaker, true, _weaker.penetration, 0
    );
    return {
        interacted: true,
        equal_power: false,
        reason: "cancel.projectile_collision",
        first: _first.ordinal == _stronger.ordinal ? _stronger_result : _weaker_result,
        second: _second.ordinal == _stronger.ordinal ? _stronger_result : _weaker_result,
    };
}
