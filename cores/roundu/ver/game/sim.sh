#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 18-10-2026

set -euo pipefail
roundu_repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd -P)
roundu_image=${JTFRAME_SIM_IMAGE:-jotego/simulator:arm64}
roundu_preload=0
if [ "${1:-}" = --preload ]; then
    roundu_preload=1
    shift
    python3 "$roundu_repo/cores/roundu/ver/game/verify_banks.py"
fi
if [ ! -f "$roundu_repo/rom/roundup5.rom" ]; then
    python3 "$roundu_repo/cores/roundu/ver/game/verify_roms.py" \
        --archive "$HOME/.mame/roms-local/roundup5.7z"
fi
if [ "$#" -eq 0 ]; then set -- -video 180 -time 4000; fi
docker image inspect "$roundu_image" >/dev/null
docker run --rm --pull=never --entrypoint /bin/bash \
    -v "$roundu_repo:/jtcores" \
    -v "$roundu_repo/modules:/jtcores/modules:ro" \
    -e ROUNDU_PRELOAD="$roundu_preload" \
    -w /jtcores/cores/roundu/ver/roundup5 \
    "$roundu_image" -lc '
        set -euo pipefail
        export JTROOT=/jtcores
        export JTFRAME=$JTROOT/modules/jtframe
        export CORES=$JTROOT/cores
        export MODULES=$JTROOT/modules
        export JTBIN=$JTROOT/release
        export ROM=$JTROOT/rom
        export RLS=$JTROOT/release
        export MRA=$JTROOT/release/mra
        export POCKET=$JTFRAME/target/pocket
        export ROUNDU_VERILATOR=$(command -v verilator)
        export PATH=$CORES/roundu/ver/game:$JTFRAME/bin:$PATH
        export JTFRAME_REGRESSION=1
        export MAKEJOBS=-j4
        unset VERILATOR_ROOT
        cd "$JTFRAME/src/jtframe"
        go build -o "$CORES/roundu/ver/game/jtframe" .
        cd "$JTFRAME/src/jtutil"
        go build -o "$CORES/roundu/ver/game/jtutil" .
        cd "$CORES/roundu/ver/roundup5"
        roundu_load=(-load)
        if [ "$ROUNDU_PRELOAD" = 1 ]; then
            roundu_load=()
            ln -sfn "$ROM/roundup5.rom" rom.bin
        fi
        for roundu_arg in "$@"; do
            if [ "$roundu_arg" = -lint ]; then
                roundu_load=()
                ln -sfn "$ROM/roundup5.rom" rom.bin
            fi
        done
        jtsim -setname roundup5 -skipROM -mister "${roundu_load[@]}" -batch -fast -fx68k "$@"
    ' roundu-sim "$@"
