/// Load one validated selector catalog and its representative runtime sprites.
catalog = undefined;
selector_state = undefined;
preview_sprites = [];
error_text = "";
keyboard_bindings = BladeConfigCreateDefault().bindings.keyboard;
if (variable_global_exists("blade_config_service")) {
    keyboard_bindings = BladeConfigServiceSnapshot(
        global.blade_config_service
    ).bindings.keyboard;
}

try {
    catalog = BladeShipSelectionLoad();
    selector_state = BladeShipSelectionStateCreate(catalog);
    for (var _index = 0; _index < array_length(catalog.entries); ++_index) {
        var _sprite = BladeStage1ForestTextureLoad(
            catalog.entries[_index].selector_sprite
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
