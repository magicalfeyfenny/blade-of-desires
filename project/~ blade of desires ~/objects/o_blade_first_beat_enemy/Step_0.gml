if (hit_flash > 0) {
    hit_flash -= 1;
}
var _controller = instance_find(o_blade_first_beat_controller, 0);
if (_controller == noone || _controller.state != BladeFirstBeatState.Playing
    || !BladeSurvivalGameplayAdvances(_controller)) exit;

if (y < target_y) {
    y = min(target_y, y + entry_speed);
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

var _hyper_tier = _controller.economy.active_hyper_tier;
fire_cooldown = max(
    0,
    fire_cooldown - BladeSurvivalHyperHostileFireRate(_hyper_tier)
);
if (_controller.bomb_clears_this_frame
    || fire_cooldown > 0
    || !BladeCombatPlaneContainsPixelCircle(
    _controller.gameplay_plane, x, y, hit_radius
)) exit;

var _player = BladeStage1PlayerInstance(_controller);
if (_player == noone) exit;
var _aim = point_direction(x, y, _player.x, _player.y);
for (var _index = 0; _index < array_length(bullet_offsets); ++_index) {
    var _direction = _aim + bullet_offsets[_index];
    var _bullet = instance_create_layer(
        x, y + hit_radius, "Projectiles", o_blade_first_beat_enemy_bullet
    );
    var _shot_speed = BladeSurvivalHyperHostileBulletSpeed(
        bullet_speed, _hyper_tier
    );
    _bullet.velocity_x = lengthdir_x(_shot_speed, _direction);
    _bullet.velocity_y = lengthdir_y(_shot_speed, _direction);
    _bullet.owner_stage_instance_id = stage_instance_id;
}
BladeStage1AudioPlayForController(
    _controller, BladeStage1AudioSfx.EnemyVolley, 0.12
);
fire_cooldown = fire_repeat_ticks;
