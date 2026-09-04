/// @description Platform input adapter for the shared semantic action model.

// Returns the first connected pad so menus can use the same configured actions
// without retaining a device-specific path in their state.
function _BladeLiveInputConnectedGamepad() {
    for (var _index = 0; _index < 4; ++_index) {
        if (gamepad_is_connected(_index)) return _index;
    }
    return -1;
}

// Reads one configured keyboard binding as a held or edge-triggered signal.
function _BladeLiveInputKeyboardCheck(_bindings, _stable_id, _pressed) {
    var _code = variable_struct_get(_bindings, _stable_id);
    return _pressed
        ? keyboard_check_pressed(_code)
        : keyboard_check(_code);
}

// Reads one configured gamepad binding when a pad is available.
function _BladeLiveInputGamepadCheck(
    _bindings, _stable_id, _gamepad_id, _pressed
) {
    if (_gamepad_id < 0) return false;
    var _code = variable_struct_get(_bindings, _stable_id);
    return _pressed
        ? gamepad_button_check_pressed(_gamepad_id, _code)
        : gamepad_button_check(_gamepad_id, _code);
}

// Reads one action through both device adapters and preserves semantic identity.
function _BladeLiveInputActionCheck(
    _config, _stable_id, _gamepad_id, _pressed
) {
    return _BladeLiveInputKeyboardCheck(
        _config.bindings.keyboard, _stable_id, _pressed
    ) || _BladeLiveInputGamepadCheck(
        _config.bindings.gamepad, _stable_id, _gamepad_id, _pressed
    );
}

/// @func BladeLiveInputActionPressed(sample, action_bit)
/// Returns whether one semantic action began on this presentation frame.
function BladeLiveInputActionPressed(_sample, _action_bit) {
    return (_sample.pressed_actions & _action_bit) != 0;
}

/// @func BladeLiveInputActionHeld(sample, action_bit)
/// Returns whether one semantic action is held on this presentation frame.
function BladeLiveInputActionHeld(_sample, _action_bit) {
    return (_sample.held_actions & _action_bit) != 0;
}

/// @func BladeLiveInputSample(config)
/// Samples keyboard and the first connected gamepad into one semantic frame.
/// The returned values are presentation input; deterministic simulation still
/// consumes the existing immutable BladeInputSnapshot contract.
function BladeLiveInputSample(_config) {
    var _gamepad_id = _BladeLiveInputConnectedGamepad();
    var _keyboard = _config.bindings.keyboard;
    var _gamepad = _config.bindings.gamepad;

    var _keyboard_left = _BladeLiveInputKeyboardCheck(
        _keyboard, "input.move_left", false
    );
    var _keyboard_right = _BladeLiveInputKeyboardCheck(
        _keyboard, "input.move_right", false
    );
    var _keyboard_up = _BladeLiveInputKeyboardCheck(
        _keyboard, "input.move_up", false
    );
    var _keyboard_down = _BladeLiveInputKeyboardCheck(
        _keyboard, "input.move_down", false
    );
    var _keyboard_left_pressed = _BladeLiveInputKeyboardCheck(
        _keyboard, "input.move_left", true
    );
    var _keyboard_right_pressed = _BladeLiveInputKeyboardCheck(
        _keyboard, "input.move_right", true
    );
    var _keyboard_up_pressed = _BladeLiveInputKeyboardCheck(
        _keyboard, "input.move_up", true
    );
    var _keyboard_down_pressed = _BladeLiveInputKeyboardCheck(
        _keyboard, "input.move_down", true
    );

    var _gamepad_left = _BladeLiveInputGamepadCheck(
        _gamepad, "input.move_left", _gamepad_id, false
    );
    var _gamepad_right = _BladeLiveInputGamepadCheck(
        _gamepad, "input.move_right", _gamepad_id, false
    );
    var _gamepad_up = _BladeLiveInputGamepadCheck(
        _gamepad, "input.move_up", _gamepad_id, false
    );
    var _gamepad_down = _BladeLiveInputGamepadCheck(
        _gamepad, "input.move_down", _gamepad_id, false
    );
    var _gamepad_left_pressed = _BladeLiveInputGamepadCheck(
        _gamepad, "input.move_left", _gamepad_id, true
    );
    var _gamepad_right_pressed = _BladeLiveInputGamepadCheck(
        _gamepad, "input.move_right", _gamepad_id, true
    );
    var _gamepad_up_pressed = _BladeLiveInputGamepadCheck(
        _gamepad, "input.move_up", _gamepad_id, true
    );
    var _gamepad_down_pressed = _BladeLiveInputGamepadCheck(
        _gamepad, "input.move_down", _gamepad_id, true
    );

    var _held_actions = int64(0);
    var _pressed_actions = int64(0);
    var _action_ids = [
        "input.fire", "input.bomb", "input.focus",
        "input.pause", "input.confirm", "input.cancel",
    ];
    for (var _action_index = 0;
        _action_index < array_length(_action_ids);
        ++_action_index) {
        var _stable_id = _action_ids[_action_index];
        var _bit = BladeInputBindingRecord(_stable_id).action_bit;
        if (_BladeLiveInputActionCheck(
            _config, _stable_id, _gamepad_id, false
        )) {
            _held_actions = _held_actions | _bit;
        }
        if (_BladeLiveInputActionCheck(
            _config, _stable_id, _gamepad_id, true
        )) {
            _pressed_actions = _pressed_actions | _bit;
        }
    }

    var _keyboard_move_x = bool(_keyboard_right) - bool(_keyboard_left);
    var _keyboard_move_y = bool(_keyboard_down) - bool(_keyboard_up);
    var _gamepad_move_x = bool(_gamepad_right) - bool(_gamepad_left);
    var _gamepad_move_y = bool(_gamepad_down) - bool(_gamepad_up);
    var _move_x = clamp(_keyboard_move_x + _gamepad_move_x, -1, 1);
    var _move_y = clamp(_keyboard_move_y + _gamepad_move_y, -1, 1);

    var _keyboard_pressed_x = bool(_keyboard_right_pressed)
        - bool(_keyboard_left_pressed);
    var _keyboard_pressed_y = bool(_keyboard_down_pressed)
        - bool(_keyboard_up_pressed);
    var _gamepad_pressed_x = bool(_gamepad_right_pressed)
        - bool(_gamepad_left_pressed);
    var _gamepad_pressed_y = bool(_gamepad_down_pressed)
        - bool(_gamepad_up_pressed);

    var _keyboard_activity = _keyboard_move_x != 0
        || _keyboard_move_y != 0
        || _keyboard_pressed_x != 0
        || _keyboard_pressed_y != 0;
    var _gamepad_activity = _gamepad_move_x != 0
        || _gamepad_move_y != 0
        || _gamepad_pressed_x != 0
        || _gamepad_pressed_y != 0;
    var _prompt_device = BladePromptDevice.Unknown;
    if (_gamepad_activity) {
        _prompt_device = BladePromptDevice.Gamepad;
    } else if (_keyboard_activity || _held_actions != 0 || _pressed_actions != 0) {
        _prompt_device = BladePromptDevice.KeyboardMouse;
    }

    return {
        move_x: int64(_move_x * 1024),
        move_y: int64(_move_y * 1024),
        pressed_move_x: _keyboard_pressed_x + _gamepad_pressed_x,
        pressed_move_y: _keyboard_pressed_y + _gamepad_pressed_y,
        held_actions: _held_actions,
        pressed_actions: _pressed_actions,
        prompt_device: _prompt_device,
        gamepad_id: _gamepad_id,
    };
}
