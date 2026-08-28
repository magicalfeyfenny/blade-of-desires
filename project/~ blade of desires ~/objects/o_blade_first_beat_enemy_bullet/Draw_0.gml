var _shown_outer = grazed ? merge_color(outer_color, c_white, 0.45) : outer_color;
switch (bullet_kind) {
    case BladeFirstBeatBulletKind.MayniiLeaf:
    case BladeFirstBeatBulletKind.ComboLeaf:
        draw_set_color(_shown_outer);
        draw_ellipse(x - 6, y - 3, x + 6, y + 3, false);
        draw_set_color(inner_color);
        draw_line(x - 4, y, x + 4, y);
        break;

    case BladeFirstBeatBulletKind.KolarCrystal:
    case BladeFirstBeatBulletKind.ComboCrystal:
        draw_set_color(_shown_outer);
        draw_triangle(x, y - 7, x - 4, y, x, y + 7, false);
        draw_triangle(x, y - 7, x + 4, y, x, y + 7, false);
        draw_set_color(inner_color);
        draw_circle(x, y, 2, false);
        break;

    default:
        draw_set_color(_shown_outer);
        draw_circle(x, y, radius, false);
        draw_set_color(inner_color);
        draw_circle(x, y, 2, false);
        break;
}
