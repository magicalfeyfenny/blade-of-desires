/// @description Deterministic read-only profile projection and identity tests.

function _BladeProfileViewTestProfile() {
    var _profile = BladeProfileCreateDefault();
    BladeProfileRecordClear(
        _profile,
        BLADE_PROFILE_STAGE1_ID,
        "ship.ciela",
        BLADE_DIFFICULTY_NORMAL_ID,
        true
    );
    BladeProfileGrantUnlock(_profile, BLADE_PROFILE_EXTRA_UNLOCK_ID);
    BladeProfileGrantAchievement(_profile, "achievement.first_clear");
    BladeProfileGrantCgFlag(_profile, "cg.intro_scene");
    array_push(_profile.records, {
        run_id: "run:profile-view-test",
        stage_id: BLADE_PROFILE_STAGE1_ID,
        result_id: "result.stage_clear",
        terminal_result_id: "result.run_complete",
        ship_id: "ship.ciela",
        difficulty_id: BLADE_DIFFICULTY_NORMAL_ID,
        score: 123456,
        run_seed: 42,
        continue_used: false,
    });
    return _profile;
}

function _BladeProfileViewTestLoad(_profile) {
    return {
        ok: true,
        status: BladeProfileLoadStatus.Loaded,
        code: "profile.load.current",
        profile: _profile,
    };
}

/// @func BladeProfileViewTestsRun(state)
/// Registers projection cases on the shared kernel runner.
function BladeProfileViewTestsRun(_state) {
    BladeKernelTestRunCase(_state, "profile view maps stable identities", function() {
        var _profile = _BladeProfileViewTestProfile();
        var _view = BladeProfileViewCreate(_BladeProfileViewTestLoad(_profile));
        BladeKernelTestAssertEqual(
            _view.state, BladeProfileViewState.Ready,
            "loaded profile produces a ready view"
        );
        BladeKernelTestAssertEqual(
            _view.clear_entries[0].ship_label, "CIELA",
            "clear ship label comes from ship identity"
        );
        BladeKernelTestAssertEqual(
            _view.clear_entries[0].difficulty_label, "ARCADE",
            "clear difficulty label comes from difficulty identity"
        );
        BladeKernelTestAssertEqual(
            _view.clear_entries[0].status_label, "1CC",
            "clear keeps its no-continue status"
        );
        BladeKernelTestAssertTrue(
            _view.unlock_entries[0].granted,
            "known extra-stage unlock is shown as granted"
        );
        BladeKernelTestAssertEqual(
            _view.achievement_entries[0].label, "FIRST CLEAR",
            "achievement flag is visible"
        );
        BladeKernelTestAssertEqual(
            _view.cg_entries[0].label, "INTRO SCENE",
            "CG flag is visible"
        );
        BladeKernelTestAssertEqual(
            _view.records[0].score, 123456,
            "arcade record keeps its authoritative score"
        );
    });

    BladeKernelTestRunCase(_state, "profile view exposes locked and empty states", function() {
        var _view = BladeProfileViewCreate();
        BladeKernelTestAssertEqual(
            _view.state, BladeProfileViewState.Ready,
            "missing profile uses a valid empty view"
        );
        BladeKernelTestAssertFalse(
            _view.unlock_entries[0].granted,
            "extra-stage unlock is explicitly locked by default"
        );
        BladeKernelTestAssertEqual(
            array_length(_view.clear_entries), 0,
            "empty profile has no clear rows"
        );
        BladeKernelTestAssertEqual(
            array_length(_view.records), 0,
            "empty profile has no record rows"
        );
    });

    BladeKernelTestRunCase(_state, "profile view preserves unavailable data state", function() {
        var _unavailable = BladeProfileViewCreate({
            ok: false,
            status: BladeProfileLoadStatus.Corrupt,
            code: "profile.parse.invalid_shape",
            profile: BladeProfileCreateDefault(),
        });
        BladeKernelTestAssertEqual(
            _unavailable.state, BladeProfileViewState.Unavailable,
            "corrupt profile is not presented as an empty profile"
        );
        BladeKernelTestAssertEqual(
            BladeProfileViewStatusLabel(_unavailable.status),
            "CORRUPT PROFILE",
            "unavailable state identifies corrupt profile data"
        );
        BladeKernelTestAssertEqual(
            array_length(_unavailable.records), 0,
            "unavailable profile exposes no fabricated records"
        );
    });

    BladeKernelTestRunCase(_state, "profile view is detached from persistence data", function() {
        var _profile = _BladeProfileViewTestProfile();
        var _before = BladeProfileSerializerStringify(_profile);
        var _view = BladeProfileViewCreate(_BladeProfileViewTestLoad(_profile));
        _view.clear_entries[0].ship_label = "CHANGED IN VIEW";
        _view.records[0].score = 0;
        BladeKernelTestAssertEqual(
            BladeProfileSerializerStringify(_profile),
            _before,
            "editing the view cannot mutate the stored profile snapshot"
        );
    });

    return _state;
}
