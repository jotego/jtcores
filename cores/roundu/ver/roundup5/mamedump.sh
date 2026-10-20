#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 20-10-2026

set -euo pipefail
setdir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
core=$(cd -- "$setdir/../.." && pwd -P)
mame=${MAME_BINARY:-/Users/andreabogazzi/Emus/mame0276-arm64/mame}
rompath=${MAME_ROMPATH:-$HOME/.mame/roms-local}
output="$setdir/scenes"
work="$setdir/scratch/mamedump"
manual=0
replace=0
frames=()
usage() {
    cat <<'HELP'
Usage: mamedump.sh [--replace] [--output DIR] FRAME [FRAME ...]
       mamedump.sh --manual [--output DIR] [--replace]
No frames: capture 300, 600, ... 6000. Manual capture key: backslash (\).
MAME_BINARY selects MAME 0.282; MAME_ROMPATH selects the ROM directory.
Manual captures can also use mamedump.lua as a MAME startup script.
HELP
}
while [ "$#" -gt 0 ]; do
    case "$1" in
        --help|-h) usage; exit 0 ;;
        --manual) manual=1; shift ;;
        --frames) shift ;;
        --replace) replace=1; shift ;;
        --output) output=${2:?Missing output directory}; shift 2 ;;
        *)
            [[ "$1" =~ ^[0-9]+$ ]] && (( 10#$1 > 0 )) || { usage >&2; exit 2; }
            frames+=("$((10#$1))"); shift ;;
    esac
done
if [ "$manual" = 1 ] && [ "${#frames[@]}" -ne 0 ]; then
    echo 'Use frame numbers or --manual' >&2; exit 2
fi
[ -x "$mame" ] || { echo 'Set MAME_BINARY to your MAME 0.282 executable' >&2; exit 1; }
version=$("$mame" -help)
version=${version%%$'\n'*}
case "$version" in "MAME v0.282 "*) ;; *) echo "Expected MAME 0.282; got $version" >&2; exit 1 ;; esac
expected_mmr=d44de92a49fa2e78115f41cf23199ca60ad0a8a793ce66d9612448e88447727e
actual_mmr=$(shasum -a 256 "$core/cfg/mmr.yaml")
[ "${actual_mmr%% *}" = "$expected_mmr" ] || { echo 'cfg/mmr.yaml changed; regenerate the MAME capture/restore binding' >&2; exit 1; }
mkdir -p "$output" "$work"
output=$(cd -- "$output" && pwd -P)
printf '%s\n%s\n' "$version" "$mame" > "$work/session.log"
settings="$work/settings"
rm -rf -- "$settings"
mkdir -p "$settings"
export MAMEDUMP_OUTPUT="$output" MAMEDUMP_WORK="$work" MAMEDUMP_REPLACE="$replace"
unset MAMEDUMP_FRAME
common=(roundup5 -rompath "$rompath" -noreadconfig -inipath "$settings" -homepath "$settings"
    -cfg_directory "$settings" -nvram_directory "$settings" -snapshot_directory "$settings"
    -video soft -window -skip_gameinfo -snapview native -nosnapbilinear
    -autoboot_script "$setdir/mamedump.lua" -autoboot_delay 0)
if [ "$manual" = 1 ]; then
    echo "Play Round Up 5; press backslash (\\) to capture. Scenes: $output"
    exec "$mame" "${common[@]}"
fi
if [ "${#frames[@]}" -eq 0 ]; then
    for ((frame=300;frame<=6000;frame+=300)); do frames+=("$frame"); done
fi
selected=$(printf '%s\n' "${frames[@]}" | sort -nu)
for frame in $selected; do
    if [ -e "$output/$frame" ] && [ "$replace" != 1 ]; then
        echo "$output/$frame exists; use --replace" >&2; exit 1
    fi
done
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
for frame in $selected; do
    rm -rf -- "$settings"
    mkdir -p "$settings"
    export MAMEDUMP_FRAME="$frame"
    if ! "$mame" "${common[@]}" -sound none -nothrottle -seconds_to_run "$((frame/57+5))" > "$work/$frame.log" 2>&1; then
        echo "MAME failed; see $work/$frame.log" >&2; exit 1
    fi
    grep -q "MAMEDUMP_OK frame=$frame reference=$((frame+1)) " "$work/$frame.log" || {
        echo "Capture failed; see $work/$frame.log" >&2; exit 1;
    }
    [ "$(wc -c < "$output/$frame/dump.bin" | tr -d ' ')" = 309850 ]
    [ "$(wc -c < "$output/$frame/mmr.bin" | tr -d ' ')" = 612 ]
    printf 'Captured %s\n' "$output/$frame"
done
