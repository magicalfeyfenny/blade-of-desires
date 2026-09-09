#!/bin/zsh

# Compile and execute the opt-in GameMaker front-end room lifecycle test.
set -euo pipefail

script_dir=$(cd -- "$(dirname "$0")" && pwd)
exec "$script_dir/run_blade_kernel_tests.zsh" frontend-room-lifecycle
