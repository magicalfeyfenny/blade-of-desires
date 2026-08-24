/// Project-owned tests for product-plane gates, swept hits, and cancellation pairs.

/// Returns the decoded gameplay-plane object copied from the validated product contract.
function _BladeCombatGeometryTestsPlaneSource() {
    return {
        x_min: 185,
        x_max_exclusive: 455,
        y_min: 0,
        y_max_exclusive: 360,
        width: 270,
        height: 360,
        containment: "The plane is half-open.",
        anchor_containment: "point_inside_half_open_plane",
        hurtbox_containment: "fully_contained_in_half_open_plane",
        coordinate_grid: "binary_fixed_1_1024_logical_pixel",
        right_bottom_clamp: "exclusive_max_minus_one_grid_step",
    };
}

/// Creates the cancellation-facing projectile fields used by the pure pair tests.
function _BladeCombatGeometryTestsProjectile(
    _id, _faction, _policy, _power, _penetration
) {
    return {
        projectile_id: _id,
        faction: _faction,
        cancellation_policy: _policy,
        cancellation_power: _power,
        penetration_remaining: _penetration,
    };
}

/// Encodes a normalized cancellation result so reversed arguments compare byte-for-byte.
function _BladeCombatGeometryTestsCancellationCanonical(_result) {
    return BladeCanonicalRecord("CANCEL1", [
        _result.interacted ? "1" : "0",
        _result.equal_power ? "1" : "0",
        _result.reason,
        _result.first.projectile_id,
        _result.first.cancelled ? "1" : "0",
        string(_result.first.penetration_before),
        string(_result.first.penetration_after),
        string(_result.first.penetration_consumed),
        _result.second.projectile_id,
        _result.second.cancelled ? "1" : "0",
        string(_result.second.penetration_before),
        string(_result.second.penetration_after),
        string(_result.second.penetration_consumed),
    ]);
}

/// Registers authoritative plane, swept-discovery, ordering, and symmetric-pair cases.
function BladeCombatGeometryTestsRun(_state) {
    BladeKernelTestRunCase(_state, "combat plane derives exact contract edges", function() {
        var _plane = BladeCombatPlaneCreate(_BladeCombatGeometryTestsPlaneSource());
        var _copy = BladeCombatPlaneCopy(_plane);
        BladeKernelTestAssertEqual(_copy.left_q10, int64(189440), "left q10 edge");
        BladeKernelTestAssertEqual(
            _copy.right_q10_exclusive, int64(465920), "right q10 edge"
        );
        BladeKernelTestAssertEqual(_copy.top_q10, int64(0), "top q10 edge");
        BladeKernelTestAssertEqual(
            _copy.bottom_q10_exclusive, int64(368640), "bottom q10 edge"
        );
        _copy.left_q10 = 0;
        BladeKernelTestAssertEqual(
            BladeCombatPlaneCopy(_plane).left_q10,
            int64(189440),
            "plane copy is detached"
        );
    });

    BladeKernelTestRunCase(_state, "combat plane applies half-open point and hurtbox rules", function() {
        var _plane = BladeCombatPlaneCreate(_BladeCombatGeometryTestsPlaneSource());
        BladeKernelTestAssertTrue(
            BladeCombatPlaneContainsPoint(_plane, 189440, 0), "minimum point included"
        );
        BladeKernelTestAssertTrue(
            BladeCombatPlaneContainsPoint(_plane, 465919, 368639),
            "maximum anchor included"
        );
        BladeKernelTestAssertFalse(
            BladeCombatPlaneContainsPoint(_plane, 465920, 100), "right edge excluded"
        );
        BladeKernelTestAssertFalse(
            BladeCombatPlaneContainsPoint(_plane, 200000, 368640), "bottom edge excluded"
        );
        BladeKernelTestAssertTrue(
            BladeCombatPlaneContainsHurtbox(
                _plane, BladeCombatAabbCreate(189440, 0, 465920, 368640)
            ),
            "full plane hurtbox included"
        );
        BladeKernelTestAssertFalse(
            BladeCombatPlaneContainsHurtbox(
                _plane, BladeCombatAabbCreate(189439, 0, 465920, 368640)
            ),
            "partially outside hurtbox rejected"
        );
        BladeKernelTestAssertThrows(function() {
            BladeCombatAabbCreate(1, 1, 1, 2);
        }, "positive half-open", "zero-width hurtbox rejected");
    });

    BladeKernelTestRunCase(_state, "emission gate recalculates every transition", function() {
        var _plane = BladeCombatPlaneCreate(_BladeCombatGeometryTestsPlaneSource());
        var _x_values = [100000, 200000, 500000, 300000];
        var _allowed = [];
        for (var _index = 0; _index < array_length(_x_values); ++_index) {
            array_push(_allowed, BladeCombatEmissionGateAllows(
                _plane,
                BladeCombatGateKind.Point,
                { x_q10: _x_values[_index], y_q10: 1000 }
            ));
        }
        BladeKernelTestAssertArrayEqual(
            _allowed, [false, true, false, true],
            "outside-inside-outside-inside attempts are independent"
        );
        BladeKernelTestAssertTrue(
            BladeCombatEmissionGateAllows(
                _plane,
                BladeCombatGateKind.Hurtbox,
                BladeCombatAabbCreate(200000, 1000, 201024, 2024)
            ),
            "hurtbox gate uses the same plane"
        );
    });

    BladeKernelTestRunCase(_state, "swept AABB catches a high-speed traversal", function() {
        var _source_before = BladeCombatAabbCreate(0, 0, 1024, 1024);
        var _source_after = BladeCombatAabbCreate(10240, 0, 11264, 1024);
        var _target = BladeCombatAabbCreate(5120, 0, 6144, 1024);
        var _candidate = BladeCombatGeometrySweep(
            "blt:1", "ins:1",
            _source_before, _source_after, _target, _target
        );
        BladeKernelTestAssertFalse(is_undefined(_candidate), "traversal produces a candidate");
        BladeKernelTestAssertTrue(
            _candidate.impact_numerator > 0
                && _candidate.impact_numerator < _candidate.impact_denominator,
            "impact occurs strictly between endpoints"
        );
        var _miss = BladeCombatGeometrySweep(
            "blt:1", "ins:1",
            _source_before, _source_after,
            BladeCombatAabbCreate(5120, 4096, 6144, 5120),
            BladeCombatAabbCreate(5120, 4096, 6144, 5120)
        );
        BladeKernelTestAssertTrue(is_undefined(_miss), "separate axis remains a miss");
    });

    BladeKernelTestRunCase(_state, "hit candidates sort by exact time and numeric IDs", function() {
        var _sorted = BladeCombatGeometrySortCandidates([
            {
                projectile_id: "blt:10", target_id: "ins:2",
                impact_numerator: 1, impact_denominator: 2,
            },
            {
                projectile_id: "blt:2", target_id: "ins:10",
                impact_numerator: 1, impact_denominator: 2,
            },
            {
                projectile_id: "blt:1", target_id: "ins:1",
                impact_numerator: 1, impact_denominator: 3,
            },
        ]);
        BladeKernelTestAssertEqual(_sorted[0].projectile_id, "blt:1", "earliest time first");
        BladeKernelTestAssertEqual(_sorted[1].projectile_id, "blt:2", "numeric ID two");
        BladeKernelTestAssertEqual(_sorted[2].projectile_id, "blt:10", "numeric ID ten");
    });

    BladeKernelTestRunCase(_state, "projectile cancellation is symmetric and explicit", function() {
        var _strong = _BladeCombatGeometryTestsProjectile(
            "blt:10", BladeCombatFaction.Player,
            BladeCombatCancellationPolicy.Symmetric, 9, 1
        );
        var _weak = _BladeCombatGeometryTestsProjectile(
            "blt:2", BladeCombatFaction.Enemy,
            BladeCombatCancellationPolicy.Symmetric, 4, 5
        );
        var _forward = BladeCombatCancellationResolve(_strong, _weak);
        var _reverse = BladeCombatCancellationResolve(_weak, _strong);
        BladeKernelTestAssertEqual(
            _BladeCombatGeometryTestsCancellationCanonical(_forward),
            _BladeCombatGeometryTestsCancellationCanonical(_reverse),
            "reversing pair input retains normalized output"
        );
        BladeKernelTestAssertTrue(_forward.first.cancelled, "weaker projectile cancelled");
        BladeKernelTestAssertFalse(_forward.second.cancelled, "stronger projectile survives");
        BladeKernelTestAssertEqual(
            _forward.second.penetration_after, int64(0), "one penetration consumed"
        );

        var _equal = BladeCombatCancellationResolve(
            _BladeCombatGeometryTestsProjectile(
                "blt:3", BladeCombatFaction.Player,
                BladeCombatCancellationPolicy.Symmetric, 5, 2
            ),
            _BladeCombatGeometryTestsProjectile(
                "blt:4", BladeCombatFaction.Enemy,
                BladeCombatCancellationPolicy.Symmetric, 5, 7
            )
        );
        BladeKernelTestAssertTrue(_equal.equal_power, "equality rule reported");
        BladeKernelTestAssertTrue(
            _equal.first.cancelled && _equal.second.cancelled,
            "equal power cancels both"
        );
        BladeKernelTestAssertEqual(
            _equal.first.penetration_before,
            _equal.first.penetration_after,
            "equal cancellation consumes no penetration"
        );
    });

    BladeKernelTestRunCase(_state, "cancellation policy and exhausted penetration fail closed", function() {
        var _strong_empty = _BladeCombatGeometryTestsProjectile(
            "blt:1", BladeCombatFaction.Player,
            BladeCombatCancellationPolicy.Symmetric, 10, 0
        );
        var _weak = _BladeCombatGeometryTestsProjectile(
            "blt:2", BladeCombatFaction.Enemy,
            BladeCombatCancellationPolicy.Symmetric, 1, 3
        );
        var _spent = BladeCombatCancellationResolve(_strong_empty, _weak);
        BladeKernelTestAssertTrue(
            _spent.first.cancelled && _spent.second.cancelled,
            "stronger projectile without penetration also cancels"
        );
        var _ignored = BladeCombatCancellationResolve(
            _BladeCombatGeometryTestsProjectile(
                "blt:3", BladeCombatFaction.Player,
                BladeCombatCancellationPolicy.Ignore, 99, 99
            ),
            _weak
        );
        BladeKernelTestAssertFalse(_ignored.interacted, "ignore policy prevents interaction");
    });
}
