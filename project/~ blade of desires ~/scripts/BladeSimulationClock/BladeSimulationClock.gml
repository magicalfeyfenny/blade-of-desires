/// @description Deterministic 60 Hz simulation clock with explicit time domains.

enum BladeClockDomain {
	None = 0,
	Stage = 1,
	Actor = 2,
	Boss = 4,
	Presentation = 8,
	Combat = 16,
	All = 31
}

// Rejects values that are not version 2 clock structs before other clock fields are read.
function _BladeSimulationClockRequire(_clock) {
	if (!is_struct(_clock)
		|| !variable_struct_exists(_clock, "__blade_simulation_clock_version")
		|| _clock.__blade_simulation_clock_version != 2) {
		throw("BladeSimulationClock: expected a version 2 clock");
	}
}

// Converts supported exact numeric values to int64 and enforces a lower bound,
// excluding fractional or imprecise Real values from deterministic clock state.
function _BladeSimulationClockInteger(_value, _field, _minimum) {
	var _type = typeof(_value);
	var _integer;
	if (_type == "int32" || _type == "int64") {
		_integer = int64(_value);
	} else if (_type == "number") {
		if (is_nan(_value) || is_infinity(_value)
			|| floor(_value) != _value
			|| abs(_value) > 9007199254740991) {
			throw("BladeSimulationClock: " + _field + " must be an exact finite integer");
		}
		_integer = int64(_value);
	} else {
		throw("BladeSimulationClock: " + _field + " must be an integer");
	}

	if (_integer < _minimum) {
		throw("BladeSimulationClock: " + _field + " must be at least " + string(_minimum));
	}
	return _integer;
}

// Accepts only integer combinations of the declared domain bits so unknown bits fail loudly.
function _BladeSimulationClockDomainMask(_domain_mask) {
	var _mask = _BladeSimulationClockInteger(_domain_mask, "domain mask", 0);
	if (_mask > BladeClockDomain.All) {
		throw("BladeSimulationClock: domain mask contains an unknown domain");
	}
	return _mask;
}

// Limits optional callbacks to callable methods because tick processing invokes them directly.
function _BladeSimulationClockCallback(_callback, _field) {
	if (!is_undefined(_callback) && typeof(_callback) != "method") {
		throw("BladeSimulationClock: " + _field + " must be a method or undefined");
	}
}

// Resolves a method against a fresh counter view on each tick, then validates its returned mask.
// Numeric masks take the same validation path without invoking a provider.
function _BladeSimulationClockResolveEligibility(_eligibility, _clock) {
	if (typeof(_eligibility) == "method") {
		return _BladeSimulationClockDomainMask(
			_eligibility(BladeSimulationClockGetCounters(_clock))
		);
	}
	return _BladeSimulationClockDomainMask(_eligibility);
}

// Builds the signed int64 maximum from decimal text to avoid an imprecise Real literal.
function _BladeSimulationClockInt64Maximum() {
	return int64("9223372036854775807");
}

// Checks room for an increment by subtraction so the validation itself cannot overflow.
function _BladeSimulationClockRequireCounterCapacity(_value, _increment, _field) {
	if (_value > _BladeSimulationClockInt64Maximum() - _increment) {
		throw("BladeSimulationClock: " + _field + " exceeds signed int64 range");
	}
}

// Preflights the simulation counter and every counter selected by a known numeric mask.
// This keeps a multi-counter tick from partially advancing when one counter is exhausted.
function _BladeSimulationClockRequireTickCapacity(_clock, _domain_mask, _tick_count) {
	_BladeSimulationClockRequireCounterCapacity(
		_clock.simulation_tick,
		_tick_count,
		"simulation tick"
	);
	if ((_domain_mask & BladeClockDomain.Stage) != 0) {
		_BladeSimulationClockRequireCounterCapacity(
			_clock.stage_tick,
			_tick_count,
			"stage tick"
		);
	}
	if ((_domain_mask & BladeClockDomain.Actor) != 0) {
		_BladeSimulationClockRequireCounterCapacity(
			_clock.actor_tick,
			_tick_count,
			"actor tick"
		);
	}
	if ((_domain_mask & BladeClockDomain.Boss) != 0) {
		_BladeSimulationClockRequireCounterCapacity(
			_clock.boss_tick,
			_tick_count,
			"boss tick"
		);
	}
	if ((_domain_mask & BladeClockDomain.Combat) != 0) {
		_BladeSimulationClockRequireCounterCapacity(
			_clock.combat_tick,
			_tick_count,
			"combat tick"
		);
	}
	if ((_domain_mask & BladeClockDomain.Presentation) != 0) {
		_BladeSimulationClockRequireCounterCapacity(
			_clock.presentation_tick,
			_tick_count,
			"presentation tick"
		);
	}
}

// Verifies that one independent presentation increment fits before the clock is mutated.
function _BladeSimulationClockRequirePresentationCapacity(_clock) {
	_BladeSimulationClockRequire(_clock);
	_BladeSimulationClockRequireCounterCapacity(
		_clock.presentation_tick,
		int64(1),
		"presentation tick"
	);
}

// Validates a direct-step count and any fixed mask before sampling or stepping can begin.
// Method masks stay deferred because their contract is to observe the real counters per tick.
function _BladeSimulationClockPreflightDirect(
	_clock,
	_tick_count,
	_eligibility,
	_strip_presentation = false
) {
	_BladeSimulationClockRequire(_clock);
	var _count = _BladeSimulationClockInteger(_tick_count, "direct tick count", 0);
	if (typeof(_eligibility) == "method") {
		_BladeSimulationClockRequireTickCapacity(_clock, BladeClockDomain.None, _count);
		return _count;
	}

	var _mask = _BladeSimulationClockDomainMask(_eligibility);
	if (_strip_presentation) {
		_mask &= ~BladeClockDomain.Presentation;
	}
	_BladeSimulationClockRequireTickCapacity(_clock, _mask, _count);
	return _count;
}

// Computes catch-up, drop, accumulator, and fixed-domain capacity as a local plan.
// Arithmetic and fixed-mask failures are rejected before mutation. Method eligibility
// stays deferred so each call sees live counters and can fail after earlier updates.
function _BladeSimulationClockPreflightAdvance(_clock, _delta_us, _eligibility) {
	_BladeSimulationClockRequire(_clock);
	var _delta = _BladeSimulationClockInteger(_delta_us, "delta microseconds", 0);
	var _numeric_mask = BladeClockDomain.None;
	var _has_numeric_mask = typeof(_eligibility) != "method";
	if (_has_numeric_mask) {
		_numeric_mask = _BladeSimulationClockDomainMask(_eligibility);
	}

	var _remaining_range = _BladeSimulationClockInt64Maximum()
		- _clock.accumulator_units;
	var _maximum_delta = _remaining_range div int64(_clock.tick_rate);
	if (_delta > _maximum_delta) {
		throw("BladeSimulationClock: delta microseconds exceeds exact accumulator range");
	}

	var _proposed_accumulator = _clock.accumulator_units
		+ (_delta * int64(_clock.tick_rate));
	var _available = _proposed_accumulator div _clock.accumulator_threshold;
	var _ticks_to_run = min(_available, _clock.max_catch_up_ticks);
	var _capacity_mask = BladeClockDomain.None;
	if (_has_numeric_mask) {
		_capacity_mask = _numeric_mask & ~BladeClockDomain.Presentation;
	}
	_BladeSimulationClockRequireTickCapacity(_clock, _capacity_mask, _ticks_to_run);

	var _after_run = _proposed_accumulator
		- (_ticks_to_run * _clock.accumulator_threshold);
	var _dropped = _after_run div _clock.accumulator_threshold;
	_BladeSimulationClockRequireCounterCapacity(
		_clock.total_dropped_ticks,
		_dropped,
		"total dropped ticks"
	);
	_BladeSimulationClockRequirePresentationCapacity(_clock);

	return {
		delta: _delta,
		available: _available,
		ticks_to_run: _ticks_to_run,
		dropped: _dropped,
	};
}

/// @func BladeSimulationClockCreate(max_catch_up_ticks)
/// @param {Real} max_catch_up_ticks Maximum simulation ticks run per accumulator update.
/// Creates a zeroed 60 Hz clock whose integer accumulator stores microseconds multiplied by 60.
function BladeSimulationClockCreate(_max_catch_up_ticks = 8) {
	var _maximum = _BladeSimulationClockInteger(
		_max_catch_up_ticks,
		"maximum catch-up ticks",
		1
	);

	return {
		__blade_simulation_clock_version: 2,
		tick_rate: 60,
		accumulator_threshold: int64(1000000),
		max_catch_up_ticks: _maximum,
		accumulator_units: int64(0),
		total_dropped_ticks: int64(0),
		simulation_tick: int64(0),
		stage_tick: int64(0),
		actor_tick: int64(0),
		boss_tick: int64(0),
		combat_tick: int64(0),
		presentation_tick: int64(0),
	};
}

/// @func BladeSimulationClockReset(clock)
/// @param {Struct} clock
/// Clears accumulated time, drops, and all counters while retaining the configured catch-up cap.
function BladeSimulationClockReset(_clock) {
	_BladeSimulationClockRequire(_clock);
	_clock.accumulator_units = int64(0);
	_clock.total_dropped_ticks = int64(0);
	_clock.simulation_tick = int64(0);
	_clock.stage_tick = int64(0);
	_clock.actor_tick = int64(0);
	_clock.boss_tick = int64(0);
	_clock.combat_tick = int64(0);
	_clock.presentation_tick = int64(0);
	return _clock;
}

/// @func BladeSimulationClockGetCounters(clock)
/// @param {Struct} clock
/// @returns {Struct} A fresh diagnostic view of all integer counters.
/// Copies the counters into a new struct so callers cannot mutate the clock through the view.
function BladeSimulationClockGetCounters(_clock) {
	_BladeSimulationClockRequire(_clock);
	return {
		simulation_tick: _clock.simulation_tick,
		stage_tick: _clock.stage_tick,
		actor_tick: _clock.actor_tick,
		boss_tick: _clock.boss_tick,
		combat_tick: _clock.combat_tick,
		presentation_tick: _clock.presentation_tick,
	};
}

/// @func BladeSimulationClockMarkPresentation(clock)
/// @desc Advances presentation time once, independently of simulation ticks.
/// Capacity-checks and records one presentation update without advancing simulation domains.
function BladeSimulationClockMarkPresentation(_clock) {
	_BladeSimulationClockRequirePresentationCapacity(_clock);
	_clock.presentation_tick += int64(1);
	return _clock.presentation_tick;
}

/// @func BladeSimulationClockStepDirect(clock, eligibility, tick_callback)
/// @param {Struct} clock
/// @param {Real} eligibility BladeClockDomain bit mask supplied by the caller.
/// @param {Method} tick_callback Optional callback receiving the completed tick view.
/// Advances simulation and each eligible domain once.
/// An optional callback receives the completed tick view.
function BladeSimulationClockStepDirect(_clock, _eligibility, _tick_callback = undefined) {
	_BladeSimulationClockRequire(_clock);
	_BladeSimulationClockCallback(_tick_callback, "tick callback");
	var _domain_mask = _BladeSimulationClockDomainMask(_eligibility);
	_BladeSimulationClockRequireTickCapacity(_clock, _domain_mask, int64(1));

	_clock.simulation_tick += int64(1);
	if ((_domain_mask & BladeClockDomain.Stage) != 0) {
		_clock.stage_tick += int64(1);
	}
	if ((_domain_mask & BladeClockDomain.Actor) != 0) {
		_clock.actor_tick += int64(1);
	}
	if ((_domain_mask & BladeClockDomain.Boss) != 0) {
		_clock.boss_tick += int64(1);
	}
	if ((_domain_mask & BladeClockDomain.Combat) != 0) {
		_clock.combat_tick += int64(1);
	}
	if ((_domain_mask & BladeClockDomain.Presentation) != 0) {
		_clock.presentation_tick += int64(1);
	}

	var _tick = BladeSimulationClockGetCounters(_clock);
	_tick.domain_mask = _domain_mask;
	if (typeof(_tick_callback) == "method") {
		_tick_callback(_tick);
	}
	return _tick;
}

/// @func BladeSimulationClockStepManyDirect(clock, tick_count, eligibility, tick_callback)
/// @param {Struct} clock
/// @param {Real} tick_count Number of exact ticks to run without wall time.
/// @param {Real|Method} eligibility Domain mask or a provider called before each tick.
/// @param {Method} tick_callback Optional callback receiving each completed tick view.
/// Runs an exact number of ticks without touching the wall-time accumulator or creating drops.
/// Eligibility methods are resolved inside the loop so each one sees the preceding tick's counters.
function BladeSimulationClockStepManyDirect(
	_clock,
	_tick_count,
	_eligibility,
	_tick_callback = undefined
) {
	_BladeSimulationClockRequire(_clock);
	_BladeSimulationClockCallback(_tick_callback, "tick callback");
	var _count = _BladeSimulationClockPreflightDirect(
		_clock,
		_tick_count,
		_eligibility
	);
	var _ran = int64(0);
	while (_ran < _count) {
		var _mask = _BladeSimulationClockResolveEligibility(_eligibility, _clock);
		BladeSimulationClockStepDirect(_clock, _mask, _tick_callback);
		_ran += int64(1);
	}

	return {
		ticks_run: _ran,
		dropped_ticks: int64(0),
		overrun: false,
		accumulator_units: _clock.accumulator_units,
		remainder_units: _clock.accumulator_units,
		interpolation_numerator: _clock.accumulator_units,
		interpolation_denominator: _clock.accumulator_threshold,
		counters: BladeSimulationClockGetCounters(_clock),
	};
}

/// @func BladeSimulationClockAdvance(clock, delta_us, eligibility, tick_callback)
/// @param {Struct} clock
/// @param {Real} delta_us Nonnegative integer wall-time delta in microseconds.
/// @param {Real|Method} eligibility Domain mask or a provider called before each tick.
/// @param {Method} tick_callback Optional callback receiving each completed tick view.
/// @returns {Struct} Catch-up, drop, remainder, and counter diagnostics.
/// Adds delta_us * 60 units, runs the capped whole ticks, and drops whole excess ticks.
/// Presentation advances once per update, while the sub-tick remainder is retained exactly.
/// On each catch-up tick, method eligibility and any callback run after mutation begins.
/// Their failures can leave earlier work applied; deferral lets eligibility see live counters.
function BladeSimulationClockAdvance(
	_clock,
	_delta_us,
	_eligibility,
	_tick_callback = undefined
) {
	_BladeSimulationClockRequire(_clock);
	_BladeSimulationClockCallback(_tick_callback, "tick callback");
	var _plan = _BladeSimulationClockPreflightAdvance(
		_clock,
		_delta_us,
		_eligibility
	);
	BladeSimulationClockMarkPresentation(_clock);
	_clock.accumulator_units += _plan.delta * int64(_clock.tick_rate);

	var _ran = int64(0);
	while (_ran < _plan.ticks_to_run) {
		// The accumulator owns exactly one presentation increment per update;
		// catch-up ticks cannot duplicate it.
		var _mask = _BladeSimulationClockResolveEligibility(_eligibility, _clock)
			& ~BladeClockDomain.Presentation;
		BladeSimulationClockStepDirect(_clock, _mask, _tick_callback);
		_ran += int64(1);
	}
	_clock.accumulator_units -= _ran * _clock.accumulator_threshold;

	var _dropped = _plan.dropped;
	_clock.accumulator_units -= _dropped * _clock.accumulator_threshold;
	_clock.total_dropped_ticks += _dropped;

	return {
		ticks_available: _plan.available,
		ticks_run: _ran,
		dropped_ticks: _dropped,
		overrun: _dropped > 0,
		total_dropped_ticks: _clock.total_dropped_ticks,
		accumulator_units: _clock.accumulator_units,
		remainder_units: _clock.accumulator_units,
		interpolation_numerator: _clock.accumulator_units,
		interpolation_denominator: _clock.accumulator_threshold,
		counters: BladeSimulationClockGetCounters(_clock),
	};
}
