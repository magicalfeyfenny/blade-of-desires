/// @description Injected text storage and recoverable profile replacement transactions.

/// Checks one relative path through GameMaker's per-user save-area lookup.
function _BladeProfileFileStorageExists(_path) {
    return file_exists(_path);
}

/// Reads one complete text payload and closes its handle on every path.
function _BladeProfileFileStorageReadText(_path) {
    var _result = { ok: false, text: "" };
    var _file = -1;
    try {
        _file = file_text_open_read(_path);
        if (_file < 0) return _result;
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
        if (is_bool(_close_result) && !_close_result) return _result;
        _result.ok = true;
        _result.text = _text;
    } catch (_exception) {
        if (_file >= 0) {
            try {
                file_text_close(_file);
            } catch (_close_exception) {
                // The original failed read remains the authoritative diagnostic.
            }
        }
    }
    return _result;
}

/// Writes one candidate payload; transaction promotion verifies it by rereading.
function _BladeProfileFileStorageWriteText(_path, _text) {
    var _file = -1;
    try {
        _file = file_text_open_write(_path);
        if (_file < 0) return false;
        file_text_write_string(_file, _text);
        var _close_result = file_text_close(_file);
        _file = -1;
        if (is_bool(_close_result) && !_close_result) return false;
        return true;
    } catch (_exception) {
        if (_file >= 0) {
            try {
                file_text_close(_file);
            } catch (_close_exception) {
                // The failed write remains false even when its handle cannot close.
            }
        }
        return false;
    }
}

/// Moves only to an absent target so overwrite behavior is explicit and recoverable.
function _BladeProfileFileStorageMove(_source, _target) {
    try {
        if (!file_exists(_source) || file_exists(_target)) return false;
        return file_rename(_source, _target);
    } catch (_exception) {
        return false;
    }
}

/// Removes one exact file path and accepts an already absent path.
function _BladeProfileFileStorageRemove(_path) {
    try {
        if (!file_exists(_path)) return true;
        return file_delete(_path);
    } catch (_exception) {
        return false;
    }
}

/// Creates the production adapter whose relative paths resolve to per-user storage.
function BladeProfileFileStorageCreate() {
    return {
        exists: method({}, _BladeProfileFileStorageExists),
        read_text: method({}, _BladeProfileFileStorageReadText),
        write_text: method({}, _BladeProfileFileStorageWriteText),
        move: method({}, _BladeProfileFileStorageMove),
        remove: method({}, _BladeProfileFileStorageRemove),
    };
}

function BladeProfileStorageIsValid(_storage) {
    if (!is_struct(_storage)) return false;
    var _operations = ["exists", "read_text", "write_text", "move", "remove"];
    for (var _index = 0; _index < array_length(_operations); ++_index) {
        var _operation = _operations[_index];
        if (!variable_struct_exists(_storage, _operation)
            || !is_callable(variable_struct_get(_storage, _operation))) {
            return false;
        }
    }
    return true;
}

function _BladeProfileStorageRequire(_storage) {
    if (!BladeProfileStorageIsValid(_storage)) {
        throw("BladeProfileStorage: adapter is incomplete");
    }
}

function BladeProfileStorageTemporaryPath(_path) {
    return _path + ".tmp";
}

function BladeProfileStoragePreviousPath(_path) {
    return _path + ".previous";
}

function _BladeProfileStorageResult(_ok, _code, _recovery_path = "") {
    return { ok: _ok, code: _code, recovery_path: _recovery_path };
}

function _BladeProfileStorageRemoveStale(_storage, _path) {
    if (!_storage.exists(_path)) return true;
    return _storage.remove(_path);
}

function _BladeProfileStorageTemporaryMatches(_storage, _path, _expected_text) {
    var _read = _storage.read_text(_path);
    return is_struct(_read)
        && variable_struct_exists(_read, "ok")
        && _read.ok == true
        && variable_struct_exists(_read, "text")
        && is_string(_read.text)
        && _read.text == _expected_text;
}

/// Publishes verified text while retaining or restoring the prior live payload.
function BladeProfileStorageTransactionalReplace(_storage, _path, _text) {
    _BladeProfileStorageRequire(_storage);
    if (!is_string(_path) || _path == "" || !is_string(_text)) {
        return _BladeProfileStorageResult(false, "profile.storage.invalid_argument");
    }
    var _temporary_path = BladeProfileStorageTemporaryPath(_path);
    var _previous_path = BladeProfileStoragePreviousPath(_path);

    // Recover an interrupted prior replacement before accepting another write.
    if (!_storage.exists(_path) && _storage.exists(_previous_path)) {
        if (!_storage.move(_previous_path, _path)) {
            return _BladeProfileStorageResult(
                false, "profile.storage.recovery_blocked", _previous_path
            );
        }
    }
    if (!_BladeProfileStorageRemoveStale(_storage, _temporary_path)) {
        return _BladeProfileStorageResult(false, "profile.storage.temp_cleanup_failed");
    }
    if (!_storage.write_text(_temporary_path, _text)) {
        _storage.remove(_temporary_path);
        return _BladeProfileStorageResult(false, "profile.storage.temp_write_failed");
    }
    if (!_BladeProfileStorageTemporaryMatches(_storage, _temporary_path, _text)) {
        _storage.remove(_temporary_path);
        return _BladeProfileStorageResult(false, "profile.storage.temp_verify_failed");
    }

    var _archived_live = false;
    if (_storage.exists(_path)) {
        if (!_BladeProfileStorageRemoveStale(_storage, _previous_path)) {
            _storage.remove(_temporary_path);
            return _BladeProfileStorageResult(
                false, "profile.storage.previous_cleanup_failed", _path
            );
        }
        if (!_storage.move(_path, _previous_path)) {
            _storage.remove(_temporary_path);
            return _BladeProfileStorageResult(
                false, "profile.storage.archive_failed", _path
            );
        }
        _archived_live = true;
    }
    if (_storage.move(_temporary_path, _path)) {
        return _BladeProfileStorageResult(
            true,
            "profile.storage.replaced",
            _archived_live ? _previous_path : ""
        );
    }
    _storage.remove(_temporary_path);
    if (_archived_live) {
        if (_storage.move(_previous_path, _path)) {
            return _BladeProfileStorageResult(
                false, "profile.storage.replace_failed_rolled_back", _path
            );
        }
        return _BladeProfileStorageResult(
            false, "profile.storage.rollback_failed", _previous_path
        );
    }
    return _BladeProfileStorageResult(false, "profile.storage.replace_failed");
}
