var _controller = instance_find(o_blade_first_beat_controller, 0);
if (_controller == noone || _controller.state != BladeFirstBeatState.Playing) {
    instance_destroy();
    exit;
}
// Hit response freezes committed shots; death and reset own their cleanup.
if (!BladeSurvivalGameplayAdvances(_controller)) exit;

if (tracking) {
    var _target = BladeMayniiResolveTarget(target_stage_instance_id);
    if (_target == noone) {
        _target = BladeMayniiAcquireTarget(x, y);
        target_stage_instance_id = _target == noone
            ? ""
            : _target.stage_instance_id;
    }
    if (_target == noone) {
        // No target is still useful: the leaf resumes a straight forward shot.
        var _fallback = BladeMayniiForwardFallback(travel_speed);
        velocity_x = _fallback.x;
        velocity_y = _fallback.y;
    } else {
        var _steered = BladeMayniiSteerVelocity(
            velocity_x, velocity_y, x, y, _target.x, _target.y,
            travel_speed, BLADE_MAYNII_TRACKING_TURN_DEGREES
        );
        velocity_x = _steered.x;
        velocity_y = _steered.y;
    }
}

x += velocity_x;
y += velocity_y;
if (!BladeFirstBeatPlayerShotInsideVerticalPlane(
    _controller.gameplay_plane, y
)) {
    instance_destroy();
    exit;
}

var _hit_target = BladeMayniiAcquireTarget(x, y, radius);
if (_hit_target == noone) exit;
BladeFirstBeatApplyPlayerShot(_controller, _hit_target, damage);
instance_destroy();
