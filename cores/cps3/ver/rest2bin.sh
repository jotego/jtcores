#!/bin/bash
# CPS3 scene payload after the 128-byte EEPROM and generated BRAM chunks.
set -euo pipefail

readonly REST=rest.bin
readonly SCENE_BYTES=$((0x002000))
readonly PAL_BYTES=$((0x040000))
readonly SSCHAR_BYTES=$((0x004000))
readonly SSMAP_BYTES=$((0x002000))
readonly SSSCR_BYTES=$((0x002000))
readonly SPRITERAM_BYTES=$((0x080000))
readonly TILECHAR_BYTES=$((0x800000))
readonly PPUREG_BYTES=$((0x0000b0))
readonly SSREG_BYTES=$((0x000016))
readonly DMAST_BYTES=$((0x000002))
readonly EXPECTED_BYTES=$((SCENE_BYTES + PAL_BYTES + SSCHAR_BYTES + SSMAP_BYTES + SSSCR_BYTES + SPRITERAM_BYTES + TILECHAR_BYTES + PPUREG_BYTES + SSREG_BYTES + DMAST_BYTES))

if [ "${1:-}" = "--delete" ]; then
    rm -f scene.bin pal.bin pal_hi.bin pal_lo.bin \
        sschar.bin sschar_hi.bin sschar_lo.bin \
        ssmap.bin ssmap_hi.bin ssmap_lo.bin \
        ssscr.bin ssscr_hi.bin ssscr_lo.bin \
        spriteram.bin tilechar.bin ppureg.bin ssreg.bin dmast.bin
    exit 0
fi

test -f "$REST" || { echo "Missing $REST" >&2; exit 1; }
actual_bytes=$(stat -c %s "$REST")
if [ "$actual_bytes" -ne "$EXPECTED_BYTES" ]; then
    echo "Invalid CPS3 scene payload: $REST is $actual_bytes bytes, expected $EXPECTED_BYTES" >&2
    exit 1
fi

split() {
    local name=$1 bytes=$2 skip=$3
    dd if="$REST" of="$name" bs=1 count="$bytes" skip="$skip" status=none
    test "$(stat -c %s "$name")" -eq "$bytes"
}

offset=0
split scene.bin      "$SCENE_BYTES"      "$offset"; offset=$((offset + SCENE_BYTES))
split pal.bin        "$PAL_BYTES"        "$offset"; offset=$((offset + PAL_BYTES))
split sschar.bin     "$SSCHAR_BYTES"     "$offset"; offset=$((offset + SSCHAR_BYTES))
split ssmap.bin      "$SSMAP_BYTES"      "$offset"; offset=$((offset + SSMAP_BYTES))
split ssscr.bin      "$SSSCR_BYTES"      "$offset"; offset=$((offset + SSSCR_BYTES))
split spriteram.bin "$SPRITERAM_BYTES" "$offset"; offset=$((offset + SPRITERAM_BYTES))
split tilechar.bin  "$TILECHAR_BYTES"  "$offset"; offset=$((offset + TILECHAR_BYTES))
split ppureg.bin    "$PPUREG_BYTES"    "$offset"; offset=$((offset + PPUREG_BYTES))
split ssreg.bin     "$SSREG_BYTES"     "$offset"; offset=$((offset + SSREG_BYTES))
split dmast.bin     "$DMAST_BYTES"     "$offset"

# The two SDRAM images are deliberately overlaid only for simulation. Normal
# IOCTL save/restore remains the 128-byte EEPROM block declared in mem.yaml.
jtutil sdram --sim
