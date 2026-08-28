/// Coordinate Maynii and Kolar's simultaneous solos and one shared combo attack.

enum BladeStage1FaeRole {
    Maynii = 1,
    Kolar = 2
}

#macro BLADE_STAGE1_MIDBOSS_PERSONAL_HP 80
#macro BLADE_STAGE1_MIDBOSS_COMBO_HP 150
#macro BLADE_STAGE1_MIDBOSS_ENTRY_TELL_TICKS 75
#macro BLADE_STAGE1_MIDBOSS_RECHARGE_TICKS 120

/// Creates attempt-local coordination state without owning either visible fae object.
function BladeStage1MidbossStateCreate() {
    return {
        members: [],
        combo_active: false,
        completed: false,
    };
}

/// Returns the authored display name for one Stage 1 fae role.
function BladeStage1MidbossRoleName(_role) {
    return _role == BladeStage1FaeRole.Maynii ? "MAYNII" : "KOLAR";
}

/// Registers one Stage-owned fae as an independently damageable personal attack.
function BladeStage1MidbossRegister(_controller, _member, _role) {
    if (!variable_instance_exists(_controller, "midboss_state")) {
        _controller.midboss_state = BladeStage1MidbossStateCreate();
    }
    _member.fae_role = _role;
    _member.target_kind = BladeFirstBeatTargetKind.Stage1FaeMidboss;
    _member.max_health = BLADE_STAGE1_MIDBOSS_PERSONAL_HP;
    _member.hit_points = _member.max_health;
    _member.hit_radius = 18;
    _member.targetable = false;
    _member.personal_defeated = false;
    _member.combo_active = false;
    _member.phase_transition_ticks = BLADE_STAGE1_MIDBOSS_ENTRY_TELL_TICKS;
    _member.entry_complete = false;
    _member.attack_ticks = 0;
    _member.motion_phase = _role == BladeStage1FaeRole.Maynii ? 0 : 180;
    array_push(_controller.midboss_state.members, _member);
    return _member;
}

/// Returns true only after both concrete personal lives have been defeated.
function BladeStage1MidbossPersonalCleared(_controller) {
    var _state = _controller.midboss_state;
    if (array_length(_state.members) != 2) return false;
    for (var _index = 0; _index < array_length(_state.members); ++_index) {
        var _member = _state.members[_index];
        if (!instance_exists(_member) || !_member.personal_defeated) return false;
    }
    return true;
}

/// Removes bullets from both fae while preserving every unrelated enemy pattern.
function BladeStage1MidbossClearPairBullets(_controller) {
    var _members = _controller.midboss_state.members;
    for (var _index = 0; _index < array_length(_members); ++_index) {
        var _member = _members[_index];
        if (instance_exists(_member)) {
            BladeFirstBeatClearOwnedBullets(_member.stage_instance_id);
        }
    }
}

/// Reforms both defeated solos around one synchronized combo life pool.
function BladeStage1MidbossBeginCombo(_controller) {
    var _state = _controller.midboss_state;
    if (_state.combo_active || !BladeStage1MidbossPersonalCleared(_controller)) {
        return false;
    }
    _state.combo_active = true;
    BladeStage1MidbossClearPairBullets(_controller);
    for (var _index = 0; _index < array_length(_state.members); ++_index) {
        var _member = _state.members[_index];
        _member.combo_active = true;
        _member.targetable = false;
        _member.max_health = BLADE_STAGE1_MIDBOSS_COMBO_HP;
        _member.hit_points = BLADE_STAGE1_MIDBOSS_COMBO_HP;
        _member.hit_radius = 18;
        _member.phase_transition_ticks = BLADE_STAGE1_MIDBOSS_RECHARGE_TICKS;
        _member.attack_ticks = 0;
        _member.hit_flash = 0;
    }
    _controller.feedback_text = "MAYNII + KOLAR\nROOT AND RIDGELINE";
    _controller.feedback_ticks = BLADE_STAGE1_MIDBOSS_RECHARGE_TICKS;
    return true;
}

/// Applies damage to a personal life or the shared combo life exactly once.
function BladeStage1MidbossApplyDamage(_controller, _member, _damage) {
    if (!instance_exists(_member) || !_member.targetable) {
        return { applied: 0, defeated: false };
    }
    var _result = BladeFirstBeatDamageResult(_member.hit_points, _damage);
    _member.hit_flash = 4;
    if (!_member.combo_active) {
        _member.hit_points = _result.remaining;
        if (_result.defeated) {
            _member.personal_defeated = true;
            _member.targetable = false;
            _member.hit_radius = 0;
            BladeFirstBeatClearOwnedBullets(_member.stage_instance_id);
            _controller.feedback_text = BladeStage1MidbossRoleName(
                _member.fae_role
            ) + " SOLO CLEARED";
            _controller.feedback_ticks = 90;
            BladeStage1MidbossBeginCombo(_controller);
        }
        return _result;
    }

    var _state = _controller.midboss_state;
    for (var _index = 0; _index < array_length(_state.members); ++_index) {
        var _paired = _state.members[_index];
        if (instance_exists(_paired)) {
            _paired.hit_points = _result.remaining;
            _paired.hit_flash = 4;
        }
    }
    if (_result.defeated && !_state.completed) {
        _state.completed = true;
        BladeStage1MidbossClearPairBullets(_controller);
        BladeSurvivalApplyScore(_controller.economy, 25000);
        _controller.feedback_text = "DUO DEFEATED\nTHE FOREST PATH OPENS";
        _controller.feedback_ticks = 150;
        for (var _defeat_index = 0;
            _defeat_index < array_length(_state.members); ++_defeat_index) {
            var _defeated_member = _state.members[_defeat_index];
            if (!instance_exists(_defeated_member)) continue;
            _defeated_member.targetable = false;
            BladeFirstBeatQueueStageDefeat(_controller, _defeated_member);
        }
        for (var _destroy_index = 0;
            _destroy_index < array_length(_state.members); ++_destroy_index) {
            var _destroyed_member = _state.members[_destroy_index];
            if (instance_exists(_destroyed_member)) {
                with (_destroyed_member) instance_destroy();
            }
        }
    }
    return _result;
}

/// Creates one themed hostile bullet with explicit Stage participant ownership.
function BladeStage1MidbossBulletSpawn(
    _member, _direction, _speed, _kind, _outer, _inner
) {
    var _bullet = instance_create_layer(
        _member.x, _member.y + 12,
        "Projectiles", o_blade_first_beat_enemy_bullet
    );
    _bullet.velocity_x = lengthdir_x(_speed, _direction);
    _bullet.velocity_y = lengthdir_y(_speed, _direction);
    _bullet.owner_stage_instance_id = _member.stage_instance_id;
    _bullet.bullet_kind = _kind;
    _bullet.outer_color = _outer;
    _bullet.inner_color = _inner;
    _bullet.radius = 4;
    return _bullet;
}

/// Fires Maynii's leaf-wing fan while leaving a readable central lane.
function BladeStage1MidbossMayniiSolo(_member, _player) {
    if (_member.attack_ticks mod 54 != 0) return false;
    var _aim = point_direction(_member.x, _member.y, _player.x, _player.y);
    var _offsets = [-42, -24, 24, 42];
    for (var _index = 0; _index < array_length(_offsets); ++_index) {
        BladeStage1MidbossBulletSpawn(
            _member, _aim + _offsets[_index], 2.05 + _index * 0.08,
            BladeFirstBeatBulletKind.MayniiLeaf,
            make_color_rgb(64, 204, 92), make_color_rgb(212, 255, 134)
        );
    }
    return true;
}

/// Fires Kolar's compact crystal fan from beneath her sparkly mountain cape.
function BladeStage1MidbossKolarSolo(_member, _player) {
    if (_member.attack_ticks mod 64 != 0) return false;
    var _aim = point_direction(_member.x, _member.y, _player.x, _player.y);
    var _offsets = [-30, -15, 0, 15, 30];
    for (var _index = 0; _index < array_length(_offsets); ++_index) {
        BladeStage1MidbossBulletSpawn(
            _member, _aim + _offsets[_index], 2.25 + abs(_index - 2) * 0.12,
            BladeFirstBeatBulletKind.KolarCrystal,
            make_color_rgb(176, 150, 226), make_color_rgb(247, 232, 255)
        );
    }
    return true;
}

/// Fires Maynii's half of the combo as a leaf curtain with one moving gap.
function BladeStage1MidbossMayniiCombo(_member) {
    if (_member.attack_ticks mod 72 != 0) return false;
    var _lane_count = 9;
    var _open_lane = 1 + ((_member.attack_ticks div 72) mod 7);
    for (var _lane = 0; _lane < _lane_count; ++_lane) {
        if (_lane == _open_lane) continue;
        BladeStage1MidbossBulletSpawn(
            _member, 222 + _lane * 12, 2.05 + (_lane mod 3) * 0.12,
            BladeFirstBeatBulletKind.ComboLeaf,
            make_color_rgb(54, 226, 112), make_color_rgb(255, 240, 132)
        );
    }
    return true;
}

/// Fires Kolar's answering combo fan halfway between Maynii's leaf curtains.
function BladeStage1MidbossKolarCombo(_member, _player) {
    if (_member.attack_ticks mod 72 != 36) return false;
    var _aim = point_direction(_member.x, _member.y, _player.x, _player.y);
    var _offsets = [-34, -17, 0, 17, 34];
    for (var _index = 0; _index < array_length(_offsets); ++_index) {
        BladeStage1MidbossBulletSpawn(
            _member, _aim + _offsets[_index], 2.7 - abs(_index - 2) * 0.12,
            BladeFirstBeatBulletKind.ComboCrystal,
            make_color_rgb(202, 132, 255), make_color_rgb(124, 244, 196)
        );
    }
    return true;
}

/// Advances one fae only while its full hurtbox is inside the canonical plane.
function BladeStage1MidbossStep(_member) {
    var _controller = instance_find(o_blade_first_beat_controller, 0);
    if (_controller == noone || !BladeSurvivalGameplayAdvances(_controller)) return;
    if (_member.hit_flash > 0) _member.hit_flash -= 1;

    if (!_member.entry_complete) {
        _member.y = min(_member.anchor_y, _member.y + 1.8);
        if (_member.y < _member.anchor_y) return;
        _member.entry_complete = true;
    }
    _member.x = _member.anchor_x
        + dsin(_member.motion_phase + _member.attack_ticks * 1.25) * 12;
    _member.y = _member.anchor_y
        + dsin(_member.motion_phase + _member.attack_ticks * 1.8) * 3;

    if (_member.personal_defeated && !_member.combo_active) return;
    if (_member.phase_transition_ticks > 0) {
        _member.phase_transition_ticks -= 1;
        if (_member.phase_transition_ticks == 0) _member.targetable = true;
        return;
    }
    if (!_member.targetable) return;
    _member.attack_ticks += 1;
    if (_controller.bomb_clears_this_frame
        || !BladeCombatPlaneContainsPixelCircle(
        _controller.gameplay_plane,
        _member.x,
        _member.y,
        _member.hit_radius
    )) return;
    var _player = instance_find(o_ciela_first_beat_player, 0);
    if (_player == noone) return;

    if (_member.combo_active) {
        if (_member.fae_role == BladeStage1FaeRole.Maynii) {
            BladeStage1MidbossMayniiCombo(_member);
        } else {
            BladeStage1MidbossKolarCombo(_member, _player);
        }
    } else if (_member.fae_role == BladeStage1FaeRole.Maynii) {
        BladeStage1MidbossMayniiSolo(_member, _player);
    } else {
        BladeStage1MidbossKolarSolo(_member, _player);
    }
}

/// Draws Maynii's leaf wings or Kolar's sparkly mountain cape as distinct silhouettes.
function BladeStage1MidbossDraw(_member) {
    var _waiting = _member.personal_defeated && !_member.combo_active;
    draw_set_alpha(_waiting ? 0.32 : 1);
    if (_member.fae_role == BladeStage1FaeRole.Maynii) {
        draw_set_color(make_color_rgb(83, 196, 92));
        draw_triangle(_member.x - 6, _member.y - 2,
            _member.x - 25, _member.y - 16,
            _member.x - 19, _member.y + 2, false);
        draw_triangle(_member.x + 6, _member.y - 2,
            _member.x + 25, _member.y - 16,
            _member.x + 19, _member.y + 2, false);
        draw_set_color(make_color_rgb(164, 234, 106));
        draw_triangle(_member.x - 5, _member.y + 2,
            _member.x - 22, _member.y + 15,
            _member.x - 15, _member.y - 2, false);
        draw_triangle(_member.x + 5, _member.y + 2,
            _member.x + 22, _member.y + 15,
            _member.x + 15, _member.y - 2, false);
        draw_set_color(make_color_rgb(28, 98, 51));
    } else {
        draw_set_color(make_color_rgb(104, 86, 146));
        draw_triangle(_member.x, _member.y - 7,
            _member.x - 23, _member.y + 23,
            _member.x + 23, _member.y + 23, false);
        draw_set_color(make_color_rgb(218, 202, 255));
        for (var _spark = -1; _spark <= 1; ++_spark) {
            var _spark_x = _member.x + _spark * 10;
            var _spark_y = _member.y + 9 + abs(_spark) * 5;
            draw_line(_spark_x - 3, _spark_y, _spark_x + 3, _spark_y);
            draw_line(_spark_x, _spark_y - 3, _spark_x, _spark_y + 3);
        }
        draw_set_color(make_color_rgb(74, 72, 92));
    }
    draw_circle(_member.x, _member.y - 3, 10, false);
    draw_set_color(_member.hit_flash > 0 ? c_white : make_color_rgb(245, 226, 198));
    draw_circle(_member.x, _member.y - 8, 5, false);

    if (_member.phase_transition_ticks > 0 && !_waiting) {
        var _total = _member.combo_active
            ? BLADE_STAGE1_MIDBOSS_RECHARGE_TICKS
            : BLADE_STAGE1_MIDBOSS_ENTRY_TELL_TICKS;
        var _ratio = 1 - _member.phase_transition_ticks / _total;
        draw_set_color(_member.fae_role == BladeStage1FaeRole.Maynii
            ? make_color_rgb(160, 255, 128)
            : make_color_rgb(226, 204, 255));
        draw_circle(_member.x, _member.y, 20 + _ratio * 18, true);
    }
    draw_set_alpha(1);
}

/// Draws two personal bars or the one shared combo bar in the Stage 1 HUD.
function BladeStage1MidbossDrawHud(_controller, _x, _y, _width) {
    var _state = _controller.midboss_state;
    if (_state.completed || array_length(_state.members) != 2) return false;
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    if (_state.combo_active) {
        var _member = _state.members[0];
        if (!instance_exists(_member)) return false;
        draw_set_color(c_white);
        draw_text(_x, _y, "ROOT + RIDGELINE");
        draw_set_color(make_color_rgb(38, 45, 54));
        draw_rectangle(_x, _y + 18, _x + _width, _y + 24, false);
        draw_set_color(make_color_rgb(178, 126, 229));
        draw_rectangle(
            _x, _y + 18,
            _x + _width * _member.hit_points / max(1, _member.max_health),
            _y + 24, false
        );
        draw_set_color(c_white);
        draw_text(_x, _y + 28, _member.targetable ? "SHARED COMBO" : "RECHARGING");
        return true;
    }

    for (var _index = 0; _index < 2; ++_index) {
        var _personal = _state.members[_index];
        if (!instance_exists(_personal)) continue;
        var _bar_y = _y + _index * 38;
        draw_set_color(c_white);
        draw_text(_x, _bar_y, BladeStage1MidbossRoleName(_personal.fae_role));
        draw_set_color(make_color_rgb(38, 45, 54));
        draw_rectangle(_x, _bar_y + 16, _x + _width, _bar_y + 22, false);
        draw_set_color(_personal.fae_role == BladeStage1FaeRole.Maynii
            ? make_color_rgb(86, 218, 108)
            : make_color_rgb(190, 158, 236));
        draw_rectangle(
            _x, _bar_y + 16,
            _x + _width * _personal.hit_points / max(1, _personal.max_health),
            _bar_y + 22, false
        );
    }
    return true;
}
