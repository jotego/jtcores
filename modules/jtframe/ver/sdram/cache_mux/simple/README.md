Exercises `jtframe_cache_mux` with 16-bit lanes against the burst SDRAM path.

The bench checks:
- fixed-priority arbitration between simultaneous misses
- `okN` staying asserted until the requester drops `rdN`
- address latching on the request edge
- read-only lane service
- dropped requests that are already in flight still blocking later misses until completion
