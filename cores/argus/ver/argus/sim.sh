#!/bin/bash
# Verilator sim wrapper for the Argus core.
#
# Usage:
#   ./sim.sh -video 5 -fast
#   ./sim.sh -frame 260 -fast -inputs start_game.cab
#   ARGUS_ROM=/Users/fulvio/Downloads ./sim.sh -setname argus -video 5 -fast

set -e

HERE=$(cd "$(dirname "$0")" && pwd)
ARGUS=$(cd "$HERE/../.." && pwd)
JTROOT=$(cd "$ARGUS/../.." && pwd)
export JTROOT
export JTFRAME=$JTROOT/modules/jtframe
export CORES=$JTROOT/cores
export MODULES=$JTROOT/modules
export JTBIN=${JTBIN:-$JTROOT/release}
export ROM=${ROM:-$JTROOT/rom}
mkdir -p "$JTBIN" "$ROM"

mkdir -p "$HERE/shim"
if [ "$(uname)" = "Darwin" ]; then
    for bin in grealpath gsed gcp gln gstat gwc gtac gtr; do
        full=$(which "$bin" 2>/dev/null || true)
        if [ -z "$full" ]; then
            echo "sim.sh: missing $bin; install GNU coreutils/gnu-sed first" >&2
            exit 1
        fi
        ln -sf "$full" "$HERE/shim/${bin#g}"
    done
fi
export PATH="$HERE/shim:$JTFRAME/bin:$PATH"

export JTFRAME_SIM_VIDEO_BMP=${JTFRAME_SIM_VIDEO_BMP:-1}
export JTFRAME_SIM_VIDEO_EVERY=${JTFRAME_SIM_VIDEO_EVERY:-1}

cd "$HERE"

if [ ! -s "$ROM/argus.rom" ] || [ ! -s "$ROM/argus.mod" ] || [ "$ARGUS/cfg/mame2mra.toml" -nt "$ROM/argus.mod" ]; then
    rom_path=${ARGUS_ROM:-/Users/fulvio/Downloads}
    jtframe mra argus --setname argus --path "$rom_path"
fi
cp "$ROM/argus.mod" "$HERE/core.mod"

exec jtsim -verilator -mist -load -skipROM -setname argus "$@"
