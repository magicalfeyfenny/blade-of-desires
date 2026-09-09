/// @description State-transition and gameplay-gate tests for the Stage 1 pause menu.

/// Creates the smallest semantic input record needed by pause navigation.
function _BladeStage1PauseTestInput(_pressed_actions, _pressed_move_y = 0) {
    return {
        pressed_actions: _pressed_actions,
        pressed_move_y: _pressed_move_y,
    };
}

/// Opens a test menu through the same Pause edge that production samples.
function _BladeStage1PauseTestOpen(_menu) {
    var _opened = BladeStage1PauseAdvance(
        _menu,
        _BladeStage1PauseTestInput(BladeInputAction.Pause),
        true
    );
    BladeKernelTestAssertTrue(_opened.opened, "Pause edge opens the menu");
    BladeKernelTestAssertTrue(_menu.open, "opened menu owns the frame");
}

/// Registers the focused menu transitions and the controller freeze contract.
function BladeStage1PauseTestsRun(_state) {
    BladeKernelTestRunCase(_state, "Stage 1 pause menu opens only from an active attempt", function() {
        var _menu = BladeStage1PauseCreate();
        var _closed = BladeStage1PauseAdvance(
            _menu,
            _BladeStage1PauseTestInput(BladeInputAction.Confirm),
            false
        );
        BladeKernelTestAssertFalse(_closed.opened, "terminal or unavailable menu stays closed");
        BladeKernelTestAssertEqual(
            _closed.action,
            BladeStage1PauseAction.None,
            "closed menu emits no action"
        );

        _BladeStage1PauseTestOpen(_menu);
        BladeKernelTestAssertEqual(_menu.selected_index, 0, "Resume is the default selection");
        var _labels = BladeStage1PauseMenuLabels();
        BladeKernelTestAssertEqual(
            _labels[2],
            "QUIT TO MAIN MENU",
            "quit label names the front-end destination"
        );
    });

    BladeKernelTestRunCase(_state, "Stage 1 pause menu uses semantic navigation and resume", function() {
        var _menu = BladeStage1PauseCreate();
        _BladeStage1PauseTestOpen(_menu);

        var _move = BladeStage1PauseAdvance(
            _menu,
            _BladeStage1PauseTestInput(BladeInputAction.None, 1),
            true
        );
        BladeKernelTestAssertEqual(_move.selected_index, 1, "down selects Retry");
        BladeKernelTestAssertEqual(
            _move.action,
            BladeStage1PauseAction.None,
            "navigation does not activate a menu item"
        );

        var _same_frame = BladeStage1PauseAdvance(
            _menu,
            _BladeStage1PauseTestInput(BladeInputAction.Confirm, 1),
            true
        );
        BladeKernelTestAssertEqual(
            _same_frame.selected_index,
            2,
            "navigation consumes the frame before confirmation"
        );
        BladeKernelTestAssertEqual(
            _same_frame.action,
            BladeStage1PauseAction.None,
            "navigation cannot double-submit confirmation"
        );

        var _wrap = BladeStage1PauseAdvance(
            _menu,
            _BladeStage1PauseTestInput(BladeInputAction.None, 1),
            true
        );
        BladeKernelTestAssertEqual(_wrap.selected_index, 0, "cursor wraps after the last item");

        var _resume = BladeStage1PauseAdvance(
            _menu,
            _BladeStage1PauseTestInput(BladeInputAction.Confirm),
            true
        );
        BladeKernelTestAssertEqual(
            _resume.action,
            BladeStage1PauseAction.Resume,
            "Confirm on Resume returns the semantic resume action"
        );
        BladeKernelTestAssertTrue(_resume.closed, "Resume closes the menu");
        BladeKernelTestAssertFalse(_menu.open, "closed menu no longer freezes gameplay");

        _BladeStage1PauseTestOpen(_menu);
        var _cancel = BladeStage1PauseAdvance(
            _menu,
            _BladeStage1PauseTestInput(BladeInputAction.Cancel),
            true
        );
        BladeKernelTestAssertEqual(
            _cancel.action,
            BladeStage1PauseAction.Resume,
            "Cancel is the shared semantic back/resume action"
        );
    });

    BladeKernelTestRunCase(_state, "Stage 1 pause menu emits retry and quit exactly once", function() {
        var _menu = BladeStage1PauseCreate();
        _BladeStage1PauseTestOpen(_menu);
        BladeStage1PauseAdvance(
            _menu,
            _BladeStage1PauseTestInput(BladeInputAction.None, 1),
            true
        );
        var _retry = BladeStage1PauseAdvance(
            _menu,
            _BladeStage1PauseTestInput(BladeInputAction.Confirm),
            true
        );
        BladeKernelTestAssertEqual(
            _retry.action,
            BladeStage1PauseAction.Retry,
            "Retry is a distinct controller action"
        );
        var _retry_repeat = BladeStage1PauseAdvance(
            _menu,
            _BladeStage1PauseTestInput(BladeInputAction.Confirm),
            true
        );
        BladeKernelTestAssertEqual(
            _retry_repeat.action,
            BladeStage1PauseAction.None,
            "closed Retry cannot repeat without a new Pause edge"
        );

        _BladeStage1PauseTestOpen(_menu);
        BladeStage1PauseAdvance(
            _menu,
            _BladeStage1PauseTestInput(BladeInputAction.None, 1),
            true
        );
        BladeStage1PauseAdvance(
            _menu,
            _BladeStage1PauseTestInput(BladeInputAction.None, 1),
            true
        );
        var _quit = BladeStage1PauseAdvance(
            _menu,
            _BladeStage1PauseTestInput(BladeInputAction.Confirm),
            true
        );
        BladeKernelTestAssertEqual(
            _quit.action,
            BladeStage1PauseAction.QuitToMain,
            "Quit is a distinct controller action"
        );
        BladeKernelTestAssertTrue(_quit.closed, "Quit closes before the room transition");
    });

    BladeKernelTestRunCase(_state, "Stage 1 pause eligibility distinguishes terminal states", function() {
        var _controller = { state: BladeFirstBeatState.Playing };
        BladeKernelTestAssertTrue(
            BladeStage1PauseCanOpen(_controller),
            "Playing can open pause"
        );
        _controller.state = BladeFirstBeatState.Rewarding;
        BladeKernelTestAssertTrue(
            BladeStage1PauseCanOpen(_controller),
            "Rewarding can open pause"
        );
        _controller.state = BladeFirstBeatState.Won;
        BladeKernelTestAssertFalse(
            BladeStage1PauseCanOpen(_controller),
            "clear cannot open pause"
        );
        _controller.state = BladeFirstBeatState.Failed;
        BladeKernelTestAssertFalse(
            BladeStage1PauseCanOpen(_controller),
            "game over cannot open pause"
        );
    });

    BladeFirstBeatTestRunCase(_state, "paused Stage 1 controller freezes rank and timed survival state", function() {
        var _controller = instance_create_layer(
            0, 0, "Instances", o_blade_first_beat_controller
        );
        _controller.rank_clock_tick = 41;
        _controller.economy.bomb_ticks = 7;
        _controller.feedback_ticks = 19;
        _controller.pause_menu.open = true;
        BladeKernelTestAssertFalse(
            BladeSurvivalGameplayAdvances(_controller),
            "pause blocks ordinary gameplay"
        );
        BladeKernelTestAssertFalse(
            BladeSurvivalItemMotionAdvances(_controller),
            "pause blocks reward motion"
        );
        with (_controller) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertEqual(_controller.rank_clock_tick, 41, "rank clock freezes");
        BladeKernelTestAssertEqual(_controller.economy.bomb_ticks, 7, "bomb timer freezes");
        BladeKernelTestAssertEqual(_controller.feedback_ticks, 19, "feedback timer freezes");

        _controller.pause_menu.open = false;
        with (_controller) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertEqual(_controller.rank_clock_tick, 42, "rank resumes after close");
        BladeKernelTestAssertEqual(_controller.economy.bomb_ticks, 6, "bomb timer resumes after close");
    });
}
