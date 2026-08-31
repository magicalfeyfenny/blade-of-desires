/// Owns Asahi's readable phase lifecycle, attacks, result, and Stage 1 bonus.

enum BladeStage1BossState {
    Entry = 0,
    Active = 1,
    Recharge = 2,
    Terminal = 3
}

enum BladeStage1BossResolution {
    None = 0,
    Defeat = 1,
    Timeout = 2
}

#macro BLADE_STAGE1_ASAHI_CONTENT_ID "encounter.stage1.asahi"
#macro BLADE_STAGE1_ASAHI_PHASE_1_HP 260
#macro BLADE_STAGE1_ASAHI_PHASE_2_HP 360
#macro BLADE_STAGE1_ASAHI_PHASE_1_TICKS 1200
#macro BLADE_STAGE1_ASAHI_PHASE_2_TICKS 1500
#macro BLADE_STAGE1_ASAHI_ENTRY_TICKS 75
#macro BLADE_STAGE1_ASAHI_RECHARGE_TICKS 120
#macro BLADE_STAGE1_ASAHI_STAGE_BONUS 50000

/// Returns the readable authored title for one Asahi phase.
function BladeStage1BossPhaseName(_phase) {
    return _phase == 1 ? "SOLAR WALTZ" : "CROWN OF DAWN";
}

/// Returns the authored hit points for one Asahi phase.
function BladeStage1BossPhaseHealth(_phase) {
    return _phase == 1
        ? BLADE_STAGE1_ASAHI_PHASE_1_HP
        : BLADE_STAGE1_ASAHI_PHASE_2_HP;
}

/// Returns the authored timeout for one Asahi phase.
function BladeStage1BossPhaseDuration(_phase) {
    return _phase == 1
        ? BLADE_STAGE1_ASAHI_PHASE_1_TICKS
        : BLADE_STAGE1_ASAHI_PHASE_2_TICKS;
}

/// Removes attacks owned by Asahi without touching any unrelated participant.
function BladeStage1BossClearOwnedBullets(_boss) {
    if (!instance_exists(_boss)) return 0;
    var _owner = _boss.stage_instance_id;
    var _removed = 0;
    with (o_blade_first_beat_enemy_bullet) {
        if (owner_stage_instance_id == _owner) {
            _removed += 1;
            instance_destroy();
        }
    }
    return _removed;
}

/// Clears the prior route before the warning claims the World Tree arena.
function BladeStage1BossBeginWarning(_controller) {
    if (!instance_exists(_controller)) return false;
    with (o_blade_first_beat_enemy_bullet) instance_destroy();
    with (o_ciela_first_beat_shot) instance_destroy();
    with (o_blade_reward_item) instance_destroy();
    with (o_blade_first_beat_enemy) instance_destroy();
    with (o_blade_stage1_fae_midboss) instance_destroy();
    _controller.midboss_state = BladeStage1MidbossStateCreate();
    _controller.boss_warning_active = true;
    _controller.boss_instance = noone;
    _controller.route_label = "WARNING  ASAHI";
    _controller.feedback_text = "SUNNY FAE OF FLAME\nAPPROACHING";
    _controller.feedback_ticks = 150;
    return true;
}

/// Starts one active phase after its entry or recharge boundary finishes.
function BladeStage1BossActivatePhase(_boss, _phase) {
    _boss.boss_phase = _phase;
    _boss.boss_state = BladeStage1BossState.Active;
    _boss.phase_resolved = false;
    _boss.max_health = BladeStage1BossPhaseHealth(_phase);
    _boss.hit_points = _boss.max_health;
    _boss.phase_ticks = 0;
    _boss.phase_time_limit = BladeStage1BossPhaseDuration(_phase);
    _boss.attack_ticks = 0;
    _boss.attack_tell_ticks = 0;
    _boss.targetable = true;
    return _phase;
}

/// Registers the one object-backed boss and clears shots made during the warning.
function BladeStage1BossRegister(_controller, _boss) {
    if (!instance_exists(_controller) || !instance_exists(_boss)) return false;
    with (o_blade_first_beat_enemy_bullet) instance_destroy();
    with (o_ciela_first_beat_shot) instance_destroy();
    _controller.boss_warning_active = false;
    _controller.boss_instance = _boss;
    _controller.boss_resolution = BladeStage1BossResolution.None;
    _controller.route_label = "ASAHI  SUNNY FAE";
    _boss.boss_phase = 1;
    _boss.boss_state = BladeStage1BossState.Entry;
    _boss.phase_resolved = false;
    _boss.max_health = BLADE_STAGE1_ASAHI_PHASE_1_HP;
    _boss.hit_points = _boss.max_health;
    _boss.phase_time_limit = BLADE_STAGE1_ASAHI_PHASE_1_TICKS;
    _boss.phase_ticks = 0;
    _boss.entry_ticks = BLADE_STAGE1_ASAHI_ENTRY_TICKS;
    _boss.targetable = false;
    return true;
}

/// Creates one flame bullet with explicit boss ownership and canonical-plane origin.
function BladeStage1BossBulletSpawn(
    _boss, _direction, _speed, _kind, _outer, _inner, _hyper_tier = 0
) {
    var _bullet = instance_create_layer(
        _boss.x, _boss.y + 13,
        "Projectiles", o_blade_first_beat_enemy_bullet
    );
    var _shot_speed = BladeSurvivalHyperHostileBulletSpeed(
        _speed, _hyper_tier
    );
    _bullet.velocity_x = lengthdir_x(_shot_speed, _direction);
    _bullet.velocity_y = lengthdir_y(_shot_speed, _direction);
    _bullet.owner_stage_instance_id = _boss.stage_instance_id;
    _bullet.bullet_kind = _kind;
    _bullet.outer_color = _outer;
    _bullet.inner_color = _inner;
    _bullet.radius = _kind == BladeFirstBeatBulletKind.AsahiCrown ? 4 : 5;
    return _bullet;
}

/// Fires an aimed seven-flame fan after a visible solar gathering tell.
function BladeStage1BossSolarWaltz(_boss, _player, _hyper_tier = 0) {
    var _interval = BladeSurvivalHyperHostileFireInterval(58, _hyper_tier);
    var _tell = min(18, max(6, _interval div 3));
    var _cycle_tick = _boss.attack_ticks mod _interval;
    if (_cycle_tick == _interval - _tell) _boss.attack_tell_ticks = _tell;
    if (_boss.attack_ticks <= 0 || _cycle_tick != 0) return false;

    var _aim = point_direction(_boss.x, _boss.y, _player.x, _player.y);
    var _offsets = [-48, -32, -16, 0, 16, 32, 48];
    for (var _index = 0; _index < array_length(_offsets); ++_index) {
        BladeStage1BossBulletSpawn(
            _boss,
            _aim + _offsets[_index],
            2.15 + abs(_index - 3) * 0.08,
            BladeFirstBeatBulletKind.AsahiFlame,
            make_color_rgb(255, 112, 48),
            make_color_rgb(255, 244, 156),
            _hyper_tier
        );
    }
    return true;
}

/// Fires a rotating crown with one moving safe gap and one delayed aimed answer.
function BladeStage1BossCrownOfDawn(_boss, _player, _hyper_tier = 0) {
    var _interval = BladeSurvivalHyperHostileFireInterval(72, _hyper_tier);
    var _cycle_tick = _boss.attack_ticks mod _interval;
    var _tell = min(20, max(8, _interval div 3));
    if (_cycle_tick == _interval - _tell) _boss.attack_tell_ticks = _tell;

    var _fired = false;
    if (_boss.attack_ticks > 0 && _cycle_tick == 0) {
        var _cycle = _boss.attack_ticks div _interval;
        var _gap = (_cycle * 3) mod 16;
        var _rotation = (_cycle * 11) mod 360;
        for (var _ray = 0; _ray < 16; ++_ray) {
            if (_ray == _gap || _ray == ((_gap + 1) mod 16)) continue;
            BladeStage1BossBulletSpawn(
                _boss,
                _rotation + _ray * 22.5,
                1.75 + (_ray mod 3) * 0.10,
                BladeFirstBeatBulletKind.AsahiCrown,
                make_color_rgb(255, 173, 54),
                make_color_rgb(255, 252, 196),
                _hyper_tier
            );
        }
        _fired = true;
    }

    if (_cycle_tick == max(1, _interval div 2)) {
        var _aim = point_direction(_boss.x, _boss.y, _player.x, _player.y);
        var _offsets = [-14, 0, 14];
        for (var _index = 0; _index < array_length(_offsets); ++_index) {
            BladeStage1BossBulletSpawn(
                _boss,
                _aim + _offsets[_index],
                2.9,
                BladeFirstBeatBulletKind.AsahiFlame,
                make_color_rgb(255, 91, 42),
                make_color_rgb(255, 236, 135),
                _hyper_tier
            );
        }
        _fired = true;
    }
    return _fired;
}

/// Begins the exact two-second ring recharge without carrying excess damage.
function BladeStage1BossBeginRecharge(_controller, _boss) {
    BladeStage1BossClearOwnedBullets(_boss);
    _boss.boss_state = BladeStage1BossState.Recharge;
    _boss.recharge_ticks = BLADE_STAGE1_ASAHI_RECHARGE_TICKS;
    _boss.next_phase = 2;
    _boss.targetable = false;
    _controller.feedback_text = "PHASE BREAK\nSOLAR RING RECHARGE";
    _controller.feedback_ticks = BLADE_STAGE1_ASAHI_RECHARGE_TICKS;
    BladeStage1FeedbackSpawn(
        _boss.x,
        _boss.y,
        BLADE_STAGE1_EFFECT_ASAHI_PHASE,
        make_color_rgb(255, 196, 72),
        1.45
    );
    BladeStage1AudioPlayForController(
        _controller, BladeStage1AudioSfx.Phase, 0.96
    );
    return true;
}

/// Resolves a phase once, clears its attacks, and advances to recharge or terminal.
function BladeStage1BossResolvePhase(_controller, _boss, _resolution) {
    if (!instance_exists(_controller)
        || !instance_exists(_boss)
        || _boss.phase_resolved
        || _boss.boss_state != BladeStage1BossState.Active) {
        return false;
    }
    _boss.phase_resolved = true;
    _boss.targetable = false;
    BladeStage1BossClearOwnedBullets(_boss);

    if (_boss.boss_phase == 1) {
        if (_resolution == BladeStage1BossResolution.Defeat) {
            BladeSurvivalApplyScore(_controller.economy, 20000);
        }
        var _recharge_started = BladeStage1BossBeginRecharge(
            _controller, _boss
        );
        if (_resolution == BladeStage1BossResolution.Timeout) {
            _controller.feedback_text = "SOLAR WALTZ TIMEOUT\nRECHARGE";
            _controller.feedback_ticks = BLADE_STAGE1_ASAHI_RECHARGE_TICKS;
        }
        return _recharge_started;
    }

    _boss.boss_state = BladeStage1BossState.Terminal;
    _boss.terminal_ticks = 150;
    _controller.boss_resolution = _resolution;
    if (_resolution == BladeStage1BossResolution.Defeat) {
        BladeSurvivalApplyScore(_controller.economy, 50000);
        _controller.feedback_text = "ASAHI DEFEATED\nDAWN BREAKS";
        BladeStage1AudioPlayForController(
            _controller, BladeStage1AudioSfx.BossDefeat, 1
        );
        var _offsets = [
            [-34, -10], [34, -10], [-22, 18], [22, 18], [0, 0]
        ];
        for (var _index = 0; _index < array_length(_offsets); ++_index) {
            BladeStage1FeedbackSpawn(
                _boss.x + _offsets[_index][0],
                _boss.y + _offsets[_index][1],
                BLADE_STAGE1_EFFECT_ASAHI_DEFEAT,
                make_color_rgb(255, 175 + _index * 10, 72),
                1.25 + _index * 0.14
            );
        }
    } else {
        _controller.feedback_text = "CROWN OF DAWN TIMEOUT\nSURVIVAL CLEAR";
        BladeStage1AudioPlayForController(
            _controller, BladeStage1AudioSfx.Phase, 0.82
        );
        BladeStage1FeedbackSpawn(
            _boss.x,
            _boss.y,
            BLADE_STAGE1_EFFECT_ASAHI_PHASE,
            make_color_rgb(255, 228, 135),
            1.7
        );
    }
    _controller.feedback_ticks = 180;
    BladeFirstBeatQueueStageDefeat(_controller, _boss);
    return true;
}

/// Applies damage only in an active phase, so recharge cannot be bypassed.
function BladeStage1BossApplyDamage(_controller, _boss, _damage) {
    if (!instance_exists(_boss)
        || _boss.boss_state != BladeStage1BossState.Active
        || !_boss.targetable
        || _boss.phase_resolved) {
        var _remaining = instance_exists(_boss) ? _boss.hit_points : 0;
        return { remaining: _remaining, applied: 0, defeated: false };
    }
    var _result = BladeFirstBeatDamageResult(_boss.hit_points, _damage);
    _boss.hit_points = _result.remaining;
    _boss.hit_flash = 4;
    if (_result.defeated) {
        BladeStage1BossResolvePhase(
            _controller, _boss, BladeStage1BossResolution.Defeat
        );
    }
    return _result;
}

/// Advances Asahi's motion, timeout, recharge, and authored fire patterns.
function BladeStage1BossStep(_boss) {
    var _controller = instance_find(o_blade_first_beat_controller, 0);
    if (_controller == noone || !BladeSurvivalGameplayAdvances(_controller)) return;
    if (_boss.hit_flash > 0) _boss.hit_flash -= 1;
    if (_boss.attack_tell_ticks > 0) _boss.attack_tell_ticks -= 1;

    _boss.motion_ticks += 1;
    _boss.x = _boss.anchor_x + dsin(_boss.motion_ticks * 1.15) * 42;
    _boss.y = _boss.anchor_y + dsin(_boss.motion_ticks * 1.8) * 5;

    if (_boss.boss_state == BladeStage1BossState.Entry) {
        _boss.entry_ticks = max(0, _boss.entry_ticks - 1);
        if (_boss.entry_ticks == 0) BladeStage1BossActivatePhase(_boss, 1);
        return;
    }
    if (_boss.boss_state == BladeStage1BossState.Recharge) {
        _boss.recharge_ticks = max(0, _boss.recharge_ticks - 1);
        if (_boss.recharge_ticks == 0) {
            BladeStage1BossActivatePhase(_boss, _boss.next_phase);
            _controller.feedback_text = "PHASE 2\nCROWN OF DAWN";
            _controller.feedback_ticks = 90;
        }
        return;
    }
    if (_boss.boss_state == BladeStage1BossState.Terminal) {
        _boss.terminal_ticks = max(0, _boss.terminal_ticks - 1);
        if (_boss.terminal_ticks == 0) with (_boss) instance_destroy();
        return;
    }
    if (_boss.boss_state != BladeStage1BossState.Active) return;

    _boss.phase_ticks += 1;
    if (_boss.phase_ticks >= _boss.phase_time_limit) {
        BladeStage1BossResolvePhase(
            _controller, _boss, BladeStage1BossResolution.Timeout
        );
        return;
    }
    _boss.attack_ticks += 1;
    if (_controller.bomb_clears_this_frame
        || !BladeCombatPlaneContainsPixelCircle(
            _controller.gameplay_plane,
            _boss.x,
            _boss.y,
            _boss.hit_radius
        )) return;
    var _player = instance_find(o_ciela_first_beat_player, 0);
    if (_player == noone) return;
    var _hyper_tier = _controller.economy.active_hyper_tier;
    var _fired = _boss.boss_phase == 1
        ? BladeStage1BossSolarWaltz(_boss, _player, _hyper_tier)
        : BladeStage1BossCrownOfDawn(_boss, _player, _hyper_tier);
    if (_fired) {
        BladeStage1AudioPlayForController(
            _controller, BladeStage1AudioSfx.EnemyVolley, 0.28
        );
    }
}

/// Draws Asahi's authored Sunny-Fae sprite and her readable ring telegraphs.
function BladeStage1BossDraw(_boss) {
    var _renderer = instance_find(o_blade_stage1_forest_renderer, 0);
    var _asahi_sprite = -1;
    var _sunfire_sprite = -1;
    if (_renderer != noone) {
        _asahi_sprite = _renderer.asahi_sprite;
        _sunfire_sprite = _renderer.asahi_sunfire_sprite;
    }

    var _ring_visible = _boss.attack_tell_ticks > 0
        || _boss.boss_state == BladeStage1BossState.Recharge
        || _boss.boss_state == BladeStage1BossState.Entry;
    if (_ring_visible && sprite_exists(_sunfire_sprite)) {
        var _ring_progress = 0;
        if (_boss.boss_state == BladeStage1BossState.Recharge) {
            _ring_progress = 1
                - _boss.recharge_ticks / BLADE_STAGE1_ASAHI_RECHARGE_TICKS;
        } else if (_boss.boss_state == BladeStage1BossState.Entry) {
            _ring_progress = 1
                - _boss.entry_ticks / BLADE_STAGE1_ASAHI_ENTRY_TICKS;
        } else {
            _ring_progress = 1 - _boss.attack_tell_ticks / 20;
        }
        gpu_set_blendmode(bm_add);
        draw_sprite_ext(
            _sunfire_sprite,
            0,
            _boss.x,
            _boss.y,
            0.64 + _ring_progress * 0.24,
            0.64 + _ring_progress * 0.24,
            _boss.motion_ticks * 1.8,
            c_white,
            0.36 + _ring_progress * 0.32
        );
        gpu_set_blendmode(bm_normal);
    }

    var _alpha = _boss.boss_state == BladeStage1BossState.Terminal
        ? max(0.18, _boss.terminal_ticks / 150)
        : 1;
    draw_set_alpha(_alpha);
    if (sprite_exists(_asahi_sprite)) {
        draw_sprite_ext(
            _asahi_sprite, 0, _boss.x, _boss.y,
            0.70, 0.70, 0, c_white, 1
        );
    } else {
        draw_set_color(make_color_rgb(255, 160, 58));
        draw_circle(_boss.x, _boss.y, 22, false);
        draw_set_color(make_color_rgb(255, 240, 152));
        draw_triangle(
            _boss.x, _boss.y - 26,
            _boss.x - 18, _boss.y + 22,
            _boss.x + 18, _boss.y + 22,
            false
        );
    }
    if (_boss.hit_flash > 0) {
        draw_set_alpha(0.58);
        draw_set_color(c_white);
        draw_circle(_boss.x, _boss.y, 28, false);
    }
    draw_set_alpha(1);
}

/// Draws the one Asahi HUD during warning, active phases, and recharge.
function BladeStage1BossDrawHud(_controller, _x, _y, _width) {
    var _boss = _controller.boss_instance;
    if (_controller.boss_warning_active && !instance_exists(_boss)) {
        draw_set_color(make_color_rgb(255, 192, 74));
        draw_text(_x, _y, "WARNING\nASAHI  SUNNY FAE\nFLAME ELEMENT");
        return true;
    }
    if (!instance_exists(_boss)) return false;

    draw_set_alpha(0.76);
    draw_set_color(make_color_rgb(25, 10, 16));
    draw_rectangle(_x, _y, _x + _width, _y + 84, false);
    draw_set_alpha(1);
    var _renderer = instance_find(o_blade_stage1_forest_renderer, 0);
    if (_renderer != noone && sprite_exists(_renderer.asahi_hud_frame_sprite)) {
        var _frame = _renderer.asahi_hud_frame_sprite;
        var _scale_x = _width / sprite_get_width(_frame);
        var _scale_y = 84 / sprite_get_height(_frame);
        draw_sprite_ext(
            _frame, 0,
            _x + _width * 0.5, _y + 42,
            _scale_x, _scale_y, 0, c_white, 0.38
        );
    }

    draw_set_color(make_color_rgb(255, 232, 164));
    draw_text(_x + 10, _y + 8, "ASAHI   PHASE " + string(_boss.boss_phase));
    draw_text(_x + 10, _y + 25, BladeStage1BossPhaseName(_boss.boss_phase));
    draw_set_color(make_color_rgb(62, 31, 24));
    draw_rectangle(_x + 10, _y + 45, _x + _width - 10, _y + 54, false);
    draw_set_color(make_color_rgb(255, 126, 42));
    var _ratio = _boss.max_health > 0
        ? clamp(_boss.hit_points / _boss.max_health, 0, 1)
        : 0;
    draw_rectangle(
        _x + 10,
        _y + 45,
        _x + 10 + (_width - 20) * _ratio,
        _y + 54,
        false
    );
    draw_set_color(c_white);
    if (_boss.boss_state == BladeStage1BossState.Recharge) {
        draw_text(
            _x + 10, _y + 61,
            "RING RECHARGE  " + string(_boss.recharge_ticks)
        );
    } else if (_boss.boss_state == BladeStage1BossState.Entry) {
        draw_text(_x + 10, _y + 61, "SUNNY FAE ENTERS");
    } else {
        var _remaining = max(0, _boss.phase_time_limit - _boss.phase_ticks);
        draw_text(
            _x + 10, _y + 61,
            "TIME  " + string(ceil(_remaining / 60))
        );
    }
    return true;
}

/// Awards the stable Stage Clear breakdown exactly once after Asahi resolves.
function BladeStage1BossFinalizeStageClear(_controller) {
    if (_controller.stage_clear_awarded) return _controller.stage_clear_breakdown;
    var _life_bonus = max(0, _controller.economy.lives) * 10000;
    var _bomb_bonus = max(0, _controller.economy.bombs) * 2000;
    var _total = BLADE_STAGE1_ASAHI_STAGE_BONUS + _life_bonus + _bomb_bonus;
    _controller.economy.score += _total;
    _controller.stage_clear_awarded = true;
    _controller.stage_clear_breakdown = {
        base: BLADE_STAGE1_ASAHI_STAGE_BONUS,
        lives: _life_bonus,
        bombs: _bomb_bonus,
        total: _total,
    };
    with (o_blade_first_beat_enemy_bullet) instance_destroy();
    with (o_ciela_first_beat_shot) instance_destroy();
    with (o_blade_reward_item) instance_destroy();
    with (o_blade_stage1_asahi) instance_destroy();
    _controller.boss_instance = noone;
    _controller.boss_warning_active = false;
    _controller.feedback_text = "STAGE CLEAR\nBONUS " + string(_total);
    _controller.feedback_ticks = 240;
    return _controller.stage_clear_breakdown;
}
