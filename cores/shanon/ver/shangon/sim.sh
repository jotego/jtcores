#!/bin/bash
# copy the road ROM in the right format for simulation

dd if=rom.bin of=rd0.bin bs=4k skip=$((0x270000/4096)) count=$((0x4000/4096))
dd if=rom.bin of=rd1.bin bs=4k skip=$((0x274000/4096)) count=$((0x4000/4096))

jtutil drop1    <rd0.bin >rd0_hi.bin
jtutil drop1 -l <rd0.bin >rd0_lo.bin

jtutil drop1    <rd1.bin >rd1_hi.bin
jtutil drop1 -l <rd1.bin >rd1_lo.bin

jtsim $*