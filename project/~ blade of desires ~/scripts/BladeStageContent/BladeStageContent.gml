/// @description Loads one canonical bundled stage catalog into a validated runtime plan.

/// Throws one field-bound content-loading diagnostic.
function _BladeStageContentFail(_field, _reason) {
	throw("BladeStageContent: " + _field + ": " + _reason);
}

/// Reads one complete text file and closes its handle on every path.
function _BladeStageContentReadText(_path) {
	if (!is_string(_path) || string_length(_path) == 0) {
		_BladeStageContentFail("path", "must be a nonempty string");
	}
	if (!file_exists(_path)) {
		_BladeStageContentFail("path", "does not exist");
	}
	var _file = -1;
	try {
		_file = file_text_open_read(_path);
		if (_file < 0) _BladeStageContentFail("path", "could not be opened");
		var _text = "";
		var _first_line = true;
		while (!file_text_eof(_file)) {
			if (!_first_line) _text += "\n";
			_text += file_text_read_string(_file);
			file_text_readln(_file);
			_first_line = false;
		}
		var _close_result = file_text_close(_file);
		_file = -1;
		if (is_bool(_close_result) && !_close_result) {
			_BladeStageContentFail("path", "could not be closed after reading");
		}
		return _text;
	} catch (_caught) {
		if (_file >= 0) {
			try {
				file_text_close(_file);
			} catch (_close_failure) {
				// The original load failure remains the authoritative diagnostic.
			}
		}
		throw _caught;
	}
}

/// Loads the authoritative product binding only when its raw-file hash matches the run header.
function _BladeStageContentProductBinding(_path, _expected_fingerprint) {
	var _expected = BladeCanonicalRequireSha1Fingerprint(
		_expected_fingerprint, "stage product fingerprint"
	);
	var _text = _BladeStageContentReadText(_path);
	var _actual = "sha1:" + sha1_file(_path);
	if (_actual != _expected) {
		_BladeStageContentFail("product fingerprint", "does not match the active run");
	}
	var _raw;
	try {
		_raw = json_parse(_text, undefined, true);
	} catch (_caught) {
		_BladeStageContentFail("product JSON", "is invalid");
	}
	if (!is_struct(_raw)
		|| !variable_struct_exists(_raw, "id")
		|| !variable_struct_exists(_raw, "content_version")) {
		_BladeStageContentFail("product binding", "is missing id or content_version");
	}
	return {
		id: _BladeStagePlanStableId(_raw.id, "contract", "product contract id"),
		content_version: _BladeStagePlanContentVersion(_raw.content_version),
	};
}

/// @func BladeStageContentDecode(text, gameplay_plane)
/// Parses one raw catalog, normalizes it, and binds a fingerprint to the exact plan bytes.
function BladeStageContentDecode(_text, _gameplay_plane) {
	if (!is_string(_text)) _BladeStageContentFail("text", "must be a string");
	var _raw;
	try {
		// Inhibiting string conversion keeps content text from becoming runtime handles.
		_raw = json_parse(_text, undefined, true);
	} catch (_caught) {
		_BladeStageContentFail("JSON", "is invalid");
	}
	var _normalized = BladeStageCatalogNormalize(_raw, _gameplay_plane);
	return {
		normalized_plan: _normalized,
		plan_fingerprint: BladeStageNormalizedPlanFingerprint(_normalized),
	};
}

/// @func BladeStageContentLoad(path, gameplay_plane)
/// Loads the canonical bundled JSON at one GameMaker data-file path.
function BladeStageContentLoad(_path, _gameplay_plane) {
	return BladeStageContentDecode(
		_BladeStageContentReadText(_path), _gameplay_plane
	);
}

/// @func BladeStageContentCreateExecutor(path, stage_id, participant_spec_resolver, gameplay_plane, product_path, product_fingerprint)
/// Creates an executor only after the catalog and authoritative product binding both validate.
function BladeStageContentCreateExecutor(
	_path, _stage_id, _participant_spec_resolver, _gameplay_plane,
	_product_path, _product_fingerprint
) {
	var _content = BladeStageContentLoad(_path, _gameplay_plane);
	var _product = _BladeStageContentProductBinding(
		_product_path, _product_fingerprint
	);
	if (_content.normalized_plan.product_contract.id != _product.id
		|| _content.normalized_plan.product_contract.content_version
			!= _product.content_version) {
		_BladeStageContentFail(
			"product binding", "stage catalog is incompatible with the active contract"
		);
	}
	return BladeStageExecutorCreate(
		_content.normalized_plan, _content.plan_fingerprint, _stage_id,
		_participant_spec_resolver, _gameplay_plane
	);
}
