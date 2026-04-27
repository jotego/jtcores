# Cache Big-Endian Test

This simunit test exercises `jtframe_cache` as a `DW=32`, `ENDIAN=1`
read/write cache against `jtframe_burst_sdram` and the `mt48lc16m16a2`
SDRAM model.

It checks:

- 32-bit big-endian read assembly from two 16-bit SDRAM words
- full-width writes
- partial writes on the upper and lower 16-bit halves
- dirty eviction and re-read from SDRAM after write-back
