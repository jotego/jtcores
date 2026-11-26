#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 25-11-2026
set -euo pipefail

run_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
mame=${MAME_BINARY:-/Users/andreabogazzi/Emus/mame0276-arm64/mame}
rompath=${MAME_ROMPATH:-"$HOME/.mame/roms-local"}
export SCENEDUMP_ROOT="$run_dir"
unset SCENEDUMP_FRAMES SCENEDUMP_DONE
manual=0
frames=()
for argument in "$@"; do
    case "$argument" in
        --manual) manual=1;;
        ''|*[!0-9]*) printf 'Invalid frame or option: %s\n' "$argument" >&2; exit 2;;
        *) frames+=("$argument");;
    esac
done
[[ $("$mame" -version) == '0.282 (mame0282)' ]] || { echo 'MAME 0.282 is required' >&2; exit 1; }

mkdir -p "$run_dir/scratch" "$run_dir/logs"
work_dir=$(mktemp -d "$run_dir/scratch/mamedump.XXXXXX")
cd "$work_dir"
options=(-rompath "$rompath" -skip_gameinfo -snapview native -nosnapbilinear
    -frameskip 0 -cfg_directory cfg -nvram_directory nvram
    -autoboot_delay 0 -autoboot_script "$run_dir/mamedump.lua")
if ((manual)); then exec "$mame" shadfrce "${options[@]}"; fi

if ((${#frames[@]} == 0)); then
    for ((frame=300; frame<=9000; frame+=300)); do frames+=("$frame"); done
fi
export SCENEDUMP_FRAMES="${frames[*]}"
export SCENEDUMP_DONE="$work_dir/done"
last=0
for frame in "${frames[@]}"; do
    ((10#$frame > 0)) || exit 2
    if ((10#$frame > last)); then last=$((10#$frame)); fi
done
log="$run_dir/logs/${work_dir##*/}.log"
SDL_VIDEODRIVER=dummy "$mame" shadfrce "${options[@]}" -video none -sound none -nothrottle \
    -seconds_to_run "$((last/57+20))" > "$log" 2>&1
[[ -s "$SCENEDUMP_DONE" ]] || { printf 'Capture incomplete. See %s\n' "$log" >&2; exit 1; }
printf 'Scenes saved in %s\n' "$run_dir/scenes"
