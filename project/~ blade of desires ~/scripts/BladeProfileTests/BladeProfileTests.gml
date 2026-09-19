/// Focused persistence, progression, and authoritative-result tests for #135.

function _BladeProfileTestMemoryExists(_path) {
    return variable_struct_exists(self.files, _path);
}

function _BladeProfileTestMemoryRead(_path) {
    if (!variable_struct_exists(self.files, _path)) {
        return { ok: false, text: "" };
    }
    return { ok: true, text: variable_struct_get(self.files, _path) };
}

function _BladeProfileTestMemoryWrite(_path, _text) {
    self.write_calls += 1;
    if (self.fail_write_call == self.write_calls) return false;
    variable_struct_set(self.files, _path, _text);
    return true;
}

function _BladeProfileTestMemoryMove(_source, _target) {
    self.move_calls += 1;
    if (self.fail_move_call == self.move_calls) return false;
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

function _BladeProfileTestMemoryRemove(_path) {
    if (variable_struct_exists(self.files, _path)) {
        variable_struct_remove(self.files, _path);
    }
    return true;
}

function _BladeProfileTestMemoryStorageCreate() {
    var _context = {
        files: {},
        write_calls: 0,
        move_calls: 0,
        fail_write_call: -1,
        fail_move_call: -1,
    };
    return {
        context: _context,
        exists: method(_context, _BladeProfileTestMemoryExists),
        read_text: method(_context, _BladeProfileTestMemoryRead),
        write_text: method(_context, _BladeProfileTestMemoryWrite),
        move: method(_context, _BladeProfileTestMemoryMove),
        remove: method(_context, _BladeProfileTestMemoryRemove),
    };
}

function _BladeProfileTestSelection() {
    return {
        __blade_stage1_selected_run_version: 2,
        difficulty_id: BLADE_DIFFICULTY_NORMAL_ID,
        ship_id: "ship.ciela",
        route_id: "route.stage1.ciela_lost_forest",
        player_kind_id: "player_kind.stage1.ciela",
        loadout_id: "loadout.stage1.ciela_spread",
        stage_schedule_id: BLADE_PROFILE_STAGE1_SCHEDULE_ID,
        midboss_ship_ids: ["ship.maynii", "ship.kolar"],
        standard_pattern_ids: [
            "pattern.stage1.maynii_leaf_wing",
            "pattern.stage1.kolar_mountain_crystal",
        ],
        combo_pattern_id: "pattern.stage1.root_ridgeline",
    };
}

function _BladeProfileTestRunResult() {
    var _economy = BladeSurvivalEconomyCreate(BLADE_DIFFICULTY_NORMAL_ID);
    _economy.score = 123456;
    var _controller = {
        selected_run: _BladeProfileTestSelection(),
        economy: _economy,
        boss_resolution: BladeStage1BossResolution.Defeat,
        boss_instance: noone,
        route_cue_id: "cue.stage1.stage_clear",
        state: BladeFirstBeatState.Playing,
        stage_executor: {
            lifecycle: BladeStageLifecycle.Completed,
        },
        stage_clear_breakdown: { base: 50000, lives: 0, bombs: 0, total: 50000 },
    };
    var _result = BladeStage1RunResultCreate();
    BladeStage1RunResultCaptureClear(_result, _controller, 10);
    BladeStage1RunResultComplete(_result, _controller, 11);
    return _result;
}

function _BladeProfileTestRoundTrip() {
    var _profile = BladeProfileCreateDefault();
    BladeProfileGrantAchievement(_profile, "achievement.first_clear");
    BladeProfileGrantCgFlag(_profile, "cg.intro_scene");
    var _text = BladeProfileSerializerStringify(_profile);
    var _parsed = BladeProfileSerializerParse(_text);
    BladeKernelTestAssertEqual(
        _parsed.kind, BladeProfileParseKind.Current, "profile round trip kind"
    );
    BladeKernelTestAssertTrue(
        BladeProfileIsCanonical(_parsed.profile), "profile round trip canonical"
    );
    BladeKernelTestAssertTrue(
        BladeProfileHasFlag(
            _parsed.profile, BladeProfileFlagKind.Achievement,
            "achievement.first_clear"
        ),
        "achievement flag survives round trip"
    );
    BladeKernelTestAssertTrue(
        BladeProfileHasFlag(
            _parsed.profile, BladeProfileFlagKind.Cg, "cg.intro_scene"
        ),
        "CG flag survives round trip"
    );
}

function _BladeProfileTestDerivedUnlock() {
    var _profile = BladeProfileCreateDefault();
    var _stages = BladeProfileMainCampaignStageIds();
    for (var _index = 0; _index < array_length(_stages); ++_index) {
        BladeProfileRecordClear(
            _profile,
            _stages[_index],
            "ship.ciela",
            BLADE_DIFFICULTY_NORMAL_ID,
            true
        );
    }
    BladeProfileRecomputeDerivedUnlocks(_profile);
    BladeKernelTestAssertTrue(
        BladeProfileHasUnlock(_profile, BLADE_PROFILE_EXTRA_UNLOCK_ID),
        "one-credit campaign clears derive the extra-stage unlock"
    );
    var _continued = BladeProfileCreateDefault();
    BladeProfileRecordClear(
        _continued,
        _stages[0],
        "ship.ciela",
        BLADE_DIFFICULTY_NORMAL_ID,
        false
    );
    for (var _continued_index = 1;
        _continued_index < array_length(_stages);
        ++_continued_index) {
        BladeProfileRecordClear(
            _continued,
            _stages[_continued_index],
            "ship.ciela",
            BLADE_DIFFICULTY_NORMAL_ID,
            true
        );
    }
    BladeProfileRecomputeDerivedUnlocks(_continued);
    BladeKernelTestAssertFalse(
        BladeProfileHasUnlock(_continued, BLADE_PROFILE_EXTRA_UNLOCK_ID),
        "a continued campaign does not derive the one-credit unlock"
    );
}

/// Runs all focused profile contract cases through the shared kernel harness.
function BladeProfileTestsRun(_state) {
    BladeKernelTestRunCase(_state, "profile defaults and strict schema", function() {
        var _profile = BladeProfileCreateDefault();
        BladeKernelTestAssertTrue(
            BladeProfileIsCanonical(_profile), "default profile is canonical"
        );
        BladeKernelTestAssertEqual(
            BladeProfileFormatId(), "blade.profile", "profile format ID"
        );
        BladeKernelTestAssertEqual(
            BladeProfileFilename(), "blade-profile.json", "profile filename"
        );
        BladeKernelTestAssertEqual(
            BladeProfileSerializerParse("{not-json").kind,
            BladeProfileParseKind.Corrupt,
            "malformed profile is corrupt"
        );
        var _future = BladeProfileSerializerParse(json_stringify({
            format_id: BladeProfileFormatId(),
            schema_version: BladeProfileSchemaVersion() + 1,
        }));
        BladeKernelTestAssertEqual(
            _future.kind,
            BladeProfileParseKind.Future,
            "future profile is not normalized"
        );
    });

    BladeKernelTestRunCase(_state, "profile serializer preserves independent flags", function() {
        _BladeProfileTestRoundTrip();
    });

    BladeKernelTestRunCase(_state, "profile derives only a qualifying campaign unlock", function() {
        _BladeProfileTestDerivedUnlock();
    });

    BladeKernelTestRunCase(_state, "authoritative Stage 1 result creates one arcade record", function() {
        var _applied = BladeProfileApplyRunResult(
            BladeProfileCreateDefault(),
            _BladeProfileTestRunResult()
        );
        BladeKernelTestAssertTrue(_applied.ok, "completed live result applies");
        BladeKernelTestAssertEqual(
            array_length(_applied.profile.records), 1, "one record is stored"
        );
        BladeKernelTestAssertEqual(
            _applied.profile.records[0].score,
            123456,
            "record keeps authoritative score"
        );
        BladeKernelTestAssertEqual(
            _applied.profile.records[0].ship_id,
            "ship.ciela",
            "record keeps machine ship ID"
        );
        BladeKernelTestAssertEqual(
            _applied.profile.records[0].difficulty_id,
            BLADE_DIFFICULTY_NORMAL_ID,
            "record keeps machine difficulty ID"
        );
        var _duplicate = BladeProfileApplyRunResult(
            _applied.profile,
            _BladeProfileTestRunResult()
        );
        BladeKernelTestAssertFalse(_duplicate.ok, "same result is rejected twice");
        BladeKernelTestAssertEqual(
            _duplicate.code,
            "profile.apply.duplicate_result",
            "duplicate has an explicit diagnostic"
        );
    });

    BladeKernelTestRunCase(_state, "replay and administrative outcomes cannot mutate profile", function() {
        var _profile = BladeProfileCreateDefault();
        var _live_result = _BladeProfileTestRunResult();
        var _replay = BladeProfileApplyRunResult(_profile, _live_result, "replay");
        BladeKernelTestAssertFalse(_replay.ok, "replay source is rejected");
        var _game_over = BladeStage1RunResultCreate();
        BladeStage1RunResultOfferContinue(_game_over);
        BladeStage1RunResultRecordGameOver(_game_over, undefined, 20);
        var _rejected = BladeProfileApplyRunResult(_profile, _game_over);
        BladeKernelTestAssertFalse(_rejected.ok, "incomplete Game Over is rejected");
        BladeKernelTestAssertEqual(
            array_length(_profile.records), 0,
            "rejected outcomes do not create records"
        );
    });

    BladeKernelTestRunCase(_state, "profile service keeps missing and corrupt data separate from config", function() {
        var _storage = _BladeProfileTestMemoryStorageCreate();
        var _service = BladeProfileServiceCreate(_storage, "profile-test.json");
        var _missing = BladeProfileServiceLoad(_service);
        BladeKernelTestAssertTrue(_missing.ok, "missing profile loads defaults");
        BladeKernelTestAssertFalse(
            _storage.exists("blade-config.json"),
            "profile load does not create or mutate config"
        );
        var _saved = BladeProfileServiceSave(_service, BladeProfileCreateDefault());
        BladeKernelTestAssertTrue(_saved.ok, "profile default can be saved");
        var _reloaded = BladeProfileServiceCreate(_storage, "profile-test.json");
        BladeKernelTestAssertTrue(
            BladeProfileServiceLoad(_reloaded).ok,
            "saved profile reloads"
        );
        var _corrupt_storage = _BladeProfileTestMemoryStorageCreate();
        variable_struct_set(
            _corrupt_storage.context.files,
            "profile-test.json",
            "{broken"
        );
        var _corrupt_service = BladeProfileServiceCreate(
            _corrupt_storage, "profile-test.json"
        );
        var _corrupt = BladeProfileServiceLoad(_corrupt_service);
        BladeKernelTestAssertFalse(_corrupt.ok, "corrupt profile fails clearly");
        var _before = variable_struct_get(
            _corrupt_storage.context.files, "profile-test.json"
        );
        var _blocked_save = BladeProfileServiceSave(
            _corrupt_service, BladeProfileCreateDefault()
        );
        BladeKernelTestAssertFalse(
            _blocked_save.ok, "corrupt profile cannot be silently replaced"
        );
        BladeKernelTestAssertEqual(
            variable_struct_get(_corrupt_storage.context.files, "profile-test.json"),
            _before,
            "corrupt bytes remain available for recovery"
        );
    });

    BladeKernelTestRunCase(_state, "profile replacement rolls back failed writes", function() {
        var _storage = _BladeProfileTestMemoryStorageCreate();
        var _service = BladeProfileServiceCreate(_storage, "profile-test.json");
        BladeProfileServiceLoad(_service);
        BladeKernelTestAssertTrue(
            BladeProfileServiceSave(_service, BladeProfileCreateDefault()).ok,
            "initial profile save"
        );
        var _candidate = BladeProfileCreateDefault();
        BladeProfileGrantAchievement(_candidate, "achievement.pending");
        _storage.context.fail_write_call = _storage.context.write_calls + 1;
        var _failed = BladeProfileServiceSave(_service, _candidate);
        BladeKernelTestAssertFalse(_failed.ok, "injected profile write fails");
        BladeKernelTestAssertFalse(
            BladeProfileHasFlag(
                BladeProfileServiceSnapshot(_service),
                BladeProfileFlagKind.Achievement,
                "achievement.pending"
            ),
            "failed write does not publish candidate"
        );
    });
}
