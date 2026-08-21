/// @description Defensive JSON parsing and closed version 1 config serialization.

// Separates supported payloads from future data that must never be normalized away.
enum BladeConfigParseKind {
    Current = 1,
    Future = 2,
    Corrupt = 3
}
/// Creates one classified parse result with a stable diagnostic code.
function _BladeConfigParseResult(
    _kind,
    _code,
    _source_version = undefined,
    _config = undefined,
    _was_normalized = false
) {
    return {
        kind: _kind,
        code: _code,
        source_version: _source_version,
        config: _config,
        was_normalized: _was_normalized,
    };
}

/// Builds an explicit binding map so serialized fields follow registry order.
function _BladeConfigSerializerBindingMap(_source) {
    var _result = {};
    var _records = BladeInputBindingRecords();
    for (var _index = 0; _index < array_length(_records); ++_index) {
        var _stable_id = _records[_index].stable_id;
        variable_struct_set(
            _result,
            _stable_id,
            variable_struct_get(_source, _stable_id)
        );
    }
    return _result;
}

/// Builds only the closed version 1 fields in a stable human-readable order.
function _BladeConfigSerializerRecord(_config) {
    return {
        format_id: _config.format_id,
        schema_version: _config.schema_version,
        display: {
            fullscreen: _config.display.fullscreen,
            window_scale: _config.display.window_scale,
            vsync: _config.display.vsync,
        },
        audio: {
            master_gain_percent: _config.audio.master_gain_percent,
            music_gain_percent: _config.audio.music_gain_percent,
            sfx_gain_percent: _config.audio.sfx_gain_percent,
        },
        bindings: {
            keyboard: _BladeConfigSerializerBindingMap(_config.bindings.keyboard),
            gamepad: _BladeConfigSerializerBindingMap(_config.bindings.gamepad),
        },
    };
}

/// @func BladeConfigSerializerParse(text)
/// Parses untrusted JSON without runtime-reference conversion and classifies its version.
function BladeConfigSerializerParse(_text) {
    if (!is_string(_text)) {
        return _BladeConfigParseResult(
            BladeConfigParseKind.Corrupt,
            "config.parse.not_text"
        );
    }

    var _value = undefined;
    try {
        // Inhibiting string conversion prevents JSON text from becoming runtime handles.
        _value = json_parse(_text, undefined, true);
    } catch (_exception) {
        return _BladeConfigParseResult(
            BladeConfigParseKind.Corrupt,
            "config.parse.invalid_json"
        );
    }

    if (!is_struct(_value)
        || !variable_struct_exists(_value, "format_id")
        || !is_string(_value.format_id)
        || _value.format_id != BladeConfigFormatId()) {
        return _BladeConfigParseResult(
            BladeConfigParseKind.Corrupt,
            "config.parse.wrong_format"
        );
    }
    if (!variable_struct_exists(_value, "schema_version")
        || !_BladeConfigFiniteInteger(_value.schema_version)) {
        return _BladeConfigParseResult(
            BladeConfigParseKind.Corrupt,
            "config.parse.invalid_version"
        );
    }

    var _source_version = _value.schema_version;
    if (_source_version > BladeConfigSchemaVersion()) {
        return _BladeConfigParseResult(
            BladeConfigParseKind.Future,
            "config.parse.future_version",
            _source_version
        );
    }
    if (_source_version != BladeConfigSchemaVersion()) {
        return _BladeConfigParseResult(
            BladeConfigParseKind.Corrupt,
            "config.parse.unsupported_legacy",
            _source_version
        );
    }

    var _was_normalized = !BladeConfigIsCanonical(_value);
    return _BladeConfigParseResult(
        BladeConfigParseKind.Current,
        _was_normalized ? "config.parse.normalized" : "config.parse.current",
        _source_version,
        BladeConfigNormalize(_value),
        _was_normalized
    );
}

/// @func BladeConfigSerializerStringify(config)
/// Serializes only a complete canonical config so malformed data cannot reach storage.
function BladeConfigSerializerStringify(_config) {
    if (!BladeConfigIsCanonical(_config)) {
        throw("BladeConfigSerializer: config must be canonical before serialization");
    }
    return json_stringify(_BladeConfigSerializerRecord(_config));
}
