/// Initialize one configurable ordinary target; Stage content replaces these defaults.
content_id = BLADE_SURVIVAL_BOMB_CARRIER_ID;
participant_id = "";
stage_instance_id = "";
stage_encounter_id = "";
stage_managed = false;
defeat_queued = false;
// Ordinary enemies never auto-cancel their emitted bullets on defeat.
auto_cancel_bullets_on_defeat = false;
target_kind = BladeFirstBeatTargetKind.Ordinary;
targetable = true;
spawn_order = 0;
hit_flash = 0;
target_y = 72;
fire_cooldown = 0;
role_id = BladeStage1EnemyRole.Mook;
role_content_id = BLADE_STAGE1_MOOK_CONTENT_ID;
display_name = "MOOK";
variant_id = "bomb_carrier";
is_bomb_carrier = true;
projectile_radius = 4;
bullet_kind = BladeFirstBeatBulletKind.MookPetal;
movement_amplitude = 8;
movement_step_degrees = 4;
movement_phase = 0;
pattern_phase = 0;
body_color = make_color_rgb(105, 218, 126);
tell_color = make_color_rgb(216, 255, 130);
accent_color = make_color_rgb(233, 255, 196);
visual_scale = 0.86;
motion_id = "leaf_sweep";
tell_id = "leaf_ring";
pattern_id = "three_leaf_fan";
expected_defeat_ticks = 18;
BladeStage1EnemyConfigure(
    id, BLADE_STAGE1_MOOK_CONTENT_ID, 0,
    BLADE_DIFFICULTY_NORMAL_ID, 0, true
);
content_id = BLADE_SURVIVAL_BOMB_CARRIER_ID;
target_y = 72;
