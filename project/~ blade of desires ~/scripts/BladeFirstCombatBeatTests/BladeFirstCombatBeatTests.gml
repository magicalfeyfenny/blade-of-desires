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
