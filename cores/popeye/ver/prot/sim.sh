#!/bin/bash
cd "$(dirname "$0")"
ZIPD=${POPEYE_ZIP:-/mnt/c/Roms/Mame/popeye.zip}
ZIPU=${POPEYEU_ZIP:-/mnt/c/Roms/Mame/popeyeu.zip}
TMP=$(mktemp -d)
python3 -I dec.py "$ZIPD" "$ZIPU" $TMP/d.bin $TMP/u.bin || { rm -rf $TMP; exit 1; }
iverilog -g2005 -s test -o $TMP/sim test.v ../../hdl/jtpopeye_prot.v \
    -DDROM=\"$TMP/d.bin\" -DUROM=\"$TMP/u.bin\" || { rm -rf $TMP; exit 1; }
vvp -n $TMP/sim | tee $TMP/sim.log
RESULT=${PIPESTATUS[0]}
grep -q "^PASS" $TMP/sim.log || RESULT=1
rm -rf $TMP
exit $RESULT
