/// Draw the title, main menu, options, and binding pages on the 640x360 GUI surface.
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_alpha(1);
draw_set_color(make_color_rgb(8, 19, 25));
draw_rectangle(0, 0, 640, 360, false);

for (var _band = 0; _band < 7; ++_band) {
    var _band_y = 38 + _band * 49;
    draw_set_color(make_color_rgb(12 + _band * 3, 42 + _band * 4, 48));
    draw_rectangle(0, _band_y, 640, _band_y + 22, false);
}

draw_set_color(make_color_rgb(116, 226, 194));
draw_text(32, 20, "BLADE OF DESIRES");
if (frontend_state.page != BladeFrontendPage.Bindings) {
    draw_set_color(make_color_rgb(190, 232, 205));
    draw_text(32, 43, "LOST FOREST OF AUREI");
}

if (frontend_state.page == BladeFrontendPage.Main) {
    var _main_labels = BladeFrontendMainLabels();
    for (var _main_index = 0;
        _main_index < array_length(_main_labels);
        ++_main_index) {
        var _main_y = 112 + _main_index * 42;
        var _main_selected = frontend_state.selected_index == _main_index;
        BladeFrontendUiDrawPanel(
            frontend_ui,
            _main_selected,
            168,
            _main_y,
            304,
            31
        );
        draw_set_color(_main_selected ? c_white : make_color_rgb(174, 196, 190));
        draw_set_halign(fa_center);
        draw_text(320, _main_y + 6, _main_labels[_main_index]);
        draw_set_halign(fa_left);
    }
} else if (frontend_state.page == BladeFrontendPage.Options) {
    draw_set_color(make_color_rgb(214, 242, 228));
    draw_text(32, 70, "OPTIONS");
    var _option_labels = BladeFrontendOptionLabels();
    for (var _option_index = 0;
        _option_index < array_length(_option_labels);
        ++_option_index) {
        var _option_y = 94 + _option_index * 30;
        var _option_selected = frontend_state.selected_index == _option_index;
        BladeFrontendUiDrawPanel(
            frontend_ui,
            _option_selected,
            54,
            _option_y,
            532,
            24
        );
        draw_set_color(_option_selected ? c_white : make_color_rgb(190, 214, 202));
        draw_text(68, _option_y + 4, _option_labels[_option_index]);

        var _option_value = "";
        switch (_option_index) {
            case 0:
                _option_value = frontend_state.config.display.fullscreen
                    ? "ON" : "OFF";
                break;
            case 1:
                _option_value = string(frontend_state.config.display.window_scale) + "X";
                break;
            case 2:
                _option_value = string(frontend_state.config.audio.master_gain_percent) + "%";
                break;
            case 3:
                _option_value = string(frontend_state.config.audio.music_gain_percent) + "%";
                break;
            case 4:
                _option_value = string(frontend_state.config.audio.sfx_gain_percent) + "%";
                break;
            case 5:
                _option_value = "OPEN";
                break;
            case 6:
                _option_value = "RETURN";
                break;
        }
        draw_set_halign(fa_right);
        draw_text(572, _option_y + 4, _option_value);
        draw_set_halign(fa_left);
    }
} else {
    draw_set_color(make_color_rgb(214, 242, 228));
    draw_text(32, 52, "KEYBOARD BINDINGS");
    var _binding_ids = BladeFrontendBindingIds();
    var _binding_count = array_length(_binding_ids);
    var _visible_count = 7;
    var _first_index = clamp(
        frontend_state.selected_index - 3,
        0,
        max(0, _binding_count - _visible_count)
    );
    for (var _visible_index = 0;
        _visible_index < _visible_count
            && _first_index + _visible_index < _binding_count;
        ++_visible_index) {
        var _binding_index = _first_index + _visible_index;
        var _binding_y = 76 + _visible_index * 30;
        var _binding_selected = frontend_state.selected_index == _binding_index;
        BladeFrontendUiDrawPanel(
            frontend_ui,
            _binding_selected,
            42,
            _binding_y,
            556,
            24
        );
        draw_set_color(_binding_selected ? c_white : make_color_rgb(190, 214, 202));
        draw_text(
            56, _binding_y + 4,
            BladeFrontendBindingLabel(_binding_ids[_binding_index])
        );
        draw_set_halign(fa_right);
        draw_text(
            584, _binding_y + 4,
            BladeFrontendKeyboardLabel(variable_struct_get(
                frontend_state.config.bindings.keyboard,
                _binding_ids[_binding_index]
            ))
        );
        draw_set_halign(fa_left);
    }
    if (frontend_state.listening) {
        draw_set_color(make_color_rgb(244, 224, 184));
        draw_set_halign(fa_center);
        draw_text(320, 294, "PRESS A KEY  -  CONFIGURED CANCEL TO BACK OUT");
        draw_set_halign(fa_left);
    }
}

if (frontend_state.message_ticks > 0 && frontend_state.message != "") {
    draw_set_color(make_color_rgb(255, 226, 156));
    draw_set_halign(fa_center);
    draw_text(320, 294, frontend_state.message);
    draw_set_halign(fa_left);
}

draw_set_color(make_color_rgb(238, 226, 170));
draw_text(34, 334, "MOVE: CONFIGURED UP / DOWN");
draw_set_halign(fa_right);
draw_text(606, 334, "CONFIRM / BACK: CONFIGURED");
draw_set_halign(fa_left);
