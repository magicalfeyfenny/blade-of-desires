/// Complete the return transition and report the machine-readable lifecycle result.
if (!variable_global_exists("blade_frontend_room_lifecycle")) exit;
var _state = global.blade_frontend_room_lifecycle;
if (!is_struct(_state) || _state.status != "pending") exit;

frames_waited += 1;
if (frames_waited > 180) {
    BladeFrontendRoomLifecycleTestFail("room transition did not complete");
    exit;
}

if (phase == 1) {
    if (room == r_blade_start) exit;
    if (room != r_blade_character_select) {
        BladeFrontendRoomLifecycleTestFail(
            "supported flow entered an unexpected room " + string(room)
        );
        exit;
    }

    try {
        if (BladeFrontendRoomLifecycleTestReturnToStart()) {
            phase = 2;
        }
    } catch (_caught) {
        BladeFrontendRoomLifecycleTestFail(
            "post-cleanup return transition: " + string(_caught)
        );
    }
    exit;
}

if (phase != 2 || room != r_blade_start) exit;

var _start = instance_find(o_blade_start, 0);
if (!instance_exists(_start) || !is_struct(_start.frontend_state)) {
    BladeFrontendRoomLifecycleTestFail(
        "front-end did not complete safe re-entry"
    );
    exit;
}
if (_start.frontend_state.page != BladeFrontendPage.Main) {
    BladeFrontendRoomLifecycleTestFail(
        "front-end re-entry did not restore the main page"
    );
    exit;
}

_BladeFrontendRoomLifecycleTestFinish("passed", "");
