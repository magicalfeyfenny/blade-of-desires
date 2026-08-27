if (hit_flash > 0) {
    hit_flash -= 1;
}
var _controller = instance_find(o_blade_first_beat_controller, 0);
if (_controller == noone || _controller.state != BladeFirstBeatState.Playing) exit;

if (y < target_y) {
    y = min(target_y, y + 1.25);
    exit;
}

if (tell_ticks > 0) {
    tell_ticks -= 1;
    exit;
}

x += travel_speed_x;
if (x <= 230 || x >= 410) {
    x = clamp(x, 230, 410);
    travel_speed_x = -travel_speed_x;
}

fire_cooldown = max(0, fire_cooldown - 1);
if (fire_cooldown > 0 || !BladeFirstBeatHurtboxCanFire(x, y, hit_radius)) exit;

var _player = instance_find(o_ciela_first_beat_player, 0);
if (_player == noone) exit;
var _aim = point_direction(x, y, _player.x, _player.y);
var _offsets = [-12, 0, 12];
for (var _index = 0; _index < array_length(_offsets); ++_index) {
    var _direction = _aim + _offsets[_index];
    var _bullet = instance_create_layer(
        x, y + hit_radius, "Projectiles", o_blade_first_beat_enemy_bullet
    );
    _bullet.velocity_x = lengthdir_x(2.7, _direction);
    _bullet.velocity_y = lengthdir_y(2.7, _direction);
}
fire_cooldown = 52;
