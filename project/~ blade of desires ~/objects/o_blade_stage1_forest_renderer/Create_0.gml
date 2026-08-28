/// Own the Stage 1 perspective assets and presentation-only route position.
geometry_format = BladeStage1ForestVertexFormatCreate();
route_buffer = BladeStage1ForestBufferLoad(
    "models/stage1/lost_forest_route.vbuff",
    geometry_format
);
billboard_buffer = BladeStage1ForestBillboardBufferCreate(geometry_format);
material_sprite = BladeStage1ForestTextureLoad(
    "textures/stage1/lost_forest_materials.png"
);
fae_sprite = BladeStage1ForestTextureLoad(
    "textures/stage1/lost_forest_fae.png"
);
light_sprite = BladeStage1ForestTextureLoad(
    "textures/stage1/lost_forest_fae_light.png"
);
assets_ready = route_buffer >= 0
    && billboard_buffer >= 0
    && sprite_exists(material_sprite)
    && sprite_exists(fae_sprite)
    && sprite_exists(light_sprite);

route_progress = 0;
route_progress_limit = 218;
route_scroll_speed = 0.09;
route_scroll_enabled = true;
camera_x = 0;
camera_y = -18;
camera_z = -8;
look_x = 0;
look_y = 6;
look_z = -1.8;

fae_time = 0;
fae_history_length = 76;
fae_history_x = array_create(fae_history_length, 0);
fae_history_y = array_create(fae_history_length, camera_y + 21);
fae_history_z = array_create(fae_history_length, -4.8);
light_lags = [10, 23, 38, 55, 74];
depth = 1500;
