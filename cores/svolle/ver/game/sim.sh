#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 25-10-2026

set -euo pipefail
core_dir=$(cd "$(dirname "$0")/../.." && pwd)
repo_dir=$(cd "$core_dir/../.." && pwd)
run_dir="$core_dir/ver/svolley"
image=${SIMULATOR_IMAGE:-jotego/simulator:arm64}
mkdir -p "$run_dir/scratch/bin"
docker image inspect "$image" >/dev/null
if [[ ! -s "$repo_dir/rom/svolley.rom" ]]; then
    export JTROOT="$repo_dir" JTFRAME="$repo_dir/modules/jtframe"
    export CORES="$repo_dir/cores" JTBIN="$repo_dir/release"
    rom_dir=${MAME_ROMPATH:-$HOME/.mame/roms-local/svolley}
    mkdir -p "$run_dir/scratch/roms"
    (cd "$rom_dir" && zip -q -j "$run_dir/scratch/roms/svolley.zip" ./*.bin)
    "$JTFRAME/bin/jtframemac" mra svolle --path "$run_dir/scratch/roms" --skipPocket
fi
if [[ $# == 0 ]]; then set -- -load -video 180; fi
docker run --rm --pull=never --entrypoint /bin/bash \
    -v "$repo_dir:/jtcores" \
    -w /jtcores/cores/svolle/ver/svolley \
    -e JTROOT=/jtcores -e JTFRAME=/jtcores/modules/jtframe \
    -e CORES=/jtcores/cores -e MODULES=/jtcores/modules \
    -e JTBIN=/jtcores/release -e ROM=/jtcores/rom \
    -e RLS=/jtcores/release -e MRA=/jtcores/release/mra \
    "$image" -euo pipefail -c '
        helper="$PWD/scratch/bin/jtframe"
        if [[ ! -x "$helper" ]] || [[ -n $(find "$JTFRAME/src/jtframe" -name "*.go" -newer "$helper" -print -quit) ]]; then
            go build -C "$JTFRAME/src/jtframe" -o "$helper" .
        fi
        export PATH="$PWD/scratch/bin:$JTFRAME/bin:$PATH"
        exec jtsim -setname svolley -skipROM -mister "$@"
    ' bash "$@"
