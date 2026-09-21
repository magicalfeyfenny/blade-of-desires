/// @description Deterministic tests for front-end pages, options, and input identity.

/// Proves the title flow has stable choices and one permitted start transition.
function _BladeFrontendTestMainFlow() {
    var _state = BladeFrontendStateCreate(BladeConfigCreateDefault());
    BladeKernelTestAssertEqual(
        _state.page, BladeFrontendPage.Main, "front-end starts on main page"
    );
    BladeKernelTestAssertEqual(
        BladeFrontendPageItemCount(BladeFrontendPage.Main),
        5,
        "main page has start/replay/options/profile/quit"
    );
    var _start = BladeFrontendStateActivate(_state);
    BladeKernelTestAssertEqual(
        _start.action, BladeFrontendAction.StartGame,
        "first main choice starts a game"
    );
    BladeKernelTestAssertTrue(
        BladeFrontendStateConsumeStart(_state), "first start transition is accepted"
    );
    BladeKernelTestAssertFalse(
        BladeFrontendStateConsumeStart(_state), "repeated start transition is ignored"
    );

    var _options_state = BladeFrontendStateCreate(BladeConfigCreateDefault());
    BladeFrontendStateMove(_options_state, 1);
    BladeFrontendStateMove(_options_state, 1);
    BladeFrontendStateActivate(_options_state);
    BladeKernelTestAssertEqual(
        _options_state.page, BladeFrontendPage.Options,
        "options choice opens the options page"
    );
    BladeKernelTestAssertEqual(
        BladeFrontendPageItemCount(BladeFrontendPage.Options),
        8,
        "options page exposes both device remap entries"
    );
    BladeFrontendStateBack(_options_state);
    BladeKernelTestAssertEqual(
        _options_state.page, BladeFrontendPage.Main,
        "cancel returns options to the main page"
    );
}

/// Proves the profile page is read-only and returns through the shared menu path.
function _BladeFrontendTestProfileNavigation() {
    var _profile = BladeProfileCreateDefault();
    BladeProfileGrantUnlock(_profile, BLADE_PROFILE_EXTRA_UNLOCK_ID);
    var _state = BladeFrontendStateCreate(
        BladeConfigCreateDefault(),
        undefined,
        {
            ok: true,
            status: BladeProfileLoadStatus.Loaded,
            code: "profile.load.current",
            profile: _profile,
        }
    );
    BladeFrontendStateMove(_state, 1);
    BladeFrontendStateMove(_state, 1);
    BladeFrontendStateMove(_state, 1);
    var _open = BladeFrontendStateActivate(_state);
    BladeKernelTestAssertEqual(
        _state.page, BladeFrontendPage.Profile,
        "profile choice opens the profile page"
    );
    BladeKernelTestAssertEqual(
        BladeFrontendPageItemCount(BladeFrontendPage.Profile),
        1,
        "profile page has one read-only selection"
    );
    BladeKernelTestAssertEqual(
        _state.profile_view.unlock_entries[0].granted,
        true,
        "profile page receives the current profile projection"
    );
    BladeKernelTestAssertEqual(
        _open.action, BladeFrontendAction.None,
        "profile transition does not start gameplay"
    );
    var _confirm = BladeFrontendStateActivate(_state);
    BladeKernelTestAssertEqual(
        _confirm.action, BladeFrontendAction.None,
        "profile confirm remains read-only"
    );
    BladeFrontendStateBack(_state);
    BladeKernelTestAssertEqual(
        _state.page, BladeFrontendPage.Main,
        "profile cancel returns to the main page"
    );
}

/// Proves the catalog is a safe front-end page even when no replay exists.
function _BladeFrontendTestReplayCatalogNavigation() {
    var _state = BladeFrontendStateCreate(BladeConfigCreateDefault());
    BladeFrontendStateMove(_state, 1);
    var _open = BladeFrontendStateActivate(_state);
    BladeKernelTestAssertEqual(
        _state.page, BladeFrontendPage.ReplayCatalog,
        "replay choice opens the catalog page"
    );
    BladeKernelTestAssertEqual(
        BladeFrontendPageItemCount(
            BladeFrontendPage.ReplayCatalog, _state.replay_view
        ),
        1,
        "empty catalog exposes one safe placeholder selection"
    );
    BladeKernelTestAssertEqual(
        _open.action, BladeFrontendAction.None,
        "catalog transition does not start gameplay"
    );
    var _empty = BladeFrontendStateActivate(_state);
    BladeKernelTestAssertEqual(
        _empty.action, BladeFrontendAction.None,
        "empty catalog confirm remains on the catalog page"
    );
    BladeKernelTestAssertEqual(
        _state.message, "REPLAY CATALOG EMPTY",
        "empty catalog gives an explicit player-facing state"
    );
    BladeFrontendStateBack(_state);
    BladeKernelTestAssertEqual(
        _state.page, BladeFrontendPage.Main,
        "catalog cancel returns to the main page"
    );
}

/// Proves bounded option edits are detached, readable, and independent.
function _BladeFrontendTestOptionCandidates() {
    var _config = BladeConfigCreateDefault();
    var _fullscreen = BladeFrontendOptionCandidate(_config, 0, 1);
    BladeKernelTestAssertTrue(
        _fullscreen.display.fullscreen, "fullscreen option toggles on"
    );
    BladeKernelTestAssertFalse(
        _config.display.fullscreen, "fullscreen candidate does not mutate source"
    );

    var _scale = _config;
    for (var _scale_up = 0; _scale_up < 20; ++_scale_up) {
        _scale = BladeFrontendOptionCandidate(_scale, 1, 1);
    }
    BladeKernelTestAssertEqual(_scale.display.window_scale, 6, "scale clamps high");
    for (var _scale_down = 0; _scale_down < 20; ++_scale_down) {
        _scale = BladeFrontendOptionCandidate(_scale, 1, -1);
    }
    BladeKernelTestAssertEqual(_scale.display.window_scale, 1, "scale clamps low");

    _config.audio.master_gain_percent = 40;
    var _master = BladeFrontendOptionCandidate(_config, 2, 1);
    BladeKernelTestAssertEqual(_master.audio.master_gain_percent, 50, "master moves by ten");
    _config.audio.music_gain_percent = 10;
    var _music = BladeFrontendOptionCandidate(_config, 3, -1);
    BladeKernelTestAssertEqual(_music.audio.music_gain_percent, 0, "music clamps low");
    _config.audio.sfx_gain_percent = 90;
    var _sfx = BladeFrontendOptionCandidate(_config, 4, 1);
    BladeKernelTestAssertEqual(_sfx.audio.sfx_gain_percent, 100, "sfx clamps high");
}

/// Proves valid rebinding uses stable IDs and invalid codes never replace them.
function _BladeFrontendTestBindingCandidates() {
    var _config = BladeConfigCreateDefault();
    var _accepted = BladeFrontendBindingCandidate(
        _config, "input.fire", ord("C")
    );
    BladeKernelTestAssertTrue(_accepted.accepted, "supported key is accepted");
    BladeKernelTestAssertEqual(
        variable_struct_get(_accepted.config.bindings.keyboard, "input.fire"),
        ord("C"),
        "accepted key is stored by stable ID"
    );
    BladeKernelTestAssertEqual(
        variable_struct_get(_config.bindings.keyboard, "input.fire"),
        ord("Z"),
        "binding candidate does not mutate source"
    );

    var _rejected = BladeFrontendBindingCandidate(
        _config, "input.fire", -500
    );
    BladeKernelTestAssertFalse(_rejected.accepted, "unsupported key is rejected");
    BladeKernelTestAssertEqual(
        variable_struct_get(_rejected.config.bindings.keyboard, "input.fire"),
        ord("Z"),
        "rejected key preserves prior binding"
    );
    BladeKernelTestAssertThrows(
        method({}, function() {
            BladeFrontendBindingCandidate(
                BladeConfigCreateDefault(), "input.unknown", ord("Q")
            );
        }),
        "unknown stable ID",
        "unknown binding cannot enter options"
    );

    var _gamepad_accepted = BladeFrontendBindingCandidate(
        _config,
        "input.fire",
        gp_face3,
        BladePromptDevice.Gamepad
    );
    BladeKernelTestAssertTrue(
        _gamepad_accepted.accepted,
        "supported gamepad button is accepted"
    );
    BladeKernelTestAssertEqual(
        variable_struct_get(_gamepad_accepted.config.bindings.gamepad, "input.fire"),
        gp_face3,
        "accepted gamepad button is stored by stable ID"
    );
    BladeKernelTestAssertEqual(
        variable_struct_get(_config.bindings.gamepad, "input.fire"),
        gp_face1,
        "gamepad candidate does not mutate source"
    );

    var _gamepad_rejected = BladeFrontendBindingCandidate(
        _config,
        "input.fire",
        -500,
        BladePromptDevice.Gamepad
    );
    BladeKernelTestAssertFalse(
        _gamepad_rejected.accepted,
        "unsupported gamepad button is rejected"
    );
    BladeKernelTestAssertEqual(
        variable_struct_get(_gamepad_rejected.config.bindings.gamepad, "input.fire"),
        gp_face1,
        "rejected gamepad button preserves prior binding"
    );
}

/// Proves keyboard-page entry, modal cancellation, and return navigation.
function _BladeFrontendTestBindingNavigation() {
    var _state = BladeFrontendStateCreate(BladeConfigCreateDefault());
    BladeFrontendStateMove(_state, 1);
    BladeFrontendStateMove(_state, 1);
    BladeFrontendStateActivate(_state);
    for (var _index = 0; _index < 5; ++_index) {
        BladeFrontendStateMove(_state, 1);
    }
    var _open = BladeFrontendStateActivate(_state);
    BladeKernelTestAssertEqual(
        _state.page, BladeFrontendPage.Bindings,
        "remap option opens binding page"
    );
    BladeKernelTestAssertEqual(
        BladeFrontendPageItemCount(BladeFrontendPage.Bindings),
        10,
        "binding page exposes the full semantic registry"
    );
    BladeKernelTestAssertEqual(
        _state.binding_device,
        BladePromptDevice.KeyboardMouse,
        "keyboard remap page selects the keyboard device"
    );
    BladeKernelTestAssertEqual(
        _open.action, BladeFrontendAction.None,
        "binding page transition does not start gameplay"
    );
    var _listen = BladeFrontendStateActivate(_state);
    BladeKernelTestAssertTrue(_listen.listening, "binding confirm enters listen mode");
    BladeFrontendStateBack(_state);
    BladeKernelTestAssertFalse(_state.listening, "cancel closes listen mode first");
    BladeFrontendStateBack(_state);
    BladeKernelTestAssertEqual(
        _state.page, BladeFrontendPage.Options,
        "second cancel returns to options"
    );

    var _gamepad_state = BladeFrontendStateCreate(BladeConfigCreateDefault());
    BladeFrontendStateMove(_gamepad_state, 1);
    BladeFrontendStateMove(_gamepad_state, 1);
    BladeFrontendStateActivate(_gamepad_state);
    for (var _gamepad_index = 0; _gamepad_index < 6; ++_gamepad_index) {
        BladeFrontendStateMove(_gamepad_state, 1);
    }
    var _gamepad_open = BladeFrontendStateActivate(_gamepad_state);
    BladeKernelTestAssertEqual(
        _gamepad_state.page,
        BladeFrontendPage.Bindings,
        "gamepad remap option opens the binding page"
    );
    BladeKernelTestAssertEqual(
        _gamepad_state.binding_device,
        BladePromptDevice.Gamepad,
        "gamepad remap page selects the gamepad device"
    );
    BladeKernelTestAssertEqual(
        _gamepad_open.action,
        BladeFrontendAction.None,
        "gamepad binding page transition stays in options"
    );
}

/// @func BladeFrontendStateTestsRun(state)
/// Registers front-end state and configuration cases on the kernel runner.
function BladeFrontendStateTestsRun(_state) {
    BladeKernelTestRunCase(_state, "front-end title flow and one-shot start", function() {
        _BladeFrontendTestMainFlow();
    });
    BladeKernelTestRunCase(_state, "front-end profile navigation is read-only", function() {
        _BladeFrontendTestProfileNavigation();
    });
    BladeKernelTestRunCase(_state, "front-end replay catalog navigation is safe", function() {
        _BladeFrontendTestReplayCatalogNavigation();
    });
    BladeKernelTestRunCase(_state, "front-end option candidates stay bounded", function() {
        _BladeFrontendTestOptionCandidates();
    });
    BladeKernelTestRunCase(_state, "front-end binding candidates use stable IDs", function() {
        _BladeFrontendTestBindingCandidates();
    });
    BladeKernelTestRunCase(_state, "front-end binding navigation is modal", function() {
        _BladeFrontendTestBindingNavigation();
    });
    return _state;
}
