/// @description Tests for selectable Stage 1 difficulty and attempt-local rank.

function _BladeDifficultyRankTestIdsAndProfiles() {
    var _ids = BladeDifficultyIds();
    BladeKernelTestAssertEqual(array_length(_ids), 3, "three playable difficulty IDs");
    BladeKernelTestAssertEqual(_ids[0], "difficulty.easy", "Easy ID is canonical");
    BladeKernelTestAssertEqual(_ids[1], "difficulty.normal", "Normal ID is canonical");
    BladeKernelTestAssertEqual(_ids[2], "difficulty.hard", "Hard ID is canonical");
    BladeKernelTestAssertEqual(BladeDifficultyPlayerName(_ids[0]), "Easy", "Easy label");
    BladeKernelTestAssertEqual(BladeDifficultyPlayerName(_ids[1]), "Normal", "Normal label");
    BladeKernelTestAssertEqual(BladeDifficultyPlayerName(_ids[2]), "Hard", "Hard label");
    BladeKernelTestAssertEqual(
        BladeDifficultyProfile(_ids[1]).hostile_speed_per_mille,
        1000,
        "Normal pressure baseline"
    );
    BladeKernelTestAssertThrows(
        method({}, function() {
            BladeDifficultyProfile("stage.extra.dreams_of_a_clockwork_angel");
        }),
        "three playable difficulty IDs",
        "the extra stage ID is not a difficulty"
    );
}

function _BladeDifficultyRankTestMappings() {
    var _normal_speed = BladeDifficultyHostileBulletSpeed(
        2, BLADE_DIFFICULTY_NORMAL_ID, 0
    );
    BladeKernelTestAssertTrue(
        abs(_normal_speed - 2) < 0.001,
        "Normal rank zero preserves authored bullet speed"
    );
    BladeKernelTestAssertTrue(
        BladeDifficultyHostileBulletSpeed(2, BLADE_DIFFICULTY_EASY_ID, 0)
            < _normal_speed,
        "Easy bullet speed is lower"
    );
    BladeKernelTestAssertTrue(
        _normal_speed < BladeDifficultyHostileBulletSpeed(
            2, BLADE_DIFFICULTY_HARD_ID, 0
        ),
        "Hard bullet speed is higher"
    );
    var _rank_zero = BladeDifficultyHostileBulletSpeed(
        2, BLADE_DIFFICULTY_NORMAL_ID, 0
    );
    var _rank_mid = BladeDifficultyHostileBulletSpeed(
        2, BLADE_DIFFICULTY_NORMAL_ID, 25
    );
    var _rank_max = BladeDifficultyHostileBulletSpeed(
        2, BLADE_DIFFICULTY_NORMAL_ID, 50
    );
    BladeKernelTestAssertTrue(_rank_zero < _rank_mid, "rank raises bullet speed");
    BladeKernelTestAssertTrue(_rank_mid < _rank_max, "rank 50 raises bullet speed");
    BladeKernelTestAssertTrue(
        BladeDifficultyHostileFireRate(BLADE_DIFFICULTY_NORMAL_ID, 0)
            < BladeDifficultyHostileFireRate(BLADE_DIFFICULTY_NORMAL_ID, 50),
        "rank raises hostile fire rate"
    );
    BladeKernelTestAssertTrue(
        BladeDifficultyHostileFireInterval(120, BLADE_DIFFICULTY_EASY_ID, 0)
            > BladeDifficultyHostileFireInterval(120, BLADE_DIFFICULTY_NORMAL_ID, 0),
        "Easy emitter interval is longer"
    );
    BladeKernelTestAssertTrue(
        BladeDifficultyHostileFireInterval(120, BLADE_DIFFICULTY_HARD_ID, 0)
            < BladeDifficultyHostileFireInterval(120, BLADE_DIFFICULTY_NORMAL_ID, 0),
        "Hard emitter interval is shorter"
    );
    BladeKernelTestAssertEqual(
        BladeDifficultyRewardValue(1000, BLADE_DIFFICULTY_NORMAL_ID, 0),
        1000,
        "Normal rank zero preserves authored reward"
    );
    BladeKernelTestAssertTrue(
        BladeDifficultyRewardValue(1000, BLADE_DIFFICULTY_EASY_ID, 0)
            < BladeDifficultyRewardValue(1000, BLADE_DIFFICULTY_NORMAL_ID, 0),
        "Easy reward is lower"
    );
    BladeKernelTestAssertTrue(
        BladeDifficultyRewardValue(1000, BLADE_DIFFICULTY_NORMAL_ID, 0)
            < BladeDifficultyRewardValue(1000, BLADE_DIFFICULTY_HARD_ID, 0),
        "Hard reward is higher"
    );
    BladeKernelTestAssertTrue(
        BladeDifficultyRewardValue(1000, BLADE_DIFFICULTY_NORMAL_ID, 25)
            < BladeDifficultyRewardValue(1000, BLADE_DIFFICULTY_NORMAL_ID, 50),
        "rank raises reward value"
    );
    BladeKernelTestAssertTrue(
        BladeDifficultyEnemyHealth(80, BLADE_DIFFICULTY_EASY_ID, 50)
            < BladeDifficultyEnemyHealth(80, BLADE_DIFFICULTY_HARD_ID, 0),
        "difficulty health tuning is independent of rank pressure"
    );
    BladeKernelTestAssertEqual(
        BladeDifficultyPressureHash(BLADE_DIFFICULTY_NORMAL_ID, 25),
        BladeDifficultyPressureHash(BLADE_DIFFICULTY_NORMAL_ID, 25),
        "pressure snapshot hash is stable"
    );
    BladeKernelTestAssertTrue(
        BladeDifficultyPressureHash(BLADE_DIFFICULTY_NORMAL_ID, 25)
            != BladeDifficultyPressureHash(BLADE_DIFFICULTY_NORMAL_ID, 26),
        "pressure snapshot hash includes rank"
    );
}

function _BladeDifficultyRankTestStateAndOrdering() {
    var _state = BladeDifficultyRankStateCreate();
    BladeKernelTestAssertEqual(_state.value, 0, "rank starts at zero");
    for (var _tick = 0; _tick < BLADE_DIFFICULTY_RANK_ACTIVE_PERIOD - 1; ++_tick) {
        var _quiet = BladeDifficultyRankAdvanceActive(_state, _tick);
        BladeKernelTestAssertFalse(_quiet.advanced, "active rank waits for its period");
    }
    var _active = BladeDifficultyRankAdvanceActive(
        _state, BLADE_DIFFICULTY_RANK_ACTIVE_PERIOD - 1
    );
    BladeKernelTestAssertTrue(_active.advanced, "active play raises rank periodically");
    BladeKernelTestAssertEqual(_state.value, 1, "active play delta is one");
    var _hyper = BladeDifficultyRankApplyReason(
        _state, BladeDifficultyRankReason.NormalHyper, 29
    );
    var _bomb = BladeDifficultyRankApplyReason(
        _state, BladeDifficultyRankReason.NormalBomb, 29
    );
    BladeKernelTestAssertEqual(_hyper.after, 5, "Normal Hyper raises rank once");
    BladeKernelTestAssertEqual(_bomb.after, 0, "Normal Bomb lowers and clamps rank");
    BladeKernelTestAssertEqual(array_length(_state.events), 3, "each rank action is logged once");
    BladeKernelTestAssertThrows(
        method({ rank_state: _state }, function() {
            BladeDifficultyRankApplyReason(
                self.rank_state,
                BladeDifficultyRankReason.ActivePlay,
                29
            );
        }),
        "earlier priority",
        "same-tick ordering rejects a late active event"
    );
    var _same_sequence = BladeDifficultyRankStateCreate();
    BladeDifficultyRankApplyReason(
        _same_sequence, BladeDifficultyRankReason.NormalHyper, 0
    );
    BladeDifficultyRankApplyReason(
        _same_sequence, BladeDifficultyRankReason.DeathBombHyper, 0
    );
    BladeKernelTestAssertEqual(
        _same_sequence.value, 0,
        "death-bomb Hyper lowers its rank once after its ordered action"
    );
    BladeKernelTestAssertThrows(
        method({ rank_state: _same_sequence }, function() {
            BladeDifficultyRankApplyReason(
                self.rank_state,
                BladeDifficultyRankReason.LifeLoss,
                -1
            );
        }),
        "between 0 and",
        "rank events reject negative ticks"
    );
    var _high = BladeDifficultyRankStateCreate();
    for (var _event_index = 0; _event_index < 13; ++_event_index) {
        BladeDifficultyRankApplyReason(
            _high, BladeDifficultyRankReason.NormalHyper, _event_index
        );
    }
    BladeKernelTestAssertEqual(_high.value, 50, "rank clamps at fifty");
    BladeKernelTestAssertTrue(_high.events[12].clamped, "upper clamp is recorded");
    BladeDifficultyRankApplyReason(_high, BladeDifficultyRankReason.LifeLoss, 13);
    BladeKernelTestAssertEqual(_high.value, 40, "life loss lowers rank once");
}

function _BladeDifficultyRankTestCanonicalDeterminism() {
    var _left = BladeDifficultyRankStateCreate();
    var _right = BladeDifficultyRankStateCreate();
    for (var _index = 0; _index < 30; ++_index) {
        BladeDifficultyRankAdvanceActive(_left, _index);
        BladeDifficultyRankAdvanceActive(_right, _index);
    }
    BladeDifficultyRankApplyReason(
        _left, BladeDifficultyRankReason.NormalHyper, 30
    );
    BladeDifficultyRankApplyReason(
        _right, BladeDifficultyRankReason.NormalHyper, 30
    );
    BladeKernelTestAssertEqual(
        BladeDifficultyRankHash(_left), BladeDifficultyRankHash(_right),
        "identical rank event streams hash identically"
    );
    BladeDifficultyRankApplyReason(
        _right, BladeDifficultyRankReason.NormalBomb, 31
    );
    BladeKernelTestAssertTrue(
        BladeDifficultyRankHash(_left) != BladeDifficultyRankHash(_right),
        "rank event streams affect their canonical hash"
    );
}

function _BladeDifficultyRankTestRaiseTo(_economy, _target_rank) {
    if (_target_rank == 0) return;
    if (_target_rank == 25) {
        for (var _index = 0; _index < 6; ++_index) {
            BladeDifficultyRankApplyReason(
                _economy.rank_state,
                BladeDifficultyRankReason.NormalHyper,
                _index
            );
        }
        BladeDifficultyRankApplyReason(
            _economy.rank_state, BladeDifficultyRankReason.ActivePlay, 6
        );
        return;
    }
    for (var _max_index = 0; _max_index < 13; ++_max_index) {
        BladeDifficultyRankApplyReason(
            _economy.rank_state,
            BladeDifficultyRankReason.NormalHyper,
            _max_index
        );
    }
}

// Covers every currently playable ship/difficulty pair at three rank snapshots.
function _BladeDifficultyRankTestAllStage1Combinations() {
    var _catalog = BladeShipSelectionLoad();
    var _ids = BladeDifficultyIds();
    var _controller = instance_create_layer(
        0, 0, "Instances", o_blade_first_beat_controller
    );
    for (var _ship_index = 0; _ship_index < array_length(_catalog.entries); ++_ship_index) {
        var _ship_id = _catalog.entries[_ship_index].ship_id;
        for (var _difficulty_index = 0;
            _difficulty_index < array_length(_ids); ++_difficulty_index) {
            var _difficulty_id = _ids[_difficulty_index];
            var _run = BladeShipSelectionCreateRun(
                _catalog, _ship_id, _difficulty_id
            );
            var _validated = BladeShipSelectionRequireRun(_catalog, _run);
            BladeKernelTestAssertEqual(
                _validated.difficulty_id, _difficulty_id,
                "all nine Stage 1 choices retain difficulty"
            );
            BladeKernelTestAssertTrue(
                _validated.midboss_ship_ids[0] != _ship_id
                    && _validated.midboss_ship_ids[1] != _ship_id,
                "selected ship is excluded from its midboss pair"
            );
            for (var _rank_index = 0; _rank_index < 3; ++_rank_index) {
                var _rank = _rank_index == 0 ? 0 : (_rank_index == 1 ? 25 : 50);
                _controller.economy = BladeSurvivalEconomyCreate(_difficulty_id);
                _BladeDifficultyRankTestRaiseTo(_controller.economy, _rank);
                var _member = instance_create_layer(
                    320, 80, "Instances", o_blade_stage1_fae_midboss
                );
                var _role = _validated.midboss_ship_ids[0] == "ship.ciela"
                    ? BladeStage1FaeRole.Ciela
                    : (_validated.midboss_ship_ids[0] == "ship.maynii"
                        ? BladeStage1FaeRole.Maynii
                        : BladeStage1FaeRole.Kolar);
                BladeStage1MidbossRegister(
                    _controller,
                    _member,
                    _role,
                    BladeStage1MidbossStandardPatternId(_role)
                );
                BladeKernelTestAssertEqual(
                    _member.max_health,
                    BladeDifficultyEnemyHealth(
                        BLADE_STAGE1_MIDBOSS_PERSONAL_HP,
                        _difficulty_id,
                        _rank
                    ),
                    "midboss uses selected difficulty health"
                );
                with (_member) instance_destroy();
            }
        }
    }
    with (_controller) instance_destroy();
}

function _BladeDifficultyRankTestNonGameplayGate() {
    var _controller = instance_create_layer(
        0, 0, "Instances", o_blade_first_beat_controller
    );
    var _enemy = instance_create_layer(
        320, 72, "Instances", o_blade_first_beat_enemy
    );
    _controller.economy = BladeSurvivalEconomyCreate(BLADE_DIFFICULTY_NORMAL_ID);
    BladeKernelTestAssertTrue(
        BladeDifficultyRankGameplayEligible(_controller),
        "live target permits active rank"
    );
    _controller.player_phase = BladeSurvivalPlayerPhase.HitResponse;
    BladeKernelTestAssertFalse(
        BladeDifficultyRankGameplayEligible(_controller),
        "hit response cannot passively raise rank"
    );
    _controller.player_phase = BladeSurvivalPlayerPhase.Respawning;
    BladeKernelTestAssertFalse(
        BladeDifficultyRankGameplayEligible(_controller),
        "respawn cannot passively raise rank"
    );
    _controller.player_phase = BladeSurvivalPlayerPhase.Active;
    _controller.state = BladeFirstBeatState.Rewarding;
    BladeKernelTestAssertFalse(
        BladeDifficultyRankGameplayEligible(_controller),
        "results cannot passively raise rank"
    );
    _controller.state = BladeFirstBeatState.Playing;
    _controller.boss_warning_active = true;
    BladeKernelTestAssertFalse(
        BladeDifficultyRankGameplayEligible(_controller),
        "boss warning cannot passively raise rank"
    );
    with (_enemy) instance_destroy();
    with (_controller) instance_destroy();
}

/// @func BladeDifficultyRankTestsRun(state)
/// Registers difficulty and rank cases on the project-owned runner.
function BladeDifficultyRankTestsRun(_state) {
    BladeKernelTestRunCase(_state, "difficulty identities and profiles", function() {
        _BladeDifficultyRankTestIdsAndProfiles();
    });
    BladeKernelTestRunCase(_state, "difficulty and rank mappings", function() {
        _BladeDifficultyRankTestMappings();
    });
    BladeKernelTestRunCase(_state, "rank state ordering and clamps", function() {
        _BladeDifficultyRankTestStateAndOrdering();
    });
    BladeKernelTestRunCase(_state, "rank canonical state is deterministic", function() {
        _BladeDifficultyRankTestCanonicalDeterminism();
    });
    BladeKernelTestRunCase(_state, "all Stage 1 ship and difficulty combinations tune midbosses", function() {
        _BladeDifficultyRankTestAllStage1Combinations();
    });
    BladeKernelTestRunCase(_state, "rank advances only during active play", function() {
        _BladeDifficultyRankTestNonGameplayGate();
    });
    return _state;
}
