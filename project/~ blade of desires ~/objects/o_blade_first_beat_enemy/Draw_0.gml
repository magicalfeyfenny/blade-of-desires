var _is_carrier = BladeSurvivalEnemyIsBombCarrier(archetype_id);
if (hit_flash > 0) {
    draw_set_color(c_white);
} else if (_is_carrier) {
    draw_set_color(make_color_rgb(255, 183, 82));
} else {
    draw_set_color(make_color_rgb(102, 210, 145));
}
draw_circle(x, y, hit_radius, false);
draw_set_color(_is_carrier
    ? make_color_rgb(115, 56, 25)
    : make_color_rgb(28, 94, 72));
draw_circle(x, y, 7, false);
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_color(c_white);
draw_text(x, y, _is_carrier ? "B" : "S");
draw_set_halign(fa_left);
draw_set_valign(fa_top);

if (tell_ticks > 0 && y >= target_y) {
    var _tell_radius = 18 + (tell_ticks mod 12);
    draw_set_color(make_color_rgb(255, 235, 128));
    draw_circle(x, y, _tell_radius, true);
}

draw_set_color(make_color_rgb(30, 24, 18));
draw_rectangle(x - 18, y - 23, x + 18, y - 19, false);
draw_set_color(_is_carrier
    ? make_color_rgb(255, 208, 94)
    : make_color_rgb(121, 238, 168));
draw_rectangle(
    x - 18, y - 23, x - 18 + 36 * hit_points / max_health, y - 19, false
);
