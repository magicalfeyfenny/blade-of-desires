draw_set_color(hyper_tier > 0
    ? make_color_rgb(255, 126, 236)
    : make_color_rgb(120, 236, 255));
draw_line_width(x, y + 4 + hyper_tier, x, y - 5 - hyper_tier, 2 + hyper_tier);
draw_set_color(c_white);
draw_circle(x, y - 5, 2, false);
