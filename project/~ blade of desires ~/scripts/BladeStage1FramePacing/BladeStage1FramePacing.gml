/// @description Measurement-only replay driver and bounded Stage 1 frame summary.

#macro BLADE_STAGE1_FRAME_PACING_FRAME_BUDGET_US 16667
#macro BLADE_STAGE1_FRAME_PACING_WARMUP_FRAMES 120
#macro BLADE_STAGE1_FRAME_PACING_BUCKET_WIDTH_US 1000
#macro BLADE_STAGE1_FRAME_PACING_BUCKET_COUNT 1001
#macro BLADE_STAGE1_FRAME_PACING_INPUT_TICKS 1002

/// Adds the selected difficulty to the current route's canonical content IDs.
function _BladeStage1FramePacingKnownContent(_content_id) {
    return BladeStage1RouteKnownContent(_content_id)
        || _content_id == BLADE_DIFFICULTY_NORMAL_ID;
}

/// Keeps benchmark recordings inside this process rather than the user save area.
function _BladeStage1FramePacingStorageList() {
    return {
        ok: true,
        paths: variable_struct_get_names(self.files),
        code: "replay.catalog.listed",
    };
}

function _BladeStage1FramePacingStorageRead(_path) {
    if (!variable_struct_exists(self.files, _path)) {
        return { ok: false, text: "", code: "replay.catalog.missing" };
    }
    return {
        ok: true,
        text: variable_struct_get(self.files, _path),
        code: "replay.catalog.read",
    };
}

function _BladeStage1FramePacingStorageWrite(_path, _text) {
    variable_struct_set(self.files, _path, _text);
    return { ok: true, code: "replay.catalog.saved" };
}

function _BladeStage1FramePacingStorageCreate() {
    var _context = { files: {} };
    return {
        list: method(_context, _BladeStage1FramePacingStorageList),
        read_text: method(_context, _BladeStage1FramePacingStorageRead),
        write_text: method(_context, _BladeStage1FramePacingStorageWrite),
    };
}

/// Creates a small histogram that keeps full-run tail measurements bounded.
function BladeStage1FramePacingCreate() {
    return {
        __blade_stage1_frame_pacing_version: 1,
        warmup_frames: BLADE_STAGE1_FRAME_PACING_WARMUP_FRAMES,
        frame_budget_us: BLADE_STAGE1_FRAME_PACING_FRAME_BUDGET_US,
        frames_seen: 0,
        sample_count: 0,
        frame_time_bins: array_create(
            BLADE_STAGE1_FRAME_PACING_BUCKET_COUNT, 0
        ),
        sum_frame_time_us: 0,
        max_frame_time_us: 0,
        over_budget_frames: 0,
        peak_enemies: 0,
        peak_hostile_bullets: 0,
        peak_player_shots: 0,
    };
}

function _BladeStage1FramePacingRequire(_profile) {
    if (!is_struct(_profile)
        || !variable_struct_exists(
            _profile, "__blade_stage1_frame_pacing_version"
        )
        || _profile.__blade_stage1_frame_pacing_version != 1
        || !variable_struct_exists(_profile, "frame_time_bins")
        || !is_array(_profile.frame_time_bins)
        || array_length(_profile.frame_time_bins)
            != BLADE_STAGE1_FRAME_PACING_BUCKET_COUNT) {
        throw("BladeStage1FramePacing: profile is incomplete");
    }
}

/// Adds one frame interval after the fixed startup warmup.
function BladeStage1FramePacingRecord(
    _profile,
    _frame_time_us,
    _enemy_count = 0,
    _hostile_bullet_count = 0,
    _player_shot_count = 0
) {
    _BladeStage1FramePacingRequire(_profile);
    _profile.frames_seen += 1;
    if (_profile.frames_seen <= _profile.warmup_frames) return false;

    var _duration_us = max(0, floor(_frame_time_us));
    var _bucket = clamp(
        floor(_duration_us / BLADE_STAGE1_FRAME_PACING_BUCKET_WIDTH_US),
        0,
        BLADE_STAGE1_FRAME_PACING_BUCKET_COUNT - 1
    );
    _profile.frame_time_bins[_bucket] += 1;
    _profile.sample_count += 1;
    _profile.sum_frame_time_us += _duration_us;
    _profile.max_frame_time_us = max(
        _profile.max_frame_time_us, _duration_us
    );
    if (_duration_us > _profile.frame_budget_us) {
        _profile.over_budget_frames += 1;
    }
    _profile.peak_enemies = max(_profile.peak_enemies, _enemy_count);
    _profile.peak_hostile_bullets = max(
        _profile.peak_hostile_bullets, _hostile_bullet_count
    );
    _profile.peak_player_shots = max(
        _profile.peak_player_shots, _player_shot_count
    );
    return true;
}

/// Returns the closed 1 ms bucket containing a requested percentile.
function _BladeStage1FramePacingPercentile(_profile, _fraction) {
    if (_profile.sample_count == 0) {
        return { lower_us: 0, upper_us: 0 };
    }
    var _target_rank = max(1, ceil(_profile.sample_count * _fraction));
    var _seen = 0;
    for (var _index = 0;
        _index < array_length(_profile.frame_time_bins);
        ++_index) {
        _seen += _profile.frame_time_bins[_index];
        if (_seen >= _target_rank) {
            return {
                lower_us: _index * BLADE_STAGE1_FRAME_PACING_BUCKET_WIDTH_US,
                upper_us: (_index + 1)
                    * BLADE_STAGE1_FRAME_PACING_BUCKET_WIDTH_US,
            };
        }
    }
    throw("BladeStage1FramePacing: histogram does not cover its samples");
}

/// Reports reproducible frame-time percentiles and workload pressure counts.
function BladeStage1FramePacingSnapshot(_profile) {
    _BladeStage1FramePacingRequire(_profile);
    var _p50 = _BladeStage1FramePacingPercentile(_profile, 0.50);
    var _p95 = _BladeStage1FramePacingPercentile(_profile, 0.95);
    var _p99 = _BladeStage1FramePacingPercentile(_profile, 0.99);
    return {
        frames_seen: _profile.frames_seen,
        warmup_frames: _profile.warmup_frames,
        sample_count: _profile.sample_count,
        frame_budget_us: _profile.frame_budget_us,
        mean_frame_time_us: _profile.sample_count == 0
            ? 0
            : _profile.sum_frame_time_us / _profile.sample_count,
        p50_frame_time_us: _p50,
        p95_frame_time_us: _p95,
        p99_frame_time_us: _p99,
        max_frame_time_us: _profile.max_frame_time_us,
        over_budget_frames: _profile.over_budget_frames,
        over_budget_percent: _profile.sample_count == 0
            ? 0
            : 100 * _profile.over_budget_frames / _profile.sample_count,
        peak_enemies: _profile.peak_enemies,
        peak_hostile_bullets: _profile.peak_hostile_bullets,
        peak_player_shots: _profile.peak_player_shots,
    };
}

/// Rebuilds the live-input shape from one recorded snapshot without device reads.
function BladeStage1FramePacingInputSample(_state, _snapshot) {
    _BladeLiveInputStateRequire(_state);
    var _recorded = BladeInputSnapshotRead(_snapshot);
    var _direction_x = _BladeLiveInputDirection(_recorded.move_x);
    var _direction_y = _BladeLiveInputDirection(_recorded.move_y);
    var _pressed_move_x = _state.has_sample
        && _direction_x != _BladeLiveInputDirection(_state.last_move_x)
        ? _direction_x
        : (!_state.has_sample ? _direction_x : 0);
    var _pressed_move_y = _state.has_sample
        && _direction_y != _BladeLiveInputDirection(_state.last_move_y)
        ? _direction_y
        : (!_state.has_sample ? _direction_y : 0);

    _state.has_sample = true;
    _state.last_held_actions = _recorded.held_actions;
    _state.last_move_x = _recorded.move_x;
    _state.last_move_y = _recorded.move_y;
    _state.last_gamepad_id = -1;
    return {
        move_x: _recorded.move_x,
        move_y: _recorded.move_y,
        pressed_move_x: _pressed_move_x,
        pressed_move_y: _pressed_move_y,
        held_actions: _recorded.held_actions,
        pressed_actions: _recorded.pressed_actions,
        prompt_device: _recorded.prompt_device,
        gamepad_id: -1,
        has_analog: _recorded.has_analog,
        analog_x: _recorded.analog_x,
        analog_y: _recorded.analog_y,
    };
}

/// Records one deterministic high-pressure input stream through the replay API.
function BladeStage1FramePacingFixtureCreate() {
    var _product_path = BladeStage1RouteIncludedPath(
        "content/product_contract.json"
    );
    var _fingerprint = "sha1:" + sha1_file(_product_path);
    var _known_content = method({}, _BladeStage1FramePacingKnownContent);
    var _seed = BLADE_STAGE1_ROUTE_SEED;
    var _coordinator = BladeRunCoordinatorCreate(
        _fingerprint,
        _known_content,
        "ship.maynii",
        "difficulty.normal",
        BladeRunMode.Normal,
        _seed,
        8
    );
    var _recorder = BladeReplayRecorderCreate(_coordinator);
    var _record_callback = BladeReplayRecorderBind(_recorder);
    var _domains = BladeClockDomain.Stage
        | BladeClockDomain.Actor
        | BladeClockDomain.Boss
        | BladeClockDomain.Combat;

    for (var _index = 0;
        _index < BLADE_STAGE1_FRAME_PACING_INPUT_TICKS;
        ++_index) {
        var _movement_phase = floor(_index / 240) mod 4;
        var _move_x = (_movement_phase == 0 || _movement_phase == 3)
            ? -1024
            : 1024;
        var _held = BladeInputAction.Fire | BladeInputAction.Focus;
        if ((_index mod 600) == 0) {
            _held = _held | BladeInputAction.Bomb;
        }
        BladeRunCoordinatorStepDirect(
            _coordinator,
            BladeInputRawStateCreate(
                _move_x,
                0,
                _held,
                BladePromptDevice.KeyboardMouse,
                false,
                0,
                0
            ),
            _domains,
            _record_callback
        );
    }
    return BladeReplayRecordingSerialize(_recorder);
}

/// Starts a temporary Stage 1 profiling run through the catalog state path.
function BladeStage1FramePacingProfilePrepare() {
    var _recording = BladeStage1FramePacingFixtureCreate();
    var _catalog = BladeReplayCatalogCreate(
        _BladeStage1FramePacingStorageCreate()
    );
    var _save = BladeReplayCatalogSave(_catalog, _recording);
    if (!_save.ok) {
        show_debug_message(
            "BLADE_STAGE1_FRAME_PACING_SETUP: FAIL " + string(_save.code)
        );
        return false;
    }

    var _frontend = BladeFrontendStateCreate(BladeConfigCreateDefault(), _catalog);
    BladeFrontendStateMove(_frontend, 1);
    BladeFrontendStateActivate(_frontend);
    if (_frontend.page != BladeFrontendPage.ReplayCatalog) {
        show_debug_message(
            "BLADE_STAGE1_FRAME_PACING_SETUP: FAIL replay catalog did not open"
        );
        return false;
    }

    var _selected_index = -1;
    for (var _index = 0;
        _index < array_length(_frontend.replay_view.entries);
        ++_index) {
        if (_frontend.replay_view.entries[_index].replay_id
            == _save.entry.replay_id) {
            _selected_index = _index;
            break;
        }
    }
    if (_selected_index < 0) {
        show_debug_message(
            "BLADE_STAGE1_FRAME_PACING_SETUP: FAIL saved replay not listed"
        );
        return false;
    }
    _frontend.selected_index = _selected_index;
    var _activation = BladeFrontendStateActivate(_frontend);
    if (_activation.action != BladeFrontendAction.LaunchReplay) {
        show_debug_message(
            "BLADE_STAGE1_FRAME_PACING_SETUP: FAIL replay not selectable"
        );
        return false;
    }
    var _launch = BladeFrontendStateLaunchReplay(
        _frontend,
        method({}, _BladeStage1FramePacingKnownContent),
        8
    );
    if (!_launch.ok) {
        show_debug_message(
            "BLADE_STAGE1_FRAME_PACING_SETUP: FAIL " + string(_launch.code)
        );
        return false;
    }

    var _ship_catalog = BladeShipSelectionLoad();
    global.blade_selected_run = BladeShipSelectionCreateRun(
        _ship_catalog,
        _launch.entry.ship_id,
        _launch.entry.difficulty_id
    );
    global.blade_stage1_frame_pacing_profile = {
        playback: _frontend.replay_playback,
        replay_entry: _launch.entry,
        metrics: undefined,
        input_state: undefined,
    };
    window_set_fullscreen(false);
    window_set_size(640, 360);
    window_center();
    show_debug_message(
        "BLADE_STAGE1_FRAME_PACING_SETUP: replay="
            + _launch.entry.replay_id
            + " seed=" + string(_launch.entry.run_seed)
            + " ticks=" + string(_launch.entry.input_count)
            + " save=" + string(_save.code)
    );
    return true;
}

/// Hashes deterministic Stage 1 ownership at the end of the replay workload.
function BladeStage1FramePacingStageHash(_controller) {
    var _canonical = BladeCanonicalRecord("SFP1", [
        BladeKernelGameplayCanonical(_controller.stage_kernel),
        BladeStageExecutorCanonical(_controller.stage_executor),
        BladeDifficultyRankCanonical(_controller.economy.rank_state),
        BladeSurvivalEconomyCanonical(_controller.economy),
        string(_controller.rank_clock_tick),
        string(_controller.state),
        string(_controller.player_phase),
        string(instance_number(o_blade_first_beat_enemy)),
        string(instance_number(o_blade_stage1_fae_midboss)),
        string(instance_number(o_blade_stage1_asahi)),
        string(instance_number(o_blade_first_beat_enemy_bullet)),
        string(instance_number(o_blade_player_shot)),
    ]);
    return BladeCanonicalHashUtf8(_canonical);
}

/// Emits the performance summary and deterministic replay/state evidence once.
function BladeStage1FramePacingFinish(_controller) {
    var _profile = _controller.frame_pacing_profile;
    if (!is_struct(_profile) || _profile.finished) return false;
    BladeReplayPlaybackComplete(_profile.playback);
    var _summary = BladeStage1FramePacingSnapshot(_profile.metrics);
    _summary.replay_id = _profile.replay_entry.replay_id;
    _summary.run_seed = _profile.replay_entry.run_seed;
    _summary.ship_id = _profile.replay_entry.ship_id;
    _summary.difficulty_id = _profile.replay_entry.difficulty_id;
    _summary.input_ticks = _profile.replay_entry.input_count;
    _summary.replay_state_hash = BladeReplayPlaybackHash(
        _profile.playback
    );
    var _forest_renderer = instance_find(
        o_blade_stage1_forest_renderer, 0
    );
    _summary.camera_depth_culling = BladeStage1ForestCameraDepthCullSnapshot(
        _forest_renderer
    );
    _summary.stage_state_hash = BladeStage1FramePacingStageHash(_controller);
    _summary.stage_ticks = _controller.rank_clock_tick;
    _summary.stage_lifecycle = _controller.state;
    _profile.finished = true;
    show_debug_message(
        "BLADE_STAGE1_FRAME_PACING_RUN: " + json_stringify(_summary)
    );
    return true;
}
