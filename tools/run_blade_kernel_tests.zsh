#!/bin/zsh

# Compile Blade with GameMaker's single-dependency loader and execute one
# project-owned engine test. GMTL output is intentionally not parsed: the
# imported demo contains known-red cases and unsound matchers.
set -euo pipefail

test_mode=${1:-kernel}
case "$test_mode" in
    kernel)
        launch_argument="--run-test"
        result_sentinel="BLADE_KERNEL_TEST_RESULT"
        summary_prefix="BLADE_KERNEL_TESTS:"
        temp_prefix="blade-kernel-tests"
        ;;
    frontend-room-lifecycle)
        launch_argument="--run-frontend-room-lifecycle-test"
        result_sentinel="BLADE_FRONTEND_ROOM_LIFECYCLE_RESULT"
        summary_prefix=""
        temp_prefix="blade-frontend-room-lifecycle-tests"
        ;;
    application-lifecycle)
        launch_argument="--run-application-lifecycle-test"
        result_sentinel="BLADE_KERNEL_TEST_RESULT"
        summary_prefix="BLADE_KERNEL_TESTS:"
        temp_prefix="blade-application-lifecycle-tests"
        ;;
    frame-pacing)
        launch_argument="--run-stage1-frame-pacing-test"
        result_sentinel="BLADE_STAGE1_FRAME_PACING_RUN"
        summary_prefix=""
        temp_prefix="blade-stage1-frame-pacing-tests"
        ;;
    *)
        print -u2 "Unknown GameMaker test mode: $test_mode"
        exit 2
        ;;
esac

# Run a command in its own process group so a timeout or interruption also
# stops any child runner it created. macOS does not provide GNU timeout, so the
# small Python wrapper handles that lifecycle explicitly.
run_with_timeout() {
    local timeout_seconds=$1
    shift
    python3.12 - "$timeout_seconds" "$@" <<'PY'
import os
import signal
import subprocess
import sys
import time

timeout_seconds = int(sys.argv[1])
command = sys.argv[2:]
# A new session gives the command a process group that can be terminated
# without touching this shell.
process = subprocess.Popen(command, start_new_session=True)


def process_group_exists() -> bool:
    """Check the group because its leader can exit before its descendants."""
    process.poll()
    try:
        os.killpg(process.pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def terminate_process_group() -> None:
    """Give the child group five seconds, then kill survivors to avoid orphans."""
    if not process_group_exists():
        return
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return

    deadline = time.monotonic() + 5
    while time.monotonic() < deadline and process_group_exists():
        time.sleep(0.05)
    if process_group_exists():
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    try:
        process.wait(timeout=1)
    except subprocess.TimeoutExpired:
        pass


def handle_signal(signum: int, _frame: object) -> None:
    """Clean up children before returning the shell status for this signal."""
    terminate_process_group()
    raise SystemExit(128 + signum)


signal.signal(signal.SIGINT, handle_signal)
signal.signal(signal.SIGTERM, handle_signal)
try:
    command_status = process.wait(timeout=timeout_seconds)
    # Python reports signal exits as negative numbers; shells expose them as
    # 128 plus the signal number.
    if command_status < 0:
        command_status = 128 - command_status
    raise SystemExit(command_status)
except subprocess.TimeoutExpired:
    print(
        f"Command timed out after {timeout_seconds} seconds: {command[0]}",
        file=sys.stderr,
    )
    terminate_process_group()
    raise SystemExit(124)
PY
}

script_dir=$(cd -- "$(dirname "$0")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
project_file="$repo_root/project/~ blade of desires ~/~ blade of desires ~.yyp"

runtime_dir=""
for runtime_root in \
    /Users/Shared/GameMakerStudio2-LTS2026/Cache/runtimes \
    /Users/Shared/GameMakerStudio2/Cache/runtimes; do
    [[ -d "$runtime_root" ]] || continue
    for candidate in "$runtime_root"/runtime-*(N); do
        [[ -d "$candidate" ]] || continue
        runtime_dir="$candidate"
    done
done

if [[ -z "$runtime_dir" ]]; then
    print -u2 "No installed GameMaker runtime was found."
    exit 1
fi

gm_user_dir=""
for user_root in \
    "$HOME/Library/Application Support/GameMakerStudio2-LTS2026" \
    "$HOME/Library/Application Support/GameMakerStudio2"; do
    [[ -d "$user_root" ]] || continue
    for candidate in "$user_root"/*(N); do
        [[ -d "$candidate" ]] || continue
        [[ -f "$candidate/licence.plist" ]] || continue
        gm_user_dir="$candidate"
        break
    done
    [[ -n "$gm_user_dir" ]] && break
done

if [[ -z "$gm_user_dir" ]]; then
    print -u2 "No GameMaker user directory with licence.plist was found."
    exit 1
fi

igor_bin=""
for candidate in \
    "$runtime_dir/bin/igor/osx/arm64/Igor" \
    "$runtime_dir/bin/igor/osx/x64/Igor" \
    "$runtime_dir/bin/Igor"; do
    [[ -x "$candidate" ]] || continue
    igor_bin="$candidate"
    break
done

runner_bin="$runtime_dir/mac/YoYo Runner.app/Contents/MacOS/Mac_Runner"
if [[ -z "$igor_bin" || ! -x "$runner_bin" ]]; then
    print -u2 "The installed GameMaker runtime lacks Igor or Mac_Runner."
    exit 1
fi

temp_parent=${TMPDIR:-/tmp}
temp_parent=${temp_parent%/}
test_root=$(mktemp -d "$temp_parent/$temp_prefix.XXXXXX")
build_log="$test_root/build.log"

# Remove only the mktemp directory created above. The name and direct-parent
# checks prevent a broader deletion if a path variable is ever malformed.
cleanup() {
    if [[ "${test_root:h}" == "$temp_parent" && "${test_root:t}" == $temp_prefix.* ]]; then
        rm -rf -- "$test_root"
    fi
}
trap cleanup EXIT INT TERM

# Reject invalid numeric settings before passing them to loop bounds or timeout
# arithmetic.
require_positive_integer() {
    local setting_name=$1
    local setting_value=$2
    if [[ "$setting_value" != <-> || "$setting_value" -lt 1 ]]; then
        print -u2 "$setting_name must be a positive integer."
        exit 1
    fi
}

max_compile_attempts=${BLADE_GM_COMPILE_ATTEMPTS:-6}
compile_timeout_seconds=${BLADE_GM_COMPILE_TIMEOUT_SECONDS:-120}
runner_timeout_seconds=${BLADE_GM_RUNNER_TIMEOUT_SECONDS:-60}
require_positive_integer "BLADE_GM_COMPILE_ATTEMPTS" "$max_compile_attempts"
require_positive_integer "BLADE_GM_COMPILE_TIMEOUT_SECONDS" "$compile_timeout_seconds"
require_positive_integer "BLADE_GM_RUNNER_TIMEOUT_SECONDS" "$runner_timeout_seconds"

game_data=""
for (( attempt = 1; attempt <= max_compile_attempts; attempt++ )); do
    attempt_root="$test_root/build-$attempt"
    mkdir -p "$attempt_root"
    print "Blade GameMaker compile attempt $attempt of $max_compile_attempts"

    set +e
    run_with_timeout "$compile_timeout_seconds" "$igor_bin" \
        -j=1 \
        --project="$project_file" \
        --runtimePath="$runtime_dir" \
        --user="$gm_user_dir" \
        --licencefile="$gm_user_dir/licence.plist" \
        --cache="$attempt_root/cache" \
        --temp="$attempt_root/temp" \
        --of="$attempt_root/blade.zip" \
        --runtime=VM \
        --assetCompiler=--sdlm \
        mac Compile 2>&1 | tee -a "$build_log"
    # Read Igor's status from the pipeline rather than tee's status.
    igor_status=${pipestatus[1]}
    set -e

    if (( igor_status == 0 )); then
        candidate_game_data="$attempt_root/game.zip"
        if [[ -s "$candidate_game_data" ]]; then
            game_data="$candidate_game_data"
            break
        fi
        print -u2 "GameMaker reported success without a nonempty game.zip; retrying."
        continue
    fi
    # This bounded retry policy treats timeout, abort, and segmentation-fault
    # statuses as compiler crashes. Every other failure stops immediately with
    # its original diagnostic.
    if (( igor_status != 124 && igor_status != 134 && igor_status != 139 )); then
        print -u2 "GameMaker compilation failed with status $igor_status."
        exit "$igor_status"
    fi
    print -u2 "GameMaker compiler crashed or timed out with status $igor_status; retrying."
done

if [[ -z "$game_data" ]]; then
    print -u2 "GameMaker compilation crashed on all $max_compile_attempts attempts."
    exit 1
fi
if [[ ! -s "$game_data" ]]; then
    print -u2 "GameMaker did not produce $game_data."
    exit 1
fi

run_count=1
if [[ "$test_mode" == frame-pacing ]]; then
    run_count=${BLADE_STAGE1_FRAME_PACING_RUNS:-3}
    require_positive_integer "BLADE_STAGE1_FRAME_PACING_RUNS" "$run_count"
    if (( run_count < 3 )); then
        print -u2 "Frame-pacing characterization requires at least three runs."
        exit 2
    fi
fi

for (( run_index = 1; run_index <= run_count; run_index++ )); do
    runner_log="$test_root/runner-$run_index.log"
    debug_log="$test_root/debug-$run_index.log"
    print "Blade GameMaker runtime pass $run_index of $run_count"

    set +e
    (
        cd "$test_root"
        run_with_timeout "$runner_timeout_seconds" "$runner_bin" \
            -game "$game_data" \
            -debugoutput "$debug_log" \
            -output "$debug_log" \
            "$launch_argument"
    ) 2>&1 | tee "$runner_log"
    # Read the runner wrapper's status from the pipeline rather than tee's status.
    runner_status=${pipestatus[1]}
    set -e

    result_count=$(grep -c "^$result_sentinel: " "$runner_log" || true)
    summary=""
    if [[ -n "$summary_prefix" ]]; then
        summary=$(grep "^$summary_prefix " "$runner_log" | tail -n 1 || true)
    fi
    result=$(grep "^$result_sentinel: " "$runner_log" | tail -n 1 || true)

    if [[ -z "$result" && -f "$debug_log" ]]; then
        if [[ -n "$summary_prefix" ]]; then
            summary=$(grep "^$summary_prefix " "$debug_log" | tail -n 1 || true)
        fi
        result=$(grep "^$result_sentinel: " "$debug_log" | tail -n 1 || true)
        result_count=$(grep -c "^$result_sentinel: " "$debug_log" || true)
        print "$summary"
        print "$result"
    fi

    if (( runner_status != 0 )); then
        if (( runner_status == 124 )); then
            print -u2 "GameMaker runner timed out after $runner_timeout_seconds seconds."
            exit 1
        fi
        print -u2 "GameMaker runner exited with status $runner_status."
        exit "$runner_status"
    fi

    if (( result_count != 1 )); then
        print -u2 "Expected exactly one $result_sentinel sentinel; found $result_count."
        exit 1
    fi

    if [[ "$test_mode" == kernel || "$test_mode" == application-lifecycle ]]; then
        if [[ "$summary" != BLADE_KERNEL_TESTS:\ *\ passed,\ 0\ failed,\ *\ total ]]; then
            print -u2 "Blade kernel summary was missing, empty, or reported failures."
            exit 1
        fi
        if [[ "$summary" == *" 0 total" || "$result" != "$result_sentinel: PASS" ]]; then
            print -u2 "Blade kernel tests did not report a nonzero passing run."
            exit 1
        fi
    elif [[ "$test_mode" == frame-pacing ]]; then
        if [[ "$result" != "$result_sentinel: "*'"replay_id"'* ]]; then
            print -u2 "Frame-pacing run did not emit replay measurements."
            exit 1
        fi
        print "$result"
    elif [[ "$result" != "$result_sentinel: PASS" ]]; then
        print -u2 "Front-end room lifecycle test did not pass."
        exit 1
    fi
done

if [[ "$test_mode" == frame-pacing ]]; then
    python3.12 - "$test_root" "$run_count" <<'PY'
import json
from pathlib import Path
import sys

test_root = Path(sys.argv[1])
run_count = int(sys.argv[2])
sentinel = "BLADE_STAGE1_FRAME_PACING_RUN: "
required_equal = (
    "replay_id",
    "run_seed",
    "input_ticks",
    "replay_state_hash",
    "stage_state_hash",
    "stage_ticks",
    "stage_lifecycle",
    "camera_depth_culling",
)
measurements = []

for run_index in range(1, run_count + 1):
    payload = None
    for log_name in (f"runner-{run_index}.log", f"debug-{run_index}.log"):
        log_path = test_root / log_name
        if not log_path.is_file():
            continue
        results = [
            line[len(sentinel):]
            for line in log_path.read_text(errors="replace").splitlines()
            if line.startswith(sentinel)
        ]
        if results:
            if len(results) != 1:
                raise SystemExit(
                    f"Run {run_index} emitted {len(results)} profiling records."
                )
            payload = json.loads(results[0])
            break
    if payload is None:
        raise SystemExit(f"Run {run_index} has no profiling record.")
    if payload.get("sample_count", 0) <= 0:
        raise SystemExit(f"Run {run_index} has no measured frame samples.")
    if payload.get("stage_ticks") != payload.get("input_ticks"):
        raise SystemExit(
            f"Run {run_index} ended Stage 1 at tick {payload.get('stage_ticks')} "
            f"before replay tick {payload.get('input_ticks')}."
        )
    measurements.append(payload)

reference = measurements[0]
for run_index, payload in enumerate(measurements[1:], start=2):
    changed = [
        field for field in required_equal
        if payload.get(field) != reference.get(field)
    ]
    if changed:
        raise SystemExit(
            f"Run {run_index} changed replay or Stage 1 state: "
            + ", ".join(changed)
        )

print(
    f"Stage 1 frame-pacing runs matched: {run_count} runs, "
    f"replay={reference['replay_id']}, ticks={reference['stage_ticks']}, "
    f"replay_hash={reference['replay_state_hash']}, "
    f"stage_hash={reference['stage_state_hash']}"
)

def metric_range(field: str, scale: float = 1.0, suffix: str = "") -> str:
    values = [float(payload[field]) * scale for payload in measurements]
    return f"{min(values):.3f}..{max(values):.3f}{suffix}"

percentiles = reference["p50_frame_time_us"]
p95 = reference["p95_frame_time_us"]
p99 = reference["p99_frame_time_us"]
print(
    f"Frame profile: {reference['sample_count']} samples/run after "
    f"{reference['warmup_frames']} warmup frames; "
    f"mean={metric_range('mean_frame_time_us', 0.001, ' ms')}; "
    f"p50={percentiles['lower_us']:.0f}..{percentiles['upper_us']:.0f} us; "
    f"p95={p95['lower_us']:.0f}..{p95['upper_us']:.0f} us; "
    f"p99={p99['lower_us']:.0f}..{p99['upper_us']:.0f} us; "
    f"over budget={metric_range('over_budget_percent', 1.0, '%')}; "
    f"max={metric_range('max_frame_time_us', 0.001, ' ms')}"
)
print(
    "Camera-depth culling at the final replay camera: "
    f"{reference['camera_depth_culling']['camera_depth_skipped_props']:.0f} "
    "of "
    f"{reference['camera_depth_culling']['camera_depth_tested_props']:.0f} "
    "eligible submissions skipped ("
    f"{reference['camera_depth_culling']['camera_depth_skipped_percent']:.2f}%)."
)
PY
fi
