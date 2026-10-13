#!/bin/bash
# Select exactly the defaults described by the generated MRA, or an explicit
# MiSTer saved image. No cfg override guessing or MAME live-NVRAM reuse.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
JTROOT=${JTROOT:-$(cd "$HERE/../../.." && pwd)}
SET=${1:?Usage: prepare_nvram.sh SET [OUTPUT]}
OUTPUT=${2:-"$HERE/game/nvram.seed"}
MRA_DIR=${MRA_DIR:-"$JTROOT/release/mra"}
ROMS_HOST=${ROMS_HOST:-"$HOME/.mame/roms-local"}
[[ "$SET" =~ ^[a-z0-9_]+$ ]] || { echo "Invalid set name: $SET" >&2; exit 1; }
mkdir -p "$(dirname "$OUTPUT")"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/osman-nvram.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
fail() { echo "$*" >&2; exit 1; }

if [[ -n ${NVRAM_FILE:-} ]]; then
    cp "$NVRAM_FILE" "$WORK/seed"
else
    MRA=
    while IFS= read -r file; do
        [[ -z "$MRA" ]] || fail "Multiple MRAs for $SET in $MRA_DIR"
        MRA=$file
    done < <(rg -l --glob '*.mra' "<setname>$SET</setname>" "$MRA_DIR")
    [[ -n "$MRA" ]] || fail "No generated MRA for $SET; regenerate osman MRAs first"
    NODE='/misterromdescription/rom[@index="2"]'
    xpath() { xmllint --xpath "$1" "$MRA"; }
    [[ $(xpath 'string(/misterromdescription/nvram/@size)') == 128 ]] || fail "MRA NVRAM size must be 128"
    [[ $(xpath "count($NODE/part)") == 1 ]] || fail "Expected one default EEPROM part"
    NAME=$(xpath "string($NODE/part/@name)")
    if [[ -z "$NAME" ]]; then
        xpath "string($NODE/part)" | tr -d '[:space:]' > "$WORK/hex"
        [[ $(wc -c < "$WORK/hex") -eq 256 ]] || fail "MRA must contain 128 literal default bytes"
        [[ $(tr -d '0-9A-Fa-f' < "$WORK/hex" | wc -c) -eq 0 ]] || fail "Invalid default byte data"
        xxd -r -p "$WORK/hex" > "$WORK/seed"
    else
        CRC=$(xpath "string($NODE/part/@crc)")
        IFS='|' read -r -a ZIP_NAMES <<< "$(xpath "string($NODE/@zip)")"
        IFS=':' read -r -a ROM_PATHS <<< "$ROMS_HOST"
        FOUND=
        for archive_name in "${ZIP_NAMES[@]}"; do
            for rom_path in "${ROM_PATHS[@]}"; do
                archive="$rom_path/$archive_name"
                [[ -f "$archive" ]] || continue
                unzip -Z -1 "$archive" > "$WORK/members"
                while IFS= read -r member; do
                    [[ ${member##*/} == "$NAME" ]] || continue
                    actual_crc=$(unzip -v "$archive" "$member" | awk 'NF>=8 && $1 ~ /^[0-9]+$/ { print $7 }')
                    [[ "$actual_crc" == "$CRC" ]] || continue
                    unzip -p "$archive" "$member" > "$WORK/seed"
                    FOUND=1
                    break
                done < "$WORK/members"
                [[ -z "$FOUND" ]] || break
            done
            [[ -z "$FOUND" ]] || break
        done
        [[ -n "$FOUND" ]] || fail "Missing $NAME (CRC $CRC) in MRA ZIP search list"
    fi
fi
[[ $(wc -c < "$WORK/seed") -eq 128 ]] || fail "EEPROM image must be exactly 128 bytes"
cp "$WORK/seed" "$OUTPUT"
echo "$SET: prepared 128 EEPROM bytes in $OUTPUT"
