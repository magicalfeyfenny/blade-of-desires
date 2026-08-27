draw_clear(make_color_rgb(6, 16, 18));
var _bounds = BladeCombatPlanePixelBounds(gameplay_plane);

// The simple forest shapes are readable gameplay presentation, not final art.
draw_set_color(make_color_rgb(16, 43, 34));
draw_rectangle(0, 0, _bounds.left - 1, 359, false);
draw_rectangle(_bounds.right_exclusive, 0, 639, 359, false);
draw_set_color(make_color_rgb(24, 67, 47));
for (var _trunk_x = 22; _trunk_x < 640; _trunk_x += 54) {
    if (_trunk_x >= _bounds.left && _trunk_x < _bounds.right_exclusive) continue;
    draw_rectangle(_trunk_x, 0, _trunk_x + 13, 360, false);
}

draw_set_color(make_color_rgb(9, 28, 34));
draw_rectangle(
    _bounds.left, _bounds.top,
    _bounds.right_exclusive - 1, _bounds.bottom_exclusive - 1, false
);
draw_set_color(make_color_rgb(78, 154, 125));
draw_rectangle(
    _bounds.left, _bounds.top,
    _bounds.right_exclusive - 1, _bounds.bottom_exclusive - 1, true
);

draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_color(c_white);
draw_text(12, 12, "LOST FOREST\nSURVIVAL LOOP");
draw_text(12, 62, "SCORE\n" + string_format(economy.score, 9, 0));
draw_text(12, 102, "POINT  " + string(economy.point_value));
draw_text(12, 122, "LIVES  " + string(economy.lives));
draw_text(12, 142, "BOMBS  " + string(economy.bombs)
    + " / " + string(BLADE_SURVIVAL_BOMB_CAP));

var _ready_tier = BladeSurvivalHyperTierForMeter(economy.hyper_meter);
draw_text(12, 174, "HYPER  " + string(economy.hyper_meter)
    + " / " + string(BLADE_SURVIVAL_HYPER_TIER_3));
draw_set_color(make_color_rgb(30, 58, 65));
draw_rectangle(12, 194, 168, 202, false);
draw_set_color(make_color_rgb(89, 217, 241));
draw_rectangle(
    12, 194,
    12 + 156 * economy.hyper_meter / BLADE_SURVIVAL_HYPER_TIER_3,
    202, false
);
draw_set_color(c_white);
if (economy.active_hyper_tier > 0) {
    draw_text(12, 208, "ACTIVE T" + string(economy.active_hyper_tier)
        + "  " + string(economy.hyper_ticks));
} else if (_ready_tier > 0) {
    draw_text(12, 208, "READY T" + string(_ready_tier));
} else {
    draw_text(12, 208, "NOT READY  NEXT 100");
}

draw_text(12, 250, "Move   Arrows\nFocus  Shift\nFire   Z"
    + "\nPower  X\nHyper takes priority");

draw_text(469, 12, "CIELA\nARCADE");
draw_text(469, 62, "Defeat the gold\nbomb carrier, then\ncollect its rewards.");
if (economy.bomb_ticks > 0) {
    draw_set_color(make_color_rgb(255, 224, 116));
    draw_text(469, 132, "PROTECTED\nBOMB " + string(economy.bomb_ticks));
} else if (invulnerable_ticks > 0) {
    draw_set_color(make_color_rgb(126, 228, 255));
    draw_text(469, 132, "PROTECTED\n" + string(invulnerable_ticks));
} else {
    draw_set_color(make_color_rgb(255, 156, 126));
    draw_text(469, 132, "VULNERABLE");
}
draw_set_color(c_white);
draw_text(469, 190, "Enemy fire uses\none shared plane\nand hurtbox gate.");
if (feedback_ticks > 0) {
    draw_set_color(make_color_rgb(255, 239, 145));
    draw_text(469, 270, feedback_text);
}

if (state != BladeFirstBeatState.Playing) {
    if (state == BladeFirstBeatState.Won) {
        draw_set_alpha(0.82);
        draw_set_color(c_black);
        draw_rectangle(214, 134, 426, 226, false);
        draw_set_alpha(1);
        draw_set_halign(fa_center);
        draw_set_color(c_white);
        draw_text(320, 154, "COMBAT BEAT CLEAR\n\nPress R to play again");
        draw_set_halign(fa_left);
    } else if (state == BladeFirstBeatState.Failed) {
        draw_set_alpha(0.82);
        draw_set_color(c_black);
        draw_rectangle(214, 134, 426, 226, false);
        draw_set_alpha(1);
        draw_set_halign(fa_center);
        draw_set_color(c_white);
        draw_text(320, 154, "GAME OVER\n\nPress R to retry");
        draw_set_halign(fa_left);
    }
}

if (player_phase == BladeSurvivalPlayerPhase.HitResponse) {
    draw_set_alpha(0.45);
    draw_set_color(make_color_rgb(105, 12, 20));
    draw_rectangle(_bounds.left, 0, _bounds.right_exclusive - 1, 359, false);
    draw_set_alpha(1);
    draw_set_halign(fa_center);
    draw_set_color(c_white);
    var _response_action = BladeSurvivalPowerActionForX(economy, true);
    var _response_prompt = "NO DEFENSE READY\nDEATH WILL COMMIT";
    if (_response_action == BladeSurvivalPowerAction.Hyper) {
        _response_prompt = "PRESS X: HYPER DEFENSE T"
            + string(BladeSurvivalHyperTierForMeter(economy.hyper_meter));
    } else if (_response_action == BladeSurvivalPowerAction.EmergencyBomb) {
        _response_prompt = "PRESS X: SPEND ALL BOMBS";
    }
    draw_text(320, 156, "HIT RESPONSE  " + string(hit_response_ticks)
        + "\n" + _response_prompt);
    draw_set_halign(fa_left);
}
