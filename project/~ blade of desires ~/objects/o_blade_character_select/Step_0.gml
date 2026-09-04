/// Navigate and confirm through the shared configured semantic input adapter.
if (error_text != "" || is_undefined(selector_state)) exit;

var _input = BladeLiveInputSample(input_config);
if (_input.pressed_move_y < 0) {
    BladeShipSelectionMove(selector_state, catalog, -1);
} else if (_input.pressed_move_y > 0) {
    BladeShipSelectionMove(selector_state, catalog, 1);
}
if (_input.pressed_move_x < 0) {
    BladeShipSelectionMoveDifficulty(selector_state, catalog, -1);
} else if (_input.pressed_move_x > 0) {
    BladeShipSelectionMoveDifficulty(selector_state, catalog, 1);
}
if (BladeLiveInputActionPressed(_input, BladeInputAction.Cancel)) {
    global.blade_selected_run = undefined;
    room_goto(r_blade_start);
    exit;
}
if (!BladeLiveInputActionPressed(_input, BladeInputAction.Confirm)) exit;

var _confirmation = BladeShipSelectionConfirm(selector_state, catalog);
if (!_confirmation.accepted) exit;
global.blade_selected_run = _confirmation.run;
room_goto(r_stage1_first_beat);
