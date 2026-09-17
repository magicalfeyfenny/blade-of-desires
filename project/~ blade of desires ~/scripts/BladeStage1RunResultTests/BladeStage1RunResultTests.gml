/// Focused tests for the Stage 1 clear payload and terminal transition ledger.

/// Builds a detached selected-run fixture without consulting presentation text.
function _BladeStage1RunResultTestsSelection() {
    return {
        __blade_stage1_selected_run_version: 2,
        difficulty_id: BLADE_DIFFICULTY_NORMAL_ID,
        ship_id: "ship.ciela",
        route_id: "route.stage1.ciela_lost_forest",
        player_kind_id: "player_kind.stage1.ciela",
        loadout_id: "loadout.stage1.ciela_spread",
        stage_schedule_id: "stage_schedule.stage1.selected_ship_lost_forest",
        midboss_ship_ids: ["ship.maynii", "ship.kolar"],
        standard_pattern_ids: [
            "pattern.stage1.maynii_leaf_wing",
            "pattern.stage1.kolar_mountain_crystal",
        ],
        combo_pattern_id: "pattern.stage1.root_ridgeline",
    };
}

/// Builds the same explicit controller fields consumed by the live capture.
function _BladeStage1RunResultTestsController() {
    var _economy = BladeSurvivalEconomyCreate(
        BLADE_DIFFICULTY_NORMAL_ID
    );
    _economy.score = 123456;
    _economy.lives = 1;
    _economy.bombs = 2;
    BladeDifficultyRankApplyReason(
        _economy.rank_state,
        BladeDifficultyRankReason.ActivePlay,
        30
    );
    return {
        selected_run: _BladeStage1RunResultTestsSelection(),
        economy: _economy,
        boss_resolution: BladeStage1BossResolution.Defeat,
        boss_instance: noone,
        route_cue_id: "cue.stage1.stage_clear",
        state: BladeFirstBeatState.Playing,
        stage_executor: {
            lifecycle: BladeStageLifecycle.Completed,
        },
        stage_clear_breakdown: {
            base: 50000,
            lives: 10000,
            bombs: 4000,
            total: 64000,
        },
    };
}

/// Registers all state-machine, snapshot, and duplicate-signal assertions.
function BladeStage1RunResultTestsRun(_state) {
    BladeKernelTestRunCase(
        _state,
        "Stage Clear captures immutable selection, identity, rank, and economy state",
        function() {
            var _result = BladeStage1RunResultCreate();
            var _controller = _BladeStage1RunResultTestsController();
            BladeKernelTestAssertEqual(
                BladeStage1RunResultPhaseToken(_result.phase),
                "active",
                "fresh result starts active"
            );
            BladeKernelTestAssertFalse(
                BladeStage1RunResultComplete(_result, _controller, 10),
                "run completion cannot precede Stage Clear"
            );
            BladeKernelTestAssertTrue(
                BladeStage1RunResultCaptureClear(_result, _controller, 12),
                "clear captures one explicit boundary"
            );
            var _clear = _result.clear_result;
            BladeKernelTestAssertEqual(
                BladeStage1RunResultEventToken(_clear.outcome),
                "stage_clear",
                "clear payload has a distinct outcome"
            );
            BladeKernelTestAssertEqual(
                _clear.selection.ship_id,
                "ship.ciela",
                "clear preserves the selected ship"
            );
            BladeKernelTestAssertEqual(
                _clear.selection.route_id,
                "route.stage1.ciela_lost_forest",
                "clear preserves the selected route"
            );
            BladeKernelTestAssertEqual(
                _clear.selection.difficulty_id,
                BLADE_DIFFICULTY_NORMAL_ID,
                "clear preserves difficulty identity"
            );
            BladeKernelTestAssertEqual(
                _clear.run_identity.run_seed,
                BLADE_STAGE1_ROUTE_SEED,
                "unbound fixture still carries the authored Stage seed"
            );
            BladeKernelTestAssertEqual(
                _clear.economy.score,
                123456,
                "clear captures score instead of querying it later"
            );
            BladeKernelTestAssertEqual(
                _clear.economy.lives,
                1,
                "clear captures remaining lives"
            );
            BladeKernelTestAssertEqual(
                _clear.economy.bombs,
                2,
                "clear captures remaining bombs"
            );
            BladeKernelTestAssertEqual(
                _clear.rank_state.value,
                1,
                "clear captures the current rank value"
            );
            BladeKernelTestAssertTrue(
                string_length(_clear.rank_state.canonical) > 0,
                "clear captures the canonical rank event stream"
            );
            BladeKernelTestAssertEqual(
                _clear.terminal.boss_resolution,
                BladeStage1BossResolution.Defeat,
                "clear retains the boss resolution"
            );
            BladeKernelTestAssertEqual(
                _clear.transition.destination_id,
                BLADE_STAGE1_RUN_RESULT_DESTINATION_ID,
                "clear exposes the stable alpha destination"
            );
            BladeKernelTestAssertFalse(
                _clear.transition.next_stage_declared,
                "future next-stage routing remains explicitly undeclared"
            );

            var _score_before = _controller.economy.score;
            BladeKernelTestAssertFalse(
                BladeStage1RunResultCaptureClear(_result, _controller, 13),
                "duplicate clear signal is rejected"
            );
            BladeKernelTestAssertEqual(
                _controller.economy.score,
                _score_before,
                "result capture never mutates the live economy"
            );
        }
    );

    BladeKernelTestRunCase(
        _state,
        "Stage Clear and run completion remain distinct and complete once",
        function() {
            var _result = BladeStage1RunResultCreate();
            var _controller = _BladeStage1RunResultTestsController();
            BladeStage1RunResultCaptureClear(_result, _controller, 20);
            BladeKernelTestAssertEqual(
                array_length(_result.event_history),
                1,
                "clear appends one boundary event"
            );
            BladeKernelTestAssertTrue(
                BladeStage1RunResultComplete(_result, _controller, 21),
                "the explicit complete node advances the run"
            );
            BladeKernelTestAssertEqual(
                BladeStage1RunResultPhaseToken(_result.phase),
                "run_completed",
                "run completion has its own lifecycle phase"
            );
            BladeKernelTestAssertEqual(
                _result.clear_result.outcome,
                BladeStage1RunResultEvent.StageClear,
                "completion does not overwrite the clear payload"
            );
            BladeKernelTestAssertEqual(
                _result.run_completion.outcome,
                BladeStage1RunResultEvent.RunComplete,
                "completion records a distinct outcome"
            );
            BladeKernelTestAssertEqual(
                _result.run_completion.destination_id,
                BLADE_STAGE1_RUN_RESULT_DESTINATION_ID,
                "completion preserves the stable destination"
            );
            BladeKernelTestAssertFalse(
                BladeStage1RunResultComplete(_result, _controller, 22),
                "duplicate completion signal is rejected"
            );
            BladeKernelTestAssertEqual(
                array_length(_result.event_history),
                2,
                "duplicate completion cannot advance history"
            );
        }
    );

    BladeKernelTestRunCase(
        _state,
        "death decisions, retries, aborts, and cleanup stay administrative",
        function() {
            var _continue_result = BladeStage1RunResultCreate();
            BladeKernelTestAssertTrue(
                BladeStage1RunResultOfferContinue(_continue_result),
                "final death makes Continue explicitly available"
            );
            BladeKernelTestAssertFalse(
                BladeStage1RunResultOfferContinue(_continue_result),
                "duplicate final-death signal cannot reset Continue"
            );
            BladeKernelTestAssertTrue(
                BladeStage1RunResultRecordContinue(
                    _continue_result, undefined, 30
                ),
                "confirmed Continue is recorded once"
            );
            BladeKernelTestAssertFalse(
                BladeStage1RunResultRecordContinue(
                    _continue_result, undefined, 31
                ),
                "held Continue input cannot repeat"
            );
            BladeKernelTestAssertTrue(
                BladeStage1RunResultRecordRetry(
                    _continue_result, undefined, 32
                ),
                "room restart records a distinct retry"
            );
            BladeKernelTestAssertTrue(
                BladeStage1RunResultRecordCleanup(
                    _continue_result, undefined, 33, "cleanup.retry"
                ),
                "cleanup is recorded administratively"
            );
            BladeKernelTestAssertEqual(
                _continue_result.terminal_outcome,
                BladeStage1RunResultEvent.Retry,
                "cleanup never replaces the retry outcome"
            );
            BladeKernelTestAssertEqual(
                _continue_result.continue_state,
                BladeStage1RunContinueState.Consumed,
                "Continue state remains consumed through retry cleanup"
            );

            var _game_over_result = BladeStage1RunResultCreate();
            BladeStage1RunResultOfferContinue(_game_over_result);
            BladeKernelTestAssertTrue(
                BladeStage1RunResultRecordGameOver(
                    _game_over_result, undefined, 40
                ),
                "No records Game Over"
            );
            BladeKernelTestAssertTrue(
                BladeStage1RunResultRecordAbort(
                    _game_over_result, undefined, 41, "cleanup.run_aborted"
                ),
                "post-Game-Over stage abort remains administrative"
            );
            BladeKernelTestAssertEqual(
                _game_over_result.terminal_outcome,
                BladeStage1RunResultEvent.GameOver,
                "abort cannot disguise Game Over"
            );
            BladeKernelTestAssertEqual(
                array_length(_game_over_result.event_history),
                2,
                "Game Over and abort remain separately auditable"
            );
        }
    );
}
