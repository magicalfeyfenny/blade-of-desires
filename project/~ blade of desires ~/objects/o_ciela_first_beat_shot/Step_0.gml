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

var _target = instance_nearest(x, y, o_blade_first_beat_enemy);
if (_target == noone || !BladeFirstBeatCirclesOverlap(
    x, y, radius, _target.x, _target.y, _target.hit_radius
)) exit;

var _result = BladeFirstBeatDamageResult(_target.hit_points, damage);
_target.hit_points = _result.remaining;
_target.hit_flash = 4;
BladeSurvivalAwardEnemyHit(_controller.economy, _result.applied);
if (_result.defeated) {
    var _drop_x = _target.x;
    var _drop_y = _target.y;
    var _drops = BladeSurvivalResolveEnemyExit(
        _controller.economy,
        BladeSurvivalEnemyExitReason.Defeated,
        BladeSurvivalEnemyIsBombCarrier(_target.archetype_id)
    );
    for (var _drop_index = 0;
        _drop_index < _drops.point_item_count; ++_drop_index) {
        var _point = instance_create_layer(
            _drop_x + (_drop_index - 2) * 9,
            _drop_y,
            "Items",
            o_blade_reward_item
        );
        _point.kind = BladeSurvivalItemKind.Point;
        _point.velocity_x = (_drop_index - 2) * 0.24;
        _point.velocity_y = 0.7 + _drop_index * 0.08;
    }
    for (var _bomb_index = 0;
        _bomb_index < _drops.bomb_item_count; ++_bomb_index) {
        var _bomb_item = instance_create_layer(
            _drop_x + (_bomb_index - 1) * 16,
            _drop_y - 10,
            "Items",
            o_blade_reward_item
        );
        _bomb_item.kind = BladeSurvivalItemKind.Bomb;
        _bomb_item.velocity_x = (_bomb_index - 1) * 0.18;
        _bomb_item.velocity_y = 0.45 + _bomb_index * 0.06;
    }
    _controller.state = BladeFirstBeatTransition(
        _controller.state, BladeFirstBeatEvent.EnemyDefeated
    );
    _controller.feedback_text = "CARRIER DOWN\nCOLLECT REWARDS";
    _controller.feedback_ticks = 120;
    _controller.reward_wait_ticks = 30;
    with (o_blade_first_beat_enemy_bullet) instance_destroy();
    with (_target) instance_destroy();
}
instance_destroy();
