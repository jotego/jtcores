#!/bin/bash
set -euo pipefail
export LC_ALL=C

if [[ ${1:-} == --delete ]]; then
    # The direct EEPROM port is outside mem.yaml's BRAM dump sections.
    rm -f nvram.bin pal.bin palh.bin pf1.bin pf2.bin rs1.bin rs2.bin oram.bin
    if [[ -f nvram.seed ]]; then cp nvram.seed nvram.bin; fi
    exit 0
fi

# Preserve the existing scene-replay layout as well as direct EEPROM uploads.
SIZE=$(wc -c < rest.bin | tr -d '[:space:]')
split() { dd if=rest.bin of="$1" bs=1 skip="$2" count="$3" 2>/dev/null; }
case "$SIZE" in
    128)
        dd if=rest.bin of=nvram.bin bs=128 count=1 2>/dev/null
        ;;
    $((0x5810)))
        # MAME video dump: control 0x10, palette 0x800, then five 0x1000
        # regions (pf1, pf2, rowscroll 1/2 and sprite RAM).
        # Control registers remain in rest.bin for jtdeco16ic_mmr SEEK=0.
        rm -f nvram.bin
        split pal.bin  $((0x0010)) $((0x0800))
        # Avoid retaining a previous Heavy Smash scene's high palette half.
        dd if=/dev/zero of=palh.bin bs=2048 count=1 2>/dev/null
        split pf1.bin  $((0x0810)) $((0x1000))
        split pf2.bin  $((0x1810)) $((0x1000))
        split rs1.bin  $((0x2810)) $((0x1000))
        split rs2.bin  $((0x3810)) $((0x1000))
        split oram.bin $((0x4810)) $((0x1000))
        ;;
    $((0x6010)))
        # Heavy Smash: control 0x10, 1024 LE32 xBGR888 palette words,
        # then the same five 0x1000-byte video RAM regions.
        # Each dword becomes a low (R/G) and high (B/unused) LE16 word.
        rm -f nvram.bin
        : > pal.bin
        : > palh.bin
        dd if=rest.bin bs=1 skip=16 count=4096 2>/dev/null |
            od -An -v -tu1 |
            awk '{ for (i=1; i<=NF; i++) {
                if ((n++ % 4) < 2) printf "%c", $i > "pal.bin";
                else printf "%c", $i > "palh.bin";
            } }'
        split pf1.bin  $((0x1010)) $((0x1000))
        split pf2.bin  $((0x2010)) $((0x1000))
        split rs1.bin  $((0x3010)) $((0x1000))
        split rs2.bin  $((0x4010)) $((0x1000))
        split oram.bin $((0x5010)) $((0x1000))
        ;;
    *) echo "rest2bin: $SIZE bytes; expected 128-byte EEPROM, 0x5810-byte scene or 0x6010-byte Heavy Smash scene" >&2; exit 1;;
esac
