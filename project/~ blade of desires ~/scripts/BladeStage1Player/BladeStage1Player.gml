/// @description Shared Stage 1 player lifecycle with small ship-specific loadouts.

/// @func BladeStage1PlayerConfigure(player, ship_id, player_kind_id, loadout_id)
/// Binds one child object to stable content after the shared Create event.
function BladeStage1PlayerConfigure(
    _player, _ship_id, _player_kind_id, _loadout_id
) {
    _player.ship_id = _ship_id;
    _player.player_kind_id = _player_kind_id;
    _player.loadout_id = _loadout_id;
    return _player;
}

/// @func BladeStage1PlayerInstance(controller)
/// Returns the controller-owned player, falling back to parent lookup for tests.
function BladeStage1PlayerInstance(_controller) {
    if (_controller != noone
        && variable_instance_exists(_controller, "player_instance")
        && instance_exists(_controller.player_instance)) {
        return _controller.player_instance;
    }
    return instance_find(o_blade_stage1_player, 0);
}

// Creates Ciela's unchanged broad or focus-tightened five-shot volley.
function _BladeStage1PlayerFireCiela(_player, _controller) {
    var _spread = BladeFirstBeatCielaSpread(_player.focused);
    for (var _index = 0; _index < array_length(_spread); ++_index) {
        var _shot = instance_create_layer(
            _player.x, _player.y - 8,
            "Projectiles", o_ciela_first_beat_shot
        );
        _shot.velocity_x = _spread[_index].x;
        _shot.velocity_y = _spread[_index].y;
        _shot.damage = BladeSurvivalPlayerShotDamage(_controller.economy);
        _shot.hyper_tier = _controller.economy.active_hyper_tier;
    }
}

// Creates Maynii's ordered tracking or forward volley from her visible options.
function _BladeStage1PlayerFireMaynii(_player, _controller) {
    var _volley = BladeMayniiVolley(
        _player.focused, _controller.economy.active_hyper_tier
    );
    for (var _index = 0; _index < array_length(_volley); ++_index) {
        var _spec = _volley[_index];
        var _shot = instance_create_layer(
            _player.x + _spec.offset_x,
            _player.y + _spec.offset_y,
            "Projectiles",
            o_maynii_first_beat_shot
        );
        _shot.velocity_x = _spec.velocity_x;
        _shot.velocity_y = _spec.velocity_y;
        _shot.travel_speed = _spec.speed;
        _shot.speed = 0;
        _shot.tracking = _spec.tracking;
        _shot.damage = _spec.damage
            * _controller.economy.shot_strength
            * BladeSurvivalHyperDamageMultiplier(
                _controller.economy.active_hyper_tier
            );
        _shot.hyper_tier = _controller.economy.active_hyper_tier;
    }
}

// Dispatches only the two complete loadouts represented in the selector contract.
function _BladeStage1PlayerFire(_player, _controller) {
    switch (_player.ship_id) {
        case "ship.ciela":
            _BladeStage1PlayerFireCiela(_player, _controller);
            return;
        case "ship.maynii":
            _BladeStage1PlayerFireMaynii(_player, _controller);
            return;
    }
    throw("BladeStage1Player: no firing loadout for " + string(_player.ship_id));
}

/// @func BladeStage1PlayerStep(player)
/// Advances shared movement, fire, hit, graze, and protection behavior once.
function BladeStage1PlayerStep(_player) {
    var _controller = instance_find(o_blade_first_beat_controller, 0);
    if (_controller == noone || !BladeSurvivalGameplayAdvances(_controller)) return;

    var _bindings = _controller.keyboard_bindings;
    var _move_x = keyboard_check(
        variable_struct_get(_bindings, "input.move_right")
    ) - keyboard_check(variable_struct_get(_bindings, "input.move_left"));
    var _move_y = keyboard_check(
        variable_struct_get(_bindings, "input.move_down")
    ) - keyboard_check(variable_struct_get(_bindings, "input.move_up"));
    _player.focused = keyboard_check(
        variable_struct_get(_bindings, "input.focus")
    );
    var _movement = BladeFirstBeatMovePlayer(
        _controller.gameplay_plane,
        _player.x,
        _player.y,
        _move_x,
        _move_y,
        _player.focused,
        _player.body_radius
    );
    _player.x = _movement.x;
    _player.y = _movement.y;

    if (_controller.state == BladeFirstBeatState.Playing) {
        var _fire_held = keyboard_check(
            variable_struct_get(_bindings, "input.fire")
        );
        var _cadence = BladeFirstBeatFireCadence(
            _player.fire_cooldown,
            _fire_held,
            _controller.economy.active_hyper_tier
        );
        _player.fire_cooldown = _cadence.cooldown;
        if (_cadence.fires) {
            _BladeStage1PlayerFire(_player, _controller);
            BladeStage1AudioPlayForController(
                _controller, BladeStage1AudioSfx.PlayerVolley, 0.13
            );
        }
    }

    for (var _bullet_index = instance_number(o_blade_first_beat_enemy_bullet) - 1;
        _bullet_index >= 0; --_bullet_index) {
        var _bullet = instance_find(
            o_blade_first_beat_enemy_bullet, _bullet_index
        );
        if (_bullet == noone) continue;
        if (BladeFirstBeatCirclesOverlap(
            _player.x, _player.y, _player.hit_radius,
            _bullet.x, _bullet.y, _bullet.radius
        )) {
            if (BladeSurvivalBeginPlayerHit(_controller)) {
                with (_bullet) instance_destroy();
                return;
            }
            continue;
        }
        if (BladeFirstBeatCirclesOverlap(
            _player.x, _player.y, _player.graze_radius,
            _bullet.x, _bullet.y, _bullet.radius
        ) && BladeSurvivalTryGrazeBullet(_controller.economy, _bullet)) {
            _controller.feedback_text = "GRAZE +100";
            _controller.feedback_ticks = 45;
        }
    }
}

// Selects the packaged player sprite without using decorative bounds for gameplay.
function _BladeStage1PlayerSprite(_player, _renderer) {
    if (_renderer == noone) return -1;
    if (_player.ship_id == "ship.ciela"
        && variable_instance_exists(_renderer, "ciela_sprite")) {
        return _renderer.ciela_sprite;
    }
    if (_player.ship_id == "ship.maynii"
        && variable_instance_exists(_renderer, "maynii_player_sprite")) {
        return _renderer.maynii_player_sprite;
    }
    return -1;
}

// Draws Maynii's explicit leaf options at the same offsets that emit her shots.
function _BladeStage1PlayerDrawMayniiOptions(_player, _renderer, _alpha) {
    var _options = BladeMayniiOptionFormation(_player.focused);
    var _sprite = -1;
    if (_renderer != noone
        && variable_instance_exists(_renderer, "maynii_option_sprite")) {
        _sprite = _renderer.maynii_option_sprite;
    }
    for (var _index = 0; _index < array_length(_options); ++_index) {
        var _option = _options[_index];
        var _x = _player.x + _option.x;
        var _y = _player.y + _option.y;
        if (sprite_exists(_sprite)) {
            draw_sprite_ext(
                _sprite, 0, _x, _y, 0.72, 0.72,
                _player.focused ? 0 : (_index == 0 ? -18 : 18),
                c_white, _alpha
            );
        } else {
            draw_set_alpha(_alpha);
            draw_set_color(make_color_rgb(182, 244, 116));
            draw_triangle(_x, _y - 4, _x - 4, _y + 4, _x + 4, _y + 3, false);
        }
    }
}

/// @func BladeStage1PlayerDraw(player)
/// Draws ship art, options, focus geometry, and shared protection feedback.
function BladeStage1PlayerDraw(_player) {
    var _controller = instance_find(o_blade_first_beat_controller, 0);
    var _renderer = instance_find(o_blade_stage1_forest_renderer, 0);
    var _hyper_tier = _controller == noone
        ? 0
        : _controller.economy.active_hyper_tier;
    var _protected = _controller != noone
        && (_controller.invulnerable_ticks > 0
            || _controller.economy.bomb_ticks > 0);
    var _ship_alpha = 1;
    if (_controller != noone
        && _controller.player_phase == BladeSurvivalPlayerPhase.Respawning) {
        _ship_alpha = 0.35;
    } else if (_protected
        && ((_controller.invulnerable_ticks div 4) mod 2) == 0) {
        _ship_alpha = 0.55;
    }

    if (_player.ship_id == "ship.maynii") {
        _BladeStage1PlayerDrawMayniiOptions(_player, _renderer, _ship_alpha);
    }
    var _sprite = _BladeStage1PlayerSprite(_player, _renderer);
    if (sprite_exists(_sprite)) {
        draw_sprite_ext(
            _sprite, 0, _player.x, _player.y, 1, 1, 0,
            _hyper_tier > 0 ? make_color_rgb(255, 194, 255) : c_white,
            _ship_alpha
        );
    } else {
        draw_set_alpha(_ship_alpha);
        draw_set_color(_player.ship_id == "ship.maynii"
            ? make_color_rgb(142, 226, 98)
            : make_color_rgb(108, 224, 255));
        draw_triangle(
            _player.x, _player.y - 9,
            _player.x - 7, _player.y + 7,
            _player.x + 7, _player.y + 7,
            false
        );
        draw_set_color(c_white);
        draw_circle(_player.x, _player.y - 1, 2, false);
    }

    if (_player.focused) {
        draw_set_color(make_color_rgb(255, 245, 160));
        draw_circle(_player.x, _player.y, _player.hit_radius, false);
        draw_set_color(_player.ship_id == "ship.maynii"
            ? make_color_rgb(162, 238, 108)
            : make_color_rgb(108, 224, 255));
        draw_circle(_player.x, _player.y, _player.body_radius + 3, true);
    }
    if (_controller != noone && _controller.economy.bomb_ticks > 0) {
        draw_set_color(make_color_rgb(255, 230, 126));
        draw_circle(
            _player.x, _player.y,
            20 + (_controller.economy.bomb_ticks mod 18), true
        );
    }
    if (_hyper_tier > 0) {
        draw_set_color(make_color_rgb(255, 126, 236));
        draw_circle(_player.x, _player.y, 12 + _hyper_tier * 3, true);
    }
    draw_set_alpha(1);
}

/// @func BladeStage1PlayerFeedback(player)
/// Returns ship-specific death feedback without changing shared lifecycle rules.
function BladeStage1PlayerFeedback(_player) {
    if (_player.ship_id == "ship.maynii") {
        return {
            kind: BLADE_STAGE1_EFFECT_MAYNII,
            color: make_color_rgb(132, 238, 104),
        };
    }
    return {
        kind: BLADE_STAGE1_EFFECT_CIELA,
        color: make_color_rgb(98, 232, 255),
    };
}
