/// Route test launches to the isolated runner and ordinary launches to gameplay.
var _run_tests = false;
for (var _index = 1; _index <= parameter_count(); ++_index) {
    var _argument = parameter_string(_index);
    if (_argument == "--run-test" || _argument == "-runTest") {
        _run_tests = true;
        break;
    }
}

if (_run_tests) {
    room_goto(r_blade_kernel_tests);
} else {
    // Load the established per-user owner once for front-end, input, and audio.
    global.blade_config_service = BladeConfigServiceCreate(
        BladeConfigFileStorageCreate()
    );
    var _config_result = BladeConfigServiceLoad(global.blade_config_service);
    var _config = _config_result.config;

    // Keep the logical surface crisp at the chosen integer presentation size.
    gpu_set_texfilter(false);
    if (_config.display.fullscreen) {
        window_set_fullscreen(true);
    } else {
        window_set_fullscreen(false);
        window_set_size(
            640 * _config.display.window_scale,
            360 * _config.display.window_scale
        );
        window_center();
    }

    // GMTL ships demo suites that run ten frames after startup. Blade keeps the
    // pinned library read-only and clears only those registered demo callbacks
    // before production objects exist, so their simulated frames cannot drive play.
    // GMTL deletes this temporary suite state after the tests finish, so a later
    // return to this room must treat the missing state as normal cleanup.
    if (variable_global_exists("__gmtl_internal")
        && is_struct(global.__gmtl_internal)
        && variable_struct_exists(global.__gmtl_internal, "suites")) {
        var _gmtl_suites = variable_struct_get(
            global.__gmtl_internal,
            "suites"
        );
        if (is_struct(_gmtl_suites)
            && variable_struct_exists(_gmtl_suites, "list")) {
            variable_struct_set(_gmtl_suites, "list", []);
        }
    }
    global.blade_selected_run = undefined;
    frontend_state = BladeFrontendStateCreate(_config);
    frontend_ui = BladeFrontendUiCreate();
    frontend_input = BladeLiveInputSample(frontend_state.config);
    depth = -1000;
}
