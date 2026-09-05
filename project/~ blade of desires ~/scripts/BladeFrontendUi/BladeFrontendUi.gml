#macro BLADE_FRONTEND_UI_ASSET_PATH "ui/blade_frontend_panels.png"
#macro BLADE_FRONTEND_UI_FRAME_COUNT 2
#macro BLADE_FRONTEND_UI_FRAME_WIDTH 128
#macro BLADE_FRONTEND_UI_FRAME_HEIGHT 128
#macro BLADE_FRONTEND_UI_GUIDE_LEFT 24
#macro BLADE_FRONTEND_UI_GUIDE_RIGHT 24
#macro BLADE_FRONTEND_UI_GUIDE_TOP 24
#macro BLADE_FRONTEND_UI_GUIDE_BOTTOM 24

/// Returns one packaged front-end UI asset path without owning project packaging.
function _BladeFrontendUiIncludedPath(_relative_path) {
    var _candidates = [
        program_directory + _relative_path,
        program_directory + "datafiles/" + _relative_path,
        working_directory + _relative_path,
        working_directory + "datafiles/" + _relative_path,
    ];
    for (var _index = 0; _index < array_length(_candidates); ++_index) {
        if (file_exists(_candidates[_index])) return _candidates[_index];
    }
    return "";
}

/// Returns the fixed source dimensions and guides shared by every UI panel.
function BladeFrontendUiNineSliceContract() {
    return {
        frame_count: BLADE_FRONTEND_UI_FRAME_COUNT,
        frame_width: BLADE_FRONTEND_UI_FRAME_WIDTH,
        frame_height: BLADE_FRONTEND_UI_FRAME_HEIGHT,
        guide_left: BLADE_FRONTEND_UI_GUIDE_LEFT,
        guide_right: BLADE_FRONTEND_UI_GUIDE_RIGHT,
        guide_top: BLADE_FRONTEND_UI_GUIDE_TOP,
        guide_bottom: BLADE_FRONTEND_UI_GUIDE_BOTTOM,
    };
}

/// Creates a runtime sprite with fixed guides so corners remain unscaled.
function BladeFrontendUiCreate() {
    var _ui = {
        ready: false,
        sprite: -1,
        base_frame: 0,
        selected_frame: 1,
        error: "",
    };
    var _path = _BladeFrontendUiIncludedPath(BLADE_FRONTEND_UI_ASSET_PATH);
    if (_path == "") {
        _ui.error = "missing packaged front-end UI asset";
        return _ui;
    }

    var _sprite = sprite_add(
        _path,
        BLADE_FRONTEND_UI_FRAME_COUNT,
        false,
        false,
        0,
        0
    );
    if (!sprite_exists(_sprite)) {
        _ui.error = "front-end UI asset could not be loaded";
        return _ui;
    }

    var _nineslice = sprite_nineslice_create();
    _nineslice.enabled = true;
    _nineslice.left = BLADE_FRONTEND_UI_GUIDE_LEFT;
    _nineslice.right = BLADE_FRONTEND_UI_GUIDE_RIGHT;
    _nineslice.top = BLADE_FRONTEND_UI_GUIDE_TOP;
    _nineslice.bottom = BLADE_FRONTEND_UI_GUIDE_BOTTOM;
    sprite_set_nineslice(_sprite, _nineslice);

    _ui.ready = true;
    _ui.sprite = _sprite;
    return _ui;
}

/// Releases one screen's dynamic UI sprite before its room is destroyed.
function BladeFrontendUiDestroy(_ui) {
    if (!is_struct(_ui)
        || !variable_struct_exists(_ui, "sprite")
        || !sprite_exists(_ui.sprite)) {
        return;
    }
    sprite_delete(_ui.sprite);
    _ui.sprite = -1;
    _ui.ready = false;
}

/// Draws one source region into a destination region with independent scaling.
function _BladeFrontendUiDrawPart(
    _ui,
    _frame,
    _source_x,
    _source_y,
    _source_width,
    _source_height,
    _destination_x,
    _destination_y,
    _destination_width,
    _destination_height,
    _alpha
) {
    if (_destination_width <= 0 || _destination_height <= 0) return;
    draw_sprite_part_ext(
        _ui.sprite,
        _frame,
        _source_x,
        _source_y,
        _source_width,
        _source_height,
        _destination_x,
        _destination_y,
        _destination_width / _source_width,
        _destination_height / _source_height,
        c_white,
        _alpha
    );
}

/// Draws one reusable base or selected panel with explicit nine-slice regions.
function BladeFrontendUiDrawPanel(
    _ui,
    _frame,
    _x,
    _y,
    _width,
    _height,
    _alpha = 1
) {
    if (is_struct(_ui)
        && variable_struct_exists(_ui, "ready")
        && _ui.ready
        && sprite_exists(_ui.sprite)) {
        // Compress only the ornate borders when a short row cannot fit them.
        var _left = min(BLADE_FRONTEND_UI_GUIDE_LEFT, _width * 0.5);
        var _right = min(BLADE_FRONTEND_UI_GUIDE_RIGHT, _width - _left);
        var _top = min(BLADE_FRONTEND_UI_GUIDE_TOP, _height * 0.5);
        var _bottom = min(BLADE_FRONTEND_UI_GUIDE_BOTTOM, _height - _top);
        var _center_width = max(0, _width - _left - _right);
        var _center_height = max(0, _height - _top - _bottom);
        var _source_center_width = BLADE_FRONTEND_UI_FRAME_WIDTH
            - BLADE_FRONTEND_UI_GUIDE_LEFT
            - BLADE_FRONTEND_UI_GUIDE_RIGHT;
        var _source_center_height = BLADE_FRONTEND_UI_FRAME_HEIGHT
            - BLADE_FRONTEND_UI_GUIDE_TOP
            - BLADE_FRONTEND_UI_GUIDE_BOTTOM;

        _BladeFrontendUiDrawPart(
            _ui, _frame, 0, 0,
            BLADE_FRONTEND_UI_GUIDE_LEFT,
            BLADE_FRONTEND_UI_GUIDE_TOP,
            _x, _y, _left, _top, _alpha
        );
        _BladeFrontendUiDrawPart(
            _ui, _frame,
            BLADE_FRONTEND_UI_GUIDE_LEFT, 0,
            _source_center_width,
            BLADE_FRONTEND_UI_GUIDE_TOP,
            _x + _left, _y, _center_width, _top, _alpha
        );
        _BladeFrontendUiDrawPart(
            _ui, _frame,
            BLADE_FRONTEND_UI_FRAME_WIDTH - BLADE_FRONTEND_UI_GUIDE_RIGHT, 0,
            BLADE_FRONTEND_UI_GUIDE_RIGHT,
            BLADE_FRONTEND_UI_GUIDE_TOP,
            _x + _width - _right, _y, _right, _top, _alpha
        );
        _BladeFrontendUiDrawPart(
            _ui, _frame,
            0, BLADE_FRONTEND_UI_GUIDE_TOP,
            BLADE_FRONTEND_UI_GUIDE_LEFT,
            _source_center_height,
            _x, _y + _top, _left, _center_height, _alpha
        );
        _BladeFrontendUiDrawPart(
            _ui, _frame,
            BLADE_FRONTEND_UI_GUIDE_LEFT,
            BLADE_FRONTEND_UI_GUIDE_TOP,
            _source_center_width,
            _source_center_height,
            _x + _left,
            _y + _top,
            _center_width,
            _center_height,
            _alpha
        );
        _BladeFrontendUiDrawPart(
            _ui, _frame,
            BLADE_FRONTEND_UI_FRAME_WIDTH - BLADE_FRONTEND_UI_GUIDE_RIGHT,
            BLADE_FRONTEND_UI_GUIDE_TOP,
            BLADE_FRONTEND_UI_GUIDE_RIGHT,
            _source_center_height,
            _x + _width - _right,
            _y + _top,
            _right,
            _center_height,
            _alpha
        );
        _BladeFrontendUiDrawPart(
            _ui, _frame, 0,
            BLADE_FRONTEND_UI_FRAME_HEIGHT - BLADE_FRONTEND_UI_GUIDE_BOTTOM,
            BLADE_FRONTEND_UI_GUIDE_LEFT,
            BLADE_FRONTEND_UI_GUIDE_BOTTOM,
            _x,
            _y + _height - _bottom,
            _left,
            _bottom,
            _alpha
        );
        _BladeFrontendUiDrawPart(
            _ui, _frame,
            BLADE_FRONTEND_UI_GUIDE_LEFT,
            BLADE_FRONTEND_UI_FRAME_HEIGHT - BLADE_FRONTEND_UI_GUIDE_BOTTOM,
            _source_center_width,
            BLADE_FRONTEND_UI_GUIDE_BOTTOM,
            _x + _left,
            _y + _height - _bottom,
            _center_width,
            _bottom,
            _alpha
        );
        _BladeFrontendUiDrawPart(
            _ui, _frame,
            BLADE_FRONTEND_UI_FRAME_WIDTH - BLADE_FRONTEND_UI_GUIDE_RIGHT,
            BLADE_FRONTEND_UI_FRAME_HEIGHT - BLADE_FRONTEND_UI_GUIDE_BOTTOM,
            BLADE_FRONTEND_UI_GUIDE_RIGHT,
            BLADE_FRONTEND_UI_GUIDE_BOTTOM,
            _x + _width - _right,
            _y + _height - _bottom,
            _right,
            _bottom,
            _alpha
        );
        return;
    }

    // Keep a legible diagnostic fallback if a packaged asset is unavailable.
    draw_set_color(_frame == 1
        ? make_color_rgb(54, 102, 91)
        : make_color_rgb(21, 48, 51));
    draw_rectangle(_x, _y, _x + _width, _y + _height, true);
    draw_set_color(_frame == 1
        ? make_color_rgb(176, 255, 203)
        : make_color_rgb(72, 114, 108));
    draw_rectangle(_x, _y, _x + _width, _y + _height, false);
}
