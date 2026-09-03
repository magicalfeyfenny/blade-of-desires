/// Direct gameplay rules shared by the first combat room and its focused tests.

enum BladeFirstBeatState {
    Playing = 0,
    Rewarding = 1,
    Won = 2,
    Failed = 3
}

enum BladeFirstBeatEvent {
    EnemyDefeated = 1,
    RewardsCollected = 2,
    PlayerOutOfLives = 3,
    Retry = 4
}

enum BladeFirstBeatTargetKind {
    Ordinary = 1,
    Stage1FaeMidboss = 2,
    Stage1Asahi = 3
}

enum BladeFirstBeatBulletKind {
    Ordinary = 1,
    MayniiLeaf = 2,
    KolarCrystal = 3,
    CielaCurrent = 4,
    ComboLeaf = 5,
    ComboCrystal = 6,
    ComboRiver = 7,
    ComboRiverCrystal = 8,
    AsahiFlame = 9,
    AsahiCrown = 10,
    ComboRiverRoots = 11,
    ComboLeafRoots = 12,
    PopcornSeed = 13,
    ScoutPetal = 14,
    EliteMoon = 15,
    CommanderCrown = 16
}

#macro BLADE_FIRST_BEAT_PRODUCT_CONTRACT_PATH "content/product_contract.json"

/// Reads one bundled text file completely and always closes its GameMaker handle.
function _BladeFirstBeatReadBundledText(_path) {
    var _resolved_path = _path;
    if (!file_exists(_resolved_path)
        && file_exists(working_directory + _resolved_path)) {
        _resolved_path = working_directory + _resolved_path;
    }
    if (!file_exists(_resolved_path)) {
        throw("BladeFirstCombatBeat: bundled file does not exist: " + _path);
    }

    var _file = -1;
    try {
        _file = file_text_open_read(_resolved_path);
        if (_file < 0) {
            throw("BladeFirstCombatBeat: bundled file could not be opened: " + _path);
        }
        var _text = "";
        var _first_line = true;
        while (!file_text_eof(_file)) {
            if (!_first_line) _text += "\n";
            _text += file_text_read_string(_file);
            file_text_readln(_file);
            _first_line = false;
        }
        return _text;
    } finally {
        if (_file >= 0) file_text_close(_file);
    }
}

/// Loads the playable room's plane from the bundled canonical product contract.
function BladeFirstBeatLoadGameplayPlane(
    _path = BLADE_FIRST_BEAT_PRODUCT_CONTRACT_PATH
) {
    var _contract;
    try {
        _contract = json_parse(
            _BladeFirstBeatReadBundledText(_path), undefined, true
        );
    } catch (_caught) {
        throw("BladeFirstCombatBeat: product contract could not be decoded");
    }
    if (!is_struct(_contract)
        || !variable_struct_exists(_contract, "runtime_geometry")
        || !is_struct(_contract.runtime_geometry)
        || !variable_struct_exists(_contract.runtime_geometry, "gameplay_plane")) {
        throw("BladeFirstCombatBeat: product contract has no gameplay plane");
    }
    return BladeCombatPlaneCreate(_contract.runtime_geometry.gameplay_plane);
}

/// Removes every attempt-local actor, projectile, and reward before retry restarts.
function BladeFirstBeatCleanupTransientInstances() {
    with (o_blade_first_beat_enemy_bullet) instance_destroy();
    with (o_blade_player_shot) instance_destroy();
    with (o_blade_reward_item) instance_destroy();
    with (o_blade_enemy_target) instance_destroy();
    with (o_blade_stage1_asahi) instance_destroy();
    with (o_blade_stage1_player) instance_destroy();
    with (o_blade_stage1_feedback_effect) instance_destroy();
}

/// Keeps player shots alive through horizontal curves and ends only vertical exits.
function BladeFirstBeatPlayerShotInsideVerticalPlane(_plane, _y) {
    if (!is_numeric(_y) || is_nan(_y) || is_infinity(_y)) {
        throw("BladeFirstCombatBeat: player shot y must be finite");
    }
    var _bounds = BladeCombatPlanePixelBounds(_plane);
    return _y >= _bounds.top && _y < _bounds.bottom_exclusive;
}

/// Keeps hostile bullets in the UI gutters and ends them at the window edge.
function BladeFirstBeatHostileBulletInsideWindow(
    _x, _y, _window_width, _window_height
) {
    if (!is_numeric(_x) || is_nan(_x) || is_infinity(_x)
        || !is_numeric(_y) || is_nan(_y) || is_infinity(_y)) {
        throw("BladeFirstCombatBeat: hostile bullet position must be finite");
    }
    if (!is_numeric(_window_width) || _window_width <= 0
        || !is_numeric(_window_height) || _window_height <= 0) {
        throw("BladeFirstCombatBeat: hostile bullet window must be positive");
    }
    return _x >= 0 && _x < _window_width
        && _y >= 0 && _y < _window_height;
}

/// Returns the nearest currently damageable ordinary or midboss target.
function BladeFirstBeatNearestTarget(_x, _y) {
    var _nearest = noone;
    var _nearest_distance = infinity;
    var _count = instance_number(o_blade_enemy_target);
    for (var _index = 0; _index < _count; ++_index) {
        var _candidate = instance_find(o_blade_enemy_target, _index);
        if (_candidate == noone
            || !variable_instance_exists(_candidate, "targetable")
            || !_candidate.targetable) continue;
        var _distance = point_distance(_x, _y, _candidate.x, _candidate.y);
        if (_distance < _nearest_distance) {
            _nearest = _candidate;
            _nearest_distance = _distance;
        }
    }
    return _nearest;
}

/// @func BladeFirstBeatApplyPlayerShot(controller, target, damage)
/// Applies one concrete player projectile through the target's owned lifecycle.
function BladeFirstBeatApplyPlayerShot(_controller, _target, _damage) {
    if (_target.target_kind == BladeFirstBeatTargetKind.Stage1FaeMidboss) {
        var _midboss = BladeStage1MidbossApplyDamage(
            _controller, _target, _damage
        );
        BladeSurvivalAwardEnemyHit(_controller.economy, _midboss.applied);
        return _midboss;
    }
    if (_target.target_kind == BladeFirstBeatTargetKind.Stage1Asahi) {
        var _boss = BladeStage1BossApplyDamage(_controller, _target, _damage);
        BladeSurvivalAwardEnemyHit(_controller.economy, _boss.applied);
        return _boss;
    }
    var _ordinary = BladeFirstBeatDamageResult(_target.hit_points, _damage);
    _target.hit_points = _ordinary.remaining;
    _target.hit_flash = 4;
    BladeSurvivalAwardEnemyHit(_controller.economy, _ordinary.applied);
    if (_ordinary.defeated) {
        BladeFirstBeatDefeatOrdinaryTarget(_controller, _target);
    }
    return _ordinary;
}

/// Clears bullets owned by one exact stage participant without touching its partner.
function BladeFirstBeatClearOwnedBullets(_stage_instance_id) {
    var _owner = _stage_instance_id;
    with (o_blade_first_beat_enemy_bullet) {
        if (owner_stage_instance_id == _owner) instance_destroy();
    }
}

/// Replaces an opted-in target's live bullets with one point item per bullet.
/// Collection, rather than defeat conversion, awards score and Hyper.
function BladeFirstBeatConvertOwnedBulletsToPointItems(_target) {
    if (!instance_exists(_target)
        || !variable_instance_exists(_target, "auto_cancel_bullets_on_defeat")
        || !_target.auto_cancel_bullets_on_defeat
        || !variable_instance_exists(_target, "stage_instance_id")
        || _target.stage_instance_id == "") {
        return 0;
    }

    var _owner = _target.stage_instance_id;
    var _converted = 0;
    with (o_blade_first_beat_enemy_bullet) {
        if (owner_stage_instance_id == _owner
            && !defeat_conversion_claimed) {
            var _item_x = x;
            var _item_y = y;
            defeat_conversion_claimed = true;
            instance_destroy();
            var _point = instance_create_layer(
                _item_x, _item_y, "Items", o_blade_reward_item
            );
            _point.kind = BladeSurvivalItemKind.Point;
            _point.velocity_x = 0;
            _point.velocity_y = 0.7;
            _converted += 1;
        }
    }
    return _converted;
}

/// Queues one concrete object defeat for the next deterministic Stage tick.
function BladeFirstBeatQueueStageDefeat(_controller, _target) {
    if (!_target.stage_managed || _target.defeat_queued) return false;
    if (!variable_instance_exists(_controller, "stage_defeat_queue")) {
        throw("BladeFirstCombatBeat: managed defeat has no Stage queue");
    }
    _target.defeat_queued = true;
    array_push(_controller.stage_defeat_queue, _target.stage_instance_id);
    return true;
}

/// Creates the concrete point and optional bomb drops declared by one defeated target.
function BladeFirstBeatSpawnTargetRewards(_controller, _target) {
    var _drops = BladeSurvivalResolveEnemyExit(
        _controller.economy,
        BladeSurvivalEnemyExitReason.Defeated,
        BladeSurvivalEnemyIsBombCarrier(_target.archetype_id)
    );
    for (var _drop_index = 0;
        _drop_index < _drops.point_item_count; ++_drop_index) {
        var _point = instance_create_layer(
            _target.x + (_drop_index - 2) * 9,
            _target.y,
            "Items",
            o_blade_reward_item
        );
        _point.kind = BladeSurvivalItemKind.Point;
        _point.velocity_x = (_drop_index - 2) * 0.24;
        _point.velocity_y = 0.7 + _drop_index * 0.08;
    }
    for (var _bomb_index = 0;
        _bomb_index < _drops.bomb_item_count; ++_bomb_index) {
        var _bomb_offset = (
            _bomb_index - (_drops.bomb_item_count - 1) * 0.5
        );
        var _bomb_item = instance_create_layer(
            _target.x + _bomb_offset * 16,
            _target.y - 10,
            "Items",
            o_blade_reward_item
        );
        _bomb_item.kind = BladeSurvivalItemKind.Bomb;
        _bomb_item.velocity_x = _bomb_offset * 0.18;
        _bomb_item.velocity_y = 0.45 + _bomb_index * 0.06;
    }
    return _drops;
}

/// Resolves one ordinary enemy defeat without granting it an auto-cancel privilege.
function BladeFirstBeatDefeatOrdinaryTarget(_controller, _target) {
    var _is_carrier = BladeSurvivalEnemyIsBombCarrier(_target.archetype_id);
    BladeStage1FeedbackSpawn(
        _target.x,
        _target.y,
        BLADE_STAGE1_EFFECT_ENEMY,
        _is_carrier
            ? make_color_rgb(255, 221, 96)
            : make_color_rgb(100, 242, 174),
        _is_carrier ? 1.25 : 1,
        variable_instance_exists(_target, "role_id")
            ? _target.role_id
            : -1,
        3
    );
    BladeStage1AudioPlayForController(
        _controller, BladeStage1AudioSfx.EnemyDefeat, _is_carrier ? 0.78 : 0.52
    );
    BladeFirstBeatSpawnTargetRewards(_controller, _target);
    if (_target.stage_managed) {
        BladeFirstBeatQueueStageDefeat(_controller, _target);
        _controller.feedback_text = _is_carrier
            ? "BOMB CARRIER DOWN\nROUTE CONTINUES"
            : "ENEMY DOWN";
        _controller.feedback_ticks = _is_carrier ? 120 : 45;
    } else {
        _controller.state = BladeFirstBeatTransition(
            _controller.state, BladeFirstBeatEvent.EnemyDefeated
        );
        _controller.feedback_text = "CARRIER DOWN\nCOLLECT REWARDS";
        _controller.feedback_ticks = 120;
        _controller.reward_wait_ticks = 30;
    }
    with (_target) instance_destroy();
}

/// Applies one visible room event without allowing a finished beat to change outcome.
function BladeFirstBeatTransition(_state, _event) {
    if (_event == BladeFirstBeatEvent.Retry) {
        return BladeFirstBeatState.Playing;
    }
    if (_state == BladeFirstBeatState.Playing) {
        switch (_event) {
            case BladeFirstBeatEvent.EnemyDefeated:
                return BladeFirstBeatState.Rewarding;
            case BladeFirstBeatEvent.PlayerOutOfLives:
                return BladeFirstBeatState.Failed;
        }
    } else if (_state == BladeFirstBeatState.Rewarding
        && _event == BladeFirstBeatEvent.RewardsCollected) {
        return BladeFirstBeatState.Won;
    }
    return _state;
}

/// Moves Ciela at her focused or unfocused speed and keeps her body inside the playfield.
function BladeFirstBeatMovePlayer(
    _plane, _x, _y, _move_x, _move_y, _focused, _body_radius
) {
    var _horizontal = clamp(_move_x, -1, 1);
    var _vertical = clamp(_move_y, -1, 1);
    var _length = point_distance(0, 0, _horizontal, _vertical);
    if (_length > 0) {
        _horizontal /= _length;
        _vertical /= _length;
    }

    var _speed = _focused ? 1.35 : 2.75;
    var _bounds = BladeCombatPlanePixelBounds(_plane);
    return {
        x: clamp(
            _x + _horizontal * _speed,
            _bounds.left + _body_radius,
            _bounds.right_exclusive - _body_radius
        ),
        y: clamp(
            _y + _vertical * _speed,
            _bounds.top + _body_radius,
            _bounds.bottom_exclusive - _body_radius
        ),
        speed: _speed,
    };
}

/// Returns Ciela's five-shot upward spread, tightened while she is focused.
function BladeFirstBeatCielaSpread(_focused) {
    var _offsets = _focused
        ? [-6, -3, 0, 3, 6]
        : [-18, -9, 0, 9, 18];
    var _velocities = [];
    for (var _index = 0; _index < array_length(_offsets); ++_index) {
        var _direction = 90 + _offsets[_index];
        array_push(_velocities, {
            x: lengthdir_x(7, _direction),
            y: lengthdir_y(7, _direction),
        });
    }
    return _velocities;
}

/// Advances Ciela's repeat cadence, which active Hyper tiers shorten, and reports a volley.
function BladeFirstBeatFireCadence(_cooldown, _fire_held, _hyper_tier = 0) {
    var _remaining = max(0, _cooldown - 1);
    var _fires = _fire_held && _remaining == 0;
    var _repeat_ticks = max(4, 8 - max(0, _hyper_tier));
    return {
        fires: _fires,
        cooldown: _fires ? _repeat_ticks : _remaining,
    };
}

/// Resolves positive damage once and reports whether the target was defeated.
function BladeFirstBeatDamageResult(_health, _damage) {
    var _remaining = max(0, _health - max(0, _damage));
    return {
        remaining: _remaining,
        applied: max(0, _health - _remaining),
        defeated: _health > 0 && _remaining == 0,
    };
}

/// Uses circle bounds for the simple sprite-free collision shapes in this beat.
function BladeFirstBeatCirclesOverlap(_left_x, _left_y, _left_radius,
    _right_x, _right_y, _right_radius) {
    var _distance_x = _right_x - _left_x;
    var _distance_y = _right_y - _left_y;
    var _combined_radius = _left_radius + _right_radius;
    return _distance_x * _distance_x + _distance_y * _distance_y
        <= _combined_radius * _combined_radius;
}
