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
    BladeKernelTestAssertEqual(
        BladeDifficultyProfile(_ids[0]).enemy_health_per_mille,
        1000,
        "Easy preserves authored enemy health"
    );
    BladeKernelTestAssertEqual(
        BladeDifficultyProfile(_ids[2]).enemy_health_per_mille,
        1000,
        "Hard preserves authored enemy health"
    );
    BladeKernelTestAssertTrue(
        BladeDifficultyProfile(_ids[0]).hostile_density_per_mille
            < BladeDifficultyProfile(_ids[1]).hostile_density_per_mille
            && BladeDifficultyProfile(_ids[1]).hostile_density_per_mille
                < BladeDifficultyProfile(_ids[2]).hostile_density_per_mille,
        "difficulty changes authored hostile density"
    );
    var _easy_bounds = BladeDifficultyRankBounds(_ids[0]);
    var _normal_bounds = BladeDifficultyRankBounds(_ids[1]);
    var _hard_bounds = BladeDifficultyRankBounds(_ids[2]);
    BladeKernelTestAssertEqual(_easy_bounds.minimum, 0, "Easy rank starts at zero");
    BladeKernelTestAssertEqual(_easy_bounds.maximum, 25, "Easy rank caps at twenty-five");
    BladeKernelTestAssertEqual(_normal_bounds.maximum, 50, "Normal rank caps at fifty");
    BladeKernelTestAssertEqual(_hard_bounds.minimum, 20, "Hard rank starts at twenty");
    BladeKernelTestAssertEqual(_hard_bounds.maximum, 50, "Hard rank caps at fifty");
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
            2, BLADE_DIFFICULTY_HARD_ID, BLADE_DIFFICULTY_RANK_HARD_MIN
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
        BladeDifficultyHostileFireInterval(
            120, BLADE_DIFFICULTY_HARD_ID, BLADE_DIFFICULTY_RANK_HARD_MIN
        ) < BladeDifficultyHostileFireInterval(
            120, BLADE_DIFFICULTY_NORMAL_ID, BLADE_DIFFICULTY_RANK_NORMAL_MIN
        ),
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
            < BladeDifficultyRewardValue(
                1000, BLADE_DIFFICULTY_HARD_ID, BLADE_DIFFICULTY_RANK_HARD_MIN
            ),
        "Hard reward is higher"
    );
    BladeKernelTestAssertTrue(
        BladeDifficultyRewardValue(1000, BLADE_DIFFICULTY_NORMAL_ID, 25)
            < BladeDifficultyRewardValue(1000, BLADE_DIFFICULTY_NORMAL_ID, 50),
        "rank raises reward value"
    );
    BladeKernelTestAssertEqual(
        BladeDifficultyEnemyHealth(80, BLADE_DIFFICULTY_EASY_ID, 25),
        80,
        "Easy preserves authored enemy health at its rank cap"
    );
    BladeKernelTestAssertEqual(
        BladeDifficultyEnemyHealth(80, BLADE_DIFFICULTY_HARD_ID, 20),
        80,
        "Hard preserves authored enemy health at its rank floor"
    );
    BladeKernelTestAssertTrue(
        BladeDifficultyHostileDensityPerMille(
            BLADE_DIFFICULTY_NORMAL_ID, 0, 0
        ) < BladeDifficultyHostileDensityPerMille(
            BLADE_DIFFICULTY_NORMAL_ID, 50, 3
        ),
        "rank and Hyper raise hostile density"
    );
    BladeKernelTestAssertEqual(
        array_length(BladeDifficultyExpandFanOffsets(
            [-30, 0, 30], BLADE_DIFFICULTY_NORMAL_ID, 0, 0
        )),
        3,
        "baseline fan keeps authored cardinality"
    );
    BladeKernelTestAssertTrue(
        array_length(BladeDifficultyExpandFanOffsets(
            [-30, 0, 30], BLADE_DIFFICULTY_NORMAL_ID, 0, 3
        )) > 3,
        "Hyper expands fan cardinality"
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
    BladeKernelTestAssertEqual(
        _state.value, BLADE_DIFFICULTY_RANK_NORMAL_MIN,
        "Normal rank starts at zero"
    );
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
    BladeKernelTestAssertEqual(_hyper.delta, 5, "Normal Hyper delta is five");
    BladeKernelTestAssertEqual(_hyper.after, 6, "Normal Hyper raises rank once");
    BladeKernelTestAssertEqual(_bomb.delta, -3, "Normal Bomb delta is three down");
    BladeKernelTestAssertEqual(_bomb.after, 3, "Normal Bomb lowers rank once");
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
    var _death_bomb_bomb = BladeDifficultyRankApplyReason(
        _same_sequence, BladeDifficultyRankReason.DeathBombBomb, 1
    );
    BladeKernelTestAssertEqual(
        _death_bomb_bomb.delta, -10,
        "death-bomb Bomb delta is ten down"
    );
    var _life_loss = BladeDifficultyRankApplyReason(
        _same_sequence, BladeDifficultyRankReason.LifeLoss, 2
    );
    BladeKernelTestAssertEqual(
        _life_loss.delta, -15,
        "committed life loss delta is fifteen down"
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
    BladeKernelTestAssertThrows(
        method({}, function() {
            BladeDifficultyRankReasonDelta(7);
        }),
        "between 1 and 6",
        "generic recovery reasons are rejected"
    );
    var _easy = BladeDifficultyRankStateCreate(BLADE_DIFFICULTY_EASY_ID);
    for (var _easy_index = 0; _easy_index < 6; ++_easy_index) {
        BladeDifficultyRankApplyReason(
            _easy, BladeDifficultyRankReason.NormalHyper, _easy_index
        );
    }
    BladeKernelTestAssertEqual(_easy.value, 25, "Easy clamps at twenty-five");
    BladeKernelTestAssertTrue(_easy.events[5].clamped, "Easy upper clamp is recorded");

    var _hard = BladeDifficultyRankStateCreate(BLADE_DIFFICULTY_HARD_ID);
    BladeKernelTestAssertEqual(_hard.value, 20, "Hard starts at twenty");
    var _hard_bomb = BladeDifficultyRankApplyReason(
        _hard, BladeDifficultyRankReason.DeathBombBomb, 0
    );
    BladeKernelTestAssertTrue(_hard_bomb.clamped, "Hard lower clamp is recorded");
    BladeKernelTestAssertEqual(_hard.value, 20, "Hard stays above its floor");

    var _high = BladeDifficultyRankStateCreate();
    for (var _event_index = 0; _event_index < 11; ++_event_index) {
        BladeDifficultyRankApplyReason(
            _high, BladeDifficultyRankReason.NormalHyper, _event_index
        );
    }
    BladeKernelTestAssertEqual(_high.value, 50, "rank clamps at fifty");
    BladeKernelTestAssertTrue(_high.events[10].clamped, "upper clamp is recorded");
    BladeDifficultyRankApplyReason(_high, BladeDifficultyRankReason.LifeLoss, 11);
    BladeKernelTestAssertEqual(_high.value, 35, "life loss lowers rank once");
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
    var _tick = _economy.rank_state.event_ordinal;
    while (BladeDifficultyRankValue(_economy.rank_state) < _target_rank) {
        BladeDifficultyRankApplyReason(
            _economy.rank_state,
            BladeDifficultyRankReason.NormalHyper,
            _tick
        );
        _tick += 1;
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
                var _bounds = BladeDifficultyRankBounds(_difficulty_id);
                var _rank = _rank_index == 0
                    ? _bounds.minimum
                    : (_rank_index == 1
                        ? _bounds.minimum
                            + floor((_bounds.maximum - _bounds.minimum) / 10) * 5
                        : _bounds.maximum);
                _controller.economy = BladeSurvivalEconomyCreate(_difficulty_id);
                _BladeDifficultyRankTestRaiseTo(_controller.economy, _rank);
                BladeKernelTestAssertEqual(
                    BladeSurvivalEconomyRank(_controller.economy), _rank,
                    "rank fixture reaches its documented snapshot"
                );
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
