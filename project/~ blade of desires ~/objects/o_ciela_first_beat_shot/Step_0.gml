var _controller = instance_find(o_blade_first_beat_controller, 0);
if (_controller == noone || _controller.state != BladeFirstBeatState.Playing) {
    instance_destroy();
    exit;
}
// Freeze live shots during hit response; committed death owns their cleanup.
if (!BladeSurvivalGameplayAdvances(_controller)) exit;

x += velocity_x;
y += velocity_y;
if (!BladeCombatPlaneContainsPixelPoint(_controller.gameplay_plane, x, y)) {
    instance_destroy();
    exit;
}

var _target = BladeFirstBeatNearestTarget(x, y);
if (_target == noone || !BladeFirstBeatCirclesOverlap(
    x, y, radius, _target.x, _target.y, _target.hit_radius
)) exit;

if (_target.target_kind == BladeFirstBeatTargetKind.Stage1FaeMidboss) {
    var _midboss_result = BladeStage1MidbossApplyDamage(
        _controller, _target, damage
    );
    BladeSurvivalAwardEnemyHit(
        _controller.economy, _midboss_result.applied
    );
} else {
    var _result = BladeFirstBeatDamageResult(_target.hit_points, damage);
    _target.hit_points = _result.remaining;
    _target.hit_flash = 4;
    BladeSurvivalAwardEnemyHit(_controller.economy, _result.applied);
    if (_result.defeated) {
        BladeFirstBeatDefeatOrdinaryTarget(_controller, _target);
    }
}
instance_destroy();
