/// Defines the small controller-owned Stage 1 cutscene command contract.

enum BladeStage1CutsceneMode {
    Inactive = 0,
    Running = 1,
    DialogueWaiting = 2
}

enum BladeStage1CutsceneCommandKind {
    MoveActor = 1,
    ActorAction = 2,
    Wait = 3,
    Dialogue = 4,
    Finish = 5
}

#macro BLADE_STAGE1_CUTSCENE_STATE_VERSION 1

/// Creates one actor movement command measured in fixed Stage ticks.
function BladeStage1CutsceneMoveActor(
    _actor_id, _target_x, _target_y, _duration_ticks
) {
    return {
        kind: BladeStage1CutsceneCommandKind.MoveActor,
        actor_id: _actor_id,
        target_x: _target_x,
        target_y: _target_y,
        duration_ticks: _duration_ticks,
        action_id: "",
        speaker_id: "",
        speaker_name: "",
        text: "",
    };
}

/// Creates one deterministic actor action command.
function BladeStage1CutsceneActorAction(
    _actor_id, _action_id, _duration_ticks
) {
    return {
        kind: BladeStage1CutsceneCommandKind.ActorAction,
        actor_id: _actor_id,
        target_x: 0,
        target_y: 0,
        duration_ticks: _duration_ticks,
        action_id: _action_id,
        speaker_id: "",
        speaker_name: "",
        text: "",
    };
}

/// Creates one fixed-duration sequence hold.
function BladeStage1CutsceneWait(_duration_ticks) {
    return {
        kind: BladeStage1CutsceneCommandKind.Wait,
        actor_id: "",
        target_x: 0,
        target_y: 0,
        duration_ticks: _duration_ticks,
        action_id: "",
        speaker_id: "",
        speaker_name: "",
        text: "",
    };
}

/// Creates one dialogue command that waits for a semantic interaction.
function BladeStage1CutsceneDialogue(
    _speaker_id, _speaker_name, _text
) {
    return {
        kind: BladeStage1CutsceneCommandKind.Dialogue,
        actor_id: "",
        target_x: 0,
        target_y: 0,
        duration_ticks: 1,
        action_id: "",
        speaker_id: _speaker_id,
        speaker_name: _speaker_name,
        text: _text,
    };
}

/// Creates the explicit terminal command for releasing actor control.
function BladeStage1CutsceneFinishCommand() {
    return {
        kind: BladeStage1CutsceneCommandKind.Finish,
        actor_id: "",
        target_x: 0,
        target_y: 0,
        duration_ticks: 1,
        action_id: "",
        speaker_id: "",
        speaker_name: "",
        text: "",
    };
}

/// Returns the first player-visible production slice at the World Tree.
function BladeStage1CutsceneAsahiIntro() {
    return [
        BladeStage1CutsceneMoveActor(
            "actor.stage1.asahi", 320, 72, 45
        ),
        BladeStage1CutsceneActorAction(
            "actor.stage1.asahi", "solar_arrival", 30
        ),
        BladeStage1CutsceneDialogue(
            "character.asahi",
            "ASAHI",
            "The World Tree shines brighter than the forest remembers."
                + "\nCome on, Sunny Fae. Show me your resolve."
        ),
        BladeStage1CutsceneFinishCommand(),
    ];
}

/// Reads one field from a test struct or a live instance.
function _BladeStage1CutsceneField(_value, _name) {
    if (is_struct(_value)) {
        return variable_struct_exists(_value, _name)
            ? variable_struct_get(_value, _name)
            : undefined;
    }
    if (!is_numeric(_value) || _value < 0 || !instance_exists(_value)) {
        return undefined;
    }
    return variable_instance_exists(_value, _name)
        ? variable_instance_get(_value, _name)
        : undefined;
}

/// Writes one field while preserving the struct/instance boundary.
function _BladeStage1CutsceneSetField(_value, _name, _new_value) {
    if (is_struct(_value)) {
        variable_struct_set(_value, _name, _new_value);
        return true;
    }
    if (!is_numeric(_value) || _value < 0 || !instance_exists(_value)
        || !variable_instance_exists(_value, _name)) return false;
    variable_instance_set(_value, _name, _new_value);
    return true;
}

/// Tests whether an actor record still refers to a live object.
function _BladeStage1CutsceneActorExists(_actor) {
    if (is_struct(_actor)) return true;
    return is_numeric(_actor) && _actor >= 0 && instance_exists(_actor);
}

/// Requires the controller to own a versioned cutscene state record.
function _BladeStage1CutsceneState(_controller) {
    var _state = _BladeStage1CutsceneField(_controller, "cutscene");
    if (!is_struct(_state)
        || !variable_struct_exists(
            _state, "__blade_stage1_cutscene_version"
        )
        || _state.__blade_stage1_cutscene_version
            != BLADE_STAGE1_CUTSCENE_STATE_VERSION) {
        throw("BladeStage1Cutscene: controller state is incomplete");
    }
    return _state;
}

/// Validates one nonempty stable machine identity.
function _BladeStage1CutsceneRequireId(_value, _field_name) {
    if (!is_string(_value) || string_length(_value) == 0) {
        throw(
            "BladeStage1Cutscene: " + string(_field_name)
                + " must be a nonempty stable ID"
        );
    }
}

/// Validates one positive integral Stage duration.
function _BladeStage1CutsceneRequireDuration(_value) {
    if (!is_numeric(_value)
        || is_nan(_value)
        || is_infinity(_value)
        || _value < 1
        || _value != floor(_value)) {
        throw("BladeStage1Cutscene: duration must be a positive integer");
    }
}

/// Validates one finite actor target coordinate.
function _BladeStage1CutsceneRequireCoordinate(_value, _field_name) {
    if (!is_numeric(_value) || is_nan(_value) || is_infinity(_value)) {
        throw(
            "BladeStage1Cutscene: " + string(_field_name)
                + " must be finite"
        );
    }
}

/// Validates the command shape before it can affect a running controller.
function _BladeStage1CutsceneValidateCommand(_command) {
    if (!is_struct(_command)
        || !variable_struct_exists(_command, "kind")) {
        throw("BladeStage1Cutscene: command is incomplete");
    }
    switch (_command.kind) {
        case BladeStage1CutsceneCommandKind.MoveActor:
            _BladeStage1CutsceneRequireId(_command.actor_id, "actor_id");
            _BladeStage1CutsceneRequireCoordinate(
                _command.target_x, "target_x"
            );
            _BladeStage1CutsceneRequireCoordinate(
                _command.target_y, "target_y"
            );
            _BladeStage1CutsceneRequireDuration(_command.duration_ticks);
            break;
        case BladeStage1CutsceneCommandKind.ActorAction:
            _BladeStage1CutsceneRequireId(_command.actor_id, "actor_id");
            _BladeStage1CutsceneRequireId(_command.action_id, "action_id");
            _BladeStage1CutsceneRequireDuration(_command.duration_ticks);
            break;
        case BladeStage1CutsceneCommandKind.Wait:
            _BladeStage1CutsceneRequireDuration(_command.duration_ticks);
            break;
        case BladeStage1CutsceneCommandKind.Dialogue:
            _BladeStage1CutsceneRequireId(_command.speaker_id, "speaker_id");
            _BladeStage1CutsceneRequireId(
                _command.speaker_name, "speaker_name"
            );
            if (!is_string(_command.text) || string_length(_command.text) == 0) {
                throw("BladeStage1Cutscene: dialogue text must be nonempty");
            }
            break;
        case BladeStage1CutsceneCommandKind.Finish:
            break;
        default:
            throw(
                "BladeStage1Cutscene: unknown command kind "
                    + string(_command.kind)
            );
    }
}

/// Copies only known command fields so a caller cannot mutate running state by alias.
function _BladeStage1CutsceneCopySequence(_sequence) {
    if (!is_array(_sequence) || array_length(_sequence) == 0) {
        throw("BladeStage1Cutscene: sequence must contain commands");
    }
    var _copy = [];
    for (var _index = 0; _index < array_length(_sequence); ++_index) {
        var _command = _sequence[_index];
        _BladeStage1CutsceneValidateCommand(_command);
        switch (_command.kind) {
            case BladeStage1CutsceneCommandKind.MoveActor:
                array_push(
                    _copy,
                    BladeStage1CutsceneMoveActor(
                        _command.actor_id, _command.target_x,
                        _command.target_y, _command.duration_ticks
                    )
                );
                break;
            case BladeStage1CutsceneCommandKind.ActorAction:
                array_push(
                    _copy,
                    BladeStage1CutsceneActorAction(
                        _command.actor_id, _command.action_id,
                        _command.duration_ticks
                    )
                );
                break;
            case BladeStage1CutsceneCommandKind.Wait:
                array_push(
                    _copy,
                    BladeStage1CutsceneWait(_command.duration_ticks)
                );
                break;
            case BladeStage1CutsceneCommandKind.Dialogue:
                array_push(
                    _copy,
                    BladeStage1CutsceneDialogue(
                        _command.speaker_id, _command.speaker_name,
                        _command.text
                    )
                );
                break;
            case BladeStage1CutsceneCommandKind.Finish:
                array_push(_copy, BladeStage1CutsceneFinishCommand());
                break;
        }
    }
    return _copy;
}

/// Creates the controller state used by production and machine tests.
function BladeStage1CutsceneCreate(_sequence = undefined) {
    var _commands = [];
    if (!is_undefined(_sequence)) {
        _commands = _BladeStage1CutsceneCopySequence(_sequence);
    }
    return {
        __blade_stage1_cutscene_version: BLADE_STAGE1_CUTSCENE_STATE_VERSION,
        mode: BladeStage1CutsceneMode.Inactive,
        sequence: _commands,
        command_index: 0,
        command_started: false,
        command_ticks: 0,
        command_start_x: 0,
        command_start_y: 0,
        dialogue: {
            open: false,
            speaker_id: "",
            speaker_name: "",
            text: "",
        },
        last_dialogue: {
            speaker_id: "",
            speaker_name: "",
            text: "",
        },
        controlled_actors: [],
        action_records: [],
        started_count: 0,
        completed_count: 0,
        aborted_count: 0,
        dialogue_count: 0,
        dialogue_dismiss_count: 0,
        stage_suspended: false,
        last_sequence_id: "",
        last_cleanup: {
            ordinary: 0,
            bullets: 0,
            player_shots: 0,
            rewards: 0,
        },
        last_error: "",
    };
}

/// Reports whether running or dialogue waiting owns the Stage tick.
function BladeStage1CutsceneIsActive(_controller) {
    var _state = _BladeStage1CutsceneField(_controller, "cutscene");
    return is_struct(_state)
        && variable_struct_exists(_state, "mode")
        && _state.mode != BladeStage1CutsceneMode.Inactive;
}

/// Reports the separate stage suspension state for tests and HUDs.
function BladeStage1CutsceneStageSuspended(_controller) {
    var _state = _BladeStage1CutsceneField(_controller, "cutscene");
    return is_struct(_state)
        && variable_struct_exists(_state, "stage_suspended")
        && _state.stage_suspended;
}

/// Provides the explicit gameplay gate without conflating it with pause state.
function BladeStage1CutsceneGameplayAllowed(_controller) {
    return !BladeStage1CutsceneIsActive(_controller);
}

/// Registers one declared actor under one stable ID, rejecting collisions.
function BladeStage1CutsceneRegisterActor(
    _controller, _actor, _actor_id = undefined
) {
    _BladeStage1CutsceneState(_controller);
    if (!_BladeStage1CutsceneActorExists(_actor)) {
        throw("BladeStage1Cutscene: cannot register a missing actor");
    }
    var _resolved_id = is_undefined(_actor_id)
        ? _BladeStage1CutsceneField(_actor, "cutscene_actor_id")
        : _actor_id;
    _BladeStage1CutsceneRequireId(_resolved_id, "actor_id");
    _BladeStage1CutsceneSetField(
        _actor, "cutscene_actor_id", _resolved_id
    );
    var _registry = _BladeStage1CutsceneField(
        _controller, "cutscene_actor_registry"
    );
    if (!is_array(_registry)) {
        throw("BladeStage1Cutscene: actor registry is incomplete");
    }
    for (var _index = 0; _index < array_length(_registry); ++_index) {
        var _candidate = _registry[_index];
        if (!_BladeStage1CutsceneActorExists(_candidate)) continue;
        if (_BladeStage1CutsceneField(_candidate, "cutscene_actor_id")
            != _resolved_id) continue;
        if (_candidate != _actor) {
            throw(
                "BladeStage1Cutscene: duplicate actor ID "
                    + string(_resolved_id)
            );
        }
        return _actor;
    }
    array_push(_registry, _actor);
    _BladeStage1CutsceneSetField(
        _controller, "cutscene_actor_registry", _registry
    );
    return _actor;
}

/// Resolves one actor from the controller-owned registry.
function BladeStage1CutsceneFindActor(_controller, _actor_id) {
    var _registry = _BladeStage1CutsceneField(
        _controller, "cutscene_actor_registry"
    );
    if (!is_array(_registry)) return noone;
    for (var _index = 0; _index < array_length(_registry); ++_index) {
        var _actor = _registry[_index];
        if (_BladeStage1CutsceneActorExists(_actor)
            && _BladeStage1CutsceneField(_actor, "cutscene_actor_id")
                == _actor_id) {
            return _actor;
        }
    }
    return noone;
}
