/// @description Compact deterministic run recording and tick-driven playback.

/// Returns the discriminator that keeps replay payloads separate from other saves.
function BladeReplayFormatId() {
	return "blade.replay";
}

/// Returns the only replay schema currently understood by the runtime.
function BladeReplaySchemaVersion() {
	return 1;
}

/// Throws a replay diagnostic that identifies the rejected field or lifecycle.
function _BladeReplayFail(_field, _reason) {
	throw("BladeReplayRecording: " + _field + ": " + _reason);
}

/// Parses one canonical signed decimal without accepting alternate spellings.
function _BladeReplaySignedDecimal(_text, _field) {
	if (!is_string(_text) || string_length(_text) == 0) {
		_BladeReplayFail(_field, "must be a canonical integer");
	}

	var _start = 1;
	if (string_char_at(_text, 1) == "-") {
		if (string_length(_text) == 1) {
			_BladeReplayFail(_field, "must be a canonical integer");
		}
		_start = 2;
	}
	for (var _index = _start; _index <= string_length(_text); ++_index) {
		var _byte = string_ord_at(_text, _index);
		if (_byte < 48 || _byte > 57) {
			_BladeReplayFail(_field, "must be a canonical integer");
		}
	}

	var _integer = int64(_text);
	if (string(_integer) != _text) {
		_BladeReplayFail(_field, "must be a canonical integer");
	}
	return _integer;
}

/// Validates one exact integer field after parsing its canonical decimal text.
function _BladeReplayIntegerText(_text, _field, _minimum, _maximum) {
	return BladeCanonicalRequireInteger(
		_BladeReplaySignedDecimal(_text, _field),
		_minimum,
		_maximum,
		_field
	);
}

/// Validates a stable ship or difficulty ID without copying the content registry.
function _BladeReplayStableId(_value, _prefix, _field) {
	if (!is_string(_value) || string_length(_value) == 0
		|| string_byte_length(_value) != string_length(_value)) {
		_BladeReplayFail(_field, "must be a nonempty ASCII stable ID");
	}
	if (string_copy(_value, 1, string_length(_prefix)) != _prefix) {
		_BladeReplayFail(_field, "has the wrong stable-ID namespace");
	}

	var _parts = string_split(_value, ".");
	for (var _part_index = 0; _part_index < array_length(_parts); ++_part_index) {
		var _part = _parts[_part_index];
		if (string_length(_part) == 0) {
			_BladeReplayFail(_field, "contains an empty stable-ID component");
		}
		for (var _index = 1; _index <= string_length(_part); ++_index) {
			var _byte = string_ord_at(_part, _index);
			var _lower = _byte >= 97 && _byte <= 122;
			var _digit = _byte >= 48 && _byte <= 57;
			if ((!_lower && !_digit && _byte != 95)
				|| (_index == 1 && !_lower)) {
				_BladeReplayFail(_field, "contains a forbidden stable-ID byte");
			}
		}
	}
	return _value;
}

/// Maps the run mode enum to its stable serialized token.
function _BladeReplayModeToken(_mode) {
	if (_mode == BladeRunMode.Normal) return "normal";
	if (_mode == BladeRunMode.Practice) return "practice";
	_BladeReplayFail("run mode", "is not registered");
}

/// Parses the stable run mode token used by the replay header.
function _BladeReplayModeFromToken(_token) {
	if (_token == "normal") return BladeRunMode.Normal;
	if (_token == "practice") return BladeRunMode.Practice;
	_BladeReplayFail("run mode", "is not registered");
}

/// Requires the session contract fields that the current playback code can reproduce.
function _BladeReplaySessionContract(
	_format_version,
	_simulation_contract_version,
	_prng_version,
	_tick_rate,
	_field_prefix
) {
	if (_format_version != BladeSessionFormatVersion()) {
		_BladeReplayFail(_field_prefix, "has an unsupported session format");
	}
	if (_simulation_contract_version != BladeSimulationContractVersion()) {
		_BladeReplayFail(_field_prefix, "has an unsupported simulation contract");
	}
	if (_prng_version != BladeRandomAlgorithmVersion()) {
		_BladeReplayFail(_field_prefix, "has an unsupported random algorithm");
	}
	if (_tick_rate != BladeSimulationTickRate()) {
		_BladeReplayFail(_field_prefix, "has an unsupported simulation tick rate");
	}
}

/// Parses one compact replay input token and returns validated gameplay fields.
function _BladeReplayInputParse(_token) {
	if (!is_string(_token)) {
		_BladeReplayFail("input snapshot", "must be text");
	}
	var _parts = string_split(_token, ":");
	if (array_length(_parts) != 10 || _parts[0] != "RI1") {
		_BladeReplayFail("input snapshot", "has malformed RI1 fields");
	}

	var _frame = _BladeReplayIntegerText(
		_parts[1], "input simulation frame", 0,
		int64("9223372036854775807")
	);
	var _move_x = _BladeReplayIntegerText(_parts[2], "input movement x", -1024, 1024);
	var _move_y = _BladeReplayIntegerText(_parts[3], "input movement y", -1024, 1024);
	var _held = _BladeReplayIntegerText(
		_parts[4], "input held actions", 0, BladeInputAction.All
	);
	var _pressed = _BladeReplayIntegerText(
		_parts[5], "input pressed actions", 0, BladeInputAction.All
	);
	var _released = _BladeReplayIntegerText(
		_parts[6], "input released actions", 0, BladeInputAction.All
	);
	var _analog_flag = _BladeReplayIntegerText(
		_parts[7], "input analog presence", 0, 1
	);
	var _analog_x = _BladeReplayIntegerText(
		_parts[8], "input analog x", -32767, 32767
	);
	var _analog_y = _BladeReplayIntegerText(
		_parts[9], "input analog y", -32767, 32767
	);
	if (_analog_flag == 0 && (_analog_x != 0 || _analog_y != 0)) {
		_BladeReplayFail("input analog state", "absent analog must have zero axes");
	}

	var _canonical = "RI1:" + string(_frame)
		+ ":" + string(_move_x)
		+ ":" + string(_move_y)
		+ ":" + string(_held)
		+ ":" + string(_pressed)
		+ ":" + string(_released)
		+ ":" + string(_analog_flag)
		+ ":" + string(_analog_x)
		+ ":" + string(_analog_y);
	if (_canonical != _token) {
		_BladeReplayFail("input snapshot", "is not canonically encoded");
	}
	return {
		canonical: _canonical,
		simulation_frame: _frame,
		move_x: _move_x,
		move_y: _move_y,
		held_actions: _held,
		pressed_actions: _pressed,
		released_actions: _released,
		has_analog: _analog_flag == 1,
		analog_x: _analog_x,
		analog_y: _analog_y,
	};
}

/// Requires a recorder before its metadata or mutable input list is accessed.
function _BladeReplayRecorderRequire(_recorder) {
	if (!is_struct(_recorder)
		|| !variable_struct_exists(_recorder, "__blade_replay_recorder_version")
		|| _recorder.__blade_replay_recorder_version != 1) {
		_BladeReplayFail("recorder", "expected a version 1 replay recorder");
	}
	var _fields = [
		"format_id", "schema_version", "format_version",
		"simulation_contract_version", "prng_version", "tick_rate",
		"content_fingerprint", "run_seed", "ship_id", "difficulty_id",
		"run_mode", "input_snapshots", "last_simulation_tick",
	];
	for (var _index = 0; _index < array_length(_fields); ++_index) {
		if (!variable_struct_exists(_recorder, _fields[_index])) {
			_BladeReplayFail("recorder", "is missing " + _fields[_index]);
		}
	}
	if (!is_array(_recorder.input_snapshots)) {
		_BladeReplayFail("recorder input", "must be an array");
	}
	return _recorder;
}

/// Builds one canonical BRP1 payload from validated metadata and RI1 tokens.
function _BladeReplayEncode(
	_format_version,
	_content_fingerprint,
	_run_seed,
	_ship_id,
	_difficulty_id,
	_run_mode,
	_input_snapshots
) {
	var _session_format = BladeCanonicalRequireInteger(
		_format_version,
		BladeSessionFormatVersion(),
		BladeSessionFormatVersion(),
		"replay session format version"
	);
	var _fingerprint = BladeCanonicalRequireSha1Fingerprint(
		_content_fingerprint, "replay content fingerprint"
	);
	var _seed = BladeCanonicalRequireInteger(
		_run_seed, 0, int64("4294967295"), "replay run seed"
	);
	var _ship = _BladeReplayStableId(_ship_id, "ship.", "replay ship ID");
	var _difficulty = _BladeReplayStableId(
		_difficulty_id, "difficulty.", "replay difficulty ID"
	);
	var _mode = _BladeReplayModeToken(_run_mode);
	if (!is_array(_input_snapshots)) {
		_BladeReplayFail("replay inputs", "must be an array");
	}

	var _result = "BRP1|1|" + string(_session_format)
		+ "|" + BladeSimulationContractVersion()
		+ "|" + BladeRandomAlgorithmVersion()
		+ "|" + string(BladeSimulationTickRate())
		+ "|" + _fingerprint
		+ "|" + string(_seed)
		+ "|" + _ship
		+ "|" + _difficulty
		+ "|" + _mode
		+ "|" + string(array_length(_input_snapshots));
	for (var _index = 0; _index < array_length(_input_snapshots); ++_index) {
		var _parsed = _BladeReplayInputParse(_input_snapshots[_index]);
		if (_parsed.simulation_frame != int64(_index + 1)) {
			_BladeReplayFail(
				"replay inputs", "simulation frames must start at one and be consecutive"
			);
		}
		_result += "|" + _parsed.canonical;
	}
	return _result;
}

/// Requires an active coordinator and captures immutable attempt metadata for a recorder.
function BladeReplayRecorderCreate(_coordinator) {
	var _run = BladeRunCoordinatorSnapshot(_coordinator);
	if (_run.lifecycle != BladeRunLifecycle.Active) {
		_BladeReplayFail("recorder", "requires an active run");
	}
	var _header = BladeKernelDiagnostics(_coordinator.__kernel).header;
	_BladeReplaySessionContract(
		_header.format_version,
		_header.simulation_contract_version,
		_header.prng_version,
		_header.tick_rate,
		"run header"
	);
	return {
		__blade_replay_recorder_version: 1,
		format_id: BladeReplayFormatId(),
		schema_version: BladeReplaySchemaVersion(),
		format_version: _header.format_version,
		simulation_contract_version: _header.simulation_contract_version,
		prng_version: _header.prng_version,
		tick_rate: _header.tick_rate,
		content_fingerprint: _header.content_contract_fingerprint,
		run_seed: _header.run_seed,
		ship_id: _run.ship_id,
		difficulty_id: _run.difficulty_id,
		run_mode: _run.mode,
		input_snapshots: [],
		last_simulation_tick: int64(0),
	};
}

/// Appends one successful coordinator callback input after validating its run and tick identity.
function BladeReplayRecorderAppend(
	_recorder,
	_run_snapshot,
	_input_snapshot,
	_tick
) {
	_BladeReplayRecorderRequire(_recorder);
	if (!is_struct(_run_snapshot)
		|| _run_snapshot.lifecycle != BladeRunLifecycle.Active) {
		_BladeReplayFail("recorder run", "requires the matching active run snapshot");
	}
	if (_run_snapshot.run_seed != _recorder.run_seed
		|| _run_snapshot.ship_id != _recorder.ship_id
		|| _run_snapshot.difficulty_id != _recorder.difficulty_id
		|| _run_snapshot.mode != _recorder.run_mode) {
		_BladeReplayFail("recorder run", "does not match its starting metadata");
	}
	if (!is_struct(_tick)
		|| !variable_struct_exists(_tick, "simulation_tick")
		|| !variable_struct_exists(_tick, "domain_mask")) {
		_BladeReplayFail("recorder tick", "requires simulation tick and domain mask");
	}

	var _view = BladeInputSnapshotRead(_input_snapshot);
	var _tick_number = BladeCanonicalRequireInteger(
		_tick.simulation_tick,
		1,
		int64("9223372036854775807"),
		"recorder simulation tick"
	);
	if (_view.simulation_frame != _tick_number) {
		_BladeReplayFail("recorder tick", "input frame must match simulation tick");
	}
	var _expected = _recorder.last_simulation_tick;
	if (_expected >= int64("9223372036854775807")) {
		_BladeReplayFail("recorder tick", "simulation frame capacity is exhausted");
	}
	_expected += int64(1);
	if (_tick_number != _expected) {
		_BladeReplayFail("recorder tick", "simulation ticks must be recorded consecutively");
	}
	var _domain_mask = BladeCanonicalRequireInteger(
		_tick.domain_mask, 0, BladeClockDomain.All, "recorder domain mask"
	);
	if ((_domain_mask & BladeClockDomain.Actor) == 0
		&& (_view.pressed_actions != 0 || _view.released_actions != 0)) {
		_BladeReplayFail("recorder input", "ineligible ticks must not contain action edges");
	}

	var _canonical = "RI1:" + string(_view.simulation_frame)
		+ ":" + string(_view.move_x)
		+ ":" + string(_view.move_y)
		+ ":" + string(_view.held_actions)
		+ ":" + string(_view.pressed_actions)
		+ ":" + string(_view.released_actions)
		+ ":" + string(_view.has_analog ? 1 : 0)
		+ ":" + string(_view.analog_x)
		+ ":" + string(_view.analog_y);
	array_push(_recorder.input_snapshots, _canonical);
	_recorder.last_simulation_tick = _tick_number;
	return _canonical;
}

/// Wraps a normal coordinator callback so every executed tick is recorded at the input boundary.
function BladeReplayRecorderBind(_recorder, _simulate_callback = undefined) {
	_BladeReplayRecorderRequire(_recorder);
	if (!is_undefined(_simulate_callback) && typeof(_simulate_callback) != "method") {
		_BladeReplayFail("simulation callback", "must be a method or undefined");
	}
	var _context = {
		recorder: _recorder,
		simulate_callback: _simulate_callback,
	};
	return method(_context, function(_run_snapshot, _input_snapshot, _tick) {
		BladeReplayRecorderAppend(
			self.recorder, _run_snapshot, _input_snapshot, _tick
		);
		var _result = "";
		if (typeof(self.simulate_callback) == "method") {
			_result = self.simulate_callback(_run_snapshot, _input_snapshot, _tick);
			if (is_undefined(_result)) _result = "";
			if (!is_string(_result)) {
				_BladeReplayFail("simulation callback", "must return text or undefined");
			}
		}
		return _result;
	});
}

/// Serializes the current recorder as one immutable replay payload.
function BladeReplayRecordingSerialize(_recorder) {
	_BladeReplayRecorderRequire(_recorder);
	return _BladeReplayEncode(
		_recorder.format_version,
		_recorder.content_fingerprint,
		_recorder.run_seed,
		_recorder.ship_id,
		_recorder.difficulty_id,
		_recorder.run_mode,
		_recorder.input_snapshots
	);
}

/// Returns a detached recorder view without exposing its mutable input array.
function BladeReplayRecorderSnapshot(_recorder) {
	_BladeReplayRecorderRequire(_recorder);
	return {
		format_id: _recorder.format_id,
		schema_version: _recorder.schema_version,
		content_fingerprint: _recorder.content_fingerprint,
		run_seed: _recorder.run_seed,
		ship_id: _recorder.ship_id,
		difficulty_id: _recorder.difficulty_id,
		run_mode: _recorder.run_mode,
		input_count: int64(array_length(_recorder.input_snapshots)),
		last_simulation_tick: _recorder.last_simulation_tick,
	};
}

/// Parses and validates one saved BRP1 payload, rejecting malformed or unsupported data.
function BladeReplayRecordingParse(_text) {
	if (!is_string(_text) || string_length(_text) == 0) {
		_BladeReplayFail("recording", "must be nonempty text");
	}
	var _parts = string_split(_text, "|");
	if (array_length(_parts) < 12 || _parts[0] != "BRP1") {
		_BladeReplayFail("recording", "has malformed BRP1 fields");
	}

	var _schema = _BladeReplayIntegerText(
		_parts[1], "replay schema version", BladeReplaySchemaVersion(), BladeReplaySchemaVersion()
	);
	var _format_version = _BladeReplayIntegerText(
		_parts[2],
		"replay session format version",
		BladeSessionFormatVersion(),
		BladeSessionFormatVersion()
	);
	if (_parts[3] != BladeSimulationContractVersion()) {
		_BladeReplayFail("recording", "has an unsupported simulation contract");
	}
	if (_parts[4] != BladeRandomAlgorithmVersion()) {
		_BladeReplayFail("recording", "has an unsupported random algorithm");
	}
	var _tick_rate = _BladeReplayIntegerText(
		_parts[5], "replay tick rate", BladeSimulationTickRate(), BladeSimulationTickRate()
	);
	var _fingerprint = BladeCanonicalRequireSha1Fingerprint(
		_parts[6], "replay content fingerprint"
	);
	var _seed = _BladeReplayIntegerText(
		_parts[7], "replay run seed", 0, int64("4294967295")
	);
	var _ship = _BladeReplayStableId(_parts[8], "ship.", "replay ship ID");
	var _difficulty = _BladeReplayStableId(
		_parts[9], "difficulty.", "replay difficulty ID"
	);
	var _mode = _BladeReplayModeFromToken(_parts[10]);
	var _count = _BladeReplayIntegerText(
		_parts[11], "replay input count", 0,
		int64("9223372036854775807")
	);
	if (_count > int64(string_length(_text))) {
		_BladeReplayFail("replay input count", "is larger than the payload can contain");
	}
	if (array_length(_parts) != 12 + _count) {
		_BladeReplayFail("replay input count", "does not match payload fields");
	}

	var _inputs = [];
	for (var _index = 0; _index < _count; ++_index) {
		var _parsed = _BladeReplayInputParse(_parts[12 + _index]);
		if (_parsed.simulation_frame != int64(_index + 1)) {
			_BladeReplayFail(
				"replay input", "simulation frames must start at one and be consecutive"
			);
		}
		array_push(_inputs, _parsed.canonical);
	}

	var _canonical = _BladeReplayEncode(
		_format_version,
		_fingerprint, _seed, _ship, _difficulty, _mode, _inputs
	);
	if (_canonical != _text) {
		_BladeReplayFail("recording", "is not canonically encoded");
	}
	return {
		format_id: BladeReplayFormatId(),
		schema_version: _schema,
		format_version: _format_version,
		simulation_contract_version: _parts[3],
		prng_version: _parts[4],
		tick_rate: _tick_rate,
		content_fingerprint: _fingerprint,
		run_seed: _seed,
		ship_id: _ship,
		difficulty_id: _difficulty,
		run_mode: _mode,
		input_snapshots: _inputs,
		input_count: _count,
		canonical: _canonical,
		hash: BladeCanonicalHashUtf8(_canonical),
	};
}

/// Returns the validated immutable saved payload without exposing parsed mutable fields.
function BladeReplayRecordingCanonical(_text) {
	return BladeReplayRecordingParse(_text).canonical;
}

/// Hashes the exact canonical saved payload for catalog identity and diagnostics.
function BladeReplayRecordingHash(_text) {
	return BladeReplayRecordingParse(_text).hash;
}

/// Requires a playback owner before its cursor or coordinator can be used.
function _BladeReplayPlaybackRequire(_playback) {
	if (!is_struct(_playback)
		|| !variable_struct_exists(_playback, "__blade_replay_playback_version")
		|| _playback.__blade_replay_playback_version != 1
		|| !variable_struct_exists(_playback, "recording")
		|| !variable_struct_exists(_playback, "coordinator")
		|| !variable_struct_exists(_playback, "next_input_index")) {
		_BladeReplayFail("playback", "expected a complete version 1 playback owner");
	}
}

/// Creates a fresh coordinator whose run metadata matches one parsed recording.
function BladeReplayPlaybackCreate(
	_recording_text,
	_content_id_predicate,
	_max_catch_up_ticks = 8,
	_gameplay_plane = undefined
) {
	var _recording = BladeReplayRecordingParse(_recording_text);
	var _coordinator = BladeRunCoordinatorCreate(
		_recording.content_fingerprint,
		_content_id_predicate,
		_recording.ship_id,
		_recording.difficulty_id,
		_recording.run_mode,
		_recording.run_seed,
		_max_catch_up_ticks,
		_gameplay_plane
	);
	return {
		__blade_replay_playback_version: 1,
		recording: _recording,
		coordinator: _coordinator,
		next_input_index: int64(0),
	};
}

/// Returns whether every recorded simulation tick has been consumed.
function BladeReplayPlaybackFinished(_playback) {
	_BladeReplayPlaybackRequire(_playback);
	return _playback.next_input_index >= _playback.recording.input_count;
}

/// Returns the coordinator for explicit stage attachment by an integration owner.
function BladeReplayPlaybackCoordinator(_playback) {
	_BladeReplayPlaybackRequire(_playback);
	return _playback.coordinator;
}

/// Converts one compact gameplay token to a neutral full snapshot for the kernel seam.
function _BladeReplayInputSnapshot(_token) {
	var _input = _BladeReplayInputParse(_token);
	return BladeInputSnapshotCreateRecorded(
		_input.simulation_frame,
		_input.move_x,
		_input.move_y,
		_input.held_actions,
		_input.pressed_actions,
		_input.released_actions,
		_input.has_analog,
		_input.analog_x,
		_input.analog_y
	);
}

/// Steps exactly one recorded input snapshot through the existing coordinator callback path.
function BladeReplayPlaybackStep(
	_playback,
	_eligibility,
	_simulate_callback = undefined
) {
	_BladeReplayPlaybackRequire(_playback);
	if (BladeReplayPlaybackFinished(_playback)) {
		_BladeReplayFail("playback", "input stream is exhausted");
	}
	var _index = _playback.next_input_index;
	var _snapshot = _BladeReplayInputSnapshot(
		_playback.recording.input_snapshots[_index]
	);
	var _result = BladeRunCoordinatorStepRecorded(
		_playback.coordinator,
		_snapshot,
		_eligibility,
		_simulate_callback
	);
	_playback.next_input_index = _index + int64(1);
	_result.replay_input_index = _index;
	_result.replay_input_snapshot = _snapshot;
	return _result;
}

/// Consumes the complete recording through exact simulation ticks without a wall-time clock.
function BladeReplayPlaybackRunToEnd(
	_playback,
	_eligibility,
	_simulate_callback = undefined
) {
	_BladeReplayPlaybackRequire(_playback);
	var _ran = int64(0);
	while (!BladeReplayPlaybackFinished(_playback)) {
		BladeReplayPlaybackStep(_playback, _eligibility, _simulate_callback);
		_ran += int64(1);
	}
	return {
		ticks_run: _ran,
		input_count: _playback.recording.input_count,
		finished: true,
		run: BladeRunCoordinatorSnapshot(_playback.coordinator),
	};
}

/// Completes a replayed normal or practice attempt only after its entire input stream was consumed.
function BladeReplayPlaybackComplete(_playback) {
	_BladeReplayPlaybackRequire(_playback);
	if (!BladeReplayPlaybackFinished(_playback)) {
		_BladeReplayFail("playback", "cannot complete before input stream exhaustion");
	}
	return BladeRunCoordinatorComplete(_playback.coordinator);
}

/// Returns a detached replay cursor, metadata, and current run state.
function BladeReplayPlaybackSnapshot(_playback) {
	_BladeReplayPlaybackRequire(_playback);
	return {
		format_id: _playback.recording.format_id,
		schema_version: _playback.recording.schema_version,
		recording_hash: _playback.recording.hash,
		input_count: _playback.recording.input_count,
		next_input_index: _playback.next_input_index,
		finished: BladeReplayPlaybackFinished(_playback),
		run: BladeRunCoordinatorSnapshot(_playback.coordinator),
	};
}

/// Returns the complete current coordinator canonical state for replay comparison.
function BladeReplayPlaybackCanonical(_playback) {
	_BladeReplayPlaybackRequire(_playback);
	return BladeRunCoordinatorCanonical(_playback.coordinator);
}

/// Hashes the current coordinator state for a compact replay comparison.
function BladeReplayPlaybackHash(_playback) {
	return BladeCanonicalHashUtf8(BladeReplayPlaybackCanonical(_playback));
}
