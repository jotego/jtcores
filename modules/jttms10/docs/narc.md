# NARC integration

NARC defines `JTNARC_UCODE` in `cfg/macros.def`, so its GSP wrapper and file
list use `modules/jttms10` and generate both YAML microcode ROMs by default.
The conditional wrapper retains the pinned old CPU for reference work.
The new selection uses the same NARC cycle
controller, 48 MHz clock, and video clock enable. Host, HOLD and external
video sync inputs use NARC's existing tie-offs.

For example, from `cores/narc/ver/narc`:

```sh
jtsim -mister -video -time 1000
```

ROM/SDRAM inputs must already be present, or use the usual `-load` flow.
A simulation diagnostic stops on an unsupported defined opcode and reports
its IR and following PC. Graphics and cache have architectural and focused
bus tests. The matched CPU-boundary fit is 2,746 ALMs against the old
14,000 ALMs; final-source NARC gameplay and board timing validation are
running. See the [area report](../ver/area/README.md).

The old CPU's first 571-input-frame run completed normally at 54.83 Hz. It
reached NARC's connector/chip ROM-test display, with no attract screen yet.
The capture, simulator, ROM hash and 240 source hashes are archived under
`/tmp/jttms10-141/narc-reference-full`. The script includes reset at input
frame 70; ROM download precedes input playback. The simulator reported no
`cmos.bin`, so factory CMOS contents are not assumed. A longer baseline
reuses the exact archived simulator in
`/tmp/jttms10-141/narc-reference-extended`.
