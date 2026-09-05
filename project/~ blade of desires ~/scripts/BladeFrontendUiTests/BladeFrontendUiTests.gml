/// @description Deterministic checks for the reusable front-end panel contract.

/// @func BladeFrontendUiTestsRun(state)
/// Registers nine-slice geometry checks on the shared kernel runner.
function BladeFrontendUiTestsRun(_state) {
    BladeKernelTestRunCase(_state, "front-end UI nine-slice contract", function() {
        var _contract = BladeFrontendUiNineSliceContract();
        BladeKernelTestAssertEqual(
            _contract.frame_count,
            1,
            "one shared panel frame is present"
        );
        BladeKernelTestAssertEqual(
            _contract.frame_width,
            _contract.frame_height,
            "panel frames are square"
        );
        BladeKernelTestAssertEqual(
            _contract.guide_left,
            _contract.guide_right,
            "horizontal guides match"
        );
        BladeKernelTestAssertEqual(
            _contract.guide_top,
            _contract.guide_bottom,
            "vertical guides match"
        );
        BladeKernelTestAssertTrue(
            _contract.guide_left * 2 < _contract.frame_width,
            "center region remains available"
        );
    });
    BladeKernelTestRunCase(_state, "front-end UI asset loads and releases", function() {
        var _ui = BladeFrontendUiCreate();
        BladeKernelTestAssertTrue(
            _ui.ready,
            "packaged front-end UI sheet creates a runtime sprite"
        );
        BladeFrontendUiDestroy(_ui);
        BladeKernelTestAssertTrue(
            !_ui.ready,
            "front-end UI cleanup releases its runtime sprite"
        );
    });
    return _state;
}
