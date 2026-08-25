/// @description Owned typed task, signal, and semantic-cue outboxes for one stage executor.

/// Rejects values that are not version 1 stage port owners.
function _BladeStagePortsRequire(_ports) {
	if (!is_struct(_ports)
		|| !variable_struct_exists(_ports, "__blade_stage_ports_version")
		|| _ports.__blade_stage_ports_version != 1) {
		_BladeStagePlanFail("ports", "expected a version 1 port owner");
	}
	if (!is_array(_ports.task_requests)
		|| !is_array(_ports.signal_records)
		|| !is_array(_ports.cue_requests)) {
		_BladeStagePlanFail("ports", "owned outboxes must remain arrays");
	}
	return _ports;
}

/// Validates one positive stage-local execution generation.
function _BladeStagePortsGeneration(_value, _field) {
	return _BladeStagePlanInteger(
		_value, 1, int64("9223372036854775807"), _field
	);
}

/// Finds one task request by port and execution generation.
function _BladeStagePortsTaskRequest(_ports, _port_id, _generation) {
	for (var _index = 0; _index < array_length(_ports.task_requests); ++_index) {
		var _request = _ports.task_requests[_index];
		if (_request.port_id == _port_id
			&& _request.execution_generation == _generation) return _request;
	}
	return undefined;
}

/// Finds the normalized signal definition for one exact ID and type pair.
function _BladeStagePortsSignalDefinition(_ports, _signal_id, _type_id) {
	var _signal = _BladeStagePlanFind(_ports.plan.signals, _signal_id);
	if (is_undefined(_signal) || _signal.type_id != _type_id) return undefined;
	return _signal;
}

/// Creates one empty owned port set over an already validated immutable plan.
function BladeStagePortsCreate(_plan) {
	_BladeStagePlanRequire(_plan);
	return {
		__blade_stage_ports_version: 1,
		plan: _plan,
		task_requests: [],
		signal_records: [],
		cue_requests: [],
	};
}

/// Emits one exact typed task request identified by its stage-node execution generation.
function BladeStagePortsEmitTask(
	_ports, _node_id, _generation, _port_id, _type_id
) {
	_BladeStagePortsRequire(_ports);
	var _port = _BladeStagePlanFind(_ports.plan.task_ports, _port_id);
	if (is_undefined(_port) || _port.type_id != _type_id) {
		_BladeStagePlanFail("task request", "does not match a declared port and type");
	}
	var _validated_generation = _BladeStagePortsGeneration(
		_generation, "task request generation"
	);
	if (!is_undefined(_BladeStagePortsTaskRequest(
		_ports, _port_id, _validated_generation
	))) {
		_BladeStagePlanFail("task request", "cannot emit one generation twice");
	}
	var _request = {
		schema_version: 1,
		stage_id: _ports.plan.stage.id,
		node_id: _BladeStagePlanStableId(_node_id, "stage_node", "task node ID"),
		execution_generation: _validated_generation,
		port_id: _port.id,
		type_id: _port.type_id,
		completion_signal_id: _port.completion_signal.signal_id,
		completion_signal_type_id: _port.completion_signal.type_id,
		completion_received: false,
	};
	array_push(_ports.task_requests, _request);
	return _BladeStagePlanClone(_request);
}

/// Emits one exact typed semantic cue without adding freeform payload or gameplay authority.
function BladeStagePortsEmitCue(
	_ports, _node_id, _generation, _cue_id, _type_id
) {
	_BladeStagePortsRequire(_ports);
	var _cue = _BladeStagePlanFind(_ports.plan.cues, _cue_id);
	if (is_undefined(_cue) || _cue.type_id != _type_id) {
		_BladeStagePlanFail("presentation cue", "does not match a declared cue and type");
	}
	var _record = {
		schema_version: 1,
		stage_id: _ports.plan.stage.id,
		node_id: _BladeStagePlanStableId(_node_id, "stage_node", "cue node ID"),
		execution_generation: _BladeStagePortsGeneration(
			_generation, "cue execution generation"
		),
		cue_id: _cue.id,
		type_id: _cue.type_id,
	};
	for (var _index = 0; _index < array_length(_ports.cue_requests); ++_index) {
		if (_ports.cue_requests[_index].node_id == _record.node_id
			&& _ports.cue_requests[_index].execution_generation
				== _record.execution_generation) {
			_BladeStagePlanFail("presentation cue", "cannot emit one generation twice");
		}
	}
	array_push(_ports.cue_requests, _record);
	return _BladeStagePlanClone(_record);
}

/// Appends one validated signal fact after its declared source and generation are known.
function _BladeStagePortsEmitSignal(
	_ports, _signal, _source_kind, _source_id, _source_generation
) {
	var _record = {
		schema_version: 1,
		signal_id: _signal.id,
		type_id: _signal.type_id,
		source_kind: _source_kind,
		source_id: _source_id,
		source_generation: _BladeStagePortsGeneration(
			_source_generation, "signal source generation"
		),
		consumed: false,
		consumer_node_id: "",
		consumer_generation: int64(0),
	};
	array_push(_ports.signal_records, _record);
	return _BladeStagePlanClone(_record);
}

/// Emits one internally owned encounter started or completed signal.
function BladeStagePortsEmitEncounterSignal(
	_ports, _signal_id, _type_id, _encounter_id, _source_kind, _encounter_generation
) {
	_BladeStagePortsRequire(_ports);
	var _signal = _BladeStagePortsSignalDefinition(_ports, _signal_id, _type_id);
	if (is_undefined(_signal)
		|| _signal.source.kind != _source_kind
		|| _signal.source.encounter_id != _encounter_id
		|| (_source_kind != "encounter_started"
			&& _source_kind != "encounter_completed")) {
		_BladeStagePlanFail("encounter signal", "does not match its declared source");
	}
	return _BladeStagePortsEmitSignal(
		_ports, _signal, _source_kind, _encounter_id, _encounter_generation
	);
}

/// Accepts a task completion only for the exact pending request and current typed wait.
function BladeStagePortsSubmitTaskCompletion(
	_ports, _wait_node, _wait_generation,
	_port_id, _type_id, _signal_id, _signal_type_id, _request_generation
) {
	_BladeStagePortsRequire(_ports);
	if (!is_struct(_wait_node) || _wait_node.kind != "wait_signal"
		|| _wait_node.signal.signal_id != _signal_id
		|| _wait_node.signal.type_id != _signal_type_id
		|| _wait_generation < 1) {
		return { accepted: false };
	}
	var _validated_wait_generation = _BladeStagePortsGeneration(
		_wait_generation, "task completion wait generation"
	);
	var _request = _BladeStagePortsTaskRequest(
		_ports, _port_id, _request_generation
	);
	if (is_undefined(_request) || _request.type_id != _type_id
		|| _request.completion_received
		|| _request.completion_signal_id != _signal_id
		|| _request.completion_signal_type_id != _signal_type_id) {
		return { accepted: false };
	}
	var _signal = _BladeStagePortsSignalDefinition(_ports, _signal_id, _signal_type_id);
	if (is_undefined(_signal) || _signal.source.kind != "task_completion"
		|| _signal.source.task_port_id != _port_id) {
		return { accepted: false };
	}
	_request.completion_received = true;
	var _record = _BladeStagePortsEmitSignal(
		_ports, _signal, "task_completion", _port_id, _request_generation
	);
	return {
		accepted: true,
		wait_generation: _validated_wait_generation,
		signal: _record,
	};
}

/// Accepts one external signal only for the exact current wait execution generation.
function BladeStagePortsSubmitExternalSignal(
	_ports, _wait_node, _wait_generation, _signal_id, _type_id, _submitted_generation
) {
	_BladeStagePortsRequire(_ports);
	if (!is_struct(_wait_node) || _wait_node.kind != "wait_signal"
		|| _wait_node.signal.signal_id != _signal_id
		|| _wait_node.signal.type_id != _type_id
		|| _submitted_generation != _wait_generation) {
		return { accepted: false };
	}
	var _signal = _BladeStagePortsSignalDefinition(_ports, _signal_id, _type_id);
	if (is_undefined(_signal) || _signal.source.kind != "external") {
		return { accepted: false };
	}
	for (var _index = 0; _index < array_length(_ports.signal_records); ++_index) {
		var _record = _ports.signal_records[_index];
		if (!_record.consumed && _record.signal_id == _signal_id
			&& _record.type_id == _type_id
			&& _record.source_kind == "external"
			&& _record.source_generation == _submitted_generation) {
			return { accepted: false };
		}
	}
	return {
		accepted: true,
		signal: _BladeStagePortsEmitSignal(
			_ports, _signal, "external", "", _submitted_generation
		),
	};
}

/// Reports whether one exact signal can be consumed without mutating its record.
function BladeStagePortsCanConsumeSignal(
	_ports, _wait_node, _wait_generation, _expected_source_generation
) {
	_BladeStagePortsRequire(_ports);
	for (var _index = 0; _index < array_length(_ports.signal_records); ++_index) {
		var _record = _ports.signal_records[_index];
		if (!_record.consumed
			&& _record.signal_id == _wait_node.signal.signal_id
			&& _record.type_id == _wait_node.signal.type_id
			&& (_expected_source_generation < 0
				|| _record.source_generation == _expected_source_generation)) {
			return true;
		}
	}
	return false;
}

/// Consumes the first exact unconsumed signal in deterministic append order.
function BladeStagePortsConsumeSignal(
	_ports, _wait_node, _wait_generation, _expected_source_generation
) {
	_BladeStagePortsRequire(_ports);
	for (var _index = 0; _index < array_length(_ports.signal_records); ++_index) {
		var _record = _ports.signal_records[_index];
		if (!_record.consumed
			&& _record.signal_id == _wait_node.signal.signal_id
			&& _record.type_id == _wait_node.signal.type_id
			&& (_expected_source_generation < 0
				|| _record.source_generation == _expected_source_generation)) {
			_record.consumed = true;
			_record.consumer_node_id = _wait_node.id;
			_record.consumer_generation = _BladeStagePortsGeneration(
				_wait_generation, "signal consumer generation"
			);
			return { consumed: true, signal: _BladeStagePlanClone(_record) };
		}
	}
	return { consumed: false };
}

/// Returns detached task, signal, and cue records without exposing owned outboxes.
function BladeStagePortsSnapshot(_ports) {
	_BladeStagePortsRequire(_ports);
	return {
		task_requests: _BladeStagePlanClone(_ports.task_requests),
		signal_records: _BladeStagePlanClone(_ports.signal_records),
		cue_requests: _BladeStagePlanClone(_ports.cue_requests),
	};
}

/// Returns immutable outbox occurrences after a caller-owned delivery cursor.
function _BladeStagePortsRead(_records, _cursor, _field) {
	var _validated_cursor = _BladeStagePlanInteger(
		_cursor, 0, array_length(_records), _field + " cursor"
	);
	var _copy = [];
	for (var _index = real(_validated_cursor);
		_index < array_length(_records); ++_index) {
		array_push(_copy, _BladeStagePlanClone(_records[_index]));
	}
	return { next_cursor: int64(array_length(_records)), records: _copy };
}

/// Reads exactly-once task occurrences using a consumer-owned resumable cursor.
function BladeStagePortsReadTaskRequests(_ports, _cursor) {
	_BladeStagePortsRequire(_ports);
	return _BladeStagePortsRead(_ports.task_requests, _cursor, "task outbox");
}

/// Reads exactly-once cue occurrences using a consumer-owned resumable cursor.
function BladeStagePortsReadCueRequests(_ports, _cursor) {
	_BladeStagePortsRequire(_ports);
	return _BladeStagePortsRead(_ports.cue_requests, _cursor, "cue outbox");
}

/// Reads appended signal facts using a consumer-owned resumable cursor.
function BladeStagePortsReadSignalRecords(_ports, _cursor) {
	_BladeStagePortsRequire(_ports);
	return _BladeStagePortsRead(_ports.signal_records, _cursor, "signal outbox");
}

/// Encodes all typed port records in append order for deterministic stage hashing.
function BladeStagePortsCanonical(_ports) {
	return BladeCanonicalRecord(
		"BSPORTS1", [_BladeStagePlanCanonicalValue(BladeStagePortsSnapshot(_ports))]
	);
}
