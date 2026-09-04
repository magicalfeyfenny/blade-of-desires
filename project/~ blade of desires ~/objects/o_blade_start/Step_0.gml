/// Advance the front-end state through the shared semantic input adapter.
if (frontend_state.message_ticks > 0) frontend_state.message_ticks -= 1;
frontend_input = BladeLiveInputSample(frontend_state.config);

if (frontend_state.listening) {
    var _binding_ids = BladeFrontendBindingIds();
    var _binding_id = _binding_ids[frontend_state.selected_index];
    var _cancel_code = variable_struct_get(
        frontend_state.config.bindings.keyboard, "input.cancel"
    );
    if (keyboard_check_pressed(_cancel_code)) {
        frontend_state.listening = false;
        BladeFrontendStateSetMessage(frontend_state, "KEY LISTENING CANCELLED");
        exit;
    }
    if (keyboard_check_pressed(vk_anykey)) {
        var _key_code = keyboard_lastkey;
        var _binding_candidate = BladeFrontendBindingCandidate(
            frontend_state.config, _binding_id, _key_code
        );
        if (_binding_candidate.accepted) {
            var _binding_save = BladeFrontendConfigSave(
                global.blade_config_service,
                frontend_state.config,
                _binding_candidate.config
            );
            if (_binding_save.ok) {
                frontend_state.config = _binding_save.config;
                BladeFrontendStateSetMessage(
                    frontend_state, "KEY SAVED: " + BladeFrontendKeyboardLabel(_key_code)
                );
            } else {
                BladeFrontendStateSetMessage(
                    frontend_state, "KEY NOT SAVED: " + string(_binding_save.code)
                );
            }
        } else {
            BladeFrontendStateSetMessage(
                frontend_state, "UNSUPPORTED KEY - TRY AGAIN"
            );
        }
        frontend_state.listening = false;
    }
    exit;
}

if (BladeLiveInputActionPressed(frontend_input, BladeInputAction.Cancel)) {
    BladeFrontendStateBack(frontend_state);
    exit;
}

var _moved = false;
if (frontend_input.pressed_move_y != 0) {
    BladeFrontendStateMove(frontend_state, frontend_input.pressed_move_y);
    _moved = true;
}

if (frontend_state.page == BladeFrontendPage.Options
    && frontend_input.pressed_move_x != 0
    && BladeFrontendOptionIsAdjustable(frontend_state.selected_index)) {
    var _option_candidate = BladeFrontendOptionCandidate(
        frontend_state.config,
        frontend_state.selected_index,
        frontend_input.pressed_move_x
    );
    var _option_save = BladeFrontendConfigSave(
        global.blade_config_service,
        frontend_state.config,
        _option_candidate
    );
    if (_option_save.ok) {
        frontend_state.config = _option_save.config;
        BladeFrontendStateSetMessage(frontend_state, "SETTING SAVED");
    } else {
        BladeFrontendStateSetMessage(
            frontend_state, "SETTING NOT APPLIED: " + string(_option_save.code)
        );
    }
    _moved = true;
}
if (_moved) exit;

if (!BladeLiveInputActionPressed(frontend_input, BladeInputAction.Confirm)) exit;

// Confirm adjusts a selected scalar option; subpage entries use the state machine.
if (frontend_state.page == BladeFrontendPage.Options
    && BladeFrontendOptionIsAdjustable(frontend_state.selected_index)) {
    var _confirmed_option = BladeFrontendOptionCandidate(
        frontend_state.config, frontend_state.selected_index, 1
    );
    var _confirmed_save = BladeFrontendConfigSave(
        global.blade_config_service,
        frontend_state.config,
        _confirmed_option
    );
    if (_confirmed_save.ok) {
        frontend_state.config = _confirmed_save.config;
        BladeFrontendStateSetMessage(frontend_state, "SETTING SAVED");
    } else {
        BladeFrontendStateSetMessage(
            frontend_state, "SETTING NOT APPLIED: " + string(_confirmed_save.code)
        );
    }
    exit;
}

var _activation = BladeFrontendStateActivate(frontend_state);
if (_activation.action == BladeFrontendAction.StartGame) {
    if (BladeFrontendStateConsumeStart(frontend_state)) {
        global.blade_selected_run = undefined;
        room_goto(r_blade_character_select);
    }
} else if (_activation.action == BladeFrontendAction.Quit) {
    game_end();
}
