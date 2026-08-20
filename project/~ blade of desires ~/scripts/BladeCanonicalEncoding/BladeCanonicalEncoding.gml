/// Deterministic UTF-8 framing and hashing for replay-auditable records.

function __BladeCanonicalFail(_field, _reason) {
	throw "BladeCanonicalEncoding: " + _field + ": " + _reason;
}

function __BladeCanonicalToInt64(_value, _field) {
	var _type = typeof(_value);

	if (_type == "int32" || _type == "int64") {
		return int64(_value);
	}

	if (_type != "number") {
		__BladeCanonicalFail(_field, "must be an integer");
	}
	if (is_nan(_value) || is_infinity(_value)) {
		__BladeCanonicalFail(_field, "must be finite");
	}
	if (floor(_value) != _value) {
		__BladeCanonicalFail(_field, "must not contain a fractional part");
	}
	if (abs(_value) > 9007199254740991) {
		__BladeCanonicalFail(_field, "real-valued integers must be exactly representable");
	}

	return int64(_value);
}

/// @func BladeCanonicalRequireInteger(value, minimum, maximum, field)
/// @desc Returns an exact int64 after validating its inclusive bounds.
function BladeCanonicalRequireInteger(_value, _minimum, _maximum, _field = "value") {
	var _integer = __BladeCanonicalToInt64(_value, _field);
	var _minimum_integer = __BladeCanonicalToInt64(_minimum, _field + " minimum");
	var _maximum_integer = __BladeCanonicalToInt64(_maximum, _field + " maximum");

	if (_minimum_integer > _maximum_integer) {
		__BladeCanonicalFail(_field, "has invalid internal bounds");
	}
	if (_integer < _minimum_integer || _integer > _maximum_integer) {
		__BladeCanonicalFail(
			_field,
			"must be between " + string(_minimum_integer)
				+ " and " + string(_maximum_integer) + " inclusive"
		);
	}

	return _integer;
}

function __BladeCanonicalValidateDecimal(_text, _field) {
	var _length = string_byte_length(_text);
	if (_length < 1 || _length != string_length(_text)) {
		__BladeCanonicalFail(_field, "did not convert to canonical ASCII decimal");
	}

	var _position = 1;
	if (string_ord_at(_text, 1) == 45) {
		if (_length == 1) {
			__BladeCanonicalFail(_field, "did not convert to canonical ASCII decimal");
		}
		_position = 2;
	}

	if (string_ord_at(_text, _position) == 48 && _position < _length) {
		__BladeCanonicalFail(_field, "must not contain leading zeroes");
	}

	for (var i = _position; i <= _length; i++) {
		var _byte = string_ord_at(_text, i);
		if (_byte < 48 || _byte > 57) {
			__BladeCanonicalFail(_field, "did not convert to canonical ASCII decimal");
		}
	}

	if (_text == "-0") {
		__BladeCanonicalFail(_field, "must encode zero as 0");
	}
	return _text;
}

/// @func BladeCanonicalIntegerString(value, minimum, maximum, field)
/// @desc Converts an exact bounded integer to canonical base-10 ASCII.
function BladeCanonicalIntegerString(_value, _minimum, _maximum, _field = "value") {
	var _integer = BladeCanonicalRequireInteger(_value, _minimum, _maximum, _field);
	return __BladeCanonicalValidateDecimal(string(_integer), _field);
}

/// @func BladeCanonicalLengthPrefix(value)
/// @desc Frames a string as its UTF-8 byte length, a colon, and the string.
function BladeCanonicalLengthPrefix(_value) {
	if (!is_string(_value)) {
		__BladeCanonicalFail("record field", "must already be a string");
	}
	return string(string_byte_length(_value)) + ":" + _value;
}

function __BladeCanonicalValidatePrefix(_prefix) {
	if (!is_string(_prefix) || string_length(_prefix) < 1) {
		__BladeCanonicalFail("record prefix", "must be a nonempty ASCII token");
	}
	if (string_byte_length(_prefix) != string_length(_prefix)) {
		__BladeCanonicalFail("record prefix", "must be ASCII");
	}

	for (var i = 1; i <= string_length(_prefix); i++) {
		var _byte = string_ord_at(_prefix, i);
		var _digit = _byte >= 48 && _byte <= 57;
		var _upper = _byte >= 65 && _byte <= 90;
		var _lower = _byte >= 97 && _byte <= 122;
		if (!_digit && !_upper && !_lower && _byte != 46 && _byte != 95) {
			__BladeCanonicalFail("record prefix", "contains a forbidden byte");
		}
	}
	return _prefix;
}

/// @func BladeCanonicalRecord(prefix, ordered_fields)
/// @desc Encodes fields in caller-supplied order without struct iteration.
function BladeCanonicalRecord(_prefix, _ordered_fields) {
	var _record = __BladeCanonicalValidatePrefix(_prefix);
	if (!is_array(_ordered_fields)) {
		__BladeCanonicalFail("ordered fields", "must be an array");
	}

	for (var i = 0; i < array_length(_ordered_fields); i++) {
		if (!is_string(_ordered_fields[i])) {
			__BladeCanonicalFail("ordered fields[" + string(i) + "]", "must already be a string");
		}
		_record += BladeCanonicalLengthPrefix(_ordered_fields[i]);
	}
	return _record;
}

/// @func BladeCanonicalRequireSha1Fingerprint(value, field)
/// @desc Validates the exact lowercase `sha1:<40 hex>` fingerprint form.
function BladeCanonicalRequireSha1Fingerprint(_value, _field = "SHA-1 fingerprint") {
	if (!is_string(_value) || string_length(_value) != 45) {
		__BladeCanonicalFail(_field, "must use sha1 followed by 40 lowercase hex digits");
	}
	if (string_copy(_value, 1, 5) != "sha1:") {
		__BladeCanonicalFail(_field, "must start with sha1:");
	}

	for (var i = 6; i <= 45; i++) {
		var _byte = string_ord_at(_value, i);
		var _digit = _byte >= 48 && _byte <= 57;
		var _lower_hex = _byte >= 97 && _byte <= 102;
		if (!_digit && !_lower_hex) {
			__BladeCanonicalFail(_field, "must contain exactly 40 lowercase hex digits");
		}
	}
	return _value;
}

/// @func BladeCanonicalHashUtf8(canonical_value)
/// @desc Returns a normalized lowercase SHA-1 of the exact UTF-8 string bytes.
function BladeCanonicalHashUtf8(_canonical_value) {
	if (!is_string(_canonical_value)) {
		__BladeCanonicalFail("canonical value", "must be a string");
	}
	var _digest = string_lower(string_replace_all(sha1_string_utf8(_canonical_value), " ", ""));
	BladeCanonicalRequireSha1Fingerprint("sha1:" + _digest, "generated SHA-1");
	return _digest;
}

/// @func BladeCanonicalRecordHash(prefix, ordered_fields)
function BladeCanonicalRecordHash(_prefix, _ordered_fields) {
	return BladeCanonicalHashUtf8(BladeCanonicalRecord(_prefix, _ordered_fields));
}
