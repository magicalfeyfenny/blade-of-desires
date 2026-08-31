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
    }
    if (sprite_exists(_attack_sprite)) {
        draw_sprite_ext(
            _attack_sprite,
            0,
            x,
            y,
            0.82,
            0.82,
            point_direction(0, 0, velocity_x, velocity_y),
            grazed ? c_white : merge_color(c_white, outer_color, 0.18),
            1
        );
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
