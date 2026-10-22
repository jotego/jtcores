#!/usr/bin/env bash
set -euo pipefail
sim_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
out_dir=${1:-${TMPDIR:-/tmp}/jttms10-restart-held-hlt}
JTTMS10_RESTART_BENCH="$sim_dir/test-reserved.sv" \
JTTMS10_RESTART_DEFINE=RESTART_HOLD_HLT \
    "$sim_dir/sim.sh" "$out_dir"
