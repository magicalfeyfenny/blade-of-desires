var _controller = instance_find(o_blade_first_beat_controller, 0);
var _hyper_tier = _controller == noone ? 0 : _controller.economy.active_hyper_tier;
var _protected = _controller != noone
    && (_controller.invulnerable_ticks > 0 || _controller.economy.bomb_ticks > 0);
if (_controller != noone
    && _controller.player_phase == BladeSurvivalPlayerPhase.Respawning) {
    draw_set_alpha(0.35);
} else if (_protected && ((_controller.invulnerable_ticks div 4) mod 2) == 0) {
    draw_set_alpha(0.55);
}

draw_set_color(_hyper_tier > 0
    ? make_color_rgb(255, 126, 236)
    : make_color_rgb(108, 224, 255));
draw_triangle(x, y - 9, x - 7, y + 7, x + 7, y + 7, false);
draw_set_color(c_white);
draw_circle(x, y - 1, 2, false);

if (focused) {
    draw_set_color(make_color_rgb(255, 245, 160));
    draw_circle(x, y, hit_radius, false);
    draw_set_color(make_color_rgb(108, 224, 255));
    draw_circle(x, y, body_radius + 3, true);
}

if (_controller != noone && _controller.economy.bomb_ticks > 0) {
    draw_set_color(make_color_rgb(255, 230, 126));
    draw_circle(x, y, 20 + (_controller.economy.bomb_ticks mod 18), true);
}
if (_hyper_tier > 0) {
    draw_set_color(make_color_rgb(255, 126, 236));
    draw_circle(x, y, 12 + _hyper_tier * 3, true);
}
draw_set_alpha(1);
