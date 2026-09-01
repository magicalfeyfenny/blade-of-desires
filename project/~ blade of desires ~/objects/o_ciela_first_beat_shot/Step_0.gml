var _controller = instance_find(o_blade_first_beat_controller, 0);
if (_controller == noone || _controller.state != BladeFirstBeatState.Playing) {
    instance_destroy();
    exit;
}
// Freeze live shots during hit response; committed death owns their cleanup.
if (!BladeSurvivalGameplayAdvances(_controller)) exit;

x += velocity_x;
y += velocity_y;
if (!BladeFirstBeatPlayerShotInsideVerticalPlane(
    _controller.gameplay_plane, y
)) {
    instance_destroy();
    exit;
}

var _target = BladeFirstBeatNearestTarget(x, y);
if (_target == noone || !BladeFirstBeatCirclesOverlap(
    x, y, radius, _target.x, _target.y, _target.hit_radius
)) exit;

BladeFirstBeatApplyPlayerShot(_controller, _target, damage);
instance_destroy();
