/// Own the first beat's encounter outcome and complete attempt-local survival state.
state = BladeFirstBeatState.Playing;
gameplay_plane = BladeFirstBeatLoadGameplayPlane();
keyboard_bindings = BladeConfigCreateDefault().bindings.keyboard;
economy = BladeSurvivalEconomyCreate();
bomb_clears_this_frame = false;
player_phase = BladeSurvivalPlayerPhase.Active;
hit_response_ticks = 0;
respawn_ticks = 0;
invulnerable_ticks = 0;
reward_wait_ticks = 30;
feedback_text = "";
feedback_ticks = 0;
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
    BladeStage1RouteInitialize(id);
}
