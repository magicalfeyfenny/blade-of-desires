var _shown_outer = grazed ? merge_color(outer_color, c_white, 0.45) : outer_color;
var _speed = point_distance(0, 0, velocity_x, velocity_y);
var _forward_x = _speed > 0 ? velocity_x / _speed : 0;
var _forward_y = _speed > 0 ? velocity_y / _speed : 1;
var _side_x = -_forward_y;
var _side_y = _forward_x;
var _renderer = instance_find(o_blade_stage1_forest_renderer, 0);
if (_renderer != noone) {
    var _attack_sprite = -1;
    switch (bullet_kind) {
        case BladeFirstBeatBulletKind.MayniiLeaf:
        case BladeFirstBeatBulletKind.ComboLeaf:
            _attack_sprite = _renderer.maynii_leaf_sprite;
            break;
        case BladeFirstBeatBulletKind.KolarCrystal:
        case BladeFirstBeatBulletKind.ComboCrystal:
            _attack_sprite = _renderer.kolar_crystal_sprite;
            break;
        case BladeFirstBeatBulletKind.CielaCurrent:
            _attack_sprite = _renderer.ciela_current_sprite;
            break;
        case BladeFirstBeatBulletKind.ComboRiver:
        case BladeFirstBeatBulletKind.ComboRiverCrystal:
            _attack_sprite = _renderer.ciela_kolar_combo_sprite;
            break;
        case BladeFirstBeatBulletKind.ComboRiverRoots:
        case BladeFirstBeatBulletKind.ComboLeafRoots:
            _attack_sprite = _renderer.ciela_maynii_combo_sprite;
            break;
        case BladeFirstBeatBulletKind.AsahiFlame:
        case BladeFirstBeatBulletKind.AsahiCrown:
            _attack_sprite = _renderer.asahi_sunfire_sprite;
            break;
    }
    if (sprite_exists(_attack_sprite)) {
        var _attack_scale = bullet_kind == BladeFirstBeatBulletKind.AsahiCrown
            ? 0.15
            : (bullet_kind == BladeFirstBeatBulletKind.AsahiFlame
                ? 0.19
                : (bullet_kind == BladeFirstBeatBulletKind.CielaCurrent
                    ? 0.72
                    : 0.82));
        draw_sprite_ext(
            _attack_sprite,
            0,
            x,
            y,
            _attack_scale,
            _attack_scale,
            point_direction(0, 0, velocity_x, velocity_y),
            grazed ? c_white : merge_color(c_white, outer_color, 0.18),
            1
        );
        exit;
    }
    if (role_id >= BladeStage1EnemyRole.Popcorn
        && role_id <= BladeStage1EnemyRole.Commander
        && variable_instance_exists(
            _renderer, "ordinary_enemy_effects_sprite"
        )
        && BladeStage1EnemyDrawEffectCell(
            _renderer.ordinary_enemy_effects_sprite,
            role_id,
            0,
            x,
            y,
            0.55,
            grazed ? c_white : c_white,
            1
        )) {
        // Authored effect-atlas row 1 is the projectile family.
        exit;
    }
}
switch (bullet_kind) {
    case BladeFirstBeatBulletKind.MayniiLeaf:
    case BladeFirstBeatBulletKind.ComboLeaf:
        draw_set_color(_shown_outer);
        draw_triangle(
            x + _forward_x * 7, y + _forward_y * 7,
            x + _side_x * 3, y + _side_y * 3,
            x - _forward_x * 7, y - _forward_y * 7,
            false
        );
        draw_triangle(
            x + _forward_x * 7, y + _forward_y * 7,
            x - _forward_x * 7, y - _forward_y * 7,
            x - _side_x * 3, y - _side_y * 3,
            false
        );
        draw_set_color(inner_color);
        draw_line(
            x - _forward_x * 4, y - _forward_y * 4,
            x + _forward_x * 4, y + _forward_y * 4
        );
        break;

    case BladeFirstBeatBulletKind.KolarCrystal:
    case BladeFirstBeatBulletKind.ComboCrystal:
        draw_set_color(_shown_outer);
        draw_triangle(
            x + _forward_x * 7, y + _forward_y * 7,
            x + _side_x * 4, y + _side_y * 4,
            x - _forward_x * 7, y - _forward_y * 7,
            false
        );
        draw_triangle(
            x + _forward_x * 7, y + _forward_y * 7,
            x - _forward_x * 7, y - _forward_y * 7,
            x - _side_x * 4, y - _side_y * 4,
            false
        );
        draw_set_color(inner_color);
        draw_circle(x, y, 2, false);
        break;

    case BladeFirstBeatBulletKind.ComboRiverRoots:
        draw_set_color(_shown_outer);
        draw_circle(x, y, radius + 2, false);
        draw_set_color(inner_color);
        draw_line(
            x - _side_x * (radius + 2), y - _side_y * (radius + 2),
            x + _side_x * (radius + 2), y + _side_y * (radius + 2)
        );
        draw_line(
            x - _forward_x * (radius + 2), y - _forward_y * (radius + 2),
            x + _forward_x * (radius + 2), y + _forward_y * (radius + 2)
        );
        break;

    case BladeFirstBeatBulletKind.ComboLeafRoots:
        draw_set_color(_shown_outer);
        draw_triangle(
            x + _forward_x * 8, y + _forward_y * 8,
            x + _side_x * 5, y + _side_y * 5,
            x - _forward_x * 5, y - _forward_y * 5,
            false
        );
        draw_set_color(inner_color);
        draw_line(
            x - _forward_x * 5, y - _forward_y * 5,
            x + _forward_x * 5, y + _forward_y * 5
        );
        break;

    default:
        draw_set_color(_shown_outer);
        draw_circle(x, y, radius, false);
        draw_set_color(inner_color);
        draw_circle(x, y, 2, false);
        draw_line(
            x - _forward_x * radius, y - _forward_y * radius,
            x + _forward_x * 2, y + _forward_y * 2
        );
        break;
}
