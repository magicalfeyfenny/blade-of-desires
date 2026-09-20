/// @description File-backed replay discovery, classification, and playback launch.

enum BladeReplayCatalogEntryState {
    Playable = 1,
    Unsupported = 2,
    Corrupt = 3,
    Missing = 4,
    Unreadable = 5,
}

#macro BLADE_REPLAY_CATALOG_DIRECTORY "blade-replays"
#macro BLADE_REPLAY_CATALOG_EXTENSION ".brp"

/// Returns the machine-readable state token shown by the catalog UI.
function BladeReplayCatalogEntryStateToken(_state) {
    switch (_state) {
        case BladeReplayCatalogEntryState.Playable: return "playable";
        case BladeReplayCatalogEntryState.Unsupported: return "unsupported";
        case BladeReplayCatalogEntryState.Corrupt: return "corrupt";
        case BladeReplayCatalogEntryState.Missing: return "missing";
        case BladeReplayCatalogEntryState.Unreadable: return "unreadable";
    }
    throw("BladeReplayCatalog: unknown entry state");
}

/// Returns the production relative directory used by the platform save area.
function BladeReplayCatalogDirectory() {
    return BLADE_REPLAY_CATALOG_DIRECTORY;
}

/// Requires the bare SHA-1 form that the canonical replay parser emits.
function _BladeReplayCatalogReplayId(_hash) {
    if (!is_string(_hash)
        || string_length(_hash) != 40) {
        throw("BladeReplayCatalog: replay hash is not a SHA-1 fingerprint");
    }
    BladeCanonicalRequireSha1Fingerprint(
        "sha1:" + _hash, "replay hash"
    );
    return "replay." + _hash;
}

/// Maps a replay identity to the only filename produced by the save path.
function BladeReplayCatalogPathForId(_replay_id) {
    if (!is_string(_replay_id)
        || string_copy(_replay_id, 1, 7) != "replay."
        || string_length(_replay_id) != 47) {
        throw("BladeReplayCatalog: replay ID is not canonical");
    }
    return BLADE_REPLAY_CATALOG_DIRECTORY + "/"
        + string_copy(_replay_id, 8, 40)
        + BLADE_REPLAY_CATALOG_EXTENSION;
}

/// Creates one read-only catalog entry from validated BRP1 metadata.
function _BladeReplayCatalogPlayableEntry(_path, _recording) {
    return {
        __blade_replay_catalog_entry_version: 1,
        replay_id: _BladeReplayCatalogReplayId(_recording.hash),
        file_path: _path,
        state: BladeReplayCatalogEntryState.Playable,
        state_token: BladeReplayCatalogEntryStateToken(
            BladeReplayCatalogEntryState.Playable
        ),
        reason: "",
        content_fingerprint: _recording.content_fingerprint,
        run_seed: _recording.run_seed,
        ship_id: _recording.ship_id,
        difficulty_id: _recording.difficulty_id,
        run_mode: _recording.run_mode,
        input_count: _recording.input_count,
        progress_ticks: _recording.input_count,
        terminal_result: "not_recorded",
        has_score: false,
        score: int64(0),
    };
}

/// Creates a stable invalid entry without treating its filename as replay data.
function _BladeReplayCatalogInvalidEntry(_path, _state, _reason) {
    return {
        __blade_replay_catalog_entry_version: 1,
        replay_id: "",
        file_path: _path,
        state: _state,
        state_token: BladeReplayCatalogEntryStateToken(_state),
        reason: _reason,
        content_fingerprint: "",
        run_seed: int64(-1),
        ship_id: "",
        difficulty_id: "",
        run_mode: 0,
        input_count: int64(-1),
        progress_ticks: int64(-1),
        terminal_result: "unavailable",
        has_score: false,
        score: int64(0),
    };
}

/// Reads one complete text file and reports missing versus unreadable data.
function _BladeReplayCatalogFileReadText(_path) {
    var _file = -1;
    try {
        _file = file_text_open_read(_path);
        if (_file < 0) {
            return { ok: false, text: "", code: "replay.catalog.missing" };
        }
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
            return { ok: false, text: "", code: "replay.catalog.unreadable" };
        }
        return { ok: true, text: _text, code: "replay.catalog.read" };
    } catch (_caught) {
        if (_file >= 0) {
            try {
                file_text_close(_file);
            } catch (_close_exception) {
                // The original read failure is the useful diagnostic.
            }
        }
        return {
            ok: false,
            text: "",
            code: "replay.catalog.unreadable",
            diagnostic: string(_caught),
        };
    }
}

/// Enumerates only replay payload files in the per-user catalog directory.
function _BladeReplayCatalogFileList() {
    var _paths = [];
    if (!directory_exists(BLADE_REPLAY_CATALOG_DIRECTORY)) {
        return { ok: true, paths: [], code: "replay.catalog.empty" };
    }
    try {
        var _path = file_find_first(
            BLADE_REPLAY_CATALOG_DIRECTORY + "/*" + BLADE_REPLAY_CATALOG_EXTENSION,
            fa_none
        );
        while (_path != "") {
            array_push(
                _paths,
                BLADE_REPLAY_CATALOG_DIRECTORY + "/" + _path
            );
            _path = file_find_next();
        }
        file_find_close();
        return { ok: true, paths: _paths, code: "replay.catalog.listed" };
    } catch (_caught) {
        try {
            file_find_close();
        } catch (_close_exception) {
            // The enumeration failure remains the authoritative result.
        }
        return {
            ok: false,
            paths: [],
            code: "replay.catalog.list_failed",
            diagnostic: string(_caught),
        };
    }
}

/// Writes one canonical payload after creating the save-area directory.
function _BladeReplayCatalogFileWriteText(_path, _text) {
    try {
        if (!directory_exists(BLADE_REPLAY_CATALOG_DIRECTORY)
            && !directory_create(BLADE_REPLAY_CATALOG_DIRECTORY)) {
            return { ok: false, code: "replay.catalog.directory_failed" };
        }
        var _file = file_text_open_write(_path);
        if (_file < 0) {
            return { ok: false, code: "replay.catalog.write_failed" };
        }
        file_text_write_string(_file, _text);
        var _close_result = file_text_close(_file);
        if (is_bool(_close_result) && !_close_result) {
            return { ok: false, code: "replay.catalog.write_failed" };
        }
        return { ok: true, code: "replay.catalog.saved" };
    } catch (_caught) {
        return {
            ok: false,
            code: "replay.catalog.write_failed",
            diagnostic: string(_caught),
        };
    }
}

/// Creates the native file adapter; tests inject the same three operations.
function BladeReplayCatalogFileStorageCreate() {
    return {
        list: method({}, _BladeReplayCatalogFileList),
        read_text: method({}, _BladeReplayCatalogFileReadText),
        write_text: method({}, _BladeReplayCatalogFileWriteText),
    };
}

/// Checks the storage boundary before catalog operations touch it.
function BladeReplayCatalogStorageIsValid(_storage) {
    if (!is_struct(_storage)) return false;
    var _operations = ["list", "read_text", "write_text"];
    for (var _index = 0; _index < array_length(_operations); ++_index) {
        var _operation = _operations[_index];
        if (!variable_struct_exists(_storage, _operation)
            || !is_callable(variable_struct_get(_storage, _operation))) {
            return false;
        }
    }
    return true;
}

function _BladeReplayCatalogRequireStorage(_storage) {
    if (!BladeReplayCatalogStorageIsValid(_storage)) {
        throw("BladeReplayCatalog: storage adapter is incomplete");
    }
}

function _BladeReplayCatalogRequire(_catalog) {
    if (!is_struct(_catalog)
        || !variable_struct_exists(_catalog, "__blade_replay_catalog_version")
        || _catalog.__blade_replay_catalog_version != 1
        || !variable_struct_exists(_catalog, "storage")
        || !BladeReplayCatalogStorageIsValid(_catalog.storage)
        || !variable_struct_exists(_catalog, "entries")
        || !is_array(_catalog.entries)) {
        throw("BladeReplayCatalog: catalog is incomplete");
    }
}

/// Exposes a non-throwing validity check to front-end owners and tests.
function BladeReplayCatalogIsValid(_catalog) {
    try {
        _BladeReplayCatalogRequire(_catalog);
        return true;
    } catch (_caught) {
        return false;
    }
}

/// Creates an empty catalog whose storage can be refreshed on demand.
function BladeReplayCatalogCreate(_storage) {
    _BladeReplayCatalogRequireStorage(_storage);
    return {
        __blade_replay_catalog_version: 1,
        storage: _storage,
        entries: [],
        refresh_ok: false,
        refresh_code: "replay.catalog.not_loaded",
    };
}

/// Returns detached entry data so the UI cannot mutate catalog ownership.
function BladeReplayCatalogSnapshot(_catalog) {
    _BladeReplayCatalogRequire(_catalog);
    var _entries = [];
    for (var _index = 0; _index < array_length(_catalog.entries); ++_index) {
        var _source = _catalog.entries[_index];
        var _copy = {};
        var _fields = variable_struct_get_names(_source);
        for (var _field_index = 0;
            _field_index < array_length(_fields);
            ++_field_index) {
            variable_struct_set(
                _copy,
                _fields[_field_index],
                variable_struct_get(_source, _fields[_field_index])
            );
        }
        array_push(_entries, _copy);
    }
    return {
        entries: _entries,
        refresh_ok: _catalog.refresh_ok,
        refresh_code: _catalog.refresh_code,
    };
}

/// Sorts playable identities independently from arbitrary source filenames.
function _BladeReplayCatalogEntryKey(_entry) {
    if (_entry.state == BladeReplayCatalogEntryState.Playable) {
        return "0|" + _entry.replay_id;
    }
    return "1|" + _entry.state_token + "|" + _entry.file_path;
}

/// Compares catalog keys bytewise so ordering is deterministic across locales.
function _BladeReplayCatalogAsciiCompare(_left, _right) {
    var _shared = min(string_length(_left), string_length(_right));
    for (var _index = 1; _index <= _shared; ++_index) {
        var _left_byte = string_ord_at(_left, _index);
        var _right_byte = string_ord_at(_right, _index);
        if (_left_byte < _right_byte) return -1;
        if (_left_byte > _right_byte) return 1;
    }
    if (string_length(_left) < string_length(_right)) return -1;
    if (string_length(_left) > string_length(_right)) return 1;
    return 0;
}

function _BladeReplayCatalogSort(_entries) {
    for (var _index = 1; _index < array_length(_entries); ++_index) {
        var _value = _entries[_index];
        var _value_key = _BladeReplayCatalogEntryKey(_value);
        var _cursor = _index - 1;
        while (_cursor >= 0
            && _BladeReplayCatalogAsciiCompare(
                _BladeReplayCatalogEntryKey(_entries[_cursor]), _value_key
            ) > 0) {
            _entries[_cursor + 1] = _entries[_cursor];
            _cursor -= 1;
        }
        _entries[_cursor + 1] = _value;
    }
    return _entries;
}

/// Treats version and contract mismatches as unsupported, not corrupt.
function _BladeReplayCatalogParseState(_diagnostic) {
    var _text = string_lower(string(_diagnostic));
    var _unsupported_markers = [
        "unsupported",
        "schema version",
        "session format",
        "simulation contract",
        "random algorithm",
        "tick rate",
        "run mode",
    ];
    for (var _index = 0;
        _index < array_length(_unsupported_markers);
        ++_index) {
        if (string_pos(_unsupported_markers[_index], _text) > 0) {
            return BladeReplayCatalogEntryState.Unsupported;
        }
    }
    return BladeReplayCatalogEntryState.Corrupt;
}

/// Recognizes a numeric future header before strict parsing can reject it.
function _BladeReplayCatalogHeaderState(_text) {
    var _parts = string_split(_text, "|");
    if (array_length(_parts) < 3 || _parts[0] != "BRP1") {
        return undefined;
    }
    var _schema = _parts[1];
    var _schema_is_integer = string_length(_schema) > 0;
    for (var _index = 1;
        _index <= string_length(_schema) && _schema_is_integer;
        ++_index) {
        var _byte = string_ord_at(_schema, _index);
        _schema_is_integer = _byte >= 48 && _byte <= 57;
    }
    if (_schema_is_integer && _schema != string(BladeReplaySchemaVersion())) {
        return BladeReplayCatalogEntryState.Unsupported;
    }
    return undefined;
}

/// Reads and strictly parses one source path without changing the catalog.
function _BladeReplayCatalogOpenPath(_catalog, _path) {
    var _read = _catalog.storage.read_text(_path);
    if (!is_struct(_read)
        || !variable_struct_exists(_read, "ok")
        || _read.ok != true
        || !variable_struct_exists(_read, "text")
        || !is_string(_read.text)) {
        var _read_code = is_struct(_read)
            && variable_struct_exists(_read, "code")
            ? _read.code
            : "replay.catalog.unreadable";
        var _state = _read_code == "replay.catalog.missing"
            ? BladeReplayCatalogEntryState.Missing
            : BladeReplayCatalogEntryState.Unreadable;
        return {
            ok: false,
            state: _state,
            code: _read_code,
            entry: _BladeReplayCatalogInvalidEntry(
                _path,
                _state,
                is_struct(_read) && variable_struct_exists(_read, "diagnostic")
                    ? string(_read.diagnostic)
                    : _read_code
            ),
            recording: "",
            parsed: undefined,
        };
    }

    var _header_state = _BladeReplayCatalogHeaderState(_read.text);
    if (_header_state == BladeReplayCatalogEntryState.Unsupported) {
        return {
            ok: false,
            state: _header_state,
            code: "replay.catalog.unsupported",
            entry: _BladeReplayCatalogInvalidEntry(
                _path, _header_state, "replay schema version is unsupported"
            ),
            recording: "",
            parsed: undefined,
        };
    }

    try {
        var _parsed = BladeReplayRecordingParse(_read.text);
        return {
            ok: true,
            state: BladeReplayCatalogEntryState.Playable,
            code: "replay.catalog.playable",
            entry: _BladeReplayCatalogPlayableEntry(_path, _parsed),
            recording: _parsed.canonical,
            parsed: _parsed,
        };
    } catch (_caught) {
        var _diagnostic = string(_caught);
        var _parse_state = _BladeReplayCatalogParseState(_diagnostic);
        return {
            ok: false,
            state: _parse_state,
            code: _parse_state == BladeReplayCatalogEntryState.Unsupported
                ? "replay.catalog.unsupported"
                : "replay.catalog.corrupt",
            entry: _BladeReplayCatalogInvalidEntry(
                _path, _parse_state, _diagnostic
            ),
            recording: "",
            parsed: undefined,
        };
    }
}

/// Refreshes entries from disk while preserving every failure as a visible state.
function BladeReplayCatalogRefresh(_catalog) {
    _BladeReplayCatalogRequire(_catalog);
    var _listed = _catalog.storage.list();
    if (!is_struct(_listed)
        || !variable_struct_exists(_listed, "ok")
        || _listed.ok != true
        || !variable_struct_exists(_listed, "paths")
        || !is_array(_listed.paths)) {
        _catalog.entries = [];
        _catalog.refresh_ok = false;
        _catalog.refresh_code = "replay.catalog.list_failed";
        return {
            ok: false,
            code: _catalog.refresh_code,
            catalog: BladeReplayCatalogSnapshot(_catalog),
        };
    }

    var _entries = [];
    for (var _index = 0; _index < array_length(_listed.paths); ++_index) {
        var _path = _listed.paths[_index];
        if (!is_string(_path) || string_length(_path) == 0) continue;
        var _opened = _BladeReplayCatalogOpenPath(_catalog, _path);
        var _duplicate = false;
        if (_opened.ok) {
            for (var _entry_index = 0;
                _entry_index < array_length(_entries);
                ++_entry_index) {
                if (_entries[_entry_index].state
                    == BladeReplayCatalogEntryState.Playable
                    && _entries[_entry_index].replay_id
                        == _opened.entry.replay_id) {
                    _duplicate = true;
                    break;
                }
            }
        }
        if (!_duplicate) array_push(_entries, _opened.entry);
    }
    _catalog.entries = _BladeReplayCatalogSort(_entries);
    _catalog.refresh_ok = true;
    _catalog.refresh_code = "replay.catalog.refreshed";
    return {
        ok: true,
        code: _catalog.refresh_code,
        catalog: BladeReplayCatalogSnapshot(_catalog),
    };
}

/// Saves a canonical recording using an identity-derived path, never caller text.
function BladeReplayCatalogSave(_catalog, _recording_text) {
    _BladeReplayCatalogRequire(_catalog);
    var _parsed;
    try {
        _parsed = BladeReplayRecordingParse(_recording_text);
    } catch (_caught) {
        return {
            ok: false,
            state: _BladeReplayCatalogParseState(string(_caught)),
            code: "replay.catalog.invalid_save",
            entry: undefined,
        };
    }
    var _entry = _BladeReplayCatalogPlayableEntry("", _parsed);
    var _path = BladeReplayCatalogPathForId(_entry.replay_id);
    var _existing = _catalog.storage.read_text(_path);
    if (is_struct(_existing)
        && variable_struct_exists(_existing, "ok")
        && _existing.ok == true) {
        return {
            ok: true,
            state: BladeReplayCatalogEntryState.Playable,
            code: "replay.catalog.already_saved",
            entry: _BladeReplayCatalogPlayableEntry(_path, _parsed),
        };
    }
    var _written = _catalog.storage.write_text(_path, _parsed.canonical);
    if (!is_struct(_written)
        || !variable_struct_exists(_written, "ok")
        || _written.ok != true) {
        return {
            ok: false,
            state: BladeReplayCatalogEntryState.Unreadable,
            code: is_struct(_written)
                && variable_struct_exists(_written, "code")
                ? _written.code
                : "replay.catalog.write_failed",
            entry: _BladeReplayCatalogPlayableEntry(_path, _parsed),
        };
    }
    return {
        ok: true,
        state: BladeReplayCatalogEntryState.Playable,
        code: "replay.catalog.saved",
        entry: _BladeReplayCatalogPlayableEntry(_path, _parsed),
    };
}

/// Opens one current entry again so deletion or replacement cannot strand launch.
function BladeReplayCatalogOpen(_catalog, _entry_index) {
    _BladeReplayCatalogRequire(_catalog);
    if (_entry_index < 0 || _entry_index >= array_length(_catalog.entries)) {
        throw("BladeReplayCatalog: entry index is outside the catalog");
    }
    return _BladeReplayCatalogOpenPath(
        _catalog, _catalog.entries[_entry_index].file_path
    );
}

/// Validates and launches one entry through the existing deterministic playback owner.
function BladeReplayCatalogLaunch(
    _catalog,
    _entry_index,
    _content_id_predicate,
    _max_catch_up_ticks = 8,
    _gameplay_plane = undefined
) {
    var _opened = BladeReplayCatalogOpen(_catalog, _entry_index);
    if (!_opened.ok) return _opened;
    try {
        _opened.playback = BladeReplayPlaybackCreate(
            _opened.recording,
            _content_id_predicate,
            _max_catch_up_ticks,
            _gameplay_plane
        );
        _opened.code = "replay.catalog.playback_ready";
        return _opened;
    } catch (_caught) {
        var _diagnostic = string(_caught);
        var _state = _BladeReplayCatalogParseState(_diagnostic);
        _opened.ok = false;
        _opened.state = _state;
        _opened.code = _state == BladeReplayCatalogEntryState.Unsupported
            ? "replay.catalog.playback_unsupported"
            : "replay.catalog.playback_failed";
        _opened.entry = _BladeReplayCatalogInvalidEntry(
            _opened.entry.file_path, _state, _diagnostic
        );
        _opened.recording = "";
        _opened.parsed = undefined;
        return _opened;
    }
}
