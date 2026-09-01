/// Own the first beat's encounter outcome and complete attempt-local survival state.
state = BladeFirstBeatState.Playing;
gameplay_plane = BladeFirstBeatLoadGameplayPlane();
var _config = BladeConfigCreateDefault();
if (room == r_stage1_first_beat
    && variable_global_exists("blade_config_service")) {
    _config = BladeConfigServiceSnapshot(global.blade_config_service);
}
keyboard_bindings = _config.bindings.keyboard;
selected_run = undefined;
selected_ship_id = "";
player_instance = noone;
economy = BladeSurvivalEconomyCreate();
bomb_clears_this_frame = false;
player_phase = BladeSurvivalPlayerPhase.Active;
hit_response_ticks = 0;
respawn_ticks = 0;
invulnerable_ticks = 0;
reward_wait_ticks = 30;
feedback_text = "";
feedback_ticks = 0;
route_notice_text = "";
route_notice_ticks = 0;
stage_audio = undefined;
stage_route_enabled = false;
stage_defeat_queue = [];
stage_last_defeat_results = [];
stage_cue_cursor = 0;
route_cue_id = "";
route_label = "FIRST COMBAT BEAT";
midboss_state = BladeStage1MidbossStateCreate();
boss_warning_active = false;
boss_instance = noone;
boss_resolution = BladeStage1BossResolution.None;
stage_clear_awarded = false;
stage_clear_breakdown = { base: 0, lives: 0, bombs: 0, total: 0 };
depth = 1000;

// Only the production Stage 1 room consumes the authored deterministic route.
if (room == r_stage1_first_beat) {
    if (!variable_global_exists("blade_selected_run")
        || is_undefined(global.blade_selected_run)) {
        throw("Stage 1 requires a confirmed character selection");
    }
    var _selection_catalog = BladeShipSelectionLoad();
    selected_run = BladeShipSelectionRequireRun(
        _selection_catalog, global.blade_selected_run
    );
    selected_ship_id = selected_run.ship_id;
    var _player_object = BladeShipSelectionPlayerObject(
        selected_run.player_kind_id
    );
    player_instance = instance_create_layer(
        BLADE_SURVIVAL_PLAYER_START_X,
        BLADE_SURVIVAL_PLAYER_START_Y,
        "Instances",
        _player_object
    );
    stage_audio = BladeStage1AudioCreate(_config.audio);
    BladeStage1RouteInitialize(id);
}
