#!/bin/bash
# Burst-capture wrapper for Speed Racer: one MAME run, multiple scene dumps.
# Uses the freshly built subtarget binary ~/develop/mame/sysfl (latest driver).
#
# Usage:  ./burst_capture.sh        (MAME=... and ROMS_HOST=... override defaults)
#
# Output: ver/speedrcr/scenes/burst_<frame>/ with per-region .bin, dump.bin
#         (pal+vram+scrctl+rozram+rozctl+oram+regs order) and screen.png.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JTROOT="$(cd "$HERE/../../../../.." && pwd)"
LUA="$HERE/../mame_scripts/dump_burst.lua"
SETNAME=speedrcr
RUN_SECS=130

MAME="${MAME:-$HOME/develop/mame/sysfl}"
ROMPATH="${ROMS_HOST:-$HOME/develop/mame/roms}"

[ -x "$MAME" ] || { echo "missing MAME binary $MAME" >&2; exit 1; }
[ -f "$LUA"  ] || { echo "missing $LUA" >&2; exit 1; }

echo ">> launching MAME burst capture ($SETNAME, ${RUN_SECS}s, Lua=$LUA) ..."
rm -f /tmp/speedrcr_burst_*
"$MAME" "$SETNAME" -rompath "$ROMPATH" -autoboot_script "$LUA" \
    -autoboot_delay 1 -nothrottle -video none -sound none -seconds_to_run "$RUN_SECS" || true

cd "$HERE"
count=0
for pal in /tmp/speedrcr_burst_*_pal.bin; do
    [ -f "$pal" ] || continue
    frame=$(echo "$pal" | sed -E 's|.*_burst_([0-9]+)_pal\.bin|\1|')
    dst="$HERE/burst_${frame}"
    mkdir -p "$dst"
    for r in pal vram scrctl rozram rozctl oram regs; do
        cp "/tmp/speedrcr_burst_${frame}_${r}.bin" "$dst/${r}.bin"
    done
    [ -f "/tmp/speedrcr_burst_${frame}_screen.png" ] && \
        cp "/tmp/speedrcr_burst_${frame}_screen.png" "$dst/screen.png"
    echo "  burst_${frame}  ($(wc -c < "$dst/dump.bin") bytes)"
    count=$((count + 1))
done

python3 "$HERE/make_dump.py"

echo
echo "Captured $count scenes under $HERE/"
