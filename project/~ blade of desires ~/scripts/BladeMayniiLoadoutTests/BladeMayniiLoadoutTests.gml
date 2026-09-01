/// @description Deterministic tests for Maynii's two fire modes and target rules.

// Proves the option formations and projectile order switch cleanly with focus.
function _BladeMayniiLoadoutTestModes() {
    var _tracking = BladeMayniiVolley(false, 0);
    var _forward = BladeMayniiVolley(true, 0);
    BladeKernelTestAssertEqual(
        array_length(_tracking), 2, "unfocused tracking option count"
    );
    BladeKernelTestAssertEqual(
        array_length(_forward), 3, "focused forward option count"
    );
    for (var _index = 0; _index < array_length(_tracking); ++_index) {
        BladeKernelTestAssertTrue(
            _tracking[_index].tracking, "unfocused projectile tracks"
        );
        BladeKernelTestAssertEqual(
            _tracking[_index].order, _index, "tracking projectile order"
        );
    }
    for (var _forward_index = 0;
        _forward_index < array_length(_forward); ++_forward_index) {
        BladeKernelTestAssertFalse(
            _forward[_forward_index].tracking, "focused projectile stays forward"
        );
        BladeKernelTestAssertEqual(
            _forward[_forward_index].order,
            _forward_index,
            "forward projectile order"
        );
    }
    var _unfocused_again = BladeMayniiVolleyCanonical(false, 0);
    BladeKernelTestAssertEqual(
        _unfocused_again,
        BladeMayniiVolleyCanonical(false, 0),
        "returning to unfocused restores the exact volley"
    );
    BladeKernelTestAssertNotEqual(
        _unfocused_again,
        BladeMayniiVolleyCanonical(true, 0),
        "focus does not combine or invert the modes"
    );
}

// Exercises nearest distance, spawn order, stable-ID ties, loss, and reacquisition.
function _BladeMayniiLoadoutTestTargetOrder() {
    var _records = [
        { eligible: true, stable_id: "ins:3", spawn_order: 2, x: 20, y: 0 },
        { eligible: true, stable_id: "ins:2", spawn_order: 1, x: -20, y: 0 },
        { eligible: true, stable_id: "ins:1", spawn_order: 0, x: 5, y: 0 },
    ];
    BladeKernelTestAssertEqual(
        BladeMayniiChooseTarget(_records, 0, 0),
        2,
        "nearest target wins before ordering ties"
    );

    _records[2].eligible = false;
    BladeKernelTestAssertEqual(
        BladeMayniiChooseTarget(_records, 0, 0),
        1,
        "spawn order breaks equal-distance ties"
    );
    _records[0].spawn_order = 1;
    BladeKernelTestAssertEqual(
        BladeMayniiChooseTarget(_records, 0, 0),
        1,
        "stable identity breaks the remaining tie"
    );

    _records[1].eligible = false;
    BladeKernelTestAssertEqual(
        BladeMayniiChooseTarget(_records, 0, 0),
        0,
        "tracking reacquires the next eligible target after loss"
    );
    _records[0].eligible = false;
    BladeKernelTestAssertEqual(
        BladeMayniiChooseTarget(_records, 0, 0),
        -1,
        "no eligible target returns no stale index"
    );
    var _fallback = BladeMayniiForwardFallback(BLADE_MAYNII_TRACKING_SPEED);
    BladeKernelTestAssertEqual(_fallback.x, 0, "fallback has no sideways drift");
    BladeKernelTestAssertEqual(
        _fallback.y,
        -BLADE_MAYNII_TRACKING_SPEED,
        "fallback keeps useful forward damage"
    );
}

// Encodes a short steering path so identical state produces identical trajectories.
function _BladeMayniiLoadoutTrajectory(_target_x, _target_y) {
    var _x = 320;
    var _y = 300;
    var _velocity_x = 0;
    var _velocity_y = -BLADE_MAYNII_TRACKING_SPEED;
    var _text = "BMT1";
    for (var _tick = 0; _tick < 12; ++_tick) {
        var _velocity = BladeMayniiSteerVelocity(
            _velocity_x,
            _velocity_y,
            _x,
            _y,
            _target_x,
            _target_y,
            BLADE_MAYNII_TRACKING_SPEED,
            BLADE_MAYNII_TRACKING_TURN_DEGREES
        );
        _velocity_x = _velocity.x;
        _velocity_y = _velocity.y;
        _x += _velocity_x;
        _y += _velocity_y;
        _text += "|" + string(_x) + "," + string(_y);
    }
    return _text;
}

// Proves first-N ticks and Hyper-adjusted damage repeat for the same inputs.
function _BladeMayniiLoadoutTestRepeatability() {
    var _left_first = _BladeMayniiLoadoutTrajectory(250, 80);
    var _left_second = _BladeMayniiLoadoutTrajectory(250, 80);
    var _right = _BladeMayniiLoadoutTrajectory(390, 80);
    BladeKernelTestAssertEqual(
        _left_first, _left_second, "same target repeats the first twelve ticks"
    );
    BladeKernelTestAssertNotEqual(
        _left_first, _right, "different target changes the trajectory"
    );
    BladeKernelTestAssertEqual(
        BladeMayniiVolleyCanonical(false, 2),
        BladeMayniiVolleyCanonical(false, 2),
        "same Hyper state repeats projectile damage and order"
    );
    BladeKernelTestAssertNotEqual(
        BladeMayniiVolleyCanonical(false, 0),
        BladeMayniiVolleyCanonical(false, 2),
        "Hyper state changes documented preliminary damage"
    );
}

// Rejects incomplete eligible data rather than inventing an unstable target key.
function _BladeMayniiLoadoutTestMalformedTarget() {
    BladeKernelTestAssertThrows(
        method({}, function() {
            BladeMayniiChooseTarget([
                { eligible: true, stable_id: "", spawn_order: 0, x: 0, y: 0 },
            ], 0, 0);
        }),
        "eligible target record is incomplete",
        "eligible target requires stable identity"
    );
}

/// @func BladeMayniiLoadoutTestsRun(state)
/// Registers Maynii's focus, targeting, fallback, and repeatability cases.
function BladeMayniiLoadoutTestsRun(_state) {
    BladeKernelTestRunCase(_state, "Maynii focus states select distinct volleys", function() {
        _BladeMayniiLoadoutTestModes();
    });
    BladeKernelTestRunCase(_state, "Maynii target order and loss are deterministic", function() {
        _BladeMayniiLoadoutTestTargetOrder();
    });
    BladeKernelTestRunCase(_state, "Maynii trajectories and damage repeat", function() {
        _BladeMayniiLoadoutTestRepeatability();
    });
    BladeKernelTestRunCase(_state, "Maynii rejects malformed target records", function() {
        _BladeMayniiLoadoutTestMalformedTarget();
    });
    return _state;
}
