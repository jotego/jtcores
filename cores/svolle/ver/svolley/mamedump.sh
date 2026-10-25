#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 25-10-2026

set -euo pipefail
run_dir=$(cd "$(dirname "$0")" && pwd)
game=${run_dir##*/}
mame=${MAME_BINARY:-/Users/andreabogazzi/Emus/mame0276-arm64/mame}
rompath=${MAME_ROMPATH:-$HOME/.mame/roms-local}
manual=0
export SCENEDUMP_ROOT="$run_dir" SCENEDUMP_REPLACE=0
frames=()
for argument in "$@"; do
    case "$argument" in
        --manual) manual=1;;
        --replace) export SCENEDUMP_REPLACE=1;;
        *[!0-9]*|'') echo "Invalid frame or option: $argument" >&2; exit 1;;
        *) frames+=("$argument");;
    esac
done
version=$("$mame" -help | sed -n '1p')
[[ "$version" == 'MAME v0.282 '* ]] || { echo "MAME 0.282 is required" >&2; exit 1; }
mkdir -p "$run_dir/scratch/capture/cfg" "$run_dir/scratch/capture/nvram"
cd "$run_dir/scratch/capture"
options=(-rompath "$rompath" -skip_gameinfo -snapview native -nosnapbilinear
    -frameskip 0 -cfg_directory cfg -nvram_directory nvram
    -autoboot_delay 0 -autoboot_script "$run_dir/mamedump.lua")
if [[ "$manual" == 1 ]]; then
    unset SCENEDUMP_FRAMES SCENEDUMP_DONE
    exec "$mame" "$game" "${options[@]}"
fi
if [[ ${#frames[@]} == 0 ]]; then
    for ((frame=300;frame<=6000;frame+=300)); do frames+=("$frame"); done
fi
export SCENEDUMP_FRAMES="${frames[*]}"
export SCENEDUMP_DONE="$run_dir/scratch/capture/done-$$"
last=0
for frame in "${frames[@]}"; do ((frame>last)) && last=$frame; done
log="$run_dir/scratch/capture/run-$$.log"
"$mame" "$game" "${options[@]}" -video none -sound none -nothrottle \
    -seconds_to_run "$((last/60+20))" > "$log" 2>&1
[[ -f "$SCENEDUMP_DONE" ]] || { echo "Capture incomplete: $log" >&2; exit 1; }
echo "$game capture complete: $run_dir/scenes"
