/// @description Versioned Stage 1 terminal result and transition boundary.

enum BladeStage1RunResultPhase {
    Active = 0,
    StageClearCaptured = 1,
    RunCompleted = 2
}

enum BladeStage1RunResultEvent {
    None = 0,
    BossDefeat = 1,
    StageClear = 2,
    RunComplete = 3,
    GameOver = 4,
    Continue = 5,
    Retry = 6,
    Abort = 7,
    Cleanup = 8
}

enum BladeStage1RunContinueState {
    NotOffered = 0,
    Available = 1,
    Consumed = 2,
    Declined = 3
}

#macro BLADE_STAGE1_RUN_RESULT_VERSION 1
#macro BLADE_STAGE1_RUN_RESULT_DESTINATION_ID "destination.stage1.results"

/// Throws one field-specific terminal-result diagnostic.
function _BladeStage1RunResultFail(_field, _reason) {
    throw("BladeStage1RunResult: " + _field + ": " + _reason);
}

/// Validates a finite integer tick while allowing an unbound test fixture's -1.
function _BladeStage1RunResultTick(_value, _field = "tick") {
    return BladeCanonicalRequireInteger(
        _value, int64(-1), int64("9007199254740991"), _field
    );
}

/// Copies arrays and plain structs so a result never retains mutable gameplay state.
function _BladeStage1RunResultClone(_value) {
    if (is_array(_value)) {
        var _array = [];
        for (var _index = 0; _index < array_length(_value); ++_index) {
            array_push(_array, _BladeStage1RunResultClone(_value[_index]));
        }
        return _array;
    }
    if (is_struct(_value)) {
        var _copy = {};
        var _names = variable_struct_get_names(_value);
        for (var _name_index = 0;
            _name_index < array_length(_names);
            ++_name_index) {
            var _name = _names[_name_index];
            variable_struct_set(
                _copy,
                _name,
                _BladeStage1RunResultClone(variable_struct_get(_value, _name))
            );
        }
        return _copy;
    }
    return _value;
}

/// Reads a field from either a test struct or the live controller instance.
function _BladeStage1RunResultControllerField(_controller, _name, _fallback) {
    if (is_struct(_controller)) {
        return variable_struct_exists(_controller, _name)
            ? variable_struct_get(_controller, _name)
            : _fallback;
    }
    if (!is_numeric(_controller) || _controller < 0
        || !instance_exists(_controller)
        || !variable_instance_exists(_controller, _name)) {
        return _fallback;
    }
    return variable_instance_get(_controller, _name);
}

/// Converts one closed result enum to the stable event token used by diagnostics.
function BladeStage1RunResultEventToken(_event) {
    switch (_event) {
        case BladeStage1RunResultEvent.None: return "none";
        case BladeStage1RunResultEvent.BossDefeat: return "boss_defeat";
        case BladeStage1RunResultEvent.StageClear: return "stage_clear";
        case BladeStage1RunResultEvent.RunComplete: return "run_complete";
        case BladeStage1RunResultEvent.GameOver: return "game_over";
        case BladeStage1RunResultEvent.Continue: return "continue";
        case BladeStage1RunResultEvent.Retry: return "retry";
        case BladeStage1RunResultEvent.Abort: return "abort";
        case BladeStage1RunResultEvent.Cleanup: return "cleanup";
    }
    _BladeStage1RunResultFail("event", "has no canonical token");
    return "";
}

/// Converts one lifecycle phase to the stable phase token used by consumers.
function BladeStage1RunResultPhaseToken(_phase) {
    switch (_phase) {
        case BladeStage1RunResultPhase.Active: return "active";
        case BladeStage1RunResultPhase.StageClearCaptured: return "stage_clear_captured";
        case BladeStage1RunResultPhase.RunCompleted: return "run_completed";
    }
    _BladeStage1RunResultFail("phase", "has no canonical token");
    return "";
}

/// Converts the continue decision state to a stable token.
function BladeStage1RunContinueStateToken(_state) {
    switch (_state) {
        case BladeStage1RunContinueState.NotOffered: return "not_offered";
        case BladeStage1RunContinueState.Available: return "available";
        case BladeStage1RunContinueState.Consumed: return "consumed";
        case BladeStage1RunContinueState.Declined: return "declined";
    }
    _BladeStage1RunResultFail("continue_state", "has no canonical token");
    return "";
}

/// Requires the closed top-level result shape before a caller can mutate it.
function _BladeStage1RunResultRequire(_result) {
    if (!is_struct(_result)
        || !variable_struct_exists(
            _result, "__blade_stage1_run_result_version"
        )
        || _result.__blade_stage1_run_result_version
            != BLADE_STAGE1_RUN_RESULT_VERSION) {
        _BladeStage1RunResultFail(
            "result", "expected a version 1 Stage 1 run result"
        );
    }
    var _keys = [
        "__blade_stage1_run_result_version",
        "phase",
        "terminal_outcome",
        "last_event",
        "continue_state",
        "clear_result",
        "run_completion",
        "event_history",
        "cleanup_count",
    ];
    var _names = variable_struct_get_names(_result);
    if (array_length(_names) != array_length(_keys)) {
        _BladeStage1RunResultFail("result", "has unknown or missing fields");
    }
    for (var _index = 0; _index < array_length(_keys); ++_index) {
        if (!variable_struct_exists(_result, _keys[_index])) {
            _BladeStage1RunResultFail(
                "result", "requires " + _keys[_index]
            );
        }
    }
    if (_result.phase < BladeStage1RunResultPhase.Active
        || _result.phase > BladeStage1RunResultPhase.RunCompleted) {
        _BladeStage1RunResultFail("result.phase", "is outside the closed range");
    }
    BladeStage1RunResultEventToken(_result.terminal_outcome);
    BladeStage1RunResultEventToken(_result.last_event);
    BladeStage1RunContinueStateToken(_result.continue_state);
    if (!is_array(_result.event_history)) {
        _BladeStage1RunResultFail("result.event_history", "must be an array");
    }
    _BladeStage1RunResultTick(_result.cleanup_count, "result.cleanup_count");
    if (_result.cleanup_count > array_length(_result.event_history)) {
        _BladeStage1RunResultFail(
            "result.cleanup_count", "cannot exceed event history length"
        );
    }
    return _result;
}

/// Creates a fresh attempt-local result ledger before any terminal signal exists.
function BladeStage1RunResultCreate() {
    return {
        __blade_stage1_run_result_version: BLADE_STAGE1_RUN_RESULT_VERSION,
        phase: BladeStage1RunResultPhase.Active,
        terminal_outcome: BladeStage1RunResultEvent.None,
        last_event: BladeStage1RunResultEvent.None,
        continue_state: BladeStage1RunContinueState.NotOffered,
        clear_result: undefined,
        run_completion: undefined,
        event_history: [],
        cleanup_count: int64(0),
    };
}

/// Returns whether a semantic event has already been accepted by this attempt.
function _BladeStage1RunResultHasEvent(_result, _event) {
    for (var _index = 0;
        _index < array_length(_result.event_history);
        ++_index) {
        if (_result.event_history[_index].event == _event) return true;
    }
    return false;
}

/// Appends one event once; cleanup remains administrative and never replaces outcome.
function _BladeStage1RunResultRecordEvent(
    _result, _event, _tick, _reason = ""
) {
    _BladeStage1RunResultRequire(_result);
    if (_event <= BladeStage1RunResultEvent.None
        || _event > BladeStage1RunResultEvent.Cleanup) {
        _BladeStage1RunResultFail("event", "is outside the closed range");
    }
    var _ordered_tick = _BladeStage1RunResultTick(_tick);
    if (!is_string(_reason) || string_length(string_trim(_reason)) == 0) {
        _reason = BladeStage1RunResultEventToken(_event);
    }
    if (_event != BladeStage1RunResultEvent.Cleanup
        && _result.phase == BladeStage1RunResultPhase.RunCompleted) {
        return false;
    }
    if (_event != BladeStage1RunResultEvent.Cleanup
        && _BladeStage1RunResultHasEvent(_result, _event)) {
        return false;
    }
    array_push(_result.event_history, {
        ordinal: int64(array_length(_result.event_history) + 1),
        event: _event,
        token: BladeStage1RunResultEventToken(_event),
        tick: _ordered_tick,
        reason: _reason,
        terminal: _event != BladeStage1RunResultEvent.Cleanup,
    });
    _result.last_event = _event;
    if (_event == BladeStage1RunResultEvent.Cleanup) {
        _result.cleanup_count += 1;
    } else if (!(_event == BladeStage1RunResultEvent.Abort
        && _result.terminal_outcome == BladeStage1RunResultEvent.GameOver)) {
        _result.terminal_outcome = _event;
    }
    return true;
}

/// Gets the current deterministic kernel diagnostics or an unbound test fixture.
function _BladeStage1RunResultKernelCapture(_controller) {
    var _empty_clock = {
        simulation_tick: int64(-1),
        stage_tick: int64(-1),
        actor_tick: int64(-1),
        boss_tick: int64(-1),
        combat_tick: int64(-1),
        presentation_tick: int64(-1),
    };
    var _capture = {
        header: undefined,
        clock: _empty_clock,
        identity_counters: undefined,
        gameplay_event_hash: "",
        gameplay_hash: "",
    };
    var _kernel = _BladeStage1RunResultControllerField(
        _controller, "stage_kernel", undefined
    );
    if (!is_struct(_kernel)
        || !variable_struct_exists(_kernel, "__blade_kernel_version")) {
        return _capture;
    }
    var _diagnostics = BladeKernelDiagnostics(_kernel);
    _capture.header = _BladeStage1RunResultClone(_diagnostics.header);
    _capture.clock = _BladeStage1RunResultClone(_diagnostics.clock);
    _capture.identity_counters = _BladeStage1RunResultClone(
        _diagnostics.identity
    );
    _capture.gameplay_event_hash = _diagnostics.gameplay_event_hash;
    _capture.gameplay_hash = _diagnostics.gameplay_hash;
    return _capture;
}

/// Copies the selected route identity into the terminal payload.
function _BladeStage1RunResultSelection(_selected_run) {
    if (!is_struct(_selected_run)
        || !variable_struct_exists(
            _selected_run, "__blade_stage1_selected_run_version"
        )) {
        _BladeStage1RunResultFail(
            "selected_run", "must be a confirmed version 2 selection"
        );
    }
    return {
        version: _selected_run.__blade_stage1_selected_run_version,
        difficulty_id: _selected_run.difficulty_id,
        ship_id: _selected_run.ship_id,
        route_id: _selected_run.route_id,
        player_kind_id: _selected_run.player_kind_id,
        loadout_id: _selected_run.loadout_id,
        stage_schedule_id: _selected_run.stage_schedule_id,
        midboss_ship_ids: [
            _selected_run.midboss_ship_ids[0],
            _selected_run.midboss_ship_ids[1],
        ],
        standard_pattern_ids: [
            _selected_run.standard_pattern_ids[0],
            _selected_run.standard_pattern_ids[1],
        ],
        combo_pattern_id: _selected_run.combo_pattern_id,
    };
}

/// Copies every attempt-local economy field without retaining the live economy.
function _BladeStage1RunResultEconomy(_economy) {
    if (!is_struct(_economy)) {
        _BladeStage1RunResultFail("economy", "must be a struct");
    }
    return {
        difficulty_id: _economy.difficulty_id,
        score: _economy.score,
        point_value: _economy.point_value,
        lives: _economy.lives,
        bombs: _economy.bombs,
        hyper_meter: _economy.hyper_meter,
        active_hyper_tier: _economy.active_hyper_tier,
        hyper_ticks: _economy.hyper_ticks,
        bomb_ticks: _economy.bomb_ticks,
        awarded_life_mask: _economy.awarded_life_mask,
        shot_strength: _economy.shot_strength,
    };
}

/// Copies the complete rank event stream at the boundary rather than recomputing it.
function _BladeStage1RunResultRank(_rank_state) {
    if (!is_struct(_rank_state)
        || !variable_struct_exists(
            _rank_state, "__blade_difficulty_rank_state_version"
        )) {
        _BladeStage1RunResultFail("rank_state", "must be a rank-state struct");
    }
    return {
        version: _rank_state.__blade_difficulty_rank_state_version,
        difficulty_id: _rank_state.difficulty_id,
        value: _rank_state.value,
        active_play_ticks: _rank_state.active_play_ticks,
        event_ordinal: _rank_state.event_ordinal,
        last_tick: _rank_state.last_tick,
        last_reason: _rank_state.last_reason,
        last_delta: _rank_state.last_delta,
        last_priority: _rank_state.last_priority,
        events: _BladeStage1RunResultClone(_rank_state.events),
        canonical: BladeDifficultyRankCanonical(_rank_state),
    };
}

/// Captures the stage executor boundary at the clear cue before the run-complete record.
function _BladeStage1RunResultStageBoundary(_controller, _selected_run, _clock) {
    var _boundary = {
        stage_id: _selected_run.stage_schedule_id,
        plan_fingerprint: "",
        lifecycle: BladeStageLifecycle.Active,
        current_node_id: "",
        current_generation: int64(0),
        last_stage_tick: _clock.stage_tick,
        last_simulation_tick: _clock.simulation_tick,
        completion_stage_tick: int64(-1),
        completion_simulation_tick: int64(-1),
    };
    var _executor = _BladeStage1RunResultControllerField(
        _controller, "stage_executor", undefined
    );
    if (!is_struct(_executor)
        || !variable_struct_exists(
            _executor, "__blade_stage_executor_version"
        )) {
        return _boundary;
    }
    var _snapshot = BladeStageExecutorSnapshot(_executor);
    _boundary.stage_id = _snapshot.stage_id;
    _boundary.plan_fingerprint = _snapshot.plan_fingerprint;
    _boundary.lifecycle = _snapshot.lifecycle;
    _boundary.current_node_id = _snapshot.current_node_id;
    _boundary.current_generation = _snapshot.current_generation;
    _boundary.last_stage_tick = _snapshot.last_stage_tick;
    _boundary.last_simulation_tick = _snapshot.last_simulation_tick;
    _boundary.completion_stage_tick = _snapshot.completion_stage_tick;
    _boundary.completion_simulation_tick = _snapshot.completion_simulation_tick;
    return _boundary;
}

/// Reads a live controller tick when a caller did not provide one explicitly.
function _BladeStage1RunResultResolveTick(_controller, _tick) {
    var _ordered_tick = _BladeStage1RunResultTick(_tick);
    if (_ordered_tick >= 0) return _ordered_tick;
    var _kernel = _BladeStage1RunResultKernelCapture(_controller);
    return _kernel.clock.stage_tick;
}

/// Captures the stage identity, terminal metadata, and economy before cleanup begins.
function BladeStage1RunResultCaptureClear(
    _result, _controller, _tick = int64(-1)
) {
    _BladeStage1RunResultRequire(_result);
    if (_result.phase != BladeStage1RunResultPhase.Active) return false;
    if (_BladeStage1RunResultHasEvent(
        _result, BladeStage1RunResultEvent.StageClear
    )) return false;

    var _selected_run = _BladeStage1RunResultControllerField(
        _controller, "selected_run", undefined
    );
    var _economy = _BladeStage1RunResultControllerField(
        _controller, "economy", undefined
    );
    var _selection_snapshot = _BladeStage1RunResultSelection(_selected_run);
    var _economy_snapshot = _BladeStage1RunResultEconomy(_economy);
    var _rank_snapshot = _BladeStage1RunResultRank(_economy.rank_state);
    var _kernel = _BladeStage1RunResultKernelCapture(_controller);
    var _capture_tick = _BladeStage1RunResultResolveTick(_controller, _tick);
    var _stage_boundary = _BladeStage1RunResultStageBoundary(
        _controller, _selection_snapshot, _kernel.clock
    );
    var _breakdown = _BladeStage1RunResultControllerField(
        _controller,
        "stage_clear_breakdown",
        { base: 0, lives: 0, bombs: 0, total: 0 }
    );
    var _boss = _BladeStage1RunResultControllerField(
        _controller, "boss_instance", noone
    );
    var _boss_phase = -1;
    var _boss_state = -1;
    if (is_numeric(_boss) && _boss >= 0 && instance_exists(_boss)) {
        _boss_phase = _BladeStage1RunResultControllerField(
            _boss, "boss_phase", -1
        );
        _boss_state = _BladeStage1RunResultControllerField(
            _boss, "boss_state", -1
        );
    }

    var _clear = {
        __blade_stage1_clear_result_version: BLADE_STAGE1_RUN_RESULT_VERSION,
        outcome: BladeStage1RunResultEvent.StageClear,
        selection: _selection_snapshot,
        run_identity: {
            content_contract_fingerprint:
                is_undefined(_kernel.header)
                    ? ""
                    : _kernel.header.content_contract_fingerprint,
            run_seed: is_undefined(_kernel.header)
                ? BLADE_STAGE1_ROUTE_SEED
                : _kernel.header.run_seed,
            session_header: _BladeStage1RunResultClone(_kernel.header),
            identity_counters: _BladeStage1RunResultClone(
                _kernel.identity_counters
            ),
            gameplay_event_hash: _kernel.gameplay_event_hash,
            gameplay_hash: _kernel.gameplay_hash,
            stage_plan_fingerprint: _stage_boundary.plan_fingerprint,
        },
        stage_boundary: _stage_boundary,
        economy: _economy_snapshot,
        rank_state: _rank_snapshot,
        terminal: {
            boss_resolution: _BladeStage1RunResultControllerField(
                _controller, "boss_resolution", BladeStage1BossResolution.None
            ),
            boss_phase: _boss_phase,
            boss_state: _boss_state,
            stage_clear_breakdown: _BladeStage1RunResultClone(_breakdown),
            route_cue_id: _BladeStage1RunResultControllerField(
                _controller, "route_cue_id", ""
            ),
            controller_state: _BladeStage1RunResultControllerField(
                _controller, "state", BladeFirstBeatState.Playing
            ),
            captured_stage_tick: _capture_tick,
            captured_simulation_tick: _kernel.clock.simulation_tick,
            continue_state: _result.continue_state,
        },
        transition: {
            destination_id: BLADE_STAGE1_RUN_RESULT_DESTINATION_ID,
            next_stage_id: "",
            next_stage_declared: false,
        },
    };
    if (!_BladeStage1RunResultRecordEvent(
        _result,
        BladeStage1RunResultEvent.StageClear,
        _capture_tick,
        "cue.stage1.stage_clear"
    )) return false;
    _result.clear_result = _clear;
    _result.phase = BladeStage1RunResultPhase.StageClearCaptured;
    return true;
}

/// Commits the schedule's explicit complete node as a distinct run-complete outcome.
function BladeStage1RunResultComplete(
    _result, _controller = undefined, _tick = int64(-1)
) {
    _BladeStage1RunResultRequire(_result);
    if (_result.phase != BladeStage1RunResultPhase.StageClearCaptured
        || is_undefined(_result.clear_result)) return false;
    var _executor = _BladeStage1RunResultControllerField(
        _controller, "stage_executor", undefined
    );
    if (!is_struct(_executor)
        || !variable_struct_exists(_executor, "lifecycle")
        || _executor.lifecycle != BladeStageLifecycle.Completed) {
        return false;
    }
    var _kernel = _BladeStage1RunResultKernelCapture(_controller);
    var _completion_tick = _BladeStage1RunResultResolveTick(
        _controller, _tick
    );
    if (!_BladeStage1RunResultRecordEvent(
        _result,
        BladeStage1RunResultEvent.RunComplete,
        _completion_tick,
        "stage_executor.completed"
    )) return false;
    _result.run_completion = {
        __blade_stage1_run_completion_version: BLADE_STAGE1_RUN_RESULT_VERSION,
        outcome: BladeStage1RunResultEvent.RunComplete,
        completion_stage_tick: _completion_tick,
        completion_simulation_tick: _kernel.clock.simulation_tick,
        destination_id: BLADE_STAGE1_RUN_RESULT_DESTINATION_ID,
        next_stage_id: "",
        next_stage_declared: false,
    };
    _result.phase = BladeStage1RunResultPhase.RunCompleted;
    return true;
}

/// Records Asahi's defeat without confusing it with the later Stage Clear.
function BladeStage1RunResultRecordBossDefeat(
    _result, _controller = undefined, _tick = int64(-1)
) {
    return _BladeStage1RunResultRecordEvent(
        _result,
        BladeStage1RunResultEvent.BossDefeat,
        _BladeStage1RunResultResolveTick(_controller, _tick),
        "boss.defeat"
    );
}

/// Marks the Continue prompt as available exactly once after the final life.
function BladeStage1RunResultOfferContinue(_result) {
    _BladeStage1RunResultRequire(_result);
    if (_result.phase != BladeStage1RunResultPhase.Active
        || _result.continue_state != BladeStage1RunContinueState.NotOffered) {
        return false;
    }
    _result.continue_state = BladeStage1RunContinueState.Available;
    return true;
}

/// Records a confirmed Continue and consumes the one available prompt.
function BladeStage1RunResultRecordContinue(
    _result, _controller = undefined, _tick = int64(-1)
) {
    _BladeStage1RunResultRequire(_result);
    if (_result.continue_state != BladeStage1RunContinueState.Available) {
        return false;
    }
    var _recorded = _BladeStage1RunResultRecordEvent(
        _result,
        BladeStage1RunResultEvent.Continue,
        _BladeStage1RunResultResolveTick(_controller, _tick),
        "terminal.continue"
    );
    if (_recorded) _result.continue_state = BladeStage1RunContinueState.Consumed;
    return _recorded;
}

/// Records No as a one-shot Game Over decision and closes the continue state.
function BladeStage1RunResultRecordGameOver(
    _result, _controller = undefined, _tick = int64(-1)
) {
    _BladeStage1RunResultRequire(_result);
    if (_result.continue_state != BladeStage1RunContinueState.Available) {
        return false;
    }
    var _recorded = _BladeStage1RunResultRecordEvent(
        _result,
        BladeStage1RunResultEvent.GameOver,
        _BladeStage1RunResultResolveTick(_controller, _tick),
        "terminal.game_over"
    );
    if (_recorded) _result.continue_state = BladeStage1RunContinueState.Declined;
    return _recorded;
}

/// Records a player-requested retry while the stage is still active.
function BladeStage1RunResultRecordRetry(
    _result, _controller = undefined, _tick = int64(-1)
) {
    return _BladeStage1RunResultRecordEvent(
        _result,
        BladeStage1RunResultEvent.Retry,
        _BladeStage1RunResultResolveTick(_controller, _tick),
        "terminal.retry"
    );
}

/// Records an administrative abort without replacing a prior Game Over outcome.
function BladeStage1RunResultRecordAbort(
    _result, _controller = undefined, _tick = int64(-1), _reason = "terminal.abort"
) {
    return _BladeStage1RunResultRecordEvent(
        _result,
        BladeStage1RunResultEvent.Abort,
        _BladeStage1RunResultResolveTick(_controller, _tick),
        _reason
    );
}

/// Records cleanup as administrative evidence; it never grants clear or reward.
function BladeStage1RunResultRecordCleanup(
    _result, _controller = undefined, _tick = int64(-1), _reason = "cleanup"
) {
    return _BladeStage1RunResultRecordEvent(
        _result,
        BladeStage1RunResultEvent.Cleanup,
        _BladeStage1RunResultResolveTick(_controller, _tick),
        _reason
    );
}

/// Returns a detached result snapshot for UI, future persistence, and tests.
function BladeStage1RunResultSnapshot(_result) {
    _BladeStage1RunResultRequire(_result);
    return _BladeStage1RunResultClone(_result);
}
