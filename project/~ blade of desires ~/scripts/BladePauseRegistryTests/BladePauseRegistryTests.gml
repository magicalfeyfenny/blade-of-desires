/// @description Project-owned pause-registry unit and deterministic-kernel integration tests.

/// Rejects every content ID because pause tests use only run-local event-owner identities.
function _BladePauseTestsRejectContent(_content_id) {
    return false;
}

/// Creates one identity, three allocated owners, and an empty registry for an isolated case.
function _BladePauseTestsFixture() {
    var _identity = BladeRunIdentityCreate(method({}, _BladePauseTestsRejectContent));
    var _run_owner = BladeRunIdentityAllocate(_identity, BladeRunIdKind.EventOwner);
    var _owner_a = BladeRunIdentityAllocate(_identity, BladeRunIdKind.EventOwner);
    var _owner_b = BladeRunIdentityAllocate(_identity, BladeRunIdKind.EventOwner);
    return {
        identity: _identity,
        run_owner: _run_owner,
        owner_a: _owner_a,
        owner_b: _owner_b,
        registry: BladePauseRegistryCreate(_identity),
    };
}

/// Resolves a bound registry against its base mask before each kernel simulation tick.
function _BladePauseTestsEligibility(_counters) {
    return BladePauseRegistryResolveDomains(self.registry, self.requested_domains);
}

/// Counts only work whose resolved domain bit is present and records input edges for integration checks.
function _BladePauseTestsSimulate(_kernel, _snapshot, _tick) {
    if ((_tick.domain_mask & BladeClockDomain.Stage) != 0) {
        self.stage_work += int64(1);
    }
    if ((_tick.domain_mask & BladeClockDomain.Actor) != 0) {
        self.actor_work += int64(1);
    }
    if ((_tick.domain_mask & BladeClockDomain.Boss) != 0) {
        self.boss_work += int64(1);
    }
    if ((_tick.domain_mask & BladeClockDomain.Combat) != 0) {
        self.combat_work += int64(1);
    }
    var _input = BladeInputSnapshotRead(_snapshot);
    array_push(self.pressed_actions, _input.pressed_actions);
    return BladeCanonicalRecord("PTF2", [
        string(self.stage_work),
        string(self.actor_work),
        string(self.boss_work),
        string(self.combat_work),
    ]);
}

/// Adds all pause-registry cases to the shared project-owned result state.
function BladePauseRegistryTestsRun(_state) {
    BladeKernelTestRunCase(_state, "pause IDs records and snapshots are deterministic", function() {
        // Acquire equal records in independent fixtures and compare canonical bytes and detached views.
        var _left = _BladePauseTestsFixture();
        var _right = _BladePauseTestsFixture();
        var _left_token = BladePauseRegistryAcquire(
            _left.registry,
            _left.owner_a,
            "pause.menu",
            BladeClockDomain.Stage
                | BladeClockDomain.Actor
                | BladeClockDomain.Combat,
            12,
            BladePauseReleasePolicy.OwnerDestroyed
        );
        var _right_token = BladePauseRegistryAcquire(
            _right.registry,
            _right.owner_a,
            "pause.menu",
            BladeClockDomain.Stage
                | BladeClockDomain.Actor
                | BladeClockDomain.Combat,
            12,
            BladePauseReleasePolicy.OwnerDestroyed
        );
        BladeKernelTestAssertEqual(_left_token.token_id, "pau:1", "first pause ID");
        BladeKernelTestAssertEqual(
            _left_token.owner_id,
            _left.owner_a,
            "token owner"
        );
        BladeKernelTestAssertEqual(_left_token.reason, "pause.menu", "token reason");
        BladeKernelTestAssertEqual(
            _left_token.domains,
            BladeClockDomain.Stage | BladeClockDomain.Actor | BladeClockDomain.Combat,
            "Combat is a pausable gameplay domain"
        );
        BladeKernelTestAssertEqual(
            _left_token.acquisition_tick,
            int64(12),
            "token acquisition tick"
        );
        BladeKernelTestAssertEqual(
            BladePauseRegistryCanonical(_left.registry),
            BladePauseRegistryCanonical(_right.registry),
            "equal pause canonical state"
        );
        var _canonical = BladePauseRegistryCanonical(_left.registry);
        BladeKernelTestAssertEqual(
            string_copy(_canonical, 1, 4),
            "BPR2",
            "version 2 pause registry record"
        );
        BladeKernelTestAssertTrue(
            string_pos("BPT2", _canonical) > 0,
            "version 2 pause token record"
        );
        BladeKernelTestAssertEqual(
            _left_token.token_id,
            _right_token.token_id,
            "equal acquisition IDs"
        );

        _left_token.owner_id = "mutated";
        var _snapshot = BladePauseRegistrySnapshot(_left.registry);
        BladeKernelTestAssertEqual(
            _snapshot.active_tokens[0].owner_id,
            _left.owner_a,
            "returned token is detached"
        );
        _snapshot.active_tokens[0].reason = "mutated";
        _snapshot.diagnostics = ["mutated"];
        var _fresh = BladePauseRegistrySnapshot(_left.registry);
        BladeKernelTestAssertEqual(
            _fresh.active_tokens[0].reason,
            "pause.menu",
            "snapshot token is detached"
        );
        BladeKernelTestAssertEqual(
            array_length(_fresh.diagnostics),
            0,
            "snapshot diagnostics are detached"
        );
    });

    BladeKernelTestRunCase(_state, "invalid pause acquisition does not consume an ID", function() {
        // Exercise reason, domain, tick, policy, and owner validation before one valid acquisition.
        var _fixture = _BladePauseTestsFixture();
        var _context = { fixture: _fixture };
        BladeKernelTestAssertThrows(method(_context, function() {
            // Reject a display-like reason outside the canonical pause.* namespace.
            BladePauseRegistryAcquire(
                self.fixture.registry,
                self.fixture.owner_a,
                "Pause Menu",
                BladeClockDomain.Stage,
                0,
                BladePauseReleasePolicy.OwnerDestroyed
            );
        }), "reason", "invalid reason");
        BladeKernelTestAssertThrows(method(_context, function() {
            // Reject a zero mask because a token must freeze at least one simulation domain.
            BladePauseRegistryAcquire(
                self.fixture.registry,
                self.fixture.owner_a,
                "pause.menu",
                BladeClockDomain.None,
                0,
                BladePauseReleasePolicy.OwnerDestroyed
            );
        }), "at least one", "zero domain mask");
        BladeKernelTestAssertThrows(method(_context, function() {
            // Reject Presentation because the kernel advances it once per outer update.
            BladePauseRegistryAcquire(
                self.fixture.registry,
                self.fixture.owner_a,
                "pause.menu",
                BladeClockDomain.Presentation,
                0,
                BladePauseReleasePolicy.OwnerDestroyed
            );
        }), "Stage, Actor, Boss, and Combat", "presentation pause mask");
        BladeKernelTestAssertThrows(method(_context, function() {
            // Reject a negative acquisition tick before the token frontier changes.
            BladePauseRegistryAcquire(
                self.fixture.registry,
                self.fixture.owner_a,
                "pause.menu",
                BladeClockDomain.Stage,
                -1,
                BladePauseReleasePolicy.OwnerDestroyed
            );
        }), "acquisition tick", "negative acquisition tick");
        BladeKernelTestAssertThrows(method(_context, function() {
            // Reject an enum value outside the closed release-policy range.
            BladePauseRegistryAcquire(
                self.fixture.registry,
                self.fixture.owner_a,
                "pause.menu",
                BladeClockDomain.Stage,
                0,
                99
            );
        }), "pause release policy", "unknown release policy");
        BladeKernelTestAssertThrows(method(_context, function() {
            // Reject a canonical-looking owner that the shared identity has not allocated.
            BladePauseRegistryAcquire(
                self.fixture.registry,
                "own:99",
                "pause.menu",
                BladeClockDomain.Stage,
                0,
                BladePauseReleasePolicy.OwnerDestroyed
            );
        }), "unallocated", "unallocated owner");

        var _valid = BladePauseRegistryAcquire(
            _fixture.registry,
            _fixture.owner_a,
            "pause.menu",
            BladeClockDomain.Stage,
            0,
            BladePauseReleasePolicy.OwnerDestroyed
        );
        BladeKernelTestAssertEqual(
            _valid.token_id,
            "pau:1",
            "failed acquisitions leave the first ID available"
        );
    });

    BladeKernelTestRunCase(_state, "overlapping pause owners release independently", function() {
        // Freeze Stage twice, then prove each owner can remove only its own contribution.
        var _fixture = _BladePauseTestsFixture();
        var _first = BladePauseRegistryAcquire(
            _fixture.registry,
            _fixture.owner_a,
            "pause.menu",
            BladeClockDomain.Stage
                | BladeClockDomain.Actor
                | BladeClockDomain.Combat,
            0,
            BladePauseReleasePolicy.OwnerDestroyed
        );
        var _second = BladePauseRegistryAcquire(
            _fixture.registry,
            _fixture.owner_b,
            "pause.dialogue",
            BladeClockDomain.Stage,
            0,
            BladePauseReleasePolicy.OwnerDestroyed
        );
        BladeKernelTestAssertEqual(
            BladePauseRegistryFrozenDomains(_fixture.registry),
            BladeClockDomain.Stage
                | BladeClockDomain.Actor
                | BladeClockDomain.Combat,
            "overlapping frozen union"
        );
        BladeKernelTestAssertEqual(
            BladePauseRegistryResolveDomains(_fixture.registry, BladeClockDomain.All),
            BladeClockDomain.Boss | BladeClockDomain.Presentation,
            "only unfrozen base domains remain"
        );

        var _wrong_owner = BladePauseRegistryRelease(
            _fixture.registry,
            _fixture.owner_b,
            _first.token_id,
            1
        );
        BladeKernelTestAssertFalse(_wrong_owner.released, "wrong owner release result");
        BladeKernelTestAssertEqual(
            _wrong_owner.diagnostic.code,
            "pause.release_owner_mismatch",
            "wrong owner diagnostic"
        );
        BladeKernelTestAssertEqual(
            BladePauseRegistryFrozenDomains(_fixture.registry),
            BladeClockDomain.Stage
                | BladeClockDomain.Actor
                | BladeClockDomain.Combat,
            "wrong owner leaves token active"
        );

        BladeKernelTestAssertTrue(
            BladePauseRegistryRelease(
                _fixture.registry,
                _fixture.owner_a,
                _first.token_id,
                1
            ).released,
            "first owner releases its token"
        );
        BladeKernelTestAssertEqual(
            BladePauseRegistryFrozenDomains(_fixture.registry),
            BladeClockDomain.Stage,
            "second owner still freezes Stage"
        );
        BladeKernelTestAssertEqual(
            BladePauseRegistryResolveDomains(_fixture.registry, BladeClockDomain.All),
            BladeClockDomain.Actor
                | BladeClockDomain.Boss
                | BladeClockDomain.Presentation
                | BladeClockDomain.Combat,
            "Actor and Combat resume while Stage stays frozen"
        );
        BladePauseRegistryRelease(
            _fixture.registry,
            _fixture.owner_b,
            _second.token_id,
            1
        );
        BladeKernelTestAssertEqual(
            BladePauseRegistryResolveDomains(_fixture.registry, BladeClockDomain.All),
            BladeClockDomain.All,
            "final release restores base eligibility"
        );

        var _unknown = BladePauseRegistryRelease(
            _fixture.registry,
            _fixture.owner_b,
            _second.token_id,
            2
        );
        BladeKernelTestAssertEqual(
            _unknown.diagnostic.code,
            "pause.unknown_release",
            "double release diagnostic"
        );
        BladeKernelTestAssertEqual(
            BladePauseRegistryFrozenDomains(_fixture.registry),
            BladeClockDomain.None,
            "unknown release cannot freeze or resume a domain"
        );
    });

    BladeKernelTestRunCase(_state, "pause commands reject pre-acquisition observations atomically", function() {
        // Keep one canonical baseline while every known-token and boundary path rejects time travel.
        var _fixture = _BladePauseTestsFixture();
        var _token = BladePauseRegistryAcquire(
            _fixture.registry,
            _fixture.owner_a,
            "pause.temporal_guard",
            BladeClockDomain.Stage,
            5,
            BladePauseReleasePolicy.Explicit
        );
        BladePauseRegistryAcquire(
            _fixture.registry,
            _fixture.owner_b,
            "pause.temporal_guard_other",
            BladeClockDomain.Actor,
            6,
            BladePauseReleasePolicy.OwnerDestroyed
        );
        var _canonical = BladePauseRegistryCanonical(_fixture.registry);
        var _context = { fixture: _fixture, token: _token };

        BladeKernelTestAssertThrows(method(_context, function() {
            // A known-token release cannot precede acquisition even for its owner.
            BladePauseRegistryRelease(
                self.fixture.registry, self.fixture.owner_a, self.token.token_id, 4
            );
        }), "observed tick", "release chronology");
        BladeKernelTestAssertEqual(
            BladePauseRegistryCanonical(_fixture.registry),
            _canonical,
            "failed release leaves canonical state unchanged"
        );
        BladeKernelTestAssertThrows(method(_context, function() {
            // Transfer chronology is checked before token ownership can change.
            BladePauseRegistryTransfer(
                self.fixture.registry, self.fixture.owner_a, self.token.token_id,
                self.fixture.run_owner, BladePauseReleasePolicy.RunBoundary, 4
            );
        }), "observed tick", "transfer chronology");
        BladeKernelTestAssertThrows(method(_context, function() {
            // Owner cleanup also preflights a later token retained for another owner.
            BladePauseRegistryOwnerDestroyed(
                self.fixture.registry, self.fixture.owner_a, 5
            );
        }), "observed tick", "owner cleanup chronology");
        BladeKernelTestAssertThrows(method(_context, function() {
            // Room exit preflights both released and retained token candidates.
            BladePauseRegistryRoomExit(
                self.fixture.registry, self.fixture.run_owner, 4
            );
        }), "observed tick", "room exit chronology");
        BladeKernelTestAssertThrows(method(_context, function() {
            // Run replacement preflights every active token before cleanup diagnostics.
            BladePauseRegistryRunBoundary(
                self.fixture.registry, BladePauseRunBoundary.Reset, 4
            );
        }), "observed tick", "run boundary chronology");
        BladeKernelTestAssertEqual(
            BladePauseRegistryCanonical(_fixture.registry),
            _canonical,
            "all failed temporal boundaries leave canonical state unchanged"
        );
    });

    BladeKernelTestRunCase(_state, "owner cleanup diagnoses missing transfers", function() {
        // Destroy one owner with both owner-lifetime and longer-lived tokens while another owner remains.
        var _fixture = _BladePauseTestsFixture();
        BladePauseRegistryAcquire(
            _fixture.registry,
            _fixture.owner_a,
            "pause.dialogue",
            BladeClockDomain.Actor,
            3,
            BladePauseReleasePolicy.OwnerDestroyed
        );
        var _leaked = BladePauseRegistryAcquire(
            _fixture.registry,
            _fixture.owner_a,
            "pause.transition",
            BladeClockDomain.Stage,
            3,
            BladePauseReleasePolicy.RoomExit
        );
        BladePauseRegistryAcquire(
            _fixture.registry,
            _fixture.owner_b,
            "pause.continue",
            BladeClockDomain.Boss,
            3,
            BladePauseReleasePolicy.OwnerDestroyed
        );

        var _report = BladePauseRegistryOwnerDestroyed(
            _fixture.registry,
            _fixture.owner_a,
            4
        );
        BladeKernelTestAssertEqual(
            array_length(_report.released_tokens),
            2,
            "destroyed owner releases two tokens"
        );
        BladeKernelTestAssertEqual(
            array_length(_report.retained_tokens),
            1,
            "other owner token remains"
        );
        BladeKernelTestAssertEqual(
            array_length(_report.diagnostics),
            1,
            "missing transfer emits one leak"
        );
        BladeKernelTestAssertEqual(
            _report.diagnostics[0].code,
            "pause.leaked_token",
            "owner cleanup leak code"
        );
        BladeKernelTestAssertEqual(
            _report.diagnostics[0].token_id,
            _leaked.token_id,
            "leak identifies longer-lived token"
        );
        BladeKernelTestAssertEqual(
            _report.diagnostics[0].boundary,
            "owner.destroyed",
            "owner cleanup boundary"
        );
        BladeKernelTestAssertEqual(
            BladePauseRegistryFrozenDomains(_fixture.registry),
            BladeClockDomain.Boss,
            "other owner still freezes Boss"
        );
    });

    BladeKernelTestRunCase(_state, "room exit retains only transferred run tokens", function() {
        // Transfer one token to the run owner and leave another run token orphaned at room exit.
        var _fixture = _BladePauseTestsFixture();
        var _transferred = BladePauseRegistryAcquire(
            _fixture.registry,
            _fixture.owner_a,
            "pause.run_transition",
            BladeClockDomain.Stage,
            5,
            BladePauseReleasePolicy.RoomExit
        );
        var _orphan = BladePauseRegistryAcquire(
            _fixture.registry,
            _fixture.owner_b,
            "pause.orphaned_transition",
            BladeClockDomain.Actor,
            5,
            BladePauseReleasePolicy.RunBoundary
        );
        var _room_token = BladePauseRegistryAcquire(
            _fixture.registry,
            _fixture.owner_a,
            "pause.room_transition",
            BladeClockDomain.Boss,
            5,
            BladePauseReleasePolicy.RoomExit
        );
        var _transfer = BladePauseRegistryTransfer(
            _fixture.registry,
            _fixture.owner_a,
            _transferred.token_id,
            _fixture.run_owner,
            BladePauseReleasePolicy.RunBoundary,
            6
        );
        BladeKernelTestAssertTrue(_transfer.transferred, "run-owner transfer succeeds");
        BladeKernelTestAssertEqual(
            _transfer.token.acquisition_tick,
            int64(5),
            "transfer preserves acquisition tick"
        );

        var _room = BladePauseRegistryRoomExit(
            _fixture.registry,
            _fixture.run_owner,
            6
        );
        BladeKernelTestAssertEqual(
            array_length(_room.retained_tokens),
            1,
            "transferred run token survives room exit"
        );
        BladeKernelTestAssertEqual(
            _room.retained_tokens[0].token_id,
            _transferred.token_id,
            "retained token identity"
        );
        BladeKernelTestAssertEqual(
            array_length(_room.released_tokens),
            2,
            "room and untransferred run tokens are released"
        );
        BladeKernelTestAssertEqual(
            _room.released_tokens[1].token_id,
            _room_token.token_id,
            "room-lifetime token releases without a leak"
        );
        BladeKernelTestAssertEqual(
            _room.diagnostics[0].token_id,
            _orphan.token_id,
            "room leak identifies orphan token"
        );
        BladeKernelTestAssertEqual(
            _room.diagnostics[0].boundary,
            "room.exit",
            "room leak boundary"
        );

        var _abort = BladePauseRegistryRunBoundary(
            _fixture.registry,
            BladePauseRunBoundary.Aborted,
            7
        );
        BladeKernelTestAssertEqual(
            array_length(_abort.released_tokens),
            1,
            "abort releases surviving run token"
        );
        BladeKernelTestAssertEqual(
            array_length(_abort.diagnostics),
            0,
            "declared run-boundary release is not a leak"
        );
        BladeKernelTestAssertEqual(
            BladePauseRegistryFrozenDomains(_fixture.registry),
            BladeClockDomain.None,
            "abort clears all pause domains"
        );
    });

    BladeKernelTestRunCase(_state, "run reset reports explicit leaks and fresh registries restart IDs", function() {
        // Clean the old registry at reset, then construct the independently validated replacement state.
        var _old = _BladePauseTestsFixture();
        var _explicit = BladePauseRegistryAcquire(
            _old.registry,
            _old.owner_a,
            "pause.test",
            BladeClockDomain.Stage,
            8,
            BladePauseReleasePolicy.Explicit
        );
        BladePauseRegistryAcquire(
            _old.registry,
            _old.owner_b,
            "pause.menu",
            BladeClockDomain.Actor,
            8,
            BladePauseReleasePolicy.OwnerDestroyed
        );
        var _reset = BladePauseRegistryRunBoundary(
            _old.registry,
            BladePauseRunBoundary.Reset,
            9
        );
        BladeKernelTestAssertEqual(
            array_length(_reset.released_tokens),
            2,
            "reset releases every old token"
        );
        BladeKernelTestAssertEqual(
            array_length(_reset.diagnostics),
            1,
            "reset reports one explicit leak"
        );
        BladeKernelTestAssertEqual(
            _reset.diagnostics[0].token_id,
            _explicit.token_id,
            "explicit leak token"
        );
        BladeKernelTestAssertEqual(
            _reset.diagnostics[0].boundary,
            "run.reset",
            "reset diagnostic boundary"
        );

        var _fresh = _BladePauseTestsFixture();
        var _fresh_token = BladePauseRegistryAcquire(
            _fresh.registry,
            _fresh.owner_a,
            "pause.menu",
            BladeClockDomain.Stage,
            0,
            BladePauseReleasePolicy.OwnerDestroyed
        );
        BladeKernelTestAssertEqual(
            _fresh_token.token_id,
            "pau:1",
            "replacement registry restarts deterministic IDs"
        );
        var _load = BladePauseRegistryRunBoundary(
            _fresh.registry,
            BladePauseRunBoundary.Load,
            0
        );
        BladeKernelTestAssertEqual(_load.boundary, "run.load", "load boundary code");
        BladeKernelTestAssertEqual(
            array_length(_load.released_tokens),
            1,
            "committed run load clears the prior registry"
        );
        BladeKernelTestAssertEqual(
            BladePauseRegistryFrozenDomains(_fresh.registry),
            BladeClockDomain.None,
            "run load leaves no active pause domains"
        );
    });

    BladeKernelTestRunCase(_state, "pause resolver freezes simulation while presentation advances", function() {
        // Drive three kernel updates through overlapping pause masks and count resolved work.
        var _kernel = BladeDeterministicKernelCreate(
            "sha1:d9a345101d9fa9971924bb2b9138a39dd5fd7c0b",
            305419896,
            method({}, _BladePauseTestsRejectContent),
            8
        );
        var _owner_a = BladeKernelAllocate(_kernel, BladeRunIdKind.EventOwner);
        var _owner_b = BladeKernelAllocate(_kernel, BladeRunIdKind.EventOwner);
        var _registry = BladePauseRegistryCreate(_kernel.identity);
        var _first = BladePauseRegistryAcquire(
            _registry,
            _owner_a,
            "pause.menu",
            BladeClockDomain.Stage
                | BladeClockDomain.Actor
                | BladeClockDomain.Combat,
            0,
            BladePauseReleasePolicy.OwnerDestroyed
        );
        var _second = BladePauseRegistryAcquire(
            _registry,
            _owner_b,
            "pause.dialogue",
            BladeClockDomain.Stage,
            0,
            BladePauseReleasePolicy.OwnerDestroyed
        );
        var _eligibility = method({
            registry: _registry,
            requested_domains: BladeClockDomain.All,
        }, _BladePauseTestsEligibility);
        var _work = {
            stage_work: int64(0),
            actor_work: int64(0),
            boss_work: int64(0),
            combat_work: int64(0),
            pressed_actions: [],
        };
        var _simulate = method(_work, _BladePauseTestsSimulate);
        var _raw = BladeInputRawStateCreate(
            0,
            0,
            BladeInputAction.Fire,
            BladePromptDevice.KeyboardMouse,
            false,
            0,
            0
        );

        var _paused = BladeKernelAdvancePresentation(
            _kernel,
            16667,
            _raw,
            _eligibility,
            _simulate
        );
        BladeKernelTestAssertEqual(
            _paused.counters.simulation_tick,
            int64(1),
            "master simulation still executes"
        );
        BladeKernelTestAssertEqual(_paused.counters.stage_tick, int64(0), "Stage frozen");
        BladeKernelTestAssertEqual(_paused.counters.actor_tick, int64(0), "Actor frozen");
        BladeKernelTestAssertEqual(_paused.counters.boss_tick, int64(1), "Boss permitted");
        BladeKernelTestAssertEqual(_paused.counters.combat_tick, int64(0), "Combat frozen");
        BladeKernelTestAssertEqual(
            _paused.counters.presentation_tick,
            int64(1),
            "presentation advances while simulation domains freeze"
        );
        BladeKernelTestAssertEqual(_work.stage_work, int64(0), "no Stage work");
        BladeKernelTestAssertEqual(_work.actor_work, int64(0), "no Actor work");
        BladeKernelTestAssertEqual(_work.boss_work, int64(1), "permitted Boss work");
        BladeKernelTestAssertEqual(_work.combat_work, int64(0), "no Combat work");

        BladePauseRegistryRelease(_registry, _owner_a, _first.token_id, 1);
        var _actor_resumed = BladeKernelAdvancePresentation(
            _kernel,
            16667,
            _raw,
            _eligibility,
            _simulate
        );
        BladeKernelTestAssertEqual(
            _actor_resumed.counters.stage_tick,
            int64(0),
            "overlapping owner keeps Stage frozen"
        );
        BladeKernelTestAssertEqual(
            _actor_resumed.counters.actor_tick,
            int64(1),
            "Actor resumes after its only token releases"
        );
        BladeKernelTestAssertEqual(
            _actor_resumed.counters.combat_tick,
            int64(1),
            "Combat resumes after its only token releases"
        );
        BladeKernelTestAssertEqual(
            _actor_resumed.counters.presentation_tick,
            int64(2),
            "second presentation update"
        );

        BladePauseRegistryRelease(_registry, _owner_b, _second.token_id, 2);
        var _resumed = BladeKernelAdvancePresentation(
            _kernel,
            16667,
            _raw,
            _eligibility,
            _simulate
        );
        BladeKernelTestAssertEqual(_resumed.counters.stage_tick, int64(1), "Stage resumes");
        BladeKernelTestAssertEqual(_resumed.counters.actor_tick, int64(2), "Actor continues");
        BladeKernelTestAssertEqual(_resumed.counters.boss_tick, int64(3), "Boss continues");
        BladeKernelTestAssertEqual(_resumed.counters.combat_tick, int64(2), "Combat continues");
        BladeKernelTestAssertEqual(
            _resumed.counters.presentation_tick,
            int64(3),
            "presentation advances on every outer update"
        );
        BladeKernelTestAssertArrayEqual(
            _work.pressed_actions,
            [int64(0), int64(BladeInputAction.Fire), int64(0)],
            "Actor pause retains one input edge until resume"
        );
    });
}
