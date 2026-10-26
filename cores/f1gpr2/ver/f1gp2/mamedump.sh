#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 25-10-2026

set -euo pipefail
run_dir=$(cd "$(dirname "$0")" && pwd)
mame=${MAME_BINARY:-/Users/andreabogazzi/Emus/mame0276-arm64/mame}
rompath=${MAME_ROMPATH:-$HOME/.mame/roms-local}
output=$run_dir
manual=0
replace=0
frames=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --manual) manual=1;;
        --replace) replace=1;;
        --output) shift; output=${1:?Missing output directory};;
        *[!0-9]*|'') echo "Usage: $0 [--manual] [--replace] [--output DIR] [frames...]" >&2; exit 1;;
        *) frame=$((10#$1)); ((frame>0)) || { echo "Frame must be positive" >&2; exit 1; }; frames+=("$frame");;
    esac
    shift
done
[[ $manual -eq 0 || ${#frames[@]} -eq 0 ]] || { echo "Manual mode does not take a frame list" >&2; exit 1; }
[[ -x "$mame" ]] || { echo "MAME executable unavailable: $mame" >&2; exit 1; }
version=$("$mame" -help | sed -n '1p')
[[ "$version" == 'MAME v0.282 '* ]] || { echo "MAME 0.282 is required; got $version" >&2; exit 1; }
mkdir -p "$output"
output=$(cd "$output" && pwd)
mkdir -p "$output/scratch/capture/cfg" "$output/scratch/capture/nvram"
export SCENEDUMP_ROOT="$output" SCENEDUMP_REPLACE="$replace"
cd "$output/scratch/capture"
options=(-rompath "$rompath" -skip_gameinfo -snapview native -nosnapbilinear -frameskip 0
    -cfg_directory cfg -nvram_directory nvram -inipath .
    -autoboot_delay 0 -autoboot_script "$run_dir/mamedump.lua")
if [[ $manual -eq 1 ]]; then
    unset SCENEDUMP_FRAMES SCENEDUMP_DONE
    echo "Backslash captures the current frame, including while paused."
    exec "$mame" f1gp2 "${options[@]}"
fi
if [[ ${#frames[@]} -eq 0 ]]; then
    for ((frame=300;frame<=6000;frame+=300)); do frames+=("$frame"); done
fi
export SCENEDUMP_FRAMES="${frames[*]}"
export SCENEDUMP_DONE="$output/scratch/capture/done-$$"
rm -f "$SCENEDUMP_DONE"
last=0
for frame in "${frames[@]}"; do if ((frame>last)); then last=$frame; fi; done
log="$output/scratch/capture/run-$$.log"
{
    echo "MAME: $mame"
    echo "$version"
    echo "Frames: ${frames[*]}"
} > "$log"
SDL_VIDEODRIVER=${SDL_VIDEODRIVER:-dummy} SDL_AUDIODRIVER=${SDL_AUDIODRIVER:-dummy} \
    "$mame" f1gp2 "${options[@]}" -video none -sound none -nothrottle \
    -seconds_to_run "$((last/60+20))" >> "$log" 2>&1
[[ -f "$SCENEDUMP_DONE" ]] || { echo "Capture incomplete: $log" >&2; exit 1; }
echo "f1gp2 capture complete: $output/scenes"
echo "Log: $log"
