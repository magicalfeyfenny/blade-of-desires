/// Immutable replay/session compatibility header for the deterministic kernel.

/// @func BladeSessionFormatVersion()
function BladeSessionFormatVersion() {
	return 1;
}

/// @func BladeSimulationContractVersion()
function BladeSimulationContractVersion() {
	return "blade.simulation.v1";
}

/// @func BladeSimulationTickRate()
function BladeSimulationTickRate() {
	return 60;
}

/// @func BladeSessionHeader(content_contract_fingerprint, run_seed)
function BladeSessionHeader(_content_contract_fingerprint, _run_seed) constructor {
	__format_version = BladeSessionFormatVersion();
	__simulation_contract_version = BladeSimulationContractVersion();
	__content_contract_fingerprint = BladeCanonicalRequireSha1Fingerprint(
		_content_contract_fingerprint,
		"content contract fingerprint"
	);
	__prng_version = BladeRandomAlgorithmVersion();
	__tick_rate = BladeSimulationTickRate();
	__run_seed = BladeRandomNormalizeSeed(_run_seed);

	var _format_text = BladeCanonicalIntegerString(__format_version, 1, 1, "session format version");
	var _tick_rate_text = BladeCanonicalIntegerString(__tick_rate, 60, 60, "simulation tick rate");
	var _seed_text = BladeCanonicalIntegerString(
		__run_seed,
		int64(0),
		int64("4294967295"),
		"normalized run seed"
	);
	__canonical = BladeCanonicalRecord("H1", [
		_format_text,
		__simulation_contract_version,
		__content_contract_fingerprint,
		__prng_version,
		_tick_rate_text,
		_seed_text,
	]);
	__hash = BladeCanonicalHashUtf8(__canonical);

	/// @func get_format_version()
	function get_format_version() {
		return __format_version;
	}

	/// @func get_simulation_contract_version()
	function get_simulation_contract_version() {
		return __simulation_contract_version;
	}

	/// @func get_content_contract_fingerprint()
	function get_content_contract_fingerprint() {
		return __content_contract_fingerprint;
	}

	/// @func get_prng_version()
	function get_prng_version() {
		return __prng_version;
	}

	/// @func get_tick_rate()
	function get_tick_rate() {
		return __tick_rate;
	}

	/// @func get_run_seed()
	function get_run_seed() {
		return __run_seed;
	}

	/// @func canonical()
	function canonical() {
		return __canonical;
	}

	/// @func hash()
	function hash() {
		return __hash;
	}

	/// @func to_struct()
	/// @desc Returns a fresh diagnostic copy; mutating it cannot affect the header.
	function to_struct() {
		return {
			format_version: __format_version,
			simulation_contract_version: __simulation_contract_version,
			content_contract_fingerprint: __content_contract_fingerprint,
			prng_version: __prng_version,
			tick_rate: __tick_rate,
			run_seed: __run_seed,
			canonical: __canonical,
			hash: __hash,
		};
	}
}
