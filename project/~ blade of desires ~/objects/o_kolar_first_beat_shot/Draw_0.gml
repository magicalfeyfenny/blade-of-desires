var _renderer = instance_find(o_blade_stage1_forest_renderer, 0);
var _sprite = -1;
if (_renderer != noone) {
    _sprite = channel == "close"
        ? _renderer.kolar_close_shot_sprite
        : _renderer.kolar_ranged_shot_sprite;
}
var _direction = point_direction(0, 0, velocity_x, velocity_y);
if (sprite_exists(_sprite)) {
    var _scale = channel == "close" ? 0.78 : 0.72;
    draw_sprite_ext(
        _sprite, 0, x, y, _scale, _scale, _direction + 90,
        hyper_tier > 0 ? make_color_rgb(255, 190, 244) : c_white,
        0.96
    );
    exit;
}
draw_set_color(channel == "close"
    ? make_color_rgb(232, 188, 255)
    : make_color_rgb(169, 226, 255));
if (channel == "close") {
    draw_line_width(x, y + 7, x, y - 7, 4);
    draw_circle(x, y - 4, 3, false);
} else {
    draw_triangle(x, y - 6, x - 4, y + 5, x + 4, y + 5, false);
    draw_line(x, y + 3, x, y - 4);
}
