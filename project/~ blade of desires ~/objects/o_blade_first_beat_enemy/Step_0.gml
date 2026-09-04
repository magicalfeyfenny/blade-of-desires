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

BladeStage1EnemyAdvanceMotion(id);

var _hyper_tier = _controller.economy.active_hyper_tier;
var _difficulty_id = BladeSurvivalEconomyDifficulty(_controller.economy);
var _rank = BladeSurvivalEconomyRank(_controller.economy);
fire_cooldown = max(
    0,
    fire_cooldown - BladeDifficultyHostileFireRate(
        _difficulty_id, _rank, _hyper_tier
    )
);
if (_controller.bomb_clears_this_frame
    || fire_cooldown > 0
    || !BladeCombatPlaneContainsPixelCircle(
    _controller.gameplay_plane, x, y, hit_radius
)) exit;

var _player = BladeStage1PlayerInstance(_controller);
if (_player == noone) exit;
var _aim = point_direction(x, y, _player.x, _player.y);
var _directions = BladeStage1EnemyFireDirections(
    id, _aim, _difficulty_id, _rank, _hyper_tier
);
var _emitted_count = 0;
for (var _index = 0; _index < array_length(_directions); ++_index) {
    var _emission_x = x;
    var _emission_y = y + hit_radius;
    // Gate each concrete emission, not just the decorative sprite center.
    if (!BladeStage1EnemyEmissionAllowed(
        _controller.gameplay_plane,
        _emission_x,
        _emission_y,
        projectile_radius
    )) continue;
    var _direction = _directions[_index];
    var _bullet = instance_create_layer(
        _emission_x, _emission_y,
        "Projectiles", o_blade_first_beat_enemy_bullet
    );
    var _shot_speed = BladeDifficultyHostileBulletSpeed(
        bullet_speed, _difficulty_id, _rank, _hyper_tier
    );
    _bullet.velocity_x = lengthdir_x(_shot_speed, _direction);
    _bullet.velocity_y = lengthdir_y(_shot_speed, _direction);
    _bullet.owner_stage_instance_id = stage_instance_id;
    _bullet.bullet_kind = bullet_kind;
    _bullet.role_id = role_id;
    _bullet.radius = projectile_radius;
    _bullet.outer_color = body_color;
    _bullet.inner_color = accent_color;
    _emitted_count += 1;
}
if (_emitted_count > 0) {
    BladeStage1AudioPlayForController(
        _controller, BladeStage1AudioSfx.EnemyVolley, 0.12
    );
    fire_cooldown = BladeDifficultyHostileFireInterval(
        fire_repeat_ticks, _difficulty_id, _rank, _hyper_tier
    );
    pattern_phase += 1;
}
