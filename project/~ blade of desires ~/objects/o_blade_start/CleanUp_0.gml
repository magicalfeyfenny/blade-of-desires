/// Release the dynamic UI sprite owned by the front-end room.
if (variable_instance_exists(id, "frontend_ui")) {
    BladeFrontendUiDestroy(frontend_ui);
}
