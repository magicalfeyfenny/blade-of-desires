/// @description Versioned stable input-binding identity and semantic mappings.

// Separates directional axis contributions from the unchanged action-mask bits.
enum BladeInputBindingKind {
	Movement = 1,
	Action = 2
}

/// @func BladeInputBindingSchemaVersion()
/// Returns the schema version shared by every stable input-binding record.
function BladeInputBindingSchemaVersion() {
	return 1;
}

// Creates the authoritative version 1 binding registry in persisted canonical order.
// Movement values are full-scale digital contributions to BladeInputRawStateCreate axes.
function _BladeInputBindingCanonicalRecords() {
	return [
		{
			schema_version: BladeInputBindingSchemaVersion(),
			stable_id: "input.move_up",
			kind: BladeInputBindingKind.Movement,
			movement_axis: "move_y",
			movement_value: int64(-1024),
		},
		{
			schema_version: BladeInputBindingSchemaVersion(),
			stable_id: "input.move_down",
			kind: BladeInputBindingKind.Movement,
			movement_axis: "move_y",
			movement_value: int64(1024),
		},
		{
			schema_version: BladeInputBindingSchemaVersion(),
			stable_id: "input.move_left",
			kind: BladeInputBindingKind.Movement,
			movement_axis: "move_x",
			movement_value: int64(-1024),
		},
		{
			schema_version: BladeInputBindingSchemaVersion(),
			stable_id: "input.move_right",
			kind: BladeInputBindingKind.Movement,
			movement_axis: "move_x",
			movement_value: int64(1024),
		},
		{
			schema_version: BladeInputBindingSchemaVersion(),
			stable_id: "input.fire",
			kind: BladeInputBindingKind.Action,
			action_bit: int64(BladeInputAction.Fire),
		},
		{
			schema_version: BladeInputBindingSchemaVersion(),
			stable_id: "input.bomb",
			kind: BladeInputBindingKind.Action,
			action_bit: int64(BladeInputAction.Bomb),
		},
		{
			schema_version: BladeInputBindingSchemaVersion(),
			stable_id: "input.focus",
			kind: BladeInputBindingKind.Action,
			action_bit: int64(BladeInputAction.Focus),
		},
		{
			schema_version: BladeInputBindingSchemaVersion(),
			stable_id: "input.pause",
			kind: BladeInputBindingKind.Action,
			action_bit: int64(BladeInputAction.Pause),
		},
		{
			schema_version: BladeInputBindingSchemaVersion(),
			stable_id: "input.confirm",
			kind: BladeInputBindingKind.Action,
			action_bit: int64(BladeInputAction.Confirm),
		},
		{
			schema_version: BladeInputBindingSchemaVersion(),
			stable_id: "input.cancel",
			kind: BladeInputBindingKind.Action,
			action_bit: int64(BladeInputAction.Cancel),
		},
	];
}

// Copies only the fields belonging to a record's discriminated semantic kind.
function _BladeInputBindingRecordCopy(_record) {
	if (_record.kind == BladeInputBindingKind.Movement) {
		return {
			schema_version: _record.schema_version,
			stable_id: _record.stable_id,
			kind: _record.kind,
			movement_axis: _record.movement_axis,
			movement_value: _record.movement_value,
		};
	}
	return {
		schema_version: _record.schema_version,
		stable_id: _record.stable_id,
		kind: _record.kind,
		action_bit: _record.action_bit,
	};
}

/// @func BladeInputBindingRecords(stable_ids)
/// Returns detached records in canonical order, optionally filtered by unique known IDs.
function BladeInputBindingRecords(_stable_ids = undefined) {
	var _canonical = _BladeInputBindingCanonicalRecords();
	var _requested_ids = _stable_ids;
	if (is_undefined(_requested_ids)) {
		_requested_ids = [];
		for (var _canonical_index = 0;
			_canonical_index < array_length(_canonical);
			++_canonical_index) {
			array_push(_requested_ids, _canonical[_canonical_index].stable_id);
		}
	}

	if (!is_array(_requested_ids)) {
		throw("BladeInputBindingRegistry: lookup requires an array of stable IDs");
	}

	for (var _requested_index = 0;
		_requested_index < array_length(_requested_ids);
		++_requested_index) {
		var _requested_id = _requested_ids[_requested_index];
		if (!is_string(_requested_id)) {
			throw("BladeInputBindingRegistry: stable IDs must be strings");
		}
		for (var _earlier_index = 0;
			_earlier_index < _requested_index;
			++_earlier_index) {
			if (_requested_ids[_earlier_index] == _requested_id) {
				throw("BladeInputBindingRegistry: duplicate stable ID " + _requested_id);
			}
		}
	}

	var _selected = array_create(array_length(_canonical), false);
	for (var _lookup_index = 0;
		_lookup_index < array_length(_requested_ids);
		++_lookup_index) {
		var _lookup_id = _requested_ids[_lookup_index];
		var _found = false;
		for (var _registry_index = 0;
			_registry_index < array_length(_canonical);
			++_registry_index) {
			if (_canonical[_registry_index].stable_id == _lookup_id) {
				_selected[_registry_index] = true;
				_found = true;
				break;
			}
		}
		if (!_found) {
			throw("BladeInputBindingRegistry: unknown stable ID " + _lookup_id);
		}
	}

	var _records = [];
	for (var _output_index = 0;
		_output_index < array_length(_canonical);
		++_output_index) {
		if (_selected[_output_index]) {
			array_push(
				_records,
				_BladeInputBindingRecordCopy(_canonical[_output_index])
			);
		}
	}
	return _records;
}

/// @func BladeInputBindingRecord(stable_id)
/// Returns one detached record and rejects IDs outside the canonical registry.
function BladeInputBindingRecord(_stable_id) {
	var _records = BladeInputBindingRecords([_stable_id]);
	return _records[0];
}
