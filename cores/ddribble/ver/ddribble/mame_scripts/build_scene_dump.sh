#!/bin/bash -e
# build_scene_dump.sh — assemble dump.bin for jtsim scene replay (-s) from the
# per-region MAME captures (fgram/bgram/spr0/spr1/pal) that dump_sprites.lua
# wrote into each scenes/mame_<frame>/ directory.
#
# Layout MUST match ver/game/rest2bin.sh:
#   0x0000  4096  fgram (chip 1 tile RAM)
#   0x1000  4096  bgram (chip 2 tile RAM)
#   0x2000  4096  chip 1 OBJ RAM (spr0 256 B + zero pad to 4 KB)
#   0x3000  4096  chip 2 OBJ RAM (spr1 512 B + zero pad to 4 KB)
#   0x4000   128  palette
#
# Usage (from repo root):
#   cores/ddribble/ver/ddribble/mame_scripts/build_scene_dump.sh \
#       cores/ddribble/ver/ddribble/scenes/mame_01500 \
#       cores/ddribble/ver/ddribble/scenes/mame_01800
# (no args => every scenes/mame_* dir)

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENES="$HERE/../scenes"

dirs=("$@")
if [ ${#dirs[@]} -eq 0 ]; then dirs=("$SCENES"/mame_*); fi

pad() { # pad file $1 up to $2 bytes with zeros, append to dump.bin
    local f="$1" want="$2" have
    have=$(wc -c < "$f")
    cat "$f" >> dump.bin
    if [ "$have" -lt "$want" ]; then
        dd if=/dev/zero bs=1 count=$((want-have)) 2>/dev/null >> dump.bin
    fi
}

for d in "${dirs[@]}"; do
    [ -d "$d" ] || { echo "skip (not a dir): $d"; continue; }
    ( cd "$d"
      for f in fgram.bin bgram.bin spr0.bin spr1.bin pal.bin; do
          [ -e "$f" ] || { echo "missing $d/$f" >&2; exit 1; }
      done
      : > dump.bin
      pad fgram.bin 4096
      pad bgram.bin 4096
      pad spr0.bin  4096
      pad spr1.bin  4096
      cat pal.bin >> dump.bin
      echo "$d/dump.bin = $(wc -c < dump.bin) bytes (expect 16512)"
    )
done
