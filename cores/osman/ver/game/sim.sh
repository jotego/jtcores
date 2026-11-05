#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 5-11-2026
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
JTROOT=$(cd "$HERE/../../../.." && pwd)
SET=${1:-wcvol95}
FRAMES=${2:-180}
CAB=${3:-}
ROMS_HOST=${ROMS_HOST:-"$HOME/.mame/roms-local"}
IMAGE=${IMAGE:-jotego/simulator:arm64}
[[ "$SET" =~ ^[a-z0-9_]+$ ]] || { echo "Invalid set: $SET" >&2; exit 1; }
[[ "$FRAMES" =~ ^[1-9][0-9]*$ ]] || { echo "Invalid frame count: $FRAMES" >&2; exit 1; }
[[ -d "$ROMS_HOST" ]] || { echo "ROM folder unavailable: $ROMS_HOST" >&2; exit 1; }
if [[ -n "$CAB" ]]; then
    [[ -f "$CAB" ]] || { echo "Cabinet script unavailable: $CAB" >&2; exit 1; }
    CAB=$(cd "$(dirname "$CAB")" && pwd)/$(basename "$CAB")
    [[ "$CAB" == "$JTROOT/"* ]] || { echo "Cabinet script must be inside the repository" >&2; exit 1; }
    CAB=/jtcores/${CAB#"$JTROOT/"}
fi
export JTROOT JTFRAME="$JTROOT/modules/jtframe" CORES="$JTROOT/cores"
export MODULES="$JTROOT/modules" JTBIN="$JTROOT/release"
docker image inspect "$IMAGE" >/dev/null
"$JTFRAME/bin/jtframemac" mra osman --setname "$SET" --path "$ROMS_HOST" --skipPocket --nodbg
[[ -s "$JTROOT/rom/$SET.rom" ]] || { echo "ROM generation failed for $SET" >&2; exit 1; }
RUN="$CORES/osman/ver/$SET"
mkdir -p "$RUN"
bash "$HERE/../prepare_nvram.sh" "$SET" "$RUN/nvram.seed"
cp "$HERE/rest2bin.sh" "$RUN/rest2bin.sh"
chmod +x "$RUN/rest2bin.sh"
docker run --rm --pull=never \
    -v "$JTROOT:/jtcores" -v "$ROMS_HOST:/roms:ro" \
    -e OSMAN_SET="$SET" -e OSMAN_FRAMES="$FRAMES" -e OSMAN_CAB="$CAB" \
    -w "/jtcores/cores/osman/ver/$SET" "$IMAGE" -c '
        unset VERILATOR_ROOT
        export JTROOT=/jtcores JTFRAME=/jtcores/modules/jtframe MODULES=/jtcores/modules
        export CORES=/jtcores/cores JTBIN=/jtcores/release RLS=/jtcores/release
        export ROM=/jtcores/rom MRA=/jtcores/release/mra
        export PATH="$JTFRAME/bin:$PATH:."
        args=()
        if [[ -n "$OSMAN_CAB" ]]; then args+=("$OSMAN_CAB"); fi
        jtsim -setname "$OSMAN_SET" -skipROM -mister -u JTFRAME_180SHIFT -load -video "$OSMAN_FRAMES" "${args[@]}"
    ' > "$RUN/sim.log" 2>&1
tail -12 "$RUN/sim.log"
