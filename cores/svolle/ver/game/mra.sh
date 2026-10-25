#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 25-10-2026

set -euo pipefail
core_dir=$(cd "$(dirname "$0")/../.." && pwd)
export JTROOT=$(cd "$core_dir/../.." && pwd)
export JTFRAME="$JTROOT/modules/jtframe" CORES="$JTROOT/cores" JTBIN="$JTROOT/release"
rom_root=${MAME_ROMPATH:-$HOME/.mame/roms-local}
stage_dir="$core_dir/ver/svolley/scratch/roms"
mkdir -p "$stage_dir"
skip_rom=0
for argument in "$@"; do
    if [[ "$argument" == --skipROM ]]; then skip_rom=1; fi
done
if [[ "$skip_rom" == 0 ]]; then
    for game in svolley svolleyk svolleyu svolleyua rabiolep; do
        folder=
        for candidate in "$rom_root/$game" "$rom_root/svolley/$game" "$rom_root/../$game"; do
            if [[ -d "$candidate" ]]; then folder="$candidate"; break; fi
        done
        if [[ ${rom_root##*/} == "$game" ]]; then folder="$rom_root"; fi
        if [[ -n "$folder" ]]; then
            files=()
            for file in "$folder"/*; do
                if [[ -f "$file" ]]; then files+=("$file"); fi
            done
            if [[ ${#files[@]} -gt 0 ]]; then
                temporary="$stage_dir/$game-new.zip"
                rm -f "$temporary"
                zip -q -j "$temporary" "${files[@]}"
                mv "$temporary" "$stage_dir/$game.zip"
            fi
        elif [[ -f "$rom_root/$game.zip" ]]; then
            cp "$rom_root/$game.zip" "$stage_dir/$game.zip"
        fi
    done
fi
exec "$JTFRAME/bin/jtframemac" mra svolle --path "$stage_dir" --skipPocket "$@"
