var _controller = instance_find(o_blade_first_beat_controller, 0);
if (_controller == noone || !BladeSurvivalGameplayAdvances(_controller)) exit;

var _bindings = _controller.keyboard_bindings;
var _move_x = keyboard_check(
    variable_struct_get(_bindings, "input.move_right")
) - keyboard_check(variable_struct_get(_bindings, "input.move_left"));
var _move_y = keyboard_check(
    variable_struct_get(_bindings, "input.move_down")
) - keyboard_check(variable_struct_get(_bindings, "input.move_up"));
focused = keyboard_check(variable_struct_get(_bindings, "input.focus"));
var _movement = BladeFirstBeatMovePlayer(
    _controller.gameplay_plane,
    x, y, _move_x, _move_y, focused, body_radius
);
x = _movement.x;
y = _movement.y;

if (_controller.state == BladeFirstBeatState.Playing) {
    var _fire_held = keyboard_check(
        variable_struct_get(_bindings, "input.fire")
    );
    var _cadence = BladeFirstBeatFireCadence(
        fire_cooldown, _fire_held, _controller.economy.active_hyper_tier
    );
    fire_cooldown = _cadence.cooldown;
    if (_cadence.fires) {
        var _spread = BladeFirstBeatCielaSpread(focused);
        for (var _index = 0; _index < array_length(_spread); ++_index) {
            var _shot = instance_create_layer(
                x, y - 8, "Projectiles", o_ciela_first_beat_shot
            );
            _shot.velocity_x = _spread[_index].x;
            _shot.velocity_y = _spread[_index].y;
            _shot.damage = BladeSurvivalPlayerShotDamage(_controller.economy);
            _shot.hyper_tier = _controller.economy.active_hyper_tier;
        }
    }
}

for (var _bullet_index = instance_number(o_blade_first_beat_enemy_bullet) - 1;
    _bullet_index >= 0; --_bullet_index) {
    var _bullet = instance_find(
        o_blade_first_beat_enemy_bullet, _bullet_index
    );
    if (_bullet == noone) continue;
    var _hits = BladeFirstBeatCirclesOverlap(
        x, y, hit_radius, _bullet.x, _bullet.y, _bullet.radius
    );
    if (_hits) {
        if (BladeSurvivalBeginPlayerHit(_controller)) {
            with (_bullet) instance_destroy();
            exit;
        }
        continue;
    }
    if (BladeFirstBeatCirclesOverlap(
        x, y, graze_radius, _bullet.x, _bullet.y, _bullet.radius
    ) && BladeSurvivalTryGrazeBullet(_controller.economy, _bullet)) {
        _controller.feedback_text = "GRAZE +100";
        _controller.feedback_ticks = 45;
    }
}
