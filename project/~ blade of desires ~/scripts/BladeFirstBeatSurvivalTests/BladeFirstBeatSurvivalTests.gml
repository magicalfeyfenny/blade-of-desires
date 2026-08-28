/// Behavior-focused tests for the playable score, reward, and survival loop.

function BladeFirstBeatSurvivalTestsRun(_state) {
    BladeKernelTestRunCase(_state, "survival attempt starts with explicit canonical tuning", function() {
        var _economy = BladeSurvivalEconomyCreate();
        BladeKernelTestAssertEqual(_economy.score, 0, "score starts empty");
        BladeKernelTestAssertEqual(
            _economy.lives, BLADE_SURVIVAL_STARTING_LIVES,
            "three starting lives"
        );
        BladeKernelTestAssertEqual(
            _economy.bombs, BLADE_SURVIVAL_STARTING_BOMBS,
            "three starting bombs"
        );
        BladeKernelTestAssertEqual(_economy.hyper_meter, 0, "Hyper starts empty");
        var _thresholds = BladeSurvivalLifeThresholds();
        BladeKernelTestAssertEqual(array_length(_thresholds), 3, "three extends");
        BladeKernelTestAssertTrue(
            _thresholds[0] < _thresholds[1]
                && _thresholds[1] < _thresholds[2],
            "extend thresholds strictly increase"
        );
    });

    BladeKernelTestRunCase(_state, "one score jump grants all three one-shot extends", function() {
        var _economy = BladeSurvivalEconomyCreate();
        var _first = BladeSurvivalApplyScore(
            _economy, BLADE_SURVIVAL_LIFE_THRESHOLD_3
        );
        BladeKernelTestAssertEqual(_first.life_awards, 3, "jump crosses three");
        BladeKernelTestAssertEqual(_economy.lives, 6, "three extends add once");
        var _again = BladeSurvivalApplyScore(_economy, 1);
        BladeKernelTestAssertEqual(_again.life_awards, 0, "claimed extends stay claimed");
        BladeKernelTestAssertEqual(_economy.lives, 6, "repeat adds no lives");
    });

    BladeKernelTestRunCase(_state, "point pickups score and raise the next point value", function() {
        var _economy = BladeSurvivalEconomyCreate();
        var _first = BladeSurvivalCollectPointItem(_economy);
        BladeKernelTestAssertEqual(
            _first.collected_value, BLADE_SURVIVAL_STARTING_POINT_VALUE,
            "pickup uses current point value"
        );
        BladeKernelTestAssertEqual(
            _economy.score, BLADE_SURVIVAL_STARTING_POINT_VALUE,
            "pickup adds visible score"
        );
        BladeKernelTestAssertEqual(
            _economy.point_value,
            BLADE_SURVIVAL_STARTING_POINT_VALUE
                + BLADE_SURVIVAL_POINT_VALUE_STEP,
            "next pickup is worth more"
        );
    });

    BladeKernelTestRunCase(_state, "one hostile bullet can graze only once", function() {
        var _economy = BladeSurvivalEconomyCreate();
        var _bullet = { grazed: false };
        BladeKernelTestAssertTrue(
            BladeSurvivalTryGrazeBullet(_economy, _bullet),
            "first near miss claims graze"
        );
        var _score = _economy.score;
        var _meter = _economy.hyper_meter;
        BladeKernelTestAssertFalse(
            BladeSurvivalTryGrazeBullet(_economy, _bullet),
            "same bullet cannot graze twice"
        );
        BladeKernelTestAssertEqual(_economy.score, _score, "score stays once");
        BladeKernelTestAssertEqual(
            _economy.hyper_meter, _meter, "meter stays once"
        );
    });

    BladeKernelTestRunCase(_state, "only defeat rewards and the carrier owns the bomb drop", function() {
        var _defeat_economy = BladeSurvivalEconomyCreate();
        var _defeat = BladeSurvivalResolveEnemyExit(
            _defeat_economy, BladeSurvivalEnemyExitReason.Defeated, true
        );
        BladeKernelTestAssertTrue(_defeat.rewarded, "HP defeat rewards");
        BladeKernelTestAssertEqual(_defeat.point_item_count, 5, "five point drops");
        BladeKernelTestAssertEqual(
            _defeat.bomb_item_count,
            BLADE_SURVIVAL_CARRIER_BOMB_ITEM_COUNT,
            "carrier drops its one reusable bomb item"
        );
        BladeKernelTestAssertTrue(
            BladeSurvivalEnemyIsBombCarrier(BLADE_SURVIVAL_BOMB_CARRIER_ID),
            "carrier identity owns the drop"
        );

        var _cleanup_economy = BladeSurvivalEconomyCreate();
        var _cleanup = BladeSurvivalResolveEnemyExit(
            _cleanup_economy, BladeSurvivalEnemyExitReason.Cleanup, true
        );
        BladeKernelTestAssertFalse(_cleanup.rewarded, "cleanup is not defeat");
        BladeKernelTestAssertEqual(_cleanup_economy.score, 0, "cleanup gives no score");
        BladeKernelTestAssertEqual(
            _cleanup.bomb_item_count, 0, "cleanup gives no bomb"
        );

        var _ordinary = BladeSurvivalResolveEnemyExit(
            BladeSurvivalEconomyCreate(),
            BladeSurvivalEnemyExitReason.Defeated,
            false
        );
        BladeKernelTestAssertEqual(
            _ordinary.bomb_item_count, 0, "non-carrier defeat gives no bomb"
        );
    });

    BladeKernelTestRunCase(_state, "bomb pickups stock to cap then use explicit overflow", function() {
        var _economy = BladeSurvivalEconomyCreate();
        _economy.bombs = BLADE_SURVIVAL_BOMB_CAP - 1;
        var _stocked = BladeSurvivalCollectBomb(_economy);
        BladeKernelTestAssertTrue(_stocked.stocked, "pickup fills final stock");
        BladeKernelTestAssertEqual(
            _economy.bombs, BLADE_SURVIVAL_BOMB_CAP, "stock stops at cap"
        );
        var _overflow = BladeSurvivalCollectBomb(_economy);
        BladeKernelTestAssertFalse(_overflow.stocked, "full pickup overflows");
        BladeKernelTestAssertEqual(
            _economy.bombs, BLADE_SURVIVAL_BOMB_CAP, "overflow keeps cap"
        );
        BladeKernelTestAssertEqual(
            _overflow.overflow_score, 10000, "overflow has explicit score"
        );

        _economy.active_hyper_tier = 3;
        var _hyper_overflow = BladeSurvivalCollectBomb(_economy);
        BladeKernelTestAssertEqual(
            _hyper_overflow.overflow_score, 40000,
            "overflow reports the actual Hyper-multiplied award"
        );
    });

    BladeKernelTestRunCase(_state, "bomb spends once, protects, clears, and cancels Hyper", function() {
        var _economy = BladeSurvivalEconomyCreate();
        _economy.score = 1000;
        _economy.active_hyper_tier = 2;
        _economy.hyper_ticks = 360;
        var _bomb = BladeSurvivalUseBomb(_economy, false);
        BladeKernelTestAssertTrue(_bomb.used, "stocked bomb activates");
        BladeKernelTestAssertEqual(_economy.bombs, 2, "normal bomb spends one");
        BladeKernelTestAssertEqual(_economy.score, 800, "bomb applies score cost");
        BladeKernelTestAssertEqual(
            _economy.bomb_ticks, BLADE_SURVIVAL_NORMAL_BOMB_TICKS,
            "bomb owns protection window"
        );
        BladeKernelTestAssertEqual(
            _economy.active_hyper_tier, 0, "bomb cancels Hyper"
        );
        BladeKernelTestAssertFalse(
            BladeSurvivalUseBomb(_economy, false).used,
            "active bomb cannot spend twice"
        );
    });

    BladeKernelTestRunCase(_state, "bomb and respawn protection both reject player hits", function() {
        var _controller = {
            state: BladeFirstBeatState.Playing,
            player_phase: BladeSurvivalPlayerPhase.Active,
            invulnerable_ticks: 0,
            hit_response_ticks: 0,
            feedback_text: "",
            feedback_ticks: 0,
            economy: BladeSurvivalEconomyCreate(),
        };
        _controller.economy.bomb_ticks = 1;
        BladeKernelTestAssertFalse(
            BladeSurvivalBeginPlayerHit(_controller),
            "active bomb rejects a hit"
        );
        BladeKernelTestAssertEqual(
            _controller.player_phase,
            BladeSurvivalPlayerPhase.Active,
            "bomb protection keeps control active"
        );

        _controller.economy.bomb_ticks = 0;
        _controller.invulnerable_ticks = 1;
        BladeKernelTestAssertFalse(
            BladeSurvivalBeginPlayerHit(_controller),
            "respawn invulnerability rejects a hit"
        );
        BladeKernelTestAssertEqual(
            _controller.player_phase,
            BladeSurvivalPlayerPhase.Active,
            "respawn protection keeps control active"
        );
    });

    BladeKernelTestRunCase(_state, "all three Hyper tiers change concrete offense", function() {
        var _thresholds = [
            BLADE_SURVIVAL_HYPER_TIER_1,
            BLADE_SURVIVAL_HYPER_TIER_2,
            BLADE_SURVIVAL_HYPER_TIER_3,
        ];
        for (var _tier = 1; _tier <= 3; ++_tier) {
            var _economy = BladeSurvivalEconomyCreate();
            _economy.hyper_meter = _thresholds[_tier - 1];
            var _activation = BladeSurvivalTryActivateHyper(_economy);
            BladeKernelTestAssertTrue(_activation.activated, "tier activates");
            BladeKernelTestAssertEqual(_activation.tier, _tier, "highest tier selected");
            BladeKernelTestAssertEqual(
                _economy.hyper_ticks, BladeSurvivalHyperDuration(_tier),
                "tier has authored duration"
            );
            BladeKernelTestAssertEqual(
                BladeSurvivalPlayerShotDamage(_economy),
                2 * (_tier + 1),
                "tier strengthens real shot damage"
            );
            var _score = BladeSurvivalApplyScore(_economy, 10);
            BladeKernelTestAssertEqual(
                _score.score, 10 * (_tier + 1),
                "tier strengthens real scoring"
            );
        }
    });

    BladeKernelTestRunCase(_state, "X gives stocked Hyper priority over Bomb", function() {
        var _economy = BladeSurvivalEconomyCreate();
        _economy.hyper_meter = BLADE_SURVIVAL_HYPER_TIER_1;
        BladeKernelTestAssertEqual(
            BladeSurvivalPowerActionForX(_economy, false),
            BladeSurvivalPowerAction.Hyper,
            "plain X selects ready Hyper"
        );
        BladeKernelTestAssertEqual(
            BladeSurvivalPowerActionForX(_economy, true),
            BladeSurvivalPowerAction.Hyper,
            "hit response also selects ready Hyper"
        );
        var _hyper = BladeSurvivalTryActivateHyper(_economy);
        BladeKernelTestAssertTrue(_hyper.activated, "ready Hyper activates");
        BladeKernelTestAssertEqual(_economy.bombs, 3, "Hyper spends no bomb");
        BladeKernelTestAssertEqual(
            BladeSurvivalPowerActionForX(_economy, false),
            BladeSurvivalPowerAction.Bomb,
            "X can cancel an active Hyper with Bomb"
        );
        _economy.active_hyper_tier = 0;
        _economy.bombs = 0;
        BladeKernelTestAssertEqual(
            BladeSurvivalPowerActionForX(_economy, true),
            BladeSurvivalPowerAction.None,
            "empty stock exposes no false hit-response defense"
        );
    });

    BladeFirstBeatTestRunCase(_state, "playable path consumes the canonical keyboard controls", function() {
        var _controller = instance_create_layer(
            0, 0, "Instances", o_blade_first_beat_controller
        );
        var _bindings = _controller.keyboard_bindings;
        BladeKernelTestAssertEqual(
            variable_struct_get(_bindings, "input.move_up"),
            vk_up,
            "movement uses arrows"
        );
        BladeKernelTestAssertEqual(
            variable_struct_get(_bindings, "input.fire"),
            ord("Z"),
            "fire uses Z"
        );
        BladeKernelTestAssertEqual(
            variable_struct_get(_bindings, "input.bomb"),
            ord("X"),
            "power uses X"
        );
        BladeKernelTestAssertEqual(
            variable_struct_get(_bindings, "input.focus"),
            vk_shift,
            "focus uses Shift"
        );
        with (_controller) instance_destroy();
    });

    BladeKernelTestRunCase(_state, "emergency bomb spends all stock inside hit response", function() {
        var _economy = BladeSurvivalEconomyCreate();
        _economy.bombs = 2;
        var _emergency = BladeSurvivalUseBomb(_economy, true);
        BladeKernelTestAssertTrue(_emergency.used, "response bomb activates");
        BladeKernelTestAssertEqual(_emergency.spent, 2, "all stock is spent");
        BladeKernelTestAssertEqual(_economy.bombs, 0, "stock reaches zero");
        BladeKernelTestAssertEqual(
            _economy.bomb_ticks, BLADE_SURVIVAL_EMERGENCY_BOMB_TICKS,
            "emergency window is powered"
        );
    });

    BladeKernelTestRunCase(_state, "committed death resets resources but preserves shot strength", function() {
        var _economy = BladeSurvivalEconomyCreate();
        _economy.score = 1000;
        _economy.bombs = 1;
        _economy.hyper_meter = 200;
        _economy.active_hyper_tier = 2;
        _economy.hyper_ticks = 100;
        _economy.bomb_ticks = 20;
        _economy.shot_strength = 3;
        var _death = BladeSurvivalCommitDeath(_economy);
        BladeKernelTestAssertFalse(_death.game_over, "first death can respawn");
        BladeKernelTestAssertEqual(_economy.lives, 2, "one life is removed");
        BladeKernelTestAssertEqual(_economy.score, 500, "death halves score");
        BladeKernelTestAssertEqual(_economy.bombs, 3, "death resets bombs to three");
        BladeKernelTestAssertEqual(_economy.hyper_meter, 0, "stocked Hyper resets");
        BladeKernelTestAssertEqual(_economy.active_hyper_tier, 0, "active Hyper ends");
        BladeKernelTestAssertEqual(_economy.bomb_ticks, 0, "active bomb ends");
        BladeKernelTestAssertEqual(_economy.shot_strength, 3, "shot strength remains");
    });

    BladeFirstBeatTestRunCase(_state, "a real near miss grazes once and a real hit opens response", function() {
        var _controller = instance_create_layer(
            0, 0, "Instances", o_blade_first_beat_controller
        );
        var _player = instance_create_layer(
            320, 314, "Instances", o_ciela_first_beat_player
        );
        var _graze = instance_create_layer(
            332, 314, "Instances", o_blade_first_beat_enemy_bullet
        );
        with (_player) event_perform(ev_step, ev_step_normal);
        with (_player) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertEqual(_controller.economy.score, 100, "graze scores once");
        BladeKernelTestAssertTrue(_graze.grazed, "bullet records graze");

        var _hit = instance_create_layer(
            320, 314, "Instances", o_blade_first_beat_enemy_bullet
        );
        with (_player) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertEqual(
            _controller.player_phase, BladeSurvivalPlayerPhase.HitResponse,
            "lethal overlap opens response"
        );
        BladeKernelTestAssertEqual(
            _controller.economy.score, 100, "hit does not also graze"
        );
        BladeKernelTestAssertFalse(instance_exists(_hit), "hit bullet is claimed");
        with (o_blade_first_beat_enemy_bullet) instance_destroy();
        with (_player) instance_destroy();
        with (_controller) instance_destroy();
    });

    BladeFirstBeatTestRunCase(_state, "active bomb clears bullets on consecutive frames", function() {
        var _controller = instance_create_layer(
            0, 0, "Instances", o_blade_first_beat_controller
        );
        _controller.economy.bomb_ticks = 2;
        var _first = instance_create_layer(
            320, 200, "Instances", o_blade_first_beat_enemy_bullet
        );
        with (_controller) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertFalse(instance_exists(_first), "existing bullet clears");
        var _second = instance_create_layer(
            320, 200, "Instances", o_blade_first_beat_enemy_bullet
        );
        with (_controller) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertFalse(instance_exists(_second), "new bullet also clears");
        with (_controller) instance_destroy();
    });

    BladeFirstBeatTestRunCase(_state, "active bomb suppresses final-tick enemy emission", function() {
        var _controller = instance_create_layer(
            0, 0, "Instances", o_blade_first_beat_controller
        );
        var _player = instance_create_layer(
            320, 314, "Instances", o_ciela_first_beat_player
        );
        var _enemy = instance_create_layer(
            320, 72, "Instances", o_blade_first_beat_enemy
        );
        _enemy.y = _enemy.target_y;
        _enemy.tell_ticks = 0;
        _enemy.fire_cooldown = 0;
        _controller.economy.bomb_ticks = 1;
        with (_controller) event_perform(ev_step, ev_step_normal);
        with (_enemy) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertEqual(
            instance_number(o_blade_first_beat_enemy_bullet), 0,
            "enemy cannot refill bullets after the final bomb sweep"
        );
        with (_enemy) instance_destroy();
        with (_player) instance_destroy();
        with (_controller) instance_destroy();
    });

    BladeFirstBeatTestRunCase(_state, "Hyper clears on expiry but not continuously", function() {
        var _controller = instance_create_layer(
            0, 0, "Instances", o_blade_first_beat_controller
        );
        _controller.economy.active_hyper_tier = 1;
        _controller.economy.hyper_ticks = 2;
        var _during = instance_create_layer(
            320, 200, "Instances", o_blade_first_beat_enemy_bullet
        );
        with (_controller) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertTrue(
            instance_exists(_during),
            "active Hyper does not continuously erase bullets"
        );
        var _ending = instance_create_layer(
            340, 200, "Instances", o_blade_first_beat_enemy_bullet
        );
        with (_controller) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertFalse(
            instance_exists(_during) || instance_exists(_ending),
            "Hyper expiry performs its one ending clear"
        );
        with (_controller) instance_destroy();
    });

    BladeFirstBeatTestRunCase(_state, "carrier rewards collect naturally and finish the beat", function() {
        var _controller = instance_create_layer(
            0, 0, "Instances", o_blade_first_beat_controller
        );
        var _player = instance_create_layer(
            320, 314, "Instances", o_ciela_first_beat_player
        );
        var _enemy = instance_create_layer(
            320, 100, "Instances", o_blade_first_beat_enemy
        );
        _enemy.hit_points = 2;
        var _shot = instance_create_layer(
            320, 100, "Instances", o_ciela_first_beat_shot
        );
        with (_shot) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertEqual(
            _controller.state, BladeFirstBeatState.Rewarding,
            "defeat enters reward collection"
        );
        BladeKernelTestAssertEqual(
            instance_number(o_blade_reward_item), 6,
            "five point items and one carrier bomb item exist"
        );
        BladeKernelTestAssertFalse(instance_exists(_enemy), "carrier is removed");
        var _score_before_pickups = _controller.economy.score;
        for (var _reward_frame = 0;
            _reward_frame < 360
                && instance_number(o_blade_reward_item) > 0;
            ++_reward_frame) {
            with (o_blade_reward_item) {
                event_perform(ev_step, ev_step_normal);
            }
        }
        BladeKernelTestAssertEqual(
            instance_number(o_blade_reward_item), 0,
            "every naturally falling reward reaches Ciela"
        );
        BladeKernelTestAssertEqual(
            _controller.economy.point_value, 2250,
            "five pickups raise the next point value"
        );
        BladeKernelTestAssertEqual(
            _controller.economy.bombs, BLADE_SURVIVAL_STARTING_BOMBS + 1,
            "carrier pickup adds its one bomb stock"
        );
        BladeKernelTestAssertEqual(
            _controller.economy.score - _score_before_pickups,
            7500,
            "five increasing point pickups award their visible values"
        );
        _controller.reward_wait_ticks = 1;
        with (_controller) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertEqual(
            _controller.state, BladeFirstBeatState.Won,
            "collected rewards finish the encounter"
        );
    });

    BladeFirstBeatTestRunCase(_state, "expired response commits exact respawn state", function() {
        var _controller = instance_create_layer(
            0, 0, "Instances", o_blade_first_beat_controller
        );
        var _player = instance_create_layer(
            250, 180, "Instances", o_ciela_first_beat_player
        );
        _controller.economy.score = 1000;
        _controller.economy.bombs = 1;
        _controller.economy.hyper_meter = 200;
        _controller.economy.shot_strength = 3;
        _controller.player_phase = BladeSurvivalPlayerPhase.HitResponse;
        _controller.hit_response_ticks = 1;
        with (_controller) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertEqual(_controller.economy.lives, 2, "life commits once");
        BladeKernelTestAssertEqual(_controller.economy.bombs, 3, "bombs reset exactly");
        BladeKernelTestAssertEqual(_controller.economy.hyper_meter, 0, "Hyper resets exactly");
        BladeKernelTestAssertEqual(
            _controller.economy.shot_strength, 3, "shot strength survives"
        );
        BladeKernelTestAssertEqual(
            _controller.player_phase, BladeSurvivalPlayerPhase.Respawning,
            "control is removed for respawn"
        );
        BladeKernelTestAssertEqual(_player.x, BLADE_SURVIVAL_PLAYER_START_X, "respawn x");
        BladeKernelTestAssertEqual(_player.y, BLADE_SURVIVAL_PLAYER_START_Y, "respawn y");
        BladeKernelTestAssertEqual(
            _controller.invulnerable_ticks, BLADE_SURVIVAL_INVULNERABLE_TICKS,
            "respawn protection is visible"
        );
        with (_player) instance_destroy();
        with (_controller) instance_destroy();
    });

    BladeFirstBeatTestRunCase(_state, "final committed death makes input terminal", function() {
        var _controller = instance_create_layer(
            0, 0, "Instances", o_blade_first_beat_controller
        );
        var _player = instance_create_layer(
            250, 180, "Instances", o_ciela_first_beat_player
        );
        _controller.economy.lives = 1;
        _controller.economy.bombs = 1;
        _controller.economy.hyper_meter = 200;
        _controller.player_phase = BladeSurvivalPlayerPhase.HitResponse;
        _controller.hit_response_ticks = 1;
        with (_controller) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertEqual(
            _controller.state, BladeFirstBeatState.Failed,
            "last life reaches game over"
        );
        BladeKernelTestAssertEqual(
            _controller.player_phase, BladeSurvivalPlayerPhase.Respawning,
            "terminal player cannot accept emergency input"
        );
        BladeKernelTestAssertEqual(_controller.economy.bombs, 3, "final death resets bombs");
        BladeKernelTestAssertEqual(_controller.economy.hyper_meter, 0, "final death resets Hyper");
        with (_player) instance_destroy();
        with (_controller) instance_destroy();
    });

    BladeFirstBeatTestRunCase(_state, "retry cleanup removes transients and restores fresh power", function() {
        var _controller = instance_create_layer(
            0, 0, "Instances", o_blade_first_beat_controller
        );
        instance_create_layer(320, 100, "Instances", o_blade_first_beat_enemy);
        instance_create_layer(
            360, 100, "Instances", o_blade_stage1_fae_midboss
        );
        instance_create_layer(320, 314, "Instances", o_ciela_first_beat_player);
        instance_create_layer(
            320, 180, "Projectiles", o_blade_first_beat_enemy_bullet
        );
        instance_create_layer(
            320, 180, "Projectiles", o_ciela_first_beat_shot
        );
        instance_create_layer(320, 180, "Items", o_blade_reward_item);
        _controller.economy.hyper_meter = 300;
        _controller.economy.bomb_ticks = 20;
        BladeFirstBeatCleanupTransientInstances();
        BladeKernelTestAssertEqual(
            instance_number(o_blade_enemy_target), 0,
            "retry removes ordinary enemies and fae midbosses"
        );
        BladeKernelTestAssertEqual(
            instance_number(o_blade_first_beat_enemy_bullet), 0,
            "retry removes hostile bullets"
        );
        BladeKernelTestAssertEqual(
            instance_number(o_ciela_first_beat_shot), 0,
            "retry removes player shots"
        );
        BladeKernelTestAssertEqual(
            instance_number(o_blade_reward_item), 0,
            "retry removes unclaimed rewards"
        );
        BladeKernelTestAssertEqual(
            instance_number(o_ciela_first_beat_player), 0,
            "retry removes the old player"
        );
        var _fresh = BladeSurvivalEconomyCreate();
        BladeKernelTestAssertEqual(_fresh.awarded_life_mask, 0, "extends reset");
        BladeKernelTestAssertEqual(_fresh.bomb_ticks, 0, "bomb effect resets");
        BladeKernelTestAssertEqual(_fresh.hyper_ticks, 0, "Hyper effect resets");
        BladeKernelTestAssertEqual(_fresh.point_value, 1000, "point value resets");
    });
}
