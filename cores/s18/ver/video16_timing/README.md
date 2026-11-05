# S18 real S16 graphics timing fixture

This bounded simunit exercises the production `jts18_video16` wrapper with the
S16B tilemap, character, both scroll planes, object scanner/drawer, priority
encoder, and color DAC. Registered address-tagged responders model one-clock
palette data and fixed four-clock character/map/scroll/object memories. For
each request, the responder waits four stable address clocks, registers the
address-derived data, then holds the cache-hit `ok` level and data until the
address changes. `init.go` creates the character and object RAM images and a
zeroed S16 MMR initialization file; the bench then programs legal S16B MMR
addresses through the wrapper's CPU port, including row and column scroll
enables.

The bench records startup line-buffer state and strictly captures the 320 active
source coordinates on V0–V2 for the static original timer and the production
dual-rate timer in fast mode, then repeats V0–V2 after each live switch. It
caches each stream by its own H/V source coordinates, then compares complete
layer/palette/RGB tuples. At each instance's own H128 deadline, it requires the
scroll engines to report `done` and confirms that each line buffer committed
address 511 since its last real start edge. It also checks active endpoints,
nonzero data from every layer, row/column scroll latches, `scr_bad`, and
sprite-list completion. Two objects are visible on the first sentinel row; a
62-object list is visible on the next two rows. The dual-rate request changes
through the production input in both directions, and each reacquired line-buffer
output is checked against its captured profile cache. A 950-line physical-line watchdog
bounds the run; it does not boot the game or use scene data.

The same run compares fixed-mode `jts16_vtimer` and `jtframe_vtimer` cycle by
cycle from simulation startup for the default S16 endpoints, the S18 `HS_END`
override, and a varied `HB_END`. It checks all counters, blanking, and sync
outputs while the fixed-mode request toggles through both values on enabled
samples; the public `is_57Hz` output must remain high.

Run from the repository root after sourcing `modules/jtframe/bin/setprj.sh`:

```sh
simunit.sh --run cores/s18/ver/video16_timing
```

The comparison is specific to this deterministic memory latency and content.
It is a fetch-budget and live-switch check for the actual S18 S16 graphics path,
not a claim of whole-game compatibility.
