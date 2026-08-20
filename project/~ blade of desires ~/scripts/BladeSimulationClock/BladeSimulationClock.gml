/// @description Deterministic 60 Hz simulation clock with explicit time domains.

enum BladeClockDomain {
	None = 0,
	Stage = 1,
	Actor = 2,
	Boss = 4,
	Presentation = 8,
	All = 15
}

function _BladeSimulationClockRequire(_clock) {
	if (!is_struct(_clock)
		|| !variable_struct_exists(_clock, "__blade_simulation_clock_version")
		|| _clock.__blade_simulation_clock_version != 1) {
		throw("BladeSimulationClock: expected a version 1 clock");
	}
}

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

function _BladeSimulationClockDomainMask(_domain_mask) {
	var _mask = _BladeSimulationClockInteger(_domain_mask, "domain mask", 0);
	if (_mask > BladeClockDomain.All) {
		throw("BladeSimulationClock: domain mask contains an unknown domain");
	}
	return _mask;
}

function _BladeSimulationClockCallback(_callback, _field) {
	if (!is_undefined(_callback) && !is_callable(_callback)) {
		throw("BladeSimulationClock: " + _field + " must be callable or undefined");
	}
}

function _BladeSimulationClockResolveEligibility(_eligibility, _clock) {
	if (is_callable(_eligibility)) {
		return _BladeSimulationClockDomainMask(
			_eligibility(BladeSimulationClockGetCounters(_clock))
		);
	}
	return _BladeSimulationClockDomainMask(_eligibility);
}

/// @func BladeSimulationClockCreate(max_catch_up_ticks)
/// @param {Real} max_catch_up_ticks Maximum simulation ticks run per accumulator update.
function BladeSimulationClockCreate(_max_catch_up_ticks = 8) {
	var _maximum = _BladeSimulationClockInteger(
		_max_catch_up_ticks,
		"maximum catch-up ticks",
		1
	);

	return {
		__blade_simulation_clock_version: 1,
		tick_rate: 60,
		accumulator_threshold: int64(1000000),
		max_catch_up_ticks: _maximum,
		accumulator_units: int64(0),
		total_dropped_ticks: int64(0),
		simulation_tick: int64(0),
		stage_tick: int64(0),
		actor_tick: int64(0),
		boss_tick: int64(0),
		presentation_tick: int64(0),
	};
}

/// @func BladeSimulationClockReset(clock)
/// @param {Struct} clock
function BladeSimulationClockReset(_clock) {
	_BladeSimulationClockRequire(_clock);
	_clock.accumulator_units = int64(0);
	_clock.total_dropped_ticks = int64(0);
	_clock.simulation_tick = int64(0);
	_clock.stage_tick = int64(0);
	_clock.actor_tick = int64(0);
	_clock.boss_tick = int64(0);
	_clock.presentation_tick = int64(0);
	return _clock;
}

/// @func BladeSimulationClockGetCounters(clock)
/// @param {Struct} clock
/// @returns {Struct} A fresh diagnostic view of all integer counters.
function BladeSimulationClockGetCounters(_clock) {
	_BladeSimulationClockRequire(_clock);
	return {
		simulation_tick: _clock.simulation_tick,
		stage_tick: _clock.stage_tick,
		actor_tick: _clock.actor_tick,
		boss_tick: _clock.boss_tick,
		presentation_tick: _clock.presentation_tick,
	};
}

/// @func BladeSimulationClockMarkPresentation(clock)
/// @desc Advances presentation time once, independently of simulation ticks.
function BladeSimulationClockMarkPresentation(_clock) {
	_BladeSimulationClockRequire(_clock);
	if (_clock.presentation_tick == int64("9223372036854775807")) {
		throw("BladeSimulationClock: presentation tick exceeds signed int64 range");
	}
	_clock.presentation_tick += int64(1);
	return _clock.presentation_tick;
}

/// @func BladeSimulationClockStepDirect(clock, eligibility, tick_callback)
/// @param {Struct} clock
/// @param {Real} eligibility BladeClockDomain bit mask supplied by the caller.
/// @param {Function} tick_callback Optional callback receiving the completed tick view.
function BladeSimulationClockStepDirect(_clock, _eligibility, _tick_callback = undefined) {
	_BladeSimulationClockRequire(_clock);
	_BladeSimulationClockCallback(_tick_callback, "tick callback");
	var _domain_mask = _BladeSimulationClockDomainMask(_eligibility);

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
	if ((_domain_mask & BladeClockDomain.Presentation) != 0) {
		_clock.presentation_tick += int64(1);
	}

	var _tick = BladeSimulationClockGetCounters(_clock);
	_tick.domain_mask = _domain_mask;
	if (is_callable(_tick_callback)) {
		_tick_callback(_tick);
	}
	return _tick;
}

/// @func BladeSimulationClockStepManyDirect(clock, tick_count, eligibility, tick_callback)
/// @param {Struct} clock
/// @param {Real} tick_count Number of exact ticks to run without wall time.
/// @param {Real|Function} eligibility Domain mask or a provider called before each tick.
/// @param {Function} tick_callback Optional callback receiving each completed tick view.
function BladeSimulationClockStepManyDirect(
	_clock,
	_tick_count,
	_eligibility,
	_tick_callback = undefined
) {
	_BladeSimulationClockRequire(_clock);
	_BladeSimulationClockCallback(_tick_callback, "tick callback");
	if (!is_callable(_eligibility)) {
		_BladeSimulationClockDomainMask(_eligibility);
	}
	var _count = _BladeSimulationClockInteger(_tick_count, "direct tick count", 0);
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
/// @param {Real|Function} eligibility Domain mask or a provider called before each tick.
/// @param {Function} tick_callback Optional callback receiving each completed tick view.
/// @returns {Struct} Catch-up, drop, remainder, and counter diagnostics.
function BladeSimulationClockAdvance(
	_clock,
	_delta_us,
	_eligibility,
	_tick_callback = undefined
) {
	_BladeSimulationClockRequire(_clock);
	_BladeSimulationClockCallback(_tick_callback, "tick callback");
	if (!is_callable(_eligibility)) {
		_BladeSimulationClockDomainMask(_eligibility);
	}
	BladeSimulationClockMarkPresentation(_clock);

	var _delta = _BladeSimulationClockInteger(_delta_us, "delta microseconds", 0);
	var _remaining_range = int64("9223372036854775807") - _clock.accumulator_units;
	var _maximum_delta = _remaining_range div int64(_clock.tick_rate);
	if (_delta > _maximum_delta) {
		throw("BladeSimulationClock: delta microseconds exceeds exact accumulator range");
	}

	_clock.accumulator_units += _delta * int64(_clock.tick_rate);
	var _available = _clock.accumulator_units div _clock.accumulator_threshold;
	var _ticks_to_run = _available;
	if (_ticks_to_run > _clock.max_catch_up_ticks) {
		_ticks_to_run = _clock.max_catch_up_ticks;
	}

	var _ran = int64(0);
	while (_ran < _ticks_to_run) {
		// The accumulator owns exactly one presentation increment per update;
		// catch-up ticks cannot duplicate it.
		var _mask = _BladeSimulationClockResolveEligibility(_eligibility, _clock)
			& ~BladeClockDomain.Presentation;
		BladeSimulationClockStepDirect(_clock, _mask, _tick_callback);
		_ran += int64(1);
	}
	_clock.accumulator_units -= _ran * _clock.accumulator_threshold;

	var _dropped = _clock.accumulator_units div _clock.accumulator_threshold;
	_clock.accumulator_units -= _dropped * _clock.accumulator_threshold;
	_clock.total_dropped_ticks += _dropped;

	return {
		ticks_available: _available,
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
