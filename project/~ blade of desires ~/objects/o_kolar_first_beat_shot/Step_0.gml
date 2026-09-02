var _controller = instance_find(o_blade_first_beat_controller, 0);
if (_controller == noone || _controller.state != BladeFirstBeatState.Playing) {
    instance_destroy();
    exit;
}
// Shared pause and hit-response policy freezes live shots before moving them.
if (!BladeSurvivalGameplayAdvances(_controller)) exit;

x += velocity_x;
y += velocity_y;
travel_distance = point_distance(origin_x, origin_y, x, y);
if (channel == "close" && travel_distance >= range_limit) {
    instance_destroy();
    exit;
}
if (!BladeFirstBeatPlayerShotInsideVerticalPlane(
    _controller.gameplay_plane, y
)) {
    instance_destroy();
    exit;
}

var _max_distance = channel == "close" ? range_limit : -1;
var _target = BladeKolarAcquireTarget(x, y, radius, _max_distance);
if (_target == noone) exit;

BladeFirstBeatApplyPlayerShot(_controller, _target, damage);
// Each shot is single-hit; the declared cadence prevents duplicate damage.
instance_destroy();
