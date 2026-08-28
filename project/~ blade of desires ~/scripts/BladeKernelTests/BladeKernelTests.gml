/// Synchronous project-owned entry point for deterministic-kernel tests.

/// Runs every Blade suite through exact assertions and returns one aggregate
/// pass/fail result so the test object emits only one final outcome.
function BladeKernelTestsRun() {
    var _state = BladeKernelTestStateCreate();
    show_debug_message("BLADE_KERNEL_TEST_ENTRY: v1");

    BladeSimulationClockTestsRun(_state);
    BladeClockInputTestsRun(_state);
    BladeInputBindingTestsRun(_state);
    BladeConfigTestsRun(_state);
    BladePauseRegistryTestsRun(_state);
    BladeRandomIdentityTestsRun(_state);
    BladeRunCoordinatorTestsRun(_state);
    BladeRunPauseTestsRun(_state);
    BladeRuntimeOwnershipTestsRun(_state);
    BladeEventSchemaTestsRun(_state);
    BladeEventSessionTestsRun(_state);
    BladeCombatGeometryTestsRun(_state);
    BladeCombatRuntimeTestsRun(_state);
    BladeCombatLifecycleTestsRun(_state);
    BladeFirstCombatBeatTestsRun(_state);
    BladeFirstBeatSurvivalTestsRun(_state);
    BladeStage1RouteTestsRun(_state);
    BladeStagePlanTestsRun(_state);
    BladeStageRuntimeTestsRun(_state);
    BladeRunStageTestsRun(_state);
    BladeKernelIntegrationTestsRun(_state);

    return BladeKernelTestFinish(_state);
}
