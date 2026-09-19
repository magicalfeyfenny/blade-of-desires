/// @description Defensive JSON parsing and closed version 1 profile serialization.

enum BladeProfileParseKind {
    Current = 1,
    Future = 2,
    Corrupt = 3
}

function _BladeProfileParseResult(
    _kind, _code, _source_version = undefined, _profile = undefined
) {
    return {
        kind: _kind,
        code: _code,
        source_version: _source_version,
        profile: _profile,
    };
}

/// Builds stable record fields without serializing runtime methods or references.
function _BladeProfileSerializerRecord(_profile) {
    var _clear_states = [];
    for (var _clear_index = 0;
        _clear_index < array_length(_profile.clear_states);
        ++_clear_index) {
        var _clear = _profile.clear_states[_clear_index];
        array_push(_clear_states, {
            stage_id: _clear.stage_id,
            ship_id: _clear.ship_id,
            difficulty_id: _clear.difficulty_id,
            result_id: _clear.result_id,
            no_continue: _clear.no_continue,
        });
    }
    var _records = [];
    for (var _record_index = 0;
        _record_index < array_length(_profile.records);
        ++_record_index) {
        var _record = _profile.records[_record_index];
        array_push(_records, {
            run_id: _record.run_id,
            stage_id: _record.stage_id,
            result_id: _record.result_id,
            terminal_result_id: _record.terminal_result_id,
            ship_id: _record.ship_id,
            difficulty_id: _record.difficulty_id,
            score: _record.score,
            run_seed: _record.run_seed,
            continue_used: _record.continue_used,
        });
    }
    return {
        format_id: _profile.format_id,
        schema_version: _profile.schema_version,
        clear_states: _clear_states,
        unlocks: _profile.unlocks,
        achievements: _profile.achievements,
        cg_flags: _profile.cg_flags,
        records: _records,
    };
}

/// Parses untrusted JSON without normalizing malformed or future profile data.
function BladeProfileSerializerParse(_text) {
    if (!is_string(_text)) {
        return _BladeProfileParseResult(
            BladeProfileParseKind.Corrupt,
            "profile.parse.not_text"
        );
    }
    var _value = undefined;
    try {
        // Inhibiting string conversion prevents JSON text from becoming runtime handles.
        _value = json_parse(_text, undefined, true);
    } catch (_exception) {
        return _BladeProfileParseResult(
            BladeProfileParseKind.Corrupt,
            "profile.parse.invalid_json"
        );
    }
    if (!is_struct(_value)
        || !variable_struct_exists(_value, "format_id")
        || !is_string(_value.format_id)
        || _value.format_id != BladeProfileFormatId()) {
        return _BladeProfileParseResult(
            BladeProfileParseKind.Corrupt,
            "profile.parse.wrong_format"
        );
    }
    if (!variable_struct_exists(_value, "schema_version")
        || !_BladeProfileIntegerInRange(
            _value.schema_version, 0, 9007199254740991
        )) {
        return _BladeProfileParseResult(
            BladeProfileParseKind.Corrupt,
            "profile.parse.invalid_version"
        );
    }
    var _source_version = _value.schema_version;
    if (_source_version > BladeProfileSchemaVersion()) {
        return _BladeProfileParseResult(
            BladeProfileParseKind.Future,
            "profile.parse.future_version",
            _source_version
        );
    }
    if (_source_version != BladeProfileSchemaVersion()
        || !BladeProfileIsCanonical(_value)) {
        return _BladeProfileParseResult(
            BladeProfileParseKind.Corrupt,
            _source_version != BladeProfileSchemaVersion()
                ? "profile.parse.unsupported_legacy"
                : "profile.parse.invalid_shape",
            _source_version
        );
    }
    return _BladeProfileParseResult(
        BladeProfileParseKind.Current,
        "profile.parse.current",
        _source_version,
        BladeProfileClone(_value)
    );
}

/// Serializes only a complete canonical profile.
function BladeProfileSerializerStringify(_profile) {
    if (!BladeProfileIsCanonical(_profile)) {
        throw("BladeProfileSerializer: profile must be canonical before serialization");
    }
    return json_stringify(_BladeProfileSerializerRecord(_profile));
}
