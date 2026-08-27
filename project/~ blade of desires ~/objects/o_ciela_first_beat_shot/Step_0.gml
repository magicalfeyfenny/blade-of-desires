x += velocity_x;
y += velocity_y;
if (!BladeFirstBeatPointInsidePlane(x, y)) {
    instance_destroy();
    exit;
}

var _target = instance_nearest(x, y, o_blade_first_beat_enemy);
if (_target == noone || !BladeFirstBeatCirclesOverlap(
    x, y, radius, _target.x, _target.y, _target.hit_radius
)) exit;

var _result = BladeFirstBeatDamageResult(_target.hit_points, damage);
_target.hit_points = _result.remaining;
_target.hit_flash = 4;
if (_result.defeated) {
    var _controller = instance_find(o_blade_first_beat_controller, 0);
    if (_controller != noone) {
        _controller.state = BladeFirstBeatTransition(
            _controller.state, BladeFirstBeatEvent.EnemyDefeated
        );
    }
    with (o_blade_first_beat_enemy_bullet) instance_destroy();
    with (_target) instance_destroy();
}
instance_destroy();
