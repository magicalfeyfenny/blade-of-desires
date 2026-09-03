/// Bind authored Stage 1 content to the ordinary objects that make it playable.

#macro BLADE_STAGE1_ROUTE_CATALOG_PATH "content/stages/stage1_lost_forest_v1.json"
#macro BLADE_STAGE1_ROUTE_SEED 14041991

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

/// Recognizes only the concrete content identities spawned by either selected route.
function BladeStage1RouteKnownContent(_content_id) {
    return BladeStage1EnemyKnownContent(_content_id)
        || _content_id == "ship.ciela"
        || _content_id == "ship.maynii"
        || _content_id == "ship.kolar"
        || _content_id == BLADE_STAGE1_ASAHI_CONTENT_ID;
}

/// Maps generic fae slots through the selected run's canonical unchosen pair.
function BladeStage1RouteResolveParticipant(
    _kind_id, _participant_id, _x_q10, _y_q10
) {
    switch (_kind_id) {
        case "participant_kind.stage1.popcorn":
            return { content_id: BLADE_STAGE1_POPCORN_CONTENT_ID };
        case "participant_kind.stage1.mook":
            return { content_id: BLADE_STAGE1_MOOK_CONTENT_ID };
        case "participant_kind.stage1.elite":
            return { content_id: BLADE_STAGE1_ELITE_CONTENT_ID };
        case "participant_kind.stage1.commander":
            return { content_id: BLADE_STAGE1_COMMANDER_CONTENT_ID };
        // Bounded migration support for catalogs written before Issue #115.
        case "participant_kind.stage1.scout":
            return { content_id: BLADE_STAGE1_MOOK_CONTENT_ID };
        case "participant_kind.stage1.bomb_carrier":
            return { content_id: BLADE_SURVIVAL_BOMB_CARRIER_ID };
        case "participant_kind.stage1.fae_slot_a":
            return { content_id: self.selected_run.midboss_ship_ids[0] };
        case "participant_kind.stage1.fae_slot_b":
            return { content_id: self.selected_run.midboss_ship_ids[1] };
        case "participant_kind.stage1.asahi":
            return { content_id: BLADE_STAGE1_ASAHI_CONTENT_ID };
    }
    throw("BladeStage1Route: unknown participant kind " + _kind_id);
}

// Converts the three canonical ship identities to concise route labels.
function BladeStage1RouteShipName(_ship_id) {
    switch (_ship_id) {
        case "ship.ciela": return "CIELA";
        case "ship.maynii": return "MAYNII";
        case "ship.kolar": return "KOLAR";
    }
    throw("BladeStage1Route: unknown ship identity " + string(_ship_id));
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

/// Creates one roster role or bomb-carrier variant using inspectable gameplay fields.
function BladeStage1RouteSpawnOrdinary(_controller, _spawn, _x, _target_y) {
    var _enemy = instance_create_layer(
        _x, -24 - _spawn.spawn_order * 8,
        "Instances", o_blade_first_beat_enemy
    );
    BladeStage1RouteAssignOwnership(_enemy, _spawn);
    var _difficulty_id = BladeSurvivalEconomyDifficulty(_controller.economy);
    var _rank = BladeSurvivalEconomyRank(_controller.economy);
    _enemy.target_y = _target_y;
    _enemy.fire_cooldown = 0;
    _enemy.targetable = true;
    var _is_carrier = _spawn.content_id == BLADE_SURVIVAL_BOMB_CARRIER_ID;
    var _role_content_id = _is_carrier
        ? BLADE_STAGE1_MOOK_CONTENT_ID
        : _spawn.content_id;
    BladeStage1EnemyConfigure(
        _enemy,
        _role_content_id,
        _spawn.spawn_order,
        _difficulty_id,
        _rank,
        _is_carrier
    );
    // Ownership remains the schedule's stable participant identity.
    _enemy.content_id = _spawn.content_id;
    _enemy.target_y = _target_y;
    return _enemy;
}

/// Creates one unchosen fae body and binds its role and standard-pattern identity.
function BladeStage1RouteSpawnMidboss(_controller, _spawn, _x, _target_y) {
    var _member = instance_create_layer(
        _x, -34,
        "Instances", o_blade_stage1_fae_midboss
    );
    BladeStage1RouteAssignOwnership(_member, _spawn);
    _member.anchor_x = _x;
    _member.anchor_y = _target_y;
    var _role;
    switch (_spawn.content_id) {
        case "ship.ciela": _role = BladeStage1FaeRole.Ciela; break;
        case "ship.maynii": _role = BladeStage1FaeRole.Maynii; break;
        case "ship.kolar": _role = BladeStage1FaeRole.Kolar; break;
        default:
            throw("BladeStage1Route: unsupported fae " + _spawn.content_id);
    }
    var _pattern_id = _controller.selected_run.standard_pattern_ids[
        _spawn.spawn_order
    ];
    BladeStage1MidbossRegister(_controller, _member, _role, _pattern_id);
    _controller.route_label = BladeStage1RouteShipName(
        _controller.selected_run.midboss_ship_ids[0]
    ) + " + " + BladeStage1RouteShipName(
        _controller.selected_run.midboss_ship_ids[1]
    );
    return _member;
}

/// Creates Asahi at the World Tree and binds her exact schedule ownership.
function BladeStage1RouteSpawnAsahi(_controller, _spawn, _x, _target_y) {
    var _boss = instance_create_layer(
        _x, -48,
        "Instances", o_blade_stage1_asahi
    );
    BladeStage1RouteAssignOwnership(_boss, _spawn);
    _boss.anchor_x = _x;
    _boss.anchor_y = _target_y;
    BladeStage1BossRegister(_controller, _boss);
    return _boss;
}

/// Materializes one preflighted Stage participant as an ordinary gameplay object.
function BladeStage1RouteSpawnParticipant(_spawn) {
    var _controller = self.controller;
    if (!instance_exists(_controller)) return false;
    var _x = real(_spawn.x_q10) / 1024;
    var _target_y = real(_spawn.y_q10) / 1024;
    if (_spawn.content_id == BLADE_STAGE1_ASAHI_CONTENT_ID) {
        BladeStage1RouteSpawnAsahi(_controller, _spawn, _x, _target_y);
    } else if (_spawn.content_id == "ship.ciela"
        || _spawn.content_id == "ship.maynii"
        || _spawn.content_id == "ship.kolar") {
        BladeStage1RouteSpawnMidboss(_controller, _spawn, _x, _target_y);
    } else {
        BladeStage1RouteSpawnOrdinary(_controller, _spawn, _x, _target_y);
    }
    return true;
}

/// Initializes deterministic schedule ownership without constructing the old combat runtime.
function BladeStage1RouteInitialize(_controller) {
    if (is_undefined(_controller.selected_run)) {
        throw("BladeStage1Route: selected run must be configured before Stage 1");
    }
    _controller.stage_route_enabled = true;
    _controller.stage_defeat_queue = [];
    _controller.stage_last_defeat_results = [];
    _controller.stage_cue_cursor = 0;
    _controller.route_cue_id = "";
    _controller.route_label = "FOREST  FIRST HALF";
    _controller.midboss_state = BladeStage1MidbossStateCreate(
        _controller.selected_run
    );

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
        _controller.selected_run.stage_schedule_id,
        method(
            { selected_run: _controller.selected_run },
            BladeStage1RouteResolveParticipant
        ),
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
    return BladeCanonicalRecord("BRT2", [
        BladeStageExecutorCanonical(_controller.stage_executor),
        BladeDifficultyRankCanonical(_controller.economy.rank_state),
        BladeDifficultyPressureCanonical(
            BladeSurvivalEconomyDifficulty(_controller.economy),
            BladeSurvivalEconomyRank(_controller.economy),
            _controller.economy.active_hyper_tier
        ),
        BladeSurvivalEconomyCanonical(_controller.economy),
    ]);
}

/// Applies one semantic route cue to presentation and readable player feedback.
function BladeStage1RouteApplyCue(_controller, _cue_id) {
    var _renderer = instance_find(o_blade_stage1_forest_renderer, 0);
    _controller.route_cue_id = _cue_id;
    if (_renderer != noone) {
        BladeStage1ForestApplyRouteCue(_renderer, _cue_id);
    }
    BladeStage1AudioApplyRouteCue(_controller, _cue_id);
    switch (_cue_id) {
        case "cue.stage1.forest_travel":
            _controller.route_label = "FOREST  FIRST HALF";
            _controller.route_notice_text = "ENTER THE LOST FOREST";
            _controller.route_notice_ticks = 100;
            break;

        case "cue.stage1.midboss_stop":
            _controller.route_label = "MIDBOSS STOP";
            _controller.route_notice_text = "THE FOREST HOLDS BREATH";
            _controller.route_notice_ticks = 120;
            break;

        case "cue.stage1.forest_resume":
            _controller.route_label = "FOREST  SECOND HALF";
            _controller.route_notice_text = "PATH REOPENED  FORWARD";
            _controller.route_notice_ticks = 120;
            break;

        case "cue.stage1.world_tree_approach":
            _controller.route_label = "WORLD TREE APPROACH";
            _controller.route_notice_text = "WORLD TREE ON THE HORIZON";
            _controller.route_notice_ticks = 150;
            break;

        case "cue.stage1.world_tree_handoff":
            _controller.route_label = "WORLD TREE  ASAHI";
            _controller.route_notice_text = "ASAHI AWAITS AT THE TREE";
            _controller.route_notice_ticks = 180;
            BladeStage1FeedbackSpawn(
                320,
                154,
                BLADE_STAGE1_EFFECT_HANDOFF,
                make_color_rgb(255, 232, 142),
                1.25
            );
            break;

        case "cue.stage1.asahi_warning":
            _controller.route_label = "WARNING  ASAHI";
            _controller.route_notice_text = "ASAHI  SUNNY FAE OF FLAME";
            _controller.route_notice_ticks = 150;
            BladeStage1BossBeginWarning(_controller);
            break;

        case "cue.stage1.stage_clear":
            _controller.route_label = "STAGE 1 CLEAR";
            _controller.route_notice_text = "ASAHI RESOLVED  DAWN BREAKS";
            _controller.route_notice_ticks = 240;
            BladeStage1BossFinalizeStageClear(_controller);
            break;
    }
}

/// Advances Stage 1 once, delivers new cues once, and ends at Stage Clear.
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
        _controller.route_label = "STAGE 1 CLEAR";
        with (o_blade_first_beat_enemy_bullet) instance_destroy();
        with (o_blade_player_shot) instance_destroy();
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
