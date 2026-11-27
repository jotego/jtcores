#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 10-11-2026

set -euo pipefail
scene=${1:?Expected scene frame number}
[[ "$scene" =~ ^[0-9]+$ ]] || { echo "Invalid scene: $scene" >&2; exit 2; }
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
set_dir="$repo_root/cores/geebee/ver/geebee"
[[ -f "$set_dir/scenes/$scene/dump.bin" && -f "$set_dir/scenes/$scene/mmr.bin" ]] || {
    echo "Missing scene $scene" >&2
    exit 1
}
mkdir -p "$set_dir/bin" "$set_dir/build" "$set_dir/sim_results"
cd "$set_dir"
docker run --rm --pull=never --entrypoint /bin/bash \
    -v "$repo_root:$repo_root" -w "$set_dir" \
    jotego/simulator:arm64 -lc '
set -euo pipefail
export JTROOT="$(realpath "$PWD/../../../..")"
export JTFRAME="$JTROOT/modules/jtframe"
export MODULES="$JTROOT/modules"
export CORES="$JTROOT/cores"
export JTBIN="$JTROOT/release"
export ROM="$JTROOT/rom"
export RLS="$JTROOT/release"
export MRA="$JTROOT/release/mra"
export GEEBEE_SCENE_DIR="scenes/$1"
export PATH="$PWD/bin:$JTFRAME/bin:$PATH"
(cd "$JTFRAME/src/jtframe" && go build -o "$OLDPWD/bin/jtframe" .)
jtframe mem geebee --target mister --local > "build/scene_${1}_prepare.log" 2>&1
"$JTFRAME/bin/jtsim" -mister -setname geebee -skipROM -load \
    -d NOMAIN -d NOSOUND -video 3 > "sim_results/$1.log" 2>&1
' _ "$scene"
scene_frame=$(find frames -maxdepth 1 -name 'frame_*.png' | sort -V | tail -1)
[[ -n "$scene_frame" ]] || { echo "No scene image: $set_dir/sim_results/$scene.log" >&2; exit 1; }
cp "$scene_frame" "sim_results/$scene.png"
echo "Gee Bee scene $scene rendered: $set_dir/sim_results/$scene.png"
