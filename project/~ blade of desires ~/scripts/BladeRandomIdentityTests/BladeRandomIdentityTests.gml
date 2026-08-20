/// Project-owned characterization for named RNG streams and run-local identity.

/// Recognizes only the fixture IDs used below so identity tests exercise the
/// injected contract lookup without duplicating the full production registry.
function _BladeRandomIdentityFixtureContentIdKnown(_content_id) {
    return _content_id == "ship.maynii"
        || _content_id == "stage.stage1.lost_forest_of_aurei"
        || _content_id == "encounter.stage1.asahi";
}

/// Compares every typed counter so reset and rejection tests can detect a gap
/// in any ID sequence.
function _BladeRandomIdentityAssertCountersEqual(_actual, _expected, _message) {
    BladeKernelTestAssertEqual(_actual.instance, _expected.instance, _message + " instance");
    BladeKernelTestAssertEqual(_actual.attack, _expected.attack, _message + " attack");
    BladeKernelTestAssertEqual(_actual.bullet, _expected.bullet, _message + " bullet");
    BladeKernelTestAssertEqual(
        _actual.damage_event,
        _expected.damage_event,
        _message + " damage event"
    );
    BladeKernelTestAssertEqual(
        _actual.event_owner,
        _expected.event_owner,
        _message + " event owner"
    );
    BladeKernelTestAssertEqual(_actual.event, _expected.event, _message + " event");
}

/// Checks signed and full-int64 seed boundaries to lock the implemented
/// modulo-2^32 normalization.
function _BladeRandomIdentityTestSeedNormalization() {
    var _fixtures = [
        [int64(0), int64(0)],
        [int64(-1), int64("4294967295")],
        [int64("4294967296"), int64(0)],
        [int64("4294967297"), int64(1)],
        [int64("-4294967297"), int64("4294967295")],
        [int64("9223372036854775807"), int64("4294967295")],
        [int64("-9223372036854775808"), int64(0)],
    ];

    for (var i = 0; i < array_length(_fixtures); i++) {
        BladeKernelTestAssertEqual(
            BladeRandomNormalizeSeed(_fixtures[i][0]),
            _fixtures[i][1],
            "seed normalization fixture " + string(i)
        );
    }
}

/// Checks each named stream's derived state and first draw against independent
/// fixed vectors.
function _BladeRandomIdentityTestNamedStreamGoldens() {
    var _fixtures = [
        {
            name: "stage_schedule",
            state: [
                int64("4277075231"), int64("3739846392"),
                int64("2016622737"), int64("122783860")
            ],
            first: int64("2254228885"),
        },
        {
            name: "enemy_spawn_variant",
            state: [
                int64("4155205928"), int64("1904688343"),
                int64("3357857511"), int64("2154382541")
            ],
            first: int64("1658381939"),
        },
        {
            name: "pattern_geometry",
            state: [
                int64("2406806776"), int64("552724118"),
                int64("3971373864"), int64("409384850")
            ],
            first: int64("1120154082"),
        },
        {
            name: "drop_selection",
            state: [
                int64("1223054349"), int64("961200663"),
                int64("3356295191"), int64("2532870360")
            ],
            first: int64("302974471"),
        },
        {
            name: "cosmetic_effects",
            state: [
                int64("1430015543"), int64("3585178760"),
                int64("3033702857"), int64("2478210147")
            ],
            first: int64("426898630"),
        },
    ];

    for (var i = 0; i < array_length(_fixtures); i++) {
        var _fixture = _fixtures[i];
        var _stream = new BladeRandomStream(int64("305419896"), _fixture.name);
        BladeKernelTestAssertArrayEqual(
            _stream.get_initial_state(),
            _fixture.state,
            _fixture.name + " derived state"
        );
        BladeKernelTestAssertEqual(
            _stream.next_u32(),
            _fixture.first,
            _fixture.name + " first output"
        );
        BladeKernelTestAssertEqual(_stream.get_draw_count(), int64(1), "first draw count");
    }
}

/// Checks representative half-open ranges so bounded draws retain the exact
/// sequence implemented by the stream.
function _BladeRandomIdentityTestBoundedRangeGoldens() {
    var _stream = new BladeRandomStream(int64("305419896"), "pattern_geometry");
    BladeKernelTestAssertEqual(_stream.next_range(0, 1), int64(0), "unit span");
    BladeKernelTestAssertEqual(_stream.next_range(0, 2), int64(0), "power-of-two span");
    BladeKernelTestAssertEqual(_stream.next_range(-5, 6), int64(-4), "signed span");
    BladeKernelTestAssertEqual(_stream.next_range(0, 10), int64(3), "decimal span");
    BladeKernelTestAssertEqual(
        _stream.next_range(int64(0), int64("4294967296")),
        int64("2387263317"),
        "full uint32 span"
    );
    BladeKernelTestAssertEqual(_stream.get_draw_count(), int64(5), "bounded draws consumed");
}

/// Creates streams in opposite orders to prove their state comes from name and
/// seed rather than creation order.
function _BladeRandomIdentityTestCreationOrderIndependence() {
    var _stage_first = new BladeRandomStream(int64("305419896"), "stage_schedule");
    var _pattern_second = new BladeRandomStream(int64("305419896"), "pattern_geometry");
    var _pattern_first = new BladeRandomStream(int64("305419896"), "pattern_geometry");
    var _stage_second = new BladeRandomStream(int64("305419896"), "stage_schedule");

    BladeKernelTestAssertArrayEqual(
        _stage_first.get_initial_state(),
        _stage_second.get_initial_state(),
        "stage stream creation order"
    );
    BladeKernelTestAssertArrayEqual(
        _pattern_first.get_initial_state(),
        _pattern_second.get_initial_state(),
        "pattern stream creation order"
    );
    BladeKernelTestAssertEqual(
        _stage_first.next_u32(),
        _stage_second.next_u32(),
        "stage output creation order"
    );
    BladeKernelTestAssertEqual(
        _pattern_first.next_u32(),
        _pattern_second.next_u32(),
        "pattern output creation order"
    );
}

/// Draws only from the cosmetic stream and verifies the separate gameplay
/// stream never advances.
function _BladeRandomIdentityTestCosmeticIsolation() {
    var _gameplay = new BladeRandomStream(int64("305419896"), "pattern_geometry");
    var _reference = new BladeRandomStream(int64("305419896"), "pattern_geometry");
    var _cosmetic = new BladeRandomStream(int64("305419896"), "cosmetic_effects");
    var _before_state = _gameplay.get_state();
    var _before_count = _gameplay.get_draw_count();

    for (var i = 0; i < 7; i++) {
        _cosmetic.next_u32();
    }

    BladeKernelTestAssertArrayEqual(
        _gameplay.get_state(),
        _before_state,
        "cosmetic draws leave gameplay state unchanged"
    );
    BladeKernelTestAssertEqual(
        _gameplay.get_draw_count(),
        _before_count,
        "cosmetic draws leave gameplay count unchanged"
    );
    BladeKernelTestAssertEqual(
        _gameplay.next_u32(),
        _reference.next_u32(),
        "cosmetic draws leave next gameplay output unchanged"
    );
    BladeKernelTestAssertEqual(_cosmetic.get_draw_count(), int64(7), "cosmetic diagnostics");
}

/// Sends invalid stream and range requests and verifies validation happens
/// before any random state changes.
function _BladeRandomIdentityTestRandomFailuresDoNotDraw() {
    var _stream = new BladeRandomStream(int64("305419896"), "pattern_geometry");
    var _state = _stream.get_state();
    var _count = _stream.get_draw_count();
    BladeKernelTestAssertThrows(
        function() {
            // Construct an unregistered stream so the assertion captures registry rejection.
            var _unused = new BladeRandomStream(1, "stage_shedule");
        },
        "is not registered",
        "unknown stream fails closed"
    );
    BladeKernelTestAssertArrayEqual(_stream.get_state(), _state, "unknown stream state");
    BladeKernelTestAssertEqual(_stream.get_draw_count(), _count, "unknown stream count");
    // Bind the stream as explicit callback context because AssertThrows calls
    // through a method value, where that context is available as self.
    BladeKernelTestAssertThrows(
        method(
            { stream: _stream },
            function() {
                // Request an empty range so its rejection can be checked before any draw.
                self.stream.next_range(5, 5);
            }
        ),
        "maximum must be greater",
        "empty range fails closed"
    );
    BladeKernelTestAssertArrayEqual(_stream.get_state(), _state, "empty range state");
    BladeKernelTestAssertEqual(_stream.get_draw_count(), _count, "empty range count");

    BladeKernelTestAssertThrows(
        method(
            { stream: _stream },
            function() {
                // Request a span above 2^32 so validation can reject it before any draw.
                self.stream.next_range(0, int64("4294967297"));
            }
        ),
        "span cannot exceed 2^32",
        "oversized range fails closed"
    );
    BladeKernelTestAssertArrayEqual(_stream.get_state(), _state, "oversized range state");
    BladeKernelTestAssertEqual(_stream.get_draw_count(), _count, "oversized range count");
}

/// Allocates every supported ID kind, then resets to prove each independent
/// counter starts reproducibly at one.
function _BladeRandomIdentityTestTypedAllocationAndReset() {
    var _identity = BladeRunIdentityCreate(
        method({}, _BladeRandomIdentityFixtureContentIdKnown)
    );
    BladeKernelTestAssertEqual(
        BladeRunIdentityAllocateForContent(_identity, BladeRunIdKind.Instance, "ship.maynii"),
        "ins:1",
        "known ship allocation"
    );
    BladeKernelTestAssertEqual(
        BladeRunIdentityAllocate(_identity, BladeRunIdKind.Attack),
        "atk:1",
        "first attack"
    );
    BladeKernelTestAssertEqual(
        BladeRunIdentityAllocate(_identity, BladeRunIdKind.Instance),
        "ins:2",
        "second instance"
    );
    BladeKernelTestAssertEqual(
        BladeRunIdentityAllocate(_identity, BladeRunIdKind.Bullet),
        "blt:1",
        "first bullet"
    );
    BladeKernelTestAssertEqual(
        BladeRunIdentityAllocate(_identity, BladeRunIdKind.DamageEvent),
        "dmg:1",
        "first damage event"
    );
    BladeKernelTestAssertEqual(
        BladeRunIdentityAllocate(_identity, BladeRunIdKind.EventOwner),
        "own:1",
        "first event owner"
    );
    BladeKernelTestAssertEqual(
        BladeRunIdentityAllocate(_identity, BladeRunIdKind.Event),
        "evt:1",
        "first event"
    );

    var _expected = {
        instance: int64(2), attack: int64(1), bullet: int64(1),
        damage_event: int64(1), event_owner: int64(1), event: int64(1),
    };
    _BladeRandomIdentityAssertCountersEqual(
        BladeRunIdentityGetCounters(_identity),
        _expected,
        "typed counter order"
    );

    BladeRunIdentityReset(_identity);
    BladeKernelTestAssertEqual(
        BladeRunIdentityAllocateForContent(
            _identity,
            BladeRunIdKind.Instance,
            "stage.stage1.lost_forest_of_aurei"
        ),
        "ins:1",
        "reset reproduces instance identity"
    );
    BladeKernelTestAssertEqual(
        BladeRunIdentityAllocate(_identity, BladeRunIdKind.Attack),
        "atk:1",
        "reset reproduces attack identity"
    );
}

/// Rejects an unknown content ID and checks the next known allocation has no
/// skipped instance number.
function _BladeRandomIdentityTestIdentityFailuresDoNotAllocate() {
    var _identity = BladeRunIdentityCreate(
        method({}, _BladeRandomIdentityFixtureContentIdKnown)
    );
    BladeKernelTestAssertEqual(
        BladeRunIdentityAllocateForContent(
            _identity,
            BladeRunIdKind.Instance,
            "encounter.stage1.asahi"
        ),
        "ins:1",
        "known encounter allocation"
    );
    var _before = BladeRunIdentityGetCounters(_identity);

    BladeKernelTestAssertThrows(
        method({ identity: _identity }, function() {
            // Attempt an unknown content allocation so counter stability can be checked.
            BladeRunIdentityAllocateForContent(
                self.identity,
                BladeRunIdKind.Instance,
                "ship.not_in_contract"
            );
        }),
        "unknown content ID",
        "unknown content fails before allocation"
    );
    _BladeRandomIdentityAssertCountersEqual(
        BladeRunIdentityGetCounters(_identity),
        _before,
        "unknown content counter stability"
    );
    BladeKernelTestAssertEqual(
        BladeRunIdentityAllocateForContent(_identity, BladeRunIdKind.Instance, "ship.maynii"),
        "ins:2",
        "known allocation continues without a gap"
    );
}

/// Tries malformed, mistyped, future, and reset IDs to show validation checks
/// canonical type and spelling against the identity's current counter frontier.
function _BladeRandomIdentityTestIdentityValidation() {
    var _identity = BladeRunIdentityCreate(
        method({}, _BladeRandomIdentityFixtureContentIdKnown)
    );
    var _allocated = BladeRunIdentityAllocate(_identity, BladeRunIdKind.Instance);
    BladeKernelTestAssertEqual(
        BladeRunIdentityRequireAllocated(_identity, _allocated, BladeRunIdKind.Instance),
        "ins:1",
        "allocated ID accepted"
    );
    BladeKernelTestAssertThrows(
        method({ identity: _identity }, function() {
            // Check an attack prefix as an instance ID to exercise typed rejection.
            BladeRunIdentityRequireAllocated(
                self.identity,
                "atk:1",
                BladeRunIdKind.Instance
            );
        }),
        "expected ins ID",
        "wrong typed prefix rejected"
    );
    BladeKernelTestAssertThrows(
        method({ identity: _identity }, function() {
            // Check ordinal zero to exercise the positive-decimal boundary.
            BladeRunIdentityRequireAllocated(
                self.identity,
                "ins:0",
                BladeRunIdKind.Instance
            );
        }),
        "malformed run-local ID",
        "zero ordinal rejected"
    );
    BladeKernelTestAssertThrows(
        method({ identity: _identity }, function() {
            // Check a leading-zero ordinal to exercise canonical spelling rejection.
            BladeRunIdentityRequireAllocated(
                self.identity,
                "ins:01",
                BladeRunIdKind.Instance
            );
        }),
        "malformed run-local ID",
        "leading zero rejected"
    );
    BladeKernelTestAssertThrows(
        method({ identity: _identity }, function() {
            // Check the next ordinal to exercise the current counter frontier.
            BladeRunIdentityRequireAllocated(
                self.identity,
                "ins:2",
                BladeRunIdKind.Instance
            );
        }),
        "unallocated run-local ID",
        "future ordinal rejected"
    );
    BladeKernelTestAssertThrows(
        method({ identity: _identity }, function() {
            // Pass a number instead of an ID string to exercise type rejection.
            BladeRunIdentityRequireAllocated(
                self.identity,
                1,
                BladeRunIdKind.Instance
            );
        }),
        "must be a string",
        "numeric identity rejected"
    );

    BladeRunIdentityReset(_identity);
    BladeKernelTestAssertThrows(
        method({ identity: _identity }, function() {
            // Recheck the former ID after reset lowers the counter frontier.
            BladeRunIdentityRequireAllocated(
                self.identity,
                "ins:1",
                BladeRunIdKind.Instance
            );
        }),
        "unallocated run-local ID",
        "pre-reset identity is no longer allocated"
    );
}

/// Places a counter at the int64 limit to prove exhaustion is reported before
/// incrementing or allocating an ID.
function _BladeRandomIdentityTestCounterOverflow() {
    var _identity = BladeRunIdentityCreate(
        method({}, _BladeRandomIdentityFixtureContentIdKnown)
    );
    _identity.next_instance = int64("9223372036854775807");
    BladeKernelTestAssertThrows(
        method({ identity: _identity }, function() {
            // Attempt allocation at the int64 frontier so the counter cannot wrap.
            BladeRunIdentityAllocate(self.identity, BladeRunIdKind.Instance);
        }),
        "counter exhausted",
        "identity exhaustion must fail explicitly"
    );
    BladeKernelTestAssertEqual(
        _identity.next_instance,
        int64("9223372036854775807"),
        "failed exhausted allocation preserves the counter"
    );
}

/// @func BladeRandomIdentityTestsRun(state)
/// Registers the random-stream and run-identity cases on the shared
/// project-owned test state.
function BladeRandomIdentityTestsRun(_state) {
    BladeKernelTestRunCase(_state, "random seed normalization boundaries", function() {
        // Run the seed boundary fixtures inside the shared case accounting callback.
        _BladeRandomIdentityTestSeedNormalization();
    });
    BladeKernelTestRunCase(_state, "named random stream goldens", function() {
        // Run the named-stream vectors inside the shared case accounting callback.
        _BladeRandomIdentityTestNamedStreamGoldens();
    });
    BladeKernelTestRunCase(_state, "bounded random range goldens", function() {
        // Run the bounded-range vectors inside the shared case accounting callback.
        _BladeRandomIdentityTestBoundedRangeGoldens();
    });
    BladeKernelTestRunCase(_state, "random stream creation order", function() {
        // Compare opposite creation orders inside one reported test case.
        _BladeRandomIdentityTestCreationOrderIndependence();
    });
    BladeKernelTestRunCase(_state, "cosmetic random stream isolation", function() {
        // Check cosmetic isolation inside one reported test case.
        _BladeRandomIdentityTestCosmeticIsolation();
    });
    BladeKernelTestRunCase(_state, "random validation is fail-before-draw", function() {
        // Check invalid random requests without splitting their state assertions.
        _BladeRandomIdentityTestRandomFailuresDoNotDraw();
    });
    BladeKernelTestRunCase(_state, "typed identity allocation and reset", function() {
        // Check every typed counter and reset sequence inside one reported case.
        _BladeRandomIdentityTestTypedAllocationAndReset();
    });
    BladeKernelTestRunCase(_state, "unknown content is fail-before-allocation", function() {
        // Check unknown content rejection and the following allocation for a gap.
        _BladeRandomIdentityTestIdentityFailuresDoNotAllocate();
    });
    BladeKernelTestRunCase(_state, "run-local identity validation", function() {
        // Check ID type, spelling, and the current counter frontier without provenance claims.
        _BladeRandomIdentityTestIdentityValidation();
    });
    BladeKernelTestRunCase(_state, "identity counters fail before overflow", function() {
        // Check counter exhaustion and retained state inside one reported case.
        _BladeRandomIdentityTestCounterOverflow();
    });
    return _state;
}
