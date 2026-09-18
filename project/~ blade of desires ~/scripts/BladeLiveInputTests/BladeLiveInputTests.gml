/// @description Deterministic validation for native-device input composition.

/// Proves keyboard and controller adapters converge on the same semantic frame.
function _BladeLiveInputTestEquivalentSources() {
    var _keyboard = BladeLiveInputSourceCreate(
        -1024,
        1024,
        -1,
        1,
        BladeInputAction.Fire | BladeInputAction.Focus,
        BladeInputAction.Fire,
        BladePromptDevice.KeyboardMouse
    );
    var _gamepad = BladeLiveInputSourceCreate(
        -1024,
        1024,
        -1,
        1,
        BladeInputAction.Fire | BladeInputAction.Focus,
        BladeInputAction.Fire,
        BladePromptDevice.Gamepad,
        true,
        -32767,
        32767
    );
    var _keyboard_state = BladeLiveInputStateCreate();
    var _gamepad_state = BladeLiveInputStateCreate();
    var _keyboard_sample = BladeLiveInputCompose(
        _keyboard_state,
        _keyboard,
        BladeLiveInputSourceCreate(),
        -1
    );
    var _gamepad_sample = BladeLiveInputCompose(
        _gamepad_state,
        BladeLiveInputSourceCreate(),
        _gamepad,
        2
    );

    BladeKernelTestAssertEqual(
        _keyboard_sample.move_x,
        _gamepad_sample.move_x,
        "keyboard and gamepad movement share move_x"
    );
    BladeKernelTestAssertEqual(
        _keyboard_sample.move_y,
        _gamepad_sample.move_y,
        "keyboard and gamepad movement share move_y"
    );
    BladeKernelTestAssertEqual(
        _keyboard_sample.pressed_move_x,
        _gamepad_sample.pressed_move_x,
        "keyboard and gamepad movement edges share move_x"
    );
    BladeKernelTestAssertEqual(
        _keyboard_sample.pressed_move_y,
        _gamepad_sample.pressed_move_y,
        "keyboard and gamepad movement edges share move_y"
    );
    BladeKernelTestAssertEqual(
        _keyboard_sample.held_actions,
        _gamepad_sample.held_actions,
        "keyboard and gamepad held actions share semantic bits"
    );
    BladeKernelTestAssertEqual(
        _keyboard_sample.pressed_actions,
        _gamepad_sample.pressed_actions,
        "keyboard and gamepad pressed actions share semantic bits"
    );
    BladeKernelTestAssertEqual(
        _keyboard_sample.prompt_device,
        BladePromptDevice.KeyboardMouse,
        "keyboard source reports keyboard prompt device"
    );
    BladeKernelTestAssertEqual(
        _gamepad_sample.prompt_device,
        BladePromptDevice.Gamepad,
        "gamepad source reports gamepad prompt device"
    );
    BladeKernelTestAssertEqual(
        _gamepad_sample.gamepad_id,
        2,
        "gamepad identity remains presentation-only"
    );
}

/// Proves device switching and reconnecting never creates duplicate action edges.
function _BladeLiveInputTestDeviceEdges() {
    var _state = BladeLiveInputStateCreate();
    var _keyboard_held = BladeLiveInputSourceCreate(
        1024,
        0,
        1,
        0,
        BladeInputAction.Fire,
        BladeInputAction.Fire,
        BladePromptDevice.KeyboardMouse
    );
    var _first = BladeLiveInputCompose(
        _state,
        _keyboard_held,
        BladeLiveInputSourceCreate(),
        -1
    );
    BladeKernelTestAssertTrue(
        BladeLiveInputActionPressed(_first, BladeInputAction.Fire),
        "first semantic press produces one fire edge"
    );
    BladeKernelTestAssertEqual(
        _first.pressed_move_x,
        1,
        "first movement produces one right edge"
    );

    var _gamepad_held = BladeLiveInputSourceCreate(
        1024,
        0,
        1,
        0,
        BladeInputAction.Fire,
        BladeInputAction.Fire,
        BladePromptDevice.Gamepad
    );
    var _switched = BladeLiveInputCompose(
        _state,
        BladeLiveInputSourceCreate(),
        _gamepad_held,
        3
    );
    BladeKernelTestAssertFalse(
        BladeLiveInputActionPressed(_switched, BladeInputAction.Fire),
        "switching devices does not duplicate a held fire edge"
    );
    BladeKernelTestAssertEqual(
        _switched.pressed_move_x,
        0,
        "switching devices does not duplicate a held direction edge"
    );

    var _disconnected = BladeLiveInputCompose(
        _state,
        BladeLiveInputSourceCreate(),
        BladeLiveInputSourceCreate(),
        -1
    );
    BladeKernelTestAssertEqual(
        _disconnected.held_actions,
        int64(0),
        "disconnect clears held semantic actions"
    );
    BladeKernelTestAssertEqual(
        _disconnected.gamepad_id,
        -1,
        "disconnect clears presentation gamepad identity"
    );

    var _reconnected = BladeLiveInputCompose(
        _state,
        BladeLiveInputSourceCreate(),
        BladeLiveInputSourceCreate(
            -1024,
            0,
            -1,
            0,
            BladeInputAction.Fire,
            BladeInputAction.Fire,
            BladePromptDevice.Gamepad
        ),
        5
    );
    BladeKernelTestAssertTrue(
        BladeLiveInputActionPressed(_reconnected, BladeInputAction.Fire),
        "reconnecting after release produces a new fire edge"
    );
    BladeKernelTestAssertEqual(
        _reconnected.pressed_move_x,
        -1,
        "reconnecting with a new direction produces one left edge"
    );
}

/// Proves normalized analog movement creates stable directional menu edges.
function _BladeLiveInputTestAnalogEdges() {
    var _state = BladeLiveInputStateCreate();
    BladeLiveInputCompose(
        _state,
        BladeLiveInputSourceCreate(),
        BladeLiveInputSourceCreate(),
        -1
    );
    var _analog = BladeLiveInputSourceCreate(
        512,
        -768,
        0,
        0,
        0,
        0,
        BladePromptDevice.Gamepad,
        true,
        16384,
        -24576
    );
    var _first_analog = BladeLiveInputCompose(
        _state,
        BladeLiveInputSourceCreate(),
        _analog,
        1
    );
    BladeKernelTestAssertEqual(
        _first_analog.move_x,
        512,
        "analog x remains fixed-point normalized"
    );
    BladeKernelTestAssertEqual(
        _first_analog.move_y,
        -768,
        "analog y remains fixed-point normalized"
    );
    BladeKernelTestAssertEqual(
        _first_analog.pressed_move_x,
        1,
        "analog x creates a right navigation edge"
    );
    BladeKernelTestAssertEqual(
        _first_analog.pressed_move_y,
        -1,
        "analog y creates an up navigation edge"
    );

    var _held_analog = BladeLiveInputCompose(
        _state,
        BladeLiveInputSourceCreate(),
        _analog,
        1
    );
    BladeKernelTestAssertEqual(
        _held_analog.pressed_move_x,
        0,
        "held analog x does not repeat a menu edge"
    );
    BladeKernelTestAssertEqual(
        _held_analog.pressed_move_y,
        0,
        "held analog y does not repeat a menu edge"
    );

    var _neutral = BladeLiveInputCompose(
        _state,
        BladeLiveInputSourceCreate(),
        BladeLiveInputSourceCreate(),
        -1
    );
    BladeKernelTestAssertEqual(
        _neutral.pressed_move_x,
        0,
        "returning analog movement to neutral creates no menu move"
    );
    BladeKernelTestAssertEqual(
        _neutral.pressed_move_y,
        0,
        "returning analog movement to neutral creates no vertical move"
    );
}

/// Proves composed controller samples drive the current selector, pause, and continue seams.
function _BladeLiveInputTestSemanticConsumers() {
    var _frontend = BladeFrontendStateCreate(BladeConfigCreateDefault());
    var _frontend_input_state = BladeLiveInputStateCreate();
    var _move_to_options = BladeLiveInputCompose(
        _frontend_input_state,
        BladeLiveInputSourceCreate(),
        BladeLiveInputSourceCreate(
            0, 1024, 0, 1, 0, 0, BladePromptDevice.Gamepad
        ),
        0
    );
    BladeFrontendStateMove(_frontend, _move_to_options.pressed_move_y);
    BladeKernelTestAssertEqual(
        _frontend.selected_index,
        1,
        "controller movement navigates the title selector"
    );
    var _confirm_options = BladeLiveInputCompose(
        _frontend_input_state,
        BladeLiveInputSourceCreate(),
        BladeLiveInputSourceCreate(
            0, 0, 0, 0, BladeInputAction.Confirm, BladeInputAction.Confirm,
            BladePromptDevice.Gamepad
        ),
        0
    );
    if (BladeLiveInputActionPressed(
        _confirm_options, BladeInputAction.Confirm
    )) {
        BladeFrontendStateActivate(_frontend);
    }
    BladeKernelTestAssertEqual(
        _frontend.page,
        BladeFrontendPage.Options,
        "controller confirm activates the selected front-end option"
    );

    var _pause = BladeStage1PauseCreate();
    var _pause_input_state = BladeLiveInputStateCreate();
    var _pause_open = BladeLiveInputCompose(
        _pause_input_state,
        BladeLiveInputSourceCreate(),
        BladeLiveInputSourceCreate(
            0, 0, 0, 0, BladeInputAction.Pause, BladeInputAction.Pause,
            BladePromptDevice.Gamepad
        ),
        1
    );
    var _opened = BladeStage1PauseAdvance(_pause, _pause_open, true);
    BladeKernelTestAssertTrue(_opened.opened, "controller pause opens the stage menu");
    var _pause_move = BladeLiveInputCompose(
        _pause_input_state,
        BladeLiveInputSourceCreate(),
        BladeLiveInputSourceCreate(
            0, 1024, 0, 1, 0, 0, BladePromptDevice.Gamepad
        ),
        1
    );
    BladeStage1PauseAdvance(_pause, _pause_move, true);
    BladeKernelTestAssertEqual(
        _pause.selected_index,
        1,
        "controller movement navigates the pause menu"
    );
    var _pause_confirm = BladeLiveInputCompose(
        _pause_input_state,
        BladeLiveInputSourceCreate(),
        BladeLiveInputSourceCreate(
            0, 0, 0, 0, BladeInputAction.Confirm, BladeInputAction.Confirm,
            BladePromptDevice.Gamepad
        ),
        1
    );
    var _pause_result = BladeStage1PauseAdvance(
        _pause, _pause_confirm, true
    );
    BladeKernelTestAssertEqual(
        _pause_result.action,
        BladeStage1PauseAction.Retry,
        "controller confirm activates the selected pause action"
    );

    var _terminal = BladeStage1TerminalCreate();
    BladeKernelTestAssertTrue(
        BladeStage1TerminalOpen(_terminal),
        "terminal continue prompt opens for controller input"
    );
    var _continue_input = BladeLiveInputSourceCreate(
        0, 0, 0, 0, BladeInputAction.Confirm, BladeInputAction.Confirm,
        BladePromptDevice.Gamepad
    );
    var _continue_result = BladeStage1TerminalAdvance(
        _terminal,
        BladeLiveInputCompose(
            BladeLiveInputStateCreate(),
            BladeLiveInputSourceCreate(),
            _continue_input,
            1
        )
    );
    BladeKernelTestAssertEqual(
        _continue_result.action,
        BladeStage1TerminalAction.ContinueRun,
        "controller confirm accepts the terminal continue choice"
    );
}

/// @func BladeLiveInputTestsRun(state)
/// Registers semantic device-adapter and controller-consumer cases.
function BladeLiveInputTestsRun(_state) {
    BladeKernelTestRunCase(_state, "live input adapters share semantic frames", function() {
        _BladeLiveInputTestEquivalentSources();
    });
    BladeKernelTestRunCase(_state, "live input device edges remain stable", function() {
        _BladeLiveInputTestDeviceEdges();
    });
    BladeKernelTestRunCase(_state, "live input analog edges are deterministic", function() {
        _BladeLiveInputTestAnalogEdges();
    });
    BladeKernelTestRunCase(_state, "live input drives controller menu seams", function() {
        _BladeLiveInputTestSemanticConsumers();
    });
    return _state;
}
