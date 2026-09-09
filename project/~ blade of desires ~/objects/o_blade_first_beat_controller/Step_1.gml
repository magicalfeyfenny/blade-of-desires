/// Sample configured semantic input before any Stage 1 gameplay Step can advance.
pause_action = BladeStage1PauseAction.None;
live_input = BladeLiveInputSample(input_config);
var _pause_result = BladeStage1PauseAdvance(
    pause_menu,
    live_input,
    BladeStage1PauseCanOpen(id)
);
pause_action = _pause_result.action;
