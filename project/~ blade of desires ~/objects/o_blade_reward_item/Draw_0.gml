if (kind == BladeSurvivalItemKind.Bomb) {
    draw_set_color(make_color_rgb(255, 215, 76));
    draw_circle(x, y, radius, false);
    draw_set_color(make_color_rgb(105, 52, 23));
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text(x, y, "B");
} else {
    draw_set_color(make_color_rgb(111, 245, 207));
    draw_triangle(x, y - radius, x - radius, y, x, y + radius, false);
    draw_triangle(x, y - radius, x + radius, y, x, y + radius, false);
    draw_set_color(c_white);
    draw_circle(x, y, 2, false);
}
draw_set_halign(fa_left);
draw_set_valign(fa_top);
