var _controller = instance_find(o_blade_first_beat_controller, 0);
var _player = BladeStage1PlayerInstance(_controller);
// Rewards keep their own fall/collection lifecycle through response and death.
if (_controller == noone || !BladeSurvivalItemMotionAdvances(_controller)) exit;

var _can_collect = _player != noone
    && BladeSurvivalGameplayAdvances(_controller);
var _hyper_active = _controller.economy.active_hyper_tier > 0;
var _distance = _can_collect
    ? point_distance(x, y, _player.x, _player.y)
    : infinity;
var _vacuum_radius = _can_collect
    ? BladeSurvivalItemVacuumRadius(_player.focused)
    : 0;
if (!_can_collect || (!_hyper_active && _distance > _vacuum_radius)) {
    x += velocity_x;
    y += velocity_y;
    velocity_x *= 0.985;
    velocity_y = min(1.7, velocity_y + 0.018);
} else if (!_hyper_active) {
    var _direction = point_direction(x, y, _player.x, _player.y);
    var _vacuum_speed = BladeSurvivalItemVacuumSpeed(_player.focused);
    x += lengthdir_x(_vacuum_speed, _direction);
    y += lengthdir_y(_vacuum_speed, _direction);
}

if (!BladeCombatPlaneContainsPixelCircle(_controller.gameplay_plane, x, y, radius)) {
    instance_destroy();
    exit;
}

if (!_can_collect || (!_hyper_active && !BladeFirstBeatCirclesOverlap(
    x, y, radius, _player.x, _player.y, _player.body_radius
))) exit;

if (kind == BladeSurvivalItemKind.Bomb) {
    var _bomb = BladeSurvivalCollectBomb(_controller.economy);
    _controller.feedback_text = _bomb.stocked
        ? "BOMB +1"
        : "BOMB MAX  +" + string(_bomb.overflow_score);
} else {
    var _point = BladeSurvivalCollectPointItem(_controller.economy);
    _controller.feedback_text = "POINT +" + string(_point.collected_value);
}
_controller.feedback_ticks = 60;
BladeStage1AudioPlayForController(
    _controller, BladeStage1AudioSfx.Pickup, 0.36
);
instance_destroy();
