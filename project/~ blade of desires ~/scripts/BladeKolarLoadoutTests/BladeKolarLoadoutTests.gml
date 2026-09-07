/// @description Deterministic tests for Kolar's close and ranged channels.

// Proves focus changes the close payoff while retaining useful ranged fire.
function _BladeKolarLoadoutTestModes() {
    var _unfocused = BladeKolarVolley(false, 0);
    var _focused = BladeKolarVolley(true, 0);
    BladeKernelTestAssertEqual(
        array_length(_unfocused), 3, "unfocused Kolar volley count"
    );
    BladeKernelTestAssertEqual(
        array_length(_focused), 3, "focused Kolar volley count"
    );
    var _unfocused_close = 0;
    var _unfocused_ranged = 0;
    var _focused_close = 0;
    var _focused_ranged = 0;
    for (var _index = 0; _index < 3; ++_index) {
        var _unfocused_shot = _unfocused[_index];
        var _focused_shot = _focused[_index];
        BladeKernelTestAssertEqual(
            _unfocused_shot.order, _index, "unfocused Kolar order"
        );
        BladeKernelTestAssertEqual(
            _focused_shot.order, _index, "focused Kolar order"
        );
        if (_unfocused_shot.channel == "close") {
            _unfocused_close += _unfocused_shot.damage;
        } else {
            _unfocused_ranged += _unfocused_shot.damage;
        }
        if (_focused_shot.channel == "close") {
            _focused_close += _focused_shot.damage;
        } else {
            _focused_ranged += _focused_shot.damage;
        }
    }
    BladeKernelTestAssertEqual(
        _unfocused_close, 3, "unfocused close channel remains explicit"
    );
    BladeKernelTestAssertTrue(
        _unfocused_ranged >= 3.8, "unfocused ranged channel is meaningful"
    );
    BladeKernelTestAssertTrue(
        _focused_close > _unfocused_close,
        "focused close channel has the strongest payoff"
    );
    BladeKernelTestAssertTrue(
        _focused_ranged >= 2.25, "focused ranged channel remains useful"
    );
    BladeKernelTestAssertEqual(
        BladeKolarCloseBand(), 58, "close band uses the authored logical distance"
    );
    BladeKernelTestAssertNotEqual(
        BladeKolarVolleyCanonical(false, 0),
        BladeKolarVolleyCanonical(true, 0),
        "focus produces a distinct Kolar command"
    );
}

// Exercises nearest distance, authored spawn order, and stable-ID tie breaks.
function _BladeKolarLoadoutTestTargetOrder() {
    var _records = [
        { eligible: true, stable_id: "ins:3", spawn_order: 2, x: 20, y: 0 },
        { eligible: true, stable_id: "ins:2", spawn_order: 1, x: -20, y: 0 },
        { eligible: true, stable_id: "ins:1", spawn_order: 0, x: 5, y: 0 },
    ];
    BladeKernelTestAssertEqual(
        BladeKolarChooseTarget(_records, 0, 0),
        2,
        "nearest Kolar target wins"
    );
    _records[2].eligible = false;
    BladeKernelTestAssertEqual(
        BladeKolarChooseTarget(_records, 0, 0, 20),
        1,
        "cleaned target is skipped for the next eligible target"
    );
    _records[0].spawn_order = 1;
    BladeKernelTestAssertEqual(
        BladeKolarChooseTarget(_records, 0, 0, 20),
        1,
        "spawn order breaks equal-distance ties"
    );
    _records[1].spawn_order = 1;
    BladeKernelTestAssertEqual(
        BladeKolarChooseTarget(_records, 0, 0, 20),
        1,
        "stable identity breaks remaining ties"
    );
    BladeKernelTestAssertEqual(
        BladeKolarChooseTarget(_records, 0, 0, 10),
        -1,
        "close channel rejects targets outside its band"
    );
}

// Confirms same focus and Hyper inputs always yield the same ordered commands.
function _BladeKolarLoadoutTestRepeatability() {
    for (var _hyper = 0; _hyper <= 3; ++_hyper) {
        for (var _focused = 0; _focused <= 1; ++_focused) {
            BladeKernelTestAssertEqual(
                BladeKolarVolleyCanonical(_focused, _hyper),
                BladeKolarVolleyCanonical(_focused, _hyper),
                "Kolar volley repeats for identical state"
            );
        }
    }
    BladeKernelTestAssertNotEqual(
        BladeKolarVolleyCanonical(false, 0),
        BladeKolarVolleyCanonical(false, 2),
        "Hyper changes documented Kolar damage"
    );
}

// Proves the declared close payoff and exact logical band against equal durations.
function _BladeKolarLoadoutTestCharacterizationMargin() {
    var _characterization = BladeKolarCharacterization();
    for (var _focused = 0; _focused <= 1; ++_focused) {
        var _close_damage = BladeKolarBaseDamageOverTicks(
            _focused, BladeKolarCloseBand(),
            _characterization.equal_duration_ticks
        );
        var _far_damage = BladeKolarBaseDamageOverTicks(
            _focused, BladeKolarCloseBand() + 1,
            _characterization.equal_duration_ticks
        );
        BladeKernelTestAssertTrue(
            _close_damage >= _far_damage * _characterization.close_damage_margin,
            "Kolar close-band damage clears the declared margin"
        );
    }
    BladeKernelTestAssertTrue(
        BladeKolarBaseDamageOverTicks(false, 58, 120)
            > BladeKolarBaseDamageOverTicks(false, 59, 120),
        "close channel includes distance 58 and excludes distance 59"
    );
}

// Uses the weakest focused ranged floor for representative safe-separation fixtures.
function _BladeKolarLoadoutTestRangedViability() {
    var _characterization = BladeKolarCharacterization();
    var _far_distance = BladeKolarCloseBand() + 1;
    var _far_target_damage = BladeKolarBaseDamageOverTicks(
        true, _far_distance, _characterization.far_target.window_ticks
    );
    BladeKernelTestAssertTrue(
        _far_target_damage >= _characterization.far_target.hit_points,
        "focused ranged fire defeats the representative far target in-window"
    );
    BladeKernelTestAssertTrue(
        BladeKolarBaseDamageOverTicks(
            false, _far_distance, _characterization.far_target.window_ticks
        ) >= _characterization.far_target.hit_points,
        "unfocused ranged fire also defeats the representative far target"
    );

    var _commander_far = BladeKolarBaseDamageOverTicks(
        true, _far_distance, _characterization.commander.window_ticks
    );
    var _commander_close = BladeKolarBaseDamageOverTicks(
        true, BladeKolarCloseBand(), _characterization.commander.window_ticks
    );
    BladeKernelTestAssertTrue(
        _commander_far >= _characterization.commander.hit_points,
        "Stage 1-shaped commander remains defeatable from safe range"
    );
    BladeKernelTestAssertTrue(
        _commander_close
            >= _commander_far * _characterization.close_damage_margin,
        "commander fixture preserves close-range payoff"
    );

    var _boss_far = BladeKolarBaseDamageOverTicks(
        true, _far_distance, _characterization.separation_boss.window_ticks
    );
    var _boss_close = BladeKolarBaseDamageOverTicks(
        true, BladeKolarCloseBand(),
        _characterization.separation_boss.window_ticks
    );
    BladeKernelTestAssertTrue(
        _boss_far >= _characterization.separation_boss.hit_points,
        "forced-separation boss remains defeatable with ranged fire alone"
    );
    BladeKernelTestAssertTrue(
        _boss_close >= _boss_far * _characterization.close_damage_margin,
        "forced-separation fixture does not erase close-range identity"
    );
}

// Locks the base cadence and prevents Kolar from drifting into the other ship identities.
function _BladeKolarLoadoutTestCadenceAndIdentity() {
    var _far_distance = BladeKolarCloseBand() + 1;
    BladeKernelTestAssertEqual(
        BladeKolarBaseDamageOverTicks(false, _far_distance, 8),
        3.8,
        "eight ticks contain exactly one base unfocused ranged volley"
    );
    BladeKernelTestAssertEqual(
        BladeKolarBaseDamageOverTicks(false, _far_distance, 9),
        7.6,
        "ninth tick starts the next base volley"
    );
    var _volley = BladeKolarVolley(false, 0);
    BladeKernelTestAssertEqual(
        array_length(_volley), 3,
        "Kolar remains a three-option loadout rather than Ciela's five-shot spread"
    );
    for (var _index = 0; _index < array_length(_volley); ++_index) {
        BladeKernelTestAssertFalse(
            variable_struct_exists(_volley[_index], "tracking"),
            "Kolar shots do not acquire Maynii tracking state"
        );
        BladeKernelTestAssertTrue(
            abs(_volley[_index].velocity_x) <= 0.24,
            "Kolar lateral velocity stays narrow rather than broad-spread"
        );
    }
}

// Encodes early projectile positions as integer hundredths for a stable trajectory golden.
function _BladeKolarLoadoutTrajectoryCanonical(_focused, _ticks) {
    var _volley = BladeKolarVolley(_focused, 0);
    var _text = "KTR1";
    for (var _tick = 1; _tick <= _ticks; ++_tick) {
        for (var _index = 0; _index < array_length(_volley); ++_index) {
            var _shot = _volley[_index];
            var _x_q100 = round(
                (_shot.offset_x + _shot.velocity_x * _tick) * 100
            );
            var _y_q100 = round(
                (_shot.offset_y + _shot.velocity_y * _tick) * 100
            );
            _text += "|" + string(_tick)
                + "," + string(_index)
                + "," + string(_x_q100)
                + "," + string(_y_q100);
        }
    }
    return _text;
}

// Locks the first four focused ticks independently from decorative sprite motion.
function _BladeKolarLoadoutTestTrajectoryGolden() {
    var _expected = "KTR1"
        + "|1,0,-1014,-1640|1,1,0,-2100|1,2,1014,-1640"
        + "|2,0,-1028,-2380|2,1,0,-2800|2,2,1028,-2380"
        + "|3,0,-1042,-3120|3,1,0,-3500|3,2,1042,-3120"
        + "|4,0,-1056,-3860|4,1,0,-4200|4,2,1056,-3860";
    BladeKernelTestAssertEqual(
        _BladeKolarLoadoutTrajectoryCanonical(true, 4),
        _expected,
        "focused Kolar first-four-tick trajectory golden"
    );
    BladeKernelTestAssertEqual(
        _BladeKolarLoadoutTrajectoryCanonical(true, 4),
        _BladeKolarLoadoutTrajectoryCanonical(true, 4),
        "identical Kolar trajectory fixtures are byte-identical"
    );
}

// Rejects incomplete eligible records instead of inventing a target identity.
function _BladeKolarLoadoutTestMalformedTarget() {
    BladeKernelTestAssertThrows(
        method({}, function() {
            BladeKolarChooseTarget([
                { eligible: true, stable_id: "", spawn_order: 0, x: 0, y: 0 },
            ], 0, 0);
        }),
        "eligible target record is incomplete",
        "eligible Kolar target requires stable identity"
    );
}

/// @func BladeKolarLoadoutTestsRun(state)
/// Registers Kolar's focus, range, characterization, identity, and repeatability cases.
function BladeKolarLoadoutTestsRun(_state) {
    BladeKernelTestRunCase(_state, "Kolar focus states preserve close and ranged channels", function() {
        _BladeKolarLoadoutTestModes();
    });
    BladeKernelTestRunCase(_state, "Kolar target range and ordering are deterministic", function() {
        _BladeKolarLoadoutTestTargetOrder();
    });
    BladeKernelTestRunCase(_state, "Kolar volleys repeat across Hyper states", function() {
        _BladeKolarLoadoutTestRepeatability();
    });
    BladeKernelTestRunCase(_state, "Kolar close damage clears its characterized far margin", function() {
        _BladeKolarLoadoutTestCharacterizationMargin();
    });
    BladeKernelTestRunCase(_state, "Kolar ranged floor clears far combat fixtures", function() {
        _BladeKolarLoadoutTestRangedViability();
    });
    BladeKernelTestRunCase(_state, "Kolar cadence and ship identity remain distinct", function() {
        _BladeKolarLoadoutTestCadenceAndIdentity();
    });
    BladeKernelTestRunCase(_state, "Kolar early trajectory matches its golden", function() {
        _BladeKolarLoadoutTestTrajectoryGolden();
    });
    BladeKernelTestRunCase(_state, "Kolar rejects malformed target records", function() {
        _BladeKolarLoadoutTestMalformedTarget();
    });
    return _state;
}
