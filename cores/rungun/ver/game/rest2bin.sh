#!/bin/bash
dd if=rest.bin of=obj.bin bs=1K count=8
dd if=rest.bin of=ccu.bin bs=8  count=2 skip=1K
dd if=rest.bin of=obj_mmr.bin bs=8  count=1 skip=1026
jtutil drop1    < obj.bin > obj_hi.bin
jtutil drop1 -l < obj.bin > obj_lo.bin
