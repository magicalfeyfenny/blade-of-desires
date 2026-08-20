/// Project-owned tests for session binding and reason-coded event records.

/// Recognizes only the content IDs used by these event fixtures so their
/// identity checks use the injected lookup seam.
function _BladeEventSessionKnownContent(_content_id) {
    return _content_id == "ship.maynii"
        || _content_id == "stage.stage1.lost_forest_of_aurei"
        || _content_id == "encounter.stage1.asahi";
}

/// Allocates one valid ID of each needed kind so event tests exercise identity
/// validation rather than relying on invented strings.
function _BladeEventSessionIdentityFixture() {
    var _identity = BladeRunIdentityCreate(
        method({}, _BladeEventSessionKnownContent)
    );
    return {
        identity: _identity,
        owner: BladeRunIdentityAllocate(_identity, BladeRunIdKind.EventOwner),
        instance_a: BladeRunIdentityAllocateForContent(
            _identity,
            BladeRunIdKind.Instance,
            "ship.maynii"
        ),
        instance_b: BladeRunIdentityAllocateForContent(
            _identity,
            BladeRunIdKind.Instance,
            "encounter.stage1.asahi"
        ),
        attack: BladeRunIdentityAllocate(_identity, BladeRunIdKind.Attack),
        bullet: BladeRunIdentityAllocate(_identity, BladeRunIdKind.Bullet),
        damage: BladeRunIdentityAllocate(_identity, BladeRunIdKind.DamageEvent),
    };
}

/// Queues the same two events in either order to prove the explicit order keys,
/// not callback order, determine serialization.
function _BladeEventSessionOrderedLog(_reverse_queue_order) {
    var _fixture = _BladeEventSessionIdentityFixture();
    var _log = BladeEventLogCreate(_fixture.identity);
    BladeEventLogBeginTick(_log, 7);

    // Bind one explicit context for both callbacks. GameMaker exposes this
    // struct as self when either stored method runs.
    var _queue_context = {
        log: _log,
        fixture: _fixture,
    };
    var _queue_attack = method(_queue_context, function() {
        BladeEventLogQueue(
            self.log,
            BladeEventChannel.Gameplay,
            10,
            "attack.started",
            "outcome.input_pressed",
            self.fixture.instance_a,
            self.fixture.attack,
            self.fixture.owner,
            "ship.maynii",
            [BladeEventPayload("power", "i32", 3)]
        );
    });
    var _queue_bullet = method(_queue_context, function() {
        BladeEventLogQueue(
            self.log,
            BladeEventChannel.Gameplay,
            20,
            "bullet.spawned",
            "outcome.pattern_emitted",
            self.fixture.attack,
            self.fixture.bullet,
            self.fixture.owner,
            "stage.stage1.lost_forest_of_aurei",
            [
                BladeEventPayload("speed_q10", "q10", 2048),
                BladeEventPayload("rng_value", "u32", 1120154082),
            ]
        );
    });

    if (_reverse_queue_order) {
        _queue_bullet();
        _queue_attack();
    } else {
        _queue_attack();
        _queue_bullet();
    }
    BladeEventLogCommitTick(_log);
    return {
        fixture: _fixture,
        log: _log,
        canonical: BladeEventLogGameplayCanonical(_log),
    };
}

/// Registers session-header, event validation, ordering, copy-isolation, and
/// overflow cases on the shared test state.
function BladeEventSessionTestsRun(_state) {
    BladeKernelTestRunCase(_state, "session header binds compatibility fields", function() {
        var _header = new BladeSessionHeader(
            "sha1:60bbf1e2436c7f0132be5877b2dc38a149d8ea72",
            305419896
        );
        BladeKernelTestAssertEqual(_header.get_format_version(), 1, "format version");
        BladeKernelTestAssertEqual(
            _header.get_simulation_contract_version(),
            "blade.simulation.v1",
            "simulation contract version"
        );
        BladeKernelTestAssertEqual(
            _header.get_prng_version(),
            "blade.xoshiro128ss.v1",
            "PRNG version"
        );
        BladeKernelTestAssertEqual(_header.get_tick_rate(), 60, "tick rate");
        BladeKernelTestAssertEqual(
            _header.get_run_seed(),
            int64(305419896),
            "normalized run seed"
        );
        BladeKernelTestAssertEqual(
            _header.hash(),
            "6b5a4fa97fc45004d30bb6a516aaa5781c7430e0",
            "header golden hash"
        );

        var _copy = _header.to_struct();
        _copy.run_seed = 7;
        BladeKernelTestAssertEqual(
            _header.get_run_seed(),
            int64(305419896),
            "diagnostic copy cannot mutate header"
        );
    });

    BladeKernelTestRunCase(_state, "session header rejects unknown fingerprint form", function() {
        BladeKernelTestAssertThrows(function() {
            var _invalid_header = new BladeSessionHeader(
                "sha1:60BBF1E2436C7F0132BE5877B2DC38A149D8EA72",
                1
            );
        }, "lowercase hex", "uppercase content fingerprint must fail");
    });

    BladeKernelTestRunCase(_state, "event ordering ignores queue order", function() {
        var _forward = _BladeEventSessionOrderedLog(false);
        var _reverse = _BladeEventSessionOrderedLog(true);
        BladeKernelTestAssertEqual(
            _forward.canonical,
            _reverse.canonical,
            "stable order must produce byte-identical records"
        );
        BladeKernelTestAssertTrue(
            string_pos("evt:1", _forward.canonical)
                < string_pos("evt:2", _forward.canonical),
            "sorted records receive event IDs in canonical order"
        );
    });

    BladeKernelTestRunCase(_state, "unknown event reason fails before allocation", function() {
        var _fixture = _BladeEventSessionIdentityFixture();
        var _log = BladeEventLogCreate(_fixture.identity);
        BladeEventLogBeginTick(_log, 1);
        var _invalid_event_context = {
            log: _log,
            fixture: _fixture,
        };
        BladeKernelTestAssertThrows(method(_invalid_event_context, function() {
            BladeEventLogQueue(
                self.log,
                BladeEventChannel.Gameplay,
                0,
                "damage.applied",
                "cleanup.owner_removed",
                self.fixture.bullet,
                self.fixture.instance_b,
                self.fixture.owner,
                "encounter.stage1.asahi",
                []
            );
        }), "unknown or invalid pair", "invalid type/reason pair must fail");
        BladeKernelTestAssertEqual(
            BladeRunIdentityGetCounters(_fixture.identity).event,
            int64(0),
            "failed event must not consume an ID"
        );
    });

    BladeKernelTestRunCase(_state, "cleanup reason cannot impersonate success", function() {
        var _fixture = _BladeEventSessionIdentityFixture();
        var _log = BladeEventLogCreate(_fixture.identity);
        BladeEventLogBeginTick(_log, 1);
        var _invalid_cleanup_context = {
            log: _log,
            fixture: _fixture,
        };
        BladeKernelTestAssertThrows(method(_invalid_cleanup_context, function() {
            BladeEventLogQueue(
                self.log,
                BladeEventChannel.Gameplay,
                0,
                "instance.removed",
                "outcome.scheduled",
                self.fixture.instance_b,
                "",
                self.fixture.owner,
                "encounter.stage1.asahi",
                []
            );
        }), "unknown or invalid pair", "cleanup must use cleanup/cancel reason");

        BladeEventLogQueue(
            _log,
            BladeEventChannel.Gameplay,
            0,
            "instance.removed",
            "cleanup.out_of_bounds",
            _fixture.instance_b,
            "",
            _fixture.owner,
            "encounter.stage1.asahi",
            []
        );
        BladeEventLogCommitTick(_log);
        BladeKernelTestAssertTrue(
            string_pos("cleanup.out_of_bounds", BladeEventLogGameplayCanonical(_log)) > 0,
            "cleanup reason is retained in canonical event"
        );
    });

    BladeKernelTestRunCase(_state, "unknown event content fails closed", function() {
        var _fixture = _BladeEventSessionIdentityFixture();
        var _log = BladeEventLogCreate(_fixture.identity);
        BladeEventLogBeginTick(_log, 1);
        var _unknown_content_context = {
            log: _log,
            fixture: _fixture,
        };
        BladeKernelTestAssertThrows(method(_unknown_content_context, function() {
            BladeEventLogQueue(
                self.log,
                BladeEventChannel.Gameplay,
                0,
                "attack.started",
                "outcome.input_pressed",
                self.fixture.instance_a,
                self.fixture.attack,
                self.fixture.owner,
                "ship.invented",
                []
            );
        }), "unknown content ID", "event content must come from injected contract");
        BladeKernelTestAssertEqual(
            BladeRunIdentityGetCounters(_fixture.identity).event,
            int64(0),
            "unknown content must not consume an event ID"
        );
    });

    BladeKernelTestRunCase(_state, "presentation events never enter gameplay log", function() {
        var _fixture = _BladeEventSessionIdentityFixture();
        var _log = BladeEventLogCreate(_fixture.identity);
        BladeEventLogBeginTick(_log, 1);
        BladeEventLogQueue(
            _log,
            BladeEventChannel.Gameplay,
            0,
            "instance.spawned",
            "outcome.scheduled",
            "",
            _fixture.instance_a,
            _fixture.owner,
            "ship.maynii",
            []
        );
        BladeEventLogCommitTick(_log);
        var _gameplay_before = BladeEventLogGameplayCanonical(_log);
        var _hash_before = BladeEventLogGameplayHash(_log);
        var _event_count_before = BladeRunIdentityGetCounters(_fixture.identity).event;

        BladeEventLogBeginTick(_log, 2);
        BladeEventLogQueue(
            _log,
            BladeEventChannel.Presentation,
            0,
            "presentation.effect",
            "presentation.requested",
            "",
            "",
            _fixture.owner,
            "ship.maynii",
            [BladeEventPayload("density", "i32", 7)]
        );
        BladeEventLogCommitTick(_log);

        BladeKernelTestAssertEqual(
            BladeEventLogGameplayCanonical(_log),
            _gameplay_before,
            "presentation record excluded from gameplay bytes"
        );
        BladeKernelTestAssertEqual(
            BladeEventLogGameplayHash(_log),
            _hash_before,
            "presentation record excluded from gameplay hash"
        );
        BladeKernelTestAssertEqual(
            BladeRunIdentityGetCounters(_fixture.identity).event,
            _event_count_before,
            "presentation event uses an isolated counter"
        );
        BladeKernelTestAssertNotEqual(
            BladeEventLogAllCanonical(_log),
            BladeCanonicalRecord("A1", [
                _gameplay_before,
                BladeCanonicalRecord("V1", []),
            ]),
            "presentation event remains available for diagnostics"
        );
    });

    BladeKernelTestRunCase(_state, "queue result is detached from pending state", function() {
        var _fixture = _BladeEventSessionIdentityFixture();
        var _log = BladeEventLogCreate(_fixture.identity);
        BladeEventLogBeginTick(_log, 1);
        var _queued = BladeEventLogQueue(
            _log,
            BladeEventChannel.Gameplay,
            0,
            "instance.spawned",
            "outcome.scheduled",
            "",
            _fixture.instance_a,
            _fixture.owner,
            "ship.maynii",
            [BladeEventPayload("rank", "i32", 7)]
        );

        _queued.channel = BladeEventChannel.Presentation;
        _queued.type = "presentation.effect";
        _queued.reason = "presentation.requested";
        _queued.payload[0].value = 99;
        BladeKernelTestAssertEqual(
            _log.pending[0].channel,
            BladeEventChannel.Gameplay,
            "returned channel does not alias pending state"
        );
        BladeKernelTestAssertEqual(
            _log.pending[0].payload[0].value,
            int64(7),
            "returned payload does not alias pending state"
        );

        BladeEventLogCommitTick(_log);
        var _canonical = BladeEventLogGameplayCanonical(_log);
        BladeKernelTestAssertTrue(
            string_pos("instance.spawned", _canonical) > 0,
            "validated gameplay event remains canonical"
        );
        BladeKernelTestAssertEqual(
            BladeRunIdentityGetCounters(_fixture.identity).event,
            int64(1),
            "detached mutation does not alter event allocation"
        );
    });

    BladeKernelTestRunCase(_state, "commit rejects mutated pending schema before allocation", function() {
        var _fixture = _BladeEventSessionIdentityFixture();
        var _log = BladeEventLogCreate(_fixture.identity);
        BladeEventLogBeginTick(_log, 1);
        BladeEventLogQueue(
            _log,
            BladeEventChannel.Gameplay,
            0,
            "instance.spawned",
            "outcome.scheduled",
            "",
            _fixture.instance_a,
            _fixture.owner,
            "ship.maynii",
            []
        );
        _log.pending[0].channel = BladeEventChannel.Presentation;
        var _commit_context = { log: _log };
        BladeKernelTestAssertThrows(method(_commit_context, function() {
            BladeEventLogCommitTick(self.log);
        }), "presentation channel requires", "commit must rebuild the channel schema");
        BladeKernelTestAssertEqual(
            BladeRunIdentityGetCounters(_fixture.identity).event,
            int64(0),
            "invalid pending schema must not consume an event ID"
        );
        BladeKernelTestAssertEqual(
            array_length(_log.pending),
            1,
            "failed commit retains pending diagnostics"
        );
    });

    BladeKernelTestRunCase(_state, "commit rejects mutated pending payload before allocation", function() {
        var _fixture = _BladeEventSessionIdentityFixture();
        var _log = BladeEventLogCreate(_fixture.identity);
        BladeEventLogBeginTick(_log, 1);
        BladeEventLogQueue(
            _log,
            BladeEventChannel.Gameplay,
            0,
            "instance.spawned",
            "outcome.scheduled",
            "",
            _fixture.instance_a,
            _fixture.owner,
            "ship.maynii",
            [BladeEventPayload("rank", "i32", 7)]
        );
        _log.pending[0].payload[0].type = "invented";
        var _commit_context = { log: _log };
        BladeKernelTestAssertThrows(method(_commit_context, function() {
            BladeEventLogCommitTick(self.log);
        }), "unknown type", "commit must rebuild and validate payload data");
        BladeKernelTestAssertEqual(
            BladeRunIdentityGetCounters(_fixture.identity).event,
            int64(0),
            "invalid pending payload must not consume an event ID"
        );
    });

    BladeKernelTestRunCase(_state, "enqueue ordinal overflow fails before mutation", function() {
        var _fixture = _BladeEventSessionIdentityFixture();
        var _log = BladeEventLogCreate(_fixture.identity);
        BladeEventLogBeginTick(_log, 1);
        _log.enqueue_ordinal = int64("9223372036854775807");
        var _queue_context = {
            log: _log,
            fixture: _fixture,
        };
        BladeKernelTestAssertThrows(method(_queue_context, function() {
            BladeEventLogQueue(
                self.log,
                BladeEventChannel.Gameplay,
                0,
                "instance.spawned",
                "outcome.scheduled",
                "",
                self.fixture.instance_a,
                self.fixture.owner,
                "ship.maynii",
                []
            );
        }), "cannot exceed signed int64 range", "enqueue overflow must fail closed");
        BladeKernelTestAssertEqual(
            array_length(_log.pending),
            0,
            "enqueue overflow must not append a pending event"
        );
        BladeKernelTestAssertEqual(
            BladeRunIdentityGetCounters(_fixture.identity).event,
            int64(0),
            "enqueue overflow must not consume an event ID"
        );
    });

    BladeKernelTestRunCase(_state, "presentation counter overflow preflights all event IDs", function() {
        var _fixture = _BladeEventSessionIdentityFixture();
        var _log = BladeEventLogCreate(_fixture.identity);
        BladeEventLogBeginTick(_log, 1);
        BladeEventLogQueue(
            _log,
            BladeEventChannel.Gameplay,
            0,
            "instance.spawned",
            "outcome.scheduled",
            "",
            _fixture.instance_a,
            _fixture.owner,
            "ship.maynii",
            []
        );
        BladeEventLogQueue(
            _log,
            BladeEventChannel.Presentation,
            1,
            "presentation.effect",
            "presentation.requested",
            "",
            "",
            _fixture.owner,
            "ship.maynii",
            []
        );
        _log.next_presentation_event = int64("9223372036854775807");
        var _commit_context = { log: _log };
        BladeKernelTestAssertThrows(method(_commit_context, function() {
            BladeEventLogCommitTick(self.log);
        }), "presentation event counter", "presentation overflow must preflight commit");
        BladeKernelTestAssertEqual(
            BladeRunIdentityGetCounters(_fixture.identity).event,
            int64(0),
            "presentation overflow must fail before gameplay event allocation"
        );
        BladeKernelTestAssertEqual(
            _log.next_presentation_event,
            int64("9223372036854775807"),
            "presentation overflow must not mutate its counter"
        );
    });
}
