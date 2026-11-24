# S18 native sync centering

This simunit drives the production dual-rate S16 raster timer into the S18
centered sync helper and two instances of JTFRAME's actual
`jtframe_resync`. One instance receives raw HS/VS plus the former 320-pixel
OSD settings (H+4/V-4 at 57 Hz, H+7/V-4 at 60 Hz); the other receives native
centered HS/VS and zero offsets. It waits three active-frame boundaries after
each rate settles so both resync field slots have learned the input phase,
then compares the resync outputs across a full frame. It also repeats the fast
profile after a live switch back, checks known outputs and expected HS/VS edge
counts, and has a pixel-enable watchdog.

Run from the repository root after sourcing `modules/jtframe/bin/setprj.sh`:

```sh
simunit.sh --run cores/s18/ver/sync_center
```
