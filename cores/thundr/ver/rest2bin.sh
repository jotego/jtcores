#!/bin/bash
dd if=rest.bin of=mmr0.bin  bs=8 count=1
dd if=rest.bin of=mmr1.bin  bs=8 count=1 skip=1
dd if=rest.bin of=ommr.bin  bs=4 count=1 skip=4
dd if=rest.bin of=other.bin bs=1 count=2 skip=20
