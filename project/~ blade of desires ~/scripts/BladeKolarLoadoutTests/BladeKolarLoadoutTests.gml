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
        "close band accepts the nearest eligible target"
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
/// Registers Kolar's focus, range, ordering, and repeatability cases.
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
    BladeKernelTestRunCase(_state, "Kolar rejects malformed target records", function() {
        _BladeKolarLoadoutTestMalformedTarget();
    });
    return _state;
}
