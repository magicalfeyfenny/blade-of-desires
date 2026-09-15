/// Runs one bounded Stage 1 sequence and owns temporary combat control.

/// Clears ordinary targets, bullets, player shots, and rewards administratively.
function _BladeStage1CutsceneAdministrativeCleanup() {
    var _result = {
        ordinary: instance_number(o_blade_first_beat_enemy),
        bullets: instance_number(o_blade_first_beat_enemy_bullet),
        player_shots: instance_number(o_blade_player_shot),
        rewards: instance_number(o_blade_reward_item),
    };
    with (o_blade_first_beat_enemy) instance_destroy();
    with (o_blade_first_beat_enemy_bullet) instance_destroy();
    with (o_blade_player_shot) instance_destroy();
    with (o_blade_reward_item) instance_destroy();
    return _result;
}

/// Captures only the fields temporary cutscene ownership may change.
function _BladeStage1CutsceneSnapshotActor(_actor) {
    var _targetable = _BladeStage1CutsceneField(_actor, "targetable");
    var _controlled = _BladeStage1CutsceneField(
        _actor, "cutscene_controlled"
    );
    var _action_id = _BladeStage1CutsceneField(
        _actor, "cutscene_action_id"
    );
    var _action_ticks = _BladeStage1CutsceneField(
        _actor, "cutscene_action_ticks"
    );
    return {
        actor: _actor,
        actor_id: _BladeStage1CutsceneField(_actor, "cutscene_actor_id"),
        targetable: is_undefined(_targetable) ? false : _targetable,
        cutscene_controlled: is_undefined(_controlled) ? false : _controlled,
        cutscene_action_id: is_undefined(_action_id) ? "" : _action_id,
        cutscene_action_ticks: is_undefined(_action_ticks)
            ? 0
            : _action_ticks,
    };
}

/// Takes ownership of one actor and cancels only its authored bullets.
function _BladeStage1CutsceneAcquireActor(_controller, _actor_id) {
    var _state = _BladeStage1CutsceneState(_controller);
    var _actor = BladeStage1CutsceneFindActor(_controller, _actor_id);
    if (!_BladeStage1CutsceneActorExists(_actor)) return false;
    for (var _index = 0;
        _index < array_length(_state.controlled_actors);
        ++_index) {
        if (_state.controlled_actors[_index].actor_id == _actor_id) {
            return true;
        }
    }
    var _stage_instance_id = _BladeStage1CutsceneField(
        _actor, "stage_instance_id"
    );
    if (!is_struct(_actor)
        && is_string(_stage_instance_id)
        && string_length(_stage_instance_id) > 0) {
        BladeFirstBeatClearOwnedBullets(_stage_instance_id);
    }
    array_push(
        _state.controlled_actors,
        _BladeStage1CutsceneSnapshotActor(_actor)
    );
    _BladeStage1CutsceneSetField(_actor, "cutscene_controlled", true);
    _BladeStage1CutsceneSetField(_actor, "targetable", false);
    _BladeStage1CutsceneSetField(_actor, "cutscene_action_id", "");
    _BladeStage1CutsceneSetField(_actor, "cutscene_action_ticks", 0);
    return true;
}

/// Restores every actor snapshot and removes all temporary action state.
function _BladeStage1CutsceneReleaseActors(_state) {
    for (var _index = 0;
        _index < array_length(_state.controlled_actors);
        ++_index) {
        var _snapshot = _state.controlled_actors[_index];
        var _actor = _snapshot.actor;
        if (!_BladeStage1CutsceneActorExists(_actor)) continue;
        _BladeStage1CutsceneSetField(
            _actor, "targetable", _snapshot.targetable
        );
        _BladeStage1CutsceneSetField(
            _actor, "cutscene_controlled", _snapshot.cutscene_controlled
        );
        _BladeStage1CutsceneSetField(
            _actor, "cutscene_action_id", _snapshot.cutscene_action_id
        );
        _BladeStage1CutsceneSetField(
            _actor, "cutscene_action_ticks", _snapshot.cutscene_action_ticks
        );
    }
    _state.controlled_actors = [];
}

/// Builds the machine-observable result after one Stage tick.
function _BladeStage1CutsceneResult(
    _state, _progressed = false, _dialogue_closed = false,
    _finished = false, _aborted = false
) {
    return {
        mode: _state.mode,
        command_index: _state.command_index,
        stage_suspended: _state.stage_suspended,
        progressed: _progressed,
        dialogue_open: _state.dialogue.open,
        dialogue_closed: _dialogue_closed,
        finished: _finished,
        aborted: _aborted,
    };
}

/// Releases actor control and resumes the existing route on the next tick.
function BladeStage1CutsceneFinish(_controller) {
    var _state = _BladeStage1CutsceneState(_controller);
    _BladeStage1CutsceneReleaseActors(_state);
    _state.mode = BladeStage1CutsceneMode.Inactive;
    _state.command_index = array_length(_state.sequence);
    _state.command_started = false;
    _state.command_ticks = 0;
    _state.dialogue.open = false;
    _state.stage_suspended = false;
    _state.completed_count += 1;
    return true;
}

/// Aborts safely if a declared actor disappears during the sequence.
function BladeStage1CutsceneAbort(_controller, _reason) {
    var _state = _BladeStage1CutsceneState(_controller);
    _BladeStage1CutsceneReleaseActors(_state);
    _state.mode = BladeStage1CutsceneMode.Inactive;
    _state.command_index = array_length(_state.sequence);
    _state.command_started = false;
    _state.command_ticks = 0;
    _state.dialogue.open = false;
    _state.stage_suspended = false;
    _state.aborted_count += 1;
    _state.last_error = string(_reason);
    return false;
}

/// Starts only after command validation and all actor references preflight.
function BladeStage1CutsceneStart(
    _controller, _sequence, _sequence_id = "stage1.cutscene"
) {
    var _state = _BladeStage1CutsceneState(_controller);
    if (BladeStage1CutsceneIsActive(_controller)) return false;
    var _controller_state = _BladeStage1CutsceneField(_controller, "state");
    if (!is_undefined(_controller_state)
        && _controller_state != BladeFirstBeatState.Playing) return false;
    var _pause_menu = _BladeStage1CutsceneField(_controller, "pause_menu");
    if (is_struct(_pause_menu)
        && variable_struct_exists(_pause_menu, "open")
        && _pause_menu.open) return false;
    _BladeStage1CutsceneRequireId(_sequence_id, "sequence_id");
    var _commands = _BladeStage1CutsceneCopySequence(_sequence);
    for (var _index = 0; _index < array_length(_commands); ++_index) {
        var _command = _commands[_index];
        if (_command.kind != BladeStage1CutsceneCommandKind.MoveActor
            && _command.kind != BladeStage1CutsceneCommandKind.ActorAction) {
            continue;
        }
        if (!_BladeStage1CutsceneActorExists(
            BladeStage1CutsceneFindActor(_controller, _command.actor_id)
        )) {
            throw(
                "BladeStage1Cutscene: actor is not registered: "
                    + string(_command.actor_id)
            );
        }
    }

    _state.last_cleanup = _BladeStage1CutsceneAdministrativeCleanup();
    _state.sequence = _commands;
    _state.mode = BladeStage1CutsceneMode.Running;
    _state.command_index = 0;
    _state.command_started = false;
    _state.command_ticks = 0;
    _state.dialogue.open = false;
    _state.dialogue.speaker_id = "";
    _state.dialogue.speaker_name = "";
    _state.dialogue.text = "";
    _state.controlled_actors = [];
    _state.action_records = [];
    _state.stage_suspended = true;
    _state.last_sequence_id = _sequence_id;
    _state.last_error = "";
    _state.started_count += 1;
    return true;
}

/// Advances exactly one command, or waits for dialogue confirmation/cancel.
function BladeStage1CutsceneAdvance(_controller, _input) {
    var _state = _BladeStage1CutsceneState(_controller);
    if (_state.mode == BladeStage1CutsceneMode.Inactive) {
        return _BladeStage1CutsceneResult(_state);
    }
    if (_state.mode == BladeStage1CutsceneMode.DialogueWaiting) {
        if (BladeLiveInputActionPressed(_input, BladeInputAction.Confirm)
            || BladeLiveInputActionPressed(_input, BladeInputAction.Cancel)) {
            _state.dialogue.open = false;
            _state.mode = BladeStage1CutsceneMode.Running;
            _state.command_index += 1;
            _state.command_started = false;
            _state.command_ticks = 0;
            _state.dialogue_dismiss_count += 1;
            return _BladeStage1CutsceneResult(_state, true, true);
        }
        return _BladeStage1CutsceneResult(_state);
    }
    if (_state.command_index >= array_length(_state.sequence)) {
        BladeStage1CutsceneFinish(_controller);
        return _BladeStage1CutsceneResult(_state, true, false, true);
    }

    var _command = _state.sequence[_state.command_index];
    switch (_command.kind) {
        case BladeStage1CutsceneCommandKind.MoveActor:
            var _move_actor = BladeStage1CutsceneFindActor(
                _controller, _command.actor_id
            );
            if (!_BladeStage1CutsceneActorExists(_move_actor)) {
                BladeStage1CutsceneAbort(
                    _controller, "actor disappeared: " + _command.actor_id
                );
                return _BladeStage1CutsceneResult(
                    _state, false, false, false, true
                );
            }
            if (!_state.command_started) {
                if (!_BladeStage1CutsceneAcquireActor(
                    _controller, _command.actor_id
                )) {
                    BladeStage1CutsceneAbort(
                        _controller, "actor could not be acquired: "
                            + _command.actor_id
                    );
                    return _BladeStage1CutsceneResult(
                        _state, false, false, false, true
                    );
                }
                _state.command_started = true;
                _state.command_ticks = 0;
                _state.command_start_x = _BladeStage1CutsceneField(
                    _move_actor, "x"
                );
                _state.command_start_y = _BladeStage1CutsceneField(
                    _move_actor, "y"
                );
            }
            if (!is_numeric(_state.command_start_x)
                || !is_numeric(_state.command_start_y)) {
                BladeStage1CutsceneAbort(
                    _controller, "actor has no finite position: "
                        + _command.actor_id
                );
                return _BladeStage1CutsceneResult(
                    _state, false, false, false, true
                );
            }
            _state.command_ticks += 1;
            var _ratio = min(
                1, _state.command_ticks / _command.duration_ticks
            );
            _BladeStage1CutsceneSetField(
                _move_actor,
                "x",
                _state.command_start_x
                    + (_command.target_x - _state.command_start_x) * _ratio
            );
            _BladeStage1CutsceneSetField(
                _move_actor,
                "y",
                _state.command_start_y
                    + (_command.target_y - _state.command_start_y) * _ratio
            );
            if (_state.command_ticks >= _command.duration_ticks) {
                _state.command_index += 1;
                _state.command_started = false;
                _state.command_ticks = 0;
            }
            return _BladeStage1CutsceneResult(_state, true);

        case BladeStage1CutsceneCommandKind.ActorAction:
            var _action_actor = BladeStage1CutsceneFindActor(
                _controller, _command.actor_id
            );
            if (!_BladeStage1CutsceneActorExists(_action_actor)) {
                BladeStage1CutsceneAbort(
                    _controller, "actor disappeared: " + _command.actor_id
                );
                return _BladeStage1CutsceneResult(
                    _state, false, false, false, true
                );
            }
            if (!_state.command_started) {
                if (!_BladeStage1CutsceneAcquireActor(
                    _controller, _command.actor_id
                )) {
                    BladeStage1CutsceneAbort(
                        _controller, "actor could not be acquired: "
                            + _command.actor_id
                    );
                    return _BladeStage1CutsceneResult(
                        _state, false, false, false, true
                    );
                }
                _state.command_started = true;
                _state.command_ticks = _command.duration_ticks;
                _BladeStage1CutsceneSetField(
                    _action_actor, "cutscene_action_id", _command.action_id
                );
                _BladeStage1CutsceneSetField(
                    _action_actor,
                    "cutscene_action_ticks",
                    _command.duration_ticks
                );
                array_push(
                    _state.action_records,
                    {
                        actor_id: _command.actor_id,
                        action_id: _command.action_id,
                        duration_ticks: _command.duration_ticks,
                    }
                );
            }
            _state.command_ticks = max(0, _state.command_ticks - 1);
            _BladeStage1CutsceneSetField(
                _action_actor, "cutscene_action_ticks", _state.command_ticks
            );
            if (_state.command_ticks == 0) {
                _BladeStage1CutsceneSetField(
                    _action_actor, "cutscene_action_id", ""
                );
                _state.command_index += 1;
                _state.command_started = false;
            }
            return _BladeStage1CutsceneResult(_state, true);

        case BladeStage1CutsceneCommandKind.Wait:
            if (!_state.command_started) {
                _state.command_started = true;
                _state.command_ticks = _command.duration_ticks;
            }
            _state.command_ticks = max(0, _state.command_ticks - 1);
            if (_state.command_ticks == 0) {
                _state.command_index += 1;
                _state.command_started = false;
            }
            return _BladeStage1CutsceneResult(_state, true);

        case BladeStage1CutsceneCommandKind.Dialogue:
            if (!_state.command_started) {
                _state.command_started = true;
                _state.mode = BladeStage1CutsceneMode.DialogueWaiting;
                _state.dialogue.open = true;
                _state.dialogue.speaker_id = _command.speaker_id;
                _state.dialogue.speaker_name = _command.speaker_name;
                _state.dialogue.text = _command.text;
                _state.last_dialogue.speaker_id = _command.speaker_id;
                _state.last_dialogue.speaker_name = _command.speaker_name;
                _state.last_dialogue.text = _command.text;
                _state.dialogue_count += 1;
                return _BladeStage1CutsceneResult(_state, true);
            }
            return _BladeStage1CutsceneResult(_state);

        case BladeStage1CutsceneCommandKind.Finish:
            BladeStage1CutsceneFinish(_controller);
            return _BladeStage1CutsceneResult(_state, true, false, true);
    }
    BladeStage1CutsceneAbort(_controller, "unreachable command");
    return _BladeStage1CutsceneResult(_state, false, false, false, true);
}

/// Draws actor-action rings and the readable interaction-gated dialogue panel.
function BladeStage1CutsceneDraw(_state, _ui, _config) {
    if (!is_struct(_state)
        || !variable_struct_exists(_state, "mode")
        || _state.mode == BladeStage1CutsceneMode.Inactive) return;
    draw_set_alpha(0.35);
    draw_set_color(make_color_rgb(255, 226, 122));
    for (var _index = 0;
        _index < array_length(_state.controlled_actors);
        ++_index) {
        var _actor = _state.controlled_actors[_index].actor;
        if (!_BladeStage1CutsceneActorExists(_actor)) continue;
        var _x = _BladeStage1CutsceneField(_actor, "x");
        var _y = _BladeStage1CutsceneField(_actor, "y");
        if (is_numeric(_x) && is_numeric(_y)) {
            draw_circle(_x, _y, 29, false);
            draw_circle(_x, _y, 34, false);
        }
    }
    draw_set_alpha(1);
    if (!_state.dialogue.open) return;
    draw_set_alpha(0.82);
    draw_set_color(c_black);
    draw_rectangle(0, 0, 639, 359, true);
    draw_set_alpha(1);
    if (is_struct(_ui)) {
        BladeFrontendUiDrawPanel(_ui, true, 56, 210, 528, 112, 0.96);
    } else {
        draw_set_alpha(0.94);
        draw_set_color(make_color_rgb(12, 34, 38));
        draw_rectangle(56, 210, 584, 322, true);
        draw_set_alpha(1);
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(make_color_rgb(255, 232, 142));
    draw_text(76, 224, _state.dialogue.speaker_name);
    draw_set_color(c_white);
    draw_text_ext(76, 248, _state.dialogue.text, 4, 490);
    draw_set_color(make_color_rgb(190, 231, 220));
    draw_text(76, 300, "CONFIRM / CANCEL  DISMISS");
    draw_set_color(c_white);
    draw_set_alpha(1);
}
