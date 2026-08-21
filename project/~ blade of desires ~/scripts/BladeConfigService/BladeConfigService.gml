/// @description Isolated config loading, recovery, backup, and transactional saving.

// Reports how a load established the service's current detached config snapshot.
enum BladeConfigLoadStatus {
    MissingDefaults = 1,
    Loaded = 2,
    Normalized = 3,
    CorruptDefaults = 4,
    FutureDefaults = 5,
    RecoveredPrevious = 6,
    RecoveredTemporary = 7,
    ReadFailedDefaults = 8
}
/// Returns whether a filename is a single relative save-area basename.
function _BladeConfigServiceFilenameIsSafe(_filename) {
    return is_string(_filename)
        && _filename != ""
        && string_pos("/", _filename) == 0
        && string_pos("\\", _filename) == 0
        && _filename != "."
        && _filename != "..";
}

/// @func BladeConfigServiceCreate(storage, filename)
/// Creates an isolated config owner without reading or mutating storage.
function BladeConfigServiceCreate(_storage, _filename = undefined) {
    _BladeConfigStorageRequire(_storage);
    var _resolved_filename = _filename;
    if (is_undefined(_resolved_filename)) {
        _resolved_filename = BladeConfigFilename();
    }
    if (!_BladeConfigServiceFilenameIsSafe(_resolved_filename)) {
        throw("BladeConfigService: filename must be one relative basename");
    }
    return {
        storage: _storage,
        filename: _resolved_filename,
        current: BladeConfigCreateDefault(),
    };
}

/// Validates a service before an operation can read or publish its state.
function _BladeConfigServiceRequire(_service) {
    if (!is_struct(_service)
        || !variable_struct_exists(_service, "storage")
        || !BladeConfigStorageIsValid(_service.storage)
        || !variable_struct_exists(_service, "filename")
        || !_BladeConfigServiceFilenameIsSafe(_service.filename)
        || !variable_struct_exists(_service, "current")) {
        throw("BladeConfigService: service is incomplete");
    }
}

/// @func BladeConfigServiceSnapshot(service)
/// Returns a detached canonical copy of the service's current config.
function BladeConfigServiceSnapshot(_service) {
    _BladeConfigServiceRequire(_service);
    return BladeConfigNormalize(_service.current);
}

/// Returns the stable exact backup path for malformed JSON bytes.
function _BladeConfigServiceCorruptBackupPath(_service) {
    return _service.filename + ".corrupt.backup";
}

/// Returns the stable exact backup path for one unsupported future schema version.
function _BladeConfigServiceFutureBackupPath(_service, _version) {
    return _service.filename + ".future-v" + string(_version) + ".backup";
}

/// Creates a load result containing a detached snapshot and recovery evidence.
function _BladeConfigServiceLoadResult(
    _service,
    _status,
    _code,
    _backup_path = "",
    _backup_ok = false,
    _rewrite_ok = false,
    _recovery_published = false
) {
    return {
        status: _status,
        code: _code,
        config: BladeConfigServiceSnapshot(_service),
        backup_path: _backup_path,
        backup_ok: _backup_ok,
        rewrite_ok: _rewrite_ok,
        recovery_published: _recovery_published,
    };
}

/// Reads and classifies one exact storage path without changing service state.
function _BladeConfigServiceReadParsed(_service, _path) {
    var _read = _service.storage.read_text(_path);
    if (!is_struct(_read)
        || !variable_struct_exists(_read, "ok")
        || _read.ok != true
        || !variable_struct_exists(_read, "text")
        || !is_string(_read.text)) {
        return { ok: false, parsed: undefined };
    }
    return {
        ok: true,
        parsed: BladeConfigSerializerParse(_read.text),
    };
}

/// Copies rejected live bytes without reconstructing them through text APIs.
function _BladeConfigServiceBackupLive(_service, _backup_path) {
    return BladeConfigStorageTransactionalCopy(
        _service.storage,
        _service.filename,
        _backup_path
    );
}

/// Loads a valid recovery sibling and publishes it when the live target is absent.
function _BladeConfigServiceRecoverAbsentLive(_service, _recovery_path, _status) {
    if (!_service.storage.exists(_recovery_path)) {
        return undefined;
    }
    var _recovery = _BladeConfigServiceReadParsed(_service, _recovery_path);
    if (!_recovery.ok
        || _recovery.parsed.kind != BladeConfigParseKind.Current) {
        return undefined;
    }

    _service.current = _recovery.parsed.config;
    var _published = _service.storage.move(_recovery_path, _service.filename);
    return _BladeConfigServiceLoadResult(
        _service,
        _status,
        _status == BladeConfigLoadStatus.RecoveredPrevious
            ? "config.load.recovered_previous"
            : "config.load.recovered_temporary",
        "",
        false,
        false,
        _published
    );
}

/// Loads a prior valid payload after corrupt live bytes have been preserved.
function _BladeConfigServiceRecoverCorruptLive(
    _service,
    _previous_path,
    _backup_path,
    _backup_ok
) {
    if (!_backup_ok || !_service.storage.exists(_previous_path)) {
        return undefined;
    }
    var _previous = _BladeConfigServiceReadParsed(_service, _previous_path);
    if (!_previous.ok
        || _previous.parsed.kind != BladeConfigParseKind.Current) {
        return undefined;
    }

    _service.current = _previous.parsed.config;
    var _published = false;
    if (_service.storage.remove(_service.filename)) {
        _published = _service.storage.move(_previous_path, _service.filename);
    }
    return _BladeConfigServiceLoadResult(
        _service,
        BladeConfigLoadStatus.RecoveredPrevious,
        "config.load.recovered_previous_after_corruption",
        _backup_path,
        _backup_ok,
        false,
        _published
    );
}

/// @func BladeConfigServiceLoad(service)
/// Loads current config, normalizes recognized fields, and recovers without run-state effects.
function BladeConfigServiceLoad(_service) {
    _BladeConfigServiceRequire(_service);
    _service.current = BladeConfigCreateDefault();

    var _previous_path = BladeConfigStoragePreviousPath(_service.filename);
    var _temporary_path = BladeConfigStorageTemporaryPath(_service.filename);
    if (!_service.storage.exists(_service.filename)) {
        var _previous_result = _BladeConfigServiceRecoverAbsentLive(
            _service,
            _previous_path,
            BladeConfigLoadStatus.RecoveredPrevious
        );
        if (!is_undefined(_previous_result)) {
            return _previous_result;
        }
        var _temporary_result = _BladeConfigServiceRecoverAbsentLive(
            _service,
            _temporary_path,
            BladeConfigLoadStatus.RecoveredTemporary
        );
        if (!is_undefined(_temporary_result)) {
            return _temporary_result;
        }
        return _BladeConfigServiceLoadResult(
            _service,
            BladeConfigLoadStatus.MissingDefaults,
            "config.load.missing"
        );
    }

    var _live = _BladeConfigServiceReadParsed(_service, _service.filename);
    if (!_live.ok) {
        return _BladeConfigServiceLoadResult(
            _service,
            BladeConfigLoadStatus.ReadFailedDefaults,
            "config.load.read_failed"
        );
    }

    if (_live.parsed.kind == BladeConfigParseKind.Future) {
        var _future_path = _BladeConfigServiceFutureBackupPath(
            _service,
            _live.parsed.source_version
        );
        var _future_backup = _BladeConfigServiceBackupLive(
            _service,
            _future_path
        );
        return _BladeConfigServiceLoadResult(
            _service,
            BladeConfigLoadStatus.FutureDefaults,
            _future_backup.ok
                ? "config.load.future_backed_up"
                : "config.load.future_backup_failed",
            _future_path,
            _future_backup.ok
        );
    }

    if (_live.parsed.kind == BladeConfigParseKind.Corrupt) {
        var _corrupt_path = _BladeConfigServiceCorruptBackupPath(_service);
        var _corrupt_backup = _BladeConfigServiceBackupLive(
            _service,
            _corrupt_path
        );
        var _recovered = _BladeConfigServiceRecoverCorruptLive(
            _service,
            _previous_path,
            _corrupt_path,
            _corrupt_backup.ok
        );
        if (!is_undefined(_recovered)) {
            return _recovered;
        }
        return _BladeConfigServiceLoadResult(
            _service,
            BladeConfigLoadStatus.CorruptDefaults,
            _corrupt_backup.ok
                ? "config.load.corrupt_backed_up"
                : "config.load.corrupt_backup_failed",
            _corrupt_path,
            _corrupt_backup.ok
        );
    }

    _service.current = _live.parsed.config;
    if (_live.parsed.was_normalized) {
        var _normalized_text = BladeConfigSerializerStringify(_service.current);
        var _rewrite = BladeConfigStorageTransactionalReplace(
            _service.storage,
            _service.filename,
            _normalized_text
        );
        return _BladeConfigServiceLoadResult(
            _service,
            BladeConfigLoadStatus.Normalized,
            _rewrite.ok
                ? "config.load.normalized_rewritten"
                : "config.load.normalized_rewrite_failed",
            "",
            false,
            _rewrite.ok
        );
    }

    return _BladeConfigServiceLoadResult(
        _service,
        BladeConfigLoadStatus.Loaded,
        "config.load.current"
    );
}

/// @func BladeConfigServiceSave(service, candidate)
/// Normalizes and transactionally publishes a candidate without changing current on failure.
function BladeConfigServiceSave(_service, _candidate) {
    _BladeConfigServiceRequire(_service);
    if (!_BladeConfigIdentityIsSupported(_candidate)) {
        return {
            ok: false,
            code: "config.save.unsupported_candidate",
            recovery_path: "",
            config: BladeConfigServiceSnapshot(_service),
        };
    }
    var _normalized = BladeConfigNormalize(_candidate);
    var _text = BladeConfigSerializerStringify(_normalized);
    var _transaction = BladeConfigStorageTransactionalReplace(
        _service.storage,
        _service.filename,
        _text
    );
    if (_transaction.ok) {
        _service.current = _normalized;
    }
    return {
        ok: _transaction.ok,
        code: _transaction.code,
        recovery_path: _transaction.recovery_path,
        config: BladeConfigServiceSnapshot(_service),
    };
}
