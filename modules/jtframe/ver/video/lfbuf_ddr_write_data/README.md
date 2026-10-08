# LF-buffer DDR write data alignment

This simunit checks the handoff between `jtframe_lfbuf_line` and
`jtframe_lfbuf_ddr_ctrl` during the DDR write phase.

The test fills one completed line with a unique value per horizontal address,
then lets the DDR controller copy that line out through `fb_din` / `ddram_din`.
The DDR write stream must carry `pattern[fb_addr]` at each write address. A
one-cycle `fb_din` latency bug appears as `pattern[fb_addr-1]` and fails the
test immediately.
