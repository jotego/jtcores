Long-running read-only stress test for `jtframe_cache_mux`.

The bench runs for about 6ms of simulated time by default with:
- all eight lanes active
- different cache block sizes across lanes
- disjoint SDRAM regions per lane
- refresh pulses every 64us (`STRESS_CYCLES`, default `300_000` via `--macros`)

It checks consumer-visible read data continuously and fails if SDRAM refresh overlaps an active burst.
