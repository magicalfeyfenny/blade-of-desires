/// @description Stage 1 terminal-death prompt and deterministic Game Over handoff.

enum BladeStage1TerminalPhase {
    Inactive = 0,
    ContinuePrompt = 1,
    GameOver = 2
}

enum BladeStage1TerminalAction {
    None = 0,
    ContinueRun = 1,
    BeginGameOver = 2,
    ReturnToMain = 3
}

#macro BLADE_STAGE1_TERMINAL_STATE_VERSION 1
#macro BLADE_STAGE1_TERMINAL_MENU_ITEM_COUNT 2
#macro BLADE_STAGE1_TERMINAL_GAME_OVER_TICKS 90

/// Returns the two choices in their stable player-facing order.
function BladeStage1TerminalLabels() {
    return ["YES", "NO"];
}

/// Creates an inactive terminal flow; a final committed death opens it once.
function BladeStage1TerminalCreate() {
    return {
        __blade_stage1_terminal_version: BLADE_STAGE1_TERMINAL_STATE_VERSION,
        phase: BladeStage1TerminalPhase.Inactive,
        selected_index: 0,
        game_over_ticks: 0,
    };
}

/// Rejects malformed terminal state before input can change its decision.
function _BladeStage1TerminalRequire(_flow) {
    if (!is_struct(_flow)
        || !variable_struct_exists(
            _flow, "__blade_stage1_terminal_version"
        )
        || _flow.__blade_stage1_terminal_version
            != BLADE_STAGE1_TERMINAL_STATE_VERSION
        || !variable_struct_exists(_flow, "phase")
        || _flow.phase < BladeStage1TerminalPhase.Inactive
        || _flow.phase > BladeStage1TerminalPhase.GameOver
        || !variable_struct_exists(_flow, "selected_index")
        || _flow.selected_index < 0
        || _flow.selected_index >= BLADE_STAGE1_TERMINAL_MENU_ITEM_COUNT
        || !variable_struct_exists(_flow, "game_over_ticks")
        || _flow.game_over_ticks < 0) {
        throw("BladeStage1Terminal: state is incomplete");
    }
}

/// Reads one optional edge from the shared semantic input sample.
function _BladeStage1TerminalPressed(_input, _action) {
    if (!is_struct(_input)
        || !variable_struct_exists(_input, "pressed_actions")) {
        return false;
    }
    return BladeLiveInputActionPressed(_input, _action);
}

/// Reads one optional navigation edge from the shared semantic input sample.
function _BladeStage1TerminalMoveY(_input) {
    if (!is_struct(_input)
        || !variable_struct_exists(_input, "pressed_move_y")) {
        return 0;
    }
    if (_input.pressed_move_y < 0) return -1;
    if (_input.pressed_move_y > 0) return 1;
    return 0;
}

/// Moves the terminal cursor once and wraps at the two authored choices.
function _BladeStage1TerminalMove(_flow, _delta) {
    if (_delta == 0) return _flow.selected_index;
    _flow.selected_index = (
        _flow.selected_index + (_delta > 0 ? 1 : -1)
            + BLADE_STAGE1_TERMINAL_MENU_ITEM_COUNT
    ) mod BLADE_STAGE1_TERMINAL_MENU_ITEM_COUNT;
    return _flow.selected_index;
}

/// Opens the Continue prompt once for the current terminal attempt.
function BladeStage1TerminalOpen(_flow) {
    _BladeStage1TerminalRequire(_flow);
    if (_flow.phase != BladeStage1TerminalPhase.Inactive) return false;
    _flow.phase = BladeStage1TerminalPhase.ContinuePrompt;
    _flow.selected_index = 0;
    _flow.game_over_ticks = 0;
    return true;
}

/// Returns whether the prompt or Game Over handoff still owns the frame.
function BladeStage1TerminalIsActive(_flow) {
    _BladeStage1TerminalRequire(_flow);
    return _flow.phase != BladeStage1TerminalPhase.Inactive;
}

/// Advances one terminal frame and emits at most one one-shot lifecycle action.
function BladeStage1TerminalAdvance(_flow, _input) {
    _BladeStage1TerminalRequire(_flow);
    var _result = {
        action: BladeStage1TerminalAction.None,
        phase: _flow.phase,
        selected_index: _flow.selected_index,
        game_over_ticks: _flow.game_over_ticks,
    };

    if (_flow.phase == BladeStage1TerminalPhase.Inactive) return _result;

    if (_flow.phase == BladeStage1TerminalPhase.GameOver) {
        _flow.game_over_ticks = max(0, _flow.game_over_ticks - 1);
        if (_flow.game_over_ticks == 0) {
            _flow.phase = BladeStage1TerminalPhase.Inactive;
            _result.action = BladeStage1TerminalAction.ReturnToMain;
        }
        _result.phase = _flow.phase;
        _result.game_over_ticks = _flow.game_over_ticks;
        return _result;
    }

    // Navigation consumes the frame before confirmation can activate a choice.
    var _move_y = _BladeStage1TerminalMoveY(_input);
    if (_move_y != 0) {
        _BladeStage1TerminalMove(_flow, _move_y);
        _result.selected_index = _flow.selected_index;
        return _result;
    }

    // Back is the safe No path; it cannot also confirm Yes in the same frame.
    var _choose_no = _BladeStage1TerminalPressed(
        _input, BladeInputAction.Cancel
    );
    var _choose_yes_or_no = _BladeStage1TerminalPressed(
        _input, BladeInputAction.Confirm
    );
    if (!_choose_no && !_choose_yes_or_no) return _result;

    if (_choose_no || _flow.selected_index == 1) {
        _flow.phase = BladeStage1TerminalPhase.GameOver;
        _flow.game_over_ticks = BLADE_STAGE1_TERMINAL_GAME_OVER_TICKS;
        _result.action = BladeStage1TerminalAction.BeginGameOver;
    } else {
        _flow.phase = BladeStage1TerminalPhase.Inactive;
        _flow.game_over_ticks = 0;
        _result.action = BladeStage1TerminalAction.ContinueRun;
    }
    _result.phase = _flow.phase;
    _result.selected_index = _flow.selected_index;
    _result.game_over_ticks = _flow.game_over_ticks;
    return _result;
}

/// Returns a configured device label when the runtime has a valid config.
function _BladeStage1TerminalKeyboardLabel(_config, _binding_id, _fallback) {
    if (is_struct(_config)
        && variable_struct_exists(_config, "bindings")
        && is_struct(_config.bindings)
        && variable_struct_exists(_config.bindings, "keyboard")) {
        var _keyboard = _config.bindings.keyboard;
        if (variable_struct_exists(_keyboard, _binding_id)) {
            return BladeFrontendKeyboardLabel(
                variable_struct_get(_keyboard, _binding_id)
            );
        }
    }
    return _fallback;
}

/// Returns a configured gamepad label without coupling terminal logic to codes.
function _BladeStage1TerminalGamepadLabel(_config, _binding_id, _fallback) {
    if (is_struct(_config)
        && variable_struct_exists(_config, "bindings")
        && is_struct(_config.bindings)
        && variable_struct_exists(_config.bindings, "gamepad")) {
        var _gamepad = _config.bindings.gamepad;
        if (variable_struct_exists(_gamepad, _binding_id)) {
            return BladeFrontendGamepadLabel(
                variable_struct_get(_gamepad, _binding_id)
            );
        }
    }
    return _fallback;
}

/// Draws Continue? or Game Over without changing combat geometry or state.
function BladeStage1TerminalDraw(_flow, _config, _ui) {
    _BladeStage1TerminalRequire(_flow);
    if (_flow.phase == BladeStage1TerminalPhase.Inactive) return;

    draw_set_alpha(0.84);
    draw_set_color(c_black);
    draw_rectangle(178, 104, 462, 272, true);
    draw_set_alpha(1);
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_color(make_color_rgb(255, 232, 142));

    if (_flow.phase == BladeStage1TerminalPhase.ContinuePrompt) {
        draw_text(320, 118, "NO LIVES REMAIN\n\nCONTINUE?");
        var _labels = BladeStage1TerminalLabels();
        for (var _index = 0; _index < array_length(_labels); ++_index) {
            var _panel_y = 194 + _index * 34;
            if (is_struct(_ui)) {
                BladeFrontendUiDrawPanel(
                    _ui,
                    _index == _flow.selected_index,
                    246,
                    _panel_y,
                    148,
                    26,
                    0.96
                );
            } else {
                draw_set_color(
                    _index == _flow.selected_index
                        ? make_color_rgb(70, 130, 104)
                        : make_color_rgb(30, 54, 54)
                );
                draw_rectangle(246, _panel_y, 394, _panel_y + 26, true);
            }
            draw_set_color(c_white);
            draw_text(320, _panel_y + 4, _labels[_index]);
        }
        var _confirm_label = _BladeStage1TerminalKeyboardLabel(
            _config, "input.confirm", "CONFIRM"
        );
        var _cancel_label = _BladeStage1TerminalKeyboardLabel(
            _config, "input.cancel", "BACK"
        );
        var _confirm_gamepad = _BladeStage1TerminalGamepadLabel(
            _config, "input.confirm", "CONFIRM"
        );
        var _cancel_gamepad = _BladeStage1TerminalGamepadLabel(
            _config, "input.cancel", "BACK"
        );
        draw_set_color(make_color_rgb(190, 231, 220));
        draw_text(
            320,
            266,
            "UP / DOWN  NAVIGATE\n"
                + _confirm_label + " / " + _confirm_gamepad
                + "  SELECT    " + _cancel_label + " / " + _cancel_gamepad
                + "  NO"
        );
    } else {
        draw_set_color(c_white);
        draw_text(
            320,
            150,
            "GAME OVER\n\nRETURNING TO MAIN MENU"
        );
    }

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_set_alpha(1);
}
