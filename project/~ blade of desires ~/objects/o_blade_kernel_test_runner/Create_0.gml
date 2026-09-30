/// Run Blade's isolated deterministic-kernel tests only for an explicit test launch.
/// The argument gate keeps ordinary project starts from executing tests, while
/// game_end gives the shell runner a process that exits after the result.
var _run_tests = false;
var _run_frame_pacing_profile = false;
var _run_application_lifecycle_tests = false;
for (var i = 1; i <= parameter_count(); i++) {
    var _argument = parameter_string(i);
    if (_argument == "--run-stage1-frame-pacing-test") {
        _run_frame_pacing_profile = true;
        break;
    }
    if (_argument == "--run-test" || _argument == "-runTest") {
        _run_tests = true;
    }
    if (_argument == "--run-application-lifecycle-test") {
        _run_tests = true;
        _run_application_lifecycle_tests = true;
    }
}

if (_run_frame_pacing_profile) {
    // Keep deterministic replay instrumentation independent of runner-window focus.
    // Native focus and pause boundaries are covered by the lifecycle integration suite.
    global.blade_application_lifecycle_test_observation = {
        has_focus: true,
        platform_paused: false,
    };
    if (BladeStage1FramePacingProfilePrepare()) {
        room_goto(r_stage1_first_beat);
    } else {
        game_end();
    }
    exit;
}

if (!_run_tests) {
    instance_destroy();
    exit;
}

if (_run_application_lifecycle_tests) {
    var _state = BladeKernelTestStateCreate();
    BladeLiveInputTestsRun(_state);
    BladeApplicationLifecycleTestsRun(_state);
    BladeApplicationLifecycleIntegrationTestsRun(_state);
    BladeKernelTestFinish(_state);
} else {
    BladeKernelTestsRun();
}
game_end();
