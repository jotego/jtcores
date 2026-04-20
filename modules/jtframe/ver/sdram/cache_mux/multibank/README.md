Exercises `jtframe_cache_mux` with one full-SDRAM cache lane and one fixed-bank
lane.

The bench checks:
- full-range lanes derive the SDRAM bank from the top cache address bits
- the burst address stays bank-local for full-range lanes
- fixed-bank lanes still use their configured `BA` and `OFFSET`
- mixed arbitration between a full-range lane and a fixed-bank lane still works
