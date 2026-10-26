#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 25-10-2026

set -euo pipefail

task_root=$(cd "$(dirname "$0")/../../../.." && pwd)
image=${SIM_IMAGE:-jotego/simulator:arm64}
target=${SIM_TARGET:-mister}
case "$target" in
    mister|sidi128) ;;
    *) echo "SIM_TARGET must be mister or sidi128" >&2; exit 1 ;;
esac
frames=${1:-360}
[[ "$frames" =~ ^[1-9][0-9]*$ ]] || { echo "Usage: $0 [frames] [jtsim options]" >&2; exit 1; }
if [ "$#" -gt 0 ]; then shift; fi
docker image inspect "$image" >/dev/null
mkdir -p "$task_root/cores/f1gpr2/ver/f1gp2/scratch/bin"

docker run --rm --pull=never \
    -e SIM_TARGET="$target" \
    -v "$task_root:/jtroot" \
    -w /jtroot/cores/f1gpr2/ver/f1gp2 \
    "$image" -lc '
        set -euo pipefail
        export JTROOT=/jtroot JTFRAME=/jtroot/modules/jtframe
        export MODULES=/jtroot/modules CORES=/jtroot/cores
        export JTBIN=/jtroot/release ROM=/jtroot/rom
        export RLS=/jtroot/release MRA=/jtroot/release/mra
        export PATH="$PWD/scratch/bin:$JTFRAME/bin:$PATH"
        if [ ! -x scratch/bin/jtframe ] ||
           [ -n "$(find "$JTFRAME/src/jtframe" -name "*.go" -newer scratch/bin/jtframe -print -quit)" ]; then
            (cd "$JTFRAME/src/jtframe" && go build -o "$CORES/f1gpr2/ver/f1gp2/scratch/bin/jtframe" .)
        fi
        "$CORES/f1gpr2/ver/game/rest2bin.sh" --delete
        jtsim -setname f1gp2 -skipROM "-$SIM_TARGET" -load -u JTFRAME_180SHIFT -video "$@"
    ' sim "$frames" "$@"
