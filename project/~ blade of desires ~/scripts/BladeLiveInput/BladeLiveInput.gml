/// @description Platform input adapter for the shared semantic action model.

#macro BLADE_LIVE_INPUT_MIN_GAMEPAD_SLOTS 12
#macro BLADE_LIVE_INPUT_MAX_GAMEPAD_SLOTS 32
#macro BLADE_LIVE_INPUT_AXIS_SCALE 1024

/// Creates the owner-local edge latch used by one front-end or run instance.
/// The latch is deliberately separate from deterministic replay state.
function BladeLiveInputStateCreate() {
    return {
        __blade_live_input_state_version: 1,
        has_sample: false,
        last_held_actions: int64(0),
        last_move_x: int64(0),
        last_move_y: int64(0),
        last_gamepad_id: -1,
    };
}

/// Rejects a missing or foreign input latch before sampling can mutate it.
function _BladeLiveInputStateRequire(_state) {
    if (!is_struct(_state)
        || !variable_struct_exists(_state, "__blade_live_input_state_version")
        || _state.__blade_live_input_state_version != 1
        || !variable_struct_exists(_state, "has_sample")
        || !is_bool(_state.has_sample)
        || !variable_struct_exists(_state, "last_held_actions")
        || !variable_struct_exists(_state, "last_move_x")
        || !variable_struct_exists(_state, "last_move_y")
        || !variable_struct_exists(_state, "last_gamepad_id")) {
        throw("BladeLiveInput: state is incomplete");
    }
}

/// Resets one owner-local edge latch when a room or input context is rebuilt.
function BladeLiveInputStateReset(_state) {
    _BladeLiveInputStateRequire(_state);
    _state.has_sample = false;
    _state.last_held_actions = int64(0);
    _state.last_move_x = int64(0);
    _state.last_move_y = int64(0);
    _state.last_gamepad_id = -1;
    return _state;
}

/// Returns the signed direction of one fixed-point movement value.
function _BladeLiveInputDirection(_value) {
    if (_value < 0) return -1;
    if (_value > 0) return 1;
    return 0;
}

/// Creates a semantic source sample for deterministic adapter composition tests.
/// Source values contain no platform key codes or controller identity.
function BladeLiveInputSourceCreate(
    _move_x = 0,
    _move_y = 0,
    _pressed_move_x = 0,
    _pressed_move_y = 0,
    _held_actions = 0,
    _pressed_actions = 0,
    _prompt_device = BladePromptDevice.Unknown,
    _has_analog = false,
    _analog_x = 0,
    _analog_y = 0
) {
    return {
        move_x: int64(clamp(_move_x, -BLADE_LIVE_INPUT_AXIS_SCALE, BLADE_LIVE_INPUT_AXIS_SCALE)),
        move_y: int64(clamp(_move_y, -BLADE_LIVE_INPUT_AXIS_SCALE, BLADE_LIVE_INPUT_AXIS_SCALE)),
        pressed_move_x: clamp(_pressed_move_x, -1, 1),
        pressed_move_y: clamp(_pressed_move_y, -1, 1),
        held_actions: int64(_held_actions),
        pressed_actions: int64(_pressed_actions),
        prompt_device: _prompt_device,
        has_analog: _has_analog,
        analog_x: int64(clamp(_analog_x, -32767, 32767)),
        analog_y: int64(clamp(_analog_y, -32767, 32767)),
        active: _move_x != 0
            || _move_y != 0
            || _pressed_move_x != 0
            || _pressed_move_y != 0
            || _held_actions != 0
            || _pressed_actions != 0,
    };
}

/// Validates a platform-neutral source sample before it enters the shared seam.
function _BladeLiveInputSourceRequire(_source) {
    if (!is_struct(_source)
        || !variable_struct_exists(_source, "move_x")
        || !variable_struct_exists(_source, "move_y")
        || !variable_struct_exists(_source, "pressed_move_x")
        || !variable_struct_exists(_source, "pressed_move_y")
        || !variable_struct_exists(_source, "held_actions")
        || !variable_struct_exists(_source, "pressed_actions")
        || !variable_struct_exists(_source, "active")) {
        throw("BladeLiveInput: source sample is incomplete");
    }
}

/// Converts raw source edges into semantic action edges without duplicate presses.
function _BladeLiveInputActionEdges(
    _held_actions,
    _raw_pressed_actions,
    _state
) {
    if (!_state.has_sample) return int64(_raw_pressed_actions);

    var _result = int64(0);
    var _bits = [
        BladeInputAction.Fire,
        BladeInputAction.Bomb,
        BladeInputAction.Focus,
        BladeInputAction.Pause,
        BladeInputAction.Confirm,
        BladeInputAction.Cancel,
    ];
    for (var _index = 0; _index < array_length(_bits); ++_index) {
        var _bit = int64(_bits[_index]);
        if ((_raw_pressed_actions & _bit) != 0
            && (_held_actions & _bit) != 0
            && (_state.last_held_actions & _bit) == 0) {
            _result = _result | _bit;
        }
    }
    return _result;
}

/// Merges keyboard and gamepad semantic source states into one stable frame.
/// Device changes affect only source selection and prompt metadata, never action identity.
function BladeLiveInputCompose(_state, _keyboard, _gamepad, _gamepad_id) {
    _BladeLiveInputStateRequire(_state);
    _BladeLiveInputSourceRequire(_keyboard);
    _BladeLiveInputSourceRequire(_gamepad);

    var _move_x = int64(clamp(
        _keyboard.move_x + _gamepad.move_x,
        -BLADE_LIVE_INPUT_AXIS_SCALE,
        BLADE_LIVE_INPUT_AXIS_SCALE
    ));
    var _move_y = int64(clamp(
        _keyboard.move_y + _gamepad.move_y,
        -BLADE_LIVE_INPUT_AXIS_SCALE,
        BLADE_LIVE_INPUT_AXIS_SCALE
    ));
    var _held_actions = int64(
        _keyboard.held_actions | _gamepad.held_actions
    );
    var _raw_pressed_actions = int64(
        _keyboard.pressed_actions | _gamepad.pressed_actions
    );
    var _pressed_actions = _BladeLiveInputActionEdges(
        _held_actions,
        _raw_pressed_actions,
        _state
    );

    var _direction_x = _BladeLiveInputDirection(_move_x);
    var _direction_y = _BladeLiveInputDirection(_move_y);
    var _pressed_move_x = 0;
    var _pressed_move_y = 0;
    if (_state.has_sample) {
        if (_direction_x != _BladeLiveInputDirection(_state.last_move_x)) {
            _pressed_move_x = _direction_x;
        }
        if (_direction_y != _BladeLiveInputDirection(_state.last_move_y)) {
            _pressed_move_y = _direction_y;
        }
    } else {
        _pressed_move_x = _BladeLiveInputDirection(
            _keyboard.pressed_move_x + _gamepad.pressed_move_x
        );
        _pressed_move_y = _BladeLiveInputDirection(
            _keyboard.pressed_move_y + _gamepad.pressed_move_y
        );
    }

    var _prompt_device = BladePromptDevice.Unknown;
    if (_gamepad.active) {
        _prompt_device = BladePromptDevice.Gamepad;
    } else if (_keyboard.active) {
        _prompt_device = BladePromptDevice.KeyboardMouse;
    }

    var _sample = {
        move_x: _move_x,
        move_y: _move_y,
        pressed_move_x: _pressed_move_x,
        pressed_move_y: _pressed_move_y,
        held_actions: _held_actions,
        pressed_actions: _pressed_actions,
        prompt_device: _prompt_device,
        gamepad_id: _gamepad_id,
        has_analog: _gamepad.has_analog,
        analog_x: _gamepad.analog_x,
        analog_y: _gamepad.analog_y,
    };

    _state.has_sample = true;
    _state.last_held_actions = _held_actions;
    _state.last_move_x = _move_x;
    _state.last_move_y = _move_y;
    _state.last_gamepad_id = _gamepad_id;
    return _sample;
}

// Returns the first connected pad across the available GameMaker slots.
// The minimum scan covers XInput/DirectInput; the reported count extends it
// for platforms that reserve higher slot indices for reconnecting devices.
function _BladeLiveInputConnectedGamepad() {
    if (!gamepad_is_supported()) return -1;

    var _slot_count = BLADE_LIVE_INPUT_MIN_GAMEPAD_SLOTS;
    var _reported_count = gamepad_get_device_count();
    if (is_real(_reported_count)) {
        _slot_count = max(_slot_count, floor(_reported_count));
    }
    _slot_count = min(_slot_count, BLADE_LIVE_INPUT_MAX_GAMEPAD_SLOTS);
    for (var _index = 0; _index < _slot_count; ++_index) {
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

// Reads one configured keyboard action without consulting controller state.
function _BladeLiveInputKeyboardActionCheck(_config, _stable_id, _pressed) {
    return _BladeLiveInputKeyboardCheck(
        _config.bindings.keyboard, _stable_id, _pressed
    );
}

// Reads one configured gamepad action without consulting keyboard state.
function _BladeLiveInputGamepadActionCheck(
    _config, _stable_id, _gamepad_id, _pressed
) {
    return _BladeLiveInputGamepadCheck(
        _config.bindings.gamepad, _stable_id, _gamepad_id, _pressed
    );
}

/// Reads all configured keyboard movement/action sources into a semantic sample.
function _BladeLiveInputKeyboardSource(_config) {
    var _keyboard = _config.bindings.keyboard;
    var _left = _BladeLiveInputKeyboardCheck(
        _keyboard, "input.move_left", false
    );
    var _right = _BladeLiveInputKeyboardCheck(
        _keyboard, "input.move_right", false
    );
    var _up = _BladeLiveInputKeyboardCheck(
        _keyboard, "input.move_up", false
    );
    var _down = _BladeLiveInputKeyboardCheck(
        _keyboard, "input.move_down", false
    );
    var _left_pressed = _BladeLiveInputKeyboardCheck(
        _keyboard, "input.move_left", true
    );
    var _right_pressed = _BladeLiveInputKeyboardCheck(
        _keyboard, "input.move_right", true
    );
    var _up_pressed = _BladeLiveInputKeyboardCheck(
        _keyboard, "input.move_up", true
    );
    var _down_pressed = _BladeLiveInputKeyboardCheck(
        _keyboard, "input.move_down", true
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
        if (_BladeLiveInputKeyboardActionCheck(_config, _stable_id, false)) {
            _held_actions = _held_actions | _bit;
        }
        if (_BladeLiveInputKeyboardActionCheck(_config, _stable_id, true)) {
            _pressed_actions = _pressed_actions | _bit;
        }
    }

    return BladeLiveInputSourceCreate(
        (bool(_right) - bool(_left)) * BLADE_LIVE_INPUT_AXIS_SCALE,
        (bool(_down) - bool(_up)) * BLADE_LIVE_INPUT_AXIS_SCALE,
        bool(_right_pressed) - bool(_left_pressed),
        bool(_down_pressed) - bool(_up_pressed),
        _held_actions,
        _pressed_actions,
        BladePromptDevice.KeyboardMouse
    );
}

/// Reads a normalized left stick plus configured digital gamepad bindings.
function _BladeLiveInputGamepadAxis(_gamepad_id, _axis) {
    var _value = gamepad_axis_value(_gamepad_id, _axis);
    if (!is_real(_value) || is_nan(_value) || is_infinity(_value)) return 0;
    return clamp(_value, -1, 1);
}

function _BladeLiveInputGamepadSource(_config, _gamepad_id) {
    if (_gamepad_id < 0) {
        return BladeLiveInputSourceCreate();
    }

    var _gamepad = _config.bindings.gamepad;
    var _left = _BladeLiveInputGamepadCheck(
        _gamepad, "input.move_left", _gamepad_id, false
    );
    var _right = _BladeLiveInputGamepadCheck(
        _gamepad, "input.move_right", _gamepad_id, false
    );
    var _up = _BladeLiveInputGamepadCheck(
        _gamepad, "input.move_up", _gamepad_id, false
    );
    var _down = _BladeLiveInputGamepadCheck(
        _gamepad, "input.move_down", _gamepad_id, false
    );
    var _left_pressed = _BladeLiveInputGamepadCheck(
        _gamepad, "input.move_left", _gamepad_id, true
    );
    var _right_pressed = _BladeLiveInputGamepadCheck(
        _gamepad, "input.move_right", _gamepad_id, true
    );
    var _up_pressed = _BladeLiveInputGamepadCheck(
        _gamepad, "input.move_up", _gamepad_id, true
    );
    var _down_pressed = _BladeLiveInputGamepadCheck(
        _gamepad, "input.move_down", _gamepad_id, true
    );
    var _axis_x = _BladeLiveInputGamepadAxis(_gamepad_id, gp_axislh);
    var _axis_y = _BladeLiveInputGamepadAxis(_gamepad_id, gp_axislv);
    var _digital_x = bool(_right) - bool(_left);
    var _digital_y = bool(_down) - bool(_up);

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
        if (_BladeLiveInputGamepadActionCheck(
            _config, _stable_id, _gamepad_id, false
        )) {
            _held_actions = _held_actions | _bit;
        }
        if (_BladeLiveInputGamepadActionCheck(
            _config, _stable_id, _gamepad_id, true
        )) {
            _pressed_actions = _pressed_actions | _bit;
        }
    }

    return BladeLiveInputSourceCreate(
        clamp(
            _digital_x * BLADE_LIVE_INPUT_AXIS_SCALE
                + round(_axis_x * BLADE_LIVE_INPUT_AXIS_SCALE),
            -BLADE_LIVE_INPUT_AXIS_SCALE,
            BLADE_LIVE_INPUT_AXIS_SCALE
        ),
        clamp(
            _digital_y * BLADE_LIVE_INPUT_AXIS_SCALE
                + round(_axis_y * BLADE_LIVE_INPUT_AXIS_SCALE),
            -BLADE_LIVE_INPUT_AXIS_SCALE,
            BLADE_LIVE_INPUT_AXIS_SCALE
        ),
        bool(_right_pressed) - bool(_left_pressed),
        bool(_down_pressed) - bool(_up_pressed),
        _held_actions,
        _pressed_actions,
        BladePromptDevice.Gamepad,
        true,
        round(_axis_x * 32767),
        round(_axis_y * 32767)
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

/// Returns the first supported gamepad button pressed on one connected device.
/// Axis movement remains a movement source; remappable bindings are buttons.
function BladeLiveInputGamepadBindingPressed(_gamepad_id) {
    if (_gamepad_id < 0) return -1;
    var _codes = BladeConfigGamepadBindingCodes();
    for (var _index = 0; _index < array_length(_codes); ++_index) {
        if (gamepad_button_check_pressed(_gamepad_id, _codes[_index])) {
            return _codes[_index];
        }
    }
    return -1;
}

/// @func BladeLiveInputSample(config, state)
/// Samples keyboard and the first connected gamepad into one semantic frame.
/// The returned values are presentation input; deterministic simulation still
/// consumes the existing immutable BladeInputSnapshot contract.
function BladeLiveInputSample(_config, _state = undefined) {
    var _sample_state = _state;
    if (is_undefined(_sample_state)) {
        _sample_state = BladeLiveInputStateCreate();
    }
    var _gamepad_id = _BladeLiveInputConnectedGamepad();
    var _keyboard = _BladeLiveInputKeyboardSource(_config);
    var _gamepad = _BladeLiveInputGamepadSource(_config, _gamepad_id);
    return BladeLiveInputCompose(
        _sample_state,
        _keyboard,
        _gamepad,
        _gamepad_id
    );
}
