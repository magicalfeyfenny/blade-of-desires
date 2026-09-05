/// Draw every packaged choice inside the native 640x360 logical surface.
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_alpha(1);
draw_set_color(make_color_rgb(8, 19, 25));
draw_rectangle(0, 0, 640, 360, false);

// Layered currents and leaves keep the first menu visually tied to Stage 1.
for (var _band = 0; _band < 7; ++_band) {
    var _band_y = 38 + _band * 49;
    draw_set_color(make_color_rgb(12 + _band * 3, 42 + _band * 4, 48));
    draw_rectangle(0, _band_y, 640, _band_y + 22, false);
}
draw_set_color(make_color_rgb(116, 226, 194));
draw_text(32, 22, "CHOOSE YOUR FAIRY");

if (error_text != "") {
    draw_set_color(make_color_rgb(255, 104, 126));
    draw_text_ext(42, 112, error_text, 18, 552);
    draw_set_color(make_color_rgb(244, 224, 184));
    draw_text(42, 300, "The run cannot start until this content is repaired.");
    exit;
}

draw_set_color(make_color_rgb(214, 242, 228));
var _difficulty = catalog.difficulty_entries[selector_state.selected_difficulty_index];
draw_text(
    32, 43,
    string_upper(_difficulty.display_name) + "  -  LOST FOREST OF AUREI"
);

var _entry_count = array_length(catalog.entries);
var _card_gap = 12;
var _card_margin = 24;
var _card_width = floor(
    (640 - _card_margin * 2 - _card_gap * (_entry_count - 1))
    / _entry_count
);
for (var _index = 0; _index < _entry_count; ++_index) {
    var _entry = catalog.entries[_index];
    var _selected = selector_state.selected_index == _index;
    var _left = _card_margin + _index * (_card_width + _card_gap);
    var _right = _left + _card_width;
    var _center = (_left + _right) * 0.5;
    BladeFrontendUiDrawPanel(
        frontend_ui,
        _selected ? frontend_ui.selected_frame : frontend_ui.base_frame,
        _left,
        82,
        _card_width,
        206
    );

    var _preview = preview_sprites[_index];
    if (sprite_exists(_preview)) {
        draw_sprite_ext(
            _preview, 0, _center, 151,
            _entry_count <= 2 ? 1.35 : 1.05,
            _entry_count <= 2 ? 1.35 : 1.05,
            0, c_white, _selected ? 1 : 0.62
        );
    }
    draw_set_halign(fa_center);
    draw_set_color(_selected ? c_white : make_color_rgb(174, 196, 190));
    draw_text(_center, 94, string_upper(_entry.display_name));
    draw_set_color(_selected
        ? make_color_rgb(188, 246, 172)
        : make_color_rgb(132, 164, 143));
    draw_text(_center, 116, string_upper(_entry.fairy_identity));
    draw_set_halign(fa_left);
    draw_set_color(make_color_rgb(222, 234, 224));
    draw_text_ext(
        _left + 12, 190, _entry.combat_identity, 15, _card_width - 24
    );
    draw_set_color(make_color_rgb(132, 184, 168));
    draw_set_halign(fa_center);
    draw_text(_center, 264, _selected ? "READY  -  CONFIRM" : "AVAILABLE");
    draw_set_halign(fa_left);
}

draw_set_color(make_color_rgb(238, 226, 170));
draw_text(34, 316, "MOVE: CONFIGURED UP / DOWN");
draw_text(34, 334, "DIFFICULTY: CONFIGURED LEFT / RIGHT");
draw_set_halign(fa_right);
draw_text(606, 334, "CONFIRM / BACK: CONFIGURED");
draw_set_halign(fa_left);
