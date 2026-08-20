/// Project-owned characterization for the stable input-binding identity seam.

/// Checks all ten IDs, registry version, uniqueness, and filtered canonical order.
function _BladeInputBindingTestCanonicalOrder() {
    var _expected_ids = [
        "input.move_up",
        "input.move_down",
        "input.move_left",
        "input.move_right",
        "input.fire",
        "input.bomb",
        "input.focus",
        "input.pause",
        "input.confirm",
        "input.cancel",
    ];
    var _records = BladeInputBindingRecords();

    BladeKernelTestAssertEqual(
        BladeInputBindingSchemaVersion(),
        1,
        "binding registry schema version"
    );
    BladeKernelTestAssertEqual(
        array_length(_records),
        array_length(_expected_ids),
        "binding registry contains exactly ten records"
    );

    for (var _index = 0; _index < array_length(_expected_ids); ++_index) {
        BladeKernelTestAssertEqual(
            _records[_index].stable_id,
            _expected_ids[_index],
            "canonical binding ID " + string(_index)
        );
        BladeKernelTestAssertEqual(
            _records[_index].schema_version,
            1,
            "binding record schema version " + string(_index)
        );
        for (var _earlier = 0; _earlier < _index; ++_earlier) {
            BladeKernelTestAssertNotEqual(
                _records[_index].stable_id,
                _records[_earlier].stable_id,
                "binding IDs remain unique"
            );
        }
    }

    var _filtered = BladeInputBindingRecords([
        "input.cancel",
        "input.move_up",
        "input.fire",
    ]);
    BladeKernelTestAssertEqual(array_length(_filtered), 3, "filtered binding count");
    BladeKernelTestAssertEqual(
        _filtered[0].stable_id,
        "input.move_up",
        "filtered movement remains first"
    );
    BladeKernelTestAssertEqual(
        _filtered[1].stable_id,
        "input.fire",
        "filtered action follows canonical order"
    );
    BladeKernelTestAssertEqual(
        _filtered[2].stable_id,
        "input.cancel",
        "filtered cancel remains last"
    );
}

/// Maps every movement ID to its exact raw-state axis contribution without action bits.
function _BladeInputBindingTestMovementMappings() {
    var _fixtures = [
        { id: "input.move_up", axis: "move_y", value: int64(-1024) },
        { id: "input.move_down", axis: "move_y", value: int64(1024) },
        { id: "input.move_left", axis: "move_x", value: int64(-1024) },
        { id: "input.move_right", axis: "move_x", value: int64(1024) },
    ];

    for (var _index = 0; _index < array_length(_fixtures); ++_index) {
        var _fixture = _fixtures[_index];
        var _record = BladeInputBindingRecord(_fixture.id);
        BladeKernelTestAssertEqual(
            _record.kind,
            BladeInputBindingKind.Movement,
            _fixture.id + " movement kind"
        );
        BladeKernelTestAssertEqual(
            _record.movement_axis,
            _fixture.axis,
            _fixture.id + " semantic axis"
        );
        BladeKernelTestAssertEqual(
            _record.movement_value,
            _fixture.value,
            _fixture.id + " axis contribution"
        );
        BladeKernelTestAssertFalse(
            variable_struct_exists(_record, "action_bit"),
            _fixture.id + " invents no action-bit field"
        );

        var _move_x = int64(0);
        var _move_y = int64(0);
        if (_record.movement_axis == "move_x") {
            _move_x = _record.movement_value;
        } else {
            _move_y = _record.movement_value;
        }
        var _raw = BladeInputRawStateCreate(_move_x, _move_y, 0);
        BladeKernelTestAssertEqual(_raw.move_x, _move_x, _fixture.id + " raw move_x");
        BladeKernelTestAssertEqual(_raw.move_y, _move_y, _fixture.id + " raw move_y");
        BladeKernelTestAssertEqual(
            _raw.held_actions,
            int64(0),
            _fixture.id + " leaves held actions clear"
        );
    }
}

/// Maps every action ID one-to-one to the six unchanged BladeInputAction values.
function _BladeInputBindingTestActionMappings() {
    var _fixtures = [
        { id: "input.fire", bit: BladeInputAction.Fire, value: int64(1) },
        { id: "input.bomb", bit: BladeInputAction.Bomb, value: int64(2) },
        { id: "input.focus", bit: BladeInputAction.Focus, value: int64(4) },
        { id: "input.pause", bit: BladeInputAction.Pause, value: int64(8) },
        { id: "input.confirm", bit: BladeInputAction.Confirm, value: int64(16) },
        { id: "input.cancel", bit: BladeInputAction.Cancel, value: int64(32) },
    ];

    for (var _index = 0; _index < array_length(_fixtures); ++_index) {
        var _fixture = _fixtures[_index];
        var _record = BladeInputBindingRecord(_fixture.id);
        BladeKernelTestAssertEqual(
            int64(_fixture.bit),
            _fixture.value,
            _fixture.id + " enum bit remains unchanged"
        );
        BladeKernelTestAssertEqual(
            _record.kind,
            BladeInputBindingKind.Action,
            _fixture.id + " action kind"
        );
        BladeKernelTestAssertFalse(
            variable_struct_exists(_record, "movement_axis"),
            _fixture.id + " has no movement-axis field"
        );
        BladeKernelTestAssertFalse(
            variable_struct_exists(_record, "movement_value"),
            _fixture.id + " has no movement-value field"
        );
        BladeKernelTestAssertEqual(
            _record.action_bit,
            _fixture.value,
            _fixture.id + " mapped action bit"
        );

        var _raw = BladeInputRawStateCreate(0, 0, _record.action_bit);
        BladeKernelTestAssertEqual(_raw.move_x, int64(0), _fixture.id + " raw move_x");
        BladeKernelTestAssertEqual(_raw.move_y, int64(0), _fixture.id + " raw move_y");
        BladeKernelTestAssertEqual(
            _raw.held_actions,
            _fixture.value,
            _fixture.id + " raw held action"
        );
    }

    BladeKernelTestAssertEqual(
        int64(BladeInputAction.All),
        int64(63),
        "complete action mask remains unchanged"
    );
}

/// Proves the registry has four axis records and six disjoint action-bit records.
function _BladeInputBindingTestMovementActionSeparation() {
    var _records = BladeInputBindingRecords();
    var _movement_count = 0;
    var _action_count = 0;
    var _action_mask = int64(0);

    for (var _index = 0; _index < array_length(_records); ++_index) {
        var _record = _records[_index];
        if (_record.kind == BladeInputBindingKind.Movement) {
            _movement_count += 1;
            BladeKernelTestAssertNotEqual(
                _record.movement_axis,
                "",
                _record.stable_id + " declares an axis"
            );
            BladeKernelTestAssertFalse(
                variable_struct_exists(_record, "action_bit"),
                _record.stable_id + " remains outside the action mask"
            );
        } else if (_record.kind == BladeInputBindingKind.Action) {
            _action_count += 1;
            BladeKernelTestAssertFalse(
                variable_struct_exists(_record, "movement_axis"),
                _record.stable_id + " remains outside movement axes"
            );
            _action_mask = _action_mask | _record.action_bit;
        } else {
            BladeKernelTestFail(_record.stable_id + " has an unknown binding kind");
        }
    }

    BladeKernelTestAssertEqual(_movement_count, 4, "movement binding count");
    BladeKernelTestAssertEqual(_action_count, 6, "action binding count");
    BladeKernelTestAssertEqual(
        _action_mask,
        int64(BladeInputAction.All),
        "six action records cover only the existing mask"
    );
}

/// Confirms unknown, duplicate, malformed, and non-array lookup requests fail closed.
function _BladeInputBindingTestLookupRejections() {
    BladeKernelTestAssertThrows(
        method({}, function() {
            // Request an ID outside the closed registry.
            BladeInputBindingRecord("input.unknown");
        }),
        "unknown stable ID input.unknown",
        "unknown binding ID"
    );
    BladeKernelTestAssertThrows(
        method({}, function() {
            // Repeat a known ID so query ambiguity is rejected explicitly.
            BladeInputBindingRecords(["input.fire", "input.fire"]);
        }),
        "duplicate stable ID input.fire",
        "duplicate binding ID"
    );
    BladeKernelTestAssertThrows(
        method({}, function() {
            // Supply a numeric element so stable IDs cannot be confused with action bits.
            BladeInputBindingRecords([BladeInputAction.Fire]);
        }),
        "stable IDs must be strings",
        "numeric binding ID"
    );
    BladeKernelTestAssertThrows(
        method({}, function() {
            // Supply one scalar instead of the documented ID array.
            BladeInputBindingRecords("input.fire");
        }),
        "lookup requires an array",
        "scalar binding lookup"
    );
}

/// Mutates list and single-record results, then proves fresh lookups retain registry values.
function _BladeInputBindingTestDetachedRecords() {
    var _records = BladeInputBindingRecords();
    _records[0].schema_version = 99;
    _records[0].stable_id = "input.changed";
    _records[0].movement_axis = "changed";
    _records[0].movement_value = int64(0);
    _records[4] = _records[0];
    array_push(_records, _records[0]);

    var _fresh = BladeInputBindingRecords();
    BladeKernelTestAssertEqual(array_length(_fresh), 10, "fresh registry count");
    BladeKernelTestAssertEqual(_fresh[0].schema_version, 1, "fresh registry version");
    BladeKernelTestAssertEqual(_fresh[0].stable_id, "input.move_up", "fresh first ID");
    BladeKernelTestAssertEqual(_fresh[0].movement_axis, "move_y", "fresh first axis");
    BladeKernelTestAssertEqual(
        _fresh[0].movement_value,
        int64(-1024),
        "fresh first movement value"
    );
    BladeKernelTestAssertEqual(_fresh[4].stable_id, "input.fire", "fresh action ID");

    var _fire = BladeInputBindingRecord("input.fire");
    _fire.stable_id = "input.changed_again";
    _fire.action_bit = int64(0);
    var _fresh_fire = BladeInputBindingRecord("input.fire");
    BladeKernelTestAssertEqual(_fresh_fire.stable_id, "input.fire", "fresh direct ID");
    BladeKernelTestAssertEqual(
        _fresh_fire.action_bit,
        int64(BladeInputAction.Fire),
        "fresh direct action bit"
    );
}

/// @func BladeInputBindingTestsRun(state)
/// Registers stable binding identity cases on the shared project-owned test state.
function BladeInputBindingTestsRun(_state) {
    BladeKernelTestRunCase(_state, "binding ID canonical order and uniqueness", function() {
        // Check the complete and filtered registries inside one reported case.
        _BladeInputBindingTestCanonicalOrder();
    });
    BladeKernelTestRunCase(_state, "movement binding semantic mappings", function() {
        // Exercise all four full-scale digital axis contributions.
        _BladeInputBindingTestMovementMappings();
    });
    BladeKernelTestRunCase(_state, "action binding bit mappings", function() {
        // Exercise all six unchanged action-bit values through raw-state creation.
        _BladeInputBindingTestActionMappings();
    });
    BladeKernelTestRunCase(_state, "movement and action binding separation", function() {
        // Prove axis directions and action bits remain disjoint registry kinds.
        _BladeInputBindingTestMovementActionSeparation();
    });
    BladeKernelTestRunCase(_state, "binding lookup rejects invalid requests", function() {
        // Check unknown, duplicate, malformed, and scalar lookup requests.
        _BladeInputBindingTestLookupRejections();
    });
    BladeKernelTestRunCase(_state, "binding lookup returns detached records", function() {
        // Mutate prior lookup results before verifying fresh registry values.
        _BladeInputBindingTestDetachedRecords();
    });
    return _state;
}
