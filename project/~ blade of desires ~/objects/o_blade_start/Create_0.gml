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
    // GMTL ships demo suites that run ten frames after startup. Blade keeps the
    // pinned library read-only and clears only those registered demo callbacks
    // before production objects exist, so their simulated frames cannot drive play.
    if (variable_global_exists("__gmtl_internal")
        && is_struct(global.__gmtl_internal)
        && variable_struct_exists(global.__gmtl_internal, "suites")) {
        global.__gmtl_internal.suites.list = [];
    }
    room_goto(r_stage1_first_beat);
}
