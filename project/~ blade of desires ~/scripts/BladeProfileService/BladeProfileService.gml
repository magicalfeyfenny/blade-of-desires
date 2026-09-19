/// @description Isolated profile loading, strict validation, and result application.

enum BladeProfileLoadStatus {
    NotLoaded = 0,
    MissingDefaults = 1,
    Loaded = 2,
    Corrupt = 3,
    Future = 4,
    ReadFailed = 5
}

function _BladeProfileServiceFilenameIsSafe(_filename) {
    return is_string(_filename)
        && _filename != ""
        && string_pos("/", _filename) == 0
        && string_pos("\\", _filename) == 0
        && _filename != "."
        && _filename != "..";
}

function BladeProfileServiceCreate(_storage, _filename = undefined) {
    _BladeProfileStorageRequire(_storage);
    var _resolved_filename = _filename;
    if (is_undefined(_resolved_filename)) {
        _resolved_filename = BladeProfileFilename();
    }
    if (!_BladeProfileServiceFilenameIsSafe(_resolved_filename)) {
        throw("BladeProfileService: filename must be one relative basename");
    }
    return {
        storage: _storage,
        filename: _resolved_filename,
        current: BladeProfileCreateDefault(),
        load_status: BladeProfileLoadStatus.NotLoaded,
        write_allowed: true,
    };
}

function _BladeProfileServiceRequire(_service) {
    if (!is_struct(_service)
        || !variable_struct_exists(_service, "storage")
        || !BladeProfileStorageIsValid(_service.storage)
        || !variable_struct_exists(_service, "filename")
        || !_BladeProfileServiceFilenameIsSafe(_service.filename)
        || !variable_struct_exists(_service, "current")
        || !BladeProfileIsCanonical(_service.current)) {
        throw("BladeProfileService: service is incomplete");
    }
}

function BladeProfileServiceSnapshot(_service) {
    _BladeProfileServiceRequire(_service);
    return BladeProfileClone(_service.current);
}

function _BladeProfileServiceLoadResult(_service, _status, _code, _ok) {
    return {
        ok: _ok,
        status: _status,
        code: _code,
        profile: BladeProfileServiceSnapshot(_service),
    };
}

function _BladeProfileServiceReadParsed(_service) {
    var _read = _service.storage.read_text(_service.filename);
    if (!is_struct(_read)
        || !variable_struct_exists(_read, "ok")
        || _read.ok != true
        || !variable_struct_exists(_read, "text")
        || !is_string(_read.text)) {
        return { ok: false, parsed: undefined };
    }
    return {
        ok: true,
        parsed: BladeProfileSerializerParse(_read.text),
    };
}

/// Loads a missing profile as defaults but preserves invalid bytes and fails closed.
function BladeProfileServiceLoad(_service) {
    _BladeProfileServiceRequire(_service);
    _service.current = BladeProfileCreateDefault();
    if (!_service.storage.exists(_service.filename)) {
        _service.load_status = BladeProfileLoadStatus.MissingDefaults;
        _service.write_allowed = true;
        return _BladeProfileServiceLoadResult(
            _service,
            _service.load_status,
            "profile.load.missing",
            true
        );
    }
    var _read = _BladeProfileServiceReadParsed(_service);
    if (!_read.ok) {
        _service.load_status = BladeProfileLoadStatus.ReadFailed;
        _service.write_allowed = false;
        return _BladeProfileServiceLoadResult(
            _service,
            _service.load_status,
            "profile.load.read_failed",
            false
        );
    }
    if (_read.parsed.kind == BladeProfileParseKind.Current) {
        _service.current = BladeProfileClone(_read.parsed.profile);
        _service.load_status = BladeProfileLoadStatus.Loaded;
        _service.write_allowed = true;
        return _BladeProfileServiceLoadResult(
            _service,
            _service.load_status,
            "profile.load.current",
            true
        );
    }
    _service.load_status = _read.parsed.kind == BladeProfileParseKind.Future
        ? BladeProfileLoadStatus.Future
        : BladeProfileLoadStatus.Corrupt;
    _service.write_allowed = false;
    return _BladeProfileServiceLoadResult(
        _service,
        _service.load_status,
        _read.parsed.code,
        false
    );
}

/// Strictly saves one canonical candidate without changing current on failure.
function BladeProfileServiceSave(_service, _candidate) {
    _BladeProfileServiceRequire(_service);
    if (!_service.write_allowed) {
        return {
            ok: false,
            code: "profile.save.blocked_by_load",
            recovery_path: "",
            profile: BladeProfileServiceSnapshot(_service),
        };
    }
    if (!BladeProfileIsCanonical(_candidate)) {
        return {
            ok: false,
            code: "profile.save.invalid_candidate",
            recovery_path: "",
            profile: BladeProfileServiceSnapshot(_service),
        };
    }
    var _text = BladeProfileSerializerStringify(_candidate);
    var _transaction = BladeProfileStorageTransactionalReplace(
        _service.storage,
        _service.filename,
        _text
    );
    if (_transaction.ok) {
        _service.current = BladeProfileClone(_candidate);
        _service.load_status = BladeProfileLoadStatus.Loaded;
    }
    return {
        ok: _transaction.ok,
        code: _transaction.code,
        recovery_path: _transaction.recovery_path,
        profile: BladeProfileServiceSnapshot(_service),
    };
}

/// Applies a live authoritative result and persists it as one transaction.
function BladeProfileServiceApplyRunResult(
    _service, _result, _source = "live"
) {
    _BladeProfileServiceRequire(_service);
    if (!_service.write_allowed) {
        return {
            ok: false,
            code: "profile.apply.blocked_by_load",
            profile: BladeProfileServiceSnapshot(_service),
        };
    }
    var _applied = BladeProfileApplyRunResult(
        BladeProfileServiceSnapshot(_service), _result, _source
    );
    if (!_applied.ok) return _applied;
    var _saved = BladeProfileServiceSave(_service, _applied.profile);
    return {
        ok: _saved.ok,
        code: _saved.ok ? _applied.code : _saved.code,
        recovery_path: _saved.recovery_path,
        profile: _saved.profile,
        record: _applied.record,
    };
}

function _BladeProfileServiceGrantFlag(_service, _kind, _flag_id) {
    _BladeProfileServiceRequire(_service);
    if (!_service.write_allowed) {
        return {
            ok: false,
            code: "profile.flag.blocked_by_load",
            changed: false,
            profile: BladeProfileServiceSnapshot(_service),
        };
    }
    var _candidate = BladeProfileServiceSnapshot(_service);
    var _changed = BladeProfileGrantFlag(_candidate, _kind, _flag_id);
    if (!_changed) {
        return {
            ok: true,
            code: "profile.flag.already_granted",
            changed: false,
            profile: _candidate,
        };
    }
    var _saved = BladeProfileServiceSave(_service, _candidate);
    return {
        ok: _saved.ok,
        code: _saved.code,
        changed: _saved.ok,
        profile: _saved.profile,
    };
}

function BladeProfileServiceGrantUnlock(_service, _flag_id) {
    return _BladeProfileServiceGrantFlag(
        _service, BladeProfileFlagKind.Unlock, _flag_id
    );
}

function BladeProfileServiceGrantAchievement(_service, _flag_id) {
    return _BladeProfileServiceGrantFlag(
        _service, BladeProfileFlagKind.Achievement, _flag_id
    );
}

function BladeProfileServiceGrantCgFlag(_service, _flag_id) {
    return _BladeProfileServiceGrantFlag(
        _service, BladeProfileFlagKind.Cg, _flag_id
    );
}
