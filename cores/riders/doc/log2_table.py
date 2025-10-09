#!/usr/bin/python
# generates a LUT for the log2 function
# 2**10 entries, each of 2**9 bits, so it fits in one BRAM
import math
with open("../hdl/log2.hex","w") as f:
    maxlog = math.log2(1023)
    for i in range(1024):
        if i==0:
            q = 0
        else:
            val = math.log2(i)
            q   = int(round(val * (1<<9)/maxlog ))
        if q>0x1ff:
            q = 0x1ff
        f.write(f"{q:03x}\n")

with open("../hdl/exp2.hex","w") as f:
    for i in range(1024):
        q = int(round(2.0**(i*(10.0/511))))
        if q>0x7fff:
            q = 0x7fff
        f.write(f"{q:04x}\n")