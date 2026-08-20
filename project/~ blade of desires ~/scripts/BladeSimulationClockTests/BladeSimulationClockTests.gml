/// Project-owned tests for exact simulation-clock behavior.

/// Runs the pure clock cases in the shared state so their failures join the kernel report.
function BladeSimulationClockTestsRun(_state) {
    BladeKernelTestRunCase(_state, "clock preserves exact 60 Hz remainders", function() {
        // Runs three adjacent deltas in one case callback so the runner attributes
        // every exact-remainder assertion to this named scenario.
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
        // Advances twin clocks through the same delta list inside one case callback
        // so any deterministic divergence is reported under this scenario.
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
        // Forces one capped overrun and one idle update in the same case callback
        // so the runner reports both immediate and cumulative drop checks together.
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
        // Compares catch-up domains with independent presentation increments in one
        // callback so failures retain this domain-separation case name.
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
        // Exercises multi-step providers and a single explicit step in one callback
        // so all direct-stepping assertions share the same runner case.
        var _clock = BladeSimulationClockCreate();
        var _masks = [];
        var _capture_context = { masks: _masks };
        var _domain_provider = function(_counters) {
            // Selects Stage, Actor, then Boss from the current tick counter;
            // a provider callback proves eligibility is resolved before each step.
            if (_counters.simulation_tick == 0) {
                return BladeClockDomain.Stage;
            }
            if (_counters.simulation_tick == 1) {
                return BladeClockDomain.Actor;
            }
            return BladeClockDomain.Boss;
        };
        var _capture_tick_mask = method(_capture_context, function(_tick) {
            // Records each completed mask through self because method binding
            // makes the local capture array explicit to this tick callback.
            array_push(self.masks, _tick.domain_mask);
        });
        var _result = BladeSimulationClockStepManyDirect(
            _clock,
            3,
            _domain_provider,
            _capture_tick_mask
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
}
