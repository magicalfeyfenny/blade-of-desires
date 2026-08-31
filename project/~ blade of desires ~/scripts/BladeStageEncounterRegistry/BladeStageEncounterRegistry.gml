/// @description Encounter-owned participant registration and exact all-defeated completion gates.

/// Rejects values that are not version 1 encounter registries.
function _BladeStageEncounterRegistryRequire(_registry) {
	if (!is_struct(_registry)
		|| !variable_struct_exists(_registry, "__blade_stage_encounter_registry_version")
		|| _registry.__blade_stage_encounter_registry_version != 1) {
		_BladeStagePlanFail("encounter registry", "expected a version 1 registry");
	}
	if (!is_array(_registry.generations)) {
		_BladeStagePlanFail("encounter registry", "generations must remain an array");
	}
	return _registry;
}

/// Finds the most recently spawned generation for one encounter ID.
function BladeStageEncounterRegistryLatest(_registry, _encounter_id) {
	_BladeStageEncounterRegistryRequire(_registry);
	for (var _index = array_length(_registry.generations) - 1; _index >= 0; --_index) {
		if (_registry.generations[_index].encounter_id == _encounter_id) {
			return _registry.generations[_index];
		}
	}
	return undefined;
}

/// Finds an active participant by allocated instance ID across owned generations.
function _BladeStageEncounterParticipant(_registry, _instance_id) {
	for (var _generation_index = 0;
		_generation_index < array_length(_registry.generations); ++_generation_index) {
		var _generation = _registry.generations[_generation_index];
		for (var _participant_index = 0;
			_participant_index < array_length(_generation.participants); ++_participant_index) {
			var _participant = _generation.participants[_participant_index];
			if (_participant.instance_id == _instance_id) {
				return { generation: _generation, participant: _participant };
			}
		}
	}
	return undefined;
}

/// Requires combat runtime geometry to equal the plane bound during plan preflight.
function _BladeStageEncounterRequirePlane(_registry, _runtime) {
	var _expected = BladeCombatPlaneCopy(_registry.plan.gameplay_plane);
	var _actual = BladeCombatPlaneCopy(_runtime.plane);
	if (_actual.left_q10 != _expected.left_q10
		|| _actual.top_q10 != _expected.top_q10
		|| _actual.right_q10_exclusive != _expected.right_q10_exclusive
		|| _actual.bottom_q10_exclusive != _expected.bottom_q10_exclusive) {
		_BladeStagePlanFail(
			"participant spawn", "combat runtime plane differs from the plan binding"
		);
	}
}

/// Validates one resolver-produced combat actor specification without allocating an ID.
function _BladeStageEncounterSpawnSpec(_runtime, _value, _field) {
	_BladeStagePlanExactKeys(
		_value,
		["content_id", "faction", "health", "box", "invulnerable_until_combat_tick", "reward_on_defeat", "child_spec"],
		_field
	);
	return {
		content_id: BladeRunIdentityRequireContent(_runtime.identity, _value.content_id),
		faction: _BladeCombatRuntimeInteger(
			_value.faction, BladeCombatFaction.Player, BladeCombatFaction.Enemy,
			_field + ".faction"
		),
		health: _BladeCombatRuntimeInteger(
			_value.health, 1, int64("2147483647"), _field + ".health"
		),
		box: _BladeCombatGeometryAabbCopy(_value.box),
		invulnerable_until_combat_tick: _BladeCombatRuntimeInteger(
			_value.invulnerable_until_combat_tick, 0,
			int64("9223372036854775807"), _field + ".invulnerable_until_combat_tick"
		),
		reward_on_defeat: _BladeCombatRuntimeBoolean(
			_value.reward_on_defeat, _field + ".reward_on_defeat"
		),
		child_spec: _BladeCombatRuntimeChildSpec(_runtime, _value.child_spec),
	};
}

/// Resolves and validates every participant spawn specification before any runtime mutation.
function _BladeStageEncounterSpawnPlan(
	_registry, _encounter, _anchor_point, _resolver, _runtime
) {
	if (typeof(_resolver) != "method") {
		_BladeStagePlanFail("participant resolver", "must be a method");
	}
	var _plans = [];
	for (var _index = 0; _index < array_length(_encounter.participants); ++_index) {
		var _participant = _encounter.participants[_index];
		var _x = _BladeStagePlanInteger(
			_anchor_point.x_q10 + _participant.local_offset_q10.x,
			int64("-2147483648"), int64("2147483647"), "participant x_q10"
		);
		var _y = _BladeStagePlanInteger(
			_anchor_point.y_q10 + _participant.local_offset_q10.y,
			int64("-2147483648"), int64("2147483647"), "participant y_q10"
		);
		var _resolved = _resolver(
			_participant.kind_id, _participant.id, _x, _y
		);
		array_push(_plans, {
			participant: _BladeStagePlanClone(_participant),
			x_q10: _x,
			y_q10: _y,
			spawn_spec: _BladeStageEncounterSpawnSpec(
				_runtime, _resolved, "participant spawn specification"
			),
		});
	}
	return _plans;
}

/// Rechecks mutable Instance-ID capacity immediately before a prepared commit.
function _BladeStageEncounterRequireCapacity(_identity, _count) {
	var _counters = BladeRunIdentityGetCounters(_identity);
	var _validated_count = _BladeStagePlanInteger(
		_count, 1, int64("2147483647"), "participant spawn count"
	);
	var _maximum_allocated = int64("9223372036854775806");
	if (_counters.instance > _maximum_allocated - _validated_count) {
		_BladeStagePlanFail("participant spawn", "exceeds instance ID capacity");
	}
}

/// Commits one validated spawn batch through the caller's concrete participant creator.
function _BladeStageEncounterCommitPrepared(
	_registry, _ports, _kernel, _validated, _tick, _generation, _spawn_callback
) {
	if (typeof(_spawn_callback) != "method") {
		_BladeStagePlanFail("participant spawn", "requires a concrete spawn callback");
	}
	var _validated_generation = _BladeStagePortsGeneration(
		_generation, "encounter generation"
	);
	var _participants = [];
	for (var _index = 0; _index < array_length(_validated.participants); ++_index) {
		var _plan = _validated.participants[_index];
		var _instance_id = BladeKernelAllocateForContent(
			_kernel, BladeRunIdKind.Instance, _plan.spawn_spec.content_id
		);
		_spawn_callback(_plan, _instance_id, _tick);
		array_push(_participants, {
			participant_id: _plan.participant.id,
			participant_kind_id: _plan.participant.kind_id,
			spawn_order: _plan.participant.spawn_order,
			instance_id: _instance_id,
			content_id: _plan.spawn_spec.content_id,
			x_q10: _plan.x_q10,
			y_q10: _plan.y_q10,
			defeat_disposition: _plan.participant.defeat_disposition,
			state: BladeStageParticipantState.Active,
			terminal_reason: BladeCombatTerminalReason.None,
			terminal_simulation_tick: int64(-1),
			terminal_combat_tick: int64(-1),
		});
	}
	var _record = {
		encounter_id: _validated.encounter_id,
		spawn_node_id: _validated.node_id,
		execution_generation: _validated_generation,
		lifecycle: BladeStageLifecycle.Active,
		participants: _participants,
		completion_simulation_tick: int64(-1),
		completion_stage_tick: int64(-1),
	};
	array_push(_registry.generations, _record);
	var _encounter = _BladeStagePlanFind(
		_registry.plan.encounters, _validated.encounter_id
	);
	BladeStagePortsEmitEncounterSignal(
		_ports, _encounter.stage_signals.started.signal_id,
		_encounter.stage_signals.started.type_id, _encounter.id,
		"encounter_started", _validated_generation
	);
	return _BladeStagePlanClone(_record);
}

/// Validates one cached whole-batch plan without calling its resolver again.
function _BladeStageEncounterPreparedPlan(
	_registry, _runtime, _prepared
) {
	_BladeStagePlanExactKeys(
		_prepared,
		["__blade_stage_encounter_spawn_plan_version", "node_id", "encounter_id", "participants"],
		"prepared participant spawn"
	);
	if (_prepared.__blade_stage_encounter_spawn_plan_version != 1) {
		_BladeStagePlanFail("prepared participant spawn", "has the wrong version");
	}
	var _encounter = _BladeStagePlanFind(
		_registry.plan.encounters, _prepared.encounter_id
	);
	if (is_undefined(_encounter)
		|| array_length(_prepared.participants)
			!= array_length(_encounter.participants)) {
		_BladeStagePlanFail("prepared participant spawn", "does not match its encounter");
	}
	var _participants = [];
	for (var _index = 0; _index < array_length(_encounter.participants); ++_index) {
		var _value = _prepared.participants[_index];
		_BladeStagePlanExactKeys(
			_value, ["participant", "x_q10", "y_q10", "spawn_spec"],
			"prepared participant"
		);
		var _expected = _encounter.participants[_index];
		if (!is_struct(_value.participant)
			|| _value.participant.id != _expected.id
			|| _value.participant.kind_id != _expected.kind_id
			|| _value.participant.spawn_order != _expected.spawn_order
			|| _value.participant.defeat_disposition != _expected.defeat_disposition) {
			_BladeStagePlanFail("prepared participant", "does not match spawn order");
		}
		var _x = _BladeStagePlanInteger(
			_value.x_q10, int64("-2147483648"), int64("2147483647"),
			"prepared participant x_q10"
		);
		var _y = _BladeStagePlanInteger(
			_value.y_q10, int64("-2147483648"), int64("2147483647"),
			"prepared participant y_q10"
		);
		if (!BladeCombatPlaneContainsPoint(_registry.plan.gameplay_plane, _x, _y)) {
			_BladeStagePlanFail("prepared participant", "lies outside the gameplay plane");
		}
		array_push(_participants, {
			participant: _BladeStagePlanClone(_expected),
			x_q10: _x,
			y_q10: _y,
			spawn_spec: _BladeStageEncounterSpawnSpec(
				_runtime, _value.spawn_spec, "prepared participant spawn specification"
			),
		});
	}
	return {
		__blade_stage_encounter_spawn_plan_version: 1,
		node_id: _BladeStagePlanStableId(
			_prepared.node_id, "stage_node", "prepared spawn node ID"
		),
		encounter_id: _encounter.id,
		participants: _participants,
	};
}

/// Creates an empty registry that observes the selected plan's combat terminal frontier.
function BladeStageEncounterRegistryCreate(_plan) {
	_BladeStagePlanRequire(_plan);
	return {
		__blade_stage_encounter_registry_version: 1,
		plan: _plan,
		generations: [],
		terminal_cursor: int64(0),
	};
}

/// Resolves and validates one entire spawn node without allocating or registering anything.
function BladeStageEncounterRegistryPrepareSpawn(
	_registry, _kernel, _runtime, _node_id, _encounter_id, _anchor_point, _resolver
) {
	_BladeStageEncounterRegistryRequire(_registry);
	_BladeKernelRequire(_kernel);
	_BladeCombatRuntimeRequire(_runtime);
	if (_runtime.identity != _kernel.identity || !is_undefined(_runtime.active_tick)) {
		_BladeStagePlanFail(
			"participant spawn preflight", "requires the shared identity between ticks"
		);
	}
	_BladeStageEncounterRequirePlane(_registry, _runtime);
	var _encounter = _BladeStagePlanFind(_registry.plan.encounters, _encounter_id);
	if (is_undefined(_encounter)) {
		_BladeStagePlanFail("participant spawn preflight", "references an unknown encounter");
	}
	var _participants = _BladeStageEncounterSpawnPlan(
		_registry, _encounter, _anchor_point, _resolver, _runtime
	);
	_BladeStageEncounterRequireCapacity(
		_runtime.identity, array_length(_participants)
	);
	return {
		__blade_stage_encounter_spawn_plan_version: 1,
		node_id: _BladeStagePlanStableId(
			_node_id, "stage_node", "prepared spawn node ID"
		),
		encounter_id: _encounter.id,
		participants: _participants,
	};
}

/// Revalidates a cached spawn plan and mutable capacity without committing it.
function BladeStageEncounterRegistryPreflightPreparedSpawn(
	_registry, _kernel, _runtime, _prepared
) {
	_BladeStageEncounterRegistryRequire(_registry);
	_BladeKernelRequire(_kernel);
	_BladeCombatRuntimeRequire(_runtime);
	if (_runtime.identity != _kernel.identity || !is_undefined(_runtime.active_tick)) {
		_BladeStagePlanFail(
			"prepared participant spawn", "requires the shared identity between ticks"
		);
	}
	_BladeStageEncounterRequirePlane(_registry, _runtime);
	var _validated = _BladeStageEncounterPreparedPlan(
		_registry, _runtime, _prepared
	);
	var _latest = BladeStageEncounterRegistryLatest(
		_registry, _validated.encounter_id
	);
	if (!is_undefined(_latest) && _latest.lifecycle == BladeStageLifecycle.Active) {
		_BladeStagePlanFail("participant spawn", "cannot overlap one owned encounter");
	}
	_BladeStageEncounterRequireCapacity(
		_runtime.identity, array_length(_validated.participants)
	);
	return _validated;
}

/// Commits one cached batch without invoking participant content resolution again.
function BladeStageEncounterRegistrySpawnPrepared(
	_registry, _ports, _kernel, _runtime, _prepared, _tick, _generation
) {
	_BladeStagePortsRequire(_ports);
	var _validated = BladeStageEncounterRegistryPreflightPreparedSpawn(
		_registry, _kernel, _runtime, _prepared
	);
	var _spawn_context = { runtime: _runtime };
	return _BladeStageEncounterCommitPrepared(
		_registry, _ports, _kernel, _validated, _tick, _generation,
		method(_spawn_context, function(_plan, _instance_id, _spawn_tick) {
			BladeCombatRuntimeRegisterActor(
				self.runtime, _instance_id, _plan.spawn_spec.content_id,
				_plan.spawn_spec.faction, _plan.spawn_spec.health,
				_plan.spawn_spec.box,
				_plan.spawn_spec.invulnerable_until_combat_tick,
				_plan.spawn_spec.reward_on_defeat, _plan.spawn_spec.child_spec,
				_spawn_tick.simulation_tick, _spawn_tick.combat_tick
			);
		})
	);
}

/// @func BladeStageEncounterRegistrySpawn(registry, ports, kernel, combat_runtime, encounter_id, anchor_point, resolver, tick, node_id, generation)
/// Preflights a whole participant batch, then allocates and registers it in spawn order.
function BladeStageEncounterRegistrySpawn(
	_registry, _ports, _kernel, _runtime, _encounter_id, _anchor_point,
	_resolver, _tick, _node_id, _generation
) {
	var _prepared = BladeStageEncounterRegistryPrepareSpawn(
		_registry, _kernel, _runtime, _node_id, _encounter_id,
		_anchor_point, _resolver
	);
	return BladeStageEncounterRegistrySpawnPrepared(
		_registry, _ports, _kernel, _runtime, _prepared, _tick, _generation
	);
}

/// Reports whether every owned participant ended through selected combat defeat.
function _BladeStageEncounterAllDefeated(_generation) {
	for (var _index = 0; _index < array_length(_generation.participants); ++_index) {
		var _state = _generation.participants[_index].state;
		if (_state != BladeStageParticipantState.Defeated
			&& _state != BladeStageParticipantState.RetainedHarmless) return false;
	}
	return true;
}

/// Applies one new actor terminal to its exact owned participant, if any.
function _BladeStageEncounterApplyTerminal(_registry, _terminal) {
	if (_terminal.subject_kind != BladeCombatSubjectKind.Actor) return undefined;
	var _owned = _BladeStageEncounterParticipant(_registry, _terminal.subject_id);
	if (is_undefined(_owned)
		|| _owned.participant.state != BladeStageParticipantState.Active) {
		return undefined;
	}
	_owned.participant.terminal_reason = _terminal.reason;
	_owned.participant.terminal_simulation_tick = _terminal.simulation_tick;
	_owned.participant.terminal_combat_tick = _terminal.combat_tick;
	if (_terminal.reason == BladeCombatTerminalReason.Defeat) {
		_owned.participant.state = _owned.participant.defeat_disposition == "retain_harmless"
			? BladeStageParticipantState.RetainedHarmless
			: BladeStageParticipantState.Defeated;
	} else {
		_owned.participant.state = BladeStageParticipantState.Cleaned;
	}
	return _owned.generation;
}

/// Completes each all-defeated generation once after its terminal reports are applied.
function _BladeStageEncounterCompleteReady(_registry, _ports, _tick) {
	var _completed = [];
	for (var _index = 0; _index < array_length(_registry.generations); ++_index) {
		var _generation = _registry.generations[_index];
		if (_generation.lifecycle == BladeStageLifecycle.Active
			&& _BladeStageEncounterAllDefeated(_generation)) {
			_generation.lifecycle = BladeStageLifecycle.Completed;
			_generation.completion_simulation_tick = _tick.simulation_tick;
			_generation.completion_stage_tick = _tick.stage_tick;
			var _encounter = _BladeStagePlanFind(
				_registry.plan.encounters, _generation.encounter_id
			);
			BladeStagePortsEmitEncounterSignal(
				_ports, _encounter.stage_signals.completed.signal_id,
				_encounter.stage_signals.completed.type_id, _encounter.id,
				"encounter_completed", _generation.execution_generation
			);
			array_push(_completed, _BladeStagePlanClone(_generation));
		}
	}
	return _completed;
}

/// Observes each newly committed combat terminal once and emits exact completed signals.
function BladeStageEncounterRegistryObserve(
	_registry, _ports, _runtime, _tick
) {
	_BladeStageEncounterRegistryRequire(_registry);
	_BladeStagePortsRequire(_ports);
	var _combat = BladeCombatRuntimeSnapshot(_runtime);
	var _count = int64(array_length(_combat.terminal_records));
	if (_count < _registry.terminal_cursor) {
		_BladeStagePlanFail("combat terminal cursor", "cannot move backwards");
	}
	for (var _index = real(_registry.terminal_cursor);
		_index < array_length(_combat.terminal_records); ++_index) {
		_BladeStageEncounterApplyTerminal(_registry, _combat.terminal_records[_index]);
	}
	_registry.terminal_cursor = _count;
	return _BladeStageEncounterCompleteReady(_registry, _ports, _tick);
}

/// Marks every still-active participant cleaned during an administrative boundary.
function _BladeStageEncounterAbortActive(_registry, _reason, _tick) {
	for (var _generation_index = 0;
		_generation_index < array_length(_registry.generations); ++_generation_index) {
		var _generation = _registry.generations[_generation_index];
		if (_generation.lifecycle != BladeStageLifecycle.Active) continue;
		_generation.lifecycle = BladeStageLifecycle.Aborted;
		for (var _participant_index = 0;
			_participant_index < array_length(_generation.participants); ++_participant_index) {
			var _participant = _generation.participants[_participant_index];
			if (_participant.state == BladeStageParticipantState.Active) {
				_participant.state = BladeStageParticipantState.Cleaned;
				_participant.terminal_reason = _reason;
				_participant.terminal_simulation_tick = _tick.simulation_tick;
				_participant.terminal_combat_tick = _tick.combat_tick;
			}
		}
	}
}

/// Reconciles committed terminals, then aborts without emitting encounter completion.
function BladeStageEncounterRegistryAbort(_registry, _runtime, _reason, _tick) {
	_BladeStageEncounterRegistryRequire(_registry);
	_BladeCombatRuntimeRequire(_runtime);
	if (_reason != BladeCombatTerminalReason.StageEnd
		&& _reason != BladeCombatTerminalReason.RoomExit
		&& _reason != BladeCombatTerminalReason.RunCompleted
		&& _reason != BladeCombatTerminalReason.RunAborted
		&& _reason != BladeCombatTerminalReason.RunReset
		&& _reason != BladeCombatTerminalReason.RunLoad) {
		_BladeStagePlanFail("encounter abort", "requires an administrative terminal reason");
	}
	var _combat = BladeCombatRuntimeSnapshot(_runtime);
	var _count = int64(array_length(_combat.terminal_records));
	if (_count < _registry.terminal_cursor) {
		_BladeStagePlanFail("combat terminal cursor", "cannot move backwards");
	}
	for (var _terminal_index = real(_registry.terminal_cursor);
		_terminal_index < array_length(_combat.terminal_records); ++_terminal_index) {
		_BladeStageEncounterApplyTerminal(
			_registry, _combat.terminal_records[_terminal_index]
		);
	}
	_registry.terminal_cursor = _count;
	_BladeStageEncounterAbortActive(_registry, _reason, _tick);
}

/// Returns a detached encounter registry view without mutable combat ownership.
function BladeStageEncounterRegistrySnapshot(_registry) {
	_BladeStageEncounterRegistryRequire(_registry);
	return {
		terminal_cursor: _registry.terminal_cursor,
		generations: _BladeStagePlanClone(_registry.generations),
	};
}

/// Encodes every encounter generation and participant in stable append/spawn order.
function BladeStageEncounterRegistryCanonical(_registry) {
	return BladeCanonicalRecord(
		"BSENCOUNTERS1",
		[_BladeStagePlanCanonicalValue(BladeStageEncounterRegistrySnapshot(_registry))]
	);
}
