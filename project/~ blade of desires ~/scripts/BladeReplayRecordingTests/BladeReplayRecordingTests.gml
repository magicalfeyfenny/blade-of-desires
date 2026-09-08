/// @description Focused recording, malformed-payload, and tick-driven playback tests.

/// Keeps replay tests on the same stable selection IDs used by the run coordinator.
function _BladeReplayTestKnownContent(_content_id) {
	return _content_id == "ship.maynii"
		|| _content_id == "difficulty.normal";
}

/// Creates one active run with the production coordinator and deterministic session header.
function _BladeReplayTestCreate() {
	return BladeRunCoordinatorCreate(
		"sha1:1c7a96f800d7ac228659dd0759706ed6833bb92c",
		method({}, _BladeReplayTestKnownContent),
		"ship.maynii",
		"difficulty.normal",
		BladeRunMode.Normal,
		305419896,
		8
	);
}

/// Builds equivalent semantic input with a caller-selected presentation device.
function _BladeReplayTestInputs(_prompt_device) {
	return [
		BladeInputRawStateCreate(
			1024, 0, BladeInputAction.Fire, _prompt_device, false, 0, 0
		),
		BladeInputRawStateCreate(
			0, -512,
			BladeInputAction.Fire | BladeInputAction.Focus,
			_prompt_device,
			true,
			12000,
			-4000
		),
		BladeInputRawStateCreate(
			-1024, 0, BladeInputAction.Focus, _prompt_device, false, 0, 0
		),
		BladeInputRawStateCreate(0, 0, 0, _prompt_device, false, 0, 0),
	];
}

/// Returns a deterministic simulation fragment over the coordinator callback surface.
function _BladeReplayTestSimulation(_run_snapshot, _input_snapshot, _tick) {
	var _input = BladeInputSnapshotRead(_input_snapshot);
	return BladeCanonicalRecord("RR1", [
		_run_snapshot.ship_id,
		_run_snapshot.difficulty_id,
		string(_tick.simulation_tick),
		string(_tick.actor_tick),
		string(_tick.combat_tick),
		string(_input.move_x),
		string(_input.move_y),
		string(_input.held_actions),
		string(_input.pressed_actions),
		string(_input.released_actions),
		string(_input.has_analog ? 1 : 0),
		string(_input.analog_x),
		string(_input.analog_y),
	]);
}

/// Drives a live coordinator through the same callback that a playback run will receive.
function _BladeReplayTestDrive(
	_coordinator,
	_inputs,
	_recorder = undefined
) {
	var _callback = method({}, _BladeReplayTestSimulation);
	if (!is_undefined(_recorder)) {
		_callback = BladeReplayRecorderBind(_recorder, _callback);
	}
	var _domains = BladeClockDomain.Stage
		| BladeClockDomain.Actor
		| BladeClockDomain.Boss
		| BladeClockDomain.Combat;
	for (var _index = 0; _index < array_length(_inputs); ++_index) {
		BladeRunCoordinatorStepDirect(
			_coordinator,
			_inputs[_index],
			_domains,
			_callback
		);
	}
}

/// Records one complete four-tick fixture and returns its live run for comparison.
function _BladeReplayTestFixture(_prompt_device) {
	var _coordinator = _BladeReplayTestCreate();
	var _recorder = BladeReplayRecorderCreate(_coordinator);
	var _inputs = _BladeReplayTestInputs(_prompt_device);
	_BladeReplayTestDrive(_coordinator, _inputs, _recorder);
	return {
		coordinator: _coordinator,
		recorder: _recorder,
		recording: BladeReplayRecordingSerialize(_recorder),
	};
}

/// Parses a supplied payload through the public strict loader for assertion helpers.
function _BladeReplayTestParse(_recording) {
	BladeReplayRecordingParse(_recording);
}

/// Creates playback from a supplied payload so malformed content is tested at the public seam.
function _BladeReplayTestPlayback(_recording) {
	BladeReplayPlaybackCreate(
		_recording,
		method({}, _BladeReplayTestKnownContent),
		8
	);
}

/// Registers all replay contract and deterministic-equivalence cases.
function BladeReplayRecordingTestsRun(_state) {
	BladeKernelTestRunCase(_state, "replay recording stores canonical run metadata and ticks", function() {
		var _fixture = _BladeReplayTestFixture(BladePromptDevice.KeyboardMouse);
		var _parsed = BladeReplayRecordingParse(_fixture.recording);
		var _recorder_view = BladeReplayRecorderSnapshot(_fixture.recorder);

		BladeKernelTestAssertEqual(_parsed.format_id, "blade.replay", "replay format ID");
		BladeKernelTestAssertEqual(_parsed.schema_version, 1, "replay schema version");
		BladeKernelTestAssertEqual(
			_parsed.format_version,
			BladeSessionFormatVersion(),
			"replay session format version"
		);
		BladeKernelTestAssertEqual(
			_parsed.simulation_contract_version,
			BladeSimulationContractVersion(),
			"replay simulation contract"
		);
		BladeKernelTestAssertEqual(
			_parsed.prng_version,
			BladeRandomAlgorithmVersion(),
			"replay random contract"
		);
		BladeKernelTestAssertEqual(
			_parsed.tick_rate,
			BladeSimulationTickRate(),
			"replay tick rate"
		);
		BladeKernelTestAssertEqual(
			_parsed.content_fingerprint,
			"sha1:1c7a96f800d7ac228659dd0759706ed6833bb92c",
			"replay content fingerprint"
		);
		BladeKernelTestAssertEqual(_parsed.run_seed, int64(305419896), "replay run seed");
		BladeKernelTestAssertEqual(_parsed.ship_id, "ship.maynii", "replay ship ID");
		BladeKernelTestAssertEqual(
			_parsed.difficulty_id,
			"difficulty.normal",
			"replay difficulty ID"
		);
		BladeKernelTestAssertEqual(_parsed.run_mode, BladeRunMode.Normal, "replay run mode");
		BladeKernelTestAssertEqual(_parsed.input_count, int64(4), "replay input count");
		BladeKernelTestAssertEqual(
			_recorder_view.input_count,
			int64(4),
			"recorder input count"
		);
		BladeKernelTestAssertEqual(
			_recorder_view.last_simulation_tick,
			int64(4),
			"recorder last tick"
		);
		BladeKernelTestAssertEqual(
			BladeReplayRecordingCanonical(_fixture.recording),
			_fixture.recording,
			"replay canonical round trip"
		);
		BladeKernelTestAssertEqual(
			BladeReplayRecordingHash(_fixture.recording),
			_parsed.hash,
			"replay hash round trip"
		);
		BladeKernelTestAssertTrue(
			string_pos("RI1:", _fixture.recording) > 0,
			"replay contains compact input tokens"
		);
		BladeKernelTestAssertEqual(
			string_pos("BIS1", _fixture.recording),
			0,
			"replay payload omits full input snapshot framing"
		);
		BladeKernelTestAssertEqual(
			string_pos("Keyboard", _fixture.recording),
			0,
			"replay payload omits prompt-device labels"
		);
	});

	BladeKernelTestRunCase(_state, "replay playback reproduces coordinator state and terminal outcome", function() {
		var _fixture = _BladeReplayTestFixture(BladePromptDevice.KeyboardMouse);
		var _playback = BladeReplayPlaybackCreate(
			_fixture.recording,
			method({}, _BladeReplayTestKnownContent),
			8
		);
		var _callback = method({}, _BladeReplayTestSimulation);
		var _run_result = BladeReplayPlaybackRunToEnd(
			_playback,
			BladeClockDomain.Stage
				| BladeClockDomain.Actor
				| BladeClockDomain.Boss
				| BladeClockDomain.Combat,
			_callback
		);

		BladeKernelTestAssertEqual(_run_result.ticks_run, int64(4), "playback ticks run");
		BladeKernelTestAssertTrue(
			BladeReplayPlaybackFinished(_playback),
			"playback reaches end of input stream"
		);
		var _replay_terminal = BladeReplayPlaybackComplete(_playback);
		var _live_terminal = BladeRunCoordinatorComplete(_fixture.coordinator);
		BladeKernelTestAssertEqual(
			_replay_terminal.lifecycle,
			BladeRunLifecycle.Completed,
			"replay terminal lifecycle"
		);
		BladeKernelTestAssertEqual(
			_live_terminal.lifecycle,
			BladeRunLifecycle.Completed,
			"live terminal lifecycle"
		);
		BladeKernelTestAssertEqual(
			BladeRunCoordinatorCanonical(_fixture.coordinator),
			BladeReplayPlaybackCanonical(_playback),
			"replay coordinator canonical state"
		);
		BladeKernelTestAssertEqual(
			BladeRunCoordinatorHash(_fixture.coordinator),
			BladeReplayPlaybackHash(_playback),
			"replay coordinator state hash"
		);
		var _live_snapshot = BladeRunCoordinatorSnapshot(_fixture.coordinator);
		var _replay_snapshot = BladeReplayPlaybackSnapshot(_playback);
		BladeKernelTestAssertEqual(
			_live_snapshot.terminal_tick,
			int64(4),
			"live terminal tick"
		);
		BladeKernelTestAssertEqual(
			_replay_snapshot.run.terminal_tick,
			int64(4),
			"replay terminal tick"
		);
		BladeKernelTestAssertEqual(
			_replay_snapshot.next_input_index,
			int64(4),
			"replay cursor at terminal"
		);
	});

	BladeKernelTestRunCase(_state, "replay playback is tick-driven and prompt-device independent", function() {
		var _keyboard = _BladeReplayTestFixture(BladePromptDevice.KeyboardMouse);
		var _gamepad = _BladeReplayTestFixture(BladePromptDevice.Gamepad);
		BladeKernelTestAssertEqual(
			_keyboard.recording,
			_gamepad.recording,
			"equivalent semantic input has one replay payload"
		);
		BladeKernelTestAssertEqual(
			BladeReplayRecordingHash(_keyboard.recording),
			BladeReplayRecordingHash(_gamepad.recording),
			"equivalent semantic input has one replay hash"
		);

		var _playback = BladeReplayPlaybackCreate(
			_keyboard.recording,
			method({}, _BladeReplayTestKnownContent),
			8
		);
		var _step = BladeReplayPlaybackStep(
			_playback,
			BladeClockDomain.Stage
				| BladeClockDomain.Actor
				| BladeClockDomain.Boss
				| BladeClockDomain.Combat,
			method({}, _BladeReplayTestSimulation)
		);
		var _input = BladeInputSnapshotRead(_step.replay_input_snapshot);
		var _kernel = BladeReplayPlaybackCoordinator(_playback).__kernel;
		BladeKernelTestAssertEqual(_input.simulation_frame, int64(1), "playback input frame");
		BladeKernelTestAssertEqual(
			_input.presentation_frame,
			int64(0),
			"playback supplies neutral presentation frame"
		);
		BladeKernelTestAssertEqual(
			_input.prompt_device,
			BladePromptDevice.Unknown,
			"playback supplies neutral prompt device"
		);
		BladeKernelTestAssertEqual(
			_kernel.presentation_frame,
			int64(-1),
			"playback does not advance kernel presentation frame"
		);
		var _counters = BladeSimulationClockGetCounters(_kernel.clock);
		BladeKernelTestAssertEqual(
			_counters.presentation_tick,
			int64(0),
			"playback does not advance presentation clock"
		);
		BladeKernelTestAssertEqual(
			_counters.simulation_tick,
			int64(1),
			"playback advances exactly one simulation tick"
		);
	});

	BladeKernelTestRunCase(_state, "replay parser rejects malformed or incompatible payloads", function() {
		var _recording = _BladeReplayTestFixture(BladePromptDevice.KeyboardMouse).recording;
		var _bad_schema = string_replace(
			_recording,
			"BRP1|1|1|",
			"BRP1|2|1|"
		);
		BladeKernelTestAssertThrows(
			method({ recording: _bad_schema }, function() {
				_BladeReplayTestParse(self.recording);
			}),
			"replay schema version",
			"unsupported replay schema is rejected"
		);

		var _bad_format = string_replace(
			_recording,
			"BRP1|1|1|",
			"BRP1|1|2|"
		);
		BladeKernelTestAssertThrows(
			method({ recording: _bad_format }, function() {
				_BladeReplayTestParse(self.recording);
			}),
			"replay session format version",
			"unsupported session format is rejected"
		);

		var _bad_contract = string_replace(
			_recording,
			"|blade.simulation.v2|",
			"|blade.simulation.v1|"
		);
		BladeKernelTestAssertThrows(
			method({ recording: _bad_contract }, function() {
				_BladeReplayTestParse(self.recording);
			}),
			"unsupported simulation contract",
			"unsupported simulation contract is rejected"
		);

		var _bad_count = string_replace(
			_recording,
			"|normal|4|RI1:1:",
			"|normal|5|RI1:1:"
		);
		BladeKernelTestAssertThrows(
			method({ recording: _bad_count }, function() {
				_BladeReplayTestParse(self.recording);
			}),
			"replay input count",
			"mismatched replay input count is rejected"
		);

		var _bad_frame = string_replace(
			_recording,
			"|RI1:1:",
			"|RI1:0:"
		);
		BladeKernelTestAssertThrows(
			method({ recording: _bad_frame }, function() {
				_BladeReplayTestParse(self.recording);
			}),
			"replay input",
			"nonconsecutive replay frame is rejected"
		);

		var _bad_content = string_replace(
			_recording,
			"|ship.maynii|",
			"|ship.unknown|"
		);
		BladeKernelTestAssertThrows(
			method({ recording: _bad_content }, function() {
				_BladeReplayTestPlayback(self.recording);
			}),
			"unknown content ID",
			"unknown replay selection is rejected"
		);
	});
}
