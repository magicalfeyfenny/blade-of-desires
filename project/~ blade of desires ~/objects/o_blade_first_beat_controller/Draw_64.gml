display_set_gui_size(room_width, room_height);
var _bounds = BladeCombatPlanePixelBounds(gameplay_plane);

// The world renderer owns the clear; these translucent panels keep combat readable.
draw_set_alpha(0.88);
draw_set_color(make_color_rgb(6, 18, 22));
draw_rectangle(0, 0, _bounds.left - 1, 359, false);
draw_rectangle(_bounds.right_exclusive, 0, 639, 359, false);
draw_set_alpha(0.12);
draw_set_color(make_color_rgb(5, 22, 28));
draw_rectangle(
    _bounds.left, _bounds.top,
    _bounds.right_exclusive - 1, _bounds.bottom_exclusive - 1, false
);
draw_set_alpha(1);
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
draw_text(12, 102, "POINT  " + string(BladeSurvivalCurrentPointValue(economy)));
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
    draw_text(12, 208, "BONUS T" + string(economy.active_hyper_tier)
        + "  DANGER UP\n" + string(economy.hyper_ticks));
} else if (_ready_tier > 0) {
    draw_text(12, 208, "READY T" + string(_ready_tier));
} else {
    draw_text(12, 208, "NOT READY  NEXT 100");
}

draw_text(12, 250, "Move   Arrows\nFocus  Shift\nFire   Z"
    + "\nPower  X\nFocus widens item reach\nHyper pulls all items");
draw_text(12, 304, string_upper(BladeDifficultyPlayerName(economy.difficulty_id))
    + "  RANK " + string(BladeSurvivalEconomyRank(economy)) + " / 50");

var _selected_ship_name = selected_ship_id == ""
    ? "CIELA"
    : BladeStage1RouteShipName(selected_ship_id);
draw_text(469, 12, _selected_ship_name + "\nSTAGE 1");
draw_text(469, 62, route_label);
if (stage_route_enabled
    && BladeStage1BossDrawHud(id, 469, 92, 155)) {
    // Asahi owns the right panel from warning through the boss terminal.
} else if (stage_route_enabled
    && BladeStage1MidbossDrawHud(id, 469, 100, 155)) {
    // The midboss HUD owns this space while its personal or combo life is active.
} else if (state == BladeFirstBeatState.Won) {
    draw_text(469, 100, "CLEAR BONUS"
        + "\nBASE   " + string(stage_clear_breakdown.base)
        + "\nLIVES  " + string(stage_clear_breakdown.lives)
        + "\nBOMBS  " + string(stage_clear_breakdown.bombs));
} else {
    draw_text(469, 100, "Clear each wave.\nGold carriers hold\none Bomb each.");
}
if (state == BladeFirstBeatState.Won) {
    draw_set_color(make_color_rgb(255, 232, 142));
    draw_text(469, 188, "RUN COMPLETE");
} else if (state == BladeFirstBeatState.Failed) {
    draw_set_color(make_color_rgb(255, 156, 126));
    draw_text(469, 188, "ATTEMPT ENDED");
} else if (economy.bomb_ticks > 0) {
    draw_set_color(make_color_rgb(255, 224, 116));
    draw_text(469, 188, "PROTECTED\nBOMB " + string(economy.bomb_ticks));
} else if (invulnerable_ticks > 0) {
    draw_set_color(make_color_rgb(126, 228, 255));
    draw_text(469, 188, "PROTECTED\n" + string(invulnerable_ticks));
} else {
    draw_set_color(make_color_rgb(255, 156, 126));
    draw_text(469, 188, "VULNERABLE");
}
draw_set_color(c_white);
draw_text(469, 238, "Every emission uses\nthe shared 2D plane\nand current hurtbox.");
if (feedback_ticks > 0) {
    draw_set_color(make_color_rgb(255, 239, 145));
    draw_text(469, 298, feedback_text);
}

if (route_notice_ticks > 0) {
    var _notice_alpha = min(1, route_notice_ticks / 20);
    draw_set_alpha(0.72 * _notice_alpha);
    draw_set_color(make_color_rgb(4, 16, 20));
    draw_rectangle(214, 28, 426, 66, false);
    draw_set_alpha(_notice_alpha);
    draw_set_halign(fa_center);
    draw_set_color(make_color_rgb(255, 241, 170));
    draw_text(320, 38, route_notice_text);
    draw_set_halign(fa_left);
    draw_set_alpha(1);
}

if (state != BladeFirstBeatState.Playing) {
    if (state == BladeFirstBeatState.Won) {
        draw_set_alpha(0.82);
        draw_set_color(c_black);
        draw_rectangle(214, 134, 426, 226, false);
        draw_set_alpha(1);
        draw_set_halign(fa_center);
        draw_set_color(c_white);
        var _clear_kind = boss_resolution == BladeStage1BossResolution.Defeat
            ? "ASAHI DEFEATED"
            : "TIMEOUT SURVIVAL";
        draw_text(
            320,
            139,
            "STAGE CLEAR\n" + _clear_kind
                + "\nBONUS  " + string(stage_clear_breakdown.total)
                + "\n\nR retry   Esc exit"
        );
        draw_set_halign(fa_left);
    } else if (state == BladeFirstBeatState.Failed) {
        draw_set_alpha(0.82);
        draw_set_color(c_black);
        draw_rectangle(214, 134, 426, 226, false);
        draw_set_alpha(1);
        draw_set_halign(fa_center);
        draw_set_color(c_white);
        draw_text(320, 154, "GAME OVER\n\nR retry   Esc exit");
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
    if (_response_action == BladeSurvivalPowerAction.DeathBombHyper) {
        _response_prompt = "PRESS X: DEATH-BOMB HYPER";
    } else if (_response_action == BladeSurvivalPowerAction.EmergencyBomb) {
        _response_prompt = "PRESS X: SPEND ALL BOMBS";
    }
    draw_text(320, 156, "HIT RESPONSE  " + string(hit_response_ticks)
        + "\n" + _response_prompt);
    draw_set_halign(fa_left);
}
