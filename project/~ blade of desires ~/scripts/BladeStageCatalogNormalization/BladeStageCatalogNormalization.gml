/// @description Pure raw-catalog normalization into the detached runtime plan shape.

/// Inserts one validated stable ID into a deterministic lexical copy.
function _BladeStageCatalogInsertId(_target, _value, _prefix, _field) {
	var _id = _BladeStagePlanStableId(_value, _prefix, _field);
	var _insert = array_length(_target);
	for (var _index = 0; _index < array_length(_target); ++_index) {
		if (_BladeStagePlanAsciiCompare(_id, _target[_index]) < 0) {
			_insert = _index;
			break;
		}
	}
	array_insert(_target, _insert, _id);
}

/// Returns one lexical detached copy of a raw stable-ID array.
function _BladeStageCatalogSortIds(_values, _prefix, _field) {
	_BladeStagePlanArray(_values, _field);
	var _sorted = [];
	for (var _index = 0; _index < array_length(_values); ++_index) {
		_BladeStageCatalogInsertId(
			_sorted, _values[_index], _prefix,
			_field + "[" + string(_index) + "]"
		);
	}
	return _sorted;
}

/// Returns records detached and sorted bytewise by their validated stable IDs.
function _BladeStageCatalogSortRecords(_values, _prefix, _field) {
	_BladeStagePlanArray(_values, _field);
	var _sorted = [];
	for (var _index = 0; _index < array_length(_values); ++_index) {
		var _record = _values[_index];
		if (!is_struct(_record) || !variable_struct_exists(_record, "id")) {
			_BladeStagePlanFail(_field, "contains a record without id");
		}
		var _id = _BladeStagePlanStableId(
			_record.id, _prefix, _field + "[" + string(_index) + "].id"
		);
		var _insert = array_length(_sorted);
		for (var _scan = 0; _scan < array_length(_sorted); ++_scan) {
			if (_BladeStagePlanAsciiCompare(_id, _sorted[_scan].id) < 0) {
				_insert = _scan;
				break;
			}
		}
		array_insert(_sorted, _insert, _BladeStagePlanClone(_record));
	}
	return _sorted;
}

/// Returns records detached and sorted by one exact nonnegative order field.
function _BladeStageCatalogSortOrdered(_values, _order_field, _field) {
	_BladeStagePlanArray(_values, _field, true);
	var _sorted = [];
	for (var _index = 0; _index < array_length(_values); ++_index) {
		var _record = _values[_index];
		if (!is_struct(_record) || !variable_struct_exists(_record, _order_field)) {
			_BladeStagePlanFail(_field, "contains a record without " + _order_field);
		}
		var _order = _BladeStagePlanInteger(
			variable_struct_get(_record, _order_field), 0, int64("2147483647"),
			_field + "[" + string(_index) + "]." + _order_field
		);
		var _insert = array_length(_sorted);
		for (var _scan = 0; _scan < array_length(_sorted); ++_scan) {
			if (_order < variable_struct_get(_sorted[_scan], _order_field)) {
				_insert = _scan;
				break;
			}
		}
		array_insert(_sorted, _insert, _BladeStagePlanClone(_record));
	}
	return _sorted;
}

/// Expands one closed raw signal source into normalized nullable reference fields.
function _BladeStageCatalogNormalizeSignal(_value, _field) {
	_BladeStagePlanExactKeys(
		_value, ["schema_version", "id", "display_name", "type_id", "source"],
		_field
	);
	if (!is_struct(_value.source) || !variable_struct_exists(_value.source, "kind")) {
		_BladeStagePlanFail(_field + ".source", "must be a source struct with kind");
	}
	var _task_port_id = undefined;
	var _encounter_id = undefined;
	switch (_value.source.kind) {
		case "external":
			_BladeStagePlanExactKeys(_value.source, ["kind"], _field + ".source");
			break;
		case "task_completion":
			_BladeStagePlanExactKeys(
				_value.source, ["kind", "source_id"], _field + ".source"
			);
			_task_port_id = _BladeStagePlanStableId(
				_value.source.source_id, "task_port", _field + ".source.source_id"
			);
			break;
		case "encounter_started":
		case "encounter_completed":
			_BladeStagePlanExactKeys(
				_value.source, ["kind", "source_id"], _field + ".source"
			);
			_encounter_id = _BladeStagePlanStableId(
				_value.source.source_id, "encounter_schedule",
				_field + ".source.source_id"
			);
			break;
		default:
			_BladeStagePlanFail(_field + ".source.kind", "is unknown");
	}
	return {
		schema_version: _value.schema_version,
		id: _value.id,
		display_name: _value.display_name,
		type_id: _value.type_id,
		source: {
			kind: _value.source.kind,
			task_port_id: _task_port_id,
			encounter_id: _encounter_id,
		},
	};
}

/// Normalizes and lexically sorts every raw signal definition.
function _BladeStageCatalogNormalizeSignals(_values, _field) {
	_BladeStagePlanArray(_values, _field);
	var _normalized = [];
	for (var _index = 0; _index < array_length(_values); ++_index) {
		array_push(
			_normalized,
			_BladeStageCatalogNormalizeSignal(
				_values[_index], _field + "[" + string(_index) + "]"
			)
		);
	}
	return _BladeStageCatalogSortRecords(_normalized, "signal", _field);
}

/// Reorders one predicate's participant IDs to the normalized spawn order.
function _BladeStageCatalogPredicateIds(_predicate, _participants, _field) {
	_BladeStagePlanExactKeys(_predicate, ["kind", "participant_ids"], _field);
	_BladeStagePlanArray(_predicate.participant_ids, _field + ".participant_ids", true);
	var _ordered = [];
	for (var _participant_index = 0;
		_participant_index < array_length(_participants); ++_participant_index) {
		var _participant = _participants[_participant_index];
		if (!is_struct(_participant) || !variable_struct_exists(_participant, "id")) {
			_BladeStagePlanFail(_field, "cannot resolve a participant without id");
		}
		var _matches = 0;
		for (var _id_index = 0;
			_id_index < array_length(_predicate.participant_ids); ++_id_index) {
			if (_predicate.participant_ids[_id_index] == _participant.id) _matches += 1;
		}
		if (_matches != 1) {
			_BladeStagePlanFail(_field, "must name every participant exactly once");
		}
		array_push(_ordered, _participant.id);
	}
	if (array_length(_ordered) != array_length(_predicate.participant_ids)) {
		_BladeStagePlanFail(_field, "contains an unknown participant ID");
	}
	return _ordered;
}

/// Normalizes nested participant ordering and completion IDs for one encounter.
function _BladeStageCatalogNormalizeEncounter(_value, _field) {
	var _copy = _BladeStagePlanClone(_value);
	if (!is_struct(_copy)
		|| !variable_struct_exists(_copy, "participants")
		|| !variable_struct_exists(_copy, "completion_predicate")) {
		_BladeStagePlanFail(_field, "must contain participants and completion_predicate");
	}
	_copy.participants = _BladeStageCatalogSortOrdered(
		_copy.participants, "spawn_order", _field + ".participants"
	);
	_copy.completion_predicate.participant_ids = _BladeStageCatalogPredicateIds(
		_copy.completion_predicate, _copy.participants,
		_field + ".completion_predicate"
	);
	return _copy;
}

/// Normalizes nested node ordering for one stage record.
function _BladeStageCatalogNormalizeStage(_value, _field) {
	var _copy = _BladeStagePlanClone(_value);
	if (!is_struct(_copy) || !variable_struct_exists(_copy, "nodes")) {
		_BladeStagePlanFail(_field, "must contain nodes");
	}
	_copy.nodes = _BladeStageCatalogSortOrdered(
		_copy.nodes, "content_order", _field + ".nodes"
	);
	return _copy;
}

/// Normalizes nested records before applying stable lexical catalog order.
function _BladeStageCatalogNormalizeNested(
	_values, _prefix, _field, _normalizer
) {
	_BladeStagePlanArray(_values, _field);
	var _normalized = [];
	for (var _index = 0; _index < array_length(_values); ++_index) {
		array_push(
			_normalized,
			_normalizer(_values[_index], _field + "[" + string(_index) + "]")
		);
	}
	return _BladeStageCatalogSortRecords(_normalized, _prefix, _field);
}

/// Applies cross-reference and graph validation to every stage in one normalized root.
function _BladeStageCatalogValidateRoot(_root, _gameplay_plane) {
	var _stages = _root.catalogs[0].stages;
	if (array_length(_stages) == 0) {
		_BladeStagePlanFail("catalog.stages", "must define at least one stage");
	}
	var _validation_fingerprint = BladeStageNormalizedPlanFingerprint(_root);
	for (var _index = 0; _index < array_length(_stages); ++_index) {
		BladeStagePlanCreate(
			_root, _validation_fingerprint, _stages[_index].id, _gameplay_plane
		);
	}
}

/// @func BladeStageCatalogNormalize(raw_catalog, gameplay_plane)
/// Validates, detaches, sorts, expands source variants, and returns one normalized plan root.
function BladeStageCatalogNormalize(_raw_catalog, _gameplay_plane) {
	var _plane = BladeCombatPlaneCopy(_gameplay_plane);
	_BladeStagePlanExactKeys(
		_raw_catalog,
		[
			"schema_version", "id", "display_name", "product_contract",
			"named_anchors", "participant_kind_ids", "task_type_ids",
			"signal_type_ids", "cue_type_ids", "task_ports", "signals",
			"cues", "stages", "encounters",
		],
		"raw catalog"
	);
	_BladeStagePlanExactKeys(
		_raw_catalog.product_contract, ["id", "content_version"],
		"raw catalog.product_contract"
	);
	var _product = {
		id: _BladeStagePlanStableId(
			_raw_catalog.product_contract.id, "contract",
			"raw catalog.product_contract.id"
		),
		content_version: _BladeStagePlanContentVersion(
			_raw_catalog.product_contract.content_version
		),
	};
	var _stages = _BladeStageCatalogNormalizeNested(
		_raw_catalog.stages, "stage_schedule", "raw catalog.stages",
		_BladeStageCatalogNormalizeStage
	);
	var _encounters = _BladeStageCatalogNormalizeNested(
		_raw_catalog.encounters, "encounter_schedule", "raw catalog.encounters",
		_BladeStageCatalogNormalizeEncounter
	);
	var _catalog = _BladeStagePlanCatalog({
		schema_version: _raw_catalog.schema_version,
		id: _raw_catalog.id,
		display_name: _raw_catalog.display_name,
		named_anchors: _BladeStageCatalogSortRecords(
			_raw_catalog.named_anchors, "anchor", "raw catalog.named_anchors"
		),
		participant_kind_ids: _BladeStageCatalogSortIds(
			_raw_catalog.participant_kind_ids, "participant_kind",
			"raw catalog.participant_kind_ids"
		),
		task_type_ids: _BladeStageCatalogSortIds(
			_raw_catalog.task_type_ids, "task_type", "raw catalog.task_type_ids"
		),
		signal_type_ids: _BladeStageCatalogSortIds(
			_raw_catalog.signal_type_ids, "signal_type", "raw catalog.signal_type_ids"
		),
		cue_type_ids: _BladeStageCatalogSortIds(
			_raw_catalog.cue_type_ids, "cue_type", "raw catalog.cue_type_ids"
		),
		task_ports: _BladeStageCatalogSortRecords(
			_raw_catalog.task_ports, "task_port", "raw catalog.task_ports"
		),
		signals: _BladeStageCatalogNormalizeSignals(
			_raw_catalog.signals, "raw catalog.signals"
		),
		cues: _BladeStageCatalogSortRecords(
			_raw_catalog.cues, "cue", "raw catalog.cues"
		),
		stages: _stages,
		encounters: _encounters,
	}, "catalog");
	var _root = {
		schema_version: _BladeStagePlanSchemaVersion(
			_raw_catalog.schema_version, "raw catalog.schema_version"
		),
		product_contract: _product,
		catalogs: [_catalog],
	};
	_BladeStageCatalogValidateRoot(_root, _plane);
	return _root;
}
