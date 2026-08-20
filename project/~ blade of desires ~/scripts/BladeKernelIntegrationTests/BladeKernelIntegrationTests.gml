/// End-to-end deterministic-kernel fixture and invariance tests.

/// Recognizes the three fixture IDs so the integration test keeps production
/// identity validation active without copying the complete content registry.
function _BladeKernelFixtureKnownContent(_content_id) {
    return _content_id == "ship.maynii"
        || _content_id == "stage.stage1.lost_forest_of_aurei"
        || _content_id == "encounter.stage1.asahi";
}

/// Performs the fixture's tick-specific allocations, random draws, and events
/// so two runs execute the same gameplay script.
function _BladeKernelFixtureSimulate(_kernel, _snapshot, _tick) {
    var _input = BladeInputSnapshotRead(_snapshot);
    var _frame = _tick.simulation_tick;

    switch (_frame) {
        case 1:
            var _owner_id = BladeKernelAllocate(
                _kernel,
                BladeRunIdKind.EventOwner
            );
            var _player_id = BladeKernelAllocateForContent(
                _kernel,
                BladeRunIdKind.Instance,
                "ship.maynii"
            );
            var _enemy_id = BladeKernelAllocateForContent(
                _kernel,
                BladeRunIdKind.Instance,
                "encounter.stage1.asahi"
            );
            _kernel.fixture_ids = {
                owner: _owner_id,
                player: _player_id,
                enemy: _enemy_id,
            };
            _kernel.fixture_stage_rng = BladeKernelRandom(
                _kernel,
                "stage_schedule"
            ).next_u32();
            BladeKernelQueueEvent(
                _kernel,
                BladeEventChannel.Gameplay,
                0,
                "instance.spawned",
                "outcome.scheduled",
                "",
                _kernel.fixture_ids.player,
                _kernel.fixture_ids.owner,
                "ship.maynii",
                [
                    BladeEventPayload("x_q10", "q10", 189440),
                    BladeEventPayload("y_q10", "q10", 0),
                ]
            );
            break;

        case 2:
            _kernel.fixture_ids.attack = BladeKernelAllocate(
                _kernel,
                BladeRunIdKind.Attack
            );
            _kernel.fixture_enemy_rng = BladeKernelRandom(
                _kernel,
                "enemy_spawn_variant"
            ).next_u32();
            BladeKernelQueueEvent(
                _kernel,
                BladeEventChannel.Gameplay,
                0,
                "attack.started",
                "outcome.input_pressed",
                _kernel.fixture_ids.player,
                _kernel.fixture_ids.attack,
                _kernel.fixture_ids.owner,
                "ship.maynii",
                [BladeEventPayload("power", "i32", 3)]
            );
            break;

        case 3:
            _kernel.fixture_ids.bullet = BladeKernelAllocate(
                _kernel,
                BladeRunIdKind.Bullet
            );
            _kernel.fixture_pattern_rng = BladeKernelRandom(
                _kernel,
                "pattern_geometry"
            ).next_u32();
            _kernel.fixture_pattern_rng_second = BladeKernelRandom(
                _kernel,
                "pattern_geometry"
            ).next_u32();
            BladeKernelQueueEvent(
                _kernel,
                BladeEventChannel.Gameplay,
                0,
                "bullet.spawned",
                "outcome.pattern_emitted",
                _kernel.fixture_ids.attack,
                _kernel.fixture_ids.bullet,
                _kernel.fixture_ids.owner,
                "stage.stage1.lost_forest_of_aurei",
                [
                    BladeEventPayload("rng_value", "u32", _kernel.fixture_pattern_rng),
                    BladeEventPayload("speed_q10", "q10", 2048),
                ]
            );
            break;

        case 4:
            _kernel.fixture_ids.damage = BladeKernelAllocate(
                _kernel,
                BladeRunIdKind.DamageEvent
            );
            _kernel.fixture_drop_rng = BladeKernelRandom(
                _kernel,
                "drop_selection"
            ).next_u32();
            BladeKernelQueueEvent(
                _kernel,
                BladeEventChannel.Gameplay,
                0,
                "damage.applied",
                "outcome.collision_confirmed",
                _kernel.fixture_ids.bullet,
                _kernel.fixture_ids.enemy,
                _kernel.fixture_ids.owner,
                "encounter.stage1.asahi",
                [BladeEventPayload("amount", "i32", 10)]
            );
            break;
    }

    return BladeCanonicalRecord("F1", [
        string(_frame),
        string(_input.held_actions),
    ]);
}

/// Builds four injected input samples. Optional gameplay and prompt-only
/// changes let the hash tests exercise each boundary separately.
function _BladeKernelFixtureInputs(_input_variant, _prompt_variant) {
    var _device = BladePromptDevice.KeyboardMouse;
    if (_prompt_variant) {
        _device = BladePromptDevice.Gamepad;
    }

    var _second_move_y = 0;
    if (_input_variant) {
        _second_move_y = 256;
    }
    return [
        BladeInputRawStateCreate(
            1024,
            0,
            BladeInputAction.Fire | BladeInputAction.Focus,
            _device,
            false,
            0,
            0
        ),
        BladeInputRawStateCreate(
            1024,
            _second_move_y,
            BladeInputAction.Fire | BladeInputAction.Focus,
            _device,
            true,
            12000,
            -4000
        ),
        BladeInputRawStateCreate(
            1024,
            0,
            BladeInputAction.Focus,
            _device,
            false,
            0,
            0
        ),
        BladeInputRawStateCreate(0, 0, 0, _device, false, 0, 0),
    ];
}

/// Advances one kernel through the fixture and returns every canonical result
/// that the invariance cases compare.
function _BladeKernelFixtureDrive(
    _kernel,
    _input_variant,
    _cosmetic_draws,
    _prompt_variant
) {
    for (var i = 0; i < _cosmetic_draws; i++) {
        BladeKernelRandom(_kernel, "cosmetic_effects").next_u32();
    }

    var _inputs = _BladeKernelFixtureInputs(_input_variant, _prompt_variant);
    var _domains = BladeClockDomain.Stage
        | BladeClockDomain.Actor
        | BladeClockDomain.Boss;
    // The kernel accepts a GameMaker method value. This named callback needs no
    // captured fixture state, so its bound context is intentionally empty.
    var _simulate = method({}, _BladeKernelFixtureSimulate);
    for (var i = 0; i < array_length(_inputs); i++) {
        BladeKernelStepDirect(
            _kernel,
            _inputs[i],
            _domains,
            _simulate
        );
    }
    return {
        canonical: BladeKernelGameplayCanonical(_kernel),
        hash: BladeKernelGameplayHash(_kernel),
        events: BladeEventLogGameplayCanonical(_kernel.event_log),
        event_hash: BladeEventLogGameplayHash(_kernel.event_log),
    };
}

/// Creates a fresh seeded kernel before driving the fixture so separate runs
/// cannot share mutable state accidentally.
function _BladeKernelFixtureRun(
    _seed,
    _input_variant = false,
    _cosmetic_draws = 0,
    _prompt_variant = false
) {
    var _kernel = BladeDeterministicKernelCreate(
        "sha1:60bbf1e2436c7f0132be5877b2dc38a149d8ea72",
        _seed,
        method({}, _BladeKernelFixtureKnownContent),
        8
    );
    var _result = _BladeKernelFixtureDrive(
        _kernel,
        _input_variant,
        _cosmetic_draws,
        _prompt_variant
    );
    _result.kernel = _kernel;
    return _result;
}

/// Registers end-to-end cases that prove repeatability and the implemented
/// gameplay-versus-presentation hash boundary.
function BladeKernelIntegrationTestsRun(_state) {
    BladeKernelTestRunCase(_state, "identical integration fixtures are byte identical", function() {
        // Run two equal fixtures to compare bytes, hashes, and final ID counts.
        var _first = _BladeKernelFixtureRun(305419896);
        var _second = _BladeKernelFixtureRun(305419896);
        BladeKernelTestAssertEqual(
            _first.canonical,
            _second.canonical,
            "same run canonical bytes"
        );
        BladeKernelTestAssertEqual(_first.events, _second.events, "same event bytes");
        BladeKernelTestAssertEqual(_first.hash, _second.hash, "same gameplay hash");
        BladeKernelTestAssertEqual(
            _first.event_hash,
            _second.event_hash,
            "same event hash"
        );
        BladeKernelTestAssertEqual(
            _first.event_hash,
            "a2ca10f5fba445635a90f0400fea807e2299b928",
            "independent event-log golden hash"
        );
        BladeKernelTestAssertEqual(
            _first.hash,
            "26e97ec1441354bd518717a485356778fa35dc62",
            "independent gameplay golden hash"
        );

        var _ids = BladeRunIdentityGetCounters(_first.kernel.identity);
        BladeKernelTestAssertEqual(_ids.instance, int64(2), "instance ID count");
        BladeKernelTestAssertEqual(_ids.attack, int64(1), "attack ID count");
        BladeKernelTestAssertEqual(_ids.bullet, int64(1), "bullet ID count");
        BladeKernelTestAssertEqual(_ids.damage_event, int64(1), "damage ID count");
        BladeKernelTestAssertEqual(_ids.event_owner, int64(1), "owner ID count");
        BladeKernelTestAssertEqual(_ids.event, int64(4), "event ID count");

        show_debug_message("BLADE_KERNEL_INTEGRATION_EVENT_HASH: " + _first.event_hash);
        show_debug_message("BLADE_KERNEL_INTEGRATION_GAMEPLAY_HASH: " + _first.hash);
    });

    BladeKernelTestRunCase(_state, "seed and gameplay input changes alter output", function() {
        // Vary the seed and one gameplay input independently to check both hash inputs.
        var _baseline = _BladeKernelFixtureRun(305419896);
        var _changed_seed = _BladeKernelFixtureRun(305419897);
        var _changed_input = _BladeKernelFixtureRun(305419896, true);
        BladeKernelTestAssertNotEqual(
            _baseline.hash,
            _changed_seed.hash,
            "gameplay seed must alter hash"
        );
        BladeKernelTestAssertNotEqual(
            _baseline.events,
            _changed_seed.events,
            "gameplay seed must alter RNG-backed event bytes"
        );
        BladeKernelTestAssertNotEqual(
            _baseline.hash,
            _changed_input.hash,
            "gameplay input must alter hash"
        );
    });

    BladeKernelTestRunCase(_state, "cosmetic draws are isolated from gameplay", function() {
        // Add cosmetic-only draws and compare gameplay bytes, hashes, and events.
        var _baseline = _BladeKernelFixtureRun(305419896);
        var _with_cosmetics = _BladeKernelFixtureRun(305419896, false, 7);
        BladeKernelTestAssertEqual(
            _baseline.canonical,
            _with_cosmetics.canonical,
            "cosmetic draws excluded from canonical gameplay"
        );
        BladeKernelTestAssertEqual(
            _baseline.hash,
            _with_cosmetics.hash,
            "cosmetic draws excluded from gameplay hash"
        );
        BladeKernelTestAssertEqual(
            _baseline.events,
            _with_cosmetics.events,
            "cosmetic draws do not perturb gameplay events"
        );
        BladeKernelTestAssertEqual(
            _with_cosmetics.kernel.cosmetic_effects.get_draw_count(),
            int64(7),
            "cosmetic diagnostics still count draws"
        );
    });

    BladeKernelTestRunCase(_state, "prompt device is presentation-only hash data", function() {
        // Change only the prompt device to verify it stays outside the gameplay hash.
        var _keyboard = _BladeKernelFixtureRun(305419896, false, 0, false);
        var _gamepad = _BladeKernelFixtureRun(305419896, false, 0, true);
        BladeKernelTestAssertEqual(
            _keyboard.hash,
            _gamepad.hash,
            "prompt device identity excluded from gameplay hash"
        );
    });

    BladeKernelTestRunCase(_state, "kernel reset reproduces IDs events and hash", function() {
        // Drive, reset, and drive one kernel again to compare its reproducible outputs.
        var _kernel = BladeDeterministicKernelCreate(
            "sha1:60bbf1e2436c7f0132be5877b2dc38a149d8ea72",
            305419896,
            method({}, _BladeKernelFixtureKnownContent),
            8
        );
        var _before = _BladeKernelFixtureDrive(_kernel, false, 0, false);
        BladeDeterministicKernelReset(_kernel);
        var _after = _BladeKernelFixtureDrive(_kernel, false, 0, false);
        BladeKernelTestAssertEqual(_before.canonical, _after.canonical, "reset bytes");
        BladeKernelTestAssertEqual(_before.events, _after.events, "reset event IDs");
        BladeKernelTestAssertEqual(_before.hash, _after.hash, "reset gameplay hash");
    });

    BladeKernelTestRunCase(_state, "kernel rejects unknown content before ID allocation", function() {
        // Attempt an unknown content allocation and verify the instance counter stays zero.
        var _kernel = BladeDeterministicKernelCreate(
            "sha1:60bbf1e2436c7f0132be5877b2dc38a149d8ea72",
            1,
            method({}, _BladeKernelFixtureKnownContent),
            8
        );
        var _allocation_context = { kernel: _kernel };
        BladeKernelTestAssertThrows(method(_allocation_context, function() {
            // Allocate the invented content ID through bound kernel context.
            BladeKernelAllocateForContent(
                self.kernel,
                BladeRunIdKind.Instance,
                "ship.invented"
            );
        }), "unknown content ID", "kernel content lookup must fail closed");
        BladeKernelTestAssertEqual(
            BladeRunIdentityGetCounters(_kernel.identity).instance,
            int64(0),
            "failed content allocation does not consume ID"
        );
    });
}
