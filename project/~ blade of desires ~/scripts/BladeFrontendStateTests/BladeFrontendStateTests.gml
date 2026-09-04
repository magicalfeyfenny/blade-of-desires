/// @description Deterministic tests for front-end pages, options, and input identity.

/// Proves the title flow has stable choices and one permitted start transition.
function _BladeFrontendTestMainFlow() {
    var _state = BladeFrontendStateCreate(BladeConfigCreateDefault());
    BladeKernelTestAssertEqual(
        _state.page, BladeFrontendPage.Main, "front-end starts on main page"
    );
    BladeKernelTestAssertEqual(
        BladeFrontendPageItemCount(BladeFrontendPage.Main),
        3,
        "main page has start/options/quit"
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
    BladeFrontendStateActivate(_options_state);
    BladeKernelTestAssertEqual(
        _options_state.page, BladeFrontendPage.Options,
        "options choice opens the options page"
    );
    BladeFrontendStateBack(_options_state);
    BladeKernelTestAssertEqual(
        _options_state.page, BladeFrontendPage.Main,
        "cancel returns options to the main page"
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
}

/// Proves keyboard-page entry, modal cancellation, and return navigation.
function _BladeFrontendTestBindingNavigation() {
    var _state = BladeFrontendStateCreate(BladeConfigCreateDefault());
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
}

/// @func BladeFrontendStateTestsRun(state)
/// Registers front-end state and configuration cases on the kernel runner.
function BladeFrontendStateTestsRun(_state) {
    BladeKernelTestRunCase(_state, "front-end title flow and one-shot start", function() {
        _BladeFrontendTestMainFlow();
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
