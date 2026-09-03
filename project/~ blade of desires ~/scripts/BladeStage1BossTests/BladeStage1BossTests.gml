/// Focused deterministic tests for Asahi's camera, phases, and Stage Clear.

/// Creates one schedule-owned Asahi body for an instance-aware test.
function _BladeStage1BossTestsCreate(_controller, _instance_id) {
    var _boss = instance_create_layer(
        320, 72, "Instances", o_blade_stage1_asahi
    );
    _boss.stage_instance_id = _instance_id;
    _boss.stage_encounter_id = BLADE_STAGE1_ASAHI_CONTENT_ID;
    _boss.participant_id = "participant.stage1.asahi";
    BladeStage1BossRegister(_controller, _boss);
    return _boss;
}

/// Runs the boss-specific cases through the existing instance cleanup wrapper.
function BladeStage1BossTestsRun(_state) {
    BladeKernelTestRunCase(
        _state,
        "Asahi presentation orbits the World Tree without moving gameplay",
        function() {
            var _plane = BladeFirstBeatLoadGameplayPlane();
            var _before = BladeCombatPlanePixelBounds(_plane);
            var _renderer = {
                gameplay_plane: _plane,
                route_progress: 218,
                route_progress_limit: 218,
                route_progress_cap: 218,
                route_scroll_speed: 0,
                route_scroll_enabled: false,
                presentation_time: 0,
                camera_x: 0,
                camera_y: 200,
                camera_z: -8,
                look_x: 0,
                look_y: 224,
                look_z: -1.8,
                boss_orbit_active: false,
                boss_orbit_angle: 270,
                boss_orbit_center_x: 13,
                boss_orbit_center_y: 248,
                boss_orbit_surface_z: -6,
                foliage_placements: [],
                fae_placements: [],
                fae_trail_placements: [],
                ball_light_placements: [],
                point_lights: [],
            };
            BladeStage1ForestApplyRouteCue(
                _renderer, "cue.stage1.asahi_warning"
            );
            var _start_x = _renderer.camera_x;
            for (var _tick = 0; _tick < 20; ++_tick) {
                BladeStage1ForestPresentationStep(_renderer);
            }
            BladeKernelTestAssertTrue(
                _renderer.boss_orbit_active,
                "the warning selects the authored scenic orbit"
            );
            BladeKernelTestAssertNotEqual(
                _renderer.camera_x, _start_x,
                "the 3D camera advances around the World Tree"
            );
            BladeKernelTestAssertEqual(
                _renderer.look_x, _renderer.boss_orbit_center_x,
                "the orbit keeps the World Tree centered"
            );
            BladeKernelTestAssertEqual(
                _renderer.look_y, _renderer.boss_orbit_center_y,
                "the orbit retains its authored World Tree depth"
            );
            BladeKernelTestAssertTrue(
                _renderer.look_z < _renderer.boss_orbit_surface_z,
                "the scenic look target respects the repository's -Z up world"
            );
            var _after = BladeCombatPlanePixelBounds(
                _renderer.gameplay_plane
            );
            BladeKernelTestAssertEqual(
                _after.left, _before.left,
                "presentation never moves the canonical left gameplay edge"
            );
            BladeKernelTestAssertEqual(
                _after.right_exclusive, _before.right_exclusive,
                "presentation never moves the canonical right gameplay edge"
            );
            BladeKernelTestAssertEqual(
                _after.top, _before.top,
                "presentation never moves the canonical top gameplay edge"
            );
            BladeKernelTestAssertEqual(
                _after.bottom_exclusive, _before.bottom_exclusive,
                "presentation never moves the canonical bottom gameplay edge"
            );
        }
    );

    BladeFirstBeatTestRunCase(
        _state,
        "Asahi phases emit distinct patterns and honor the recharge boundary",
        function() {
            var _controller = instance_create_layer(
                0, 0, "Instances", o_blade_first_beat_controller
            );
            var _player = instance_create_layer(
                320, 300, "Instances", o_ciela_first_beat_player
            );
            var _boss = _BladeStage1BossTestsCreate(
                _controller, "stage1-asahi-phase-test"
            );
            BladeStage1BossActivatePhase(_boss, 1);

            _boss.attack_ticks = 58;
            BladeKernelTestAssertTrue(
                BladeStage1BossSolarWaltz(_boss, _player),
                "phase one emits its aimed seven-flame fan"
            );
            BladeKernelTestAssertEqual(
                instance_number(o_blade_first_beat_enemy_bullet), 7,
                "Solar Waltz has the exact readable fan count"
            );
            BladeStage1BossClearOwnedBullets(_boss);
            BladeStage1BossActivatePhase(_boss, 2);
            _boss.attack_ticks = 72;
            BladeKernelTestAssertTrue(
                BladeStage1BossCrownOfDawn(_boss, _player),
                "phase two emits its rotating crown"
            );
            BladeKernelTestAssertEqual(
                instance_number(o_blade_first_beat_enemy_bullet), 14,
                "Crown of Dawn leaves one two-ray safe gap"
            );
            BladeStage1BossClearOwnedBullets(_boss);
            BladeStage1BossActivatePhase(_boss, 1);

            var _owned = instance_create_layer(
                320, 100,
                "Projectiles", o_blade_first_beat_enemy_bullet
            );
            _owned.owner_stage_instance_id = _boss.stage_instance_id;
            var _unrelated = instance_create_layer(
                330, 100,
                "Projectiles", o_blade_first_beat_enemy_bullet
            );
            _unrelated.owner_stage_instance_id = "another-participant";
            var _score_before = _controller.economy.score;
            var _phase_one = BladeStage1BossApplyDamage(
                _controller, _boss, BLADE_STAGE1_ASAHI_PHASE_1_HP
            );
            BladeKernelTestAssertTrue(
                _phase_one.defeated,
                "the exact authored damage resolves phase one"
            );
            BladeKernelTestAssertEqual(
                _boss.boss_state, BladeStage1BossState.Recharge,
                "phase one enters the non-damageable recharge"
            );
            BladeKernelTestAssertEqual(
                _boss.recharge_ticks, BLADE_STAGE1_ASAHI_RECHARGE_TICKS,
                "the ring recharge lasts exactly two seconds"
            );
            BladeKernelTestAssertFalse(
                _boss.targetable,
                "shots cannot bypass the recharge boundary"
            );
            BladeKernelTestAssertEqual(
                _controller.economy.score, _score_before + 20000,
                "phase one score is awarded once"
            );
            BladeKernelTestAssertFalse(
                instance_exists(_owned),
                "phase defeat converts the Asahi-owned bullet"
            );
            var _phase_one_item = instance_find(o_blade_reward_item, 0);
            BladeKernelTestAssertTrue(
                _phase_one_item != noone
                    && _phase_one_item.kind == BladeSurvivalItemKind.Point
                    && _phase_one_item.x == 320
                    && _phase_one_item.y == 100,
                "phase defeat creates one point item at each bullet position"
            );
            BladeKernelTestAssertTrue(
                instance_exists(_unrelated),
                "phase resolution preserves unrelated participant bullets"
            );
            var _repeat = BladeStage1BossApplyDamage(
                _controller, _boss, BLADE_STAGE1_ASAHI_PHASE_1_HP
            );
            BladeKernelTestAssertEqual(
                _repeat.applied, 0,
                "repeated damage cannot resolve the phase twice"
            );
            for (var _tick = 1;
                _tick < BLADE_STAGE1_ASAHI_RECHARGE_TICKS;
                ++_tick) {
                BladeStage1BossStep(_boss);
            }
            BladeKernelTestAssertEqual(
                _boss.recharge_ticks, 1,
                "phase two remains closed one tick before the boundary"
            );
            BladeStage1BossStep(_boss);
            BladeKernelTestAssertEqual(
                _boss.boss_phase, 2,
                "phase two opens on the exact recharge boundary"
            );
            BladeKernelTestAssertTrue(
                _boss.targetable,
                "phase two is damageable after recharge"
            );

            var _phase_two_owned = instance_create_layer(
                320, 100,
                "Projectiles", o_blade_first_beat_enemy_bullet
            );
            _phase_two_owned.owner_stage_instance_id = _boss.stage_instance_id;
            var _items_before_timeout = instance_number(o_blade_reward_item);
            _boss.phase_ticks = _boss.phase_time_limit - 1;
            BladeStage1BossStep(_boss);
            BladeKernelTestAssertEqual(
                _controller.boss_resolution,
                BladeStage1BossResolution.Timeout,
                "the final phase resolves when its authored timer expires"
            );
            BladeKernelTestAssertEqual(
                _boss.boss_state, BladeStage1BossState.Terminal,
                "timeout enters the one terminal boundary"
            );
            BladeKernelTestAssertEqual(
                array_length(_controller.stage_defeat_queue), 1,
                "timeout reports the Stage encounter exactly once"
            );
            BladeKernelTestAssertFalse(
                instance_exists(_phase_two_owned),
                "timeout clears the last boss-owned attack"
            );
            BladeKernelTestAssertEqual(
                instance_number(o_blade_reward_item), _items_before_timeout,
                "timeout creates no point item"
            );
            BladeKernelTestAssertFalse(
                BladeStage1BossResolvePhase(
                    _controller,
                    _boss,
                    BladeStage1BossResolution.Timeout
                ),
                "the terminal phase cannot resolve again"
            );
            BladeKernelTestAssertEqual(
                array_length(_controller.stage_defeat_queue), 1,
                "repeat resolution cannot duplicate the Stage report"
            );
        }
    );

    BladeFirstBeatTestRunCase(
        _state,
        "Asahi defeat and Stage Clear rewards resolve exactly once",
        function() {
            var _controller = instance_create_layer(
                0, 0, "Instances", o_blade_first_beat_controller
            );
            var _boss = _BladeStage1BossTestsCreate(
                _controller, "stage1-asahi-defeat-test"
            );
            BladeStage1BossActivatePhase(_boss, 2);
            var _defeat = BladeStage1BossApplyDamage(
                _controller, _boss, BLADE_STAGE1_ASAHI_PHASE_2_HP
            );
            BladeKernelTestAssertTrue(
                _defeat.defeated,
                "the exact second-life damage resolves defeat"
            );
            BladeKernelTestAssertEqual(
                _controller.boss_resolution,
                BladeStage1BossResolution.Defeat,
                "defeat is distinct from survival timeout"
            );
            BladeKernelTestAssertEqual(
                array_length(_controller.stage_defeat_queue), 1,
                "defeat reports the encounter once"
            );
            BladeKernelTestAssertEqual(
                _controller.feedback_text,
                "ASAHI DEFEATED\nDAWN BREAKS",
                "defeat owns its unique readable resolution message"
            );
            var _boss_score = _controller.economy.score;
            var _repeat = BladeStage1BossApplyDamage(
                _controller, _boss, BLADE_STAGE1_ASAHI_PHASE_2_HP
            );
            BladeKernelTestAssertEqual(
                _repeat.applied, 0,
                "terminal damage cannot award boss score twice"
            );
            BladeKernelTestAssertEqual(
                _controller.economy.score, _boss_score,
                "boss score remains stable after repeated damage"
            );

            _controller.economy.lives = 2;
            _controller.economy.bombs = 3;
            var _before_clear = _controller.economy.score;
            var _breakdown = BladeStage1BossFinalizeStageClear(_controller);
            BladeKernelTestAssertEqual(
                _breakdown.base, BLADE_STAGE1_ASAHI_STAGE_BONUS,
                "Stage Clear records its base bonus"
            );
            BladeKernelTestAssertEqual(
                _breakdown.lives, 20000,
                "Stage Clear records the exact remaining-life bonus"
            );
            BladeKernelTestAssertEqual(
                _breakdown.bombs, 6000,
                "Stage Clear records the exact remaining-bomb bonus"
            );
            BladeKernelTestAssertEqual(
                _controller.economy.score,
                _before_clear + _breakdown.total,
                "Stage Clear applies the recorded total"
            );
            var _score_after_clear = _controller.economy.score;
            var _repeat_breakdown = BladeStage1BossFinalizeStageClear(
                _controller
            );
            BladeKernelTestAssertEqual(
                _repeat_breakdown.total, _breakdown.total,
                "repeat finalization returns the stable breakdown"
            );
            BladeKernelTestAssertEqual(
                _controller.economy.score, _score_after_clear,
                "repeat finalization cannot award the bonus twice"
            );
            BladeKernelTestAssertFalse(
                instance_exists(_boss),
                "Stage Clear removes the terminal boss body"
            );
        }
    );
}
