/// @description Closed version 1 player profile and authoritative result rules.

#macro BLADE_PROFILE_FORMAT_ID "blade.profile"
#macro BLADE_PROFILE_SCHEMA_VERSION 1
#macro BLADE_PROFILE_FILENAME "blade-profile.json"
#macro BLADE_PROFILE_STAGE1_ID "stage.stage1.lost_forest_of_aurei"
#macro BLADE_PROFILE_STAGE1_SCHEDULE_ID "stage_schedule.stage1.selected_ship_lost_forest"
#macro BLADE_PROFILE_EXTRA_STAGE_ID "stage.extra.dreams_of_a_clockwork_angel"
#macro BLADE_PROFILE_EXTRA_UNLOCK_ID "unlock.extra_stage"

enum BladeProfileFlagKind {
    Unlock = 1,
    Achievement = 2,
    Cg = 3
}

/// Throws one field-bound profile diagnostic.
function _BladeProfileFail(_field, _reason) {
    throw("BladeProfilePayload: " + string(_field) + ": " + string(_reason));
}

/// Returns whether a value is a finite, exact integer in the supplied range.
function _BladeProfileIntegerInRange(_value, _minimum, _maximum) {
    if (!is_real(_value) || is_bool(_value)
        || is_nan(_value) || is_infinity(_value)
        || floor(_value) != _value) {
        return false;
    }
    return _value >= _minimum && _value <= _maximum;
}

/// Requires the lowercase dotted stable-ID grammar used by profile identities.
function _BladeProfileStableId(_value, _field) {
    if (!is_string(_value) || string_length(_value) < 3) {
        _BladeProfileFail(_field, "must be a lowercase dotted stable ID");
    }
    var _has_dot = false;
    var _segment_start = true;
    for (var _index = 1; _index <= string_length(_value); ++_index) {
        var _character = string_char_at(_value, _index);
        var _byte = string_ord_at(_value, _index);
        if (_character == ".") {
            if (_segment_start || _index == string_length(_value)) {
                _BladeProfileFail(_field, "must be a lowercase dotted stable ID");
            }
            _has_dot = true;
            _segment_start = true;
            continue;
        }
        var _letter = _byte >= 97 && _byte <= 122;
        var _digit = _byte >= 48 && _byte <= 57;
        if ((_segment_start && !_letter)
            || (!_segment_start && !_letter && !_digit && _character != "_")) {
            _BladeProfileFail(_field, "must be a lowercase dotted stable ID");
        }
        _segment_start = false;
    }
    if (!_has_dot) {
        _BladeProfileFail(_field, "must be a lowercase dotted stable ID");
    }
    return _value;
}

/// Requires exactly the named fields without assigning meaning to their order.
function _BladeProfileExactKeys(_value, _expected, _field) {
    if (!is_struct(_value)) {
        _BladeProfileFail(_field, "must be a struct");
    }
    var _actual = variable_struct_get_names(_value);
    if (array_length(_actual) != array_length(_expected)) {
        _BladeProfileFail(_field, "has incomplete or unknown fields");
    }
    for (var _index = 0; _index < array_length(_expected); ++_index) {
        if (!variable_struct_exists(_value, _expected[_index])) {
            _BladeProfileFail(
                _field,
                "requires " + string(_expected[_index])
            );
        }
    }
}

/// Deep-copies plain profile arrays and structs before a candidate is mutated.
function BladeProfileClone(_value) {
    if (is_array(_value)) {
        var _array = [];
        for (var _index = 0; _index < array_length(_value); ++_index) {
            array_push(_array, BladeProfileClone(_value[_index]));
        }
        return _array;
    }
    if (is_struct(_value)) {
        var _copy = {};
        var _names = variable_struct_get_names(_value);
        for (var _name_index = 0;
            _name_index < array_length(_names);
            ++_name_index) {
            var _name = _names[_name_index];
            variable_struct_set(
                _copy,
                _name,
                BladeProfileClone(variable_struct_get(_value, _name))
            );
        }
        return _copy;
    }
    return _value;
}

function BladeProfileFormatId() {
    return BLADE_PROFILE_FORMAT_ID;
}

function BladeProfileSchemaVersion() {
    return BLADE_PROFILE_SCHEMA_VERSION;
}

function BladeProfileFilename() {
    return BLADE_PROFILE_FILENAME;
}

/// Returns the product-contract campaign stages used by the derived unlock rule.
function BladeProfileMainCampaignStageIds() {
    return [
        "stage.stage1.lost_forest_of_aurei",
        "stage.stage2.waters_of_unyielding_life",
        "stage.stage3.under_the_vultures_shadow",
        "stage.stage4.assault_on_the_desert_rose",
        "stage.stage5.banner_of_the_bloody_lion",
        "stage.stage6.blade_of_desires",
    ];
}

/// Returns the current machine-readable ship registry used by Stage 1.
function BladeProfileShipIds() {
    return ["ship.maynii", "ship.ciela", "ship.kolar"];
}

function _BladeProfileContains(_values, _expected) {
    for (var _index = 0; _index < array_length(_values); ++_index) {
        if (_values[_index] == _expected) return true;
    }
    return false;
}

function _BladeProfileKnownShip(_ship_id) {
    return _BladeProfileContains(BladeProfileShipIds(), _ship_id);
}

function _BladeProfileKnownDifficulty(_difficulty_id) {
    return _BladeProfileContains(BladeDifficultyIds(), _difficulty_id);
}

function _BladeProfileStageId(_stage_id, _field) {
    return _BladeProfileStableId(_stage_id, _field);
}

function _BladeProfileResultId(_result_id, _field) {
    _BladeProfileStableId(_result_id, _field);
    if (string_copy(_result_id, 1, 7) != "result.") {
        _BladeProfileFail(_field, "must use the result.* namespace");
    }
    return _result_id;
}

function _BladeProfileFlagArray(_profile, _kind) {
    switch (_kind) {
        case BladeProfileFlagKind.Unlock: return _profile.unlocks;
        case BladeProfileFlagKind.Achievement: return _profile.achievements;
        case BladeProfileFlagKind.Cg: return _profile.cg_flags;
    }
    _BladeProfileFail("flag kind", "is unknown");
    return [];
}

function _BladeProfileFlagField(_kind) {
    switch (_kind) {
        case BladeProfileFlagKind.Unlock: return "unlocks";
        case BladeProfileFlagKind.Achievement: return "achievements";
        case BladeProfileFlagKind.Cg: return "cg_flags";
    }
    _BladeProfileFail("flag kind", "is unknown");
    return "";
}

function _BladeProfileFlagPrefix(_kind) {
    switch (_kind) {
        case BladeProfileFlagKind.Unlock: return "unlock.";
        case BladeProfileFlagKind.Achievement: return "achievement.";
        case BladeProfileFlagKind.Cg: return "cg.";
    }
    _BladeProfileFail("flag kind", "is unknown");
    return "";
}

/// Returns a fresh empty profile; missing data never borrows configuration state.
function BladeProfileCreateDefault() {
    return {
        format_id: BladeProfileFormatId(),
        schema_version: BladeProfileSchemaVersion(),
        clear_states: [],
        unlocks: [],
        achievements: [],
        cg_flags: [],
        records: [],
    };
}

function _BladeProfileStringArrayCanonical(_values, _prefix) {
    if (!is_array(_values)) return false;
    for (var _index = 0; _index < array_length(_values); ++_index) {
        var _value = _values[_index];
        if (!is_string(_value)) return false;
        if (string_copy(_value, 1, string_length(_prefix)) != _prefix) {
            return false;
        }
        try {
            _BladeProfileStableId(_value, "flag");
        } catch (_caught) {
            return false;
        }
        for (var _previous = 0; _previous < _index; ++_previous) {
            if (_values[_previous] == _value) return false;
        }
    }
    return true;
}

function _BladeProfileClearStatesCanonical(_values) {
    if (!is_array(_values)) return false;
    for (var _index = 0; _index < array_length(_values); ++_index) {
        var _state = _values[_index];
        try {
            _BladeProfileExactKeys(
                _state,
                ["stage_id", "ship_id", "difficulty_id", "result_id", "no_continue"],
                "clear_states[" + string(_index) + "]"
            );
            _BladeProfileStageId(_state.stage_id, "clear state stage_id");
            if (!_BladeProfileKnownShip(_state.ship_id)) return false;
            if (!_BladeProfileKnownDifficulty(_state.difficulty_id)) return false;
            _BladeProfileResultId(_state.result_id, "clear state result_id");
            if (_state.result_id != "result.stage_clear" || !is_bool(_state.no_continue)) {
                return false;
            }
        } catch (_caught) {
            return false;
        }
        for (var _previous = 0; _previous < _index; ++_previous) {
            var _other = _values[_previous];
            if (_other.stage_id == _state.stage_id
                && _other.ship_id == _state.ship_id
                && _other.difficulty_id == _state.difficulty_id) {
                return false;
            }
        }
    }
    return true;
}

function _BladeProfileRecordsCanonical(_values) {
    if (!is_array(_values)) return false;
    for (var _index = 0; _index < array_length(_values); ++_index) {
        var _record = _values[_index];
        try {
            _BladeProfileExactKeys(
                _record,
                [
                    "run_id", "stage_id", "result_id", "terminal_result_id",
                    "ship_id", "difficulty_id", "score", "run_seed",
                    "continue_used",
                ],
                "records[" + string(_index) + "]"
            );
            if (!is_string(_record.run_id)
                || string_copy(_record.run_id, 1, 4) != "run:") {
                return false;
            }
            _BladeProfileStageId(_record.stage_id, "record stage_id");
            _BladeProfileResultId(_record.result_id, "record result_id");
            _BladeProfileResultId(
                _record.terminal_result_id, "record terminal_result_id"
            );
            if (!_BladeProfileKnownShip(_record.ship_id)
                || !_BladeProfileKnownDifficulty(_record.difficulty_id)
                || !_BladeProfileIntegerInRange(
                    _record.score, 0, 9007199254740991
                )
                || !_BladeProfileIntegerInRange(
                    _record.run_seed, 0, 4294967295
                )
                || !is_bool(_record.continue_used)) {
                return false;
            }
        } catch (_caught) {
            return false;
        }
        for (var _previous = 0; _previous < _index; ++_previous) {
            if (_values[_previous].run_id == _record.run_id) return false;
        }
    }
    return true;
}

/// Validates the exact closed profile representation and every machine ID.
function BladeProfileIsCanonical(_profile) {
    if (!is_struct(_profile)) return false;
    try {
        _BladeProfileExactKeys(
            _profile,
            [
                "format_id", "schema_version", "clear_states", "unlocks",
                "achievements", "cg_flags", "records",
            ],
            "profile"
        );
        if (_profile.format_id != BladeProfileFormatId()
            || !_BladeProfileIntegerInRange(
                _profile.schema_version,
                BladeProfileSchemaVersion(),
                BladeProfileSchemaVersion()
            )) {
            return false;
        }
    } catch (_caught) {
        return false;
    }
    return _BladeProfileClearStatesCanonical(_profile.clear_states)
        && _BladeProfileStringArrayCanonical(_profile.unlocks, "unlock.")
        && _BladeProfileStringArrayCanonical(
            _profile.achievements, "achievement."
        )
        && _BladeProfileStringArrayCanonical(_profile.cg_flags, "cg.")
        && _BladeProfileRecordsCanonical(_profile.records);
}

/// Adds an independent unlock, achievement, or CG flag once.
function BladeProfileGrantFlag(_profile, _kind, _flag_id) {
    if (!BladeProfileIsCanonical(_profile)) {
        _BladeProfileFail("profile", "must be canonical");
    }
    _BladeProfileStableId(_flag_id, "flag_id");
    var _prefix = _BladeProfileFlagPrefix(_kind);
    if (string_copy(_flag_id, 1, string_length(_prefix)) != _prefix) {
        _BladeProfileFail("flag_id", "does not match its flag namespace");
    }
    var _flags = _BladeProfileFlagArray(_profile, _kind);
    if (_BladeProfileContains(_flags, _flag_id)) return false;
    array_push(_flags, _flag_id);
    return true;
}

function BladeProfileHasFlag(_profile, _kind, _flag_id) {
    if (!BladeProfileIsCanonical(_profile)) {
        _BladeProfileFail("profile", "must be canonical");
    }
    return _BladeProfileContains(_BladeProfileFlagArray(_profile, _kind), _flag_id);
}

function BladeProfileGrantUnlock(_profile, _flag_id) {
    return BladeProfileGrantFlag(_profile, BladeProfileFlagKind.Unlock, _flag_id);
}

function BladeProfileGrantAchievement(_profile, _flag_id) {
    return BladeProfileGrantFlag(
        _profile, BladeProfileFlagKind.Achievement, _flag_id
    );
}

function BladeProfileGrantCgFlag(_profile, _flag_id) {
    return BladeProfileGrantFlag(_profile, BladeProfileFlagKind.Cg, _flag_id);
}

function BladeProfileHasUnlock(_profile, _flag_id) {
    return BladeProfileHasFlag(_profile, BladeProfileFlagKind.Unlock, _flag_id);
}

/// Records one successful clear state without changing an existing state.
function BladeProfileRecordClear(
    _profile, _stage_id, _ship_id, _difficulty_id, _no_continue = true
) {
    if (!BladeProfileIsCanonical(_profile)) {
        _BladeProfileFail("profile", "must be canonical");
    }
    _BladeProfileStageId(_stage_id, "stage_id");
    if (!_BladeProfileKnownShip(_ship_id)) {
        _BladeProfileFail("ship_id", "is not a known profile ship");
    }
    if (!_BladeProfileKnownDifficulty(_difficulty_id)) {
        _BladeProfileFail("difficulty_id", "is not a known difficulty");
    }
    if (!is_bool(_no_continue)) {
        _BladeProfileFail("no_continue", "must be Boolean");
    }
    for (var _index = 0; _index < array_length(_profile.clear_states); ++_index) {
        var _existing = _profile.clear_states[_index];
        if (_existing.stage_id == _stage_id
            && _existing.ship_id == _ship_id
            && _existing.difficulty_id == _difficulty_id) {
            if (_no_continue && !_existing.no_continue) {
                _existing.no_continue = true;
            }
            return false;
        }
    }
    array_push(_profile.clear_states, {
        stage_id: _stage_id,
        ship_id: _ship_id,
        difficulty_id: _difficulty_id,
        result_id: "result.stage_clear",
        no_continue: _no_continue,
    });
    return true;
}

/// Recomputes the one current derived campaign unlock from clear states.
function BladeProfileRecomputeDerivedUnlocks(_profile) {
    if (!BladeProfileIsCanonical(_profile)) {
        _BladeProfileFail("profile", "must be canonical");
    }
    var _one_cc = true;
    var _stages = BladeProfileMainCampaignStageIds();
    for (var _stage_index = 0; _stage_index < array_length(_stages); ++_stage_index) {
        var _found = false;
        for (var _clear_index = 0;
            _clear_index < array_length(_profile.clear_states);
            ++_clear_index) {
            var _clear = _profile.clear_states[_clear_index];
            if (_clear.stage_id == _stages[_stage_index]) {
                _found = true;
                if (!_clear.no_continue) _one_cc = false;
                break;
            }
        }
        if (!_found) _one_cc = false;
    }
    if (_one_cc) {
        BladeProfileGrantUnlock(_profile, BLADE_PROFILE_EXTRA_UNLOCK_ID);
    }
    return _profile;
}

function _BladeProfileRunResultHasEvent(_result, _event) {
    for (var _index = 0; _index < array_length(_result.event_history); ++_index) {
        var _entry = _result.event_history[_index];
        if (is_struct(_entry)
            && variable_struct_exists(_entry, "event")
            && _entry.event == _event) {
            return true;
        }
    }
    return false;
}

/// Converts the current Stage 1 result boundary into a persisted arcade record.
function _BladeProfileRecordFromRunResult(_result) {
    if (!is_struct(_result)
        || !variable_struct_exists(
            _result, "__blade_stage1_run_result_version"
        )
        || _result.__blade_stage1_run_result_version != 1
        || !variable_struct_exists(_result, "phase")
        || _result.phase != BladeStage1RunResultPhase.RunCompleted
        || _result.terminal_outcome != BladeStage1RunResultEvent.RunComplete
        || !is_struct(_result.clear_result)
        || !is_struct(_result.run_completion)) {
        return { ok: false, code: "profile.apply.incomplete_result" };
    }
    if (_BladeProfileRunResultHasEvent(
            _result, BladeStage1RunResultEvent.GameOver
        )
        || _BladeProfileRunResultHasEvent(
            _result, BladeStage1RunResultEvent.Continue
        )
        || _BladeProfileRunResultHasEvent(
            _result, BladeStage1RunResultEvent.Retry
        )
        || _BladeProfileRunResultHasEvent(
            _result, BladeStage1RunResultEvent.Abort
        )) {
        return { ok: false, code: "profile.apply.nonqualifying_result" };
    }

    var _clear = _result.clear_result;
    var _completion = _result.run_completion;
    if (!variable_struct_exists(_clear, "outcome")
        || _clear.outcome != BladeStage1RunResultEvent.StageClear
        || !variable_struct_exists(_completion, "outcome")
        || _completion.outcome != BladeStage1RunResultEvent.RunComplete
        || !variable_struct_exists(_clear, "selection")
        || !is_struct(_clear.selection)
        || !variable_struct_exists(_clear, "stage_boundary")
        || !is_struct(_clear.stage_boundary)
        || !variable_struct_exists(_clear, "economy")
        || !is_struct(_clear.economy)
        || !variable_struct_exists(_clear, "run_identity")
        || !is_struct(_clear.run_identity)) {
        return { ok: false, code: "profile.apply.invalid_clear_boundary" };
    }
    if (_clear.stage_boundary.stage_id != BLADE_PROFILE_STAGE1_SCHEDULE_ID) {
        return { ok: false, code: "profile.apply.unsupported_stage" };
    }
    var _selection = _clear.selection;
    var _economy = _clear.economy;
    var _identity = _clear.run_identity;
    if (!variable_struct_exists(_selection, "ship_id")
        || !variable_struct_exists(_selection, "difficulty_id")
        || !_BladeProfileKnownShip(_selection.ship_id)
        || !_BladeProfileKnownDifficulty(_selection.difficulty_id)
        || !variable_struct_exists(_economy, "score")
        || !_BladeProfileIntegerInRange(_economy.score, 0, 9007199254740991)
        || !variable_struct_exists(_identity, "run_seed")
        || !_BladeProfileIntegerInRange(_identity.run_seed, 0, 4294967295)) {
        return { ok: false, code: "profile.apply.invalid_terminal_fields" };
    }

    var _plan_fingerprint = variable_struct_exists(
        _identity, "stage_plan_fingerprint"
    ) ? string(_identity.stage_plan_fingerprint) : "";
    var _gameplay_hash = variable_struct_exists(
        _identity, "gameplay_hash"
    ) ? string(_identity.gameplay_hash) : "";
    var _run_id = "run:" + BladeCanonicalRecordHash("P1", [
        BLADE_PROFILE_STAGE1_ID,
        _selection.ship_id,
        _selection.difficulty_id,
        string(_identity.run_seed),
        _plan_fingerprint,
        _gameplay_hash,
    ]);
    return {
        ok: true,
        record: {
            run_id: _run_id,
            stage_id: BLADE_PROFILE_STAGE1_ID,
            result_id: "result.stage_clear",
            terminal_result_id: "result.run_complete",
            ship_id: _selection.ship_id,
            difficulty_id: _selection.difficulty_id,
            score: _economy.score,
            run_seed: _identity.run_seed,
            continue_used: false,
        },
    };
}

/// Applies only a live, completed, non-administrative terminal result.
function BladeProfileApplyRunResult(_profile, _result, _source = "live") {
    if (!BladeProfileIsCanonical(_profile)) {
        return {
            ok: false,
            code: "profile.apply.invalid_profile",
            profile: BladeProfileClone(_profile),
        };
    }
    if (_source != "live") {
        return {
            ok: false,
            code: "profile.apply.non_live_source",
            profile: BladeProfileClone(_profile),
        };
    }
    var _record_result = _BladeProfileRecordFromRunResult(_result);
    if (!_record_result.ok) {
        return {
            ok: false,
            code: _record_result.code,
            profile: BladeProfileClone(_profile),
        };
    }
    var _candidate = BladeProfileClone(_profile);
    var _record = _record_result.record;
    for (var _index = 0; _index < array_length(_candidate.records); ++_index) {
        if (_candidate.records[_index].run_id == _record.run_id) {
            return {
                ok: false,
                code: "profile.apply.duplicate_result",
                profile: _candidate,
            };
        }
    }
    BladeProfileRecordClear(
        _candidate,
        _record.stage_id,
        _record.ship_id,
        _record.difficulty_id,
        !_record.continue_used
    );
    array_push(_candidate.records, _record);
    BladeProfileRecomputeDerivedUnlocks(_candidate);
    return {
        ok: true,
        code: "profile.apply.recorded",
        profile: _candidate,
        record: _record,
    };
}
