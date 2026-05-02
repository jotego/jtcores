#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
GRAD3=$(cd ../.. && pwd)
JTROOT=${JTROOT:-$(cd "$GRAD3/../.." && pwd)}
export JTROOT
export JTFRAME=${JTFRAME:-$JTROOT/modules/jtframe}
export CORES=${CORES:-$JTROOT/cores}
export MODULES=${MODULES:-$JTROOT/modules}
export JTBIN=${JTBIN:-$JTROOT/release}
export ROM=${ROM:-$JTROOT/rom}

mkdir -p "$PWD/shim"
if [ "$(uname)" = "Darwin" ]; then
    for bin in grealpath gsed gcp gln gstat; do
        full=$(which "$bin" 2>/dev/null || true)
        if [ -z "$full" ]; then
            echo "sim.sh: missing $bin; install GNU coreutils/gnu-sed first" >&2
            exit 1
        fi
        ln -sf "$full" "$PWD/shim/${bin#g}"
    done
fi
export PATH="$PWD/shim:$JTFRAME/bin:$PATH"
export JTFRAME_SIM_VIDEO_BMP=${JTFRAME_SIM_VIDEO_BMP:-1}
export JTFRAME_SIM_VIDEO_EVERY=${JTFRAME_SIM_VIDEO_EVERY:-1}
export CONVERT_OPTIONS=${CONVERT_OPTIONS:--quality 100 -sampling-factor 4:4:4}

if [ "${GRAD3_KEEP_FRAMES:-0}" != "1" ]; then
    mkdir -p frames
    rm -f frames/frame_*.jpg frames/frame_*.bmp frames/frame_*.png frames/frames.crc
fi

if [ ! -s "$ROM/gradius3.rom" ]; then
    ROMPATH=${GRAD3_ROM:-${MAME_ROM_PATH:-}}
    if [ -z "$ROMPATH" ]; then
        echo "sim.sh: set GRAD3_ROM or MAME_ROM_PATH to a directory containing gradius3.zip" >&2
        exit 1
    fi
    jtframe mra grad3 --path "$ROMPATH" --skipPocket --setname gradius3
fi

if [ ! -e rom.bin ] || [ "$(readlink rom.bin 2>/dev/null || true)" != "$ROM/gradius3.rom" ]; then
    rm -f rom.bin
    ln -srf "$ROM/gradius3.rom" rom.bin
fi
if [ -e "$ROM/gradius3.mod" ]; then
    cp "$ROM/gradius3.mod" core.mod
fi

exec jtsim "$@"
