/// Behavior-focused tests for the first player-visible combat beat.

/// Removes every playable test instance so one failed case cannot poison later cases.
function _BladeFirstBeatTestCleanupInstances() {
    BladeFirstBeatCleanupTransientInstances();
    with (o_blade_first_beat_controller) instance_destroy();
}

/// Runs one instance-aware case with cleanup before entry and on every exit path.
function BladeFirstBeatTestRunCase(_state, _name, _callback) {
    _BladeFirstBeatTestCleanupInstances();
    var _context = { callback: _callback };
    BladeKernelTestRunCase(_state, _name, method(_context, function() {
        try {
            self.callback();
        } finally {
            _BladeFirstBeatTestCleanupInstances();
        }
    }));
}

function BladeFirstCombatBeatTestsRun(_state) {
    BladeKernelTestRunCase(_state, "first beat movement is bounded and focus is slower", function() {
        var _plane = BladeFirstBeatLoadGameplayPlane();
        var _fast = BladeFirstBeatMovePlayer(
            _plane, 320, 300, 1, -1, false, 6
        );
        var _slow = BladeFirstBeatMovePlayer(
            _plane, 320, 300, 1, -1, true, 6
        );
        BladeKernelTestAssertTrue(
            abs(point_distance(320, 300, _fast.x, _fast.y) - 2.75) < 0.001,
            "unfocused diagonal speed"
        );
        BladeKernelTestAssertTrue(
            abs(point_distance(320, 300, _slow.x, _slow.y) - 1.35) < 0.001,
            "focused diagonal speed"
        );
        var _minimum = BladeFirstBeatMovePlayer(
            _plane, 0, 0, -1, -1, false, 6
        );
        var _maximum = BladeFirstBeatMovePlayer(
            _plane, 640, 500, 1, 1, false, 6
        );
        BladeKernelTestAssertEqual(_minimum.x, 191, "left body bound");
        BladeKernelTestAssertEqual(_minimum.y, 6, "top body bound");
        BladeKernelTestAssertEqual(_maximum.x, 449, "right body bound");
        BladeKernelTestAssertEqual(_maximum.y, 354, "bottom body bound");
    });

    BladeKernelTestRunCase(_state, "Ciela tightens her spread while focused", function() {
        var _broad = BladeFirstBeatCielaSpread(false);
        var _focused = BladeFirstBeatCielaSpread(true);
        BladeKernelTestAssertEqual(array_length(_broad), 5, "broad shot count");
        BladeKernelTestAssertEqual(array_length(_focused), 5, "focused shot count");
        for (var _index = 0; _index < array_length(_broad); ++_index) {
            BladeKernelTestAssertTrue(_broad[_index].y < 0, "broad shot moves upward");
            BladeKernelTestAssertTrue(_focused[_index].y < 0, "focused shot moves upward");
        }
        BladeKernelTestAssertTrue(_broad[0].x > 0, "first broad muzzle fans right");
        BladeKernelTestAssertTrue(_broad[4].x < 0, "last broad muzzle fans left");
        BladeKernelTestAssertTrue(
            abs(_focused[0].x) < abs(_broad[0].x),
            "focused outer muzzle is tighter"
        );
        BladeKernelTestAssertTrue(
            abs(_focused[4].x) < abs(_broad[4].x),
            "focused opposite muzzle is tighter"
        );
    });

    BladeKernelTestRunCase(_state, "held fire repeats on an eight-frame cadence", function() {
        var _cooling = BladeFirstBeatFireCadence(8, true);
        BladeKernelTestAssertFalse(_cooling.fires, "cooldown blocks an early volley");
        BladeKernelTestAssertEqual(_cooling.cooldown, 7, "cooldown advances one frame");
        var _ready = BladeFirstBeatFireCadence(1, true);
        BladeKernelTestAssertTrue(_ready.fires, "held fire repeats when ready");
        BladeKernelTestAssertEqual(_ready.cooldown, 8, "volley resets cadence");
        var _released = BladeFirstBeatFireCadence(1, false);
        BladeKernelTestAssertFalse(_released.fires, "released fire stays quiet");
        BladeKernelTestAssertEqual(_released.cooldown, 0, "released cooldown reaches ready");
    });

    BladeKernelTestRunCase(_state, "projectile anchors use the half-open plane", function() {
        var _plane = BladeFirstBeatLoadGameplayPlane();
        BladeKernelTestAssertTrue(
            BladeCombatPlaneContainsPixelPoint(_plane, 185, 0),
            "minimum anchor is inside"
        );
        BladeKernelTestAssertTrue(
            BladeCombatPlaneContainsPixelPoint(_plane, 454.999, 359.999),
            "interior maximum anchor is inside"
        );
        BladeKernelTestAssertFalse(
            BladeCombatPlaneContainsPixelPoint(_plane, 455, 100),
            "right edge is outside"
        );
        BladeKernelTestAssertFalse(
            BladeCombatPlaneContainsPixelPoint(_plane, 320, 360),
            "bottom edge is outside"
        );
    });

    BladeFirstBeatTestRunCase(
        _state,
        "player shots ignore side exits and clean up only on vertical exits",
        function() {
            var _controller = instance_create_layer(
                0, 0, "Instances", o_blade_first_beat_controller
            );
            var _bounds = BladeCombatPlanePixelBounds(
                _controller.gameplay_plane
            );

            var _ciela_side = instance_create_layer(
                _bounds.left - 40,
                180,
                "Projectiles",
                o_ciela_first_beat_shot
            );
            _ciela_side.velocity_x = -4;
            _ciela_side.velocity_y = -1;
            with (_ciela_side) event_perform(ev_step, ev_step_normal);
            BladeKernelTestAssertTrue(
                instance_exists(_ciela_side),
                "Ciela shot survives beyond the left gameplay edge"
            );

            var _maynii_side = instance_create_layer(
                _bounds.right_exclusive + 40,
                180,
                "Projectiles",
                o_maynii_first_beat_shot
            );
            _maynii_side.tracking = false;
            _maynii_side.velocity_x = 4;
            _maynii_side.velocity_y = -1;
            with (_maynii_side) event_perform(ev_step, ev_step_normal);
            BladeKernelTestAssertTrue(
                instance_exists(_maynii_side),
                "Maynii shot survives beyond the right gameplay edge"
            );

            var _top_exit = instance_create_layer(
                _bounds.left - 40,
                _bounds.top + 0.5,
                "Projectiles",
                o_ciela_first_beat_shot
            );
            _top_exit.velocity_x = -4;
            _top_exit.velocity_y = -1;
            with (_top_exit) event_perform(ev_step, ev_step_normal);
            BladeKernelTestAssertFalse(
                instance_exists(_top_exit),
                "top exit still ends a player shot"
            );

            var _bottom_exit = instance_create_layer(
                _bounds.right_exclusive + 40,
                _bounds.bottom_exclusive - 0.5,
                "Projectiles",
                o_maynii_first_beat_shot
            );
            _bottom_exit.tracking = false;
            _bottom_exit.velocity_x = 4;
            _bottom_exit.velocity_y = 1;
            with (_bottom_exit) event_perform(ev_step, ev_step_normal);
            BladeKernelTestAssertFalse(
                instance_exists(_bottom_exit),
                "bottom exit still ends a player shot"
            );
        }
    );

    BladeFirstBeatTestRunCase(
        _state,
        "hostile bullets cross side gutters and clean up at window edges",
        function() {
            var _controller = instance_create_layer(
                0, 0, "Instances", o_blade_first_beat_controller
            );
            var _bounds = BladeCombatPlanePixelBounds(
                _controller.gameplay_plane
            );

            var _left_gutter = instance_create_layer(
                _bounds.left - 40,
                180,
                "Projectiles",
                o_blade_first_beat_enemy_bullet
            );
            _left_gutter.velocity_x = -1;
            _left_gutter.velocity_y = 0;
            with (_left_gutter) event_perform(ev_step, ev_step_normal);
            BladeKernelTestAssertTrue(
                instance_exists(_left_gutter),
                "hostile bullet survives in the left UI gutter"
            );

            var _right_gutter = instance_create_layer(
                _bounds.right_exclusive + 40,
                180,
                "Projectiles",
                o_blade_first_beat_enemy_bullet
            );
            _right_gutter.velocity_x = 1;
            _right_gutter.velocity_y = 0;
            with (_right_gutter) event_perform(ev_step, ev_step_normal);
            BladeKernelTestAssertTrue(
                instance_exists(_right_gutter),
                "hostile bullet survives in the right UI gutter"
            );

            var _left_exit = instance_create_layer(
                0.5, 180, "Projectiles", o_blade_first_beat_enemy_bullet
            );
            _left_exit.velocity_x = -1;
            _left_exit.velocity_y = 0;
            with (_left_exit) event_perform(ev_step, ev_step_normal);
            BladeKernelTestAssertFalse(
                instance_exists(_left_exit),
                "hostile bullet ends beyond the left window edge"
            );

            var _right_exit = instance_create_layer(
                room_width - 0.5,
                180,
                "Projectiles",
                o_blade_first_beat_enemy_bullet
            );
            _right_exit.velocity_x = 1;
            _right_exit.velocity_y = 0;
            with (_right_exit) event_perform(ev_step, ev_step_normal);
            BladeKernelTestAssertFalse(
                instance_exists(_right_exit),
                "hostile bullet ends beyond the right window edge"
            );

            var _top_exit = instance_create_layer(
                320, 0.5, "Projectiles", o_blade_first_beat_enemy_bullet
            );
            _top_exit.velocity_x = 0;
            _top_exit.velocity_y = -1;
            with (_top_exit) event_perform(ev_step, ev_step_normal);
            BladeKernelTestAssertFalse(
                instance_exists(_top_exit),
                "hostile bullet ends beyond the top window edge"
            );

            var _bottom_exit = instance_create_layer(
                320,
                room_height - 0.5,
                "Projectiles",
                o_blade_first_beat_enemy_bullet
            );
            _bottom_exit.velocity_x = 0;
            _bottom_exit.velocity_y = 1;
            with (_bottom_exit) event_perform(ev_step, ev_step_normal);
            BladeKernelTestAssertFalse(
                instance_exists(_bottom_exit),
                "hostile bullet ends beyond the bottom window edge"
            );
        }
    );

    BladeKernelTestRunCase(_state, "enemy fire uses its current full hurtbox", function() {
        var _plane = BladeFirstBeatLoadGameplayPlane();
        BladeKernelTestAssertTrue(
            BladeCombatPlaneContainsPixelCircle(_plane, 320, 72, 14),
            "in-plane enemy can fire"
        );
        BladeKernelTestAssertFalse(
            BladeCombatPlaneContainsPixelCircle(_plane, 320, 10, 14),
            "top overlap cannot fire"
        );
        BladeKernelTestAssertTrue(
            BladeCombatPlaneContainsPixelCircle(_plane, 199, 100, 14),
            "left contained edge can fire"
        );
        BladeKernelTestAssertFalse(
            BladeCombatPlaneContainsPixelCircle(_plane, 198, 100, 14),
            "left outside edge cannot fire"
        );
    });

    BladeKernelTestRunCase(_state, "damage and outcomes resolve exactly once", function() {
        var _survived = BladeFirstBeatDamageResult(12, 5);
        BladeKernelTestAssertEqual(_survived.remaining, 7, "damage reduces health");
        BladeKernelTestAssertFalse(_survived.defeated, "positive health survives");
        var _defeated = BladeFirstBeatDamageResult(4, 10);
        BladeKernelTestAssertEqual(_defeated.remaining, 0, "damage clamps at zero");
        BladeKernelTestAssertEqual(_defeated.applied, 4, "damage reports actual loss");
        BladeKernelTestAssertTrue(_defeated.defeated, "zero health defeats target");

        var _rewarding = BladeFirstBeatTransition(
            BladeFirstBeatState.Playing, BladeFirstBeatEvent.EnemyDefeated
        );
        BladeKernelTestAssertEqual(
            _rewarding, BladeFirstBeatState.Rewarding,
            "defeat opens reward collection"
        );
        var _won = BladeFirstBeatTransition(
            _rewarding, BladeFirstBeatEvent.RewardsCollected
        );
        BladeKernelTestAssertEqual(_won, BladeFirstBeatState.Won, "rewards finish beat");
        BladeKernelTestAssertEqual(
            BladeFirstBeatTransition(_won, BladeFirstBeatEvent.PlayerOutOfLives),
            BladeFirstBeatState.Won,
            "finished outcome is stable"
        );
        BladeKernelTestAssertEqual(
            BladeFirstBeatTransition(_won, BladeFirstBeatEvent.Retry),
            BladeFirstBeatState.Playing,
            "retry starts a fresh beat"
        );
    });

    BladeFirstBeatTestRunCase(_state, "a player shot damages a live enemy instance", function() {
        var _controller = instance_create_layer(
            0, 0, "Instances", o_blade_first_beat_controller
        );
        var _enemy = instance_create_layer(
            320, 100, "Instances", o_blade_first_beat_enemy
        );
        var _shot = instance_create_layer(
            320, 100, "Instances", o_ciela_first_beat_shot
        );
        with (_shot) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertTrue(
            variable_instance_exists(_enemy, "hit_points"),
            "enemy owns instance hit points"
        );
        BladeKernelTestAssertEqual(_enemy.hit_points, 34, "impact applies shot damage");
        with (_enemy) instance_destroy();
        with (_controller) instance_destroy();
    });

    BladeFirstBeatTestRunCase(_state, "ordinary defeat preserves each owned bullet lifetime", function() {
        var _controller = instance_create_layer(
            0, 0, "Instances", o_blade_first_beat_controller
        );
        var _enemy = instance_create_layer(
            320, 100, "Instances", o_blade_first_beat_enemy
        );
        _enemy.stage_managed = true;
        _enemy.stage_instance_id = "ordinary-persistence-test";
        _enemy.archetype_id = "enemy.ordinary";
        var _owned = instance_create_layer(
            320, 100, "Projectiles", o_blade_first_beat_enemy_bullet
        );
        _owned.owner_stage_instance_id = _enemy.stage_instance_id;
        _owned.velocity_x = 1;
        _owned.velocity_y = 0;
        var _unrelated = instance_create_layer(
            340, 100, "Projectiles", o_blade_first_beat_enemy_bullet
        );
        _unrelated.owner_stage_instance_id = "another-participant";
        BladeKernelTestAssertFalse(
            _enemy.auto_cancel_bullets_on_defeat,
            "ordinary target has no defeat conversion privilege"
        );
        var _defeat = BladeFirstBeatApplyPlayerShot(
            _controller, _enemy, _enemy.hit_points
        );
        BladeKernelTestAssertTrue(_defeat.defeated, "ordinary target is defeated");
        BladeKernelTestAssertTrue(
            instance_exists(_owned) && instance_exists(_unrelated),
            "ordinary defeat preserves owned and unrelated bullets"
        );
        var _before_x = _owned.x;
        with (_owned) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertTrue(_owned.x > _before_x, "owned bullet keeps moving");
        _owned.x = -1;
        _owned.velocity_x = -1;
        with (_owned) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertFalse(
            instance_exists(_owned), "owned bullet still cleans up at its edge"
        );
        BladeKernelTestAssertTrue(
            instance_exists(_unrelated), "unrelated bullet remains independent"
        );
    });

    BladeFirstBeatTestRunCase(_state, "items fall, focus vacuums, and Hyper collects immediately", function() {
        var _controller = instance_create_layer(
            0, 0, "Instances", o_blade_first_beat_controller
        );
        var _player = instance_create_layer(
            320, 300, "Instances", o_ciela_first_beat_player
        );
        _player.focused = false;
        var _normal = instance_create_layer(
            320, 214, "Items", o_blade_reward_item
        );
        with (_normal) event_perform(ev_step, ev_step_normal);
        var _normal_y = _normal.y;
        _player.focused = true;
        var _focused = instance_create_layer(
            320, 214, "Items", o_blade_reward_item
        );
        with (_focused) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertTrue(
            _normal_y > 214 && _focused.y > _normal_y,
            "normal items fall while Focus pulls from farther away"
        );
        _controller.economy.active_hyper_tier = 1;
        var _score_before = _controller.economy.score;
        var _hyper = instance_create_layer(
            200, 40, "Items", o_blade_reward_item
        );
        with (_hyper) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertFalse(
            instance_exists(_hyper), "active Hyper collects a distant point item"
        );
        BladeKernelTestAssertTrue(
            _controller.economy.score > _score_before,
            "Hyper collection awards visible score"
        );
    });

    BladeFirstBeatTestRunCase(_state, "items continue through hit response, respawn, and Game Over", function() {
        var _controller = instance_create_layer(
            0, 0, "Instances", o_blade_first_beat_controller
        );
        instance_create_layer(
            320, 300, "Instances", o_ciela_first_beat_player
        );
        var _response_item = instance_create_layer(
            320, 240, "Items", o_blade_reward_item
        );
        _controller.player_phase = BladeSurvivalPlayerPhase.HitResponse;
        var _response_y = _response_item.y;
        with (_response_item) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertTrue(
            _response_item.y > _response_y,
            "items fall during hit response"
        );
        var _respawn_item = instance_create_layer(
            320, 250, "Items", o_blade_reward_item
        );
        _controller.hit_response_ticks = 1;
        with (_controller) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertEqual(
            _controller.player_phase, BladeSurvivalPlayerPhase.Respawning,
            "committed first death enters respawn"
        );
        var _respawn_y = _respawn_item.y;
        with (_respawn_item) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertTrue(
            _respawn_item.y > _respawn_y,
            "items keep falling during respawn"
        );
        var _game_over_item = instance_create_layer(
            320, 250, "Items", o_blade_reward_item
        );
        _controller.economy.lives = 1;
        _controller.player_phase = BladeSurvivalPlayerPhase.HitResponse;
        _controller.hit_response_ticks = 1;
        with (_controller) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertEqual(
            _controller.state, BladeFirstBeatState.Failed,
            "last life reaches Game Over"
        );
        var _game_over_y = _game_over_item.y;
        with (_game_over_item) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertTrue(
            _game_over_item.y > _game_over_y,
            "items keep falling during Game Over"
        );
        var _edge_item = instance_create_layer(
            350, 353, "Items", o_blade_reward_item
        );
        _edge_item.velocity_y = 2;
        with (_edge_item) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertFalse(
            instance_exists(_edge_item), "falling items leave without bottom clamping"
        );
    });

    BladeFirstBeatTestRunCase(_state, "a player hit opens the readable response window", function() {
        var _controller = instance_create_layer(
            0, 0, "Instances", o_blade_first_beat_controller
        );
        var _player = instance_create_layer(
            320, 300, "Instances", o_ciela_first_beat_player
        );
        var _bullet = instance_create_layer(
            320, 300, "Instances", o_blade_first_beat_enemy_bullet
        );
        var _shot = instance_create_layer(
            320, 250, "Instances", o_ciela_first_beat_shot
        );
        with (_player) event_perform(ev_step, ev_step_normal);
        with (_shot) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertEqual(
            _controller.state, BladeFirstBeatState.Playing,
            "a first hit does not skip the survival loop"
        );
        BladeKernelTestAssertEqual(
            _controller.player_phase, BladeSurvivalPlayerPhase.HitResponse,
            "collision opens hit response"
        );
        BladeKernelTestAssertFalse(
            instance_exists(_bullet), "the claimed hit bullet is removed"
        );
        BladeKernelTestAssertTrue(
            instance_exists(_shot), "hit response freezes the live shot"
        );
        with (_shot) instance_destroy();
        with (_player) instance_destroy();
        with (_controller) instance_destroy();
    });

    BladeKernelTestRunCase(_state, "sprite-free collision uses both radii", function() {
        BladeKernelTestAssertTrue(
            BladeFirstBeatCirclesOverlap(100, 100, 3, 106, 100, 3),
            "touching circles collide"
        );
        BladeKernelTestAssertFalse(
            BladeFirstBeatCirclesOverlap(100, 100, 3, 107, 100, 3),
            "separated circles miss"
        );
    });
}
