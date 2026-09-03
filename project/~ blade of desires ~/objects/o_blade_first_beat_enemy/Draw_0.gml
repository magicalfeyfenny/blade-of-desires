var _is_carrier = BladeSurvivalEnemyIsBombCarrier(archetype_id);
var _renderer = instance_find(o_blade_stage1_forest_renderer, 0);
var _body_color = variable_instance_exists(self, "body_color")
    ? body_color
    : make_color_rgb(102, 210, 145);
var _tell_color = variable_instance_exists(self, "tell_color")
    ? tell_color
    : make_color_rgb(255, 235, 128);
var _accent_color = variable_instance_exists(self, "accent_color")
    ? accent_color
    : c_white;
var _scale = variable_instance_exists(self, "visual_scale")
    ? visual_scale
    : 0.86;
var _role_id = variable_instance_exists(self, "role_id")
    ? role_id
    : BladeStage1EnemyRole.Mook;

if (_renderer != noone
    && variable_instance_exists(_renderer, "ordinary_enemy_roster_sprite")
    && BladeStage1EnemyDrawRosterCell(
        _renderer.ordinary_enemy_roster_sprite,
        _role_id,
        x,
        y,
        _scale,
        hit_flash > 0 ? c_white : c_white,
        1
    )) {
    // The roster atlas owns silhouette and fae identity; geometry remains code-owned.
} else {
    draw_set_color(hit_flash > 0 ? c_white : _body_color);
    draw_circle(x, y, hit_radius, false);
    draw_set_color(_accent_color);
    draw_circle(x, y, 4, false);
}

if (tell_ticks > 0 && y >= target_y) {
    var _tell_scale = 0.54 + (tell_ticks mod 14) / 34;
    if (_renderer != noone
        && variable_instance_exists(_renderer, "ordinary_enemy_effects_sprite")
        && BladeStage1EnemyDrawEffectCell(
            _renderer.ordinary_enemy_effects_sprite,
            _role_id,
            1,
            x,
            y,
            _tell_scale,
            c_white,
            0.86
        )) {
        // Authored row 2 is the pre-fire tell.
    } else {
        draw_set_color(_tell_color);
        draw_circle(x, y, 18 + (tell_ticks mod 12), true);
    }
}

if (hit_flash > 0) {
    var _hit_scale = 0.50 + hit_flash / 24;
    if (_renderer != noone
        && variable_instance_exists(_renderer, "ordinary_enemy_effects_sprite")
        && BladeStage1EnemyDrawEffectCell(
            _renderer.ordinary_enemy_effects_sprite,
            _role_id,
            2,
            x,
            y,
            _hit_scale,
            c_white,
            0.95
        )) {
        // Authored row 3 is the hit spark.
    }
}

if (_is_carrier) {
    // The carrier is a mook variant: this gold ring is its reward marker.
    draw_set_color(make_color_rgb(255, 208, 94));
    draw_circle(x, y, hit_radius + 4, true);
    draw_set_color(make_color_rgb(110, 58, 26));
    draw_circle(x, y, 5, false);
    draw_set_color(make_color_rgb(255, 232, 142));
    draw_circle(x, y - 1, 2, false);
}

draw_set_color(make_color_rgb(30, 24, 18));
draw_rectangle(x - 18, y - 23, x + 18, y - 19, false);
draw_set_color(_is_carrier ? make_color_rgb(255, 208, 94) : _body_color);
draw_rectangle(
    x - 18, y - 23, x - 18 + 36 * hit_points / max_health, y - 19, false
);
draw_set_color(c_white);
