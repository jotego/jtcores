# Cache + Burst SDRAM Unit Test

This simunit test hooks `jtframe_cache` to `jtframe_burst_sdram` and the
`mt48lc16m16a2` SDRAM model.

## What It Verifies

- SDRAM initialization completes and the download path can preload memory
- `jtframe_cache` can refill a cache line through `jtframe_burst_sdram`
- reads inside a filled line complete as cache hits without a new SDRAM burst
- reads from new line regions trigger new cache refill bursts
- after one refill completes, the cache can issue a later refill request and
  return the correct data

## Test Flow

1. Reset the SDRAM controller and wait for initialization to finish.
2. Preload a deterministic byte pattern into SDRAM through `jtframe_dwnld`.
3. Read several words through `jtframe_cache`.
4. Alternate between same-line reads and different-line reads so the bench sees
   both cache hits and refill-triggering misses.
5. Count SDRAM `ack` pulses to confirm only the misses open a new burst.
