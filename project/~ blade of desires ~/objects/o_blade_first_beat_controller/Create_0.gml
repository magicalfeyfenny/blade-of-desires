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
depth = 1000;
