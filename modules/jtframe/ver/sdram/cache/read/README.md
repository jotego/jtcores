# Cache Read Test

This simunit test exercises `jtframe_cache` directly against
`jtframe_burst_sdram` and the `mt48lc16m16a2` SDRAM model.

It runs three independent cache instances:

- `DW=8`
- `DW=16`
- `DW=32`, little-endian

The test preloads deterministic bytes through `jtframe_dwnld`, checks the first
and last elements inside cache lines, and confirms that cache hits do not open a
new SDRAM burst.

