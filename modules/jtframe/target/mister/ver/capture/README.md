# MiSTer regression capture

Unit test for `jtframe_mister_capture`, driven through the real
`jtframe_mister_uio` transport: the testbench sends CAP_* commands word by
word and reads CAPS and the descriptor back, as Main does. CAB replay signals
are driven directly. The native video has a two-pixel pipeline delay after
the game's LVBL. A DDR model with random `busy` stalls records the bursts.

The checker rebuilds each expected image independently and compares every
pixel byte and the zero row padding read back from DDR, the JTC2 descriptor
fields, its CRC32 and the GFW1 hash computed over the DDR payload.

Cases: ARM without a CAB session, capture and freeze while the game runs,
release and repeated release, recapture under heavy stalls, a wrong release,
abort, a late target, an ARM in the middle of the frame before the target, a
mode change, a geometry change in the target frame, bad ARM payloads, a
lifecycle drop, a short command, every partial-word row ending (widths 9 to
16), a 400x240 frame (1,200 payload bursts), a DDR stall that overruns the
FIFO, a replay that ends before the target and an ARM in DONE for a checkpoint
that has already passed.
