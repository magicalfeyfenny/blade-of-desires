/// Project-owned exact assertions for the deterministic-kernel test runner.
/// These assertions deliberately do not depend on GMTL matchers.

function BladeKernelTestStateCreate() {
    return {
        passed: 0,
        failed: 0,
        total: 0,
        failures: [],
    };
}

function BladeKernelTestFail(_message) {
    throw "Blade kernel assertion failed: " + string(_message);
}

function BladeKernelTestAssertTrue(_value, _message) {
    if (_value != true) {
        BladeKernelTestFail(_message);
    }
}

function BladeKernelTestAssertFalse(_value, _message) {
    if (_value != false) {
        BladeKernelTestFail(_message);
    }
}

function BladeKernelTestAssertEqual(_actual, _expected, _message) {
    if (_actual != _expected) {
        BladeKernelTestFail(
            string(_message)
            + " (expected " + string(_expected)
            + ", received " + string(_actual) + ")"
        );
    }
}

function BladeKernelTestAssertNotEqual(_actual, _unexpected, _message) {
    if (_actual == _unexpected) {
        BladeKernelTestFail(
            string(_message) + " (unexpected " + string(_unexpected) + ")"
        );
    }
}

function BladeKernelTestAssertArrayEqual(_actual, _expected, _message) {
    var _actual_length = array_length(_actual);
    var _expected_length = array_length(_expected);

    if (_actual_length != _expected_length) {
        BladeKernelTestFail(
            string(_message)
            + " (expected length " + string(_expected_length)
            + ", received " + string(_actual_length) + ")"
        );
    }

    for (var i = 0; i < _expected_length; i++) {
        if (_actual[i] != _expected[i]) {
            BladeKernelTestFail(
                string(_message)
                + " (index " + string(i)
                + ": expected " + string(_expected[i])
                + ", received " + string(_actual[i]) + ")"
            );
        }
    }
}

function BladeKernelTestAssertThrows(_callback, _message_fragment, _message) {
    var _threw = false;
    var _caught_message = "";

    try {
        _callback();
    } catch (_caught) {
        _threw = true;
        _caught_message = string(_caught);
    }

    if (!_threw) {
        BladeKernelTestFail(string(_message) + " (nothing was thrown)");
    }

    if (string_pos(_message_fragment, _caught_message) <= 0) {
        BladeKernelTestFail(
            string(_message)
            + " (expected diagnostic containing '" + string(_message_fragment)
            + "', received '" + _caught_message + "')"
        );
    }
}

function BladeKernelTestRunCase(_state, _name, _callback) {
    _state.total += 1;

    try {
        _callback();
        _state.passed += 1;
        show_debug_message("BLADE_KERNEL_TEST_CASE: PASS " + _name);
    } catch (_caught) {
        _state.failed += 1;
        var _diagnostic = _name + ": " + string(_caught);
        array_push(_state.failures, _diagnostic);
        show_debug_message("BLADE_KERNEL_TEST_CASE: FAIL " + _diagnostic);
    }
}

function BladeKernelTestFinish(_state) {
    show_debug_message(
        "BLADE_KERNEL_TESTS: "
        + string(_state.passed) + " passed, "
        + string(_state.failed) + " failed, "
        + string(_state.total) + " total"
    );

    var _result = (_state.total > 0) && (_state.failed == 0);
    show_debug_message(
        "BLADE_KERNEL_TEST_RESULT: " + (_result ? "PASS" : "FAIL")
    );
    return _result;
}
