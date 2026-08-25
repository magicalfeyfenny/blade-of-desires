/// @description Cross-catalog resolution and immutable runtime views for normalized stage plans.

/// Finds a stable-ID record in one flattened array, or returns undefined.
function _BladeStagePlanFind(_records, _id) {
	for (var _index = 0; _index < array_length(_records); ++_index) {
		if (_records[_index].id == _id) return _records[_index];
	}
	return undefined;
}

/// Reports whether one scalar stable ID occurs in a flattened registry.
function _BladeStagePlanContains(_values, _id) {
	for (var _index = 0; _index < array_length(_values); ++_index) {
		if (_values[_index] == _id) return true;
	}
	return false;
}

/// Adds one scalar to a local path-state set when it is not already present.
function _BladeStagePlanSetAdd(_values, _id) {
	if (!_BladeStagePlanContains(_values, _id)) array_push(_values, _id);
}

/// Removes one scalar from a local path-state set when present.
function _BladeStagePlanSetRemove(_values, _id) {
	for (var _index = 0; _index < array_length(_values); ++_index) {
		if (_values[_index] == _id) {
			array_delete(_values, _index, 1);
			return;
		}
	}
}

/// Adds a globally unique definition ID to the constructor's local claim set.
function _BladeStagePlanClaim(_claims, _id, _field) {
	if (_BladeStagePlanContains(_claims, _id)) {
		_BladeStagePlanFail(_field, "duplicates globally defined ID " + _id);
	}
	array_push(_claims, _id);
}

/// Appends detached records while claiming each stable ID exactly once.
function _BladeStagePlanFlattenRecords(_target, _source, _claims, _field) {
	for (var _index = 0; _index < array_length(_source); ++_index) {
		_BladeStagePlanClaim(_claims, _source[_index].id, _field);
		array_push(_target, _BladeStagePlanClone(_source[_index]));
	}
}

/// Appends scalar registry IDs while claiming every definition exactly once.
function _BladeStagePlanFlattenIds(_target, _source, _claims, _field) {
	for (var _index = 0; _index < array_length(_source); ++_index) {
		_BladeStagePlanClaim(_claims, _source[_index], _field);
		array_push(_target, _source[_index]);
	}
}

/// Requires an exact typed reference to resolve to one defined record.
function _BladeStagePlanRequireTyped(
	_records, _id, _type_id, _id_field, _type_field, _field
) {
	var _record = _BladeStagePlanFind(_records, _id);
	if (is_undefined(_record)) {
		_BladeStagePlanFail(_field, "references unknown " + _id_field + " " + _id);
	}
	if (variable_struct_get(_record, _type_field) != _type_id) {
		_BladeStagePlanFail(_field, "does not match the referenced type ID");
	}
	return _record;
}

/// Requires an exact x.y.z nonnegative decimal content version.
function _BladeStagePlanContentVersion(_value) {
	if (!is_string(_value)) _BladeStagePlanFail("product content version", "must be a string");
	var _parts = string_split(_value, ".");
	if (array_length(_parts) != 3) {
		_BladeStagePlanFail("product content version", "must use major.minor.patch");
	}
	for (var _part_index = 0; _part_index < 3; ++_part_index) {
		var _part = _parts[_part_index];
		if (string_length(_part) == 0
			|| (string_length(_part) > 1 && string_char_at(_part, 1) == "0")) {
			_BladeStagePlanFail("product content version", "must use canonical decimals");
		}
		for (var _index = 1; _index <= string_length(_part); ++_index) {
			var _byte = string_ord_at(_part, _index);
			if (_byte < 48 || _byte > 57) {
				_BladeStagePlanFail("product content version", "must use decimal digits");
			}
		}
	}
	return _value;
}

/// Resolves every task, signal, cue, and reciprocal signal-source relationship.
function _BladeStagePlanResolvePorts(_plan) {
	for (var _index = 0; _index < array_length(_plan.task_ports); ++_index) {
		var _port = _plan.task_ports[_index];
		if (!_BladeStagePlanContains(_plan.task_type_ids, _port.type_id)) {
			_BladeStagePlanFail("task port", "references an unknown task type");
		}
		var _signal = _BladeStagePlanRequireTyped(
			_plan.signals, _port.completion_signal.signal_id,
			_port.completion_signal.type_id, "signal ID", "type_id",
			"task port completion signal"
		);
		if (_signal.source.kind != "task_completion"
			|| _signal.source.task_port_id != _port.id) {
			_BladeStagePlanFail("task port completion signal", "is not reciprocal");
		}
	}
	for (var _index = 0; _index < array_length(_plan.signals); ++_index) {
		var _signal = _plan.signals[_index];
		if (!_BladeStagePlanContains(_plan.signal_type_ids, _signal.type_id)) {
			_BladeStagePlanFail("signal", "references an unknown signal type");
		}
		if (_signal.source.kind == "task_completion") {
			var _port = _BladeStagePlanFind(_plan.task_ports, _signal.source.task_port_id);
			if (is_undefined(_port)
				|| _port.completion_signal.signal_id != _signal.id
				|| _port.completion_signal.type_id != _signal.type_id) {
				_BladeStagePlanFail("task completion signal", "is not reciprocal");
			}
		} else if (_signal.source.kind == "encounter_started"
			|| _signal.source.kind == "encounter_completed") {
			if (is_undefined(_BladeStagePlanFind(_plan.encounters, _signal.source.encounter_id))) {
				_BladeStagePlanFail("encounter signal", "references an unknown encounter");
			}
		}
	}
	for (var _index = 0; _index < array_length(_plan.cues); ++_index) {
		if (!_BladeStagePlanContains(_plan.cue_type_ids, _plan.cues[_index].type_id)) {
			_BladeStagePlanFail("cue", "references an unknown cue type");
		}
	}
}

/// Resolves encounter participant kinds and reciprocal started/completed signals.
function _BladeStagePlanResolveEncounters(_plan) {
	for (var _index = 0; _index < array_length(_plan.encounters); ++_index) {
		var _encounter = _plan.encounters[_index];
		for (var _participant_index = 0;
			_participant_index < array_length(_encounter.participants); ++_participant_index) {
			var _participant = _encounter.participants[_participant_index];
			if (!_BladeStagePlanContains(_plan.participant_kind_ids, _participant.kind_id)) {
				_BladeStagePlanFail("encounter participant", "references an unknown kind");
			}
		}
		var _started = _BladeStagePlanRequireTyped(
			_plan.signals, _encounter.stage_signals.started.signal_id,
			_encounter.stage_signals.started.type_id, "signal ID", "type_id",
			"encounter started signal"
		);
		if (_started.source.kind != "encounter_started"
			|| _started.source.encounter_id != _encounter.id) {
			_BladeStagePlanFail("encounter started signal", "is not reciprocal");
		}
		var _completed = _BladeStagePlanRequireTyped(
			_plan.signals, _encounter.stage_signals.completed.signal_id,
			_encounter.stage_signals.completed.type_id, "signal ID", "type_id",
			"encounter completed signal"
		);
		if (_completed.source.kind != "encounter_completed"
			|| _completed.source.encounter_id != _encounter.id) {
			_BladeStagePlanFail("encounter completed signal", "is not reciprocal");
		}
		if (_encounter.stage_signals.started.signal_id
			== _encounter.stage_signals.completed.signal_id) {
			_BladeStagePlanFail(
				"encounter stage signals", "started and completed must differ"
			);
		}
	}
}

/// Finds one node in a selected stage by stable ID.
function BladeStagePlanFindNode(_plan, _node_id) {
	_BladeStagePlanRequire(_plan);
	return _BladeStagePlanFind(_plan.stage.nodes, _node_id);
}

/// Resolves one selected stage's forward graph and every node reference.
function _BladeStagePlanResolveStage(_plan) {
	var _stage = _plan.stage;
	var _active_encounters = [];
	var _spawned_encounters = [];
	var _pending_task_ports = [];
	var _waited_signals = [];
	for (var _anchor_index = 0;
		_anchor_index < array_length(_plan.named_anchors); ++_anchor_index) {
		var _anchor = _plan.named_anchors[_anchor_index];
		if (!BladeCombatPlaneContainsPoint(
			_plan.gameplay_plane, _anchor.x_q10, _anchor.y_q10
		)) {
			_BladeStagePlanFail("named anchor", "lies outside the bound gameplay plane");
		}
	}
	if (_stage.nodes[0].id != _stage.entry_node_id) {
		_BladeStagePlanFail("stage entry", "must be content order zero");
	}
	var _terminal_count = 0;
	for (var _index = 0; _index < array_length(_stage.nodes); ++_index) {
		var _node = _stage.nodes[_index];
		if (_node.kind == "complete") {
			_terminal_count += 1;
			if (_node.id != _stage.terminal_node_id
				|| _index != array_length(_stage.nodes) - 1) {
				_BladeStagePlanFail("stage terminal", "must be the final content node");
			}
			if (array_length(_active_encounters) > 0) {
				_BladeStagePlanFail("stage terminal", "has active encounter ownership");
			}
			if (array_length(_pending_task_ports) > 0) {
				_BladeStagePlanFail("stage terminal", "has pending task requests");
			}
			continue;
		}
		var _next = _BladeStagePlanFind(_stage.nodes, _node.next_node_id);
		if (is_undefined(_next) || _next.content_order <= _node.content_order) {
			_BladeStagePlanFail("stage transition", "must target a later node");
		}
		if (_next.content_order != _node.content_order + 1) {
			_BladeStagePlanFail("stage graph", "contains an unreachable content node");
		}
		switch (_node.kind) {
			case "spawn_encounter":
				var _encounter = _BladeStagePlanFind(_plan.encounters, _node.encounter_id);
				if (is_undefined(_encounter)) {
					_BladeStagePlanFail("spawn encounter node", "references an unknown encounter");
				}
				if (is_undefined(_BladeStagePlanFind(_plan.named_anchors, _node.anchor_id))) {
					_BladeStagePlanFail("spawn encounter node", "references an unknown anchor");
				}
				if (_BladeStagePlanContains(_active_encounters, _node.encounter_id)) {
					_BladeStagePlanFail(
						"spawn encounter node", "overlaps an active owned generation"
					);
				}
				var _point = BladeStagePlanResolveAnchor(
					_plan, _node.anchor_id, _node.local_offset_q10
				);
				for (var _participant_index = 0;
					_participant_index < array_length(_encounter.participants);
					++_participant_index) {
					var _participant = _encounter.participants[_participant_index];
					var _x = _point.x_q10 + _participant.local_offset_q10.x;
					var _y = _point.y_q10 + _participant.local_offset_q10.y;
					if (!BladeCombatPlaneContainsPoint(_plan.gameplay_plane, _x, _y)) {
						_BladeStagePlanFail(
							"spawn encounter node",
							"places participant outside the bound gameplay plane"
						);
					}
				}
				_BladeStagePlanSetAdd(_active_encounters, _node.encounter_id);
				_BladeStagePlanSetAdd(_spawned_encounters, _node.encounter_id);
				break;
			case "wait_encounter_completion":
				if (is_undefined(_BladeStagePlanFind(_plan.encounters, _node.encounter_id))) {
					_BladeStagePlanFail("encounter wait node", "references an unknown encounter");
				}
				if (!_BladeStagePlanContains(_active_encounters, _node.encounter_id)) {
					_BladeStagePlanFail(
						"encounter wait node", "has no active owned generation"
					);
				}
				_BladeStagePlanSetRemove(_active_encounters, _node.encounter_id);
				break;
			case "request_task":
				var _port = _BladeStagePlanRequireTyped(
					_plan.task_ports, _node.task.port_id, _node.task.type_id,
					"port ID", "type_id", "task request node"
				);
				if (_BladeStagePlanContains(_pending_task_ports, _port.id)) {
					_BladeStagePlanFail(
						"task request node", "overlaps a pending request generation"
					);
				}
				_BladeStagePlanSetAdd(_pending_task_ports, _port.id);
				break;
			case "wait_signal":
				var _signal = _BladeStagePlanRequireTyped(
					_plan.signals, _node.signal.signal_id, _node.signal.type_id,
					"signal ID", "type_id", "signal wait node"
				);
				if (_BladeStagePlanContains(_waited_signals, _signal.id)) {
					_BladeStagePlanFail("signal wait node", "consumes one signal twice");
				}
				_BladeStagePlanSetAdd(_waited_signals, _signal.id);
				if (_signal.source.kind == "task_completion") {
					if (!_BladeStagePlanContains(
						_pending_task_ports, _signal.source.task_port_id
					)) {
						_BladeStagePlanFail(
							"signal wait node", "has no pending task producer"
						);
					}
					_BladeStagePlanSetRemove(
						_pending_task_ports, _signal.source.task_port_id
					);
				} else if (_signal.source.kind == "encounter_started"
					|| _signal.source.kind == "encounter_completed") {
					if (!_BladeStagePlanContains(
						_spawned_encounters, _signal.source.encounter_id
					)) {
						_BladeStagePlanFail(
							"signal wait node", "has no prior encounter producer"
						);
					}
					if (_signal.source.kind == "encounter_completed") {
						_BladeStagePlanSetRemove(
							_active_encounters, _signal.source.encounter_id
						);
					}
				}
				break;
			case "emit_presentation_cue":
				_BladeStagePlanRequireTyped(
					_plan.cues, _node.cue.cue_id, _node.cue.type_id,
					"cue ID", "type_id", "presentation cue node"
				);
				break;
		}
	}
	if (_terminal_count != 1) {
		_BladeStagePlanFail("stage terminal", "requires exactly one complete node");
	}
}

/// Rejects values that are not validated immutable stage runtime plans.
function _BladeStagePlanRequire(_plan) {
	if (!is_struct(_plan)
		|| !variable_struct_exists(_plan, "__blade_stage_plan_version")
		|| _plan.__blade_stage_plan_version != 1) {
		_BladeStagePlanFail("plan", "expected a version 1 runtime plan");
	}
	return _plan;
}

/// @func BladeStagePlanCreate(normalized_plan, plan_fingerprint, stage_id, gameplay_plane)
/// Fully validates and detaches a normalized catalog union without touching runtime ownership.
function BladeStagePlanCreate(
	_normalized_plan, _plan_fingerprint, _stage_id, _gameplay_plane
) {
	_BladeStagePlanExactKeys(
		_normalized_plan, ["schema_version", "product_contract", "catalogs"], "root"
	);
	_BladeStagePlanSchemaVersion(_normalized_plan.schema_version, "root.schema_version");
	_BladeStagePlanExactKeys(
		_normalized_plan.product_contract, ["id", "content_version"], "product_contract"
	);
	var _product = {
		id: _BladeStagePlanStableId(
			_normalized_plan.product_contract.id, "contract", "product_contract.id"
		),
		content_version: _BladeStagePlanContentVersion(
			_normalized_plan.product_contract.content_version
		),
	};
	_BladeStagePlanArray(_normalized_plan.catalogs, "catalogs", true);
	var _catalogs = [];
	var _claims = [];
	var _previous_catalog = "";
	var _flat = {
		named_anchors: [], participant_kind_ids: [], task_type_ids: [],
		signal_type_ids: [], cue_type_ids: [], task_ports: [], signals: [],
		cues: [], stages: [], encounters: [],
	};
	for (var _index = 0; _index < array_length(_normalized_plan.catalogs); ++_index) {
		var _catalog = _BladeStagePlanCatalog(
			_normalized_plan.catalogs[_index], "catalogs[" + string(_index) + "]"
		);
		if (_index > 0 && _BladeStagePlanAsciiCompare(_previous_catalog, _catalog.id) >= 0) {
			_BladeStagePlanFail("catalogs", "must be strictly lexical with no duplicates");
		}
		_BladeStagePlanClaim(_claims, _catalog.id, "catalog");
		_BladeStagePlanFlattenRecords(
			_flat.named_anchors, _catalog.named_anchors, _claims, "named anchor"
		);
		_BladeStagePlanFlattenIds(
			_flat.participant_kind_ids, _catalog.participant_kind_ids, _claims, "participant kind"
		);
		_BladeStagePlanFlattenIds(
			_flat.task_type_ids, _catalog.task_type_ids, _claims, "task type"
		);
		_BladeStagePlanFlattenIds(
			_flat.signal_type_ids, _catalog.signal_type_ids, _claims, "signal type"
		);
		_BladeStagePlanFlattenIds(
			_flat.cue_type_ids, _catalog.cue_type_ids, _claims, "cue type"
		);
		_BladeStagePlanFlattenRecords(_flat.task_ports, _catalog.task_ports, _claims, "task port");
		_BladeStagePlanFlattenRecords(_flat.signals, _catalog.signals, _claims, "signal");
		_BladeStagePlanFlattenRecords(_flat.cues, _catalog.cues, _claims, "cue");
		_BladeStagePlanFlattenRecords(_flat.stages, _catalog.stages, _claims, "stage");
		_BladeStagePlanFlattenRecords(_flat.encounters, _catalog.encounters, _claims, "encounter");
		for (var _stage_index = 0; _stage_index < array_length(_catalog.stages); ++_stage_index) {
			var _catalog_stage = _catalog.stages[_stage_index];
			for (var _node_index = 0;
				_node_index < array_length(_catalog_stage.nodes); ++_node_index) {
				_BladeStagePlanClaim(
					_claims, _catalog_stage.nodes[_node_index].id, "stage node"
				);
			}
		}
		for (var _encounter_index = 0;
			_encounter_index < array_length(_catalog.encounters); ++_encounter_index) {
			var _catalog_encounter = _catalog.encounters[_encounter_index];
			for (var _participant_index = 0;
				_participant_index < array_length(_catalog_encounter.participants);
				++_participant_index) {
				_BladeStagePlanClaim(
					_claims, _catalog_encounter.participants[_participant_index].id,
					"encounter participant"
				);
			}
		}
		array_push(_catalogs, _catalog);
		_previous_catalog = _catalog.id;
	}
	var _selected_id = _BladeStagePlanStableId(_stage_id, "stage_schedule", "stage ID");
	var _selected = _BladeStagePlanFind(_flat.stages, _selected_id);
	if (is_undefined(_selected)) _BladeStagePlanFail("stage ID", "is not defined by the plan");
	var _accepted_root = {
		schema_version: 1, product_contract: _product, catalogs: _catalogs,
	};
	var _normalized_canonical = BladeStageNormalizedPlanCanonical(_accepted_root);
	var _validated_fingerprint = _BladeStagePlanFingerprint(_plan_fingerprint);
	var _expected_fingerprint = "sha1:" + BladeCanonicalHashUtf8(
		_normalized_canonical
	);
	if (_validated_fingerprint != _expected_fingerprint) {
		_BladeStagePlanFail(
			"plan fingerprint", "does not match validated normalized plan bytes"
		);
	}
	var _plan = {
		__blade_stage_plan_version: 1,
		plan_fingerprint: _validated_fingerprint,
		product_contract: _product,
		gameplay_plane: BladeCombatPlaneCopy(_gameplay_plane),
		catalogs: _catalogs,
		stage: _BladeStagePlanClone(_selected),
		named_anchors: _flat.named_anchors,
		participant_kind_ids: _flat.participant_kind_ids,
		task_type_ids: _flat.task_type_ids,
		signal_type_ids: _flat.signal_type_ids,
		cue_type_ids: _flat.cue_type_ids,
		task_ports: _flat.task_ports,
		signals: _flat.signals,
		cues: _flat.cues,
		encounters: _flat.encounters,
		normalized_canonical: _normalized_canonical,
	};
	_BladeStagePlanResolvePorts(_plan);
	_BladeStagePlanResolveEncounters(_plan);
	_BladeStagePlanResolveStage(_plan);
	return _plan;
}

/// Resolves one named anchor plus local offset without consulting room or instance state.
function BladeStagePlanResolveAnchor(_plan, _anchor_id, _local_offset_q10) {
	_BladeStagePlanRequire(_plan);
	var _anchor = _BladeStagePlanFind(_plan.named_anchors, _anchor_id);
	if (is_undefined(_anchor)) _BladeStagePlanFail("anchor", "is unknown");
	var _offset = _BladeStagePlanOffset(_local_offset_q10, "local offset");
	return {
		x_q10: _anchor.x_q10 + _offset.x,
		y_q10: _anchor.y_q10 + _offset.y,
	};
}

/// Returns detached normalized plan data suitable for diagnostics and tests.
function BladeStagePlanSnapshot(_plan) {
	_BladeStagePlanRequire(_plan);
	return {
		plan_fingerprint: _plan.plan_fingerprint,
		product_contract: _BladeStagePlanClone(_plan.product_contract),
		gameplay_plane: BladeCombatPlaneCopy(_plan.gameplay_plane),
		stage: _BladeStagePlanClone(_plan.stage),
		named_anchors: _BladeStagePlanClone(_plan.named_anchors),
		participant_kind_ids: _BladeStagePlanClone(_plan.participant_kind_ids),
		task_ports: _BladeStagePlanClone(_plan.task_ports),
		signals: _BladeStagePlanClone(_plan.signals),
		cues: _BladeStagePlanClone(_plan.cues),
		encounters: _BladeStagePlanClone(_plan.encounters),
	};
}

/// Encodes plan identity and complete normalized bytes for deterministic stage ownership.
function BladeStagePlanCanonical(_plan) {
	_BladeStagePlanRequire(_plan);
	return BladeCanonicalRecord("BSPLAN1", [
		_plan.plan_fingerprint,
		_plan.product_contract.id,
		_plan.product_contract.content_version,
		_plan.stage.id,
		_BladeStagePlanCanonicalValue(BladeCombatPlaneCopy(_plan.gameplay_plane)),
		_plan.normalized_canonical,
	]);
}
