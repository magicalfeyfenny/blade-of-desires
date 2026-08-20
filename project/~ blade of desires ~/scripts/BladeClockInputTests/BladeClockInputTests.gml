/// Project-owned tests for the fixed clock and immutable input snapshots.

function _BladeClockInputKernelCreate() {
    return BladeDeterministicKernelCreate(
        "sha1:60bbf1e2436c7f0132be5877b2dc38a149d8ea72",
        305419896,
        function(_content_id) {
            return false;
        }
    );
}

function _BladeClockInputClockState(_clock) {
    var _counters = BladeSimulationClockGetCounters(_clock);
    return BladeCanonicalRecord("CLOCK_TEST_STATE", [
        string(_clock.accumulator_units),
        string(_clock.total_dropped_ticks),
        string(_counters.simulation_tick),
        string(_counters.stage_tick),
        string(_counters.actor_tick),
        string(_counters.boss_tick),
        string(_counters.presentation_tick),
    ]);
}

function _BladeClockInputSamplerState(_sampler) {
    return BladeCanonicalRecord("INPUT_TEST_STATE", [
        string(_sampler.has_sample),
        string(_sampler.presentation_frame),
        string(_sampler.last_simulation_frame),
        string(_sampler.move_x),
        string(_sampler.move_y),
        string(_sampler.held_actions),
        string(_sampler.pending_pressed_actions),
        string(_sampler.pending_released_actions),
        string(_sampler.prompt_device),
        string(_sampler.has_analog),
        string(_sampler.analog_x),
        string(_sampler.analog_y),
    ]);
}

function _BladeClockInputKernelState(_kernel) {
    return BladeCanonicalRecord("KERNEL_TEST_STATE", [
        string(_kernel.presentation_frame),
        _BladeClockInputClockState(_kernel.clock),
        _BladeClockInputSamplerState(_kernel.input_sampler),
        BladeKernelGameplayCanonical(_kernel),
    ]);
}

function _BladeClockInputAssertRejected(_callback, _fragment, _state_callback, _message) {
    var _before = _state_callback();
    BladeKernelTestAssertThrows(_callback, _fragment, _message);
    BladeKernelTestAssertEqual(_state_callback(), _before, _message + " preserves state");
}

function BladeClockInputTestsRun(_state) {
    BladeKernelTestRunCase(_state, "clock preserves exact 60 Hz remainders", function() {
        var _clock = BladeSimulationClockCreate();
        var _first = BladeSimulationClockAdvance(
            _clock,
            16666,
            BladeClockDomain.All
        );
        BladeKernelTestAssertEqual(_first.ticks_run, int64(0), "first short delta ticks");
        BladeKernelTestAssertEqual(
            _first.remainder_units,
            int64(999960),
            "first short delta remainder"
        );

        var _second = BladeSimulationClockAdvance(
            _clock,
            16667,
            BladeClockDomain.All
        );
        BladeKernelTestAssertEqual(_second.ticks_run, int64(1), "second delta ticks");
        BladeKernelTestAssertEqual(
            _second.remainder_units,
            int64(999980),
            "second delta remainder"
        );

        var _third = BladeSimulationClockAdvance(
            _clock,
            16667,
            BladeClockDomain.All
        );
        BladeKernelTestAssertEqual(_third.ticks_run, int64(2), "third delta ticks");
        BladeKernelTestAssertEqual(
            _third.remainder_units,
            int64(0),
            "three deltas total exactly fifty milliseconds"
        );
        BladeKernelTestAssertEqual(
            _third.interpolation_denominator,
            int64(1000000),
            "fixed interpolation denominator"
        );
        BladeKernelTestAssertEqual(
            _third.counters.simulation_tick,
            int64(3),
            "three exact simulation ticks"
        );
        BladeKernelTestAssertEqual(
            _third.counters.presentation_tick,
            int64(3),
            "one presentation tick per accumulator update"
        );
    });

    BladeKernelTestRunCase(_state, "equal clock delta sequences stay identical", function() {
        var _left = BladeSimulationClockCreate(8);
        var _right = BladeSimulationClockCreate(8);
        var _deltas = [16666, 16667, 0, 33334, 1, 99999];

        for (var _index = 0; _index < array_length(_deltas); ++_index) {
            var _left_result = BladeSimulationClockAdvance(
                _left,
                _deltas[_index],
                BladeClockDomain.Stage | BladeClockDomain.Actor
            );
            var _right_result = BladeSimulationClockAdvance(
                _right,
                _deltas[_index],
                BladeClockDomain.Stage | BladeClockDomain.Actor
            );
            var _context = "equal sequence result " + string(_index);
            BladeKernelTestAssertEqual(
                _left_result.ticks_run,
                _right_result.ticks_run,
                _context + " ticks"
            );
            BladeKernelTestAssertEqual(
                _left_result.dropped_ticks,
                _right_result.dropped_ticks,
                _context + " drops"
            );
            BladeKernelTestAssertEqual(
                _left_result.remainder_units,
                _right_result.remainder_units,
                _context + " remainder"
            );
            BladeKernelTestAssertEqual(
                _left_result.overrun,
                _right_result.overrun,
                _context + " overrun"
            );
            BladeKernelTestAssertEqual(
                _left_result.counters.simulation_tick,
                _right_result.counters.simulation_tick,
                _context + " simulation counter"
            );
            BladeKernelTestAssertEqual(
                _left_result.counters.presentation_tick,
                _right_result.counters.presentation_tick,
                _context + " presentation counter"
            );
        }
    });

    BladeKernelTestRunCase(_state, "clock caps catch-up and reports dropped ticks", function() {
        var _clock = BladeSimulationClockCreate(2);
        var _overrun = BladeSimulationClockAdvance(
            _clock,
            100001,
            BladeClockDomain.All
        );
        BladeKernelTestAssertEqual(
            _overrun.ticks_available,
            int64(6),
            "available ticks before cap"
        );
        BladeKernelTestAssertEqual(_overrun.ticks_run, int64(2), "catch-up cap");
        BladeKernelTestAssertEqual(
            _overrun.dropped_ticks,
            int64(4),
            "explicit dropped ticks"
        );
        BladeKernelTestAssertTrue(_overrun.overrun, "overrun flag");
        BladeKernelTestAssertEqual(
            _overrun.total_dropped_ticks,
            int64(4),
            "cumulative drop count"
        );
        BladeKernelTestAssertEqual(
            _overrun.remainder_units,
            int64(60),
            "sub-tick remainder survives dropping"
        );

        var _idle = BladeSimulationClockAdvance(
            _clock,
            0,
            BladeClockDomain.All
        );
        BladeKernelTestAssertFalse(_idle.overrun, "zero delta is not an overrun");
        BladeKernelTestAssertEqual(_idle.dropped_ticks, int64(0), "no new drops");
        BladeKernelTestAssertEqual(
            _idle.total_dropped_ticks,
            int64(4),
            "prior drops remain diagnostic"
        );
    });

    BladeKernelTestRunCase(_state, "clock domains and presentation count separately", function() {
        var _clock = BladeSimulationClockCreate();
        var _catch_up = BladeSimulationClockAdvance(
            _clock,
            50000,
            BladeClockDomain.Stage
                | BladeClockDomain.Actor
                | BladeClockDomain.Presentation
        );
        BladeKernelTestAssertEqual(
            _catch_up.counters.simulation_tick,
            int64(3),
            "simulation catch-up count"
        );
        BladeKernelTestAssertEqual(
            _catch_up.counters.stage_tick,
            int64(3),
            "stage domain count"
        );
        BladeKernelTestAssertEqual(
            _catch_up.counters.actor_tick,
            int64(3),
            "actor domain count"
        );
        BladeKernelTestAssertEqual(
            _catch_up.counters.boss_tick,
            int64(0),
            "ineligible boss domain"
        );
        BladeKernelTestAssertEqual(
            _catch_up.counters.presentation_tick,
            int64(1),
            "catch-up does not duplicate presentation"
        );

        var _zero = BladeSimulationClockAdvance(
            _clock,
            0,
            BladeClockDomain.Boss | BladeClockDomain.Presentation
        );
        BladeKernelTestAssertEqual(_zero.ticks_run, int64(0), "zero delta ticks");
        BladeKernelTestAssertEqual(
            _zero.counters.presentation_tick,
            int64(2),
            "zero-tick update still presents once"
        );
        BladeKernelTestAssertEqual(
            BladeSimulationClockMarkPresentation(_clock),
            int64(3),
            "presentation may advance independently"
        );
    });

    BladeKernelTestRunCase(_state, "clock supports exact direct stepping", function() {
        var _clock = BladeSimulationClockCreate();
        var _masks = [];
        var _capture_context = { masks: _masks };
        var _result = BladeSimulationClockStepManyDirect(
            _clock,
            3,
            function(_counters) {
                if (_counters.simulation_tick == 0) {
                    return BladeClockDomain.Stage;
                }
                if (_counters.simulation_tick == 1) {
                    return BladeClockDomain.Actor;
                }
                return BladeClockDomain.Boss;
            },
            method(_capture_context, function(_tick) {
                array_push(self.masks, _tick.domain_mask);
            })
        );
        BladeKernelTestAssertEqual(_result.ticks_run, int64(3), "direct tick count");
        BladeKernelTestAssertEqual(_result.dropped_ticks, int64(0), "direct drops");
        BladeKernelTestAssertFalse(_result.overrun, "direct steps cannot overrun");
        BladeKernelTestAssertEqual(
            _result.remainder_units,
            int64(0),
            "direct steps leave accumulator unchanged"
        );
        BladeKernelTestAssertArrayEqual(
            _masks,
            [BladeClockDomain.Stage, BladeClockDomain.Actor, BladeClockDomain.Boss],
            "eligibility is resolved before each direct tick"
        );

        var _counters = BladeSimulationClockGetCounters(_clock);
        BladeKernelTestAssertEqual(_counters.stage_tick, int64(1), "direct stage count");
        BladeKernelTestAssertEqual(_counters.actor_tick, int64(1), "direct actor count");
        BladeKernelTestAssertEqual(_counters.boss_tick, int64(1), "direct boss count");
        BladeKernelTestAssertEqual(
            _counters.presentation_tick,
            int64(0),
            "direct simulation domains do not imply presentation"
        );

        BladeSimulationClockStepDirect(
            _clock,
            BladeClockDomain.Stage | BladeClockDomain.Presentation
        );
        _counters = BladeSimulationClockGetCounters(_clock);
        BladeKernelTestAssertEqual(_counters.simulation_tick, int64(4), "single direct step");
        BladeKernelTestAssertEqual(_counters.stage_tick, int64(2), "single step domain");
        BladeKernelTestAssertEqual(
            _counters.presentation_tick,
            int64(1),
            "explicit direct presentation domain"
        );
    });

    BladeKernelTestRunCase(_state, "input edges survive zero and ineligible ticks", function() {
        var _kernel = _BladeClockInputKernelCreate();
        var _held_fire = BladeInputRawStateCreate(
            0,
            0,
            BladeInputAction.Fire,
            BladePromptDevice.KeyboardMouse
        );
        var _zero = BladeKernelAdvancePresentation(
            _kernel,
            0,
            _held_fire,
            BladeClockDomain.All
        );
        BladeKernelTestAssertEqual(_zero.ticks_run, int64(0), "zero update ticks");
        var _pending = BladeInputSamplerGetPendingEdges(_kernel.input_sampler);
        BladeKernelTestAssertEqual(
            _pending.pressed_actions,
            int64(BladeInputAction.Fire),
            "press waits through zero ticks"
        );

        var _ineligible_snapshots = [];
        var _ineligible_context = { snapshots: _ineligible_snapshots };
        BladeKernelStepDirect(
            _kernel,
            _held_fire,
            BladeClockDomain.Stage,
            method(_ineligible_context, function(_active_kernel, _snapshot, _tick) {
                array_push(self.snapshots, _snapshot);
                return "";
            })
        );
        var _ineligible = BladeInputSnapshotRead(_ineligible_snapshots[0]);
        BladeKernelTestAssertEqual(
            _ineligible.pressed_actions,
            int64(0),
            "actor-ineligible tick receives no press edge"
        );
        BladeKernelTestAssertEqual(
            _ineligible.held_actions,
            int64(BladeInputAction.Fire),
            "held state still reaches ineligible tick"
        );
        _pending = BladeInputSamplerGetPendingEdges(_kernel.input_sampler);
        BladeKernelTestAssertEqual(
            _pending.pressed_actions,
            int64(BladeInputAction.Fire),
            "ineligible tick does not consume edge"
        );

        var _eligible_snapshots = [];
        var _eligible_context = { snapshots: _eligible_snapshots };
        BladeKernelStepDirect(
            _kernel,
            _held_fire,
            BladeClockDomain.Actor,
            method(_eligible_context, function(_active_kernel, _snapshot, _tick) {
                array_push(self.snapshots, _snapshot);
                return "";
            })
        );
        var _eligible = BladeInputSnapshotRead(_eligible_snapshots[0]);
        BladeKernelTestAssertEqual(
            _eligible.pressed_actions,
            int64(BladeInputAction.Fire),
            "first actor-eligible tick receives pending press"
        );
        _pending = BladeInputSamplerGetPendingEdges(_kernel.input_sampler);
        BladeKernelTestAssertEqual(_pending.pressed_actions, int64(0), "press consumed once");
    });

    BladeKernelTestRunCase(_state, "catch-up delivers edges only on its first tick", function() {
        var _kernel = _BladeClockInputKernelCreate();
        var _raw = BladeInputRawStateCreate(
            512,
            -256,
            BladeInputAction.Fire | BladeInputAction.Focus,
            BladePromptDevice.Gamepad,
            true,
            12345,
            -23456
        );
        var _snapshots = [];
        var _capture_context = { snapshots: _snapshots };
        var _advance = BladeKernelAdvancePresentation(
            _kernel,
            50000,
            _raw,
            BladeClockDomain.All,
            method(_capture_context, function(_active_kernel, _snapshot, _tick) {
                array_push(self.snapshots, _snapshot);
                return "";
            })
        );
        BladeKernelTestAssertEqual(_advance.ticks_run, int64(3), "catch-up tick count");
        BladeKernelTestAssertEqual(array_length(_snapshots), 3, "captured snapshots");

        for (var _index = 0; _index < array_length(_snapshots); ++_index) {
            var _view = BladeInputSnapshotRead(_snapshots[_index]);
            var _expected_pressed = (_index == 0)
                ? int64(BladeInputAction.Fire | BladeInputAction.Focus)
                : int64(0);
            BladeKernelTestAssertEqual(
                _view.pressed_actions,
                _expected_pressed,
                "catch-up press edge " + string(_index)
            );
            BladeKernelTestAssertEqual(
                _view.released_actions,
                int64(0),
                "catch-up release edge " + string(_index)
            );
            BladeKernelTestAssertEqual(
                _view.held_actions,
                int64(BladeInputAction.Fire | BladeInputAction.Focus),
                "held state carries through catch-up " + string(_index)
            );
            BladeKernelTestAssertTrue(
                _view.has_analog,
                "analog presence carries through catch-up " + string(_index)
            );
            BladeKernelTestAssertEqual(
                _view.analog_x,
                int64(12345),
                "analog x carries through catch-up " + string(_index)
            );
            BladeKernelTestAssertEqual(
                _view.analog_y,
                int64(-23456),
                "analog y carries through catch-up " + string(_index)
            );
        }
    });

    BladeKernelTestRunCase(_state, "press and release queue before an eligible tick", function() {
        var _kernel = _BladeClockInputKernelCreate();
        var _pressed = BladeInputRawStateCreate(
            0,
            0,
            BladeInputAction.Bomb,
            BladePromptDevice.KeyboardMouse
        );
        var _released = BladeInputRawStateCreate(
            0,
            0,
            0,
            BladePromptDevice.KeyboardMouse
        );
        BladeKernelAdvancePresentation(
            _kernel,
            0,
            _pressed,
            BladeClockDomain.All
        );
        BladeKernelAdvancePresentation(
            _kernel,
            0,
            _released,
            BladeClockDomain.All
        );
        var _pending = BladeInputSamplerGetPendingEdges(_kernel.input_sampler);
        BladeKernelTestAssertEqual(
            _pending.pressed_actions,
            int64(BladeInputAction.Bomb),
            "queued press"
        );
        BladeKernelTestAssertEqual(
            _pending.released_actions,
            int64(BladeInputAction.Bomb),
            "queued release"
        );

        var _snapshots = [];
        var _capture_context = { snapshots: _snapshots };
        BladeKernelStepDirect(
            _kernel,
            _released,
            BladeClockDomain.Actor,
            method(_capture_context, function(_active_kernel, _snapshot, _tick) {
                array_push(self.snapshots, _snapshot);
                return "";
            })
        );
        var _view = BladeInputSnapshotRead(_snapshots[0]);
        BladeKernelTestAssertEqual(_view.held_actions, int64(0), "released held state");
        BladeKernelTestAssertEqual(
            _view.pressed_actions,
            int64(BladeInputAction.Bomb),
            "eligible tick receives queued press"
        );
        BladeKernelTestAssertEqual(
            _view.released_actions,
            int64(BladeInputAction.Bomb),
            "eligible tick receives queued release"
        );
    });

    BladeKernelTestRunCase(_state, "presentation input samples at most once", function() {
        var _sampler = BladeInputSamplerCreate();
        var _raw = BladeInputRawStateCreate(
            0,
            0,
            BladeInputAction.Confirm,
            BladePromptDevice.Gamepad
        );
        BladeInputSamplePresentation(_sampler, 0, _raw);
        var _sample_context = { sampler: _sampler, raw: _raw };
        BladeKernelTestAssertThrows(method(_sample_context, function() {
            BladeInputSamplePresentation(self.sampler, 0, self.raw);
        }), "once and consecutively", "duplicate presentation sample must fail");
        BladeKernelTestAssertThrows(method(_sample_context, function() {
            BladeInputSamplePresentation(self.sampler, 2, self.raw);
        }), "once and consecutively", "skipped presentation sample must fail");

        BladeInputSamplePresentation(_sampler, 1, _raw);
        var _snapshot = BladeInputSnapshotPublishTick(_sampler, 0, true);
        var _view = BladeInputSnapshotRead(_snapshot);
        BladeKernelTestAssertEqual(
            _view.presentation_frame,
            int64(1),
            "valid next sample remains accepted after failures"
        );
    });

    BladeKernelTestRunCase(_state, "snapshots preserve earlier immutable values", function() {
        var _sampler = BladeInputSamplerCreate();
        var _first_raw = BladeInputRawStateCreate(
            64,
            -32,
            BladeInputAction.Fire,
            BladePromptDevice.KeyboardMouse,
            false,
            0,
            0
        );
        BladeInputSamplePresentation(_sampler, 0, _first_raw);
        var _first_snapshot = BladeInputSnapshotPublishTick(_sampler, 0, true);
        var _first_view = BladeInputSnapshotRead(_first_snapshot);

        var _second_raw = BladeInputRawStateCreate(
            -128,
            256,
            BladeInputAction.Bomb,
            BladePromptDevice.Gamepad,
            true,
            -30000,
            30000
        );
        BladeInputSamplePresentation(_sampler, 1, _second_raw);
        var _second_snapshot = BladeInputSnapshotPublishTick(_sampler, 1, true);
        BladeKernelTestAssertNotEqual(
            _first_snapshot,
            _second_snapshot,
            "changed input creates a distinct immutable value"
        );

        _first_view.move_x = int64(999);
        _first_view.held_actions = int64(0);
        var _fresh_first_view = BladeInputSnapshotRead(_first_snapshot);
        BladeKernelTestAssertEqual(
            _fresh_first_view.move_x,
            int64(64),
            "mutating a read view cannot change the snapshot"
        );
        BladeKernelTestAssertEqual(
            _fresh_first_view.move_y,
            int64(-32),
            "earlier movement remains stable"
        );
        BladeKernelTestAssertEqual(
            _fresh_first_view.held_actions,
            int64(BladeInputAction.Fire),
            "earlier held state remains stable"
        );
        BladeKernelTestAssertEqual(
            _fresh_first_view.pressed_actions,
            int64(BladeInputAction.Fire),
            "earlier edge remains stable"
        );
        BladeKernelTestAssertEqual(
            BladeInputSnapshotCanonical(_first_snapshot),
            _first_snapshot,
            "canonical validation returns the immutable value"
        );

        var _second_view = BladeInputSnapshotRead(_second_snapshot);
        BladeKernelTestAssertEqual(
            _second_view.move_x,
            int64(-128),
            "later snapshot keeps its own movement"
        );
        BladeKernelTestAssertEqual(
            _second_view.pressed_actions,
            int64(BladeInputAction.Bomb),
            "later snapshot keeps its own press edge"
        );
        BladeKernelTestAssertEqual(
            _second_view.released_actions,
            int64(BladeInputAction.Fire),
            "later snapshot keeps its own release edge"
        );
    });

    BladeKernelTestRunCase(_state, "clock and input failures preserve counters", function() {
        var _clock = BladeSimulationClockCreate(1);
        var _context = { clock: _clock };
        var _state_view = method(_context, function() {
            return _BladeClockInputClockState(self.clock);
        });
        _BladeClockInputAssertRejected(method(_context, function() {
            BladeSimulationClockAdvance(self.clock, -1, BladeClockDomain.All);
        }), "must be at least", _state_view, "negative delta");
        _BladeClockInputAssertRejected(method(_context, function() {
            BladeSimulationClockAdvance(self.clock, 0, true);
        }), "domain mask must be an integer", _state_view, "boolean clock mask");
        _BladeClockInputAssertRejected(method(_context, function() {
            BladeSimulationClockStepManyDirect(
                self.clock,
                -1,
                BladeClockDomain.All
            );
        }), "must be at least", _state_view, "negative direct count");

        _clock.accumulator_units = int64("9223372036854775807");
        _BladeClockInputAssertRejected(method(_context, function() {
            BladeSimulationClockAdvance(self.clock, 1, BladeClockDomain.None);
        }), "exact accumulator range", _state_view, "accumulator overflow");

        _clock = BladeSimulationClockCreate(1);
        _clock.total_dropped_ticks = int64("9223372036854775807");
        _context.clock = _clock;
        _BladeClockInputAssertRejected(method(_context, function() {
            BladeSimulationClockAdvance(self.clock, 33334, BladeClockDomain.None);
        }), "total dropped ticks exceeds", _state_view, "drop counter overflow");

        _clock = BladeSimulationClockCreate();
        _clock.stage_tick = int64("9223372036854775807");
        _context.clock = _clock;
        _BladeClockInputAssertRejected(method(_context, function() {
            BladeSimulationClockStepDirect(self.clock, BladeClockDomain.Stage);
        }), "stage tick exceeds", _state_view, "domain counter overflow");

        var _sampler = BladeInputSamplerCreate();
        var _raw = BladeInputRawStateCreate(0, 0, BladeInputAction.Fire);
        BladeInputSamplePresentation(_sampler, 0, _raw);
        var _input_context = { sampler: _sampler, raw: _raw };
        var _input_state = method(_input_context, function() {
            return _BladeClockInputSamplerState(self.sampler);
        });
        _sampler.presentation_frame = int64("9223372036854775807");
        _BladeClockInputAssertRejected(method(_input_context, function() {
            BladeInputSamplePresentation(
                self.sampler,
                int64("9223372036854775807"),
                self.raw
            );
        }), "presentation frame exceeds", _input_state, "input presentation overflow");
        _sampler.presentation_frame = int64(0);
        _sampler.last_simulation_frame = int64("9223372036854775807");
        _BladeClockInputAssertRejected(method(_input_context, function() {
            BladeInputSnapshotPublishTick(
                self.sampler,
                int64("9223372036854775807"),
                true
            );
        }), "simulation frame exceeds", _input_state, "input simulation overflow");
    });

    BladeKernelTestRunCase(_state, "kernel rejects invalid updates without sampling", function() {
        var _kernel = _BladeClockInputKernelCreate();
        var _raw = BladeInputRawStateCreate(0, 0, BladeInputAction.Fire);
        var _bad_raw = {
            move_x: 2048,
            move_y: 0,
            held_actions: 0,
            prompt_device: BladePromptDevice.Unknown,
            has_analog: false,
            analog_x: 0,
            analog_y: 0,
        };
        var _context = { kernel: _kernel, raw: _raw, bad_raw: _bad_raw };
        var _state_view = method(_context, function() {
            return _BladeClockInputKernelState(self.kernel);
        });
        _BladeClockInputAssertRejected(method(_context, function() {
            BladeKernelAdvancePresentation(
                self.kernel,
                -1,
                self.raw,
                BladeClockDomain.All
            );
        }), "must be at least", _state_view, "kernel negative delta");
        _BladeClockInputAssertRejected(method(_context, function() {
            BladeKernelStepManyDirect(
                self.kernel,
                self.raw,
                -1,
                BladeClockDomain.All
            );
        }), "must be at least", _state_view, "kernel negative count");
        _BladeClockInputAssertRejected(method(_context, function() {
            BladeKernelStepManyDirect(self.kernel, self.raw, 1, true);
        }), "domain mask must be an integer", _state_view, "kernel boolean mask");
        _BladeClockInputAssertRejected(method(_context, function() {
            BladeKernelAdvancePresentation(
                self.kernel,
                0,
                self.bad_raw,
                BladeClockDomain.All
            );
        }), "movement x must be in", _state_view, "kernel invalid raw sample");

        _kernel.presentation_frame = int64("9223372036854775807");
        _BladeClockInputAssertRejected(method(_context, function() {
            BladeKernelStepManyDirect(
                self.kernel,
                self.raw,
                0,
                BladeClockDomain.None
            );
        }), "presentation frame", _state_view, "kernel presentation overflow");
    });

}
