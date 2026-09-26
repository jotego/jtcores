#!/bin/bash
# Copy a captured scene's RAM images into ver/game/ so the next sim starts with
# them. Run the sim with -d NOMAIN so the 68000 does not overwrite them:
#
#   cores/blkpan/ver/blkpnthr/scenes/load_scene.sh 1200
#   FRAMES=4 ROMS_HOST=~/mameroms ./sim-core.sh blkpan blkpnthr -d NOMAIN
#
set -euo pipefail
FRAME=${1:?usage: load_scene.sh <frame>}
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SRC="$HERE/burst_$(printf %05d "$FRAME")"
[ -d "$SRC" ] || SRC="/tmp/blkpan_scene_$(printf %05d "$FRAME")"
[ -d "$SRC" ] || { echo "no scene for frame $FRAME"; exit 1; }
DST="$HERE/../../game"
mkdir -p "$DST"
cp "$SRC"/*.hex "$SRC"/pal.bin "$DST"/
echo "loaded scene $FRAME from $SRC into $DST"
ls "$DST"/*.hex "$DST"/pal.bin | sed 's|.*/|  |'

# NOTE: these files stay in ver/game and are read by ANY later sim. Before a
# normal full run, clear them:
#   rm -f cores/blkpan/ver/game/{charram*.hex,objram.hex,scrollram.hex,vram1_*.hex,vram2.hex,pal.bin}
