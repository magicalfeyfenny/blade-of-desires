/// @description Isolated characterization for version 1 config persistence.

/// Returns whether an integer appears in a test adapter's configured failure calls.
function _BladeConfigTestArrayContains(_values, _expected) {
    for (var _index = 0; _index < array_length(_values); ++_index) {
        if (_values[_index] == _expected) {
            return true;
        }
    }
    return false;
}

/// Checks whether the in-memory adapter contains one exact path.
function _BladeConfigTestMemoryExists(_path) {
    return variable_struct_exists(self.files, _path);
}

/// Reads one exact in-memory text value without filesystem fallback behavior.
function _BladeConfigTestMemoryRead(_path) {
    if (!variable_struct_exists(self.files, _path)) {
        return { ok: false, text: "" };
    }
    return { ok: true, text: variable_struct_get(self.files, _path) };
}

/// Writes text in memory while supporting one precisely injected write failure.
function _BladeConfigTestMemoryWrite(_path, _text) {
    self.write_calls += 1;
    if (self.fail_write_call == self.write_calls) {
        return false;
    }
    var _stored_text = self.mismatch_next_write ? _text + "!" : _text;
    self.mismatch_next_write = false;
    variable_struct_set(self.files, _path, _stored_text);
    return true;
}

/// Copies one exact in-memory value while supporting one injected copy failure.
function _BladeConfigTestMemoryCopy(_source, _target) {
    self.copy_calls += 1;
    if (self.fail_copy_call == self.copy_calls) {
        return false;
    }
    if (!variable_struct_exists(self.files, _source)
        || variable_struct_exists(self.files, _target)) {
        return false;
    }
    variable_struct_set(
        self.files,
        _target,
        variable_struct_get(self.files, _source)
    );
    return true;
}

/// Moves one in-memory value while supporting failures at selected move calls.
function _BladeConfigTestMemoryMove(_source, _target) {
    self.move_calls += 1;
    if (_BladeConfigTestArrayContains(self.fail_move_calls, self.move_calls)) {
        return false;
    }
    if (!variable_struct_exists(self.files, _source)
        || variable_struct_exists(self.files, _target)) {
        return false;
    }
    variable_struct_set(
        self.files,
        _target,
        variable_struct_get(self.files, _source)
    );
    variable_struct_remove(self.files, _source);
    return true;
}

/// Removes only one exact in-memory path and supports a selected cleanup failure.
function _BladeConfigTestMemoryRemove(_path) {
    self.remove_calls += 1;
    if (self.fail_remove_call == self.remove_calls) {
        return false;
    }
    if (variable_struct_exists(self.files, _path)) {
        variable_struct_remove(self.files, _path);
    }
    return true;
}

/// Creates a fully injectable adapter without touching GameMaker's save area.
function _BladeConfigTestMemoryStorageCreate() {
    var _context = {
        files: {},
        write_calls: 0,
        copy_calls: 0,
        move_calls: 0,
        remove_calls: 0,
        fail_write_call: -1,
        fail_copy_call: -1,
        fail_move_calls: [],
        fail_remove_call: -1,
        mismatch_next_write: false,
    };
    return {
        context: _context,
        exists: method(_context, _BladeConfigTestMemoryExists),
        read_text: method(_context, _BladeConfigTestMemoryRead),
        write_text: method(_context, _BladeConfigTestMemoryWrite),
        copy: method(_context, _BladeConfigTestMemoryCopy),
        move: method(_context, _BladeConfigTestMemoryMove),
        remove: method(_context, _BladeConfigTestMemoryRemove),
    };
}

/// Places exact bytes at one test-adapter path without passing through a transaction.
function _BladeConfigTestMemoryPut(_storage, _path, _text) {
    variable_struct_set(_storage.context.files, _path, _text);
}

/// Returns exact bytes from one test path and fails clearly when they are absent.
function _BladeConfigTestMemoryText(_storage, _path) {
    BladeKernelTestAssertTrue(_storage.exists(_path), "expected test path " + _path);
    return variable_struct_get(_storage.context.files, _path);
}

/// Checks every scalar and binding code in two canonical config snapshots.
function _BladeConfigTestAssertEqualConfig(_actual, _expected, _message) {
    BladeKernelTestAssertTrue(BladeConfigIsCanonical(_actual), _message + " actual canonical");
    BladeKernelTestAssertTrue(BladeConfigIsCanonical(_expected), _message + " expected canonical");
    BladeKernelTestAssertEqual(_actual.format_id, _expected.format_id, _message + " format");
    BladeKernelTestAssertEqual(
        _actual.schema_version,
        _expected.schema_version,
        _message + " schema"
    );
    BladeKernelTestAssertEqual(
        _actual.display.fullscreen,
        _expected.display.fullscreen,
        _message + " fullscreen"
    );
    BladeKernelTestAssertEqual(
        _actual.display.window_scale,
        _expected.display.window_scale,
        _message + " window scale"
    );
    BladeKernelTestAssertEqual(
        _actual.display.vsync,
        _expected.display.vsync,
        _message + " vsync"
    );
    BladeKernelTestAssertEqual(
        _actual.audio.master_gain_percent,
        _expected.audio.master_gain_percent,
        _message + " master gain"
    );
    BladeKernelTestAssertEqual(
        _actual.audio.music_gain_percent,
        _expected.audio.music_gain_percent,
        _message + " music gain"
    );
    BladeKernelTestAssertEqual(
        _actual.audio.sfx_gain_percent,
        _expected.audio.sfx_gain_percent,
        _message + " sfx gain"
    );

    var _records = BladeInputBindingRecords();
    for (var _index = 0; _index < array_length(_records); ++_index) {
        var _stable_id = _records[_index].stable_id;
        BladeKernelTestAssertEqual(
            variable_struct_get(_actual.bindings.keyboard, _stable_id),
            variable_struct_get(_expected.bindings.keyboard, _stable_id),
            _message + " keyboard " + _stable_id
        );
        BladeKernelTestAssertEqual(
            variable_struct_get(_actual.bindings.gamepad, _stable_id),
            variable_struct_get(_expected.bindings.gamepad, _stable_id),
            _message + " gamepad " + _stable_id
        );
    }
}

/// Proves defaults are complete, detached, and intentionally share menu/gameplay buttons.
function _BladeConfigTestDefaults() {
    var _config = BladeConfigCreateDefault();
    BladeKernelTestAssertTrue(BladeConfigIsCanonical(_config), "default config canonical");
    BladeKernelTestAssertEqual(_config.format_id, "blade.config", "config format ID");
    BladeKernelTestAssertEqual(_config.schema_version, 1, "config schema version");
    BladeKernelTestAssertEqual(BladeConfigFilename(), "blade-config.json", "config filename");
    BladeKernelTestAssertEqual(
        array_length(variable_struct_get_names(_config.bindings.keyboard)),
        10,
        "keyboard default count"
    );
    BladeKernelTestAssertEqual(
        array_length(variable_struct_get_names(_config.bindings.gamepad)),
        10,
        "gamepad default count"
    );
    BladeKernelTestAssertEqual(
        variable_struct_get(_config.bindings.keyboard, "input.fire"),
        variable_struct_get(_config.bindings.keyboard, "input.confirm"),
        "keyboard fire and confirm share their default"
    );
    BladeKernelTestAssertEqual(
        variable_struct_get(_config.bindings.gamepad, "input.bomb"),
        variable_struct_get(_config.bindings.gamepad, "input.cancel"),
        "gamepad bomb and cancel share their default"
    );

    _config.display.window_scale = 6;
    variable_struct_set(_config.bindings.keyboard, "input.fire", ord("C"));
    var _fresh = BladeConfigCreateDefault();
    BladeKernelTestAssertEqual(_fresh.display.window_scale, 2, "fresh default scale detached");
    BladeKernelTestAssertEqual(
        variable_struct_get(_fresh.bindings.keyboard, "input.fire"),
        ord("Z"),
        "fresh keyboard defaults detached"
    );
}

/// Proves recognized values overlay independently while malformed and unknown data disappear.
function _BladeConfigTestNormalization() {
    var _source = BladeConfigCreateDefault();
    _source.display.fullscreen = "yes";
    _source.display.window_scale = 99.2;
    _source.display.vsync = false;
    _source.audio.master_gain_percent = -10;
    _source.audio.music_gain_percent = 44.6;
    _source.audio.sfx_gain_percent = "loud";
    variable_struct_set(_source, "unknown_root", 7);
    variable_struct_set(_source.display, "unknown_display", true);
    variable_struct_set(_source.bindings.keyboard, "input.fire", ord("C"));
    variable_struct_set(_source.bindings.keyboard, "input.pause", -500);
    variable_struct_set(_source.bindings.keyboard, "input.unknown", ord("Q"));
    variable_struct_set(_source.bindings.gamepad, "input.focus", gp_shoulderr);

    var _normalized = BladeConfigNormalize(_source);
    BladeKernelTestAssertTrue(BladeConfigIsCanonical(_normalized), "normalized config canonical");
    BladeKernelTestAssertFalse(_normalized.display.fullscreen, "invalid boolean falls back");
    BladeKernelTestAssertEqual(_normalized.display.window_scale, 6, "window scale clamps");
    BladeKernelTestAssertFalse(_normalized.display.vsync, "valid boolean overlays");
    BladeKernelTestAssertEqual(_normalized.audio.master_gain_percent, 0, "master clamps low");
    BladeKernelTestAssertEqual(_normalized.audio.music_gain_percent, 45, "music rounds");
    BladeKernelTestAssertEqual(_normalized.audio.sfx_gain_percent, 100, "invalid sfx falls back");
    BladeKernelTestAssertEqual(
        variable_struct_get(_normalized.bindings.keyboard, "input.fire"),
        ord("C"),
        "valid keyboard binding overlays"
    );
    BladeKernelTestAssertEqual(
        variable_struct_get(_normalized.bindings.keyboard, "input.pause"),
        vk_escape,
        "invalid keyboard binding falls back"
    );
    BladeKernelTestAssertEqual(
        variable_struct_get(_normalized.bindings.gamepad, "input.focus"),
        gp_shoulderr,
        "valid gamepad binding overlays"
    );
    BladeKernelTestAssertFalse(
        variable_struct_exists(_normalized, "unknown_root"),
        "unknown root removed"
    );
    BladeKernelTestAssertFalse(
        variable_struct_exists(_normalized.bindings.keyboard, "input.unknown"),
        "unknown binding removed"
    );
}

/// Characterizes current, malformed, and unsupported-future serializer outcomes.
function _BladeConfigTestSerializer() {
    var _default = BladeConfigCreateDefault();
    var _text = BladeConfigSerializerStringify(_default);
    var _parsed = BladeConfigSerializerParse(_text);
    BladeKernelTestAssertEqual(_parsed.kind, BladeConfigParseKind.Current, "current parse kind");
    BladeKernelTestAssertFalse(_parsed.was_normalized, "canonical JSON needs no normalization");
    _BladeConfigTestAssertEqualConfig(_parsed.config, _default, "serializer round trip");

    var _corrupt = BladeConfigSerializerParse("{not-json");
    BladeKernelTestAssertEqual(_corrupt.kind, BladeConfigParseKind.Corrupt, "corrupt parse kind");
    var _future_text = json_stringify({
        format_id: BladeConfigFormatId(),
        schema_version: BladeConfigSchemaVersion() + 1,
    });
    var _future = BladeConfigSerializerParse(_future_text);
    BladeKernelTestAssertEqual(_future.kind, BladeConfigParseKind.Future, "future parse kind");
    BladeKernelTestAssertEqual(_future.source_version, 2, "future source version");
}

/// Exercises missing defaults and a complete save/load round trip through injection.
function _BladeConfigTestMissingAndRoundTrip() {
    var _storage = _BladeConfigTestMemoryStorageCreate();
    var _service = BladeConfigServiceCreate(_storage, "automation-config.json");
    var _missing = BladeConfigServiceLoad(_service);
    BladeKernelTestAssertEqual(
        _missing.status,
        BladeConfigLoadStatus.MissingDefaults,
        "missing config status"
    );
    var _rejected = BladeConfigServiceSave(_service, { schema_version: 99 });
    BladeKernelTestAssertFalse(_rejected.ok, "unsupported save candidate rejected");
    BladeKernelTestAssertEqual(
        _rejected.code,
        "config.save.unsupported_candidate",
        "unsupported candidate diagnostic"
    );
    BladeKernelTestAssertFalse(
        _storage.exists("automation-config.json"),
        "unsupported candidate does not create a file"
    );

    var _candidate = BladeConfigServiceSnapshot(_service);
    _candidate.display.fullscreen = true;
    _candidate.audio.music_gain_percent = 37;
    variable_struct_set(_candidate.bindings.keyboard, "input.fire", ord("C"));
    var _saved = BladeConfigServiceSave(_service, _candidate);
    BladeKernelTestAssertTrue(_saved.ok, "memory config save succeeds");

    var _reloaded_service = BladeConfigServiceCreate(_storage, "automation-config.json");
    var _loaded = BladeConfigServiceLoad(_reloaded_service);
    BladeKernelTestAssertEqual(_loaded.status, BladeConfigLoadStatus.Loaded, "loaded status");
    _BladeConfigTestAssertEqualConfig(_loaded.config, _candidate, "service round trip");
}

/// Preserves malformed raw bytes and returns a fresh default payload.
function _BladeConfigTestCorruptBackup() {
    var _storage = _BladeConfigTestMemoryStorageCreate();
    var _filename = "automation-corrupt.json";
    var _raw = "{definitely\r\nnot-json}\r\n";
    _BladeConfigTestMemoryPut(_storage, _filename, _raw);
    var _service = BladeConfigServiceCreate(_storage, _filename);
    var _loaded = BladeConfigServiceLoad(_service);

    BladeKernelTestAssertEqual(
        _loaded.status,
        BladeConfigLoadStatus.CorruptDefaults,
        "corrupt config status"
    );
    BladeKernelTestAssertTrue(_loaded.backup_ok, "corrupt backup succeeds");
    BladeKernelTestAssertEqual(
        _BladeConfigTestMemoryText(_storage, _filename + ".corrupt.backup"),
        _raw,
        "corrupt copy preserves CRLF and trailing newline"
    );
    BladeKernelTestAssertEqual(
        _BladeConfigTestMemoryText(_storage, _filename),
        _raw,
        "corrupt live bytes remain available"
    );
    _BladeConfigTestAssertEqualConfig(
        _loaded.config,
        BladeConfigCreateDefault(),
        "corrupt fallback defaults"
    );
}

/// Rejects a future schema, preserves its exact bytes, and never downgrades live data.
function _BladeConfigTestFutureBackup() {
    var _storage = _BladeConfigTestMemoryStorageCreate();
    var _filename = "automation-future.json";
    var _raw = "{\r\n  \"format_id\": \"blade.config\",\r\n"
        + "  \"schema_version\": 2,\r\n  \"future\": true\r\n}\r\n";
    _BladeConfigTestMemoryPut(_storage, _filename, _raw);
    _storage.context.fail_copy_call = 1;
    var _service = BladeConfigServiceCreate(_storage, _filename);
    var _failed = BladeConfigServiceLoad(_service);

    BladeKernelTestAssertEqual(
        _failed.status,
        BladeConfigLoadStatus.FutureDefaults,
        "future copy-failure status"
    );
    BladeKernelTestAssertFalse(_failed.backup_ok, "future injected copy failure reports false");
    BladeKernelTestAssertFalse(
        _storage.exists(_filename + ".future-v2.backup"),
        "failed future copy does not publish backup"
    );
    BladeKernelTestAssertEqual(
        _BladeConfigTestMemoryText(_storage, _filename),
        _raw,
        "future live bytes remain while backup fails"
    );

    _storage.context.fail_copy_call = -1;
    var _retry_service = BladeConfigServiceCreate(_storage, _filename);
    var _loaded = BladeConfigServiceLoad(_retry_service);

    BladeKernelTestAssertEqual(
        _loaded.status,
        BladeConfigLoadStatus.FutureDefaults,
        "future config status"
    );
    BladeKernelTestAssertTrue(_loaded.backup_ok, "future backup succeeds");
    BladeKernelTestAssertEqual(
        _BladeConfigTestMemoryText(_storage, _filename + ".future-v2.backup"),
        _raw,
        "future copy preserves CRLF and trailing newline"
    );
    BladeKernelTestAssertEqual(
        _BladeConfigTestMemoryText(_storage, _filename),
        _raw,
        "future live bytes remain unchanged"
    );
}

/// Fails copied-backup promotion and restores the prior backup without touching source.
function _BladeConfigTestCopyFailureRollback() {
    var _storage = _BladeConfigTestMemoryStorageCreate();
    var _alias_target = "automation-copy-alias.backup";
    var _temporary_source = BladeConfigStorageTemporaryPath(_alias_target);
    var _previous_source = BladeConfigStoragePreviousPath(_alias_target);
    _BladeConfigTestMemoryPut(_storage, _temporary_source, "temporary source");
    _BladeConfigTestMemoryPut(_storage, _previous_source, "previous source");
    var _temporary_alias = BladeConfigStorageTransactionalCopy(
        _storage,
        _temporary_source,
        _alias_target
    );
    var _previous_alias = BladeConfigStorageTransactionalCopy(
        _storage,
        _previous_source,
        _alias_target
    );
    BladeKernelTestAssertFalse(_temporary_alias.ok, "copy rejects temporary source alias");
    BladeKernelTestAssertFalse(_previous_alias.ok, "copy rejects previous source alias");
    BladeKernelTestAssertEqual(
        _BladeConfigTestMemoryText(_storage, _temporary_source),
        "temporary source",
        "copy retains temporary source alias"
    );
    BladeKernelTestAssertEqual(
        _BladeConfigTestMemoryText(_storage, _previous_source),
        "previous source",
        "copy retains previous source alias"
    );

    var _source_path = "automation-copy-source.json";
    var _target_path = "automation-copy-target.backup";
    var _source = "source\r\nbytes\r\n";
    var _prior_target = "prior backup";
    _BladeConfigTestMemoryPut(_storage, _source_path, _source);
    _BladeConfigTestMemoryPut(_storage, _target_path, _prior_target);
    _storage.context.fail_move_calls = [2];

    var _failed = BladeConfigStorageTransactionalCopy(
        _storage,
        _source_path,
        _target_path
    );
    BladeKernelTestAssertFalse(_failed.ok, "copy promotion failure reports false");
    BladeKernelTestAssertEqual(
        _failed.code,
        "config.storage.copy_promote_failed_rolled_back",
        "copy rollback diagnostic"
    );
    BladeKernelTestAssertEqual(
        _BladeConfigTestMemoryText(_storage, _source_path),
        _source,
        "copy rollback leaves exact source bytes"
    );
    BladeKernelTestAssertEqual(
        _BladeConfigTestMemoryText(_storage, _target_path),
        _prior_target,
        "copy rollback restores prior target"
    );
    BladeKernelTestAssertFalse(
        _storage.exists(BladeConfigStorageTemporaryPath(_target_path)),
        "copy rollback removes temporary candidate"
    );
}

/// Injects a temporary-write failure and proves live bytes and current state do not change.
function _BladeConfigTestWriteFailure() {
    var _storage = _BladeConfigTestMemoryStorageCreate();
    var _service = BladeConfigServiceCreate(_storage, "automation-write-failure.json");
    var _old = BladeConfigCreateDefault();
    _old.audio.master_gain_percent = 70;
    BladeKernelTestAssertTrue(BladeConfigServiceSave(_service, _old).ok, "initial save");
    var _old_text = _BladeConfigTestMemoryText(_storage, _service.filename);

    var _new = BladeConfigServiceSnapshot(_service);
    _new.audio.master_gain_percent = 20;
    _storage.context.fail_write_call = _storage.context.write_calls + 1;
    var _failed = BladeConfigServiceSave(_service, _new);
    BladeKernelTestAssertFalse(_failed.ok, "injected write failure reports false");
    BladeKernelTestAssertEqual(
        _BladeConfigTestMemoryText(_storage, _service.filename),
        _old_text,
        "write failure preserves live bytes"
    );
    _BladeConfigTestAssertEqualConfig(
        BladeConfigServiceSnapshot(_service),
        _old,
        "write failure preserves current config"
    );
}

/// Injects a temporary reread mismatch before any live payload is archived.
function _BladeConfigTestTemporaryVerificationFailure() {
    var _storage = _BladeConfigTestMemoryStorageCreate();
    var _service = BladeConfigServiceCreate(_storage, "automation-verify-failure.json");
    var _old = BladeConfigCreateDefault();
    _old.audio.master_gain_percent = 68;
    BladeKernelTestAssertTrue(BladeConfigServiceSave(_service, _old).ok, "initial save");
    var _old_text = _BladeConfigTestMemoryText(_storage, _service.filename);

    var _new = BladeConfigServiceSnapshot(_service);
    _new.audio.master_gain_percent = 18;
    _storage.context.mismatch_next_write = true;
    var _failed = BladeConfigServiceSave(_service, _new);
    BladeKernelTestAssertFalse(_failed.ok, "temporary verification failure reports false");
    BladeKernelTestAssertEqual(
        _failed.code,
        "config.storage.temp_verify_failed",
        "temporary verification diagnostic"
    );
    BladeKernelTestAssertEqual(
        _BladeConfigTestMemoryText(_storage, _service.filename),
        _old_text,
        "temporary verification failure preserves live bytes"
    );
    BladeKernelTestAssertFalse(
        _storage.exists(BladeConfigStorageTemporaryPath(_service.filename)),
        "failed temporary candidate is removed"
    );
    _BladeConfigTestAssertEqualConfig(
        BladeConfigServiceSnapshot(_service),
        _old,
        "temporary verification failure preserves current config"
    );
}

/// Injects promotion failure and proves the archived live payload rolls back in place.
function _BladeConfigTestReplaceFailureRollback() {
    var _storage = _BladeConfigTestMemoryStorageCreate();
    var _service = BladeConfigServiceCreate(_storage, "automation-replace-failure.json");
    var _old = BladeConfigCreateDefault();
    _old.audio.sfx_gain_percent = 71;
    BladeKernelTestAssertTrue(BladeConfigServiceSave(_service, _old).ok, "initial save");
    var _old_text = _BladeConfigTestMemoryText(_storage, _service.filename);

    var _new = BladeConfigServiceSnapshot(_service);
    _new.audio.sfx_gain_percent = 19;
    var _promotion_call = _storage.context.move_calls + 2;
    _storage.context.fail_move_calls = [_promotion_call];
    var _failed = BladeConfigServiceSave(_service, _new);
    BladeKernelTestAssertFalse(_failed.ok, "injected replace failure reports false");
    BladeKernelTestAssertEqual(
        _failed.code,
        "config.storage.replace_failed_rolled_back",
        "replace failure rollback diagnostic"
    );
    BladeKernelTestAssertEqual(
        _BladeConfigTestMemoryText(_storage, _service.filename),
        _old_text,
        "rollback restores live bytes"
    );
}

/// Leaves the prior payload at its recovery path when promotion and rollback both fail.
function _BladeConfigTestRollbackFailureRecovery() {
    var _storage = _BladeConfigTestMemoryStorageCreate();
    var _filename = "automation-rollback-failure.json";
    var _service = BladeConfigServiceCreate(_storage, _filename);
    var _old = BladeConfigCreateDefault();
    _old.audio.music_gain_percent = 63;
    BladeKernelTestAssertTrue(BladeConfigServiceSave(_service, _old).ok, "initial save");

    var _new = BladeConfigServiceSnapshot(_service);
    _new.audio.music_gain_percent = 11;
    var _promotion_call = _storage.context.move_calls + 2;
    _storage.context.fail_move_calls = [_promotion_call, _promotion_call + 1];
    var _failed = BladeConfigServiceSave(_service, _new);
    BladeKernelTestAssertFalse(_failed.ok, "rollback failure reports false");
    BladeKernelTestAssertEqual(
        _failed.code,
        "config.storage.rollback_failed",
        "rollback failure diagnostic"
    );
    BladeKernelTestAssertFalse(_storage.exists(_filename), "failed live path remains absent");
    BladeKernelTestAssertTrue(
        _storage.exists(BladeConfigStoragePreviousPath(_filename)),
        "previous payload remains recoverable"
    );

    _storage.context.fail_move_calls = [];
    var _recovery_service = BladeConfigServiceCreate(_storage, _filename);
    var _recovered = BladeConfigServiceLoad(_recovery_service);
    BladeKernelTestAssertEqual(
        _recovered.status,
        BladeConfigLoadStatus.RecoveredPrevious,
        "previous recovery status"
    );
    _BladeConfigTestAssertEqualConfig(_recovered.config, _old, "recovered previous config");
}

/// Rewrites a valid partial payload while retaining its original bytes as previous.
function _BladeConfigTestNormalizedRewrite() {
    var _storage = _BladeConfigTestMemoryStorageCreate();
    var _filename = "automation-normalized.json";
    var _partial = BladeConfigCreateDefault();
    _partial.display.window_scale = 20;
    _partial.audio.master_gain_percent = 33.7;
    variable_struct_set(_partial, "unknown", "discard me");
    var _raw = json_stringify(_partial);
    _BladeConfigTestMemoryPut(_storage, _filename, _raw);

    var _service = BladeConfigServiceCreate(_storage, _filename);
    var _loaded = BladeConfigServiceLoad(_service);
    BladeKernelTestAssertEqual(
        _loaded.status,
        BladeConfigLoadStatus.Normalized,
        "normalized load status"
    );
    BladeKernelTestAssertTrue(_loaded.rewrite_ok, "normalized payload rewrites");
    BladeKernelTestAssertEqual(_loaded.config.display.window_scale, 6, "normalized scale");
    BladeKernelTestAssertEqual(_loaded.config.audio.master_gain_percent, 34, "normalized gain");
    BladeKernelTestAssertEqual(
        _BladeConfigTestMemoryText(_storage, BladeConfigStoragePreviousPath(_filename)),
        _raw,
        "normalization retains original bytes"
    );
    var _live_parse = BladeConfigSerializerParse(
        _BladeConfigTestMemoryText(_storage, _filename)
    );
    BladeKernelTestAssertEqual(
        _live_parse.kind,
        BladeConfigParseKind.Current,
        "normalized live parse kind"
    );
    BladeKernelTestAssertFalse(_live_parse.was_normalized, "normalized live is canonical");
}

/// Returns every exact artifact path owned by the real-adapter config test.
function _BladeConfigTestDiskPaths() {
    var _filename = "automation-blade-config-issue8.json";
    var _corrupt = _filename + ".corrupt.backup";
    var _future = _filename + ".future-v2.backup";
    return [
        _filename,
        BladeConfigStorageTemporaryPath(_filename),
        BladeConfigStoragePreviousPath(_filename),
        _corrupt,
        BladeConfigStorageTemporaryPath(_corrupt),
        BladeConfigStoragePreviousPath(_corrupt),
        _future,
        BladeConfigStorageTemporaryPath(_future),
        BladeConfigStoragePreviousPath(_future),
    ];
}

/// Removes only the real-adapter test's enumerated automation-prefixed artifacts.
function _BladeConfigTestDiskCleanup() {
    var _storage = BladeConfigFileStorageCreate();
    var _paths = _BladeConfigTestDiskPaths();
    for (var _index = 0; _index < array_length(_paths); ++_index) {
        var _path = _paths[_index];
        if (string_pos("automation-blade-config-issue8", _path) == 1) {
            _storage.remove(_path);
        }
    }
}

/// Requires every enumerated real-adapter artifact to be absent after cleanup.
function _BladeConfigTestDiskAssertClean() {
    var _storage = BladeConfigFileStorageCreate();
    var _paths = _BladeConfigTestDiskPaths();
    for (var _index = 0; _index < array_length(_paths); ++_index) {
        BladeKernelTestAssertFalse(
            _storage.exists(_paths[_index]),
            "cleaned real-adapter artifact " + _paths[_index]
        );
    }
}

/// Runs one disk callback with exact cleanup before and after, including failure paths.
function _BladeConfigTestWithDiskCleanup(_callback) {
    _BladeConfigTestDiskCleanup();
    _BladeConfigTestDiskAssertClean();
    var _failed = false;
    var _caught = undefined;
    try {
        _callback();
    } catch (_exception) {
        _failed = true;
        _caught = _exception;
    }
    _BladeConfigTestDiskCleanup();
    _BladeConfigTestDiskAssertClean();
    if (_failed) {
        throw(_caught);
    }
}

/// Proves the production adapter round-trips through GameMaker's per-user save area.
function _BladeConfigTestFileAdapterRoundTrip() {
    var _storage = BladeConfigFileStorageCreate();
    var _filename = "automation-blade-config-issue8.json";
    var _service = BladeConfigServiceCreate(_storage, _filename);
    var _candidate = BladeConfigCreateDefault();
    _candidate.display.fullscreen = true;
    _candidate.audio.sfx_gain_percent = 42;
    BladeKernelTestAssertTrue(
        BladeConfigServiceSave(_service, _candidate).ok,
        "file adapter save succeeds"
    );
    BladeKernelTestAssertTrue(_storage.exists(_filename), "isolated file exists");

    var _copy_path = _filename + ".future-v2.backup";
    var _copied = BladeConfigStorageTransactionalCopy(
        _storage,
        _filename,
        _copy_path
    );
    BladeKernelTestAssertTrue(_copied.ok, "file adapter exact copy succeeds");
    var _source_read = _storage.read_text(_filename);
    var _copy_read = _storage.read_text(_copy_path);
    BladeKernelTestAssertTrue(_source_read.ok, "file adapter source rereads");
    BladeKernelTestAssertTrue(_copy_read.ok, "file adapter copy rereads");
    BladeKernelTestAssertEqual(_copy_read.text, _source_read.text, "file adapter copy matches");

    var _reloaded = BladeConfigServiceCreate(_storage, _filename);
    var _loaded = BladeConfigServiceLoad(_reloaded);
    BladeKernelTestAssertEqual(_loaded.status, BladeConfigLoadStatus.Loaded, "file load status");
    _BladeConfigTestAssertEqualConfig(_loaded.config, _candidate, "file adapter round trip");
}

/// @func BladeConfigTestsRun(state)
/// Registers config payload, recovery, transaction, and real-adapter cases.
function BladeConfigTestsRun(_state) {
    BladeKernelTestRunCase(_state, "config defaults and stable binding coverage", function() {
        // Check the complete fresh payload and intentionally shared physical defaults.
        _BladeConfigTestDefaults();
    });
    BladeKernelTestRunCase(_state, "config recognized-field normalization", function() {
        // Overlay valid values while clamping ranges and dropping malformed fields.
        _BladeConfigTestNormalization();
    });
    BladeKernelTestRunCase(_state, "config serializer classification", function() {
        // Distinguish canonical, corrupt, and unsupported-future JSON.
        _BladeConfigTestSerializer();
    });
    BladeKernelTestRunCase(_state, "config missing and round-trip load", function() {
        // Exercise defaults followed by a complete injected-storage round trip.
        _BladeConfigTestMissingAndRoundTrip();
    });
    BladeKernelTestRunCase(_state, "config corruption fallback and backup", function() {
        // Preserve malformed raw bytes before falling back to fresh defaults.
        _BladeConfigTestCorruptBackup();
    });
    BladeKernelTestRunCase(_state, "config future-version rejection and backup", function() {
        // Preserve and reject newer data without replacing its live path.
        _BladeConfigTestFutureBackup();
    });
    BladeKernelTestRunCase(_state, "config copy promotion rollback", function() {
        // Restore a prior backup when publishing its exact copied replacement fails.
        _BladeConfigTestCopyFailureRollback();
    });
    BladeKernelTestRunCase(_state, "config interrupted temporary write", function() {
        // Fail temporary writing before any live payload is moved.
        _BladeConfigTestWriteFailure();
    });
    BladeKernelTestRunCase(_state, "config temporary verification failure", function() {
        // Reject a temporary file whose exact reread differs before promotion.
        _BladeConfigTestTemporaryVerificationFailure();
    });
    BladeKernelTestRunCase(_state, "config replace failure rollback", function() {
        // Fail promotion and require the prior live payload to return in place.
        _BladeConfigTestReplaceFailureRollback();
    });
    BladeKernelTestRunCase(_state, "config rollback-failure recovery", function() {
        // Fail promotion and rollback, then recover the retained previous payload.
        _BladeConfigTestRollbackFailureRecovery();
    });
    BladeKernelTestRunCase(_state, "config normalized rewrite retains original", function() {
        // Canonicalize recognized values while preserving the source at previous.
        _BladeConfigTestNormalizedRewrite();
    });
    BladeKernelTestRunCase(_state, "config isolated GameMaker file adapter", function() {
        // Use one exact automation filename and clean only its enumerated artifacts.
        _BladeConfigTestWithDiskCleanup(method({}, _BladeConfigTestFileAdapterRoundTrip));
    });
    return _state;
}
