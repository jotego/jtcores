# ROM requester consumer interface

Runs `jtframe_romrq_bcache` and `jtframe_romrq_lcache` through independent,
identical `jtframe_sdram64` controllers and Micron SDRAM models. For each
consumer request it verifies that `data_ok` only acknowledges known data,
both caches return the same data, cache hits issue no SDRAM request, and logs
the latency from `addr_ok` to each response. Cache pin waveforms are not
compared directly because their internal hit handling differs.
