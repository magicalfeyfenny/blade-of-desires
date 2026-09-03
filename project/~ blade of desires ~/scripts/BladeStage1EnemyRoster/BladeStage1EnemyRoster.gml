/// Canonical Stage 1 ordinary-enemy roles and their authored presentation data.
///
/// The old scout string is accepted only at this compatibility boundary. It is
/// normalized to mook before any player-facing display or active schedule use.

enum BladeStage1EnemyRole {
    Popcorn = 0,
    Mook = 1,
    Elite = 2,
    Commander = 3
}

#macro BLADE_STAGE1_POPCORN_CONTENT_ID "enemy.stage1.popcorn"
#macro BLADE_STAGE1_MOOK_CONTENT_ID "enemy.stage1.mook"
#macro BLADE_STAGE1_ELITE_CONTENT_ID "enemy.stage1.elite"
#macro BLADE_STAGE1_COMMANDER_CONTENT_ID "enemy.stage1.commander"
#macro BLADE_STAGE1_SCOUT_COMPATIBILITY_ID "enemy.stage1.scout"
// Retain the historical macro name for bounded source compatibility only.
#macro BLADE_STAGE1_SCOUT_CONTENT_ID "enemy.stage1.scout"

#macro BLADE_STAGE1_ROSTER_CELL_WIDTH 64
#macro BLADE_STAGE1_ROSTER_CELL_HEIGHT 96
#macro BLADE_STAGE1_EFFECT_CELL_SIZE 64

/// Returns only the four active player-facing ordinary identities in strength order.
function BladeStage1EnemyRoleContentIds() {
    return [
        BLADE_STAGE1_POPCORN_CONTENT_ID,
        BLADE_STAGE1_MOOK_CONTENT_ID,
        BLADE_STAGE1_ELITE_CONTENT_ID,
        BLADE_STAGE1_COMMANDER_CONTENT_ID,
    ];
}

/// Returns one stable display label without exposing the retired scout alias.
function BladeStage1EnemyRoleDisplayName(_role_id) {
    switch (_role_id) {
        case BladeStage1EnemyRole.Popcorn: return "POPCORN";
        case BladeStage1EnemyRole.Mook: return "MOOK";
        case BladeStage1EnemyRole.Elite: return "ELITE";
        case BladeStage1EnemyRole.Commander: return "COMMANDER";
    }
    throw("BladeStage1EnemyRoster: unknown role " + string(_role_id));
}

/// Returns the complete authored normal/rank-0 profile for one role.
function BladeStage1EnemyProfile(_role_id) {
    switch (_role_id) {
        case BladeStage1EnemyRole.Popcorn:
            return {
                role_id: BladeStage1EnemyRole.Popcorn,
                content_id: BLADE_STAGE1_POPCORN_CONTENT_ID,
                display_name: "POPCORN",
                authored_max_health: 10,
                expected_defeat_ticks: 10,
                hit_radius: 10,
                projectile_radius: 3,
                tell_ticks: 42,
                fire_repeat_ticks: 84,
                bullet_speed: 1.90,
                bullet_offsets: [0],
                bullet_kind: BladeFirstBeatBulletKind.PopcornSeed,
                entry_speed: 1.45,
                travel_speed_x: 0.92,
                movement_amplitude: 5,
                movement_step_degrees: 5,
                motion_id: "seed_bob",
                tell_id: "seed_glimmer",
                pattern_id: "single_seed",
                visual_scale: 0.82,
                body_color: make_color_rgb(255, 205, 166),
                tell_color: make_color_rgb(255, 235, 156),
                accent_color: make_color_rgb(255, 244, 212),
            };

        case BladeStage1EnemyRole.Mook:
            return {
                role_id: BladeStage1EnemyRole.Mook,
                content_id: BLADE_STAGE1_MOOK_CONTENT_ID,
                display_name: "MOOK",
                authored_max_health: 18,
                expected_defeat_ticks: 18,
                hit_radius: 11,
                projectile_radius: 4,
                tell_ticks: 35,
                fire_repeat_ticks: 68,
                bullet_speed: 2.20,
                bullet_offsets: [-14, 0, 14],
                bullet_kind: BladeFirstBeatBulletKind.MookPetal,
                entry_speed: 1.25,
                travel_speed_x: 0.70,
                movement_amplitude: 8,
                movement_step_degrees: 4,
                motion_id: "leaf_sweep",
                tell_id: "leaf_ring",
                pattern_id: "three_leaf_fan",
                visual_scale: 0.86,
                body_color: make_color_rgb(105, 218, 126),
                tell_color: make_color_rgb(216, 255, 130),
                accent_color: make_color_rgb(233, 255, 196),
            };

        case BladeStage1EnemyRole.Elite:
            return {
                role_id: BladeStage1EnemyRole.Elite,
                content_id: BLADE_STAGE1_ELITE_CONTENT_ID,
                display_name: "ELITE",
                authored_max_health: 30,
                expected_defeat_ticks: 30,
                hit_radius: 12,
                projectile_radius: 4,
                tell_ticks: 50,
                fire_repeat_ticks: 58,
                bullet_speed: 2.55,
                bullet_offsets: [-34, -17, 0, 17, 34],
                bullet_kind: BladeFirstBeatBulletKind.EliteMoon,
                entry_speed: 1.05,
                travel_speed_x: 0.84,
                movement_amplitude: 13,
                movement_step_degrees: 3,
                motion_id: "moon_orbit",
                tell_id: "moon_rune",
                pattern_id: "five_moon_fan",
                visual_scale: 0.90,
                body_color: make_color_rgb(178, 123, 255),
                tell_color: make_color_rgb(239, 202, 255),
                accent_color: make_color_rgb(255, 236, 255),
            };

        case BladeStage1EnemyRole.Commander:
            return {
                role_id: BladeStage1EnemyRole.Commander,
                content_id: BLADE_STAGE1_COMMANDER_CONTENT_ID,
                display_name: "COMMANDER",
                authored_max_health: 44,
                expected_defeat_ticks: 44,
                hit_radius: 13,
                projectile_radius: 4,
                tell_ticks: 64,
                fire_repeat_ticks: 52,
                bullet_speed: 2.82,
                bullet_offsets: [-54, -36, -18, 0, 18, 36, 54],
                bullet_kind: BladeFirstBeatBulletKind.CommanderCrown,
                entry_speed: 0.88,
                travel_speed_x: 0.96,
                movement_amplitude: 18,
                movement_step_degrees: 2,
                motion_id: "crown_sweep",
                tell_id: "crown_warning",
                pattern_id: "seven_thorn_fan",
                visual_scale: 0.94,
                body_color: make_color_rgb(255, 102, 78),
                tell_color: make_color_rgb(255, 214, 103),
                accent_color: make_color_rgb(255, 244, 190),
            };
    }
    throw("BladeStage1EnemyRoster: missing profile " + string(_role_id));
}

/// Identifies active content, the retired alias, and the reward-bearing modifier.
function BladeStage1EnemyKnownContent(_content_id) {
    return _content_id == BLADE_STAGE1_POPCORN_CONTENT_ID
        || _content_id == BLADE_STAGE1_MOOK_CONTENT_ID
        || _content_id == BLADE_STAGE1_ELITE_CONTENT_ID
        || _content_id == BLADE_STAGE1_COMMANDER_CONTENT_ID
        || _content_id == BLADE_STAGE1_SCOUT_COMPATIBILITY_ID
        || _content_id == BLADE_SURVIVAL_BOMB_CARRIER_ID;
}

/// Normalizes only the retired scout spelling and the carrier's base role.
function BladeStage1EnemyNormalizeContentId(_content_id) {
    if (_content_id == BLADE_STAGE1_SCOUT_COMPATIBILITY_ID
        || _content_id == BLADE_SURVIVAL_BOMB_CARRIER_ID) {
        return BLADE_STAGE1_MOOK_CONTENT_ID;
    }
    if (_content_id == BLADE_STAGE1_POPCORN_CONTENT_ID
        || _content_id == BLADE_STAGE1_MOOK_CONTENT_ID
        || _content_id == BLADE_STAGE1_ELITE_CONTENT_ID
        || _content_id == BLADE_STAGE1_COMMANDER_CONTENT_ID) {
        return _content_id;
    }
    throw("BladeStage1EnemyRoster: unknown content " + string(_content_id));
}

/// Resolves any accepted content identity to a canonical four-role enum.
function BladeStage1EnemyRoleForContent(_content_id) {
    var _normalized = BladeStage1EnemyNormalizeContentId(_content_id);
    switch (_normalized) {
        case BLADE_STAGE1_POPCORN_CONTENT_ID: return BladeStage1EnemyRole.Popcorn;
        case BLADE_STAGE1_MOOK_CONTENT_ID: return BladeStage1EnemyRole.Mook;
        case BLADE_STAGE1_ELITE_CONTENT_ID: return BladeStage1EnemyRole.Elite;
        case BLADE_STAGE1_COMMANDER_CONTENT_ID:
            return BladeStage1EnemyRole.Commander;
    }
    throw("BladeStage1EnemyRoster: content did not resolve " + string(_content_id));
}

/// Returns the player-facing label for active content and the compatibility alias.
function BladeStage1EnemyDisplayName(_content_id) {
    return BladeStage1EnemyRoleDisplayName(
        BladeStage1EnemyRoleForContent(_content_id)
    );
}

/// Produces one deterministic role-specific set of aim offsets for a volley.
function BladeStage1EnemyFireDirections(_enemy, _aim_direction) {
    var _phase_offset = 0;
    if (_enemy.role_id == BladeStage1EnemyRole.Elite) {
        _phase_offset = (_enemy.pattern_phase mod 2 == 0) ? -6 : 6;
    } else if (_enemy.role_id == BladeStage1EnemyRole.Commander) {
        _phase_offset = ((_enemy.pattern_phase mod 3) - 1) * 8;
    }

    var _directions = [];
    for (var _index = 0;
        _index < array_length(_enemy.bullet_offsets);
        ++_index) {
        array_push(
            _directions,
            _aim_direction + _enemy.bullet_offsets[_index] + _phase_offset
        );
    }
    return _directions;
}

/// Applies the one canonical full-circle gate at a concrete projectile origin.
function BladeStage1EnemyEmissionAllowed(_plane, _x, _y, _radius) {
    return BladeCombatPlaneContainsPixelCircle(_plane, _x, _y, _radius);
}

/// Advances the authored movement profile after the pre-fire tell is complete.
function BladeStage1EnemyAdvanceMotion(_enemy) {
    _enemy.movement_phase += _enemy.movement_step_degrees;
    _enemy.x += _enemy.travel_speed_x;
    if (_enemy.x <= 220 || _enemy.x >= 420) {
        _enemy.x = clamp(_enemy.x, 220, 420);
        _enemy.travel_speed_x = -_enemy.travel_speed_x;
    }

    switch (_enemy.role_id) {
        case BladeStage1EnemyRole.Popcorn:
            _enemy.y = _enemy.target_y
                + dsin(_enemy.movement_phase) * _enemy.movement_amplitude;
            break;
        case BladeStage1EnemyRole.Mook:
            _enemy.y = _enemy.target_y
                + dsin(_enemy.movement_phase * 1.5)
                * _enemy.movement_amplitude;
            break;
        case BladeStage1EnemyRole.Elite:
            _enemy.y = _enemy.target_y
                + dsin(_enemy.movement_phase * 2)
                * _enemy.movement_amplitude;
            break;
        case BladeStage1EnemyRole.Commander:
            _enemy.y = _enemy.target_y
                + dsin(_enemy.movement_phase)
                * _enemy.movement_amplitude;
            break;
    }
}

/// Applies one role profile while preserving the bomb carrier as a mook variant.
function BladeStage1EnemyConfigure(
    _enemy, _content_id, _spawn_order, _difficulty_id, _rank,
    _is_bomb_carrier = false
) {
    var _role_id = BladeStage1EnemyRoleForContent(_content_id);
    var _profile = BladeStage1EnemyProfile(_role_id);
    var _carrier = _is_bomb_carrier
        || _content_id == BLADE_SURVIVAL_BOMB_CARRIER_ID;

    _enemy.role_id = _role_id;
    _enemy.role_content_id = _profile.content_id;
    _enemy.display_name = _profile.display_name;
    _enemy.variant_id = _carrier ? "bomb_carrier" : "standard";
    _enemy.is_bomb_carrier = _carrier;
    _enemy.archetype_id = _carrier
        ? BLADE_SURVIVAL_BOMB_CARRIER_ID
        : _profile.content_id;
    _enemy.authored_max_health = _carrier
        ? 36
        : _profile.authored_max_health;
    _enemy.max_health = BladeDifficultyEnemyHealth(
        _enemy.authored_max_health, _difficulty_id, _rank
    );
    _enemy.hit_points = _enemy.max_health;
    _enemy.hit_radius = _carrier ? 14 : _profile.hit_radius;
    _enemy.tell_ticks = _carrier ? 55 : _profile.tell_ticks + _spawn_order * 4;
    _enemy.fire_repeat_ticks = _carrier
        ? 56
        : _profile.fire_repeat_ticks + (_spawn_order mod 2) * 6;
    _enemy.bullet_speed = _carrier ? 2.55 : _profile.bullet_speed;
    _enemy.bullet_offsets = _carrier
        ? [-14, 0, 14]
        : _profile.bullet_offsets;
    _enemy.bullet_kind = _profile.bullet_kind;
    _enemy.projectile_radius = _carrier ? 4 : _profile.projectile_radius;
    _enemy.entry_speed = _carrier ? 1.25 : _profile.entry_speed;
    _enemy.travel_speed_x = _carrier ? 0.65 : _profile.travel_speed_x;
    _enemy.movement_amplitude = _carrier
        ? _profile.movement_amplitude
        : _profile.movement_amplitude;
    _enemy.movement_step_degrees = _profile.movement_step_degrees;
    _enemy.movement_phase = (_spawn_order mod 4) * 18;
    _enemy.pattern_phase = 0;
    _enemy.body_color = _profile.body_color;
    _enemy.tell_color = _profile.tell_color;
    _enemy.accent_color = _profile.accent_color;
    _enemy.visual_scale = _profile.visual_scale;
    _enemy.motion_id = _profile.motion_id;
    _enemy.tell_id = _profile.tell_id;
    _enemy.pattern_id = _profile.pattern_id;
    _enemy.expected_defeat_ticks = _profile.expected_defeat_ticks;
    _enemy.auto_cancel_bullets_on_defeat = false;
    return _profile;
}

/// Draws one cell of the four-column role roster atlas without owning geometry.
function BladeStage1EnemyDrawRosterCell(
    _sprite, _role_id, _x, _y, _scale, _color = c_white, _alpha = 1
) {
    if (!sprite_exists(_sprite)) return false;
    var _width = BLADE_STAGE1_ROSTER_CELL_WIDTH * _scale;
    var _height = BLADE_STAGE1_ROSTER_CELL_HEIGHT * _scale;
    draw_sprite_part_ext(
        _sprite, 0,
        _role_id * BLADE_STAGE1_ROSTER_CELL_WIDTH, 0,
        BLADE_STAGE1_ROSTER_CELL_WIDTH, BLADE_STAGE1_ROSTER_CELL_HEIGHT,
        _x - _width * 0.5, _y - _height * 0.5,
        _scale, _scale, _color, _alpha
    );
    return true;
}

/// Draws one row/column cell of the authored projectile/effect atlas.
function BladeStage1EnemyDrawEffectCell(
    _sprite, _role_id, _row, _x, _y, _scale,
    _color = c_white, _alpha = 1
) {
    if (!sprite_exists(_sprite)) return false;
    var _size = BLADE_STAGE1_EFFECT_CELL_SIZE * _scale;
    draw_sprite_part_ext(
        _sprite, 0,
        _role_id * BLADE_STAGE1_EFFECT_CELL_SIZE,
        _row * BLADE_STAGE1_EFFECT_CELL_SIZE,
        BLADE_STAGE1_EFFECT_CELL_SIZE, BLADE_STAGE1_EFFECT_CELL_SIZE,
        _x - _size * 0.5, _y - _size * 0.5,
        _scale, _scale, _color, _alpha
    );
    return true;
}
