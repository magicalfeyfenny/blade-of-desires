/// Coordinate the selected run's two unchosen fae and one shared combo attack.

enum BladeStage1FaeRole {
    Ciela = 1,
    Maynii = 2,
    Kolar = 3
}

#macro BLADE_STAGE1_MIDBOSS_PERSONAL_HP 80
#macro BLADE_STAGE1_MIDBOSS_COMBO_HP 150
#macro BLADE_STAGE1_MIDBOSS_ENTRY_TELL_TICKS 75
#macro BLADE_STAGE1_MIDBOSS_RECHARGE_TICKS 120

/// Creates attempt-local coordination state without owning either visible fae object.
function BladeStage1MidbossStateCreate(_selected_run = undefined) {
    var _combo_pattern_id = "";
    var _selected_ship_id = "";
    if (!is_undefined(_selected_run)) {
        _combo_pattern_id = _selected_run.combo_pattern_id;
        _selected_ship_id = _selected_run.ship_id;
    }
    return {
        members: [],
        combo_active: false,
        completed: false,
        selected_ship_id: _selected_ship_id,
        combo_pattern_id: _combo_pattern_id,
    };
}

/// Returns the authored display name for one Stage 1 fae role.
function BladeStage1MidbossRoleName(_role) {
    switch (_role) {
        case BladeStage1FaeRole.Ciela: return "CIELA";
        case BladeStage1FaeRole.Maynii: return "MAYNII";
        case BladeStage1FaeRole.Kolar: return "KOLAR";
    }
    throw("BladeStage1Midboss: unknown fae role " + string(_role));
}

// Returns one fae's feedback color without coupling it to decorative sprites.
function BladeStage1MidbossRoleColor(_role) {
    switch (_role) {
        case BladeStage1FaeRole.Ciela: return make_color_rgb(92, 218, 244);
        case BladeStage1FaeRole.Maynii: return make_color_rgb(116, 236, 116);
        case BladeStage1FaeRole.Kolar: return make_color_rgb(211, 170, 255);
    }
    throw("BladeStage1Midboss: unknown fae role color " + string(_role));
}

// Returns one fae's existing readable feedback effect kind.
function BladeStage1MidbossRoleEffect(_role) {
    if (_role == BladeStage1FaeRole.Ciela) return BLADE_STAGE1_EFFECT_CIELA;
    if (_role == BladeStage1FaeRole.Maynii) return BLADE_STAGE1_EFFECT_MAYNII;
    if (_role == BladeStage1FaeRole.Kolar) return BLADE_STAGE1_EFFECT_KOLAR;
    throw("BladeStage1Midboss: unknown fae role effect " + string(_role));
}

// Maps one concrete fae role to the only standard pattern it may execute.
function BladeStage1MidbossStandardPatternId(_role) {
    switch (_role) {
        case BladeStage1FaeRole.Ciela:
            return "pattern.stage1.standard.ciela_river_current";
        case BladeStage1FaeRole.Maynii:
            return "pattern.stage1.standard.maynii_leaf_fan";
        case BladeStage1FaeRole.Kolar:
            return "pattern.stage1.standard.kolar_crystal_fan";
    }
    throw("BladeStage1Midboss: unknown standard-pattern role " + string(_role));
}

// Names the one shared combo represented by the selected route's stable ID.
function BladeStage1MidbossComboLabel(_combo_pattern_id) {
    if (_combo_pattern_id
        == "pattern.stage1.combo.maynii_kolar_root_ridgeline") {
        return "ROOT + RIDGELINE";
    }
    if (_combo_pattern_id
        == "pattern.stage1.combo.ciela_kolar_river_ridgeline") {
        return "RIVER + RIDGELINE";
    }
    if (_combo_pattern_id
        == "pattern.stage1.combo.ciela_maynii_river_roots") {
        return "RIVER + ROOTS";
    }
    throw(
        "BladeStage1Midboss: unknown combo pattern "
        + string(_combo_pattern_id)
    );
}

/// Registers one Stage-owned fae as an independently damageable personal attack.
function BladeStage1MidbossRegister(
    _controller, _member, _role, _standard_pattern_id
) {
    var _expected_pattern_id = BladeStage1MidbossStandardPatternId(_role);
    if (_standard_pattern_id != _expected_pattern_id) {
        throw(
            "BladeStage1Midboss: standard pattern "
            + string(_standard_pattern_id)
            + " does not match " + BladeStage1MidbossRoleName(_role)
        );
    }
    if (!variable_instance_exists(_controller, "midboss_state")) {
        _controller.midboss_state = BladeStage1MidbossStateCreate();
    }
    _member.fae_role = _role;
    _member.standard_pattern_id = _standard_pattern_id;
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
    _member.motion_phase = _role == BladeStage1FaeRole.Maynii
        ? 0
        : (_role == BladeStage1FaeRole.Ciela ? 120 : 180);
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
    _controller.feedback_text = BladeStage1MidbossComboLabel(
        _state.combo_pattern_id
    ) + "\nSHARED LIFE";
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
            var _personal_kind = BladeStage1MidbossRoleEffect(
                _member.fae_role
            );
            var _personal_color = BladeStage1MidbossRoleColor(
                _member.fae_role
            );
            BladeStage1FeedbackSpawn(
                _member.x, _member.y, _personal_kind, _personal_color, 1.1
            );
            BladeStage1AudioPlayForController(
                _controller, BladeStage1AudioSfx.Phase, 0.64
            );
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
                var _combo_kind = BladeStage1MidbossRoleEffect(
                    _destroyed_member.fae_role
                );
                var _combo_color = BladeStage1MidbossRoleColor(
                    _destroyed_member.fae_role
                );
                BladeStage1FeedbackSpawn(
                    _destroyed_member.x,
                    _destroyed_member.y,
                    _combo_kind,
                    _combo_color,
                    1.45
                );
                with (_destroyed_member) instance_destroy();
            }
        }
        BladeStage1AudioPlayForController(
            _controller, BladeStage1AudioSfx.EnemyDefeat, 0.92
        );
    }
    return _result;
}

/// Creates one themed hostile bullet with explicit Stage participant ownership.
function BladeStage1MidbossBulletSpawn(
    _member, _direction, _speed, _kind, _outer, _inner, _hyper_tier = 0
) {
    var _bullet = instance_create_layer(
        _member.x, _member.y + 12,
        "Projectiles", o_blade_first_beat_enemy_bullet
    );
    var _shot_speed = BladeSurvivalHyperHostileBulletSpeed(
        _speed, _hyper_tier
    );
    _bullet.velocity_x = lengthdir_x(_shot_speed, _direction);
    _bullet.velocity_y = lengthdir_y(_shot_speed, _direction);
    _bullet.owner_stage_instance_id = _member.stage_instance_id;
    _bullet.bullet_kind = _kind;
    _bullet.outer_color = _outer;
    _bullet.inner_color = _inner;
    _bullet.radius = 4;
    return _bullet;
}

/// Fires Maynii's leaf-wing fan while leaving a readable central lane.
function BladeStage1MidbossMayniiSolo(_member, _player, _hyper_tier = 0) {
    var _interval = BladeSurvivalHyperHostileFireInterval(54, _hyper_tier);
    if (_member.attack_ticks mod _interval != 0) return false;
    var _aim = point_direction(_member.x, _member.y, _player.x, _player.y);
    var _offsets = [-42, -24, 24, 42];
    for (var _index = 0; _index < array_length(_offsets); ++_index) {
        BladeStage1MidbossBulletSpawn(
            _member, _aim + _offsets[_index], 2.05 + _index * 0.08,
            BladeFirstBeatBulletKind.MayniiLeaf,
            make_color_rgb(64, 204, 92), make_color_rgb(212, 255, 134),
            _hyper_tier
        );
    }
    return true;
}

/// Fires Ciela's staggered river-current banks with alternating open water.
function BladeStage1MidbossCielaSolo(_member, _player, _hyper_tier = 0) {
    var _interval = BladeSurvivalHyperHostileFireInterval(58, _hyper_tier);
    if (_member.attack_ticks mod _interval != 0) return false;
    var _aim = point_direction(_member.x, _member.y, _player.x, _player.y);
    var _pulse = (_member.attack_ticks div _interval) mod 4;
    var _offsets = [-52, -34, -16, 16, 34, 52];
    for (var _index = 0; _index < array_length(_offsets); ++_index) {
        var _bank = _index < 3 ? -1 : 1;
        var _current = (_pulse - 1.5) * 3 * _bank;
        BladeStage1MidbossBulletSpawn(
            _member,
            _aim + _offsets[_index] + _current,
            1.9 + (_index mod 3) * 0.18,
            BladeFirstBeatBulletKind.CielaCurrent,
            make_color_rgb(62, 178, 224),
            make_color_rgb(194, 248, 255),
            _hyper_tier
        );
    }
    return true;
}

/// Fires Kolar's compact crystal fan from beneath her sparkly mountain cape.
function BladeStage1MidbossKolarSolo(_member, _player, _hyper_tier = 0) {
    var _interval = BladeSurvivalHyperHostileFireInterval(64, _hyper_tier);
    if (_member.attack_ticks mod _interval != 0) return false;
    var _aim = point_direction(_member.x, _member.y, _player.x, _player.y);
    var _offsets = [-30, -15, 0, 15, 30];
    for (var _index = 0; _index < array_length(_offsets); ++_index) {
        BladeStage1MidbossBulletSpawn(
            _member, _aim + _offsets[_index], 2.25 + abs(_index - 2) * 0.12,
            BladeFirstBeatBulletKind.KolarCrystal,
            make_color_rgb(176, 150, 226), make_color_rgb(247, 232, 255),
            _hyper_tier
        );
    }
    return true;
}

/// Fires Maynii's half of the combo as a leaf curtain with one moving gap.
function BladeStage1MidbossMayniiCombo(_member, _hyper_tier = 0) {
    var _interval = BladeSurvivalHyperHostileFireInterval(72, _hyper_tier);
    if (_member.attack_ticks mod _interval != 0) return false;
    var _lane_count = 9;
    var _open_lane = 1 + ((_member.attack_ticks div _interval) mod 7);
    for (var _lane = 0; _lane < _lane_count; ++_lane) {
        if (_lane == _open_lane) continue;
        BladeStage1MidbossBulletSpawn(
            _member, 222 + _lane * 12, 2.05 + (_lane mod 3) * 0.12,
            BladeFirstBeatBulletKind.ComboLeaf,
            make_color_rgb(54, 226, 112), make_color_rgb(255, 240, 132),
            _hyper_tier
        );
    }
    return true;
}

/// Fires Kolar's answering combo fan halfway between Maynii's leaf curtains.
function BladeStage1MidbossKolarCombo(_member, _player, _hyper_tier = 0) {
    var _interval = BladeSurvivalHyperHostileFireInterval(72, _hyper_tier);
    var _answer_tick = max(1, _interval div 2);
    if (_member.attack_ticks mod _interval != _answer_tick) return false;
    var _aim = point_direction(_member.x, _member.y, _player.x, _player.y);
    var _offsets = [-34, -17, 0, 17, 34];
    for (var _index = 0; _index < array_length(_offsets); ++_index) {
        BladeStage1MidbossBulletSpawn(
            _member, _aim + _offsets[_index], 2.7 - abs(_index - 2) * 0.12,
            BladeFirstBeatBulletKind.ComboCrystal,
            make_color_rgb(202, 132, 255), make_color_rgb(124, 244, 196),
            _hyper_tier
        );
    }
    return true;
}

/// Sends Ciela's combo half as offset river bands whose channel moves each wave.
function BladeStage1MidbossCielaCombo(_member, _hyper_tier = 0) {
    var _interval = BladeSurvivalHyperHostileFireInterval(68, _hyper_tier);
    if (_member.attack_ticks mod _interval != 0) return false;
    var _wave = (_member.attack_ticks div _interval) mod 5;
    for (var _lane = 0; _lane < 8; ++_lane) {
        var _open_lane = 1 + _wave;
        if (_lane == _open_lane || _lane == _open_lane + 1) continue;
        var _bend = dsin((_lane * 45) + (_wave * 36)) * 7;
        BladeStage1MidbossBulletSpawn(
            _member,
            232 + _lane * 11 + _bend,
            2 + (_lane mod 2) * 0.2,
            BladeFirstBeatBulletKind.ComboRiver,
            make_color_rgb(54, 166, 236),
            make_color_rgb(174, 250, 255),
            _hyper_tier
        );
    }
    return true;
}

/// Answers Ciela's channels with Kolar's narrow moving crystal ridgelines.
function BladeStage1MidbossKolarRiverCombo(
    _member, _player, _hyper_tier = 0
) {
    var _interval = BladeSurvivalHyperHostileFireInterval(68, _hyper_tier);
    var _answer_tick = max(1, _interval div 3);
    if (_member.attack_ticks mod _interval != _answer_tick) return false;
    var _aim = point_direction(_member.x, _member.y, _player.x, _player.y);
    var _wave = (_member.attack_ticks div _interval) mod 5;
    var _sweep = (_wave - 2) * 6;
    var _offsets = [-27, -9, 9, 27];
    for (var _index = 0; _index < array_length(_offsets); ++_index) {
        BladeStage1MidbossBulletSpawn(
            _member,
            _aim + _offsets[_index] + _sweep,
            2.45 + abs(_index - 1.5) * 0.14,
            BladeFirstBeatBulletKind.ComboRiverCrystal,
            make_color_rgb(182, 142, 248),
            make_color_rgb(116, 232, 244),
            _hyper_tier
        );
    }
    return true;
}

/// Sends Ciela's river-root half as a wider, pulsed channel unlike prior duos.
function BladeStage1MidbossCielaMayniiRiverRoots(_member, _hyper_tier = 0) {
    var _interval = BladeSurvivalHyperHostileFireInterval(76, _hyper_tier);
    if (_member.attack_ticks mod _interval != 0) return false;
    var _wave = (_member.attack_ticks div _interval) mod 4;
    var _angles = [210, 228, 246, 294, 312, 330, 348];
    for (var _index = 0; _index < array_length(_angles); ++_index) {
        var _bend = ((_wave + _index) mod 3 - 1) * 4;
        BladeStage1MidbossBulletSpawn(
            _member,
            _angles[_index] + _bend,
            1.72 + (_index mod 3) * 0.16,
            BladeFirstBeatBulletKind.ComboRiverRoots,
            make_color_rgb(48, 188, 224),
            make_color_rgb(178, 255, 196),
            _hyper_tier
        );
    }
    return true;
}

/// Answers the river channel with a delayed three-leaf root weave.
function BladeStage1MidbossMayniiRiverRoots(
    _member, _player, _hyper_tier = 0
) {
    var _interval = BladeSurvivalHyperHostileFireInterval(76, _hyper_tier);
    var _answer_tick = max(1, _interval div 2);
    if (_member.attack_ticks mod _interval != _answer_tick) return false;
    var _aim = point_direction(_member.x, _member.y, _player.x, _player.y);
    var _offsets = [-24, 0, 24];
    for (var _index = 0; _index < array_length(_offsets); ++_index) {
        var _root_turn = (_index - 1) * 11;
        BladeStage1MidbossBulletSpawn(
            _member,
            _aim + _offsets[_index] + _root_turn,
            2.42 + (_index mod 2) * 0.2,
            BladeFirstBeatBulletKind.ComboLeafRoots,
            make_color_rgb(74, 212, 108),
            make_color_rgb(224, 255, 142),
            _hyper_tier
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
    var _player = BladeStage1PlayerInstance(_controller);
    if (_player == noone) return;
    var _hyper_tier = _controller.economy.active_hyper_tier;

    var _fired = false;
    if (_member.combo_active) {
        var _combo_pattern_id = _controller.midboss_state.combo_pattern_id;
        if (_combo_pattern_id
            == "pattern.stage1.combo.maynii_kolar_root_ridgeline") {
            _fired = _member.fae_role == BladeStage1FaeRole.Maynii
                ? BladeStage1MidbossMayniiCombo(_member, _hyper_tier)
                : BladeStage1MidbossKolarCombo(
                    _member, _player, _hyper_tier
                );
        } else if (_combo_pattern_id
            == "pattern.stage1.combo.ciela_kolar_river_ridgeline") {
            _fired = _member.fae_role == BladeStage1FaeRole.Ciela
                ? BladeStage1MidbossCielaCombo(_member, _hyper_tier)
                : BladeStage1MidbossKolarRiverCombo(
                    _member, _player, _hyper_tier
                );
        } else if (_combo_pattern_id
            == "pattern.stage1.combo.ciela_maynii_river_roots") {
            _fired = _member.fae_role == BladeStage1FaeRole.Ciela
                ? BladeStage1MidbossCielaMayniiRiverRoots(
                    _member, _hyper_tier
                )
                : BladeStage1MidbossMayniiRiverRoots(
                    _member, _player, _hyper_tier
                );
        } else {
            throw(
                "BladeStage1Midboss: no runtime for combo "
                + string(_combo_pattern_id)
            );
        }
    } else if (_member.fae_role == BladeStage1FaeRole.Ciela) {
        _fired = BladeStage1MidbossCielaSolo(
            _member, _player, _hyper_tier
        );
    } else if (_member.fae_role == BladeStage1FaeRole.Maynii) {
        _fired = BladeStage1MidbossMayniiSolo(
            _member, _player, _hyper_tier
        );
    } else {
        _fired = BladeStage1MidbossKolarSolo(
            _member, _player, _hyper_tier
        );
    }
    if (_fired) {
        BladeStage1AudioPlayForController(
            _controller, BladeStage1AudioSfx.EnemyVolley, 0.22
        );
    }
}

/// Draws each fae's authored front-facing boss presentation and readable tells.
function BladeStage1MidbossDraw(_member) {
    var _waiting = _member.personal_defeated && !_member.combo_active;
    draw_set_alpha(_waiting ? 0.32 : 1);
    var _renderer = instance_find(o_blade_stage1_forest_renderer, 0);
    var _art = -1;
    if (_renderer != noone) {
        switch (_member.fae_role) {
            case BladeStage1FaeRole.Ciela:
                _art = _renderer.ciela_boss_sprite;
                break;
            case BladeStage1FaeRole.Maynii:
                _art = _renderer.maynii_sprite;
                break;
            case BladeStage1FaeRole.Kolar:
                _art = _renderer.kolar_sprite;
                break;
        }
    }
    if (sprite_exists(_art)) {
        draw_sprite_ext(_art, 0, _member.x, _member.y, 1, 1, 0, c_white, 1);
        if (_member.hit_flash > 0) {
            draw_set_alpha(0.55);
            draw_set_color(c_white);
            draw_circle(_member.x, _member.y, 24, false);
            draw_set_alpha(_waiting ? 0.32 : 1);
        }
    } else {
        if (_member.fae_role == BladeStage1FaeRole.Ciela) {
            draw_set_color(make_color_rgb(54, 156, 210));
            draw_triangle(_member.x, _member.y - 23,
                _member.x - 21, _member.y + 20,
                _member.x + 21, _member.y + 20, false);
            draw_set_color(make_color_rgb(126, 230, 244));
            draw_line_width(_member.x - 20, _member.y + 9,
                _member.x + 18, _member.y + 1, 3);
            draw_line_width(_member.x - 17, _member.y + 16,
                _member.x + 20, _member.y + 8, 2);
            draw_set_color(make_color_rgb(28, 88, 132));
        } else if (_member.fae_role == BladeStage1FaeRole.Maynii) {
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
        draw_set_color(_member.hit_flash > 0
            ? c_white
            : make_color_rgb(245, 226, 198));
        draw_circle(_member.x, _member.y - 8, 5, false);
    }

    if (_member.phase_transition_ticks > 0 && !_waiting) {
        var _total = _member.combo_active
            ? BLADE_STAGE1_MIDBOSS_RECHARGE_TICKS
            : BLADE_STAGE1_MIDBOSS_ENTRY_TELL_TICKS;
        var _ratio = 1 - _member.phase_transition_ticks / _total;
        draw_set_color(BladeStage1MidbossRoleColor(_member.fae_role));
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
        draw_text(_x, _y, BladeStage1MidbossComboLabel(
            _state.combo_pattern_id
        ));
        draw_set_color(make_color_rgb(38, 45, 54));
        draw_rectangle(_x, _y + 18, _x + _width, _y + 24, false);
        draw_set_color(_state.combo_pattern_id
            == "pattern.stage1.combo.ciela_kolar_river_ridgeline"
            ? make_color_rgb(84, 184, 220)
            : (_state.combo_pattern_id
                == "pattern.stage1.combo.ciela_maynii_river_roots"
                ? make_color_rgb(98, 218, 164)
                : make_color_rgb(178, 126, 229)));
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
        draw_set_color(BladeStage1MidbossRoleColor(_personal.fae_role));
        draw_rectangle(
            _x, _bar_y + 16,
            _x + _width * _personal.hit_points / max(1, _personal.max_health),
            _bar_y + 22, false
        );
    }
    return true;
}
