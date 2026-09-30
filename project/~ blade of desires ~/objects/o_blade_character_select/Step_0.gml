/// Navigate and confirm through the shared configured semantic input adapter.
var _application = BladeApplicationLifecyclePoll();
if (!_application.gameplay_allowed) {
    BladeLiveInputStateReset(live_input_state);
    exit;
}
if (_application.epoch != application_lifecycle_epoch) {
    application_lifecycle_epoch = _application.epoch;
    BladeLiveInputStateReset(live_input_state);
    exit;
}
if (error_text != "" || is_undefined(selector_state)) exit;

var _input = BladeLiveInputSample(input_config, live_input_state);
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
