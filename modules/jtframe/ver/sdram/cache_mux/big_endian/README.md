Exercises `jtframe_cache_mux` with 32-bit, big-endian caches.

The bench verifies:
- 32-bit big-endian reads through the mux
- write hits and partial byte-lane writes on a writable lane
- dirty eviction and write-back through the shared SDRAM port
- refill correctness after the dirty line is evicted
