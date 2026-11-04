#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 04-11-2026
set -euo pipefail
game_dir=$(cd "$(dirname "$0")" && pwd)
run_dir=$(cd "$game_dir/../tail2nos" && pwd)
cd "$run_dir"
mkdir -p sim_results
if [[ $# == 0 ]]; then
    scenes=()
    for path in scenes/[0-9]*/dump.bin; do
        [[ -f "$path" ]] || continue
        scene=${path#scenes/}
        scenes+=("${scene%/dump.bin}")
    done
    set -- "${scenes[@]}"
fi
[[ $# -gt 0 ]] || { echo 'No captured scenes found' >&2; exit 1; }
for scene in "$@"; do
    [[ "$scene" =~ ^[0-9]+$ ]] || { echo "Invalid scene: $scene" >&2; exit 1; }
    [[ -f "scenes/$scene/dump.bin" && -f "scenes/$scene/mmr.bin" ]] || {
        echo "Missing capture: $scene" >&2; exit 1;
    }
done
for scene in "$@"; do
    echo "Replaying scene $scene"
    export TTNOSE_SCENE_DUMP="/jtcores/cores/ttnose/ver/tail2nos/scenes/$scene/dump.bin"
    if ! "$game_dir/sim.sh" -load -batch -fast -d NOMAIN -d NOSOUND -d SIMSCENE -video 3 -time 200 >"sim_results/$scene.log" 2>&1; then
        echo "Replay failed: $run_dir/sim_results/$scene.log" >&2
        exit 1
    fi
    frame=$(find frames -name 'frame_*.png' -type f | LC_ALL=C sort | tail -1)
    [[ -n "$frame" ]] || { echo "No frame: $run_dir/sim_results/$scene.log" >&2; exit 1; }
    cp "$frame" "sim_results/$scene.png"
    echo "Replayed scene $scene"
done
echo "Replay complete: $run_dir/sim_results"
