/// Synchronous project-owned entry point for deterministic-kernel tests.

function BladeKernelTestsRun() {
    var _state = BladeKernelTestStateCreate();
    show_debug_message("BLADE_KERNEL_TEST_ENTRY: v1");

    BladeClockInputTestsRun(_state);
    BladeRandomIdentityTestsRun(_state);
    BladeEventSessionTestsRun(_state);
    BladeKernelIntegrationTestsRun(_state);

    return BladeKernelTestFinish(_state);
}
