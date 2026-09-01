/// Navigate and confirm through the configured semantic keyboard bindings.
if (error_text != "" || is_undefined(selector_state)) exit;

var _move_up = variable_struct_get(keyboard_bindings, "input.move_up");
var _move_down = variable_struct_get(keyboard_bindings, "input.move_down");
var _confirm = variable_struct_get(keyboard_bindings, "input.confirm");
if (keyboard_check_pressed(_move_up)) {
    BladeShipSelectionMove(selector_state, catalog, -1);
}
if (keyboard_check_pressed(_move_down)) {
    BladeShipSelectionMove(selector_state, catalog, 1);
}
if (!keyboard_check_pressed(_confirm)) exit;

var _confirmation = BladeShipSelectionConfirm(selector_state, catalog);
if (!_confirmation.accepted) exit;
global.blade_selected_run = _confirmation.run;
room_goto(r_stage1_first_beat);
