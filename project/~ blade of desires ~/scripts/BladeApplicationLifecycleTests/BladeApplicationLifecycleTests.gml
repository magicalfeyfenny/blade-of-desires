/// @description Deterministic focus, suspend, resume, and shutdown lifecycle tests.

/// Proves focus loss and platform suspension stop gameplay until a clean resume.
function _BladeApplicationLifecycleTestObservationTransitions() {
    var _lifecycle = BladeApplicationLifecycleCreate();
    var _active = BladeApplicationLifecycleObserve(_lifecycle, true, false);
    BladeKernelTestAssertEqual(
        _active.state,
        BladeApplicationState.Active,
        "fresh lifecycle remains active"
    );
    BladeKernelTestAssertTrue(
        _active.gameplay_allowed,
        "active lifecycle permits gameplay"
    );
    BladeKernelTestAssertEqual(
        _active.epoch,
        int64(0),
        "initial lifecycle epoch is stable"
    );

    var _lost_focus = BladeApplicationLifecycleObserve(
        _lifecycle, false, false
    );
    BladeKernelTestAssertEqual(
        _lost_focus.transition,
        BladeApplicationTransition.Suspended,
        "focus loss creates one suspended transition"
    );
    BladeKernelTestAssertFalse(
        _lost_focus.gameplay_allowed,
        "focus loss blocks gameplay"
    );
    BladeKernelTestAssertEqual(
        _lost_focus.epoch,
        int64(1),
        "focus loss increments the lifecycle epoch"
    );

    var _still_lost = BladeApplicationLifecycleObserve(
        _lifecycle, false, false
    );
    BladeKernelTestAssertEqual(
        _still_lost.transition,
        BladeApplicationTransition.None,
        "repeated focus loss does not churn transitions"
    );
    BladeKernelTestAssertEqual(
        _still_lost.epoch,
        int64(1),
        "repeated focus loss preserves the lifecycle epoch"
    );

    var _resumed = BladeApplicationLifecycleObserve(
        _lifecycle, true, false
    );
    BladeKernelTestAssertEqual(
        _resumed.transition,
        BladeApplicationTransition.Resumed,
        "focus return creates one resume transition"
    );
    BladeKernelTestAssertTrue(
        _resumed.input_allowed,
        "resume restores input authority"
    );

    var _platform_pause = BladeApplicationLifecycleObserve(
        _lifecycle, true, true
    );
    BladeKernelTestAssertEqual(
        _platform_pause.state,
        BladeApplicationState.Suspended,
        "platform pause shares the suspension authority"
    );
    BladeKernelTestAssertFalse(
        _platform_pause.input_allowed,
        "platform pause blocks input authority"
    );
}

/// Proves shutdown is administrative, idempotent, and never reopens a run.
function _BladeApplicationLifecycleTestShutdown() {
    var _lifecycle = BladeApplicationLifecycleCreate();
    var _requested = BladeApplicationLifecycleRequestShutdown(
        _lifecycle, "test.application_quit"
    );
    BladeKernelTestAssertEqual(
        _requested.state,
        BladeApplicationState.ShuttingDown,
        "shutdown request enters administrative shutdown"
    );
    BladeKernelTestAssertEqual(
        _requested.shutdown_reason,
        "test.application_quit",
        "shutdown preserves its administrative reason"
    );
    BladeKernelTestAssertFalse(
        BladeApplicationLifecycleGameplayAllowed(_lifecycle),
        "shutdown cannot advance gameplay"
    );

    var _repeated = BladeApplicationLifecycleRequestShutdown(
        _lifecycle, "test.duplicate_quit"
    );
    BladeKernelTestAssertEqual(
        _repeated.transition,
        BladeApplicationTransition.None,
        "duplicate shutdown is idempotent"
    );
    BladeKernelTestAssertEqual(
        _repeated.shutdown_count,
        int64(1),
        "duplicate shutdown does not duplicate ownership"
    );

    var _finalized = BladeApplicationLifecycleFinalizeShutdown(_lifecycle);
    BladeKernelTestAssertEqual(
        _finalized.state,
        BladeApplicationState.Terminated,
        "cleanup finalizes the lifecycle"
    );
    BladeKernelTestAssertFalse(
        _finalized.input_allowed,
        "terminated lifecycle never accepts input"
    );
}

/// Proves the resume boundary discards a held edge before live input can act again.
function _BladeApplicationLifecycleTestInputBoundary() {
    var _state = BladeLiveInputStateCreate();
    var _held_fire = BladeLiveInputSourceCreate(
        0, 0, 0, 0,
        BladeInputAction.Fire,
        BladeInputAction.Fire,
        BladePromptDevice.KeyboardMouse
    );
    var _first = BladeLiveInputCompose(
        _state, _held_fire, BladeLiveInputSourceCreate(), -1
    );
    BladeKernelTestAssertTrue(
        BladeLiveInputActionPressed(_first, BladeInputAction.Fire),
        "initial held input creates its first edge"
    );

    BladeLiveInputStateReset(_state);
    var _after_resume = BladeLiveInputCompose(
        _state, _held_fire, BladeLiveInputSourceCreate(), -1
    );
    BladeKernelTestAssertTrue(
        BladeLiveInputActionPressed(_after_resume, BladeInputAction.Fire),
        "reset input latch accepts a fresh post-resume edge"
    );
}

/// Registers lifecycle ownership and stale-input boundary cases.
function BladeApplicationLifecycleTestsRun(_state) {
    BladeKernelTestRunCase(
        _state,
        "application lifecycle focus and platform suspension are deterministic",
        function() {
            _BladeApplicationLifecycleTestObservationTransitions();
        }
    );
    BladeKernelTestRunCase(
        _state,
        "application shutdown is administrative and idempotent",
        function() {
            _BladeApplicationLifecycleTestShutdown();
        }
    );
    BladeKernelTestRunCase(
        _state,
        "application resume resets stale live input edges",
        function() {
            _BladeApplicationLifecycleTestInputBoundary();
        }
    );
    return _state;
}
