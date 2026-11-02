#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -e

# ROMs must already exist as $ROM/<setname>.rom; default: megazone.
SIM_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SETNAME=${MZONE_SETNAME:-megazone}
SIM_ARGS=()
while (( $# )); do
    case "$1" in
        -g)
            [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || {
                echo "Usage: $0 [-g setname] [-s scene] [jtsim options]" >&2
                exit 1
            }
            SETNAME=$2; shift 2 ;;
        --scene) SIM_ARGS+=(-s); shift ;;
        *) SIM_ARGS+=("$1"); shift ;;
    esac
done

# jtsim owns scene linking, dump splitting and simulation macros. Run in the
# ROM-set directory so its scenes symlink can target $JOTEGO/scenes/mzone/$SETNAME.
mkdir -p -- "$SIM_DIR/../$SETNAME"
cd -- "$SIM_DIR/../$SETNAME"
jtframe mem mzone --target mist
exec jtsim -mist -setname "$SETNAME" -skipROM -load "${SIM_ARGS[@]}"
