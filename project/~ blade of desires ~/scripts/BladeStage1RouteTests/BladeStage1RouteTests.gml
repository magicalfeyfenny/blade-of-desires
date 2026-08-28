/// Focused playable-route tests for Stage 1 and its Maynii-Kolar midboss.

/// Queues every newly spawned ordinary target and records authored carrier count.
function _BladeStage1RouteTestsQueueOrdinary(_controller, _record) {
    var _count = instance_number(o_blade_first_beat_enemy);
    for (var _index = _count - 1; _index >= 0; --_index) {
        var _target = instance_find(o_blade_first_beat_enemy, _index);
        if (_target == noone || !_target.stage_managed
            || _target.defeat_queued) continue;
        _record.ordinary_count += 1;
        if (_target.content_id == BLADE_SURVIVAL_BOMB_CARRIER_ID) {
            _record.carrier_count += 1;
        }
        BladeFirstBeatQueueStageDefeat(_controller, _target);
        with (_target) instance_destroy();
    }
}

/// Advances and clears ordinary waves until the authored duo is materialized.
function _BladeStage1RouteTestsReachDuo(_controller, _record) {
    for (var _tick = 0; _tick < 1200; ++_tick) {
        _BladeStage1RouteTestsQueueOrdinary(_controller, _record);
        BladeStage1RouteAdvance(_controller);
        if (instance_number(o_blade_stage1_fae_midboss) == 2) return true;
    }
    return false;
}

/// Finishes the post-midboss route while clearing each ordinary encounter once.
function _BladeStage1RouteTestsReachHandoff(_controller, _record) {
    for (var _tick = 0; _tick < 1600; ++_tick) {
        _BladeStage1RouteTestsQueueOrdinary(_controller, _record);
        BladeStage1RouteAdvance(_controller);
        if (_controller.state == BladeFirstBeatState.Won) return true;
    }
    return false;
}

/// Counts visible hostile bullets belonging to one concrete authored pattern kind.
function _BladeStage1RouteTestsBulletCount(_kind) {
    var _matches = 0;
    var _count = instance_number(o_blade_first_beat_enemy_bullet);
    for (var _index = 0; _index < _count; ++_index) {
        var _bullet = instance_find(o_blade_first_beat_enemy_bullet, _index);
        if (_bullet != noone && _bullet.bullet_kind == _kind) _matches += 1;
    }
    return _matches;
}

/// Confirms every bullet in one pattern kind travels down toward the player.
function _BladeStage1RouteTestsBulletsMoveDown(_kind) {
    var _found = false;
    var _count = instance_number(o_blade_first_beat_enemy_bullet);
    for (var _index = 0; _index < _count; ++_index) {
        var _bullet = instance_find(o_blade_first_beat_enemy_bullet, _index);
        if (_bullet == noone || _bullet.bullet_kind != _kind) continue;
        _found = true;
        if (_bullet.velocity_y <= 0) return false;
    }
    return _found;
}

/// Registers the real route, duo lifecycle, continuation, and handoff case.
function BladeStage1RouteTestsRun(_state) {
    BladeKernelTestRunCase(
        _state,
        "Stage 1 camera cues cap each route segment and land at the World Tree",
        function() {
            var _renderer = {
                route_progress: 0,
                route_progress_limit: 218,
                route_progress_cap: 218,
                route_scroll_speed: 0,
                route_scroll_enabled: false,
            };
            BladeStage1ForestApplyRouteCue(
                _renderer, "cue.stage1.forest_travel"
            );
            BladeKernelTestAssertEqual(
                _renderer.route_progress_cap,
                BLADE_STAGE1_FOREST_FIRST_HALF_CAP,
                "first-half travel cannot reveal the World Tree early"
            );
            BladeStage1ForestApplyRouteCue(
                _renderer, "cue.stage1.midboss_stop"
            );
            BladeKernelTestAssertFalse(
                _renderer.route_scroll_enabled,
                "midboss cue deliberately stops forward travel"
            );
            BladeStage1ForestApplyRouteCue(
                _renderer, "cue.stage1.forest_resume"
            );
            BladeKernelTestAssertEqual(
                _renderer.route_progress_cap,
                BLADE_STAGE1_FOREST_SECOND_HALF_CAP,
                "second-half travel owns a later bounded segment"
            );
            _renderer.route_progress = 134;
            BladeStage1ForestApplyRouteCue(
                _renderer, "cue.stage1.world_tree_approach"
            );
            BladeKernelTestAssertEqual(
                _renderer.route_progress_cap, _renderer.route_progress_limit,
                "World Tree approach unlocks the authored endpoint"
            );
            BladeKernelTestAssertTrue(
                _renderer.route_scroll_speed
                    >= (218 - 134) / BLADE_STAGE1_WORLD_TREE_TRAVEL_TICKS,
                "approach speed can cover the remaining route in its cue window"
            );
            BladeStage1ForestApplyRouteCue(
                _renderer, "cue.stage1.world_tree_handoff"
            );
            BladeKernelTestAssertEqual(
                _renderer.route_progress, _renderer.route_progress_limit,
                "handoff holds the camera at the exact World Tree endpoint"
            );
            BladeKernelTestAssertFalse(
                _renderer.route_scroll_enabled,
                "World Tree endpoint remains visually stable"
            );
        }
    );

    BladeFirstBeatTestRunCase(
        _state,
        "Stage 1 clears simultaneous solos, shared combo, then resumes",
        function() {
            var _controller = instance_create_layer(
                0, 0, "Instances", o_blade_first_beat_controller
            );
            BladeStage1RouteInitialize(_controller);
            BladeKernelTestAssertTrue(
                _controller.stage_route_enabled,
                "production controller owns the playable Stage executor"
            );
            BladeKernelTestAssertEqual(
                _controller.stage_executor.runtime_kind, "playable",
                "route uses object-backed Stage binding without combat runtime"
            );

            var _record = { ordinary_count: 0, carrier_count: 0 };
            BladeKernelTestAssertTrue(
                _BladeStage1RouteTestsReachDuo(_controller, _record),
                "authored first half reaches Maynii and Kolar"
            );
            BladeKernelTestAssertEqual(
                _record.carrier_count, 1,
                "one bomb carrier precedes the midboss"
            );
            BladeKernelTestAssertEqual(
                _controller.stage_executor.current_node_id,
                "stage_node.stage1.wait_fae_duo",
                "Stage waits on the concrete duo encounter"
            );
            BladeKernelTestAssertEqual(
                array_length(_controller.midboss_state.members), 2,
                "duo director owns exactly two visible fae bodies"
            );

            var _maynii = _controller.midboss_state.members[0];
            var _kolar = _controller.midboss_state.members[1];
            BladeKernelTestAssertEqual(
                _maynii.fae_role, BladeStage1FaeRole.Maynii,
                "first authored participant is Maynii"
            );
            BladeKernelTestAssertEqual(
                _kolar.fae_role, BladeStage1FaeRole.Kolar,
                "second authored participant is Kolar"
            );
            for (var _hold = 0; _hold < 8; ++_hold) {
                BladeStage1RouteAdvance(_controller);
            }
            BladeKernelTestAssertEqual(
                _controller.stage_executor.current_node_id,
                "stage_node.stage1.wait_fae_duo",
                "the route cannot bypass undefeated fae"
            );

            var _player = instance_create_layer(
                320, 300, "Instances", o_ciela_first_beat_player
            );
            _maynii.targetable = true;
            _kolar.targetable = true;
            _maynii.phase_transition_ticks = 0;
            _kolar.phase_transition_ticks = 0;
            _maynii.entry_complete = true;
            _kolar.entry_complete = true;
            _maynii.x = _maynii.anchor_x;
            _maynii.y = _maynii.anchor_y;
            _kolar.x = _kolar.anchor_x;
            _kolar.y = _kolar.anchor_y;
            _maynii.attack_ticks = 53;
            _controller.bomb_clears_this_frame = true;
            BladeStage1MidbossStep(_maynii);
            BladeKernelTestAssertEqual(
                instance_number(o_blade_first_beat_enemy_bullet), 0,
                "an active bomb suppresses fae emission for the whole frame"
            );
            _controller.bomb_clears_this_frame = false;
            _maynii.attack_ticks = 53;
            _kolar.attack_ticks = 63;
            BladeStage1MidbossStep(_maynii);
            BladeStage1MidbossStep(_kolar);
            BladeKernelTestAssertEqual(
                _BladeStage1RouteTestsBulletCount(
                    BladeFirstBeatBulletKind.MayniiLeaf
                ),
                4,
                "Maynii contributes one leaf-wing solo pattern"
            );
            BladeKernelTestAssertEqual(
                _BladeStage1RouteTestsBulletCount(
                    BladeFirstBeatBulletKind.KolarCrystal
                ),
                5,
                "Kolar contributes one mountain-crystal solo pattern"
            );
            BladeStage1MidbossClearPairBullets(_controller);

            var _maynii_solo = BladeStage1MidbossApplyDamage(
                _controller, _maynii, BLADE_STAGE1_MIDBOSS_PERSONAL_HP
            );
            BladeKernelTestAssertTrue(
                _maynii_solo.defeated && _maynii.personal_defeated,
                "Maynii's personal life clears independently"
            );
            BladeKernelTestAssertFalse(
                _controller.midboss_state.combo_active,
                "one cleared solo cannot begin the combination"
            );
            BladeKernelTestAssertTrue(
                _kolar.targetable,
                "Kolar remains live while Maynii waits harmlessly"
            );

            var _kolar_solo = BladeStage1MidbossApplyDamage(
                _controller, _kolar, BLADE_STAGE1_MIDBOSS_PERSONAL_HP
            );
            BladeKernelTestAssertTrue(
                _kolar_solo.defeated && _controller.midboss_state.combo_active,
                "both cleared solos begin the one shared combo"
            );
            BladeKernelTestAssertFalse(
                _maynii.targetable || _kolar.targetable,
                "the shared combo begins with a readable recharge"
            );
            BladeKernelTestAssertEqual(
                _maynii.hit_points, BLADE_STAGE1_MIDBOSS_COMBO_HP,
                "Maynii reforms with the shared combo life"
            );
            BladeKernelTestAssertEqual(
                _kolar.hit_points, BLADE_STAGE1_MIDBOSS_COMBO_HP,
                "Kolar reforms with the same combo life"
            );

            _maynii.targetable = true;
            _kolar.targetable = true;
            _maynii.phase_transition_ticks = 0;
            _kolar.phase_transition_ticks = 0;
            _maynii.attack_ticks = 71;
            _kolar.attack_ticks = 35;
            BladeStage1MidbossStep(_maynii);
            BladeStage1MidbossStep(_kolar);
            BladeKernelTestAssertEqual(
                _BladeStage1RouteTestsBulletCount(
                    BladeFirstBeatBulletKind.ComboLeaf
                ),
                8,
                "Maynii's combo half leaves one moving curtain gap"
            );
            BladeKernelTestAssertTrue(
                _BladeStage1RouteTestsBulletsMoveDown(
                    BladeFirstBeatBulletKind.ComboLeaf
                ),
                "Maynii's curtain travels down into Ciela's play space"
            );
            BladeKernelTestAssertEqual(
                _BladeStage1RouteTestsBulletCount(
                    BladeFirstBeatBulletKind.ComboCrystal
                ),
                5,
                "Kolar's combo half answers with one aimed fan"
            );
            BladeStage1MidbossClearPairBullets(_controller);

            BladeStage1MidbossApplyDamage(_controller, _maynii, 25);
            BladeKernelTestAssertEqual(
                _maynii.hit_points, 125,
                "combo damage reduces the struck body"
            );
            BladeKernelTestAssertEqual(
                _kolar.hit_points, 125,
                "combo damage synchronizes the partner body"
            );
            BladeStage1MidbossApplyDamage(_controller, _kolar, 125);
            BladeKernelTestAssertTrue(
                _controller.midboss_state.completed,
                "the shared combo resolves exactly once"
            );
            BladeKernelTestAssertEqual(
                array_length(_controller.stage_defeat_queue), 2,
                "combo resolution reports both authored participants"
            );
            BladeKernelTestAssertEqual(
                _controller.state, BladeFirstBeatState.Playing,
                "midboss defeat does not end Stage 1"
            );

            BladeStage1RouteAdvance(_controller);
            BladeKernelTestAssertEqual(
                _controller.route_cue_id, "cue.stage1.forest_resume",
                "duo completion emits the second-half continuation cue"
            );
            BladeKernelTestAssertEqual(
                _controller.state, BladeFirstBeatState.Playing,
                "second half remains ordinary active gameplay"
            );
            BladeKernelTestAssertEqual(
                _controller.stage_executor.current_node_id,
                "stage_node.stage1.second_half_breath",
                "the same schedule advances beyond the midboss"
            );

            BladeKernelTestAssertTrue(
                _BladeStage1RouteTestsReachHandoff(_controller, _record),
                "second-half encounters reach the stable World Tree handoff"
            );
            BladeKernelTestAssertEqual(
                _record.carrier_count, 2,
                "one bomb carrier appears in each route half"
            );
            BladeKernelTestAssertEqual(
                _controller.stage_executor.lifecycle,
                BladeStageLifecycle.Completed,
                "only the explicit handoff completion ends this slice"
            );
            BladeKernelTestAssertEqual(
                _controller.route_label, "WORLD TREE REACHED",
                "finished slice presents the reached destination"
            );
        }
    );
}
