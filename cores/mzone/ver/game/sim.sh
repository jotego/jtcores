#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

# ROMs must already exist as $ROM/<setname>.rom; default: megazone.
SIM_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || exit 1
SETNAME=${MZONE_SETNAME:-megazone}
SCENE=
SIM_ARGS=()
while (( $# )); do
    case "$1" in
        -g|-s|--scene)
            [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || {
                echo "Usage: $0 [-g setname] [-s|--scene name] [jtsim options]" >&2
                exit 1
            }
            if [[ "$1" == -g ]]; then
                SETNAME=$2
            else
                SCENE=$2
            fi
            shift 2
            ;;
        *) SIM_ARGS+=("$1"); shift ;;
    esac
done

if [[ -n "$SCENE" ]]; then
    SCENE="$SIM_DIR/scenes/$SCENE"
    scene_files=(vram0.bin vram1.bin cram0.bin cram1.bin obj.bin shared.bin regs.hex)
    for file in "${scene_files[@]}"; do
        [[ -s "$SCENE/$file" ]] || {
            echo "Missing scene file: $SCENE/$file. Capture the scene first." >&2
            exit 1
        }
    done
    for file in "${scene_files[@]}"; do
        cp -- "$SCENE/$file" "$SIM_DIR/$file" || exit 1
    done
    cp -- "$SIM_DIR/shared.bin" "$SIM_DIR/main_shared.bin" || exit 1
    SIM_ARGS=(-d SIMSCENE -d NOMAIN -d NOSOUND -zoom -video 2 -w "${SIM_ARGS[@]}")
fi

cd -- "$SIM_DIR" || exit 1
exec jtsim -mist -setname "$SETNAME" \
    -skipROM -load -verilator "${SIM_ARGS[@]}"
