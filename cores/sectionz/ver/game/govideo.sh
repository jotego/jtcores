#!/bin/bash
# simulates a MAME video dump only for CHAR layer

# dd if=char.bin of=char0.bin count=2
# dd if=char.bin of=char1.bin count=2 skip=2

go.sh -d NOMAIN -d NOSOUND -video 3 -deep \
    -d NOOBJ -d NOSCR -d PAL_GRAY \
    -d JTCHAR_LOWER_SIMFILE=',.simfile("char0.bin")' \
    -d JTCHAR_UPPER_SIMFILE=',.simfile("char1.bin")' 
