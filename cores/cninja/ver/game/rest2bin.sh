#!/bin/bash -e
# Split rest.bin (= the scene dump, since cninja has no mem.yaml ioctl blocks)
# into the per-RAM images the NOMAIN video BRAMs load through SIMFILE.
#
# The layout is fixed for all four boards - ver/cninja/mame_scripts/dump_scene.lua
# zero pads every region up to its slot. The register blocks at the front are
# NOT split out: jtdeco16ic_mmr and jtframe_simdumper read rest.bin directly at
# their SEEK offsets (0, 16 and 32).
#
#   0x0000  0x0040  registers (2x deco16ic control + board priority)
#   0x0040  0x2000  pal    0x2040  0x2000  t0p1   0x4040  0x2000  t0p2
#   0x6040  0x2000  t1p1   0x8040  0x2000  t1p2
#   0xA040  0x1000  rs0    0xB040  0x1000  rs1    0xC040  0x0800  oram
REST=rest.bin
EXPECTED=51264      # 0xC840

[ -e "$REST" ] || { echo "rest2bin: $REST not found" >&2; exit 1; }
SZ=$(wc -c < "$REST")
if [ "$SZ" -ne "$EXPECTED" ]; then
    echo "rest2bin: $REST is $SZ bytes, expected $EXPECTED." >&2
    echo "          Re-capture the scene with the current dump_scene.lua." >&2
    exit 1
fi

cut() { # name offset length
    dd if="$REST" of="$1" bs=1 skip="$2" count="$3" status=none
}

cut pal.bin   $((0x0040)) $((0x2000))
cut t0p1.bin  $((0x2040)) $((0x2000))
cut t0p2.bin  $((0x4040)) $((0x2000))
cut t1p1.bin  $((0x6040)) $((0x2000))
cut t1p2.bin  $((0x8040)) $((0x2000))
cut rs0.bin   $((0xA040)) $((0x1000))
cut rs1.bin   $((0xB040)) $((0x1000))
cut oram.bin  $((0xC040)) $((0x0800))
