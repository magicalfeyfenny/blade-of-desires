/// @description Cross-boundary tests for run, pause, and mutable config ownership.

/// Proves config normalization and loading cannot serialize or mutate live run/pause state.
function _BladeRuntimeOwnershipTestConfigIsolation() {
    var _coordinator = _BladeRunCoordinatorTestCreate();
    var _owner = BladeRunCoordinatorAllocatePauseOwner(_coordinator);
    var _token = BladeRunCoordinatorAcquirePause(
        _coordinator,
        _owner,
        "pause.config_isolation",
        BladeClockDomain.Stage,
        BladePauseReleasePolicy.OwnerDestroyed
    );
    var _run_before = BladeRunCoordinatorCanonical(_coordinator);

    var _storage = _BladeConfigTestMemoryStorageCreate();
    var _filename = "automation-runtime-ownership.json";
    var _service = BladeConfigServiceCreate(_storage, _filename);
    var _candidate = BladeConfigCreateDefault();
    variable_struct_set(_candidate, "run_state", BladeRunCoordinatorSnapshot(_coordinator));
    variable_struct_set(_candidate, "player", { instance_id: "ins:999" });
    variable_struct_set(_candidate, "pause", BladeRunCoordinatorPauseSnapshot(_coordinator));
    variable_struct_set(_candidate, "combat", BladeRunCombatSnapshot(_coordinator));
    variable_struct_set(_candidate, "run_seed", int64(999));
    BladeKernelTestAssertTrue(
        BladeConfigServiceSave(_service, _candidate).ok,
        "config save accepts recognized fields while dropping run-shaped fields"
    );

    var _stored = _storage.read_text(_filename);
    BladeKernelTestAssertTrue(_stored.ok, "isolated config bytes exist");
    var _payload = json_parse(_stored.text, undefined, true);
    var _forbidden = ["run_state", "player", "pause", "combat", "run_seed"];
    for (var _index = 0; _index < array_length(_forbidden); ++_index) {
        BladeKernelTestAssertFalse(
            variable_struct_exists(_payload, _forbidden[_index]),
            "config omits " + _forbidden[_index]
        );
    }

    var _reloaded = BladeConfigServiceCreate(_storage, _filename);
    BladeKernelTestAssertEqual(
        BladeConfigServiceLoad(_reloaded).status,
        BladeConfigLoadStatus.Loaded,
        "isolated config reload status"
    );
    BladeKernelTestAssertEqual(
        BladeRunCoordinatorCanonical(_coordinator),
        _run_before,
        "config save and load cannot mutate run or pause canonical state"
    );
    var _pause = BladeRunCoordinatorPauseSnapshot(_coordinator);
    BladeKernelTestAssertEqual(_pause.active_tokens[0].token_id, _token.token_id, "pause token retained");
    BladeKernelTestAssertEqual(_pause.frozen_domains, BladeClockDomain.Stage, "pause domain retained");
}

/// @func BladeRuntimeOwnershipTestsRun(state)
/// Registers the config-versus-run/pause ownership boundary on the shared test state.
function BladeRuntimeOwnershipTestsRun(_state) {
    BladeKernelTestRunCase(_state, "runtime config remains isolated from run and pause state", function() {
        // Serialize hostile run-shaped fields, then prove they disappear without touching live state.
        _BladeRuntimeOwnershipTestConfigIsolation();
    });
    return _state;
}
