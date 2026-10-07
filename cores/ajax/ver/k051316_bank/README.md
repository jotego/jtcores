The 051316 ROM address uses register 13 as the high five bank bits and
register 12 as the low eight bank bits. This simunit checks the generated MMR
output that feeds both the renderer and the CPU ROM read path.

The 88 Games extended ROM test sweeps register 12 through all 256 values.
An earlier mapping put those eight bits above register 13, making each step
jump 32 KiB instead of 1 KiB in its four-bit-per-pixel ROM.
