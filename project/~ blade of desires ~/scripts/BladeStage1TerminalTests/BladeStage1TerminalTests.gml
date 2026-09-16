/// @description Focused tests for terminal-death decisions and Game Over handoff.

/// Creates the smallest semantic input record needed by terminal navigation.
function _BladeStage1TerminalTestInput(_pressed_actions, _pressed_move_y = 0) {
    return {
        pressed_actions: _pressed_actions,
        pressed_move_y: _pressed_move_y,
    };
}

/// Opens a terminal flow through the same one-shot boundary used by production.
function _BladeStage1TerminalTestOpen(_flow) {
    BladeKernelTestAssertTrue(
        BladeStage1TerminalOpen(_flow),
        "final death opens Continue prompt once"
    );
    BladeKernelTestAssertFalse(
        BladeStage1TerminalOpen(_flow),
        "duplicate terminal signal cannot reset the prompt"
    );
}

/// Runs deterministic Continue/No transitions without launching a room boundary.
function BladeStage1TerminalTestsRun(_state) {
    BladeKernelTestRunCase(_state, "Continue prompt uses semantic navigation and one-shot Yes", function() {
        var _flow = BladeStage1TerminalCreate();
        BladeKernelTestAssertFalse(
            BladeStage1TerminalIsActive(_flow),
            "new terminal flow is inactive"
        );
        _BladeStage1TerminalTestOpen(_flow);
        var _labels = BladeStage1TerminalLabels();
        BladeKernelTestAssertEqual(_labels[0], "YES", "Yes is first");
        BladeKernelTestAssertEqual(_labels[1], "NO", "No is second");

        var _move = BladeStage1TerminalAdvance(
            _flow,
            _BladeStage1TerminalTestInput(BladeInputAction.None, 1)
        );
        BladeKernelTestAssertEqual(_move.selected_index, 1, "down selects No");
        BladeKernelTestAssertEqual(
            _move.action,
            BladeStage1TerminalAction.None,
            "navigation does not decide the terminal outcome"
        );

        var _same_frame = BladeStage1TerminalAdvance(
            _flow,
            _BladeStage1TerminalTestInput(BladeInputAction.Confirm, -1)
        );
        BladeKernelTestAssertEqual(
            _same_frame.selected_index,
            0,
            "navigation consumes the frame before confirmation"
        );
        BladeKernelTestAssertEqual(
            _same_frame.action,
            BladeStage1TerminalAction.None,
            "navigation cannot also submit No"
        );

        var _continue = BladeStage1TerminalAdvance(
            _flow,
            _BladeStage1TerminalTestInput(BladeInputAction.Confirm)
        );
        BladeKernelTestAssertEqual(
            _continue.action,
            BladeStage1TerminalAction.ContinueRun,
            "Yes requests a fresh attempt"
        );
        BladeKernelTestAssertFalse(
            BladeStage1TerminalIsActive(_flow),
            "Yes closes the terminal flow before room restart"
        );
        var _repeat = BladeStage1TerminalAdvance(
            _flow,
            _BladeStage1TerminalTestInput(BladeInputAction.Confirm)
        );
        BladeKernelTestAssertEqual(
            _repeat.action,
            BladeStage1TerminalAction.None,
            "closed Yes cannot repeat"
        );
    });

    BladeKernelTestRunCase(_state, "No enters Game Over and returns to main exactly once", function() {
        var _flow = BladeStage1TerminalCreate();
        _BladeStage1TerminalTestOpen(_flow);
        BladeStage1TerminalAdvance(
            _flow,
            _BladeStage1TerminalTestInput(BladeInputAction.None, 1)
        );
        var _game_over = BladeStage1TerminalAdvance(
            _flow,
            _BladeStage1TerminalTestInput(BladeInputAction.Confirm)
        );
        BladeKernelTestAssertEqual(
            _game_over.action,
            BladeStage1TerminalAction.BeginGameOver,
            "No begins Game Over"
        );
        BladeKernelTestAssertEqual(
            _flow.phase,
            BladeStage1TerminalPhase.GameOver,
            "Game Over owns the terminal display"
        );

        for (var _index = 0;
            _index < BLADE_STAGE1_TERMINAL_GAME_OVER_TICKS - 1;
            ++_index) {
            var _waiting = BladeStage1TerminalAdvance(
                _flow,
                _BladeStage1TerminalTestInput(BladeInputAction.Confirm)
            );
            BladeKernelTestAssertEqual(
                _waiting.action,
                BladeStage1TerminalAction.None,
                "Game Over ignores held menu input"
            );
        }
        var _return = BladeStage1TerminalAdvance(
            _flow,
            _BladeStage1TerminalTestInput(BladeInputAction.Confirm)
        );
        BladeKernelTestAssertEqual(
            _return.action,
            BladeStage1TerminalAction.ReturnToMain,
            "Game Over returns to the main menu"
        );
        BladeKernelTestAssertFalse(
            BladeStage1TerminalIsActive(_flow),
            "return action closes the terminal flow"
        );
        var _repeat = BladeStage1TerminalAdvance(
            _flow,
            _BladeStage1TerminalTestInput(BladeInputAction.Confirm)
        );
        BladeKernelTestAssertEqual(
            _repeat.action,
            BladeStage1TerminalAction.None,
            "return action cannot repeat"
        );
    });

    BladeKernelTestRunCase(_state, "terminal Cancel follows the safe No path", function() {
        var _flow = BladeStage1TerminalCreate();
        _BladeStage1TerminalTestOpen(_flow);
        var _cancel = BladeStage1TerminalAdvance(
            _flow,
            _BladeStage1TerminalTestInput(BladeInputAction.Cancel)
        );
        BladeKernelTestAssertEqual(
            _cancel.action,
            BladeStage1TerminalAction.BeginGameOver,
            "Cancel chooses No"
        );
        var _held_cancel = BladeStage1TerminalAdvance(
            _flow,
            _BladeStage1TerminalTestInput(BladeInputAction.Cancel)
        );
        BladeKernelTestAssertEqual(
            _held_cancel.action,
            BladeStage1TerminalAction.None,
            "Game Over ignores a repeated Cancel edge"
        );
    });
}
