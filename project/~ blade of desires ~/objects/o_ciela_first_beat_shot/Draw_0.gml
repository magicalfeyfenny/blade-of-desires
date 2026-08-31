var _renderer = instance_find(o_blade_stage1_forest_renderer, 0);
var _direction = point_direction(0, 0, velocity_x, velocity_y);
if (_renderer != noone && sprite_exists(_renderer.ciela_wave_sprite)) {
    var _scale = 0.68 + min(hyper_tier, 3) * 0.06;
    draw_sprite_ext(
        _renderer.ciela_wave_sprite,
        0,
        x,
        y,
        _scale,
        _scale,
        _direction,
        hyper_tier > 0 ? make_color_rgb(255, 176, 255) : c_white,
        0.92
    );
    exit;
}

draw_set_color(hyper_tier > 0
    ? make_color_rgb(255, 126, 236)
    : make_color_rgb(120, 236, 255));
var _speed = max(0.001, point_distance(0, 0, velocity_x, velocity_y));
var _forward_x = velocity_x / _speed;
var _forward_y = velocity_y / _speed;
var _side_x = -_forward_y;
var _side_y = _forward_x;
var _half_width = 9 + hyper_tier * 2;
var _line_width = 2 + min(hyper_tier, 2);
var _side_offsets = [-_half_width, -_half_width * 0.5, 0,
    _half_width * 0.5, _half_width];
var _forward_offsets = [-1, 2, -1, 2, -1];
for (var _index = 0; _index < 4; ++_index) {
    draw_line_width(
        x + _side_x * _side_offsets[_index]
            + _forward_x * _forward_offsets[_index],
        y + _side_y * _side_offsets[_index]
            + _forward_y * _forward_offsets[_index],
        x + _side_x * _side_offsets[_index + 1]
            + _forward_x * _forward_offsets[_index + 1],
        y + _side_y * _side_offsets[_index + 1]
            + _forward_y * _forward_offsets[_index + 1],
        _line_width
    );
}
draw_set_color(c_white);
draw_circle(x + _forward_x * 4, y + _forward_y * 4, 2, false);
