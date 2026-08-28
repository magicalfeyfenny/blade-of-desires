/// Creates the compact position, colour, and texture layout used by Stage 1 scenery.
function BladeStage1ForestVertexFormatCreate() {
    vertex_format_begin();
    vertex_format_add_position_3d();
    vertex_format_add_colour();
    vertex_format_add_texcoord();
    return vertex_format_end();
}

/// Finds one packaged Stage 1 asset without making the renderer own packaging rules.
function BladeStage1ForestIncludedPath(_relative_path) {
    var _candidates = [
        program_directory + _relative_path,
        program_directory + "datafiles/" + _relative_path,
        working_directory + _relative_path,
    ];
    for (var _index = 0; _index < array_length(_candidates); _index += 1) {
        if (file_exists(_candidates[_index])) return _candidates[_index];
    }
    return "";
}

/// Loads one frozen offline-authored mesh and rejects incomplete triangles.
function BladeStage1ForestBufferLoad(_relative_path, _format) {
    var _path = BladeStage1ForestIncludedPath(_relative_path);
    if (_path == "") {
        show_debug_message("Missing Stage 1 model: " + _relative_path);
        return -1;
    }

    var _data = buffer_load(_path);
    var _byte_count = buffer_get_size(_data);
    // Three 24-byte vertices form every triangle in the governed VBUFF export.
    if (_byte_count <= 0 || _byte_count mod 72 != 0) {
        buffer_delete(_data);
        show_debug_message("Invalid Stage 1 model: " + _relative_path);
        return -1;
    }

    var _vertex_buffer = vertex_create_buffer_from_buffer(_data, _format);
    buffer_delete(_data);
    vertex_freeze(_vertex_buffer);
    return _vertex_buffer;
}

/// Loads one full-image billboard or material texture owned by this renderer.
function BladeStage1ForestTextureLoad(_relative_path) {
    var _path = BladeStage1ForestIncludedPath(_relative_path);
    if (_path == "") {
        show_debug_message("Missing Stage 1 texture: " + _relative_path);
        return -1;
    }
    return sprite_add(_path, 1, false, false, 0, 0);
}

/// Adds one position, colour, and texture coordinate to a billboard mesh.
function BladeStage1ForestBillboardVertex(_buffer, _x, _z, _u, _v) {
    vertex_position_3d(_buffer, _x, 0, _z);
    vertex_colour(_buffer, c_white, 1);
    vertex_texcoord(_buffer, _u, _v);
}

/// Builds the one reusable camera-facing quad shared by the fae and every light.
function BladeStage1ForestBillboardBufferCreate(_format) {
    var _buffer = vertex_create_buffer();
    vertex_begin(_buffer, _format);
    BladeStage1ForestBillboardVertex(_buffer, -0.5, -0.5, 0, 0);
    BladeStage1ForestBillboardVertex(_buffer, 0.5, -0.5, 1, 0);
    BladeStage1ForestBillboardVertex(_buffer, 0.5, 0.5, 1, 1);
    BladeStage1ForestBillboardVertex(_buffer, -0.5, -0.5, 0, 0);
    BladeStage1ForestBillboardVertex(_buffer, 0.5, 0.5, 1, 1);
    BladeStage1ForestBillboardVertex(_buffer, -0.5, 0.5, 0, 1);
    vertex_end(_buffer);
    vertex_freeze(_buffer);
    return _buffer;
}

#macro BLADE_STAGE1_FOREST_FIRST_HALF_CAP 86
#macro BLADE_STAGE1_FOREST_SECOND_HALF_CAP 176
#macro BLADE_STAGE1_WORLD_TREE_TRAVEL_TICKS 180

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
    }
    return false;
}

/// Advances the presentation-only route camera and records one fae trail sample.
function BladeStage1ForestPresentationStep(_renderer) {
    if (_renderer.route_scroll_enabled) {
        _renderer.route_progress = min(
            _renderer.route_progress + _renderer.route_scroll_speed,
            _renderer.route_progress_cap
        );
    }

    _renderer.fae_time += 1;
    _renderer.camera_y = -18 + _renderer.route_progress;
    _renderer.look_y = _renderer.camera_y + 24;

    var _fae_x = dsin(_renderer.fae_time * 2.1) * 2.4;
    var _fae_y = _renderer.camera_y + 21;
    var _fae_z = -4.8 + dsin(_renderer.fae_time * 3.4) * 0.55;
    for (
        var _history_index = _renderer.fae_history_length - 1;
        _history_index > 0;
        _history_index -= 1
    ) {
        _renderer.fae_history_x[_history_index]
            = _renderer.fae_history_x[_history_index - 1];
        _renderer.fae_history_y[_history_index]
            = _renderer.fae_history_y[_history_index - 1];
        _renderer.fae_history_z[_history_index]
            = _renderer.fae_history_z[_history_index - 1];
    }
    _renderer.fae_history_x[0] = _fae_x;
    _renderer.fae_history_y[0] = _fae_y;
    _renderer.fae_history_z[0] = _fae_z;
}

/// Submits one independent billboard record toward the shared perspective camera.
function BladeStage1ForestBillboardDraw(
    _renderer,
    _sprite,
    _x,
    _y,
    _z,
    _scale
) {
    if (!sprite_exists(_sprite)) return;
    var _camera_direction = point_direction(
        _x,
        _y,
        _renderer.camera_x,
        _renderer.camera_y
    );
    // The authored quad faces -Y before rotation, which is 270 degrees in XY.
    var _facing = _camera_direction - 270;
    matrix_set(
        matrix_world,
        matrix_build(_x, _y, _z, 0, 0, _facing, _scale, _scale, _scale)
    );
    vertex_submit(
        _renderer.billboard_buffer,
        pr_trianglelist,
        sprite_get_texture(_sprite, 0)
    );
}

/// Draws the full Stage 1 perspective pass, then restores normal 2D rendering.
function BladeStage1ForestDraw(_renderer) {
    draw_clear(make_color_rgb(4, 13, 16));
    draw_clear_depth(1);
    if (!_renderer.assets_ready) return;

    var _old_world = matrix_get(matrix_world);
    var _old_view = matrix_get(matrix_view);
    var _old_projection = matrix_get(matrix_projection);
    matrix_set(matrix_world, matrix_build_identity());
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

    gpu_push_state();
    gpu_set_ztestenable(true);
    gpu_set_zwriteenable(true);
    gpu_set_cullmode(cull_noculling);
    gpu_set_texfilter(true);
    gpu_set_texrepeat(false);
    gpu_set_blendenable(false);
    vertex_submit(
        _renderer.route_buffer,
        pr_trianglelist,
        sprite_get_texture(_renderer.material_sprite, 0)
    );

    gpu_set_zwriteenable(false);
    gpu_set_blendenable(true);
    gpu_set_blendmode(bm_normal);
    BladeStage1ForestBillboardDraw(
        _renderer,
        _renderer.fae_sprite,
        _renderer.fae_history_x[0],
        _renderer.fae_history_y[0],
        _renderer.fae_history_z[0],
        3.2
    );

    // Each lagged light is a separate billboard using the single-light asset.
    gpu_set_blendmode(bm_add);
    for (
        var _light_index = array_length(_renderer.light_lags) - 1;
        _light_index >= 0;
        _light_index -= 1
    ) {
        var _history_index = _renderer.light_lags[_light_index];
        BladeStage1ForestBillboardDraw(
            _renderer,
            _renderer.light_sprite,
            _renderer.fae_history_x[_history_index],
            _renderer.fae_history_y[_history_index],
            _renderer.fae_history_z[_history_index],
            1.15 - _light_index * 0.08
        );
    }

    gpu_pop_state();
    matrix_set(matrix_world, _old_world);
    matrix_set(matrix_view, _old_view);
    matrix_set(matrix_projection, _old_projection);
}

/// Releases only the dynamic sprites and vertex resources owned by this renderer.
function BladeStage1ForestAssetsDestroy(_renderer) {
    if (_renderer.route_buffer >= 0) {
        vertex_delete_buffer(_renderer.route_buffer);
        _renderer.route_buffer = -1;
    }
    if (_renderer.billboard_buffer >= 0) {
        vertex_delete_buffer(_renderer.billboard_buffer);
        _renderer.billboard_buffer = -1;
    }
    if (_renderer.geometry_format >= 0) {
        vertex_format_delete(_renderer.geometry_format);
        _renderer.geometry_format = -1;
    }
    if (sprite_exists(_renderer.material_sprite)) {
        sprite_delete(_renderer.material_sprite);
        _renderer.material_sprite = -1;
    }
    if (sprite_exists(_renderer.fae_sprite)) {
        sprite_delete(_renderer.fae_sprite);
        _renderer.fae_sprite = -1;
    }
    if (sprite_exists(_renderer.light_sprite)) {
        sprite_delete(_renderer.light_sprite);
        _renderer.light_sprite = -1;
    }
}
