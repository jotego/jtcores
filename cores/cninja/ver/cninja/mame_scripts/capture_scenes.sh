#!/bin/bash
# Capture a burst of scene dumps for one board of the cninja family.
#
#   capture_scenes.sh <setname> [first:last:step]
#
# Writes cores/cninja/ver/<setname>/scenes/<NNNN>/{dump.bin,screen.png}, both
# taken on the same frame. dump_scene.lua handles all four boards, so this is
# the single capture entry point; grade with tools/scenesim/.
set -euo pipefail

SETNAME=${1:?usage: capture_scenes.sh <setname> [first:last:step]}
FRAMES=${2:-300:6000:300}
MAME=${MAME:-$HOME/mame/mame}
ROMS=${ROMS:-$HOME/mameroms}

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE="$(cd "$HERE/../../.." && pwd)"
OUT="$CORE/ver/$SETNAME/scenes"

IFS=: read -r first last step <<<"$FRAMES"
for ((f=first; f<=last; f+=step)); do mkdir -p "$(printf '%s/%04d' "$OUT" "$f")"; done

# margin so the last target is reached
SECS=$(( last / 60 + 5 ))

# keep MAME's own cfg/nvram/snap out of the repo
CNJ_SCENE_BASE="$OUT" CNJ_SCENE_FRAMES="$FRAMES" \
    "$MAME" -rompath "$ROMS" "$SETNAME" -video none -sound none \
            -cfg_directory /tmp/mame_cfg -nvram_directory /tmp/mame_nvram \
            -snapshot_directory /tmp/mame_snap \
            -seconds_to_run "$SECS" -nothrottle \
            -autoboot_script "$HERE/dump_scene.lua"
