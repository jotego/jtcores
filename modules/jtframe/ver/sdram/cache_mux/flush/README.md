Dedicated flush test for `jtframe_cache_mux`.

The bench writes a dirty word through lane 0, checks that the SDRAM backing
store is still stale while the dirty line is resident in cache, asserts
`flush0`, waits for `flushing0` and `flush_done0`, then verifies the SDRAM word
was written back through the mux SDRAM path. It then flushes the same clean
line again and checks that no mux SDRAM write request is issued.
