if (!initialized) exit;
var _progress = clamp(age / max(1, duration), 0, 1);
var _fade = power(1 - _progress, 1.4);
var _radius = max_radius * effect_scale * (0.12 + _progress * 0.88);

draw_set_alpha(_fade * 0.72);
draw_set_color(effect_color);
draw_circle(x, y, _radius, true);
draw_circle(x, y, max(2, _radius - 2 * effect_scale), true);

for (var _index = 0; _index < particle_count; ++_index) {
    var _angle = effect_seed + _index * 137.507;
    var _variation = 0.62 + ((_index * 17) mod 11) / 18;
    var _distance = _radius * _variation;
    var _particle_x = x + lengthdir_x(_distance, _angle);
    var _particle_y = y + lengthdir_y(_distance, _angle)
        + power(_progress, 2) * 18 * effect_scale;
    var _size = max(1, round((2 + (_index mod 3)) * effect_scale));
    var _bright = (_index mod 4 == 0)
        ? merge_color(effect_color, c_white, 0.55)
        : effect_color;
    draw_set_alpha(_fade * (0.54 + (_index mod 3) * 0.16));
    draw_set_color(_bright);

    switch (effect_kind) {
        case BLADE_STAGE1_EFFECT_MAYNII:
            draw_triangle(
                _particle_x + _size * 2, _particle_y,
                _particle_x - _size, _particle_y - _size,
                _particle_x - _size, _particle_y + _size,
                false
            );
            break;

        case BLADE_STAGE1_EFFECT_KOLAR:
            draw_triangle(
                _particle_x, _particle_y - _size * 2,
                _particle_x - _size, _particle_y,
                _particle_x, _particle_y + _size * 2,
                false
            );
            draw_triangle(
                _particle_x, _particle_y - _size * 2,
                _particle_x + _size, _particle_y,
                _particle_x, _particle_y + _size * 2,
                false
            );
            break;

        case BLADE_STAGE1_EFFECT_CIELA:
            draw_circle(_particle_x, _particle_y, _size, false);
            draw_line_width(
                _particle_x - _size * 2,
                _particle_y + _size,
                _particle_x + _size * 2,
                _particle_y - _size,
                max(1, _size div 2)
            );
            break;

        case BLADE_STAGE1_EFFECT_HANDOFF:
            draw_rectangle(
                _particle_x - max(1, _size div 2),
                _particle_y - _size * 3,
                _particle_x + max(1, _size div 2),
                _particle_y + _size * 3,
                false
            );
            break;

        default:
            draw_rectangle(
                _particle_x - _size,
                _particle_y - _size,
                _particle_x + _size,
                _particle_y + _size,
                false
            );
            break;
    }
}

draw_set_alpha(1);
draw_set_color(c_white);
