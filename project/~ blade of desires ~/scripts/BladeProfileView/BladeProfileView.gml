/// @description Read-only profile projection for the title front end.

enum BladeProfileViewState {
    Ready = 1,
    Unavailable = 2
}

function _BladeProfileViewEmpty(_state, _status, _code) {
    return {
        __blade_profile_view_version: 1,
        state: _state,
        status: _status,
        code: _code,
        clear_entries: [],
        unlock_entries: [],
        achievement_entries: [],
        cg_entries: [],
        records: [],
    };
}

/// Returns a short diagnostic token without exposing the storage exception.
function BladeProfileViewStatusLabel(_status) {
    switch (_status) {
        case BladeProfileLoadStatus.MissingDefaults: return "EMPTY PROFILE";
        case BladeProfileLoadStatus.Loaded: return "PROFILE LOADED";
        case BladeProfileLoadStatus.Corrupt: return "CORRUPT PROFILE";
        case BladeProfileLoadStatus.Future: return "UNSUPPORTED PROFILE";
        case BladeProfileLoadStatus.ReadFailed: return "PROFILE READ FAILED";
    }
    return "PROFILE UNAVAILABLE";
}

/// Maps stable identities to authored labels without grouping by display text.
function BladeProfileViewDisplayLabel(_id) {
    switch (_id) {
        case BLADE_PROFILE_STAGE1_ID: return "LOST FOREST OF AUREI";
        case "stage.stage2.waters_of_unyielding_life":
            return "WATERS OF UNYIELDING LIFE";
        case "stage.stage3.under_the_vultures_shadow":
            return "UNDER THE VULTURES' SHADOW";
        case "stage.stage4.assault_on_the_desert_rose":
            return "ASSAULT ON THE DESERT ROSE";
        case "stage.stage5.banner_of_the_bloody_lion":
            return "BANNER OF THE BLOODY LION";
        case "stage.stage6.blade_of_desires": return "BLADE OF DESIRES";
        case BLADE_PROFILE_EXTRA_STAGE_ID:
            return "DREAMS OF A CLOCKWORK ANGEL";
        case "ship.maynii": return "MAYNII";
        case "ship.ciela": return "CIELA";
        case "ship.kolar": return "KOLAR";
        case BLADE_DIFFICULTY_EASY_ID:
        case BLADE_DIFFICULTY_NORMAL_ID:
        case BLADE_DIFFICULTY_HARD_ID:
            return string_upper(BladeDifficultyContractName(_id));
        case BLADE_PROFILE_EXTRA_UNLOCK_ID: return "EXTRA STAGE";
        case "achievement.first_clear": return "FIRST CLEAR";
        case "cg.intro_scene": return "INTRO SCENE";
    }

    // Unknown future flags remain visible as identifiers instead of being lost.
    var _label = string_upper(string(_id));
    _label = string_replace_all(_label, ".", " ");
    return string_replace_all(_label, "_", " ");
}

function _BladeProfileViewClearEntries(_profile) {
    var _entries = [];
    for (var _index = 0;
        _index < array_length(_profile.clear_states);
        ++_index) {
        var _clear = _profile.clear_states[_index];
        array_push(_entries, {
            stage_id: _clear.stage_id,
            stage_label: BladeProfileViewDisplayLabel(_clear.stage_id),
            ship_id: _clear.ship_id,
            ship_label: BladeProfileViewDisplayLabel(_clear.ship_id),
            difficulty_id: _clear.difficulty_id,
            difficulty_label: BladeProfileViewDisplayLabel(_clear.difficulty_id),
            result_id: _clear.result_id,
            no_continue: _clear.no_continue,
            status_label: _clear.no_continue ? "1CC" : "CONTINUE",
        });
    }
    return _entries;
}

function _BladeProfileViewKnownUnlock(_values, _id) {
    for (var _index = 0; _index < array_length(_values); ++_index) {
        if (_values[_index] == _id) return true;
    }
    return false;
}

function _BladeProfileViewUnlockEntries(_profile) {
    var _entries = [];
    var _known = [BLADE_PROFILE_EXTRA_UNLOCK_ID];
    for (var _known_index = 0;
        _known_index < array_length(_known);
        ++_known_index) {
        var _known_id = _known[_known_index];
        array_push(_entries, {
            id: _known_id,
            label: BladeProfileViewDisplayLabel(_known_id),
            granted: _BladeProfileViewKnownUnlock(_profile.unlocks, _known_id),
        });
    }
    for (var _index = 0; _index < array_length(_profile.unlocks); ++_index) {
        var _id = _profile.unlocks[_index];
        if (_BladeProfileViewKnownUnlock(_known, _id)) continue;
        array_push(_entries, {
            id: _id,
            label: BladeProfileViewDisplayLabel(_id),
            granted: true,
        });
    }
    return _entries;
}

function _BladeProfileViewFlagEntries(_values, _kind) {
    var _entries = [];
    for (var _index = 0; _index < array_length(_values); ++_index) {
        var _id = _values[_index];
        array_push(_entries, {
            id: _id,
            label: BladeProfileViewDisplayLabel(_id),
            kind: _kind,
            granted: true,
        });
    }
    return _entries;
}

function _BladeProfileViewRecordEntries(_profile) {
    var _entries = [];
    for (var _index = 0; _index < array_length(_profile.records); ++_index) {
        var _record = _profile.records[_index];
        array_push(_entries, {
            run_id: _record.run_id,
            stage_id: _record.stage_id,
            stage_label: BladeProfileViewDisplayLabel(_record.stage_id),
            result_id: _record.result_id,
            terminal_result_id: _record.terminal_result_id,
            ship_id: _record.ship_id,
            ship_label: BladeProfileViewDisplayLabel(_record.ship_id),
            difficulty_id: _record.difficulty_id,
            difficulty_label: BladeProfileViewDisplayLabel(_record.difficulty_id),
            score: _record.score,
            run_seed: _record.run_seed,
            continue_used: _record.continue_used,
        });
    }
    return _entries;
}

/// Creates only detached display data; it never parses or writes profile storage.
function BladeProfileViewCreate(_load_result = undefined) {
    if (is_undefined(_load_result)) {
        _load_result = {
            ok: true,
            status: BladeProfileLoadStatus.MissingDefaults,
            code: "profile.load.missing",
            profile: BladeProfileCreateDefault(),
        };
    }
    if (!is_struct(_load_result)
        || !variable_struct_exists(_load_result, "ok")
        || !variable_struct_exists(_load_result, "status")
        || !variable_struct_exists(_load_result, "code")
        || !is_string(_load_result.code)) {
        return _BladeProfileViewEmpty(
            BladeProfileViewState.Unavailable,
            BladeProfileLoadStatus.ReadFailed,
            "profile.view.invalid_load_result"
        );
    }
    if (_load_result.ok != true) {
        return _BladeProfileViewEmpty(
            BladeProfileViewState.Unavailable,
            _load_result.status,
            _load_result.code
        );
    }
    if (!variable_struct_exists(_load_result, "profile")
        || !BladeProfileIsCanonical(_load_result.profile)) {
        return _BladeProfileViewEmpty(
            BladeProfileViewState.Unavailable,
            BladeProfileLoadStatus.ReadFailed,
            "profile.view.invalid_profile"
        );
    }

    var _profile = BladeProfileClone(_load_result.profile);
    return {
        __blade_profile_view_version: 1,
        state: BladeProfileViewState.Ready,
        status: _load_result.status,
        code: _load_result.code,
        clear_entries: _BladeProfileViewClearEntries(_profile),
        unlock_entries: _BladeProfileViewUnlockEntries(_profile),
        achievement_entries: _BladeProfileViewFlagEntries(
            _profile.achievements, "achievement"
        ),
        cg_entries: _BladeProfileViewFlagEntries(_profile.cg_flags, "cg"),
        records: _BladeProfileViewRecordEntries(_profile),
    };
}

function BladeProfileViewIsValid(_view) {
    return is_struct(_view)
        && variable_struct_exists(_view, "__blade_profile_view_version")
        && _view.__blade_profile_view_version == 1
        && variable_struct_exists(_view, "state")
        && (_view.state == BladeProfileViewState.Ready
            || _view.state == BladeProfileViewState.Unavailable)
        && variable_struct_exists(_view, "status")
        && variable_struct_exists(_view, "code")
        && is_string(_view.code)
        && variable_struct_exists(_view, "clear_entries")
        && is_array(_view.clear_entries)
        && variable_struct_exists(_view, "unlock_entries")
        && is_array(_view.unlock_entries)
        && variable_struct_exists(_view, "achievement_entries")
        && is_array(_view.achievement_entries)
        && variable_struct_exists(_view, "cg_entries")
        && is_array(_view.cg_entries)
        && variable_struct_exists(_view, "records")
        && is_array(_view.records);
}
