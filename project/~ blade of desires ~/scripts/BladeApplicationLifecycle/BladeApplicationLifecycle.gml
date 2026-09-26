/// @description Native focus/suspend/shutdown authority shared by every runtime owner.

enum BladeApplicationState {
    Active = 0,
    Suspended = 1,
    ShuttingDown = 2,
    Terminated = 3
}

enum BladeApplicationTransition {
    None = 0,
    Suspended = 1,
    Resumed = 2,
    ShutdownRequested = 3,
    Finalized = 4
}

#macro BLADE_APPLICATION_LIFECYCLE_VERSION 1

/// Returns a stable diagnostic token for one application state.
function BladeApplicationStateToken(_state) {
    switch (_state) {
        case BladeApplicationState.Active: return "active";
        case BladeApplicationState.Suspended: return "suspended";
        case BladeApplicationState.ShuttingDown: return "shutting_down";
        case BladeApplicationState.Terminated: return "terminated";
    }
    throw("BladeApplicationLifecycle: unknown application state");
}

/// Returns a stable diagnostic token for one lifecycle transition.
function BladeApplicationTransitionToken(_transition) {
    switch (_transition) {
        case BladeApplicationTransition.None: return "none";
        case BladeApplicationTransition.Suspended: return "suspended";
        case BladeApplicationTransition.Resumed: return "resumed";
        case BladeApplicationTransition.ShutdownRequested: return "shutdown_requested";
        case BladeApplicationTransition.Finalized: return "finalized";
    }
    throw("BladeApplicationLifecycle: unknown transition");
}

/// Rejects a malformed lifecycle owner before native observations can mutate it.
function _BladeApplicationLifecycleRequire(_lifecycle) {
    if (!is_struct(_lifecycle)
        || !variable_struct_exists(
            _lifecycle, "__blade_application_lifecycle_version"
        )
        || _lifecycle.__blade_application_lifecycle_version
            != BLADE_APPLICATION_LIFECYCLE_VERSION
        || !variable_struct_exists(_lifecycle, "state")
        || !variable_struct_exists(_lifecycle, "epoch")
        || !variable_struct_exists(_lifecycle, "last_transition")
        || !variable_struct_exists(_lifecycle, "shutdown_reason")
        || !variable_struct_exists(_lifecycle, "shutdown_count")) {
        throw("BladeApplicationLifecycle: state is incomplete");
    }
    BladeApplicationStateToken(_lifecycle.state);
    BladeApplicationTransitionToken(_lifecycle.last_transition);
    if (_lifecycle.epoch < 0 || _lifecycle.shutdown_count < 0) {
        throw("BladeApplicationLifecycle: counters are invalid");
    }
    if (!is_string(_lifecycle.shutdown_reason)) {
        throw("BladeApplicationLifecycle: shutdown reason is invalid");
    }
    return _lifecycle;
}

/// Creates the one process-owned lifecycle state before the first room starts.
function BladeApplicationLifecycleCreate() {
    return {
        __blade_application_lifecycle_version: BLADE_APPLICATION_LIFECYCLE_VERSION,
        state: BladeApplicationState.Active,
        epoch: int64(0),
        last_transition: BladeApplicationTransition.None,
        shutdown_reason: "",
        shutdown_count: int64(0),
    };
}

/// Builds a detached observation so callers cannot retain mutable owner state.
function _BladeApplicationLifecycleObservation(_lifecycle, _transition) {
    var _gameplay_allowed = _lifecycle.state == BladeApplicationState.Active;
    return {
        state: _lifecycle.state,
        state_token: BladeApplicationStateToken(_lifecycle.state),
        transition: _transition,
        transition_token: BladeApplicationTransitionToken(_transition),
        epoch: _lifecycle.epoch,
        gameplay_allowed: _gameplay_allowed,
        input_allowed: _gameplay_allowed,
        inactive: _lifecycle.state != BladeApplicationState.Active,
        shutdown_reason: _lifecycle.shutdown_reason,
        shutdown_count: _lifecycle.shutdown_count,
    };
}

/// Applies one platform-neutral focus/suspend observation to the lifecycle owner.
function BladeApplicationLifecycleObserve(_lifecycle, _has_focus, _platform_paused) {
    _BladeApplicationLifecycleRequire(_lifecycle);
    if (!is_bool(_has_focus) || !is_bool(_platform_paused)) {
        throw("BladeApplicationLifecycle: native observation must be Boolean");
    }

    var _transition = BladeApplicationTransition.None;
    var _inactive = !_has_focus || _platform_paused;
    if (_lifecycle.state == BladeApplicationState.Active && _inactive) {
        _lifecycle.state = BladeApplicationState.Suspended;
        _lifecycle.epoch += int64(1);
        _lifecycle.last_transition = BladeApplicationTransition.Suspended;
        _transition = BladeApplicationTransition.Suspended;
    } else if (_lifecycle.state == BladeApplicationState.Suspended && !_inactive) {
        _lifecycle.state = BladeApplicationState.Active;
        _lifecycle.epoch += int64(1);
        _lifecycle.last_transition = BladeApplicationTransition.Resumed;
        _transition = BladeApplicationTransition.Resumed;
    }
    return _BladeApplicationLifecycleObservation(_lifecycle, _transition);
}

/// Requests administrative shutdown exactly once and preserves its reason.
function BladeApplicationLifecycleRequestShutdown(
    _lifecycle, _reason = "application.shutdown"
) {
    _BladeApplicationLifecycleRequire(_lifecycle);
    if (!is_string(_reason) || string_length(string_trim(_reason)) == 0) {
        throw("BladeApplicationLifecycle: shutdown reason must be nonempty text");
    }

    var _transition = BladeApplicationTransition.None;
    if (_lifecycle.state == BladeApplicationState.Active
        || _lifecycle.state == BladeApplicationState.Suspended) {
        _lifecycle.state = BladeApplicationState.ShuttingDown;
        _lifecycle.epoch += int64(1);
        _lifecycle.last_transition = BladeApplicationTransition.ShutdownRequested;
        _lifecycle.shutdown_reason = _reason;
        _lifecycle.shutdown_count += int64(1);
        _transition = BladeApplicationTransition.ShutdownRequested;
    }
    return _BladeApplicationLifecycleObservation(_lifecycle, _transition);
}

/// Finalizes shutdown after owned run, input, and front-end resources are released.
function BladeApplicationLifecycleFinalizeShutdown(_lifecycle) {
    _BladeApplicationLifecycleRequire(_lifecycle);
    var _transition = BladeApplicationTransition.None;
    if (_lifecycle.state == BladeApplicationState.ShuttingDown) {
        _lifecycle.state = BladeApplicationState.Terminated;
        _lifecycle.epoch += int64(1);
        _lifecycle.last_transition = BladeApplicationTransition.Finalized;
        _transition = BladeApplicationTransition.Finalized;
    }
    return _BladeApplicationLifecycleObservation(_lifecycle, _transition);
}

/// Reads the process owner when an object is running outside the normal app room.
function BladeApplicationLifecycleGlobal() {
    if (!variable_global_exists("blade_application_lifecycle")
        || !is_struct(global.blade_application_lifecycle)) {
        return undefined;
    }
    return _BladeApplicationLifecycleRequire(
        global.blade_application_lifecycle
    );
}

/// Returns whether gameplay may advance for the current process state.
function BladeApplicationLifecycleGameplayAllowed(_lifecycle = undefined) {
    if (is_undefined(_lifecycle)) {
        _lifecycle = BladeApplicationLifecycleGlobal();
        if (is_undefined(_lifecycle)) return true;
    }
    _BladeApplicationLifecycleRequire(_lifecycle);
    return _lifecycle.state == BladeApplicationState.Active;
}

/// Returns the current epoch used to discard stale input edges after a boundary.
function BladeApplicationLifecycleCurrentEpoch() {
    var _lifecycle = BladeApplicationLifecycleGlobal();
    if (is_undefined(_lifecycle)) return int64(0);
    return _lifecycle.epoch;
}

/// Polls native focus and platform pause signals without embedding them in tests.
function BladeApplicationLifecyclePoll() {
    var _lifecycle = BladeApplicationLifecycleGlobal();
    if (is_undefined(_lifecycle)) {
        return {
            state: BladeApplicationState.Active,
            state_token: "active",
            transition: BladeApplicationTransition.None,
            transition_token: "none",
            epoch: int64(0),
            gameplay_allowed: true,
            input_allowed: true,
            inactive: false,
            shutdown_reason: "",
            shutdown_count: int64(0),
        };
    }
    var _has_focus = window_has_focus() != 0;
    var _platform_paused = os_is_paused() != 0;
    if (variable_global_exists(
        "blade_application_lifecycle_test_observation"
    ) && is_struct(global.blade_application_lifecycle_test_observation)) {
        var _test_observation = global.blade_application_lifecycle_test_observation;
        if (variable_struct_exists(_test_observation, "has_focus")
            && variable_struct_exists(_test_observation, "platform_paused")
            && is_bool(_test_observation.has_focus)
            && is_bool(_test_observation.platform_paused)) {
            _has_focus = _test_observation.has_focus;
            _platform_paused = _test_observation.platform_paused;
        }
    }
    return BladeApplicationLifecycleObserve(
        _lifecycle, _has_focus, _platform_paused
    );
}

/// Abandons all active run ownership before a normal application quit.
function BladeApplicationLifecycleShutdownActiveRun() {
    var _controller = instance_find(o_blade_first_beat_controller, 0);
    if (_controller != noone) {
        var _already_handled = variable_instance_exists(
            _controller, "application_shutdown_handled"
        ) && _controller.application_shutdown_handled;
        if (!_already_handled) {
            _controller.application_shutdown_handled = true;
            if (variable_instance_exists(_controller, "stage_route_enabled")
                && _controller.stage_route_enabled
                && variable_instance_exists(_controller, "stage_executor")
                && is_struct(_controller.stage_executor)) {
                BladeStage1RouteAbort(
                    _controller, BladeCombatTerminalReason.RunAborted
                );
            }
            if (variable_instance_exists(_controller, "stage_run_result")
                && is_struct(_controller.stage_run_result)) {
                BladeStage1RunResultRecordCleanup(
                    _controller.stage_run_result,
                    _controller,
                    int64(-1),
                    "cleanup.application_shutdown"
                );
            }
            BladeFirstBeatCleanupTransientInstances();
        }
    }

    var _front_end = instance_find(o_blade_start, 0);
    if (_front_end != noone
        && variable_instance_exists(_front_end, "frontend_state")
        && is_struct(_front_end.frontend_state)) {
        BladeFrontendStateShutdown(_front_end.frontend_state);
    }
    if (variable_global_exists("blade_selected_run")) {
        global.blade_selected_run = undefined;
    }
    if (variable_global_exists("blade_replay_recorder")
        && is_struct(global.blade_replay_recorder)) {
        BladeReplayRecorderAbort(global.blade_replay_recorder);
    }
    if (variable_global_exists("blade_replay_playback")
        && is_struct(global.blade_replay_playback)) {
        BladeReplayPlaybackAbort(global.blade_replay_playback);
    }
    return true;
}

/// Performs the complete normal-quit boundary and lets GameMaker close the app.
function BladeApplicationLifecycleRequestQuit(_reason = "application.quit") {
    var _lifecycle = BladeApplicationLifecycleGlobal();
    if (!is_undefined(_lifecycle)) {
        BladeApplicationLifecycleRequestShutdown(_lifecycle, _reason);
    }
    BladeApplicationLifecycleShutdownActiveRun();
    game_end();
    return true;
}

/// Completes native Game End cleanup without recursively requesting another quit.
function BladeApplicationLifecycleHandleGameEnd() {
    var _lifecycle = BladeApplicationLifecycleGlobal();
    if (!is_undefined(_lifecycle)) {
        BladeApplicationLifecycleRequestShutdown(
            _lifecycle, "application.window_close"
        );
        BladeApplicationLifecycleShutdownActiveRun();
        BladeApplicationLifecycleFinalizeShutdown(_lifecycle);
    } else {
        BladeApplicationLifecycleShutdownActiveRun();
    }
    return true;
}
