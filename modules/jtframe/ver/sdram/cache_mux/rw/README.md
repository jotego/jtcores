Read/write stress test for `jtframe_cache_mux`.

The bench drives:
- random reads and writes on writable lanes 0..3
- random reads on read-only lanes 4..7
- disjoint SDRAM regions per lane
- refresh pulses every 64us

It checks consumer-visible read data during the run, requires every writable lane to complete writes, then flushes the caches and compares SDRAM contents against the software model.
