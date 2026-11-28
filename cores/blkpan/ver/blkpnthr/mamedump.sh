#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 25-11-2026

set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
mame=${MAME_BINARY:-/Users/andreabogazzi/Emus/mame0276-arm64/mame}
rompath=${MAME_ROMPATH:-"$HOME/.mame/roms-local"}
output="$here/scenes"
manual=false
replace=0
frames=()
while (($#)); do
    case $1 in
        --manual) manual=true ;;
        --replace) replace=1 ;;
        --output) output=${2:?Missing output directory}; shift ;;
        -h|--help)
            printf 'Usage: %s [--replace] [--output DIR] [--manual | FRAME ...]\n' "$0"
            exit 0 ;;
        *)
            if [[ ! $1 =~ ^[1-9][0-9]{0,7}$ ]]; then
                printf 'Invalid frame or option: %s\n' "$1" >&2
                exit 2
            fi
            frames+=("$1") ;;
    esac
    shift
done

if [[ ! $("$mame" -version) =~ ^0\.282([[:space:]]|$) ]]; then
    printf 'MAME 0.282 is required: %s\n' "$mame" >&2
    exit 1
fi
mkdir -p -- "$output" "$here/scratch/mamedump"
export BLKPAN_SCENE_OUTPUT=$(cd -- "$output" && pwd -P)
export BLKPAN_SCENE_REPLACE=$replace
args=(blkpnthr -rompath "$rompath" -autoboot_delay 0 -autoboot_script "$here/mamedump.lua"
    -snapview native -nosnapbilinear -skip_gameinfo)

if $manual; then
    if [[ -n ${frames[0]+set} ]]; then
        printf 'Frame arguments cannot be used with --manual\n' >&2
        exit 2
    fi
    unset BLKPAN_CAPTURE_FRAME
    exec "$mame" "${args[@]}"
fi

if [[ -z ${frames[0]+set} ]]; then
    for ((frame=300; frame<=6000; frame+=300)); do frames+=("$frame"); done
fi
logs=$(mktemp -d "$here/scratch/mamedump/run.XXXXXXXX")
for frame in "${frames[@]}"; do
    if [[ -e "$BLKPAN_SCENE_OUTPUT/$frame" && $replace == 0 ]]; then
        printf 'Scene %s exists. Use --replace to capture it again.\n' "$frame" >&2
        exit 1
    fi
done
for frame in "${frames[@]}"; do
    limit=$((frame / 60 + 10))
    log="$logs/$frame.log"
    if ! SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy BLKPAN_CAPTURE_FRAME="$frame" \
        "$mame" "${args[@]}" -video none -sound none -uifontprovider none -frameskip 0 \
        -nothrottle -seconds_to_run "$limit" -inipath "$logs" -homepath "$logs" -cfg_directory "$logs/cfg" \
        -nvram_directory "$logs/nvram" -snapshot_directory "$logs" >"$log" 2>&1 ||
        ! grep -Fxq "CAPTURE_OK $frame" "$log"; then
        printf 'Capture failed at frame %s. See %s\n' "$frame" "$log" >&2
        exit 1
    fi
    printf 'Captured frame %s\n' "$frame"
done
