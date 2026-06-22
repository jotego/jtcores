#!/bin/bash -e
# rest2bin.sh — ddribble scene-replay splitter (per-core hook called by the
# framework dump2bin.sh after it copies the scene dump.bin to rest.bin).
#
# It splits rest.bin into the SIMFILE targets that the NOMAIN-mode BRAMs load:
#   gfx1_attr.bin / gfx1_code.bin / gfx1_obj.bin   (chip 1, FG  — u_k5885_1)
#   gfx2_attr.bin / gfx2_code.bin / gfx2_obj.bin   (chip 2, BG  — u_k5885_2)
#   pal.bin                                         (007327 palette BRAM)
#
# dump.bin layout (built by ../ddribble/mame_scripts/build_scene_dump.sh from
# the MAME captures), all regions packed back-to-back:
#   0x0000  4096   fgram  (chip 1 tile RAM, MAME 0x2000-0x2FFF)
#   0x1000  4096   bgram  (chip 2 tile RAM, MAME 0x6000-0x6FFF)
#   0x2000  4096   chip 1 OBJ RAM (MAME 0x3000-0x3FFF; spr0 256 B + zero pad)
#   0x3000  4096   chip 2 OBJ RAM (MAME 0x7000-0x7FFF; spr1 512 B + zero pad)
#   0x4000   128   palette (MAME 0x1800-0x187F)
#
# The 005885 splits each 4 KB tile RAM into a 2 KB attr BRAM and a 2 KB code
# BRAM using CPU address bit 10 (attr when ~A10, code when A10), and the BRAM
# index is {A11, A9:0} (A10 dropped). So the CPU's flat 4 KB image must be
# DE-INTERLEAVED into the two 2 KB BRAM images exactly as the HDL would have
# written them (jtddribble_5885_7121_gfx.v: ram_addr={addr[11],addr[9:0]},
# attr_we=~addr[10], code_we=addr[10]):
#   attr[0x000:0x400] = tile[0x000:0x400]   (A11=0, A10=0)
#   attr[0x400:0x800] = tile[0x800:0xC00]   (A11=1, A10=0)
#   code[0x000:0x400] = tile[0x400:0x800]   (A11=0, A10=1)
#   code[0x400:0x800] = tile[0xC00:0x1000]  (A11=1, A10=1)
# OBJ RAM is addressed directly (addr[11:0]) so it copies straight through.

REST=rest.bin
if [ ! -e "$REST" ]; then echo "rest2bin: $REST not found" >&2; exit 1; fi

# Pull each 4 KB region out of rest.bin (bs=4096 blocks).
dd if="$REST" of=fg.tmp  bs=4096 skip=0 count=1 2>/dev/null
dd if="$REST" of=bg.tmp  bs=4096 skip=1 count=1 2>/dev/null
dd if="$REST" of=gfx1_obj.bin bs=4096 skip=2 count=1 2>/dev/null
dd if="$REST" of=gfx2_obj.bin bs=4096 skip=3 count=1 2>/dev/null
# Palette: 128 B at byte offset 0x4000.
dd if="$REST" of=pal.bin bs=1 skip=16384 count=128 2>/dev/null

# De-interleave one 4 KB tile image ($1) into attr ($2) and code ($3) 2 KB BRAMs.
deint() {
    local src="$1" attr="$2" code="$3"
    # 1 KB blocks: 0,1,2,3 = tile[0x000,0x400,0x800,0xC00]
    dd if="$src" of="$attr"      bs=1024 skip=0 count=1 2>/dev/null            # attr lo  <- block0
    dd if="$src" bs=1024 skip=2 count=1 2>/dev/null >> "$attr"                 # attr hi  <- block2
    dd if="$src" of="$code"      bs=1024 skip=1 count=1 2>/dev/null            # code lo  <- block1
    dd if="$src" bs=1024 skip=3 count=1 2>/dev/null >> "$code"                 # code hi  <- block3
}
deint fg.tmp gfx1_attr.bin gfx1_code.bin
deint bg.tmp gfx2_attr.bin gfx2_code.bin

# New jtddribble_k005885 path: each chip has ONE 8 KB VRAM (tile 4 KB at A12=0,
# sprite 4 KB at A12=1), addressed by raw A[12:0] (no de-interleave). Build it.
cat fg.tmp gfx1_obj.bin > vram1.bin
cat bg.tmp gfx2_obj.bin > vram2.bin
rm -f fg.tmp bg.tmp

echo "rest2bin: gfx1 attr/code/obj $(wc -c <gfx1_attr.bin)/$(wc -c <gfx1_code.bin)/$(wc -c <gfx1_obj.bin)" \
     "gfx2 $(wc -c <gfx2_attr.bin)/$(wc -c <gfx2_code.bin)/$(wc -c <gfx2_obj.bin)" \
     "pal $(wc -c <pal.bin)"
