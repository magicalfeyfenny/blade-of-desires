/// Focused deterministic checks for the four ordinary Stage 1 roles.

/// Counts distinct scalar labels without depending on runtime collection helpers.
function _BladeStage1EnemyRosterUniqueCount(_values) {
    var _unique = [];
    for (var _index = 0; _index < array_length(_values); ++_index) {
        var _found = false;
        for (var _unique_index = 0;
            _unique_index < array_length(_unique);
            ++_unique_index) {
            if (_unique[_unique_index] == _values[_index]) {
                _found = true;
                break;
            }
        }
        if (!_found) array_push(_unique, _values[_index]);
    }
    return array_length(_unique);
}

function BladeStage1EnemyRosterTestsRun(_state) {
    BladeKernelTestRunCase(
        _state,
        "Stage 1 roster exposes four active roles and bounds scout compatibility",
        function() {
            var _ids = BladeStage1EnemyRoleContentIds();
            BladeKernelTestAssertArrayEqual(
                _ids,
                [
                    BLADE_STAGE1_POPCORN_CONTENT_ID,
                    BLADE_STAGE1_MOOK_CONTENT_ID,
                    BLADE_STAGE1_ELITE_CONTENT_ID,
                    BLADE_STAGE1_COMMANDER_CONTENT_ID,
                ],
                "active role IDs stay in strength order"
            );
            BladeKernelTestAssertTrue(
                BladeStage1EnemyKnownContent(
                    BLADE_STAGE1_SCOUT_COMPATIBILITY_ID
                ),
                "retired scout spelling remains readable at the compatibility boundary"
            );
            BladeKernelTestAssertEqual(
                BladeStage1EnemyNormalizeContentId(
                    BLADE_STAGE1_SCOUT_COMPATIBILITY_ID
                ),
                BLADE_STAGE1_MOOK_CONTENT_ID,
                "scout normalizes to canonical mook"
            );
            BladeKernelTestAssertEqual(
                BladeStage1EnemyDisplayName(
                    BLADE_STAGE1_SCOUT_COMPATIBILITY_ID
                ),
                "MOOK",
                "scout is never player-visible"
            );
        }
    );

    BladeKernelTestRunCase(
        _state,
        "normal rank zero role profiles establish a strict strength order",
        function() {
            var _ids = BladeStage1EnemyRoleContentIds();
            var _previous_health = 0;
            var _previous_defeat_ticks = 0;
            for (var _index = 0; _index < array_length(_ids); ++_index) {
                var _profile = BladeStage1EnemyProfile(
                    BladeStage1EnemyRoleForContent(_ids[_index])
                );
                BladeKernelTestAssertTrue(
                    _profile.authored_max_health > _previous_health,
                    "role health rises with each tier"
                );
                BladeKernelTestAssertTrue(
                    _profile.expected_defeat_ticks > _previous_defeat_ticks,
                    "representative defeat window rises with each tier"
                );
                _previous_health = _profile.authored_max_health;
                _previous_defeat_ticks = _profile.expected_defeat_ticks;
            }
        }
    );

    BladeKernelTestRunCase(
        _state,
        "role movement tells cadence and trajectories are authored differences",
        function() {
            var _ids = BladeStage1EnemyRoleContentIds();
            var _motion_ids = [];
            var _tell_ids = [];
            var _pattern_ids = [];
            for (var _index = 0; _index < array_length(_ids); ++_index) {
                var _profile = BladeStage1EnemyProfile(
                    BladeStage1EnemyRoleForContent(_ids[_index])
                );
                array_push(_motion_ids, _profile.motion_id);
                array_push(_tell_ids, _profile.tell_id);
                array_push(_pattern_ids, _profile.pattern_id);
                BladeKernelTestAssertEqual(
                    array_length(_profile.bullet_offsets),
                    _index == 0 ? 1 : (_index == 1 ? 3 : (_index == 2 ? 5 : 7)),
                    "each tier owns a different volley width"
                );
                BladeKernelTestAssertTrue(
                    _profile.fire_repeat_ticks
                        < (_index == 0
                            ? 1000
                            : BladeStage1EnemyProfile(
                                BladeStage1EnemyRoleForContent(_ids[_index - 1])
                            ).fire_repeat_ticks),
                    "stronger tiers use a tighter authored cadence"
                );
            }
            BladeKernelTestAssertEqual(
                _BladeStage1EnemyRosterUniqueCount(_motion_ids),
                4,
                "movement profiles do not collapse to palette swaps"
            );
            BladeKernelTestAssertEqual(
                _BladeStage1EnemyRosterUniqueCount(_tell_ids),
                4,
                "pre-fire tell profiles are distinct"
            );
            BladeKernelTestAssertEqual(
                _BladeStage1EnemyRosterUniqueCount(_pattern_ids),
                4,
                "bullet pattern profiles are distinct"
            );
        }
    );

    BladeKernelTestRunCase(
        _state,
        "every role uses the canonical gameplay plane for each emission",
        function() {
            var _plane = BladeFirstBeatLoadGameplayPlane();
            var _ids = BladeStage1EnemyRoleContentIds();
            for (var _index = 0; _index < array_length(_ids); ++_index) {
                var _profile = BladeStage1EnemyProfile(
                    BladeStage1EnemyRoleForContent(_ids[_index])
                );
                BladeKernelTestAssertTrue(
                    BladeStage1EnemyEmissionAllowed(
                        _plane, 320, 72 + _profile.hit_radius,
                        _profile.projectile_radius
                    ),
                    "in-plane emission origin is accepted"
                );
                BladeKernelTestAssertFalse(
                    BladeStage1EnemyEmissionAllowed(
                        _plane, 320, 1, _profile.projectile_radius
                    ),
                    "top-edge emission is rejected"
                );
            }
        }
    );

    BladeKernelTestRunCase(
        _state,
        "bomb carrier remains a mook reward modifier rather than a fifth tier",
        function() {
            BladeKernelTestAssertEqual(
                BladeStage1EnemyRoleForContent(
                    BLADE_SURVIVAL_BOMB_CARRIER_ID
                ),
                BladeStage1EnemyRole.Mook,
                "carrier uses the mook base role"
            );
            var _ids = BladeStage1EnemyRoleContentIds();
            for (var _index = 0; _index < array_length(_ids); ++_index) {
                BladeKernelTestAssertNotEqual(
                    _ids[_index], BLADE_SURVIVAL_BOMB_CARRIER_ID,
                    "carrier does not enter the strength roster"
                );
            }
            BladeKernelTestAssertTrue(
                BladeSurvivalEnemyIsBombCarrier(
                    BLADE_SURVIVAL_BOMB_CARRIER_ID
                ),
                "carrier identity still owns the bomb reward"
            );
        }
    );
}
