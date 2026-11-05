#!/bin/bash
# Burst-capture wrapper for Ninja Emaki: one MAME run, 15 scene snapshots.
# Usage: ./burst_capture.sh   (MAME=... ROMS_HOST=... override defaults)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JTROOT="$(cd "$HERE/../../../../.." && pwd)"
LUA="$HERE/../mame_scripts/dump_burst.lua"
SETNAME=ninjemak
RUN_SECS=80

MAME="${MAME:-$HOME/Emus/mame0276-arm64/mame}"
ROMPATH="${ROMS_HOST:-$HOME/.mame/roms}"

[ -f "$LUA" ] || { echo "missing $LUA" >&2; exit 1; }

echo ">> launching MAME burst capture ($SETNAME, ${RUN_SECS}s) ..."
rm -f /tmp/nnjema_burst_*
"$MAME" "$SETNAME" -rompath "$ROMPATH" -autoboot_script "$LUA" \
    -autoboot_delay 1 -nothrottle -video none -sound none -seconds_to_run "$RUN_SECS" || true

cd "$HERE"
count=0
for dump in /tmp/nnjema_burst_*_dump.bin; do
    [ -f "$dump" ] || continue
    frame=$(echo "$dump" | sed -E 's|.*_burst_([0-9]+)_dump\.bin|\1|')
    dst="$HERE/burst_${frame}"
    mkdir -p "$dst"
    cp "$dump" "$dst/dump.bin"
    [ -f "/tmp/nnjema_burst_${frame}_screen.png" ] && \
        cp "/tmp/nnjema_burst_${frame}_screen.png" "$dst/screen.png"
    echo "  burst_${frame}  ($(wc -c < "$dst/dump.bin") bytes)"
    count=$((count + 1))
done
echo "Captured $count scenes under $HERE/"
