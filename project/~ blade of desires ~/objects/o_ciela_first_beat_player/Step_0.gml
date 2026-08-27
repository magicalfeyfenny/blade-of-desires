var _controller = instance_find(o_blade_first_beat_controller, 0);
if (_controller == noone || _controller.state != BladeFirstBeatState.Playing) exit;

var _move_x = (keyboard_check(vk_right) || keyboard_check(ord("D")))
    - (keyboard_check(vk_left) || keyboard_check(ord("A")));
var _move_y = (keyboard_check(vk_down) || keyboard_check(ord("S")))
    - (keyboard_check(vk_up) || keyboard_check(ord("W")));
focused = keyboard_check(vk_shift) || keyboard_check(ord("X"));
var _movement = BladeFirstBeatMovePlayer(x, y, _move_x, _move_y, focused);
x = _movement.x;
y = _movement.y;

var _fire_held = keyboard_check(ord("Z")) || keyboard_check(vk_space);
var _cadence = BladeFirstBeatFireCadence(fire_cooldown, _fire_held);
fire_cooldown = _cadence.cooldown;
if (_cadence.fires) {
    var _spread = BladeFirstBeatCielaSpread(focused);
    for (var _index = 0; _index < array_length(_spread); ++_index) {
        var _shot = instance_create_layer(
            x, y - 8, "Projectiles", o_ciela_first_beat_shot
        );
        _shot.velocity_x = _spread[_index].x;
        _shot.velocity_y = _spread[_index].y;
    }
}

var _bullet = instance_nearest(x, y, o_blade_first_beat_enemy_bullet);
if (_bullet != noone && BladeFirstBeatCirclesOverlap(
    x, y, hit_radius, _bullet.x, _bullet.y, _bullet.radius
)) {
    _controller.state = BladeFirstBeatTransition(
        _controller.state, BladeFirstBeatEvent.PlayerHit
    );
    with (o_blade_first_beat_enemy_bullet) instance_destroy();
    with (o_ciela_first_beat_shot) instance_destroy();
}
