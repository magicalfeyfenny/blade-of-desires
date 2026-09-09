/// @description Controller-owned Stage 1 pause menu and semantic input seam.

enum BladeStage1PauseAction {
    None = 0,
    Resume = 1,
    Retry = 2,
    QuitToMain = 3
}

#macro BLADE_STAGE1_PAUSE_STATE_VERSION 1
#macro BLADE_STAGE1_PAUSE_MENU_ITEM_COUNT 3

/// Returns the stable action labels used by the in-game pause menu.
function BladeStage1PauseMenuLabels() {
    return ["RESUME", "RETRY", "QUIT TO MAIN MENU"];
}

/// Creates a closed menu whose first selection is always Resume.
function BladeStage1PauseCreate() {
    return {
        __blade_stage1_pause_version: BLADE_STAGE1_PAUSE_STATE_VERSION,
        open: false,
        selected_index: 0,
    };
}

/// Creates the neutral presentation sample used before the first Begin Step.
function BladeStage1PauseInputNeutral() {
    return {
        move_x: int64(0),
        move_y: int64(0),
        pressed_move_x: 0,
        pressed_move_y: 0,
        held_actions: int64(0),
        pressed_actions: int64(0),
        prompt_device: BladePromptDevice.Unknown,
        gamepad_id: -1,
    };
}

/// Rejects malformed menu state before navigation can change its cursor.
function _BladeStage1PauseRequire(_menu) {
    if (!is_struct(_menu)
        || !variable_struct_exists(
            _menu, "__blade_stage1_pause_version"
        )
        || _menu.__blade_stage1_pause_version
            != BLADE_STAGE1_PAUSE_STATE_VERSION
        || !variable_struct_exists(_menu, "open")
        || !is_bool(_menu.open)
        || !variable_struct_exists(_menu, "selected_index")
        || _menu.selected_index < 0
        || _menu.selected_index >= BLADE_STAGE1_PAUSE_MENU_ITEM_COUNT) {
        throw("BladeStage1Pause: state is incomplete");
    }
}

/// Reads one optional edge from the shared live-input sample.
function _BladeStage1PausePressed(_input, _action) {
    if (!is_struct(_input)
        || !variable_struct_exists(_input, "pressed_actions")) {
        return false;
    }
    return BladeLiveInputActionPressed(_input, _action);
}

/// Reads one optional navigation edge from the shared live-input sample.
function _BladeStage1PauseMoveY(_input) {
    if (!is_struct(_input)
        || !variable_struct_exists(_input, "pressed_move_y")) {
        return 0;
    }
    if (_input.pressed_move_y < 0) return -1;
    if (_input.pressed_move_y > 0) return 1;
    return 0;
}

/// Moves the pause cursor once and wraps at the authored menu bounds.
function _BladeStage1PauseMove(_menu, _delta) {
    if (_delta == 0) return _menu.selected_index;
    _menu.selected_index = (
        _menu.selected_index + (_delta > 0 ? 1 : -1)
            + BLADE_STAGE1_PAUSE_MENU_ITEM_COUNT
    ) mod BLADE_STAGE1_PAUSE_MENU_ITEM_COUNT;
    return _menu.selected_index;
}

/// Converts the selected menu item into one controller action.
function _BladeStage1PauseSelectedAction(_selected_index) {
    switch (_selected_index) {
        case 0: return BladeStage1PauseAction.Resume;
        case 1: return BladeStage1PauseAction.Retry;
        case 2: return BladeStage1PauseAction.QuitToMain;
    }
    throw("BladeStage1Pause: selected menu item is unreachable");
}

/// Steps pause navigation and returns at most one one-frame controller action.
function BladeStage1PauseAdvance(_menu, _input, _can_open) {
    _BladeStage1PauseRequire(_menu);
    var _result = {
        action: BladeStage1PauseAction.None,
        opened: false,
        closed: false,
        selected_index: _menu.selected_index,
    };

    if (!_menu.open) {
        if (_can_open && _BladeStage1PausePressed(
            _input, BladeInputAction.Pause
        )) {
            _menu.open = true;
            _menu.selected_index = 0;
            _result.opened = true;
        }
        _result.selected_index = _menu.selected_index;
        return _result;
    }

    // Pause and Cancel both provide an immediate, semantic resume edge.
    if (_BladeStage1PausePressed(_input, BladeInputAction.Pause)
        || _BladeStage1PausePressed(_input, BladeInputAction.Cancel)) {
        _menu.open = false;
        _result.action = BladeStage1PauseAction.Resume;
        _result.closed = true;
        return _result;
    }

    var _move_y = _BladeStage1PauseMoveY(_input);
    if (_move_y != 0) {
        _BladeStage1PauseMove(_menu, _move_y);
        _result.selected_index = _menu.selected_index;
        return _result;
    }

    if (_BladeStage1PausePressed(_input, BladeInputAction.Confirm)) {
        _menu.open = false;
        _result.action = _BladeStage1PauseSelectedAction(
            _menu.selected_index
        );
        _result.closed = true;
    }
    _result.selected_index = _menu.selected_index;
    return _result;
}

/// Returns whether an active, nonterminal Stage 1 attempt may open its menu.
function BladeStage1PauseCanOpen(_controller) {
    return _controller.state == BladeFirstBeatState.Playing
        || _controller.state == BladeFirstBeatState.Rewarding;
}

/// Reads one controller field without assuming whether the caller is an instance or struct.
function _BladeStage1PauseControllerField(_controller, _name) {
    if (is_struct(_controller)) {
        if (!variable_struct_exists(_controller, _name)) return undefined;
        return variable_struct_get(_controller, _name);
    }
    if (!variable_instance_exists(_controller, _name)) return undefined;
    return variable_instance_get(_controller, _name);
}

/// Blocks gameplay while the menu or a one-frame menu action owns the controller.
function BladeStage1PauseGameplayAllowed(_controller) {
    if (_controller == noone) return false;

    var _menu = _BladeStage1PauseControllerField(
        _controller, "pause_menu"
    );
    if (is_struct(_menu)
        && variable_struct_exists(_menu, "open")
        && _menu.open) {
        return false;
    }

    var _action = _BladeStage1PauseControllerField(
        _controller, "pause_action"
    );
    if (!is_undefined(_action)
        && _action != BladeStage1PauseAction.None) {
        return false;
    }
    return true;
}

/// Draws the readable modal panel without changing gameplay geometry or state.
function BladeStage1PauseDraw(_menu, _config, _ui) {
    if (!is_struct(_menu) || !_menu.open) return;

    draw_set_alpha(0.78);
    draw_set_color(c_black);
    draw_rectangle(0, 0, 639, 359, true);
    draw_set_alpha(1);

    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_color(make_color_rgb(255, 232, 142));
    draw_text(320, 52, "PAUSED");

    var _labels = BladeStage1PauseMenuLabels();
    for (var _index = 0; _index < array_length(_labels); ++_index) {
        var _panel_y = 104 + _index * 42;
        BladeFrontendUiDrawPanel(
            _ui,
            _index == _menu.selected_index,
            170,
            _panel_y,
            300,
            32,
            0.96
        );
        draw_set_color(c_white);
        draw_text(320, _panel_y + 7, _labels[_index]);
    }

    var _confirm_label = "KEY";
    var _cancel_label = "KEY";
    if (is_struct(_config)
        && variable_struct_exists(_config, "bindings")
        && is_struct(_config.bindings)
        && variable_struct_exists(_config.bindings, "keyboard")) {
        var _keyboard = _config.bindings.keyboard;
        _confirm_label = BladeFrontendKeyboardLabel(
            variable_struct_get(_keyboard, "input.confirm")
        );
        _cancel_label = BladeFrontendKeyboardLabel(
            variable_struct_get(_keyboard, "input.cancel")
        );
    }
    draw_set_color(make_color_rgb(190, 231, 220));
    draw_text(
        320,
        250,
        "UP / DOWN  NAVIGATE\n"
            + _confirm_label + "  SELECT    " + _cancel_label + "  BACK"
    );
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_set_alpha(1);
}
