Long-running read-only stress test for `jtframe_cache_mux`.

The bench runs for 20ms of simulated time with:
- all eight lanes active
- different cache block sizes across lanes
- disjoint SDRAM regions per lane
- refresh pulses every 64us

It checks consumer-visible read data continuously and fails if SDRAM refresh overlaps an active burst.
