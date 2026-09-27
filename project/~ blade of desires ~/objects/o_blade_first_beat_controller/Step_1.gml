/// Sample configured semantic input before any Stage 1 gameplay Step can advance.
pause_action = BladeStage1PauseAction.None;
if (is_struct(frame_pacing_profile)
    && !frame_pacing_profile.finished
    && !BladeReplayPlaybackFinished(frame_pacing_profile.playback)) {
    var _domains = BladeClockDomain.Stage
        | BladeClockDomain.Actor
        | BladeClockDomain.Boss
        | BladeClockDomain.Combat;
    var _recorded_step = BladeReplayPlaybackStep(
        frame_pacing_profile.playback, _domains
    );
    live_input = BladeStage1FramePacingInputSample(
        frame_pacing_profile.input_state,
        _recorded_step.replay_input_snapshot
    );
} else if (is_struct(frame_pacing_profile)
    && !frame_pacing_profile.finished) {
    live_input = {
        move_x: int64(0),
        move_y: int64(0),
        pressed_move_x: 0,
        pressed_move_y: 0,
        held_actions: int64(0),
        pressed_actions: int64(0),
        prompt_device: BladePromptDevice.Unknown,
        gamepad_id: -1,
        has_analog: false,
        analog_x: int64(0),
        analog_y: int64(0),
    };
} else {
    live_input = BladeLiveInputSample(input_config, live_input_state);
}
var _pause_result = BladeStage1PauseAdvance(
    pause_menu,
    live_input,
    BladeStage1PauseCanOpen(id)
);
pause_action = _pause_result.action;
