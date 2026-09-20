/// @description Deterministic catalog, failure-state, and playback-launch tests.

function _BladeReplayCatalogTestMemoryList() {
    var _paths = [];
    var _names = variable_struct_get_names(self.files);
    for (var _index = 0; _index < array_length(_names); ++_index) {
        array_push(_paths, _names[_index]);
    }
    var _failed_names = variable_struct_get_names(self.fail_reads);
    for (var _failed_index = 0;
        _failed_index < array_length(_failed_names);
        ++_failed_index) {
        array_push(_paths, _failed_names[_failed_index]);
    }
    return { ok: true, paths: _paths, code: "replay.catalog.listed" };
}

function _BladeReplayCatalogTestMemoryRead(_path) {
    if (variable_struct_exists(self.files, _path)) {
        return {
            ok: true,
            text: variable_struct_get(self.files, _path),
            code: "replay.catalog.read",
        };
    }
    if (variable_struct_exists(self.fail_reads, _path)) {
        return {
            ok: false,
            text: "",
            code: "replay.catalog.unreadable",
            diagnostic: "injected read failure",
        };
    }
    return { ok: false, text: "", code: "replay.catalog.missing" };
}

function _BladeReplayCatalogTestMemoryWrite(_path, _text) {
    if (variable_struct_exists(self.fail_writes, _path)) {
        return { ok: false, code: "replay.catalog.write_failed" };
    }
    variable_struct_set(self.files, _path, _text);
    return { ok: true, code: "replay.catalog.saved" };
}

function _BladeReplayCatalogTestMemoryStorageCreate() {
    var _context = {
        files: {},
        fail_reads: {},
        fail_writes: {},
    };
    return {
        context: _context,
        list: method(_context, _BladeReplayCatalogTestMemoryList),
        read_text: method(_context, _BladeReplayCatalogTestMemoryRead),
        write_text: method(_context, _BladeReplayCatalogTestMemoryWrite),
    };
}

function _BladeReplayCatalogTestKnownContent(_content_id) {
    return _content_id == "ship.maynii"
        || _content_id == "difficulty.normal";
}

function _BladeReplayCatalogTestRecording() {
    return _BladeReplayTestFixture(BladePromptDevice.KeyboardMouse).recording;
}

function _BladeReplayCatalogTestFindState(_catalog, _state) {
    for (var _index = 0; _index < array_length(_catalog.entries); ++_index) {
        if (_catalog.entries[_index].state == _state) return _catalog.entries[_index];
    }
    return undefined;
}

function _BladeReplayCatalogTestFindPathIndex(_catalog, _path) {
    for (var _index = 0; _index < array_length(_catalog.entries); ++_index) {
        if (_catalog.entries[_index].file_path == _path) return _index;
    }
    return -1;
}

function _BladeReplayCatalogTestSaveAndRefresh() {
    var _storage = _BladeReplayCatalogTestMemoryStorageCreate();
    var _catalog = BladeReplayCatalogCreate(_storage);
    var _recording = _BladeReplayCatalogTestRecording();
    var _saved = BladeReplayCatalogSave(_catalog, _recording);
    BladeKernelTestAssertTrue(_saved.ok, "canonical recording saves");
    BladeKernelTestAssertEqual(
        _saved.entry.replay_id,
        "replay." + BladeReplayRecordingHash(_recording),
        "replay ID derives from payload hash"
    );
    var _refresh = BladeReplayCatalogRefresh(_catalog);
    BladeKernelTestAssertTrue(_refresh.ok, "catalog refresh succeeds");
    BladeKernelTestAssertEqual(
        array_length(_catalog.entries), 1, "saved recording is listed once"
    );
    var _entry = _catalog.entries[0];
    BladeKernelTestAssertEqual(
        _entry.state, BladeReplayCatalogEntryState.Playable,
        "valid recording is playable"
    );
    BladeKernelTestAssertEqual(_entry.run_seed, int64(305419896), "seed is listed");
    BladeKernelTestAssertEqual(_entry.ship_id, "ship.maynii", "ship is listed");
    BladeKernelTestAssertEqual(
        _entry.difficulty_id, "difficulty.normal", "difficulty is listed"
    );
    BladeKernelTestAssertEqual(
        _entry.progress_ticks, int64(4), "recording progress uses available tick count"
    );
    BladeKernelTestAssertEqual(
        _entry.terminal_result, "not_recorded",
        "catalog reports unavailable terminal metadata explicitly"
    );
    BladeKernelTestAssertFalse(
        _entry.has_score, "catalog does not invent absent score metadata"
    );
}

function _BladeReplayCatalogTestFailureStates() {
    var _storage = _BladeReplayCatalogTestMemoryStorageCreate();
    var _catalog = BladeReplayCatalogCreate(_storage);
    var _valid = _BladeReplayCatalogTestRecording();
    variable_struct_set(_storage.context.files, "z-valid.brp", _valid);
    variable_struct_set(
        _storage.context.files,
        "a-future.brp",
        string_replace(_valid, "BRP1|1|", "BRP1|2|")
    );
    variable_struct_set(_storage.context.files, "b-corrupt.brp", "not a BRP1 payload");
    variable_struct_set(_storage.context.fail_reads, "c-unreadable.brp", true);
    var _refresh = BladeReplayCatalogRefresh(_catalog);
    BladeKernelTestAssertTrue(_refresh.ok, "mixed catalog refresh succeeds");
    BladeKernelTestAssertEqual(
        array_length(_catalog.entries), 4,
        "mixed catalog keeps every listed source"
    );
    var _unsupported = _BladeReplayCatalogTestFindState(
        _catalog, BladeReplayCatalogEntryState.Unsupported
    );
    BladeKernelTestAssertTrue(
        is_struct(_unsupported), "future schema has an explicit catalog state"
    );
    BladeKernelTestAssertEqual(
        _unsupported.state_token,
        "unsupported",
        "future schema is explicitly unsupported"
    );
    var _corrupt = _BladeReplayCatalogTestFindState(
        _catalog, BladeReplayCatalogEntryState.Corrupt
    );
    BladeKernelTestAssertTrue(
        is_struct(_corrupt), "malformed payload has an explicit catalog state"
    );
    BladeKernelTestAssertEqual(
        _corrupt.state_token,
        "corrupt",
        "malformed payload is explicitly corrupt"
    );
    var _unreadable = _BladeReplayCatalogTestFindState(
        _catalog, BladeReplayCatalogEntryState.Unreadable
    );
    BladeKernelTestAssertTrue(
        is_struct(_unreadable), "read failure has an explicit catalog state"
    );
    BladeKernelTestAssertEqual(
        _unreadable.state_token,
        "unreadable",
        "read failure is explicitly unreadable"
    );
    variable_struct_remove(_storage.context.files, "z-valid.brp");
    var _missing_index = _BladeReplayCatalogTestFindPathIndex(
        _catalog, "z-valid.brp"
    );
    BladeKernelTestAssertTrue(
        _missing_index >= 0, "removed source remains addressable by catalog path"
    );
    var _missing = BladeReplayCatalogOpen(_catalog, _missing_index);
    BladeKernelTestAssertEqual(
        _missing.state, BladeReplayCatalogEntryState.Missing,
        "removed source is reported missing at launch time"
    );
}

function _BladeReplayCatalogTestLaunchIsPlaybackOnly() {
    var _storage = _BladeReplayCatalogTestMemoryStorageCreate();
    var _catalog = BladeReplayCatalogCreate(_storage);
    var _recording = _BladeReplayCatalogTestRecording();
    BladeReplayCatalogSave(_catalog, _recording);
    BladeReplayCatalogRefresh(_catalog);
    var _before = variable_struct_get(
        _storage.context.files, _catalog.entries[0].file_path
    );
    var _launch = BladeReplayCatalogLaunch(
        _catalog,
        0,
        method({}, _BladeReplayCatalogTestKnownContent)
    );
    BladeKernelTestAssertTrue(_launch.ok, "playable catalog entry launches playback");
    BladeKernelTestAssertTrue(
        is_struct(_launch.playback), "launch returns the deterministic playback owner"
    );
    var _run = BladeReplayPlaybackRunToEnd(
        _launch.playback,
        BladeClockDomain.Stage
            | BladeClockDomain.Actor
            | BladeClockDomain.Boss
            | BladeClockDomain.Combat
    );
    BladeKernelTestAssertEqual(_run.ticks_run, int64(4), "playback consumes every tick");
    BladeReplayPlaybackComplete(_launch.playback);
    BladeKernelTestAssertEqual(
        variable_struct_get(_storage.context.files, _catalog.entries[0].file_path),
        _before,
        "catalog launch never mutates the source replay"
    );
}

function _BladeReplayCatalogTestInvalidSave() {
    var _storage = _BladeReplayCatalogTestMemoryStorageCreate();
    var _catalog = BladeReplayCatalogCreate(_storage);
    var _saved = BladeReplayCatalogSave(_catalog, "not a replay");
    BladeKernelTestAssertFalse(_saved.ok, "invalid recording cannot be saved");
    BladeKernelTestAssertEqual(
        array_length(variable_struct_get_names(_storage.context.files)),
        0,
        "invalid save leaves storage empty"
    );
}

/// Registers catalog discovery, failure-state, and playback cases.
function BladeReplayCatalogTestsRun(_state) {
    BladeKernelTestRunCase(_state, "replay catalog saves and lists metadata", function() {
        _BladeReplayCatalogTestSaveAndRefresh();
    });
    BladeKernelTestRunCase(_state, "replay catalog preserves explicit failure states", function() {
        _BladeReplayCatalogTestFailureStates();
    });
    BladeKernelTestRunCase(_state, "replay catalog launches deterministic playback", function() {
        _BladeReplayCatalogTestLaunchIsPlaybackOnly();
    });
    BladeKernelTestRunCase(_state, "replay catalog rejects invalid saves", function() {
        _BladeReplayCatalogTestInvalidSave();
    });
    return _state;
}
