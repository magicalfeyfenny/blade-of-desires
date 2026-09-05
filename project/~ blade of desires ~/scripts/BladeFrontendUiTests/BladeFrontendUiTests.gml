/// @description Deterministic checks for the reusable front-end panel contract.

/// @func BladeFrontendUiTestsRun(state)
/// Registers nine-slice geometry checks on the shared kernel runner.
function BladeFrontendUiTestsRun(_state) {
    BladeKernelTestRunCase(_state, "front-end UI nine-slice contract", function() {
        var _contract = BladeFrontendUiNineSliceContract();
        BladeKernelTestAssertEqual(
            _contract.frame_count,
            2,
            "base and selected frames are present"
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
    return _state;
}
