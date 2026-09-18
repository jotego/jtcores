# DDR line-buffer pipeline

This simunit runs the complete DDR wrapper, synchronous line RAMs, and DDR model
with a handshake-driven pixel producer. It runs both with and without
`JTFRAME_LF_FULLV`, plus the 10-bit horizontal / 9-bit vertical address widths
used by CPS3.

A scoreboard checks every accepted DDR pixel, destination row, and frame bank.
Blank requests deliberately produce pixels: these must not reach DDR or survive
buffer clearing. Subsequent sparse lines verify cleared pixels as well as writes.
The test also requires drawing and copying to overlap and exactly one
acknowledgement before each subsequent request.

Stalls cover the first/last words, both sides of a 128-word burst boundary, a
mid-burst pause spanning two VS edges with both line buffers occupied, a renderer
held across two VS edges, and the last line's clearing across VS. Frames must
repeat during overruns and resume afterwards without pixel loss or reordering.

Horizontal and vertical scale factors change through values above and below
unity. An independent expected-height check verifies the visible source-line
count, including rounding up fractional vertical downscaling;
`lfbuf_scale` separately checks readout sampling stability.

The memory-model clock pauses during injected busy periods, preserving a burst's
position until the controller can accept another beat. No DUT state is forced.
