/// @description End-to-end public coordinator tests over bundled neutral stage content.

/// Recognizes every stable ID used by the neutral stage and its runtime actor fixture.
function _BladeRunStageTestsKnownContent(_content_id) {
	var _known = [
		"contract.blade", "ship.maynii", "difficulty.normal",
		"enemy.fixture", "ally.fixture",
		"stage_catalog.neutral_fixture", "anchor.neutral_stage.entry",
		"participant_kind.neutral_stage.target",
		"task_type.neutral_stage.probe",
		"signal_type.neutral_stage.encounter_lifecycle",
		"signal_type.neutral_stage.external",
		"signal_type.neutral_stage.task_completion",
		"cue_type.neutral_stage.semantic", "task_port.neutral_stage.probe",
		"signal.neutral_stage.encounter_completed",
		"signal.neutral_stage.encounter_started",
		"signal.neutral_stage.release",
		"signal.neutral_stage.task_completed", "cue.neutral_stage.ready",
		"stage_schedule.neutral_fixture",
		"stage_node.neutral_stage.ready",
		"stage_node.neutral_stage.wait_two_ticks",
		"stage_node.neutral_stage.spawn_targets",
		"stage_node.neutral_stage.wait_targets",
		"stage_node.neutral_stage.request_probe",
		"stage_node.neutral_stage.wait_probe",
		"stage_node.neutral_stage.wait_release",
		"stage_node.neutral_stage.complete",
		"encounter_schedule.neutral_stage.targets",
		"participant.neutral_stage.first",
		"participant.neutral_stage.second",
	];
	for (var _index = 0; _index < array_length(_known); ++_index) {
		if (_known[_index] == _content_id) return true;
	}
	return false;
}

/// Resolves one neutral participant to a deterministic one-pixel enemy actor.
function _BladeRunStageTestsParticipantResolver(
	_kind_id, _participant_id, _x_q10, _y_q10
) {
	self.calls += 1;
	if (_kind_id != "participant_kind.neutral_stage.target") {
		throw("run-stage fixture received unknown kind " + _kind_id);
	}
	return {
		content_id: "enemy.fixture",
		faction: BladeCombatFaction.Enemy,
		health: 1,
		box: BladeCombatAabbCreate(
			_x_q10, _y_q10, _x_q10 + 1024, _y_q10 + 1024
		),
		invulnerable_until_combat_tick: int64(0),
		reward_on_defeat: true,
		child_spec: undefined,
	};
}

/// Returns the exact raw-file SHA-1 expected by the bundled product loader.
function _BladeRunStageTestsProductFingerprint() {
	return "sha1:" + sha1_file("content/product_contract.json");
}

/// Creates one coordinator and optionally attaches the actual bundled neutral catalog.
function _BladeRunStageTestsCreate(
	_attach = true, _fingerprint = undefined, _seed = 305419896
) {
	if (is_undefined(_fingerprint)) {
		_fingerprint = _BladeRunStageTestsProductFingerprint();
	}
	var _resolver_state = { calls: 0 };
	var _coordinator = BladeRunCoordinatorCreate(
		_fingerprint, method({}, _BladeRunStageTestsKnownContent),
		"ship.maynii", "difficulty.normal", BladeRunMode.Normal,
		_seed, 8, _BladeStageTestsPlane()
	);
	var _player = BladeRunCombatRegisterPlayer(
		_coordinator, 10,
		BladeCombatAabbCreate(200000, 300000, 201024, 301024)
	);
	var _attach_result = undefined;
	if (_attach) {
		_attach_result = BladeRunStageLoadAndAttach(
			_coordinator, "content/stages/neutral_v1.json",
			"stage_schedule.neutral_fixture",
			method(_resolver_state, _BladeRunStageTestsParticipantResolver)
		);
	}
	return {
		coordinator: _coordinator,
		player_id: _player.instance_id,
		resolver_state: _resolver_state,
		attach_result: _attach_result,
	};
}

/// Advances one coordinator tick with neutral input and caller-selected domains.
function _BladeRunStageTestsStep(
	_fixture, _domains = BladeClockDomain.All, _callback = undefined
) {
	return BladeRunCoordinatorStepDirect(
		_fixture.coordinator, BladeInputRawStateCreate(0, 0, 0),
		_domains, _callback
	);
}

/// Advances through the cue, active wait, and deterministic encounter spawn.
function _BladeRunStageTestsReachSpawn(_fixture) {
	_BladeRunStageTestsStep(_fixture);
	_BladeRunStageTestsStep(_fixture);
	_BladeRunStageTestsStep(_fixture);
	return BladeRunStageSnapshot(_fixture.coordinator);
}

/// Emits one legitimate lethal player attack spanning both owned participants.
function _BladeRunStageTestsDefeatCallback(_run, _input, _tick) {
	BladeRunCombatPlayerEmit(
		self.coordinator, self.player_id,
		BladeCombatOffenseSpecCreate(
			1, BladeCombatCancellationPolicy.Ignore, 0, 0, 2, 1
		),
		self.target_box
	);
	return undefined;
}

/// Mutates only detached callback data and proves live submissions reject reentrancy.
function _BladeRunStageTestsDetachedCallback(_run, _input, _tick) {
	_run.stage.current_node_id = "stage_node.detached.mutation";
	_run.stage.ports.task_requests = [{ mutated: true }];
	try {
		BladeRunStageSubmitExternalSignal(
			self.coordinator, "signal.neutral_stage.release",
			"signal_type.neutral_stage.external", int64(1)
		);
	} catch (_caught) {
		self.submission_rejected = string_pos(
			"cannot run while coordinator is advancing", string(_caught)
		) > 0;
	}
	self.callback_tick = _tick.simulation_tick;
	return undefined;
}

/// Hashes the detached public stage-event occurrence stream in append order.
function _BladeRunStageTestsEventDigest(_events) {
	var _hashes = [];
	for (var _index = 0; _index < array_length(_events); ++_index) {
		array_push(_hashes, _events[_index].event_hash);
	}
	return BladeCanonicalHashUtf8(BladeCanonicalRecord("BRSTE1", _hashes));
}

/// Runs the exact bundled neutral schedule to its explicit complete node.
function _BladeRunStageTestsCompleteScenario() {
	var _fixture = _BladeRunStageTestsCreate();
	var _spawned = _BladeRunStageTestsReachSpawn(_fixture);
	var _generation = _spawned.encounters.generations[0];
	var _defeat_context = {
		coordinator: _fixture.coordinator,
		player_id: _fixture.player_id,
		target_box: BladeCombatAabbCreate(
			min(
				_generation.participants[0].x_q10,
				_generation.participants[1].x_q10
			),
			min(
				_generation.participants[0].y_q10,
				_generation.participants[1].y_q10
			),
			max(
				_generation.participants[0].x_q10,
				_generation.participants[1].x_q10
			) + 1024,
			max(
				_generation.participants[0].y_q10,
				_generation.participants[1].y_q10
			) + 1024
		),
	};
	_BladeRunStageTestsStep(
		_fixture, BladeClockDomain.All,
		method(_defeat_context, _BladeRunStageTestsDefeatCallback)
	);
	var _after_defeat = BladeRunStageSnapshot(_fixture.coordinator);
	var _task_read = BladeRunStageReadTaskRequests(_fixture.coordinator, 0);
	var _request = _task_read.records[0];
	var _task_result = BladeRunStageSubmitTaskCompletion(
		_fixture.coordinator, _request.port_id, _request.type_id,
		_request.completion_signal_id, _request.completion_signal_type_id,
		_request.execution_generation
	);
	_BladeRunStageTestsStep(_fixture);
	var _wait = BladeRunStageSnapshot(_fixture.coordinator);
	var _external_result = BladeRunStageSubmitExternalSignal(
		_fixture.coordinator, "signal.neutral_stage.release",
		"signal_type.neutral_stage.external", _wait.current_generation
	);
	_BladeRunStageTestsStep(_fixture);
	var _event_read = BladeRunStageReadEvents(_fixture.coordinator, 0);
	return {
		fixture: _fixture,
		after_defeat: _after_defeat,
		task_result: _task_result,
		external_result: _external_result,
		events: _event_read.records,
		event_digest: _BladeRunStageTestsEventDigest(_event_read.records),
		stage_hash: BladeCanonicalHashUtf8(
			BladeRunStageCanonical(_fixture.coordinator)
		),
		final_canonical: BladeRunCoordinatorCanonical(_fixture.coordinator),
		final_hash: BladeRunCoordinatorHash(_fixture.coordinator),
	};
}

/// Asserts one administrative boundary aborts owned participants without completion.
function _BladeRunStageTestsAssertAbortedBoundary(_report, _reason, _label) {
	BladeKernelTestAssertEqual(
		_report.lifecycle, BladeStageLifecycle.Aborted,
		_label + " aborts stage ownership"
	);
	var _generation = _report.encounters.generations[0];
	BladeKernelTestAssertEqual(
		_generation.lifecycle, BladeStageLifecycle.Aborted,
		_label + " cannot complete the encounter"
	);
	for (var _index = 0; _index < array_length(_generation.participants); ++_index) {
		BladeKernelTestAssertEqual(
			_generation.participants[_index].state,
			BladeStageParticipantState.Cleaned,
			_label + " cleans each still-active participant"
		);
		BladeKernelTestAssertEqual(
			_generation.participants[_index].terminal_reason, _reason,
			_label + " retains the authoritative cleanup reason"
		);
	}
	for (var _index = 0; _index < array_length(_report.ports.signal_records); ++_index) {
		BladeKernelTestAssertFalse(
			_report.ports.signal_records[_index].source_kind == "encounter_completed",
			_label + " emits no encounter-completed signal"
		);
	}
}

/// Registers bundled loading, progression, pause, lifecycle, and determinism coverage.
function BladeRunStageTestsRun(_state) {
	BladeKernelTestRunCase(_state, "bundled neutral stage completes in exact public order", function() {
		var _first = _BladeRunStageTestsCompleteScenario();
		var _second = _BladeRunStageTestsCompleteScenario();
		var _final = BladeRunStageSnapshot(_first.fixture.coordinator);
		BladeKernelTestAssertEqual(
			_final.lifecycle, BladeStageLifecycle.Completed,
			"explicit complete node owns the terminal stage lifecycle"
		);
		BladeKernelTestAssertTrue(
			_first.task_result.accepted && _first.external_result.accepted,
			"exact typed task and external occurrences are accepted"
		);
		BladeKernelTestAssertEqual(
			_first.after_defeat.current_node_id,
			"stage_node.neutral_stage.wait_probe",
			"same-tick Combat defeats open the encounter gate before callback return"
		);
		var _defeated = _first.after_defeat.encounters.generations[0];
		BladeKernelTestAssertEqual(
			_defeated.participants[0].state, BladeStageParticipantState.Defeated,
			"removed participant records exact defeat"
		);
		BladeKernelTestAssertEqual(
			_defeated.participants[1].state,
			BladeStageParticipantState.RetainedHarmless,
			"retained participant records harmless defeat"
		);

		var _orders = [];
		var _ticks = [];
		var _stage_ticks = [];
		var _nodes = [];
		for (var _index = 0; _index < array_length(_first.events); ++_index) {
			var _event = _first.events[_index];
			array_push(_orders, _event.content_order);
			array_push(_ticks, _event.simulation_tick);
			array_push(_stage_ticks, _event.stage_tick);
			array_push(_nodes, _event.node_id);
		}
		BladeKernelTestAssertArrayEqual(
			_orders, [0, 1, 2, 3, 4, 5, 6, 7],
			"neutral node events commit once in content order"
		);
		BladeKernelTestAssertArrayEqual(
			_ticks, [1, 3, 3, 4, 4, 5, 6, 6],
			"neutral event transcript uses fixed simulation ticks"
		);
		BladeKernelTestAssertArrayEqual(
			_stage_ticks, [1, 3, 3, 4, 4, 5, 6, 6],
			"unpaused neutral transcript uses matching Stage ticks"
		);
		BladeKernelTestAssertArrayEqual(_nodes, [
			"stage_node.neutral_stage.ready",
			"stage_node.neutral_stage.wait_two_ticks",
			"stage_node.neutral_stage.spawn_targets",
			"stage_node.neutral_stage.wait_targets",
			"stage_node.neutral_stage.request_probe",
			"stage_node.neutral_stage.wait_probe",
			"stage_node.neutral_stage.wait_release",
			"stage_node.neutral_stage.complete",
		], "neutral transcript retains exact stable node IDs");
		BladeKernelTestAssertEqual(
			_first.final_canonical, _second.final_canonical,
			"equal public runs produce byte-identical final canonical state"
		);
		BladeKernelTestAssertEqual(
			_first.event_digest, _second.event_digest,
			"equal public runs produce identical event transcript hashes"
		);
		BladeKernelTestAssertEqual(
			_first.stage_hash, _second.stage_hash,
			"equal public runs produce identical final stage hashes"
		);
		BladeKernelTestAssertEqual(
			_first.event_digest,
			"71d5bf5ba4bccd279b1555e3a57e5f68e939fde8",
			"public neutral event transcript matches its verified fixed digest"
		);
		BladeKernelTestAssertEqual(
			_first.stage_hash,
			"5ba94aa4520a08e8473600d67607173185f04e0c",
			"public neutral stage matches its verified final hash"
		);
		BladeKernelTestAssertEqual(
			_first.final_hash,
			"8f3a8e64e1e320846b760f2a4817c98138603a1d",
			"public neutral coordinator matches its verified final hash"
		);

		var _cue_read = BladeRunStageReadCueRequests(
			_first.fixture.coordinator, 0
		);
		BladeKernelTestAssertEqual(
			array_length(_cue_read.records), 1,
			"semantic ready cue is delivered exactly once"
		);
		BladeKernelTestAssertEqual(
			_cue_read.records[0].cue_id, "cue.neutral_stage.ready",
			"cue delivery retains its stable semantic ID"
		);
		_cue_read.records[0].cue_id = "cue.detached.mutation";
		BladeKernelTestAssertEqual(
			BladeRunStageReadCueRequests(
				_first.fixture.coordinator, 0
			).records[0].cue_id,
			"cue.neutral_stage.ready",
			"consumer mutation cannot alter the owned cue outbox"
		);
		BladeKernelTestAssertEqual(
			array_length(BladeRunStageReadCueRequests(
				_first.fixture.coordinator, _cue_read.next_cursor
			).records), 0,
			"resumed cue cursor redispatches nothing"
		);
	});

	BladeKernelTestRunCase(_state, "public Stage pause freezes schedule but not Combat", function() {
		var _fixture = _BladeRunStageTestsCreate();
		_BladeRunStageTestsStep(_fixture);
		var _stage_before = BladeRunStageCanonical(_fixture.coordinator);
		var _clock_before = BladeRunCoordinatorDiagnostics(
			_fixture.coordinator
		).kernel.clock;
		var _first_owner = BladeRunCoordinatorAllocatePauseOwner(_fixture.coordinator);
		var _second_owner = BladeRunCoordinatorAllocatePauseOwner(_fixture.coordinator);
		var _first_token = BladeRunCoordinatorAcquirePause(
			_fixture.coordinator, _first_owner, "pause.stage_integration_test.first",
			BladeClockDomain.Stage, BladePauseReleasePolicy.Explicit
		);
		var _second_token = BladeRunCoordinatorAcquirePause(
			_fixture.coordinator, _second_owner, "pause.stage_integration_test.second",
			BladeClockDomain.Stage, BladePauseReleasePolicy.Explicit
		);
		_BladeRunStageTestsStep(_fixture);
		_BladeRunStageTestsStep(_fixture);
		var _clock_paused = BladeRunCoordinatorDiagnostics(
			_fixture.coordinator
		).kernel.clock;
		BladeKernelTestAssertEqual(
			BladeRunStageCanonical(_fixture.coordinator), _stage_before,
			"nested public pause tokens consume no Stage executor state"
		);
		BladeKernelTestAssertEqual(
			_clock_paused.stage_tick, _clock_before.stage_tick,
			"Stage clock remains frozen while token is active"
		);
		BladeKernelTestAssertEqual(
			_clock_paused.combat_tick, _clock_before.combat_tick + 2,
			"Combat continues for both Stage-paused simulation ticks"
		);
		BladeKernelTestAssertTrue(
			BladeRunCoordinatorReleasePause(
				_fixture.coordinator, _first_owner, _first_token.token_id
			).released,
			"first public owner releases only its Stage pause token"
		);
		_BladeRunStageTestsStep(_fixture);
		var _clock_nested = BladeRunCoordinatorDiagnostics(
			_fixture.coordinator
		).kernel.clock;
		BladeKernelTestAssertEqual(
			BladeRunStageCanonical(_fixture.coordinator), _stage_before,
			"remaining nested token keeps Stage frozen"
		);
		BladeKernelTestAssertEqual(
			_clock_nested.stage_tick, _clock_before.stage_tick,
			"releasing one nested owner cannot advance Stage"
		);
		BladeKernelTestAssertEqual(
			_clock_nested.combat_tick, _clock_before.combat_tick + 3,
			"Combat advances while the second Stage token remains"
		);
		BladeKernelTestAssertTrue(
			BladeRunCoordinatorReleasePause(
				_fixture.coordinator, _second_owner, _second_token.token_id
			).released,
			"second public owner releases the final Stage pause token"
		);
		_BladeRunStageTestsStep(_fixture);
		BladeKernelTestAssertNotEqual(
			BladeRunStageCanonical(_fixture.coordinator), _stage_before,
			"released Stage resumes on the next eligible tick"
		);
	});

	BladeKernelTestRunCase(_state, "callback snapshots and submissions cannot mutate Stage", function() {
		var _fixture = _BladeRunStageTestsCreate();
		var _stage_before = BladeRunStageCanonical(_fixture.coordinator);
		var _context = {
			coordinator: _fixture.coordinator,
			submission_rejected: false,
			callback_tick: int64(0),
		};
		_BladeRunStageTestsStep(
			_fixture, BladeClockDomain.Combat,
			method(_context, _BladeRunStageTestsDetachedCallback)
		);
		BladeKernelTestAssertTrue(
			_context.submission_rejected,
			"stage submission is rejected while coordinator advances"
		);
		BladeKernelTestAssertEqual(
			_context.callback_tick, int64(1),
			"detached callback observes the resolved simulation tick"
		);
		BladeKernelTestAssertEqual(
			BladeRunStageCanonical(_fixture.coordinator), _stage_before,
			"detached mutation and Combat-only tick cannot progress Stage"
		);
	});

	BladeKernelTestRunCase(_state, "reset restarts and binds Stage with the new attempt", function() {
		var _fixture = _BladeRunStageTestsCreate();
		_BladeRunStageTestsReachSpawn(_fixture);
		var _reset = BladeRunCoordinatorReset(
			_fixture.coordinator, "ship.maynii", "difficulty.normal",
			BladeRunMode.Normal, 305419896
		);
		var _fresh = _BladeRunStageTestsCreate();
		BladeKernelTestAssertEqual(
			_fixture.resolver_state.calls, 4,
			"reset preflights both participant specs for the new identity"
		);
		BladeKernelTestAssertTrue(
			_reset.stage.runtime_bound,
			"replacement Stage is bound before the reset returns"
		);
		BladeKernelTestAssertEqual(
			array_length(_reset.stage.events), 0,
			"replacement Stage carries no prior attempt events"
		);
		BladeKernelTestAssertEqual(
			array_length(_reset.combat.actors), 0,
			"reset does not retain client combat registration"
		);
		_BladeRunStageTestsAssertAbortedBoundary(
			_reset.prior_stage_boundary_report,
			BladeCombatTerminalReason.RunReset, "reset"
		);
		BladeKernelTestAssertEqual(
			BladeRunStageCanonical(_fixture.coordinator),
			BladeRunStageCanonical(_fresh.coordinator),
			"reset Stage equals independently created attached ownership"
		);
	});

	BladeKernelTestRunCase(_state, "administrative cleanup never completes an encounter", function() {
		var _aborted = _BladeRunStageTestsCreate();
		_BladeRunStageTestsReachSpawn(_aborted);
		var _abort_result = BladeRunCoordinatorAbort(_aborted.coordinator);
		_BladeRunStageTestsAssertAbortedBoundary(
			_abort_result.stage_boundary_report,
			BladeCombatTerminalReason.RunAborted, "run abort"
		);

		var _loaded = _BladeRunStageTestsCreate();
		_BladeRunStageTestsReachSpawn(_loaded);
		var _load_result = BladeRunCoordinatorLoadBoundary(_loaded.coordinator);
		_BladeRunStageTestsAssertAbortedBoundary(
			_load_result.stage_boundary_report,
			BladeCombatTerminalReason.RunLoad, "run load"
		);

		var _room = _BladeRunStageTestsCreate();
		_BladeRunStageTestsReachSpawn(_room);
		var _room_result = BladeRunCombatRoomExit(_room.coordinator);
		_BladeRunStageTestsAssertAbortedBoundary(
			_room_result.stage_boundary_report,
			BladeCombatTerminalReason.RoomExit, "room exit"
		);
		BladeKernelTestAssertFalse(
			variable_struct_exists(
				BladeRunCoordinatorSnapshot(_room.coordinator), "stage"
			),
			"room exit releases attached stage ownership"
		);
		BladeRunStageLoadAndAttach(
			_room.coordinator, "content/stages/neutral_v1.json",
			"stage_schedule.neutral_fixture",
			method(_room.resolver_state, _BladeRunStageTestsParticipantResolver)
		);
		BladeKernelTestAssertEqual(
			BladeRunStageSnapshot(_room.coordinator).lifecycle,
			BladeStageLifecycle.Active,
			"active run can attach the next room's fresh stage"
		);
	});

	BladeKernelTestRunCase(_state, "product fingerprint mismatch cannot attach or allocate", function() {
		var _fixture = _BladeRunStageTestsCreate(
			false, "sha1:0000000000000000000000000000000000000000"
		);
		var _before = BladeRunCoordinatorCanonical(_fixture.coordinator);
		var _identity_before = BladeRunCoordinatorDiagnostics(
			_fixture.coordinator
		).kernel.identity;
		var _context = { fixture: _fixture };
		BladeKernelTestAssertThrows(method(_context, function() {
			BladeRunStageLoadAndAttach(
				self.fixture.coordinator, "content/stages/neutral_v1.json",
				"stage_schedule.neutral_fixture",
				method(
					self.fixture.resolver_state,
					_BladeRunStageTestsParticipantResolver
				)
			);
		}), "product fingerprint", "mismatched product file is rejected");
		var _identity_after = BladeRunCoordinatorDiagnostics(
			_fixture.coordinator
		).kernel.identity;
		BladeKernelTestAssertEqual(
			BladeRunCoordinatorCanonical(_fixture.coordinator), _before,
			"failed product binding changes no coordinator state"
		);
		BladeKernelTestAssertFalse(
			variable_struct_exists(
				BladeRunCoordinatorSnapshot(_fixture.coordinator), "stage"
			),
			"failed product binding attaches no stage owner"
		);
		BladeKernelTestAssertEqual(
			_fixture.resolver_state.calls, 0,
			"failed product binding never invokes participant resolution"
		);
		BladeKernelTestAssertEqual(
			_identity_after.instance, _identity_before.instance,
			"failed product binding allocates no instance ID"
		);
		BladeKernelTestAssertEqual(
			_identity_after.event, _identity_before.event,
			"failed product binding allocates no event ID"
		);
	});
}
