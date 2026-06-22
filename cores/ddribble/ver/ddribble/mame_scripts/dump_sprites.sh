#!/bin/bash
# dump_sprites.sh — run MAME ddribble with dump_sprites.lua, then collate the
# /tmp dumps into ver/ddribble/scenes/<frame>/ for offline analysis.
#
# Produces, per captured frame, a scenes/mame_<frame>/ folder with:
#   spr0.bin spr1.bin fgram.bin bgram.bin screen.png sprites.txt
#
# These are the GROUND TRUTH (real 005885) sprite bytes + the rendered
# result, used to validate jtddribble_5885_7121_obj.v's parse.
#
# Usage (from repo root):
#   cores/ddribble/ver/ddribble/mame_scripts/dump_sprites.sh [seconds]
#
# Requires: host MAME 0.276 + ddribble.zip on a rompath. Tries the local
# copy first, then the network share.

set -e
MAME=~/Emus/mame0276-arm64/mame
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENES="$HERE/../scenes"
SECS="${1:-65}"

# Pick a rompath that actually has ddribble.zip
ROMPATH=""
for cand in "$HOME/.mame/roms-local" "$HOME/.mame/roms" /tmp/mrom; do
    if [ -e "$cand/ddribble.zip" ]; then ROMPATH="$cand"; break; fi
done
if [ -z "$ROMPATH" ]; then
    echo "error: ddribble.zip not found in ~/.mame/roms-local, ~/.mame/roms, or /tmp/mrom" >&2
    exit 1
fi
echo "Using rompath: $ROMPATH"

rm -f /tmp/ddribble_*_pal.bin /tmp/ddribble_*_spr0.bin /tmp/ddribble_*_spr1.bin \
      /tmp/ddribble_*_fgram.bin /tmp/ddribble_*_bgram.bin \
      /tmp/ddribble_*_screen.png /tmp/ddribble_*_sprites.txt 2>/dev/null || true

# Use throwaway cfg/nvram dirs so NO persisted DIP (e.g. a leftover service-mode
# setting) is loaded — MAME falls back to the ROM's default DIPs (service OFF),
# i.e. a clean attract boot. Without this, cfg/ddribble.cfg from a prior
# interactive run can silently force service mode on.
CLEANCFG=$(mktemp -d)
trap 'rm -rf "$CLEANCFG"' EXIT
"$MAME" -rompath "$ROMPATH" ddribble \
    -cfg_directory "$CLEANCFG/cfg" -nvram_directory "$CLEANCFG/nvram" \
    -autoboot_script "$HERE/dump_sprites.lua" \
    -autoboot_delay 1 -nothrottle -video none -seconds_to_run "$SECS" || true

# Collate by frame number
shopt -s nullglob
for f in /tmp/ddribble_*_sprites.txt; do
    base=$(basename "$f" _sprites.txt)          # ddribble_01200
    frame=${base#ddribble_}                      # 01200
    dst="$SCENES/mame_$frame"
    mkdir -p "$dst"
    for suf in pal.bin spr0.bin spr1.bin fgram.bin bgram.bin screen.png sprites.txt; do
        [ -e "/tmp/${base}_${suf}" ] && cp "/tmp/${base}_${suf}" "$dst/$suf"
    done
    echo "collated $dst"
done
echo "Done. Scenes under: $SCENES"
