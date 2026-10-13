#!/bin/bash -e

if [[ ${1:-} == --delete ]]; then
    # The direct EEPROM port is outside mem.yaml's BRAM dump sections.
    rm -f nvram.bin pal.bin pf1.bin pf2.bin rs1.bin rs2.bin oram.bin
    if [[ -f nvram.seed ]]; then cp nvram.seed nvram.bin; fi
    exit 0
fi

# Preserve the existing scene-replay layout as well as direct EEPROM uploads.
SIZE=$(wc -c < rest.bin | tr -d '[:space:]')
case "$SIZE" in
    128)
        dd if=rest.bin of=nvram.bin bs=128 count=1 2>/dev/null
        ;;
    $((0x5810)))
        # MAME video dump: control 0x10, palette 0x800, then five 0x1000
        # regions (pf1, pf2, rowscroll 1/2 and sprite RAM).
        # Control registers remain in rest.bin for jtdeco16ic_mmr SEEK=0.
        rm -f nvram.bin
        split() { dd if=rest.bin of="$1" bs=1 skip="$2" count="$3" 2>/dev/null; }
        split pal.bin  $((0x0010)) $((0x0800))
        split pf1.bin  $((0x0810)) $((0x1000))
        split pf2.bin  $((0x1810)) $((0x1000))
        split rs1.bin  $((0x2810)) $((0x1000))
        split rs2.bin  $((0x3810)) $((0x1000))
        split oram.bin $((0x4810)) $((0x1000))
        ;;
    *) echo "rest2bin: $SIZE bytes; expected 128-byte EEPROM or 0x5810-byte scene" >&2; exit 1;;
esac
