#!/bin/bash
# SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

main() {
    local setname=${1:?Usage: scene.sh setname scene}
    local scene=${2:?Usage: scene.sh setname scene}
    : "${JTFRAME:?Source setprj.sh first}"
    : "${JOTEGO:?Set the private support directory}"
    cd "$(dirname "$0")/$setname"
    jtutil sdram
    prepare_graphics_roms
    local candidate="scenes/$scene/$scene.png"
    if [ -L scenes ]; then rm -f "$candidate"; fi
    # jtsim copies the final field; the MAME reference contains both fields.
    JTFRAME_SCENE_COMPARE_SKIP=1 jtsim -load -s "$scene" -batch
    source "$JTFRAME/bin/jtsim-funcs"
    SCENE="scenes/$scene/dump.bin"
    if [ ! -s "$candidate" ]; then
        local frame
        frame=$(last_frame_image)
        test -s "$frame"
        cp "$frame" "$candidate"
    fi
    compare_field "$candidate" "scenes/$scene/snapshot.png"
}

prepare_graphics_roms() {
    # The four-byte board header precedes the graphics regions in the .rom.
    # These files initialize simulation BRAMs before ioctl download begins.
    dd if=rom.bin of=char.bin bs=1 skip=$((0x8000 + 4)) count=4096 status=none
    local bank offset
    for bank in 0 1 2 3; do
        offset=$((0x9000 + 4 + bank*0x2000))
        dd if=rom.bin bs=1 skip="$offset" count=8192 status=none | jtutil drop1 -l > "obj${bank}_lo.bin"
        dd if=rom.bin bs=1 skip="$offset" count=8192 status=none | jtutil drop1 > "obj${bank}_hi.bin"
    done
}

compare_field() (
    local candidate=$1 reference=$2
    local rw rh cw ch mean_abs nonblank tmp
    test -s "$reference"
    rw=$(identify -format '%w' "$reference")
    rh=$(identify -format '%h' "$reference")
    cw=$(identify -format '%w' "$candidate")
    ch=$(identify -format '%h' "$candidate")
    if [ "$rw" -ne "$cw" ] || [ "$rh" -ne "$((2*ch))" ]; then
        echo "Scene field compare: FAIL geometry reference=${rw}x${rh} core=${cw}x${ch}"
        return 1
    fi
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    convert "$reference" -sample "${cw}x${ch}!" "$tmp/reference-field.png"
    convert "$tmp/reference-field.png" "$candidate" -compose difference -composite "$tmp/diff.png"
    mean_abs=$(identify -format '%[fx:mean*255]' "$tmp/diff.png")
    nonblank=$(identify -format '%[fx:mean*255]' "$candidate")
    # Dynamic objects differ between a sampled field and MAME's two-field
    # snapshot; all four gameplay sets stay below 12 RGB levels on average.
    if ! awk -v d="$mean_abs" -v b="$nonblank" 'BEGIN { exit !(d < 12 && b > 1) }'; then
        echo "Scene field compare: FAIL mean_abs=$mean_abs nonblank=$nonblank"
        return 1
    fi
    echo "Scene field compare: PASS mean_abs=$mean_abs nonblank=$nonblank"
)

main "$@"
