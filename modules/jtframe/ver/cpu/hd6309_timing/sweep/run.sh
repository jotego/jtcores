#!/usr/bin/env bash
set -euo pipefail
args=("$@")
repo=$(git rev-parse --show-toplevel)
set --
source "$repo/setprj.sh"
python3 "$repo/modules/jtframe/ver/cpu/hd6309_timing/sweep/run.py" "${args[@]}"
