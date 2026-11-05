# YM7101 external raster tracker

This simunit drives independent synthetic active-high HS/VS and LHBL/LVBL timing into `ym7101_raster`. It checks 400x262, 384x262, 384x260 and 384x261 totals with a 320x224 active region, changes horizontal and vertical edge offsets, shifts stable edges by one clk48 tick, and removes HS/VS and pixel-enable edges. Reset is held while the synthetic raster and enables continue advancing. An independent oracle checks x/y at every active pixel sample over multiple lines.

The tracker reports external coordinates and measured geometry only. It does not indicate VDP renderer or prefetch readiness.

Run from the repository root:

```sh
source modules/jtframe/bin/setprj.sh >/dev/null
simunit.sh --run cores/s18/ver/ym7101_raster
```
