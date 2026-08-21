/// @description Version 1 user-config defaults, validation, and normalization.

/// @func BladeConfigFormatId()
/// Returns the discriminator that keeps config JSON distinct from later save formats.
function BladeConfigFormatId() {
    return "blade.config";
}
/// @func BladeConfigSchemaVersion()
/// Returns the only config schema version understood by this persistence slice.
function BladeConfigSchemaVersion() {
    return 1;
}

/// @func BladeConfigFilename()
/// Returns the production filename relative to GameMaker's per-user save area.
function BladeConfigFilename() {
    return "blade-config.json";
}

/// Returns whether a numeric value is finite and already represents an integer.
function _BladeConfigFiniteInteger(_value) {
    return is_real(_value)
        && !is_bool(_value)
        && !is_nan(_value)
        && !is_infinity(_value)
        && floor(_value) == _value;
}

/// Returns the default keyboard code for one canonical stable binding ID.
function _BladeConfigKeyboardDefaultCode(_stable_id) {
    switch (_stable_id) {
        case "input.move_up": return vk_up;
        case "input.move_down": return vk_down;
        case "input.move_left": return vk_left;
        case "input.move_right": return vk_right;
        case "input.fire": return ord("Z");
        case "input.bomb": return ord("X");
        case "input.focus": return vk_shift;
        case "input.pause": return vk_escape;
        case "input.confirm": return ord("Z");
        case "input.cancel": return ord("X");
    }
    throw("BladeConfigPayload: no keyboard default for " + string(_stable_id));
}

/// Returns the default gamepad code for one canonical stable binding ID.
function _BladeConfigGamepadDefaultCode(_stable_id) {
    switch (_stable_id) {
        case "input.move_up": return gp_padu;
        case "input.move_down": return gp_padd;
        case "input.move_left": return gp_padl;
        case "input.move_right": return gp_padr;
        case "input.fire": return gp_face1;
        case "input.bomb": return gp_face2;
        case "input.focus": return gp_shoulderl;
        case "input.pause": return gp_start;
        case "input.confirm": return gp_face1;
        case "input.cancel": return gp_face2;
    }
    throw("BladeConfigPayload: no gamepad default for " + string(_stable_id));
}

/// Creates one complete binding map in the canonical registry order.
function _BladeConfigBindingMapCreateDefault(_keyboard) {
    var _result = {};
    var _records = BladeInputBindingRecords();
    for (var _index = 0; _index < array_length(_records); ++_index) {
        var _stable_id = _records[_index].stable_id;
        var _code = _keyboard
            ? _BladeConfigKeyboardDefaultCode(_stable_id)
            : _BladeConfigGamepadDefaultCode(_stable_id);
        variable_struct_set(_result, _stable_id, _code);
    }
    return _result;
}

/// @func BladeConfigCreateDefault()
/// Creates a detached, complete version 1 config with conservative platform defaults.
function BladeConfigCreateDefault() {
    return {
        format_id: BladeConfigFormatId(),
        schema_version: BladeConfigSchemaVersion(),
        display: {
            fullscreen: false,
            window_scale: 2,
            vsync: true,
        },
        audio: {
            master_gain_percent: 100,
            music_gain_percent: 100,
            sfx_gain_percent: 100,
        },
        bindings: {
            keyboard: _BladeConfigBindingMapCreateDefault(true),
            gamepad: _BladeConfigBindingMapCreateDefault(false),
        },
    };
}

/// @func BladeConfigKeyboardCodeIsSupported(code)
/// Accepts only finite integer keyboard codes that the future remapper can name clearly.
function BladeConfigKeyboardCodeIsSupported(_code) {
    if (!_BladeConfigFiniteInteger(_code)) {
        return false;
    }
    if ((_code >= ord("A") && _code <= ord("Z"))
        || (_code >= ord("0") && _code <= ord("9"))) {
        return true;
    }

    var _special_codes = [
        vk_left, vk_right, vk_up, vk_down,
        vk_enter, vk_escape, vk_space, vk_shift, vk_control, vk_alt, vk_tab,
        vk_home, vk_end, vk_delete, vk_insert, vk_pageup, vk_pagedown, vk_pause,
        vk_f1, vk_f2, vk_f3, vk_f4, vk_f5, vk_f6,
        vk_f7, vk_f8, vk_f9, vk_f10, vk_f11, vk_f12,
    ];
    for (var _index = 0; _index < array_length(_special_codes); ++_index) {
        if (_code == _special_codes[_index]) {
            return true;
        }
    }
    return false;
}

/// @func BladeConfigGamepadCodeIsSupported(code)
/// Accepts only finite integer digital buttons supported by the minimal binding schema.
function BladeConfigGamepadCodeIsSupported(_code) {
    if (!_BladeConfigFiniteInteger(_code)) {
        return false;
    }
    var _supported_codes = [
        gp_face1, gp_face2, gp_face3, gp_face4,
        gp_shoulderl, gp_shoulderr, gp_shoulderlb, gp_shoulderrb,
        gp_start, gp_select, gp_stickl, gp_stickr,
        gp_padu, gp_padd, gp_padl, gp_padr,
    ];
    for (var _index = 0; _index < array_length(_supported_codes); ++_index) {
        if (_code == _supported_codes[_index]) {
            return true;
        }
    }
    return false;
}

/// Clamps one finite numeric setting to an integer range or keeps its fallback.
function _BladeConfigClampedInteger(_value, _fallback, _minimum, _maximum) {
    if (!is_real(_value) || is_bool(_value)
        || is_nan(_value) || is_infinity(_value)) {
        return _fallback;
    }
    return clamp(round(_value), _minimum, _maximum);
}

/// Overlays recognized keyboard codes while preserving every malformed default.
function _BladeConfigKeyboardBindingsNormalize(_source, _defaults) {
    var _result = _BladeConfigBindingMapCreateDefault(true);
    if (!is_struct(_source)) {
        return _result;
    }

    var _records = BladeInputBindingRecords();
    for (var _index = 0; _index < array_length(_records); ++_index) {
        var _stable_id = _records[_index].stable_id;
        if (variable_struct_exists(_source, _stable_id)) {
            var _code = variable_struct_get(_source, _stable_id);
            if (BladeConfigKeyboardCodeIsSupported(_code)) {
                variable_struct_set(_result, _stable_id, _code);
            } else {
                variable_struct_set(
                    _result,
                    _stable_id,
                    variable_struct_get(_defaults, _stable_id)
                );
            }
        }
    }
    return _result;
}

/// Overlays recognized gamepad codes while preserving every malformed default.
function _BladeConfigGamepadBindingsNormalize(_source, _defaults) {
    var _result = _BladeConfigBindingMapCreateDefault(false);
    if (!is_struct(_source)) {
        return _result;
    }

    var _records = BladeInputBindingRecords();
    for (var _index = 0; _index < array_length(_records); ++_index) {
        var _stable_id = _records[_index].stable_id;
        if (variable_struct_exists(_source, _stable_id)) {
            var _code = variable_struct_get(_source, _stable_id);
            if (BladeConfigGamepadCodeIsSupported(_code)) {
                variable_struct_set(_result, _stable_id, _code);
            } else {
                variable_struct_set(
                    _result,
                    _stable_id,
                    variable_struct_get(_defaults, _stable_id)
                );
            }
        }
    }
    return _result;
}

/// Returns whether a source declares the exact supported config identity and version.
function _BladeConfigIdentityIsSupported(_source) {
    return is_struct(_source)
        && variable_struct_exists(_source, "format_id")
        && is_string(_source.format_id)
        && _source.format_id == BladeConfigFormatId()
        && variable_struct_exists(_source, "schema_version")
        && _BladeConfigFiniteInteger(_source.schema_version)
        && _source.schema_version == BladeConfigSchemaVersion();
}

/// @func BladeConfigNormalize(source)
/// Starts from fresh defaults and overlays only recognized valid version 1 fields.
function BladeConfigNormalize(_source) {
    var _result = BladeConfigCreateDefault();
    if (!_BladeConfigIdentityIsSupported(_source)) {
        return _result;
    }

    if (variable_struct_exists(_source, "display") && is_struct(_source.display)) {
        var _display = _source.display;
        if (variable_struct_exists(_display, "fullscreen")
            && is_bool(_display.fullscreen)) {
            _result.display.fullscreen = _display.fullscreen;
        }
        if (variable_struct_exists(_display, "window_scale")) {
            _result.display.window_scale = _BladeConfigClampedInteger(
                _display.window_scale,
                _result.display.window_scale,
                1,
                6
            );
        }
        if (variable_struct_exists(_display, "vsync") && is_bool(_display.vsync)) {
            _result.display.vsync = _display.vsync;
        }
    }

    if (variable_struct_exists(_source, "audio") && is_struct(_source.audio)) {
        var _audio = _source.audio;
        if (variable_struct_exists(_audio, "master_gain_percent")) {
            _result.audio.master_gain_percent = _BladeConfigClampedInteger(
                _audio.master_gain_percent,
                _result.audio.master_gain_percent,
                0,
                100
            );
        }
        if (variable_struct_exists(_audio, "music_gain_percent")) {
            _result.audio.music_gain_percent = _BladeConfigClampedInteger(
                _audio.music_gain_percent,
                _result.audio.music_gain_percent,
                0,
                100
            );
        }
        if (variable_struct_exists(_audio, "sfx_gain_percent")) {
            _result.audio.sfx_gain_percent = _BladeConfigClampedInteger(
                _audio.sfx_gain_percent,
                _result.audio.sfx_gain_percent,
                0,
                100
            );
        }
    }

    if (variable_struct_exists(_source, "bindings") && is_struct(_source.bindings)) {
        var _bindings = _source.bindings;
        if (variable_struct_exists(_bindings, "keyboard")) {
            _result.bindings.keyboard = _BladeConfigKeyboardBindingsNormalize(
                _bindings.keyboard,
                _result.bindings.keyboard
            );
        }
        if (variable_struct_exists(_bindings, "gamepad")) {
            _result.bindings.gamepad = _BladeConfigGamepadBindingsNormalize(
                _bindings.gamepad,
                _result.bindings.gamepad
            );
        }
    }
    return _result;
}

/// Returns whether a struct has exactly the named fields, independent of key order.
function _BladeConfigStructHasExactFields(_value, _expected_fields) {
    if (!is_struct(_value)) {
        return false;
    }
    var _actual_fields = variable_struct_get_names(_value);
    if (array_length(_actual_fields) != array_length(_expected_fields)) {
        return false;
    }
    for (var _index = 0; _index < array_length(_expected_fields); ++_index) {
        if (!variable_struct_exists(_value, _expected_fields[_index])) {
            return false;
        }
    }
    return true;
}

/// Returns whether one device map contains exactly all supported canonical IDs and codes.
function _BladeConfigBindingMapIsCanonical(_value, _keyboard) {
    if (!is_struct(_value)) {
        return false;
    }
    var _fields = variable_struct_get_names(_value);
    var _records = BladeInputBindingRecords();
    if (array_length(_fields) != array_length(_records)) {
        return false;
    }
    for (var _index = 0; _index < array_length(_records); ++_index) {
        var _stable_id = _records[_index].stable_id;
        if (!variable_struct_exists(_value, _stable_id)) {
            return false;
        }
        var _code = variable_struct_get(_value, _stable_id);
        var _supported = _keyboard
            ? BladeConfigKeyboardCodeIsSupported(_code)
            : BladeConfigGamepadCodeIsSupported(_code);
        if (!_supported) {
            return false;
        }
    }
    return true;
}

/// @func BladeConfigIsCanonical(value)
/// Validates the exact closed version 1 payload shape and every normalized value.
function BladeConfigIsCanonical(_value) {
    if (!_BladeConfigIdentityIsSupported(_value)
        || !_BladeConfigStructHasExactFields(
            _value,
            ["format_id", "schema_version", "display", "audio", "bindings"]
        )
        || !_BladeConfigStructHasExactFields(
            _value.display,
            ["fullscreen", "window_scale", "vsync"]
        )
        || !_BladeConfigStructHasExactFields(
            _value.audio,
            ["master_gain_percent", "music_gain_percent", "sfx_gain_percent"]
        )
        || !_BladeConfigStructHasExactFields(
            _value.bindings,
            ["keyboard", "gamepad"]
        )) {
        return false;
    }

    if (!is_bool(_value.display.fullscreen)
        || !is_bool(_value.display.vsync)
        || !_BladeConfigFiniteInteger(_value.display.window_scale)
        || _value.display.window_scale < 1
        || _value.display.window_scale > 6) {
        return false;
    }

    var _gain_fields = [
        "master_gain_percent",
        "music_gain_percent",
        "sfx_gain_percent",
    ];
    for (var _gain_index = 0; _gain_index < array_length(_gain_fields); ++_gain_index) {
        var _gain = variable_struct_get(_value.audio, _gain_fields[_gain_index]);
        if (!_BladeConfigFiniteInteger(_gain) || _gain < 0 || _gain > 100) {
            return false;
        }
    }

    return _BladeConfigBindingMapIsCanonical(_value.bindings.keyboard, true)
        && _BladeConfigBindingMapIsCanonical(_value.bindings.gamepad, false);
}
