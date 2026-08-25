/// @description Sole authoritative owner for one deterministic run and its player lifecycle.

// Separates immutable run intent from the active or terminal lifecycle of an attempt.
enum BladeRunMode {
	Normal = 1,
	Practice = 2
}

// Declares the only run lifecycle states accepted by the coordinator.
enum BladeRunLifecycle {
	Active = 1,
	Completed = 2,
	Aborted = 3
}

// Keeps player lifecycle ownership here while combat and respawn states remain deferred.
enum BladePlayerLifecycle {
	Active = 1,
	Released = 2
}

/// Adds the module and field names to a stable validation diagnostic before throwing.
function _BladeRunCoordinatorFail(_field, _reason) {
	throw("BladeRunCoordinator: " + _field + ": " + _reason);
}

/// Converts exact integer values to int64 and enforces inclusive bounds without rounding.
function _BladeRunCoordinatorInteger(_value, _minimum, _maximum, _field) {
	var _type = typeof(_value);
	var _integer;
	if (_type == "int32" || _type == "int64") {
		_integer = int64(_value);
	} else if (_type == "number") {
		if (is_nan(_value) || is_infinity(_value)
			|| floor(_value) != _value
			|| abs(_value) > 9007199254740991) {
			_BladeRunCoordinatorFail(_field, "must be an exact finite integer");
		}
		_integer = int64(_value);
	} else {
		_BladeRunCoordinatorFail(_field, "must be an integer");
	}

	if (_integer < _minimum || _integer > _maximum) {
		_BladeRunCoordinatorFail(
			_field,
			"must be between " + string(_minimum)
				+ " and " + string(_maximum) + " inclusive"
		);
	}
	return _integer;
}

/// Accepts only the two declared run modes so unknown enum values fail before construction.
function _BladeRunCoordinatorMode(_mode) {
	var _value = _BladeRunCoordinatorInteger(
		_mode,
		BladeRunMode.Normal,
		BladeRunMode.Practice,
		"run mode"
	);
	if (_value != BladeRunMode.Normal && _value != BladeRunMode.Practice) {
		_BladeRunCoordinatorFail("run mode", "is not registered");
	}
	return _value;
}

/// Accepts only active, completed, or aborted run lifecycle values.
function _BladeRunCoordinatorLifecycle(_lifecycle) {
	var _value = _BladeRunCoordinatorInteger(
		_lifecycle,
		BladeRunLifecycle.Active,
		BladeRunLifecycle.Aborted,
		"run lifecycle"
	);
	if (_value != BladeRunLifecycle.Active
		&& _value != BladeRunLifecycle.Completed
		&& _value != BladeRunLifecycle.Aborted) {
		_BladeRunCoordinatorFail("run lifecycle", "is not registered");
	}
	return _value;
}

/// Accepts only active or released player lifecycle values.
function _BladeRunCoordinatorPlayerLifecycle(_lifecycle) {
	var _value = _BladeRunCoordinatorInteger(
		_lifecycle,
		BladePlayerLifecycle.Active,
		BladePlayerLifecycle.Released,
		"player lifecycle"
	);
	if (_value != BladePlayerLifecycle.Active
		&& _value != BladePlayerLifecycle.Released) {
		_BladeRunCoordinatorFail("player lifecycle", "is not registered");
	}
	return _value;
}

/// Maps a validated run mode to the stable token used by canonical state.
function _BladeRunCoordinatorModeToken(_mode) {
	switch (_BladeRunCoordinatorMode(_mode)) {
		case BladeRunMode.Normal: return "normal";
		case BladeRunMode.Practice: return "practice";
	}
	_BladeRunCoordinatorFail("run mode", "is unreachable");
}

/// Maps a validated run lifecycle to the stable token used by canonical state.
function _BladeRunCoordinatorLifecycleToken(_lifecycle) {
	switch (_BladeRunCoordinatorLifecycle(_lifecycle)) {
		case BladeRunLifecycle.Active: return "active";
		case BladeRunLifecycle.Completed: return "completed";
		case BladeRunLifecycle.Aborted: return "aborted";
	}
	_BladeRunCoordinatorFail("run lifecycle", "is unreachable");
}

/// Maps a validated player lifecycle to the stable token used by canonical state.
function _BladeRunCoordinatorPlayerLifecycleToken(_lifecycle) {
	switch (_BladeRunCoordinatorPlayerLifecycle(_lifecycle)) {
		case BladePlayerLifecycle.Active: return "active";
		case BladePlayerLifecycle.Released: return "released";
	}
	_BladeRunCoordinatorFail("player lifecycle", "is unreachable");
}

/// Rejects malformed coordinator values before any internal field is accessed.
function _BladeRunCoordinatorRequire(_coordinator) {
	if (!is_struct(_coordinator)
		|| !variable_struct_exists(_coordinator, "__blade_run_coordinator_version")
		|| _coordinator.__blade_run_coordinator_version != 3) {
		_BladeRunCoordinatorFail("coordinator", "expected a version 3 coordinator");
	}

	var _fields = [
		"__content_fingerprint",
		"__content_id_predicate",
		"__max_catch_up_ticks",
		"__kernel",
		"__combat",
		"__stage",
		"__is_advancing",
		"__pause_registry",
		"__state",
	];
	for (var _index = 0; _index < array_length(_fields); ++_index) {
		if (!variable_struct_exists(_coordinator, _fields[_index])) {
			_BladeRunCoordinatorFail(
				"coordinator",
				"is missing internal field " + _fields[_index]
			);
		}
	}
	if (typeof(_coordinator.__content_id_predicate) != "method") {
		_BladeRunCoordinatorFail("content ID predicate", "must remain a method");
	}
	if (typeof(_coordinator.__is_advancing) != "bool") {
		_BladeRunCoordinatorFail("advancing guard", "must remain a boolean");
	}
	return _coordinator;
}

/// Requires a globally known content ID in the requested namespace without copying the registry.
function _BladeRunCoordinatorRequireContentKind(_identity, _content_id, _prefix, _field) {
	var _known_id = BladeRunIdentityRequireContent(_identity, _content_id);
	if (string_copy(_known_id, 1, string_length(_prefix)) != _prefix) {
		_BladeRunCoordinatorFail(
			_field,
			"expected a known " + _prefix + " content ID, received " + _known_id
		);
	}
	return _known_id;
}

/// Builds a complete fresh kernel and initial state locally so failed validation cannot alter a live run.
function _BladeRunCoordinatorBuildAttempt(
	_content_fingerprint,
	_content_id_predicate,
	_max_catch_up_ticks,
	_ship_id,
	_difficulty_id,
	_run_mode,
	_run_seed,
	_gameplay_plane
) {
	var _mode = _BladeRunCoordinatorMode(_run_mode);
	var _kernel = BladeDeterministicKernelCreate(
		_content_fingerprint,
		_run_seed,
		_content_id_predicate,
		_max_catch_up_ticks
	);
	var _ship = _BladeRunCoordinatorRequireContentKind(
		_kernel.identity,
		_ship_id,
		"ship.",
		"ship ID"
	);
	var _difficulty = _BladeRunCoordinatorRequireContentKind(
		_kernel.identity,
		_difficulty_id,
		"difficulty.",
		"difficulty ID"
	);
	var _owner_id = BladeKernelAllocate(_kernel, BladeRunIdKind.EventOwner);
	var _combat = BladeCombatRuntimeCreate(
		_kernel.identity, _owner_id, _gameplay_plane
	);
	var _player_id = BladeKernelAllocateForContent(
		_kernel,
		BladeRunIdKind.Instance,
		_ship
	);
	var _seed = _kernel.header.get_run_seed();

	return {
		kernel: _kernel,
		combat: _combat,
		pause_registry: BladePauseRegistryCreate(_kernel.identity),
		state: {
			__blade_run_state_version: 1,
			mode: _mode,
			lifecycle: BladeRunLifecycle.Active,
			ship_id: _ship,
			difficulty_id: _difficulty,
			run_seed: _seed,
			event_owner_id: _owner_id,
			started_tick: int64(0),
			terminal_tick: int64(-1),
			player: {
				__blade_player_state_version: 1,
				instance_id: _player_id,
				ship_id: _ship,
				lifecycle: BladePlayerLifecycle.Active,
				started_tick: int64(0),
				terminal_tick: int64(-1),
			},
		},
	};
}

/// Validates internal run and player invariants and returns a detached public snapshot.
function _BladeRunCoordinatorStateView(_coordinator) {
	_BladeRunCoordinatorRequire(_coordinator);
	var _state = _coordinator.__state;
	if (!is_struct(_state)
		|| !variable_struct_exists(_state, "__blade_run_state_version")
		|| _state.__blade_run_state_version != 1) {
		_BladeRunCoordinatorFail("run state", "expected a version 1 state");
	}
	if (!is_struct(_state.player)
		|| !variable_struct_exists(_state.player, "__blade_player_state_version")
		|| _state.player.__blade_player_state_version != 1) {
		_BladeRunCoordinatorFail("player state", "expected a version 1 state");
	}

	var _maximum = int64("9223372036854775807");
	var _mode = _BladeRunCoordinatorMode(_state.mode);
	var _lifecycle = _BladeRunCoordinatorLifecycle(_state.lifecycle);
	var _player_lifecycle = _BladeRunCoordinatorPlayerLifecycle(
		_state.player.lifecycle
	);
	var _ship = _BladeRunCoordinatorRequireContentKind(
		_coordinator.__kernel.identity,
		_state.ship_id,
		"ship.",
		"ship ID"
	);
	var _difficulty = _BladeRunCoordinatorRequireContentKind(
		_coordinator.__kernel.identity,
		_state.difficulty_id,
		"difficulty.",
		"difficulty ID"
	);
	var _seed = BladeRandomNormalizeSeed(_state.run_seed);
	if (_seed != _state.run_seed
		|| _seed != _coordinator.__kernel.header.get_run_seed()) {
		_BladeRunCoordinatorFail("run seed", "must match the canonical session header");
	}

	var _owner_id = BladeRunIdentityRequireAllocated(
		_coordinator.__kernel.identity,
		_state.event_owner_id,
		BladeRunIdKind.EventOwner
	);
	var _player_id = BladeRunIdentityRequireAllocated(
		_coordinator.__kernel.identity,
		_state.player.instance_id,
		BladeRunIdKind.Instance
	);
	if (_owner_id != "own:1") {
		_BladeRunCoordinatorFail("event owner ID", "must remain own:1");
	}
	_BladeCombatRuntimeRequire(_coordinator.__combat);
	if (_coordinator.__combat.identity != _coordinator.__kernel.identity
		|| _coordinator.__combat.event_owner_id != _owner_id) {
		_BladeRunCoordinatorFail(
			"combat ownership", "must share the active run identity and event owner"
		);
	}
	if (_player_id != "ins:1") {
		_BladeRunCoordinatorFail("player instance ID", "must remain ins:1");
	}
	if (_state.player.ship_id != _ship) {
		_BladeRunCoordinatorFail("player ship ID", "must match the run ship ID");
	}

	var _started_tick = _BladeRunCoordinatorInteger(
		_state.started_tick,
		0,
		0,
		"run started tick"
	);
	var _terminal_tick = _BladeRunCoordinatorInteger(
		_state.terminal_tick,
		-1,
		_maximum,
		"run terminal tick"
	);
	var _player_started_tick = _BladeRunCoordinatorInteger(
		_state.player.started_tick,
		0,
		0,
		"player started tick"
	);
	var _player_terminal_tick = _BladeRunCoordinatorInteger(
		_state.player.terminal_tick,
		-1,
		_maximum,
		"player terminal tick"
	);
	var _counters = BladeSimulationClockGetCounters(_coordinator.__kernel.clock);
	if (_terminal_tick > _counters.simulation_tick) {
		_BladeRunCoordinatorFail("run terminal tick", "cannot exceed simulation time");
	}
	if (_player_started_tick != _started_tick
		|| _player_terminal_tick != _terminal_tick) {
		_BladeRunCoordinatorFail("player lifecycle ticks", "must match the run lifecycle ticks");
	}

	if (_lifecycle == BladeRunLifecycle.Active) {
		if (_player_lifecycle != BladePlayerLifecycle.Active || _terminal_tick != -1) {
			_BladeRunCoordinatorFail(
				"active lifecycle",
				"requires an active player and no terminal tick"
			);
		}
	} else if (_player_lifecycle != BladePlayerLifecycle.Released || _terminal_tick < 0) {
		_BladeRunCoordinatorFail(
			"terminal lifecycle",
			"requires a released player and terminal tick"
		);
	}

	var _view = {
		schema_version: 1,
		mode: _mode,
		lifecycle: _lifecycle,
		ship_id: _ship,
		difficulty_id: _difficulty,
		run_seed: _seed,
		event_owner_id: _owner_id,
		started_tick: _started_tick,
		terminal_tick: _terminal_tick,
		pause: BladePauseRegistrySnapshot(_coordinator.__pause_registry),
		combat: BladeCombatRuntimeSnapshot(_coordinator.__combat),
		player: {
			schema_version: 1,
			instance_id: _player_id,
			ship_id: _ship,
			lifecycle: _player_lifecycle,
			started_tick: _player_started_tick,
			terminal_tick: _player_terminal_tick,
		},
	};
	if (!is_undefined(_coordinator.__stage)) {
		_view.stage = BladeStageExecutorSnapshot(
			_BladeRunStageAttached(_coordinator)
		);
	}
	return _view;
}

/// Encodes one detached state view in fixed BPS1 then BRS1 field order.
function _BladeRunCoordinatorStateCanonical(_view) {
	var _maximum = int64("9223372036854775807");
	var _player = BladeCanonicalRecord("BPS1", [
		BladeCanonicalIntegerString(_view.player.schema_version, 1, 1, "player schema version"),
		_view.player.instance_id,
		_view.player.ship_id,
		_BladeRunCoordinatorPlayerLifecycleToken(_view.player.lifecycle),
		BladeCanonicalIntegerString(_view.player.started_tick, 0, 0, "player started tick"),
		BladeCanonicalIntegerString(_view.player.terminal_tick, -1, _maximum, "player terminal tick"),
	]);
	return BladeCanonicalRecord("BRS1", [
		BladeCanonicalIntegerString(_view.schema_version, 1, 1, "run schema version"),
		_BladeRunCoordinatorModeToken(_view.mode),
		_BladeRunCoordinatorLifecycleToken(_view.lifecycle),
		_view.ship_id,
		_view.difficulty_id,
		BladeCanonicalIntegerString(_view.run_seed, 0, int64("4294967295"), "run seed"),
		_view.event_owner_id,
		BladeCanonicalIntegerString(_view.started_tick, 0, 0, "run started tick"),
		BladeCanonicalIntegerString(_view.terminal_tick, -1, _maximum, "run terminal tick"),
		_player,
	]);
}

/// Requires an active run before any command can advance deterministic kernel state.
function _BladeRunCoordinatorRequireActive(_coordinator) {
	var _view = _BladeRunCoordinatorStateView(_coordinator);
	if (_view.lifecycle != BladeRunLifecycle.Active) {
		_BladeRunCoordinatorFail("run lifecycle", "command requires an active run");
	}
	return _view;
}

/// Rejects lifecycle replacement and nested advance commands while a kernel batch is executing.
function _BladeRunCoordinatorRequireNotAdvancing(_coordinator, _command) {
	_BladeRunCoordinatorRequire(_coordinator);
	if (_coordinator.__is_advancing) {
		_BladeRunCoordinatorFail(
			"advancing guard",
			_command + " cannot run while coordinator is advancing"
		);
	}
	return _coordinator;
}

/// Validates one active non-reentrant advance before setting its transient execution guard.
function _BladeRunCoordinatorBeginAdvance(_coordinator) {
	_BladeRunCoordinatorRequireNotAdvancing(_coordinator, "advance command");
	_BladeRunCoordinatorRequireActive(_coordinator);
	_coordinator.__is_advancing = true;
}

/// Applies one terminal lifecycle only after all current state and clock values are validated.
function _BladeRunCoordinatorTransitionTerminal(
	_coordinator, _target_lifecycle, _terminal_reason = undefined
) {
	_BladeRunCoordinatorRequireNotAdvancing(_coordinator, "terminal command");
	_BladeRunCoordinatorRequireActive(_coordinator);
	var _target = _BladeRunCoordinatorLifecycle(_target_lifecycle);
	if (_target != BladeRunLifecycle.Completed
		&& _target != BladeRunLifecycle.Aborted) {
		_BladeRunCoordinatorFail("run lifecycle", "terminal command requires completed or aborted");
	}
	var _tick = _BladeRunCoordinatorCurrentTick(_coordinator);
	var _counters = BladeSimulationClockGetCounters(_coordinator.__kernel.clock);
	var _boundary = BladePauseRunBoundary.Completed;
	var _combat_reason = BladeCombatTerminalReason.RunCompleted;
	if (_target == BladeRunLifecycle.Aborted) {
		_boundary = BladePauseRunBoundary.Aborted;
		_combat_reason = BladeCombatTerminalReason.RunAborted;
	}
	if (!is_undefined(_terminal_reason)) {
		_combat_reason = _BladeCombatRuntimeInteger(
			_terminal_reason, BladeCombatTerminalReason.RunCompleted,
			BladeCombatTerminalReason.RunLoad, "terminal boundary reason"
		);
	}
	if ((_target == BladeRunLifecycle.Completed
			&& _combat_reason != BladeCombatTerminalReason.RunCompleted)
		|| (_target == BladeRunLifecycle.Aborted
			&& _combat_reason != BladeCombatTerminalReason.RunAborted
			&& _combat_reason != BladeCombatTerminalReason.RunLoad)) {
		_BladeRunCoordinatorFail(
			"terminal boundary reason", "must match the selected lifecycle"
		);
	}
	if (_combat_reason == BladeCombatTerminalReason.RunLoad) {
		_boundary = BladePauseRunBoundary.Load;
	}
	var _stage_boundary = _BladeRunStagePrepareAbort(
		_coordinator, _combat_reason
	);
	var _combat_plan = BladeCombatRuntimeBoundaryPlan(
		_coordinator.__combat, _combat_reason,
		_counters.simulation_tick, _counters.combat_tick
	);
	var _pause_report = BladePauseRegistryRunBoundary(
		_coordinator.__pause_registry,
		_boundary,
		_tick
	);
	var _combat_report = BladeCombatRuntimeCommitBoundary(
		_coordinator.__combat, _combat_plan
	);
	var _stage_report = _BladeRunStageCommitAbort(_stage_boundary);

	// Pause cleanup preflight passed, so terminal run/player state now changes together.
	_coordinator.__state.lifecycle = _target;
	_coordinator.__state.terminal_tick = _tick;
	_coordinator.__state.player.lifecycle = BladePlayerLifecycle.Released;
	_coordinator.__state.player.terminal_tick = _tick;
	var _result = BladeRunCoordinatorSnapshot(_coordinator);
	_result.pause_boundary_report = _pause_report;
	_result.combat_boundary_report = _combat_report;
	if (!is_undefined(_stage_report)) {
		_result.stage_boundary_report = _stage_report;
	}
	return _result;
}

/// @func BladeRunCoordinatorCreate(content_fingerprint, content_id_predicate, ship_id, difficulty_id, run_mode, run_seed, max_catch_up_ticks, gameplay_plane)
/// Creates an active deterministic attempt and retains only immutable construction inputs for later reset.
function BladeRunCoordinatorCreate(
	_content_fingerprint,
	_content_id_predicate,
	_ship_id,
	_difficulty_id,
	_run_mode,
	_run_seed,
	_max_catch_up_ticks = 8,
	_gameplay_plane = undefined
) {
	var _plan = _BladeRunCoordinatorBuildAttempt(
		_content_fingerprint,
		_content_id_predicate,
		_max_catch_up_ticks,
		_ship_id,
		_difficulty_id,
		_run_mode,
		_run_seed,
		_gameplay_plane
	);
	return {
		__blade_run_coordinator_version: 3,
		__content_fingerprint: _plan.kernel.header.get_content_contract_fingerprint(),
		__content_id_predicate: _content_id_predicate,
		__max_catch_up_ticks: _plan.kernel.clock.max_catch_up_ticks,
		__kernel: _plan.kernel,
		__combat: _plan.combat,
		__stage: undefined,
		__is_advancing: false,
		__pause_registry: _plan.pause_registry,
		__state: _plan.state,
	};
}

/// @func BladeRunCoordinatorReset(coordinator, ship_id, difficulty_id, run_mode, run_seed)
/// Builds fresh kernel, combat, stage, pause, and run owners before replacing the prior attempt.
function BladeRunCoordinatorReset(
	_coordinator,
	_ship_id,
	_difficulty_id,
	_run_mode,
	_run_seed
) {
	_BladeRunCoordinatorRequireNotAdvancing(_coordinator, "reset command");
	var _gameplay_plane = BladeCombatRuntimePlaneCopy(_coordinator.__combat);
	var _plan = _BladeRunCoordinatorBuildAttempt(
		_coordinator.__content_fingerprint,
		_coordinator.__content_id_predicate,
		_coordinator.__max_catch_up_ticks,
		_ship_id,
		_difficulty_id,
		_run_mode,
		_run_seed,
		_gameplay_plane
	);
	var _new_stage = undefined;
	if (!is_undefined(_coordinator.__stage)) {
		_new_stage = BladeStageExecutorRestart(_coordinator.__stage);
		BladeStageExecutorBindRuntime(
			_new_stage, _plan.kernel, _plan.combat
		);
	}
	var _old_stage_boundary = _BladeRunStagePrepareAbort(
		_coordinator, BladeCombatTerminalReason.RunReset
	);
	var _old_counters = BladeSimulationClockGetCounters(_coordinator.__kernel.clock);
	var _old_combat_plan = BladeCombatRuntimeBoundaryPlan(
		_coordinator.__combat, BladeCombatTerminalReason.RunReset,
		_old_counters.simulation_tick, _old_counters.combat_tick
	);
	var _old_pause_report = BladePauseRegistryRunBoundary(
		_coordinator.__pause_registry,
		BladePauseRunBoundary.Reset,
		_BladeRunCoordinatorCurrentTick(_coordinator)
	);
	var _old_combat_report = BladeCombatRuntimeCommitBoundary(
		_coordinator.__combat, _old_combat_plan
	);
	var _old_stage_report = _BladeRunStageCommitAbort(_old_stage_boundary);

	// Replacement planning and old cleanup passed, so every owned reference swaps together.
	_coordinator.__kernel = _plan.kernel;
	_coordinator.__combat = _plan.combat;
	_coordinator.__stage = _new_stage;
	_coordinator.__pause_registry = _plan.pause_registry;
	_coordinator.__state = _plan.state;
	var _result = BladeRunCoordinatorSnapshot(_coordinator);
	_result.prior_pause_boundary_report = _old_pause_report;
	_result.prior_combat_boundary_report = _old_combat_report;
	if (!is_undefined(_old_stage_report)) {
		_result.prior_stage_boundary_report = _old_stage_report;
	}
	return _result;
}

/// @func BladeRunCoordinatorComplete(coordinator)
/// Transitions one active attempt to completed and releases its player at the current simulation tick.
function BladeRunCoordinatorComplete(_coordinator) {
	return _BladeRunCoordinatorTransitionTerminal(
		_coordinator,
		BladeRunLifecycle.Completed
	);
}

/// @func BladeRunCoordinatorAbort(coordinator)
/// Transitions one active attempt to aborted and releases its player at the current simulation tick.
function BladeRunCoordinatorAbort(_coordinator) {
	return _BladeRunCoordinatorTransitionTerminal(
		_coordinator,
		BladeRunLifecycle.Aborted
	);
}

/// @func BladeRunCoordinatorLoadBoundary(coordinator)
/// Ends the active attempt for an explicit load without granting rewards or retaining combat.
function BladeRunCoordinatorLoadBoundary(_coordinator) {
	return _BladeRunCoordinatorTransitionTerminal(
		_coordinator,
		BladeRunLifecycle.Aborted,
		BladeCombatTerminalReason.RunLoad
	);
}

/// @func BladeRunCoordinatorStepDirect(coordinator, raw_state, eligibility, simulate_callback)
/// Advances one active-run tick and supplies callbacks only a run snapshot, input snapshot, and tick.
function BladeRunCoordinatorStepDirect(
	_coordinator,
	_raw_state,
	_eligibility,
	_simulate_callback = undefined
) {
	_BladeRunCoordinatorBeginAdvance(_coordinator);
	try {
		var _bound_callback = _BladeRunCoordinatorBindSimulationCallback(
			_coordinator,
			_simulate_callback
		);
		return BladeKernelStepDirect(
			_coordinator.__kernel,
			_raw_state,
			_BladeRunCoordinatorPauseEligibility(_coordinator, _eligibility),
			_bound_callback
		);
	} finally {
		_coordinator.__is_advancing = false;
	}
}

/// @func BladeRunCoordinatorStepManyDirect(coordinator, raw_state, tick_count, eligibility, simulate_callback)
/// Runs exact active-run ticks while pause ownership constrains every supplied base mask.
function BladeRunCoordinatorStepManyDirect(
	_coordinator, _raw_state, _tick_count, _eligibility, _simulate_callback = undefined
) {
	_BladeRunCoordinatorBeginAdvance(_coordinator);
	try {
		return BladeKernelStepManyDirect(
			_coordinator.__kernel,
			_raw_state,
			_tick_count,
			_BladeRunCoordinatorPauseEligibility(_coordinator, _eligibility),
			_BladeRunCoordinatorBindSimulationCallback(_coordinator, _simulate_callback)
		);
	} finally {
		_coordinator.__is_advancing = false;
	}
}

/// @func BladeRunCoordinatorAdvancePresentation(coordinator, delta_us, raw_state, eligibility, simulate_callback)
/// Advances one presentation update and every due active-run tick through owned pause resolution.
function BladeRunCoordinatorAdvancePresentation(
	_coordinator, _delta_us, _raw_state, _eligibility, _simulate_callback = undefined
) {
	_BladeRunCoordinatorBeginAdvance(_coordinator);
	try {
		return BladeKernelAdvancePresentation(
			_coordinator.__kernel,
			_delta_us,
			_raw_state,
			_BladeRunCoordinatorPauseEligibility(_coordinator, _eligibility),
			_BladeRunCoordinatorBindSimulationCallback(_coordinator, _simulate_callback)
		);
	} finally {
		_coordinator.__is_advancing = false;
	}
}

/// @func BladeRunCoordinatorSnapshot(coordinator)
/// Returns detached run ownership and includes stage state only when one is attached.
function BladeRunCoordinatorSnapshot(_coordinator) {
	return _BladeRunCoordinatorStateView(_coordinator);
}

/// @func BladeRunCoordinatorCanRecordNormalResult(coordinator)
/// Allows future normal-run persistence only for a completed non-practice attempt.
function BladeRunCoordinatorCanRecordNormalResult(_coordinator) {
	var _view = _BladeRunCoordinatorStateView(_coordinator);
	return _view.mode == BladeRunMode.Normal
		&& _view.lifecycle == BladeRunLifecycle.Completed;
}

/// @func BladeRunCoordinatorCanonical(coordinator)
/// Encodes fixed legacy ownership fields and appends stage state only when attached.
function BladeRunCoordinatorCanonical(_coordinator) {
	var _view = _BladeRunCoordinatorStateView(_coordinator);
	var _fields = [
		_BladeRunCoordinatorStateCanonical(_view),
		BladePauseRegistryCanonical(_coordinator.__pause_registry),
		BladeCombatRuntimeCanonical(_coordinator.__combat),
		BladeKernelGameplayCanonical(_coordinator.__kernel),
	];
	if (!is_undefined(_coordinator.__stage)) {
		array_push(_fields, BladeStageExecutorCanonical(_coordinator.__stage));
	}
	return BladeCanonicalRecord("BRC3", _fields);
}

/// @func BladeRunCoordinatorHash(coordinator)
/// Hashes the complete BRC3 record so run, combat, and kernel state all participate.
function BladeRunCoordinatorHash(_coordinator) {
	return BladeCanonicalHashUtf8(BladeRunCoordinatorCanonical(_coordinator));
}

/// @func BladeRunCoordinatorDiagnostics(coordinator)
/// Returns detached ownership diagnostics, adding stage state only when attached.
function BladeRunCoordinatorDiagnostics(_coordinator) {
	var _snapshot = _BladeRunCoordinatorStateView(_coordinator);
	var _canonical = BladeRunCoordinatorCanonical(_coordinator);
	var _diagnostics = {
		snapshot: _snapshot,
		pause: _snapshot.pause,
		combat: _snapshot.combat,
		kernel: BladeKernelDiagnostics(_coordinator.__kernel),
		canonical: _canonical,
		hash: BladeCanonicalHashUtf8(_canonical),
	};
	if (!is_undefined(_coordinator.__stage)) {
		_diagnostics.stage = _snapshot.stage;
	}
	return _diagnostics;
}
