/// Project-owned tests for kernel input delivery and immutable input snapshots.
/// When a callback needs fixture values, method(context, callback) exposes the
/// context as self; this keeps the callback's dependencies visible in GML.

/// Creates the same seeded kernel for each clock/input case. Content lookup is
/// disabled because these cases never allocate a content-backed ID.
function _BladeClockInputKernelCreate() {
    return BladeDeterministicKernelCreate(
        "sha1:d9a345101d9fa9971924bb2b9138a39dd5fd7c0b",
        305419896,
        function(_content_id) {
            // Rejects every content ID because these input cases never allocate
            // content-backed IDs; the kernel still requires an injected predicate.
            return false;
        }
    );
}

/// Serializes every mutable clock field used by these tests so a rejected call
/// can be checked for side effects.
function _BladeClockInputClockState(_clock) {
    var _counters = BladeSimulationClockGetCounters(_clock);
    return BladeCanonicalRecord("CLOCK_TEST_STATE", [
        string(_clock.accumulator_units),
        string(_clock.total_dropped_ticks),
        string(_counters.simulation_tick),
        string(_counters.stage_tick),
        string(_counters.actor_tick),
        string(_counters.boss_tick),
        string(_counters.combat_tick),
        string(_counters.presentation_tick),
    ]);
}

/// Serializes the sampler's stored input and edge state so failed validation
/// cannot mutate it unnoticed.
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

/// Combines kernel, clock, input, and gameplay state into one value so the
/// rejection tests can compare all affected state at once.
function _BladeClockInputKernelState(_kernel) {
    return BladeCanonicalRecord("KERNEL_TEST_STATE", [
        string(_kernel.presentation_frame),
        _BladeClockInputClockState(_kernel.clock),
        _BladeClockInputSamplerState(_kernel.input_sampler),
        BladeKernelGameplayCanonical(_kernel),
    ]);
}

/// Confirms a call rejects the expected error and leaves its captured state
/// byte-for-byte unchanged.
function _BladeClockInputAssertRejected(_callback, _fragment, _state_callback, _message) {
    var _before = _state_callback();
    BladeKernelTestAssertThrows(_callback, _fragment, _message);
    BladeKernelTestAssertEqual(_state_callback(), _before, _message + " preserves state");
}

/// Runs kernel-input, snapshot, and rejection cases in the shared test state.
/// Keeping these cases together makes their sampler and kernel fixtures local to one suite.
function BladeClockInputTestsRun(_state) {
    BladeKernelTestRunCase(_state, "input edges survive zero and ineligible ticks", function() {
        // Drives zero, actor-ineligible, and actor-eligible ticks in one case callback
        // so the runner reports the entire edge-latching sequence under this name.
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
        var _capture_ineligible = method(
            _ineligible_context,
            function(_active_kernel, _snapshot, _tick) {
                // Saves the Stage-only snapshot and returns an empty state fragment.
                // Method binding exposes this callback's local array through self.
                array_push(self.snapshots, _snapshot);
                return "";
            }
        );
        BladeKernelStepDirect(
            _kernel,
            _held_fire,
            BladeClockDomain.Stage,
            _capture_ineligible
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
        var _capture_eligible = method(
            _eligible_context,
            function(_active_kernel, _snapshot, _tick) {
                // Saves the Actor-eligible snapshot and returns an empty state fragment.
                // Method binding exposes this callback's local array through self.
                array_push(self.snapshots, _snapshot);
                return "";
            }
        );
        BladeKernelStepDirect(
            _kernel,
            _held_fire,
            BladeClockDomain.Actor,
            _capture_eligible
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
        // Captures every snapshot from one three-tick catch-up inside a case callback
        // so edge consumption and carried state are checked as one sequence.
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
        var _capture_catch_up = method(
            _capture_context,
            function(_active_kernel, _snapshot, _tick) {
                // Appends each catch-up snapshot and returns an empty state fragment.
                // Method binding exposes the case's local array through self.
                array_push(self.snapshots, _snapshot);
                return "";
            }
        );
        var _advance = BladeKernelAdvancePresentation(
            _kernel,
            50000,
            _raw,
            BladeClockDomain.All,
            _capture_catch_up
        );
        BladeKernelTestAssertEqual(_advance.ticks_run, int64(3), "catch-up tick count");
        BladeKernelTestAssertEqual(array_length(_snapshots), 3, "captured snapshots");

        for (var _index = 0; _index < array_length(_snapshots); ++_index) {
            var _view = BladeInputSnapshotRead(_snapshots[_index]);
            var _expected_pressed = int64(0);
            if (_index == 0) {
                _expected_pressed = int64(
                    BladeInputAction.Fire | BladeInputAction.Focus
                );
            }
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
        // Samples a press and release before one eligible tick in a case callback
        // so the runner groups both queued-edge assertions under this scenario.
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
        var _capture_queued_edges = method(
            _capture_context,
            function(_active_kernel, _snapshot, _tick) {
                // Saves the consuming snapshot and returns an empty state fragment.
                // Method binding exposes the case's local array through self.
                array_push(self.snapshots, _snapshot);
                return "";
            }
        );
        BladeKernelStepDirect(
            _kernel,
            _released,
            BladeClockDomain.Actor,
            _capture_queued_edges
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
        // Attempts duplicate and skipped presentation frames in one case callback
        // so both rejection paths and the following valid sample are tested together.
        var _sampler = BladeInputSamplerCreate();
        var _raw = BladeInputRawStateCreate(
            0,
            0,
            BladeInputAction.Confirm,
            BladePromptDevice.Gamepad
        );
        BladeInputSamplePresentation(_sampler, 0, _raw);
        var _sample_context = { sampler: _sampler, raw: _raw };
        var _repeat_same_frame = method(_sample_context, function() {
            // Repeats frame zero through self because the throw assertion callback
            // needs explicit access to the sampler and raw-state fixtures.
            BladeInputSamplePresentation(self.sampler, 0, self.raw);
        });
        BladeKernelTestAssertThrows(
            _repeat_same_frame,
            "once and consecutively",
            "duplicate presentation sample must fail"
        );
        var _skip_presentation_frame = method(_sample_context, function() {
            // Jumps from frame zero to frame two through self because the throw
            // assertion callback needs the same explicitly bound fixtures.
            BladeInputSamplePresentation(self.sampler, 2, self.raw);
        });
        BladeKernelTestAssertThrows(
            _skip_presentation_frame,
            "once and consecutively",
            "skipped presentation sample must fail"
        );

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
        // Creates two snapshots and mutates only a parsed view in one case callback
        // so the runner attributes every value-semantics check to this scenario.
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
        // Runs clock and sampler rejection probes in one case callback so the
        // shared preservation checks retain this original cross-boundary case name.
        var _clock = BladeSimulationClockCreate(1);
        var _context = { clock: _clock };
        var _state_view = method(_context, function() {
            // Serializes whichever clock self currently references; method binding
            // lets this state callback follow later fixture replacements.
            var _serialized = _BladeClockInputClockState(self.clock);
            return _serialized;
        });
        var _reject_negative_delta = method(_context, function() {
            // Submits a negative delta through self so the rejection callback uses
            // the same explicitly bound clock as the state callback.
            BladeSimulationClockAdvance(self.clock, -1, BladeClockDomain.All);
        });
        _BladeClockInputAssertRejected(
            _reject_negative_delta,
            "must be at least",
            _state_view,
            "negative delta"
        );
        var _reject_boolean_mask = method(_context, function() {
            // Supplies a boolean mask through self so this callback isolates the
            // clock's original-mask type validation.
            BladeSimulationClockAdvance(self.clock, 0, true);
        });
        _BladeClockInputAssertRejected(
            _reject_boolean_mask,
            "domain mask must be an integer",
            _state_view,
            "boolean clock mask"
        );
        var _reject_negative_count = method(_context, function() {
            // Supplies a negative direct-step count through self so this callback
            // targets count preflight without changing the shared clock fixture.
            BladeSimulationClockStepManyDirect(
                self.clock,
                -1,
                BladeClockDomain.All
            );
        });
        _BladeClockInputAssertRejected(
            _reject_negative_count,
            "must be at least",
            _state_view,
            "negative direct count"
        );

        _clock.accumulator_units = int64("9223372036854775807");
        var _reject_accumulator_overflow = method(_context, function() {
            // Adds one microsecond to the full accumulator through self so the
            // callback reaches the exact-range preflight guard.
            BladeSimulationClockAdvance(self.clock, 1, BladeClockDomain.None);
        });
        _BladeClockInputAssertRejected(
            _reject_accumulator_overflow,
            "exact accumulator range",
            _state_view,
            "accumulator overflow"
        );

        _clock = BladeSimulationClockCreate(1);
        _clock.total_dropped_ticks = int64("9223372036854775807");
        _context.clock = _clock;
        var _reject_drop_overflow = method(_context, function() {
            // Creates one dropped tick on the rebound clock through self so this
            // callback targets the full cumulative-drop counter.
            BladeSimulationClockAdvance(self.clock, 33334, BladeClockDomain.None);
        });
        _BladeClockInputAssertRejected(
            _reject_drop_overflow,
            "total dropped ticks exceeds",
            _state_view,
            "drop counter overflow"
        );

        _clock = BladeSimulationClockCreate();
        _clock.stage_tick = int64("9223372036854775807");
        _context.clock = _clock;
        var _reject_stage_overflow = method(_context, function() {
            // Requests one Stage step through self so the callback isolates the
            // exhausted domain counter before any other counter advances.
            BladeSimulationClockStepDirect(self.clock, BladeClockDomain.Stage);
        });
        _BladeClockInputAssertRejected(
            _reject_stage_overflow,
            "stage tick exceeds",
            _state_view,
            "domain counter overflow"
        );

        _clock = BladeSimulationClockCreate();
        _clock.combat_tick = int64("9223372036854775807");
        _context.clock = _clock;
        var _reject_combat_overflow = method(_context, function() {
            // Requests one Combat step through self so the exhausted counter
            // rejects before the master counter can advance.
            BladeSimulationClockStepDirect(self.clock, BladeClockDomain.Combat);
        });
        _BladeClockInputAssertRejected(
            _reject_combat_overflow,
            "combat tick exceeds",
            _state_view,
            "combat counter overflow"
        );

        var _sampler = BladeInputSamplerCreate();
        var _raw = BladeInputRawStateCreate(0, 0, BladeInputAction.Fire);
        BladeInputSamplePresentation(_sampler, 0, _raw);
        var _input_context = { sampler: _sampler, raw: _raw };
        var _input_state = method(_input_context, function() {
            // Re-serializes the bound sampler through self so the rejection helper
            // can compare its pending edges and frame counters before and after.
            var _serialized = _BladeClockInputSamplerState(self.sampler);
            return _serialized;
        });
        _sampler.presentation_frame = int64("9223372036854775807");
        var _reject_presentation_overflow = method(_input_context, function() {
            // Attempts the impossible successor of a full presentation counter;
            // method binding exposes the sampler and raw state through self.
            BladeInputSamplePresentation(
                self.sampler,
                int64("9223372036854775807"),
                self.raw
            );
        });
        _BladeClockInputAssertRejected(
            _reject_presentation_overflow,
            "presentation frame exceeds",
            _input_state,
            "input presentation overflow"
        );
        _sampler.presentation_frame = int64(0);
        _sampler.last_simulation_frame = int64("9223372036854775807");
        var _reject_simulation_overflow = method(_input_context, function() {
            // Attempts to publish after a full simulation-frame counter through
            // self so the callback reuses the explicitly bound sampler fixture.
            BladeInputSnapshotPublishTick(
                self.sampler,
                int64("9223372036854775807"),
                true
            );
        });
        _BladeClockInputAssertRejected(
            _reject_simulation_overflow,
            "simulation frame exceeds",
            _input_state,
            "input simulation overflow"
        );
    });

    BladeKernelTestRunCase(_state, "kernel rejects invalid updates without sampling", function() {
        // Exercises every kernel preflight rejection in one case callback so all
        // no-sampling state comparisons retain this original scenario name.
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
            // Re-serializes the bound kernel through self so the rejection helper
            // compares clock, input, presentation, and gameplay state together.
            var _serialized = _BladeClockInputKernelState(self.kernel);
            return _serialized;
        });
        var _reject_kernel_delta = method(_context, function() {
            // Submits a negative presentation delta through self so this callback
            // targets kernel preflight before input sampling can occur.
            BladeKernelAdvancePresentation(
                self.kernel,
                -1,
                self.raw,
                BladeClockDomain.All
            );
        });
        _BladeClockInputAssertRejected(
            _reject_kernel_delta,
            "must be at least",
            _state_view,
            "kernel negative delta"
        );
        var _reject_kernel_count = method(_context, function() {
            // Submits a negative direct count through self so this callback reaches
            // count preflight before the kernel samples presentation input.
            BladeKernelStepManyDirect(
                self.kernel,
                self.raw,
                -1,
                BladeClockDomain.All
            );
        });
        _BladeClockInputAssertRejected(
            _reject_kernel_count,
            "must be at least",
            _state_view,
            "kernel negative count"
        );
        var _reject_kernel_mask = method(_context, function() {
            // Supplies a boolean domain mask through self so the callback proves
            // validation happens before Presentation is stripped from the mask.
            BladeKernelStepManyDirect(self.kernel, self.raw, 1, true);
        });
        _BladeClockInputAssertRejected(
            _reject_kernel_mask,
            "domain mask must be an integer",
            _state_view,
            "kernel boolean mask"
        );
        var _reject_bad_raw_state = method(_context, function() {
            // Supplies the bound out-of-range movement sample through self so this
            // callback checks that failed sampling leaves the kernel unchanged.
            BladeKernelAdvancePresentation(
                self.kernel,
                0,
                self.bad_raw,
                BladeClockDomain.All
            );
        });
        _BladeClockInputAssertRejected(
            _reject_bad_raw_state,
            "movement x must be in",
            _state_view,
            "kernel invalid raw sample"
        );

        _kernel.presentation_frame = int64("9223372036854775807");
        var _reject_kernel_presentation_overflow = method(_context, function() {
            // Requests a zero-tick presentation through self so this callback
            // isolates the kernel's exhausted presentation-frame guard.
            BladeKernelStepManyDirect(
                self.kernel,
                self.raw,
                0,
                BladeClockDomain.None
            );
        });
        _BladeClockInputAssertRejected(
            _reject_kernel_presentation_overflow,
            "presentation frame",
            _state_view,
            "kernel presentation overflow"
        );
    });

}
