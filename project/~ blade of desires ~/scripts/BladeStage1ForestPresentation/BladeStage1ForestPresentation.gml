#macro BLADE_STAGE1_FOREST_FIRST_HALF_CAP 86
#macro BLADE_STAGE1_FOREST_SECOND_HALF_CAP 176
#macro BLADE_STAGE1_WORLD_TREE_TRAVEL_TICKS 180
#macro BLADE_STAGE1_FOREST_POINT_LIGHT_LIMIT 8

/// Creates the normal-bearing layout used by every modular Stage 1 model.
function BladeStage1ForestWorldVertexFormatCreate() {
    vertex_format_begin();
    vertex_format_add_position_3d();
    vertex_format_add_normal();
    vertex_format_add_colour();
    vertex_format_add_texcoord();
    return vertex_format_end();
}

/// Finds one packaged Stage 1 asset without making the renderer own packaging.
function BladeStage1ForestIncludedPath(_relative_path) {
    var _candidates = [
        program_directory + _relative_path,
        program_directory + "datafiles/" + _relative_path,
        working_directory + _relative_path,
    ];
    for (var _index = 0; _index < array_length(_candidates); ++_index) {
        if (file_exists(_candidates[_index])) return _candidates[_index];
    }
    return "";
}

/// Loads one frozen normal-bearing mesh and rejects incomplete triangles.
function BladeStage1ForestBufferLoad(_relative_path, _format) {
    var _path = BladeStage1ForestIncludedPath(_relative_path);
    if (_path == "") {
        show_debug_message("Missing Stage 1 model: " + _relative_path);
        return -1;
    }

    var _data = buffer_load(_path);
    var _byte_count = buffer_get_size(_data);
    // Three 36-byte vertices form every triangle in the governed VBUFF export.
    if (_byte_count <= 0 || _byte_count mod 108 != 0) {
        buffer_delete(_data);
        show_debug_message("Invalid Stage 1 model: " + _relative_path);
        return -1;
    }

    var _vertex_buffer = vertex_create_buffer_from_buffer(_data, _format);
    buffer_delete(_data);
    vertex_freeze(_vertex_buffer);
    return _vertex_buffer;
}

/// Loads one full-image runtime sprite and gives 2D consumers a useful origin.
function BladeStage1ForestTextureLoad(_relative_path) {
    var _path = BladeStage1ForestIncludedPath(_relative_path);
    if (_path == "") {
        show_debug_message("Missing Stage 1 texture: " + _relative_path);
        return -1;
    }
    var _sprite = sprite_add(_path, 1, false, false, 0, 0);
    if (sprite_exists(_sprite)) {
        sprite_set_offset(
            _sprite,
            sprite_get_width(_sprite) * 0.5,
            sprite_get_height(_sprite) * 0.5
        );
    }
    return _sprite;
}

/// Caches the uniforms used by the lit model shader.
function BladeStage1ForestWorldUniformsCreate() {
    return {
        ambient: shader_get_uniform(shd_blade_stage1_lit_world,
            "u_ambient_color"),
        directional_direction: shader_get_uniform(shd_blade_stage1_lit_world,
            "u_directional_direction"),
        directional_color: shader_get_uniform(shd_blade_stage1_lit_world,
            "u_directional_color"),
        point_positions: shader_get_uniform(shd_blade_stage1_lit_world,
            "u_point_position_range[0]"),
        point_colors: shader_get_uniform(shd_blade_stage1_lit_world,
            "u_point_color_strength[0]"),
        lighting_mix: shader_get_uniform(shd_blade_stage1_lit_world,
            "u_lighting_mix"),
        alpha_cutoff: shader_get_uniform(shd_blade_stage1_lit_world,
            "u_alpha_cutoff"),
    };
}

/// Caches the common and optional motion uniforms used by one billboard shader.
function BladeStage1ForestBillboardUniformsCreate(
    _shader, _has_camera, _has_sway
) {
    return {
        size: shader_get_uniform(_shader, "u_size"),
        tint: shader_get_uniform(_shader, "u_tint"),
        alpha_cutoff: shader_get_uniform(_shader, "u_alpha_cutoff"),
        camera: _has_camera
            ? shader_get_uniform(_shader, "u_camera_position")
            : -1,
        sway: _has_sway ? shader_get_uniform(_shader, "u_sway") : -1,
        sway_pivot: _has_sway
            ? shader_get_uniform(_shader, "u_sway_pivot")
            : -1,
    };
}

/// Maps each authored route cue to one bounded, player-visible camera segment.
function BladeStage1ForestApplyRouteCue(_renderer, _cue_id) {
    switch (_cue_id) {
        case "cue.stage1.forest_travel":
            _renderer.route_progress_cap = BLADE_STAGE1_FOREST_FIRST_HALF_CAP;
            _renderer.route_scroll_speed = 0.10;
            _renderer.route_scroll_enabled = true;
            return true;

        case "cue.stage1.midboss_stop":
            _renderer.route_progress_cap = BLADE_STAGE1_FOREST_FIRST_HALF_CAP;
            _renderer.route_scroll_enabled = false;
            return true;

        case "cue.stage1.forest_resume":
            _renderer.route_progress_cap = BLADE_STAGE1_FOREST_SECOND_HALF_CAP;
            _renderer.route_scroll_speed = 0.12;
            _renderer.route_scroll_enabled = true;
            return true;

        case "cue.stage1.world_tree_approach":
            _renderer.route_progress_cap = _renderer.route_progress_limit;
            _renderer.route_scroll_speed = max(
                0.18,
                (_renderer.route_progress_limit - _renderer.route_progress)
                    / BLADE_STAGE1_WORLD_TREE_TRAVEL_TICKS
            );
            _renderer.route_scroll_enabled = true;
            return true;

        case "cue.stage1.world_tree_handoff":
            _renderer.route_progress = _renderer.route_progress_limit;
            _renderer.route_progress_cap = _renderer.route_progress_limit;
            _renderer.route_scroll_enabled = false;
            return true;

        case "cue.stage1.asahi_warning":
            _renderer.route_progress = _renderer.route_progress_limit;
            _renderer.route_progress_cap = _renderer.route_progress_limit;
            _renderer.route_scroll_enabled = false;
            _renderer.boss_orbit_active = true;
            _renderer.boss_orbit_angle = 270;
            return true;

        case "cue.stage1.stage_clear":
            _renderer.route_scroll_enabled = false;
            return true;
    }
    return false;
}

/// Advances the presentation camera and every independently moving scene prop.
function BladeStage1ForestPresentationStep(_renderer) {
    if (_renderer.route_scroll_enabled) {
        _renderer.route_progress = min(
            _renderer.route_progress + _renderer.route_scroll_speed,
            _renderer.route_progress_cap
        );
    }
    if (_renderer.boss_orbit_active) {
        // Only presentation matrices orbit; the canonical 2D plane is untouched.
        _renderer.boss_orbit_angle = (
            _renderer.boss_orbit_angle + 0.16
        ) mod 360;
        _renderer.camera_x = _renderer.boss_orbit_center_x
            + dcos(_renderer.boss_orbit_angle) * 28;
        _renderer.camera_y = _renderer.boss_orbit_center_y
            + dsin(_renderer.boss_orbit_angle) * 38;
        _renderer.camera_z = _renderer.boss_orbit_surface_z - 11
            + dsin(_renderer.boss_orbit_angle * 1.4) * 1.5;
        _renderer.look_x = _renderer.boss_orbit_center_x;
        _renderer.look_y = _renderer.boss_orbit_center_y;
        _renderer.look_z = _renderer.boss_orbit_surface_z - 19;
    } else {
        _renderer.camera_x = 0;
        _renderer.camera_y = -18 + _renderer.route_progress;
        _renderer.camera_z = -8;
        _renderer.look_x = 0;
        _renderer.look_y = _renderer.camera_y + 24;
        _renderer.look_z = -1.8;
    }

    _renderer.presentation_time += 1;
    var _time = _renderer.presentation_time;
    for (var _foliage_index = 0;
        _foliage_index < array_length(_renderer.foliage_placements);
        ++_foliage_index) {
        var _foliage = _renderer.foliage_placements[_foliage_index];
        _foliage.sway = dsin(
            _foliage.sway_phase + _time * _foliage.sway_speed
        ) * _foliage.sway_range;
    }

    for (var _fae_index = 0;
        _fae_index < array_length(_renderer.fae_placements);
        ++_fae_index) {
        var _fae = _renderer.fae_placements[_fae_index];
        var _position = BladeStage1ForestFaePathPosition(_fae, _time);
        _fae.x = _position.x;
        _fae.y = _position.y;
        _fae.z = _position.z;
        var _fae_light = _renderer.point_lights[_fae_index];
        _fae_light.x = _fae.x;
        _fae_light.y = _fae.y;
        _fae_light.z = _fae.z;
    }

    for (var _trail_index = 0;
        _trail_index < array_length(_renderer.fae_trail_placements);
        ++_trail_index) {
        var _trail = _renderer.fae_trail_placements[_trail_index];
        var _owner = _renderer.fae_placements[_trail.fae_index];
        var _trail_position = BladeStage1ForestFaePathPosition(
            _owner, _time - _trail.lag_ticks
        );
        _trail.x = _trail_position.x;
        _trail.y = _trail_position.y;
        _trail.z = _trail_position.z;
    }

    var _ball_light_offset = array_length(_renderer.fae_placements);
    for (var _ball_index = 0;
        _ball_index < array_length(_renderer.ball_light_placements);
        ++_ball_index) {
        var _ball = _renderer.ball_light_placements[_ball_index];
        var _ball_angle = _ball.orbit_phase + _time * _ball.orbit_speed;
        _ball.x = _ball.anchor_x
            + dcos(_ball_angle) * _ball.orbit_radius_x;
        _ball.y = _ball.anchor_y
            + dsin(_ball_angle) * _ball.orbit_radius_y;
        _ball.z = BladeStage1ForestSurfaceZ(_ball.x, _ball.y) + _ball.altitude
            + dsin(_ball_angle * 1.9 + _ball.orbit_phase)
                * _ball.orbit_height;
        var _ball_light = _renderer.point_lights[
            _ball_light_offset + _ball_index
        ];
        _ball_light.x = _ball.x;
        _ball_light.y = _ball.y;
        _ball_light.z = _ball.z;
    }
}

/// Selects the eight nearest authored lights and writes packed uniform arrays.
function BladeStage1ForestNearestLightArrays(_renderer) {
    var _light_count = array_length(_renderer.point_lights);
    var _used = array_create(_light_count, false);
    var _positions = array_create(BLADE_STAGE1_FOREST_POINT_LIGHT_LIMIT * 4, 0);
    var _colors = array_create(BLADE_STAGE1_FOREST_POINT_LIGHT_LIMIT * 4, 0);

    for (var _slot = 0; _slot < BLADE_STAGE1_FOREST_POINT_LIGHT_LIMIT; ++_slot) {
        var _best_index = -1;
        var _best_distance = 1000000000000;
        for (var _index = 0; _index < _light_count; ++_index) {
            if (_used[_index]) continue;
            var _light = _renderer.point_lights[_index];
            var _distance = sqr(_light.x - _renderer.camera_x)
                + sqr(_light.y - _renderer.camera_y)
                + sqr(_light.z - _renderer.camera_z);
            if (_distance < _best_distance) {
                _best_distance = _distance;
                _best_index = _index;
            }
        }
        if (_best_index < 0) break;

        _used[_best_index] = true;
        var _selected = _renderer.point_lights[_best_index];
        var _offset = _slot * 4;
        _positions[_offset] = _selected.x;
        _positions[_offset + 1] = _selected.y;
        _positions[_offset + 2] = _selected.z;
        _positions[_offset + 3] = _selected.range;
        _colors[_offset] = _selected.red;
        _colors[_offset + 1] = _selected.green;
        _colors[_offset + 2] = _selected.blue;
        _colors[_offset + 3] = _selected.strength;
    }
    return { positions: _positions, colors: _colors };
}

/// Begins one lit-model pass with dawn ambient, sun, and nearby prop lights.
function BladeStage1ForestWorldShaderBegin(_renderer, _lighting_mix, _cutoff) {
    shader_set(shd_blade_stage1_lit_world);
    var _uniforms = _renderer.world_uniforms;
    shader_set_uniform_f(_uniforms.ambient, 0.24, 0.28, 0.34);
    shader_set_uniform_f(_uniforms.directional_direction, 0.34, -0.24, 0.91);
    shader_set_uniform_f(_uniforms.directional_color, 0.72, 0.52, 0.39);
    shader_set_uniform_f_array(
        _uniforms.point_positions,
        _renderer.nearest_light_arrays.positions
    );
    shader_set_uniform_f_array(
        _uniforms.point_colors,
        _renderer.nearest_light_arrays.colors
    );
    shader_set_uniform_f(_uniforms.lighting_mix, _lighting_mix);
    shader_set_uniform_f(_uniforms.alpha_cutoff, _cutoff);
}

/// Submits one reusable model at a fixed authored world transform.
function BladeStage1ForestModelSubmit(
    _buffer, _texture_sprite, _x, _y, _z, _rotation, _scale
) {
    if (_buffer < 0 || !sprite_exists(_texture_sprite)) return false;
    matrix_set(matrix_world, matrix_build(
        _x, _y, _z, 0, 0, _rotation, _scale, _scale, _scale
    ));
    vertex_submit(_buffer, pr_trianglelist, sprite_get_texture(_texture_sprite, 0));
    return true;
}

/// Begins either fixed-upright or fully camera-facing billboard rendering.
function BladeStage1ForestBillboardPassBegin(_renderer, _spherical, _cutoff) {
    var _shader = _spherical
        ? shd_blade_stage1_billboard_spherical
        : shd_blade_stage1_billboard_cylindrical;
    var _uniforms = _spherical
        ? _renderer.spherical_uniforms
        : _renderer.cylindrical_uniforms;
    shader_set(_shader);
    shader_set_uniform_f(_uniforms.alpha_cutoff, _cutoff);
    if (_uniforms.camera >= 0) {
        shader_set_uniform_f(
            _uniforms.camera,
            _renderer.camera_x,
            _renderer.camera_y,
            _renderer.camera_z
        );
    }
    return _uniforms;
}

/// Submits one authored billboard buffer at one independent world transform.
function BladeStage1ForestBillboardSubmit(
    _buffer, _uniforms, _sprite, _record, _tint = c_white, _alpha = 1,
    _sway = 0, _sway_pivot = -0.5
) {
    if (_buffer < 0 || !sprite_exists(_sprite)) return false;
    shader_set_uniform_f(_uniforms.size, _record.width, _record.height);
    shader_set_uniform_f(
        _uniforms.tint,
        color_get_red(_tint) / 255,
        color_get_green(_tint) / 255,
        color_get_blue(_tint) / 255,
        _alpha
    );
    if (_uniforms.sway >= 0) {
        shader_set_uniform_f(_uniforms.sway, _sway);
        shader_set_uniform_f(_uniforms.sway_pivot, _sway_pivot);
    }
    matrix_set(
        matrix_world,
        matrix_build(_record.x, _record.y, _record.z, 0, 0, 0, 1, 1, 1)
    );
    vertex_submit(
        _buffer,
        pr_trianglelist,
        sprite_get_texture(_sprite, 0)
    );
    return true;
}

/// Returns the authored buffer owned by one foliage placement kind.
function BladeStage1ForestFoliageBuffer(_renderer, _kind) {
    switch (_kind) {
        case BladeStage1ForestFoliageKind.Vines:
            return _renderer.vines_billboard_buffer;
        case BladeStage1ForestFoliageKind.Bush:
            return _renderer.bush_billboard_buffer;
        default:
            return _renderer.grass_billboard_buffer;
    }
}

/// Returns the texture owned by one foliage placement kind.
function BladeStage1ForestFoliageSprite(_renderer, _kind) {
    switch (_kind) {
        case BladeStage1ForestFoliageKind.Vines:
            return _renderer.vines_sprite;
        case BladeStage1ForestFoliageKind.Bush:
            return _renderer.bush_sprite;
        default:
            return _renderer.grass_sprite;
    }
}

/// Converts one floating-point light color to a GameMaker billboard tint.
function BladeStage1ForestBallLightTint(_record) {
    return make_color_rgb(
        round(_record.red * 255),
        round(_record.green * 255),
        round(_record.blue * 255)
    );
}

/// Draws the lit modular forest, then its independent billboard prop passes.
function BladeStage1ForestDraw(_renderer) {
    draw_clear(make_color_rgb(104, 113, 158));
    draw_clear_depth(1);
    if (!_renderer.assets_ready) return;

    var _old_world = matrix_get(matrix_world);
    var _old_view = matrix_get(matrix_view);
    var _old_projection = matrix_get(matrix_projection);
    matrix_set(
        matrix_view,
        matrix_build_lookat(
            _renderer.camera_x,
            _renderer.camera_y,
            _renderer.camera_z,
            _renderer.look_x,
            _renderer.look_y,
            _renderer.look_z,
            0,
            0,
            -1
        )
    );
    matrix_set(
        matrix_projection,
        matrix_build_projection_perspective_fov(
            52,
            room_width / room_height,
            0.25,
            320
        )
    );
    _renderer.nearest_light_arrays = BladeStage1ForestNearestLightArrays(_renderer);

    gpu_push_state();
    gpu_set_cullmode(cull_noculling);
    gpu_set_texfilter(false);
    gpu_set_texrepeat(false);

    // The sky is a standalone camera-centered model and never writes depth.
    gpu_set_ztestenable(false);
    gpu_set_zwriteenable(false);
    gpu_set_blendenable(false);
    BladeStage1ForestWorldShaderBegin(_renderer, 0, 0);
    BladeStage1ForestModelSubmit(
        _renderer.skybox_buffer,
        _renderer.skybox_sprite,
        _renderer.camera_x,
        _renderer.camera_y,
        _renderer.camera_z,
        0,
        1
    );

    // Terrain owns only ground; trees and the World Tree are reusable models.
    gpu_set_ztestenable(true);
    gpu_set_zwriteenable(true);
    BladeStage1ForestWorldShaderBegin(_renderer, 1, 0.01);
    BladeStage1ForestModelSubmit(
        _renderer.terrain_buffer, _renderer.material_sprite,
        0, 0, 0, 0, 1
    );
    for (var _tree_index = 0;
        _tree_index < array_length(_renderer.tree_placements);
        ++_tree_index) {
        var _tree = _renderer.tree_placements[_tree_index];
        if (abs(_tree.y - _renderer.camera_y) > 95) continue;
        var _buffer = _tree.model_kind == 0
            ? _renderer.tree_a_buffer
            : _renderer.tree_b_buffer;
        BladeStage1ForestModelSubmit(
            _buffer, _renderer.material_sprite,
            _tree.x, _tree.y, _tree.z, _tree.rotation, _tree.scale
        );
    }
    BladeStage1ForestModelSubmit(
        _renderer.world_tree_buffer,
        _renderer.material_sprite,
        BladeStage1ForestRouteCenter(248),
        248,
        BladeStage1ForestSurfaceZ(BladeStage1ForestRouteCenter(248), 248),
        0,
        1
    );

    // Each foliage kind reuses its own authored buffer with a rooted sway.
    gpu_set_zwriteenable(false);
    gpu_set_blendenable(true);
    gpu_set_blendmode(bm_normal);
    var _cylindrical = BladeStage1ForestBillboardPassBegin(
        _renderer, false, 0.04
    );
    for (var _foliage_index = 0;
        _foliage_index < array_length(_renderer.foliage_placements);
        ++_foliage_index) {
        var _foliage = _renderer.foliage_placements[_foliage_index];
        if (abs(_foliage.y - _renderer.camera_y) > 85) continue;
        BladeStage1ForestBillboardSubmit(
            BladeStage1ForestFoliageBuffer(_renderer, _foliage.kind),
            _cylindrical,
            BladeStage1ForestFoliageSprite(_renderer, _foliage.kind),
            _foliage,
            _foliage.tint,
            1,
            _foliage.sway,
            _foliage.sway_pivot
        );
    }

    // Fae follow small world paths and remain true spherical billboards.
    var _spherical = BladeStage1ForestBillboardPassBegin(_renderer, true, 0.025);
    for (var _fae_index = 0;
        _fae_index < array_length(_renderer.fae_placements);
        ++_fae_index) {
        var _fae = _renderer.fae_placements[_fae_index];
        if (abs(_fae.y - _renderer.camera_y) > 80) continue;
        BladeStage1ForestBillboardSubmit(
            _renderer.fae_billboard_buffer,
            _spherical,
            _renderer.fae_sprite,
            _fae,
            make_color_rgb(154, 255, 178)
        );
    }

    // Every fae trail light is an individual additive billboard on the fae path.
    gpu_set_blendmode(bm_add);
    _spherical = BladeStage1ForestBillboardPassBegin(_renderer, true, 0.01);
    for (var _trail_index = 0;
        _trail_index < array_length(_renderer.fae_trail_placements);
        ++_trail_index) {
        var _trail = _renderer.fae_trail_placements[_trail_index];
        if (abs(_trail.y - _renderer.camera_y) > 80) continue;
        BladeStage1ForestBillboardSubmit(
            _renderer.ball_light_billboard_buffer,
            _spherical,
            _renderer.ball_light_sprite,
            _trail,
            make_color_rgb(112, 255, 164),
            _trail.alpha
        );
    }

    // Colored ball lights keep their own routes and illumination records.
    for (var _ball_index = 0;
        _ball_index < array_length(_renderer.ball_light_placements);
        ++_ball_index) {
        var _ball = _renderer.ball_light_placements[_ball_index];
        if (abs(_ball.y - _renderer.camera_y) > 80) continue;
        BladeStage1ForestBillboardSubmit(
            _renderer.ball_light_billboard_buffer,
            _spherical,
            _renderer.ball_light_sprite,
            _ball,
            BladeStage1ForestBallLightTint(_ball),
            0.92
        );
    }

    shader_reset();
    gpu_pop_state();
    matrix_set(matrix_world, _old_world);
    matrix_set(matrix_view, _old_view);
    matrix_set(matrix_projection, _old_projection);
}

/// Releases every dynamic sprite, format, and buffer owned by this renderer.
function BladeStage1ForestAssetsDestroy(_renderer) {
    var _buffer_fields = [
        "terrain_buffer", "tree_a_buffer", "tree_b_buffer",
        "world_tree_buffer", "skybox_buffer",
        "grass_billboard_buffer", "vines_billboard_buffer",
        "bush_billboard_buffer", "fae_billboard_buffer",
        "ball_light_billboard_buffer",
    ];
    for (var _buffer_index = 0;
        _buffer_index < array_length(_buffer_fields);
        ++_buffer_index) {
        var _buffer_field = _buffer_fields[_buffer_index];
        if (!variable_instance_exists(_renderer, _buffer_field)) continue;
        var _buffer = variable_instance_get(_renderer, _buffer_field);
        if (_buffer >= 0) vertex_delete_buffer(_buffer);
        variable_instance_set(_renderer, _buffer_field, -1);
    }

    var _format_fields = ["world_format"];
    for (var _format_index = 0;
        _format_index < array_length(_format_fields);
        ++_format_index) {
        var _format_field = _format_fields[_format_index];
        if (!variable_instance_exists(_renderer, _format_field)) continue;
        var _format = variable_instance_get(_renderer, _format_field);
        if (_format >= 0) vertex_format_delete(_format);
        variable_instance_set(_renderer, _format_field, -1);
    }

    var _sprite_fields = [
        "material_sprite", "skybox_sprite", "fae_sprite",
        "grass_sprite", "vines_sprite", "bush_sprite", "ball_light_sprite",
        "maynii_sprite", "kolar_sprite", "ciela_sprite",
        "ciela_wave_sprite", "maynii_leaf_sprite", "kolar_crystal_sprite",
        "asahi_sprite", "asahi_sunfire_sprite", "asahi_hud_frame_sprite",
    ];
    for (var _sprite_index = 0;
        _sprite_index < array_length(_sprite_fields);
        ++_sprite_index) {
        var _sprite_field = _sprite_fields[_sprite_index];
        if (!variable_instance_exists(_renderer, _sprite_field)) continue;
        var _sprite = variable_instance_get(_renderer, _sprite_field);
        if (sprite_exists(_sprite)) sprite_delete(_sprite);
        variable_instance_set(_renderer, _sprite_field, -1);
    }
}
