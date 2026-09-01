/// @description Deterministic tests for selection, confirmation, and run identity.

// Supplies the smallest complete contract fixture, including an unavailable registry ship.
function _BladeShipSelectionTestContract() {
    return {
        ships: [
            {
                id: "ship.ciela",
                display_name: "Ciela",
                combat_identity: "Spread specialist with broad field coverage.",
            },
            {
                id: "ship.maynii",
                display_name: "Maynii",
                combat_identity: "All-around ship with tracking coverage.",
            },
            {
                id: "ship.kolar",
                display_name: "Kolar",
                combat_identity: "Close-range specialist.",
            },
        ],
        stage1_playable_routes: [
            {
                schema_version: 1,
                id: "playable_route.stage1.ciela",
                display_name: "Ciela - Lost Forest",
                ship_id: "ship.ciela",
                fairy_identity: "river fairy",
                selector_sprite: "sprites/stage1/ciela_player.png",
                player_kind_id: "player_kind.stage1.ciela",
                loadout_id: "loadout.stage1.ciela_spread",
                stage_schedule_id: "stage_schedule.stage1.selected_ship_lost_forest",
                midboss_ship_ids: ["ship.maynii", "ship.kolar"],
                standard_pattern_ids: [
                    "pattern.stage1.standard.maynii_leaf_fan",
                    "pattern.stage1.standard.kolar_crystal_fan",
                ],
                combo_pattern_id: "pattern.stage1.combo.maynii_kolar_root_ridgeline",
            },
            {
                schema_version: 1,
                id: "playable_route.stage1.maynii",
                display_name: "Maynii - Lost Forest",
                ship_id: "ship.maynii",
                fairy_identity: "leaf fairy",
                selector_sprite: "sprites/stage1/maynii_player.png",
                player_kind_id: "player_kind.stage1.maynii",
                loadout_id: "loadout.stage1.maynii_tracking_forward",
                stage_schedule_id: "stage_schedule.stage1.selected_ship_lost_forest",
                midboss_ship_ids: ["ship.ciela", "ship.kolar"],
                standard_pattern_ids: [
                    "pattern.stage1.standard.ciela_river_current",
                    "pattern.stage1.standard.kolar_crystal_fan",
                ],
                combo_pattern_id: "pattern.stage1.combo.ciela_kolar_river_ridgeline",
            },
        ],
    };
}

// Proves route presence, not the three-ship registry, controls the two visible choices.
function _BladeShipSelectionTestCatalogChoices() {
    var _catalog = BladeShipSelectionCatalogFromContract(
        _BladeShipSelectionTestContract()
    );
    BladeKernelTestAssertEqual(
        array_length(_catalog.entries), 2, "selector exposes two runnable routes"
    );
    BladeKernelTestAssertEqual(
        _catalog.entries[0].ship_id, "ship.ciela", "Ciela is the first choice"
    );
    BladeKernelTestAssertEqual(
        _catalog.entries[1].ship_id, "ship.maynii", "Maynii is the second choice"
    );
    BladeKernelTestAssertEqual(
        _catalog.entries[0].fairy_identity,
        "river fairy",
        "Ciela fairy identity"
    );
    BladeKernelTestAssertEqual(
        _catalog.entries[1].fairy_identity,
        "leaf fairy",
        "Maynii fairy identity"
    );
    BladeKernelTestAssertThrows(
        method({ catalog: _catalog }, function() {
            BladeShipSelectionRouteForShip(self.catalog, "ship.kolar");
        }),
        "is not runnable: ship.kolar",
        "registry-only Kolar remains unavailable"
    );
}

// Exercises wraparound navigation and the one-shot confirmation latch.
function _BladeShipSelectionTestConfirmOnce() {
    var _catalog = BladeShipSelectionCatalogFromContract(
        _BladeShipSelectionTestContract()
    );
    var _state = BladeShipSelectionStateCreate(_catalog);
    BladeKernelTestAssertEqual(
        BladeShipSelectionMove(_state, _catalog, -1),
        1,
        "up wraps to Maynii"
    );
    BladeKernelTestAssertEqual(
        BladeShipSelectionMove(_state, _catalog, 1),
        0,
        "down wraps to Ciela"
    );
    BladeShipSelectionMove(_state, _catalog, 1);
    var _first = BladeShipSelectionConfirm(_state, _catalog);
    var _repeated = BladeShipSelectionConfirm(_state, _catalog);
    BladeKernelTestAssertTrue(_first.accepted, "first confirmation is accepted");
    BladeKernelTestAssertEqual(
        _first.run.ship_id, "ship.maynii", "confirmation preserves selection"
    );
    BladeKernelTestAssertFalse(
        _repeated.accepted, "held or repeated confirmation is ignored"
    );
    BladeKernelTestAssertTrue(
        is_undefined(_repeated.run), "repeated confirmation creates no run"
    );
    BladeKernelTestAssertEqual(
        BladeShipSelectionMove(_state, _catalog, 1),
        1,
        "navigation is locked after confirmation"
    );
}

// Revalidates the same persistent identity twice to model room transition and retry.
function _BladeShipSelectionTestRunPersistence() {
    var _catalog = BladeShipSelectionCatalogFromContract(
        _BladeShipSelectionTestContract()
    );
    var _state = BladeShipSelectionStateCreate(_catalog);
    BladeShipSelectionMove(_state, _catalog, 1);
    var _run = BladeShipSelectionConfirm(_state, _catalog).run;
    var _transition = BladeShipSelectionRequireRun(_catalog, _run);
    var _retry = BladeShipSelectionRequireRun(_catalog, _run);
    BladeKernelTestAssertEqual(
        _transition.ship_id, "ship.maynii", "room transition keeps Maynii"
    );
    BladeKernelTestAssertEqual(
        _retry.ship_id, _transition.ship_id, "retry keeps the selected ship"
    );
    BladeKernelTestAssertEqual(
        _retry.difficulty_id, "difficulty.normal", "run remains Normal difficulty"
    );
    BladeKernelTestAssertArrayEqual(
        _retry.midboss_ship_ids,
        ["ship.ciela", "ship.kolar"],
        "Maynii run preserves its unchosen pair"
    );
}

// Covers malformed, incomplete, duplicate, self-opposing, and tampered identities.
function _BladeShipSelectionTestRejections() {
    BladeKernelTestAssertThrows(
        method({}, function() {
            var _contract = _BladeShipSelectionTestContract();
            array_delete(_contract.stage1_playable_routes, 0, 2);
            BladeShipSelectionCatalogFromContract(_contract);
        }),
        "must match every packaged player capability exactly once",
        "empty route catalog"
    );
    BladeKernelTestAssertThrows(
        method({}, function() {
            var _contract = _BladeShipSelectionTestContract();
            array_delete(_contract.stage1_playable_routes, 1, 1);
            BladeShipSelectionCatalogFromContract(_contract);
        }),
        "must match every packaged player capability exactly once",
        "missing Maynii route"
    );
    BladeKernelTestAssertThrows(
        method({}, function() {
            var _contract = _BladeShipSelectionTestContract();
            var _first = _contract.stage1_playable_routes[0];
            _contract.stage1_playable_routes[0]
                = _contract.stage1_playable_routes[1];
            _contract.stage1_playable_routes[1] = _first;
            BladeShipSelectionCatalogFromContract(_contract);
        }),
        "must use packaged player order at index 0",
        "reordered playable routes"
    );
    BladeKernelTestAssertThrows(
        method({}, function() {
            var _contract = _BladeShipSelectionTestContract();
            var _kolar = {
                schema_version: 1,
                id: "playable_route.stage1.kolar",
                display_name: "Kolar - Lost Forest",
                ship_id: "ship.kolar",
                fairy_identity: "mountain fairy",
                selector_sprite: "sprites/stage1/kolar_player.png",
                player_kind_id: "player_kind.stage1.kolar",
                loadout_id: "loadout.stage1.kolar_close_range",
                stage_schedule_id:
                    "stage_schedule.stage1.selected_ship_lost_forest",
                midboss_ship_ids: ["ship.ciela", "ship.maynii"],
                standard_pattern_ids: [
                    "pattern.stage1.standard.ciela_river_current",
                    "pattern.stage1.standard.maynii_leaf_fan",
                ],
                combo_pattern_id:
                    "pattern.stage1.combo.ciela_maynii_river_roots",
            };
            array_push(_contract.stage1_playable_routes, _kolar);
            BladeShipSelectionCatalogFromContract(_contract);
        }),
        "has no packaged player for ship.kolar",
        "aspirational Kolar route"
    );
    BladeKernelTestAssertThrows(
        method({}, function() {
            var _contract = _BladeShipSelectionTestContract();
            _contract.stage1_playable_routes[1].midboss_ship_ids[0] = "ship.maynii";
            BladeShipSelectionCatalogFromContract(_contract);
        }),
        "must exclude the selected ship",
        "selected ship cannot be its own midboss"
    );
    BladeKernelTestAssertThrows(
        method({}, function() {
            var _contract = _BladeShipSelectionTestContract();
            _contract.stage1_playable_routes[1].loadout_id = "";
            BladeShipSelectionCatalogFromContract(_contract);
        }),
        "must be a lowercase dotted stable ID",
        "missing loadout"
    );

    var _catalog = BladeShipSelectionCatalogFromContract(
        _BladeShipSelectionTestContract()
    );
    var _state = BladeShipSelectionStateCreate(_catalog);
    var _run = BladeShipSelectionConfirm(_state, _catalog).run;
    _run.ship_id = "ship.maynii";
    BladeKernelTestAssertThrows(
        method({ catalog: _catalog, run: _run }, function() {
            BladeShipSelectionRequireRun(self.catalog, self.run);
        }),
        "does not match content",
        "tampered run cannot substitute another ship"
    );
}

/// @func BladeShipSelectionTestsRun(state)
/// Registers selector and run-identity cases on the project-owned runner.
function BladeShipSelectionTestsRun(_state) {
    BladeKernelTestRunCase(_state, "ship selector exposes only complete routes", function() {
        _BladeShipSelectionTestCatalogChoices();
    });
    BladeKernelTestRunCase(_state, "ship selector confirms exactly once", function() {
        _BladeShipSelectionTestConfirmOnce();
    });
    BladeKernelTestRunCase(_state, "selected ship persists through transition and retry", function() {
        _BladeShipSelectionTestRunPersistence();
    });
    BladeKernelTestRunCase(_state, "ship selector rejects invalid content and identity", function() {
        _BladeShipSelectionTestRejections();
    });
    return _state;
}
