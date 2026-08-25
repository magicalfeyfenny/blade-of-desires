/// @description Exact structural validation for normalized stage catalog records.

/// Validates one q10 offset object and returns a detached copy.
function _BladeStagePlanOffset(_value, _field) {
	_BladeStagePlanExactKeys(_value, ["x", "y"], _field);
	return {
		x: _BladeStagePlanInteger(
			_value.x, -1000000, 1000000, _field + ".x"
		),
		y: _BladeStagePlanInteger(
			_value.y, -1000000, 1000000, _field + ".y"
		),
	};
}

/// Validates one exact stable ID and type ID reference pair.
function _BladeStagePlanTypedReference(
	_value, _id_key, _id_prefix, _type_prefix, _field
) {
	_BladeStagePlanExactKeys(_value, [_id_key, "type_id"], _field);
	var _copy = { type_id: _BladeStagePlanStableId(
		_value.type_id, _type_prefix, _field + ".type_id"
	) };
	variable_struct_set(
		_copy, _id_key,
		_BladeStagePlanStableId(
			variable_struct_get(_value, _id_key), _id_prefix, _field + "." + _id_key
		)
	);
	return _copy;
}

/// Validates a lexical stable-ID registry with no duplicates.
function _BladeStagePlanIdRegistry(_values, _prefix, _field) {
	_BladeStagePlanArray(_values, _field);
	var _copy = [];
	var _previous = "";
	for (var _index = 0; _index < array_length(_values); ++_index) {
		var _id = _BladeStagePlanStableId(
			_values[_index], _prefix, _field + "[" + string(_index) + "]"
		);
		if (_index > 0 && _BladeStagePlanAsciiCompare(_previous, _id) >= 0) {
			_BladeStagePlanFail(_field, "must be strictly lexical with no duplicates");
		}
		array_push(_copy, _id);
		_previous = _id;
	}
	return _copy;
}

/// Validates one normalized named anchor.
function _BladeStagePlanAnchor(_value, _field) {
	_BladeStagePlanExactKeys(
		_value, ["schema_version", "id", "display_name", "x_q10", "y_q10"], _field
	);
	return {
		schema_version: _BladeStagePlanSchemaVersion(_value.schema_version, _field + ".schema_version"),
		id: _BladeStagePlanStableId(_value.id, "anchor", _field + ".id"),
		display_name: _BladeStagePlanDisplayName(_value.display_name, _field + ".display_name"),
		x_q10: _BladeStagePlanInteger(
			_value.x_q10, int64("-2147483648"), int64("2147483647"), _field + ".x_q10"
		),
		y_q10: _BladeStagePlanInteger(
			_value.y_q10, int64("-2147483648"), int64("2147483647"), _field + ".y_q10"
		),
	};
}

/// Validates one normalized typed task port and its reciprocal completion signal.
function _BladeStagePlanTaskPort(_value, _field) {
	_BladeStagePlanExactKeys(
		_value, ["schema_version", "id", "display_name", "type_id", "completion_signal"],
		_field
	);
	return {
		schema_version: _BladeStagePlanSchemaVersion(_value.schema_version, _field + ".schema_version"),
		id: _BladeStagePlanStableId(_value.id, "task_port", _field + ".id"),
		display_name: _BladeStagePlanDisplayName(_value.display_name, _field + ".display_name"),
		type_id: _BladeStagePlanStableId(_value.type_id, "task_type", _field + ".type_id"),
		completion_signal: _BladeStagePlanTypedReference(
			_value.completion_signal, "signal_id", "signal", "signal_type",
			_field + ".completion_signal"
		),
	};
}

/// Validates one normalized signal source with explicit null expansion.
function _BladeStagePlanSignalSource(_value, _field) {
	_BladeStagePlanExactKeys(_value, ["kind", "task_port_id", "encounter_id"], _field);
	if (!is_string(_value.kind)) _BladeStagePlanFail(_field + ".kind", "must be a string");
	var _task_port_id = _value.task_port_id;
	var _encounter_id = _value.encounter_id;
	switch (_value.kind) {
		case "external":
			if (!is_undefined(_task_port_id) || !is_undefined(_encounter_id)) {
				_BladeStagePlanFail(_field, "external source requires null references");
			}
			break;
		case "task_completion":
			_task_port_id = _BladeStagePlanStableId(
				_task_port_id, "task_port", _field + ".task_port_id"
			);
			if (!is_undefined(_encounter_id)) {
				_BladeStagePlanFail(_field, "task completion requires a null encounter ID");
			}
			break;
		case "encounter_started":
		case "encounter_completed":
			_encounter_id = _BladeStagePlanStableId(
				_encounter_id, "encounter_schedule", _field + ".encounter_id"
			);
			if (!is_undefined(_task_port_id)) {
				_BladeStagePlanFail(_field, "encounter source requires a null task port ID");
			}
			break;
		default:
			_BladeStagePlanFail(_field + ".kind", "is unknown");
	}
	return {
		kind: _value.kind,
		task_port_id: _task_port_id,
		encounter_id: _encounter_id,
	};
}

/// Validates one normalized typed signal definition.
function _BladeStagePlanSignal(_value, _field) {
	_BladeStagePlanExactKeys(
		_value, ["schema_version", "id", "display_name", "type_id", "source"], _field
	);
	return {
		schema_version: _BladeStagePlanSchemaVersion(_value.schema_version, _field + ".schema_version"),
		id: _BladeStagePlanStableId(_value.id, "signal", _field + ".id"),
		display_name: _BladeStagePlanDisplayName(_value.display_name, _field + ".display_name"),
		type_id: _BladeStagePlanStableId(_value.type_id, "signal_type", _field + ".type_id"),
		source: _BladeStagePlanSignalSource(_value.source, _field + ".source"),
	};
}

/// Validates one normalized typed semantic presentation cue.
function _BladeStagePlanCue(_value, _field) {
	_BladeStagePlanExactKeys(
		_value, ["schema_version", "id", "display_name", "type_id"], _field
	);
	return {
		schema_version: _BladeStagePlanSchemaVersion(_value.schema_version, _field + ".schema_version"),
		id: _BladeStagePlanStableId(_value.id, "cue", _field + ".id"),
		display_name: _BladeStagePlanDisplayName(_value.display_name, _field + ".display_name"),
		type_id: _BladeStagePlanStableId(_value.type_id, "cue_type", _field + ".type_id"),
	};
}

/// Validates one normalized stage node union without resolving cross-record references.
function _BladeStagePlanNode(_value, _field, _expected_order) {
	if (!is_struct(_value) || !variable_struct_exists(_value, "kind")) {
		_BladeStagePlanFail(_field, "must be a node struct with kind");
	}
	var _base = ["schema_version", "id", "display_name", "content_order", "kind"];
	var _keys;
	switch (_value.kind) {
		case "wait":
			_keys = array_concat(_base, ["active_ticks", "next_node_id"]);
			break;
		case "spawn_encounter":
			_keys = array_concat(
				_base, ["encounter_id", "anchor_id", "local_offset_q10", "next_node_id"]
			);
			break;
		case "wait_encounter_completion":
			_keys = array_concat(_base, ["encounter_id", "next_node_id"]);
			break;
		case "request_task":
			_keys = array_concat(_base, ["task", "next_node_id"]);
			break;
		case "wait_signal":
			_keys = array_concat(_base, ["signal", "next_node_id"]);
			break;
		case "emit_presentation_cue":
			_keys = array_concat(_base, ["cue", "next_node_id"]);
			break;
		case "complete":
			_keys = _base;
			break;
		default:
			_BladeStagePlanFail(_field + ".kind", "is unknown");
	}
	_BladeStagePlanExactKeys(_value, _keys, _field);
	var _copy = {
		schema_version: _BladeStagePlanSchemaVersion(_value.schema_version, _field + ".schema_version"),
		id: _BladeStagePlanStableId(_value.id, "stage_node", _field + ".id"),
		display_name: _BladeStagePlanDisplayName(_value.display_name, _field + ".display_name"),
		content_order: _BladeStagePlanInteger(
			_value.content_order, _expected_order, _expected_order, _field + ".content_order"
		),
		kind: _value.kind,
	};
	switch (_value.kind) {
		case "wait":
			_copy.active_ticks = _BladeStagePlanInteger(
				_value.active_ticks, 1, 1000000, _field + ".active_ticks"
			);
			break;
		case "spawn_encounter":
			_copy.encounter_id = _BladeStagePlanStableId(
				_value.encounter_id, "encounter_schedule", _field + ".encounter_id"
			);
			_copy.anchor_id = _BladeStagePlanStableId(
				_value.anchor_id, "anchor", _field + ".anchor_id"
			);
			_copy.local_offset_q10 = _BladeStagePlanOffset(
				_value.local_offset_q10, _field + ".local_offset_q10"
			);
			break;
		case "wait_encounter_completion":
			_copy.encounter_id = _BladeStagePlanStableId(
				_value.encounter_id, "encounter_schedule", _field + ".encounter_id"
			);
			break;
		case "request_task":
			_copy.task = _BladeStagePlanTypedReference(
				_value.task, "port_id", "task_port", "task_type", _field + ".task"
			);
			break;
		case "wait_signal":
			_copy.signal = _BladeStagePlanTypedReference(
				_value.signal, "signal_id", "signal", "signal_type", _field + ".signal"
			);
			break;
		case "emit_presentation_cue":
			_copy.cue = _BladeStagePlanTypedReference(
				_value.cue, "cue_id", "cue", "cue_type", _field + ".cue"
			);
	}
	if (_value.kind != "complete") {
		_copy.next_node_id = _BladeStagePlanStableId(
			_value.next_node_id, "stage_node", _field + ".next_node_id"
		);
	}
	return _copy;
}

/// Validates one normalized stage and its contiguous content-ordered nodes.
function _BladeStagePlanStage(_value, _field) {
	_BladeStagePlanExactKeys(
		_value,
		["schema_version", "id", "display_name", "entry_node_id", "terminal_node_id", "nodes"],
		_field
	);
	_BladeStagePlanArray(_value.nodes, _field + ".nodes", true);
	var _nodes = [];
	for (var _index = 0; _index < array_length(_value.nodes); ++_index) {
		array_push(
			_nodes,
			_BladeStagePlanNode(
				_value.nodes[_index], _field + ".nodes[" + string(_index) + "]", _index
			)
		);
	}
	return {
		schema_version: _BladeStagePlanSchemaVersion(_value.schema_version, _field + ".schema_version"),
		id: _BladeStagePlanStableId(_value.id, "stage_schedule", _field + ".id"),
		display_name: _BladeStagePlanDisplayName(_value.display_name, _field + ".display_name"),
		entry_node_id: _BladeStagePlanStableId(
			_value.entry_node_id, "stage_node", _field + ".entry_node_id"
		),
		terminal_node_id: _BladeStagePlanStableId(
			_value.terminal_node_id, "stage_node", _field + ".terminal_node_id"
		),
		nodes: _nodes,
	};
}

/// Validates one normalized encounter participant record.
function _BladeStagePlanParticipant(_value, _field, _expected_order) {
	_BladeStagePlanExactKeys(
		_value,
		["schema_version", "id", "display_name", "kind_id", "spawn_order", "local_offset_q10", "defeat_disposition"],
		_field
	);
	if (_value.defeat_disposition != "remove"
		&& _value.defeat_disposition != "retain_harmless") {
		_BladeStagePlanFail(_field + ".defeat_disposition", "is unknown");
	}
	return {
		schema_version: _BladeStagePlanSchemaVersion(_value.schema_version, _field + ".schema_version"),
		id: _BladeStagePlanStableId(_value.id, "participant", _field + ".id"),
		display_name: _BladeStagePlanDisplayName(_value.display_name, _field + ".display_name"),
		kind_id: _BladeStagePlanStableId(
			_value.kind_id, "participant_kind", _field + ".kind_id"
		),
		spawn_order: _BladeStagePlanInteger(
			_value.spawn_order, _expected_order, _expected_order, _field + ".spawn_order"
		),
		local_offset_q10: _BladeStagePlanOffset(
			_value.local_offset_q10, _field + ".local_offset_q10"
		),
		defeat_disposition: _value.defeat_disposition,
	};
}

/// Validates one normalized encounter record and its exact all-defeated contract.
function _BladeStagePlanEncounter(_value, _field) {
	_BladeStagePlanExactKeys(
		_value,
		["schema_version", "id", "display_name", "participants", "completion_predicate", "cleanup_policy", "stage_signals"],
		_field
	);
	_BladeStagePlanArray(_value.participants, _field + ".participants", true);
	var _participants = [];
	for (var _index = 0; _index < array_length(_value.participants); ++_index) {
		array_push(
			_participants,
			_BladeStagePlanParticipant(
				_value.participants[_index],
				_field + ".participants[" + string(_index) + "]", _index
			)
		);
	}
	_BladeStagePlanExactKeys(
		_value.completion_predicate, ["kind", "participant_ids"],
		_field + ".completion_predicate"
	);
	if (_value.completion_predicate.kind != "all_participants_defeated") {
		_BladeStagePlanFail(_field + ".completion_predicate.kind", "is unknown");
	}
	_BladeStagePlanArray(
		_value.completion_predicate.participant_ids,
		_field + ".completion_predicate.participant_ids", true
	);
	var _participant_ids = [];
	if (array_length(_value.completion_predicate.participant_ids)
		!= array_length(_participants)) {
		_BladeStagePlanFail(_field + ".completion_predicate", "must name every participant");
	}
	for (var _index = 0; _index < array_length(_participants); ++_index) {
		var _id = _BladeStagePlanStableId(
			_value.completion_predicate.participant_ids[_index], "participant",
			_field + ".completion_predicate.participant_ids[" + string(_index) + "]"
		);
		if (_id != _participants[_index].id) {
			_BladeStagePlanFail(
				_field + ".completion_predicate",
				"participant IDs must equal spawn order"
			);
		}
		array_push(_participant_ids, _id);
	}
	_BladeStagePlanExactKeys(
		_value.cleanup_policy, ["on_completion"], _field + ".cleanup_policy"
	);
	if (_value.cleanup_policy.on_completion != "cleanup.stage_end") {
		_BladeStagePlanFail(_field + ".cleanup_policy.on_completion", "is unknown");
	}
	_BladeStagePlanExactKeys(
		_value.stage_signals, ["started", "completed"], _field + ".stage_signals"
	);
	return {
		schema_version: _BladeStagePlanSchemaVersion(_value.schema_version, _field + ".schema_version"),
		id: _BladeStagePlanStableId(_value.id, "encounter_schedule", _field + ".id"),
		display_name: _BladeStagePlanDisplayName(_value.display_name, _field + ".display_name"),
		participants: _participants,
		completion_predicate: {
			kind: "all_participants_defeated",
			participant_ids: _participant_ids,
		},
		cleanup_policy: { on_completion: "cleanup.stage_end" },
		stage_signals: {
			started: _BladeStagePlanTypedReference(
				_value.stage_signals.started, "signal_id", "signal", "signal_type",
				_field + ".stage_signals.started"
			),
			completed: _BladeStagePlanTypedReference(
				_value.stage_signals.completed, "signal_id", "signal", "signal_type",
				_field + ".stage_signals.completed"
			),
		},
	};
}

/// Validates a lexical array of normalized records using a supplied validator method.
function _BladeStagePlanRecordArray(_values, _validator, _field) {
	_BladeStagePlanArray(_values, _field);
	var _copy = [];
	var _previous = "";
	for (var _index = 0; _index < array_length(_values); ++_index) {
		var _record = _validator(_values[_index], _field + "[" + string(_index) + "]");
		if (_index > 0 && _BladeStagePlanAsciiCompare(_previous, _record.id) >= 0) {
			_BladeStagePlanFail(_field, "must be strictly lexical with no duplicates");
		}
		array_push(_copy, _record);
		_previous = _record.id;
	}
	return _copy;
}

/// Validates one complete normalized catalog before cross-catalog resolution.
function _BladeStagePlanCatalog(_value, _field) {
	_BladeStagePlanExactKeys(
		_value,
		["schema_version", "id", "display_name", "named_anchors", "participant_kind_ids", "task_type_ids", "signal_type_ids", "cue_type_ids", "task_ports", "signals", "cues", "stages", "encounters"],
		_field
	);
	return {
		schema_version: _BladeStagePlanSchemaVersion(_value.schema_version, _field + ".schema_version"),
		id: _BladeStagePlanStableId(_value.id, "stage_catalog", _field + ".id"),
		display_name: _BladeStagePlanDisplayName(_value.display_name, _field + ".display_name"),
		named_anchors: _BladeStagePlanRecordArray(
			_value.named_anchors, _BladeStagePlanAnchor, _field + ".named_anchors"
		),
		participant_kind_ids: _BladeStagePlanIdRegistry(
			_value.participant_kind_ids, "participant_kind", _field + ".participant_kind_ids"
		),
		task_type_ids: _BladeStagePlanIdRegistry(
			_value.task_type_ids, "task_type", _field + ".task_type_ids"
		),
		signal_type_ids: _BladeStagePlanIdRegistry(
			_value.signal_type_ids, "signal_type", _field + ".signal_type_ids"
		),
		cue_type_ids: _BladeStagePlanIdRegistry(
			_value.cue_type_ids, "cue_type", _field + ".cue_type_ids"
		),
		task_ports: _BladeStagePlanRecordArray(
			_value.task_ports, _BladeStagePlanTaskPort, _field + ".task_ports"
		),
		signals: _BladeStagePlanRecordArray(
			_value.signals, _BladeStagePlanSignal, _field + ".signals"
		),
		cues: _BladeStagePlanRecordArray(
			_value.cues, _BladeStagePlanCue, _field + ".cues"
		),
		stages: _BladeStagePlanRecordArray(
			_value.stages, _BladeStagePlanStage, _field + ".stages"
		),
		encounters: _BladeStagePlanRecordArray(
			_value.encounters, _BladeStagePlanEncounter, _field + ".encounters"
		),
	};
}
