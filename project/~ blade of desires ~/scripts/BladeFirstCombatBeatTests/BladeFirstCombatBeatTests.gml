/// Behavior-focused tests for the first player-visible combat beat.

function BladeFirstCombatBeatTestsRun(_state) {
    BladeKernelTestRunCase(_state, "first beat movement is bounded and focus is slower", function() {
        var _fast = BladeFirstBeatMovePlayer(320, 300, 1, -1, false);
        var _slow = BladeFirstBeatMovePlayer(320, 300, 1, -1, true);
        BladeKernelTestAssertTrue(
            abs(point_distance(320, 300, _fast.x, _fast.y) - 2.75) < 0.001,
            "unfocused diagonal speed"
        );
        BladeKernelTestAssertTrue(
            abs(point_distance(320, 300, _slow.x, _slow.y) - 1.35) < 0.001,
            "focused diagonal speed"
        );
        var _minimum = BladeFirstBeatMovePlayer(0, 0, -1, -1, false);
        var _maximum = BladeFirstBeatMovePlayer(640, 500, 1, 1, false);
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
        BladeKernelTestAssertTrue(
            BladeFirstBeatPointInsidePlane(185, 0), "minimum anchor is inside"
        );
        BladeKernelTestAssertTrue(
            BladeFirstBeatPointInsidePlane(454.999, 359.999),
            "interior maximum anchor is inside"
        );
        BladeKernelTestAssertFalse(
            BladeFirstBeatPointInsidePlane(455, 100), "right edge is outside"
        );
        BladeKernelTestAssertFalse(
            BladeFirstBeatPointInsidePlane(320, 360), "bottom edge is outside"
        );
    });

    BladeKernelTestRunCase(_state, "enemy fire uses its current full hurtbox", function() {
        BladeKernelTestAssertTrue(
            BladeFirstBeatHurtboxCanFire(320, 72, 14),
            "in-plane enemy can fire"
        );
        BladeKernelTestAssertFalse(
            BladeFirstBeatHurtboxCanFire(320, 10, 14),
            "top overlap cannot fire"
        );
        BladeKernelTestAssertTrue(
            BladeFirstBeatHurtboxCanFire(199, 100, 14),
            "left contained edge can fire"
        );
        BladeKernelTestAssertFalse(
            BladeFirstBeatHurtboxCanFire(198, 100, 14),
            "left outside edge cannot fire"
        );
    });

    BladeKernelTestRunCase(_state, "damage and outcomes resolve exactly once", function() {
        var _survived = BladeFirstBeatDamageResult(12, 5);
        BladeKernelTestAssertEqual(_survived.remaining, 7, "damage reduces health");
        BladeKernelTestAssertFalse(_survived.defeated, "positive health survives");
        var _defeated = BladeFirstBeatDamageResult(4, 10);
        BladeKernelTestAssertEqual(_defeated.remaining, 0, "damage clamps at zero");
        BladeKernelTestAssertTrue(_defeated.defeated, "zero health defeats target");

        var _won = BladeFirstBeatTransition(
            BladeFirstBeatState.Playing, BladeFirstBeatEvent.EnemyDefeated
        );
        BladeKernelTestAssertEqual(_won, BladeFirstBeatState.Won, "defeat wins beat");
        BladeKernelTestAssertEqual(
            BladeFirstBeatTransition(_won, BladeFirstBeatEvent.PlayerHit),
            BladeFirstBeatState.Won,
            "finished outcome is stable"
        );
        BladeKernelTestAssertEqual(
            BladeFirstBeatTransition(_won, BladeFirstBeatEvent.Retry),
            BladeFirstBeatState.Playing,
            "retry starts a fresh beat"
        );
    });

    BladeKernelTestRunCase(_state, "a player shot damages a live enemy instance", function() {
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
    });

    BladeKernelTestRunCase(_state, "a player hit fails the beat and cleans projectiles", function() {
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
        BladeKernelTestAssertEqual(
            _controller.state, BladeFirstBeatState.Failed, "collision fails beat"
        );
        BladeKernelTestAssertFalse(
            instance_exists(_bullet), "enemy bullets are cleaned"
        );
        BladeKernelTestAssertFalse(
            instance_exists(_shot), "player shots are cleaned"
        );
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
