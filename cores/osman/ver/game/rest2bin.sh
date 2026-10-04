#!/bin/bash -e
# Split rest.bin (= the scene dump; osman has no mem.yaml ioctl blocks) into the
# per-RAM images the NOMAIN video BRAMs load through SIMFILE. All regions are
# dense little-endian 16-bit, packed by ver/osman/mame_scripts/dump_burst.lua.
# The deco16ic control block at the front is NOT split out: jtdeco16ic_mmr reads
# rest.bin directly at its SEEK offset (0).
#
#   0x0000 0x0010 control | 0x0010 0x0800 pal | 0x0810 0x1000 pf1
#   0x1810 0x1000 pf2     | 0x2810 0x1000 rs1 | 0x3810 0x1000 rs2
#   0x4810 0x1000 oram    | total 0x5810
REST=rest.bin
if [ "${1:-}" = "--delete" ]; then
	rm -f pal.bin pf1.bin pf2.bin rs1.bin rs2.bin oram.bin
	exit 0
fi
EXPECTED=$((0x5810))
[ -e "$REST" ] || { echo "rest2bin: $REST not found" >&2; exit 1; }
SZ=$(wc -c < "$REST")
if [ "$SZ" -ne "$EXPECTED" ]; then
	echo "rest2bin: $REST is $SZ bytes, expected $EXPECTED." >&2
	echo "          Re-capture the scene with the current dump_burst.lua." >&2
	exit 1
fi

cut() { # name offset length
	dd if="$REST" of="$1" bs=1 skip="$2" count="$3" status=none
}

cut pal.bin  $((0x0010)) $((0x0800))
cut pf1.bin  $((0x0810)) $((0x1000))
cut pf2.bin  $((0x1810)) $((0x1000))
cut rs1.bin  $((0x2810)) $((0x1000))
cut rs2.bin  $((0x3810)) $((0x1000))
cut oram.bin $((0x4810)) $((0x1000))
echo "rest2bin: pal/pf1/pf2/rs1/rs2/oram split; deco16ic regs stay in rest.bin @0"
