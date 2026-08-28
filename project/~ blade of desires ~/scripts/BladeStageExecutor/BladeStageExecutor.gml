/// @description One deterministic executor for a fully prevalidated linear stage schedule.

/// Rejects values that are not version 1 stage executors.
function _BladeStageExecutorRequire(_executor) {
	if (!is_struct(_executor)
		|| !variable_struct_exists(_executor, "__blade_stage_executor_version")
		|| _executor.__blade_stage_executor_version != 1) {
		_BladeStagePlanFail("executor", "expected a version 1 executor");
	}
	_BladeStagePlanRequire(_executor.plan);
	_BladeStagePortsRequire(_executor.ports);
	_BladeStageEncounterRegistryRequire(_executor.encounters);
	_BladeStageEventStreamRequire(_executor.events);
	if (!is_array(_executor.execution_records)
		|| !is_array(_executor.prepared_spawns)
		|| typeof(_executor.runtime_bound) != "bool"
		|| !is_string(_executor.runtime_kind)
		|| (_executor.runtime_kind != "unbound"
			&& _executor.runtime_kind != "combat"
			&& _executor.runtime_kind != "playable")
		|| (!is_undefined(_executor.playable_spawn_callback)
			&& typeof(_executor.playable_spawn_callback) != "method")) {
		_BladeStagePlanFail("executor", "has invalid mutable runtime fields");
	}
	return _executor;
}

/// Finds the cached spawn plan bound to one exact stage node.
function _BladeStageExecutorPreparedSpawn(_executor, _node_id) {
	for (var _index = 0; _index < array_length(_executor.prepared_spawns); ++_index) {
		if (_executor.prepared_spawns[_index].node_id == _node_id) {
			return _executor.prepared_spawns[_index];
		}
	}
	_BladeStagePlanFail("executor", "has no prepared batch for spawn node " + _node_id);
}

/// Validates one clock tick view without retaining caller-owned state.
function _BladeStageExecutorTick(_tick) {
	if (!is_struct(_tick)) _BladeStagePlanFail("stage tick", "must be a struct");
	var _fields = [
		"simulation_tick", "stage_tick", "actor_tick", "boss_tick",
		"combat_tick", "presentation_tick", "domain_mask",
	];
	for (var _index = 0; _index < array_length(_fields); ++_index) {
		if (!variable_struct_exists(_tick, _fields[_index])) {
			_BladeStagePlanFail("stage tick", "is missing " + _fields[_index]);
		}
	}
	return {
		simulation_tick: _BladeStagePlanInteger(
			_tick.simulation_tick, 0, int64("9223372036854775807"), "simulation tick"
		),
		stage_tick: _BladeStagePlanInteger(
			_tick.stage_tick, 0, int64("9223372036854775807"), "stage tick"
		),
		actor_tick: _BladeStagePlanInteger(
			_tick.actor_tick, 0, int64("9223372036854775807"), "actor tick"
		),
		boss_tick: _BladeStagePlanInteger(
			_tick.boss_tick, 0, int64("9223372036854775807"), "boss tick"
		),
		combat_tick: _BladeStagePlanInteger(
			_tick.combat_tick, 0, int64("9223372036854775807"), "combat tick"
		),
		presentation_tick: _BladeStagePlanInteger(
			_tick.presentation_tick, 0, int64("9223372036854775807"), "presentation tick"
		),
		domain_mask: _BladeSimulationClockDomainMask(_tick.domain_mask),
	};
}

/// Finds the mutable execution record for the currently entered node.
function _BladeStageExecutorCurrentRecord(_executor) {
	for (var _index = array_length(_executor.execution_records) - 1;
		_index >= 0; --_index) {
		var _record = _executor.execution_records[_index];
		if (_record.node_id == _executor.current_node_id
			&& _record.execution_generation == _executor.current_generation) {
			return _record;
		}
	}
	_BladeStagePlanFail("executor", "lost the current execution record");
}

/// Enters the current node once and assigns its monotonic stage-local generation.
function _BladeStageExecutorEnter(_executor, _node, _tick) {
	if (_executor.current_generation > 0) return;
	if (_executor.next_generation >= int64("9223372036854775807")) {
		_BladeStagePlanFail("execution generation", "exceeds signed int64 range");
	}
	var _generation = _executor.next_generation;
	_executor.next_generation += int64(1);
	_executor.current_generation = _generation;
	array_push(_executor.execution_records, {
		node_id: _node.id,
		content_order: _node.content_order,
		kind: _node.kind,
		execution_generation: _generation,
		entered_simulation_tick: _tick.simulation_tick,
		entered_stage_tick: _tick.stage_tick,
		completed: false,
		completed_simulation_tick: int64(-1),
		completed_stage_tick: int64(-1),
	});
}

/// Marks the current node complete and advances to its declared successor.
function _BladeStageExecutorMoveNext(_executor, _kernel, _node, _tick) {
	var _record = _BladeStageExecutorCurrentRecord(_executor);
	if (_record.completed) _BladeStagePlanFail("executor", "completed one node twice");
	BladeStageEventStreamCommit(
		_executor.events, _kernel, _node, _executor.current_generation, _tick
	);
	_record.completed = true;
	_record.completed_simulation_tick = _tick.simulation_tick;
	_record.completed_stage_tick = _tick.stage_tick;
	_executor.current_node_id = _node.next_node_id;
	_executor.current_generation = int64(0);
	_executor.wait_until_stage_tick = int64(-1);
	_executor.wait_encounter_generation = int64(0);
}

/// Finds the latest task request capable of producing one completion signal.
function _BladeStageExecutorSignalTaskGeneration(_executor, _signal) {
	for (var _index = array_length(_executor.ports.task_requests) - 1;
		_index >= 0; --_index) {
		var _request = _executor.ports.task_requests[_index];
		if (_request.port_id == _signal.source.task_port_id
			&& _request.completion_signal_id == _signal.id
			&& _request.completion_signal_type_id == _signal.type_id) {
			return _request.execution_generation;
		}
	}
	_BladeStagePlanFail("signal wait", "has no prior owned task request");
}

/// Resolves the exact owned generation that may satisfy the current signal wait.
function _BladeStageExecutorSignalSourceGeneration(_executor, _node) {
	var _signal = _BladeStagePlanFind(_executor.plan.signals, _node.signal.signal_id);
	switch (_signal.source.kind) {
		case "external":
			return _executor.current_generation;
		case "task_completion":
			return _BladeStageExecutorSignalTaskGeneration(_executor, _signal);
		case "encounter_started":
		case "encounter_completed":
			var _encounter = BladeStageEncounterRegistryLatest(
				_executor.encounters, _signal.source.encounter_id
			);
			if (is_undefined(_encounter)) {
				_BladeStagePlanFail("signal wait", "has no prior owned encounter generation");
			}
			return _encounter.execution_generation;
	}
	_BladeStagePlanFail("signal wait", "has an unknown source");
}

/// Processes one wait node and reports whether its successor is now eligible.
function _BladeStageExecutorWait(_executor, _kernel, _node, _tick) {
	if (_executor.wait_until_stage_tick < 0) {
		var _maximum = int64("9223372036854775807");
		if (_tick.stage_tick > _maximum - _node.active_ticks) {
			_BladeStagePlanFail("stage wait", "exceeds stage tick capacity");
		}
		_executor.wait_until_stage_tick = _tick.stage_tick + _node.active_ticks;
	}
	if (_tick.stage_tick < _executor.wait_until_stage_tick) return false;
	_BladeStageExecutorMoveNext(_executor, _kernel, _node, _tick);
	return true;
}

/// Processes one exact owned encounter-completion wait.
function _BladeStageExecutorWaitEncounter(_executor, _kernel, _node, _tick) {
	if (_executor.wait_encounter_generation == 0) {
		var _latest = BladeStageEncounterRegistryLatest(
			_executor.encounters, _node.encounter_id
		);
		if (is_undefined(_latest)) {
			_BladeStagePlanFail("encounter wait", "has no spawned generation");
		}
		_executor.wait_encounter_generation = _latest.execution_generation;
	}
	var _generation = BladeStageEncounterRegistryLatest(
		_executor.encounters, _node.encounter_id
	);
	if (is_undefined(_generation)
		|| _generation.execution_generation != _executor.wait_encounter_generation
		|| _generation.lifecycle != BladeStageLifecycle.Completed) return false;
	_BladeStageExecutorMoveNext(_executor, _kernel, _node, _tick);
	return true;
}

/// Processes one exact typed signal wait in deterministic append order.
function _BladeStageExecutorWaitSignal(_executor, _kernel, _node, _tick) {
	var _source_generation = _BladeStageExecutorSignalSourceGeneration(
		_executor, _node
	);
	if (!BladeStagePortsCanConsumeSignal(
		_executor.ports, _node, _executor.current_generation, _source_generation
	)) return false;
	BladeStageEventStreamPreflight(
		_executor.events, _kernel, _node, _executor.current_generation, _tick
	);
	var _result = BladeStagePortsConsumeSignal(
		_executor.ports, _node, _executor.current_generation, _source_generation
	);
	if (!_result.consumed) return false;
	_BladeStageExecutorMoveNext(_executor, _kernel, _node, _tick);
	return true;
}

/// Executes one immediate node exactly once and moves to its successor.
function _BladeStageExecutorImmediate(
	_executor, _kernel, _runtime, _node, _tick
) {
	BladeStageEventStreamPreflight(
		_executor.events, _kernel, _node, _executor.current_generation, _tick
	);
	switch (_node.kind) {
		case "spawn_encounter":
			if (_executor.runtime_kind == "combat") {
				BladeStageEncounterRegistrySpawnPrepared(
					_executor.encounters, _executor.ports, _kernel, _runtime,
					_BladeStageExecutorPreparedSpawn(_executor, _node.id),
					_tick, _executor.current_generation
				);
			} else {
				BladeStageEncounterRegistrySpawnPlayablePrepared(
					_executor.encounters, _executor.ports, _kernel,
					_BladeStageExecutorPreparedSpawn(_executor, _node.id),
					_tick, _executor.current_generation,
					_executor.playable_spawn_callback
				);
			}
			break;
		case "request_task":
			BladeStagePortsEmitTask(
				_executor.ports, _node.id, _executor.current_generation,
				_node.task.port_id, _node.task.type_id
			);
			break;
		case "emit_presentation_cue":
			BladeStagePortsEmitCue(
				_executor.ports, _node.id, _executor.current_generation,
				_node.cue.cue_id, _node.cue.type_id
			);
			break;
		default:
			_BladeStagePlanFail("executor", "expected an immediate node");
	}
	_BladeStageExecutorMoveNext(_executor, _kernel, _node, _tick);
}

/// Marks the explicit terminal node and executor complete once.
function _BladeStageExecutorComplete(_executor, _kernel, _node, _tick) {
	var _record = _BladeStageExecutorCurrentRecord(_executor);
	BladeStageEventStreamCommit(
		_executor.events, _kernel, _node, _executor.current_generation, _tick
	);
	_record.completed = true;
	_record.completed_simulation_tick = _tick.simulation_tick;
	_record.completed_stage_tick = _tick.stage_tick;
	_executor.lifecycle = BladeStageLifecycle.Completed;
	_executor.completion_simulation_tick = _tick.simulation_tick;
	_executor.completion_stage_tick = _tick.stage_tick;
}

/// @func BladeStageExecutorCreate(normalized_plan, plan_fingerprint, stage_id, participant_spec_resolver, gameplay_plane)
/// Fully preflights decoded content while leaving kernel IDs, RNG, events, and ports untouched.
function BladeStageExecutorCreate(
	_normalized_plan, _plan_fingerprint, _stage_id, _participant_spec_resolver,
	_gameplay_plane
) {
	var _plan = BladeStagePlanCreate(
		_normalized_plan, _plan_fingerprint, _stage_id, _gameplay_plane
	);
	if (typeof(_participant_spec_resolver) != "method") {
		_BladeStagePlanFail("participant resolver", "must be a method");
	}
	return {
		__blade_stage_executor_version: 1,
		plan: _plan,
		participant_spec_resolver: _participant_spec_resolver,
		ports: BladeStagePortsCreate(_plan),
		encounters: BladeStageEncounterRegistryCreate(_plan),
		events: BladeStageEventStreamCreate(_plan),
		runtime_bound: false,
		runtime_kind: "unbound",
		bound_identity: undefined,
		playable_spawn_callback: undefined,
		prepared_spawns: [],
		lifecycle: BladeStageLifecycle.Active,
		current_node_id: _plan.stage.entry_node_id,
		current_generation: int64(0),
		next_generation: int64(1),
		wait_until_stage_tick: int64(-1),
		wait_encounter_generation: int64(0),
		last_stage_tick: int64(0),
		last_simulation_tick: int64(0),
		completion_simulation_tick: int64(-1),
		completion_stage_tick: int64(-1),
		execution_records: [],
	};
}

/// Requires an attach-time plane to equal the plan's authoritative geometry binding.
function BladeStageExecutorRequireGameplayPlane(_executor, _gameplay_plane) {
	_BladeStageExecutorRequire(_executor);
	var _expected = BladeCombatPlaneCopy(_executor.plan.gameplay_plane);
	var _actual = BladeCombatPlaneCopy(_gameplay_plane);
	if (_actual.left_q10 != _expected.left_q10
		|| _actual.top_q10 != _expected.top_q10
		|| _actual.right_q10_exclusive != _expected.right_q10_exclusive
		|| _actual.bottom_q10_exclusive != _expected.bottom_q10_exclusive) {
		_BladeStagePlanFail("executor plane", "does not match the preflight binding");
	}
	return true;
}

/// Resolves every selected-stage participant spec before any schedule can advance.
function BladeStageExecutorBindRuntime(_executor, _kernel, _runtime) {
	_BladeStageExecutorRequire(_executor);
	_BladeKernelRequire(_kernel);
	_BladeCombatRuntimeRequire(_runtime);
	if (_runtime.identity != _kernel.identity || !is_undefined(_runtime.active_tick)) {
		_BladeStagePlanFail("executor binding", "requires shared identity between ticks");
	}
	BladeStageExecutorRequireGameplayPlane(_executor, _runtime.plane);
	if (_executor.runtime_bound) {
		if (_executor.runtime_kind != "combat"
			|| _executor.bound_identity != _kernel.identity) {
			_BladeStagePlanFail(
				"executor binding", "cannot change its runtime kind or run identity"
			);
		}
		return BladeStageExecutorSnapshot(_executor);
	}
	var _prepared = [];
	for (var _index = 0;
		_index < array_length(_executor.plan.stage.nodes); ++_index) {
		var _node = _executor.plan.stage.nodes[_index];
		if (_node.kind != "spawn_encounter") continue;
		var _anchor = BladeStagePlanResolveAnchor(
			_executor.plan, _node.anchor_id, _node.local_offset_q10
		);
		array_push(_prepared, BladeStageEncounterRegistryPrepareSpawn(
			_executor.encounters, _kernel, _runtime, _node.id,
			_node.encounter_id, _anchor, _executor.participant_spec_resolver
		));
	}
	_executor.prepared_spawns = _prepared;
	_executor.bound_identity = _kernel.identity;
	_executor.runtime_kind = "combat";
	_executor.runtime_bound = true;
	return BladeStageExecutorSnapshot(_executor);
}

/// Binds content-only spawn specs and one real-object creation callback without a combat runtime.
function BladeStageExecutorBindPlayable(_executor, _kernel, _spawn_callback) {
	_BladeStageExecutorRequire(_executor);
	_BladeKernelRequire(_kernel);
	if (typeof(_spawn_callback) != "method") {
		_BladeStagePlanFail("playable executor binding", "requires a spawn callback");
	}
	if (_executor.runtime_bound) {
		if (_executor.runtime_kind != "playable"
			|| _executor.bound_identity != _kernel.identity
			|| _executor.playable_spawn_callback != _spawn_callback) {
			_BladeStagePlanFail(
				"playable executor binding",
				"cannot change its callback, runtime kind, or run identity"
			);
		}
		return BladeStageExecutorSnapshot(_executor);
	}
	var _prepared = [];
	for (var _index = 0;
		_index < array_length(_executor.plan.stage.nodes); ++_index) {
		var _node = _executor.plan.stage.nodes[_index];
		if (_node.kind != "spawn_encounter") continue;
		var _anchor = BladeStagePlanResolveAnchor(
			_executor.plan, _node.anchor_id, _node.local_offset_q10
		);
		array_push(_prepared, BladeStageEncounterRegistryPreparePlayableSpawn(
			_executor.encounters, _kernel, _node.id, _node.encounter_id,
			_anchor, _executor.participant_spec_resolver
		));
	}
	_executor.prepared_spawns = _prepared;
	_executor.bound_identity = _kernel.identity;
	_executor.playable_spawn_callback = _spawn_callback;
	_executor.runtime_kind = "playable";
	_executor.runtime_bound = true;
	return BladeStageExecutorSnapshot(_executor);
}

/// Rebuilds fresh ownership over the same immutable plan binding and resolver.
function BladeStageExecutorRestart(_executor) {
	_BladeStageExecutorRequire(_executor);
	var _normalized = {
		schema_version: 1,
		product_contract: _BladeStagePlanClone(_executor.plan.product_contract),
		catalogs: _BladeStagePlanClone(_executor.plan.catalogs),
	};
	var _restart = BladeStageExecutorCreate(
		_normalized, _executor.plan.plan_fingerprint, _executor.plan.stage.id,
		_executor.participant_spec_resolver, _executor.plan.gameplay_plane
	);
	return _restart;
}

/// Advances the shared schedule once after its public runtime-specific boundary validates.
function _BladeStageExecutorAdvanceBound(_executor, _kernel, _runtime, _tick) {
	_BladeStageExecutorRequire(_executor);
	_BladeKernelRequire(_kernel);
	if (!_executor.runtime_bound || _executor.bound_identity != _kernel.identity) {
		_BladeStagePlanFail("executor", "must bind all runtime spawn specs before advance");
	}
	var _validated_tick = _BladeStageExecutorTick(_tick);
	if ((_validated_tick.domain_mask & BladeClockDomain.Stage) == 0) {
		return BladeStageExecutorSnapshot(_executor);
	}
	if (_executor.lifecycle != BladeStageLifecycle.Active) {
		return BladeStageExecutorSnapshot(_executor);
	}
	if (_validated_tick.stage_tick == _executor.last_stage_tick
		&& _executor.last_stage_tick > 0) {
		return BladeStageExecutorSnapshot(_executor);
	}
	if (_validated_tick.stage_tick <= _executor.last_stage_tick
		|| (_executor.last_stage_tick > 0
			&& _validated_tick.stage_tick != _executor.last_stage_tick + 1)) {
		_BladeStagePlanFail("stage tick", "must advance exactly once in eligible order");
	}
	if (_validated_tick.simulation_tick <= _executor.last_simulation_tick) {
		_BladeStagePlanFail("simulation tick", "must advance on each eligible Stage tick");
	}
	if (_executor.runtime_kind == "combat") {
		BladeStageEncounterRegistryObserve(
			_executor.encounters, _executor.ports, _runtime, _validated_tick
		);
	} else {
		BladeStageEncounterRegistryObservePlayable(
			_executor.encounters, _executor.ports, _validated_tick
		);
	}
	var _budget = array_length(_executor.plan.stage.nodes) + 1;
	while (_executor.lifecycle == BladeStageLifecycle.Active && _budget > 0) {
		var _node = BladeStagePlanFindNode(
			_executor.plan, _executor.current_node_id
		);
		if (is_undefined(_node)) _BladeStagePlanFail("executor", "lost its current node");
		if (_node.kind == "spawn_encounter") {
			if (_executor.runtime_kind == "combat") {
				BladeStageEncounterRegistryPreflightPreparedSpawn(
					_executor.encounters, _kernel, _runtime,
					_BladeStageExecutorPreparedSpawn(_executor, _node.id)
				);
			} else {
				BladeStageEncounterRegistryPreflightPlayableSpawn(
					_executor.encounters, _kernel,
					_BladeStageExecutorPreparedSpawn(_executor, _node.id)
				);
			}
		}
		_BladeStageExecutorEnter(_executor, _node, _validated_tick);
		var _continue = false;
		switch (_node.kind) {
			case "wait":
				_continue = _BladeStageExecutorWait(
					_executor, _kernel, _node, _validated_tick
				);
				break;
			case "wait_encounter_completion":
				_continue = _BladeStageExecutorWaitEncounter(
					_executor, _kernel, _node, _validated_tick
				);
				break;
			case "wait_signal":
				_continue = _BladeStageExecutorWaitSignal(
					_executor, _kernel, _node, _validated_tick
				);
				break;
			case "spawn_encounter":
			case "request_task":
			case "emit_presentation_cue":
				_BladeStageExecutorImmediate(
					_executor, _kernel, _runtime, _node, _validated_tick
				);
				_continue = true;
				break;
			case "complete":
				_BladeStageExecutorComplete(
					_executor, _kernel, _node, _validated_tick
				);
				break;
		}
		if (!_continue) break;
		_budget -= 1;
	}
	if (_budget <= 0 && _executor.lifecycle == BladeStageLifecycle.Active) {
		_BladeStagePlanFail("executor", "exceeded the validated linear node budget");
	}
	_executor.last_stage_tick = _validated_tick.stage_tick;
	_executor.last_simulation_tick = _validated_tick.simulation_tick;
	return BladeStageExecutorSnapshot(_executor);
}

/// @func BladeStageExecutorAdvance(executor, kernel, combat_runtime, tick)
/// Advances the legacy combat-backed schedule on one new eligible Stage tick.
function BladeStageExecutorAdvance(_executor, _kernel, _runtime, _tick) {
	_BladeStageExecutorRequire(_executor);
	_BladeKernelRequire(_kernel);
	_BladeCombatRuntimeRequire(_runtime);
	if (_executor.runtime_kind != "combat"
		|| _runtime.identity != _kernel.identity) {
		_BladeStagePlanFail(
			"executor", "requires its combat runtime and shared kernel identity"
		);
	}
	BladeStageExecutorRequireGameplayPlane(_executor, _runtime.plane);
	return _BladeStageExecutorAdvanceBound(
		_executor, _kernel, _runtime, _tick
	);
}

/// Advances the production object-backed schedule on one new eligible Stage tick.
function BladeStageExecutorAdvancePlayable(_executor, _kernel, _tick) {
	_BladeStageExecutorRequire(_executor);
	_BladeKernelRequire(_kernel);
	if (_executor.runtime_kind != "playable") {
		_BladeStagePlanFail("playable executor", "is not bound to playable objects");
	}
	return _BladeStageExecutorAdvanceBound(
		_executor, _kernel, undefined, _tick
	);
}

/// Accepts one real enemy defeat from the bound kernel simulation callback.
function BladeStageExecutorReportPlayableDefeat(
	_executor, _kernel, _instance_id, _tick
) {
	_BladeStageExecutorRequire(_executor);
	_BladeKernelRequire(_kernel);
	if (_executor.runtime_kind != "playable"
		|| _executor.bound_identity != _kernel.identity) {
		_BladeStagePlanFail(
			"playable executor defeat", "requires its bound kernel identity"
		);
	}
	if (_executor.lifecycle != BladeStageLifecycle.Active) {
		return { accepted: false };
	}
	return BladeStageEncounterRegistryReportPlayableDefeat(
		_executor.encounters, _instance_id, _BladeStageExecutorTick(_tick)
	);
}

/// Accepts one completion only while the exact typed signal wait is current.
function BladeStageExecutorSubmitTaskCompletion(
	_executor, _port_id, _type_id, _signal_id, _signal_type_id,
	_request_generation
) {
	_BladeStageExecutorRequire(_executor);
	if (_executor.lifecycle != BladeStageLifecycle.Active
		|| _executor.current_generation == 0) return { accepted: false };
	var _node = BladeStagePlanFindNode(_executor.plan, _executor.current_node_id);
	return BladeStagePortsSubmitTaskCompletion(
		_executor.ports, _node, _executor.current_generation,
		_port_id, _type_id, _signal_id, _signal_type_id, _request_generation
	);
}

/// Accepts one external signal only for the exact current wait generation.
function BladeStageExecutorSubmitExternalSignal(
	_executor, _signal_id, _type_id, _wait_generation
) {
	_BladeStageExecutorRequire(_executor);
	if (_executor.lifecycle != BladeStageLifecycle.Active
		|| _executor.current_generation == 0) return { accepted: false };
	var _node = BladeStagePlanFindNode(_executor.plan, _executor.current_node_id);
	return BladeStagePortsSubmitExternalSignal(
		_executor.ports, _node, _executor.current_generation,
		_signal_id, _type_id, _wait_generation
	);
}

/// Reconciles combat provenance, then aborts without advancing or emitting completion.
function BladeStageExecutorAbort(_executor, _runtime, _reason, _tick) {
	_BladeStageExecutorRequire(_executor);
	_BladeCombatRuntimeRequire(_runtime);
	if (!_executor.runtime_bound || _executor.runtime_kind != "combat"
		|| _executor.bound_identity != _runtime.identity) {
		_BladeStagePlanFail("executor abort", "requires its bound combat runtime");
	}
	var _validated_tick = _BladeStageExecutorTick(_tick);
	if (_executor.lifecycle != BladeStageLifecycle.Active) {
		return BladeStageExecutorSnapshot(_executor);
	}
	BladeStageEncounterRegistryAbort(
		_executor.encounters, _runtime, _reason, _validated_tick
	);
	_executor.lifecycle = BladeStageLifecycle.Aborted;
	_executor.completion_simulation_tick = _validated_tick.simulation_tick;
	_executor.completion_stage_tick = _validated_tick.stage_tick;
	return BladeStageExecutorSnapshot(_executor);
}

/// Aborts playable stage ownership without converting object cleanup into encounter defeat.
function BladeStageExecutorAbortPlayable(_executor, _reason, _tick) {
	_BladeStageExecutorRequire(_executor);
	if (!_executor.runtime_bound || _executor.runtime_kind != "playable") {
		_BladeStagePlanFail("playable executor abort", "requires a playable binding");
	}
	var _validated_tick = _BladeStageExecutorTick(_tick);
	if (_executor.lifecycle != BladeStageLifecycle.Active) {
		return BladeStageExecutorSnapshot(_executor);
	}
	BladeStageEncounterRegistryAbortPlayable(
		_executor.encounters, _reason, _validated_tick
	);
	_executor.lifecycle = BladeStageLifecycle.Aborted;
	_executor.completion_simulation_tick = _validated_tick.simulation_tick;
	_executor.completion_stage_tick = _validated_tick.stage_tick;
	return BladeStageExecutorSnapshot(_executor);
}

/// Returns a detached complete view of deterministic stage ownership and outboxes.
function BladeStageExecutorSnapshot(_executor) {
	_BladeStageExecutorRequire(_executor);
	return {
		plan_fingerprint: _executor.plan.plan_fingerprint,
		stage_id: _executor.plan.stage.id,
		lifecycle: _executor.lifecycle,
		current_node_id: _executor.current_node_id,
		current_generation: _executor.current_generation,
		next_generation: _executor.next_generation,
		wait_until_stage_tick: _executor.wait_until_stage_tick,
		wait_encounter_generation: _executor.wait_encounter_generation,
		last_stage_tick: _executor.last_stage_tick,
		last_simulation_tick: _executor.last_simulation_tick,
		completion_simulation_tick: _executor.completion_simulation_tick,
		completion_stage_tick: _executor.completion_stage_tick,
		runtime_bound: _executor.runtime_bound,
		prepared_spawns: _BladeStagePlanClone(_executor.prepared_spawns),
		execution_records: _BladeStagePlanClone(_executor.execution_records),
		events: BladeStageEventStreamSnapshot(_executor.events),
		ports: BladeStagePortsSnapshot(_executor.ports),
		encounters: BladeStageEncounterRegistrySnapshot(_executor.encounters),
	};
}

/// Encodes plan identity plus all mutable stage ownership in deterministic order.
function BladeStageExecutorCanonical(_executor) {
	_BladeStageExecutorRequire(_executor);
	return BladeCanonicalRecord("BSEXECUTOR1", [
		BladeStagePlanCanonical(_executor.plan),
		_BladeStagePlanCanonicalValue(BladeStageExecutorSnapshot(_executor)),
	]);
}

/// Returns the SHA-1 hash of one executor's complete canonical state.
function BladeStageExecutorHash(_executor) {
	return BladeCanonicalHashUtf8(BladeStageExecutorCanonical(_executor));
}
