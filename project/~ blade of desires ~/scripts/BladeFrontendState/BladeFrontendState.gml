/// @description Explicit front-end pages, option values, and safe config commits.

enum BladeFrontendPage {
    Main = 1,
    Options = 2,
    Bindings = 3
}

enum BladeFrontendAction {
    None = 0,
    StartGame = 1,
    Quit = 2
}

/// Returns the stable main-menu labels in their player-facing order.
function BladeFrontendMainLabels() {
    return ["START GAME", "OPTIONS", "QUIT"];
}

/// Returns the option labels; the final two entries open or leave a subpage.
function BladeFrontendOptionLabels() {
    return [
        "FULLSCREEN",
        "WINDOW SCALE",
        "MASTER VOLUME",
        "MUSIC VOLUME",
        "SFX VOLUME",
        "REMAP KEYBOARD",
        "BACK",
    ];
}

/// Returns all stable IDs in the binding registry's canonical order.
function BladeFrontendBindingIds() {
    var _records = BladeInputBindingRecords();
    var _ids = [];
    for (var _index = 0; _index < array_length(_records); ++_index) {
        array_push(_ids, _records[_index].stable_id);
    }
    return _ids;
}

/// Returns the number of entries on one front-end page.
function BladeFrontendPageItemCount(_page) {
    switch (_page) {
        case BladeFrontendPage.Main:
            return array_length(BladeFrontendMainLabels());
        case BladeFrontendPage.Options:
            return array_length(BladeFrontendOptionLabels());
        case BladeFrontendPage.Bindings:
            return array_length(BladeFrontendBindingIds());
    }
    throw("BladeFrontendState: unknown page");
}

/// Rejects malformed front-end state before page transitions can leak state.
function _BladeFrontendStateRequire(_state) {
    if (!is_struct(_state)
        || !variable_struct_exists(_state, "__blade_frontend_state_version")
        || _state.__blade_frontend_state_version != 1
        || !variable_struct_exists(_state, "config")
        || !BladeConfigIsCanonical(_state.config)
        || !variable_struct_exists(_state, "page")
        || _state.page < BladeFrontendPage.Main
        || _state.page > BladeFrontendPage.Bindings
        || !variable_struct_exists(_state, "selected_index")
        || _state.selected_index < 0
        || _state.selected_index >= BladeFrontendPageItemCount(_state.page)
        || !variable_struct_exists(_state, "listening")
        || !is_bool(_state.listening)
        || !variable_struct_exists(_state, "transitioned")
        || !is_bool(_state.transitioned)) {
        throw("BladeFrontendState: state is incomplete");
    }
}

/// Creates a detached front-end state with the title screen selected.
function BladeFrontendStateCreate(_config) {
    var _normalized = BladeConfigNormalize(_config);
    return {
        __blade_frontend_state_version: 1,
        page: BladeFrontendPage.Main,
        selected_index: 0,
        listening: false,
        transitioned: false,
        message: "",
        message_ticks: 0,
        config: _normalized,
    };
}

/// Moves one page cursor with wraparound and keeps key-listening modal.
function BladeFrontendStateMove(_state, _delta) {
    _BladeFrontendStateRequire(_state);
    if (_state.listening || _delta == 0) return _state.selected_index;
    var _count = BladeFrontendPageItemCount(_state.page);
    var _direction = _delta > 0 ? 1 : -1;
    _state.selected_index = (
        _state.selected_index + _direction + _count
    ) mod _count;
    return _state.selected_index;
}

/// Opens a page and starts its cursor at the first item.
function _BladeFrontendStateOpenPage(_state, _page) {
    _state.page = _page;
    _state.selected_index = 0;
    _state.listening = false;
    return _state;
}

/// Applies the title/options/bindings confirm action without starting gameplay twice.
function BladeFrontendStateActivate(_state) {
    _BladeFrontendStateRequire(_state);
    if (_state.listening) {
        return { action: BladeFrontendAction.None };
    }

    if (_state.page == BladeFrontendPage.Main) {
        if (_state.selected_index == 0) {
            return { action: BladeFrontendAction.StartGame };
        }
        if (_state.selected_index == 1) {
            _BladeFrontendStateOpenPage(_state, BladeFrontendPage.Options);
            return { action: BladeFrontendAction.None };
        }
        return { action: BladeFrontendAction.Quit };
    }

    if (_state.page == BladeFrontendPage.Options) {
        if (_state.selected_index == 5) {
            _BladeFrontendStateOpenPage(_state, BladeFrontendPage.Bindings);
            return { action: BladeFrontendAction.None };
        }
        if (_state.selected_index == 6) {
            _BladeFrontendStateOpenPage(_state, BladeFrontendPage.Main);
            return { action: BladeFrontendAction.None };
        }
        return { action: BladeFrontendAction.None };
    }

    _state.listening = true;
    return {
        action: BladeFrontendAction.None,
        listening: true,
        binding_index: _state.selected_index,
    };
}

/// Leaves a subpage, or closes its modal key-listening state first.
function BladeFrontendStateBack(_state) {
    _BladeFrontendStateRequire(_state);
    if (_state.listening) {
        _state.listening = false;
        return _state.page;
    }
    if (_state.page == BladeFrontendPage.Bindings) {
        _BladeFrontendStateOpenPage(_state, BladeFrontendPage.Options);
    } else if (_state.page == BladeFrontendPage.Options) {
        _BladeFrontendStateOpenPage(_state, BladeFrontendPage.Main);
    }
    return _state.page;
}

/// Latches the one allowed title-to-game transition.
function BladeFrontendStateConsumeStart(_state) {
    _BladeFrontendStateRequire(_state);
    if (_state.transitioned) return false;
    _state.transitioned = true;
    return true;
}

/// Adds one short-lived status message without changing menu selection.
function BladeFrontendStateSetMessage(_state, _message) {
    _BladeFrontendStateRequire(_state);
    _state.message = _message;
    _state.message_ticks = 120;
    return _state;
}

/// Reports which five option rows accept left/right adjustments.
function BladeFrontendOptionIsAdjustable(_index) {
    return _index >= 0 && _index <= 4;
}

/// Returns a detached candidate for one bounded display or audio adjustment.
function BladeFrontendOptionCandidate(_config, _index, _delta) {
    if (!BladeFrontendOptionIsAdjustable(_index)) {
        throw("BladeFrontendState: option is not adjustable");
    }
    var _candidate = BladeConfigNormalize(_config);
    if (_delta == 0) return _candidate;
    var _direction = _delta > 0 ? 1 : -1;
    switch (_index) {
        case 0:
            _candidate.display.fullscreen = !_candidate.display.fullscreen;
            break;
        case 1:
            _candidate.display.window_scale = clamp(
                _candidate.display.window_scale + _direction, 1, 6
            );
            break;
        case 2:
            _candidate.audio.master_gain_percent = clamp(
                _candidate.audio.master_gain_percent + _direction * 10, 0, 100
            );
            break;
        case 3:
            _candidate.audio.music_gain_percent = clamp(
                _candidate.audio.music_gain_percent + _direction * 10, 0, 100
            );
            break;
        case 4:
            _candidate.audio.sfx_gain_percent = clamp(
                _candidate.audio.sfx_gain_percent + _direction * 10, 0, 100
            );
            break;
    }
    return _candidate;
}

/// Returns a valid candidate binding, or leaves the current config untouched.
function BladeFrontendBindingCandidate(_config, _stable_id, _keyboard_code) {
    var _current = BladeConfigNormalize(_config);
    // Registry lookup rejects unknown IDs before a key code can be persisted.
    BladeInputBindingRecord(_stable_id);
    if (!BladeConfigKeyboardCodeIsSupported(_keyboard_code)) {
        return {
            accepted: false,
            code: "config.input.unsupported_key",
            config: _current,
        };
    }
    variable_struct_set(
        _current.bindings.keyboard, _stable_id, _keyboard_code
    );
    return {
        accepted: true,
        code: "config.input.accepted",
        config: _current,
    };
}

/// Applies a display candidate and reports whether the runtime reflects it.
function BladeFrontendApplyDisplay(_config) {
    window_set_fullscreen(_config.display.fullscreen);
    if (!_config.display.fullscreen) {
        window_set_size(
            640 * _config.display.window_scale,
            360 * _config.display.window_scale
        );
        window_center();
    }
}

/// Checks the platform display state after a front-end display request.
function BladeFrontendDisplayMatches(_config) {
    if (window_get_fullscreen() != _config.display.fullscreen) return false;
    if (_config.display.fullscreen) return true;
    return round(window_get_width()) == 640 * _config.display.window_scale
        && round(window_get_height()) == 360 * _config.display.window_scale;
}

/// Saves through the existing transactional service and rolls back display state on failure.
function BladeFrontendConfigSave(_service, _current, _candidate) {
    var _old_config = BladeConfigNormalize(_current);
    var _new_config = BladeConfigNormalize(_candidate);
    var _display_changed = _old_config.display.fullscreen
        != _new_config.display.fullscreen
        || _old_config.display.window_scale
            != _new_config.display.window_scale;
    if (_display_changed) {
        BladeFrontendApplyDisplay(_new_config);
        if (!BladeFrontendDisplayMatches(_new_config)) {
            BladeFrontendApplyDisplay(_old_config);
            return {
                ok: false,
                code: "config.apply.display_failed",
                config: _old_config,
            };
        }
    }

    var _saved = BladeConfigServiceSave(_service, _new_config);
    if (!_saved.ok) {
        if (_display_changed) BladeFrontendApplyDisplay(_old_config);
        return {
            ok: false,
            code: _saved.code,
            config: _old_config,
        };
    }
    return {
        ok: true,
        code: _saved.code,
        config: _saved.config,
    };
}

/// Turns one stable keyboard binding into short readable menu text.
function BladeFrontendBindingLabel(_stable_id) {
    switch (_stable_id) {
        case "input.move_up": return "MOVE UP";
        case "input.move_down": return "MOVE DOWN";
        case "input.move_left": return "MOVE LEFT";
        case "input.move_right": return "MOVE RIGHT";
        case "input.fire": return "FIRE";
        case "input.bomb": return "BOMB / HYPER";
        case "input.focus": return "FOCUS";
        case "input.pause": return "PAUSE";
        case "input.confirm": return "CONFIRM";
        case "input.cancel": return "CANCEL / BACK";
    }
    throw("BladeFrontendState: unknown binding label");
}

/// Turns supported keyboard codes into player-facing labels without freezing IDs.
function BladeFrontendKeyboardLabel(_code) {
    if (_code >= ord("A") && _code <= ord("Z")) return chr(_code);
    if (_code >= ord("0") && _code <= ord("9")) return chr(_code);
    switch (_code) {
        case vk_left: return "LEFT";
        case vk_right: return "RIGHT";
        case vk_up: return "UP";
        case vk_down: return "DOWN";
        case vk_enter: return "ENTER";
        case vk_escape: return "ESC";
        case vk_space: return "SPACE";
        case vk_shift: return "SHIFT";
        case vk_control: return "CTRL";
        case vk_alt: return "ALT";
        case vk_tab: return "TAB";
        case vk_home: return "HOME";
        case vk_end: return "END";
        case vk_delete: return "DELETE";
        case vk_insert: return "INSERT";
        case vk_pageup: return "PAGE UP";
        case vk_pagedown: return "PAGE DOWN";
        case vk_pause: return "PAUSE";
        case vk_f1: return "F1";
        case vk_f2: return "F2";
        case vk_f3: return "F3";
        case vk_f4: return "F4";
        case vk_f5: return "F5";
        case vk_f6: return "F6";
        case vk_f7: return "F7";
        case vk_f8: return "F8";
        case vk_f9: return "F9";
        case vk_f10: return "F10";
        case vk_f11: return "F11";
        case vk_f12: return "F12";
    }
    return "KEY " + string(_code);
}
