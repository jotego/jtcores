# Cache Tags Block Index Simunit

This test exercises `jtframe_cache_tags` with `SETS=3` and `WAYS=4`. The
block index outputs must remain densely packed as `way * SETS + set`; this
catches rewrites that assume `SETS` is a power of two.
