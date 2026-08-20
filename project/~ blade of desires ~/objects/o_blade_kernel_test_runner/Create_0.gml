/// Run Blade's isolated deterministic-kernel tests only for an explicit test launch.
/// The argument gate keeps ordinary project starts from executing tests, while
/// game_end gives the shell runner a process that exits after the result.
var _run_tests = false;
for (var i = 1; i <= parameter_count(); i++) {
    var _argument = parameter_string(i);
    if (_argument == "--run-test" || _argument == "-runTest") {
        _run_tests = true;
        break;
    }
}

if (!_run_tests) {
    instance_destroy();
    exit;
}

BladeKernelTestsRun();
game_end();
