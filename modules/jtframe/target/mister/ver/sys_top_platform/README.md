# MiSTer `sys_top` platform regression

Run `./sim.sh` from any directory. The test compiles the production
`sys_top.v` and supplies passive stubs for external FPGA/HPS peripherals and
video/audio blocks. The test directly drives top-level clock, sync, command,
and audio boundaries with hierarchical forces; the modified decoder, frame
counter, audio selection registers, and output gates are the real `sys_top`
logic.

The checks cover analog/HDMI audio source selection on `clk_audio`, output
gating by `av_dis`, the inverted HDMI interrupt input in `gp_in[20]`, command
`0x44` capability and command `0x42` frame count responses, sampled VS edge
counting, and 8-bit wraparound. Verilator is two-state, so this regression
checks that `av_dis` gates the pins but does not prove the physical high
impedance state. The RTL still drives `Z` in the production assignment; a
four-state board or simulator check remains necessary for that electrical
property.

The external stubs were generated from the `sys_top.v` instance port names
and adjusted only to declare the actual parameter names used by positional
and named overrides. No production RTL is copied into the stubs.
