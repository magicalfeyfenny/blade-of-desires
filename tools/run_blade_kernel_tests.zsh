#!/bin/zsh

# Compile Blade with GameMaker's single-dependency loader and execute the
# project-owned deterministic-kernel runner. GMTL output is intentionally not
# parsed: the imported demo contains known-red cases and unsound matchers.
set -euo pipefail

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
process = subprocess.Popen(command, start_new_session=True)


def process_group_exists() -> bool:
    process.poll()
    try:
        os.killpg(process.pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def terminate_process_group() -> None:
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
    terminate_process_group()
    raise SystemExit(128 + signum)


signal.signal(signal.SIGINT, handle_signal)
signal.signal(signal.SIGTERM, handle_signal)
try:
    raise SystemExit(process.wait(timeout=timeout_seconds))
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
test_root=$(mktemp -d "$temp_parent/blade-kernel-tests.XXXXXX")
build_log="$test_root/build.log"
runner_log="$test_root/runner.log"
debug_log="$test_root/debug.log"

cleanup() {
    if [[ "${test_root:h}" == "$temp_parent" && "${test_root:t}" == blade-kernel-tests.* ]]; then
        rm -rf -- "$test_root"
    fi
}
trap cleanup EXIT INT TERM

max_compile_attempts=${BLADE_GM_COMPILE_ATTEMPTS:-6}
compile_timeout_seconds=${BLADE_GM_COMPILE_TIMEOUT_SECONDS:-120}
runner_timeout_seconds=${BLADE_GM_RUNNER_TIMEOUT_SECONDS:-60}
for setting in \
    "BLADE_GM_COMPILE_ATTEMPTS:$max_compile_attempts" \
    "BLADE_GM_COMPILE_TIMEOUT_SECONDS:$compile_timeout_seconds" \
    "BLADE_GM_RUNNER_TIMEOUT_SECONDS:$runner_timeout_seconds"; do
    setting_name=${setting%%:*}
    setting_value=${setting#*:}
    if [[ "$setting_value" != <-> || "$setting_value" -lt 1 ]]; then
        print -u2 "$setting_name must be a positive integer."
        exit 1
    fi
done

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

set +e
(
    cd "$test_root"
    run_with_timeout "$runner_timeout_seconds" "$runner_bin" \
        -game "$game_data" \
        -debugoutput "$debug_log" \
        -output "$debug_log" \
        --run-test
) 2>&1 | tee "$runner_log"
runner_status=${pipestatus[1]}
set -e

result_count=$(grep -c '^BLADE_KERNEL_TEST_RESULT: ' "$runner_log" || true)
summary=$(grep '^BLADE_KERNEL_TESTS: ' "$runner_log" | tail -n 1 || true)
result=$(grep '^BLADE_KERNEL_TEST_RESULT: ' "$runner_log" | tail -n 1 || true)

if [[ -z "$summary" && -f "$debug_log" ]]; then
    summary=$(grep 'BLADE_KERNEL_TESTS: ' "$debug_log" | tail -n 1 || true)
    result=$(grep 'BLADE_KERNEL_TEST_RESULT: ' "$debug_log" | tail -n 1 || true)
    result_count=$(grep -c 'BLADE_KERNEL_TEST_RESULT: ' "$debug_log" || true)
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
    print -u2 "Expected exactly one Blade kernel result sentinel; found $result_count."
    exit 1
fi

if [[ "$summary" != BLADE_KERNEL_TESTS:\ *\ passed,\ 0\ failed,\ *\ total ]]; then
    print -u2 "Blade kernel summary was missing, empty, or reported failures."
    exit 1
fi

if [[ "$summary" == *" 0 total" || "$result" != "BLADE_KERNEL_TEST_RESULT: PASS" ]]; then
    print -u2 "Blade kernel tests did not report a nonzero passing run."
    exit 1
fi
