/// Own the first beat's encounter outcome and complete attempt-local survival state.
state = BladeFirstBeatState.Playing;
gameplay_plane = BladeFirstBeatLoadGameplayPlane();
var _config = BladeConfigCreateDefault();
if (room == r_stage1_first_beat
    && variable_global_exists("blade_config_service")) {
    _config = BladeConfigServiceSnapshot(global.blade_config_service);
}
keyboard_bindings = _config.bindings.keyboard;
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
depth = 1000;

// Only the production Stage 1 room consumes the authored deterministic route.
if (room == r_stage1_first_beat) {
    stage_audio = BladeStage1AudioCreate(_config.audio);
    BladeStage1RouteInitialize(id);
}
