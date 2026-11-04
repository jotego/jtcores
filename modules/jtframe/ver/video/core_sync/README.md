# Core exported sync timing regression

This test measures the live `LHBL`, `LVBL`, `HS`, and `VS` ports of the actual
video module for Block Out, Pocket Gal, Street Fighter, Side Arms, Gaelco 1,
and Toki. It keeps the real timer, sync comparators, and SF/Side Arms color
mixer blanking pipeline in the elaborated hierarchy. It checks sync containment,
stable pulse widths and line totals, and horizontal and vertical centering in
the exported blanking intervals. A second bench sends each actual export through
nine real `jtframe_resync` instances to cover H/V defaults and all combinations
of the minimum and maximum MiSTer offsets. It checks pulse widths, containment,
line/frame totals, and the measured phase delta. The Icarus fixture initializes
the resync `field` register to model FPGA power-up; the RTL module has no reset
for that register. Gaelco 1 can be run with more than one `VTOTAL` value.

From the repository root, after sourcing `modules/jtframe/bin/setprj.sh`:

```sh
bash modules/jtframe/ver/video/core_sync/run.sh blkout
bash modules/jtframe/ver/video/core_sync/run.sh pktgal
bash modules/jtframe/ver/video/core_sync/run.sh sf
bash modules/jtframe/ver/video/core_sync/run.sh sarms
bash modules/jtframe/ver/video/core_sync/run.sh gae1 272
bash modules/jtframe/ver/video/core_sync/run.sh gae1 348
bash modules/jtframe/ver/video/core_sync/run.sh gae1 273
bash modules/jtframe/ver/video/core_sync/run.sh toki
```

Each invocation gets its source search directories from `jtframe files sim`
and lazily elaborates the actual video hierarchy with Icarus. A run prints a
`PASS` line containing the measured porches, pulse widths, and totals. Set
`WAVEFORM=1` to save a VCD of the exported sync and blanking ports. To measure
pre-change top-level timing against the issue branch base, use
`SOURCE_REV=8f88d2e9fff6f52d5e89d0af91a113d6c1dbfed3 bash .../run.sh <core>`.
The base run disables centering assertions but still checks pulse widths,
active geometry, totals, frame period, and sync containment.

## Measured output ports

Baseline is commit `8f88d2e9fff6f52d5e89d0af91a113d6c1dbfed3`; candidate is
the issue worktree after sync-phase changes. `V` porch measurements are in
lines; half-line values are retained. The test measures the video-module ports,
including the SF/Side Arms color-mixer blanking delay.

| Core | H front/sync/back before → after (pixels) | V front/sync/back before → after (lines) | Active / total, before and after |
|---|---:|---:|---:|
| blkout | 31/27/134 → 82/27/83 | 10.113/3/15.887 → 13/3/13 | 320×240 / 512×269 |
| pktgal | 24/32/72 → 48/32/48 | 8.146/3/24.854 → 16.5/3/16.5 | 256×224 / 384×260 |
| sf | 32/40/56 → 44/40/44 | 5.016/3/23.984 → 14.5/3/14.5 | 384×224 / 512×256 |
| sarms | 32/40/56 → 44/40/44 | 5.031/3/23.969 → 14.5/3/14.5 | 384×224 / 512×256 |
| gae1 (`VTOTAL=272`) | 4/28/32 → 18/28/18 | 8.083/8/15.917 → 12/8/12 | 320×240 / 384×272 |
| toki | 34/32/62 → 48/32/48 | 9.865/3/25.135 → 17.5/3/17.5 | 256×224 / 384×262 |

All six retained their active dimensions, totals, sync widths, blank widths,
and frame periods in the direct-port comparison. Gaelco 1 also passed the
direct-export checks at `VTOTAL=273` and `348`; the corresponding centered
vertical porches were 12.5/8/12.5 and 50/8/50 lines. The resync offsets leave
active blanking and frame timing unchanged and preserve pulse widths.
Measured pixel-enable ticks per frame stayed at 137728 (Block Out), 99840
(Pocket Gal), 131072 (SF and Side Arms), 104448 (Gaelco 1 at `VTOTAL=272`), and
100608 (Toki). Gaelco 1 variants used 104832 ticks at `273` and 133632 at `348`.

The baseline and candidate results show unchanged active dimensions and frame
timing for all six cores. The targeted video modules keep their timer HS routed
to renderer consumers; the test checks those raw-HS connections for Block Out,
Pocket Gal, Gaelco 1, and Toki. SF and Side Arms renderers do not consume HS.
This is a manually invoked timing harness, not a `simunit-all.sh` test: it uses
`jtframe files sim` directories to lazily load the complete real video-module
dependency closure without pulling unrelated CPU/SDRAM sources into Icarus.
The timing test does not load game ROM scenes or claim RGB image equivalence. An
existing Toki scene comparison reports exact frame-0800 match and no new
scene-10 pixel difference versus the baseline; scene 10 already differs from
its stored reference by 8.2642%. No final MiSTer VGA/HDMI pins or physical CRT
were tested.
