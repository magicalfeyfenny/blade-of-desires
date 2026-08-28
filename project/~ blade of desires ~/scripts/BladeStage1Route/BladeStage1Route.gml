/// Bind authored Stage 1 content to the ordinary objects that make it playable.

#macro BLADE_STAGE1_ROUTE_CATALOG_PATH "content/stages/stage1_lost_forest_v1.json"
#macro BLADE_STAGE1_ROUTE_STAGE_ID "stage_schedule.stage1.ciela_lost_forest"
#macro BLADE_STAGE1_ROUTE_SEED 14041991
#macro BLADE_STAGE1_SCOUT_CONTENT_ID "enemy.stage1.scout"

/// Resolves one bundled Stage 1 text file across source and packaged runner layouts.
function BladeStage1RouteIncludedPath(_relative_path) {
    var _candidates = [
        program_directory + _relative_path,
        program_directory + "datafiles/" + _relative_path,
        working_directory + _relative_path,
        _relative_path,
    ];
    for (var _index = 0; _index < array_length(_candidates); ++_index) {
        if (file_exists(_candidates[_index])) return _candidates[_index];
    }
    throw("BladeStage1Route: bundled file does not exist: " + _relative_path);
}

/// Recognizes only the four concrete content identities spawned by this route.
function BladeStage1RouteKnownContent(_content_id) {
    return _content_id == BLADE_STAGE1_SCOUT_CONTENT_ID
        || _content_id == BLADE_SURVIVAL_BOMB_CARRIER_ID
        || _content_id == "ship.maynii"
        || _content_id == "ship.kolar";
}

/// Maps each authored participant kind directly to its playable content identity.
function BladeStage1RouteResolveParticipant(
    _kind_id, _participant_id, _x_q10, _y_q10
) {
    switch (_kind_id) {
        case "participant_kind.stage1.scout":
            return { content_id: BLADE_STAGE1_SCOUT_CONTENT_ID };
        case "participant_kind.stage1.bomb_carrier":
            return { content_id: BLADE_SURVIVAL_BOMB_CARRIER_ID };
        case "participant_kind.stage1.fae_maynii":
            return { content_id: "ship.maynii" };
        case "participant_kind.stage1.fae_kolar":
            return { content_id: "ship.kolar" };
    }
    throw("BladeStage1Route: unknown participant kind " + _kind_id);
}

/// Copies deterministic Stage ownership fields onto one real target object.
function BladeStage1RouteAssignOwnership(_target, _spawn) {
    _target.content_id = _spawn.content_id;
    _target.participant_id = _spawn.participant_id;
    _target.stage_instance_id = _spawn.instance_id;
    _target.stage_encounter_id = _spawn.encounter_id;
    _target.stage_managed = true;
    _target.defeat_queued = false;
    _target.spawn_order = _spawn.spawn_order;
    return _target;
}

/// Creates one scout or bomb carrier using direct, inspectable gameplay fields.
function BladeStage1RouteSpawnOrdinary(_controller, _spawn, _x, _target_y) {
    var _enemy = instance_create_layer(
        _x, -24 - _spawn.spawn_order * 8,
        "Instances", o_blade_first_beat_enemy
    );
    BladeStage1RouteAssignOwnership(_enemy, _spawn);
    _enemy.target_y = _target_y;
    _enemy.fire_cooldown = 0;
    _enemy.targetable = true;
    if (_spawn.content_id == BLADE_SURVIVAL_BOMB_CARRIER_ID) {
        _enemy.archetype_id = BLADE_SURVIVAL_BOMB_CARRIER_ID;
        _enemy.max_health = 36;
        _enemy.hit_radius = 14;
        _enemy.tell_ticks = 55;
        _enemy.fire_repeat_ticks = 56;
        _enemy.bullet_speed = 2.55;
        _enemy.bullet_offsets = [-14, 0, 14];
        _enemy.travel_speed_x = 0.65;
    } else {
        _enemy.archetype_id = BLADE_STAGE1_SCOUT_CONTENT_ID;
        _enemy.max_health = 18;
        _enemy.hit_radius = 11;
        _enemy.tell_ticks = 35 + _spawn.spawn_order * 8;
        _enemy.fire_repeat_ticks = 72 + (_spawn.spawn_order mod 2) * 12;
        _enemy.bullet_speed = 2.15 + (_spawn.spawn_order mod 3) * 0.12;
        _enemy.bullet_offsets = (_spawn.spawn_order mod 2 == 0)
            ? [-18, 18]
            : [-10, 0, 10];
        _enemy.travel_speed_x = (_spawn.spawn_order mod 2 == 0) ? 0.55 : -0.55;
    }
    _enemy.hit_points = _enemy.max_health;
    return _enemy;
}

/// Creates one Maynii or Kolar body and registers it with the compact duo director.
function BladeStage1RouteSpawnMidboss(_controller, _spawn, _x, _target_y) {
    var _member = instance_create_layer(
        _x, -34,
        "Instances", o_blade_stage1_fae_midboss
    );
    BladeStage1RouteAssignOwnership(_member, _spawn);
    _member.anchor_x = _x;
    _member.anchor_y = _target_y;
    var _role = _spawn.content_id == "ship.maynii"
        ? BladeStage1FaeRole.Maynii
        : BladeStage1FaeRole.Kolar;
    BladeStage1MidbossRegister(_controller, _member, _role);
    _controller.route_label = "MIDBOSS  MAYNII + KOLAR";
    return _member;
}

/// Materializes one preflighted Stage participant as an ordinary gameplay object.
function BladeStage1RouteSpawnParticipant(_spawn) {
    var _controller = self.controller;
    if (!instance_exists(_controller)) return false;
    var _x = real(_spawn.x_q10) / 1024;
    var _target_y = real(_spawn.y_q10) / 1024;
    if (_spawn.content_id == "ship.maynii"
        || _spawn.content_id == "ship.kolar") {
        BladeStage1RouteSpawnMidboss(_controller, _spawn, _x, _target_y);
    } else {
        BladeStage1RouteSpawnOrdinary(_controller, _spawn, _x, _target_y);
    }
    return true;
}

/// Initializes deterministic schedule ownership without constructing the old combat runtime.
function BladeStage1RouteInitialize(_controller) {
    _controller.stage_route_enabled = true;
    _controller.stage_defeat_queue = [];
    _controller.stage_last_defeat_results = [];
    _controller.stage_cue_cursor = 0;
    _controller.route_cue_id = "";
    _controller.route_label = "LOST FOREST  FIRST HALF";
    _controller.midboss_state = BladeStage1MidbossStateCreate();

    var _product_path = BladeStage1RouteIncludedPath(
        BLADE_FIRST_BEAT_PRODUCT_CONTRACT_PATH
    );
    var _catalog_path = BladeStage1RouteIncludedPath(
        BLADE_STAGE1_ROUTE_CATALOG_PATH
    );
    var _fingerprint = "sha1:" + sha1_file(_product_path);
    _controller.stage_kernel = BladeDeterministicKernelCreate(
        _fingerprint,
        BLADE_STAGE1_ROUTE_SEED,
        method({}, BladeStage1RouteKnownContent),
        8
    );
    _controller.stage_executor = BladeStageContentCreateExecutor(
        _catalog_path,
        BLADE_STAGE1_ROUTE_STAGE_ID,
        method({}, BladeStage1RouteResolveParticipant),
        _controller.gameplay_plane,
        _product_path,
        _fingerprint
    );
    _controller.stage_spawn_callback = method(
        { controller: _controller }, BladeStage1RouteSpawnParticipant
    );
    BladeStageExecutorBindPlayable(
        _controller.stage_executor,
        _controller.stage_kernel,
        _controller.stage_spawn_callback
    );
    return BladeStageExecutorSnapshot(_controller.stage_executor);
}

/// Reports queued object defeats before advancing one exact deterministic Stage tick.
function BladeStage1RouteTick(_kernel, _input, _tick) {
    var _controller = self.controller;
    var _queued = _controller.stage_defeat_queue;
    _controller.stage_defeat_queue = [];
    _controller.stage_last_defeat_results = [];
    for (var _index = 0; _index < array_length(_queued); ++_index) {
        array_push(
            _controller.stage_last_defeat_results,
            BladeStageExecutorReportPlayableDefeat(
                _controller.stage_executor,
                _kernel,
                _queued[_index],
                _tick
            )
        );
    }
    BladeStageExecutorAdvancePlayable(
        _controller.stage_executor, _kernel, _tick
    );
    return BladeStageExecutorCanonical(_controller.stage_executor);
}

/// Applies one semantic route cue to presentation and readable player feedback.
function BladeStage1RouteApplyCue(_controller, _cue_id) {
    var _renderer = instance_find(o_blade_stage1_forest_renderer, 0);
    _controller.route_cue_id = _cue_id;
    if (_renderer != noone) {
        BladeStage1ForestApplyRouteCue(_renderer, _cue_id);
    }
    switch (_cue_id) {
        case "cue.stage1.forest_travel":
            _controller.route_label = "LOST FOREST  FIRST HALF";
            break;

        case "cue.stage1.midboss_stop":
            _controller.route_label = "MIDBOSS STOP";
            _controller.feedback_text = "THE FOREST HOLDS ITS BREATH";
            _controller.feedback_ticks = 90;
            break;

        case "cue.stage1.forest_resume":
            _controller.route_label = "LOST FOREST  SECOND HALF";
            _controller.feedback_text = "PATH REOPENED\nFORWARD";
            _controller.feedback_ticks = 120;
            break;

        case "cue.stage1.world_tree_approach":
            _controller.route_label = "WORLD TREE APPROACH";
            _controller.feedback_text = "THE WORLD TREE FILLS THE HORIZON";
            _controller.feedback_ticks = 150;
            break;

        case "cue.stage1.world_tree_handoff":
            _controller.route_label = "WORLD TREE  ASAHI AHEAD";
            _controller.feedback_text = "THE WORLD TREE\nASAHI AWAITS";
            _controller.feedback_ticks = 180;
            break;
    }
}

/// Advances Stage 1 once, delivers new cues once, and ends only at the handoff node.
function BladeStage1RouteAdvance(_controller) {
    if (!_controller.stage_route_enabled) return undefined;
    var _context = { controller: _controller };
    var _result = BladeKernelStepDirect(
        _controller.stage_kernel,
        BladeInputRawStateCreate(0, 0, 0),
        BladeClockDomain.Stage,
        method(_context, BladeStage1RouteTick)
    );
    var _cues = BladeStagePortsReadCueRequests(
        _controller.stage_executor.ports,
        _controller.stage_cue_cursor
    );
    _controller.stage_cue_cursor = _cues.next_cursor;
    for (var _index = 0; _index < array_length(_cues.records); ++_index) {
        BladeStage1RouteApplyCue(_controller, _cues.records[_index].cue_id);
    }
    if (_controller.stage_executor.lifecycle == BladeStageLifecycle.Completed
        && _controller.state == BladeFirstBeatState.Playing) {
        _controller.state = BladeFirstBeatState.Won;
        _controller.route_label = "WORLD TREE REACHED";
        with (o_blade_first_beat_enemy_bullet) instance_destroy();
        with (o_ciela_first_beat_shot) instance_destroy();
    }
    return _result;
}

/// Aborts active Stage ownership before retry cleanup removes attempt-local objects.
function BladeStage1RouteAbort(_controller, _reason) {
    if (!_controller.stage_route_enabled
        || _controller.stage_executor.lifecycle != BladeStageLifecycle.Active) {
        return false;
    }
    var _counters = BladeSimulationClockGetCounters(
        _controller.stage_kernel.clock
    );
    BladeStageExecutorAbortPlayable(
        _controller.stage_executor,
        _reason,
        {
            simulation_tick: _counters.simulation_tick,
            stage_tick: _counters.stage_tick,
            actor_tick: _counters.actor_tick,
            boss_tick: _counters.boss_tick,
            combat_tick: _counters.combat_tick,
            presentation_tick: _counters.presentation_tick,
            domain_mask: BladeClockDomain.None,
        }
    );
    return true;
}
