/// @description Bounded frame-summary, replay-seed, culling, and input checks.

function BladeStage1FramePacingTestsRun(_state) {
    BladeKernelTestRunCase(
        _state,
        "Stage 1 frame pacing preserves replay and render contracts",
        function() {
            var _profile = BladeStage1FramePacingCreate();
            _profile.warmup_frames = 2;
            BladeStage1FramePacingRecord(_profile, 1000, 1, 2, 3);
            BladeStage1FramePacingRecord(_profile, 1200, 2, 3, 4);
            BladeStage1FramePacingRecord(_profile, 16000, 3, 8, 5);
            BladeStage1FramePacingRecord(_profile, 17000, 4, 12, 7);
            BladeStage1FramePacingRecord(_profile, 30000, 5, 10, 8);
            BladeStage1FramePacingRecord(_profile, 45000, 6, 16, 9);
            var _summary = BladeStage1FramePacingSnapshot(_profile);
            BladeKernelTestAssertEqual(
                _summary.frames_seen, 6, "frame pacing counts every frame"
            );
            BladeKernelTestAssertEqual(
                _summary.sample_count, 4, "frame pacing excludes warmup"
            );
            BladeKernelTestAssertEqual(
                _summary.p50_frame_time_us.lower_us,
                17000,
                "frame pacing reports median bucket"
            );
            BladeKernelTestAssertEqual(
                _summary.p95_frame_time_us.lower_us,
                45000,
                "frame pacing reports tail bucket"
            );
            BladeKernelTestAssertEqual(
                _summary.max_frame_time_us,
                45000,
                "frame pacing retains exact maximum"
            );
            BladeKernelTestAssertEqual(
                _summary.over_budget_frames,
                3,
                "frame pacing counts frames over the target budget"
            );
            BladeKernelTestAssertEqual(
                _summary.peak_hostile_bullets,
                16,
                "frame pacing records measured workload pressure"
            );

            BladeKernelTestAssertEqual(
                BladeStage1RouteRunSeed({
                    frame_pacing_profile: {
                        replay_entry: { run_seed: int64(1535400) },
                    },
                }),
                int64(1535400),
                "frame pacing initializes Stage 1 from the replay seed"
            );
            BladeKernelTestAssertEqual(
                BladeStage1RouteRunSeed({ frame_pacing_profile: undefined }),
                int64(14041991),
                "ordinary Stage 1 retains its route seed"
            );

            var _camera = {
                camera_x: 0,
                camera_y: 0,
                camera_z: 0,
                look_x: 0,
                look_y: 1,
                look_z: 0,
            };
            var _prop_counts = _BladeStage1ForestCameraDepthCountItems(
                _camera,
                [
                    { x: 0, y: 10, z: 0, width: 1, height: 1 },
                    { x: 0, y: -10, z: 0, width: 2, height: 2 },
                    { x: 0, y: -1, z: 0, width: 2, height: 2 },
                ],
                100,
                "foliage"
            );
            BladeKernelTestAssertEqual(
                _prop_counts.tested,
                3,
                "culling measurement counts eligible same-camera props"
            );
            BladeKernelTestAssertEqual(
                _prop_counts.rejected,
                1,
                "culling measurement counts rearward submissions avoided"
            );

            var _input_state = BladeLiveInputStateCreate();
            var _input = BladeStage1FramePacingInputSample(
                _input_state,
                BladeInputSnapshotCreateRecorded(
                    int64(1), int64(1024), int64(0),
                    int64(BladeInputAction.Fire),
                    int64(BladeInputAction.Fire), int64(0),
                    false, int64(0), int64(0)
                )
            );
            BladeKernelTestAssertEqual(
                _input.move_x, 1024, "replay adapter preserves movement"
            );
            BladeKernelTestAssertEqual(
                _input.held_actions,
                BladeInputAction.Fire,
                "replay adapter preserves held actions"
            );
            BladeKernelTestAssertEqual(
                _input.pressed_actions,
                BladeInputAction.Fire,
                "replay adapter preserves action edges"
            );
        }
    );
}
