var _controller = instance_find(o_blade_first_beat_controller, 0);
if (_controller == noone || !BladeSurvivalGameplayAdvances(_controller)) exit;

x += velocity_x;
y += velocity_y;
if (!BladeCombatPlaneContainsPixelPoint(_controller.gameplay_plane, x, y)) {
    instance_destroy();
}
