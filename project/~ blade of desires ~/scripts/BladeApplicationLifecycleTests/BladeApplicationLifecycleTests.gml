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

/// Proves held controls stay neutral until a release and a fresh press after resume.
function _BladeApplicationLifecycleTestInputBoundary() {
    var _state = BladeLiveInputStateCreate();
    var _held_fire_and_move = BladeLiveInputSourceCreate(
        1024, 0, 1, 0,
        BladeInputAction.Fire,
        BladeInputAction.Fire,
        BladePromptDevice.KeyboardMouse
    );
    var _first = BladeLiveInputCompose(
        _state, _held_fire_and_move, BladeLiveInputSourceCreate(), -1
    );
    BladeKernelTestAssertTrue(
        BladeLiveInputActionPressed(_first, BladeInputAction.Fire),
        "initial held input creates its first edge"
    );

    BladeLiveInputStateReset(_state);
    var _after_resume = BladeLiveInputCompose(
        _state, _held_fire_and_move, BladeLiveInputSourceCreate(), -1
    );
    BladeKernelTestAssertFalse(
        BladeLiveInputActionPressed(_after_resume, BladeInputAction.Fire),
        "held action after resume is not converted into a fresh edge"
    );
    BladeKernelTestAssertEqual(
        _after_resume.move_x,
        int64(0),
        "held movement after resume stays neutral"
    );
    BladeLiveInputCompose(
        _state,
        BladeLiveInputSourceCreate(),
        BladeLiveInputSourceCreate(),
        -1
    );
    var _fresh_press = BladeLiveInputCompose(
        _state, _held_fire_and_move, BladeLiveInputSourceCreate(), -1
    );
    BladeKernelTestAssertTrue(
        BladeLiveInputActionPressed(_fresh_press, BladeInputAction.Fire),
        "release followed by a new press is accepted after resume"
    );
    BladeKernelTestAssertEqual(
        _fresh_press.pressed_move_x,
        1,
        "fresh movement after resume creates one direction edge"
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

/// Simulates native exit delivery after the real application cleanup boundary.
function _BladeApplicationLifecycleTestRequestExit() {
    self.requested = true;
    self.game_end = BladeApplicationLifecycleHandleGameEnd();
}

/// Exercises quit, lifecycle input quarantine, persisted owners, and replay cleanup together.
function _BladeApplicationLifecycleTestShutdownIntegration() {
    if (instance_number(o_blade_first_beat_controller) != 0) {
        throw("lifecycle integration requires an empty application room");
    }

    var _config_storage = _BladeConfigTestMemoryStorageCreate();
    var _config_service = BladeConfigServiceCreate(
        _config_storage, "application-lifecycle-config.json"
    );
    var _config_candidate = BladeConfigCreateDefault();
    _config_candidate.display.fullscreen = true;
    var _config_save = BladeConfigServiceSave(
        _config_service, _config_candidate
    );
    BladeKernelTestAssertTrue(_config_save.ok, "config commit succeeds before quit");
    var _committed_config_text = variable_struct_get(
        _config_storage.context.files, _config_service.filename
    );

    var _profile_storage = _BladeProfileTestMemoryStorageCreate();
    var _profile_service = BladeProfileServiceCreate(
        _profile_storage, "application-lifecycle-profile.json"
    );
    var _profile_candidate = BladeProfileCreateDefault();
    BladeProfileGrantAchievement(
        _profile_candidate, "achievement.first_clear"
    );
    var _profile_save = BladeProfileServiceSave(
        _profile_service, _profile_candidate
    );
    BladeKernelTestAssertTrue(_profile_save.ok, "profile commit succeeds before quit");
    var _committed_profile_text = variable_struct_get(
        _profile_storage.context.files, _profile_service.filename
    );
    var _config_write_count = _config_storage.context.write_calls;
    var _profile_write_count = _profile_storage.context.write_calls;

    global.blade_config_service = _config_service;
    global.blade_profile_service = _profile_service;
    global.blade_profile_load_result = BladeProfileServiceLoad(
        _profile_service
    );
    global.blade_replay_catalog = BladeReplayCatalogCreate(
        _BladeReplayCatalogTestMemoryStorageCreate()
    );
    global.blade_selected_run = undefined;

    var _run_instance = noone;
    try {
        global.blade_application_lifecycle = BladeApplicationLifecycleCreate();
        global.blade_application_lifecycle_test_observation = {
            has_focus: true,
            platform_paused: false,
        };
        var _frontend_state = BladeFrontendStateCreate(
            _config_save.config,
            global.blade_replay_catalog,
            global.blade_profile_load_result
        );
        _frontend_state.selected_index = 4;

        var _frontend_replay_fixture = _BladeReplayTestFixture(
            BladePromptDevice.KeyboardMouse
        );
        var _frontend_playback = BladeReplayPlaybackCreate(
            _frontend_replay_fixture.recording,
            method({}, _BladeReplayTestKnownContent),
            8
        );
        _frontend_state.replay_playback = _frontend_playback;
        global.blade_replay_playback = _frontend_playback;
        global.blade_replay_recorder = undefined;

        var _live_state = BladeLiveInputStateCreate();
        BladeLiveInputStateReset(_live_state);
        BladeLiveInputCompose(
            _live_state,
            BladeLiveInputSourceCreate(),
            BladeLiveInputSourceCreate(),
            2
        );
        var _held_controller_confirm = BladeLiveInputSourceCreate(
            1024, 0, 1, 0,
            BladeInputAction.Confirm,
            BladeInputAction.Confirm,
            BladePromptDevice.Gamepad,
            true,
            32767,
            0
        );
        var _controller_input = BladeLiveInputCompose(
            _live_state,
            BladeLiveInputSourceCreate(),
            _held_controller_confirm,
            2
        );
        BladeKernelTestAssertTrue(
            BladeLiveInputActionPressed(
                _controller_input, BladeInputAction.Confirm
            ),
            "semantic controller confirm reaches the front-end before suspension"
        );
        BladeKernelTestAssertEqual(
            BladeFrontendStateActivate(_frontend_state).action,
            BladeFrontendAction.Quit,
            "front-end selection routes confirm to quit"
        );

        global.blade_application_lifecycle_test_observation.has_focus = false;
        var _focus_lost = BladeApplicationLifecyclePoll();
        BladeKernelTestAssertFalse(
            _focus_lost.gameplay_allowed,
            "focus loss stops the application owner"
        );
        BladeLiveInputStateReset(_live_state);

        global.blade_application_lifecycle_test_observation.has_focus = true;
        global.blade_application_lifecycle_test_observation.platform_paused = true;
        var _platform_suspended = BladeApplicationLifecyclePoll();
        BladeKernelTestAssertFalse(
            _platform_suspended.input_allowed,
            "platform suspension keeps input disabled after focus returns"
        );
        BladeLiveInputStateReset(_live_state);

        global.blade_application_lifecycle_test_observation.platform_paused = false;
        var _resumed = BladeApplicationLifecyclePoll();
        BladeKernelTestAssertTrue(
            _resumed.input_allowed,
            "platform resume restores input authority"
        );
        BladeLiveInputStateReset(_live_state);

        var _stale_controller_input = BladeLiveInputCompose(
            _live_state,
            BladeLiveInputSourceCreate(),
            _held_controller_confirm,
            2
        );
        BladeKernelTestAssertFalse(
            BladeLiveInputActionPressed(
                _stale_controller_input, BladeInputAction.Confirm
            ),
            "held controller confirm cannot trigger after resume"
        );
        BladeKernelTestAssertEqual(
            _stale_controller_input.move_x,
            int64(0),
            "held controller movement cannot advance after resume"
        );
        BladeKernelTestAssertFalse(
            _stale_controller_input.has_analog,
            "stale controller axes are absent from the resumed input frame"
        );
        BladeKernelTestAssertEqual(
            _stale_controller_input.analog_x,
            int64(0),
            "stale analog x is cleared after resume"
        );

        BladeLiveInputCompose(
            _live_state,
            BladeLiveInputSourceCreate(),
            BladeLiveInputSourceCreate(),
            2
        );
        var _keyboard_confirm = BladeLiveInputCompose(
            _live_state,
            BladeLiveInputSourceCreate(
                0, 0, 0, 0,
                BladeInputAction.Confirm,
                BladeInputAction.Confirm,
                BladePromptDevice.KeyboardMouse
            ),
            BladeLiveInputSourceCreate(),
            2
        );
        BladeKernelTestAssertTrue(
            BladeLiveInputActionPressed(
                _keyboard_confirm, BladeInputAction.Confirm
            ),
            "fresh semantic keyboard confirm works after release"
        );
        var _frontend_activation = BladeFrontendStateActivate(_frontend_state);
        BladeKernelTestAssertEqual(
            _frontend_activation.action,
            BladeFrontendAction.Quit,
            "fresh keyboard input requests front-end quit"
        );
        _frontend_state.listening = true;

        var _frontend_exit = { requested: false, game_end: undefined };
        BladeKernelTestAssertTrue(
            BladeApplicationLifecycleRequestQuit(
                "menu.quit",
                method(
                    _frontend_exit,
                    _BladeApplicationLifecycleTestRequestExit
                ),
                _frontend_state
            ),
            "front-end quit completes its cleanup request"
        );
        BladeKernelTestAssertTrue(
            _frontend_exit.requested,
            "front-end quit requests native application exit"
        );
        BladeKernelTestAssertEqual(
            _frontend_exit.game_end,
            true,
            "front-end exit handler processes native game end"
        );
        BladeKernelTestAssertEqual(
            BladeApplicationLifecycleGlobal().state,
            BladeApplicationState.Terminated,
            "front-end exit finalizes the lifecycle"
        );
        BladeKernelTestAssertTrue(
            BladeReplayPlaybackAborted(_frontend_playback),
            "front-end quit aborts replay playback"
        );
        BladeKernelTestAssertTrue(
            is_undefined(_frontend_state.replay_playback)
                && !_frontend_state.listening,
            "front-end quit clears its transient replay and listening state"
        );
        BladeKernelTestAssertTrue(
            is_undefined(global.blade_selected_run),
            "front-end quit leaves no selected run"
        );

        global.blade_application_lifecycle = BladeApplicationLifecycleCreate();
        global.blade_application_lifecycle_test_observation = {
            has_focus: true,
            platform_paused: false,
        };

        var _active_run_fixture = _BladeStageTestsPlayableFixture();
        _run_instance = instance_create_layer(
            0, 0, "Instances", o_blade_first_beat_controller
        );
        if (!instance_exists(_run_instance)) {
            throw("active-run owner could not be created");
        }
        _run_instance.stage_route_enabled = true;
        _run_instance.stage_kernel = _active_run_fixture.kernel;
        _run_instance.stage_executor = _active_run_fixture.executor;
        _run_instance.stage_run_result = BladeStage1RunResultCreate();
        _run_instance.application_shutdown_handled = false;
        global.blade_selected_run = _BladeProfileTestSelection();

        var _active_replay_fixture = _BladeReplayTestFixture(
            BladePromptDevice.Gamepad
        );
        var _active_playback = BladeReplayPlaybackCreate(
            _active_replay_fixture.recording,
            method({}, _BladeReplayTestKnownContent),
            8
        );
        global.blade_replay_recorder = _active_replay_fixture.recorder;
        global.blade_replay_playback = _active_playback;

        var _run_exit = { requested: false, game_end: undefined };
        BladeKernelTestAssertTrue(
            BladeApplicationLifecycleRequestQuit(
                "terminal.quit",
                method(_run_exit, _BladeApplicationLifecycleTestRequestExit)
            ),
            "active-run quit completes its cleanup request"
        );
        BladeKernelTestAssertTrue(
            _run_exit.requested
                && _run_exit.game_end
                && BladeApplicationLifecycleGlobal().state
                    == BladeApplicationState.Terminated,
            "active-run quit reaches native exit after finalization"
        );
        BladeKernelTestAssertEqual(
            _run_instance.stage_executor.lifecycle,
            BladeStageLifecycle.Aborted,
            "active-run quit aborts stage ownership"
        );
        BladeKernelTestAssertEqual(
            _run_instance.stage_run_result.terminal_outcome,
            BladeStage1RunResultEvent.Abort,
            "active-run quit records administrative abandonment"
        );
        BladeKernelTestAssertEqual(
            _run_instance.stage_run_result.phase,
            BladeStage1RunResultPhase.Active,
            "active-run quit does not create a clear or completion phase"
        );
        BladeKernelTestAssertTrue(
            is_undefined(_run_instance.stage_run_result.clear_result)
                && is_undefined(_run_instance.stage_run_result.run_completion),
            "active-run quit produces no terminal reward payload"
        );
        BladeKernelTestAssertEqual(
            _run_instance.stage_run_result.cleanup_count,
            int64(1),
            "active-run quit records one cleanup boundary"
        );
        BladeKernelTestAssertTrue(
            _active_replay_fixture.recorder.aborted,
            "active-run quit aborts its incomplete recorder"
        );
        BladeKernelTestAssertThrows(
            method(
                { recorder: _active_replay_fixture.recorder },
                function() {
                    BladeReplayRecordingSerialize(self.recorder);
                }
            ),
            "aborted recording",
            "active-run shutdown cannot publish an incomplete replay"
        );
        BladeKernelTestAssertTrue(
            BladeReplayPlaybackAborted(_active_playback),
            "active-run quit aborts playback"
        );
        BladeKernelTestAssertTrue(
            is_undefined(global.blade_selected_run),
            "active-run quit leaves no selected run"
        );
        BladeKernelTestAssertEqual(
            _config_storage.context.write_calls,
            _config_write_count,
            "shutdown does not rewrite a committed config"
        );
        BladeKernelTestAssertEqual(
            _profile_storage.context.write_calls,
            _profile_write_count,
            "administrative run abandonment does not write profile rewards"
        );
        BladeKernelTestAssertEqual(
            variable_struct_get(
                _config_storage.context.files, _config_service.filename
            ),
            _committed_config_text,
            "committed config bytes survive both quit paths"
        );
        BladeKernelTestAssertEqual(
            variable_struct_get(
                _profile_storage.context.files, _profile_service.filename
            ),
            _committed_profile_text,
            "committed profile bytes survive both quit paths"
        );

        var _config_reload = BladeConfigServiceCreate(
            _config_storage, _config_service.filename
        );
        BladeKernelTestAssertTrue(
            BladeConfigServiceLoad(_config_reload).config.display.fullscreen,
            "committed config reloads after application exit"
        );
        var _profile_reload = BladeProfileServiceCreate(
            _profile_storage, _profile_service.filename
        );
        var _profile_reloaded = BladeProfileServiceLoad(_profile_reload);
        BladeKernelTestAssertTrue(
            BladeProfileHasFlag(
                _profile_reloaded.profile,
                BladeProfileFlagKind.Achievement,
                "achievement.first_clear"
            ),
            "committed profile reloads after application exit"
        );
    } finally {
        if (instance_exists(_run_instance)) {
            with (_run_instance) instance_destroy();
        }
        global.blade_application_lifecycle = undefined;
        global.blade_application_lifecycle_test_observation = undefined;
        global.blade_config_service = undefined;
        global.blade_profile_service = undefined;
        global.blade_profile_load_result = undefined;
        global.blade_replay_catalog = undefined;
        global.blade_replay_recorder = undefined;
        global.blade_replay_playback = undefined;
        global.blade_selected_run = undefined;
    }
}

/// Runs an end-to-end application shutdown scenario after component suites.
function BladeApplicationLifecycleIntegrationTestsRun(_state) {
    BladeKernelTestRunCase(
        _state,
        "application quit preserves committed owners and abandons replay/run state",
        function() {
            _BladeApplicationLifecycleTestShutdownIntegration();
        }
    );
    return _state;
}
