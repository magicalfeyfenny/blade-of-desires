draw_clear(make_color_rgb(6, 16, 18));

// The simple forest shapes are readable gameplay presentation, not final art.
draw_set_color(make_color_rgb(16, 43, 34));
draw_rectangle(0, 0, 184, 359, false);
draw_rectangle(455, 0, 639, 359, false);
draw_set_color(make_color_rgb(24, 67, 47));
for (var _trunk_x = 22; _trunk_x < 640; _trunk_x += 54) {
    if (_trunk_x >= 185 && _trunk_x < 455) continue;
    draw_rectangle(_trunk_x, 0, _trunk_x + 13, 360, false);
}

draw_set_color(make_color_rgb(9, 28, 34));
draw_rectangle(185, 0, 454, 359, false);
draw_set_color(make_color_rgb(78, 154, 125));
draw_rectangle(185, 0, 454, 359, true);

draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_color(c_white);
draw_text(12, 12, "LOST FOREST\nFIRST COMBAT BEAT");
draw_text(12, 72, "Move  Arrow keys / WASD\nFocus Shift / X\nFire   Z / Space");
draw_text(469, 12, "Ciela\nArcade");
draw_text(469, 72, "Defeat the fae scout.\nEnemy fire locks when\nits body leaves the plane.");

if (state != BladeFirstBeatState.Playing) {
    draw_set_alpha(0.82);
    draw_set_color(c_black);
    draw_rectangle(214, 134, 426, 226, false);
    draw_set_alpha(1);
    draw_set_halign(fa_center);
    draw_set_color(c_white);
    if (state == BladeFirstBeatState.Won) {
        draw_text(320, 154, "COMBAT BEAT CLEAR\n\nPress R to play again");
    } else {
        draw_text(320, 154, "CIELA WAS HIT\n\nPress R to retry");
    }
    draw_set_halign(fa_left);
}
