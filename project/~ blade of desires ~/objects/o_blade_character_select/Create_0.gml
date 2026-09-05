/// Load one validated selector catalog and its representative runtime sprites.
catalog = undefined;
selector_state = undefined;
preview_sprites = [];
error_text = "";
frontend_ui = BladeFrontendUiCreate();
input_config = BladeConfigCreateDefault();
if (variable_global_exists("blade_config_service")) {
    input_config = BladeConfigServiceSnapshot(global.blade_config_service);
}

try {
    catalog = BladeShipSelectionLoad();
    selector_state = BladeShipSelectionStateCreate(catalog);
    for (var _index = 0; _index < array_length(catalog.entries); ++_index) {
        var _selector_path = catalog.entries[_index].selector_sprite;
        var _frame_count = _selector_path == "sprites/stage1/kolar_player.png"
            ? 6
            : 1;
        var _sprite = BladeStage1ForestTextureLoad(
            _selector_path, _frame_count
        );
        if (!sprite_exists(_sprite)) {
            throw(
                "missing packaged selector sprite "
                + catalog.entries[_index].selector_sprite
            );
        }
        array_push(preview_sprites, _sprite);
    }
} catch (_caught) {
    error_text = "SHIP CONTENT ERROR\n" + string(_caught);
    show_debug_message(error_text);
}
depth = -1000;
