draw_set_color(make_color_rgb(108, 224, 255));
draw_triangle(x, y - 9, x - 7, y + 7, x + 7, y + 7, false);
draw_set_color(c_white);
draw_circle(x, y - 1, 2, false);

if (focused) {
    draw_set_color(make_color_rgb(255, 245, 160));
    draw_circle(x, y, hit_radius, false);
    draw_set_color(make_color_rgb(108, 224, 255));
    draw_circle(x, y, body_radius + 3, true);
}
