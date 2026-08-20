/// Versioned named xoshiro128** streams for deterministic gameplay.

/// Prepends the module and field names to the reason, then throws the combined diagnostic.
function __BladeRandomFail(_field, _reason) {
	throw "BladeRandomStream: " + _field + ": " + _reason;
}

/// Returns the low-32-bit mask applied after shifts, products, and lane transitions.
function __BladeRandomU32Mask() {
	return int64("4294967295");
}

/// Returns 2^32 for seed wrapping and unbiased bounded sampling.
function __BladeRandomU32Modulus() {
	return int64("4294967296");
}

/// @func BladeRandomAlgorithmVersion()
/// Supplies the version string embedded in stream derivation, diagnostics, and the session header.
function BladeRandomAlgorithmVersion() {
	return "blade.xoshiro128ss.v1";
}

/// @func BladeRandomStreamNames()
/// @desc Returns the fixed stream registry in diagnostic order.
/// Returns a fresh array whose five entries are also the only names accepted for state derivation.
function BladeRandomStreamNames() {
	return [
		"stage_schedule",
		"enemy_spawn_variant",
		"pattern_geometry",
		"drop_selection",
		"cosmetic_effects"
	];
}

/// Accepts only an exact registry entry so misspellings cannot create new streams.
function __BladeRandomRequireStreamName(_stream_name) {
	if (!is_string(_stream_name)) {
		__BladeRandomFail("stream name", "must be a string");
	}
	var _names = BladeRandomStreamNames();
	for (var i = 0; i < array_length(_names); i++) {
		if (_stream_name == _names[i]) {
			return _stream_name;
		}
	}
	__BladeRandomFail("stream name", "is not registered: " + _stream_name);
}

/// @func BladeRandomNormalizeSeed(run_seed)
/// @desc Maps an exact signed integer into the canonical unsigned 32-bit domain.
/// Validates before modulo 2^32 and corrects a negative remainder so seeds with the
/// same low 32 bits share one stored value.
function BladeRandomNormalizeSeed(_run_seed) {
	var _type = typeof(_run_seed);
	var _integer;

	if (_type == "int32" || _type == "int64") {
		_integer = int64(_run_seed);
	} else if (_type == "number") {
		if (is_nan(_run_seed) || is_infinity(_run_seed)) {
			__BladeRandomFail("run seed", "must be finite");
		}
		if (floor(_run_seed) != _run_seed) {
			__BladeRandomFail("run seed", "must not contain a fractional part");
		}
		if (abs(_run_seed) > 9007199254740991) {
			__BladeRandomFail("run seed", "real-valued integers must be exactly representable");
		}
		_integer = int64(_run_seed);
	} else {
		__BladeRandomFail("run seed", "must be an integer");
	}

	var _modulus = __BladeRandomU32Modulus();
	var _normalized = _integer % _modulus;
	if (_normalized < 0) {
		_normalized += _modulus;
	}
	return _normalized;
}

/// Converts one lowercase hexadecimal digest byte to its numeric nibble.
function __BladeRandomHexNibble(_byte) {
	if (_byte >= 48 && _byte <= 57) {
		return _byte - 48;
	}
	if (_byte >= 97 && _byte <= 102) {
		return _byte - 87;
	}
	__BladeRandomFail("derived seed", "SHA-1 returned a non-hex byte");
}

/// Folds eight digest characters from left to right into one big-endian unsigned 32-bit lane.
function __BladeRandomHexWord(_digest, _start) {
	var _word = int64(0);
	for (var i = 0; i < 8; i++) {
		_word = (_word * int64(16)) + __BladeRandomHexNibble(string_ord_at(_digest, _start + i));
	}
	return _word;
}

/// Hashes version, normalized seed, and name with explicit line feeds, then uses the
/// first 128 digest bits as four lanes.
function __BladeRandomDeriveState(_run_seed, _stream_name) {
	var _seed_text = BladeCanonicalIntegerString(
		_run_seed,
		int64(0),
		__BladeRandomU32Mask(),
		"normalized run seed"
	);
	var _derivation = BladeRandomAlgorithmVersion()
		+ "\n" + _seed_text
		+ "\n" + _stream_name
		+ "\n";
	var _digest = BladeCanonicalHashUtf8(_derivation);
	var _state = [
		__BladeRandomHexWord(_digest, 1),
		__BladeRandomHexWord(_digest, 9),
		__BladeRandomHexWord(_digest, 17),
		__BladeRandomHexWord(_digest, 25)
	];

	// The all-zero xoshiro state is absorbing. Compare each lane directly so this
	// exceptional digest case remains visible instead of hiding it in a bitwise expression.
	var _all_zero_state = _state[0] == 0
		&& _state[1] == 0
		&& _state[2] == 0
		&& _state[3] == 0;
	if (_all_zero_state) {
		_state[0] = int64("2654435769");
	}
	return _state;
}

/// Multiplies 16-bit halves and keeps the low 32 bits, avoiding a full unsigned
/// product that exceeds signed int64.
function __BladeRandomMultiplyU32(_left, _right) {
	var _low_mask = int64(65535);
	var _left_low = _left & _low_mask;
	var _left_high = (_left >> 16) & _low_mask;
	var _right_low = _right & _low_mask;
	var _right_high = (_right >> 16) & _low_mask;
	var _low_product = _left_low * _right_low;
	var _cross_product = (_left_low * _right_high) + (_left_high * _right_low);
	return (_low_product + ((_cross_product & _low_mask) << 16)) & __BladeRandomU32Mask();
}

/// Combines opposite int64 shifts, then masks the fixed 7- and 11-bit rotations to
/// one 32-bit lane.
function __BladeRandomRotateLeftU32(_value, _amount) {
	return ((_value << _amount) | (_value >> (32 - _amount))) & __BladeRandomU32Mask();
}

/// @func BladeRandomStream(run_seed, stream_name)
/// Stores a validated name, normalized seed, derived initial lanes, mutable lane
/// copy, and zero draw count.
function BladeRandomStream(_run_seed, _stream_name) constructor {
	__run_seed = BladeRandomNormalizeSeed(_run_seed);
	__stream_name = __BladeRandomRequireStreamName(_stream_name);
	__initial_state = __BladeRandomDeriveState(__run_seed, __stream_name);
	__state = [__initial_state[0], __initial_state[1], __initial_state[2], __initial_state[3]];
	__draw_count = int64(0);

	/// @func get_algorithm_version()
	/// Reports the same algorithm version used when this stream's initial state was derived.
	function get_algorithm_version() {
		return BladeRandomAlgorithmVersion();
	}

	/// @func get_stream_name()
	/// Returns the name field; the constructor accepted only a registry entry initially.
	function get_stream_name() {
		return __stream_name;
	}

	/// @func get_run_seed()
	/// Returns the seed field; the constructor normalized its initial value to u32 range.
	function get_run_seed() {
		return __run_seed;
	}

	/// @func get_initial_state()
	/// Returns a new array; mutating that result does not change the lanes retained for reset.
	function get_initial_state() {
		return [__initial_state[0], __initial_state[1], __initial_state[2], __initial_state[3]];
	}

	/// @func get_state()
	/// Returns a new array; mutating that result does not change the live generator lanes.
	function get_state() {
		return [__state[0], __state[1], __state[2], __state[3]];
	}

	/// @func get_draw_count()
	/// Returns the count that next_u32 increments after each completed state transition.
	function get_draw_count() {
		return __draw_count;
	}

	/// @func diagnostics()
	/// Builds fresh metadata and copied state arrays; mutating the result does not change the stream.
	function diagnostics() {
		return {
			algorithm_version: BladeRandomAlgorithmVersion(),
			stream_name: __stream_name,
			run_seed: __run_seed,
			initial_state: get_initial_state(),
			state: get_state(),
			draw_count: __draw_count,
		};
	}

	/// @func reset()
	/// Restores copied initial lanes and a zero draw count, then reports the reset state.
	function reset() {
		__state = [__initial_state[0], __initial_state[1], __initial_state[2], __initial_state[3]];
		__draw_count = int64(0);
		return diagnostics();
	}

	/// @func next_u32()
	/// Checks count capacity, then computes one xoshiro128** output and state transition.
	function next_u32() {
		if (__draw_count == int64("9223372036854775807")) {
			__BladeRandomFail("draw count", "cannot exceed signed int64 range");
		}

		var _s0 = __state[0];
		var _s1 = __state[1];
		var _s2 = __state[2];
		var _s3 = __state[3];
		// The ** scrambler is rotl32(s1 * 5, 7) * 9, reduced after each product.
		var _result = __BladeRandomMultiplyU32(
			__BladeRandomRotateLeftU32(__BladeRandomMultiplyU32(_s1, int64(5)), 7),
			int64(9)
		);
		var _shifted = (_s1 << 9) & __BladeRandomU32Mask();

		// Apply the xor/shift transition to old lanes and mask each new lane to u32.
		_s2 = (_s2 ^ _s0) & __BladeRandomU32Mask();
		_s3 = (_s3 ^ _s1) & __BladeRandomU32Mask();
		_s1 = (_s1 ^ _s2) & __BladeRandomU32Mask();
		_s0 = (_s0 ^ _s3) & __BladeRandomU32Mask();
		_s2 = (_s2 ^ _shifted) & __BladeRandomU32Mask();
		_s3 = __BladeRandomRotateLeftU32(_s3, 11);

		__state = [_s0, _s1, _s2, _s3];
		__draw_count += int64(1);
		return _result;
	}

	/// @func next_unit()
	/// @desc Returns a real in the half-open interval [0, 1).
	/// Divides one unsigned draw by 2^32, so even the largest output stays below one.
	function next_unit() {
		return real(next_u32()) / 4294967296.0;
	}

	/// @func next_range(minimum, maximum_exclusive)
	/// @desc Returns an unbiased integer in [minimum, maximum_exclusive).
	/// Validates before drawing, then rejects the short tail to avoid modulo bias.
	function next_range(_minimum, _maximum_exclusive) {
		var _safe_minimum = int64("-9007199254740991");
		var _safe_maximum = int64("9007199254740991");
		var _minimum_integer = BladeCanonicalRequireInteger(
			_minimum,
			_safe_minimum,
			_safe_maximum,
			"range minimum"
		);
		var _maximum_integer = BladeCanonicalRequireInteger(
			_maximum_exclusive,
			_safe_minimum,
			_safe_maximum,
			"range maximum"
		);
		var _span = _maximum_integer - _minimum_integer;
		var _modulus = __BladeRandomU32Modulus();

		if (_span < 1) {
			__BladeRandomFail("range", "maximum must be greater than minimum");
		}
		if (_span > _modulus) {
			__BladeRandomFail("range", "span cannot exceed 2^32");
		}

		// Values below this divisible prefix can be reduced modulo span without bias.
		var _limit = _modulus - (_modulus % _span);
		var _raw;
		do {
			_raw = next_u32();
		} until (_raw < _limit);
		return _minimum_integer + (_raw % _span);
	}
}
