/// Construction-time replay/session compatibility fields with cached canonical bytes.

/// @func BladeSessionFormatVersion()
/// Supplies the numeric format field stored and encoded by each session header.
function BladeSessionFormatVersion() {
	return 1;
}

/// @func BladeSimulationContractVersion()
/// Supplies the simulation-contract string stored and encoded by each session header.
function BladeSimulationContractVersion() {
	return "blade.simulation.v1";
}

/// @func BladeSimulationTickRate()
/// Supplies the fixed integer tick-rate field stored and encoded by each session header.
function BladeSimulationTickRate() {
	return 60;
}

/// @func BladeSessionHeader(content_contract_fingerprint, run_seed)
/// Validates the injected fingerprint and seed, stores all compatibility fields,
/// then caches one fixed-order H1 record and its hash.
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

	var _format_text = BladeCanonicalIntegerString(
		__format_version,
		1,
		1,
		"session format version"
	);
	var _tick_rate_text = BladeCanonicalIntegerString(
		__tick_rate,
		60,
		60,
		"simulation tick rate"
	);
	var _seed_text = BladeCanonicalIntegerString(
		__run_seed,
		int64(0),
		int64("4294967295"),
		"normalized run seed"
	);
	// H1 fixes construction-time fields in this order.
	// Length framing makes each field's bytes explicit.
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
	/// Returns the format-version field without rebuilding the cached H1 bytes.
	function get_format_version() {
		return __format_version;
	}

	/// @func get_simulation_contract_version()
	/// Returns the simulation-contract field without rebuilding the cached H1 bytes.
	function get_simulation_contract_version() {
		return __simulation_contract_version;
	}

	/// @func get_content_contract_fingerprint()
	/// Returns the fingerprint field; the constructor validated its initial text.
	function get_content_contract_fingerprint() {
		return __content_contract_fingerprint;
	}

	/// @func get_prng_version()
	/// Returns the PRNG-version field without rebuilding the cached H1 bytes.
	function get_prng_version() {
		return __prng_version;
	}

	/// @func get_tick_rate()
	/// Returns the tick-rate field without rebuilding the cached H1 bytes.
	function get_tick_rate() {
		return __tick_rate;
	}

	/// @func get_run_seed()
	/// Returns the seed field; the constructor normalized its initial value to u32 range.
	function get_run_seed() {
		return __run_seed;
	}

	/// @func canonical()
	/// Returns the construction-time H1 string instead of rebuilding it from exposed fields.
	function canonical() {
		return __canonical;
	}

	/// @func hash()
	/// Returns the bare lowercase SHA-1 cached from the construction-time H1 string.
	function hash() {
		return __hash;
	}

	/// @func to_struct()
	/// @desc Returns a fresh diagnostic copy; mutating it cannot affect the header.
	/// Copies current stored fields and cached bytes into a new diagnostic struct.
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
