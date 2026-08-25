/// @description Primitive validation, copying, and canonical encoding for normalized stage plans.

enum BladeStageLifecycle {
	Active = 1,
	Completed = 2,
	Aborted = 3
}

enum BladeStageParticipantState {
	Active = 1,
	Defeated = 2,
	RetainedHarmless = 3,
	Cleaned = 4
}

/// Throws a field-specific stage-plan diagnostic.
function _BladeStagePlanFail(_field, _reason) {
	throw("BladeStagePlan: " + _field + ": " + _reason);
}

/// Converts one exact numeric value to int64 inside inclusive bounds.
function _BladeStagePlanInteger(_value, _minimum, _maximum, _field) {
	return BladeCanonicalRequireInteger(_value, _minimum, _maximum, _field);
}

/// Requires a real Boolean without accepting numeric substitutes.
function _BladeStagePlanBoolean(_value, _field) {
	if (typeof(_value) != "bool") {
		_BladeStagePlanFail(_field, "must be a boolean");
	}
	return _value;
}

/// Requires a nonempty string used as player-facing normalized content.
function _BladeStagePlanDisplayName(_value, _field) {
	if (!is_string(_value) || string_length(_value) == 0) {
		_BladeStagePlanFail(_field, "must be a nonempty string");
	}
	return _value;
}

/// Recognizes one lowercase stable ID with at least two nonempty dot-separated components.
function _BladeStagePlanStableId(_value, _prefix, _field) {
	if (!is_string(_value) || string_length(_value) == 0
		|| string_byte_length(_value) != string_length(_value)) {
		_BladeStagePlanFail(_field, "must be a nonempty ASCII stable ID");
	}
	var _parts = string_split(_value, ".");
	if (array_length(_parts) < 2 || (_prefix != "" && _parts[0] != _prefix)) {
		_BladeStagePlanFail(_field, "has the wrong stable-ID namespace");
	}
	for (var _part_index = 0; _part_index < array_length(_parts); ++_part_index) {
		var _part = _parts[_part_index];
		if (string_length(_part) == 0) {
			_BladeStagePlanFail(_field, "contains an empty stable-ID component");
		}
		for (var _index = 1; _index <= string_length(_part); ++_index) {
			var _byte = string_ord_at(_part, _index);
			var _lower = _byte >= 97 && _byte <= 122;
			var _digit = _byte >= 48 && _byte <= 57;
			if ((!_lower && !_digit && _byte != 95)
				|| (_index == 1 && !_lower)) {
				_BladeStagePlanFail(_field, "contains a forbidden stable-ID byte");
			}
		}
	}
	return _value;
}

/// Requires one exact schema version used by every normalized v1 record.
function _BladeStagePlanSchemaVersion(_value, _field) {
	return _BladeStagePlanInteger(_value, 1, 1, _field);
}

/// Requires a struct to expose exactly the named normalized keys.
function _BladeStagePlanExactKeys(_value, _keys, _field) {
	if (!is_struct(_value)) {
		_BladeStagePlanFail(_field, "must be a struct");
	}
	var _names = variable_struct_get_names(_value);
	if (array_length(_names) != array_length(_keys)) {
		_BladeStagePlanFail(_field, "has unknown or missing fields");
	}
	for (var _index = 0; _index < array_length(_keys); ++_index) {
		if (!variable_struct_exists(_value, _keys[_index])) {
			_BladeStagePlanFail(_field, "is missing " + _keys[_index]);
		}
	}
	return _value;
}

/// Requires an array before normalized record iteration begins.
function _BladeStagePlanArray(_value, _field, _require_nonempty = false) {
	if (!is_array(_value) || (_require_nonempty && array_length(_value) == 0)) {
		_BladeStagePlanFail(
			_field,
			_require_nonempty ? "must be a nonempty array" : "must be an array"
		);
	}
	return _value;
}

/// Compares two ASCII strings bytewise so canonical ordering does not use locale collation.
function _BladeStagePlanAsciiCompare(_left, _right) {
	var _shared = min(string_length(_left), string_length(_right));
	for (var _index = 1; _index <= _shared; ++_index) {
		var _left_byte = string_ord_at(_left, _index);
		var _right_byte = string_ord_at(_right, _index);
		if (_left_byte < _right_byte) return -1;
		if (_left_byte > _right_byte) return 1;
	}
	if (string_length(_left) < string_length(_right)) return -1;
	if (string_length(_left) > string_length(_right)) return 1;
	return 0;
}

/// Returns a lexically sorted copy of struct field names for deterministic generic encoding.
function _BladeStagePlanSortedNames(_value) {
	var _names = variable_struct_get_names(_value);
	var _sorted = [];
	for (var _index = 0; _index < array_length(_names); ++_index) {
		var _insert = array_length(_sorted);
		for (var _scan = 0; _scan < array_length(_sorted); ++_scan) {
			if (_BladeStagePlanAsciiCompare(_names[_index], _sorted[_scan]) < 0) {
				_insert = _scan;
				break;
			}
		}
		array_insert(_sorted, _insert, _names[_index]);
	}
	return _sorted;
}

/// Deep-copies arrays and structs so caller mutation cannot alter an accepted plan.
function _BladeStagePlanClone(_value) {
	if (is_array(_value)) {
		var _array = [];
		for (var _index = 0; _index < array_length(_value); ++_index) {
			array_push(_array, _BladeStagePlanClone(_value[_index]));
		}
		return _array;
	}
	if (is_struct(_value)) {
		var _copy = {};
		var _names = variable_struct_get_names(_value);
		for (var _index = 0; _index < array_length(_names); ++_index) {
			var _name = _names[_index];
			variable_struct_set(
				_copy, _name,
				_BladeStagePlanClone(variable_struct_get(_value, _name))
			);
		}
		return _copy;
	}
	return _value;
}

/// Encodes normalized scalars, arrays, and structs without relying on struct key order.
function _BladeStagePlanCanonicalValue(_value) {
	var _type = typeof(_value);
	if (is_undefined(_value)) return BladeCanonicalRecord("BSNULL1", []);
	if (_type == "string") return BladeCanonicalRecord("BSSTRING1", [_value]);
	if (_type == "bool") {
		return BladeCanonicalRecord("BSBOOL1", [_value ? "1" : "0"]);
	}
	if (_type == "int32" || _type == "int64" || _type == "number") {
		var _integer_text = BladeCanonicalIntegerString(
			_value, _value, _value, "canonical integer"
		);
		return BladeCanonicalRecord("BSINT1", [_integer_text]);
	}
	if (is_array(_value)) {
		var _fields = [];
		for (var _index = 0; _index < array_length(_value); ++_index) {
			array_push(_fields, _BladeStagePlanCanonicalValue(_value[_index]));
		}
		return BladeCanonicalRecord("BSARRAY1", _fields);
	}
	if (is_struct(_value)) {
		var _fields = [];
		var _names = _BladeStagePlanSortedNames(_value);
		for (var _index = 0; _index < array_length(_names); ++_index) {
			var _name = _names[_index];
			array_push(_fields, _name);
			array_push(
				_fields,
				_BladeStagePlanCanonicalValue(variable_struct_get(_value, _name))
			);
		}
		return BladeCanonicalRecord("BSSTRUCT1", _fields);
	}
	_BladeStagePlanFail("canonical value", "contains an unsupported runtime type");
}

/// Validates the lowercase sha1-prefixed fingerprint supplied for normalized plan bytes.
function _BladeStagePlanFingerprint(_value) {
	if (!is_string(_value) || string_length(_value) != 45
		|| string_copy(_value, 1, 5) != "sha1:") {
		_BladeStagePlanFail("plan fingerprint", "must be sha1 followed by 40 lowercase hex digits");
	}
	for (var _index = 6; _index <= 45; ++_index) {
		var _byte = string_ord_at(_value, _index);
		var _digit = _byte >= 48 && _byte <= 57;
		var _hex = _byte >= 97 && _byte <= 102;
		if (!_digit && !_hex) {
			_BladeStagePlanFail("plan fingerprint", "must use lowercase hexadecimal");
		}
	}
	return _value;
}

/// Returns a fixed canonical record for one fully validated normalized plan value.
function BladeStageNormalizedPlanCanonical(_value) {
	return BladeCanonicalRecord("BSPLANVALUE1", [_BladeStagePlanCanonicalValue(_value)]);
}

/// Returns the canonical sha1-prefixed identity for normalized plan bytes.
function BladeStageNormalizedPlanFingerprint(_value) {
	return "sha1:" + BladeCanonicalHashUtf8(
		BladeStageNormalizedPlanCanonical(_value)
	);
}
