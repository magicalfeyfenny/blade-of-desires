/// @description Opt-in GMTL coverage for the front-end room re-entry lifecycle.

/// Reports one terminal result for the dedicated engine test.
function _BladeFrontendRoomLifecycleTestFinish(_status, _message) {
    if (!variable_global_exists("blade_frontend_room_lifecycle")) return;
    var _state = global.blade_frontend_room_lifecycle;
    if (!is_struct(_state) || _state.status != "pending") return;

    _state.status = _status;
    if (_status == "passed") {
        show_debug_message("BLADE_FRONTEND_ROOM_LIFECYCLE_RESULT: PASS");
    } else {
        show_debug_message(
            "BLADE_FRONTEND_ROOM_LIFECYCLE_CASE: FAIL " + string(_message)
        );
        show_debug_message("BLADE_FRONTEND_ROOM_LIFECYCLE_RESULT: FAIL");
    }
    game_end();
}

/// Fails closed when a lifecycle phase cannot establish its expected boundary.
function BladeFrontendRoomLifecycleTestFail(_message) {
    _BladeFrontendRoomLifecycleTestFinish("failed", _message);
}

/// Drives one real object Step with GMTL's configured keyboard simulation.
function _BladeFrontendRoomLifecycleTestStepWithKey(_instance, _key_code) {
    simulateKeyHold(_key_code);
    try {
        simulateEvent(ev_step, ev_step_normal, _instance);
    } finally {
        variable_struct_set(
            global.__gmtl_internal.keys,
            string(_key_code),
            false
        );
    }
}

/// Recognizes the cleanup boundary without depending on GMTL's private shape.
function _BladeFrontendRoomLifecycleTestSuitesRetired() {
    if (!variable_global_exists("__gmtl_internal")
        || !is_struct(global.__gmtl_internal)) return true;
    if (variable_struct_exists(global.__gmtl_internal, "finished")
        && global.__gmtl_internal.finished) return true;
    return !variable_struct_exists(global.__gmtl_internal, "suites");
}

/// Supplies only the public input-simulation state needed after GMTL cleanup.
function _BladeFrontendRoomLifecycleTestPreparePostCleanupInput() {
    global.__gmtl_internal = {
        keys: {},
        running: false,
    };
}

/// Starts the title-menu transition while GMTL's startup suites are running.
function BladeFrontendRoomLifecycleTestBegin() {
    global.blade_frontend_room_lifecycle = {
        status: "pending",
    };

    try {
        if (room != r_blade_start) {
            throw("startup did not enter r_blade_start");
        }

        var _start = instance_find(o_blade_start, 0);
        if (!instance_exists(_start) || !is_struct(_start.frontend_state)) {
            throw("startup front-end instance is incomplete");
        }

        var _runner = instance_create_layer(
            0, 0, "Instances", o_blade_frontend_room_lifecycle_test
        );
        if (!instance_exists(_runner)) {
            throw("lifecycle controller could not be created");
        }
        _runner.persistent = true;
        _runner.phase = 1;

        var _confirm_code = variable_struct_get(
            _start.frontend_state.config.bindings.keyboard,
            "input.confirm"
        );
        _BladeFrontendRoomLifecycleTestStepWithKey(_start, _confirm_code);
    } catch (_caught) {
        BladeFrontendRoomLifecycleTestFail(
            "startup-to-selector transition: " + string(_caught)
        );
    }
}

/// Returns from character select only after GMTL has retired its suite state.
function BladeFrontendRoomLifecycleTestReturnToStart() {
    if (_BladeFrontendRoomLifecycleTestSuitesRetired()) {
        _BladeFrontendRoomLifecycleTestPreparePostCleanupInput();
        var _selector = instance_find(o_blade_character_select, 0);
        if (!instance_exists(_selector)) {
            throw("character-select instance is missing after startup cleanup");
        }

        var _previous_running = global.__gmtl_internal.running;
        global.__gmtl_internal.running = true;
        try {
            var _cancel_code = variable_struct_get(
                _selector.input_config.bindings.keyboard,
                "input.cancel"
            );
            _BladeFrontendRoomLifecycleTestStepWithKey(
                _selector,
                _cancel_code
            );
        } finally {
            global.__gmtl_internal.running = _previous_running;
        }
        return true;
    }
    return false;
}

/// Registers the bounded scenario for the dedicated engine-test launch.
function BladeFrontendRoomLifecycleTestRegister() {
    if (variable_global_exists("blade_frontend_room_lifecycle")) return;
    if (variable_global_exists(
        "blade_frontend_room_lifecycle_test_registered"
    )) return;
    global.blade_frontend_room_lifecycle_test_registered = true;

    suite(function() {
        describe("Blade front-end room re-entry", function() {
            it("starts the transition scenario", function() {
                BladeFrontendRoomLifecycleTestBegin();
                expect(true).toBe(true);
            });
        });
    });
}
