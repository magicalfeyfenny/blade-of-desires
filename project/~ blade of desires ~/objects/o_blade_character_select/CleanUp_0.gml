/// Release only the dynamic preview sprites owned by this screen.
for (var _index = 0; _index < array_length(preview_sprites); ++_index) {
    if (sprite_exists(preview_sprites[_index])) {
        sprite_delete(preview_sprites[_index]);
    }
}
preview_sprites = [];
BladeFrontendUiDestroy(frontend_ui);
