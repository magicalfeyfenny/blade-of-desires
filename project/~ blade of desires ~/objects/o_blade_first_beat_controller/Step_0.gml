if ((state == BladeFirstBeatState.Won || state == BladeFirstBeatState.Failed)
    && keyboard_check_pressed(ord("R"))) {
    BladeStage1RouteAbort(id, BladeCombatTerminalReason.RunReset);
    state = BladeFirstBeatTransition(state, BladeFirstBeatEvent.Retry);
    BladeFirstBeatCleanupTransientInstances();
    room_restart();
    exit;
}

if (route_notice_ticks > 0) route_notice_ticks -= 1;
var _bomb_was_active = economy.bomb_ticks > 0;
var _hyper_was_active = economy.hyper_ticks > 0;
BladeSurvivalAdvancePowerTimers(economy);
bomb_clears_this_frame = _bomb_was_active || economy.bomb_ticks > 0;
var _hyper_ended_this_frame = _hyper_was_active && economy.hyper_ticks == 0;
if (feedback_ticks > 0) feedback_ticks -= 1;
if (invulnerable_ticks > 0) invulnerable_ticks -= 1;

// An active bomb owns the whole hostile-bullet clearing window, including new fire.
if (bomb_clears_this_frame) {
    with (o_blade_first_beat_enemy_bullet) instance_destroy();
} else if (_hyper_ended_this_frame) {
    // Hyper clears once on expiry; it never owns the continuous bomb sweep.
    with (o_blade_first_beat_enemy_bullet) instance_destroy();
}

var _power_key = variable_struct_get(keyboard_bindings, "input.bomb");

if (player_phase == BladeSurvivalPlayerPhase.HitResponse) {
    if (keyboard_check_pressed(_power_key)) {
        var _response_action = BladeSurvivalPowerActionForX(economy, true);
        if (_response_action == BladeSurvivalPowerAction.EmergencyBomb) {
            var _emergency = BladeSurvivalUseBomb(economy, true);
            BladeStage1AudioPlayForController(
                id, BladeStage1AudioSfx.Bomb, 0.82
            );
            bomb_clears_this_frame = true;
            player_phase = BladeSurvivalPlayerPhase.Active;
            hit_response_ticks = 0;
            feedback_text = "EMERGENCY!\nALL BOMBS SPENT";
            feedback_ticks = 120;
            with (o_blade_first_beat_enemy_bullet) instance_destroy();
        }
    }
    if (player_phase == BladeSurvivalPlayerPhase.HitResponse) {
        hit_response_ticks = max(0, hit_response_ticks - 1);
        if (hit_response_ticks == 0) {
            var _death = BladeSurvivalCommitDeath(economy);
            with (o_blade_first_beat_enemy_bullet) instance_destroy();
            with (o_ciela_first_beat_shot) instance_destroy();
            var _player = instance_find(o_ciela_first_beat_player, 0);
            if (_player != noone) {
                BladeStage1FeedbackSpawn(
                    _player.x,
                    _player.y,
                    BLADE_STAGE1_EFFECT_CIELA,
                    make_color_rgb(98, 232, 255),
                    1.25
                );
                BladeStage1AudioPlayForController(
                    id, BladeStage1AudioSfx.PlayerDeath, 0.92
                );
                _player.x = BLADE_SURVIVAL_PLAYER_START_X;
                _player.y = BLADE_SURVIVAL_PLAYER_START_Y;
                _player.focused = false;
                _player.fire_cooldown = 0;
            }
            if (_death.game_over) {
                state = BladeFirstBeatTransition(
                    state, BladeFirstBeatEvent.PlayerOutOfLives
                );
                player_phase = BladeSurvivalPlayerPhase.Respawning;
                respawn_ticks = 0;
                invulnerable_ticks = 0;
                feedback_text = "NO LIVES REMAIN";
                feedback_ticks = 120;
            } else {
                player_phase = BladeSurvivalPlayerPhase.Respawning;
                respawn_ticks = BLADE_SURVIVAL_RESPAWN_TICKS;
                invulnerable_ticks = BLADE_SURVIVAL_INVULNERABLE_TICKS;
                feedback_text = "LIFE LOST\nBOMBS 3  HYPER 0";
                feedback_ticks = 150;
            }
        }
    }
    exit;
}

if (player_phase == BladeSurvivalPlayerPhase.Respawning) {
    respawn_ticks = max(0, respawn_ticks - 1);
    if (respawn_ticks == 0 && state != BladeFirstBeatState.Failed) {
        player_phase = BladeSurvivalPlayerPhase.Active;
        feedback_text = "RESPAWN PROTECTION";
        feedback_ticks = 90;
    }
    exit;
}

if (state == BladeFirstBeatState.Playing
    || state == BladeFirstBeatState.Rewarding) {
    if (keyboard_check_pressed(_power_key)) {
        // X and Shift+X share one priority: stocked Hyper, then Bomb.
        var _power_action = BladeSurvivalPowerActionForX(economy, false);
        if (_power_action == BladeSurvivalPowerAction.Hyper) {
            var _hyper = BladeSurvivalTryActivateHyper(economy);
            BladeStage1AudioPlayForController(
                id, BladeStage1AudioSfx.Hyper, 0.82
            );
            with (o_blade_first_beat_enemy_bullet) instance_destroy();
            feedback_text = "HYPER BONUS T" + string(_hyper.tier)
                + "\nDANGER UP";
            feedback_ticks = 120;
        } else if (_power_action == BladeSurvivalPowerAction.Bomb) {
            var _bomb = BladeSurvivalUseBomb(economy, false);
            BladeStage1AudioPlayForController(
                id, BladeStage1AudioSfx.Bomb, 0.82
            );
            bomb_clears_this_frame = true;
            with (o_blade_first_beat_enemy_bullet) instance_destroy();
            feedback_text = "BOMB  SCORE -20%";
            feedback_ticks = 120;
        } else {
            feedback_text = "NO HYPER OR BOMBS";
            feedback_ticks = 60;
        }
    }
}

if (stage_route_enabled
    && state == BladeFirstBeatState.Playing
    && BladeSurvivalGameplayAdvances(id)) {
    BladeStage1RouteAdvance(id);
}

if (state == BladeFirstBeatState.Rewarding) {
    if (instance_number(o_blade_reward_item) == 0) {
        reward_wait_ticks = max(0, reward_wait_ticks - 1);
        if (reward_wait_ticks == 0) {
            state = BladeFirstBeatTransition(
                state, BladeFirstBeatEvent.RewardsCollected
            );
        }
    } else {
        reward_wait_ticks = 30;
    }
}
