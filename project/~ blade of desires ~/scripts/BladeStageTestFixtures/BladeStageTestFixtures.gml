/// @description Neutral raw-content, kernel, combat, resolver, and stepping fixtures for stage tests.

/// Returns the authoritative product gameplay plane used by the neutral catalog.
function _BladeStageTestsPlane() {
	return BladeCombatPlaneCreate({
		x_min: 185,
		x_max_exclusive: 455,
		y_min: 0,
		y_max_exclusive: 360,
		width: 270,
		height: 360,
		containment: "The plane is half-open.",
		anchor_containment: "point_inside_half_open_plane",
		hurtbox_containment: "fully_contained_in_half_open_plane",
		coordinate_grid: "binary_fixed_1_1024_logical_pixel",
		right_bottom_clamp: "exclusive_max_minus_one_grid_step",
	});
}

/// Reads and decodes the sole bundled neutral stage runtime authority.
function _BladeStageTestsRawCatalog() {
	var _stored = _BladeConfigFileStorageReadText(
		"content/stages/neutral_v1.json"
	);
	if (!_stored.ok) {
		_stored = _BladeConfigFileStorageReadText(
			working_directory + "content/stages/neutral_v1.json"
		);
	}
	if (!_stored.ok) BladeKernelTestFail("neutral stage data file is unavailable");
	return json_parse(_stored.text, undefined, true);
}

/// Returns a detached array with the caller's order reversed.
function _BladeStageTestsReverse(_values) {
	var _copy = [];
	for (var _index = array_length(_values) - 1; _index >= 0; --_index) {
		array_push(_copy, _BladeStagePlanClone(_values[_index]));
	}
	return _copy;
}

/// Reorders every authored collection while preserving identical raw semantics.
function _BladeStageTestsReorderedRaw(_raw) {
	var _copy = _BladeStagePlanClone(_raw);
	var _collections = [
		"named_anchors", "participant_kind_ids", "task_type_ids",
		"signal_type_ids", "cue_type_ids", "task_ports", "signals", "cues",
		"stages", "encounters",
	];
	for (var _index = 0; _index < array_length(_collections); ++_index) {
		var _name = _collections[_index];
		variable_struct_set(
			_copy, _name, _BladeStageTestsReverse(variable_struct_get(_copy, _name))
		);
	}
	for (var _stage_index = 0;
		_stage_index < array_length(_copy.stages); ++_stage_index) {
		_copy.stages[_stage_index].nodes = _BladeStageTestsReverse(
			_copy.stages[_stage_index].nodes
		);
	}
	for (var _encounter_index = 0;
		_encounter_index < array_length(_copy.encounters); ++_encounter_index) {
		var _encounter = _copy.encounters[_encounter_index];
		_encounter.participants = _BladeStageTestsReverse(_encounter.participants);
		_encounter.completion_predicate.participant_ids = _BladeStageTestsReverse(
			_encounter.completion_predicate.participant_ids
		);
	}
	return _copy;
}

/// Recognizes only the non-art actor content used by participant fixtures.
function _BladeStageTestsKnownContent(_content_id) {
	return _content_id == "enemy.fixture" || _content_id == "ally.fixture";
}

/// Resolves one complete combat spawn spec and can reject a selected call for atomicity tests.
function _BladeStageTestsParticipantResolver(
	_kind_id, _participant_id, _x_q10, _y_q10
) {
	self.calls += 1;
	if (self.fail_on_call == self.calls) {
		throw("fixture resolver rejected " + _participant_id);
	}
	if (_kind_id != "participant_kind.neutral_stage.target") {
		throw("fixture resolver received unknown kind " + _kind_id);
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

/// Resolves the minimal content identity needed by one ordinary playable object.
function _BladeStageTestsPlayableParticipantResolver(
	_kind_id, _participant_id, _x_q10, _y_q10
) {
	self.calls += 1;
	if (self.fail_on_call == self.calls) {
		throw("fixture playable resolver rejected " + _participant_id);
	}
	if (_kind_id != "participant_kind.neutral_stage.target") {
		throw("fixture playable resolver received unknown kind " + _kind_id);
	}
	return { content_id: "enemy.fixture" };
}

/// Records one real-object creation request without constructing a combat-runtime actor.
function _BladeStageTestsPlayableSpawn(_spawn) {
	array_push(self.records, _BladeStagePlanClone(_spawn));
	return true;
}

/// Replaces the neutral schedule with a spawn-first atomicity fixture.
function _BladeStageTestsSpawnFirstPlan(_normalized) {
	var _copy = _BladeStagePlanClone(_normalized);
	var _stage = _copy.catalogs[0].stages[0];
	var _spawn = _BladeStagePlanClone(_stage.nodes[2]);
	var _wait = _BladeStagePlanClone(_stage.nodes[3]);
	var _complete = _BladeStagePlanClone(_stage.nodes[7]);
	_spawn.content_order = 0;
	_spawn.next_node_id = _wait.id;
	_wait.content_order = 1;
	_wait.next_node_id = _complete.id;
	_complete.content_order = 2;
	_stage.entry_node_id = _spawn.id;
	_stage.nodes = [_spawn, _wait, _complete];
	return _copy;
}

/// Creates a bound standalone executor over a direct kernel and combat runtime.
function _BladeStageTestsFixture(
	_raw = undefined, _fail_on_call = 0, _spawn_first = false, _bind = true
) {
	var _plane = _BladeStageTestsPlane();
	if (is_undefined(_raw)) _raw = _BladeStageTestsRawCatalog();
	var _normalized = BladeStageCatalogNormalize(_raw, _plane);
	if (_spawn_first) _normalized = _BladeStageTestsSpawnFirstPlan(_normalized);
	var _fingerprint = BladeStageNormalizedPlanFingerprint(_normalized);
	var _kernel = BladeDeterministicKernelCreate(
		"sha1:288e8d1b7d90b5ce04b881bfa631ee3a497ef885", 305419896,
		method({}, _BladeStageTestsKnownContent), 8
	);
	var _event_owner_id = BladeKernelAllocate(
		_kernel, BladeRunIdKind.EventOwner
	);
	var _runtime = BladeCombatRuntimeCreate(
		_kernel.identity, _event_owner_id, _plane
	);
	var _resolver_state = { calls: 0, fail_on_call: _fail_on_call };
	var _executor = BladeStageExecutorCreate(
		_normalized, _fingerprint, "stage_schedule.neutral_fixture",
		method(_resolver_state, _BladeStageTestsParticipantResolver), _plane
	);
	if (_bind) BladeStageExecutorBindRuntime(_executor, _kernel, _runtime);
	return {
		plane: _plane,
		normalized: _normalized,
		fingerprint: _fingerprint,
		kernel: _kernel,
		runtime: _runtime,
		event_owner_id: _event_owner_id,
		resolver_state: _resolver_state,
		executor: _executor,
		terminal_requests: [],
		queue_ordinary_event: false,
	};
}

/// Creates a stage fixture bound directly to playable object creation and defeat reports.
function _BladeStageTestsPlayableFixture(
	_raw = undefined, _fail_on_call = 0, _bind = true
) {
	var _plane = _BladeStageTestsPlane();
	if (is_undefined(_raw)) _raw = _BladeStageTestsRawCatalog();
	var _normalized = BladeStageCatalogNormalize(_raw, _plane);
	var _fingerprint = BladeStageNormalizedPlanFingerprint(_normalized);
	var _kernel = BladeDeterministicKernelCreate(
		"sha1:288e8d1b7d90b5ce04b881bfa631ee3a497ef885", 305419896,
		method({}, _BladeStageTestsKnownContent), 8
	);
	var _resolver_state = { calls: 0, fail_on_call: _fail_on_call };
	var _spawn_state = { records: [] };
	var _spawn_callback = method(_spawn_state, _BladeStageTestsPlayableSpawn);
	var _executor = BladeStageExecutorCreate(
		_normalized, _fingerprint, "stage_schedule.neutral_fixture",
		method(_resolver_state, _BladeStageTestsPlayableParticipantResolver), _plane
	);
	if (_bind) {
		BladeStageExecutorBindPlayable(_executor, _kernel, _spawn_callback);
	}
	return {
		plane: _plane,
		normalized: _normalized,
		fingerprint: _fingerprint,
		kernel: _kernel,
		resolver_state: _resolver_state,
		spawn_state: _spawn_state,
		spawn_callback: _spawn_callback,
		executor: _executor,
		defeat_instance_ids: [],
		defeat_results: [],
	};
}

/// Runs combat first and Stage last while the kernel's EventLog tick stays open.
function _BladeStageTestsTick(_kernel, _input, _tick) {
	_BladeCombatRuntimeBeginTick(self.runtime, _kernel, _tick);
	for (var _index = 0; _index < array_length(self.terminal_requests); ++_index) {
		var _request = self.terminal_requests[_index];
		if (_request.reason == BladeCombatTerminalReason.Defeat) {
			var _actor_index = _BladeCombatRuntimeFind(
				self.runtime.actors, "instance_id", _request.instance_id
			);
			if (_actor_index >= 0) self.runtime.actors[_actor_index].health = 0;
		}
		BladeCombatRuntimeRequestTerminal(
			self.runtime, BladeCombatSubjectKind.Actor,
			_request.instance_id, _request.reason
		);
	}
	_BladeCombatRuntimeEndTick(self.runtime);
	BladeStageExecutorAdvance(self.executor, _kernel, self.runtime, _tick);
	if (self.queue_ordinary_event) {
		var _generation = BladeStageEncounterRegistryLatest(
			self.executor.encounters,
			"encounter_schedule.neutral_stage.targets"
		);
		BladeKernelQueueEvent(
			_kernel, BladeEventChannel.Gameplay, 200,
			"instance.spawned", "outcome.scheduled", "",
			_generation.participants[0].instance_id,
			self.event_owner_id, "enemy.fixture", []
		);
	}
	return BladeStageExecutorCanonical(self.executor);
}

/// Steps one exact kernel tick with caller-selected domains and terminal inputs.
function _BladeStageTestsStep(
	_fixture, _domains, _terminal_requests = [], _queue_ordinary_event = false
) {
	_fixture.terminal_requests = _BladeStagePlanClone(_terminal_requests);
	_fixture.queue_ordinary_event = _queue_ordinary_event;
	var _result = BladeKernelStepDirect(
		_fixture.kernel, BladeInputRawStateCreate(0, 0, 0), _domains,
		method(_fixture, _BladeStageTestsTick)
	);
	_fixture.terminal_requests = [];
	_fixture.queue_ordinary_event = false;
	return _result;
}

/// Reports queued real-object defeats, then advances the same deterministic schedule.
function _BladeStageTestsPlayableTick(_kernel, _input, _tick) {
	self.defeat_results = [];
	for (var _index = 0;
		_index < array_length(self.defeat_instance_ids); ++_index) {
		array_push(self.defeat_results, BladeStageExecutorReportPlayableDefeat(
			self.executor, _kernel, self.defeat_instance_ids[_index], _tick
		));
	}
	BladeStageExecutorAdvancePlayable(self.executor, _kernel, _tick);
	return BladeStageExecutorCanonical(self.executor);
}

/// Steps one playable stage tick with caller-selected domains and defeat IDs.
function _BladeStageTestsPlayableStep(
	_fixture, _domains, _defeat_instance_ids = []
) {
	_fixture.defeat_instance_ids = _BladeStagePlanClone(_defeat_instance_ids);
	var _result = BladeKernelStepDirect(
		_fixture.kernel, BladeInputRawStateCreate(0, 0, 0), _domains,
		method(_fixture, _BladeStageTestsPlayableTick)
	);
	_fixture.defeat_instance_ids = [];
	return _result;
}

/// Returns one terminal request record for an owned actor.
function _BladeStageTestsTerminal(_instance_id, _reason) {
	return { instance_id: _instance_id, reason: _reason };
}
