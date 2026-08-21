/// @description Injected text storage and recoverable config replacement transactions.

/// Checks one relative path through GameMaker's sandboxed file lookup.
function _BladeConfigFileStorageExists(_path) {
    return file_exists(_path);
}

/// Reads one complete compact-text payload and closes its handle on every path.
function _BladeConfigFileStorageReadText(_path) {
    var _result = { ok: false, text: "" };
    var _file = -1;
    try {
        _file = file_text_open_read(_path);
        if (_file < 0) {
            return _result;
        }

        var _text = "";
        var _first_line = true;
        while (!file_text_eof(_file)) {
            if (!_first_line) {
                _text += "\n";
            }
            _text += file_text_read_string(_file);
            file_text_readln(_file);
            _first_line = false;
        }

        var _close_result = file_text_close(_file);
        _file = -1;
        // The runner may report successful closure with a non-Boolean value.
        if (is_bool(_close_result) && !_close_result) {
            return _result;
        }
        _result.ok = true;
        _result.text = _text;
    } catch (_exception) {
        if (_file >= 0) {
            try {
                file_text_close(_file);
            } catch (_close_exception) {
                // The failed read already reports false; close failure adds no safe recovery.
            }
        }
    }
    return _result;
}

/// Writes text; exact rereading confirms persistence before a transaction promotes it.
function _BladeConfigFileStorageWriteText(_path, _text) {
    var _file = -1;
    try {
        _file = file_text_open_write(_path);
        if (_file < 0) {
            return false;
        }
        file_text_write_string(_file, _text);
        var _close_result = file_text_close(_file);
        _file = -1;
        // The runner may report successful closure with a non-Boolean value.
        if (is_bool(_close_result) && !_close_result) {
            return false;
        }
        return true;
    } catch (_exception) {
        if (_file >= 0) {
            try {
                file_text_close(_file);
            } catch (_close_exception) {
                // The failed write remains false even when its handle cannot close cleanly.
            }
        }
        return false;
    }
}

/// Copies exact source bytes only to an absent target path.
function _BladeConfigFileStorageCopy(_source, _target) {
    try {
        if (!file_exists(_source) || file_exists(_target)) {
            return false;
        }
        var _copy_result = file_copy(_source, _target);
        // The runner may report a successful copy with a non-Boolean value.
        if (is_bool(_copy_result) && !_copy_result) {
            return false;
        }
        return file_exists(_target);
    } catch (_exception) {
        return false;
    }
}

/// Moves a file only to an absent target so platform overwrite behavior is irrelevant.
function _BladeConfigFileStorageMove(_source, _target) {
    try {
        if (!file_exists(_source) || file_exists(_target)) {
            return false;
        }
        return file_rename(_source, _target);
    } catch (_exception) {
        return false;
    }
}

/// Removes one exact file path and treats an already absent path as successful cleanup.
function _BladeConfigFileStorageRemove(_path) {
    try {
        if (!file_exists(_path)) {
            return true;
        }
        return file_delete(_path);
    } catch (_exception) {
        return false;
    }
}

/// @func BladeConfigFileStorageCreate()
/// Creates the production adapter whose relative paths resolve to per-user storage.
function BladeConfigFileStorageCreate() {
    return {
        exists: method({}, _BladeConfigFileStorageExists),
        read_text: method({}, _BladeConfigFileStorageReadText),
        write_text: method({}, _BladeConfigFileStorageWriteText),
        copy: method({}, _BladeConfigFileStorageCopy),
        move: method({}, _BladeConfigFileStorageMove),
        remove: method({}, _BladeConfigFileStorageRemove),
    };
}

/// @func BladeConfigStorageIsValid(storage)
/// Checks that an injected adapter supplies every callable storage operation.
function BladeConfigStorageIsValid(_storage) {
    if (!is_struct(_storage)) {
        return false;
    }
    var _operations = ["exists", "read_text", "write_text", "copy", "move", "remove"];
    for (var _index = 0; _index < array_length(_operations); ++_index) {
        var _operation = _operations[_index];
        if (!variable_struct_exists(_storage, _operation)
            || !is_callable(variable_struct_get(_storage, _operation))) {
            return false;
        }
    }
    return true;
}

/// Rejects an incomplete adapter before any storage operation can mutate files.
function _BladeConfigStorageRequire(_storage) {
    if (!BladeConfigStorageIsValid(_storage)) {
        throw("BladeConfigStorage: adapter is incomplete");
    }
}

/// @func BladeConfigStorageTemporaryPath(path)
/// Returns the exact sibling used for a fully written replacement candidate.
function BladeConfigStorageTemporaryPath(_path) {
    return _path + ".tmp";
}

/// @func BladeConfigStoragePreviousPath(path)
/// Returns the exact sibling retaining the previous valid live payload.
function BladeConfigStoragePreviousPath(_path) {
    return _path + ".previous";
}

/// Creates a transaction result with a stable diagnostic and optional recovery path.
function _BladeConfigStorageResult(_ok, _code, _recovery_path = "") {
    return {
        ok: _ok,
        code: _code,
        recovery_path: _recovery_path,
    };
}

/// Removes one stale transaction file before its exact name is reused.
function _BladeConfigStorageRemoveStale(_storage, _path) {
    if (!_storage.exists(_path)) {
        return true;
    }
    return _storage.remove(_path);
}

/// Reads a just-written temporary file and requires its bytes to match exactly.
function _BladeConfigStorageTemporaryMatches(_storage, _path, _expected_text) {
    var _read = _storage.read_text(_path);
    return is_struct(_read)
        && variable_struct_exists(_read, "ok")
        && _read.ok == true
        && variable_struct_exists(_read, "text")
        && is_string(_read.text)
        && _read.text == _expected_text;
}

/// @func BladeConfigStorageTransactionalReplace(storage, path, text)
/// Publishes verified text while retaining or restoring the prior live payload on failure.
function BladeConfigStorageTransactionalReplace(_storage, _path, _text) {
    _BladeConfigStorageRequire(_storage);
    if (!is_string(_path) || _path == "" || !is_string(_text)) {
        return _BladeConfigStorageResult(false, "config.storage.invalid_argument");
    }

    var _temporary_path = BladeConfigStorageTemporaryPath(_path);
    var _previous_path = BladeConfigStoragePreviousPath(_path);

    // Resolve a prior interrupted replacement before accepting another write.
    if (!_storage.exists(_path) && _storage.exists(_previous_path)) {
        if (!_storage.move(_previous_path, _path)) {
            return _BladeConfigStorageResult(
                false,
                "config.storage.recovery_blocked",
                _previous_path
            );
        }
    }
    if (!_BladeConfigStorageRemoveStale(_storage, _temporary_path)) {
        return _BladeConfigStorageResult(false, "config.storage.temp_cleanup_failed");
    }

    if (!_storage.write_text(_temporary_path, _text)) {
        _storage.remove(_temporary_path);
        return _BladeConfigStorageResult(false, "config.storage.temp_write_failed");
    }
    if (!_BladeConfigStorageTemporaryMatches(_storage, _temporary_path, _text)) {
        _storage.remove(_temporary_path);
        return _BladeConfigStorageResult(false, "config.storage.temp_verify_failed");
    }

    var _archived_live = false;
    if (_storage.exists(_path)) {
        if (!_BladeConfigStorageRemoveStale(_storage, _previous_path)) {
            _storage.remove(_temporary_path);
            return _BladeConfigStorageResult(
                false,
                "config.storage.previous_cleanup_failed",
                _path
            );
        }
        if (!_storage.move(_path, _previous_path)) {
            _storage.remove(_temporary_path);
            return _BladeConfigStorageResult(
                false,
                "config.storage.archive_failed",
                _path
            );
        }
        _archived_live = true;
    }

    if (_storage.move(_temporary_path, _path)) {
        return _BladeConfigStorageResult(
            true,
            "config.storage.replaced",
            _archived_live ? _previous_path : ""
        );
    }

    _storage.remove(_temporary_path);
    if (_archived_live) {
        if (_storage.move(_previous_path, _path)) {
            return _BladeConfigStorageResult(
                false,
                "config.storage.replace_failed_rolled_back",
                _path
            );
        }
        return _BladeConfigStorageResult(
            false,
            "config.storage.rollback_failed",
            _previous_path
        );
    }
    return _BladeConfigStorageResult(false, "config.storage.replace_failed");
}

/// @func BladeConfigStorageTransactionalCopy(storage, source_path, target_path)
/// Publishes an exact source-file copy while retaining the source and recoverable target.
function BladeConfigStorageTransactionalCopy(_storage, _source_path, _target_path) {
    _BladeConfigStorageRequire(_storage);
    if (!is_string(_source_path)
        || _source_path == ""
        || !is_string(_target_path)
        || _target_path == ""
        || _source_path == _target_path) {
        return _BladeConfigStorageResult(false, "config.storage.invalid_argument");
    }

    var _temporary_path = BladeConfigStorageTemporaryPath(_target_path);
    var _previous_path = BladeConfigStoragePreviousPath(_target_path);
    if (_source_path == _temporary_path
        || _source_path == _previous_path
        || !_storage.exists(_source_path)) {
        return _BladeConfigStorageResult(false, "config.storage.invalid_argument");
    }

    // Recover an interrupted older target before preparing the new exact copy.
    if (!_storage.exists(_target_path) && _storage.exists(_previous_path)) {
        if (!_storage.move(_previous_path, _target_path)) {
            return _BladeConfigStorageResult(
                false,
                "config.storage.copy_recovery_blocked",
                _previous_path
            );
        }
    }
    if (!_BladeConfigStorageRemoveStale(_storage, _temporary_path)) {
        return _BladeConfigStorageResult(false, "config.storage.copy_temp_cleanup_failed");
    }

    if (!_storage.copy(_source_path, _temporary_path)
        || !_storage.exists(_temporary_path)) {
        _storage.remove(_temporary_path);
        return _BladeConfigStorageResult(false, "config.storage.copy_failed");
    }

    var _archived_target = false;
    if (_storage.exists(_target_path)) {
        if (!_BladeConfigStorageRemoveStale(_storage, _previous_path)) {
            _storage.remove(_temporary_path);
            return _BladeConfigStorageResult(
                false,
                "config.storage.copy_previous_cleanup_failed",
                _target_path
            );
        }
        if (!_storage.move(_target_path, _previous_path)) {
            _storage.remove(_temporary_path);
            return _BladeConfigStorageResult(
                false,
                "config.storage.copy_archive_failed",
                _target_path
            );
        }
        _archived_target = true;
    }

    if (_storage.move(_temporary_path, _target_path)) {
        return _BladeConfigStorageResult(
            true,
            "config.storage.copied",
            _archived_target ? _previous_path : ""
        );
    }

    _storage.remove(_temporary_path);
    if (_archived_target) {
        if (_storage.move(_previous_path, _target_path)) {
            return _BladeConfigStorageResult(
                false,
                "config.storage.copy_promote_failed_rolled_back",
                _target_path
            );
        }
        return _BladeConfigStorageResult(
            false,
            "config.storage.copy_rollback_failed",
            _previous_path
        );
    }
    return _BladeConfigStorageResult(false, "config.storage.copy_promote_failed");
}
