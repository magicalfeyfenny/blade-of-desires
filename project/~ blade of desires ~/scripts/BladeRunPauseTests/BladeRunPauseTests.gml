/// @description Coordinator integration tests for composable deterministic pause ownership.

/// Creates the neutral raw input shared by pause integration cases.
function _BladeRunPauseTestsRawState() {
	return BladeInputRawStateCreate(0, 0, 0);
}

/// Counts live eligibility requests and always asks for every declared clock domain.
function _BladeRunPauseTestsAllEligibility(_counters) {
	self.calls += int64(1);
	self.last_simulation_tick = _counters.simulation_tick;
	return BladeClockDomain.All;
}

/// Acquires Stage pause ownership after the first completed tick of a direct batch.
function _BladeRunPauseTestsAcquireAfterFirstTick(_run_snapshot, _input_snapshot, _tick) {
	self.calls += int64(1);
	if (_tick.simulation_tick == int64(1)) {
		self.token = BladeRunCoordinatorAcquirePause(
			self.coordinator,
			self.owner_id,
			"pause.mid_batch",
			BladeClockDomain.Stage,
			BladePauseReleasePolicy.OwnerDestroyed
		);
	}
	return undefined;
}

/// Mutates every callback pause-view layer to prove none aliases coordinator ownership.
function _BladeRunPauseTestsMutateCallbackView(_run_snapshot, _input_snapshot, _tick) {
	self.calls += int64(1);
	_run_snapshot.pause.next_token_ordinal = int64(999);
	_run_snapshot.pause.frozen_domains = BladeClockDomain.None;
	_run_snapshot.pause.active_tokens[0].reason = "pause.mutated";
	array_push(_run_snapshot.pause.diagnostics, "mutated");
	return undefined;
}

/// Attempts terminal, reset, and nested presentation commands from one live eligibility call.
function _BladeRunPauseTestsReentrantEligibility(_counters) {
	self.calls += int64(1);
	if (self.calls != int64(1)) {
		return BladeClockDomain.All;
	}

	var _message = "not rejected";
	try {
		BladeRunCoordinatorComplete(self.coordinator);
	} catch (_caught) {
		_message = string(_caught);
	}
	array_push(self.guard_messages, _message);
	_message = "not rejected";
	try {
		BladeRunCoordinatorReset(
			self.coordinator,
			"ship.ciela",
			"difficulty.hard",
			BladeRunMode.Practice,
			77
		);
	} catch (_caught) {
		_message = string(_caught);
	}
	array_push(self.guard_messages, _message);
	_message = "not rejected";
	try {
		BladeRunCoordinatorAdvancePresentation(
			self.coordinator,
			16667,
			self.raw,
			BladeClockDomain.All
		);
	} catch (_caught) {
		_message = string(_caught);
	}
	array_push(self.guard_messages, _message);
	self.snapshot = BladeRunCoordinatorSnapshot(self.coordinator);
	self.diagnostics = BladeRunCoordinatorDiagnostics(self.coordinator);
	return BladeClockDomain.All;
}

/// Attempts abort and both nested direct commands, then acquires a legal pause inside the tick.
function _BladeRunPauseTestsReentrantCallback(_run_snapshot, _input_snapshot, _tick) {
	self.calls += int64(1);
	if (self.calls != int64(1)) {
		return undefined;
	}

	var _message = "not rejected";
	try {
		BladeRunCoordinatorAbort(self.coordinator);
	} catch (_caught) {
		_message = string(_caught);
	}
	array_push(self.guard_messages, _message);
	_message = "not rejected";
	try {
		BladeRunCoordinatorStepDirect(
			self.coordinator,
			self.raw,
			BladeClockDomain.All
		);
	} catch (_caught) {
		_message = string(_caught);
	}
	array_push(self.guard_messages, _message);
	_message = "not rejected";
	try {
		BladeRunCoordinatorStepManyDirect(
			self.coordinator,
			self.raw,
			2,
			BladeClockDomain.All
		);
	} catch (_caught) {
		_message = string(_caught);
	}
	array_push(self.guard_messages, _message);
	self.token = BladeRunCoordinatorAcquirePause(
		self.coordinator,
		self.owner_id,
		"pause.reentrant_allowed",
		BladeClockDomain.Stage,
		BladePauseReleasePolicy.OwnerDestroyed
	);
	self.pause_snapshot = BladeRunCoordinatorPauseSnapshot(self.coordinator);
	self.run_snapshot = BladeRunCoordinatorSnapshot(self.coordinator);
	return undefined;
}

/// Throws from eligibility so tests can prove StepMany clears its transient guard.
function _BladeRunPauseTestsThrowingEligibility(_counters) {
	throw("run pause intentional eligibility failure");
}

/// Throws from simulation so tests can prove StepDirect and presentation advance clear their guards.
function _BladeRunPauseTestsThrowingCallback(_run_snapshot, _input_snapshot, _tick) {
	throw("run pause intentional callback failure");
}

/// Adds the focused run-pause integration cases to the shared project-owned result state.
function BladeRunPauseTestsRun(_state) {
	BladeKernelTestRunCase(_state, "run pause numeric masks freeze gameplay while presentation advances", function() {
		// Reject unknown bits before sampling, then prove All cannot bypass frozen gameplay domains.
		var _coordinator = _BladeRunCoordinatorTestCreate();
		var _raw = _BladeRunPauseTestsRawState();
		var _initial = BladeRunCoordinatorCanonical(_coordinator);
		BladeKernelTestAssertThrows(method({
			coordinator: _coordinator,
			raw: _raw,
		}, function() {
			// Numeric eligibility is validated before the kernel can sample presentation input.
			BladeRunCoordinatorStepDirect(
				self.coordinator,
				self.raw,
				BladeClockDomain.All | 32
			);
		}), "requested domain mask", "invalid numeric eligibility");
		BladeKernelTestAssertEqual(
			BladeRunCoordinatorCanonical(_coordinator),
			_initial,
			"invalid numeric eligibility leaves coordinator state unchanged"
		);

		var _owner = BladeRunCoordinatorAllocatePauseOwner(_coordinator);
		var _before_pause = BladeRunCoordinatorCanonical(_coordinator);
		var _token = BladeRunCoordinatorAcquirePause(
			_coordinator,
			_owner,
			"pause.menu",
			BladeClockDomain.Stage
				| BladeClockDomain.Actor
				| BladeClockDomain.Combat,
			BladePauseReleasePolicy.OwnerDestroyed
		);
		BladeKernelTestAssertEqual(_token.token_id, "pau:1", "first coordinator pause ID");
		BladeKernelTestAssertEqual(
			_token.acquisition_tick,
			int64(0),
			"coordinator supplies initial acquisition tick"
		);
		BladeKernelTestAssertNotEqual(
			BladeRunCoordinatorCanonical(_coordinator),
			_before_pause,
			"active pause ownership participates in coordinator canonical state"
		);

		var _direct = BladeRunCoordinatorStepDirect(
			_coordinator,
			_raw,
			BladeClockDomain.All
		);
		BladeKernelTestAssertEqual(_direct.counters.simulation_tick, int64(1), "direct master tick");
		BladeKernelTestAssertEqual(_direct.counters.stage_tick, int64(0), "direct Stage frozen");
		BladeKernelTestAssertEqual(_direct.counters.actor_tick, int64(0), "direct Actor frozen");
		BladeKernelTestAssertEqual(_direct.counters.boss_tick, int64(1), "direct Boss advances");
		BladeKernelTestAssertEqual(_direct.counters.combat_tick, int64(0), "direct Combat frozen");
		BladeKernelTestAssertEqual(
			_direct.counters.presentation_tick,
			int64(1),
			"direct presentation advances"
		);

		var _advance = BladeRunCoordinatorAdvancePresentation(
			_coordinator,
			16667,
			_raw,
			BladeClockDomain.All
		);
		BladeKernelTestAssertEqual(_advance.counters.simulation_tick, int64(2), "advance master tick");
		BladeKernelTestAssertEqual(_advance.counters.stage_tick, int64(0), "advance Stage frozen");
		BladeKernelTestAssertEqual(_advance.counters.actor_tick, int64(0), "advance Actor frozen");
		BladeKernelTestAssertEqual(_advance.counters.boss_tick, int64(2), "advance Boss tick");
		BladeKernelTestAssertEqual(_advance.counters.combat_tick, int64(0), "advance Combat frozen");
		BladeKernelTestAssertEqual(
			_advance.counters.presentation_tick,
			int64(2),
			"outer presentation update remains unpausable"
		);

		BladeKernelTestAssertTrue(
			BladeRunCoordinatorReleasePause(_coordinator, _owner, _token.token_id).released,
			"coordinator releases owned pause"
		);
		var _resumed = BladeRunCoordinatorStepDirect(
			_coordinator,
			_raw,
			BladeClockDomain.All
		);
		BladeKernelTestAssertEqual(_resumed.counters.stage_tick, int64(1), "Stage resumes");
		BladeKernelTestAssertEqual(_resumed.counters.actor_tick, int64(1), "Actor resumes");
		BladeKernelTestAssertEqual(_resumed.counters.boss_tick, int64(3), "Boss continues");
		BladeKernelTestAssertEqual(_resumed.counters.combat_tick, int64(1), "Combat resumes");
		BladeKernelTestAssertEqual(
			BladeRunCoordinatorDiagnostics(_coordinator).pause.frozen_domains,
			BladeClockDomain.None,
			"diagnostics include cleared pause ownership"
		);
	});

	BladeKernelTestRunCase(_state, "run pause method providers are constrained every direct tick", function() {
		// Ask for All from a live method three times while Stage ownership remains authoritative.
		var _coordinator = _BladeRunCoordinatorTestCreate();
		var _owner = BladeRunCoordinatorAllocatePauseOwner(_coordinator);
		BladeRunCoordinatorAcquirePause(
			_coordinator,
			_owner,
			"pause.method_provider",
			BladeClockDomain.Stage,
			BladePauseReleasePolicy.OwnerDestroyed
		);
		var _provider_context = {
			calls: int64(0),
			last_simulation_tick: int64(-1),
		};
		var _provider = method(_provider_context, _BladeRunPauseTestsAllEligibility);
		var _result = BladeRunCoordinatorStepManyDirect(
			_coordinator,
			_BladeRunPauseTestsRawState(),
			3,
			_provider
		);
		BladeKernelTestAssertEqual(_provider_context.calls, int64(3), "one provider call per tick");
		BladeKernelTestAssertEqual(
			_provider_context.last_simulation_tick,
			int64(2),
			"provider observes the preceding completed tick"
		);
		BladeKernelTestAssertEqual(_result.ticks_run, int64(3), "three direct ticks run");
		BladeKernelTestAssertEqual(_result.counters.stage_tick, int64(0), "method cannot bypass Stage");
		BladeKernelTestAssertEqual(_result.counters.actor_tick, int64(3), "method permits Actor");
		BladeKernelTestAssertEqual(_result.counters.boss_tick, int64(3), "method permits Boss");
		BladeKernelTestAssertEqual(_result.counters.combat_tick, int64(3), "method permits Combat");
		BladeKernelTestAssertEqual(
			_result.counters.presentation_tick,
			int64(1),
			"direct batch advances presentation once"
		);
	});

	BladeKernelTestRunCase(_state, "run pause numeric masks re-read ownership within a batch", function() {
		// Acquire during tick one and require the same numeric base mask to freeze ticks two and three.
		var _coordinator = _BladeRunCoordinatorTestCreate();
		var _owner = BladeRunCoordinatorAllocatePauseOwner(_coordinator);
		var _callback_context = {
			coordinator: _coordinator,
			owner_id: _owner,
			calls: int64(0),
			token: undefined,
		};
		var _result = BladeRunCoordinatorStepManyDirect(
			_coordinator,
			_BladeRunPauseTestsRawState(),
			3,
			BladeClockDomain.All,
			method(_callback_context, _BladeRunPauseTestsAcquireAfterFirstTick)
		);
		BladeKernelTestAssertEqual(_callback_context.calls, int64(3), "three callbacks run");
		BladeKernelTestAssertEqual(
			_callback_context.token.acquisition_tick,
			int64(1),
			"mid-batch command uses the completed first tick"
		);
		BladeKernelTestAssertEqual(_result.counters.simulation_tick, int64(3), "master batch ticks");
		BladeKernelTestAssertEqual(
			_result.counters.stage_tick,
			int64(1),
			"tick one advances Stage before later ticks freeze"
		);
		BladeKernelTestAssertEqual(_result.counters.actor_tick, int64(3), "Actor remains eligible");
		BladeKernelTestAssertEqual(_result.counters.boss_tick, int64(3), "Boss remains eligible");
		BladeKernelTestAssertEqual(_result.counters.combat_tick, int64(3), "Combat remains eligible");
		BladeKernelTestAssertEqual(
			BladeRunCoordinatorPauseSnapshot(_coordinator).frozen_domains,
			BladeClockDomain.Stage,
			"mid-batch token remains owned"
		);
	});

	BladeKernelTestRunCase(_state, "run pause advancing guard rejects captured reentrancy", function() {
		// Catch every forbidden command while one legal pause command changes later batch ticks.
		var _coordinator = _BladeRunCoordinatorTestCreate();
		var _raw = _BladeRunPauseTestsRawState();
		var _owner = BladeRunCoordinatorAllocatePauseOwner(_coordinator);
		var _provider_context = {
			coordinator: _coordinator,
			raw: _raw,
			calls: int64(0),
			guard_messages: [],
			snapshot: undefined,
			diagnostics: undefined,
		};
		var _callback_context = {
			coordinator: _coordinator,
			raw: _raw,
			owner_id: _owner,
			calls: int64(0),
			guard_messages: [],
			token: undefined,
			pause_snapshot: undefined,
			run_snapshot: undefined,
		};
		var _result = BladeRunCoordinatorStepManyDirect(
			_coordinator,
			_raw,
			3,
			method(_provider_context, _BladeRunPauseTestsReentrantEligibility),
			method(_callback_context, _BladeRunPauseTestsReentrantCallback)
		);
		BladeKernelTestAssertEqual(_provider_context.calls, int64(3), "provider batch calls");
		BladeKernelTestAssertEqual(_callback_context.calls, int64(3), "callback batch calls");
		BladeKernelTestAssertEqual(
			array_length(_provider_context.guard_messages),
			3,
			"provider catches terminal reset and nested advance"
		);
		BladeKernelTestAssertEqual(
			array_length(_callback_context.guard_messages),
			3,
			"callback catches abort and nested direct advances"
		);
		var _guard_fragment = "cannot run while coordinator is advancing";
		for (var i = 0; i < array_length(_provider_context.guard_messages); ++i) {
			BladeKernelTestAssertTrue(
				string_pos(_guard_fragment, _provider_context.guard_messages[i]) > 0,
				"provider rejection " + string(i)
			);
		}
		for (var i = 0; i < array_length(_callback_context.guard_messages); ++i) {
			BladeKernelTestAssertTrue(
				string_pos(_guard_fragment, _callback_context.guard_messages[i]) > 0,
				"callback rejection " + string(i)
			);
		}
		BladeKernelTestAssertEqual(
			_provider_context.snapshot.lifecycle,
			BladeRunLifecycle.Active,
			"provider query sees unchanged active lifecycle"
		);
		BladeKernelTestAssertEqual(
			_provider_context.diagnostics.snapshot.ship_id,
			"ship.maynii",
			"provider diagnostics see unchanged selection"
		);
		BladeKernelTestAssertEqual(
			_callback_context.token.acquisition_tick,
			int64(1),
			"callback pause command remains legal"
		);
		BladeKernelTestAssertEqual(
			_callback_context.pause_snapshot.active_tokens[0].reason,
			"pause.reentrant_allowed",
			"callback pause query remains legal"
		);
		BladeKernelTestAssertEqual(
			_callback_context.run_snapshot.lifecycle,
			BladeRunLifecycle.Active,
			"callback run query remains legal"
		);
		BladeKernelTestAssertEqual(_result.counters.simulation_tick, int64(3), "coherent master batch");
		BladeKernelTestAssertEqual(_result.counters.stage_tick, int64(1), "later Stage ticks freeze");
		BladeKernelTestAssertEqual(_result.counters.actor_tick, int64(3), "Actor batch remains coherent");
		BladeKernelTestAssertEqual(_result.counters.boss_tick, int64(3), "Boss batch remains coherent");
		BladeKernelTestAssertEqual(_result.counters.combat_tick, int64(3), "Combat batch remains coherent");
		BladeKernelTestAssertEqual(
			BladeRunCoordinatorSnapshot(_coordinator).lifecycle,
			BladeRunLifecycle.Active,
			"rejected lifecycle commands cannot terminate the batch"
		);
		var _after = BladeRunCoordinatorStepDirect(
			_coordinator,
			_raw,
			BladeClockDomain.All
		);
		BladeKernelTestAssertEqual(_after.counters.simulation_tick, int64(4), "guard clears after success");
	});

	BladeKernelTestRunCase(_state, "run pause advancing guard clears after failures", function() {
		// Fail each public advance shape, then use another guarded command to prove finally cleanup.
		var _coordinator = _BladeRunCoordinatorTestCreate();
		var _raw = _BladeRunPauseTestsRawState();
		BladeKernelTestAssertThrows(method({
			coordinator: _coordinator,
			raw: _raw,
		}, function() {
			// Throw before the first StepMany tick from its live eligibility provider.
			BladeRunCoordinatorStepManyDirect(
				self.coordinator,
				self.raw,
				2,
				method({}, _BladeRunPauseTestsThrowingEligibility)
			);
		}), "intentional eligibility failure", "StepMany provider failure");
		var _after_provider = BladeRunCoordinatorStepDirect(
			_coordinator,
			_raw,
			BladeClockDomain.All
		);
		BladeKernelTestAssertEqual(
			_after_provider.counters.simulation_tick,
			int64(1),
			"StepMany failure clears guard for StepDirect"
		);

		BladeKernelTestAssertThrows(method({
			coordinator: _coordinator,
			raw: _raw,
		}, function() {
			// Throw after StepDirect advances its tick but before the event tick commits.
			BladeRunCoordinatorStepDirect(
				self.coordinator,
				self.raw,
				BladeClockDomain.All,
				method({}, _BladeRunPauseTestsThrowingCallback)
			);
		}), "intentional callback failure", "StepDirect callback failure");
		BladeRunCoordinatorReset(
			_coordinator,
			"ship.maynii",
			"difficulty.normal",
			BladeRunMode.Normal,
			305419896
		);
		BladeKernelTestAssertEqual(
			BladeRunCoordinatorSnapshot(_coordinator).started_tick,
			int64(0),
			"StepDirect failure clears guard for reset"
		);

		BladeKernelTestAssertThrows(method({
			coordinator: _coordinator,
			raw: _raw,
		}, function() {
			// Throw from a due presentation tick after its outer update begins.
			BladeRunCoordinatorAdvancePresentation(
				self.coordinator,
				16667,
				self.raw,
				BladeClockDomain.All,
				method({}, _BladeRunPauseTestsThrowingCallback)
			);
		}), "intentional callback failure", "presentation callback failure");
		BladeRunCoordinatorReset(
			_coordinator,
			"ship.maynii",
			"difficulty.normal",
			BladeRunMode.Normal,
			305419896
		);
		var _final = BladeRunCoordinatorStepDirect(
			_coordinator,
			_raw,
			BladeClockDomain.All
		);
		BladeKernelTestAssertEqual(
			_final.counters.simulation_tick,
			int64(1),
			"presentation failure clears guard for reset and advance"
		);
	});

	BladeKernelTestRunCase(_state, "run pause wrappers enforce owner and room lifetimes", function() {
		// Exercise every coordinator command seam while current-tick acquisition stays internal.
		var _coordinator = _BladeRunCoordinatorTestCreate();
		_BladeRunCoordinatorTestStep(_coordinator);
		var _owner_a = BladeRunCoordinatorAllocatePauseOwner(_coordinator);
		var _owner_b = BladeRunCoordinatorAllocatePauseOwner(_coordinator);
		var _owner_c = BladeRunCoordinatorAllocatePauseOwner(_coordinator);
		var _owner_token = BladeRunCoordinatorAcquirePause(
			_coordinator, _owner_a, "pause.owner", BladeClockDomain.Stage,
			BladePauseReleasePolicy.OwnerDestroyed
		);
		var _room_token = BladeRunCoordinatorAcquirePause(
			_coordinator, _owner_b, "pause.room", BladeClockDomain.Actor,
			BladePauseReleasePolicy.RoomExit
		);
		var _run_token = BladeRunCoordinatorAcquirePause(
			_coordinator, _owner_c, "pause.run", BladeClockDomain.Boss,
			BladePauseReleasePolicy.RunBoundary
		);
		BladeKernelTestAssertEqual(_owner_token.acquisition_tick, int64(1), "owner token tick");
		BladeKernelTestAssertEqual(_room_token.acquisition_tick, int64(1), "room token tick");
		BladeKernelTestAssertEqual(_run_token.acquisition_tick, int64(1), "run token tick");

		var _run_owner = BladeRunCoordinatorSnapshot(_coordinator).event_owner_id;
		var _transfer = BladeRunCoordinatorTransferPause(
			_coordinator,
			_owner_c,
			_run_token.token_id,
			_run_owner,
			BladePauseReleasePolicy.RunBoundary
		);
		BladeKernelTestAssertTrue(_transfer.transferred, "transfer to run owner succeeds");
		BladeKernelTestAssertEqual(_transfer.token.owner_id, "own:1", "persistent run owner");

		var _destroyed = BladeRunCoordinatorPauseOwnerDestroyed(_coordinator, _owner_a);
		BladeKernelTestAssertEqual(_destroyed.boundary, "owner.destroyed", "owner boundary");
		BladeKernelTestAssertEqual(array_length(_destroyed.released_tokens), 1, "owner token released");
		BladeKernelTestAssertEqual(array_length(_destroyed.diagnostics), 0, "declared owner cleanup");
		var _room = BladeRunCoordinatorPauseRoomExit(_coordinator);
		BladeKernelTestAssertEqual(_room.boundary, "room.exit", "room boundary");
		BladeKernelTestAssertEqual(_room.released_tokens[0].token_id, _room_token.token_id, "room token released");
		BladeKernelTestAssertEqual(_room.retained_tokens[0].token_id, _run_token.token_id, "run token retained");
		BladeKernelTestAssertEqual(array_length(_room.diagnostics), 0, "declared room cleanup");
		BladeKernelTestAssertTrue(
			BladeRunCoordinatorReleasePause(_coordinator, _run_owner, _run_token.token_id).released,
			"run owner can explicitly release retained token"
		);
		BladeKernelTestAssertEqual(
			array_length(BladeRunCoordinatorPauseSnapshot(_coordinator).active_tokens),
			0,
			"all wrapper-managed tokens are released"
		);
	});

	BladeKernelTestRunCase(_state, "run pause terminal boundaries clean complete and abort", function() {
		// Compare declared completion cleanup with an explicit-token abort leak at live ticks.
		var _completed = _BladeRunCoordinatorTestCreate();
		var _complete_owner = BladeRunCoordinatorAllocatePauseOwner(_completed);
		var _complete_token = BladeRunCoordinatorAcquirePause(
			_completed, _complete_owner, "pause.complete", BladeClockDomain.Stage,
			BladePauseReleasePolicy.RunBoundary
		);
		var _complete = BladeRunCoordinatorComplete(_completed);
		BladeKernelTestAssertEqual(
			_complete.pause_boundary_report.boundary,
			"run.completed",
			"completion boundary"
		);
		BladeKernelTestAssertEqual(
			_complete.pause_boundary_report.released_tokens[0].token_id,
			_complete_token.token_id,
			"completion releases run token"
		);
		BladeKernelTestAssertEqual(
			array_length(_complete.pause_boundary_report.diagnostics),
			0,
			"declared completion cleanup has no leak"
		);
		BladeKernelTestAssertEqual(array_length(_complete.pause.active_tokens), 0, "complete pause view cleared");

		var _aborted = _BladeRunCoordinatorTestCreate();
		_BladeRunCoordinatorTestStep(_aborted);
		var _abort_owner = BladeRunCoordinatorAllocatePauseOwner(_aborted);
		var _abort_token = BladeRunCoordinatorAcquirePause(
			_aborted, _abort_owner, "pause.abort", BladeClockDomain.Actor,
			BladePauseReleasePolicy.Explicit
		);
		var _abort = BladeRunCoordinatorAbort(_aborted);
		BladeKernelTestAssertEqual(_abort.pause_boundary_report.boundary, "run.aborted", "abort boundary");
		BladeKernelTestAssertEqual(
			_abort.pause_boundary_report.released_tokens[0].token_id,
			_abort_token.token_id,
			"abort releases explicit token"
		);
		BladeKernelTestAssertEqual(
			_abort.pause_boundary_report.diagnostics[0].code,
			"pause.leaked_token",
			"abort reports explicit leak"
		);
		BladeKernelTestAssertEqual(
			_abort.pause_boundary_report.diagnostics[0].observed_tick,
			int64(1),
			"abort cleanup uses current simulation tick"
		);
		BladeKernelTestAssertEqual(
			array_length(BladeRunCoordinatorPauseSnapshot(_aborted).active_tokens),
			0,
			"abort registry is cleared"
		);
	});

	BladeKernelTestRunCase(_state, "run pause reset is atomic and restarts token IDs", function() {
		// Preserve an active token across failed planning, then expose cleanup while swapping fresh state.
		var _coordinator = _BladeRunCoordinatorTestCreate();
		_BladeRunCoordinatorTestStep(_coordinator);
		var _owner = BladeRunCoordinatorAllocatePauseOwner(_coordinator);
		var _old_token = BladeRunCoordinatorAcquirePause(
			_coordinator, _owner, "pause.reset", BladeClockDomain.Stage,
			BladePauseReleasePolicy.Explicit
		);
		var _before_failure = BladeRunCoordinatorCanonical(_coordinator);
		BladeKernelTestAssertThrows(method({ coordinator: _coordinator }, function() {
			// Invalid replacement planning must not clean or swap the live pause registry.
			BladeRunCoordinatorReset(
				self.coordinator,
				"ship.maynii",
				"difficulty.unknown",
				BladeRunMode.Normal,
				305419896
			);
		}), "unknown content ID difficulty.unknown", "invalid reset with active pause");
		BladeKernelTestAssertEqual(
			BladeRunCoordinatorCanonical(_coordinator),
			_before_failure,
			"failed reset preserves pause and run state"
		);

		var _reset = BladeRunCoordinatorReset(
			_coordinator,
			"ship.maynii",
			"difficulty.normal",
			BladeRunMode.Normal,
			305419896
		);
		BladeKernelTestAssertEqual(
			_reset.prior_pause_boundary_report.boundary,
			"run.reset",
			"old reset boundary is observable"
		);
		BladeKernelTestAssertEqual(
			_reset.prior_pause_boundary_report.released_tokens[0].token_id,
			_old_token.token_id,
			"reset report identifies old token"
		);
		BladeKernelTestAssertEqual(
			_reset.prior_pause_boundary_report.diagnostics[0].observed_tick,
			int64(1),
			"reset cleanup uses old current tick"
		);
		BladeKernelTestAssertEqual(_reset.pause.next_token_ordinal, int64(1), "fresh token frontier");
		BladeKernelTestAssertEqual(_reset.pause.next_diagnostic_ordinal, int64(1), "fresh diagnostic frontier");
		BladeKernelTestAssertEqual(array_length(_reset.pause.active_tokens), 0, "fresh registry empty");

		var _new_owner = BladeRunCoordinatorAllocatePauseOwner(_coordinator);
		var _new_token = BladeRunCoordinatorAcquirePause(
			_coordinator, _new_owner, "pause.reset", BladeClockDomain.Stage,
			BladePauseReleasePolicy.OwnerDestroyed
		);
		BladeKernelTestAssertEqual(_new_owner, "own:2", "fresh owner allocation restarts");
		BladeKernelTestAssertEqual(_new_token.token_id, "pau:1", "fresh pause allocation restarts");

		var _fresh = _BladeRunCoordinatorTestCreate();
		var _fresh_owner = BladeRunCoordinatorAllocatePauseOwner(_fresh);
		BladeRunCoordinatorAcquirePause(
			_fresh, _fresh_owner, "pause.reset", BladeClockDomain.Stage,
			BladePauseReleasePolicy.OwnerDestroyed
		);
		BladeKernelTestAssertEqual(
			BladeRunCoordinatorCanonical(_coordinator),
			BladeRunCoordinatorCanonical(_fresh),
			"reset result matches equivalent fresh coordinator state"
		);
	});

	BladeKernelTestRunCase(_state, "run pause public and callback views remain detached", function() {
		// Mutate pause-only, whole-run, diagnostics, and callback snapshots without reaching ownership.
		var _coordinator = _BladeRunCoordinatorTestCreate();
		var _owner = BladeRunCoordinatorAllocatePauseOwner(_coordinator);
		BladeRunCoordinatorAcquirePause(
			_coordinator, _owner, "pause.detached", BladeClockDomain.Stage,
			BladePauseReleasePolicy.OwnerDestroyed
		);
		var _canonical = BladeRunCoordinatorCanonical(_coordinator);
		var _pause = BladeRunCoordinatorPauseSnapshot(_coordinator);
		var _run = BladeRunCoordinatorSnapshot(_coordinator);
		var _diagnostics = BladeRunCoordinatorDiagnostics(_coordinator);
		_pause.next_token_ordinal = int64(999);
		_pause.active_tokens[0].reason = "pause.mutated";
		_run.pause.active_tokens[0].owner_id = "own:999";
		_diagnostics.pause.active_tokens[0].domains = BladeClockDomain.None;
		_diagnostics.snapshot.pause.diagnostics = ["mutated"];
		BladeKernelTestAssertEqual(
			BladeRunCoordinatorCanonical(_coordinator),
			_canonical,
			"mutated public pause views cannot alter canonical ownership"
		);

		var _callback_context = { calls: int64(0) };
		BladeRunCoordinatorStepDirect(
			_coordinator,
			_BladeRunPauseTestsRawState(),
			BladeClockDomain.All,
			method(_callback_context, _BladeRunPauseTestsMutateCallbackView)
		);
		var _fresh = BladeRunCoordinatorPauseSnapshot(_coordinator);
		BladeKernelTestAssertEqual(_callback_context.calls, int64(1), "callback receives one view");
		BladeKernelTestAssertEqual(_fresh.next_token_ordinal, int64(2), "owned token frontier unchanged");
		BladeKernelTestAssertEqual(_fresh.frozen_domains, BladeClockDomain.Stage, "owned mask unchanged");
		BladeKernelTestAssertEqual(_fresh.active_tokens[0].reason, "pause.detached", "owned token unchanged");
		BladeKernelTestAssertEqual(array_length(_fresh.diagnostics), 0, "owned diagnostics unchanged");
	});

	return _state;
}
