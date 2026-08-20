/// @description Thin composition seam for deterministic Blade simulation.

function _BladeKernelFail(_field, _reason) {
    throw("BladeDeterministicKernel: " + _field + ": " + _reason);
}

function _BladeKernelRequire(_kernel) {
    if (!is_struct(_kernel)
        || !variable_struct_exists(_kernel, "__blade_kernel_version")
        || _kernel.__blade_kernel_version != 1) {
        _BladeKernelFail("kernel", "expected a version 1 deterministic kernel");
    }
}

function _BladeKernelRequireCallback(_callback, _field) {
    if (!is_undefined(_callback) && typeof(_callback) != "method") {
        _BladeKernelFail(_field, "must be a method or undefined");
    }
}

function _BladeKernelBindTickCallback(_kernel, _simulate_callback) {
    var _context = {
        kernel: _kernel,
        simulate_callback: _simulate_callback,
    };
    return method(_context, function(_tick) {
        _BladeKernelRunTick(self.kernel, _tick, self.simulate_callback);
    });
}

function _BladeKernelBindEligibilityProvider(_eligibility) {
    var _context = { eligibility: _eligibility };
    return method(_context, function(_counters) {
        var _mask = _BladeSimulationClockDomainMask(self.eligibility(_counters));
        return _mask & ~BladeClockDomain.Presentation;
    });
}

function _BladeKernelRequirePresentationCapacity(_kernel) {
    if (_kernel.presentation_frame >= int64("9223372036854775807")) {
        _BladeKernelFail("presentation frame", "exceeds signed int64 range");
    }
}

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

function _BladeKernelGameplayInputCanonical(_snapshot) {
    var _view = BladeInputSnapshotRead(_snapshot);
    return BladeCanonicalRecord("S1", [
        string(_view.simulation_frame),
        string(_view.move_x),
        string(_view.move_y),
        string(_view.held_actions),
        string(_view.pressed_actions),
        string(_view.released_actions),
        string(_view.has_analog ? 1 : 0),
        string(_view.analog_x),
        string(_view.analog_y),
    ]);
}

function _BladeKernelClockCanonical(_clock) {
    var _counters = BladeSimulationClockGetCounters(_clock);
    return BladeCanonicalRecord("C1", [
        string(_counters.simulation_tick),
        string(_counters.stage_tick),
        string(_counters.actor_tick),
        string(_counters.boss_tick),
    ]);
}

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

function _BladeKernelGameplayRandomCanonical(_kernel) {
    return BladeCanonicalRecord("R1", [
        _BladeKernelRandomStreamCanonical(_kernel.stage_schedule),
        _BladeKernelRandomStreamCanonical(_kernel.enemy_spawn_variant),
        _BladeKernelRandomStreamCanonical(_kernel.pattern_geometry),
        _BladeKernelRandomStreamCanonical(_kernel.drop_selection),
    ]);
}

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
function BladeKernelRandom(_kernel, _stream_name) {
    _BladeKernelRequire(_kernel);
    return _BladeKernelStream(_kernel, _stream_name);
}

/// @func BladeKernelAllocate(kernel, kind)
function BladeKernelAllocate(_kernel, _kind) {
    _BladeKernelRequire(_kernel);
    return BladeRunIdentityAllocate(_kernel.identity, _kind);
}

/// @func BladeKernelAllocateForContent(kernel, kind, content_id)
function BladeKernelAllocateForContent(_kernel, _kind, _content_id) {
    _BladeKernelRequire(_kernel);
    return BladeRunIdentityAllocateForContent(_kernel.identity, _kind, _content_id);
}

/// @func BladeKernelQueueEvent(kernel, channel, order_key, type, reason, source_id, target_id, owner_id, content_id, payload)
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
function BladeKernelGameplayHash(_kernel) {
    return BladeCanonicalHashUtf8(BladeKernelGameplayCanonical(_kernel));
}

/// @func BladeKernelDiagnostics(kernel)
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
