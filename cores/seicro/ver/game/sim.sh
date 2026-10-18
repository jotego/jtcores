#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 15-10-2026

set -euo pipefail
seicro_repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd -P)
seicro_image=${JTFRAME_SIM_IMAGE:-jotego/simulator:arm64}
seicro_rompath=${MAME_ROMPATH:-$seicro_repo/cores/seicro/ver/game/roms}
if [ ! -d "$seicro_rompath" ]; then seicro_rompath=$HOME/.mame/roms-local; fi
seicro_set=sectrzont
if [ "${1:-}" = --set ]; then
    seicro_set=${2:?Missing set name}
    shift 2
fi
case "$seicro_set" in
    seicross|seicrossa|sectrzon|sectrzona|sectrzont|friskyt|friskyta|friskytb|radrad|radradj) ;;
    *) printf 'Unsupported set: %s\n' "$seicro_set" >&2; exit 1 ;;
esac
mkdir -p "$seicro_repo/cores/seicro/ver/$seicro_set"
if [ ! -e "$seicro_repo/cores/seicro/ver/$seicro_set/boot.cab" ]; then
    case "$seicro_set" in
        friskyt*) seicro_cab=$seicro_repo/cores/seicro/ver/game/friskyt.cab ;;
        radrad*) seicro_cab=$seicro_repo/cores/seicro/ver/game/radrad.cab ;;
        *) seicro_cab=$seicro_repo/cores/seicro/ver/game/seicross.cab ;;
    esac
    cp "$seicro_cab" "$seicro_repo/cores/seicro/ver/$seicro_set/boot.cab"
fi
if [ "$#" -eq 0 ]; then
    case "$seicro_set" in
        friskyt*) set -- -video 1150 -time 20000 boot.cab ;;
        radrad*) set -- -video 560 -time 10000 boot.cab ;;
        *) set -- -video 360 -time 6000 boot.cab ;;
    esac
fi
docker image inspect "$seicro_image" >/dev/null
docker run --rm --pull=never \
    -v "$seicro_repo:/jtcores" \
    -v "$seicro_repo/modules:/jtcores/modules:ro" \
    -v "$seicro_rompath:/romzips:ro" \
    -e SEICRO_SET="$seicro_set" \
    -w "/jtcores/cores/seicro/ver/$seicro_set" \
    "$seicro_image" -lc '
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
        export PATH=$CORES/seicro/ver/game:$JTFRAME/bin:$PATH
        export JTFRAME_REGRESSION=1
        unset VERILATOR_ROOT
        cd "$JTFRAME/src/jtframe"
        go build -o "$CORES/seicro/ver/game/jtframe" .
        cd "$JTFRAME/src/jtutil"
        go build -o "$CORES/seicro/ver/game/jtutil" .
        cd "$CORES/seicro/ver/$SEICRO_SET"
        jtframe mra seicro --path /romzips --skipPocket > rom-build.log 2>&1
        case "$SEICRO_SET" in
            friskyt*)
                export SEICRO_NVRAM_FILE="$ROM/${SEICRO_SET^^}.RAM"
                if [ -f boot.nvm ]; then export SEICRO_NVRAM_FILE="$PWD/boot.nvm"; fi
                ;;
            *) unset SEICRO_NVRAM_FILE ;;
        esac
        jtsim -setname "$SEICRO_SET" -skipROM -mister -load -batch -fast "$@"
    ' seicro-sim "$@"
