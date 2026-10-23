#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -e

CAPTURE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if (( $# != 1 )); then
    echo "Usage: $0 scene-directory" >&2
    exit 1
fi

SCENE_DIR=$1
[[ -d "$SCENE_DIR" ]] || { echo "Cannot find scene $SCENE_DIR" >&2; exit 1; }
SCENE_DIR=$(cd -- "$SCENE_DIR" && pwd)
SCENE_CONFIG="$SCENE_DIR/scene.lua"
[[ -f "$SCENE_CONFIG" ]] || { echo "Cannot find $SCENE_CONFIG" >&2; exit 1; }

MAME_CMD=${MZONE_MAME:-mame}
if ! command -v "$MAME_CMD" >/dev/null 2>&1; then
    echo "Cannot find MAME. Set MZONE_MAME to its executable." >&2
    exit 1
fi

export SDL_VIDEODRIVER=${SDL_VIDEODRIVER:-dummy}
export SDL_AUDIODRIVER=${SDL_AUDIODRIVER:-dummy}

RUN_DIR=$(mktemp -d)
trap 'rm -rf -- "$RUN_DIR"' EXIT
mkdir -p "$RUN_DIR/cfg" "$RUN_DIR/nvram" "$RUN_DIR/snap"

MAME_ARGS=(
    megazone
    -video none
    -sound none
    -nothrottle
    -seconds_to_run 300
    -skip_gameinfo
    -cfg_directory "$RUN_DIR/cfg"
    -nvram_directory "$RUN_DIR/nvram"
    -snapshot_directory "$RUN_DIR/snap"
    -autoboot_script "$CAPTURE_DIR/capture.lua"
)

MAME_ROMPATH=${MZONE_MAME_ROMS:-${HOME:+$HOME/.mame/roms}}
if [[ -n "$MAME_ROMPATH" && -d "$MAME_ROMPATH" ]]; then
    MAME_ARGS+=( -rompath "$MAME_ROMPATH" )
fi

CAPTURE_MARKER="$SCENE_DIR/.capture-complete"
rm -f -- "$CAPTURE_MARKER"

set +e
MZONE_SCENE_OUT="$SCENE_DIR" MZONE_SCENE_CONFIG="$SCENE_CONFIG" \
    "$MAME_CMD" "${MAME_ARGS[@]}"
MAME_STATUS=$?
set -e

if [[ ! -f "$CAPTURE_MARKER" ]]; then
    echo "MAME did not complete the scene capture." >&2
    (( MAME_STATUS == 0 )) && MAME_STATUS=1
    exit "$MAME_STATUS"
fi
rm -f -- "$CAPTURE_MARKER"

declare -A EXPECTED_SIZE=(
    [vram0.bin]=1024
    [vram1.bin]=1024
    [cram0.bin]=1024
    [cram1.bin]=1024
    [obj.bin]=1024
    [shared.bin]=2048
    [regs.hex]=9
)

for SCENE_FILE in "${!EXPECTED_SIZE[@]}"; do
    ACTUAL_SIZE=$(stat -c %s "$SCENE_DIR/$SCENE_FILE" 2>/dev/null || true)
    if [[ "$ACTUAL_SIZE" != "${EXPECTED_SIZE[$SCENE_FILE]}" ]]; then
        echo "Invalid scene file $SCENE_FILE: expected ${EXPECTED_SIZE[$SCENE_FILE]} bytes, got ${ACTUAL_SIZE:-missing}." >&2
        exit 1
    fi
done

if (( MAME_STATUS == 139 )); then
    echo "MAME exited with status $MAME_STATUS after completing the capture; accepting the validated files." >&2
elif (( MAME_STATUS != 0 )); then
    echo "MAME exited with unexpected status $MAME_STATUS." >&2
    exit "$MAME_STATUS"
fi
