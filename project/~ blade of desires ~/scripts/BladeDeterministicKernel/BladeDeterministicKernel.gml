/// @description Thin composition seam for deterministic Blade simulation.

/// Throw a kernel error that names the invalid field so callers can locate failed validation.
function _BladeKernelFail(_field, _reason) {
    throw("BladeDeterministicKernel: " + _field + ": " + _reason);
}

/// Reject values that are not version 1 kernel structs before composed systems are accessed.
function _BladeKernelRequire(_kernel) {
    if (!is_struct(_kernel)
        || !variable_struct_exists(_kernel, "__blade_kernel_version")
        || _kernel.__blade_kernel_version != 1) {
        _BladeKernelFail("kernel", "expected a version 1 deterministic kernel");
    }
}

/// Accept only a bound method or undefined because tick execution invokes
/// callbacks with GameMaker method semantics.
function _BladeKernelRequireCallback(_callback, _field) {
    if (!is_undefined(_callback) && typeof(_callback) != "method") {
        _BladeKernelFail(_field, "must be a method or undefined");
    }
}

/// Store kernel state in a method context, adapting simulation to the clock's
/// one-argument callback without local capture.
function _BladeKernelBindTickCallback(_kernel, _simulate_callback) {
    var _context = {
        kernel: _kernel,
        simulate_callback: _simulate_callback,
    };
    return method(_context, function(_tick) {
        _BladeKernelRunTick(self.kernel, _tick, self.simulate_callback);
    });
}

/// Bind the caller's eligibility method and remove Presentation so direct
/// multi-tick stepping marks it only once.
function _BladeKernelBindEligibilityProvider(_eligibility) {
    var _context = { eligibility: _eligibility };
    return method(_context, function(_counters) {
        var _mask = _BladeSimulationClockDomainMask(self.eligibility(_counters));
        return _mask & ~BladeClockDomain.Presentation;
    });
}

/// Reject an exhausted kernel presentation counter before sampling would
/// require an out-of-range increment.
function _BladeKernelRequirePresentationCapacity(_kernel) {
    if (_kernel.presentation_frame >= int64("9223372036854775807")) {
        _BladeKernelFail("presentation frame", "exceeds signed int64 range");
    }
}

/// Select only a named RNG stream so deterministic domains remain explicit and
/// unknown names cannot share state.
function _BladeKernelStream(_kernel, _name) {
    switch (_name) {
        case "stage_schedule": return _kernel.stage_schedule;
        case "enemy_spawn_variant": return _kernel.enemy_spawn_variant;
        case "pattern_geometry": return _kernel.pattern_geometry;
        case "drop_selection": return _kernel.drop_selection;
        case "cosmetic_effects": return _kernel.cosmetic_effects;
    }
    _BladeKernelFail("random stream", "unknown stream " + string(_name));
}

/// Read a snapshot view and encode gameplay input in fixed order, storing
/// analog presence as 0 or 1 so boolean rendering cannot affect the transcript.
function _BladeKernelGameplayInputCanonical(_snapshot) {
    var _view = BladeInputSnapshotRead(_snapshot);
    var _analog_flag = 0;
    if (_view.has_analog) {
        _analog_flag = 1;
    }
    return BladeCanonicalRecord("S1", [
        string(_view.simulation_frame),
        string(_view.move_x),
        string(_view.move_y),
        string(_view.held_actions),
        string(_view.pressed_actions),
        string(_view.released_actions),
        string(_analog_flag),
        string(_view.analog_x),
        string(_view.analog_y),
    ]);
}

/// Encode simulation and domain counters without Presentation so presentation
/// timing cannot alter the gameplay transcript.
function _BladeKernelClockCanonical(_clock) {
    var _counters = BladeSimulationClockGetCounters(_clock);
    return BladeCanonicalRecord("C1", [
        string(_counters.simulation_tick),
        string(_counters.stage_tick),
        string(_counters.actor_tick),
        string(_counters.boss_tick),
    ]);
}

/// Encode a stream's name, four state words, and draw count so both state and
/// consumption divergence remain visible.
function _BladeKernelRandomStreamCanonical(_stream) {
    var _state = _stream.get_state();
    return BladeCanonicalRecord("RS1", [
        _stream.get_stream_name(),
        string(_state[0]),
        string(_state[1]),
        string(_state[2]),
        string(_state[3]),
        string(_stream.get_draw_count()),
    ]);
}

/// Combine the four gameplay RNG streams in fixed order while omitting
/// cosmetics from gameplay comparison.
function _BladeKernelGameplayRandomCanonical(_kernel) {
    return BladeCanonicalRecord("R1", [
        _BladeKernelRandomStreamCanonical(_kernel.stage_schedule),
        _BladeKernelRandomStreamCanonical(_kernel.enemy_spawn_variant),
        _BladeKernelRandomStreamCanonical(_kernel.pattern_geometry),
        _BladeKernelRandomStreamCanonical(_kernel.drop_selection),
    ]);
}

/// Sample raw input at the next presentation frame and advance the kernel
/// counter only after the sampler accepts it.
function _BladeKernelSamplePresentation(_kernel, _raw_state) {
    _BladeKernelRequirePresentationCapacity(_kernel);
    var _next_frame = _kernel.presentation_frame + int64(1);
    BladeInputSamplePresentation(
        _kernel.input_sampler,
        _next_frame,
        _raw_state
    );
    _kernel.presentation_frame = _next_frame;
}

/// Process one clock tick in input, simulation/event, then state order so each
/// transcript follows callback execution.
function _BladeKernelRunTick(_kernel, _tick, _simulate_callback) {
    var _input_eligible = (_tick.domain_mask & BladeClockDomain.Actor) != 0;
    var _snapshot = BladeInputSnapshotPublishTick(
        _kernel.input_sampler,
        _tick.simulation_tick,
        _input_eligible
    );
    array_push(
        _kernel.gameplay_input_transcript,
        _BladeKernelGameplayInputCanonical(_snapshot)
    );

    BladeEventLogBeginTick(_kernel.event_log, _tick.simulation_tick);
    var _state_fragment = "";
    if (typeof(_simulate_callback) == "method") {
        _state_fragment = _simulate_callback(_kernel, _snapshot, _tick);
        if (is_undefined(_state_fragment)) {
            _state_fragment = "";
        }
        if (!is_string(_state_fragment)) {
            _BladeKernelFail("simulation callback", "must return a canonical string or undefined");
        }
    }
    BladeEventLogCommitTick(_kernel.event_log);
    array_push(
        _kernel.gameplay_state_transcript,
        BladeCanonicalRecord("T1", [string(_tick.simulation_tick), _state_fragment])
    );
}

/// @func BladeDeterministicKernelCreate(content_fingerprint, run_seed, content_id_predicate, max_catch_up_ticks)
/// Assemble a fresh kernel with shared identity and log state, named seeded RNG
/// streams, and empty transcripts.
function BladeDeterministicKernelCreate(
    _content_fingerprint,
    _run_seed,
    _content_id_predicate,
    _max_catch_up_ticks = 8
) {
    var _identity = BladeRunIdentityCreate(_content_id_predicate);
    return {
        __blade_kernel_version: 1,
        header: new BladeSessionHeader(_content_fingerprint, _run_seed),
        clock: BladeSimulationClockCreate(_max_catch_up_ticks),
        input_sampler: BladeInputSamplerCreate(),
        identity: _identity,
        event_log: BladeEventLogCreate(_identity),
        stage_schedule: new BladeRandomStream(_run_seed, "stage_schedule"),
        enemy_spawn_variant: new BladeRandomStream(_run_seed, "enemy_spawn_variant"),
        pattern_geometry: new BladeRandomStream(_run_seed, "pattern_geometry"),
        drop_selection: new BladeRandomStream(_run_seed, "drop_selection"),
        cosmetic_effects: new BladeRandomStream(_run_seed, "cosmetic_effects"),
        presentation_frame: int64(-1),
        gameplay_input_transcript: [],
        gameplay_state_transcript: [],
    };
}

/// @func BladeDeterministicKernelReset(kernel)
/// Restore composed systems and transcripts to their initial run state while
/// retaining the existing session header.
function BladeDeterministicKernelReset(_kernel) {
    _BladeKernelRequire(_kernel);
    BladeSimulationClockReset(_kernel.clock);
    BladeInputSamplerReset(_kernel.input_sampler);
    BladeRunIdentityReset(_kernel.identity);
    BladeEventLogReset(_kernel.event_log);
    _kernel.stage_schedule.reset();
    _kernel.enemy_spawn_variant.reset();
    _kernel.pattern_geometry.reset();
    _kernel.drop_selection.reset();
    _kernel.cosmetic_effects.reset();
    _kernel.presentation_frame = int64(-1);
    _kernel.gameplay_input_transcript = [];
    _kernel.gameplay_state_transcript = [];
    return _kernel;
}

/// @func BladeKernelRandom(kernel, stream_name)
/// Return a requested named stream after validating the kernel so simulation
/// draws from an explicit RNG domain.
function BladeKernelRandom(_kernel, _stream_name) {
    _BladeKernelRequire(_kernel);
    return _BladeKernelStream(_kernel, _stream_name);
}

/// @func BladeKernelAllocate(kernel, kind)
/// Allocate the next kind-specific ID through shared identity state so the
/// kernel and event log see the same counters.
function BladeKernelAllocate(_kernel, _kind) {
    _BladeKernelRequire(_kernel);
    return BladeRunIdentityAllocate(_kernel.identity, _kind);
}

/// @func BladeKernelAllocateForContent(kernel, kind, content_id)
/// Delegate content-aware ID allocation to shared identity state so its content
/// validation and counters stay coordinated.
function BladeKernelAllocateForContent(_kernel, _kind, _content_id) {
    _BladeKernelRequire(_kernel);
    return BladeRunIdentityAllocateForContent(_kernel.identity, _kind, _content_id);
}

/// @func BladeKernelQueueEvent(kernel, channel, order_key, type, reason, source_id, target_id, owner_id, content_id, payload)
/// Forward an event to the kernel's log so simulation uses the same active tick
/// and identity allocation context.
function BladeKernelQueueEvent(
    _kernel,
    _channel,
    _order_key,
    _type,
    _reason,
    _source_id,
    _target_id,
    _owner_id,
    _content_id,
    _payload = []
) {
    _BladeKernelRequire(_kernel);
    return BladeEventLogQueue(
        _kernel.event_log,
        _channel,
        _order_key,
        _type,
        _reason,
        _source_id,
        _target_id,
        _owner_id,
        _content_id,
        _payload
    );
}

/// @func BladeKernelAdvancePresentation(kernel, delta_us, raw_state, eligibility, simulate_callback)
/// Preflight detectable clock errors before sampling input once, then run due
/// ticks through a context-bound callback.
function BladeKernelAdvancePresentation(
    _kernel,
    _delta_us,
    _raw_state,
    _eligibility,
    _simulate_callback = undefined
) {
    _BladeKernelRequire(_kernel);
    _BladeKernelRequireCallback(_simulate_callback, "simulation callback");
    _BladeSimulationClockPreflightAdvance(
        _kernel.clock,
        _delta_us,
        _eligibility
    );
    _BladeKernelRequirePresentationCapacity(_kernel);
    _BladeKernelSamplePresentation(_kernel, _raw_state);
    return BladeSimulationClockAdvance(
        _kernel.clock,
        _delta_us,
        _eligibility,
        _BladeKernelBindTickCallback(_kernel, _simulate_callback)
    );
}

/// @func BladeKernelStepManyDirect(kernel, raw_state, tick_count, eligibility, simulate_callback)
/// Preflight count and fixed masks, mark one input sample, and strip Presentation
/// per tick so a batch samples once.
function BladeKernelStepManyDirect(
    _kernel,
    _raw_state,
    _tick_count,
    _eligibility,
    _simulate_callback = undefined
) {
    _BladeKernelRequire(_kernel);
    _BladeKernelRequireCallback(_simulate_callback, "simulation callback");
    _BladeSimulationClockPreflightDirect(
        _kernel.clock,
        _tick_count,
        _eligibility,
        true
    );
    _BladeSimulationClockRequirePresentationCapacity(_kernel.clock);
    _BladeKernelRequirePresentationCapacity(_kernel);
    _BladeKernelSamplePresentation(_kernel, _raw_state);
    BladeSimulationClockMarkPresentation(_kernel.clock);
    var _step_eligibility;
    if (typeof(_eligibility) == "method") {
        _step_eligibility = _BladeKernelBindEligibilityProvider(_eligibility);
    } else {
        _step_eligibility = _eligibility & ~BladeClockDomain.Presentation;
    }
    return BladeSimulationClockStepManyDirect(
        _kernel.clock,
        _tick_count,
        _step_eligibility,
        _BladeKernelBindTickCallback(_kernel, _simulate_callback)
    );
}

/// @func BladeKernelStepDirect(kernel, raw_state, eligibility, simulate_callback)
/// Delegate one direct tick to the batch path so sampling, eligibility masking,
/// and callback behavior stay identical.
function BladeKernelStepDirect(
    _kernel,
    _raw_state,
    _eligibility,
    _simulate_callback = undefined
) {
    return BladeKernelStepManyDirect(
        _kernel,
        _raw_state,
        1,
        _eligibility,
        _simulate_callback
    );
}

/// @func BladeKernelGameplayCanonical(kernel)
/// Encode gameplay header, input, clock, RNG, identity, events, and state while
/// excluding presentation-only state.
function BladeKernelGameplayCanonical(_kernel) {
    _BladeKernelRequire(_kernel);
    return BladeCanonicalRecord("G1", [
        _kernel.header.canonical(),
        BladeCanonicalRecord("I1", _kernel.gameplay_input_transcript),
        _BladeKernelClockCanonical(_kernel.clock),
        _BladeKernelGameplayRandomCanonical(_kernel),
        BladeRunIdentityCountersCanonical(_kernel.identity),
        BladeEventLogGameplayCanonical(_kernel.event_log),
        BladeCanonicalRecord("ST1", _kernel.gameplay_state_transcript),
    ]);
}

/// @func BladeKernelGameplayHash(kernel)
/// Hash the complete gameplay canonical record to provide a compact deterministic comparison value.
function BladeKernelGameplayHash(_kernel) {
    return BladeCanonicalHashUtf8(BladeKernelGameplayCanonical(_kernel));
}

/// @func BladeKernelDiagnostics(kernel)
/// Return current subsystem counters, all RNG diagnostics, and gameplay hashes
/// without mutating kernel state.
function BladeKernelDiagnostics(_kernel) {
    _BladeKernelRequire(_kernel);
    return {
        header: _kernel.header.to_struct(),
        clock: BladeSimulationClockGetCounters(_kernel.clock),
        identity: BladeRunIdentityGetCounters(_kernel.identity),
        stage_schedule: _kernel.stage_schedule.diagnostics(),
        enemy_spawn_variant: _kernel.enemy_spawn_variant.diagnostics(),
        pattern_geometry: _kernel.pattern_geometry.diagnostics(),
        drop_selection: _kernel.drop_selection.diagnostics(),
        cosmetic_effects: _kernel.cosmetic_effects.diagnostics(),
        gameplay_event_hash: BladeEventLogGameplayHash(_kernel.event_log),
        gameplay_hash: BladeKernelGameplayHash(_kernel),
    };
}
