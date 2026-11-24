# MiSTer regression capture

Unit test for `jtframe_mister_capture`, driven through the real
`jtframe_mister_uio` transport: the testbench sends ARM (0x91) word by word
and reads the status (0x90) and the JTC3 result (0x92) back, as Main does.
CAB interval starts are driven directly (interval f is frame f+1). The native
video has a two-pixel pipeline delay after the game's LVBL. A DDR model with
random `busy` stalls records the bursts.

The checker rebuilds each expected image independently and compares every
pixel byte and the zero row padding read back from DDR, the JTC3 words and
the GFW1 hash computed over the DDR payload. Main's rule is used throughout:
a capture is good when `ready` rises, missed when the status frame passes the
target with `ready` low.

Cases: capture and freeze while the game runs, ARM that keeps the frame
number and releases the slot, recapture under heavy stalls, DDR stalled
across the frame start that ends the target frame, ARM 0, a target in the
past, ARM while the target picture is drawn, ARM that moves a target, a video
mode change and a geometry change in the target frame, malformed ARM
commands, every partial-word row ending (widths 9 to 16), a 400x240 frame
(1,200 payload bursts), a FIFO overrun followed by a good capture, and a new
CAB session clearing the frame number.
