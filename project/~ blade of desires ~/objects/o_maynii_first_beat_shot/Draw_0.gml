var _renderer = instance_find(o_blade_stage1_forest_renderer, 0);
var _sprite = -1;
if (_renderer != noone) {
    _sprite = tracking
        ? _renderer.maynii_tracking_shot_sprite
        : _renderer.maynii_forward_shot_sprite;
}
var _direction = point_direction(0, 0, velocity_x, velocity_y);
if (sprite_exists(_sprite)) {
    draw_sprite_ext(
        _sprite, 0, x, y,
        tracking ? 0.72 : 0.78,
        tracking ? 0.72 : 0.78,
        _direction + 90,
        hyper_tier > 0 ? make_color_rgb(255, 190, 244) : c_white,
        0.96
    );
    exit;
}
draw_set_color(tracking
    ? make_color_rgb(166, 244, 102)
    : make_color_rgb(236, 255, 148));
if (tracking) {
    draw_triangle(x, y - 5, x - 4, y + 4, x + 4, y + 2, false);
} else {
    draw_line_width(x, y + 5, x, y - 6, 3);
    draw_circle(x, y - 4, 3, false);
}
