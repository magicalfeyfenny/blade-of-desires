var _controller = instance_find(o_blade_first_beat_controller, 0);
if (_controller == noone || !BladeSurvivalGameplayAdvances(_controller)) exit;

x += velocity_x;
y += velocity_y;
if (!BladeFirstBeatHostileBulletInsideWindow(
    x, y, room_width, room_height
)) {
    instance_destroy();
}
