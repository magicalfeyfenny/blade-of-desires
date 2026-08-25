/// @description Canonical run-local stage events committed in stage content order.

/// Rejects values that are not version 1 owned stage-event streams.
function _BladeStageEventStreamRequire(_stream) {
	if (!is_struct(_stream)
		|| !variable_struct_exists(_stream, "__blade_stage_event_stream_version")
		|| _stream.__blade_stage_event_stream_version != 1
		|| !is_array(_stream.records)) {
		_BladeStagePlanFail("stage events", "expected a version 1 event stream");
	}
	_BladeStagePlanRequire(_stream.plan);
	return _stream;
}

/// Encodes one event without its derived hash in fixed semantic field order.
function _BladeStageEventBodyCanonical(_record) {
	return BladeCanonicalRecord("BSEVENT1", [
		_record.event_id,
		_record.stage_id,
		_record.node_id,
		string(_record.execution_generation),
		string(_record.content_order),
		_record.kind,
		string(_record.simulation_tick),
		string(_record.stage_tick),
	]);
}

/// Finds a prior event for one exact node execution occurrence.
function _BladeStageEventFind(_stream, _node_id, _generation) {
	for (var _index = 0; _index < array_length(_stream.records); ++_index) {
		var _record = _stream.records[_index];
		if (_record.node_id == _node_id
			&& _record.execution_generation == _generation) return _record;
	}
	return undefined;
}

/// Validates one pending node event and shared Event-ID capacity without mutation.
function _BladeStageEventPreflight(
	_stream, _kernel, _node, _generation, _tick
) {
	_BladeStageEventStreamRequire(_stream);
	_BladeKernelRequire(_kernel);
	var _plan_node = BladeStagePlanFindNode(_stream.plan, _node.id);
	if (is_undefined(_plan_node)
		|| _plan_node.content_order != _node.content_order
		|| _plan_node.kind != _node.kind) {
		_BladeStagePlanFail("stage event", "does not match a selected plan node");
	}
	var _validated_generation = _BladeStagePortsGeneration(
		_generation, "stage event generation"
	);
	if (!is_undefined(_BladeStageEventFind(
		_stream, _node.id, _validated_generation
	))) {
		_BladeStagePlanFail("stage event", "cannot commit one node generation twice");
	}
	var _counters = BladeRunIdentityGetCounters(_kernel.identity);
	if (_counters.event >= int64("9223372036854775806")) {
		_BladeStagePlanFail("stage event", "exceeds Event ID capacity");
	}
	return {
		stage_id: _stream.plan.stage.id,
		node_id: _node.id,
		execution_generation: _validated_generation,
		content_order: _node.content_order,
		kind: _node.kind,
		simulation_tick: _BladeStagePlanInteger(
			_tick.simulation_tick, 0, int64("9223372036854775807"),
			"stage event simulation tick"
		),
		stage_tick: _BladeStagePlanInteger(
			_tick.stage_tick, 0, int64("9223372036854775807"),
			"stage event stage tick"
		),
	};
}

/// Creates an empty event stream without consuming shared gameplay identity.
function BladeStageEventStreamCreate(_plan) {
	_BladeStagePlanRequire(_plan);
	return {
		__blade_stage_event_stream_version: 1,
		plan: _plan,
		records: [],
	};
}

/// Publicly preflights an upcoming command before it mutates IDs or outboxes.
function BladeStageEventStreamPreflight(
	_stream, _kernel, _node, _generation, _tick
) {
	return _BladeStagePlanClone(_BladeStageEventPreflight(
		_stream, _kernel, _node, _generation, _tick
	));
}

/// Allocates one evt ID only after its node command committed successfully.
function BladeStageEventStreamCommit(
	_stream, _kernel, _node, _generation, _tick
) {
	var _pending = _BladeStageEventPreflight(
		_stream, _kernel, _node, _generation, _tick
	);
	var _record = {
		schema_version: 1,
		event_id: BladeKernelAllocate(_kernel, BladeRunIdKind.Event),
		stage_id: _pending.stage_id,
		node_id: _pending.node_id,
		execution_generation: _pending.execution_generation,
		content_order: _pending.content_order,
		kind: _pending.kind,
		simulation_tick: _pending.simulation_tick,
		stage_tick: _pending.stage_tick,
		event_hash: "",
	};
	_record.event_hash = BladeCanonicalHashUtf8(
		_BladeStageEventBodyCanonical(_record)
	);
	array_push(_stream.records, _record);
	return _BladeStagePlanClone(_record);
}

/// Returns a detached append-ordered view of committed stage events.
function BladeStageEventStreamSnapshot(_stream) {
	_BladeStageEventStreamRequire(_stream);
	return _BladeStagePlanClone(_stream.records);
}

/// Reads committed events after a caller-owned resumable delivery cursor.
function BladeStageEventStreamRead(_stream, _cursor) {
	_BladeStageEventStreamRequire(_stream);
	var _validated_cursor = _BladeStagePlanInteger(
		_cursor, 0, array_length(_stream.records), "stage event cursor"
	);
	var _copy = [];
	for (var _index = real(_validated_cursor);
		_index < array_length(_stream.records); ++_index) {
		array_push(_copy, _BladeStagePlanClone(_stream.records[_index]));
	}
	return { next_cursor: int64(array_length(_stream.records)), records: _copy };
}

/// Encodes committed stage events in their authoritative content commit order.
function BladeStageEventStreamCanonical(_stream) {
	_BladeStageEventStreamRequire(_stream);
	var _fields = [];
	for (var _index = 0; _index < array_length(_stream.records); ++_index) {
		var _record = _stream.records[_index];
		array_push(_fields, _BladeStageEventBodyCanonical(_record));
		array_push(_fields, _record.event_hash);
	}
	return BladeCanonicalRecord("BSEVENTS1", _fields);
}
