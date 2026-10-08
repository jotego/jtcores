# Cache Read/Write Test

This simunit test exercises `jtframe_cache` directly against
`jtframe_burst_sdram` and the `mt48lc16m16a2` SDRAM model with the full
consumer interface enabled.

It runs three cache instances:

- `DW=8`
- `DW=16`
- `DW=32`, little-endian

The test covers:

- write miss with refill
- write hit
- partial writes
- dirty eviction and write-back
- readback after cache hits and misses
