/// @description Standalone deterministic executor, encounter, event, and port tests.

/// Advances the neutral fixture through its initial wait and spawn node.
function _BladeStageRuntimeTestsReachSpawn(_fixture) {
	_BladeStageTestsStep(_fixture, BladeClockDomain.All);
	_BladeStageTestsStep(_fixture, BladeClockDomain.All);
	_BladeStageTestsStep(_fixture, BladeClockDomain.All);
	return BladeStageExecutorSnapshot(_fixture.executor);
}

/// Returns a complete tick view over the fixture's current clock counters.
function _BladeStageRuntimeTestsBoundaryTick(_fixture) {
	var _counters = BladeSimulationClockGetCounters(_fixture.kernel.clock);
	return {
		simulation_tick: _counters.simulation_tick,
		stage_tick: _counters.stage_tick,
		actor_tick: _counters.actor_tick,
		boss_tick: _counters.boss_tick,
		combat_tick: _counters.combat_tick,
		presentation_tick: _counters.presentation_tick,
		domain_mask: BladeClockDomain.None,
	};
}

/// Completes one neutral run under reversible raw and delivery ordering variants.
function _BladeStageRuntimeTestsScenario(
	_reordered_raw, _reverse_terminals, _reverse_invalid_signals
) {
	var _raw = _BladeStageTestsRawCatalog();
	if (_reordered_raw) _raw = _BladeStageTestsReorderedRaw(_raw);
	var _fixture = _BladeStageTestsFixture(_raw);
	_BladeStageRuntimeTestsReachSpawn(_fixture);
	var _generation = BladeStageEncounterRegistryLatest(
		_fixture.executor.encounters,
		"encounter_schedule.neutral_stage.targets"
	);
	var _terminals = [
		_BladeStageTestsTerminal(
			_generation.participants[0].instance_id,
			BladeCombatTerminalReason.Defeat
		),
		_BladeStageTestsTerminal(
			_generation.participants[1].instance_id,
			BladeCombatTerminalReason.Defeat
		),
	];
	if (_reverse_terminals) _terminals = _BladeStageTestsReverse(_terminals);
	_BladeStageTestsStep(_fixture, BladeClockDomain.All, _terminals);
	var _request = _fixture.executor.ports.task_requests[0];
	if (_reverse_invalid_signals) {
		BladeStageExecutorSubmitTaskCompletion(
			_fixture.executor, _request.port_id, _request.type_id,
			_request.completion_signal_id,
			"signal_type.neutral_stage.external",
			_request.execution_generation
		);
		BladeStageExecutorSubmitTaskCompletion(
			_fixture.executor, _request.port_id, _request.type_id,
			_request.completion_signal_id,
			_request.completion_signal_type_id,
			_request.execution_generation + 99
		);
	} else {
		BladeStageExecutorSubmitTaskCompletion(
			_fixture.executor, _request.port_id, _request.type_id,
			_request.completion_signal_id,
			_request.completion_signal_type_id,
			_request.execution_generation + 99
		);
		BladeStageExecutorSubmitTaskCompletion(
			_fixture.executor, _request.port_id, _request.type_id,
			_request.completion_signal_id,
			"signal_type.neutral_stage.external",
			_request.execution_generation
		);
	}
	BladeStageExecutorSubmitTaskCompletion(
		_fixture.executor, _request.port_id, _request.type_id,
		_request.completion_signal_id,
		_request.completion_signal_type_id,
		_request.execution_generation
	);
	_BladeStageTestsStep(_fixture, BladeClockDomain.All);
	var _wait_generation = _fixture.executor.current_generation;
	BladeStageExecutorSubmitExternalSignal(
		_fixture.executor, "signal.neutral_stage.release",
		"signal_type.neutral_stage.external", _wait_generation
	);
	_BladeStageTestsStep(_fixture, BladeClockDomain.All);
	return {
		events: BladeStageEventStreamCanonical(_fixture.executor.events),
		stage_hash: BladeStageExecutorHash(_fixture.executor),
		kernel_hash: BladeKernelGameplayHash(_fixture.kernel),
	};
}

/// Registers combat and playable binding, timing, ownership, abort, and determinism cases.
function BladeStageRuntimeTestsRun(_state) {
	BladeKernelTestRunCase(_state, "runtime binding preflights all participant specs atomically", function() {
		var _fixture = _BladeStageTestsFixture(undefined, 2, false, false);
		var _before = BladeStageExecutorCanonical(_fixture.executor);
		var _kernel_before = BladeKernelGameplayCanonical(_fixture.kernel);
		var _counters = BladeRunIdentityGetCounters(_fixture.kernel.identity);
		BladeKernelTestAssertEqual(
			_fixture.resolver_state.calls, 0,
			"content-only constructor does not invoke runtime resolver"
		);
		var _context = { fixture: _fixture };
		BladeKernelTestAssertThrows(method(_context, function() {
			BladeStageExecutorBindRuntime(
				self.fixture.executor, self.fixture.kernel, self.fixture.runtime
			);
		}), "fixture resolver rejected", "invalid second participant rejects binding");
		var _after_counters = BladeRunIdentityGetCounters(_fixture.kernel.identity);
		BladeKernelTestAssertEqual(
			BladeStageExecutorCanonical(_fixture.executor), _before,
			"failed binding changes no executor state or outbox"
		);
		BladeKernelTestAssertEqual(
			BladeKernelGameplayCanonical(_fixture.kernel), _kernel_before,
			"failed binding consumes no kernel identity, RNG, or event state"
		);
		BladeKernelTestAssertEqual(
			_after_counters.instance, _counters.instance,
			"failed binding allocates no instance ID"
		);
		BladeKernelTestAssertEqual(
			_after_counters.event, _counters.event,
			"failed binding allocates no event ID"
		);
		BladeKernelTestAssertEqual(
			array_length(_fixture.runtime.actors), 0,
			"failed binding registers no actor"
		);

		var _valid = _BladeStageTestsFixture(undefined, 0, false, false);
		BladeStageExecutorBindRuntime(
			_valid.executor, _valid.kernel, _valid.runtime
		);
		var _valid_counters = BladeRunIdentityGetCounters(_valid.kernel.identity);
		BladeKernelTestAssertEqual(
			_valid.resolver_state.calls, 2,
			"binding resolves every participant exactly once"
		);
		BladeKernelTestAssertTrue(
			_valid.executor.runtime_bound,
			"successful whole-stage binding enables advance"
		);
		BladeKernelTestAssertEqual(
			_valid_counters.instance, int64(0),
			"successful binding still allocates no participant IDs"
		);
		BladeKernelTestAssertEqual(
			_valid_counters.event, int64(0),
			"successful binding still allocates no event IDs"
		);
	});

	BladeKernelTestRunCase(_state, "playable binding preflights content without creating objects", function() {
		var _fixture = _BladeStageTestsPlayableFixture(undefined, 2, false);
		var _before = BladeStageExecutorCanonical(_fixture.executor);
		var _kernel_before = BladeKernelGameplayCanonical(_fixture.kernel);
		var _counters = BladeRunIdentityGetCounters(_fixture.kernel.identity);
		var _context = { fixture: _fixture };
		BladeKernelTestAssertThrows(method(_context, function() {
			BladeStageExecutorBindPlayable(
				self.fixture.executor, self.fixture.kernel,
				self.fixture.spawn_callback
			);
		}), "fixture playable resolver rejected",
		"invalid second playable participant rejects binding");
		var _after_counters = BladeRunIdentityGetCounters(_fixture.kernel.identity);
		BladeKernelTestAssertEqual(
			BladeStageExecutorCanonical(_fixture.executor), _before,
			"failed playable binding changes no schedule ownership"
		);
		BladeKernelTestAssertEqual(
			BladeKernelGameplayCanonical(_fixture.kernel), _kernel_before,
			"failed playable binding changes no deterministic kernel state"
		);
		BladeKernelTestAssertEqual(
			_after_counters.instance, _counters.instance,
			"failed playable binding allocates no participant ID"
		);
		BladeKernelTestAssertEqual(
			array_length(_fixture.spawn_state.records), 0,
			"failed playable binding creates no gameplay object"
		);

		var _valid = _BladeStageTestsPlayableFixture(undefined, 0, false);
		BladeStageExecutorBindPlayable(
			_valid.executor, _valid.kernel, _valid.spawn_callback
		);
		var _valid_counters = BladeRunIdentityGetCounters(_valid.kernel.identity);
		BladeKernelTestAssertEqual(
			_valid.resolver_state.calls, 2,
			"playable binding resolves every participant exactly once"
		);
		BladeKernelTestAssertEqual(
			array_length(_valid.spawn_state.records), 0,
			"successful preflight still creates no object"
		);
		BladeKernelTestAssertEqual(
			_valid_counters.instance, int64(0),
			"successful playable preflight still allocates no participant ID"
		);
	});

	BladeKernelTestRunCase(_state, "playable objects receive stable spawns and open only owned defeat gates", function() {
		var _fixture = _BladeStageTestsPlayableFixture();
		_BladeStageTestsPlayableStep(_fixture, BladeClockDomain.All);
		_BladeStageTestsPlayableStep(_fixture, BladeClockDomain.All);
		_BladeStageTestsPlayableStep(_fixture, BladeClockDomain.All);
		BladeKernelTestAssertFalse(
			variable_struct_exists(_fixture, "runtime"),
			"playable stage fixture constructs no duplicate combat runtime"
		);
		BladeKernelTestAssertEqual(
			array_length(_fixture.spawn_state.records), 2,
			"spawn node creates the complete playable participant batch"
		);
		var _first_spawn = _fixture.spawn_state.records[0];
		var _second_spawn = _fixture.spawn_state.records[1];
		BladeKernelTestAssertArrayEqual(
			[_first_spawn.instance_id, _second_spawn.instance_id],
			["ins:1", "ins:2"],
			"playable participants keep deterministic spawn-order IDs"
		);
		BladeKernelTestAssertArrayEqual(
			[_first_spawn.x_q10, _first_spawn.y_q10],
			[int64(326656), int64(62464)],
			"playable callback receives exact plane-bound coordinates"
		);
		BladeKernelTestAssertEqual(
			_first_spawn.encounter_id,
			"encounter_schedule.neutral_stage.targets",
			"playable callback identifies its owning encounter"
		);
		BladeKernelTestAssertEqual(
			_first_spawn.execution_generation, int64(3),
			"playable callback receives the validated spawn generation"
		);
		var _generation = BladeStageEncounterRegistryLatest(
			_fixture.executor.encounters,
			"encounter_schedule.neutral_stage.targets"
		);
		BladeKernelTestAssertArrayEqual(
			[_generation.participants[0].instance_id,
				_generation.participants[1].instance_id],
			["ins:1", "ins:2"],
			"registry and gameplay objects share one participant identity"
		);

		_BladeStageTestsPlayableStep(
			_fixture, BladeClockDomain.All,
			["ins:999", _first_spawn.instance_id, _first_spawn.instance_id]
		);
		BladeKernelTestAssertArrayEqual(
			[_fixture.defeat_results[0].accepted,
				_fixture.defeat_results[1].accepted,
				_fixture.defeat_results[2].accepted],
			[false, true, false],
			"unowned and duplicate defeats cannot change encounter ownership"
		);
		BladeKernelTestAssertEqual(
			_fixture.executor.current_node_id,
			"stage_node.neutral_stage.wait_targets",
			"one of two real defeats keeps the all-defeated gate closed"
		);
		_BladeStageTestsPlayableStep(
			_fixture, BladeClockDomain.All, [_second_spawn.instance_id]
		);
		BladeKernelTestAssertTrue(
			_fixture.defeat_results[0].accepted,
			"final owned real defeat is accepted once"
		);
		BladeKernelTestAssertEqual(
			_generation.participants[1].state,
			BladeStageParticipantState.RetainedHarmless,
			"authored retained disposition survives direct object defeat"
		);
		BladeKernelTestAssertEqual(
			_fixture.executor.current_node_id,
			"stage_node.neutral_stage.wait_probe",
			"final defeat advances through completion into the next real route gate"
		);
		BladeKernelTestAssertEqual(
			array_length(_fixture.executor.ports.signal_records), 2,
			"playable encounter emits started and completed exactly once"
		);
	});

	BladeKernelTestRunCase(_state, "playable abort cleans only active objects and restart drops the callback", function() {
		var _fixture = _BladeStageTestsPlayableFixture();
		_BladeStageTestsPlayableStep(_fixture, BladeClockDomain.All);
		_BladeStageTestsPlayableStep(_fixture, BladeClockDomain.All);
		_BladeStageTestsPlayableStep(_fixture, BladeClockDomain.All);
		var _generation = BladeStageEncounterRegistryLatest(
			_fixture.executor.encounters,
			"encounter_schedule.neutral_stage.targets"
		);
		_BladeStageTestsPlayableStep(
			_fixture, BladeClockDomain.Combat,
			[_generation.participants[1].instance_id]
		);
		BladeStageExecutorAbortPlayable(
			_fixture.executor, BladeCombatTerminalReason.RunLoad,
			_BladeStageRuntimeTestsBoundaryTick(_fixture)
		);
		BladeKernelTestAssertEqual(
			_generation.participants[1].state,
			BladeStageParticipantState.RetainedHarmless,
			"reported playable defeat retains its exact terminal provenance"
		);
		BladeKernelTestAssertEqual(
			_generation.participants[0].state,
			BladeStageParticipantState.Cleaned,
			"abort cleans only the still-active playable participant"
		);
		BladeKernelTestAssertEqual(
			_generation.lifecycle, BladeStageLifecycle.Aborted,
			"abort cannot convert one reported defeat into completion"
		);
		BladeKernelTestAssertEqual(
			array_length(_fixture.executor.ports.signal_records), 1,
			"playable abort emits no completed signal"
		);
		var _restart = BladeStageExecutorRestart(_fixture.executor);
		BladeKernelTestAssertFalse(
			_restart.runtime_bound,
			"playable restart returns fresh unbound stage ownership"
		);
		BladeKernelTestAssertEqual(
			_restart.runtime_kind, "unbound",
			"playable restart carries no former runtime kind"
		);
		BladeKernelTestAssertTrue(
			is_undefined(_restart.playable_spawn_callback),
			"playable restart carries no former object callback"
		);
	});

	BladeKernelTestRunCase(_state, "combat and playable hosts cannot impersonate each other", function() {
		var _combat = _BladeStageTestsFixture();
		var _combat_context = { fixture: _combat };
		BladeKernelTestAssertThrows(method(_combat_context, function() {
			BladeStageExecutorBindPlayable(
				self.fixture.executor, self.fixture.kernel,
				method({ records: [] }, _BladeStageTestsPlayableSpawn)
			);
		}), "cannot change", "combat-bound stage rejects a playable rebind");

		var _playable = _BladeStageTestsPlayableFixture();
		var _event_owner_id = BladeKernelAllocate(
			_playable.kernel, BladeRunIdKind.EventOwner
		);
		var _runtime = BladeCombatRuntimeCreate(
			_playable.kernel.identity, _event_owner_id, _playable.plane
		);
		var _playable_context = { fixture: _playable, runtime: _runtime };
		BladeKernelTestAssertThrows(method(_playable_context, function() {
			BladeStageExecutorBindRuntime(
				self.fixture.executor, self.fixture.kernel, self.runtime
			);
		}), "cannot change", "playable-bound stage rejects a combat rebind");
		BladeKernelTestAssertThrows(method(_playable_context, function() {
			BladeStageExecutorAbort(
				self.fixture.executor, self.runtime,
				BladeCombatTerminalReason.RunLoad,
				_BladeStageRuntimeTestsBoundaryTick(self.fixture)
			);
		}), "bound combat runtime",
		"playable-bound stage rejects combat-runtime abort");
	});

	BladeKernelTestRunCase(_state, "eligible Stage ticks own wait timing and stable command events", function() {
		var _fixture = _BladeStageTestsFixture();
		_BladeStageTestsStep(_fixture, BladeClockDomain.All);
		var _entered = BladeStageExecutorSnapshot(_fixture.executor);
		BladeKernelTestAssertEqual(
			_entered.current_node_id, "stage_node.neutral_stage.wait_two_ticks",
			"ready cue chains to the first blocker"
		);
		BladeKernelTestAssertEqual(
			_entered.wait_until_stage_tick, int64(3),
			"two active ticks end at stage tick three"
		);
		var _paused_canonical = BladeStageExecutorCanonical(_fixture.executor);
		_BladeStageTestsStep(_fixture, BladeClockDomain.Combat);
		_BladeStageTestsStep(_fixture, BladeClockDomain.Combat);
		BladeKernelTestAssertEqual(
			BladeStageExecutorCanonical(_fixture.executor), _paused_canonical,
			"nested Stage pause consumes no executor state"
		);
		_BladeStageTestsStep(_fixture, BladeClockDomain.All);
		BladeKernelTestAssertEqual(
			_fixture.executor.current_node_id,
			"stage_node.neutral_stage.wait_two_ticks",
			"first resumed eligible tick remains blocked"
		);
		_BladeStageTestsStep(_fixture, BladeClockDomain.All, [], true);
		var _generation = BladeStageEncounterRegistryLatest(
			_fixture.executor.encounters,
			"encounter_schedule.neutral_stage.targets"
		);
		BladeKernelTestAssertEqual(
			array_length(_generation.participants), 2,
			"spawn commits the full prevalidated batch"
		);
		BladeKernelTestAssertEqual(
			_generation.participants[0].instance_id, "ins:1",
			"first spawn-order participant receives first contiguous ID"
		);
		BladeKernelTestAssertEqual(
			_generation.participants[1].instance_id, "ins:2",
			"second spawn-order participant receives next contiguous ID"
		);
		BladeKernelTestAssertEqual(
			_generation.participants[0].x_q10, int64(326656),
			"named anchor and local offsets resolve exact q10 x"
		);
		BladeKernelTestAssertEqual(
			_generation.participants[0].y_q10, int64(62464),
			"named anchor and local offsets resolve exact q10 y"
		);
		var _events = BladeStageEventStreamSnapshot(_fixture.executor.events);
		BladeKernelTestAssertArrayEqual(
			[_events[0].content_order, _events[1].content_order, _events[2].content_order],
			[int64(0), int64(1), int64(2)],
			"same-tick and cross-tick commands commit in content order"
		);
		BladeKernelTestAssertArrayEqual(
			[_events[0].event_id, _events[1].event_id, _events[2].event_id],
			["evt:1", "evt:2", "evt:3"],
			"stage events consume stable run-local event IDs"
		);
		BladeKernelTestAssertTrue(
			string_pos("evt:4", BladeEventLogGameplayCanonical(
				_fixture.kernel.event_log
			)) > 0,
			"ordinary queued gameplay event follows unique stage event IDs"
		);
		var _event_read = BladeStageEventStreamRead(_fixture.executor.events, 0);
		BladeKernelTestAssertEqual(
			array_length(_event_read.records), 3,
			"event consumer reads each new occurrence once"
		);
		BladeKernelTestAssertEqual(
			array_length(BladeStageEventStreamRead(
				_fixture.executor.events, _event_read.next_cursor
			).records), 0,
			"resumed event cursor redispatches nothing"
		);
	});

	BladeKernelTestRunCase(_state, "owned defeats alone open gates and typed ports complete explicitly", function() {
		var _fixture = _BladeStageTestsFixture();
		_BladeStageRuntimeTestsReachSpawn(_fixture);
		var _unrelated = BladeCombatRuntimeSpawnActor(
			_fixture.runtime, "ally.fixture", BladeCombatFaction.Player, 1,
			BladeCombatAabbCreate(300000, 50000, 301024, 51024),
			0, false, undefined,
			_fixture.kernel.clock.simulation_tick,
			_fixture.kernel.clock.combat_tick
		);
		_BladeStageTestsStep(_fixture, BladeClockDomain.All, [
			_BladeStageTestsTerminal(
				_unrelated.instance_id, BladeCombatTerminalReason.Defeat
			),
		]);
		BladeKernelTestAssertEqual(
			_fixture.executor.current_node_id,
			"stage_node.neutral_stage.wait_targets",
			"unrelated actor cannot open the owned encounter gate"
		);
		var _generation = BladeStageEncounterRegistryLatest(
			_fixture.executor.encounters,
			"encounter_schedule.neutral_stage.targets"
		);
		_BladeStageTestsStep(_fixture, BladeClockDomain.All, [
			_BladeStageTestsTerminal(
				_generation.participants[0].instance_id,
				BladeCombatTerminalReason.Defeat
			),
		]);
		BladeKernelTestAssertEqual(
			_fixture.executor.current_node_id,
			"stage_node.neutral_stage.wait_targets",
			"one of two owned defeats keeps the exact all-defeated gate closed"
		);
		_BladeStageTestsStep(_fixture, BladeClockDomain.All, [
			_BladeStageTestsTerminal(
				_generation.participants[1].instance_id,
				BladeCombatTerminalReason.Defeat
			),
			_BladeStageTestsTerminal(
				_generation.participants[1].instance_id,
				BladeCombatTerminalReason.Defeat
			),
		]);
		BladeKernelTestAssertEqual(
			_fixture.executor.current_node_id,
			"stage_node.neutral_stage.wait_probe",
			"final owned defeat chains to task request and typed wait"
		);
		BladeKernelTestAssertEqual(
			_generation.participants[1].state,
			BladeStageParticipantState.RetainedHarmless,
			"retained defeat becomes an inert terminal registry record"
		);
		BladeKernelTestAssertEqual(
			array_length(_fixture.runtime.reward_requests), 2,
			"duplicate defeat request cannot reward the retained participant twice"
		);
		var _request = _fixture.executor.ports.task_requests[0];
		var _signal_count = array_length(_fixture.executor.ports.signal_records);
		BladeKernelTestAssertFalse(BladeStageExecutorSubmitTaskCompletion(
			_fixture.executor, _request.port_id, _request.type_id,
			_request.completion_signal_id,
			_request.completion_signal_type_id,
			_request.execution_generation + 1
		).accepted, "stale task generation is a no-op");
		BladeKernelTestAssertEqual(
			array_length(_fixture.executor.ports.signal_records), _signal_count,
			"stale completion appends no signal"
		);
		BladeKernelTestAssertTrue(BladeStageExecutorSubmitTaskCompletion(
			_fixture.executor, _request.port_id, _request.type_id,
			_request.completion_signal_id,
			_request.completion_signal_type_id,
			_request.execution_generation
		).accepted, "exact typed task completion is accepted");
		BladeKernelTestAssertFalse(BladeStageExecutorSubmitTaskCompletion(
			_fixture.executor, _request.port_id, _request.type_id,
			_request.completion_signal_id,
			_request.completion_signal_type_id,
			_request.execution_generation
		).accepted, "duplicate task completion is a no-op");
		_BladeStageTestsStep(_fixture, BladeClockDomain.All);
		var _wait_generation = _fixture.executor.current_generation;
		BladeKernelTestAssertFalse(BladeStageExecutorSubmitExternalSignal(
			_fixture.executor, "signal.neutral_stage.release",
			"signal_type.neutral_stage.external", _wait_generation - 1
		).accepted, "stale external generation is a no-op");
		BladeKernelTestAssertTrue(BladeStageExecutorSubmitExternalSignal(
			_fixture.executor, "signal.neutral_stage.release",
			"signal_type.neutral_stage.external", _wait_generation
		).accepted, "exact external signal generation is accepted");
		BladeKernelTestAssertFalse(BladeStageExecutorSubmitExternalSignal(
			_fixture.executor, "signal.neutral_stage.release",
			"signal_type.neutral_stage.external", _wait_generation
		).accepted, "duplicate external signal is a no-op");
		_BladeStageTestsStep(_fixture, BladeClockDomain.All);
		var _final = BladeStageExecutorSnapshot(_fixture.executor);
		BladeKernelTestAssertEqual(
			_final.lifecycle, BladeStageLifecycle.Completed,
			"only explicit complete node ends the stage"
		);
		var _orders = [];
		for (var _index = 0; _index < array_length(_final.events); ++_index) {
			array_push(_orders, _final.events[_index].content_order);
		}
		BladeKernelTestAssertArrayEqual(
			_orders, [0, 1, 2, 3, 4, 5, 6, 7],
			"every linear node commits one event exactly once"
		);
		var _task_read = BladeStagePortsReadTaskRequests(
			_fixture.executor.ports, 0
		);
		BladeKernelTestAssertEqual(
			array_length(_task_read.records), 1,
			"task occurrence is available once from cursor zero"
		);
		BladeKernelTestAssertEqual(
			array_length(BladeStagePortsReadTaskRequests(
				_fixture.executor.ports, _task_read.next_cursor
			).records), 0,
			"resumed task cursor does not duplicate dispatch"
		);
	});

	BladeKernelTestRunCase(_state, "cleanup cannot impersonate defeat and paused defeat survives abort", function() {
		var _cleanup = _BladeStageTestsFixture();
		_BladeStageRuntimeTestsReachSpawn(_cleanup);
		var _cleanup_generation = BladeStageEncounterRegistryLatest(
			_cleanup.executor.encounters,
			"encounter_schedule.neutral_stage.targets"
		);
		_BladeStageTestsStep(_cleanup, BladeClockDomain.All, [
			_BladeStageTestsTerminal(
				_cleanup_generation.participants[0].instance_id,
				BladeCombatTerminalReason.StageEnd
			),
		]);
		BladeKernelTestAssertEqual(
			_cleanup.executor.current_node_id,
			"stage_node.neutral_stage.wait_targets",
			"StageEnd cleanup cannot satisfy all-defeated"
		);
		BladeKernelTestAssertEqual(
			array_length(_cleanup.runtime.reward_requests), 0,
			"StageEnd cleanup cannot request defeat reward"
		);

		var _paused = _BladeStageTestsFixture();
		_BladeStageRuntimeTestsReachSpawn(_paused);
		var _paused_generation = BladeStageEncounterRegistryLatest(
			_paused.executor.encounters,
			"encounter_schedule.neutral_stage.targets"
		);
		_BladeStageTestsStep(_paused, BladeClockDomain.Combat, [
			_BladeStageTestsTerminal(
				_paused_generation.participants[1].instance_id,
				BladeCombatTerminalReason.Defeat
			),
		]);
		BladeKernelTestAssertEqual(
			_paused_generation.participants[1].state,
			BladeStageParticipantState.Active,
			"paused Stage has not yet observed eligible Combat defeat"
		);
		BladeStageExecutorAbort(
			_paused.executor, _paused.runtime,
			BladeCombatTerminalReason.RunLoad,
			_BladeStageRuntimeTestsBoundaryTick(_paused)
		);
		BladeKernelTestAssertEqual(
			_paused_generation.participants[1].state,
			BladeStageParticipantState.RetainedHarmless,
			"abort reconciliation preserves unseen defeat provenance"
		);
		BladeKernelTestAssertEqual(
			_paused_generation.participants[0].state,
			BladeStageParticipantState.Cleaned,
			"abort marks only still-active participant cleaned"
		);
		BladeKernelTestAssertEqual(
			_paused_generation.lifecycle, BladeStageLifecycle.Aborted,
			"abort never converts reconciled defeat into encounter completion"
		);
		BladeKernelTestAssertEqual(
			array_length(_paused.executor.ports.signal_records), 1,
			"abort emits no completed lifecycle signal"
		);
		var _restart = BladeStageExecutorRestart(_paused.executor);
		BladeKernelTestAssertFalse(
			_restart.runtime_bound,
			"restart returns fresh unbound ownership for a new attempt"
		);
		BladeKernelTestAssertEqual(
			array_length(_restart.events.records), 0,
			"restart carries no prior event occurrence"
		);
	});

	BladeKernelTestRunCase(_state, "equivalent creation and delivery order yields identical bytes", function() {
		var _first = _BladeStageRuntimeTestsScenario(false, false, false);
		var _second = _BladeStageRuntimeTestsScenario(true, true, true);
		BladeKernelTestAssertEqual(
			_first.events, _second.events,
			"stage event bytes ignore raw and terminal delivery order"
		);
		BladeKernelTestAssertEqual(
			_first.stage_hash, _second.stage_hash,
			"final stage hash ignores equivalent delivery order"
		);
		BladeKernelTestAssertEqual(
			_first.kernel_hash, _second.kernel_hash,
			"kernel gameplay hash ignores equivalent delivery order"
		);
		var _event_hash = BladeCanonicalHashUtf8(_first.events);
		BladeKernelTestAssertEqual(
			_event_hash, "020f52c17ac895c94bde6d7aacc58e8274f32968",
			"stage event bytes retain their deterministic golden"
		);
		BladeKernelTestAssertEqual(
			_first.stage_hash, "8893b3c46f07b648aa0fffdbfe4a0f1c40981cee",
			"final stage state retains its deterministic golden"
		);
		BladeKernelTestAssertEqual(
			_first.kernel_hash, "bbb211d8a463cfcdd9a9511f5c34be256c2cc50c",
			"composed kernel state retains its deterministic golden"
		);
		show_debug_message(
			"BLADE_STAGE_EVENT_HASH: " + _event_hash
		);
		show_debug_message("BLADE_STAGE_FINAL_HASH: " + _first.stage_hash);
		show_debug_message("BLADE_STAGE_KERNEL_HASH: " + _first.kernel_hash);
	});
}
