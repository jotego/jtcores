# NARC integration

NARC defines `JTNARC_UCODE` in `cfg/macros.def`, so its GSP wrapper and file
list use `modules/jttms10` and generate both YAML microcode ROMs by default.
The conditional wrapper retains the pinned old CPU for reference work.
The new selection uses the same NARC cycle
controller, 48 MHz clock, and video clock enable. Host, HOLD and external
video sync inputs use NARC's existing tie-offs.

NARC sets `JTFRAME_NO_REGISTER_RETIMING` to disable Quartus's optional physical
register-retiming search, which takes excessive time on the shared microcoded
datapath. The clocks and timing constraints are unchanged.

For example, from `cores/narc/ver/narc`:

```sh
jtsim -mister -video -time 1000
```

ROM/SDRAM inputs must already be present, or use the usual `-load` flow.
The directed gameplay script is checked in as `ver/narc.cab`. With the
same initialized `cmos.bin` used by the archived run, invoke from
`cores/narc/ver/narc`:

```sh
jtsim -mister -video -d NARC_SKIPPOST "$MODULES/jttms10/ver/narc.cab"
```

This script inserts a coin, starts one player, waits for the briefing,
then exercises right/fire, left/fire and rockets. `NARC_SKIPPOST` changes
two existing program words; use an ordinary build without that option
for unmodified startup testing.

A simulation diagnostic stops on an unsupported defined opcode and reports
its IR and following PC. Graphics and cache have architectural and focused
bus tests. The matched CPU-boundary fit is **2,746 ALMs against the old
14,000 ALMs**, with identical device, clock, seed, effort and wrapper.
See the [area report](../ver/area/README.md).

## Final CPU validation

The CPU HDL and YAML used by these checks match commit
`a0d3612799adaa1df556aac8b5f6f2b27ae33b5b`. Later build configuration disables
optional register retiming; it changes neither RTL nor generated ROMs.

The frozen regression passes 180 architectural programs, the full
unit/system suite, 160 independent array programs, 44 all-PPOP PIXT
programs, 20 LINE programs and strict lint. The decoder audit covers all
65,536 encodings, and the graphics flow audit checks 2,058 reachable
states with a maximum return depth of two.

Both HDMI-enabled MiSTer profiles pass with Quartus Lite 20.1.1 Build 720
and Cyclone V 5CSEBA6U23I7:

| Physical register retiming | Seed | ALMs | RAM blocks | DSPs | Setup slack | Hold slack |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| ON | 1 | 21,285 | 399 | 48 | +0.349 ns | +0.254 ns |
| OFF (final NARC setting) | 1 | 21,080 | 399 | 48 | +0.033 ns | +0.249 ns |

All reported constrained groups have zero total negative slack. Existing
board constraints leave the auxiliary `joy_db15 JCLOCKS[4]` clock and
20 input/88 output ports unconstrained. These results establish closure
of the constrained paths.

The ON build completed in 69m49s. The final OFF retry reused its unchanged,
successful map database and generated fresh fit, assembler and timing
outputs in 19m30s; source hashes verify the reused mapped inputs.
The final OFF bitstream SHA256 is
`116955515c84f55944825536c5b1fb9ead7d79ac947caec7d4e530b41392de81`.
Its hash was verified after copying to MiSTer. The unmodified-ROM MRA,
without `NARC_SKIPPOST`, reached factory-settings restoration on first
boot. F3 reset then reached attract mode; coin/start reached active
gameplay. Sustained right/fire produced movement, scrolling through several
buildings, visible shots and defeated enemies. Captures four seconds apart
show ammunition 44 to 23 and score 2300 to 5150. The earlier ON hardware
check also covered left/fire and rockets. No physical audio capture or
listening is claimed.

The root quick build `jtcore narc -mrq --seed 2` completed in 17m20s,
using 15,905 ALMs, 346 RAM blocks and 25 DSPs. Its constrained setup/hold
slack is +0.080/+0.247 ns, with zero TNS. Quick mode disables HDMI/scaler.
Seed 1 compiled but missed setup by 0.455 ns on the existing 96 MHz DMA
path from `u_dma|ctrl[4]` to duplicated `src_addr` registers. Seed 2 changes
only placement; CPU RTL, ROMs and constraints are identical. The passing
quick RBF remains at `release/mister/jtnarc.rbf`; the tested HDMI RBF is
`release/mister/jtnarc-issue141-final.rbf`.

The final directed RTL simulation completed with observed exit status zero:
1,310 input frames, 1,311 video frames, 1,040 saved PNGs and at least
36,700,161 retired instructions without a CPU fault. It renders the agency
intro, car/player entry, right/fire, left/fire and a rocket trail. Captures
show scores 100, 200 and 300, ammunition consumption and rocket count 5 to 4.
All simulator, CMOS, script and SDRAM input hashes still match the launch
manifest. The checked-in CAB file is byte-identical to the executed script.

This simulation uses the existing two-word `NARC_SKIPPOST` option and
independently initialized CMOS; it does not establish unmodified startup.
The separate hardware checks above use the unmodified ROM.

Final audio is stereo 48 kHz, 1,150,982 sample frames (23.979 seconds), peak
10,179, with no clipped samples. An independent 64-band log-spectral
sequence search aligns simulation 6–10 s with MAME 147.2–151.2 s (score
0.758, unrelated maximum 0.386). Simulation 16–20 s aligns with MAME
156.1–160.1 s (score 0.746, next nonoverlapping match 0.627). The 18–20 s
tail alone is not unique. These results support the common intro/game-entry
music and voice sequence; differing player inputs preclude claiming
individual firing-effect or full-stream equivalence. No audio was auditioned.

Artifacts are archived separately so differing source and build profiles
are not mixed:

| Evidence | Archive |
| --- | --- |
| Matched CPU fit, 28 copied inputs and 7 regenerated files | `/tmp/jttms10-141-area/generic-final-snapshot` |
| Frozen CPU regression and generated graphics tests | `/tmp/jttms10-141/generic-corrected-snapshot` |
| CPU HDMI retiming-ON build and hardware screenshots | `/tmp/jttms10-141/narc-fpga-generic-hdmi` |
| Final HDMI retiming-OFF build and hardware screenshots | `/tmp/jttms10-141/narc-fpga-generic-retimeoff-supervised` |
| Passing root quick build, seed 2 | `/tmp/jttms10-141/narc-native-seed2` |
| Final directed RTL gameplay/audio simulation | `/tmp/jttms10-141/narc-generic-gameplay` |
| Independent MAME timeline and audio | `/tmp/jttms10-141/narc-mame-input-timeline` |
| Intro audio sequence analysis | `/tmp/jttms10-141/audio-validation` |

The implementation is architecturally tested and runs NARC; it does not
claim instruction-cycle equivalence with the original CPU. NARC ties off
the physical asynchronous host interface, whose board timing is outside
this validation.
