/// @description Focused project-owned tests for authoritative run and player lifecycle state.

/// Recognizes the run-selection fixtures plus one stage used to prove typed namespace rejection.
function _BladeRunCoordinatorTestKnownContent(_content_id) {
	return _content_id == "ship.maynii"
		|| _content_id == "ship.ciela"
		|| _content_id == "ship.kolar"
		|| _content_id == "difficulty.easy"
		|| _content_id == "difficulty.normal"
		|| _content_id == "difficulty.hard"
		|| _content_id == "stage.extra.dreams_of_a_clockwork_angel";
}

/// Creates one standard fixture while allowing each deterministic run input to vary independently.
function _BladeRunCoordinatorTestCreate(
	_ship_id = "ship.maynii",
	_difficulty_id = "difficulty.normal",
	_run_mode = BladeRunMode.Normal,
	_run_seed = 305419896
) {
	return BladeRunCoordinatorCreate(
		"sha1:d9a345101d9fa9971924bb2b9138a39dd5fd7c0b",
		method({}, _BladeRunCoordinatorTestKnownContent),
		_ship_id,
		_difficulty_id,
		_run_mode,
		_run_seed,
		8
	);
}

/// Returns one deterministic state fragment through the coordinator's kernel-hiding callback adapter.
function _BladeRunCoordinatorTestDirtySimulation(_run_snapshot, _snapshot, _tick) {
	return BladeCanonicalRecord("RT2", [
		string(_tick.simulation_tick),
		string(_tick.combat_tick),
		_run_snapshot.ship_id,
		BladeInputSnapshotCanonical(_snapshot),
	]);
}

/// Steps one exact active-run tick with neutral semantic input and all gameplay domains eligible.
function _BladeRunCoordinatorTestStep(_coordinator, _callback = undefined) {
	return BladeRunCoordinatorStepDirect(
		_coordinator,
		BladeInputRawStateCreate(0, 0, 0),
		BladeClockDomain.Stage
			| BladeClockDomain.Actor
			| BladeClockDomain.Boss
			| BladeClockDomain.Combat,
		_callback
	);
}

/// Checks the complete minimal initial shape, deterministic IDs, and deferred-field boundaries.
function _BladeRunCoordinatorTestInitialState() {
	var _coordinator = _BladeRunCoordinatorTestCreate(
		"ship.maynii",
		"difficulty.easy",
		BladeRunMode.Normal,
		123
	);
	var _snapshot = BladeRunCoordinatorSnapshot(_coordinator);
	BladeKernelTestAssertEqual(_snapshot.schema_version, 1, "run schema version");
	BladeKernelTestAssertEqual(_snapshot.mode, BladeRunMode.Normal, "normal run mode");
	BladeKernelTestAssertEqual(
		_snapshot.lifecycle,
		BladeRunLifecycle.Active,
		"initial run lifecycle"
	);
	BladeKernelTestAssertEqual(_snapshot.ship_id, "ship.maynii", "stable ship ID");
	BladeKernelTestAssertEqual(
		_snapshot.difficulty_id,
		"difficulty.easy",
		"stable difficulty ID"
	);
	BladeKernelTestAssertEqual(_snapshot.run_seed, int64(123), "normalized run seed");
	BladeKernelTestAssertEqual(_snapshot.event_owner_id, "own:1", "run event owner ID");
	BladeKernelTestAssertEqual(_snapshot.started_tick, int64(0), "run started tick");
	BladeKernelTestAssertEqual(_snapshot.terminal_tick, int64(-1), "open terminal tick");
	BladeKernelTestAssertEqual(_snapshot.player.schema_version, 1, "player schema version");
	BladeKernelTestAssertEqual(_snapshot.player.instance_id, "ins:1", "player instance ID");
	BladeKernelTestAssertEqual(_snapshot.player.ship_id, "ship.maynii", "player ship ID");
	BladeKernelTestAssertEqual(
		_snapshot.player.lifecycle,
		BladePlayerLifecycle.Active,
		"initial player lifecycle"
	);
	BladeKernelTestAssertEqual(_snapshot.player.started_tick, int64(0), "player started tick");
	BladeKernelTestAssertEqual(
		_snapshot.player.terminal_tick,
		int64(-1),
		"open player terminal tick"
	);
	BladeKernelTestAssertFalse(
		BladeRunCoordinatorCanRecordNormalResult(_coordinator),
		"active normal run cannot record a result"
	);
	BladeKernelTestAssertFalse(
		variable_struct_exists(_snapshot, "score"),
		"run scope excludes scoring"
	);
	BladeKernelTestAssertFalse(
		variable_struct_exists(_snapshot.player, "lives"),
		"player scope excludes balance resources"
	);
	BladeKernelTestAssertFalse(
		variable_struct_exists(_snapshot.player, "weapon"),
		"player scope excludes combat behavior"
	);

	var _identity = BladeRunCoordinatorDiagnostics(_coordinator).kernel.identity;
	BladeKernelTestAssertEqual(_identity.instance, int64(1), "one player instance allocated");
	BladeKernelTestAssertEqual(_identity.event_owner, int64(1), "one run owner allocated");
	BladeKernelTestAssertEqual(_identity.attack, int64(0), "no attack state invented");
}

/// Proves equal inputs match byte-for-byte while every selected deterministic input changes state.
function _BladeRunCoordinatorTestRepeatability() {
	var _first = _BladeRunCoordinatorTestCreate();
	var _second = _BladeRunCoordinatorTestCreate();
	var _baseline = BladeRunCoordinatorCanonical(_first);
	BladeKernelTestAssertEqual(
		string_copy(_baseline, 1, 4),
		"BRC3",
		"version 3 coordinator record"
	);
	BladeKernelTestAssertEqual(
		_baseline,
		BladeRunCoordinatorCanonical(_second),
		"equal run inputs produce equal canonical bytes"
	);
	BladeKernelTestAssertEqual(
		BladeRunCoordinatorHash(_first),
		BladeRunCoordinatorHash(_second),
		"equal run inputs produce equal hashes"
	);

	var _changed_ship = _BladeRunCoordinatorTestCreate("ship.ciela");
	var _changed_difficulty = _BladeRunCoordinatorTestCreate(
		"ship.maynii",
		"difficulty.hard"
	);
	var _changed_mode = _BladeRunCoordinatorTestCreate(
		"ship.maynii",
		"difficulty.normal",
		BladeRunMode.Practice
	);
	var _changed_seed = _BladeRunCoordinatorTestCreate(
		"ship.maynii",
		"difficulty.normal",
		BladeRunMode.Normal,
		305419897
	);
	BladeKernelTestAssertNotEqual(
		_baseline,
		BladeRunCoordinatorCanonical(_changed_ship),
		"ship selection participates in canonical state"
	);
	BladeKernelTestAssertNotEqual(
		_baseline,
		BladeRunCoordinatorCanonical(_changed_difficulty),
		"difficulty selection participates in canonical state"
	);
	BladeKernelTestAssertNotEqual(
		_baseline,
		BladeRunCoordinatorCanonical(_changed_mode),
		"run mode participates in canonical state"
	);
	BladeKernelTestAssertNotEqual(
		_baseline,
		BladeRunCoordinatorCanonical(_changed_seed),
		"run seed participates in canonical state"
	);
}

/// Advances clock, input, and state transcripts, then proves reset matches fresh construction.
function _BladeRunCoordinatorTestDeterministicReset() {
	var _coordinator = _BladeRunCoordinatorTestCreate();
	var _initial = BladeRunCoordinatorCanonical(_coordinator);
	var _callback = method({}, _BladeRunCoordinatorTestDirtySimulation);
	_BladeRunCoordinatorTestStep(_coordinator, _callback);
	var _dirty = BladeRunCoordinatorDiagnostics(_coordinator);
	BladeKernelTestAssertEqual(
		_dirty.kernel.clock.simulation_tick,
		int64(1),
		"dirty simulation tick"
	);
	BladeKernelTestAssertNotEqual(
		_dirty.canonical,
		_initial,
		"one stepped tick dirties canonical kernel state"
	);

	BladeRunCoordinatorReset(
		_coordinator,
		"ship.maynii",
		"difficulty.normal",
		BladeRunMode.Normal,
		305419896
	);
	var _fresh = _BladeRunCoordinatorTestCreate();
	BladeKernelTestAssertEqual(
		BladeRunCoordinatorCanonical(_coordinator),
		BladeRunCoordinatorCanonical(_fresh),
		"reset state matches fresh construction"
	);
	var _reset = BladeRunCoordinatorDiagnostics(_coordinator);
	BladeKernelTestAssertEqual(_reset.kernel.clock.simulation_tick, int64(0), "reset clock");
	BladeKernelTestAssertEqual(_reset.kernel.identity.attack, int64(0), "reset attack count");
	BladeKernelTestAssertEqual(_reset.snapshot.event_owner_id, "own:1", "reset run owner ID");
	BladeKernelTestAssertEqual(_reset.snapshot.player.instance_id, "ins:1", "reset player ID");

	BladeRunCoordinatorReset(
		_coordinator,
		"ship.kolar",
		"difficulty.hard",
		BladeRunMode.Practice,
		-1
	);
	var _changed_fresh = _BladeRunCoordinatorTestCreate(
		"ship.kolar",
		"difficulty.hard",
		BladeRunMode.Practice,
		int64("4294967295")
	);
	BladeKernelTestAssertEqual(
		BladeRunCoordinatorCanonical(_coordinator),
		BladeRunCoordinatorCanonical(_changed_fresh),
		"reset accepts new inputs and canonical seed normalization"
	);
}

/// Rejects unknown, wrongly typed, and malformed reset inputs without replacing live state.
function _BladeRunCoordinatorTestInvalidResetIsAtomic() {
	var _coordinator = _BladeRunCoordinatorTestCreate();
	var _before = BladeRunCoordinatorCanonical(_coordinator);
	BladeKernelTestAssertThrows(
		method({ coordinator: _coordinator }, function() {
			// Supply a known stage where a ship content ID is required.
			BladeRunCoordinatorReset(
				self.coordinator,
				"stage.extra.dreams_of_a_clockwork_angel",
				"difficulty.normal",
				BladeRunMode.Normal,
				1
			);
		}),
		"ship ID: expected a known ship.",
		"stage cannot serve as a ship"
	);
	BladeKernelTestAssertThrows(
		method({ coordinator: _coordinator }, function() {
			// Supply the extra-stage ID where one of the three difficulty IDs is required.
			BladeRunCoordinatorReset(
				self.coordinator,
				"ship.maynii",
				"stage.extra.dreams_of_a_clockwork_angel",
				BladeRunMode.Normal,
				1
			);
		}),
		"difficulty ID: expected a known difficulty.",
		"extra stage cannot serve as a difficulty"
	);
	BladeKernelTestAssertThrows(
		method({ coordinator: _coordinator }, function() {
			// Supply an ID outside the injected canonical registry.
			BladeRunCoordinatorReset(
				self.coordinator,
				"ship.unknown",
				"difficulty.normal",
				BladeRunMode.Normal,
				1
			);
		}),
		"unknown content ID ship.unknown",
		"unknown ship rejected"
	);
	BladeKernelTestAssertThrows(
		method({ coordinator: _coordinator }, function() {
			// Supply an enum value outside the closed Normal and Practice range.
			BladeRunCoordinatorReset(
				self.coordinator,
				"ship.maynii",
				"difficulty.normal",
				3,
				1
			);
		}),
		"run mode: must be between 1 and 2 inclusive",
		"unknown run mode rejected"
	);
	BladeKernelTestAssertThrows(
		method({ coordinator: _coordinator }, function() {
			// Supply a fractional seed so deterministic integer normalization cannot proceed.
			BladeRunCoordinatorReset(
				self.coordinator,
				"ship.maynii",
				"difficulty.normal",
				BladeRunMode.Normal,
				1.5
			);
		}),
		"run seed: must not contain a fractional part",
		"fractional run seed rejected"
	);
	BladeKernelTestAssertEqual(
		BladeRunCoordinatorCanonical(_coordinator),
		_before,
		"failed resets preserve the complete live attempt"
	);
}

/// Confirms simulation callbacks receive detached run/tick views and never the owned kernel reference.
function _BladeRunCoordinatorTestCallbackIsolation() {
	var _coordinator = _BladeRunCoordinatorTestCreate();
	var _observed = {
		called: false,
		run_is_struct: false,
		has_kernel_marker: true,
		has_kernel_field: true,
		input_is_string: false,
		tick_is_struct: false,
		tick_value: int64(-1),
		combat_tick_value: int64(-1),
	};
	var _callback = method(_observed, function(_run_snapshot, _input_snapshot, _tick) {
		// Inspect and mutate only the detached or immutable values supplied by the adapter.
		self.called = true;
		self.run_is_struct = is_struct(_run_snapshot);
		self.has_kernel_marker = variable_struct_exists(
			_run_snapshot,
			"__blade_kernel_version"
		);
		self.has_kernel_field = variable_struct_exists(_run_snapshot, "__kernel");
		self.input_is_string = is_string(_input_snapshot);
		self.tick_is_struct = is_struct(_tick);
		self.tick_value = _tick.simulation_tick;
		self.combat_tick_value = _tick.combat_tick;
		_run_snapshot.ship_id = "ship.changed";
		_run_snapshot.player.instance_id = "ins:999";
		_tick.simulation_tick = int64(999);
		_tick.combat_tick = int64(999);
		return BladeCanonicalRecord("RCI1", [
			_input_snapshot,
			string(self.tick_value),
		]);
	});

	_BladeRunCoordinatorTestStep(_coordinator, _callback);
	BladeKernelTestAssertTrue(_observed.called, "isolated callback was invoked");
	BladeKernelTestAssertTrue(_observed.run_is_struct, "callback receives run snapshot");
	BladeKernelTestAssertFalse(
		_observed.has_kernel_marker,
		"callback run argument is not a kernel"
	);
	BladeKernelTestAssertFalse(
		_observed.has_kernel_field,
		"callback run argument has no owned kernel field"
	);
	BladeKernelTestAssertTrue(
		_observed.input_is_string,
		"callback receives immutable input snapshot"
	);
	BladeKernelTestAssertTrue(_observed.tick_is_struct, "callback receives detached tick view");
	BladeKernelTestAssertEqual(_observed.tick_value, int64(1), "callback tick value");
	BladeKernelTestAssertEqual(
		_observed.combat_tick_value,
		int64(1),
		"callback receives the Combat tick value"
	);
	var _fresh = BladeRunCoordinatorSnapshot(_coordinator);
	BladeKernelTestAssertEqual(_fresh.ship_id, "ship.maynii", "callback cannot change run ship");
	BladeKernelTestAssertEqual(_fresh.player.instance_id, "ins:1", "callback cannot change player ID");
	BladeKernelTestAssertEqual(
		BladeRunCoordinatorDiagnostics(_coordinator).kernel.clock.simulation_tick,
		int64(1),
		"callback tick mutation cannot change the owned clock"
	);
	BladeKernelTestAssertEqual(
		BladeRunCoordinatorDiagnostics(_coordinator).kernel.clock.combat_tick,
		int64(1),
		"coordinator advances the Combat counter"
	);

	var _reference = _BladeRunCoordinatorTestCreate();
	var _reference_callback = method({}, function(_run_snapshot, _input_snapshot, _tick) {
		// Return the same state fragment without attempting to mutate any callback view.
		return BladeCanonicalRecord("RCI1", [
			_input_snapshot,
			string(_tick.simulation_tick),
		]);
	});
	_BladeRunCoordinatorTestStep(_reference, _reference_callback);
	BladeKernelTestAssertEqual(
		BladeRunCoordinatorCanonical(_coordinator),
		BladeRunCoordinatorCanonical(_reference),
		"callback view mutation cannot alter canonical kernel state"
	);
}

/// Exercises completed and aborted terminals, invalid transitions, reset, and stepping guards.
function _BladeRunCoordinatorTestLifecycleTransitions() {
	var _completed = _BladeRunCoordinatorTestCreate();
	_BladeRunCoordinatorTestStep(_completed);
	var _completed_view = BladeRunCoordinatorComplete(_completed);
	BladeKernelTestAssertEqual(
		_completed_view.lifecycle,
		BladeRunLifecycle.Completed,
		"completed lifecycle"
	);
	BladeKernelTestAssertEqual(
		_completed_view.player.lifecycle,
		BladePlayerLifecycle.Released,
		"completed run releases player"
	);
	BladeKernelTestAssertEqual(_completed_view.terminal_tick, int64(1), "completion tick");
	BladeKernelTestAssertEqual(
		_completed_view.player.terminal_tick,
		int64(1),
		"player completion tick"
	);
	BladeKernelTestAssertTrue(
		BladeRunCoordinatorCanRecordNormalResult(_completed),
		"completed normal run can record a future result"
	);
	BladeKernelTestAssertThrows(
		method({ coordinator: _completed }, function() {
			// Attempt to complete an already terminal run.
			BladeRunCoordinatorComplete(self.coordinator);
		}),
		"command requires an active run",
		"double completion rejected"
	);
	BladeKernelTestAssertThrows(
		method({ coordinator: _completed }, function() {
			// Attempt to replace a completed outcome with an aborted one.
			BladeRunCoordinatorAbort(self.coordinator);
		}),
		"command requires an active run",
		"abort after completion rejected"
	);
	BladeKernelTestAssertThrows(
		method({ coordinator: _completed }, function() {
			// Attempt simulation after terminal state releases the player.
			_BladeRunCoordinatorTestStep(self.coordinator);
		}),
		"command requires an active run",
		"terminal stepping rejected"
	);
	BladeKernelTestAssertEqual(
		BladeRunCoordinatorDiagnostics(_completed).kernel.clock.simulation_tick,
		int64(1),
		"rejected terminal step preserves the clock"
	);

	BladeRunCoordinatorReset(
		_completed,
		"ship.maynii",
		"difficulty.normal",
		BladeRunMode.Normal,
		305419896
	);
	BladeKernelTestAssertEqual(
		BladeRunCoordinatorSnapshot(_completed).lifecycle,
		BladeRunLifecycle.Active,
		"completed run can reset to active"
	);

	var _aborted = _BladeRunCoordinatorTestCreate();
	var _aborted_view = BladeRunCoordinatorAbort(_aborted);
	BladeKernelTestAssertEqual(
		_aborted_view.lifecycle,
		BladeRunLifecycle.Aborted,
		"aborted lifecycle"
	);
	BladeKernelTestAssertEqual(_aborted_view.terminal_tick, int64(0), "abort tick");
	BladeKernelTestAssertFalse(
		BladeRunCoordinatorCanRecordNormalResult(_aborted),
		"aborted normal run cannot record a result"
	);
	BladeKernelTestAssertThrows(
		method({ coordinator: _aborted }, function() {
			// Attempt to replace an aborted outcome with completion.
			BladeRunCoordinatorComplete(self.coordinator);
		}),
		"command requires an active run",
		"completion after abort rejected"
	);
}

/// Proves practice never exposes normal-result eligibility and snapshots remain detached.
function _BladeRunCoordinatorTestPracticeAndDetachedViews() {
	var _practice = _BladeRunCoordinatorTestCreate(
		"ship.ciela",
		"difficulty.easy",
		BladeRunMode.Practice,
		77
	);
	var _canonical = BladeRunCoordinatorCanonical(_practice);
	var _view = BladeRunCoordinatorSnapshot(_practice);
	_view.mode = BladeRunMode.Normal;
	_view.ship_id = "ship.changed";
	_view.player.instance_id = "ins:999";
	_view.player.lifecycle = BladePlayerLifecycle.Released;
	var _fresh = BladeRunCoordinatorSnapshot(_practice);
	BladeKernelTestAssertEqual(_fresh.mode, BladeRunMode.Practice, "fresh practice mode");
	BladeKernelTestAssertEqual(_fresh.ship_id, "ship.ciela", "fresh ship ID");
	BladeKernelTestAssertEqual(_fresh.player.instance_id, "ins:1", "fresh player ID");
	BladeKernelTestAssertEqual(
		_fresh.player.lifecycle,
		BladePlayerLifecycle.Active,
		"fresh player lifecycle"
	);
	BladeKernelTestAssertEqual(
		BladeRunCoordinatorCanonical(_practice),
		_canonical,
		"mutated snapshot cannot alter canonical state"
	);
	BladeKernelTestAssertFalse(
		BladeRunCoordinatorCanRecordNormalResult(_practice),
		"active practice cannot record a normal result"
	);
	BladeRunCoordinatorComplete(_practice);
	BladeKernelTestAssertFalse(
		BladeRunCoordinatorCanRecordNormalResult(_practice),
		"completed practice cannot record a normal result"
	);
}

/// @func BladeRunCoordinatorTestsRun(state)
/// Registers focused run coordinator cases on the shared project-owned test state.
function BladeRunCoordinatorTestsRun(_state) {
	BladeKernelTestRunCase(_state, "run coordinator minimal initial state", function() {
		// Check stable selection, identity, lifecycle, and deferred-field boundaries.
		_BladeRunCoordinatorTestInitialState();
	});
	BladeKernelTestRunCase(_state, "run coordinator deterministic selection", function() {
		// Compare equal inputs and independently varied deterministic inputs.
		_BladeRunCoordinatorTestRepeatability();
	});
	BladeKernelTestRunCase(_state, "run coordinator deterministic reset", function() {
		// Advance one clock/input/state tick before comparing reset with a fresh attempt.
		_BladeRunCoordinatorTestDeterministicReset();
	});
	BladeKernelTestRunCase(_state, "run coordinator failed reset is atomic", function() {
		// Reject invalid selection, mode, and seed inputs without replacing live state.
		_BladeRunCoordinatorTestInvalidResetIsAtomic();
	});
	BladeKernelTestRunCase(_state, "run coordinator callback hides kernel", function() {
		// Inspect the callback argument surface and mutate only its detached views.
		_BladeRunCoordinatorTestCallbackIsolation();
	});
	BladeKernelTestRunCase(_state, "run coordinator lifecycle transitions", function() {
		// Exercise completion, abort, invalid terminal commands, stepping, and reset.
		_BladeRunCoordinatorTestLifecycleTransitions();
	});
	BladeKernelTestRunCase(_state, "run coordinator practice and detached views", function() {
		// Prove practice isolation and snapshot ownership in one boundary case.
		_BladeRunCoordinatorTestPracticeAndDetachedViews();
	});
	return _state;
}
