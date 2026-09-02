/// Focused coverage for selected players and every Stage 1 route variant.

// Places one entered fae directly into its independently targetable attack.
function _BladeStage1SelectedRouteTestsActivate(_member) {
    _member.targetable = true;
    _member.phase_transition_ticks = 0;
    _member.entry_complete = true;
    _member.x = _member.anchor_x;
    _member.y = _member.anchor_y;
    return _member;
}

// Runs a deterministic zero-input prefix and returns its command/event evidence.
function _BladeStage1SelectedRouteTestsPrefix(_ship_id) {
    var _controller = instance_create_layer(
        0, 0, "Instances", o_blade_first_beat_controller
    );
    _BladeStage1RouteTestsSelect(_controller, _ship_id);
    BladeStage1RouteInitialize(_controller);
    var _record = { ordinary_count: 0, carrier_count: 0 };
    if (!_BladeStage1RouteTestsReachDuo(_controller, _record)) {
        throw("selected route did not reach its midboss prefix");
    }
    var _diagnostics = BladeKernelDiagnostics(_controller.stage_kernel);
    var _events = BladeStageEventStreamSnapshot(
        _controller.stage_executor.events
    );
    var _result = {
        executor_hash: BladeStageExecutorHash(_controller.stage_executor),
        gameplay_hash: _diagnostics.gameplay_hash,
        event_count: array_length(_events),
        event_hash: BladeCanonicalHashUtf8(
            BladeStageEventStreamCanonical(_controller.stage_executor.events)
        ),
    };
    with (_controller) instance_destroy();
    BladeFirstBeatCleanupTransientInstances();
    return _result;
}

// Proves Maynii owns the shared player lifecycle and both concrete shot children.
function _BladeStage1SelectedRouteTestsMayniiPlayer(_state) {
    BladeFirstBeatTestRunCase(
        _state,
        "Maynii uses the shared player lifecycle through death and cleanup",
        function() {
            var _controller = instance_create_layer(
                0, 0, "Instances", o_blade_first_beat_controller
            );
            var _run = _BladeStage1RouteTestsSelect(
                _controller, "ship.maynii"
            );
            var _player = instance_create_layer(
                320, 300, "Instances", o_maynii_first_beat_player
            );
            _controller.player_instance = _player;
            BladeKernelTestAssertEqual(
                BladeShipSelectionPlayerObject(_run.player_kind_id),
                o_maynii_first_beat_player,
                "validated Maynii player kind maps to the packaged child object"
            );
            BladeKernelTestAssertEqual(
                instance_number(o_blade_stage1_player), 1,
                "the selected player exists through the one shared parent"
            );
            BladeKernelTestAssertEqual(
                BladeStage1PlayerInstance(_controller), _player,
                "controller lookup returns exactly the selected player"
            );
            BladeKernelTestAssertEqual(
                _player.ship_id, "ship.maynii",
                "Maynii child binds stable ship identity"
            );

            _player.focused = false;
            _BladeStage1PlayerFireMaynii(_player, _controller);
            BladeKernelTestAssertEqual(
                instance_number(o_maynii_first_beat_shot), 2,
                "unfocused Maynii creates only the two tracking shots"
            );
            var _first_tracking = instance_find(
                o_maynii_first_beat_shot, 0
            );
            var _tracking_start_x = _first_tracking.x;
            var _tracking_start_y = _first_tracking.y;
            BladeKernelTestAssertEqual(
                _first_tracking.speed, 0,
                "manual trajectory keeps GameMaker built-in motion disabled"
            );
            with (_first_tracking) event_perform(ev_step, ev_step_normal);
            BladeKernelTestAssertEqual(
                _first_tracking.x, _tracking_start_x,
                "no-target tracking fallback has no sideways drift"
            );
            BladeKernelTestAssertTrue(
                abs(
                    _first_tracking.y
                    - (_tracking_start_y - BLADE_MAYNII_TRACKING_SPEED)
                ) < 0.001,
                "real tracking shot advances exactly one manual trajectory step"
            );
            for (var _tracking_index = 0;
                _tracking_index < instance_number(o_maynii_first_beat_shot);
                ++_tracking_index) {
                var _tracking = instance_find(
                    o_maynii_first_beat_shot, _tracking_index
                );
                BladeKernelTestAssertTrue(
                    _tracking.tracking,
                    "each unfocused child projectile owns tracking mode"
                );
            }
            with (o_blade_player_shot) instance_destroy();

            _player.focused = true;
            _BladeStage1PlayerFireMaynii(_player, _controller);
            BladeKernelTestAssertEqual(
                instance_number(o_maynii_first_beat_shot), 3,
                "focused Maynii creates only the three forward shots"
            );
            for (var _forward_index = 0;
                _forward_index < instance_number(o_maynii_first_beat_shot);
                ++_forward_index) {
                var _forward = instance_find(
                    o_maynii_first_beat_shot, _forward_index
                );
                BladeKernelTestAssertFalse(
                    _forward.tracking,
                    "each focused child projectile owns forward mode"
                );
                BladeKernelTestAssertEqual(
                    _forward.speed, 0,
                    "forward child also disables GameMaker built-in motion"
                );
            }

            _controller.economy.score = 1000;
            _controller.economy.bombs = 1;
            _controller.economy.hyper_meter = 200;
            _controller.economy.shot_strength = 3;
            _controller.player_phase = BladeSurvivalPlayerPhase.HitResponse;
            _controller.hit_response_ticks = 1;
            with (_controller) event_perform(ev_step, ev_step_normal);
            BladeKernelTestAssertEqual(
                _controller.selected_ship_id, "ship.maynii",
                "committed death preserves selected identity"
            );
            BladeKernelTestAssertEqual(
                _controller.selected_run.route_id,
                "playable_route.stage1.maynii",
                "committed death preserves selected route identity"
            );
            BladeKernelTestAssertEqual(
                _player.ship_id, "ship.maynii",
                "the same Maynii body enters respawn"
            );
            BladeKernelTestAssertEqual(
                _player.x, BLADE_SURVIVAL_PLAYER_START_X,
                "shared death handling resets Maynii x"
            );
            BladeKernelTestAssertEqual(
                _player.y, BLADE_SURVIVAL_PLAYER_START_Y,
                "shared death handling resets Maynii y"
            );
            BladeKernelTestAssertEqual(
                _controller.player_phase,
                BladeSurvivalPlayerPhase.Respawning,
                "Maynii enters the shared respawn phase"
            );
            _controller.respawn_ticks = 1;
            with (_controller) event_perform(ev_step, ev_step_normal);
            BladeKernelTestAssertEqual(
                _controller.player_phase, BladeSurvivalPlayerPhase.Active,
                "Maynii returns through the shared respawn boundary"
            );

            BladeFirstBeatCleanupTransientInstances();
            BladeKernelTestAssertEqual(
                instance_number(o_blade_stage1_player), 0,
                "reset cleanup removes the selected Maynii child"
            );
            BladeKernelTestAssertEqual(
                instance_number(o_blade_player_shot), 0,
                "reset cleanup removes every Maynii shot child"
            );
            var _validated = BladeShipSelectionRequireRun(
                BladeShipSelectionLoad(), _controller.selected_run
            );
            BladeKernelTestAssertEqual(
                _validated.ship_id, "ship.maynii",
                "attempt cleanup cannot erase persistent run identity"
            );
        }
    );
}

// Proves Kolar owns both explicit channels through the shared player lifecycle.
function _BladeStage1SelectedRouteTestsKolarPlayer(_state) {
    BladeFirstBeatTestRunCase(
        _state,
        "Kolar uses the shared player lifecycle with close and ranged fire",
        function() {
            var _controller = instance_create_layer(
                0, 0, "Instances", o_blade_first_beat_controller
            );
            var _run = _BladeStage1RouteTestsSelect(
                _controller, "ship.kolar"
            );
            var _player = instance_create_layer(
                320, 300, "Instances", o_kolar_first_beat_player
            );
            _controller.player_instance = _player;
            BladeKernelTestAssertEqual(
                BladeShipSelectionPlayerObject(_run.player_kind_id),
                o_kolar_first_beat_player,
                "validated Kolar player kind maps to the packaged child object"
            );
            BladeKernelTestAssertEqual(
                _player.ship_id, "ship.kolar",
                "Kolar child binds stable ship identity"
            );

            _player.focused = false;
            _BladeStage1PlayerFireKolar(_player, _controller);
            BladeKernelTestAssertEqual(
                instance_number(o_kolar_first_beat_shot), 3,
                "unfocused Kolar creates one close and two ranged shots"
            );
            var _unfocused_close = 0;
            var _unfocused_ranged = 0;
            for (var _unfocused_index = 0;
                _unfocused_index < instance_number(o_kolar_first_beat_shot);
                ++_unfocused_index) {
                var _unfocused = instance_find(
                    o_kolar_first_beat_shot, _unfocused_index
                );
                if (_unfocused.channel == "close") {
                    _unfocused_close += 1;
                    BladeKernelTestAssertEqual(
                        _unfocused.range_limit, BLADE_KOLAR_CLOSE_BAND,
                        "close shot owns the logical close band"
                    );
                } else {
                    _unfocused_ranged += 1;
                }
                BladeKernelTestAssertEqual(
                    _unfocused.speed, 0,
                    "Kolar shot uses explicit manual motion"
                );
            }
            BladeKernelTestAssertEqual(_unfocused_close, 1, "unfocused close count");
            BladeKernelTestAssertEqual(_unfocused_ranged, 2, "unfocused ranged count");
            with (o_blade_player_shot) instance_destroy();

            _player.focused = true;
            _BladeStage1PlayerFireKolar(_player, _controller);
            var _focused_close = 0;
            var _focused_ranged = 0;
            for (var _focused_index = 0;
                _focused_index < instance_number(o_kolar_first_beat_shot);
                ++_focused_index) {
                var _focused = instance_find(
                    o_kolar_first_beat_shot, _focused_index
                );
                if (_focused.channel == "close") _focused_close += 1;
                else _focused_ranged += 1;
            }
            BladeKernelTestAssertEqual(_focused_close, 2, "focused close count");
            BladeKernelTestAssertEqual(_focused_ranged, 1, "focused ranged count");
            BladeFirstBeatCleanupTransientInstances();
            BladeKernelTestAssertEqual(
                instance_number(o_blade_stage1_player), 0,
                "cleanup removes the selected Kolar child"
            );
        }
    );
}

// Exercises the complete Ciela-Kolar personal, recharge, combo, and resume path.
function _BladeStage1SelectedRouteTestsCielaKolar(_state) {
    BladeFirstBeatTestRunCase(
        _state,
        "fae registration rejects a standard pattern for the wrong identity",
        function() {
            var _controller = instance_create_layer(
                0, 0, "Instances", o_blade_first_beat_controller
            );
            var _member = instance_create_layer(
                320, 80, "Instances", o_blade_stage1_fae_midboss
            );
            BladeKernelTestAssertThrows(
                method(
                    { controller: _controller, member: _member },
                    function() {
                        BladeStage1MidbossRegister(
                            self.controller,
                            self.member,
                            BladeStage1FaeRole.Ciela,
                            "pattern.stage1.standard.kolar_crystal_fan"
                        );
                    }
                ),
                "does not match CIELA",
                "valid pattern IDs cannot silently substitute another fae"
            );
        }
    );

    BladeFirstBeatTestRunCase(
        _state,
        "Maynii route resolves Ciela and Kolar once then resumes Stage 1",
        function() {
            var _controller = instance_create_layer(
                0, 0, "Instances", o_blade_first_beat_controller
            );
            var _run = _BladeStage1RouteTestsSelect(
                _controller, "ship.maynii"
            );
            BladeStage1RouteInitialize(_controller);
            var _record = { ordinary_count: 0, carrier_count: 0 };
            BladeKernelTestAssertTrue(
                _BladeStage1RouteTestsReachDuo(_controller, _record),
                "Maynii route reaches its authored unchosen pair"
            );
            var _state_before = _controller.midboss_state;
            var _ciela = _state_before.members[0];
            var _kolar = _state_before.members[1];
            BladeKernelTestAssertArrayEqual(
                _run.midboss_ship_ids, ["ship.ciela", "ship.kolar"],
                "Maynii route excludes the selected player from the pair"
            );
            BladeKernelTestAssertEqual(
                _state_before.selected_ship_id, "ship.maynii",
                "duo director retains selected ship identity"
            );
            BladeKernelTestAssertEqual(
                _ciela.content_id, "ship.ciela",
                "first generic fae slot resolves to Ciela"
            );
            BladeKernelTestAssertEqual(
                _kolar.content_id, "ship.kolar",
                "second generic fae slot resolves to Kolar"
            );
            BladeKernelTestAssertEqual(
                _ciela.standard_pattern_id,
                "pattern.stage1.standard.ciela_river_current",
                "Ciela owns her unique river-current standard"
            );
            BladeKernelTestAssertEqual(
                _kolar.standard_pattern_id,
                "pattern.stage1.standard.kolar_crystal_fan",
                "Kolar retains her crystal standard"
            );
            BladeKernelTestAssertEqual(
                _state_before.combo_pattern_id,
                "pattern.stage1.combo.ciela_kolar_river_ridgeline",
                "the pair owns its distinct shared combo identity"
            );

            var _player = instance_create_layer(
                320, 300, "Instances", o_maynii_first_beat_player
            );
            _controller.player_instance = _player;
            _BladeStage1SelectedRouteTestsActivate(_ciela);
            _BladeStage1SelectedRouteTestsActivate(_kolar);
            _ciela.attack_ticks = 57;
            _kolar.attack_ticks = 63;
            BladeStage1MidbossStep(_ciela);
            BladeStage1MidbossStep(_kolar);
            BladeKernelTestAssertEqual(
                _BladeStage1RouteTestsBulletCount(
                    BladeFirstBeatBulletKind.CielaCurrent
                ),
                6,
                "Ciela's standard emits two staggered river banks"
            );
            BladeKernelTestAssertEqual(
                _BladeStage1RouteTestsBulletCount(
                    BladeFirstBeatBulletKind.KolarCrystal
                ),
                5,
                "Kolar's standard remains independently authored"
            );
            BladeKernelTestAssertEqual(
                _BladeStage1RouteTestsBulletCount(
                    BladeFirstBeatBulletKind.MayniiLeaf
                ),
                0,
                "selected Maynii never emits a midboss standard"
            );

            var _unrelated = instance_create_layer(
                320, 90, "Projectiles", o_blade_first_beat_enemy_bullet
            );
            _unrelated.owner_stage_instance_id = "stage.instance.unrelated";
            var _stage_tick = BladeSimulationClockGetCounters(
                _controller.stage_kernel.clock
            ).stage_tick;
            var _kolar_solo = BladeStage1MidbossApplyDamage(
                _controller, _kolar, BLADE_STAGE1_MIDBOSS_PERSONAL_HP
            );
            BladeKernelTestAssertTrue(
                _kolar_solo.defeated && _kolar.personal_defeated,
                "reverse defeat order clears Kolar first"
            );
            _kolar.attack_ticks = 63;
            BladeStage1MidbossStep(_kolar);
            BladeKernelTestAssertFalse(
                _kolar.targetable,
                "defeated retained Kolar is harmless and untargetable"
            );
            BladeKernelTestAssertEqual(
                _BladeStage1RouteTestsBulletCount(
                    BladeFirstBeatBulletKind.KolarCrystal
                ),
                0,
                "defeated retained Kolar cannot fire"
            );
            BladeKernelTestAssertEqual(
                BladeStage1MidbossApplyDamage(_controller, _kolar, 1).applied,
                0,
                "defeated retained Kolar cannot take duplicate damage"
            );

            var _ciela_solo = BladeStage1MidbossApplyDamage(
                _controller, _ciela, BLADE_STAGE1_MIDBOSS_PERSONAL_HP
            );
            BladeKernelTestAssertTrue(
                _ciela_solo.defeated && _state_before.combo_active,
                "same-tick second defeat starts exactly one combo"
            );
            BladeKernelTestAssertEqual(
                BladeSimulationClockGetCounters(
                    _controller.stage_kernel.clock
                ).stage_tick,
                _stage_tick,
                "simultaneous personal defeats require no intervening Stage tick"
            );
            BladeKernelTestAssertTrue(
                instance_exists(_unrelated),
                "pair phase cleanup preserves unrelated route bullets"
            );
            BladeKernelTestAssertFalse(
                BladeStage1MidbossBeginCombo(_controller),
                "a duplicate combo-start request is ignored"
            );

            for (var _recharge = 0;
                _recharge < BLADE_STAGE1_MIDBOSS_RECHARGE_TICKS - 1;
                ++_recharge) {
                BladeStage1MidbossStep(_ciela);
                BladeStage1MidbossStep(_kolar);
            }
            BladeKernelTestAssertFalse(
                _ciela.targetable || _kolar.targetable,
                "combo remains harmless through the penultimate recharge tick"
            );
            BladeStage1MidbossStep(_ciela);
            BladeStage1MidbossStep(_kolar);
            BladeKernelTestAssertTrue(
                _ciela.targetable && _kolar.targetable,
                "the exact recharge boundary enables both shared hurtboxes"
            );

            _ciela.attack_ticks = 67;
            _kolar.attack_ticks = 21;
            BladeStage1MidbossStep(_ciela);
            BladeStage1MidbossStep(_kolar);
            BladeKernelTestAssertEqual(
                _BladeStage1RouteTestsBulletCount(
                    BladeFirstBeatBulletKind.ComboRiver
                ),
                6,
                "Ciela leaves a two-lane channel in her river combo"
            );
            BladeKernelTestAssertEqual(
                _BladeStage1RouteTestsBulletCount(
                    BladeFirstBeatBulletKind.ComboRiverCrystal
                ),
                4,
                "Kolar answers the river channel with one ridgeline"
            );
            BladeKernelTestAssertEqual(
                _BladeStage1RouteTestsBulletCount(
                    BladeFirstBeatBulletKind.ComboLeaf
                ) + _BladeStage1RouteTestsBulletCount(
                    BladeFirstBeatBulletKind.ComboCrystal
                ),
                0,
                "Ciela-Kolar cannot replay the Maynii-Kolar combo commands"
            );

            var _score_before = _controller.economy.score;
            BladeStage1MidbossApplyDamage(_controller, _ciela, 30);
            BladeKernelTestAssertEqual(
                _ciela.hit_points, 120,
                "combo damage reduces Ciela's shared life"
            );
            BladeKernelTestAssertEqual(
                _kolar.hit_points, 120,
                "combo damage synchronizes Kolar's shared life"
            );
            var _ciela_reference = _ciela;
            BladeStage1MidbossApplyDamage(_controller, _kolar, 120);
            BladeKernelTestAssertTrue(
                _state_before.completed,
                "Ciela-Kolar combo reaches one completion"
            );
            BladeKernelTestAssertEqual(
                array_length(_controller.stage_defeat_queue), 2,
                "one completion queues the two authored participants once"
            );
            BladeKernelTestAssertEqual(
                _controller.economy.score, _score_before + 25000,
                "one completion awards the duo score once"
            );
            BladeKernelTestAssertEqual(
                BladeStage1MidbossApplyDamage(
                    _controller, _ciela_reference, 1
                ).applied,
                0,
                "destroyed combo body cannot award a duplicate completion"
            );
            BladeKernelTestAssertEqual(
                array_length(_controller.stage_defeat_queue), 2,
                "duplicate damage cannot duplicate Stage defeat reports"
            );
            BladeKernelTestAssertTrue(
                instance_exists(_unrelated),
                "combo completion still preserves unrelated route bullets"
            );

            BladeStage1RouteAdvance(_controller);
            BladeKernelTestAssertEqual(
                _controller.route_cue_id, "cue.stage1.forest_resume",
                "Ciela-Kolar completion resumes the second route half"
            );
            BladeKernelTestAssertEqual(
                _controller.stage_executor.current_node_id,
                "stage_node.stage1.second_half_breath",
                "the shared schedule advances beyond the selected duo"
            );
        }
    );
}

// Exercises Kolar's Ciela-Maynii standards, unique combo, and continuation.
function _BladeStage1SelectedRouteTestsKolarCielaMaynii(_state) {
    BladeFirstBeatTestRunCase(
        _state,
        "Kolar route resolves Ciela and Maynii with one river-roots combo",
        function() {
            var _controller = instance_create_layer(
                0, 0, "Instances", o_blade_first_beat_controller
            );
            var _run = _BladeStage1RouteTestsSelect(
                _controller, "ship.kolar"
            );
            BladeStage1RouteInitialize(_controller);
            var _record = { ordinary_count: 0, carrier_count: 0 };
            BladeKernelTestAssertTrue(
                _BladeStage1RouteTestsReachDuo(_controller, _record),
                "Kolar route reaches its authored unchosen pair"
            );
            var _state_before = _controller.midboss_state;
            var _ciela = _state_before.members[0];
            var _maynii = _state_before.members[1];
            BladeKernelTestAssertArrayEqual(
                _run.midboss_ship_ids, ["ship.ciela", "ship.maynii"],
                "Kolar route excludes the selected player from the pair"
            );
            BladeKernelTestAssertEqual(
                _state_before.combo_pattern_id,
                "pattern.stage1.combo.ciela_maynii_river_roots",
                "Kolar route owns the unique river-roots combo identity"
            );
            var _player = instance_create_layer(
                320, 300, "Instances", o_kolar_first_beat_player
            );
            _controller.player_instance = _player;
            _BladeStage1SelectedRouteTestsActivate(_ciela);
            _BladeStage1SelectedRouteTestsActivate(_maynii);
            _ciela.attack_ticks = 57;
            _maynii.attack_ticks = 53;
            BladeStage1MidbossStep(_ciela);
            BladeStage1MidbossStep(_maynii);
            BladeKernelTestAssertEqual(
                _BladeStage1RouteTestsBulletCount(
                    BladeFirstBeatBulletKind.CielaCurrent
                ),
                6,
                "Kolar route retains Ciela's river-current standard"
            );
            BladeKernelTestAssertEqual(
                _BladeStage1RouteTestsBulletCount(
                    BladeFirstBeatBulletKind.MayniiLeaf
                ),
                4,
                "Kolar route retains Maynii's leaf-fan standard"
            );
            BladeStage1MidbossApplyDamage(
                _controller, _ciela, BLADE_STAGE1_MIDBOSS_PERSONAL_HP
            );
            BladeStage1MidbossApplyDamage(
                _controller, _maynii, BLADE_STAGE1_MIDBOSS_PERSONAL_HP
            );
            BladeKernelTestAssertTrue(
                _state_before.combo_active,
                "both personal defeats start the shared combo once"
            );
            for (var _recharge = 0;
                _recharge < BLADE_STAGE1_MIDBOSS_RECHARGE_TICKS;
                ++_recharge) {
                BladeStage1MidbossStep(_ciela);
                BladeStage1MidbossStep(_maynii);
            }
            _ciela.attack_ticks = 75;
            _maynii.attack_ticks = 37;
            BladeStage1MidbossStep(_ciela);
            BladeStage1MidbossStep(_maynii);
            BladeKernelTestAssertEqual(
                _BladeStage1RouteTestsBulletCount(
                    BladeFirstBeatBulletKind.ComboRiverRoots
                ),
                7,
                "Ciela contributes the distinct river half"
            );
            BladeKernelTestAssertEqual(
                _BladeStage1RouteTestsBulletCount(
                    BladeFirstBeatBulletKind.ComboLeafRoots
                ),
                3,
                "Maynii answers with the distinct roots half"
            );
            BladeKernelTestAssertEqual(
                _BladeStage1RouteTestsBulletCount(
                    BladeFirstBeatBulletKind.ComboLeaf
                ) + _BladeStage1RouteTestsBulletCount(
                    BladeFirstBeatBulletKind.ComboCrystal
                ),
                0,
                "Kolar route cannot replay the prior root-ridgeline combo"
            );
            BladeStage1MidbossApplyDamage(
                _controller, _ciela, BLADE_STAGE1_MIDBOSS_COMBO_HP
            );
            BladeKernelTestAssertTrue(
                _state_before.completed,
                "river-roots combo completes exactly once"
            );
            BladeStage1RouteAdvance(_controller);
            BladeKernelTestAssertEqual(
                _controller.route_cue_id, "cue.stage1.forest_resume",
                "Kolar combo resumes the second route half"
            );
        }
    );
}

// Covers explicit abort, non-defeat cleanup, retry identity, and deterministic hashes.
function _BladeStage1SelectedRouteTestsBoundaryAndHashes(_state) {
    BladeFirstBeatTestRunCase(
        _state,
        "selected route aborts without defeat and retries as the same pair",
        function() {
            var _controller = instance_create_layer(
                0, 0, "Instances", o_blade_first_beat_controller
            );
            _BladeStage1RouteTestsSelect(_controller, "ship.maynii");
            BladeStage1RouteInitialize(_controller);
            var _first_record = { ordinary_count: 0, carrier_count: 0 };
            BladeKernelTestAssertTrue(
                _BladeStage1RouteTestsReachDuo(_controller, _first_record),
                "first attempt reaches Ciela and Kolar"
            );
            BladeKernelTestAssertTrue(
                BladeStage1RouteAbort(
                    _controller, BladeCombatTerminalReason.RunReset
                ),
                "active selected route accepts one explicit abort"
            );
            BladeKernelTestAssertEqual(
                _controller.stage_executor.lifecycle,
                BladeStageLifecycle.Aborted,
                "abort owns a non-completion Stage boundary"
            );
            BladeKernelTestAssertEqual(
                array_length(_controller.stage_defeat_queue), 0,
                "administrative cleanup queues no eligible defeats"
            );
            BladeKernelTestAssertFalse(
                BladeStage1RouteAbort(
                    _controller, BladeCombatTerminalReason.RunReset
                ),
                "already-aborted route ignores a duplicate abort"
            );
            BladeFirstBeatCleanupTransientInstances();
            BladeStage1RouteInitialize(_controller);
            var _retry_record = { ordinary_count: 0, carrier_count: 0 };
            BladeKernelTestAssertTrue(
                _BladeStage1RouteTestsReachDuo(_controller, _retry_record),
                "retry reaches the same selected-route pair"
            );
            BladeKernelTestAssertEqual(
                _controller.selected_run.ship_id, "ship.maynii",
                "retry retains the selected ship"
            );
            BladeKernelTestAssertEqual(
                _controller.midboss_state.members[0].content_id, "ship.ciela",
                "retry resolves Ciela in slot A again"
            );
            BladeKernelTestAssertEqual(
                _controller.midboss_state.members[1].content_id, "ship.kolar",
                "retry resolves Kolar in slot B again"
            );
        }
    );

    BladeFirstBeatTestRunCase(
        _state,
        "same selected route repeats command and event hashes",
        function() {
            var _first = _BladeStage1SelectedRouteTestsPrefix("ship.maynii");
            var _second = _BladeStage1SelectedRouteTestsPrefix("ship.maynii");
            var _ciela = _BladeStage1SelectedRouteTestsPrefix("ship.ciela");
            BladeKernelTestAssertEqual(
                _first.executor_hash, _second.executor_hash,
                "same selection, seed, and zero-input commands repeat"
            );
            BladeKernelTestAssertEqual(
                _first.gameplay_hash, _second.gameplay_hash,
                "same selected route repeats the complete gameplay hash"
            );
            BladeKernelTestAssertEqual(
                _first.event_hash, _second.event_hash,
                "same selected route repeats its Stage event hash"
            );
            BladeKernelTestAssertTrue(
                _first.event_count > 0,
                "route event hash represents a nonempty committed stream"
            );
            BladeKernelTestAssertEqual(
                _first.event_count, _second.event_count,
                "equal route prefixes commit the same event count"
            );
            BladeKernelTestAssertNotEqual(
                _first.executor_hash, _ciela.executor_hash,
                "a different selected route has a distinct command state"
            );
        }
    );
}

/// Registers selected-player, alternate-route, retry, and hash coverage.
function BladeStage1SelectedRouteTestsRun(_state) {
    _BladeStage1SelectedRouteTestsMayniiPlayer(_state);
    _BladeStage1SelectedRouteTestsKolarPlayer(_state);
    _BladeStage1SelectedRouteTestsCielaKolar(_state);
    _BladeStage1SelectedRouteTestsKolarCielaMaynii(_state);
    _BladeStage1SelectedRouteTestsBoundaryAndHashes(_state);
    return _state;
}
