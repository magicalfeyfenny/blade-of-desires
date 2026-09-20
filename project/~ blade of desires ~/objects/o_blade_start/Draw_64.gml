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
                _option_value = "OPEN";
                break;
            case 7:
                _option_value = "RETURN";
                break;
        }
        draw_set_halign(fa_right);
        draw_text(572, _option_y + 4, _option_value);
        draw_set_halign(fa_left);
    }
} else if (frontend_state.page == BladeFrontendPage.ReplayCatalog) {
    draw_set_color(make_color_rgb(214, 242, 228));
    draw_text(32, 62, "REPLAY CATALOG");
    var _replay_entries = frontend_state.replay_view.entries;
    if (array_length(_replay_entries) == 0) {
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(190, 214, 202));
        draw_text(320, 150, "NO SAVED REPLAYS");
        draw_text(320, 178, "RECORDINGS APPEAR AFTER A RUN IS SAVED");
        draw_set_halign(fa_left);
    } else {
        var _replay_count = array_length(_replay_entries);
        var _replay_visible_count = 7;
        var _replay_first_index = clamp(
            frontend_state.selected_index - 3,
            0,
            max(0, _replay_count - _replay_visible_count)
        );
        for (var _replay_visible_index = 0;
            _replay_visible_index < _replay_visible_count
                && _replay_first_index + _replay_visible_index < _replay_count;
            ++_replay_visible_index) {
            var _replay_index = _replay_first_index + _replay_visible_index;
            var _replay_entry = _replay_entries[_replay_index];
            var _replay_y = 84 + _replay_visible_index * 31;
            var _replay_selected = frontend_state.selected_index == _replay_index;
            BladeFrontendUiDrawPanel(
                frontend_ui,
                _replay_selected,
                36,
                _replay_y,
                568,
                25
            );
            draw_set_color(
                _replay_selected ? c_white : make_color_rgb(190, 214, 202)
            );
            var _replay_label = _replay_entry.state_token == "playable"
                ? string(_replay_entry.replay_id)
                : string(_replay_entry.file_path);
            draw_text(48, _replay_y + 4, _replay_label);
            draw_set_halign(fa_right);
            draw_text(590, _replay_y + 4, string_upper(_replay_entry.state_token));
            draw_set_halign(fa_left);
        }
        var _selected_replay = _replay_entries[frontend_state.selected_index];
        draw_set_color(make_color_rgb(238, 226, 170));
        draw_text(
            42,
            294,
            _selected_replay.state_token == "playable"
                ? "SEED " + string(_selected_replay.run_seed)
                    + "  " + _selected_replay.ship_id
                    + "  " + _selected_replay.difficulty_id
                    + "  TICKS " + string(_selected_replay.progress_ticks)
                : string(_selected_replay.reason)
        );
        if (_selected_replay.state_token == "playable") {
            draw_text(
                42,
                314,
                "RESULT " + _selected_replay.terminal_result
                    + "  SCORE "
                    + (_selected_replay.has_score
                        ? string(_selected_replay.score)
                        : "UNAVAILABLE")
            );
        }
    }
} else if (frontend_state.page == BladeFrontendPage.ReplayPlayback) {
    draw_set_color(make_color_rgb(214, 242, 228));
    draw_text(32, 62, "REPLAY PLAYBACK");
    if (is_struct(frontend_state.replay_entry)) {
        draw_set_color(make_color_rgb(190, 214, 202));
        draw_text(
            42,
            92,
            string(frontend_state.replay_entry.replay_id)
                + "  " + frontend_state.replay_entry.ship_id
                + "  " + frontend_state.replay_entry.difficulty_id
        );
    }
    var _replay_snapshot = BladeReplayPlaybackSnapshot(
        frontend_state.replay_playback
    );
    draw_set_color(make_color_rgb(238, 226, 170));
    draw_text(
        42,
        126,
        "TICK " + string(_replay_snapshot.next_input_index)
            + " / " + string(_replay_snapshot.input_count)
    );
    draw_text(42, 150, "LIVE INPUT DISABLED");
    draw_set_halign(fa_center);
    draw_text(
        320,
        220,
        frontend_state.replay_completed
            ? "PLAYBACK COMPLETE"
            : "DETERMINISTIC PLAYBACK"
    );
    draw_set_halign(fa_left);
} else {
    draw_set_color(make_color_rgb(214, 242, 228));
    draw_text(
        32,
        52,
        BladeFrontendBindingDeviceLabel(frontend_state.binding_device)
    );
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
            BladeFrontendConfiguredBindingLabel(
                frontend_state.config,
                _binding_ids[_binding_index],
                frontend_state.binding_device
            )
        );
        draw_set_halign(fa_left);
    }
    if (frontend_state.listening) {
        draw_set_color(make_color_rgb(244, 224, 184));
        draw_set_halign(fa_center);
        draw_text(
            320,
            294,
            (frontend_state.binding_device == BladePromptDevice.Gamepad
                ? "PRESS A BUTTON"
                : "PRESS A KEY")
                + "  -  CONFIGURED CANCEL TO BACK OUT"
        );
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
