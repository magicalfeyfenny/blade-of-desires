var _controller = instance_find(o_blade_first_beat_controller, 0);
var _player = BladeStage1PlayerInstance(_controller);
if (_controller == noone || _player == noone
    || !BladeSurvivalGameplayAdvances(_controller)) exit;

var _bounds = BladeCombatPlanePixelBounds(_controller.gameplay_plane);
var _distance = point_distance(x, y, _player.x, _player.y);
var _bottom_y = _bounds.bottom_exclusive - radius - 2;
if (_distance < 86 || y >= _bottom_y) {
    var _direction = point_direction(x, y, _player.x, _player.y);
    x += lengthdir_x(3.6, _direction);
    y += lengthdir_y(3.6, _direction);
} else {
    x += velocity_x;
    y += velocity_y;
    velocity_x *= 0.985;
    velocity_y = min(1.7, velocity_y + 0.018);
}

x = clamp(x, _bounds.left + radius, _bounds.right_exclusive - radius);
y = min(y, _bottom_y);

if (!BladeFirstBeatCirclesOverlap(
    x, y, radius, _player.x, _player.y, _player.body_radius
)) exit;

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
