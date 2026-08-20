/// @description Semantic input sampling and immutable per-tick snapshot values.

enum BladeInputAction {
	Fire = 1,
	Bomb = 2,
	Focus = 4,
	Pause = 8,
	Confirm = 16,
	Cancel = 32,
	All = 63
}

enum BladePromptDevice {
	Unknown = 0,
	KeyboardMouse = 1,
	Gamepad = 2
}

// Rejects values that are not version 1 samplers before sampler fields are read or changed.
function _BladeInputRequireSampler(_sampler) {
	if (!is_struct(_sampler)
		|| !variable_struct_exists(_sampler, "__blade_input_sampler_version")
		|| _sampler.__blade_input_sampler_version != 1) {
		throw("BladeInputSnapshot: expected a version 1 input sampler");
	}
}

// Stops a consecutive-frame addition at the signed int64 boundary before overflow can occur.
function _BladeInputRequireFrameCapacity(_value, _field) {
	if (_value >= int64("9223372036854775807")) {
		throw("BladeInputSnapshot: " + _field + " exceeds signed int64 range");
	}
}

// Converts supported exact numeric values to int64 and enforces the field's closed range.
// The exact-Real check prevents rounded or fractional input from entering a snapshot.
function _BladeInputInteger(_value, _field, _minimum, _maximum) {
	var _type = typeof(_value);
	var _integer;
	if (_type == "int32" || _type == "int64") {
		_integer = int64(_value);
	} else if (_type == "number") {
		if (is_nan(_value) || is_infinity(_value)
			|| floor(_value) != _value
			|| abs(_value) > 9007199254740991) {
			throw("BladeInputSnapshot: " + _field + " must be an exact finite integer");
		}
		_integer = int64(_value);
	} else {
		throw("BladeInputSnapshot: " + _field + " must be an integer");
	}

	if (_integer < _minimum || _integer > _maximum) {
		throw(
			"BladeInputSnapshot: " + _field + " must be in ["
			+ string(_minimum) + ", " + string(_maximum) + "]"
		);
	}
	return _integer;
}

// Retrieves a required raw-state field; the field-specific validators constrain its returned value.
function _BladeInputRawField(_raw, _name) {
	if (!is_struct(_raw) || !variable_struct_exists(_raw, _name)) {
		throw("BladeInputSnapshot: raw state requires scalar field " + _name);
	}
	return variable_struct_get(_raw, _name);
}

// Rejects values other than GML's true and false flags.
// Accepted flags are normalized with bool() before storage or encoding.
function _BladeInputBool(_value, _field) {
	if (_value != true && _value != false) {
		throw("BladeInputSnapshot: " + _field + " must be boolean");
	}
	return bool(_value);
}

// Parses optional-minus decimal text and requires an exact int64 string round trip.
// This rejects alternate spellings such as plus signs and redundant leading zeroes.
function _BladeInputSignedDecimal(_text, _field) {
	if (!is_string(_text) || string_length(_text) == 0) {
		throw("BladeInputSnapshot: " + _field + " is not a canonical integer");
	}

	var _start = 1;
	if (string_char_at(_text, 1) == "-") {
		if (string_length(_text) == 1) {
			throw("BladeInputSnapshot: " + _field + " is not a canonical integer");
		}
		_start = 2;
	}
	for (var _index = _start; _index <= string_length(_text); ++_index) {
		var _byte = string_ord_at(_text, _index);
		if (_byte < 48 || _byte > 57) {
			throw("BladeInputSnapshot: " + _field + " is not a canonical integer");
		}
	}

	var _integer = int64(_text);
	if (string(_integer) != _text) {
		throw("BladeInputSnapshot: " + _field + " is not a canonical integer");
	}
	return _integer;
}

// Encodes every authoritative input field in a fixed-order BIS1 value string.
// The string representation prevents later struct mutation from changing an earlier snapshot.
function _BladeInputSnapshotEncode(
	_simulation_frame,
	_presentation_frame,
	_move_x,
	_move_y,
	_held_actions,
	_pressed_actions,
	_released_actions,
	_prompt_device,
	_has_analog,
	_analog_x,
	_analog_y
) {
	var _analog_flag = 0;
	if (_has_analog) {
		_analog_flag = 1;
	}
	return "BIS1|" + string(_simulation_frame)
		+ "|" + string(_presentation_frame)
		+ "|" + string(_move_x)
		+ "|" + string(_move_y)
		+ "|" + string(_held_actions)
		+ "|" + string(_pressed_actions)
		+ "|" + string(_released_actions)
		+ "|" + string(_prompt_device)
		+ "|" + string(_analog_flag)
		+ "|" + string(_analog_x)
		+ "|" + string(_analog_y);
}

/// @func BladeInputRawStateCreate(move_x, move_y, held_actions, prompt_device, has_analog, analog_x, analog_y)
/// @description Create an injected semantic state. No platform key codes are retained.
/// Validates the semantic scalar ranges and forces both analog axes to zero when analog is absent.
function BladeInputRawStateCreate(
	_move_x,
	_move_y,
	_held_actions,
	_prompt_device = BladePromptDevice.Unknown,
	_has_analog = false,
	_analog_x = 0,
	_analog_y = 0
) {
	var _movement_x = _BladeInputInteger(_move_x, "movement x", -1024, 1024);
	var _movement_y = _BladeInputInteger(_move_y, "movement y", -1024, 1024);
	var _held = _BladeInputInteger(_held_actions, "held actions", 0, BladeInputAction.All);
	var _device = _BladeInputInteger(
		_prompt_device,
		"prompt device",
		BladePromptDevice.Unknown,
		BladePromptDevice.Gamepad
	);
	var _analog_present = _BladeInputBool(_has_analog, "analog presence");
	var _axis_x = _BladeInputInteger(_analog_x, "analog x", -32767, 32767);
	var _axis_y = _BladeInputInteger(_analog_y, "analog y", -32767, 32767);
	if (!_analog_present) {
		_axis_x = int64(0);
		_axis_y = int64(0);
	}

	return {
		move_x: _movement_x,
		move_y: _movement_y,
		held_actions: _held,
		prompt_device: _device,
		has_analog: _analog_present,
		analog_x: _axis_x,
		analog_y: _axis_y,
	};
}

/// @func BladeInputSamplerCreate()
/// Creates an unsampled input latch with frame sentinels at -1 and all semantic state cleared.
function BladeInputSamplerCreate() {
	return {
		__blade_input_sampler_version: 1,
		has_sample: false,
		presentation_frame: int64(-1),
		last_simulation_frame: int64(-1),
		move_x: int64(0),
		move_y: int64(0),
		held_actions: int64(0),
		pending_pressed_actions: int64(0),
		pending_released_actions: int64(0),
		prompt_device: int64(BladePromptDevice.Unknown),
		has_analog: false,
		analog_x: int64(0),
		analog_y: int64(0),
	};
}

/// @func BladeInputSamplerReset(sampler)
/// Restores an existing sampler to the same unsampled state without replacing its struct.
function BladeInputSamplerReset(_sampler) {
	_BladeInputRequireSampler(_sampler);
	_sampler.has_sample = false;
	_sampler.presentation_frame = int64(-1);
	_sampler.last_simulation_frame = int64(-1);
	_sampler.move_x = int64(0);
	_sampler.move_y = int64(0);
	_sampler.held_actions = int64(0);
	_sampler.pending_pressed_actions = int64(0);
	_sampler.pending_released_actions = int64(0);
	_sampler.prompt_device = int64(BladePromptDevice.Unknown);
	_sampler.has_analog = false;
	_sampler.analog_x = int64(0);
	_sampler.analog_y = int64(0);
	return _sampler;
}

/// @func BladeInputSamplePresentation(sampler, presentation_frame, raw_state)
/// @description Sample exactly once for each consecutive presentation frame.
/// Validates the full sample before mutation, then OR-latches edges and stores the latest state.
/// OR-latching preserves short transitions until an eligible tick consumes them.
function BladeInputSamplePresentation(_sampler, _presentation_frame, _raw_state) {
	_BladeInputRequireSampler(_sampler);
	var _frame = _BladeInputInteger(
		_presentation_frame,
		"presentation frame",
		0,
		int64("9223372036854775807")
	);
	if (_sampler.has_sample) {
		_BladeInputRequireFrameCapacity(
			_sampler.presentation_frame,
			"presentation frame"
		);
		if (_frame != _sampler.presentation_frame + int64(1)) {
			throw("BladeInputSnapshot: presentation frames must be sampled once and consecutively");
		}
	}

	var _movement_x = _BladeInputInteger(
		_BladeInputRawField(_raw_state, "move_x"),
		"movement x",
		-1024,
		1024
	);
	var _movement_y = _BladeInputInteger(
		_BladeInputRawField(_raw_state, "move_y"),
		"movement y",
		-1024,
		1024
	);
	var _held = _BladeInputInteger(
		_BladeInputRawField(_raw_state, "held_actions"),
		"held actions",
		0,
		BladeInputAction.All
	);
	var _device = _BladeInputInteger(
		_BladeInputRawField(_raw_state, "prompt_device"),
		"prompt device",
		BladePromptDevice.Unknown,
		BladePromptDevice.Gamepad
	);
	var _analog_present = _BladeInputBool(
		_BladeInputRawField(_raw_state, "has_analog"),
		"analog presence"
	);
	var _axis_x = _BladeInputInteger(
		_BladeInputRawField(_raw_state, "analog_x"),
		"analog x",
		-32767,
		32767
	);
	var _axis_y = _BladeInputInteger(
		_BladeInputRawField(_raw_state, "analog_y"),
		"analog y",
		-32767,
		32767
	);
	if (!_analog_present) {
		_axis_x = int64(0);
		_axis_y = int64(0);
	}

	var _pressed = (_held & ~_sampler.held_actions) & BladeInputAction.All;
	var _released = (_sampler.held_actions & ~_held) & BladeInputAction.All;
	_sampler.pending_pressed_actions = (
		_sampler.pending_pressed_actions | _pressed
	) & BladeInputAction.All;
	_sampler.pending_released_actions = (
		_sampler.pending_released_actions | _released
	) & BladeInputAction.All;

	_sampler.has_sample = true;
	_sampler.presentation_frame = _frame;
	_sampler.move_x = _movement_x;
	_sampler.move_y = _movement_y;
	_sampler.held_actions = _held;
	_sampler.prompt_device = _device;
	_sampler.has_analog = _analog_present;
	_sampler.analog_x = _axis_x;
	_sampler.analog_y = _axis_y;
	return _sampler;
}

/// @func BladeInputSnapshotPublishTick(sampler, simulation_frame, input_eligible)
/// @returns {String} Immutable authoritative version 1 snapshot.
/// Publishes the next simulation frame as a BIS1 string and advances the publication frontier.
/// Only eligible ticks copy and clear pending edges, so ineligible ticks do not lose them.
function BladeInputSnapshotPublishTick(_sampler, _simulation_frame, _input_eligible) {
	_BladeInputRequireSampler(_sampler);
	if (!_sampler.has_sample) {
		throw("BladeInputSnapshot: cannot publish before presentation input is sampled");
	}
	var _frame = _BladeInputInteger(
		_simulation_frame,
		"simulation frame",
		0,
		int64("9223372036854775807")
	);
	if (_sampler.last_simulation_frame >= 0) {
		_BladeInputRequireFrameCapacity(
			_sampler.last_simulation_frame,
			"simulation frame"
		);
		if (_frame != _sampler.last_simulation_frame + int64(1)) {
			throw("BladeInputSnapshot: simulation frames must be published consecutively");
		}
	}
	var _eligible = _BladeInputBool(_input_eligible, "input eligibility");

	var _pressed = int64(0);
	var _released = int64(0);
	if (_eligible) {
		_pressed = _sampler.pending_pressed_actions;
		_released = _sampler.pending_released_actions;
		_sampler.pending_pressed_actions = int64(0);
		_sampler.pending_released_actions = int64(0);
	}
	_sampler.last_simulation_frame = _frame;

	return _BladeInputSnapshotEncode(
		_frame,
		_sampler.presentation_frame,
		_sampler.move_x,
		_sampler.move_y,
		_sampler.held_actions,
		_pressed,
		_released,
		_sampler.prompt_device,
		_sampler.has_analog,
		_sampler.analog_x,
		_sampler.analog_y
	);
}

/// @func BladeInputSnapshotRead(snapshot)
/// @returns {Struct} A fresh mutable view; mutating it cannot affect the snapshot string.
/// Parses, range-checks, and re-encodes a BIS1 string before returning a fresh field view.
/// The re-encode comparison rejects valid-looking text that is not the one canonical spelling.
function BladeInputSnapshotRead(_snapshot) {
	if (!is_string(_snapshot)) {
		throw("BladeInputSnapshot: snapshot must be an immutable string");
	}
	var _parts = string_split(_snapshot, "|");
	if (array_length(_parts) != 12 || _parts[0] != "BIS1") {
		throw("BladeInputSnapshot: malformed version 1 snapshot");
	}

	var _simulation_frame = _BladeInputSignedDecimal(_parts[1], "simulation frame");
	var _presentation_frame = _BladeInputSignedDecimal(_parts[2], "presentation frame");
	var _move_x = _BladeInputSignedDecimal(_parts[3], "movement x");
	var _move_y = _BladeInputSignedDecimal(_parts[4], "movement y");
	var _held = _BladeInputSignedDecimal(_parts[5], "held actions");
	var _pressed = _BladeInputSignedDecimal(_parts[6], "pressed actions");
	var _released = _BladeInputSignedDecimal(_parts[7], "released actions");
	var _device = _BladeInputSignedDecimal(_parts[8], "prompt device");
	var _analog_flag = _BladeInputSignedDecimal(_parts[9], "analog presence");
	var _analog_x = _BladeInputSignedDecimal(_parts[10], "analog x");
	var _analog_y = _BladeInputSignedDecimal(_parts[11], "analog y");

	_simulation_frame = _BladeInputInteger(
		_simulation_frame,
		"simulation frame",
		0,
		int64("9223372036854775807")
	);
	_presentation_frame = _BladeInputInteger(
		_presentation_frame,
		"presentation frame",
		0,
		int64("9223372036854775807")
	);
	_move_x = _BladeInputInteger(_move_x, "movement x", -1024, 1024);
	_move_y = _BladeInputInteger(_move_y, "movement y", -1024, 1024);
	_held = _BladeInputInteger(_held, "held actions", 0, BladeInputAction.All);
	_pressed = _BladeInputInteger(_pressed, "pressed actions", 0, BladeInputAction.All);
	_released = _BladeInputInteger(_released, "released actions", 0, BladeInputAction.All);
	_device = _BladeInputInteger(
		_device,
		"prompt device",
		BladePromptDevice.Unknown,
		BladePromptDevice.Gamepad
	);
	_analog_flag = _BladeInputInteger(_analog_flag, "analog presence", 0, 1);
	_analog_x = _BladeInputInteger(_analog_x, "analog x", -32767, 32767);
	_analog_y = _BladeInputInteger(_analog_y, "analog y", -32767, 32767);
	if (_analog_flag == 0 && (_analog_x != 0 || _analog_y != 0)) {
		throw("BladeInputSnapshot: absent analog state must have zero axes");
	}

	var _view = {
		simulation_frame: _simulation_frame,
		presentation_frame: _presentation_frame,
		move_x: _move_x,
		move_y: _move_y,
		held_actions: _held,
		pressed_actions: _pressed,
		released_actions: _released,
		prompt_device: _device,
		has_analog: _analog_flag == 1,
		analog_x: _analog_x,
		analog_y: _analog_y,
	};
	var _canonical = _BladeInputSnapshotEncode(
		_view.simulation_frame,
		_view.presentation_frame,
		_view.move_x,
		_view.move_y,
		_view.held_actions,
		_view.pressed_actions,
		_view.released_actions,
		_view.prompt_device,
		_view.has_analog,
		_view.analog_x,
		_view.analog_y
	);
	if (_canonical != _snapshot) {
		throw("BladeInputSnapshot: snapshot is not canonically encoded");
	}
	return _view;
}

/// @func BladeInputSnapshotCanonical(snapshot)
/// @returns {String} The validated immutable authoritative value.
/// Runs full reader validation and returns the original string.
/// No defensive copy is needed because strings are not mutable views.
function BladeInputSnapshotCanonical(_snapshot) {
	BladeInputSnapshotRead(_snapshot);
	return _snapshot;
}

/// @func BladeInputSamplerGetPendingEdges(sampler)
/// @returns {Struct} Fresh diagnostics without consuming pending edges.
/// Copies both pending edge masks into a diagnostic struct without clearing the sampler's latches.
function BladeInputSamplerGetPendingEdges(_sampler) {
	_BladeInputRequireSampler(_sampler);
	return {
		pressed_actions: _sampler.pending_pressed_actions,
		released_actions: _sampler.pending_released_actions,
	};
}
