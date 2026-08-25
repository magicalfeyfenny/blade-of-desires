/// Project-owned tests for the combat event type and reason vocabulary.

/// Recognizes the one fixture content ID used while exercising run-local event endpoints.
function _BladeEventSchemaTestsKnownContent(_content_id) {
    return _content_id == "encounter.fixture.combat";
}

/// Allocates one ID of every endpoint kind needed by the closed event schema tests.
function _BladeEventSchemaTestsFixture() {
    var _identity = BladeRunIdentityCreate(
        method({}, _BladeEventSchemaTestsKnownContent)
    );
    return {
        identity: _identity,
        owner: BladeRunIdentityAllocate(_identity, BladeRunIdKind.EventOwner),
        parent: BladeRunIdentityAllocateForContent(
            _identity,
            BladeRunIdKind.Instance,
            "encounter.fixture.combat"
        ),
        child: BladeRunIdentityAllocateForContent(
            _identity,
            BladeRunIdKind.Instance,
            "encounter.fixture.combat"
        ),
        attack: BladeRunIdentityAllocate(_identity, BladeRunIdKind.Attack),
        bullet: BladeRunIdentityAllocate(_identity, BladeRunIdKind.Bullet),
        damage: BladeRunIdentityAllocate(_identity, BladeRunIdKind.DamageEvent),
    };
}

/// Queues and commits one event so tests cover endpoint validation and the public log boundary.
function _BladeEventSchemaTestsCommit(
    _fixture, _type, _reason, _source_id, _target_id
) {
    var _log = BladeEventLogCreate(_fixture.identity);
    BladeEventLogBeginTick(_log, 1);
    BladeEventLogQueue(
        _log,
        BladeEventChannel.Gameplay,
        0,
        _type,
        _reason,
        _source_id,
        _target_id,
        _fixture.owner,
        "encounter.fixture.combat",
        []
    );
    BladeEventLogCommitTick(_log);
    return BladeEventLogGameplayCanonical(_log);
}

/// Registers combat additions, boundary-reason coverage, and invalid-pair rejection.
function BladeEventSchemaTestsRun(_state) {
    BladeKernelTestRunCase(_state, "combat event schema owns transaction and defeat relations", function() {
        var _damage = _BladeEventSchemaTestsFixture();
        var _damage_canonical = _BladeEventSchemaTestsCommit(
            _damage,
            "damage.transaction_applied",
            "outcome.collision_confirmed",
            _damage.damage,
            _damage.child
        );
        BladeKernelTestAssertTrue(
            string_pos("damage.transaction_applied", _damage_canonical) > 0,
            "damage transaction pair committed"
        );

        var _child = _BladeEventSchemaTestsFixture();
        var _child_canonical = _BladeEventSchemaTestsCommit(
            _child,
            "instance.spawned",
            "outcome.defeat_child",
            _child.parent,
            _child.child
        );
        BladeKernelTestAssertTrue(
            string_pos("outcome.defeat_child", _child_canonical) > 0,
            "defeat-child relation committed"
        );

        var _reward = _BladeEventSchemaTestsFixture();
        var _reward_canonical = _BladeEventSchemaTestsCommit(
            _reward,
            "reward.requested",
            "outcome.defeated",
            _reward.parent,
            ""
        );
        BladeKernelTestAssertTrue(
            string_pos("reward.requested", _reward_canonical) > 0,
            "defeat reward relation committed"
        );
    });

    BladeKernelTestRunCase(_state, "combat event schema accepts every administrative boundary", function() {
        var _reasons = [
            "cleanup.stage_end",
            "cleanup.run_load",
            "cleanup.run_reset",
            "cleanup.run_aborted",
            "cleanup.run_completed",
            "cleanup.room_exit",
        ];
        for (var _index = 0; _index < array_length(_reasons); ++_index) {
            var _instance = _BladeEventSchemaTestsFixture();
            _BladeEventSchemaTestsCommit(
                _instance,
                "instance.removed",
                _reasons[_index],
                _instance.parent,
                ""
            );

            var _attack = _BladeEventSchemaTestsFixture();
            _BladeEventSchemaTestsCommit(
                _attack,
                "attack.cancelled",
                _reasons[_index],
                _attack.attack,
                ""
            );

            var _bullet = _BladeEventSchemaTestsFixture();
            _BladeEventSchemaTestsCommit(
                _bullet,
                "bullet.removed",
                _reasons[_index],
                _bullet.bullet,
                ""
            );

            var _damage = _BladeEventSchemaTestsFixture();
            _BladeEventSchemaTestsCommit(
                _damage,
                "damage.cancelled",
                _reasons[_index],
                _damage.damage,
                ""
            );
        }
    });

    BladeKernelTestRunCase(_state, "combat event schema rejects reason impersonation", function() {
        var _fixture = _BladeEventSchemaTestsFixture();
        var _log = BladeEventLogCreate(_fixture.identity);
        BladeEventLogBeginTick(_log, 1);
        var _context = {
            log: _log,
            fixture: _fixture,
        };
        BladeKernelTestAssertThrows(method(_context, function() {
            BladeEventLogQueue(
                self.log,
                BladeEventChannel.Gameplay,
                0,
                "reward.requested",
                "cleanup.run_reset",
                self.fixture.parent,
                "",
                self.fixture.owner,
                "encounter.fixture.combat",
                []
            );
        }), "unknown or invalid pair", "cleanup cannot impersonate a defeat reward");
        BladeKernelTestAssertEqual(
            BladeRunIdentityGetCounters(_fixture.identity).event,
            int64(0),
            "invalid pair consumes no event ID"
        );
    });
}
