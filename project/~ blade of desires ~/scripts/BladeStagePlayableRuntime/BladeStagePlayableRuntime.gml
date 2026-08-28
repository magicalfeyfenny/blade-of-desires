/// @description Small bridge from deterministic stage ownership to ordinary playable objects.

/// Validates the content-only participant specification used by playable objects.
function _BladeStagePlayableSpawnSpec(_identity, _value, _field) {
	_BladeStagePlanExactKeys(_value, ["content_id"], _field);
	return {
		content_id: BladeRunIdentityRequireContent(_identity, _value.content_id),
	};
}

/// Resolves every playable participant before the stage can allocate or create anything.
function _BladeStagePlayableSpawnPlan(
	_registry, _encounter, _anchor_point, _resolver, _identity
) {
	if (typeof(_resolver) != "method") {
		_BladeStagePlanFail("playable participant resolver", "must be a method");
	}
	var _plans = [];
	for (var _index = 0; _index < array_length(_encounter.participants); ++_index) {
		var _participant = _encounter.participants[_index];
		var _x = _BladeStagePlanInteger(
			_anchor_point.x_q10 + _participant.local_offset_q10.x,
			int64("-2147483648"), int64("2147483647"),
			"playable participant x_q10"
		);
		var _y = _BladeStagePlanInteger(
			_anchor_point.y_q10 + _participant.local_offset_q10.y,
			int64("-2147483648"), int64("2147483647"),
			"playable participant y_q10"
		);
		var _resolved = _resolver(
			_participant.kind_id, _participant.id, _x, _y
		);
		array_push(_plans, {
			participant: _BladeStagePlanClone(_participant),
			x_q10: _x,
			y_q10: _y,
			spawn_spec: _BladeStagePlayableSpawnSpec(
				_identity, _resolved, "playable participant spawn specification"
			),
		});
	}
	return _plans;
}

/// Revalidates one cached playable batch without invoking its content resolver again.
function _BladeStagePlayablePreparedPlan(_registry, _identity, _prepared) {
	_BladeStagePlanExactKeys(
		_prepared,
		["__blade_stage_playable_spawn_plan_version", "node_id", "encounter_id", "participants"],
		"prepared playable participant spawn"
	);
	if (_prepared.__blade_stage_playable_spawn_plan_version != 1) {
		_BladeStagePlanFail("prepared playable participant spawn", "has the wrong version");
	}
	var _encounter = _BladeStagePlanFind(
		_registry.plan.encounters, _prepared.encounter_id
	);
	if (is_undefined(_encounter)
		|| array_length(_prepared.participants)
			!= array_length(_encounter.participants)) {
		_BladeStagePlanFail(
			"prepared playable participant spawn", "does not match its encounter"
		);
	}
	var _participants = [];
	for (var _index = 0; _index < array_length(_encounter.participants); ++_index) {
		var _value = _prepared.participants[_index];
		_BladeStagePlanExactKeys(
			_value, ["participant", "x_q10", "y_q10", "spawn_spec"],
			"prepared playable participant"
		);
		var _expected = _encounter.participants[_index];
		if (!is_struct(_value.participant)
			|| _value.participant.id != _expected.id
			|| _value.participant.kind_id != _expected.kind_id
			|| _value.participant.spawn_order != _expected.spawn_order
			|| _value.participant.defeat_disposition != _expected.defeat_disposition) {
			_BladeStagePlanFail(
				"prepared playable participant", "does not match spawn order"
			);
		}
		var _x = _BladeStagePlanInteger(
			_value.x_q10, int64("-2147483648"), int64("2147483647"),
			"prepared playable participant x_q10"
		);
		var _y = _BladeStagePlanInteger(
			_value.y_q10, int64("-2147483648"), int64("2147483647"),
			"prepared playable participant y_q10"
		);
		if (!BladeCombatPlaneContainsPoint(_registry.plan.gameplay_plane, _x, _y)) {
			_BladeStagePlanFail(
				"prepared playable participant", "lies outside the gameplay plane"
			);
		}
		array_push(_participants, {
			participant: _BladeStagePlanClone(_expected),
			x_q10: _x,
			y_q10: _y,
			spawn_spec: _BladeStagePlayableSpawnSpec(
				_identity, _value.spawn_spec,
				"prepared playable participant spawn specification"
			),
		});
	}
	return {
		__blade_stage_playable_spawn_plan_version: 1,
		node_id: _BladeStagePlanStableId(
			_prepared.node_id, "stage_node", "prepared playable spawn node ID"
		),
		encounter_id: _encounter.id,
		participants: _participants,
	};
}

/// Resolves one whole playable spawn node without allocating IDs or creating objects.
function BladeStageEncounterRegistryPreparePlayableSpawn(
	_registry, _kernel, _node_id, _encounter_id, _anchor_point, _resolver
) {
	_BladeStageEncounterRegistryRequire(_registry);
	_BladeKernelRequire(_kernel);
	var _encounter = _BladeStagePlanFind(_registry.plan.encounters, _encounter_id);
	if (is_undefined(_encounter)) {
		_BladeStagePlanFail(
			"playable participant spawn preflight", "references an unknown encounter"
		);
	}
	var _participants = _BladeStagePlayableSpawnPlan(
		_registry, _encounter, _anchor_point, _resolver, _kernel.identity
	);
	_BladeStageEncounterRequireCapacity(
		_kernel.identity, array_length(_participants)
	);
	return {
		__blade_stage_playable_spawn_plan_version: 1,
		node_id: _BladeStagePlanStableId(
			_node_id, "stage_node", "prepared playable spawn node ID"
		),
		encounter_id: _encounter.id,
		participants: _participants,
	};
}

/// Revalidates a cached playable batch and current ID capacity before creation.
function BladeStageEncounterRegistryPreflightPlayableSpawn(
	_registry, _kernel, _prepared
) {
	_BladeStageEncounterRegistryRequire(_registry);
	_BladeKernelRequire(_kernel);
	var _validated = _BladeStagePlayablePreparedPlan(
		_registry, _kernel.identity, _prepared
	);
	var _latest = BladeStageEncounterRegistryLatest(
		_registry, _validated.encounter_id
	);
	if (!is_undefined(_latest) && _latest.lifecycle == BladeStageLifecycle.Active) {
		_BladeStagePlanFail(
			"playable participant spawn", "cannot overlap one owned encounter"
		);
	}
	_BladeStageEncounterRequireCapacity(
		_kernel.identity, array_length(_validated.participants)
	);
	return _validated;
}

/// Creates one prepared batch as real gameplay objects and registers stage ownership.
function BladeStageEncounterRegistrySpawnPlayablePrepared(
	_registry, _ports, _kernel, _prepared, _tick, _generation, _spawn_callback
) {
	_BladeStagePortsRequire(_ports);
	if (typeof(_spawn_callback) != "method") {
		_BladeStagePlanFail("playable participant spawn", "requires a spawn callback");
	}
	var _validated = BladeStageEncounterRegistryPreflightPlayableSpawn(
		_registry, _kernel, _prepared
	);
	var _validated_generation = _BladeStagePortsGeneration(
		_generation, "playable encounter generation"
	);
	var _context = {
		callback: _spawn_callback,
		encounter_id: _validated.encounter_id,
		execution_generation: _validated_generation,
	};
	return _BladeStageEncounterCommitPrepared(
		_registry, _ports, _kernel, _validated, _tick, _validated_generation,
		method(_context, function(_plan, _instance_id, _spawn_tick) {
			var _created = self.callback({
				encounter_id: self.encounter_id,
				execution_generation: self.execution_generation,
				participant_id: _plan.participant.id,
				participant_kind_id: _plan.participant.kind_id,
				spawn_order: _plan.participant.spawn_order,
				instance_id: _instance_id,
				content_id: _plan.spawn_spec.content_id,
				x_q10: _plan.x_q10,
				y_q10: _plan.y_q10,
				defeat_disposition: _plan.participant.defeat_disposition,
				simulation_tick: _spawn_tick.simulation_tick,
				stage_tick: _spawn_tick.stage_tick,
			});
			if (!is_bool(_created) || !_created) {
				_BladeStagePlanFail(
					"playable participant spawn", "callback did not confirm creation"
				);
			}
		})
	);
}

/// Reports one real object's defeat to its exact active stage participant.
function BladeStageEncounterRegistryReportPlayableDefeat(
	_registry, _instance_id, _tick
) {
	_BladeStageEncounterRegistryRequire(_registry);
	var _owned = _BladeStageEncounterApplyTerminal(_registry, {
		subject_kind: BladeCombatSubjectKind.Actor,
		subject_id: _instance_id,
		reason: BladeCombatTerminalReason.Defeat,
		simulation_tick: _tick.simulation_tick,
		combat_tick: _tick.combat_tick,
	});
	return { accepted: !is_undefined(_owned) };
}

/// Emits completion only after all directly reported defeats satisfy one generation.
function BladeStageEncounterRegistryObservePlayable(_registry, _ports, _tick) {
	_BladeStageEncounterRegistryRequire(_registry);
	_BladeStagePortsRequire(_ports);
	return _BladeStageEncounterCompleteReady(_registry, _ports, _tick);
}

/// Aborts playable encounter ownership without treating cleanup as a defeat.
function BladeStageEncounterRegistryAbortPlayable(_registry, _reason, _tick) {
	_BladeStageEncounterRegistryRequire(_registry);
	if (_reason != BladeCombatTerminalReason.StageEnd
		&& _reason != BladeCombatTerminalReason.RoomExit
		&& _reason != BladeCombatTerminalReason.RunCompleted
		&& _reason != BladeCombatTerminalReason.RunAborted
		&& _reason != BladeCombatTerminalReason.RunReset
		&& _reason != BladeCombatTerminalReason.RunLoad) {
		_BladeStagePlanFail(
			"playable encounter abort", "requires an administrative terminal reason"
		);
	}
	_BladeStageEncounterAbortActive(_registry, _reason, _tick);
}
