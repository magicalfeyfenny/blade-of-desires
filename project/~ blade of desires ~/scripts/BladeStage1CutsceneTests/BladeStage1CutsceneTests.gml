/// Runtime integration tests for Stage 1 cutscene ownership and dialogue waits.

/// Creates one actor-shaped record with the same fields used by live actors.
function _BladeStage1CutsceneTestActor(_x, _y, _targetable = true) {
    return {
        cutscene_actor_id: "",
        x: _x,
        y: _y,
        targetable: _targetable,
        cutscene_controlled: false,
        cutscene_action_id: "",
        cutscene_action_ticks: 0,
        stage_instance_id: "",
    };
}

/// Adds one semantic confirm edge without bypassing the live-input contract.
function _BladeStage1CutsceneTestConfirm() {
    var _input = BladeStage1PauseInputNeutral();
    _input.pressed_actions = BladeInputAction.Confirm;
    return _input;
}

/// Runs the full enter, puppet, dialogue, resume, and finish lifecycle.
function _BladeStage1CutsceneTestLifecycle() {
    var _controller = instance_create_layer(
        0, 0, "Instances", o_blade_first_beat_controller
    );
    try {
        var _actor = _BladeStage1CutsceneTestActor(10, 20);
        BladeStage1CutsceneRegisterActor(
            _controller, _actor, "actor.test.stage1"
        );
        var _sequence = [
            BladeStage1CutsceneMoveActor(
                "actor.test.stage1", 40, 60, 3
            ),
            BladeStage1CutsceneActorAction(
                "actor.test.stage1", "wave", 2
            ),
            BladeStage1CutsceneDialogue(
                "character.test", "TEST", "Waits for the player."
            ),
            BladeStage1CutsceneWait(2),
            BladeStage1CutsceneFinishCommand(),
        ];
        BladeKernelTestAssertTrue(
            BladeStage1CutsceneStart(
                _controller, _sequence, "sequence.test.lifecycle"
            ),
            "cutscene enters from active gameplay"
        );
        BladeKernelTestAssertEqual(
            _controller.cutscene.mode,
            BladeStage1CutsceneMode.Running,
            "cutscene starts in running mode"
        );
        BladeKernelTestAssertTrue(
            BladeStage1CutsceneStageSuspended(_controller),
            "stage suspension is explicit"
        );
        BladeKernelTestAssertFalse(
            BladeStage1PauseCanOpen(_controller),
            "pause remains distinct and unavailable during cutscene"
        );
        BladeKernelTestAssertFalse(
            BladeSurvivalGameplayAdvances(_controller),
            "ordinary gameplay is gated during cutscene"
        );

        _controller.rank_clock_tick = 12;
        with (_controller) event_perform(ev_step, ev_step_normal);
        BladeKernelTestAssertEqual(
            _controller.rank_clock_tick, 12,
            "controller step delegates the active tick to cutscene"
        );
        for (var _move = 1; _move < 3; ++_move) {
            BladeStage1CutsceneAdvance(
                _controller, BladeStage1PauseInputNeutral()
            );
        }
        BladeKernelTestAssertEqual(_actor.x, 40, "puppet reaches target x");
        BladeKernelTestAssertEqual(_actor.y, 60, "puppet reaches target y");
        BladeKernelTestAssertEqual(
            _controller.cutscene.command_index, 1,
            "movement advances exactly one command"
        );

        BladeStage1CutsceneAdvance(
            _controller, BladeStage1PauseInputNeutral()
        );
        BladeKernelTestAssertTrue(
            _actor.cutscene_controlled,
            "declared actor yields normal control"
        );
        BladeKernelTestAssertEqual(
            _controller.cutscene.action_records[0].action_id,
            "wave",
            "actor action is machine-observable"
        );
        BladeStage1CutsceneAdvance(
            _controller, BladeStage1PauseInputNeutral()
        );
        BladeKernelTestAssertEqual(
            _controller.cutscene.command_index, 2,
            "action consumes its declared duration"
        );

        var _dialogue = BladeStage1CutsceneAdvance(
            _controller, BladeStage1PauseInputNeutral()
        );
        BladeKernelTestAssertEqual(
            _dialogue.mode, BladeStage1CutsceneMode.DialogueWaiting,
            "dialogue exposes a separate waiting mode"
        );
        BladeKernelTestAssertTrue(
            _controller.cutscene.dialogue.open,
            "dialogue is visible while waiting"
        );
        var _waiting = BladeStage1CutsceneAdvance(
            _controller, BladeStage1PauseInputNeutral()
        );
        BladeKernelTestAssertEqual(
            _waiting.command_index, 2,
            "neutral input cannot advance visible dialogue"
        );
        BladeStage1CutsceneAdvance(_controller, _BladeStage1CutsceneTestConfirm());
        BladeKernelTestAssertEqual(
            _controller.cutscene.command_index, 3,
            "confirm dismisses only the dialogue command"
        );
        BladeStage1CutsceneAdvance(
            _controller, BladeStage1PauseInputNeutral()
        );
        BladeStage1CutsceneAdvance(
            _controller, BladeStage1PauseInputNeutral()
        );
        var _finished = BladeStage1CutsceneAdvance(
            _controller, BladeStage1PauseInputNeutral()
        );
        BladeKernelTestAssertTrue(_finished.finished, "finish is observable");
        BladeKernelTestAssertFalse(
            BladeStage1CutsceneIsActive(_controller),
            "finish exits cutscene mode"
        );
        BladeKernelTestAssertFalse(
            BladeStage1CutsceneStageSuspended(_controller),
            "finish releases stage suspension"
        );
        BladeKernelTestAssertFalse(
            _actor.cutscene_controlled,
            "finish releases puppet control"
        );
        BladeKernelTestAssertTrue(
            _actor.targetable,
            "finish restores the actor targetability snapshot"
        );
        BladeKernelTestAssertEqual(
            _controller.cutscene.completed_count, 1,
            "sequence completes exactly once"
        );
        BladeKernelTestAssertTrue(
            BladeStage1PauseCanOpen(_controller),
            "pause eligibility resumes after cutscene"
        );
    } finally {
        with (_controller) instance_destroy();
    }
}

/// Proves administrative cleanup cannot award score, Hyper, or defeat rewards.
function _BladeStage1CutsceneTestAdministrativeCleanup() {
    var _controller = instance_create_layer(
        0, 0, "Instances", o_blade_first_beat_controller
    );
    var _ordinary = noone;
    try {
        var _actor = _BladeStage1CutsceneTestActor(16, 24);
        BladeStage1CutsceneRegisterActor(
            _controller, _actor, "actor.test.cleanup"
        );
        _ordinary = instance_create_layer(
            320, 80, "Instances", o_blade_first_beat_enemy
        );
        instance_create_layer(
            320, 120, "Projectiles", o_blade_first_beat_enemy_bullet
        );
        instance_create_layer(
            320, 100, "Instances", o_ciela_first_beat_shot
        );
        instance_create_layer(320, 180, "Items", o_blade_reward_item);
        var _score = _controller.economy.score;
        var _hyper = _controller.economy.hyper_meter;
        BladeStage1CutsceneStart(
            _controller,
            [BladeStage1CutsceneActorAction(
                "actor.test.cleanup", "cleanup_pose", 1
            ), BladeStage1CutsceneFinishCommand()],
            "sequence.test.cleanup"
        );
        BladeKernelTestAssertEqual(
            _controller.cutscene.last_cleanup.ordinary, 1,
            "ordinary enemies are counted before administration"
        );
        BladeKernelTestAssertEqual(
            _controller.cutscene.last_cleanup.bullets, 1,
            "hostile bullets are counted before administration"
        );
        BladeKernelTestAssertEqual(
            _controller.cutscene.last_cleanup.player_shots, 1,
            "player shots are counted before administration"
        );
        BladeKernelTestAssertEqual(
            _controller.cutscene.last_cleanup.rewards, 1,
            "rewards are counted before administration"
        );
        BladeKernelTestAssertEqual(
            instance_number(o_blade_first_beat_enemy), 0,
            "ordinary enemies clear without defeat resolution"
        );
        BladeKernelTestAssertEqual(
            instance_number(o_blade_first_beat_enemy_bullet), 0,
            "hostile bullets clear without point conversion"
        );
        BladeKernelTestAssertEqual(
            instance_number(o_blade_player_shot), 0,
            "player shots clear administratively"
        );
        BladeKernelTestAssertEqual(
            instance_number(o_blade_reward_item), 0,
            "existing rewards do not survive the administrative boundary"
        );
        BladeKernelTestAssertEqual(
            _controller.economy.score, _score,
            "administrative cleanup does not change score"
        );
        BladeKernelTestAssertEqual(
            _controller.economy.hyper_meter, _hyper,
            "administrative cleanup does not change Hyper"
        );
        BladeStage1CutsceneAdvance(
            _controller, BladeStage1PauseInputNeutral()
        );
        BladeKernelTestAssertTrue(
            _actor.cutscene_controlled,
            "cleanup sequence can still acquire its declared actor"
        );
        BladeStage1CutsceneAdvance(
            _controller, BladeStage1PauseInputNeutral()
        );
        BladeKernelTestAssertFalse(
            BladeStage1CutsceneIsActive(_controller),
            "cleanup sequence returns to ordinary mode"
        );
    } finally {
        with (_controller) instance_destroy();
        if (_ordinary != noone && instance_exists(_ordinary)) {
            with (_ordinary) instance_destroy();
        }
    }
}

/// Runs state, ownership, dialogue, cleanup, and malformed-reference checks.
function BladeStage1CutsceneTestsRun(_state) {
    BladeFirstBeatTestRunCase(
        _state,
        "Stage 1 cutscene runs deterministic puppet and dialogue lifecycle",
        _BladeStage1CutsceneTestLifecycle
    );
    BladeFirstBeatTestRunCase(
        _state,
        "Stage 1 cutscene cleanup is administrative and nonrewarding",
        _BladeStage1CutsceneTestAdministrativeCleanup
    );
    BladeKernelTestRunCase(
        _state,
        "Stage 1 cutscene rejects unregistered actor references",
        function() {
            var _controller = {
                state: BladeFirstBeatState.Playing,
                cutscene: BladeStage1CutsceneCreate(),
                cutscene_actor_registry: [],
                pause_menu: BladeStage1PauseCreate(),
            };
            var _context = { controller: _controller };
            BladeKernelTestAssertThrows(
                method(_context, function() {
                    BladeStage1CutsceneStart(
                        self.controller,
                        [BladeStage1CutsceneMoveActor(
                            "actor.missing", 1, 1, 1
                        )],
                        "sequence.test.missing"
                    );
                }),
                "actor is not registered",
                "missing actor fails during preflight"
            );
            BladeKernelTestAssertFalse(
                BladeStage1CutsceneIsActive(_controller),
                "failed preflight leaves state inactive"
            );
        }
    );
}
