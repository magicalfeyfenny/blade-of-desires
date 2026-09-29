/// Sample configured semantic input before any Stage 1 gameplay Step can advance.
application_lifecycle_frame_blocked = false;
var _application = BladeApplicationLifecyclePoll();
if (!_application.gameplay_allowed
    || _application.epoch != application_lifecycle_epoch) {
    application_lifecycle_epoch = _application.epoch;
    BladeLiveInputStateReset(live_input_state);
    live_input = BladeStage1PauseInputNeutral();
    application_lifecycle_frame_blocked = true;
    pause_action = BladeStage1PauseAction.None;
    exit;
}
pause_action = BladeStage1PauseAction.None;
live_input = BladeLiveInputSample(input_config, live_input_state);
var _pause_result = BladeStage1PauseAdvance(
    pause_menu,
    live_input,
    BladeStage1PauseCanOpen(id)
);
pause_action = _pause_result.action;
