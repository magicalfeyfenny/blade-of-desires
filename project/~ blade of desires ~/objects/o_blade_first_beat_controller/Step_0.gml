if (state != BladeFirstBeatState.Playing && keyboard_check_pressed(ord("R"))) {
    state = BladeFirstBeatTransition(state, BladeFirstBeatEvent.Retry);
    room_restart();
}
