# ROM request large cache synchronous tags
Exercises `jtframe_romrq_lcache` with `TAG_RAM=1`. It checks the synchronous
tag lookup latency, tag/data alignment across a 32-bit cache line, direct-map
replacement, cache clear invalidation, and a client address glitch while a
miss is pending. The glitch is allowed to make the transient `dout` invalid,
but it must not corrupt the cache line selected by the original request.
