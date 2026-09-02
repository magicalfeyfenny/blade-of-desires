/// @description Fail-closed Stage 1 ship selection and run identity.

#macro BLADE_SHIP_SELECTION_CONTRACT_PATH "content/product_contract.json"
#macro BLADE_SHIP_SELECTION_DIFFICULTY_ID "difficulty.normal"

// Keeps selector diagnostics short enough to show directly on the launch screen.
function _BladeShipSelectionFail(_field, _reason) {
    throw("BladeShipSelection: " + _field + " " + _reason);
}

// Requires one struct to contain exactly the documented fields before use.
function _BladeShipSelectionExactKeys(_value, _expected, _field) {
    if (!is_struct(_value)) {
        _BladeShipSelectionFail(_field, "must be a struct");
    }
    var _actual = variable_struct_get_names(_value);
    if (array_length(_actual) != array_length(_expected)) {
        _BladeShipSelectionFail(_field, "has incomplete or unknown fields");
    }
    for (var _expected_index = 0;
        _expected_index < array_length(_expected); ++_expected_index) {
        if (!variable_struct_exists(_value, _expected[_expected_index])) {
            _BladeShipSelectionFail(
                _field, "requires " + _expected[_expected_index]
            );
        }
    }
}

// Accepts only lowercase dotted IDs so malformed content never reaches a switch.
function _BladeShipSelectionStableId(_value, _field) {
    if (!is_string(_value) || string_length(_value) < 3) {
        _BladeShipSelectionFail(_field, "must be a lowercase dotted stable ID");
    }
    var _has_dot = false;
    var _segment_start = true;
    for (var _index = 1; _index <= string_length(_value); ++_index) {
        var _character = string_char_at(_value, _index);
        var _byte = string_ord_at(_value, _index);
        if (_character == ".") {
            if (_segment_start || _index == string_length(_value)) {
                _BladeShipSelectionFail(
                    _field, "must be a lowercase dotted stable ID"
                );
            }
            _has_dot = true;
            _segment_start = true;
            continue;
        }
        var _letter = _byte >= 97 && _byte <= 122;
        var _digit = _byte >= 48 && _byte <= 57;
        if ((_segment_start && !_letter)
            || (!_segment_start && !_letter && !_digit && _character != "_")) {
            _BladeShipSelectionFail(
                _field, "must be a lowercase dotted stable ID"
            );
        }
        _segment_start = false;
    }
    if (!_has_dot) {
        _BladeShipSelectionFail(_field, "must be a lowercase dotted stable ID");
    }
    return _value;
}

// Copies and validates an exact two-entry identity list without retaining JSON arrays.
function _BladeShipSelectionPair(_value, _field) {
    if (!is_array(_value) || array_length(_value) != 2) {
        _BladeShipSelectionFail(_field, "must contain exactly two stable IDs");
    }
    var _first = _BladeShipSelectionStableId(_value[0], _field + "[0]");
    var _second = _BladeShipSelectionStableId(_value[1], _field + "[1]");
    if (_first == _second) {
        _BladeShipSelectionFail(_field, "must contain two distinct stable IDs");
    }
    return [_first, _second];
}

// Returns one required nonempty player-facing string.
function _BladeShipSelectionText(_value, _field) {
    if (!is_string(_value) || string_length(string_trim(_value)) == 0) {
        _BladeShipSelectionFail(_field, "must be nonempty text");
    }
    return _value;
}

// Finds one ship record without assuming the registry's unrelated canonical order.
function _BladeShipSelectionFindShip(_ships, _ship_id) {
    if (!is_array(_ships)) {
        _BladeShipSelectionFail("ships", "must be an array");
    }
    var _found = undefined;
    for (var _index = 0; _index < array_length(_ships); ++_index) {
        var _ship = _ships[_index];
        if (!is_struct(_ship) || !variable_struct_exists(_ship, "id")) continue;
        if (_ship.id != _ship_id) continue;
        if (!is_undefined(_found)) {
            _BladeShipSelectionFail("ships", "duplicates " + _ship_id);
        }
        _found = _ship;
    }
    if (is_undefined(_found)) {
        _BladeShipSelectionFail("ships", "does not declare " + _ship_id);
    }
    return _found;
}

// Lists only player implementations that are complete and packaged in this build.
function _BladeShipSelectionRuntimeCapabilities() {
    return [
        {
            ship_id: "ship.ciela",
            player_kind_id: "player_kind.stage1.ciela",
            loadout_id: "loadout.stage1.ciela_spread",
        },
        {
            ship_id: "ship.maynii",
            player_kind_id: "player_kind.stage1.maynii",
            loadout_id: "loadout.stage1.maynii_tracking_forward",
        },
        {
            ship_id: "ship.kolar",
            player_kind_id: "player_kind.stage1.kolar",
            loadout_id: "loadout.stage1.kolar_close_range",
        },
    ];
}

// Finds the packaged capability that makes one route genuinely runnable.
function _BladeShipSelectionCapability(_ship_id) {
    var _capabilities = _BladeShipSelectionRuntimeCapabilities();
    for (var _index = 0; _index < array_length(_capabilities); ++_index) {
        if (_capabilities[_index].ship_id == _ship_id) {
            return _capabilities[_index];
        }
    }
    _BladeShipSelectionFail(
        "stage1_playable_routes", "has no packaged player for " + _ship_id
    );
}

// Converts one contract route into the detached record consumed by UI and gameplay.
function _BladeShipSelectionRoute(_ships, _route, _index) {
    var _field = "stage1_playable_routes[" + string(_index) + "]";
    _BladeShipSelectionExactKeys(_route, [
        "schema_version", "id", "display_name", "ship_id",
        "fairy_identity", "selector_sprite", "player_kind_id",
        "loadout_id", "stage_schedule_id", "midboss_ship_ids",
        "standard_pattern_ids", "combo_pattern_id",
    ], _field);
    if (_route.schema_version != 1) {
        _BladeShipSelectionFail(_field + ".schema_version", "must be 1");
    }
    var _ship_id = _BladeShipSelectionStableId(
        _route.ship_id, _field + ".ship_id"
    );
    var _ship = _BladeShipSelectionFindShip(_ships, _ship_id);
    var _midbosses = _BladeShipSelectionPair(
        _route.midboss_ship_ids, _field + ".midboss_ship_ids"
    );
    if (_midbosses[0] == _ship_id || _midbosses[1] == _ship_id) {
        _BladeShipSelectionFail(
            _field + ".midboss_ship_ids", "must exclude the selected ship"
        );
    }
    var _patterns = _BladeShipSelectionPair(
        _route.standard_pattern_ids, _field + ".standard_pattern_ids"
    );
    var _sprite = _BladeShipSelectionText(
        _route.selector_sprite, _field + ".selector_sprite"
    );
    if (string_pos("sprites/stage1/", _sprite) != 1
        || string_copy(_sprite, string_length(_sprite) - 3, 4) != ".png") {
        _BladeShipSelectionFail(
            _field + ".selector_sprite", "must name a Stage 1 PNG"
        );
    }
    var _player_kind_id = _BladeShipSelectionStableId(
        _route.player_kind_id, _field + ".player_kind_id"
    );
    var _loadout_id = _BladeShipSelectionStableId(
        _route.loadout_id, _field + ".loadout_id"
    );
    var _capability = _BladeShipSelectionCapability(_ship_id);
    if (_player_kind_id != _capability.player_kind_id
        || _loadout_id != _capability.loadout_id) {
        _BladeShipSelectionFail(
            _field,
            "does not match the packaged player capability for " + _ship_id
        );
    }
    return {
        schema_version: 1,
        route_id: _BladeShipSelectionStableId(_route.id, _field + ".id"),
        route_name: _BladeShipSelectionText(
            _route.display_name, _field + ".display_name"
        ),
        ship_id: _ship_id,
        display_name: _BladeShipSelectionText(
            _ship.display_name, "ships." + _ship_id + ".display_name"
        ),
        fairy_identity: _BladeShipSelectionText(
            _route.fairy_identity, _field + ".fairy_identity"
        ),
        combat_identity: _BladeShipSelectionText(
            _ship.combat_identity, "ships." + _ship_id + ".combat_identity"
        ),
        selector_sprite: _sprite,
        player_kind_id: _player_kind_id,
        loadout_id: _loadout_id,
        stage_schedule_id: _BladeShipSelectionStableId(
            _route.stage_schedule_id, _field + ".stage_schedule_id"
        ),
        midboss_ship_ids: _midbosses,
        standard_pattern_ids: _patterns,
        combo_pattern_id: _BladeShipSelectionStableId(
            _route.combo_pattern_id, _field + ".combo_pattern_id"
        ),
    };
}

/// @func BladeShipSelectionCatalogFromContract(contract)
/// Builds the selectable list only from complete Stage 1 route records.
/// A ship registry entry alone cannot become selectable through this boundary.
function BladeShipSelectionCatalogFromContract(_contract) {
    if (!is_struct(_contract)
        || !variable_struct_exists(_contract, "ships")
        || !variable_struct_exists(_contract, "stage1_playable_routes")
        || !is_array(_contract.stage1_playable_routes)) {
        _BladeShipSelectionFail(
            "product contract", "requires ships and stage1_playable_routes"
        );
    }
    var _entries = [];
    for (var _index = 0;
        _index < array_length(_contract.stage1_playable_routes); ++_index) {
        var _entry = _BladeShipSelectionRoute(
            _contract.ships, _contract.stage1_playable_routes[_index], _index
        );
        for (var _earlier = 0; _earlier < array_length(_entries); ++_earlier) {
            if (_entries[_earlier].ship_id == _entry.ship_id) {
                _BladeShipSelectionFail(
                    "stage1_playable_routes", "duplicates " + _entry.ship_id
                );
            }
        }
        array_push(_entries, _entry);
    }
    var _capabilities = _BladeShipSelectionRuntimeCapabilities();
    if (array_length(_entries) != array_length(_capabilities)) {
        _BladeShipSelectionFail(
            "stage1_playable_routes",
            "must match every packaged player capability exactly once"
        );
    }
    for (var _capability_index = 0;
        _capability_index < array_length(_capabilities);
        ++_capability_index) {
        if (_entries[_capability_index].ship_id
            != _capabilities[_capability_index].ship_id) {
            _BladeShipSelectionFail(
                "stage1_playable_routes",
                "must use packaged player order at index "
                + string(_capability_index)
            );
        }
    }
    return {
        __blade_ship_selection_catalog_version: 1,
        entries: _entries,
    };
}

/// @func BladeShipSelectionLoad(path)
/// Loads the one packaged product contract used by both selector and Stage 1.
function BladeShipSelectionLoad(
    _path = BLADE_SHIP_SELECTION_CONTRACT_PATH
) {
    var _resolved = BladeStage1RouteIncludedPath(_path);
    var _contract;
    try {
        _contract = json_parse(
            _BladeFirstBeatReadBundledText(_resolved), undefined, true
        );
    } catch (_caught) {
        _BladeShipSelectionFail(
            "product contract", "could not be decoded: " + string(_caught)
        );
    }
    return BladeShipSelectionCatalogFromContract(_contract);
}

// Requires the catalog marker before indexing a route supplied by content.
function _BladeShipSelectionRequireCatalog(_catalog) {
    if (!is_struct(_catalog)
        || !variable_struct_exists(
            _catalog, "__blade_ship_selection_catalog_version"
        )
        || _catalog.__blade_ship_selection_catalog_version != 1
        || !variable_struct_exists(_catalog, "entries")
        || !is_array(_catalog.entries)) {
        _BladeShipSelectionFail("catalog", "must be a version 1 catalog");
    }
}

/// @func BladeShipSelectionRouteForShip(catalog, ship_id)
/// Returns the canonical detached route for one currently runnable ship.
function BladeShipSelectionRouteForShip(_catalog, _ship_id) {
    _BladeShipSelectionRequireCatalog(_catalog);
    for (var _index = 0; _index < array_length(_catalog.entries); ++_index) {
        if (_catalog.entries[_index].ship_id == _ship_id) {
            return _catalog.entries[_index];
        }
    }
    _BladeShipSelectionFail("selected ship", "is not runnable: " + string(_ship_id));
}

// Copies a route into the persistent run record without retaining selector state.
function _BladeShipSelectionRunFromRoute(_route) {
    return {
        __blade_stage1_selected_run_version: 1,
        difficulty_id: BLADE_SHIP_SELECTION_DIFFICULTY_ID,
        ship_id: _route.ship_id,
        route_id: _route.route_id,
        player_kind_id: _route.player_kind_id,
        loadout_id: _route.loadout_id,
        stage_schedule_id: _route.stage_schedule_id,
        midboss_ship_ids: [
            _route.midboss_ship_ids[0], _route.midboss_ship_ids[1]
        ],
        standard_pattern_ids: [
            _route.standard_pattern_ids[0], _route.standard_pattern_ids[1]
        ],
        combo_pattern_id: _route.combo_pattern_id,
    };
}

/// @func BladeShipSelectionCreateRun(catalog, ship_id)
/// Creates the canonical Normal Stage 1 identity for one runnable ship.
function BladeShipSelectionCreateRun(_catalog, _ship_id) {
    return _BladeShipSelectionRunFromRoute(
        BladeShipSelectionRouteForShip(_catalog, _ship_id)
    );
}

/// @func BladeShipSelectionStateCreate(catalog)
/// Creates one UI state whose confirmation latch can transition only once.
function BladeShipSelectionStateCreate(_catalog) {
    _BladeShipSelectionRequireCatalog(_catalog);
    return {
        __blade_ship_selector_state_version: 1,
        selected_index: 0,
        confirmation_started: false,
    };
}

// Requires one live selector state before navigation or confirmation changes it.
function _BladeShipSelectionRequireState(_state, _catalog) {
    _BladeShipSelectionRequireCatalog(_catalog);
    if (!is_struct(_state)
        || !variable_struct_exists(_state, "__blade_ship_selector_state_version")
        || _state.__blade_ship_selector_state_version != 1
        || !variable_struct_exists(_state, "selected_index")
        || !variable_struct_exists(_state, "confirmation_started")
        || _state.selected_index < 0
        || _state.selected_index >= array_length(_catalog.entries)) {
        _BladeShipSelectionFail("selector state", "is invalid");
    }
}

/// @func BladeShipSelectionMove(state, catalog, delta)
/// Wraps one semantic navigation step and ignores motion after confirmation.
function BladeShipSelectionMove(_state, _catalog, _delta) {
    _BladeShipSelectionRequireState(_state, _catalog);
    if (_state.confirmation_started || _delta == 0) return _state.selected_index;
    var _count = array_length(_catalog.entries);
    var _direction = _delta > 0 ? 1 : -1;
    _state.selected_index = (_state.selected_index + _direction + _count) mod _count;
    return _state.selected_index;
}

/// @func BladeShipSelectionConfirm(state, catalog)
/// Latches the first confirmation and returns no run for every repeated call.
function BladeShipSelectionConfirm(_state, _catalog) {
    _BladeShipSelectionRequireState(_state, _catalog);
    if (_state.confirmation_started) {
        return { accepted: false, run: undefined };
    }
    _state.confirmation_started = true;
    return {
        accepted: true,
        run: _BladeShipSelectionRunFromRoute(
            _catalog.entries[_state.selected_index]
        ),
    };
}

/// @func BladeShipSelectionRequireRun(catalog, run)
/// Rebinds persistent identity to current content and rejects every mismatch.
function BladeShipSelectionRequireRun(_catalog, _run) {
    _BladeShipSelectionRequireCatalog(_catalog);
    _BladeShipSelectionExactKeys(_run, [
        "__blade_stage1_selected_run_version", "difficulty_id", "ship_id",
        "route_id", "player_kind_id", "loadout_id", "stage_schedule_id",
        "midboss_ship_ids", "standard_pattern_ids", "combo_pattern_id",
    ], "selected run");
    if (_run.__blade_stage1_selected_run_version != 1
        || _run.difficulty_id != BLADE_SHIP_SELECTION_DIFFICULTY_ID) {
        _BladeShipSelectionFail("selected run", "has the wrong version or difficulty");
    }
    var _canonical = _BladeShipSelectionRunFromRoute(
        BladeShipSelectionRouteForShip(_catalog, _run.ship_id)
    );
    var _scalar_fields = [
        "difficulty_id", "ship_id", "route_id", "player_kind_id", "loadout_id",
        "stage_schedule_id", "combo_pattern_id",
    ];
    for (var _index = 0; _index < array_length(_scalar_fields); ++_index) {
        var _field = _scalar_fields[_index];
        if (variable_struct_get(_run, _field)
            != variable_struct_get(_canonical, _field)) {
            _BladeShipSelectionFail("selected run." + _field, "does not match content");
        }
    }
    var _midbosses = _BladeShipSelectionPair(
        _run.midboss_ship_ids, "selected run.midboss_ship_ids"
    );
    var _patterns = _BladeShipSelectionPair(
        _run.standard_pattern_ids, "selected run.standard_pattern_ids"
    );
    for (var _pair_index = 0; _pair_index < 2; ++_pair_index) {
        if (_midbosses[_pair_index] != _canonical.midboss_ship_ids[_pair_index]
            || _patterns[_pair_index]
                != _canonical.standard_pattern_ids[_pair_index]) {
            _BladeShipSelectionFail("selected run", "does not match its route");
        }
    }
    return _canonical;
}

/// @func BladeShipSelectionPlayerObject(player_kind_id)
/// Maps validated runtime kinds to concrete GameMaker objects at one boundary.
function BladeShipSelectionPlayerObject(_player_kind_id) {
    switch (_player_kind_id) {
        case "player_kind.stage1.ciela": return o_ciela_first_beat_player;
        case "player_kind.stage1.maynii": return o_maynii_first_beat_player;
        case "player_kind.stage1.kolar": return o_kolar_first_beat_player;
    }
    _BladeShipSelectionFail(
        "player_kind_id", "has no packaged player: " + string(_player_kind_id)
    );
}
