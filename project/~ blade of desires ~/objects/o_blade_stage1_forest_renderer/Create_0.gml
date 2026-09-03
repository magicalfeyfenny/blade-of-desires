/// Own Stage 1's separate model and billboard buffers plus their textures.
world_format = BladeStage1ForestWorldVertexFormatCreate();
terrain_buffer = BladeStage1ForestBufferLoad(
    "models/stage1/lost_forest_terrain.vbuff", world_format
);
tree_a_buffer = BladeStage1ForestBufferLoad(
    "models/stage1/lost_forest_tree_a.vbuff", world_format
);
tree_b_buffer = BladeStage1ForestBufferLoad(
    "models/stage1/lost_forest_tree_b.vbuff", world_format
);
world_tree_buffer = BladeStage1ForestBufferLoad(
    "models/stage1/lost_forest_world_tree.vbuff", world_format
);
skybox_buffer = BladeStage1ForestBufferLoad(
    "models/stage1/lost_forest_skybox.vbuff", world_format
);
grass_billboard_buffer = BladeStage1ForestBufferLoad(
    "models/stage1/lost_forest_grass_billboard.vbuff", world_format
);
vines_billboard_buffer = BladeStage1ForestBufferLoad(
    "models/stage1/lost_forest_vines_billboard.vbuff", world_format
);
bush_billboard_buffer = BladeStage1ForestBufferLoad(
    "models/stage1/lost_forest_bush_billboard.vbuff", world_format
);
fae_billboard_buffer = BladeStage1ForestBufferLoad(
    "models/stage1/lost_forest_fae_billboard.vbuff", world_format
);
ball_light_billboard_buffer = BladeStage1ForestBufferLoad(
    "models/stage1/lost_forest_ball_light_billboard.vbuff", world_format
);

material_sprite = BladeStage1ForestTextureLoad(
    "textures/stage1/lost_forest_materials.png"
);
skybox_sprite = BladeStage1ForestTextureLoad(
    "textures/stage1/lost_forest_skybox.png"
);
fae_sprite = BladeStage1ForestTextureLoad(
    "textures/stage1/lost_forest_fae.png"
);
grass_sprite = BladeStage1ForestTextureLoad(
    "textures/stage1/lost_forest_grass.png"
);
vines_sprite = BladeStage1ForestTextureLoad(
    "textures/stage1/lost_forest_vines.png"
);
bush_sprite = BladeStage1ForestTextureLoad(
    "textures/stage1/lost_forest_bush.png"
);
ball_light_sprite = BladeStage1ForestTextureLoad(
    "textures/stage1/lost_forest_ball_light.png"
);

maynii_sprite = BladeStage1ForestTextureLoad("sprites/stage1/maynii_boss.png");
kolar_sprite = BladeStage1ForestTextureLoad("sprites/stage1/kolar_boss.png");
ciela_sprite = BladeStage1ForestTextureLoad("sprites/stage1/ciela_player.png");
ciela_boss_sprite = BladeStage1ForestTextureLoad("sprites/stage1/ciela_boss.png");
maynii_player_sprite = BladeStage1ForestTextureLoad(
    "sprites/stage1/maynii_player.png"
);
maynii_option_sprite = BladeStage1ForestTextureLoad(
    "sprites/stage1/maynii_option.png"
);
maynii_tracking_shot_sprite = BladeStage1ForestTextureLoad(
    "sprites/stage1/maynii_tracking_shot.png"
);
maynii_forward_shot_sprite = BladeStage1ForestTextureLoad(
    "sprites/stage1/maynii_forward_shot.png"
);
ciela_wave_sprite = BladeStage1ForestTextureLoad("sprites/stage1/ciela_wave.png");
ciela_current_sprite = BladeStage1ForestTextureLoad(
    "sprites/stage1/ciela_current.png"
);
ciela_kolar_combo_sprite = BladeStage1ForestTextureLoad(
    "sprites/stage1/ciela_kolar_combo.png"
);
kolar_player_sprite = BladeStage1ForestTextureLoad(
    "sprites/stage1/kolar_player.png", 6
);
kolar_option_sprite = BladeStage1ForestTextureLoad(
    "sprites/stage1/kolar_option.png", 2
);
kolar_close_shot_sprite = BladeStage1ForestTextureLoad(
    "sprites/stage1/kolar_close_channel.png", 4
);
kolar_ranged_shot_sprite = BladeStage1ForestTextureLoad(
    "sprites/stage1/kolar_ranged_shot.png", 4
);
ciela_maynii_combo_sprite = BladeStage1ForestTextureLoad(
    "sprites/stage1/ciela_maynii_combo.png"
);
maynii_leaf_sprite = BladeStage1ForestTextureLoad("sprites/stage1/maynii_leaf.png");
kolar_crystal_sprite = BladeStage1ForestTextureLoad(
    "sprites/stage1/kolar_crystal.png"
);
asahi_sprite = BladeStage1ForestTextureLoad("sprites/stage1/asahi_boss.png");
asahi_sunfire_sprite = BladeStage1ForestTextureLoad(
    "sprites/stage1/asahi_sunfire.png"
);
asahi_hud_frame_sprite = BladeStage1ForestTextureLoad(
    "sprites/stage1/asahi_hud_frame.png"
);

tree_placements = BladeStage1ForestTreePlacementsCreate();
foliage_placements = BladeStage1ForestFoliagePlacementsCreate();
fae_placements = BladeStage1ForestFaePlacementsCreate();
fae_trail_placements = BladeStage1ForestFaeTrailPlacementsCreate(
    fae_placements
);
ball_light_placements = BladeStage1ForestBallLightPlacementsCreate();
point_lights = BladeStage1ForestPointLightsCreate(
    fae_placements, ball_light_placements
);
nearest_light_arrays = { positions: [], colors: [] };

world_uniforms = BladeStage1ForestWorldUniformsCreate();
cylindrical_uniforms = BladeStage1ForestBillboardUniformsCreate(
    shd_blade_stage1_billboard_cylindrical, true, true
);
spherical_uniforms = BladeStage1ForestBillboardUniformsCreate(
    shd_blade_stage1_billboard_spherical, false, false
);

assets_ready = terrain_buffer >= 0
    && tree_a_buffer >= 0
    && tree_b_buffer >= 0
    && world_tree_buffer >= 0
    && skybox_buffer >= 0
    && grass_billboard_buffer >= 0
    && vines_billboard_buffer >= 0
    && bush_billboard_buffer >= 0
    && fae_billboard_buffer >= 0
    && ball_light_billboard_buffer >= 0
    && sprite_exists(material_sprite)
    && sprite_exists(skybox_sprite)
    && sprite_exists(fae_sprite)
    && sprite_exists(grass_sprite)
    && sprite_exists(vines_sprite)
    && sprite_exists(bush_sprite)
    && sprite_exists(ball_light_sprite)
    && sprite_exists(maynii_sprite)
    && sprite_exists(kolar_sprite)
    && sprite_exists(ciela_sprite)
    && sprite_exists(ciela_boss_sprite)
    && sprite_exists(maynii_player_sprite)
    && sprite_exists(maynii_option_sprite)
    && sprite_exists(maynii_tracking_shot_sprite)
    && sprite_exists(maynii_forward_shot_sprite)
    && sprite_exists(ciela_wave_sprite)
    && sprite_exists(ciela_current_sprite)
    && sprite_exists(ciela_kolar_combo_sprite)
    && sprite_exists(kolar_player_sprite)
    && sprite_exists(kolar_option_sprite)
    && sprite_exists(kolar_close_shot_sprite)
    && sprite_exists(kolar_ranged_shot_sprite)
    && sprite_exists(ciela_maynii_combo_sprite)
    && sprite_exists(maynii_leaf_sprite)
    && sprite_exists(kolar_crystal_sprite)
    && sprite_exists(asahi_sprite)
    && sprite_exists(asahi_sunfire_sprite)
    && sprite_exists(asahi_hud_frame_sprite);

route_progress = 0;
route_progress_limit = 218;
route_progress_cap = BLADE_STAGE1_FOREST_FIRST_HALF_CAP;
route_scroll_speed = 0.09;
route_scroll_enabled = true;
presentation_time = 0;
camera_x = 0;
camera_y = -18;
camera_z = -8;
look_x = 0;
look_y = 6;
look_z = -1.8;
boss_orbit_active = false;
boss_orbit_angle = 270;
boss_orbit_center_x = BladeStage1ForestRouteCenter(248);
boss_orbit_center_y = 248;
boss_orbit_surface_z = BladeStage1ForestSurfaceZ(
    boss_orbit_center_x, boss_orbit_center_y
);
depth = 1500;
