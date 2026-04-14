# Cache Mux + Burst SDRAM Unit Test

This simunit test hooks `jtframe_cache_mux` to `jtframe_burst_sdram` and the
`mt48lc16m16a2` SDRAM model.

## What It Verifies

- cache instances can target different SDRAM banks and offsets
- mixed cache widths (`DW=8`, `16`, and `32`) return the expected data
- misses serialize onto the single burst SDRAM consumer interface
- back-to-back misses from different caches are served one at a time

## Test Flow

1. Reset the SDRAM controller and wait for initialization to finish.
2. Preload three bank regions with deterministic byte patterns through
   `jtframe_dwnld`.
3. Read through three cache instances configured with different widths.
4. Launch two misses together and confirm the mux completes them serially.
