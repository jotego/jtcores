#!/bin/bash -e
EXPECTED=$((8192+16+16))
SIZE=$(wc -c < rest.bin)
if [ $SIZE -ne  $EXPECTED ]; then
	echo "wrong size for rest.bin. Expected $EXPECTED bytes but got $SIZE"
	exit 1
fi

dd if=rest.bin of=obj.bin bs=1K count=8
jtutil drop1    < obj.bin > obj_hi.bin
jtutil drop1 -l < obj.bin > obj_lo.bin

dd if=rest.bin of=obj_mmr.bin bs=8  count=1 skip=1024

dd if=rest.bin of=ccu.bin bs=8  count=2 skip=1026
if [ $(od -tx1 -An ccu.bin | tr -d ' ') != 01ff0019001f04000107110e74000000 ]; then
	echo "wrong contents for CCU configuration"
	exit 1
fi