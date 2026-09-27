# Issue #153 Stage 1 frame-pacing evidence

## Workload and method

`tools/run_blade_kernel_tests.zsh frame-pacing` compiled and launched the
GameMaker Mac Runner three times with the same deterministic recording. Each
process records a fixed 1,002-tick Stage 1 input stream with the replay recorder
from #127, saves it to a process-local replay catalog, opens the replay page,
selects the saved entry, and launches it through the frontend replay path from
#136. The process-local storage adapter prevents the benchmark from changing a
player's persistent replay files.

The recording uses `ship.maynii`, `difficulty.normal`, and run seed `14041991`.
It holds Fire and Focus, follows a four-phase horizontal movement pattern with
240-tick phases, and taps Bomb every 600 ticks. Each run reaches the same terminal
failure after simulating all 1,002 replay and Stage 1 ticks; this is a fixed
workload, not a claim of a full-stage clear. The workload peaks at 4 enemies,
57 hostile bullets, and 24 player shots.

The runner uses GameMaker runtime `2026.0.0.23` on the macOS Mac Runner at
640x360 windowed resolution. It discards the first 120 Stage 1 frames as
warmup, then summarizes `delta_time` for the next 882 frames. The 16,667 us
frame budget represents a 60 Hz target. Percentiles are reported as 1,000 us
intervals because the bounded histogram intentionally uses 1 ms bins.
These measurements characterize frame pacing; they do not isolate CPU versus
GPU time or identify a particular expensive function.

## Results

All three runs consumed replay
`replay.3ee2ce4196ad65e58109cc090884b04df37dc642` and matched on both hashes:

- Replay input hash: `bf6cde2bad0d8dad40a242b1337fd4ec538eb67f`
- Stage 1 state hash: `bf1768b4e5e8a7039b087fbf5a5b278c805987bc`
- Simulated ticks: 1,002 of 1,002; terminal state: Failed
- Mean frame time: 16.661 ms in each run
- Median: 16–17 ms; p95: 18–19 ms; p99: 19–20 ms
- Frames over 16.667 ms: 48.2–50.3% across runs
- Maximum frame time: 25.500–27.660 ms across runs

The average is close to the budget, but the tail and the share of over-budget
frames show that 60 Hz frame pacing is not consistently met on this workload.
The current measurements do not locate the cause, so they do not support a
focused performance correction without further profiling.

## Rearward-prop culling

At the final replay camera (`x=0`, `y=68`, `z=-8`), the same-camera
counterfactual counted 146 eligible forest prop submissions and 63 rejected by
the current rearward-depth checks (43.15%). The breakdown was 18 trees, 30
foliage items, 2 fae, 6 trails, and 7 ball lights; the World Tree remained
visible. This establishes the draw submissions currently avoided for that
camera and workload. It does not claim a frame-time saving or compare against
an obsolete build.

## Validation

- `tools/run_blade_kernel_tests.zsh kernel`: 252 passed, 0 failed.
- `BLADE_GM_RUNNER_TIMEOUT_SECONDS=60 tools/run_blade_kernel_tests.zsh frame-pacing`:
  three matching runtime runs, each with 1,002 replay and Stage 1 ticks.
- The repeated-run script rejected any run with mismatched replay metadata,
  hashes, tick count, or terminal lifecycle.
